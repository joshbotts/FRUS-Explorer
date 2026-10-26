# usage: headings_latam.py REGEX -- like headings_grep but only paths with a Latin American country segment; prints distinct (volume, path, ndocs)
import re, sys, collections
LAT = r"^(argentina|bolivia|brazil|chile|colombia|costa rica|cuba|dominican republic|santo domingo|ecuador|el salvador|salvador|guatemala|haiti|honduras|mexico|nicaragua|panama|paraguay|peru|uruguay|venezuela|central america|greater republic of central america|guatemala and honduras|latin america|american republics|the american republics|western hemisphere|guyana|british guiana|british honduras|surinam|suriname|grenada|jamaica|trinidad|bahamas|barbados|belize|dominica|guadeloupe|martinique|puerto rico|caribbean|south america|hispaniola)\b"
latrx = re.compile(LAT, re.I)
rx = re.compile(sys.argv[1], re.I)
mn = int(sys.argv[2]) if len(sys.argv) > 2 else 1
cnt = collections.OrderedDict()
for line in open("/Users/jbotts/frus-analysis/c3/runs/r1/work/structure_flat.tsv"):
    v, d, p = line.rstrip("\n").split("\t")
    segs = [s.strip() for s in p.split(" > ")]
    if any(latrx.search(s) for s in segs) and rx.search(p):
        cnt[(v, p)] = cnt.get((v, p), 0) + 1
print(len(cnt), "distinct (volume, path) headings;", sum(cnt.values()), "document ids")
for (v, p), n in cnt.items():
    if n >= mn:
        print("%s | %d | %s" % (v, n, p[:250]))
