function aux = filterAuxRecords(aux, keep, nRec)
%FILTERAUXRECORDS  Apply a record mask to all per-record aux fields.
%
%   SYNTAX
%     aux = gracefoReading.internal.filterAuxRecords(aux, keep, nRec)
%
%   DESCRIPTION
%     Filters every per-record field of the aux struct with the same
%     logical mask that was applied to time and obs, so that quality
%     and time-range filtering leave a self-consistent result.
%     Metadata fields are protected by an explicit list, because a
%     metadata field could accidentally have as many rows as there are
%     records and would then be filtered as if it were data. Internal
%     function - the public interface is gracefoReading.readL1b.
%
%   INPUT
%     aux - struct, 1x1
%                Aux struct as assembled by parseDataSection.
%                Required, positional.
%     keep - logical, [nRec x 1]
%                Records to retain.
%                Required, positional.
%     nRec - double, 1x1
%                Record count before filtering; only fields with
%                exactly this many rows are touched.
%                Required, positional.
%
%   OUTPUT
%     aux - struct, 1x1
%                Same struct with all per-record fields filtered.
%
%   ACCURACY AND LIMITATIONS
%     - Filtering is exact; no values are altered.
%     - The protected-field list must be extended whenever a new
%       metadata field is added to aux, otherwise that field could be
%       silently truncated. It currently covers header, obsNames,
%       variableNames, fileName, product, timeVariable, timeSystem,
%       epochDescription, epochMJD, the four record counts,
%       variableUnits, variableAttributes, headerFormat and cacheHit.
%     - numRecordsActual keeps reporting the parsed count, not the
%       count after filtering; the number removed is in
%       numRecordsFlagged.
%
%   ERRORS
%     (none)
%
%   EXAMPLE
%     % internal use only; called by gracefoReading.readL1b:
%     aux = gracefoReading.internal.filterAuxRecords(aux, keep, nRec);
%
%   See also gracefoReading.readL1b
%
%   Toolbox:  gracefoReading v1.2.0
%   Created:  2026-08-01
%   Updated:  2026-09-27
%   Author:   Matthias Weigelt with support of Anthropic Claude

protected = {'header', 'obsNames', 'variableNames', 'fileName', 'product', ...
    'timeVariable', 'timeSystem', 'epochDescription', 'epochMJD', ...
    'numRecordsHeader', 'numRecordsActual', 'numRecordsFlagged', ...
    'numRecordsZeroTime', 'variableUnits', 'variableAttributes', 'headerFormat', 'cacheHit'};
fns = fieldnames(aux);
for f = 1:numel(fns)
    if any(strcmp(fns{f}, protected)), continue; end
    v = aux.(fns{f});
    if (isnumeric(v) || islogical(v) || ischar(v) || iscell(v)) && size(v, 1) == nRec
        aux.(fns{f}) = v(keep, :);
    end
end
end
