# CONCEPT — GRACE-FO instrument preprocessing, accelerometer calibration, LRI/KBR processing

**Revision 0.5 (DRAFT) · 2026-09-18 · written with Claude Opus 5 (Anthropic)**

This file is the **single point of truth for the design** of one pipeline
that spans five toolboxes. Each repository's own HANDOVER stays the single
point of truth for its status, obligations and decisions and points here
(gracefoReading O-13, NonGravForces O-45, referenceSystem #25). Nothing in
this file is implemented yet.

**Hosting.** This file lives in gracefoReading only until the preprocessing
repository exists. X-00 moves it and `inputs/` there and leaves a pointer
here. gracefoReading itself gains **no code** from this concept.

History: Rev 0.1 draft · 0.2 Q1–Q3 · 0.3 Q5 · 0.4 Q7 (ACC calibration in
NonGravForces) · 0.4a Q8, Q9 · **0.5 Q10: a shared preprocessing toolbox;
full restructure** (owner, 2026-09-18, section 11).

Read at: gracefoReading `a18e9ad` (v1.0.2) · referenceSystem `311e060`
(2.1.244) · NonGravForces `3cc0123` (0.12.0) · lsqvce `ac981cd` (6.1).
Inputs: `inputs/README.md` (AccelCal v3 handover, AccelBiasScaleToolbox
v2.4.2).

---

## 1. Why, and where each part lives

GRACE-FO Level-1B series are not usable as delivered: spurious samples must
be found and down-weighted, systematic effects must be pre-estimated or
pre-eliminated, gaps must be bridged for consumers that need continuity, and
hidden dependencies (β′ angle, eclipse, solar activity, SNR) must be made
visible by correlation analysis.

**Each capability sits with the toolbox whose domain it is; applications sit
above what they use.** *Working names* `preproc` and `ranging` stand until
Q11.

| toolbox | domain | new in this concept |
|---|---|---|
| referenceSystem | time, frames, ephemerides, orbit geometry | `orbitSunGeometry`: β′, argument of latitude (#25) |
| gracefoReading | reading L1B / ITSG / GROOPS | **nothing** (pure reader, unchanged) |
| **preproc** (new) | physics-free instrument preprocessing for any L1B series | `Arc`, `Config`, CRN kernel, masks, QC, alignment, gaps, observability, bootstrap, blocked CV, correlation, `run` |
| NonGravForces | forces, environment, and the ACC calibration application | `app.calibrate` upgraded in place; `qc` leaves (to preproc) |
| **ranging** (new) | LRI/KBR processing and analysis | observables, phase jumps, KBR↔LRI comparison, spectra, `process` |
| lsqvce | least squares | nothing; the one estimator, called by the applications |

Out of scope: orbit and gravity estimation, LGD, mascons. GRACE-FO first;
classic GRACE is blocked by gracefoReading O-1.

---

## 2. Authority map — one owner per capability (R1)

| capability | authority | consequence |
|---|---|---|
| L1B / ITSG / GROOPS reading | gracefoReading | v3 `+io` **retired** |
| qualflg bit meanings | the file's own header via `gracefoReading.decodeQualFlags` | v3 handbook bit table **retired** (O-1 lesson) |
| gaps, segments | `gracefoReading.findGaps` | used by `preproc.fill` |
| int64 GPS-ns epochs | `gracefoReading.readL1b 'TimeFormat' "gpsns"` | `preproc.Arc` accepts gpsns only |
| time scales, rotations, quaternions, Sun | referenceSystem | v3 `+time` **retired** |
| β′, argument of latitude | **referenceSystem `orbitSunGeometry`** (#25) | enter preproc and ranging as driver data |
| orbit in the celestial frame | `NonGravForces.io.readGNV1B` · ITSG `reducedDynamicOrbit` · GNV1B + `referenceSystem.rotationItrsToGcrs` | input to `orbitSunGeometry`; preproc never rotates |
| modelled non-gravitational acceleration, per effect | `NonGravForces.Model` (`series`, `budget`) | inside `app.calibrate`; external references enter as an `Arc` |
| eclipse factor, space weather | `NonGravForces.env.eclipseFactor`, `io.spaceWeather` | used by `app.calibrate`; driver data elsewhere |
| exact ATBD CRN kernel + derivative kernels, ACC/KBR/LRI presets | **preproc** `crnKernel` (port of v2 `crnFilter`) | NonGravForces (`sensor.Electrostatic`, calibration) and ranging consume it |
| residual QC: Hampel, impulses, jumps, event table | `NonGravForces.qc` 0.12.0 → **`preproc.qc`** | ported; NonGravForces forwards for one release, then deletes (N-01) |
| least-squares estimation | **`lsqvce.fit`**, called by each application for its own problem | `app.calibrate`'s own QR retired (N-02); v3 `fit.solve`, `+noise` **retired**; preproc is estimator-agnostic |
| instrument settings | `preproc.Config` | embedded in each application's options; hashed with them into provenance |

---

## 3. Architecture

### 3.1 Dependency graph (acyclic)

```
referenceSystem  <------------------------------+--------------------+
gracefoReading   <-- preproc  <-- NonGravForces-+  (+ lsqvce)        |
      ^                  ^                                           |
      +------------------+------- ranging -------------------------- +  (+ lsqvce)
```

| toolbox | depends on |
|---|---|
| preproc | gracefoReading only |
| NonGravForces | referenceSystem, gracefoReading, preproc, lsqvce; gjToolbox optional |
| ranging | referenceSystem, gracefoReading, preproc, lsqvce |

Checked 2026-09-18: no `.m` file of lsqvce `ac981cd` or referenceSystem
`311e060` calls gracefoReading or NonGravForces. ranging does **not** depend
on NonGravForces; eclipse or space weather, if wanted as drivers, arrive as
data.

### 3.2 preproc layers (downward calls only, tested mechanically)

```
L3  preproc.run                                  single point of access, instrument level
L2  mask, qc, align, crnApply, fill, observability, bootstrap, crossval, drivers, correlate, report
L1  Arc, Config, crnKernel
```

- A missing dependency errors at the point of use with
  `preproc:<fn>:depMissing` naming the setup function (R4).
- **No estimator inside preproc.** `bootstrap` and `crossval` take a
  statistic handle; `fill` with collocation takes a covariance model (from
  lsqvce or any source) and refuses without one.

### 3.3 NonGravForces

The calibration application stays in the `app` layer (L8) and calls preproc
and lsqvce by qualified name. lsqvce **re-enters** its dependency table:
NonGravForces B.4 named the re-entry condition itself, and coloured-noise GLS
with multi-arc pre-elimination meets it. Its governing rule (A.2, "computes
forces and torques and nothing else") is reworded to admit the `app` layer
(N-06).

---

## 4. Single points of access

**Instrument level — preproc**, chained after reading; the product is read
from the file and chooses the preset (R3):

```matlab
[t, a, aux] = gracefoReading.readL1bMulti(files, 'TimeFormat', "gpsns");
acc = preproc.Arc(t, a, aux);
res = preproc.run(acc, 'Reference', ref);                % masks, QC, CRN, gaps, report
```

**Accelerometer calibration — NonGravForces**:

```matlab
M   = NonGravForces.Model(NonGravForces.geom.graceFO("C"), NonGravForces.Options("standard"), ...
                          'Eop', eop, 'SpaceWeather', sw);
res = NonGravForces.app.calibrate(acc, M, 'Orbit', orb, 'Attitude', att);   % a priori from M
res = NonGravForces.app.calibrate(acc, itsgArc);                           % external reference
```

- With a `Model`, `'Orbit'` (GNV1B via `io.readGNV1B`) and `'Attitude'`
  (SCA1B via `io.readSCA1B`) are required. The a priori acceleration is
  evaluated **per effect** on the ACC epochs through `Model.budget`, which is
  what constituent attribution needs (v3 D7).
- The instrument stages run by calling `preproc.run`: **one code path**
  (v3 F4).

**LRI/KBR — ranging**:

```matlab
lri = preproc.Arc(tl, rl, auxl);   kbr = preproc.Arc(tk, rk, auxk);
res = ranging.process(lri, 'Reference', kbr, 'Drivers', drv);
```

**Result fields.** `preproc.run` returns `arc` (cleaned: weights, named
layers, `filled`, provenance), `reference` (aligned, CRN-consistent),
`diagnostics`, `correlation`, `flags`, `config`, `provenance`; this set is
pinned by a contract test. Each application returns the same fields plus
its own: `calibration` (`app.Calibration`: apply / invert / summaryTable /
save / load) and `attribution` for NonGravForces, `comparison` for ranging.

---

## 5. Data model

**`preproc.Arc`** (value class), constructed from gracefoReading's triple.
It refuses anything but int64 gpsns time (`preproc:Arc:timeFormat`).

| property | type, size | source |
|---|---|---|
| `t` | int64 N×1, strictly increasing | reader, gpsns |
| `obs` | double N×M | reader |
| `names`, `units` | string 1×M | file header |
| `product`, `satellite`, `frame`, `frameSource` | string | `aux`. A frame not stated by the file or an explicit option stays `""`, and any stage that needs it refuses (v3 F5) |
| `weights` | double N×1 in [0,1] | `min` over layers; fits scale rows by √w |
| `layers` | struct of N×1 logical, true = remove | additive, named; a layer can only remove |
| `filled` | logical N×1 | created by `fill`; weight 0 in every fit |
| `provenance` | struct array, append-only | one entry per stage |

Columns are selected by name through a product dictionary (ACT1B
`lin_accl_x/y/z`; LRI1B from the real header, V-3). There is no positional
fallback.

**`preproc.Config`** — sections `mask`, `qc`, `crn`, `align`, `fill`, `unc`,
`drivers`, `run`.
- `Config(arc)` gives the preset for the measured product; unknown fields
  error.
- An option whose default would be an assumption defaults to empty (R5).
- Applications take it as `'Preproc'` and hash it together with their own
  options into provenance.

---

## 6. Pipeline

### 6.1 Instrument stages (preproc)

| # | stage | function | guarantee |
|---|---|---|---|
| 1 | mask | `mask` | qualflg layers via `decodeQualFlags`; THR1B windows (margins justified by the CRN span); eclipse transitions from a driver series; CRN edges; user layer |
| 2 | QC | `qc` | residual-based outliers, impulses (matched filter on the CRN impulse response, THR1B priors), jumps (reported and become parameters, never masked) |
| 3 | align | `align`, `checkAlignment` | reference onto observation epochs; lag diagnostic ±60 s, warns above 1 s, never shifts silently (v3 F2) |
| 4 | consistency | `crnKernel`, `crnApply` | exact ATBD kernel normalised at f0, DC gain 1.0004533 kept; chunked per file day with half-span overlap, bit-identical to unchunked; NaN edges |
| 5 | gate | `observability` | the metrics an application uses to refuse or downgrade unidentifiable parameters before its fit |
| 6 | uncertainty | `bootstrap`, `crossval` | moving-block bootstrap with substreamed RNG; blocked CV |
| 7 | gaps | `fill` | 6.5 |
| 8 | correlation | `drivers`, `correlate` | section 7 |

### 6.2 ACC calibration (NonGravForces `app`)

Per axis i, with H the CRN kernel from `preproc.crnKernel`:

  y_i(t) = H∗b_i(t) + Σ_j S_ij·(H∗a_j)(t) [+ K2_i·(H∗a_i)², demeaned] [+ 1/rev] [+ Σ jumps] + e_i(t),  e coloured, estimated by `lsqvce.fit`.

- Bias basis `constant | linear | hat | pspline`, filtered by H like every
  deterministic column; knot spacing below the kernel span warns.
- Scale `diag | full | mask`; cross-track scale fixed by default; a full S is
  gated by the model-axis VIF (v3 I.5-3).
- **Refused combination:** per-revolution scale together with 1/rev empirical
  terms (measured r ≈ −0.7).
- Time-varying s(t) only with its pointwise σ band and an
  `isDriftSignificant` flag (v3 I.5-1).
- Every scale carries the errors-in-variables attenuation bound (v3 D4).
- Satellite D ACT1B is a transplant product (V-5), and the report says so.
- Attribution: per-revolution parameters regressed on per-effect a priori
  amplitudes, space weather, β′ and u (via `preproc.correlate`). A VIF above
  10 gives the verdict `unresolved`.

### 6.3 LRI/KBR (ranging)

- `observables`: range, range-rate, range-acceleration, with the correction
  columns the real header declares (V-3).
- `detectPhaseJumps`: a range step is a CRN-shaped doublet in
  range-acceleration. It is detected by `preproc.qc` with the CRN derivative
  kernel as template.
- `compareKbr`: KBR (5 s) and LRI (2 s) on common epochs with CRN-consistent
  filtering (V-2). It estimates the time-tag offset (bounded, reported), the
  LRI/KBR scale factor, and the bias and drift of the difference, all through
  `lsqvce.fit`.
- `spectrum`: amplitude spectral density of LRI, KBR and their difference,
  gap-aware.
- Residuals against a reference orbit or gravity field: out of scope (Q4).

### 6.4 Pre-estimation versus pre-elimination (application option)

- `"preestimate"`: nuisance parameters are estimated, applied and reported
  with their covariance; the returned `arc` holds corrected data.
- `"preeliminate"`: the nuisance columns are handed on as lsqvce local
  parameters (scope `arc`/`day`), so the downstream adjustment reduces them by
  Schur complement under its own stochastic model.
- Regularisation is declared as lsqvce priors. Its weight comes from the
  variance-component estimate (REML-type) or from blocked CV; plain GCV is not
  offered (v3 D2).

### 6.5 Gaps (`Config.fill`)

| method | fills | use |
|---|---|---|
| `none` (**default**) | nothing; gaps are reported (`findGaps`) and arcs split there | estimation, and every run that does not ask |
| `collocation` (on request) | prediction with a supplied covariance model, gaps ≤ `maxGap` only | consumers needing continuity |
| `reference` (explicit request) | calibrated reference plus collocated residual | continuity beyond what collocation can bridge |

`maxGap` has no default: a fill without it refuses
(`preproc:fill:maxGapMissing`). Filled samples are marked in `arc.filled`,
carry weight 0 in every fit and never re-enter an estimate.

---

## 7. Correlation analysis (`preproc.drivers`, `preproc.correlate`)

**Drivers are supplied, never computed in preproc.**
- β′ and u from `referenceSystem.orbitSunGeometry`;
- eclipse factor and space weather from NonGravForces;
- THR1B counts, LRI/KBR SNR, per-effect a priori amplitudes.

`drivers` aligns them onto the arc epochs and checks units and coverage.

**Methods**, each with significance that respects autocorrelation:
- lagged correlation of pre-whitened series;
- regression of gated per-revolution parameters on the drivers, with a VIF
  gate;
- partial correlation (β′ versus eclipse fraction);
- binned maps residual(β′, u);
- effective sample size from the residual ACF, and block-bootstrap confidence
  intervals (naive sigmas are 5–14× too small here).

---

## 8. Rules carried over — measured, do not re-litigate

| rule | evidence |
|---|---|
| exact ATBD CRN kernel only; normalise at f0, keep DC gain 1.0004533 | approximate kernel −11.5 % scale; unit-DC renormalisation +453 ppm (v2 refval) |
| model and bias basis through the same kernel as the observation | unfiltered comparison biases scale to ≈ 0.49 (v2) |
| observability gate before the fit; demean regressors | corr(bias, scale) = −1 on quiet arcs (v2) |
| never co-estimate per-rev scale and 1/rev terms | r ≈ −0.7 (v2) |
| block bootstrap for sigmas | naive 5–14× optimistic (v2) |
| int64 gpsns, never double GPS time | 2020 gpsns ≈ 6.3e17 > 2^53 |
| qualflg meanings from the file header | O-1: invented formats fail on real files |
| deterministic opt-in parallelism; RNG substream per replicate, seed per stage name | results independent of worker count and stage insertion |

GRACE-FO CRN parameters are the GRACE ATBD ones, unverified for GRACE-FO (V-1).
`crnKernel` warns until a named constant cites the handbook.

---

## 9. Validation

**Test categories.** Every new public unit carries the tags `contract`,
`reference`, `precision`, `speed` (ratio budget), `robustness`,
`vectorisation` and `metamorphic`, or an exemption stating why a category is
impossible.
- Each repository has its own runner and category audit.
- Test counts are predicted as passed + failed + incomplete = total before
  every run.

| id | oracle (nothing checks itself) | checks |
|---|---|---|
| ORC-1 | GRACE L1B ATBD App. B via Python `refval/crn_atbd.py` (v2 zip) | CRN taps, DC gain, derivatives |
| ORC-2 | v2 keystone numbers regenerated in Python | 0.49, +453 ppm, 5–7× inflation, lag-1 ACF > 0.8 |
| ORC-3 | real 2020-01-01 ACT1B/THR1B/GNV1B/SCA1B (C), KBR1B, LRI1B | dictionaries, masks, end-to-end smoke |
| ORC-4 | ITSG `nonConservativeForces` 2020-01-01 | independent reference series (V-4) |
| ORC-5 | numpy circular-orbit geometry | β′, u (referenceSystem #25) |
| ORC-6 | numpy least squares on white noise | each application's lsqvce declaration equals the textbook solution |
| ORC-7 | truth generators (ACC in NonGravForces, LRI/KBR in ranging), fixed seeds | recovery and flagging of planted parameters and defects |

| id | verification item (from documents or real bytes, never memory) | blocks |
|---|---|---|
| V-1 | GRACE-FO ACC CRN parameters vs JPL D-56935 | removal of the `crnKernel` warning |
| V-2 | KBR1B and LRI1B CRN parameters | `crnKernel` presets for ranging |
| V-3 | LRI1B correction columns, signs, units from the real header | L-01 |
| V-4 | ITSG `nonConservativeForces`: model or calibrated measurement? CRN-filtered? | ORC-4 |
| V-5 | ACT1B satellite D transplant statement in the header | N-02 report wording |
| V-6 | lsqvce 6.1: local parameters + priors + ARMA/PSD + robust in one `fit`, read from source | N-02, L-03 |

---

## 10. Work packages, dependency order

Each WP: scope frozen in the owning repository's HANDOVER first, one branch,
a draft PR at once, help block + tests + regenerated documentation in the
same change.

| repo | WP | content | replaces v3 | needs |
|---|---|---|---|---|
| referenceSystem | R-01 | `orbitSunGeometry` (#25) | WP-16 part | — |
| preproc | X-00 | repository skeleton, CI (ci-actions probe), documentation pipeline, test tags, layering test, gracefoReading resolution; **move this concept and `inputs/` here, leave a pointer in gracefoReading** | WP-00, WP-05 | Q11 |
| preproc | X-01 | `Arc`, `Config` skeleton | WP-01 | X-00 |
| preproc | X-02 | `crnKernel` (ACC; KBR/LRI after V-2), `crnApply` | WP-10 | X-01 |
| preproc | X-03 | `mask`, `qc` (port of NonGravForces.qc 0.12.0) | WP-06 | X-02 |
| preproc | X-04 | `align`, `checkAlignment` | WP-02 part, WP-11 part | X-02 |
| preproc | X-05 | `observability`, `bootstrap`, `crossval` | WP-12, WP-15 part | X-01 |
| preproc | X-06 | `fill` | — | X-05 |
| preproc | X-07 | `drivers`, `correlate` | WP-17 part | X-05 |
| preproc | X-08 | `run`, full `Config`, integration test (real ACT1B vs ITSG reference; synthetic) | WP-19 part | X-01..X-07 |
| preproc | X-09 | `report` | WP-20 part | X-08 |
| preproc | X-10 | V-1 CRN verification | WP-24 | handbook |
| NonGravForces | N-01 | `qc` forwards to `preproc.qc`, then is deleted | — | X-03 released |
| NonGravForces | N-02 | `app.calibrate` upgraded: `Arc` input, reference `Model` or `Arc`, 6.2 design, CRN via preproc, estimation via `lsqvce.fit` (own QR retired), gates, EIV bound, `app.Calibration`, ACC truth generator, integration test | WP-08, WP-09, WP-13, WP-18, WP-21 | X-08 released, V-6 |
| NonGravForces | N-03 | time-varying scale, model comparison, per-revolution, attribution | WP-14, WP-16 part, WP-17 part | N-02, R-01 |
| NonGravForces | N-04 | `sensor.Electrostatic` default kernel from `preproc.crnKernel` | — | X-02 released |
| NonGravForces | N-05 | calibration figures | WP-20 part | N-03 |
| NonGravForces | N-06 | records: A.2 rule, dependency table (preproc, lsqvce), B.4 | — | with N-02 |
| ranging | L-00 | repository skeleton, as X-00 | — | Q11 |
| ranging | L-01 | `observables` | — | L-00, V-3 |
| ranging | L-02 | `detectPhaseJumps` | — | L-01, X-03 |
| ranging | L-03 | `compareKbr` | — | L-02, X-04, V-2, V-6 |
| ranging | L-04 | `spectrum` | — | L-01 |
| ranging | L-05 | `process`, truth generator, integration test, report | — | L-01..L-04, X-08, R-01 |

Retired without replacement: v3 WP-02 time conversions (referenceSystem),
WP-03/04 readers (gracefoReading; space weather is `NonGravForces.io`),
WP-07 noise models (lsqvce), WP-22 benchmark harness (speed ratios live in
the tests), WP-23 (each repository's documentation pipeline), WP-25
`fromSca1b` (referenceSystem + `NonGravForces.geom.AttitudeProvider`).

---

## 11. Decisions

| id | question | status |
|---|---|---|
| Q1 | Dependency direction | **decided 2026-09-18: one-way** (graph 3.1) |
| Q2 | Estimator core | **decided 2026-09-18: `lsqvce.fit`**. Rev 0.5: called by each application directly; preproc has no estimator |
| Q3 | Gap filling default | **decided 2026-09-18: `none`**; collocation ≤ `maxGap` on request; `maxGap` has no default |
| Q4 | LRI analysis beyond L1B-internal and KBR comparison? | open — proposal in force: no; LGD and orbit residuals stay downstream |
| Q5 | Help footer in gracefoReading | **decided 2026-09-18: keep that repository's rule**. New repositories: proposal in force — date, time and model in the footer, as referenceSystem does and as the owner's standing instruction asks |
| Q6 | Classic GRACE? | open — proposal in force: no; after gracefoReading O-1 |
| Q7 | Where does ACC calibration live? | **decided 2026-09-18: NonGravForces `app`**, upgraded in place |
| Q8 | Owner of β′ and argument of latitude | **decided 2026-09-18: referenceSystem** (#25) |
| Q9 | Where does LRI/KBR processing live? | **decided 2026-09-18: a toolbox of its own** (ranging) |
| Q10 | Where do Arc, CRN kernel, masks, QC, gaps and correlation live? | **decided 2026-09-18: a shared preprocessing toolbox** below NonGravForces and ranging; gracefoReading stays a pure reader |
| Q11 | Names of the two new toolboxes (and repositories) | open — working names `preproc`, `ranging`. **Gates X-00 and L-00** |

---

## 12. What a next session would be wrong for not reading

1. gracefoReading gets **no code** from this concept; it stays a pure reader.
   The concept is hosted here only until X-00.
2. Calibration stays in NonGravForces and is upgraded in place; only `qc`
   leaves NonGravForces, and it goes to preproc, not to gracefoReading.
3. preproc contains no estimator. The applications call `lsqvce.fit`; a
   second least-squares code anywhere repeats v3 F1.
4. β′ and u are referenceSystem's (#25). preproc receives them as data and
   never rotates an orbit.
5. ranging does not depend on NonGravForces.
6. Do not implement from the v3 handover's Part IV prompts; section 10 maps
   each of them.
7. The legacy zip is v2.4.2, not the v2.5.0 the v3 handover reviewed.
8. gracefoReading O-11 (`readL1bMulti` rejects `findL1bFiles`' column)
   breaks the first line of section 4; it is gracefoReading's own fix.
