open Base
open Stdio
open Metal

let%expect_test "metal device synchronization between command queues" =
  (* 1. Initialize Metal device and create two command queues *)
  let device = Device.create_system_default () in
  printf "Device: %s\n" (Device.get_attributes device).name;
  [%expect {| Device: .* (regexp) |}];
  
  let queue1 = CommandQueue.on_device device in
  let queue2 = CommandQueue.on_device device in

  (* 2. Create a SharedEvent for synchronization *)
  let event = SharedEvent.on_device device in
  let event_value_to_signal = Unsigned.ULLong.of_int 1 in

  (* 3. Create two buffers, initializing the first one *)
  let buffer_size = 16 in
  let resource_options = ResourceOptions.storage_mode_managed in
  let buffer1 = Buffer.on_device device ~length:buffer_size resource_options in
  let buffer2 = Buffer.on_device device ~length:buffer_size resource_options in

  (* Initialize buffer1 with some data *)
  let buffer1_ptr = Ctypes.coerce (Ctypes.ptr Ctypes.void) (Ctypes.ptr Ctypes.int) (Buffer.contents buffer1) in
  for i = 0 to Ctypes.(buffer_size / sizeof int) - 1 do
    Ctypes.(buffer1_ptr +@ i <-@ i)
  done;
  Buffer.did_modify_range buffer1 (Buffer.NSRange.make ~location:0 ~length:buffer_size);

  (* 4. Submit command buffer 1 (Copy buffer1 -> buffer2, Signal event) *)
  let command_buffer1 = CommandQueue.command_buffer queue1 in
  let blit_encoder1 = CommandBuffer.blit_command_encoder command_buffer1 in
  BlitCommandEncoder.synchronize_resource ~self:blit_encoder1 ~resource:(Resource.of_buffer buffer1);
  BlitCommandEncoder.copy_from_buffer ~self:blit_encoder1 ~source_buffer:buffer1 ~source_offset:0 ~destination_buffer:buffer2 ~destination_offset:0 ~size:buffer_size;
  BlitCommandEncoder.synchronize_resource ~self:blit_encoder1 ~resource:(Resource.of_buffer buffer2);
  BlitCommandEncoder.end_encoding blit_encoder1;
  CommandBuffer.encode_signal_event command_buffer1 event event_value_to_signal;
  CommandBuffer.commit command_buffer1;
  printf "Committed command buffer 1 (copy 1->2, signal)\n";
  [%expect {| Committed command buffer 1 (copy 1->2, signal) |}];

  (* 5. Submit command buffer 2 (Wait for event, Copy buffer2 -> buffer1) *)
  let command_buffer2 = CommandQueue.command_buffer queue2 in
  CommandBuffer.encode_wait_for_event command_buffer2 event event_value_to_signal;
  let blit_encoder2 = CommandBuffer.blit_command_encoder command_buffer2 in
  BlitCommandEncoder.synchronize_resource ~self:blit_encoder2 ~resource:(Resource.of_buffer buffer2);
  BlitCommandEncoder.copy_from_buffer ~self:blit_encoder2 ~source_buffer:buffer2 ~source_offset:0 ~destination_buffer:buffer1 ~destination_offset:0 ~size:buffer_size;
  BlitCommandEncoder.synchronize_resource ~self:blit_encoder2 ~resource:(Resource.of_buffer buffer1);
  BlitCommandEncoder.end_encoding blit_encoder2;
  CommandBuffer.commit command_buffer2;
  printf "Committed command buffer 2 (wait, copy 2->1)\n";
  [%expect {| Committed command buffer 2 (wait, copy 2->1) |}];

  (* 6. Wait on the CPU for the second command buffer to complete *)
  printf "Waiting for command buffer 2 to complete...\n";
  [%expect {| Waiting for command buffer 2 to complete... |}];
  
  CommandBuffer.wait_until_completed command_buffer2;
  printf "Command buffer 2 completed.\n";
  [%expect {| Command buffer 2 completed. |}];

  (* 7. Verify the final state of the first buffer *)
  (* Synchronize buffer1 back to CPU before reading *)
  let sync_buffer = CommandQueue.command_buffer queue1 in (* Use any queue *)
  let sync_encoder = CommandBuffer.blit_command_encoder sync_buffer in
  BlitCommandEncoder.synchronize_resource ~self:sync_encoder ~resource:(Resource.of_buffer buffer1);
  BlitCommandEncoder.end_encoding sync_encoder;
  CommandBuffer.commit sync_buffer;
  CommandBuffer.wait_until_completed sync_buffer;

  printf "Verifying buffer1 contents...\n";
  [%expect {| Verifying buffer1 contents... |}];
  
  let buffer1_final_ptr = Ctypes.coerce (Ctypes.ptr Ctypes.void) (Ctypes.ptr Ctypes.int) (Buffer.contents buffer1) in
  let all_match = ref true in
  
  for i = 0 to Ctypes.(buffer_size / sizeof int) - 1 do
    let expected = i in
    let actual = Ctypes.(!@(buffer1_final_ptr +@ i)) in
    if actual <> expected then (
      printf "Mismatch at index %d: Expected %d, Got %d\n" i expected actual;
      all_match := false
    )
  done;

  if !all_match then
    printf "Test PASSED: Buffer contents verified successfully.\n"
  else
    printf "Test FAILED: Buffer contents mismatch.\n";
  
  [%expect {| Test PASSED: Buffer contents verified successfully. |}] 