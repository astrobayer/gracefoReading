function [fields, keys, values] = parseClassicHeader(headerLines)
%PARSECLASSICHEADER  Parse the "KEY : VALUE" header of a classic product.
%
%   SYNTAX
%     fields = gracefoReading.internal.parseClassicHeader(headerLines)
%     [fields, keys, values] = ...
%         gracefoReading.internal.parseClassicHeader(headerLines)
%
%   DESCRIPTION
%     SINGLE POINT OF ACCESS for the classic GRACE (2002-2017) header
%     dialect: 80-character records of the form "KEY : VALUE",
%     terminated by a record reading "END OF HEADER". Both classic
%     paths use it - the ASCII one and the binary one - so the two
%     cannot disagree about what a header says, which matters because
%     the binary path reads its record count and its declared file
%     size from exactly these fields. Internal function; the public
%     interface is gracefoReading.readL1b.
%
%   INPUT
%     headerLines - cellstr | string, [H x 1]
%                Header records up to and including "END OF HEADER";
%                H = number of records. Trailing padding is ignored.
%                Required, positional.
%
%   OUTPUT
%     fields - struct, 1x1
%                One field per parsed key, named by
%                matlab.lang.makeValidName of the lower-cased key, with
%                the trimmed value as char. Lines matching no
%                "KEY : VALUE" pattern are skipped. A repeated key
%                keeps the LAST occurrence, which is how the repeated
%                "INPUT FILE NAME" records behave.
%     keys - string, [K x 1]
%                The raw key text of each parsed record, in file
%                order and before any sanitising; K = parsed records.
%                Use this to look a field up by what the header
%                actually calls it, rather than by a name that depends
%                on how makeValidName happens to rewrite it.
%     values - string, [K x 1]
%                The matching values, trimmed.
%
%   ACCURACY AND LIMITATIONS
%     - Values are kept verbatim as text; numeric fields such as
%       NUMBER OF DATA RECORDS must be converted by the caller.
%     - A key containing a colon would be split at the first colon.
%       No classic key does.
%     - The key character class admits letters in either case, digits,
%       spaces, "()-/." and "=+". The last two matter: the real
%       headers carry "FILE FORMAT 0=BINARY 1=ASCII", which the
%       upper-case-only class used until 2026-09-22 skipped silently -
%       and that is the field the binary dispatch turns on.
%     - Repeated keys collapse, so the provenance chain of
%       "INPUT FILE NAME" records is not recoverable from this struct.
%       The raw header is kept in aux.header for that reason.
%
%   EXAMPLE
%     % internal use only; called by parseClassicProduct and
%     % parseClassicBinary:
%     f = gracefoReading.internal.parseClassicHeader(lines(1:hdrEnd));
%     n = str2double(f.numberOfDataRecords);
%
%   See also gracefoReading.readL1b,
%            gracefoReading.internal.parseClassicProduct,
%            gracefoReading.internal.parseClassicBinary
%
%   Toolbox:  gracefoReading v1.1.0
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    headerLines
end

lines = cellstr(headerLines);
fields = struct();
keys = strings(0, 1);
values = strings(0, 1);
for i = 1:numel(lines)
    tok = regexp(lines{i}, ...
        '^([A-Za-z0-9][A-Za-z0-9 ()\-/\.=+]*?)\s*:\s*(.*\S)\s*$', ...
        'tokens', 'once');
    if ~isempty(tok)
        rawKey = strtrim(tok{1});
        rawVal = strtrim(tok{2});
        key = matlab.lang.makeValidName(lower(rawKey));
        fields.(key) = rawVal;
        keys(end+1, 1) = string(rawKey);   %#ok<AGROW>
        values(end+1, 1) = string(rawVal); %#ok<AGROW>
    end
end
end
