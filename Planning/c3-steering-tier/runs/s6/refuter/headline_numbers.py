#!/usr/bin/env python3
# Refuter re-run of the overview's headline numbers (cell s6). Read-only.
import sqlite3, re, collections, json, sys
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con = sqlite3.connect(DB, uri=True)
ED2 = ('frus1951-54IranEd2', 'frus1969-76ve15p2Ed2')
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s6/"

def one(sql, *a):
    return con.execute(sql, a).fetchone()[0]

print("== volumes")
vols = [r[0] for r in con.execute("SELECT DISTINCT volume_id FROM document_cache")]
print("distinct volumes in document_cache:", len(vols))
print("volumes ending Ed2:", sorted(v for v in vols if v.endswith("Ed2")))
print("non-Ed2 volumes:", len([v for v in vols if v not in ED2]))

print("== N2 denominator")
den = one("SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN (?,?)", *ED2)
print("non-apparatus, non-Ed2 documents:", den)

print("== N3/N4: FTS inventory + family regex (memo's stated predicate)")
FAM = re.compile(r"\b(corrupt\w*|brib\w*|kickback\w*|embezzl\w*|malfeasance|peculat\w*|graft|venal\w*|nepotism|cronyism)\b", re.I)
sql = """SELECT d.volume_id, d.document_id, d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH 'corrupt OR bribe OR bribery OR kickback OR embezzle OR malfeasance OR peculation OR graft OR venal OR nepotism OR cronyism OR payoff'
AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (?,?)"""
nfam = {}
for v, d, b in con.execute(sql, ED2):
    nfam[(v, d)] = len(FAM.findall(b))
print("FTS candidate rows:", len(nfam))
ge1 = [k for k, n in nfam.items() if n >= 1]
ge3 = [k for k, n in nfam.items() if n >= 3]
ge5 = [k for k, n in nfam.items() if n >= 5]
print(">=1 family match:", len(ge1), "| per 100 =", round(100 * len(ge1) / den, 2), "| 1 in", round(den / len(ge1), 1))
print(">=3 family matches:", len(ge3), "in", len({k[0] for k in ge3}), "volumes | 1 in", round(den / len(ge3), 1))
print(">=5 family matches:", len(ge5), "in", len({k[0] for k in ge5}), "volumes")
core = set(ge3)
json.dump(sorted(["%s/%s" % k for k in core]), open(RUN + "refuter/core_pairs.json", "w"))
json.dump({"%s/%s" % k: n for k, n in nfam.items()}, open(RUN + "refuter/nfam.json", "w"))

print("== cited documents in overview.md (by URL)")
ov = open(RUN + "overview.md", encoding="utf-8").read()
urls = re.findall(r"https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)", ov)
cited = []
for v, d in urls:
    if (v, d) not in cited:
        cited.append((v, d))
print("distinct cited pairs:", len(cited), "| URL mentions:", len(urls))
print("cited volumes:", len({v for v, d in cited}))
scope_keys = open(RUN + "scope_keys.txt").read().split()
print("scope_keys.txt pairs:", len(scope_keys), "| same set as overview URLs:", set(scope_keys) == {"%s/%s" % k for k in cited})
print("cited pairs in core (>=3):", sum(1 for k in cited if k in core), "of", len(cited))
print("cited pairs with >=1 family match:", sum(1 for k in cited if nfam.get(k, 0) >= 1))
print("cited pairs NOT in FTS inventory at all:", ["%s/%s" % k for k in cited if k not in nfam])
print("cited pairs family counts:", {"%s/%s" % k: nfam.get(k, 0) for k in cited})

print("== N15: source lines and external citations for the cited pairs")
src = sum(1 for v, d in cited if one("SELECT COUNT(*) FROM document_sources WHERE volume_id=? AND document_id=?", v, d))
ext = sum(1 for v, d in cited if one("SELECT COUNT(*) FROM external_citations WHERE volume_id=? AND document_id=?", v, d))
print("with a document_sources row:", src, "of", len(cited))
print("without:", ["%s/%s" % (v, d) for v, d in cited if not one("SELECT COUNT(*) FROM document_sources WHERE volume_id=? AND document_id=?", v, d)])
print("with external_citations rows:", ext, "of", len(cited))
print("date_iso range of cited pairs:", con.execute("SELECT MIN(dd.date_iso), MAX(dd.date_iso) FROM document_dates dd WHERE (dd.volume_id||'/'||dd.document_id) IN (%s)" % ",".join("'%s/%s'" % k for k in cited)).fetchone())

print("== pointed-at index coverage of the cited volumes")
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
ec = json.load(open(R + "external-citation-index.json"))
cv = sorted({v for v, d in cited})
print("cited volumes:", len(cv), "| in external-citation-index volumes:", sum(1 for v in cv if v in set(ec["volumes"])), "| missing:", [v for v in cv if v not in set(ec["volumes"])])

print("== N13 and other FTS counts (non-apparatus, all volumes incl. Ed2 as the session ran them)")
def cnt(m):
    return con.execute("SELECT COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0", (m,)).fetchone()
for m in ['Church AND Subcommittee AND Multinational', 'Watergate', '"Teapot Dome"', 'BCCI OR "Bank of Credit and Commerce"', '"Iran-Contra"', '"Tongsun Park" OR Koreagate', 'Lockheed', 'nepotism', 'cronyism']:
    print(" ", m, "->", cnt(m))

print("== N11 pre-1860")
pre = "AND d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso<'1860-01-01' AND dd.date_iso<>''"
print("pre-1860 dated non-apparatus docs:", one("SELECT COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE 1=1 " + pre),
      "| volumes:", one("SELECT COUNT(DISTINCT d.volume_id) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE 1=1 " + pre))
def cntpre(m):
    return one("SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH ? " + pre, m)
print("  'Department of State' pre-1860:", cntpre('"Department of State"'), "| ZZZ:", cntpre('ZZZ_IMPOSSIBLE_ZZZ'))
print("  wider vocabulary pre-1860:", cntpre('corrupt OR bribe OR bribery OR peculation OR defalcation OR extortion OR exactions OR embezzle OR malversation OR venal OR "presents to" OR squeeze OR irregularities'))
# family (>=1 regex) among pre-1860 dated docs
pre_keys = set(con.execute("SELECT d.volume_id, d.document_id FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE 1=1 " + pre).fetchall())
print("  family (>=1 regex) pre-1860:", sum(1 for k in ge1 if k in pre_keys), [ "%s/%s"%k for k in ge1 if k in pre_keys])

print("== N12 after 1989")
print("dated non-apparatus non-Ed2 docs with date_iso >= '1990':", one("SELECT COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (?,?) AND dd.date_iso>='1990' AND dd.date_iso<>''", *ED2))
post = set(con.execute("SELECT d.volume_id, d.document_id FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (?,?) AND dd.date_iso>='1990' AND dd.date_iso<>''", ED2).fetchall())
print("  of which with >=1 family match:", sum(1 for k in ge1 if k in post))
print("  max date_iso in index:", one("SELECT MAX(date_iso) FROM document_dates"), "| min:", one("SELECT MIN(date_iso) FROM document_dates WHERE date_iso<>''"))

print("== N9 decade shape (core >=3 per 1,000 dated docs)")
dec_of = {}
den_dec = collections.Counter()
for v, d, di in con.execute("SELECT d.volume_id,d.document_id,dd.date_iso FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (?,?) AND dd.date_iso IS NOT NULL AND dd.date_iso<>''", ED2):
    dec = di[:3] + "0s"; den_dec[dec] += 1; dec_of[(v, d)] = dec
num = collections.Counter(); byv = collections.defaultdict(collections.Counter)
for k in core:
    if k in dec_of:
        num[dec_of[k]] += 1; byv[dec_of[k]][k[0]] += 1
for dec in sorted(den_dec):
    if dec < "1840s": continue
    tv = byv[dec].most_common(1)
    print("  %s %d of %d = %.1f per 1000 %s" % (dec, num[dec], den_dec[dec], 1000 * num[dec] / den_dec[dec], ("top %s %d" % (tv[0][0], tv[0][1])) if tv else ""))

print("== N8 controls: top-10 volumes by core count vs others")
corev = collections.Counter(k[0] for k in core)
top = [v for v, _ in corev.most_common(10)]
print("top10:", corev.most_common(10))
tot = collections.Counter()
for v, n in con.execute("SELECT volume_id, COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN (?,?) GROUP BY volume_id", ED2): tot[v] = n
fam = collections.Counter(k[0] for k in ge1)
def pervol(m):
    c = collections.Counter()
    for v, n in con.execute("SELECT d.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (?,?) GROUP BY d.volume_id", (m, *ED2)): c[v] = n
    return c
ctl = pervol('"Department of State"'); neg = pervol('ZZZ_IMPOSSIBLE_ZZZ')
A = sum(tot[v] for v in top); B = sum(tot[v] for v in tot if v not in top)
for name, c in (("family>=1", fam), ("Department of State", ctl), ("ZZZ", neg)):
    a = sum(c[v] for v in top); b = sum(c[v] for v in tot if v not in top)
    print("  %s: top10 %d of %d = %.1f per 100 | others %d of %d = %.1f per 100" % (name, a, A, 100 * a / A, b, B, 100 * b / B))
print("  volumes with zero 'Department of State':", [v for v in tot if ctl[v] == 0])

print("== N7 strict/tolerant over the core set (header+dateline+source_note+body_text, whitespace-collapsed)")
TOL = FAM; STR = re.compile(r"\b(corruption|corrupt|bribery|bribe|graft)\b")
t = s = 0
for v, d in sorted(core):
    h, dl, sn, b = con.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    txt = re.sub(r"\s+", " ", " ".join([h or "", dl or "", sn or "", b or ""]))
    t += bool(TOL.search(txt)); s += bool(STR.search(txt))
print("  tolerant", t, "strict", s, "of", len(core))

print("== N14 nepotism/cronyism documents among candidates (regex)")
nep = sum(1 for (v, d), n in nfam.items() if n >= 0 and re.search(r"\bnepotism\b", con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0], re.I))
cro = sum(1 for (v, d), n in nfam.items() if n >= 0 and re.search(r"\bcronyism\b", con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0], re.I))
print("  nepotism docs:", nep, "| cronyism docs:", cro, "| sum:", nep + cro)
