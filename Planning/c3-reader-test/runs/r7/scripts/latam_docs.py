# Builds out/latam_docs.tsv (every non-apparatus document under a Latin American heading or in a Latin American volume)
# and out/heading_recog_docs.tsv (the subset whose heading path names recognition). Reads volume_structures + manifest.json.
import sqlite3, json, re
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con = sqlite3.connect(DB, uri=True)
LATAM = ["argentin","bolivia","brazil","chile","colombia","costa rica","cuba","dominican","santo domingo","ecuador","salvador",
         "guatemala","haiti","hayti","honduras","mexic","nicaragua","panama","paraguay","peru","uruguay","venezuela",
         "central america","american republics","western hemisphere","latin america","south america","caribbean","inter-american","hawaiian" ]
# 'hawaiian' is deliberately listed so it can be EXCLUDED below (frus1894 Hawaiian Republic heading); it is not Latin America.
EXCL = ["hawaiian"]
m = {v["volumeId"]: v for v in json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))}
def is_latam(text):
    t = text.lower()
    if any(e in t for e in EXCL): return False
    return any(k in t for k in LATAM)
latam_vol = {vid for vid,v in m.items() if is_latam(" ".join(v["title"].split()))}
apparatus = {}
for vid, did, fm, en in con.execute("SELECT volume_id, document_id, is_front_matter, is_editorial_note FROM document_cache"):
    apparatus[(vid,did)] = (fm or en)
rows = {}
def walk(vid, secs, path):
    for s in secs:
        title = " ".join((s.get("title") or "").split())
        p = path + [title]
        pj = " > ".join(p)
        for did in s.get("documentIds") or []:
            key=(vid,did)
            if key in rows: continue  # first (outermost-first) path wins; ids are listed once per leaf in practice
            rows[key] = pj
        walk(vid, s.get("subsections") or [], p)
for vid, sj in con.execute("SELECT volume_id, structure_json FROM volume_structures"):
    walk(vid, json.loads(sj).get("sections", []), [])
out = open("/Users/jbotts/frus-analysis/c3/runs/r7/out/latam_docs.tsv","w")
outr = open("/Users/jbotts/frus-analysis/c3/runs/r7/out/heading_recog_docs.tsv","w")
n=nr=0
seen=set()
for (vid,did), pj in sorted(rows.items()):
    if apparatus.get((vid,did),1): continue
    if vid.endswith("Ed2") and vid in ("frus1951-54IranEd2","frus1969-76ve15p2Ed2"): continue
    if is_latam(pj) or vid in latam_vol:
        out.write(f"{vid}\t{did}\t{pj}\n"); n+=1; seen.add((vid,did))
        if re.search(r"recogni", pj, re.I) and is_latam(pj):
            outr.write(f"{vid}\t{did}\t{pj}\n"); nr+=1
# documents in Latin American volumes that no heading lists (structure gaps)
for (vid,did), ap in apparatus.items():
    if ap or (vid,did) in rows or (vid,did) in seen: continue
    if vid in latam_vol and not (vid.endswith("Ed2") and vid in ("frus1951-54IranEd2","frus1969-76ve15p2Ed2")):
        out.write(f"{vid}\t{did}\t(no heading)\n"); n+=1
out.close(); outr.close()
print("latam volumes by title:", len(latam_vol))
print("latam non-apparatus docs:", n, " under recognition headings:", nr)
