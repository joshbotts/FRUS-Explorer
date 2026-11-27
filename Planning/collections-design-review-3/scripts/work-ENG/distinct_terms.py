# Counts distinct word forms (lowercased, letters only, length >= 3) in the text of chosen
# documents of a FRUS volume, notes excluded, as a rough stand-in for the word cloud's count
# (the app lemmatises and drops stopwords, so its distinct count is lower; minimumCount = 1).
import sys, re, xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XML = '{http://www.w3.org/XML/1998/namespace}'
path, ids = sys.argv[1], sys.argv[2]
wanted = None if ids == 'first52' else set(ids.split(','))
root = ET.parse(path).getroot()
def text_without_notes(el):
    out = []
    def walk(e):
        if e.tag == TEI + 'note':
            if e.tail: out.append(e.tail)
            return
        if e.text: out.append(e.text)
        for c in e: walk(c)
        if e.tail: out.append(e.tail)
    if el.text: out.append(el.text)
    for c in el: walk(c)
    return ' '.join(out)
docs = [d for d in root.iter(TEI + 'div') if d.get('type') == 'document']
if wanted is None:
    docs = docs[:52]
else:
    docs = [d for d in docs if d.get(XML + 'id') in wanted]
counts = {}
tokens = 0
for d in docs:
    for w in re.findall(r"[A-Za-z]+", text_without_notes(d)):
        if len(w) < 3: continue
        w = w.lower(); tokens += 1
        counts[w] = counts.get(w, 0) + 1
print(f"{len(docs)} documents, {tokens} tokens, {len(counts)} distinct forms, "
      f"{sum(1 for v in counts.values() if v == 1)} seen once, {sum(1 for v in counts.values() if v >= 2)} seen twice or more")
