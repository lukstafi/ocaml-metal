(* auto-generated, do not modify *)

[@@@ocaml.warning "-33"]
open Runtime
open Objc

let t : [`MTLClearColor] structure typ = structure "MTLClearColor"
(** Apple docs: {{:https://developer.apple.com/documentation/metal/mtlclearcolor?language=objc}MTLClearColor} *)

let red = field t "red" double
let green = field t "green" double
let blue = field t "blue" double
let alpha = field t "alpha" double

let () = seal t

let init
    ~red:red_v
    ~green:green_v
    ~blue:blue_v
    ~alpha:alpha_v
    =
  let t = make t in
  setf t red red_v;
  setf t green green_v;
  setf t blue blue_v;
  setf t alpha alpha_v;
  t
let red t = getf t red
let green t = getf t green
let blue t = getf t blue
let alpha t = getf t alpha
