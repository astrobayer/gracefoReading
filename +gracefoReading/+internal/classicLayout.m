function layout = classicLayout(product)
%CLASSICLAYOUT  Record layout of a classic GRACE (2002-2017) product.
%
%   SYNTAX
%     layout = gracefoReading.internal.classicLayout(product)
%
%   DESCRIPTION
%     SINGLE POINT OF ACCESS for what a classic GRACE Level-1B record
%     contains. Classic headers, unlike the GRACE-FO YAML ones, do NOT
%     declare their columns, so the layout has to come from somewhere
%     else - and until 2026-09-22 it came from the GRACE Level-1B
%     handbook read from memory, which is what obligation O-1 records
%     as unsafe.
%
%     Every entry below is now MEASURED on a real RL02 file of
%     2008-01-01 supplied by the owner (G-02, issue #17), for GRACE A
%     and GRACE B where both exist. The measurement is not a reading
%     of one record: for each product the declared record count times
%     the derived record length reproduces the file size exactly, the
%     first epoch equals the header's TIME FIRST OBS, and a physical
%     quantity in the record was checked against what it must be -
%     see ACCURACY AND LIMITATIONS for each product's oracle.
%
%     The field TYPES and OFFSETS are therefore evidence. The field
%     NAMES come from one of two DOCUMENTED sources and never from
%     memory: the GRACE-FO sibling product, whose YAML header declares
%     them, or the GRACE Level-1B Data Product User Handbook v1.3
%     (JPL D-22027, March 2010), whose chapter 6 tabulates the classic
%     record fields in order. MAG1B is named from the handbook
%     (section 6.8, pages 38-39) and everything else from its sibling.
%     Either way the measured magnitudes have to agree with the
%     assignment; where a name could not be justified that way the
%     product is refused rather than guessed at.
%
%   INPUT
%     product - string | char, 1x1
%                Product token from the file name, e.g. "ACC1B".
%                Options: ACC1B | SCA1B | GNV1B | KBR1B | THR1B |
%                MAS1B | MAG1B; any other value returns an empty
%                layout.
%                Required, positional.
%
%   OUTPUT
%     layout - struct, 1x1
%                Empty struct for an unknown product. Otherwise:
%                names (cellstr [1 x C]) column names in record
%                order; types (cellstr [1 x C]) one of int32, int16,
%                uint8, single, double, char; conditional (logical
%                [1 x C]) true for columns present only when their
%                prod_flag bit is set; prodFlagIdx (double) index of
%                the prod_flag column or 0; recordBytes (double)
%                fixed record length, or 0 when records are variable;
%                oracle (char) the physical check this layout was
%                verified against.
%
%   ACCURACY AND LIMITATIONS
%     - Verified per product on ACC1B/SCA1B/GNV1B/THR1B/MAS1B/MAG1B
%       for both GRACE A and B, and on the single combined KBR1B
%       (satellite token X), all of 2008-01-01, release 02:
%         ACC1B  78 B/record; linear accelerations <= 1.3e-6 m/s2 and
%                angular <= 1e-3 rad/s2, residual columns ~1e-9.
%         SCA1B  47 B/record; quaternion norm within 1e-6 of unity in
%                every one of 16 818 (A) and 17 222 (B) records.
%         GNV1B  103 B/record; |r| 6827-6862 km and |v| ~7.6 km/s.
%         KBR1B  93 B/record; the numerical derivative of the biased
%                range matches the range-rate column to a median
%                5.8e-6 m/s, and the four SNR columns fall in
%                57-69 dB.
%         THR1B  179 B/record; 42 counter columns, fractional time in
%                microseconds.
%         MAS1B  variable; the record walk consumed the data section
%                to the byte, and the thruster-based and tank-based
%                spacecraft masses agree to 4 g (476.855 / 476.851 kg)
%                with the GRACE-FO prod_flag bit meanings applied.
%         MAG1B  63 B/record; 86 400 records x 63 B reproduces the
%                5 443 200-byte data section exactly, the first and
%                last epochs equal the header's TIME FIRST/LAST OBS to
%                the microsecond, and |B| comes out at 18.3-54.5 uT
%                (median 38.9) on GRACE A and 19.5-54.4 uT on GRACE B
%                - the geomagnetic field strength at 480 km. The six
%                magnetorquer currents stay within 0-120 mA of the
%                torque_cal full scale, which is 120 all day.
%     - **Not supported, deliberately**: classic AHK1B. Its records
%       are variable-length - 8 700 records over 526 350 data bytes is
%       60.5 bytes each, so they cannot be fixed - and the handbook
%       has no AHK1B entry in chapter 6 at all: the product appears
%       only in the report-file appendix, which names the eight
%       qualflg bits and nothing else. The per-bit value TYPES that a
%       prod_flag walk needs are therefore not documented anywhere
%       available here, and one file cannot reveal them. Naming them
%       from memory is the failure O-1 exists to prevent, so AHK1B
%       raises unsupportedClassicProduct. See HANDOVER O-15.
%     - **Release 02 and release 03.** The six products were measured
%       on RL02. RL03 publishes only SCA1B and KBR1B (plus the ACT1B
%       transplant archive), and both were checked on 2026-09-22: the
%       record lengths are identical, 47 and 93 bytes, and the oracles
%       hold - the RL03 SCA1B of 2008-01-20 keeps its quaternion norm
%       to 9.6e-11 over 86 398 records, and the RL03 KBR1B of
%       2008-01-01 is BIT-IDENTICAL to the RL02 file of the same day
%       in every ranging observable and all four SNRs, differing only
%       in the reprocessed antenna-centre correction (1.7 micrometre)
%       and in qualflg. Two independently produced files agreeing that
%       way under one layout is stronger evidence than either alone.
%       The ACT1B transplant archive was not supplied and is not
%       claimed.
%     - RL03 SCA1B samples at 1 Hz where the RL02 file samples at 5 s,
%       and its sca_id uses head codes RL02 does not (1, 4, 5, 6, 7,
%       8 against 1, 2, 4). Both are properties of the product, not of
%       the record layout.
%     - Classic qualflg is a single BYTE bitmask in the binary files,
%       not an 8-character bit string; parseClassicBinary renders it
%       as the same 8-character string the GRACE-FO products use, so
%       decodeQualFlags works identically on both.
%
%   EXAMPLE
%     % internal use only; called by parseClassicBinary:
%     L = gracefoReading.internal.classicLayout('SCA1B');
%     fprintf('%s: %d columns, %d bytes/record\n', 'SCA1B', ...
%         numel(L.names), L.recordBytes);
%
%   See also gracefoReading.readL1b,
%            gracefoReading.internal.parseClassicBinary,
%            gracefoReading.internal.parseClassicProduct
%
%   Toolbox:  gracefoReading v1.1.0
%   Created:  2026-09-22
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    product (1,1) string
end

switch upper(product)
    case 'ACC1B'
        spec = { {'gps_time'}, 'int32'
                 {'GRACE_id'}, 'char'
                 {'lin_accl_x','lin_accl_y','lin_accl_z', ...
                  'ang_accl_x','ang_accl_y','ang_accl_z', ...
                  'acl_x_res','acl_y_res','acl_z_res'}, 'double'
                 {'qualflg'}, 'uint8' };
        oracle = 'accelerations within instrument range; residual columns ~1e-9';

    case 'SCA1B'
        spec = { {'gps_time'}, 'int32'
                 {'GRACE_id'}, 'char'
                 {'sca_id'}, 'uint8'
                 {'quatangle','quaticoeff','quatjcoeff','quatkcoeff'}, 'double'
                 {'qual_rss'}, 'double'
                 {'qualflg'}, 'uint8' };
        oracle = 'quaternion norm within 1e-6 of unity in every record';

    case 'GNV1B'
        spec = { {'gps_time'}, 'int32'
                 {'GRACE_id'}, 'char'
                 {'coord_ref'}, 'char'
                 {'xpos','ypos','zpos','xpos_err','ypos_err','zpos_err', ...
                  'xvel','yvel','zvel','xvel_err','yvel_err','zvel_err'}, 'double'
                 {'qualflg'}, 'uint8' };
        oracle = 'orbit radius 6827-6862 km and speed ~7.6 km/s';

    case 'KBR1B'
        % No satellite id: KBR1B is the A+B link, file token X.
        spec = { {'gps_time'}, 'int32'
                 {'biased_range','range_rate','range_accl','iono_corr', ...
                  'lighttime_corr','lighttime_rate','lighttime_accl', ...
                  'ant_centr_corr','ant_centr_rate','ant_centr_accl'}, 'double'
                 {'K_A_SNR','Ka_A_SNR','K_B_SNR','Ka_B_SNR'}, 'int16'
                 {'qualflg'}, 'uint8' };
        oracle = 'd(biased_range)/dt matches range_rate to 5.8e-6 m/s; SNR 57-69 dB';

    case 'THR1B'
        spec = { {'time_intg'}, 'int32'
                 {'time_frac'}, 'int32'
                 {'time_ref'}, 'char'
                 {'GRACE_id'}, 'char'
                 localThrusterNames(), 'int32'
                 {'qualflg'}, 'uint8' };
        oracle = '42 counter columns; fractional time in microseconds';

    case 'MAS1B'
        spec = { {'time_intg'}, 'int32'
                 {'time_frac'}, 'int32'
                 {'time_ref'}, 'char'
                 {'GRACE_id'}, 'char'
                 {'qualflg'}, 'uint8'
                 {'prod_flag'}, 'uint8'
                 {'mass_thr','mass_thr_err','mass_tnk','mass_tnk_err', ...
                  'gas_mass_thr1','gas_mass_thr2', ...
                  'gas_mass_tnk1','gas_mass_tnk2'}, 'double' };
        oracle = 'thruster- and tank-based spacecraft mass agree to 4 g';

    case 'MAG1B'
        % Named from the handbook, section 6.8 (pp. 38-39), which
        % tabulates these eighteen fields in exactly this order with
        % exactly these widths. Nothing here is inferred from a
        % sibling: GRACE-FO publishes no MAG1B of this shape.
        spec = { {'time_intg'}, 'int32'
                 {'time_frac'}, 'int32'
                 {'time_ref'}, 'char'
                 {'GRACE_id'}, 'char'
                 {'MfvX_RAW','MfvY_RAW','MfvZ_RAW'}, 'single'
                 {'torque1A','torque2A','torque3A', ...
                  'torque1B','torque2B','torque3B'}, 'single'
                 {'MF_BCalX','MF_BCalY','MF_BCalZ'}, 'single'
                 {'torque_cal'}, 'single'
                 {'qualflg'}, 'uint8' };
        oracle = '|B| 18.3-54.5 microtesla; 63 B/record reproduces the file size exactly';

    otherwise
        layout = struct();
        return
end

names = {}; types = {};
for k = 1:size(spec, 1)
    grp = spec{k, 1};
    names = [names, grp];                              %#ok<AGROW>
    types = [types, repmat(spec(k, 2), 1, numel(grp))]; %#ok<AGROW>
end

layout = struct();
layout.names = names;
layout.types = types;
layout.prodFlagIdx = find(strcmp(names, 'prod_flag'), 1);
if isempty(layout.prodFlagIdx)
    layout.prodFlagIdx = 0;
end
layout.conditional = false(1, numel(names));
if layout.prodFlagIdx > 0
    layout.conditional(layout.prodFlagIdx+1:end) = true;
end
layout.oracle = oracle;

widths = cellfun(@localWidth, types);
if layout.prodFlagIdx > 0
    layout.recordBytes = 0;                 % variable, see parseClassicBinary
else
    layout.recordBytes = sum(widths);
end
end

% ========================================================================
function w = localWidth(t)
switch t
    case {'char', 'uint8'}, w = 1;
    case 'int16',           w = 2;
    case {'int32','single'},w = 4;
    case 'double',          w = 8;
    otherwise
        error('gracefoReading:readL1b:badClassicType', ...
            'Unknown classic field type "%s".', t);
end
end

% ========================================================================
function names = localThrusterNames()
% The 42 counter columns, in record order. Named from the GRACE-FO
% THR1B header, which declares exactly these 42 between GRACEFO_id and
% qualflg; the classic record carries exactly 42 int32 in the same
% position, and its first six counters repeat in two branches as the
% attitude-thruster naming implies.
att = {};
for branch = 1:2
    for th = 1:6
        att{end+1} = sprintf('thrust_count_att_ctrl_%d_%d', branch, th); %#ok<AGROW>
    end
end
onAtt = {};
for branch = 1:2
    for th = 1:6
        onAtt{end+1} = sprintf('on_time_att_ctrl_%d_%d', branch, th); %#ok<AGROW>
    end
end
accum = {'accum_dur_att_ctrl'};
for k = 1:11
    accum{end+1} = sprintf('accum_dur_undef_%d', k); %#ok<AGROW>
end
names = [att, {'thrust_count_undef_1','thrust_count_undef_2'}, ...
         onAtt, {'on_time_orb_ctrl_1','on_time_orb_ctrl_2'}, ...
         accum, {'accum_dur_orb_ctrl','accum_dur_undef_12'}];
end
