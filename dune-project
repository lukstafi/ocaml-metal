(lang dune 3.17)

(name metal)

(generate_opam_files true)

(source
 (github lukstafi/ocaml-metal))

(authors "Lukasz Stafiniak <lukstafi@gmail.com>")

(maintainers "Lukasz Stafiniak <lukstafi@gmail.com>")

(license MIT)

(documentation https://url/to/documentation)

(package
 (name metal)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends
  ocaml
  camlkit-base
  )
 (tags
  ("add topics" "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
