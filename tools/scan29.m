function scan29()
%SCAN29  Throwaway: real CLK1B/TIM1B bytes for gracefoReading#29 fixtures.
%   Not for merge. Prints header facts, the zero-time TIM1B records, the
%   near-zero eps_time CLK1B records and base64 extracts of the files.
pool = string(getenv("READING_DATA_POOL"));
day = fullfile(pool, "GRACEFO", "L1B", "RL04", "2020", "2020-01-02");
for name = ["CLK1B_2020-01-02_C_04.txt", "CLK1B_2020-01-02_D_04.txt", ...
            "TIM1B_2020-01-02_C_04.txt", "TIM1B_2020-01-02_D_04.txt"]
    try
        one(fullfile(day, name), name);
    catch err
        fprintf('SCAN %s FAILED: %s\n', name, err.message);
    end
end
end

function one(p, name)
fid = fopen(p, 'r'); b = fread(fid, Inf, '*uint8')'; fclose(fid);
nl = find(b == 10);
starts = [1, nl(1:end-1) + 1];
lines = arrayfun(@(s, e) char(b(s:e)), starts, nl, 'UniformOutput', false);
crlf = sum(b(max(nl - 1, 1)) == 13);
h = find(contains(lines, "End of YAML header"), 1);
fprintf('SCAN %s: %d bytes, %d lines, %d CRLF, header ends at line %d, %d records, trailing byte %d\n', ...
    name, numel(b), numel(lines), crlf, h, numel(lines) - h, b(end));
rec = lines(h + 1:end);
tok = cellfun(@(s) sscanf(s, '%f', 1), rec, 'UniformOutput', false);
if startsWith(name, "TIM1B")
    c = cellfun(@(s) textscan(strtrim(s), '%s'), rec);
    c = cellfun(@(x) x', c, 'UniformOutput', false);
    zero = find(cellfun(@(x) numel(x) >= 5 && str2double(x{4}) == 0 && str2double(x{5}) == 0, c));
    fprintf('SCAN %s: %d records with rcvtime_intg = rcvtime_frac = 0, at record indices %s\n', ...
        name, numel(zero), mat2str(zero));
    for k = zero(:)'
        fprintf('ZERO %s rec %d: %s', name, k, rec{k});
    end
    if ~isempty(zero)
        lo = max(1, zero(1) - 10); hi = min(numel(rec), lo + 59);
    else
        lo = 1; hi = 60;
    end
else
    c = cellfun(@(s) textscan(strtrim(s), '%s'), rec);
    c = cellfun(@(x) x', c, 'UniformOutput', false);
    eps = cellfun(@(x) str2double(x{4}), c);
    small = find(abs(eps) < 1e-6);
    fprintf('SCAN %s: %d records with |eps_time| < 1e-6 s, at record indices %s\n', ...
        name, numel(small), mat2str(small(:)'));
    for k = small(:)'
        fprintf('SMALLEPS %s rec %d: %s', name, k, rec{k});
    end
    fprintf('SCAN %s: eps_time min %.9g max %.9g median %.9g\n', name, min(eps), max(eps), median(eps));
    lo = 1; hi = 60;
end
fprintf('SCAN %s: extract records %d..%d\n', name, lo, hi);
ext = uint8([lines{1:h}, rec{lo:hi}]);
s = char(matlab.net.base64encode(ext));
for k = 1:76:numel(s)
    fprintf('B64 %s %s\n', name, s(k:min(end, k + 75)));
end
fprintf('B64END %s %d bytes\n', name, numel(ext));
end
