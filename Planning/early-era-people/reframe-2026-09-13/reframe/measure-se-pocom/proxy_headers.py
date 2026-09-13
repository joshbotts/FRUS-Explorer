#!/usr/bin/env python3
"""Filing-role label precision, proxy 2 (headers that PRINT the office) + parity of this program's mirrors.

(1) PARITY. lib_se.foreign_legation_name and lib_se.sos_sender mirror merged Swift rules; they are used only to
    split rows by chapter kind and to say when the sender rule decided. Here they are checked against what the
    compiled classifier actually did, wherever its output makes the rule observable.
(2) DOCUMENT-LEVEL HEADER PROXY over every document in the marked-scope volumes (1861-1899, 1900-1905) of the
    live-index export: split the header at its first " to " (memoranda skipped), parse each side for a printed
    office (lib_se.segment_evidence), and judge the label for that side. Documents whose label used header words
    the classifier itself reads (foreign-legation chapters; consular, domestic-letter and special-agent
    candidates) are tallied as 'circular' and kept apart.
(3) POST-1905 LIST VOLUMES (1914-1952; label-validation census): headers print office AND post
    ("The Minister in China (Johnson) to the Secretary of State"). Shown rows are gated off after 1905, so only
    the title-candidate arm (T_after) exists; the classifier runs there outside the era it was written for.

Writes out/proxy-headers.json.
"""
import os, sys, json, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib_se as S

US_LEG_DL = ["legation of the united states", "embassy of the united states", "american legation", "american embassy",
             "united states legation", "u. s. legation", "u.s. legation"]
EXEC_DL = ["war department", "navy department", "treasury department", "post office department", "department of justice",
           "department of the interior", "department of agriculture", "department of commerce", "executive mansion", "white house"]


def circular(ac):
    if ac is None:
        return False
    if ac.get("kind_used") == "foreign-legation":
        return True
    cats = {x["category"] for x in ac["cands"]}
    return bool(cats & {"consularInstructions", "notesToForeignConsuls", "domesticLetters",
                        "specialAgentsDespatches", "specialAgentsInstructions"})


def parity(docs, P, PX, label):
    for (v, d), r in docs.items():
        dl = (r.get("dateline") or "").lower()
        hl = (r.get("header") or "").lower()
        special = any(k in hl or k in dl for k in ("special agent", "special commissioner", "special mission"))
        other_branch = special or any(k in dl for k in EXEC_DL) or "consulate" in dl or "consular" in dl
        for t in r["classifierByTitle"]:
            if not t["titleGeoKeys"] or other_branch:
                continue
            cats = [c["category"] for c in t["classifications"]]
            mirror = S.foreign_legation_name(t["title"]) is not None
            observed = None
            if "diplomaticInstructions" in cats or "diplomaticDespatches" in cats:
                observed = False
            elif "department of state" in dl and cats[:1] == ["notesToForeignMissions"]:
                observed = True
            elif any(k in dl for k in US_LEG_DL) and not cats:
                observed = True
            if observed is not None:
                P[(label, "legation-mirror")]["agree" if mirror == observed else "DISAGREE"] += 1
                if mirror != observed and len(PX[(label, "legation-mirror")]) < 20:
                    PX[(label, "legation-mirror")].append([v + "/" + d, t["title"], cats, (r.get("dateline") or "")[:50]])
            # Sender rule. Observable in a legation title (mirror) whose dateline names neither the Department nor a
            # U.S. legation: [notesTo, ...] means departmentOutbound fired, so the sender matched; [notesFrom] or []
            # means it did not ([] is also the President refusal or a dateline naming neither Washington nor a legation).
            if mirror and "department of state" not in dl and not any(k in dl for k in US_LEG_DL):
                if cats[:1] == ["notesToForeignMissions"]:
                    obs = True
                elif cats == ["notesFromForeignMissions"] or not cats:
                    obs = False
                else:
                    obs = None
                if obs is None:
                    P[(label, "sender-mirror")]["unobservable:" + "+".join(cats)] += 1
                    continue
                m = S.sos_sender(r.get("header"))
                P[(label, "sender-mirror")][("agree" if m == obs else "DISAGREE") + (":sender-rule-fired" if obs else ":not-fired")] += 1
                if m != obs and len(PX[(label, "sender-mirror")]) < 20:
                    PX[(label, "sender-mirror")].append([v + "/" + d, r.get("header"), cats, (r.get("dateline") or "")[:50]])


def header_proxy(docs, band_of, arms, H, HX, count_docs):
    for (v, d), r in docs.items():
        band = band_of(v)
        if band is None:
            continue
        snd, adr = S.header_sides(r.get("header"))
        if count_docs:
            H[("any", band)]["docs"] += 1
        if snd is None:
            if count_docs:
                H[("any", band)]["docs-without-sender/addressee (no ' to ', or a memorandum)"] += 1
            continue
        evs = {"from": S.segment_evidence(snd), "to": S.segment_evidence(adr)}
        if count_docs:
            H[("any", band)]["docs-with-office-printed-on-a-side"] += bool(evs["from"] or evs["to"])
            H[("any", band)]["sides-with-office-printed"] += bool(evs["from"]) + bool(evs["to"])
        for arm, fn in arms:
            ac = fn(r)
            F, T = S.roles_from(ac["cands"], ac["geo_ok"]) if ac else (frozenset(), frozenset())
            circ = "circular" if circular(ac) else "independent"
            for side, ev in evs.items():
                if not ev:
                    continue
                roles_ev, strength, tag = ev
                own, other = (F, T) if side == "from" else (T, F)
                out = S.judge(own, roles_ev) if own else "unlabeled"
                for k in ((arm, band, strength, circ), (arm, band, strength, circ, "side=" + side),
                          (arm, band, strength, circ, "tag=" + tag),
                          (arm, band, strength, circ, "label=" + ("|".join(sorted(k_ for k_, _ in own)) or "none"))):
                    H[k][out] += 1
                if own and out in ("wrong-kind", "wrong-place") and circ == "independent" and len(HX[(arm, band, strength, out)]) < 30:
                    HX[(arm, band, strength, out)].append({"doc": v + "/" + d, "side": side, "header": (r.get("header") or "")[:120],
                                                           "dateline": (r.get("dateline") or "")[:70], "chapter": ac.get("chapter"),
                                                           "label": S.render_row_label(own, other, side),
                                                           "evidence": sorted(map(str, roles_ev)), "tag": tag})


def main():
    scope = set(S.scope_volumes(1905))
    DA_all = S.load_docs(S.AFTER)
    DB_all = S.load_docs(S.BEFORE)
    LA = S.load_docs(S.LISTVOLS_AFTER)
    P = collections.defaultdict(collections.Counter)
    PX = collections.defaultdict(list)
    parity(DA_all, P, PX, "after-docs (46,837 pre-1906 export documents)")
    parity(LA, P, PX, "HEAD harness over the list-volume export (25,529 documents)")
    H = collections.defaultdict(collections.Counter)
    HX = collections.defaultdict(list)
    band_scope = lambda v: S.band_of_volume(v) if v in scope else None
    header_proxy(DA_all, band_scope, (("S_after", S.arm_S), ("T_after", S.arm_T)), H, HX, True)
    header_proxy(DB_all, band_scope, (("S_before", S.arm_S), ("T_before", S.arm_T)), H, HX, False)
    band_post = lambda v: None if v.startswith("frus1873") else "post-1905 list volumes"
    header_proxy(LA, band_post, (("T_after", S.arm_T),), H, HX, True)
    out = {"generated_by": os.path.abspath(__file__),
           "parity": {"|".join(k): dict(v) for k, v in P.items()},
           "parity_disagreements": {"|".join(k): v for k, v in PX.items()},
           "header_proxy": {"|".join(k): (S.precision_block(v) | {"counts": dict(v)}) if k[0] != "any" else dict(v)
                            for k, v in H.items()},
           "header_proxy_wrong_examples_independent": {"|".join(k): v for k, v in HX.items()}}
    json.dump(out, open(os.path.join(HERE, "out", "proxy-headers.json"), "w"), indent=1, sort_keys=True)
    print(json.dumps(out["parity"], indent=1))
    for k in sorted(out["header_proxy"]):
        v = out["header_proxy"][k]
        if k.startswith("any|"):
            print(k, v)
        elif k.count("|") == 3 or "|label=" in k:
            print(k, "judged", v["judged"], "right", v["right"], "untestable", v["right_kind_place_untestable"],
                  "wrong-place", v["wrong_place"], "wrong-kind", v["wrong_kind"], "unlabeled", v["unlabeled"],
                  "strict", v["strict_precision_wilson95"], "loose", v["loose_precision_wilson95"])


if __name__ == "__main__":
    main()
