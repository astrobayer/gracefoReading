function txt = readTextMaybeGz(fileName)
%READTEXTMAYBEGZ  Read a text file, transparently handling gzip input.
%
%   SYNTAX
%     txt = gracefoReading.internal.readTextMaybeGz(fileName)
%
%   DESCRIPTION
%     Returns the full text content of a file as a char row vector.
%     Files ending in ".gz" are decompressed in memory using the JVM's
%     GZIPInputStream when Java is available; if that fails, for
%     example under -nojvm, a temporary-directory gunzip fallback is
%     used and cleaned up afterwards. Internal function - the public
%     interface is gracefoReading.readL1b, which accepts .gz paths
%     directly.
%
%   INPUT
%     fileName - string | char, 1x1
%                Path to a plain-text or gzip-compressed text file.
%                Validation: mustBeFile. Required, positional.
%
%   OUTPUT
%     txt - char, [1 x C]
%                Complete file content, line endings preserved.
%
%   ACCURACY AND LIMITATIONS
%     - The in-memory path reads the whole file at once via
%       org.apache.commons.io.IOUtils.toByteArray. A byte-buffer read
%       loop must NOT be used from MATLAB: Java primitive arrays are
%       passed by value, so an out-parameter fills a copy and the
%       MATLAB side silently keeps its zeros. That defect produced
%       zero-filled text and is the reason for the current
%       implementation.
%     - Memory use is roughly the uncompressed size; a full day of
%       1 Hz ASCII data is a few tens of megabytes, which is
%       comfortable, but very large concatenated archives should be
%       read file by file.
%     - Only gzip is handled. Other containers (zip, bz2) must be
%       unpacked beforehand.
%     - Content is returned as char, i.e. interpreted as 8-bit text;
%       the ASCII products contain no multi-byte characters.
%
%   ERRORS
%     (none of its own; propagates errors from gunzip or fileread)
%
%   EXAMPLE
%     % internal use only; called by gracefoReading.readL1b:
%     txt = gracefoReading.internal.readTextMaybeGz('ACT1B_2020-01-01_C_04.txt.gz');
%
%   See also gracefoReading.readL1b
%
%   Toolbox:  gracefoReading v1.3.2
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    fileName (1,1) string {mustBeFile}
end

if ~endsWith(fileName, ".gz", 'IgnoreCase', true)
    txt = fileread(fileName);
    return
end

% In-memory decompression via Java, no temp files.
% NOTE: a byte-buffer read loop (gzs.read(jbuf, ...)) does NOT work from
% MATLAB: Java primitive arrays are auto-converted to MATLAB arrays and
% passed BY VALUE, so Java's out-parameter fills a copy and the MATLAB
% side keeps its zeros (silent data corruption, found by unit test).
% IOUtils.toByteArray performs the whole read inside Java and returns
% the finished array, avoiding the out-parameter pattern entirely.
try
    fis = java.io.FileInputStream(char(fileName));
    clnF = onCleanup(@() fis.close()); %#ok<NASGU>
    gzs = java.util.zip.GZIPInputStream(fis);
    bytes = org.apache.commons.io.IOUtils.toByteArray(gzs);  % int8 vector
    gzs.close();
    if ~isempty(bytes)
        txt = char(reshape(typecast(int8(bytes), 'uint8'), 1, []));
        return
    end
catch
    % fall through to gunzip
end

outDir = tempname; mkdir(outDir);
cleanupTmp = onCleanup(@() rmdir(outDir, 's')); %#ok<NASGU>
unzipped = gunzip(fileName, outDir);
txt = fileread(unzipped{1});
end
