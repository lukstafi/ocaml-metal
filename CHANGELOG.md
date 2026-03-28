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
