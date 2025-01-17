(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLRegion] structure typ = structure "MTLRegion"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlregion?language=objc}MTLRegion} *)

let origin = field t "origin" MTLOrigin.t
let size = field t "size" MTLSize.t

let () = seal t

let init
    ~origin:origin_v
    ~size:size_v
    =
  let t = make t in
  setf t origin origin_v;
  setf t size size_v;
  t
let origin t = getf t origin
let size t = getf t size
