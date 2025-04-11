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
  type t

  val create_system_default : unit -> t
  (** Returns the default Metal device for the system. See
      {{:https://developer.apple.com/documentation/metal/1433401-mtlcreatesystemdefaultdevice}
       MTLCreateSystemDefaultDevice} *)
end

(** Options for configuring Metal resources like buffers and textures. See
    {{:https://developer.apple.com/documentation/metal/mtlresourceoptions} MTLResourceOptions} *)
module ResourceOptions : sig
  type t = Unsigned.ullong

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
  type t

  val init : unit -> t
  (** Creates a new, default set of compile options. *)

  (** Specifies the version of the Metal Shading Language to use. See
      {{:https://developer.apple.com/documentation/metal/mtllanguageversion} MTLLanguageVersion} *)
  module LanguageVersion : sig
    type t = ResourceOptions.t

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
    type t = ResourceOptions.t

    val executable : t
    (** An executable library. *)

    val dynamic : t
    (** A dynamic library. *)
  end

  (** Specifies the optimization level for the compiler. See
      {{:https://developer.apple.com/documentation/metal/mtllibraryoptimizationlevel}
       MTLLibraryOptimizationLevel} *)
  module OptimizationLevel : sig
    type t = ResourceOptions.t

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

(** An interface to a Metal buffer object, representing a region of memory. See
    {{:https://developer.apple.com/documentation/metal/mtlbuffer} MTLBuffer} *)
module Buffer : sig
  type t

  val contents : t -> unit Ctypes_static.ptr
  (** Returns a pointer to the buffer's contents. See
      {{:https://developer.apple.com/documentation/metal/mtlbuffer/1515718-contents} contents} *)

  val length : t -> Unsigned.ulong
  (** Returns the logical size of the buffer in bytes. See
      {{:https://developer.apple.com/documentation/metal/mtlbuffer/1515936-length} length} *)

  (** Represents a range within a buffer or collection. See
      {{:https://developer.apple.com/documentation/foundation/nsrange} NSRange} *)
  module NSRange : sig
    type t

    val location : t -> Unsigned.ulong
    (** The starting location (index) of the range. *)

    val length : t -> Unsigned.ulong
    (** The length of the range. *)

    val make : location:int -> length:int -> t
    (** Creates an NSRange structure. *)
  end

  val did_modify_range : t -> NSRange.t -> unit
  (** Notifies the system that a specific range of the buffer's contents has been modified by the
      CPU. Required for buffers with managed storage mode. See
      {{:https://developer.apple.com/documentation/metal/mtlbuffer/1515616-didmodifyrange}
       didModifyRange:} *)

  val on_device : Device.t -> length:int -> ResourceOptions.t -> t
  (** Creates a new buffer allocated on this device. See
      {{:https://developer.apple.com/documentation/metal/mtldevice/1433429-newbufferwithlength}
       newBufferWithLength:options:} *)
end

(** Represents a single Metal shader function. See
    {{:https://developer.apple.com/documentation/metal/mtlfunction} MTLFunction} *)
module Function : sig
  type t

  val name : t -> string
  (** Returns the name of the function. See
      {{:https://developer.apple.com/documentation/metal/mtlfunction/1515878-name} name} *)
end

(** Represents a collection of compiled Metal shader functions. See
    {{:https://developer.apple.com/documentation/metal/mtllibrary} MTLLibrary} *)
module Library : sig
  type t

  val new_function_with_name : t -> string -> Function.t
  (** Creates a function object for a given function name within the library. See
      {{:https://developer.apple.com/documentation/metal/mtllibrary/1515524-newfunctionwithname}
       newFunctionWithName:} *)

  val function_names : t -> string array
  (** Returns an array of the names of all functions in the library. See
      {{:https://developer.apple.com/documentation/metal/mtllibrary/1516070-functionnames}
       functionNames} *)

  val on_device : Device.t -> source:string -> CompileOptions.t -> t
  (** Creates a new library by compiling Metal Shading Language source code. See
      {{:https://developer.apple.com/documentation/metal/mtldevice/1433431-newlibrarywithsource}
       newLibraryWithSource:options:error:} *)
end

(** Represents a compiled compute pipeline state. See
    {{:https://developer.apple.com/documentation/metal/mtlcomputepipelinestate}
     MTLComputePipelineState} *)
module ComputePipelineState : sig
  type t

  val max_total_threads_per_threadgroup : t -> Unsigned.ulong
  (** The maximum number of threads in a threadgroup for this pipeline state. See
      {{:https://developer.apple.com/documentation/metal/mtlcomputepipelinestate/1514843-maxtotalthreadsperthreadgroup}
       maxTotalThreadsPerThreadgroup} *)

  val thread_execution_width : t -> Unsigned.ulong
  (** The width of a thread execution group for this pipeline state. See
      {{:https://developer.apple.com/documentation/metal/mtlcomputepipelinestate/1640034-threadexecutionwidth}
       threadExecutionWidth} *)

  val on_device : Device.t -> Function.t -> t
  (** Creates a new compute pipeline state from a function object. See
      {{:https://developer.apple.com/documentation/metal/mtldevice/1433427-newcomputepipelinestatewithfunc}
       newComputePipelineStateWithFunction:error:} *)
end

(** An encoder for issuing commands common to all command encoder types. See
    {{:https://developer.apple.com/documentation/metal/mtlcommandencoder} MTLCommandEncoder} *)
module CommandEncoder : sig
  type t

  val end_encoding : t -> unit
  (** Declares that all command generation from this encoder is complete. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandencoder/1515817-endencoding}
       endEncoding} *)

  val label : t -> string
  (** Returns the label associated with the command encoder. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandencoder/1515815-label} label} *)

  val set_label : t -> string -> unit
  (** Sets the label for the command encoder. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandencoder/1515477-setlabel}
       setLabel:} *)
end

(** Represents a GPU synchronization primitive. See
    {{:https://developer.apple.com/documentation/metal/mtlfence} MTLFence} *)
module Fence : sig
  type t

  val label : t -> string
  (** Returns the label associated with the fence. See
      {{:https://developer.apple.com/documentation/metal/mtlfence/2866156-label} label} *)

  val set_label : t -> string -> unit
  (** Sets the label for the fence. See
      {{:https://developer.apple.com/documentation/metal/mtlfence/2866155-setlabel} setLabel:} *)

  val on_device : Device.t -> t
  (** Creates a new fence associated with this device. See
      {{:https://developer.apple.com/documentation/metal/mtldevice/2866162-newfence} newFence} *)

  val get_device : t -> Device.t
  (** Returns the device associated with the fence. See
      {{:https://developer.apple.com/documentation/metal/mtlfence/2866154-device} device} *)
end

(** An object used to listen for Metal shared event notifications. See
    {{:https://developer.apple.com/documentation/metal/mtlsharedeventlistener}
     MTLSharedEventListener} *)
module SharedEventListener : sig
  type t
  (** The type representing a shared event listener. *)

  val init : unit -> t
  (** Creates a new shared event listener. See
      {{:https://developer.apple.com/documentation/metal/mtlsharedeventlistener/2967404-init} init}
  *)

  (* Removed incorrect fence/event functions from SharedEventListener *)
end

(** A serializable handle for a shared event. See
    {{:https://developer.apple.com/documentation/metal/mtlsharedeventhandle} MTLSharedEventHandle}
*)
module SharedEventHandle : sig
  type t
  (** The type representing a shared event handle. *)

  val label : t -> string
  (** Returns the label associated with the event handle. *)
end

(** An event that can be signaled and waited on by the CPU and GPU across process boundaries. See
    {{:https://developer.apple.com/documentation/metal/mtlsharedevent} MTLSharedEvent} *)
module SharedEvent : sig
  type t
  (** The type representing a shared event. *)

  val signaled_value : t -> Unsigned.ullong
  (** The current signaled value of the event. See
      {{:https://developer.apple.com/documentation/metal/mtlsharedevent/2967401-signaledvalue}
       signaledValue} *)

  val label : t -> string
  (** Returns the label associated with the event. See
      {{:https://developer.apple.com/documentation/metal/mtlsharedevent/2967398-label} label} *)

  val set_label : t -> string -> unit
  (** Sets the label for the event. See
      {{:https://developer.apple.com/documentation/metal/mtlsharedevent/2967400-setlabel} setLabel:}
  *)

  val new_shared_event_handle : t -> SharedEventHandle.t
  (** Creates a new serializable handle for this event. See
      {{:https://developer.apple.com/documentation/metal/mtlsharedevent/2967399-newsharedeventhandle}
       newSharedEventHandle} *)

  val notify_listener :
    t ->
    SharedEventListener.t ->
    Unsigned.ullong ->
    (t -> Unsigned.ullong -> unit) ->
    (* Block: (MTLSharedEvent*, uint64_t) -> void *)
    unit
  (** Registers a listener block to be called when the event reaches a specific value. See
      {{:https://developer.apple.com/documentation/metal/mtlsharedevent/2967402-notifylistener}
       notifyListener:atValue:block:} *)

  val on_device : Device.t -> t
  (** Creates a new shared event associated with this device. See
      {{:https://developer.apple.com/documentation/metal/mtldevice/2966686-newsharedevent}
       newSharedEvent} *)
end

(** An encoder for issuing data transfer (blit) commands. See
    {{:https://developer.apple.com/documentation/metal/mtlblitcommandencoder} MTLBlitCommandEncoder}
*)
module BlitCommandEncoder : sig
  type t

  val end_encoding : t -> unit
  (** Inherited from CommandEncoder. *)

  val set_label : t -> string -> unit
  (** Inherited from CommandEncoder. *)

  val label : t -> string
  (** Inherited from CommandEncoder. *)

  val copy_from_buffer :
    self:t ->
    source_buffer:Buffer.t ->
    source_offset:int ->
    destination_buffer:Buffer.t ->
    destination_offset:int ->
    size:int ->
    unit
  (** Copies data from one buffer to another. See
      {{:https://developer.apple.com/documentation/metal/mtlblitcommandencoder/1515530-copyfrombuffer}
       copyFromBuffer:sourceOffset:toBuffer:destinationOffset:size:} *)

  val synchronize_resource :
    self:t ->
    resource:id ->
    (* MTLResource, Buffer is one *)
    unit
  (** Ensures that memory operations on a resource are complete before subsequent commands execute.
      Required for resources with managed storage mode. See
      {{:https://developer.apple.com/documentation/metal/mtlblitcommandencoder/1515424-synchronizeresource}
       synchronizeResource:} *)

  val update_fence : t -> Fence.t -> unit
  (** Encodes a command to update a fence after all prior commands in the encoder have completed.
      See
      {{:https://developer.apple.com/documentation/metal/mtlblitcommandencoder/2866157-updatefence}
       updateFence:} *)

  val wait_for_fence : t -> Fence.t -> unit
  (** Encodes a command that blocks the execution of subsequent commands in the encoder until the
      fence is updated. See
      {{:https://developer.apple.com/documentation/metal/mtlblitcommandencoder/2866158-waitforfence}
       waitForFence:} *)

  val signal_event : t -> SharedEvent.t -> Unsigned.ullong -> unit
  (** Encodes a command to signal an event with a specific value after all work prior to this
      command has finished. See
      {{:https://developer.apple.com/documentation/metal/mtlblitcommandencoder/2966597-signalevent}
       signalEvent:value:} *)

  val wait_for_event : t -> SharedEvent.t -> Unsigned.ullong -> unit
  (** Encodes a command that waits until an event reaches a specific value before executing
      subsequent commands. See
      {{:https://developer.apple.com/documentation/metal/mtlblitcommandencoder/2966598-waitforevent}
       waitForEvent:value:} *)
end

(** An encoder for issuing compute processing commands. See
    {{:https://developer.apple.com/documentation/metal/mtlcomputecommandencoder}
     MTLComputeCommandEncoder} *)
module ComputeCommandEncoder : sig
  type t

  val end_encoding : t -> unit
  (** Inherited from CommandEncoder. *)

  val set_label : t -> string -> unit
  (** Inherited from CommandEncoder. *)

  val label : t -> string
  (** Inherited from CommandEncoder. *)

  val set_compute_pipeline_state : t -> ComputePipelineState.t -> unit
  (** Sets the current compute pipeline state object. See
      {{:https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/1515811-setcomputepipelinestate}
       setComputePipelineState:} *)

  val set_buffer : t -> Buffer.t -> int -> int -> unit
  (** Sets a buffer for a compute function. See
      {{:https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/1515293-setbuffer}
       setBuffer:offset:atIndex:} *)

  (** Defines the dimensions of a grid or threadgroup. See
      {{:https://developer.apple.com/documentation/metal/mtlsize} MTLSize} *)
  module Size : sig
    type t

    val width : t -> Unsigned.ulong
    (** The width dimension. *)

    val height : t -> Unsigned.ulong
    (** The height dimension. *)

    val depth : t -> Unsigned.ulong
    (** The depth dimension. *)

    val make : width:int -> height:int -> depth:int -> t
    (** Creates an MTLSize structure. *)
  end

  (** Defines a region within a 1D, 2D, or 3D resource. See
      {{:https://developer.apple.com/documentation/metal/mtlregion} MTLRegion} *)
  module Region : sig
    type t

    val origin : t -> Size.t
    (** The origin (starting point {x,y,z}) of the region. Uses MTLSize struct layout. *)

    val size : t -> Size.t
    (** The size {width, height, depth} of the region. *)

    val make : ox:int -> oy:int -> oz:int -> sx:int -> sy:int -> sz:int -> t
    (** Creates an MTLRegion structure. [ox, oy, oz] is the origin, [sx, sy, sz] is the size. *)
  end

  val dispatch_threads : t -> threads_per_grid:Size.t -> threads_per_threadgroup:Size.t -> unit
  (** Dispatches compute work items based on the total number of threads in the grid. See
      {{:https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/1515819-dispatchthreads}
       dispatchThreads:threadsPerThreadgroup:} *)

  val dispatch_threadgroups :
    t -> threadgroups_per_grid:Size.t -> threads_per_threadgroup:Size.t -> unit
  (** Dispatches compute work items based on the number of threadgroups in the grid. See
      {{:https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/16494dispatchthreadgroups}
       dispatchThreadgroups:threadsPerThreadgroup:} *)

  val update_fence : t -> Fence.t -> unit
  (** Encodes a command to update a fence after all prior commands in the encoder have completed.
      See
      {{:https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/2866161-updatefence}
       updateFence:} *)

  val wait_for_fence : t -> Fence.t -> unit
  (** Encodes a command that blocks the execution of subsequent commands in the encoder until the
      fence is updated. See
      {{:https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/2866160-waitforfence}
       waitForFence:} *)

  val signal_event : t -> SharedEvent.t -> Unsigned.ullong -> unit
  (** Encodes a command to signal an event with a specific value after all work prior to this
      command has finished. See
      {{:https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/2966600-signalevent}
       signalEvent:value:} *)

  val wait_for_event : t -> SharedEvent.t -> Unsigned.ullong -> unit
  (** Encodes a command that waits until an event reaches a specific value before executing
      subsequent commands. See
      {{:https://developer.apple.com/documentation/metal/mtlcomputecommandencoder/2966599-waitforevent}
       waitForEvent:value:} *)
end

(** A container for encoded commands that will be executed by the GPU. See
    {{:https://developer.apple.com/documentation/metal/mtlcommandbuffer} MTLCommandBuffer} *)
module CommandBuffer : sig
  type t

  val commit : t -> unit
  (** Submits the command buffer for execution. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515649-commit} commit} *)

  val wait_until_completed : t -> unit
  (** Waits synchronously until the command buffer has completed execution. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515550-waituntilcompleted}
       waitUntilCompleted} *)

  val blit_command_encoder : t -> BlitCommandEncoder.t
  (** Creates a blit command encoder to encode data transfer commands into the buffer. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515500-blitcommandencoder}
       blitCommandEncoder} *)

  val compute_command_encoder : t -> ComputeCommandEncoder.t
  (** Creates a compute command encoder to encode compute commands into the buffer. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515806-computecommandencoder}
       computeCommandEncoder} *)

  val add_completed_handler :
    t ->
    (Runtime__C.Types.object_t -> Runtime__C.Types.object_t -> unit) ->
    (* Block: (MTLCommandBuffer* ) -> void *)
    unit
  (** Registers a block to be called when the command buffer completes execution. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515831-addcompletedhandler}
       addCompletedHandler:} *)

  val error : t -> id (* NSError *)
  (** Returns an error object if the command buffer execution failed. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandbuffer/1515780-error} error} *)

  val encode_signal_event : t -> SharedEvent.t -> Unsigned.ullong -> unit
  (** Encodes a command to signal an event with a specific value when the command buffer reaches
      this point. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandbuffer/2966601-encodesignalevent}
       encodeSignalEvent:value:} *)

  val encode_wait_for_event : t -> SharedEvent.t -> Unsigned.ullong -> unit
  (** Encodes a command to pause command buffer execution until an event reaches a specific value.
      See
      {{:https://developer.apple.com/documentation/metal/mtlcommandbuffer/2966602-encodewaitforevent}
       encodeWaitForEvent:value:} *)
end

(** A queue for submitting command buffers to a device. See
    {{:https://developer.apple.com/documentation/metal/mtlcommandqueue} MTLCommandQueue} *)
module CommandQueue : sig
  type t

  val command_buffer : t -> CommandBuffer.t
  (** Creates a new command buffer associated with this queue. See
      {{:https://developer.apple.com/documentation/metal/mtlcommandqueue/1515758-commandbuffer}
       commandBuffer} *)

  val on_device : Device.t -> t
  (** Creates a new command queue associated with a device. See
      {{:https://developer.apple.com/documentation/metal/mtldevice/1433388-newcommandqueue}
       newCommandQueue} *)
end

val get_error_description : id -> string
(** Extracts the localized description string from an NSError object. See
    {{:https://developer.apple.com/documentation/foundation/nserror/1414418-localizeddescription}
     localizedDescription} *)
