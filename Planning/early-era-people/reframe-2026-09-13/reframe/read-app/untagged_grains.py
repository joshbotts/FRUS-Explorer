# Read-only measurement over the live FRUS Explorer index (app-view population).
# Question: for volumes whose indexed state has NO persons rows (the untagged volumes as the app
# sees them), what does each grain an app surface reads actually hold today?
import sqlite3, json, os, sys, time
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "untagged_grains.json")
con = sqlite3.connect('file:' + DB + '?mode=ro', uri=True)
q = lambda s, *a: con.execute(s, a).fetchall()
t0 = time.time()
res = {"db": DB, "population": "app-view: volumes present in the live index document_cache"}
try:
    res["index_version_rows"] = q("SELECT index_version, COUNT(*) FROM document_revisions GROUP BY index_version")
except sqlite3.OperationalError as e:
    res["index_version_rows"] = str(e)
res["tables"] = [r[0] for r in q("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
docs_by_vol = dict(q("SELECT volume_id, COUNT(*) FROM document_cache GROUP BY volume_id"))
nonfm_by_vol = dict(q("SELECT volume_id, COUNT(*) FROM document_cache WHERE is_front_matter=0 GROUP BY volume_id"))
persons_by_vol = dict(q("SELECT volume_id, COUNT(*) FROM persons GROUP BY volume_id"))
pm_by_vol = dict(q("SELECT volume_id, COUNT(*) FROM person_mentions GROUP BY volume_id"))
try:
    borrowers = set(r[0] for r in q("SELECT volume_id FROM person_list_sources"))
    res_borrow_note = "present"
except sqlite3.OperationalError as e:
    borrowers = set()
    res_borrow_note = "person_list_sources absent in this index (added at v51): " + str(e)
vols = sorted(docs_by_vol)
untagged = [v for v in vols if persons_by_vol.get(v, 0) == 0]
tagged = [v for v in vols if persons_by_vol.get(v, 0) > 0]
res["person_list_sources"] = res_borrow_note
res["volumes_in_index"] = len(vols)
res["documents_in_index"] = sum(docs_by_vol.values())
res["persons_rows"] = q("SELECT COUNT(*) FROM persons")[0][0]
res["person_mentions_rows"] = q("SELECT COUNT(*) FROM person_mentions")[0][0]
res["person_rollup_rows"] = q("SELECT COUNT(*) FROM person_rollup")[0][0]
res["volumes_with_persons_rows"] = len(tagged)
res["volumes_without_persons_rows"] = len(untagged)
res["borrower_volumes_with_persons_rows"] = len([v for v in tagged if v in borrowers])
res["untagged_documents_all"] = sum(docs_by_vol[v] for v in untagged)
res["untagged_documents_non_front_matter"] = sum(nonfm_by_vol.get(v, 0) for v in untagged)
res["untagged_person_mentions_rows"] = sum(pm_by_vol.get(v, 0) for v in untagged)
U = set(untagged)
# header / dateline presence in untagged non-front-matter documents
hd = {"docs": 0, "header_nonempty": 0, "dateline_nonempty": 0, "source_note_nonempty": 0, "despatch_serial": 0}
for v, h, d, s, ds in con.execute("SELECT volume_id, length(header), length(dateline), length(source_note), despatch_serial FROM document_cache WHERE is_front_matter=0"):
    if v not in U: continue
    hd["docs"] += 1
    if h: hd["header_nonempty"] += 1
    if d: hd["dateline_nonempty"] += 1
    if s: hd["source_note_nonempty"] += 1
    if ds: hd["despatch_serial"] += 1
res["untagged_header_dateline"] = hd
# document_dates years for untagged docs
years = {}
for v, y in con.execute("SELECT volume_id, CAST(substr(date_iso,1,4) AS INTEGER) FROM document_dates WHERE substr(date_iso,1,4) GLOB '[12][0-9][0-9][0-9]'"):
    if v in U:
        b = "pre1906" if y < 1906 else ("1906-1945" if y <= 1945 else "post1945")
        years[b] = years.get(b, 0) + 1
res["untagged_dated_documents_by_band"] = years
def count_in(table):
    n = 0
    for v, c in con.execute(f"SELECT volume_id, COUNT(*) FROM {table} GROUP BY volume_id"):
        if v in U: n += c
    return n
for t in ["document_sources", "external_citations", "document_subjects", "cross_references", "volume_structures", "document_dates"]:
    try:
        res[f"untagged_rows_{t}"] = count_in(t)
    except Exception as e:
        res[f"untagged_rows_{t}"] = f"error: {e}"
res["untagged_volume_ids_sample"] = untagged[:20]
res["untagged_volumes_by_decade"] = {}
for v in untagged:
    import re
    m = re.match(r"frus(\d{4})", v)
    dec = (m.group(1)[:3] + "0s") if m else "other"
    res["untagged_volumes_by_decade"][dec] = res["untagged_volumes_by_decade"].get(dec, 0) + 1
res["seconds"] = round(time.time() - t0, 1)
json.dump(res, open(OUT, "w"), indent=1, default=str)
print(json.dumps({k: v for k, v in res.items() if k not in ("tables",)}, indent=1, default=str))
