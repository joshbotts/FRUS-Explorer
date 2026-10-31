"""Refuter step 3: every quotation in overview.md and every excerpt in the collection, segment-strict against the exact pair."""
import json, re, sqlite3
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s3/"
con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)

def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())

def check(quote, v, d):
    r = con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if r is None:
        return False, "PAIR NOT IN document_cache"
    doc = norm("".join(x or "" for x in r))
    segs = [norm(s) for s in re.split(r"\[\.\.\.\]|\.\.\.|…", quote)]
    segs = [s for s in segs if s]
    pos = 0; found = []
    for s in segs:
        i = doc.find(s, pos)
        if i < 0:
            return False, "segment not found: %r" % s[:60]
        found.append(i); pos = i + len(s)
    return True, "offsets %s" % found

# the overview's quotations attributed to a document, in reading order, with the printed citation as the overview gives it
# (printed volume, printed document number) and the pair the memo's trace table / §4 gives
OV = [
 ("I have not been able to present much in the way of specific instances of corruption. There is here almost a conspiracy to conceal facts", "1922, Volume I", 841, "frus1922v01", "d841"),
 ("graft, bribery and corruption are standard practices to be found in every section of the province", "1944, Volume VI", 292, "frus1944v06", "d292"),
 ("A thorough investigation should be made into the charges of corruption among army officers", "1947, Volume VII", 583, "frus1947v07", "d583"),
 ("many US reporters, when they come across any corruption or graft, play up the cases, making the US public believe that the entire Chinese Government is corrupt", "1948, Volume VII", 43, "frus1948v07", "d43"),
 ("Nationalist failures in suppression rebellion entirely due to Nationalist corruption and impotence", "1948, Volume VII", 471, "frus1948v07", "d471"),
 ("Military government’s efforts to deal with wholesale graft, bribery and corruption in government and business", "1961–1963, Volume XXII", 244, "frus1961-63v22", "d244"),
 ("the graft and corruption in the Garcia Administration", "1961–1963, Volume XXIII", 356, "frus1961-63v23", "d356"),
 ("the principal cause for the low state of Garcia’s public image", "1961–1963, Volume XXIII", 356, "frus1961-63v23", "d356"),
 ("As we have watched corruption mount we have asked ourselves what we might do to counter it—not from any moralistic concern, but as a means of guarding U.S. interests.", "1969–1976, Volume E–9, Part 2", 122, "frus1969-76ve09p2", "d122"),
 ("Our own U.S. government reputation for incorruptability may one day prove to be our most valued asset in Saudi Arabia", "1969–1976, Volume E–9, Part 2", 122, "frus1969-76ve09p2", "d122"),
 ("Problems arising from publicity over the enormous commissions being paid by American firms to promote sales of defense articles and services to the Saudi Government threaten to strain US-Saudi relations", "1969–1976, Volume E–9, Part 2 (same volume)", 155, "frus1969-76ve09p2", "d155"),
 ("The Department just learned of the bribe. It refused to help cover it up.", "1969–1976, Volume E–11, Part 1", 159, "frus1969-76ve11p1", "d159"),
 ("At that point apparently, Lockheed bribed Prince Bernard to weigh in with the Germans.", "1969–1976, Volume E–15, Part 2", 292, "frus1969-76ve15p2", "d292"),
 ("As a nation we have decided that bribery in international trade is reprehensible and that American companies must forego exports that can be attained only by illicit payments.", "1977–1980, Volume III", 248, "frus1977-80v03", "d248"),
]
# resolve each printed citation through manifest.json (title holds the printed volume designation) and document_cache.document_number
man = {v["filename"][:-4]: v for v in json.load(open(RES + "/manifest.json"))}
def resolve(printed_vol, printed_num):
    pv = printed_vol.replace(" (same volume)", "")
    cands = [vid for vid, v in man.items() if re.sub(r"\s+", " ", v["title"]).find(pv) >= 0 and not vid.endswith("Ed2")]
    out = []
    for vid in cands:
        r = con.execute("SELECT document_id FROM document_cache WHERE volume_id=? AND document_number=?", (vid, str(printed_num))).fetchall()
        out += [(vid, d) for (d,) in r]
    return cands, out

print("== OVERVIEW QUOTATIONS (14 quoted passages attributed to a document; the 6 search-term quotes and the 3 stemmer examples carry no citation and are listed in notes) ==")
fab = mis = ok = 0
for qte, pv, num, v, d in OV:
    cands, pairs = resolve(pv, num)
    res, why = check(qte, v, d)
    resolves = (v, d) in pairs
    tag = "OK" if res and resolves else ("FABRICATION" if not res else "MIS-CITATION")
    if tag == "OK": ok += 1
    elif tag == "FABRICATION": fab += 1
    else: mis += 1
    print(tag, "|", v, d, "| printed:", pv, "Doc", num, "-> manifest candidates", cands, "-> pairs", pairs, "|", why, "|", qte[:50])
print("overview: ok", ok, "fabrications", fab, "mis-citations", mis, "of", len(OV))

print("\n== COLLECTION EXCERPTS ==")
col = json.load(open(RUN + "collection.fruscollection"))
ex = [(e["volumeId"], e["documentId"], e["text"]) for e in col["entries"] if e["kind"] == "excerpt"]
cok = cfab = 0
for v, d, t in ex:
    res, why = check(t, v, d)
    print("OK" if res else "FABRICATION", "|", v, d, "|", why, "|", t[:50])
    cok += res; cfab += (not res)
print("collection excerpts: ok", cok, "fabrications", cfab, "of", len(ex))

print("\n== memo's quotes.json against the overview's quoted passages ==")
Q = json.load(open(RUN + "quotes.json"))
print("quotes.json entries", len(Q), "| overview document quotations", len(OV), "| collection excerpts", len(ex))
qs = set(q for _, _, q in Q)
for qte, pv, num, v, d in OV:
    if qte not in qs:
        print("  overview passage not verbatim in quotes.json:", repr(qte[:70]), "(memo Q7 is one longer quotation that the overview splits into two)")
