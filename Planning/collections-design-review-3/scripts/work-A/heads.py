"""Skeptic A: count document headings that repeat inside a volume.

For each <div type="document"> (TEI namespace), take its first direct-child <head>,
drop any <note> inside it (keeping the note's tail), collapse whitespace, and count
how many documents share that exact text with another document of the same volume.
Two counts: as the heading reads (number kept), and with a leading "N." / "No. N" removed.

Usage: python3 -I heads.py <volumes_dir> <manifest.json> [volume_id ...]
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter

TEI = "{http://www.tei-c.org/ns/1.0}"


def text_without_notes(el):
    parts = []
    if el.text:
        parts.append(el.text)
    for child in el:
        if child.tag == TEI + "note":
            pass
        else:
            parts.append(text_without_notes(child))
        if child.tail:
            parts.append(child.tail)
    return "".join(parts)


LEAD = re.compile(r"^(No\.\s*)?\d+[A-Za-z]?\.\s+")


def volume_heads(path):
    heads = []
    for _, el in ET.iterparse(path, events=("end",)):
        if el.tag == TEI + "div" and el.get("type") == "document":
            head = el.find(TEI + "head")
            if head is not None:
                t = " ".join(text_without_notes(head).split())
                if t:
                    heads.append(t)
            el.clear()
    return heads


def main():
    vols_dir, manifest = sys.argv[1], sys.argv[2]
    only = set(sys.argv[3:])
    vols = json.load(open(manifest))
    tot = {"before1952": [0, 0, 0], "from1952": [0, 0, 0]}
    for v in vols:
        fn = v["filename"]
        vid = fn[:-4]
        if only and vid not in only:
            continue
        heads = volume_heads(f"{vols_dir}/{fn}")
        c = Counter(heads)
        c2 = Counter(LEAD.sub("", h) for h in heads)
        shared = sum(n for n in c.values() if n > 1)
        shared2 = sum(n for n in c2.values() if n > 1)
        m = re.match(r"frus(\d{4})", vid)
        year = int(m.group(1)) if m else 9999
        key = "before1952" if year < 1952 else "from1952"
        tot[key][0] += len(heads)
        tot[key][1] += shared
        tot[key][2] += shared2
        if only:
            print(vid, "docs with head", len(heads), "shared as read", shared,
                  "shared without number", shared2, "commonest", c.most_common(2))
    print(json.dumps(tot))


if __name__ == "__main__":
    main()
