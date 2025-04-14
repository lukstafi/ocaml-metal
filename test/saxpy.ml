open Metal
open Ctypes
open Bigarray
open Runtime
open Ctypes_static

(* Helper for memcpy *)
let memcpy = Foreign.foreign "memcpy" (ptr void @-> ptr void @-> size_t @-> returning (ptr void))

(* Helper function to copy Bigarray data to Metal buffer *)
(* Assume Metal.Buffer.t is the type of Metal buffers *)
let copy_bigarray_to_buffer ba (buffer : Metal.Buffer.t) =
  let data_ptr = bigarray_start array1 ba in
  (* Assume Metal.Buffer.contents returns unit ptr *)
  let buffer_ptr : unit ptr = Metal.Buffer.contents buffer in
  let kind = Array1.kind ba in
  let element_size = sizeof (Ctypes.typ_of_bigarray_kind kind) in
  let len = Array1.dim ba * element_size in
  (* Use to_voidp for compatibility with memcpy *)
  ignore (memcpy (to_voidp buffer_ptr) (to_voidp data_ptr) (Unsigned.Size_t.of_int len));
  (* Assume Metal.Buffer.NSRange and Metal.Buffer.did_modify_range exist *)
  let range = Metal.Buffer.NSRange.make ~location:0 ~length:len in
  Metal.Buffer.did_modify_range buffer range

(* Metal Shading Language (MSL) kernel for SAXPY *)
let saxpy_kernel_source =
  "\n\
  \  #include <metal_stdlib>\n\
  \  using namespace metal;\n\n\
  \  kernel void saxpy_kernel(device float *y [[buffer(0)]],\n\
  \                           device const float *x [[buffer(1)]],\n\
  \                           device const float *a [[buffer(2)]],\n\
  \                           uint index [[thread_position_in_grid]]) {\n\
  \    y[index] = (*a) * x[index] + y[index];\n\
  \  }\n"

let%expect_test "SAXPY kernel computation test" =
  (* 1. Initialize Metal *)
  let device = Metal.Device.create_system_default () in
  Printf.printf "Metal device created successfully.\n";
  [%expect {| Metal device created successfully. |}];

  let command_queue = Metal.CommandQueue.on_device device in
  Printf.printf "Command queue created successfully.\n";
  [%expect {| Command queue created successfully. |}];

  (* 2. Prepare Data *)
  let array_length = 1024 * 1024 in
  (* Example size *)
  let buffer_size = array_length * sizeof float in

  (* Create Bigarrays *)
  let x_ba = Array1.create float32 C_layout array_length in
  let y_ba = Array1.create float32 C_layout array_length in
  let a_val = 2.0 in

  (* Initialize data *)
  for i = 0 to array_length - 1 do
    x_ba.{i} <- float_of_int i;
    y_ba.{i} <- float_of_int (array_length - i)
  done;

  (* Define resource options - Using Shared memory for simplicity *)
  let options = Metal.ResourceOptions.storage_mode_shared in

  (* Create Metal buffers *)
  let buffer_x = Metal.Buffer.on_device device ~length:buffer_size options in
  let buffer_y = Metal.Buffer.on_device device ~length:buffer_size options in
  let buffer_a = Metal.Buffer.on_device device ~length:(sizeof float) options in
  Printf.printf "Metal buffers created successfully.\n";
  [%expect {| Metal buffers created successfully. |}];

  (* Copy data to buffers *)
  copy_bigarray_to_buffer x_ba buffer_x;
  copy_bigarray_to_buffer y_ba buffer_y;

  (* Copy scalar 'a' *)
  let a_ptr : unit ptr = Metal.Buffer.contents buffer_a in
  coerce (ptr void) (ptr float) a_ptr <-@ a_val;
  let a_range = Metal.Buffer.NSRange.make ~location:0 ~length:(sizeof float) in
  Metal.Buffer.did_modify_range buffer_a a_range;

  Printf.printf "Data copied to buffers.\n";
  [%expect {| Data copied to buffers. |}];

  (* 3. Compile the Kernel *)
  (* Create Compile Options *)
  let compile_options = Metal.CompileOptions.init () in
  Metal.CompileOptions.set_language_version compile_options
    Metal.CompileOptions.LanguageVersion.version_2_4;

  let library : Metal.Library.t =
    Metal.Library.on_device device ~source:saxpy_kernel_source compile_options
  in

  let function_name = "saxpy_kernel" in
  let saxpy_function = Metal.Library.new_function_with_name library function_name in
  Printf.printf "Kernel function '%s' obtained.\n" function_name;
  [%expect {| Kernel function 'saxpy_kernel' obtained. |}];

  (* 4. Create Pipeline State *)
  (* Assign nil_ptr to the location pointed by error_ptr *)
  let pipeline_state =
    Metal.ComputePipelineState.on_device device saxpy_function
  in

  (* 5. Create Command Buffer and Encoder *)
  let command_buffer = Metal.CommandQueue.command_buffer command_queue in

  let compute_encoder = Metal.CommandBuffer.compute_command_encoder command_buffer in
  Printf.printf "Command buffer and encoder created.\n";
  [%expect {| Command buffer and encoder created. |}];

  (* 6. Set Up Encoder *)
  Metal.ComputeCommandEncoder.set_compute_pipeline_state compute_encoder pipeline_state;
  Metal.ComputeCommandEncoder.set_buffer compute_encoder buffer_y 0 0;
  (* y at index 0 *)
  Metal.ComputeCommandEncoder.set_buffer compute_encoder buffer_x 0 1;
  (* x at index 1 *)
  Metal.ComputeCommandEncoder.set_buffer compute_encoder buffer_a 0 2;

  (* a at index 2 *)

  (* 7. Dispatch Kernel *)
  let thread_execution_width =
    Unsigned.ULong.to_int (Metal.ComputePipelineState.thread_execution_width pipeline_state)
  in
  let threads_per_threadgroup =
    Metal.ComputeCommandEncoder.Size.make ~width:thread_execution_width ~height:1 ~depth:1
  in
  let threads_per_grid =
    Metal.ComputeCommandEncoder.Size.make ~width:array_length ~height:1 ~depth:1
  in

  Metal.ComputeCommandEncoder.dispatch_threads compute_encoder ~threads_per_grid
    ~threads_per_threadgroup;
  Printf.printf "Kernel dispatched.\n";
  [%expect {| Kernel dispatched. |}];

  (* 8. End Encoding and Commit *)
  Metal.ComputeCommandEncoder.end_encoding compute_encoder;
  Metal.CommandBuffer.commit command_buffer;
  Printf.printf "Command buffer committed.\n";
  [%expect {| Command buffer committed. |}];

  (* 9. Wait for Completion *)
  Metal.CommandBuffer.wait_until_completed command_buffer;
  Printf.printf "Computation completed.\n";
  [%expect {| Computation completed. |}];

  (* Check for command buffer errors *)
  let command_buffer_error = Metal.CommandBuffer.error command_buffer in
  (if not (is_nil command_buffer_error) then
     let desc = get_error_description command_buffer_error in
     Printf.eprintf "Command buffer error: %s\n" desc);

  (* 10. Verify Results (Optional but recommended) *)
  (* For shared memory, we might need to ensure CPU/GPU caches are synchronized.
     A blit encoder synchronize step can be added if using managed memory or experiencing issues.
     Since we use Shared and wait_until_completed, the data should be visible. *)
  let result_ptr : unit ptr = Metal.Buffer.contents buffer_y in
  (* Coerce to (ptr float) which corresponds to Bigarray.float32 kind *)
  let result_ba =
    bigarray_of_ptr array1 array_length float32 (coerce (ptr void) (ptr float) result_ptr)
  in

  Printf.printf "Starting verification of results...\n";
  [%expect {| Starting verification of results... |}];
  
  let verify_results () =
    let tolerance = 1e-5 in
    let errors = ref 0 in
    for i = 0 to array_length - 1 do
      let expected = (a_val *. float_of_int i) +. float_of_int (array_length - i) in
      let actual = result_ba.{i} in
      if abs_float (actual -. expected) > tolerance then (
        if !errors < 10 then (* Print first few errors *)
          Printf.printf "Verification failed at index %d: Expected %f, Got %f\n" i expected actual;
        incr errors)
    done;
    if !errors = 0 then 
      Printf.printf "Verification successful!\n"
    else 
      Printf.printf "Verification failed with %d errors.\n" !errors
  in

  verify_results ();
  [%expect {| Verification successful! |}]
