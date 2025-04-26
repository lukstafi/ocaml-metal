# ocaml-metal

OCaml bindings to selected parts of Apple Metal, for general compute applications.

[The API documentation.](https://lukstafi.github.io/ocaml-metal/)

The following environment variables can be helpful in debugging:

```shell
MTL_DEBUG_LAYER=1 MTL_SHADER_VALIDATION=1 MTL_SHADER_VALIDATION_REPORT_TO_STDERR=1
```

But note the error: `-[MTLGPUDebugDevice newIndirectCommandBufferWithDescriptor:maxCommandCount:options:]:1406: failed assertion `Indirect Command Buffers are not currently supported with Shader Validation'`.