function writeGroopsInstrument(fileName, time, data, options)
%WRITEGROOPSINSTRUMENT  Export time and observations as a GROOPS ASCII instrument file.
%
%   SYNTAX
%     gracefoReading.writeGroopsInstrument(fileName, time, data)
%     gracefoReading.writeGroopsInstrument(fileName, time, data, Name, Value)
%
%   DESCRIPTION
%     Writes an ASCII instrument file in the GROOPS convention
%
%         groops instrument version=<version>
%         <typeCode> <dataColumns>          (type/dimension header)
%         <numRecords>                      (record-count line)
%         <decimalMJD> <data1> <data2> ...  (one line per record)
%
%     closing the loop from PO.DAAC Level-1B files read with this
%     toolbox to GROOPS-based processing without intermediate scripts.
%     Output always uses Unix line endings (LF) on every platform, so
%     files written on Windows and Linux are byte-identical.
%
%   INPUT
%     fileName - string | char, 1x1
%                Output path; an existing file is overwritten.
%                Required, positional.
%
%     time - double, [N x 2] | datetime, [N x 1]
%                Epochs as returned by gracefoReading.readL1b: integer
%                MJD and seconds of day, or datetime on the GPS time
%                scale. Converted to the decimal MJD that GROOPS
%                expects.
%                Required, positional.
%
%     data - double, [N x M]
%                Observation columns to write; M may be zero, which
%                produces a time-only file.
%                Required, positional.
%
%     'TypeCode' - double, 1x1
%                GROOPS epoch-type code written as the first integer of
%                the type/dimension header.
%                Options: integer-valued; 0 denotes a generic
%                MISCVALUES-style record, other codes denote typed
%                records (accelerometer, star camera, ...) as defined
%                by the GROOPS release in use.
%                Default: 0.
%
%     'Version' - double, 1x1
%                Version tag written on the first line.
%                Options: integer-valued, e.g. 20200123.
%                Default: 20200123.
%
%     'Format' - string, 1x1
%                printf format applied to each data value.
%                Options: any valid floating-point conversion, e.g.
%                "%.16e" for full double precision or "%.6f" for
%                compact output.
%                Default: "%.16e".
%
%   OUTPUT
%     (none) - the file is written as a side effect
%
%   ACCURACY AND LIMITATIONS
%     - Time is written as decimal MJD in a single double, as the
%       GROOPS convention requires. Around MJD 58849 a double resolves
%       about 1.3 microseconds, which is adequate for 1 Hz Level-1B
%       products but not for sub-microsecond timing; such applications
%       must not round-trip through decimal MJD. The int64 "gpsns"
%       format of readL1b preserves the full time tag inside MATLAB.
%     - Data values are written with 'Format'; the default keeps full
%       double precision, a shorter format silently truncates.
%     - The header conventions (version tag, type codes) reflect the
%       documented GROOPS ASCII layout but have NOT been verified
%       against a file produced by a specific GROOPS installation;
%       confirm both before relying on this export in production (see
%       HANDOVER.md, open topics). gracefoReading.readGroopsInstrument
%       reads the format back and makes that check a two-line test.
%     - NaN values are written as the platform's printf representation
%       of NaN; GROOPS may not accept them, so filter or fill gaps
%       before export.
%
%   ERRORS
%     gracefoReading:writeGroopsInstrument:sizeMismatch
%       number of rows of time and data differ
%     gracefoReading:writeGroopsInstrument:openFailed
%       the output file could not be opened for writing
%
%   EXAMPLES
%     % 1. export the three linear accelerations of one day
%     [t, acc, aux] = gracefoReading.readL1b('ACT1B_2020-01-01_C_04.txt');
%     gracefoReading.writeGroopsInstrument('act.txt', t, acc(:,1:3));
%
%     % 2. typed record with compact formatting, then verify
%     gracefoReading.writeGroopsInstrument('act.txt', t, acc(:,1:3), ...
%         'TypeCode', 3, 'Format', "%.9e");
%     [t2, d2, info] = gracefoReading.readGroopsInstrument('act.txt');
%
%   See also gracefoReading.readGroopsInstrument, gracefoReading.readL1b
%
%   Toolbox:  gracefoReading v1.3.1
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    fileName (1,1) string
    time
    data (:,:) double
    options.TypeCode (1,1) double {mustBeInteger} = 0
    options.Version (1,1) double {mustBeInteger} = 20200123
    options.Format (1,1) string = "%.16e"
end

if isdatetime(time)
    mjdDec = 51544 + days(time(:) - datetime(2000,1,1,0,0,0));
else
    if size(time, 2) ~= 2
        error('gracefoReading:writeGroopsInstrument:sizeMismatch', ...
            'TIME must be [N x 2] (MJD, seconds of day) or datetime [N x 1].');
    end
    mjdDec = time(:,1) + time(:,2) / 86400;
end
n = numel(mjdDec);
if size(data, 1) ~= n
    error('gracefoReading:writeGroopsInstrument:sizeMismatch', ...
        'DATA has %d rows but TIME has %d records.', size(data,1), n);
end

% 'w' (not 'wt'): no platform newline translation, so output is always
% LF-terminated and byte-identical across Linux/Windows (reproducible
% checksums; GROOPS runs on Linux and expects plain LF).
fid = fopen(fileName, 'w');
if fid < 0
    error('gracefoReading:writeGroopsInstrument:openFailed', ...
        'Could not open %s for writing.', fileName);
end
cln = onCleanup(@() fclose(fid));

fprintf(fid, 'groops instrument version=%d\n', options.Version);
fprintf(fid, '%d %d\n', options.TypeCode, size(data, 2));
fprintf(fid, '%d\n', n);
lineFmt = ['%.15f', repmat([' ', char(options.Format)], 1, size(data, 2)), '\n'];
for r = 1:n
    fprintf(fid, lineFmt, mjdDec(r), data(r, :));
end
end
