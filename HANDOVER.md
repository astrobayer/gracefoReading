# HANDOVER — gracefoReading

**Revision 4.4 · 2026-09-27 · toolbox v1.1.0 → 1.2.0 in progress (#29, branch `claude/grace-timeseries-issues-28g3a4`)**

The single point of truth for this repository. Where this document and a
general engineering habit disagree, this document is right. Read it
before any code, and do not start from memory of a previous session.

`README.md` is the user-facing description (what the toolbox does, how to
install it). This file is the developer record: status, decisions,
obligations, and what a next session would be wrong for not reading.
The design of the preprocessing pipeline built on this reader lives in
`astrobayer/timeSeriesPreparation`: `docs/CONCEPT.md` (decisions in its
section 11) and `docs/GUIDE.md` (order of work and procedures). This toolbox
gains no preprocessing code from it. Facts live in one place, never in two.

---

## A. Status — measured, not asserted

| | |
|---|---|
| Version | 1.1.0 (`gracefoReading.version()`; `Contents.m` and `docsrc/functionSpecs.json` must agree) |
| Tests | **153 passed, 0 failed, 1 incomplete = 154 total** — CI run 35742860944, head `5e74b09`, self-hosted Windows runner, MATLAB R2026a, 2026-09-22, 216.2 s. GREEN, prediction matched on all three numbers. `testClassicProducts` is **22**: the classic ASCII variant is verified against its binary twin, including the MAG1B column swap and AHK1B's bit-string `status`. *Previously:* 149 + 0 + 1 = 150 — CI run 35719247713, head `df0b0ec`, self-hosted Windows runner, MATLAB R2026a, 2026-09-22, 204.8 s. GREEN, and the prediction matched on all three numbers on the first run with real code changes since `2d6f226`. `testClassicProducts` is **18** rows: both AHK1B acceptance points pass, so the 32-bit `prod_flag`, the five-type conditional walk and the two unsigned corrections are all verified on the runner. *Previously:* 147 + 0 + 1 = 148 — CI run 35707792415, head `2d6f226`, self-hosted Windows runner, MATLAB R2026a, 2026-09-22, 205.5 s. GREEN, and the prediction matched on all three numbers. `testClassicProducts` is 16 rows with both MAG1B acceptance points passing, so the handbook naming is verified on real bytes. `testRealData/testACH1B` passes in 7.96 s, which is the full-day file from the pool and not the 120-record extract. The run before it, 35707090459 (`885bdb0`), was RED on that one row — see the finding below. Earlier: 144 + 0 + 2 = 146 on run 35704249941 (`8ff0ee0`), and the v1.1.0 release 142 + 0 + 2 = 144 on run 35702315239 (`3c2bf28`, merged as `2c0d7d8`) |
| Static gates | `docsrc/sourceIntegrity.py` 50 files / 0 findings · `docsrc/auditHelp.py` 50 help blocks clean · `python3 docsrc/generate_docs.py` then `git diff --exit-code -- html/` clean, and byte-identical on a second run — all four run 2026-09-22 in a sandbox without MATLAB |
| Public units | 15 in `+gracefoReading/`, 19 internal in `+gracefoReading/+internal/` |
| Tag / release | **`v1.1.0` is tagged ANNOTATED on the merge commit `2c0d7d8` and released, 2026-09-22 08:13Z** — the first release to meet VERSIONING.md in full. `v1.0.1` is annotated; `v1.0.0` and `v1.0.2` are lightweight and stay so, tags being immutable. O-4 is discharged forward |

Per-class test counts, for the prediction a next session must make
*before* running: `testReadL1b` **30**, `testUtilities` 16,
`testBatchTools` 15, `testItsgProducts` 15, `testRealData` 11,
`testItsgBatch` 12, `testDataPool` **10** (new, G-06),
`testClassicProducts` **22** (12 at v1.1.0, +2 RL03, +2 MAG1B,
+2 AHK1B, +4 classic ASCII), `testEventLists` **11** (new, G-05),
`testDocConsistency` 7, `testSourceIntegrity` 5. Sum **154**, of which
153 pass and **1** is the documented incomplete below — `testRealData/testACH1B` stopped
being incomplete when its fixture was bundled, so the count of
incompletes went down while the total went up. Predicting the total
alone would have hidden that.
The previous measured total is 121. A run reporting anything else is a
finding, not a rounding.

**The ACH1B finding, run 35707090459 — a hazard this session wrote
down and then walked into.** *(Fixed in `2d6f226`; run 35707792415 is
green. Kept because the reason a run goes red is worth more than the
run.)* `testACH1B` was written asserting the
bundled 120-record extract. The fixture lookup is **pool first,
bundled second**, and the owner's pool holds the FULL published day
under the same name, so the row read 86 400 records and failed on
exactly the four length-dependent lines (`numRecordsHeader`, the size
of `t`, the last epoch, the zero angular columns). Nothing was wrong
with the reader or with either file — every value-level assertion
passed on the full day, including the nine observation columns, the
satellite identifier and the first record's accelerations, which is
itself the strongest confirmation of the fixture.

The same hazard had been written into `tests/realdata/README.md` in
the same push, as a thing to know before putting a full day in the
pool. Documenting a hazard is not preventing it. The row now DERIVES
what depends on the record count — at 1 Hz from midnight with no gap
the last epoch is `n-1`, which is a stronger statement on the full day
than on the extract — and refuses any length that is neither 120 nor
86 400. **`testMAS1B` and `testTHR1B` still hard-code theirs** and
would fail the same way; that is loud rather than silent, and is left
alone deliberately rather than fixed in passing.

**Predict the split, not just the sum.** The 2026-09-14 prediction gave
the per-class sum correctly as 89 and then wrote it as "89 passed and 1
incomplete", which is 90 tests. The measured run is 88 passed + 1
incomplete = 89. Nothing was wrong with the code or the count; the
arithmetic of the *reconciliation* was wrong, and a sum that agrees with
itself hides that. State the prediction as passed + failed + incomplete
= total, and check that the three add up before running.

**What the first CI run of the branch measured, and what the prediction
got wrong.** The first prediction assumed AHK1B and LHK1B were absent
from the pool and would skip. They are **present** — only ACH1B is
missing — so the two new acceptance points ran against real bytes and
did what an acceptance point is for: both found something. The *second*
prediction, made after that was known, matched its run exactly. Kept
here because the reason a prediction misses is worth more than the
prediction:

| finding | evidence | whose defect |
|---|---|---|
| Real **AHK1B is 864 077 records over 36 declared variables, with a 32-character `prod_flag`**, where ACT1B and MAS1B carry eight | `verifySize([864077x32 logical],[864077 8]) failed` | **the test's.** It asserted 8, imported from a sibling product — the one inference `resolveTime`'s rule forbids. The file itself read correctly, so the G-04 reader work is verified on real AHK1B. Fixed by reading the width off the file |
| Real **LHK1B could not be read at all**: `readL1b:columnMismatch`, "Data line 537 has 9 whitespace-separated token(s), expected 8 (from 8 declared variables)" | run 35696829972, then the header itself on run 35697358724 | **the reader's.** A genuine G-04 finding, now fixed — see the rest-of-line rule below |

**The G-03 measurement was lost to an unrelated failure.** Its step read
`if: ${{ vars.READING_DATA_POOL != '' }}`, and a failed suite step skips
a step without `always()`. Corrected; O-7 still waits for the number.

**What the second run read off the real housekeeping files.** A
temporary CI step dumped both headers rather than letting the fix be
written from a guess. It has been removed again; what it measured:

- **LHK1B declares eight columns** — `time_intg`, `time_frac`
  (nanoseconds), `time_ref`, `GRACEFO_id`, `qualflg`, `sensortype`,
  `sensorvalue`, `sensorname` — over **1 169 274 records**, of which
  **1 166 388 carry eight tokens and 2 886 carry nine**. The header
  answers why in its own words:

  ```
      - sensorname:
          comment: Entire remaining portion of each record
          long_name: Sensor name.  Max number of characters = 1,000
  ```

  The nine-token records are `fpga_state: science_state` and
  `mode: science` — a sensor name with a space. Note that `sensorname`
  declares **no `units: char`**, so a rule keyed on character columns
  would not have fired: the licence is the sentence, and only reading
  the file produced it.
- **LHK1B is long format**: one record per sensor per epoch, so its
  first three records share the tag 631108800.872776889. Epochs are
  non-decreasing, **not** strictly increasing, and the shared invariant
  helper said "strictly" — a third defect, found by reading the dumped
  records rather than by another red run.
- **AHK1B declares 36 variables**, among them `TSU_Y+`, `TICUN`,
  `TSU_Y-`, `TSU_Z+`, **`TSU Z-`** (with the space), `+3.3V`, `+5V`,
  `+15V`, `-15V`, `+48V`, `-48V`. That is the real-file evidence for
  both halves of the G-04 change at once: the old header pattern would
  have dropped `TSU Z-`, and `makeValidName` collapses **three** pairs
  in this one file — `TSU_Y+`/`TSU_Y-`, `+15V`/`-15V` and
  `+48V`/`-48V`. Six of its 32 prod_flag bits are set all day
  (TFEEU_REF, Vp, icu_blk_nr, PPS_source, Sync_Qual, statusflag),
  giving twelve tokens per record.
- **The pool answers every file through the LEGACY path.** Run
  35698502947 reports `9 of 11 found; 9 via the legacy path`, and
  prints the fixture folder it tried first as
  `…\RawData\tests\realdata\RawData\tests\realdata` — the doubled
  path that the repository-level variable, still pointing at the
  fixture folder, necessarily produces. G-07's fallback is carrying
  every real-data acceptance point on this runner. **Deleting the
  repository variable is therefore a real change, not a formality**:
  the next run must report the same nine files with `0 via the legacy
  path`, and only then may the fallback be dropped.

**The one failure of run 35701780423 was the test's, and it taught
something about the product** (fixed in `3c2bf28`; the next run was
green).** `sca_id` is the star-camera HEAD
identifier and it is **not constant**: 31 of the fixture's 40 records
come from head 4 and 9 from head 1, and the full day uses heads 1, 2
and 4 (12 248 / 6 / 4 564 records). The row asserted a constant taken
from record 1.

The replacement is stronger than a corrected constant. `sca_id` sits at
byte 6 of the record and `qualflg` at byte 47, decoded independently of
each other, yet **"head 1" and qualflg bit 3 select exactly the same
records** — all 40 in the fixture, and 16 812 of the full day's 16 818,
the six exceptions being precisely the head-2 records. A wrong offset
on either field would destroy that correspondence, so the two columns
now cross-check each other instead of being asserted apart.

**Release 03 reads under the same layouts, measured 2026-09-22.** The
v1.1.0 record said classic RL03 was not read, release 02 being what had
been supplied. Two RL03 files then arrived, and RL03 publishes only two
products anyway (plus the ACT1B transplant archive, still not supplied):

- **SCA1B RL03**, 2008-01-20: 47 bytes per record as in RL02, and the
  quaternion norm holds to **9.6e-11** over all 86 398 records.
- **KBR1B RL03**, 2008-01-01 — the *same day* as the bundled RL02 file.
  Decoded with the one layout, the two independently produced files are
  **bit-identical** in `biased_range`, `range_rate`, `range_accl`,
  `iono_corr` and all four SNRs, and differ only in the reprocessed
  `ant_centr_corr` (1.7 micrometre) and in `qualflg`. A wrong offset
  could not produce that pattern; this pair is the strongest single
  piece of evidence for the KBR1B layout.

Two differences are the product's, not the layout's: RL03 SCA1B samples
at 1 Hz where the RL02 file samples at 5 s, and its `sca_id` uses head
codes 1, 4, 5, 6, 7 and 8 against RL02's 1, 2 and 4.

**And a correction to scope, not to fact.** The `sca_id` <-> `qualflg`
bit 3 correspondence recorded below holds on the RL02 file and its full
day, as stated. It does **not** generalise: on the RL03 day it holds in
57 % of records. Nothing written earlier claimed otherwise - it was
always scoped to that file - but a future session could easily read it
as a law of the product, so the limit is now written down beside it.

**O-7 is measured, and decided.** CI run 35698502947 on the runner,
`ACT1B_2020-01-01_C_04.txt`, 14 159 480 B, 86 400 records in 9
observation columns, 3 repeats, MATLAB R2026a on PCWIN64:

| quantity | measured |
|---|---|
| `readL1b`, minimum | **7.801 s** |
| `readL1b`, median | 7.874 s |
| `fileread` alone, minimum | **0.059 s — 0.8 % of the total** |
| throughput | 11 076 records/s, 1.73 MB/s |
| extrapolated year (365 x the minimum) | **2 847 s = 47.5 min** |

Measured three times on three runs of this branch, since the step runs
under `always()`: **7.801 s, 7.744 s and 7.525 s** per day, with the
`fileread` share 0.8 % each time and the year between 45.8 and
47.5 min. A 3.5 % spread on a shared runner is what one would expect,
and the decision below does not turn on it - three independent
measurements agreeing this closely are worth more than any one of them.

**The decision: no fixed-layout fast path, and the reason is not the
headroom.** The headroom is real — parsing is 99.2 % of the cost, so a
typed `textscan` path could in principle win back almost all of it. It
is not built because:

1. 47.5 minutes for a year of one 1 Hz product is below the threshold
   where it blocks anything, and `'CacheDir'` already turns every
   re-read into a load, so that cost is paid once per file.
2. It would be a **second parsing path for a subset of products**. The
   reader now handles three distinct record grammars — fixed columns,
   `prod_flag` variable columns (MAS1B, AHK1B) and the rest-of-line
   column (LHK1B) — and only the first could use it. One fact in two
   places is the failure mode this repository has been bitten by twice
   (the help-block boundaries on 2026-09-06, the datetime epoch on
   2026-09-14), and a divergence between two parsers would move epochs
   with nothing visible to say so.

**Re-entry:** if a campaign run of timeSeriesPreparation X-15 measures
parse time as its dominant cost, re-open with that measurement beside
this one. `ci/benchmarkParse` stays, so the comparison is one command.

**Two incompletes are expected and are not a regression.** Each has a
named cause and a one-file fix, and each becomes a pass the moment the
file is in the pool. Everywhere else in this file "incomplete is a
finding" still holds.

| point | waits for | since |
|---|---|---|
| `testItsgProducts/testFullDayKinematicJitter` | `GRACEFO-1_kinematicOrbit_2020-01-01.txt` (~2.2 MB, or its `.gz`). It asserts the receiver-clock variation of the kinematic products, which first occurs well past record 60 and so cannot be seen in the bundled fixture | 2026-09-14 |
| `testRealData/testACH1B` | `ACH1B_2020-01-01_C_04.txt`, from the `.ACX` daily archive | 2026-09-22, G-04 |

`testRealData/testAHK1B` and `testRealData/testLHK1B` were predicted to
join this table and did not: the pool holds both (126 MB and 63 MB).
They run, and each carries golden numbers measured on 2026-09-22.

The CI step "Report which real-data files the pool provides" now names
all four, so a wrong pool layout and a genuinely absent file are
distinguishable from the log rather than from the skip count.

**These counts were wrong until 2026-09-14, and the error was only
caught by making the prediction.** This table said `testReadL1b` 22 and
a total of 65. The real figures before the 2026-09-14 change were 25 and
**68**: the three MAG1B tests added for issue #9 in v1.0.2 went into
`testReadL1b` and the table was never updated, so the 1.0.2 bump shipped
with a stale status line. A prediction of 71 was made from it and missed
by exactly those three. Predict before running, and reconcile per class
rather than on the total — a total that is wrong by the same amount in
both places still agrees with itself. `0 incomplete` means the
real-data pool resolved and no acceptance point filtered itself out; a
skipped fixture counts as incomplete and is a finding, not noise.

**A correction to the record.** The `## 1.0.1` CHANGELOG entry states
that no annotated tag or GitHub release exists for any version. That is
false and was written without checking: `v1.0.0` was tagged and released
on 2026-09-06. What is true, and is what O-4 now carries, is that the
tag is *lightweight* where `astrobayer/ci-actions/VERSIONING.md` requires
an annotated one, and that 1.0.1 has neither tag nor release.

---

## A3. Scope frozen — branch `claude/grace-timeseries-issues-28g3a4` (#29, release 1.2.0)

**Frozen 2026-09-27, tier B** (no MATLAB in the sandbox; the DATAPOOL
only on the runner). Issue #29 was filed from timeSeriesPreparation X-12
(its scan PR #66 and verification PR #67), which read the GRACE-FO L1B
RL04 files of 2020-01-02 with v1.1.0. Owner decisions of 2026-09-27:
warn **and** offer `DropZeroTime`; this PR **releases 1.2.0**, which is
what timeSeriesPreparation's X-13 waits for (its GUIDE: "G-02
(gracefoReading `v1.2.0`) → X-13"). G-02 is merged since PR #28 and
unreleased.

| part of #29 | what this branch delivers |
|---|---|
| 1 — CLK1B refused (`readL1b:noTime`) | `resolveTime` detects a single `rcv_time` column after `gps_time` and before the split pairs. CLK1B's header declares it as "Seconds past 12:00:00 noon of January 1, 2000 in Receiver Time", units seconds; it is returned as written (receiver time; GPS = rcv_time + eps_time is the caller's step). `aux.timeSystem` keeps reading 'GPS' for every YAML product, the receiver-time tags included - it names the counting convention; `aux.timeVariable` distinguishes them. Recorded, not changed |
| 2 — TIM1B_D records with time 0 | `readL1b` counts records whose tag is exactly 0 in `aux.numRecordsZeroTime` and raises `readL1b:zeroTime` (count, first record, what was done). `'DropZeroTime'` (default false) removes them; `readL1bMulti` forwards it and returns the per-file counts |
| 3 — CLK1B_D eps_time ≈ 0 | information only, and **not a defect** (scan of PR #31): records 6321..6329 of 8 671 are the clock offset passing through zero, −1.9e-7 … −9.6e-7 s at a steady drift of −9.6e-9 s/s with qualflg 0; the day's eps_time runs from −0.01117 to +1.8e-6 s. No reader change. The TIM1B_D zero-time records, by contrast, ARE flagged by the product: qualflg `10001000`, bit 3 "Receiver Time mapping not defined" |

**Fixtures from real bytes.** Two trimmed extracts are bundled, taken
byte-exact from the runner's DATAPOOL
(`GRACEFO\L1B\RL04\2020\2020-01-02\`) by a scan printed as base64 in
the CI log, with only `num_records` changed to the extract's count (the
ITSG fixtures' rule): `CLK1B_2020-01-02_C_04.txt` (header + first 60
records) and `TIM1B_2020-01-02_D_04.txt` (header + 60 records around its
first zero-time records). The first scan PR (#30) was meant to be closed
unmerged and **was merged**; its `READING_DATA_POOL` in this repository is
the legacy fixture folder, so it found nothing. This branch re-runs the
corrected scan as its first code commit and **removes**
`.github/workflows/scan.yml` and `tools/scan29.m` again, in their own
commit.

**Existing tests touched, and why.** A tag of 0 now warns by design. Four
warning-free assertions used a synthetic first record at tag 0
(`testBatchTools/testMultiMonotonicWarning`,
`testReadL1b/testVariableNameAdjustedStaysSilentOnCleanHeaders`,
`testUtilities/testMultiPartiallyEmptyRangeConcatenates`,
`testUtilities/testMultiSingleSurvivingRecordIsMonotonic`); their first
tag moves to 1 or 10 s. No asserted value depends on it.

**Release 1.2.0** in its own commit (`chore: version 1.1.0 -> 1.2.0`):
`Contents.m`, `version.m`, `docsrc/functionSpecs.json`, README and every
`Toolbox:` stamp; `Updated:` moves only where content changed (D).

**The legacy fixture path stays in 1.2.0.** G item 8 lets it go only
after a green run reports `0 via the legacy path`. The scan of this
branch measured the opposite: this repository's `READING_DATA_POOL` is
still `<ROOT>\RawData\tests\realdata`. Dropping the fallback is left
for the release after the variable changes.

**Prediction** (before any run), per class: `testReadL1b` 30 → **32**
(`testRcvTimeSingleColumnIsDetected`, `testZeroTimeWarnsCountsAndDrops`),
`testBatchTools` 15 → **16** (`testMultiForwardsDropZeroTime`),
`testRealData` 11 → **13** (`testCLK1B`, `testTIM1BZeroTime`), all others
unchanged. **158 passed + 0 failed + 1 incomplete = 159.**

---

## A2. Scope frozen — branch `claude/graceforreading-open-issues-88b9na`

**Frozen 2026-09-22, tier B** (no MATLAB and no DATAPOOL in the working
sandbox; the MATLAB suite runs in CI on the self-hosted Windows runner).
One PR carrying one commit per WP row, per GUIDE section 1.

**What is true after this branch**

| WP | issue | what this branch delivers |
|---|---|---|
| G-01 | #16 | `readL1bMulti` accepts a `[K x 1]` column, so the two-line `findL1bFiles` → `readL1bMulti` workflow printed in both help blocks runs. O-11 closes |
| G-03 | #18 | a measurement, not a guess: `ci/benchmarkParse.m` times one real ACT1B day and extrapolates the year; a non-blocking CI step runs it on the runner, where the file is. The fast-path decision is recorded from the number the run prints, not before it |
| G-04 | #19 | the reader gap V-13 names is closed: header variable names that are not MATLAB identifiers (`TSU Z-`, with a space) are parsed instead of dropped. The generic `prod_flag` path already covers AHK1B's variable columns and is now tested on an AHK1B-shaped fixture. `testRealData` carries ACH1B / AHK1B / LHK1B rows that skip until the files are in the pool |
| G-06 | #21 | `gracefoReading.verifyDataPool` verifies a pool against the checksum manifests its sources publish (the ISDC MD5 lists, the SHA-256 manifests written beside the data), reporting per file OK / MISMATCH / MISSING / UNLISTED with the manifest that made each claim |
| G-07 | #23 | `READING_DATA_POOL` is read as the DATAPOOL **root**: fixtures resolve as `<ROOT>\RawData\tests\realdata\<name>`, falling back to `<ROOT>\<name>` for one release so both values of the variable work. Help text, README and the CI reporting step say the same thing |

**Scope widened 2026-09-22, mid-branch, and why.** The freeze above put
G-02 (#17) and G-05 (#20) out of scope because the bytes they need
could not be reached — recorded as O-14. **The owner then supplied
them**: sixteen files, the classic RL02 products of 2008-01-01 for
GRACE A and B and both official event lists. O-14's discharge
condition was met exactly as it was written, so the two work packages
came into scope rather than waiting for a second PR. What that adds is
in the WP table below; the frozen rows above are unchanged, and the
green run they were measured on (35698502947) still stands as their
verdict.

| WP | issue | what the widening delivers |
|---|---|---|
| G-02 | #17 | classic GRACE read from **measured** layouts, not from a remembered handbook. O-1 closes |
| G-05 | #20 | `gracefoReading.readEventList` for TN-01 and TN-01a, reading without interpreting |

**Out of scope on this branch**

- ~~G-02 and G-05~~ — **superseded, see the widening above.** The
  original reason stands as a record: the sandbox's network policy
  denies `isdc-data.gfz.de` (measured 2026-09-22, `403 CONNECT`, for
  both the RL03 tree and `DOCUMENTS/TECHNICAL_NOTES/`), so the files
  could not be fetched. They were supplied directly instead.
- **Classic RL03 is still out of scope.** The files supplied are
  release 02. RL03 carries only KBR1B and SCA1B plus the transplant,
  and no RL03 file was available, so nothing here claims to read one —
  the record-length self-check is what will say so if its layout
  differs.
- ~~**Classic MAG1B and AHK1B are not read.**~~ **Half superseded
  2026-09-22**, after the owner supplied the GRACE Level-1B Data
  Product User Handbook v1.3 (JPL D-22027). **MAG1B is read**, named
  from its section 6.8. **AHK1B is still refused**, and the handbook
  is why it stays refused rather than why it might not: chapter 6 has
  no AHK1B entry at all. See O-15.
- No preprocessing code (CONCEPT, 2026-09-18).
- No whitespace sweep of the two over-length lines in `readL1bMulti.m`
  (section D): a sweep is its own change and this branch edits that file
  for G-01.
- **Deviation, recorded:** GUIDE section 1 says workflow changes stand
  alone in their own PR, while the same section allows only one open PR
  per repository. G-07 and G-03 each require a step in
  `.github/workflows/ci.yml`, so the workflow edits ride in this PR in
  **their own commit**, named in the PR body for line-by-line reading.
  Nothing else in the diff touches `.github/`.

---

## B. How to run

```matlab
cd('...\gracefoReading'); setupGraceFOReading
results = runtests('tests'); disp(table(results))
```

`addpath('ci'); runCI('Exit', true)` is the one entry point CI uses; it
writes `artifacts/` and exits non-zero on red so a batch call fails.

Licence-free, needs no MATLAB, runs in about a second — use these before
every push:

```bash
python3 docsrc/sourceIntegrity.py    # files parse, exactly one help block each
python3 docsrc/auditHelp.py          # help blocks meet the standard
python3 docsrc/generate_docs.py      # regenerate html/ and the PDF guide
git diff --exit-code -- html/        # the CI byte-identity check
```

**CI** (`.github/workflows/ci.yml`), two jobs, both required:
`documentation` on ubuntu (the three commands above) and `MATLAB suite`
on the **self-hosted Windows runner**. The five large PO.DAAC products
are not bundled; their location comes from the repository variable
`READING_DATA_POOL`, never from this file. Unset variable: the affected
acceptance points filter themselves out and the count drops.

---

## C. Key format knowledge — from real files, not from a handbook

This section is why v2 exists. **v1 failed on every real RL04 file**: it
parsed an invented header style, and the real one differs. Every rule
below was read off a real file.

- Header: a `variables:` list, entries `- varname:` with indented
  attributes (`units`, `comment`, `long_name`, `flag_meanings`, ...),
  terminated by `# End of YAML header`.
- `time_frac` is in **microseconds** in THR1B/MAS1B → scale 1e-6.
- `qualflg` / `prod_flag` are 8-character bit strings; **bit 0 is
  rightmost**.
- MAS1B has variable-length records: a declared conditional column
  appears in a record iff its `prod_flag` bit is set, in ascending bit
  order left to right.
- `units: char` marks character columns (`GRACEFO_id`, `time_ref`,
  `coord_ref`). `sca_id` is numeric but auxiliary (the `*_id` rule).
  `qual_rss` (SCA1B) is a genuine observation, not a flag.
- Epoch: MJD 51544, GPS seconds counted from **2000-01-01 12:00**, so
  `timeMjd = 51544 + floor((gps + 43200)/86400)`. Any test that
  hardcodes an MJD must derive it from this, not guess it.
- `readL1b` raises `noData` when a file holds no data records at all.
  An empty result from `readL1b` or `readL1bMulti` therefore always
  means a filter removed everything, never that the file was empty.
- **Classic binary record lengths, measured** (RL02 and RL03 alike):
  ACC1B 78, SCA1B 47, GNV1B 103, KBR1B 93, THR1B 179, MAG1B 63 bytes;
  MAS1B and AHK1B variable. AHK1B averages 60.5 bytes over the 2008
  day (8 700 records, 526 350 data bytes) because its `prod_flag`
  alternates between two patterns.
- **`prod_flag` is not one shape.** MAS1B's is **one byte** addressing
  eight columns that are all `double`. AHK1B's is **four bytes**
  addressing 29 columns of five types (7 `double`, 18 `single`,
  `uint8`, `uint16`, `uint8`, `int32`). `parseClassicBinary` takes
  both the flag width and every column type from `classicLayout` and
  never from the first column it sees; a set bit the layout does not
  define raises `classicUndefinedProdFlagBit` rather than guessing a
  width.
- **AHK1B calls its split time tag `rcvtime_intg`/`rcvtime_frac`**,
  not `time_intg`/`time_frac`, because it shares the ACC1A record.
  Same meaning, same microsecond fraction. The time detection accepts
  both spellings.
- **The classic ASCII variant is NOT the binary columns as text.** Two
  products deviate, both measured 2026-09-22 against the JPL read
  software's own `Bin2AsciiLevel1`, neither inferable from the binary
  record, and both silent if got wrong:
  - **MAG1B prints `GRACE_id` before `time_ref`** — the opposite of
    its binary order and of every other classic product.
  - **AHK1B writes `status` as eight bit characters**, so a decimal
    read gives 10 111 111 instead of 191. It is decoded back to a
    number, not exposed as a bit string, because it is conditional and
    only `NaN` can say "absent".
  `classicLayout.asciiNames` and `.asciiBitString` carry both; the
  parser reads them. The ASCII variant is also **not lossless** for
  AHK1B's single columns — `%.10g`, so 3.3e-10 relative.
- **A `_frac` suffix, not the literal name `time_frac`, is what marks
  a microsecond fraction.** AHK1B calls its `rcvtime_frac`; keying on
  the literal name defaulted the scale to 1 and put every ASCII epoch
  out by a factor of a million, silently. Fixed 2026-09-22.
- **The JPL GRACE Level-1 read software (`GraceReadSW_L1`, release
  2010-03-31) is in hand** as of 2026-09-22 — the producer's own
  reference implementation, and the authority that closed O-15. Its
  `GRACEiolib.h` declares one C struct per product, which independently
  confirmed **all seven** layouts this repository had already measured,
  name for name, including the MAG1B naming taken from the handbook
  the same day and ACC1B's nine columns. **Nothing from the archive is
  vendored into this repository** (owner's decision, 2026-09-22): it is
  an offline oracle, cited in the documentation, and every fixture
  still comes from the owner's own files.
- **The GRACE Level-1B Data Product User Handbook v1.3 (JPL D-22027,
  March 2010) is in hand** as of 2026-09-22 and is the naming source
  for classic MAG1B (section 6.8). Its chapter 6 has format records
  for ACC1B, CLK1B, GPS1B, GNV1B, IHK1B, KBR1B, MAG1B, MAS1B, SCA1B,
  THR1B, TIM1B, TNK1B, USO1B and the vector-offset products — and for
  **AHK1B it has none**. That absence is a fact about the document,
  established by reading it, not an assumption about it.
- **The Level-1B ATBD (JPL D-27672 / GRACE 327-741, v1.2, 2006) is
  also in hand** as of 2026-09-22, and what it is NOT is as worth
  recording as what it is. It carries **no record formats**: searched
  end to end, `prod_flag`, "Data Type", "Byte Length" and `qualflg`
  appear **zero** times, and AHK1B appears twice, both as a file name
  of `TimeCorrHK`. It therefore does **not** discharge the AHK1B half
  of O-15, and a later session should not re-open that hope.
  What it does give:
  - §3.1.4 step 8 **corroborates the nine-column ACC1B layout** — the
    correction that was O-1's headline finding — by saying ACC_1B
    carries the six compressed components *plus* the fit residuals
    plus flags. Third independent line of evidence, after the bytes
    and after ACH1B's declared columns.
  - §3.1.4 step 6 says residuals are compressed minus uncompressed
    **linear** acceleration, flagged above 10 µm/s². That is why
    there are three `acl_*_res` and not six, and the threshold
    matches the ACH1B header's `qualflg` bit 2 word for word.
  - Appendix G defines the three time frames and states that **GPS
    time is the corrected receiver time used in all Level-1B data** —
    the authority for `aux.timeSystem = 'GPS'`, and the meaning of
    the `time_ref` column (`R` receiver, `G` GPS).
  - §7.1 names `TimeCorrHK` as the producer of AHK1B, IHK1B, MAG1B,
    MAS1B, THR1B and TNK1B, matching the `SOFTWARE VERSION` line of
    the real MAG1B and AHK1B headers.
  - Its appendices (B CRN-class filter, D KBR combinations, E
    light-time correction, J SCA combination) are design authority
    for **timeSeriesPreparation**, not for this reader.
- **ACH1B declares the same nine observation columns as classic
  ACC1B**, measured on the real GRACE D file of 2020-01-01. Its
  `ang_accl_x/y/z` are identically zero in all 86 400 records: the
  hybrid transplant supplies linear accelerations only.

---

## D. Conventions

**Two integer types were corrected 2026-09-22** against the JPL read
software, which declares unsigned what this toolbox had signed:
`KBR1B`'s four SNR columns are `uint16_t` (were int16) and `THR1B`'s
42 counters are `uint32_t` (were int32). **Neither changes a value in
any bundled file** — the SNRs reach 690 of 32 767 and the counters
89 329 647 of 2^31 — so this is hardening against a large value on
some other day, not a bug fix, and no golden number moved. Recorded
because "no test changed" is the kind of claim that needs its reason
written down.


- camelCase; `arguments` block on every public function; error
  identifiers `gracefoReading:<fn>:<id>`; provenance footer
  (`Toolbox:` / `Created:` / `Updated:` / `Author:`) in every help block.
- **The help block is the single source of documentation.**
  `docsrc/helpparse.py` parses it; `generate_html.py` and
  `generate_guide.py` render from that parse. Editing `html/` or the PDF
  by hand has no effect and will be overwritten. Edit the `.m` help and
  run `python3 docsrc/generate_docs.py`.
  *Revision 3.0 correction:* the previous Conventions section told the
  reader to edit `docsrc/functionSpecs.json` and regenerate. That
  contradicted the v2.3.0 section three paragraphs above it in the same
  file. `functionSpecs.json` now carries toolbox-level metadata only
  (name, version, date, summary); function bodies come from the help
  blocks.
- `Updated:` moves when a file's *content* changes, not when its version
  stamp does. A version bump rewrites 28 stamps and must leave
  `Updated:` alone in the files it did not otherwise touch.
- Every identifier a public `.m` raises must appear in that function's
  generated HTML page — `testDocConsistency.testErrorIdentifiersDocumented`
  checks it, and it fails on a stale page long before a human notices.
- Real-data expectations are derived independently (the Python reference
  in `tests/python_reference/`) *before* being hardcoded in a MATLAB test.
- Line length 100. Two lines in `readL1bMulti.m` exceed it and predate
  the rule; a whitespace sweep is its own change, never mixed with a fix.

---

## E. Obligations

Each has an owner and a re-entry condition. This is the list; nothing
outside this table claims to be one.

| id | obligation | owner | re-entry |
|---|---|---|---|
| O-1 | **CLOSED 2026-09-22 — the classic layouts are measured.** The owner supplied the RL02 products of 2008-01-01 for GRACE A and B, and the binary layouts of ACC1B, SCA1B, GNV1B, KBR1B, THR1B and MAS1B were derived from those bytes: for each, the declared record count times the derived record length reproduces the data section **exactly**, the first epoch equals the header's TIME FIRST OBS, and a physical quantity was checked (quaternion norm within 1e-6 of unity in all 16 818 + 17 222 SCA1B records; orbit radius 6827-6862 km; range-rate against the derivative of the biased range to 5.8e-6 m/s; thruster- and tank-based spacecraft mass agreeing to 4 g). The assumed table was **wrong**: ACC1B has nine observation columns, not six — the three residual columns were missing entirely. `classicExperimental` no longer fires for the binary variant — nor, since revision 4.2, for the ASCII one, which was measured against the producer's own converter and turned out NOT to be the binary columns as text (MAG1B swaps two of them). Nothing remains | — | — |
| O-2 | **GROOPS export conventions unverified — now half-closed on the READ side.** Five real GROOPS files (ITSG, version tag `20200123`, identical to the writer's) were read on 2026-09-14, so the reader is verified against real output. The WRITER is not: real GROOPS emits a type-name comment, a column legend and a rule that `writeGroopsInstrument` does not, and it writes `1` as the second header integer where the writer writes the column count. An exported file is therefore still not known to be readable by a GROOPS installation. *Original entry:* `writeGroopsInstrument` writes `groops instrument version=20200123`, a two-integer type/dim header, a lone record count and decimal-MJD records, per the known structure. Neither writer nor reader has been checked against a real GROOPS installation. `NonGravForces` WP-34 (its O-19) closes this from the other side | owner | before production export |
| O-3 | **Three version literals, one fact.** `astrobayer/ci-actions/VERSIONING.md` says `version.m` reads `Contents.m` at runtime and never hardcodes. Here `version.m`, `Contents.m` and `docsrc/functionSpecs.json` each carry the literal, reconciled by `testDocConsistency` and `auditHelp.py` rather than derived from one source (R1). A bump therefore touches 28 stamps plus three literals by hand | owner | next time the version machinery is touched |
| O-4 | **CLOSED 2026-09-22.** `v1.1.0` is an **annotated** tag on the merge commit `2c0d7d8` with a GitHub release, which is what VERSIONING.md asks for and what no previous release of this repository had. `v1.0.0` and `v1.0.2` remain lightweight and are left alone: tags are immutable and the correction was always forward-only. Nothing further is owed | — | — |
| O-5 | **Superseded in part, 2026-09-22.** Classic GRACE binary products ARE now read (O-1). What remains true is narrower and not a gap: the GRACE-FO releases this toolbox targets publish ASCII only, so there is no binary GRACE-FO product to support | — | if a binary GRACE-FO product ever appears |
| O-6 | **RL05+ header conventions are unknown.** If PO.DAAC changes them, extend `internal/parseHeaderVariables.m` and add the new files to `tests/realdata/` | owner | when RL05 appears |
| O-15 | **CLOSED 2026-09-22.** Both halves. MAG1B was named from the GRACE Level-1B Data Product User Handbook v1.3 (JPL D-22027) section 6.8. AHK1B - the half this row was narrowed to, with the discharge condition "the GRACE Level-1 *Software* Handbook ... or a real GRACE-FO AHK1B header" - was closed by something better than either: the **JPL GRACE Level-1 read software** (`GraceReadSW_L1`, release 2010-03-31), the producer's own reference implementation. `GRACEiolib.h` types `AHK1X_t` as `ACC1A_t` and `ReadACC1AFRecord.c` walks the flag bit by bit, giving the two facts no single file could reveal: `prod_flag` is **four bytes** (29 conditional columns, not 8) and those columns carry **five different types** (7 double, 18 single, uint8, uint16, uint8, int32). Verified, not trusted: the walk consumed the data section **to the byte** on four files - JPL's 2003 RL00 samples for A and B and the RL02 files of 2008-01-01 for A and B - and the named supply rails come out at nominal (+15 V 14.91, -15 V -14.90, +5 V 5.05, +48 V 50.18, -48 V -50.39), which is the oracle, since one wrong width garbles everything after it. The same archive independently confirmed all seven other layouts struct by struct and corrected two integer types (see D). Nothing from it is vendored | - | - |
| O-10 | **`neutralDensity` is not in the product table.** The ITSG server publishes it and the README gives two different column layouts for releases 1.0 and 1.5/2.0, but no real file was read, so no entry was written. It parses as a generic GROOPS file and warns `productNotRecognised`. Writing the entry from the README alone is the mistake O-1 records | owner | when a real neutralDensity file exists |
| O-7 | **CLOSED 2026-09-22 — measured, then decided.** `readL1b` takes **7.801 s** on one real ACT1B day (86 400 records, 13.5 MB), of which `fileread` is 0.059 s: parsing is 99.2 % of the cost. A year extrapolates to **47.5 min**. No fixed-layout `textscan` fast path is built, and not for want of headroom — see section A for the two reasons (47.5 min/year is not a bottleneck and `'CacheDir'` pays it once; and it would be a second parsing path for one of the reader's three record grammars). `ci/benchmarkParse` and its CI step stay, so re-opening it costs one command | — | a campaign run of X-15 measuring parse time as its dominant cost |

Closed: **O-14** (G-02 and G-05 blocked on unreachable bytes) — opened
and discharged on 2026-09-22. It was opened because the DATAPOOL is
invisible to a Claude Code session and the environment's network policy
answers 403 to the ISDC host; it was discharged the same day by the
owner supplying the sixteen files directly. The obligation did its job:
it stated a precise condition, and that condition is what was met. The
network measurement stays recorded in A2, because it will be true again
next time.

Closed: **O-11** (`readL1bMulti` could not take what `findL1bFiles`
returns) — fixed 2026-09-22 in this branch as G-02's sibling G-01, issue
#16. The declaration is unsized and normalised on entry, and the
documented two-line workflow is run end to end by
`testBatchTools/testFindL1bFilesOutputFeedsMultiDirectly`, which fails
on the old declaration.

Closed: **O-12 of `NonGravForces`** (issue #6, `readL1bMulti` raised
`MATLAB:badsubscript` on an all-empty `TimeRange`) — fixed in 1.0.1,
PR #7, merged 2026-09-08.

Closed: **O-9** (the ITSG date range). `findItsgFiles` and
`readItsgProductMulti` were added 2026-09-14, mirroring `findL1bFiles`
and `readL1bMulti` so the ITSG side reads the same way as the L1B side.
The one limitation worth carrying forward is in the tests, not the code:
only one date of real ITSG data exists here, so the batch suite exercises
the mechanics on synthetic multi-day files and leaves the parsing of real
bytes to `testItsgProducts`.

Closed: **O-8** (the TU Graz reader, issue #11). Opened 2026-09-14 when
the format could not be reached and discharged the same day when five
real products were supplied. Its re-entry condition — "one real file per
sub-product in `tests/realdata/`" — is exactly what discharged it, and
the five trimmed fixtures now in that folder are what keep it closed.
The half of it that remains is O-2's writer side, not this.

---

## F. Record of decisions

| date | decision | why |
|---|---|---|
| 2026-08-01 | Rewrite as `+gracefoReading`; v1 (`graceReading`, `readGraceFoL1b`) superseded | v1 failed on every real RL04 file |
| 2026-08-01 | Parsing rules implemented and verified in Python first (`tests/python_reference/validate_realdata.py`) against the seven real 2020-01-01 products, then hardcoded in `testRealData` | an expectation derived from the code it tests proves nothing |
| 2026-08-14 | `'TimeFormat',"gpsns"` computes int64 GPS nanoseconds by integer arithmetic and never round-trips through double | 2020-era GPS-ns values are ~6.3e17, past double's exact integer range (2^53) |
| 2026-08-14 | Cache key is a SHA-256 of content **plus the toolbox version** | caches self-invalidate on upgrade instead of silently serving an old parse |
| 2026-09-06 | Renumber 2.3.0 → 1.0.0 | no tag, no release, nothing published was rewritten; 2.3.0 was reached without a rollout |
| 2026-09-06 | `docsrc/mfile.py` becomes the single point of access for help-block boundaries | four copies of the rule "the declaration is line 1" existed and all four were wrong the same way; writer and auditor shared the error, so the audit certified files MATLAB could not parse |
| 2026-09-08 | `readL1bMulti` returns clean empties for an all-excluding range rather than erroring, and reports it with `noRecordsInRange` | erroring would make the two readers disagree on one input class and would keep `NonGravForces` `l1bLoad`'s single/multi split alive permanently; silence would hide a wrong `TimeRange` |
| 2026-09-08 | `localWarnNoRecords` derives every number in its message from the run | diagnostic text is a claim too (R3); a message restating the call can drift from what happened |
| 2026-09-14 | Issue #11 stopped **before** implementation and recorded as O-8 instead of being built from the layout the issue quotes | the issue itself asks to "check rather than assume", and the check is impossible from here. `resolveTime` already states the governing rule for this repository: a unit "is a property of the file, not of the product family. Do not infer a unit from a sibling product" — building the Graz reader from the COST-G benchmark layout is exactly that inference |
| 2026-09-14 | `readGroopsInstrument` recovers the epoch from the printed **digits** (integer split at the decimal point, int64 throughout) rather than from `sscanf('%f')` | measured, not assumed: over 100 000 epochs of 2020-01-01 the double path misplaced tags by up to **314 ns** and the digit path by **0 ns**. Without this, `'TimeFormat', "gpsns"` would return nine digits of which three are noise |
| 2026-09-14 | `readGroopsInstrument` validates time tags **before** the declared column count | CI run 34807682341 showed the other order naming the wrong cause: a tag like `58849.5.5` makes `sscanf('%f')` return three values where two columns were declared, and `fifty` returns none, so both were reported as `countMismatch` when the real fault was the time tag. R3 — a diagnostic is a claim too |
| 2026-09-14 | Issue #11 implemented from five real files rather than from the layout the issue quoted | the files arrived, so O-8's re-entry condition was met. Every structural claim in the reader was read off the bytes: the comment lines, the type names and codes, and the second header integer being 1 against 3/4/6/9 columns — which the issue's quoted layout would not have revealed |
| 2026-09-14 | `readItsgProduct` excludes zero-padding columns from OBS and verifies the exclusion against the data | the GROOPS ORBIT type always writes 9 columns; a kinematicOrbit file fills 3. Returning the zeros would give a caller exactly 0 m/s at every epoch of a kinematic orbit. The documentation says which columns are carried, so the check fires when a file disagrees with it rather than trusting either side alone |
| 2026-09-14 | The frame and time system are recorded with their provenance, never inferred from the file name alone | measured: no frame or time-system string appears anywhere in the files. The product README supplies both, keyed on the product, and the product comes from the name — so `aux.frameSource`, `aux.timeSystemSource` and `aux.productSource` say how each answer was reached, and an unrecognised product gets no frame at all |
| 2026-09-14 | `readItsgProductMulti` checks the product first and does not check the frame at all | the frame is derived from the product and `'Frame'` is forwarded to every file, so equal products already mean equal frames. A frame check could never fire, and a documented identifier that cannot be raised is a promise the function cannot keep — the same standard `auditHelp.py` enforces in the other direction |
| 2026-09-14 | `readItsgProductMulti` declares `fileNames` unsized and normalises it, rather than copying `readL1bMulti`'s `(1,:)` | `findItsgFiles` returns a `[K x 1]` column, exactly as `findL1bFiles` does. Copying the declaration would have reproduced O-11, where the documented two-line workflow fails for more than one file |
| 2026-09-18 | The preprocessing concept is the design authority for preprocessing, accelerometer calibration and LRI/KBR processing across the ecosystem. It was drafted here on branch `claude/preproc-concept` and moved to `astrobayer/timeSeriesPreparation` `docs/` at X-00a (timeSeriesPreparation#2); decisions Q1–Q16 are in its section 11 and not restated here. **Consequence for this repository:** no preprocessing code; reader obligations G-01 #16 (= O-11), G-02 #17 (= O-1), G-03 #18 (= O-7), G-04 #19, G-05 #20, G-06 #21 | owner |
| 2026-09-18 | **Correction, measured after the merge:** PR #15 was merged with a **merge commit** (`de87fbf`, parents `a18e9ad` and `4a6bc8c`), not squashed as planned, and its branch was deleted. The tree is as intended (net change `HANDOVER.md` only; CI on `main` run 35392857232 green), but `main`'s history now contains every concept draft (`2d7a06c` … `4c08cb7`) and the two input zips (AccelBiasScaleToolbox 2.4.2, sigtools 1.3.1; about 2.7 MB). Accepted: removing them would mean rewriting `main`, which the ruleset forbids and nothing requires. The concept's pre-move history stays reachable from `main` up to `4c08cb7` | measured 2026-09-18; the planned squash (concept Q14 item 5) did not happen |
| 2026-09-22 | The classic binary layouts were derived from the bytes and each checked against a PHYSICAL quantity, not read from the handbook | The handbook was not at hand, and a layout from memory is what O-1 records as the v1 failure. A structural check alone would not have been enough either: a wrong offset yields plausible numbers. The quaternion norm, the orbit radius, the range-rate against the range derivative and the two independent spacecraft masses are oracles the file cannot satisfy by accident — and one of them caught the real error, ACC1B having nine columns where the assumed table had six |
| 2026-09-22 | **Superseded for MAG1B the same day, by the handbook arriving.** MAG1B's columns are now named from JPL D-22027 section 6.8 and the product is read; AHK1B stays refused, and the handbook is the reason it stays refused rather than the reason it might not - it has no AHK1B format record at all. The entry below stands as the record of why refusing was right while the document was missing | the discharge condition O-15 stated was met exactly as written, which is what a well-written obligation is for |
| 2026-09-22 | Classic MAG1B and AHK1B are REFUSED although their structure was measured | Structure is not a layout. Ten of MAG1B's thirteen columns have no name that any document here supplies, and AHK1B's conditional columns have per-bit types a single file cannot reveal. Returning columns under invented names would be worse than refusing, because a caller cannot tell an invented name from a measured one. O-15 records exactly what is known so the gap closes in minutes when the handbook appears |
| 2026-09-22 | **Reversed the same day, and the caution paid for itself.** The ASCII variant was measured against the JPL read software's own `Bin2AsciiLevel1`: the inference it shares the binary column table is **false for MAG1B**, which prints `GRACE_id` before `time_ref`, and AHK1B writes `status` as bit characters. Holding the warning until a real measurement existed is exactly what kept two silent corruptions out of the toolbox. The entry below stands as the record | the warning now fires only for caller-supplied `ColumnNames` |
| 2026-09-22 | The classic ASCII variant keeps its `classicExperimental` warning although it now shares the corrected column table | The correction was measured on the BINARY variant. That the ASCII variant of the same product carries the same columns is a sound inference and it is what the shared table assumes, but it is an inference, and no real classic ASCII file has been read here. The warning is the difference between the two, stated |
| 2026-09-22 | `readL1b` reads BYTES and derives text from them, rather than reading text | A char read applies the file encoding, and an arbitrary binary record is not valid UTF-8: bytes would be replaced or merged and the records destroyed, silently, because the ASCII header would still look perfectly readable. `char()` over a uint8 row is byte-exact, so the text paths see exactly what they saw before |
| 2026-09-22 | The classic binary dispatch reads the FILE FORMAT field by its RAW key text, not by a sanitised field name | `makeValidName` rewrites "FILE FORMAT 0=BINARY 1=ASCII" in a way that is its business; guessing the result would silently route a binary file through the text parser. Finding the field also required widening the header key pattern, which had never admitted "=" and had been dropping that record — and two others — without a word |
| 2026-09-22 | `readEventList` returns TN-01a entries as date plus text, and extracts no manoeuvre windows from the prose | CONCEPT 9 is explicit that nothing is inferred that a list states, and the interpretation belongs to X-05. TN-01a is an operators' log written by different people over years; a regex over it would look like structure and behave like a guess. TN-01's declared value count IS structure, and that is parsed exactly — all 3 402 lines of the published file parse under it, measured |
| 2026-09-22 | A TN-01 row commented out with a leading "x" is kept and flagged, not dropped | Dropping it would lose the record that the value was once there, which is precisely what a caller reconstructing a history needs. `disabled` lets the caller decide, which is the same reason the unparsable line numbers are returned rather than swallowed |
| 2026-09-22 | The epoch arithmetic moved to `internal/gpsSecondsToMjd`, shared by the ASCII and the classic binary parsers, and it returns the epoch integer too | The 2026-09-14 entry says why in its own words: the formula was once about to live in two files, and a divergence would shift every epoch of one reader with nothing visible to say so. The classic binary parser would have been that second file. The epoch integer 51544 comes back from the helper for the same reason — a second copy is a second thing to get wrong |
| 2026-09-22 | A record may exceed its declared column count only where the last declared variable says so **in its own comment or long_name**, and then it takes the rest of the line verbatim | Read off real LHK1B: `comment: Entire remaining portion of each record`. Two rules were available and only one is file-driven. "The last column is text" would have keyed on `units: char`, which `sensorname` does not declare, so it would not have fired; "surplus tokens go to the last column" would have weakened the row-integrity check for every product. The header's own sentence is the licence, so the check stays strict everywhere else and a SHORT record is still an error |
| 2026-09-22 | The shared real-data invariant asserts **non-decreasing** epochs, not strictly increasing | LHK1B is long format — one record per sensor per epoch — and opens with three records sharing 631108800.872776889. Strict monotonicity is a property of the one-record-per-epoch products, not of L1B as such, and asserting it in a shared helper would have made a correct file look corrupt |
| 2026-09-22 | The LHK1B fix waited one CI round for a header dump instead of being written from the owner's description of the format | The description (sensortype, sensorvalue, sensorname) was right and would have produced a working reader, but by inference. The dump then showed two things the inference did not: the licence is a sentence rather than `units: char`, and the product is long format. Both would have been defects. One round of CI is cheaper than either |
| 2026-09-22 | `internal/variableFieldNames` becomes the single point of access for the variable-name → struct-field mapping, applied to the WHOLE ordered list rather than per name | `matlab.lang.makeValidName` is not injective: `+` and `-` both become `_`, so AHK1B's `TSU_Y+` and `TSU_Y-` collapse onto one field and one real temperature column silently overwrites the other. Per-name calls cannot see a collision, and there were four of them in three files — the 2026-09-06 failure mode exactly. The mapping is the identity on every name in every product read so far, so no existing fixture moves |
| 2026-09-22 | A renamed field is reported by `readL1b:variableNameAdjusted`, and `aux.variableNames` / `aux.obsNames` keep the declared names | R3 — silently changing the name a caller matches on is the same class of defect as silently changing a number. The declared name stays the interface; the field name is a per-file detail, and `aux.variableFieldNames` gives the mapping |
| 2026-09-22 | The G-04 acceptance rows for ACH1B, AHK1B and LHK1B assert invariants and documented facts, not golden numbers | No one in this repository has read those files. A golden number derived from a file nobody has seen is an assumption dressed as a measurement — O-1 again. The invariants (record count, strict monotonicity, every declared variable reachable under its own field) are what the reader promises for any product, and the last of them is precisely what failed before the `variableFieldNames` change |
| 2026-09-22 | `verifyDataPool` reports UNLISTED files rather than leaving them out, and an unlisted file does NOT clear the `ok` verdict | "Not checked" and "checked and correct" are different answers. ITSG and ZARM publish no checksums at all (V-15), so a report that showed only verified files would be read as covering the pool. An unlisted file is not a failure either, so it is said out loud without failing the verdict |
| 2026-09-22 | The digest algorithm is taken from the digest LENGTH, not from the manifest's file name | The same rule `resolveTime` states for units: it is a property of the line, not of the family it sits in. A list called `SHA256SUMS_…` that holds MD5 digests is read as what it contains, and a BSD tag that disagrees with its own digest length names no algorithm at all |
| 2026-09-22 | `ci/benchmarkParse` reports `fileread` alone beside the total, and is `continue-on-error` in CI | The total alone cannot answer O-7: a fast path can only win back the difference between parsing and reading the bytes. And a measurement that can turn a green suite red would be an acceptance point, which it is not — it asserts nothing |
| 2026-09-22 | `<ROOT>\<name>` stays a fixture candidate for exactly one release beside `<ROOT>\RawData\tests\realdata\<name>` | Deleting the repository-level variable and switching to the organisation one is one step; without the fallback that step would also turn a green run into a row of skipped acceptance points, and the two causes would be indistinguishable. The CI step prints which candidate answered, so the switch is measured rather than assumed |
| 2026-09-22 | The `.github/` changes ride in this PR, in their own commit, instead of a separate PR | GUIDE section 1 asks for both "workflow changes stand alone" and "one open PR per repository", and G-07 and G-03 each need a CI step. The commit is isolated and named in the PR body for line-by-line reading, which is what the rule protects. Recorded rather than done quietly |
| 2026-09-14 | The `'TimeFormat'` mapping moved to `internal/formatEpoch`, called by both readers | the datetime epoch formula was about to exist in two files. That is the 2026-09-06 failure mode exactly, and a divergence would shift every epoch of one reader with nothing visible to say so |

---

## G. What a next session would be wrong for not reading

1. **The version was renumbered downwards.** 2.3.0 → 1.0.0 on 2026-09-06.
   Anything in this repository's history that says "v2.x" describes the
   same code under the old scheme. `HANDOVER.md` itself said v2.0.0 until
   Revision 3.0 and listed CI-covered work as open — do not trust a
   status line without a measured number beside it.
2. **A version bump is a 31-file change.** 28 provenance stamps plus
   `Contents.m`, `version.m` and `functionSpecs.json` (O-3). Keep it in
   its own commit or the real diff becomes unreadable.
3. **Regenerate the docs in the same change as any help edit.** CI runs
   `git diff --exit-code -- html/`, and `testDocConsistency` requires
   every raised identifier to be on its function's page. A new `error` or
   `warning` id with a stale page is a red run.
4. **The classic-GRACE path is unvalidated (O-1).** It warns on every
   use. Do not let a green suite be read as evidence about it: no real
   classic file exists in this repository.
5. **Issue #11 is implemented, and the digit-based epoch path is why
   it works.** The ITSG time tags carry 18 decimals and do not lie on
   the double lattice at all; the kinematic products sit 213 ns off the
   integer second and vary by up to 291 ns over a day, which is 0.46 of
   a double's ulp at MJD 58849. Reading them through `sscanf('%f')`
   would erase exactly the receiver-clock correction the product README
   says is there. Do not "simplify" `localExactMjd` back to a double.
6. **Section A's test counts were stale for a whole release, and only
   a prediction caught it.** See the note under the per-class table: the
   v1.0.2 MAG1B work added three `testReadL1b` tests that were never
   recorded, so the status line said 65 when the suite ran 68. Nothing
   failed because of it — a stale count is invisible until someone
   predicts against it, which is the reason the prediction step exists.
7. **Two test suites need things the sandbox does not have.**
   `testRealData` needs `READING_DATA_POOL`; the full suite needs MATLAB.
   A session with neither can still run all three static gates, and
   should say so rather than reporting "green".
8. **`READING_DATA_POOL` is the DATAPOOL ROOT, and the fallback dies
   next release.** Fixtures resolve below it in `RawData\tests\realdata`.
   `<ROOT>\<name>` is still accepted, deliberately, for 1.1.0 only
   (G-07, #23). Dropping it is a one-line change in
   `testRealData.resolveFixture` plus the CI step's `cand` list, and
   must not happen until a green run reports `0 via the legacy path`.
9. **All seven G-items are done.** G-02 and G-05 were blocked on
   bytes no session could reach (O-14) and were unblocked the same day
   by the owner supplying sixteen files directly. The lesson to carry
   forward is the shape of that obligation, not its subject: it named
   a precise discharge condition, and that condition is what was met.
10. **The classic layouts are measured, and one of them was wrong.**
   ACC1B carries NINE observation columns; the table assumed from the
   handbook had six, the three residual columns missing altogether. If
   you find yourself about to trust a layout nobody in this repository
   has read off a file, read O-1's history first — it is closed now,
   but it was open for two months for good reason.
11. **Classic qualflg is a byte.** The binary files store it as a
   single-byte bitmask, not as text. The reader renders it as the same
   8-character bit string the GRACE-FO products use, so
   `decodeQualFlags` works on both unchanged. V-8's open question is
   answered.
12. **gracefoReading gains no preprocessing code from the concept.** Its
   items are G-01 … G-06 (issues #16–#21). The design, the order of work and
   the procedures live in `astrobayer/timeSeriesPreparation` (`docs/CONCEPT.md`,
   `docs/GUIDE.md`). The concept's history before the move is in this
   repository's `main` history (merged with #15), ending at `4c08cb7`; the
   files are no longer in the tree.
