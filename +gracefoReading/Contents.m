% GRACEFOREADING  GRACE-FO Level-1B ASCII data reading toolbox (+gracefoReading).
% Version 1.0.2  2026-09-09
%
% Reading
%   gracefoReading.readL1b               - Read one Level-1B ASCII product file.
%   gracefoReading.readL1bMulti          - Read and concatenate several files.
%   gracefoReading.readItsgProduct       - Read a TU Graz (ITSG) satellite orbit
%                                          product: orbit, covariance, attitude, forces.
%
% Batch tools
%   gracefoReading.findL1bFiles          - Locate product files in an archive by
%                                          product/date/satellite, with coverage report.
%   gracefoReading.findGaps              - Detect sampling gaps and contiguous segments.
%
% Utilities
%   gracefoReading.decodeQualFlags       - Decode bit-string quality/product flags
%                                          using the file's own header metadata.
%   gracefoReading.checkQuaternionNorm   - Unit-norm sanity check for SCA1B quaternions.
%   gracefoReading.writeGroopsInstrument - Export to GROOPS ASCII instrument format.
%   gracefoReading.readGroopsInstrument  - Read GROOPS ASCII instrument files.
%   gracefoReading.version               - Toolbox version for programmatic checks.
%
% Use "doc gracefoReading.readL1b" for full reference pages, or
% "help gracefoReading.<functionName>" for plain text.
%
% Validated against real GRACE-FO RL04 files (ACT1B, GNV1B, SCA1B,
% THR1B, KBR1B, LRI1B, MAS1B); see tests/testRealData.m.
%
%   Toolbox:  gracefoReading v1.0.2
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Matthias Weigelt with support of Anthropic Claude
