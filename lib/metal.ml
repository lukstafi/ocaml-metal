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

  let sexp_of_t t =
    let device = Objc.msg_send ~self:t ~cmd:(selector "name") ~typ:(returning Objc.id) in
    let name = ocaml_string_from_nsstring device in
    Sexplib0.Sexp.Atom name

  let create_system_default () =
    let device = Foreign.foreign "MTLCreateSystemDefaultDevice" (void @-> returning Objc.id) () in
    if is_nil device then failwith "Failed to create Metal device";
    device
end

module CommandQueue = struct
  type t = id

  let sexp_of_t t =
    let device_id = Objc.msg_send ~self:t ~cmd:(selector "device") ~typ:(returning Objc.id) in
    let device_sexp =
      if is_nil device_id then Sexplib0.Sexp.Atom "<no device>"
      else Device.sexp_of_t device_id
    in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLCommandQueue>";
                       Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "device"; device_sexp]]

  let command_buffer self =
    let command_buffer =
      Objc.msg_send ~self ~cmd:(selector "commandBuffer") ~typ:(returning Objc.id)
    in
    if is_nil command_buffer then failwith "Failed to create Metal command buffer";
    command_buffer
    
  let on_device self =
    let command_queue =
      Objc.msg_send ~self ~cmd:(selector "newCommandQueue") ~typ:(returning Objc.id)
    in
    if is_nil command_queue then failwith "Failed to create Metal command queue";
    command_queue
end

module ResourceOptions = struct
  type t = Unsigned.ULLong.t

  let sexp_of_t t =
    Sexplib0.Sexp.Atom (Unsigned.ULLong.to_string t)

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

    let sexp_of_t v =
      let open Sexplib0.Sexp in
      if Unsigned.ULLong.equal v version_1_0 then Atom "Version_1_0"
      else if Unsigned.ULLong.equal v version_1_1 then Atom "Version_1_1"
      else if Unsigned.ULLong.equal v version_1_2 then Atom "Version_1_2"
      else if Unsigned.ULLong.equal v version_2_0 then Atom "Version_2_0"
      else if Unsigned.ULLong.equal v version_2_1 then Atom "Version_2_1"
      else if Unsigned.ULLong.equal v version_2_2 then Atom "Version_2_2"
      else if Unsigned.ULLong.equal v version_2_3 then Atom "Version_2_3"
      else if Unsigned.ULLong.equal v version_2_4 then Atom "Version_2_4"
      else if Unsigned.ULLong.equal v version_3_0 then Atom "Version_3_0"
      else if Unsigned.ULLong.equal v version_3_1 then Atom "Version_3_1"
      else Atom ("Unknown_Version_" ^ Unsigned.ULLong.to_string v)
  end

  module LibraryType = struct
    type t = Unsigned.ULLong.t

    let executable = Unsigned.ULLong.of_int 0
    let dynamic = Unsigned.ULLong.of_int 1

    let sexp_of_t v =
      let open Sexplib0.Sexp in
      if Unsigned.ULLong.equal v executable then Atom "Executable"
      else if Unsigned.ULLong.equal v dynamic then Atom "Dynamic"
      else Atom ("Unknown_LibraryType_" ^ Unsigned.ULLong.to_string v)
  end

  module OptimizationLevel = struct
    type t = Unsigned.ULLong.t

    let default = Unsigned.ULLong.of_int 0
    let size = Unsigned.ULLong.of_int 1
    let performance = Unsigned.ULLong.of_int 2

    let sexp_of_t v =
      let open Sexplib0.Sexp in
      if Unsigned.ULLong.equal v default then Atom "Default"
      else if Unsigned.ULLong.equal v size then Atom "Size"
      else if Unsigned.ULLong.equal v performance then Atom "Performance"
      else Atom ("Unknown_OptimizationLevel_" ^ Unsigned.ULLong.to_string v)
  end

  let set_fast_math_enabled self enabled =
    Objc.msg_send ~self ~cmd:(selector "setFastMathEnabled:") ~typ:(bool @-> returning void) enabled

  let get_fast_math_enabled self =
    Objc.msg_send ~self ~cmd:(selector "fastMathEnabled") ~typ:(returning bool)

  let set_language_version self version =
    Objc.msg_send ~self ~cmd:(selector "setLanguageVersion:")
      ~typ:(ullong @-> returning void)
      version

  let get_language_version self =
    Objc.msg_send ~self ~cmd:(selector "languageVersion") ~typ:(returning ullong)

  let set_library_type self library_type =
    Objc.msg_send ~self ~cmd:(selector "setLibraryType:")
      ~typ:(ullong @-> returning void)
      library_type

  let get_library_type self =
    Objc.msg_send ~self ~cmd:(selector "libraryType") ~typ:(returning ullong)

  let set_optimization_level self level =
    Objc.msg_send ~self
      ~cmd:(selector "setOptimizationLevel:")
      ~typ:(ullong @-> returning void)
      level

  let get_optimization_level self =
    Objc.msg_send ~self ~cmd:(selector "optimizationLevel") ~typ:(returning ullong)

  let sexp_of_t t =
    let fast_math = get_fast_math_enabled t in
    let lang_version_val = get_language_version t in
    let lib_type_val = get_library_type t in
    let opt_level_val = get_optimization_level t in
    Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "<MTLCompileOptions>";
                         Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "fast_math"; Sexplib0.Sexp.Atom (Bool.to_string fast_math) ];
                         Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "language_version"; LanguageVersion.sexp_of_t lang_version_val ];
                         Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "library_type"; LibraryType.sexp_of_t lib_type_val ];
                         Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "optimization_level"; OptimizationLevel.sexp_of_t opt_level_val ];
                       ]
end

module Buffer = struct
  type t = id

  let sexp_of_t t =
    let len = Objc.msg_send ~self:t ~cmd:(selector "length") ~typ:(returning ulong) in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLBuffer>";
                       Sexplib0.Sexp.Atom ("length: " ^ Unsigned.ULong.to_string len)]

  let contents self = Objc.msg_send ~self ~cmd:(selector "contents") ~typ:(returning (ptr void))
  let length self = Objc.msg_send ~self ~cmd:(selector "length") ~typ:(returning ulong)

  module NSRange = struct
    type nsrange
    type t = nsrange structure ptr

    let t : nsrange structure typ = structure "NSRange"
    let location_field = field t "location" ulong
    let length_field = field t "length" ulong
    let () = seal t
    let location range = getf !@range location_field
    let length range = getf !@range length_field

    let sexp_of_t range_ptr =
      if is_null range_ptr then Sexplib0.Sexp.Atom "<null NSRange>" (* Check pointer itself *)
      else
        let loc = location range_ptr in (* Use existing helper *)
        let len = length range_ptr in (* Use existing helper *)
        Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "NSRange";
                             Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "location"; Sexplib0.Sexp.Atom (Unsigned.ULong.to_string loc) ];
                             Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "length"; Sexplib0.Sexp.Atom (Unsigned.ULong.to_string len) ];
                           ]

    let make ~location:(loc : int) ~length:(len : int) =
      let s = make t in
      setf s location_field (Unsigned.ULong.of_int loc);
      setf s length_field (Unsigned.ULong.of_int len);
      s.structured
  end

  let did_modify_range self range_struct =
    Objc.msg_send ~self ~cmd:(selector "didModifyRange:")
      ~typ:(NSRange.t @-> returning void)
      !@range_struct
      
  let on_device self ~length options =
    let buffer =
      Objc.msg_send ~self
        ~cmd:(selector "newBufferWithLength:options:")
        ~typ:(ulong @-> ullong @-> returning Objc.id)
        (Unsigned.ULong.of_int length) options
    in
    if is_nil buffer then failwith "Failed to create Metal buffer";
    buffer
end

module CommandBuffer = struct
  type t = id

  let sexp_of_t t =
    let label_id = Objc.msg_send ~self:t ~cmd:(selector "label") ~typ:(returning Objc.id) in
    let label = ocaml_string_from_nsstring label_id in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLCommandBuffer>";
                       Sexplib0.Sexp.Atom ("label: " ^ if label = "" then "<no label>" else label)]

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

  let encode_signal_event self event value =
    Objc.msg_send ~self
      ~cmd:(selector "encodeSignalEvent:value:")
      ~typ:(Objc.id @-> ullong @-> returning void)
      event value

  let encode_wait_for_event self event value =
    Objc.msg_send ~self
      ~cmd:(selector "encodeWaitForEvent:value:")
      ~typ:(Objc.id @-> ullong @-> returning void)
      event value
end

module CommandEncoder = struct
  type t = id

  let sexp_of_t t =
    let label_id = Objc.msg_send ~self:t ~cmd:(selector "label") ~typ:(returning Objc.id) in
    let label = ocaml_string_from_nsstring label_id in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLCommandEncoder>";
                       Sexplib0.Sexp.Atom ("label: " ^ if label = "" then "<no label>" else label)]

  let end_encoding self = Objc.msg_send ~self ~cmd:(selector "endEncoding") ~typ:(returning void)

  let label self =
    Objc.msg_send ~self ~cmd:(selector "label") ~typ:(returning Objc.id)
    |> ocaml_string_from_nsstring

  let set_label self label_str =
    Objc.msg_send ~self ~cmd:(selector "setLabel:")
      ~typ:(Objc.id @-> returning void)
      (new_string label_str)
end

(* Fences *)
module Fence = struct
  type t = id

  let sexp_of_t t =
    let label_id = Objc.msg_send ~self:t ~cmd:(selector "label") ~typ:(returning Objc.id) in
    let label = ocaml_string_from_nsstring label_id in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLFence>";
                       Sexplib0.Sexp.Atom ("label: " ^ if label = "" then "<no label>" else label)]

  let device self = Objc.msg_send ~self ~cmd:(selector "device") ~typ:(returning Objc.id)

  let label self =
    Objc.msg_send ~self ~cmd:(selector "label") ~typ:(returning Objc.id)
    |> ocaml_string_from_nsstring

  let set_label self label_str =
    Objc.msg_send ~self ~cmd:(selector "setLabel:")
      ~typ:(Objc.id @-> returning void)
      (new_string label_str)
      
  let on_device self =
    let fence = Objc.msg_send ~self ~cmd:(selector "newFence") ~typ:(returning Objc.id) in
    if is_nil fence then failwith "Failed to create Metal fence";
    fence
    
  let get_device = device
end

module BlitCommandEncoder = struct
  type t = id

  let sexp_of_t t =
    let label_id = Objc.msg_send ~self:t ~cmd:(selector "label") ~typ:(returning Objc.id) in
    let label = ocaml_string_from_nsstring label_id in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLBlitCommandEncoder>";
                       Sexplib0.Sexp.Atom ("label: " ^ if label = "" then "<no label>" else label)]

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

  let update_fence self (fence : Fence.t) =
    Objc.msg_send ~self ~cmd:(selector "updateFence:") ~typ:(Objc.id @-> returning void) fence

  let wait_for_fence self (fence : Fence.t) =
    Objc.msg_send ~self ~cmd:(selector "waitForFence:") ~typ:(Objc.id @-> returning void) fence

  let signal_event self event value =
    Objc.msg_send ~self ~cmd:(selector "signalEvent:value:")
      ~typ:(Objc.id @-> ullong @-> returning void)
      event value

  let wait_for_event self event value =
    Objc.msg_send ~self ~cmd:(selector "waitForEvent:value:")
      ~typ:(Objc.id @-> ullong @-> returning void)
      event value
end

module Library = struct
  type t = id

  let sexp_of_t t =
    (* Libraries don't have a simple name property accessible directly.
       We could get the device and its name, or function names, but let's keep it simple. *)
    let device_id = Objc.msg_send ~self:t ~cmd:(selector "device") ~typ:(returning Objc.id) in
    let device_name =
      if is_nil device_id then "<no device>"
      else Device.sexp_of_t device_id |> Sexplib0.Sexp.to_string
    in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLLibrary>";
                       Sexplib0.Sexp.Atom ("device: " ^ device_name)]

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
    
  let on_device self ~source options =
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
end

module Function = struct
  type t = id

  let sexp_of_t t =
    let name_id = Objc.msg_send ~self:t ~cmd:(selector "name") ~typ:(returning Objc.id) in
    let name = ocaml_string_from_nsstring name_id in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLFunction>";
                       Sexplib0.Sexp.Atom ("name: " ^ name)]

  let name self =
    Objc.msg_send ~self ~cmd:(selector "name") ~typ:(returning Objc.id)
    |> ocaml_string_from_nsstring
end

module ComputePipelineState = struct
  type t = id

  let sexp_of_t t =
    let label_id = Objc.msg_send ~self:t ~cmd:(selector "label") ~typ:(returning Objc.id) in
    let label = ocaml_string_from_nsstring label_id in
    let device_id = Objc.msg_send ~self:t ~cmd:(selector "device") ~typ:(returning Objc.id) in
    let device_name =
      if is_nil device_id then "<no device>"
      else Device.sexp_of_t device_id |> Sexplib0.Sexp.to_string
    in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLComputePipelineState>";
                       Sexplib0.Sexp.Atom ("label: " ^ if label = "" then "<no label>" else label);
                       Sexplib0.Sexp.Atom ("device: " ^ device_name)]

  let max_total_threads_per_threadgroup self =
    Objc.msg_send ~self ~cmd:(selector "maxTotalThreadsPerThreadgroup") ~typ:(returning ulong)

  let thread_execution_width self =
    Objc.msg_send ~self ~cmd:(selector "threadExecutionWidth") ~typ:(returning ulong)

  let on_device self compute_function =
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

module ComputeCommandEncoder = struct
  type t = id

  let sexp_of_t t =
    let label_id = Objc.msg_send ~self:t ~cmd:(selector "label") ~typ:(returning Objc.id) in
    let label = ocaml_string_from_nsstring label_id in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLComputeCommandEncoder>";
                       Sexplib0.Sexp.Atom ("label: " ^ if label = "" then "<no label>" else label)]

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
    type mtlsize
    type t = mtlsize structure ptr

    let t : mtlsize structure typ = structure "MTLSize"
    let width_field = field t "width" ulong
    let height_field = field t "height" ulong
    let depth_field = field t "depth" ulong
    let () = seal t
    let width size = getf !@size width_field
    let height size = getf !@size height_field
    let depth size = getf !@size depth_field

    let make ~width:(w : int) ~height:(h : int) ~depth:(d : int) =
      (* Expect int *)
      let s = make t in
      setf s width_field (Unsigned.ULong.of_int w);
      (* Convert to ulong *)
      setf s height_field (Unsigned.ULong.of_int h);
      (* Convert to ulong *)
      setf s depth_field (Unsigned.ULong.of_int d);
      (* Convert to ulong *)
      s.structured
  end

  module Region = struct
    type mtlregion
    type t = mtlregion structure ptr

    let t : mtlregion structure typ = structure "MTLRegion"
    let origin_field = field t "origin" Size.t (* MTLOrigin is {x,y,z} ulongs, same struct *)
    let size_field = field t "size" Size.t (* MTLSize is {width,height,depth} ulongs *)
    let () = seal t
    let origin region = (getf !@region origin_field).structured
    let size region = (getf !@region size_field).structured

    let make ~(ox : int) ~(oy : int) ~(oz : int) ~(sx : int) ~(sy : int) ~(sz : int) =
      (* Expect int *)
      let r = make t in
      let origin_val = Size.make ~width:ox ~height:oy ~depth:oz in
      let size_val = Size.make ~width:sx ~height:sy ~depth:sz in
      setf r origin_field !@origin_val;
      setf r size_field !@size_val;
      r.structured
  end

  let dispatch_threads self ~threads_per_grid ~threads_per_threadgroup =
    Objc.msg_send ~self
      ~cmd:(selector "dispatchThreads:threadsPerThreadgroup:")
      ~typ:(Size.t @-> Size.t @-> returning void)
      !@threads_per_grid !@threads_per_threadgroup

  let dispatch_threadgroups self ~threadgroups_per_grid ~threads_per_threadgroup =
    Objc.msg_send ~self
      ~cmd:(selector "dispatchThreadgroups:threadsPerThreadgroup:")
      ~typ:(Size.t @-> Size.t @-> returning void)
      !@threadgroups_per_grid !@threads_per_threadgroup

  let update_fence self (fence : Fence.t) =
    Objc.msg_send ~self ~cmd:(selector "updateFence:") ~typ:(Objc.id @-> returning void) fence

  let wait_for_fence self (fence : Fence.t) =
    Objc.msg_send ~self ~cmd:(selector "waitForFence:") ~typ:(Objc.id @-> returning void) fence

  let signal_event self event value =
    Objc.msg_send ~self ~cmd:(selector "signalEvent:value:")
      ~typ:(Objc.id @-> ullong @-> returning void)
      event value

  let wait_for_event self event value =
    Objc.msg_send ~self ~cmd:(selector "waitForEvent:value:")
      ~typ:(Objc.id @-> ullong @-> returning void)
      event value
end

(* Events *)
module SharedEventHandle = struct
  type t = id

  let sexp_of_t t =
    let label_id = Objc.msg_send ~self:t ~cmd:(selector "label") ~typ:(returning Objc.id) in
    let label = ocaml_string_from_nsstring label_id in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLSharedEventHandle>";
                       Sexplib0.Sexp.Atom ("label: " ^ if label = "" then "<no label>" else label)]

  let label self =
    Objc.msg_send ~self ~cmd:(selector "label") ~typ:(returning Objc.id)
    |> ocaml_string_from_nsstring

  (* Note: MTLSharedEventHandle conforms to NSSecureCoding, but adding full serialization might
     require more Foundation bindings or specific use cases. *)
end

module SharedEventListener = struct
  type t = id

  let sexp_of_t _t =
    (* Listeners don't have identifying properties like labels *)
    Sexplib0.Sexp.Atom "<MTLSharedEventListener>"

  let init () =
    let cls = Objc.get_class "MTLSharedEventListener" in
    Objc.msg_send ~self:cls ~cmd:(selector "alloc") ~typ:(returning Objc.id) |> fun allocated_obj ->
    Objc.msg_send ~self:allocated_obj ~cmd:(selector "init") ~typ:(returning Objc.id)

  (* init_with_dispatch_queue requires binding dispatch_queue_t, skipping for now *)
end

module SharedEvent = struct
  type t = id

  let sexp_of_t t =
    let label_id = Objc.msg_send ~self:t ~cmd:(selector "label") ~typ:(returning Objc.id) in
    let label = ocaml_string_from_nsstring label_id in
    let signaled_val = Objc.msg_send ~self:t ~cmd:(selector "signaledValue") ~typ:(returning ullong) in
    Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "<MTLSharedEvent>";
                       Sexplib0.Sexp.Atom ("label: " ^ if label = "" then "<no label>" else label);
                       Sexplib0.Sexp.Atom ("signaledValue: " ^ Unsigned.ULLong.to_string signaled_val)]

  let signaled_value self =
    Objc.msg_send ~self ~cmd:(selector "signaledValue") ~typ:(returning ullong)

  let label self =
    Objc.msg_send ~self ~cmd:(selector "label") ~typ:(returning Objc.id)
    |> ocaml_string_from_nsstring

  let set_label self label_str =
    Objc.msg_send ~self ~cmd:(selector "setLabel:")
      ~typ:(Objc.id @-> returning void)
      (new_string label_str)

  let new_shared_event_handle self =
    let handle =
      Objc.msg_send ~self ~cmd:(selector "newSharedEventHandle") ~typ:(returning Objc.id)
    in
    if is_nil handle then failwith "Failed to create Metal shared event handle";
    handle

  let notify_listener (self : t) (listener : SharedEventListener.t) (value : Unsigned.ullong)
      (callback : SharedEventListener.t -> Unsigned.ullong -> unit) =
    (* block signature: void (^)(MTLSharedEvent*, uint64_t)) *)
    let block_callback _self event value = callback event value in
    let block =
      (* Objc_type redefines the list constructors *)
      Block.make block_callback
        ~args:Objc_type.([ id (* event *); ullong (* value *) ])
        ~return:Objc_type.void
    in
    Objc.msg_send ~self
      ~cmd:(selector "notifyListener:atValue:block:")
      ~typ:(Objc.id @-> ullong @-> ptr void @-> returning void)
      listener value block
      
  let on_device self =
    let event = Objc.msg_send ~self ~cmd:(selector "newSharedEvent") ~typ:(returning Objc.id) in
    if is_nil event then failwith "Failed to create Metal shared event";
    event
end
