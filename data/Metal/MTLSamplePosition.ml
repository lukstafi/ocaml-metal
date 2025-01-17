(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLSamplePosition] structure typ = structure "MTLSamplePosition"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlsampleposition?language=objc}MTLSamplePosition} *)

let x = field t "x" float
let y = field t "y" float

let () = seal t

let init
    ~x:x_v
    ~y:y_v
    =
  let t = make t in
  setf t x x_v;
  setf t y y_v;
  t
let x t = getf t x
let y t = getf t y
