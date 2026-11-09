classdef testEventLists < matlab.unittest.TestCase
%TESTEVENTLISTS  Reading the official TN-01 / TN-01a event lists.
%
%   DESCRIPTION
%     Covers gracefoReading.readEventList against the two official
%     lists bundled in tests/realdata/ (G-05, issue #20): TN-01, the
%     machine-readable sequence of events, and TN-01a, the operators'
%     spacecraft-events log.
%
%     The expectations were derived by re-parsing the same fixtures
%     with a short independent script rather than with the function
%     under test, and the epochs were converted with the civil-date
%     and GPS-epoch formulae worked out separately. The point of the
%     suite is as much what the reader must NOT do: TN-01a is prose,
%     and no test here expects a manoeuvre window to have been
%     extracted from a sentence.
%
%     Run with:
%       results = runtests('testEventLists'); table(results)
%
%   COVERAGE
%     - TN-01: row count, the declared value count honoured per row,
%       multi-value rows (QSA carries five), the MANV manoeuvre rows,
%       epochs converted from GPS seconds, "x"-disabled rows kept and
%       marked rather than dropped, satellite filtering, datetime output
%     - TN-01a: entries grouped under their date, wrapped continuation
%       lines joined to the entry they belong to, several entries under
%       one date, dayOnly set, header comments captured, timeSystem
%       reported as "date" and not as a time scale the file never gives
%     - format auto-detection from content, and the explicit override
%     - a malformed row reported by line number instead of guessed at
%
%   ACCURACY AND LIMITATIONS
%     - The fixtures are extracts: TN-01 keeps the leading defaults
%       (which include the disabled rows and the QSA quaternions) plus
%       a block carrying manoeuvres, and TN-01a keeps its header and
%       the first days. Line numbers are those of the extract, which is
%       a file in its own right.
%     - Nothing here tests an interpretation of TN-01a prose, because
%       the reader deliberately performs none.
%
%   EXAMPLE
%     results = runtests('testEventLists');
%     disp(table(results));
%
%   Toolbox:  gracefoReading v1.4.0
%   Created:  2026-09-22
%   Updated:  2026-09-22
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
            testCase.assertTrue(isfile(f), sprintf('Fixture %s missing.', name));
        end
    end

    methods (Test)

        function testSoeStructure(testCase)
            f = testCase.fixture('TN-01_SOE.txt');
            [ev, aux] = gracefoReading.readEventList(f);

            testCase.verifyEqual(aux.format, "soe");
            testCase.verifyEqual(aux.timeSystem, "GPS");
            testCase.verifyEqual(height(ev), 60);
            testCase.verifyEqual(aux.numUnparsable, 0, ...
                'Every line of the fixture must parse under the declared grammar.');

            testCase.verifyEqual(ev.satellite(1), "GRACEC");
            testCase.verifyEqual(ev.key(1), "ACC");
            testCase.verifyEqual(ev.values{1}, 1, 'AbsTol', 1e-12);
            testCase.verifyEqual(ev.text(1), "Initial default by hywen");
            testCase.verifyFalse(ev.dayOnly(1), ...
                'A TN-01 epoch is an instant, not a date.');
            % epoch 0 is the file''s initial default: 2000-01-01 12:00 GPS
            testCase.verifyEqual(ev.time(1,:), [51544, 43200], 'AbsTol', 1e-9);
            testCase.verifyEqual(ev.line(1), 1);
        end

        function testSoeHonoursTheDeclaredValueCount(testCase)
            % The row says how many numbers it carries; everything after
            % them is text. QSA carries five - a head number and a
            % quaternion - and its comment begins with a weekday.
            f = testCase.fixture('TN-01_SOE.txt');
            ev = gracefoReading.readEventList(f);
            qsa = ev(ev.key == "QSA", :);
            testCase.verifyEqual(height(qsa), 6);
            testCase.verifyEqual(numel(qsa.values{1}), 5);
            testCase.verifyEqual(qsa.values{1}(1), 1, 'AbsTol', 1e-12);
            testCase.verifyEqual(qsa.values{1}(2), -0.1846523033914243, ...
                'AbsTol', 1e-15);
            testCase.verifyTrue(startsWith(qsa.text(1), "Mon May 14"));
            % the four quaternion components are a unit quaternion
            q = qsa.values{1}(2:5);
            testCase.verifyEqual(norm(q), 1, 'AbsTol', 1e-12);
        end

        function testSoeManoeuvreRows(testCase)
            f = testCase.fixture('TN-01_SOE.txt');
            ev = gracefoReading.readEventList(f);
            manv = ev(ev.key == "MANV", :);
            testCase.verifyEqual(height(manv), 6);
            testCase.verifyEqual(manv.satellite(1), "GRACEC");
            testCase.verifyEqual(numel(manv.values{1}), 4);
            testCase.verifyEqual(manv.values{1}, [127.000 0.0988 0 0], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(manv.time(1,:), [58262, 22784.60003399849], ...
                'AbsTol', 1e-6);
        end

        function testSoeDisabledRowsAreKeptAndMarked(testCase)
            % A leading "x" comments a line out. Dropping it would lose
            % the record that the value was once there; the row is kept
            % and flagged so the caller decides.
            f = testCase.fixture('TN-01_SOE.txt');
            ev = gracefoReading.readEventList(f);
            testCase.verifyEqual(sum(ev.disabled), 6);
            off = ev(ev.disabled, :);
            testCase.verifyEqual(off.key(1), "VGN");
            testCase.verifyEqual(off.line(1), 39);
            testCase.verifyEqual(numel(off.values{1}), 6);
        end

        function testSoeSatelliteFilterAndDatetime(testCase)
            f = testCase.fixture('TN-01_SOE.txt');
            all1 = gracefoReading.readEventList(f);
            c = gracefoReading.readEventList(f, 'Satellite', "gracec");
            testCase.verifyTrue(all(c.satellite == "GRACEC"));
            testCase.verifyLessThan(height(c), height(all1));
            testCase.verifyGreaterThan(height(c), 0);

            d = gracefoReading.readEventList(f, 'TimeFormat', "datetime");
            testCase.verifyClass(d.time, 'datetime');
            testCase.verifyEqual(d.time(1), datetime(2000,1,1,12,0,0));
        end

        function testSceStructure(testCase)
            f = testCase.fixture('TN-01a_SCE.txt');
            [ev, aux] = gracefoReading.readEventList(f);

            testCase.verifyEqual(aux.format, "sce");
            testCase.verifyEqual(aux.timeSystem, "date", ...
                'The file states no time scale, so none is claimed.');
            testCase.verifyEqual(numel(aux.headerComments), 8);
            testCase.verifyEqual(height(ev), 14);
            testCase.verifyTrue(all(ev.dayOnly), ...
                'Every TN-01a row is a date, not an instant.');
            testCase.verifyTrue(all(ev.satellite == ""));
            testCase.verifyTrue(all(ev.key == ""));
            testCase.verifyEqual(ev.time(1,:), [58261, 0], 'AbsTol', 1e-9);
            testCase.verifyEqual(ev.line(1), 9);
        end

        function testSceContinuationLinesAreJoined(testCase)
            % The first entry of 2018-05-23 runs over four lines; the
            % deeper-indented ones belong to it, not to a new entry.
            f = testCase.fixture('TN-01a_SCE.txt');
            ev = gracefoReading.readEventList(f);
            first = ev.text(1);
            testCase.verifyTrue(startsWith(first, "GRACE-C/D Missing data"));
            testCase.verifyTrue(contains(first, "nearest 5-min epoch"), ...
                'A wrapped line must be joined to its entry.');
            testCase.verifyTrue(contains(first, "look closer later."));
            % ... and the next entry, at the date indent, is separate
            testCase.verifyTrue(startsWith(ev.text(2), "IPU resets manually added"));
        end

        function testSceSeveralEntriesShareOneDate(testCase)
            f = testCase.fixture('TN-01a_SCE.txt');
            ev = gracefoReading.readEventList(f);
            onDay = ev(ev.time(:,1) == 58262, :);      % 2018-05-24
            testCase.verifyEqual(height(onDay), 2);
            testCase.verifyTrue(contains(onDay.text(1), "calibration maneuver"));
            % deliberately NOT parsed into a window: the text is the row
            testCase.verifyTrue(contains(onDay.text(1), "06:19:26"));
        end

        function testFormatIsDetectedFromContentAndCanBeForced(testCase)
            soe = testCase.fixture('TN-01_SOE.txt');
            sce = testCase.fixture('TN-01a_SCE.txt');
            [~, a1] = gracefoReading.readEventList(soe);
            [~, a2] = gracefoReading.readEventList(sce);
            testCase.verifyEqual(a1.format, "soe");
            testCase.verifyEqual(a2.format, "sce");

            % a renamed copy must still read correctly: the decision is
            % made on content, never on the file name
            copied = fullfile(testCase.workDir, 'whatever.txt');
            copyfile(sce, copied);
            [~, a3] = gracefoReading.readEventList(copied);
            testCase.verifyEqual(a3.format, "sce");

            [~, a4] = gracefoReading.readEventList(soe, 'Format', "soe");
            testCase.verifyEqual(a4.format, "soe");
        end

        function testMalformedRowIsReportedNotGuessed(testCase)
            f = fullfile(testCase.workDir, 'TN-01_SOE.txt');
            fid = fopen(f, 'wt');
            fprintf(fid, '0.0  GRACEC ACC 1  1  Initial default\n');
            fprintf(fid, '1.0  GRACEC ACC 3  1  2  oops only two values\n');
            fprintf(fid, '2.0  GRACEC ACC 1  notanumber  bad value\n');
            fprintf(fid, '3.0  GRACED KBR 1  0  fine again\n');
            fclose(fid);

            testCase.verifyWarning(@() gracefoReading.readEventList(f), ...
                'gracefoReading:readEventList:unparsableLines');
            w = warning('off', 'gracefoReading:readEventList:unparsableLines');
            c = onCleanup(@() warning(w)); %#ok<NASGU>
            [ev, aux] = gracefoReading.readEventList(f);
            testCase.verifyEqual(height(ev), 2);
            testCase.verifyEqual(aux.unparsableLines, [2; 3]);
        end

        function testEmptyAndUnknownFilesRaise(testCase)
            empty = fullfile(testCase.workDir, 'empty.txt');
            fid = fopen(empty, 'wt'); fprintf(fid, '# only a comment\n'); fclose(fid);
            testCase.verifyError(@() gracefoReading.readEventList(empty), ...
                'gracefoReading:readEventList:formatNotRecognised');

            odd = fullfile(testCase.workDir, 'odd.txt');
            fid = fopen(odd, 'wt');
            fprintf(fid, 'this is not an event list at all\n');
            fclose(fid);
            testCase.verifyError(@() gracefoReading.readEventList(odd), ...
                'gracefoReading:readEventList:formatNotRecognised');
        end

    end
end
