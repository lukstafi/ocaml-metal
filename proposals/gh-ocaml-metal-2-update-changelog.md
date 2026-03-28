# Proposal: Update CHANGELOG

**Task**: gh-ocaml-metal-2
**Issue**: https://github.com/lukstafi/ocaml-metal/issues/2

## Summary

Add missing CHANGELOG entries for releases 0.1.0.1, 0.1.1, and 0.1.1.1. Currently the CHANGELOG only documents 0.1.0.

## Current State

- `CHANGELOG.md` has a single entry for `0.1.0` (2025-05-06).
- Four tags exist: `0.1.0`, `0.1.0.1`, `0.1.1`, `0.1.1.1`.
- Two GitHub releases exist: `0.1.0.1` (2025-05-07) and `0.1.1.1` (2025-07-18).
- Tags `0.1.0` and `0.1.1` have no GitHub release pages.

## Proposed Changes

Add three new sections above the existing `[0.1.0]` entry, covering all post-0.1.0 tags.

### [0.1.1.1] -- 2025-07-18

From the GitHub release notes plus commit `01ab385`:

- **Changed**: Removed dependency on `ppx_sexp_conv` and its large JaneStreet dependency cone (`base`, `ppx_jane`, etc.). Still depends on `sexplib0`.

### [0.1.1] -- 2025-07-17

From commits `0.1.0.1..0.1.1`:

- **Changed**: Vendored `camlkit-base.Runtime` with modifications; removed dependency on `camlkit-base`. Removed static configuration.
- **Changed**: Migrated tests away from `ppx_expect`.
- **Fixed**: Restored joint behavior for `Foreign.funptr` config for `Block` (camlkit issues #9 and #10).
- **Fixed**: Corrected `os_log` max args warning.
- **Added**: Bound `Runtime.Objc.id` to `id`.
- **Added**: `send_msg_suspended` in vendored Runtime code (from `Runtime.Block` fixes).
- **Removed**: Text files copied from official Metal documentation.

### [0.1.0.1] -- 2025-05-07

From commits `0.1.0..0.1.0.1`:

- **Fixed**: Don't rely on device name in tests; list properties of all devices.
- **Fixed**: Graceful handling on older-than-supported systems.
- **Fixed**: Syntax for opam `with-test`.
- **Added**: Running tests in opam repo CI.

## Approach

1. Edit `CHANGELOG.md` to prepend the three new sections.
2. Keep the existing `[0.1.0]` entry unchanged.
3. Close GitHub issue #2 after merging.

## Ambiguities

- The task elaboration only mentions `0.1.1.1`, but there are also unreleased tags `0.1.0.1` and `0.1.1` that should be documented. This proposal covers all three.
- Tag `0.1.1` has no GitHub release page, so its entry is reconstructed from commit messages. The owner should verify accuracy.
- Some commits between `0.1.0.1` and `0.1.1` are intermediate/broken states (e.g., `d41cfc8 "Broken: vendor camlkit-base.Runtime"`). The CHANGELOG entry summarizes the net result, not intermediate steps.

## Effort

Small -- approximately 15 minutes of work.
