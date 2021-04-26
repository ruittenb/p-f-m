
# Personal File Manager


- This package is available from https://github.com/ruittenb/p-f-m

- Prerequisites for this package, in dependency order:

```
                           at least      preferred
  perl                     5.10          5.14
    File::stat             1.00          1.05
      File::Stat::Bits     0.19          0.19 (*)
    File::Temp             0.22 ?        0.2304
    HTML::Parser           3.59 ?        3.72
      LWP                  5.827 ?       6.26
    Module::Load           0.16          0.32
  readline                 4.1           5
    Term-ReadLine-Gnu      1.09          1.24
  ncurses                  ?             5
    Term-Screen            1.06          1.06
      Term-ScreenColor     1.20          1.20
```

- Confusingly, the package File-Stat-Bits-1.01.tar.gz provides
  version 0.19 of the module File::Stat::Bits.

- If you are not sure if you have all the dependencies, you can run
  the 'install.sh' shell script. Otherwise, you can go straight to the
  'perl Makefile.PL; make; make test; sudo make install' phase.

