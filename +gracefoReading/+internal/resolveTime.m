function [timeColIdx, timeVarUsed, fracScale] = resolveTime(varNames, varAttrs, ...
    override, fieldNames)
%RESOLVETIME  Identify the time-tag column or columns of an L1B product.
%
%   SYNTAX
%     [timeColIdx, timeVarUsed, fracScale] = ...
%         gracefoReading.internal.resolveTime(varNames, varAttrs, ...
%             override, fieldNames)
%
%   DESCRIPTION
%     Shared by the YAML and classic parsing paths. Automatic detection
%     prefers a single gps_time column, then a single rcv_time column
%     (CLK1B), then the known split pairs time_intg+time_frac,
%     rcvtime_intg+rcvtime_frac and gps_intg+gps_frac; an explicit
%     override takes precedence. The
%     scale of the fractional column is derived from its declared unit,
%     which matters because the real THR1B and MAS1B files give the
%     fraction in microseconds while a naive reader would assume
%     seconds. Internal function - the public interface is
%     gracefoReading.readL1b.
%
%   INPUT
%     varNames - cellstr, [1 x V]
%                Declared variable names in column order.
%                Required, positional.
%     varAttrs - struct, 1x1
%                Per-variable attributes; the units attribute of the
%                fractional column determines fracScale.
%                Required, positional.
%     override - string, 1x1
%                Explicit time variable.
%                Options: "" for automatic detection, one variable
%                name, or two joined by '+' such as
%                "time_intg+time_frac".
%                Default: "" (set by the caller readL1b).
%     fieldNames - cellstr, [1 x V]
%                The varAttrs field name of each variable, from
%                gracefoReading.internal.variableFieldNames. Passed in
%                rather than recomputed so the attribute of the
%                fractional column is looked up under exactly the key
%                the header parser wrote it under.
%                Required, positional.
%
%   OUTPUT
%     timeColIdx - double, [1 x 1] or [1 x 2]
%                Column index of the single time tag, or the indices of
%                the integer and fractional columns.
%     timeVarUsed - char, [1 x C]
%                Name actually used, e.g. 'gps_time' or
%                'time_intg+time_frac'; stored in aux.timeVariable.
%     fracScale - double, 1x1
%                Seconds per unit of the fractional column: 1 for
%                seconds, 1e-3 for milliseconds, 1e-6 for
%                microseconds, 1e-9 for nanoseconds. Returns 1 for
%                single-column time tags.
%
%   ACCURACY AND LIMITATIONS
%     - Only the two single-column names and the three known split-pair
%       conventions are detected automatically; any other tag must be
%       given via the override.
%     - rcv_time is RECEIVER time, not GPS time: CLK1B's own header says
%       "GPS Time = rcv_time + eps_time". The tag is returned as it is
%       written, like every other tag; aux.timeVariable names it, and
%       applying eps_time is the caller's step. aux.timeSystem reads
%       'GPS' for every YAML product, the receiver-time tags included
%       (rcv_time here, rcvtime_intg+rcvtime_frac elsewhere); it names
%       the counting convention, not the clock. Before rcv_time was
%       recognised, CLK1B raised noTime (issue #29).
%     - Unit strings are matched case-insensitively against the
%       singular and plural forms of second, millisecond, microsecond
%       and nanosecond; anything else raises unknownFracUnit rather
%       than being guessed, because a wrong scale would corrupt every
%       epoch. The refusal is deliberate and must stay: a fallback of
%       s = 1 on an unrecognised unit would have put MAG1B epochs out
%       by nine orders of magnitude with nothing visible to say so.
%     - Which unit each product declares is a property of the file, not
%       of the product family. Across GRACE-C RL04, MAG1B is the only
%       product declaring nanoseconds; IHK1B, MAS1B, THR1B and TNK1B
%       declare microseconds; the remaining products carry no time_frac
%       at all. Do not infer a unit from a sibling product.
%     - The scale is applied as fracScale*frac, and the exact int64
%       nanosecond path of parseDataSection then recovers the integer
%       by round(fracSec*1e9). That round trip was checked exhaustively
%       over the full declared valid_range of every supported unit
%       (0 to 999999999 for nanoseconds): zero mismatches, so 'gpsns'
%       stays exact for MAG1B as it is for the microsecond products.
%     - A fractional column without a declared unit is assumed to be in
%       seconds, following the YAML default.
%
%   ERRORS
%     gracefoReading:readL1b:noTime                no time tag identified
%     gracefoReading:readL1b:timeVariableNotFound  override not in header
%     gracefoReading:readL1b:unknownFracUnit       unsupported fraction unit
%
%   EXAMPLE
%     % internal use only; called by parseDataSection:
%     [idx, name, scale] = gracefoReading.internal.resolveTime( ...
%         varNames, varAttrs, "");
%
%   See also gracefoReading.readL1b, gracefoReading.internal.parseDataSection
%
%   Toolbox:  gracefoReading v1.2.0
%   Created:  2026-08-01
%   Updated:  2026-09-27
%   Author:   Matthias Weigelt with support of Anthropic Claude

fracScale = 1;
if override ~= ""
    parts = strtrim(split(override, '+'));
    idx = zeros(1, numel(parts));
    for p = 1:numel(parts)
        i = find(strcmpi(varNames, parts(p)), 1);
        if isempty(i)
            error('gracefoReading:readL1b:timeVariableNotFound', ...
                'TimeVariable "%s" not found among header variables: %s', ...
                override, strjoin(varNames, ', '));
        end
        idx(p) = i;
    end
    timeColIdx = idx;
    timeVarUsed = char(strjoin(varNames(idx), '+'));
    if numel(idx) == 2
        fracScale = localFracScale(varAttrs, fieldNames{idx(2)}, varNames{idx(2)});
    end
    return
end
% One-column tags, in order of preference: gps_time (GPS time), then
% rcv_time, the integer receiver-time second CLK1B declares
% ("Seconds past 12:00:00 noon of January 1, 2000 in Receiver Time").
for single = {'gps_time', 'rcv_time'}
    i = find(strcmpi(varNames, single{1}), 1);
    if ~isempty(i)
        timeColIdx = i; timeVarUsed = varNames{i};
        return
    end
end
pairs = {{'time_intg','time_frac'}, {'rcvtime_intg','rcvtime_frac'}, {'gps_intg','gps_frac'}};
for p = 1:numel(pairs)
    i1 = find(strcmpi(varNames, pairs{p}{1}), 1);
    i2 = find(strcmpi(varNames, pairs{p}{2}), 1);
    if ~isempty(i1) && ~isempty(i2)
        timeColIdx = [i1, i2];
        timeVarUsed = sprintf('%s+%s', varNames{i1}, varNames{i2});
        fracScale = localFracScale(varAttrs, fieldNames{i2}, varNames{i2});
        return
    end
end
error('gracefoReading:readL1b:noTime', ...
    'Could not identify a time tag column among: %s', strjoin(varNames, ', '));
end

function s = localFracScale(varAttrs, fracField, fracName)
a = varAttrs.(fracField);
unit = 'seconds';
if isfield(a, 'units'), unit = lower(a.units); end
switch unit
    case {'second','seconds'},           s = 1;
    case {'millisecond','milliseconds'}, s = 1e-3;
    case {'microsecond','microseconds'}, s = 1e-6;
    case {'nanosecond','nanoseconds'},   s = 1e-9;   % MAG1B (issue #9)
    otherwise
        error('gracefoReading:readL1b:unknownFracUnit', ...
            'Unsupported fractional-time unit "%s" for variable %s.', unit, fracName);
end
end
