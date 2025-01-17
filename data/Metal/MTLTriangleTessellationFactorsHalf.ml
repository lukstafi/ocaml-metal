(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLTriangleTessellationFactorsHalf] structure typ = structure "MTLTriangleTessellationFactorsHalf"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtltriangletessellationfactorshalf?language=objc}MTLTriangleTessellationFactorsHalf} *)

let edgeTessellationFactor = field t "edgeTessellationFactor" (ptr ushort)
let insideTessellationFactor = field t "insideTessellationFactor" ushort

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
