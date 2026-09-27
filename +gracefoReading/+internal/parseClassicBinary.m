function [timeMjd, timeNs, obs, aux] = parseClassicBinary(bytes, fileName, timeVarOpt)
%PARSECLASSICBINARY  Decode a classic GRACE binary Level-1B product.
%
%   SYNTAX
%     [timeMjd, timeNs, obs, aux] = ...
%         gracefoReading.internal.parseClassicBinary(bytes, fileName, timeVarOpt)
%
%   DESCRIPTION
%     Reads the classic GRACE (2002-2017) products whose header says
%     "FILE FORMAT 0=BINARY 1=ASCII : 0": an ASCII header of
%     80-character records ending in "END OF HEADER", followed by
%     packed BIG-ENDIAN binary records.
%
%     The record layout comes from gracefoReading.internal.classicLayout,
%     which was measured on real RL02 files rather than assumed
%     (G-02, issue #17); only the column NAMES come from a document,
%     and only from one that is in hand. Two independent checks guard
%     the result before any value is returned:
%
%       1. the record length implied by the layout, times the header's
%          NUMBER OF DATA RECORDS, must equal the data section exactly;
%       2. for variable-length products the record walk must land
%          precisely on the end of the data section.
%
%     Either check failing means the layout does not describe the
%     file, and that is an error rather than a warning: a wrong
%     offset produces plausible-looking numbers, which is the one
%     failure mode a reader must never pass on silently.
%
%     Byte order is big-endian, measured. MATLAB's typecast is
%     little-endian on every supported platform, so each field's bytes
%     are reversed before casting; this is done by reshaping rather
%     than looping, so a day file decodes in one pass per column
%     group.
%
%     Internal function - the public interface is gracefoReading.readL1b.
%
%   INPUT
%     bytes - uint8, [1 x B]
%                Whole file as bytes, from readBytesMaybeGz;
%                B = file size.
%                Required, positional.
%     fileName - string | char, 1x1
%                Source path; its leading product token selects the
%                layout.
%                Required, positional.
%     timeVarOpt - string, 1x1
%                Time-tag override, "" for automatic detection.
%                Required, positional.
%
%   OUTPUT
%     timeMjd - double, [N x 2]
%                Integer MJD and seconds of day; N = records read.
%     timeNs - int64, [N x 1]
%                Exact GPS nanoseconds.
%     obs - double, [N x M]
%                Observation columns, ordered as aux.obsNames.
%     aux - struct, 1x1
%                The same fields the ASCII path returns, including
%                classicHeaderFields, qualflg / qualflgBits rendered
%                as the 8-character bit string the rest of the
%                toolbox uses, and prod_flag / prodFlagBits for the
%                variable-length products.
%
%   ACCURACY AND LIMITATIONS
%     - Only the products classicLayout carries are read; any other
%       classic binary product raises unsupportedClassicProduct rather
%       than being decoded on a guess.
%     - Values are returned exactly as stored. The single-precision
%       columns of some products are widened to double without change,
%       so they carry about seven significant digits however they are
%       printed.
%     - A record whose conditional columns are absent returns NaN for
%       them, as the GRACE-FO products do.
%     - The conditional columns of a prod_flag product need NOT share
%       one type, and the flag need not be one byte. MAS1B's flag is a
%       byte addressing eight doubles; AHK1B's is four bytes
%       addressing twenty-nine columns across five types. Both widths
%       and every type come from classicLayout, never from the first
%       column seen.
%     - The header's FILESIZE field is not used as a check: it is the
%       size the producer intended, and a truncated download would
%       still declare the original. The record-count check above is
%       the one that catches truncation.
%
%   ERRORS
%     gracefoReading:readL1b:unsupportedClassicProduct
%       no measured layout for this product
%     gracefoReading:readL1b:classicRecordMismatch
%       record length or record walk disagrees with the file
%     gracefoReading:readL1b:classicUndefinedProdFlagBit
%       a record sets a prod_flag bit the layout does not define, so
%       the field is present but its width is unknown
%     gracefoReading:readL1b:noData
%       header declares no data records
%
%   EXAMPLE
%     % internal use only; reached via gracefoReading.readL1b:
%     b = gracefoReading.internal.readBytesMaybeGz('SCA1B_2008-01-01_A_02.dat');
%     [t, ns, obs, aux] = gracefoReading.internal.parseClassicBinary( ...
%         b, 'SCA1B_2008-01-01_A_02.dat', "");
%
%   See also gracefoReading.readL1b,
%            gracefoReading.internal.classicLayout,
%            gracefoReading.internal.readBytesMaybeGz
%
%   Toolbox:  gracefoReading v1.2.0
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    bytes (1,:) uint8
    fileName (1,1) string
    timeVarOpt (1,1) string
end

% ---- split header from data -------------------------------------------
hdrChars = char(bytes);
marker = strfind(hdrChars, 'END OF HEADER');
if isempty(marker)
    error('gracefoReading:readL1b:badHeader', ...
        'No "END OF HEADER" marker found in %s.', fileName);
end
nl = find(bytes(marker(1):end) == uint8(10), 1);
dataStart = marker(1) + nl;                       % first byte after the newline
headerLines = cellstr(splitlines(string(hdrChars(1:marker(1)+nl-1))));
headerLines = headerLines(~cellfun('isempty', headerLines));
hdrFields = gracefoReading.internal.parseClassicHeader(headerLines);

numRecordsHeader = NaN;
if isfield(hdrFields, 'numberOfDataRecords')
    numRecordsHeader = str2double(hdrFields.numberOfDataRecords);
end
if isnan(numRecordsHeader) || numRecordsHeader <= 0
    error('gracefoReading:readL1b:noData', ...
        'Classic header of %s declares no data records.', fileName);
end

[~, base] = fileparts(fileName);
prodTok = regexp(char(base), '^([A-Z]{3}1B)', 'tokens', 'once');
product = '';
if ~isempty(prodTok), product = prodTok{1}; end

layout = gracefoReading.internal.classicLayout(product);
if isempty(fieldnames(layout))
    error('gracefoReading:readL1b:unsupportedClassicProduct', ...
        ['No measured binary layout for classic product "%s". Measured and ', ...
         'supported: ACC1B, SCA1B, GNV1B, KBR1B, THR1B, MAS1B, MAG1B, ', ...
         'AHK1B. Any other classic binary product is refused rather than ', ...
         'decoded on a guess - see gracefoReading.internal.classicLayout ', ...
         'for what each supported layout was measured against.'], product);
end

data = bytes(dataStart:end);
nRec = numRecordsHeader;

% ---- decode ------------------------------------------------------------
if layout.recordBytes > 0
    values = localDecodeFixed(data, layout, nRec, fileName);
else
    values = localDecodeVariable(data, layout, nRec, fileName);
end

% ---- assemble ----------------------------------------------------------
[timeMjd, timeNs, obs, aux] = localAssemble(values, layout, hdrFields, ...
    headerLines, fileName, product, numRecordsHeader, timeVarOpt);
end

% ========================================================================
function values = localDecodeFixed(data, layout, nRec, fileName)
% One pass per column group over a [recordBytes x nRec] view.
R = layout.recordBytes;
if numel(data) ~= R * nRec
    error('gracefoReading:readL1b:classicRecordMismatch', ...
        ['%s has %d data byte(s) for %d declared record(s), which is %.4f ', ...
         'bytes per record; the measured layout needs exactly %d. The file ', ...
         'is truncated, or this is not the release the layout was measured ', ...
         'on.'], fileName, numel(data), nRec, numel(data)/nRec, R);
end
recs = reshape(data, R, nRec);

values = cell(1, numel(layout.names));
off = 0;
k = 1;
while k <= numel(layout.names)
    t = layout.types{k};
    w = localWidth(t);
    % group the run of identically typed columns that follows
    kEnd = k;
    while kEnd < numel(layout.names) && strcmp(layout.types{kEnd+1}, t)
        kEnd = kEnd + 1;
    end
    nCol = kEnd - k + 1;
    block = recs(off+1:off+w*nCol, :);
    values(k:kEnd) = localCastBlock(block, t, w, nCol, nRec);
    off = off + w * nCol;
    k = kEnd + 1;
end
end

% ========================================================================
function cols = localCastBlock(block, t, w, nCol, nRec)
% block is [w*nCol x nRec]; return nCol column vectors of length nRec.
if strcmp(t, 'char')
    cols = cell(1, nCol);
    for c = 1:nCol
        cols{c} = char(block(c, :))';
    end
    return
end
if strcmp(t, 'uint8')
    cols = cell(1, nCol);
    for c = 1:nCol
        cols{c} = double(block(c, :))';
    end
    return
end
% Big-endian: reverse each field's bytes, then cast. Reshaping to
% [w x nCol*nRec] puts one field in each column, in record-major order.
flat = reshape(block, w, nCol * nRec);
flat = flipud(flat);
v = typecast(flat(:), t);
v = reshape(double(v), nCol, nRec)';
cols = num2cell(v, 1);
end

% ========================================================================
function values = localDecodeVariable(data, layout, nRec, fileName)
% prod_flag products: the fixed head, then one value per set bit.
%
% Neither the flag's width nor the conditional columns' type may be
% assumed. MAS1B's prod_flag is one byte addressing eight columns that
% are all double; AHK1B's is FOUR bytes addressing twenty-nine columns
% of five different types. Both come from layout.
pf = layout.prodFlagIdx;
nNames = numel(layout.names);
headW = 0;
for k = 1:pf
    headW = headW + localWidth(layout.types{k});
end
nBits = layout.prodFlagBits;

values = cell(1, nNames);
for k = 1:pf
    values{k} = zeros(nRec, 1);
end
for k = pf+1:nNames
    values{k} = nan(nRec, 1);
end
charCols = find(strcmp(layout.types(1:pf), 'char'));
for c = charCols
    values{c} = repmat(' ', nRec, 1);
end

off = 0;
for r = 1:nRec
    if off + headW > numel(data)
        error('gracefoReading:readL1b:classicRecordMismatch', ...
            ['%s ended inside record %d of %d declared: the data section ', ...
             'is shorter than the record walk needs.'], fileName, r, nRec);
    end
    o = off;
    for k = 1:pf
        t = layout.types{k};
        w = localWidth(t);
        raw = data(o+1:o+w);
        switch t
            case 'char',  values{k}(r) = char(raw);
            case 'uint8', values{k}(r) = double(raw);
            otherwise
                values{k}(r) = double(typecast(fliplr(raw), t));
        end
        o = o + w;
    end
    flagWord = values{pf}(r);
    setBits = find(bitget(uint32(flagWord), 1:nBits));  % bit 0 is bit 1 here
    for b = 1:numel(setBits)
        col = pf + setBits(b);                          % bit i -> column pf+i
        if col > nNames
            error('gracefoReading:readL1b:classicUndefinedProdFlagBit', ...
                ['%s: record %d sets prod_flag bit %d, which %s does not ', ...
                 'define. The field is present in the record but its width ', ...
                 'is unknown, so every byte after it would be misread. This ', ...
                 'is refused rather than guessed at.'], ...
                fileName, r, setBits(b) - 1, layout.names{pf});
        end
        t = layout.types{col};
        w = localWidth(t);
        if o + w > numel(data)
            error('gracefoReading:readL1b:classicRecordMismatch', ...
                ['%s: record %d needs %d more byte(s) for column "%s" but ', ...
                 'the data section has only %d left.'], ...
                fileName, r, w, layout.names{col}, numel(data) - o);
        end
        raw = data(o+1:o+w);
        switch t
            case 'uint8', values{col}(r) = double(raw);
            otherwise,    values{col}(r) = double(typecast(fliplr(raw), t));
        end
        o = o + w;
    end
    off = o;
end

if off ~= numel(data)
    error('gracefoReading:readL1b:classicRecordMismatch', ...
        ['%s: the record walk consumed %d of %d data byte(s) over %d ', ...
         'record(s). The layout does not describe this file.'], ...
        fileName, off, numel(data), nRec);
end
end

% ========================================================================
function [timeMjd, timeNs, obs, aux] = localAssemble(values, layout, ...
    hdrFields, headerLines, fileName, product, numRecordsHeader, timeVarOpt)
names = layout.names;
nVar = numel(names);
fieldNames = gracefoReading.internal.variableFieldNames(names);

% bit-string columns: the file stores a BYTE, the toolbox speaks the
% 8-character string, so decodeQualFlags works on classic and GRACE-FO
% alike (V-8: classic qualflg is a bitmask byte, measured 2026-09-22).
isFlag = ~cellfun('isempty', regexpi(names, 'flag|qualflg', 'once'));
isChar = strcmp(layout.types, 'char');
isId   = ~cellfun('isempty', regexpi(names, '_id$', 'once'));

% time columns
% AHK1B shares the ACC1A record and therefore calls its split tag
% rcvtime_intg/rcvtime_frac where THR1B and MAS1B call it time_intg/
% time_frac. Same meaning, same microsecond fraction, different name.
iIntg = find(strcmpi(names, 'time_intg'), 1);
iFrac = find(strcmpi(names, 'time_frac'), 1);
if isempty(iIntg) || isempty(iFrac)
    iIntg = find(strcmpi(names, 'rcvtime_intg'), 1);
    iFrac = find(strcmpi(names, 'rcvtime_frac'), 1);
end
iGps  = find(strcmpi(names, 'gps_time'), 1);
if strlength(timeVarOpt) > 0
    parts = strtrim(split(timeVarOpt, '+'));
    idx = zeros(1, numel(parts));
    for p = 1:numel(parts)
        q = find(strcmpi(names, parts(p)), 1);
        if isempty(q)
            error('gracefoReading:readL1b:timeVariableNotFound', ...
                'TimeVariable "%s" not found among classic columns: %s', ...
                timeVarOpt, strjoin(names, ', '));
        end
        idx(p) = q;
    end
    if numel(idx) == 2
        iIntg = idx(1); iFrac = idx(2); iGps = [];
    else
        iGps = idx(1); iIntg = []; iFrac = [];
    end
end

if ~isempty(iIntg) && ~isempty(iFrac)
    % classic split tags are documented in microseconds and measured so
    [timeMjd, timeNs, mjdEpoch] = gracefoReading.internal.gpsSecondsToMjd( ...
        values{iIntg}, values{iFrac} * 1e-6);
    timeVarUsed = sprintf('%s+%s', names{iIntg}, names{iFrac});
    timeCols = [iIntg, iFrac];
elseif ~isempty(iGps)
    [timeMjd, timeNs, mjdEpoch] = gracefoReading.internal.gpsSecondsToMjd( ...
        values{iGps}, zeros(numel(values{iGps}), 1));
    timeVarUsed = names{iGps};
    timeCols = iGps;
else
    error('gracefoReading:readL1b:noTime', ...
        'Could not identify a time tag column among: %s', strjoin(names, ', '));
end

isAux = isChar | isFlag | isId;
isAux(timeCols) = true;
obsCols = find(~isAux);
obs = zeros(numel(timeMjd(:,1)), numel(obsCols));
for c = 1:numel(obsCols)
    obs(:, c) = values{obsCols(c)};
end

aux = struct();
aux.fileName = fileName;
aux.product = product;
aux.obsNames = names(obsCols);
aux.variableNames = names;
aux.variableFieldNames = fieldNames;
aux.timeVariable = timeVarUsed;
aux.timeSystem = 'GPS';
aux.epochDescription = ...
    'Continuous seconds past 2000-01-01 12:00:00 GPS (no leap seconds)';
aux.epochMJD = mjdEpoch;
aux.numRecordsHeader = numRecordsHeader;
aux.numRecordsActual = size(timeMjd, 1);
aux.numRecordsFlagged = 0;
aux.header = headerLines(:);
aux.classicHeaderFields = hdrFields;

units = struct();
for k = 1:nVar
    if isChar(k), units.(fieldNames{k}) = 'char'; end
end
aux.variableUnits = units;
attrs = struct();
for k = 1:nVar
    a = struct();
    if isChar(k), a.units = 'char'; end
    if any(strcmpi(names{k}, {'time_frac', 'rcvtime_frac'}))
        a.units = 'microseconds';
    end
    attrs.(fieldNames{k}) = a;
end
aux.variableAttributes = attrs;

for k = 1:nVar
    if ~isAux(k) || any(k == timeCols), continue; end
    fn = fieldNames{k};
    if isFlag(k)
        raw = localBitString(values{k}, 8 * localWidth(layout.types{k}));
        aux.(fn) = raw;
        bitsFn = [regexprep(fn, '_', ''), 'Bits'];
        if strcmpi(fn, 'prod_flag'), bitsFn = 'prodFlagBits'; end
        if strcmpi(fn, 'qualflg'),   bitsFn = 'qualflgBits';  end
        aux.(bitsFn) = raw(:, end:-1:1) == '1';
    elseif isChar(k)
        aux.(fn) = values{k};
    else
        aux.(fn) = values{k};
    end
end
end

% ========================================================================
function s = localBitString(v, nBits)
% A flag field rendered as a bit string, bit 0 rightmost - the
% representation every other part of this toolbox already speaks. The
% WIDTH comes from the field: classic qualflg is one byte and gives
% eight characters, AHK1B's prod_flag is four bytes and gives
% thirty-two, which is what the GRACE-FO product declares as well.
s = dec2bin(uint32(v), nBits);
end

% ========================================================================
function w = localWidth(t)
switch t
    case {'char', 'uint8'},          w = 1;
    case {'int16','uint16'},         w = 2;
    case {'int32','uint32','single'},w = 4;
    case 'double',                   w = 8;
    otherwise
        error('gracefoReading:readL1b:badClassicType', ...
            'Unknown classic field type "%s".', t);
end
end
