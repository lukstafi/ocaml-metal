# OCaml-Metal

OCaml bindings to selected parts of Apple Metal, for general compute applications.

## Overview

OCaml-Metal provides OCaml bindings to Apple's Metal framework, focusing specifically on general compute applications. This library allows OCaml developers to leverage the power of GPU computing on macOS and iOS devices.

Metal provides a low-overhead API for GPU programming, offering significant performance advantages for compute-intensive tasks like machine learning, scientific computing, and data processing.

See also [Camlkit: OCaml bindings to macOS and iOS Cocoa frameworks](https://github.com/dboris/camlkit).

## Documentation

[API Documentation](https://lukstafi.github.io/ocaml-metal/)

## Installation

### Prerequisites

- macOS operating system (Metal is Apple-specific)
- OCaml 4.14 or later
- Dune build system
- OPAM package manager

### Installing from OPAM

```shell
opam install metal
```

### Building from Source

```shell
git clone https://github.com/lukstafi/ocaml-metal.git
cd ocaml-metal
opam install --deps-only .
dune build
```

## Example

Here's a simple example of using OCaml-Metal to perform a SAXPY operation (Single-precision A·X Plus Y) on the GPU:

```ocaml
open Metal

(* Initialize Metal *)
let device = Device.create_system_default ()
let command_queue = CommandQueue.on_device device

(* Prepare data *)
let array_length = 1024
let buffer_size = array_length * 4 (* sizeof float *)
let options = ResourceOptions.storage_mode_shared

(* Create buffers *)
let buffer_x = Buffer.on_device device ~length:buffer_size options
let buffer_y = Buffer.on_device device ~length:buffer_size options
let buffer_a = Buffer.on_device device ~length:4 options (* size of one float *)

(* Initialize buffer data *)
let fill_buffer buffer values =
  let ptr = Buffer.contents buffer |> Ctypes.(coerce (ptr void) (ptr float)) in
  Array.iteri (fun i v -> Ctypes.CArray.set (Ctypes.CArray.from_ptr ptr array_length) i v) values

(* Create sample data *)
let x_values = Array.init array_length float_of_int
let y_values = Array.init array_length (fun i -> float_of_int (array_length - i))

(* Fill buffers *)
fill_buffer buffer_x x_values
fill_buffer buffer_y y_values

(* Set scalar value for a *)
let a_value = 2.0
let a_ptr = Buffer.contents buffer_a |> Ctypes.(coerce (ptr void) (ptr float))
Ctypes.( <-@ ) a_ptr a_value

(* Define kernel in Metal Shading Language *)
let kernel_source = {|
  #include <metal_stdlib>
  using namespace metal;

  kernel void saxpy_kernel(device float *y [[buffer(0)]],
                           device const float *x [[buffer(1)]],
                           device const float *a [[buffer(2)]],
                           uint index [[thread_position_in_grid]]) {
    y[index] = (*a) * x[index] + y[index];
  }
|}

(* Compile kernel *)
let compile_options = CompileOptions.init ()
let library = Library.on_device device ~source:kernel_source compile_options
let function_obj = Library.new_function_with_name library "saxpy_kernel"
let pipeline_state, _ = ComputePipelineState.on_device_with_function device function_obj

(* Execute compute operation *)
let command_buffer = CommandBuffer.on_queue command_queue
let compute_encoder = ComputeCommandEncoder.on_buffer command_buffer

(* Set up encoder *)
let () =
  ComputeCommandEncoder.set_compute_pipeline_state compute_encoder pipeline_state;
  ComputeCommandEncoder.set_buffer compute_encoder buffer_y ~index:0;
  ComputeCommandEncoder.set_buffer compute_encoder buffer_x ~index:1;
  ComputeCommandEncoder.set_buffer compute_encoder buffer_a ~index:2

(* Dispatch compute *)
let thread_width = ComputePipelineState.get_thread_execution_width pipeline_state
let () =
  ComputeCommandEncoder.dispatch_threadgroups compute_encoder
    ~threadgroups_per_grid:{ width = array_length; height = 1; depth = 1 }
    ~threads_per_threadgroup:{ width = thread_width; height = 1; depth = 1 }

(* Finish and execute *)
let () =
  ComputeCommandEncoder.end_encoding compute_encoder;
  CommandBuffer.commit command_buffer;
  CommandBuffer.wait_until_completed command_buffer

(* Read results *)
let result_ptr = Buffer.contents buffer_y |> Ctypes.(coerce (ptr void) (ptr float))
let result = Ctypes.CArray.from_ptr result_ptr array_length
```

## Debugging

The following environment variables can be helpful in debugging Metal applications:

```shell
MTL_DEBUG_LAYER=1 MTL_SHADER_VALIDATION=1 MTL_SHADER_VALIDATION_REPORT_TO_STDERR=1
```

But note the error: `-[MTLGPUDebugDevice newIndirectCommandBufferWithDescriptor:maxCommandCount:options:]:1406: failed assertion 'Indirect Command Buffers are not currently supported with Shader Validation'`.

## Features

- Low-level bindings to essential Metal compute capabilities
- Support for buffer creation and management
- Command queue and command buffer operations
- Compute pipeline state configuration
- Shader compilation and execution
- Resource and memory management

### Currently missing: upcoming features

The following classes or protocols are not yet bound, but support is planned in upcoming releases.

- `MTLHeap`
- `MTLFunctionOptions`
- `MTLBinaryArchive`, `MTLBinaryArchiveDescriptor`
- `MTLDynamicLibrary`

## License

This project is licensed under the MIT License - see the LICENSE file for details.
