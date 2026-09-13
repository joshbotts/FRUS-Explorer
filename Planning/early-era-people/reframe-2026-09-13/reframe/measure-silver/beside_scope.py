#!/usr/bin/env python3
"""Task 1, beside the scope. What the 81 persons rows of frus1941-43 are keyed on in the TEI (no persName xml:id by the
TEI rule), and what element carries the corresp attributes in frus1914/frus1915/frus1916. Read-only."""
import re, json, collections
V="/Users/jbotts/Development/frus/volumes"; out={}
t=open(f"{V}/frus1941-43.xml",encoding="utf-8").read()
out["frus1941-43"]={"persName_xml_id":len(re.findall(r'<persName\b[^>]*xml:id=',t)),
  "any_xml_id_p_":len(re.findall(r'xml:id="p_',t)),
  "elements_with_xml_id_p_":dict(collections.Counter(re.findall(r'<(\w+)\b[^>]*xml:id="p_',t))),
  "corresp_or_ref_hash_p_":len(re.findall(r'(?:corresp|ref|target)="#p_',t)),
  "persName_total":len(re.findall(r'<persName\b',t)),
  "sample_list_item":(re.search(r'<item\b[^>]*>.{0,300}',t,re.S).group(0)[:300] if re.search(r'<item\b',t) else None)}
for v in ("frus1914","frus1915","frus1916"):
    t=open(f"{V}/{v}.xml",encoding="utf-8").read()
    els=collections.Counter(m.group(1) for m in re.finditer(r'<(\w+)\b[^>]*\bcorresp="',t))
    ex=[m.group(0)[:160] for m in re.finditer(r'<\w+\b[^>]*\bcorresp="[^"]*"[^>]*>',t)][:5]
    out[v]={"corresp_by_element":dict(els),"examples":ex}
json.dump(out,open("beside-scope.json","w"),indent=1)
print(json.dumps(out,indent=1))
