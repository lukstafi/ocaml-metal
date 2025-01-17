(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLDrawPrimitivesIndirectArguments] structure typ = structure "MTLDrawPrimitivesIndirectArguments"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtldrawprimitivesindirectarguments?language=objc}MTLDrawPrimitivesIndirectArguments} *)

let vertexCount = field t "vertexCount" uint
let instanceCount = field t "instanceCount" uint
let vertexStart = field t "vertexStart" uint
let baseInstance = field t "baseInstance" uint

let () = seal t

let init
    ~vertexCount:vertexCount_v
    ~instanceCount:instanceCount_v
    ~vertexStart:vertexStart_v
    ~baseInstance:baseInstance_v
    =
  let t = make t in
  setf t vertexCount vertexCount_v;
  setf t instanceCount instanceCount_v;
  setf t vertexStart vertexStart_v;
  setf t baseInstance baseInstance_v;
  t
let vertexCount t = getf t vertexCount
let instanceCount t = getf t instanceCount
let vertexStart t = getf t vertexStart
let baseInstance t = getf t baseInstance
