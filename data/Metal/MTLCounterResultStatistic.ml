(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLCounterResultStatistic] structure typ = structure "MTLCounterResultStatistic"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlcounterresultstatistic?language=objc}MTLCounterResultStatistic} *)

let tessellationInputPatches = field t "tessellationInputPatches" ullong
let vertexInvocations = field t "vertexInvocations" ullong
let postTessellationVertexInvocations = field t "postTessellationVertexInvocations" ullong
let clipperInvocations = field t "clipperInvocations" ullong
let clipperPrimitivesOut = field t "clipperPrimitivesOut" ullong
let fragmentInvocations = field t "fragmentInvocations" ullong
let fragmentsPassed = field t "fragmentsPassed" ullong
let computeKernelInvocations = field t "computeKernelInvocations" ullong

let () = seal t

let init
    ~tessellationInputPatches:tessellationInputPatches_v
    ~vertexInvocations:vertexInvocations_v
    ~postTessellationVertexInvocations:postTessellationVertexInvocations_v
    ~clipperInvocations:clipperInvocations_v
    ~clipperPrimitivesOut:clipperPrimitivesOut_v
    ~fragmentInvocations:fragmentInvocations_v
    ~fragmentsPassed:fragmentsPassed_v
    ~computeKernelInvocations:computeKernelInvocations_v
    =
  let t = make t in
  setf t tessellationInputPatches tessellationInputPatches_v;
  setf t vertexInvocations vertexInvocations_v;
  setf t postTessellationVertexInvocations postTessellationVertexInvocations_v;
  setf t clipperInvocations clipperInvocations_v;
  setf t clipperPrimitivesOut clipperPrimitivesOut_v;
  setf t fragmentInvocations fragmentInvocations_v;
  setf t fragmentsPassed fragmentsPassed_v;
  setf t computeKernelInvocations computeKernelInvocations_v;
  t
let tessellationInputPatches t = getf t tessellationInputPatches
let vertexInvocations t = getf t vertexInvocations
let postTessellationVertexInvocations t = getf t postTessellationVertexInvocations
let clipperInvocations t = getf t clipperInvocations
let clipperPrimitivesOut t = getf t clipperPrimitivesOut
let fragmentInvocations t = getf t fragmentInvocations
let fragmentsPassed t = getf t fragmentsPassed
let computeKernelInvocations t = getf t computeKernelInvocations
