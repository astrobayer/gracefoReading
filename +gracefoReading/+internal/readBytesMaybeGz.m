function bytes = readBytesMaybeGz(fileName)
%READBYTESMAYBEGZ  Read a file as raw bytes, transparently un-gzipping.
%
%   SYNTAX
%     bytes = gracefoReading.internal.readBytesMaybeGz(fileName)
%
%   DESCRIPTION
%     Byte-exact counterpart of readTextMaybeGz, for the classic GRACE
%     products whose records are BINARY after an ASCII header.
%
%     Those files cannot go through the text reader. fileread returns
%     char, and a char read applies the file encoding: an arbitrary
%     byte sequence is not valid UTF-8, so bytes would be replaced or
%     merged and the record structure destroyed - silently, because
%     the ASCII header would still look perfectly readable. This
%     function opens the stream in binary mode and reads '*uint8', so
%     what comes back is what is on disk whatever the encoding
%     setting. Internal function - the public interface is
%     gracefoReading.readL1b.
%
%   INPUT
%     fileName - string | char, 1x1
%                Path of the file, plain or gzip-compressed (".gz").
%                Validation: mustBeFile. Required, positional.
%
%   OUTPUT
%     bytes - uint8, [1 x B]
%                Every byte of the (decompressed) file, in order;
%                B = decompressed size. Empty for an empty file.
%
%   ACCURACY AND LIMITATIONS
%     - The whole file is held in memory. A classic daily product is a
%       few megabytes, so this is not a constraint here; a caller
%       reading a mission of days should read one file at a time.
%     - Gzip is decompressed in memory via Java when available, with
%       the same temporary-file fallback readTextMaybeGz uses. The
%       Java path returns int8 and is cast back to uint8; the
%       pass-by-value trap documented in readTextMaybeGz applies here
%       too, which is why IOUtils.toByteArray is used rather than a
%       read loop.
%     - No encoding is applied, deliberately. Callers that want text
%       convert with char() themselves.
%
%   EXAMPLE
%     % internal use only; called by gracefoReading.readL1b for a
%     % classic binary product:
%     b = gracefoReading.internal.readBytesMaybeGz('ACC1B_2008-01-01_A_02.dat');
%
%   See also gracefoReading.readL1b,
%            gracefoReading.internal.readTextMaybeGz,
%            gracefoReading.internal.parseClassicBinary
%
%   Toolbox:  gracefoReading v1.3.3
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    fileName (1,1) string {mustBeFile}
end

if ~endsWith(fileName, ".gz", 'IgnoreCase', true)
    fid = fopen(fileName, 'r');
    if fid < 0
        error('gracefoReading:readL1b:fileUnreadable', ...
            'Could not open %s for reading.', fileName);
    end
    closeFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
    bytes = reshape(fread(fid, inf, '*uint8'), 1, []);
    return
end

try
    fis = java.io.FileInputStream(char(fileName));
    clnF = onCleanup(@() fis.close()); %#ok<NASGU>
    gzs = java.util.zip.GZIPInputStream(fis);
    jb = org.apache.commons.io.IOUtils.toByteArray(gzs);   % int8 vector
    gzs.close();
    if ~isempty(jb)
        bytes = reshape(typecast(int8(jb), 'uint8'), 1, []);
        return
    end
catch
    % fall through to gunzip
end

outDir = tempname; mkdir(outDir);
cleanupTmp = onCleanup(@() rmdir(outDir, 's')); %#ok<NASGU>
unzipped = gunzip(fileName, outDir);
fid = fopen(unzipped{1}, 'r');
closeTmp = onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes = reshape(fread(fid, inf, '*uint8'), 1, []);
end
