function [timeMjd, timeNs, data, info] = parseGroopsInstrument(fileName)
%PARSEGROOPSINSTRUMENT  Parse a GROOPS ASCII instrument file into both time forms.
%
%   SYNTAX
%     [timeMjd, timeNs, data, info] = ...
%         gracefoReading.internal.parseGroopsInstrument(fileName)
%
%   DESCRIPTION
%     The whole parse of a GROOPS ASCII instrument file, in both dialects:
%     the one gracefoReading.writeGroopsInstrument emits, and the one real
%     GROOPS installations emit, which interleaves comment lines carrying
%     the epoch type name and a column legend. Partitioning the header on
%     '#' reads both through one path.
%
%     It returns BOTH time representations because they cannot be derived
%     from one another without loss: the int64 nanosecond count is built by
%     integer arithmetic from the printed digits, and rebuilding it from the
%     double pair would reintroduce the rounding the digit path exists to
%     remove. Callers select one with internal.formatEpoch. Existing as an
%     internal function is what lets readGroopsInstrument and
%     readItsgProduct each parse a file once rather than twice.
%
%   INPUT
%     fileName - string, 1x1
%                Path to a GROOPS ASCII instrument file, plain or
%                gzip-compressed. Required, positional.
%
%   OUTPUT
%     timeMjd - double, [N x 2]
%                Integer MJD and seconds of day.
%     timeNs - int64, [N x 1]
%                Exact GPS nanoseconds past 2000-01-01 12:00:00.
%     data - double, [N x M]
%                Data columns, time excluded.
%     info - struct, 1x1
%                version, typeCode, typeName, headerCount, dataColumns,
%                numRecords, columnNames, columnUnits, timeColumnLabel,
%                comments. See readGroopsInstrument for the meaning of
%                headerCount versus dataColumns.
%
%   ACCURACY AND LIMITATIONS
%     - Exact to what the file prints, to 1 ns; see readGroopsInstrument
%       for the digit path and the 15-decimal bound.
%     - Nothing here interprets the epoch type code. A type this toolbox
%       has never seen still parses, because the columns come from the
%       file's own legend.
%
%   ERRORS
%     gracefoReading:readGroopsInstrument:badFormat
%       header lines not in either known convention
%     gracefoReading:readGroopsInstrument:countMismatch
%       declared record or column count does not match the data
%     gracefoReading:readGroopsInstrument:badTimeToken
%       a time tag is not a plain fixed-point decimal MJD
%
%   EXAMPLE
%     % internal use only; called by readGroopsInstrument:
%     [tMjd, tNs, data, info] = ...
%         gracefoReading.internal.parseGroopsInstrument(fileName);
%
%   See also gracefoReading.readGroopsInstrument, gracefoReading.readItsgProduct
%
%   Toolbox:  gracefoReading v1.3.0
%   Created:  2026-09-14
%   Updated:  2026-09-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    fileName (1,1) string {mustBeFile}
end

txt = gracefoReading.internal.readTextMaybeGz(fileName);
lines = splitlines(string(txt));
lines = lines(strlength(strtrim(lines)) > 0);

if isempty(lines)
    error('gracefoReading:readGroopsInstrument:badFormat', ...
        '%s is empty.', fileName);
end
verTok = regexp(lines(1), '^groops instrument version=(\d+)\s*$', 'tokens', 'once');
if isempty(verTok)
    error('gracefoReading:readGroopsInstrument:badFormat', ...
        'First line of %s is not "groops instrument version=<N>".', fileName);
end

% Real GROOPS output interleaves comment lines with the header: a type name,
% a column legend and a rule. The writer in this toolbox emits none of them.
% Partitioning on '#' reads both dialects through one path instead of
% branching on which produced the file.
rest = lines(2:end);
isComment = startsWith(strtrim(rest), "#");
comments = rest(isComment);
content = rest(~isComment);

if numel(content) < 2
    error('gracefoReading:readGroopsInstrument:badFormat', ...
        ['%s has %d non-comment header line(s); a GROOPS ASCII instrument file ', ...
         'needs "<typeCode> <count>" and a record count.'], fileName, numel(content));
end
hdr2 = sscanf(content(1), '%d');
hdr3 = sscanf(content(2), '%d');
if numel(hdr2) ~= 2 || numel(hdr3) ~= 1
    error('gracefoReading:readGroopsInstrument:badFormat', ...
        'Header lines of %s are not "<typeCode> <count>" and "<numRecords>".', fileName);
end

[typeName, columnNames, columnUnits, timeLabel] = localHeaderComments(comments);

% Column authority: the legend when the file carries one, otherwise the second
% header integer. They are not the same quantity - the ITSG operational
% products write 1 there against 3, 4, 6 and 9 data columns - so the legend
% wins wherever it exists and the integer is reported raw as info.headerCount.
if ~isempty(columnNames)
    expectedCols = numel(columnNames);
else
    expectedCols = hdr2(2);
end

info = struct('version', str2double(verTok{1}), ...
    'typeCode', hdr2(1), 'typeName', typeName, 'headerCount', hdr2(2), ...
    'dataColumns', expectedCols, 'numRecords', hdr3(1), ...
    'columnNames', {columnNames}, 'columnUnits', {columnUnits}, ...
    'timeColumnLabel', timeLabel, 'comments', {cellstr(comments)});

recLines = content(3:end);
n = numel(recLines);

% Read and validate the time tags BEFORE the column count. A malformed tag
% derails sscanf's column arithmetic - "58849.5.5" yields three values where
% two were declared, "fifty" yields none - so with the count check first the
% reader blamed countMismatch for what is really a bad time tag. The specific
% diagnostic has to win, or the message names the wrong cause.
[mjd, nsOfDay] = localExactMjd(recLines, fileName);

vals = sscanf(char(join(recLines, newline)), '%f');
nCols = numel(vals) / max(n, 1);
if n ~= info.numRecords || mod(numel(vals), max(n,1)) ~= 0 || nCols ~= expectedCols + 1
    error('gracefoReading:readGroopsInstrument:countMismatch', ...
        ['%s: expected %d records x %d data columns, found %d ', ...
         'record line(s) with %.10g columns.'], fileName, info.numRecords, ...
        expectedCols, n, nCols);
end
M = reshape(vals, nCols, n)';
data = M(:, 2:end);

% GPS seconds count from 2000-01-01 12:00, i.e. MJD 51544 + 43200 s
% (HANDOVER.md section C). Formed in int64 so "gpsns" never touches a double.
timeNs = (int64(mjd) - int64(51544)) * int64(86400) * int64(1e9) ...
       + nsOfDay - int64(43200) * int64(1e9);
timeMjd = [mjd, double(nsOfDay) / 1e9];
end

% ========================================================================
function [mjd, nsOfDay] = localExactMjd(recLines, fileName)
%LOCALEXACTMJD  Integer MJD and exact nanoseconds of day from the printed digits.
%   Splitting the token at the decimal point and staying in int64 keeps every
%   digit the file carries; sscanf('%f') would round the tag into a double
%   first and lose about 0.3 us around MJD 58849.
dayNs = int64(86400) * int64(1e9);

% Leading token of each record. The trailing space covers a record that has
% no data columns at all, where there is no separator to extract before.
first = extractBefore(strip(recLines) + " ", whitespacePattern);

hasDot = contains(first, ".");
ipStr = first;
fpStr = strings(size(first));
ipStr(hasDot) = extractBefore(first(hasDot), ".");
fpStr(hasDot) = extractAfter(first(hasDot), ".");

% '+' is tolerated, '-' is not: MJD is positive for every real epoch and a
% negative tag would need floor semantics this integer split does not have.
plusLead = startsWith(ipStr, "+");
ipStr(plusLead) = extractAfter(ipStr(plusLead), 1);

% digitsPattern rejects an exponent ("8849e4"), a second dot ("5.5") and any
% non-numeric text, so the refusal below covers every tag the digit path
% cannot read exactly.
valid = matches(ipStr, digitsPattern) & ...
        (strlength(fpStr) == 0 | matches(fpStr, digitsPattern));
if ~all(valid)
    k = find(~valid, 1);
    error('gracefoReading:readGroopsInstrument:badTimeToken', ...
        ['%s record %d: time tag "%s" is not a plain fixed-point decimal MJD. ', ...
         'Exponential, negative or non-numeric tags are refused rather than read ', ...
         'through a double, because the printed digits are what make the ', ...
         'nanosecond output exact.'], fileName, k, first(k));
end

% Beyond 15 digits str2double would no longer be exact, and the 15th digit of
% a day is already 86 ps - far below the nanosecond the result is quoted in.
long = strlength(fpStr) > 15;
fpStr(long) = extractBefore(fpStr(long), 16);

d = strlength(fpStr);
fracInt = int64(str2double(fpStr));
fracInt(d == 0) = 0;                       % str2double("") is NaN

% nsOfDay = frac * 86400e9 / 10^d, rearranged as frac * 864 * 10^(11-d) so the
% intermediate stays in int64: the worst case, 15 nines, reaches 8.64e17
% against an int64 ceiling of 9.22e18.
nsOfDay = zeros(numel(d), 1, 'int64');
lo = d <= 11;
nsOfDay(lo)  = fracInt(lo) .* int64(864) .* int64(10 .^ (11 - d(lo)));
nsOfDay(~lo) = idivide(fracInt(~lo) .* int64(864), int64(10 .^ (d(~lo) - 11)), 'round');

mjd = str2double(ipStr);

% A tag within ~43 ps of midnight rounds up to a whole day; carry it so
% seconds of day stays in [0, 86400) rather than reporting 86400.0.
carry = nsOfDay >= dayNs;
mjd(carry) = mjd(carry) + 1;
nsOfDay(carry) = nsOfDay(carry) - dayNs;
end

% ========================================================================
function [typeName, names, units, timeLabel] = localHeaderComments(comments)
%LOCALHEADERCOMMENTS  Type name, column names and units from the '#' lines.
%   Real GROOPS output names its epoch type on one comment line and lays out
%   the columns on another as "data0: pos x [m]   data1: ...". Both are read
%   from the file rather than keyed off a type-code table, so a product this
%   toolbox has never seen still comes back with its columns named.
typeName = '';
names = {};
units = {};
timeLabel = '';
if isempty(comments)
    return
end
bare = strtrim(erase(strtrim(comments), "#"));

legendIdx = find(contains(bare, "data0:"), 1);
if ~isempty(legendIdx)
    leg = char(bare(legendIdx));
    [mStart, mEnd] = regexp(leg, 'data\d+:', 'start', 'end');
    timeLabel = strtrim(leg(1:mStart(1)-1));
    names = cell(1, numel(mStart));
    units = cell(1, numel(mStart));
    for k = 1:numel(mStart)
        if k < numel(mStart)
            seg = leg(mEnd(k)+1 : mStart(k+1)-1);
        else
            seg = leg(mEnd(k)+1 : end);
        end
        seg = strtrim(seg);
        u = regexp(seg, '\[([^\]]*)\]\s*$', 'tokens', 'once');
        if isempty(u)
            units{k} = '';
        else
            units{k} = u{1};
            seg = strtrim(regexprep(seg, '\[[^\]]*\]\s*$', ''));
        end
        names{k} = seg;
    end
end

% The type name is the first comment that is not the legend and not a rule
% of '=' or '-' characters.
for k = 1:numel(bare)
    if k == legendIdx, continue; end
    c = char(bare(k));
    if isempty(c) || all(ismember(c, '=- ')), continue; end
    typeName = c;
    break
end
end
