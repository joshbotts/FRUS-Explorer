# (1) presidential-library-catalog.json: collections whose title matches the library series cited by the scope's
#     came-from rows (National Security File(s), NSC Files, Whitman File, National Security Affairs...).
# (2) subject-numeric-labels.json: gloss the scope's subject-numeric keys (POL 16 ARG etc.) with the schedule that
#     governs each DOCUMENT's date (coverage.glossableYears), never across schedules.
import json, re, collections
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
pl = json.load(open(RES + "presidential-library-catalog.json"))
want = {"Kennedy Library": r"National Security Files|President.s Office Files", "Johnson Library": r"National Security File|Mann",
        "Nixon": r"NSC|National Security Council", "Eisenhower Library": r"Whitman|Ann Whitman|Special Assistant for National Security|Herter|Project .Clean Up",
        "Carter Library": r"National Security Affairs|National Security Council|Brzezinski"}
for lib in pl["libraries"]:
    for k, pat in want.items():
        if k.split()[0] in lib["citedAs"]:
            for c in lib["collections"]:
                if re.search(pat, c["title"], re.I):
                    print("%s | %s | collection NAID %s | id %s | series: %s" % (lib["citedAs"], c["title"], c.get("naId"), c.get("identifier"),
                          "; ".join("%s (%s, NAID %s)" % (s["title"], s.get("inclusiveDates"), s.get("naId")) for s in c.get("series", [])[:6])))
sn = json.load(open(RES + "subject-numeric-labels.json"))
print("subject-numeric coverage:", json.dumps(sn["coverage"])[:1500])
for s in sn["schedules"]:
    print("schedule", s.get("id"), "keys:", sorted(s.keys()))
def gloss(key, year):
    sid = next((g["scheduleId"] for g in sn["coverage"]["glossableYears"] if g["startYear"] <= year <= g["endYear"]), None)
    if not sid: return "no gloss (year %d outside glossable years)" % year
    s = next(x for x in sn["schedules"] if x.get("id") == sid)
    m = re.match(r"^([A-Z]+)\s*([0-9\-]+)?\s*(.*)$", key)
    cat, num, area = m.groups()
    cats = s.get("categories", {})
    c = cats.get(cat)
    head = None
    if isinstance(c, dict):
        subs = c.get("subjects") or c.get("headings") or {}
        head = subs.get(num) if num else None
        cname = c.get("name") or c.get("title")
    else:
        cname = c
    return "%s | %s | %s | area %s=%s" % (sid, cname, head, area, s.get("areas", {}).get(area.split(",")[0].strip()) if area else "")
for line in open(R + "out/18_ds_S2.tsv"):
    f = line.rstrip("\n").split("\t")
    if len(f) > 10 and f[8] == "subject_numeric" or (len(f) > 10 and re.match(r"^[A-Z]{2,4} \d", f[10] or "")):
        print("SN", f[0] + "/" + f[1], f[2], repr(f[10]), "->", gloss(f[10], int(f[2][:4])) if f[10] else "(no key)")
