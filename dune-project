(lang dune 3.17)

(name cli)

(generate_opam_files true)

(source
 (github sundywy/ocaml-cli))

(authors "Sundy Yaputra <sundy.yap@gmail.com>")

(maintainers "Sundy Yaputra <sundy.yap@gmail.com>")

(license LICENSE)

(package
 (name catr)
 (synopsis "Rust cat in Ocaml")
 (description "Rust cat in Ocaml")
 (depends
  (ocaml (>= 5.3))
   cmdliner))

(package
 (name echor)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends ocaml))
