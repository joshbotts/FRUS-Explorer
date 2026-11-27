"""Count <gloss> elements inside documents whose @target (or @ref) holds more than one pointer,
and the document-target pairs they make. Read-only over the TEI.
Usage: python3 -I multi_target_glosses.py /path/to/volumes"""
import os, sys
import xml.etree.ElementTree as ET
TEI = "{http://www.tei-c.org/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
glosses, pairs, vols, samples = 0, set(), {}, []
for n in sorted(os.listdir(sys.argv[1])):
    if not n.endswith(".xml"): continue
    stack = []
    for ev, el in ET.iterparse(os.path.join(sys.argv[1], n), events=("start", "end")):
        if ev == "start":
            if el.tag == TEI + "div":
                if (el.get("type") or "") == "document" and el.get(XMLID): stack.append(el.get(XMLID))
                else: stack.append(stack[-1] if stack else None)
            elif el.tag == TEI + "gloss" and stack and stack[-1]:
                raw = el.get("target") if el.get("target") is not None else (el.get("ref") or "")
                parts = raw.split()
                if len(parts) > 1:
                    glosses += 1
                    pairs.add((n[:-4], stack[-1], raw))
                    vols[n[:-4]] = vols.get(n[:-4], 0) + 1
                    if len(samples) < 4: samples.append((n[:-4], stack[-1], raw))
        else:
            if el.tag == TEI + "div": stack.pop()
            el.clear()
print("multi-pointer glosses in documents:", glosses, "distinct (volume, document, target):", len(pairs),
      "volumes:", len(vols))
print("top volumes:", sorted(vols.items(), key=lambda t: -t[1])[:8])
print("samples:", samples)
