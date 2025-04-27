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
