open Ctypes
open Metal

let%expect_test "Blit encoder operations" =
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
    Printf.printf "Dest buffer[%d] = %g\n" i value
  done;
  [%expect
    {|
    Dest buffer[0] = 0
    Dest buffer[1] = 10
    Dest buffer[2] = 20
    Dest buffer[3] = 30
    Dest buffer[4] = 40
    Dest buffer[5] = 50
    Dest buffer[6] = 60
    Dest buffer[7] = 70
    Dest buffer[8] = 80
    Dest buffer[9] = 90
  |}]

let%expect_test "Blit fill operations" =
  let device = Device.create_system_default () in
  let queue = CommandQueue.on_device device in

  (* Create a buffer to fill *)
  let options = ResourceOptions.storage_mode_shared in
  let buffer_size = 16 in
  let buffer = Buffer.on_device device ~length:buffer_size options in

  (* Create command buffer and blit encoder *)
  let cmd_buffer = CommandBuffer.on_queue queue in
  let blit_encoder = BlitCommandEncoder.on_buffer cmd_buffer in

  (* Fill the buffer with a value (42) *)
  BlitCommandEncoder.fill_buffer blit_encoder buffer
    { Range.location = 0; length = buffer_size }
    ~value:42;

  (* End encoding and commit *)
  BlitCommandEncoder.end_encoding blit_encoder;
  CommandBuffer.commit cmd_buffer;
  CommandBuffer.wait_until_completed cmd_buffer;

  (* Verify the buffer contents *)
  let ptr = Buffer.contents buffer |> coerce (ptr void) (ptr uint8_t) in
  for i = 0 to 15 do
    let value = !@(ptr +@ i) in
    Printf.printf "buffer[%d] = %d\n" i (Unsigned.UInt8.to_int value)
  done;
  [%expect
    {|
    buffer[0] = 42
    buffer[1] = 42
    buffer[2] = 42
    buffer[3] = 42
    buffer[4] = 42
    buffer[5] = 42
    buffer[6] = 42
    buffer[7] = 42
    buffer[8] = 42
    buffer[9] = 42
    buffer[10] = 42
    buffer[11] = 42
    buffer[12] = 42
    buffer[13] = 42
    buffer[14] = 42
    buffer[15] = 42
  |}]

let%expect_test "Event synchronization" =
  let device = Device.create_system_default () in
  let queue = CommandQueue.on_device device in

  (* Create shared event *)
  let event = SharedEvent.on_device device in
  SharedEvent.set_label event "Test shared event";

  (* Set initial value *)
  let initial_value = Unsigned.ULLong.of_int 0 in
  SharedEvent.set_signaled_value event initial_value;
  let current_value = SharedEvent.get_signaled_value event in
  Printf.printf "Initial event value: %s\n" (Unsigned.ULLong.to_string current_value);

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
  Printf.printf "Final event value: %s\n" (Unsigned.ULLong.to_string final_value);
  [%expect {|
    Initial event value: 0
    Final event value: 1
  |}]

let%expect_test "Fence synchronization in blit encoder" =
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
    Printf.printf "dest_buffer[%d] = %d\n" i (Unsigned.UInt8.to_int value)
  done;
  [%expect
    {|
    dest_buffer[0] = 0
    dest_buffer[1] = 1
    dest_buffer[2] = 2
    dest_buffer[3] = 3
    dest_buffer[4] = 4
    dest_buffer[5] = 5
    dest_buffer[6] = 6
    dest_buffer[7] = 7
    dest_buffer[8] = 8
    dest_buffer[9] = 9
    dest_buffer[10] = 10
    dest_buffer[11] = 11
    dest_buffer[12] = 12
    dest_buffer[13] = 13
    dest_buffer[14] = 14
    dest_buffer[15] = 15
  |}]

let%expect_test "Indirect command buffer basics" =
  let device = Device.create_system_default () in

  (* Skip if device doesn't support indirect command buffers *)
  let pipeline_desc = ComputePipelineDescriptor.create () in
  ComputePipelineDescriptor.set_support_indirect_command_buffers pipeline_desc true;

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

  let compile_options = CompileOptions.init () in
  let library = Library.on_device device ~source:kernel_source compile_options in
  let func = Library.new_function_with_name library "double_values" in
  ComputePipelineDescriptor.set_compute_function pipeline_desc func;
  (* Log pipeline descriptor via sexp conversion *)
  Format.printf "Pipeline descriptor: %a\n%!" Sexplib0.Sexp.pp_hum (ComputePipelineDescriptor.sexp_of_t pipeline_desc);

  (* Create compute pipeline state *)
  let pipeline_state, _ =
    ComputePipelineState.on_device_with_descriptor device pipeline_desc
  in

  let supports_icb = ComputePipelineState.get_support_indirect_command_buffers pipeline_state in
  Printf.printf "Pipeline supports indirect command buffers: %b\n" supports_icb;

  if supports_icb then (
    (* Create ICB descriptor *)
    let icb_desc = IndirectCommandBufferDescriptor.create () in
    IndirectCommandBufferDescriptor.set_command_types icb_desc
      IndirectCommandType.concurrent_dispatch;
    IndirectCommandBufferDescriptor.set_inherit_pipeline_state icb_desc false;
    IndirectCommandBufferDescriptor.set_max_kernel_buffer_bind_count icb_desc 1;

    (* Create indirect command buffer *)
    let icb =
      IndirectCommandBuffer.on_device_with_descriptor device icb_desc ~max_command_count:1
        ~options:ResourceOptions.storage_mode_shared
    in

    (* Get indirect compute command *)
    let cmd = IndirectCommandBuffer.indirect_compute_command_at_index icb 0 in

    (* Set up the command *)
    IndirectComputeCommand.set_compute_pipeline_state cmd pipeline_state;

    (* Create data buffer *)
    let buffer_size = 16 in
    (* 4 floats *)
    let buffer = Buffer.on_device device ~length:buffer_size ResourceOptions.storage_mode_shared in

    (* Initialize buffer *)
    let ptr = Buffer.contents buffer |> coerce (ptr void) (ptr float) in
    for i = 0 to 3 do
      ptr +@ i <-@ float_of_int (i + 1)
    done;
    (* Buffer.did_modify_range buffer { Range.location = 0; length = buffer_size }; *)

    (* Set buffer in command *)
    IndirectComputeCommand.set_kernel_buffer cmd ~index:0 buffer;

    (* Set dispatch dimensions *)
    IndirectComputeCommand.concurrent_dispatch_threadgroups cmd
      ~threadgroups_per_grid:{ Size.width = 4; height = 1; depth = 1 }
      ~threads_per_threadgroup:{ Size.width = 1; height = 1; depth = 1 };

    (* Create command buffer and encoder *)
    let queue = CommandQueue.on_device device in
    let cmd_buffer = CommandBuffer.on_queue queue in
    let compute_encoder = ComputeCommandEncoder.on_buffer cmd_buffer in

    (* Execute the indirect command buffer *)
    ComputeCommandEncoder.execute_commands_in_buffer compute_encoder icb
      { Range.location = 0; length = 1 };

    (* End encoding and commit *)
    ComputeCommandEncoder.end_encoding compute_encoder;
    CommandBuffer.commit cmd_buffer;
    CommandBuffer.wait_until_completed cmd_buffer;

    (* Verify results *)
    for i = 0 to 3 do
      let value = !@(ptr +@ i) in
      Printf.printf "buffer[%d] = %g\n" i value
    done);
  [%expect
    {|
    Pipeline descriptor: ((label "") (function (name double_values type Kernel))
                          (support_icb true))
    Pipeline supports indirect command buffers: true
    buffer[0] = 2
    buffer[1] = 4
    buffer[2] = 6
    buffer[3] = 8
    |}]
