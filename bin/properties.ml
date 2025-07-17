open Metal

let () =
  (* Get all Metal devices *)
  let devices = Device.copy_all_devices () in
  Printf.printf "Found %d device(s)\n" (Array.length devices);

  Array.iteri
    (fun i device ->
      Printf.printf "\nDevice %d: %s\n" i (Device.sexp_of_t device |> Sexplib0.Sexp.to_string);

      (* Get the device attributes *)
      let attrs = Device.get_attributes device in

      (* Convert attributes to a human-readable S-expression and print *)
      let attrs_sexp = Device.sexp_of_attributes attrs in
      Printf.printf "Device %d Attributes:\n%s\n" i (Sexplib0.Sexp.to_string_hum attrs_sexp))
    devices
