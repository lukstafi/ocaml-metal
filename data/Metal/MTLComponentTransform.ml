(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLComponentTransform] structure typ = structure "MTLComponentTransform"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlcomponenttransform?language=objc}MTLComponentTransform} *)

let scale = field t "scale" MTLPackedFloat3.t
let shear = field t "shear" MTLPackedFloat3.t
let pivot = field t "pivot" MTLPackedFloat3.t
let rotation = field t "rotation" MTLPackedFloatQuaternion.t
let translation = field t "translation" MTLPackedFloat3.t

let () = seal t

let init
    ~scale:scale_v
    ~shear:shear_v
    ~pivot:pivot_v
    ~rotation:rotation_v
    ~translation:translation_v
    =
  let t = make t in
  setf t scale scale_v;
  setf t shear shear_v;
  setf t pivot pivot_v;
  setf t rotation rotation_v;
  setf t translation translation_v;
  t
let scale t = getf t scale
let shear t = getf t shear
let pivot t = getf t pivot
let rotation t = getf t rotation
let translation t = getf t translation
