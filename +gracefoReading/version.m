function [versionString, info] = version()
%VERSION  Version and release metadata of the gracefoReading toolbox.
%
%   SYNTAX
%     v = gracefoReading.version()
%     [v, info] = gracefoReading.version()
%
%   DESCRIPTION
%     Returns the toolbox version as a semantic version string,
%     allowing downstream scripts and processing chains to assert a
%     minimum version programmatically instead of trusting folder
%     names. The second output adds release metadata. The version
%     string is also part of the cache key used by readL1b, so caches
%     written by an older toolbox are never reused after an upgrade.
%
%   INPUT
%     (none)
%
%   OUTPUT
%     versionString - char, [1 x C]
%                Semantic version, e.g. '2.3.0'.
%     info - struct, 1x1
%                  version       char, same as versionString
%                  date          char, release date 'yyyy-MM-dd'
%                  developedWith char, authorship and model note
%                  license       char, 'MIT'
%
%   ACCURACY AND LIMITATIONS
%     - The version is a literal maintained in this file and mirrored
%       in Contents.m and docsrc/functionSpecs.json; the consistency
%       test testDocConsistency enforces that the three agree. Tests
%       must never pin a version literal themselves, since that breaks
%       on the next bump.
%     - String comparison of semantic versions is lexicographic and
%       only reliable while all components stay single-digit; for
%       robust checks compare the numeric parts, e.g.
%       sscanf(gracefoReading.version(), '%d.%d.%d').
%
%   EXAMPLES
%     % 1. simple assertion in a processing script
%     assert(string(gracefoReading.version()) >= "2.3.0")
%
%     % 2. numeric comparison, robust beyond version 9
%     v = sscanf(gracefoReading.version(), '%d.%d.%d')';
%     assert(v(1) > 2 || (v(1) == 2 && v(2) >= 3))
%
%   See also gracefoReading.readL1b
%
%   Toolbox:  gracefoReading v2.3.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14

versionString = '2.3.0';
info = struct( ...
    'version', versionString, ...
    'date', '2026-08-14', ...
    'developedWith', 'Matthias Weigelt with the help of Anthropic Claude Opus 5', ...
    'license', 'MIT');
end
