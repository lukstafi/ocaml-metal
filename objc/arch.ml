type t = Amd64 | Arm64

let detect_arch () =
  try
    let ic = Unix.open_process_in "uname -m" in
    let arch_str = input_line ic in
    let _ = Unix.close_process_in ic in
    match String.trim arch_str with
    | "x86_64" -> Amd64
    | "arm64" -> Arm64
    | _ -> failwith ("Unknown architecture: " ^ arch_str)
  with _ -> failwith "Failed to detect architecture"

let current = detect_arch ()
