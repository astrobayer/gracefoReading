function [bits, report] = decodeQualFlags(aux, flagName)
%DECODEQUALFLAGS  Decode a bit-string flag column using the file's own header.
%
%   SYNTAX
%     [bits, report] = gracefoReading.decodeQualFlags(aux)
%     [bits, report] = gracefoReading.decodeQualFlags(aux, flagName)
%
%   DESCRIPTION
%     Decodes a bit-string flag column of a previously read Level-1B
%     product into a logical matrix and summarises how often each bit
%     is set. The bit meanings are taken from the flag_meanings
%     attribute parsed out of the product file's own header
%     (aux.variableAttributes), so the decoding always matches the file
%     actually read and no release-dependent bit tables are hard-coded.
%     Bits without a documented meaning are still reported, marked as
%     not documented.
%
%   INPUT
%     aux - struct, 1x1
%                Third output of gracefoReading.readL1b or
%                readL1bMulti. Must contain the raw flag field as char
%                [N x B] and the variableAttributes struct.
%                Required, positional.
%
%     flagName - string | char, 1x1
%                Name of the flag variable to decode.
%                Options: 'qualflg', 'prod_flag', or any other
%                bit-string column present in aux.
%                Default: 'qualflg'. Optional, positional.
%
%   OUTPUT
%     bits   - logical, [N x B]
%                Column b corresponds to bit b-1; bit 0 is the
%                rightmost character of the bit string, following the
%                GRACE-FO convention.
%     report - table, [B x 4]
%                One row per bit, variables:
%                  bit      double, bit number (0-based)
%                  meaning  string, meaning from the header, or
%                           "(not documented)"
%                  countSet double, records with this bit set
%                  fracSet  double, fraction of records, range 0 to 1
%
%   ACCURACY AND LIMITATIONS
%     - Decoding is exact: it is a character comparison, not a
%       numerical conversion.
%     - Meanings are only as complete as the header of the file at
%       hand. Different releases document different bits, and some
%       products document none, in which case every meaning reads
%       "(not documented)" - this is a property of the data, not a
%       failure of the function.
%     - The order in which flag_meanings entries map to bit numbers
%       follows the file's declaration order, assumed to start at
%       bit 0. Where a header lists fewer meanings than the flag has
%       characters, the surplus bits stay undocumented.
%     - Applies to bit-string columns only. Classic GRACE products may
%       store qualflg as a decimal number, which this function does not
%       decode (see readL1b limitations).
%
%   ERRORS
%     gracefoReading:decodeQualFlags:flagNotFound
%       the requested flag column is not present in aux
%     gracefoReading:decodeQualFlags:notBitString
%       the requested column is not a character bit string
%
%   EXAMPLES
%     % 1. quality flags of an SCA1B day
%     [t, q, aux] = gracefoReading.readL1b('SCA1B_2020-01-01_C_04.txt');
%     [bits, report] = gracefoReading.decodeQualFlags(aux);
%     disp(report)
%
%     % 2. which MAS1B columns are actually present (prod_flag)
%     [~, ~, auxM] = gracefoReading.readL1b('MAS1B_2020-01-01_C_04.txt');
%     [~, rep] = gracefoReading.decodeQualFlags(auxM, 'prod_flag');
%     disp(rep(rep.fracSet > 0, :))
%
%   See also gracefoReading.readL1b, gracefoReading.readL1bMulti
%
%   Toolbox:  gracefoReading v2.3.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14

arguments
    aux (1,1) struct
    flagName (1,1) string = "qualflg"
end

fn = matlab.lang.makeValidName(char(flagName));
if ~isfield(aux, fn)
    error('gracefoReading:decodeQualFlags:flagNotFound', ...
        'Field "%s" not found in aux. Available fields: %s', ...
        flagName, strjoin(fieldnames(aux), ', '));
end
raw = aux.(fn);
if ~ischar(raw)
    error('gracefoReading:decodeQualFlags:notBitString', ...
        'aux.%s is not a raw bit-string (char) column.', fn);
end
nBits = size(raw, 2);
bits = raw(:, end:-1:1) == '1';

meanings = repmat("(not documented)", nBits, 1);
if isfield(aux, 'variableAttributes') && isfield(aux.variableAttributes, fn) ...
        && isfield(aux.variableAttributes.(fn), 'flag_meanings')
    fm = aux.variableAttributes.(fn).flag_meanings;
    for i = 1:numel(fm)
        % entries like "bit 6 = No OBC-to-Receiver Time mapping"
        tok = regexp(fm{i}, '^bit\s+(\d+)\s*=\s*(.*)$', 'tokens', 'once');
        if ~isempty(tok)
            b = str2double(tok{1});
            if b < nBits, meanings(b+1) = string(strtrim(tok{2})); end
            continue
        end
        % entries like "bits 0-5 = Not defined"
        tok = regexp(fm{i}, '^bits\s+(\d+)\s*-\s*(\d+)\s*=\s*(.*)$', 'tokens', 'once');
        if ~isempty(tok)
            b1 = str2double(tok{1}); b2 = str2double(tok{2});
            for b = b1:min(b2, nBits-1)
                meanings(b+1) = string(strtrim(tok{3}));
            end
        end
    end
end

countSet = sum(bits, 1)';
report = table((0:nBits-1)', meanings, countSet, countSet / size(bits,1), ...
    'VariableNames', {'bit', 'meaning', 'countSet', 'fracSet'});
end
