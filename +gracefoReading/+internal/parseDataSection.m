function [timeMjd, timeNs, obs, aux] = parseDataSection(dataLines, dataLineNos, ...
    varNames, varAttrs, fileName, timeVarOpt, numRecordsHeader, headerLines)
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
%     which internal path produced them: badBitString, columnMismatch,
%     noData, noTime, timeVariableNotFound, unknownFracUnit.
%
%   EXAMPLE
%     % internal use only; called by gracefoReading.readL1b:
%     [timeMjd, timeNs, obs, aux] = gracefoReading.internal.parseDataSection( ...
%         dataLines, lineNos, varNames, varAttrs, f, "", 86400, hdr);
%
%   See also gracefoReading.readL1b, gracefoReading.internal.parseYamlProduct,
%            gracefoReading.internal.parseClassicProduct
%
%   Toolbox:  gracefoReading v1.2.0
%   Created:  2026-08-01
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

nVar = numel(varNames);
nRec = numel(dataLines);
if nRec == 0
    error('gracefoReading:readL1b:noData', 'No data records found in %s', fileName);
end

% ---- classify columns --------------------------------------------------
isBitStr = ~cellfun('isempty', regexpi(varNames, 'flag|qualflg', 'once'));
% One rule, one call: the field names used here are the same ones
% parseHeaderVariables keyed varAttrs with, so a name that had to be
% adjusted (AHK1B's "TSU Z-") still finds its attributes.
[fieldNames, nameAdjusted] = gracefoReading.internal.variableFieldNames(varNames);
isCharCol = false(1, nVar);
isBinText = false(1, nVar);
for k = 1:nVar
    a = varAttrs.(fieldNames{k});
    isCharCol(k) = isfield(a, 'units') && strcmpi(a.units, 'char');
    % A column the ASCII variant writes as BIT CHARACTERS but which is
    % a number: classic AHK1B's `status`. Read as decimal it would be
    % 10111111 instead of 191, silently. It is decoded back to its
    % value rather than exposed as a bit string, because it is
    % CONDITIONAL - absent in most records - and a bit string cannot
    % represent "absent" the way NaN can.
    isBinText(k) = isfield(a, 'bitStringNumeric') && a.bitStringNumeric;
end
if any(nameAdjusted)
    idx = find(nameAdjusted);
    pairs = arrayfun(@(k) sprintf('"%s" -> aux.%s', varNames{k}, fieldNames{k}), ...
        idx, 'UniformOutput', false);
    warning('gracefoReading:readL1b:variableNameAdjusted', ...
        ['%d of %d declared variable name(s) in %s are not usable as struct ', ...
         'fields verbatim and were mapped: %s. aux.variableNames and ', ...
         'aux.obsNames keep the declared names.'], ...
        numel(idx), nVar, fileName, strjoin(pairs, ', '));
end
isIdCol = ~cellfun('isempty', regexpi(varNames, '_id$', 'once'));

% ---- rest-of-line column ----------------------------------------------
% LHK1B and the other long-format housekeeping products end in a free-text
% column that the header itself describes as taking what is left of the
% line. Real LHK1B of 2020-01-01 declares:
%
%     - sensorname:
%         comment: Entire remaining portion of each record
%         long_name: Sensor name.  Max number of characters = 1,000
%
% and 2 886 of its 1 169 274 records use that licence: "fpga_state:
% science_state" and "mode: science" carry a SPACE, so the record has one
% whitespace-separated token more than the header declares columns. Until
% 2026-09-22 that raised columnMismatch on line 537 and the product could
% not be read at all (issue #19).
%
% The rule is read off the file, not assumed from the position: only a
% last column whose own comment or long_name says it takes the remaining
% portion absorbs the surplus. It cannot be inferred from "units: char"
% either - sensorname does not declare units at all.
restIdx = 0;
if ~hasProdFlagName(varNames) && nVar >= 2
    aLast = varAttrs.(fieldNames{nVar});
    claim = '';
    if isfield(aLast, 'comment'),   claim = [claim, ' ', aLast.comment];   end
    if isfield(aLast, 'long_name'), claim = [claim, ' ', aLast.long_name]; end
    if ~isempty(regexpi(claim, 'remaining\s+portion', 'once'))
        restIdx = nVar;
    end
end
hasRestOfLine = restIdx > 0;
if hasRestOfLine
    % Free text by construction: never numeric, and never a bit string
    % even if the name happened to contain "flag".
    isCharCol(restIdx) = true;
    isBitStr(restIdx) = false;
end

% ---- identify time columns --------------------------------------------
[timeColIdx, timeVarUsed, fracScale] = gracefoReading.internal.resolveTime( ...
    varNames, varAttrs, timeVarOpt, fieldNames);

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
elseif hasRestOfLine
    % Surplus tokens are the last column's text, so only a SHORTFALL is a
    % defect here. The check stays strict in that direction.
    badIdx = find(tokenCounts < nVar, 1);
    if ~isempty(badIdx)
        error('gracefoReading:readL1b:columnMismatch', ...
            ['Data line %d has %d whitespace-separated token(s); at least %d ', ...
             'expected (%d declared variables, the last of which the header ', ...
             'declares as the remaining portion of the record). File may be ', ...
             'truncated or corrupted.'], ...
            dataLineNos(badIdx), tokenCounts(badIdx), nVar, nVar);
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
elseif hasRestOfLine
    % The leading columns are ordinary tokens; the last one is the rest of
    % the raw line, sliced at the end of token nVar-1 so that its internal
    % spacing survives verbatim. vertcat cannot be used here: with a
    % variable token count the rows are not one matrix.
    for k = 1:nVar-1
        colTok{k} = cellfun(@(tk) tk{k}, tokens, 'UniformOutput', false);
    end
    tokEnds = regexp(cellstr(dataLines), '\S+', 'end');
    cut = cellfun(@(e) e(nVar-1), tokEnds);
    colTok{nVar} = cellstr(strtrim(extractAfter(string(dataLines(:)), cut(:))));
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
    if isBinText(k)
        tok = colTok{k}(present);
        bad = find(~cellfun(@(t) all(ismember(t, '01')), tok), 1);
        if ~isempty(bad)
            error('gracefoReading:readL1b:badBitString', ...
                ['Column "%s" of %s is declared as bit characters but ', ...
                 'record %d holds "%s". Refusing to guess a number from ', ...
                 'it.'], varNames{k}, fileName, bad, tok{bad});
        end
        vals(present) = cellfun(@(t) bin2dec(t), tok);
        data(:, k) = vals;
        continue
    end
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
% The epoch arithmetic itself lives in internal/gpsSecondsToMjd, shared
% with the classic binary parser. Splitting the tag into whole and
% fractional seconds is this function's job, because only here is the
% declared unit of the fractional column known.
if numel(timeColIdx) == 1
    v = data(:, timeColIdx);
    intPart = floor(v);
    fracPart = v - intPart;
else
    intPart = data(:, timeColIdx(1));
    fracPart = fracScale * data(:, timeColIdx(2));
end
[timeMjd, timeNs, mjdEpoch] = ...
    gracefoReading.internal.gpsSecondsToMjd(intPart, fracPart);

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

aux.variableFieldNames = fieldNames;
unitStruct = struct();
for k = 1:nVar
    fn = fieldNames{k};
    a = varAttrs.(fn);
    if isfield(a, 'units'), unitStruct.(fn) = a.units; end
end
aux.variableUnits = unitStruct;
aux.variableAttributes = varAttrs;

for k = 1:nVar
    if ~isAux(k) || any(k == timeColIdx), continue; end
    fn = fieldNames{k};
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

% ========================================================================
function tf = hasProdFlagName(varNames)
% A file driven by prod_flag already has a rule for its variable columns;
% the rest-of-line rule is for the products that have no prod_flag at all.
% No known product declares both, and one that did would need reading
% before it could be handled.
tf = any(strcmpi(varNames, 'prod_flag'));
end
