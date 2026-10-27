# False-friend test for the question's own terms, by era band (date_iso year), Cuba core set (coreset.json) vs a baseline
# random sample of 400 dated non-apparatus documents per band (random.Random(1877), Ed2 dropped).
# Surface: header+dateline+body_text whitespace-collapsed; re.I.
# national security STRICT: \bnational security\b ; TOLERANT: \bnational[\s\-,.()]+securit(y|ies)\b
# prosperity: \bprosper(ity|ous|ed|ing|s)?\b ; control phrase: \bSecretary of State\b
import sqlite3, re, json, random
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
R = {"natsec_strict": r"\bnational security\b", "natsec_tolerant": r"\bnational[\s\-,.()]+securit(y|ies)\b",
     "prosper": r"\bprosper(ity|ous|ed|ing|s)?\b", "CONTROL_secretary_of_state": r"\bSecretary of State\b"}
C = {k: re.compile(v, re.I) for k, v in R.items()}
BANDS = [(1861, 1898), (1899, 1933), (1934, 1958), (1959, 1980)]
def txt(v, d):
    h, dl, b = db.execute("SELECT header, dateline, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    return " ".join(" ".join([h or "", dl or "", b or ""]).split())
core = json.load(open("coreset.json")); rng = random.Random(1877)
print("band\tset\tN\t" + "\t".join(R))
for lo, hi in BANDS:
    cs = [(x["v"], x["d"]) for x in core if x["date"] and lo <= int(x["date"][:4]) <= hi]
    keys = db.execute("SELECT c.volume_id, c.document_id FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND CAST(substr(d.date_iso,1,4) AS INT) BETWEEN ? AND ? ORDER BY 1,2", (lo, hi)).fetchall()
    bs = rng.sample(keys, 400)
    for name, S in (("cuba_core", cs), ("baseline", bs)):
        cnt = {k: 0 for k in R}
        for v, d in S:
            t = txt(v, d)
            for k, c in C.items(): cnt[k] += bool(c.search(t))
        print(f"{lo}-{hi}\t{name}\t{len(S)}\t" + "\t".join(f"{cnt[k]}/{len(S)}" for k in R), flush=True)
