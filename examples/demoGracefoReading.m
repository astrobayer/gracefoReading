%DEMOGRACEFOREADING  Guided tour of the gracefoReading toolbox.
%
%   SYNTAX
%     demoGracefoReading
%     run(fullfile(toolboxRoot, 'examples', 'demoGracefoReading.m'))
%
%   DESCRIPTION
%     Self-contained walkthrough of the main workflows: reading a
%     product, decoding flags from the file's own header, exact
%     nanosecond time, gap analysis, content-hashed caching, GROOPS
%     export and read-back, and archive search. It uses only the two
%     small real PO.DAAC files bundled in tests/realdata/ (MAS1B and
%     THR1B of 2020-01-01), so it runs anywhere the toolbox is
%     installed. Run it section by section in the editor, or as a
%     script for a quick smoke test of an installation.
%
%   INPUT
%     (none) - the script locates the toolbox relative to its own path
%
%   OUTPUT
%     (none) - prints a short report and opens two figures
%
%   ACCURACY AND LIMITATIONS
%     - The bundled MAS1B file is hourly and THR1B is event-driven, so
%       the plots illustrate the interface rather than typical 1 Hz
%       science data.
%     - Cache timings printed by the script depend on the file system
%       and are indicative only; the benefit of caching grows with file
%       size, and the two demo files are small.
%     - The script writes to tempdir (cache and GROOPS export) and
%       leaves those files in place for inspection.
%
%   EXAMPLE
%     % from the toolbox root
%     run(fullfile('examples', 'demoGracefoReading.m'))
%
%   See also gracefoReading.readL1b, gracefoReading.findGaps,
%            gracefoReading.findL1bFiles
%
%   Toolbox:  gracefoReading v1.1.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

%% Setup
here = fileparts(mfilename('fullpath'));
run(fullfile(fileparts(here), 'setupGraceFOReading.m'));
dataDir = fullfile(fileparts(here), 'tests', 'realdata');

%% Read a product: MAS1B (prod_flag variable-length records)
masFile = fullfile(dataDir, 'MAS1B_2020-01-01_C_04.txt');
[t, m, aux] = gracefoReading.readL1b(masFile);
fprintf('MAS1B: %d records, columns: %s\n', size(m,1), strjoin(aux.obsNames, ', '));

figure('Name', 'MAS1B gas masses');
i1 = strcmp(aux.obsNames, 'gas_mass_tnk1');
i2 = strcmp(aux.obsNames, 'gas_mass_tnk2');
plot(t(:,2)/3600, m(:,i1), '.-', t(:,2)/3600, m(:,i2), '.-');
xlabel('hours of 2020-01-01'); ylabel('gas mass [kg]');
legend({'tank 1','tank 2'}); grid on;

%% Decode flags straight from the file's own header
[~, report] = gracefoReading.decodeQualFlags(aux, 'prod_flag');
disp(report)

%% Exact int64 GPS-nanosecond time (lossless pipeline handoff)
tns = gracefoReading.readL1b(masFile, 'TimeFormat', 'gpsns');
fprintf('first epoch: %d ns GPS  (class %s)\n', tns(1), class(tns));

%% Gap analysis (MAS1B is nominally hourly)
[gaps, stats] = gracefoReading.findGaps(t, 'NominalRate', 3600);
fprintf('gaps: %d, longest %.1f s, %d contiguous segment(s)\n', ...
    stats.numGaps, stats.longestGapSec, size(stats.segments, 1));

%% Content-hashed caching: second read loads instead of parses
cacheDir = fullfile(tempdir, 'gracefoReadingDemoCache');
tic; gracefoReading.readL1b(masFile, 'CacheDir', cacheDir); t1 = toc;
tic; [~, ~, auxC] = gracefoReading.readL1b(masFile, 'CacheDir', cacheDir); t2 = toc;
fprintf('parse: %.3f s -> cached load: %.3f s (cacheHit=%d)\n', t1, t2, auxC.cacheHit);

%% THR1B thruster events
thrFile = fullfile(dataDir, 'THR1B_2020-01-01_C_04.txt');
[tt, thr, auxT] = gracefoReading.readL1b(thrFile);
figure('Name', 'THR1B activity');
plot(tt(:,2)/3600, sum(thr, 2, 'omitnan'), '.');
xlabel('hours of 2020-01-01'); ylabel('sum of thruster counters');
title(sprintf('THR1B: %d event records', size(thr,1))); grid on;

%% GROOPS export + read-back roundtrip
grpFile = fullfile(tempdir, 'mas1b_demo.groops.txt');
gracefoReading.writeGroopsInstrument(grpFile, t, m(:, i1 | i2));
[tg, mg, info] = gracefoReading.readGroopsInstrument(grpFile);
fprintf('GROOPS roundtrip: %d records, type %d, max |dt| = %.3g s\n', ...
    info.numRecords, info.typeCode, ...
    max(abs((tg(:,1)-t(:,1))*86400 + tg(:,2)-t(:,2))));

%% Batch tools (illustrative; searches the bundled folder)
[files, rep] = gracefoReading.findL1bFiles(dataDir, "MAS1B");
fprintf('findL1bFiles: %d file(s), %s .. %s\n', numel(files), ...
    string(rep.firstDate), string(rep.lastDate));
