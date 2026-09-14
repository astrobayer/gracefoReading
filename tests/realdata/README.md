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


# ITSG (TU Graz) satellite orbit products

`testItsgProducts.m` reads the five files below from this folder. They
are bundled and the suite therefore covers the real GROOPS dialect
without any external data:

    GRACEFO-1_kinematicOrbit_2020-01-01.txt            (~16 KB)
    GRACEFO-1_kinematicOrbitCovariance_2020-01-01.txt  (~11 KB)
    GRACEFO-1_reducedDynamicOrbit_2020-01-01.txt       (~16 KB)
    GRACEFO-1_attitude_2020-01-01.txt                  (~8 KB)
    GRACEFO-1_nonConservativeForces_2020-01-01.txt     (~7 KB)

**These are trimmed.** Each is the first 60 records of the published
file with the record-count line changed from 8640/8641 to 60 so the file
stays self-consistent. Header lines and record text are byte-for-byte as
published — nothing was reformatted, and the 18-decimal time tags are
untouched. That is what makes them usable as format evidence; they are
not a substitute for the full day.

One property does NOT survive the trim: the kinematic products are
corrected for receiver clock errors and their sampling is not constant,
but the departures from 10 s (up to ±291 ns over a day) first occur well
past record 60. `testFullDayKinematicJitter` covers that and needs the
complete file, so copy the published originals into the pool to enable
it:

    GRACEFO-1_kinematicOrbit_2020-01-01.txt            (~2.2 MB)

Obtain them from
https://ftp.tugraz.at/pub/ITSG/satelliteOrbitProducts/operational/GRACEFO-1/,
which serves them gzip-compressed; `readItsgProduct` reads `.gz`
directly, so they need not be expanded.

The frame and the time system are **not** in these files. They come from
the server's `README.txt` and `README_referenceFrames.txt`, which is why
`aux.frameSource` exists — see `readItsgProduct`.
