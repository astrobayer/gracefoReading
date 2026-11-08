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
%     - the hybrid transplant accelerometer ACH1B of GRACE D, bundled
%       trimmed, including its identically zero angular columns
%     - the pool products that only the runner holds: the
%       accelerometer housekeeping AHK1B and the LRI housekeeping
%       LHK1B (G-04); these skip until the files are in the pool
%     - fractional time declared in microseconds (THR1B, MAS1B)
%     - qualflg and prod_flag as 8-character bit strings
%     - MAS1B prod_flag-controlled variable-length records, including
%       the first gas-mass values and the resulting NaN pattern
%     - record counts, first and last epochs, observation counts per
%       product
%     - char columns and identifier columns routed to aux
%     - the clock products of GRACE-FO, bundled trimmed (#29): CLK1B C
%       of 2020-01-02 read through its single rcv_time column, and
%       TIM1B D of 2020-01-02 with its 31 records whose receiver time
%       is 0 - reported by zeroTime, removed by 'DropZeroTime', and
%       flagged by the product itself (qualflg bit 3)
%
%   ACCURACY AND LIMITATIONS
%     - Expected values were produced by the Python reference reader
%       and are hard-coded here; they describe the bundled files of
%       2020-01-01 and are not claims about other days or releases.
%     - The CLK1B and TIM1B extracts of 2020-01-02 (60 records each,
%       num_records rewritten) were taken byte for byte from the
%       runner's DATAPOOL by the scan of PR #31 and their expected
%       values derived with Python from the extracts' text, not with
%       this reader.
%     - Only the small products (MAS1B, THR1B, and the trimmed ACH1B
%       extract) are bundled by default to keep the toolbox small;
%       tests for the large products skip themselves when the
%       corresponding file is absent, so a green run does not imply
%       full-product coverage unless the archive files are present.
%     - The bundled ACH1B is the first 120 records of the published
%       GRACE D file with num_records rewritten to match, and the
%       owner's pool holds the full day under the same name. Since
%       the lookup is pool first, bundled second, testACH1B has to
%       pass on either, so its length-dependent expectations are
%       DERIVED from the record count rather than hard-coded, and it
%       refuses any length that is neither. The same shadowing
%       applies to testMAS1B and testTHR1B, which do hard-code theirs
%       and would fail loudly if a full day were put in the pool
%       under those names.
%     - The five large products are looked up in the data pool named
%       by the environment variable DATAPOOL - or, when it is unset,
%       READING_DATA_POOL, the older name (1.3.2, the astrobayer data
%       pool rule) - before the bundled tests/realdata folder. That
%       variable is the DATAPOOL ROOT (G-07, issue #23), and fixtures sit below it in
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
%   Toolbox:  gracefoReading v1.3.1
%   Created:  2026-08-01
%   Updated:  2026-11-08
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
                 '(DATAPOOL, else READING_DATA_POOL = "%s"); test skipped.'], ...
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

            % Non-decreasing epochs, day-of-second in range. NOT strictly
            % increasing: measured 2026-09-22, the long-format
            % housekeeping products carry one record per SENSOR per
            % epoch, so real LHK1B opens with three records all tagged
            % 631108800.872776889 (pztInLoopStatus, pztOutOfLoopStatus,
            % quadDc0). Strictness is a property of the one-record-per-
            % epoch products and is asserted where it is known to hold,
            % not here.
            secs = (t(:,1) - t(1,1)) * 86400 + (t(:,2) - t(1,2));
            testCase.verifyTrue(all(diff(secs) >= 0), ...
                'Epochs of a real product must never go backwards.');
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
            % environment variable DATAPOOL (which the installer's
            % startup.m sets) or, when that is unset or empty, from
            % READING_DATA_POOL, the older name, which the CI workflow
            % fills from the repository variable of the same name - the
            % order of the astrobayer data pool rule
            % (toolboxInstaller docs/DATA_POOL.md, 1.3.2). That keeps the
            % mechanism version controlled and the machine-specific
            % location out of the tree, and a second runner needs no
            % code change. The first variable that is set decides; a
            % set DATAPOOL is not passed over for READING_DATA_POOL.
            %
            % Read with getenv rather than interpolated from anywhere,
            % so a path containing spaces or backslashes cannot break.
            %
            % OUTPUT
            %   pool - string, 1x1. "" when the variable is unset or
            %          does not name a folder; every caller then falls
            %          back to the bundled tests/realdata folder and the
            %          affected points skip themselves as before.
            pool = string(getenv('DATAPOOL'));
            if strlength(pool) == 0
                pool = string(getenv('READING_DATA_POOL'));
            end
            if strlength(pool) == 0 || ~isfolder(pool)
                pool = "";
            end
        end

        function f = resolveFixture(name)
            %RESOLVEFIXTURE  Full path of one pool fixture, or "".
            %
            % SINGLE POINT OF ACCESS for the fixture LAYOUT, as
            % resolvePool is for the pool location. G-07 (issue #23):
            % the pool variable names the DATAPOOL ROOT, and the day
            % fixtures live below it in RawData\tests\realdata.
            %
            % Two candidates are tried, in this order:
            %   1. <ROOT>\RawData\tests\realdata\<name>  - the
            %      organisation value, the owner's real layout;
            %   2. <ROOT>\<name>                            - the
            %      repository-level value, which pointed straight at
            %      the fixture folder.
            % In each, <name> is tried before <name>.gz: ITSG serves its
            % products only gzip-compressed, the readers read .gz
            % directly, and a fixture need not be expanded to count.
            %
            % The second is a DELIBERATE FALLBACK for exactly one
            % release, so that deleting the repository-level variable
            % and switching to the organisation one cannot turn a
            % green run into a row of skipped acceptance points in the
            % same step. It goes away with the next release; the CI
            % step that lists the pool reports which of the two
            % answered, so the switch is visible rather than inferred.
            %
            % INPUT
            %   name - string | char, 1x1. Bare file name of a fixture.
            %
            % OUTPUT
            %   f - string, 1x1. Full path of the first candidate that
            %       exists (possibly the .gz), or "" when the pool is
            %       unset or holds none of them. Callers then fall back
            %       to the bundled tests/realdata folder and skip as before.
            f = "";
            pool = testRealData.resolvePool();
            if strlength(pool) == 0
                return
            end
            name = string(name);
            candidates = [fullfile(pool, 'RawData', 'tests', 'realdata', name)
                          fullfile(pool, 'RawData', 'tests', 'realdata', name + ".gz")
                          fullfile(pool, name)
                          fullfile(pool, name + ".gz")];
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
            % READER on the real bytes, not a layout.
            %
            % The file is GRACE D, not C: satellite D is the one whose
            % accelerometer failed and therefore the one the transplant
            % exists for. It is bundled trimmed to 120 records, so this
            % row no longer waits on the pool.
            %
            % It must nevertheless pass on EITHER file. The lookup is
            % pool first, bundled second, and the owner's pool holds
            % the full published day under this very name - measured
            % on the runner, CI run 35707090459, where a first version
            % of this row asserting 120 records read 86 400 and failed
            % on exactly the four length-dependent lines. Nothing was
            % wrong with the reader or with either file: they agreed
            % on every value. A fixture that only passes when the pool
            % is absent is not an acceptance point, so what is length
            % dependent is now DERIVED from the record count and what
            % is not is asserted outright.
            f = testCase.requireFile('ACH1B_2020-01-01_D_04.txt');
            [t, obs, aux] = gracefoReading.readL1b(f);
            testCase.verifyGenericInvariants(t, obs, aux, 'ACH1B');

            n = size(t, 1);
            testCase.verifyTrue(n == 120 || n == 86400, sprintf( ...
                ['ACH1B must be either the bundled 120-record extract ', ...
                 'or the full published day of 86 400 records; this ', ...
                 'file has %d. A third length means the fixture was ', ...
                 'cut differently and the numbers below no longer ', ...
                 'describe it.'], n));

            % True of both, and stronger on the full day than on the
            % extract: 1 Hz from midnight with no gap anywhere, so the
            % last epoch is fixed by the record count alone.
            testCase.verifyEqual(aux.numRecordsHeader, n);
            testCase.verifyEqual(t(1,:),   [58849,   0], 'AbsTol', 1e-9);
            testCase.verifyEqual(t(end,:), [58849, n-1], 'AbsTol', 1e-9);

            % Independent of length: twelve declared variables, nine
            % observation columns - exactly classic ACC1B's, which is
            % what makes this file confirmation of that measured
            % layout rather than only a reader check.
            testCase.verifyEqual(numel(aux.variableNames), 12);
            testCase.verifyEqual(aux.obsNames, ...
                {'lin_accl_x','lin_accl_y','lin_accl_z', ...
                 'ang_accl_x','ang_accl_y','ang_accl_z', ...
                 'acl_x_res','acl_y_res','acl_z_res'});
            testCase.verifyEqual(aux.GRACEFO_id(1), 'D');
            testCase.verifyEqual(aux.timeVariable, 'gps_time');
            testCase.verifyEqual(obs(1, 1:3), ...
                [3.146952561383804e-07, 1.125335240065487e-05, ...
                 -1.781514495161417e-07], 'AbsTol', 1e-20);

            % The transplant carries LINEAR accelerations only: the
            % three angular columns are declared, so the reader must
            % return them, and are identically zero - over all 86 400
            % records of the published day, not only over the extract.
            iAng = 4:6;
            testCase.verifyEqual(obs(:, iAng), zeros(n, 3));
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

            % Golden numbers, MEASURED on the runner 2026-09-22 (CI runs
            % 35696829972 and 35697358724) and not before: the file is
            % 864 077 records over 36 declared variables, with a
            % 32-character prod_flag of which six bits are set all day
            % (TFEEU_REF, Vp, icu_blk_nr, PPS_source, Sync_Qual,
            % statusflag), giving twelve tokens per record.
            testCase.verifyEqual(aux.numRecordsActual, 864077);
            testCase.verifyEqual(numel(aux.variableNames), 36);
            testCase.verifyTrue(isfield(aux, 'prod_flag'), ...
                'AHK1B is documented (R-2 pp. 31-32) as prod_flag driven.');
            testCase.verifyEqual(size(aux.prod_flag, 2), 32);
            % MEASURED 2026-09-22, CI run 35696829972: real AHK1B is
            % 864 077 records with a THIRTY-TWO character prod_flag,
            % where ACT1B and MAS1B carry eight. This assertion said 8
            % and failed, which is the right outcome for the wrong
            % reason: the width was imported from a sibling product,
            % the one inference resolveTime's rule explicitly forbids
            % ("a property of the file, not of the product family").
            % It is now read off the file, and only the relation
            % between the decoded bits and the raw column is asserted.
            [bits, report] = gracefoReading.decodeQualFlags(aux, 'prod_flag');
            nBits = size(aux.prod_flag, 2);
            testCase.verifySize(bits, [size(t, 1), nBits]);
            testCase.verifyEqual(numel(report.meaning), nBits, ...
                'decodeQualFlags must report one row per bit of the column.');
            testCase.verifyEqual(bits(:, 1), aux.prod_flag(:, end) == '1', ...
                'Bit 0 is the rightmost character of the raw bit string.');
            % The four sensor-unit temperatures, declared exactly as
            % V-13 measured them - the last with a SPACE. This is the
            % real-file evidence for the header-parser half of G-04:
            % under the pattern used until 2026-09-22, "TSU Z-" was not
            % a variable at all.
            declared = string(aux.variableNames);
            for want = ["TSU_Y+", "TSU_Y-", "TSU_Z+", "TSU Z-"]
                testCase.verifyTrue(any(declared == want), sprintf( ...
                    'AHK1B declares %s; the header parser must keep it.', want));
            end

            % And the evidence for the field-name half. makeValidName is
            % not injective, and this one file has THREE colliding pairs:
            % TSU_Y+/TSU_Y-, +15V/-15V and +48V/-48V all collapse under
            % it. Every declared variable must still own a field.
            testCase.verifyEqual(numel(unique(aux.variableFieldNames)), ...
                numel(aux.variableNames), ...
                'Colliding declared names must map to distinct aux fields.');
            for pair = ["+15V" "-15V"; "+48V" "-48V"; "TSU_Y+" "TSU_Y-"]'
                i1 = find(declared == pair(1), 1);
                i2 = find(declared == pair(2), 1);
                testCase.verifyNotEmpty(i1, sprintf('%s not declared', pair(1)));
                testCase.verifyNotEmpty(i2, sprintf('%s not declared', pair(2)));
                if isempty(i1) || isempty(i2), continue; end
                testCase.verifyNotEqual(aux.variableFieldNames{i1}, ...
                    aux.variableFieldNames{i2}, sprintf( ...
                    '%s and %s must not share one field.', pair(1), pair(2)));
            end
        end

        function testLHK1B(testCase)
            % G-04 / V-14, issue #19. LHK1B is the LRI housekeeping
            % product; V-14 closed on it carrying LRI temperatures and
            % NO solar-array temperature, which is why L-09 takes the
            % thermal-coupling correction from AEI RTC1B instead.
            f = testCase.requireFile('LHK1B_2020-01-01_C_04.txt');
            [t, obs, aux] = gracefoReading.readL1b(f);
            testCase.verifyGenericInvariants(t, obs, aux, 'LHK1B');

            % Golden numbers, MEASURED on the runner 2026-09-22 (CI run
            % 35697358724). The long format the owner described on issue
            % #19, read off the header: eight columns ending in a
            % free-text name the header itself calls the remaining
            % portion of the record.
            testCase.verifyEqual(aux.numRecordsActual, 1169274);
            testCase.verifyEqual(aux.variableNames, ...
                {'time_intg','time_frac','time_ref','GRACEFO_id', ...
                 'qualflg','sensortype','sensorvalue','sensorname'});
            testCase.verifyEqual(aux.obsNames, {'sensorvalue'});

            % The finding this row exists for: 2 886 of those records
            % carry a SPACE in the sensor name, so the record has nine
            % whitespace-separated tokens where the header declares
            % eight. Until 2026-09-22 the first of them, file line 537,
            % raised columnMismatch and the product could not be read.
            testCase.verifyClass(aux.sensorname, 'cell');
            testCase.verifyEqual(numel(aux.sensorname), 1169274);
            withSpace = contains(string(aux.sensorname), " ");
            testCase.verifyEqual(sum(withSpace), 2886, ...
                'The number of space-bearing sensor names is a golden number.');
            testCase.verifyTrue(any(string(aux.sensorname) == ...
                "fpga_state: science_state"));
            testCase.verifyTrue(any(string(aux.sensorname) == "mode: science"));
        end

        function testCLK1B(testCase)
            % Issue #29: v1.1.0 refused CLK1B with noTime, because its
            % time tag is one integer receiver-time column, rcv_time.
            f = testCase.requireFile('CLK1B_2020-01-02_C_04.txt');
            [t, obs, aux] = testCase.verifyWarningFree(@() gracefoReading.readL1b(f));
            testCase.verifyGenericInvariants(t, obs, aux, 'CLK1B');
            testCase.verifyEqual(aux.numRecordsHeader, 60, ...
                'The bundled extract has 60 records; a pool file would shadow it.');
            testCase.verifyEqual(aux.timeVariable, 'rcv_time');
            testCase.verifyEqual(aux.obsNames, ...
                {'eps_time', 'eps_err', 'eps_drift', 'drift_err'});
            tns = gracefoReading.readL1b(f, 'TimeFormat', 'gpsns');
            testCase.verifyEqual(tns([1 2 end]), ...
                int64([631194900; 631194900; 631195480]) * int64(1e9));
            iEps = strcmp(aux.obsNames, 'eps_time');
            testCase.verifyEqual(obs([1 end], iEps), ...
                [-0.0104623276378565; -0.01046875679691837], 'AbsTol', 1e-17);
            % the first epoch is written twice; only the first copy has
            % bit 1 ("extrapolation of eps_time not valid BEFORE rcv_time")
            testCase.verifyEqual(aux.qualflg(1:2, :), ['00000010'; '00000000']);
        end

        function testTIM1BZeroTime(testCase)
            % Issue #29: real TIM1B D of 2020-01-02 carries 31 records
            % whose receiver time is 0 - records 7872..7902 of the day,
            % 11..41 of the extract. The product flags every one of them
            % with qualflg bit 3, "Receiver Time mapping not defined".
            f = testCase.requireFile('TIM1B_2020-01-02_D_04.txt');
            [t, ~, aux] = testCase.verifyWarning(@() ...
                gracefoReading.readL1b(f, 'TimeFormat', 'gpsns'), ...
                'gracefoReading:readL1b:zeroTime');
            testCase.verifyEqual(aux.numRecordsHeader, 60, ...
                'The bundled extract has 60 records; a pool file would shadow it.');
            testCase.verifyEqual(aux.timeVariable, 'rcvtime_intg+rcvtime_frac');
            testCase.verifyEqual(aux.numRecordsZeroTime, 31);
            testCase.verifyEqual(find(t == 0), (11:41)');

            [t2, ~, aux2] = testCase.verifyWarning(@() ...
                gracefoReading.readL1b(f, 'TimeFormat', 'gpsns', 'DropZeroTime', true), ...
                'gracefoReading:readL1b:zeroTime');
            testCase.verifySize(t2, [29, 1]);
            % int64 arithmetic: a literal 631258091000000119 is parsed as
            % a double first and would round to ...128 (above 2^53)
            testCase.verifyEqual(t2([1 end]), ...
                int64([631258091; 631258563]) * int64(1e9) + int64([119; 0]));
            testCase.verifyTrue(all(diff(t2) > 0), 'Without them the tags increase.');
            testCase.verifyEqual(aux2.numRecordsZeroTime, 31);
            testCase.verifyEqual(aux2.numRecordsActual, 60);

            % The product's own flag selects exactly the same records.
            ws = warning('off', 'gracefoReading:readL1b:zeroTime');
            testCase.addTeardown(@() warning(ws));
            t3 = gracefoReading.readL1b(f, 'TimeFormat', 'gpsns', 'QualityBitMask', 3);
            testCase.verifyEqual(t3, t2);
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
