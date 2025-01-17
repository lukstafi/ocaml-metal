(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLSize] structure typ = structure "MTLSize"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlsize?language=objc}MTLSize} *)

let width = field t "width" ullong
let height = field t "height" ullong
let depth = field t "depth" ullong

let () = seal t

let init
    ~width:width_v
    ~height:height_v
    ~depth:depth_v
    =
  let t = make t in
  setf t width width_v;
  setf t height height_v;
  setf t depth depth_v;
  t
let width t = getf t width
let height t = getf t height
let depth t = getf t depth
