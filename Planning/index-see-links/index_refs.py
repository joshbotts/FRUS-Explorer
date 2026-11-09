#!/usr/bin/env python3
# A back-of-volume index's "See" links, measured for Lane 2 of
# Planning/Editors-Annotations-Followups-2026-11-08.md (2026-11-08).
# argv: <volumes dir> <manifest.json> <out.json>   (the tables go to stdout)
# Run through Scripts/heavy.sh, as the editors' annotations sweeps are: one ElementTree parse per
# manifest volume, about a minute on the M5 MacBook. Read-only; writes only <out.json>. Stdlib only.
#
# What it records, over the 553 catalogue volumes:
#   - every <ref> whose target is "#in<digits>" (this volume) or "frus…#in<digits>" (another), and
#     for each whether it sits inside an index division: a <div> whose @subtype is "index" or whose
#     xml:id begins "index", or a <list type="index">;
#   - whether the target id exists in the same volume, and inside the same division as the ref;
#   - the volumes that have such refs, and their counts;
#   - every element whose xml:id matches ^in\d+$, by tag, and whether it sits in an index division;
#   - whether any <div type="document"> has an xml:id beginning "in" followed by a digit, over
#     every document in every volume: the figure that decides whether a prefix rule is safe
#     (#988's footnote rule was measured the same way, "captures 0 of 314,571").
import json, re, sys, collections
import xml.etree.ElementTree as ET

TEI = "{http://www.tei-c.org/ns/1.0}"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
IN_ID = re.compile(r"^in\d+$")
IN_PREFIX = re.compile(r"^in\d")
TARGET = re.compile(r"^(frus[^#\s]*)?#(in\d+)$")

def local(tag):
    return tag[len(TEI):] if tag.startswith(TEI) else tag

def is_index_division(el):
    tag = local(el.tag)
    if tag == "div":
        if (el.get("subtype") or "") == "index": return True
        if (el.get(XMLID) or "").lower().startswith("index"): return True
    if tag == "list" and (el.get("type") or "") == "index": return True
    return False

def survey(path, volume_id, out_refs):
    root = ET.parse(path).getroot()
    ids = {}                      # xml:id -> (tag, in index division, division id)
    documents = 0; doc_in_prefix = []; in_ids_by_tag = collections.Counter(); in_ids_outside_index = []
    refs = []                     # (target volume or None, anchor, in index division, division id)
    div_chain = []

    def walk(el, in_index, division):
        nonlocal documents
        tag = local(el.tag)
        here_index = in_index or is_index_division(el)
        here_division = division
        if tag == "div":
            here_division = el.get(XMLID) or f"{el.get('type')}/{el.get('subtype')}"
            if (el.get("type") or "") == "document":
                documents += 1
                xid = el.get(XMLID) or ""
                if IN_PREFIX.match(xid): doc_in_prefix.append(xid)
        xid = el.get(XMLID)
        if xid:
            ids[xid] = (tag, here_index, here_division)
            if IN_ID.match(xid):
                in_ids_by_tag[tag] += 1
                if not here_index: in_ids_outside_index.append((tag, xid, here_division))
        if tag == "ref" and el.get("target"):
            for t in el.get("target").split():
                m = TARGET.match(t.strip())
                if m:
                    refs.append((m.group(1), m.group(2), here_index, here_division))
        for ch in el:
            walk(ch, here_index, here_division)

    walk(root, False, None)
    resolved = 0; same_division = 0; dangling = []; outside_index = 0; other_volume = []
    for target_volume, anchor, in_index, division in refs:
        if target_volume and target_volume != volume_id:
            other_volume.append((target_volume, anchor)); continue
        if not in_index: outside_index += 1
        hit = ids.get(anchor)
        if hit is None: dangling.append((anchor, division)); continue
        resolved += 1
        if hit[2] == division: same_division += 1
    out_refs.extend((volume_id, tv, a, ii, d) for tv, a, ii, d in refs)
    return dict(documents=documents, refs=len(refs), resolved=resolved, same_division=same_division,
                dangling=dangling[:20], dangling_count=len(dangling), outside_index=outside_index,
                other_volume=other_volume[:20], other_volume_count=len(other_volume),
                in_ids_by_tag=dict(in_ids_by_tag), in_ids_outside_index=in_ids_outside_index[:20],
                in_ids_outside_index_count=len(in_ids_outside_index), document_ids_with_in_prefix=doc_in_prefix)

def main():
    vdir, manifest, out = sys.argv[1:4]
    man = json.load(open(manifest))
    refs = []
    res = {}
    for i, v in enumerate(man):
        res[v["volumeId"]] = survey(f"{vdir}/{v['filename']}", v["volumeId"], refs)
        if i % 50 == 0: print(f"… {i} {v['volumeId']}", file=sys.stderr, flush=True)
    json.dump(res, open(out, "w"))

    vols = res
    total_docs = sum(v["documents"] for v in vols.values())
    with_refs = {k: v for k, v in vols.items() if v["refs"]}
    print(f"# \"See\" links in back-of-volume indexes, over {len(vols)} manifest volumes\n")
    print(f"- Documents (div[@type=\"document\"]) in all: {total_docs}")
    print(f"- Documents whose xml:id begins `in` + digit: "
          f"{sum(len(v['document_ids_with_in_prefix']) for v in vols.values())} "
          f"{[ (k, v['document_ids_with_in_prefix'][:5]) for k, v in vols.items() if v['document_ids_with_in_prefix']][:10]}")
    print(f"- Refs to `#in<digits>`: {sum(v['refs'] for v in vols.values())} in {len(with_refs)} volumes")
    print(f"  - inside an index division: {sum(v['refs'] - v['outside_index'] - v['other_volume_count'] for v in vols.values())}; "
          f"outside one: {sum(v['outside_index'] for v in vols.values())}")
    print(f"  - to another volume (`frus…#in…`): {sum(v['other_volume_count'] for v in vols.values())} "
          f"{[(k, v['other_volume'][:3]) for k, v in vols.items() if v['other_volume']][:10]}")
    print(f"  - target id present in the volume: {sum(v['resolved'] for v in vols.values())}; "
          f"in the same division as the ref: {sum(v['same_division'] for v in vols.values())}; "
          f"dangling: {sum(v['dangling_count'] for v in vols.values())} "
          f"{[(k, v['dangling'][:3]) for k, v in vols.items() if v['dangling']][:10]}")
    tags = collections.Counter()
    for v in vols.values(): tags.update(v["in_ids_by_tag"])
    print(f"- Elements whose xml:id matches ^in\\d+$, by tag: {dict(tags)} in "
          f"{sum(1 for v in vols.values() if v['in_ids_by_tag'])} volumes")
    print(f"  - outside an index division: {sum(v['in_ids_outside_index_count'] for v in vols.values())} "
          f"{[(k, v['in_ids_outside_index'][:3]) for k, v in vols.items() if v['in_ids_outside_index']][:10]}")
    print("\n## Volumes with the most refs\n")
    print("| Volume | refs | resolved | same division | item ids |")
    print("|---|---|---|---|---|")
    for k, v in sorted(with_refs.items(), key=lambda kv: -kv[1]["refs"])[:25]:
        print(f"| {k} | {v['refs']} | {v['resolved']} | {v['same_division']} | {v['in_ids_by_tag'].get('item', 0)} |")
    print("\n## The volumes the plan names\n")
    for k in ("frus1932v04", "frus1955-57v03", "frus1969-76v17"):
        v = vols.get(k)
        if v: print(f"- {k}: {v['refs']} refs, {v['resolved']} resolved, {v['same_division']} in the same division, item ids {v['in_ids_by_tag']}")
    print("\ndone", len(vols))

if __name__ == "__main__":
    sys.setrecursionlimit(100000)
    main()
