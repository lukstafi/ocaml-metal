## [0.1.1.1] -- 2025-07-18

### Changed

- Removed dependency on `camlkit-base`; vendored `camlkit-base.Runtime` and simplified it (removed static configuration).
- Removed dependency on `ppx_sexp_conv` and its large JaneStreet dependency cone (`base`, `ppx_jane`, etc.). Still depends on `sexplib0`.

### Added

- `send_msg_suspended` in vendored Runtime code.

### Fixed

- Upstreamed fixes/changes to `Runtime.Block`.

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
