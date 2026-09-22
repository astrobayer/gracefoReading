# Real PO.DAAC test data

`testRealData.m` looks for real GRACE-FO RL04 files here by their
original names. Included with the toolbox (small):

    MAS1B_2020-01-01_C_04.txt      (~8 KB)
    THR1B_2020-01-01_C_04.txt      (~95 KB)
    ACH1B_2020-01-01_D_04.txt      (~25 KB, trimmed - see below)

To enable the full acceptance suite, copy in addition (too large to
bundle; obtain from PO.DAAC, https://podaac.jpl.nasa.gov/, or the ISDC
mirror):

    ACT1B_2020-01-01_C_04.txt      (~14 MB)
    GNV1B_2020-01-01_C_04.txt      (~23 MB)
    SCA1B_2020-01-01_C_04.txt      (~11 MB)
    KBR1B_2020-01-01_Y_04.txt      (~4 MB)
    LRI1B_2020-01-01_Y_04.txt      (~8 MB)
    AHK1B_2020-01-01_C_04.txt      accelerometer housekeeping
    LHK1B_2020-01-01_C_04.txt      LRI housekeeping

These two arrive with the `.LRI` daily archive rather than with
`.noLRI`, and they are what the `testAHK1B` and `testLHK1B` rows wait
for. ACH1B, which arrives with `.ACX`, no longer waits: it is bundled.

**A bundled fixture can be shadowed, and one of them was.** The lookup
is pool first, this folder second, so a full-day file of the same name
in the pool replaces the trimmed extract. That is exactly what happened
to ACH1B on CI run 35707090459: the owner's pool holds the full
published day under the bundled name, the row read 86 400 records where
it asserted 120, and it failed on exactly the four length-dependent
lines while agreeing on every value. A fixture that passes only when
the pool is absent is not an acceptance point, so `testACH1B` now
**derives** what depends on the record count and refuses any length
that is neither 120 nor 86 400.

`testMAS1B` and `testTHR1B` still hard-code theirs. They would fail the
same way, loudly rather than silently, if a full day were put in the
pool under `MAS1B_2020-01-01_C_04.txt` or `THR1B_2020-01-01_C_04.txt`.

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


# Hybrid transplant accelerometer (ACH1B, GRACE D)

    ACH1B_2020-01-01_D_04.txt      the first 120 records of the
                                   published day, `num_records`
                                   rewritten to 120

Satellite **D** and not C: D is the one whose accelerometer failed, and
therefore the one the ACU + ACS + ACM + AC0 transplant exists for.

The complete published file was read before the extract was cut, and
three properties come from it rather than from the 120 records:

* 86 400 records, first epoch MJD 58849 0 s, last 86 399 s;
* twelve declared variables and **nine** observation columns — exactly
  the columns of classic ACC1B, which is independent confirmation of
  the classic layout measured below;
* `ang_accl_x/y/z` are identically **zero in all 86 400 records**. The
  transplant supplies linear accelerations only; the angular columns
  are declared, so the reader must still return them.

`testACH1B` passes on either file. Its length-dependent expectations
are derived from the record count - at 1 Hz from midnight with no gap,
the last epoch is fixed by the count alone, which is a *stronger*
statement on the full day than on the extract - and everything else
(the twelve declared variables, the nine observation columns, the
satellite identifier, the first record's accelerations, the zero
angular columns) is asserted outright because it does not depend on
how many records were kept.


# Classic GRACE (RL02, 2008-01-01) — binary products

`testClassicProducts.m` reads these seven bundled files. They are the
evidence that discharged obligation **O-1**: until 2026-09-22 the
classic column layouts were assumed from the GRACE Level-1B handbook
and no real classic file existed in this repository.

    ACC1B_2008-01-01_A_02.dat      78 bytes/record
    SCA1B_2008-01-01_A_02.dat      47
    GNV1B_2008-01-01_A_02.dat     103
    KBR1B_2008-01-01_X_02.dat      93   (the A+B link, satellite token X)
    THR1B_2008-01-01_A_02.dat     179
    MAS1B_2008-01-01_A_02.dat     variable, prod_flag driven
    MAG1B_2008-01-01_A_02.dat      63

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

ACC1B's nine columns have a second, documentary witness. The GRACE
Level-1B **ATBD** (JPL D-27672, §3.1.4 step 8) says `ACC_1B` carries
"the six components of compressed ACC data (3 linear and 3 angular
accelerations), the fit residuals and quality flags" — six plus three,
stated by a document that never mentions a byte. Step 6 says why there
are *three* residuals and not six: they are compressed minus
uncompressed **linear** acceleration at the integer second, flagged
above 10 µm/s², the same threshold the GRACE-FO ACH1B header gives for
`qualflg` bit 2. The ATBD holds no record formats otherwise, so it
names nothing here — it only agrees.

The layouts were derived from these files rather than from a handbook,
and each was checked against a quantity it must reproduce: the
quaternion norm (SCA1B), the orbit radius and speed (GNV1B), the
agreement between the range-rate column and the derivative of the
biased range (KBR1B), and the agreement of the thruster- and tank-based
spacecraft masses (MAS1B). `tests/python_reference/classic_reference.py`
is the independent decoder the golden numbers come from; run it to
regenerate them:

    python3 tests/python_reference/classic_reference.py tests/realdata

## MAG1B, and why AHK1B is still refused

**MAG1B is supported since 2026-09-22.** Its 63-byte record is
measured — 86 400 records over a 5 443 200-byte data section is 63.0
bytes each, and no other field count fits at these widths — and its
eighteen columns are **named from the GRACE Level-1B Data Product User
Handbook v1.3 (JPL D-22027), section 6.8, pages 38–39**, which is in
hand. That is the whole difference from the situation obligation O-1
records: the earlier layouts were recalled from that handbook, these
are read out of it. The measured magnitudes then have to agree, and do:
|B| is 18.3–54.5 µT on GRACE A and 19.5–54.4 µT on GRACE B over the
full day — the geomagnetic field at 480 km — the six magnetorquer
currents stay inside the 120 mA `torque_cal` full scale, and the three
`MF_BCal*` calibration columns are constants (54, 54, 53).

Classic **AHK1B** is still deliberately not supported, and neither
document in hand changes that. The handbook's chapter 6 has **no AHK1B
entry at all**; the ATBD has no record formats whatsoever — searched end
to end, `prod_flag`, "Data Type" and "Byte Length" appear zero times. The
product appears only in the report-file appendix, which names its eight
`qualflg` bits and nothing else. Its records are variable-length —
8 700 records over 526 350 data bytes is 60.5 bytes each — so a
`prod_flag` walk needs a per-bit value *type* for every bit, and those
are documented nowhere available here. One file cannot reveal them.
Naming them from memory is the failure O-1 exists to prevent, so AHK1B
is refused with an explicit error.

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
