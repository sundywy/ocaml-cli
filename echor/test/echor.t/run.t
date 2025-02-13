Check hello1
  $ cat expected/hello1.txt
  Hello there
  $ echor Hello there > hello1.txt
  $ diff hello1.txt expected/hello1.txt

 Check hello2
  $ cat expected/hello2.txt
  Hello there
  $ echor "Hello there" > hello2.txt
  $ diff hello2.txt expected/hello2.txt

Check hello1.n
  $ cat expected/hello1.n.txt
  Hello  there
  $ echor -n "Hello  there" > hello1.n.txt
  $ diff hello1.n.txt expected/hello1.n.txt

Check hello2.n
  $ cat expected/hello2.n.txt
  Hello there
  $ echor -n "Hello" "there" > hello2.n.txt
  $ diff hello2.n.txt expected/hello2.n.txt
