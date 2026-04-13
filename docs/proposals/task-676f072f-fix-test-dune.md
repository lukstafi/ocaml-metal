# Proposal: Fix broken test suite — add output validation to dune test stanzas

**Task:** task-676f072f
**Date:** 2026-04-13

## Goal

Add `(action (diff <name>.expected %{test}))` to all 7 test stanzas in `test/dune` so `dune runtest` validates test output against expected files.

## Acceptance Criteria

1. Each of the 7 test stanzas in `test/dune` has an `(action (diff <name>.expected %{test}))` clause.
2. `dune runtest` passes locally (skipping ICB and logging tests if on CI/paravirtual).
3. No changes to `.expected` files or test source code.

## Context

The migration from `ppx_expect` to manual output-file validation (commit `543b22a`, Jul 2025) created `.expected` files but never added the dune `(action ...)` clauses to compare output. Currently `dune runtest` only checks exit codes — output mismatches are silently ignored.

## Approach

For each test stanza in `test/dune`, add the action clause. Example transformation:

```lisp
;; Before:
(test
 (name basic_tests)
 (deps basic_tests.expected)
 (libraries metal ctypes.foreign))

;; After:
(test
 (name basic_tests)
 (deps basic_tests.expected)
 (libraries metal ctypes.foreign)
 (action (diff basic_tests.expected %{test})))
```

All 7 tests: `basic_tests`, `error_tests`, `advanced_tests`, `coverage_tests`, `saxpy`, `advanced_tests_icb`, `logging_tests`.

### Files to modify

- `test/dune` — add `(action ...)` to all 7 stanzas
