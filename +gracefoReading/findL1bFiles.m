function [files, report] = findL1bFiles(archiveRoot, product, options)
%FINDL1BFILES  Locate GRACE-FO L1B files in an archive by product and date.
%
%   SYNTAX
%     files = gracefoReading.findL1bFiles(archiveRoot, product)
%     [files, report] = gracefoReading.findL1bFiles(archiveRoot, product, Name, Value)
%
%   DESCRIPTION
%     Searches an archive folder for PO.DAAC-named product files, for
%     example ACT1B_2020-01-03_C_04.txt or the gzipped variant
%     ACT1B_2020-01-03_C_04.txt.gz, sorts them chronologically and
%     reports date coverage including calendar days without a file.
%     Together with readL1bMulti this reduces multi-month batch reading
%     to two lines. Files whose names do not match the PO.DAAC pattern
%     are ignored, and an empty result is returned rather than raised
%     as an error, so the function can be used to probe an archive.
%
%   INPUT
%     archiveRoot - string | char, 1x1
%                Folder to search.
%                Validation: mustBeFolder. Required, positional.
%
%     product - string, 1x1
%                Product identifier as it appears at the start of the
%                file name.
%                Options: "ACT1B", "ACC1B", "SCA1B", "KBR1B", "LRI1B",
%                "GNV1B", "THR1B", "MAS1B", ... Required, positional.
%
%     'DateRange' - datetime, 1x2
%                Inclusive date window; order of the two elements is
%                irrelevant. Also defines the span over which missing
%                days are reported.
%                Default: [] (all dates found).
%
%     'Satellite' - string, 1x1
%                Satellite letter in the file name.
%                Options: "C" | "D" (GRACE-FO 1 and 2), "Y" (dual-
%                satellite products such as KBR1B/LRI1B), "" for any.
%                Default: "" (any satellite).
%
%     'Release' - string, 1x1
%                Release tag in the file name.
%                Options: "04", "03", ... Default: "04".
%
%     'Recursive' - logical, 1x1
%                Search subfolders as well, which suits archives
%                organised by year or month.
%                Options: true | false. Default: true.
%
%   OUTPUT
%     files  - string, [K x 1]
%                Full paths sorted by date and then satellite; empty
%                string array if nothing matches.
%     report - struct, 1x1
%                  dates        datetime [K x 1], date of each file
%                  satellites   string   [K x 1], satellite letters
%                  firstDate    datetime, NaT if no files
%                  lastDate     datetime, NaT if no files
%                  missingDates datetime [D x 1], calendar days with no
%                               file inside [firstDate, lastDate], or
%                               inside 'DateRange' when it is given
%
%   ACCURACY AND LIMITATIONS
%     - Dates come from the file NAME, not from the file content; a
%       misnamed file is placed wrongly. Content dates are available
%       from readL1b via the time output.
%     - Only the PO.DAAC naming convention
%       PROD1B_yyyy-MM-dd_S_RR.txt[.gz] is recognized. Archives using
%       other conventions need their own listing; the resulting string
%       array can be passed to readL1bMulti directly.
%     - Missing-day detection assumes daily files; it is not meaningful
%       for products delivered at another cadence.
%     - Recursive search visits every subfolder of archiveRoot and can
%       be slow on network file systems with very large archives; set
%       'Recursive' to false when the layout is flat.
%     - Duplicates of the same date in different subfolders are all
%       returned; the caller decides which to keep.
%
%   ERRORS
%     (none beyond argument validation; an empty result is not an error)
%
%   EXAMPLES
%     % 1. one month of ACT1B for GRACE-FO 1, then read it
%     files = gracefoReading.findL1bFiles(archive, "ACT1B", ...
%         'DateRange', [datetime(2020,1,1) datetime(2020,1,31)], ...
%         'Satellite', "C");
%     [t, acc, aux] = gracefoReading.readL1bMulti(files);
%
%     % 2. check archive completeness before a long run
%     [~, rep] = gracefoReading.findL1bFiles(archive, "KBR1B", 'Satellite', "Y");
%     fprintf('%s .. %s, %d day(s) missing\n', rep.firstDate, rep.lastDate, ...
%             numel(rep.missingDates));
%
%   See also gracefoReading.readL1bMulti, gracefoReading.readL1b,
%            gracefoReading.findGaps
%
%   Toolbox:  gracefoReading v2.3.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14

arguments
    archiveRoot (1,1) string {mustBeFolder}
    product (1,1) string
    options.DateRange datetime = datetime.empty
    options.Satellite (1,1) string = ""
    options.Release (1,1) string = "04"
    options.Recursive (1,1) logical = true
end

if options.Recursive
    pattern = fullfile(archiveRoot, '**', product + "_*.txt*");
else
    pattern = fullfile(archiveRoot, product + "_*.txt*");
end
d = dir(pattern);
d = d(~[d.isdir]);

% parse names: PROD1B_yyyy-MM-dd_S_RR.txt[.gz]
rx = "^" + product + "_(\d{4}-\d{2}-\d{2})_([A-Z])_(\w+)\.txt(\.gz)?$";
dates = NaT(numel(d), 1);
sats = strings(numel(d), 1);
keep = false(numel(d), 1);
for i = 1:numel(d)
    tok = regexp(d(i).name, rx, 'tokens', 'once');
    if isempty(tok), continue; end
    if options.Satellite ~= "" && ~strcmp(tok{2}, options.Satellite), continue; end
    if ~strcmp(tok{3}, options.Release), continue; end
    dates(i) = datetime(tok{1}, 'InputFormat', 'yyyy-MM-dd');
    sats(i) = string(tok{2});
    keep(i) = true;
end
d = d(keep); dates = dates(keep); sats = sats(keep);

if ~isempty(options.DateRange)
    inRange = dates >= min(options.DateRange) & dates <= max(options.DateRange);
    d = d(inRange); dates = dates(inRange); sats = sats(inRange);
end

% Guard the empty case: char(strings(0,1) + " ") is 0x0, so the sort key
% has a single column and sortrows(..., [1 2]) raises COLmismatchX. The
% documented contract is an empty result, not an error, and the report
% branch below already provides for it.
if ~isempty(d)
    [~, order] = sortrows([datenum(dates), double(char(sats + " "))], [1 2]); %#ok<DATNM>
    d = d(order); dates = dates(order); sats = sats(order);
end

files = strings(numel(d), 1);
for i = 1:numel(d)
    files(i) = string(fullfile(d(i).folder, d(i).name));
end

report = struct();
report.dates = dates;
report.satellites = sats;
if isempty(dates)
    report.firstDate = NaT; report.lastDate = NaT;
    report.missingDates = datetime.empty(0, 1);
else
    report.firstDate = min(dates);
    report.lastDate = max(dates);
    if isempty(options.DateRange)
        span = (report.firstDate : caldays(1) : report.lastDate)';
    else
        span = (dateshift(min(options.DateRange),'start','day') : caldays(1) : ...
                dateshift(max(options.DateRange),'start','day'))';
    end
    report.missingDates = span(~ismember(span, dates));
end
end
