open Runtime

let () =
  let a_class = Objc.get_class "MTLCompileOptions" in
  let an_instance = alloc a_class |> init in
  msg_send (selector "newLibraryWithSource:options:error:") ~self:an_instance
    ~args:Objc_type.[]
    ~return:Objc_type.void;
  print_endline "Hello, World!"
