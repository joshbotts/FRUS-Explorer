#!/usr/bin/env python3
# Every figure in Planning/Editors-Annotations-Design-2026-11-06.md, from the three committed
# extracts beside this script (2026-11-06).
# argv: <inventory.json> <index-extract.json> <index-extract-v72.json> <note-marking-gap.json>
#       <manifest.json> <out.csv>     (stdout → tables.out)
# inventory.json comes from inventory.py over the TEI; index-extract.json from index_extract.py
# over a copy of the app's index at version 71; index-extract-v72.json from the same script over
# a full index at version 72 (#1853); note-marking-gap.json from note_marking_gap.py over that
# index. Nothing here reads the corpus or an index itself, so the tables can be re-made from the
# repository alone.
#
# Bases. "Documents" are the TEI's <div type="document"> elements inside <body> (314,510) unless a
# line says "index rows" (document_cache rows outside front matter, 320,646, which also counts a
# section's own printed text). A volume CARRIES a pervasive category when at least half its
# documents do; a counted category (cross-references, excisions, editorial notes, Subject lines,
# participant lists, marginal notes) when one document does; a section when the volume prints it.
# Classification is the marking the index stores at version 72 (the source note's, else the
# opener's), counted in index rows; inventory.json's word search is kept only as §7's comparison.
# Era bands are keyed by the subseries' FIRST year, not the manifest's earliest date, which
# reaches back to enclosures centuries older than the volume. The nine late retrospective
# volumes (Public Diplomacy, the two Intelligence volumes, Iran and its second edition, Guatemala)
# are their own band, since their editors worked in the modern format whatever the era covered.
import csv, json, re, statistics, sys, collections

INV, IDX, IDX72, GAP, MANIFEST, OUT_CSV = sys.argv[1:7]
inv = json.load(open(INV))
idx = json.load(open(IDX))["volumes"]
ext72 = json.load(open(IDX72))
idx72, values72 = ext72["volumes"], ext72["values"]
gapx = json.load(open(GAP))
man = {v["volumeId"]: v for v in json.load(open(MANIFEST))}
# inventory.py's word search, copied, to count the stored values its vocabulary cannot match.
CLASSIF = re.compile(r"\b(top secret|secret|confidential|limited official use|unclassified|"
                     r"eyes only|nodis|exdis|limdis|strictly confidential)\b", re.I)

BANDS = [(1861, 1898), (1899, 1913), (1914, 1919), (1920, 1931), (1932, 1944), (1945, 1950),
         (1951, 1954), (1955, 1968), (1969, 1980), (1981, 1992)]
B = [f"{lo}-{hi}" for lo, hi in BANDS] + ["retro"]
PUBS = [(1861, 1899), (1900, 1919), (1920, 1939), (1940, 1949), (1950, 1959), (1960, 1969),
        (1970, 1979), (1980, 1984), (1985, 1989), (1990, 1999), (2000, 2026)]
P = [f"{lo}-{hi}" for lo, hi in PUBS]
RETRO = re.compile(r"PubDip|Intel$|Iran|Guat$")

def start(v): return int(man[v]["subseries"][:4])
def pub(v):
    m = re.search(r"\d{4}", man[v].get("publicationDate") or "")
    return int(m.group()) if m else None
def band(v):
    if RETRO.search(v): return "retro"
    y = start(v)
    for lo, hi in BANDS:
        if lo <= y <= hi: return f"{lo}-{hi}"
    raise ValueError(v)
def pbin(v):
    y = pub(v)
    for lo, hi in PUBS:
        if lo <= y <= hi: return f"{lo}-{hi}"
    raise ValueError(v)

def docs(v): return inv[v]["vol"]["docs_body"]
def feat(v, k): return inv[v]["feat"].get(k, 0)
def disc(v, k): return inv[v]["disc"].get(k, 0)
def sections(v): return inv[v]["sections"]
def has_section(v, *names):
    for region, typ, sub, xid, head in sections(v):
        if sub in names or xid.lower() in names: return True
    return False
def people_docs(v):          # inline links, or the document-level @ana one volume uses instead
    return feat(v, "pers_linked") or feat(v, "ana_persons")

# (id, label, family, documents carrying it per volume, does the volume carry it)
half = lambda f: (lambda v: f(v) >= 0.5 * max(docs(v), 1))
anyd = lambda f: (lambda v: f(v) > 0)
CATS = [
    ("people", "People tagged", "named", people_docs, half(people_docs)),
    ("abbreviations", "Abbreviations explained", "named", lambda v: feat(v, "terms_linked"),
     half(lambda v: feat(v, "terms_linked"))),
    ("correspondents", "Senders and recipients marked", "named", lambda v: feat(v, "from_to"),
     half(lambda v: feat(v, "from_to"))),
    ("subjects", "Subject lines", "named", lambda v: disc(v, "list@type=subject"),
     anyd(lambda v: disc(v, "list@type=subject"))),
    ("participants", "Meeting participants", "named", lambda v: disc(v, "list@type=participants"),
     anyd(lambda v: disc(v, "list@type=participants"))),
    ("source-notes", "Source notes (either form)", "provenance", lambda v: feat(v, "source_note"),
     half(lambda v: feat(v, "source_note"))),
    ("source-file-number", " file-number form", "provenance", lambda v: feat(v, "source_note_inline"),
     half(lambda v: feat(v, "source_note_inline"))),
    ("source-citation", " \"Source:\" form", "provenance", lambda v: feat(v, "source_note_footnote"),
     half(lambda v: feat(v, "source_note_footnote"))),
    ("classification", "Classification stored (rows)", "provenance", lambda v: idx72[v]["classified"],
     lambda v: idx72[v]["classified"] >= 0.5 * max(idx72[v]["docs"], 1)),
    ("excisions", "Excisions marked", "provenance", lambda v: feat(v, "not_declassified"),
     anyd(lambda v: feat(v, "not_declassified"))),
    ("despatch", "Despatch numbers (>=10% rows)", "provenance", lambda v: idx[v]["despatch"],
     lambda v: idx[v]["despatch"] >= 0.1 * max(idx[v]["docs"], 1)),
    ("numbered", "Numbered in print (index rows)", "connects", lambda v: idx[v]["numbered"],
     lambda v: idx[v]["numbered"] >= 0.5 * max(idx[v]["docs"], 1)),
    ("xref-documents", "Cross-refs to documents", "connects", lambda v: feat(v, "xref_doc"),
     anyd(lambda v: feat(v, "xref_doc"))),
    ("xref-footnotes", "Cross-refs to footnotes", "connects", lambda v: feat(v, "xref_footnote"),
     anyd(lambda v: feat(v, "xref_footnote"))),
    ("xref-volumes", "Cross-refs to other volumes", "connects", lambda v: feat(v, "xref_other-volume"),
     anyd(lambda v: feat(v, "xref_other-volume"))),
    ("xref-pages", "Page references (see p.)", "connects", lambda v: feat(v, "xref_page"),
     anyd(lambda v: feat(v, "xref_page"))),
    ("editorial-notes", "Editorial notes", "connects", lambda v: feat(v, "editorial_note"),
     lambda v: inv[v]["vol"]["edn"] > 0),
    ("footnotes", "Footnotes (>=50% docs)", "connects", lambda v: feat(v, "footnote"),
     half(lambda v: feat(v, "footnote"))),
    ("marginal-notes", "Marginal notes", "connects", lambda v: disc(v, "seg@type=margin"),
     anyd(lambda v: disc(v, "seg@type=margin"))),
    ("figures", "Figures in documents", "connects", lambda v: feat(v, "figure"),
     anyd(lambda v: feat(v, "figure"))),
]
SECTIONS = [
    ("persons-list", "List of Persons", lambda v: inv[v]["vol"]["persons_entries"] > 0),
    ("terms-list", "List of Abbreviations", lambda v: inv[v]["vol"]["terms_entries"] > 0),
    ("note-on-sources", "Note on Sources", lambda v: has_section(v, "sources")),
    ("preface", "Preface", lambda v: has_section(v, "preface")),
    ("list-of-papers", "List of Papers (analytical)",
     lambda v: any(s[3].lower().startswith(("papers", "toc-papers")) for s in sections(v))),
    ("index", "Printed index (back)",
     lambda v: any(s[0] == "back" and s[2] == "index" and s[3].lower() == "index" for s in sections(v))),
    ("covert-actions", "Note on U.S. Covert Actions", lambda v: has_section(v, "note-on-covert-actions")),
    ("press-release", "Press release", lambda v: has_section(v, "press-release")),
    ("volume-summary", "Volume summary", lambda v: has_section(v, "volume-summary")),
    ("errata", "Errata", lambda v: has_section(v, "errata")),
]

vols = sorted(man)
nB = collections.Counter(band(v) for v in vols)
nP = collections.Counter(pbin(v) for v in vols)
TD = sum(docs(v) for v in vols)
TI = sum(idx[v]["docs"] for v in vols)

def hdr(cols, w=30, cw=9, short=lambda c: c):
    return "".ljust(w) + "".join(short(c).rjust(cw) for c in cols)
def bshort(b): return "retro" if b == "retro" else b[2:4] + "-" + b[7:9]
def row(name, pred, keyf, cols, n, w=30, cw=9):
    c = collections.Counter(keyf(v) for v in vols if pred(v))
    return name[:w - 1].ljust(w) + "".join(f"{c[k]}/{n[k]}".rjust(cw) for k in cols) + f"  | {sum(c.values())}"

print("== 1. Bases")
print(f"manifest volumes {len(vols)}; TEI body documents {TD:,}; index rows outside front matter {TI:,}")
print("band sizes:", ", ".join(f"{b} {nB[b]}" for b in B))
print("retrospective band:", ", ".join(v for v in vols if band(v) == "retro"))
# The version-72 index was built by a generator, not the app: every per-volume figure but the
# classification #1853 adds must equal the app's index at 71.
same = {k: sum(1 for v in vols if idx[v][k] == idx72[v][k])
        for k in ("docs", "people_docs", "persons_rows", "numbered", "despatch")}
print("index at 72 against the app's at 71, volumes equal on each figure:",
      ", ".join(f"{k} {n}/{len(vols)}" for k, n in same.items()),
      f"| classified only grows: {all(idx72[v]['classified'] >= idx[v]['classified'] for v in vols)}")

print("\n== 2. People, by the index's rule")
tagged = [v for v in vols if idx[v]["people_docs"] > 0]
listonly = [v for v in vols if idx[v]["people_docs"] == 0 and idx[v]["persons_rows"] > 0]
print(f"tagged volumes {len(tagged)} ({sum(idx[v]['docs'] for v in tagged):,} index rows); "
      f"not tagged {len(vols) - len(tagged)} ({sum(idx[v]['docs'] for v in vols if v not in tagged):,} rows); "
      f"list but no links: {', '.join(listonly)}")
print(f"TEI rule (>=50% of documents linked, or @ana): {sum(1 for v in vols if CATS[0][4](v))} volumes")

print("\n== 3. Totals: volumes carrying each category, and documents carrying it (TEI basis)")
for cid, label, fam, dcount, pred in CATS:
    n = sum(1 for v in vols if pred(v)); d = sum(dcount(v) for v in vols)
    basis = "index rows" if cid in ("numbered", "despatch", "classification") else "docs"
    tot = TI if basis == "index rows" else TD
    print(f"{label:34} {n:4} volumes   {d:8,} {basis} ({100 * d / tot:.1f}%)")
for sid, label, pred in SECTIONS:
    print(f"{label:34} {sum(1 for v in vols if pred(v)):4} volumes")
# frus1870 encodes its despatch numbers ("No. 3.") as <note type="source">: 302 notes, every one
# "unrecognized" in source-provenance-index.json. It is no archival source note, so the
# design's figure for source notes (and for the file-number form) leaves it out.
fake = [v for v in vols if CATS[5][4](v) and start(v) < 1906]
fake_docs = sum(feat(v, "source_note_inline") for v in fake)
fn_docs = sum(feat(v, "source_note_inline") for v in vols) - fake_docs
fake_text = ", ".join("%s (%d of %d documents)" % (v, feat(v, "source_note"), docs(v)) for v in fake)
print(f"source notes before 1906 (element present in >=50% of documents): {fake_text}; "
      f"without them: {sum(1 for v in vols if CATS[5][4](v)) - len(fake)} volumes; "
      f"file-number form {sum(1 for v in vols if CATS[6][4](v)) - len(fake)} volumes, "
      f"{fn_docs:,} docs ({100 * fn_docs / TD:.1f}%)")
print(f"Note on Sources by @subtype alone: {sum(1 for v in vols if any(s[2] == 'sources' for s in sections(v)))} "
      f"volumes (by the parser's rule, @subtype else @xml:id: {sum(1 for v in vols if SECTIONS[2][2](v))})")
print(f"page breaks with a printed number: {sum(1 for v in vols if inv[v]['vol']['pb'] > 0)} volumes; "
      f"with a page scan (@facs or <surface>): "
      f"{sum(1 for v in vols if inv[v]['vol']['pb_facs'] > 0 or inv[v]['vol']['surfaces'] > 0)} volumes")
oldest = min(vols, key=lambda v: man[v]["dateRange"]["earliest"])
print(f"the manifest's earliest date, at its oldest: {oldest} {man[oldest]['dateRange']['earliest'][:10]} "
      f"(subseries {man[oldest]['subseries']})")

print("\n== 4. Volumes carrying each category, by era covered (subseries' first year)")
print(hdr(B, short=bshort))
for cid, label, fam, dcount, pred in CATS:
    print(row(label, pred, band, B, nB))
for sid, label, pred in SECTIONS:
    print(row(label, pred, band, B, nB))

print("\n== 5. The same, by publication year")
print(hdr(P, short=lambda p: p[2:4] + "-" + p[7:9]))
for cid, label, fam, dcount, pred in CATS:
    print(row(label, pred, pbin, P, nP))
for sid, label, pred in SECTIONS:
    print(row(label, pred, pbin, P, nP))

print("\n== 6. Exceptions inside the modern format (subseries from 1955, and the retrospectives)")
modern = [v for v in vols if band(v) in ("1955-1968", "1969-1980", "1981-1992", "retro")]
for cid, label, fam, dcount, pred in CATS:
    if cid in ("people", "abbreviations", "source-citation", "numbered", "classification", "subjects",
               "participants", "xref-documents"):
        miss = [v for v in modern if not pred(v)]
        print(f"{label:34} missing in {len(miss)} of {len(modern)}: {', '.join(miss)}")
for sid, label, pred in SECTIONS:
    if sid in ("persons-list", "terms-list", "note-on-sources"):
        miss = [v for v in modern if not pred(v)]
        print(f"{label:34} missing in {len(miss)} of {len(modern)}: {', '.join(miss)}")
early_terms = [v for v in vols if inv[v]["vol"]["terms_entries"] > 0 and start(v) < 1945 and band(v) != "retro"]
print("abbreviation lists before 1945:", ", ".join(early_terms))

print("\n== 7. Classification markings: the word search (TEI) against what the index stores, at 71 "
      "and at 72 (#1853), by era")
CAT = {c[0]: c for c in CATS}
word = lambda v: feat(v, "classification")
print(hdr(B, short=bshort))
for name, f in (("documents (TEI)", docs), ("word search, note or opener", word),
                ("index rows", lambda v: idx[v]["docs"]),
                ("stored at 71 (app's index)", lambda v: idx[v]["classified"]),
                ("stored at 72 (#1853)", lambda v: idx72[v]["classified"])):
    agg = collections.Counter()
    for v in vols: agg[band(v)] += f(v)
    print(name[:29].ljust(30) + "".join(f"{agg[b]:,}".rjust(9) for b in B))
for name, pred in (("volumes, word search >=50%", lambda v: word(v) >= 0.5 * max(docs(v), 1)),
                   ("volumes, stored at 72 >=50%", CAT["classification"][4])):
    print(row(name, pred, band, B, nB))
gap = [v for v in vols if 1932 <= start(v) <= 1954 and band(v) != "retro"]
print(f"1932-54 (retrospectives excluded, {len(gap)} volumes): word search {sum(word(v) for v in gap):,} "
      f"documents; stored at 71 {sum(idx[v]['classified'] for v in gap):,}, at 72 "
      f"{sum(idx72[v]['classified'] for v in gap):,}; volumes at half or more: word search "
      f"{sum(1 for v in gap if word(v) >= 0.5 * docs(v))}, stored at 72 "
      f"{sum(1 for v in gap if CAT['classification'][4](v))}")
grew = [v for v in vols if idx72[v]["classified"] > idx[v]["classified"]]
print(f"all volumes: stored at 71 {sum(idx[v]['classified'] for v in vols):,}, at 72 "
      f"{sum(idx72[v]['classified'] for v in vols):,}; volumes whose stored count grew: {len(grew)}, "
      f"outside 1932-54's regular volumes: "
      + ", ".join(f"{v} +{idx72[v]['classified'] - idx[v]['classified']}" for v in grew if v not in gap))
outside = {k: n for k, n in values72.items() if not CLASSIF.search(k)}
print(f"stored at 72 with a value the word search's vocabulary cannot match: {sum(outside.values()):,} "
      f"documents, {len(outside)} of {len(values72):,} distinct values; the commonest: "
      + "; ".join(f"{k} {n:,}" for k, n in sorted(outside.items(), key=lambda kv: (-kv[1], kv[0]))[:6]))

print("\n== 8. The three example volumes")
for v in ("frus1890", "frus1952-54v13p1", "frus1969-76v17"):
    r = inv[v]
    print(v, "| documents", docs(v), "| editorial notes", r["vol"]["edn"], "| persons listed",
          r["vol"]["persons_entries"], "| terms listed", r["vol"]["terms_entries"],
          "| numbered in print", idx[v]["numbered"], "of", idx[v]["docs"], "rows",
          "| despatch numbers", idx[v]["despatch"])
    print("   ", ", ".join(f"{cid} {dcount(v)}" for cid, label, fam, dcount, pred in CATS))
    print("    sections:", "; ".join(f"{s[0]} {s[2] or s[3]} ({s[4]})" for s in sections(v)))

print("\n== 9. Discovery: markup whose mean share of documents moves 15 points or more across eras")
keys = collections.Counter()
for v in vols: keys.update(inv[v]["disc"].keys())
print(hdr(B, w=34, cw=8, short=bshort))
for k in sorted(keys):
    sh = {b: [] for b in B}
    for v in vols: sh[band(v)].append(disc(v, k) / max(docs(v), 1))
    m = [statistics.mean(sh[b]) for b in B]
    if max(m) - min(m) >= 0.15:
        print(k[:33].ljust(34) + "".join(f"{100 * x:.0f}".rjust(8) for x in m))

with open(OUT_CSV, "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["volume", "subseries", "published", "era_band", "documents", "index_rows",
                "persons_listed", "terms_listed"] + [c[0] for c in CATS] + [s[0] for s in SECTIONS])
    for v in vols:
        w.writerow([v, man[v]["subseries"], pub(v), band(v), docs(v), idx[v]["docs"],
                    inv[v]["vol"]["persons_entries"], inv[v]["vol"]["terms_entries"]]
                   + [c[3](v) for c in CATS] + [int(s[2](v)) for s in SECTIONS])
print(f"\nwrote {OUT_CSV}: {len(vols)} rows")

# ── 10. Onset: the first subseries from which every later (non-retrospective) subseries has the
# category in at least 90% of its volumes; and how close to "every document" the carriers come.
print("\n== 10. Onset, and coverage inside the volumes that carry a category")
subs = sorted({man[v]["subseries"] for v in vols if band(v) != "retro"}, key=lambda s: (int(s[:4]), s))
for cid, label, fam, dcount, pred in CATS:
    share = {}
    for s in subs:
        members = [v for v in vols if man[v]["subseries"] == s and band(v) != "retro"]
        share[s] = sum(1 for v in members if pred(v)) / len(members)
    onset = None
    for i, s in enumerate(subs):
        if all(share[t] >= 0.9 for t in subs[i:]):
            onset = s; break
    first = min((v for v in vols if pred(v) and band(v) != "retro"), key=lambda v: (start(v), v), default=None)
    carriers = [v for v in vols if pred(v)]
    if fam != "x" and cid in ("people", "abbreviations", "source-notes", "numbered", "correspondents", "footnotes"):
        denom = (lambda v: idx[v]["docs"]) if cid == "numbered" else docs
        cov = sorted(dcount(v) / max(denom(v), 1) for v in carriers)
        below = sum(1 for c in cov if c < 0.9)
        print(f"{label:34} onset {onset or '-':10} first {first or '-':22} carriers {len(carriers)}: "
              f"median {100 * statistics.median(cov):.1f}%, lowest {100 * cov[0]:.1f}%, below 90%: {below}")
    else:
        print(f"{label:34} onset {onset or '-':10} first {first or '-':22} carriers {len(carriers)}")

# ── 11. The design's onset rule, the people arithmetic, inferred dates, and the artifact's size.
print("\n== 11. Onset by era band (retrospectives excluded): the first band from which every later "
      "band has >=75% of its volumes carrying the category")
chron = [b for b in B if b != "retro"]
for cid, label, fam, dcount, pred in CATS + [(s[0], s[1], "section", None, s[2]) for s in SECTIONS]:
    share = {b: sum(1 for v in vols if band(v) == b and pred(v)) / nB[b] for b in chron}
    onset = next((b for i, b in enumerate(chron) if all(share[t] >= 0.75 for t in chron[i:])), "-")
    print(f"{label:34} {onset:10} " + " ".join(f"{100 * share[b]:.0f}" for b in chron))

tagged = {v for v in vols if idx[v]["people_docs"] > 0}
lists = {v for v in vols if inv[v]["vol"]["persons_entries"] > 0}
print(f"\npeople: {len(lists)} Lists of Persons by the section ids; tagged without such a list: "
      f"{', '.join(sorted(tagged - lists))}; listed but not tagged: {', '.join(sorted(lists - tagged))}")
lowest = min(tagged, key=lambda v: people_docs(v) / docs(v))
print(f"lowest people coverage: {lowest} {100 * people_docs(lowest) / docs(lowest):.1f}%")
inferred = sum(disc(v, "date@ana") for v in vols)
print(f"documents with a date the corpus build inferred (date@ana): {inferred:,} ({100 * inferred / TD:.1f}%)")
v27 = inv["frus1977-80v27"]["vol"]
print(f"frus1977-80v27: persons listed {v27['persons_entries']}, linked docs {feat('frus1977-80v27', 'pers_linked')}; "
      f"terms listed {v27['terms_entries']}, linked docs {feat('frus1977-80v27', 'terms_linked')}")

# The artifact's size two ways: counts keyed by name in every volume, and columnar (the names
# once, counts as arrays in that order, sections as indices into one list of section names).
names = [c[0] for c in CATS if c[0] not in ("source-notes",)]
secnames = sorted({(s[2] if s[2] and s[2] != "index" else s[3].lower()) for v in vols for s in sections(v)})
def secs(v): return sorted({(s[2] if s[2] and s[2] != "index" else s[3].lower()) for s in sections(v)})
keyed = {v: {"documents": docs(v), "lists": [inv[v]["vol"]["persons_entries"], inv[v]["vol"]["terms_entries"]],
             "counts": {c[0]: c[3](v) for c in CATS if c[0] in names}, "sections": secs(v)} for v in vols}
columnar = {"categories": names, "sections": secnames,
            "volumes": {v: [docs(v), inv[v]["vol"]["persons_entries"], inv[v]["vol"]["terms_entries"]]
                        + [c[3](v) for c in CATS if c[0] in names] + [[secnames.index(s) for s in secs(v)]]
                        for v in vols}}
print(f"artifact size: keyed {len(json.dumps(keyed, separators=(',', ':'))):,} bytes compact; "
      f"columnar {len(json.dumps(columnar, separators=(',', ':'))):,} bytes compact "
      f"({len(names)} counts a volume, {len(secnames)} section names)")

# ── 12. The markings the notes print in a sentence the note parser does not read.
print("\n== 12. Markings source notes print that the index does not store (note_marking_gap.py, index at 72)")
rep, gv = gapx["replica"], gapx["volumes"]
print(f"replica of SourceNoteParser.classificationMarking(fromSourceNote:): equals the stored value "
      f"{rep['agree']:,} times, differs {rep['disagree']}")
by_band = collections.Counter()
for v, n in gv.items(): by_band[band(v)] += n
print(f"in the gap: {sum(gv.values()):,} documents in {len(gv)} volumes; by era: "
      + ", ".join(f"{b} {by_band[b]:,}" for b in B if by_band[b]))
print("causes: " + ", ".join(f"{k} {n:,}" for k, n in sorted(gapx["causes"].items(), key=lambda kv: -kv[1])))
print("a period inside the citation, by how sentence 1 ends: " + ", ".join(
      f"{k} {n:,}" for k, n in sorted(gapx["citation_periods"].items(), key=lambda kv: -kv[1])))
ms = {v: n for v, n in gv.items() if "mSupp" in v}
print(f"the microfiche supplements: {sum(ms.values()):,} notes in the gap; by cause: "
      + ", ".join(f"{k} {n:,}" for k, n in sorted(gapx["causes_microfiche"].items(), key=lambda kv: -kv[1])))
print("most: " + ", ".join(f"{v} {n}" for v, n in sorted(gv.items(), key=lambda kv: (-kv[1], kv[0]))[:8]))
printed = lambda v: idx72[v]["classified"] + gv.get(v, 0)
carry_p = lambda v: printed(v) >= 0.5 * max(idx72[v]["docs"], 1)
print(row("volumes, stored + gap >=50%", carry_p, band, B, nB))
print("modern volumes under half, stored: " + ", ".join(v for v in modern if not CAT["classification"][4](v)))
print("modern volumes under half, stored + gap: " + ", ".join(
      f"{v} {printed(v)}/{idx72[v]['docs']}" for v in modern if not carry_p(v)))
for v in ("frus1952-54v13p1", "frus1969-76v17", "frus1917-72PubDipv06"):
    print(f"{v}: stored {idx72[v]['classified']}, gap {gv.get(v, 0)}, of {idx72[v]['docs']} rows")
share_p = {s: sum(1 for v in vols if man[v]["subseries"] == s and band(v) != "retro" and carry_p(v))
           / sum(1 for v in vols if man[v]["subseries"] == s and band(v) != "retro") for s in subs}
share_s = {s: sum(1 for v in vols if man[v]["subseries"] == s and band(v) != "retro"
                  and CAT["classification"][4](v))
           / sum(1 for v in vols if man[v]["subseries"] == s and band(v) != "retro") for s in subs}
onset90 = lambda sh: next((s for i, s in enumerate(subs) if all(sh[t] >= 0.9 for t in subs[i:])), "-")
print(f"the tighter onset (every later subseries at 90%): stored {onset90(share_s)}, stored + gap "
      f"{onset90(share_p)}; subseries under 90% from 1955, stored: "
      + ", ".join(f"{s} {100 * share_s[s]:.0f}%" for s in subs if int(s[:4]) >= 1955 and share_s[s] < 0.9))
