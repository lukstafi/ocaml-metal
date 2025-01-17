(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLDrawPatchIndirectArguments] structure typ = structure "MTLDrawPatchIndirectArguments"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtldrawpatchindirectarguments?language=objc}MTLDrawPatchIndirectArguments} *)

let patchCount = field t "patchCount" uint
let instanceCount = field t "instanceCount" uint
let patchStart = field t "patchStart" uint
let baseInstance = field t "baseInstance" uint

let () = seal t

let init
    ~patchCount:patchCount_v
    ~instanceCount:instanceCount_v
    ~patchStart:patchStart_v
    ~baseInstance:baseInstance_v
    =
  let t = make t in
  setf t patchCount patchCount_v;
  setf t instanceCount instanceCount_v;
  setf t patchStart patchStart_v;
  setf t baseInstance baseInstance_v;
  t
let patchCount t = getf t patchCount
let instanceCount t = getf t instanceCount
let patchStart t = getf t patchStart
let baseInstance t = getf t baseInstance
