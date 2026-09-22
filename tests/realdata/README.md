# Real PO.DAAC test data

`testRealData.m` looks for real GRACE-FO RL04 files here by their
original names. Included with the toolbox (small):

    MAS1B_2020-01-01_C_04.txt      (~8 KB)
    THR1B_2020-01-01_C_04.txt      (~95 KB)

To enable the full acceptance suite, copy in addition (too large to
bundle; obtain from PO.DAAC, https://podaac.jpl.nasa.gov/, or the ISDC
mirror):

    ACT1B_2020-01-01_C_04.txt      (~14 MB)
    GNV1B_2020-01-01_C_04.txt      (~23 MB)
    SCA1B_2020-01-01_C_04.txt      (~11 MB)
    KBR1B_2020-01-01_Y_04.txt      (~4 MB)
    LRI1B_2020-01-01_Y_04.txt      (~8 MB)
    ACH1B_2020-01-01_C_04.txt      hybrid transplant accelerometer (ACX)
    AHK1B_2020-01-01_C_04.txt      accelerometer housekeeping
    LHK1B_2020-01-01_C_04.txt      LRI housekeeping

The last three arrive with the `.ACX` and `.LRI` daily archives rather
than with `.noLRI`, and they are what the `testACH1B`, `testAHK1B` and
`testLHK1B` rows wait for.

Tests for absent files are skipped automatically (assumption failure),
so the suite passes either way — it simply becomes stricter with data.

## Where the pool is, and where in it these files live

The files above need not sit in this folder. `testRealData` looks
them up first in the data pool named by the environment variable
`READING_DATA_POOL` and only then here. That variable is the
**DATAPOOL root**, and the day fixtures live below it:

    <READING_DATA_POOL>\RawData\tests\realdata\<name>

`<READING_DATA_POOL>\<name>` — the variable pointing straight at the
fixture folder — is still accepted, **for one release only**, so that a
repository-level and an organisation-level value both work while the
switch is made. The CI step that lists the pool reports which of the two
answered each file, so the switch is visible rather than inferred.


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
complete file, so copy the published originals into the pool (same
layout as above) to enable it:

    GRACEFO-1_kinematicOrbit_2020-01-01.txt            (~2.2 MB)

Obtain them from
https://ftp.tugraz.at/pub/ITSG/satelliteOrbitProducts/operational/GRACEFO-1/,
which serves them gzip-compressed; `readItsgProduct` reads `.gz`
directly, so they need not be expanded.

The frame and the time system are **not** in these files. They come from
the server's `README.txt` and `README_referenceFrames.txt`, which is why
`aux.frameSource` exists — see `readItsgProduct`.


# Classic GRACE (RL02, 2008-01-01) — binary products

`testClassicProducts.m` reads these six bundled files. They are the
evidence that discharged obligation **O-1**: until 2026-09-22 the
classic column layouts were assumed from the GRACE Level-1B handbook
and no real classic file existed in this repository.

    ACC1B_2008-01-01_A_02.dat      78 bytes/record
    SCA1B_2008-01-01_A_02.dat      47
    GNV1B_2008-01-01_A_02.dat     103
    KBR1B_2008-01-01_X_02.dat      93   (the A+B link, satellite token X)
    THR1B_2008-01-01_A_02.dat     179
    MAS1B_2008-01-01_A_02.dat     variable, prod_flag driven

**These are trimmed.** Each is the first 40 records of the published
file, with the `NUMBER OF DATA RECORDS` header record rewritten to 40 —
padded back to the 80-character record width so the header keeps its
shape. Every other header record, and every data byte kept, is exactly
as published.

Two header fields therefore still describe the **full** published file
and not the extract: `FILESIZE (BYTES)` and `TIME LAST OBS`. That is
deliberate. The reader must not depend on either — it checks the record
count against the data section instead — and leaving them as published
is what proves it does not.

The layouts were derived from these files rather than from a handbook,
and each was checked against a quantity it must reproduce: the
quaternion norm (SCA1B), the orbit radius and speed (GNV1B), the
agreement between the range-rate column and the derivative of the
biased range (KBR1B), and the agreement of the thruster- and tank-based
spacecraft masses (MAS1B). `tests/python_reference/classic_reference.py`
is the independent decoder the golden numbers come from; run it to
regenerate them:

    python3 tests/python_reference/classic_reference.py tests/realdata

Classic **MAG1B** and **AHK1B** are deliberately not supported. Their
record structure was measured too (MAG1B is 63 bytes with 13 float32
after the time frame, and |B| comes out at 18–55 µT), but ten of
MAG1B's thirteen columns could not be named from a documented sibling
product, and AHK1B's variable columns carry per-bit value *types* that
a single file cannot reveal. Naming them from memory is the failure O-1
exists to prevent, so both are refused with an explicit error.

## Release 03

RL03 publishes only two of these products (plus the ACT1B transplant
archive, which is not bundled). Both are here, trimmed the same way:

    SCA1B_2008-01-20_A_03.dat      47 bytes/record, 1 Hz
    KBR1B_2008-01-01_X_03.dat      93 bytes/record, 5 s

The record layouts are **identical to RL02**, measured. The RL03
KBR1B is of the same day as the RL02 one, which makes the pair the
strongest single piece of evidence for that layout: decoded with one
table, the two files agree **bit for bit** on `biased_range`,
`range_rate`, `range_accl`, `iono_corr` and all four SNRs, and differ
only in the reprocessed `ant_centr_corr` — by 1.7 micrometre — and in
`qualflg`. A wrong offset could not produce that pattern.

Two differences are properties of the product rather than the layout:
RL03 SCA1B samples at 1 Hz where the RL02 file samples at 5 s, and its
`sca_id` uses head codes 1, 4, 5, 6, 7 and 8 where RL02 uses 1, 2 and
4. The `sca_id` ↔ `qualflg` bit 3 correspondence that holds on the
RL02 file therefore does **not** generalise: on the RL03 day it holds
in 57 % of records. It is evidence about those bytes, not a law.

# Official event lists (TN-01, TN-01a)

`testEventLists.m` reads these two:

    TN-01_SOE.txt      sequence of events, machine-readable
    TN-01a_SCE.txt     spacecraft events, the operators' log

Both are **extracts** of the published lists. TN-01 keeps the leading
default rows — which carry the `x`-disabled lines and the QSA
quaternions — followed by a block containing manoeuvre (`MANV`) rows.
TN-01a keeps its eight header comment lines and the first days, which
between them show several entries under one date and wrapped
continuation lines.
