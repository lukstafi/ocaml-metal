(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLMapIndirectArguments] structure typ = structure "MTLMapIndirectArguments"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlmapindirectarguments?language=objc}MTLMapIndirectArguments} *)

let regionOriginX = field t "regionOriginX" uint
let regionOriginY = field t "regionOriginY" uint
let regionOriginZ = field t "regionOriginZ" uint
let regionSizeWidth = field t "regionSizeWidth" uint
let regionSizeHeight = field t "regionSizeHeight" uint
let regionSizeDepth = field t "regionSizeDepth" uint
let mipMapLevel = field t "mipMapLevel" uint
let sliceId = field t "sliceId" uint

let () = seal t

let init
    ~regionOriginX:regionOriginX_v
    ~regionOriginY:regionOriginY_v
    ~regionOriginZ:regionOriginZ_v
    ~regionSizeWidth:regionSizeWidth_v
    ~regionSizeHeight:regionSizeHeight_v
    ~regionSizeDepth:regionSizeDepth_v
    ~mipMapLevel:mipMapLevel_v
    ~sliceId:sliceId_v
    =
  let t = make t in
  setf t regionOriginX regionOriginX_v;
  setf t regionOriginY regionOriginY_v;
  setf t regionOriginZ regionOriginZ_v;
  setf t regionSizeWidth regionSizeWidth_v;
  setf t regionSizeHeight regionSizeHeight_v;
  setf t regionSizeDepth regionSizeDepth_v;
  setf t mipMapLevel mipMapLevel_v;
  setf t sliceId sliceId_v;
  t
let regionOriginX t = getf t regionOriginX
let regionOriginY t = getf t regionOriginY
let regionOriginZ t = getf t regionOriginZ
let regionSizeWidth t = getf t regionSizeWidth
let regionSizeHeight t = getf t regionSizeHeight
let regionSizeDepth t = getf t regionSizeDepth
let mipMapLevel t = getf t mipMapLevel
let sliceId t = getf t sliceId
