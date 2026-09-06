#!/usr/bin/env python3
"""helpparse.py - parse MATLAB help blocks of the gracefoReading toolbox.

The toolbox documentation standard (see docsrc/auditHelp.py) gives every
help block a fixed structure. This module turns such a block into a
dictionary, so that the HTML reference pages and the PDF guide are
generated FROM THE HELP TEXT ITSELF. Consequence: `help
gracefoReading.readL1b` in MATLAB and the generated documentation can
never disagree, because there is only one source.

Parsed structure:
    {'name', 'purpose', 'syntax': [...], 'description': [para, ...],
     'inputs':  [{'name','type','size','desc','options','default'}, ...],
     'outputs': [{...same...}],
     'limitations': [str, ...],
     'errors':  [{'id','cond'}, ...],
     'warnings':[{'id','cond'}, ...],
     'examples':[{'caption','code'}, ...],
     'seealso': [str, ...]}

Developed by Matthias Weigelt with the help of Anthropic Claude Opus 5,
2026-08-14.
"""
import os
import re

import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from mfile import help_span

SECTION_RE = re.compile(r'^%\s{3}([A-Z][A-Z /-]{2,})\s*$')
ENTRY_RE = re.compile(r"^%\s{4,6}('?[A-Za-z_][\w.']*'?)\s+-\s+(.+)$")
ERRID_RE = re.compile(r'^%\s+(gracefoReading:[A-Za-z0-9_:]+)\s*(.*)$')


def read_block(path):
    """Leading help comment block of a MATLAB file, as list of lines."""
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    first, stop = help_span(lines)          # docsrc/mfile.py: single source
    return lines[first:stop]


def strip(ln):
    return re.sub(r'^%\s?', '', ln).rstrip()


def split_sections(block):
    """Split into {'H1':..., 'SECTIONNAME': [lines]}."""
    out = {'H1': ''}
    if block:
        m = re.match(r'^%([A-Z][A-Z0-9_]*)\s{2}(.*)$', block[0])
        out['H1'] = m.group(2).strip() if m else strip(block[0])
    current = None
    for ln in block[1:]:
        m = SECTION_RE.match(ln)
        if m:
            current = m.group(1).strip()
            out[current] = []
            continue
        m2 = re.match(r'^%\s{3}(See also)\s*(.*)$', ln)
        if m2:
            current = 'SEEALSO'
            out[current] = [m2.group(2)]
            continue
        if re.match(r'^%\s{3}(Toolbox|Created|Updated|Author):', ln):
            current = 'META'
            out.setdefault(current, [])
        if current:
            out[current].append(strip(ln))
    return out


def paragraphs(lines):
    """Group indented text lines into paragraphs."""
    paras, buf = [], []
    for ln in lines:
        if not ln.strip():
            if buf:
                paras.append(' '.join(buf))
                buf = []
        else:
            buf.append(ln.strip())
    if buf:
        paras.append(' '.join(buf))
    return paras


def split_type_size(spec):
    """'string | char, 1x1' -> ('string | char', '1x1')."""
    types, sizes = [], []
    for part in spec.split(' | '):
        if ',' in part:
            t, s = part.rsplit(',', 1)
            types.append(t.strip())
            sizes.append(s.strip())
        else:
            types.append(part.strip())
    seen, usizes = set(), []
    for s in sizes:
        if s not in seen:
            seen.add(s)
            usizes.append(s)
    return ' | '.join(types), ' | '.join(usizes)


def parse_args(lines):
    """Parse an INPUT/OUTPUT section into argument dictionaries."""
    if not lines:
        return []
    if any('(none)' in ln for ln in lines):
        return []
    field_re = re.compile(
        r'^\s{6,}([A-Za-z_]\w*)\s+'
        r'(double|char|logical|string|struct|cellstr|table|datetime|int64|cell)'
        r'\b\s*(\[[^\]]*\]|\d+x[\dA-Za-z]+)?\s*,?\s*(.*)$')
    args, cur = [], None
    for ln in lines:
        fm = field_re.match(ln)
        if fm and cur is not None:
            cur.setdefault('fields', []).append(
                {'name': fm.group(1), 'type': fm.group(2),
                 'size': (fm.group(3) or '').strip(),
                 'desc': fm.group(4).strip()})
            continue
        if cur is not None and cur.get('fields') and ln.strip() \
                and not ENTRY_RE.match('%' + ln):
            cur['fields'][-1]['desc'] += ' ' + ln.strip()
            continue
        m = ENTRY_RE.match('%' + ln if not ln.startswith('%') else ln)
        if m is None:
            m = ENTRY_RE.match('%     ' + ln.strip()) if re.match(
                r"^\s{4,6}'?[A-Za-z_][\w.']*'?\s+-\s+", ln) else None
        if m:
            typ, size = split_type_size(m.group(2).strip())
            cur = {'name': m.group(1), 'type': typ, 'size': size,
                   'desc': [], 'options': '', 'default': ''}
            args.append(cur)
        elif cur is not None and ln.strip():
            cur['desc'].append(ln.strip())
    for a in args:
        text = ' '.join(a['desc'])
        mo = re.search(r'Options:\s*(.*?)(?=\s*Default:|$)', text)
        md = re.search(r'Default:\s*(.*?)$', text)
        if mo:
            a['options'] = mo.group(1).strip().rstrip('.')
        if md:
            a['default'] = md.group(1).strip().rstrip('.')
        text = re.sub(r'\s*Options:.*?(?=Default:|$)', ' ', text)
        text = re.sub(r'\s*Default:.*$', '', text)
        text = re.sub(r'\s*(Required, positional|Optional, positional)\.?', '', text)
        mv = re.search(r'Validation:\s*([^.]+)\.', text)
        if mv:
            a['validation'] = mv.group(1).strip()
            text = re.sub(r'\s*Validation:[^.]+\.', '', text)
        a['desc'] = re.sub(r'\s+', ' ', text).strip()
    return args


def parse_bullets(lines):
    """Parse '- item' bullet lists with continuation lines."""
    items, cur = [], None
    for ln in lines:
        s = ln.strip()
        if s.startswith('- '):
            if cur:
                items.append(' '.join(cur))
            cur = [s[2:]]
        elif cur is not None and s:
            cur.append(s)
    if cur:
        items.append(' '.join(cur))
    return items


def parse_errors(lines):
    """Parse identifier/condition pairs from ERRORS or WARNINGS."""
    out, cur = [], None
    for ln in lines:
        m = ERRID_RE.match('%' + ln if not ln.startswith('%') else ln)
        if m is None and re.match(r'^\s*gracefoReading:', ln):
            parts = ln.strip().split(None, 1)
            m = None
            cur = {'id': parts[0], 'cond': parts[1] if len(parts) > 1 else ''}
            out.append(cur)
            continue
        if m:
            cur = {'id': m.group(1), 'cond': m.group(2).strip()}
            out.append(cur)
        elif cur is not None and ln.strip() and not ln.strip().startswith('('):
            cur['cond'] = (cur['cond'] + ' ' + ln.strip()).strip()
    return out


def parse_examples(lines):
    """Split an EXAMPLES section into caption/code blocks."""
    blocks, cur = [], None
    for ln in lines:
        s = ln[5:] if ln.startswith('     ') else ln.strip()
        if not s.strip():
            continue
        m = re.match(r'^%\s*\d+\.\s*(.*)$', s.strip())
        if m:
            cur = {'caption': m.group(1).strip(), 'code': []}
            blocks.append(cur)
            continue
        if cur is None:
            cur = {'caption': '', 'code': []}
            blocks.append(cur)
        cur['code'].append(s.rstrip())
    for b in blocks:
        while b['code'] and not b['code'][-1].strip():
            b['code'].pop()
        b['code'] = '\n'.join(b['code'])
    return [b for b in blocks if b['code']]


def parse_file(path):
    """Parse one .m file into the documentation dictionary."""
    block = read_block(path)
    sec = split_sections(block)
    name = os.path.splitext(os.path.basename(path))[0]
    doc = {
        'name': name,
        'purpose': sec.get('H1', ''),
        'syntax': [ln.strip() for ln in sec.get('SYNTAX', []) if ln.strip()],
        'description': paragraphs(sec.get('DESCRIPTION', [])),
        'inputs': parse_args(sec.get('INPUT', [])),
        'outputs': parse_args(sec.get('OUTPUT', [])),
        'limitations': parse_bullets(sec.get('ACCURACY AND LIMITATIONS', [])),
        'errors': parse_errors(sec.get('ERRORS', [])),
        'warnings': parse_errors(sec.get('WARNINGS', [])),
        'examples': parse_examples(sec.get('EXAMPLES', sec.get('EXAMPLE', []))),
        'seealso': [],
    }
    if 'SEEALSO' in sec:
        txt = ' '.join(sec['SEEALSO'])
        doc['seealso'] = [s.strip() for s in re.split(r',\s*', txt) if s.strip()]
    if not doc['outputs'] and any('(none)' in ln for ln in sec.get('OUTPUT', [])):
        doc['outputsNone'] = True
    if not doc['inputs'] and any('(none)' in ln for ln in sec.get('INPUT', [])):
        doc['inputsNone'] = True
    return doc


if __name__ == '__main__':
    import json
    import sys
    print(json.dumps(parse_file(sys.argv[1]), indent=2))
