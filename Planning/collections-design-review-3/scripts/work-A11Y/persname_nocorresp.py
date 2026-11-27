# Over the manifest's 553 volumes, inside the documents' part: <persName> with and without @corresp, and <gloss>
# without @target (the serializer writes a link with no target as href="#": FRUSRenderNodeHTMLSerializer.swift:896, :901).
import json, re, sys
repo, corpus = sys.argv[1], sys.argv[2]
files = [v["filename"] for v in json.load(open(f"{repo}/FRUSExplorer/Resources/manifest.json"))]
doc_start = re.compile(r'<div\b[^>]*\btype="document"')
tag = re.compile(r'<(persName|gloss)\b([^>]*)>')
c = {"persName with corresp": 0, "persName without corresp": 0, "gloss with target": 0, "gloss without target": 0}
for name in files:
    try:
        t = open(f"{corpus}/{name}", encoding="utf-8").read()
    except FileNotFoundError:
        continue
    m = doc_start.search(t)
    if not m:
        continue
    for el, attrs in tag.findall(t, m.start()):
        if el == "persName":
            c["persName with corresp" if "corresp=" in attrs else "persName without corresp"] += 1
        else:
            c["gloss with target" if "target=" in attrs else "gloss without target"] += 1
print(c)
