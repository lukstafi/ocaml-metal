(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLVertexAmplificationViewMapping] structure typ = structure "MTLVertexAmplificationViewMapping"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlvertexamplificationviewmapping?language=objc}MTLVertexAmplificationViewMapping} *)

let viewportArrayIndexOffset = field t "viewportArrayIndexOffset" uint
let renderTargetArrayIndexOffset = field t "renderTargetArrayIndexOffset" uint

let () = seal t

let init
    ~viewportArrayIndexOffset:viewportArrayIndexOffset_v
    ~renderTargetArrayIndexOffset:renderTargetArrayIndexOffset_v
    =
  let t = make t in
  setf t viewportArrayIndexOffset viewportArrayIndexOffset_v;
  setf t renderTargetArrayIndexOffset renderTargetArrayIndexOffset_v;
  t
let viewportArrayIndexOffset t = getf t viewportArrayIndexOffset
let renderTargetArrayIndexOffset t = getf t renderTargetArrayIndexOffset
