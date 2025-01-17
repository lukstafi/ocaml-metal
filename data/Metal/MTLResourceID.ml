(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLResourceID] structure typ = structure "MTLResourceID"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlresourceid?language=objc}MTLResourceID} *)

let _impl = field t "_impl" ullong

let () = seal t

let init
    ~_impl:_impl_v
    =
  let t = make t in
  setf t _impl _impl_v;
  t
let _impl t = getf t _impl
