function [time, obs, aux] = readL1b(fileName, options)
%READL1B  Read one GRACE-FO or classic GRACE Level-1B ASCII product file.
%
%   SYNTAX
%     [time, obs, aux] = gracefoReading.readL1b(fileName)
%     [time, obs, aux] = gracefoReading.readL1b(fileName, Name, Value)
%
%   DESCRIPTION
%     Reads any GRACE-FO Level-1B RL04 ASCII product (ACC1B/ACT1B,
%     SCA1B, KBR1B, LRI1B, GNV1B, THR1B, MAS1B, ...). These products
%     share one structure: a YAML header terminated by
%     "# End of YAML header" whose "variables:" list declares every
%     data column in order, followed by whitespace-delimited records.
%     The reader is driven entirely by the file's own header, so no
%     release-dependent column tables are hard-coded.
%
%     Handled automatically:
%       - single (gps_time) and split (time_intg + time_frac) time tags
%         with unit-aware fractional scaling, read from each file's own
%         header rather than assumed per product family: microseconds
%         in the real IHK1B/MAS1B/THR1B/TNK1B files, nanoseconds in
%         MAG1B,
%       - bit-string flag columns (qualflg, prod_flag) preserved as
%         character bit patterns and decoded into logical bit matrices,
%       - prod_flag-controlled variable-length records (MAS1B, and the
%         accelerometer housekeeping product AHK1B, whose declared
%         columns are present per record exactly where their bit is
%         set); absent values are returned as NaN,
%       - declared names that are not MATLAB identifiers, such as
%         AHK1B's "TSU Z-": the aux field is renamed under the
%         variableNameAdjusted warning and stays distinct from its
%         siblings, rather than colliding with them,
%       - a trailing free-text column that the header declares as the
%         remaining portion of each record (LHK1B's sensorname): it
%         absorbs the rest of the line, spaces and all, instead of
%         being counted as extra columns,
%       - gzip-compressed input (.gz), decompressed in memory,
%       - strict row-integrity checking with exact line-number reports,
%       - optional content-hashed caching of parsed results.
%
%     Classic GRACE (2002-2017) files, whose headers are "KEY : VALUE"
%     records terminated by "END OF HEADER", are detected
%     automatically, and so is the variant: the header's own
%     "FILE FORMAT 0=BINARY 1=ASCII" record decides whether the data
%     section is packed big-endian binary or whitespace-separated
%     text. Classic headers do not declare their columns, so the
%     layout comes from a per-product table - measured on real RL02
%     files for the binary variant, inferred from it for the ASCII one
%     - or from the 'ColumnNames' option (ASCII only). See ACCURACY
%     AND LIMITATIONS for what that distinction means.
%
%   INPUT
%     fileName - string | char, 1x1
%                Path to a Level-1B ASCII product file, plain or
%                gzip-compressed (.gz).
%                Validation: mustBeFile. Required, positional.
%
%     'TimeVariable' - string, 1x1
%                Override of the automatic time-tag detection: one
%                variable name, or two joined by '+', e.g.
%                "time_intg+time_frac".
%                Options: any variable name declared in the header.
%                Default: "" (automatic detection).
%
%     'TimeRange' - double, 1x2 | datetime, 1x2
%                Inclusive epoch window. Doubles are interpreted as
%                decimal MJD, datetimes on the GPS time scale.
%                Default: [] (no restriction).
%
%     'TimeFormat' - string, 1x1
%                Representation of the TIME output.
%                Options: "mjd" (integer MJD + seconds of day),
%                "datetime" (GPS time scale), "gpsns" (int64 GPS
%                nanoseconds past 2000-01-01 12:00:00).
%                Default: "mjd".
%
%     'ApplyQualityFlags' - logical, 1x1
%                If true, every record whose qualflg has ANY bit set is
%                removed; the number removed is reported in
%                aux.numRecordsFlagged. Mutually exclusive with
%                'QualityBitMask'.
%                Options: true | false. Default: false.
%
%     'QualityBitMask' - double, 1xQ
%                Selective alternative to 'ApplyQualityFlags': removes
%                records where any of the LISTED qualflg bits is set.
%                Bit numbering is 0-based, bit 0 = rightmost character
%                of the bit string. Bits beyond the flag width are
%                ignored.
%                Options: non-negative integers. Default: [] (off).
%
%     'CacheDir' - string, 1x1
%                Directory for content-hashed .mat parse caches,
%                created if it does not exist. The cache key is the
%                SHA-256 digest of file content + toolbox version +
%                'TimeVariable' + 'ColumnNames'; TimeRange, TimeFormat
%                and quality filtering are applied after loading, so
%                one entry serves every combination of them.
%                Default: "" (caching disabled).
%
%     'ColumnNames' - string, 1xC
%                Classic-format files only: explicit column names in
%                file order, overriding the built-in layout. Ignored
%                for YAML-header files, which declare their own.
%                Default: [] (use the built-in layout table).
%
%   OUTPUT
%     time - double, [N x 2] | datetime, [N x 1] | int64, [N x 1]
%                Epochs according to 'TimeFormat': [N x 2] integer MJD
%                and seconds of day (default), datetime on the GPS time
%                scale, or int64 GPS nanoseconds. GRACE(-FO) time tags
%                count continuous GPS seconds past 2000-01-01 12:00:00
%                with no leap seconds; the MJD split uses floor/mod
%                arithmetic.
%     obs  - double, [N x M]
%                Observation columns: numeric variables that are not
%                time tags, not char-typed, not bit-string flags and
%                not "_id" identifiers. Column j corresponds to
%                aux.obsNames{j}; values absent because of prod_flag
%                are NaN.
%     aux  - struct, 1x1
%                Metadata and non-observation columns. Fields:
%                obsNames, variableNames, variableFieldNames,
%                variableUnits, variableAttributes, timeVariable,
%                timeSystem, epochDescription, epochMJD,
%                numRecordsHeader, numRecordsActual,
%                numRecordsFlagged, header, product, fileName,
%                headerFormat ('yaml' | 'classic'), cacheHit
%                (logical), classicHeaderFields (classic only),
%                qualflg / qualflgBits, prod_flag / prodFlagBits, and
%                one field per further auxiliary column.
%                variableFieldNames gives, per declared variable, the
%                aux field that carries it; it equals variableNames
%                except where a declared name is not a valid or unique
%                MATLAB field name. See the HTML reference page for
%                the full table.
%
%   ACCURACY AND LIMITATIONS
%     - Time in the default "mjd" format is a double pair; around
%       MJD 58849 the seconds-of-day double resolves about 2e-11 s, so
%       the L1B time tags are represented without loss at both
%       quantizations in use: microsecond, and the nanosecond tags of
%       MAG1B, which 2e-11 s still resolves about fifty times over. The "gpsns" format is exact integer arithmetic
%       and is the recommended handoff to nanosecond pipelines, since a
%       single double cannot hold 2020-era GPS nanoseconds (~6.3e17 >
%       2^53) without rounding.
%     - Values are converted with str2double, i.e. to the nearest
%       double; the ASCII products carry fewer significant digits than
%       a double, so no precision is lost relative to the file.
%     - Quality filtering removes whole records; it does not repair or
%       interpolate. Gaps that result are reported by
%       gracefoReading.findGaps, not by this function.
%     - Classic GRACE (2002-2017) comes in two variants, and they are
%       NOT on the same footing:
%         BINARY (the ".dat" files, header "FILE FORMAT ... : 0") is
%         read from a MEASURED layout and does not warn. ACC1B, SCA1B,
%         GNV1B, KBR1B, THR1B and MAS1B were derived from real RL02
%         files of 2008-01-01 and each checked against a physical
%         quantity it must reproduce; classic MAG1B and AHK1B are
%         refused, because their structure is known but their column
%         names and per-bit value types are not. The layouts hold for
%         release 03 as well as 02: SCA1B and KBR1B, the only products
%         RL03 publishes, were checked against real RL03 files.
%         ASCII (the ".asc" files) still WARNS. Its columns are taken
%         to be those measured on the binary variant of the same
%         product, which is an inference and not a measurement: no
%         real classic ASCII file has been read here.
%       Classic qualflg was the open question and is now answered: the
%       binary files store it as a single BYTE bitmask, which the
%       reader renders as the same 8-character bit string the GRACE-FO
%       products use, so decodeQualFlags works on both unchanged.
%     - Binary classic products are read; binary GRACE-FO products are
%       not, there being none in the ASCII releases this toolbox reads.
%     - Caching trusts the SHA-256 content digest; if no JVM is
%       available the digest cannot be computed and the file is parsed
%       normally after a cacheUnavailable warning.
%
%     - A record may carry MORE whitespace-separated tokens than the
%       header declares variables only when the last declared variable
%       says so itself, in its comment or long_name, as LHK1B's
%       sensorname does ("Entire remaining portion of each record").
%       That column then takes the rest of the line verbatim,
%       internal spacing included, and is returned as text in aux.
%       Every other surplus token is still columnMismatch with its
%       line number, and a record SHORT of the declared count is an
%       error either way. The rule is the header's sentence, never the
%       column's position, and it does not apply to a file that also
%       declares prod_flag.
%
%   ERRORS
%     gracefoReading:readL1b:badHeader            no recognized header end marker
%     gracefoReading:readL1b:binaryNotSupported   binary-format file
%     gracefoReading:readL1b:noVariables          no variables declared
%     gracefoReading:readL1b:noTime               no time tag identified
%     gracefoReading:readL1b:timeVariableNotFound 'TimeVariable' not in header
%     gracefoReading:readL1b:unknownFracUnit      unsupported time_frac unit
%     gracefoReading:readL1b:columnMismatch       row-integrity violation
%     gracefoReading:readL1b:noData               no data records
%     gracefoReading:readL1b:conflictingQualityOptions
%                                                 both quality options given
%     gracefoReading:readL1b:unsupportedClassicProduct
%                                                 classic file without a known
%                                                 layout and no 'ColumnNames'
%     gracefoReading:readL1b:classicRecordMismatch
%                                                 classic binary record length
%                                                 disagrees with the file
%     gracefoReading:readL1b:columnNamesNotForBinary
%                                                 'ColumnNames' given for a
%                                                 classic BINARY product
%     gracefoReading:readL1b:fileUnreadable       file could not be opened
%     gracefoReading:readL1b:badClassicType       unknown classic field type
%
%   WARNINGS
%     gracefoReading:readL1b:recordCountMismatch  header/actual count differ
%     gracefoReading:readL1b:cacheUnavailable     hashing failed; parsed fresh
%     gracefoReading:readL1b:classicExperimental  classic ASCII layout
%                                                 inferred from the binary one
%     gracefoReading:readL1b:variableNameAdjusted declared variable name
%                                                 not usable as a struct
%                                                 field; aux field renamed
%
%   EXAMPLES
%     % 1. plain read of one daily accelerometer file
%     [t, acc, aux] = gracefoReading.readL1b('ACT1B_2020-01-01_C_04.txt');
%     plot(t(:,2)/3600, acc(:, strcmp(aux.obsNames,'lin_accl_x')));
%
%     % 2. exact int64 nanoseconds, cached, selective flag filtering
%     [tns, m, aux] = gracefoReading.readL1b('MAS1B_2020-01-01_C_04.txt', ...
%         'TimeFormat', 'gpsns', 'QualityBitMask', [6 7], ...
%         'CacheDir', 'l1bcache');
%
%     % 3. one hour of a gzipped KBR1B file as datetime
%     [t, kbr] = gracefoReading.readL1b('KBR1B_2020-01-01_Y_04.txt.gz', ...
%         'TimeFormat', 'datetime', ...
%         'TimeRange', [datetime(2020,1,1,0,0,0), datetime(2020,1,1,1,0,0)]);
%
%   See also gracefoReading.readL1bMulti, gracefoReading.findGaps,
%            gracefoReading.findL1bFiles, gracefoReading.decodeQualFlags,
%            gracefoReading.checkQuaternionNorm,
%            gracefoReading.writeGroopsInstrument,
%            gracefoReading.readGroopsInstrument, gracefoReading.version
%
%   Toolbox:  gracefoReading v1.1.0
%   Created:  2026-08-01
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    fileName (1,1) string {mustBeFile}
    options.TimeVariable (1,1) string = ""
    options.TimeRange = []
    options.TimeFormat (1,1) string {mustBeMember(options.TimeFormat, ["mjd","datetime","gpsns"])} = "mjd"
    options.ApplyQualityFlags (1,1) logical = false
    options.QualityBitMask (1,:) double {mustBeInteger, mustBeNonnegative} = []
    options.CacheDir (1,1) string = ""
    options.ColumnNames (1,:) string = string.empty
end

if options.ApplyQualityFlags && ~isempty(options.QualityBitMask)
    error('gracefoReading:readL1b:conflictingQualityOptions', ...
        ['Specify either ''ApplyQualityFlags'' (all bits) or ', ...
         '''QualityBitMask'' (selected bits), not both.']);
end

% ---- read file (gzip-aware) -------------------------------------------
% Bytes, not text, and then char() over the bytes. The classic GRACE
% products are BINARY after an ASCII header, and a char read applies the
% file encoding: an arbitrary byte sequence is not valid UTF-8, so bytes
% would be replaced or merged and the records destroyed - silently,
% because the ASCII header would still look perfectly readable.
% char() of a uint8 row maps each byte to the same code point, so the
% text paths below see exactly what they saw before.
rawBytes = gracefoReading.internal.readBytesMaybeGz(fileName);
rawText = char(rawBytes);

% ---- cache lookup ------------------------------------------------------
cacheFile = "";
if options.CacheDir ~= ""
    key = gracefoReading.internal.contentHash(rawText, ...
        gracefoReading.version(), char(options.TimeVariable), ...
        strjoin(options.ColumnNames, ','));
    if key == ""
        warning('gracefoReading:readL1b:cacheUnavailable', ...
            'Content hashing unavailable (no JVM?); parsing without cache.');
    else
        if ~isfolder(options.CacheDir), mkdir(options.CacheDir); end
        cacheFile = fullfile(options.CacheDir, "gracefoReading_" + key + ".mat");
    end
end

if cacheFile ~= "" && isfile(cacheFile)
    S = load(cacheFile, 'timeMjd', 'timeNs', 'obs', 'aux');
    timeMjd = S.timeMjd; timeNs = S.timeNs; obs = S.obs; aux = S.aux;
    aux.fileName = fileName;      % cache may have been written elsewhere
    aux.cacheHit = true;
else
    [timeMjd, timeNs, obs, aux] = localParse(rawText, rawBytes, fileName, ...
        options.TimeVariable, options.ColumnNames);
    aux.cacheHit = false;
    if cacheFile ~= ""
        save(cacheFile, 'timeMjd', 'timeNs', 'obs', 'aux');
    end
end
nRec = size(timeMjd, 1);

% ---- quality filtering -------------------------------------------------
keep = true(nRec, 1);
if isfield(aux, 'qualflgBits')
    if options.ApplyQualityFlags
        keep = ~any(aux.qualflgBits, 2);
    elseif ~isempty(options.QualityBitMask)
        cols = options.QualityBitMask + 1;
        cols = cols(cols <= size(aux.qualflgBits, 2));
        keep = ~any(aux.qualflgBits(:, cols), 2);
    end
    aux.numRecordsFlagged = nnz(~keep);
end

% ---- time-range filtering ---------------------------------------------
if ~isempty(options.TimeRange)
    tr = options.TimeRange;
    if isdatetime(tr)
        trMjd = aux.epochMJD + (seconds(tr - datetime(2000,1,1,0,0,0)) / 86400);
    else
        trMjd = double(tr);
    end
    tDec = timeMjd(:,1) + timeMjd(:,2) / 86400;
    keep = keep & tDec >= min(trMjd) & tDec <= max(trMjd);
end

if ~all(keep)
    timeMjd = timeMjd(keep, :);
    timeNs  = timeNs(keep, :);
    obs = obs(keep, :);
    aux = gracefoReading.internal.filterAuxRecords(aux, keep, nRec);
end

% ---- output time format ------------------------------------------------
time = gracefoReading.internal.formatEpoch(timeMjd, timeNs, ...
    options.TimeFormat, aux.epochMJD);
end

% ========================================================================
function [timeMjd, timeNs, obs, aux] = localParse(rawText, rawBytes, fileName, ...
    timeVarOpt, columnNames)
% The YAML marker is searched in the FIRST part of the file only for the
% classic test below; a binary data section can contain any byte
% sequence, including one that looks like a marker, so the classic
% branch is decided by the header's own FILE FORMAT field rather than by
% what the bytes further down happen to spell.
lines = splitlines(string(rawText));

yamlEnd = find(contains(lines, "End of YAML header"), 1);
classicEnd = find(strtrim(lines) == "END OF HEADER", 1);

if ~isempty(yamlEnd) && (isempty(classicEnd) || yamlEnd < classicEnd)
    [timeMjd, timeNs, obs, aux] = gracefoReading.internal.parseYamlProduct( ...
        lines, yamlEnd, fileName, timeVarOpt);
    aux.headerFormat = 'yaml';
elseif ~isempty(classicEnd)
    % Looked up by the key the header actually prints, not by a
    % sanitised field name: makeValidName rewrites
    % "FILE FORMAT 0=BINARY 1=ASCII" in a way that is its business, not
    % this dispatch's, and getting it wrong would silently route a
    % binary file through the text parser.
    [~, hdrKeys, hdrValues] = ...
        gracefoReading.internal.parseClassicHeader(lines(1:classicEnd));
    iFmt = find(startsWith(hdrKeys, "FILE FORMAT"), 1);
    isBinary = ~isempty(iFmt) && str2double(hdrValues(iFmt)) == 0;
    if isBinary
        if ~isempty(columnNames)
            error('gracefoReading:readL1b:columnNamesNotForBinary', ...
                ['%s is a classic BINARY product; its record layout is a ', ...
                 'sequence of typed fields, so ''ColumnNames'' cannot ', ...
                 'describe it. Names come from the measured layout table.'], ...
                fileName);
        end
        [timeMjd, timeNs, obs, aux] = gracefoReading.internal.parseClassicBinary( ...
            rawBytes, fileName, timeVarOpt);
        aux.headerFormat = 'classicBinary';
    else
        warning('gracefoReading:readL1b:classicExperimental', ...
            ['Classic GRACE ASCII header detected in %s. The ASCII variant ', ...
             'is still read with column layouts that have NOT been validated ', ...
             'against a real ASCII file - only the BINARY variant was ', ...
             'measured (G-02). Verify results or supply ''ColumnNames''. ', ...
             'See HANDOVER.md.'], fileName);
        [timeMjd, timeNs, obs, aux] = gracefoReading.internal.parseClassicProduct( ...
            lines, classicEnd, fileName, timeVarOpt, columnNames);
        aux.headerFormat = 'classic';
    end
else
    error('gracefoReading:readL1b:badHeader', ...
        ['No "# End of YAML header" (GRACE-FO) or "END OF HEADER" ', ...
         '(classic GRACE) marker found in %s; not a supported L1B ASCII product.'], fileName);
end
end
