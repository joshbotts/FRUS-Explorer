# quote_check.py: the guide's quotation check over every overview quotation and every collection excerpt.
# lower-case both sides, drop everything but [a-z0-9], split the quotation at ellipsis marks, require every
# segment in order at increasing offsets as a substring of header||dateline||source_note||body_text of the
# EXACT (volume_id, document_id) cited.
import sqlite3, re, json, sys
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f5/"
c = sqlite3.connect(DB, uri=True)

def canon(s):
    return re.sub(r'[^a-z0-9]', '', s.lower())

def segments(q):
    q = q.replace('[...]', '…').replace('...', '…')
    return [canon(x) for x in q.split('…') if canon(x)]

_cache = {}
def doctext(v, d):
    if (v, d) not in _cache:
        r = c.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", [v, d]).fetchone()
        _cache[(v, d)] = canon((r[0] or '') + (r[1] or '') + (r[2] or '') + (r[3] or '')) if r else None
    return _cache[(v, d)]

def check(v, d, q):
    t = doctext(v, d)
    if t is None:
        return False, "pair not in document_cache"
    pos = 0
    for seg in segments(q):
        i = t.find(seg, pos)
        if i < 0:
            return False, f"segment not found at offset>={pos}: {seg[:50]}"
        pos = i + len(seg)
    return True, "ok"

# ---- the overview's quoted passages, in reading order, each with the pair the memo's trace table gives.
# (volume, document) = None marks a search term or an example word, not a quotation from a document.
OV = [
 ("bottom line 1", "soft power", None, "search term"),
 ("bottom line 1", "public diplomacy", None, "search term"),
 ("bottom line 3", "soft power", None, "search term"),
 ("bottom line 3", "Department of State", None, "control term"),
 ("bottom line 3", "Public diplomacy", None, "search term"),
 ("decisions", "soft power", None, "search term"),
 ("decisions", "policymakers", None, "word of the question"),
 ("decisions", "Orientals", ("frus1961-63v04", "d81"), "memo Q19 (no explicit citation in the overview; memo section 8 names the vocabulary)"),
 ("decisions", "face", ("frus1961-63v02", "d16"), "memo Q16 (no explicit citation; the only 'face' among the 39 quotations)"),
 ("finding 1 prose", "middle group", ("frus1948v07", "d567"), "trace: Q2"),
 ("finding 1 bullet", "If the United States is to win and retain moral leadership it must continue to discuss domestic conditions in the United States.", ("frus1948v07", "d567"), "trace: Q1; URL frus1948v07/d567"),
 ("finding 1 bullet", "A considerably expanded information program both in Communist and non-Communist areas of Asia is called for, both to demonstrate our understanding and sympathy for the nationalist aspirations of the Asian peoples and to expose the menace to these aspirations created by Soviet imperialism.", ("frus1949v07p2", "d386"), "trace: Q4; URL frus1949v07p2/d386"),
 ("finding 1 bullet", "The USIA program emphasizes comprehensive anti-Communist indoctrination throughout Thailand.", ("frus1955-57v22", "d484"), "trace: Q13; URL frus1955-57v22/d484"),
 ("finding 2 prose", "more affected by our actions than our words", ("frus1952-54v12p2", "d251"), "trace: Q7"),
 ("finding 2 prose", "Asia for Asians", ("frus1952-54v12p2", "d352"), "trace: Q9"),
 ("finding 2 prose", "Orientals", ("frus1961-63v04", "d81"), "memo Q19"),
 ("finding 2 bullet", "which is more affected by our actions than our words and which is hostile to propaganda from any source, especially non-Asian.", ("frus1952-54v12p2", "d251"), "trace: Q7; URL frus1952-54v12p2/d251"),
 ("finding 2 bullet", "a fear of placing the U.S. in the position of appearing to support colonialism.", ("frus1955-57v22", "d447"), "trace: Q12; URL frus1955-57v22/d447"),
 ("finding 2 bullet", "The predominant mood is apolitical, seeking to be neutral, and concerned with economic and trade problems rather than strong ideological convictions.", ("frus1917-72PubDipv08", "d149"), "trace: Q32; URL frus1917-72PubDipv08/d149"),
 ("finding 3 prose", "degree cannot be accurately measured", ("frus1952-54v13p1", "d116"), "trace: Q6"),
 ("finding 3 prose", "a really hard reading", ("frus1961-63v02", "d197"), "trace: Q18"),
 ("finding 3 prose", "the weakest part of the war operation", ("frus1964-68v01", "d122"), "trace: Q20"),
 ("finding 3 prose", "not progressed to my satisfaction", ("frus1964-68v02", "d160"), "trace: Q22"),
 ("finding 3 prose", "nothing worthwhile left", ("frus1964-68v26", "d106"), "trace: Q26"),
 ("finding 3 bullet", "All factors recited must be viewed as effective though degree cannot be accurately measured.", ("frus1952-54v13p1", "d116"), "trace: Q6; URL frus1952-54v13p1/d116"),
 ("finding 3 bullet", "the weakest part of the war operation, both on our part and that of the Government of South Viet-Nam, is in the field of information and psychological warfare.", ("frus1964-68v01", "d122"), "trace: Q20; URL frus1964-68v01/d122"),
 ("finding 3 bullet", "Does anyone have a really hard reading on how well GVN propaganda is working in the rural areas?", ("frus1961-63v02", "d197"), "trace: Q18; URL frus1961-63v02/d197"),
 ("finding 4 prose", "persuaded by other Vietnamese", ("frus1917-72PubDipv07", "d32"), "trace: Q23"),
 ("finding 4 bullet", "Vietnamese peasants are, in the main, going to be persuaded by other Vietnamese.", ("frus1917-72PubDipv07", "d32"), "trace: Q23; URL frus1917-72PubDipv07/d32"),
 ("finding 4 bullet", "The Thai Government has not given proper attention to the need for a national information program designed to gain popular support.", ("frus1964-68v27", "d386"), "trace: Q27; URL frus1964-68v27/d386"),
 ("finding 4 bullet", "an unfortunately large amount of anti-Americanism under the surface in Viet-Nam.", ("frus1917-72PubDipv07", "d85"), "trace: Q25; URL frus1917-72PubDipv07/d85"),
 ("finding 5 prose", "lower its voice", ("frus1917-72PubDipv08", "d99"), "trace: Q31"),
 ("finding 5 prose", "lack credibility", ("frus1969-76v38p2", "d105"), "trace: Q34"),
 ("finding 5 prose", "the confidence of East Asians in America’s long-term staying power", ("frus1977-80v30", "d79"), "trace: Q37"),
 ("finding 5 bullet", "PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations (security treaty, Okinawa, Korean military modernization, trade restrictions) than on developments within the US.", ("frus1917-72PubDipv08", "d31"), "trace: Q29; URL frus1917-72PubDipv08/d31"),
 ("finding 5 bullet", "During this waiting period, programs on U.S. security relations in Asia lack credibility and may in fact do damage to our relations.", ("frus1969-76v38p2", "d105"), "trace: Q34; URL frus1969-76v38p2/d105"),
 ("finding 5 bullet", "Rather than being reassured, the ASEAN countries and Japan interpreted our apparent unwillingness to come to grips with the “new realities” as another indication that the United States, after twenty years of exaggerating the extent of its interests in Southeast Asia, might now decide it had no interest there at all.", ("frus1977-80v22", "d104"), "trace: Q36; URL frus1977-80v22/d104"),
 ("how this was done", "clearing", None, "example word"),
 ("how this was done", "clear", None, "example word"),
]

# cross-check: every straight- or curly-quoted string actually present in overview.md
ov = open(RUN + "overview.md").read()
found = re.findall(r'"([^"\n]+)"', ov) + re.findall(r'“([^”\n]+)”', ov)
print("quoted strings found by regex in overview.md:", len(found))
listed = [q for _, q, _, _ in OV]
for f in found:
    if f not in listed and f != "new realities":
        print("  NOT IN MY LIST:", f[:90])
for q in listed:
    if q not in found:
        print("  LISTED BUT NOT FOUND BY REGEX:", q[:90])

print("\n== OVERVIEW QUOTATIONS ==")
nq = fab = 0
for where, q, pair, how in OV:
    if pair is None:
        print(f"  [not a quotation: {how}] {where}: \"{q}\"")
        continue
    nq += 1
    ok, why = check(pair[0], pair[1], q)
    if not ok: fab += 1
    print(f"  {'OK  ' if ok else 'FAIL'} {where}: {pair[0]}/{pair[1]} \"{q[:70]}\" -- {how}; {why}")
print(f"overview quotations checked: {nq}; failing the check: {fab}")

print("\n== COLLECTION EXCERPTS ==")
col = json.load(open(RUN + "collection.fruscollection"))
ex = [e for e in col['entries'] if e['kind'] == 'excerpt']
efail = 0
for e in ex:
    ok, why = check(e['volumeId'], e['documentId'], e['text'])
    if not ok: efail += 1
    print(f"  {'OK  ' if ok else 'FAIL'} {e['volumeId']}/{e['documentId']} \"{e['text'][:70]}\" {why if not ok else ''}")
print(f"excerpts checked: {len(ex)}; failing: {efail}")

# cross-check: does each quotation also appear in any OTHER collection document (would a mis-citation be masked)?
print("\n== OVERVIEW PROSE QUOTATIONS: how many of the 31 collection documents hold the words (mis-citation risk) ==")
docs = sorted({(e['volumeId'], e['documentId']) for e in col['entries'] if e['kind'] == 'document'})
for where, q, pair, how in OV:
    if pair is None or 'bullet' in where: continue
    hits = [f"{v}/{d}" for v, d in docs if check(v, d, q)[0]]
    print(f"  \"{q[:50]}\" cited->{pair[0]}/{pair[1]}: found in {len(hits)} of 31: {hits if len(hits)<=6 else str(len(hits))+' docs'}")
