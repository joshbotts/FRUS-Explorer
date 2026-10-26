# Build work/quotes.tsv: each quotation is the exact substring of document_cache.body_text between a start marker and an end marker (inclusive).
# The body text is re-read here with an explicit SELECT (logged) and the substring is checked to occur exactly once, to contain no line break, and to equal the file raw/<vol>__<doc>.body.txt slice.
import sys, re
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
Q = [
 ("Q01", 1, "frus1900", "d530", "the rule of the United States is to defer recognition", "under treaties and international law."),
 ("Q02", 1, "frus1948v09", "d7", "(a) de facto control of the territory", "in the government in power."),
 ("Q03", 1, "frus1948v09", "d7", "Recognition should not be withheld as a political weapon", "would be served thereby."),
 ("Q05", 1, "frus1949v02", "d489", "This Government, furthermore, is of the opinion that nonrecognition", "strengthening democratic governments."),
 ("Q06", 2, "frus1913", "d7", "just government rests always upon the consent of the governed", "public conscience and approval."),
 ("Q07", 2, "frus1931v02", "d232", "The Department has stated on various occasions", "as President of Salvador."),
 ("Q08", 2, "frus1936v05", "d109", "Under our new policy, if General Somoza headed", "under the 1923 Treaty."),
 ("Q09", 3, "frus1877", "d222", "In the present case it waits before recognizing General Diaz", "obligations of treaties."),
 ("Q10", 3, "frus1932v05", "d518", "You are correct in your understanding that the policy of this Government is not to associate recognition", "set by international law and practice."),
 ("Q11", 4, "frus1961-63v12", "d359", "to secure their agreement prior to our recognition or resumption of aid", "as President."),
 ("Q12", 5, "frus1944v07", "d388", "You should indicate to the Minister of Foreign Affairs", "will recognize the new regime."),
 ("Q13", 5, "frus1944v07", "d1090", "Recognition of the new Administration in El Salvador", "present Government of Argentina."),
 ("Q14", 5, "frus1948v09", "d115", "(d) In the light of the above, it seems evident to us that non-recognition", "Venezuela at this time."),
 ("Q15", 6, "frus1955-57v06", "d354", "While fully appreciating significance of fair and free elections", "pledge from Junta."),
 ("Q16", 6, "frus1955-57v06", "d354", "does not wish to find itself recognizing a new de facto regime every few weeks", "international obligations."),
 ("Q17", 6, "frus1964-68v31", "d518", "The Military Government is in full control", "traditional tests for recognition."),
 ("Q18", 6, "frus1969-76v21", "d361", "Right now would be a good time. They have satisfied the requirements.", "They have satisfied the requirements."),
 ("Q19", 4, "frus1934v05", "d85", "This Government will recognize a Cuban provisional Government", "normal functions of Government."),
 ("Q20", 3, "frus1921v02", "d344", "In short, when it appears that there is a government in Mexico", "its recognition will take place."),
]
conn = frus.connect()
out = open(frus.RUN + "/work/quotes.tsv", "w")
out.write("qid\tfinding\tvolume_id\tdocument_id\tchars\ttext\n")
bad = 0
for qid, f, v, d, a, b in Q:
    r = frus.sql(conn, "SELECT body_text FROM document_cache WHERE volume_id = ? AND document_id = ?", (v, d), script="scripts/extract_quotes.py")
    t = r[0][0]
    i = t.find(a)
    if i < 0 or t.count(a) != 1:
        print(qid, "START MARKER problem", t.count(a)); bad += 1; continue
    j = t.find(b, i)
    if j < 0:
        print(qid, "END MARKER problem"); bad += 1; continue
    q = t[i:j + len(b)]
    raw = open("%s/raw/%s__%s.body.txt" % (frus.RUN, v, d)).read()
    ok = (q in raw) and ("\n" not in q) and (q in t)
    if not ok: bad += 1
    out.write("%s\t%d\t%s\t%s\t%d\t%s\n" % (qid, f, v, d, len(q), q))
    print("%s F%d %s/%s (%d chars) %s" % (qid, f, v, d, len(q), "OK" if ok else "PROBLEM"))
out.close()
print("problems:", bad)
