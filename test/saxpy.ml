open Ctypes
open Bigarray
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
  Metal.Buffer.did_modify_range buffer { location = 0; length = len }

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

  let command_queue = Metal.CommandQueue.on_device device in
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
  let buffer_x = Metal.Buffer.on_device device ~length:buffer_size options in
  let buffer_y = Metal.Buffer.on_device device ~length:buffer_size options in
  let buffer_a = Metal.Buffer.on_device device ~length:(sizeof float) options in
  Printf.printf "Metal buffers created successfully.\n";

  (* Copy data to buffers *)
  copy_bigarray_to_buffer x_ba buffer_x;
  copy_bigarray_to_buffer y_ba buffer_y;

  (* Copy scalar 'a' *)
  let a_ptr : unit ptr = Metal.Buffer.contents buffer_a in
  coerce (ptr void) (ptr float) a_ptr <-@ a_val;
  Metal.Buffer.did_modify_range buffer_a {location = 0; length = sizeof float};

  Printf.printf "Data copied to buffers.\n";

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

  (* 4. Create Pipeline State *)
  (* Assign nil_ptr to the location pointed by error_ptr *)
  let pipeline_state, _ =
    Metal.ComputePipelineState.on_device_with_function device saxpy_function
  in

  (* 5. Create Command Buffer and Encoder *)
  let command_buffer = Metal.CommandBuffer.on_queue command_queue in

  let compute_encoder = Metal.ComputeCommandEncoder.on_buffer command_buffer in
  Printf.printf "Command buffer and encoder created.\n";

  (* 6. Set Up Encoder *)
  Metal.ComputeCommandEncoder.set_compute_pipeline_state compute_encoder pipeline_state;
  Metal.ComputeCommandEncoder.set_buffer compute_encoder buffer_y ~index:0;
  (* y at index 0 *)
  Metal.ComputeCommandEncoder.set_buffer compute_encoder buffer_x ~index:1;
  (* x at index 1 *)
  Metal.ComputeCommandEncoder.set_buffer compute_encoder buffer_a ~index:2;

  (* a at index 2 *)

  (* 7. Dispatch Kernel *)
  let thread_execution_width =
    Metal.ComputePipelineState.get_thread_execution_width pipeline_state
  in

  Metal.ComputeCommandEncoder.dispatch_threadgroups compute_encoder
    ~threadgroups_per_grid:{ width = array_length; height = 1; depth = 1 }
    ~threads_per_threadgroup:{ width = thread_execution_width; height = 1; depth = 1 };
  Printf.printf "Kernel dispatched.\n";

  (* 8. End Encoding and Commit *)
  Metal.ComputeCommandEncoder.end_encoding compute_encoder;
  Metal.CommandBuffer.commit command_buffer;
  Printf.printf "Command buffer committed.\n";

  (* 9. Wait for Completion *)
  Metal.CommandBuffer.wait_until_completed command_buffer;
  Printf.printf "Computation completed.\n";

  (* Check for command buffer errors *)
  let command_buffer_error = Metal.CommandBuffer.get_error command_buffer in
  Option.iter
    (fun error ->
      let desc = Metal.get_error_description error in
      Printf.eprintf "Command buffer error: %s\n" desc)
    command_buffer_error;

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

  let verify_results () =
    let tolerance = 1e-5 in
    let errors = ref 0 in
    for i = 0 to array_length - 1 do
      let expected = (a_val *. float_of_int i) +. float_of_int (array_length - i) in
      let actual = result_ba.{i} in
      if i < 10 || i > array_length - 10 then
        Printf.printf "At index %d: Expected %f, Got %f\n" i expected actual;
      if abs_float (actual -. expected) > tolerance then (
        if !errors < 10 then (* Print first few errors *)
          Printf.printf "Verification failed at index %d: Expected %f, Got %f\n" i expected actual;
        incr errors)
    done;
    if !errors = 0 then Printf.printf "Verification successful!\n"
    else Printf.printf "Verification failed with %d errors.\n" !errors
  in

  verify_results ();
  [%expect {|
    Metal device created successfully.
    Command queue created successfully.
    Metal buffers created successfully.
    Data copied to buffers.
    Kernel function 'saxpy_kernel' obtained.
    Command buffer and encoder created.
    Kernel dispatched.
    Command buffer committed.
    Computation completed.
    Starting verification of results...
    At index 0: Expected 1048576.000000, Got 1048576.000000
    At index 1: Expected 1048577.000000, Got 1048577.000000
    At index 2: Expected 1048578.000000, Got 1048578.000000
    At index 3: Expected 1048579.000000, Got 1048579.000000
    At index 4: Expected 1048580.000000, Got 1048580.000000
    At index 5: Expected 1048581.000000, Got 1048581.000000
    At index 6: Expected 1048582.000000, Got 1048582.000000
    At index 7: Expected 1048583.000000, Got 1048583.000000
    At index 8: Expected 1048584.000000, Got 1048584.000000
    At index 9: Expected 1048585.000000, Got 1048585.000000
    At index 1048567: Expected 2097143.000000, Got 2097143.000000
    At index 1048568: Expected 2097144.000000, Got 2097144.000000
    At index 1048569: Expected 2097145.000000, Got 2097145.000000
    At index 1048570: Expected 2097146.000000, Got 2097146.000000
    At index 1048571: Expected 2097147.000000, Got 2097147.000000
    At index 1048572: Expected 2097148.000000, Got 2097148.000000
    At index 1048573: Expected 2097149.000000, Got 2097149.000000
    At index 1048574: Expected 2097150.000000, Got 2097150.000000
    At index 1048575: Expected 2097151.000000, Got 2097151.000000
    Verification successful!
    |}]
