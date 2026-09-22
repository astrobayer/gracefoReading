function [timeMjd, timeNs, obs, aux] = parseClassicProduct(lines, hdrEnd, ...
    fileName, timeVarOpt, columnNames)
%PARSECLASSICPRODUCT  Parse a classic GRACE (2002-2017) Level-1B ASCII product.
%
%   SYNTAX
%     [timeMjd, timeNs, obs, aux] = gracefoReading.internal.parseClassicProduct( ...
%         lines, hdrEnd, fileName, timeVarOpt, columnNames)
%
%   DESCRIPTION
%     EXPERIMENTAL. Classic GRACE ASCII headers are "KEY : VALUE" lines
%     terminated by "END OF HEADER" and, unlike GRACE-FO YAML headers,
%     do not declare their data columns. Column layouts therefore come
%     from built-in per-product tables or from the caller. The record
%     section is parsed by the same validated engine as the modern
%     products. Internal function - the public interface is
%     gracefoReading.readL1b, which warns on every classic read.
%
%     Built-in layouts: ACC1B, SCA1B, KBR1B, GNV1B. Any other classic
%     product requires explicit column names.
%
%   INPUT
%     lines - string, [L x 1]
%                All lines of the file.
%                Required, positional.
%     hdrEnd - double, 1x1
%                Index of the "END OF HEADER" line.
%                Required, positional.
%     fileName - string, 1x1
%                Source path; the leading product token of the file
%                name selects the built-in layout.
%                Required, positional.
%     timeVarOpt - string, 1x1
%                Time-tag override, "" for automatic detection.
%                Required, positional.
%     columnNames - string, [1 x C]
%                Explicit column layout in file order, overriding the
%                built-in table.
%                Options: any variable names; recognized special names
%                are gps_time, time_intg, time_frac, qualflg,
%                prod_flag, GRACE_id, coord_ref.
%                Default: [] (empty, use the built-in table).
%
%   OUTPUT
%     timeMjd - double, [N x 2]
%                Integer MJD and seconds of day.
%     timeNs  - int64, [N x 1]
%                Exact GPS nanoseconds.
%     obs     - double, [N x M]
%                Observation columns.
%     aux     - struct, 1x1
%                Core metadata plus classicHeaderFields, a struct of
%                the parsed KEY : VALUE pairs with sanitized names.
%
%   ACCURACY AND LIMITATIONS
%     - The built-in column layouts are ASSUMED from the GRACE
%       Level-1B handbook and have NOT been validated against real
%       classic files. Using them unverified risks silently mislabelled
%       columns; obtain one real file per product and confirm, or pass
%       'ColumnNames' explicitly.
%     - Classic qualflg may be stored as a decimal number rather than
%       an 8-character bit string. In that case the column is treated
%       as numeric auxiliary data and decodeQualFlags cannot decode it.
%     - Classic headers are less standardized than YAML headers; the
%       KEY : VALUE parser keeps only lines matching that pattern and
%       silently ignores the rest.
%     - Time in classic products is GPS seconds past the same 2000
%       epoch, so the time handling is identical to GRACE-FO. Products
%       with a split time tag are assumed to give the fractional part
%       in microseconds.
%
%   ERRORS
%     gracefoReading:readL1b:unsupportedClassicProduct
%       no built-in layout for this product and no columnNames given
%
%   EXAMPLE
%     % internal use only; reached via gracefoReading.readL1b:
%     [t, obs, aux] = gracefoReading.readL1b('ACC1B_2008-01-01_A_02.txt', ...
%         'ColumnNames', ["gps_time","GRACE_id","lin_accl_x"]);
%
%   See also gracefoReading.readL1b, gracefoReading.internal.parseDataSection
%
%   Toolbox:  gracefoReading v1.1.0
%   Created:  2026-08-01
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

headerLines = cellstr(lines(1:hdrEnd));

% One parser for the classic header dialect, shared with the binary path
% so the two cannot disagree about what a header says.
hdrFields = gracefoReading.internal.parseClassicHeader(headerLines);

numRecordsHeader = NaN;
if isfield(hdrFields, 'numberOfDataRecords')
    numRecordsHeader = str2double(hdrFields.numberOfDataRecords);
end

[~, base] = fileparts(fileName);
prodTok = regexp(char(base), '^([A-Z]{3}1B)', 'tokens', 'once');
product = '';
if ~isempty(prodTok), product = prodTok{1}; end

% column layout: explicit override or built-in table
if ~isempty(columnNames)
    varNames = cellstr(columnNames);
else
    layout = gracefoReading.internal.classicLayout(product);
    if isempty(fieldnames(layout))
        error('gracefoReading:readL1b:unsupportedClassicProduct', ...
            ['No classic column layout for product "%s" (known: ACC1B, ', ...
             'SCA1B, GNV1B, KBR1B, THR1B, MAS1B). Supply the layout via ', ...
             'the ''ColumnNames'' option.'], product);
    end
    varNames = layout.names;
end

% attributes: units 'char' for the known character columns
charCols = {'GRACE_id', 'GRACEFO_id', 'coord_ref', 'time_ref'};
varAttrs = struct();
% Same field-name rule as the YAML path: 'ColumnNames' is caller-supplied
% and may hold anything, and parseDataSection looks the attributes up by
% the field name this call produces.
classicFields = gracefoReading.internal.variableFieldNames(varNames);
for k = 1:numel(varNames)
    fn = classicFields{k};
    if any(strcmpi(varNames{k}, charCols))
        varAttrs.(fn) = struct('units', 'char');
    else
        varAttrs.(fn) = struct();
    end
    % classic split time tags are documented in microseconds
    if strcmpi(varNames{k}, 'time_frac')
        varAttrs.(fn).units = 'microseconds';
    end
end

dataLines = lines(hdrEnd+1:end);
nonEmpty = strlength(strtrim(dataLines)) > 0;
dataLines = dataLines(nonEmpty);
dataLineNos = hdrEnd + find(nonEmpty);

[timeMjd, timeNs, obs, aux] = gracefoReading.internal.parseDataSection( ...
    dataLines, dataLineNos, varNames, varAttrs, fileName, timeVarOpt, ...
    numRecordsHeader, headerLines);
aux.classicHeaderFields = hdrFields;
end
