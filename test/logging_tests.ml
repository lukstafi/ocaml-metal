open Ctypes
open Metal

let%expect_test "Metal shader logging" =
  let device = Device.create_system_default () in
  Printf.printf "Device created successfully\n";
  
  (* Create a simple compute kernel with logging *)
  let buffer_size = 8 in (* 8 floats, 2 threadgroups of 4 *)
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
      if (index < |} ^ string_of_int buffer_size ^ {|) {
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
  LogStateDescriptor.set_buffer_size log_desc (1024 * 100); (* 100KB buffer *)
  
  (* Create log state with the descriptor *)
  let log_state = LogState.on_device_with_descriptor device log_desc in
  
  (* Create mutable reference to store captured logs *)
  let captured_logs = ref [] in
  
  (* Add log handler to process and store log messages *)
  LogState.add_log_handler log_state (fun ~sub_system ~category ~level ~message ->
    let level_str = match level with
      | LogLevel.Debug -> "Debug"
      | LogLevel.Info -> "Info"
      | LogLevel.Notice -> "Notice"
      | LogLevel.Error -> "Error"
      | LogLevel.Fault -> "Fault"
      | LogLevel.Undefined -> "Undefined"
    in
    
    let sub_system_str = match sub_system with
      | Some s -> s
      | None -> "<none>"
    in
    
    let category_str = match category with
      | Some c -> c
      | None -> "<none>"
    in
    
    let log_entry = Printf.sprintf "[%s] %s/%s: %s" 
                      level_str sub_system_str category_str message in
    captured_logs := log_entry :: !captured_logs
  );
  
  (* Create command queue with log state *)
  let queue_desc = CommandQueueDescriptor.create () in
  CommandQueueDescriptor.set_log_state queue_desc (Some log_state);
  let queue = CommandQueue.on_device_with_descriptor device queue_desc in
  
  (* Create buffer for computation *)
  let buffer = Buffer.on_device device ~length:(buffer_size * sizeof float) ResourceOptions.storage_mode_shared in
  
  (* Initialize buffer with values *)
  let contents = Buffer.contents buffer in
  let float_ptr = coerce (ptr void) (ptr float) contents in
  for i = 0 to buffer_size - 1 do
    (float_ptr +@ i) <-@ float_of_int (i + 1);
  done;
  
  (* Create command buffer and encoder *)
  let cmd_buffer = CommandBuffer.on_queue queue in
  let compute_encoder = ComputeCommandEncoder.on_buffer cmd_buffer in
  
  (* Set compute pipeline and buffer *)
  ComputeCommandEncoder.set_compute_pipeline_state compute_encoder pipeline_state;
  ComputeCommandEncoder.set_buffer compute_encoder ~index:0 buffer;
  
  (* Dispatch threads *)
  ComputeCommandEncoder.dispatch_threadgroups compute_encoder 
    ~threadgroups_per_grid:{width=buffer_size / 4; height=1; depth=1} 
    ~threads_per_threadgroup:{width=4; height=1; depth=1};
  
  (* End encoding and commit command buffer *)
  ComputeCommandEncoder.end_encoding compute_encoder;
  CommandBuffer.commit cmd_buffer;
  CommandBuffer.wait_until_completed cmd_buffer;
  
  (* Verify computation worked *)
  for i = 0 to buffer_size - 1 do
    let value = !@(float_ptr +@ i) in
    let expected = float_of_int (i + 1) *. 2.0 in
    Printf.printf "Buffer[%d] = %f (expected %f)\n" i value expected;
  done;
  
  (* Print captured logs (in reverse order to get chronological order) *)
  Printf.printf "\nCaptured shader logs:\n";
  List.rev !captured_logs |> List.iter (Printf.printf "%s\n");
  
  [%expect {|
    Device created successfully
    Buffer[0] = 2.000000 (expected 2.000000)
    Buffer[1] = 4.000000 (expected 4.000000)
    Buffer[2] = 6.000000 (expected 6.000000)
    Buffer[3] = 8.000000 (expected 8.000000)
    Buffer[4] = 10.000000 (expected 10.000000)
    Buffer[5] = 12.000000 (expected 12.000000)
    Buffer[6] = 14.000000 (expected 14.000000)
    Buffer[7] = 16.000000 (expected 16.000000)

    Captured shader logs:
    [Notice] com.custom_log.subsystem/custom category: Thread 0 started processing

    [Notice] com.custom_log.subsystem/custom category: Thread 1 started processing

    [Notice] com.custom_log.subsystem/custom category: Thread 2 started processing

    [Notice] com.custom_log.subsystem/custom category: Thread 3 started processing

    [Notice] com.custom_log.subsystem/custom category: Thread 4 started processing

    [Notice] com.custom_log.subsystem/custom category: Thread 5 started processing

    [Notice] com.custom_log.subsystem/custom category: Thread 6 started processing

    [Notice] com.custom_log.subsystem/custom category: Thread 7 started processing

    [Notice] com.custom_log.subsystem/custom category: Thread 0 calculation complete: 2.000000

    [Notice] com.custom_log.subsystem/custom category: Thread 1 calculation complete: 4.000000

    [Notice] com.custom_log.subsystem/custom category: Thread 2 calculation complete: 6.000000

    [Notice] com.custom_log.subsystem/custom category: Thread 3 calculation complete: 8.000000

    [Notice] com.custom_log.subsystem/custom category: Thread 4 calculation complete: 10.000000

    [Notice] com.custom_log.subsystem/custom category: Thread 5 calculation complete: 12.000000

    [Notice] com.custom_log.subsystem/custom category: Thread 6 calculation complete: 14.000000

    [Notice] com.custom_log.subsystem/custom category: Thread 7 calculation complete: 16.000000
    |}]