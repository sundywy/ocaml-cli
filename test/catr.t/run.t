  $ cat inputs/the-bustle.txt | catr | tee output > /dev/null
  $ diff output expected/the-bustle.txt.stdin.out

  $ catr inputs/the-bustle.txt > output
  $ diff output expected/the-bustle.txt.out

  $ catr bad_inputs
  bad_inputs: No such file or directory

  $ cat inputs/the-bustle.txt | catr -n | tee output > /dev/null
  $ diff output expected/the-bustle.txt.n.stdin.out

  $ cat inputs/the-bustle.txt | catr -b | tee output > /dev/null
  $ diff output expected/the-bustle.txt.b.stdin.out

  $ catr inputs/empty.txt > output
  $ diff output expected/empty.txt.out

  $ catr -n inputs/empty.txt > output
  $ diff output expected/empty.txt.n.out

  $ catr -b inputs/empty.txt > output
  $ diff output expected/empty.txt.b.out

  $ catr inputs/fox.txt > output
  $ diff output expected/fox.txt.out

  $ catr -n inputs/fox.txt > output
  $ diff output expected/fox.txt.n.out

  $ catr -b inputs/fox.txt > output
  $ diff output expected/fox.txt.b.out

  $ catr inputs/spiders.txt > output
  $ diff output expected/spiders.txt.out

  $ catr --number-lines inputs/spiders.txt > output
  $ diff output expected/spiders.txt.n.out

  $ catr --number-nonblank-lines inputs/spiders.txt > output
  $ diff output expected/spiders.txt.b.out

  $ catr inputs/the-bustle.txt > output
  $ diff output expected/the-bustle.txt.out

  $ catr -n inputs/the-bustle.txt > output
  $ diff output expected/the-bustle.txt.n.out

  $ catr -b inputs/the-bustle.txt > output
  $ diff output expected/the-bustle.txt.b.out

  $ catr inputs/fox.txt inputs/spiders.txt inputs/the-bustle.txt > output
  $ diff output expected/all.out

  $ catr -n inputs/fox.txt inputs/spiders.txt inputs/the-bustle.txt > output
  $ diff output expected/all.n.out

  $ catr -b inputs/fox.txt inputs/spiders.txt inputs/the-bustle.txt > output
  $ diff output expected/all.b.out
