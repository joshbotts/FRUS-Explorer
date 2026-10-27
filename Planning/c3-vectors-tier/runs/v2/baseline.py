# False-friend baseline: same families as coreset.py over a random sample of 300 dated, non-apparatus documents per decade
# (1860s-1980s, Ed2 dropped), random.Random(1877). Same counting surface (header+dateline+body_text collapsed), re.I.
import sqlite3, re, random, collections, sys
sys.path.insert(0, ".")
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
FAM = {
 "security_word": r"\bsecurity\b",
 "strategic_naval": r"\b(strategic\w*|naval|navy|coaling|Guantanamo|base|bases)\b",
 "soviet_communist_missile": r"\b(Soviets?|Sino-Soviet|communis[mt]s?|missiles?|subversi\w+|Castroism|Castroite)\b",
 "economy": r"\b(sugar|tariffs?|reciprocity|trade|commerce|commercial|investments?|tobacco)\b",
 "property_claims": r"\b(property|properties|claims?|expropriat\w+|nationaliz\w+|compensation)\b",
 "order_intervention": r"\b(insurrection\w*|revolution\w*|intervention|intervene|Platt|annexation|stability|disorder)\b",
}
CF = {k: re.compile(v, re.I) for k, v in FAM.items()}
rng = random.Random(1877)
print("dec\tN\t" + "\t".join(FAM))
for dec in range(186, 199):
    keys = db.execute("SELECT c.volume_id, c.document_id FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND substr(d.date_iso,1,3)=? ORDER BY c.volume_id, c.document_id", (str(dec),)).fetchall()
    if len(keys) < 50: continue
    s = rng.sample(keys, 300); cnt = collections.Counter()
    for v, d in s:
        h, dl, b = db.execute("SELECT header, dateline, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
        t = " ".join(" ".join([h or "", dl or "", b or ""]).split())
        for k, c in CF.items():
            if c.search(t): cnt[k] += 1
    print(f"{dec}0s", 300, *[f"{cnt[k]}/300" for k in FAM], sep="\t", flush=True)
