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
%     record fields in order, or the JPL GRACE Level-1 read software
%     (GraceReadSW_L1, release 2010-03-31), the producer's own
%     reference implementation, whose GRACEiolib.h declares one C
%     struct per product. MAG1B is named from the handbook (section
%     6.8, pages 38-39), AHK1B from the read software (AHK1X_t is a
%     typedef of ACC1A_t; ReadACC1AFRecord.c walks the prod_flag bit
%     by bit), and everything else from its GRACE-FO sibling - which
%     the read software then independently confirms, struct by
%     struct, for all seven. Nothing from either document is vendored
%     into this repository.
%     Either way the measured magnitudes have to agree with the
%     assignment; where a name could not be justified that way the
%     product is refused rather than guessed at.
%
%     A third document corroborates rather than names: the GRACE
%     Algorithm Theoretical Basis Document for Level-1B Data
%     Processing (JPL D-27672 / GRACE 327-741, v1.2, 2006). It holds
%     no record formats at all - no field widths, no types, no
%     prod_flag - but it states what each module WRITES, which is an
%     independent check on a column count. See the ACC1B entry below.
%
%   INPUT
%     product - string | char, 1x1
%                Product token from the file name, e.g. "ACC1B".
%                Options: ACC1B | SCA1B | GNV1B | KBR1B | THR1B |
%                MAS1B | MAG1B | AHK1B; any other value returns an
%                empty layout.
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
%                prodFlagBits (double) how many bits the flag
%                addresses, 8 or 32, or 0; asciiNames (cellstr
%                [1 x C]) column order of the ASCII variant, which
%                equals names except for MAG1B; asciiBitString
%                (cellstr) columns the ASCII variant renders as a bit
%                string beyond qualflg and prod_flag; oracle (char)
%                the physical check this layout was verified against;
%                units (cellstr [1 x C]) the unit of each column, ''
%                where the handbook gives none; flagMeanings (struct)
%                per flag column ('qualflg', MAS1B 'prod_flag') a
%                cellstr of "bit N = text" lines, the form a GRACE-FO
%                header lists them in; unitSource (char) the handbook
%                section both come from.
%
%   ACCURACY AND LIMITATIONS
%     - Verified per product on ACC1B/SCA1B/GNV1B/THR1B/MAS1B/MAG1B/
%       AHK1B for both GRACE A and B, and on the single combined
%       KBR1B (satellite token X), all of 2008-01-01, release 02:
%         ACC1B  78 B/record; linear accelerations <= 1.3e-6 m/s2 and
%                angular <= 1e-3 rad/s2, residual columns ~1e-9.
%                The nine columns are CORROBORATED by the ATBD
%                (D-27672 section 3.1.4 step 8), which says ACC_1B
%                carries "the six components of compressed ACC data
%                (3 linear and 3 angular accelerations), the fit
%                residuals and quality flags" - six plus three, from
%                a document that never mentions a byte. Step 6 adds
%                why there are THREE residuals and not six: they are
%                compressed minus uncompressed LINEAR acceleration at
%                the integer second, with the quality flag set above
%                10 micron/s2 - the same threshold the GRACE-FO
%                ACH1B header states for qualflg bit 2.
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
%         AHK1B  variable, and unlike any other classic product in
%                two ways: prod_flag is FOUR bytes, addressing 29
%                conditional columns rather than 8, and those columns
%                do NOT share a type - seven double, eighteen single,
%                then uint8, uint16, uint8, int32. The record walk
%                consumed the data section to the byte on four files
%                (JPL's own 2003 RL00 samples for A and B, and the
%                RL02 files of 2008-01-01 for A and B), and the named
%                supply rails come out at nominal: +15 V at 14.91,
%                -15 V at -14.90, +5 V at 5.05, +48 V at 50.18 and
%                -48 V at -50.39, with four electronics temperatures
%                between 17 and 52 C. Read one width wrong anywhere
%                in that walk and every field after it is garbage, so
%                the voltages are the oracle.
%     - **Not supported**: every other classic product, TNK1B, IHK1B,
%       CLK1B, TIM1B, USO1B and the vector-offset files among them.
%       No real file of any of them has been read here, so they raise
%       unsupportedClassicProduct rather than being decoded on a
%       guess.
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
%     - **Two integer types were corrected on 2026-09-22** against the
%       JPL read software, which declares them unsigned where this
%       table had them signed: KBR1B's four SNR columns are uint16_t
%       and THR1B's 42 counters are uint32_t. Neither changes a value
%       in any bundled file - the SNRs reach 690 of 32 767 and the
%       counters 89 329 647 of 2^31 - so this is hardening against a
%       large value in some other day, not a bug fix.
%     - **Units and flag meanings (release 1.3.0)** are not in any
%       classic header. They come from the same handbook, chapter 6,
%       one table per product: 6.2 ACC1B, 6.5 GNV1B, 6.7 KBR1B, 6.8
%       MAG1B, 6.9 MAS1B, 6.10 SCA1B, 6.11 THR1B, each with a Units
%       column and the qualflg bit list (MAS1B also prod_flag). The
%       spelling follows the GRACE-FO headers for the quantities they
%       share (the handbook's "s" is "seconds", "millisec" is
%       "milliseconds"), so a caller meets one vocabulary; the others
%       keep the handbook's (0.1 dB-Hz, microT, mA). MAG1B's time_frac
%       has no unit in 6.8 and is given microseconds, as its siblings
%       6.9 and 6.11 state for the same column. AHK1B has no chapter-6
%       table and gets no units beyond that: stated, not guessed.
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
%   Toolbox:  gracefoReading v1.2.0
%   Created:  2026-09-22
%   Updated:  2026-09-27
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    product (1,1) string
end

% The ASCII variant is NOT simply the binary columns as text. Two
% products deviate, both measured against the JPL read software's own
% Bin2AsciiLevel1 output on 2026-09-22 and neither inferable from the
% binary record. These two locals carry the deviations; empty means
% "ASCII prints exactly the binary order, numbers as numbers".
asciiSwapPair = {};      % two columns the ASCII writer emits swapped
asciiBits = {};          % columns ASCII renders as a bit string
units = cell(0, 2);      % {name, unit} from the product's handbook table
meanings = struct();     % flag column -> "bit N = text" lines

switch upper(product)
    case 'ACC1B'
        spec = { {'gps_time'}, 'int32'
                 {'GRACE_id'}, 'char'
                 {'lin_accl_x','lin_accl_y','lin_accl_z', ...
                  'ang_accl_x','ang_accl_y','ang_accl_z', ...
                  'acl_x_res','acl_y_res','acl_z_res'}, 'double'
                 {'qualflg'}, 'uint8' };
        oracle = 'accelerations within instrument range; residual columns ~1e-9';
        unitSource = 'D-22027 v1.3 section 6.2';
        units = {'gps_time','seconds'; 'lin_accl_x','m/s2'; 'lin_accl_y','m/s2'; ...
                 'lin_accl_z','m/s2'; 'ang_accl_x','rad/s2'; 'ang_accl_y','rad/s2'; ...
                 'ang_accl_z','rad/s2'; 'acl_x_res','m/s2'; 'acl_y_res','m/s2'; ...
                 'acl_z_res','m/s2'};
        meanings.qualflg = { ...
            'bit 0 = Proof mass voltage out of nominal range'
            'bit 1 = Not Defined'
            'bit 2 = if any linear ACC component has fit residual > 10 microns/s2'
            'bit 3 = extrapolated clock correction >5s but < 15s from fit center'
            'bit 4 = extrapolated clock correction < 5s from fit center'
            'bit 5 = filled data > 15s from fit center'
            'bit 6 = filled data > 5s but < 15s from fit center'
            'bit 7 = filled data < 5s from fit center'};

    case 'SCA1B'
        spec = { {'gps_time'}, 'int32'
                 {'GRACE_id'}, 'char'
                 {'sca_id'}, 'uint8'
                 {'quatangle','quaticoeff','quatjcoeff','quatkcoeff'}, 'double'
                 {'qual_rss'}, 'double'
                 {'qualflg'}, 'uint8' };
        oracle = 'quaternion norm within 1e-6 of unity in every record';
        unitSource = 'D-22027 v1.3 section 6.10';
        units = {'gps_time','seconds'};        % quaternion and qual_rss: N/A
        meanings.qualflg = { ...
            'bit 0 = filled data at T'
            'bit 1 = filled data at T + 1 sec'
            'bit 2 = filled data at T + 2 sec'
            'bit 3 = data from 1 star camera only'
            'bit 4 = extrapolated clock correction'
            'bit 5 = Not Defined'
            'bit 6 = low rate data from 2nd SCA'
            'bit 7 = low rate data from 1st SCA'};

    case 'GNV1B'
        spec = { {'gps_time'}, 'int32'
                 {'GRACE_id'}, 'char'
                 {'coord_ref'}, 'char'
                 {'xpos','ypos','zpos','xpos_err','ypos_err','zpos_err', ...
                  'xvel','yvel','zvel','xvel_err','yvel_err','zvel_err'}, 'double'
                 {'qualflg'}, 'uint8' };
        oracle = 'orbit radius 6827-6862 km and speed ~7.6 km/s';
        unitSource = 'D-22027 v1.3 section 6.5';
        units = [{'gps_time','seconds'}; ...
                 [{'xpos';'ypos';'zpos';'xpos_err';'ypos_err';'zpos_err'}, repmat({'m'}, 6, 1)]; ...
                 [{'xvel';'yvel';'zvel';'xvel_err';'yvel_err';'zvel_err'}, repmat({'m/s'}, 6, 1)]];
        meanings.qualflg = { ...
            'bit 0 = Not Defined'
            'bit 1 = Not Defined'
            'bit 2 = overlap data missing before start midnight'
            'bit 3 = overlap data missing after start midnight'
            'bit 4 = overlap data missing before end midnight'
            'bit 5 = overlap data missing after end midnight'
            'bit 6 = Not Defined'
            'bit 7 = Not Defined'};

    case 'KBR1B'
        % No satellite id: KBR1B is the A+B link, file token X.
        spec = { {'gps_time'}, 'int32'
                 {'biased_range','range_rate','range_accl','iono_corr', ...
                  'lighttime_corr','lighttime_rate','lighttime_accl', ...
                  'ant_centr_corr','ant_centr_rate','ant_centr_accl'}, 'double'
                 {'K_A_SNR','Ka_A_SNR','K_B_SNR','Ka_B_SNR'}, 'uint16'
                 {'qualflg'}, 'uint8' };
        oracle = 'd(biased_range)/dt matches range_rate to 5.8e-6 m/s; SNR 57-69 dB';
        unitSource = 'D-22027 v1.3 section 6.7';
        units = {'gps_time','seconds'; 'biased_range','m'; 'range_rate','m/s'; ...
                 'range_accl','m/s2'; 'iono_corr','m'; 'lighttime_corr','m'; ...
                 'lighttime_rate','m/s'; 'lighttime_accl','m/s2'; 'ant_centr_corr','m'; ...
                 'ant_centr_rate','m/s'; 'ant_centr_accl','m/s2'; 'K_A_SNR','0.1 dB-Hz'; ...
                 'Ka_A_SNR','0.1 dB-Hz'; 'K_B_SNR','0.1 dB-Hz'; 'Ka_B_SNR','0.1 dB-Hz'};
        meanings.qualflg = { ...
            'bit 0 = phase break'
            'bit 1 = extrapolated states for lighttime_corr'
            'bit 2 = model eci attitudes for ant_centr_corr'
            'bit 3 = extrapolated clock correction > 5s from fit center'
            'bit 4 = extrapolated clock correction < 5s from fit center'
            'bit 5 = data corrected for timetag bias of either K or Ka phase'
            'bit 6 = filled data > 5s from fit center'
            'bit 7 = filled data < 5s from fit center'};

    case 'THR1B'
        spec = { {'time_intg'}, 'int32'
                 {'time_frac'}, 'int32'
                 {'time_ref'}, 'char'
                 {'GRACE_id'}, 'char'
                 localThrusterNames(), 'uint32'
                 {'qualflg'}, 'uint8' };
        oracle = '42 counter columns; fractional time in microseconds';
        % thrust_count carries no unit (a count); on_time and accum_dur
        % are "millisec" in the handbook.
        unitSource = 'D-22027 v1.3 section 6.11';
        thr = localThrusterNames();
        ms = thr(startsWith(thr, {'on_time_', 'accum_dur_'}));
        units = [{'time_intg','seconds'; 'time_frac','microseconds'}; ...
                 [ms(:), repmat({'milliseconds'}, numel(ms), 1)]];
        meanings.qualflg = { ...
            'bit 0 = On time not calculated'
            'bit 1 = Multiple unaccounted thrusts prior to current record'
            'bit 2 = Not Defined'
            'bit 3 = Not Defined'
            'bit 4 = Not Defined'
            'bit 5 = Not Defined'
            'bit 6 = No OBDH->Receiver time mapping'
            'bit 7 = No Clock correction available'};

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
        unitSource = 'D-22027 v1.3 section 6.9';
        units = [{'time_intg','seconds'; 'time_frac','microseconds'}; ...
                 [{'mass_thr';'mass_thr_err';'mass_tnk';'mass_tnk_err'; ...
                   'gas_mass_thr1';'gas_mass_thr2';'gas_mass_tnk1';'gas_mass_tnk2'}, ...
                  repmat({'kg'}, 8, 1)]];
        meanings.qualflg = {'bits 0-7 = Not Defined'};
        meanings.prod_flag = { ...
            'bit 0 = SC Mass from thruster usage'
            'bit 1 = SC Mass error bit 0'
            'bit 2 = SC Mass from tank observations'
            'bit 3 = SC Mass error bit 2'
            'bit 4 = gas mass tank 1 (thr. usage)'
            'bit 5 = gas mass tank 2 (thr. usage)'
            'bit 6 = gas mass tank 1 (tank obs)'
            'bit 7 = gas mass tank 2 (tank obs)'};

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
        % time_frac has no unit in 6.8; it is the microseconds part, as
        % in every sibling table (6.9, 6.11) - the column's own long
        % name says so. The calibration factors carry none.
        unitSource = 'D-22027 v1.3 section 6.8';
        units = {'time_intg','seconds'; 'time_frac','microseconds'; ...
                 'MfvX_RAW','microT'; 'MfvY_RAW','microT'; 'MfvZ_RAW','microT'; ...
                 'torque1A','mA'; 'torque2A','mA'; 'torque3A','mA'; ...
                 'torque1B','mA'; 'torque2B','mA'; 'torque3B','mA'};
        meanings.qualflg = { ...
            'bit 0 = 0 > GPS Receiver Time; 1 > Space Craft Elapsed Time'
            'bit 1 = 0 > Pulse Sync; 1 > no Pulse Sync'
            'bits 2-7 = Not Defined'};
        % WrAsciiMAG1XFRecord.c prints GRACE_id BEFORE time_ref - the
        % opposite of the binary record, and of every other product.
        % Its own THR1B sibling holds the two in the same variables
        % and passes them the other way round, so this is a quirk of
        % the writer rather than a convention.
        asciiSwapPair = {'time_ref', 'GRACE_id'};

    case 'AHK1B'
        % The accelerometer housekeeping product, from the JPL GRACE
        % Level-1 read software (GraceReadSW_L1, release 2010-03-31),
        % which types AHK1X_t as ACC1A_t and reads it with
        % ReadACC1AFRecord.c. Two things here are unlike every other
        % variable-length classic product and are why this one could
        % not be inferred: prod_flag is FOUR bytes, so there are 32
        % conditional columns and not 8, and they do NOT share a type
        % - seven doubles, eighteen floats, then int8/uint16/int8/
        % int32. Bits 29-31 are undefined; a file that sets one is an
        % error rather than a guess, because their width is unknown.
        spec = { {'rcvtime_intg'}, 'int32'
                 {'rcvtime_frac'}, 'int32'
                 {'time_ref'}, 'char'
                 {'GRACE_id'}, 'char'
                 {'qualflg'}, 'uint8'
                 {'prod_flag'}, 'uint32'
                 {'lin_accl_x','lin_accl_y','lin_accl_z', ...
                  'ang_accl_x','ang_accl_y','ang_accl_z', ...
                  'bias_vol'}, 'double'
                 {'vd','x1_out','x2_out','x3_out','y1_out','y2_out', ...
                  'z1_out','tesu','taicu','tisu','v15picu','v15micu', ...
                  'vr5picu','tcicu','v15psu','v15msu','v48psu', ...
                  'v48msu'}, 'single'
                 {'status'}, 'uint8'
                 {'icu_blk_nr'}, 'uint16'
                 {'Tenhz_count'}, 'uint8'
                 {'Mhz_count'}, 'int32' };
        oracle = 'ICU/SU rails +-15 V, +5 V and +-48 V at nominal; record walk exact';
        % D-22027 has no AHK1B table and the read software states no
        % units: only the split time tag's microseconds are known.
        unitSource = 'none (not in D-22027 chapter 6)';
        units = {'rcvtime_frac','microseconds'};
        % WrAsciiACC1AFRecord.c case 25 writes `status` as an
        % 8-character bit string, not a number. Parsed as a number it
        % would read 10111111 instead of 191 - silently, which is why
        % the layout has to say so.
        asciiBits = {'status'};

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
layout.prodFlagBits = 0;
if layout.prodFlagIdx > 0
    layout.conditional(layout.prodFlagIdx+1:end) = true;
    % How many conditional columns the flag can address is a property
    % of the flag's own width, not a constant: MAS1B's prod_flag is
    % one byte and AHK1B's is four.
    layout.prodFlagBits = 8 * localWidth(types{layout.prodFlagIdx});
end
layout.oracle = oracle;

% Units and flag meanings, which classic headers do not carry. One unit
% per column in record order, '' where the handbook gives none; the
% spelling follows the GRACE-FO headers where they declare the same
% quantity (seconds, microseconds, milliseconds, m/s2, rad/s2, m, m/s,
% kg), so one vocabulary reaches the caller.
layout.units = repmat({''}, 1, numel(names));
for k = 1:size(units, 1)
    j = find(strcmp(names, units{k, 1}), 1);
    if isempty(j)
        error('gracefoReading:readL1b:badClassicType', ...
            'classicLayout: unit for unknown column "%s".', units{k, 1});
    end
    layout.units{j} = units{k, 2};
end
layout.flagMeanings = meanings;
layout.unitSource = unitSource;

% ASCII column order and rendering. Callers of the ASCII path take
% BOTH from here; nothing infers them from the binary order any more.
layout.asciiNames = names;
if ~isempty(asciiSwapPair)
    i1 = find(strcmp(names, asciiSwapPair{1}), 1);
    i2 = find(strcmp(names, asciiSwapPair{2}), 1);
    layout.asciiNames([i1, i2]) = layout.asciiNames([i2, i1]);
end
layout.asciiBitString = asciiBits;

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
    case {'char', 'uint8'},          w = 1;
    case {'int16','uint16'},         w = 2;
    case {'int32','uint32','single'},w = 4;
    case 'double',                   w = 8;
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
