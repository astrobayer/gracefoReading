#!/usr/bin/env python3
"""generate_guide.py - the PDF user guide for the gracefoReading toolbox.

Builds doc/gracefoReading_Guide.pdf with:
  1 Overview and data background
  2 Installation
  3 Build, test and continuous integration
  4 Step-by-step guides (seven workflows)
  5 Worked examples
  6 API reference (generated from the MATLAB help blocks)
  7 Accuracy, limitations and known issues
  8 Version history

Sections 6 and 7 come from the help blocks via helpparse.py, so the
guide cannot drift from the code; the narrative sections live here.

Usage: python3 docsrc/generate_guide.py   (needs reportlab)

Developed by Matthias Weigelt with the help of Anthropic Claude Opus 5,
2026-08-14.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from helpparse import parse_file  # noqa: E402

PKG = os.path.join(ROOT, "+gracefoReading")
OUT = os.path.join(ROOT, "doc", "gracefoReading_Guide.pdf")

from reportlab.lib import colors  # noqa: E402
from reportlab.lib.pagesizes import A4  # noqa: E402
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle  # noqa: E402
from reportlab.lib.units import cm  # noqa: E402
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table,  # noqa: E402
                                TableStyle, PageBreak, Preformatted,
                                KeepTogether, ListFlowable, ListItem)

ACCENT = colors.HexColor("#993333")
S = getSampleStyleSheet()
BODY = ParagraphStyle("BodyX", parent=S["BodyText"], fontSize=9.5, leading=13,
                      spaceAfter=6)
H1 = ParagraphStyle("H1x", parent=S["Heading1"], textColor=ACCENT, fontSize=17,
                    spaceBefore=6, spaceAfter=10)
H2 = ParagraphStyle("H2x", parent=S["Heading2"], fontSize=12.5, spaceBefore=12,
                    spaceAfter=6)
H3 = ParagraphStyle("H3x", parent=S["Heading3"], fontSize=10.5, spaceBefore=8,
                    spaceAfter=4, textColor=colors.HexColor("#444444"))
CODE = ParagraphStyle("CodeX", parent=S["Code"], fontSize=7.6, leading=9.4,
                      backColor=colors.HexColor("#f5f5f5"),
                      borderPadding=4, spaceBefore=3, spaceAfter=7,
                      leftIndent=6)
CELL = ParagraphStyle("CellX", parent=BODY, fontSize=7.4, leading=9, spaceAfter=0)
CELLM = ParagraphStyle("CellMX", parent=CELL, fontName="Courier", fontSize=7.0)
BULLET = ParagraphStyle("BulX", parent=BODY, fontSize=9, leading=12, spaceAfter=3)


def esc(t):
    return (str(t).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def para(t, style=BODY):
    return Paragraph(esc(t), style)


def code(t):
    return Preformatted(t, CODE)


def bullets(items, style=BULLET):
    return ListFlowable([ListItem(Paragraph(esc(i), style), leftIndent=12)
                         for i in items], bulletType="bullet", start="•",
                        leftIndent=12)


def table(data, widths, header=True):
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    style = [("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#cccccc")),
             ("VALIGN", (0, 0), (-1, -1), "TOP"),
             ("LEFTPADDING", (0, 0), (-1, -1), 4),
             ("RIGHTPADDING", (0, 0), (-1, -1), 4),
             ("TOPPADDING", (0, 0), (-1, -1), 3),
             ("BOTTOMPADDING", (0, 0), (-1, -1), 3)]
    if header:
        style.append(("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#f0f0f0")))
    t.setStyle(TableStyle(style))
    return t


def hdr(txt, cols):
    return [Paragraph(f"<b>{esc(h)}</b>", CELL) for h in cols]


# --------------------------------------------------------------- API part
def api_section(doc, tb):
    """One function's reference entry, built from its help block."""
    full = f'{tb["name"]}.{doc["name"]}'
    out = [Paragraph(esc(full), H2), para(doc["purpose"])]
    out.append(code("\n".join(doc["syntax"])))
    for p in doc["description"]:
        out.append(para(p))

    for key, title, none in (("inputs", "Input arguments", "None."),
                             ("outputs", "Output arguments",
                              "None; the function works by side effect.")):
        out.append(Paragraph(title, H3))
        args = doc[key]
        if not args:
            out.append(para(none))
            continue
        data = [hdr(None, ["Name", "Type", "Size", "Description",
                           "Options and default"])]
        for a in args:
            desc = a["desc"]
            if a.get("validation"):
                desc += f' (validation: {a["validation"]})'
            if a.get("fields"):
                desc += "<br/>" + "<br/>".join(
                    f'&nbsp;&nbsp;<font face="Courier">{esc(f["name"])}</font> '
                    f'{esc(f["type"])} {esc(f.get("size",""))}: {esc(f["desc"])}'
                    for f in a["fields"])
            od = ""
            if a["options"]:
                od += f'Options: {esc(a["options"])}<br/>'
            if a["default"]:
                od += f'<b>Default:</b> <font face="Courier">{esc(a["default"])}</font>'
            data.append([Paragraph(esc(a["name"]), CELLM),
                         Paragraph(esc(a["type"]), CELL),
                         Paragraph(esc(a["size"]), CELL),
                         Paragraph(desc if a.get("fields") else esc(desc), CELL),
                         Paragraph(od or "&ndash;", CELL)])
        out.append(table(data, [2.6 * cm, 2.3 * cm, 1.9 * cm, 6.2 * cm, 3.4 * cm]))

    if doc["limitations"]:
        out.append(Paragraph("Accuracy and limitations", H3))
        out.append(bullets(doc["limitations"]))
    for key, title in (("errors", "Errors"), ("warnings", "Warnings")):
        if doc[key]:
            out.append(Paragraph(title, H3))
            data = [hdr(None, ["Identifier", "Condition"])]
            for e in doc[key]:
                data.append([Paragraph(esc(e["id"]), CELLM),
                             Paragraph(esc(e["cond"]), CELL)])
            out.append(table(data, [7.0 * cm, 9.4 * cm]))
    if doc["examples"]:
        out.append(Paragraph("Examples", H3))
        for ex in doc["examples"]:
            if ex["caption"]:
                out.append(para(ex["caption"], ParagraphStyle(
                    "ExCap", parent=BODY, fontSize=8.5, spaceAfter=1,
                    textColor=colors.HexColor("#555555"))))
            out.append(code(ex["code"]))
    if doc["seealso"]:
        out.append(para("See also: " + ", ".join(doc["seealso"]),
                        ParagraphStyle("SeeAlso", parent=BODY, fontSize=8.5,
                                       textColor=colors.HexColor("#555555"))))
    out.append(Spacer(1, 0.35 * cm))
    return out


def changelog_rows():
    """Version history from CHANGELOG.md headings."""
    path = os.path.join(ROOT, "CHANGELOG.md")
    rows = []
    if not os.path.isfile(path):
        return rows
    cur = None
    for ln in open(path, encoding="utf-8"):
        m = re.match(r"^##\s+([\d.]+)\s+—\s+(\S+)", ln)
        if m:
            cur = {"v": m.group(1), "date": m.group(2), "items": []}
            rows.append(cur)
        elif cur is not None and ln.startswith("### "):
            cur["items"].append(ln[4:].strip())
    return rows


def build(tb=None):
    if tb is None:
        spec = json.load(open(os.path.join(HERE, "functionSpecs.json"), encoding="utf-8"))
        tb = spec["toolbox"]
        order = [f["name"] for f in spec["functions"]]
    else:
        order = []
    files = [f[:-2] for f in sorted(os.listdir(PKG))
             if f.endswith(".m") and f != "Contents.m"]
    names = [n for n in order if n in files] + [n for n in files if n not in order]
    docs = [parse_file(os.path.join(PKG, n + ".m")) for n in names]
    release = re.sub(r'\s+or later$', '', tb["matlabRelease"])

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    story = []

    # ---------------------------------------------------------- title page
    story += [
        Spacer(1, 3.5 * cm),
        Paragraph("gracefoReading", ParagraphStyle(
            "TitleX", parent=H1, fontSize=30, textColor=ACCENT, spaceAfter=4)),
        Paragraph(esc(tb["title"]), ParagraphStyle(
            "SubX", parent=S["Heading3"], fontSize=13, textColor=colors.HexColor("#444444"))),
        Spacer(1, 0.8 * cm),
        Paragraph("User Guide and API Reference", ParagraphStyle(
            "Sub2", parent=BODY, fontSize=12)),
        Spacer(1, 0.4 * cm),
        para(f'Version {tb["version"]} — {tb["date"]}'),
        Spacer(1, 1.2 * cm),
        para(tb["summary"]),
        Spacer(1, 4.5 * cm),
        para("Developed by Matthias Weigelt with the help of Anthropic Claude "
             f'Opus 5, {tb["date"]}.'),
        para(f'License: {tb["license"]}. Requires MATLAB {release} or later.'),
        para("Sections 6 and 7 are generated from the MATLAB help blocks, so this "
             "guide and the in-product help cannot disagree."),
        PageBreak(),
    ]

    # ------------------------------------------------------- 1  Overview
    story += [
        Paragraph("1  Overview", H1),
        para("gracefoReading reads GRACE-FO Level-1B ASCII products into MATLAB "
             "and provides the surrounding tooling needed for real processing "
             "work: archive search, gap analysis, quality-flag decoding, "
             "content-hashed caching and GROOPS interoperability."),
        Paragraph("1.1  What the products look like", H2),
        para("All GRACE-FO Level-1B ASCII products share one structure. A YAML "
             "header, terminated by the line \"# End of YAML header\", declares "
             "every data column in order under its variables key, together with "
             "units, comments and flag meanings. The records follow as "
             "whitespace-delimited lines."),
        para("Because the header is self-describing, readL1b needs no per-product "
             "column tables: it reads ACT1B/ACC1B, SCA1B, KBR1B, LRI1B, GNV1B, "
             "THR1B and MAS1B with the same code path, and a future product with "
             "the same header dialect will work without changes."),
        Paragraph("1.2  Details that decide correctness", H2),
        para("Four properties of the real PO.DAAC RL04 files matter enough to "
             "state explicitly, because a reader that assumes otherwise produces "
             "plausible but wrong results:"),
        bullets([
            "Split time tags: time_intg carries whole seconds and time_frac the "
            "fraction, but in THR1B and MAS1B the fraction is declared in "
            "MICROSECONDS. Assuming seconds shifts every epoch.",
            "Time system: GPS seconds past 2000-01-01 12:00:00, continuous, "
            "without leap seconds. Converting via a naive UTC path introduces "
            "an 18 second error.",
            "Flag columns: qualflg and prod_flag are 8-character bit STRINGS, "
            "not numbers. Bit 0 is the rightmost character. Reading them as "
            "numbers destroys the bit pattern.",
            "Variable-length records: in MAS1B the prod_flag decides which "
            "columns are present in each line, so a line has fewer tokens than "
            "there are declared variables. Absent values are returned as NaN.",
        ]),
        Paragraph("1.3  Design principles", H2),
        bullets([
            "Header-driven: metadata comes from the file, never from a "
            "hard-coded table, so the reader follows the products across "
            "releases.",
            "Fail loudly: a row-integrity violation names the exact line rather "
            "than silently producing a shorter array.",
            "Validated against real data: the acceptance suite reads genuine "
            "PO.DAAC files and compares against an independent Python "
            "reference implementation.",
            "Provenance: everything the reader learned about a file is returned "
            "in aux, and cache keys are SHA-256 digests of the parse inputs.",
        ]),
        Paragraph("1.4  Toolbox layout", H2),
        table([hdr(None, ["Path", "Contents"])] + [
            [Paragraph(esc(a), CELLM), Paragraph(esc(b), CELL)] for a, b in [
                ("+gracefoReading/", "namespace package: public API and +internal helpers"),
                ("html/", "generated HTML reference, registered with the doc browser"),
                ("doc/", "this guide"),
                ("docsrc/", "documentation generators and the help-text audit"),
                ("tests/", "matlab.unittest suites, real data and Python reference"),
                ("examples/", "demoGracefoReading.m, an executable tour"),
                ("ci/", "runCI.m, the continuous-integration entry point"),
                ("buildfile.m", "buildtool tasks: test, audit, docs, check, guide, release"),
            ]], [4.6 * cm, 11.8 * cm]),
        PageBreak(),
    ]

    # --------------------------------------------------- 2  Installation
    story += [
        Paragraph("2  Installation", H1),
        Paragraph("2.1  Requirements", H2),
        bullets([
            f'MATLAB {release} or later (the toolbox uses arguments blocks).',
            "No additional MathWorks toolboxes are required.",
            "A JVM is used for in-memory gzip decompression and SHA-256 cache "
            "keys; under -nojvm both fall back gracefully.",
            "Python 3.9+ with reportlab only if you want to regenerate the "
            "documentation yourself.",
        ]),
        Paragraph("2.2  Install", H2),
        para("Unpack the archive anywhere you like, for example "
             "C:\\Users\\<you>\\Documents\\MATLAB\\gracefoReading or "
             "~/matlab/gracefoReading, then add it to the path:"),
        code("cd <toolboxRoot>\nsetupGraceFOReading"),
        para("setupGraceFOReading adds the toolbox root, which contains the "
             "+gracefoReading package folder, and registers the HTML "
             "documentation with the doc browser. The tests folder is "
             "deliberately not added to the path, so that fixture names can "
             "never shadow real functions."),
        para("For a permanent installation put the addpath call into your "
             "startup.m:"),
        code("addpath('C:\\Users\\<you>\\Documents\\MATLAB\\gracefoReading');"),
        Paragraph("2.3  Verify", H2),
        code("addpath('ci');\nresults = runCI();        % all suites; reports in artifacts/\n"
             "disp(table(results));"),
        para("A clean installation reports all tests passed. The suites are "
             "self-contained: synthetic fixtures are written to a temporary "
             "folder and removed afterwards, and the bundled real files in "
             "tests/realdata/ provide the acceptance checks."),
        Paragraph("2.4  Uninstall", H2),
        para("Remove the folder from the path and delete it. Nothing is "
             "installed elsewhere; caches, if you used them, live in the "
             "directory you named with 'CacheDir'."),
        PageBreak(),
    ]

    # ------------------------------------------- 3  Build, test and CI
    story += [
        Paragraph("3  Build, test and continuous integration", H1),
        para("Every repeatable action has one entry point, so that a release "
             "never depends on remembering a sequence of steps."),
        Paragraph("3.1  Build tasks", H2),
        table([hdr(None, ["Command", "Action"])] + [
            [Paragraph(esc(a), CELLM), Paragraph(esc(b), CELL)] for a, b in [
                ("buildtool test", "run every suite through ci/runCI.m; JUnit and Cobertura reports in artifacts/"),
                ("buildtool audit", "check all help blocks against the documentation standard (docsrc/auditHelp.py)"),
                ("buildtool docs", "regenerate html/ and this guide from the help blocks"),
                ("buildtool check", "run the documentation-consistency suite only"),
                ("buildtool guide", "regenerate this PDF alone"),
                ("buildtool release", "audit, test, docs and check, then package a versioned zip"),
            ]], [4.6 * cm, 11.8 * cm]),
        para("buildtool requires R2022b or later. On earlier releases call "
             "ci/runCI.m and docsrc/generate_docs.py directly; the actions are "
             "identical."),
        Paragraph("3.2  Running the tests", H2),
        code("addpath('ci');\nresults = runCI();                 % interactive\n"
             "results = runCI('Coverage', false);% faster, no instrumentation\n\n"
             "% batch mode, exactly what CI runs:\n"
             "%   matlab -batch \"addpath('ci'); runCI('Exit', true)\""),
        para("'Exit' matters: MATLAB in -batch mode returns exit status 0 even "
             "when tests fail, so without it a CI job stays green over a red "
             "test suite. Do not use it interactively, since it closes MATLAB."),
        Paragraph("3.3  Test suites", H2),
        table([hdr(None, ["Suite", "Scope"])] + [
            [Paragraph(esc(a), CELLM), Paragraph(esc(b), CELL)] for a, b in [
                ("testReadL1b", "reader core against synthetic fixtures: headers, time tags, flags, prod_flag, cache, classic path"),
                ("testRealData", "acceptance against bundled real PO.DAAC files, expectations from the Python reference"),
                ("testBatchTools", "findGaps, findL1bFiles, readGroopsInstrument, multi-file monotonicity"),
                ("testUtilities", "flag decoding, quaternion norm, GROOPS export, version metadata"),
                ("testDocConsistency", "code, documentation and metadata agree; help blocks meet the standard"),
            ]], [4.2 * cm, 12.2 * cm]),
        Paragraph("3.4  Continuous integration", H2),
        para("The repository ships .github/workflows/ci.yml, which runs the "
             "suites on Linux and Windows and audits the documentation. Both "
             "platforms are tested deliberately: the two defects that survived "
             "release testing in this toolbox were platform-specific, namely a "
             "Java gzip read that silently returned zeros and CRLF line endings "
             "from fopen 'wt' on Windows."),
        code("matlab -batch \"addpath('ci'); runCI('Exit', true)\""),
        para("Installation of runners, licensing on self-hosted machines, and "
             "the equivalent GitLab and Jenkins snippets are documented in "
             "docs/CI_SETUP.md."),
        Paragraph("3.5  Documentation workflow", H2),
        para("The MATLAB help blocks are the single source of truth. "
             "docsrc/generate_docs.py parses them and writes both the HTML "
             "reference and this guide; docsrc/auditHelp.py enforces the "
             "structure that makes the parsing possible. Never edit html/ by "
             "hand: edit the help text and regenerate."),
        code("python3 docsrc/auditHelp.py      # structure check\n"
             "python3 docsrc/generate_docs.py  # html/ + doc/ regeneration"),
        PageBreak(),
    ]

    # -------------------------------------------- 4  Step-by-step guides
    story += [Paragraph("4  Step-by-step guides", H1)]
    guides = [
        ("4.1  Read one product file",
         "Start from a downloaded PO.DAAC file. The reader needs nothing but "
         "the path: column names, units and flag meanings come from the file.",
         "[t, obs, aux] = gracefoReading.readL1b('ACT1B_2020-01-01_C_04.txt');\n\n"
         "disp(aux.product);            % 'ACT1B'\n"
         "disp(aux.obsNames');          % what each obs column is\n"
         "disp(aux.numRecordsActual);   % records parsed\n\n"
         "ix = strcmp(aux.obsNames, 'lin_accl_x');\n"
         "plot(t(:,2)/3600, obs(:, ix));\n"
         "xlabel('hours of day'); ylabel('linear acceleration x [m/s^2]');",
         ["t(:,1) is the integer MJD, t(:,2) the seconds of day.",
          "Gzipped files work identically: pass the .gz path.",
          "aux.header keeps the raw header for provenance."]),
        ("4.2  Select a time window and a time format",
         "Restrict to an interval and choose the representation that fits the "
         "next processing step.",
         "% one hour, as datetime\n"
         "[t, obs] = gracefoReading.readL1b(f, 'TimeFormat', 'datetime', ...\n"
         "    'TimeRange', [datetime(2020,1,1,0,0,0), datetime(2020,1,1,1,0,0)]);\n\n"
         "% exact int64 GPS nanoseconds for a nanosecond pipeline\n"
         "tns = gracefoReading.readL1b(f, 'TimeFormat', 'gpsns');\n"
         "fprintf('%d ns, class %s\\n', tns(1), class(tns));",
         ["\"mjd\" (default) is the double pair, convenient for plotting.",
          "\"gpsns\" is exact integer arithmetic; a double cannot hold "
          "2020-era GPS nanoseconds without rounding.",
          "'TimeRange' accepts decimal MJD as doubles or datetimes."]),
        ("4.3  Work with quality flags",
         "Flags are bit strings. Decode them with the meanings from the file's "
         "own header, then filter as coarsely or as finely as you need.",
         "[t, obs, aux] = gracefoReading.readL1b(f);\n"
         "[bits, report] = gracefoReading.decodeQualFlags(aux);\n"
         "disp(report)            % bit, meaning, countSet, fracSet\n\n"
         "% drop everything flagged\n"
         "[t, obs] = gracefoReading.readL1b(f, 'ApplyQualityFlags', true);\n\n"
         "% or only the bits that matter for your application\n"
         "[t, obs, aux] = gracefoReading.readL1b(f, 'QualityBitMask', [6 7]);\n"
         "fprintf('%d record(s) removed\\n', aux.numRecordsFlagged);",
         ["Bit 0 is the rightmost character of the bit string.",
          "The two quality options are mutually exclusive by design; asking "
          "for both raises conflictingQualityOptions.",
          "Filtering removes records, which creates gaps; see 4.4."]),
        ("4.4  Find gaps and process contiguous segments",
         "Filtering and data outages both break continuity. Most downstream "
         "operations, from differentiation to filtering, are only valid within "
         "a contiguous segment.",
         "[gaps, stats] = gracefoReading.findGaps(t);          % rate auto-detected\n"
         "fprintf('%d gap(s), longest %.0f s\\n', stats.numGaps, stats.longestGapSec);\n"
         "disp(gaps)\n\n"
         "for s = 1:size(stats.segments, 1)\n"
         "    idx = stats.segments(s,1):stats.segments(s,2);\n"
         "    processSegment(t(idx,:), obs(idx,:));\n"
         "end",
         ["Pass 'NominalRate' when the series is dominated by gaps, since the "
          "automatic estimate is the median difference.",
          "All three time formats give identical results.",
          "stats.segments always has at least one row."]),
        ("4.5  Batch process an archive",
         "Locate files by product and date, check coverage, then read them as "
         "one series.",
         "[files, rep] = gracefoReading.findL1bFiles(archive, \"ACT1B\", ...\n"
         "    'DateRange', [datetime(2020,1,1) datetime(2020,1,31)], ...\n"
         "    'Satellite', \"C\");\n"
         "fprintf('%d file(s), %d day(s) missing\\n', numel(files), numel(rep.missingDates));\n\n"
         "[t, acc, aux] = gracefoReading.readL1bMulti(files, ...\n"
         "    'ApplyQualityFlags', true, 'CacheDir', 'l1bcache');\n"
         "disp(aux.recordsPerFile');   % contribution of each file",
         ["Check rep.missingDates before a long run; a silent hole in the "
          "archive is worse than a failed search.",
          "readL1bMulti warns when the concatenated time is not strictly "
          "increasing, which catches wrong order and duplicates.",
          "aux.recordsPerFile lets you map any record back to its file."]),
        ("4.6  Speed up repeated reads with caching",
         "Parsing ASCII is the expensive part. The cache stores the parsed "
         "result under a SHA-256 digest of the file content and toolbox "
         "version, so it is safe by construction: change a byte, or upgrade "
         "the toolbox, and the entry is no longer used.",
         "tic; gracefoReading.readL1b(f, 'CacheDir', 'l1bcache'); toc   % parse + store\n"
         "tic; [t, obs, aux] = gracefoReading.readL1b(f, 'CacheDir', 'l1bcache'); toc\n"
         "disp(aux.cacheHit);   % true\n\n"
         "% post-parse options still apply to a cached read\n"
         "tns = gracefoReading.readL1b(f, 'CacheDir', 'l1bcache', 'TimeFormat', 'gpsns');",
         ["One cache entry serves every TimeRange, TimeFormat and quality "
          "setting, because those are applied after loading.",
          "The digest doubles as a provenance fingerprint: equal keys mean "
          "equal parse inputs.",
          "Delete the directory to clear the cache; nothing else refers to it."]),
        ("4.7  Exchange data with GROOPS",
         "Export a series in the GROOPS ASCII instrument convention and read "
         "it back to verify the roundtrip.",
         "gracefoReading.writeGroopsInstrument('act.txt', t, acc(:,1:3), 'TypeCode', 3);\n"
         "[t2, d2, info] = gracefoReading.readGroopsInstrument('act.txt');\n"
         "fprintf('max |dt| = %.3g s\\n', ...\n"
         "    max(abs((t2(:,1)-t(:,1))*86400 + t2(:,2)-t(:,2))));",
         ["GROOPS stores time as decimal MJD, which resolves about 1.3 "
          "microseconds around MJD 58849; that is the roundtrip limit.",
          "Verify the version tag and type code against your GROOPS "
          "installation before production use.",
          "Output is LF-only on every platform, so files are byte-identical."]),
        ("4.8  Read classic GRACE data (experimental)",
         "Files from the original GRACE mission use key-value headers that do "
         "not declare their columns. The toolbox detects them and applies "
         "built-in layouts, warning every time.",
         "% built-in layout (ACC1B, SCA1B, KBR1B, GNV1B)\n"
         "[t, obs, aux] = gracefoReading.readL1b('ACC1B_2008-01-01_A_02.txt');\n"
         "disp(aux.headerFormat);          % 'classic'\n"
         "disp(aux.classicHeaderFields);   % parsed KEY : VALUE pairs\n\n"
         "% any other classic product needs an explicit layout\n"
         "[t, obs] = gracefoReading.readL1b(f, 'ColumnNames', ...\n"
         "    [\"gps_time\",\"GRACE_id\",\"myval\",\"qualflg\"]);",
         ["The built-in layouts are taken from the handbook and are NOT yet "
          "validated against real classic files. Confirm before scientific "
          "use, or pass 'ColumnNames'.",
          "Classic qualflg may be decimal rather than a bit string; then "
          "decodeQualFlags does not apply.",
          "Suppress the warning per session with warning('off', "
          "'gracefoReading:readL1b:classicExperimental') once verified."]),
    ]
    for title, intro, snippet, notes in guides:
        story.append(KeepTogether([Paragraph(title, H2), para(intro), code(snippet)]))
        story.append(bullets(notes))
    story.append(PageBreak())

    # ------------------------------------------------- 5  Worked examples
    story += [
        Paragraph("5  Worked examples", H1),
        Paragraph("5.1  Executable demo", H2),
        para("examples/demoGracefoReading.m walks through reading, flag "
             "decoding, nanosecond time, gap analysis, caching, GROOPS "
             "roundtrip and archive search using the two small real files "
             "bundled with the toolbox. It runs anywhere the toolbox is "
             "installed and doubles as a smoke test."),
        code("run(fullfile(toolboxRoot, 'examples', 'demoGracefoReading.m'))"),
        Paragraph("5.2  Daily accelerometer series for a month", H2),
        para("A complete, realistic script: locate files, read with quality "
             "filtering and caching, verify continuity, and hand the result to "
             "processing."),
        code("archive = '/data/gracefo/L1B';\n"
             "files = gracefoReading.findL1bFiles(archive, \"ACT1B\", ...\n"
             "    'DateRange', [datetime(2020,1,1) datetime(2020,1,31)], ...\n"
             "    'Satellite', \"C\");\n"
             "[~, rep] = gracefoReading.findL1bFiles(archive, \"ACT1B\", 'Satellite', \"C\");\n"
             "assert(isempty(rep.missingDates), 'archive incomplete');\n\n"
             "[t, acc, aux] = gracefoReading.readL1bMulti(files, ...\n"
             "    'ApplyQualityFlags', true, 'CacheDir', fullfile(tempdir,'l1b'));\n\n"
             "[gaps, stats] = gracefoReading.findGaps(t, 'NominalRate', 1);\n"
             "fprintf('%d records, %d gap(s), %d missing epoch(s)\\n', ...\n"
             "    size(t,1), stats.numGaps, stats.totalMissing);\n\n"
             "ix = ismember(aux.obsNames, {'lin_accl_x','lin_accl_y','lin_accl_z'});\n"
             "gracefoReading.writeGroopsInstrument('act_202001.txt', t, acc(:,ix));"),
        Paragraph("5.3  Attitude quality control", H2),
        code("[t, q, aux] = gracefoReading.readL1b('SCA1B_2020-01-01_C_04.txt');\n"
             "[ok, stats] = gracefoReading.checkQuaternionNorm(q, aux);\n"
             "fprintf('max |norm-1| = %.3g over %d records\\n', stats.maxDeviation, stats.n);\n"
             "if stats.numViolations > 0\n"
             "    disp(t(~ok, :));      % epochs to investigate\n"
             "end"),
        Paragraph("5.4  Thruster activity around a manoeuvre", H2),
        code("[tt, thr, auxT] = gracefoReading.readL1b('THR1B_2020-01-01_C_04.txt');\n"
             "[bits, rep] = gracefoReading.decodeQualFlags(auxT);\n"
             "activity = sum(thr, 2, 'omitnan');\n"
             "plot(tt(:,2)/3600, activity, '.');\n"
             "xlabel('hours of day'); ylabel('sum of thruster counters');\n"
             "% THR1B is event-driven: gaps here are physical, not data loss\n"
             "[gaps, stats] = gracefoReading.findGaps(tt);"),
        PageBreak(),
    ]

    # ------------------------------------------------- 6  API reference
    story += [Paragraph("6  API reference", H1),
              para("Generated from the MATLAB help blocks. In MATLAB, the same "
                   "text is available with help or doc, e.g. "
                   "help gracefoReading.readL1b.")]
    for i, d in enumerate(docs):
        story += api_section(d, tb)
        if i < len(docs) - 1:
            story.append(PageBreak())
    story.append(PageBreak())

    # ------------------------- 7  Accuracy, limitations and known issues
    story += [
        Paragraph("7  Accuracy, limitations and known issues", H1),
        Paragraph("7.1  Numerical accuracy", H2),
        bullets([
            "Values are converted with str2double, i.e. to the nearest double. "
            "The ASCII products carry fewer significant digits than a double, "
            "so nothing is lost relative to the file.",
            "The default time format is a double pair (integer MJD, seconds of "
            "day) and resolves better than 1e-10 s within a day.",
            "The \"gpsns\" format is exact integer arithmetic and is the "
            "recommended handoff to nanosecond pipelines; a single double "
            "cannot represent 2020-era GPS nanoseconds exactly.",
            "GROOPS export uses decimal MJD, limiting exchange with GROOPS to "
            "about 1.3 microseconds around MJD 58849.",
        ]),
        Paragraph("7.2  Known limitations", H2),
        bullets([
            "Binary Level-1B products are not supported; ASCII only.",
            "Classic GRACE (2002-2017) support is experimental: the built-in "
            "column layouts come from the handbook and are not yet validated "
            "against real classic files. Every classic read warns.",
            "GROOPS header conventions (version tag, type codes) have not been "
            "verified against a specific GROOPS installation.",
            "findL1bFiles recognizes the PO.DAAC naming convention only, and "
            "takes dates from file names rather than content.",
            "readL1bMulti concatenates in the given order without sorting or "
            "de-duplicating; it warns rather than repairing.",
            "Caching and gzip decompression use the JVM where available and "
            "fall back safely under -nojvm, with a warning in the cache case.",
        ]),
        Paragraph("7.3  Verified against real data", H2),
        para("The acceptance suite reads genuine PO.DAAC RL04 files of "
             "2020-01-01 for all seven products and compares record counts, "
             "first and last epochs, observation counts, flag handling and the "
             "MAS1B variable-length layout against an independent Python "
             "reference implementation. This exists because version 1.0 of "
             "this toolbox was written against invented header conventions and "
             "failed on every real file; synthetic fixtures alone cannot catch "
             "that class of error."),
        Paragraph("7.4  Version history", H2),
    ]
    rows = changelog_rows()
    if rows:
        data = [hdr(None, ["Version", "Date", "Highlights"])]
        for r in rows[:8]:
            data.append([Paragraph(esc(r["v"]), CELLM), Paragraph(esc(r["date"]), CELL),
                         Paragraph(esc("; ".join(r["items"]) or "see CHANGELOG.md"), CELL)])
        story.append(table(data, [1.8 * cm, 2.2 * cm, 12.4 * cm]))
    story.append(para("The complete change log is CHANGELOG.md in the toolbox root."))

    doc = SimpleDocTemplate(
        OUT, pagesize=A4, title=f'gracefoReading v{tb["version"]} User Guide',
        author="Matthias Weigelt", leftMargin=2.2 * cm, rightMargin=2.2 * cm,
        topMargin=2.0 * cm, bottomMargin=1.8 * cm)

    def decorate(canvas, _doc):
        canvas.saveState()
        canvas.setFont("Helvetica", 7.5)
        canvas.setFillColor(colors.HexColor("#888888"))
        if canvas.getPageNumber() > 1:
            canvas.drawString(2.2 * cm, 1.1 * cm,
                              f'gracefoReading v{tb["version"]} — User Guide')
            canvas.drawRightString(A4[0] - 2.2 * cm, 1.1 * cm,
                                   f"page {canvas.getPageNumber()}")
        canvas.restoreState()

    doc.build(story, onFirstPage=decorate, onLaterPages=decorate)
    print(f"PDF guide: {OUT} ({os.path.getsize(OUT)/1024:.0f} kB)")
    return OUT


if __name__ == "__main__":
    build()
