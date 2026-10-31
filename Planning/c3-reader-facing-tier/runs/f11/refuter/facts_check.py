import sqlite3, re, json
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f11/"
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
c = json.load(open(RUN + "collection.fruscollection"))
pairs = [(e["volumeId"], e["documentId"]) for e in c["entries"] if e["kind"] == "document"]
CHECKS = {
 ("frus1949v07p2", "d386"): [r"Jessup", r"nationalis", r"imperialis", r"non-Communist", r"1949"],
 ("frus1952-54v12p2", "d403"): [r"Psychological Strategy Board", r"Thailand", r"guerrilla", r"indigenous leadership", r"aid"],
 ("frus1955-57v09", "d189"): [r"Washburn", r"Acting Director", r"Geneva", r"all (USIS )?posts|circular|To all", r"neutralism"],
 ("frus1917-72PubDipv06", "d135"): [r"nuclear", r"Chinese|ChiCom|Communist China", r"all posts|circular|Unclassified|To:", r"July"],
 ("frus1917-72PubDipv08", "d24"): [r"Midway", r"Thieu", r"public image"],
 ("frus1950v06", "d89"): [r"white troops will always be associated with colonialism", r"survey mission|Survey Mission", r"Joint|Defense", r"December"],
 ("frus1958-60v16", "d65"): [r"NSC 6012", r"relatively privileged positions", r"Hold or reduce the number of U\.S\. officials", r"July"],
 ("frus1917-72PubDipv07", "d32"): [r"Tull", r"peasants", r"family-oriented"],
 ("frus1964-68v29p2", "d46"): [r"ostrich-like pacifism", r"49 percent", r"40 percent", r"22 percent", r"32 percent", r"52 percent", r"38 percent", r"4 percent", r"8 percent", r"bombing", r"Reischauer", r"Bundy", r"since January", r"neutralis"],
 ("frus1955-57v09", "d190"): [r"Japan", r"placement", r"atomic energy", r"Far East"],
 ("frus1955-57v09", "d207"): [r"Japan", r"dissatisfaction", r"favorable|favourable", r"Kishi"],
 ("frus1964-68v01", "d197"): [r"Rowan", r"28 million", r"Honolulu", r"President"],
 ("frus1917-72PubDipv07", "d73"): [r"elite", r"budget", r"mass"],
 ("frus1917-72PubDipv07", "d100"): [r"Marks", r"huge white nation", r"more action by Asians", r"Rostow"],
 ("frus1917-72PubDipv08", "d88"): [r"637", r"26 percent|26%", r"thirteen", r"23 percent|23%", r"college", r"dependable ally", r"May"],
 ("frus1964-68v29p2", "d123"): [r"Racial violence", r"Tet"],
 ("frus1917-72PubDipv08", "d31"): [r"Manila", r"May", r"conference|Conference", r"America watchers", r"bi-lateral relations"],
 ("frus1917-72PubDipv08", "d149"): [r"overseas Chinese|Overseas Chinese", r"emotional pull", r"ideological"],
 ("frus1969-76ve12", "d10"): [r"Smyser", r"Nixon Doctrine", r"adjusting", r"Kissinger"],
 ("frus1969-76v38p2", "d105"): [r"Hong Kong", r"Japan", r"very clearly in default", r"written off", r"Indochina"],
 ("frus1977-80v22", "d104"): [r"ASEAN", r"Japan", r"no interest", r"reassess", r"Sullivan"],
 ("frus1977-80v30", "d79"): [r"Administration believes", r"staying power", r"Smith", r"Bray"],
 ("frus1977-80v30", "d81"): [r"Holbrooke", r"Vance", r"views", r"public diplomacy|Public Diplomacy", r"Assistant Secretary"],
 ("frus1977-80v30", "d83"): [r"withdrawing", r"deeply implanted", r"Jakarta"],
 ("frus1977-80v30", "d152"): [r"exchange", r"film", r"book", r"Beijing|Peking", r"ICA"],
}
for v, d in pairs:
    r = db.execute("SELECT document_number, header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    dt = db.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    full = re.sub(r"\s+", " ", (r[1] or "") + " | " + (r[2] or "") + " | " + (r[3] or "") + " || " + (r[4] or ""))
    print("\n### %s/%s  docnum=%s  date_iso=%s" % (v, d, r[0], dt[0] if dt else None))
    print("  HEADER:", re.sub(r"\s+", " ", r[1])[:220])
    print("  DATELINE:", (r[2] or "")[:120])
    print("  SOURCE:", re.sub(r"\s+", " ", r[3] or "")[:300])
    for pat in CHECKS.get((v, d), []):
        ms = list(re.finditer(pat, full))
        if not ms:
            print("   -- MISSING /%s/" % pat)
        else:
            m = ms[0]
            print("   ok /%s/ x%d: ...%s..." % (pat, len(ms), full[max(0, m.start() - 90):m.end() + 110]))
