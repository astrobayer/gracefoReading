function [entries, unparsable] = parseChecksumManifest(manifestFile)
%PARSECHECKSUMMANIFEST  Parse a checksum manifest into name/digest pairs.
%
%   SYNTAX
%     entries = gracefoReading.internal.parseChecksumManifest(manifestFile)
%     [entries, unparsable] = ...
%         gracefoReading.internal.parseChecksumManifest(manifestFile)
%
%   DESCRIPTION
%     Reads a checksum list of the kind the data sources publish beside
%     their archives and returns one entry per listed file. Two line
%     formats are recognised, which between them cover what the tools
%     in use emit:
%
%       coreutils   "<hex>  <name>"   or   "<hex> *<name>"
%                   as written by sha256sum / md5sum, the second form
%                   marking binary mode;
%       BSD tagged  "SHA256 (<name>) = <hex>"
%                   as written by BSD md5/shasum -a and by openssl
%                   dgst -r's tagged output.
%
%     The algorithm comes from the tag where the format carries one and
%     otherwise from the digest LENGTH, which is a property of the line
%     rather than of the manifest's file name: a list called
%     SHA256SUMS_2020-01.txt that in fact holds MD5 digests is read as
%     what it contains, and the disagreement is visible to the caller
%     because the algorithm is returned per entry.
%
%     Blank lines and lines whose first non-blank character is '#' are
%     comments and are skipped silently. Any other line that matches
%     neither format is reported through unparsable, never guessed at.
%     Internal function - the public interface is
%     gracefoReading.verifyDataPool.
%
%   INPUT
%     manifestFile - string | char, 1x1
%                Path of the manifest. Must be readable.
%                Required, positional.
%
%   OUTPUT
%     entries - struct, 1x1
%                Fields name, digest and algorithm, each a string
%                [E x 1] in file order; E = number of parsed lines.
%                name is exactly as written in the manifest, with a
%                leading "./" removed and backslashes left alone;
%                digest is lowercase hexadecimal; algorithm is a JCA
%                name ("MD5", "SHA-1", "SHA-256", "SHA-384",
%                "SHA-512") or "" when the digest length matches none
%                of them.
%     unparsable - double, [U x 1]
%                Line numbers of non-comment lines that matched
%                neither format.
%
%   ACCURACY AND LIMITATIONS
%     - A file name containing two or more consecutive spaces, or a
%       leading space, is returned as written; the separator between
%       digest and name is taken to be the first run of whitespace.
%     - Only the two formats above are recognised. A manifest that
%       lists the name first, or that carries a size column, is
%       reported as unparsable rather than parsed by guesswork: the
%       caller then sees zero entries and a list of line numbers
%       instead of a silently empty verification.
%     - The digest length decides the algorithm, so a truncated or
%       padded digest yields "" rather than a wrong algorithm.
%     - The file is read as text, so both LF and CRLF manifests work.
%
%   EXAMPLE
%     % internal use only; called by gracefoReading.verifyDataPool:
%     e = gracefoReading.internal.parseChecksumManifest( ...
%         'SHA256SUMS_2020-01.txt');
%     fprintf('%d entry/entries, first algorithm %s\n', ...
%         numel(e.name), e.algorithm(1));
%
%   See also gracefoReading.verifyDataPool,
%            gracefoReading.internal.fileDigest
%
%   Toolbox:  gracefoReading v1.0.2
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    manifestFile (1,1) string
end

txt = string(fileread(manifestFile));
lines = splitlines(regexprep(txt, '\r\n?', newline));

names = strings(0, 1);
digests = strings(0, 1);
algos = strings(0, 1);
unparsable = zeros(0, 1);

for i = 1:numel(lines)
    ln = strtrim(lines(i));
    if strlength(ln) == 0 || startsWith(ln, "#")
        continue
    end

    tok = regexp(char(ln), '^([0-9a-fA-F]{8,128})\s+\*?(.+)$', 'tokens', 'once');
    if ~isempty(tok)
        names(end+1, 1)   = localCleanName(tok{2});      %#ok<AGROW>
        digests(end+1, 1) = lower(string(tok{1}));       %#ok<AGROW>
        algos(end+1, 1)   = localAlgorithm(numel(tok{1})); %#ok<AGROW>
        continue
    end

    tok = regexp(char(ln), ...
        '^([A-Za-z0-9-]+)\s*\(\s*(.+?)\s*\)\s*=\s*([0-9a-fA-F]{8,128})$', ...
        'tokens', 'once');
    if ~isempty(tok)
        names(end+1, 1)   = localCleanName(tok{2});       %#ok<AGROW>
        digests(end+1, 1) = lower(string(tok{3}));        %#ok<AGROW>
        algos(end+1, 1)   = localTaggedAlgorithm(tok{1}, numel(tok{3})); %#ok<AGROW>
        continue
    end

    unparsable(end+1, 1) = i; %#ok<AGROW>
end

% Assigned field by field, not struct('name', names, ...): struct()
% expands array values into a STRUCT ARRAY of that size, which would
% turn one manifest into E scalar entries.
entries = struct();
entries.name = names;
entries.digest = digests;
entries.algorithm = algos;
end

% ========================================================================
function name = localCleanName(raw)
% The name as written, minus the "./" a recursive sha256sum run prefixes.
name = string(strtrim(raw));
if startsWith(name, "./")
    name = extractAfter(name, 2);
end
end

% ========================================================================
function algo = localAlgorithm(nHexDigits)
% The digest LENGTH names the algorithm: it is a property of the line.
switch nHexDigits
    case 32,  algo = "MD5";
    case 40,  algo = "SHA-1";
    case 64,  algo = "SHA-256";
    case 96,  algo = "SHA-384";
    case 128, algo = "SHA-512";
    otherwise, algo = "";
end
end

% ========================================================================
function algo = localTaggedAlgorithm(tag, nHexDigits)
% A tagged line states its algorithm; the length still has to agree,
% because a tag that disagrees with its own digest cannot be trusted to
% name the right one.
byLength = localAlgorithm(nHexDigits);
switch upper(strrep(string(tag), "-", ""))
    case "MD5",    byTag = "MD5";
    case "SHA1",   byTag = "SHA-1";
    case "SHA256", byTag = "SHA-256";
    case "SHA384", byTag = "SHA-384";
    case "SHA512", byTag = "SHA-512";
    otherwise,     byTag = "";
end
if byTag == byLength
    algo = byTag;
else
    algo = "";
end
end
