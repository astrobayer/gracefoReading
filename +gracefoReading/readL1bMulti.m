function [time, obs, aux] = readL1bMulti(fileNames, options)
%READL1BMULTI  Read and concatenate several GRACE-FO L1B ASCII files.
%
%   SYNTAX
%     [time, obs, aux] = gracefoReading.readL1bMulti(fileNames)
%     [time, obs, aux] = gracefoReading.readL1bMulti(fileNames, Name, Value)
%
%   DESCRIPTION
%     Calls gracefoReading.readL1b on each file (e.g. consecutive daily
%     ACT1B files) and concatenates the results into one continuous
%     record. All files must expose the same observation columns
%     (aux.obsNames); a mismatch raises an error rather than silently
%     joining incompatible data. Per-file provenance is preserved in
%     aux, and the concatenated time series is checked for strict
%     monotonicity, which catches wrong file order and duplicate days.
%     All name-value options are forwarded unchanged to readL1b.
%
%   INPUT
%     fileNames - string | cellstr, [1 x K] | [K x 1]
%                Files in concatenation (typically chronological)
%                order; K = number of files. Either orientation is
%                accepted and normalised internally, so the column
%                gracefoReading.findL1bFiles returns can be passed
%                straight in.
%                Validation: mustBeNonempty. Required, positional.
%
%     'TimeVariable' - string, 1x1
%                Forwarded to readL1b (time-tag override).
%                Default: "" (automatic detection).
%
%     'TimeRange' - double, 1x2 | datetime, 1x2
%                Forwarded to readL1b; applied to every file.
%                Default: [] (no restriction).
%
%     'TimeFormat' - string, 1x1
%                Forwarded to readL1b.
%                Options: "mjd" | "datetime" | "gpsns". Default: "mjd".
%
%     'ApplyQualityFlags' - logical, 1x1
%                Forwarded to readL1b.
%                Options: true | false. Default: false.
%
%     'QualityBitMask' - double, 1xQ
%                Forwarded to readL1b (0-based bit numbers).
%                Default: [] (off).
%
%     'CacheDir' - string, 1x1
%                Forwarded to readL1b; caching is per file, so a
%                partially cached series only parses the new files.
%                Default: "" (caching disabled).
%
%     'ColumnNames' - string, 1xC
%                Forwarded to readL1b (classic-format files only).
%                Default: [] (use the built-in layout table).
%
%   OUTPUT
%     time - double, [N x 2] | datetime, [N x 1] | int64, [N x 1]
%                Concatenated epochs in the requested format;
%                N = total records kept across all files. N = 0 is a
%                valid result (see ACCURACY AND LIMITATIONS); the
%                column count is preserved, so an empty mjd result is
%                0x2 and an empty datetime/gpsns result is 0x1.
%     obs  - double, [N x M]
%                Concatenated observation columns, ordered as
%                aux.obsNames.
%     aux  - struct, 1x1
%                obsNames, variableNames, variableFieldNames,
%                variableUnits,
%                variableAttributes, timeVariable, timeSystem,
%                epochDescription, epochMJD taken from the first file;
%                fileNames [K x 1], products [K x 1], headers [K x 1],
%                recordsPerFile [K x 1] (cumsum gives the split
%                points), numRecordsHeader/Actual/Flagged [K x 1], plus
%                per-record auxiliary fields that are present with
%                consistent type in every file, concatenated in file
%                order; inconsistent fields are dropped with warning
%                fieldDropped.
%
%   ACCURACY AND LIMITATIONS
%     - Accuracy is that of readL1b; concatenation itself is exact.
%     - Records are joined in the order given, not sorted. Overlapping
%       or out-of-order files trigger the timeNotMonotonic warning but
%       are still returned, so the caller can decide how to resolve
%       the overlap.
%     - Duplicate epochs are not removed automatically.
%     - If 'TimeRange' or a quality option removes every record of
%       every file, the result is empty rather than an error: time and
%       obs are the same clean empties readL1b returns for one file,
%       aux still carries fileNames, products, recordsPerFile (all
%       zero) and the per-file record counts, and the outcome is
%       reported by the noRecordsInRange warning. The monotonicity
%       check is skipped, an empty series being trivially monotonic.
%       Callers that require data should test isempty(time) or promote
%       the warning with
%       warning('error', 'gracefoReading:readL1bMulti:noRecordsInRange').
%     - Memory grows linearly with the number of files; a full year of
%       1 Hz ACT1B is roughly 3e7 records. For long series, read in
%       blocks or use 'CacheDir' with per-day processing.
%
%   ERRORS
%     gracefoReading:readL1bMulti:inconsistentVariables
%       observation columns differ between files
%
%   WARNINGS
%     gracefoReading:readL1bMulti:fieldDropped      aux field not concatenable
%     gracefoReading:readL1bMulti:timeNotMonotonic  time not strictly
%                                                   increasing across files
%     gracefoReading:readL1bMulti:noRecordsInRange  filters removed every
%                                                   record of every file
%
%   EXAMPLES
%     % 1. five consecutive days
%     files = compose("ACT1B_2020-01-%02d_C_04.txt", 1:5);
%     [t, acc, aux] = gracefoReading.readL1bMulti(files);
%     disp(aux.recordsPerFile');
%
%     % 2. a month located by findL1bFiles, cached and flag-filtered
%     files = gracefoReading.findL1bFiles(archive, "ACT1B", ...
%         'DateRange', [datetime(2020,1,1) datetime(2020,1,31)], ...
%         'Satellite', "C");
%     [t, acc] = gracefoReading.readL1bMulti(files, ...
%         'ApplyQualityFlags', true, 'CacheDir', 'l1bcache');
%
%     % 3. a range the files do not cover: empty, not an error
%     tr = [datetime(2019,12,31,0,0,0), datetime(2019,12,31,1,0,0)];
%     [t, acc, aux] = gracefoReading.readL1bMulti(files, 'TimeRange', tr);
%     if isempty(t)
%         fprintf('%d file(s) read, no record in range\n', numel(aux.fileNames));
%     end
%
%   See also gracefoReading.readL1b, gracefoReading.findL1bFiles,
%            gracefoReading.findGaps
%
%   Toolbox:  gracefoReading v1.0.2
%   Created:  2026-08-01
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    % Deliberately unsized: findL1bFiles returns a [K x 1] column, and the
    % former (1,:) declaration rejected exactly the two-line workflow both
    % help blocks print (O-11, issue #16). Normalised to a row below, as
    % readItsgProductMulti already does.
    fileNames string {mustBeNonempty}
    options.TimeVariable (1,1) string = ""
    options.TimeRange = []
    options.TimeFormat (1,1) string {mustBeMember(options.TimeFormat, ["mjd","datetime","gpsns"])} = "mjd"
    options.ApplyQualityFlags (1,1) logical = false
    options.QualityBitMask (1,:) double {mustBeInteger, mustBeNonnegative} = []
    options.CacheDir (1,1) string = ""
    options.ColumnNames (1,:) string = string.empty
end

fileNames = fileNames(:)';
nFiles = numel(fileNames);
timeAll = cell(nFiles, 1); obsAll = cell(nFiles, 1); auxAll = cell(nFiles, 1);
optArgs = {'TimeVariable', options.TimeVariable, 'TimeRange', options.TimeRange, ...
           'TimeFormat', options.TimeFormat, 'ApplyQualityFlags', options.ApplyQualityFlags, ...
           'QualityBitMask', options.QualityBitMask, 'CacheDir', options.CacheDir, ...
           'ColumnNames', options.ColumnNames};

for i = 1:nFiles
    [timeAll{i}, obsAll{i}, auxAll{i}] = gracefoReading.readL1b(fileNames(i), optArgs{:});
end

refObsNames = auxAll{1}.obsNames;
for i = 2:nFiles
    if ~isequal(auxAll{i}.obsNames, refObsNames)
        error('gracefoReading:readL1bMulti:inconsistentVariables', ...
            ['File "%s" has observation columns {%s} differing from file "%s" {%s}. ', ...
             'All files must expose the same variables.'], ...
            fileNames(i), strjoin(auxAll{i}.obsNames, ', '), ...
            fileNames(1), strjoin(refObsNames, ', '));
    end
end

time = vertcat(timeAll{:});
obs  = vertcat(obsAll{:});

% Cross-file monotonicity: catches wrong file order or duplicate days.
% All three branches below index the first epoch, so the check must never
% run on an empty concatenation. readL1b returns clean empties when
% 'TimeRange' or a quality option removes every record, so readL1bMulti can
% legitimately be handed nFiles such results; it then raised a bare
% MATLAB:badsubscript from inside the reader (issue #6). An empty series is
% trivially monotonic, so the check is skipped and the same clean empties
% readL1b produces are returned - reported under a documented identifier,
% because silently returning nothing where a series was expected hides a
% wrong 'TimeRange' or a wrong file list.
if isempty(time)
    localWarnNoRecords(auxAll, options, time);
else
    if isdatetime(time)
        tCheck = seconds(time - time(1));
    elseif isa(time, 'int64')
        tCheck = double(time - time(1)) * 1e-9;
    else
        tCheck = (time(:,1) - time(1,1)) * 86400 + (time(:,2) - time(1,2));
    end
    iBad = find(diff(tCheck) <= 0, 1);
    if ~isempty(iBad)
        boundaries = cumsum(cellfun(@(t) size(t,1), timeAll));
        fileIdx = find(boundaries >= iBad + 1, 1);
        warning('gracefoReading:readL1bMulti:timeNotMonotonic', ...
            ['Concatenated time is not strictly increasing at record %d ', ...
             '(in file %d of %d: "%s"). Check file order and duplicates.'], ...
            iBad + 1, fileIdx, nFiles, fileNames(min(fileIdx, nFiles)));
    end
end

aux = struct();
aux.obsNames           = refObsNames;
aux.variableNames      = auxAll{1}.variableNames;
aux.variableFieldNames = auxAll{1}.variableFieldNames;
aux.variableUnits      = auxAll{1}.variableUnits;
aux.variableAttributes = auxAll{1}.variableAttributes;
aux.timeVariable       = auxAll{1}.timeVariable;
aux.timeSystem         = auxAll{1}.timeSystem;
aux.epochDescription   = auxAll{1}.epochDescription;
aux.epochMJD           = auxAll{1}.epochMJD;
aux.fileNames          = fileNames(:);
aux.products           = cellfun(@(a) a.product, auxAll, 'UniformOutput', false);
aux.headers            = cellfun(@(a) a.header, auxAll, 'UniformOutput', false);
aux.recordsPerFile     = cellfun(@(t) size(t, 1), timeAll);
aux.numRecordsHeader   = cellfun(@(a) a.numRecordsHeader, auxAll);
aux.numRecordsActual   = cellfun(@(a) a.numRecordsActual, auxAll);
aux.numRecordsFlagged  = cellfun(@(a) a.numRecordsFlagged, auxAll);

metaFields = {'obsNames','variableNames','variableFieldNames','variableUnits', ...
    'variableAttributes','header','fileName','product','timeVariable','timeSystem', ...
    'epochDescription','epochMJD','numRecordsHeader','numRecordsActual', ...
    'numRecordsFlagged','headerFormat','cacheHit','classicHeaderFields'};
candidates = setdiff(fieldnames(auxAll{1}), metaFields, 'stable');

for f = 1:numel(candidates)
    fn = candidates{f};
    consistent = true;
    refClass = class(auxAll{1}.(fn));
    for i = 2:nFiles
        if ~isfield(auxAll{i}, fn) || ~strcmp(class(auxAll{i}.(fn)), refClass)
            consistent = false; break
        end
    end
    if consistent
        vals = cellfun(@(a) a.(fn), auxAll, 'UniformOutput', false);
        try
            aux.(fn) = vertcat(vals{:});
        catch
            consistent = false;
        end
    end
    if ~consistent
        warning('gracefoReading:readL1bMulti:fieldDropped', ...
            'Auxiliary field "%s" is missing or inconsistently typed in at least one file and was not concatenated.', fn);
    end
end
end

% ========================================================================
function localWarnNoRecords(auxAll, options, time)
% Report an all-empty concatenation under a documented identifier.
% Every number in the message is read back from the run (parsed record
% counts, the options actually set, the shape and class actually returned)
% rather than restated from the call, so the text cannot drift from what
% happened. readL1b raises noData when a file holds no records at all, so
% an empty result normally means the filters removed everything; the
% no-filter wording is kept honest for any future path that could produce
% empties without one.
nParsed = sum(cellfun(@(a) a.numRecordsActual, auxAll));
active = string.empty(1, 0);
if ~isempty(options.TimeRange)
    active(end+1) = "TimeRange";
end
if options.ApplyQualityFlags
    active(end+1) = "ApplyQualityFlags";
end
if ~isempty(options.QualityBitMask)
    active(end+1) = "QualityBitMask";
end
if isempty(active)
    cause = 'no filtering option was set';
else
    cause = ['active filters: ', char(strjoin(active, ', '))];
end
warning('gracefoReading:readL1bMulti:noRecordsInRange', ...
    ['No record survived filtering: %d record(s) parsed from %d file(s), all ', ...
     'removed (%s). Returning empty time (%s, %dx%d) and obs; aux still carries ', ...
     'fileNames, products and recordsPerFile.'], ...
    nParsed, numel(auxAll), cause, class(time), size(time, 1), size(time, 2));
end
