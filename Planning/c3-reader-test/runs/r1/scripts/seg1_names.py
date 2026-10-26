# list distinct first-level section titles (all volumes up to 1931 and pre-1932 style) that do NOT match the Latin American regex, with total doc counts, to find missed spellings
import re, collections, sys
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
exec(open("/Users/jbotts/frus-analysis/c3/runs/r1/scripts/latam_sections.py").read().split("latrx =")[0].split("LAT = ")[1].join(["LAT = ", ""]) if False else "")
LAT = r"^(argentina|bolivia|brazil|chile|colombia|costa rica|cuba|dominican republic|santo domingo|ecuador|el salvador|salvador|guatemala|haiti|honduras|mexico|nicaragua|panama|paraguay|peru|uruguay|venezuela|central america|latin america|american republics|the american republics|western hemisphere|guyana|british guiana|british honduras|surinam|suriname|grenada|jamaica|trinidad|bahamas|barbados|belize|puerto rico|caribbean|south america|hispaniola)\b"
latrx = re.compile(LAT, re.I)
cnt = collections.Counter(); vols = collections.defaultdict(set)
for line in open("/Users/jbotts/frus-analysis/c3/runs/r1/work/structure_flat.tsv"):
    v, d, p = line.rstrip("\n").split("\t")
    if v == "volume_id": continue
    yr = re.match(r"frus(\d{4})", v)
    if not yr or int(yr.group(1)) > 1931: continue
    s1 = p.split(" > ")[0].strip()
    if not latrx.search(s1):
        cnt[s1] += 1; vols[s1].add(v)
names = sorted(cnt)
print(len(names), "distinct non-matching first-level titles (pre-1932 volumes)")
print(" | ".join("%s(%d)" % (n[:40], cnt[n]) for n in names))
