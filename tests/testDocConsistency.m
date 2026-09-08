classdef testDocConsistency < matlab.unittest.TestCase
%TESTDOCCONSISTENCY  Tests that code, documentation and metadata agree.
%
%   DESCRIPTION
%     Documentation drifts silently unless something checks it. This
%     suite treats the generated HTML reference as an artifact that
%     must match the code: every public function needs a page, every
%     error identifier raised anywhere in the package must appear in
%     the page of the function that documents it, and the version must
%     be identical in version.m, Contents.m, the product page and
%     docsrc/functionSpecs.json. Documentation is edited only through
%     functionSpecs.json and regenerated with
%     docsrc/generate_docs.py, so a mismatch means the regeneration
%     step was skipped.
%
%     Run with:
%       results = runtests('testDocConsistency'); table(results)
%
%   COVERAGE
%     - one HTML page per public function, referenced from helptoc.xml
%     - every gracefoReading:* error and warning identifier in the
%       package documented on the corresponding page
%     - version identical across version.m, Contents.m, the product
%       page and the documentation source
%     - help blocks conform to the documentation standard: required
%       sections, typed and sized input/output entries, stated
%       defaults for name-value options, authorship and date metadata
%
%   ACCURACY AND LIMITATIONS
%     - The suite compares text, not meaning: it can prove that an
%       error id is mentioned, not that the description is correct.
%     - The help-standard check mirrors docsrc/auditHelp.py; the
%       Python version is the more detailed of the two and runs in CI,
%       while this test keeps the check available inside MATLAB.
%     - Generated PDF output is not compared, as it is binary and
%       carries timestamps.
%
%   EXAMPLE
%     results = runtests('testDocConsistency');
%     disp(table(results));
%
%   Toolbox:  gracefoReading v1.0.1
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14

    properties
        codeDir
        htmlDir
    end

    methods (TestClassSetup)
        function locate(testCase)
            here = fileparts(mfilename('fullpath'));
            testCase.codeDir = fileparts(here);   % toolbox root
            testCase.htmlDir = fullfile(testCase.codeDir, 'html');
            % only touch the path if the toolbox is not already on it
            if ~any(strcmp(strsplit(path, pathsep), testCase.codeDir))
                addpath(testCase.codeDir);
                testCase.addTeardown(@() rmpath(testCase.codeDir));
            end
        end
    end

    methods (Test)

        function testErrorIdentifiersDocumented(testCase)
            pkgDir = fullfile(testCase.codeDir, '+gracefoReading');
            srcFiles = dir(fullfile(pkgDir, '*.m'));
            for s = 1:numel(srcFiles)
                [~, fname] = fileparts(srcFiles(s).name);
                if strcmpi(fname, 'Contents'), continue; end
                src = fileread(fullfile(pkgDir, srcFiles(s).name));
                ids = regexp(src, ...
                    '(?:error|warning)\(\s*''(gracefoReading:[A-Za-z0-9_:]+)''', ...
                    'tokens');
                if isempty(ids), continue; end
                htmlFile = fullfile(testCase.htmlDir, ['gracefoReading.', fname, '.html']);
                testCase.verifyTrue(isfile(htmlFile), ...
                    sprintf('Missing HTML reference page for %s', fname));
                html = fileread(htmlFile);
                for k = 1:numel(ids)
                    testCase.verifyTrue(contains(html, ids{k}{1}), sprintf( ...
                        'Error id "%s" raised in %s.m is not documented in its HTML page.', ...
                        ids{k}{1}, fname));
                end
            end
        end

        function testVersionConsistency(testCase)
            v = gracefoReading.version();
            contents = fileread(fullfile(testCase.codeDir, ...
                '+gracefoReading', 'Contents.m'));
            testCase.verifyTrue(contains(contents, ['Version ', v]), ...
                'Contents.m version differs from gracefoReading.version().');
            productPage = fullfile(testCase.htmlDir, 'gracefoReading_product_page.html');
            testCase.verifyTrue(isfile(productPage));
            testCase.verifyTrue(contains(fileread(productPage), ['v', v]), ...
                'Product page version differs from gracefoReading.version().');
        end

        function testEveryPublicFunctionHasHtmlPage(testCase)
            pkgDir = fullfile(testCase.codeDir, '+gracefoReading');
            srcFiles = dir(fullfile(pkgDir, '*.m'));
            for s = 1:numel(srcFiles)
                [~, fname] = fileparts(srcFiles(s).name);
                if strcmpi(fname, 'Contents'), continue; end
                htmlFile = fullfile(testCase.htmlDir, ...
                    ['gracefoReading.', fname, '.html']);
                testCase.verifyTrue(isfile(htmlFile), ...
                    sprintf('Missing HTML reference page for public function %s', fname));
            end
        end

        function testHelpBlocksMeetDocumentationStandard(testCase)
            % Mirror of docsrc/auditHelp.py inside MATLAB: every function
            % help block must carry the documented sections, so that the
            % documentation generators can parse it.
            files = [ ...
                dir(fullfile(testCase.codeDir, '+gracefoReading', '*.m')); ...
                dir(fullfile(testCase.codeDir, '+gracefoReading', '+internal', '*.m'))];
            required = {'SYNTAX', 'DESCRIPTION', 'INPUT', 'OUTPUT', ...
                        'ACCURACY AND LIMITATIONS'};
            for s = 1:numel(files)
                [~, fname] = fileparts(files(s).name);
                if strcmpi(fname, 'Contents'), continue; end
                blk = localHelpBlock(fileread(fullfile(files(s).folder, files(s).name)));
                for r = 1:numel(required)
                    testCase.verifyTrue(contains(blk, ['%   ', required{r}]), ...
                        sprintf('%s.m: help block lacks section %s', fname, required{r}));
                end
                testCase.verifyTrue( ...
                    contains(blk, '%   EXAMPLE') || contains(blk, '%   EXAMPLES'), ...
                    sprintf('%s.m: help block lacks an EXAMPLE section', fname));
            end
        end

        function testHelpMetadataAndAuthorship(testCase)
            files = [ ...
                dir(fullfile(testCase.codeDir, '+gracefoReading', '*.m')); ...
                dir(fullfile(testCase.codeDir, '+gracefoReading', '+internal', '*.m')); ...
                dir(fullfile(testCase.codeDir, 'tests', '*.m')); ...
                dir(fullfile(testCase.codeDir, 'ci', '*.m'))];
            v = gracefoReading.version();
            for s = 1:numel(files)
                [~, fname] = fileparts(files(s).name);
                blk = localHelpBlock(fileread(fullfile(files(s).folder, files(s).name)));
                flat = regexprep(strrep(blk, '%', ' '), '\s+', ' ');
                testCase.verifyTrue(contains(blk, ['gracefoReading v', v]), ...
                    sprintf('%s.m: metadata block does not carry version %s', fname, v));
                testCase.verifyTrue(contains(flat, ...
                    'Developed by Matthias Weigelt with the help of Anthropic Claude'), ...
                    sprintf('%s.m: missing authorship line', fname));
                testCase.verifyNotEmpty(regexp(blk, 'Created:\s+\d{4}-\d{2}-\d{2}', 'once'), ...
                    sprintf('%s.m: missing Created date', fname));
                testCase.verifyNotEmpty(regexp(blk, 'Updated:\s+\d{4}-\d{2}-\d{2}', 'once'), ...
                    sprintf('%s.m: missing Updated date', fname));
            end
        end

        function testOptionsDocumentDefaults(testCase)
            % Every name-value option of a public function must be
            % documented with its default, since that is what users read.
            pkgDir = fullfile(testCase.codeDir, '+gracefoReading');
            files = dir(fullfile(pkgDir, '*.m'));
            quote = char(39);
            for s = 1:numel(files)
                [~, fname] = fileparts(files(s).name);
                if strcmpi(fname, 'Contents'), continue; end
                txt = fileread(fullfile(pkgDir, files(s).name));
                opts = regexp(txt, 'options\.([A-Za-z]\w*)', 'tokens');
                blk = localHelpBlock(txt);
                seen = {};
                for k = 1:numel(opts)
                    name = opts{k}{1};
                    if any(strcmp(name, seen)), continue; end
                    seen{end+1} = name; %#ok<AGROW>
                    % The entry ends at the NEXT entry header or the
                    % next section - not at any continuation line that
                    % happens to open with a quoted option name, such
                    % as "'QualityBitMask'." inside the body of
                    % 'ApplyQualityFlags'. That truncation cut the
                    % Default: line off two entries. Mirror of ENTRY_RE
                    % in docsrc/helpparse.py; keep the two in step.
                    nextEntry = ['\n%\s{4,6}', quote, '?[A-Za-z_][\w.', ...
                                 quote, ']*', quote, '?\s+-\s'];
                    pattern = ['%\s+', quote, name, quote, '\s+-.*?(?=', ...
                               nextEntry, '|\n%\s{3}[A-Z])'];
                    entry = regexp(blk, pattern, 'match', 'once');
                    testCase.verifyNotEmpty(entry, sprintf( ...
                        '%s.m: option %s is not documented in the help text', fname, name));
                    if ~isempty(entry)
                        testCase.verifyTrue(contains(entry, 'Default:'), sprintf( ...
                            '%s.m: option %s does not state a default', fname, name));
                    end
                end
            end
        end

        function testHtmlPagesCarryStandardSections(testCase)
            pages = dir(fullfile(testCase.htmlDir, 'gracefoReading.*.html'));
            testCase.verifyNotEmpty(pages);
            for p = 1:numel(pages)
                html = fileread(fullfile(pages(p).folder, pages(p).name));
                for sec = {'Syntax', 'Description', 'Input Arguments', ...
                           'Output Arguments', 'Accuracy and Limitations', 'Examples'}
                    testCase.verifyTrue(contains(html, ['<h2>', sec{1}, '</h2>']), ...
                        sprintf('%s: generated page lacks the %s section', ...
                        pages(p).name, sec{1}));
                end
                testCase.verifyTrue(contains(html, 'Matthias Weigelt'), ...
                    sprintf('%s: generated page lacks the authorship footer', pages(p).name));
            end
        end

    end
end

function blk = localHelpBlock(txt)
% Leading help comment block of a MATLAB source file.
lines = splitlines(string(txt));
first = 1;
if ~startsWith(strtrim(lines(1)), '%')
    % The declaration may span several physical lines through ...
    % continuations; the help block starts after the LAST of them. The
    % old rule "first = 2" was the same assumption that let a help block
    % be written into the middle of a declaration and then certified as
    % correct. Mirror of declaration_end() in docsrc/mfile.py.
    k = 1;
    while k < numel(lines) && localContinues(lines(k))
        k = k + 1;
    end
    first = k + 1;
end
last = first - 1;
for i = first:numel(lines)
    if startsWith(lines(i), '%'), last = i; else, break; end
end
if last < first
    blk = '';
else
    blk = char(join(lines(first:last), newline));
end
end

function tf = localContinues(line)
% True if LINE is continued on the next physical line.
% Mirror of continues() in docsrc/mfile.py; keep the two in step.
s = strtrim(line);
if startsWith(s, '%'), tf = false; return; end
i = strfind(line, '...');
if isempty(i), tf = false; return; end
before = extractBefore(line, i(1));
tf = mod(count(before, ''''), 2) == 0 && ~contains(before, '%');
end
