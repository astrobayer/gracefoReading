function [digest, reason] = fileDigest(fileName, algorithm)
%FILEDIGEST  Cryptographic digest of a file, streamed block by block.
%
%   SYNTAX
%     digest = gracefoReading.internal.fileDigest(fileName, algorithm)
%     [digest, reason] = gracefoReading.internal.fileDigest(fileName, algorithm)
%
%   DESCRIPTION
%     Returns the lowercase hexadecimal digest of a file's bytes, for
%     comparison against a published checksum. The file is read in
%     blocks and fed to java.security.MessageDigest, so a pool file of
%     several gigabytes is hashed without ever being held in memory.
%
%     The bytes are read exactly as they are on disk ('r' with '*uint8'
%     on a stream opened in binary mode), never as text: a text-mode
%     read would rewrite CRLF on Windows and every digest of every text
%     product would then disagree with the published one. Internal
%     function - the public interface is
%     gracefoReading.verifyDataPool.
%
%   INPUT
%     fileName - string | char, 1x1
%                Path of the file to hash. Need not exist; a file that
%                cannot be opened is reported through reason rather
%                than raising.
%                Required, positional.
%     algorithm - string | char, 1x1
%                JCA digest name.
%                Options: "MD5" | "SHA-1" | "SHA-256" (any name the
%                installed provider accepts).
%                Required, positional.
%
%   OUTPUT
%     digest - string, 1x1
%                Lowercase hexadecimal digest, or "" when the file
%                could not be hashed.
%     reason - string, 1x1
%                "" on success, otherwise a one-line explanation the
%                caller can put into its report: the file could not be
%                opened, the algorithm is unknown to the provider, or
%                no JVM is available.
%
%   ACCURACY AND LIMITATIONS
%     - Needs the JVM. MATLAB started with -nojvm returns "" and a
%       reason; the caller reports that state rather than treating an
%       unhashable file as a mismatch.
%     - The digest covers the bytes on disk. A gzip-compressed product
%       hashes as the compressed file, which is what a published
%       checksum of a .gz refers to.
%     - Reading is sequential; the cost is one pass over the file and
%       is dominated by disk throughput, not by the digest.
%
%   EXAMPLE
%     % internal use only; called by gracefoReading.verifyDataPool:
%     d = gracefoReading.internal.fileDigest( ...
%         'ACT1B_2020-01-01_C_04.txt', 'SHA-256');
%
%   See also gracefoReading.verifyDataPool,
%            gracefoReading.internal.contentHash
%
%   Toolbox:  gracefoReading v1.4.0
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    fileName (1,1) string
    algorithm (1,1) string
end

digest = "";
reason = "";

try
    md = java.security.MessageDigest.getInstance(algorithm);
catch err
    reason = "digest algorithm """ + algorithm + """ unavailable (" + ...
        string(err.message) + ")";
    return
end

fid = fopen(fileName, 'r');
if fid < 0
    reason = "file could not be opened for reading";
    return
end
closeFile = onCleanup(@() fclose(fid));

blockBytes = 1048576;                       % 1 MiB per read
while true
    block = fread(fid, blockBytes, '*uint8');
    if isempty(block)
        break
    end
    md.update(typecast(block(:), 'int8'));
end

digest = string(sprintf('%02x', typecast(md.digest(), 'uint8')));
end
