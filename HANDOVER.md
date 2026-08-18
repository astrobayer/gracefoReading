# HANDOVER — gracefoReading v2.0.0 (2026-08-01)

Developed with Claude Sonnet 5 (Anthropic). This document records
status, design decisions, and open topics for the next session.

## Status

- Complete v2.0.0 rewrite in namespace `+gracefoReading`; v1.0.0
  (`graceReading`, function `readGraceFoL1b`) is superseded.
- **Motivating finding**: v1 failed on *every* real RL04 file — the
  real header declaration style (`variables:` with `- varname:`)
  differs from the invented style v1 parsed. Real-data validation was
  therefore made the backbone of v2.
- Parsing rules were first implemented and verified in Python
  (`tests/python_reference/validate_realdata.py`) against the seven
  real 2020-01-01 RL04 files (ACT1B, GNV1B, SCA1B, THR1B, KBR1B,
  LRI1B, MAS1B): record counts vs. headers, first/last epochs,
  column classification, MAS1B prod_flag expansion — all consistent.
  The MATLAB acceptance suite `tests/testRealData.m` hardcodes those
  independently derived values as regression truth.
- MATLAB tests were **not executed here** (no MATLAB in this
  environment — the reason .mltbx packaging was dropped). The suites
  are written against the verified Python reference; run
  `runtests('tests')` in MATLAB and report failures verbatim.

## Key format knowledge (from real files)

- Header: `variables:` list, entries `- varname:` with indented
  attributes (`units`, `comment`, `long_name`, `flag_meanings`, ...).
- `time_frac` unit is **microseconds** in THR1B/MAS1B → scale 1e-6.
- `qualflg`/`prod_flag` are 8-char bit strings; bit 0 = rightmost.
- MAS1B: variable-length records; declared conditional columns appear
  per record iff the matching prod_flag bit is set (ascending bit
  order left→right in the data line).
- `units: char` marks character columns (GRACEFO_id, time_ref,
  coord_ref); `sca_id` is numeric but auxiliary (`*_id` rule);
  `qual_rss` (SCA1B) is a genuine observation.

## v2.2.0 additions (this session)

- Batch layer: findL1bFiles + findGaps + CacheDir (SHA-256 content-
  hashed parse cache) + Multi monotonicity warning.
- 'TimeFormat',"gpsns": exact int64 GPS nanoseconds (integer
  arithmetic in internal.parseDataSection; never round-trips through
  double, which cannot represent 2020-era GPS-ns values exactly).
- 'QualityBitMask' selective filtering.
- Classic GRACE support (EXPERIMENTAL): internal.parseClassicProduct
  with built-in layouts for ACC1B/SCA1B/KBR1B/GNV1B; every classic
  read warns classicExperimental until validated.
- readGroopsInstrument (writer counterpart, roundtrip-tested).
- buildfile.m, GitHub Actions CI (Linux+Windows), examples/ demo.
- readL1b refactored: dispatcher + internal parse core; caching keys
  include toolbox version, so caches self-invalidate on upgrade.

## v2.3.0 additions (documentation, CI)

- Help text is now the single source of truth for documentation:
  docsrc/helpparse.py parses the blocks, generate_html.py and
  generate_guide.py render from that parse. Editing html/ or the PDF by
  hand has no effect; edit the .m help and run
  python3 docsrc/generate_docs.py.
- docsrc/auditHelp.py enforces the standard (sections, typed/sized
  arguments, stated defaults, accuracy statements, authorship). It runs
  in CI and is mirrored by four tests in testDocConsistency.
- ci/runCI.m is the one command for tests everywhere; docs/CI_SETUP.md
  documents runner installation and licence handling.
- doc/gracefoReading_Guide.pdf replaces the old UserManual PDF.

## Open topics

1. **Run the MATLAB test suites** (user side): `runtests('tests')` —
   now including testBatchTools and the extended testReadL1b (gpsns,
   bit mask, cache, classic). The cache and classic paths are new
   MATLAB code not executed in this sandbox.
1b. **Classic GRACE layouts are ASSUMED, not validated.** The built-in
   ACC1B/SCA1B/KBR1B/GNV1B column tables come from the GRACE L1B
   handbook from memory. Before scientific use: obtain one real
   classic file per product and either confirm the layouts (then add
   the files to tests/realdata/ and remove the experimental warning)
   or correct the tables in internal/parseClassicProduct.m. The v1
   lesson applies: invented formats fail on real files. Classic
   qualflg may also be decimal rather than an 8-char bit string —
   verify.
1c. **CI**: .github/workflows/ci.yml is ready but only runs once the
   toolbox lives in a GitHub repository (matlab-actions requires a
   licensed runner setup or the free MATLAB on GitHub-hosted runners
   for public repos).
   Expected: all pass; testRealData skips files absent from
   tests/realdata/ (MAS1B + THR1B ship with the zip; copy the five
   larger products in as available).
2. **GROOPS export header conventions**: `writeGroopsInstrument`
   writes `groops instrument version=<N>` + two-integer type/dim
   header + lone record count + decimal-MJD records, per the known
   structure. Verify version tag and type codes against the GROOPS
   release in use before production.
3. **Performance**: line-wise regexp tokenization handles an 86400-line
   day file acceptably but has headroom (typed textscan fast path for
   fixed-layout products). Profile in MATLAB before optimizing.
4. Binary L1B format remains unsupported (explicit error).
5. If PO.DAAC releases (RL05+) change header conventions, extend
   `+gracefoReading/+internal/parseHeaderVariables.m` — and add the new files to
   tests/realdata/.

## Conventions

- camelCase; `arguments` blocks; error ids `gracefoReading:<fn>:<id>`;
  metadata block (Toolbox/Created/Author) in every file's help text.
- Docs: edit `docsrc/functionSpecs.json`, regenerate with
  `python3 docsrc/generate_docs.py`; never edit `html/` or the
  PDF by hand. `tests/testDocConsistency.m` enforces code↔docs sync.
- Real-data expectations must be derived independently (Python
  reference) before being hardcoded into MATLAB tests.
