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
