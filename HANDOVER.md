# HANDOVER — gracefoReading

**Revision 3.2 · 2026-09-14 · toolbox v1.0.2**

The single point of truth for this repository. Where this document and a
general engineering habit disagree, this document is right. Read it
before any code, and do not start from memory of a previous session.

`README.md` is the user-facing description (what the toolbox does, how to
install it). This file is the developer record: status, decisions,
obligations, and what a next session would be wrong for not reading.
Facts live in one of the two, not both.

---

## A. Status — measured, not asserted

| | |
|---|---|
| Version | 1.0.2 (`gracefoReading.version()`; `Contents.m` and `docsrc/functionSpecs.json` must agree) |
| Tests | **88 passed, 0 failed, 1 incomplete — 89 total** — CI run 34869994810, head `3618e84`, self-hosted Windows runner, MATLAB R2026a Update 5, 2026-09-14. The incomplete is `testFullDayKinematicJitter`, which needs a full ITSG day in the pool and is expected until one is copied there — see the note below |
| Static gates | `docsrc/sourceIntegrity.py` 32 files / 0 findings · `docsrc/auditHelp.py` 32 help blocks clean · `git diff --exit-code -- html/` clean — all three run 2026-09-14 in a sandbox without MATLAB |
| Public units | 11 in `+gracefoReading/`, 10 internal in `+gracefoReading/+internal/` |
| Tag / release | `v1.0.0` (lightweight tag + GitHub release, 2026-09-06). **v1.0.1 is merged but not tagged or released** — see O-4 |

Per-class test counts, for the prediction a next session must make
*before* running: `testReadL1b` **25**, `testUtilities` 15,
`testBatchTools` **14**, `testItsgProducts` **15** (new 2026-09-14),
`testRealData` 8, `testDocConsistency` 7, `testSourceIntegrity` 5. Sum
**89**, which reconciles with the CI total. A run reporting anything
else is a finding, not a rounding.

**Predict the split, not just the sum.** The 2026-09-14 prediction gave
the per-class sum correctly as 89 and then wrote it as "89 passed and 1
incomplete", which is 90 tests. The measured run is 88 passed + 1
incomplete = 89. Nothing was wrong with the code or the count; the
arithmetic of the *reconciliation* was wrong, and a sum that agrees with
itself hides that. State the prediction as passed + failed + incomplete
= total, and check that the three add up before running.

**One incomplete is expected and is not a regression.**
`testItsgProducts/testFullDayKinematicJitter` asserts the receiver-clock
variation of the kinematic products, which first occurs well past record
60 and so cannot be seen in the bundled fixture. It reads the full
published day from `READING_DATA_POOL` and skips when it is absent. The
CI pool currently holds the five PO.DAAC products and no ITSG file, so
it will report incomplete until
`GRACEFO-1_kinematicOrbit_2020-01-01.txt` (~2.2 MB, or its `.gz`) is
copied there. Everywhere else in this file "incomplete is a finding"
still holds; this one row has a named cause and a one-file fix.

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
| O-1 | **Classic GRACE layouts are ASSUMED, not validated.** The built-in ACC1B/SCA1B/KBR1B/GNV1B column tables in `internal/parseClassicProduct.m` come from the GRACE L1B handbook *from memory*. Every classic read warns `classicExperimental`. Before any scientific use: obtain one real classic file per product, then either confirm the layouts (add the files to `tests/realdata/`, drop the warning) or correct the tables. Classic `qualflg` may be decimal rather than an 8-character bit string — verify. The v1 lesson applies exactly: invented formats fail on real files | owner | before any classic-era study |
| O-2 | **GROOPS export conventions unverified — now half-closed on the READ side.** Five real GROOPS files (ITSG, version tag `20200123`, identical to the writer's) were read on 2026-09-14, so the reader is verified against real output. The WRITER is not: real GROOPS emits a type-name comment, a column legend and a rule that `writeGroopsInstrument` does not, and it writes `1` as the second header integer where the writer writes the column count. An exported file is therefore still not known to be readable by a GROOPS installation. *Original entry:* `writeGroopsInstrument` writes `groops instrument version=20200123`, a two-integer type/dim header, a lone record count and decimal-MJD records, per the known structure. Neither writer nor reader has been checked against a real GROOPS installation. `NonGravForces` WP-34 (its O-19) closes this from the other side | owner | before production export |
| O-3 | **Three version literals, one fact.** `astrobayer/ci-actions/VERSIONING.md` says `version.m` reads `Contents.m` at runtime and never hardcodes. Here `version.m`, `Contents.m` and `docsrc/functionSpecs.json` each carry the literal, reconciled by `testDocConsistency` and `auditHelp.py` rather than derived from one source (R1). A bump therefore touches 28 stamps plus three literals by hand | owner | next time the version machinery is touched |
| O-4 | **Tagging is behind and off-standard.** `v1.0.0` is a *lightweight* tag; VERSIONING.md requires an annotated tag plus a GitHub release per version. v1.0.1 is merged with neither. Tags are immutable and are never moved, so `v1.0.0` stays as it is; the correction is forward-only | owner | before anyone depends on a pinned version |
| O-5 | **Binary L1B is unsupported** and refuses with an explicit error. Only the ASCII products are read | — | if a binary product is ever needed |
| O-6 | **RL05+ header conventions are unknown.** If PO.DAAC changes them, extend `internal/parseHeaderVariables.m` and add the new files to `tests/realdata/` | owner | when RL05 appears |
| O-9 | **`readItsgProduct` reads one file per call.** Issue #11 asked for "one file or a date range"; the date range is not built. There is no ITSG counterpart to `readL1bMulti` (concatenation, aux merging, monotonicity) or to `findL1bFiles` (the ITSG names are `<satellite>_<product>_<yyyy-mm-dd>.txt[.gz]`, not the PO.DAAC pattern). Callers loop and concatenate for now | owner | when a multi-day ITSG study is actually needed |
| O-10 | **`neutralDensity` is not in the product table.** The ITSG server publishes it and the README gives two different column layouts for releases 1.0 and 1.5/2.0, but no real file was read, so no entry was written. It parses as a generic GROOPS file and warns `productNotRecognised`. Writing the entry from the README alone is the mistake O-1 records | owner | when a real neutralDensity file exists |
| O-7 | **Line-wise regexp tokenisation has headroom.** An 86400-line day file parses acceptably, but a typed `textscan` fast path exists for fixed-layout products. Profile in MATLAB before optimising — no speed claim has been measured | — | if a day file becomes a bottleneck |

Closed: **O-12 of `NonGravForces`** (issue #6, `readL1bMulti` raised
`MATLAB:badsubscript` on an all-empty `TimeRange`) — fixed in 1.0.1,
PR #7, merged 2026-09-08.

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
