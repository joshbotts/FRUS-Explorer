#!/usr/bin/env python3
# One TEI parse pass over the manifest's volumes, timed per file.
# argv: <volumes dir> <manifest.json> <out.tsv>
# Per file: xml.etree.ElementTree.parse (the whole tree, as an agent's script usually does), then a
# walk that attributes each text node to its innermost <div type="document"> and, inside it, to the
# outermost <note> it sits in (type="source" kept apart from every other note). Text surface: the
# text nodes of each bucket in document order, joined with no separator, whitespace runs collapsed
# to one space, stripped. Positive controls for the parse: <graphic> whose parent is <figure>, and
# <graphic> whose parent is <surface> (the page scans), against the counts on record.
import json, os, re, resource, sys, time
import xml.etree.ElementTree as ET

TEI = "{http://www.tei-c.org/ns/1.0}"
FRUS = "{http://history.state.gov/frus/ns/1.0}"
DIV, NOTE, FIGURE, SURFACE, GRAPHIC = (TEI + t for t in ("div", "note", "figure", "surface", "graphic"))
WS = re.compile(r"\s+")
KEYS = ["docs", "hist", "edn", "other_sub", "dated", "figure_graphics", "surface_graphics",
        "body_chars", "source_chars", "note_chars", "notes", "source_notes"]

def collapsed_len(parts):
    return len(WS.sub(" ", "".join(parts)).strip())

def walk(root):
    c = dict.fromkeys(KEYS, 0)

    def visit(el, parent_tag, buckets, idx):
        tag = el.tag
        if tag == GRAPHIC:
            if parent_tag == FIGURE: c["figure_graphics"] += 1
            elif parent_tag == SURFACE: c["surface_graphics"] += 1
        is_doc = tag == DIV and el.get("type") == "document"
        if is_doc:
            c["docs"] += 1
            st = el.get("subtype")
            if st == "historical-document": c["hist"] += 1
            elif st == "editorial-note": c["edn"] += 1
            else: c["other_sub"] += 1
            if el.get(FRUS + "doc-dateTime-min"): c["dated"] += 1
            buckets, idx = [[], [], []], 0          # a nested document keeps its own text
        elif tag == NOTE and buckets is not None and idx == 0:
            if el.get("type") == "source":
                idx = 1; c["source_notes"] += 1
            else:
                idx = 2; c["notes"] += 1
        if buckets is not None and el.text:
            buckets[idx].append(el.text)
        for ch in el:
            visit(ch, tag, buckets, idx)
            if buckets is not None and ch.tail:     # a child's tail is this element's text
                buckets[idx].append(ch.tail)
        if is_doc:
            c["body_chars"] += collapsed_len(buckets[0])
            c["source_chars"] += collapsed_len(buckets[1])
            c["note_chars"] += collapsed_len(buckets[2])

    visit(root, None, None, 0)
    return c

def main():
    vol_dir, manifest_path, out_tsv = sys.argv[1:4]
    files = [v["filename"] for v in json.load(open(manifest_path))]
    cols = ["filename", "bytes", "parse_wall", "parse_cpu", "walk_wall"] + KEYS + ["maxrss_after"]
    start_wall, start_cpu = time.perf_counter(), time.process_time()
    print("start", time.strftime("%Y-%m-%d %H:%M:%S"), "load", os.getloadavg(), flush=True)
    with open(out_tsv, "w") as out:
        out.write("\t".join(cols) + "\n")
        for i, name in enumerate(files):
            path = os.path.join(vol_dir, name)
            size = os.path.getsize(path)
            w0, c0 = time.perf_counter(), time.process_time()
            tree = ET.parse(path)
            w1, c1 = time.perf_counter(), time.process_time()
            r = walk(tree.getroot())
            w2 = time.perf_counter()
            del tree
            rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
            row = [name, size, f"{w1 - w0:.4f}", f"{c1 - c0:.4f}", f"{w2 - w1:.4f}"] + \
                  [r[k] for k in KEYS] + [rss]
            out.write("\t".join(str(x) for x in row) + "\n"); out.flush()
            if i % 50 == 0:
                print(i, name, f"{time.perf_counter() - start_wall:.1f}s", flush=True)
    print("end", time.strftime("%Y-%m-%d %H:%M:%S"), "load", os.getloadavg(),
          f"wall {time.perf_counter() - start_wall:.1f}s cpu {time.process_time() - start_cpu:.1f}s",
          "maxrss", resource.getrusage(resource.RUSAGE_SELF).ru_maxrss, flush=True)

main()
