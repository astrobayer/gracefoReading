classdef testReadL1b < matlab.unittest.TestCase
%TESTREADL1B  Unit tests for gracefoReading.readL1b and its parsing core.
%
%   DESCRIPTION
%     Synthetic-fixture suite: each test writes a small L1B-like file
%     with a known header and known records, reads it back and checks
%     the parsed result. Fixtures are written to a temporary folder
%     that is removed on teardown, so the suite is independent of any
%     data archive. Real-file behaviour is covered separately by
%     testRealData.
%
%     Run with:
%       results = runtests('testReadL1b'); table(results)
%
%   COVERAGE
%     - YAML header parsing, both declaration styles
%     - time tags: single gps_time and split intg+frac, unit-aware
%       fractional scaling, MJD conversion, day rollover; CLK1B's single
%       rcv_time column detected without an override (#29)
%     - zero time tags (#29): counted in aux.numRecordsZeroTime and
%       reported by the zeroTime warning; 'DropZeroTime' removes
%       exactly those records and the warning says so
%     - 'TimeFormat': mjd, datetime and exact int64 gpsns arithmetic
%     - column classification: observations, char columns, identifiers,
%       bit-string flags
%     - the rest-of-line column the long-format housekeeping products
%       declare ("Entire remaining portion of each record"): its spaces
%       survive verbatim, a surplus token under a header that makes no
%       such claim is still refused, and a short record still is (G-04)
%     - prod_flag variable-length records and NaN filling, for MAS1B
%       gas masses and for AHK1B-style housekeeping temperatures
%     - declared names that are not MATLAB identifiers and that
%       collide under makeValidName (AHK1B's "TSU Y+" / "TSU Y-" /
%       "TSU Z-"): kept verbatim, mapped to distinct aux fields, and
%       reported by the variableNameAdjusted warning, which stays
%       silent on a header whose names are already valid (G-04)
%     - quality filtering: 'ApplyQualityFlags', selective
%       'QualityBitMask', and the conflicting-options error
%     - 'TimeRange' filtering with double and datetime bounds
%     - content-hashed caching: write, hit, post-parse options from
%       cache, and invalidation on content change
%     - classic GRACE path: built-in layout, 'ColumnNames' override,
%       experimental warning and unsupported-product error
%     - gzip input, row-integrity errors and every documented error id
%
%   ACCURACY AND LIMITATIONS
%     - Numerical comparisons use explicit tolerances (typically
%       1e-12 relative for observations, exact equality for int64
%       nanoseconds and for character data).
%     - Synthetic fixtures encode the header conventions found in the
%       real PO.DAAC RL04 files; they cannot prove that a future
%       release keeps those conventions, which is why testRealData
%       runs against bundled real files.
%     - The suite does not measure performance; timing is exercised
%       only qualitatively by the cache test.
%
%   EXAMPLE
%     results = runtests('testReadL1b');
%     disp(table(results));
%
%   Toolbox:  gracefoReading v1.3.0
%   Created:  2026-08-01
%   Updated:  2026-09-27
%   Author:   Matthias Weigelt with support of Anthropic Claude

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
        function f = writeActLike(testCase, gpsTimes, opts)
            % Synthetic ACT1B-style file, real RL04 header layout.
            arguments
                testCase
                gpsTimes (:,1) double
                opts.DeclaredCount double = numel(gpsTimes)
                opts.BadRow double = 0
                opts.Qualflg string = "00000000"
                opts.Name string = "ACT1B_synth.txt"
            end
            f = fullfile(testCase.workDir, char(opts.Name));
            fid = fopen(f, 'wt');
            fprintf(fid, 'header:\n  dimensions:\n    num_records: %d\n', opts.DeclaredCount);
            fprintf(fid, '  global_attributes:\n    title: synthetic ACT1B\n');
            fprintf(fid, '  variables:\n');
            addVar = @(name, unit) fprintf(fid, ...
                '    - %s:\n        comment: column\n        units: %s\n', name, unit);
            addVarNoUnit = @(name) fprintf(fid, ...
                '    - %s:\n        comment: column\n', name);
            addVar('gps_time', 'second');
            addVar('GRACEFO_id', 'char');
            addVar('lin_accl_x', 'm/s2');
            addVar('lin_accl_y', 'm/s2');
            addVar('lin_accl_z', 'm/s2');
            addVarNoUnit('sca_id');
            fprintf(fid, ['    - qualflg:\n        comment: column\n', ...
                '        flag_masks: 1b, 2b\n        flag_meanings:\n', ...
                '          - bit 0 = Test bit zero\n          - bit 1 = Test bit one\n']);
            fprintf(fid, '# End of YAML header\n');
            for k = 1:numel(gpsTimes)
                if k == opts.BadRow
                    fprintf(fid, '%.6f C %.9e %.9e\n', gpsTimes(k), 1e-6*k, 2e-6*k);
                else
                    fprintf(fid, '%.6f C %.9e %.9e %.9e 23 %s\n', gpsTimes(k), ...
                        1e-6*k, 2e-6*k, 3e-6*k, char(opts.Qualflg));
                end
            end
            fclose(fid);
        end

        function f = writeMasLike(testCase, intg, fracMicro, prodFlags, values)
            % Synthetic MAS1B-style file: time_intg + time_frac
            % (microseconds) and prod_flag-driven variable-length rows.
            % values: cell array, one numeric row vector per record with
            % as many entries as bits set in prodFlags{k}.
            f = fullfile(testCase.workDir, 'MAS1B_synth.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, 'header:\n  dimensions:\n    num_records: %d\n', numel(intg));
            fprintf(fid, '  variables:\n');
            fprintf(fid, '    - time_intg:\n        units: seconds\n');
            fprintf(fid, '    - time_frac:\n        units: microseconds\n');
            fprintf(fid, '    - time_ref:\n        units: char\n');
            fprintf(fid, '    - GRACEFO_id:\n        units: char\n');
            fprintf(fid, '    - qualflg:\n        comment: column\n');
            fprintf(fid, ['    - prod_flag:\n        flag_meanings:\n', ...
                '          - bit 0 = mass_a\n          - bit 1 = mass_b\n', ...
                '          - bit 2 = mass_c\n']);
            fprintf(fid, '    - mass_a:\n        units: kg\n');
            fprintf(fid, '    - mass_b:\n        units: kg\n');
            fprintf(fid, '    - mass_c:\n        units: kg\n');
            fprintf(fid, '# End of YAML header\n');
            for k = 1:numel(intg)
                fprintf(fid, '%d %d G C 00000000 %s', intg(k), fracMicro(k), prodFlags{k});
                fprintf(fid, ' %.10g', values{k});
                fprintf(fid, '\n');
            end
            fclose(fid);
        end

        function f = writeAhkLike(testCase, intg, prodFlags, values)
            % Synthetic AHK1B-style file (V-13, issue #19). Two things
            % that no other fixture has and that real AHK1B has:
            %   - prod_flag-controlled variable columns for ordinary
            %     numeric housekeeping, not only for MAS1B gas masses;
            %   - declared names that are not MATLAB identifiers and
            %     that collapse onto one another under makeValidName:
            %     "TSU_Y+" / "TSU_Y-" / "TSU_Z+" all map to TSU_Y_ or
            %     TSU_Z_, and the real header carries one name with a
            %     SPACE, "TSU Z-".
            % values: cell array, one numeric row vector per record,
            % as many entries as bits set in prodFlags{k}.
            f = fullfile(testCase.workDir, 'AHK1B_synth.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, 'header:\n  dimensions:\n    num_records: %d\n', numel(intg));
            fprintf(fid, '  variables:\n');
            fprintf(fid, '    - time_intg:\n        units: seconds\n');
            fprintf(fid, '    - time_frac:\n        units: microseconds\n');
            fprintf(fid, '    - time_ref:\n        units: char\n');
            fprintf(fid, '    - GRACEFO_id:\n        units: char\n');
            fprintf(fid, '    - qualflg:\n        comment: column\n');
            fprintf(fid, ['    - prod_flag:\n        flag_meanings:\n', ...
                '          - bit 0 = TSU_Y+\n          - bit 1 = TSU_Y-\n', ...
                '          - bit 2 = TSU_Z+\n          - bit 3 = TSU Z-\n']);
            names = {'TSU_Y+', 'TSU_Y-', 'TSU_Z+', 'TSU Z-'};
            for k = 1:numel(names)
                fprintf(fid, '    - %s:\n        units: degC\n        long_name: %s\n', ...
                    names{k}, ['temperature ', names{k}]);
            end
            fprintf(fid, '# End of YAML header\n');
            for k = 1:numel(intg)
                fprintf(fid, '%d 0 G C 00000000 %s', intg(k), prodFlags{k});
                fprintf(fid, ' %.10g', values{k});
                fprintf(fid, '\n');
            end
            fclose(fid);
        end

        function f = writeLhkLike(testCase, records, declareRemaining)
            % Synthetic LHK1B-style file (issue #19). The long-format
            % housekeeping products end in a free-text column that the
            % real header describes as
            %     comment: Entire remaining portion of each record
            % and 2 886 of the 1 169 274 records of the real
            % LHK1B_2020-01-01_C_04 use that licence, carrying a SPACE
            % in the sensor name. declareRemaining false writes the
            % same records with that sentence removed, which is the
            % fault injection: the surplus token must then still be
            % refused.
            f = fullfile(testCase.workDir, 'LHK1B_synth.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, 'header:\n  dimensions:\n    num_records: %d\n', numel(records));
            fprintf(fid, '  variables:\n');
            fprintf(fid, '    - time_intg:\n        units: seconds\n');
            fprintf(fid, '    - time_frac:\n        units: nanoseconds\n');
            fprintf(fid, '    - time_ref:\n        units: char\n');
            fprintf(fid, '    - GRACEFO_id:\n        units: char\n');
            fprintf(fid, '    - qualflg:\n        comment: column\n');
            fprintf(fid, '    - sensortype:\n        units: char\n');
            fprintf(fid, ['    - sensorvalue:\n', ...
                '        long_name: Value of observation\n']);
            if declareRemaining
                fprintf(fid, ['    - sensorname:\n', ...
                    '        comment: Entire remaining portion of each record\n', ...
                    '        long_name: Sensor name.  Max number of characters = 1,000\n']);
            else
                fprintf(fid, ['    - sensorname:\n', ...
                    '        long_name: Sensor name\n']);
            end
            fprintf(fid, '# End of YAML header\n');
            for k = 1:numel(records)
                fprintf(fid, '%d %d G C 00000000 ? %d %s\n', ...
                    631108800 + k - 1, 100000 * k, 40 + k, records{k});
            end
            fclose(fid);
        end

        function f = writeMagLike(testCase, intg, fracNano, values)
            % Synthetic MAG1B-style file: time_intg + time_frac declared in
            % NANOSECONDS, the unit that made MAG1B unreadable (issue #9).
            % The valid_range is written as the real header carries it,
            % 0 to 999999999, because that range is what confirms the unit.
            f = fullfile(testCase.workDir, 'MAG1B_synth.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, 'header:\n  dimensions:\n    num_records: %d\n', numel(intg));
            fprintf(fid, '  variables:\n');
            fprintf(fid, '    - time_intg:\n        units: seconds\n');
            fprintf(fid, ['    - time_frac:\n        long_name: Fractional portion of time tag\n', ...
                '        units: nanoseconds\n        valid_range: 0, 999999999\n']);
            fprintf(fid, '    - time_ref:\n        units: char\n');
            fprintf(fid, '    - GRACEFO_id:\n        units: char\n');
            fprintf(fid, '    - MfvX_RAW:\n        units: microTesla\n');
            fprintf(fid, '    - qualflg:\n        comment: column\n');
            fprintf(fid, '# End of YAML header\n');
            for k = 1:numel(intg)
                fprintf(fid, '%d %d G C %.10g 00000000\n', ...
                    intg(k), fracNano(k), values(k));
            end
            fclose(fid);
        end

        function f = writeLegacyStyle(testCase, gpsTimes)
            % Legacy "- name: varname" declaration style.
            f = fullfile(testCase.workDir, 'LEGACY_synth.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, 'header:\n  dimensions:\n    num_records: %d\n', numel(gpsTimes));
            fprintf(fid, '  variable_descriptions:\n');
            fprintf(fid, '    - name: gps_time\n      units: second\n');
            fprintf(fid, '    - name: obs_value\n      units: m\n');
            fprintf(fid, '# End of YAML header\n');
            for k = 1:numel(gpsTimes)
                fprintf(fid, '%.6f %.6f\n', gpsTimes(k), 10*k);
            end
            fclose(fid);
        end
    end

    methods (Test)

        function testBasicShapesAndClassification(testCase)
            f = testCase.writeActLike([0; 43200; 86400]);
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifySize(t, [3, 2]);
            testCase.verifySize(obs, [3, 3]);
            testCase.verifyEqual(aux.obsNames, {'lin_accl_x','lin_accl_y','lin_accl_z'});
            % sca_id numeric but *_id -> aux; GRACEFO_id char -> aux
            testCase.verifyEqual(aux.sca_id, [23; 23; 23]);
            testCase.verifyEqual(aux.GRACEFO_id, ['C';'C';'C']);
            testCase.verifyEqual(aux.product, 'ACT1B');
        end

        function testTimeEpochAndRollover(testCase)
            f = testCase.writeActLike([0; 43200; 86400]);
            t = gracefoReading.readL1b(f);
            testCase.verifyEqual(t(1,:), [51544, 43200], 'AbsTol', 1e-9);
            testCase.verifyEqual(t(2,:), [51545, 0],     'AbsTol', 1e-9);
            testCase.verifyEqual(t(3,:), [51545, 43200], 'AbsTol', 1e-9);
        end

        function testMicrosecondFracScaling(testCase)
            % time_frac declared in microseconds must be scaled by 1e-6.
            f = testCase.writeMasLike([0; 3600], [990452; 500000], ...
                {'001','001'}, {1.5, 2.5});
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifyEqual(aux.timeVariable, 'time_intg+time_frac');
            testCase.verifyEqual(t(1,:), [51544, 43200.990452], 'AbsTol', 1e-9);
            testCase.verifyEqual(t(2,:), [51544, 46800.5], 'AbsTol', 1e-9);
            testCase.verifyEqual(obs(:,1), [1.5; 2.5], 'AbsTol', 1e-12);
        end

        function testNanosecondFracScaling(testCase)
            % issue #9: MAG1B declares time_frac in nanoseconds and was
            % unreadable - localFracScale refused the unit. 500000000 ns
            % must land half a second after the integer tag, which pins
            % the scale (1e-9) and the sign in one assertion.
            f = testCase.writeMagLike([0; 3600], [500000000; 999999999], [1.5; 2.5]);
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifyEqual(aux.timeVariable, 'time_intg+time_frac');
            testCase.verifyEqual(t(1,:), [51544, 43200.5], 'AbsTol', 1e-9);
            testCase.verifyEqual(t(2,:), [51544, 46800.999999999], 'AbsTol', 1e-9);
            testCase.verifyEqual(obs(:,1), [1.5; 2.5], 'AbsTol', 1e-12);
        end

        function testNanosecondFracIsExactInGpsns(testCase)
            % The scale must not cost the int64 exactness guarantee. The
            % double round trip round(fracScale*frac*1e9) was checked
            % exhaustively over 0..999999999 offline; this pins the two
            % boundary values in MATLAB, where int64 arithmetic is what
            % actually runs.
            f = testCase.writeMagLike([0; 3600], [500000000; 999999999], [1.5; 2.5]);
            t = gracefoReading.readL1b(f, 'TimeFormat', 'gpsns');

            testCase.verifyClass(t, 'int64');
            testCase.verifyEqual(t(1), int64(500000000));
            testCase.verifyEqual(t(2), int64(3600) * 1000000000 + int64(999999999));
        end

        function testNanosecondUnitIsNotGuessedFromASibling(testCase)
            % Across GRACE-C RL04 the unit is a property of the file: MAG1B
            % declares nanoseconds, MAS1B microseconds. The same frac digits
            % must therefore give different epochs, and a reader that
            % guessed from the product family would return the same.
            fNano = testCase.writeMagLike(0, 500000, 1.5);
            fMicro = testCase.writeMasLike(0, 500000, {'001'}, {1.5});
            tNano = gracefoReading.readL1b(fNano);
            tMicro = gracefoReading.readL1b(fMicro);

            testCase.verifyEqual(tNano(1,2), 43200.0005, 'AbsTol', 1e-9);
            testCase.verifyEqual(tMicro(1,2), 43200.5, 'AbsTol', 1e-9);
        end

        function testProdFlagVariableLengthRecords(testCase)
            % Record 1: bits 0+2 set -> mass_a, mass_c present, mass_b NaN
            % Record 2: bit 1 set   -> only mass_b present
            f = testCase.writeMasLike([0; 1], [0; 0], ...
                {'101', '010'}, {[1.0, 3.0], 2.0});
            [~, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifyEqual(aux.obsNames, {'mass_a','mass_b','mass_c'});
            testCase.verifyEqual(obs(1,:), [1.0, NaN, 3.0], 'AbsTol', 1e-12);
            testCase.verifyEqual(obs(2,:), [NaN, 2.0, NaN], 'AbsTol', 1e-12);
            testCase.verifyEqual(aux.prod_flag, ['101'; '010']);
            testCase.verifyEqual(aux.prodFlagBits, ...
                logical([1 0 1; 0 1 0]));  % col b = bit b-1
        end

        function testAhkStyleNamesSurviveAndStayDistinct(testCase)
            % G-04 / V-13, issue #19. Before 2026-09-22 the header
            % parser accepted identifier names only, so "TSU Z-" was
            % dropped and the record then had one token too many; the
            % three remaining names collapsed onto two fields.
            names = {'TSU_Y+', 'TSU_Y-', 'TSU_Z+', 'TSU Z-'};
            f = testCase.writeAhkLike([0; 1], ...
                {'00001111', '00001001'}, {[21 22 23 24], [25 28]});

            testCase.verifyWarning(@() gracefoReading.readL1b(f), ...
                'gracefoReading:readL1b:variableNameAdjusted');

            w = warning('off', 'gracefoReading:readL1b:variableNameAdjusted');
            c = onCleanup(@() warning(w)); %#ok<NASGU>
            [t, obs, aux] = gracefoReading.readL1b(f);

            testCase.verifySize(t, [2, 2]);
            % every declared name is kept verbatim, in declaration order
            testCase.verifyEqual(aux.obsNames, names);
            testCase.verifyTrue(all(ismember(names, aux.variableNames)));
            % and each has its OWN field, so nothing was overwritten
            fn = aux.variableFieldNames(end-3:end);
            testCase.verifyEqual(numel(unique(fn)), 4, ...
                'Four colliding names must map to four distinct fields.');
            for k = 1:4
                a = aux.variableAttributes.(fn{k});
                testCase.verifyEqual(a.long_name, ['temperature ', names{k}], ...
                    'Attributes must follow their own variable.');
                testCase.verifyEqual(aux.variableUnits.(fn{k}), 'degC');
            end
            % prod_flag drives which columns a record carries
            testCase.verifyEqual(obs(1, :), [21 22 23 24], 'AbsTol', 1e-12);
            testCase.verifyEqual(obs(2, [1 4]), [25 28], 'AbsTol', 1e-12);
            testCase.verifyTrue(all(isnan(obs(2, [2 3]))));
        end

        function testVariableNameAdjustedStaysSilentOnCleanHeaders(testCase)
            % The other half of the fault injection: the warning must
            % not fire on a header whose names are already valid and
            % unique, which is every product read so far.
            f = testCase.writeActLike([1; 43200]);   % not 0: zeroTime (#29)
            testCase.verifyWarningFree(@() gracefoReading.readL1b(f));
            [~, ~, aux] = gracefoReading.readL1b(f);
            testCase.verifyEqual(aux.variableFieldNames, aux.variableNames, ...
                'Valid unique names must be their own field names.');
        end

        function testRestOfLineColumnAbsorbsItsSpaces(testCase)
            % G-04, issue #19. Read off the real LHK1B header, whose
            % last column declares itself "Entire remaining portion of
            % each record". Before 2026-09-22 the surplus token raised
            % columnMismatch and the product could not be read at all.
            names = {'pztInLoopStatus', 'fpga_state: science_state', ...
                     'mode:  science'};
            f = testCase.writeLhkLike(names, true);

            [t, obs, aux] = gracefoReading.readL1b(f);
            testCase.verifySize(t, [3, 2]);
            % sensorvalue is the only observation; everything else is aux
            testCase.verifyEqual(aux.obsNames, {'sensorvalue'});
            testCase.verifyEqual(obs, [41; 42; 43], 'AbsTol', 1e-12);
            % the text comes back VERBATIM, internal spacing included
            testCase.verifyEqual(aux.sensorname, names(:));
            testCase.verifyEqual(aux.sensortype, repmat('?', 3, 1));
            % and the leading columns are unaffected by the surplus
            testCase.verifyEqual(aux.GRACEFO_id, repmat('C', 3, 1));
            % gps 631108800 = 2020-01-01, MJD 58849 (epoch rule in
            % HANDOVER C, derived and not guessed)
            testCase.verifyEqual(t(:,1), repmat(58849, 3, 1));
        end

        function testSurplusTokenWithoutTheDeclarationStillErrors(testCase)
            % The other half of the fault injection. The rule is the
            % header's sentence, not the column's position: the same
            % records under a header that does not claim the remaining
            % portion must still be refused, with the line number.
            names = {'pztInLoopStatus', 'fpga_state: science_state'};
            f = testCase.writeLhkLike(names, false);
            testCase.verifyError(@() gracefoReading.readL1b(f), ...
                'gracefoReading:readL1b:columnMismatch');
        end

        function testRestOfLineStillRefusesAShortRecord(testCase)
            % Surplus tokens are text; a SHORTFALL is still corruption.
            f = testCase.writeLhkLike({'pztInLoopStatus'}, true);
            txt = fileread(f);
            txt = strrep(txt, '631108800 100000 G C 00000000 ? 41 pztInLoopStatus', ...
                          '631108800 100000 G C 00000000 ? 41');
            % 'w', not 'wt': txt already carries the platform's line
            % endings from fileread, and text mode would double the CR
            fid = fopen(f, 'w'); fwrite(fid, txt); fclose(fid);
            testCase.verifyError(@() gracefoReading.readL1b(f), ...
                'gracefoReading:readL1b:columnMismatch');
        end

        function testProdFlagTokenCountMismatchRaises(testCase)
            % Claim 2 bits set but provide only one value.
            f = fullfile(testCase.workDir, 'MAS1B_bad.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, ['header:\n  dimensions:\n    num_records: 1\n', ...
                '  variables:\n    - time_intg:\n        units: seconds\n', ...
                '    - time_frac:\n        units: microseconds\n', ...
                '    - prod_flag:\n        comment: column\n', ...
                '    - v_a:\n        units: kg\n    - v_b:\n        units: kg\n', ...
                '# End of YAML header\n']);
            fprintf(fid, '0 0 11 1.0\n');
            fclose(fid);
            testCase.verifyError(@() gracefoReading.readL1b(f), ...
                'gracefoReading:readL1b:columnMismatch');
        end

        function testQualflgStaysBitStringNotNumericZero(testCase)
            % "00000000" must NOT be swallowed as numeric 0.
            f = testCase.writeActLike([0; 1], 'Qualflg', "00000010");
            [~, ~, aux] = gracefoReading.readL1b(f);

            testCase.verifyClass(aux.qualflg, 'char');
            testCase.verifyEqual(aux.qualflg, ['00000010'; '00000010']);
            testCase.verifyTrue(all(aux.qualflgBits(:,2)));   % bit 1 set
            testCase.verifyFalse(any(aux.qualflgBits(:,1)));  % bit 0 clear
            testCase.verifyFalse(any(strcmp(aux.obsNames, 'qualflg')));
        end

        function testApplyQualityFlags(testCase)
            f = fullfile(testCase.workDir, 'ACT1B_flags.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, ['header:\n  dimensions:\n    num_records: 3\n', ...
                '  variables:\n    - gps_time:\n        units: second\n', ...
                '    - val:\n        units: m\n    - qualflg:\n        comment: c\n', ...
                '# End of YAML header\n']);
            fprintf(fid, '0 1.0 00000000\n1 2.0 00000001\n2 3.0 00000000\n');
            fclose(fid);

            [t, obs, aux] = gracefoReading.readL1b(f, 'ApplyQualityFlags', true);
            testCase.verifySize(t, [2, 2]);
            testCase.verifyEqual(obs, [1.0; 3.0], 'AbsTol', 1e-12);
            testCase.verifyEqual(aux.numRecordsFlagged, 1);
            testCase.verifyEqual(aux.numRecordsActual, 3);
            testCase.verifySize(aux.qualflg, [2, 8]);   % filtered too
        end

        function testTimeRangeFiltering(testCase)
            f = testCase.writeActLike((0:3600:86400)');   % 25 records
            tr = [51544 + 43200/86400, 51544 + 50400/86400];  % first 2h
            [t, obs] = gracefoReading.readL1b(f, 'TimeRange', tr);

            testCase.verifySize(t, [3, 2]);   % 0, 3600, 7200 s offsets
            testCase.verifySize(obs, [3, 3]);
            testCase.verifyEqual(t(1,2), 43200, 'AbsTol', 1e-9);
            testCase.verifyEqual(t(end,2), 50400, 'AbsTol', 1e-9);
        end

        function testTimeFormatDatetime(testCase)
            f = testCase.writeActLike([0; 86400]);
            t = gracefoReading.readL1b(f, 'TimeFormat', 'datetime');

            testCase.verifyClass(t, 'datetime');
            testCase.verifyEqual(t(1), datetime(2000,1,1,12,0,0), ...
                'AbsTol', seconds(1e-6));
            testCase.verifyEqual(t(2), datetime(2000,1,2,12,0,0), ...
                'AbsTol', seconds(1e-6));
        end

        function testLegacyHeaderStyleStillSupported(testCase)
            f = testCase.writeLegacyStyle([0; 100]);
            [t, obs, aux] = gracefoReading.readL1b(f);
            testCase.verifyEqual(aux.obsNames, {'obs_value'});
            testCase.verifyEqual(obs, [10; 20], 'AbsTol', 1e-9);
            testCase.verifyEqual(t(1,:), [51544, 43200], 'AbsTol', 1e-9);
        end

        function testTimeVariableOverride(testCase)
            f = testCase.writeMasLike([0; 100], [0; 0], {'001','001'}, {1.0, 2.0});
            [t, ~, aux] = gracefoReading.readL1b(f, ...
                'TimeVariable', 'time_intg+time_frac');
            testCase.verifyEqual(aux.timeVariable, 'time_intg+time_frac');
            testCase.verifyEqual(t(2,2) - t(1,2), 100, 'AbsTol', 1e-9);

            testCase.verifyError(@() gracefoReading.readL1b(f, ...
                'TimeVariable', 'nope'), ...
                'gracefoReading:readL1b:timeVariableNotFound');
        end

        function testColumnMismatchNamesLineNumber(testCase)
            f = testCase.writeActLike([0; 1; 2], 'BadRow', 2);
            caught = [];
            try
                gracefoReading.readL1b(f);
            catch caught
            end
            testCase.verifyNotEmpty(caught);
            testCase.verifyEqual(caught.identifier, 'gracefoReading:readL1b:columnMismatch');
            % header of writeActLike is 26 lines incl. marker; bad row is
            % data line 2 -> file line 28. Compute robustly instead:
            fid = fopen(f); n = 0;
            while ~contains(fgetl(fid), 'End of YAML header'), n = n + 1; end
            fclose(fid);
            expectedLine = n + 1 + 2;
            testCase.verifyTrue(contains(caught.message, num2str(expectedLine)));
        end

        function testRecordCountMismatchWarns(testCase)
            f = testCase.writeActLike([0; 1; 2], 'DeclaredCount', 5);
            testCase.verifyWarning(@() gracefoReading.readL1b(f), ...
                'gracefoReading:readL1b:recordCountMismatch');
        end

        function testGzipMatchesPlain(testCase)
            f = testCase.writeActLike([0; 43200; 86400]);
            gz = gzip(f, testCase.workDir); gz = gz{1};
            [t1, o1] = gracefoReading.readL1b(f);
            [t2, o2] = gracefoReading.readL1b(gz);
            testCase.verifyEqual(t2, t1);
            testCase.verifyEqual(o2, o1);
        end

        function testErrorsForBrokenFiles(testCase)
            d = testCase.workDir;
            % missing marker
            f1 = fullfile(d, 'nomarker.txt');
            fid = fopen(f1, 'wt'); fprintf(fid, 'header:\n  variables:\n    - gps_time:\n'); fclose(fid);
            testCase.verifyError(@() gracefoReading.readL1b(f1), ...
                'gracefoReading:readL1b:badHeader');
            % binary
            f2 = fullfile(d, 'bin.txt');
            fid = fopen(f2, 'wt');
            fprintf(fid, 'header:\n  format: binary\n  variables:\n    - gps_time:\n# End of YAML header\n');
            fclose(fid);
            testCase.verifyError(@() gracefoReading.readL1b(f2), ...
                'gracefoReading:readL1b:binaryNotSupported');
            % no variables
            f3 = fullfile(d, 'novars.txt');
            fid = fopen(f3, 'wt'); fprintf(fid, 'header:\n  dimensions:\n# End of YAML header\n'); fclose(fid);
            testCase.verifyError(@() gracefoReading.readL1b(f3), ...
                'gracefoReading:readL1b:noVariables');
            % no data
            f4 = fullfile(d, 'nodata.txt');
            fid = fopen(f4, 'wt');
            fprintf(fid, 'header:\n  variables:\n    - gps_time:\n        units: second\n# End of YAML header\n');
            fclose(fid);
            testCase.verifyError(@() gracefoReading.readL1b(f4), ...
                'gracefoReading:readL1b:noData');
            % missing file
            testCase.verifyError(@() gracefoReading.readL1b(fullfile(d, 'nope.txt')), ...
                'MATLAB:validators:mustBeFile');
        end

        function testUnknownFracUnitRaises(testCase)
            f = fullfile(testCase.workDir, 'badunit.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, ['header:\n  variables:\n', ...
                '    - time_intg:\n        units: seconds\n', ...
                '    - time_frac:\n        units: fortnights\n', ...
                '    - v:\n        units: m\n# End of YAML header\n']);
            fprintf(fid, '0 0 1.0\n');
            fclose(fid);
            testCase.verifyError(@() gracefoReading.readL1b(f), ...
                'gracefoReading:readL1b:unknownFracUnit');
        end


        function testGpsnsTimeFormatExactness(testCase)
            % int64 nanoseconds must be exact integer arithmetic:
            % 631112399 s + 990452 us -> 631112399990452000 ns.
            f = testCase.writeMasLike([631112399; 631115999], ...
                [990452; 990412], {'001','001'}, {1.0, 2.0});
            tns = gracefoReading.readL1b(f, 'TimeFormat', 'gpsns');

            testCase.verifyClass(tns, 'int64');
            testCase.verifyEqual(tns(1), int64(631112399990452000));
            testCase.verifyEqual(tns(2), int64(631115999990412000));

            % single gps_time column, integer seconds
            f2 = testCase.writeActLike([0; 86400]);
            tns2 = gracefoReading.readL1b(f2, 'TimeFormat', 'gpsns');
            testCase.verifyEqual(tns2, int64([0; 86400000000000]));
        end

        function testQualityBitMaskSelective(testCase)
            f = fullfile(testCase.workDir, 'ACT1B_mask.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, ['header:\n  dimensions:\n    num_records: 3\n', ...
                '  variables:\n    - gps_time:\n        units: second\n', ...
                '    - val:\n        units: m\n    - qualflg:\n        comment: c\n', ...
                '# End of YAML header\n']);
            fprintf(fid, '0 1.0 00000001\n1 2.0 01000000\n2 3.0 00000000\n');
            fclose(fid);

            % mask bit 6 only: record 2 removed, record 1 (bit 0) kept
            [t, obs, aux] = gracefoReading.readL1b(f, 'QualityBitMask', 6);
            testCase.verifyEqual(obs, [1.0; 3.0], 'AbsTol', 1e-12);
            testCase.verifyEqual(aux.numRecordsFlagged, 1);
            testCase.verifySize(t, [2, 2]);

            % ApplyQualityFlags removes both flagged records
            [~, obsAll] = gracefoReading.readL1b(f, 'ApplyQualityFlags', true);
            testCase.verifyEqual(obsAll, 3.0, 'AbsTol', 1e-12);

            % both options together is an error
            testCase.verifyError(@() gracefoReading.readL1b(f, ...
                'ApplyQualityFlags', true, 'QualityBitMask', 6), ...
                'gracefoReading:readL1b:conflictingQualityOptions');
        end

        function testCacheRoundtrip(testCase)
            f = testCase.writeActLike([0; 43200; 86400]);
            cacheDir = fullfile(testCase.workDir, 'cache');

            [t1, o1, a1] = gracefoReading.readL1b(f, 'CacheDir', cacheDir);
            testCase.verifyFalse(a1.cacheHit);
            testCase.verifyEqual(numel(dir(fullfile(cacheDir, '*.mat'))), 1);

            [t2, o2, a2] = gracefoReading.readL1b(f, 'CacheDir', cacheDir);
            testCase.verifyTrue(a2.cacheHit);
            testCase.verifyEqual(t2, t1);
            testCase.verifyEqual(o2, o1);
            testCase.verifyEqual(a2.obsNames, a1.obsNames);
            testCase.verifyEqual(a2.qualflg, a1.qualflg);

            % post-parse options work from cache: gpsns + TimeRange
            % The epoch is 2000-01-01 12:00:00 GPS, so gps_time 0 is
            % MJD 51544.5, not 51544. The window must start at noon to
            % contain the first two records; the old literal 51544
            % excluded the second and was never exercised because the
            % file could not be parsed at all. The half-day shift is
            % validated independently in testRealData against the
            % Python reference (THR1B first epoch MJD 58849, 250.09 s).
            tns = gracefoReading.readL1b(f, 'CacheDir', cacheDir, ...
                'TimeFormat', 'gpsns', ...
                'TimeRange', [51544 + 43200/86400, 51545]);
            testCase.verifyEqual(tns, int64([0; 43200000000000]));

            % content change -> different key -> fresh parse
            fid = fopen(f, 'at'); fprintf(fid, '90000 C 1e-6 2e-6 3e-6 23 00000000\n'); fclose(fid);
            [~, o3, a3] = gracefoReading.readL1b(f, 'CacheDir', cacheDir);
            testCase.verifyFalse(a3.cacheHit);
            testCase.verifySize(o3, [4, 3]);
            testCase.verifyEqual(numel(dir(fullfile(cacheDir, '*.mat'))), 2);
        end

        function testClassicAsciiHeaderReadsWithoutWarning(testCase)
            % Classic GRACE ACC1B, ASCII variant: KEY : VALUE header,
            % END OF HEADER, and the column layout now shared with the
            % binary path - and MEASURED for this variant too since
            % 2026-09-22, not inferred. That layout was CORRECTED: it
            % carries NINE observation columns, the three residual ones
            % having been missing from the assumed table entirely, so
            % a record has twelve tokens and not nine.
            f = fullfile(testCase.workDir, 'ACC1B_2008-01-01_A_02.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, 'PRODUCER AGENCY               : NASA\n');
            fprintf(fid, 'PRODUCER INSTITUTION          : JPL\n');
            fprintf(fid, 'NUMBER OF DATA RECORDS        : 2\n');
            fprintf(fid, 'END OF HEADER\n');
            fprintf(fid, ['252460800 A 1e-7 2e-7 3e-7 1e-9 2e-9 3e-9 ', ...
                '1e-11 2e-11 3e-11 00000000\n']);
            fprintf(fid, ['252460801 A 4e-7 5e-7 6e-7 4e-9 5e-9 6e-9 ', ...
                '4e-11 5e-11 6e-11 00000000\n']);
            fclose(fid);

            % The ASCII variant no longer warns. Its column order and
            % rendering were measured against the JPL read software's
            % own Bin2AsciiLevel1 output, byte for byte on all eight
            % products - see testClassicProducts.
            [t, obs, aux] = testCase.verifyWarningFree( ...
                @() gracefoReading.readL1b(f));
            testCase.verifyEqual(aux.headerFormat, 'classic');
            testCase.verifyEqual(aux.numRecordsHeader, 2);
            testCase.verifyEqual(aux.obsNames, ...
                {'lin_accl_x','lin_accl_y','lin_accl_z', ...
                 'ang_accl_x','ang_accl_y','ang_accl_z', ...
                 'acl_x_res','acl_y_res','acl_z_res'});
            testCase.verifySize(obs, [2, 9]);
            testCase.verifyEqual(obs(1,7), 1e-11, 'AbsTol', 1e-24);
            testCase.verifyEqual(aux.GRACE_id, ['A'; 'A']);
            testCase.verifyEqual(aux.classicHeaderFields.producerAgency, 'NASA');
            % 252460800 s = 2008-01-01 12:00:00 GPS -> MJD 54466, 43200+0
            testCase.verifyEqual(t(1,:), [54466, 43200], 'AbsTol', 1e-9);
        end

        function testClassicColumnNamesOverrideAndUnsupported(testCase)
            f = fullfile(testCase.workDir, 'XYZ1B_2008-01-01_A_02.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, 'NUMBER OF DATA RECORDS        : 1\nEND OF HEADER\n');
            fprintf(fid, '0 7.5\n');
            fclose(fid);

            % unknown classic product without ColumnNames -> error
            testCase.verifyError( ...
                @() localReadNoWarn(f), ...
                'gracefoReading:readL1b:unsupportedClassicProduct');

            % Explicit ColumnNames make it readable - and still warn,
            % because those names are the CALLER's claim about the file
            % and nothing here has checked them against it.
            [t, obs, aux] = testCase.verifyWarning( ...
                @() gracefoReading.readL1b(f, ...
                    'ColumnNames', ["gps_time", "myval"]), ...
                'gracefoReading:readL1b:classicExperimental');
            testCase.verifyEqual(aux.obsNames, {'myval'});
            testCase.verifyEqual(obs, 7.5, 'AbsTol', 1e-12);
            testCase.verifyEqual(t(1,:), [51544, 43200], 'AbsTol', 1e-9);
        end

        function testRcvTimeSingleColumnIsDetected(testCase)
            % CLK1B's header, as the real file declares it (issue #29):
            % one integer receiver-time column called rcv_time and no
            % gps_time. v1.1.0 raised noTime on it.
            f = fullfile(testCase.workDir, 'CLK1B_synth.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, ['header:\n  dimensions:\n    num_records: 2\n', ...
                '  variables:\n', ...
                '    - rcv_time:\n        comment: 1st column\n', ...
                '        long_name: Seconds past 12:00:00 noon of January 1, 2000 ', ...
                'in Receiver Time\n', ...
                '        units: seconds\n', ...
                '    - GRACEFO_id:\n        units: char\n', ...
                '    - clock_id:\n        long_name: Clock ID\n', ...
                '    - eps_time:\n        units: seconds\n', ...
                '    - qualflg:\n        long_name: Quality Flags\n', ...
                '# End of YAML header\n']);
            fprintf(fid, '631194900 C 1 -1.1e-02 00000000\n631195200 C 1 -1.2e-02 00000000\n');
            fclose(fid);
            [t, obs, aux] = testCase.verifyWarningFree(@() ...
                gracefoReading.readL1b(f, 'TimeFormat', 'gpsns'));
            testCase.verifyEqual(aux.timeVariable, 'rcv_time');
            testCase.verifyEqual(t, int64([631194900; 631195200]) * int64(1e9));
            testCase.verifyEqual(aux.obsNames, {'eps_time'});
            testCase.verifyEqual(obs, [-1.1e-2; -1.2e-2], 'AbsTol', 1e-15);
        end

        function testZeroTimeWarnsCountsAndDrops(testCase)
            % Real TIM1B_2020-01-02_D_04 carries records whose tag is 0
            % (issue #29). Counted and reported either way; removed only
            % on request. Fault injection: the warning-free tests above
            % use tags that are not zero and must stay silent.
            f = testCase.writeActLike([100; 0; 200; 0; 300]);
            [t, obs, aux] = testCase.verifyWarning(@() gracefoReading.readL1b(f), ...
                'gracefoReading:readL1b:zeroTime');
            testCase.verifySize(t, [5, 2]);
            testCase.verifyEqual(aux.numRecordsZeroTime, 2);
            testCase.verifyEqual(t([2 4], :), repmat([51544, 43200], 2, 1), 'AbsTol', 1e-9);

            lastwarn('', '');
            [t, obs2, aux] = gracefoReading.readL1b(f, 'DropZeroTime', true, ...
                'TimeFormat', 'gpsns');
            [msg, wid] = lastwarn();
            testCase.verifyEqual(wid, 'gracefoReading:readL1b:zeroTime');
            testCase.verifyTrue(contains(msg, '2 of 5') && contains(msg, 'record 2') ...
                && contains(msg, 'removed'), msg);
            testCase.verifyEqual(t, int64([100; 200; 300]) * int64(1e9));
            testCase.verifyEqual(obs2, obs([1 3 5], :));
            testCase.verifyEqual(aux.numRecordsZeroTime, 2);
            testCase.verifyEqual(aux.numRecordsActual, 5);
            testCase.verifySize(aux.qualflg, [3, 8]);   % per-record aux filtered too
        end

        function testLargeFileSmokeTest(testCase)
            n = 20000;
            f = testCase.writeActLike((0:n-1)');
            ticId = tic;
            [t, obs] = gracefoReading.readL1b(f);
            elapsed = toc(ticId);
            testCase.verifySize(t, [n, 2]);
            testCase.verifySize(obs, [n, 3]);
            testCase.verifyLessThan(elapsed, 120);
            fprintf('testLargeFileSmokeTest: %d records in %.2f s\n', n, elapsed);
        end

    end
end

function varargout = localReadNoWarn(f)
% Suppress the caller-supplied-layout warning so verifyError sees only
% the error. Kept for the ColumnNames cases; the built-in layouts no
% longer warn at all.
ws = warning('off', 'gracefoReading:readL1b:classicExperimental');
cln = onCleanup(@() warning(ws));
[varargout{1:nargout}] = gracefoReading.readL1b(f);
end
