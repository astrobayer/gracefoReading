function [gaps, stats] = findGaps(time, options)
%FINDGAPS  Detect sampling gaps and contiguous segments in an L1B time series.
%
%   SYNTAX
%     [gaps, stats] = gracefoReading.findGaps(time)
%     [gaps, stats] = gracefoReading.findGaps(time, Name, Value)
%
%   DESCRIPTION
%     Analyses the epoch spacing of a time series read with
%     gracefoReading.readL1b or readL1bMulti and reports every gap
%     exceeding Tolerance times the nominal sampling interval, together
%     with the contiguous segments between the gaps. Downstream
%     processing - filtering, arc segmentation, differentiation -
%     requires contiguous data, so this moves a routine and
%     error-prone preprocessing step into tested code. All three
%     readL1b time formats are accepted and produce identical results;
%     gap epochs are always reported as MJD and seconds of day.
%
%   INPUT
%     time - double, [N x 2] | datetime, [N x 1] | int64, [N x 1]
%                Epochs as returned by readL1b: [N x 2] integer MJD and
%                seconds of day, datetime on the GPS time scale, or
%                int64 GPS nanoseconds past 2000-01-01 12:00:00. Must
%                be sorted ascending.
%                Required, positional.
%
%     'NominalRate' - double, 1x1
%                Nominal sampling interval in seconds (e.g. 1 for
%                ACT1B, 5 for KBR1B, 2 for LRI1B, 3600 for MAS1B).
%                Options: any positive value, or NaN to estimate the
%                rate as the median of the epoch differences.
%                Default: NaN (estimate from the data).
%
%     'Tolerance' - double, 1x1
%                A step dt counts as a gap when
%                dt > Tolerance * NominalRate.
%                Options: any positive value; 1.5 tolerates jitter of
%                half a sampling interval.
%                Default: 1.5.
%
%   OUTPUT
%     gaps  - table, [G x 8]
%                One row per detected gap, variables:
%                  indexBefore    double, record index before the gap
%                  indexAfter     double, record index after the gap
%                  mjdBefore      double, integer MJD of last record
%                  secBefore      double, seconds of day of last record
%                  mjdAfter       double, integer MJD of next record
%                  secAfter       double, seconds of day of next record
%                  durationSec    double, gap length in seconds
%                  missingRecords double, round(durationSec/rate) - 1
%                Empty table (G = 0) if the series is contiguous.
%     stats - struct, 1x1
%                  n              double, epochs analysed
%                  nominalRate    double, sampling interval used [s]
%                  rateEstimated  logical, true if estimated from data
%                  numGaps        double, height(gaps)
%                  totalMissing   double, sum of missingRecords
%                  longestGapSec  double, 0 if no gaps
%                  segments       double [G+1 x 2], first and last
%                                 record index of each contiguous
%                                 segment
%
%   ACCURACY AND LIMITATIONS
%     - Differences are formed relative to the first epoch in double
%       precision. Over a one-day series the resolution is better than
%       1e-9 s, far below any physically meaningful gap, so the double
%       reduction is harmless even for int64 input.
%     - Automatic rate estimation uses the median difference and
%       therefore requires that most steps are nominal; for series
%       dominated by gaps, pass 'NominalRate' explicitly.
%     - missingRecords is a count derived from the assumed constant
%       rate, rounded and floored at 1; it is an estimate, not a
%       statement about which epochs the data centre actually intended
%       to deliver.
%     - Duplicate epochs (dt = 0) are not gaps and are not reported
%       here; use the monotonicity warning of readL1bMulti.
%     - The input must be sorted; unsorted input raises an error rather
%       than being silently sorted, since sorting would break the
%       correspondence to obs.
%
%   ERRORS
%     gracefoReading:findGaps:notSorted     time not ascending
%     gracefoReading:findGaps:badTimeFormat unrecognized time layout
%
%   EXAMPLES
%     % 1. automatic rate detection on a KBR1B day (5 s nominal)
%     [t, kbr] = gracefoReading.readL1b('KBR1B_2020-01-01_Y_04.txt');
%     [gaps, stats] = gracefoReading.findGaps(t);
%     fprintf('%d gap(s), %d record(s) missing\n', stats.numGaps, stats.totalMissing);
%
%     % 2. process each contiguous segment separately
%     [~, stats] = gracefoReading.findGaps(t, 'NominalRate', 5);
%     for s = 1:size(stats.segments, 1)
%         idx = stats.segments(s,1):stats.segments(s,2);
%         processSegment(t(idx,:), kbr(idx,:));
%     end
%
%   See also gracefoReading.readL1b, gracefoReading.readL1bMulti
%
%   Toolbox:  gracefoReading v1.3.2
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    time
    options.NominalRate (1,1) double = NaN
    options.Tolerance (1,1) double {mustBePositive} = 1.5
end

[mjd, sec] = localToMjdPair(time);
n = numel(mjd);

% seconds relative to first epoch (double is exact enough for gap logic)
tRel = (mjd - mjd(1)) * 86400 + (sec - sec(1));
dt = diff(tRel);
if any(dt < 0)
    error('gracefoReading:findGaps:notSorted', ...
        'Time series is not sorted ascending (first decrease at record %d).', ...
        find(dt < 0, 1) + 1);
end

rate = options.NominalRate;
rateEstimated = false;
if isnan(rate)
    rate = median(dt);
    rateEstimated = true;
end

isGap = dt > options.Tolerance * rate;
idxB = find(isGap);
durationSec = dt(idxB);
missing = max(round(durationSec / rate) - 1, 1);

gaps = table(idxB(:), idxB(:) + 1, ...
    mjd(idxB(:)), sec(idxB(:)), mjd(idxB(:)+1), sec(idxB(:)+1), ...
    durationSec(:), missing(:), ...
    'VariableNames', {'indexBefore','indexAfter','mjdBefore','secBefore', ...
                      'mjdAfter','secAfter','durationSec','missingRecords'});

segStart = [1; idxB(:) + 1];
segEnd   = [idxB(:); n];

stats = struct();
stats.n             = n;
stats.nominalRate   = rate;
stats.rateEstimated = rateEstimated;
stats.numGaps       = height(gaps);
stats.totalMissing  = sum(gaps.missingRecords);
if stats.numGaps > 0, stats.longestGapSec = max(gaps.durationSec);
else,                 stats.longestGapSec = 0; end
stats.segments      = [segStart, segEnd];
end

function [mjd, sec] = localToMjdPair(time)
epochMJD = 51544;
if isdatetime(time)
    s = seconds(time(:) - datetime(2000,1,1,0,0,0));
    d = floor(s / 86400);
    mjd = epochMJD + d;
    sec = s - d * 86400;
elseif isinteger(time) && isa(time, 'int64') && (isvector(time) || isempty(time))
    % exact split: seconds and nanosecond remainder
    si = idivide(time(:), int64(1e9), 'floor');
    ns = time(:) - si * int64(1e9);
    tot = double(si) + 43200 + double(ns) * 1e-9;
    d = floor(tot / 86400);
    mjd = epochMJD + d;
    sec = tot - d * 86400;
elseif isnumeric(time) && size(time, 2) == 2
    mjd = double(time(:, 1));
    sec = double(time(:, 2));
else
    error('gracefoReading:findGaps:badTimeFormat', ...
        ['TIME must be [N x 2] (MJD, seconds of day), datetime [N x 1], ', ...
         'or int64 GPS nanoseconds [N x 1].']);
end
end
