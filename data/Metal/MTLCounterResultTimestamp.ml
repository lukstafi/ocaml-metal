(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLCounterResultTimestamp] structure typ = structure "MTLCounterResultTimestamp"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlcounterresulttimestamp?language=objc}MTLCounterResultTimestamp} *)

let timestamp = field t "timestamp" ullong

let () = seal t

let init
    ~timestamp:timestamp_v
    =
  let t = make t in
  setf t timestamp timestamp_v;
  t
let timestamp t = getf t timestamp
