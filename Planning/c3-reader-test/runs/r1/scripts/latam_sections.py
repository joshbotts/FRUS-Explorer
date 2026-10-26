# for each volume, count documents in Latin American sections (country-name path segment) from work/structure_flat.tsv; write work/latam_by_volume.tsv
import re, collections, json
LAT = r"^(argentina|bolivia|brazil|chile|colombia|costa rica|cuba|dominican republic|santo domingo|ecuador|el salvador|salvador|guatemala|haiti|honduras|mexico|nicaragua|panama|paraguay|peru|uruguay|venezuela|central america|greater republic of central america|guatemala and honduras|latin america|american republics|the american republics|western hemisphere|guyana|british guiana|british honduras|surinam|suriname|grenada|jamaica|trinidad|bahamas|barbados|belize|dominica|guadeloupe|martinique|puerto rico|caribbean|south america|hispaniola|nicaragua, salvador|uruguay and paraguay|colombia and venezuela|costa rica and nicaragua|honduras and nicaragua|mexico and|brazil and|argentina and|chile and|peru and|bolivia and|ecuador and)\b"
latrx = re.compile(LAT, re.I)
tot = collections.Counter(); lat = collections.Counter()
for line in open("/Users/jbotts/frus-analysis/c3/runs/r1/work/structure_flat.tsv"):
    v, d, p = line.rstrip("\n").split("\t")
    if v == "volume_id":
        continue
    tot[v] += 1
    segs = [s.strip() for s in p.split(" > ")]
    if any(latrx.search(s) for s in segs):
        lat[v] += 1
with open("/Users/jbotts/frus-analysis/c3/runs/r1/work/latam_by_volume.tsv", "w") as f:
    f.write("volume_id\tdocs_in_sections\tdocs_in_latam_sections\n")
    for v in sorted(tot):
        f.write("%s\t%d\t%d\n" % (v, tot[v], lat[v]))
print(sum(1 for v in tot if lat[v] > 0), "volumes with some Latin American section;", sum(lat.values()), "document ids in them")
