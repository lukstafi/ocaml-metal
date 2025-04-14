open Ctypes
open Ctypes_static

(* Shader kernel with simple computation *)
let compute_kernel_source = "
  #include <metal_stdlib>
  using namespace metal;

  kernel void increment_kernel(device int *buffer [[buffer(0)]],
                        uint index [[thread_position_in_grid]]) {
    buffer[index] += 1;
  }
"

let () =
  (* Initialize Metal *)
  let device = Metal.Device.create_system_default () in
  Printf.printf "Metal device: %s\n" (Metal.Device.get_attributes device).name;

  (* Create two separate command queues to demonstrate queue synchronization *)
  let command_queue1 = Metal.CommandQueue.on_device device in
  let command_queue2 = Metal.CommandQueue.on_device device in
  Printf.printf "Created two command queues\n";

  (* Create a shared event for synchronization between queues *)
  let shared_event = Metal.SharedEvent.on_device device in
  Metal.SharedEvent.set_label shared_event "Queue Sync Event";
  let signal_value = Unsigned.ULLong.of_int 1 in
  
  (* Create data buffer for computation *)
  let array_length = 1024 in
  let buffer_size = array_length * sizeof int in
  let options = Metal.ResourceOptions.storage_mode_shared in
  let data_buffer = Metal.Buffer.on_device device ~length:buffer_size options in
  
  (* Initialize buffer with zeros *)
  let buffer_ptr = Metal.Buffer.contents data_buffer in
  for i = 0 to array_length - 1 do
    let ptr = (coerce (ptr void) (ptr int) buffer_ptr) +@ i in
    ptr <-@ 0
  done;
  
  (* Create a fence for synchronization within encoders *)
  let fence = Metal.Fence.on_device device in
  Metal.Fence.set_label fence "Encoder Sync Fence";
  
  (* Compile the kernel *)
  let compile_options = Metal.CompileOptions.init () in
  Metal.CompileOptions.set_language_version compile_options 
    Metal.CompileOptions.LanguageVersion.version_2_4;
  
  let library = Metal.Library.on_device device ~source:compute_kernel_source compile_options in
  let function_name = "increment_kernel" in
  let compute_function = Metal.Library.new_function_with_name library function_name in
  Printf.printf "Kernel function '%s' compiled\n" function_name;
  
  (* Create pipeline state *)
  let pipeline_state = Metal.ComputePipelineState.on_device device compute_function in
  
  (* First queue operations *)
  let command_buffer1 = Metal.CommandQueue.command_buffer command_queue1 in
  (* FIXME: set_label is not available in the CommandBuffer module *)
  (* Metal.CommandBuffer.set_label command_buffer1 "First Queue Command Buffer"; *)
  
  let compute_encoder1 = Metal.CommandBuffer.compute_command_encoder command_buffer1 in
  Metal.ComputeCommandEncoder.set_label compute_encoder1 "First Compute Encoder";
  Metal.ComputeCommandEncoder.set_compute_pipeline_state compute_encoder1 pipeline_state;
  Metal.ComputeCommandEncoder.set_buffer compute_encoder1 data_buffer 0 0;
  
  (* Setup threadgroup sizes *)
  let thread_execution_width = 
    Unsigned.ULong.to_int (Metal.ComputePipelineState.thread_execution_width pipeline_state) in
  let threads_per_threadgroup = 
    Metal.ComputeCommandEncoder.Size.make ~width:thread_execution_width ~height:1 ~depth:1 in
  let threads_per_grid = 
    Metal.ComputeCommandEncoder.Size.make ~width:array_length ~height:1 ~depth:1 in
  
  (* Dispatch the threads on the first encoder *)
  Metal.ComputeCommandEncoder.dispatch_threads compute_encoder1 ~threads_per_grid ~threads_per_threadgroup;
  
  (* Update fence and signal shared event when this encoder is done *)
  Metal.ComputeCommandEncoder.update_fence compute_encoder1 fence;
  Metal.ComputeCommandEncoder.signal_event compute_encoder1 shared_event signal_value;
  Metal.ComputeCommandEncoder.end_encoding compute_encoder1;
  
  (* Commit the first command buffer *)
  Printf.printf "Committing first command buffer\n";
  Metal.CommandBuffer.commit command_buffer1;
  
  (* Second queue operations - must wait for the first queue *)
  let command_buffer2 = Metal.CommandQueue.command_buffer command_queue2 in
  (* FIXME: set_label is not available in the CommandBuffer module *)
  (* Metal.CommandBuffer.set_label command_buffer2 "Second Queue Command Buffer"; *)
  
  (* Encode a wait for the shared event from the first queue *)
  Metal.CommandBuffer.encode_wait_for_event command_buffer2 shared_event signal_value;
  
  (* Create a blit encoder to synchronize the buffer's memory for CPU visibility *)
  let blit_encoder = Metal.CommandBuffer.blit_command_encoder command_buffer2 in
  Metal.BlitCommandEncoder.set_label blit_encoder "Blit Encoder";
  
  (* Wait for the fence from the first compute encoder *)
  Metal.BlitCommandEncoder.wait_for_fence blit_encoder fence;
  
  (* Synchronize the resource to ensure memory is visible across CPU/GPU boundary *)
  Metal.BlitCommandEncoder.synchronize_resource ~self:blit_encoder ~resource:(Obj.magic data_buffer); 
  Metal.BlitCommandEncoder.end_encoding blit_encoder;
  
  (* Create a second compute encoder for the second queue *)
  let compute_encoder2 = Metal.CommandBuffer.compute_command_encoder command_buffer2 in
  Metal.ComputeCommandEncoder.set_label compute_encoder2 "Second Compute Encoder";
  Metal.ComputeCommandEncoder.set_compute_pipeline_state compute_encoder2 pipeline_state;
  Metal.ComputeCommandEncoder.set_buffer compute_encoder2 data_buffer 0 0;
  
  (* Dispatch the threads on the second encoder *)
  Metal.ComputeCommandEncoder.dispatch_threads compute_encoder2 ~threads_per_grid ~threads_per_threadgroup;
  Metal.ComputeCommandEncoder.end_encoding compute_encoder2;
  
  (* Commit the second command buffer *)
  Printf.printf "Committing second command buffer\n";
  Metal.CommandBuffer.commit command_buffer2;
  
  (* CPU Blocking Synchronization - wait for the second command buffer to complete *)
  Printf.printf "CPU waiting for completion...\n";
  Metal.CommandBuffer.wait_until_completed command_buffer2;
  Printf.printf "GPU work completed\n";
  
  (* Use SharedEvent with timeout for a more flexible CPU sync example *)
  let third_signal_value = Unsigned.ULLong.of_int 3 in
  let command_buffer3 = Metal.CommandQueue.command_buffer command_queue1 in
  let compute_encoder3 = Metal.CommandBuffer.compute_command_encoder command_buffer3 in
  
  (* Setup and run a third compute pass *)
  Metal.ComputeCommandEncoder.set_compute_pipeline_state compute_encoder3 pipeline_state;
  Metal.ComputeCommandEncoder.set_buffer compute_encoder3 data_buffer 0 0;
  Metal.ComputeCommandEncoder.dispatch_threads compute_encoder3 ~threads_per_grid ~threads_per_threadgroup;
  Metal.ComputeCommandEncoder.signal_event compute_encoder3 shared_event third_signal_value;
  Metal.ComputeCommandEncoder.end_encoding compute_encoder3;
  
  Printf.printf "Committing third command buffer\n";
  Metal.CommandBuffer.commit command_buffer3;
  
  (* Wait for the event with timeout *)
  Printf.printf "CPU waiting for event with timeout...\n";
  let timeout_ms = 1000 in (* 1 second timeout *)
  let completed = Metal.SharedEvent.wait_until_signaled_value shared_event third_signal_value ~timeout_ms in
  
  if completed then
    Printf.printf "Event signaled within timeout\n"
  else
    Printf.printf "Timeout elapsed before event was signaled\n";
  
  (* Verify results - buffer should be incremented 3 times, so each value should be 3 *)
  Printf.printf "Verifying results...\n";
  let errors = ref 0 in
  for i = 0 to array_length - 1 do
    let ptr = (coerce (ptr void) (ptr int) buffer_ptr) +@ i in
    let value = !@ptr in
    if value != 3 then begin
      if !errors < 10 then
        Printf.printf "Error at index %d: expected 3, got %d\n" i value;
      incr errors
    end
  done;
  
  if !errors = 0 then
    Printf.printf "Verification successful! All values are 3 as expected.\n"
  else
    Printf.printf "Verification failed with %d errors.\n" !errors;
  
  Printf.printf "Synchronization test completed.\n" 