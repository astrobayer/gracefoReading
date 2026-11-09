function [time, obs, aux] = readItsgProductMulti(fileNames, options)
%READITSGPRODUCTMULTI  Read and concatenate several ITSG product files.
%
%   SYNTAX
%     [time, obs, aux] = gracefoReading.readItsgProductMulti(fileNames)
%     [time, obs, aux] = gracefoReading.readItsgProductMulti(fileNames, ...
%         Name, Value)
%
%   DESCRIPTION
%     Calls gracefoReading.readItsgProduct on each file - typically
%     consecutive days of one product from
%     gracefoReading.findItsgFiles - and concatenates the results into
%     one continuous record. It is the ITSG counterpart of
%     gracefoReading.readL1bMulti and follows the same rules.
%
%     Three things are refused rather than concatenated, because each
%     would produce a result that looks continuous and is not:
%
%     - Files whose observation columns differ. Stacking a kinematic
%       orbit (3 position columns) on a reduced-dynamic one (6) would
%       silently change what column 4 means partway down the matrix.
%     - Files of different products, even when their column counts
%       happen to agree. This is checked first, because it is the most
%       informative thing to say about a bad list.
%
%     The reference frame is deliberately NOT checked separately. It is
%     derived from the product, and 'Frame' is forwarded to every file,
%     so equal products already mean equal frames; a frame check here
%     could never fire and would be a promise this function cannot keep.
%
%     Epoch order is checked but not enforced: a non-increasing join
%     raises the timeNotMonotonic warning naming the record and the
%     file, because wrong file order and a genuine duplicate day look
%     identical here and only the caller knows which it is.
%
%   INPUT
%     fileNames - string, [1 x K] | cellstr
%                Paths in concatenation order, normally chronological.
%                Each may be plain or gzip-compressed. An empty list
%                raises noFiles rather than returning an ambiguous
%                empty. Required, positional.
%
%     'Product' - string, 1x1
%                Forwarded to readItsgProduct for every file.
%                Default: "" (take it from each file name).
%
%     'Frame' - string, 1x1
%                Forwarded to readItsgProduct for every file.
%                Default: "" (use the product documentation).
%
%     'TimeFormat' - string, 1x1
%                Representation of the TIME output.
%                Options: "mjd", "datetime", "gpsns".
%                Default: "mjd".
%
%   OUTPUT
%     time - double, [N x 2] | datetime, [N x 1] | int64, [N x 1]
%                Concatenated epochs; N is the total record count.
%     obs  - double, [N x M]
%                Concatenated observations, the carried columns only.
%                Zero padding is excluded per file, as in
%                readItsgProduct.
%     aux  - struct, 1x1
%                product, frame, frameDescription, frameSource,
%                timeSystem, timeSystemSource, obsNames, obsUnits,
%                groopsType, groopsTypeCode and epochDescription are
%                taken from the first file and verified against the
%                rest. Per-file: fileNames [K x 1], satellites [K x 1],
%                epochDates [K x 1], recordsPerFile [K x 1],
%                paddingColumns (cell, [K x 1]), numRecords [K x 1].
%                allColumns is NOT concatenated; see LIMITATIONS.
%
%   ACCURACY AND LIMITATIONS
%     - aux.allColumns is deliberately absent. Concatenating it would
%       stack the zero padding into a single matrix and invite exactly
%       the reading readItsgProduct exists to prevent. Read a file on
%       its own when the padding is what you want.
%     - Nothing is interpolated, resampled or gap-filled, and no frame
%       rotation is applied. A gap between files stays a gap; use
%       gracefoReading.findGaps on the result to find it.
%     - The kinematic products are not on a constant sampling by design,
%       so a monotonicity check is the only ordering assertion made. Do
%       not read strict monotonicity as evenly spaced.
%     - Memory is the limit on how many days can be joined: every file
%       is parsed in full before concatenation. A year of 10 s orbits is
%       roughly 3 million records.
%
%   ERRORS
%     gracefoReading:readItsgProductMulti:noFiles
%       the file list is empty
%     gracefoReading:readItsgProductMulti:inconsistentProduct
%       two files are different products
%     gracefoReading:readItsgProductMulti:inconsistentColumns
%       two files of the same product expose different observation
%       columns, which means a malformed or mislabelled archive
%     gracefoReading:readItsgProductMulti:timeNotMonotonic
%       (warning) concatenated epochs are not strictly increasing
%
%   EXAMPLES
%     % 1. a month of kinematic orbits in two lines
%     files = gracefoReading.findItsgFiles(root, "kinematicOrbit", ...
%         'DateRange', [datetime(2020,1,1) datetime(2020,1,31)]);
%     [t, pos, aux] = gracefoReading.readItsgProductMulti(files);
%
%     % 2. exact epochs across the join, then look for gaps
%     tns = gracefoReading.readItsgProductMulti(files, 'TimeFormat', 'gpsns');
%     gaps = gracefoReading.findGaps(tns);
%
%   See also gracefoReading.findItsgFiles, gracefoReading.readItsgProduct,
%            gracefoReading.readL1bMulti, gracefoReading.findGaps
%
%   Toolbox:  gracefoReading v1.4.0
%   Created:  2026-09-14
%   Updated:  2026-09-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    % Deliberately unsized: findItsgFiles returns a [K x 1] column, and a
    % (1,:) declaration would reject exactly the call this function exists
    % to serve. Normalised to a row below.
    fileNames string
    options.Product (1,1) string = ""
    options.Frame (1,1) string = ""
    options.TimeFormat (1,1) string ...
        {mustBeMember(options.TimeFormat, ["mjd", "datetime", "gpsns"])} = "mjd"
end

fileNames = fileNames(:)';
nFiles = numel(fileNames);
if nFiles == 0
    error('gracefoReading:readItsgProductMulti:noFiles', ...
        ['No file names given. An empty list would return an empty result ', ...
         'indistinguishable from a range that excluded everything.']);
end

timeAll = cell(nFiles, 1);
obsAll = cell(nFiles, 1);
auxAll = cell(nFiles, 1);
for i = 1:nFiles
    [timeAll{i}, obsAll{i}, auxAll{i}] = gracefoReading.readItsgProduct( ...
        fileNames(i), 'Product', options.Product, 'Frame', options.Frame, ...
        'TimeFormat', options.TimeFormat);
end

ref = auxAll{1};
for i = 2:nFiles
    % Product first: it is the most informative thing to say, and the frame
    % follows from it, so a separate frame check could never fire. 'Frame'
    % and 'Product' are forwarded to every file, so equal products here mean
    % equal frames by construction rather than by luck.
    localAssertSame({ref.product}, {auxAll{i}.product}, ...
        'inconsistentProduct', 'product', fileNames, i);
    localAssertSame(ref.obsNames, auxAll{i}.obsNames, ...
        'inconsistentColumns', 'observation columns', fileNames, i);
end

time = vertcat(timeAll{:});
obs = vertcat(obsAll{:});

localCheckMonotonic(time, timeAll, fileNames);

aux = struct();
aux.product          = ref.product;
aux.frame            = ref.frame;
aux.frameDescription = ref.frameDescription;
aux.frameSource      = ref.frameSource;
aux.timeSystem       = ref.timeSystem;
aux.timeSystemSource = ref.timeSystemSource;
aux.epochDescription = ref.epochDescription;
aux.obsNames         = ref.obsNames;
aux.obsUnits         = ref.obsUnits;
aux.groopsType       = ref.groopsType;
aux.groopsTypeCode   = ref.groopsTypeCode;
aux.fileNames        = fileNames(:);
aux.satellites       = string(cellfun(@(a) a.satellite, auxAll, 'UniformOutput', false));
% Built by loop: cellfun cannot return a datetime with UniformOutput true,
% and MATLAB does not allow {:} indexing straight off a function result.
epochDates = NaT(nFiles, 1);
for i = 1:nFiles
    epochDates(i) = auxAll{i}.epochDate;
end
aux.epochDates       = epochDates;
aux.recordsPerFile   = cellfun(@(o) size(o, 1), obsAll);
aux.numRecords       = cellfun(@(a) a.numRecords, auxAll);
aux.paddingColumns   = cellfun(@(a) a.paddingColumns, auxAll, 'UniformOutput', false);
end

% ========================================================================
function localAssertSame(refVal, val, id, what, fileNames, i)
%LOCALASSERTSAME  Refuse a join that would change meaning partway down.
if ~isequal(refVal, val)
    error(['gracefoReading:readItsgProductMulti:', id], ...
        ['File %d of %d ("%s") differs from the first file in its %s. ', ...
         'Concatenating would change what a column means at an unmarked ', ...
         'row, so the files are not joined.'], ...
        i, numel(fileNames), fileNames(i), what);
end
end

% ========================================================================
function localCheckMonotonic(time, timeAll, fileNames)
%LOCALCHECKMONOTONIC  Warn, naming the record and the file it came from.
%   Warn rather than error: wrong file order and a duplicated day look
%   identical from here and only the caller knows which it is.
if isdatetime(time)
    t = time(:);
elseif isinteger(time)
    t = time(:);
elseif size(time, 2) == 2
    % Offset from the first day before scaling. Absolute MJD seconds reach
    % 5e9, where a double resolves about a microsecond and the sub-microsecond
    % structure of the kinematic products would vanish into the rounding.
    t = (time(:,1) - time(1,1)) * 86400 + time(:,2);
else
    t = time(:);
end
bad = find(diff(t) <= 0, 1);
if isempty(bad)
    return
end
% Locate the file the offending record came from, so the message names
% something the caller can act on rather than a global row number.
edges = cumsum(cellfun(@(x) size(x, 1), timeAll));
fileIdx = find(edges >= bad + 1, 1);
warning('gracefoReading:readItsgProductMulti:timeNotMonotonic', ...
    ['Concatenated epochs are not strictly increasing at record %d ', ...
     '(file %d of %d: "%s"). Check the file order and look for a ', ...
     'duplicated day.'], bad + 1, fileIdx, numel(fileNames), ...
    fileNames(min(fileIdx, numel(fileNames))));
end
