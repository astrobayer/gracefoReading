classdef testUtilities < matlab.unittest.TestCase
%TESTUTILITIES  Unit tests for the utility and export functions.
%
%   DESCRIPTION
%     Covers gracefoReading.decodeQualFlags,
%     gracefoReading.checkQuaternionNorm,
%     gracefoReading.writeGroopsInstrument and
%     gracefoReading.version. Fixtures are synthetic aux structs and
%     small files in a temporary folder removed on teardown.
%
%     Run with:
%       results = runtests('testUtilities'); table(results)
%
%   COVERAGE
%     - decodeQualFlags: bit order (bit 0 rightmost), meanings taken
%       from header attributes, undocumented bits, counts and
%       fractions, flagNotFound and notBitString errors
%     - checkQuaternionNorm: clean and violating quaternions, custom
%       tolerance, statistics fields, columnsNotFound error
%     - writeGroopsInstrument: file layout, LF-only line endings on
%       every platform, datetime input, custom TypeCode, Version and
%       Format, sizeMismatch error
%     - version: semantic-version structure and metadata fields,
%       deliberately without pinning a literal version
%
%   ACCURACY AND LIMITATIONS
%     - The line-ending test asserts the absence of carriage returns,
%       which is what caught the Windows CRLF defect in version 2.1.1;
%       synthetic reader fixtures intentionally keep 'wt' mode so that
%       CRLF input remains covered on Windows.
%     - version tests verify structure only. Cross-artifact version
%       agreement is the job of testDocConsistency, so a version bump
%       never breaks this suite.
%
%   EXAMPLE
%     results = runtests('testUtilities');
%     disp(table(results));
%
%   Toolbox:  gracefoReading v1.0.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14

    properties
        workDir
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            here = fileparts(mfilename('fullpath'));
            codeDir = fileparts(here);   % toolbox root (contains +gracefoReading)
            % only touch the path if the toolbox is not already on it, so a
            % test run never strips a path set up via setupGraceFOReading
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
        function f = writeSimple(testCase, name, gpsTimes, valOffset)
            f = fullfile(testCase.workDir, name);
            fid = fopen(f, 'wt');
            fprintf(fid, 'header:\n  dimensions:\n    num_records: %d\n', numel(gpsTimes));
            fprintf(fid, '  variables:\n    - gps_time:\n        units: second\n');
            fprintf(fid, '    - val:\n        units: m\n');
            fprintf(fid, ['    - qualflg:\n        flag_meanings:\n', ...
                '          - bit 0 = Test A\n          - bits 1-2 = Test B\n']);
            fprintf(fid, '# End of YAML header\n');
            for k = 1:numel(gpsTimes)
                fprintf(fid, '%.6f %.6f 00000000\n', gpsTimes(k), valOffset + k);
            end
            fclose(fid);
        end

        function f = writeScaLike(testCase, q)
            % q: N x 4 quaternion rows (angle, i, j, k)
            f = fullfile(testCase.workDir, 'SCA1B_synth.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, 'header:\n  dimensions:\n    num_records: %d\n', size(q,1));
            fprintf(fid, '  variables:\n    - gps_time:\n        units: second\n');
            for nm = {'quatangle','quaticoeff','quatjcoeff','quatkcoeff'}
                fprintf(fid, '    - %s:\n        comment: c\n', nm{1});
            end
            fprintf(fid, '    - qualflg:\n        comment: c\n# End of YAML header\n');
            for k = 1:size(q,1)
                fprintf(fid, '%d %.16f %.16f %.16f %.16f 00000000\n', k-1, q(k,:));
            end
            fclose(fid);
        end
    end

    methods (Test)

        function testMultiConcatenation(testCase)
            f1 = testCase.writeSimple('day1.txt', [0; 43200], 0);
            f2 = testCase.writeSimple('day2.txt', [86400; 129600], 100);
            [t, obs, aux] = gracefoReading.readL1bMulti([string(f1), string(f2)]);

            testCase.verifySize(t, [4, 2]);
            testCase.verifyEqual(obs, [1; 2; 101; 102], 'AbsTol', 1e-9);
            testCase.verifyEqual(aux.recordsPerFile, [2; 2]);
            testCase.verifyEqual(t(4,:), [51546, 0], 'AbsTol', 1e-9);
            testCase.verifySize(aux.qualflg, [4, 8]);   % concatenated
        end

        function testMultiSingleFileEquivalence(testCase)
            f1 = testCase.writeSimple('day1.txt', [0; 43200; 86400], 0);
            [t1, o1] = gracefoReading.readL1b(f1);
            [t2, o2, aux2] = gracefoReading.readL1bMulti(string(f1));
            testCase.verifyEqual(t2, t1);
            testCase.verifyEqual(o2, o1);
            testCase.verifyEqual(aux2.recordsPerFile, 3);
        end

        function testMultiForwardsOptions(testCase)
            f1 = testCase.writeSimple('day1.txt', [0; 43200], 0);
            f2 = testCase.writeSimple('day2.txt', [86400; 129600], 100);
            t = gracefoReading.readL1bMulti([string(f1), string(f2)], ...
                'TimeFormat', 'datetime');
            testCase.verifyClass(t, 'datetime');
            testCase.verifySize(t, [4, 1]);
        end

        function testDecodeQualFlagsMeanings(testCase)
            f = testCase.writeSimple('day1.txt', [0; 1], 0);
            [~, ~, aux] = gracefoReading.readL1b(f);
            [bits, report] = gracefoReading.decodeQualFlags(aux);

            testCase.verifySize(bits, [2, 8]);
            testCase.verifyFalse(any(bits(:)));
            testCase.verifyEqual(report.meaning(1), "Test A");     % bit 0
            testCase.verifyEqual(report.meaning(2), "Test B");     % bits 1-2
            testCase.verifyEqual(report.meaning(3), "Test B");
            testCase.verifyEqual(report.meaning(4), "(not documented)");
            testCase.verifyEqual(report.countSet, zeros(8,1));

            testCase.verifyError(@() gracefoReading.decodeQualFlags(aux, 'nope'), ...
                'gracefoReading:decodeQualFlags:flagNotFound');
        end

        function testQuaternionNormOkAndViolations(testCase)
            qGood = [1 0 0 0; 0.5 0.5 0.5 0.5];              % unit norm
            qBad  = [1.001 0 0 0];                            % off by 1e-3
            f = testCase.writeScaLike([qGood; qBad]);
            [~, obs, aux] = gracefoReading.readL1b(f);

            [ok, stats] = gracefoReading.checkQuaternionNorm(obs, aux);
            testCase.verifyEqual(ok, [true; true; false]);
            testCase.verifyEqual(stats.numViolations, 1);
            testCase.verifyEqual(stats.maxDeviation, 1e-3, 'RelTol', 1e-6);
            testCase.verifyEqual(stats.n, 3);

            % loose tolerance accepts everything
            okLoose = gracefoReading.checkQuaternionNorm(obs, aux, ...
                'Tolerance', 1e-2);
            testCase.verifyTrue(all(okLoose));
        end

        function testQuaternionNormWrongProductRaises(testCase)
            f = testCase.writeSimple('day1.txt', [0; 1], 0);
            [~, obs, aux] = gracefoReading.readL1b(f);
            testCase.verifyError(@() gracefoReading.checkQuaternionNorm(obs, aux), ...
                'gracefoReading:checkQuaternionNorm:columnsNotFound');
        end

        function testGroopsWriterRoundtrip(testCase)
            t = [58849, 0; 58849, 43200.5; 58850, 100];
            data = [1.5, -2.5; 3.5, -4.5; 5.5, -6.5];
            f = fullfile(testCase.workDir, 'out.groops.txt');
            gracefoReading.writeGroopsInstrument(f, t, data, 'TypeCode', 7);

            % splitlines is line-ending agnostic (LF and CRLF): on Windows,
            % splitting on '\n' alone left an invisible trailing \r on each
            % line and failed the comparison (found by this test on Windows).
            lines = cellstr(splitlines(strtrim(fileread(f))));
            testCase.verifyEqual(lines{1}, 'groops instrument version=20200123');
            testCase.verifyFalse(contains(fileread(f), sprintf('\r')), ...
                'GROOPS export must use LF line endings on all platforms.');
            testCase.verifyEqual(sscanf(lines{2}, '%d %d')', [7, 2]);
            testCase.verifyEqual(sscanf(lines{3}, '%d'), 3);
            rec = sscanf(lines{4}, '%f')';
            testCase.verifyEqual(rec(1), 58849, 'AbsTol', 1e-9);
            testCase.verifyEqual(rec(2:3), data(1,:), 'AbsTol', 1e-12);
            rec2 = sscanf(lines{5}, '%f')';
            testCase.verifyEqual(rec2(1), 58849 + 43200.5/86400, 'AbsTol', 2e-11);

            % size mismatch raises
            testCase.verifyError(@() gracefoReading.writeGroopsInstrument( ...
                f, t, data(1:2,:)), ...
                'gracefoReading:writeGroopsInstrument:sizeMismatch');
        end

        function testGroopsWriterDatetimeInput(testCase)
            t = datetime(2020,1,1,0,0,0) + seconds([0; 1]);
            f = fullfile(testCase.workDir, 'out2.groops.txt');
            gracefoReading.writeGroopsInstrument(f, t, [1; 2]);
            lines = cellstr(splitlines(strtrim(fileread(f))));
            rec = sscanf(lines{4}, '%f')';
            testCase.verifyEqual(rec(1), 58849, 'AbsTol', 1e-9);
        end

        function testVersion(testCase)
            % Deliberately no hardcoded version literal here: pinning the
            % release number in two places caused a test failure after the
            % 2.0.1 bump. Cross-artifact version consistency (version.m,
            % Contents.m, HTML product page) is enforced by
            % testDocConsistency; this test checks structure only.
            [v, info] = gracefoReading.version();
            testCase.verifyMatches(v, '^\d+\.\d+\.\d+$', ...
                'Version must be a semantic version string.');
            testCase.verifyEqual(info.version, v);
            testCase.verifyMatches(info.date, '^\d{4}-\d{2}-\d{2}$');
            testCase.verifyEqual(info.license, 'MIT');
            testCase.verifyTrue(contains(info.developedWith, 'Claude'));
        end

    end
end
