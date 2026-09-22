"""Independent reference decoder for classic GRACE binary L1B products.

Mirrors +gracefoReading/+internal/classicLayout.m and parseClassicBinary.m
field for field, so the MATLAB expectations in tests/testRealData.m are
derived here and not from the code they test.
"""
import struct, re

W = {'char':1, 'uint8':1, 'int16':2, 'uint16':2, 'int32':4, 'uint32':4,
     'single':4, 'double':8}
FMT = {'int16':'h', 'uint16':'H', 'int32':'i', 'uint32':'I',
       'single':'f', 'double':'d'}

def _thruster_names():
    att=[f'thrust_count_att_ctrl_{b}_{t}' for b in (1,2) for t in range(1,7)]
    on=[f'on_time_att_ctrl_{b}_{t}' for b in (1,2) for t in range(1,7)]
    accum=['accum_dur_att_ctrl']+[f'accum_dur_undef_{k}' for k in range(1,12)]
    return (att+['thrust_count_undef_1','thrust_count_undef_2']+
            on+['on_time_orb_ctrl_1','on_time_orb_ctrl_2']+
            accum+['accum_dur_orb_ctrl','accum_dur_undef_12'])

def layout(product):
    p = product.upper()
    if p=='ACC1B':
        spec=[(['gps_time'],'int32'),(['GRACE_id'],'char'),
              (['lin_accl_x','lin_accl_y','lin_accl_z','ang_accl_x','ang_accl_y',
                'ang_accl_z','acl_x_res','acl_y_res','acl_z_res'],'double'),
              (['qualflg'],'uint8')]
    elif p=='SCA1B':
        spec=[(['gps_time'],'int32'),(['GRACE_id'],'char'),(['sca_id'],'uint8'),
              (['quatangle','quaticoeff','quatjcoeff','quatkcoeff'],'double'),
              (['qual_rss'],'double'),(['qualflg'],'uint8')]
    elif p=='GNV1B':
        spec=[(['gps_time'],'int32'),(['GRACE_id'],'char'),(['coord_ref'],'char'),
              (['xpos','ypos','zpos','xpos_err','ypos_err','zpos_err',
                'xvel','yvel','zvel','xvel_err','yvel_err','zvel_err'],'double'),
              (['qualflg'],'uint8')]
    elif p=='KBR1B':
        spec=[(['gps_time'],'int32'),
              (['biased_range','range_rate','range_accl','iono_corr',
                'lighttime_corr','lighttime_rate','lighttime_accl',
                'ant_centr_corr','ant_centr_rate','ant_centr_accl'],'double'),
              (['K_A_SNR','Ka_A_SNR','K_B_SNR','Ka_B_SNR'],'uint16'),
              (['qualflg'],'uint8')]
    elif p=='THR1B':
        spec=[(['time_intg'],'int32'),(['time_frac'],'int32'),(['time_ref'],'char'),
              (['GRACE_id'],'char'),(_thruster_names(),'uint32'),(['qualflg'],'uint8')]
    elif p=='MAS1B':
        spec=[(['time_intg'],'int32'),(['time_frac'],'int32'),(['time_ref'],'char'),
              (['GRACE_id'],'char'),(['qualflg'],'uint8'),(['prod_flag'],'uint8'),
              (['mass_thr','mass_thr_err','mass_tnk','mass_tnk_err',
                'gas_mass_thr1','gas_mass_thr2','gas_mass_tnk1','gas_mass_tnk2'],'double')]
    elif p=='AHK1B':
        spec=[(['rcvtime_intg'],'int32'),(['rcvtime_frac'],'int32'),
              (['time_ref'],'char'),(['GRACE_id'],'char'),
              (['qualflg'],'uint8'),(['prod_flag'],'uint32'),
              (['lin_accl_x','lin_accl_y','lin_accl_z','ang_accl_x','ang_accl_y',
                'ang_accl_z','bias_vol'],'double'),
              (['vd','x1_out','x2_out','x3_out','y1_out','y2_out','z1_out',
                'tesu','taicu','tisu','v15picu','v15micu','vr5picu','tcicu',
                'v15psu','v15msu','v48psu','v48msu'],'single'),
              (['status'],'uint8'),(['icu_blk_nr'],'uint16'),
              (['Tenhz_count'],'uint8'),(['Mhz_count'],'int32')]
    elif p=='MAG1B':
        spec=[(['time_intg'],'int32'),(['time_frac'],'int32'),(['time_ref'],'char'),
              (['GRACE_id'],'char'),
              (['MfvX_RAW','MfvY_RAW','MfvZ_RAW'],'single'),
              (['torque1A','torque2A','torque3A',
                'torque1B','torque2B','torque3B'],'single'),
              (['MF_BCalX','MF_BCalY','MF_BCalZ'],'single'),
              (['torque_cal'],'single'),(['qualflg'],'uint8')]
    else:
        return None
    names=[]; types=[]
    for g,t in spec:
        names+=g; types+=[t]*len(g)
    pf = names.index('prod_flag')+1 if 'prod_flag' in names else 0
    recbytes = 0 if pf else sum(W[t] for t in types)
    nbits = 8*W[types[pf-1]] if pf else 0
    return dict(names=names, types=types, prodFlagIdx=pf,
                recordBytes=recbytes, prodFlagBits=nbits)

def split_file(path):
    raw=open(path,'rb').read()
    i=raw.find(b'END OF HEADER'); j=raw.index(b'\n', i)
    hdr=raw[:j+1].decode('ascii','replace')
    return hdr, raw[j+1:], j+1

def decode(path, product):
    hdr, data, _ = split_file(path)
    L = layout(product)
    n = int(re.search(r'NUMBER OF DATA RECORDS\s*:\s*(\d+)', hdr).group(1))
    out = {k: [] for k in L['names']}
    if L['recordBytes']:
        R=L['recordBytes']
        assert len(data)==R*n, (len(data), R*n)
        for r in range(n):
            rec=data[r*R:(r+1)*R]; o=0
            for name,t in zip(L['names'], L['types']):
                w=W[t]
                b=rec[o:o+w]
                if t=='char': v=chr(b[0])
                elif t=='uint8': v=b[0]
                else: v=struct.unpack('>'+FMT[t], b)[0]
                out[name].append(v); o+=w
    else:
        pf=L['prodFlagIdx']; o=0
        for r in range(n):
            for k in range(pf):
                name=L['names'][k]; t=L['types'][k]; w=W[t]
                b=data[o:o+w]
                v = chr(b[0]) if t=='char' else (b[0] if t=='uint8'
                      else struct.unpack('>'+FMT[t], b)[0])
                out[name].append(v); o+=w
            flag=out['prod_flag'][-1]
            cond=L['names'][pf:]
            vals={}
            for bit in range(L['prodFlagBits']):
                if flag>>bit & 1:
                    assert bit < len(cond), f'undefined prod_flag bit {bit}'
                    ct=L['types'][pf+bit]; w=W[ct]
                    v = data[o] if ct=='uint8' else \
                        struct.unpack('>'+FMT[ct], data[o:o+w])[0]
                    vals[cond[bit]]=v; o+=w
            for c in cond:
                out[c].append(vals.get(c, float('nan')))
        assert o==len(data), (o, len(data))
    return hdr, out, n


if __name__ == '__main__':
    # Regenerate the golden numbers hard-coded in tests/testClassicProducts.m.
    #   python3 tests/python_reference/classic_reference.py tests/realdata
    import sys, math, os
    root = sys.argv[1] if len(sys.argv) > 1 else 'tests/realdata'
    for name, prod in [('ACC1B_2008-01-01_A_02.dat', 'ACC1B'),
                       ('SCA1B_2008-01-01_A_02.dat', 'SCA1B'),
                       ('GNV1B_2008-01-01_A_02.dat', 'GNV1B'),
                       ('KBR1B_2008-01-01_X_02.dat', 'KBR1B'),
                       ('THR1B_2008-01-01_A_02.dat', 'THR1B'),
                       ('MAS1B_2008-01-01_A_02.dat', 'MAS1B'),
                       ('MAG1B_2008-01-01_A_02.dat', 'MAG1B'),
                       ('AHK1B_2008-01-01_A_02.dat', 'AHK1B')]:
        path = os.path.join(root, name)
        if not os.path.isfile(path):
            print(f'{prod}: absent'); continue
        hdr, cols, n = decode(path, prod)
        if 'gps_time' in cols:
            t0 = cols['gps_time'][0] + 43200.0
        elif 'time_intg' in cols:
            t0 = cols['time_intg'][0] + cols['time_frac'][0] * 1e-6 + 43200.0
        else:
            t0 = cols['rcvtime_intg'][0] + cols['rcvtime_frac'][0]*1e-6 + 43200.0
        d = math.floor(t0 / 86400)
        print(f'{prod}: {n} records, first epoch MJD {51544 + d} '
              f'{t0 - d * 86400:.6f} s')
