# Over the manifest's 553 volumes: links the web page writes inside documents, by the element they come from.
# persName@corresp -> frusexplorer://person/, gloss@target -> frusexplorer://gloss/, ref@target -> frusexplorer://doc/
# (a ref to a footnote is drawn as a marker, not a link, so refs are an upper bound). Stdlib, regex.
import json, re, sys
repo, corpus = sys.argv[1], sys.argv[2]
files = [v["filename"] for v in json.load(open(f"{repo}/FRUSExplorer/Resources/manifest.json"))]
doc_start = re.compile(r'<div\b[^>]*\btype="document"')
pat = {k: re.compile(p) for k, p in {
    "person": r'<persName\b[^>]*\bcorresp=', "gloss": r'<gloss\b[^>]*\btarget=', "ref": r'<ref\b[^>]*\btarget='}.items()}
tot = {k: 0 for k in pat}; vols = {k: 0 for k in pat}
for name in files:
    try:
        t = open(f"{corpus}/{name}", encoding="utf-8").read()
    except FileNotFoundError:
        continue
    m = doc_start.search(t)
    if not m:
        continue
    body = t[m.start():]
    for k, p in pat.items():
        n = len(p.findall(body))
        tot[k] += n
        vols[k] += n > 0
print("links inside the documents' part of each volume:", tot, "volumes with any:", vols)
