(* A same-domain systhread cannot signal the event while a foreign call keeps the runtime lock. The
   timeout bounds that failure; no elapsed time is asserted. *)
let () =
  let device = Metal.Device.create_system_default () in
  let event = Metal.SharedEvent.on_device device in
  let value = Unsigned.ULLong.one in
  let signaler =
    Thread.create
      (fun () ->
        Thread.delay 0.05;
        Gc.full_major ();
        Metal.SharedEvent.set_signaled_value event value)
      ()
  in
  let signaled =
    Metal.SharedEvent.wait_until_signaled_value event ~value
      ~timeout_ms:(Unsigned.ULLong.of_int 5000)
  in
  Thread.join signaler;
  if not signaled then failwith "event wait prevented the signaling systhread from running";
  if
    Metal.SharedEvent.wait_until_signaled_value event ~value:(Unsigned.ULLong.of_int 2)
      ~timeout_ms:Unsigned.ULLong.zero
  then failwith "an unsignaled event unexpectedly completed"
