(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLAxisAlignedBoundingBox] structure typ = structure "_MTLAxisAlignedBoundingBox"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/_mtlaxisalignedboundingbox?language=objc}_MTLAxisAlignedBoundingBox} *)

let min = field t "min" MTLPackedFloat3.t
let max = field t "max" MTLPackedFloat3.t

let () = seal t

let init
    ~min:min_v
    ~max:max_v
    =
  let t = make t in
  setf t min min_v;
  setf t max max_v;
  t
let min t = getf t min
let max t = getf t max
