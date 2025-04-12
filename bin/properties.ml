open Metal

let () =
  (* Get the default Metal device *)
  let device = Device.create_system_default () in
  Printf.printf "Found device: %s\n" (Device.sexp_of_t device |> Sexplib0.Sexp.to_string);

  (* Get the device attributes *)
  let attrs = Device.get_attributes device in

  (* Convert attributes to a human-readable S-expression and print *)
  let attrs_sexp = Device.sexp_of_attributes attrs in
  Printf.printf "\nDevice Attributes:\n%s\n"
    (Sexplib0.Sexp.to_string_hum attrs_sexp)
