# CONCEPT — GRACE-FO time-series preparation, accelerometer calibration, LRI/KBR processing

**Revision 0.7 (DRAFT) · 2026-09-18 · written with Claude Opus 5 (Anthropic)**

This file is the **single point of truth for the design** of one pipeline
spanning six toolboxes. Each repository's HANDOVER stays the single point of
truth for its own status, obligations and decisions and points here
(gracefoReading O-13, NonGravForces O-45, referenceSystem #25).

Nothing in this file is implemented yet.

**Hosting.** This file lives in gracefoReading only until the
timeSeriesPreparation repository exists. X-00 moves this folder there and
leaves a pointer behind. gracefoReading itself gains **no code**.

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
| **0.7** | **Q11: LRI/KBR toolbox named rangingPreparation; Q12: sigtools and lsqvce kernels both kept, with a mechanical agreement test** |

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
| gracefoReading | reading L1B, ITSG and GROOPS files | **nothing** (pure reader) |
| **timeSeriesPreparation** (new) | physics-free time-series preparation and analysis | sigtools v1.3.1 (spectra, ARMA/SARIMA models, synthesis, diagnostics); the `Arc` container, CRN kernel, masks, QC, alignment, gaps, observability, bootstrap, blocked CV, correlation; entry point `run` |
| NonGravForces | forces, environment, the ACC calibration application | `app.calibrate` upgraded in place; `qc` leaves for timeSeriesPreparation |
| **rangingPreparation** (new) | LRI/KBR processing and analysis | observables, phase jumps, KBR↔LRI comparison, spectra; entry point `process` |
| lsqvce | least squares | nothing; the one estimator, called by the applications |

Out of scope: orbit and gravity estimation, LGD, mascons. GRACE-FO comes
first; classic GRACE is blocked by gracefoReading O-1.

---

## 2. Authority map — one owner per capability (R1)

| capability | authority | consequence |
|---|---|---|
| L1B / ITSG / GROOPS reading | gracefoReading | v3 `+io` **retired** |
| qualflg bit meanings | the file's own header, via `gracefoReading.decodeQualFlags` | v3 handbook bit table **retired** (O-1 lesson) |
| gaps and segments | `gracefoReading.findGaps` | used by `fill` |
| int64 GPS-ns epochs | `gracefoReading.readL1b 'TimeFormat' "gpsns"` | `Arc` accepts gpsns only |
| time scales, rotations, quaternions, Sun | referenceSystem | v3 `+time` **retired** |
| β′, argument of latitude | referenceSystem `orbitSunGeometry` (#25) | enter as driver data |
| orbit in the celestial frame | `NonGravForces.io.readGNV1B`, ITSG `reducedDynamicOrbit`, or GNV1B + `referenceSystem.rotationItrsToGcrs` | input to `orbitSunGeometry`; timeSeriesPreparation never rotates an orbit |
| modelled non-gravitational acceleration, per effect | `NonGravForces.Model` (`series`, `budget`) | used inside `app.calibrate`; external references enter as an `Arc` |
| eclipse factor, space weather | `NonGravForces.env.eclipseFactor`, `io.spaceWeather` | driver data outside NonGravForces |
| spectra (Welch, Lomb-Scargle), Allan deviation, PSD↔ACV, ARMA↔PSD, ARMA ACV, noise synthesis, ARIMA/SARIMA exact ML with gaps, ACF/PACF (gap-aware), Ljung-Box, residual diagnostics | **timeSeriesPreparation** (from sigtools v1.3.1) | v3 `+noise`, `lombScarglePSD` and the synthetic-noise parts of `syntheticPair` **retired**; overlap with lsqvce kernels is Q12 |
| exact ATBD CRN kernel and its derivative kernels, presets for ACC, KBR and LRI | **timeSeriesPreparation** `crnKernel` (port of v2 `crnFilter`) | consumed by NonGravForces and rangingPreparation |
| residual QC: Hampel, impulses, jumps, event table | `NonGravForces.qc` 0.12.0 → **timeSeriesPreparation** `qc` | ported; NonGravForces forwards for one release, then deletes (N-01) |
| least-squares estimation | **`lsqvce.fit`**, called by each application for its own problem | `app.calibrate`'s own QR solver **retired**; v3 `fit.solve` **retired**; timeSeriesPreparation contains no least-squares estimator |
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
| `product`, `satellite`, `frame`, `frameSource` | string | `aux`. A frame not stated by the file or an explicit option stays `""`, and a stage needing it refuses (v3 F5) |
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

---

## 6. Pipeline

### 6.1 Instrument stages (timeSeriesPreparation)

| # | stage | function | guarantee |
|---|---|---|---|
| 1 | mask | `mask` | qualflg layers via `decodeQualFlags`; THR1B windows (margins justified by the CRN span); eclipse transitions from a driver series; CRN edges; a user layer |
| 2 | QC | `qc` | residual-based outliers; impulses (matched filter on the CRN impulse response, THR1B priors); jumps (reported and turned into parameters, never masked) |
| 3 | align | `align`, `checkAlignment` | reference moved onto the observation epochs; lag diagnostic over ±60 s that warns above 1 s and never shifts silently (v3 F2) |
| 4 | consistency | `crnKernel`, `crnApply` | exact ATBD kernel normalised at f0, DC gain 1.0004533 kept; chunked per file day with half-span overlap, bit-identical to unchunked; NaN edges |
| 5 | noise | `tsmodels`, `spectral` | residual noise model (AR/ARMA/SARIMA exact ML with gaps, or PSD → ARMA), Ljung-Box, Allan deviation; the model feeds `fill` and the applications' lsqvce covariance |
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
- Residuals against a reference orbit or gravity field are out of scope (Q4).

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
| sigtools numerics move unchanged; conventions change afterwards, in a separate WP | any numerical change must be attributable to a WP that says so |

GRACE-FO CRN parameters are the GRACE ATBD ones and are unverified for
GRACE-FO (V-1). `crnKernel` warns until a named constant cites the handbook.

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

| id | verification item (from documents or real bytes, never memory) | blocks |
|---|---|---|
| V-1 | GRACE-FO ACC CRN parameters vs JPL D-56935 | removing the `crnKernel` warning |
| V-2 | KBR1B and LRI1B CRN parameters | rangingPreparation CRN presets |
| V-3 | LRI1B correction columns, signs and units from the real header | L-01 |
| V-4 | ITSG `nonConservativeForces`: model or calibrated measurement? CRN-filtered? | ORC-4 |
| V-5 | the ACT1B satellite-D transplant statement in the header | N-02 report wording |
| V-6 | lsqvce 6.1: local parameters + priors + ARMA/PSD + robust in one `fit` call, read from source | N-02, L-03 |
| V-7 | sigtools: does the gap-aware Kalman filter smooth (interpolate) or only filter/forecast? If only the latter, `fill` adds a fixed-interval smoother on the same state space | X-08 |

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
| referenceSystem | R-01 | `orbitSunGeometry` (#25) | WP-16 part | — |
| lsqvce | V-6 | read-only: confirm the surface N-02 and L-03 declare against | — | — |
| timeSeriesPreparation | X-00 | repository, CI (ci-actions probe), documentation pipeline, test tags, layering test, optional-gracefoReading resolution; move this folder here | WP-00, WP-05 | — |
| timeSeriesPreparation | X-01 | **sigtools import**: `+spectral`, `+tsmodels`, demos, tests; numerics byte-identical; imported suite green and counted | — | X-00 |
| timeSeriesPreparation | X-02 | sigtools conventions: `arguments` blocks (24 of 26 files lack one), prefixed error identifiers, plotting split out of the four functions whose code plots (`allanVariance`, `plotPowerSpectrum`, `psd2arma`, `tsCheckResiduals`), one shared Lyapunov solver (four local copies today). Numbers unchanged; ORC-8 is the gate | — | X-01 |
| timeSeriesPreparation | X-03 | `Arc`, `Config` skeleton | WP-01 | X-00 |
| timeSeriesPreparation | X-04 | `crnKernel` (ACC; KBR/LRI after V-2), `crnApply` → **release 0.1** | WP-10 | X-03 |
| timeSeriesPreparation | X-05 | `mask`, `qc` (port of NonGravForces.qc 0.12.0) → **release 0.2** | WP-06 | X-04 |
| timeSeriesPreparation | X-06 | `align`, `checkAlignment` | WP-02 part, WP-11 part | X-04 |
| timeSeriesPreparation | X-07 | noise stage on `tsmodels`/`spectral`, `observability`, `bootstrap`, `crossval`; **Q12 agreement test**: `arma2acv`↔`lsqvce.kernel.armaACV`, `spec2acv`↔`psd2acv`, `tsLjungBox`↔`whitenessCorr`, `tsFitAR`↔`levinsonDurbin`/`whittle`, each with a tolerance naming the term it bounds (lsqvce is a test-only dependency) | WP-07, WP-12, WP-15 part | X-02, X-03 |
| timeSeriesPreparation | X-08 | `fill` | — | X-07, V-7 |
| timeSeriesPreparation | X-09 | `drivers`, `correlate` | WP-17 part | X-07 |
| timeSeriesPreparation | X-10 | `run`, full `Config`, integration test (real ACT1B against the ITSG reference; synthetic) → **release 1.0** | WP-19 part | X-03..X-09 |
| timeSeriesPreparation | X-11 | `report` | WP-20 part | X-10 |
| timeSeriesPreparation | X-12 | V-1 CRN verification | WP-24 | handbook |
| NonGravForces | N-04 | `sensor.Electrostatic` takes its default kernel from `crnKernel` | — | release 0.1 |
| NonGravForces | N-01 | `qc` forwards to timeSeriesPreparation, then is deleted | — | release 0.2 |
| NonGravForces | N-02 | `app.calibrate` upgraded (6.2), estimation via `lsqvce.fit`, `app.Calibration`, truth generator, integration test | WP-08, WP-09, WP-13, WP-18, WP-21 | release 1.0, V-6 |
| NonGravForces | N-03 | time-varying scale, model comparison, per-revolution, attribution | WP-14, WP-16 part, WP-17 part | N-02, R-01 |
| NonGravForces | N-05 | calibration figures | WP-20 part | N-03 |
| NonGravForces | N-06 | records: A.2 rule, dependency table, B.4 | — | with N-02 |
| rangingPreparation | L-00 | repository, as X-00 | — | X-00 |
| rangingPreparation | L-01 | `observables` | — | L-00, V-3 |
| rangingPreparation | L-04 | `spectrum` (on `+spectral`) | — | L-01, X-02 |
| rangingPreparation | L-02 | `detectPhaseJumps` | — | L-01, release 0.2 |
| rangingPreparation | L-03 | `compareKbr` | — | L-02, X-06, V-2, V-6 |
| rangingPreparation | L-05 | `process`, truth generator, integration test, report | — | L-01..L-04, release 1.0, R-01 |

### 10.2 Global order — why this sequence

**Principles.**
1. Build from the bottom of the dependency graph upward.
2. Settle facts that could change a design (V-items) before building on them.
3. Ship small releases early, so downstream repositories can work in
   parallel.
4. Keep one open PR per repository.

**Phase 0 — decisions and reading, no code (days).**
- Q11 and Q12 are decided (rev 0.7).
- Read V-3 and V-5 from the pool's real headers, V-4 from the ITSG README,
  and V-6 from the lsqvce source.
- V-1 and V-2 need the handbooks. Establish whether they are available now,
  because V-2 is the only item that can block rangingPreparation late.

**Phase 1 — foundations, three repositories in parallel.**

| repo | sequence |
|---|---|
| gracefoReading | G-01 |
| referenceSystem | R-01 |
| timeSeriesPreparation | X-00 → X-01 → X-02 |

- G-01 and R-01 are small, independent, and needed by everything later.
- The sigtools import comes first in the new repository because it tests the
  fresh harness (CI, documentation, category audit) on 26 existing files
  with an existing oracle before any new code is written.
- The conventions work X-02 follows immediately, so nothing new is built
  against an API that is about to change.

**Phase 2 — the critical path, in timeSeriesPreparation:**
X-03 → X-04 (**0.1**) → X-05 (**0.2**) → X-06 → X-07 → X-08 → X-09 → X-10 (**1.0**).

Downstream work starts early, one PR at a time per repository:
- as soon as 0.1 is out: N-04, and L-00 → L-01 → L-04;
- as soon as 0.2 is out: N-01, and L-02.

**Phase 3 — applications, after 1.0.**

| repo | sequence |
|---|---|
| NonGravForces | N-02 (+ N-06) → N-03 → N-05 |
| rangingPreparation | L-03 → L-05 |

**Phase 4 — X-11 reports, and X-12 whenever the handbook is available.**

**Critical path:** X-00 → X-01 → X-02 → X-03 → X-04 → X-05 → X-06 → X-07 →
X-10 → N-02 → N-03 → N-05, about twelve WPs deep. Everything else runs
beside it.

**Largest schedule risks:**
- V-2: KBR/LRI CRN parameters from the handbook;
- V-6: whether lsqvce's surface matches what N-02 declares;
- X-02's size: 26 files, about 5 000 lines.

---

## 11. Decisions

| id | question | status |
|---|---|---|
| Q1 | Dependency direction | **decided: one-way** (graph 3.1) |
| Q2 | Estimator core | **decided: `lsqvce.fit`**, called directly by each application; timeSeriesPreparation contains no least-squares estimator |
| Q3 | Default gap filling | **decided: `none`**; collocation up to `maxGap` on request; `maxGap` has no default |
| Q4 | LRI analysis beyond L1B-internal checks and the KBR comparison? | open — proposal in force: no; LGD and orbit residuals stay downstream |
| Q5 | Help footer | **decided for gracefoReading: keep its rule.** New repositories: proposal in force — date, time and model in the footer, as referenceSystem does and as the owner's standing instruction asks |
| Q6 | Classic GRACE? | open — proposal in force: no; after gracefoReading O-1 |
| Q7 | Where does ACC calibration live? | **decided: NonGravForces `app`**, upgraded in place |
| Q8 | Owner of β′ and argument of latitude | **decided: referenceSystem** (#25) |
| Q9 | Where does LRI/KBR processing live? | **decided: a toolbox of its own** |
| Q10 | Where do Arc, the CRN kernel, masks, QC, gaps and correlation live? | **decided: a shared toolbox**, named **timeSeriesPreparation** (owner, 2026-09-18) |
| Q11 | Name of the LRI/KBR toolbox | **decided 2026-09-18: rangingPreparation** |
| Q12 | sigtools and lsqvce both implement ARMA autocovariance (`arma2acv` / `armaACV`), PSD→ACV (`spec2acv` / `psd2acv`), Ljung-Box (`tsLjungBox` / `whitenessCorr`) and AR fitting (`tsFitAR` / `levinsonDurbin`, `whittle`) | **decided 2026-09-18: keep both**, with a mechanical agreement test in timeSeriesPreparation (X-07; lsqvce as a test-only dependency). The copies serve different roles: user-facing analysis versus batched whitening inside the adjustment. Making either call the other adds a dependency in one direction |
| Q13 | Is sigtools included whole, or only the parts the pipeline uses? | **decided: included** (owner, 2026-09-18); proposal in force: whole, since nothing else owns it |

---

## 12. What a next session would be wrong for not reading

1. gracefoReading gains **no code** from this concept; G-01 (O-11) is its
   own fix. This folder moves at X-00.
2. The two draft PRs (gracefoReading #15, NonGravForces #57) are **not ready
   to merge**: the owner said so on 2026-09-18.
3. sigtools moves **unchanged** first (X-01), then changes conventions (X-02)
   with its own tests as the gate. Never mix the two.
4. Calibration stays in NonGravForces. Only `qc` leaves NonGravForces, and it
   goes to timeSeriesPreparation.
5. timeSeriesPreparation contains no least-squares estimator. The
   applications call `lsqvce.fit`.
6. β′ and u belong to referenceSystem (#25). rangingPreparation does not depend on
   NonGravForces.
7. Do not implement from the v3 handover's Part IV; section 10 maps every WP.
8. The legacy AccelBiasScaleToolbox zip is v2.4.2, not the v2.5.0 that the
   v3 handover reviewed.
