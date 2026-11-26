"""Skeptic A: per-document counts over the manifest's volumes, with ElementTree.

For each <div type="document">:
  - does it hold a frus:attachment with a <head>?        (A11Y-7)
  - does it hold a <table>?                               (A11Y-8)
  - does it hold a <figure> with a <graphic>?             (A11Y-8)
  - how many <persName> with / without @corresp or @ref,
    and <gloss> with @target, does it hold?               (A11Y-10, inside documents only)

Usage: python3 -I doc_parts.py <volumes_dir> <manifest.json>
"""
import json
import sys
import xml.etree.ElementTree as ET

TEI = "{http://www.tei-c.org/ns/1.0}"
FRUS = "{http://history.state.gov/frus/ns/1.0}"


def main():
    vols_dir, manifest = sys.argv[1], sys.argv[2]
    vols = json.load(open(manifest))
    c = dict(docs=0, att_head=0, att_head_vols=0, table=0, table_vols=0, fig=0, fig_vols=0,
             pers_ref=0, pers_noref=0, gloss_target=0)
    for v in vols:
        path = f"{vols_dir}/{v['filename']}"
        a = t = f = 0
        for _, el in ET.iterparse(path, events=("end",)):
            if el.tag != TEI + "div" or el.get("type") != "document":
                continue
            c["docs"] += 1
            has_att = any(att.find(TEI + "head") is not None for att in el.iter(FRUS + "attachment"))
            if has_att:
                c["att_head"] += 1
                a += 1
            if el.find(".//" + TEI + "table") is not None:
                c["table"] += 1
                t += 1
            if any(fig.find(".//" + TEI + "graphic") is not None for fig in el.iter(TEI + "figure")):
                c["fig"] += 1
                f += 1
            for p in el.iter(TEI + "persName"):
                if p.get("corresp") or p.get("ref"):
                    c["pers_ref"] += 1
                else:
                    c["pers_noref"] += 1
            for g in el.iter(TEI + "gloss"):
                if g.get("target"):
                    c["gloss_target"] += 1
            el.clear()
        c["att_head_vols"] += a > 0
        c["table_vols"] += t > 0
        c["fig_vols"] += f > 0
    print(json.dumps(c))


if __name__ == "__main__":
    main()
