(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLStageInRegionIndirectArguments] structure typ = structure "MTLStageInRegionIndirectArguments"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlstageinregionindirectarguments?language=objc}MTLStageInRegionIndirectArguments} *)

let stageInOrigin = field t "stageInOrigin" (ptr uint)
let stageInSize = field t "stageInSize" (ptr uint)

let () = seal t

let init
    ~stageInOrigin:stageInOrigin_v
    ~stageInSize:stageInSize_v
    =
  let t = make t in
  setf t stageInOrigin stageInOrigin_v;
  setf t stageInSize stageInSize_v;
  t
let stageInOrigin t = getf t stageInOrigin
let stageInSize t = getf t stageInSize
