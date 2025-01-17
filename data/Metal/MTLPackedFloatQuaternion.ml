(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLPackedFloatQuaternion] structure typ = structure "MTLPackedFloatQuaternion"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlpackedfloatquaternion?language=objc}MTLPackedFloatQuaternion} *)

let x = field t "x" float
let y = field t "y" float
let z = field t "z" float
let w = field t "w" float

let () = seal t

let init
    ~x:x_v
    ~y:y_v
    ~z:z_v
    ~w:w_v
    =
  let t = make t in
  setf t x x_v;
  setf t y y_v;
  setf t z z_v;
  setf t w w_v;
  t
let x t = getf t x
let y t = getf t y
let z t = getf t z
let w t = getf t w
