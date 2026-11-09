classdef testItsgProducts < matlab.unittest.TestCase
%TESTITSGPRODUCTS  Acceptance tests for the TU Graz (ITSG) orbit products.
%
%   DESCRIPTION
%     Reads the five real ITSG products bundled in tests/realdata/ and
%     checks gracefoReading.readItsgProduct and the real-GROOPS dialect
%     of gracefoReading.readGroopsInstrument against them. Every
%     expectation here was derived independently from the file bytes and
%     from the ITSG product README before being written down, per
%     HANDOVER.md section D; none was read back out of the MATLAB code
%     it tests.
%
%     The bundled fixtures are the first 60 records of the published
%     files with the record-count line adjusted to match. Headers and
%     record text are byte-for-byte as published, so every format claim
%     is tested on real bytes. Assertions that need a whole day - the
%     receiver-clock jitter of the kinematic products - use the full
%     file from the data pool (DATAPOOL, else READING_DATA_POOL) and skip when it is absent.
%
%     Run with:
%       results = runtests('testItsgProducts'); table(results)
%
%   COVERAGE
%     - real-GROOPS dialect: comment lines skipped, epoch type name and
%       code read from the file, columns named and united from the
%       file's own legend, record count honoured
%     - the second header integer is NOT the column count in these files
%       (it is 1 against 3, 4, 6 and 9 columns) and the legend wins
%     - zero padding: kinematicOrbit returns 3 position columns and not
%       the 9 the ORBIT type declares; reducedDynamicOrbit returns 6
%     - frame and time system come from the product documentation with
%       their provenance recorded, never from the file, never guessed;
%       the frame is per product and is withheld when the product is
%       unknown, the time system is stated for the whole product set and
%       is therefore 'GPS' either way
%     - exact epochs: the kinematic products sit 213 ns off the integer
%       second, the 10 s products sit exactly on it
%     - warnings: productNotRecognised, paddingNotZero
%     - gzip input reads identically to plain
%
%   ACCURACY AND LIMITATIONS
%     - Epoch expectations are exact int64 nanoseconds; no tolerance is
%       involved. Data values carry AbsTol/RelTol 1e-9 relative, which
%       is the printed precision of the files, not a fitted number.
%     - The trimmed fixtures sample a constant 10 s; the +-291 ns
%       variation documented for the kinematic products appears later in
%       the day and is covered only by the pool test.
%     - No frame rotation or interpolation is tested because the
%       toolbox performs none.
%
%   EXAMPLE
%     results = runtests('testItsgProducts');
%     disp(table(results));
%
%   Toolbox:  gracefoReading v1.3.3
%   Created:  2026-09-14
%   Updated:  2026-11-08
%   Author:   Matthias Weigelt with support of Anthropic Claude

    properties
        dataDir
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
            % Bound to the BUNDLED fixture folder on purpose. Resolving through
            % the data pool first, as testRealData does, would silently swap
            % in the full 8640-record day when a pool is configured and break
            % every count asserted here.
            testCase.dataDir = fullfile(here, 'realdata');
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
        function f = fixture(testCase, product)
            f = fullfile(testCase.dataDir, ...
                sprintf('GRACEFO-1_%s_2020-01-01.txt', product));
            testCase.assertTrue(isfile(f), sprintf('bundled fixture %s missing', f));
        end
    end

    methods (Test)

        function testRealGroopsDialectIsRead(testCase)
            % The writer in this toolbox emits no comment lines; real GROOPS
            % output carries three. Reading one proves the dialect split.
            [t, data, info] = gracefoReading.readGroopsInstrument( ...
                testCase.fixture('kinematicOrbit'));
            testCase.verifyEqual(info.typeName, 'ORBIT');
            testCase.verifyEqual(info.typeCode, -6);
            testCase.verifyEqual(info.numRecords, 60);
            testCase.verifyEqual(info.dataColumns, 9);
            testCase.verifySize(t, [60 2]);
            testCase.verifySize(data, [60 9]);
            testCase.verifyEqual(info.timeColumnLabel, 'Time [MJD]');
            testCase.verifyEqual(info.columnNames, ...
                {'pos x','pos y','pos z','vel x','vel y','vel z','acc x','acc y','acc z'});
            testCase.verifyEqual(info.columnUnits, ...
                {'m','m','m','m/s','m/s','m/s','m/s^2','m/s^2','m/s^2'});
        end

        function testSecondHeaderIntegerIsNotTheColumnCount(testCase)
            % Measured across all five products: the second header integer is 1
            % while the files carry 3, 4, 6 and 9 data columns. Treating it as a
            % column count, which the toolbox's own writer dialect does, rejects
            % every real file. The legend is the authority when present.
            expect = {'kinematicOrbit', 9; 'reducedDynamicOrbit', 9; ...
                      'attitude', 4; 'kinematicOrbitCovariance', 6; ...
                      'nonConservativeForces', 3};
            for k = 1:size(expect, 1)
                [~, ~, info] = gracefoReading.readGroopsInstrument( ...
                    testCase.fixture(expect{k,1}));
                testCase.verifyEqual(info.headerCount, 1, ...
                    sprintf('%s: second header integer', expect{k,1}));
                testCase.verifyEqual(info.dataColumns, expect{k,2}, ...
                    sprintf('%s: actual data columns', expect{k,1}));
            end
        end

        function testKinematicOrbitPaddingIsNotReturnedAsData(testCase)
            % The ORBIT type declares 9 columns; a kinematic orbit carries only
            % position. Handing back the 6 zero columns would give a caller an
            % exactly-zero velocity at every epoch.
            [~, obs, aux] = gracefoReading.readItsgProduct( ...
                testCase.fixture('kinematicOrbit'));
            testCase.verifySize(obs, [60 3]);
            testCase.verifyEqual(aux.obsNames, {'pos x','pos y','pos z'});
            testCase.verifyEqual(aux.obsUnits, {'m','m','m'});
            testCase.verifyEqual(aux.paddingColumns, 4:9);
            testCase.verifySize(aux.allColumns, [60 9]);
            % the padding really is zero, which is why it may be dropped
            testCase.verifyEqual(aux.allColumns(:, 4:9), zeros(60, 6));
        end

        function testReducedDynamicOrbitCarriesVelocity(testCase)
            [~, obs, aux] = gracefoReading.readItsgProduct( ...
                testCase.fixture('reducedDynamicOrbit'));
            testCase.verifySize(obs, [60 6]);
            testCase.verifyEqual(aux.obsNames, ...
                {'pos x','pos y','pos z','vel x','vel y','vel z'});
            testCase.verifyEqual(aux.paddingColumns, 7:9);
            testCase.verifyTrue(all(obs(:,4) ~= 0), 'velocity must not be padding here');
        end

        function testFrameAndTimeSystemComeFromDocumentation(testCase)
            % Neither is anywhere in the files - measured, no header field and
            % no filename suffix - so aux must say where the answer came from.
            expect = {'kinematicOrbit', 'celestial'; ...
                      'kinematicOrbitCovariance', 'celestial'; ...
                      'reducedDynamicOrbit', 'celestial'; ...
                      'attitude', 'satellite->celestial'; ...
                      'nonConservativeForces', 'satellite'};
            for k = 1:size(expect, 1)
                [~, ~, aux] = gracefoReading.readItsgProduct(testCase.fixture(expect{k,1}));
                testCase.verifyEqual(aux.frame, expect{k,2}, ...
                    sprintf('%s: frame', expect{k,1}));
                testCase.verifyEqual(aux.frameSource, 'productDocumentation');
                testCase.verifyEqual(aux.timeSystem, 'GPS');
                testCase.verifyEqual(aux.timeSystemSource, 'productDocumentation');
                testCase.verifyEqual(aux.productSource, 'fileName');
                testCase.verifyEqual(aux.satellite, 'GRACEFO-1');
                testCase.verifyEqual(aux.epochDate, datetime(2020,1,1));
                testCase.verifyNotEmpty(aux.frameDescription);
            end
        end

        function testExplicitFrameOverridesAndIsRecorded(testCase)
            [~, ~, aux] = gracefoReading.readItsgProduct( ...
                testCase.fixture('kinematicOrbit'), 'Frame', "itrf2020");
            testCase.verifyEqual(aux.frame, 'itrf2020');
            testCase.verifyEqual(aux.frameSource, 'option');
        end

        function testExactEpochsOfKinematicAndGriddedProducts(testCase)
            % Independently derived from the printed digits. The kinematic
            % products are corrected for receiver clock errors and land 213 ns
            % before midnight; the 10 s products land exactly on it. 213 ns is
            % a third of a double's ulp at MJD 58849, so this contrast exists
            % only because the epoch is read from the digits.
            midnight = int64(631108800) * int64(1e9);
            tk = gracefoReading.readItsgProduct( ...
                testCase.fixture('kinematicOrbit'), 'TimeFormat', 'gpsns');
            tr = gracefoReading.readItsgProduct( ...
                testCase.fixture('reducedDynamicOrbit'), 'TimeFormat', 'gpsns');
            testCase.verifyClass(tk, 'int64');
            testCase.verifyEqual(tk(1), midnight - int64(213));
            testCase.verifyEqual(tr(1), midnight);
            testCase.verifyEqual(tr(2) - tr(1), int64(10) * int64(1e9));
        end

        function testCovarianceReadsSixElements(testCase)
            [t, obs, aux] = gracefoReading.readItsgProduct( ...
                testCase.fixture('kinematicOrbitCovariance'));
            testCase.verifySize(obs, [60 6]);
            testCase.verifyEqual(aux.obsNames, {'xx','yy','zz','xy','xz','yz'});
            testCase.verifyEqual(aux.groopsType, 'COVARIANCE3D');
            testCase.verifyEqual(aux.groopsTypeCode, -5);
            testCase.verifyEmpty(aux.paddingColumns);
            % same epochs as the kinematic orbit it belongs to
            tk = gracefoReading.readItsgProduct(testCase.fixture('kinematicOrbit'));
            testCase.verifyEqual(t, tk);
            % variances are positive, covariances need not be
            testCase.verifyTrue(all(obs(:,1:3) > 0, 'all'));
        end

        function testFirstRecordValues(testCase)
            % One known answer per product family, read off the file by hand.
            [~, pos] = gracefoReading.readItsgProduct(testCase.fixture('kinematicOrbit'));
            testCase.verifyEqual(pos(1,:), ...
                [-3274858.655151798, 1285178.1078592371, -5918778.040959775], ...
                'RelTol', 1e-12);
            [~, q] = gracefoReading.readItsgProduct(testCase.fixture('attitude'));
            testCase.verifyEqual(q(1,1), 0.952174404712275, 'RelTol', 1e-12);
            testCase.verifyEqual(norm(q(1,:)), 1, 'AbsTol', 1e-9);
        end

        function testProductNotRecognisedWarnsAndWithholdsFrame(testCase)
            % neutralDensity is published by the same server but no real file
            % was available, so it is deliberately absent from the table. It
            % must still read, and must not be given a frame by guesswork.
            src = testCase.fixture('nonConservativeForces');
            f = fullfile(testCase.workDir, 'GRACEFO-1_neutralDensity_2020-01-01.txt');
            copyfile(src, f);
            testCase.verifyWarning(@() gracefoReading.readItsgProduct(f), ...
                'gracefoReading:readItsgProduct:productNotRecognised');
            [~, obs, aux] = testCase.evalWithoutWarning(f);
            testCase.verifyEqual(aux.frame, '');
            testCase.verifyEqual(aux.frameSource, 'undeclared');
            testCase.verifySize(obs, [60 3]);          % everything, nothing dropped
            testCase.verifyEmpty(aux.paddingColumns);
            % The time system is NOT withheld with the frame. The README states
            % "All times are GPS times" for the whole product set, where it
            % states the frame per product, so an unrecognised product still
            % has a known time system and only an unknown frame.
            testCase.verifyEqual(aux.timeSystem, 'GPS');
            testCase.verifyEqual(aux.timeSystemSource, 'productDocumentation');
        end

        function testPaddingNotZeroWarns(testCase)
            % Fault injection: if a column the documentation calls padding is
            % not zero, the file is not the product the table says it is, and
            % silently dropping it would lose real data.
            src = fileread(testCase.fixture('kinematicOrbit'));
            lines = splitlines(string(src));
            tok = split(strtrim(lines(7)));
            tok(5) = "1.234500000000000000e+00";        % vel x on record 1
            lines(7) = " " + join(tok, "  ");
            f = fullfile(testCase.workDir, 'GRACEFO-1_kinematicOrbit_2020-01-01.txt');
            fid = fopen(f, 'w'); fprintf(fid, '%s\n', lines(1:end-1)); fclose(fid);
            testCase.verifyWarning(@() gracefoReading.readItsgProduct(f), ...
                'gracefoReading:readItsgProduct:paddingNotZero');
        end

        function testGzipMatchesPlain(testCase)
            plain = testCase.fixture('attitude');
            copied = fullfile(testCase.workDir, 'GRACEFO-1_attitude_2020-01-01.txt');
            copyfile(plain, copied);
            gzip(copied);
            [t1, o1, a1] = gracefoReading.readItsgProduct(copied);
            [t2, o2, a2] = gracefoReading.readItsgProduct([copied '.gz']);
            testCase.verifyEqual(t2, t1);
            testCase.verifyEqual(o2, o1);
            testCase.verifyEqual(a2.product, a1.product);
            testCase.verifyEqual(a2.frame, a1.frame);
        end

        function testTimeFormatsAgree(testCase)
            f = testCase.fixture('reducedDynamicOrbit');
            tMjd = gracefoReading.readItsgProduct(f);
            tNs  = gracefoReading.readItsgProduct(f, 'TimeFormat', 'gpsns');
            tDt  = gracefoReading.readItsgProduct(f, 'TimeFormat', 'datetime');
            fromMjd = (int64(tMjd(:,1)) - int64(51544)) * int64(86400) * int64(1e9) ...
                    + int64(round(tMjd(:,2) * 1e9)) - int64(43200) * int64(1e9);
            testCase.verifyEqual(fromMjd, tNs);
            testCase.verifyEqual(tDt, datetime(2000,1,1,0,0,0) ...
                + days(tMjd(:,1) - 51544) + seconds(tMjd(:,2)));
        end

        function testItsgAgreesWithGroopsReader(testCase)
            % Metamorphic: the product layer must not alter the numbers, only
            % select among them and label them.
            f = testCase.fixture('reducedDynamicOrbit');
            [tg, dg] = gracefoReading.readGroopsInstrument(f);
            [ti, obs, aux] = gracefoReading.readItsgProduct(f);
            testCase.verifyEqual(ti, tg);
            testCase.verifyEqual(aux.allColumns, dg);
            testCase.verifyEqual(obs, dg(:, 1:6));
        end

        function testFullDayKinematicJitter(testCase)
            % Needs the whole published day: the +-291 ns receiver-clock
            % variation does not occur inside the first 60 records.
            % One authority for the pool AND for the layout below it:
            % the fixture sits in <ROOT>\RawData\tests\realdata (G-07).
            f = testRealData.resolveFixture('GRACEFO-1_kinematicOrbit_2020-01-01.txt');
            testCase.assumeTrue(strlength(f) > 0, ...
                ['GRACEFO-1_kinematicOrbit_2020-01-01.txt not found via ', ...
                 'DATAPOOL / READING_DATA_POOL; skipped']);
            tns = gracefoReading.readItsgProduct(f, 'TimeFormat', 'gpsns');
            steps = unique(diff(tns));
            testCase.verifyGreaterThan(numel(steps), 1, ...
                'kinematic sampling is documented as not constant');
            testCase.verifyLessThan(max(abs(steps - int64(10) * int64(1e9))), ...
                int64(1000), 'departures from 10 s should be sub-microsecond');
        end

    end

    methods (Access = private)
        function [t, obs, aux] = evalWithoutWarning(~, f)
            w = warning('off', 'gracefoReading:readItsgProduct:productNotRecognised');
            c = onCleanup(@() warning(w));
            [t, obs, aux] = gracefoReading.readItsgProduct(f);
        end
    end
end
