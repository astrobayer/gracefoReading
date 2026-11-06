function [events, aux] = readEventList(fileName, options)
%READEVENTLIST  Read an official GRACE/GRACE-FO event list (TN-01, TN-01a).
%
%   SYNTAX
%     events = gracefoReading.readEventList(fileName)
%     events = gracefoReading.readEventList(fileName, Name, Value)
%     [events, aux] = gracefoReading.readEventList(___)
%
%   DESCRIPTION
%     Reads the two official event lists the project publishes beside
%     the Level-1 data and returns one table row per event, with the
%     provenance of every row (G-05, issue #20):
%
%       TN-01  "sequence of events", machine-readable. Each line is
%              <epoch> <satellite> <key> <count> <count values>
%              <free text>, where epoch is GPS seconds past
%              2000-01-01 12:00 and a leading "x" disables the line.
%              The manoeuvres are the rows whose key is MANV.
%       TN-01a "spacecraft events", written by the operators. Entries
%              are grouped under a YYYY-MM-DD date; an entry starts at
%              the indentation of the date field and wrapped text is
%              indented deeper.
%
%     **This function reads; it does not interpret.** The values of a
%     TN-01 row are returned as the numbers the file gives, under the
%     key the file gives, and a TN-01a entry is returned as its date
%     and its text. Nothing is inferred that the list does not state -
%     turning these rows into mask layers and calibration windows is
%     the business of the preprocessing chain, which knows what it
%     wants them for. That division is why the text and the line
%     number travel with every row.
%
%   INPUT
%     fileName - string | char, 1x1
%                Path to TN-01_SOE.txt, TN-01a_SCE.txt, or a copy of
%                either. Plain or gzip-compressed.
%                Validation: mustBeFile. Required, positional.
%
%     'Format' - string, 1x1
%                Which list this is.
%                Options: "auto" | "soe" | "sce". "auto" decides from
%                the content: a file whose first data line parses as
%                the TN-01 grammar is an SOE, one led by YYYY-MM-DD
%                entries is an SCE.
%                Default: "auto".
%
%     'Satellite' - string, 1x1
%                Keep only rows whose satellite token matches, case
%                insensitively.
%                Options: any token the file uses, e.g. "GRACEC",
%                "GRACED"; "" keeps everything. Only TN-01 rows carry
%                a satellite token, so a non-empty value removes every
%                TN-01a row.
%                Default: "" (no filter).
%
%     'TimeFormat' - string, 1x1
%                Representation of the time column.
%                Options: "mjd" (an [N x 2] integer MJD and seconds of
%                day) | "datetime" ([N x 1] datetime on the GPS scale).
%                Default: "mjd".
%
%   OUTPUT
%     events - table, [N x 8]
%                One row per event, in file order; N = rows kept.
%                Variables:
%                  time       double [N x 2] or datetime [N x 1]
%                  satellite  string, "" for a TN-01a entry
%                  key        string, the TN-01 key, "" for TN-01a
%                  values     cell, the TN-01 numeric values as a row
%                             vector, {} for TN-01a
%                  text       string, the free text of the row
%                  disabled   logical, true for a TN-01 line commented
%                             out with a leading "x"
%                  dayOnly    logical, true when the file gave a DATE
%                             and no time of day, which is every
%                             TN-01a row. Such a time is the start of
%                             that day and must not be read as an
%                             instant.
%                  line       double, line number in the source file
%     aux - struct, 1x1
%                fileName, format ("soe" | "sce"), numRows, numDisabled,
%                numUnparsable, unparsableLines (double [U x 1]),
%                headerComments (string [H x 1], the leading "#" lines)
%                and timeSystem. timeSystem is "GPS" for an SOE, whose
%                epochs are GPS seconds, and "date" for an SCE, whose
%                dates carry no time scale at all.
%
%   ACCURACY AND LIMITATIONS
%     - **TN-01a is prose.** Its entries are a human log; only the date
%       and the entry text are structured, and this function returns
%       exactly those. Extracting a manoeuvre window from a sentence
%       like "performed a calibration maneuver from 06:19:26 to
%       06:21:33 (2.0 cm/sec)" is pattern-matching over free text
%       written by different operators over years, and is deliberately
%       NOT done here.
%     - Where a TN-01a entry ends and the next begins is decided by
%       indentation: a line indented as far as the date field starts an
%       entry, a deeper one continues it. That is the file's own
%       convention, stated in its header, and it is the only rule
%       available; a misaligned line would be joined to its
%       predecessor. The line number of every row is returned so a
%       caller can check.
%     - A TN-01 epoch of 0 is what the file uses for an initial default
%       rather than a real event. It converts to 2000-01-01 12:00 GPS
%       like any other zero and is NOT filtered out, because which
%       defaults matter is the caller's decision.
%     - TN-01 epochs are GPS seconds past the same epoch the L1B
%       products use, so they need no leap-second handling. TN-01a
%       dates are calendar dates as the operators wrote them; no time
%       scale is stated in the file and none is assumed here.
%     - A TN-01 line whose value count does not match its declared
%       count, or whose values are not numeric, is not guessed at: it
%       is left out and its line number is reported in
%       aux.unparsableLines.
%
%   ERRORS
%     gracefoReading:readEventList:formatNotRecognised
%       'Format' is "auto" and the content matches neither list
%     gracefoReading:readEventList:noEvents
%       the file holds no parsable event at all
%
%   WARNINGS
%     gracefoReading:readEventList:unparsableLines
%       at least one line matched neither grammar and was skipped
%
%   EXAMPLES
%     % 1. every manoeuvre of GRACE-C, as datetimes
%     ev = gracefoReading.readEventList('TN-01_SOE.txt', ...
%         'Satellite', "GRACEC", 'TimeFormat', "datetime");
%     manv = ev(ev.key == "MANV", :);
%     fprintf('%d manoeuvre(s), first %s\n', height(manv), manv.time(1));
%
%     % 2. the operators' log for one day
%     sce = gracefoReading.readEventList('TN-01a_SCE.txt');
%     onDay = sce(sce.time(:,1) == 58849, :);
%     disp(onDay.text);
%
%     % 3. what the reader could not parse
%     [~, a] = gracefoReading.readEventList('TN-01_SOE.txt');
%     fprintf('%d of %d line(s) unparsable\n', a.numUnparsable, a.numRows);
%
%   See also gracefoReading.readL1b, gracefoReading.findGaps,
%            gracefoReading.decodeQualFlags
%
%   Toolbox:  gracefoReading v1.3.1
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    fileName (1,1) string {mustBeFile}
    options.Format (1,1) string ...
        {mustBeMember(options.Format, ["auto","soe","sce"])} = "auto"
    options.Satellite (1,1) string = ""
    options.TimeFormat (1,1) string ...
        {mustBeMember(options.TimeFormat, ["mjd","datetime"])} = "mjd"
end

txt = gracefoReading.internal.readTextMaybeGz(fileName);
lines = splitlines(string(txt));

isComment = startsWith(strtrim(lines), "#");
headerComments = lines(isComment);

fmt = options.Format;
if fmt == "auto"
    fmt = localDetectFormat(lines, isComment, fileName);
end

if fmt == "soe"
    [tbl, unparsable] = localParseSoe(lines, isComment);
    timeSystem = "GPS";
else
    [tbl, unparsable] = localParseSce(lines, isComment);
    timeSystem = "date";
end

if ~isempty(unparsable)
    warning('gracefoReading:readEventList:unparsableLines', ...
        ['%d line(s) of %s matched neither the declared value count nor a ', ...
         'date entry and were skipped: line(s) %s.'], ...
        numel(unparsable), fileName, ...
        strjoin(string(unparsable(1:min(10, numel(unparsable))))', ', '));
end

if isempty(tbl)
    error('gracefoReading:readEventList:noEvents', ...
        'No parsable event found in %s (read as format "%s").', fileName, fmt);
end

if strlength(options.Satellite) > 0
    keep = strcmpi(tbl.satellite, options.Satellite);
    tbl = tbl(keep, :);
end

if options.TimeFormat == "datetime"
    % One renderer for the datetime epoch, shared with readL1b, and the
    % epoch integer comes from the same place the conversion does rather
    % than being written out again here.
    [~, ~, mjdEpoch] = gracefoReading.internal.gpsSecondsToMjd(0, 0);
    tbl.time = gracefoReading.internal.formatEpoch(tbl.time, ...
        zeros(height(tbl), 1, 'int64'), "datetime", mjdEpoch);
end
events = tbl;

aux = struct();
aux.fileName = fileName;
aux.format = fmt;
aux.numRows = height(events);
aux.numDisabled = sum(events.disabled);
aux.numUnparsable = numel(unparsable);
aux.unparsableLines = unparsable(:);
aux.headerComments = headerComments(:);
aux.timeSystem = timeSystem;
end

% ========================================================================
function fmt = localDetectFormat(lines, isComment, fileName)
% Decided from the content, never from the file name: a copy renamed by
% a fetch script must still read correctly.
body = strtrim(lines(~isComment & strlength(strtrim(lines)) > 0));
if isempty(body)
    error('gracefoReading:readEventList:formatNotRecognised', ...
        '%s holds no content outside its comment lines.', fileName);
end
nDate = sum(~cellfun('isempty', regexp(cellstr(body), '^\d{4}-\d{2}-\d{2}\s', 'once')));
nSoe = sum(~cellfun('isempty', regexp(cellstr(body), ...
    '^(x\s+)?[-\d.]+\s+\S+\s+\S+\s+\d+\s', 'once')));
if nSoe >= nDate && nSoe > 0
    fmt = "soe";
elseif nDate > 0
    fmt = "sce";
else
    error('gracefoReading:readEventList:formatNotRecognised', ...
        ['%s matches neither the TN-01 grammar (epoch satellite key count ', ...
         'values) nor the TN-01a one (YYYY-MM-DD entries). Name the list ', ...
         'with the ''Format'' option if it is one of them.'], fileName);
end
end

% ========================================================================
function [tbl, unparsable] = localParseSoe(lines, isComment)
n = numel(lines);
time = zeros(n, 2); sat = strings(n, 1); key = strings(n, 1);
vals = cell(n, 1); txt = strings(n, 1);
disabled = false(n, 1); lineNo = zeros(n, 1);
unparsable = zeros(0, 1);
m = 0;

for i = 1:n
    if isComment(i), continue; end
    s = strtrim(lines(i));
    if strlength(s) == 0, continue; end

    % a leading "x" comments the line out; the row is kept and marked
    isOff = false;
    if ~isempty(regexp(char(s), '^x\s', 'once'))
        isOff = true;
        s = strtrim(extractAfter(s, 1));
    end

    tok = split(strtrim(s));
    tok = tok(strlength(tok) > 0);
    if numel(tok) < 4
        unparsable(end+1, 1) = i; %#ok<AGROW>
        continue
    end
    epoch = str2double(tok(1));
    count = str2double(tok(4));
    if isnan(epoch) || isnan(count) || count < 0 || ...
            mod(count, 1) ~= 0 || numel(tok) < 4 + count
        unparsable(end+1, 1) = i; %#ok<AGROW>
        continue
    end
    v = str2double(tok(5:4+count))';
    if any(isnan(v)) && count > 0
        unparsable(end+1, 1) = i; %#ok<AGROW>
        continue
    end

    m = m + 1;
    intSec = floor(epoch);
    mjd = gracefoReading.internal.gpsSecondsToMjd(intSec, epoch - intSec);
    time(m, :) = mjd;
    sat(m) = upper(tok(2));
    key(m) = tok(3);
    vals{m} = v;
    txt(m) = strtrim(strjoin(tok(5+count:end), " "));
    disabled(m) = isOff;
    lineNo(m) = i;
end

tbl = localTable(time(1:m,:), sat(1:m), key(1:m), vals(1:m), txt(1:m), ...
    disabled(1:m), false(m, 1), lineNo(1:m));
end

% ========================================================================
function [tbl, unparsable] = localParseSce(lines, isComment)
% Entries are grouped under a date. A line indented as far as the date
% field starts an entry; a deeper one continues the entry before it.
n = numel(lines);
time = zeros(n, 2); txt = strings(n, 1); lineNo = zeros(n, 1);
unparsable = zeros(0, 1);
m = 0;
curMjd = [];

for i = 1:n
    if isComment(i), continue; end
    raw = lines(i);
    if strlength(strtrim(raw)) == 0, continue; end

    tokDate = regexp(char(raw), '^(\d{4})-(\d{2})-(\d{2})\s+(.*)$', ...
        'tokens', 'once');
    if ~isempty(tokDate)
        y = str2double(tokDate{1}); mo = str2double(tokDate{2});
        d = str2double(tokDate{3});
        curMjd = [localDateToMjd(y, mo, d), 0];
        m = m + 1;
        time(m, :) = curMjd;
        txt(m) = strtrim(string(tokDate{4}));
        lineNo(m) = i;
        continue
    end

    if isempty(curMjd)
        unparsable(end+1, 1) = i; %#ok<AGROW>
        continue
    end

    indent = strlength(raw) - strlength(strip(raw, 'left'));
    if indent <= 11
        m = m + 1;
        time(m, :) = curMjd;
        txt(m) = strtrim(raw);
        lineNo(m) = i;
    else
        txt(m) = strtrim(txt(m) + " " + strtrim(raw));
    end
end

sat = strings(m, 1); key = strings(m, 1);
vals = repmat({[]}, m, 1);
tbl = localTable(time(1:m,:), sat, key, vals, txt(1:m), ...
    false(m, 1), true(m, 1), lineNo(1:m));
end

% ========================================================================
function mjd = localDateToMjd(y, mo, d)
% Calendar date to integer MJD, by the standard civil-date formula.
a = floor((14 - mo) / 12);
yy = y + 4800 - a;
mm = mo + 12 * a - 3;
jdn = d + floor((153 * mm + 2) / 5) + 365 * yy + floor(yy / 4) ...
      - floor(yy / 100) + floor(yy / 400) - 32045;
mjd = jdn - 2400001;
end

% ========================================================================
function tbl = localTable(time, sat, key, vals, txt, disabled, dayOnly, lineNo)
tbl = table(time, sat, key, vals, txt, disabled, dayOnly, lineNo, ...
    'VariableNames', {'time','satellite','key','values','text', ...
                      'disabled','dayOnly','line'});
end
