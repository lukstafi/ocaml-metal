open Runtime
open Runtime.Objc
open Runtime.Class
open Runtime.Property

module ResourceOptions = struct
  let mtl_resource_cpu_cache_mode_default_cache = 0
  let mtl_resource_storage_mode_shared = 0 lsl 4
end

module PipelineOption = struct
  let mtl_pipeline_option_none = 0
end

let request_type_compile = 13
let libobjc = Dl.dlopen ~filename:"/usr/lib/libobjc.dylib" ~flags:[ Dl.RTLD_NOW ]

let libmetal =
  Dl.dlopen ~filename:"/System/Library/Frameworks/Metal.framework/Metal" ~flags:[ Dl.RTLD_NOW ]

let libdispatch = Dl.dlopen ~filename:"/usr/lib/libSystem.dylib" ~flags:[ Dl.RTLD_NOW ]

module Compiler = struct
  type t = { cgs : id }

  let create () =
    let cgs =
      msg_send ~self:(get_class "MTLCodeGenService") ~cmd:(selector "new") ~typ:(returning id)
    in
    { cgs }

  let build_request t src params =
    let src_padded =
      src ^ String.make (round_up (String.length src + 1) 4 - String.length src) '\000'
    in
    let params_padded =
      params ^ String.make (round_up (String.length params + 1) 4 - String.length params) '\000'
    in
    let request = Bytes.create (8 + String.length src_padded + String.length params_padded) in
    Bytes.set_int64_le request 0 (Int64.of_int (String.length src_padded));
    Bytes.set_int64_le request 8 (Int64.of_int (String.length params_padded));
    Bytes.blit_string src_padded 0 request 16 (String.length src_padded);
    Bytes.blit_string params_padded 0 request
      (16 + String.length src_padded)
      (String.length params_padded);
    request

  let compile t src params =
    let request = build_request t src params in
    let callback = Block.make (fun _ _ -> ()) ~args:[] ~return:void in
    msg_send ~self:t.cgs
      ~cmd:(selector "MTLCodeGenServiceBuildRequest")
      ~typ:(id @-> id @-> int @-> string @-> int @-> id @-> returning void)
      nil nil request_type_compile request (String.length request) callback;
    (* TODO: Handle return value and error checking *)
    ()
end

module Program = struct
  type t = {
    dev : id;
    name : string;
    lib : string;
    library : id;
    fxn : id;
    pipeline_state : id;
    max_total_threads : int;
  }

  let create dev name lib =
    let library =
      if String.sub lib 0 4 = "MTLB" then
        let data =
          msg_send
            ~self:(get_class "dispatch_data_create")
            ~cmd:(selector "new")
            ~typ:(string @-> int @-> id @-> id @-> returning id)
            lib (String.length lib) nil nil
        in
        msg_send ~self:dev
          ~cmd:(selector "newLibraryWithData:error:")
          ~typ:(id @-> id @-> returning id)
          data nil
      else
        (* TODO: Handle source compilation *)
        failwith "Source compilation not implemented"
    in

    let fxn =
      msg_send ~self:library ~cmd:(selector "newFunctionWithName:")
        ~typ:(id @-> returning id)
        (new_string name)
    in
    let descriptor =
      msg_send
        ~self:(get_class "MTLComputePipelineDescriptor")
        ~cmd:(selector "new") ~typ:(returning id)
    in
    msg_send ~self:descriptor ~cmd:(selector "setComputeFunction:") ~typ:(id @-> returning void) fxn;
    msg_send ~self:descriptor
      ~cmd:(selector "setSupportIndirectCommandBuffers:")
      ~typ:(bool @-> returning void)
      true;

    let pipeline_state =
      msg_send ~self:dev
        ~cmd:(selector "newComputePipelineStateWithDescriptor:options:reflection:error:")
        ~typ:(id @-> int @-> id @-> id @-> returning id)
        descriptor PipelineOption.mtl_pipeline_option_none nil nil
    in

    let max_total_threads =
      msg_send ~self:pipeline_state
        ~cmd:(selector "maxTotalThreadsPerThreadgroup")
        ~typ:(returning int)
    in

    { dev; name; lib; library; fxn; pipeline_state; max_total_threads }

  let execute t bufs global_size local_size vals wait =
    (if List.fold_left ( * ) 1 local_size > t.max_total_threads then
       let exec_width =
         msg_send ~self:t.pipeline_state ~cmd:(selector "threadExecutionWidth") ~typ:(returning int)
       in
       let memory_length =
         msg_send ~self:t.pipeline_state
           ~cmd:(selector "staticThreadgroupMemoryLength")
           ~typ:(returning int)
       in
       failwith
         (Printf.sprintf "local size %s bigger than %d with exec width %d memory length %d"
            (String.concat "," (List.map string_of_int local_size))
            t.max_total_threads exec_width memory_length));

    let command_buffer = msg_send ~self:t.dev ~cmd:(selector "commandBuffer") ~typ:(returning id) in
    let encoder =
      msg_send ~self:command_buffer ~cmd:(selector "computeCommandEncoder") ~typ:(returning id)
    in
    msg_send ~self:encoder
      ~cmd:(selector "setComputePipelineState:")
      ~typ:(id @-> returning void)
      t.pipeline_state;

    List.iteri
      (fun i buf ->
        msg_send ~self:encoder
          ~cmd:(selector "setBuffer:offset:atIndex:")
          ~typ:(id @-> int @-> int @-> returning void)
          buf.buf buf.offset i)
      bufs;

    List.iteri
      (fun i value ->
        let bytes = Bytes.create 4 in
        Bytes.set_int32_le bytes 0 (Int32.of_int value);
        msg_send ~self:encoder
          ~cmd:(selector "setBytes:length:atIndex:")
          ~typ:(string @-> int @-> int @-> returning void)
          (Bytes.to_string bytes) 4
          (List.length bufs + i))
      vals;

    msg_send ~self:encoder
      ~cmd:(selector "dispatchThreadgroups:threadsPerThreadgroup:")
      ~typ:(id @-> id @-> returning void)
      (new_string (String.concat "," (List.map string_of_int global_size)))
      (new_string (String.concat "," (List.map string_of_int local_size)));

    msg_send ~self:encoder ~cmd:(selector "endEncoding") ~typ:(returning void);
    msg_send ~self:command_buffer ~cmd:(selector "setLabel:")
      ~typ:(id @-> returning void)
      (new_string t.name);
    msg_send ~self:command_buffer ~cmd:(selector "commit") ~typ:(returning void);

    if wait then
      msg_send ~self:command_buffer ~cmd:(selector "waitUntilCompleted") ~typ:(returning void);
    ()
end

module Buffer = struct
  type t = { buf : id; size : int; offset : int }

  let create buf size offset = { buf; size; offset }
end

module Allocator = struct
  type t = { dev : id; buffers : (int, Buffer.t) Hashtbl.t }

  let create dev = { dev; buffers = Hashtbl.create 10 }

  let alloc t size options =
    if options.external_ptr then Buffer.create (objc_id options.external_ptr) size 0
    else
      let buf =
        msg_send ~self:t.dev
          ~cmd:(selector "newBufferWithLength:options:")
          ~typ:(int @-> int @-> returning id)
          size ResourceOptions.mtl_resource_storage_mode_shared
      in
      if is_nil buf then failwith (Printf.sprintf "Metal OOM while allocating size=%d" size);
      Buffer.create buf size 0

  let free t buf = msg_send ~self:buf.Buffer.buf ~cmd:(selector "release") ~typ:(returning void)

  let transfer t dest src sz src_dev dest_dev =
    msg_send ~self:dest_dev ~cmd:(selector "synchronize") ~typ:(returning void);
    let src_command_buffer =
      msg_send ~self:src_dev ~cmd:(selector "commandBuffer") ~typ:(returning id)
    in
    let encoder =
      msg_send ~self:src_command_buffer ~cmd:(selector "blitCommandEncoder") ~typ:(returning id)
    in
    msg_send ~self:encoder
      ~cmd:(selector "copyFromBuffer:sourceOffset:toBuffer:destinationOffset:size:")
      ~typ:(id @-> int @-> id @-> int @-> int @-> returning void)
      src.Buffer.buf src.Buffer.offset dest.Buffer.buf dest.Buffer.offset sz;
    msg_send ~self:encoder ~cmd:(selector "endEncoding") ~typ:(returning void);
    msg_send ~self:src_command_buffer ~cmd:(selector "commit") ~typ:(returning void);
    ()
end
