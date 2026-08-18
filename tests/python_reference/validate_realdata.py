#!/usr/bin/env python3
"""
validate_realdata.py — Python reference implementation of the
gracefoReading parsing rules, run against real GRACE-FO L1B files.

Serves two purposes:
  1. Development-time validation of the parsing rules on real PO.DAAC
     files before/alongside the MATLAB implementation.
  2. A language-independent reference: the MATLAB toolbox and this
     script must agree on record counts, time conversion, column
     classification, and prod_flag expansion.

Usage: python3 validate_realdata.py <folder-with-L1B-files>
"""
import os
import re
import sys
import math

MJD_EPOCH = 51544  # 2000-01-01 00:00:00
HALF_DAY = 43200.0

FRAC_UNIT_SCALE = {
    "microseconds": 1e-6, "microsecond": 1e-6,
    "milliseconds": 1e-3, "millisecond": 1e-3,
    "seconds": 1.0, "second": 1.0,
}


def parse_header(lines):
    """Parse the YAML header. Returns (varnames, attrs, num_records, n_header_lines).
    attrs: dict varname -> dict of scalar attributes + 'flag_meanings' list."""
    varnames, attrs = [], {}
    num_records = None
    in_vars = False
    current = None
    n_hdr = None
    list_attr = None
    for i, ln in enumerate(lines):
        if "End of YAML header" in ln:
            n_hdr = i + 1
            break
        m = re.match(r"\s*num_records:\s*(\d+)", ln)
        if m:
            num_records = int(m.group(1))
        if re.match(r"^  variables:\s*$", ln) or re.match(r"^  variable_descriptions:\s*$", ln):
            in_vars = True
            continue
        if in_vars:
            # new variable: "    - varname:"  (real)  or "    - name: varname" (legacy)
            m = re.match(r"^\s{2,6}-\s+name:\s*(\S+)\s*$", ln)
            if m:
                current = m.group(1).strip("'\"")
                varnames.append(current)
                attrs[current] = {}
                list_attr = None
                continue
            m = re.match(r"^\s{2,6}-\s+([A-Za-z_]\w*):\s*$", ln)
            if m:
                current = m.group(1)
                varnames.append(current)
                attrs[current] = {}
                list_attr = None
                continue
            # attribute list items (flag_meanings / value_meanings entries)
            m = re.match(r"^\s{8,}-\s+(.*\S)\s*$", ln)
            if m and current and list_attr:
                attrs[current].setdefault(list_attr, []).append(m.group(1).strip("'\""))
                continue
            # scalar attribute or start of a list attribute
            m = re.match(r"^\s{6,}([A-Za-z_]\w*):\s*(.*)$", ln)
            if m and current:
                key, val = m.group(1), m.group(2).strip().strip("'\"")
                if val == "":
                    list_attr = key
                else:
                    attrs[current][key] = val
                    list_attr = None
                continue
            # anything at 2-space indent ends the variables block
            if re.match(r"^  \S", ln):
                in_vars = False
    return varnames, attrs, num_records, n_hdr


def is_bitstring_var(name):
    return bool(re.search(r"flag|qualflg", name, re.I))


def classify(varnames, attrs):
    """Return (time_vars, char_vars, bit_vars)."""
    char_vars = {v for v in varnames if attrs[v].get("units", "") == "char"}
    bit_vars = {v for v in varnames if is_bitstring_var(v)}
    if "gps_time" in varnames:
        time_vars = ["gps_time"]
    elif "time_intg" in varnames and "time_frac" in varnames:
        time_vars = ["time_intg", "time_frac"]
    else:
        raise ValueError("no time variable found")
    return time_vars, char_vars, bit_vars


def frac_scale(attrs, name):
    unit = attrs.get(name, {}).get("units", "seconds").lower()
    if unit not in FRAC_UNIT_SCALE:
        raise ValueError(f"unknown fractional-time unit: {unit}")
    return FRAC_UNIT_SCALE[unit]


def gps_to_mjd(gps_seconds):
    total = gps_seconds + HALF_DAY
    days = math.floor(total / 86400.0)
    sec = total - days * 86400.0
    return MJD_EPOCH + days, sec


def process_file(path):
    with open(path) as f:
        lines = f.read().splitlines()
    varnames, attrs, num_records, n_hdr = parse_header(lines)
    time_vars, char_vars, bit_vars = classify(varnames, attrs)

    # prod_flag handling
    has_prod = "prod_flag" in varnames
    if has_prod:
        pf_idx = varnames.index("prod_flag")
        fixed_vars = varnames[: pf_idx + 1]
        cond_vars = varnames[pf_idx + 1:]
    else:
        fixed_vars = varnames
        cond_vars = []

    n_rec = 0
    first_t = last_t = None
    obs_cols = [v for v in varnames
                if v not in time_vars and v not in char_vars
                and v not in bit_vars and not v.endswith("_id")]
    bad = 0
    present_counts = {v: 0 for v in cond_vars}
    for ln_no, ln in enumerate(lines[n_hdr:], start=n_hdr + 1):
        toks = ln.split()
        if not toks:
            continue
        if has_prod:
            pf = toks[len(fixed_vars) - 1]
            n_set = pf.count("1")
            expected = len(fixed_vars) + n_set
            set_bits = [len(pf) - 1 - i for i, c in enumerate(pf) if c == "1"]
            for b in sorted(set_bits):
                if b < len(cond_vars):
                    present_counts[cond_vars[b]] += 1
        else:
            expected = len(varnames)
        if len(toks) != expected:
            bad += 1
            print(f"    LINE {ln_no}: {len(toks)} tokens, expected {expected}")
            continue
        n_rec += 1
        if "gps_time" in time_vars:
            gps = float(toks[varnames.index("gps_time")])
        else:
            gps = (float(toks[varnames.index("time_intg")])
                   + float(toks[varnames.index("time_frac")])
                   * frac_scale(attrs, "time_frac"))
        mjd, sec = gps_to_mjd(gps)
        if first_t is None:
            first_t = (mjd, sec)
        last_t = (mjd, sec)

    name = os.path.basename(path)
    print(f"\n=== {name} ===")
    print(f"  variables declared : {len(varnames)}  ({', '.join(varnames[:6])}...)")
    print(f"  num_records header : {num_records}")
    print(f"  records parsed     : {n_rec}   (bad lines: {bad})")
    print(f"  header/actual match: {num_records == n_rec}")
    print(f"  time vars          : {'+'.join(time_vars)}"
          + (f" (frac scale {frac_scale(attrs,'time_frac')})" if len(time_vars) == 2 else ""))
    print(f"  first epoch        : MJD {first_t[0]}, sec {first_t[1]:.6f}")
    print(f"  last  epoch        : MJD {last_t[0]}, sec {last_t[1]:.6f}")
    print(f"  obs columns ({len(obs_cols)})    : {', '.join(obs_cols)}")
    aux_cols = [v for v in varnames if v not in obs_cols and v not in time_vars]
    print(f"  aux columns ({len(aux_cols)})    : {', '.join(aux_cols)}")
    if has_prod:
        print(f"  prod_flag conditional presence: "
              + ", ".join(f"{v}={c}" for v, c in present_counts.items()))
    return num_records == n_rec and bad == 0


def main(folder):
    ok = True
    for f in sorted(os.listdir(folder)):
        if re.match(r"^[A-Z]{3}1B_.*\.txt$", f):
            ok &= process_file(os.path.join(folder, f))
    print("\nALL FILES CONSISTENT" if ok else "\nINCONSISTENCIES FOUND")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
