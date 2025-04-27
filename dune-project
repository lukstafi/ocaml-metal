(lang dune 3.18)

(name metal)

(version 0.1.0)

(generate_opam_files true)

(source
 (github lukstafi/ocaml-metal))

(authors "Lukasz Stafiniak <lukstafi@gmail.com>")

(maintainers "Lukasz Stafiniak <lukstafi@gmail.com>")

(maintenance_intent "(latest)")

(license MIT)

(documentation https://github.com/lukstafi/ocaml-metal/blob/main/README.md)

(package
 (name metal)
 (synopsis
  "OCaml bindings to selected parts of Apple Metal, for general compute applications")
 (description
  "OCaml bindings to selected parts of Apple Metal, for general compute applications")
 (depends
  ; at OCaml 4.13, base.0.15.1 is crashing the installation.
  (ocaml
   (>= 4.14))
  dune
  (ctypes
   (>= 0.14.0))
  ctypes-foreign
  sexplib0
  ppx_sexp_conv
  ppx_expect
  (odoc :with-doc)
  camlkit-base)
 (tags
  ("metal" "gpu" "compute" "apple")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
