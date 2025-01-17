(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLQuadTessellationFactorsHalf] structure typ = structure "MTLQuadTessellationFactorsHalf"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlquadtessellationfactorshalf?language=objc}MTLQuadTessellationFactorsHalf} *)

let edgeTessellationFactor = field t "edgeTessellationFactor" (ptr ushort)
let insideTessellationFactor = field t "insideTessellationFactor" (ptr ushort)

let () = seal t

let init
    ~edgeTessellationFactor:edgeTessellationFactor_v
    ~insideTessellationFactor:insideTessellationFactor_v
    =
  let t = make t in
  setf t edgeTessellationFactor edgeTessellationFactor_v;
  setf t insideTessellationFactor insideTessellationFactor_v;
  t
let edgeTessellationFactor t = getf t edgeTessellationFactor
let insideTessellationFactor t = getf t insideTessellationFactor
