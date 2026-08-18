"""Helper: replace the leading help block of a MATLAB file (docsrc tooling)."""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

META = """%
%   Toolbox:  gracefoReading v2.3.0
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14"""

def set_help(relpath, block, meta=True):
    path = os.path.join(ROOT, relpath)
    lines = open(path, encoding='utf-8').read().split('\n')
    start = 0 if lines[0].startswith('%') else 1
    end = start
    while end < len(lines) and lines[end].startswith('%'):
        end += 1
    body = block.rstrip('\n')
    if meta:
        body += '\n' + META
    new = lines[:start] + body.split('\n') + lines[end:]
    open(path, 'w', encoding='utf-8').write('\n'.join(new))
    return relpath
