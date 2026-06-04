(lang dune 3.17)

(name cli)

(generate_opam_files true)

(source
 (github sundywy/ocaml-cli))

(authors "Sundy Yaputra <sundy.yap@gmail.com>")

(maintainers "Sundy Yaputra <sundy.yap@gmail.com>")

(license LICENSE)

(package
 (name cli)
 (synopsis "Ocaml port of CLI exercise in Rust c")
 (description "Learning ocaml by using rust book")
 (depends
  (ocaml (>= 5.3))
   cmdliner))
