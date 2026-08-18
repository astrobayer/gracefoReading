# Changelog — gracefoReading

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
