# CONCEPT — Instrument preprocessing (gracefoReading) and accelerometer calibration (NonGravForces)

**Revision 0.4 (DRAFT) · 2026-09-18 · written with Claude Opus 5 (Anthropic)**

This file is the **single point of truth for the design** of two pieces of
work that share one pipeline: the instrument-level preprocessing layer of
`gracefoReading` (masks, QC, CRN, gaps, correlation, the LRI chain) and the
accelerometer calibration application in `NonGravForces.app`. Each
repository's `HANDOVER.md` stays the single point of truth for its own
status, obligations and decisions and points here (gracefoReading O-13,
NonGravForces O-45). Nothing in this file is implemented yet.

History: Rev 0.1 draft · Rev 0.2 Q1 = A, Q2 = lsqvce, Q3 = no fill ·
Rev 0.3 Q5 = keep the footer rule · **Rev 0.4 Q7 = the ACC calibration
application lives in NonGravForces**, owner 2026-09-18 (section 11).

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

**The split follows the dependency that already exists.** A force model
needs orbit, attitude and mass, so NonGravForces reads through
gracefoReading (`io/private/l1bLoad` → `readL1bMulti`). Calibration needs
data *and* the force model, so it sits above both — in NonGravForces' `app`
layer, beside `forceBudget` and `densityInversion`. Everything that needs no
physics and serves every instrument (ACC, KBR, LRI) sits in gracefoReading.

| gracefoReading — instrument data, no physics | NonGravForces — physics and the ACC application |
|---|---|
| reading (L0, unchanged) | force model `Model`, environment, eclipse, space weather |
| `Arc`, `preproc.Config` | `app.calibrate` (upgraded to the v3 design), `app.Calibration` |
| exact CRN kernel, masks (qualflg, thrusters, eclipse), generic QC | bias/scale/K2/1-rev/jump design, time-varying scale, model comparison |
| alignment check, gaps and fill | per-revolution parameters, attribution to force constituents and space weather |
| estimation bridge to lsqvce, observability, bootstrap, blocked CV | EIV bound, scale-matrix decomposition, ACC truth generator |
| drivers (β′, argument of latitude), correlation analysis | `sensor.Electrostatic` (takes the CRN kernel from gracefoReading) |
| the LRI/KBR chain | |

Out of scope for both: time scales and frames (referenceSystem), orbit and
gravity estimation, LGD, mascons. GRACE-FO first; classic GRACE is blocked
by gracefoReading O-1.

---

## 2. Authority map — one owner per capability (R1)

| capability | authority | consequence |
|---|---|---|
| L1B / ITSG / GROOPS reading, gz, cache | gracefoReading L0 | v3 `+io` **retired** |
| qualflg bit meanings | the file's own header via `decodeQualFlags` | v3 handbook bit table **retired** (O-1 lesson) |
| gaps, segments | `gracefoReading.findGaps` | reused |
| int64 GPS-ns epochs | `readL1b 'TimeFormat' "gpsns"` | `Arc` accepts gpsns only |
| time scales, leap seconds, rotations, quaternions, Sun | referenceSystem | v3 `+time` **retired** |
| orbit in the celestial frame | `NonGravForces.io.readGNV1B` (GNV1B ITRS→GCRS) · ITSG `reducedDynamicOrbit` via `readItsgProduct` | `preproc.drivers` takes an orbit `Arc` whose frame is celestial and refuses any other; it never rotates GNV1B itself |
| β′, argument of latitude | **nobody yet** → `gracefoReading.preproc.drivers` | from the orbit `Arc` and `referenceSystem.geocentricBodyState` |
| modelled non-gravitational acceleration, per effect | `NonGravForces.Model` (`series`, `budget`) | inside `app.calibrate`; external references (ITSG `nonConservativeForces`, GROOPS) enter as an `Arc` |
| eclipse factor, space weather | `NonGravForces.env.eclipseFactor`, `io.spaceWeather` | used directly by `app.calibrate`; enter gracefoReading as driver data |
| exact ATBD CRN kernel + derivative kernels | **nobody yet** (`sensor.Electrostatic`: "not implemented, supply the kernel") → `gracefoReading.preproc.crnKernel` | port of v2 `crnFilter`; NonGravForces consumes it |
| residual QC: Hampel, impulses, jumps, event table | `NonGravForces.qc` 0.12.0 → **`gracefoReading.preproc.qc`** | ported down (LRI needs it; needs the CRN kernel); NonGravForces forwards for one release, then deletes (N-01) |
| least-squares estimation | `lsqvce.fit` 6.1, reached **only** through `gracefoReading.preproc.estimate` | one estimator, one bridge, used by the LRI chain and by `app.calibrate`; `app.calibrate`'s own QR solver **retired** (N-02) |
| accelerometer calibration | **`NonGravForces.app.calibrate`**, upgraded in place | one calibration in the ecosystem; v3 `+fit`, `+unc`, `+diag` ACC parts land here |
| processing settings | `gracefoReading.preproc.Config` (instrument stages) embedded in the calibration options | one resolved, hashed object per run; the result carries it |

---

## 3. Architecture

### 3.1 Dependency graph (acyclic)

```
referenceSystem <-- gracefoReading (L2 preproc.drivers)   <-- NonGravForces (io, env, app)
lsqvce          <-- gracefoReading (L2 preproc.estimate)  <-- NonGravForces.app.calibrate
```

Checked 2026-09-18: no `.m` file of lsqvce `ac981cd` or referenceSystem
`311e060` calls gracefoReading or NonGravForces. NonGravForces never calls
lsqvce directly, so its "no least-squares code inside NonGravForces" rule
becomes true again once `app.calibrate`'s own QR is retired.

### 3.2 Layers in gracefoReading (downward calls only, tested mechanically)

```
L4  gracefoReading.preprocess                 single point of access, instrument level
L3  +gracefoReading/+lri                      LRI/KBR chain
L2  +gracefoReading/+preproc                  shared stages; the only callers of lsqvce and referenceSystem
L1  gracefoReading.Arc, preproc.Config        data model, settings
L0  gracefoReading.read*/find*/decode*/…      reader, UNCHANGED, zero dependencies
```

L0 keeps zero external dependencies. A missing dependency errors at the
point of use with `gracefoReading:<fn>:depMissing` naming the setup function
(R4). The layering test fails any upward call and any call to lsqvce or
referenceSystem outside `preproc.estimate` and `preproc.drivers`.

### 3.3 In NonGravForces

The calibration application stays in the `app` layer (L8) and calls
gracefoReading L1–L2 by qualified name, exactly as it calls referenceSystem
today. NonGravForces' governing rule (its HANDOVER A.2, "computes forces and
torques and nothing else") must be reworded to admit the `app` layer it
already has (N-06).

---

## 4. Single points of access

**Instrument level (any product) — gracefoReading**, chained after reading;
the chain is chosen by `arc.product`, read from the file (R3):

```matlab
[t, a, aux] = gracefoReading.readL1bMulti(files, 'TimeFormat', "gpsns");
acc = gracefoReading.Arc(t, a, aux);
res = gracefoReading.preprocess(acc, 'Reference', ref);          % masks, QC, CRN, gaps, report
res = gracefoReading.preprocess(lri, 'Reference', kbr, 'Drivers', drv);   % LRI chain
```

**Accelerometer calibration — NonGravForces**, chained after the same read:

```matlab
acc = gracefoReading.Arc(t, a, aux);
M   = NonGravForces.Model(NonGravForces.geom.graceFO("C"), NonGravForces.Options("standard"), ...
                         'Eop', eop, 'SpaceWeather', sw);
res = NonGravForces.app.calibrate(acc, M, 'Orbit', orb, 'Attitude', att);   % a priori from M
res = NonGravForces.app.calibrate(acc, itsgArc);                           % external reference
cfg = gracefoReading.preproc.Config(acc);                                  % full control
res = NonGravForces.app.calibrate(acc, M, 'Orbit', orb, 'Attitude', att, ...
          'Preproc', cfg, 'Scale', "full", 'Bias', "pspline");
```

- The reference is a `Model` (then `'Orbit'` — GNV1B via `io.readGNV1B` —
  and `'Attitude'` — SCA1B via `io.readSCA1B` — are required, and the a
  priori acceleration, **per effect**, is evaluated on the ACC epochs through
  `Model.budget(epoch, r, v, q)`) or an `Arc` (ITSG, GROOPS, a stored run).
- `app.calibrate` runs the instrument stages by calling
  `gracefoReading.preprocess` — **one code path** for masks, QC, CRN,
  alignment and gaps (v3 F4) — then design, estimation through
  `preproc.estimate`, uncertainty, attribution.
- Per-effect a priori (drag, radiation, thermal) is what makes constituent
  attribution possible (v3 D7); this is the concrete gain of calibrating
  inside NonGravForces.

`res` of `gracefoReading.preprocess` (field set pinned by a contract test):
`arc` (cleaned: weights, named layers, `filled`, provenance), `reference`
(aligned, CRN-consistent), `diagnostics` (gates, per-layer removal counts,
alignment verdict, noise model), `correlation`, `flags`, `config`,
`provenance`. `app.calibrate` returns the same fields plus `calibration`
(an `app.Calibration`: apply / invert / summaryTable / save / load) and
`attribution`.

---

## 5. Data model

**`gracefoReading.Arc`** (value class), constructed from the reader's triple;
refuses anything but int64 gpsns time (`gracefoReading:Arc:timeFormat`).

| property | type, size | source |
|---|---|---|
| `t` | int64 N×1, strictly increasing | reader, gpsns |
| `obs` | double N×M | reader |
| `names`, `units` | string 1×M | file header |
| `product`, `satellite`, `frame`, `frameSource` | string | `aux`; a frame the file or an explicit option does not state stays `""`, and a stage needing it refuses (v3 F5) |
| `weights` | double N×1 in [0,1] | `min` over layers; fits scale rows by √w |
| `layers` | struct of N×1 logical, true = remove | additive, named; layers only remove |
| `filled` | logical N×1 | created by the gap stage; weight 0 in every fit |
| `provenance` | struct array, append-only | one entry per stage |

Columns are selected by name through a product dictionary (ACT1B:
`lin_accl_x/y/z`; LRI1B: from the real header, V-3). No positional fallback.

**`gracefoReading.preproc.Config`** — sections `mask`, `qc`, `crn`,
`fill`, `align`, `lri`, `estimate`, `unc`, `drivers`, `run`; `Config(arc)`
gives the preset for the measured product; unknown fields error; the
resolved object is hashed into provenance. Options whose default would be an
assumption default to empty (R5). `app.calibrate` takes it as `'Preproc'`
and adds its own sections under NonGravForces' option conventions.

---

## 6. Pipeline

### 6.1 Instrument stages (gracefoReading, shared)

| # | stage | function | guarantee |
|---|---|---|---|
| 1 | mask | `preproc.mask` | qualflg layers via `decodeQualFlags`; THR1B windows (margins justified by the CRN span); eclipse transitions from a driver series; CRN edges; user layer |
| 2 | QC | `preproc.qc` | residual-based outliers, impulses (matched filter on the CRN impulse response, THR1B priors), jumps (reported, become parameters, never masked) |
| 3 | align | `preproc.align`, `preproc.checkAlignment` | reference onto observation epochs; lag diagnostic ±60 s, warns > 1 s, never shifts silently (v3 F2) |
| 4 | consistency | `preproc.crnKernel`, `preproc.crnApply` | exact ATBD kernel, normalised at f0, DC gain 1.0004533 kept; chunked per file day with half-span overlap, bit-identical to unchunked; NaN edges |
| 5 | gate | `preproc.observability` | refuses or downgrades unidentifiable parameters before any fit |
| 6 | estimate | `preproc.estimate` | the lsqvce bridge (6.4) |
| 7 | uncertainty | lsqvce whitened covariance, `preproc.bootstrap`, `preproc.crossval` | honest sigmas under coloured noise |
| 8 | gaps | `preproc.fill` | 6.5 |
| 9 | correlation | `preproc.drivers`, `preproc.correlate` | section 7 |

### 6.2 ACC calibration (NonGravForces `app`)

Per axis i, H the CRN kernel from `preproc.crnKernel`:

  y_i(t) = H∗b_i(t) + Σ_j S_ij·(H∗a_j)(t) [+ K2_i·(H∗a_i)², demeaned] [+ 1/rev] [+ Σ jumps] + e_i(t),  e coloured.

- Bias basis `constant | linear | hat | pspline`, filtered by H like every
  deterministic column; knot spacing below the kernel span warns.
- Scale `diag | full | mask`; cross-track scale fixed by default; full S
  gated by the model-axis VIF (v3 I.5-3).
- **Refused combination:** per-revolution scale with 1/rev empirical terms
  (measured r ≈ −0.7).
- Time-varying s(t) only with its pointwise σ band and an
  `isDriftSignificant` flag (v3 I.5-1).
- Every scale carries the errors-in-variables attenuation bound (v3 D4).
- Satellite D ACT1B is a transplant product; its report says so (V-5).
- Attribution: per-revolution parameters regressed on per-effect a priori
  amplitudes, space weather, β′, argument of latitude, through
  `preproc.correlate`; VIF > 10 → verdict `unresolved`.

### 6.3 LRI chain (gracefoReading `+lri`)

- `lri.observables`: range, range-rate, range-acceleration with the
  correction columns the real header declares (V-3).
- `lri.detectPhaseJumps`: a range step is a CRN-shaped doublet in
  range-acceleration; detected through `preproc.qc` with the CRN derivative
  kernel as template.
- `lri.compareKbr`: KBR (5 s) and LRI (2 s) on common epochs with
  CRN-consistent filtering (V-2); time-tag offset (bounded, reported),
  LRI/KBR scale factor, bias/drift of the difference, through
  `preproc.estimate`.
- `lri.spectrum`: ASD of LRI, KBR and their difference (gap-aware).
- Residuals against a reference orbit or gravity field: out of scope (Q4).

### 6.4 Pre-estimation versus pre-elimination (`Config.estimate.mode`)

- `"preestimate"`: nuisance parameters estimated, applied, reported with
  covariance; `res.arc` holds corrected data.
- `"preeliminate"`: nuisance columns are handed on as lsqvce local
  parameters (scope `arc`/`day`) so the downstream adjustment reduces them by
  Schur complement under its own stochastic model.
- Regularisation is declared as lsqvce priors; its weight comes from the
  variance-component estimate (REML-type) or blocked CV. Plain GCV is not
  offered (v3 D2).

### 6.5 Gaps (`Config.fill`)

| method | fills | use |
|---|---|---|
| `none` (**default**) | nothing; gaps reported (`findGaps`), arcs split there | estimation, and every run that does not ask |
| `collocation` (on request) | prediction with the fitted noise covariance, gaps ≤ `maxGap` | consumers needing continuity |
| `reference` (explicit request) | calibrated reference + collocated residual | continuity beyond what collocation bridges |

`maxGap` has no default: a fill without it refuses
(`gracefoReading:preproc:fill:maxGapMissing`). Filled samples are in
`arc.filled`, weigh 0 in every fit, and never re-enter an estimate.

---

## 7. Correlation analysis (`preproc.drivers`, `preproc.correlate`)

**Drivers** on the arc epochs, computed once, shared by LRI and ACC: β′ and
argument of latitude (orbit `Arc` in the celestial frame + Sun from
referenceSystem), eclipse factor and space weather (data), THR1B counts,
LRI/KBR SNR, per-effect a priori amplitudes when supplied.

**Methods**, with significance that respects autocorrelation: lagged
correlation of pre-whitened series; regression of gated per-revolution
parameters on drivers with a VIF gate; partial correlation (β′ versus
eclipse fraction); binned maps residual(β′, u); effective sample size from
the residual ACF and block-bootstrap CIs (naive sigmas are 5–14× too small
here).

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

GRACE-FO CRN parameters are the GRACE ATBD ones and are unverified for
GRACE-FO (V-1): `crnKernel` warns until a named constant cites the handbook.

---

## 9. Validation

Every new public unit carries the tags `contract`, `reference`, `precision`,
`speed` (ratio budget), `robustness`, `vectorisation`, `metamorphic`, or an
exemption stating why a category is impossible. Each repository keeps its
own runner and category audit (NonGravForces `auditTestCategories`,
gracefoReading from P-00). Counts are predicted as passed + failed +
incomplete = total before every run.

| id | oracle (nothing checks itself) | checks |
|---|---|---|
| ORC-1 | GRACE L1B ATBD App. B via Python `refval/crn_atbd.py` (v2 zip) | kernel taps, DC gain, derivatives |
| ORC-2 | v2 keystone numbers regenerated in Python | 0.49, +453 ppm, 5–7× inflation, lag-1 ACF > 0.8 |
| ORC-3 | real 2020-01-01 ACT1B/THR1B/GNV1B/SCA1B (C), KBR1B, LRI1B | dictionaries, masks, end-to-end smoke |
| ORC-4 | ITSG `nonConservativeForces` 2020-01-01 (bundled, trimmed) | independent reference series (V-4) |
| ORC-5 | analytic circular orbit (Python) | β′, u |
| ORC-6 | numpy least squares on white noise | the lsqvce bridge equals the textbook solution |
| ORC-7 | truth generators (ACC in NonGravForces, LRI in gracefoReading), fixed seeds | recovery and flagging of planted parameters and defects |

| id | verification item (from documents or real bytes, never memory) | blocks |
|---|---|---|
| V-1 | GRACE-FO ACC CRN parameters vs JPL D-56935 | removal of the `crnKernel` warning |
| V-2 | KBR1B and LRI1B CRN parameters | P-09 |
| V-3 | LRI1B correction columns, signs, units from the real header | P-09 |
| V-4 | ITSG `nonConservativeForces`: model or calibrated measurement? CRN-filtered? | ORC-4 |
| V-5 | ACT1B satellite D transplant statement in the header | N-02 report wording |
| V-6 | lsqvce 6.1: local parameters + priors + ARMA/PSD + robust in one `fit`, read from source | P-05 |

---

## 10. Work packages, dependency order

Each WP: frozen scope in the owning repository's HANDOVER first, one branch,
draft PR at once, help block + tests + regenerated documentation in the same
change. gracefoReading 1.0.2 → 1.1.0; NonGravForces 0.12.x → 0.13.0.

**gracefoReading (P-)**

| WP | content | replaces v3 | needs |
|---|---|---|---|
| P-00 | layering test, optional-dependency resolution, deterministic-parallel helper, CI checkout of referenceSystem + lsqvce, `docsrc`/`auditHelp.py` for sub-packages, test tags. **Workflow change, own PR** | WP-00, WP-05 | — |
| P-01 | `Arc` | WP-01 | P-00 |
| P-02 | `crnKernel`, `crnApply` | WP-10 | P-01 |
| P-03 | `mask`, `qc` (port of NonGravForces.qc 0.12.0) | WP-06 | P-02 |
| P-04 | `align`, `checkAlignment` | WP-02 part, WP-11 part | P-02 |
| P-05 | `estimate`, `observability`, `bootstrap`, `crossval` | WP-07, WP-09, WP-12, WP-15 part | P-01, V-6 |
| P-06 | `fill` | — | P-05 |
| P-07 | `drivers`, `correlate` | WP-16 part, WP-17 part | P-05 |
| P-08 | `Config`, `preprocess`, integration test (real ACT1B vs ITSG reference; synthetic) | WP-19 part | P-01..P-07 |
| P-09 | `lri.observables`, `detectPhaseJumps`, `compareKbr`, `spectrum`, LRI truth generator, integration test | — | P-08, V-2, V-3 |
| P-10 | `preproc.report` (instrument figures, HTML summary) | WP-20 part | P-08 |
| P-11 | V-1 CRN verification | WP-24 | handbook |

**NonGravForces (N-)** — recorded there as O-45

| WP | content | replaces v3 | needs |
|---|---|---|---|
| N-01 | `qc` forwards to `gracefoReading.preproc.qc`, then is deleted; dependency table gracefoReading ≥ 1.1 | — | P-03 released |
| N-02 | `app.calibrate` upgraded: `Arc` input, reference `Model` or `Arc`, v3 design (6.2), CRN-consistent via `preproc.crnKernel`, estimation via `preproc.estimate` (own QR retired), gates, EIV bound, `app.Calibration`, ACC truth generator, integration test | WP-08, WP-13, WP-18, WP-21 | P-08 released |
| N-03 | time-varying scale, model comparison, per-revolution, attribution with per-effect a priori, `decomposeScale` | WP-14, WP-16 part, WP-17 part | N-02, P-07 |
| N-04 | `sensor.Electrostatic`: default kernel from `preproc.crnKernel` (explicit kernel still accepted) | — | P-02 released |
| N-05 | calibration figures and report | WP-20 part | N-03 |
| N-06 | records: A.2 rule and dependency table, B.4 (lsqvce reached only through gracefoReading) | — | with N-02 |

Retired without replacement: v3 WP-02 time conversions (referenceSystem),
WP-03/04 readers (gracefoReading L0; space weather is `NonGravForces.io`),
WP-22 benchmark harness (speed ratios live in the tests), WP-23 (each
repository's documentation pipeline), WP-25 `fromSca1b` (referenceSystem +
`NonGravForces.geom.AttitudeProvider`).

---

## 11. Decisions

| id | question | status |
|---|---|---|
| Q1 | Dependency direction | **decided 2026-09-18: one-way**, referenceSystem ← gracefoReading ← NonGravForces |
| Q2 | Estimator core | **decided 2026-09-18: `lsqvce.fit`**, reached only through `gracefoReading.preproc.estimate` (Rev 0.4: the bridge stays in gracefoReading because the LRI chain estimates too). V-6 gates P-05 |
| Q3 | Gap filling default | **decided 2026-09-18: `none`**; `collocation` ≤ `maxGap` on request; `maxGap` has no default |
| Q4 | LRI analysis beyond L1B-internal and KBR comparison? | open — proposal in force: no; LGD and orbit residuals stay downstream. Gates P-09 |
| Q5 | Help footer in gracefoReading | **decided 2026-09-18: keep the repository rule**; model and time in commits and PRs. NonGravForces units follow NonGravForces' own template |
| Q6 | Classic GRACE in 1.1? | open — proposal in force: no; after O-1 |
| Q7 | Where does ACC calibration live? | **decided 2026-09-18: NonGravForces `app`**, upgraded in place; instrument stages and LRI in gracefoReading; only `qc` moves (down). Supersedes Rev 0.2's "calibrate moves to gracefoReading" |

---

## 12. What a next session would be wrong for not reading

1. Q7 reversed Rev 0.2/0.3: calibration is **not** moving to gracefoReading.
   `app.calibrate` is upgraded where it is; only `qc` moves, down.
2. Do not implement from the v3 handover's Part IV prompts; section 10 maps
   each of them, and five re-implement capabilities that have an owner.
3. NonGravForces must not call lsqvce itself: one bridge
   (`preproc.estimate`), or two estimator glues drift apart.
4. `preproc.drivers` takes a celestial-frame orbit `Arc`; it never rotates
   GNV1B (that is `NonGravForces.io.readGNV1B`'s job, and gracefoReading
   cannot call it).
5. The legacy zip is v2.4.2, not the v2.5.0 the v3 handover reviewed.
6. L0 must stay dependency-free and its contracts unchanged; NonGravForces
   relies on `readL1bMulti`'s `aux` fields. O-11 (`readL1bMulti` rejects
   `findL1bFiles`' column) breaks the first line of section 4; fix it in its
   own PR near P-00.
