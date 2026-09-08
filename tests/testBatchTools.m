classdef testBatchTools < matlab.unittest.TestCase
%TESTBATCHTOOLS  Unit tests for the batch and interoperability functions.
%
%   DESCRIPTION
%     Covers the functions added for multi-file processing:
%     gracefoReading.findGaps, gracefoReading.findL1bFiles,
%     gracefoReading.readGroopsInstrument and the cross-file
%     monotonicity check of gracefoReading.readL1bMulti. All fixtures
%     are synthetic and written to a temporary folder removed on
%     teardown, so no archive is required.
%
%     Run with:
%       results = runtests('testBatchTools'); table(results)
%
%   COVERAGE
%     - findGaps: gap detection with estimated and explicit rate,
%       gap-free series, identical results for MJD-pair, datetime and
%       int64 input including a midnight rollover, segment table,
%       notSorted and badTimeFormat errors
%     - findL1bFiles: recursive and flat search, .gz files, satellite
%       and release filters, date-range narrowing, missing-day report,
%       rejection of decoy names, empty result without error
%     - readL1bMulti: timeNotMonotonic warning on overlapping files
%       and warning-free concatenation in correct order
%     - readGroopsInstrument: roundtrip against writeGroopsInstrument
%       including header fields, badFormat and countMismatch errors
%
%   ACCURACY AND LIMITATIONS
%     - The GROOPS roundtrip is checked to better than 1e-5 s, the
%       resolution limit of the decimal-MJD time tag; it cannot verify
%       compatibility with a real GROOPS installation.
%     - findL1bFiles is tested against the PO.DAAC naming convention
%       only, since that is the convention the function documents.
%     - Gap fixtures are built from exact arithmetic, so tolerances are
%       tight (1e-6 s or better).
%
%   EXAMPLE
%     results = runtests('testBatchTools');
%     disp(table(results));
%
%   Toolbox:  gracefoReading v1.0.1
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
            % only touch the path if the toolbox is not already on it
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
        function f = writeSimple(testCase, name, gpsTimes)
            f = fullfile(testCase.workDir, name);
            fid = fopen(f, 'wt');
            fprintf(fid, 'header:\n  dimensions:\n    num_records: %d\n', numel(gpsTimes));
            fprintf(fid, '  variables:\n    - gps_time:\n        units: second\n');
            fprintf(fid, '    - val:\n        units: m\n# End of YAML header\n');
            for k = 1:numel(gpsTimes)
                fprintf(fid, '%.6f %.6f\n', gpsTimes(k), k);
            end
            fclose(fid);
        end
    end

    methods (Test)

        function testFindGapsBasic(testCase)
            % 10 s sampling, records at 0..50 and 90..120: one 40 s gap
            gps = [0:10:50, 90:10:120]';
            t = [repmat(51544, numel(gps), 1), 43200 + gps];
            [gaps, stats] = gracefoReading.findGaps(t);

            testCase.verifyEqual(stats.nominalRate, 10, 'AbsTol', 1e-9);
            testCase.verifyTrue(stats.rateEstimated);
            testCase.verifyEqual(stats.numGaps, 1);
            testCase.verifyEqual(gaps.indexBefore, 6);
            testCase.verifyEqual(gaps.indexAfter, 7);
            testCase.verifyEqual(gaps.durationSec, 40, 'AbsTol', 1e-9);
            testCase.verifyEqual(gaps.missingRecords, 3);
            testCase.verifyEqual(stats.totalMissing, 3);
            testCase.verifyEqual(stats.segments, [1 6; 7 10]);
        end

        function testFindGapsNoGapsAndExplicitRate(testCase)
            t = [repmat(51544, 5, 1), (0:4)' * 5];
            [gaps, stats] = gracefoReading.findGaps(t, 'NominalRate', 5);
            testCase.verifyEqual(height(gaps), 0);
            testCase.verifyFalse(stats.rateEstimated);
            testCase.verifyEqual(stats.longestGapSec, 0);
            testCase.verifyEqual(stats.segments, [1 5]);
        end

        function testFindGapsAllTimeFormats(testCase)
            % day rollover included: MJD pair, datetime, int64 ns agree.
            % 5 s sampling continuous across midnight, then one 25 s gap.
            tPair = [51544 86390; 51544 86395; 51545 0; 51545 25];
            [g1, s1] = gracefoReading.findGaps(tPair, 'NominalRate', 5);

            tDt = datetime(2000,1,1) + days(tPair(:,1) - 51544) + seconds(tPair(:,2));
            [g2, s2] = gracefoReading.findGaps(tDt, 'NominalRate', 5);

            tNs = int64((tPair(:,1) - 51544) * 86400 - 43200 + tPair(:,2)) * int64(1e9);
            [g3, s3] = gracefoReading.findGaps(tNs, 'NominalRate', 5);

            testCase.verifyEqual(s1.numGaps, 1);
            testCase.verifyEqual(g1.indexBefore, 3);
            testCase.verifyEqual(g2.durationSec, g1.durationSec, 'AbsTol', 1e-6);
            testCase.verifyEqual(g3.durationSec, g1.durationSec, 'AbsTol', 1e-6);
            testCase.verifyEqual(s2.numGaps, 1);
            testCase.verifyEqual(s3.numGaps, 1);
            % reporting uses MJD pairs in all cases
            testCase.verifyEqual(g2.mjdAfter, 51545);
            testCase.verifyEqual(g3.mjdAfter, 51545);
        end

        function testFindGapsErrors(testCase)
            tBad = [51544 10; 51544 5];
            testCase.verifyError(@() gracefoReading.findGaps(tBad), ...
                'gracefoReading:findGaps:notSorted');
            testCase.verifyError(@() gracefoReading.findGaps(ones(3)), ...
                'gracefoReading:findGaps:badTimeFormat');
        end

        function testFindL1bFiles(testCase)
            d = testCase.workDir;
            mkdir(fullfile(d, 'sub'));
            touch = @(p) fclose(fopen(p, 'w'));
            touch(fullfile(d, 'ACT1B_2020-01-01_C_04.txt'));
            touch(fullfile(d, 'sub', 'ACT1B_2020-01-03_C_04.txt'));      % recursion
            touch(fullfile(d, 'ACT1B_2020-01-02_D_04.txt'));             % other sat
            touch(fullfile(d, 'ACT1B_2020-01-04_C_04.txt.gz'));          % gz
            touch(fullfile(d, 'ACT1B_2020-01-05_C_03.txt'));             % other release
            touch(fullfile(d, 'KBR1B_2020-01-01_Y_04.txt'));             % other product
            touch(fullfile(d, 'ACT1B_notadate_C_04.txt'));               % bad name

            [files, rep] = gracefoReading.findL1bFiles(d, "ACT1B", 'Satellite', "C");
            [~, names] = cellfun(@fileparts, cellstr(files), 'UniformOutput', false);
            testCase.verifyEqual(numel(files), 3);
            testCase.verifyTrue(issorted(rep.dates));
            testCase.verifyEqual(rep.firstDate, datetime(2020,1,1));
            testCase.verifyEqual(rep.lastDate, datetime(2020,1,4));
            testCase.verifyEqual(rep.missingDates, datetime(2020,1,2));
            testCase.verifyTrue(any(contains(string(names), "2020-01-04")));  % gz found

            % date range narrows the result
            f2 = gracefoReading.findL1bFiles(d, "ACT1B", 'Satellite', "C", ...
                'DateRange', [datetime(2020,1,1), datetime(2020,1,3)]);
            testCase.verifyEqual(numel(f2), 2);

            % non-recursive: file in sub/ not found
            f3 = gracefoReading.findL1bFiles(d, "ACT1B", 'Satellite', "C", ...
                'Recursive', false);
            testCase.verifyEqual(numel(f3), 2);

            % nothing found is an empty result, not an error
            f4 = gracefoReading.findL1bFiles(d, "LRI1B");
            testCase.verifyEmpty(f4);
        end

        function testMultiMonotonicWarning(testCase)
            f1 = testCase.writeSimple('day1.txt', [0; 100]);
            f2 = testCase.writeSimple('day2.txt', [50; 150]);   % overlaps day1
            testCase.verifyWarning( ...
                @() gracefoReading.readL1bMulti([string(f1), string(f2)]), ...
                'gracefoReading:readL1bMulti:timeNotMonotonic');
            % correct order: no warning
            f3 = testCase.writeSimple('day3.txt', [200; 300]);
            testCase.verifyWarningFree( ...
                @() gracefoReading.readL1bMulti([string(f1), string(f3)]));
        end

        function testGroopsReaderRoundtrip(testCase)
            t = [58849, 0; 58849, 43200.5; 58850, 100];
            data = [1.5, -2.5; 3.5, -4.5; 5.5, -6.5];
            f = fullfile(testCase.workDir, 'rt.groops.txt');
            gracefoReading.writeGroopsInstrument(f, t, data, 'TypeCode', 3);

            [t2, d2, info] = gracefoReading.readGroopsInstrument(f);
            testCase.verifyEqual(info.typeCode, 3);
            testCase.verifyEqual(info.dataColumns, 2);
            testCase.verifyEqual(info.numRecords, 3);
            testCase.verifyEqual(d2, data, 'AbsTol', 1e-12);
            % decimal-MJD roundtrip: ~1.3 us resolution around MJD 58849
            dtSec = (t2(:,1) - t(:,1)) * 86400 + (t2(:,2) - t(:,2));
            testCase.verifyLessThan(max(abs(dtSec)), 1e-5);
        end

        function testGroopsReaderErrors(testCase)
            f = fullfile(testCase.workDir, 'bad.txt');
            fid = fopen(f, 'w'); fprintf(fid, 'not a groops file\n1 2\n3\n'); fclose(fid);
            testCase.verifyError(@() gracefoReading.readGroopsInstrument(f), ...
                'gracefoReading:readGroopsInstrument:badFormat');

            f2 = fullfile(testCase.workDir, 'trunc.txt');
            fid = fopen(f2, 'w');
            fprintf(fid, 'groops instrument version=20200123\n0 2\n3\n');
            fprintf(fid, '58849.0 1.0 2.0\n58849.1 3.0 4.0\n');   % 2 of 3 records
            fclose(fid);
            testCase.verifyError(@() gracefoReading.readGroopsInstrument(f2), ...
                'gracefoReading:readGroopsInstrument:countMismatch');
        end

    end
end
