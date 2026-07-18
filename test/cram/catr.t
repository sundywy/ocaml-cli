Setup input files:

  $ printf 'The quick brown fox jumps over the lazy dog.\n' > fox.txt
  $ printf '' > empty.txt
  $ printf 'a\n\nb\n' > spiders.txt
  $ printf 'The bustle in a house\nThe morning after death\nIs solemnest of industries\nEnacted upon earth.\n' > bustle.txt

Missing file is reported on stderr and skipped:

  $ catr missing.txt
  missing.txt: No such file or directory

Empty file:

  $ catr empty.txt

  $ catr -n empty.txt

  $ catr -b empty.txt

Single file:

  $ catr fox.txt
  The quick brown fox jumps over the lazy dog.

  $ catr -n fox.txt
       1	The quick brown fox jumps over the lazy dog.

  $ catr -b fox.txt
       1	The quick brown fox jumps over the lazy dog.

Number all lines vs nonempty lines:

  $ catr --number spiders.txt
       1	a
       2	
       3	b

  $ catr --number-nonblank spiders.txt
       1	a
  
       2	b

Stdin with -:

  $ cat bustle.txt | catr -
  The bustle in a house
  The morning after death
  Is solemnest of industries
  Enacted upon earth.

  $ cat bustle.txt | catr -n -
       1	The bustle in a house
       2	The morning after death
       3	Is solemnest of industries
       4	Enacted upon earth.

  $ cat bustle.txt | catr -b -
       1	The bustle in a house
       2	The morning after death
       3	Is solemnest of industries
       4	Enacted upon earth.

Multiple files:

  $ catr fox.txt spiders.txt bustle.txt
  The quick brown fox jumps over the lazy dog.
  a
  
  b
  The bustle in a house
  The morning after death
  Is solemnest of industries
  Enacted upon earth.

  $ catr fox.txt spiders.txt bustle.txt -n
       1	The quick brown fox jumps over the lazy dog.
       1	a
       2	
       3	b
       1	The bustle in a house
       2	The morning after death
       3	Is solemnest of industries
       4	Enacted upon earth.

  $ catr fox.txt spiders.txt bustle.txt -b
       1	The quick brown fox jumps over the lazy dog.
       1	a
  
       2	b
       1	The bustle in a house
       2	The morning after death
       3	Is solemnest of industries
       4	Enacted upon earth.

-n and -b together is an error:

  $ catr -n -b fox.txt
  catr: can only use one of -n/--number or -b/--number-nonblank
  Usage: catr [--number-nonblank] [--number] [OPTION]… [FILE]…
  Try 'catr --help' for more information.
  [124]
