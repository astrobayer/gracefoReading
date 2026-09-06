# Continuous integration — setup guide

Toolbox: gracefoReading v1.0.0
Developed by Matthias Weigelt with the help of Anthropic Claude Opus 5, 2026-08-14.

This document explains how to run the toolbox test suites automatically:
locally, on GitHub-hosted runners, and on a self-hosted runner at the
institute. Everything routes through one entry point, `ci/runCI.m`, so
the command is identical in all three places.

---

## 1. What CI runs

| Job | What it does | Where |
|---|---|---|
| `matlab-tests` | `runCI('Exit', true)` → all suites in `tests/`, JUnit + Cobertura reports in `artifacts/` | Linux + Windows, R2024b; plus R2020b on Linux (oldest supported release) |
| `documentation` | `docsrc/auditHelp.py` (help-text standard) and regeneration of `html/` with a `git diff --exit-code` check | Linux, Python 3.11 |

Both platforms are tested deliberately. The two defects that survived
release testing in this toolbox were platform-specific: an in-memory
Java gzip read that silently returned zeros, and CRLF line endings from
`fopen(...,'wt')` on Windows. Neither is visible on the other platform.

The R2020b entry guards the documented minimum release: the toolbox uses
`arguments` blocks, so R2020b is the floor.

---

## 2. Local use — same command as CI

```matlab
cd <toolboxRoot>
addpath('ci');
results = runCI();          % reports in <toolboxRoot>/artifacts/
disp(table(results));
```

Options: `runCI('Coverage', false)` skips instrumentation (faster),
`runCI('OutputDir', "C:\temp\ci")` redirects the reports.

Batch mode, exactly as CI invokes it:

```bash
matlab -batch "addpath('ci'); runCI('Exit', true)"
echo $?      # 0 = all passed, 1 = failures
```

`'Exit'` exists because MATLAB in `-batch` mode returns status 0 even
when tests fail; without it a red build looks green. Do not use `'Exit'`
in an interactive session — it closes MATLAB.

Via the build tool: `buildtool test` (same runner), `buildtool release`
(audit + test + docs + check + zip).

---

## 3. GitHub-hosted runners

The workflow `.github/workflows/ci.yml` is ready to use. Requirements:

1. **Public repository** — `matlab-actions/setup-matlab@v2` installs
   MATLAB on GitHub-hosted runners and runs it without a licence for
   *public* repositories. This is the zero-configuration path.
2. **Private repository** — GitHub-hosted runners then need a licence.
   Two options:
   - a *batch licensing token*: obtain it from MathWorks
     (Licence Centre → batch licensing), store it as repository secret
     `MLM_LICENSE_TOKEN`, and add to the `setup-matlab` step:
     ```yaml
     - uses: matlab-actions/setup-matlab@v2
       with:
         release: R2024b
         products: MATLAB
       env:
         MLM_LICENSE_TOKEN: ${{ secrets.MLM_LICENSE_TOKEN }}
     ```
   - or use a self-hosted runner (section 4), which is usually the
     better fit for an institute with a network licence server.

Enabling: push the repository to GitHub — the workflow runs on every
push and pull request, weekly on Mondays, and on demand via the Actions
tab ("Run workflow", from `workflow_dispatch`).

Artifacts: each matrix job uploads `artifacts/` (JUnit XML and Cobertura
coverage). Download them from the run summary page. To display results
inline, add a reporter action such as `dorny/test-reporter` reading
`artifacts/testresults.xml`.

---

## 4. Self-hosted runner (institute machine with campus licence)

This is the recommended setup when MATLAB is licensed through a network
licence server (`MLM` / FlexNet), as at most universities.

### 4.1 Prepare the machine

- MATLAB R2020b or newer installed, licence working for the *runner
  user account* (test: `matlab -batch "disp(version)"`).
- Python 3.9+ with `reportlab` if the machine should also run the
  documentation job.
- Git installed.

### 4.2 Install the runner

On the machine (Linux example; Windows uses the same steps with the
`.zip` package and `run.cmd`):

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -o actions-runner-linux-x64.tar.gz -L \
  https://github.com/actions/runner/releases/latest/download/actions-runner-linux-x64.tar.gz
tar xzf actions-runner-linux-x64.tar.gz
./config.sh --url https://github.com/<org>/<repo> --token <REGISTRATION_TOKEN> \
            --labels self-hosted,linux,matlab
sudo ./svc.sh install && sudo ./svc.sh start     # run as a service
```

The registration token comes from the repository:
*Settings → Actions → Runners → New self-hosted runner*.

### 4.3 Point the workflow at it

```yaml
  matlab-tests:
    runs-on: [self-hosted, matlab]
    steps:
      - uses: actions/checkout@v4
      # no setup-matlab step: MATLAB is already installed
      - name: Run test suites
        run: matlab -batch "addpath('ci'); runCI('Exit', true)"
```

If MATLAB is not on `PATH` for the service user, give the absolute
executable, e.g.
`/usr/local/MATLAB/R2024b/bin/matlab -batch "..."` or
`"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -batch "..."`.

### 4.4 Licence environment

Set the licence server for the runner service, not only for interactive
shells:

```bash
# Linux, in ~/actions-runner/.env
MLM_LICENSE_FILE=27000@licence.your-university.de
```

```powershell
# Windows, system environment variable
setx /M MLM_LICENSE_FILE 27000@licence.your-university.de
```

Restart the runner service afterwards. A licence checkout failure shows
as `License checkout failed` in the job log, not as a test failure.

### 4.5 Housekeeping

- The runner keeps the working directory between jobs. `runCI` restores
  the MATLAB path on cleanup, and every test suite removes its temporary
  fixtures, so no state leaks between runs.
- `artifacts/` is overwritten each run; add it to `.gitignore`.
- Concurrency: one MATLAB licence seat is used per running job. Limit
  parallel jobs with `concurrency: {group: matlab-ci, cancel-in-progress: true}`
  if seats are scarce.

---

## 5. Other CI systems

`runCI` is plain MATLAB, so any system can drive it:

**GitLab CI** (`.gitlab-ci.yml`):

```yaml
matlab-tests:
  tags: [matlab]
  script:
    - matlab -batch "addpath('ci'); runCI('Exit', true)"
  artifacts:
    when: always
    reports:
      junit: artifacts/testresults.xml
    paths: [artifacts/]
```

**Jenkins** (declarative pipeline):

```groovy
stage('MATLAB tests') {
  steps { sh 'matlab -batch "addpath(\'ci\'); runCI(\'Exit\', true)"' }
  post  { always { junit 'artifacts/testresults.xml' } }
}
```

**Plain cron / institute scheduler**: the same `matlab -batch` line; mail
the exit status and attach `artifacts/testresults.xml`.

---

## 6. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Job green although tests failed | `'Exit'` not passed to `runCI`; MATLAB `-batch` always exits 0 otherwise. |
| `License checkout failed` | `MLM_LICENSE_FILE` not visible to the runner service; set it in `.env` (Linux) or as a system variable (Windows) and restart the service. |
| `Undefined function 'runCI'` | `addpath('ci')` missing, or the job did not start in the repository root. |
| Coverage step warns and is skipped | Release older than R2017b, or the package folder was moved; tests still run. |
| `documentation` job fails on `git diff` | `html/` was edited by hand or `generate_docs.py` was not rerun after editing `docsrc/functionSpecs.json`. Regenerate and commit. |
| Windows job fails on line endings | Repository checked out with `core.autocrlf=true` rewriting fixtures; set `.gitattributes` `* text=auto eol=lf` or disable autocrlf on the runner. |
| Tests pass locally, fail on the runner | Almost always a path or working-directory difference; `runCI` prints the toolbox root it used at the start of the log. |

---

## 7. Before the first run

- [ ] Repository created and pushed (the workflow file is inert until then).
- [ ] Decided: GitHub-hosted (public repo) or self-hosted (licence server).
- [ ] `matlab -batch "addpath('ci'); runCI('Exit', true)"` succeeds on the target machine, manually.
- [ ] `python3 docsrc/auditHelp.py` succeeds locally.
- [ ] `artifacts/` added to `.gitignore`.
