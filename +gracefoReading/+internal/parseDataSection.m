function [timeMjd, timeNs, obs, aux] = parseDataSection(dataLines, dataLineNos, ...
%PARSEDATASECTION  Parse the record section shared by all L1B ASCII formats.
%
%   SYNTAX
%     [timeMjd, timeNs, obs, aux] = gracefoReading.internal.parseDataSection( ...
%         dataLines, dataLineNos, varNames, varAttrs, fileName, ...
%         timeVarOpt, numRecordsHeader, headerLines)
%
%   DESCRIPTION
%     Core engine behind gracefoReading.readL1b: tokenization,
%     prod_flag-aware row-integrity checking, column type
%     classification, time conversion and aux assembly. Used by both
%     the GRACE-FO YAML header path and the classic GRACE header path,
%     so classic support reuses every validated code path. Internal
%     function - the public interface is gracefoReading.readL1b.
%
%   INPUT
%     dataLines - string, [R x 1]
%                Non-empty data lines of the file.
%                Required, positional.
%     dataLineNos - double, [R x 1]
%                Original file line numbers, used so that error
%                messages point at the real line.
%                Required, positional.
%     varNames - cellstr, [1 x V]
%                Declared variables in file column order.
%                Required, positional.
%     varAttrs - struct, 1x1
%                Per-variable attributes; the units attribute drives
%                char-column detection and fractional time scaling.
%                Required, positional.
%     fileName - string, 1x1
%                Source path, used in messages and stored in aux.
%                Required, positional.
%     timeVarOpt - string, 1x1
%                Time-tag override, "" for automatic detection.
%                Required, positional.
%     numRecordsHeader - double, 1x1
%                Record count declared in the header, NaN if none;
%                a mismatch produces a warning, not an error.
%                Required, positional.
%     headerLines - cellstr, [H x 1]
%                Raw header, stored verbatim in aux.header.
%                Required, positional.
%
%   OUTPUT
%     timeMjd - double, [N x 2]
%                Integer MJD and seconds of day.
%     timeNs  - int64, [N x 1]
%                GPS nanoseconds past 2000-01-01 12:00:00, formed by
%                exact integer arithmetic without a double round-trip.
%     obs     - double, [N x M]
%                Observation columns.
%     aux     - struct, 1x1
%                Core metadata fields; see gracefoReading.readL1b.
%
%   ACCURACY AND LIMITATIONS
%     - timeNs is exact for integer seconds plus a fractional part
%       given in whole microseconds, which covers the L1B products; the
%       nanosecond remainder is rounded, so a hypothetical sub-
%       nanosecond time tag would be quantized.
%     - timeMjd is a double pair and therefore not bit-identical to
%       timeNs; use timeNs where exactness matters.
%     - Numeric conversion is str2double, i.e. nearest double.
%     - A column is classified as observation only if it is numeric and
%       neither a time tag, char column, bit-string flag nor an "_id"
%       identifier; products that break these naming conventions would
%       be classified wrongly.
%     - Row integrity is checked per record, which is O(R) in MATLAB
%       loops for prod_flag products; for the fixed-width majority a
%       vectorized path is used.
%
%   ERRORS
%     Raised with gracefoReading:readL1b:* identifiers so that the
%     public function's documented error contract holds regardless of
%     which internal path produced them: columnMismatch, noData,
%     noTime, timeVariableNotFound, unknownFracUnit.
%
%   EXAMPLE
%     % internal use only; called by gracefoReading.readL1b:
%     [timeMjd, timeNs, obs, aux] = gracefoReading.internal.parseDataSection( ...
%         dataLines, lineNos, varNames, varAttrs, f, "", 86400, hdr);
%
%   See also gracefoReading.readL1b, gracefoReading.internal.parseYamlProduct,
%            gracefoReading.internal.parseClassicProduct
%
%   Toolbox:  gracefoReading v2.3.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14
    varNames, varAttrs, fileName, timeVarOpt, numRecordsHeader, headerLines)
%PARSEDATASECTION  Parse the record section shared by all L1B ASCII formats.
%
%   Core engine behind gracefoReading.readL1b: tokenization, prod_flag-
%   aware row-integrity checking, column type classification, time
%   conversion (MJD/sec-of-day double pair AND exact int64 GPS
%   nanoseconds), and aux assembly. Used by both the GRACE-FO YAML
%   header path and the classic GRACE header path so that classic
%   support reuses every validated code path.
%
%   INPUT
%     dataLines        - string [R x 1], non-empty data lines
%     dataLineNos      - double [R x 1], original file line numbers
%     varNames         - cellstr [1 x V], declared variables in order
%     varAttrs         - struct, per-variable attributes (units, ...)
%     fileName         - string, for messages and aux
%     timeVarOpt       - string, 'TimeVariable' override ("" = auto)
%     numRecordsHeader - double, declared record count (NaN if none)
%     headerLines      - cellstr [H x 1], raw header (stored in aux)
%
%   OUTPUT
%     timeMjd - double [N x 2], integer MJD + seconds of day
%     timeNs  - int64 [N x 1], GPS nanoseconds past 2000-01-01 12:00:00
%               (exact integer arithmetic; no double round-trip)
%     obs     - double [N x M]
%     aux     - struct, core fields (see readL1b documentation)
%
%   Errors use the gracefoReading:readL1b:* identifiers documented in
%   gracefoReading.readL1b.
%
%   Toolbox:  gracefoReading v2.3.0
%   Created:  2026-08-01
%   Author:   Developed with Claude Sonnet 5 (Anthropic)

nVar = numel(varNames);
nRec = numel(dataLines);
if nRec == 0
    error('gracefoReading:readL1b:noData', 'No data records found in %s', fileName);
end

% ---- classify columns --------------------------------------------------
isBitStr = ~cellfun('isempty', regexpi(varNames, 'flag|qualflg', 'once'));
isCharCol = false(1, nVar);
for k = 1:nVar
    a = varAttrs.(matlab.lang.makeValidName(varNames{k}));
    isCharCol(k) = isfield(a, 'units') && strcmpi(a.units, 'char');
end
isIdCol = ~cellfun('isempty', regexpi(varNames, '_id$', 'once'));

% ---- identify time columns --------------------------------------------
[timeColIdx, timeVarUsed, fracScale] = gracefoReading.internal.resolveTime( ...
    varNames, varAttrs, timeVarOpt);

% ---- prod_flag layout --------------------------------------------------
pfIdx = find(strcmpi(varNames, 'prod_flag'), 1);
hasProdFlag = ~isempty(pfIdx);
if hasProdFlag
    nFixed = pfIdx;
else
    nFixed = nVar;
end

% ---- tokenize ----------------------------------------------------------
tokens = regexp(cellstr(dataLines), '\S+', 'match');
tokenCounts = cellfun(@numel, tokens);

% ---- row-integrity check ----------------------------------------------
if hasProdFlag
    for r = 1:nRec
        if tokenCounts(r) < nFixed
            error('gracefoReading:readL1b:columnMismatch', ...
                'Data line %d has %d token(s); at least %d fixed columns expected.', ...
                dataLineNos(r), tokenCounts(r), nFixed);
        end
        pf = tokens{r}{pfIdx};
        expected = nFixed + sum(pf == '1');
        if tokenCounts(r) ~= expected
            error('gracefoReading:readL1b:columnMismatch', ...
                ['Data line %d has %d token(s), expected %d ', ...
                 '(%d fixed + %d set prod_flag bits). File may be corrupted.'], ...
                dataLineNos(r), tokenCounts(r), expected, nFixed, sum(pf == '1'));
        end
    end
else
    badIdx = find(tokenCounts ~= nVar, 1);
    if ~isempty(badIdx)
        error('gracefoReading:readL1b:columnMismatch', ...
            ['Data line %d has %d whitespace-separated token(s), expected %d ', ...
             '(from %d declared variables). File may be truncated or corrupted.'], ...
            dataLineNos(badIdx), tokenCounts(badIdx), nVar, nVar);
    end
end

if ~isnan(numRecordsHeader) && numRecordsHeader ~= nRec
    warning('gracefoReading:readL1b:recordCountMismatch', ...
        'Header declares num_records=%d but %d data record(s) were read from %s.', ...
        numRecordsHeader, nRec, fileName);
end

% ---- assemble per-variable token columns ------------------------------
colTok = cell(1, nVar);
if hasProdFlag
    for k = 1:nVar, colTok{k} = repmat({''}, nRec, 1); end
    for r = 1:nRec
        tk = tokens{r};
        for k = 1:nFixed, colTok{k}{r} = tk{k}; end
        pf = tk{pfIdx};
        nb = numel(pf);
        pos = nFixed;
        for b = 0:nb-1                       % bit 0 = rightmost char
            if pf(nb - b) == '1'
                pos = pos + 1;
                kk = pfIdx + 1 + b;
                if kk <= nVar
                    colTok{kk}{r} = tk{pos};
                end
            end
        end
    end
else
    tokMat = vertcat(tokens{:});
    for k = 1:nVar, colTok{k} = tokMat(:, k); end
end

% ---- convert columns ---------------------------------------------------
data = nan(nRec, nVar);
isNumericCol = true(1, nVar);
for k = 1:nVar
    if isBitStr(k) || isCharCol(k)
        isNumericCol(k) = false;
        continue
    end
    present = ~cellfun('isempty', colTok{k});
    vals = nan(nRec, 1);
    vals(present) = str2double(colTok{k}(present));
    stillNaN = present & isnan(vals);
    litNaN = present & (strcmpi(colTok{k}, 'nan') | strcmpi(colTok{k}, 'nanf'));
    if any(stillNaN & ~litNaN)
        isNumericCol(k) = false;
    else
        data(:, k) = vals;
    end
end

% ---- build time: double MJD pair AND exact int64 nanoseconds ----------
mjdEpoch = 51544;
if numel(timeColIdx) == 1
    v = data(:, timeColIdx);
    ip = floor(v);
    timeNs = int64(ip) * 1000000000 + int64(round((v - ip) * 1e9));
    gpsSeconds = v;
else
    fracSec = fracScale * data(:, timeColIdx(2));
    timeNs = int64(data(:, timeColIdx(1))) * 1000000000 + int64(round(fracSec * 1e9));
    gpsSeconds = data(:, timeColIdx(1)) + fracSec;
end
totalSec = gpsSeconds + 43200;
daysFull = floor(totalSec / 86400);
secOfDay = totalSec - daysFull * 86400;
timeMjd = [mjdEpoch + daysFull, secOfDay];

% ---- classify obs vs aux ----------------------------------------------
isAux = ~isNumericCol | isBitStr | isCharCol | isIdCol;
isAux(timeColIdx) = true;
obsCols = find(~isAux);
obs = data(:, obsCols);

% ---- assemble aux ------------------------------------------------------
aux = struct();
aux.fileName = fileName;
[~, base] = fileparts(fileName);
prodTok = regexp(char(base), '^([A-Z]{3}1B)', 'tokens', 'once');
if isempty(prodTok), aux.product = ''; else, aux.product = prodTok{1}; end
aux.obsNames = varNames(obsCols);
aux.variableNames = varNames;
aux.timeVariable = timeVarUsed;
aux.timeSystem = 'GPS';
aux.epochDescription = 'Continuous seconds past 2000-01-01 12:00:00 GPS (no leap seconds)';
aux.epochMJD = mjdEpoch;
aux.numRecordsHeader = numRecordsHeader;
aux.numRecordsActual = nRec;
aux.numRecordsFlagged = 0;
aux.header = headerLines(:);

unitStruct = struct();
for k = 1:nVar
    fn = matlab.lang.makeValidName(varNames{k});
    a = varAttrs.(fn);
    if isfield(a, 'units'), unitStruct.(fn) = a.units; end
end
aux.variableUnits = unitStruct;
aux.variableAttributes = varAttrs;

for k = 1:nVar
    if ~isAux(k) || any(k == timeColIdx), continue; end
    fn = matlab.lang.makeValidName(varNames{k});
    if isBitStr(k)
        raw = char(colTok{k});
        aux.(fn) = raw;
        bitsFn = [regexprep(fn, '_', ''), 'Bits'];
        if strcmpi(fn, 'prod_flag'), bitsFn = 'prodFlagBits'; end
        if strcmpi(fn, 'qualflg'),   bitsFn = 'qualflgBits'; end
        aux.(bitsFn) = raw(:, end:-1:1) == '1';
    elseif isNumericCol(k)
        aux.(fn) = data(:, k);
    else
        col = colTok{k};
        if all(cellfun('length', col) == 1)
            aux.(fn) = char(col);
        else
            aux.(fn) = col;
        end
    end
end
end
