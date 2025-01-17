(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLAccelerationStructureInstanceDescriptor] structure typ = structure "MTLAccelerationStructureInstanceDescriptor"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlaccelerationstructureinstancedescriptor?language=objc}MTLAccelerationStructureInstanceDescriptor} *)

let transformationMatrix = field t "transformationMatrix" MTLPackedFloat4x3.t
let options = field t "options" uint
let mask = field t "mask" uint
let intersectionFunctionTableOffset = field t "intersectionFunctionTableOffset" uint
let accelerationStructureIndex = field t "accelerationStructureIndex" uint

let () = seal t

let init
    ~transformationMatrix:transformationMatrix_v
    ~options:options_v
    ~mask:mask_v
    ~intersectionFunctionTableOffset:intersectionFunctionTableOffset_v
    ~accelerationStructureIndex:accelerationStructureIndex_v
    =
  let t = make t in
  setf t transformationMatrix transformationMatrix_v;
  setf t options options_v;
  setf t mask mask_v;
  setf t intersectionFunctionTableOffset intersectionFunctionTableOffset_v;
  setf t accelerationStructureIndex accelerationStructureIndex_v;
  t
let transformationMatrix t = getf t transformationMatrix
let options t = getf t options
let mask t = getf t mask
let intersectionFunctionTableOffset t = getf t intersectionFunctionTableOffset
let accelerationStructureIndex t = getf t accelerationStructureIndex
