# CONCEPT — GRACE-FO time-series preparation, accelerometer calibration, LRI/KBR processing

**Revision 0.11 (DRAFT) · 2026-09-18 · written with Claude Opus 5 (Anthropic)**

This file is the **single point of truth for the design** of one pipeline
spanning six toolboxes. Each repository's HANDOVER stays the single point of
truth for its own status, obligations and decisions and points here
(gracefoReading O-13, NonGravForces O-45, referenceSystem #25).

Nothing in this file is implemented yet.

**Hosting (Q14, item 5).** The timeSeriesPreparation repository is created
now with documents only (X-00a), and this folder moves there at once.
gracefoReading #15 then shrinks to a pointer plus the G-01/G-02 records, and
the input zips never enter the reader's history. gracefoReading gains **no preprocessing code**; its
only items are two reader obligations, G-01 (its O-11) and G-02 (its O-1).

**History**

| rev | owner decisions, 2026-09-18 |
|---|---|
| 0.1 | draft |
| 0.2 | Q1–Q3 |
| 0.3 | Q5 |
| 0.4 | Q7: ACC calibration in NonGravForces |
| 0.4a | Q8, Q9 |
| 0.5 | Q10: shared preparation toolbox |
| 0.6 | preparation toolbox named timeSeriesPreparation; sigtools v1.3.1 becomes part of it; global order (section 10) |
| 0.7 | Q11: LRI/KBR toolbox named rangingPreparation; Q12: sigtools and lsqvce kernels both kept, with a mechanical agreement test |
| 0.8 | Q4: no orbit integration and no LGD; Q6: classic GRACE is supported as well, with real files supplied by the owner when the work starts |
| 0.9 | Q14: improvements 1–9 adopted — gpsns epoch authority (R-02), campaign mode (X-15, N-09), stage cache (X-14), regression baseline (N-10), concept moved now (X-00a), decisions recorded once, shared static audit (C-01), downstream contracts (C-02), X-02 later in the order |
| 0.10 | Q15: improvements 11–20 adopted — output-epoch CRN, QC speed after an unchanged port, reading profiled, streaming accumulation, real-day defect catalogue, minimum-data gate, array conventions, data-handling rules, one help template and generator, executed documentation |
| **0.11** | **Q16: the deep-research findings of 2026-09-18 are distributed to the repositories (W-1…W-15 → G-04…G-06, X-17, X-18, N-11, N-12, L-07…L-09; ORC-12, ORC-13; V-13…V-16); research answers to V-1…V-11 recorded as expected values (9.2); the global order and all procedures move to `GUIDE.md`** |

**Read at**

| toolbox | commit | version |
|---|---|---|
| gracefoReading | `a18e9ad` | 1.0.2 |
| referenceSystem | `311e060` | 2.1.244 |
| NonGravForces | `3cc0123` | 0.12.0 |
| lsqvce | `ac981cd` | 6.1 |

Inputs are listed in `inputs/README.md`: the AccelCal v3 handover,
AccelBiasScaleToolbox v2.4.2 and sigtools v1.3.1.

---

## 1. Why, and where each part lives

GRACE-FO Level-1B series are not usable as delivered:
- spurious samples must be found and down-weighted;
- systematic effects must be pre-estimated or pre-eliminated;
- gaps must be bridged for consumers that need continuity;
- hidden dependencies (β′ angle, eclipse, solar activity, SNR) must be made
  visible by correlation analysis.

**Each capability sits with the toolbox whose domain it is. Applications sit
above what they use.

| toolbox | domain | new in this concept |
|---|---|---|
| referenceSystem | time, frames, ephemerides, orbit geometry | `orbitSunGeometry`: β′ and argument of latitude (#25) |
| gracefoReading | reading L1B, ITSG and GROOPS files | no preprocessing code; G-01 (O-11) and G-02 (O-1: classic layouts validated on real files) |
| **timeSeriesPreparation** (new) | physics-free time-series preparation and analysis | sigtools v1.3.1 (spectra, ARMA/SARIMA models, synthesis, diagnostics); the `Arc` container, CRN kernel, masks, QC, alignment, gaps, observability, bootstrap, blocked CV, correlation; entry point `run` |
| NonGravForces | forces, environment, the ACC calibration application | `app.calibrate` upgraded in place; `qc` leaves for timeSeriesPreparation |
| **rangingPreparation** (new) | LRI/KBR processing and analysis | observables, phase jumps, KBR↔LRI comparison, spectra; entry point `process` |
| lsqvce | least squares | nothing; the one estimator, called by the applications |

**Out of scope (Q4):** orbit integration, orbit and gravity estimation, LGD,
mascons.

**Missions (Q6):** GRACE-FO (C/D) and classic GRACE (A/B). Classic data
need gracefoReading O-1 discharged first (G-02); the owner supplies real
files when that work starts. Everything is mission-aware from its first WP,
so adding classic GRACE only adds dictionary entries and presets.

---

## 2. Authority map — one owner per capability (R1)

| capability | authority | consequence |
|---|---|---|
| L1B / ITSG / GROOPS reading | gracefoReading | v3 `+io` **retired** |
| official event lists: TN-01 sequence of events, TN-01a spacecraft events, CMC and KBR calibration manoeuvres | **gracefoReading** reads them (G-05) | timeSeriesPreparation turns them into mask layers and calibration windows (X-05); nothing is inferred that a list states |
| hybrid transplant accelerometer data ACH1B (ACX/ACX2), used by the gravity release RL06.3 | gracefoReading reads it (G-04, generic reader, fixture-verified) | NonGravForces uses it as a calibration oracle (ORC-12) |
| alternative attitude products (ITSG attitude, SCA+IMU fusion products) | gracefoReading reads them; `NonGravForces.geom.AttitudeProvider` serves them (N-12) | attitude quality propagates into KBR antenna offset (L-07) |
| qualflg bit meanings | the file's own header, via `gracefoReading.decodeQualFlags` | v3 handbook bit table **retired** (O-1 lesson) |
| gaps and segments | `gracefoReading.findGaps` | used by `fill` |
| int64 GPS-ns epochs | `gracefoReading.readL1b 'TimeFormat' "gpsns"` | `Arc` accepts gpsns only |
| time scales, rotations, quaternions, Sun | referenceSystem | v3 `+time` **retired** |
| int64 GPS nanoseconds ↔ referenceSystem epoch struct | **referenceSystem**, a new representation with exact integer arithmetic (R-02) | `Arc` times reach `Model.budget` and `orbitSunGeometry` through it; no toolbox writes its own conversion |
| β′, argument of latitude | referenceSystem `orbitSunGeometry` (#25) | enter as driver data |
| orbit in the celestial frame | `NonGravForces.io.readGNV1B`, ITSG `reducedDynamicOrbit`, or GNV1B + `referenceSystem.rotationItrsToGcrs` | input to `orbitSunGeometry`; timeSeriesPreparation never rotates an orbit |
| modelled non-gravitational acceleration, per effect | `NonGravForces.Model` (`series`, `budget`) | used inside `app.calibrate`; external references enter as an `Arc` |
| eclipse factor, space weather | `NonGravForces.env.eclipseFactor`, `io.spaceWeather` | driver data outside NonGravForces |
| spectra (Welch, Lomb-Scargle), Allan deviation, PSD↔ACV, ARMA↔PSD, ARMA ACV, noise synthesis, ARIMA/SARIMA exact ML with gaps, ACF/PACF (gap-aware), Ljung-Box, residual diagnostics | **timeSeriesPreparation** (from sigtools v1.3.1) | v3 `+noise`, `lombScarglePSD` and the synthetic-noise parts of `syntheticPair` **retired**; overlap with lsqvce kernels is Q12 |
| exact ATBD CRN kernel and its derivative kernels, presets for ACC, KBR and LRI | **timeSeriesPreparation** `crnKernel` (port of v2 `crnFilter`) | consumed by NonGravForces and rangingPreparation |
| residual QC: Hampel, impulses, jumps, event table | `NonGravForces.qc` 0.12.0 → **timeSeriesPreparation** `qc` | ported; NonGravForces forwards for one release, then deletes (N-01) |
| least-squares estimation | **`lsqvce.fit`**, called by each application for its own problem | `app.calibrate`'s own QR solver **retired**; v3 `fit.solve` **retired**; timeSeriesPreparation contains no least-squares estimator |
| cached stage results | the stage cache of `run` (6.6) | key = SHA-256 of stage, toolbox version, resolved settings and input content hashes |
| instrument settings | timeSeriesPreparation `Config` | embedded in each application's options and hashed with them |

---

## 3. Architecture

### 3.1 Dependency graph (acyclic)

```
referenceSystem  <------------------------------------------+---------------+
gracefoReading   <-- timeSeriesPreparation <-- NonGravForces-+  (+ lsqvce)   |
      ^   (optional)         ^                                              |
      +----------------------+------------ rangingPreparation --------------+  (+ lsqvce)
```

| toolbox | depends on |
|---|---|
| timeSeriesPreparation | gracefoReading, **optional**. Only the L1B-specific functions call it (qualflg masks, gap segments); these error at the point of use with `timeSeriesPreparation:<fn>:depMissing`. The sigtools half runs in base MATLAB |
| NonGravForces | referenceSystem, gracefoReading, timeSeriesPreparation, lsqvce; gjToolbox optional |
| rangingPreparation | referenceSystem, gracefoReading, timeSeriesPreparation, lsqvce |

Checked 2026-09-18:
- no `.m` file of lsqvce `ac981cd` or referenceSystem `311e060` calls
  gracefoReading, NonGravForces or any sigtools function;
- no repository calls a sigtools function today, so namespacing sigtools
  breaks nothing in the ecosystem.

rangingPreparation does not depend on NonGravForces.

### 3.2 timeSeriesPreparation packages and layers

These are checked mechanically: calls go downward only.

```
L3  timeSeriesPreparation.run                         single point of access, instrument level
L2  mask, qc, align, crnApply, fill, observability, bootstrap, crossval, drivers, correlate, report
L1  Arc, Config, crnKernel
L0  +spectral  (sigtools/spectral: 10 functions)      +tsmodels (sigtools/tsmodels: 15 functions)
```

- The sigtools functions keep their names inside two sub-packages, e.g.
  `timeSeriesPreparation.spectral.psd2arma` and
  `timeSeriesPreparation.tsmodels.tsFitSarima`. `sigtoolsDemo` moves to
  `demos/`.
- **No least-squares estimator.**
  - `bootstrap` and `crossval` take a statistic handle.
  - `fill` with collocation takes a covariance model, built by
    `tsmodels`/`spectral` or supplied from lsqvce.
  - sigtools' ARIMA fitting is time-series *model* estimation (maximum
    likelihood of noise parameters), not parameter adjustment, so it stays.

### 3.3 NonGravForces

- The calibration application stays in the `app` layer (L8) and calls
  timeSeriesPreparation and lsqvce by qualified name.
- lsqvce **re-enters** NonGravForces' dependency table under the re-entry
  condition its B.4 section set itself.
- The A.2 governing rule is reworded (N-06).

---

## 4. Single points of access

**Instrument level — timeSeriesPreparation.** It is chained after reading,
and the product read from the file selects the preset (R3):

```matlab
[t, a, aux] = gracefoReading.readL1bMulti(files, 'TimeFormat', "gpsns");
acc = timeSeriesPreparation.Arc(t, a, aux);
res = timeSeriesPreparation.run(acc, 'Reference', ref);    % masks, QC, CRN, gaps, report
```

**Accelerometer calibration — NonGravForces**:

```matlab
M   = NonGravForces.Model(NonGravForces.geom.graceFO("C"), NonGravForces.Options("standard"), ...
                          'Eop', eop, 'SpaceWeather', sw);
res = NonGravForces.app.calibrate(acc, M, 'Orbit', orb, 'Attitude', att);   % a priori from M
res = NonGravForces.app.calibrate(acc, itsgArc);                           % external reference
```

- With a `Model`, `'Orbit'` (GNV1B via `io.readGNV1B`) and `'Attitude'`
  (SCA1B via `io.readSCA1B`) are required.
- The a priori acceleration is evaluated **per effect** through
  `Model.budget`.
- The instrument stages run through `timeSeriesPreparation.run`, so there is
  one code path (v3 F4).

**LRI/KBR — rangingPreparation**:

```matlab
lri = timeSeriesPreparation.Arc(tl, rl, auxl);   kbr = timeSeriesPreparation.Arc(tk, rk, auxk);
res = rangingPreparation.process(lri, 'Reference', kbr, 'Drivers', drv);
```

**Result fields.**
- `run` returns `arc`, `reference`, `diagnostics`, `correlation`, `flags`,
  `config` and `provenance`. A contract test pins this set.
- `app.calibrate` adds `calibration` (`app.Calibration`: apply / invert /
  summaryTable / save / load) and `attribution`.
- `rangingPreparation.process` adds `comparison`.

---

## 5. Data model

**`timeSeriesPreparation.Arc`** is a value class built from gracefoReading's
triple by field names; the constructor calls no gracefoReading function. It
refuses anything but int64 gpsns time (`timeSeriesPreparation:Arc:timeFormat`).

| property | type, size | source |
|---|---|---|
| `t` | int64 N×1, strictly increasing | reader, gpsns |
| `obs` | double N×M | reader |
| `names`, `units` | string 1×M | file header |
| `mission`, `product`, `satellite`, `frame`, `frameSource` | string | `aux`. A frame not stated by the file or an explicit option stays `""`, and a stage needing it refuses (v3 F5) |
| `weights` | double N×1 in [0,1] | `min` over layers; fits scale rows by √w |
| `layers` | struct of N×1 logical, true = remove | additive and named; a layer can only remove |
| `filled` | logical N×1 | set by `fill`; weight 0 in every fit |
| `provenance` | struct array, append-only | one entry per stage |

Columns are selected by name through a product dictionary: ACT1B uses
`lin_accl_x/y/z`, LRI1B takes its names from the real header (V-3). There is
no positional fallback.

**`timeSeriesPreparation.Config`**
- Sections: `mask`, `qc`, `crn`, `align`, `fill`, `noise`, `unc`,
  `drivers`, `run`.
- `Config(arc)` returns the preset for the measured product; unknown fields
  error.
- An option whose default would be an assumption defaults to empty (R5).
- Applications take it as `'Preproc'` and hash it together with their own
  options.

### 5.1 Array conventions (Q15, item 17)

- **Samples in rows, channels in columns** (N×M) everywhere. One call handles
  the 3 ACC axes or all LRI observables; there is no per-axis loop in a public
  interface.
- A campaign is an **array of `Arc`s**; numerical kernels see plain matrices,
  never objects or per-sample structures.
- **No `datetime` in inner loops.** Relative double seconds are formed once per
  arc from the int64 epochs: about 6e-10 s resolution over a month. Absolute
  time stays int64.
- The `vectorisation` test category holds every kernel to this: a batched call
  equals the loop over its parts, bitwise.

### 5.2 Data-handling rules (Q15, item 18)

- **One L1B release per arc and per campaign.** Mixing release versions
  (e.g. RL04 and a later one) refuses unless asked for explicitly. The release
  is read from the file name or header and recorded in provenance (R3).
- **NaN is the only missing value.** No sentinel numbers; filled samples are
  flagged, never disguised.
- **Units are checked** between observation and reference at `align`; a
  mismatch refuses.
- **Results are stored per day**, not as one array: about 1 GB per
  satellite-year at 1 Hz for 3 axes plus weights. Versioned MAT schema per day,
  and one data-management manifest per campaign (DataCite/PROV fields).
- **Minimum-data gate (item 16).** An axis whose remaining weight fraction
  falls below a threshold refuses with an identifier; it never returns NaN.
  The threshold is set explicitly in each product preset, with its rationale
  in the preset's help.

---

## 6. Pipeline

### 6.1 Instrument stages (timeSeriesPreparation)

| # | stage | function | guarantee |
|---|---|---|---|
| 1 | mask | `mask` | qualflg layers via `decodeQualFlags`; THR1B windows (margins justified by the CRN span); eclipse transitions from a driver series; CRN edges; a user layer; **official event lists** (G-05) as layers and calibration windows |
| 2 | QC | `qc` | residual-based outliers; impulses (matched filter on the CRN impulse response, THR1B priors); jumps (reported and turned into parameters, never masked); after X-16, a **labelled template bank** (twang, heater, magnetic-torquer and thruster spikes) with one mask layer per type (X-17) |
| 3 | align | `align`, `checkAlignment` | reference moved onto the observation epochs; lag diagnostic over ±60 s that warns above 1 s and never shifts silently (v3 F2) |
| 4 | consistency | `crnKernel`, `crnApply` | exact ATBD kernel normalised at f0, DC gain 1.0004533 kept; chunked per file day with half-span overlap, bit-identical to unchunked; NaN edges. **The convolution sum is evaluated only at the output epochs** (1 Hz for ACC1B from the 10 Hz grid): about 3.6e8 instead of 3.6e9 multiply-adds per day for 3 axes, pinned equal to full-rate convolution followed by sampling |
| 5 | noise | `tsmodels`, `spectral` | residual noise model (AR/ARMA/SARIMA exact ML with gaps, or PSD → ARMA), Ljung-Box, Allan deviation; the model feeds `fill` and the applications' lsqvce covariance; a **reference noise-model library** (ACC 1/f, KBR CNR-limited, LRI design ASD) as priors and validation targets (W-12, X-07) |
| 6 | gate | `observability` | metrics an application uses to refuse or downgrade unidentifiable parameters before its fit |
| 7 | uncertainty | `bootstrap`, `crossval` | moving-block bootstrap with substreamed RNG; blocked CV |
| 8 | gaps | `fill` | see 6.5 |
| 9 | correlation | `drivers`, `correlate` | see section 7 |

### 6.2 ACC calibration (NonGravForces `app`)

Per axis i, with H the CRN kernel from `timeSeriesPreparation.crnKernel`:

  y_i(t) = H∗b_i(t) + Σ_j S_ij·(H∗a_j)(t) [+ K2_i·(H∗a_i)², demeaned] [+ 1/rev] [+ Σ jumps] + e_i(t)

The noise e is coloured and modelled by timeSeriesPreparation; the parameters
are estimated by `lsqvce.fit`.

- **Bias basis** `constant | linear | hat | pspline`, filtered by H like every
  deterministic column; knot spacing below the kernel span warns.
- **Scale** `diag | full | mask`. The cross-track scale is fixed by default;
  a full S is gated by the model-axis VIF.
- **Refused combination:** per-revolution scale together with 1/rev terms
  (measured correlation r ≈ −0.7).
- **Time-varying s(t)** only with its pointwise σ band and an
  `isDriftSignificant` flag.
- **EIV bound:** every scale carries the errors-in-variables attenuation
  bound (v3 D4).
- **Satellite D:** ACT1B is a transplant product (V-5), and the report says
  so.
- **Classic GRACE:** needs a GRACE macro model in NonGravForces (N-07, V-9).
  Accelerometer thermal behaviour over the mission may need a temperature
  driver or a bias model; V-10 establishes the facts first.
- **Temperature and magnetic torquers (N-11):** a temperature regressor in the
  bias basis (housekeeping product per V-13), an optional temperature-dependent,
  fully-populated scale matrix, and magnetic-torquer current as a regressor
  (MAG1B via `io.readMAG1B`).
- **Oracle (ORC-12):** calibrated ACT1B compared with the hybrid ACH1B
  (ACX/ACX2) for the same days.
- **Attribution:** per-revolution parameters are regressed on per-effect
  a priori amplitudes, space weather, β′ and u; a VIF above 10 gives the
  verdict `unresolved`.

### 6.3 LRI/KBR (rangingPreparation)

- `observables`: range, range-rate and range-acceleration, with the
  correction columns the real header declares (V-3).
- `detectPhaseJumps`: a range step appears as a CRN-shaped doublet in
  range-acceleration. It is detected through `qc`, with the CRN derivative
  kernel as template.
- `compareKbr`: KBR (5 s) and LRI (2 s) on common epochs with CRN-consistent
  filtering (V-2). It estimates the time-tag offset, the LRI/KBR scale and the
  bias/drift of the difference through `lsqvce.fit`.
- `spectrum`: `spectral.plotPowerSpectrum` (Welch, or Lomb-Scargle for
  gapped data) and `spectral.allanVariance` on LRI, KBR and their difference.
- **Classic GRACE:** KBR only. `observables`, phase jumps, spectra and
  correlation apply; `compareKbr` does not.
- **KBR antenna offset (L-07):** read the applied correction, recompute it from
  attitude (alternative attitude via N-12) for QC, and flag multipath-affected
  calibration-manoeuvre windows.
- **Time tags (L-08):** KBR↔LRI time-tag offset co-estimated, optional
  low-pass filtering of the clock offset.
- **LRI scale (L-09):** continuous scale instead of daily steps, with a
  thermal-coupling regressor (temperature source per V-14).
- **Deglitching benchmark (ORC-13):** phase-jump detection compared with the
  alternative LRI1B products (AEI, SYSU, HUST).
- **Out of scope (Q4):** orbit integration and LGD. Residuals against a
  reference orbit or gravity field are not formed here.

### 6.4 Pre-estimation versus pre-elimination (application option)

- `"preestimate"`: the nuisance parameters are estimated, applied, and
  reported with their covariance.
- `"preeliminate"`: the nuisance columns are handed on as lsqvce local
  parameters, so the downstream adjustment reduces them by Schur complement.
- Regularisation is declared as lsqvce priors. Its weight comes from variance
  components (REML-type) or blocked CV; plain GCV is not offered (v3 D2).

### 6.5 Gaps (`Config.fill`)

| method | fills | use |
|---|---|---|
| `none` (**default**) | nothing; gaps are reported (`findGaps`) and arcs split there | estimation, and every run that does not ask |
| `collocation` (on request) | optimal prediction under the fitted noise model (ARMA state space; V-7), gaps ≤ `maxGap` | consumers needing continuity |
| `reference` (explicit request) | calibrated reference plus collocated residual | continuity beyond what collocation can bridge |

- `maxGap` has no default; a fill without it refuses
  (`timeSeriesPreparation:fill:maxGapMissing`).
- Filled samples are flagged in `arc.filled`, weigh 0 in every fit, and never
  re-enter an estimate.

### 6.6 Campaigns, cache and regression baseline (Q14)

**Campaign mode, through the same two entry points.**
- `timeSeriesPreparation.run` accepts an **array of `Arc`s**, one per day or
  arc. It runs the same stages on each, captures errors per arc (the
  `MException` is stored and the campaign continues), and parallelises over
  arcs deterministically and only when asked. It returns one result per arc
  plus a campaign summary.
- `NonGravForces.app.calibrate` accepts an `Arc` array: a multi-arc
  calibration. Per-arc biases are lsqvce local parameters, pre-eliminated;
  the scale is common or per arc as configured. Multi-day solutions with
  space-weather attribution are the only route that separates sensor error
  from model error (v3 I.5-2).
- **Multi-arc fits use lsqvce's streaming accumulation** (declaration kind A,
  one system per arc) rather than a dense design matrix over the campaign, and
  keep the three axes as three separate problems (item 14).

**Stage cache.**
- `Config.run.cacheDir` is empty by default, which means the cache is off (R5).
- The key is the SHA-256 of stage, toolbox version, resolved settings and
  input content hashes. It is written into provenance as the reproducibility
  fingerprint.
- A cache hit is reported, never silent. gracefoReading's `CacheDir` covers
  reading; this cache covers the stages.

**Regression baseline.**
- After N-03, the results for the reference month 2020-01 (satellites C and
  D) are frozen as golden numbers. After G-02, one classic month is added.
- Each tolerance is k × the bootstrap sigma, with k stated beside it.
- The baseline is re-run for every release of timeSeriesPreparation or
  NonGravForces.
- If published daily bias and scale series exist, they are an external
  oracle (V-11). Whether any are available is not known yet.

---

## 7. Correlation analysis (`drivers`, `correlate`)

**Drivers are supplied, not computed here:**
- β′ and u from `referenceSystem.orbitSunGeometry`;
- eclipse factor and space weather from NonGravForces;
- THR1B counts, LRI/KBR SNR, and per-effect a priori amplitudes.

**Methods.** Every significance statement respects autocorrelation.
- Lagged correlation of pre-whitened series.
- Regression of gated per-revolution parameters on the drivers, with a VIF
  gate.
- Partial correlation (β′ versus eclipse fraction).
- Binned maps of the residual over (β′, u).
- Effective sample size from the gap-aware `tsmodels.tsAcf`; block-bootstrap
  confidence intervals.

---

## 8. Rules carried over — measured, do not re-litigate

| rule | evidence |
|---|---|
| exact ATBD CRN kernel only; normalise at f0, keep DC gain 1.0004533 | approximate kernel −11.5 % scale; unit-DC renormalisation +453 ppm (v2 refval) |
| model and bias basis through the same kernel as the observation | an unfiltered comparison biases the scale to ≈ 0.49 (v2) |
| observability gate before the fit; demean regressors | corr(bias, scale) = −1 on quiet arcs (v2) |
| never co-estimate per-rev scale and 1/rev terms | r ≈ −0.7 (v2) |
| block bootstrap for sigmas | naive sigmas 5–14× optimistic (v2) |
| int64 gpsns, never double GPS time | 2020 gpsns ≈ 6.3e17 > 2^53 |
| qualflg meanings from the file header | O-1: invented formats fail on real files |
| deterministic opt-in parallelism; RNG substream per replicate, seed per stage name | results independent of worker count and stage insertion |
| **ported code moves unchanged first** (sigtools, NonGravForces `qc`); conventions or speed change afterwards, in a separate WP gated by equality to the ported version | any numerical change must be attributable to a WP that says so |
| CRN convolution evaluated only at output epochs | same numbers, a tenth of the work (item 11) |

GRACE-FO CRN parameters are the GRACE ATBD ones and are unverified for
GRACE-FO (V-1). `crnKernel` warns until a named constant cites the handbook.
For classic GRACE the ATBD is the mission's own document, so the warning
does not apply there; its numbers are still checked against the ATBD by
ORC-1.

---

## 9. Validation

Every new public unit carries the tags `contract`, `reference`, `precision`,
`speed` (ratio budget), `robustness`, `vectorisation` and `metamorphic`, or
an exemption stating why a category is impossible. Counts are predicted as
passed + failed + incomplete = total before every run.

**sigtools baseline**
- Its HANDOFF reports 209 tests passing on R2026a Update 3: 180 class-based
  tests in 15 suites plus 29 legacy ones. This is stated by the input and not
  re-run here.
- The imported suite is X-01's first gate. It is re-measured, not assumed.

**Downstream contracts (Q14, item 8).**
- Every consumer pins, with `contract` tests, the dependency fields it reads:
  - `Arc` pins gracefoReading's `aux` fields;
  - NonGravForces' readers pin the same fields;
  - rangingPreparation pins `Arc` and `qc`;
  - NonGravForces pins the epoch representation from R-02.
- An ecosystem compatibility file in `ci-actions` (C-02) lists the version
  sets tested together. Each release updates it, and the provenance of every
  run cites it.

| id | oracle (nothing checks itself) | checks |
|---|---|---|
| ORC-1 | GRACE L1B ATBD App. B via Python `refval/crn_atbd.py` (v2 zip) | CRN taps, DC gain, derivatives |
| ORC-2 | v2 keystone numbers regenerated in Python | 0.49, +453 ppm, 5–7× inflation, lag-1 ACF > 0.8 |
| ORC-3 | real 2020-01-01 ACT1B/THR1B/GNV1B/SCA1B (C), KBR1B, LRI1B | dictionaries, masks, end-to-end smoke |
| ORC-4 | ITSG `nonConservativeForces` 2020-01-01 | independent reference series (V-4) |
| ORC-5 | numpy circular-orbit geometry | β′ and u (referenceSystem #25) |
| ORC-6 | numpy least squares on white noise | each application's lsqvce declaration equals the textbook solution |
| ORC-7 | truth generators with noise from `spectral.synthTimeSeries`, fixed seeds | recovery and flagging of planted parameters and defects |
| ORC-8 | sigtools' NumPy/SciPy re-derivations (per its HANDOFF §3) and its imported suite | the moved numerics are unchanged |
| ORC-9 | real classic GRACE files (A/B), one per product, supplied by the owner at G-02 | classic layouts, qualflg, dictionaries, presets |
| ORC-10 | regression baseline 2020-01, C and D, plus one classic month (6.6) | releases change no calibrated number beyond k × bootstrap sigma |
| ORC-11 | **defect catalogue of real days** (V-12): thruster spikes, bias jumps, day-boundary duplicates and gaps, a satellite-D transplant period, an LRI phase jump, a KBR SNR drop, and classic cases after G-02 | every detector is tested on a real instance, not only on synthetic data |
| ORC-12 | hybrid transplant ACH1B (ACX/ACX2) for the reference month | NonGravForces calibration against the SDS's own current accelerometer product |
| ORC-13 | alternative LRI1B products (AEI V50, SYSU, HUST) | phase-jump detection and deglitching |

| id | verification item (from documents or real bytes, never memory) | blocks |
|---|---|---|
| V-1 | GRACE-FO ACC CRN parameters vs JPL D-56935 | removing the `crnKernel` warning |
| V-2 | KBR1B and LRI1B CRN parameters | rangingPreparation CRN presets |
| V-3 | LRI1B correction columns, signs and units from the real header | L-01 |
| V-4 | ITSG `nonConservativeForces`: model or calibrated measurement? CRN-filtered? | ORC-4 |
| V-5 | the ACT1B satellite-D transplant statement in the header | N-02 report wording |
| V-6 | lsqvce 6.1: local parameters + priors + ARMA/PSD + robust in one `fit` call, read from source | N-02, L-03 |
| V-7 | sigtools: does the gap-aware Kalman filter smooth (interpolate) or only filter/forecast? If only the latter, `fill` adds a fixed-interval smoother on the same state space | X-08 |
| V-8 | classic GRACE: column layouts, `qualflg` format (bit string or decimal) and flag meanings, from real files (gracefoReading O-1) | G-02, X-13 |
| V-9 | GRACE macro model (plates, areas, optical properties, mass), from the GRACE product specification; the document must be supplied, not recalled | N-07 |
| V-10 | classic GRACE accelerometer thermal-control history, and which housekeeping product carries the accelerometer temperature | N-08 bias model and drivers |
| V-11 | is there a published daily ACC bias/scale series (processing centre or science data system) usable as an external oracle? | ORC-10 external half |
| V-12 | the defect catalogue: one real day per defect class, recorded as file, epoch range and expected verdict | X-05, L-02, N-02 tests |
| V-13 | GRACE-FO accelerometer temperature housekeeping: product name and columns, from real files | N-11 |
| V-14 | temperature source for LRI thermal coupling (zenith solar-array temperature), product and columns | L-09 |
| V-15 | PO.DAAC/ISDC collection names, file naming and published checksums for every product in the data plan | G-06, GUIDE Stage B |
| V-16 | ACH1B/ACX/ACX2 format and availability periods (ACX2 from 2023-01 in wide-pointing mode, gap 2023-03…06, per the research) | G-04, ORC-12 |

**Fault injection (item 16).** Every new check is fault-injected in the
round that adds it: it must fire on a broken input and stay silent on a
healthy one. A check that its own injection does not fire is not a check.

### 9.1 Help text and documentation (Q15, items 19–20)

**One help template for the new repositories**, enforced by the shared audit
C-01 and rendered by the shared generator C-03:
- SYNTAX;
- DESCRIPTION, motivated, with numbers;
- INPUTS / OUTPUTS / OPTIONS as `(size) type units description`;
- ACCURACY, never empty ("not applicable, because ..." is an answer);
- ERRORS grouped by cause;
- a runnable EXAMPLE;
- LIMITATIONS and REFERENCES;
- See also;
- the footer per Q5: toolbox and version, date and time, model.

Existing repositories keep their own templates until each opts into C-01 in
its own PR (see the C-01 risk in 10.2).

**One generator.** Today there are three (`docsrc/generate_docs.py`,
`tools/buildDocs.py`, `referenceSystem.buildDocumentation`) and four help
styles counting sigtools. C-03 provides one, driven by the help blocks:
- HTML pages, `helptoc.xml`, `info.xml`, the search database;
- a generated error-identifier catalogue per repository.

sigtools' hand-made HTML pages are replaced at X-02, because otherwise they
would be a second authority.

**Executed documentation.**
- Every help EXAMPLE runs in the suite (`testHelpExamples`, generated by C-03),
  as NonGravForces already does for its demos.
- Every warning about a pitfall quotes the measured size of the effect and
  the experiment that produced it (v3 V.2).
- One **processing-chain page** (read → prepare → calibrate → ranging on
  2020-01-01) is executed by an ecosystem job in `ci-actions` (C-04). It lives
  at the top of the dependency graph, so no toolbox's CI needs a toolbox
  above it; each toolbox's getting-started page links to it.

### 9.2 Research answers of 2026-09-18 — expected values, not yet facts

The deep-research report of 2026-09-18 answered most verification items from
primary sources. These answers are **expected values**: each V-item closes
only when the number has been read from the registered document itself
(GUIDE Stage C), per R3. They also reconcile with measured data where the
repository has any: gracefoReading's real-data tests find **5 s** sampling
for KBR1B (17 280 records per day) and **2 s** for LRI1B (43 200 records per
day), matching the filter outputs below.

| item | expected answer | source to confirm in |
|---|---|---|
| V-1 | GRACE-FO ACC CRN identical to GRACE: 7th-order self-convolution, 35 mHz bandwidth, 140.7 s span, 10 Hz → 1 Hz. NB = 5, the DC gain 1.0004533 and the normalisation at f0 are **not** stated in the documents; they are implementation choices to validate numerically | JPL D-27672 App. B; JPL D-56935 |
| V-2 | KBR: 7th order, 100 mHz, 70.7 s span, output 0.2 Hz. LRI: Nc = 9, fc = 0.25 Hz, Nf = 747, input 9.664 Hz (9.664198 Hz on GRACE-D), output 0.5 Hz. **Three distinct presets** | JPL D-27672; JPL D-56935 §4.2.14; SYSU LRI1B documentation, Table 1 |
| V-3 | LRI1B uses the KBR1B 16-column layout. Light-time correction additive; antenna-centre columns zero for LRI in RL04; no ionospheric correction for laser ranging; the "iono" slot carries a multiplicative scale; `Ka_B_SNR` carries the LRI–KBR time offset in ns | JPL D-56935 §3.3.2, §4.2.11, §4.2.14 — and the real header of LRI1B_2020-01-01_Y_04 |
| V-4 | TU Graz ACT is calibrated/recovered accelerometer data; the operational `nonConservativeForces` file itself stays **unresolved** — verify from the file and its README | ITSG server README; Behzadpour et al. 2021 |
| V-5 | GRACE-D uses the GRACE-C transplant from 2018-06-21; ACT exists for both satellites; hybrid ACH1B (ACX/ACX2) is used by RL06.3 | JPL D-103863; Bandikova et al. 2019; Harvey et al. 2022 |
| V-8 | Classic formats per the GRACE L1B handbook; classic KBR1B `qualflg` bit 0 threshold 0.2 cycle | JPL D-22027 — and the real classic files (G-02) |
| V-9 | GRACE macro model: Bettadpur (2012); exact document number **not found** | CSR / PO.DAAC; to be supplied |
| V-10 | ACC thermal control permanently off from April 2011; GRACE-B accelerometer off 2016–2017, GRACE-A → B transplant | Tapley et al. 2015; Behzadpour et al. 2021 |
| V-11 | external oracles: Klinger & Mayer-Gürr 2016 (daily bias/scale), Behzadpour et al. 2021, Harvey et al. 2022, Siemes et al. 2023 (density datasets with calibration) | the publications and their data sets |
| release | GRACE-FO L1B RL04 is current; no L1B RL05 announced; the SDS reprocessed the accelerometer transplant (ACX → ACX2) for gravity RL06.3 (2024-11-07); RL07 in preparation | PO.DAAC release notes, GRACE-FO SDS newsletters |

---

## 10. Work packages and global order

Each WP follows the same procedure: freeze the scope in the owning
repository's HANDOVER, work on one branch, open a draft PR at once, and put
the help block, tests and regenerated documentation in the same change. Each
repository has one open PR at a time.

### 10.1 Work packages

| repo | WP | content | replaces v3 | needs |
|---|---|---|---|---|
| gracefoReading | G-01 | O-11: `readL1bMulti` accepts `findL1bFiles`' column | — | — |
| gracefoReading | G-03 | O-7 measured (item 13): parse time of one real ACT1B day and the extrapolated year; decide on the fixed-layout fast path from the number | — | G-01 |
| gracefoReading | G-02 | O-1 discharge: classic layouts confirmed or corrected against real files, `classicExperimental` warning removed, files added to `tests/realdata/` | — | owner supplies files (V-8) |
| gracefoReading | G-04 | ACH1B (ACX/ACX2), accelerometer housekeeping (V-13) and the LRI thermal-coupling temperature product (V-14): real fixtures, generic reader verified on each, `testRealData` rows | — | V-13, V-14, V-16 |
| gracefoReading | G-05 | reader for the official event lists (TN-01 SOE, TN-01a SCE, CMC and KBR calibration manoeuvres), both missions; returns an event table with provenance | — | V-15 |
| gracefoReading | G-06 | data-pool verification: every pool file checked against the source's published checksum or a recorded SHA-256 manifest | — | V-15 |
| referenceSystem | R-01 | `orbitSunGeometry` (#25) | WP-16 part | — |
| referenceSystem | R-02 | int64 GPS nanoseconds as an epoch representation (to and from), exact integer arithmetic | WP-02 part | — |
| ci-actions | C-01 | shared static audit as a versioned action: help template, footer, error-identifier agreement, catalogue; per-repository configuration | — | — |
| ci-actions | C-02 | ecosystem compatibility file (version sets tested together) and its update rule | — | — |
| ci-actions | C-03 | shared documentation generator: help blocks → HTML, `helptoc.xml`, `info.xml`, search database, error-identifier catalogue, `testHelpExamples` | WP-23 | C-01 |
| ci-actions | C-04 | ecosystem job: the processing-chain page executed on 2020-01-01 across all toolboxes | — | N-02, L-05 |
| lsqvce | V-6 | read-only: confirm the surface N-02 and L-03 declare against | — | — |
| timeSeriesPreparation | X-00a | create the repository with documents only; move this folder and `inputs/` here; reduce gracefoReading #15 to a pointer and the G-01/G-02 records | — | — |
| timeSeriesPreparation | X-00b | skeleton, CI (ci-actions probe and C-01 audit), documentation pipeline, test tags, layering test, optional-gracefoReading resolution | WP-00, WP-05 | X-00a, C-01 |
| timeSeriesPreparation | X-01 | **sigtools import**: `+spectral`, `+tsmodels`, demos, tests; numerics byte-identical; imported suite green and counted | — | X-00b |
| timeSeriesPreparation | X-02 | sigtools conventions: `arguments` blocks (24 of 26 files lack one), prefixed error identifiers, plotting split out of the four functions whose code plots (`allanVariance`, `plotPowerSpectrum`, `psd2arma`, `tsCheckResiduals`), one shared Lyapunov solver (four local copies today). Numbers unchanged; ORC-8 is the gate. Hand-made HTML replaced by C-03 output | — | X-01, C-03 |
| timeSeriesPreparation | X-03 | `Arc`, `Config` skeleton; `contract` tests pinning gracefoReading's `aux` fields; release version in the metadata and the one-release rule (5.2) | WP-01 | X-00b |
| timeSeriesPreparation | X-04 | `crnKernel` (ACC; KBR/LRI after V-2), `crnApply` with output-epoch evaluation (item 11) → **release 0.1** | WP-10 | X-03 |
| timeSeriesPreparation | X-05 | `mask`, `qc` (port of NonGravForces.qc 0.12.0, **unchanged**, its tests as gate); defect-catalogue tests (ORC-11) → **release 0.2** | WP-06 | X-04, V-12 |
| timeSeriesPreparation | X-06 | `align`, `checkAlignment`, unit check (5.2) | WP-02 part, WP-11 part | X-04 |
| timeSeriesPreparation | X-07 | noise stage on `tsmodels`/`spectral`, `observability` with the minimum-data gate (5.2), `bootstrap`, `crossval`; **Q12 agreement test**: `arma2acv`↔`lsqvce.kernel.armaACV`, `spec2acv`↔`psd2acv`, `tsLjungBox`↔`whitenessCorr`, `tsFitAR`↔`levinsonDurbin`/`whittle`, each with a tolerance naming the term it bounds (lsqvce is a test-only dependency) | WP-07, WP-12, WP-15 part | X-02, X-03 |
| timeSeriesPreparation | X-08 | `fill` | — | X-07, V-7 |
| timeSeriesPreparation | X-09 | `drivers`, `correlate` | WP-17 part | X-07 |
| timeSeriesPreparation | X-10 | `run`, full `Config`, integration test (real ACT1B against the ITSG reference; synthetic) → **release 1.0** | WP-19 part | X-03..X-09 |
| timeSeriesPreparation | X-11 | `report` | WP-20 part | X-10 |
| timeSeriesPreparation | X-12 | V-1 CRN verification | WP-24 | handbook |
| timeSeriesPreparation | X-14 | stage cache (6.6) | — | X-10 |
| timeSeriesPreparation | X-16 | QC speed (item 12): `hampel` on `movmedian` with an exact window MAD, jump detection's candidate bookkeeping vectorised (or a C layer); gated by equality to the X-05 port | — | X-05, X-14 |
| timeSeriesPreparation | X-17 | QC template bank (twang, heater, magnetic torquer, thruster), one mask layer per type, tested on the defect catalogue | — | X-16, V-12 |
| timeSeriesPreparation | X-18 | CF/ACDD NetCDF export with PROV-O provenance and DataCite fields; Arc schema version and migration | — | X-15 |
| timeSeriesPreparation | X-15 | campaign mode of `run` (6.6), per-day storage and the per-campaign manifest (5.2) → **release 1.1** | WP-19 part (`runBatch`) | X-14, X-16, G-03 |
| timeSeriesPreparation | X-13 | classic GRACE: dictionaries, masks (`qualflg` per V-8), `Config` presets, classic fixtures in the integration test | — | G-02, X-10 |
| NonGravForces | N-04 | `sensor.Electrostatic` takes its default kernel from `crnKernel` | — | release 0.1 |
| NonGravForces | N-01 | `qc` forwards to timeSeriesPreparation, then is deleted | — | release 0.2 |
| NonGravForces | N-02 | `app.calibrate` upgraded (6.2), estimation via `lsqvce.fit`, `app.Calibration`, truth generator, integration test | WP-08, WP-09, WP-13, WP-18, WP-21 | release 1.0, V-6, R-02 |
| NonGravForces | N-03 | time-varying scale, model comparison, per-revolution, attribution | WP-14, WP-16 part, WP-17 part | N-02, R-01 |
| NonGravForces | N-05 | calibration figures | WP-20 part | N-03 |
| NonGravForces | N-06 | records: A.2 rule, dependency table, B.4 | — | with N-02 |
| NonGravForces | N-09 | multi-arc calibration (6.6): per-arc biases pre-eliminated in lsqvce, common or per-arc scale | WP-19 part | N-03, release 1.1 |
| NonGravForces | N-10 | regression baseline 2020-01 C/D (ORC-10), classic month after N-08 | — | N-09 |
| NonGravForces | N-11 | temperature bias regressor, temperature-dependent full scale matrix, magnetic-torquer regressor | — | N-02, G-04, V-13 |
| NonGravForces | N-12 | alternative attitude sources in `geom.AttitudeProvider` (ITSG, SCA+IMU fusion products) and an attitude-quality diagnostic | — | N-02 |
| NonGravForces | N-07 | `geom.grace` macro model (GRACE-A/B) | — | V-9 |
| NonGravForces | N-08 | classic calibration: presets, thermal handling (V-10), integration test on real A/B data | — | N-02, N-07, X-13, V-10 |
| rangingPreparation | L-00 | repository, as X-00b | — | C-01 |
| rangingPreparation | L-01 | `observables` | — | L-00, V-3 |
| rangingPreparation | L-04 | `spectrum` (on `+spectral`) | — | L-01, X-02 |
| rangingPreparation | L-02 | `detectPhaseJumps` | — | L-01, release 0.2 |
| rangingPreparation | L-03 | `compareKbr` | — | L-02, X-06, V-2, V-6 |
| rangingPreparation | L-05 | `process`, truth generator, integration test, report | — | L-01..L-04, release 1.0, R-01 |
| rangingPreparation | L-06 | classic GRACE KBR: dictionary, presets, integration test | — | L-05, X-13 |
| rangingPreparation | L-07 | KBR antenna-offset QC from attitude, multipath flag on calibration-manoeuvre windows | — | L-05, N-12, G-05 |
| rangingPreparation | L-08 | KBR↔LRI time-tag co-estimation, optional clock-offset low-pass | — | L-03 |
| rangingPreparation | L-09 | continuous LRI scale with thermal-coupling regressor; deglitching benchmark (ORC-13) | — | L-03, G-04, V-14 |

### 10.2 Global order and procedures

The order of work over all repositories, the preparation of repositories,
data and references, and the procedure for every step (branch, audit, gate,
PR, merge, tag, record) live in **`GUIDE.md`** in this folder. That file is
their only authority; this section is not a copy of it.

---

## 11. Decisions

| id | question | status |
|---|---|---|
| Q1 | Dependency direction | **decided: one-way** (graph 3.1) |
| Q2 | Estimator core | **decided: `lsqvce.fit`**, called directly by each application; timeSeriesPreparation contains no least-squares estimator |
| Q3 | Default gap filling | **decided: `none`**; collocation up to `maxGap` on request; `maxGap` has no default |
| Q4 | LRI analysis beyond L1B-internal checks and the KBR comparison? | **decided 2026-09-18: no orbit integration and no LGD** in rangingPreparation |
| Q5 | Help footer | **decided for gracefoReading: keep its rule.** New repositories: proposal in force — date, time and model in the footer, as referenceSystem does and as the owner's standing instruction asks |
| Q6 | Classic GRACE? | **decided 2026-09-18: supported as well**; the owner supplies real files when the work starts (G-02); classic WPs X-13, N-07, N-08, L-06 |
| Q7 | Where does ACC calibration live? | **decided: NonGravForces `app`**, upgraded in place |
| Q8 | Owner of β′ and argument of latitude | **decided: referenceSystem** (#25) |
| Q9 | Where does LRI/KBR processing live? | **decided: a toolbox of its own** |
| Q10 | Where do Arc, the CRN kernel, masks, QC, gaps and correlation live? | **decided: a shared toolbox**, named **timeSeriesPreparation** (owner, 2026-09-18) |
| Q11 | Name of the LRI/KBR toolbox | **decided 2026-09-18: rangingPreparation** |
| Q12 | sigtools and lsqvce both implement ARMA autocovariance (`arma2acv` / `armaACV`), PSD→ACV (`spec2acv` / `psd2acv`), Ljung-Box (`tsLjungBox` / `whitenessCorr`) and AR fitting (`tsFitAR` / `levinsonDurbin`, `whittle`) | **decided 2026-09-18: keep both**, with a mechanical agreement test in timeSeriesPreparation (X-07; lsqvce as a test-only dependency). The copies serve different roles: user-facing analysis versus batched whitening inside the adjustment. Making either call the other adds a dependency in one direction |
| Q13 | Is sigtools included whole, or only the parts the pipeline uses? | **decided: included** (owner, 2026-09-18); proposal in force: whole, since nothing else owns it |
| Q14 | Improvements 1–9 proposed 2026-09-18 | **decided 2026-09-18: all adopted** — R-02, X-15/N-09, X-14, N-10/ORC-10, X-00a, decisions recorded once, C-01, C-02, X-02 moved before X-07 |
| Q15 | Improvements 11–20 proposed 2026-09-18 | **decided 2026-09-18: all adopted** — output-epoch CRN (X-04), unchanged QC port then X-16, G-03, streaming multi-arc (N-09), ORC-11/V-12, minimum-data gate and fault injection, 5.1, 5.2, 9.1 with C-03 and C-04 |
| Q16 | Distribute the deep-research findings of 2026-09-18 | **decided 2026-09-18: yes** — W-1…W-15 mapped to G-04…G-06, X-17, X-18, N-11, N-12, L-07…L-09, ORC-12/13, V-13…V-16; the three CRN presets (V-1, V-2) are expected values until read from the documents |

---

## 12. What a next session would be wrong for not reading

1. **The order of work and every procedure are in `GUIDE.md`.** Follow it;
   do not reconstruct them from this file.
2. gracefoReading gains **no preprocessing code**; G-01 (O-11) and G-02
   (O-1, classic layouts) are reader fixes. This folder moves at X-00a, which
   comes first.
3. **Decisions live in section 11 only.** A HANDOVER cites the Q-id and
   states the consequence for its own repository; it never restates the
   decision.
4. X-02 comes after X-06, not after X-01: do not "restore" the early
   position.
5. Ported code (sigtools, `qc`) moves unchanged first; speed and conventions
   change in their own WPs (X-02, X-16), gated by equality to the port.
6. The processing-chain page belongs to `ci-actions` (C-04), at the top of the
   graph, not to any toolbox.
7. Classic GRACE is in scope (Q6), but nothing classic is built on the
   unvalidated layouts: G-02 with real files comes first.
8. The two draft PRs (gracefoReading #15, NonGravForces #57) are **not ready
   to merge**: the owner said so on 2026-09-18.
9. sigtools moves **unchanged** first (X-01), then changes conventions (X-02)
   with its own tests as the gate. Never mix the two.
10. Calibration stays in NonGravForces. Only `qc` leaves NonGravForces, and it
   goes to timeSeriesPreparation.
11. timeSeriesPreparation contains no least-squares estimator. The
   applications call `lsqvce.fit`.
12. β′ and u belong to referenceSystem (#25). rangingPreparation does not depend on
   NonGravForces.
13. Do not implement from the v3 handover's Part IV; section 10 maps every WP.
14. The legacy AccelBiasScaleToolbox zip is v2.4.2, not the v2.5.0 that the
   v3 handover reviewed.
