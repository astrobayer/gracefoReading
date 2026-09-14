classdef testItsgBatch < matlab.unittest.TestCase
%TESTITSGBATCH  Unit tests for the ITSG discovery and concatenation pair.
%
%   DESCRIPTION
%     Covers gracefoReading.findItsgFiles and
%     gracefoReading.readItsgProductMulti, the ITSG counterparts of
%     findL1bFiles and readL1bMulti.
%
%     Fixtures here are synthetic and written to a temporary folder,
%     deliberately. Only one date of real ITSG data exists in the
%     repository, so a multi-day join cannot be exercised against real
%     files; what is tested here is the batch MECHANICS - discovery,
%     ordering, coverage reporting, refusal to mix, epoch monotonicity -
%     while the parsing of real bytes stays covered by testItsgProducts
%     against the five published fixtures. The files written here use
%     the real GROOPS dialect, comment lines and all, so the two suites
%     do not disagree about the format.
%
%     Run with:
%       results = runtests('testItsgBatch'); table(results)
%
%   COVERAGE
%     - findItsgFiles: recursive and flat search, .gz files, satellite
%       filter, date-range narrowing, missing-day report, chronological
%       ordering, decoy names ignored, empty result without error,
%       exact product matching (neutralDensity does not match
%       neutralDensity_ACC)
%     - readItsgProductMulti: concatenation and record counts, aux
%       merging and per-file fields, a [K x 1] column of file names
%       accepted, TimeFormat forwarding, noFiles error,
%       inconsistentProduct and inconsistentColumns refusals, the frame
%       being consistent by construction rather than by a check, and the
%       timeNotMonotonic warning on a duplicated day
%
%   ACCURACY AND LIMITATIONS
%     - Synthetic epochs are exact 10 s multiples, so concatenation is
%       checked bitwise in the int64 format with no tolerance.
%     - These tests say nothing about whether the format is read
%       correctly; that is testItsgProducts' job against real files.
%
%   EXAMPLE
%     results = runtests('testItsgBatch');
%     disp(table(results));
%
%   Toolbox:  gracefoReading v1.0.2
%   Created:  2026-09-14
%   Updated:  2026-09-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

    properties
        workDir
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
        function f = writeDay(testCase, satellite, product, dateStr, mjd0, nRec, folder)
            % A real-dialect GROOPS ORBIT file: comment lines, a type code
            % whose second integer is 1, and a legend that names the columns.
            if nargin < 7 || isempty(folder), folder = testCase.workDir; end
            if ~isfolder(folder), mkdir(folder); end
            f = fullfile(folder, sprintf('%s_%s_%s.txt', satellite, product, dateStr));
            fid = fopen(f, 'w');
            fprintf(fid, 'groops instrument version=20200123\n');
            fprintf(fid, '# ORBIT\n');
            fprintf(fid, '%11d%11d\n', -6, 1);
            leg = '# Time [MJD]';
            names = {'pos x [m]','pos y [m]','pos z [m]','vel x [m/s]','vel y [m/s]', ...
                     'vel z [m/s]','acc x [m/s^2]','acc y [m/s^2]','acc z [m/s^2]'};
            for k = 1:9
                leg = [leg, sprintf('   data%d: %-22s', k-1, names{k})]; %#ok<AGROW>
            end
            fprintf(fid, '%s\n', leg);
            fprintf(fid, '# %s\n', repmat('=', 1, 40));
            fprintf(fid, '%11d\n', nRec);
            for r = 1:nRec
                mjd = mjd0 + (r-1) * 10 / 86400;
                vals = [r, r+1, r+2, 0.5, 0.6, 0.7, 0, 0, 0];   % acc is padding
                fprintf(fid, ' %.18f', mjd);
                fprintf(fid, ' %.18e', vals);
                fprintf(fid, '\n');
            end
            fclose(fid);
        end

        function f = writeOddLegend(testCase, satellite, product, dateStr, mjd0)
            % Same product name, six columns under different names. Nothing
            % published looks like this; it exists to prove the column guard
            % can actually fire.
            f = fullfile(testCase.workDir, ...
                sprintf('%s_%s_%s.txt', satellite, product, dateStr));
            fid = fopen(f, 'w');
            fprintf(fid, 'groops instrument version=20200123\n');
            fprintf(fid, '# ORBIT\n');
            fprintf(fid, '%11d%11d\n', -6, 1);
            leg = '# Time [MJD]';
            names = {'alpha [m]','beta [m]','gamma [m]','delta [m/s]','eps [m/s]','zeta [m/s]'};
            for k = 1:6
                leg = [leg, sprintf('   data%d: %-22s', k-1, names{k})]; %#ok<AGROW>
            end
            fprintf(fid, '%s\n', leg);
            fprintf(fid, '# %s\n', repmat('=', 1, 40));
            fprintf(fid, '%11d\n', 2);
            for r = 1:2
                fprintf(fid, ' %.18f', mjd0 + (r-1) * 10 / 86400);
                fprintf(fid, ' %.18e', [r, r+1, r+2, 0.5, 0.6, 0.7]);
                fprintf(fid, '\n');
            end
            fclose(fid);
        end
    end

    methods (Test)

        function testFindByProductAndDateRange(testCase)
            testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-01', 58849, 3);
            testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-02', 58850, 3);
            testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-04', 58852, 3);
            testCase.writeDay('GRACEFO-1', 'kinematicOrbit', '2020-01-01', 58849, 3);

            [files, report] = gracefoReading.findItsgFiles( ...
                testCase.workDir, "reducedDynamicOrbit");
            testCase.verifyNumElements(files, 3);
            testCase.verifyEqual(report.firstDate, datetime(2020,1,1));
            testCase.verifyEqual(report.lastDate, datetime(2020,1,4));
            testCase.verifyEqual(report.missingDates, datetime(2020,1,3));
            testCase.verifyEqual(report.products, repmat("reducedDynamicOrbit", 3, 1));
            testCase.verifyFalse(any(report.compressed));
            % chronological
            testCase.verifyTrue(issorted(report.dates));

            [f2, r2] = gracefoReading.findItsgFiles(testCase.workDir, ...
                "reducedDynamicOrbit", 'DateRange', ...
                [datetime(2020,1,2) datetime(2020,1,4)]);
            testCase.verifyNumElements(f2, 2);
            testCase.verifyEqual(r2.missingDates, datetime(2020,1,3));
        end

        function testSatelliteFilterAndGzAndRecursion(testCase)
            sub = fullfile(testCase.workDir, '2020');
            testCase.writeDay('GRACEFO-1', 'attitude', '2020-01-01', 58849, 2, sub);
            plain = testCase.writeDay('GRACEFO-2', 'attitude', '2020-01-02', 58850, 2, sub);
            gzip(plain); delete(plain);

            all3 = gracefoReading.findItsgFiles(testCase.workDir, "attitude");
            testCase.verifyNumElements(all3, 2);

            [one, rep] = gracefoReading.findItsgFiles(testCase.workDir, "attitude", ...
                'Satellite', "GRACEFO-2");
            testCase.verifyNumElements(one, 1);
            testCase.verifyTrue(rep.compressed(1));
            testCase.verifyEqual(rep.satellites, "GRACEFO-2");

            flat = gracefoReading.findItsgFiles(testCase.workDir, "attitude", ...
                'Recursive', false);
            testCase.verifyEmpty(flat);      % everything is one level down
        end

        function testDecoysAndExactProductMatching(testCase)
            testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-01', 58849, 2);
            % names that must NOT be picked up
            fid = fopen(fullfile(testCase.workDir, 'notes.txt'), 'w');
            fprintf(fid, 'nothing\n'); fclose(fid);
            fid = fopen(fullfile(testCase.workDir, 'ACT1B_2020-01-01_C_04.txt'), 'w');
            fprintf(fid, 'nothing\n'); fclose(fid);
            testCase.writeDay('CHAMP', 'neutralDensity_ACC', '2007-01-01', 54101, 2);

            f = gracefoReading.findItsgFiles(testCase.workDir, "reducedDynamicOrbit");
            testCase.verifyNumElements(f, 1);

            % the ACC variant is its own product: asking for the stem finds nothing
            testCase.verifyEmpty(gracefoReading.findItsgFiles( ...
                testCase.workDir, "neutralDensity"));
            testCase.verifyNumElements(gracefoReading.findItsgFiles( ...
                testCase.workDir, "neutralDensity_ACC"), 1);
        end

        function testEmptyResultIsNotAnError(testCase)
            [f, rep] = gracefoReading.findItsgFiles(testCase.workDir, "kinematicOrbit");
            testCase.verifyEmpty(f);
            testCase.verifyEqual(rep.firstDate, NaT);
            testCase.verifyEmpty(rep.missingDates);
        end

        function testConcatenationAndAux(testCase)
            testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-01', 58849, 4);
            testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-02', 58850, 6);
            files = gracefoReading.findItsgFiles(testCase.workDir, "reducedDynamicOrbit");
            testCase.verifySize(files, [2 1]);       % a COLUMN, as published

            % accepting the column is the point: a (1,:) declaration would
            % reject exactly the call findItsgFiles is built to feed
            [t, obs, aux] = gracefoReading.readItsgProductMulti(files);
            testCase.verifySize(t, [10 2]);
            testCase.verifySize(obs, [10 6]);        % padding still excluded
            testCase.verifyEqual(aux.recordsPerFile, [4; 6]);
            testCase.verifyEqual(aux.product, 'reducedDynamicOrbit');
            testCase.verifyEqual(aux.frame, 'celestial');
            testCase.verifyEqual(aux.timeSystem, 'GPS');
            testCase.verifyEqual(aux.obsNames, ...
                {'pos x','pos y','pos z','vel x','vel y','vel z'});
            testCase.verifyEqual(aux.epochDates, ...
                [datetime(2020,1,1); datetime(2020,1,2)]);
            testCase.verifyEqual(aux.satellites, ["GRACEFO-1"; "GRACEFO-1"]);
            testCase.verifyFalse(isfield(aux, 'allColumns'));   % deliberately absent
        end

        function testConcatenationMatchesPerFileReads(testCase)
            % Metamorphic: joining must not alter the numbers.
            a = testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-01', 58849, 3);
            b = testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-02', 58850, 3);
            [t1, o1] = gracefoReading.readItsgProduct(a, 'TimeFormat', 'gpsns');
            [t2, o2] = gracefoReading.readItsgProduct(b, 'TimeFormat', 'gpsns');
            [t, o] = gracefoReading.readItsgProductMulti([string(a), string(b)], ...
                'TimeFormat', 'gpsns');
            testCase.verifyEqual(t, [t1; t2]);       % int64, bitwise
            testCase.verifyEqual(o, [o1; o2]);
        end

        function testTimeNotMonotonicWarnsOnDuplicatedDay(testCase)
            a = testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-01', 58849, 3);
            b = testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-02', 58849, 3);
            testCase.verifyWarning(@() gracefoReading.readItsgProductMulti( ...
                [string(a), string(b)]), ...
                'gracefoReading:readItsgProductMulti:timeNotMonotonic');
            % correct order, distinct days: no warning
            c = testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-03', 58851, 3);
            testCase.verifyWarningFree(@() gracefoReading.readItsgProductMulti( ...
                [string(a), string(c)]));
        end

        function testRefusesDifferentProducts(testCase)
            % Checked first because it is the most informative thing to say:
            % "these are different products" beats "column 4 changed meaning".
            rd = testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-01', 58849, 2);
            kn = testCase.writeDay('GRACEFO-1', 'kinematicOrbit', '2020-01-02', 58850, 2);
            testCase.verifyError(@() gracefoReading.readItsgProductMulti( ...
                [string(rd), string(kn)]), ...
                'gracefoReading:readItsgProductMulti:inconsistentProduct');
        end

        function testRefusesSameProductWithDifferentColumns(testCase)
            % Same product name, different legend: a mislabelled or malformed
            % archive. Reaching this identifier at all requires crafting the
            % file, which is the point - it must be raisable to be documented.
            a = testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-01', 58849, 2);
            b = testCase.writeOddLegend('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-02', 58850);
            testCase.verifyError(@() gracefoReading.readItsgProductMulti( ...
                [string(a), string(b)]), ...
                'gracefoReading:readItsgProductMulti:inconsistentColumns');
        end

        function testFrameIsConsistentByConstruction(testCase)
            % There is no frame check, deliberately: the frame is derived from
            % the product and 'Frame' is forwarded to every file, so equal
            % products already mean equal frames. This pins that reasoning.
            a = testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-01', 58849, 2);
            b = testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-02', 58850, 2);
            f = [string(a), string(b)];
            [~, ~, aux] = gracefoReading.readItsgProductMulti(f);
            testCase.verifyEqual(aux.frame, 'celestial');
            testCase.verifyEqual(aux.frameSource, 'productDocumentation');
            [~, ~, auxOverride] = gracefoReading.readItsgProductMulti(f, 'Frame', "itrf2020");
            testCase.verifyEqual(auxOverride.frame, 'itrf2020');
            testCase.verifyEqual(auxOverride.frameSource, 'option');
        end

        function testNoFilesRaises(testCase)
            testCase.verifyError(@() gracefoReading.readItsgProductMulti(string.empty), ...
                'gracefoReading:readItsgProductMulti:noFiles');
        end

        function testTimeFormatIsForwarded(testCase)
            a = testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-01', 58849, 3);
            b = testCase.writeDay('GRACEFO-1', 'reducedDynamicOrbit', '2020-01-02', 58850, 3);
            f = [string(a), string(b)];
            tMjd = gracefoReading.readItsgProductMulti(f);
            tNs  = gracefoReading.readItsgProductMulti(f, 'TimeFormat', 'gpsns');
            tDt  = gracefoReading.readItsgProductMulti(f, 'TimeFormat', 'datetime');
            testCase.verifySize(tMjd, [6 2]);
            testCase.verifyClass(tNs, 'int64');
            testCase.verifyClass(tDt, 'datetime');
            fromMjd = (int64(tMjd(:,1)) - int64(51544)) * int64(86400) * int64(1e9) ...
                    + int64(round(tMjd(:,2) * 1e9)) - int64(43200) * int64(1e9);
            testCase.verifyEqual(fromMjd, tNs);
        end

    end
end
