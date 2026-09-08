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
%   Toolbox:  gracefoReading v1.0.1
%   Created:  2026-08-01
%   Updated:  2026-09-06
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14

headerLines = cellstr(lines(1:hdrEnd));

% parse KEY : VALUE pairs
hdrFields = struct();
for i = 1:hdrEnd-1
    tok = regexp(headerLines{i}, '^([A-Z0-9][A-Z0-9 ()\-/\.]*?)\s*:\s*(.*\S)\s*$', 'tokens', 'once');
    if ~isempty(tok)
        key = matlab.lang.makeValidName(lower(strtrim(tok{1})));
        hdrFields.(key) = strtrim(tok{2});
    end
end

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
    layout = localBuiltinLayout(product);
    if isempty(layout)
        error('gracefoReading:readL1b:unsupportedClassicProduct', ...
            ['No built-in classic column layout for product "%s" ', ...
             '(built-in: ACC1B, SCA1B, KBR1B, GNV1B). Supply the layout ', ...
             'via the ''ColumnNames'' option.'], product);
    end
    varNames = layout;
end

% attributes: units 'char' for the known character columns
charCols = {'GRACE_id', 'GRACEFO_id', 'coord_ref', 'time_ref'};
varAttrs = struct();
for k = 1:numel(varNames)
    fn = matlab.lang.makeValidName(varNames{k});
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

function names = localBuiltinLayout(product)
% ASSUMED from the GRACE Level-1B handbook — unvalidated (EXPERIMENTAL).
switch upper(product)
    case 'ACC1B'
        names = {'gps_time','GRACE_id', ...
                 'lin_accl_x','lin_accl_y','lin_accl_z', ...
                 'ang_accl_x','ang_accl_y','ang_accl_z','qualflg'};
    case 'SCA1B'
        names = {'gps_time','GRACE_id','sca_id', ...
                 'quatangle','quaticoeff','quatjcoeff','quatkcoeff', ...
                 'qual_rss','qualflg'};
    case 'KBR1B'
        names = {'gps_time','biased_range','range_rate','range_accl', ...
                 'iono_corr','lighttime_corr','lighttime_rate','lighttime_accl', ...
                 'ant_centr_corr','ant_centr_rate','ant_centr_accl', ...
                 'K_A_SNR','Ka_A_SNR','K_B_SNR','Ka_B_SNR','qualflg'};
    case 'GNV1B'
        names = {'gps_time','GRACE_id','coord_ref', ...
                 'xpos','ypos','zpos','xpos_err','ypos_err','zpos_err', ...
                 'xvel','yvel','zvel','xvel_err','yvel_err','zvel_err','qualflg'};
    otherwise
        names = {};
end
end
