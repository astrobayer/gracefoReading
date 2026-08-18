# Real PO.DAAC test data

`testRealData.m` looks for real GRACE-FO RL04 files here by their
original names. Included with the toolbox (small):

    MAS1B_2020-01-01_C_04.txt      (~8 KB)
    THR1B_2020-01-01_C_04.txt      (~95 KB)

To enable the full acceptance suite, copy in addition (too large to
bundle; obtain from PO.DAAC, https://podaac.jpl.nasa.gov/):

    ACT1B_2020-01-01_C_04.txt      (~14 MB)
    GNV1B_2020-01-01_C_04.txt      (~23 MB)
    SCA1B_2020-01-01_C_04.txt      (~11 MB)
    KBR1B_2020-01-01_Y_04.txt      (~4 MB)
    LRI1B_2020-01-01_Y_04.txt      (~8 MB)

Tests for absent files are skipped automatically (assumption failure),
so the suite passes either way — it simply becomes stricter with data.
