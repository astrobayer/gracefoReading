function [files, report] = findItsgFiles(archiveRoot, product, options)
%FINDITSGFILES  Locate ITSG product files in an archive by product and date.
%
%   SYNTAX
%     [files, report] = gracefoReading.findItsgFiles(archiveRoot, product)
%     [files, report] = gracefoReading.findItsgFiles(archiveRoot, product, ...
%         Name, Value)
%
%   DESCRIPTION
%     Searches an archive folder, recursively by default, for TU Graz
%     (ITSG) product files named <satellite>_<product>_<date>.txt or
%     .txt.gz, sorts them chronologically and reports the coverage
%     including missing calendar days. With
%     gracefoReading.readItsgProductMulti this turns a month of orbits
%     into two lines. It is the ITSG counterpart of
%     gracefoReading.findL1bFiles and behaves the same way, including
%     returning an empty result rather than an error when nothing
%     matches.
%
%     The product must be given exactly as it appears in the name. The
%     release-1.0 density products are published as neutralDensity_ACC
%     and neutralDensity_KIN, and those are the product names: one is
%     derived from accelerometer data and the other from kinematic
%     orbits, so "neutralDensity" deliberately matches neither.
%
%   INPUT
%     archiveRoot - string | char, 1x1
%                Folder to search.
%                Validation: mustBeFolder. Required, positional.
%     product - string, 1x1
%                Product segment of the file name, e.g. "kinematicOrbit",
%                "reducedDynamicOrbit", "attitude",
%                "kinematicOrbitCovariance", "nonConservativeForces".
%                Required, positional.
%
%     'DateRange' - datetime, 1x2
%                Inclusive date window, compared against the date in the
%                file name.
%                Default: [] (every date found).
%
%     'Satellite' - string, 1x1
%                Satellite segment to keep, e.g. "GRACEFO-1". Compared
%                case-sensitively, as published.
%                Default: "" (any satellite).
%
%     'Recursive' - logical, 1x1
%                Search subfolders. The server lays products out by year,
%                so the default is true.
%                Options: true | false. Default: true.
%
%   OUTPUT
%     files - string, [K x 1]
%                Full paths sorted by date, then by satellite. Empty
%                when nothing matches, which is not an error.
%     report - struct, 1x1
%                  dates        datetime [K x 1], one per file
%                  satellites   string [K x 1]
%                  products     string [K x 1], the product actually
%                               parsed from each name
%                  compressed   logical [K x 1], true for .gz
%                  firstDate    datetime, NaT when empty
%                  lastDate     datetime, NaT when empty
%                  missingDates datetime, calendar days with no file
%                               inside the covered span or 'DateRange'
%
%   ACCURACY AND LIMITATIONS
%     - Only the file name is read. A file whose name does not follow the
%       convention is skipped silently, which is what makes it safe to
%       point this at a folder holding other products too.
%     - A day present as both .txt and .txt.gz is reported twice, once
%       per file. Nothing here decides which of the two to prefer,
%       because either is readable and dropping one would be a guess
%       about which is current.
%     - missingDates counts calendar days, so a genuine gap in the
%       published series is indistinguishable from a file you have not
%       downloaded. It reports what is on disk, not what exists.
%
%   EXAMPLES
%     % 1. a month of kinematic orbits, with coverage
%     [files, report] = gracefoReading.findItsgFiles(root, "kinematicOrbit", ...
%         'DateRange', [datetime(2020,1,1) datetime(2020,1,31)], ...
%         'Satellite', "GRACEFO-1");
%     fprintf('%d file(s), %d day(s) missing\n', ...
%         numel(files), numel(report.missingDates));
%
%     % 2. straight into a concatenated read
%     [t, pos, aux] = gracefoReading.readItsgProductMulti(files);
%
%   See also gracefoReading.readItsgProductMulti,
%            gracefoReading.readItsgProduct, gracefoReading.findL1bFiles
%
%   Toolbox:  gracefoReading v1.4.0
%   Created:  2026-09-14
%   Updated:  2026-09-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    archiveRoot (1,1) string {mustBeFolder}
    product (1,1) string
    options.DateRange datetime = datetime.empty
    options.Satellite (1,1) string = ""
    options.Recursive (1,1) logical = true
end

if options.Recursive
    pattern = fullfile(archiveRoot, '**', "*_" + product + "_*.txt*");
else
    pattern = fullfile(archiveRoot, "*_" + product + "_*.txt*");
end
d = dir(pattern);
d = d(~[d.isdir]);

n = numel(d);
dates = NaT(n, 1);
sats = strings(n, 1);
prods = strings(n, 1);
gz = false(n, 1);
keep = false(n, 1);
for i = 1:n
    % One authority for the convention; a name that does not follow it is
    % simply not an ITSG product file and is skipped.
    [p, s, dt, ok] = gracefoReading.internal.parseItsgFileName(d(i).name);
    if ~ok || ~strcmp(p, product)
        continue
    end
    if options.Satellite ~= "" && ~strcmp(s, options.Satellite)
        continue
    end
    dates(i) = dt;
    sats(i) = string(s);
    prods(i) = string(p);
    gz(i) = endsWith(d(i).name, ".gz", 'IgnoreCase', true);
    keep(i) = true;
end
d = d(keep); dates = dates(keep); sats = sats(keep);
prods = prods(keep); gz = gz(keep);

if ~isempty(options.DateRange)
    inRange = dates >= dateshift(min(options.DateRange), 'start', 'day') & ...
              dates <= dateshift(max(options.DateRange), 'start', 'day');
    d = d(inRange); dates = dates(inRange); sats = sats(inRange);
    prods = prods(inRange); gz = gz(inRange);
end

% Guard the empty case the same way findL1bFiles does: char(strings(0,1)+" ")
% is 0x0, so the sort key loses a column and sortrows raises COLmismatchX.
if ~isempty(d)
    [~, order] = sortrows([datenum(dates), double(char(sats + " "))], [1 2]); %#ok<DATNM>
    d = d(order); dates = dates(order); sats = sats(order);
    prods = prods(order); gz = gz(order);
end

files = strings(numel(d), 1);
for i = 1:numel(d)
    files(i) = string(fullfile(d(i).folder, d(i).name));
end

report = struct();
report.dates = dates;
report.satellites = sats;
report.products = prods;
report.compressed = gz;
if isempty(dates)
    report.firstDate = NaT;
    report.lastDate = NaT;
    report.missingDates = datetime.empty(0, 1);
else
    report.firstDate = min(dates);
    report.lastDate = max(dates);
    if isempty(options.DateRange)
        span = (report.firstDate : caldays(1) : report.lastDate)';
    else
        span = (dateshift(min(options.DateRange), 'start', 'day') : caldays(1) : ...
                dateshift(max(options.DateRange), 'start', 'day'))';
    end
    report.missingDates = span(~ismember(span, dates));
end
end
