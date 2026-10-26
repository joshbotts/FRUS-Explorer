import sqlite3, json, re, sys
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
def norm(s): return re.sub(r'[^a-z0-9]', '', s.lower())
def doc_text(v, d):
    r = con.execute("SELECT header, dateline, source_note, body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (v,d)).fetchone()
    if not r: return None, None
    return ''.join(x or '' for x in r[:4]), (r[4], r[5])
def check(q, v, d):
    t, flags = doc_text(v, d)
    if t is None: return ('NO SUCH ROW', None)
    segs = [s for s in re.split(r'…|\.\.\.|\[\.\.\.\]', q) if norm(s)]
    nt = norm(t); pos = 0; offs=[]
    for s in segs:
        i = nt.find(norm(s), pos)
        if i < 0: return ('FAIL segment %r' % s[:60], flags)
        offs.append(i); pos = i + len(norm(s))
    return ('OK offsets=%s' % offs, flags)

# (label, quotation, volume, document) -- overview spans mapped by the memo's trace / the URL in the same sentence
overview = [
 ("ov1 'usual tests' (bottom line, Huerta)", "usual tests", "frus1913", "d894"),
 ("ov6 (F1)", "the de facto authority administering the public affairs of the State with the general acquiescence of its people and controlling the machinery of government to that end", "frus1895p1", "d244"),
 ("ov7 (F1)", "in accordance with the traditional policy of this Government", "frus1895p1", "d244"),
 ("ov8 (F1)", "these provisional governments are de facto in control of their respective countries, and that there is no active resistance to their rule. Each of the present governments has also made it clear that it is its intention to fulfill its respective international obligations and to hold, in due course, elections to regularize its status", "frus1930v01", "d375"),
 ("ov9 (F1)", "three conditions viz. “de facto” control, ability and willingness meet obligations, and acquiescence great majority of people", "frus1949v02", "d439"),
 ("ov11 (F2)", "Cooperation is possible only when supported at every turn by the orderly processes of just government based upon law, not upon arbitrary or irregular force", "frus1913", "d7"),
 ("ov12 (F2)", "will not give recognition or support to any Government which may be established unless it is clearly proven that it is elected by legal and constitutional means", "frus1917", "d378"),
 ("ov13 (F2)", "into power in any of the five Republics as a consequence of a coup d’état, or of a revolution against the recognized Government", "frus1917", "d414"),
 ("ov14 (F2)", "is not related through consanguinity to one of the leaders of the revolution as specified in Clause 1 of Article II of the Treaty", "frus1932v05", "d623"),
 ("ov15 (F2)", "the United States should no longer be guided by Article II of the General Treaty of Peace and Amity of 1923 in extending or denying recognition to Governments in Central America", "frus1936v05", "d112"),
 ("ov16 (F3)", "it was necessary to have a proper and final interpretation of Article 27 of the Constitution to the effect that this Article shall not be retroactive", "frus1920v03", "d225"),
 ("ov17 (F3)", "when it appears that there is a government in Mexico willing to bind itself to the discharge of primary international obligations, concurrently with that act its recognition will take place", "frus1921v02", "d344"),
 ("ov18 (F4)", "it was not my Government’s intention or desire to bargain with the new Government or to impose a break in relations with the Axis as a condition precedent to recognition", "frus1943v05", "d335"),
 ("ov19 (F4)", "consultation is automatically called for by the mere fact of a revolutionary change of government. The subject of the consultations is whether there is evidence in the possession of any government of Axis inspiration or tendencies", "frus1944v07", "d1023"),
 ("ov20 (F4)", "the pro-Nazi record of the MNR leaders made recognition by the other American republics impossible. There is now no MNR official in any position of prominence in Bolivia", "frus1944v07", "d432"),
 ("ov22 (F5)", "That the establishment or maintenance of diplomatic relations with a government does not imply any judgment upon the domestic policy of that government", "frus1948v09", "d74"),
 ("ov23 (F5)", "In the absence of any compelling reason to the contrary, it is desirable for the United States to maintain diplomatic relations with all Latin American governments", "frus1948v09", "d89"),
 ("ov24 (F5)", "appears free from Communist taint and there are indications that it intends to pursue friendly relations with the United States", "frus1958-60v06", "d217"),
 ("ov25 (F5)", "led the junta to take a position with respect to new elections, with respect to current civil rights", "frus1961-63v12", "d421"),
 ("ov26 (F5)", "take the public position that we recognize governments, not heads of government, and that question of recognition has not arisen", "frus1969-76v21", "d348"),
]
print("=== OVERVIEW QUOTATIONS (%d) ===" % len(overview))
bad=0
for lab,q,v,d in overview:
    res, flags = check(q,v,d)
    if not res.startswith('OK'): bad+=1
    print(f"{lab:45s} {v}/{d:6s} fm/en={flags} -> {res}")
print("overview failures:", bad)

print("\n=== COLLECTION EXCERPTS ===")
coll = json.load(open('/Users/jbotts/frus-analysis/c3/runs/r4/collection.fruscollection'))
ex = [e for e in coll['entries'] if e['kind']=='excerpt']
bad=0
for e in ex:
    res, flags = check(e['text'], e['volumeId'], e['documentId'])
    if not res.startswith('OK'): bad+=1
    print(f"{e['volumeId']}/{e['documentId']:6s} fm/en={flags} -> {res}   | {e['text'][:50]!r}")
print(len(ex), "excerpts; failures:", bad)

print("\n=== EXCERPT == memo quotes.json? ===")
qj = json.load(open('/Users/jbotts/frus-analysis/c3/runs/r4/quotes.json'))
print("quotes.json type:", type(qj).__name__, "len", len(qj))
print(json.dumps(qj, ensure_ascii=False)[:600])

print("\n=== BONUS: quoted phrases inside collection notes/prose ===")
for lab,q,v,d in [("note d894 'usual tests'", "usual tests", "frus1913","d894"),
                  ("note d344 'a subordinate one'", "a subordinate one", "frus1921v02","d344"),
                  ("prose Acheson 'recognition does not imply approval' vs frus1950v02/d476 (memo's grab)", "recognition does not imply approval", "frus1950v02","d476")]:
    res, flags = check(q,v,d); print(f"{lab:85s} -> {res}")

print("\n=== search-term phrases quoted in the overview (no document credited) ===")
for lab in ["international obligations","the other American republics","human rights","recognition","by force","Department of State"]:
    print(lab)
