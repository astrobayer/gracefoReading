function results = runCI(options)
%RUNCI  Continuous-integration entry point for the gracefoReading toolbox.
%
%   SYNTAX
%     results = runCI()
%     results = runCI(Name, Value)
%     matlab -batch "addpath('ci'); runCI('Exit', true)"
%
%   DESCRIPTION
%     Single point of access for running the toolbox test suites the
%     same way everywhere: on a developer machine, on a self-hosted
%     runner and on GitHub-hosted runners. It puts the toolbox on the
%     path without side effects, runs every suite in tests/, and writes
%     machine-readable reports that CI systems can display: JUnit XML
%     for test results and Cobertura XML for statement coverage of the
%     +gracefoReading package.
%
%     In batch mode the process must fail when tests fail, which
%     MATLAB does not do by default; 'Exit' makes the function
%     terminate the process with status 0 (all passed) or 1 (any
%     failure), so the CI job turns red as expected. Interactively the
%     default is to return the results object instead.
%
%     See docs/CI_SETUP.md for runner installation and licensing.
%
%   INPUT
%     'OutputDir' - string | char, 1x1
%                Directory for the generated reports; created if it
%                does not exist.
%                Default: "artifacts" below the toolbox root.
%
%     'Coverage' - logical, 1x1
%                Collect statement coverage of the +gracefoReading
%                package and write Cobertura XML.
%                Options: true | false. Default: true.
%
%     'Exit' - logical, 1x1
%                Terminate MATLAB with an exit status derived from the
%                test outcome. Use in -batch invocations only, since it
%                closes an interactive session.
%                Options: true | false. Default: false.
%
%     'Strict' - logical, 1x1
%                Treat uncaught warnings issued during a test as
%                failures (matlab.unittest.plugins.FailOnWarningsPlugin
%                is not used; instead the summary reports them).
%                Options: true | false. Default: false.
%
%   OUTPUT
%     results - matlab.unittest.TestResult, [1 x T]
%                Result of every test executed. When 'Exit' is true the
%                function does not return.
%
%   ACCURACY AND LIMITATIONS
%     - Coverage is statement coverage of the package folder only;
%       tests/, examples/ and ci/ are deliberately excluded, and
%       statement coverage says nothing about whether the assertions
%       are meaningful.
%     - Coverage is requested first as package coverage and, if the
%       release rejects that, as folder coverage; if both fail the
%       suites still run and only a coverage warning is issued, so a
%       coverage problem can never hide a test result.
%     - Cobertura output requires R2017b or later; on older releases
%       coverage is skipped with a warning and the tests still run.
%     - The function adds the toolbox root to the path and restores the
%       previous path on cleanup, so it can be called repeatedly in one
%       session, but it does not isolate other path changes made by the
%       tests themselves.
%     - Documentation consistency beyond MATLAB (the Python help audit
%       and the docs-in-sync check) runs as a separate CI job; runCI
%       covers what MATLAB can verify.
%
%   EXAMPLES
%     % 1. local run, same reports as CI produces
%     results = runCI();
%     disp(table(results));
%
%     % 2. exactly what the CI job executes
%     %   matlab -batch "addpath('ci'); runCI('Exit', true)"
%
%     % 3. quick run without coverage instrumentation
%     results = runCI('Coverage', false);
%
%   See also runtests, matlab.unittest.TestRunner, buildfile
%
%   Toolbox:  gracefoReading v2.3.0
%   Created:  2026-08-14
%   Updated:  2026-08-14
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14

arguments
    options.OutputDir (1,1) string = ""
    options.Coverage (1,1) logical = true
    options.Exit (1,1) logical = false
    options.Strict (1,1) logical = false
end

import matlab.unittest.TestRunner
import matlab.unittest.TestSuite
import matlab.unittest.plugins.XMLPlugin
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoberturaFormat

ciDir = fileparts(mfilename('fullpath'));
root  = fileparts(ciDir);
if options.OutputDir == ""
    outDir = fullfile(root, 'artifacts');
else
    outDir = char(options.OutputDir);
end
if ~isfolder(outDir), mkdir(outDir); end

% put the toolbox on the path without leaving traces
oldPath = path();
cleanupPath = onCleanup(@() path(oldPath));
addpath(root);

fprintf('gracefoReading CI\n');
fprintf('  toolbox root : %s\n', root);
fprintf('  version      : %s\n', gracefoReading.version());
fprintf('  MATLAB       : %s (%s)\n', version('-release'), computer);
fprintf('  output dir   : %s\n', outDir);

suite = TestSuite.fromFolder(fullfile(root, 'tests'));
runner = TestRunner.withTextOutput('OutputDetail', 'Concise');
runner.addPlugin(XMLPlugin.producingJUnitFormat( ...
    fullfile(outDir, 'testresults.xml')));

if options.Coverage
    covFile = fullfile(outDir, 'coverage.xml');
    added = false;
    % Package coverage is the correct instrument for a +namespace folder;
    % forFolder is kept as a fallback for releases that reject a package
    % path, and both are optional so a coverage problem never hides a
    % test result.
    try
        runner.addPlugin(CodeCoveragePlugin.forPackage('gracefoReading', ...
            'IncludingSubpackages', true, ...
            'Producing', CoberturaFormat(covFile)));
        added = true;
    catch
        try
            runner.addPlugin(CodeCoveragePlugin.forFolder( ...
                fullfile(root, '+gracefoReading'), ...
                'IncludingSubfolders', true, ...
                'Producing', CoberturaFormat(covFile)));
            added = true;
        catch err
            warning('gracefoReading:runCI:coverageUnavailable', ...
                'Coverage instrumentation unavailable (%s); running without it.', ...
                err.identifier);
        end
    end
    if added
        fprintf('  coverage     : %s\n', covFile);
    end
end

results = runner.run(suite);

summary = table(results);
disp(summary);
nFail = nnz([results.Failed]);
nInc  = nnz([results.Incomplete]);
fprintf('CI summary: %d passed, %d failed, %d incomplete, %.1f s total\n', ...
    nnz([results.Passed]), nFail, nInc, sum([results.Duration]));

failed = nFail > 0 || (options.Strict && nInc > 0);
if options.Exit
    exit(double(failed));   %#ok<EXIT> intentional: CI batch mode
end
if failed && nargout == 0
    error('gracefoReading:runCI:testsFailed', ...
        '%d test(s) failed, %d incomplete. See %s.', nFail, nInc, ...
        fullfile(outDir, 'testresults.xml'));
end
end
