Missing arguments fails with usage:

  $ echor
  echor: required argument TEXT is missing
  Usage: echor [-n] [OPTION]… TEXT…
  Try 'echor --help' for more information.
  [124]

One argument:

  $ echor 'Hello there'
  Hello there

Multiple arguments are joined with spaces:

  $ echor Hello there
  Hello there

Omit trailing newline with -n:

  $ echor 'Hello  there' -n | xxd -p
  48656c6c6f20207468657265

  $ echor -n Hello there | xxd -p
  48656c6c6f207468657265
