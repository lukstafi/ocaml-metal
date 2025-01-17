(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLSizeAndAlign] structure typ = structure "MTLSizeAndAlign"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlsizeandalign?language=objc}MTLSizeAndAlign} *)

let size = field t "size" ullong
let align = field t "align" ullong

let () = seal t

let init
    ~size:size_v
    ~align:align_v
    =
  let t = make t in
  setf t size size_v;
  setf t align align_v;
  t
let size t = getf t size
let align t = getf t align
