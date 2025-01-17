(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLIndirectAccelerationStructureMotionInstanceDescriptor] structure typ = structure "MTLIndirectAccelerationStructureMotionInstanceDescriptor"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlindirectaccelerationstructuremotioninstancedescriptor?language=objc}MTLIndirectAccelerationStructureMotionInstanceDescriptor} *)

let options = field t "options" uint
let mask = field t "mask" uint
let intersectionFunctionTableOffset = field t "intersectionFunctionTableOffset" uint
let userID = field t "userID" uint
let accelerationStructureID = field t "accelerationStructureID" MTLResourceID.t
let motionTransformsStartIndex = field t "motionTransformsStartIndex" uint
let motionTransformsCount = field t "motionTransformsCount" uint
let motionStartBorderMode = field t "motionStartBorderMode" uint
let motionEndBorderMode = field t "motionEndBorderMode" uint
let motionStartTime = field t "motionStartTime" float
let motionEndTime = field t "motionEndTime" float

let () = seal t

let init
    ~options:options_v
    ~mask:mask_v
    ~intersectionFunctionTableOffset:intersectionFunctionTableOffset_v
    ~userID:userID_v
    ~accelerationStructureID:accelerationStructureID_v
    ~motionTransformsStartIndex:motionTransformsStartIndex_v
    ~motionTransformsCount:motionTransformsCount_v
    ~motionStartBorderMode:motionStartBorderMode_v
    ~motionEndBorderMode:motionEndBorderMode_v
    ~motionStartTime:motionStartTime_v
    ~motionEndTime:motionEndTime_v
    =
  let t = make t in
  setf t options options_v;
  setf t mask mask_v;
  setf t intersectionFunctionTableOffset intersectionFunctionTableOffset_v;
  setf t userID userID_v;
  setf t accelerationStructureID accelerationStructureID_v;
  setf t motionTransformsStartIndex motionTransformsStartIndex_v;
  setf t motionTransformsCount motionTransformsCount_v;
  setf t motionStartBorderMode motionStartBorderMode_v;
  setf t motionEndBorderMode motionEndBorderMode_v;
  setf t motionStartTime motionStartTime_v;
  setf t motionEndTime motionEndTime_v;
  t
let options t = getf t options
let mask t = getf t mask
let intersectionFunctionTableOffset t = getf t intersectionFunctionTableOffset
let userID t = getf t userID
let accelerationStructureID t = getf t accelerationStructureID
let motionTransformsStartIndex t = getf t motionTransformsStartIndex
let motionTransformsCount t = getf t motionTransformsCount
let motionStartBorderMode t = getf t motionStartBorderMode
let motionEndBorderMode t = getf t motionEndBorderMode
let motionStartTime t = getf t motionStartTime
let motionEndTime t = getf t motionEndTime
