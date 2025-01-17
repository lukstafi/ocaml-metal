(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLDrawIndexedPrimitivesIndirectArguments] structure typ = structure "MTLDrawIndexedPrimitivesIndirectArguments"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtldrawindexedprimitivesindirectarguments?language=objc}MTLDrawIndexedPrimitivesIndirectArguments} *)

let indexCount = field t "indexCount" uint
let instanceCount = field t "instanceCount" uint
let indexStart = field t "indexStart" uint
let baseVertex = field t "baseVertex" int
let baseInstance = field t "baseInstance" uint

let () = seal t

let init
    ~indexCount:indexCount_v
    ~instanceCount:instanceCount_v
    ~indexStart:indexStart_v
    ~baseVertex:baseVertex_v
    ~baseInstance:baseInstance_v
    =
  let t = make t in
  setf t indexCount indexCount_v;
  setf t instanceCount instanceCount_v;
  setf t indexStart indexStart_v;
  setf t baseVertex baseVertex_v;
  setf t baseInstance baseInstance_v;
  t
let indexCount t = getf t indexCount
let instanceCount t = getf t instanceCount
let indexStart t = getf t indexStart
let baseVertex t = getf t baseVertex
let baseInstance t = getf t baseInstance
