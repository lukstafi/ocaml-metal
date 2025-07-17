# Vendored camlkit-base Runtime

This directory contains vendored files from camlkit-base.runtime to remove the external dependency.

[Camlkit (dboris/camlkit)](https://github.com/dboris/camlkit) by Boris D. <borisd@gmx.com> is published under the ISC licence.

## Files copied from `camlkit-base/runtime/`

- `arch.ml` - Architecture detection
- `c.ml` - C module bindings  
- `define.ml` - Definition utilities
- `function_description.ml` - Function description utilities
- `inspect.ml` - Inspection utilities (platform detection removed)
- `objc_type.ml` + `objc_type.mli` - Objective-C type system
- `runtime.ml` - Main runtime module with Objective-C bindings (platform detection removed)
- `type_description.ml` - Type description utilities

**Note:** All platform-specific code paths have been simplified to use the macOS/Darwin implementations directly.

## Changes from Original camlkit-base

### Block Module Fixes

- Changed from `__NSGlobalBlock` to `__NSStackBlock__` to avoid crashes when ctypes releases the object

### Objc Module Enhancements  

- Added `msg_send_suspended` function that releases the runtime lock to prevent blocking other threads during long-running operations

These fixes address perceived bugs in the original camlkit-base runtime and have been incorporated directly into the vendored code.

## Usage

The metal.ml file now uses explicit `Runtime.` prefixes instead of `open Runtime`.

## Dependencies

- ctypes
- ctypes.foreign

The `unsigned` dependency was removed as it wasn't needed for our use case.

## Framework Dependencies

The Metal library still requires linking against system frameworks:

- CoreGraphics framework (via `-ccopt "-framework CoreGraphics"`)
- Metal framework (via `-ccopt "-framework Metal"`)

These are native framework dependencies, not OCaml module dependencies.
