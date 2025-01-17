(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLViewport] structure typ = structure "MTLViewport"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlviewport?language=objc}MTLViewport} *)

let originX = field t "originX" double
let originY = field t "originY" double
let width = field t "width" double
let height = field t "height" double
let znear = field t "znear" double
let zfar = field t "zfar" double

let () = seal t

let init
    ~originX:originX_v
    ~originY:originY_v
    ~width:width_v
    ~height:height_v
    ~znear:znear_v
    ~zfar:zfar_v
    =
  let t = make t in
  setf t originX originX_v;
  setf t originY originY_v;
  setf t width width_v;
  setf t height height_v;
  setf t znear znear_v;
  setf t zfar zfar_v;
  t
let originX t = getf t originX
let originY t = getf t originY
let width t = getf t width
let height t = getf t height
let znear t = getf t znear
let zfar t = getf t zfar
