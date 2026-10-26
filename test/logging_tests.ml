open Ctypes
open Metal

let test_metal_shader_logging device =
  Printf.printf "Device created successfully\n";

  (* Create a simple compute kernel with logging *)
  let buffer_size = 8 in
  (* 8 floats, 2 threadgroups of 4 *)
  let kernel_source =
    {|
    #include <metal_stdlib>
    #include <metal_logging>
    using namespace metal;
    constant os_log custom_log("com.custom_log.subsystem", "custom category");
    
    kernel void logging_test_kernel(device float *buffer [[buffer(0)]],
                           uint index [[thread_position_in_grid]]) {
      // Add some Metal shader logging statements
      custom_log.log("Thread %u started processing\n", index);
      // os_log_default.log("Thread %u started processing\n", index);
      if (index < |}
    ^ string_of_int buffer_size
    ^ {|) {
        buffer[index] = buffer[index] * 2.0;
        custom_log.log("Thread %u calculation complete: %f\n", index, buffer[index]);
        // os_log_default.log("Thread %u calculation complete: %f\n", index, buffer[index]);
      }
    }
  |}
  in

  (* Create compile options with logging enabled *)
  let compile_options = CompileOptions.init () in
  CompileOptions.set_language_version compile_options CompileOptions.LanguageVersion.version_3_2;
  CompileOptions.set_enable_logging compile_options true;

  (* Create library and get the function *)
  let library = Library.on_device device ~source:kernel_source compile_options in
  let func = Library.new_function_with_name library "logging_test_kernel" in

  (* Create pipeline state *)
  let pipeline_state, _ = ComputePipelineState.on_device_with_function device func in

  (* Setup shader logging *)
  let log_desc = LogStateDescriptor.create () in
  LogStateDescriptor.set_level log_desc LogLevel.Debug;
  LogStateDescriptor.set_buffer_size log_desc (1024 * 100);

  (* 100KB buffer *)

  (* Create log state with the descriptor *)
  let log_state = LogState.on_device_with_descriptor device log_desc in

  (* Capture log messages C-side: Metal calls log handlers on its own threads, so the handler
     must not run OCaml code; the host drains the buffer after the command buffer completes. *)
  let log_buffer = LogState.add_buffered_log_handler log_state in
  let format_entry { LogState.sub_system; category; level; message } =
    let level_str =
      match level with
      | LogLevel.Debug -> "Debug"
      | LogLevel.Info -> "Info"
      | LogLevel.Notice -> "Notice"
      | LogLevel.Error -> "Error"
      | LogLevel.Fault -> "Fault"
      | LogLevel.Undefined -> "Undefined"
    in
    let sub_system_str = match sub_system with Some s -> s | None -> "<none>" in
    let category_str = match category with Some c -> c | None -> "<none>" in
    Printf.sprintf "[%s] %s/%s: %s" level_str sub_system_str category_str message
  in

  (* Create command queue with log state *)
  let queue_desc = CommandQueueDescriptor.create () in
  CommandQueueDescriptor.set_log_state queue_desc (Some log_state);
  let queue = CommandQueue.on_device_with_descriptor device queue_desc in

  (* Create buffer for computation *)
  let buffer =
    Buffer.on_device device ~length:(buffer_size * sizeof float) ResourceOptions.storage_mode_shared
  in

  (* Initialize buffer with values *)
  let contents = Buffer.contents buffer in
  let float_ptr = coerce (ptr void) (ptr float) contents in
  for i = 0 to buffer_size - 1 do
    float_ptr +@ i <-@ float_of_int (i + 1)
  done;

  (* Create command buffer and encoder *)
  let cmd_buffer = CommandBuffer.on_queue queue in
  let compute_encoder = ComputeCommandEncoder.on_buffer cmd_buffer in

  (* Set compute pipeline and buffer *)
  ComputeCommandEncoder.set_compute_pipeline_state compute_encoder pipeline_state;
  ComputeCommandEncoder.set_buffer compute_encoder ~index:0 buffer;

  (* Dispatch threads *)
  ComputeCommandEncoder.dispatch_threadgroups compute_encoder
    ~threadgroups_per_grid:{ width = buffer_size / 4; height = 1; depth = 1 }
    ~threads_per_threadgroup:{ width = 4; height = 1; depth = 1 };

  (* End encoding and commit command buffer *)
  ComputeCommandEncoder.end_encoding compute_encoder;
  CommandBuffer.commit cmd_buffer;
  CommandBuffer.wait_until_completed cmd_buffer;

  (* Verify computation worked *)
  for i = 0 to buffer_size - 1 do
    let value = !@(float_ptr +@ i) in
    let expected = float_of_int (i + 1) *. 2.0 in
    Printf.printf "Buffer[%d] = %f (expected %f)\n" i value expected
  done;

  (* Print captured logs, in delivery order *)
  let entries, dropped = LogState.drain_log_buffer log_buffer in
  Printf.printf "\nCaptured shader logs:\n";
  List.iter (fun e -> Printf.printf "%s\n" (format_entry e)) entries;
  Printf.printf "Dropped: %d\n" dropped;
  (* A second drain finds nothing: the first one took every message. *)
  let again, _ = LogState.drain_log_buffer log_buffer in
  Printf.printf "Second drain: %d messages\n" (List.length again);
  (* Further rounds, each after a full major GC and allocation churn: the handler Metal holds must
     not depend on anything the OCaml GC can reclaim. Each round's every message is in the drain
     that follows its command buffer's completion. *)
  let expected = 2 * buffer_size in
  let rounds = 20 in
  let complete = ref 0 in
  for _ = 1 to rounds do
    Gc.full_major ();
    ignore (Sys.opaque_identity (List.init 100_000 (fun i -> Bytes.create (i mod 64))));
    Gc.compact ();
    let cmd_buffer = CommandBuffer.on_queue queue in
    let compute_encoder = ComputeCommandEncoder.on_buffer cmd_buffer in
    ComputeCommandEncoder.set_compute_pipeline_state compute_encoder pipeline_state;
    ComputeCommandEncoder.set_buffer compute_encoder ~index:0 buffer;
    ComputeCommandEncoder.dispatch_threadgroups compute_encoder
      ~threadgroups_per_grid:{ width = buffer_size / 4; height = 1; depth = 1 }
      ~threads_per_threadgroup:{ width = 4; height = 1; depth = 1 };
    ComputeCommandEncoder.end_encoding compute_encoder;
    CommandBuffer.commit cmd_buffer;
    CommandBuffer.wait_until_completed cmd_buffer;
    let entries, dropped = LogState.drain_log_buffer log_buffer in
    if List.length entries = expected && dropped = 0 then incr complete
    else
      Printf.eprintf "round delivered %d of %d messages, %d dropped\n%!" (List.length entries)
        expected dropped
  done;
  Printf.printf "Rounds after GC churn with all %d messages drained at completion: %d of %d\n"
    expected !complete rounds

let () =
  let device = Device.create_system_default () in
  let attrs = Device.get_attributes device in
  if String.ends_with ~suffix:"virtual device" attrs.name then (
    Printf.printf "Device does not support logging\n";
    exit 0);
  test_metal_shader_logging device
