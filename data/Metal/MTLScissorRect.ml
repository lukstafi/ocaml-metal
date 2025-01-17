(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLScissorRect] structure typ = structure "MTLScissorRect"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlscissorrect?language=objc}MTLScissorRect} *)

let x = field t "x" ullong
let y = field t "y" ullong
let width = field t "width" ullong
let height = field t "height" ullong

let () = seal t

let init
    ~x:x_v
    ~y:y_v
    ~width:width_v
    ~height:height_v
    =
  let t = make t in
  setf t x x_v;
  setf t y y_v;
  setf t width width_v;
  setf t height height_v;
  t
let x t = getf t x
let y t = getf t y
let width t = getf t width
let height t = getf t height
