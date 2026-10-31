# slice_check.py: reproduce the topic slice (711), its pointed-at rows (392 on 200) and the unit tallies; M6 counts.
import sqlite3, csv, collections, re
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f5/"
c = sqlite3.connect(DB, uri=True)
csv.field_size_limit(10**9)
SCOPE = open(RUN + "h.py").read().split('SCOPE = """')[1].split('"""')[0].split()
rows = list(csv.DictReader(open(RUN + "scan_docs.tsv"), delimiter='\t'))
print("scan_docs rows:", len(rows), "scope rows:", sum(1 for r in rows if r['volume_id'] in SCOPE), "functional rows:", sum(1 for r in rows if r['volume_id'] not in SCOPE))
sc = [r for r in rows if r['volume_id'] in SCOPE]
print("M5: A>=1:", sum(1 for r in sc if int(r['A']) >= 1), "A>=2:", sum(1 for r in sc if int(r['A']) >= 2), "Adistinct>=2:", sum(1 for r in sc if int(r['Adistinct']) >= 2), "(claimed 4,085 / 1,482 / 622)")
fn = [r for r in rows if r['volume_id'] not in SCOPE]
print("    functional A>=1:", sum(1 for r in fn if int(r['A']) >= 1), "of", len(fn), "(claimed 913 of 5,117)")
print("M6: scan rows with A>=2 and R>=2 (all 97 volumes):", sum(1 for r in rows if int(r['A']) >= 2 and int(r['R']) >= 2), "(claimed 1,608)")
bh = [l.rstrip('\n').split('\t') for l in open(RUN + "beliefs_hits.tsv")]
print("    beliefs_hits rows:", len(bh), "(claimed 381)")
asian = [r for r in bh if re.search(r"\b(Asians?|Orientals?|face)\b", r[6], re.I)]
print("    naming Asian(s)/Oriental(s)/face:", len(asian), "(claimed 145)", "with effect word:", sum(1 for r in asian if int(r[5]) >= 1), "(claimed 33)")

slice_docs = {(r['volume_id'], r['document_id']) for r in sc if int(r['Adistinct']) >= 2 and int(r['R']) >= 2}
print("topic slice from the 77 volumes (Adistinct>=2 & R>=2):", len(slice_docs))
pub = {}
for l in open(RUN + "pubdip_scan.tsv"):
    f = l.rstrip('\n').split('\t'); pub[(f[0], f[1])] = (int(f[3]), int(f[4]))
pubsel = {k for k, (R, hR) in pub.items() if R >= 8 or hR >= 1}
print("PubDip selected (R>=8 or hR>=1):", len(pubsel), "of", len(pub), "(claimed 114 of 509)")
print("  d99 in the PubDip selection:", ("frus1917-72PubDipv08", "d99") in pubsel, " d104 in the 77-volume slice:", ("frus1977-80v22", "d104") in slice_docs)
slice_all = slice_docs | pubsel
print("TOPIC SLICE total (711 claimed):", len(slice_all))
vols = sorted({v for v, _ in slice_all})
ph = ",".join("?" * len(vols))
ec = c.execute(f"SELECT volume_id, document_id, repository, collection, lot_file_norm FROM external_citations WHERE volume_id IN ({ph})", vols).fetchall()
ec = [r for r in ec if (r[0], r[1]) in slice_all]
print("external_citations rows on slice documents (392 claimed):", len(ec), "on documents (200 claimed):", len({(r[0], r[1]) for r in ec}))
anch = collections.Counter((r[2], r[3], r[4]) for r in ec)
docsby = collections.defaultdict(set)
for r in ec: docsby[(r[2], r[3], r[4])].add((r[0], r[1]))
print("by anchors (top 12):")
for k, n in anch.most_common(12): print(f"   {n:4d} / {len(docsby[k]):3d} docs  {k}")
print("check the overview's figures: State no lot 181:", anch[('Department of State', None, None)], "| Nixon NSC 33:", anch[('Nixon Presidential Materials', 'NSC Files', None)], "| 66D95 24:", anch[('Department of State', None, '66D95')], "| Johnson NSF 19:", anch[('Johnson Library', 'National Security File', None)], "| 63D351 12:", anch[('Department of State', None, '63D351')], "| Kennedy NSF 9:", anch[('Kennedy Library', 'National Security Files', None)], "| 62D430 9:", anch[('Department of State', None, '62D430')], "| 62D1 8:", anch[('Department of State', None, '62D1')])
print("earliest document date among external_citations rows (house figure 1910-12-06):", c.execute("SELECT MIN(dd.date_iso) FROM external_citations e JOIN document_dates dd ON dd.volume_id=e.volume_id AND dd.document_id=e.document_id WHERE dd.date_iso<>''").fetchone())
