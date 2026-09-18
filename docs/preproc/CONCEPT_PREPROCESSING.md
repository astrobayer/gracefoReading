# CONCEPT — Preprocessing layer of gracefoReading (ACC calibration, LRI)

**Revision 0.2 (DRAFT, Q1–Q3 decided) · 2026-09-18 · written with Claude Opus 5 (Anthropic)**

This file is the **single point of truth for the design** of the
preprocessing layer. `HANDOVER.md` stays the single point of truth for
status, obligations and the decision record, and points here. Nothing in
this file is implemented yet. Decisions still open (section 11) block the
work packages named there until the owner has answered.
Rev 0.2: Q1 = A, Q2 = lsqvce, Q3 = no fill by default (owner, 2026-09-18).

Read at: gracefoReading `a18e9ad` (v1.0.2) · referenceSystem `311e060`
(2.1.244) · NonGravForces `3cc0123` (0.12.0) · lsqvce `ac981cd` (6.1).
Inputs: `inputs/README.md` (AccelCal v3 handover, AccelBiasScaleToolbox
v2.4.2).

---

## 1. Why, and what is in scope

GRACE-FO Level-1B series are not usable as delivered: spurious samples must
be found and down-weighted, systematic effects must be pre-estimated or
pre-eliminated, gaps must be bridged for consumers that need continuity, and
hidden dependencies (β′ angle, eclipse, solar activity, SNR) must be made
visible by correlation analysis. Today this happens in a stand-alone legacy
toolbox (AccelBiasScaleToolbox v2.4.2) and partly in `NonGravForces`; the
two have drifted and duplicate each other.

| in scope | out of scope (authority elsewhere) |
|---|---|
| ACC1B/ACT1B: masking, QC, CRN consistency, bias/scale calibration, gaps, attribution | reading (L0 of this repo, unchanged) |
| LRI1B (KBR1B as reference): masking, QC, phase jumps, KBR↔LRI comparison, gaps, spectra, attribution | force models, environment (`NonGravForces`) |
| shared: data container, masks, CRN kernel, gap policy, drivers, correlation, estimation bridge | time scales, frames, ephemerides (`referenceSystem`) |
| | least-squares engine (`lsqvce`, Q2) · orbit/gravity estimation, LGD, mascons |

GRACE-FO first. Classic GRACE ACC1B/KBR1B is blocked by O-1 (layouts
unvalidated) and enters only after O-1 is discharged.

---

## 2. Authority map — one owner per capability (R1)

The rule that decides every row: **a capability that already has an owner is
called, never re-implemented**. The v3 handover was written for a stand-alone
toolbox and re-implements five of these; those parts are retired (section 10).

| capability | authority | consequence here |
|---|---|---|
| L1B / ITSG / GROOPS reading, gz, cache | `gracefoReading` L0: `findL1bFiles`, `readL1bMulti`, `findItsgFiles`, `readItsgProductMulti`, `readGroopsInstrument` | v3 `+io` (findL1bFiles, readL1bArc, readGroopsArc) **retired** |
| qualflg bit meanings | the file's own header via `decodeQualFlags` | v3's handbook bit table from memory **retired** (it is the O-1 mistake) |
| sampling gaps, segments | `findGaps` | reused by the gap stage |
| int64 GPS-ns epochs | `readL1b 'TimeFormat' "gpsns"` (`internal/formatEpoch`) | `Arc` accepts gpsns only; no own conversion |
| time scales, leap seconds | `referenceSystem.convertTimeScale`, `leapSecondTable` | v3 `+time` toGps/fromGps/leapSeconds **retired** |
| rotations, quaternions, SLERP, Sun, ITRS→GCRS | `referenceSystem` (`rotationItrsToGcrs`, `interpolateQuaternions`, `geocentricBodyState`, `rotationGcrsToRsw`) | β′, argument of latitude computed from these (no owner yet → owned here, `preproc.drivers`) |
| modelled non-gravitational acceleration | `NonGravForces.Model` · ITSG `nonConservativeForces` · any GROOPS file | enters **as data** (an `Arc`), never as a call (Q1) |
| eclipse factor, space weather | `NonGravForces.env.eclipseFactor`, `NonGravForces.io.spaceWeather` | enter **as data** (driver series) (Q1) |
| exact ATBD CRN kernel + derivative kernels | **nobody** — `NonGravForces.sensor.Electrostatic` states "not implemented, supply the kernel" | **owned here** (`preproc.crnKernel`, port of v2 `crnFilter`); NonGravForces then consumes it |
| residual QC: Hampel, impulses, jumps, event table | `NonGravForces.qc` 0.12.0 → **`gracefoReading.preproc.qc`** (Q1) | ported here (P-03); NonGravForces forwards for one release, then deletes (P-13) |
| least-squares estimation (weights, robust, ARMA/PSD/VAR whitening, local-parameter pre-elimination, priors, VCE) | `lsqvce.fit` 6.1 (Q2) | the one estimator, called only from `preproc.estimate`; v3 `fit.solve` and `+noise` **retired** |
| accelerometer calibration | `NonGravForces.app.calibrate` → **`gracefoReading.acc.calibrate`** (Q1, Q2) | one calibration in the ecosystem; NonGravForces forwards, then deletes (P-13) |
| processing settings | `gracefoReading.preproc.Config` (one resolved, hashed object) | every stage reads its section; the result carries it |

---

## 3. Architecture

### 3.1 Layers inside the repository (downward calls only, tested mechanically)

```
L4  gracefoReading.preprocess                     single point of access
L3  +gracefoReading/+acc    +gracefoReading/+lri  product chains
L2  +gracefoReading/+preproc                      shared stages, estimation bridge
L1  gracefoReading.Arc, preproc.Config            data model, settings
L0  gracefoReading.read*/find*/decode*/…          existing reader, UNCHANGED, zero dependencies
```

- **L0 keeps zero external dependencies.** NonGravForces and every other
  consumer can keep using the reader without referenceSystem or lsqvce.
- `referenceSystem` (≥ 2.1) is called only from L2 `preproc.drivers`;
  `lsqvce` (≥ 6.1) only from L2 `preproc.estimate`. A missing dependency
  errors at the point of use with `gracefoReading:<fn>:depMissing`, naming
  the setup function — never a silent fallback (R4).
- A layering test (as in referenceSystem) fails any upward call and any
  call to `lsqvce`/`referenceSystem` outside the two named files.

### 3.2 Dependency graph between repositories — **decided: A (Q1)**

NonGravForces already depends on gracefoReading. If the new layer *calls*
NonGravForces, the two repositories depend on each other.

| option | graph | cost |
|---|---|---|
| **A (decided)** | referenceSystem ← gracefoReading ← NonGravForces; NonGravForces outputs (model, eclipse, space weather) enter as data | NonGravForces `qc` and `app.calibrate` move here (instrument level) and are forwarded there for one release, then deleted — a change in the NonGravForces repo |
| B | preproc calls NonGravForces; rule: NonGravForces may call only gracefoReading L0 | no code moves, but each repo's CI must check out the other's `main`; a breaking change needs coordinated PRs in both; neither toolbox installs alone |

Why A: gracefoReading is the instrument-data layer, NonGravForces the physics
layer on top. QC on L1B residuals and calibration of an L1B instrument are
instrument-level; the CRN kernel they both need is owned here anyway. The
calibration must also accept a reference that did *not* come from
NonGravForces (ITSG, GROOPS), so taking it as data is required regardless.

Resulting graph, checked 2026-09-18 by searching every `.m` file of lsqvce
`ac981cd` and referenceSystem `311e060` for calls into gracefoReading or
NonGravForces (none found): **acyclic**.

```
referenceSystem <-- gracefoReading (L2 drivers)  <-- NonGravForces
lsqvce          <-- gracefoReading (L2 estimate) <-- (transitively, after P-13)
```

Consequence for NonGravForces: after P-13 it reaches lsqvce through
`gracefoReading.acc.calibrate`; its B.4 row ("lsqvce not a dependency")
stays true for its own code and must say so when P-13 lands.

---

## 4. Single point of access

One entry, chained after reading, **product-driven** (the chain is chosen by
`arc.product`, which is read from the file — R3, never declared):

```matlab
% read — L0, unchanged
files       = gracefoReading.findL1bFiles(root, "ACT1B", 'Satellite', "C", 'DateRange', dr);
[t, a, aux] = gracefoReading.readL1bMulti(files, 'TimeFormat', "gpsns");
acc         = gracefoReading.Arc(t, a, aux);             % the chain point; metadata travels

% easy: the product preset
res = gracefoReading.preprocess(acc, 'Reference', mdl);  % mdl: an Arc of modelled accelerations

% powerful: one Config, every knob, reproducible
cfg = gracefoReading.preproc.Config(acc);                % preset for the measured product
cfg.acc.scale = "full";  cfg.fill.method = "collocation";
res = gracefoReading.preprocess(acc, cfg, 'Reference', mdl, 'Drivers', drv);

% LRI — same entry, other product
lri = gracefoReading.Arc(tl, rl, auxl);   kbr = gracefoReading.Arc(tk, rk, auxk);
res = gracefoReading.preprocess(lri, 'Reference', kbr, 'Drivers', drv);
```

Three interface levels, **one code path** (v3 F4): `preprocess` only
composes the stage functions below; a user who chains the stages by hand runs
the same code. Every stage is `Arc → Arc (+ info)` or `Arc → result`.

`res` (field set pinned by a contract test):

| field | content |
|---|---|
| `arc` | cleaned `Arc`: weights, named mask layers, `filled` layer, provenance |
| `reference` | the reference aligned onto `arc` epochs (CRN-consistent) |
| `calibration` | `acc.Calibration` (apply / invert / summaryTable / save / load) or the LRI comparison struct |
| `diagnostics` | preflight gates, per-layer removal counts, alignment verdict, noise model |
| `correlation` | driver table and binned maps (section 7) |
| `flags` | unique warning identifiers with their messages, in order of first occurrence |
| `config` | the resolved `Config`; `preprocess(arc, res.config, …)` reproduces `res` |
| `provenance` | toolbox + dependency versions, config SHA-256, input content hashes, UTC time |

---

## 5. Data model

**`gracefoReading.Arc`** (value class). Constructed from the reader's triple;
refuses anything but `int64` gpsns time (`gracefoReading:Arc:timeFormat`).

| property | type, size | source |
|---|---|---|
| `t` | int64 N×1, strictly increasing | reader, gpsns |
| `obs` | double N×M | reader |
| `names`, `units` | string 1×M | file header (`aux.obsNames`, `aux.variableUnits`) |
| `product`, `satellite`, `frame`, `frameSource` | string | `aux`; a frame not stated by the file or by an explicit option stays `""` and a stage needing it refuses (v3 F5) |
| `weights` | double N×1 in [0,1] | `min` over layers; fits scale rows by √w |
| `layers` | struct of N×1 logical, true = remove | additive, named; layers only ever remove |
| `filled` | logical N×1 | samples created by the gap stage; weight 0 in every fit |
| `provenance` | struct array, append-only | one entry per stage |

**Columns are selected by name through a product dictionary** (ACT1B:
`lin_accl_x/y/z`; LRI1B: taken from the real header, V-3). No positional
fallback: a missing name errors and lists what exists (v3 F5).

**`preproc.Config`** — the single source of settings. Sections: `mask`,
`qc`, `crn`, `fill`, `align`, `acc`, `lri`, `estimate`, `unc`, `drivers`,
`run`. `Config(arc)` gives the preset for the measured product; unknown
fields error; the resolved object is hashed (SHA-256) into provenance.
Options whose default would be an assumption default to **empty** and the
report says which value was used (R5).

---

## 6. Pipeline

### 6.1 Common skeleton (both chains)

| # | stage | function | what it guarantees |
|---|---|---|---|
| 1 | mask | `preproc.mask` | qualflg layers via `decodeQualFlags` (file's own meanings); THR1B windows (pre/post margins justified by the CRN span); eclipse transitions from a driver series; CRN edges; user layer |
| 2 | QC | `preproc.qc` | residual-based outliers, impulses (matched filter on the CRN impulse response, THR1B priors), jumps (reported, become parameters — never masked) |
| 3 | align | `preproc.align`, `preproc.checkAlignment` | reference onto observation epochs; lag diagnostic ±60 s, warns > 1 s, **never shifts silently** (v3 F2) |
| 4 | consistency | `preproc.crnKernel`, `preproc.crnApply` | exact ATBD kernel, normalised at f0 (DC gain 1.0004533 kept); chunked per file day with half-span overlap, bit-identical to unchunked; NaN edges, never reflection |
| 5 | preflight gate | `preproc.observability` | refuses or downgrades unidentifiable parameters **before** the fit |
| 6 | systematics | `acc.calibrate` / `lri.compareKbr` → `preproc.estimate` | pre-estimate or pre-eliminate (6.4) |
| 7 | uncertainty | lsqvce whitened covariance, `preproc.bootstrap`, `preproc.crossval`, `acc.eivBound` | honest sigmas under coloured noise |
| 8 | gaps | `preproc.fill` | policy from `Config.fill` (6.5) |
| 9 | correlation | `preproc.drivers`, `preproc.correlate` | section 7 |
| 10 | output | `res`, `acc.Calibration.save`, `writeGroopsInstrument` | GROOPS export inherits O-2 (writer unverified) |

### 6.2 ACC chain (`+acc`)

Observation model per axis i, after masking and with H the CRN kernel:

  y_i(t) = H∗b_i(t) + Σ_j S_ij·(H∗a_j)(t) [+ K2_i·(H∗a_i)², demeaned] [+ 1/rev] [+ Σ jumps] + e_i(t),  e coloured.

- Bias basis `constant | linear | hat | pspline`, filtered by H like every
  deterministic column (v2 insight: `[H·B, H·a]`); knot spacing below the
  kernel span warns.
- Scale `diag | full | mask`. **Cross-track scale fixed by default**
  (low sensitivity); `full` S gated by the model-axis VIF (v3 I.5-3).
- **Refused combination**: per-revolution scale together with 1/rev empirical
  terms (measured anti-correlation r ≈ −0.7).
- Time-varying s(t) only with its pointwise σ band and an `isDriftSignificant`
  flag (v3 I.5-1).
- Every scale is reported with the errors-in-variables attenuation bound
  (v3 D4) — a bound, not a correction.
- Satellite D ACT1B is a transplant product: its "calibration" measures the
  transplant, and the report says so (V-5).
- `acc.Calibration`: apply / invert (with the EIV caveat) / summaryTable /
  versioned save and load.

### 6.3 LRI chain (`+lri`)

- `lri.observables`: range, range-rate, range-acceleration with the
  correction columns the **real header** declares (light-time, antenna
  offset — names, signs and presence from `LRI1B_2020-01-01_Y_04`, V-3).
- `lri.detectPhaseJumps`: a range step is a CRN-shaped doublet in
  range-acceleration; matched-filter detection through the same `preproc.qc`
  machinery with the CRN derivative kernel as template.
- `lri.compareKbr`: KBR (5 s) and LRI (2 s) on common epochs with
  CRN-consistent filtering (presets V-2); estimates through
  `preproc.estimate`: time-tag offset (bounded, reported), LRI/KBR scale
  factor, bias/drift of the difference; residual difference is the product.
- `lri.spectrum`: ASD of LRI, KBR and their difference (gap-aware).
- Residuals against a reference orbit or gravity field are **out of scope**
  (Q4, proposal in force): they need orbit integration and a background field.

### 6.4 Pre-estimation versus pre-elimination (`Config.estimate.mode`)

- `"preestimate"`: nuisance parameters are estimated, applied to the data,
  reported with covariance. `res.arc` holds corrected data.
- `"preeliminate"`: the nuisance columns are **not** subtracted; they are
  handed on as lsqvce *local* parameters (`localParams`, scope `arc`/`day`)
  so the downstream adjustment reduces them by Schur complement under its own
  stochastic model. `res` carries the nuisance design, not an estimate.
- Both run through `preproc.estimate`, the only caller of `lsqvce.fit`.
  Regularisation is declared as lsqvce priors; its weight comes from the
  variance-component estimate (REML-type) or blocked CV — plain GCV is not
  offered (v3 D2).

### 6.5 Gaps (`Config.fill`) — **decided (Q3)**

| method | fills | proposed use |
|---|---|---|
| `none` (**default**) | nothing; gaps are reported (`findGaps`), arcs split there | estimation, and every run that does not ask |
| `collocation` (on request) | least-squares prediction with the **fitted** noise covariance (lsqvce model), gaps ≤ `maxGap` only | consumers needing continuity |
| `reference` (on explicit request) | calibrated reference (ACC: S·H∗a + b; LRI: aligned KBR) + collocated residual | continuity across gaps longer than collocation can bridge |

`maxGap` has **no default** (R5): `collocation` or `reference` without it
refuses with `gracefoReading:preproc:fill:maxGapMissing`. Gaps longer than
`maxGap` stay unfilled and are reported, never silently bridged.

Filled samples are always in `arc.filled`, carry weight 0 in every fit, and
are counted in the report. A filled sample never re-enters an estimate: model-
aided filling imprints the model into the data.

---

## 7. Correlation analysis (`preproc.drivers`, `preproc.correlate`)

**Drivers** on the arc epochs, computed once and shared by both chains:
β′ angle and argument of latitude (GNV1B via L0 + `referenceSystem`
ITRS→GCRS + Sun), eclipse factor and space weather (data, Q1), thruster
counts (THR1B), LRI/KBR SNR, reference-force constituents when supplied.

**Methods**, each with significance that respects autocorrelation:
- lagged correlation of pre-whitened series (lag bound stated);
- per-revolution parameters (gated windows, NaN with reason when the gate
  fails) regressed on drivers, VIF > 10 → verdict `unresolved`;
- partial correlation, to separate β′ from eclipse fraction;
- **binned maps** residual(β′, u) — the classical view in which
  β′-dependent systematics become visible;
- effective sample size from the residual ACF, block-bootstrap CIs; naive
  sigmas are known to be 5–14× too small here.

---

## 8. Rules carried over — measured, do not re-litigate

| rule | evidence |
|---|---|
| exact ATBD CRN kernel only; normalise at f0, keep DC gain 1.0004533 | approximate kernel −11.5 % scale; unit-DC renormalisation +453 ppm (v2 refval) |
| model and bias basis through the same kernel as the observation | unfiltered comparison biases scale to ≈ 0.49 (v2) |
| observability gate before the fit; demean regressors | corr(bias, scale) = −1 on quiet arcs (v2) |
| never co-estimate per-rev scale and 1/rev terms | r ≈ −0.7 (v2) |
| block bootstrap for sigmas | naive 5–14× optimistic (v2) |
| int64 gpsns; no double for GPS time | 2020 gpsns ≈ 6.3e17 > 2^53 (repo decision 2026-08-14) |
| qualflg meanings from the file header | O-1 lesson: invented formats fail on real files |
| deterministic opt-in parallelism; RNG substream per replicate, seed per stage name | results independent of worker count and of stage insertion |

GRACE-FO CRN parameters are the GRACE ATBD ones and are **unverified** for
GRACE-FO (V-1): `crnKernel` warns until a named constant cites the handbook.

---

## 9. Validation

**Test categories** for every new public unit (tags):
`contract`, `reference`, `precision`, `speed` (ratio budget), `robustness`,
`vectorisation`, `metamorphic`; an exemption row states why a category is
impossible, never why it is inconvenient. `contract` is never exempt.
Predict per-class counts as passed + failed + incomplete = total before
every run (HANDOVER A).

**Oracle register** (nothing built here checks itself):

| id | oracle | checks |
|---|---|---|
| ORC-1 | GRACE L1B ATBD App. B via Python port `refval/crn_atbd.py` (from v2 zip) | kernel taps, DC gain, derivatives |
| ORC-2 | v2 keystone numbers regenerated in Python (not MATLAB) | 0.49, +453 ppm, 5–7× inflation, lag-1 ACF > 0.8 |
| ORC-3 | real 2020-01-01 ACT1B/THR1B/GNV1B (C), KBR1B, LRI1B in `READING_DATA_POOL` | dictionaries, masks, end-to-end smoke |
| ORC-4 | ITSG `nonConservativeForces` 2020-01-01 (bundled, trimmed) | independent reference series (nature: V-4) |
| ORC-5 | analytic circular orbit (Python) | β′, u, eclipse entry/exit |
| ORC-6 | numpy least squares on white noise | the lsqvce bridge equals the textbook solution |
| ORC-7 | synthetic truth generators `acc.syntheticPair`, `lri.syntheticPair` with planted S, b(t), K2, jumps, thrusters, gaps, phase jumps | recovery and flagging, fixed seeds |

**Verification items** (answered from documents or real bytes, never from memory):

| id | item | blocks |
|---|---|---|
| V-1 | GRACE-FO ACC CRN parameters vs JPL D-56935 | removal of the `crnKernel` warning |
| V-2 | KBR1B and LRI1B CRN parameters | P-11 |
| V-3 | LRI1B correction columns, signs, units from the real header | P-11 |
| V-4 | ITSG `nonConservativeForces`: model or calibrated measurement? CRN-filtered? | ORC-4 use |
| V-5 | ACT1B satellite D transplant statement in the header | wording of the D report |
| V-6 | lsqvce 6.1: local parameters + priors + ARMA/PSD + robust in one `fit` call, read from source | P-05 (NonGravForces B.4: that surface was misdescribed twice) |

---

## 10. Work packages (Claude Code), dependency order

Each WP: frozen scope written into HANDOVER first, one branch, draft PR at
once, help block (repo template) + tests (all tags) + regenerated HTML in the
same change, version bumped once at batch end (1.0.2 → 1.1.0, additive).

| WP | content | replaces v3 | needs |
|---|---|---|---|
| P-00 | layering test; optional-dependency resolution + `depMissing`; deterministic-parallel helper (internal); CI checks out referenceSystem + lsqvce; `docsrc` and `auditHelp.py` extended to sub-packages; test-tag convention. **Workflow change, own PR** | WP-00, WP-05 | Q5 |
| P-01 | `Arc` | WP-01 (no time code) | P-00 |
| P-02 | `crnKernel`, `crnApply`, `acc.syntheticPair` (pulled forward) | WP-10, WP-21 | P-01 |
| P-03 | `mask`, `qc` (port of NonGravForces.qc if Q1 = A) | WP-06 | P-01, P-02 |
| P-04 | `align`, `checkAlignment` | WP-02 part, WP-11 part | P-01, P-02 |
| P-05 | `estimate` (lsqvce bridge), `observability` | WP-07, WP-09, WP-12 | P-01, V-6 |
| P-06 | `acc.design`, `acc.calibrate`, `acc.Calibration` | WP-08, WP-13, WP-18 | P-02..P-05 |
| P-07 | `acc.timeVarying`, `acc.compare`, `bootstrap`, `crossval`, `acc.eivBound` | WP-14, WP-15 | P-06 |
| P-08 | `fill` | — (new) | P-05 |
| P-09 | `drivers`, `correlate`, `acc.perRev`, `acc.attribute`, `acc.decomposeScale` | WP-16, WP-17 | P-05 |
| P-10 | `Config`, `preprocess`, ACC integration test (files on disk → planted truth) | WP-19 | P-01..P-09 |
| P-11 | `lri.observables`, `lri.detectPhaseJumps`, `lri.compareKbr`, `lri.spectrum`, `lri.syntheticPair`, LRI integration test | — (new) | P-10, V-2, V-3, Q4 |
| P-12 | `preproc.report` (figures, HTML summary) | WP-20 | P-10 |
| P-13 | NonGravForces side: forward `qc` / `app.calibrate` to here, then delete (in that repo); update its B.4 and dependency table | — | P-10 |
| P-14 | V-1 GRACE-FO CRN verification | WP-24 | handbook |

Retired without replacement: v3 WP-02 `toGps/fromGps/leapSeconds`
(referenceSystem), WP-03/04 readers (L0), WP-22 benchmark harness (speed
ratios live in the tests), WP-23 (the existing `docsrc` pipeline builds all
documentation from help blocks), WP-25 `fromSca1b` (referenceSystem +
`NonGravForces.geom.AttitudeProvider`).

---

## 11. Decisions

| id | question | status |
|---|---|---|
| Q1 | Dependency direction to NonGravForces (3.2) | **decided 2026-09-18: A** — acyclic; NonGravForces outputs enter as data; its `qc` and `app.calibrate` move here |
| Q2 | Estimator core | **decided 2026-09-18: `lsqvce.fit`** — NonGravForces B.4 named the re-entry condition itself; coloured-noise GLS and multi-arc pre-elimination meet it. V-6 still gates P-05 |
| Q3 | Gap filling default | **decided 2026-09-18: `none`**; `collocation` ≤ `maxGap` on request; `maxGap` has no default (6.5) |
| Q4 | LRI analysis beyond L1B-internal and KBR comparison? | open — proposal in force until overridden: no; LGD and orbit residuals stay downstream. Gates P-11 |
| Q5 | Help footer: repo rule (Author line without model, dates only) vs "time, date, Claude version" | open — proposal in force until overridden: keep the repo rule; model and time go in commit and PR. **Gates P-00** (overriding it changes `auditHelp.py`) |
| Q6 | Classic GRACE in v1.1? | open — proposal in force until overridden: no; after O-1 |

---

## 12. What a next session would be wrong for not reading

1. This is a **draft**; Q1–Q3 are decided, Q5 gates P-00, Q4 gates P-11,
   Q6 gates classic-GRACE work. Do not start from the v3
   handover's Part IV prompts: five of its packages re-implement capabilities
   that have an owner (section 2).
2. `NonGravForces` already ships `app.calibrate` and `qc.screen`. Building a
   third calibration or QC would repeat v2's two-orchestrator drift (v3 F4)
   across repositories.
3. The legacy zip is **v2.4.2**, not the v2.5.0 the v3 handover reviewed.
4. The CRN kernel is needed by ACC, KBR, LRI and NonGravForces; it is owned
   here and nowhere else.
5. L0 must stay dependency-free and its contracts unchanged: NonGravForces
   calls `readL1bMulti` and relies on its `aux` fields (NonGravForces B.2).
   O-11 (`readL1bMulti` rejects `findL1bFiles`' column) is hit by the very
   first line of section 4 and should be fixed in P-00's neighbourhood,
   in its own PR.
