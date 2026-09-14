"""Structural boundaries of a MATLAB source file.

SINGLE POINT OF ACCESS. Every tool that reads or writes the leading help
block of an .m file must obtain the block boundaries here and nowhere
else. Four independent copies of the rule "the declaration is line 1"
existed before this module (docsrc/_sethelp.py, docsrc/auditHelp.py,
docsrc/helpparse.py, tests/testDocConsistency.m). All four were wrong in
the same way, and because the writer and the auditor shared the error,
the auditor certified files that MATLAB could not parse at all.

A MATLAB declaration may span several physical lines through ...
continuations::

    function [a, b] = f(x, y, ...
        z, w)
    %F  Help text starts here, not on the line after "function".

Inserting the help block after the first physical line splits the
declaration and produces MATLAB:m_unbalanced_parens; the file then does
not exist for the interpreter.

FUNCTIONS
  declaration_end(lines)   - index of the last physical declaration line
  help_span(lines)         - (first, stop) half-open range of the help block
  comment_inside_decl(lines) - indices of comment lines that split a declaration

INPUT (all functions)
  lines - list[str], [N], the file split on '\\n', newlines removed.

Toolbox:  gracefoReading v1.0.0
Created:  2026-09-06
Author:   Matthias Weigelt with support of Anthropic Claude
          Claude Opus 5, 2026-09-06
"""

import re

__all__ = ['continues', 'declaration_end', 'help_span', 'comment_inside_decl']

_CONT = re.compile(r'\.\.\.')


def continues(line):
    """True if `line` is continued on the next physical line.

    INPUT
      line - str, one physical source line without its newline.

    OUTPUT
      out  - bool, 1x1. True when a ... continuation is in effect.

    A ... inside a comment or inside a character literal continues
    nothing. The quote count before the ellipsis distinguishes the two
    cases well enough for declaration lines, which do not contain
    strings with an odd number of quotes.
    """
    stripped = line.lstrip()
    if stripped.startswith('%'):
        return False
    m = _CONT.search(line)
    if m is None:
        return False
    before = line[:m.start()]
    if before.count("'") % 2 == 1:      # ellipsis inside a char literal
        return False
    if '%' in before:                   # ellipsis inside a trailing comment
        return False
    return True


def declaration_end(lines, start=0):
    """Index of the LAST physical line of the declaration at `start`.

    INPUT
      lines - list[str], [N], file content split on newlines.
      start - int, 1x1, index of the first declaration line. Default 0.

    OUTPUT
      idx   - int, 1x1. Equals `start` for a single-line declaration.

    A declaration that is left open at end of file returns the last
    index rather than raising: reporting the malformed file is the
    caller's job, not this function's.
    """
    i = start
    while i < len(lines) - 1 and continues(lines[i]):
        i += 1
    return i


def help_span(lines):
    """Half-open range of the leading help comment block.

    INPUT
      lines - list[str], [N], file content split on newlines.

    OUTPUT
      first - int, 1x1, index of the first help line.
      stop  - int, 1x1, index one past the last help line. Equals
              `first` when the file carries no help block.

    A file that opens with a comment (a script) has its help block at
    index 0. A file that opens with a declaration has it after the
    complete declaration, continuations included.
    """
    if not lines:
        return 0, 0
    first = 0 if lines[0].lstrip().startswith('%') else declaration_end(lines) + 1
    stop = first
    while stop < len(lines) and lines[stop].startswith('%'):
        stop += 1
    return first, stop


def comment_inside_decl(lines):
    """Comment lines that interrupt a continued declaration.

    INPUT
      lines - list[str], [N], file content split on newlines.

    OUTPUT
      hits  - list[int], [K], zero-based index of the FIRST comment line
              of each break. Empty for a well-formed file.

    One entry per broken declaration, not one per comment line: a
    90-line help block wedged into a declaration is a single defect,
    and reporting it 90 times buries the second file in the log.

    This is the defect signature that broke parseDataSection.m and
    parseClassicProduct.m. It is checked here so that the static gate
    and the MATLAB suite can both use one definition.
    """
    hits = []
    open_cont = False
    reported = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith('%'):
            if open_cont and not reported:
                hits.append(i)
                reported = True
            continue
        open_cont = continues(line)
        reported = False
    return hits
