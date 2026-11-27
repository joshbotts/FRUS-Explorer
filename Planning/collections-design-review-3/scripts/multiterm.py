# Items of a volume's term list that hold more than one <term xml:id>, and the document-term pairs that
# link each kind of id. Stdlib only. Usage: python3 -I multiterm.py <volumes-dir> <manifest.json>
import sys, os, json, collections
import xml.etree.ElementTree as ET
TEI='{http://www.tei-c.org/ns/1.0}'; XMLID='{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest = sys.argv[1], sys.argv[2]
_m=json.load(open(manifest)); cat = {v.get('id') or v.get('volumeId') for v in (_m if isinstance(_m,list) else _m['volumes'])}
def is_doc(d): return d.tag==TEI+'div' and (d.get('type')=='document' or d.get('subtype')=='editorial-note')
def terms_section(div):
    i=(div.get(XMLID) or '').lower(); t=(div.get('type') or '').lower()
    return i in ('terms','abbreviations','listofabbreviations') or t in ('terms','abbreviations','listofabbreviations')
tot=collections.Counter(); vols=collections.Counter(); ex=[]
for fn in sorted(os.listdir(vdir)):
    if not fn.endswith('.xml'): continue
    vol=fn[:-4]
    if cat is not None and vol not in cat: continue
    root=ET.parse(os.path.join(vdir,fn)).getroot()
    dropped=set(); misworded=set()
    for div in root.iter(TEI+'div'):
        if not terms_section(div): continue
        for item in div.iter(TEI+'item'):
            ids=[t.get(XMLID) for t in item.findall('.//'+TEI+'term') if t.get(XMLID)]
            # only the item's own terms, not a nested list's
            if any(ch.tag==TEI+'list' for ch in item.iter() if ch is not item): continue
            if len(ids)>1:
                tot['items']+=1
                dropped.update(ids[:-1]); misworded.add(ids[-1])
                if len(ex)<4: ex.append((vol, ids, ' '.join(''.join(item.itertext()).split())[:80]))
    if not dropped: continue
    for d in root.iter(TEI+'div'):
        if not is_doc(d): continue
        refs={g.get('target').split('#')[-1] for g in d.iter(TEI+'gloss') if g.get('target')}
        nd=len(refs & dropped); nm=len(refs & misworded)
        if nd or nm: vols[vol]+=nd+nm
        tot['dropped_pairs']+=nd; tot['misworded_pairs']+=nm
print(dict(tot), 'volumes with such pairs:', len(vols)); print(vols.most_common(6)); print(ex)
