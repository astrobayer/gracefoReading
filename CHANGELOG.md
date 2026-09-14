# Changelog — gracefoReading

## Unreleased

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

### Fixed — the record's own test counts

- HANDOVER.md section A said `testReadL1b` 22 and a suite total of 65.
  The true figures before this change were **25 and 68**: the three
  MAG1B tests added for issue #9 in v1.0.2 went into `testReadL1b` and
  the status line was never updated, so v1.0.2 shipped with a stale
  count. It surfaced only because a prediction was made against it and
  missed by exactly those three.


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
