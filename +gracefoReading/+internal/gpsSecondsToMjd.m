function [timeMjd, timeNs, mjdEpoch] = gpsSecondsToMjd(intSeconds, fracSeconds)
%GPSSECONDSTOMJD  GPS seconds past the 2000 epoch to MJD pair and int64 ns.
%
%   SYNTAX
%     [timeMjd, timeNs] = ...
%         gracefoReading.internal.gpsSecondsToMjd(intSeconds, fracSeconds)
%     [timeMjd, timeNs, mjdEpoch] = ...
%         gracefoReading.internal.gpsSecondsToMjd(intSeconds, fracSeconds)
%
%   DESCRIPTION
%     SINGLE POINT OF ACCESS for the epoch arithmetic of this toolbox.
%     Both L1B record parsers - the header-driven ASCII one and the
%     classic binary one - convert their time tags here, so the
%     formula exists once. The 2026-09-14 record states why: the
%     datetime epoch formula was once about to live in two files, and
%     a divergence would shift every epoch of one reader with nothing
%     visible to say so.
%
%     The GRACE and GRACE-FO products share one epoch: GPS seconds
%     counted from 2000-01-01 12:00:00, which is MJD 51544.5. The
%     integer and fractional parts are kept apart on purpose. The
%     nanosecond output is formed by integer arithmetic from the
%     integer second, never by scaling the sum, because a 2020-era
%     GPS-nanosecond value is about 6.3e17 and past the 2^53 where a
%     double still counts integers exactly.
%
%   INPUT
%     intSeconds - double | int32 | int64, [N x 1]
%                Whole GPS seconds past the epoch; N = records.
%                Required, positional.
%     fracSeconds - double, [N x 1]
%                Fractional part IN SECONDS, already scaled by the
%                caller from whatever unit the file declares. Pass
%                zeros for a product whose tag is a whole second.
%                Required, positional.
%
%   OUTPUT
%     timeMjd - double, [N x 2]
%                Integer MJD in column 1, seconds of day in column 2.
%     timeNs - int64, [N x 1]
%                Exact GPS nanoseconds past 2000-01-01 12:00:00.
%     mjdEpoch - double, 1x1
%                The integer MJD the epoch falls in, 51544. Returned
%                rather than written out again by each caller: the
%                number belongs to the formula, and a second copy is
%                a second thing to get wrong.
%
%   ACCURACY AND LIMITATIONS
%     - timeNs is exact to the nanosecond for any fracSeconds that is
%       itself exact to the nanosecond; the rounding is a single
%       round() of the fractional part alone.
%     - timeMjd column 2 is a double and carries about 0.2 microsecond
%       of resolution at a day boundary. Callers needing more use the
%       "gpsns" time format, which returns timeNs untouched.
%     - No leap seconds: the scale is GPS throughout, as the products
%       are.
%
%   EXAMPLE
%     % internal use only; called by the record parsers:
%     [mjd, ns] = gracefoReading.internal.gpsSecondsToMjd( ...
%         252417600, 0);         % 2008-01-01 00:00:00 GPS -> MJD 54466
%
%   See also gracefoReading.readL1b,
%            gracefoReading.internal.parseDataSection,
%            gracefoReading.internal.formatEpoch
%
%   Toolbox:  gracefoReading v1.3.2
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    intSeconds (:,1)
    fracSeconds (:,1) double
end

mjdEpoch = 51544;
timeNs = int64(intSeconds) * 1000000000 + int64(round(fracSeconds * 1e9));

gpsSeconds = double(intSeconds) + fracSeconds;
totalSec = gpsSeconds + 43200;           % epoch is noon, not midnight
daysFull = floor(totalSec / 86400);
secOfDay = totalSec - daysFull * 86400;
timeMjd = [mjdEpoch + daysFull, secOfDay];
end
