# Changelog — gracefoReading

## 1.4.0 — 2026-11-09

### Added — the repository owns its test-data list, `tests/data/SOURCES.json`

- The third-party files the real-data tests look for in the data pool
  were listed only in toolboxInstaller's registry
  (`registry/gracefoReading.json`, `tests.data.sources`), and nothing
  tied that list to the tests (the owner's request, 2026-11-09). The
  installer now reads it from this repository.
- `tests/data/SOURCES.json` is `{"schema": 1, "sources": [...]}`, the
  registry array copied verbatim (Python `json.load` / `json.dump`,
  indent 2, UTF-8, LF). Three sources: the ISDC `.noLRI` and `.LRI`
  archives of 2020-01-01 (ACT1B, AHK1B, GNV1B, KBR1B, SCA1B; LHK1B,
  LRI1B) and the ITSG kinematic orbit day; each with `url`, `files`
  (relative to `<DATAPOOL>\RawData\tests\realdata\`), `MB`, `sha256`,
  `licence`, `licenceText`, `description`.
- `tests/testDataSources.m` (4 points) makes it authoritative: the pool
  names are derived from the tests' own code (`resolveFixture`
  arguments, and `requireFile` arguments whose file is not bundled in
  `tests/realdata`) and must equal the listed files in both directions;
  schema 1, unique ids and the required fields are checked. It needs no
  pool and downloads nothing. Fault-injected: a dropped file, an unread
  file, and a duplicate id with a missing `url` each fail exactly the
  matching point.
- Documentation: README (*Verify the installation*) and
  `tests/realdata/README.md`.

### Fixed — the CI comments name both pool variables

- `.github/workflows/ci.yml` said the pool comes from
  `READING_DATA_POOL` only. Since 1.3.2 the suite reads `DATAPOOL` first
  and falls back to `READING_DATA_POOL`; the comments now say so, and
  that a `DATAPOOL` in the runner's own environment wins over the value
  the workflow passes. Comments only: the workflow still sets
  `READING_DATA_POOL` alone.

Tests: 163 + 4 = 167.

## 1.3.3 — 2026-11-09

### Fixed — installing no longer leaves the working tree modified

- `setupGraceFOReading` registers the documentation with
  `builddocsearchdb(html)`, which writes `html/custom_toolbox.json` and
  `html/helpsearch-v4_en/`. 1.3.2 committed those four generated files
  by mistake, so every install rewrote tracked files and `git status`
  showed them modified (the owner's report, 2026-11-09).
- They are untracked again and listed in `.gitignore`
  (`html/helpsearch-v4_en/`, `html/custom_toolbox.json`), as the other
  astrobayer repositories do. Setup still builds the search database;
  it is simply never committed.
- `docsrc/generate_html.py` never wrote these files, so regenerating
  the documentation cannot re-add them, and the CI sync check
  (`git diff --exit-code -- html/`) is unchanged. No code changed and no
  test was added or removed: 163.

## 1.3.2 — 2026-11-08

### Changed — the tests read `DATAPOOL` first, then `READING_DATA_POOL`

- The owner's data pool rule of 2026-11-08 (toolboxInstaller
  `docs/DATA_POOL.md`): every astrobayer repository resolves the pool
  root as `DATAPOOL`, then `READING_DATA_POOL` (the older name, still
  read, never required). The installer's `startup.m` sets `DATAPOOL`.
- `testRealData.resolvePool`, the single point of access for the pool
  location, now reads `DATAPOOL` and falls back to `READING_DATA_POOL`
  only when `DATAPOOL` is unset or empty. A set `DATAPOOL` decides even
  when it names no folder (the points then skip, as with an unset
  variable). The layout below the root is unchanged:
  `<ROOT>\RawData\tests\realdata\<name>`, then `<ROOT>\<name>`, each
  also as `.gz`. `testItsgProducts` and `ci/benchmarkParse` resolve
  through it as before; their messages name both variables.
- This toolbox downloads nothing, so nothing else changes. CI keeps
  passing the repository variable as `READING_DATA_POOL`, which remains
  a valid fallback.
- Documentation: README, `tests/realdata/README.md`, `docs/CI_SETUP.md`
  and the `verifyDataPool` help (input description and example 1).
  No test was added or removed: 163.

## 1.3.1 — 2026-11-07

### Fixed — which archive holds which real-data fixture

- `tests/realdata/README.md` said AHK1B and LHK1B arrive with the `.LRI`
  daily archive. Measured by listing the three ISDC archives of 2020-01-01:
  `.noLRI` holds ACT1B, AHK1B, GNV1B, KBR1B, SCA1B; `.LRI` holds LHK1B and
  LRI1B; `.ACX` holds ACH1B. The README now carries that table.
- The README said the ITSG orbits "need not be expanded", but
  `testRealData.resolveFixture` looked only for the `.txt`. It now tries
  `<name>` and then `<name>.gz` in each pool location; the readers read
  `.gz` directly. No test was added or removed: 163.

## 1.3.0 — 2026-09-27

Classic units and qualflg meanings, for timeSeriesPreparation X-13
(classic GRACE).

### Added — classic units and flag meanings from the handbook

- Classic headers state no units and no bit meanings. Until now
  `aux.variableUnits` held only `char` for classic files and
  `decodeQualFlags` reported every classic bit "(not documented)";
  downstream, a unit check refused a classic arc and a THR1B mask refused
  on_time columns without milliseconds.
- `classicLayout` now carries both, per product, from the GRACE Level-1B
  Data Product User Handbook v1.3 (JPL D-22027), chapter 6: 6.2 ACC1B,
  6.5 GNV1B, 6.7 KBR1B, 6.8 MAG1B, 6.9 MAS1B (qualflg and prod_flag),
  6.10 SCA1B, 6.11 THR1B. The readers put them where a GRACE-FO header
  would: `aux.variableUnits` and
  `aux.variableAttributes.<name>.flag_meanings`.
- Units are spelled as the GRACE-FO headers spell the same quantity
  (`seconds`, `microseconds`, `milliseconds`, `m/s2`, `rad/s2`, `m`,
  `m/s`, `kg`); the others keep the handbook's (`0.1 dB-Hz`, `microT`,
  `mA`). AHK1B has no chapter-6 table and states no units beyond its
  microsecond time fraction. A caller's `ColumnNames` gets none.
- The meanings agree with the data where the data can say: SCA1B bit 3,
  "data from 1 star camera only", selects exactly the records whose
  `sca_id` is 1.
- `decodeQualFlags`: the stale sentence that classic qualflg may be a
  decimal number is gone; it is a byte rendered as a bit string.

## 1.2.0 — 2026-09-27

Release of the classic GRACE work merged since 1.1.0 (G-02 and its
follow-ups, below) together with issue #29. timeSeriesPreparation's X-13
waits for this release.

### Fixed — CLK1B is read (#29)

- v1.1.0 refused every CLK1B file with `readL1b:noTime`: its time tag is
  one integer column, `rcv_time`, "Seconds past 12:00:00 noon of January
  1, 2000 in Receiver Time", which no detection rule knew. `resolveTime`
  now takes a single `rcv_time` after `gps_time` and before the split
  pairs. The tag is returned as written - receiver time; GPS time is
  rcv_time + eps_time, the caller's step. `aux.timeSystem` still reads
  'GPS', as it does for every receiver-time tag; `aux.timeVariable`
  names the column.

### Added — zero time tags are reported, and can be dropped (#29)

- Real TIM1B_2020-01-02_D_04 carries 31 records whose receiver time is
  0 (records 7872..7902 of 10 800), which v1.1.0 returned as epochs at
  2000-01-01 12:00:00 without a word. `readL1b` now counts records whose
  tag is exactly 0 in `aux.numRecordsZeroTime` and reports them with the
  new warning `gracefoReading:readL1b:zeroTime` (count, first record,
  what was done). The new option `'DropZeroTime'` (default false)
  removes them; `readL1bMulti` forwards it and returns the counts per
  file. The product flags the same records itself, with qualflg bit 3
  ("Receiver Time mapping not defined"), so `'QualityBitMask', 3`
  selects exactly them on that file.
- Two trimmed real fixtures, 60 records each and taken byte for byte
  from the DATAPOOL: `CLK1B_2020-01-02_C_04.txt` and
  `TIM1B_2020-01-02_D_04.txt`.
- Not a defect, recorded: CLK1B_2020-01-02_D_04's nine records with
  |eps_time| < 1e-6 s are the clock offset crossing zero at a steady
  drift of −9.6e-9 s/s, with qualflg 0.
- Four synthetic warning-free tests wrote a first record at tag 0; their
  first tag moved to 1 or 10 s, because a 0 now warns by design.

### Changed — the classic ASCII variant is measured, and stops warning

- `classicExperimental` no longer fires for a built-in layout. The
  ASCII column order and rendering are now **measured** against the
  JPL Level-1 read software's own `Bin2AsciiLevel1`, whose output
  `tests/python_reference/classic_ascii.py` reproduces **byte for
  byte** on all eight products of its 2003 sample set.
- The warning was right to exist. "The ASCII columns are the binary
  ones" is **false in two places**, and both fail silently:
  - **MAG1B prints `GRACE_id` before `time_ref`** — the opposite of
    its binary record and of every other classic product. Read in
    binary order the two characters come back exchanged, and no
    numeric check would ever notice.
  - **AHK1B writes `status` as eight bit characters**, not a number:
    read as a decimal it is 10 111 111 instead of 191.
- A third defect was found on the way, with no ASCII quirk behind it:
  AHK1B's split tag is `rcvtime_frac`, and the microsecond rule keyed
  on the literal name `time_frac`, so the fraction scaled by **1**
  instead of 1e-6 — every epoch out by a factor of a million, silently.
  The rule is now the `_frac` suffix.
- `classicLayout` carries the ASCII deviations (`asciiNames`,
  `asciiBitString`) so the parser reads them instead of assuming them;
  `parseClassicProduct` takes the column order, the character columns,
  the fractional unit and the rendering from there rather than from a
  hard-coded list.
- A column declared as bit characters is decoded back to its **number**
  rather than exposed as a bit string, because AHK1B's `status` is
  *conditional* — absent in 34 of 40 records — and a bit string cannot
  express "absent" the way `NaN` can. A token that is not a bit string
  raises the new `gracefoReading:readL1b:badBitString`.
- **`ColumnNames` still warns.** Those names are the caller's claim
  about the file; nothing here has checked them against it, and a
  wrong order yields plausible numbers rather than an error.
- Four ASCII fixtures are bundled, generated from the owner's own
  binary files by the verified writer. Nothing from the JPL archive is
  vendored.
- **Known limitation, measured:** the ASCII variant is not lossless for
  AHK1B's single-precision columns — the producer writes them `%.10g`,
  so they return within 3.3e-10 relative of the binary value. Its one
  double column is exact, as is every column of the other products.

### Added — classic MAG1B is read (O-15, first half)

- The magnetometer and magnetorquer product is no longer refused.
  Its 63-byte record is **measured**: the published GRACE A file of
  2008-01-01 is 86 400 records over a 5 443 200-byte data section,
  which is 63.0 bytes each and admits no other field count at these
  widths, and the first and last epochs equal the header's
  `TIME FIRST OBS` / `TIME LAST OBS` to the microsecond.
- Its eighteen columns — `time_intg`, `time_frac`, `time_ref`,
  `GRACE_id`, `MfvX/Y/Z_RAW`, `torque1A`…`torque3B`, `MF_BCalX/Y/Z`,
  `torque_cal`, `qualflg` — are **named from the GRACE Level-1B Data
  Product User Handbook v1.3 (JPL D-22027), section 6.8, pages 38–39**,
  which is now in hand. That is the difference obligation O-1 turns
  on: the layouts it flagged were *recalled* from that handbook, these
  are *read out of* it.
- The naming is then checked against what the numbers must be: |B| is
  **18.3–54.5 µT** on GRACE A and 19.5–54.4 µT on GRACE B over the
  full day — the geomagnetic field strength at 480 km — the six
  magnetorquer currents stay inside the 120 mA `torque_cal` full
  scale, and `MF_BCalX/Y/Z` are the constants 54, 54, 53. If the
  vector were not the first three floats, none of that would hold.
- `MAG1B_2008-01-01_A_02.dat` is bundled, trimmed to 40 records the
  same way as the other classic fixtures, and
  `tests/python_reference/classic_reference.py` decodes it too, so the
  golden numbers still come from outside the code they test.

### Unchanged — classic AHK1B is still refused

- The handbook does not close this half of O-15 and says so plainly:
  chapter 6 has **no AHK1B entry at all**. The product appears only in
  the report-file appendix, which names its eight `qualflg` bits and
  nothing else.
- Its records are variable-length — 8 700 records over 526 350 data
  bytes is 60.5 bytes each — so a `prod_flag` walk needs a per-bit
  value **type** for every bit, and no document available here states
  them. One file cannot reveal them. AHK1B therefore keeps raising
  `unsupportedClassicProduct`, and the refusal test now exercises it
  rather than MAG1B.

### Added — ACH1B is bundled, so its acceptance row no longer skips (G-04, #19)

- `ACH1B_2020-01-01_D_04.txt`, the hybrid transplant accelerometer,
  is bundled trimmed to its first 120 records. Satellite **D** and not
  C: D is the one whose accelerometer failed and therefore the one the
  ACU + ACS + ACM + AC0 transplant exists for.
- The **complete** published day was read before the extract was cut:
  86 400 records, first epoch MJD 58849 0 s, last 86 399 s, twelve
  declared variables and **nine** observation columns — exactly the
  columns of classic ACC1B, which is independent confirmation of that
  measured layout — and `ang_accl_x/y/z` identically **zero in all
  86 400 records**, the transplant supplying linear accelerations
  only. `testACH1B` asserts what survives the trim and states the rest
  as a measurement of the full file.
- **The row passes on either file, which took a red run to get
  right.** The fixture lookup is pool first, bundled second, and the
  owner's pool holds the full published day under the same name: the
  first version of this row asserted 120 records, read 86 400 and
  failed on exactly the four length-dependent lines (CI run
  35707090459). Every value-level assertion passed on the full day —
  which is itself the strongest confirmation the extract is faithful.
  What depends on the record count is now derived from it (at 1 Hz
  from midnight with no gap, the last epoch is `n-1`, a stronger
  statement on the full day than on the extract) and a length that is
  neither 120 nor 86 400 is refused outright.
- `testMAS1B` and `testTHR1B` still hard-code their record counts and
  would be shadowed the same way. That fails loudly rather than
  silently, so it is written down in `tests/realdata/README.md` rather
  than fixed in passing.
- The CI pool listing names `ACH1B_2020-01-01_D_04.txt` again, now
  that the run has shown the pool holds it; `testAHK1B` and
  `testLHK1B` still wait for theirs.

### Added — classic AHK1B is read, and O-15 closes completely

- The accelerometer housekeeping product is the last classic binary
  product this toolbox refused, and the hardest: neither the Level-1B
  handbook (no chapter-6 entry) nor the ATBD (no record formats at
  all) describes it. What does is the **JPL GRACE Level-1 read
  software** (`GraceReadSW_L1`, release 2010-03-31) — the producer's
  own reference implementation, where `GRACEiolib.h` types `AHK1X_t`
  as `ACC1A_t` and `ReadACC1AFRecord.c` walks the `prod_flag` bit by
  bit.
- Two facts from it are why **no single file could ever have revealed
  this layout**: `prod_flag` is **four bytes**, addressing 29
  conditional columns rather than 8, and those columns do **not share
  a type** — seven `double`, eighteen `single`, then `uint8`,
  `uint16`, `uint8`, `int32`.
- Verified rather than trusted. The record walk consumes the data
  section **to the byte** on four independent files: JPL's own 2003
  RL00 samples for GRACE A and B, and the RL02 files of 2008-01-01 for
  A and B. The oracle is the named supply rails, which cannot come out
  right if any width in the walk is wrong: **+15 V at 14.91, −15 V at
  −14.90, +5 V at 5.05, +48 V at 50.18, −48 V at −50.39**, with four
  electronics temperatures between 17 and 52 °C.
- `parseClassicBinary` now takes the flag width **and every column
  type** from the layout instead of assuming one byte and one shared
  type. A record that sets a bit the layout does not define raises the
  new `gracefoReading:readL1b:classicUndefinedProdFlagBit` — the field
  is there but its width is unknown, so every byte after it would be
  misread.
- AHK1B calls its split tag `rcvtime_intg`/`rcvtime_frac` (it shares
  the ACC1A record); the time detection accepts both spellings.
- `AHK1B_2008-01-01_A_02.dat` is bundled, trimmed to 40 records cut so
  that **both** `prod_flag` patterns of the day appear — 34 short, 6
  long — which exercises the NaN pattern for absent columns too.
- **Nothing from the JPL archive is vendored here.** It was used as an
  offline oracle and is cited; every fixture still comes from the
  owner's own files.

### Fixed — two integer types were signed where the producer declares them unsigned

- `KBR1B`'s four SNR columns are `uint16_t` and `THR1B`'s 42 counters
  are `uint32_t`, per the JPL read software. **Neither changes a value
  in any bundled file** — the SNRs reach 690 of 32 767 and the
  counters 89 329 647 of 2^31 — so no golden number moved. This is
  hardening against a large value on some other day.
- The same archive independently confirmed **all seven** previously
  measured layouts, struct by struct and name for name, including the
  MAG1B naming taken from the handbook earlier the same day.

### Documented — the ACC1B nine-column correction has a second witness

- The GRACE Level-1B **Algorithm Theoretical Basis Document** (JPL
  D-27672 / GRACE 327-741, v1.2, 2006) is now in hand. Its §3.1.4
  step 8 says `ACC_1B` carries "the six components of compressed ACC
  data (3 linear and 3 angular accelerations), the fit residuals and
  quality flags" — six plus three, from a document that never mentions
  a byte. That is a third independent line of evidence for the layout
  correction O-1 turned on, after the bytes themselves and after
  ACH1B's declared columns.
- Step 6 explains an asymmetry the bytes showed but did not explain:
  residuals are compressed minus uncompressed **linear** acceleration
  at the integer second, which is why there are three `acl_*_res` and
  not six. Its 10 µm/s² flag threshold matches the GRACE-FO ACH1B
  header's `qualflg` bit 2 word for word.
- Appendix G is the authority for `aux.timeSystem = 'GPS'`: GPS time
  is the corrected receiver time used in all Level-1B data. It also
  gives the `time_ref` column its meaning (`R` receiver, `G` GPS).
- **It does not close the AHK1B half of O-15**, and that is recorded
  so a later session does not re-open the hope: the ATBD carries no
  record formats at all — `prod_flag`, "Data Type", "Byte Length" and
  `qualflg` appear zero times in 54 pages, and AHK1B appears twice,
  both as a file name of `TimeCorrHK`.
- Documentation only; no code changed.

### Verified — classic release 03 reads under the same layouts

- The 1.1.0 notes said classic RL03 was not read: release 02 was what
  had been supplied. RL03 publishes only **SCA1B and KBR1B** (plus the
  ACT1B transplant archive, still not supplied), and both were checked
  against real files on 2026-09-22. The record lengths are identical to
  RL02 — 47 and 93 bytes — and the oracles hold.
- **SCA1B RL03** (2008-01-20): quaternion norm within **9.6e-11** of
  unity over all 86 398 records.
- **KBR1B RL03** (2008-01-01) is of the *same day* as the bundled RL02
  file, which makes the pair the strongest single piece of evidence for
  that layout. Decoded with the one table, the two independently
  produced files are **bit-identical** in `biased_range`, `range_rate`,
  `range_accl`, `iono_corr` and all four SNRs, differing only in the
  reprocessed `ant_centr_corr` (1.7 µm) and in `qualflg`. A wrong
  offset could not produce that pattern.
- Two differences are the product's rather than the layout's: RL03
  SCA1B samples at 1 Hz where the RL02 file samples at 5 s, and its
  `sca_id` uses head codes 1, 4, 5, 6, 7 and 8 against RL02's 1, 2, 4.
- **Scope correction.** The `sca_id` ↔ `qualflg` bit 3 correspondence
  recorded for the RL02 file holds there and on its full day, as it was
  always stated — but it does **not** generalise: on the RL03 day it
  holds in 57 % of records. The limit is now written beside the claim,
  so it cannot be read as a law of the product.
- No code changed. Two fixtures and two acceptance points were added,
  and the documentation now says RL02 **and** RL03 where it said RL02.

## 1.1.0 — 2026-09-22

Five of the seven reader work packages of the preprocessing concept:
G-01 (#16), G-03 (#18), G-04 (#19), G-06 (#21) and G-07 (#23). MINOR,
not PATCH: `verifyDataPool` is new capability and every existing call
keeps working.

### Added — `gracefoReading.verifyDataPool` (G-06, #21)

- Verifies a local data pool against the checksums its sources publish
  and returns one table row per file: `OK`, `MISMATCH`, `MISSING`,
  `UNREADABLE`, or `UNLISTED` for a pool file no manifest covers. Each
  row names the manifest that made the claim, so a mismatch can be
  taken back to its source.
- Reads the **coreutils** manifest format (`<hex>  <name>`, and
  `*<name>` for binary mode) and the **BSD tagged** format
  (`SHA256 (<name>) = <hex>`). Entries resolve against their own
  manifest's folder, so the MD5 list inside an L1B day archive and a
  SHA-256 manifest written beside a month of data are both read where
  they lie.
- The algorithm comes from the digest **length**, a property of the
  line rather than of the manifest's file name: a list called
  `SHA256SUMS_…` that holds MD5 digests is read as what it contains,
  and a tagged line whose tag disagrees with its own digest length
  names no algorithm at all and is reported rather than verified.
  Lines matching neither format are reported by line number, never
  guessed at.
- `UNLISTED` rows are in the report on purpose. "Not checked" and
  "checked and correct" are different answers, and the ITSG and ZARM
  products publish no checksums at all — a report that showed only the
  verified files would be read as covering the pool.
- New internals: `+internal/parseChecksumManifest` and
  `+internal/fileDigest`, the latter streaming a file through
  `MessageDigest` in 1 MiB blocks and in binary mode, so a
  multi-gigabyte file is hashed without being held in memory and CRLF
  is never rewritten under it.
- The expected digests in the test suite are **not** produced by the
  code under test: the published FIPS-180 / RFC-1321 vectors for the
  byte string `abc` and independently computed digests for the other
  fixtures are the oracle.

### Added — `ci/benchmarkParse` (G-03, #18)

- Measures `readL1b` on one real ACT1B day and extrapolates to a year,
  so O-7 — whether the fixed-layout products should gain a typed
  `textscan` fast path — is decided from a number rather than an
  impression.
- Reports the total **and** `fileread` alone. Their ratio is the part
  of the answer a total cannot give: a fast path can only win back the
  difference, so a run where reading the bytes already dominates
  settles O-7 by itself.
- Asserts nothing and returns an empty result when the pool holds no
  day file; the CI step that runs it is `continue-on-error` and runs
  under `always()`, so a red suite cannot swallow the measurement. It
  is a measurement, not an acceptance point.
- **Measured** on the self-hosted runner, CI run 35698502947, MATLAB
  R2026a: one real ACT1B day (86 400 records, 13.5 MB) takes
  **7.801 s**, of which `fileread` is 0.059 s — parsing is 99.2 % of
  the cost. A year extrapolates to **47.5 min**.
- **Decided: no fixed-layout fast path**, and not for want of headroom.
  47.5 min per product-year is not a bottleneck and `'CacheDir'` pays
  it once; and it would be a second parsing path covering only one of
  the reader's three record grammars (fixed columns, `prod_flag`
  variable columns, rest-of-line). O-7 closes; `ci/benchmarkParse`
  stays so re-opening it costs one command.

### Fixed — `readL1bMulti` accepts the column `findL1bFiles` returns (G-01, #16)

- `fileNames` was declared `(1,:) string` while `findL1bFiles` returns
  `[K x 1]`, so the two-line workflow printed in **both** help blocks
  raised a size-validation error for every K > 1 (O-11, now closed).
  The declaration is unsized and normalised on entry, as
  `readItsgProductMulti` already did; `aux.fileNames` stays a column.

### Fixed — header variable names that are not MATLAB identifiers (G-04, #19)

- The accelerometer housekeeping product AHK1B declares the sensor
  temperatures `TSU Y+`, `TSU Y-`, `TSU Z+` and `TSU Z-`, the last with
  a space. The header parser accepted identifiers only, so that column
  was dropped and every record then carried one token more than the
  declared columns.
- Worse and less visible: `varAttrs` and the `aux` fields were keyed by
  `matlab.lang.makeValidName` per name, which is not injective — `+`
  and `-` both become `_`, so `TSU_Y+` and `TSU_Y-` collapsed onto one
  field and one temperature silently overwrote the other.
- `+internal/variableFieldNames` is now the single point of access for
  that mapping — `makeValidName`, truncated, then `makeUniqueStrings`
  over the whole ordered list — and the header parser, the data-section
  parser, the classic path and the time resolver all take their keys
  from it. It is the identity on every name in every product read so
  far, so nothing existing changes.
- A rename is never silent: `gracefoReading:readL1b:variableNameAdjusted`
  names each declared name and the field it landed in, and the new
  `aux.variableFieldNames` gives the mapping. `aux.variableNames` and
  `aux.obsNames` keep the declared names, which is what callers match
  on.

### Fixed — LHK1B could not be read at all (G-04, #19)

- The long-format housekeeping products end in a free-text column that
  the header declares as taking what is left of the line. Real
  `LHK1B_2020-01-01_C_04` says so in its own words —
  `comment: Entire remaining portion of each record` — and 2 886 of its
  1 169 274 records use it: `fpga_state: science_state` and
  `mode: science` carry a space, so the record holds nine
  whitespace-separated tokens where eight columns are declared. The
  reader raised `columnMismatch` on file line 537 and the product was
  unreadable.
- A last column that makes that claim, in its `comment` or
  `long_name`, now takes the rest of the line **verbatim**, internal
  spacing included, and is returned as text in `aux`. The rule is the
  header's sentence, never the column's position: `sensorname` declares
  no `units: char`, so a rule keyed on character columns would not have
  fired. Every other surplus token is still `columnMismatch` with its
  line number, a record short of the declared count is still an error,
  and the rule does not apply to a file that also declares `prod_flag`.
- Measured, not assumed: the rule was written after a temporary CI step
  dumped the real header on the runner, because the format could not be
  reached from the working session.

### Changed — `READING_DATA_POOL` is the DATAPOOL root (G-07, #23)

- Fixtures resolve as `<ROOT>\RawData\tests\realdata\<name>`, matching
  the owner's real pool layout. `<ROOT>\<name>` — the value that
  pointed straight at the fixture folder — stays accepted for **this
  release only**, so that switching from the repository-level variable
  to the organisation one cannot turn a green run into a row of skipped
  acceptance points in the same step.
- `testRealData.resolveFixture` is the one authority for that layout,
  as `resolvePool` already was for the location; `testItsgProducts` and
  `ci/benchmarkParse` both go through it. The CI reporting step prints
  which of the two paths answered each file, so the switch is visible
  rather than inferred.
- New acceptance rows for `ACH1B`, `AHK1B` and `LHK1B`, verifying the
  generic reader on real bytes through one shared invariant helper.
  They report **incomplete** until those files are in the pool.

### Added — ITSG date ranges: findItsgFiles and readItsgProductMulti (O-9)

- `gracefoReading.findItsgFiles(root, product, ...)` locates ITSG files
  by product, `'DateRange'` and `'Satellite'`, recursively by default
  (the server lays products out by year), sorts them chronologically and
  reports coverage including missing calendar days. Plain and `.gz`
  alike; an empty result is not an error.
- `gracefoReading.readItsgProductMulti(files, ...)` concatenates them
  into one continuous record, forwarding `'Product'`, `'Frame'` and
  `'TimeFormat'` to every file.
- Together these are the "one file **or a date range**" the issue asked
  for, and they mirror `findL1bFiles` + `readL1bMulti` so the ITSG side
  reads the same way as the L1B side.
- The naming convention now has one authority,
  `+internal/parseItsgFileName`, used by both the reader and the finder.
  A trailing variant marker stays with the product: `neutralDensity_ACC`
  and `neutralDensity_KIN` are distinct products (accelerometer-derived
  and kinematic-orbit-derived), so asking for `neutralDensity` matches
  neither — deliberately.

### Refused rather than concatenated

- Files of **different products**, checked first because it is the most
  informative thing to say about a bad list.
- Files of the same product with **different observation columns**,
  which means a mislabelled or malformed archive.
- `aux.allColumns` is **not** concatenated. Stacking the zero padding
  into one matrix would invite exactly the reading `readItsgProduct`
  exists to prevent; read a file on its own when the padding is wanted.
- Epoch order is **warned** about, not enforced: wrong file order and a
  genuinely duplicated day are indistinguishable from here, and only the
  caller knows which it is.

### Two design notes worth keeping

- **No frame check, deliberately.** An earlier draft had one. The frame
  is derived from the product and `'Frame'` is forwarded to every file,
  so equal products already mean equal frames — the check could never
  fire, and a documented identifier that cannot be raised is a promise
  the function cannot keep. It was removed rather than left as
  decoration, and a test now pins the reasoning.
- **`fileNames` is declared unsized and normalised**, not `(1,:)`.
  `findItsgFiles` returns a `[K x 1]` column, so a `(1,:)` declaration
  would reject exactly the call the pair exists to serve.

### Found, not fixed — readL1bMulti rejects findL1bFiles' output (O-11)

- `readL1bMulti` declares `fileNames (1,:) string` while `findL1bFiles`
  returns `[K x 1]`, so the two-line workflow printed in both help
  blocks raises a size-validation error for more than one file. Noticed
  while deciding the ITSG signature. Left alone here because it is an
  L1B change and this branch is issue #11; recorded as O-11.
- **Fixed in this same release** — see "Fixed — `readL1bMulti` accepts
  the column `findL1bFiles` returns" above (G-01, #16). Both entries
  stay: one records when the defect was found, the other when it was
  closed.

### Tests

- 12 added in `testItsgBatch` (suite 89 → **101**, measured: 100 passed,
  0 failed, 1 incomplete, CI run 34873244487). Predicted as a split and
  matched exactly, which is the rule the previous entry's missed
  reconciliation put in place.
- Fixtures here are synthetic and in the real GROOPS dialect. Only one
  date of real ITSG data exists in the repository, so a multi-day join
  cannot be exercised against real files; this suite tests the batch
  mechanics and leaves the parsing of real bytes to `testItsgProducts`.
- Green on the first CI run of this work, with every Tier B assumption
  holding: the `dir` glob built from a string pattern, the `sortrows`
  empty guard, `gzip`/`delete` in the discovery test, and the unsized
  `fileNames` declaration all behaved as reasoned.

### Added — reader for the TU Graz (ITSG) satellite orbit products (issue #11)

- `gracefoReading.readItsgProduct` reads the operational products from
  `ftp.tugraz.at/pub/ITSG/satelliteOrbitProducts/` into the toolbox's
  `[time, obs, aux]` shape: kinematicOrbit, kinematicOrbitCovariance,
  reducedDynamicOrbit, attitude and nonConservativeForces, plain or
  gzip-compressed. **Written from five real files**, which is what
  discharged obligation O-8 — the reader was deliberately not attempted
  while the format could only be guessed at.
- `readGroopsInstrument` now reads **real** GROOPS output, not only the
  dialect this toolbox's own writer emits. Real files carry comment
  lines the writer never produces — an epoch type name, a column legend
  and a rule — so every one of them previously failed on line 2 with
  `badFormat`. The header is partitioned on `#` and both dialects go
  through one path.
- The second header integer is **not** a column count in real files: it
  is `1` in all five products, against 3, 4, 6 and 9 data columns. The
  legend is the column authority where a file carries one; the raw
  integer is reported as `info.headerCount`. Column names and units come
  from that legend, so a GROOPS epoch type this toolbox has never seen
  still returns named, united columns.
- New `+internal/parseGroopsInstrument` returns both time forms, so each
  reader parses a file once rather than twice.

### Fixed — zero-padding columns were about to be returned as observations

- The GROOPS ORBIT type always writes nine data columns. A
  `kinematicOrbit` file carries position only: its six velocity and
  acceleration columns are **identically zero** in all 8640 records. A
  `reducedDynamicOrbit` file pads three. Returning them as observations
  hands a caller exactly 0 m/s at every epoch of a kinematic orbit,
  which differencing or integrating turns into silent nonsense.
- `obs` therefore carries only the columns the product actually fills;
  the rest stay in `aux.allColumns` and are named in
  `aux.paddingColumns`. Which columns are carried is documentation, so
  it is **checked against the data on every read** — a padding column
  that is not identically zero raises `paddingNotZero` instead of being
  dropped quietly.

### Added — frame and time system, with their provenance

- Measured: **neither is anywhere in these files.** No header field, no
  filename suffix, no match for icrf/itrf/frame/gps/utc/tai in any of
  the five. They come from the server's `README.txt` and
  `README_referenceFrames.txt`, which give the frame per product and
  state "All times are GPS times".
- Because that mapping is keyed on the product and the product is read
  from the file name, `aux` records how each answer was reached:
  `frameSource`, `timeSystemSource`, `productSource`. An unrecognised
  product is never given a frame by guesswork — `readItsgProduct` warns
  `productNotRecognised` and leaves `aux.frame` empty. `'Frame'` and
  `'Product'` default to empty rather than to an assumption, so an
  omission stays distinguishable from a choice.
- **The two are not documented the same way, so they are not treated the
  same way.** The frame is stated per product; the time system is stated
  once for the whole product set — "All times are GPS times" — so
  `aux.timeSystem` is `'GPS'` for every file this function reads,
  recognised or not. An earlier draft tied both to product recognition
  and withheld `timeSystem` from an unrecognised product, which withheld
  something the documentation actually gives.

### Measured — why the digit-based epoch path was necessary

- The ITSG tags carry **18 decimals** and, tested over 2000 of them, do
  **not lie on the double lattice at all**. The kinematic products sit
  **213 ns** before midnight and their sampling varies by up to
  **±291 ns** over a day, which the product README explains: they are
  corrected for receiver clock errors and are "NOT INTERPOLATED TO
  INTEGER SECONDS NOR A CONSTANT SAMPLING".
- 291 ns is **0.46 of a double's ulp** at MJD 58849. Reading these tags
  through `sscanf('%f')`, as this reader did until earlier the same day,
  would erase precisely the structure the documentation says is there.
  The `'Unreleased'` entry above it is not a nicety for these files.

### Tests

- 15 added in `testItsgProducts` against the five real fixtures
  (suite 74 → **89**, measured: 88 passed + 1 incomplete, CI run
  34869994810). Expectations derived independently in Python from the
  file bytes and the README before being written down; all 15 passed or
  skipped as predicted on the first run.
- Fixtures are the first 60 records of each published file with the
  record-count line adjusted; headers and record text are byte-for-byte
  as published, ~58 KB together.
- **One incomplete is expected**: `testFullDayKinematicJitter` needs a
  full published day from `READING_DATA_POOL`, because the receiver-clock
  variation first occurs well past record 60. It skips until
  `GRACEFO-1_kinematicOrbit_2020-01-01.txt` is copied into the pool.
- Green on the first CI run of this work: 88 passed, 0 failed, 1
  incomplete on MATLAB R2026a Update 5. Every Tier B assumption held —
  the cell-wrapped `struct` fields, the string-array header parsing and
  the rebuilt fixture in `testPaddingNotZeroWarns` all behaved as the
  Python mirror said they would.

Not version-bumped. A bump is a 31-file change (O-3) and belongs in its
own commit; these entries are the content, not a release.

### Not done — a reader for the TU Graz operational orbit products (issue #11)

- **Deliberately not implemented, and recorded as obligation O-8.** The
  issue asks for a reader for
  `ftp.tugraz.at/pub/ITSG/satelliteOrbitProducts/operational/GRACEFO-1/`
  and says of the format: "please check rather than assume". The check
  is not possible from the development sandbox — `ftp.tugraz.at` is
  refused by the egress policy (403 on CONNECT), attaching
  `groops-devs/groops` was denied, and no other reachable source
  documents the layout. **Nothing about these files has been measured.**
- Two of the four requirements cannot even be specified without a file:
  the frame must be read from the header rather than inferred from the
  `_icrf`/`_itrf` filename, and the covariance is wanted "where the
  product carries it". Both are properties of bytes nobody here has seen.
- **Answering the issue's actual question:** `readGroopsInstrument` is
  *not* established as the reader for these files. It requires its own
  writer's three-line header as line 1, so a leading comment raises
  `badFormat`; `sscanf('%f')` stops at the first non-numeric column; and
  `info` has no frame field, so the metadata could not travel with the
  data even if the parse succeeded. `findL1bFiles` cannot discover them
  either — its regexp is the PO.DAAC `PROD1B_yyyy-MM-dd_S_RR` convention.
- The unblock is one real file per sub-product in `tests/realdata/`, or
  egress for `ftp.tugraz.at`.

### Fixed — readGroopsInstrument lost sub-microsecond epochs

- The time tag was read with `sscanf('%f')`, which rounds the decimal
  MJD into a double before anything else happens. A double holds MJD
  58849 to an ulp of **0.63 us**, so every digit below that was noise.
  The epoch is now recovered from the **printed digits**: the token is
  split at the decimal point and converted in `int64` throughout.
- Measured over 100 000 epochs of 2020-01-01, comparing both paths
  against the exact nanosecond count they should reproduce: the double
  path was out by up to **314 ns**, the digit path by **0 ns**. A worked
  single case — the tag `58849.500011574074074` reads as
  `43201000000000` ns of day exactly, and as `43201000000234` ns through
  a double.
- Rounding the fraction to whole nanoseconds can reach a full day for a
  tag within ~43 ps of midnight. That carry is applied, so seconds of
  day stays in `[0, 86400)` instead of reporting `86400.0`.
- Digits past the 15th are dropped, not rounded: the 15th digit of a day
  is 86 ps, three orders below the nanosecond the result is quoted in,
  and `str2double` stops being exact beyond it.

### Added — 'TimeFormat' on readGroopsInstrument

- `"mjd"` (default, unchanged), `"datetime"` and `"gpsns"`, matching
  `readL1b` so the two readers hand off to the same downstream code.
  `"gpsns"` is only meaningful because of the digit path above; through
  a double it would have returned nine digits of which three were noise.
- New error `gracefoReading:readGroopsInstrument:badTimeToken`. An
  exponential, negative or non-numeric time tag is **refused**, not read
  approximately. Time tags are validated **before** the declared column
  count: a tag like `58849.5.5` makes `sscanf('%f')` return three values
  where two columns were declared, and `fifty` returns none, so the
  other order reported `countMismatch` for what is really a time-tag
  fault. A diagnostic is a claim too (R3). This follows `resolveTime`'s precedent exactly: a
  silent fallback to the double path would reintroduce the error the
  digit path exists to remove.
- Reader accuracy is now limited by the **writer**, not the reader:
  `writeGroopsInstrument` still forms the decimal MJD as a double before
  printing, so a write-then-read roundtrip remains a ~0.6 us operation.
  Only a file whose digits carry true sub-microsecond information
  delivers it.

### Changed — one authority for the time-format mapping

- The `'TimeFormat'` switch moved out of `readL1b` into
  `+internal/formatEpoch.m`, now called by both readers. The datetime
  epoch formula was otherwise about to exist in two files, which is the
  2026-09-06 failure mode; a divergence would have shifted every epoch
  of one reader with nothing visible to say so.

### Tests

- Six added to `testBatchTools` (8 → 14, suite 68 → **74**): exact
  nanoseconds against independently derived expectations, agreement of
  the three `'TimeFormat'` representations, the midnight carry,
  truncation past the 15th digit, refusal of four malformed tags, and
  `mustBeMember` validation of the option.
- Expectations were derived in Python from the printed digits before
  being hardcoded, per HANDOVER.md section D. The same mirror was
  fault-injected: all malformed tags refused, split/merge bitwise equal.
- CI run 34807682341 (R2026a Update 5) ran these for the first time:
  73 passed, 1 failed. The failure was `testGroopsBadTimeToken`, a real
  defect in the ordering above rather than a bad test — see the fix in
  this same entry. Everything else passed first time, including the
  exactness and midnight-carry cases.
- **Green after the fix: run 34807977113, 74 passed, 0 failed, 0
  incomplete, 54.9 s**, matching the corrected prediction exactly.

### Fixed — the record's own test counts

- HANDOVER.md section A said `testReadL1b` 22 and a suite total of 65.
  The true figures before this change were **25 and 68**: the three
  MAG1B tests added for issue #9 in v1.0.2 went into `testReadL1b` and
  the status line was never updated, so v1.0.2 shipped with a stale
  count. It surfaced only because a prediction was made against it and
  missed by exactly those three.


### Added — classic GRACE read from measured layouts (G-02, #17)

- Classic GRACE (2002–2017) products whose header says
  `FILE FORMAT 0=BINARY 1=ASCII : 0` are now read. The data section is
  packed **big-endian** binary after the 80-character ASCII header, and
  `gracefoReading.readL1b` decodes ACC1B, SCA1B, GNV1B, KBR1B, THR1B
  and MAS1B (the last variable-length, driven by `prod_flag`).
- **The layouts are measured, not remembered.** They were derived from
  the real RL02 files of 2008-01-01 for GRACE A and B. For each
  product the declared record count times the derived record length
  reproduces the data section exactly, the first epoch equals the
  header's `TIME FIRST OBS`, and a physical quantity was checked:
  quaternion norm within 1e-6 of unity in all 16 818 + 17 222 SCA1B
  records; orbit radius 6827–6862 km and speed ~7.6 km/s; the
  derivative of the biased range matching the range-rate column to a
  median 5.8e-6 m/s; and the thruster- and tank-based spacecraft
  masses agreeing to 4 g.
- **The assumed table was wrong.** Classic ACC1B has **nine**
  observation columns; the built-in table had six, the three residual
  columns (`acl_x_res`, `acl_y_res`, `acl_z_res`) missing entirely.
  That is what obligation O-1 existed to catch, and it is now closed.
- The binary variant no longer warns `classicExperimental`. The ASCII
  variant still does: it shares the corrected column table, but that
  it carries the same columns is an inference from the binary variant
  and no real classic ASCII file has been read here.
- **Classic qualflg is a single-byte bitmask** — V-8's open question,
  answered by measurement. The reader renders it as the same
  8-character bit string the GRACE-FO products use, so
  `decodeQualFlags` works on classic and modern files unchanged.
- **Classic MAG1B and AHK1B are refused**, deliberately. Their
  structure was measured too (MAG1B is 63 bytes with 13 float32 after
  the time frame, and |B| comes out at 18–55 µT), but ten of MAG1B's
  columns could not be named from any document at hand and AHK1B's
  conditional columns carry per-bit value *types* a single file cannot
  reveal. Inventing either is the failure O-1 records, so both raise
  `unsupportedClassicProduct` naming exactly what is known. See O-15.
- New internals: `readBytesMaybeGz` (byte-exact reading — a char read
  applies the file encoding and would destroy binary records
  silently), `classicLayout`, `parseClassicBinary`, and
  `parseClassicHeader`, the last shared with the ASCII path so the two
  cannot disagree about what a header says.
- Six trimmed classic fixtures are bundled, with
  `tests/python_reference/classic_reference.py` as the independent
  decoder the golden numbers come from.

### Added — `gracefoReading.readEventList` (G-05, #20)

- Reads the two official event lists: **TN-01** (sequence of events,
  machine-readable) and **TN-01a** (spacecraft events, the operators'
  log), returning one table row per event with its source line.
- TN-01's grammar is honoured exactly — `<epoch> <satellite> <key>
  <count> <count values> <free text>` — so a `QSA` row yields its five
  numbers and a `MANV` manoeuvre row its four. All 3 402 lines of the
  published list parse under it, measured. A line commented out with a
  leading `x` is **kept and flagged**, not dropped: dropping it would
  lose the record that the value was once there.
- TN-01a entries are grouped under their date, with wrapped
  continuation lines joined to the entry they belong to.
- **It reads; it does not interpret.** No manoeuvre window is
  extracted from a sentence like "performed a calibration maneuver
  from 06:19:26 to 06:21:33 (2.0 cm/sec)". CONCEPT is explicit that
  nothing is inferred that a list states, and turning these rows into
  mask layers is X-05's business. `dayOnly` marks the TN-01a rows
  whose time is a date and not an instant, and `timeSystem` is
  reported as `"date"` for them because the file states no time scale.
- A row that does not match its own declared value count is reported
  by line number in `aux.unparsableLines`, never guessed at.

### Changed — one epoch formula, one classic header parser

- The GPS-epoch arithmetic moved to `internal/gpsSecondsToMjd`, shared
  by the header-driven and the classic binary parsers, and it returns
  the epoch integer so that 51544 is not written out twice either. The
  2026-09-14 entry explains the rule: a formula in two files can
  diverge and shift every epoch of one reader with nothing visible to
  say so.
- `internal/parseClassicHeader` is now the one parser for the classic
  `KEY : VALUE` dialect. Its key pattern had never admitted `=`, so it
  had been silently dropping `FILE FORMAT 0=BINARY 1=ASCII` — the very
  record the binary dispatch turns on — along with two others.

### Still open

- **Classic RL03** is not read. The files supplied are release 02;
  RL03 carries only KBR1B, SCA1B and the transplant, and no RL03 file
  was available. Nothing here claims to read one — the record-length
  self-check is what will say so if its layout differs.
- **Classic MAG1B and AHK1B** are refused; see O-15 above.
- ~~**The classic ASCII variant** is still inferred rather than~~
  *(Superseded: measured and no longer warning — see Unreleased.)*
  The entry as written:
  **The classic ASCII variant** is still inferred rather than
  measured, and still warns.
- One acceptance point, `testRealData/testACH1B`, stays incomplete
  until `ACH1B_2020-01-01_C_04.txt` reaches the pool.

## 1.0.2 — 2026-09-09

### Fixed — MAG1B was unreadable

- `+gracefoReading/+internal/resolveTime.m`, `localFracScale` supported
  second, millisecond and microsecond and refused everything else, so
  **MAG1B** — the only GRACE-C RL04 product declaring `time_frac` in
  nanoseconds — raised `unknownFracUnit` and could not be read at all
  (issue #9). One case added, `s = 1e-9`.
- **The `otherwise` branch is unchanged, deliberately.** A fallback of
  `s = 1` on an unrecognised unit would have put MAG1B epochs out by
  nine orders of magnitude with nothing visible to say so. The refusal
  is what made this a five-minute diagnosis instead of silent
  corruption, and it stays.
- The scale reaches the exact int64 nanosecond path as well as the
  double MJD pair, so it had to be shown not to cost the `'gpsns'`
  exactness guarantee. `int64(round(fracScale*frac*1e9))` was swept
  across the full declared `valid_range` 0..999999999 in IEEE-754
  doubles: **zero mismatches, maximum error 0 ns**. Microsecond,
  millisecond and second were swept as controls and are also exact.
- Three tests: scale and sign (500000000 ns lands half a second after
  the integer tag), `'gpsns'` exactness at both boundary values, and a
  guard on the thing that made this possible — the unit is a property
  of the **file**, not the product family, so identical `time_frac`
  digits must give different epochs through a MAG1B and a MAS1B header.

### Fixed — two public help claims that had become wrong

- `readL1b` described fractional scaling as "microseconds in the real
  THR1B/MAS1B files", and claimed the `"mjd"` double pair represents
  "the L1B time tags (microsecond quantization)" without loss. Both now
  name the nanosecond case. The no-loss claim still holds — 2e-11 s
  resolves a nanosecond tag about fifty times over — and now says why.

### Changed — version

- `1.0.1` → `1.0.2`. PATCH, per `astrobayer/ci-actions/VERSIONING.md`.

### Notes

- `localFracScale` is the only unit-driven scale table in the toolbox,
  so this defect class has no sibling to fix.
- Not implemented, and worth considering separately: the report notes
  that MAG1B's `valid_range: 0, 999999999` confirms the declared unit.
  Cross-checking `valid_range` against the unit would catch a header
  whose unit and range disagree, but it is a new behaviour rather than
  a fix and was left out of a bug-fix release.

## 1.0.1 — 2026-09-08

### Fixed — readL1bMulti crashed where readL1b returned empties

- `+gracefoReading/readL1bMulti.m` indexed the first epoch of the
  concatenated series unconditionally in its cross-file monotonicity
  check — `time(1)` in the `datetime` and `int64` branches, `time(1,1)`
  in the `mjd` branch. `readL1b` returns clean empties when `'TimeRange'`
  or a quality option removes every record, so `vertcat` of K such
  results is empty and all three branches raised a bare
  `MATLAB:badsubscript` from inside the reader (issue #6). An empty
  series is trivially monotonic; the check is now skipped.
- The result is the **same clean empties `readL1b` returns**, not an
  error. Erroring was the other option the issue offered and was
  rejected: `readL1b` returning empties for an out-of-range file is
  deliberate, and two readers disagreeing on one input class would keep
  the single-file/multi-file split in `NonGravForces`
  `io/private/l1bLoad` (O-12) alive permanently.
- Returning nothing silently would hide a wrong `'TimeRange'` or a wrong
  file list, so the outcome is reported under a new documented
  identifier, **`gracefoReading:readL1bMulti:noRecordsInRange`**.
  Callers that require data test `isempty(time)` or promote the warning
  with `warning('error', id)`. Every number in the message is read back
  from the run (parsed counts from `numRecordsActual`, the options
  actually set, the class and shape actually returned).
- Swept for the same pattern: `findGaps.localToMjdPair` is fully
  vectorised and already carried `|| isempty(time)`; `decodeQualFlags`,
  `checkQuaternionNorm` and `writeGroopsInstrument` never index element
  1. `readL1bMulti` was the only offender. The mixed case — some files
  emptied, some not — already worked and is now covered by a test.
- Six tests added to `tests/testUtilities.m`, including a metamorphic
  `readL1b` vs `readL1bMulti` equality check on the exact divergence
  reported, and the single-surviving-record boundary where `diff()` is
  empty.

### Fixed — an EXAMPLE that could not run

- `+gracefoReading/version.m` example 2 asserted `v >= 2.3`. The
  renumbering from 2.3.0 to 1.0.0 in the previous release left it
  impossible to satisfy. A runnable EXAMPLE section exists to expose
  exactly this, and did.

### Changed — version

- `1.0.0` → `1.0.1`. PATCH, per
  `astrobayer/ci-actions/VERSIONING.md`: PATCH rises for fixes, and is
  not a revision counter. Provenance stamps in all 28 help blocks,
  `Contents.m`, `version.m`, `docsrc/functionSpecs.json`, `README.md`
  and `docs/CI_SETUP.md` move together; `Updated:` dates move only in
  the files whose content changed.

### Known deviations from VERSIONING.md (not addressed here)

- `version.m` hardcodes the version literal. The organisation scheme
  says `version.m` reads `Contents.m` at runtime and never hardcodes.
  This repository instead keeps three literals (`version.m`,
  `Contents.m`, `docsrc/functionSpecs.json`) reconciled by
  `testDocConsistency` and `auditHelp` rather than deriving them from
  one source. Fixing that is a change to the version machinery and does
  not belong in a bug-fix pull request.
- No annotated tag exists. `v1.0.0` was tagged and released on
  2026-09-06, but the tag is *lightweight*, where VERSIONING.md requires
  an annotated tag plus a GitHub release per version.

  **Correction, 2026-09-08.** This bullet first read "No annotated tag or
  GitHub release exists for any version." That was false and was written
  without checking the remote; the `v1.0.0` tag and its release both
  existed at the time. Rewritten rather than deleted, because a record
  that quietly loses a wrong claim teaches nothing. Tracked as O-4 in
  `HANDOVER.md`.

## 1.0.0 — 2026-09-06

### Changed — version scheme

- **Renumbered from 2.3.0 to 1.0.0.** The toolbox carries no tag and no
  release, so nothing published is rewritten by moving it. The number it
  had said nothing: 2.3.0 was reached without a rollout, and the scheme
  differed from every sibling repository's.
- `1.0.0` under the scheme in `astrobayer/ci-actions/VERSIONING.md` means
  the documented interface is treated as stable from here: breaking it
  requires a MAJOR bump. It is not a claim of completeness.
- The `## 2.3.0` heading below is left as it stands. It describes what
  was done then, and rewriting it would make the record say something
  that never happened.
- `NonGravForces` declares a minimum of `gracefoReading 2.1` in
  `dependencyReport.m`; that minimum moves to `1.0` in the same round.


### Fixed — the toolbox could not be loaded at all
- `+gracefoReading/+internal/parseDataSection.m` and
  `parseClassicProduct.m` carried their help block **between the two
  physical lines of the function declaration**. MATLAB rejected both
  files with `MATLAB:m_unbalanced_parens`, so for the interpreter they
  did not exist and everything reaching `parseYamlProduct` errored.
  Measured on the self-hosted runner, before and after:

      before   15 passed, 33 failed, 34 incomplete
      after    43 passed,  5 failed,  7 incomplete

  Both files also carried a second, stale help block left over from the
  same insertion; it has been removed. The surviving block is the
  documented one and passes `docsrc/auditHelp.py` unchanged.

### Fixed — the cause, not just the symptom
- `docsrc/_sethelp.py` wrote the help block at line 2 unconditionally.
  `docsrc/auditHelp.py`, `docsrc/helpparse.py` and
  `tests/testDocConsistency.m` read it back with the same rule. Writer
  and auditor shared one assumption, so the audit certified files that
  MATLAB could not parse. All four now obtain the boundaries from
  **`docsrc/mfile.py`**, the single point of access for the structure of
  a MATLAB source file (`declaration_end`, `help_span`,
  `comment_inside_decl`).

### Added — checks that do not share that assumption
- `docsrc/sourceIntegrity.py`: static gate. Split declarations,
  duplicate help blocks, missing help. No MATLAB, no licence, under a
  second — it fails the pull request on `ubuntu-latest` before the
  single self-hosted runner is occupied. Verified against the
  unrepaired tree: 4 findings; against the repaired tree: 0.
- `tests/testSourceIntegrity.m`: asserts a property MATLAB defines —
  every file parses under `checkcode` — plus one help block per file and
  a reachable, correctly named H1. Its continuation rule is pinned to
  the Python one by a shared set of test vectors.
- `.github/workflows/ci.yml`: the gate runs first in the `documentation`
  job. Artifact name no longer interpolates `matrix.os`/`matrix.release`,
  which ceased to exist when the matrix was collapsed.

### Known, not addressed here
  Nine test points still fail for reasons unrelated to the parse defect;
  they were masked by it and are visible for the first time. See the pull
  request description for the measured list.

## 2.3.0 — 2026-08-14

### Added — CI and build
- `ci/runCI.m`: single CI entry point (all suites, JUnit XML + Cobertura
  coverage into `artifacts/`, `'Exit'` for correct batch exit status).
  Same command locally, on GitHub-hosted and on self-hosted runners.
- `docs/CI_SETUP.md`: setup guide — GitHub-hosted vs self-hosted runners,
  licence handling (`MLM_LICENSE_FILE`, batch tokens), GitLab/Jenkins
  snippets, troubleshooting table, pre-flight checklist.
- `.github/workflows/ci.yml` rewritten: matrix Linux/Windows on R2024b
  plus R2020b (documented minimum), artifact upload, weekly schedule,
  separate documentation job (help audit + docs-in-sync).
- `buildfile.m`: new `audit` and `guide` tasks; `test` now runs through
  `runCI`; `release` depends on audit + test + docs + check.

### Added — documentation
- **Help blocks are now the single source of truth.** `docsrc/helpparse.py`
  parses them; `docsrc/generate_html.py` and `docsrc/generate_guide.py`
  render HTML and PDF from that parse, so in-product `help` and the
  generated documentation cannot diverge.
- `docsrc/auditHelp.py`: enforces the documentation standard — SYNTAX,
  DESCRIPTION, INPUT, OUTPUT (name, type, size, description, options,
  default), ACCURACY AND LIMITATIONS, EXAMPLES, authorship and dates.
- `doc/gracefoReading_Guide.pdf` (27 pages): overview and data
  background, installation, build/test/CI, eight step-by-step guides,
  worked examples, full API reference, accuracy and known issues,
  version history. Replaces the former UserManual PDF.
- `html/gracefoReading_getting_started.html` added to the doc browser TOC.
- Four new consistency tests in `testDocConsistency`: help-standard
  sections, metadata/authorship, documented defaults for every
  name-value option, generated-page sections.

### Changed
- Every `.m` file audited and rewritten to the standard: explicit type,
  size, options and defaults for all arguments; accuracy and limitation
  statements; runnable examples; authorship line "Developed by Matthias
  Weigelt with the help of Anthropic Claude Opus 5, 2026-08-14".
- `decodeQualFlags` help now documents the `notBitString` error.
- Documentation generation refuses to run when the audit fails.

## 2.2.0 — 2026-08-01

### Added — pipeline integration
- `'TimeFormat','gpsns'`: int64 GPS-nanosecond time output via exact
  integer arithmetic (no double round-trip) for lossless handoff to
  int64-nanosecond pipelines. Also in `readL1bMulti`.
- `gracefoReading.findGaps`: gap/segment analysis for all three time
  formats, with nominal-rate auto-estimation.
- `'QualityBitMask'`: selective quality filtering on listed qualflg
  bits (mutually exclusive with `'ApplyQualityFlags'`).

### Added — batch capability
- `gracefoReading.findL1bFiles`: archive search by product / date range /
  satellite / release, chronological sorting, missing-day report.
- `'CacheDir'`: content-hashed (SHA-256) `.mat` parse caching; the key
  covers file content, toolbox version and parse-relevant options, so
  cache entries double as provenance. Post-parse options (TimeRange,
  TimeFormat, quality) are applied after loading.
- `readL1bMulti` warns on non-monotonic concatenated time
  (`timeNotMonotonic`: wrong file order, duplicate days).

### Added — strategic
- **Classic GRACE (2002-2017) support, EXPERIMENTAL**: files with
  "KEY : VALUE" headers ("END OF HEADER") are auto-detected; built-in
  column layouts for ACC1B/SCA1B/KBR1B/GNV1B (assumed from the GRACE
  L1B handbook, NOT yet validated against real classic files — every
  read warns `classicExperimental`), `'ColumnNames'` override for other
  products. Classic parsing reuses the full validated GRACE-FO engine
  (`internal.parseDataSection`).
- `gracefoReading.readGroopsInstrument`: reader counterpart to the
  GROOPS writer; enables roundtrip verification against files from a
  real GROOPS installation (HANDOVER open topic).

### Added — engineering
- `buildfile.m` (buildtool, R2022b+): `test`, `docs`, `check`,
  `release` tasks — the scripted release procedure.
- GitHub Actions CI (`.github/workflows/ci.yml`): MATLAB suites on
  Linux **and** Windows (both post-release bugs were platform-
  specific), plus docs-in-sync check.
- `examples/demoGracefoReading.m`: executable tour using the bundled
  real MAS1B/THR1B files.

### Changed (internal)
- `readL1b` refactored into parse core + post-processing
  (`internal.parseYamlProduct` / `parseClassicProduct` /
  `parseDataSection` / `resolveTime` / `filterAuxRecords` /
  `contentHash`); public behavior unchanged apart from the additions.
- `aux` gains `headerFormat` and `cacheHit`.

## 2.1.1 — 2026-08-01

### Fixed (Windows)
- `writeGroopsInstrument` opened its output with `'wt'`; on Windows this
  translated LF to CRLF, and the roundtrip test failed with two
  visually identical strings (the trailing `\r` is invisible in test
  diagnostics). The writer now opens with `'w'` and guarantees LF-only
  output on **all** platforms — byte-identical, checksum-stable exports,
  and no CRLF surprises for GROOPS on Linux.
- The roundtrip tests parse with `splitlines` (line-ending agnostic)
  and additionally assert the absence of CR in the export, so a
  regression to platform-dependent endings is caught on Windows.
- Note: the synthetic reader-test helpers intentionally keep `'wt'` —
  on Windows they produce CRLF input files, and the green reader suite
  there confirms the parser's CRLF tolerance with real evidence.

## 2.1.0 — 2026-08-01

### Changed (layout / installation)
- `setup.m` renamed to **`setupGraceFOReading.m`** (unambiguous name on
  a shared path); it no longer adds `tests/` to the path — run suites
  via `runtests(fullfile(toolboxRoot, 'tests'))`.
- `code/` folder removed: `+gracefoReading/`, `html/` and `info.xml`
  now live directly in the toolbox root. Update any hardcoded
  `addpath(.../code)` calls to the toolbox root.
- Test suites adjusted to the new layout; they now leave the path
  untouched if the toolbox root is already on it (a test run no longer
  strips a path configured via setupGraceFOReading).
- Documentation generator, README and HTML product page updated to the
  new structure. No changes to the reading/parsing code.

## 2.0.2 — 2026-08-01

### Fixed
- `testUtilities/testVersion` pinned the version literal `'2.0.0'` and
  broke on the 2.0.1 bump — a self-inflicted double-bookkeeping site.
  The test now verifies structure only (semver format, info-struct
  self-consistency); cross-artifact version pinning remains the job of
  `testDocConsistency` (version.m <-> Contents.m <-> HTML product page).

### Release process
- Rule going forward: no version literals anywhere except version.m,
  Contents.m, functionSpecs.json and CHANGELOG.md, all updated by the
  scripted bump and cross-checked by testDocConsistency.

## 2.0.1 — 2026-08-01

### Fixed
- **Gzip reading**: the in-memory Java decompression path silently
  produced zero-filled text. Root cause: MATLAB auto-converts Java
  primitive arrays and passes them **by value**, so the
  `GZIPInputStream.read(byte[], ...)` out-parameter filled a Java-side
  copy while MATLAB kept its zeros. Replaced the buffer loop with
  `org.apache.commons.io.IOUtils.toByteArray` (whole read inside Java,
  no out-parameters); `gunzip` temp-file fallback unchanged.
  Found by `testReadL1b/testGzipMatchesPlain` — the remaining 
  suites passed on first run (thanks for the verbatim log).

## 2.0.0 — 2026-08-01

Major rewrite after validation against real PO.DAAC RL04 files
(2020-01-01: ACT1B, GNV1B, SCA1B, THR1B, KBR1B, LRI1B, MAS1B).

### Breaking changes
- **Namespace**: all functions now live in the `+gracefoReading` package.
  `readGraceFoL1b`      → `gracefoReading.readL1b`
  `readGraceFoL1bMulti` → `gracefoReading.readL1bMulti`
- Error identifiers renamed accordingly
  (`graceReading:readGraceFoL1b:*` → `gracefoReading:readL1b:*`).
- Toolbox/zip name changed from `graceReading` to `gracefoReading`.

### Fixed (real-data findings — v1.0.0 failed on ALL real RL04 files)
- Header parsing now supports the **real** RL04 declaration style
  (`variables:` with `- varname:` mapping entries). v1 only understood
  an invented `variable_descriptions:` / `- name: x` layout, which no
  real file uses. The legacy style remains supported.
- Split time tags: `time_frac` is now scaled by its **declared unit**.
  Real THR1B/MAS1B files use microseconds; v1 would have summed
  seconds + microseconds directly (6 orders of magnitude error).
- `qualflg`/`prod_flag` bit strings ("00000000") are preserved as
  char + decoded logical bit matrices instead of collapsing to
  numeric 0 via str2double.
- `qual_rss` (SCA1B) is now correctly an observation column; the v1
  classification regex (`flag|qual`) would have demoted it to aux.
- `*_id` columns (e.g. numeric `sca_id`) are auxiliary, not observations.

### Added
- **prod_flag variable-length records** (MAS1B): per-record presence
  decoding, absent values as NaN, prod_flag-aware row-integrity check.
- `'TimeRange'` (decimal-MJD or datetime window) and
  `'TimeFormat'` (`"mjd"`/`"datetime"`) options.
- `'ApplyQualityFlags'` option: drop records with any qualflg bit set.
- `gracefoReading.decodeQualFlags`: bit meanings decoded from the
  file's **own header** (`flag_meanings`), no hard-coded bit tables.
- `gracefoReading.checkQuaternionNorm`: SCA1B unit-norm sanity check
  (rotations intentionally out of scope — separate toolbox).
- `gracefoReading.writeGroopsInstrument`: GROOPS ASCII instrument export.
- `gracefoReading.version`: programmatic version checks.
- Real-data acceptance suite `tests/testRealData.m` (auto-skips absent
  files) with expected values cross-derived by a Python reference
  implementation (`tests/python_reference/validate_realdata.py`).
- Single-source documentation: HTML pages and the PDF manual are both
  generated from `docsrc/functionSpecs.json`; `tests/testDocConsistency.m`
  checks the pages against error ids actually raised in the source.
- In-memory gzip decompression (Java stream) with gunzip fallback.
- `CHANGELOG.md` (this file).

### Distribution
- Distributed as zip / git; no `.mltbx` (deliberate, see HANDOVER.md).

## 1.0.0 — 2026-07-21
- Initial release: generic header-driven reader `readGraceFoL1b`,
  multi-file wrapper, unit tests, HTML + PDF documentation.
  Validated against synthetic files only.
