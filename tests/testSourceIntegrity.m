classdef testSourceIntegrity < matlab.unittest.TestCase
%TESTSOURCEINTEGRITY  Tests that every source file is parseable and singly documented.
%
%   DESCRIPTION
%     This suite exists because of a defect that no existing check
%     could see. A help block had been written between the two
%     physical lines of a continued function declaration in
%     parseDataSection.m and parseClassicProduct.m. MATLAB rejected
%     both files with MATLAB:m_unbalanced_parens, every test that
%     reached them errored, and the repository's continuous
%     integration had never been green. The help audit certified the
%     files as correct throughout, because the auditor located the
%     help block with the very same rule the writer had used to
%     misplace it: "the declaration is line 1".
%
%     The lesson is that a check must not share an assumption with the
%     tool it checks. This suite therefore asserts a property MATLAB
%     itself defines - the file parses - rather than a property the
%     documentation tooling believes about the file. It runs in about
%     a second and needs no data.
%
%     The counterpart docsrc/sourceIntegrity.py performs the same
%     structural checks statically, without MATLAB and therefore
%     without a licence, so a pull request fails on ubuntu-latest
%     before the self-hosted runner is reached. The rules live once in
%     docsrc/mfile.py; the MATLAB mirror is pinned to it by
%     testContinuationRuleMatchesSharedVectors below.
%
%     Run with:
%       results = runtests('testSourceIntegrity'); table(results)
%
%   COVERAGE
%     - every .m file in the repository parses without a parse error
%     - no comment line interrupts a continued declaration
%     - no file carries more than one leading help block
%     - every package function exposes a non-empty help text whose H1
%       line names the function
%     - the MATLAB continuation rule agrees with the Python one on a
%       shared set of test vectors
%
%   ACCURACY AND LIMITATIONS
%     - checkcode reports parse errors, not run-time correctness; a
%       file can parse and still be wrong.
%     - The duplicate-help check keys on the provenance stamp
%       "%   Toolbox:  gracefoReading". A second help block written
%       without that stamp is invisible here, and only the parse check
%       would still catch the split-declaration case.
%     - The continuation rule counts quotes to distinguish an ellipsis
%       inside a character literal from a real continuation. A
%       declaration containing an odd number of quotes inside a
%       comment would defeat it; no such line exists in this toolbox
%       and the parse check would flag the consequence anyway.
%
%   EXAMPLE
%     results = runtests('testSourceIntegrity');
%     disp(table(results))
%
%   See also gracefoReading.internal.parseDataSection, testDocConsistency
%
%   Toolbox:  gracefoReading v1.3.1
%   Created:  2026-09-06
%   Updated:  2026-09-06
%   Author:   Matthias Weigelt with support of Anthropic Claude

    properties (Constant)
        % Provenance stamp that marks the end of a help block.
        Stamp = '%   Toolbox:  gracefoReading'
    end

    properties
        Root    (1,1) string   % repository root
        Files   (:,1) string   % every .m file below Root
    end

    methods (TestClassSetup)
        function locateSources(testCase)
            % Repository root derived from this file, never hard-coded.
            here = fileparts(mfilename('fullpath'));
            testCase.Root = string(fileparts(here));
            d = dir(fullfile(testCase.Root, '**', '*.m'));
            p = string({d.folder}') + filesep + string({d.name}');
            skip = contains(p, filesep + ".git" + filesep) | ...
                   contains(p, filesep + "artifacts" + filesep);
            testCase.Files = sort(p(~skip));
            testCase.assertNotEmpty(testCase.Files, ...
                'No source files found - is the repository laid out as expected?');
            % help() resolves only with the package parent on the path.
            % Without this the suite passed or failed depending on what
            % an earlier suite had left behind - measured, not assumed.
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(testCase.Root));
        end
    end

    methods (Test, TestTags = {'Unit'})

        function testEverySourceFileParses(testCase)
            % A parse error means the file does not exist for MATLAB.
            bad = strings(0, 2);
            for k = 1:numel(testCase.Files)
                m = checkcode(testCase.Files(k), '-struct');
                for j = 1:numel(m)
                    if contains(m(j).message, 'Parse error')
                        bad(end+1, :) = [testCase.rel(testCase.Files(k)), ...
                            sprintf('line %d: %s', m(j).line, m(j).message)]; %#ok<AGROW>
                    end
                end
            end
            testCase.verifyEmpty(bad, testCase.report('parse error', bad));
        end

        function testNoCommentInsideContinuedDeclaration(testCase)
            % The exact defect signature of the two parse files.
            bad = strings(0, 2);
            for k = 1:numel(testCase.Files)
                lines = splitlines(string(fileread(testCase.Files(k))));
                hit = testSourceIntegrity.commentInsideDecl(lines);
                if ~isempty(hit)
                    bad(end+1, :) = [testCase.rel(testCase.Files(k)), ...
                        sprintf('line %d starts a help block inside the declaration', ...
                        hit(1))]; %#ok<AGROW>
                end
            end
            testCase.verifyEmpty(bad, ...
                testCase.report('split declaration', bad));
        end

        function testAtMostOneHelpBlockPerFile(testCase)
            % Two provenance stamps mean a stale block was left behind.
            bad = strings(0, 2);
            for k = 1:numel(testCase.Files)
                lines = splitlines(string(fileread(testCase.Files(k))));
                n = sum(startsWith(lines, testSourceIntegrity.Stamp));
                if n > 1
                    bad(end+1, :) = [testCase.rel(testCase.Files(k)), ...
                        sprintf('%d provenance stamps', n)]; %#ok<AGROW>
                end
            end
            testCase.verifyEmpty(bad, testCase.report('duplicate help block', bad));
        end

        function testHelpIsReachableForEveryPackageFunction(testCase)
            % help() must find the block; an H1 that names something
            % else is the tell-tale of a block left over from a rename.
            pkg = testCase.Files(contains(testCase.Files, ...
                filesep + "+gracefoReading" + filesep));
            testCase.assertNotEmpty(pkg, 'No package functions found.');
            bad = strings(0, 2);
            for k = 1:numel(pkg)
                [~, name] = fileparts(pkg(k));
                if name == "Contents", continue, end
                dotted = testCase.dottedName(pkg(k));
                h = string(help(dotted));
                if strlength(strtrim(h)) == 0
                    bad(end+1, :) = [dotted, "help is empty"]; %#ok<AGROW>
                    continue
                end
                nl = splitlines(strtrim(h));
                h1 = strtrim(nl(1));
                if ~startsWith(upper(h1), upper(name))
                    bad(end+1, :) = [dotted, "H1 does not name the function: " + h1]; %#ok<AGROW>
                end
            end
            testCase.verifyEmpty(bad, testCase.report('unreachable help', bad));
        end

        function testContinuationRuleMatchesSharedVectors(testCase)
            % Shared vectors with the Python rule in docsrc/mfile.py.
            % Columns: {lines, expected index of the first broken line
            % (0 = none)}.
            v = { {'function y = f(x)'; '%F  h1'; 'y=x;'},                     0
                  {'function y = f(x, ...'; '    z)'; '%F  h1'; 'y=x;'},       0
                  {'function y = f(x, ...'; '%F  h1'; '    z)'; 'y=x;'},       2
                  {'%SCRIPT h1'; '%  more'; 'x=1;'},                           0
                  {'function y = f(x)  % note ... here'; '%F h1'; 'y=x;'},     0
                  {'a = [1, ...'; '% wedged'; '2];'},                          2 };
            for k = 1:size(v, 1)
                hit = testSourceIntegrity.commentInsideDecl(string(v{k, 1}));
                got = 0; if ~isempty(hit), got = hit(1); end
                testCase.verifyEqual(got, v{k, 2}, sprintf( ...
                    'vector %d (%s): expected %d, got %d', k, v{k, 1}{1}, v{k, 2}, got));
            end
        end
    end

    methods (Access = private)
        function r = rel(testCase, p)
            r = erase(p, testCase.Root + filesep);
        end

        function d = dottedName(testCase, p)
            r = testCase.rel(p);
            r = erase(r, ".m");
            d = replace(replace(r, filesep, "."), "+", "");
        end

        function msg = report(~, what, bad)
            if isempty(bad), msg = ''; return, end
            % string, not char: char + char is numeric addition in
            % MATLAB, which errored inside the failure path and hid the
            % finding it was meant to report.
            msg = string(sprintf('%d %s finding(s):\n', size(bad, 1), what));
            for k = 1:size(bad, 1)
                msg = msg + sprintf('  %s -> %s\n', bad(k, 1), bad(k, 2));
            end
            msg = char(msg);
        end
    end

    methods (Static)
        function tf = continues(line)
            % True if LINE is continued on the next physical line.
            % Mirror of continues() in docsrc/mfile.py.
            if startsWith(strtrim(line), '%'), tf = false; return, end
            i = strfind(line, '...');
            if isempty(i), tf = false; return, end
            before = extractBefore(line, i(1));
            tf = mod(count(before, ''''), 2) == 0 && ~contains(before, '%');
        end

        function hits = commentInsideDecl(lines)
            % One-based indices of the first comment line of each break.
            % Mirror of comment_inside_decl() in docsrc/mfile.py.
            hits = [];
            openCont = false;
            reported = false;
            for i = 1:numel(lines)
                if startsWith(strtrim(lines(i)), '%')
                    if openCont && ~reported
                        hits(end+1) = i; %#ok<AGROW>
                        reported = true;
                    end
                    continue
                end
                openCont = testSourceIntegrity.continues(lines(i));
                reported = false;
            end
        end
    end
end
