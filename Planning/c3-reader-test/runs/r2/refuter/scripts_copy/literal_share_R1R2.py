# Literal shares for the two comparison rules used only in the recall table:
#   R1 = NEAR(recogn* govern*, 6) OR NEAR(recogn* regim*, 6) OR NEAR(recogn* junta, 6)
#   R2 = recogn*
# Hit list = Latin American (out/latam_docs.tsv) non-apparatus hits, (volume_id, document_id)-sorted; evenly spaced 40.
# Text = header+dateline+source_note+body_text, whitespace-collapsed; Python re, re.I (case-insensitive).
import csv, re, sqlite3, json
csv.field_size_limit(10**9)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
tr = open("out/sql_trace.log", "a")
latam = {(r["volume_id"], r["document_id"]) for r in csv.DictReader(open("out/latam_docs.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE)}
app = {(v, d) for v, d in con.execute("SELECT volume_id, document_id FROM document_cache WHERE is_front_matter=1 OR is_editorial_note=1")}
RULES = {"R1": "NEAR(recogn* govern*, 6) OR NEAR(recogn* regim*, 6) OR NEAR(recogn* junta, 6)", "R2": "recogn*"}
PAT = {
 "R1": (re.compile(r"\b(?:recognize|recognized|recognition)(?: \S+){0,6}? (?:government|regime|junta)\b|\b(?:government|regime|junta)(?: \S+){0,6}? (?:recognize|recognized|recognition)\b", re.I),
        re.compile(r"\b(?:recogni\w*|non-?recognition|unrecogni\w*)(?:\W+\w+){0,6}?\W+(?:govern\w*|regim\w*|juntas?)\b|\b(?:govern\w*|regim\w*|juntas?)(?:\W+\w+){0,6}?\W+(?:recogni\w*|non-?recognition|unrecogni\w*)", re.I)),
 "R2": (re.compile(r"\b(?:recognize|recognized|recognition)\b", re.I), re.compile(r"\b(?:non-?|un)?recogni\w*", re.I))}
SQL = "SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?"
res = {}
for name, m in RULES.items():
    q = "SELECT volume_id, document_id FROM frus_documents WHERE frus_documents MATCH ?"
    tr.write(f"[literal_share_R1R2.py] {q}  -- args=({m!r},); then {SQL} for 40 sampled pairs\n")
    hits = sorted(k for k in ((v, d) for v, d in con.execute(q, (m,))) if k in latam and k not in app)
    N = len(hits); idx = [int(i * N / 40) for i in range(40)]
    s_ok = t_ok = 0; misses = []
    for i in idx:
        v, d = hits[i]; h, dl, sn, b = con.execute(SQL, (v, d)).fetchone()
        txt = " ".join(" ".join([h or "", dl or "", sn or "", b or ""]).split())
        s = bool(PAT[name][0].search(txt)); t = bool(PAT[name][1].search(txt)); s_ok += s; t_ok += t
        if not s: misses.append(f"{v}/{d}")
    res[name] = {"N": N, "strict": s_ok, "tolerant": t_ok, "strict_misses": misses}
    print(f"{name}: hit list N={N}; STRICT {s_ok} of 40; TOLERANT {t_ok} of 40; strict misses: {misses[:12]}")
json.dump(res, open("out/literal_share_R1R2.json", "w"), indent=1)
