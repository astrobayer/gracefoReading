function plan = buildfile()
%BUILDFILE  Build tasks for the gracefoReading toolbox (buildtool, R2022b+).
%
%   SYNTAX
%     buildtool              % default task: test
%     buildtool test
%     buildtool audit
%     buildtool docs
%     buildtool check
%     buildtool guide
%     buildtool release
%     plan = buildfile()
%
%   DESCRIPTION
%     Single point of access for every repeatable maintenance action,
%     so that releases follow one command instead of a remembered
%     sequence. Two release defects in this toolbox came from manual
%     steps that were skipped, which is what these tasks prevent.
%
%     Tasks:
%       test    run all suites in tests/ via ci/runCI.m, producing
%               JUnit and Cobertura reports in artifacts/
%       audit   check every help block against the documentation
%               standard (docsrc/auditHelp.py)
%       docs    regenerate html/ and the PDF guide from
%               docsrc/functionSpecs.json, the single source of truth
%       check   run the documentation-consistency suite only
%       guide   regenerate the PDF user guide alone
%       release audit, test, docs and check, then package a versioned
%               zip archive next to the toolbox root
%
%   INPUT
%     (none) - buildtool passes a context to each task automatically
%
%   OUTPUT
%     plan - matlab.buildtool.Plan, 1x1
%                Task plan; returned when buildfile is called directly
%                rather than through buildtool.
%
%   ACCURACY AND LIMITATIONS
%     - Requires MATLAB R2022b or later for buildtool; on earlier
%       releases call ci/runCI.m and docsrc/generate_docs.py directly.
%     - The docs and guide tasks shell out to python3 and need
%       reportlab installed; they fail loudly if it is missing, since
%       silently shipping stale documentation is worse.
%     - The release task packages the working tree as it is; it does
%       not check version control status, so commit before releasing.
%     - Task dependencies are declarative, but buildtool does not
%       detect that a source file changed after docs ran; rerun the
%       release task rather than individual tasks when in doubt.
%
%   EXAMPLES
%     % 1. everyday development loop
%     buildtool test
%
%     % 2. full release preparation
%     buildtool release
%
%   See also runCI, buildtool, gracefoReading.version
%
%   Toolbox:  gracefoReading v1.3.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

plan = buildplan(localfunctions);
plan.DefaultTasks = "test";
plan("release").Dependencies = ["audit", "test", "docs", "check"];
end

function testTask(~)
% Run all suites through the CI entry point (JUnit + coverage reports)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'ci'));
c = onCleanup(@() rmpath(fullfile(here, 'ci'))); %#ok<NASGU>
results = runCI();
assertSuccess(results);
end

function auditTask(~)
% Check every help block against the documentation standard
here = fileparts(mfilename('fullpath'));
[rc, out] = system(sprintf('python3 "%s"', fullfile(here, 'docsrc', 'auditHelp.py')));
disp(out);
assert(rc == 0, 'Help-text audit failed; see the list above.');
end

function docsTask(~)
% Regenerate HTML reference and PDF guide from the help blocks
here = fileparts(mfilename('fullpath'));
[rc, out] = system(sprintf('python3 "%s"', fullfile(here, 'docsrc', 'generate_docs.py')));
disp(out);
assert(rc == 0, 'Documentation generation failed.');
end

function guideTask(~)
% Regenerate the PDF user guide only
here = fileparts(mfilename('fullpath'));
[rc, out] = system(sprintf('python3 "%s"', fullfile(here, 'docsrc', 'generate_guide.py')));
disp(out);
assert(rc == 0, 'Guide generation failed.');
end

function checkTask(~)
% Documentation-consistency suite only
here = fileparts(mfilename('fullpath'));
results = runtests(fullfile(here, 'tests', 'testDocConsistency.m'));
assertSuccess(results);
end

function releaseTask(~)
% Package the toolbox as a versioned zip next to the toolbox root
here = fileparts(mfilename('fullpath'));
v = gracefoReading.version();
zipName = fullfile(fileparts(here), "gracefoReading_v" + v + ".zip");
zip(zipName, here);
fprintf('Release archive: %s\n', zipName);
end
