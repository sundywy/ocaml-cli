# ocaml-cli

OCaml ports of the CLI tools from [*Command-Line Rust*](https://github.com/kyclark/command-line-rust) (Ken Youens-Clark). The goal is to learn OCaml by reimplementing the book’s exercises with [Cmdliner](https://erratique.ch/software/cmdliner) and [Dune](https://dune.build/).

## Tools

| Binary     | Status                         | Notes                          |
|------------|--------------------------------|--------------------------------|
| `echor`    | Implemented                    | `echo`                         |
| `catr`     | Implemented                    | `cat`                          |
| `headr`    | Implemented (partial vs tests) | `head`                         |
| `wcr`      | Stub (`hello world`)           | `wc`                           |
| `uniqr`    | Stub                           | `uniq`                         |
| `findr`    | Stub                           | `find`                         |
| `cutr`     | Stub                           | `cut`                          |
| `grepr`    | Stub                           | `grep`                         |
| `commr`    | Stub                           | `comm`                         |
| `tailr`    | Stub                           | `tail`                         |
| `fortuner` | Stub                           | `fortune`                      |
| `calr`     | Stub                           | `cal`                          |
| `lsr`      | Stub                           | `ls`                           |

## Requirements

- OCaml ≥ 5.3 (see `dune-project`)
- [opam](https://opam.ocaml.org/) and Dune
- Dependencies: `cmdliner`; for tests: `alcotest`, `bos`

```sh
opam install . --deps-only --with-test
```

## Build & run

```sh
dune build @install
dune exec echor -- Hello world
dune exec catr -- path/to/file
```

## Tests

### OCaml integration tests (`test/`)

Alcotest + [Bos](https://erratique.ch/software/bos) suites under `test/`, one directory per tool (fixtures in `inputs/` / `expected/`). Shared helpers live in `test/cli_test/`.

**These OCaml tests were created by Cursor (Auto),** ported from the book’s Rust CLI tests into this repo’s Alcotest layout.

```sh
dune runtest                 # all suites
dune runtest test/echor      # one suite
```

`echor` and `catr` are expected to pass. Suites for stub binaries will fail until those tools are implemented. `headr` has known failures vs the harness expectations.

### Rust test harness (`test-harness/`)

Optional mirror of the book’s `assert_cmd` tests, adapted to run `dune exec <tool> -- …`:

```sh
just test            # or: just test echor::
```

Requires a Rust toolchain. Useful for comparing behavior while porting.

## Layout

```
bin/<tool>/          # Cmdliner executables
test/<tool>/         # Alcotest + Bos integration tests
test/cli_test/       # shared test helpers
test-harness/        # Rust harness (reference)
```

## License

See `LICENSE` / `dune-project`.
