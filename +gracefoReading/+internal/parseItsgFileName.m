function [product, satellite, epochDate, ok] = parseItsgFileName(fileName)
%PARSEITSGFILENAME  Split an ITSG product file name into its three parts.
%
%   SYNTAX
%     [product, satellite, epochDate, ok] = ...
%         gracefoReading.internal.parseItsgFileName(fileName)
%
%   DESCRIPTION
%     The ITSG server publishes every product as
%     <satellite>_<product>_<yyyy-mm-dd>.txt, optionally gzip-compressed,
%     a convention stated in its README. This function is the single
%     place that knows it. gracefoReading.readItsgProduct uses it to
%     decide how a file's columns are read, and
%     gracefoReading.findItsgFiles uses it to decide which files in an
%     archive belong to a product and a date range. Two copies of a
%     naming rule is the failure this repository has already paid for
%     (HANDOVER.md, the 2026-09-06 entry), so there is one.
%
%     A trailing variant marker stays with the product: the release-1.0
%     density files are named neutralDensity_ACC and neutralDensity_KIN,
%     and those come back as the product rather than being split off or
%     silently dropped. They are genuinely different products - one is
%     derived from accelerometer data and one from kinematic orbits - so
%     asking for "neutralDensity" does not match either of them.
%
%   INPUT
%     fileName - string, 1x1
%                Path or bare name; only the name is inspected, and a
%                ".gz" suffix is stripped before matching.
%                Required, positional.
%
%   OUTPUT
%     product - char, [1 x C]
%                Product segment, e.g. 'kinematicOrbit'. '' when the
%                name does not follow the convention.
%     satellite - char, [1 x C]
%                Satellite segment, e.g. 'GRACEFO-1'. '' when the name
%                does not follow the convention.
%     epochDate - datetime, 1x1
%                Date segment. NaT when the name does not follow the
%                convention.
%     ok - logical, 1x1
%                Whether the name matched. Returned so callers can
%                decide what to do about a name that did not, rather
%                than inferring it from an empty product.
%
%   ACCURACY AND LIMITATIONS
%     - The satellite segment is whatever precedes the product, so a
%       name with extra leading underscores would put them there. No
%       published ITSG name does; the segment is not validated against
%       a list of satellites, because that list would be a second thing
%       to keep current.
%     - Only the name is read. Nothing here opens the file, so a file
%       that has been renamed is described by its new name - which is
%       why readItsgProduct offers a 'Product' override.
%
%   EXAMPLE
%     % internal use only; called by readItsgProduct and findItsgFiles:
%     [p, s, d, ok] = gracefoReading.internal.parseItsgFileName( ...
%         'GRACEFO-1_kinematicOrbit_2020-01-01.txt.gz');
%     % p = 'kinematicOrbit', s = 'GRACEFO-1', d = 01-Jan-2020, ok = true
%
%   See also gracefoReading.readItsgProduct, gracefoReading.findItsgFiles
%
%   Toolbox:  gracefoReading v1.3.2
%   Created:  2026-09-14
%   Updated:  2026-09-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    fileName (1,1) string
end

[~, base, ext] = fileparts(fileName);
if strcmpi(ext, '.gz')
    [~, base] = fileparts(base);
end

tok = regexp(char(base), '^(.+?)_(.+?)_(\d{4}-\d{2}-\d{2})$', 'tokens', 'once');
if isempty(tok)
    product = '';
    satellite = '';
    epochDate = NaT;
    ok = false;
    return
end
satellite = tok{1};
product = tok{2};
epochDate = datetime(tok{3}, 'InputFormat', 'yyyy-MM-dd');
ok = true;
end
