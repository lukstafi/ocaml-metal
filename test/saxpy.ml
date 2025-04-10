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

let () =
  (* 1. Initialize Metal *)
  let device = Metal.Device.create_system_default () in
  if is_nil device then failwith "Failed to create Metal device";
  Printf.printf "Metal device created successfully.\n";

  let command_queue = Metal.Device.new_command_queue device in
  if is_nil command_queue then failwith "Failed to create command queue";
  Printf.printf "Command queue created successfully.\n";

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
  let buffer_x = Metal.Device.new_buffer_with_length device buffer_size options in
  let buffer_y = Metal.Device.new_buffer_with_length device buffer_size options in
  let buffer_a = Metal.Device.new_buffer_with_length device (sizeof float) options in

  if is_nil buffer_x || is_nil buffer_y || is_nil buffer_a then
    failwith "Failed to create Metal buffers";
  Printf.printf "Metal buffers created successfully.\n";

  (* Copy data to buffers *)
  copy_bigarray_to_buffer x_ba buffer_x;
  copy_bigarray_to_buffer y_ba buffer_y;

  (* Copy scalar 'a' *)
  let a_ptr : unit ptr = Metal.Buffer.contents buffer_a in
  coerce (ptr void) (ptr float) a_ptr <-@ a_val;
  let a_range = Metal.Buffer.NSRange.make ~location:0 ~length:(sizeof float) in
  Metal.Buffer.did_modify_range buffer_a a_range;

  Printf.printf "Data copied to buffers.\n";

  (* 3. Compile the Kernel *)
  (* Create Compile Options *)
  let compile_options = Metal.CompileOptions.init () in
  Metal.CompileOptions.set_language_version compile_options
    Metal.CompileOptions.LanguageVersion.version_2_4;

  (* Allocate a pointer for potential error object (NSError** ) *)
  let error_ptr = allocate Objc.id nil in
  let library : id =
    Metal.Device.new_library_with_source device saxpy_kernel_source compile_options error_ptr
  in

  (* Check error pointer immediately after the call *)
  let check_error label (err_ptr : id ptr) =
    (* Dereference to get the ptr id *)
    assert (not (is_nil err_ptr)); (* Check if the pointer itself is nil *)
    let error_id : id = !@err_ptr in
    (* Dereference the non-nil pointer to get the id *)
    if is_nil error_id then Printf.printf "%s completed successfully (no error object set).\n" label else
    let desc = get_error_description error_id in
      failwith (Printf.sprintf "%s failed: %s" label desc)
  in

  check_error "Library creation" error_ptr;
  (* Also check if the returned library object itself is nil *)
  if is_nil library then failwith "Library creation returned nil without setting an error";

  let function_name = "saxpy_kernel" in
  let saxpy_function = Metal.Library.new_function_with_name library function_name in
  if is_nil saxpy_function then failwith (Printf.sprintf "Failed to get function %s" function_name);
  Printf.printf "Kernel function '%s' obtained.\n" function_name;

  (* 4. Create Pipeline State *)
  (* Reset error pointer before next call *)
  error_ptr <-@ nil;
  (* Assign nil_ptr to the location pointed by error_ptr *)
  let pipeline_state : id =
    Metal.Device.new_compute_pipeline_state_with_function device saxpy_function error_ptr
  in
  check_error "Pipeline state creation" error_ptr;
  (* Also check if the returned pipeline state object itself is nil *)
  if is_nil pipeline_state then
    failwith "Pipeline state creation returned nil without setting an error";

  (* 5. Create Command Buffer and Encoder *)
  let command_buffer = Metal.CommandQueue.command_buffer command_queue in
  if is_nil command_buffer then failwith "Failed to create command buffer";

  let compute_encoder = Metal.CommandBuffer.compute_command_encoder command_buffer in
  if is_nil compute_encoder then failwith "Failed to create compute encoder";
  Printf.printf "Command buffer and encoder created.\n";

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

  Metal.ComputeCommandEncoder.dispatch_threads compute_encoder threads_per_grid
    threads_per_threadgroup;
  Printf.printf "Kernel dispatched.\n";

  (* 8. End Encoding and Commit *)
  Metal.ComputeCommandEncoder.end_encoding compute_encoder;
  Metal.CommandBuffer.commit command_buffer;
  Printf.printf "Command buffer committed.\n";

  (* 9. Wait for Completion *)
  Metal.CommandBuffer.wait_until_completed command_buffer;
  Printf.printf "Computation completed.\n";

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
    if !errors = 0 then Printf.printf "Verification successful!\n"
    else Printf.printf "Verification failed with %d errors.\n" !errors
  in

  verify_results ()
