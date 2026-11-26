# Over the manifest's 553 volumes: documents whose chunk holds a <table> (which the PDF draws as lines joined by
# " | ", PDFCollectionExporter.swift:1118-1142), and a <figure> with a <graphic> (#1516's images). Stdlib, regex.
import json, re, sys
repo, corpus = sys.argv[1], sys.argv[2]
files = [v["filename"] for v in json.load(open(f"{repo}/FRUSExplorer/Resources/manifest.json"))]
doc_start = re.compile(r'<div\b[^>]*\btype="document"[^>]*>')
docs = with_table = with_fig = 0; vt = vf = 0
for name in files:
    try:
        t = open(f"{corpus}/{name}", encoding="utf-8").read()
    except FileNotFoundError:
        continue
    starts = [m.start() for m in doc_start.finditer(t)]
    a = b = 0
    for i, s in enumerate(starts):
        chunk = t[s: starts[i + 1] if i + 1 < len(starts) else len(t)]
        docs += 1
        if '<table' in chunk:
            with_table += 1; a += 1
        if re.search(r'<figure\b[^>]*>(?:(?!</figure>).)*<graphic\b', chunk, re.S):
            with_fig += 1; b += 1
    vt += a > 0; vf += b > 0
print(f"documents {docs}: with a table {with_table} in {vt} volumes; with a figure image {with_fig} in {vf} volumes")
