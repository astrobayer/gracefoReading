classdef testRealData < matlab.unittest.TestCase
%TESTREALDATA  Acceptance tests against bundled real PO.DAAC RL04 files.
%
%   DESCRIPTION
%     Regression suite that reads genuine GRACE-FO Level-1B files
%     shipped in tests/realdata/ and compares the result against values
%     derived independently with the Python reference implementation in
%     tests/python_reference/. This is the guard against the failure
%     mode that produced version 1.0: a reader built on invented header
%     conventions that works on synthetic fixtures and fails on every
%     real file.
%
%     Run with:
%       results = runtests('testRealData'); table(results)
%
%   COVERAGE
%     - real header dialect: "variables:" with "- varname:" entries
%     - the pool products that only the runner holds: ACH1B, the
%       accelerometer housekeeping AHK1B and the LRI housekeeping
%       LHK1B (G-04); these skip until the files are in the pool
%     - fractional time declared in microseconds (THR1B, MAS1B)
%     - qualflg and prod_flag as 8-character bit strings
%     - MAS1B prod_flag-controlled variable-length records, including
%       the first gas-mass values and the resulting NaN pattern
%     - record counts, first and last epochs, observation counts per
%       product
%     - char columns and identifier columns routed to aux
%
%   ACCURACY AND LIMITATIONS
%     - Expected values were produced by the Python reference reader
%       and are hard-coded here; they describe the bundled files of
%       2020-01-01 and are not claims about other days or releases.
%     - Only the small products (MAS1B, THR1B) are bundled by default
%       to keep the toolbox small; tests for the large products skip
%       themselves when the corresponding file is absent, so a green
%       run does not imply full-product coverage unless the archive
%       files are present.
%     - The five large products are looked up in the data pool named
%       by the environment variable READING_DATA_POOL before the
%       bundled tests/realdata folder. That variable is the DATAPOOL
%       ROOT (G-07, issue #23), and fixtures sit below it in
%       RawData\tests\realdata; <ROOT>\<name> is still accepted for
%       one release, so the repository-level and the organisation
%       value both work while the switch is made. The path is
%       deliberately not in the repository. An unset or wrong variable
%       is not an error here - the affected points skip - so a run
%       that silently covers less looks identical to one that covers
%       more. The workflow therefore names every expected file in its
%       own step, where a wrong layout is visible.
%     - Tolerances follow the ASCII precision of the products, which
%       is well within double precision.
%
%   EXAMPLE
%     results = runtests('testRealData');
%     disp(table(results));
%
%   Toolbox:  gracefoReading v1.1.0
%   Created:  2026-08-01
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

    properties
        dataDir
        dataPool (1,1) string = ""
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
            testCase.dataDir = fullfile(here, 'realdata');
            testCase.dataPool = testRealData.resolvePool();
        end
    end

    methods (Access = private)
        function f = requireFile(testCase, name)
            % Search order: external pool first, bundled folder second.
            % The two small products travel with the toolbox; the five
            % large ones are too big to bundle and live in the pool.
            f = testRealData.resolveFixture(name);
            if strlength(f) == 0
                f = fullfile(testCase.dataDir, name);
            end
            testCase.assumeTrue(isfile(f), sprintf( ...
                ['Real data file %s not present in %s nor in the pool ' ...
                 '(READING_DATA_POOL = "%s"); test skipped.'], ...
                name, testCase.dataDir, testCase.dataPool));
        end

        function verifyGenericInvariants(testCase, t, obs, aux, product)
            % The promises the header-driven reader makes for ANY RL04
            % product, checked on real bytes. Written as invariants and
            % not as golden numbers on purpose: a golden number for a
            % file nobody in this repository has read would be an
            % assumption dressed as a measurement, which is the failure
            % O-1 records. The numbers follow when the file does.
            testCase.verifyEqual(aux.product, product);
            testCase.verifySize(t, [size(obs, 1), 2]);
            testCase.verifyGreaterThan(size(t, 1), 0);
            testCase.verifyEqual(aux.numRecordsActual, size(t, 1));
            testCase.verifyEqual(aux.timeSystem, 'GPS');
            testCase.verifyEqual(aux.epochMJD, 51544);

            % strictly increasing epochs, day-of-second in range
            secs = (t(:,1) - t(1,1)) * 86400 + (t(:,2) - t(1,2));
            testCase.verifyTrue(all(diff(secs) > 0), ...
                'Epochs of a real product must be strictly increasing.');
            testCase.verifyGreaterThanOrEqual(min(t(:,2)), 0);
            testCase.verifyLessThan(max(t(:,2)), 86400);

            % every declared variable is reachable under its own field
            testCase.verifyEqual(numel(aux.variableFieldNames), ...
                numel(aux.variableNames));
            testCase.verifyEqual(numel(unique(aux.variableFieldNames)), ...
                numel(aux.variableNames), ...
                'Two declared variables must never share one aux field.');
            testCase.verifyEqual(numel(aux.obsNames), size(obs, 2));
        end

    end

    methods (Static)
        function pool = resolvePool()
            %RESOLVEPOOL  Location of the external real-data pool, or "".
            %
            % SINGLE POINT OF ACCESS for the pool location. The path
            % itself is NOT in the repository: it comes from the
            % environment variable READING_DATA_POOL, which the CI
            % workflow fills from the repository variable of the same
            % name. That keeps the mechanism version controlled and the
            % machine-specific location out of the tree, and a second
            % runner needs no code change.
            %
            % Read with getenv rather than interpolated from anywhere,
            % so a path containing spaces or backslashes cannot break.
            %
            % OUTPUT
            %   pool - string, 1x1. "" when the variable is unset or
            %          does not name a folder; every caller then falls
            %          back to the bundled tests/realdata folder and the
            %          affected points skip themselves as before.
            pool = string(getenv('READING_DATA_POOL'));
            if strlength(pool) == 0 || ~isfolder(pool)
                pool = "";
            end
        end

        function f = resolveFixture(name)
            %RESOLVEFIXTURE  Full path of one pool fixture, or "".
            %
            % SINGLE POINT OF ACCESS for the fixture LAYOUT, as
            % resolvePool is for the pool location. G-07 (issue #23):
            % READING_DATA_POOL names the DATAPOOL ROOT, and the day
            % fixtures live below it in RawData\tests\realdata.
            %
            % Two candidates are tried, in this order:
            %   1. <ROOT>\RawData\tests\realdata\<name>  - the
            %      organisation value, the owner's real layout;
            %   2. <ROOT>\<name>                            - the
            %      repository-level value, which pointed straight at
            %      the fixture folder.
            %
            % The second is a DELIBERATE FALLBACK for exactly one
            % release, so that deleting the repository-level variable
            % and switching to the organisation one cannot turn a
            % green run into eight skipped acceptance points in the
            % same step. It goes away with the next release; the CI
            % step that lists the pool reports which of the two
            % answered, so the switch is visible rather than inferred.
            %
            % INPUT
            %   name - string | char, 1x1. Bare file name of a fixture.
            %
            % OUTPUT
            %   f - string, 1x1. Full path of the first candidate that
            %       exists, or "" when the pool is unset or holds
            %       neither. Callers then fall back to the bundled
            %       tests/realdata folder and skip as before.
            f = "";
            pool = testRealData.resolvePool();
            if strlength(pool) == 0
                return
            end
            candidates = [fullfile(pool, 'RawData', 'tests', 'realdata', name)
                          fullfile(pool, name)];
            for k = 1:numel(candidates)
                if isfile(candidates(k))
                    f = candidates(k);
                    return
                end
            end
        end
    end

    methods (Test)

        function testACT1B(testCase)
            f = testCase.requireFile('ACT1B_2020-01-01_C_04.txt');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifyEqual(aux.numRecordsHeader, 86400);
            testCase.verifySize(t, [86400, 2]);
            testCase.verifyEqual(t(1,:),   [58849, 0], 'AbsTol', 1e-9);
            testCase.verifyEqual(t(end,:), [58849, 86399], 'AbsTol', 1e-9);
            testCase.verifyEqual(aux.obsNames, ...
                {'lin_accl_x','lin_accl_y','lin_accl_z', ...
                 'ang_accl_x','ang_accl_y','ang_accl_z', ...
                 'acl_x_res','acl_y_res','acl_z_res'});
            testCase.verifySize(obs, [86400, 9]);
            testCase.verifyEqual(aux.GRACEFO_id(1), 'C');
            testCase.verifyEqual(aux.timeVariable, 'gps_time');
        end

        function testGNV1B(testCase)
            f = testCase.requireFile('GNV1B_2020-01-01_C_04.txt');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifySize(t, [86400, 2]);
            testCase.verifyEqual(numel(aux.obsNames), 12);   % pos/vel + errs
            testCase.verifyEqual(aux.coord_ref(1), 'E');
            % orbit radius sanity: |r| within 6700-7100 km
            r = sqrt(sum(obs(:,1:3).^2, 2));
            testCase.verifyGreaterThan(min(r), 6.7e6);
            testCase.verifyLessThan(max(r), 7.1e6);
        end

        function testSCA1B(testCase)
            f = testCase.requireFile('SCA1B_2020-01-01_C_04.txt');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifySize(t, [86400, 2]);
            testCase.verifyEqual(aux.obsNames, ...
                {'quatangle','quaticoeff','quatjcoeff','quatkcoeff','qual_rss'});
            testCase.verifyEqual(aux.sca_id(1), 23);
            % quaternion norm check on real attitude data
            [ok, stats] = gracefoReading.checkQuaternionNorm(obs, aux, ...
                'Tolerance', 1e-6);
            testCase.verifyTrue(all(ok), sprintf( ...
                'Quaternion norm violations: %d (max dev %.3g)', ...
                stats.numViolations, stats.maxDeviation));
        end

        function testTHR1B(testCase)
            f = testCase.requireFile('THR1B_2020-01-01_C_04.txt');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifyEqual(aux.numRecordsHeader, 471);
            testCase.verifySize(t, [471, 2]);
            testCase.verifyEqual(aux.timeVariable, 'time_intg+time_frac');
            % microsecond scaling: first epoch 250.090489 s of day
            testCase.verifyEqual(t(1,:), [58849, 250.090489], 'AbsTol', 1e-6);
            testCase.verifyEqual(t(end,:), [58849, 86365.089535], 'AbsTol', 1e-6);
            testCase.verifyEqual(numel(aux.obsNames), 42);
            testCase.verifyEqual(aux.time_ref(1), 'G');
            % thruster counts are non-negative integers
            testCase.verifyGreaterThanOrEqual(min(obs(:)), 0);
        end

        function testKBR1B(testCase)
            f = testCase.requireFile('KBR1B_2020-01-01_Y_04.txt');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifySize(t, [17280, 2]);   % 5 s sampling
            testCase.verifyEqual(t(end,:), [58849, 86395], 'AbsTol', 1e-9);
            testCase.verifyEqual(numel(aux.obsNames), 14);
            testCase.verifyTrue(any(strcmp(aux.obsNames, 'biased_range')));
            testCase.verifyTrue(any(strcmp(aux.obsNames, 'K_A_SNR')));
        end

        function testLRI1B(testCase)
            f = testCase.requireFile('LRI1B_2020-01-01_Y_04.txt');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifySize(t, [43200, 2]);   % 2 s sampling
            testCase.verifyEqual(numel(aux.obsNames), 14);
            testCase.verifySize(obs, [43200, 14]);
        end

        function testMAS1B(testCase)
            f = testCase.requireFile('MAS1B_2020-01-01_C_04.txt');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifyEqual(aux.numRecordsHeader, 24);
            testCase.verifySize(t, [24, 2]);
            % microsecond frac + 00:59:59.990452 first epoch
            testCase.verifyEqual(t(1,:), [58849, 3599.990452], 'AbsTol', 1e-6);
            testCase.verifyEqual(t(end,:), [58849, 86399.989534], 'AbsTol', 1e-6);
            % prod_flag "11000000": only gas_mass_tnk1/2 present
            i1 = strcmp(aux.obsNames, 'gas_mass_tnk1');
            i2 = strcmp(aux.obsNames, 'gas_mass_tnk2');
            testCase.verifyTrue(all(~isnan(obs(:, i1))));
            testCase.verifyTrue(all(~isnan(obs(:, i2))));
            iThr = strcmp(aux.obsNames, 'mass_thr');
            testCase.verifyTrue(all(isnan(obs(:, iThr))));
            % first record values from the file itself
            testCase.verifyEqual(obs(1, i1), 15.25970067419259, 'AbsTol', 1e-12);
            testCase.verifyEqual(obs(1, i2), 15.23406422398089, 'AbsTol', 1e-12);
            % flag decoding from header metadata
            [bits, report] = gracefoReading.decodeQualFlags(aux, 'prod_flag');
            testCase.verifyTrue(all(bits(:, 7) & bits(:, 8)));  % bits 6,7
            testCase.verifyEqual(report.meaning(7), "gas_mass_tnk1");
            testCase.verifyEqual(report.meaning(8), "gas_mass_tnk2");
        end

        function testACH1B(testCase)
            % G-04 / V-16, issue #19. ACH1B is the hybrid transplant
            % accelerometer product used by gravity RL06.3
            % (ACH = ACU + ACS + ACM + AC0). It is an ordinary RL04
            % YAML product, so what this row verifies is the GENERIC
            % READER on the real bytes, not a layout: the golden
            % numbers of this file are added when it is in the pool
            % and has been read, exactly as the other rows here were
            % derived from the Python reference before being written.
            f = testCase.requireFile('ACH1B_2020-01-01_C_04.txt');
            [t, obs, aux] = gracefoReading.readL1b(f);
            testCase.verifyGenericInvariants(t, obs, aux, 'ACH1B');
        end

        function testAHK1B(testCase)
            % G-04 / V-13, issue #19. The accelerometer housekeeping
            % product: which columns a record carries is set by
            % prod_flag, and its declared names are not all MATLAB
            % identifiers. The acceptance point is the invariant the
            % reader promises and that failed before 2026-09-22 -
            % every declared variable keeps its own field - rather
            % than one file's particular malformed name.
            f = testCase.requireFile('AHK1B_2020-01-01_C_04.txt');
            ws = warning('off', 'gracefoReading:readL1b:variableNameAdjusted');
            c = onCleanup(@() warning(ws)); %#ok<NASGU>
            [t, obs, aux] = gracefoReading.readL1b(f);
            testCase.verifyGenericInvariants(t, obs, aux, 'AHK1B');

            testCase.verifyTrue(isfield(aux, 'prod_flag'), ...
                'AHK1B is documented (R-2 pp. 31-32) as prod_flag driven.');
            [bits, report] = gracefoReading.decodeQualFlags(aux, 'prod_flag');
            testCase.verifySize(bits, [size(t, 1), 8]);
            testCase.verifyGreaterThan(numel(report.meaning), 0);
            % the accelerometer sensor-unit temperatures are there
            testCase.verifyTrue(any(contains(aux.variableNames, 'TSU', ...
                'IgnoreCase', true)), ...
                'AHK1B is documented to carry the TSU temperatures.');
        end

        function testLHK1B(testCase)
            % G-04 / V-14, issue #19. LHK1B is the LRI housekeeping
            % product; V-14 closed on it carrying LRI temperatures and
            % NO solar-array temperature, which is why L-09 takes the
            % thermal-coupling correction from AEI RTC1B instead.
            f = testCase.requireFile('LHK1B_2020-01-01_C_04.txt');
            [t, obs, aux] = gracefoReading.readL1b(f);
            testCase.verifyGenericInvariants(t, obs, aux, 'LHK1B');
            testCase.verifyTrue(any(contains(aux.variableNames, 'TEMP', ...
                'IgnoreCase', true)), ...
                'LHK1B is documented to carry LRI temperatures.');
        end

        function testMultiFileMixedProductsRejected(testCase)
            f1 = testCase.requireFile('ACT1B_2020-01-01_C_04.txt');
            f2 = testCase.requireFile('SCA1B_2020-01-01_C_04.txt');
            testCase.verifyError(@() gracefoReading.readL1bMulti( ...
                [string(f1), string(f2)]), ...
                'gracefoReading:readL1bMulti:inconsistentVariables');
        end

    end
end
