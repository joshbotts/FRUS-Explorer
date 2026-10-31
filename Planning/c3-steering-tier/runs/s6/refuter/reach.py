#!/usr/bin/env python3
# Refuter: for each cited pair, which of the session's LOGGED full-text / heading queries return it. Read-only.
import sqlite3, re, json, collections
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con = sqlite3.connect(DB, uri=True)
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s6/"
ov = open(RUN + "overview.md", encoding="utf-8").read()
cited = []
for v, d in re.findall(r"https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)", ov):
    if (v, d) not in cited: cited.append((v, d))
assert len(cited) == 30, len(cited)

# Every MATCH expression the log records (queries.log line numbers), with a kind.
Q = [
 ("L4", "subject", "corrupt"), ("L5", "subject", "bribe"), ("L6", "subject", "graft"), ("L7", "subject", "kickback"),
 ("L8", "subject", "embezzle"), ("L9", "subject", "malfeasance"), ("L10", "subject", "venal"), ("L11", "subject", "peculation"),
 ("L12", "subject", "extortion"), ("L13", "subject", "payoff"), ("L14", "control", '"Department of State"'),
 ("L15", "control", "ZZZ_IMPOSSIBLE_ZZZ"), ("L16", "subject", '"corrupt practices"'), ("L17", "subject", '"Foreign Corrupt Practices"'),
 ("L18", "subject", "Lockheed"), ("L19", "subject", '"illegal payments"'), ("L20", "subject", '"questionable payments"'),
 ("L21", "subject", "misappropriat"), ("L22", "subject", "nepotism"), ("L23", "subject", "cronyism"), ("L24", "subject", '"bribery"'),
 ("L25", "subject", "scandal"),
 ("L27", "subject", "corrupt OR bribe OR bribery OR kickback OR embezzle OR malfeasance OR peculation OR graft"),
 ("L29", "subject", "corrupt"),
 ("L30", "heading", 'header:(corrupt OR bribe OR bribery OR graft OR kickback OR embezzle OR scandal OR malfeasance OR nepotism OR peculation OR "improper payments" OR "illegal payments" OR "questionable payments")'),
 ("L31/39", "subject", "corrupt OR bribe OR bribery OR kickback OR embezzle OR malfeasance OR peculation OR graft OR venal OR nepotism OR cronyism OR payoff"),
 ("L34", "subject", '("Foreign Corrupt Practices" OR "questionable payments" OR "illegal payments" OR "corrupt practices" OR (Lockheed AND (bribe OR bribery OR payments OR corrupt)) OR "improper payments" OR "bribery of foreign")'),
 ("L59", "subject", '"Tongsun Park"'), ("L60", "subject", '"Park Tong Sun" OR "Park Tong-sun"'), ("L61", "subject", "Koreagate"),
 ("L62", "subject", "Watergate"), ("L63", "subject", 'BCCI OR "Bank of Credit and Commerce"'), ("L64", "subject", '"Teapot Dome"'),
 ("L65", "subject", "Abscam"), ("L66", "subject", '"Iran-Contra"'), ("L67", "subject", "defalcation"), ("L68", "subject", '"Credit Mobilier"'),
 ("L69", "subject", "Church AND Subcommittee AND Multinational"), ("L70", "probe", '"Nixon Presidential" '),
 ("L71", "subject", '"Tongsun Park" OR Koreagate'),
 ("L76", "subject(pre-1860 only)", 'corrupt OR bribe OR bribery OR peculation OR defalcation OR extortion OR exactions OR embezzle OR malversation OR venal OR "presents to" OR squeeze OR irregularities'),
]
pairs_sql = ",".join("('%s','%s')" % k for k in cited)
hits = collections.defaultdict(list)   # pair -> [labels]
for label, kind, m in Q:
    if label == "L76":
        rows = con.execute("SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso<'1860-01-01' AND dd.date_iso<>'' AND (d.volume_id,d.document_id) IN (VALUES %s)" % pairs_sql, (m,)).fetchall()
    else:
        rows = con.execute("SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND (d.volume_id,d.document_id) IN (VALUES %s)" % pairs_sql, (m,)).fetchall()
    for r in rows: hits[tuple(r)].append((label, kind))
    print("%-7s %-22s returns %2d of 30 cited  :: %s" % (label, kind, len(rows), m[:70]))

core = set(tuple(k.split("/")) for k in json.load(open(RUN + "refuter/core_pairs.json")))
nfam = json.load(open(RUN + "refuter/nfam.json"))
print()
print("== per cited document")
strict_vector = []; untraced = []
for k in cited:
    labs = hits.get(k, [])
    subj = [l for l, kind in labs if kind in ("subject", "heading")]
    ctrl = [l for l, kind in labs if kind in ("control", "probe")]
    print("%-26s core=%s nfam=%s | subject/heading queries: %s | control/probe: %s" % ("%s/%s" % k, k in core, nfam.get("%s/%s" % k, "not-in-inventory"), subj or "NONE", ctrl or "-"))
    if not subj:
        strict_vector.append(k)
print()
print("cited docs returned by NO logged subject/heading query:", ["%s/%s" % k for k in strict_vector])
print("cited docs returned by NO logged query of any kind:", ["%s/%s" % k for k in cited if not hits.get(k)])
print("cited docs in the memo's core scope set (>=3):", sum(1 for k in cited if k in core), "of 30")
