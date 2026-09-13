#!/usr/bin/env python3
"""Summary tables + compact example file from chapter-rule.json (no new measurement)."""
import json
o = json.load(open("chapter-rule.json"))
T = o["tallies"]
out = []
for arm in ("A", "B"):
    for b in ("1861-1899", "1900-1905"):
        t = T[f"{arm}|{b}"]; g = lambda k: t.get(k, 0)
        n = g("rows"); one = g("pocom:one")
        corr = sum(v for k, v in t.items() if k.startswith("T:one:corroborated"))
        s2o = sum(v for k, v in t.items() if k.startswith("T:several:->one"))
        conv = g("T:several:->one(dept-tier1-over-same-surname-tier2)")
        contra = sum(v for k, v in t.items() if k.startswith("T:one:CONTRADICTED"))
        chap_one = g("chapter:one")
        pocom_only = one - corr
        lenient = chap_one + pocom_only
        strict = chap_one + pocom_only - contra
        expl = sum(v for k, v in t.items() if k.endswith("explained-as-uncovered-role"))
        row = dict(arm=arm, band=b, rows=n, rows_with_hypothesis=g("rows_with_hypothesis"),
                   rows_with_covered_hypothesis=g("rows_with_covered_hypothesis"),
                   i_pocom_one=one, i_share=round(one / n, 4), chapter_one=chap_one, chapter_share=round(chap_one / n, 4),
                   one_corroborated=corr, one_corroborated_share_of_pocom_one=round(corr / one, 4),
                   several_to_one=s2o, several_to_one_by_secretary_over_same_surname_assistant=conv,
                   several_to_one_other=s2o - conv, one_contradicted=contra,
                   one_untestable_uncovered_only=g("T:one:untestable-uncovered-only"),
                   one_no_hypothesis=g("combined:pocom-one-no-hypothesis"),
                   nobody_or_unknown_explained_uncovered=expl,
                   explained_side_uncovered_only=g("explained_side_uncovered_only"),
                   iii_lenient=lenient, iii_lenient_share=round(lenient / n, 4),
                   iii_strict_veto_contradicted=strict, iii_strict_share=round(strict / n, 4),
                   iii_strict_without_convention=strict - conv, iii_strict_without_convention_share=round((strict - conv) / n, 4),
                   undetermined_strict=n - strict)
        out.append(row)
json.dump(out, open("summary.json", "w"), indent=1)
for r in out: print(r)
with open("examples-armB.txt", "w") as f:
    for k, v in o["examples"].items():
        if not k.startswith("B|"): continue
        f.write(f"## {k} count={v['count']}\n")
        for e in v["sample"]:
            f.write("  %s %s %s/%s name=%r | head=%r | chap=%s %s %s | pocom=%s | rule=%s %s\n" % (
                e["doc"], e["date"], e["grain"], e["side"], e["name"], e["header_14w"], (e["chapter"] or "")[:28],
                ",".join(e["territory"] or []), ",".join(c.split("/")[0].replace("diplomatic", "d.").replace("ForeignMissions", "FM") for c in e["categories"]),
                e["pocom"], e["chapter_rule"], e.get("holder_posts_on_date", "")))
