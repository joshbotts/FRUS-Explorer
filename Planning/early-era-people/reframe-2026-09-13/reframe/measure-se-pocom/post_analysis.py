#!/usr/bin/env python3
"""Assemble the final tables from out/merged-rule.json, out/proxy-1873.json and out/proxy-headers.json
(no new measurement, except the legation-under-country document count, which re-reads lib_se.AFTER).
Writes out/tables.txt and out/final-figures.json."""
import os, sys, json, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib_se as S

OUT = os.path.join(HERE, "out")
o = json.load(open(os.path.join(OUT, "merged-rule.json")))
p73 = json.load(open(os.path.join(OUT, "proxy-1873.json")))
ph = json.load(open(os.path.join(OUT, "proxy-headers.json")))
L = []
FIG = {}


def p(*a):
    L.append(" ".join(str(x) for x in a))


SUMF = [("rows", "rows"), ("hyp", "rows_with_hypothesis"), ("pocom1", "i_pocom_one"), ("corrob", "one_corroborated"),
        ("contra", "one_contradicted"), ("sev>1 loc", "several_to_one_other"),
        ("sev>1 conv", "several_to_one_by_secretary_over_same_surname_assistant"), ("chap1", "chapter_one"),
        ("strict(iii)", "iii_strict_veto_contradicted"), ("expl-uncov", "nobody_or_unknown_explained_uncovered"),
        ("untestable", "one_untestable_uncovered_only"), ("contra:other-post", "contradicted_holder_in_other_post"),
        ("contra:no-post", "contradicted_holder_in_no_post"), ("contra:<=180d", "contradicted_within_180d")]
ARMS = ["A0", "S_before", "S_after", "T_before", "T_after", "B0", "B_after"]
S_ = o["summaries"]

p("== CONTROLS", json.dumps(o["controls_against_earlier_summary"]))
for band in ("1861-1899", "1900-1905"):
    p("\n== TASK 1 correspondent x POCOM, band", band, "(TEI-rule marked layer, all grains)")
    p("arm".ljust(9), " ".join(h.rjust(11) for h, _ in SUMF))
    for arm in ARMS:
        s = S_[arm + "|" + band]
        p(arm.ljust(9), " ".join(str(s[k]).rjust(11) for _, k in SUMF))
        FIG[f"task1|{arm}|{band}"] = {h: s[k] for h, k in SUMF}

for band in ("1861-1899", "1900-1905"):
    p("\n== TASK 2 by chapter kind, band", band)
    kinds = sorted({k.split("|kind:")[1] for k in S_ if k.startswith("S_after|" + band + "|kind:")})
    for kind in kinds:
        p(" -- kind", kind)
        for arm in ("S_before", "S_after", "T_before", "T_after", "B0"):
            s = S_.get(f"{arm}|{band}|kind:{kind}")
            if s:
                p("   ", arm.ljust(9), " ".join(f"{h}={s[k]}" for h, k in SUMF))
                FIG[f"task2|{arm}|{band}|{kind}"] = {h: s[k] for h, k in SUMF}

for band in ("1861-1899", "1900-1905"):
    p("\n== grain split S_after/T_after", band)
    for arm in ("S_before", "S_after", "T_after"):
        for g in ("head", "enclosure", "head-unlocated", "no-header", "no-harness-record"):
            s = S_.get(f"{arm}|{band}|grain:{g}")
            if s:
                p("   ", arm, g, " ".join(f"{h}={s[k]}" for h, k in SUMF[:8]))

# legation chapters whose walk stops on a parent country title (the merged legation rules then never apply)
scope = set(S.scope_volumes(1905))
DA = S.load_docs(S.AFTER, scope)
LC = collections.Counter()
LX = collections.defaultdict(list)
for (v, d), r in DA.items():
    if S.doc_kind(r) != "foreign-legation":
        continue
    b = S.band_of_volume(v)
    for arm, fn in (("S_after", S.arm_S), ("T_after", S.arm_T)):
        ac = fn(r)
        used = ac["kind_used"] if ac else "no-classification"
        LC[(b, arm, used)] += 1
        if used == "country" and len(LX[(b, arm)]) < 6:
            LX[(b, arm)].append([v + "/" + d, r["sectionPath"][-3:], (r["header"] or "")[:60],
                                 sorted({c["category"] for c in ac["classifications"]})])
p("\n== foreign-legation-kind documents by the title kind the arm actually used (scope volumes)")
for k, n in sorted(LC.items()):
    p("   ", k, n)
    FIG["legation-docs-used-title|" + "|".join(map(str, k))] = n
for k, v in LX.items():
    p("    examples", k, v)

p("\n== TASK 3 label reach (row grain: TEI-rule marked layer; docs = documents holding those rows)")
for band in ("1861-1899", "1900-1905"):
    for arm in ("S_before", "S_after", "T_before", "T_after"):
        x = o["labels_row_reach"].get(f"{arm}|{band}")
        if not x:
            continue
        p("   ", band, arm, x, "share_of_rows=%.4f share_of_head_rows=%.4f share_of_docs=%.4f" % (
            x["labeled_rows"] / x["rows"], x["labeled_rows"] / x["head_rows"], x["docs_labeled"] / x["docs"]))
        FIG[f"task3-rows|{arm}|{band}"] = x
    for arm in ("S_after", "T_after"):
        for k, x in sorted(o["labels_row_reach"].items()):
            if k.startswith(f"{arm}|{band}|kind:"):
                p("      ", k, x)
p("\n== TASK 3 document reach over every scope document (live-index export; volume-year band)")
for k, v in sorted(o["document_reach_all_scope_documents"].items()):
    p("   ", k, v)
    FIG["task3-docs|" + k] = v
p("\n== label signatures")
for k, v in o["label_signatures"].items():
    p("   ", k, v)
p("\n== label examples (S_after)")
for k, v in o["label_examples_S_after"].items():
    p("   ", k, "|", v[0]["doc"], "|", v[0]["header"][:70], "|", v[0]["label"])

p("\n== PROXY 1873 (list role text; head rows)")
for k, v in sorted(p73["precision"].items()):
    if v["judged"] and "label-kinds" not in k:
        p("   ", k, {x: v[x] for x in ("judged", "right", "wrong_place", "wrong_kind", "strict_precision_wilson95")})
        FIG["proxy1873|" + k] = v
p("    reach", {k: v for k, v in p73["counts"].items() if "reach" in k or k.startswith("documents")})
p("    distinct list entries judged", p73["distinct_list_entries_judged"])
p("\n== PROXY headers (document sides)")
for k, v in sorted(ph["header_proxy"].items()):
    if k.startswith("any|"):
        p("   ", k, v)
        FIG["proxyhdr|" + k] = v
    elif k.count("|") == 3 or "|label=" in k:
        p("   ", k, {x: v[x] for x in ("judged", "right", "right_kind_place_untestable", "wrong_place", "wrong_kind", "unlabeled", "strict_precision_wilson95", "loose_precision_wilson95")})
        FIG["proxyhdr|" + k] = {x: v[x] for x in ("judged", "right", "right_kind_place_untestable", "wrong_place", "wrong_kind", "unlabeled", "strict_precision_wilson95", "loose_precision_wilson95")}
p("    parity", ph["parity"])
FIG["parity"] = ph["parity"]
p("\n== PROXY headers at ROW grain (marked head rows whose own header side prints an office)")
for k, v in sorted(o["header_office_proxy_rows"].items()):
    if k.count("|") == 3:
        p("   ", k, {x: v[x] for x in ("judged", "right", "right_kind_place_untestable", "wrong_place", "wrong_kind", "unlabeled", "strict_precision_wilson95")})
        FIG["proxyrow|" + k] = {x: v[x] for x in ("judged", "right", "right_kind_place_untestable", "wrong_place", "wrong_kind", "unlabeled", "strict_precision_wilson95")}

p("\n== TASK 4 Seward 1861-1869")
for k, v in o["seward_1861_1869"].items():
    keep = {a: b for a, b in v.items() if b and (a == "rows" or a.startswith("kind:") or "chapter-rule" in a or "sender-rule" in a
                                                  or a.endswith(":shown") or "secretaryOfStateSender" in a or a.startswith("S_after:cats") or a.startswith("S_before:cats"))}
    p("   ", k, keep)
    FIG["seward|" + k] = keep
for k, v in o["seward_examples"].items():
    p("    ex", k, v[:3])
H = o["hunter_gap_rows"]
HC = collections.Counter()
for h in H:
    HC[("rows",)] += 1
    HC[("grain-side", h["grain"], h["side"])] += 1
    HC[("kind", h["kind"])] += 1
    for arm in ("B0", "S_before", "S_after", "T_after"):
        t = h[arm]["trans"]
        HC[(arm, t.split("(")[0])] += 1
    HC[("S_after sender-rule decided", h["S_after"].get("sender_rule_decided"))] += 1
    HC[("T_after sender-rule decided", h["T_after"].get("sender_rule_decided"))] += 1
    HC[("shown before->after", bool(h["S_before"]["cats"]), bool(h["S_after"]["cats"]))] += 1
    if h["grain"] == "head" and h["side"] == "from":
        HC[("head-from dateline has 'department of state'", "department of state" in h["dateline"].lower())] += 1
p("\n== TASK 4 Hunter rows in POCOM's gap (1865-01-01..1866-07-26)")
for k, n in sorted(HC.items(), key=lambda kv: str(kv[0])):
    p("   ", k, n)
    FIG["hunter|" + "|".join(map(str, k))] = n
p("    legation-chapter Hunter head rows:")
for h in H:
    if h["kind"] == "foreign-legation" and h["grain"] == "head":
        p("     ", h["doc"], h["date"], h["side"], "|", h["header"][:50], "|", h["dateline"][:30], "|", h["S_before"]["cats"], "->", h["S_after"]["cats"], h["S_after"]["trans"])
        break

p("\n== RECONCILIATION (1861-1899 rows)")
for k, v in o["reconciliation"].items():
    diff = [x for x in v if x[0][0] != x[0][1]] if "x" in k else v
    p("   ", k, "changed-rows:", sum(x[1] for x in diff) if "x" in k else "", diff[:16])
    FIG["recon|" + k] = diff[:40]
for k, v in o["reconciliation_examples"].items():
    p("    ex", k, v[:3])

open(os.path.join(OUT, "tables.txt"), "w").write("\n".join(L) + "\n")
json.dump(FIG, open(os.path.join(OUT, "final-figures.json"), "w"), indent=1, sort_keys=True, default=list)
print("\n".join(L))
