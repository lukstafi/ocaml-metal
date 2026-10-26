## [Unreleased]

### Added

- `LogState.add_buffered_log_handler` and `LogState.drain_log_buffer`: a native (C) `MTLLogState` handler that copies shader log messages into a mutex-protected buffer, drained on the host thread. No OCaml code runs on Metal's dispatch threads (ahrefs/ocannl#1594).

### Changed

- `LogState.add_log_handler`'s documentation steers callers to `add_buffered_log_handler`: it runs the OCaml handler on a Metal dispatch thread. It is deliberately not `[@@ocaml.deprecated]`, so clients that build with alerts as errors keep compiling.

### Fixed

- `LogState.add_log_handler` kept only its OCaml closure alive, not the ctypes block literal Metal holds a pointer to (Metal's `Block_copy` of a global-flagged block keeps the original pointer). Once the GC reclaimed the struct, the next log message crashed the process (SEGV or bus error, 6 of 6 runs under GC churn). The block is now kept in the log state's lifetime.

## [0.1.1.1] -- 2025-07-18

### Changed

- Removed dependency on `ppx_sexp_conv` and its large JaneStreet dependency cone (`base`, `ppx_jane`, etc.). Still depends on `sexplib0`.

## [0.1.1] -- 2025-07-17

### Added

- Bound `Runtime.Objc.id` to `id`.
- `send_msg_suspended` in vendored Runtime code.

### Changed

- Vendored `camlkit-base.Runtime` with modifications; removed dependency on `camlkit-base`. Removed static configuration.
- Migrated tests away from `ppx_expect`.
- Removed text files copied from official Metal documentation.

### Fixed

- Restored joint behavior for `Foreign.funptr` config for `Block` (camlkit issues #9 and #10).
- Corrected `os_log` max args warning.

## [0.1.0.1] -- 2025-05-07

### Added

- Running tests in opam repo CI.

### Fixed

- Don't rely on device name in tests; list properties of all devices.
- Graceful handling on older-than-supported systems (partial functionality without hard failure).
- Syntax for opam `with-test`.

## [0.1.0] -- 2025-05-06

### Added

- Coverage of most of the general computation related parts of the Metal framework (mostly Gemini-generated with Claude-generated tests).
- Careful lifetime management.
- GitHub actions.
- `MTLCopyAllDevices`
- More complete coverage for `MTLCompileOptions`.
- README (Claude-generated)
- `MTLCommandQueueDescriptor`
- Logging from inside kernels: `LogState` etc.
- Debug logging of all msg_send calls.

### Fixed

- Lifetime for logging handlers.
