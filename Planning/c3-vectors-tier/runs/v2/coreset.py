# Build the Cuba core set and measure vocabulary families per decade.
# Inclusion rule: (A) every document in an editors' section whose title matches /cuba|havana/i (cuba_chapters.tsv),
#   except the frus1896 section about the British steamship "Cuban"; (B) for volumes frus1861..frus1894*, which have
#   no Cuba chapter, every document whose body_text has >=3 matches of \b(Cuba|Cuban|Cubans|Havana)\b (re.I).
# Always: is_front_matter=0, is_editorial_note=0, drop frus1951-54IranEd2 and frus1969-76ve15p2Ed2.
# Decade = first 3 chars of document_dates.date_iso (the index's frus:doc-dateTime-min day).
# Counting surface: header+' '+dateline+' '+body_text, whitespace-collapsed (body_text includes footnotes).
import sqlite3, re, json, random, collections
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
ED2 = {"frus1951-54IranEd2", "frus1969-76ve15p2Ed2"}
FAM = {
 "security_word": r"\bsecurity\b",
 "strategic_naval": r"\b(strategic\w*|naval|navy|coaling|Guantanamo|base|bases)\b",
 "soviet_communist_missile": r"\b(Soviets?|Sino-Soviet|communis[mt]s?|missiles?|subversi\w+|Castroism|Castroite)\b",
 "economy": r"\b(sugar|tariffs?|reciprocity|trade|commerce|commercial|investments?|tobacco)\b",
 "property_claims": r"\b(property|properties|claims?|expropriat\w+|nationaliz\w+|compensation)\b",
 "order_intervention": r"\b(insurrection\w*|revolution\w*|intervention|intervene|Platt|annexation|stability|disorder)\b",
}
CF = {k: re.compile(v, re.I) for k, v in FAM.items()}
cuba_re = re.compile(r"\b(Cuba|Cuban|Cubans|Havana)\b", re.I)
core = {}
for line in open("cuba_chapters.tsv"):
    v, n, path, ids = line.rstrip("\n").split("\t")
    if v == "frus1896" and "steamship Cuban" in path: continue
    for d in ids.split(","):
        if d: core[(v, d)] = "A"
vols19 = [r[0] for r in db.execute("SELECT DISTINCT volume_id FROM document_cache WHERE volume_id GLOB 'frus18[6-9]*' AND volume_id < 'frus1895' ORDER BY 1")]
for v in vols19:
    for d, body in db.execute("SELECT document_id, body_text FROM document_cache WHERE volume_id=? AND is_front_matter=0 AND is_editorial_note=0", (v,)):
        if len(cuba_re.findall(body)) >= 3: core.setdefault((v, d), "B")
rows = []
for (v, d), why in sorted(core.items()):
    if v in ED2: continue
    r = db.execute("SELECT c.header, c.dateline, c.body_text, c.is_front_matter, c.is_editorial_note, dd.date_iso FROM document_cache c LEFT JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?", (v, d)).fetchone()
    if not r or r[3] or r[4]: continue
    text = " ".join((" ".join([r[0] or "", r[1] or "", r[2] or ""])).split())
    fams = {k: bool(c.search(text)) for k, c in CF.items()}
    rows.append({"v": v, "d": d, "why": why, "date": r[5], "dec": (r[5][:3] + "0s") if r[5] else None, "len": len(r[2]), **fams})
json.dump(rows, open("coreset.json", "w"))
by = collections.defaultdict(list)
for x in rows: by[x["dec"]].append(x)
print("core docs", len(rows), "A", sum(x["why"]=="A" for x in rows), "B", sum(x["why"]=="B" for x in rows), "undated", len(by[None]))
print("dec\tN\ttopvol(share)\t" + "\t".join(FAM))
for dec in sorted(k for k in by if k):
    L = by[dec]; vc = collections.Counter(x["v"] for x in L).most_common(1)[0]
    print(dec, len(L), f"{vc[0]}({vc[1]}/{len(L)})", *[f"{sum(x[k] for x in L)}/{len(L)}" for k in FAM], sep="\t")
