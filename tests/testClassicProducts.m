classdef testClassicProducts < matlab.unittest.TestCase
%TESTCLASSICPRODUCTS  Acceptance tests for classic GRACE binary products.
%
%   DESCRIPTION
%     Reads the real classic GRACE (RL02, 2008-01-01) Level-1B files
%     bundled in tests/realdata/ and checks the reader against values
%     derived independently (G-02, issue #17). This is the suite that
%     discharges obligation O-1: until 2026-09-22 the classic column
%     layouts were ASSUMED from the GRACE Level-1B handbook read from
%     memory, every classic read warned, and no real classic file
%     existed in this repository.
%
%     The layouts are now MEASURED. For each product the declared
%     record count times the derived record length reproduces the data
%     section exactly, and a physical quantity in the record was
%     checked against what it must be. The expectations below were
%     produced by a reference decoder written separately from the
%     MATLAB code (tests/python_reference/classic_reference.py), so an
%     expectation derived from the code it tests cannot hide here.
%
%     Run with:
%       results = runtests('testClassicProducts'); table(results)
%
%   COVERAGE
%     - release 03 as well as release 02: the same layouts read the
%       RL03 SCA1B of 2008-01-20 (1 Hz where RL02 is 5 s) and the RL03
%       KBR1B of 2008-01-01, whose ranging observables are bit-identical
%       to the RL02 file of the same day
%     - binary dispatch: a classic header declaring
%       "FILE FORMAT 0=BINARY 1=ASCII : 0" is read as bytes, and the
%       measured products do NOT warn classicExperimental any more
%     - ACC1B: nine observation columns, including the three residual
%       columns the assumed layout was missing entirely
%     - SCA1B: quaternion norm on real attitude data, qual_rss, and the
%       star-camera head identifier sca_id cross-checked against
%       qualflg bit 3 - two independently positioned fields selecting
%       the same records
%     - GNV1B: orbit radius and speed, coord_ref
%     - KBR1B: biased range, the four int16 SNR columns, no satellite id
%     - THR1B: 42 counter columns, microsecond fractional time
%     - MAS1B: prod_flag-driven variable-length records, NaN for absent
%       columns, and the thruster- and tank-based masses agreeing
%     - MAG1B: the magnetometer vector, the six magnetorquer currents
%       and the calibration columns, with |B| checked against the
%       geomagnetic field strength at GRACE altitude
%     - AHK1B: a FOUR-byte prod_flag addressing 29 conditional columns
%       of five different types, both flag patterns the day uses, the
%       NaN pattern for the short one, and the ICU/SU supply rails
%       checked against their nominal voltages
%     - classic qualflg: a byte in the file, rendered as the same
%       8-character bit string the GRACE-FO products use, so
%       decodeQualFlags works on both
%     - the classic ASCII variant against its binary twin, column for
%       column, for ACC1B / MAG1B / MAS1B / AHK1B: the MAG1B
%       time_ref / GRACE_id swap, AHK1B's bit-string `status` and its
%       rcvtime_frac microseconds, and that none of them warns
%     - units and qualflg meanings (1.3.0), which no classic header
%       carries, from the product tables of the GRACE Level-1B handbook
%       (D-22027 v1.3, chapter 6): ACC1B, THR1B and KBR1B units; ACC1B,
%       KBR1B and SCA1B meanings read back through decodeQualFlags, the
%       SCA1B one being the bit already cross-checked against sca_id;
%       the ASCII and binary variants describing their columns alike;
%       AHK1B, which has no handbook table, stating no units
%     - refusals: a truncated file, 'ColumnNames' against a binary
%       product, and a classic product with no measured layout
%
%   ACCURACY AND LIMITATIONS
%     - The bundled files are TRIMMED to the first 40 records with
%       their NUMBER OF DATA RECORDS record rewritten to match; every
%       other header record, and every data byte kept, is exactly as
%       published. FILESIZE and TIME LAST OBS therefore still describe
%       the full published file, which is deliberate: the reader must
%       not depend on either.
%     - Two releases: RL02 for the seven products, and RL03 for the
%       two products RL03 actually publishes, SCA1B and KBR1B. The
%       record layouts are identical across the two, measured. Nothing
%       here covers the classic ASCII variant, nor the ACT1B
%       transplant archive.
%     - MAG1B and AHK1B are the two products whose column NAMES come
%       from a document rather than from a GRACE-FO sibling: the
%       Level-1B Data Product User Handbook v1.3 section 6.8, and the
%       JPL GRACE Level-1 read software (GraceReadSW_L1, release
%       2010-03-31), whose GRACEiolib.h types AHK1X_t as ACC1A_t and
%       whose ReadACC1AFRecord.c walks the prod_flag bit by bit. Both
%       are in hand, not remembered - which is the whole difference
%       from the situation O-1 records. Nothing from either is
%       vendored into this repository; what the tests below check is
%       that the real files agree with them.
%
%   EXAMPLE
%     results = runtests('testClassicProducts');
%     disp(table(results));
%
%   Toolbox:  gracefoReading v1.2.0
%   Created:  2026-09-22
%   Updated:  2026-09-27
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
        function f = fixture(testCase, name)
            f = fullfile(testCase.dataDir, name);
            testCase.assertTrue(isfile(f), sprintf( ...
                'Bundled classic fixture %s is missing.', name));
        end
    end

    methods (Test)

        function testClassicBinaryIsNotExperimentalAnyMore(testCase)
            % O-1's headline: the measured products must read WITHOUT
            % the warning that said their layout was a guess.
            f = testCase.fixture('ACC1B_2008-01-01_A_02.dat');
            testCase.verifyWarningFree(@() gracefoReading.readL1b(f));
            [~, ~, aux] = gracefoReading.readL1b(f);
            testCase.verifyEqual(aux.headerFormat, 'classicBinary');
            testCase.verifyEqual(aux.product, 'ACC1B');
            testCase.verifyEqual(aux.timeSystem, 'GPS');
            testCase.verifyEqual(aux.epochMJD, 51544);
        end

        function testACC1B(testCase)
            f = testCase.fixture('ACC1B_2008-01-01_A_02.dat');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifyEqual(aux.numRecordsHeader, 40);
            testCase.verifySize(t, [40, 2]);
            testCase.verifyEqual(t(1,:), [54466, 0], 'AbsTol', 1e-9);
            testCase.verifyEqual(t(end,:), [54466, 39], 'AbsTol', 1e-9);

            % NINE columns. The layout assumed until 2026-09-22 had six:
            % the three residual columns were missing altogether.
            testCase.verifyEqual(aux.obsNames, ...
                {'lin_accl_x','lin_accl_y','lin_accl_z', ...
                 'ang_accl_x','ang_accl_y','ang_accl_z', ...
                 'acl_x_res','acl_y_res','acl_z_res'});
            testCase.verifySize(obs, [40, 9]);
            testCase.verifyEqual(obs(1,1), 1.2411460611666213e-06, 'AbsTol', 1e-21);
            testCase.verifyEqual(obs(1,2), -2.960812344006054e-05, 'AbsTol', 1e-20);
            testCase.verifyEqual(obs(1,7), -1.1784922187307973e-09, 'AbsTol', 1e-24);
            testCase.verifyEqual(aux.GRACE_id, repmat('A', 40, 1));
        end

        function testSCA1B(testCase)
            f = testCase.fixture('SCA1B_2008-01-01_A_02.dat');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifySize(t, [40, 2]);
            testCase.verifyEqual(t(1,:), [54466, 0], 'AbsTol', 1e-9);
            testCase.verifyEqual(aux.obsNames, ...
                {'quatangle','quaticoeff','quatjcoeff','quatkcoeff','qual_rss'});
            % sca_id identifies the star-camera HEAD, and it is not
            % constant: measured on this fixture, 31 records come from
            % head 4 and 9 from head 1. The first version of this row
            % asserted a constant 4 taken from record 1 and failed -
            % correctly, the reader being right and the test wrong.
            %
            % NOTE the scope of the cross-check below. It holds on THIS
            % file and its full day; it does NOT generalise. The RL03
            % file of 2008-01-20 uses head codes 1, 4, 5, 6, 7 and 8,
            % and there the same correspondence holds in only 57 % of
            % records. It is evidence about these bytes, not a law of
            % the product.
            testCase.verifyEqual(unique(aux.sca_id)', [1 4]);
            testCase.verifyEqual(aux.sca_id(1), 4);
            testCase.verifyEqual(sum(aux.sca_id == 4), 31);
            testCase.verifyEqual(sum(aux.sca_id == 1), 9);

            % And the two fields cross-check each other. sca_id sits at
            % byte 6 of the record and qualflg at byte 47, decoded
            % independently, yet "head 1" and qualflg bit 3 select
            % exactly the same records - here in all 40, and in 16 812
            % of the full day's 16 818 (the exceptions being the six
            % records from head 2). A wrong offset on either field
            % would destroy that correspondence.
            [bits, ~] = gracefoReading.decodeQualFlags(aux, 'qualflg');
            testCase.verifyEqual(aux.sca_id == 1, bits(:, 4), ...
                'sca_id and qualflg bit 3 must select the same records.');
            testCase.verifyEqual(obs(1,1), -0.7631110508696913, 'AbsTol', 1e-15);
            testCase.verifyEqual(obs(1,5), 3.5902978242414106e-05, 'AbsTol', 1e-19);

            % the oracle the layout was derived against, re-checked here
            [ok, stats] = gracefoReading.checkQuaternionNorm(obs, aux, ...
                'Tolerance', 1e-9);
            testCase.verifyTrue(all(ok), sprintf( ...
                'Quaternion norm violations: %d (max dev %.3g)', ...
                stats.numViolations, stats.maxDeviation));
        end

        function testGNV1B(testCase)
            f = testCase.fixture('GNV1B_2008-01-01_A_02.dat');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifySize(t, [40, 2]);
            % the orbit file starts a minute before midnight, so the
            % first epoch is on the PREVIOUS MJD - derived, not guessed
            testCase.verifyEqual(t(1,:), [54465, 86340], 'AbsTol', 1e-9);
            testCase.verifyEqual(numel(aux.obsNames), 12);
            testCase.verifyEqual(aux.coord_ref, repmat('E', 40, 1));
            testCase.verifyEqual(obs(1,1), 2787825.48771236, 'AbsTol', 1e-6);

            r = sqrt(sum(obs(:,1:3).^2, 2)) / 1e3;
            testCase.verifyGreaterThan(min(r), 6800);
            testCase.verifyLessThan(max(r), 6900);
            v = sqrt(sum(obs(:,7:9).^2, 2)) / 1e3;
            testCase.verifyGreaterThan(min(v), 7.0);
            testCase.verifyLessThan(max(v), 8.0);
        end

        function testKBR1B(testCase)
            f = testCase.fixture('KBR1B_2008-01-01_X_02.dat');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifySize(t, [40, 2]);
            testCase.verifyEqual(t(1,:), [54466, 0], 'AbsTol', 1e-9);
            testCase.verifyEqual(t(2,:), [54466, 5], 'AbsTol', 1e-9);  % 5 s
            testCase.verifyEqual(numel(aux.obsNames), 14);
            testCase.verifyFalse(isfield(aux, 'GRACE_id'), ...
                'KBR1B is the A+B link and carries no satellite id.');
            testCase.verifyEqual(obs(1,1), 164856.75098305332, 'AbsTol', 1e-8);

            iSnr = find(strcmp(aux.obsNames, 'K_A_SNR'));
            testCase.verifyEqual(obs(1, iSnr), 686, 'AbsTol', 1e-12);
            snr = obs(:, iSnr) / 10;
            testCase.verifyGreaterThan(min(snr), 40);
            testCase.verifyLessThan(max(snr), 80);
        end

        function testTHR1B(testCase)
            f = testCase.fixture('THR1B_2008-01-01_A_02.dat');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifySize(t, [40, 2]);
            % split tag, fractional part in MICROSECONDS
            testCase.verifyEqual(aux.timeVariable, 'time_intg+time_frac');
            testCase.verifyEqual(t(1,:), [54466, 337.487620], 'AbsTol', 1e-6);
            testCase.verifyEqual(numel(aux.obsNames), 42);
            testCase.verifyEqual(aux.obsNames{1}, 'thrust_count_att_ctrl_1_1');
            testCase.verifyEqual(obs(1,1), 587379, 'AbsTol', 1e-9);
            testCase.verifyEqual(aux.time_ref, repmat('G', 40, 1));
        end

        function testMAS1B(testCase)
            f = testCase.fixture('MAS1B_2008-01-01_A_02.dat');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifySize(t, [40, 2]);
            testCase.verifyEqual(t(1,:), [54466, 33.787684], 'AbsTol', 1e-6);
            testCase.verifyEqual(aux.obsNames, ...
                {'mass_thr','mass_thr_err','mass_tnk','mass_tnk_err', ...
                 'gas_mass_thr1','gas_mass_thr2','gas_mass_tnk1','gas_mass_tnk2'});

            % variable-length records: the first carries the tank set
            % only, so the thruster columns are NaN there
            testCase.verifyEqual(aux.prod_flag(1,:), '11001100');
            testCase.verifyTrue(isnan(obs(1,1)), 'mass_thr absent in record 1');
            testCase.verifyEqual(obs(1,3), 476.8510304779199, 'AbsTol', 1e-10);
            testCase.verifyEqual(obs(1,7), 10.725326967232618, 'AbsTol', 1e-12);

            % and where both are present they are the same spacecraft
            both = ~isnan(obs(:,1)) & ~isnan(obs(:,3));
            if any(both)
                testCase.verifyLessThan(max(abs(obs(both,1) - obs(both,3))), 0.5, ...
                    'Thruster- and tank-based mass must agree to well under a kg.');
            end
        end

        function testSCA1BRelease03(testCase)
            % RL03, issue #17's remaining caveat. The layouts were
            % measured on release 02 only, so nothing claimed to read
            % an RL03 file. Measured 2026-09-22: the record is 47 bytes
            % there too, and the quaternion oracle holds.
            f = testCase.fixture('SCA1B_2008-01-20_A_03.dat');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifyEqual(aux.headerFormat, 'classicBinary');
            testCase.verifySize(t, [40, 2]);
            testCase.verifyEqual(t(1,:), [54485, 0], 'AbsTol', 1e-9);
            % RL03 SCA1B is 1 Hz where the RL02 file is 5 s - a
            % difference in the product, not in the record layout
            testCase.verifyEqual(t(2,:), [54485, 1], 'AbsTol', 1e-9);
            testCase.verifyEqual(aux.obsNames, ...
                {'quatangle','quaticoeff','quatjcoeff','quatkcoeff','qual_rss'});
            testCase.verifyEqual(obs(1,1), 0.5137397438332172, 'AbsTol', 1e-15);
            testCase.verifyEqual(obs(1,5), 1.043471818915979e-06, 'AbsTol', 1e-20);

            [ok, stats] = gracefoReading.checkQuaternionNorm(obs, aux, ...
                'Tolerance', 1e-9);
            testCase.verifyTrue(all(ok), sprintf( ...
                'RL03 quaternion norm violations: %d (max dev %.3g)', ...
                stats.numViolations, stats.maxDeviation));

            % sca_id carries head codes RL02 never shows (7 throughout
            % this extract; the full day uses 1, 4, 5, 6, 7 and 8).
            % Recorded because the RL02 file's sca_id / qualflg bit 3
            % correspondence does NOT generalise - see the note in
            % testSCA1B.
            testCase.verifyEqual(unique(aux.sca_id), 7);
        end

        function testKBR1BRelease03MatchesRelease02(testCase)
            % The strongest evidence the KBR1B layout is right: two
            % files of the SAME day, produced independently in two
            % releases, decoded with one layout. The ranging
            % observables agree EXACTLY; only the reprocessed
            % antenna-centre correction differs, and by 1.7 micrometre.
            % A wrong offset could not produce that pattern.
            f02 = testCase.fixture('KBR1B_2008-01-01_X_02.dat');
            f03 = testCase.fixture('KBR1B_2008-01-01_X_03.dat');
            [t02, o02, a02] = gracefoReading.readL1b(f02);
            [t03, o03, a03] = gracefoReading.readL1b(f03);

            testCase.verifyEqual(a03.headerFormat, 'classicBinary');
            testCase.verifyEqual(t03, t02, ...
                'The two releases tag the same epochs.');
            testCase.verifyEqual(a03.obsNames, a02.obsNames);

            for name = ["biased_range", "range_rate", "range_accl", ...
                        "iono_corr", "K_A_SNR", "Ka_A_SNR", "K_B_SNR", "Ka_B_SNR"]
                i = strcmp(a02.obsNames, name);
                testCase.verifyEqual(o03(:, i), o02(:, i), sprintf( ...
                    '%s must be bit-identical between RL02 and RL03.', name));
            end

            % the one column that was reprocessed
            iAnt = strcmp(a02.obsNames, 'ant_centr_corr');
            d = max(abs(o03(:, iAnt) - o02(:, iAnt)));
            testCase.verifyGreaterThan(d, 0, ...
                'ant_centr_corr was reprocessed and must differ.');
            testCase.verifyLessThan(d, 1e-5, ...
                'and it must differ only at the micrometre level.');
        end

        function testMAG1B(testCase)
            % O-15, first half. The magnetometer and magnetorquer
            % product: 18 fields in 63 bytes, named from the GRACE
            % Level-1B Data Product User Handbook v1.3 section 6.8
            % (pp. 38-39), which tabulates them in this order with
            % these widths. The structural proof is the record length:
            % the full published file is 86 400 records over a
            % 5 443 200-byte data section, which is 63.0 bytes each
            % and admits no other field count at these widths.
            f = testCase.fixture('MAG1B_2008-01-01_A_02.dat');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifyEqual(aux.headerFormat, 'classicBinary');
            testCase.verifyEqual(aux.product, 'MAG1B');
            testCase.verifySize(t, [40, 2]);
            testCase.verifyEqual(aux.timeVariable, 'time_intg+time_frac');

            % The file opens ONE record before midnight, so the first
            % epoch is the last second of 2007-12-31 - the day the
            % header's TIME FIRST OBS names. Both epochs are the
            % reference decoder's to 1e-6 s.
            testCase.verifyEqual(t(1,:),   [54465, 86399.787692], 'AbsTol', 1e-6);
            testCase.verifyEqual(t(end,:), [54466,    38.787683], 'AbsTol', 1e-6);

            % 13 single-precision observation columns; the time frame,
            % the identifiers and qualflg go to aux.
            testCase.verifyEqual(aux.obsNames, ...
                {'MfvX_RAW','MfvY_RAW','MfvZ_RAW', ...
                 'torque1A','torque2A','torque3A', ...
                 'torque1B','torque2B','torque3B', ...
                 'MF_BCalX','MF_BCalY','MF_BCalZ','torque_cal'});
            testCase.verifySize(obs, [40, 13]);
            testCase.verifyEqual(aux.time_ref(1), 'G');
            testCase.verifyEqual(aux.GRACE_id(1), 'A');

            % First record, from the reference decoder. Single
            % precision widened to double, so ~7 significant digits.
            testCase.verifyEqual(obs(1, 1:3), ...
                [13.866063117980957, -4.9530167579650879, -25.6201171875], ...
                'AbsTol', 1e-9);
        end

        function testMAG1BFieldStrengthIsGeomagnetic(testCase)
            % The oracle that makes the handbook's column ORDER
            % evidence rather than assertion: if MfvX/Y/Z were not the
            % first three floats, their norm would not be a magnetic
            % field strength. Measured over the full published day it
            % is 18.3-54.5 uT on GRACE A and 19.5-54.4 uT on GRACE B -
            % the geomagnetic field at 480 km. The bundled 40-record
            % extract covers 40 s of one pass and sits in 28.3-29.9.
            f = testCase.fixture('MAG1B_2008-01-01_A_02.dat');
            [~, obs, aux] = gracefoReading.readL1b(f);

            iB = cellfun(@(n) find(strcmp(aux.obsNames, n)), ...
                {'MfvX_RAW','MfvY_RAW','MfvZ_RAW'});
            B = sqrt(sum(obs(:, iB).^2, 2));
            testCase.verifyGreaterThan(min(B), 18);
            testCase.verifyLessThan(max(B), 56);
            testCase.verifyEqual([min(B), max(B)], ...
                [28.305906, 29.885471], 'AbsTol', 1e-5);

            % The calibration columns are constants of the instrument,
            % not a signal, and torque_cal is the 120 mA full scale the
            % six current columns never exceed.
            cal = cellfun(@(n) find(strcmp(aux.obsNames, n)), ...
                {'MF_BCalX','MF_BCalY','MF_BCalZ','torque_cal'});
            testCase.verifyEqual(unique(obs(:, cal), 'rows'), ...
                [54, 54, 53, 120]);
            iTq = cellfun(@(n) find(strcmp(aux.obsNames, n)), ...
                {'torque1A','torque2A','torque3A', ...
                 'torque1B','torque2B','torque3B'});
            tq = obs(:, iTq);
            testCase.verifyGreaterThanOrEqual(min(tq(:)), 0);
            testCase.verifyLessThanOrEqual(max(tq(:)), 120);
        end

        function testAHK1B(testCase)
            % O-15, second half and last. The accelerometer
            % housekeeping product is the only classic record whose
            % conditional columns do NOT share a type, and the only
            % one whose prod_flag is four bytes rather than one. Both
            % facts come from the JPL read software; both are checked
            % here against real bytes.
            f = testCase.fixture('AHK1B_2008-01-01_A_02.dat');
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifyEqual(aux.headerFormat, 'classicBinary');
            testCase.verifyEqual(aux.product, 'AHK1B');
            testCase.verifySize(t, [40, 2]);
            testCase.verifyEqual(aux.timeVariable, 'rcvtime_intg+rcvtime_frac');
            testCase.verifyEqual(t(1,:),   [54465, 86100.792110], 'AbsTol', 1e-6);
            testCase.verifyEqual(t(end,:), [54466,    90.844163], 'AbsTol', 1e-6);
            testCase.verifyEqual(aux.time_ref(1), 'G');
            testCase.verifyEqual(aux.GRACE_id(1), 'A');

            % A 32-character prod_flag, not 8. This is the assertion
            % that would have been wrong under every other classic
            % product's flag width.
            testCase.verifySize(aux.prod_flag, [40, 32]);
            testCase.verifyTrue(all(ismember(aux.prod_flag(:), '01')));
            testCase.verifySize(aux.qualflg, [40, 8]);

            % Exactly the two patterns this day uses: 34 records carry
            % the short set, 6 carry the long one that adds the
            % temperatures, the supply rails and the status byte.
            [bits, ~] = gracefoReading.decodeQualFlags(aux, 'prod_flag');
            testCase.verifySize(bits, [40, 32]);
            iTesu = strcmp(aux.obsNames, 'tesu');
            testCase.verifyEqual(sum(~isnan(obs(:, iTesu))), 6);
            testCase.verifyEqual(sum(isnan(obs(:, iTesu))), 34);
            % bit 14 is tesu, and the flag must agree with the data
            testCase.verifyEqual(bits(:, 15), ~isnan(obs(:, iTesu)));

            % bias_vol (bit 6, double) is in every record; the six
            % linear/angular acceleration columns never are - AHK1B
            % carries housekeeping, the accelerations live in ACC1B.
            iBias = strcmp(aux.obsNames, 'bias_vol');
            testCase.verifyTrue(all(~isnan(obs(:, iBias))));
            iLin = strcmp(aux.obsNames, 'lin_accl_x');
            testCase.verifyTrue(all(isnan(obs(:, iLin))));

            % First record, from the reference decoder. bias_vol is a
            % double and keeps ~16 digits; vd and x1_out are floats.
            testCase.verifyEqual(obs(1, iBias), 10.157606470504755, ...
                'AbsTol', 1e-12);
            iVd = strcmp(aux.obsNames, 'vd');
            testCase.verifyEqual(obs(1, iVd), 4.9098706245422363, ...
                'AbsTol', 1e-9);
            iBlk = strcmp(aux.obsNames, 'icu_blk_nr');
            testCase.verifyEqual(obs(1, iBlk), 17090);
        end

        function testAHK1BSupplyRailsAreAtTheirNominalVoltages(testCase)
            % The oracle that makes the per-bit TYPE table evidence
            % rather than assertion. Read one width wrong anywhere in
            % the walk and every field after it is garbage; these are
            % named voltages, so they have to come out at their
            % nominal values or the layout is wrong.
            f = testCase.fixture('AHK1B_2008-01-01_A_02.dat');
            [~, obs, aux] = gracefoReading.readL1b(f);

            nominal = {'v15picu',  14.9095,  14.9213
                       'v15micu', -14.9124, -14.9006
                       'vr5picu',   5.0543,   5.0745
                       'v15psu',   14.0135,  14.0250
                       'v15msu',  -14.0350, -14.0005
                       'v48psu',   50.1770,  50.2080
                       'v48msu',  -50.4180, -50.3560};
            for k = 1:size(nominal, 1)
                col = obs(:, strcmp(aux.obsNames, nominal{k,1}));
                col = col(~isnan(col));
                testCase.verifyEqual(numel(col), 6, sprintf( ...
                    '%s is present in the six long-format records.', ...
                    nominal{k,1}));
                testCase.verifyEqual([min(col), max(col)], ...
                    [nominal{k,2}, nominal{k,3}], 'AbsTol', 1e-3, ...
                    sprintf('%s must sit at its nominal rail voltage.', ...
                    nominal{k,1}));
            end

            % Four temperatures, all plausible for powered electronics
            % in orbit, and the proof-mass bias voltage in every record.
            for name = ["tesu", "taicu", "tisu", "tcicu"]
                col = obs(:, strcmp(aux.obsNames, name));
                col = col(~isnan(col));
                testCase.verifyGreaterThan(min(col), 15);
                testCase.verifyLessThan(max(col), 60);
            end
            bias = obs(:, strcmp(aux.obsNames, 'bias_vol'));
            testCase.verifyEqual([min(bias), max(bias)], ...
                [10.1573, 10.1576], 'AbsTol', 1e-3);
        end

        function testClassicAsciiMatchesItsBinaryTwin(testCase)
            % What retires the classicExperimental warning. For each
            % bundled pair the ASCII file is the SAME 40 records as
            % the binary one, written by the producer's own format, so
            % every column has to come back the same. A wrong ASCII
            % column order yields plausible numbers rather than an
            % error, which is why this is checked and not argued.
            for name = ["ACC1B", "MAG1B", "MAS1B"]
                stem = sprintf('%s_2008-01-01_A_02', name);
                [tB, oB, aB] = gracefoReading.readL1b( ...
                    testCase.fixture([stem '.dat']));
                [tA, oA, aA] = gracefoReading.readL1b( ...
                    testCase.fixture([stem '.asc']));

                testCase.verifyEqual(aA.headerFormat, 'classic');
                testCase.verifyEqual(aB.headerFormat, 'classicBinary');
                testCase.verifyEqual(aA.obsNames, aB.obsNames, sprintf( ...
                    '%s: the two variants must expose the same observations.', name));
                testCase.verifyEqual(tA, tB, 'AbsTol', 1e-6, sprintf( ...
                    '%s: epochs must agree between the variants.', name));
                testCase.verifyEqual(oA, oB, 'RelTol', 1e-12, 'AbsTol', 1e-20, ...
                    sprintf('%s: observations must agree between the variants.', name));
                testCase.verifyEqual(aA.qualflg, aB.qualflg, sprintf( ...
                    '%s: qualflg is a bit string in both variants.', name));
            end
        end

        function testMAG1BAsciiSwapsTimeRefAndGraceId(testCase)
            % The fact that could not be inferred, and the reason the
            % warning existed. WrAsciiMAG1XFRecord.c prints GRACE_id
            % BEFORE time_ref - the opposite of the binary record and
            % of every other classic product. Read in binary order the
            % two chars come back exchanged, which no numeric check
            % would ever catch.
            [~, ~, aA] = gracefoReading.readL1b( ...
                testCase.fixture('MAG1B_2008-01-01_A_02.asc'));
            [~, ~, aB] = gracefoReading.readL1b( ...
                testCase.fixture('MAG1B_2008-01-01_A_02.dat'));

            testCase.verifyEqual(aA.GRACE_id(1), 'A');
            testCase.verifyEqual(aA.time_ref(1), 'G');
            testCase.verifyEqual(aA.GRACE_id, aB.GRACE_id);
            testCase.verifyEqual(aA.time_ref, aB.time_ref);

            % and the layout says so, rather than the parser knowing it
            L = gracefoReading.internal.classicLayout('MAG1B');
            testCase.verifyEqual(L.names{3}, 'time_ref');
            testCase.verifyEqual(L.names{4}, 'GRACE_id');
            testCase.verifyEqual(L.asciiNames{3}, 'GRACE_id');
            testCase.verifyEqual(L.asciiNames{4}, 'time_ref');
            % every other product prints them in binary order
            for name = ["THR1B", "MAS1B", "AHK1B"]
                Lo = gracefoReading.internal.classicLayout(name);
                testCase.verifyEqual(Lo.asciiNames, Lo.names, sprintf( ...
                    '%s prints its columns in binary order.', name));
            end
        end

        function testAHK1BAsciiStatusAndFractionalSecond(testCase)
            % Two silent corruptions this file would have caused before
            % 2026-09-22, neither of which raises anything:
            %   `status` is written as EIGHT BIT CHARACTERS, so read as
            %   a decimal it is 10111111 instead of 191;
            %   the split tag is rcvtime_frac, not time_frac, so the
            %   microsecond rule missed it and the fraction scaled by 1
            %   - putting every epoch out by a factor of a million.
            f = testCase.fixture('AHK1B_2008-01-01_A_02.asc');
            [tA, oA, aA] = gracefoReading.readL1b(f);
            [tB, oB, aB] = gracefoReading.readL1b( ...
                testCase.fixture('AHK1B_2008-01-01_A_02.dat'));

            testCase.verifyEqual(aA.timeVariable, 'rcvtime_intg+rcvtime_frac');
            testCase.verifyEqual(tA, tB, 'AbsTol', 1e-6);
            testCase.verifyEqual(tA(1,:), [54465, 86100.792110], 'AbsTol', 1e-6);

            iSt = strcmp(aA.obsNames, 'status');
            st = oA(:, iSt);
            testCase.verifyEqual(sum(~isnan(st)), 6, ...
                'status rides prod_flag bit 25, set in six of the forty records.');
            testCase.verifyEqual(unique(st(~isnan(st))), 1, ...
                'Decoded from "00000001", not read as the decimal 1.');
            testCase.verifyEqual(st, oB(:, iSt), ...
                'status must agree with the binary variant, NaN pattern included.');

            % a 32-character prod_flag survives the ASCII path too
            testCase.verifySize(aA.prod_flag, [40, 32]);
            testCase.verifyEqual(aA.prod_flag, aB.prod_flag);

            % The producer writes AHK1B's single-precision columns with
            % %.10g, so the ASCII variant is NOT lossless for them -
            % measured 3.3e-10 relative. Its one double column is
            % written %.16g and is exact.
            testCase.verifyEqual(oA, oB, 'RelTol', 1e-9, 'AbsTol', 1e-20);
            iBias = strcmp(aA.obsNames, 'bias_vol');
            testCase.verifyEqual(oA(1, iBias), 10.157606470504755, 'AbsTol', 1e-12);
        end

        function testClassicAsciiNoLongerWarns(testCase)
            % The retirement itself. A measured layout is a measured
            % layout in either variant.
            for nm = ["ACC1B", "MAG1B", "MAS1B", "AHK1B"]
                f = testCase.fixture(sprintf('%s_2008-01-01_A_02.asc', nm));
                testCase.verifyWarningFree(@() gracefoReading.readL1b(f), ...
                    sprintf('Classic ASCII %s is measured and must not warn.', nm));
            end
        end

        function testClassicQualflgIsABitStringLikeEverywhereElse(testCase)
            % V-8 asked whether classic qualflg is a bit string or a
            % number. Measured: in the binary files it is a single BYTE.
            % The reader renders it as the 8-character string the rest
            % of the toolbox speaks, so decodeQualFlags works unchanged.
            f = testCase.fixture('SCA1B_2008-01-01_A_02.dat');
            [~, ~, aux] = gracefoReading.readL1b(f);
            testCase.verifyClass(aux.qualflg, 'char');
            testCase.verifySize(aux.qualflg, [40, 8]);
            testCase.verifyTrue(all(ismember(aux.qualflg(:), '01')));

            [bits, report] = gracefoReading.decodeQualFlags(aux, 'qualflg');
            testCase.verifySize(bits, [40, 8]);
            testCase.verifyEqual(height(report), 8);
            % bit 0 is the rightmost character, as everywhere else
            testCase.verifyEqual(bits(:,1), aux.qualflg(:,end) == '1');
        end

        function testTruncatedFileIsRefused(testCase)
            % Fault injection. A wrong record length yields numbers that
            % look perfectly plausible, so this must be an error.
            src = testCase.fixture('SCA1B_2008-01-01_A_02.dat');
            % byte I/O throughout: fileread would apply the file
            % encoding and mangle the very bytes under test
            fidIn = fopen(src, 'r');
            bytes = fread(fidIn, inf, '*uint8');
            fclose(fidIn);
            cut = fullfile(testCase.workDir, 'SCA1B_2008-01-01_A_02.dat');
            fid = fopen(cut, 'w');
            fwrite(fid, bytes(1:end-13), 'uint8');   % lose a third of a record
            fclose(fid);
            testCase.verifyError(@() gracefoReading.readL1b(cut), ...
                'gracefoReading:readL1b:classicRecordMismatch');
        end

        function testColumnNamesAreRefusedForBinary(testCase)
            f = testCase.fixture('ACC1B_2008-01-01_A_02.dat');
            testCase.verifyError(@() gracefoReading.readL1b(f, ...
                'ColumnNames', ["a","b","c"]), ...
                'gracefoReading:readL1b:columnNamesNotForBinary');
        end

        function testUnmeasuredClassicProductIsRefused(testCase)
            % TNK1B has no layout here: no real file has been read and
            % no column table was taken from anywhere, so it is
            % refused rather than decoded on a guess. AHK1B used to
            % stand here and no longer does - it is measured now.
            f = fullfile(testCase.workDir, 'TNK1B_2008-01-01_A_02.dat');
            fid = fopen(f, 'w');
            hdr = ['FILE FORMAT 0=BINARY 1=ASCII  : 0', newline, ...
                   'NUMBER OF DATA RECORDS        : 2', newline, ...
                   'END OF HEADER', newline];
            fwrite(fid, hdr, 'char');
            fwrite(fid, zeros(1, 126, 'uint8'), 'uint8');
            fclose(fid);
            testCase.verifyError(@() gracefoReading.readL1b(f), ...
                'gracefoReading:readL1b:unsupportedClassicProduct');
        end

        function testClassicUnitsFromHandbook(testCase)
            % 1.3.0: the units classic headers lack, from D-22027 ch. 6
            % (6.2 ACC1B, 6.11 THR1B, 6.7 KBR1B), spelled as the GRACE-FO
            % headers spell the same quantity.
            [~, ~, a] = gracefoReading.readL1b(testCase.fixture('ACC1B_2008-01-01_A_02.dat'));
            u = a.variableUnits;
            testCase.verifyEqual({u.gps_time, u.lin_accl_x, u.ang_accl_z, u.acl_y_res}, ...
                {'seconds', 'm/s2', 'rad/s2', 'm/s2'});
            testCase.verifyEqual(u.GRACE_id, 'char');

            [~, ~, t] = gracefoReading.readL1b(testCase.fixture('THR1B_2008-01-01_A_02.dat'));
            u = t.variableUnits;
            testCase.verifyEqual({u.time_intg, u.time_frac, u.on_time_att_ctrl_1_1, ...
                u.on_time_orb_ctrl_2, u.accum_dur_att_ctrl}, ...
                {'seconds', 'microseconds', 'milliseconds', 'milliseconds', 'milliseconds'});
            testCase.verifyFalse(isfield(u, 'thrust_count_att_ctrl_1_1'), ...
                'A thrust count has no unit in the handbook.');

            [~, ~, k] = gracefoReading.readL1b(testCase.fixture('KBR1B_2008-01-01_X_02.dat'));
            u = k.variableUnits;
            testCase.verifyEqual({u.biased_range, u.range_rate, u.range_accl, u.K_A_SNR}, ...
                {'m', 'm/s', 'm/s2', '0.1 dB-Hz'});
        end

        function testClassicQualflgMeaningsFromHandbook(testCase)
            % 1.3.0: decodeQualFlags reported every classic bit as
            % "(not documented)". SCA1B bit 3 is the bit the sca_id test
            % above cross-checks, so its meaning is anchored in the data.
            [~, ~, a] = gracefoReading.readL1b(testCase.fixture('ACC1B_2008-01-01_A_02.dat'));
            [~, r] = gracefoReading.decodeQualFlags(a);
            testCase.verifyEqual(r.meaning([1 6 8])', [ ...
                "Proof mass voltage out of nominal range", ...
                "filled data > 15s from fit center", "filled data < 5s from fit center"]);

            [~, ~, k] = gracefoReading.readL1b(testCase.fixture('KBR1B_2008-01-01_X_02.dat'));
            [~, r] = gracefoReading.decodeQualFlags(k);
            testCase.verifyEqual(r.meaning(1), "phase break");
            testCase.verifyEqual(r.meaning(7), "filled data > 5s from fit center");

            [~, ~, c] = gracefoReading.readL1b(testCase.fixture('SCA1B_2008-01-01_A_02.dat'));
            [bits, r] = gracefoReading.decodeQualFlags(c);
            testCase.verifyEqual(r.meaning(4), "data from 1 star camera only");
            testCase.verifyEqual(c.sca_id == 1, bits(:, 4));
            testCase.verifyFalse(any(r.meaning == "(not documented)"));
        end

        function testClassicAsciiAndBinaryDescribeAlike(testCase)
            % Metamorphic: the two variants of one product, read by two
            % parsers, must describe their columns identically.
            for nm = ["ACC1B", "MAG1B", "MAS1B"]
                [~, ~, b] = gracefoReading.readL1b(testCase.fixture(nm + "_2008-01-01_A_02.dat"));
                [~, ~, s] = gracefoReading.readL1b(testCase.fixture(nm + "_2008-01-01_A_02.asc"));
                testCase.verifyEqual(orderfields(s.variableUnits), ...
                    orderfields(b.variableUnits), nm);
                testCase.verifyEqual(s.variableAttributes.qualflg.flag_meanings, ...
                    b.variableAttributes.qualflg.flag_meanings, nm);
            end
            [~, r] = gracefoReading.decodeQualFlags(b, 'prod_flag');     % MAS1B
            testCase.verifyEqual(r.meaning(7), "gas mass tank 1 (tank obs)");
        end

        function testAhk1bStatesNoUnits(testCase)
            % AHK1B has no table in D-22027 chapter 6; the read software
            % it is named from states no units. Nothing is guessed.
            [~, ~, a] = gracefoReading.readL1b(testCase.fixture('AHK1B_2008-01-01_A_02.dat'));
            u = a.variableUnits;
            testCase.verifyEqual(u.rcvtime_frac, 'microseconds');
            testCase.verifyFalse(isfield(u, 'lin_accl_x'));
            testCase.verifyFalse(isfield(a.variableAttributes.qualflg, 'flag_meanings'));
        end

        function testTimeRangeAndQualityStillApply(testCase)
            % The classic path must reach the same post-parse machinery
            % as the GRACE-FO path, not a parallel one.
            f = testCase.fixture('ACC1B_2008-01-01_A_02.dat');
            t = gracefoReading.readL1b(f, 'TimeRange', [54466, 54466 + 9/86400]);
            testCase.verifySize(t, [10, 2]);

            tAll = gracefoReading.readL1b(f, 'TimeFormat', 'datetime');
            testCase.verifyClass(tAll, 'datetime');
            testCase.verifySize(tAll, [40, 1]);

            ns = gracefoReading.readL1b(f, 'TimeFormat', 'gpsns');
            testCase.verifyClass(ns, 'int64');
            testCase.verifyEqual(ns(1), int64(252417600) * int64(1e9));
        end

    end
end
