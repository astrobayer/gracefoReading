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
%     fileNames - string | cellstr, 1xK
%                Files in concatenation (typically chronological)
%                order; K = number of files.
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
%                N = total records kept across all files.
%     obs  - double, [N x M]
%                Concatenated observation columns, ordered as
%                aux.obsNames.
%     aux  - struct, 1x1
%                obsNames, variableNames, variableUnits,
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
%   See also gracefoReading.readL1b, gracefoReading.findL1bFiles,
%            gracefoReading.findGaps
%
%   Toolbox:  gracefoReading v2.3.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14

arguments
    fileNames (1,:) string {mustBeNonempty}
    options.TimeVariable (1,1) string = ""
    options.TimeRange = []
    options.TimeFormat (1,1) string {mustBeMember(options.TimeFormat, ["mjd","datetime","gpsns"])} = "mjd"
    options.ApplyQualityFlags (1,1) logical = false
    options.QualityBitMask (1,:) double {mustBeInteger, mustBeNonnegative} = []
    options.CacheDir (1,1) string = ""
    options.ColumnNames (1,:) string = string.empty
end

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

% cross-file monotonicity: catches wrong file order or duplicate days
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

aux = struct();
aux.obsNames           = refObsNames;
aux.variableNames      = auxAll{1}.variableNames;
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

metaFields = {'obsNames','variableNames','variableUnits','variableAttributes', ...
    'header','fileName','product','timeVariable','timeSystem','epochDescription', ...
    'epochMJD','numRecordsHeader','numRecordsActual','numRecordsFlagged', ...
    'headerFormat','cacheHit','classicHeaderFields'};
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
