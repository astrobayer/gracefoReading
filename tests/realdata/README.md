# Real PO.DAAC test data

`testRealData.m` looks for real GRACE-FO RL04 files here by their
original names. Included with the toolbox (small):

    MAS1B_2020-01-01_C_04.txt      (~8 KB)
    THR1B_2020-01-01_C_04.txt      (~95 KB)
    ACH1B_2020-01-01_D_04.txt      (~25 KB, trimmed - see below)
    CLK1B_2020-01-02_C_04.txt      (~12 KB, trimmed - see below)
    TIM1B_2020-01-02_D_04.txt      (~10 KB, trimmed - see below)

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

Which ISDC daily archive (`gracefo_1B_2020-01-01_RL04.ascii.<set>.tgz`)
holds which file, MEASURED by listing the three on 2026-11-07:

    .noLRI  (147 MB)  ACT1B, AHK1B, GNV1B, KBR1B, SCA1B
    .LRI    (28 MB)   LHK1B, LRI1B
    .ACX    (17 MB)   ACH1B

AHK1B is in `.noLRI`; this file said `.LRI` until then. ACH1B no longer
waits: it is bundled. toolboxInstaller's *Get test data* (1.3.3 and
later) fetches exactly these files, pinned by SHA-256, into the pool.

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

**The two clock fixtures (issue #29)** are 60 records each of the
published 2020-01-02 files, header and record text byte for byte, with
only `num_records` rewritten. They were copied from the runner's
DATAPOOL (`GRACEFO\L1B\RL04\2020\2020-01-02\`) by a scan that printed
them as base64 in the CI log of PR #31:

- `CLK1B_2020-01-02_C_04.txt` - records 1..60. The only CLK1B product
  whose time tag is the single column `rcv_time`; its first epoch is
  written twice.
- `TIM1B_2020-01-02_D_04.txt` - records 7862..7921 of 10 800. Records
  11..41 of the extract (7872..7902 of the day) carry receiver time 0
  and qualflg bit 3, "Receiver Time mapping not defined".

The full days are in the pool under `GRACEFO\L1B\...`, not under
`RawData\tests\realdata`, so they do not shadow these extracts.

`testMAS1B` and `testTHR1B` still hard-code theirs. They would fail the
same way, loudly rather than silently, if a full day were put in the
pool under `MAS1B_2020-01-01_C_04.txt` or `THR1B_2020-01-01_C_04.txt`.

Tests for absent files are skipped automatically (assumption failure),
so the suite passes either way — it simply becomes stricter with data.

## Where the pool is, and where in it these files live

The files above need not sit in this folder. `testRealData` looks
them up first in the data pool named by the environment variable
`DATAPOOL` — or, when it is unset, `READING_DATA_POOL`, the older name
(1.3.2) — and only then here. That variable is the
**DATAPOOL root**, and the day fixtures live below it:

    <DATAPOOL>\RawData\tests\realdata\<name>

`<DATAPOOL>\<name>` — the variable pointing straight at the
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
which serves them gzip-compressed only (`kinematicOrbit/2020/...txt.gz`;
the `.txt` URL is 404). They need not be expanded: the fixture lookup
(`testRealData.resolveFixture`) accepts `<name>.gz` beside `<name>`, and
the readers read `.gz` directly.

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

`testClassicProducts.m` reads these eight bundled files. They are the
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
    AHK1B_2008-01-01_A_02.dat      variable, 4-byte prod_flag driven

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

## MAG1B and AHK1B

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

**AHK1B is supported since 2026-09-22 too**, and it was the hardest of
the eight. Neither the handbook (no chapter-6 entry) nor the ATBD (no
record formats at all) describes it. What does is the **JPL GRACE
Level-1 read software**, `GraceReadSW_L1` release 2010-03-31 — the
producer's own reference implementation, where `GRACEiolib.h` types
`AHK1X_t` as `ACC1A_t` and `ReadACC1AFRecord.c` walks the `prod_flag`
bit by bit. Nothing from that archive is vendored here: it was used to
read, and the real files were used to check.

Two things make AHK1B unlike every other classic product, and are why
no single file could have revealed it:

* its `prod_flag` is **four bytes**, addressing 29 conditional columns
  rather than 8;
* those columns do **not share a type** — seven `double`, eighteen
  `single`, then `uint8`, `uint16`, `uint8`, `int32`.

The walk consumes the data section **to the byte** on four independent
files: JPL's own 2003 RL00 samples for GRACE A and B, and the RL02
files of 2008-01-01 for A and B. The oracle is the named supply rails,
which have to come out at nominal or some width is wrong: +15 V at
14.91, −15 V at −14.90, +5 V at 5.05, +48 V at 50.18, −48 V at −50.39,
with four electronics temperatures between 17 and 52 °C.

The bundled extract is deliberately cut to span **both** `prod_flag`
patterns the day uses: 34 records carry the short set and 6 carry the
long one that adds the temperatures, the rails and the status byte, so
the NaN pattern for absent columns is exercised too.

## The ASCII variant (`.asc`)

Four of the bundled binaries have an ASCII twin:

    ACC1B_2008-01-01_A_02.asc      an ordinary fixed record
    MAG1B_2008-01-01_A_02.asc      the column-order deviation
    MAS1B_2008-01-01_A_02.asc      an 8-bit prod_flag
    AHK1B_2008-01-01_A_02.asc      a 32-bit prod_flag, bit-string status

**They are generated, not published**, by
`tests/python_reference/classic_ascii.py` from the bundled binary files
— the owner's own data, rendered in the producer's own format. That
generator is **verified byte-identical** to the JPL Level-1 read
software's `Bin2AsciiLevel1` output on all eight products of its 2003
sample set, every record, no difference at all:

    python3 tests/python_reference/classic_ascii.py --verify <RELEASE_dir>

Nothing from that archive is in this repository; it is the oracle.

### The ASCII variant is *not* the binary columns as text

That assumption is what the old `classicExperimental` warning was
hedging, and it was wrong in two places:

* **MAG1B prints `GRACE_id` before `time_ref`** — the opposite of its
  binary record, and of every other classic product. Read in binary
  order the two characters come back exchanged, which no numeric check
  would ever catch. (`WrAsciiMAG1XFRecord.c` passes `string1, string2`
  where its THR1B sibling, holding the same two variables, passes
  `string2, string1`.)
* **AHK1B writes `status` as eight bit characters**, not a number. Read
  as a decimal it is 10 111 111 instead of 191. The reader decodes it
  back to its value rather than exposing a bit string, because the
  column is *conditional* — absent in 34 of the 40 records — and a bit
  string cannot express "absent" the way `NaN` can.

Both now come from `classicLayout` (`asciiNames`, `asciiBitString`), so
the ASCII path reads them rather than assuming them.

### One thing the ASCII variant loses

It is **not lossless for AHK1B's single-precision columns**: the
producer writes them with `%.10g`, so they come back within **3.3e-10**
relative of the binary value rather than exactly. Its one double column
(`bias_vol`) uses `%.16g` and is exact, as is every column of the other
three products. The acceptance test uses those two tolerances and not
one loose one.

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
