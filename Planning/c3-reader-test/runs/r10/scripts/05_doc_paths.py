# Map every document to its editorial heading path, and flag documents in Latin American chapters.
# SQL run: SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id;
#          SELECT volume_id, document_id, is_front_matter, is_editorial_note FROM document_cache;
#          SELECT volume_id, document_id, date_iso FROM document_dates;
# A document is LA ("Latin American universe") when the path of headings above it names a Latin American
# country or regional term (LA regex below), or when its volume's manifest TITLE names one (regional volumes).
# Output: out/doc_paths.tsv  volume_id, document_id, is_front_matter, is_editorial_note, date_iso, la_flag, path, isdoc
# isdoc = 1 when document_id GLOB 'd[0-9]*' OR GLOB '*_d[0-9]*' (a printed document, microfiche ones included);
# 0 for the structural records the cache also holds (chapter/compilation/section heading rows 'ch..', 'comp..', 'sec..',
# 'subch..', appendices), which carry a heading and the editors' lead footnote, not a historical document.
import json, re, sqlite3
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
LA = re.compile(r"Argentin|Bolivi|Brazil|Chile|Colombia|Costa Rica|Cuba|Dominican|Santo Domingo|Ecuador|Salvador|"
                r"Guatemala|Haiti|Honduras|Mexic|Nicaragua|Panam|Paraguay|Peru\b|Peruvian|Uruguay|Venezuela|Central America|"
                r"American Republics|Latin America|Western Hemisphere|Inter-American|South America|Soccer War", re.I)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
man = json.load(open(RES + "manifest.json"))
# Mixed volumes (a title that also names the United Nations, or an appendix of several subjects) are flagged by path only.
MIXED = re.compile(r"United Nations|Appendix I\b", re.I)
la_vol = {v["volumeId"] for v in man if LA.search(re.sub(r"\s+", " ", v.get("title") or "")) and not MIXED.search(re.sub(r"\s+", " ", v.get("title") or ""))}
paths = {}
for vid, sj in con.execute("SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id"):
    st = json.loads(sj)
    def walk(secs, path):
        for s in secs:
            t = re.sub(r"\s+", " ", (s.get("title") or "")).strip()
            p = path + [t]
            for d in s.get("documentIds") or []:
                paths[(vid, d)] = " > ".join(p)
            walk(s.get("subsections") or [], p)
    walk(st.get("sections") or [], [])
dates = {(v, d): di for v, d, di in con.execute("SELECT volume_id, document_id, date_iso FROM document_dates")}
n = nla = 0
with open("/Users/jbotts/frus-analysis/c3/runs/r10/out/doc_paths.tsv", "w") as f:
    for v, d, fm, ed in con.execute("SELECT volume_id, document_id, is_front_matter, is_editorial_note FROM document_cache ORDER BY volume_id, document_id"):
        p = paths.get((v, d), "")
        la = 1 if (LA.search(p) or v in la_vol) else 0
        n += 1; nla += la
        isdoc = 1 if (re.match(r"^d[0-9]", d) or re.match(r"^[a-z]+_d[0-9]", d)) else 0
        f.write("\t".join([v, d, str(fm), str(ed), dates.get((v, d)) or "", str(la), p, str(isdoc)]) + "\n")
print("documents:", n, "LA-flagged (incl. apparatus):", nla, "LA volumes by title:", len(la_vol))
print("LA volumes by title (mixed excluded):", sorted(la_vol))
