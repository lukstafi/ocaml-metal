(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLAccelerationStructureSizes] structure typ = structure "MTLAccelerationStructureSizes"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlaccelerationstructuresizes?language=objc}MTLAccelerationStructureSizes} *)

let accelerationStructureSize = field t "accelerationStructureSize" ullong
let buildScratchBufferSize = field t "buildScratchBufferSize" ullong
let refitScratchBufferSize = field t "refitScratchBufferSize" ullong

let () = seal t

let init
    ~accelerationStructureSize:accelerationStructureSize_v
    ~buildScratchBufferSize:buildScratchBufferSize_v
    ~refitScratchBufferSize:refitScratchBufferSize_v
    =
  let t = make t in
  setf t accelerationStructureSize accelerationStructureSize_v;
  setf t buildScratchBufferSize buildScratchBufferSize_v;
  setf t refitScratchBufferSize refitScratchBufferSize_v;
  t
let accelerationStructureSize t = getf t accelerationStructureSize
let buildScratchBufferSize t = getf t buildScratchBufferSize
let refitScratchBufferSize t = getf t refitScratchBufferSize
