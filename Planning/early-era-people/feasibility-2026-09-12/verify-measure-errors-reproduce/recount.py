import json, collections, re
E = json.load(open("/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/measure-errors/errors.json"))
def C(items, f): return collections.Counter(f(x) for x in items)
for arm in ("filtered_control", "filtered_sweep"):
    fps = E["arms"][arm]["false_positives"]; ms = E["arms"][arm]["misses"]
    print("=====", arm, "FP", len(fps), "misses", len(ms))
    print(" fp cat:", dict(C(fps, lambda x: x["category"]).most_common()))
    print(" fp cat by band:", {b: dict(C([x for x in fps if x["band"] == b], lambda x: x["category"]).most_common()) for b in sorted({x["band"] for x in fps})})
    print(" fp band totals:", dict(C(fps, lambda x: x["band"])))
    VR = {"place", "institution", "title-only", "pronoun-common", "other:document-furniture", "other:date", "other:calendar-month"}
    NC = {"partial-name-boundary", "ship-treaty-conference", "other:citation-caption-name"}
    v = sum(1 for x in fps if x["category"] in VR); n = sum(1 for x in fps if x["category"] in NC)
    print(" vocab-removable %d/%d=%.3f needs-context %d/%d=%.3f other %d" % (v, len(fps), v/len(fps), n, len(fps), n/len(fps), len(fps)-v-n))
    print(" danger tiers:", dict(C(fps, lambda x: x["danger_tier"])), "A excl nested:", sum(1 for x in fps if x["danger_tier"]=="A" and x["category"]!="partial-name-boundary"))
    print(" danger A surfaces (excl nested):", sorted((x["n"], x["v"]+"/"+x["d"]) for x in fps if x["danger_tier"]=="A" and x["category"]!="partial-name-boundary"))
    print(" danger B surfaces:", sorted((x["n"], x["v"]+"/"+x["d"]) for x in fps if x["danger_tier"]=="B"))
    print(" nested-dup surfaces:", [x["n"] for x in fps if x["category"]=="partial-name-boundary"])
    print(" overlaps_gold on nested:", [x["overlaps_gold"] for x in fps if x["category"]=="partial-name-boundary"], "overlaps_gold on non-nested FPs:", sum(1 for x in fps if x["overlaps_gold"] and x["category"]!="partial-name-boundary"))
    print(" person-gold-missed:", sum(1 for x in fps if x["category"]=="person-gold-missed"))
    for cat in ("ship-treaty-conference", "other:citation-caption-name", "other:document-furniture", "other:date", "other:calendar-month", "title-only", "institution", "pronoun-common", "place"):
        surf = C([x for x in fps if x["category"]==cat], lambda x: x["n"])
        print("  %s (%d):" % (cat, sum(surf.values())), surf.most_common(40 if cat in ("place","institution","title-only","pronoun-common") else 20))
    inst = [x for x in fps if x["category"]=="institution"]
    gw = re.compile(r"govern|govt|gov\b|embassy|emb\b|legation|leg\b|ministry|fleet|army", re.I)
    print(" institution w/ govt-word: %d of %d" % (sum(1 for x in inst if gw.search(x["n"])), len(inst)))
    tit = [x for x in fps if x["category"]=="title-only"]
    print(" title-only multiword: %d of %d" % (sum(1 for x in tit if len(x["n"].split())>1), len(tit)))
    print(" miss cat:", dict(C(ms, lambda x: x["category"]).most_common()))
    print(" miss by band:", {b: dict(C([x for x in ms if x["band"]==b], lambda x: x["category"]).most_common()) for b in sorted({x["band"] for x in ms})})
    print(" miss flags:", dict(C([f for x in ms for f in x["flags"]], lambda f: f)))
    print(" miss editor_covers:", sum(1 for x in ms if x["editor_covers"]), "by cat:", {c: (sum(1 for x in ms if x["category"]==c and x["editor_covers"]), sum(1 for x in ms if x["category"]==c)) for c in sorted({x["category"] for x in ms})})
    print(" miss editor_covers by band:", dict(C([x for x in ms if x["editor_covers"]], lambda x: x["band"])))
    print(" miss found by other arms:", {o: sum(1 for x in ms if o in x["found_by_other_arms"]) for o in ("filtered_control","filtered_sweep","raw_sweep","raw_control")})
    print(" miss docs for danger docs:", C([x for x in fps if x["danger_tier"]=="A" and x["category"]!="partial-name-boundary"], lambda x: x["v"]+"/"+x["d"]).most_common())
rs = E["summary"]["raw_sweep"]
print("===== raw_sweep:", rs["fp_by_filter_rule"], "removed", rs["fp_removed_by_filter"], "shared misses", rs["misses_shared_with_filtered_sweep"])
print(rs["fp_surface_frequency_top40"][:24])
