#!/usr/bin/env python3
"""auditHelp.py - audit every MATLAB help block in the gracefoReading toolbox.

The toolbox documentation standard requires, for every .m file:

  1. an H1 line          "%NAME  One-line summary."
  2. section  SYNTAX     at least one call signature
  3. section  DESCRIPTION
  4. section  INPUT      every entry as
                           name - type, size
                                  description
                         name-value options additionally carry
                         "Options:" (where enumerable) and "Default:"
  5. section  OUTPUT     same entry format ("(none)" allowed)
  6. section  ACCURACY AND LIMITATIONS
  7. section  EXAMPLE(S)
  8. metadata block with the toolbox version, creation/update date and
     the authorship line
       "Developed by Matthias Weigelt with the help of Anthropic Claude ..."

Test files (tests/*.m) are classdef suites: they need H1, DESCRIPTION,
COVERAGE and the metadata block, but no INPUT/OUTPUT sections.

Usage:  python3 docsrc/auditHelp.py [--quiet]
Exit code 0 = clean, 1 = violations found.

Developed by Matthias Weigelt with the help of Anthropic Claude Opus 5,
2026-08-14.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC = json.load(open(os.path.join(ROOT, 'docsrc', 'functionSpecs.json')))
VERSION = SPEC['toolbox']['version']
AUTHOR_LINE = 'Developed by Matthias Weigelt with the help of Anthropic Claude'

FUNCTION_SECTIONS = ['SYNTAX', 'DESCRIPTION', 'INPUT', 'OUTPUT',
                     'ACCURACY AND LIMITATIONS', 'EXAMPLE']
TEST_SECTIONS = ['DESCRIPTION', 'COVERAGE']

# entry line:  "    name - type, size"  or  "    'Option' - type, size"
ENTRY_RE = re.compile(r"^%\s{4,6}('?[A-Za-z_][\w.']*'?)\s+-\s+(.+)$")
TYPE_SIZE_RE = re.compile(r".+,\s*(\[[^\]]+\]|(\d+|[A-Z])\s*x\s*(\d+|[A-Z])|"
                          r"scalar|variable|see below|none)")


def help_block(path):
    """Return (lines, start_index) of the leading help comment block."""
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    start = 0 if lines[0].startswith('%') else 1
    out = []
    for ln in lines[start:]:
        if ln.startswith('%'):
            out.append(ln)
        elif ln.strip() == '' and out:
            break
        else:
            break
    return out, start


def audit_file(path):
    rel = os.path.relpath(path, ROOT)
    problems = []
    block, _ = help_block(path)
    if not block:
        return [f'{rel}: no help block at all']
    text = '\n'.join(block)
    flat = re.sub(r'\s+', ' ', text.replace('%', ' '))

    is_test = os.path.basename(os.path.dirname(path)) == 'tests'
    is_contents = os.path.basename(path) == 'Contents.m'

    # 1. H1
    if not re.match(r'^%[A-Z][A-Z0-9_]*\s{2}\S', block[0]) and not is_contents:
        problems.append(f'{rel}: malformed H1 line: {block[0][:60]!r}')

    # 2.-7. sections
    wanted = TEST_SECTIONS if is_test else FUNCTION_SECTIONS
    if is_contents:
        wanted = []
    for sec in wanted:
        pat = re.compile(r'^%\s{3}' + sec.replace(' ', r'\s'), re.M)
        if sec == 'EXAMPLE':
            pat = re.compile(r'^%\s{3}EXAMPLES?\b', re.M)
        if not pat.search(text):
            problems.append(f'{rel}: missing section {sec}')

    # 4. entry formatting inside INPUT/OUTPUT
    if not is_test and not is_contents:
        for sec in ('INPUT', 'OUTPUT'):
            body = section_body(block, sec)
            if body is None:
                continue
            if any('(none)' in ln for ln in body):
                continue
            entries = [ln for ln in body if ENTRY_RE.match(ln)]
            if not entries:
                problems.append(f'{rel}: {sec} has no parsable "name - type, size" entry')
            for ln in entries:
                m = ENTRY_RE.match(ln)
                if not TYPE_SIZE_RE.match(m.group(2)):
                    problems.append(
                        f'{rel}: {sec} entry {m.group(1)} lacks "type, size": {m.group(2)[:50]!r}')
            # name-value options must state a default
            for ln in entries:
                m = ENTRY_RE.match(ln)
                if m.group(1).startswith("'"):
                    tail = entry_body(body, ln)
                    if 'Default:' not in tail:
                        problems.append(
                            f'{rel}: option {m.group(1)} does not state "Default:"')

    # 8. metadata
    if f'gracefoReading v{VERSION}' not in text:
        problems.append(f'{rel}: metadata does not carry current version v{VERSION}')
    if AUTHOR_LINE not in flat:
        problems.append(f'{rel}: missing authorship line')
    if not re.search(r'%\s+Created:\s+\d{4}-\d{2}-\d{2}', text):
        problems.append(f'{rel}: missing Created date')
    if not re.search(r'%\s+Updated:\s+\d{4}-\d{2}-\d{2}', text):
        problems.append(f'{rel}: missing Updated date')
    return problems


def section_body(block, name):
    """Lines of one help section, excluding the heading."""
    out, inside = [], False
    head = re.compile(r'^%\s{3}' + name + r'\b')
    other = re.compile(r'^%\s{3}[A-Z][A-Z /-]{2,}$')
    for ln in block:
        if head.match(ln):
            inside = True
            continue
        if inside:
            if other.match(ln) or re.match(r'^%\s{3}(See also|Toolbox:)', ln):
                break
            out.append(ln)
    return out if inside else None


def entry_body(body, entry_line):
    """Continuation lines belonging to one entry."""
    i = body.index(entry_line)
    out = [entry_line]
    for ln in body[i + 1:]:
        if ENTRY_RE.match(ln):
            break
        out.append(ln)
    return '\n'.join(out)


def main():
    quiet = '--quiet' in sys.argv
    files = []
    for sub in ('+gracefoReading', '+gracefoReading/+internal', 'tests',
                'examples', 'ci', '.'):
        d = os.path.join(ROOT, sub)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith('.m'):
                files.append(os.path.join(d, f))
    allprob = []
    for f in files:
        allprob += audit_file(f)
    if allprob:
        print(f'AUDIT: {len(allprob)} problem(s) in {len(files)} file(s)')
        for p in allprob:
            print('  -', p)
        return 1
    if not quiet:
        print(f'AUDIT: clean - {len(files)} help blocks conform to the standard')
    return 0


if __name__ == '__main__':
    sys.exit(main())
