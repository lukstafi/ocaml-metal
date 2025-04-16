module CG = CoreGraphics

type id = Runtime.Objc.objc_object Ctypes.structure Ctypes_static.ptr
(** A generic Objective-C object pointer. See
    {{:https://developer.apple.com/documentation/objectivec/id} id} *)

val nil_ptr : id Ctypes.ptr
(** A null pointer suitable for Objective-C objects. *)

val ocaml_string_from_nsstring : Runtime.Objc.objc_object Ctypes.structure Ctypes.ptr -> string
(** Converts an NSString object to an OCaml string. *)

val from_nsarray : Runtime.Objc.objc_object Ctypes.structure Ctypes.ptr -> id array
(** Converts an NSArray object containing Objective-C objects into an OCaml array of [id]. *)

(** Represents the GPU device capable of executing Metal commands. See
    {{:https://developer.apple.com/documentation/metal/mtldevice} MTLDevice} *)
module Device : sig
  type t [@@deriving sexp_of]

  val create_system_default : unit -> t
  (** Returns the default Metal device for the system. See
      {{:https://developer.apple.com/documentation/metal/1433401-mtlcreatesystemdefaultdevice}
       MTLCreateSystemDefaultDevice} *)

  type device_size = { width : int; height : int; depth : int } [@@deriving sexp_of]
  (** Represents the dimensions of a grid or threadgroup (width, height, depth). *)

  (** Describes the level of support for argument buffers. See
      {{:https://developer.apple.com/documentation/metal/mtlargumentbufferstier}
       MTLArgumentBuffersTier} *)
  module ArgumentBuffersTier : sig
    type t = Tier1 | Tier2 [@@deriving sexp_of]
  end

  type attributes = {
    name : string;
    registry_id : Unsigned.ULLong.t;
    max_threads_per_threadgroup : device_size;
    max_buffer_length : Unsigned.ULong.t;
    max_threadgroup_memory_length : Unsigned.ULong.t;
    argument_buffers_support : ArgumentBuffersTier.t;
    recommended_max_working_set_size : Unsigned.ULLong.t;
    is_low_power : bool;
    is_removable : bool;
    is_headless : bool;
    has_unified_memory : bool;
    peer_count : Unsigned.ULong.t;
    peer_group_id : Unsigned.ULLong.t;
  }
  [@@deriving sexp_of]
  (** A record containing static attributes of the Metal device relevant for compute. *)

  val get_attributes : t -> attributes
  (** Fetches the static compute-relevant attributes of the device. *)
end

(** Options for configuring Metal resources like buffers and textures. See
    {{:https://developer.apple.com/documentation/metal/mtlresourceoptions} MTLResourceOptions} *)
module ResourceOptions : sig
  type t [@@deriving sexp_of]

  val ullong : Unsigned.ullong Ctypes_static.typ

  val storage_mode_shared : t
  (** Shared between CPU and GPU. See
      {{:https://developer.apple.com/documentation/metal/mtlstoragemode/shared}
       MTLStorageModeShared} *)

  val storage_mode_managed : t
  (** Managed by the system, requiring synchronization. See
      {{:https://developer.apple.com/documentation/metal/mtlstoragemode/managed}
       MTLStorageModeManaged} *)

  val storage_mode_private : t
  (** Private to the GPU. See
      {{:https://developer.apple.com/documentation/metal/mtlstoragemode/private}
       MTLStorageModePrivate} *)

  val cpu_cache_mode_default_cache : t
  (** Default CPU cache mode. See
      {{:https://developer.apple.com/documentation/metal/mtlcpucachemode/defaultcache}
       MTLCPUCacheModeDefaultCache} *)

  val cpu_cache_mode_write_combined : t
  (** Write-combined CPU cache mode. See
      {{:https://developer.apple.com/documentation/metal/mtlcpucachemode/writecombined}
       MTLCPUCacheModeWriteCombined} *)

  val ( + ) : t -> t -> t
  (** Combines resource options using bitwise OR. *)
end

(** Options for compiling Metal Shading Language (MSL) source code. See
    {{:https://developer.apple.com/documentation/metal/mtlcompileoptions} MTLCompileOptions} *)
module CompileOptions : sig
  type t [@@deriving sexp_of]

  val init : unit -> t
  (** Creates a new, default set of compile options. *)

  (** Specifies the version of the Metal Shading Language to use. See
      {{:https://developer.apple.com/documentation/metal/mtllanguageversion} MTLLanguageVersion} *)
  module LanguageVersion : sig
    type t = ResourceOptions.t [@@deriving sexp_of]

    val version_1_0 : t
    (** Deprecated. *)

    val version_1_1 : t
    val version_1_2 : t
    val version_2_0 : t
    val version_2_1 : t
    val version_2_2 : t
    val version_2_3 : t
    val version_2_4 : t
    val version_3_0 : t
    val version_3_1 : t
  end

  (** Specifies the type of library to produce. See
      {{:https://developer.apple.com/documentation/metal/mtllibrarytype} MTLLibraryType} *)
  module LibraryType : sig
    type t [@@deriving sexp_of]

    val executable : t
    (** An executable library. *)

    val dynamic : t
    (** A dynamic library. *)
  end

  (** Specifies the optimization level for the compiler. See
      {{:https://developer.apple.com/documentation/metal/mtllibraryoptimizationlevel}
       MTLLibraryOptimizationLevel} *)
  module OptimizationLevel : sig
    type t [@@deriving sexp_of]

    val default : t
    (** Default optimization level. *)

    val size : t
    (** Optimize for size. *)

    val performance : t
    (** Optimize for performance. *)
  end

  val set_fast_math_enabled : t -> bool -> unit
  (** Enables or disables fast math optimizations. *)

  val set_language_version : t -> LanguageVersion.t -> unit
  (** Sets the Metal Shading Language version. *)

  val set_library_type : t -> LibraryType.t -> unit
  (** Sets the library type. *)

  val set_optimization_level : t -> OptimizationLevel.t -> unit
  (** Sets the optimization level. *)
end

(** Describes how a resource will be used by a shader. See 
    {{:https://developer.apple.com/documentation/metal/mtlresourceusage} MTLResourceUsage} *)
module ResourceUsage : sig
  type t

  val read : t
  (** Resource will be read from. *)

  val write : t
  (** Resource will be written to. *)

  val ( + ) : t -> t -> t
  (** Combines resource usage flags using bitwise OR. *)
end

(** Region struct used to specify a 3D region, see 
    {{:https://developer.apple.com/documentation/metal/mtlregion} MTLRegion} *)
module Region : sig
  type t

  val make : x:int -> y:int -> z:int -> width:int -> height:int -> depth:int -> t
  (** Create a new 3D region with given origin (x,y,z) and size (width,height,depth) *)

  val make_1d : x:int -> width:int -> t
  (** Create a new 1D region at given x with given width *)

  val make_2d : x:int -> y:int -> width:int -> height:int -> t
  (** Create a new 2D region at given (x,y) with given (width,height) *)
end

(** Represents an event that command buffers use to communicate. See
    {{:https://developer.apple.com/documentation/metal/mtlevent} MTLEvent} *)
module Event : sig
  type t [@@deriving sexp_of]

  val on_device : Device.t -> t
  (** Create a new event for the given device *)

  val set_label : t -> string -> unit
  (** Set a debug label for the event *)
end

(** Represents an event that can be shared across process boundaries. See
    {{:https://developer.apple.com/documentation/metal/mtlsharedevent} MTLSharedEvent} *)
module SharedEvent : sig
  type t [@@deriving sexp_of]

  val on_device : Device.t -> t
  (** Create a new shared event for the given device *)

  val set_label : t -> string -> unit
  (** Set a debug label for the shared event *)

  val set_signaled_value : t -> int -> unit
  (** Set the signaled value for this shared event *)

  val get_signaled_value : t -> int
  (** Get the current signaled value of this shared event *)
end

(** Represents a synchronization fence to manage resource access across command encoders. See
    {{:https://developer.apple.com/documentation/metal/mtlfence} MTLFence} *)
module Fence : sig
  type t [@@deriving sexp_of]

  val on_device : Device.t -> t
  (** Create a new fence for the given device *)

  val set_label : t -> string -> unit
  (** Set a debug label for the fence *)
end

(** Represents a Metal shader function. See
    {{:https://developer.apple.com/documentation/metal/mtlfunction} MTLFunction} *)
module Function : sig
  type t [@@deriving sexp_of]

  val get_name : t -> string
  (** Get the name of the function in the Metal shader language *)

  val set_label : t -> string -> unit
  (** Set a debug label for the function *)
end

(** Options for creating a pipeline state. See 
    {{:https://developer.apple.com/documentation/metal/mtlpipelineoption} MTLPipelineOption} *)
module PipelineOption : sig
  type t

  val none : t
  (** No special options. *)

  val ( + ) : t -> t -> t
  (** Combines pipeline options using bitwise OR. *)
end

(** Represents a collection of Metal shader functions. See
    {{:https://developer.apple.com/documentation/metal/mtllibrary} MTLLibrary} *)
module Library : sig
  type t [@@deriving sexp_of]

  val on_device_with_source : Device.t -> string -> CompileOptions.t -> t
  (** Create a new library from Metal source code *)

  val on_device_with_data : Device.t -> id -> t
  (** Create a new library from a compiled Metal library data *)

  val new_function_with_name : t -> string -> Function.t
  (** Get a function from the library by name *)

  val set_label : t -> string -> unit
  (** Set a debug label for the library *)
end

(** Represents a dynamic Metal library. See
    {{:https://developer.apple.com/documentation/metal/mtldynamiclibrary} MTLDynamicLibrary} *)
module DynamicLibrary : sig
  type t [@@deriving sexp_of]

  val set_label : t -> string -> unit
  (** Set a debug label for the dynamic library *)
end

(** Represents a Metal buffer resource for storing data. See
    {{:https://developer.apple.com/documentation/metal/mtlbuffer} MTLBuffer} *)
module Buffer : sig
  type t [@@deriving sexp_of]

  val on_device : Device.t -> int -> ResourceOptions.t -> t
  (** Create a new buffer on the given device with specified length and options *)

  val length : t -> int
  (** Get the length of the buffer in bytes *)

  val contents : t -> unit Ctypes.ptr
  (** Get a pointer to the contents of the buffer that can be accessed by the CPU *)

  val set_label : t -> string -> unit
  (** Set a debug label for the buffer *)

  val did_modify_range : t -> int -> int -> unit
  (** Inform the device that a range of the buffer has been modified *)
end

(** Types of indirect command in an indirect command buffer. See
    {{:https://developer.apple.com/documentation/metal/mtlindirectcommandtype} MTLIndirectCommandType} *)
module IndirectCommandType : sig
  type t

  val concurrent_dispatch : t
  (** A dispatch that can be executed concurrently *)

  val ( + ) : t -> t -> t
  (** Combines command types using bitwise OR. *)
end

(** Descriptor for creating an indirect command buffer. See
    {{:https://developer.apple.com/documentation/metal/mtlindirectcommandbufferdescriptor} MTLIndirectCommandBufferDescriptor} *)
module IndirectCommandBufferDescriptor : sig
  type t

  val init : unit -> t
  (** Initialize a new indirect command buffer descriptor *)

  val set_command_types : t -> IndirectCommandType.t -> unit
  (** Set the command types this buffer will support *)

  val set_inherit_buffers : t -> bool -> unit
  (** Set whether the command buffer should inherit buffers from parent encoder *)

  val set_inherit_pipeline_state : t -> bool -> unit
  (** Set whether the command buffer should inherit pipeline state from parent encoder *)

  val set_max_kernel_buffer_bind_count : t -> int -> unit
  (** Set the maximum number of buffers that can be bound to a kernel *)
end

(** A descriptor for creating a compute pipeline state. See
    {{:https://developer.apple.com/documentation/metal/mtlcomputepipelinedescriptor} MTLComputePipelineDescriptor} *)
module ComputePipelineDescriptor : sig
  type t

  val init : unit -> t
  (** Initialize a new compute pipeline descriptor *)

  val set_compute_function : t -> Function.t -> unit
  (** Set the compute function for this pipeline *)

  val set_support_indirect_command_buffers : t -> bool -> unit
  (** Set whether this pipeline supports indirect command buffers *)

  val set_label : t -> string -> unit
  (** Set a debug label for the compute pipeline descriptor *)
end

(** A compiled compute pipeline. See
    {{:https://developer.apple.com/documentation/metal/mtlcomputepipelinestate} MTLComputePipelineState} *)
module ComputePipelineState : sig
  type t [@@deriving sexp_of]

  val on_device : Device.t -> ComputePipelineDescriptor.t -> PipelineOption.t -> t
  (** Create a new compute pipeline state on the device *)

  val max_total_threads_per_threadgroup : t -> int
  (** Get the maximum number of threads that can be in a threadgroup *)

  val thread_execution_width : t -> int
  (** Get the recommended thread execution width for this pipeline *)

  val static_threadgroup_memory_length : t -> int
  (** Get the amount of threadgroup memory used by this pipeline *)
end

(** Forward declaration of modules with circular dependencies *)
module rec 
  (** An encoded compute command in an indirect command buffer. See
      {{:https://developer.apple.com/documentation/metal/mtlindirectcomputecommand} MTLIndirectComputeCommand} *)
  IndirectComputeCommand : sig
    type t

    val set_compute_pipeline_state : t -> ComputePipelineState.t -> unit
    (** Set the compute pipeline state for this command *)

    val set_kernel_buffer : t -> Buffer.t -> int -> int -> unit
    (** Set a buffer argument for the kernel *)

    val concurrent_dispatch_threadgroups : t -> int -> int -> int -> int -> int -> int -> unit
    (** Dispatch a compute kernel for concurrent execution *)

    val set_barrier : t -> unit
    (** Set a barrier to ensure order of execution *)
  end

  (** A buffer containing encoded commands for deferred execution. See
      {{:https://developer.apple.com/documentation/metal/mtlindirectcommandbuffer} MTLIndirectCommandBuffer} *)
  and IndirectCommandBuffer : sig
    type t [@@deriving sexp_of]

    val on_device : Device.t -> IndirectCommandBufferDescriptor.t -> int -> ResourceOptions.t -> t
    (** Create a new indirect command buffer on the device *)

    val indirect_compute_command_at_index : t -> int -> IndirectComputeCommand.t
    (** Get an indirect compute command at a given index *)

    val set_label : t -> string -> unit
    (** Set a debug label for the indirect command buffer *)

    val reset : t -> int -> int -> unit
    (** Reset a range of commands in the buffer *)
  end

  (** A serial queue of command buffers for execution on the GPU. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandqueue} MTLCommandQueue} *)
  and CommandQueue : sig
    type t [@@deriving sexp_of]

    val on_device : Device.t -> int -> t
    (** Create a new command queue on the device with the given maximum buffer count *)

    val command_buffer : t -> CommandBuffer.t
    (** Create a new command buffer for this queue *)

    val set_label : t -> string -> unit
    (** Set a debug label for the command queue *)
  end

  (** A command buffer containing commands to execute on the GPU. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandbuffer} MTLCommandBuffer} *)
  and CommandBuffer : sig
    type t [@@deriving sexp_of]

    val compute_command_encoder : t -> ComputeCommandEncoder.t
    (** Create a new compute command encoder for this buffer *)

    val blit_command_encoder : t -> BlitCommandEncoder.t
    (** Create a new blit command encoder for this buffer *)

    val commit : t -> unit
    (** Commit this command buffer for execution *)

    val wait_until_completed : t -> unit
    (** Wait for this command buffer to complete *)

    val error : t -> string option
    (** Get any error from this command buffer execution *)

    val get_label : t -> string
    (** Get the debug label for this command buffer *)

    val set_label : t -> string -> unit
    (** Set a debug label for the command buffer *)

    val gpu_start_time : t -> float
    (** Get the GPU start time for this command buffer *)

    val gpu_end_time : t -> float
    (** Get the GPU end time for this command buffer *)

    val encode_signal_event : t -> SharedEvent.t -> int -> unit
    (** Encode a command to signal an event with a given value *)

    val encode_wait_for_event : t -> SharedEvent.t -> int -> unit
    (** Encode a command to wait for an event to reach a given value *)
  end

  (** An encoder for compute commands. See
      {{:https://developer.apple.com/documentation/metal/mtlcomputecommandencoder} MTLComputeCommandEncoder} *)
  and ComputeCommandEncoder : sig
    type t [@@deriving sexp_of]

    val use_resources : t -> id array -> int -> ResourceUsage.t -> unit
    (** Inform Metal of resources that this encoder will access *)

    val set_compute_pipeline_state : t -> ComputePipelineState.t -> unit
    (** Set the compute pipeline state for this encoder *)

    val dispatch_threadgroups : t -> int -> int -> int -> int -> int -> int -> unit
    (** Dispatch compute kernel threads *)

    val execute_commands_in_buffer : t -> IndirectCommandBuffer.t -> int -> int -> unit
    (** Execute commands from an indirect command buffer *)

    val end_encoding : t -> unit
    (** End encoding commands *)

    val set_buffer : t -> Buffer.t -> int -> int -> unit
    (** Set a buffer for a compute kernel *)

    val set_bytes : t -> unit Ctypes.ptr -> int -> int -> unit
    (** Set bytes directly for a compute kernel *)
  end

  (** An encoder for data transfer and copying operations. See
      {{:https://developer.apple.com/documentation/metal/mtlblitcommandencoder} MTLBlitCommandEncoder} *)
  and BlitCommandEncoder : sig
    type t [@@deriving sexp_of]

    val copy_from_buffer : t -> Buffer.t -> int -> Buffer.t -> int -> int -> unit
    (** Copy data between buffers *)

    val end_encoding : t -> unit
    (** End encoding commands *)
  end

