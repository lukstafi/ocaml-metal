open Runtime
open Ctypes
module CG = CoreGraphics
open Sexplib0.Sexp_conv

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
  if not (is_nil error_id) then
    let desc = get_error_description error_id in
    failwith (Printf.sprintf "%s failed: %s" label desc)

(* Define NSRange struct type for use in methods that take ranges *)
module NSRange = struct
  type t

  let t : t structure typ = structure "NSRange"
  let location = field t "location" uint
  let length = field t "length" uint
  let () = seal t
end

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

  (* NEW: Attributes Record and related types *)
  type device_size = { width : int; height : int; depth : int } [@@deriving sexp_of]

  module ArgumentBuffersTier = struct
    type t = Tier1 | Tier2 [@@deriving sexp_of]

    let from_llong (i : Signed.LLong.t) =
      if Signed.LLong.equal i (Signed.LLong.of_int 0) then Tier1
      else if Signed.LLong.equal i (Signed.LLong.of_int 1) then Tier2
      else invalid_arg ("Unknown ArgumentBuffersTier: " ^ Signed.LLong.to_string i)
  end

  (* Define the MTLSize struct type locally for use in get_attributes *)
  type mtlsize

  let mtlsize_t : mtlsize structure typ = structure "MTLSize"
  let width_field = field mtlsize_t "width" ulong
  let height_field = field mtlsize_t "height" ulong
  let depth_field = field mtlsize_t "depth" ulong
  let () = seal mtlsize_t

  open Sexplib0.Sexp_conv (* Open standard converters for @@deriving sexp_of *)

  (* Provide local modules with manual sexp converters for Unsigned types *)
  type ulong = Unsigned.ULong.t

  let sexp_of_ulong t = Sexplib0.Sexp.Atom (Unsigned.ULong.to_string t)

  type ullong = Unsigned.ULLong.t

  let sexp_of_ullong t = Sexplib0.Sexp.Atom (Unsigned.ULLong.to_string t)

  type attributes = {
    name : string;
    registry_id : ullong;
    max_threads_per_threadgroup : device_size;
    max_buffer_length : ulong;
    max_threadgroup_memory_length : ulong;
    argument_buffers_support : ArgumentBuffersTier.t;
    recommended_max_working_set_size : ullong;
    is_low_power : bool;
    is_removable : bool;
    is_headless : bool;
    has_unified_memory : bool;
    peer_count : ulong;
    peer_group_id : ullong;
  }
  [@@deriving sexp_of]

  let get_attributes (self : t) : attributes =
    let name =
      ocaml_string_from_nsstring
        (Objc.msg_send ~self ~cmd:(selector "name") ~typ:(returning Objc.id))
    in
    let registry_id = Objc.msg_send ~self ~cmd:(selector "registryID") ~typ:(returning ullong) in
    let max_threads_per_threadgroup_struct : device_size =
      (* Use the locally defined mtlsize_t struct *)
      let size_struct : mtlsize Ctypes.structure =
        Objc.msg_send_stret ~self
          ~cmd:(selector "maxThreadsPerThreadgroup")
          ~typ:(returning mtlsize_t) (* Return the local struct type *)
          ~return_type:mtlsize_t (* Pass struct type for stret size check *)
      in
      {
        width = Unsigned.ULong.to_int (getf size_struct width_field);
        height = Unsigned.ULong.to_int (getf size_struct height_field);
        depth = Unsigned.ULong.to_int (getf size_struct depth_field);
      }
    in
    let max_buffer_length =
      Objc.msg_send ~self ~cmd:(selector "maxBufferLength") ~typ:(returning ulong)
    in
    let max_threadgroup_memory_length =
      Objc.msg_send ~self ~cmd:(selector "maxThreadgroupMemoryLength") ~typ:(returning ulong)
    in
    let argument_buffers_support_val =
      Objc.msg_send ~self ~cmd:(selector "argumentBuffersSupport") ~typ:(returning llong)
      (* Enum usually maps to long long *)
    in
    let argument_buffers_support = ArgumentBuffersTier.from_llong argument_buffers_support_val in
    let recommended_max_working_set_size =
      Objc.msg_send ~self ~cmd:(selector "recommendedMaxWorkingSetSize") ~typ:(returning ullong)
    in
    let is_low_power = Objc.msg_send ~self ~cmd:(selector "isLowPower") ~typ:(returning bool) in
    let is_removable = Objc.msg_send ~self ~cmd:(selector "isRemovable") ~typ:(returning bool) in
    let is_headless = Objc.msg_send ~self ~cmd:(selector "isHeadless") ~typ:(returning bool) in
    let has_unified_memory =
      Objc.msg_send ~self ~cmd:(selector "hasUnifiedMemory") ~typ:(returning bool)
    in
    let peer_count = Objc.msg_send ~self ~cmd:(selector "peerCount") ~typ:(returning ulong) in
    let peer_group_id = Objc.msg_send ~self ~cmd:(selector "peerGroupID") ~typ:(returning ullong) in
    {
      name;
      registry_id;
      max_threads_per_threadgroup = max_threads_per_threadgroup_struct;
      max_buffer_length;
      max_threadgroup_memory_length;
      argument_buffers_support;
      recommended_max_working_set_size;
      is_low_power;
      is_removable;
      is_headless;
      has_unified_memory;
      peer_count;
      peer_group_id;
    }
end

module ResourceOptions = struct
  type t = Unsigned.ULLong.t

  let sexp_of_t t = Sexplib0.Sexp.Atom (Unsigned.ULLong.to_string t)
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
    cls |> alloc |> init

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
    Sexplib0.Sexp.List
      [
        Sexplib0.Sexp.Atom "<MTLCompileOptions>";
        Sexplib0.Sexp.List
          [ Sexplib0.Sexp.Atom "fast_math"; Sexplib0.Sexp.Atom (Bool.to_string fast_math) ];
        Sexplib0.Sexp.List
          [ Sexplib0.Sexp.Atom "language_version"; LanguageVersion.sexp_of_t lang_version_val ];
        Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "library_type"; LibraryType.sexp_of_t lib_type_val ];
        Sexplib0.Sexp.List
          [ Sexplib0.Sexp.Atom "optimization_level"; OptimizationLevel.sexp_of_t opt_level_val ];
      ]
end

module ResourceUsage = struct
  type t = Unsigned.ULong.t

  let read = Unsigned.ULong.of_int 1 (* MTLResourceUsageRead *)
  let write = Unsigned.ULong.of_int 2 (* MTLResourceUsageWrite *)

  (* Combine options using bitwise OR *)
  let ( + ) = Unsigned.ULong.logor
end

module Region = struct
  type mtlorigin
  type mtlsize
  type mtlregion
  type t = mtlregion structure Ctypes_static.ptr

  let mtlorigin_t : mtlorigin structure typ = structure "MTLOrigin"
  let origin_x = field mtlorigin_t "x" size_t
  let origin_y = field mtlorigin_t "y" size_t
  let origin_z = field mtlorigin_t "z" size_t
  let () = seal mtlorigin_t
  let mtlsize_t : mtlsize structure typ = structure "MTLSize"
  let size_width = field mtlsize_t "width" size_t
  let size_height = field mtlsize_t "height" size_t
  let size_depth = field mtlsize_t "depth" size_t
  let () = seal mtlsize_t
  let mtlregion_t : mtlregion structure typ = structure "MTLRegion"
  let region_origin = field mtlregion_t "origin" mtlorigin_t
  let region_size = field mtlregion_t "size" mtlsize_t
  let () = seal mtlregion_t

  let make_origin ~x ~y ~z =
    let origin = make mtlorigin_t in
    setf origin origin_x (Unsigned.Size_t.of_int x);
    setf origin origin_y (Unsigned.Size_t.of_int y);
    setf origin origin_z (Unsigned.Size_t.of_int z);
    origin

  let make_size ~width ~height ~depth =
    let size = make mtlsize_t in
    setf size size_width (Unsigned.Size_t.of_int width);
    setf size size_height (Unsigned.Size_t.of_int height);
    setf size size_depth (Unsigned.Size_t.of_int depth);
    size

  let make ~x ~y ~z ~width ~height ~depth =
    let region = make mtlregion_t in
    setf region region_origin (make_origin ~x ~y ~z);
    setf region region_size (make_size ~width ~height ~depth);
    region.structured

  let make_1d ~x ~width = make ~x ~y:0 ~z:0 ~width ~height:1 ~depth:1
  let make_2d ~x ~y ~width ~height = make ~x ~y ~z:0 ~width ~height ~depth:1
end

module Event = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLEvent>"
  let on_device device = Objc.msg_send ~self:device ~cmd:(selector "newEvent") ~typ:(returning Objc.id)

  let set_label event label =
    let ns_label =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        label
    in
    Objc.msg_send ~self:event ~cmd:(selector "setLabel:") ~typ:(Objc.id @-> returning void) ns_label
end

module SharedEvent = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLSharedEvent>"

  let on_device device =
    Objc.msg_send ~self:device ~cmd:(selector "newSharedEvent") ~typ:(returning Objc.id)

  let set_label event label =
    let ns_label =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        label
    in
    Objc.msg_send ~self:event ~cmd:(selector "setLabel:") ~typ:(Objc.id @-> returning void) ns_label

  let set_signaled_value event value =
    Objc.msg_send ~self:event ~cmd:(selector "setSignaledValue:")
      ~typ:(uint64_t @-> returning void)
      (Unsigned.UInt64.of_int value)

  let get_signaled_value event =
    let value =
      Objc.msg_send ~self:event ~cmd:(selector "signaledValue") ~typ:(returning uint64_t)
    in
    Unsigned.UInt64.to_int value
end

module Fence = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLFence>"

  let on_device device =
    Objc.msg_send ~self:device ~cmd:(selector "newFence") ~typ:(returning Objc.id)

  let set_label fence label =
    let ns_label =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        label
    in
    Objc.msg_send ~self:fence ~cmd:(selector "setLabel:") ~typ:(Objc.id @-> returning void) ns_label
end

module Function = struct
  type t = id

  let sexp_of_t t =
    let function_name = Objc.msg_send ~self:t ~cmd:(selector "name") ~typ:(returning Objc.id) in
    let name = ocaml_string_from_nsstring function_name in
    Sexplib0.Sexp.Atom name

  let get_name func =
    let function_name = Objc.msg_send ~self:func ~cmd:(selector "name") ~typ:(returning Objc.id) in
    ocaml_string_from_nsstring function_name

  let set_label func label =
    let ns_label =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        label
    in
    Objc.msg_send ~self:func ~cmd:(selector "setLabel:") ~typ:(Objc.id @-> returning void) ns_label
end

module PipelineOption = struct
  type t = Unsigned.ULong.t

  let none = Unsigned.ULong.of_int 0 (* MTLPipelineOptionNone *)

  (* Combine options using bitwise OR *)
  let ( + ) = Unsigned.ULong.logor
end

module Library = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLLibrary>"

  (* Create a new library from Metal source code *)
  let on_device_with_source device source options =
    let err_ptr = allocate (ptr Objc.objc_object) Runtime.nil in
    let source_str =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        source
    in
    let library =
      Objc.msg_send ~self:device
        ~cmd:(selector "newLibraryWithSource:options:error:")
        ~typ:(Objc.id @-> Objc.id @-> ptr Objc.id @-> returning Objc.id)
        source_str options err_ptr
    in
    let _ = check_error "newLibraryWithSource" (coerce (ptr Objc.id) (ptr Objc.id) err_ptr) in
    library

  (* Create a new library from a compiled Metal library data *)
  let on_device_with_data device data =
    let err_ptr = allocate (ptr Objc.objc_object) Runtime.nil in
    let library =
      Objc.msg_send ~self:device
        ~cmd:(selector "newLibraryWithData:error:")
        ~typ:(Objc.id @-> ptr Objc.id @-> returning Objc.id)
        data err_ptr
    in
    let _ = check_error "newLibraryWithData" (coerce (ptr Objc.id) (ptr Objc.id) err_ptr) in
    library

  (* Get a function from the library by name *)
  let new_function_with_name library name =
    let name_str =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        name
    in
    let func =
      Objc.msg_send ~self:library ~cmd:(selector "newFunctionWithName:")
        ~typ:(Objc.id @-> returning Objc.id)
        name_str
    in
    if is_nil func then failwith (Printf.sprintf "Function '%s' not found in library" name);
    func

  let set_label library label =
    let ns_label =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        label
    in
    Objc.msg_send ~self:library ~cmd:(selector "setLabel:")
      ~typ:(Objc.id @-> returning void)
      ns_label
end

module DynamicLibrary = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLDynamicLibrary>"

  let set_label lib label =
    let ns_label =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        label
    in
    Objc.msg_send ~self:lib ~cmd:(selector "setLabel:") ~typ:(Objc.id @-> returning void) ns_label
end

module Buffer = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLBuffer>"

  let on_device device length options =
    Objc.msg_send ~self:device
      ~cmd:(selector "newBufferWithLength:options:")
      ~typ:(size_t @-> ullong @-> returning Objc.id)
      (Unsigned.Size_t.of_int length) options

  let length buffer =
    let len = Objc.msg_send ~self:buffer ~cmd:(selector "length") ~typ:(returning size_t) in
    Unsigned.Size_t.to_int len

  let contents buffer =
    Objc.msg_send ~self:buffer ~cmd:(selector "contents") ~typ:(returning (ptr void))

  let set_label buffer label =
    let ns_label =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        label
    in
    Objc.msg_send ~self:buffer ~cmd:(selector "setLabel:")
      ~typ:(Objc.id @-> returning void)
      ns_label

  let did_modify_range buffer range_start range_length =
    let ns_range = make NSRange.t in
    setf ns_range NSRange.location (Unsigned.UInt.of_int range_start);
    setf ns_range NSRange.length (Unsigned.UInt.of_int range_length);
    Objc.msg_send ~self:buffer ~cmd:(selector "didModifyRange:")
      ~typ:(NSRange.t @-> returning void)
      ns_range
end

module IndirectCommandType = struct
  type t = Unsigned.ULong.t

  let concurrent_dispatch = Unsigned.ULong.of_int 1

  (* Combine types using bitwise OR *)
  let ( + ) = Unsigned.ULong.logor
end

module IndirectCommandBufferDescriptor = struct
  type t = id

  let init () =
    let cls = Objc.get_class "MTLIndirectCommandBufferDescriptor" in
    cls |> alloc |> init

  let set_command_types descriptor command_types =
    Objc.msg_send ~self:descriptor ~cmd:(selector "setCommandTypes:")
      ~typ:(ulong @-> returning void)
      (command_types : IndirectCommandType.t)

  let set_inherit_buffers descriptor inherit_buffers =
    Objc.msg_send ~self:descriptor ~cmd:(selector "setInheritBuffers:")
      ~typ:(bool @-> returning void)
      inherit_buffers

  let set_inherit_pipeline_state descriptor inherit_pipeline_state =
    Objc.msg_send ~self:descriptor
      ~cmd:(selector "setInheritPipelineState:")
      ~typ:(bool @-> returning void)
      inherit_pipeline_state

  let set_max_kernel_buffer_bind_count descriptor count =
    Objc.msg_send ~self:descriptor
      ~cmd:(selector "setMaxKernelBufferBindCount:")
      ~typ:(uint @-> returning void)
      (Unsigned.UInt.of_int count)
end

(* Forward declaration for IndirectComputeCommand *)
module rec IndirectCommandBuffer : sig
  type t = id

  val sexp_of_t : t -> Sexplib0.Sexp.t
  val on_device : Device.t -> IndirectCommandBufferDescriptor.t -> int -> ResourceOptions.t -> t
  val indirect_compute_command_at_index : t -> int -> IndirectComputeCommand.t
  val set_label : t -> string -> unit
  val reset : t -> int -> int -> unit
end = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLIndirectCommandBuffer>"

  let on_device device descriptor max_count options =
    Objc.msg_send ~self:device
      ~cmd:(selector "newIndirectCommandBufferWithDescriptor:maxCommandCount:options:")
      ~typ:(Objc.id @-> uint @-> ullong @-> returning Objc.id)
      descriptor (Unsigned.UInt.of_int max_count) options

  let indirect_compute_command_at_index icb index =
    Objc.msg_send ~self:icb
      ~cmd:(selector "indirectComputeCommandAtIndex:")
      ~typ:(uint @-> returning Objc.id)
      (Unsigned.UInt.of_int index)

  let set_label icb label =
    let ns_label =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        label
    in
    Objc.msg_send ~self:icb ~cmd:(selector "setLabel:") ~typ:(Objc.id @-> returning void) ns_label

  let reset icb range_start range_length =
    let ns_range = make NSRange.t in
    setf ns_range NSRange.location (Unsigned.UInt.of_int range_start);
    setf ns_range NSRange.length (Unsigned.UInt.of_int range_length);
    Objc.msg_send ~self:icb ~cmd:(selector "resetWithRange:")
      ~typ:(NSRange.t @-> returning void)
      ns_range
end

and IndirectComputeCommand : sig
  type t = id

  val set_compute_pipeline_state : t -> id -> unit
  val set_kernel_buffer : t -> id -> int -> int -> unit
  val concurrent_dispatch_threadgroups : t -> int -> int -> int -> int -> int -> int -> unit
  val set_barrier : t -> unit
end = struct
  type t = id

  let set_compute_pipeline_state cmd pipeline_state =
    Objc.msg_send ~self:cmd
      ~cmd:(selector "setComputePipelineState:")
      ~typ:(Objc.id @-> returning void)
      pipeline_state

  let set_kernel_buffer cmd buffer offset index =
    Objc.msg_send ~self:cmd
      ~cmd:(selector "setKernelBuffer:offset:atIndex:")
      ~typ:(Objc.id @-> uint @-> uint @-> returning void)
      buffer (Unsigned.UInt.of_int offset) (Unsigned.UInt.of_int index)

  let concurrent_dispatch_threadgroups cmd width height depth thread_per_group_width
      thread_per_group_height thread_per_group_depth =
    let threadgroups = make Device.mtlsize_t in
    setf threadgroups Device.width_field (Unsigned.ULong.of_int width);
    setf threadgroups Device.height_field (Unsigned.ULong.of_int height);
    setf threadgroups Device.depth_field (Unsigned.ULong.of_int depth);

    let threads_per_threadgroup = make Device.mtlsize_t in
    setf threads_per_threadgroup Device.width_field (Unsigned.ULong.of_int thread_per_group_width);
    setf threads_per_threadgroup Device.height_field (Unsigned.ULong.of_int thread_per_group_height);
    setf threads_per_threadgroup Device.depth_field (Unsigned.ULong.of_int thread_per_group_depth);

    Objc.msg_send ~self:cmd
      ~cmd:(selector "concurrentDispatchThreadgroups:threadsPerThreadgroup:")
      ~typ:(Device.mtlsize_t @-> Device.mtlsize_t @-> returning void)
      threadgroups threads_per_threadgroup

  let set_barrier cmd = Objc.msg_send ~self:cmd ~cmd:(selector "setBarrier") ~typ:(returning void)
end

module ComputePipelineDescriptor = struct
  type t = id

  let init () =
    let cls = Objc.get_class "MTLComputePipelineDescriptor" in
    cls |> alloc |> init

  let set_compute_function descriptor function_obj =
    Objc.msg_send ~self:descriptor ~cmd:(selector "setComputeFunction:")
      ~typ:(Objc.id @-> returning void)
      function_obj

  let set_support_indirect_command_buffers descriptor support =
    Objc.msg_send ~self:descriptor
      ~cmd:(selector "setSupportIndirectCommandBuffers:")
      ~typ:(bool @-> returning void)
      support

  let set_label descriptor label =
    let ns_label =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        label
    in
    Objc.msg_send ~self:descriptor ~cmd:(selector "setLabel:")
      ~typ:(Objc.id @-> returning void)
      ns_label
end

module ComputePipelineState = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLComputePipelineState>"

  let on_device device descriptor options =
    let err_ptr = allocate (ptr Objc.objc_object) Runtime.nil in
    let pipeline_state =
      Objc.msg_send ~self:device
        ~cmd:(selector "newComputePipelineStateWithDescriptor:options:reflection:error:")
        ~typ:(Objc.id @-> ulong @-> ptr Objc.id @-> ptr Objc.id @-> returning Objc.id)
        (descriptor : ComputePipelineDescriptor.t)
        (options : PipelineOption.t)
        nil_ptr err_ptr
    in
    let _ = check_error "newComputePipelineStateWithDescriptor" err_ptr in
    pipeline_state

  let max_total_threads_per_threadgroup pipeline_state =
    let max_threads =
      Objc.msg_send ~self:pipeline_state
        ~cmd:(selector "maxTotalThreadsPerThreadgroup")
        ~typ:(returning uint)
    in
    Unsigned.UInt.to_int max_threads

  let thread_execution_width pipeline_state =
    let width =
      Objc.msg_send ~self:pipeline_state ~cmd:(selector "threadExecutionWidth")
        ~typ:(returning uint)
    in
    Unsigned.UInt.to_int width

  let static_threadgroup_memory_length pipeline_state =
    let length =
      Objc.msg_send ~self:pipeline_state
        ~cmd:(selector "staticThreadgroupMemoryLength")
        ~typ:(returning uint)
    in
    Unsigned.UInt.to_int length
end

module CommandQueue = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLCommandQueue>"

  let on_device device max_buffer_count =
    Objc.msg_send ~self:device
      ~cmd:(selector "newCommandQueueWithMaxCommandBufferCount:")
      ~typ:(uint @-> returning Objc.id)
      (Unsigned.UInt.of_int max_buffer_count)

  let command_buffer queue =
    Objc.msg_send ~self:queue ~cmd:(selector "commandBuffer") ~typ:(returning Objc.id)

  let set_label queue label =
    let ns_label =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        label
    in
    Objc.msg_send ~self:queue ~cmd:(selector "setLabel:") ~typ:(Objc.id @-> returning void) ns_label
end

module CommandBuffer = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLCommandBuffer>"

  let compute_command_encoder buffer =
    Objc.msg_send ~self:buffer ~cmd:(selector "computeCommandEncoder") ~typ:(returning Objc.id)

  let blit_command_encoder buffer =
    Objc.msg_send ~self:buffer ~cmd:(selector "blitCommandEncoder") ~typ:(returning Objc.id)

  let commit buffer = Objc.msg_send ~self:buffer ~cmd:(selector "commit") ~typ:(returning void)

  let wait_until_completed buffer =
    Objc.msg_send ~self:buffer ~cmd:(selector "waitUntilCompleted") ~typ:(returning void)

  let error buffer =
    let error_id = Objc.msg_send ~self:buffer ~cmd:(selector "error") ~typ:(returning Objc.id) in
    if is_nil error_id then None else Some (get_error_description error_id)

  let get_label buffer =
    let label_id = Objc.msg_send ~self:buffer ~cmd:(selector "label") ~typ:(returning Objc.id) in
    ocaml_string_from_nsstring label_id

  let set_label buffer label =
    let ns_label =
      Objc.msg_send ~self:(Objc.get_class "NSString")
        ~cmd:(selector "stringWithUTF8String:")
        ~typ:(string @-> returning Objc.id)
        label
    in
    Objc.msg_send ~self:buffer ~cmd:(selector "setLabel:")
      ~typ:(Objc.id @-> returning void)
      ns_label

  let gpu_start_time buffer =
    let time = Objc.msg_send ~self:buffer ~cmd:(selector "GPUStartTime") ~typ:(returning double) in
    time

  let gpu_end_time buffer =
    let time = Objc.msg_send ~self:buffer ~cmd:(selector "GPUEndTime") ~typ:(returning double) in
    time

  let encode_signal_event buffer event value =
    Objc.msg_send ~self:buffer
      ~cmd:(selector "encodeSignalEvent:value:")
      ~typ:(Objc.id @-> uint64_t @-> returning void)
      event (Unsigned.UInt64.of_int value)

  let encode_wait_for_event buffer event value =
    Objc.msg_send ~self:buffer
      ~cmd:(selector "encodeWaitForEvent:value:")
      ~typ:(Objc.id @-> uint64_t @-> returning void)
      event (Unsigned.UInt64.of_int value)
end

module ComputeCommandEncoder = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLComputeCommandEncoder>"

  let use_resources encoder resources count usage =
    (* Create an array to hold the resources *)
    let resources_arr = CArray.make (ptr void) count in
    (* Fill the array with resources *)
    for i = 0 to count - 1 do
      CArray.set resources_arr i (coerce Objc.id (ptr void) resources.(i))
    done;

    Objc.msg_send ~self:encoder
      ~cmd:(selector "useResources:count:usage:")
      ~typ:(ptr (ptr void) @-> size_t @-> ullong @-> returning void)
      (CArray.start resources_arr) (Unsigned.Size_t.of_int count) usage

  let set_compute_pipeline_state encoder pipeline_state =
    Objc.msg_send ~self:encoder
      ~cmd:(selector "setComputePipelineState:")
      ~typ:(Objc.id @-> returning void)
      pipeline_state

  let dispatch_threadgroups encoder width height depth thread_per_group_width
      thread_per_group_height thread_per_group_depth =
    let threadgroups = make Device.mtlsize_t in
    setf threadgroups Device.width_field (Unsigned.ULong.of_int width);
    setf threadgroups Device.height_field (Unsigned.ULong.of_int height);
    setf threadgroups Device.depth_field (Unsigned.ULong.of_int depth);

    let threads_per_threadgroup = make Device.mtlsize_t in
    setf threads_per_threadgroup Device.width_field (Unsigned.ULong.of_int thread_per_group_width);
    setf threads_per_threadgroup Device.height_field (Unsigned.ULong.of_int thread_per_group_height);
    setf threads_per_threadgroup Device.depth_field (Unsigned.ULong.of_int thread_per_group_depth);

    Objc.msg_send ~self:encoder
      ~cmd:(selector "dispatchThreadgroups:threadsPerThreadgroup:")
      ~typ:(Device.mtlsize_t @-> Device.mtlsize_t @-> returning void)
      threadgroups threads_per_threadgroup

  let execute_commands_in_buffer encoder icb range_start range_length =
    let ns_range = make NSRange.t in
    setf ns_range NSRange.location (Unsigned.UInt.of_int range_start);
    setf ns_range NSRange.length (Unsigned.UInt.of_int range_length);
    Objc.msg_send ~self:encoder
      ~cmd:(selector "executeCommandsInBuffer:withRange:")
      ~typ:(Objc.id @-> NSRange.t @-> returning void)
      icb ns_range

  let end_encoding encoder =
    Objc.msg_send ~self:encoder ~cmd:(selector "endEncoding") ~typ:(returning void)

  let set_buffer encoder buffer offset index =
    Objc.msg_send ~self:encoder
      ~cmd:(selector "setBuffer:offset:atIndex:")
      ~typ:(Objc.id @-> uint @-> uint @-> returning void)
      buffer (Unsigned.UInt.of_int offset) (Unsigned.UInt.of_int index)

  let set_bytes encoder bytes length index =
    Objc.msg_send ~self:encoder
      ~cmd:(selector "setBytes:length:atIndex:")
      ~typ:(ptr void @-> size_t @-> uint @-> returning void)
      bytes (Unsigned.Size_t.of_int length) (Unsigned.UInt.of_int index)
end

module BlitCommandEncoder = struct
  type t = id

  let sexp_of_t _ = Sexplib0.Sexp.Atom "<MTLBlitCommandEncoder>"

  let copy_from_buffer encoder src_buffer src_offset dst_buffer dst_offset size =
    Objc.msg_send ~self:encoder
      ~cmd:(selector "copyFromBuffer:sourceOffset:toBuffer:destinationOffset:size:")
      ~typ:(Objc.id @-> uint @-> Objc.id @-> uint @-> uint @-> returning void)
      src_buffer (Unsigned.UInt.of_int src_offset) dst_buffer (Unsigned.UInt.of_int dst_offset)
      (Unsigned.UInt.of_int size)

  let end_encoding encoder =
    Objc.msg_send ~self:encoder ~cmd:(selector "endEncoding") ~typ:(returning void)
end
