(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLIndirectCommandBufferExecutionRange] structure typ = structure "MTLIndirectCommandBufferExecutionRange"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlindirectcommandbufferexecutionrange?language=objc}MTLIndirectCommandBufferExecutionRange} *)

let location = field t "location" uint
let length = field t "length" uint

let () = seal t

let init
    ~location:location_v
    ~length:length_v
    =
  let t = make t in
  setf t location location_v;
  setf t length length_v;
  t
let location t = getf t location
let length t = getf t length
