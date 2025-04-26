open Ctypes
open Metal

let _Device_creation_and_attributes =
  let device = Device.create_system_default () in
  Printf.printf "Device created successfully\n";

  let attrs = Device.get_attributes device in
  Printf.printf "Device name: %s\n" attrs.name;
  Printf.printf "Has unified memory: %b\n" attrs.has_unified_memory;
  Printf.printf "Max buffer length: %s\n" (Unsigned.ULong.to_string attrs.max_buffer_length);

  (* Test getting other device properties *)
  ignore (attrs.max_threads_per_threadgroup : Size.t);
  ignore (attrs.registry_id : Unsigned.ULLong.t);
  ()

let _Size_Origin_and_Region_operations =
  (* Test Size module *)
  let size = Size.make ~width:100 ~height:200 ~depth:300 in
  let size_val = Size.from_struct size in
  Printf.printf "Size: width=%d, height=%d, depth=%d\n" size_val.width size_val.height
    size_val.depth;

  (* Test converting back and forth *)
  let size2 = Size.to_value size_val in
  let size_val2 = Size.from_struct size2 in
  Printf.printf "Size conversion preserved: %b\n"
    (size_val.width = size_val2.width
    && size_val.height = size_val2.height
    && size_val.depth = size_val2.depth);

  (* Test Origin module *)
  let origin = Origin.make ~x:10 ~y:20 ~z:30 in
  let origin_val = Origin.from_struct origin in
  Printf.printf "Origin: x=%d, y=%d, z=%d\n" origin_val.x origin_val.y origin_val.z;

  (* Test Region module *)
  let region = Region.make ~x:10 ~y:20 ~z:30 ~width:100 ~height:200 ~depth:300 in
  let region_val = Region.from_struct region in
  Printf.printf "Region: origin=(%d,%d,%d), size=(%d,%d,%d)\n" region_val.origin.x
    region_val.origin.y region_val.origin.z region_val.size.width region_val.size.height
    region_val.size.depth

let _Buffer_creation_and_operations =
  let device = Device.create_system_default () in

  (* Create buffer with various options *)
  let options = ResourceOptions.storage_mode_shared in
  let buffer_size = 1024 in
  let buffer = Buffer.on_device device ~length:buffer_size options in

  (* Test buffer properties *)
  let length = Buffer.length buffer in
  Printf.printf "Buffer length: %d\n" length;
  assert (length = buffer_size);

  (* Test setting and getting buffer contents *)
  let contents = Buffer.contents buffer in
  let float_ptr = coerce (ptr void) (ptr float) contents in
  float_ptr <-@ 42.0;
  (* Buffer.did_modify_range buffer { Range.location = 0; length = sizeof float }; *)

  let contents2 = Buffer.contents buffer in
  let float_ptr2 = coerce (ptr void) (ptr float) contents2 in
  let value = !@float_ptr2 in
  Printf.printf "Buffer value: %f\n" value;
  assert (value = 42.0);

  (* Test buffer labels *)
  Resource.set_label (Buffer.super buffer) "Test buffer";
  let label = Resource.get_label (Buffer.super buffer) in
  Printf.printf "Buffer label: %s\n" label;
  assert (label = "Test buffer")


let _Command_queue_and_buffer_operations =
  let device = Device.create_system_default () in
  let queue = CommandQueue.on_device device in

  (* Test queue labels *)
  CommandQueue.set_label queue "Test queue";
  let label = CommandQueue.get_label queue in
  Printf.printf "Queue label: %s\n" label;

  (* Test command buffer creation and properties *)
  let cmd_buffer = CommandBuffer.on_queue queue in
  CommandBuffer.set_label cmd_buffer "Test command buffer";
  let buffer_label = CommandBuffer.get_label cmd_buffer in
  Printf.printf "Command buffer label: %s\n" buffer_label;

  (* Test command buffer status *)
  let status = CommandBuffer.get_status cmd_buffer in
  Printf.printf "Initial status: %s\n"
    (match status with
    | CommandBuffer.Status.NotEnqueued -> "NotEnqueued"
    | Enqueued -> "Enqueued"
    | Committed -> "Committed"
    | Scheduled -> "Scheduled"
    | Completed -> "Completed"
    | Error -> "Error");

  (* Test command buffer enqueue/commit/wait *)
  CommandBuffer.enqueue cmd_buffer;
  CommandBuffer.commit cmd_buffer;
  CommandBuffer.wait_until_completed cmd_buffer;

  let final_status = CommandBuffer.get_status cmd_buffer in
  Printf.printf "Final status: %s\n"
    (match final_status with
    | CommandBuffer.Status.NotEnqueued -> "NotEnqueued"
    | Enqueued -> "Enqueued"
    | Committed -> "Committed"
    | Scheduled -> "Scheduled"
    | Completed -> "Completed"
    | Error -> "Error");

  (* Check for errors *)
  let error = CommandBuffer.get_error cmd_buffer in
  Printf.printf "Command buffer has error: %b\n" (Option.is_some error)


let _Library_and_function_operations =
  let device = Device.create_system_default () in

  (* Create a simple compute kernel *)
  let kernel_source =
    {|
    #include <metal_stdlib>
    using namespace metal;
    
    kernel void test_kernel(device float *buffer [[buffer(0)]],
                           uint index [[thread_position_in_grid]]) {
      buffer[index] = buffer[index] * 2.0;
    }
  |}
  in

  (* Create compile options *)
  let compile_options = CompileOptions.init () in
  CompileOptions.set_language_version compile_options CompileOptions.LanguageVersion.version_2_4;

  (* Create library *)
  let library = Library.on_device device ~source:kernel_source compile_options in
  Library.set_label library "Test library";
  let lib_label = Library.get_label library in
  Printf.printf "Library label: %s\n" lib_label;

  (* Get function names *)
  let function_names = Library.get_function_names library in
  Printf.printf "Library contains %d functions\n" (Array.length function_names);
  Array.iter (fun name -> Printf.printf "Function: %s\n" name) function_names;

  (* Get and test a function *)
  let func = Library.new_function_with_name library "test_kernel" in
  let func_name = Function.get_name func in
  Printf.printf "Function name: %s\n" func_name;

  let func_type = Function.get_function_type func in
  Printf.printf "Function type: %s\n"
    (match func_type with
    | FunctionType.Kernel -> "Kernel"
    | Vertex -> "Vertex"
    | Fragment -> "Fragment"
    | Visible -> "Visible"
    | Intersection -> "Intersection"
    | Mesh -> "Mesh"
    | Object -> "Object")


let _ComputePipelineState_creation_and_properties =
  let device = Device.create_system_default () in

  (* Create a simple compute kernel *)
  let kernel_source =
    {|
    #include <metal_stdlib>
    using namespace metal;

    kernel void test_kernel(device float *buffer [[buffer(0)]],
                            uint index [[thread_position_in_grid]]) {
      buffer[index] = buffer[index] * 2.0;
    }
  |}
  in

  (* Create library and function *)
  let compile_options = CompileOptions.init () in
  let library = Library.on_device device ~source:kernel_source compile_options in
  let func = Library.new_function_with_name library "test_kernel" in

  (* Create pipeline state using function *)
  let pipeline_state, _ = ComputePipelineState.on_device_with_function device func in

  (* Test pipeline properties *)
  let max_threads = ComputePipelineState.get_max_total_threads_per_threadgroup pipeline_state in
  Printf.printf "Max total threads per threadgroup: %d\n" max_threads;

  let thread_width = ComputePipelineState.get_thread_execution_width pipeline_state in
  Printf.printf "Thread execution width: %d\n" thread_width;

  let mem_length = ComputePipelineState.get_static_threadgroup_memory_length pipeline_state in
  Printf.printf "Static threadgroup memory length: %d\n" mem_length;

  (* Test using descriptor *)
  let descriptor = ComputePipelineDescriptor.create () in
  ComputePipelineDescriptor.set_compute_function descriptor func;
  ComputePipelineDescriptor.set_label descriptor "Test pipeline descriptor";

  let label = ComputePipelineDescriptor.get_label descriptor in
  Printf.printf "Pipeline descriptor label: %s\n" label;

  (* Create pipeline from descriptor *)
  let pipeline_state2, _ = ComputePipelineState.on_device_with_descriptor device descriptor in
  let thread_width2 = ComputePipelineState.get_thread_execution_width pipeline_state2 in
  Printf.printf "Second pipeline thread width: %d\n" thread_width2

let _ResourceOptions_and_other_option_types =
  (* Test ResourceOptions combinations *)
  let options1 = ResourceOptions.storage_mode_shared in
  let options2 = ResourceOptions.(storage_mode_shared + cpu_cache_mode_write_combined) in
  let options3 =
    ResourceOptions.make ~storage_mode:ResourceOptions.storage_mode_private
      ~cpu_cache_mode:ResourceOptions.cpu_cache_mode_default_cache
      ~hazard_tracking_mode:ResourceOptions.hazard_tracking_mode_tracked ()
  in

  Printf.printf "Options created successfully\n";

  (* Use options by creating buffers with them and checking properties *)
  let device = Device.create_system_default () in
  let buffer1 = Buffer.on_device device ~length:1024 options1 in
  let buffer2 = Buffer.on_device device ~length:1024 options2 in
  let buffer3 = Buffer.on_device device ~length:1024 options3 in

  let storage_mode1 = Resource.get_storage_mode (Buffer.super buffer1) in
  Printf.printf "Buffer1 storage mode: %s\n"
    (match storage_mode1 with
    | Resource.StorageMode.Shared -> "Shared"
    | Managed -> "Managed"
    | Private -> "Private"
    | Memoryless -> "Memoryless");

  let cache_mode2 = Resource.get_cpu_cache_mode (Buffer.super buffer2) in
  Printf.printf "Buffer2 CPU cache mode: %s\n"
    (match cache_mode2 with
    | Resource.CPUCacheMode.DefaultCache -> "DefaultCache"
    | WriteCombined -> "WriteCombined");

  let storage_mode3 = Resource.get_storage_mode (Buffer.super buffer3) in
  Printf.printf "Buffer3 storage mode: %s\n"
    (match storage_mode3 with
    | Resource.StorageMode.Shared -> "Shared"
    | Managed -> "Managed"
    | Private -> "Private"
    | Memoryless -> "Memoryless");

  (* Test PipelineOption combinations *)
  let pipe_opt1 = PipelineOption.none in
  let pipe_opt2 = PipelineOption.(argument_info + buffer_type_info) in

  (* Use PipelineOption values by creating pipeline with them *)
  let kernel_source =
    {|
    #include <metal_stdlib>
    using namespace metal;

    kernel void simple_kernel(device float *buffer [[buffer(0)]],
                             uint index [[thread_position_in_grid]]) {
      buffer[index] = buffer[index] * 2.0;
    }
  |}
  in

  let compile_opts = CompileOptions.init () in
  CompileOptions.set_fast_math_enabled compile_opts true;
  let fast_math = CompileOptions.get_fast_math_enabled compile_opts in
  Printf.printf "Fast math enabled: %b\n" fast_math;

  CompileOptions.set_language_version compile_opts CompileOptions.LanguageVersion.version_2_4;
  let lang_version = CompileOptions.get_language_version compile_opts in
  Printf.printf "Language version: %s\n"
    (if lang_version = CompileOptions.LanguageVersion.version_2_4 then "2.4" else "unknown");

  CompileOptions.set_optimization_level compile_opts CompileOptions.OptimizationLevel.performance;
  let opt_level = CompileOptions.get_optimization_level compile_opts in
  Printf.printf "Optimization level: %s\n"
    (if
       Unsigned.ULong.compare
         (CompileOptions.OptimizationLevel.to_ulong opt_level)
         (CompileOptions.OptimizationLevel.to_ulong CompileOptions.OptimizationLevel.performance)
       = 0
     then "Performance"
     else "Not Performance");

  (* Create library and test pipeline with options *)
  try
    let library = Library.on_device device ~source:kernel_source compile_opts in
    let func = Library.new_function_with_name library "simple_kernel" in

    (* Try creating pipeline with different options *)
    let _, reflection1 =
      ComputePipelineState.on_device_with_function device ~options:pipe_opt1 ~reflection:true func
    in
    Printf.printf "Pipeline created with option1, has reflection: %b\n" (not (is_null reflection1));

    let _, reflection2 =
      ComputePipelineState.on_device_with_function device ~options:pipe_opt2 ~reflection:true func
    in
    Printf.printf "Pipeline created with option2, has reflection: %b\n" (not (is_null reflection2))
  with Failure msg ->
    Printf.printf "Note: Pipeline creation test skipped due to: %s\n"
      (if String.length msg > 50 then String.sub msg 0 50 ^ "..." else msg)
