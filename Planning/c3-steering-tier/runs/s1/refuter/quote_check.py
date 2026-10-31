import json, re, sqlite3
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con = sqlite3.connect(DB, uri=True)

def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())

def doc_text(v, d):
    r = con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    if r is None:
        return None
    return norm("".join(x or "" for x in r))

def check(q, v, d):
    t = doc_text(v, d)
    if t is None:
        return "NO SUCH ROW"
    segs = [s for s in re.split(r"…|\.\.\.|\[\.\.\.\]", q) if norm(s)]
    pos = 0
    for s in segs:
        i = t.find(norm(s), pos)
        if i < 0:
            return "FAIL at segment: " + s[:60]
        pos = i + len(norm(s))
    return "OK (%d segment%s)" % (len(segs), "" if len(segs) == 1 else "s")

# every passage inside quotation marks in overview.md attributed to a document, with the pair of the
# URL cited beside it (the memo's trace table gives the same pairs: Q-id -> pair)
overview = [
 ("OV-01", "frus1950v06", "d832", "We said that as we started through the Government departments and as we visited the provinces, we could not very well ignore the question of graft and corruption."),
 ("OV-02", "frus1961-63v23", "d358", "Mr. Johnson opened the discussion by expressing the concern of high-level U.S. officials with respect to corruption in the present Philippine administration. He pointed out that the Philippines could not assume a role of leadership in Asia until there was a change for the better."),
 ("OV-03", "frus1977-80v23", "d252", "it is the toughest, most ambitious U.S. aid package ever presented to the GOH, and one which focuses squarely on one of the most important factors in Haiti’s development equation today: corruption."),
 ("OV-04", "frus1964-68v05", "d258", "As the Committee points out, in order to effect rapid reduction in corruption the United States would have to acquire, and be willing to exercise, at least the power to veto appointments of Province Chiefs and ARVN officers of divisional commander rank and responsibility."),
 ("OV-05", "frus1964-68v05", "d258", "I do not think it would be wise for us to seek such control."),
 ("OV-06", "frus1964-68v05", "d197", "“Most of the generals are corrupt. Most of the senior officials in the provinces are corrupt. But getting at corruption takes time. And you must remember that corruption exists everywhere, and people can live with some of it. You live with it in Chicago and New York.”"),
 ("OV-07", "frus1969-76v06", "d175", "The inability of the GVN to do anything about high level corruption is sharply affecting my ability—the American ability—to help you."),
 ("OV-08", "frus1969-76ve09p2", "d122", "as a means of guarding U.S. interests."),
 ("OV-09", "frus1969-76ve09p2", "d122", "As we have watched corruption mount we have asked ourselves what we might do to counter it—not from any moralistic concern, but as a means of guarding U.S. interests."),
 ("OV-10", "frus1969-76ve09p2", "d122", "If, with the passage of time, the Sa’uds become widely identified with corruption, they will become more vulnerable politically."),
 ("OV-11", "frus1969-76v27", "d45", "It was quite clear from this discussion that the Shah indeed is convinced that his program and the country’s future will go right downhill if he is not able to deal with the corruption issue."),
 ("OV-12", "frus1977-80v18", "d206", "The problem of corruption is a difficult one and I do not know of any truly effective means that we can use to help correct the situation."),
 ("OV-13", "frus1969-76ve11p1", "d159", "United Brands asked us to intercede with the SEC to keep the information confidential. We refused. United Brands also asked us to approach the GOH. We refused this too."),
 ("OV-14", "frus1969-76ve09p2", "d161", "Sultan said the names cannot rpt not ever be revealed."),
 ("OV-15", "frus1969-76ve12", "d219", "We are prepared to make arrangements to share with your government the information developed by the SEC, in the course of its inquiry."),
 ("OV-16", "frus1943China", "d202", "Nepotism and favoritism are rife. Graft and bribery are commonplace."),
 ("OV-17", "frus1961-63v22", "d244", "Military government’s efforts to deal with wholesale graft, bribery and corruption in government and business, smuggling, large-scale diversion of military supplies, hoodlum terror, and police and press blackmail of individuals are genuine and are producing results."),
 ("OV-18", "frus1961-63v22", "d249", "They have produced convincing evidence that they will not tolerate corruption, graft, bribes, smuggling, tax evasion, or political blackmail in government, military or civilian life."),
]
# confirm each overview quotation is literally present in overview.md
ov = open("/Users/jbotts/frus-analysis/c3s/runs/s1/overview.md", encoding="utf-8").read()
print("== overview quotations ==")
ok = 0
for qid, v, d, q in overview:
    present = q in ov
    res = check(q, v, d)
    ok += res.startswith("OK")
    print(qid, f"{v}/{d}", "in-overview:", present, "|", res, "|", q[:50])
print("overview quotations verified:", ok, "of", len(overview))

print("\n== collection excerpts ==")
c = json.load(open("/Users/jbotts/frus-analysis/c3s/runs/s1/collection.fruscollection", encoding="utf-8"))
ex = [e for e in c["entries"] if e["kind"] == "excerpt"]
ok2 = 0
for i, e in enumerate(ex, 1):
    res = check(e["text"], e["volumeId"], e["documentId"])
    ok2 += res.startswith("OK")
    print("EX-%02d" % i, f"{e['volumeId']}/{e['documentId']}", res, "|", e["text"][:50], "| in overview:", e["text"] in ov)
print("collection excerpts verified:", ok2, "of", len(ex))

print("\n== quoted fragments inside collection notes (extra, not required) ==")
for e in c["entries"]:
    if e["kind"] == "document":
        for n in e.get("notes", []):
            for frag in re.findall(r"'([^']{6,})'", n):
                print(f"{e['volumeId']}/{e['documentId']}", repr(frag), check(frag, e["volumeId"], e["documentId"]))

print("\n== cross-check: do the quotations also sit in some OTHER document? (segment check over every row that holds the first 40 normalised chars) ==")
for qid, v, d, q in overview:
    key = norm(q)[:40]
    n = 0
    for vv, dd, h, dl, sn, b in con.execute("SELECT volume_id, document_id, header, dateline, source_note, body_text FROM document_cache WHERE body_text LIKE ?", ("%" + q[:25].replace("’", "_") + "%",)):
        if key in norm("".join(x or "" for x in (h, dl, sn, b))) and (vv, dd) != (v, d):
            n += 1
            print("  ", qid, "also in", vv, dd)
    if n == 0:
        print("  ", qid, "unique to", v, d)
