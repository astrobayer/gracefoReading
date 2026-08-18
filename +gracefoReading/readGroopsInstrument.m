function [time, data, info] = readGroopsInstrument(fileName)
%READGROOPSINSTRUMENT  Read a GROOPS ASCII instrument file.
%
%   SYNTAX
%     [time, data, info] = gracefoReading.readGroopsInstrument(fileName)
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
%   INPUT
%     fileName - string | char, 1x1
%                Path to a GROOPS ASCII instrument file.
%                Validation: mustBeFile. Required, positional.
%
%   OUTPUT
%     time - double, [N x 2]
%                Integer MJD and seconds of day recovered from the
%                decimal-MJD column, matching the readL1b time layout.
%     data - double, [N x M]
%                Data columns; M equals info.dataColumns.
%     info - struct, 1x1
%                  version     double, version tag from the first line
%                  typeCode    double, first integer of the header
%                  dataColumns double, declared number of data columns
%                  numRecords  double, declared number of records
%
%   ACCURACY AND LIMITATIONS
%     - The decimal-MJD time tag limits accuracy to about 1.3
%       microseconds around MJD 58849; a roundtrip through the writer
%       reproduces epochs to that level, not to the nanosecond
%       precision available from readL1b in "gpsns" format.
%     - Only the ASCII instrument format is read; GROOPS binary files
%       are not supported.
%     - Declared record and column counts are enforced, which catches
%       truncated files, but the type code is not interpreted: the
%       function does not know what the columns mean. Consult the
%       GROOPS documentation of the type code in info.
%     - Header conventions have not been verified against a specific
%       GROOPS installation (see writeGroopsInstrument limitations);
%       files from a real installation may carry additional comment
%       lines, which this reader does not expect.
%
%   ERRORS
%     gracefoReading:readGroopsInstrument:badFormat
%       first line or header lines not in the expected convention
%     gracefoReading:readGroopsInstrument:countMismatch
%       declared record or column count does not match the data
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
%   See also gracefoReading.writeGroopsInstrument, gracefoReading.readL1b
%
%   Toolbox:  gracefoReading v2.3.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14

arguments
    fileName (1,1) string {mustBeFile}
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
vals = sscanf(char(join(recLines, newline)), '%f');
nCols = numel(vals) / max(n, 1);
if n ~= info.numRecords || mod(numel(vals), max(n,1)) ~= 0 || nCols ~= info.dataColumns + 1
    error('gracefoReading:readGroopsInstrument:countMismatch', ...
        ['%s: header declares %d records x %d data columns, found %d ', ...
         'record line(s) with %.10g columns.'], fileName, info.numRecords, ...
        info.dataColumns, n, nCols);
end
M = reshape(vals, nCols, n)';

mjdDec = M(:, 1);
mjd = floor(mjdDec);
sec = (mjdDec - mjd) * 86400;
time = [mjd, sec];
data = M(:, 2:end);
end
