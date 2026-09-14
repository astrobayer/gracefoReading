function [time, data, info] = readGroopsInstrument(fileName, options)
%READGROOPSINSTRUMENT  Read a GROOPS ASCII instrument file.
%
%   SYNTAX
%     [time, data, info] = gracefoReading.readGroopsInstrument(fileName)
%     [time, data, info] = gracefoReading.readGroopsInstrument(fileName, ...
%         Name, Value)
%
%   DESCRIPTION
%     Reads an ASCII instrument file in the convention written by
%     gracefoReading.writeGroopsInstrument: a version line, a
%     two-integer type and dimension header, a lone record count and
%     one record per line starting with the decimal MJD. It is the
%     counterpart of the writer and serves two purposes: roundtrip
%     verification of the export, and reading GROOPS-produced series
%     back into MATLAB for comparison with Level-1B data.
%
%     The decimal-MJD time tag is recovered from the DIGITS of the
%     record line, not from the double that sscanf would return. The
%     integer and fractional parts are split at the decimal point and
%     converted with int64 arithmetic, so the epoch is exact to every
%     digit the file prints. Reading the same token through a double
%     loses the low digits: a double holds MJD 58849 to an ulp of 0.63
%     microseconds, and over 200 000 epochs of 2020-01-01 the double
%     path misplaced them by up to 314 ns while the digit path was
%     exact. That is why 'TimeFormat', "gpsns" is offered here at all -
%     it would otherwise return nine digits of which three are noise.
%
%   INPUT
%     fileName - string | char, 1x1
%                Path to a GROOPS ASCII instrument file.
%                Validation: mustBeFile. Required, positional.
%
%     'TimeFormat' - string, 1x1
%                Representation of the TIME output, matching
%                gracefoReading.readL1b so the two readers hand off to
%                the same downstream code.
%                Options: "mjd" (integer MJD + seconds of day),
%                "datetime" (GPS time scale), "gpsns" (int64 GPS
%                nanoseconds past 2000-01-01 12:00:00).
%                Default: "mjd".
%
%   OUTPUT
%     time - double, [N x 2] | datetime, [N x 1] | int64, [N x 1]
%                Epochs according to 'TimeFormat': integer MJD and
%                seconds of day (default), datetime on the GPS time
%                scale, or int64 GPS nanoseconds. The MJD column and
%                the nanosecond count are both derived by integer
%                arithmetic from the printed digits.
%     data - double, [N x M]
%                Data columns; M equals info.dataColumns.
%     info - struct, 1x1
%                  version     double, version tag from the first line
%                  typeCode    double, first integer of the header
%                  dataColumns double, declared number of data columns
%                  numRecords  double, declared number of records
%
%   ACCURACY AND LIMITATIONS
%     - Time is exact with respect to what the file prints. It is NOT
%       exact with respect to a series that went through the writer:
%       writeGroopsInstrument forms the decimal MJD as a double before
%       printing it, so a write-then-read roundtrip is limited to about
%       0.6 microseconds by the writer, not by this reader. Only a file
%       whose digits carry true sub-microsecond information delivers it.
%     - At most the first 15 fractional digits are used. The 15th digit
%       of a day is 86 picoseconds, so this cannot affect a nanosecond
%       result; digits beyond it are discarded rather than rounded.
%     - Rounding the fractional digits to whole nanoseconds can reach a
%       full day (a tag within about 43 ps of midnight). The carry into
%       the MJD column is applied, so seconds of day stays in [0, 86400).
%     - Time tags must be plain fixed-point decimals. An exponential
%       tag such as 5.8849e4 raises badTimeToken rather than being read
%       through a double, because the digit path is what makes the
%       nanosecond output meaningful. A sign is accepted only as '+':
%       MJD is positive for every real epoch, and a negative tag would
%       need floor semantics the integer split does not implement.
%     - Time tags are validated before the declared column count, so a
%       malformed tag raises badTimeToken and not countMismatch. The
%       other order names the wrong cause: a tag like "58849.5.5" makes
%       sscanf return three values where two columns were declared, and
%       the reader would report a count error for a time problem.
%     - Only the ASCII instrument format is read; GROOPS binary files
%       are not supported.
%     - Declared record and column counts are enforced, which catches
%       truncated files, but the type code is not interpreted: the
%       function does not know what the columns mean. Consult the
%       GROOPS documentation of the type code in info.
%     - Header conventions have not been verified against a specific
%       GROOPS installation (see writeGroopsInstrument limitations);
%       files from a real installation may carry additional comment
%       lines, which this reader does not expect. It is therefore NOT
%       established that this function reads the TU Graz operational
%       orbit products - see obligation O-8 in HANDOVER.md.
%
%   ERRORS
%     gracefoReading:readGroopsInstrument:badFormat
%       first line or header lines not in the expected convention
%     gracefoReading:readGroopsInstrument:countMismatch
%       declared record or column count does not match the data
%     gracefoReading:readGroopsInstrument:badTimeToken
%       a time tag is not a plain fixed-point decimal MJD
%
%   EXAMPLES
%     % 1. roundtrip check of the exporter
%     gracefoReading.writeGroopsInstrument('acc.txt', t, acc);
%     [t2, acc2, info] = gracefoReading.readGroopsInstrument('acc.txt');
%     fprintf('max |dt| = %.3g s\n', ...
%         max(abs((t2(:,1)-t(:,1))*86400 + t2(:,2)-t(:,2))));
%
%     % 2. compare a GROOPS-processed series with Level-1B data
%     [tg, dg] = gracefoReading.readGroopsInstrument('fromGroops.txt');
%     [tl, obs] = gracefoReading.readL1b('ACT1B_2020-01-01_C_04.txt');
%
%     % 3. exact int64 nanoseconds, for a lossless handoff
%     [tns, dg] = gracefoReading.readGroopsInstrument('fromGroops.txt', ...
%         'TimeFormat', 'gpsns');
%
%   See also gracefoReading.writeGroopsInstrument, gracefoReading.readL1b
%
%   Toolbox:  gracefoReading v1.0.2
%   Created:  2026-08-01
%   Updated:  2026-09-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    fileName (1,1) string {mustBeFile}
    options.TimeFormat (1,1) string ...
        {mustBeMember(options.TimeFormat, ["mjd", "datetime", "gpsns"])} = "mjd"
end

txt = fileread(fileName);
lines = splitlines(string(txt));
lines = lines(strlength(strtrim(lines)) > 0);

if numel(lines) < 3
    error('gracefoReading:readGroopsInstrument:badFormat', ...
        '%s has fewer than the 3 header lines of a GROOPS ASCII instrument file.', fileName);
end
verTok = regexp(lines(1), '^groops instrument version=(\d+)\s*$', 'tokens', 'once');
if isempty(verTok)
    error('gracefoReading:readGroopsInstrument:badFormat', ...
        'First line of %s is not "groops instrument version=<N>".', fileName);
end
hdr2 = sscanf(lines(2), '%d');
hdr3 = sscanf(lines(3), '%d');
if numel(hdr2) ~= 2 || numel(hdr3) ~= 1
    error('gracefoReading:readGroopsInstrument:badFormat', ...
        'Header lines 2/3 of %s are not "<typeCode> <dataColumns>" and "<numRecords>".', fileName);
end

info = struct('version', str2double(verTok{1}), ...
    'typeCode', hdr2(1), 'dataColumns', hdr2(2), 'numRecords', hdr3(1));

recLines = lines(4:end);
n = numel(recLines);

% Read and validate the time tags BEFORE the column count. A malformed tag
% derails sscanf's column arithmetic - "58849.5.5" yields three values where
% two were declared, "fifty" yields none - so with the count check first the
% reader blamed countMismatch for what is really a bad time tag. The specific
% diagnostic has to win, or the message names the wrong cause.
[mjd, nsOfDay] = localExactMjd(recLines, fileName);

vals = sscanf(char(join(recLines, newline)), '%f');
nCols = numel(vals) / max(n, 1);
if n ~= info.numRecords || mod(numel(vals), max(n,1)) ~= 0 || nCols ~= info.dataColumns + 1
    error('gracefoReading:readGroopsInstrument:countMismatch', ...
        ['%s: header declares %d records x %d data columns, found %d ', ...
         'record line(s) with %.10g columns.'], fileName, info.numRecords, ...
        info.dataColumns, n, nCols);
end
M = reshape(vals, nCols, n)';
data = M(:, 2:end);

% GPS seconds count from 2000-01-01 12:00, i.e. MJD 51544 + 43200 s
% (HANDOVER.md section C). Formed in int64 so "gpsns" never touches a double.
mjdEpoch = 51544;
timeNs = (int64(mjd) - int64(mjdEpoch)) * int64(86400) * int64(1e9) ...
       + nsOfDay - int64(43200) * int64(1e9);
timeMjd = [mjd, double(nsOfDay) / 1e9];

time = gracefoReading.internal.formatEpoch(timeMjd, timeNs, ...
    options.TimeFormat, mjdEpoch);
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
