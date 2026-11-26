# Over the manifest's 553 volumes: documents whose heading's words (notes removed, numbers kept) are the same
# as another document's in the same volume. Under "the volume's heading leads" such documents are headings
# with the same words, and regions named the same. Stdlib, regex: the first <head> after each document's start.
import json, re, sys
from collections import Counter

repo, corpus = sys.argv[1], sys.argv[2]
vols = json.load(open(f"{repo}/FRUSExplorer/Resources/manifest.json"))
doc_start = re.compile(r'<div\b[^>]*\btype="document"[^>]*>')
head_re = re.compile(r'<head\b[^>]*>(.*?)</head>', re.S)
note_re = re.compile(r'<note\b.*?</note>', re.S)
tag_re = re.compile(r'<[^>]+>')
ws = re.compile(r'\s+')

docs = dup_docs = 0
vols_with = 0
by_era = Counter(); docs_by_era = Counter()
example = None
for v in vols:
    name = v["filename"]
    try:
        t = open(f"{corpus}/{name}", encoding="utf-8").read()
    except FileNotFoundError:
        continue
    starts = [m.end() for m in doc_start.finditer(t)]
    heads = []
    for i, s in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(t)
        m = head_re.search(t, s, min(end, s + 20000))
        if not m:
            continue
        words = ws.sub(" ", tag_re.sub("", note_re.sub("", m.group(1)))).strip()
        if words:
            heads.append(words)
    c = Counter(heads)
    d = sum(n for n in c.values() if n > 1)
    year = re.match(r'frus(\d{4})', name)
    era = "before 1952" if year and int(year.group(1)) < 1952 else "1952 on"
    docs += len(heads); dup_docs += d; vols_with += d > 0
    by_era[era] += d; docs_by_era[era] += len(heads)
    if name == "frus1946v06.xml":
        example = c.most_common(3)
print(f"documents with a heading: {docs}; sharing their heading's words with another in the volume: {dup_docs} "
      f"({dup_docs / docs:.1%}) in {vols_with} volumes")
for era in ("before 1952", "1952 on"):
    print(f"  {era}: {by_era[era]} of {docs_by_era[era]} ({by_era[era] / max(1, docs_by_era[era]):.1%})")
print("frus1946v06's commonest headings:", example)
