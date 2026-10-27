# Independent recount of the memo's six vocabulary families over MY reproduction of the core set (my_core_pairs.json),
# same surface (header+dateline+body_text, whitespace-collapsed), same regexes as the memo §2 states them.
import sqlite3, json, re, collections
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
FAM = {
 "security": r"\bsecurity\b",
 "strategic_naval": r"\b(strategic\w*|naval|navy|coaling|Guantanamo|base|bases)\b",
 "soviet": r"\b(Soviets?|Sino-Soviet|communis[mt]s?|missiles?|subversi\w+|Castroism|Castroite)\b",
 "economy": r"\b(sugar|tariffs?|reciprocity|trade|commerce|commercial|investments?|tobacco)\b",
 "property": r"\b(property|properties|claims?|expropriat\w+|nationaliz\w+|compensation)\b",
 "order": r"\b(insurrection\w*|revolution\w*|intervention|intervene|Platt|annexation|stability|disorder)\b",
}
CF = {k: re.compile(v, re.I) for k, v in FAM.items()}
N = collections.Counter(); H = collections.defaultdict(collections.Counter)
for p in json.load(open("my_core_pairs.json")):
    v, d = p.split("/")
    h, dl, b, dt = db.execute("SELECT c.header, c.dateline, c.body_text, dd.date_iso FROM document_cache c LEFT JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?", (v, d)).fetchone()
    dec = dt[:3] + "0s"; N[dec] += 1
    t = " ".join(" ".join([h or "", dl or "", b or ""]).split())
    for k, c in CF.items():
        if c.search(t): H[dec][k] += 1
memo = {"1870s": (29,87,4,90,114,108), "1880s": (9,22,1,86,56,33), "1910s": (17,175,1,172,221,167), "1940s": (25,142,20,389,122,38), "1950s": (70,124,168,159,95,207), "1960s": (1006,770,1280,485,201,510), "1970s": (304,141,193,162,75,135)}
print("dec\tN\t" + "\t".join(FAM))
for dec in sorted(N):
    row = [H[dec][k] for k in FAM]
    flag = ""
    if dec in memo: flag = "  memo=" + str(memo[dec]) + ("  MATCH" if tuple(row) == memo[dec] else "  DIFF")
    print(dec, N[dec], *row, sep="\t", end=flag + "\n")
