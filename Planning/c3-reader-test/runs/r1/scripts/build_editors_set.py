# Add table editors_recog(volume_id, document_id, heading) to work/scope.db: documents that sit under an editors' heading that names recognition / nonrecognition
# of a government in a Latin American section. Headings that use the word for something else are excluded by the explicit list below.
import re, sqlite3, sys, collections
RUN = "/Users/jbotts/frus-analysis/c3/runs/r1"
LAT = r"^(?:[ivxl]+\.\s*[—–-]?\s*)?(?:argentina|argentine republic|bolivia|brazil|chile|chili|colombia|united states of colombia|costa rica|cuba|dominican republic|dominion republic|santo domingo|san domingo|ecuador|el salvador|salvador|guatemala|haiti|hayti|honduras|mexico|nicaragua|panama|paraguay|peru|uruguay|venezuela|central america|central american states|guatemala and honduras|latin america|american republics|the american republics|western hemisphere|caribbean)\b"
latrx = re.compile(LAT, re.I)
RECOG = re.compile(r"recogni|nonrecogni|non-recogni", re.I)
# (volume, substring of the path) pairs whose heading uses 'recognition' in another sense, or recognizes a union of states rather than a government
EXCLUDE = [
 ("frus1896", "Greater Republic of Central America"),
 ("frus1902", "Ecuador > Passports and citizenship"),
 ("frus1902", "Venezuela > Blockade by decree"),
 ("frus1906p2", "Recognition of United States meat-inspection labels"),
 ("frus1907p2", "Recognition of United States meat-inspection labels"),
 ("frus1907p2", "Recognition of Mr. Simon Planas"),
 ("frus1908", "Convention between Colombia and Spain"),
 ("frus1913", "Peru: > Arrest, imprisonment, and deportation"),
 ("frus1919v02", "Declaration by the Mexican Government of nonrecognition of the Monroe Doctrine"),
 ("frus1923v02", "Authorized statement by the Federal District Attorney in Boston"),
 ("frus1936v05", "Refusal of the Department of State to recognize right of an American citizen"),
 ("frus1940v05", "Panama: > Concern of the United States regarding omission"),
]
rows = []
for line in open(RUN + "/work/structure_flat.tsv"):
    v, d, p = line.rstrip("\n").split("\t")
    if v == "volume_id": continue
    segs = [s.strip() for s in p.split(" > ")]
    if not (RECOG.search(p) and any(latrx.search(s) for s in segs)): continue
    if any(v == ev and sub in p for ev, sub in EXCLUDE): continue
    rows.append((v, d, p))
s = sqlite3.connect(RUN + "/work/scope.db")
s.execute("DROP TABLE IF EXISTS editors_recog")
s.execute("CREATE TABLE editors_recog(volume_id TEXT, document_id TEXT, heading TEXT, PRIMARY KEY(volume_id, document_id))")
s.executemany("INSERT OR IGNORE INTO editors_recog VALUES (?,?,?)", rows)
s.commit()
print("rows in table:", s.execute("SELECT COUNT(*) FROM editors_recog").fetchone()[0])
print("distinct headings:", len(set((v, p) for v, d, p in rows)), "volumes:", len(set(v for v, d, p in rows)))
# the headings that were kept
open(RUN + "/work/editors_recog_headings.tsv", "w").write("\n".join("%s\t%s" % k for k in sorted(set((v, p) for v, d, p in rows))) + "\n")
