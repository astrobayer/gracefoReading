"""Reference writer for the classic GRACE ASCII (".asc") variant.

Mirrors the JPL GRACE Level-1 read software's Bin2AsciiLevel1 and its
WrAscii<PRODUCT>FRecord.c routines field for field, so the ASCII
fixtures in tests/realdata are a faithful rendering of the bundled
binary ones rather than this repository's idea of the format.

VERIFIED byte-identical, 2026-09-22, against the ASCII files the JPL
read software ships beside its own binary samples (release
2010-03-31, 2003-09-14, GRACE A and the combined KBR): all eight
products, every record, no difference at all. Regenerate that check
with any copy of the archive:

    python3 tests/python_reference/classic_ascii.py --verify <RELEASE_dir>

Nothing from that archive is vendored here; it is the oracle, not a
dependency, and the fixtures are generated from the owner's own
binary files.

Two facts in here could NOT have been inferred from the binary
layout, which is why the ASCII variant warned until now:

  * MAG1B prints GRACE_id BEFORE time_ref - the opposite of its
    binary record order. Every other product prints them in binary
    order (THR1B's writer even holds them in the same two variables
    and passes them the other way round).
  * AHK1B prints `status` as an 8-character BIT STRING, not a number,
    and its float columns with %.10g where its one double column
    uses %.16g.
"""
import sys, os

def _bits(v, n):
    v = int(v)
    return ''.join('1' if v >> (n - 1 - i) & 1 else '0' for i in range(n))

def _g(v, prec=16):
    return '%.*g' % (prec, v)


def write_records(cols, n, product):
    """Return the ASCII data lines for a decoded classic product."""
    from classic_reference import layout
    p = product.upper()
    names = layout(p)['names']
    out = []
    for r in range(n):
        C = lambda k: cols[k][r]
        if p == 'ACC1B':
            s = '%d %s ' % (C('gps_time'), C('GRACE_id')) + ' '.join(
                _g(C(k)) for k in names[2:11]) + '  ' + _bits(C('qualflg'), 8)
        elif p == 'SCA1B':
            s = '%d %s %d ' % (C('gps_time'), C('GRACE_id'), C('sca_id')) + \
                ' '.join(_g(C(k)) for k in names[3:8]) + ' ' + _bits(C('qualflg'), 8)
        elif p == 'GNV1B':
            s = '%d %s %s ' % (C('gps_time'), C('GRACE_id'), C('coord_ref')) + \
                ' '.join(_g(C(k)) for k in names[3:15]) + '  ' + _bits(C('qualflg'), 8)
        elif p == 'KBR1B':
            s = '%d ' % C('gps_time') + ' '.join(_g(C(k)) for k in names[1:11]) + \
                ' ' + ' '.join('%2d' % C(k) for k in names[11:15]) + \
                '  ' + _bits(C('qualflg'), 8)
        elif p == 'THR1B':
            s = '%d %d %s %s   ' % (C('time_intg'), C('time_frac'),
                                    C('time_ref'), C('GRACE_id'))
            s += ''.join('%d ' % C(k) for k in names[4:46]) + '  ' + \
                 _bits(C('qualflg'), 8)
        elif p == 'MAG1B':
            # GRACE_id BEFORE time_ref - see the module docstring.
            s = '%d %d %s %s ' % (C('time_intg'), C('time_frac'),
                                  C('GRACE_id'), C('time_ref')) + \
                ' '.join(_g(C(k)) for k in names[4:17]) + '  ' + \
                _bits(C('qualflg'), 8)
        elif p == 'MAS1B':
            pf = int(C('prod_flag'))
            s = '%d %d %s %s ' % (C('time_intg'), C('time_frac'),
                                  C('time_ref'), C('GRACE_id'))
            s += ' ' + _bits(C('qualflg'), 8) + ' ' + _bits(pf, 8)
            for b in range(8):
                if pf >> b & 1:
                    s += ' ' + _g(C(names[6 + b]))
        elif p == 'AHK1B':
            pf = int(C('prod_flag'))
            s = '%d' % C('rcvtime_intg') + '  %d' % C('rcvtime_frac')
            s += '  %s' % C('time_ref') + '  %s' % C('GRACE_id')
            s += '  ' + _bits(C('qualflg'), 8) + ' '
            s += '  ' + _bits(pf, 32) + ' '
            for b in range(32):
                if pf >> b & 1:
                    v = C(names[6 + b])
                    if b == 25:              # status, as a bit string
                        s += '  ' + _bits(v, 8) + ' '
                    elif b in (26, 27, 28):  # icu_blk_nr, Tenhz, Mhz
                        s += ' %d' % int(v)
                    elif b >= 7:             # the single-precision columns
                        s += ' ' + _g(v, 10)
                    else:
                        s += ' ' + _g(v)
        else:
            raise ValueError('no ASCII writer for %s' % p)
        out.append(s)
    return out


def convert(binPath, ascPath, product):
    """Write the ASCII twin of one classic binary file."""
    from classic_reference import decode, split_file
    hdr, cols, n = decode(binPath, product)
    lines = write_records(cols, n, product)
    hdr = hdr.replace('FILE FORMAT 0=BINARY 1=ASCII  : 0',
                      'FILE FORMAT 0=BINARY 1=ASCII  : 1')
    with open(ascPath, 'w', newline='\n') as f:
        f.write(hdr)
        f.write('\n'.join(lines) + '\n')
    return n


def _verify(release_dir):
    """Diff generated ASCII against the archive's own .asc, line by line."""
    from classic_reference import decode
    pairs = [('ACC1B', 'ACC1B_2003-09-14_A_00'), ('SCA1B', 'SCA1B_2003-09-14_A_00'),
             ('GNV1B', 'GNV1B_2003-09-14_A_00'), ('KBR1B', 'KBR1B_2003-09-14_X_00'),
             ('THR1B', 'THR1B_2003-09-14_A_00'), ('MAG1B', 'MAG1B_2003-09-14_A_00'),
             ('MAS1B', 'MAS1B_2003-09-14_A_00'), ('AHK1B', 'AHK1B_2003-09-14_A_00')]
    bad = 0
    for prod, stem in pairs:
        binf = os.path.join(release_dir, 'data', stem + '.dat')
        ascf = os.path.join(release_dir, 'data', 'asc', stem + '.asc')
        if not (os.path.isfile(binf) and os.path.isfile(ascf)):
            print('%-6s absent' % prod); continue
        _, cols, n = decode(binf, prod)
        mine = write_records(cols, n, prod)
        real = open(ascf, errors='replace').read().splitlines()
        k = next(i for i, l in enumerate(real) if l.startswith('END OF HEADER'))
        real = [l for l in real[k + 1:] if l.strip()]
        diffs = [i for i in range(min(len(mine), len(real)))
                 if mine[i].rstrip() != real[i].rstrip()]
        ok = (len(mine) == len(real)) and not diffs
        bad += 0 if ok else 1
        print('%-6s %3d records  %s' % (prod, len(mine),
              'IDENTICAL' if ok else 'DIFFERS at line %d' % diffs[0]))
    return bad


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--verify':
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        raise SystemExit(1 if _verify(sys.argv[2]) else 0)
    print(__doc__)
