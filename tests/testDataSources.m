classdef testDataSources < matlab.unittest.TestCase
%TESTDATASOURCES  tests/data/SOURCES.json lists exactly what the pool must hold.
%
%   DESCRIPTION
%     tests/data/SOURCES.json is this repository's list of the
%     third-party files its real-data tests look for in the data pool:
%     where each comes from (url), which files it yields (files, paths
%     relative to the folder the installer fetches into, here
%     <DATAPOOL>\RawData\tests\realdata), its size, SHA-256, licence
%     and purpose. toolboxInstaller reads the list from this file
%     (until 1.4.0 it lived only in the installer's registry, and
%     nothing tied it to the tests).
%
%     This suite makes the file authoritative. The names the tests ask
%     the pool for are DERIVED from the tests' own code - every literal
%     argument of testRealData.resolveFixture (pool only) and every
%     literal argument of requireFile (pool first, bundled second)
%     whose file is not bundled in tests/realdata - and compared with
%     the listed files in both directions. A real-data test that gains
%     a pool file without a SOURCES.json entry, or an entry no test
%     reads, fails here, whatever the pool on the machine holds.
%
%     Run with:
%       results = runtests('testDataSources'); table(results)
%
%   COVERAGE
%     - the file parses as JSON, schema is 1, sources is non-empty
%     - every entry carries id, url, files, MB, licence, licenceText
%       and description of the right type; ids are unique; url is
%       https; MB is positive; sha256, where present, is 64 lowercase
%       hex digits; files are relative paths without ".."
%     - every pool file the tests look for is listed
%     - every listed file is one the tests look for
%
%   ACCURACY AND LIMITATIONS
%     - The derivation reads literal file names only. A requireFile or
%       resolveFixture call with a computed argument is not seen; none
%       exists in tests/ today, and testEveryPoolFixtureIsListed
%       refuses to pass on a tree where the derivation finds nothing.
%     - Nothing is downloaded and no pool is needed: the suite checks
%       the list, not the files. Whether the url still serves bytes
%       with the stated sha256 is the installer's measurement.
%
%   EXAMPLE
%     results = runtests('testDataSources');
%     disp(table(results));
%
%   Toolbox:  gracefoReading v1.4.0
%   Created:  2026-11-09
%   Updated:  2026-11-09
%   Author:   Matthias Weigelt with support of Anthropic Claude

    properties
        testsDir
        manifest
    end

    properties (Constant)
        REQUIRED = ["id", "url", "files", "MB", "licence", "licenceText", ...
                    "description"]
    end

    methods (TestClassSetup)
        function readManifest(testCase)
            testCase.testsDir = fileparts(mfilename('fullpath'));
            f = fullfile(testCase.testsDir, 'data', 'SOURCES.json');
            testCase.assertTrue(isfile(f), sprintf('%s is missing.', f));
            testCase.manifest = jsondecode(fileread(f));
        end
    end

    methods (Access = private)
        function s = sources(testCase)
            % jsondecode returns a struct array when every entry has the
            % same fields and a cell array when they differ (sha256 is
            % optional), so both are normalised to a cell column.
            s = testCase.manifest.sources;
            if isstruct(s)
                s = num2cell(s);
            end
            s = s(:);
        end

        function names = listedFiles(testCase)
            names = strings(0, 1);
            s = testCase.sources();
            for k = 1:numel(s)
                names = [names; string(s{k}.files(:))]; %#ok<AGROW>
            end
        end

        function names = poolFixtures(testCase)
            % Literal arguments of the two lookups, read from the tests.
            here = string(mfilename('fullpath')) + ".m";
            d = dir(fullfile(testCase.testsDir, '*.m'));
            poolOnly = strings(0, 1);
            poolFirst = strings(0, 1);
            for k = 1:numel(d)
                f = string(fullfile(d(k).folder, d(k).name));
                if strcmpi(f, here)
                    continue
                end
                txt = fileread(f);
                poolOnly = [poolOnly; testDataSources.literals(txt, ...
                    'resolveFixture')]; %#ok<AGROW>
                poolFirst = [poolFirst; testDataSources.literals(txt, ...
                    'requireFile')]; %#ok<AGROW>
            end
            bundled = arrayfun(@(n) isfile(fullfile(testCase.testsDir, ...
                'realdata', n)), poolFirst);
            names = unique([poolOnly; poolFirst(~bundled)]);
        end
    end

    methods (Static, Access = private)
        function v = literals(txt, fn)
            tok = regexp(txt, [fn '\(''([^'']+)''\)'], 'tokens');
            v = strings(numel(tok), 1);
            for k = 1:numel(tok)
                v(k) = string(tok{k}{1});
            end
        end
    end

    methods (Test)
        function testManifestParsesAtSchemaOne(testCase)
            m = testCase.manifest;
            testCase.verifyTrue(isfield(m, 'schema') && isfield(m, 'sources'));
            testCase.verifyEqual(m.schema, 1);
            testCase.verifyNotEmpty(testCase.sources());
        end

        function testEveryEntryCarriesRequiredFields(testCase)
            s = testCase.sources();
            ids = strings(numel(s), 1);
            for k = 1:numel(s)
                e = s{k};
                for r = testCase.REQUIRED
                    testCase.verifyTrue(isfield(e, r), ...
                        sprintf('source %d has no field %s', k, r));
                end
                if ~all(isfield(e, cellstr(testCase.REQUIRED)))
                    continue
                end
                ids(k) = string(e.id);
                testCase.verifyTrue(startsWith(string(e.url), "https://"), e.id);
                testCase.verifyTrue(isnumeric(e.MB) && isscalar(e.MB) && e.MB > 0, e.id);
                for t = ["licence", "licenceText", "description"]
                    testCase.verifyTrue(ischar(e.(t)) && ~isempty(e.(t)), ...
                        sprintf('%s: %s', e.id, t));
                end
                if isfield(e, 'sha256')
                    testCase.verifyTrue(~isempty(regexp(e.sha256, ...
                        '^[0-9a-f]{64}$', 'once')), sprintf('%s: sha256', e.id));
                end
                files = string(e.files(:));
                testCase.verifyNotEmpty(files, e.id);
                for f = files'
                    testCase.verifyFalse(startsWith(f, ["/", "\"]) || ...
                        ~isempty(regexp(f, '^[A-Za-z]:', 'once')) || ...
                        any(split(f, ["/", "\"]) == ".."), ...
                        sprintf('%s: %s is not a relative path', e.id, f));
                end
            end
            testCase.verifyEqual(numel(unique(ids)), numel(ids), ...
                'Two sources share one id.');
        end

        function testEveryPoolFixtureIsListed(testCase)
            want = testCase.poolFixtures();
            testCase.assertNotEmpty(want, ...
                'No pool fixture derived from tests/ - the derivation is broken.');
            missing = setdiff(want, testCase.listedFiles());
            testCase.verifyEmpty(missing, sprintf( ...
                'Tests look for %s in the pool, but tests/data/SOURCES.json does not list it.', ...
                strjoin(missing, ", ")));
        end

        function testEveryListedFileIsAPoolFixture(testCase)
            extra = setdiff(testCase.listedFiles(), testCase.poolFixtures());
            testCase.verifyEmpty(extra, sprintf( ...
                'tests/data/SOURCES.json lists %s, which no test looks for in the pool.', ...
                strjoin(extra, ", ")));
        end
    end
end
