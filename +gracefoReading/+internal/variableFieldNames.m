function [fieldNames, adjusted] = variableFieldNames(varNames)
%VARIABLEFIELDNAMES  Unique MATLAB field names for header variable names.
%
%   SYNTAX
%     fieldNames = gracefoReading.internal.variableFieldNames(varNames)
%     [fieldNames, adjusted] = gracefoReading.internal.variableFieldNames(varNames)
%
%   DESCRIPTION
%     SINGLE POINT OF ACCESS for the rule that turns a declared
%     variable name into the struct field that carries its attributes
%     and its auxiliary column. Every producer and every consumer of
%     varAttrs and of the aux struct calls this one function, so the
%     writer and the readers cannot disagree about where a variable's
%     data went.
%
%     The rule is two steps, in this order:
%       1. matlab.lang.makeValidName, truncated to namelengthmax;
%       2. matlab.lang.makeUniqueStrings over the WHOLE ordered list.
%
%     Step 2 exists because step 1 alone is not injective, and real
%     products depend on the difference. The GRACE-FO accelerometer
%     housekeeping product AHK1B declares the sensor temperatures
%     "TSU Y+", "TSU Y-", "TSU Z+" and "TSU Z-" (the last with a space
%     where the others carry an underscore). makeValidName maps "+"
%     and "-" to the same underscore, so the four names collapse onto
%     two fields and two of the four temperature columns would be
%     silently overwritten by the other two. Making the list unique
%     keeps all four reachable, in declaration order.
%
%     Names that are already valid, unique MATLAB identifiers - which
%     is every column of every product read so far - are returned
%     unchanged, so this function is the identity on the existing
%     fixtures. Internal function; the public interface is
%     gracefoReading.readL1b.
%
%   INPUT
%     varNames - cellstr | string, [1 x V] | [V x 1]
%                Declared variable names in file column order;
%                V = number of variables. May be empty.
%                Required, positional.
%
%   OUTPUT
%     fieldNames - cellstr, [1 x V]
%                Valid, unique field names in the same order as
%                varNames. Empty input gives a 1x0 cellstr.
%     adjusted - logical, [1 x V]
%                True where fieldNames{k} differs from varNames{k},
%                that is where the declared name could not be used as
%                a field name verbatim. Callers report this rather
%                than renaming a column in silence.
%
%   ACCURACY AND LIMITATIONS
%     - The mapping is a function of the whole list, not of one name:
%       adding or removing a variable can change the suffix another
%       colliding variable receives. Field names are therefore a
%       per-file detail; aux.variableNames and aux.obsNames keep the
%       declared names and are what a caller should match on.
%     - Uniqueness is resolved in declaration order: the first
%       occurrence keeps the plain name and later ones get the
%       suffix, so a file whose columns are reordered between
%       releases would map differently.
%     - Names longer than namelengthmax (63) are truncated before
%       uniquification; two names sharing their first 63 valid
%       characters therefore differ only by the added suffix.
%
%   EXAMPLE
%     % internal use only; called by parseHeaderVariables and
%     % parseDataSection:
%     [fn, adj] = gracefoReading.internal.variableFieldNames( ...
%         {'gps_time', 'TSU Z+', 'TSU Z-'});
%     % fn(1) is 'gps_time' unchanged; fn(2) and fn(3) are two
%     % DISTINCT valid names, although makeValidName maps both
%     % declared names onto the same one. adj = [false true true].
%     % The exact suffix is makeUniqueStrings' business and is not
%     % promised here - match on varNames, never on a field name.
%
%   See also gracefoReading.readL1b,
%            gracefoReading.internal.parseHeaderVariables,
%            gracefoReading.internal.parseDataSection
%
%   Toolbox:  gracefoReading v1.2.0
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    varNames
end

% Emptiness is tested BEFORE cellstr: parseHeaderVariables hands over a
% 0x0 cell for a header that declares nothing, and cellstr is not
% required to accept it.
if isempty(varNames)
    fieldNames = cell(1, 0);
    adjusted = false(1, 0);
    return
end
names = reshape(cellstr(varNames), 1, []);

valid = matlab.lang.makeValidName(names);
tooLong = cellfun(@(s) numel(s) > namelengthmax, valid);
valid(tooLong) = cellfun(@(s) s(1:namelengthmax), valid(tooLong), ...
    'UniformOutput', false);

% The whole list is offered for renaming, not a subset: uniqueness must
% hold across every variable of the file, and which one keeps the plain
% name is then decided by declaration order rather than by which subset
% a caller happened to pass.
fieldNames = matlab.lang.makeUniqueStrings(valid, 1:numel(valid), namelengthmax);
fieldNames = reshape(fieldNames, 1, []);
adjusted = ~strcmp(fieldNames, names);
end
