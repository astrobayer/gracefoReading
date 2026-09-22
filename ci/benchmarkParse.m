function result = benchmarkParse(options)
%BENCHMARKPARSE  Measure readL1b parse time on one real L1B day file.
%
%   SYNTAX
%     result = benchmarkParse()
%     result = benchmarkParse(Name, Value)
%
%   DESCRIPTION
%     Measures how long gracefoReading.readL1b takes on one real
%     Level-1B day file and extrapolates the figure to a year, so that
%     the decision O-7 carries - whether the line-wise regexp
%     tokenisation should gain a typed textscan fast path for the
%     fixed-layout products - is taken from a number instead of from
%     an impression (G-03, issue #18).
%
%     Two times are taken, not one. The total is what a caller waits
%     for; fileread alone is the floor that no parser can go below on
%     the same machine. Their ratio is the part of the answer a single
%     total cannot give: a fast path can only ever win back the
%     difference, so a run where reading the bytes already dominates
%     settles O-7 in the negative on its own.
%
%     The file is looked up through testRealData.resolveFixture, the
%     one authority for where a fixture lives in the data pool, so
%     this script and the acceptance suite can never look in different
%     places. The tests folder is added to the path for the lookup and
%     removed again, because setupGraceFOReading deliberately keeps it
%     off.
%
%     Nothing is asserted and nothing fails: with no pool, or no
%     ACT1B day in it, the function says so and returns an empty
%     result. It is a measurement, not an acceptance point, and a CI
%     step running it must not be able to turn a run red.
%
%   INPUT
%     'File' - string, 1x1
%                Measure this file instead of looking one up.
%                Options: any file gracefoReading.readL1b can read.
%                Default: "" (resolve 'Product' from the data pool).
%
%     'Product' - string, 1x1
%                Bare file name to resolve in the pool.
%                Options: any real day file, e.g. a different product
%                or date.
%                Default: "ACT1B_2020-01-01_C_04.txt" - 86 400 records
%                at 1 Hz, the largest routine daily parse.
%
%     'Repeats' - double, 1x1
%                Number of timed runs; the minimum is reported as the
%                machine's best and the median as what a run typically
%                costs.
%                Options: any positive integer. Default: 3.
%
%     'ExtrapolateDays' - double, 1x1
%                Days the one-day figure is scaled to.
%                Options: any positive number. Default: 365.
%
%   OUTPUT
%     result - struct, 1x1
%                Empty struct when no file was found. Otherwise:
%                file, bytes, numRecords, numObsColumns, repeats,
%                secondsMin, secondsMedian, secondsRead,
%                recordsPerSecond, megabytesPerSecond,
%                readFraction (fileread / total, from the minima),
%                extrapolatedDays and extrapolatedSeconds.
%
%   ACCURACY AND LIMITATIONS
%     - One machine, one file, one MATLAB release. The number is
%       evidence about the runner it ran on and about nothing else;
%       record it with the run id and the release beside it.
%     - The first read of a file is served from disk and later ones
%       from the operating system's cache, which is why the minimum
%       and the median are both reported: a minimum alone measures
%       the cache.
%     - Timing uses tic/toc wall clock, so a busy runner inflates it.
%       That direction is safe for the decision it feeds: it can only
%       make parsing look worse than it is.
%     - The extrapolation is linear in the number of days. It ignores
%       per-file overhead, which is small beside an 86 400-record
%       parse, and any growth in memory pressure over a long series.
%
%   EXAMPLE
%     setupGraceFOReading
%     addpath('ci');
%     r = benchmarkParse('Repeats', 5);
%     if ~isempty(fieldnames(r))
%         fprintf('%.1f s per day, %.0f s per year\n', ...
%             r.secondsMin, r.extrapolatedSeconds);
%     end
%
%   See also gracefoReading.readL1b, runCI
%
%   Toolbox:  gracefoReading v1.0.2
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    options.File (1,1) string = ""
    options.Product (1,1) string = "ACT1B_2020-01-01_C_04.txt"
    options.Repeats (1,1) double {mustBePositive, mustBeInteger} = 3
    options.ExtrapolateDays (1,1) double {mustBePositive} = 365
end

result = struct();

f = options.File;
if strlength(f) == 0
    f = localResolveFromPool(options.Product);
end
if strlength(f) == 0 || ~isfile(f)
    fprintf(['benchmarkParse: %s not found via READING_DATA_POOL; ', ...
             'no measurement taken (G-03 stays open).\n'], options.Product);
    return
end

d = dir(f);
bytes = d(1).bytes;

readSeconds = inf;
totalSeconds = zeros(1, options.Repeats);
for k = 1:options.Repeats
    tRead = tic;
    raw = fileread(f);                     %#ok<NASGU>
    readSeconds = min(readSeconds, toc(tRead));
    clear raw

    tAll = tic;
    [t, obs] = gracefoReading.readL1b(f);
    totalSeconds(k) = toc(tAll);
end

result.file               = string(f);
result.bytes              = bytes;
result.numRecords         = size(t, 1);
result.numObsColumns      = size(obs, 2);
result.repeats            = options.Repeats;
result.secondsMin         = min(totalSeconds);
result.secondsMedian      = median(totalSeconds);
result.secondsRead        = readSeconds;
result.recordsPerSecond   = result.numRecords / result.secondsMin;
result.megabytesPerSecond = (bytes / 1048576) / result.secondsMin;
result.readFraction       = readSeconds / result.secondsMin;
result.extrapolatedDays   = options.ExtrapolateDays;
result.extrapolatedSeconds = result.secondsMin * options.ExtrapolateDays;

fprintf('\n=== gracefoReading parse benchmark (G-03, O-7) ===\n');
fprintf('file          : %s\n', result.file);
fprintf('bytes         : %d (%.1f MB)\n', bytes, bytes / 1048576);
fprintf('records       : %d in %d observation column(s)\n', ...
    result.numRecords, result.numObsColumns);
fprintf('repeats       : %d\n', result.repeats);
fprintf('readL1b  min  : %.3f s\n', result.secondsMin);
fprintf('readL1b  med  : %.3f s\n', result.secondsMedian);
fprintf('fileread min  : %.3f s  (%.1f%% of the total)\n', ...
    result.secondsRead, 100 * result.readFraction);
fprintf('throughput    : %.0f records/s, %.2f MB/s\n', ...
    result.recordsPerSecond, result.megabytesPerSecond);
fprintf('%.0f day(s)    : %.1f s = %.1f min\n', result.extrapolatedDays, ...
    result.extrapolatedSeconds, result.extrapolatedSeconds / 60);
fprintf('MATLAB        : %s on %s\n', version('-release'), computer);
fprintf('==================================================\n\n');
end

% ========================================================================
function f = localResolveFromPool(name)
% One authority for the fixture layout: testRealData.resolveFixture.
% Duplicating the two candidate paths here is what would let this
% script and the acceptance suite disagree about where the pool keeps
% its day files, which is precisely what G-07 exists to prevent.
f = "";
here = fileparts(mfilename('fullpath'));
testsDir = fullfile(fileparts(here), 'tests');
if ~isfolder(testsDir)
    return
end
onPath = any(strcmp(strsplit(path, pathsep), testsDir));
if ~onPath
    addpath(testsDir);
    restore = onCleanup(@() rmpath(testsDir)); %#ok<NASGU>
end
f = testRealData.resolveFixture(char(name));
end
