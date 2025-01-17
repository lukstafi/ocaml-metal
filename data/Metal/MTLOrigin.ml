(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLOrigin] structure typ = structure "MTLOrigin"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlorigin?language=objc}MTLOrigin} *)

let x = field t "x" ullong
let y = field t "y" ullong
let z = field t "z" ullong

let () = seal t

let init
    ~x:x_v
    ~y:y_v
    ~z:z_v
    =
  let t = make t in
  setf t x x_v;
  setf t y y_v;
  setf t z z_v;
  t
let x t = getf t x
let y t = getf t y
let z t = getf t z
