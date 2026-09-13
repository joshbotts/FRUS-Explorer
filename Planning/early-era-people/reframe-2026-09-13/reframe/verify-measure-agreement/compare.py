#!/usr/bin/env python3
"""Diff v-census.json (independent) against measure-agreement's outputs. Writes compare.json."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
M = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/reframe/measure-agreement"
A = json.load(open(M + "/agreement-census.json")); S = json.load(open(M + "/summary.json"))
F = json.load(open(M + "/followup.json")); P = json.load(open(M + "/persons-rows-agreement.json"))
V = json.load(open(HERE + "/v-census.json"))
B = ["1861-1899", "1900-1929", "1930-1945", "1946-"]; BA = B + ["all"]
rows = []
def cmp(name, theirs, mine):
    rows.append({"figure": name, "theirs": theirs, "mine": mine, "equal": theirs == mine})
t1, v1 = A["task1_agreement_arm"], V["task1"]
cmp("scope docs by band", A["scope"]["documents_by_band"], {b: V["docs"][b] for b in B})
cmp("arm rows distinct", t1["rows_distinct_span_text"], v1["rows_distinct"])
cmp("arm rows editor", t1["rows_from_editor_distinct"], v1["rows_editor"])
cmp("arm rows intersection-not-editor", t1["rows_intersection_not_editor_distinct"], v1["rows_int_not_editor"])
cmp("int_fs rows (theirs raw, mine distinct)", t1["intersection_sweep_side_rows_raw"], v1["int_fs_distinct"])
cmp("int_fc rows (theirs raw, mine distinct)", t1["intersection_control_side_rows_raw"], v1["int_fc_distinct"])
cmp("arm pairs", t1["pairs"], v1["pairs"])
cmp("arm distinct K2", t1["distinct_K2"], v1["distinct_K2"])
cmp("arm docs reached", {b: t1["documents_reached"][b]["docs"] for b in BA}, v1["docs_reached"])
cmp("per-volume distinct K2", {k: t1["per_volume_distinct_K2"][k] for k in ("median", "max", "max_volume")}, v1["per_volume_distinct_K2"])
cmp("artifact bytes/gz/vocab", [t1["artifact_grouped_one_letter"][k] for k in ("bytes", "gzip_bytes", "vocab_size")], [v1["artifact"][k] for k in ("bytes", "gzip", "vocab")] if "gzip" in v1["artifact"] else [v1["artifact"][k] for k in ("bytes", "gzip_bytes", "vocab")])
ce = A["comparators_same_pass"]
cmp("editor pairs/docs/K2", [ce["editor"]["pairs"], ce["editor"]["docs"], ce["editor"]["distinct_K2"]], [v1["editor"]["pairs"]["all"], v1["editor"]["docs"]["all"], v1["editor"]["distinct_K2"]])
cmp("editor∪FC pairs/docs/K2", [ce["editor_union_filtered_control"]["pairs"], ce["editor_union_filtered_control"]["docs"], ce["editor_union_filtered_control"]["distinct_K2"]], [v1["editor_union_fc"]["pairs"]["all"], v1["editor_union_fc"]["docs"]["all"], v1["editor_union_fc"]["distinct_K2"]])
cmp("editor∪FC pairs by band", ce["editor_union_filtered_control"]["pairs_by_band"], {b: v1["editor_union_fc"]["pairs"][b] for b in B})
pr = v1["persons_rows_lowercase_key"]
cmp("persons rows agreement rows/pre1910/corpus/bytes", [P["agreement"][k] for k in ("persons_rows_sum_per_volume_distinct", "pre1910", "corpus_distinct_strings", "name_bytes_sum")], [pr["agreement"][k] for k in ("rows", "pre1910", "corpus_distinct", "name_bytes")])
cmp("persons rows marked / union", [P["marked"]["persons_rows_sum_per_volume_distinct"], P["union_marked_filtered_control"]["persons_rows_sum_per_volume_distinct"]], [pr["marked"]["rows"], pr["union_marked_fc"]["rows"]])
t2, v2 = A["task2_beyond_editor"], V["task2"]
cmp("docs gaining", {b: t2["docs_gaining_at_least_one_name"][b]["docs"] for b in BA}, v2["gain_docs"])
cmp("docs gaining with no editor name", {b: t2["docs_gaining_at_least_one_name"][b]["with_no_editor_name"] for b in BA}, v2["gain_docs_no_editor"])
cmp("added pairs", t2["added_pairs"], v2["added_pairs"])
cmp("added per gaining doc", {k: t2["added_pairs_per_gaining_document"]["all"][k] for k in ("mean", "median", "p90", "p99", "max")}, v2["per_gaining_doc"])
cmp("added distinct K2 / never in editor vocab", [t2["added_distinct_K2"]["all"], t2["added_K2_never_in_editor_vocabulary"]], [v2["added_distinct_K2"], v2["added_never_in_editor_vocab"]])
cmp("added last-token dup", t2["added_pairs_last_token_equals_an_editor_key_last_token_same_doc"], v2["added_lasttok_dup"])
cmp("added single-token pairs", F["keys"]["added"]["pairs_single_token_key"], v2["added_single_token"]["all"])
def sigstats(sig):
    n = sum(sig.values())
    anyp = sum(v for s, v in sig.items() if "prose" in s.split("+"))
    ho = sum(v for s, v in sig.items() if set(s.split("+")) <= {"head", "other_head"})
    return {"pairs": n, "any_prose": anyp, "heading_only": ho, "apparatus_only": sig.get("apparatus", 0), "note_only": sig.get("note", 0)}
theirs_sig = {k: S["added_pairs_region"]["all"][k] for k in ("pairs", "any_prose", "heading_only", "apparatus_only", "note_only")}
cmp("added pair region signature (all)", theirs_sig, sigstats(v2["pair_signature_coarse"]["all"]))
for b in B:
    cmp("added pair region signature " + b, {k: S["added_pairs_region"][b][k] for k in ("pairs", "any_prose", "heading_only", "apparatus_only", "note_only")}, sigstats(v2["pair_signature_coarse"][b]))
mine_rows = {}
for b in B:
    for r, n in v2["rows_region"][b].items():
        mine_rows[r] = mine_rows.get(r, 0) + n
cmp("added rows by region (all)", {k: S["added_rows_region"]["all"][k] for k in ("head", "other_head", "note", "apparatus", "prose")}, {k: mine_rows.get(k, 0) for k in ("head", "other_head", "note", "apparatus", "prose")})
cmp("editor from/to region control", A["positive_controls"]["editor_typed_fromto_rows_by_region"], V["controls"]["editor_fromto_region"])
for p in ("fc_only", "fs_only", "three_way_minus_agreement"):
    tp, vp = A["task3_pools"][p], V["task3"][p]
    cmp(p + " rows", tp["rows_distinct_span_text"], vp["rows"])
    cmp(p + " pairs gross", tp["pairs_gross"], vp["pairs_gross"])
    cmp(p + " pairs net", tp["pairs_net_of_agreement"], vp["pairs_net"])
    cmp(p + " docs net", tp["docs_with_net_pair"], vp["docs_net"])
    cmp(p + " keys gross", tp["distinct_K2_gross"], vp["keys_gross"])
    cmp(p + " keys net", tp["distinct_K2_net_of_agreement_pairs"], vp["keys_net"])
    cmp(p + " keys absent from arm vocab", tp["distinct_K2_gross_absent_from_agreement_vocabulary"]["all"], vp["keys_gross_absent_from_arm_vocab"])
t4 = A["task4_pocom_ceiling"]
for loader in ("quirk_loader", "elementtree_loader"):
    v4 = V["task4"][loader]
    for o_t, o_v in (("all_agreement", "all"), ("editor", "editor"), ("added", "added")):
        cmp("POCOM[%s] %s pairs in_office" % (loader, o_t), {b: t4["pairs_" + o_t][b]["surname_in_office_doc_year"] for b in BA}, {b: v4["pairs"][o_v][b]["in_office"] for b in BA})
        cmp("POCOM[%s] %s pairs exactly_one" % (loader, o_t), {b: t4["pairs_" + o_t][b]["known_exactly_one_in_office_doc_year"] for b in BA}, {b: v4["pairs"][o_v][b]["exactly_one"] for b in BA})
        cmp("POCOM[%s] %s pairs known" % (loader, o_t), {b: t4["pairs_" + o_t][b]["surname_known"] for b in BA}, {b: v4["pairs"][o_v][b]["known"] for b in BA})
    cmp("POCOM[%s] keys all: keys/known/in_office/exactly_one" % loader, [t4["distinct_K2_agreement"][k] for k in ("keys", "surname_known", "in_office_in_some_doc_year", "exactly_one_in_office_in_some_doc_year")], [v4["keys"]["all/all"][k] for k in ("keys", "known", "in_office", "exactly_one")])
    cmp("POCOM[%s] keys added: keys/in_office/exactly_one" % loader, [t4["distinct_K2_occurring_as_added"][k] for k in ("keys", "in_office_in_some_doc_year", "exactly_one_in_office_in_some_doc_year")], [v4["keys"]["added/all"][k] for k in ("keys", "in_office", "exactly_one")])
    cmp("POCOM[%s] keys by band in_office" % loader, {b: [t4["distinct_K2_by_band"][b]["keys"], t4["distinct_K2_by_band"][b]["in_office_in_some_doc_year"]] for b in B}, {b: [v4["keys"]["all/" + b]["keys"], v4["keys"]["all/" + b]["in_office"]] for b in B})
cmp("POCOM loader stats (theirs vs my quirk loader)", A["positive_controls"]["pocom_loader"]["measured"], V["controls"]["pocom_loader_quirk"])
out = {"equal": sum(r["equal"] for r in rows), "total": len(rows), "rows": rows}
json.dump(out, open(HERE + "/compare.json", "w"), indent=1, ensure_ascii=False)
print("EQUAL %d / %d" % (out["equal"], out["total"]))
for r in rows:
    if not r["equal"]:
        print("DIFF:", r["figure"], "\n   theirs:", r["theirs"], "\n   mine:  ", r["mine"])
