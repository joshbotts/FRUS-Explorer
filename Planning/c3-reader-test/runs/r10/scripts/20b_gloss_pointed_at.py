# Gloss the came-from decimal classes of the scope S2 (out/21_ec_S2.tsv, from document_sources) with
# decimal-class-labels.json, honoring its gate: a key is glossed only against the schedule whose span holds the
# DOCUMENT's own date (date_iso year); outside the glossable years (1910-1963) it is reported as "no gloss".
# Country = the two (or more) characters after the class digit, read against the schedule's countries table;
# subject = the part after the point, read against the schedule's class subjects where the file ships them
# (only class 8 / 6 of 1910-1949); otherwise the subject is left unglossed, never composed.
import json, collections, re
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
d = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/decimal-class-labels.json"))
sched = {s["id"]: s for s in d["schedules"]}
spans = [(g["startYear"], g["endYear"], g["scheduleId"]) for g in d["coverage"]["glossableYears"]]
def gloss(key, year):
    sid = next((s for a, b, s in spans if a <= year <= b), None)
    if not sid: return None, "no gloss (document year %d outside glossable years)" % year
    s = sched[sid]
    m = re.match(r"^(\d)(\d\d[a-z]?)\.?(.*)$", key)
    if not m: return sid, "unparsed key"
    cls, ctry, subj = m.groups()
    cl = s["classes"].get(cls, "?")
    if cls not in s["countryArrangedClasses"]:
        return sid, "%s (class %s; not country-arranged)" % (cl, cls)
    cn = s["countries"].get(ctry, "country %s?" % ctry)
    sub = s["subjects"].get(cls, {})
    sg = sub.get(subj) if subj else None
    if sg is None and subj:
        sg = "[subject %s not glossed by the file]" % subj
    return sid, "%s — %s — %s" % (cl, cn, sg or "")
agg = collections.Counter(); ex = {}; nog = collections.Counter()
for line in open(R + "out/21_ec_S2.tsv"):
    f = line.rstrip("\n").split("\t")
    v, dd, di, dc = f[0], f[1], f[2], (f[13] if len(f) > 13 else "")
    if not dc: continue
    y = int(di[:4]) if di else 0
    sid, g = gloss(dc, y)
    if sid is None:
        nog[dc] += 1; continue
    agg[(sid, dc[:dc.index(".")] if "." in dc else dc, g)] += 1
    ex.setdefault((sid, dc[:dc.index(".")] if "." in dc else dc, g), "%s/%s" % (v, dd))
print("pointed-at (external_citations) decimal classes in S2, glossed by the schedule governing each document's date")
for (sid, pre, g), n in sorted(agg.items(), key=lambda x: -x[1])[:45]:
    print("%4d  %s  %s  %s  e.g. %s" % (n, sid, pre, g, ex[(sid, pre, g)]))
print("documents whose class falls outside the glossable years:", sum(nog.values()), nog.most_common(10))
