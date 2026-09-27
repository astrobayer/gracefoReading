function setupGraceFOReading()
%SETUPGRACEFOREADING  Add the gracefoReading toolbox to the MATLAB path.
%
%   SYNTAX
%     setupGraceFOReading
%     run(fullfile(toolboxRoot, 'setupGraceFOReading.m'))
%
%   DESCRIPTION
%     Run once per session, or place the equivalent addpath call in
%     your startup.m for a permanent installation. Adds the toolbox
%     root folder, which contains the +gracefoReading namespace
%     package, to the MATLAB path and registers the HTML documentation
%     with the doc browser where that is supported. Nothing is copied
%     or installed elsewhere, so removing the folder removes the
%     toolbox.
%
%     The tests/ folder is intentionally NOT added to the path, so that
%     test fixture names can never shadow toolbox or user functions;
%     run the suites by folder instead:
%       results = runtests(fullfile(toolboxRoot, 'tests'));
%
%   INPUT
%     (none)
%
%   OUTPUT
%     (none) - the MATLAB path is modified as a side effect and a short
%              confirmation is printed
%
%   ACCURACY AND LIMITATIONS
%     - The path change lasts for the session only; use savepath or
%       startup.m to make it permanent.
%     - Documentation registration calls builddocsearchdb, which is
%       unavailable in some deployments and may warn on read-only
%       installations. The failure is caught and non-fatal: the HTML
%       pages remain usable directly from html/.
%     - MATLAB R2020b or later is required, because the toolbox uses
%       arguments blocks; older releases receive a warning here and
%       will fail later at parse time.
%     - Adding the toolbox root exposes the package folder, not the
%       functions themselves; every call therefore keeps the
%       gracefoReading. prefix, which is deliberate.
%
%   EXAMPLE
%     % from the toolbox root
%     setupGraceFOReading
%     [t, obs, aux] = gracefoReading.readL1b('ACT1B_2020-01-01_C_04.txt');
%
%   See also gracefoReading.readL1b, gracefoReading.version, runCI
%
%   Toolbox:  gracefoReading v1.2.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

here = fileparts(mfilename('fullpath'));
addpath(here);

if verLessThan('matlab', '9.9')  %#ok<VERLESSMATLAB>
    warning('gracefoReading:setup:oldRelease', ...
        ['gracefoReading uses arguments blocks and requires MATLAB ', ...
         'R2020b or later; this release may not work.']);
end

% register documentation (best effort; not available in all setups)
try
    builddocsearchdb(fullfile(here, 'html'));
catch
    % non-fatal: doc pages remain accessible directly from html/
end

fprintf('gracefoReading v%s on path. Try:\n', gracefoReading.version());
fprintf('  [t, obs, aux] = gracefoReading.readL1b(''ACT1B_2020-01-01_C_04.txt'');\n');
fprintf('  results = runtests(fullfile(''%s'', ''tests''));\n', here);
end
