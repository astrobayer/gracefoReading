# HANDOVER — AccelCal v3.0 Redesign
### Expert panel review of AccelBiasScaleToolbox v2.5.0 and work-package plan for its successor

**Date:** 2026-07-22 | **Prepared with:** Claude Opus 4.8 (Anthropic)
**Reviewed artifact:** AccelBiasScaleToolbox v2.5.0 (incl. graceReading v1.0.0 link)
**Panel:**
- **Expert A** — GRACE/GRACE-FO Level-1B data processing (ACC1B/ACT1B/SCA1B/THR1B, CRN filtering, time systems)
- **Expert B** — Satellite dynamics and non-gravitational force modelling (drag, SRP, accelerometer physics)
- **Expert C** — Estimation theory, statistics, and scientific software architecture

**How to use this document.** Part I is the review: what is wrong, what is merely
different, and which deviations are defensible. Part II is the redesign: the logic of
the new toolbox, then its function set. Part III contains the global conventions every
implementation chat must receive. Part IV is the work-package list: one self-contained
prompt per unit, in dependency order, each with test and documentation requirements.
Work through Part IV top to bottom; the checklist in Part V tracks progress.

---

# PART I — PANEL REVIEW

## I.1 What the toolbox gets right (keep these)

The panel agrees the toolbox's four core insights are correct, well-motivated, and
empirically demonstrated, and they must survive into v3 unchanged in substance:

1. **Exact ATBD CRN kernel, normalised at f0 = 0.37 mHz, DC gain 1.0004533 kept.**
   The help text of `crnFilter` is exemplary: it names the two traps (renormalising to
   unit DC → +453 ppm scale error; approximate kernels → percent-level bias that
   mimics physics) with measured numbers. This is the scientific heart of the toolbox.
2. **Filter consistency including the bias basis** (`[H·B, H·a]`, knot-spacing
   identifiability floor at the kernel span). Correct and subtle; rarely done right.
3. **Observability gating and regressor demeaning** before any scale is reported.
   The corr(bias, scale) = −1 collapse on quiet arcs is real; gating is the right cure.
4. **Honest uncertainty under coloured residuals**: AR-whitened feasible GLS,
   moving-block bootstrap, blocked cross-validation instead of AIC/BIC. The measured
   5–14× naive-sigma optimism justifies all of it.
5. **Independent Python cross-validation (`refval/`)** as the numerical ground truth.
   This dual-implementation discipline is best practice and is retained as a hard
   requirement in v3 (see test strategy, Part IV).

## I.2 Design flaws (must fix)

| # | Finding | Expert | Severity | Detail |
|---|---------|:------:|:--------:|--------|
| F1 | **The headline estimator bypasses the toolbox's own estimation machinery.** Inside `analyzeAccScaleArc`, the whole-arc scales come from `fitDiagonal`/`fitFull`, which are plain `X\y` OLS — no robustness, no AR whitening, no penalty — while the toolbox's documentation preaches `glsLinearFit` for exactly this. The bootstrap rescues the *CI*, but the *point estimate* the user quotes is produced by a second, duplicated, inferior code path. | C | **Critical** | One estimator core. Every path that produces a quotable number goes through it. |
| F2 | **Silent time-lag "correction" by cross-correlation over ±1 revolution.** `estimateLag` searches ±Torb and silently shifts the model by up to a full orbit. (a) With near-periodic 1/rev signals this can lock onto the wrong lobe. (b) A real physical phase lag (thermosphere density response lags the driver) is *absorbed* instead of *reported* — the diagnostic the toolbox exists to produce is partially destroyed by its own preprocessing. (c) It papers over the absent explicit time-system model. | A+B | **Critical** | v3: metadata-driven time conversion (GPS/UTC/TAI/TT, leap-second table); cross-correlation demoted to a *verification diagnostic* with a hard bound (±60 s), never a silent correction above a threshold. |
| F3 | **Quality flags are read but never used.** `readGraceFoL1b` dutifully exposes `qualflg`; `estimateNoiseModel` even has an `ExcludeMask` argument with an excellent essay on ACC1B fill data — but `analyzeAccScaleArc` never decodes `qualflg` bits nor populates any mask. Filled/interpolated ACC1B samples flow into every fit. Thruster firings (THR1B) are never masked at all. | A | **Critical** | v3: a first-class mask module (qualflg bit decoding per the L1B handbook, THR1B windows with pre/post margins, penumbra transitions, outliers, CRN edges) combined into one sample-weight vector consumed by every fit. |
| F4 | **Two overlapping orchestrators** (`analyzeAccArc` vs `analyzeAccScaleArc`) with diverging internal code paths (different fit routines, different flags). Superfluous duplication; they have already drifted (see F1). | C | High | One pipeline, one entry, array-input is just a constructor variant of the same Arc container. |
| F5 | **Silent last-resort column guessing.** `findLinAccCols` falls back to "first three columns" if name matching fails. A mislabeled product would be fit without complaint. | A | High | Fail loudly. Product dictionaries per L1B type; explicit override only. |
| F6 | **No data container.** Bare `(t, Y1, Y2)` triples are passed positionally through ~15 functions; units, frame, time system, mask, and provenance exist only as conventions in help text. This is the root cause of F2/F3 class bugs. | C | High | An `Arc` value type with schema validation is the backbone of v3. |
| F7 | **API inconsistency**: `arguments` blocks (readers) vs `inputParser` (everything else); `char` vs `string`; plot/print/save side effects inside science functions; `result` structs whose field sets differ between the two orchestrators. | C | Medium | One convention (arguments blocks, string, pure science core, side-effect functions separate). |
| F8 | **Vendored reader duplication** caused a real divergence bug (the `u{1}{1}` units crash, fixed in v2.5.0). The architectural lesson: one authoritative implementation, dependency resolved at setup. | A+C | Medium (fixed) | v3 keeps `graceReading` as the single L1B reading dependency; no vendored copies. |

## I.3 Approximations and deviations from best methods — with verdicts

| # | Approximation / deviation | Best-method reference | Panel verdict |
|---|---------------------------|----------------------|---------------|
| D1 | **AR(p) (Yule–Walker, AIC-selected) noise model** for residuals that are closer to power-law (1/f) + white. | Frequency-domain (Whittle) ML with a parametric PSD (power-law + white), as in Hector-class GNSS/geodetic time-series tools; Percival & Walden for estimation theory. | **Defensible as default** — AR(p) whitening is cheap, stable, and the block bootstrap is kept as the assumption-light check. **But** v3 must offer a PSD-model option, because AR(p) under-corrects at the lowest frequencies where the scale information lives on multi-day arcs. |
| D2 | **GCV for the bias-spline λ** while simultaneously (and correctly) arguing AIC/BIC/GCV are unreliable under coloured noise. Internally inconsistent: model *order* is chosen by blocked CV, model *smoothness* by GCV. | REML with the AR/PSD noise model, or blocked-CV on the λ grid. | **Not justified.** Same failure mode the toolbox documents for AIC applies to GCV (undersmoothing). v3: λ by blocked CV by default; REML as option. |
| D3 | **Feasible GLS with fixed NumIter = 2**, no convergence criterion. | Iterate to tolerance on φ (or on coef), cap iterations. | Minor; fix in v3 core solver (converge on ‖Δφ‖, max 10). |
| D4 | **Errors-in-variables ignored.** The regressor (modelled acceleration) carries the *dominant* error (density model, 3–4 % residual variance on real data); OLS slope is attenuated toward zero by var(model error)/var(model signal). The toolbox's own headline finding — scale anti-correlates with drag — is partly the *signature of EIV attenuation varying with signal amplitude*. | Total least squares / Deming regression with an error-ratio prior; or state the estimand explicitly as "regression calibration w.r.t. this model". | **Partially justified**: for *calibration against a stated model* the regression direction is a legitimate convention. **Not acceptable silently.** v3: quantify the attenuation bound from the residual/model variance ratio, report it with every scale, and offer a TLS option so the drag-correlation diagnosis can be cross-checked against the EIV alternative. |
| D5 | **No quadratic accelerometer term.** SuperSTAR-class electrostatic accelerometers have a documented quadratic factor K2 (historically most relevant on the GRACE X axis); standard calibration parameterisations (cf. Bettadpur's a-priori bias/scale TN; Klinger & Mayer-Gürr 2016, Adv. Space Res.) at least consider it. | Include K2 per axis as an optional design column (`y2.^2`, demeaned), off by default, observability-gated like the scale. | Gap. Cheap to add in a design-matrix builder; v3 includes it. |
| D6 | **No once-per-rev empirical terms.** Classical GRACE processing co-estimates 1/rev sine/cosine per axis to absorb model error; the toolbox's spline bias partially overlaps but is less interpretable and competes differently with the scale. | Optional per-axis {sin, cos}(2π t/Torb) columns with the same filter treatment as the bias basis. | Deviation is *defensible* (the spline is more general) but the option costs nothing and aids comparison with legacy processing. Include, off by default. |
| D7 | **Drag correlation against total modelled magnitude**, not force constituents. SRP/albedo/thermal are folded into "dragMag", diluting the diagnostic. | Regress per-rev scale on per-constituent amplitudes (GROOPS can export constituents), plus β-angle/arg-lat from GNV1B. | Justified only as a first cut. v3: constituent-aware attribution; orbit geometry computed from GNV1B instead of user-supplied "Extra". |
| D8 | **`relRange = std/|mean|` observability metric** is scale-dependent and blows up for zero-mean regressors (handled by an Inf special case). | The variance-factor Ci(scale,scale) and bias–scale correlation already computed are the principled metrics. | Minor; keep both but gate on the principled ones. |
| D9 | **`pchip` everywhere for resampling.** Amplitude-preserving, good; but pchip is not band-limited interpolation, and lifting a 5–10 s model to 10 Hz with pchip before CRN filtering imprints small spectral colouration that the filter only partly removes. | Since the CRN passband is ≤ 0.0355 Hz and the model grid is ≥ 0.1 Hz Nyquist ≫ passband, the pchip error inside the band is negligible. | **Justified.** Document the argument once, centrally, with a measured bound (refval test), and stop re-litigating it in every help text. |
| D10 | **Edge handling by reflection padding** in `applyCrnFilter` ("approximated, not measured"). | NaN-marking + down-weighting via `flagEdgeEffects`. | Both exist; the *default* should be NaN/weight-zero for anything that feeds a fit, reflection only for plots. v3 makes that the contract. |
| D11 | **GRACE ATBD CRN parameters assumed for GRACE-FO** (Tf, Nc, NB unconfirmed against the GRACE-FO Level-1 handbook, JPL D-56935). Toolbox flags it honestly. | Verify once against the handbook; parameterise per mission. | Open scientific action item — carried into v3 as an explicit verification WP. |

## I.4 Superfluous paths and methods

- `fitDiagonal` / `fitFull` inside the orchestrator (see F1) — delete; the estimator core covers them.
- `analyzeAccArc` as a separate orchestration path (F4) — delete; array input becomes `Arc.fromArrays`.
- The **legacy `crnFilter(fs,'Cutoff',...)` shim** and its `legacyLowpass` builder exist only to serve `syntheticAccelPair` and one test. v3: the synthetic generator uses the real ATBD kernel; the shim dies.
- `obsAux.obsNames = obsAux.obsNames;` dead statement — symptom of F4-style drift.
- `heteroscedasticityCheck` as a standalone: fold into the preflight report; it is never actionable alone.
- Duplicate centred-convolution helpers (`centredConv` exists in both `applyCrnFilter` and `analyzeAccScaleArc`, and `centredFIRLocal` again in `accelBiasScaleModelFit`) — one utility.

## I.5 Limitations of the method (inherent, to be documented rather than "fixed")

1. **Bias/scale aliasing at low frequency is structural.** A slowly varying s(t) and a
   flexible b(t) compete for the same variance; the identifiability comes only from the
   prior "scale drifts slower than bias structure". v3 keeps the asymmetric-smoothness
   prior and *must always* report the s(t) uncertainty band, never the curve alone.
2. **One day cannot separate density-model error, Cd error, and sensor drift** (drag
   varies ~10 %, only with orbital phase). Multi-day + space-weather regression is the
   only route; this remains the toolbox's central workflow claim.
3. **Off-diagonal S over short arcs is collinearity-limited** (model axes correlated up
   to 0.61). Shear/misalignment from a single day is not trustworthy; v3 gates the full-S
   report on a VIF threshold.
4. **The fitted bias absorbs |H(0)| = 1.0004533** and the −Σ s·μ centering shift; it is a
   nuisance parameter comparable across runs only under identical conventions.
5. **EIV attenuation bound** (D4): with model-error variance ~3 % of model signal
   variance, the OLS scale is biased low by up to ~3 % in the worst spectral overlap
   case. The reported bound quantifies, not removes, this.
6. **Everything downstream trusts L1B time tags**; onboard-clock corrections (CLK1B)
   beyond what the L1 processor already applied are out of scope.

## I.6 Structural review

The flat `src/` with 40 functions has outgrown itself: reading, masking, filtering,
estimation, diagnostics, plotting, and persistence are interleaved at one level, and
the only structure is the Contents.m prose. The two orchestrators duplicate the
pipeline. Data flows as anonymous arrays, so every function re-documents the same
implicit contract (column meaning, time convention, units) — and two of them already
disagree in practice (F1). The test suite is strong on numerics, absent on contracts
(no test pins the *interface*), absent on performance. There is no parallelism at all,
although the problem is embarrassingly parallel along four independent axes (files,
axes, bootstrap replicates, arcs).

---

# PART II — THE REDESIGN: AccelCal v3.0

## II.1 Design principles

1. **One estimator core.** Every quotable number is produced by `accal.fit.solve`
   (weighted, penalised, robust, AR/PSD-whitened). No second path, ever (fixes F1).
2. **Data travels as an `Arc`.** A validated value object carrying time (canonical GPS
   seconds), observed/model series, per-sample weights/mask, frame + unit + time-system
   metadata, and accumulated provenance. Functions map Arc → Arc or Arc → result
   (fixes F2/F3/F6).
3. **Masks are first-class and additive.** qualflg bits, thruster windows, penumbra,
   outliers, CRN edges each contribute a named layer; the fit consumes the combined
   weight vector; the report says how much each layer removed (fixes F3).
4. **Time systems are metadata, conversions are explicit**, cross-correlation is a
   *check* with a ±60 s bound that warns and reports but never silently shifts beyond
   1 s (fixes F2).
5. **Side-effect-free science core.** Plot/print/save live in `+viz` and `+io.store`,
   taking result objects (fixes F7).
6. **Three interface levels, lean surface:**
   `accal.run(cfg)` (one call) → stage functions (`staticFit`, `timeVaryingFit`,
   `attribute`) → open low-level tools. ~28 public units total.
7. **Deterministic parallelism, opt-in.** `UseParallel = "auto"|"on"|"off"`;
   `gcp('nocreate')` only; identical results for any worker count via fixed RNG
   substreams per replicate/chunk.
8. **Dual-implementation validation stays.** Every numerical unit ships with a Python
   reference in `refval/` and a stored reference-value `.mat`/`.json` consumed by the
   precision tests.

## II.2 The workflow (pipeline logic)

```
                        ┌───────────────────────── accal.run(cfg) ─────────────────────────┐
                        │                                                                   │
 (1) INGEST             │  io.findL1bFiles(dateRange) → io.readL1bArc (parfor files)        │
                        │  io.readGroopsArc            → Arc_obs, Arc_mod                   │
                        │                                                                   │
 (2) TIMEBASE           │  time.toGps on both (explicit TimeSystem metadata; leap table);   │
                        │  time.checkAlignment: xcorr diagnostic ±60 s, warn>1 s, never     │
                        │  silently shift; shift only if cfg.AllowLagCorrection             │
                        │                                                                   │
 (3) MASK               │  mask.fromQualflg ⊕ mask.fromThrusters ⊕ mask.penumbra ⊕          │
                        │  mask.outliers ⊕ (later) mask.crnEdges  → Arc.weights             │
                        │                                                                   │
 (4) CONSISTENCY        │  frame.assertSrf (or frame.accToSrf); filt.crnKernel(mission);    │
                        │  filt.applyChain on the model (chunked/day, parfor, NaN edges);   │
                        │  align onto observed epochs; mask.crnEdges added                  │
                        │                                                                   │
 (5) PREFLIGHT (gate)   │  diag.observability per axis+window; noise verdict;               │
                        │  refuse/downgrade unidentifiable requests HERE, not after the fit │
                        │                                                                   │
 (6) FIT                │  fit.design (bias family ⊕ optional 1/rev ⊕ optional K2 ⊕ scale   │
                        │  mask diag/full) → fit.solve (ONE core: weighted+penalised+robust │
                        │  +AR/PSD-GLS; λ by blocked-CV/REML) → static S,b per axis          │
                        │  and/or fit.timeVarying s(t),b(t)                                 │
                        │                                                                   │
 (7) UNCERTAINTY        │  unc.bootstrap (moving-block, parfor replicates, substreamed RNG);│
                        │  EIV attenuation bound; blocked CV for model comparison           │
                        │                                                                   │
 (8) ATTRIBUTION        │  diag.perRev → diag.orbitGeometry(GNV1B) →                        │
                        │  diag.driverRegression (constituents + F10.7/Kp/β/arg-lat)        │
                        │                                                                   │
 (9) PERSIST + REPORT   │  Calibration object (apply()/invert(), full provenance) →         │
                        │  io.store; viz.report (figures + HTML summary)                    │
                        └───────────────────────────────────────────────────────────────────┘
```

Batch mode: `accal.runBatch(cfgArray)` runs (1)–(9) per arc under `parfor` — the
highest-leverage parallel axis for month/year campaigns.

## II.3 Data handling and performance decisions

- **Canonical time**: `int64` GPS nanoseconds since 2000-01-01T12:00:00 GPS inside
  `Arc` (lossless, comparison-safe); `[intMJD, sod]` and `datetime` as import/export
  views only. All v2 precision arguments (floor/mod arithmetic) are preserved by
  construction.
- **Chunked CRN filtering**: never lift a whole month to 10 Hz. Filter per UTC day
  with a kernel-half-span (704 samples) overlap; memory stays < ~100 MB per worker
  regardless of arc length; chunks are parfor-safe and bit-identical to unchunked.
- **Fast L1B parsing**: replace per-column `str2double`-on-cellstr with a single
  `sscanf`/`textscan` numeric block parse (measured 10–50× in comparable readers);
  parse target < 0.3 s per daily ACC1B file (see speed tests). File-level `parfor`
  in `readL1bArc`.
- **Bootstrap parallelism**: `parfor` over replicates; `RandStream('Threefry')`
  substream per replicate index → reproducible for any pool size.
- **Vectorised ACF** via FFT (`ifft(|fft|²)`) in the noise module.
- **No GPU**: problem sizes (≤ ~3 M × ≤ 40 design columns) do not justify it.

## II.4 The function set (what gets built)

Classes (3): `accal.Arc`, `accal.Calibration`, `accal.Config`.
Entry points (2): `accal.run`, `accal.runBatch`.

| Package | Public functions | Replaces / absorbs (v2) |
|---|---|---|
| `+io` | `findL1bFiles`, `readL1bArc`, `readGroopsArc`, `readIndices`, `store` | graceReading link, readGroopsInstrument, loadSpaceWeatherIndices, accelCalibrationIO |
| `+time` | `toGps`, `fromGps`, `leapSeconds`, `checkAlignment` | ad-hoc MJD math, estimateLag |
| `+mask` | `fromQualflg`, `fromThrusters`, `penumbra`, `outliers`, `crnEdges`, `combine` | (new), qualityCheck (partly), flagEdgeEffects |
| `+filt` | `crnKernel`, `applyChain`, `consistency` | crnFilter (ATBD path only), applyCrnFilter, filterConsistency |
| `+frame` | `accToSrf`, `checkScaleMatrix` | accFrameToSRF |
| `+noise` | `psdModel`, `arModel`, `whiten` | estimateNoiseModel, prewhitenSeries, lombScarglePSD |
| `+fit` | `design`, `solve`, `staticFit`, `timeVaryingFit`, `compare` | buildBiasDesign+bsplineBasis+diffPenaltyMatrix (design), glsLinearFit+robustLinearFit (solve), accelBiasScaleModelFit, accelTimeVaryingScaleFit, accelBiasScaleModelCompare+gcvSelectLambda |
| `+unc` | `bootstrap`, `crossval`, `eivBound` | blockBootstrap, blockedCrossVal, (new) |
| `+diag` | `observability`, `preflight`, `perRev`, `orbitGeometry`, `driverRegression`, `decomposeScale` | scaleObservability, accelSeriesPreflight+heteroscedasticityCheck+crossCorrLag+slidingWindowFit, perRevolution (freed from orchestrator), (new), scaleFactorDiagnostics, decomposeScaleMatrix |
| `+viz` | `preflight`, `calibration`, `attribution`, `report` | all plot* functions |
| `+util` | `parallelPool`, `syntheticPair`, `validate` | (new), syntheticAccelPair, (new) |

28 functions + 3 classes + 2 entries. Everything else from v2 is retired.

---

# PART III — GLOBAL CONVENTIONS (paste into every implementation chat)

Every work-package prompt in Part IV begins with "Apply the COMMON PREAMBLE."
That means: copy the following block verbatim into the implementation chat *before*
the WP prompt. It is the contract that keeps 20+ independent chats consistent.

```text
============================ COMMON PREAMBLE (v3.0) ============================
You are implementing one unit of "AccelCal v3.0", a MATLAB toolbox for calibrating
GRACE-FO accelerometer data (ACC1B/ACT1B) against modelled non-gravitational
forces. Obey ALL of the following conventions exactly.

LANGUAGE / STYLE
- MATLAB R2022b+ baseline. Use `arguments` blocks for ALL input validation
  (no inputParser). Use string scalars for text options, char only where MATLAB
  APIs require it. camelCase functions, PascalCase classes, package namespaces
  (+accal/+<pkg>). One public function per file; local helpers below it.
- Pure science core: NO plotting, NO printing (except a Verbose option that is
  false by default), NO file writing unless the unit's job is I/O.
- Errors: error('accal:<pkg>:<function>:<CamelCaseReason>', ...) with an
  actionable message. Warnings same scheme. Never silently guess: if an input
  is ambiguous, error with the candidates listed.
- ASCII-only source files.

DATA CONVENTIONS
- Canonical time: int64 GPS nanoseconds since 2000-01-01T12:00:00 GPS
  ("gpsns"). No leap seconds in this scale. Conversions only via +accal/+time.
- Acceleration unit: m/s^2. Frame: SRF (x along-track, y cross-track,
  z radial-ish per GRACE-FO convention), asserted via Arc metadata.
- Arc object (assume it exists per its WP): value class with properties
  t (Nx1 int64 gpsns), obs (NxM double), model (NxM double or []),
  weights (Nx1 double in [0,1]), maskLayers (struct of named Nx1 logicals),
  meta (struct: frame, units, timeSystemSource, mission, satellite, obsNames),
  provenance (struct array, append-only). Methods used by other units:
  Arc.fromArrays, Arc.nSamples, Arc.seconds (double seconds from arc start),
  Arc.validate, Arc.withWeights, Arc.appendProvenance(step, info).
- Weights semantics: 0 = excluded, 1 = full; fits multiply rows by sqrt(w).

HELP-TEXT TEMPLATE (mandatory, in this order)
  %FUNCTIONNAME  One-line summary.
  %   Extended description: what, why, and the method with citations.
  %   INPUT  (name - type, size, description; name-value args listed with
  %           defaults and valid ranges)
  %   OUTPUT (field-by-field for structs: type, size, description)
  %   ERRORS (every error ID this function can raise, with trigger)
  %   EXAMPLE (at least one runnable example)
  %   REFERENCES (papers/documents with full citation)
  %   See also <RELATED FUNCTIONS>
  %
  %   Toolbox:  AccelCal v3.0
  %   Created:  <date> | Author: Developed with <Claude version> (Anthropic)

TESTS (mandatory, delivered with the unit)
- File tests/<pkg>/test_<function>.m, classdef matlab.unittest.TestCase.
- THREE mandatory groups, tagged via TestTags:
  (1) 'contract'  - interface pinning: argument validation raises the documented
      error IDs; output struct has EXACTLY the documented fields (verifyEqual on
      sorted fieldnames); size/type of every output; default behaviour.
  (2) 'precision' - numerical correctness against stored reference values in
      refval/<function>_ref.json (you also write the small Python script
      refval/<function>_ref.py that generates it with numpy/scipy only).
      Use verifyEqual with explicit AbsTol/RelTol stated in a comment WHY.
  (3) 'speed'     - a timing budget test using timeit on a documented workload;
      assert time < budget * 3 (3x slack for machine variance) and record the
      measured time with log(). State the workload and budget in the test help.
- Tests are self-contained (temp dirs via tempname, addTeardown cleanup,
  rng(42,'twister') where randomness is used). No network, no toolbox deps
  beyond MATLAB + (optionally) Parallel Computing Toolbox guarded by
  canUseParallelPool checks.

DOCUMENTATION (mandatory, delivered with the unit)
- The help text above IS the reference doc; additionally write
  doc/<pkg>.<function>.html following the house style (simple standalone HTML,
  sections: Syntax, Description, Input Arguments table, Output Arguments table,
  Examples, References, See Also). Link relative to index.html.

DEFINITION OF DONE for every WP
  [ ] function file(s) with full template help
  [ ] test class with contract+precision+speed groups, all passing
  [ ] refval Python generator + committed reference JSON
  [ ] HTML doc page
  [ ] entry added to +accal/Contents.m and doc/helptoc.xml (state the lines)
================================================================================
```

**Mission-critical scientific constants** (also give to any WP that needs them):
GPS−UTC = 18 s (since 2017-01-01); TAI−GPS = 19 s; TT−TAI = 32.184 s.
CRN ACC preset per GRACE ATBD (JPL D-27672 App. B): fs = 10 Hz, Nc = 7,
Tf = 140.7 s → Nf = 1407, NB = round(B·Tf) = 5, f0 = 0.37 mHz, DC gain
1.0004533 (normalised at f0, NOT at DC). GRACE-FO parameters to be verified
against the GRACE-FO Level-1 Handbook (JPL D-56935) in WP-10.

---

# PART IV — WORK PACKAGES

Order = dependency order. "Needs:" lists WPs that must exist first (their code can be
pasted or summarised into the chat). Budgets refer to the speed tests.

## WP-00 — Repository skeleton and conventions harness
**Needs:** —
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Create the AccelCal v3.0 repository skeleton: folders +accal (with +io +time
+mask +filt +frame +noise +fit +unc +diag +viz +util), tests/<same tree>,
refval/, doc/, benchmarks/. Write:
1. setupAccelCal.m (root): adds toolbox + tests to path, links the external
   graceReading toolbox exactly like the v2.5 linkGraceReading contract
   (resolution order: explicit arg -> setpref accal/graceReadingRoot -> env
   GRACEREADING_ROOT -> path -> sibling search; version >= 1.0.0; functional
   smoke test on a units:-bearing file; returns an info struct), errors
   accal:setup:graceReadingMissing if absent (NO vendored fallback in v3).
2. runAllTests.m: runs the suite by TestTag ('contract','precision','speed'
   selectable), prints a per-tag summary table.
3. +accal/Contents.m and doc/index.html + doc/helptoc.xml stubs listing the
   planned function set from the handover (copy the table).
4. A conventions self-test tests/test_conventions.m ('contract') that walks all
   +accal source files and asserts: ASCII-only, presence of the help-template
   sections (INPUT, OUTPUT, ERRORS, EXAMPLE, See also), arguments-block usage
   (regex '^\s*arguments' within first 80 lines of each public function), and
   error-ID prefix 'accal:'.
Definition of Done per the preamble (refval not applicable for WP-00; say so).
```

## WP-01 — `accal.Arc` (the data container)
**Needs:** WP-00
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Implement the value class accal.Arc exactly as specified there, plus:
- Constructors: Arc.fromArrays(t, obs, Name-Value: Model, Weights, Meta) where
  t may be int64 gpsns, [intMJD sod] Nx2 double, or datetime (converted via
  stub calls into +accal/+time — for now implement the [MJD,sod]->gpsns and
  datetime->gpsns conversions locally and mark them for replacement by WP-02;
  keep exact integer arithmetic: gpsns = ((mjd-51544)*86400 - 43200)*1e9
  + round(sod*1e9), computed in int64 without double round-trip for the day
  part).
- validate(): monotone strictly increasing t, size consistency of obs/model/
  weights/mask layers, weights in [0,1], meta.frame member of ["SRF","ACC",
  "unknown"]; error IDs accal:Arc:<Reason>.
- withWeights(w, layerName): returns a NEW Arc with the named logical layer
  stored and weights = min(existing, double(~layer)) — layers only ever remove.
- crop(t0,t1), cat(a,b) (contiguity check, provenance merge), seconds(),
  nSamples(), appendProvenance(step, infoStruct) adding a timestamped entry.
- disp override: one compact block (span, N, weight fraction, layer names).
Precision tests must pin the int64 time conversion to the nanosecond against
refval (Python: exact integer arithmetic), including sod values like
86399.999999999 and the 43200 s epoch offset. Speed budget: fromArrays +
validate on N=1e6 in < 0.15 s.
```

## WP-02 — `+time`: `toGps`, `fromGps`, `leapSeconds`, `checkAlignment`
**Needs:** WP-01
**Prompt:**
```text
Apply the COMMON PREAMBLE (constants block included).
Implement +accal/+time:
1. leapSeconds(): returns the built-in TAI-UTC step table (1972..2017-01-01,
   37 s) as a struct array {mjdUtc, taiMinusUtc}; option 'File' to load a
   user-supplied IERS-format table; document that post-2017 steps require a
   file update and add a warning when converting dates > table end + 1 year.
2. toGps(t, fromSystem): t as [MJD sod] or datetime; fromSystem in
   ["GPS","UTC","TAI","TT"]; returns int64 gpsns. fromGps(gpsns, toSystem)
   inverse, plus 'Format' option ("mjdsod"|"datetime"). Exact integer path for
   GPS; leap-second application at the correct UTC day boundaries (test the
   2016-12-31 23:59:60 vicinity behaviour: document that leap-second instants
   themselves are not representable and are rejected with
   accal:time:toGps:LeapSecondInstant).
3. checkAlignment(arcObs, arcMod, Name-Value 'MaxLag' (default 60 s),
   'OrbitPeriod'): cross-correlates AC-coupled along-track on a 1 s grid over
   +/-MaxLag ONLY, returns struct {lagSec, corrPeak, corrCurve, verdict}.
   verdict: "aligned" (|lag|<=1 s), "smallOffset" (warn, id
   accal:time:checkAlignment:Offset), "gross" (>0.5*MaxLag: error-level
   warning telling the user to fix time systems; NEVER apply a shift).
   This function only diagnoses; shifting is the caller's explicit decision.
Precision: leap-second table values pinned; toGps/fromGps round-trip exact for
1e5 random epochs (int64 equality). checkAlignment recovers an injected 7.0 s
shift on a synthetic 1/rev signal to +/-0.5 s. Speed: toGps 1e6 epochs <0.1 s.
```

## WP-03 — `+io`: `findL1bFiles`, `readL1bArc`
**Needs:** WP-01, WP-02; external graceReading (its readGraceFoL1b contract:
`[time,obs,aux] = readGraceFoL1b(file)`, time = [intMJD sod] GPS, aux.obsNames,
aux.qualflg, aux.variableUnits).
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Implement:
1. findL1bFiles(rootDir, product, dateRange, Name-Value 'Satellite' ("C"|"D"),
   'Version'): discovers GRACE-FO L1B ASCII files (plain or .gz) matching the
   official naming convention <PROD>1B_<YYYY-MM-DD>_<SAT>_<VV>.txt[.gz] under
   rootDir (recursive), returns a sorted string array + a table of parsed
   metadata; errors accal:io:findL1bFiles:MissingDays listing absent dates
   unless 'AllowGaps' is true. For product "ACC" on satellite "D", if ACT1B
   files exist for the same dates, prefer them and record the substitution in
   the metadata table (GRACE-FO D accelerometer degradation -> ACT1B transplant
   product is the standard observation; cite the GRACE-FO Level-1 handbook and
   the JPL ACT1B technical note in REFERENCES).
2. readL1bArc(files, Name-Value 'UseParallel' ("auto")): calls the EXTERNAL
   graceReading readGraceFoL1b per file inside parfor when a pool exists and
   UseParallel allows (util.parallelPool contract: never create a pool
   implicitly on "auto"); verifies per-file obsNames identity; concatenates
   with day-boundary continuity checks (duplicate epoch at boundary -> keep
   first, warn); converts [MJD,sod] to gpsns via +time; extracts the three
   linear-acceleration columns by EXPLICIT product dictionary
   (ACC1B/ACT1B: lin_accl_x/y/z) — if not all three found, ERROR
   accal:io:readL1bArc:ColumnsNotFound listing available names (NO positional
   fallback); stores qualflg raw uint into Arc.meta.qualflg; returns an
   accal.Arc with frame "ACC", provenance entries per file.
Precision: build synthetic 2-day files (with units: headers, qualflg, one
duplicated boundary epoch) and pin the concatenated arc numerically; parallel
and serial paths bit-identical. Speed: parse one synthetic 86400-line file
< 0.5 s; state that the target with real files is < 0.3 s via block parsing
and, if the external reader is slower, wrap-time is measured excluding it.
```

## WP-04 — `+io`: `readGroopsArc`, `readIndices`
**Needs:** WP-01, WP-02
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Implement:
1. readGroopsArc(files, Name-Value 'TimeSystem' (default "GPS", member
   ["GPS","UTC","TT"]), 'Constituent' (string, default "total")): reads GROOPS
   instrument-format ASCII files (port the v2 readGroopsInstrument parsing
   contract: 'groops instrument version=...' header line, '# <TYPE>' type
   line, count line, whitespace numeric records, MJD time column) into an
   accal.Arc (model in .obs, meta.kind="model", meta.constituent set).
   Multi-file: concatenate with continuity checks as in WP-03. The declared
   TimeSystem is CONVERTED to gpsns via +time — no day-structure guessing.
   Support reading a SET of constituent files (drag, srp, albedo, thermal)
   into one Arc with M = 3*K columns and meta.constituentNames, so the
   attribution stage can regress per constituent.
2. readIndices(file, Name-Value 'Source' ("GFZ")): port the v2
   loadSpaceWeatherIndices GFZ combined-file parsing (Kp/ap/Ap/SN/F10.7 obs+
   adj, daily) into a timetable keyed by UTC date, plus interpolation helper
   onto arbitrary gpsns epochs (previous-day for daily indices, documented).
Precision: synthetic GROOPS files incl. one with declared UTC time -> pin the
18 s conversion; GFZ sample lines from the real format pinned. Speed: 1e5
GROOPS records < 0.3 s.
```

## WP-05 — `+util`: `parallelPool`, `validate`
**Needs:** WP-00
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Implement:
1. parallelPool(mode): mode "auto"|"on"|"off" -> struct {useParfor(logical),
   nWorkers}. Rules: "off" -> false. "auto" -> true iff Parallel Computing
   Toolbox is installed AND a pool already exists (gcp('nocreate')); NEVER
   starts a pool. "on" -> starts default pool if licensed, else warning
   accal:util:parallelPool:Unavailable and serial. Document the project rule:
   all parfor loops must produce results independent of nWorkers (substreamed
   RNG, order-independent reductions).
2. validate: a small library of shared validators used in arguments blocks
   (mustBeArc, mustBeMonotoneTime, mustBeWeights, mustBeTimeSystem, ...), each
   raising accal:util:validate:<Reason>.
Tests: contract-only for parallelPool behaviour matrix (mock via
canUseParallelPool where possible, skip-with-assumption when PCT absent);
validators pinned by error IDs. Speed test: trivial (<1 ms) — include anyway
to exercise the harness.
```

## WP-06 — `+mask`: `fromQualflg`, `fromThrusters`, `penumbra`, `outliers`, `combine`
**Needs:** WP-01, WP-03 (qualflg in meta), WP-04
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Implement the mask layer family. Each returns an Nx1 logical (true = REMOVE)
plus an info struct {nRemoved, fraction, params}; accal.mask.combine(arc,
layer1, name1, ...) applies them via Arc.withWeights and appends provenance.
1. fromQualflg(arc, Name-Value 'Bits'): decode the ACC1B/ACT1B qualflg BITS per
   the GRACE-FO Level-1 handbook (JPL D-56935) — implement the bit table as a
   named constant with a source comment per bit; DEFAULT removes the
   fill/interpolated-data bit(s); document clearly that bit semantics must be
   verified against the handbook edition in use and provide 'Bits' override.
2. fromThrusters(arc, thrArcOrTimes, Name-Value 'PreMargin' (5 s),
   'PostMargin' (30 s)): removes samples within margins of thruster firing
   epochs (accepts a THR1B arc read via readL1bArc with product dict THR1B, or
   a plain gpsns vector). Justify margins in help (CRN span smearing).
3. penumbra(arc, sunFlagOrGeometry): removes eclipse-transition windows
   (accepts a precomputed shadow flag vector or the diag.orbitGeometry output);
   margin +/-60 s, name-value.
4. outliers(arc, Name-Value 'Method' ("hampel"), 'Window' (601), 'NSigma' (6)):
   per-axis Hampel filter on the observed series; conservative default.
Precision: synthetic arcs with planted flags/firings/spikes -> exact index
sets pinned. Speed: outliers on 1e6x3 < 1.5 s.
```

## WP-07 — `+noise`: `psdModel`, `arModel`, `whiten`
**Needs:** WP-00
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Implement the noise family (plain numeric API: works on residual vectors, no
Arc dependency):
1. arModel(r, Name-Value 'MaxOrder' (10), 'Order' ([]), 'ExcludeMask'):
   port the v2 estimateNoiseModel contract (Yule-Walker, AIC order selection,
   nEff via truncated ACF sum, verdict strings) but compute the ACF via FFT
   (ifft(abs(fft(x,2^nextpow2(2N)))).^2 real part, normalised) — pin numerical
   identity to the direct O(N*lags) sum in a precision test.
2. psdModel(r, dt, Name-Value 'Model' ("powerlaw+white")): Whittle-likelihood
   fit of S(f) = P0*(f/f0)^alpha + Pw on the periodogram (exclude f=0; document
   estimator bias and the standard log-periodogram correction you apply);
   returns {alpha, P0, Pw, logL, f, Sfit}. Cite Percival & Walden. This is the
   D1 upgrade path: more faithful than AR(p) at the lowest frequencies.
3. whiten(X, model): applies the AR filter (port prewhitenSeries semantics:
   output length N-p, filter both regressors and response identically) OR, for
   a psdModel input, frequency-domain whitening by 1/sqrt(Sfit) with explicit
   tapering (Tukey 0.1) — document the edge cost.
Precision: AR(2) phi=[0.75,-0.20] recovery to 0.02 abs (matches the v2 refval
experiment); powerlaw fit on synthetic flicker+white (generated in the Python
refval via spectral synthesis, seed fixed) alpha to +/-0.15. Speed: arModel on
N=1e6 < 0.5 s (FFT ACF is the point).
```

## WP-08 — `+fit`: `design`
**Needs:** WP-01
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Implement accal.fit.design(arc, spec) building the per-axis design matrix and
penalty for the calibration model
  y_obs = B(t)*beta  +  [1/rev terms]  +  S*y_mod  +  K2*(y_mod.^2 demeaned)
spec fields (all validated):
  bias: struct('type', "constant"|"poly"|"pspline", 'order'/'numKnots',
        'placement' "uniform"|"quantile") — port the v2
        buildBiasDesign/bsplineBasis/diffPenaltyMatrix math (Cox-de Boor,
        second-difference penalty). Constant function MUST lie in every basis
        span (document why: centering-shift representability).
  onePerRev: logical (default false) -> adds sin/cos(2*pi*t/Torb) columns,
        Torb from spec.orbitPeriod (justification: legacy-processing
        comparability, handover D6).
  quad:  logical (default false) -> adds demeaned y_mod.^2 column
        (SuperSTAR K2 term, handover D5; cite Klinger & Mayer-Guerr 2016).
  scale: "diagonal"|"full"|logical mask MxM.
  filterKernel: [] or CRN kernel h -> ALL deterministic columns (bias basis,
        1/rev, quad regressor built from the FILTERED model) are convolved
        with h (centred, NaN edges); enforce the knot-spacing-vs-kernel-span
        identifiability warning from v2 verbatim in spirit
        (accal:fit:design:KnotsBelowFilterSpan).
Returns per-axis {X, colMap (typed index map), P (block penalty), info}.
Precision: pin B-spline values at knots and partition-of-unity to 1e-12;
penalty matrix eigenstructure; filtered-basis columns against refval conv.
Speed: N=1e5, 30-knot spline design < 0.2 s.
```

## WP-09 — `+fit`: `solve` (THE estimator core)
**Needs:** WP-05, WP-07, WP-08
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Implement accal.fit.solve(X, y, Name-Value ...) — the single estimator every
quotable number in AccelCal flows through (handover F1). Port and improve the
v2 glsLinearFit contract:
- Options: Weights (Nx1, folded as sqrt(w) row scaling BEFORE anything else),
  Robust (true, IRLS bisquare, tuning 4.685), Noise ("ar"|"psd"|"none",
  default "ar"), MaxAROrder (10), Penalty (pxp), Lambda (0),
  ConvergeTol (1e-8 on relative coef change), MaxIter (10).
- Algorithm: weighted (+penalized, + robust) initial fit; then ITERATED
  feasible GLS: estimate noise on residuals (arModel or psdModel), whiten X
  and y, refit; iterate to ConvergeTol or MaxIter (fixes v2's fixed
  NumIter=2, handover D3). Covariance on the whitened system with the
  penalized sandwich A^-1 (Xw'Xw) A^-1 * s2, edf = trace(hat). Keep the
  sigmaNaive/sigmaInflation diagnostic.
- Output struct EXACTLY: coef, cov, sigma, sigmaNaive, sigmaInflation, edf,
  residuals, fitted, RSS, R2, noise (model struct), nIter, converged, lambda.
Precision: (a) iid Gaussian synthetic -> coef equals backslash to 1e-12 and
sigma matches analytic OLS to 1e-10; (b) AR(1) rho=0.9 synthetic with known
slope -> coverage test: over 200 refval-generated realisations (Python
generates data + stores), the 1-sigma interval covers truth in 60-75% of
cases while naive sigma covers <40% (pin counts, fixed seeds); (c) penalized
fit edf pinned. Speed: N=1e5, p=35, Robust+AR < 2.5 s.
```

## WP-10 — `+filt`: `crnKernel`, `applyChain` (+ the GRACE-FO verification task)
**Needs:** WP-01, WP-05
**Prompt:**
```text
Apply the COMMON PREAMBLE (constants block included).
1. crnKernel(mission, product, Name-Value overrides fs/Nc/Tf/B/NB/f0): port the
   v2 ATBD implementation EXACTLY (H_k self-convolved Dirichlet construction,
   removable singularity Nf/Nc, f0-normalisation, derivative kernels, info
   struct incl. dcGain/gainAtF0/bandwidth). mission "GRACE"|"GRACE-FO"; for
   "GRACE-FO" load the SAME parameters but emit a one-time warning
   accal:filt:crnKernel:ParametersUnverified until the constant
   PARAMS_VERIFIED_GRACEFO (a named constant with a comment citing the
   GRACE-FO Level-1 Handbook JPL D-56935 section/table once checked) is set
   true. NO legacy Cutoff/NumConv shim (retired, handover I.4).
2. applyChain(arcModel, h, Name-Value 'Fs' (10), 'OutputEpochs' (gpsns vector),
   'Edge' ("nan")): the production chain — lift to Fs via pchip (document the
   D9 band-limit justification with the measured bound from refval), centred
   convolution, SAMPLE (never average) at OutputEpochs. CHUNKED per UTC day
   with (Nf-1)/2-sample overlap; parfor over chunks per util.parallelPool;
   REQUIRED precision test: chunked+parallel output bit-identical (verifyEqual
   exact) to unchunked serial on a 3-day synthetic. Default Edge "nan": edge
   samples are NaN and a mask layer spec {name "crnEdges"} is returned for
   mask.combine (handover D10 — reflection is NOT offered here; plots can pad
   themselves).
Precision: kernel taps pinned against refval (Python port of the ATBD
construction) to 1e-14 rel; dcGain = 1.0004533 +/- 1e-7 for ACC preset; a
known-scale synthetic through the chain recovers scale to <1e-6 with solve.
Speed: 1-day model (8640 pts) through the full chain < 1.0 s serial.
```

## WP-11 — `+filt`: `consistency`; `+frame`: `accToSrf`, `checkScaleMatrix`
**Needs:** WP-09, WP-10
**Prompt:**
```text
Apply the COMMON PREAMBLE.
1. accal.filt.consistency(arcObs, arcMod, strategy): port the v2
   filterConsistency strategies ("explicit" -> applyChain with the ATBD
   kernel; "commonmode" -> filter BOTH series with the same kernel;
   "none" -> pass through with a mandatory warning) operating on Arc objects
   and returning aligned Arcs plus the crnEdges mask spec. Alignment onto the
   observed epochs uses pchip with source-NaN propagation and a max-gap rule
   (port the v2 alignAccelSeries mask-resampling trick and its R2026a interp1
   NaN rationale verbatim in spirit).
2. accal.frame.accToSrf(): the fixed ACC->SRF axis permutation (proper
   rotation, det +1) as a 3x3 constant with provenance; applied to an Arc via
   Name-Value; accal.frame.checkScaleMatrix(S): port the v2
   accFrameToSRF('check', S) diagnostic (detects forgotten/doubled
   permutation hiding as a "misalignment"; thresholds mrad vs degrees) with
   verdict/message contract pinned.
Precision: permutation matrix pinned; consistency end-to-end on synthetic
known-truth arc recovers scale 1.000 to 1e-5 with strategy "explicit" and is
biased (pinned value ~0.49 from the v2 experiment regenerated in refval) with
"none". Speed: consistency on 1 day < 2 s.
```

## WP-12 — `+diag`: `observability`, `preflight`
**Needs:** WP-01, WP-08
**Prompt:**
```text
Apply the COMMON PREAMBLE.
1. observability(arcOrY2, biasDesign, Name-Value thresholds): port the v2
   scaleObservability metrics (std, relRange with the zero-mean Inf case,
   cond(X), scale variance factor, bias-scale correlation from inv(X'X)) but
   gate the verdict on the PRINCIPLED metrics (variance factor + correlation
   + cond), keeping relRange as reported-only (handover D8). Same
   verdict/reason contract style.
2. preflight(arcObs, arcMod, Name-Value): the consolidated gate — per axis:
   quality (gaps/duplicates/NaN stats), alignment diagnostic (time.check-
   Alignment result echoed), observability, noise verdict (arModel on a quick
   OLS residual), heteroscedasticity ratio (fold the v2 check in as one
   number), and a per-axis pass/warn/fail with reasons. Returns a report
   struct consumed by accal.run to REFUSE unidentifiable fits before fitting
   (handover stage 5). No plotting (viz.preflight does that).
Precision: quiet-arc synthetic -> corr(bias,scale) pinned at -1.0 (to 1e-6)
undemeaned and ~0 demeaned; gate verdicts pinned. Speed: preflight on 1 day
x3 axes < 2 s.
```

## WP-13 — `+fit`: `staticFit`
**Needs:** WP-08, WP-09, WP-11, WP-12
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Implement accal.fit.staticFit(arcObs, arcMod, spec, Name-Value): the per-arc
bias+scale estimator, replacing v2 accelBiasScaleModelFit AND the orchestrator's
duplicate OLS path (handover F1) — every number here comes from fit.solve.
Per axis i (respecting spec.scale mask): X from fit.design (with filterKernel
= the CRN kernel used on the model, so the bias basis is filtered too), weights
from arc; lambda for penalized bias by BLOCKED cross-validation over a log grid
(default; option 'LambdaSelect' "blockedcv"|"reml"|"fixed" — REML implemented
against the AR noise model; plain GCV is NOT offered, handover D2).
Undo regressor centering into the bias curve exactly as v2 (constant-in-span
argument in the help). Assemble S (MxM with NaN off-mask), vec(S) covariance
scatter, per-axis result structs matching fit.solve fields plus biasCoef/
biasFitted/scaleAxes/lambda.
Also compute and attach unc.eivBound (WP-15) per axis and, if spec.quad, the
K2 estimate with its observability check.
Output: an accal.Calibration object (WP-18) is NOT built here; return the raw
fit struct the Calibration constructor consumes (document the field contract).
Precision: full synthetic truth-recovery — bias spline + known S (incl. one
off-diagonal), CRN-filtered observation, coloured noise: recover diagonal S to
5e-4, bias curve RMS < 5% of bias amplitude (fixed seeds, refval-generated
data). Contract: field set pinned. Speed: 1 day x3 axes, 30-knot bias,
blocked-CV over 15 lambdas < 20 s serial, and document the parfor axis
(lambda grid) exploited when a pool exists.
```

## WP-14 — `+fit`: `timeVaryingFit`, `compare`
**Needs:** WP-13
**Prompt:**
```text
Apply the COMMON PREAMBLE.
1. timeVaryingFit(arcObs, arcMod, axis, Name-Value): port the v2
   accelTimeVaryingScaleFit model y1 = Bb*beta + (Bs.*y2)*gamma with the
   asymmetric-smoothness identifiability prior (ScaleKnots default 3 <<
   BiasKnots 30; ScaleLambda default large). Lambdas by blocked CV (not GCV);
   solve via fit.solve with the block penalty. MUST return s(t) WITH a
   pointwise sigma band (from the coefficient covariance through Bs) and an
   isDriftSignificant flag (drift amplitude vs band, criterion documented) —
   the handover limitation II/1 requires band-first reporting.
2. compare(arcObs, arcMod, specList, Name-Value): port
   accelBiasScaleModelCompare — fit each candidate spec via staticFit
   (Robust/Noise consistent), rank by blocked-CV score; report AIC/BIC only
   as reference columns flagged "IC_unreliable". Output table pinned by
   contract test.
Precision: synthetic with a true linear s(t) drift of 1%/day: recovered s(t)
within its own 2-sigma band at >90% of epochs AND a static fit on the same
data leaves residual lag-1 ACF > 0.8 (regenerating the v2 measured 0.86
argument); compare selects the true bias order on 200-realisation refval data
in >80% of cases while AIC picks overfit in >50%. Speed: timeVaryingFit 1 day
< 25 s.
```

## WP-15 — `+unc`: `bootstrap`, `crossval`, `eivBound`
**Needs:** WP-05, WP-09
**Prompt:**
```text
Apply the COMMON PREAMBLE.
1. bootstrap(X, y, Name-Value 'NumBoot' (300), 'BlockLength' ([] -> auto
   ~1.75*N^(1/3), documented), 'Statistic' (function handle, default the
   fit.solve coef with Robust=false), 'UseParallel' ("auto"), 'Seed' (42)):
   moving-block bootstrap; parfor over replicates with
   RandStream('Threefry','Seed',Seed) and per-replicate substream index so
   results are BIT-IDENTICAL for any worker count (required precision test:
   serial vs parallel identical). Percentile and basic CIs.
2. crossval(X, y, Name-Value 'NumFolds' (5)): contiguous-block folds, port the
   v2 blockedCrossVal contract (score = out-of-fold MSE, per-fold table).
3. eivBound(y2, residuals): the errors-in-variables attenuation bound
   (handover D4): treating the residual variance as an upper bound on model-
   error variance sigma_e^2, report lambdaAtten = var(y2)/(var(y2)+sigma_e^2)
   (classical attenuation factor), the implied worst-case multiplicative scale
   bias, and a plain-language note string. Cite Fuller (Measurement Error
   Models) for the formula. This is a BOUND, not a correction — say so.
Precision: bootstrap on AR(1) rho=0.9 known-slope data reproduces the
5-7x sigma inflation band from the v2 experiment (pinned range, fixed seed);
eivBound pinned on synthetic with known error ratio. Speed: 300 replicates,
N=8e4, p=5 < 10 s serial.
```

## WP-16 — `+diag`: `perRev`, `orbitGeometry`
**Needs:** WP-01, WP-09, WP-12
**Prompt:**
```text
Apply the COMMON PREAMBLE.
1. perRev(arcObs, arcMod, Name-Value 'OrbitPeriod' (5400 s), 'MinWindowFrac'
   (0.8)): windowed per-revolution diagonal scale/bias — port the orchestrator-
   internal perRevolution logic into a public, tested unit: per window, per
   axis: observability gate (diag.observability) then fit.solve (Robust,
   Noise "ar"); windows failing the gate return NaN with the reason recorded
   (never a number). Returns {tMid (gpsns), scale, sigma, bias, dragMag,
   constituentAmp (if model Arc carries constituents), gateReasons}.
2. orbitGeometry(gnvArc): from a GNV1B arc (positions/velocities, read via
   readL1bArc with a GNV1B product dictionary added there): compute beta angle
   (sun-orbit-plane), argument of latitude, and eclipse/penumbra flag
   (cylindrical shadow model with penumbra cone, documented approximation and
   its adequacy for masking purposes — cite Montenbruck & Gill). Returns a
   timetable on the arc epochs for mask.penumbra and driverRegression.
Precision: synthetic circular orbit with known beta -> beta to 0.1 deg,
arg-lat to 0.05 deg; shadow entry/exit epochs to 5 s vs refval geometric
solution. Speed: perRev 5-day arc < 30 s serial, parfor over windows
documented.
```

## WP-17 — `+diag`: `driverRegression`, `decomposeScale`
**Needs:** WP-15, WP-16; WP-04 (readIndices)
**Prompt:**
```text
Apply the COMMON PREAMBLE.
1. driverRegression(perRevResult, indices, Name-Value): port the v2
   scaleFactorDiagnostics logic — standardize predictors, multiple-regress
   per-rev scale per axis on {F10.7, F10.7a81, Kp/Ap, beta, arg-lat harmonics,
   secular t} with fit.solve + unc.bootstrap CIs, vote the dominant
   significant predictor family into a cause verdict "density"|"geometry"|
   "sensor"|"mixed"|"unresolved". IMPROVE (handover D7): if the perRev result
   carries constituent amplitudes, include them as predictors and report a
   per-constituent sensitivity table; report VIFs and refuse a verdict
   (-> "unresolved", reason collinearity) when max VIF > 10.
2. decomposeScale(S): port decomposeScaleMatrix (symmetric/antisymmetric ->
   scale, shear, misalignment angles via polar decomposition) and ADD the VIF
   gate from handover limitation II/3: the misalignment block is reported
   only with a reliability grade based on the model-axis correlation supplied
   by the caller.
Precision: synthetic per-rev scale built as 0.9 + 0.05*z(F10.7) + noise ->
verdict "density" with the F10.7 coefficient recovered to 20%; pure secular
drift -> "sensor". decomposeScale pinned on constructed S with known angles
to 1e-10. Speed: trivial; include the harness anyway.
```

## WP-18 — `accal.Calibration` + `+io.store`
**Needs:** WP-13
**Prompt:**
```text
Apply the COMMON PREAMBLE.
1. Value class accal.Calibration: constructed from the staticFit (and
   optionally timeVaryingFit) result structs + provenance. Properties: S,
   covS, bias (coef + basis spec + curve handle), quad (or []), timeVarying
   (or []), uncertainty (sigma, CI, inflation, eivBound), gates (observability
   /preflight verdicts), provenance (toolbox version, config echo, input file
   list + SHA-256 hashes, timestamps, Claude/MATLAB versions). Methods:
   apply(arcRaw) -> calibrated Arc implementing a_cal = S*(a_meas) + b in the
   documented direction, invert() -> the inverse-direction calibration with
   covariance propagated (document the EIV caveat: inversion of a regression
   is NOT the reverse regression), summaryTable(), disp override.
2. accal.io.store("save"|"load", file, calObj): versioned MAT-file schema
   (schemaVersion field, forward-compat load with warning on newer schema),
   port the v2 accelCalibrationIO provenance discipline.
Precision: apply/invert round-trip on synthetic to 1e-12; save/load
field-identical (isequaln). Contract: schema field set pinned. Speed: save+
load < 0.5 s.
```

## WP-19 — `accal.Config`, `accal.run`, `accal.runBatch`
**Needs:** ALL of WP-01..WP-18
**Prompt:**
```text
Apply the COMMON PREAMBLE. You are assembling the pipeline; the stage functions
exist with the contracts summarised in the handover Part II.2 diagram (paste it).
1. accal.Config: a validated options factory (accal.Config.default returns the
   full struct; accal.Config.validate checks every field, unknown-field error).
   Fields grouped by stage: io (rootDir, product, satellite, dateRange,
   modelFiles/constituents), time (allowLagCorrection false, maxLagSec 60),
   mask (qualflg bits, thruster margins, penumbra on/off, outlier params),
   filt (strategy "explicit", mission), fitspec (bias family, onePerRev,
   quad, scale mask, lambdaSelect), unc (numBoot, seed), diag (orbitPeriod,
   perRev on/off, indicesFile), run (useParallel "auto", verbose, plot false,
   saveAs "").
2. accal.run(cfg): execute stages (1)-(9) EXACTLY as the handover diagram,
   with the preflight gate refusing/downgrading before fitting; returns
   {calibration (accal.Calibration), report (preflight + perRev + attribution
   + flags), arcs (optional via cfg)}. All warnings collected into
   report.flags (unique, stable). Plot/save only via cfg switches calling
   +viz / io.store.
3. accal.runBatch(cfgArray, Name-Value 'UseParallel'): parfor over configs,
   each with util.parallelPool "off" inside (no nested pools), collecting
   results + per-arc error capture (MException stored, batch continues).
Tests: an INTEGRATION test (tag 'precision') building a 3-day synthetic
campaign end-to-end from files on disk (write synthetic L1B + GROOPS + GFZ
files) with planted truth: S diag [0.95 1.03 1.06], thruster spikes, one
data gap, qualflg fills — assert recovered S to 2e-3, thruster samples
weight 0, gap not interpolated across, flags mention each planted defect.
Contract: cfg validation error IDs; run output field set pinned. Speed: the
3-day synthetic end-to-end < 90 s serial; runBatch of 3 configs not slower
than 1.2x serial sum without a pool.
```

## WP-20 — `+viz`: `preflight`, `calibration`, `attribution`, `report`
**Needs:** WP-12, WP-13, WP-17, WP-19
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Implement the four figure/report functions, each taking the corresponding
result object/struct (NEVER raw arrays), each returning figure handles, each
with 'Visible' (default "on") and 'ExportTo' (path, writes PNG 200 dpi)
options. viz.report(runResult) additionally writes a standalone HTML summary
(house doc style) with the summary tables, flags, and embedded PNGs.
Content contracts: preflight = per-axis 4-panel (series overlay AC-coupled,
gap/mask timeline, PSD obs vs model, observability bars); calibration =
scale/bias with uncertainty bands + residual ACF before/after whitening;
attribution = per-rev scale vs drivers with regression bands + verdict
banner. Tests: contract-only (fields consumed, handles returned, files
written to tempdir, closed via addTeardown; run with Visible "off") plus a
smoke 'speed' budget < 10 s per figure. No precision refval (state so).
```

## WP-21 — `+util.syntheticPair` (truth generator)
**Needs:** WP-10
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Implement accal.util.syntheticPair(Name-Value): the ground-truth generator all
integration/precision tests share. Generates a model arc (orbital-band
signal: 1/rev + 2/rev + drag-like envelope modulated by a synthetic F10.7
proxy) and an observed arc = S_true*(model) + bias_true(t) + optional K2 term
+ coloured noise (AR or power-law, seeded) + planted defects (thruster
spikes, gaps, qualflg fills), with the observation passed through the REAL
ATBD chain (crnKernel + applyChain — the legacy lowpass shim is retired,
handover I.4). Returns both Arcs plus a truth struct documenting every
planted parameter. All randomness through one 'Seed'. Precision: statistical
properties pinned (signal band powers, noise ACF) via refval; determinism
test (same seed -> isequaln). Speed: 3-day pair < 5 s.
```

## WP-22 — Benchmarks and performance harness
**Needs:** WP-19, WP-21
**Prompt:**
```text
Apply the COMMON PREAMBLE.
Create benchmarks/runBenchmarks.m: a standalone script producing a results
table (function, workload, median time over 5 runs via timeit where possible,
memory via a documented whos-based estimate) for the budgeted workloads
declared in every WP speed test, PLUS scaling studies: (a) readL1bArc 1->16
files serial vs pool, (b) bootstrap replicates serial vs pool, (c) runBatch
1->8 arcs — reporting speedup and flagging <1.5x pool speedup as a
regression. Persist results to benchmarks/results_<datestr>.json and compare
against benchmarks/baseline.json with a +/-40% tolerance report (informative,
not failing — machine variance). Document how to promote a run to baseline.
Tests: contract-only (table schema, files written).
```

## WP-23 — Documentation build and user manual
**Needs:** all WPs (run last, iteratively)
**Prompt:**
```text
Apply the COMMON PREAMBLE.
1. Assemble doc/: verify every public unit has its HTML page; write
   doc/index.html (grouped function reference mirroring Contents.m, quick
   start, the pipeline diagram from the handover), doc/helptoc.xml, info.xml
   so the MATLAB Help browser registers the toolbox; builddocsearchdb hook in
   setupAccelCal.
2. Write doc/AccelCal_UserManual (markdown -> also export PDF if pandoc
   available, else ship the .md): chapters: (i) the calibration problem and
   the four core insights (port the v2 ROADMAP prose, updated), (ii) the
   pipeline walkthrough with a real-data example, (iii) the statistics
   (why blocked CV, why block bootstrap, the EIV bound), (iv) the CRN filter
   chapter (port the v2 crnFilter essay including the two traps and the
   GRACE-FO verification status), (v) limitations (handover Part I.5
   verbatim), (vi) parallel usage and reproducibility rules, (vii) test/
   refval philosophy and how to add a unit.
3. A doc self-test tests/test_documentation.m ('contract'): every public
   function in +accal has an HTML page, every HTML page's function exists,
   helptoc entries resolve, every help text contains the template sections.
```

## WP-24 — GRACE-FO CRN parameter verification (scientific action item)
**Needs:** WP-10; a copy of the GRACE-FO Level-1 Handbook (JPL D-56935)
**Prompt:**
```text
Apply the COMMON PREAMBLE.
This is a verification WP, mostly analysis: against the GRACE-FO Level-1
Handbook (JPL D-56935) and any updated ATBD, confirm or correct the CRN
parameters used for mission "GRACE-FO" (fs, Nc, Tf, NB/B, f0 and the
normalisation convention). Deliver: (1) a short memo doc/crn_verification.md
citing document, section, table, and the confirmed numbers; (2) set
PARAMS_VERIFIED_GRACEFO = true in crnKernel with the citation comment (or
change the parameters and update every pinned refval number that depends on
them — list them: kernel taps, dcGain, chain recovery tests); (3) a test
asserting the constant is true so the unverified warning cannot silently
return. If the handbook is not available to you, STOP and report exactly
which numbers remain unverified — do not guess.
```

## WP-25 — OPTIONAL: `+frame.fromSca1b`, `+diag.angularAcc` (extension)
**Needs:** WP-03 (reader dictionaries), WP-10
**Status:** Extension, not on the critical path. Two panel points that did not make
the core plan: (a) v3 *assumes* the model arrives in SRF (true for GROOPS output);
a model delivered in the inertial frame has no path in. (b) ACC1B's angular
accelerations are read and discarded, although they are a cheap proof-mass/
thruster-torque diagnostic. Implement only after WP-19 passes.
**Prompt:**
```text
Apply the COMMON PREAMBLE.
1. accal.frame.fromSca1b(arcModelInertial, scaArc): rotate an inertial-frame
   model Arc into SRF using SCA1B attitude quaternions (SCA1B product
   dictionary added to readL1bArc: quaternion columns per the GRACE-FO
   Level-1 handbook, incl. the handbook's quaternion convention — document
   scalar-first vs scalar-last explicitly with the citation). Quaternion
   interpolation onto model epochs by SLERP (not componentwise pchip —
   document why); continuity/sign-flip handling (enforce q dot q_prev > 0);
   result meta.frame = "SRF" with provenance. Error if epochs extend beyond
   SCA1B coverage (accal:frame:fromSca1b:CoverageGap).
2. accal.diag.angularAcc(accArc, Name-Value): diagnostics on the ACC1B
   angular-acceleration columns (exposed by readL1bArc into meta or as an
   option): RMS per axis, spike epochs (Hampel), and cross-check of detected
   spikes against THR1B firing times (report match fraction) — a validation
   aid for mask.fromThrusters margins, not a calibration input.
Precision: synthetic attitude (pure yaw ramp) -> rotated components pinned to
1e-12; SLERP vs refval quaternion math; sign-flip series handled without
discontinuity. Speed: rotation of 1 day at 1 Hz < 1 s.
```

---

# PART V — CROSS-CUTTING STRATEGIES AND CHECKLIST

## V.1 Test strategy (summary of what the preamble enforces)

**Contract tests** pin the interface: exact output field sets (sorted
fieldnames equality), documented error IDs raised on bad input, size/type of
every output, defaults. They exist so 20 independent implementation chats
cannot drift the way v2's two orchestrators did.

**Precision tests** pin the numbers: every numerical unit has a Python
reference generator (`refval/<fn>_ref.py`, numpy/scipy only, fixed seeds) whose
output JSON is committed; MATLAB tests compare with explicit AbsTol/RelTol and
a comment justifying each tolerance. Statistical claims (coverage, selection
rates, sigma inflation) are tested on committed multi-realisation reference
data, never on fresh randomness. Keystone pins carried over from v2's measured
results: CRN dcGain 1.0004533; unfiltered-comparison scale bias ≈ 0.49;
renormalised-kernel error +453 ppm; AR(1) ρ=0.9 sigma inflation 5–7×; static
fit of a drifting scale leaves lag-1 ACF > 0.8.

**Speed tests** pin the budgets stated per WP with 3× machine-variance slack;
the benchmark harness (WP-22) tracks trends and parallel speedups separately
from pass/fail.

**Integration test** (in WP-19) is the single most important test: files on
disk → full pipeline → planted truth recovered, planted defects flagged.

## V.2 Documentation strategy

Help text is the primary reference (template in the preamble, machine-checked
by the conventions and documentation self-tests). HTML pages per function feed
`doc <fn>`; the user manual (WP-23) carries the narrative science. Every
function records the Claude version and date. The v2 practice of embedding
measured numbers in help text (the crnFilter essay) is elevated to a rule:
any warning about a pitfall must quote the measured size of the effect and the
refval experiment that produced it.

## V.3 Execution checklist

| ✓ | WP | Unit | Depends on |
|---|----|------|-----------|
| ☐ | 00 | skeleton, setup, conventions harness | — |
| ☐ | 01 | Arc | 00 |
| ☐ | 02 | +time | 01 |
| ☐ | 03 | findL1bFiles, readL1bArc | 01,02 |
| ☐ | 04 | readGroopsArc, readIndices | 01,02 |
| ☐ | 05 | parallelPool, validate | 00 |
| ☐ | 06 | mask family | 01,03,04 |
| ☐ | 07 | noise family | 00 |
| ☐ | 08 | fit.design | 01 |
| ☐ | 09 | fit.solve (core) | 05,07,08 |
| ☐ | 10 | crnKernel, applyChain | 01,05 |
| ☐ | 11 | consistency, frame | 09,10 |
| ☐ | 12 | observability, preflight | 01,08 |
| ☐ | 13 | staticFit | 08,09,11,12 |
| ☐ | 14 | timeVaryingFit, compare | 13 |
| ☐ | 15 | bootstrap, crossval, eivBound | 05,09 |
| ☐ | 16 | perRev, orbitGeometry | 01,09,12 |
| ☐ | 17 | driverRegression, decomposeScale | 15,16,04 |
| ☐ | 18 | Calibration, io.store | 13 |
| ☐ | 19 | Config, run, runBatch (+integration test) | 01–18 |
| ☐ | 20 | viz family | 12,13,17,19 |
| ☐ | 21 | syntheticPair | 10 |
| ☐ | 22 | benchmarks | 19,21 |
| ☐ | 23 | doc build + user manual | all |
| ☐ | 24 | GRACE-FO CRN verification | 10 + handbook |
| ☐ | 25 | OPTIONAL: fromSca1b, angularAcc | 03,10 (after 19) |

Note: WP-21 (syntheticPair) is listed late for dependency correctness but
should be pulled forward as soon as WP-10 lands, because WP-13/14/19 tests
consume it — implement in the order 00,01,02,05,07,08,10,**21**,09,03,04,06,
11,12,13,14,15,16,17,18,19,20,22,23,24 for the smoothest path.

## V.4 References cited across this handover

- Wu, Kruizinga, Bertiger: *GRACE L1B ATBD*, JPL D-27672 / GRACE 327-741, 2006.
- *GRACE-FO Level-1 Data Product User Handbook*, JPL D-56935, 2019.
- Klinger & Mayer-Gürr: *The role of accelerometer data calibration within
  GRACE gravity field recovery*, Adv. Space Res. 58(9), 2016.
- Bettadpur: *Recommendation for a-priori bias & scale parameters for Level-1B
  ACC data*, GRACE TN-02 (rev.).
- JPL technical documentation on the GRACE-FO ACT1B accelerometer-transplant
  product (GF-D degradation handling).
- Percival & Walden: *Spectral Analysis for Physical Applications*, CUP 1993.
- Fuller: *Measurement Error Models*, Wiley 1987 (EIV attenuation).
- Politis & Romano (block bootstrap foundations), JASA 1994.
- Montenbruck & Gill: *Satellite Orbits*, Springer 2000 (shadow geometry,
  time systems).

*End of handover.*
