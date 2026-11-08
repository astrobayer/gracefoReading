function [timeMjd, timeNs, obs, aux] = parseYamlProduct(lines, hdrEnd, fileName, timeVarOpt)
%PARSEYAMLPRODUCT  Parse a GRACE-FO YAML-header Level-1B ASCII product.
%
%   SYNTAX
%     [timeMjd, timeNs, obs, aux] = gracefoReading.internal.parseYamlProduct( ...
%         lines, hdrEnd, fileName, timeVarOpt)
%
%   DESCRIPTION
%     Header handling for the modern RL04 format: rejects binary
%     products, extracts the declared variables and the record count,
%     and delegates the record section to
%     gracefoReading.internal.parseDataSection. Internal function - the
%     public interface is gracefoReading.readL1b.
%
%   INPUT
%     lines - string, [L x 1]
%                All lines of the file.
%                Required, positional.
%     hdrEnd - double, 1x1
%                Index of the "# End of YAML header" line.
%                Required, positional.
%     fileName - string, 1x1
%                Source path for messages and provenance.
%                Required, positional.
%     timeVarOpt - string, 1x1
%                Time-tag override, "" for automatic detection.
%                Required, positional.
%
%   OUTPUT
%     timeMjd - double, [N x 2]
%                Integer MJD and seconds of day.
%     timeNs  - int64, [N x 1]
%                Exact GPS nanoseconds.
%     obs     - double, [N x M]
%                Observation columns.
%     aux     - struct, 1x1
%                Core metadata; readL1b adds headerFormat = 'yaml'.
%
%   ACCURACY AND LIMITATIONS
%     - Accuracy is that of parseDataSection.
%     - The record count is read from the first num_records entry in
%       the header; products declaring several counts would need a more
%       specific pattern.
%     - Binary products are detected by a "format: bin" line and
%       rejected; a binary file without that declaration would fail
%       later with a parsing error instead.
%
%   ERRORS
%     gracefoReading:readL1b:binaryNotSupported  binary product
%     gracefoReading:readL1b:noVariables         no variables declared
%
%   EXAMPLE
%     % internal use only; called by gracefoReading.readL1b:
%     [timeMjd, timeNs, obs, aux] = ...
%         gracefoReading.internal.parseYamlProduct(lines, hdrEnd, f, "");
%
%   See also gracefoReading.readL1b, gracefoReading.internal.parseDataSection
%
%   Toolbox:  gracefoReading v1.3.2
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

headerLines = cellstr(lines(1:hdrEnd));
headerText = strjoin(headerLines, newline);

if ~isempty(regexpi(headerText, 'format:\s*bin', 'once'))
    error('gracefoReading:readL1b:binaryNotSupported', ...
        'Binary Level-1B files are not supported; use the ASCII (YAML header) product.');
end

[varNames, varAttrs] = gracefoReading.internal.parseHeaderVariables(headerLines);
if isempty(varNames)
    error('gracefoReading:readL1b:noVariables', ...
        'No variable declarations found in the header of %s.', fileName);
end

numRecTok = regexp(headerText, 'num_records:\s*(\d+)', 'tokens', 'once');
if isempty(numRecTok), numRecordsHeader = NaN;
else, numRecordsHeader = str2double(numRecTok{1}); end

dataLines = lines(hdrEnd+1:end);
nonEmpty = strlength(strtrim(dataLines)) > 0;
dataLines = dataLines(nonEmpty);
dataLineNos = hdrEnd + find(nonEmpty);

[timeMjd, timeNs, obs, aux] = gracefoReading.internal.parseDataSection( ...
    dataLines, dataLineNos, varNames, varAttrs, fileName, timeVarOpt, ...
    numRecordsHeader, headerLines);
end
