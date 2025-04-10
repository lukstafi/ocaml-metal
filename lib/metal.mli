module CG = CoreGraphics

(** A generic Objective-C object pointer. See {{: https://developer.apple.com/documentation/objectivec/id } id} *)
type id = Runtime.Objc.objc_object Ctypes.structure Ctypes_static.ptr

(** A null pointer suitable for Objective-C objects. *)
val nil_ptr : id Ctypes.ptr
(** Converts an NSString object to an OCaml string. *)
val ocaml_string_from_nsstring : Runtime.Objc.objc_object Ctypes.structure Ctypes.ptr -> string

(** Converts an NSArray object containing Objective-C objects into an OCaml array of [id]. *)
val from_nsarray :
  Runtime.Objc.objc_object Ctypes.structure Ctypes.ptr ->
  id array

(** Options for configuring Metal resources like buffers and textures.
    See {{: https://developer.apple.com/documentation/metal/mtlresourceoptions } MTLResourceOptions} *)
module ResourceOptions : sig
  type t = Unsigned.ullong

  val ullong : Unsigned.ullong Ctypes_static.typ
  (** Shared between CPU and GPU. See {{: https://developer.apple.com/documentation/metal/mtlstoragemode/shared } MTLStorageModeShared} *)
  val storage_mode_shared : t
  (** Managed by the system, requiring synchronization. See {{: https://developer.apple.com/documentation/metal/mtlstoragemode/managed } MTLStorageModeManaged} *)
  val storage_mode_managed : t
  (** Private to the GPU. See {{: https://developer.apple.com/documentation/metal/mtlstoragemode/private } MTLStorageModePrivate} *)
  val storage_mode_private : t
  (** Default CPU cache mode. See {{: https://developer.apple.com/documentation/metal/mtlcpucachemode/defaultcache } MTLCPUCacheModeDefaultCache} *)
  val cpu_cache_mode_default_cache : t
  (** Write-combined CPU cache mode. See {{: https://developer.apple.com/documentation/metal/mtlcpucachemode/writecombined } MTLCPUCacheModeWriteCombined} *)
  val cpu_cache_mode_write_combined : t
  (** Combines resource options using bitwise OR. *)
  val ( + ) : t -> t -> t
end

(** Options for compiling Metal Shading Language (MSL) source code.
    See {{: https://developer.apple.com/documentation/metal/mtlcompileoptions } MTLCompileOptions} *)
module CompileOptions : sig
  type t

  (** Creates a new, default set of compile options. *)
  val init : unit -> t

  (** Specifies the version of the Metal Shading Language to use.
      See {{: https://developer.apple.com/documentation/metal/mtllanguageversion } MTLLanguageVersion} *)
  module LanguageVersion : sig
    type t = ResourceOptions.t

    (** Deprecated. *)
    val version_1_0 : t
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

  (** Specifies the type of library to produce.
      See {{: https://developer.apple.com/documentation/metal/mtllibrarytype } MTLLibraryType} *)
  module LibraryType : sig
    type t = ResourceOptions.t

    (** An executable library. *)
    val executable : t
    (** A dynamic library. *)
    val dynamic : t
  end

  (** Specifies the optimization level for the compiler.
      See {{: https://developer.apple.com/documentation/metal/mtllibraryoptimizationlevel } MTLLibraryOptimizationLevel} *)
  module OptimizationLevel : sig
    type t = ResourceOptions.t

    (** Default optimization level. *)
    val default : t
    (** Optimize for size. *)
    val size : t
    (** Optimize for performance. *)
    val performance : t
  end

  (** Enables or disables fast math optimizations. *)
  val set_fast_math_enabled : t -> bool -> unit

  (** Sets the Metal Shading Language version. *)
  val set_language_version :
    t -> LanguageVersion.t -> unit

  (** Sets the library type. *)
  val set_library_type :
    t -> LibraryType.t -> unit

  (** Sets the optimization level. *)
  val set_optimization_level :
    t -> OptimizationLevel.t -> unit
end

(** An interface to a Metal buffer object, representing a region of memory.
    See {{: https://developer.apple.com/documentation/metal/mtlbuffer } MTLBuffer} *)
module Buffer : sig
  type t

  (** Returns a pointer to the buffer's contents.
      See {{: https://developer.apple.com/documentation/metal/mtlbuffer/1515718-contents } contents} *)
  val contents : t -> unit Ctypes_static.ptr

  (** Returns the logical size of the buffer in bytes.
      See {{: https://developer.apple.com/documentation/metal/mtlbuffer/1515936-length } length} *)
  val length : t -> Unsigned.ulong

  (** Represents a range within a buffer or collection.
      See {{: https://developer.apple.com/documentation/foundation/nsrange } NSRange} *)
  module NSRange : sig
    type t

    val t : t Ctypes.structure Ctypes_static.typ
    (** The starting location (index) of the range. *)
    val location : (Unsigned.ulong, t Ctypes.structure) Ctypes_static.field
    (** The length of the range. *)
    val length : (Unsigned.ulong, t Ctypes.structure) Ctypes_static.field
    (** Creates an NSRange structure. *)
    val make : location:int -> length:int -> (t, [ `Struct ]) Ctypes_static.structured
  end

  (** Notifies the system that a specific range of the buffer's contents has been modified by the CPU.
      Required for buffers with managed storage mode.
      See {{: https://developer.apple.com/documentation/metal/mtlbuffer/1515616-didmodifyrange } didModifyRange:} *)
  val did_modify_range :
    t ->
    NSRange.t Ctypes.structure ->
    unit
end

(** Represents a single Metal shader function.
    See {{: https://developer.apple.com/documentation/metal/mtlfunction } MTLFunction} *)
module Function : sig
  type t

  (** Returns the name of the function.
      See {{: https://developer.apple.com/documentation/metal/mtlfunction/1515878-name } name} *)
  val name : t -> string
end

(** Represents a collection of compiled Metal shader functions.
    See {{: https://developer.apple.com/documentation/metal/mtllibrary } MTLLibrary} *)
module Library : sig
  type t

  (** Creates a function object for a given function name within the library.
      See {{: https://developer.apple.com/documentation/metal/mtllibrary/1515524-newfunctionwithname } newFunctionWithName:} *)
  val new_function_with_name : t -> string -> Function.t

  (** Returns an array of the names of all functions in the library.
      See {{: https://developer.apple.com/documentation/metal/mtllibrary/1516070-functionnames } functionNames} *)
  val function_names : t -> string array
end

(** Represents a compiled compute pipeline state.
    See {{: https://developer.apple.com/documentation/metal/mtlcomputepipelinestate } MTLComputePipelineState} *)
module ComputePipelineState : sig
  type t

  (** The maximum number of threads in a threadgroup for this pipeline state.
      See {{: https://developer.apple.com/documentation/metal/mtlcomputepipelinestate/1514843-maxtotalthreadsperthreadgroup } maxTotalThreadsPerThreadgroup} *)
  val max_total_threads_per_threadgroup : t -> Unsigned.ulong

  (** The width of a thread execution group for this pipeline state.
      See {{: https://developer.apple.com/documentation/metal/mtlcomputepipelinestate/1640034-threadexecutionwidth } threadExecutionWidth} *)
  val thread_execution_width : t -> Unsigned.ulong
end

(** An encoder for issuing commands common to all command encoder types.
    See {{: https://developer.apple.com/documentation/metal/mtlcommandencoder } MTLCommandEncoder} *)
module CommandEncoder : sig
  type t

  (** Declares that all command generation from this encoder is complete.
      See {{: https://developer.apple.com/documentation/metal/mtlcommandencoder/1515817-endencoding } endEncoding} *)
  val end_encoding : t -> unit
  (** Returns the label associated with the command encoder.
      See {{: https://developer.apple.com/documentation/metal/mtlcommandencoder/1515815-label } label} *)
  val label : t -> string
  (** Sets the label for the command encoder.
      See {{: https://developer.apple.com/documentation/metal/mtlcommandencoder/1515477-setlabel } setLabel:} *)
  val set_label : t -> string -> unit
end

(** An encoder for issuing data transfer (blit) commands.
    See {{: https://developer.apple.com/documentation/metal/mtlblitcommandencoder } MTLBlitCommandEncoder} *)
module BlitCommandEncoder : sig
  type t

  (** Inherited from CommandEncoder. *)
  val end_encoding : t -> unit
  (** Inherited from CommandEncoder. *)
  val set_label : t -> string -> unit
  (** Inherited from CommandEncoder. *)
  val label : t -> string

  (** Copies data from one buffer to another.
      See {{: https://developer.apple.com/documentation/metal/mtlblitcommandencoder/1515530-copyfrombuffer } copyFromBuffer:sourceOffset:toBuffer:destinationOffset:size:} *)
  val copy_from_buffer :
    self:t ->
    source_buffer:Buffer.t ->
    source_offset:int ->
    destination_buffer:Buffer.t ->
    destination_offset:int ->
    size:int ->
    unit

  (** Ensures that memory operations on a resource are complete before subsequent commands execute.
      Required for resources with managed storage mode.
      See {{: https://developer.apple.com/documentation/metal/mtlblitcommandencoder/1515424-synchronizeresource } synchronizeResource:} *)
  val synchronize_resource :
    self:t ->
    resource:id -> (* MTLResource, Buffer is one *)
    unit
end

(** An encoder for issuing compute processing commands.
    See {{: https://developer.apple.com/documentation/metal/mtlcomputecommandencoder } MTLComputeCommandEncoder} *)
module ComputeCommandEncoder : sig
  type t

  (** Inherited from CommandEncoder. *)
  val end_encoding : t -> unit
  (** Inherited from CommandEncoder. *)
  val set_label : t -> string -> unit
  (** Inherited from CommandEncoder. *)
  val label : t -> string

  (** Sets the current compute pipeline state object.
      See {{: https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/1515811-setcomputepipelinestate } setComputePipelineState:} *)
  val set_compute_pipeline_state :
    t -> ComputePipelineState.t -> unit

  (** Sets a buffer for a compute function.
      See {{: https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/1515293-setbuffer } setBuffer:offset:atIndex:} *)
  val set_buffer :
    t -> Buffer.t -> int -> int -> unit

  (** Defines the dimensions of a grid or threadgroup.
      See {{: https://developer.apple.com/documentation/metal/mtlsize } MTLSize} *)
  module Size : sig
    type t

    val t : t Ctypes.structure Ctypes_static.typ
    (** The width dimension. *)
    val width : (Unsigned.ulong, t Ctypes.structure) Ctypes_static.field
    (** The height dimension. *)
    val height : (Unsigned.ulong, t Ctypes.structure) Ctypes_static.field
    (** The depth dimension. *)
    val depth : (Unsigned.ulong, t Ctypes.structure) Ctypes_static.field
    (** Creates an MTLSize structure. *)
    val make : width:int -> height:int -> depth:int -> (t, [ `Struct ]) Ctypes_static.structured
  end

  (** Defines a region within a 1D, 2D, or 3D resource.
      See {{: https://developer.apple.com/documentation/metal/mtlregion } MTLRegion} *)
  module Region : sig
    type t

    val t : t Ctypes.structure Ctypes_static.typ
    (** The origin (starting point {x,y,z}) of the region. Uses MTLSize struct layout. *)
    val origin : (Size.t Ctypes.structure, t Ctypes.structure) Ctypes_static.field
    (** The size {width, height, depth} of the region. *)
    val size : (Size.t Ctypes.structure, t Ctypes.structure) Ctypes_static.field

    (** Creates an MTLRegion structure. *)
    val make :
      ox:int -> (* Origin x *)
      oy:int -> (* Origin y *)
      oz:int -> (* Origin z *)
      sx:int -> (* Size width *)
      sy:int -> (* Size height *)
      sz:int -> (* Size depth *)
      (t, [ `Struct ]) Ctypes_static.structured
  end

  (** Dispatches compute work items based on the total number of threads in the grid.
      See {{: https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/1515819-dispatchthreads } dispatchThreads:threadsPerThreadgroup:} *)
  val dispatch_threads :
    t ->
    Size.t Ctypes.structure -> (* threadsPerGrid *)
    Size.t Ctypes.structure -> (* threadsPerThreadgroup *)
    unit

  (** Dispatches compute work items based on the number of threadgroups in the grid.
      See {{: https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/16494dispatchthreadgroups } dispatchThreadgroups:threadsPerThreadgroup:} *)
  val dispatch_threadgroups :
    t ->
    Size.t Ctypes.structure -> (* threadgroupsPerGrid *)
    Size.t Ctypes.structure -> (* threadsPerThreadgroup *)
    unit
end

(** A container for encoded commands that will be executed by the GPU.
    See {{: https://developer.apple.com/documentation/metal/mtlcommandbuffer } MTLCommandBuffer} *)
module CommandBuffer : sig
  type t

  (** Submits the command buffer for execution.
      See {{: https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515649-commit } commit} *)
  val commit : t -> unit
  (** Waits synchronously until the command buffer has completed execution.
      See {{: https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515550-waituntilcompleted } waitUntilCompleted} *)
  val wait_until_completed : t -> unit

  (** Creates a blit command encoder to encode data transfer commands into the buffer.
      See {{: https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515500-blitcommandencoder } blitCommandEncoder} *)
  val blit_command_encoder :
    t ->
    BlitCommandEncoder.t

  (** Creates a compute command encoder to encode compute commands into the buffer.
      See {{: https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515806-computecommandencoder } computeCommandEncoder} *)
  val compute_command_encoder :
    t ->
    ComputeCommandEncoder.t

  (** Registers a block to be called when the command buffer completes execution.
      See {{: https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515831-addcompletedhandler } addCompletedHandler:} *)
  val add_completed_handler :
    t ->
    (Runtime__C.Types.object_t -> Runtime__C.Types.object_t -> unit) -> (* Block: (MTLCommandBuffer* ) -> void *)
    unit

  (** Returns an error object if the command buffer execution failed.
      See {{: https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515780-error } error} *)
  val error : t -> id (* NSError *)
end

(** A queue for submitting command buffers to a device.
    See {{: https://developer.apple.com/documentation/metal/mtlcommandqueue } MTLCommandQueue} *)
module CommandQueue : sig
  type t

  (** Creates a new command buffer associated with this queue.
      See {{: https://developer.apple.com/documentation/metal/mtlcommandqueue/1515758-commandbuffer } commandBuffer} *)
  val command_buffer : t -> CommandBuffer.t
end

(** Represents the GPU device capable of executing Metal commands.
    See {{: https://developer.apple.com/documentation/metal/mtldevice } MTLDevice} *)
module Device : sig
  type t

  (** Returns the default Metal device for the system.
      See {{: https://developer.apple.com/documentation/metal/1433401-mtlcreatesystemdefaultdevice } MTLCreateSystemDefaultDevice} *)
  val create_system_default : unit -> t

  (** Creates a new command queue associated with this device.
      See {{: https://developer.apple.com/documentation/metal/mtldevice/1433388-newcommandqueue } newCommandQueue} *)
  val new_command_queue : t -> CommandQueue.t

  (** Creates a new buffer allocated on this device.
      See {{: https://developer.apple.com/documentation/metal/mtldevice/1433429-newbufferwithlength } newBufferWithLength:options:} *)
  val new_buffer_with_length :
    t ->
    int -> (* length *)
    ResourceOptions.t -> (* options *)
    Buffer.t

  (** Creates a new library by compiling Metal Shading Language source code.
      See {{: https://developer.apple.com/documentation/metal/mtldevice/1433431-newlibrarywithsource } newLibraryWithSource:options:error:} *)
  val new_library_with_source :
    t ->
    string -> (* source *)
    CompileOptions.t -> (* options *)
    Library.t

  (** Creates a new compute pipeline state from a function object.
      See {{: https://developer.apple.com/documentation/metal/mtldevice/1433427-newcomputepipelinestatewithfunc } newComputePipelineStateWithFunction:error:} *)
  val new_compute_pipeline_state_with_function :
    t ->
    Function.t -> (* function *)
    ComputePipelineState.t
end

(** Extracts the localized description string from an NSError object.
    See {{: https://developer.apple.com/documentation/foundation/nserror/1414418-localizeddescription } localizedDescription} *)
val get_error_description : id -> string
