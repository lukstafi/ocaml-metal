open Ctypes
open Metal

let _Blit_encoder_operations =
  let device = Device.create_system_default () in
  let queue = CommandQueue.on_device device in

  (* Create source and destination buffers *)
  let options = ResourceOptions.storage_mode_shared in
  let buffer_size = 40 in
  (* 10 floats *)

  let source_buffer = Buffer.on_device device ~length:buffer_size options in
  let dest_buffer = Buffer.on_device device ~length:buffer_size options in

  (* Fill source buffer with data *)
  let src_ptr = Buffer.contents source_buffer |> coerce (ptr void) (ptr float) in
  for i = 0 to 9 do
    src_ptr +@ i <-@ float_of_int (i * 10)
  done;

  (* Buffer.did_modify_range source_buffer { Range.location = 0; length = buffer_size }; *)

  (* Create command buffer and blit encoder *)
  let cmd_buffer = CommandBuffer.on_queue queue in
  let blit_encoder = BlitCommandEncoder.on_buffer cmd_buffer in
  BlitCommandEncoder.set_label blit_encoder "Test blit encoder";

  (* Copy from source to destination *)
  BlitCommandEncoder.copy_from_buffer blit_encoder ~source_buffer ~source_offset:0
    ~destination_buffer:dest_buffer ~destination_offset:0 ~size:buffer_size;

  (* End encoding and commit *)
  BlitCommandEncoder.end_encoding blit_encoder;
  CommandBuffer.commit cmd_buffer;
  CommandBuffer.wait_until_completed cmd_buffer;

  (* Verify the destination buffer *)
  let dest_ptr = Buffer.contents dest_buffer |> coerce (ptr void) (ptr float) in
  for i = 0 to 9 do
    let value = !@(dest_ptr +@ i) in
    Printf.printf "Dest buffer[%d] = %g\n%!" i value
  done

let _Blit_fill_operations =
  Printf.printf "Starting Blit_fill_operations test\n%!";
  let device = Device.create_system_default () in
  Printf.printf "Created device: %s\n%!" (Device.sexp_of_t device |> Sexplib0.Sexp.to_string);
  let queue = CommandQueue.on_device device in
  Printf.printf "Created command queue\n%!";

  (* Create a buffer to fill *)
  Printf.printf "Creating buffer...\n%!";
  let options = ResourceOptions.storage_mode_shared in
  let buffer_size = 16 in
  let buffer = Buffer.on_device device ~length:buffer_size options in
  Printf.printf "Created buffer with size: %d\n%!" buffer_size;

  (* Create command buffer and blit encoder *)
  Printf.printf "Creating command buffer...\n%!";
  let cmd_buffer = CommandBuffer.on_queue queue in
  Printf.printf "Created command buffer\n%!";
  Printf.printf "Creating blit encoder...\n%!";
  let blit_encoder = BlitCommandEncoder.on_buffer cmd_buffer in
  Printf.printf "Created blit encoder\n%!";

  (* --- DEBUG: Check initial contents --- *)
  Printf.printf "--- Checking buffer contents BEFORE fill ---\n%!";
  let initial_ptr = Buffer.contents buffer |> coerce (ptr void) (ptr uint8_t) in
  for i = 0 to 15 do
    let value = !@(initial_ptr +@ i) in
    Printf.printf "initial_buffer[%d] = %d\n%!" i (Unsigned.UInt8.to_int value)
  done;
  Printf.printf "--- End initial check ---\n%!";

  (* --- END DEBUG --- *)
  Printf.printf "Preparing to fill buffer with value 42...\n%!";
  BlitCommandEncoder.fill_buffer blit_encoder buffer
    { Range.location = 0; length = buffer_size }
    ~value:42;
  (* Changed value for testing *)
  Printf.printf "Fill buffer command encoded\n%!";

  (* End encoding and commit *)
  Printf.printf "Ending blit encoder...\n%!";
  BlitCommandEncoder.end_encoding blit_encoder;
  Printf.printf "Blit encoder ended\n%!";

  Printf.printf "Committing command buffer...\n%!";
  CommandBuffer.commit cmd_buffer;
  Printf.printf "Command buffer committed\n%!";

  Printf.printf "Waiting for command buffer to complete...\n%!";
  CommandBuffer.wait_until_completed cmd_buffer;
  Printf.printf "Command buffer completed\n%!";

  (* --- DEBUG: Check for command buffer errors --- *)
  (match CommandBuffer.get_error cmd_buffer with
  | None -> Printf.printf "--- Command buffer completed without error ---\n%!"
  | Some err_desc -> Printf.printf "--- Command buffer completed WITH ERROR: %s ---\n%!" err_desc);

  (* --- END DEBUG --- *)

  (* Verify the buffer contents *)
  Printf.printf "--- Checking buffer contents AFTER fill ---\n%!";
  let ptr = Buffer.contents buffer |> coerce (ptr void) (ptr uint8_t) in
  for i = 0 to 15 do
    let value = !@(ptr +@ i) in
    Printf.printf "buffer[%d] = %d\n%!" i (Unsigned.UInt8.to_int value)
  done;
  Printf.printf "--- End final check ---\n%!";
  Printf.printf "Blit_fill_operations test completed successfully\n%!"

let _Event_synchronization =
  let device = Device.create_system_default () in
  let queue = CommandQueue.on_device device in

  (* Create shared event *)
  let event = SharedEvent.on_device device in
  SharedEvent.set_label event "Test shared event";

  (* Set initial value *)
  let initial_value = Unsigned.ULLong.of_int 0 in
  SharedEvent.set_signaled_value event initial_value;
  let current_value = SharedEvent.get_signaled_value event in
  Printf.printf "Initial event value: %s\n%!" (Unsigned.ULLong.to_string current_value);

  (* Create command buffer that signals the event *)
  let cmd_buffer1 = CommandBuffer.on_queue queue in
  CommandBuffer.set_label cmd_buffer1 "Event signal buffer";

  (* Signal the event at the end of the command buffer *)
  let signal_value = Unsigned.ULLong.of_int 1 in
  CommandBuffer.encode_signal_event cmd_buffer1 (SharedEvent.super event) signal_value;

  (* Create a second command buffer that waits for the event *)
  let cmd_buffer2 = CommandBuffer.on_queue queue in
  CommandBuffer.set_label cmd_buffer2 "Event wait buffer";
  CommandBuffer.encode_wait_for_event cmd_buffer2 (SharedEvent.super event) signal_value;

  (* Commit the signal buffer first *)
  CommandBuffer.commit cmd_buffer1;

  (* Commit the wait buffer *)
  CommandBuffer.commit cmd_buffer2;

  (* Wait for both to complete *)
  CommandBuffer.wait_until_completed cmd_buffer2;

  (* Check the final event value *)
  let final_value = SharedEvent.get_signaled_value event in
  Printf.printf "Final event value: %s\n%!" (Unsigned.ULLong.to_string final_value)

let _Fence_synchronization_in_blit_encoder =
  let device = Device.create_system_default () in
  let queue = CommandQueue.on_device device in

  (* Create a fence *)
  let fence = Fence.on_device device in
  Fence.set_label fence "Test fence";

  (* Create source and destination buffers *)
  let options = ResourceOptions.storage_mode_shared in
  let buffer_size = 16 in

  let source_buffer = Buffer.on_device device ~length:buffer_size options in
  let dest_buffer = Buffer.on_device device ~length:buffer_size options in

  (* Fill source buffer with data *)
  let src_ptr = Buffer.contents source_buffer |> coerce (ptr void) (ptr uint8_t) in
  for i = 0 to 15 do
    src_ptr +@ i <-@ Unsigned.UInt8.of_int i
  done;

  (* Buffer.did_modify_range source_buffer { Range.location = 0; length = buffer_size }; *)

  (* Create command buffer *)
  let cmd_buffer = CommandBuffer.on_queue queue in

  (* Create first blit encoder that updates the fence *)
  let blit_encoder1 = BlitCommandEncoder.on_buffer cmd_buffer in
  BlitCommandEncoder.copy_from_buffer blit_encoder1 ~source_buffer ~source_offset:0
    ~destination_buffer:dest_buffer ~destination_offset:0 ~size:8;
  (* Copy only the first half *)
  BlitCommandEncoder.update_fence blit_encoder1 fence;
  BlitCommandEncoder.end_encoding blit_encoder1;

  (* Create second blit encoder that waits on the fence *)
  let blit_encoder2 = BlitCommandEncoder.on_buffer cmd_buffer in
  BlitCommandEncoder.wait_for_fence blit_encoder2 fence;
  BlitCommandEncoder.copy_from_buffer blit_encoder2 ~source_buffer ~source_offset:8
    ~destination_buffer:dest_buffer ~destination_offset:8 ~size:8;
  (* Copy the second half *)
  BlitCommandEncoder.end_encoding blit_encoder2;

  (* Commit and wait *)
  CommandBuffer.commit cmd_buffer;
  CommandBuffer.wait_until_completed cmd_buffer;

  (* Verify the buffer contents *)
  let dest_ptr = Buffer.contents dest_buffer |> coerce (ptr void) (ptr uint8_t) in
  for i = 0 to 15 do
    let value = !@(dest_ptr +@ i) in
    Printf.printf "dest_buffer[%d] = %d\n%!" i (Unsigned.UInt8.to_int value)
  done

let _Indirect_command_buffer_basics =
  let device = Device.create_system_default () in
  Printf.printf "Created device: %s\n%!" (Device.sexp_of_t device |> Sexplib0.Sexp.to_string);

  (* Skip if device doesn't support indirect command buffers *)
  let pipeline_desc = ComputePipelineDescriptor.create () in
  Printf.printf "Created pipeline descriptor\n%!";
  ComputePipelineDescriptor.set_support_indirect_command_buffers pipeline_desc true;
  Printf.printf "Set support for indirect command buffers\n%!";

  (* Create kernel *)
  let kernel_source =
    {|
    #include <metal_stdlib>
    using namespace metal;

    kernel void double_values(device float *buffer [[buffer(0)]],
                              uint index [[thread_position_in_grid]]) {
      buffer[index] = buffer[index] * 2.0;
    }
  |}
  in
  Printf.printf "Defined kernel source\n%!";

  let compile_options = CompileOptions.init () in
  Printf.printf "Created compile options\n%!";

  Printf.printf "Attempting to create library...\n%!";
  let library = Library.on_device device ~source:kernel_source compile_options in
  Printf.printf "Created library\n%!";

  Printf.printf "Attempting to get function from library...\n%!";
  let func = Library.new_function_with_name library "double_values" in
  Printf.printf "Got function from library\n%!";

  Printf.printf "Setting compute function on pipeline descriptor\n%!";
  ComputePipelineDescriptor.set_compute_function pipeline_desc func;
  Format.printf "Pipeline descriptor: %a\n%!" Sexplib0.Sexp.pp_hum
    (ComputePipelineDescriptor.sexp_of_t pipeline_desc);

  (* Create compute pipeline state *)
  Printf.printf "Attempting to create pipeline state...\n%!";
  let pipeline_state, _ = ComputePipelineState.on_device_with_descriptor device pipeline_desc in
  Printf.printf "Checking if pipeline supports ICB...\n%!";
  let supports_icb = ComputePipelineState.get_support_indirect_command_buffers pipeline_state in
  Printf.printf "Pipeline supports indirect command buffers: %b\n%!" supports_icb;

  if supports_icb then (
    (* Create ICB descriptor *)
    Printf.printf "Creating ICB descriptor...\n%!";
    let icb_desc = IndirectCommandBufferDescriptor.create () in
    IndirectCommandBufferDescriptor.set_command_types icb_desc
      IndirectCommandType.concurrent_dispatch;
    IndirectCommandBufferDescriptor.set_inherit_pipeline_state icb_desc false;
    IndirectCommandBufferDescriptor.set_max_kernel_buffer_bind_count icb_desc 1;
    Printf.printf "ICB descriptor created and configured\n%!";

    (* Create indirect command buffer *)
    Printf.printf "Creating indirect command buffer...\n%!";
    let icb =
      (* NOTE: storage_mode_shared fails on CI machines (paravirtual devices) *)
      IndirectCommandBuffer.on_device_with_descriptor device icb_desc ~max_command_count:1
        ~options:ResourceOptions.storage_mode_private
    in
    Printf.printf "Indirect command buffer created\n%!";

    (* Get indirect compute command *)
    Printf.printf "Getting indirect compute command...\n%!";
    let cmd = IndirectCommandBuffer.indirect_compute_command_at_index icb 0 in
    Printf.printf "Got indirect compute command\n%!";

    (* Set up the command *)
    Printf.printf "Setting compute pipeline state on command...\n%!";
    IndirectComputeCommand.set_compute_pipeline_state cmd pipeline_state;
    Printf.printf "Pipeline state set on command\n%!";

    (* Create data buffer *)
    Printf.printf "Creating data buffer...\n%!";
    let buffer_size = 16 in
    (* 4 floats *)
    let buffer = Buffer.on_device device ~length:buffer_size ResourceOptions.storage_mode_shared in
    Printf.printf "Data buffer created\n%!";

    (* Initialize buffer *)
    Printf.printf "Initializing buffer contents...\n%!";
    let ptr = Buffer.contents buffer |> coerce (ptr void) (ptr float) in
    for i = 0 to 3 do
      ptr +@ i <-@ float_of_int (i + 1)
    done;
    (* Buffer.did_modify_range buffer { Range.location = 0; length = buffer_size }; *)
    Printf.printf "Buffer initialized\n%!";

    (* Set buffer in command *)
    Printf.printf "Setting kernel buffer on command...\n%!";
    IndirectComputeCommand.set_kernel_buffer cmd ~index:0 buffer;
    Printf.printf "Kernel buffer set on command\n%!";

    (* Set dispatch dimensions *)
    Printf.printf "Setting dispatch dimensions...\n%!";
    IndirectComputeCommand.concurrent_dispatch_threadgroups cmd
      ~threadgroups_per_grid:{ Size.width = 4; height = 1; depth = 1 }
      ~threads_per_threadgroup:{ Size.width = 1; height = 1; depth = 1 };
    Printf.printf "Dispatch dimensions set\n%!";

    (* Create command buffer and encoder *)
    Printf.printf "Creating command queue...\n%!";
    let queue = CommandQueue.on_device device in
    Printf.printf "Creating command buffer...\n%!";
    let cmd_buffer = CommandBuffer.on_queue queue in
    Printf.printf "Creating compute encoder...\n%!";
    let compute_encoder = ComputeCommandEncoder.on_buffer cmd_buffer in
    Printf.printf "Command buffer and encoder created\n%!";

    (* Execute the indirect command buffer *)
    Printf.printf "Executing commands in buffer...\n%!";
    ComputeCommandEncoder.execute_commands_in_buffer compute_encoder icb
      { Range.location = 0; length = 1 };
    Printf.printf "Commands executed\n%!";

    (* End encoding and commit *)
    Printf.printf "Ending encoding...\n%!";
    ComputeCommandEncoder.end_encoding compute_encoder;
    Printf.printf "Committing command buffer...\n%!";
    CommandBuffer.commit cmd_buffer;
    Printf.printf "Waiting for command buffer to complete...\n%!";
    CommandBuffer.wait_until_completed cmd_buffer;
    Printf.printf "Command buffer completed\n%!";

    (* Verify results *)
    Printf.printf "Verifying results...\n%!";
    for i = 0 to 3 do
      let value = !@(ptr +@ i) in
      Printf.printf "buffer[%d] = %g\n%!" i value
    done;
    Printf.printf "Verification complete\n%!")
  else Printf.printf "Skipping ICB test as device doesn't support it\n%!"
