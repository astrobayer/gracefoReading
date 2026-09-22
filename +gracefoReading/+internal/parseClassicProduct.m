function [timeMjd, timeNs, obs, aux] = parseClassicProduct(lines, hdrEnd, ...
    fileName, timeVarOpt, columnNames)
%PARSECLASSICPRODUCT  Parse a classic GRACE (2002-2017) Level-1B ASCII product.
%
%   SYNTAX
%     [timeMjd, timeNs, obs, aux] = gracefoReading.internal.parseClassicProduct( ...
%         lines, hdrEnd, fileName, timeVarOpt, columnNames)
%
%   DESCRIPTION
%     Classic GRACE ASCII headers are "KEY : VALUE" lines
%     terminated by "END OF HEADER" and, unlike GRACE-FO YAML headers,
%     do not declare their data columns. Column layouts therefore come
%     from built-in per-product tables or from the caller. The record
%     section is parsed by the same validated engine as the modern
%     products. Internal function - the public interface is
%     gracefoReading.readL1b, which warns only when the CALLER supplies
%     the layout.
%
%     Built-in layouts: ACC1B, SCA1B, GNV1B, KBR1B, THR1B, MAS1B,
%     MAG1B and AHK1B, taken from gracefoReading.internal.classicLayout
%     - the same table the binary path uses. Any other classic product
%     requires explicit column names.
%
%     The ASCII variant is NOT simply those columns as text, which is
%     why the order comes from layout.asciiNames and not layout.names:
%     MAG1B prints GRACE_id before time_ref, and AHK1B writes `status`
%     as bit characters. Both were measured against the JPL read
%     software's own Bin2AsciiLevel1 output; neither could have been
%     inferred from the binary record.
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
layout = struct();
if ~isempty(columnNames)
    varNames = cellstr(columnNames);
else
    layout = gracefoReading.internal.classicLayout(product);
    if isempty(fieldnames(layout))
        error('gracefoReading:readL1b:unsupportedClassicProduct', ...
            ['No classic column layout for product "%s" (known: ACC1B, ', ...
             'SCA1B, GNV1B, KBR1B, THR1B, MAS1B, MAG1B, AHK1B). Supply ', ...
             'the layout via the ''ColumnNames'' option.'], product);
    end
    % The ASCII order, NOT the binary one: MAG1B prints GRACE_id
    % before time_ref. classicLayout is the single point of access
    % for that difference.
    varNames = layout.asciiNames;
end

% Same field-name rule as the YAML path: 'ColumnNames' is caller-supplied
% and may hold anything, and parseDataSection looks the attributes up by
% the field name this call produces.
classicFields = gracefoReading.internal.variableFieldNames(varNames);
varAttrs = struct();
charCols = {'GRACE_id', 'GRACEFO_id', 'coord_ref', 'time_ref'};
for k = 1:numel(varNames)
    fn = classicFields{k};
    a = struct();
    if isempty(fieldnames(layout))
        % caller-supplied names: fall back to the known character ones
        if any(strcmpi(varNames{k}, charCols)), a.units = 'char'; end
    else
        j = find(strcmp(layout.names, varNames{k}), 1);
        if ~isempty(j) && strcmp(layout.types{j}, 'char')
            a.units = 'char';
        end
        if any(strcmp(layout.asciiBitString, varNames{k}))
            a.bitStringNumeric = true;
        end
    end
    % Classic split time tags are documented in microseconds, and the
    % suffix is what says so: THR1B/MAS1B/MAG1B call theirs time_frac,
    % AHK1B calls its rcvtime_frac because it shares the ACC1A record.
    % Missing this defaults the scale to 1 and puts the epochs out by
    % a factor of a million, silently.
    if endsWith(lower(varNames{k}), '_frac')
        a.units = 'microseconds';
    end
    varAttrs.(fn) = a;
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
