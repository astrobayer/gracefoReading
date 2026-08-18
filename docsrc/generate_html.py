#!/usr/bin/env python3
"""generate_html.py - HTML reference pages for the gracefoReading toolbox.

Pages are generated FROM THE MATLAB HELP BLOCKS (via helpparse.py), so
`help gracefoReading.readL1b` and the HTML reference cannot diverge:
there is one source, the code. docsrc/functionSpecs.json supplies only
toolbox-level metadata and the page order.

Outputs:
  html/gracefoReading.<function>.html
  html/gracefoReading_product_page.html
  html/gracefoReading_getting_started.html
  html/helptoc.xml

Usage: python3 docsrc/generate_html.py

Developed by Matthias Weigelt with the help of Anthropic Claude Opus 5,
2026-08-14.
"""
import html
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from helpparse import parse_file  # noqa: E402

HTML_DIR = os.path.join(ROOT, "html")
PKG = os.path.join(ROOT, "+gracefoReading")

CSS = """
body { font-family: Arial, Helvetica, sans-serif; margin: 0; padding: 0 2em 3em 2em;
       color: #212121; max-width: 62em; }
h1 { font-size: 1.6em; font-weight: normal; color: #b33; border-bottom: 1px solid #ccc;
     padding-bottom: 0.2em; margin-top: 1em; }
h2 { font-size: 1.2em; color: #333; margin-top: 1.6em; border-bottom: 1px solid #eee; }
p.purpose { font-size: 1.05em; color: #444; }
pre.syntax, pre.example { background: #f5f5f5; border: 1px solid #e0e0e0;
     padding: 0.7em 1em; border-radius: 4px; overflow-x: auto;
     font-family: Consolas, Monaco, monospace; font-size: 0.92em; }
p.excap { margin-bottom: 0.2em; font-weight: bold; font-size: 0.92em; color: #444; }
table.args { border-collapse: collapse; width: 100%; margin: 0.6em 0; }
table.args th { background: #f0f0f0; text-align: left; padding: 0.4em 0.6em;
     border: 1px solid #ddd; font-size: 0.88em; }
table.args td { padding: 0.4em 0.6em; border: 1px solid #ddd; font-size: 0.88em;
     vertical-align: top; }
td.mono, code { font-family: Consolas, Monaco, monospace; }
ul.fields { margin: 0.3em 0 0 0; padding-left: 1.1em; font-size: 0.95em; }
ul.limits li { margin-bottom: 0.35em; }
div.footer { margin-top: 3em; padding-top: 0.6em; border-top: 1px solid #ccc;
     color: #888; font-size: 0.8em; }
a { color: #06c; text-decoration: none; }
a:hover { text-decoration: underline; }
"""


def esc(s):
    return html.escape(str(s))


def footer(tb):
    return (f'<div class="footer">{esc(tb["name"])} v{esc(tb["version"])} &middot; '
            f'{esc(tb["date"])} &middot; Developed by Matthias Weigelt with the help of '
            f'Anthropic Claude Opus 5, {esc(tb["date"])} &middot; License: '
            f'{esc(tb["license"])} &middot; Generated from the MATLAB help blocks '
            f'&mdash; do not edit by hand.</div>')


def arg_table(args, none_text):
    if not args:
        return f"<p><em>{none_text}</em></p>"
    out = ['<table class="args"><tr><th>Name</th><th>Type</th><th>Size</th>'
           '<th>Description</th><th>Options</th><th>Default</th></tr>']
    for a in args:
        desc = esc(a["desc"])
        if a.get("validation"):
            desc += f'<br><em>Validation: {esc(a["validation"])}</em>'
        if a.get("fields"):
            items = "".join(
                f'<li><code>{esc(f["name"])}</code> &ndash; {esc(f["type"])}'
                + (f' {esc(f["size"])}' if f.get("size") else "")
                + f': {esc(f["desc"])}</li>' for f in a["fields"])
            desc += f'<ul class="fields">{items}</ul>'
        out.append(
            f'<tr><td class="mono">{esc(a["name"])}</td><td>{esc(a["type"])}</td>'
            f'<td>{esc(a["size"])}</td><td>{desc}</td>'
            f'<td>{esc(a["options"])}</td><td class="mono">{esc(a["default"])}</td></tr>')
    out.append("</table>")
    return "".join(out)


def err_table(rows, kind):
    out = [f'<table class="args"><tr><th>{kind} identifier</th><th>Condition</th></tr>']
    for r in rows:
        out.append(f'<tr><td class="mono">{esc(r["id"])}</td><td>{esc(r["cond"])}</td></tr>')
    out.append("</table>")
    return "".join(out)


def function_page(tb, doc, auxfields):
    full = f'{tb["name"]}.{doc["name"]}'
    p = [f'<!DOCTYPE html>\n<html><head><meta charset="utf-8"><title>{esc(full)}</title>',
         f'<style>{CSS}</style></head><body>',
         f'<h1>{esc(full)}</h1>',
         f'<p class="purpose">{esc(doc["purpose"])}</p>',
         '<h2>Syntax</h2>',
         f'<pre class="syntax">{esc(chr(10).join(doc["syntax"]))}</pre>',
         '<h2>Description</h2>']
    p += [f'<p>{esc(par)}</p>' for par in doc["description"]]
    p.append('<h2>Input Arguments</h2>')
    p.append(arg_table(doc["inputs"], "This function takes no input arguments."))
    p.append('<h2>Output Arguments</h2>')
    p.append(arg_table(doc["outputs"],
                       "This function returns no outputs; it works by side effect."))
    if auxfields:
        p.append('<h2>Fields of aux</h2>')
        rows = ['<table class="args"><tr><th>Field</th><th>Type</th><th>Size</th>'
                '<th>Description</th></tr>']
        for r in auxfields:
            rows.append(f'<tr><td class="mono">{esc(r.get("name",""))}</td>'
                        f'<td>{esc(r.get("type",""))}</td><td>{esc(r.get("size",""))}</td>'
                        f'<td>{esc(r.get("desc",""))}</td></tr>')
        rows.append('</table>')
        p.append("".join(rows))
    if doc["limitations"]:
        p.append('<h2>Accuracy and Limitations</h2><ul class="limits">')
        p += [f'<li>{esc(x)}</li>' for x in doc["limitations"]]
        p.append('</ul>')
    if doc["errors"]:
        p.append('<h2>Errors</h2>' + err_table(doc["errors"], "Error"))
    if doc["warnings"]:
        p.append('<h2>Warnings</h2>' + err_table(doc["warnings"], "Warning"))
    if doc["examples"]:
        p.append('<h2>Examples</h2>')
        for ex in doc["examples"]:
            if ex["caption"]:
                p.append(f'<p class="excap">{esc(ex["caption"])}</p>')
            p.append(f'<pre class="example">{esc(ex["code"])}</pre>')
    if doc["seealso"]:
        links = ", ".join(
            f'<a href="{s}.html"><code>{esc(s)}</code></a>'
            if os.path.isfile(os.path.join(HTML_DIR, s + ".html"))
            else f'<code>{esc(s)}</code>' for s in doc["seealso"])
        p.append(f'<h2>See Also</h2><p>{links}</p>')
    p.append(footer(tb))
    p.append('</body></html>')
    return "\n".join(p)


def product_page(tb, docs):
    rows = "".join(
        f'<tr><td class="mono"><a href="{tb["name"]}.{d["name"]}.html">'
        f'{tb["name"]}.{d["name"]}</a></td><td>{esc(d["purpose"])}</td></tr>'
        for d in docs)
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>{esc(tb['name'])} Toolbox</title>
<style>{CSS}</style></head><body>
<h1>{esc(tb['name'])} Toolbox v{esc(tb['version'])}</h1>
<p class="purpose">{esc(tb['title'])}</p>
<p>{esc(tb['summary'])}</p>
<h2>Functions</h2>
<table class="args"><tr><th>Function</th><th>Purpose</th></tr>{rows}</table>
<h2>Getting Started</h2>
<p>See the <a href="{tb['name']}_getting_started.html">getting started page</a>
for installation, a first read and the batch workflow, and the PDF guide
<code>doc/gracefoReading_Guide.pdf</code> for the complete manual.</p>
<pre class="example">setupGraceFOReading              % add toolbox to the path
[t, obs, aux] = gracefoReading.readL1b('ACT1B_2020-01-01_C_04.txt');
addpath('ci'); results = runCI();        % verify the installation</pre>
{footer(tb)}
</body></html>"""


def getting_started(tb, docs):
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Getting Started</title>
<style>{CSS}</style></head><body>
<h1>Getting Started with {esc(tb['name'])}</h1>
<p class="purpose">Installation, first read, and the batch workflow.</p>

<h2>1. Installation</h2>
<p>Unpack the toolbox anywhere and add it to the MATLAB path. Nothing is
copied elsewhere, so deleting the folder removes the toolbox.</p>
<pre class="example">cd &lt;toolboxRoot&gt;
setupGraceFOReading            % path + doc registration, this session
% permanent: add the addpath call to your startup.m</pre>
<p>Requires MATLAB {esc(tb['matlabRelease'])} or later
(<code>arguments</code> blocks). Verify with:</p>
<pre class="example">addpath('ci'); results = runCI();   % all suites, reports in artifacts/
disp(table(results));</pre>

<h2>2. Read one product file</h2>
<pre class="example">[t, obs, aux] = gracefoReading.readL1b('ACT1B_2020-01-01_C_04.txt');
disp(aux.obsNames');                       % what the columns mean
plot(t(:,2)/3600, obs(:, strcmp(aux.obsNames, 'lin_accl_x')));
xlabel('hours of day'); ylabel('m/s^2');</pre>
<p>The reader takes column names, units and flag meanings from the file's
own header, so the same call works for every Level-1B product.</p>

<h2>3. Quality flags and gaps</h2>
<pre class="example">[bits, report] = gracefoReading.decodeQualFlags(aux);   % meanings from the header
disp(report);
[t, obs, aux] = gracefoReading.readL1b(f, 'QualityBitMask', [6 7]);
[gaps, stats] = gracefoReading.findGaps(t);             % contiguous segments</pre>

<h2>4. Batch processing</h2>
<pre class="example">files = gracefoReading.findL1bFiles(archive, "ACT1B", ...
    'DateRange', [datetime(2020,1,1) datetime(2020,1,31)], 'Satellite', "C");
[t, acc, aux] = gracefoReading.readL1bMulti(files, 'CacheDir', 'l1bcache');</pre>
<p>With <code>'CacheDir'</code> the second pass over the same files loads
parsed results instead of re-parsing them; the cache key is a SHA-256
digest of file content and toolbox version, so it invalidates itself.</p>

<h2>5. Export to GROOPS</h2>
<pre class="example">gracefoReading.writeGroopsInstrument('acc.txt', t, acc(:,1:3));
[t2, d2, info] = gracefoReading.readGroopsInstrument('acc.txt');   % verify</pre>

<h2>Function reference</h2>
<p>{", ".join(f'<a href="{tb["name"]}.{d["name"]}.html">{esc(d["name"])}</a>' for d in docs)}</p>
{footer(tb)}
</body></html>"""


def helptoc(tb, docs):
    items = "\n".join(
        f'        <tocitem target="{tb["name"]}.{d["name"]}.html">'
        f'{tb["name"]}.{d["name"]}</tocitem>' for d in docs)
    return f"""<?xml version="1.0" encoding="utf-8"?>
<toc version="2.0">
    <tocitem target="{tb['name']}_product_page.html">{tb['name']} Toolbox
        <tocitem target="{tb['name']}_getting_started.html">Getting Started</tocitem>
{items}
    </tocitem>
</toc>
"""


def load_docs(spec):
    """Parse every public function, ordered as in functionSpecs.json."""
    order = [f["name"] for f in spec["functions"]]
    files = [f[:-2] for f in sorted(os.listdir(PKG))
             if f.endswith(".m") and f != "Contents.m"]
    names = [n for n in order if n in files] + [n for n in files if n not in order]
    return [parse_file(os.path.join(PKG, n + ".m")) for n in names]


def main():
    spec = json.load(open(os.path.join(HERE, "functionSpecs.json"), encoding="utf-8"))
    tb = spec["toolbox"]
    aux_by_name = {f["name"]: f.get("auxFields", []) for f in spec["functions"]}
    docs = load_docs(spec)
    os.makedirs(HTML_DIR, exist_ok=True)
    for d in docs:
        with open(os.path.join(HTML_DIR, f'{tb["name"]}.{d["name"]}.html'),
                  "w", encoding="utf-8") as fh:
            fh.write(function_page(tb, d, aux_by_name.get(d["name"], [])))
    with open(os.path.join(HTML_DIR, f'{tb["name"]}_product_page.html'),
              "w", encoding="utf-8") as fh:
        fh.write(product_page(tb, docs))
    with open(os.path.join(HTML_DIR, f'{tb["name"]}_getting_started.html'),
              "w", encoding="utf-8") as fh:
        fh.write(getting_started(tb, docs))
    with open(os.path.join(HTML_DIR, "helptoc.xml"), "w", encoding="utf-8") as fh:
        fh.write(helptoc(tb, docs))
    print(f"HTML: {len(docs)} function pages + product page + getting started + helptoc")
    return docs


if __name__ == "__main__":
    main()
