"""Helper: replace the leading help block of a MATLAB file (docsrc tooling)."""
import os

import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from mfile import help_span
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

META = """%
%   Toolbox:  gracefoReading v1.0.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Matthias Weigelt with support of Anthropic Claude
%             Claude Opus 5, 2026-08-14"""

def set_help(relpath, block, meta=True):
    path = os.path.join(ROOT, relpath)
    lines = open(path, encoding='utf-8').read().split('\n')
    start, end = help_span(lines)           # docsrc/mfile.py: single source
    body = block.rstrip('\n')
    if meta:
        body += '\n' + META
    new = lines[:start] + body.split('\n') + lines[end:]
    open(path, 'w', encoding='utf-8').write('\n'.join(new))
    return relpath
