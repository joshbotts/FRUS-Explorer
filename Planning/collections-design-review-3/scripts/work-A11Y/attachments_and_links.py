# Count, over the manifest's 553 volumes of the public TEI, documents whose text holds an attachment
# with a head (which the serializer writes as <h3 class="attachment-heading">), and, in frus1946v06's
# eight telegrams of the design's §2.2, the links the web page would write by host.
# Stdlib only; regex over each document's chunk (from one <div type="document" to the next).
import json
import re
import sys

repo, corpus = sys.argv[1], sys.argv[2]
manifest = json.load(open(f"{repo}/FRUSExplorer/Resources/manifest.json"))
files = [v["filename"] for v in manifest]

doc_start = re.compile(r'<div\b[^>]*\btype="document"[^>]*>')
att = re.compile(r'<frus:attachment\b[^>]*>(.*?)</frus:attachment>', re.S)
head = re.compile(r'<head\b')

docs = with_att_head = vols_with = 0
for name in files:
    try:
        text = open(f"{corpus}/{name}", encoding="utf-8").read()
    except FileNotFoundError:
        continue
    starts = [m.start() for m in doc_start.finditer(text)]
    found = 0
    for i, s in enumerate(starts):
        chunk = text[s: starts[i + 1] if i + 1 < len(starts) else len(text)]
        docs += 1
        if any(head.search(a.group(1)) for a in att.finditer(chunk)):
            with_att_head += 1
            found += 1
    if found:
        vols_with += 1
print(f"documents {docs}; with an attachment that has a head {with_att_head} in {vols_with} volumes")

# The eight telegrams: links by host, as the serializer writes them.
text = open(f"{corpus}/frus1946v06.xml", encoding="utf-8").read()
ids = ["d470", "d473", "d474", "d475", "d476", "d477", "d480", "d486"]
starts = {m.group(1): m.start() for m in re.finditer(r'<div\b[^>]*\bxml:id="(d\d+)"[^>]*\btype="document"', text)}
starts.update({m.group(1): m.start() for m in re.finditer(r'<div\b[^>]*\btype="document"[^>]*\bxml:id="(d\d+)"', text)})
order = sorted(starts.items(), key=lambda kv: kv[1])
pos = {k: i for i, (k, _) in enumerate(order)}
totals = {"persName@corresp": 0, "gloss@target": 0, "ref@target": 0}
for d in ids:
    i = pos[d]
    chunk = text[order[i][1]: order[i + 1][1] if i + 1 < len(order) else len(text)]
    p = len(re.findall(r'<persName\b[^>]*\bcorresp=', chunk))
    g = len(re.findall(r'<gloss\b[^>]*\btarget=', chunk))
    r = len(re.findall(r'<ref\b[^>]*\btarget=', chunk))
    totals["persName@corresp"] += p
    totals["gloss@target"] += g
    totals["ref@target"] += r
    print(f"  {d}: persName@corresp {p}, gloss@target {g}, ref@target {r}")
print("  totals", totals)
