function [ok, stats] = checkQuaternionNorm(obs, aux, options)
%CHECKQUATERNIONNORM  Verify unit norm of SCA1B attitude quaternions.
%
%   SYNTAX
%     [ok, stats] = gracefoReading.checkQuaternionNorm(obs, aux)
%     [ok, stats] = gracefoReading.checkQuaternionNorm(obs, aux, Name, Value)
%
%   DESCRIPTION
%     Checks, record by record, that the star-camera attitude
%     quaternion read from an SCA1B product has unit norm - a cheap and
%     effective detector of parsing errors, column mix-ups and corrupt
%     records before the attitude data enter any rotation. The four
%     components are located by name (quatangle, quaticoeff,
%     quatjcoeff, quatkcoeff) in aux.obsNames, so obs can be passed
%     exactly as returned by readL1b. Rotation and coordinate
%     transformations are deliberately out of scope for this toolbox;
%     only the norm sanity check is provided.
%
%   INPUT
%     obs - double, [N x M]
%                Observation matrix from readL1b or readL1bMulti of an
%                SCA1B product.
%                Required, positional.
%
%     aux - struct, 1x1
%                Matching aux output; aux.obsNames is used to locate
%                the four quaternion columns.
%                Required, positional.
%
%     'Tolerance' - double, 1x1
%                Maximum allowed absolute deviation |norm(q) - 1| per
%                record.
%                Options: any positive value; 1e-6 is loose enough for
%                the ASCII rounding of the products and tight enough to
%                expose real problems.
%                Default: 1e-6.
%
%   OUTPUT
%     ok    - logical, [N x 1]
%                True where |norm(q) - 1| <= Tolerance.
%     stats - struct, 1x1
%                  n             double, records checked
%                  numViolations double, count of ok == false
%                  maxDeviation  double, max |norm(q) - 1|
%                  rmsDeviation  double, rms of (norm(q) - 1)
%                  tolerance     double, tolerance used
%                  columns       double [1 x 4], obs column indices in
%                                the order quatangle, i, j, k
%
%   ACCURACY AND LIMITATIONS
%     - The ASCII products store quaternion components with finite
%       digits, so a small nonzero deviation is normal; real SCA1B
%       files typically show |norm-1| of order 1e-9 to 1e-8.
%     - Unit norm is necessary but not sufficient for correctness: a
%       quaternion can be normalised and still describe a wrong
%       attitude, and a sign flip (q and -q describe the same rotation)
%       is invisible to this test.
%     - The check requires all four components in obs; if a product
%       stores any of them as an auxiliary column the function raises
%       columnsNotFound rather than guessing.
%     - No renormalisation is performed. Correcting attitude data is
%       left to the processing that uses it.
%
%   ERRORS
%     gracefoReading:checkQuaternionNorm:columnsNotFound
%       one of the four quaternion columns is absent from aux.obsNames,
%       i.e. obs is not from an SCA1B-like product
%
%   EXAMPLES
%     % 1. quick verdict for one day
%     [t, q, aux] = gracefoReading.readL1b('SCA1B_2020-01-01_C_04.txt');
%     [ok, stats] = gracefoReading.checkQuaternionNorm(q, aux);
%     fprintf('max |norm-1| = %.3g, violations: %d\n', ...
%             stats.maxDeviation, stats.numViolations);
%
%     % 2. inspect the offending epochs
%     bad = find(~ok);
%     disp(t(bad, :));
%
%   See also gracefoReading.readL1b, gracefoReading.decodeQualFlags
%
%   Toolbox:  gracefoReading v1.0.2
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    obs (:,:) double
    aux (1,1) struct
    options.Tolerance (1,1) double {mustBePositive} = 1e-6
end

wanted = {'quatangle', 'quaticoeff', 'quatjcoeff', 'quatkcoeff'};
cols = zeros(1, 4);
for k = 1:4
    i = find(strcmpi(aux.obsNames, wanted{k}), 1);
    if isempty(i)
        error('gracefoReading:checkQuaternionNorm:columnsNotFound', ...
            ['Quaternion column "%s" not found in aux.obsNames {%s}. ', ...
             'Is this an SCA1B product?'], wanted{k}, strjoin(aux.obsNames, ', '));
    end
    cols(k) = i;
end

q = obs(:, cols);
dev = sqrt(sum(q.^2, 2)) - 1;
ok = abs(dev) <= options.Tolerance;

stats = struct();
stats.n             = size(q, 1);
stats.numViolations = nnz(~ok);
stats.maxDeviation  = max(abs(dev), [], 'omitnan');
stats.rmsDeviation  = sqrt(mean(dev.^2, 'omitnan'));
stats.tolerance     = options.Tolerance;
stats.columns       = cols;
end
