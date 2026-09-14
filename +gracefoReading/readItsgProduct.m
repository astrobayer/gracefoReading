function [time, obs, aux] = readItsgProduct(fileName, options)
%READITSGPRODUCT  Read a TU Graz (ITSG) satellite orbit product.
%
%   SYNTAX
%     [time, obs, aux] = gracefoReading.readItsgProduct(fileName)
%     [time, obs, aux] = gracefoReading.readItsgProduct(fileName, Name, Value)
%
%   DESCRIPTION
%     Reads one operational satellite orbit product published by the
%     Institute of Geodesy, TU Graz, from
%     ftp.tugraz.at/pub/ITSG/satelliteOrbitProducts/, and returns it in
%     the same [time, obs, aux] shape as gracefoReading.readL1b. The
%     products are GROOPS ASCII instrument files, so the parsing is done
%     by gracefoReading.readGroopsInstrument and this function adds what
%     the file itself does not carry.
%
%     Two things it adds are not cosmetic:
%
%     ZERO-PADDED COLUMNS. The GROOPS ORBIT type always writes nine data
%     columns - position, velocity and acceleration. A kinematicOrbit
%     file carries position only, and its six velocity and acceleration
%     columns are identically zero; a reducedDynamicOrbit file carries
%     position and velocity, and its three acceleration columns are
%     identically zero. Returning those zeros as observations would hand
%     a caller a velocity of exactly 0 m/s for every epoch of a kinematic
%     orbit, which differencing or integrating turns into silent nonsense.
%     OBS therefore holds only the columns the product actually carries;
%     the padding is named in aux.paddingColumns and returned untouched
%     in aux.allColumns. Which columns are carried comes from the product
%     documentation, and is CHECKED against the file: a padding column
%     that is not identically zero raises the paddingNotZero warning
%     rather than being quietly dropped.
%
%     FRAME AND TIME SYSTEM. Neither is declared anywhere in these files
%     - no header field, no filename suffix, nothing. They come from the
%     product README instead, which states the frame per product and
%     "All times are GPS times". Because that mapping is keyed on the
%     product, and the product is identified from the file name, aux
%     records not just the answer but how it was reached:
%     aux.frameSource and aux.productSource. An unrecognised product is
%     never given a frame by guesswork - aux.frame stays empty and the
%     productNotRecognised warning fires. The time system is not withheld
%     with it: the README states "All times are GPS times" for the whole
%     product set rather than per product, so aux.timeSystem is 'GPS'
%     either way.
%
%   INPUT
%     fileName - string | char, 1x1
%                Path to an ITSG product file, plain or gzip-compressed
%                (.gz), named <satellite>_<product>_<date>.txt[.gz] as
%                published, e.g. GRACEFO-1_kinematicOrbit_2020-01-01.txt.
%                Validation: mustBeFile. Required, positional.
%
%     'Product' - string, 1x1
%                Override of the product identified from the file name,
%                for a file that has been renamed.
%                Options: "kinematicOrbit", "kinematicOrbitCovariance",
%                "reducedDynamicOrbit", "attitude",
%                "nonConservativeForces".
%                Default: "" (take it from the file name).
%
%     'Frame' - string, 1x1
%                Frame to record in aux.frame, overriding the documented
%                one. Provided so a caller who knows better than this
%                function is never blocked by it; the default is empty
%                rather than a guess, so an omission stays
%                distinguishable from a choice.
%                Default: "" (use the product documentation).
%
%     'TimeFormat' - string, 1x1
%                Representation of the TIME output, matching
%                gracefoReading.readL1b.
%                Options: "mjd" (integer MJD + seconds of day),
%                "datetime" (GPS time scale), "gpsns" (int64 GPS
%                nanoseconds past 2000-01-01 12:00:00).
%                Default: "mjd".
%
%   OUTPUT
%     time - double, [N x 2] | datetime, [N x 1] | int64, [N x 1]
%                Epochs according to 'TimeFormat'. Recovered from the
%                printed digits by integer arithmetic, which matters
%                here: the kinematic products are corrected for receiver
%                clock errors and are NOT on a constant sampling, and
%                their epoch structure is finer than a double can hold.
%     obs  - double, [N x M]
%                The columns the product actually carries, in file
%                order. Column j is named by aux.obsNames{j} and carries
%                the unit aux.obsUnits{j}. Zero-padding columns are NOT
%                included; see DESCRIPTION.
%     aux  - struct, 1x1
%                Fields: product, productSource, satellite, epochDate,
%                frame, frameDescription, frameSource, timeSystem
%                (always 'GPS'), timeSystemSource, obsNames, obsUnits,
%                allColumns, allColumnNames, allColumnUnits, paddingColumns,
%                groopsType, groopsTypeCode, numRecords, fileName,
%                comments, and the full info struct from
%                readGroopsInstrument as aux.groopsInfo.
%
%   ACCURACY AND LIMITATIONS
%     - The frame and the time system are NOT in the file. They are
%       taken from the product README of 2025-10-16 and are therefore
%       only as current as that document; aux.frameSource and
%       aux.timeSystemSource say so rather than presenting them as file
%       content. Verify against the README before a result depends on
%       the frame.
%     - The two are not documented the same way and are not treated the
%       same way here. The time system is stated once for the whole
%       product set - "All times are GPS times" - so aux.timeSystem is
%       'GPS' for every file this function reads, recognised product or
%       not. The frame is stated per product, so an unrecognised product
%       gets no frame at all.
%     - Which columns a product carries is likewise documentation, not
%       file content, but it is verified against the data on every read.
%       The reverse is not checked: a column documented as carried that
%       happens to be all zero in one file is not reported, because a
%       genuinely zero observation is legitimate.
%     - One file per call. Reading a date range means calling this once
%       per file and concatenating; there is no ITSG counterpart to
%       readL1bMulti or findL1bFiles yet (HANDOVER.md, O-9).
%     - No frame rotation and no interpolation are performed, and none
%       are planned here - both are out of scope for this toolbox.
%     - neutralDensity is published by the same server but is not in the
%       product table, because no real file was available to read. It
%       parses as a generic GROOPS file and warns productNotRecognised.
%     - Epoch tags are exact to 1 ns of what the file prints. The files
%       carry 18 decimals of a day, finer than a nanosecond, so the
%       nanosecond outputs round; at most the first 15 decimals are used
%       (86 ps, see readGroopsInstrument).
%
%   ERRORS
%     gracefoReading:readItsgProduct:productNotRecognised
%       (warning) product not identified from the name and not given;
%       no frame is recorded and every column is returned as an
%       observation. The time system is still 'GPS'
%     gracefoReading:readItsgProduct:paddingNotZero
%       (warning) a column the documentation calls zero padding is not
%       identically zero in this file
%     gracefoReading:readItsgProduct:columnCountMismatch
%       the file has fewer columns than the documented product needs
%
%   EXAMPLES
%     % 1. kinematic orbit: three position columns, not nine
%     [t, pos, aux] = gracefoReading.readItsgProduct( ...
%         'GRACEFO-1_kinematicOrbit_2020-01-01.txt');
%     fprintf('%s in the %s frame (%s)\n', strjoin(aux.obsNames, ', '), ...
%         aux.frame, aux.frameSource);
%
%     % 2. exact epochs of a receiver-clock-corrected kinematic orbit
%     tns = gracefoReading.readItsgProduct( ...
%         'GRACEFO-1_kinematicOrbit_2020-01-01.txt.gz', 'TimeFormat', 'gpsns');
%     fprintf('sampling is constant: %d\n', numel(unique(diff(tns))) == 1);
%
%     % 3. a day of orbit and its epoch-wise covariance
%     [tk, pos] = gracefoReading.readItsgProduct('GRACEFO-1_kinematicOrbit_2020-01-01.txt');
%     [tc, cov] = gracefoReading.readItsgProduct( ...
%         'GRACEFO-1_kinematicOrbitCovariance_2020-01-01.txt');
%     % cov columns are xx yy zz xy xz yz in m^2, on the same epochs as pos
%
%   See also gracefoReading.readGroopsInstrument, gracefoReading.readL1b
%
%   Toolbox:  gracefoReading v1.0.2
%   Created:  2026-09-14
%   Updated:  2026-09-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    fileName (1,1) string {mustBeFile}
    options.Product (1,1) string = ""
    options.Frame (1,1) string = ""
    options.TimeFormat (1,1) string ...
        {mustBeMember(options.TimeFormat, ["mjd", "datetime", "gpsns"])} = "mjd"
end

[timeMjd, timeNs, allData, info] = ...
    gracefoReading.internal.parseGroopsInstrument(fileName);

[product, satellite, epochDate] = localIdentify(fileName, options.Product);
spec = localProductTable(product);

aux = struct();
aux.fileName = fileName;
aux.product = product;
if options.Product ~= ""
    aux.productSource = 'option';
else
    aux.productSource = 'fileName';
end
aux.satellite = satellite;
aux.epochDate = epochDate;
aux.groopsType = info.typeName;
aux.groopsTypeCode = info.typeCode;
aux.numRecords = info.numRecords;
aux.comments = info.comments;
aux.groopsInfo = info;
aux.allColumns = allData;
aux.allColumnNames = info.columnNames;
aux.allColumnUnits = info.columnUnits;

nCol = size(allData, 2);
if isempty(spec)
    warning('gracefoReading:readItsgProduct:productNotRecognised', ...
        ['%s: product "%s" is not in the documented table, so no frame is ', ...
         'recorded and all %d column(s) are returned as observations. ', ...
         'Pass ''Product'' or ''Frame'' to say what this file is.'], ...
        fileName, product, nCol);
    carried = 1:nCol;
    aux.frame = '';
    aux.frameDescription = '';
    aux.frameSource = 'undeclared';
else
    if nCol < max(spec.carried)
        error('gracefoReading:readItsgProduct:columnCountMismatch', ...
            ['%s: product "%s" needs at least %d data columns per the product ', ...
             'documentation, but the file has %d.'], ...
            fileName, product, max(spec.carried), nCol);
    end
    carried = spec.carried;
    aux.frame = spec.frame;
    aux.frameDescription = spec.frameDescription;
    if options.Frame ~= ""
        aux.frame = char(options.Frame);
        aux.frameSource = 'option';
    else
        aux.frameSource = 'productDocumentation';
    end
end

padding = setdiff(1:nCol, carried);
aux.paddingColumns = padding;

% Verify the documentation against the data. A padding column that is not
% identically zero means this file is not the product the table says it is,
% which is exactly the case where dropping the column silently would lose
% real data.
if ~isempty(padding)
    nonZero = padding(any(allData(:, padding) ~= 0, 1));
    if ~isempty(nonZero)
        warning('gracefoReading:readItsgProduct:paddingNotZero', ...
            ['%s: column(s) %s are documented as zero padding for product "%s" ', ...
             'but are not identically zero here (largest |value| %.3g). They are ', ...
             'still excluded from OBS; read them from aux.allColumns.'], ...
            fileName, mat2str(nonZero), product, max(abs(allData(:, nonZero)), [], 'all'));
    end
end

obs = allData(:, carried);
aux.obsNames = localPick(info.columnNames, carried, nCol);
aux.obsUnits = localPick(info.columnUnits, carried, nCol);
% GPS for every product this server publishes, not only the recognised ones:
% README_referenceFrames.txt states "All times are GPS times" for the whole
% product set, and README.txt repeats "GPS time" in each per-product column
% table. Only the FRAME is a per-product fact, so only the frame is withheld
% when the product is unknown. Tying the time system to product recognition
% withheld something the documentation actually gives.
aux.timeSystem = 'GPS';
aux.timeSystemSource = 'productDocumentation';
aux.epochDescription = ['GPS time as decimal MJD in the file; the toolbox pair is ' ...
    'integer MJD and seconds of day, the int64 form is nanoseconds past ' ...
    '2000-01-01 12:00:00 GPS'];

time = gracefoReading.internal.formatEpoch(timeMjd, timeNs, options.TimeFormat, 51544);
end

% ========================================================================
function [product, satellite, epochDate] = localIdentify(fileName, override)
%LOCALIDENTIFY  Satellite, product and date from the published file name.
%   The convention itself lives in internal.parseItsgFileName, which
%   findItsgFiles also uses. Only the product may be overridden here,
%   because only the product decides how the columns are read.
[product, satellite, epochDate] = ...
    gracefoReading.internal.parseItsgFileName(fileName);
if override ~= ""
    product = char(override);
end
end

% ========================================================================
function spec = localProductTable(product)
%LOCALPRODUCTTABLE  Columns and frame per product, from the ITSG README.
%   Source: README.txt of the ITSG satelliteOrbitProducts server, revision
%   16 October 2025, plus README_referenceFrames.txt. CARRIED lists the data
%   columns the product actually fills; the GROOPS epoch type may declare
%   more, and the remainder is zero padding. Only products for which a real
%   file has been read are listed - an entry written from the README alone
%   would be the assumption this toolbox has twice paid for.
spec = [];
switch lower(product)
    case 'kinematicorbit'
        spec = localSpec(1:3, 'celestial', ...
            'Position in the celestial (quasi-inertial) reference frame');
    case 'kinematicorbitcovariance'
        spec = localSpec(1:6, 'celestial', ...
            ['3x3 covariance in the celestial reference frame, elements ' ...
             'xx yy zz xy xz yz in m^2']);
    case 'reduceddynamicorbit'
        spec = localSpec(1:6, 'celestial', ...
            'Position and velocity in the celestial (quasi-inertial) reference frame');
    case 'attitude'
        spec = localSpec(1:4, 'satellite->celestial', ...
            ['Quaternion rotating the satellite reference frame into the ' ...
             'celestial reference frame, scalar part first']);
    case 'nonconservativeforces'
        spec = localSpec(1:3, 'satellite', ...
            'Non-conservative accelerations in the satellite reference frame');
end
end

% ========================================================================
function s = localSpec(carried, frame, description)
s = struct('carried', carried, 'frame', frame, 'frameDescription', description);
end

% ========================================================================
function out = localPick(names, idx, nCol)
%LOCALPICK  Column labels for the selected columns, padded when the file
%   carried no legend to name them with.
if numel(names) < nCol
    names = arrayfun(@(k) sprintf('data%d', k-1), 1:nCol, 'UniformOutput', false);
end
out = names(idx);
end
