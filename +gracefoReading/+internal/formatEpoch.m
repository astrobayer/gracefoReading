function time = formatEpoch(timeMjd, timeNs, timeFormat, epochMjd)
%FORMATEPOCH  Render parsed epochs in the requested output format.
%
%   SYNTAX
%     time = gracefoReading.internal.formatEpoch(timeMjd, timeNs, ...
%         timeFormat, epochMjd)
%
%   DESCRIPTION
%     Shared by every reader that offers the 'TimeFormat' option, so the
%     mapping from a parsed epoch to the three published representations
%     is defined once. Callers parse epochs into the two exact forms the
%     toolbox carries internally - a double [MJD, seconds of day] pair
%     and an int64 nanosecond count - and this function selects between
%     them. It performs no arithmetic on the nanosecond count, which is
%     what keeps "gpsns" exact: the int64 value is handed through
%     untouched rather than rebuilt from the double pair.
%
%     The function exists because the datetime formula was previously
%     written out at each call site. Two copies of an epoch origin is
%     the failure mode this repository has already paid for once (see
%     the 2026-09-06 entry in HANDOVER.md); a divergence between them
%     would shift every epoch of one reader with nothing visible to say
%     so. Internal function - the public interfaces are
%     gracefoReading.readL1b and gracefoReading.readGroopsInstrument.
%
%   INPUT
%     timeMjd - double, [N x 2]
%                Integer MJD in column 1, seconds of day in column 2.
%                Required, positional.
%     timeNs - int64, [N x 1]
%                Exact GPS nanoseconds past 2000-01-01 12:00:00,
%                returned unchanged for the "gpsns" format.
%                Required, positional.
%     timeFormat - string, 1x1
%                Requested representation.
%                Options: "mjd", "datetime", "gpsns". Any other value
%                yields the "mjd" default, because callers validate the
%                option with mustBeMember before calling.
%                Required, positional.
%     epochMjd - double, 1x1
%                MJD of 2000-01-01 00:00:00, i.e. 51544. Passed in
%                rather than hardcoded so the origin keeps one
%                authority in the calling reader.
%                Required, positional.
%
%   OUTPUT
%     time - double, [N x 2] | datetime, [N x 1] | int64, [N x 1]
%                Epochs in the requested representation: the unchanged
%                [MJD, seconds of day] pair, a datetime on the GPS time
%                scale, or the unchanged int64 nanosecond count.
%
%   ACCURACY AND LIMITATIONS
%     - "gpsns" is exact: the int64 argument is passed through without
%       arithmetic, so no rounding is introduced here. Whether it is
%       exact with respect to the file is the calling parser's claim,
%       not this function's.
%     - "datetime" is built from the double pair and inherits its
%       resolution. MATLAB datetime holds milliseconds as a double, so
%       around MJD 58849 it resolves roughly 0.2 microseconds - ample
%       for 1 Hz products, but not a substitute for "gpsns" when
%       nanoseconds matter.
%     - The GPS time scale carries no leap seconds; the returned
%       datetime is therefore GPS time, not UTC, and is not tagged with
%       a time zone.
%
%   EXAMPLE
%     % internal use only; called by readL1b after parsing:
%     time = gracefoReading.internal.formatEpoch(timeMjd, timeNs, ...
%         "gpsns", 51544);
%
%   See also gracefoReading.readL1b, gracefoReading.readGroopsInstrument
%
%   Toolbox:  gracefoReading v1.3.2
%   Created:  2026-09-14
%   Updated:  2026-09-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

switch timeFormat
    case "datetime"
        time = datetime(2000, 1, 1, 0, 0, 0) ...
             + days(timeMjd(:,1) - epochMjd) + seconds(timeMjd(:,2));
    case "gpsns"
        time = timeNs;
    otherwise
        time = timeMjd;
end
end
