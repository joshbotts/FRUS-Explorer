# Literal share of the scope's text rule (T). Hit list = out/scope_text.tsv (1,348 Latin American non-apparatus hits),
# sorted by (volume_id, document_id); evenly spaced sample of 40. Text = header+dateline+source_note+body_text
# concatenated and whitespace-collapsed. Python re with re.I (case-INSENSITIVE) for both forms.
# STRICT  = base words only, single spaces: (recognize|recognized|recognition) within 6 intervening tokens of
#           (government|regime|junta), either order; AND a force word in base form.
# TOLERANT= inflections allowed (recogni\w*, nonrecognition, govern\w*, regim\w*, junta\w*) with ANY run of
#           non-word characters (space, hyphen, comma, parenthesis, full stop...) between tokens; AND a force word
#           with inflections/hyphenation.
import csv, re, sqlite3, json, sys
csv.field_size_limit(10**9)
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows = sorted((r["volume_id"], r["document_id"]) for r in csv.DictReader(open("out/scope_text.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
N = len(rows); K = 40
idx = [int(i * N / K) for i in range(K)]
sample = [rows[i] for i in idx]
S_REC = re.compile(r"\b(?:recognize|recognized|recognition)(?: \S+){0,6}? (?:government|regime|junta)\b|\b(?:government|regime|junta)(?: \S+){0,6}? (?:recognize|recognized|recognition)\b", re.I)
T_REC = re.compile(r"\b(?:recogni\w*|non-?recognition|unrecogni\w*)(?:\W+\w+){0,6}?\W+(?:govern\w*|regim\w*|juntas?)\b|\b(?:govern\w*|regim\w*|juntas?)(?:\W+\w+){0,6}?\W+(?:recogni\w*|non-?recognition|unrecogni\w*)", re.I)
S_FORCE = re.compile(r"\b(?:revolution|coup|junta|de facto|overthrow|insurrection|golpe|provisional government|usurpation|unconstitutional)\b", re.I)
T_FORCE = re.compile(r"\b(?:revolution\w*|coups?|coup\W+d\W*.tat|juntas?|de\W+facto|overthr\w+|insurrect\w*|golpes?|provisional\W+govern\w*|usurp\w*|unconstitutional\w*)\b", re.I)
SQL = "SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?"
open("out/sql_trace.log", "a").write(f"[literal_share_T.py] {SQL}  -- run for each of the 40 sampled pairs (indices {idx})\n")
out = []
s_ok = t_ok = 0
for v, d in sample:
    h, dl, sn, b = con.execute(SQL, (v, d)).fetchone()
    txt = " ".join(" ".join([h or "", dl or "", sn or "", b or ""]).split())
    sr, tr_, sf, tf = S_REC.search(txt), T_REC.search(txt), S_FORCE.search(txt), T_FORCE.search(txt)
    s = bool(sr and sf); t = bool(tr_ and tf)
    s_ok += s; t_ok += t
    m = tr_ or sr
    kwic = txt[max(0, m.start() - 160): m.end() + 160] if m else ""
    out.append({"pair": f"{v}/{d}", "strict": s, "tolerant": t, "strict_rec": bool(sr), "strict_force": bool(sf),
                "header": " ".join((h or "").split())[:120], "kwic": kwic})
json.dump({"N": N, "K": K, "indices": idx, "strict_pass": s_ok, "tolerant_pass": t_ok, "rows": out}, open("out/literal_share_T.json", "w"), indent=1)
print(f"hit list N={N}; sample K={K}; STRICT {s_ok} of {K}; TOLERANT {t_ok} of {K}")
for o in out:
    print(f"{o['pair']}\tS={int(o['strict'])} T={int(o['tolerant'])} (sRec={int(o['strict_rec'])} sForce={int(o['strict_force'])})\t{o['header'][:70]}\n    …{o['kwic'][:330]}…")
