function key = contentHash(varargin)
%CONTENTHASH  SHA-256 hex digest of the concatenated inputs.
%
%   SYNTAX
%     key = gracefoReading.internal.contentHash(txt1, txt2, ...)
%
%   DESCRIPTION
%     Returns the SHA-256 digest of the concatenation of all inputs.
%     readL1b uses it as the parse-cache key over file content,
%     toolbox version and the parse-relevant options, which makes the
%     key simultaneously a cache identifier and a provenance
%     fingerprint: identical keys mean identical parse inputs.
%     Internal function - the public interface is the 'CacheDir'
%     option of gracefoReading.readL1b.
%
%   INPUT
%     varargin - char | string, 1x1 each
%                Any number of text inputs, concatenated in the order
%                given. Empty inputs contribute nothing.
%                Required, positional.
%
%   OUTPUT
%     key - string, 1x1
%                64 lowercase hex characters, or "" when hashing is
%                unavailable, which callers treat as caching disabled.
%
%   ACCURACY AND LIMITATIONS
%     - Requires the JVM (java.security.MessageDigest). Under -nojvm
%       the function returns "" instead of raising, and readL1b then
%       parses normally after a cacheUnavailable warning.
%     - Inputs are hashed as raw bytes of their char representation;
%       non-ASCII text is therefore hashed by its char codes, which is
%       stable within MATLAB but not necessarily identical to a hash
%       computed on the UTF-8 encoding of the same string.
%     - Concatenation without a separator means that the pair
%       ("ab","c") and ("a","bc") produce the same digest. All current
%       callers pass fixed-position fields, so this cannot occur; keep
%       it in mind when adding new key components.
%     - SHA-256 collisions are not a practical concern, but the digest
%       covers only what is passed in: options applied after parsing
%       are deliberately excluded from the key.
%
%   ERRORS
%     (none; failures are reported by returning "")
%
%   EXAMPLE
%     % internal use only; called by gracefoReading.readL1b:
%     key = gracefoReading.internal.contentHash(rawText, ...
%         gracefoReading.version(), 'gps_time', '');
%
%   See also gracefoReading.readL1b
%
%   Toolbox:  gracefoReading v1.3.1
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

try
    md = java.security.MessageDigest.getInstance('SHA-256');
    for i = 1:numel(varargin)
        bytes = uint8(char(varargin{i}));
        if ~isempty(bytes)
            md.update(typecast(bytes, 'int8'));
        end
    end
    key = string(sprintf('%02x', typecast(md.digest(), 'uint8')));
catch
    key = "";
end
end
