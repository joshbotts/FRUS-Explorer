#!/usr/bin/env python3
"""Hand categorisation of every relaxed FP and miss (read in listing-*.txt), joined back to errors-raw.json.

FP categories: place / institution / title-only / ship-treaty-conference / partial-name-boundary /
person-gold-missed / pronoun-common / other:<detail>.
Miss categories: unmarked-in-prose / correspondence-frame:<header|signature|addressee|salutation|routing> /
OCR-or-odd-spelling / foreign-language / initial-or-abbreviated / title-only-reference / other:<detail>.
Raw-sweep FPs are NOT hand-read: they are categorised by surface frequency and by which frozen filter rule
claims them (filter_detections.rule_for), with the 358 that survive the filter inheriting the hand category.
"""
import json, os, sys, collections
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, os.path.join(REPO, "tools/semantic-harvest"))
os.environ.setdefault("TEXT_DIR", os.path.expanduser("~/frus-semantic-raw/text"))
import filter_detections as fd  # noqa
import ner_store as store  # noqa

raw = json.load(open(os.path.join(HERE, "errors-raw.json")))


def expand(spec):
    """{category: [indices or (lo,hi) inclusive ranges]} -> {index: category}"""
    out = {}
    for cat, items in spec.items():
        for it in items:
            if isinstance(it, tuple):
                for i in range(it[0], it[1] + 1):
                    out[i] = cat
            else:
                out[it] = cat
    return out

# ---------------- filtered control: 60 FPs ----------------
FC_FP = expand({
    "ship-treaty-conference": [0, 1, 33, 35],                       # schooner Anna, the Dee, SS President Harding x2
    "place": [(2, 20), 30, 36, (38, 46), (51, 55)],                 # forts, straits, rivers, cities, provinces; 30 = 'Seville' in 'Commanding General Seville' (audit: names no one)
    "partial-name-boundary": [21],                                  # 'JNO' fragment of gold 'JNO. G. PARKE' (claimed by the control's other fragment)
    "pronoun-common": [(22, 27)],                                   # 'Samoan' x6 (nationality adjective)
    "other:calendar-month": [28],                                   # 'Ramazan 16, 1306'
    "institution": [29, 34, 47, 56],                                # Rickmers Reismühlen Rhederei, Hunzedal (a company), Leg Cairo, Greek Govt
    "other:citation-caption-name": [31, 32],                        # 'Wolf', 'Rudolf' in file-number caption 'Lic. Wolf, Rudolf/51' — a real person's name, excluded by the gold convention
    "other:document-furniture": [37, 57, 58, 59],                   # file number 'Pacific War', telegram series 'Delga' x2, 'Del s' (delegations)
    "title-only": [(48, 50)],                                       # 'Queen Mother' x3 (Queen Giovanna of Bulgaria, unnamed)
})
# ---------------- filtered sweep: 358 FPs ----------------
FS_FP = expand({
    "place": [0, 1, 3, 5, 6, (9, 29), 34, 62, 71, (85, 87), 89, 105, 106, 113, 119, 123, 147, 150, 151, 153, 175, 177, 185,
              187, 189, 192, 193, 194, 201, 202, (210, 214), 219, 221, 222, 223, 227, 228, 230, 233, 234, 244, 246, 247, 253,
              270, (284, 287), 291, 292, (293, 295), 298, 303, (305, 307), 309, 310, 314, 317, 324],
    "institution": [2, 7, 30, 33, 39, 44, 46, 58, 59, 65, 66, 72, 74, 76, (80, 84), 88, 90, 98, 99, 101, 102, 104, (107, 109),
                    111, 115, 120, 124, 130, 131, 133, 134, 137, 138, 140, 141, 143, 160, 161, 163, 165, 168, 169, 170, 173,
                    176, 180, 181, 184, 190, 218, 225, 239, 240, 243, 245, 251, 252, 254, 255, 256, 257, 259, 261, 262, 266,
                    267, 273, 276, 279, 280, 289, 290, 296, 297, 311, 313, 315, 316, 318, 320, 321, 323, 325, 326, 330, 332,
                    333, 334, 337, 338, 339, 341, 345, 346, 347, 350, 352],
    "title-only": [31, 32, 35, 40, 41, 42, 43, 45, 47, (48, 56), 61, 63, 69, 70, 73, 75, 77, 79, 95, 96, 97, 100, 103, 110,
                   112, 114, 116, 117, 118, 121, 122, 125, 126, 127, 146, 152, 154, 164, 166, 167, 171, 172, 178, 179, 182,
                   183, 186, 191, 237, 241, 242, 250, 271, 274, 275, 277, 278, 283, 288, 319, 335, 336, 340, 357],
    "pronoun-common": [4, 57, 60, 64, 67, 68, 128, 129, 132, 135, 136, 139, 142, 144, 145, 148, 188, (195, 200), (203, 209),
                       220, 224, 226, 229, 231, 232, 235, 236, 238, 258, 260, 263, 264, 265, 281, 282, 322, 342, 343, 344,
                       351, 353, 354],
    "ship-treaty-conference": [157, 158, 159, 162, 312, 327, 328, 329],   # SS President Harding x2, American Traveler, Waalhaven; Yalta agreement, Yalta, Potsdam, Moscow Agreements
    "partial-name-boundary": [8, 78, 149, 174, 215, 216, 217, 248, 249, 272, 301, 302, 304, 308, 331, 355, 356],
    "other:document-furniture": [36, 37, 38, 92, 93, 269, 299, 300, 348, 349],   # '& c.' x3, 'No. 72', 'your note No. 230', 'Secdel', 'Post' x2, 'Delga' x2
    "other:date": [91, 94, 268],
    "other:citation-caption-name": [155, 156],                       # 'Lic. Wolf', 'Rudolf/51'
})
# ---------------- filtered control: 150 misses ----------------
FC_MS = expand({
    "correspondence-frame:header": [0, 1, 3, 4, 7, 12, 13, 14, 24, 25, 27, 28, 30, 32, 34, 36, 39, 40, 42, 43, 44, 45, 47, 48,
                                    54, 55, 64, 65, 66, 68, 71, 72, 75, 76, 78, 80, 81, 82, 83, 85, 86, 88, 89, 91, 92, 93, 96,
                                    99, 101, 104, 107, 108, 109, 114, 122, 129, 131, 135, 137, 138, 144],
    "correspondence-frame:signature": [2, 5, 11, 23, 26, 29, 38, 41, 67, 70, 74, 77, 79, 90, 95, 98, 100, 103, 113, 118, 121,
                                       128, 133, 134, 136, 139, 140, 141, 143, 149],
    "correspondence-frame:addressee": [6, 31, 37, 69],
    "correspondence-frame:salutation": [110],
    "correspondence-frame:routing": [94, 105, 119, 130, 142],       # 'Repeated to Ambassador Bowers', 'From Braden', 'For Secretary and Matthews', 'For General Marshall', 'For Jessup'
    "unmarked-in-prose": [8, 9, 10, (15, 22), 33, 35, 46, (49, 53), (56, 63), 73, 84, 87, 102, 106, 111, 112, 115, 116, 117,
                          120, 123, 124, 125, 126, 127, 132, 146, 147],
    "other:footnote-doubled-name": [97, 145, 148],                  # R-0 text repeats the name ('Berthoud Eric A. Berthoud'); control emitted the doubled string as ONE span, claimed by the first gold span
})
# ---------------- filtered sweep: 28 misses ----------------
FS_MS = expand({
    "unmarked-in-prose": [0, 2, 3, 5, 6, 11, 12, 13, 14, 15, 16, 18, 19, 22, 23, 24],
    "correspondence-frame:header": [7, 8, 9],
    "correspondence-frame:signature": [1, 4, 10, 21],
    "correspondence-frame:salutation": [20],
    "other:list-span-merged": [17, 25],                             # 'Messrs. Jessup and Ford', 'Generals Yang and Chang Hsuehliang' emitted as one span; gold = one per person
    "initial-or-abbreviated": [26],                                 # "Pres Truman's"
    "other:filter-removed-bare-King": [27],                         # raw sweep found "King's"; the frozen title rule removed it
})
# sub-flags on misses, by index: diacritic / odd spelling, initials, title+name, foreign-language surface
FC_MS_FLAGS = {
    "OCR-or-odd-spelling": [46, 115, 120, 123, 124, 125],           # Aspíroz, Premier Osóbka, Houston-Boswell, Chou En-lai's x2, Lu Ting-yi
    "initial-or-abbreviated": [10, 77, 112, 21],                    # J. D. Coleman, J. W. Riddle, Hanc, "Samuel A, Mudd" (OCR comma) — flags, not categories
    "title-plus-name": [56, 57, 58, 61, 62, 63, 87, 94, 106, 115, 116, 117, 127, 130],
    "all-caps-surface": [2, 5, 11, 23, 26, 29, 38, 41],
}
FS_MS_FLAGS = {
    "OCR-or-odd-spelling": [15],                                     # Aspíroz
    "initial-or-abbreviated": [4, 26],                               # Q. A. GILLMORE, Pres Truman's
    "title-plus-name": [2, 3, 14, 16, 18],
    "all-caps-surface": [1, 4, 10],
    "famous-name-in-prose-no-arm-found": [5, 6],                     # George Washington x2
}

# Dangerous-class judgement on FPs (hand): would the SURFACE pass as a person in a People browser?
# tier A = name-shaped and plausibly a person's name to a reader (the dangerous class);
# tier B = an unnamed office/epithet that DOES denote one real person (an office masquerading as a person);
# everything else reads as a place/body/thing.
FC_DANGER = {"A": [0, 1, 4, 6, 7, 21, 28, 30, 31, 32, 33, 34, 35], "B": [48, 49, 50]}
#   A: Anna, Dee, Bull, Haro, Arro, JNO, Ramazan, Seville, Wolf, Rudolf, Harding x2, Hunzedal   B: Queen Mother x3
FS_DANGER = {"A": [8, 78, 149, 153, 155, 156, 157, 160, 162, 163, 165, 174, 215, 216, 217, 248, 249, 272, 301, 302, 304, 308,
                   331, 355, 356, 159, 161],
             "B": [45, 47, 152, 154, 271, 274, 277, 278, 283]}
#   A includes every nested duplicate (they ARE a person, the SAME one the gold hit — harmless in a browser but name-shaped),
#     plus Seville x2 (+Commanding General Seville), Lic. Wolf, Rudolf/51, President Harding x2, Hunzedal x3, Waalhaven, Socdeco
#   B: the Khedive x2, Commanding General Seville, Military Governor Bilbao, Queen Mother x4, the Young Marshal

# Vocabulary-removable without context (a bigger gazetteer / closed list would catch the surface alone):
VOCAB_REMOVABLE = {"place", "institution", "title-only", "pronoun-common", "other:document-furniture", "other:date",
                   "other:calendar-month"}
# Needs context (the surface alone is a person-shaped string): nested duplicates, ships, ambiguous surnames
NEEDS_CONTEXT = {"partial-name-boundary", "ship-treaty-conference", "other:citation-caption-name"}


def apply(arm, fp_map, ms_map, fp_danger=None, ms_flags=None):
    a = raw["arms"][arm]
    for i, x in enumerate(a["false_positives"]):
        x["category"] = fp_map[i]
        x["danger_tier"] = next((t for t, ids in (fp_danger or {}).items() if i in ids), None)
    for i, x in enumerate(a["misses"]):
        x["category"] = ms_map[i]
        x["flags"] = [f for f, ids in (ms_flags or {}).items() if i in ids]
    assert len(fp_map) == len(a["false_positives"]), (arm, len(fp_map), len(a["false_positives"]))
    assert len(ms_map) == len(a["misses"]), (arm, len(ms_map), len(a["misses"]))


apply("filtered_control", FC_FP, FC_MS, FC_DANGER, FC_MS_FLAGS)
apply("filtered_sweep", FS_FP, FS_MS, FS_DANGER, FS_MS_FLAGS)

# ---------------- raw sweep FPs: surface frequency + filter rule ----------------
gaz = fd.load_gazetteer(os.path.join(REPO, "FRUSExplorer/Resources/volume-tag-taxonomy.json"),
                        os.path.join(REPO, "FRUSExplorer/Resources/decimal-class-labels.json"))
texts = {}
filtered_keys = {(x["v"], x["d"], x["s"], x["e"]) for x in raw["arms"]["filtered_sweep"]["false_positives"]}
filtered_cat = {(x["v"], x["d"], x["s"], x["e"]): x["category"] for x in raw["arms"]["filtered_sweep"]["false_positives"]}
rs = raw["arms"]["raw_sweep"]
for x in rs["false_positives"]:
    if x["v"] not in texts:
        texts[x["v"]] = store.volume_text(os.environ["TEXT_DIR"], x["v"])
    rule = fd.rule_for(x["n"], texts[x["v"]][x["d"]], x["s"], x["e"], fd.ALL_RULES, gaz)
    x["filter_rule"] = rule
    k = (x["v"], x["d"], x["s"], x["e"])
    x["survives_filter"] = k in filtered_keys
    x["category"] = filtered_cat.get(k, "removed-by-filter:%s" % rule)
rule_counts = collections.Counter(x["filter_rule"] or "kept" for x in rs["false_positives"])
surface_counts = collections.Counter(fd.phrase(x["n"]) for x in rs["false_positives"])
rs["fp_by_filter_rule"] = dict(rule_counts)
rs["fp_surface_frequency_top40"] = surface_counts.most_common(40)
rs["fp_removed_by_filter"] = sum(1 for x in rs["false_positives"] if not x["survives_filter"])
# raw sweep misses (27): 26 are the filtered sweep's minus King's, plus... compute overlap
fs_miss_keys = {(x["v"], x["d"], x["s"], x["e"]) for x in raw["arms"]["filtered_sweep"]["misses"]}
rs["misses_shared_with_filtered_sweep"] = sum(1 for x in rs["misses"] if (x["v"], x["d"], x["s"], x["e"]) in fs_miss_keys)
fs_miss_cat = {(x["v"], x["d"], x["s"], x["e"]): x["category"] for x in raw["arms"]["filtered_sweep"]["misses"]}
for x in rs["misses"]:
    x["category"] = fs_miss_cat.get((x["v"], x["d"], x["s"], x["e"]), "not-in-filtered-sweep-misses")


# ---------------- summaries ----------------
def summarise(arm):
    a = raw["arms"][arm]
    fps, ms = a["false_positives"], a["misses"]
    def by(items, key):
        c = collections.Counter(x[key] for x in items)
        return dict(c.most_common())
    def by_band(items, key):
        out = {}
        for x in items:
            out.setdefault(x["band"], collections.Counter())[x[key]] += 1
        return {b: dict(c.most_common()) for b, c in sorted(out.items())}
    def examples(items, key, n=5):
        ex = {}
        for x in items:
            ex.setdefault(x[key], [])
            if len(ex[x[key]]) < n:
                ex[x[key]].append("%s/%s [%s] …%s⟦%s⟧%s…" % (x["v"], x["d"], x["band"], x["left"][-40:], x["n"], x["right"][:40]))
        return ex
    s = {"fp_total": len(fps), "miss_total": len(ms),
         "fp_categories": by(fps, "category"), "fp_categories_by_band": by_band(fps, "category"),
         "fp_examples": examples(fps, "category"),
         "miss_categories": by(ms, "category"), "miss_categories_by_band": by_band(ms, "category"),
         "miss_examples": examples(ms, "category")}
    if arm != "raw_sweep":
        vocab = sum(1 for x in fps if x["category"] in VOCAB_REMOVABLE)
        ctx = sum(1 for x in fps if x["category"] in NEEDS_CONTEXT)
        s["fp_vocab_removable"] = {"count": vocab, "share": round(vocab / len(fps), 3)}
        s["fp_needs_context"] = {"count": ctx, "share": round(ctx / len(fps), 3),
                                 "categories": sorted(NEEDS_CONTEXT)}
        s["fp_danger"] = {t: sum(1 for x in fps if x["danger_tier"] == t) for t in ("A", "B")}
        s["fp_danger_A_surfaces"] = collections.Counter(x["n"] for x in fps if x["danger_tier"] == "A").most_common()
        s["fp_danger_B_surfaces"] = collections.Counter(x["n"] for x in fps if x["danger_tier"] == "B").most_common()
        s["fp_nested_duplicate_of_a_hit"] = sum(1 for x in fps if x["category"] == "partial-name-boundary")
        s["fp_danger_A_excluding_nested_duplicates"] = sum(1 for x in fps if x["danger_tier"] == "A" and x["category"] != "partial-name-boundary")
        s["fp_danger_A_excluding_nested_surfaces"] = collections.Counter(x["n"] for x in fps if x["danger_tier"] == "A" and x["category"] != "partial-name-boundary").most_common()
        s["fp_person_gold_missed"] = sum(1 for x in fps if x["category"] == "person-gold-missed")
        s["fp_editor_overlap"] = sum(1 for x in fps if x["editor_overlap"])
        # union argument
        s["miss_editor_covers"] = {"count": sum(1 for x in ms if x["editor_covers"]), "total": len(ms)}
        s["miss_editor_covers_by_category"] = {c: {"editor_covers": sum(1 for x in ms if x["category"] == c and x["editor_covers"]),
                                                   "total": sum(1 for x in ms if x["category"] == c)} for c in s["miss_categories"]}
        s["miss_found_by_other_arm"] = {o: sum(1 for x in ms if o in x["found_by_other_arms"]) for o in raw["arms"] if o != arm}
        s["miss_flags"] = dict(collections.Counter(f for x in ms for f in x["flags"]))
    else:
        s["fp_by_filter_rule"] = a["fp_by_filter_rule"]
        s["fp_surface_frequency_top40"] = a["fp_surface_frequency_top40"]
        s["fp_removed_by_filter"] = a["fp_removed_by_filter"]
        s["misses_shared_with_filtered_sweep"] = a["misses_shared_with_filtered_sweep"]
    return s

raw["summary"] = {arm: summarise(arm) for arm in ("filtered_control", "filtered_sweep", "raw_sweep")}
raw["method"] = {
    "scorer": os.path.join(REPO, "tools/semantic-harvest/score_detections.py"),
    "matching": "relaxed (any-overlap, maximum-cardinality one-to-one), sd.match per document; FP = predicted span not in the matching; miss = gold span not in the matching",
    "positive_control": {arm: raw["arms"][arm]["relaxed"] for arm in raw["arms"]},
    "gold": "64 of 72 documents, 406 mentions, 2 documents naming no one (m2a-ground-truth.jsonl + -documents.jsonl, 2026-09-12 20:07)",
    "hand_read": "every FP and miss of filtered_control and filtered_sweep read with 60 chars of R-0 context on each side; raw_sweep FPs categorised by surface frequency and by filter_detections.rule_for only",
}
del raw["arms"]["raw_control"]  # not part of the task; extracted only as a cross-check
json.dump(raw, open(os.path.join(HERE, "errors.json"), "w"), indent=1, ensure_ascii=False)
print(json.dumps(raw["summary"], indent=1, ensure_ascii=False))
