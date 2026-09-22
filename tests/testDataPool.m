classdef testDataPool < matlab.unittest.TestCase
%TESTDATAPOOL  Verification of a data pool against published checksums.
%
%   DESCRIPTION
%     Covers gracefoReading.verifyDataPool and the two internal units
%     it stands on, parseChecksumManifest and fileDigest (G-06, issue
%     #21). The pools are synthetic and tiny, but the digests they are
%     checked against are NOT computed by the code under test: the
%     expected values are the published FIPS-180 / RFC-1321 test
%     vectors for the byte string "abc" and the digests of the other
%     fixtures were produced independently, outside MATLAB. An
%     expectation derived from the code it tests proves nothing, and a
%     checksum tool that agrees with itself is exactly the failure
%     this suite has to exclude.
%
%     Run with:
%       results = runtests('testDataPool'); table(results)
%
%   COVERAGE
%     - fileDigest against the published MD5, SHA-1 and SHA-256 test
%       vectors, and against the digest of the empty file
%     - parseChecksumManifest: coreutils text and binary ("*name")
%       lines, BSD tagged lines, comments, blank lines, a leading
%       "./", the algorithm taken from the digest length, a tag that
%       disagrees with its own digest length, and the line numbers of
%       lines matching neither format
%     - verifyDataPool: OK, MISMATCH, MISSING, UNLISTED and
%       UNREADABLE rows; names resolved relative to their own
%       manifest, including a sub-folder; the summary counts and the
%       ok verdict; the verificationFailed warning on a bad pool and
%       its silence on a good one; 'Manifests', 'Recursive' and
%       'ReportUnlisted'; poolNotFound, manifestNotFound and
%       noManifest errors
%
%   ACCURACY AND LIMITATIONS
%     - The fixtures are bytes written here, not real pool files; what
%       is verified is the verification, not any particular product.
%     - Hashing needs the JVM. Under -nojvm the digest points report
%       an assumption failure rather than a wrong answer.
%
%   EXAMPLE
%     results = runtests('testDataPool');
%     disp(table(results));
%
%   Toolbox:  gracefoReading v1.1.0
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

    properties
        workDir
    end

    properties (Constant)
        % Published test vectors, not computed here (see DESCRIPTION).
        MD5_ABC    = "900150983cd24fb0d6963f7d28e17f72"
        SHA1_ABC   = "a9993e364706816aba3e25717850c26c9cd0d89d"
        SHA256_ABC = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        SHA256_EMPTY = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        SHA256_ABCD = "88d4266fd4e6338d13b845fcf289579d209c897823b9217da3e161936f031589"
        SHA256_XYZ = "3608bca1e44ea6c4d268eb6db02260269892c0b42b86bbf1e77a6fa16c3c9282"
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            here = fileparts(mfilename('fullpath'));
            codeDir = fileparts(here);
            if ~any(strcmp(strsplit(path, pathsep), codeDir))
                addpath(codeDir);
                testCase.addTeardown(@() rmpath(codeDir));
            end
        end
    end

    methods (TestMethodSetup)
        function makeWorkDir(testCase)
            testCase.workDir = tempname;
            mkdir(testCase.workDir);
            testCase.addTeardown(@() rmdir(testCase.workDir, 's'));
        end
    end

    methods (Access = private)
        function f = writeBytes(testCase, relName, text)
            % Raw bytes, no newline translation: a published checksum
            % refers to the bytes on disk, so the fixture must control
            % them exactly.
            f = fullfile(testCase.workDir, relName);
            d = fileparts(f);
            if ~isfolder(d), mkdir(d); end
            fid = fopen(f, 'w');
            if ~isempty(text)
                fwrite(fid, text, 'char');
            end
            fclose(fid);
            f = string(f);
        end

        function f = writeLines(testCase, relName, lines)
            % lines(:)' : strjoin wants a row, and every caller here
            % writes its fixture as a column of lines.
            f = testCase.writeBytes(relName, char(strjoin(lines(:)', newline)));
        end
    end

    methods (Test)

        % ---- fileDigest against published vectors ----------------------

        function testDigestMatchesPublishedVectors(testCase)
            f = testCase.writeBytes('abc.bin', 'abc');
            testCase.verifyEqual( ...
                gracefoReading.internal.fileDigest(f, "MD5"), testCase.MD5_ABC);
            testCase.verifyEqual( ...
                gracefoReading.internal.fileDigest(f, "SHA-1"), testCase.SHA1_ABC);
            testCase.verifyEqual( ...
                gracefoReading.internal.fileDigest(f, "SHA-256"), testCase.SHA256_ABC);

            e = testCase.writeBytes('empty.bin', '');
            testCase.verifyEqual( ...
                gracefoReading.internal.fileDigest(e, "SHA-256"), testCase.SHA256_EMPTY);
        end

        function testDigestReportsRatherThanRaises(testCase)
            missing = fullfile(testCase.workDir, 'nothere.bin');
            [d, why] = gracefoReading.internal.fileDigest(missing, "SHA-256");
            testCase.verifyEqual(d, "");
            testCase.verifyGreaterThan(strlength(why), 0);

            f = testCase.writeBytes('abc.bin', 'abc');
            [d2, why2] = gracefoReading.internal.fileDigest(f, "NO-SUCH-DIGEST");
            testCase.verifyEqual(d2, "");
            testCase.verifyTrue(contains(why2, "NO-SUCH-DIGEST"));
        end

        % ---- manifest parsing ------------------------------------------

        function testManifestFormatsParse(testCase)
            m = testCase.writeLines('SHA256SUMS_2020-01.txt', [
                "# a comment line"
                ""
                testCase.SHA256_ABC + "  abc.bin"
                testCase.SHA256_ABCD + " *abcd.bin"
                testCase.SHA256_XYZ + "  ./sub/xyz.bin"
                "SHA256 (tagged.bin) = " + testCase.SHA256_ABC
                "MD5 (small.bin) = " + testCase.MD5_ABC]);

            [e, bad] = gracefoReading.internal.parseChecksumManifest(m);
            testCase.verifyEmpty(bad);
            testCase.verifyEqual(e.name, ["abc.bin"; "abcd.bin"; "sub/xyz.bin"; ...
                                          "tagged.bin"; "small.bin"]);
            testCase.verifyEqual(e.algorithm, ["SHA-256"; "SHA-256"; "SHA-256"; ...
                                               "SHA-256"; "MD5"]);
            testCase.verifyEqual(e.digest(1), testCase.SHA256_ABC);
        end

        function testManifestReportsWhatItCannotRead(testCase)
            m = testCase.writeLines('MANIFEST.sha256', [
                testCase.SHA256_ABC + "  abc.bin"
                "abc.bin 1234 sha256"                 % name-first, with a size
                "SHA256 (odd.bin) = " + testCase.MD5_ABC]);   % tag vs length

            [e, bad] = gracefoReading.internal.parseChecksumManifest(m);
            testCase.verifyEqual(bad, 2, ...
                'The name-first line is the only unparsable one.');
            % the mismatched tag parses but names no algorithm, so the
            % caller can refuse to verify it instead of guessing
            testCase.verifyEqual(e.algorithm(2), "");
        end

        % ---- verifyDataPool --------------------------------------------

        function testGoodPoolVerifiesSilently(testCase)
            testCase.writeBytes('abc.bin', 'abc');
            testCase.writeBytes('sub/xyz.bin', 'xyz');
            testCase.writeLines('SHA256SUMS_2020-01.txt', [
                testCase.SHA256_ABC + "  abc.bin"
                testCase.SHA256_XYZ + "  sub/xyz.bin"]);

            testCase.verifyWarningFree(@() gracefoReading.verifyDataPool( ...
                testCase.workDir, 'ReportUnlisted', false));
            [rep, s] = gracefoReading.verifyDataPool(testCase.workDir, ...
                'ReportUnlisted', false);

            testCase.verifyEqual(height(rep), 2);
            testCase.verifyTrue(all(rep.status == "OK"));
            testCase.verifyTrue(s.ok);
            testCase.verifyEqual(s.numOk, 2);
            testCase.verifyEqual(s.numChecked, 2);
            testCase.verifyEqual(s.numManifests, 1);
        end

        function testBadPoolIsReportedRowByRow(testCase)
            testCase.writeBytes('abc.bin', 'abc');
            testCase.writeBytes('abcd.bin', 'xyz');     % content does not match
            testCase.writeBytes('stray.bin', 'abc');    % no manifest lists it
            testCase.writeLines('SHA256SUMS_2020-01.txt', [
                testCase.SHA256_ABC  + "  abc.bin"
                testCase.SHA256_ABCD + "  abcd.bin"
                testCase.SHA256_XYZ  + "  gone.bin"]);

            testCase.verifyWarning(@() gracefoReading.verifyDataPool(testCase.workDir), ...
                'gracefoReading:verifyDataPool:verificationFailed');

            w = warning('off', 'gracefoReading:verifyDataPool:verificationFailed');
            c = onCleanup(@() warning(w)); %#ok<NASGU>
            [rep, s] = gracefoReading.verifyDataPool(testCase.workDir);

            st = @(n) rep.status(endsWith(rep.file, n));
            testCase.verifyEqual(st("abc.bin"), "OK");
            testCase.verifyEqual(st("abcd.bin"), "MISMATCH");
            testCase.verifyEqual(st("gone.bin"), "MISSING");
            testCase.verifyEqual(st("stray.bin"), "UNLISTED");
            % the manifest itself is data about data, never unlisted data
            testCase.verifyFalse(any(endsWith(rep.file, "SHA256SUMS_2020-01.txt")));

            testCase.verifyFalse(s.ok);
            testCase.verifyEqual([s.numOk, s.numMismatch, s.numMissing, ...
                                  s.numUnlisted], [1, 1, 1, 1]);
            % a mismatch row carries both digests, so the report can be
            % taken back to the source that made the claim
            row = rep(rep.status == "MISMATCH", :);
            testCase.verifyEqual(row.expected, testCase.SHA256_ABCD);
            testCase.verifyEqual(row.actual, testCase.SHA256_XYZ);
            testCase.verifyTrue(endsWith(row.manifest, "SHA256SUMS_2020-01.txt"));
        end

        function testUnknownAlgorithmIsNotVerified(testCase)
            testCase.writeBytes('abc.bin', 'abc');
            testCase.writeLines('SHA256SUMS_2020-01.txt', ...
                "abcdef0123456789abcd  abc.bin");     % 20 hex digits: no algorithm

            testCase.verifyWarning(@() gracefoReading.verifyDataPool( ...
                testCase.workDir, 'ReportUnlisted', false), ...
                'gracefoReading:verifyDataPool:unknownAlgorithm');

            w = warning('off', 'all');
            c = onCleanup(@() warning(w)); %#ok<NASGU>
            [rep, s] = gracefoReading.verifyDataPool(testCase.workDir, ...
                'ReportUnlisted', false);
            testCase.verifyEqual(rep.status, "UNREADABLE");
            testCase.verifyFalse(s.ok, ...
                'An unverifiable file must not count as verified.');
        end

        function testUnparsableManifestLineWarns(testCase)
            testCase.writeBytes('abc.bin', 'abc');
            testCase.writeLines('SHA256SUMS_2020-01.txt', [
                testCase.SHA256_ABC + "  abc.bin"
                "abc.bin 1234 sha256"]);
            testCase.verifyWarning(@() gracefoReading.verifyDataPool( ...
                testCase.workDir, 'ReportUnlisted', false), ...
                'gracefoReading:verifyDataPool:manifestLineUnparsable');
        end

        function testManifestsOptionAndRecursion(testCase)
            testCase.writeBytes('sub/abc.bin', 'abc');
            m = testCase.writeLines('sub/checksum.day.md5', ...
                testCase.MD5_ABC + "  abc.bin");

            % named explicitly: names still resolve against the manifest
            [rep, s] = gracefoReading.verifyDataPool(testCase.workDir, ...
                'Manifests', m, 'ReportUnlisted', false);
            testCase.verifyEqual(rep.status, "OK");
            testCase.verifyEqual(rep.algorithm, "MD5");
            testCase.verifyTrue(s.ok);

            % found by the recursive search as well
            [~, s2] = gracefoReading.verifyDataPool(testCase.workDir, ...
                'ReportUnlisted', false);
            testCase.verifyEqual(s2.numManifests, 1);

            % but not without recursion
            testCase.verifyError(@() gracefoReading.verifyDataPool( ...
                testCase.workDir, 'Recursive', false), ...
                'gracefoReading:verifyDataPool:noManifest');
        end

        function testErrorsForMissingPoolAndManifest(testCase)
            testCase.verifyError(@() gracefoReading.verifyDataPool( ...
                fullfile(testCase.workDir, 'nosuchfolder')), ...
                'gracefoReading:verifyDataPool:poolNotFound');

            testCase.writeBytes('abc.bin', 'abc');
            testCase.verifyError(@() gracefoReading.verifyDataPool( ...
                testCase.workDir, 'Manifests', ...
                fullfile(testCase.workDir, 'nosuch.sha256')), ...
                'gracefoReading:verifyDataPool:manifestNotFound');

            testCase.verifyError(@() gracefoReading.verifyDataPool( ...
                testCase.workDir), ...
                'gracefoReading:verifyDataPool:noManifest');
        end

    end
end
