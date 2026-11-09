# gracefoReading — GRACE-FO Level-1B ASCII reading toolbox for MATLAB

Version 1.3.0 — 2026-09-27 — MIT license — requires MATLAB R2020b+
Developed with Claude Sonnet 5 (Anthropic).

Reads any GRACE-FO Level-1B RL04 ASCII product (ACT1B/ACC1B, SCA1B,
KBR1B, LRI1B, GNV1B, THR1B, MAS1B, ...) into a common layout:

```matlab
setupGraceFOReading
[time, obs, aux] = gracefoReading.readL1b('ACT1B_2020-01-01_C_04.txt');
% time : [N x 2]  integer MJD | seconds of day   (or datetime, on request)
% obs  : [N x M]  observation columns, names in aux.obsNames
% aux  : struct   flags, char columns, units, header, provenance
```

The reader is driven entirely by each file's own YAML header — no
per-product layouts are hard-coded. Validated against real PO.DAAC
RL04 files of 2020-01-01 (all seven products above).

## Features

- Split time tags (`time_intg`+`time_frac`) with **unit-aware**
  fractional scaling (microseconds in real THR1B/MAS1B files)
- Bit-string flags (`qualflg`, `prod_flag`) preserved as raw bit
  patterns **and** decoded logical bit matrices
- `prod_flag` variable-length records (MAS1B): absent values → NaN
- `'TimeRange'`, `'TimeFormat'` (`"mjd"`/`"datetime"`),
  `'ApplyQualityFlags'` options
- Strict row-integrity check with exact line numbers; gzip input
- `'TimeFormat'` `"gpsns"`: exact int64 GPS-nanosecond time (lossless
  handoff to int64-nanosecond pipelines); `'QualityBitMask'` for
  selective flag filtering; `'CacheDir'` for content-hashed parse
  caching (re-reads load instead of parse)
- `gracefoReading.readL1bMulti` — safe multi-file concatenation with
  cross-file monotonicity check
- `gracefoReading.findL1bFiles` — archive search by product/date/
  satellite with missing-day report; `gracefoReading.findGaps` —
  gap/segment analysis
- `gracefoReading.verifyDataPool` — checks a local data pool against
  the checksums its sources published (the MD5 lists of the L1B day
  archives, SHA-256 manifests recorded beside the data), reporting per
  file OK / MISMATCH / MISSING / UNLISTED with the manifest that made
  the claim
- `gracefoReading.decodeQualFlags` — flag meanings from the file's own header
- `gracefoReading.checkQuaternionNorm` — SCA1B sanity check
- `gracefoReading.writeGroopsInstrument` / `readGroopsInstrument` —
  GROOPS ASCII export and import
- **Classic GRACE (2002–2017)**: auto-detected key-value headers, and
  the header's own `FILE FORMAT` record decides the variant.
  **Binary** `.dat` products (ACC1B, SCA1B, GNV1B, KBR1B, THR1B,
  MAS1B, MAG1B, AHK1B) are read from layouts *measured* on real files
  and each checked against a physical quantity it must reproduce —
  release 02 for all eight, and release 03 for the two products RL03
  publishes — these do not warn. AHK1B's `prod_flag` is four bytes
  and its conditional columns carry five different types; both come
  from the layout, never from the first column seen. The **ASCII**
  variant no longer warns either: its column order and rendering are
  *measured* against the producer's own converter, and they are not
  simply the binary order — MAG1B prints `GRACE_id` before `time_ref`,
  and AHK1B writes `status` as a bit string. `'ColumnNames'` overrides
  the layout, and *that* still warns, because those names are the
  caller's claim about the file
- `gracefoReading.readEventList` — the official TN-01 sequence-of-events
  and TN-01a spacecraft-events lists as an event table with provenance
  (line number, source, and the operators' text kept verbatim)
- `gracefoReading.version` — programmatic version checks

## Verify the installation

```matlab
results = runtests('tests');  table(results)
```

`tests/testRealData.m` runs against real PO.DAAC files placed in
`tests/realdata/`, or in the data pool named by the environment
variable `DATAPOOL` (set by the installer's `startup.m`; when it is
unset, `READING_DATA_POOL`, the older name, is read) — the **DATAPOOL root**, with the day
fixtures below it in `RawData\tests\realdata\` (see the README in
`tests/realdata/`). Tests for absent files are skipped automatically.

Which third-party files those tests look for in the pool, and where each
comes from, is listed in `tests/data/SOURCES.json` (`schema` 1; per source
`id`, `url`, `files`, `MB`, `sha256`, `licence`, `licenceText`,
`description`; `files` relative to `<DATAPOOL>\RawData\tests\realdata\`).
toolboxInstaller's *Get test data* reads that list from this repository,
and `tests/testDataSources.m` fails when a test looks for a pool file the
list does not name, or the list names a file no test reads.

## Documentation

- `doc gracefoReading.readL1b` — MATLAB-style HTML reference pages
  (also directly in `html/`)
- `doc/gracefoReading_UserManual.pdf` — full manual
- Both are generated from **one** source, `docsrc/functionSpecs.json`
  (`python3 docsrc/generate_docs.py`), and cross-checked against the
  code by `tests/testDocConsistency.m`.
- HTML pages live in `html/` at the toolbox root (referenced by
  `info.xml` for the doc browser).

## Layout

```
setupGraceFOReading.m    add toolbox root to path (tests/ stays off the path)
ci/runCI.m               CI entry point: all suites + JUnit/coverage reports
docs/CI_SETUP.md         runner setup, licensing, troubleshooting
doc/                     gracefoReading_Guide.pdf (user guide + API reference)
+gracefoReading/         namespace package (public API + internal helpers)
html/                    generated HTML documentation
tests/                   matlab.unittest suites (+ realdata/, python_reference/)
examples/                demoGracefoReading.m (executable tour)
docsrc/                  documentation single source + generator
buildfile.m              buildtool tasks: test / docs / check / release
.github/workflows/       CI: MATLAB suites on Linux + Windows
```

Distribution is via zip / git (no .mltbx by design — see HANDOVER.md).
