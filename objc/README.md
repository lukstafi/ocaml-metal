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


## Changes from Original camlkit-base

All platform-specific code paths have been simplified to use the macOS/Darwin implementations directly.
We removed static configuration and pick AMD vs. ARM architecture at runtime (at startup).

### Block Module Fixes

- Changed from `__NSGlobalBlock` to `__NSStackBlock__` to avoid crashes when ctypes releases the object
- Callback pointer created with `funptr ~runtime_lock:true ~thread_registration:true`

See:

- [Consider adding to Block the ability to set ~runtime_lock:true, to avoid Fatal error: no domain lock held](https://github.com/dboris/camlkit/issues/9),
- [Enable passing ~release_runtime_lock:true to msg_send (optional arg or msg_send_suspended)](https://github.com/dboris/camlkit/issues/10),
- [Runtime.Block has an unsafe corner case that can be fixed by pretending it's stack allocated](https://github.com/dboris/camlkit/issues/11)

Some of these changes got incorporated into a newer release of camlkit-base, in a more flexible form.

### Objc Module Enhancements  

- Added `msg_send_suspended` function that releases the runtime lock to prevent blocking other threads during long-running operations

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
