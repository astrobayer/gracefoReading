#!/usr/bin/env python3
"""Static gate: structural integrity of every MATLAB source file.

WHY THIS GATE EXISTS
  parseDataSection.m and parseClassicProduct.m carried a help block
  inserted between the two physical lines of their function
  declaration. MATLAB rejected both files with
  MATLAB:m_unbalanced_parens, every test that reached them errored, and
  the repository's CI had never once been green. The existing help
  audit could not see it, because the audit read the block with the
  same "declaration is one line" rule that the writer used to put it
  there. A gate that shares an assumption with the tool it audits
  proves nothing.

  This gate uses no such assumption. It runs in under a second, needs
  no MATLAB and therefore no licence, and fails on the pull request
  long before the self-hosted runner is reached.

CHECKS
  1 split declaration - a comment line inside a ... continuation.
      MATLAB cannot parse the file at all.
  2 duplicate help    - two leading-comment blocks, detected by two
      "Toolbox:" provenance stamps. Symptom of check 1 having been
      repaired by insertion rather than by replacement.
  3 empty help        - a function file with no help block.

USAGE
  python3 docsrc/sourceIntegrity.py [--root DIR]

EXIT STATUS
  0 - every file clean
  1 - at least one finding, one line per finding on stdout

Toolbox:  gracefoReading v2.3.0
Created:  2026-09-06
Author:   Developed by Matthias Weigelt with the help of Anthropic
          Claude Opus 5, 2026-09-06
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mfile import comment_inside_decl, help_span      # noqa: E402

SKIP_DIRS = {'.git', '.github', 'artifacts', 'html', 'doc'}
STAMP = '%   Toolbox:  gracefoReading'


def source_files(root):
    """Every .m file below `root`, excluding generated and VCS folders.

    INPUT
      root  - str, directory to walk.

    OUTPUT
      out   - list[str], [N], absolute paths, sorted for stable output.
    """
    out = []
    for base, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        out += [os.path.join(base, n) for n in names if n.endswith('.m')]
    return sorted(out)


def check(path):
    """Findings for one source file.

    INPUT
      path     - str, path to an .m file.

    OUTPUT
      findings - list[str], [K], human-readable, empty when clean.
    """
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    if not lines:
        return []
    out = []

    for i in comment_inside_decl(lines):
        out.append(f'line {i + 1}: comment inside a continued declaration '
                   f'- MATLAB cannot parse this file')

    nstamp = sum(1 for ln in lines if ln.startswith(STAMP))
    if nstamp > 1:
        out.append(f'{nstamp} provenance stamps - the file carries more '
                   f'than one help block')

    is_function = lines[0].lstrip().startswith(('function', 'classdef'))
    first, stop = help_span(lines)
    if is_function and stop == first:
        out.append('no help block')

    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--root', default=os.path.dirname(
        os.path.dirname(os.path.abspath(__file__))),
        help='repository root; derived from __file__ by default')
    args = ap.parse_args(argv)

    files = source_files(args.root)
    nbad = 0
    for path in files:
        rel = os.path.relpath(path, args.root)
        for finding in check(path):
            print(f'{rel}: {finding}')
            nbad += 1

    print(f'sourceIntegrity: {len(files)} files, {nbad} finding(s)')
    return 1 if nbad else 0


if __name__ == '__main__':
    sys.exit(main())
