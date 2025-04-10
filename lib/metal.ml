open Runtime
open Ctypes
module CG = CoreGraphics

type id = Objc.objc_object structure Ctypes_static.ptr

let nil_ptr : id ptr = coerce (ptr void) (ptr Objc.id) null

(* Helper to convert NSString to OCaml string *)
let ocaml_string_from_nsstring nsstring_id =
  if is_nil nsstring_id then ""
  else Objc.msg_send ~self:nsstring_id ~cmd:(selector "UTF8String") ~typ:(returning string)

let from_nsarray nsarray_id =
  if is_nil nsarray_id then [||]
  else
    let count = Objc.msg_send ~self:nsarray_id ~cmd:(selector "count") ~typ:(returning size_t) in
    let count_int = Unsigned.Size_t.to_int count in
    Array.init count_int (fun i ->
        let obj_id =
          Objc.msg_send ~self:nsarray_id ~cmd:(selector "objectAtIndex:")
            ~typ:(ulong @-> returning Objc.id)
            (Unsigned.ULong.of_int i)
        in
        obj_id (* Or further processing if needed *))

(* Error Handling Helper *)
let get_error_description nserror =
  if is_nil nserror then "No error"
  else
    let localized_description =
      Objc.msg_send ~self:nserror ~cmd:(selector "localizedDescription") ~typ:(returning Objc.id)
    in
    if is_nil localized_description then "Unknown error (no description)"
    else ocaml_string_from_nsstring localized_description

(* Check error pointer immediately after the call *)
let check_error label (err_ptr : id ptr) =
  (* Dereference to get the ptr id *)
  assert (not (is_nil err_ptr));
  (* Check if the pointer itself is nil *)
  let error_id : id = !@err_ptr in
  (* Dereference the non-nil pointer to get the id *)
  if is_nil error_id then Printf.printf "%s completed successfully (no error object set).\n" label
  else
    let desc = get_error_description error_id in
    failwith (Printf.sprintf "%s failed: %s" label desc)

module Device = struct
  type t = id

  let create_system_default () =
    let device = Foreign.foreign "MTLCreateSystemDefaultDevice" (void @-> returning Objc.id) () in
    if is_nil device then failwith "Failed to create Metal device";
    device

  let new_command_queue self =
    let command_queue =
      Objc.msg_send ~self ~cmd:(selector "newCommandQueue") ~typ:(returning Objc.id)
    in
    if is_nil command_queue then failwith "Failed to create Metal command queue";
    command_queue

  let new_buffer_with_length self length options =
    let buffer =
      Objc.msg_send ~self
        ~cmd:(selector "newBufferWithLength:options:")
        ~typ:(ulong @-> ullong @-> returning Objc.id)
        (Unsigned.ULong.of_int length) options
    in
    if is_nil buffer then failwith "Failed to create Metal buffer";
    buffer

  let new_library_with_source self source options =
    (* Allocate a pointer for potential error object (NSError** ) *)
    let error_ptr = allocate Objc.id nil in
    let library =
      Objc.msg_send ~self
        ~cmd:(selector "newLibraryWithSource:options:error:")
        ~typ:(Objc.id @-> Objc.id @-> ptr Objc.id @-> returning Objc.id)
        (new_string source) options error_ptr
    in
    check_error "Library creation" error_ptr;
    (* Also check if the returned library object itself is nil *)
    if is_nil library then failwith "Failed to create Metal library";
    library

  let new_compute_pipeline_state_with_function self compute_function =
    (* Allocate a pointer for potential error object (NSError** ) *)
    let error_ptr = allocate Objc.id nil in
    let compute_pipeline_state =
      Objc.msg_send ~self
        ~cmd:(selector "newComputePipelineStateWithFunction:error:")
        ~typ:(Objc.id @-> ptr Objc.id @-> returning Objc.id)
        compute_function error_ptr
    in
    check_error "Compute pipeline state creation" error_ptr;
    (* Also check if the returned pipeline state object itself is nil *)
    if is_nil compute_pipeline_state then
      failwith "Failed to create Metal compute pipeline state without setting an error";
    compute_pipeline_state
end

module CommandQueue = struct
  type t = id

  let command_buffer self =
    let command_buffer =
      Objc.msg_send ~self ~cmd:(selector "commandBuffer") ~typ:(returning Objc.id)
    in
    if is_nil command_buffer then failwith "Failed to create Metal command buffer";
    command_buffer
end

module ResourceOptions = struct
  type t = Unsigned.ULLong.t

  let ullong = ullong
  let storage_mode_shared = Unsigned.ULLong.of_int 0
  let storage_mode_managed = Unsigned.ULLong.of_int 16 (* MTLStorageModeManaged = 1 << 4 *)
  let storage_mode_private = Unsigned.ULLong.of_int 32 (* MTLStorageModePrivate = 2 << 4 *)
  let cpu_cache_mode_default_cache = Unsigned.ULLong.of_int 0
  let cpu_cache_mode_write_combined = Unsigned.ULLong.of_int 1

  (* Combine options using Bitmask *)
  let ( + ) = Unsigned.ULLong.logor
end

module CompileOptions = struct
  type t = id

  let init () =
    let cls = Objc.get_class "MTLCompileOptions" in
    Objc.msg_send ~self:cls ~cmd:(selector "alloc") ~typ:(returning Objc.id) |> fun allocated_obj ->
    Objc.msg_send ~self:allocated_obj ~cmd:(selector "init") ~typ:(returning Objc.id)

  module LanguageVersion = struct
    type t = Unsigned.ULLong.t

    let version_1_0 = Unsigned.ULLong.of_int 0 (* Deprecated *)
    let version_1_1 = Unsigned.ULLong.of_int 65537
    let version_1_2 = Unsigned.ULLong.of_int 65538
    let version_2_0 = Unsigned.ULLong.of_int 131072
    let version_2_1 = Unsigned.ULLong.of_int 131073
    let version_2_2 = Unsigned.ULLong.of_int 131074
    let version_2_3 = Unsigned.ULLong.of_int 131075
    let version_2_4 = Unsigned.ULLong.of_int 131076
    let version_3_0 = Unsigned.ULLong.of_int 196608
    let version_3_1 = Unsigned.ULLong.of_int 196609
  end

  module LibraryType = struct
    type t = Unsigned.ULLong.t

    let executable = Unsigned.ULLong.of_int 0
    let dynamic = Unsigned.ULLong.of_int 1
  end

  module OptimizationLevel = struct
    type t = Unsigned.ULLong.t

    let default = Unsigned.ULLong.of_int 0
    let size = Unsigned.ULLong.of_int 1
    let performance = Unsigned.ULLong.of_int 2
  end

  let set_fast_math_enabled self enabled =
    Objc.msg_send ~self ~cmd:(selector "setFastMathEnabled:") ~typ:(bool @-> returning void) enabled

  let set_language_version self version =
    Objc.msg_send ~self ~cmd:(selector "setLanguageVersion:")
      ~typ:(ullong @-> returning void)
      version

  let set_library_type self library_type =
    Objc.msg_send ~self ~cmd:(selector "setLibraryType:")
      ~typ:(ullong @-> returning void)
      library_type

  let set_optimization_level self level =
    Objc.msg_send ~self
      ~cmd:(selector "setOptimizationLevel:")
      ~typ:(ullong @-> returning void)
      level

  (* Getters can be added similarly if needed *)
end

module Buffer = struct
  type t = id

  let contents self = Objc.msg_send ~self ~cmd:(selector "contents") ~typ:(returning (ptr void))
  let length self = Objc.msg_send ~self ~cmd:(selector "length") ~typ:(returning ulong)

  module NSRange = struct
    type t

    let t : t structure typ = structure "NSRange"
    let location = field t "location" ulong
    let length = field t "length" ulong
    let () = seal t

    let make ~location:(loc : int) ~length:(len : int) =
      let s = make t in
      setf s location (Unsigned.ULong.of_int loc);
      setf s length (Unsigned.ULong.of_int len);
      s
  end

  let did_modify_range self range_struct =
    Objc.msg_send ~self ~cmd:(selector "didModifyRange:")
      ~typ:(NSRange.t @-> returning void)
      range_struct
end

module CommandBuffer = struct
  type t = id

  let commit self = Objc.msg_send ~self ~cmd:(selector "commit") ~typ:(returning void)

  let wait_until_completed self =
    Objc.msg_send ~self ~cmd:(selector "waitUntilCompleted") ~typ:(returning void)

  let blit_command_encoder self =
    Objc.msg_send ~self ~cmd:(selector "blitCommandEncoder") ~typ:(returning Objc.id)

  let compute_command_encoder self =
    let compute_command_encoder =
      Objc.msg_send ~self ~cmd:(selector "computeCommandEncoder") ~typ:(returning Objc.id)
    in
    if is_nil compute_command_encoder then failwith "Failed to create Metal compute command encoder";
    compute_command_encoder

  let add_completed_handler self handler_block =
    (* block signature: void (^)(id<MTLCommandBuffer>)) *)
    let block = Block.make handler_block ~args:[ Objc_type.id ] ~return:Objc_type.void in
    Objc.msg_send ~self ~cmd:(selector "addCompletedHandler:")
      ~typ:(ptr void @-> returning void) (* Pass block as ptr void *)
      block

  let error self = Objc.msg_send ~self ~cmd:(selector "error") ~typ:(returning Objc.id)
end

module CommandEncoder = struct
  type t = id

  let end_encoding self = Objc.msg_send ~self ~cmd:(selector "endEncoding") ~typ:(returning void)

  let label self =
    Objc.msg_send ~self ~cmd:(selector "label") ~typ:(returning Objc.id)
    |> ocaml_string_from_nsstring

  let set_label self label_str =
    Objc.msg_send ~self ~cmd:(selector "setLabel:")
      ~typ:(Objc.id @-> returning void)
      (new_string label_str)
end

module BlitCommandEncoder = struct
  type t = id

  (* Inherits from CommandEncoder *)
  let end_encoding = CommandEncoder.end_encoding
  let set_label = CommandEncoder.set_label
  let label = CommandEncoder.label

  let copy_from_buffer ~self ~source_buffer ~source_offset ~destination_buffer ~destination_offset
      ~size =
    Objc.msg_send ~self
      ~cmd:(selector "copyFromBuffer:sourceOffset:toBuffer:destinationOffset:size:")
      ~typ:(Objc.id @-> ulong @-> Objc.id @-> ulong @-> ulong @-> returning void)
      source_buffer
      (Unsigned.ULong.of_int source_offset)
      destination_buffer
      (Unsigned.ULong.of_int destination_offset)
      (Unsigned.ULong.of_int size)

  let synchronize_resource ~self ~resource =
    Objc.msg_send ~self ~cmd:(selector "synchronizeResource:")
      ~typ:(Objc.id @-> returning void)
      resource (* Resource is MTLResource, Buffer is one *)
end

module Library = struct
  type t = id

  let new_function_with_name self name =
    let function_name =
      Objc.msg_send ~self ~cmd:(selector "newFunctionWithName:")
        ~typ:(Objc.id @-> returning Objc.id)
        (new_string name)
    in
    if is_nil function_name then failwith "Failed to create Metal function";
    function_name

  let function_names self =
    let ns_array = Objc.msg_send ~self ~cmd:(selector "functionNames") ~typ:(returning Objc.id) in
    from_nsarray ns_array |> Array.map ocaml_string_from_nsstring
end

module Function = struct
  type t = id

  let name self =
    Objc.msg_send ~self ~cmd:(selector "name") ~typ:(returning Objc.id)
    |> ocaml_string_from_nsstring
end

module ComputePipelineState = struct
  type t = id

  let max_total_threads_per_threadgroup self =
    Objc.msg_send ~self ~cmd:(selector "maxTotalThreadsPerThreadgroup") ~typ:(returning ulong)

  let thread_execution_width self =
    Objc.msg_send ~self ~cmd:(selector "threadExecutionWidth") ~typ:(returning ulong)
end

module ComputeCommandEncoder = struct
  type t = id

  (* Inherits from CommandEncoder *)
  let end_encoding = CommandEncoder.end_encoding
  let set_label = CommandEncoder.set_label
  let label = CommandEncoder.label

  let set_compute_pipeline_state self state =
    Objc.msg_send ~self
      ~cmd:(selector "setComputePipelineState:")
      ~typ:(Objc.id @-> returning void)
      state

  let set_buffer self buffer offset index =
    Objc.msg_send ~self
      ~cmd:(selector "setBuffer:offset:atIndex:")
      ~typ:(Objc.id @-> ulong @-> ulong @-> returning void)
      buffer (Unsigned.ULong.of_int offset) (Unsigned.ULong.of_int index)

  module Size = struct
    type t

    let t : t structure typ = structure "MTLSize"
    let width = field t "width" ulong
    let height = field t "height" ulong
    let depth = field t "depth" ulong
    let () = seal t

    let make ~width:(w : int) ~height:(h : int) ~depth:(d : int) =
      (* Expect int *)
      let s = make t in
      setf s width (Unsigned.ULong.of_int w);
      (* Convert to ulong *)
      setf s height (Unsigned.ULong.of_int h);
      (* Convert to ulong *)
      setf s depth (Unsigned.ULong.of_int d);
      (* Convert to ulong *)
      s
  end

  module Region = struct
    type t

    let t : t structure typ = structure "MTLRegion"
    let origin = field t "origin" Size.t (* MTLOrigin is {x,y,z} ulongs, same struct *)
    let size = field t "size" Size.t (* MTLSize is {width,height,depth} ulongs *)
    let () = seal t

    let make ~(ox : int) ~(oy : int) ~(oz : int) ~(sx : int) ~(sy : int) ~(sz : int) =
      (* Expect int *)
      let r = make t in
      let origin_val = Size.make ~width:ox ~height:oy ~depth:oz in
      let size_val = Size.make ~width:sx ~height:sy ~depth:sz in
      setf r origin origin_val;
      setf r size size_val;
      r
  end

  let dispatch_threads self threads_per_grid threads_per_threadgroup =
    Objc.msg_send ~self
      ~cmd:(selector "dispatchThreads:threadsPerThreadgroup:")
      ~typ:(Size.t @-> Size.t @-> returning void)
      threads_per_grid threads_per_threadgroup

  let dispatch_threadgroups self threadgroups_per_grid threads_per_threadgroup =
    Objc.msg_send ~self
      ~cmd:(selector "dispatchThreadgroups:threadsPerThreadgroup:")
      ~typ:(Size.t @-> Size.t @-> returning void)
      threadgroups_per_grid threads_per_threadgroup
end
