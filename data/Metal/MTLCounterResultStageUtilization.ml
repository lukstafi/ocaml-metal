(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLCounterResultStageUtilization] structure typ = structure "MTLCounterResultStageUtilization"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlcounterresultstageutilization?language=objc}MTLCounterResultStageUtilization} *)

let totalCycles = field t "totalCycles" ullong
let vertexCycles = field t "vertexCycles" ullong
let tessellationCycles = field t "tessellationCycles" ullong
let postTessellationVertexCycles = field t "postTessellationVertexCycles" ullong
let fragmentCycles = field t "fragmentCycles" ullong
let renderTargetCycles = field t "renderTargetCycles" ullong

let () = seal t

let init
    ~totalCycles:totalCycles_v
    ~vertexCycles:vertexCycles_v
    ~tessellationCycles:tessellationCycles_v
    ~postTessellationVertexCycles:postTessellationVertexCycles_v
    ~fragmentCycles:fragmentCycles_v
    ~renderTargetCycles:renderTargetCycles_v
    =
  let t = make t in
  setf t totalCycles totalCycles_v;
  setf t vertexCycles vertexCycles_v;
  setf t tessellationCycles tessellationCycles_v;
  setf t postTessellationVertexCycles postTessellationVertexCycles_v;
  setf t fragmentCycles fragmentCycles_v;
  setf t renderTargetCycles renderTargetCycles_v;
  t
let totalCycles t = getf t totalCycles
let vertexCycles t = getf t vertexCycles
let tessellationCycles t = getf t tessellationCycles
let postTessellationVertexCycles t = getf t postTessellationVertexCycles
let fragmentCycles t = getf t fragmentCycles
let renderTargetCycles t = getf t renderTargetCycles
