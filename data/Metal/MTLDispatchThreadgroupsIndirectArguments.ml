(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLDispatchThreadgroupsIndirectArguments] structure typ = structure "MTLDispatchThreadgroupsIndirectArguments"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtldispatchthreadgroupsindirectarguments?language=objc}MTLDispatchThreadgroupsIndirectArguments} *)

let threadgroupsPerGrid = field t "threadgroupsPerGrid" (ptr uint)

let () = seal t

let init
    ~threadgroupsPerGrid:threadgroupsPerGrid_v
    =
  let t = make t in
  setf t threadgroupsPerGrid threadgroupsPerGrid_v;
  t
let threadgroupsPerGrid t = getf t threadgroupsPerGrid
