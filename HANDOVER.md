# HANDOVER — gracefoReading

**Revision 3.5 · 2026-09-22 · toolbox v1.1.0**

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
| Tests | **PREDICTED 114 passed + 0 failed + 4 incomplete = 118 total.** Not measured: this branch is tier B and the sandbox has no MATLAB. The CI run on the self-hosted Windows runner is the measurement, and this row is replaced by its numbers and run id before the merge. The last measured figure is 100 + 0 + 1 = 101, CI run 34873244487, 2026-09-14 |
| Static gates | `docsrc/sourceIntegrity.py` 42 files / 0 findings · `docsrc/auditHelp.py` 42 help blocks clean · `python3 docsrc/generate_docs.py` then `git diff --exit-code -- html/` clean, and byte-identical on a second run — all four run 2026-09-22 in a sandbox without MATLAB |
| Public units | 14 in `+gracefoReading/`, 14 internal in `+gracefoReading/+internal/` |
| Tag / release | `v1.0.0` (lightweight tag + GitHub release, 2026-09-06). **v1.0.1 and v1.0.2 are merged but v1.0.1 has no release and 1.1.0 is unreleased** — see O-4 |

Per-class test counts, for the prediction a next session must make
*before* running: `testReadL1b` **27** (+2 for G-04), `testUtilities`
**16** (+1 for G-01), `testBatchTools` **15** (+1 for G-01),
`testItsgProducts` 15, `testRealData` **11** (+3 for G-04),
`testItsgBatch` 12, `testDataPool` **10** (new 2026-09-22, G-06),
`testDocConsistency` 7, `testSourceIntegrity` 5. Sum **118**, of which
114 are expected to pass and 4 are the documented incompletes below.
The last measured total is 101. A run reporting anything else is a
finding, not a rounding.

**Predict the split, not just the sum.** The 2026-09-14 prediction gave
the per-class sum correctly as 89 and then wrote it as "89 passed and 1
incomplete", which is 90 tests. The measured run is 88 passed + 1
incomplete = 89. Nothing was wrong with the code or the count; the
arithmetic of the *reconciliation* was wrong, and a sum that agrees with
itself hides that. State the prediction as passed + failed + incomplete
= total, and check that the three add up before running.

**Four incompletes are expected and are not a regression.** Each has a
named cause and a one-file fix, and each becomes a pass the moment the
file is in the pool. Everywhere else in this file "incomplete is a
finding" still holds.

| point | waits for | since |
|---|---|---|
| `testItsgProducts/testFullDayKinematicJitter` | `GRACEFO-1_kinematicOrbit_2020-01-01.txt` (~2.2 MB, or its `.gz`). It asserts the receiver-clock variation of the kinematic products, which first occurs well past record 60 and so cannot be seen in the bundled fixture | 2026-09-14 |
| `testRealData/testACH1B` | `ACH1B_2020-01-01_C_04.txt`, from the `.ACX` daily archive | 2026-09-22, G-04 |
| `testRealData/testAHK1B` | `AHK1B_2020-01-01_C_04.txt`, from the `.noLRI` daily archive | 2026-09-22, G-04 |
| `testRealData/testLHK1B` | `LHK1B_2020-01-01_C_04.txt`, from the `.LRI` daily archive | 2026-09-22, G-04 |

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

**Out of scope on this branch**

- **G-02 (#17)** and **G-05 (#20)** are not implemented. Both need real
  bytes — classic RL02/RL03 L1B (binary records after an 80-byte ASCII
  header) and the TN-01 / TN-01a event lists — that exist only in the
  owner's DATAPOOL. The sandbox's network policy denies
  `isdc-data.gfz.de` (measured 2026-09-22: `403 CONNECT` from the egress
  proxy, for both the RL03 tree and `DOCUMENTS/TECHNICAL_NOTES/`), so the
  files could not be fetched either. Writing either layout from a handbook
  read from memory is precisely the v1 failure O-1 records, so neither was
  written. See O-1 and the new O-14.
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

---

## D. Conventions

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
| O-1 | **Classic GRACE layouts are ASSUMED, not validated.** The built-in ACC1B/SCA1B/KBR1B/GNV1B column tables in `internal/parseClassicProduct.m` come from the GRACE L1B handbook *from memory*. Every classic read warns `classicExperimental`. Before any scientific use: obtain one real classic file per product, then either confirm the layouts (add the files to `tests/realdata/`, drop the warning) or correct the tables. Classic `qualflg` may be decimal rather than an 8-character bit string — verify. The v1 lesson applies exactly: invented formats fail on real files **Scheduled 2026-09-18 as concept G-02** (Q6: classic GRACE is in scope of the preprocessing pipeline); the owner supplies the real files when that work starts. **2026-09-19, measured while fetching D-8 (issue #17):** the files exist in the DATAPOOL for 2008-07, 2012-01 and 2017-01, and the problem is larger than a column table — classic RL03 `.dat` files are **binary after an ASCII header** (`FILE FORMAT 0=BINARY 1=ASCII : 0`, `NUMBER OF HEADER RECORDS : 47`), RL03 holds only KBR1B, SCA1B and the transplant, and the full product set is RL02. O-5 (binary L1B unsupported) therefore stands between G-02 and its own data. **2026-09-22:** still not started; see O-14 for why it could not be started from this sandbox | owner | one real classic file per product reachable from the working session (G-02) |
| O-2 | **GROOPS export conventions unverified — now half-closed on the READ side.** Five real GROOPS files (ITSG, version tag `20200123`, identical to the writer's) were read on 2026-09-14, so the reader is verified against real output. The WRITER is not: real GROOPS emits a type-name comment, a column legend and a rule that `writeGroopsInstrument` does not, and it writes `1` as the second header integer where the writer writes the column count. An exported file is therefore still not known to be readable by a GROOPS installation. *Original entry:* `writeGroopsInstrument` writes `groops instrument version=20200123`, a two-integer type/dim header, a lone record count and decimal-MJD records, per the known structure. Neither writer nor reader has been checked against a real GROOPS installation. `NonGravForces` WP-34 (its O-19) closes this from the other side | owner | before production export |
| O-3 | **Three version literals, one fact.** `astrobayer/ci-actions/VERSIONING.md` says `version.m` reads `Contents.m` at runtime and never hardcodes. Here `version.m`, `Contents.m` and `docsrc/functionSpecs.json` each carry the literal, reconciled by `testDocConsistency` and `auditHelp.py` rather than derived from one source (R1). A bump therefore touches 28 stamps plus three literals by hand | owner | next time the version machinery is touched |
| O-4 | **Tagging is behind and off-standard.** `v1.0.0` is a *lightweight* tag; VERSIONING.md requires an annotated tag plus a GitHub release per version. v1.0.1 is merged with neither. Tags are immutable and are never moved, so `v1.0.0` stays as it is; the correction is forward-only | owner | before anyone depends on a pinned version |
| O-5 | **Binary L1B is unsupported** and refuses with an explicit error. Only the ASCII products are read | — | if a binary product is ever needed |
| O-6 | **RL05+ header conventions are unknown.** If PO.DAAC changes them, extend `internal/parseHeaderVariables.m` and add the new files to `tests/realdata/` | owner | when RL05 appears |
| O-14 | **G-02 (#17) and G-05 (#20) are blocked on bytes no working session can reach.** Both need real files: classic RL02/RL03 L1B (binary records, per O-1) and the official event lists TN-01 SOE / TN-01a SCE. They exist in the owner's DATAPOOL, which a Claude Code session does not see, and **the network policy of the remote execution environment denies `isdc-data.gfz.de`** — measured 2026-09-22, `403` to `CONNECT` from the egress proxy, for both `…/grace/Level-1B/JPL/INSTRUMENT/RL03/` and `…/grace-fo/DOCUMENTS/TECHNICAL_NOTES/`, through `curl` and through the fetch tool alike. `raw.githubusercontent.com` answers, so the policy is a host allow-list and not a broken proxy. Writing either reader from a handbook remembered rather than read is the v1 failure O-1 records, so neither was written. **Discharged by any one of:** the owner adding those hosts to the environment's network policy; the owner pasting one classic ASCII header, a hexdump of its first binary records and the first lines of a TN-01 / TN-01a list into the session; or the work moving to a session that can see the DATAPOOL | owner | before G-02 or G-05 is started again |
| O-10 | **`neutralDensity` is not in the product table.** The ITSG server publishes it and the README gives two different column layouts for releases 1.0 and 1.5/2.0, but no real file was read, so no entry was written. It parses as a generic GROOPS file and warns `productNotRecognised`. Writing the entry from the README alone is the mistake O-1 records | owner | when a real neutralDensity file exists |
| O-7 | **Line-wise regexp tokenisation has headroom.** An 86400-line day file parses acceptably, but a typed `textscan` fast path exists for fixed-layout products. Profile in MATLAB before optimising — no speed claim has been measured. **2026-09-22 (G-03, #18):** the instrument now exists — `ci/benchmarkParse` and a non-blocking CI step on the runner, which is the only machine with both MATLAB and a real ACT1B day. It reports the total **and** `fileread` alone, because a fast path can only ever win back the difference. **The number itself is still missing**: this branch is tier B, so it arrives with the first CI run of this branch's PR and is recorded here with the run id and the MATLAB release. O-7 closes when that number is in this table and the decision is written beside it | — | read the number out of the CI log of this PR |

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
9. **Five of the seven G-items are done; G-02 and G-05 are not, and
   the reason is not effort.** O-14 records it: the bytes are in the
   DATAPOOL and the environment's network policy denies the ISDC host.
   A next session that cannot reach either should say so rather than
   writing a layout from a handbook — that is exactly the v1 failure.
10. **gracefoReading gains no preprocessing code from the concept.** Its
   items are G-01 … G-06 (issues #16–#21). The design, the order of work and
   the procedures live in `astrobayer/timeSeriesPreparation` (`docs/CONCEPT.md`,
   `docs/GUIDE.md`). The concept's history before the move is in this
   repository's `main` history (merged with #15), ending at `4c08cb7`; the
   files are no longer in the tree.
