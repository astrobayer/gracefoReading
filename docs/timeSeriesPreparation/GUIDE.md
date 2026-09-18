# GUIDE — building the GRACE/GRACE-FO preprocessing chain, step by step

**Revision 1.0 · 2026-09-18 · written with Claude Opus 5 (Anthropic) for Matthias Weigelt**

This file is the **only authority for the order of work and for every
procedure**: preparing repositories, collecting data and references,
working through the repositories, and the branch → audit → gate → PR →
merge → tag → record loop.

What it does not hold, and where that lives instead:

| content | authority |
|---|---|
| **design** (what each WP builds) | `CONCEPT.md` |
| **status and decisions** of a repository | that repository's HANDOVER |
| **work queue** | GitHub issues |

This guide cites work packages by ID and never restates them.

Who does what:

| role | does |
|---|---|
| **You** | decides, reviews, **merges**, supplies data and documents, runs MATLAB when no MCP bridge answers |
| **Session** | a Claude Code (or chat) session working in **one** repository: implements, audits, pushes, opens draft PRs, writes the record; **never merges** |

---

## 1. The standard loop — identical in every repository

Every WP runs through these thirteen steps. Nothing is skipped; where a step
does not apply, the PR body says why.

| # | step | who | what exactly |
|---|---|---|---|
| 1 | Start | Session | `git fetch && git checkout main && git pull --ff-only`. Read the repository's HANDOVER, the WP row in `CONCEPT.md` 10.1, and the WP's issue. Declare the **tier** in the first line: A = MATLAB reachable (MCP bridge), B = no MATLAB. |
| 2 | Branch | Session | `git checkout -b claude/<wp-id>-<slug>` (for example `claude/g-01-multi-column`). Your own branches: `mw/<wp-id>-<slug>`. Always from a current `main`. |
| 3 | Freeze the scope | Session | First commit on the branch: `record: freeze scope <WP-ID>` in the HANDOVER, stating what will be true afterwards and what is out of scope. |
| 4 | Implement | Session | Code, help block (template: `CONCEPT.md` 9.1), tests in all seven categories, regenerated documentation — **in the same change**. Commit messages: `<type>: <summary>`, with type ∈ `feat` `fix` `docs` `test` `record` `chore` `ci` `security`. |
| 5 | Static audit | Session | The repository's audit command (section 2). It must exit 0 before any push. |
| 6 | Predict | Session | Test count per class as **passed + failed + incomplete = total**, written into the PR body **before** any run. |
| 7 | Push, then a draft PR at once | Session | `git push origin HEAD:refs/heads/<branch>`, check with `git ls-remote`. Open a **draft** PR immediately, title `<WP-ID>: <summary>`, body from section 5, containing `Closes #<issue>`. A branch without a PR gets **no CI run**. |
| 8 | CI | automatic | Every required check of the repository (section 2) must be green on the **last** commit. |
| 9 | Local gate | You or Session (tier A) | The repository's MATLAB gate command (section 2). The verdict goes into the PR body with the date and the MATLAB release. |
| 10 | Record | Session | HANDOVER rows in **the same PR**: measured status, the verdict per tier, any debt with its reason, and the "next session" note. **No record, no merge.** |
| 11 | Ready | Session | Mark the PR ready, citing both verdicts: CI run id and local gate. |
| 12 | Merge | **You only** | Checklist in section 6. Method: **Create a merge commit**. Then delete the branch. |
| 13 | Release | You + Session | Only when the WP completes a release (section 3): version bump in the PR before the merge; after the merge an annotated tag and a GitHub release; open the PRs that raise downstream minimum versions. |

**Standing rules**
- **One open PR per repository.** A batch is one PR with one commit per WP
  row.
- **Workflow changes stand alone.** Anything under `.github/`, a gate script
  or an audit script is its own PR, and you read it before merging.
- **A tier that is unavailable is a recorded debt, not a skip.** A merge on
  the other tier's green is allowed only if the record row names the debt and
  its reason. The later run that clears it says so.
- **Every new check is fault-injected in the same PR:** it must fire on a
  broken input and stay silent on a healthy one.
- **Token:** read from the project file at call time, never echoed, never in
  a remote URL, output piped through `sed "s/$TOKEN/***/g"`.
- **Tags are never moved or deleted.** The rulesets forbid it anyway.

---

## 2. Per-repository parameters (measured 2026-09-18)

All seven repositories are **private**. Each has a ruleset `Main Protection`
(no deletion, no force push, required status checks) and a tag ruleset
(`~ALL`: no deletion, no force push). The MATLAB suites run on the
**self-hosted Windows runner**.

**Where the record and the version live**

| repository | record file | version source |
|---|---|---|
| gracefoReading | `HANDOVER.md` (A status, E obligations, F decisions) | `Contents.m`, `version.m`, `docsrc/functionSpecs.json` (three literals, O-3) |
| referenceSystem | `HANDOVER_referenceSystem.md` (revision rows) | `Contents.m` |
| NonGravForces | `HANDOVER.md` (Part H obligations, Part I decisions); `CLAUDE.md` names the obligation range | `Contents.m` / `toolboxVersion` |
| lsqvce | `dev/HANDOVER.md` | `Contents.m` |
| ci-actions | `README.md`, `VERSIONING.md` | tags |
| timeSeriesPreparation (new) | `HANDOVER.md`; `docs/CONCEPT.md`, `docs/GUIDE.md` | `Contents.m` |
| rangingPreparation (new) | `HANDOVER.md` | `Contents.m` |

**How to check a change** (static audit runs without MATLAB; the gate needs
MATLAB)

| repository | static audit | MATLAB gate | required CI checks |
|---|---|---|---|
| gracefoReading | `python3 docsrc/sourceIntegrity.py && python3 docsrc/auditHelp.py && python3 docsrc/generate_docs.py && git diff --exit-code -- html/` (then `git checkout -- doc/gracefoReading_Guide.pdf` if only its timestamp moved) | `setupGraceFOReading; addpath('ci'); runCI('Exit', true)` | `MATLAB suite`, `Help audit and docs in sync` |
| referenceSystem | `python3 auditPackage.py` and `sh test/c/runStandaloneTests.sh` | `matlab -batch referenceSystemCiGate` | `audit`, `csuites`, `matlab` |
| NonGravForces | `python3 auditPackage.py` | `matlab -batch ciGate` | `matlab`, `audit` |
| lsqvce | `python3 dev/docs_src/audit_tree.py && python3 dev/docs_src/audit_selftest.py` | `matlab -batch "cd('dev/tests'); ci_gate"` | `audit`, `matlab` |
| ci-actions | — | — | none; a PR is required |
| timeSeriesPreparation | shared audit (C-01) | `matlab -batch timeSeriesPreparationCiGate` (X-00b) | `audit`, `matlab` (set after the first CI run) |
| rangingPreparation | shared audit (C-01) | `matlab -batch rangingPreparationCiGate` (L-00) | `audit`, `matlab` (set after the first CI run) |

**What CI needs besides the code**

| repository | data pool | sibling checkouts |
|---|---|---|
| gracefoReading | variable `READING_DATA_POOL` | — |
| referenceSystem | variable `REF_DATA_POOL` | — |
| NonGravForces | fetched by `setupNonGravForces` | `REFERENCE_READ_TOKEN`: referenceSystem, gracefoReading, odeSuite |
| lsqvce | — | — |
| ci-actions | — | — |
| timeSeriesPreparation | `READING_DATA_POOL` | `REFERENCE_READ_TOKEN`: gracefoReading; lsqvce (tests only) |
| rangingPreparation | `READING_DATA_POOL` | `REFERENCE_READ_TOKEN`: referenceSystem, gracefoReading, timeSeriesPreparation, lsqvce |

---

## 3. Versioning, tagging, releases — the same everywhere

This follows `ci-actions/VERSIONING.md`, which remains the authority.

- **Semantic versioning, `MAJOR.MINOR.PATCH`.** `Contents.m` holds the
  single source.
  - PATCH = fixes; it is **not** a revision counter.
  - MINOR = new capability that leaves callers working.
  - MAJOR = a caller breaks.
  - New repositories start at `0.y.z`.
- **Version bump:** its own commit (`chore: version X -> Y`) in the release
  PR, touching every literal the repository has. `Updated:` stamps move only
  where content changed.
- **Tag after the merge, on the merge commit of `main`:** annotated, lowercase
  `v`, never moved.
  ```bash
  git fetch origin && git checkout main && git pull --ff-only
  git tag -a vX.Y.Z -m "<repo> vX.Y.Z - <one line from the CHANGELOG>" <merge-sha>
  git push origin vX.Y.Z
  git ls-remote --tags origin vX.Y.Z          # read it back
  ```
- **GitHub release** for the tag, with the CHANGELOG section as notes (web UI
  or `gh release create vX.Y.Z --notes-file <file>`).
- **Dependency minimums** (`MAJOR.MINOR`) move in the same PR as the
  dependency's version change that requires them.

**Measured anomalies — record them, do not "fix" them (tags are
immutable)**

| repository | anomaly | action at its next release |
|---|---|---|
| referenceSystem | `Contents.m` 2.1.244, while tags `v2.2.0` and **`V2.2.1`** (capital V) exist; all tags lightweight; the revision counter kept counting after VERSIONING.md | issue referenceSystem#27: release **2.3.0** (proposal), annotated |
| lsqvce | `Contents.m` 6.1, newest tag `v5.2.1` | issue lsqvce#107: tag **v6.1.0** before any consumer declares lsqvce ≥ 6.1 |
| NonGravForces | stray tag `v.0.10.0`; five lightweight tags | recorded in O-26; next tags annotated |
| gracefoReading | `v1.0.0` and `v1.0.2` lightweight (`v1.0.1` annotated) | O-4; next tags annotated |
| ci-actions | README says gracefoReading has no required contexts; the ruleset requires two | handled in C-01 (ci-actions#2) |

---

## 4. Stage A — prepare (once, before any code)

**A1 — Replace the token (do first).** The current token sits in plain text
in this project's files.

1. GitHub → Settings → Developer settings → Fine-grained tokens → **Generate
   new token**.
2. **Repository access:** only select repositories — gracefoReading,
   referenceSystem, NonGravForces, lsqvce, ci-actions, timeSeriesPreparation,
   rangingPreparation (the last two once they exist; edit the token then).
3. **Permissions:**
   - Contents: Read and write
   - Pull requests: Read and write
   - Issues: Read and write
   - Actions: Read and write
   - **Workflows: Read and write** (needed to push `.github/workflows` files)
   - Metadata: Read
   - **Not** Administration: rulesets stay manual.
4. **Expiry:** 30–90 days.
5. Replace `GitHub_Access_Token.txt` in the Claude project; **revoke** the old
   token.
6. **Checkpoint:** a session reads one repository's metadata with the new
   token.

**A2 — Organisation settings.**
- **Variable `READING_DATA_POOL`** at organisation level, visible to
  gracefoReading, timeSeriesPreparation and rangingPreparation. Its value is
  the pool path on the runner machine. The existing repository variable keeps
  working; the organisation variable becomes the single authority for new
  repositories.
- **Secret `REFERENCE_READ_TOKEN`** at organisation level: a separate
  fine-grained token with Contents: Read on gracefoReading, referenceSystem,
  lsqvce, odeSuite and timeSeriesPreparation. It must be visible to
  NonGravForces, timeSeriesPreparation and rangingPreparation.
- **Self-hosted runner:** an organisation runner group that includes the two
  new repositories. The alternative is to register the runner per repository.
- **Checkpoint:** in each new repository, Settings → Actions shows the runner
  and the variable.

**A3 — Create `timeSeriesPreparation`.**
1. New repository, **private**, containing only a README; licence as for the
   other toolboxes (MIT, as gracefoReading and NonGravForces).
2. Settings → General:
   - "Allow merge commits" on;
   - **"Automatically delete head branches" on**.
3. Settings → Rules → New ruleset **Main Protection**:
   - target `main`;
   - restrict deletions; block force pushes;
   - require status checks: add `audit` and `matlab` **after** the first CI
     run has created them.
4. New tag ruleset **Tag protection**, target `~ALL`: restrict deletions,
   block force pushes.
5. **X-00a (Session, in the new repository):**
   - move `docs/timeSeriesPreparation/` from gracefoReading's branch
     `claude/preproc-concept` to `docs/`: `CONCEPT.md`, `GUIDE.md`, `inputs/`;
   - add a `HANDOVER.md` stub (status: no code) and the README;
   - open PR #1 as a draft. There is no CI yet: you review and merge by hand,
     the only merge without CI.
6. **Then gracefoReading #15:**
   - the Session removes `docs/timeSeriesPreparation/`;
   - O-13 points to the new repository;
   - the G-01…G-06 records stay;
   - static audit, CI green, record, ready → **you merge**.
7. **Then NonGravForces #57:** the Session updates the concept path in O-45;
   audit, CI green → **you merge**.

**A4 — Create `rangingPreparation`.** Same settings as A3, steps 1–4. Its
content arrives with L-00, after C-01.

**A5 — Issues.**
- Existing repositories: the issues were opened on 2026-09-18 (appendix A).
- New repositories: the Session opens one issue per WP right after creation,
  using the rows of `CONCEPT.md` 10.1 (X-…, L-…).

**A6 — Labels (optional):** `wp`, `record`, `release`, `debt`, `workflow`, in
every repository.

---

## 5. Stage B — collect the data

**Pool layout.** The pool at `READING_DATA_POOL` stays **flat for the
existing day fixtures**: gracefoReading's tests look for original file names
directly in the pool root. Everything else goes below `archive/`:

```
<POOL>/                                        flat: 2020-01-01 fixtures (as today)
<POOL>/archive/gracefo/L1B/RL04/<yyyy>/        daily L1B archives / files
<POOL>/archive/gracefo/L1A/RL04/<yyyy>/        only if a WP needs L1A
<POOL>/archive/gracefo/ACX/…                   hybrid transplant (V-16)
<POOL>/archive/grace/L1B/…                     classic (D-8)
<POOL>/archive/itsg/GRACEFO-1|2/<product>/
<POOL>/archive/events/                         TN-01 SOE, TN-01a SCE, manoeuvres
<POOL>/archive/alt/lri1b/{aei,sysu,hust}/
<POOL>/archive/alt/attitude/
<POOL>/MANIFEST.sha256                         every file, with source checksum where published
```

**Data plan**

| id | what | days | source | used by |
|---|---|---|---|---|
| D-1 | L1B RL04, satellites C and D: ACT1B, ACC1B, ACH1B (if published), SCA1B, GNV1B, KBR1B, LRI1B, THR1B, MAS1B, MAG1B, housekeeping (V-13, V-14) | 2020-01-01 | PO.DAAC collection `GRACEFO_L1B_ASCII_GRAV_JPL_RL04` (DOI 10.5067/GFL1B-ASJ04, CMR `C2036882118-POCLOUD`; daily granules `gracefo_1B_<date>_RL04.ascii.LRI` / `.noLRI`), mirror `https://isdc-data.gfz.de/grace-fo/Level-1B/JPL/INSTRUMENT/RL04/` | G-04, ORC-3, X-10 |
| D-2 | the same products | 2020-01 (31 days) | as D-1 | N-10, ORC-10, ORC-12, V-12 |
| D-3 | ITSG operational products: kinematicOrbit, reducedDynamicOrbit, attitude, nonConservativeForces, and the server README files | 2020-01 | `https://ftp.tugraz.at/pub/ITSG/satelliteOrbitProducts/operational/` | V-4, ORC-4, N-12 |
| D-4 | official event lists TN-01 SOE, TN-01a SCE, manoeuvre lists (both missions) | whole missions | ISDC `grace-fo/DOCUMENTS/`, PO.DAAC documentation (V-15) | G-05, X-05 |
| D-5 | space weather, CERES | as NonGravForces fetches them | `setupNonGravForces('FetchData', …)` (existing mechanism) | N-02, N-11 |
| D-6 | alternative LRI1B products: AEI V50, SYSU, HUST | 2020-01 | the providers' pages (R-8) | ORC-13, L-09 |
| D-7 | alternative attitude: SCA+IMU fusion product (e.g. HUGG-01), plus ITSG attitude (D-3) | 2020-01 | publications / providers | N-12, L-07 |
| D-8 | **classic GRACE A/B**, one file per product, three days: (a) before April 2011; (b) after April 2011, thermal control off; (c) during the GRACE-A→B transplant (2016–2017) | 3 days | **you supply** | G-02, X-13, N-08, L-06 |
| D-9 | defect catalogue: one real day per defect class (V-12) | from D-2 | chosen by a Session and recorded in timeSeriesPreparation's HANDOVER (file, epoch range, expected verdict) | X-05, X-17, L-02, N-02 |
| D-10 | external calibration series (V-11) | as available | the cited publications' data sets | ORC-10 |

**Procedure (Linux or WSL; Earthdata login in `~/.netrc`).**

```bash
pip install podaac-data-subscriber
podaac-data-subscriber -c GRACEFO_L1B_ASCII_GRAV_JPL_RL04 -d "$POOL/archive/gracefo/L1B/RL04/2020" \
    -sd 2020-01-01T00:00:00Z -ed 2020-01-31T23:59:59Z
# unpack the daily archives; copy the 2020-01-01 files with their original names into $POOL (flat)
cd "$POOL" && find . -type f ! -name MANIFEST.sha256 -print0 | sort -z | xargs -0 sha256sum > MANIFEST.sha256
```

- **Never commit pool data** to any repository. The small trimmed fixtures
  under a repository's `tests/realdata/` are the only exception, as
  gracefoReading already does.
- **Checkpoint:** G-06 verifies the pool against the manifest. Until G-06
  exists, `sha256sum -c MANIFEST.sha256` does the same.

---

## 6. Stage C — collect the references

The single bibliography is the register `docs/references/REFERENCES.md` in
timeSeriesPreparation, created in X-00b.
- Each row: id, full citation, source URL, what it is needed for, whether a
  local copy is allowed, status.
- Local copies go in `docs/references/pdf/`, **only** for openly published
  documents (JPL/NASA documents, open-access papers). Everything else is
  registered by DOI only.
- **A V-item closes only when its number is read from the registered
  document**, with page or table cited in the HANDOVER row. The research
  answers in `CONCEPT.md` 9.2 are expected values, not facts.

**Documents**

| id | document | needed for | source |
|---|---|---|---|
| R-1 | Wu, Kruizinga, Bertiger: *GRACE Level-1B ATBD*, JPL D-27672 | V-1, V-2, ORC-1 | PO.DAAC / ISDC documents |
| R-2 | Wen et al.: *GRACE-FO Level-1 Data Product User Handbook*, JPL D-56935 (2019) | V-1, V-2, V-3, V-13 | `https://isdc-data.gfz.de/grace-fo/DOCUMENTS/Level-1/` |
| R-3 | McCullough et al.: *Calibrated GRACE-FO accelerometer data products (ACT)*, JPL D-103863 (2019) | V-5 | PO.DAAC GRACE-FO documentation |
| R-4 | Case, Kruizinga, Wu: *GRACE Level-1B Data Product User Handbook*, JPL D-22027 (2010) | V-8, G-02 | PO.DAAC GRACE documentation |
| R-5 | Bettadpur (2012): GRACE product specification with the macro model | V-9, N-07 | **you supply** (CSR / PO.DAAC) |
| R-6 | TN-01 / TN-01a event lists and their description | G-05, V-15 | ISDC / PO.DAAC |
| R-7 | ACX / ACX2 and RL06.3 release notes, GRACE-FO SDS newsletters | V-16 | PO.DAAC / GRACE Tellus |
| R-8 | SYSU LRI1B documentation (Table 1), AEI and HUST product descriptions | V-2, ORC-13 | provider pages |
| R-9 | ITSG server `README.txt`, `README_referenceFrames.txt` | V-4 | TU Graz FTP |

**Papers (DOI; local copy only if open access):**
- Bandikova et al. 2019, Adv. Space Res.
- Behzadpour et al. 2021, JGR Solid Earth
- Harvey et al. 2022, Adv. Space Res.
- Harvey & Sakumura 2019
- Klinger & Mayer-Gürr 2016, Adv. Space Res.
- Kvas et al. 2019, JGR Solid Earth
- Peterseim et al. 2012, Adv. Space Res.
- Pan & Xiao 2024, Sensors
- Yan et al. 2021, J. Geod.
- Müller et al. 2022, Remote Sensing
- Müller/Yan et al. 2025, J. Geod.
- Misfeldt et al. 2023, Remote Sensing
- Wegener et al. 2020, J. Spacecraft Rockets
- Abich et al. 2019, PRL
- Ren et al. 2022, Remote Sensing
- Hu et al. 2022, Remote Sensing
- Li et al. 2025, Remote Sensing
- Siemes et al. 2023, J. Space Weather Space Clim.
- Vielberg et al. 2020, J. Geod.
- Tapley et al. 2015

The full citations are in the research report of 2026-09-18; the register
copies them once.

---

## 7. Stage D — the order of work

**Principles**
1. Build from the bottom of the dependency graph upward.
2. Settle facts that could change a design (V-items) before building on them.
3. Ship small releases early, so downstream repositories can work in
   parallel.
4. Keep one open PR per repository.
5. Shared infrastructure comes before the repositories that use it.

Release numbers below are proposals. Each release PR decides from its
CHANGELOG: MINOR for new capability, PATCH for fixes.

### Phase 0 — prerequisites (no toolbox code)

| step | what | done when |
|---|---|---|
| 0.1 | Stage A (A1–A6) | token replaced; both repositories exist with rulesets; X-00a merged; #15 and #57 merged |
| 0.2 | Stage B, D-1 to D-7 (D-8 when you supply it, D-9 after D-2) | `MANIFEST.sha256` written; `sha256sum -c` passes |
| 0.3 | Stage C; close the V-items that documents answer: V-1, V-2, V-3, V-5, V-8, V-13 to V-16 | one docs-only PR in timeSeriesPreparation per batch, each V row citing page or table |
| 0.4 | lsqvce#107: V-6 read from source, then release **lsqvce v6.1.0** (annotated) | tag read back |

### Phase 1 — foundations, four repositories in parallel

| repository | sequence | release after |
|---|---|---|
| ci-actions | C-01 → C-03 → C-02 | tags `v1.1.0` (C-01), `v1.2.0` (C-03), `v1.3.0` (C-02) |
| gracefoReading | G-01 → G-03 → G-04 → G-05 → G-06 | `v1.0.3` after G-01; `v1.1.0` after G-06 |
| referenceSystem | R-01 (#25) → R-02 (#26), with #27 | `v2.3.0` |
| timeSeriesPreparation | X-00b (needs C-01) → X-01 | — |

### Phase 2 — timeSeriesPreparation, the critical path

X-03 → X-04 (**v0.1.0**) → X-05 (**v0.2.0**) → X-06 → X-02 → X-07 → X-08 →
X-09 → X-10 (**v1.0.0**) → X-14 → X-16 → X-15 (**v1.1.0**) → X-17 → X-18
(**v1.2.0**)

Downstream starts as soon as a release exists:

| release | NonGravForces | rangingPreparation |
|---|---|---|
| v0.1.0 | N-04 | L-00 (after C-01) → L-01 → L-04 |
| v0.2.0 | N-01 | L-02 |

### Phase 3 — applications

| repository | sequence | release after |
|---|---|---|
| NonGravForces | N-02 (with N-06; needs timeSeriesPreparation v1.0.0, R-02, lsqvce v6.1.0) → N-03 → N-11 → N-12 → N-09 (needs timeSeriesPreparation v1.1.0) → N-10 → N-05 | `v0.13.0` after N-02/N-06; `v0.14.0` after N-05 |
| rangingPreparation | L-03 → L-05 → L-08 → L-07 (needs N-12) → L-09 | `v0.1.0` after L-05; `v0.2.0` after L-09 |

### Classic GRACE track — starts when D-8 arrives, in parallel

G-02 (gracefoReading `v1.2.0`) → X-13 → N-07 (needs R-5) → N-08, and X-13 →
L-06.

### Phase 4 — closing

X-11 (reports), C-04 (the executed processing-chain page), X-12 (when the
handbook is available).

**Critical path to the first calibration:** C-01 → X-00b → X-01 → X-03 →
X-04 → X-05 → X-06 → X-02 → X-07 → X-08 → X-09 → X-10 → N-02.

---

## 8. Checklists and templates

**PR body (every PR)**

```
Closes #<issue>.  WP <ID> — CONCEPT.md 10.1 row <ID>.
Tier: A | B — <what the tier does not give>.
Scope (frozen in HANDOVER <row>): <one paragraph>.
Prediction: <passed> + <failed> + <incomplete> = <total>   (per class: …)
Static audit: <command> → <exit code / findings>.
CI: run <id> → <each required check>.
Local gate: <command>, <MATLAB release>, <date> → <verdict>.
Record: HANDOVER <rows>.   Debt: none | <named, with reason>.
Release: none | vX.Y.Z (bump commit <sha>).
```

**Merge checklist (you)**
1. Every required check is green on the **last** commit.
2. The local gate verdict is cited, or the missing tier is named as a debt.
3. The prediction matches the measured run: all three numbers.
4. The record rows are in the diff, and the HANDOVER status line quotes
   measured numbers.
5. Any `.github/` or gate change has been read line by line.
6. **Create a merge commit** → delete the branch → check that the issue
   closed.
7. If a release: section 3 (tag, read back, GitHub release), then open the
   downstream minimum-version PRs.

**Release checklist (Session, inside the release PR)**
1. `chore: version X -> Y` touches every version literal; CHANGELOG section
   written.
2. Documentation regenerated; the static audit is clean after the bump.
3. Record row: version, verdicts, what the release contains (WP IDs).

**Session preamble (paste at the start of every Claude Code session)**

```
Repository <name>, WP <ID>, issue #<n>. Read the HANDOVER, CONCEPT.md 10.1 row <ID>
and GUIDE.md sections 1-3 before any code. First line of your reply: the tier.
Follow the standard loop (GUIDE 1) with this repository's commands (GUIDE 2).
Freeze the scope in the HANDOVER first; predict the test count; open a draft PR
at once; never merge; never move a tag; token rules as in GUIDE 1.
Close with: record entry, verdict per tier with debts, next-session note,
next action as a command.
```

---

## Appendix A — issue map (opened 2026-09-18)

| repository | WP → issue |
|---|---|
| gracefoReading | G-01 #16 · G-02 #17 · G-03 #18 · G-04 #19 · G-05 #20 · G-06 #21 |
| referenceSystem | R-01 #25 · R-02 #26 · versioning #27 |
| NonGravForces | N-01 #58 · N-02 #59 · N-03 #60 · N-04 #61 · N-05 #62 · N-06 #63 · N-07 #64 · N-08 #65 · N-09 #66 · N-10 #67 · N-11 #68 · N-12 #69 |
| lsqvce | release v6.1.0 + V-6 #107 |
| ci-actions | C-01 #2 · C-02 #3 · C-03 #4 · C-04 #5 |
| timeSeriesPreparation | opened at creation (A5): X-00a … X-18 |
| rangingPreparation | opened at creation (A5): L-00 … L-09 |
