function [report, summary] = verifyDataPool(poolFolder, options)
%VERIFYDATAPOOL  Verify a data pool against its published checksums.
%
%   SYNTAX
%     report = gracefoReading.verifyDataPool(poolFolder)
%     report = gracefoReading.verifyDataPool(poolFolder, Name, Value)
%     [report, summary] = gracefoReading.verifyDataPool(___)
%
%   DESCRIPTION
%     Checks every file of a local data pool against the checksum its
%     source published, so that a silently truncated download, a
%     half-written copy or a file edited by accident is found before it
%     reaches a processing run rather than after it.
%
%     The pool is searched for checksum manifests (see 'Manifests' for
%     the patterns). Each manifest lists file names relative to its own
%     folder, so the MD5 list that ships inside a daily L1B archive and
%     a SHA-256 manifest written beside a month of data are both read
%     where they lie. Every listed file is hashed with the algorithm
%     the manifest's own digest length implies and compared; every file
%     in the pool that no manifest lists is reported as well, because
%     "not checked" and "checked and correct" are different answers and
%     a report that showed only the second would be read as the first.
%
%     Each row of the report names the manifest that made the claim, so
%     a mismatch can be taken back to its source. Nothing is repaired,
%     deleted or re-downloaded: the function only reports.
%
%   INPUT
%     poolFolder - string | char, 1x1
%                Root of the pool to verify, for example the DATAPOOL
%                root named by READING_DATA_POOL, or one product
%                folder below it.
%                Validation: must be an existing folder.
%                Required, positional.
%
%     'Manifests' - string, [1 x M] | [M x 1]
%                Explicit manifest files, overriding the search. Use
%                this to verify one month against one list instead of
%                walking the whole pool.
%                Options: any readable checksum manifests. When empty,
%                the pool is searched for SHA256SUMS*.txt,
%                MD5SUMS*.txt, MANIFEST.sha256, *.sha256 and *.md5
%                (including the checksum.<kind>.md5 lists of the L1B
%                day archives).
%                Default: string.empty (search the pool).
%
%     'Recursive' - logical, 1x1
%                Search sub-folders for manifests and for unlisted
%                files.
%                Options: true | false. Default: true.
%
%     'ReportUnlisted' - logical, 1x1
%                Add one row per pool file that no manifest lists.
%                Manifests themselves are never reported as unlisted.
%                Options: true | false. Default: true.
%
%     'Progress' - logical, 1x1
%                Print one line per manifest as it is processed. A
%                full DATAPOOL is hashed at disk speed and takes
%                minutes; without this the function looks stuck.
%                Options: true | false. Default: false.
%
%   OUTPUT
%     report - table, [R x 7]
%                One row per checked or unlisted file, in manifest
%                order and then pool order; R = number of rows.
%                Variables:
%                  file       string, full path
%                  manifest   string, the manifest that listed it,
%                             "" for an unlisted file
%                  algorithm  string, "MD5" | "SHA-1" | "SHA-256" |
%                             "SHA-384" | "SHA-512", "" if unlisted
%                  status     string, "OK" | "MISMATCH" | "MISSING" |
%                             "UNREADABLE" | "UNLISTED"
%                  expected   string, digest from the manifest
%                  actual     string, digest computed here
%                  bytes      double, file size, NaN if absent
%     summary - struct, 1x1
%                Fields pool, manifests (string [M x 1]), numManifests,
%                numChecked, numOk, numMismatch, numMissing,
%                numUnreadable, numUnlisted and ok (true only when
%                nothing failed and nothing is missing or unreadable).
%
%   ACCURACY AND LIMITATIONS
%     - A pool is only as verified as its manifests. Sources that
%       publish no checksums at all (measured for the ITSG and ZARM
%       products) produce UNLISTED rows, which is the honest answer:
%       those files are unverified, not verified-good.
%     - Files are hashed byte for byte, so the cost is one full pass
%       over every listed file. Verifying a multi-gigabyte pool is
%       minutes of disk, not seconds; narrow it with 'Manifests' or by
%       pointing poolFolder at one sub-folder.
%     - A manifest entry naming a file outside the pool, or a path that
%       does not exist, is reported MISSING rather than silently
%       dropped.
%     - The same file listed by two manifests gives two rows. That is
%       deliberate: two sources claiming different digests for one file
%       is exactly the state a verification should expose.
%     - Hashing needs the JVM. Under -nojvm every row is UNREADABLE and
%       hashingUnavailable is raised once; no row is reported OK.
%     - The function reports; it never repairs. Deleting or refetching
%       a bad file is a decision for the caller.
%
%   ERRORS
%     gracefoReading:verifyDataPool:poolNotFound
%       poolFolder is not an existing folder
%     gracefoReading:verifyDataPool:manifestNotFound
%       a file named in 'Manifests' does not exist
%     gracefoReading:verifyDataPool:noManifest
%       no manifest was found in the pool and none was given
%
%   WARNINGS
%     gracefoReading:verifyDataPool:verificationFailed  at least one row
%                                                       is not OK
%     gracefoReading:verifyDataPool:manifestLineUnparsable  line matched
%                                                       neither format
%     gracefoReading:verifyDataPool:unknownAlgorithm    digest length
%                                                       names no algorithm
%     gracefoReading:verifyDataPool:hashingUnavailable  no JVM or no
%                                                       such digest
%
%   EXAMPLES
%     % 1. verify the whole pool CI reads from
%     pool = getenv('READING_DATA_POOL');
%     [rep, sum1] = gracefoReading.verifyDataPool(pool, 'Progress', true);
%     disp(rep(rep.status ~= "OK", :));
%     fprintf('%d of %d file(s) verified\n', sum1.numOk, sum1.numChecked);
%
%     % 2. one month, against the manifest written beside it
%     m = fullfile(pool, 'GRACEFO', 'L1B', 'RL04', '2020', ...
%         'SHA256SUMS_2020-01.txt');
%     rep = gracefoReading.verifyDataPool(fileparts(m), 'Manifests', m, ...
%         'ReportUnlisted', false);
%
%     % 3. fail a batch job on the first bad file
%     [~, s] = gracefoReading.verifyDataPool(pool);
%     assert(s.ok, 'Pool %s failed verification: %d mismatch(es).', ...
%         pool, s.numMismatch);
%
%   See also gracefoReading.findL1bFiles, gracefoReading.findItsgFiles,
%            gracefoReading.readL1b
%
%   Toolbox:  gracefoReading v1.3.0
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    poolFolder (1,1) string
    options.Manifests (1,:) string = string.empty
    options.Recursive (1,1) logical = true
    options.ReportUnlisted (1,1) logical = true
    options.Progress (1,1) logical = false
end

if ~isfolder(poolFolder)
    error('gracefoReading:verifyDataPool:poolNotFound', ...
        'Pool folder "%s" does not exist or is not a folder.', poolFolder);
end
poolFolder = string(localFullPath(poolFolder));

manifests = localResolveManifests(poolFolder, options);

file = strings(0, 1); manifestOf = strings(0, 1); algorithm = strings(0, 1);
status = strings(0, 1); expected = strings(0, 1); actual = strings(0, 1);
bytes = zeros(0, 1);
checked = strings(0, 1);            % full paths already covered by a manifest
noJvmReported = false;

for m = 1:numel(manifests)
    mf = manifests(m);
    base = string(fileparts(mf));
    [entries, badLines] = gracefoReading.internal.parseChecksumManifest(mf);
    if ~isempty(badLines)
        warning('gracefoReading:verifyDataPool:manifestLineUnparsable', ...
            ['%d line(s) of %s match neither the "<hex>  <name>" nor the ', ...
             '"ALGO (<name>) = <hex>" format and were skipped: line(s) %s.'], ...
            numel(badLines), mf, strjoin(string(badLines), ', '));
    end
    if options.Progress
        fprintf('%s: %d entry/entries\n', mf, numel(entries.name));
    end

    for e = 1:numel(entries.name)
        target = string(fullfile(base, strrep(entries.name(e), "/", filesep)));
        file(end+1, 1)       = target;                  %#ok<AGROW>
        manifestOf(end+1, 1) = mf;                      %#ok<AGROW>
        algorithm(end+1, 1)  = entries.algorithm(e);    %#ok<AGROW>
        expected(end+1, 1)   = entries.digest(e);       %#ok<AGROW>
        actual(end+1, 1)     = "";                      %#ok<AGROW>
        bytes(end+1, 1)      = NaN;                     %#ok<AGROW>
        checked(end+1, 1)    = lower(target);           %#ok<AGROW>

        if ~isfile(target)
            status(end+1, 1) = "MISSING";               %#ok<AGROW>
            continue
        end
        d = dir(target);
        bytes(end) = d(1).bytes;

        if strlength(entries.algorithm(e)) == 0
            warning('gracefoReading:verifyDataPool:unknownAlgorithm', ...
                ['%s lists %s with a %d-digit digest, which names no known ', ...
                 'algorithm; the file was not verified.'], ...
                mf, entries.name(e), strlength(entries.digest(e)));
            status(end+1, 1) = "UNREADABLE";            %#ok<AGROW>
            continue
        end

        [dig, reason] = gracefoReading.internal.fileDigest( ...
            target, entries.algorithm(e));
        if strlength(dig) == 0
            if ~noJvmReported
                warning('gracefoReading:verifyDataPool:hashingUnavailable', ...
                    'Could not hash %s: %s. Affected files are reported UNREADABLE.', ...
                    target, reason);
                noJvmReported = true;
            end
            status(end+1, 1) = "UNREADABLE";            %#ok<AGROW>
            continue
        end
        actual(end) = dig;
        if dig == entries.digest(e)
            status(end+1, 1) = "OK";                    %#ok<AGROW>
        else
            status(end+1, 1) = "MISMATCH";              %#ok<AGROW>
        end
    end
end

if options.ReportUnlisted
    pool = localPoolFiles(poolFolder, options.Recursive);
    pool = setdiff(pool, manifests, 'stable');          % a manifest is not data
    isNew = ~ismember(lower(pool), checked);
    for k = find(isNew(:))'
        d = dir(pool(k));
        file(end+1, 1)       = pool(k);   %#ok<AGROW>
        manifestOf(end+1, 1) = "";        %#ok<AGROW>
        algorithm(end+1, 1)  = "";        %#ok<AGROW>
        status(end+1, 1)     = "UNLISTED";%#ok<AGROW>
        expected(end+1, 1)   = "";        %#ok<AGROW>
        actual(end+1, 1)     = "";        %#ok<AGROW>
        bytes(end+1, 1)      = d(1).bytes;%#ok<AGROW>
    end
end

report = table(file, manifestOf, algorithm, status, expected, actual, bytes, ...
    'VariableNames', {'file', 'manifest', 'algorithm', 'status', ...
                      'expected', 'actual', 'bytes'});

summary = struct();
summary.pool          = poolFolder;
summary.manifests     = manifests(:);
summary.numManifests  = numel(manifests);
summary.numChecked    = sum(status ~= "UNLISTED");
summary.numOk         = sum(status == "OK");
summary.numMismatch   = sum(status == "MISMATCH");
summary.numMissing    = sum(status == "MISSING");
summary.numUnreadable = sum(status == "UNREADABLE");
summary.numUnlisted   = sum(status == "UNLISTED");
summary.ok = summary.numMismatch == 0 && summary.numMissing == 0 && ...
             summary.numUnreadable == 0;

% An UNLISTED file is not a failure - the source published nothing to
% check it against - so it does not clear summary.ok. It is still said
% out loud, because a pool with no manifest at all would otherwise
% return a clean verdict over nothing.
if ~summary.ok
    warning('gracefoReading:verifyDataPool:verificationFailed', ...
        ['Pool %s: %d of %d checked file(s) verified; %d mismatch(es), ', ...
         '%d missing, %d unreadable (%d unlisted) against %d manifest(s).'], ...
        poolFolder, summary.numOk, summary.numChecked, summary.numMismatch, ...
        summary.numMissing, summary.numUnreadable, summary.numUnlisted, ...
        summary.numManifests);
end
end

% ========================================================================
function manifests = localResolveManifests(poolFolder, options)
% Explicit list, or the documented search patterns over the pool.
if ~isempty(options.Manifests)
    manifests = strings(0, 1);
    for k = 1:numel(options.Manifests)
        if ~isfile(options.Manifests(k))
            error('gracefoReading:verifyDataPool:manifestNotFound', ...
                'Manifest "%s" does not exist.', options.Manifests(k));
        end
        manifests(end+1, 1) = string(localFullPath(options.Manifests(k))); %#ok<AGROW>
    end
    return
end

patterns = ["SHA256SUMS*.txt", "MD5SUMS*.txt", "MANIFEST.sha256", ...
            "*.sha256", "*.md5"];
manifests = strings(0, 1);
for p = 1:numel(patterns)
    if options.Recursive
        hits = dir(fullfile(poolFolder, '**', patterns(p)));
    else
        hits = dir(fullfile(poolFolder, patterns(p)));
    end
    for h = 1:numel(hits)
        if hits(h).isdir, continue; end
        manifests(end+1, 1) = string(fullfile(hits(h).folder, hits(h).name)); %#ok<AGROW>
    end
end
manifests = unique(manifests, 'stable');

if isempty(manifests)
    if options.Recursive
        how = "the pool and its sub-folders";
    else
        how = "the pool folder itself";
    end
    error('gracefoReading:verifyDataPool:noManifest', ...
        ['No checksum manifest found in %s (searched %s for %s). Supply one ', ...
         'with the ''Manifests'' option, or record one beside the data.'], ...
        poolFolder, how, strjoin(patterns, ', '));
end
end

% ========================================================================
function files = localPoolFiles(poolFolder, recursive)
% Every regular file of the pool, as full paths.
if recursive
    hits = dir(fullfile(poolFolder, '**', '*'));
else
    hits = dir(fullfile(poolFolder, '*'));
end
hits = hits(~[hits.isdir]);
if isempty(hits)
    files = strings(0, 1);
    return
end
files = string(fullfile({hits.folder}, {hits.name}))';
end

% ========================================================================
function p = localFullPath(p)
% Absolute path, from dir's own folder field rather than by cd-ing into
% the target: a function that changes the working directory to answer a
% question is one interrupt away from leaving the caller somewhere else.
if isfolder(p)
    info = dir(fullfile(p, '.'));
    if ~isempty(info)
        p = string(info(1).folder);
    end
    return
end
info = dir(p);
if ~isempty(info)
    p = string(fullfile(info(1).folder, info(1).name));
end
end
