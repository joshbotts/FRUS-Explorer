#!/usr/bin/env python3
"""Filing-role label precision, proxy 1: frus1873p1v1 and frus1873p1v2, the only pre-1900 volumes whose editors
link from/to names to a persons list that PRINTS EACH PERSON'S OFFICE.

Evidence = the linked list entry's role text + its list heading (chapter-context/label-validation/gold-entries.jsonl,
gold-mentions.jsonl; extracted from the TEI by gold_extract.py). This evidence does NOT go through POCOM, so unlike
the earlier identity score it is not circular for a role label. Label = lib_se.roles_from over the compiled
classifier's output for these two volumes: AFTER = classified/head-listvols-docs.jsonl (HEAD harness), BEFORE =
label-validation/classified-list-volumes.jsonl (pre-#1292 sources). Head rows only (a row inside the document's
own <head>); the label is refused for enclosure/body rows by design.

Writes out/proxy-1873.json.
"""
import os, sys, json, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib_se as S

VOLS = {"frus1873p1v1", "frus1873p1v2"}
ARMS = (("S_before", "B", S.arm_S), ("T_before", "B", S.arm_T), ("S_after", "A", S.arm_S), ("T_after", "A", S.arm_T))


def main():
    E = {(e["volume"], e["id"]): e for e in S.jsonl(S.GOLD_ENTRIES) if e["volume"] in VOLS}
    MENT = [m for m in S.jsonl(S.GOLD_MENTIONS) if m["v"] in VOLS]
    DOCS = {"A": S.load_docs(S.LISTVOLS_AFTER, VOLS), "B": S.load_docs(S.LISTVOLS_BEFORE, VOLS, adapter=S.slim_lv_before)}
    C = collections.defaultdict(collections.Counter)
    X = collections.defaultdict(list)
    PEOPLE = collections.defaultdict(set)
    DOCSET = collections.defaultdict(set)
    for key, r in DOCS["A"].items():
        Z = C[("documents", key[0])]
        Z["docs"] += 1
        Z["kind:" + S.doc_kind(r)] += 1
        Z["S_after:shown"] += bool(r["shown"])
        Z["S_before:shown"] += bool(DOCS["B"].get(key, {}).get("shown"))
    for m in MENT:
        key = (m["v"], m["d"])
        grain = "head" if m["in_doc_head"] else "enclosure/body"
        entry = E.get((m["v"], m["link"])) if m["linked"] else None
        ev = S.role_evidence_1873(entry) if entry else None
        evclass = "no-link" if not entry else ("unparsed" if not ev else "|".join(sorted({k for k, _ in ev})))
        C[("evidence classes", grain)][evclass] += 1
        for arm, which, fn in ARMS:
            r = DOCS[which].get(key)
            ac = fn(r) if r else None
            own = other = frozenset()
            if ac:
                F, T = S.roles_from(ac["cands"], ac["geo_ok"])
                own, other = (F, T) if m["t"] == "from" else (T, F)
            labeled = grain == "head" and bool(own)
            Z = C[(arm, grain, "reach")]
            Z["rows"] += 1
            Z["linked"] += bool(entry)
            Z["labeled"] += labeled
            Z["labeled_single"] += labeled and len(own) == 1
            Z["labeled_and_evidenced"] += labeled and bool(ev)
            if not labeled or not ev:
                continue
            out = S.judge(own, ev)
            evk = "evidence=department-only" if ev == {("department", None)} else "evidence=not-department-only"
            nk = "label-single" if len(own) == 1 else "label-multi"
            for k in ((arm, grain, "all"), (arm, grain, evk), (arm, grain, nk), (arm, grain, evk, nk),
                      (arm, grain, "side=" + m["t"]), (arm, grain, "label-kinds=" + "|".join(sorted(k for k, _ in own)))):
                C[k][out] += 1
            PEOPLE[(arm, evk)].add((m["v"], m["link"]))
            DOCSET[(arm, evk)].add(key)
            if out != "right" and len(X[(arm, out)]) < 60:
                X[(arm, out)].append({"doc": m["v"] + "/" + m["d"], "side": m["t"], "name": m["n"],
                                      "entry": entry["name"] + " -- " + entry["role"][:100], "heading": entry["heading"],
                                      "header": (r["header"] or "")[:90], "dateline": (r["dateline"] or "")[:70],
                                      "chapter": ac.get("chapter"), "label": S.render_row_label(own, other, m["t"]),
                                      "evidence": sorted(map(str, ev))})
    prec = {"|".join(k): S.precision_block(v) for k, v in C.items()
            if k[0] in ("S_before", "T_before", "S_after", "T_after") and k[2] != "reach"}
    out = {"generated_by": os.path.abspath(__file__),
           "inputs": {"after": S.LISTVOLS_AFTER, "before": S.LISTVOLS_BEFORE, "gold_mentions": S.GOLD_MENTIONS,
                      "gold_entries": S.GOLD_ENTRIES},
           "counts": {"|".join(k): dict(v) for k, v in C.items()},
           "precision": prec,
           "distinct_list_entries_judged": {"|".join(k): len(v) for k, v in PEOPLE.items()},
           "distinct_documents_judged": {"|".join(k): len(v) for k, v in DOCSET.items()},
           "non_right_examples": {"|".join(k): v for k, v in X.items()}}
    json.dump(out, open(os.path.join(HERE, "out", "proxy-1873.json"), "w"), indent=1, sort_keys=True)
    for k in sorted(prec):
        p = prec[k]
        if p["judged"]:
            print(k, "judged", p["judged"], "right", p["right"], "untestable", p["right_kind_place_untestable"],
                  "wrong-place", p["wrong_place"], "wrong-kind", p["wrong_kind"], "strict", p["strict_precision_wilson95"])
    for k, v in sorted(C.items()):
        if k[0] in ("documents", "evidence classes") or k[2] == "reach":
            print(k, dict(v))


if __name__ == "__main__":
    main()
