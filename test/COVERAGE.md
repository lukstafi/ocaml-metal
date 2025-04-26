# Code Coverage for OCaml Metal Bindings

WARNING: AI slop. This file was generated with minimal review.

This document outlines how to set up and measure code coverage for the Metal bindings.

## Tools

For OCaml code coverage, we use Bisect_ppx, which is a popular coverage tool for OCaml projects.

## Installation

First, install Bisect_ppx:

```sh
opam install bisect_ppx
```

## Setting Up the Project for Coverage

1. Modify the dune file to include Bisect_ppx:

```
(library
 (name metal)
 (public_name metal)
 (libraries ctypes ctypes.foreign ctypes.stubs runtime)
 (preprocess (pps bisect_ppx -- --implicit-module-names))
 (foreign_stubs
  (language c)
  (names runtime_stub)
  (flags -Wall -Werror)))
```

2. Create a .ocamlformat file in the project root with these options to ensure compatibility with Bisect_ppx:

```
version=0.26.1
bisect-silent=true
```

## Running Tests with Coverage

1. Clean any previous coverage data:

```sh
rm -rf _coverage bisect*.coverage
```

2. Run the tests:

```sh
dune runtest
```

3. Generate the coverage report:

```sh
bisect-ppx-report html
```

This will create an `_coverage/` directory with an HTML report.

4. View the coverage report:

```sh
open _coverage/index.html
```

## Analyzing Coverage Results

The HTML report will show:

- Overall coverage percentage
- File-by-file breakdown
- Line-by-line coverage highlighting (green = covered, red = not covered)

## Improving Coverage

Based on the coverage report, look for:

1. Functions with no coverage
2. Branches with partial coverage
3. Error handling paths that aren't tested

Add tests to address these gaps:

- For uncovered functions, add direct tests
- For error handling, add tests that trigger error conditions
- For conditional branches, ensure tests exercise all paths

## Adding Coverage to CI

To add coverage reporting to your CI pipeline:

1. Add this to your CI workflow:

```yml
- name: Generate coverage report
  run: |
    opam install bisect_ppx
    dune runtest
    bisect-ppx-report summary
    bisect-ppx-report html
```

2. Consider using a coverage service like Codecov:

```yml
- name: Upload coverage to Codecov
  run: |
    bisect-ppx-report cobertura
    curl -Os https://uploader.codecov.io/latest/macos/codecov
    chmod +x codecov
    ./codecov -f _coverage/coverage.xml
```

## Tips for Maximizing Coverage

1. Focus on core functionality first
2. Test both success and error paths
3. Test edge cases (nil pointers, empty arrays, etc.)
4. Test different options and configurations
5. Create helper functions for repetitive test setup

By following these steps, you can achieve high coverage for your Metal bindings, ensuring more robust and reliable code. 