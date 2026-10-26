# List central-files-index.json countrySeries file units (fileUnitTitle, fileUnitNaId, date span) whose geoKeys name
# the Latin American countries of the pre-1906 scope documents, for the diplomaticDespatches and
# diplomaticInstructions categories (the series a minister's despatch or the Secretary's instruction was filed in).
import json, collections
cf = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/central-files-index.json"))
want = {"peru", "mexico", "venezuela", "ecuador", "colombia", "dominican republic", "haiti", "honduras", "central america",
        "guatemala", "paraguay", "bolivia", "salvador", "el salvador", "nicaragua", "costa rica", "argentina", "chile", "brazil", "uruguay"}
for cat in cf["countrySeries"]:
    if cat["category"] not in ("diplomaticDespatches", "diplomaticInstructions"): continue
    units = collections.OrderedDict()
    for r in cat["rolls"]:
        g = set(r.get("geoKeys") or [])
        if g & want:
            u = (r.get("fileUnitTitle"), r.get("fileUnitNaId"))
            a = units.setdefault(u, ["9999", "0000", 0])
            if r.get("startISO"): a[0] = min(a[0], r["startISO"])
            if r.get("endISO"): a[1] = max(a[1], r["endISO"])
            a[2] += 1
    print("==", cat["category"], cat["displayName"], "file units:", len(units))
    for (t, n), (a, b, k) in units.items():
        print("   %s | fileUnit NAID %s | rolls %d | %s..%s" % (t, n, k, a, b))
