#!/usr/bin/env python3
"""generate_docs.py - single entry point for documentation generation.

Runs the two generators in order:
  generate_html.py   html/ reference pages, product page, getting started, helptoc
  generate_guide.py  doc/gracefoReading_Guide.pdf

Both read the MATLAB help blocks (docsrc/helpparse.py) as the single
source of truth, with docsrc/functionSpecs.json supplying only
toolbox-level metadata, page order and the aux-field tables. Editing
html/ or the PDF by hand is therefore pointless: edit the help text in
the .m file and rerun this script.

Usage: python3 docsrc/generate_docs.py

Developed by Matthias Weigelt with the help of Anthropic Claude Opus 5,
2026-08-14.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    rc = subprocess.call([sys.executable, os.path.join(HERE, "auditHelp.py"), "--quiet"])
    if rc != 0:
        print("Documentation not generated: fix the help-block problems above.",
              file=sys.stderr)
        return rc
    sys.path.insert(0, HERE)
    import generate_html
    import generate_guide
    generate_html.main()
    generate_guide.build()
    return 0


if __name__ == "__main__":
    sys.exit(main())
