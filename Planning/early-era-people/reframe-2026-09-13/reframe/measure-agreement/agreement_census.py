#!/usr/bin/env python3
"""Corpus-scale census of the detector-agreement arm (#234 reframe, label measure-agreement).

Over the TEI-rule scope (~/frus-ner-raw/scope.json: 267 volumes). Arm = agreement.agreement_spans
(editor ∪ filtered-sweep spans overlapping ≥1 filtered-control span, exact (s,e,n) dedup), keyed by
census.py's K2. Also: what the arm adds beyond the editor layer (with TEI regions), the three
disagreement pools, and a POCOM surname-in-office ceiling (measure_pocom.py's loader and rule).

Positive controls (fatal unless noted): store row totals == census.json; marked and marked∪filtered-control
artifacts, pairs and documents == census.json; R-0 length parity for every document; every row slices back;
POCOM loader stats == pocom.json; agreement spans over the 64 M2a documents == 350 (grains mention grain).
Writes agreement-census.json, per-volume.csv and artifact-*.json(.gz) beside this script.
"""
import collections
import csv
import json
import os
import statistics
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import agreement as A                    # noqa: E402
import census_orig_copy as census        # noqa: E402
import measure_pocom_copy as mp          # noqa: E402
ner_store = census.ner_store

HOME = os.path.expanduser("~")
FEAS = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12"
E_STORE = os.path.join(HOME, "frus-ner-raw")
FC_STORE = os.path.join(HOME, "frus-ner-raw-control-filtered")
FS_STORE = os.path.join(HOME, "frus-ner-raw-filtered")
TEXT_DIR = os.path.join(HOME, "frus-semantic-raw/text")
VOLUMES = "/Users/jbotts/Development/frus/volumes"
GOLD_DOCS = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/m2a-ground-truth-documents.jsonl"
BANDS = ["1861-1899", "1900-1929", "1930-1945", "1946-"]
POOLS = ["fc_only", "fs_only", "three_way_minus_agreement"]
STATUS = ["no_surname_token", "surname_not_in_pocom", "known_doc_undated", "known_nobody_in_office_doc_year",
          "known_several_in_office_doc_year", "known_exactly_one_in_office_doc_year"]


def q(values, p):
    v = sorted(values)
    if not v:
        return None
    return v[min(len(v) - 1, int(round(p * (len(v) - 1))))]


def dist(values):
    if not values:
        return None
    return {"n": len(values), "mean": round(sum(values) / len(values), 3), "median": statistics.median(values),
            "p90": q(values, 0.9), "p99": q(values, 0.99), "max": max(values)}


def main():
    t0 = time.time()
    cen = json.load(open(os.path.join(FEAS, "measure-census/census.json")))
    poc = json.load(open(os.path.join(FEAS, "measure-pocom/pocom.json")))
    volumes = ner_store.scope_volumes(E_STORE)
    assert len(volumes) == 267

    # ---- POCOM, measure_pocom.py's loader verbatim
    surnames, spans, by_surname = mp.load_pocom()
    by_surname_cf = collections.defaultdict(set)
    for sur, slugs in by_surname.items():
        by_surname_cf[sur.casefold()] |= slugs
    pocom_stats = {"people_files": len(mp.glob.glob(f"{mp.POCOM}/people/*/*.xml")), "people_with_surname": len(surnames),
                   "people_with_dated_appointment": len(spans), "distinct_surnames_with_dated_appointment": len(by_surname),
                   "distinct_surnames_casefolded": len(by_surname_cf)}
    assert pocom_stats == poc["pocom"], (pocom_stats, poc["pocom"])
    status_cache = {}

    def status_of(n, year):
        ck = (n, year)
        if ck in status_cache:
            return status_cache[ck]
        key, stripped = mp.k2_surface(mp.text_of(n))
        sur = mp.surname_of(stripped) if key else None
        if not sur:
            st = 0
        else:
            cands = by_surname_cf.get(sur.casefold())
            if not cands:
                st = 1
            elif year is None:
                st = 2
            else:
                live = mp.live_count(cands, spans, year, year)
                st = 3 if live == 0 else (5 if live == 1 else 4)
        status_cache[ck] = st
        return st

    gold_docs = set()
    for line in open(GOLD_DOCS, encoding="utf-8"):
        if line.strip():
            r = json.loads(line)
            gold_docs.add((r["v"], r["d"]))
    assert len(gold_docs) == 64

    k2cache = {}

    def K(n):
        v = k2cache.get(n)
        if v is None:
            v = k2cache[n] = A.k2_of(n)
        return v

    accs = {label: census.ArmAcc(label) for label in
            ("marked", "union_marked_filtered_control", "agreement", "intersection_sweep_side")}
    C = collections.Counter                                    # scalar counters, keyed (metric, band)
    c = C()
    keysets = collections.defaultdict(set)                     # (name, band) -> set of K2
    agr_k2_counter = C()
    added_per_doc = collections.defaultdict(list)              # band -> [added pairs per gaining doc]
    region_rows = C()                                          # (population, band, region)
    added_sig = C()                                            # (band, signature)
    key_best_status = {}                                       # K2 -> best status over agreement pairs
    key_best_status_added = {}                                 # K2 -> best status over ADDED pairs
    key_best_band = collections.defaultdict(dict)              # band -> K2 -> best status
    docs_total, docs_by_band = 0, C()
    gold_agreement_spans = 0
    per_volume = []
    parity = {"docs_text_layer": 0, "length_mismatch": [], "rows_doc_missing_from_regions": 0,
              "rows_not_slicing_back": 0, "docs_regions_not_in_text_layer": 0}
    head_problems = []
    zero_len = C()

    for i, vol in enumerate(volumes):
        band = ner_store.band_of(vol)
        mh = ner_store.layer_head(E_STORE, "marked", vol)
        n_docs = mh["docs"]
        docs_total += n_docs
        docs_by_band[band] += n_docs
        layers = {}
        for name, store, layer in (("E", E_STORE, "marked"), ("FC", FC_STORE, "detected"), ("FS", FS_STORE, "detected")):
            rows = ner_store.volume_layer(store, layer, vol)
            head = ner_store.layer_head(store, layer, vol)
            hd = head.get("docs", head.get("docs_in_volume")) if head else None
            if head is None or head.get("mentions") != len(rows) or hd != n_docs or (name != "E" and head.get("sampled") is not False):
                head_problems.append((name, vol))
            c[("rows_" + name, "all")] += len(rows)
            layers[name] = rows
        xml = open(os.path.join(VOLUMES, vol + ".xml"), encoding="utf-8").read()
        reg = A.document_regions(xml)
        texts = ner_store.volume_text(TEXT_DIR, vol)
        parity["docs_text_layer"] += len(texts)
        for d, t in texts.items():
            if d not in reg or reg[d][0] != len(t):
                parity["length_mismatch"].append((vol, d))
        parity["docs_regions_not_in_text_layer"] += sum(1 for d in reg if d not in texts)

        by_doc = {"E": collections.defaultdict(list), "FC": collections.defaultdict(list), "FS": collections.defaultdict(list)}
        e_ft = collections.defaultdict(set)
        for name, rows in layers.items():
            for r in rows:
                t = texts.get(r["d"])
                if t is None or t[r["s"]:r["e"]] != r["n"]:
                    parity["rows_not_slicing_back"] += 1
                if r["d"] not in reg:
                    parity["rows_doc_missing_from_regions"] += 1
                if r["e"] <= r["s"]:
                    zero_len[name] += 1
                sp = (r["s"], r["e"], r["n"])
                by_doc[name][r["d"]].append(sp)
                if name == "E" and r.get("t") in ("from", "to"):
                    e_ft[r["d"]].add(sp)

        dr = {label: {} for label in accs}
        vrow = C()
        for d in sorted(set(by_doc["E"]) | set(by_doc["FC"]) | set(by_doc["FS"])):
            e, fc, fs = by_doc["E"].get(d, []), by_doc["FC"].get(d, []), by_doc["FS"].get(d, [])
            int_fs, fs_only, int_fc, fc_only = A.split_detectors(fc, fs)
            agr = set(e) | set(int_fs)
            if (vol, d) in gold_docs:
                gold_agreement_spans += len(agr)
            rentry = reg.get(d)
            year = rentry[1] if rentry else None
            ftset = e_ft.get(d, set())
            if e:
                dr["marked"][d] = [(K(n), (s, en, n) in ftset) for s, en, n in e]
            if e or fc:
                dr["union_marked_filtered_control"][d] = [(K(n), (s, en, n) in ftset) for s, en, n in e] + [(K(n), False) for _, _, n in fc]
            if agr:
                dr["agreement"][d] = [(K(n), (s, en, n) in ftset) for s, en, n in e] + [(K(n), False) for _, _, n in int_fs]
            if int_fs:
                dr["intersection_sweep_side"][d] = [(K(n), False) for _, _, n in int_fs]

            kE = {K(n) for _, _, n in e}
            kA = {K(sp[2]) for sp in agr}
            kFC = {K(n) for _, _, n in fc}
            kFS = {K(n) for _, _, n in fs}
            for b in (band, "all"):
                c[("agr_rows_summed", b)] += len(e) + len(int_fs)
                c[("agr_rows_distinct_span_text", b)] += len(agr)
                c[("agr_rows_distinct_offsets", b)] += len({(s, en) for s, en, _ in agr})
                c[("agr_rows_from_editor_distinct", b)] += len(set(e))
                c[("agr_rows_intersection_distinct_not_editor", b)] += len(set(int_fs) - set(e))
                c[("int_fs_rows_raw", b)] += len(int_fs)
                c[("int_fc_rows_raw", b)] += len(int_fc)
                c[("fc_rows", b)] += len(fc)
                c[("fs_rows", b)] += len(fs)
                c[("e_rows", b)] += len(e)
                c[("agr_pairs", b)] += len(kA)
                c[("e_pairs", b)] += len(kE)
                if kA:
                    c[("agr_docs", b)] += 1
                if kE:
                    c[("e_docs", b)] += 1
            vrow["agr_rows_distinct"] += len(agr)
            vrow["agr_pairs"] += len(kA)
            vrow["agr_docs"] += 1 if kA else 0
            for sp in agr:
                agr_k2_counter[K(sp[2])] += 1
            keysets[("agr", band)] |= kA
            keysets[("agr", "all")] |= kA
            keysets[("e", "all")] |= kE

            # ---- regions of the arm's distinct rows, by origin
            if rentry:
                eset = set(e)
                for sp in agr:
                    origin = "editor" if sp in eset else "intersection"
                    region_rows[("agr_" + origin, band, A.region_of(sp[0], rentry))] += 1
                for sp in ftset:
                    region_rows[("editor_typed_fromto", band, A.region_of(sp[0], rentry))] += 1

            # ---- task 2: beyond the editor layer
            added = kA - kE
            if added:
                vrow["added_pairs"] += len(added)
                vrow["docs_gaining"] += 1
                e_last = {k.split()[-1] for k in kE if k.split()}
                for b in (band, "all"):
                    c[("docs_gaining", b)] += 1
                    c[("docs_gaining_no_editor_name", b) if not kE else ("docs_gaining_with_editor_name", b)] += 1
                    c[("added_pairs", b)] += len(added)
                    c[("added_pairs_last_token_equals_an_editor_key_last_token", b)] += sum(1 for k in added if k.split() and k.split()[-1] in e_last)
                    added_per_doc[b].append(len(added))
                keysets[("added", band)] |= added
                keysets[("added", "all")] |= added
                rows_by_key = collections.defaultdict(set)
                for sp in set(int_fs) - set(e):
                    k = K(sp[2])
                    if k in added:
                        rows_by_key[k].add(A.region_of(sp[0], rentry) if rentry else "no_region")
                        region_rows[("added", band, A.region_of(sp[0], rentry) if rentry else "no_region")] += 1
                for k, regs in rows_by_key.items():
                    added_sig[(band, "+".join(sorted(regs)))] += 1

            # ---- task 3: disagreement pools
            three = set(e) | set(fc) | set(fs)
            pool3 = three - agr
            kThree = kE | kFC | kFS
            pools = {"fc_only": (fc_only, {K(n) for _, _, n in fc_only}),
                     "fs_only": (fs_only, {K(n) for _, _, n in fs_only}),
                     "three_way_minus_agreement": (pool3, {K(sp[2]) for sp in pool3})}
            for pname, (prow, pkeys) in pools.items():
                net = (kThree - kA) if pname == "three_way_minus_agreement" else (pkeys - kA)
                for b in (band, "all"):
                    c[(pname + "_rows_raw", b)] += len(prow)
                    c[(pname + "_rows_distinct_span_text", b)] += len(set(prow))
                    c[(pname + "_pairs_gross", b)] += len(pkeys)
                    c[(pname + "_pairs_net_of_agreement", b)] += len(net)
                    if net:
                        c[(pname + "_docs_with_net_pair", b)] += 1
                keysets[(pname + "_gross", band)] |= pkeys
                keysets[(pname + "_gross", "all")] |= pkeys
                keysets[(pname + "_net", band)] |= net
                keysets[(pname + "_net", "all")] |= net
                if rentry:
                    for sp in set(prow):
                        region_rows[(pname, band, A.region_of(sp[0], rentry))] += 1

            # ---- task 4: POCOM surname in office in the document's year (ceiling)
            surf_by_key = collections.defaultdict(set)
            for sp in agr:
                surf_by_key[K(sp[2])].add(sp[2])
            for k, surfs in surf_by_key.items():
                st = max(status_of(n, year) for n in surfs)
                origin = "added" if k in added else "editor"
                for b in (band, "all"):
                    c[("pocom_pairs", origin, b, st)] += 1
                    c[("pocom_pairs", "all_agreement", b, st)] += 1
                if st > key_best_status.get(k, -1):
                    key_best_status[k] = st
                if st > key_best_band[band].get(k, -1):
                    key_best_band[band][k] = st
                if origin == "added" and st > key_best_status_added.get(k, -1):
                    key_best_status_added[k] = st

        for label, acc in accs.items():
            acc.add_volume(vol, band, dr[label], None)
        per_volume.append(dict(volume=vol, band=band, docs=n_docs, **vrow))
        if (i + 1) % 25 == 0:
            print("  %d/%d volumes, %.0fs" % (i + 1, len(volumes), time.time() - t0), file=sys.stderr)

    # ---------------------------------------------------------------- controls
    arts = {label: acc.finish() for label, acc in accs.items()}
    controls = {
        "store_rows": {n: {"expected": cen["positive_controls"][lab]["expected"], "measured": c[("rows_" + n, "all")]}
                       for n, lab in (("E", "marked"), ("FC", "filtered_control"), ("FS", "filtered_sweep"))},
        "scope_documents": {"expected": cen["scope"]["documents"], "measured": docs_total},
        "census_arms": {},
        "editor_typed_fromto_rows_by_region": {b: {r: region_rows[("editor_typed_fromto", b, r)] for r in A.REGIONS} for b in BANDS},
        "r0_parity": {"docs_text_layer": parity["docs_text_layer"], "length_mismatches": len(parity["length_mismatch"]),
                      "first": parity["length_mismatch"][:5], "rows_not_slicing_back": parity["rows_not_slicing_back"],
                      "rows_whose_document_has_no_region_entry": parity["rows_doc_missing_from_regions"],
                      "regions_not_in_text_layer": parity["docs_regions_not_in_text_layer"]},
        "head_problems": head_problems,
        "zero_length_rows": dict(zero_len),
        "gold_64_documents_agreement_spans": {"expected": 350, "measured": gold_agreement_spans},
        "pocom_loader": {"expected": poc["pocom"], "measured": pocom_stats},
    }
    for label in ("marked", "union_marked_filtered_control"):
        ca = cen["arms"][label]
        acc = accs[label]
        exp = (ca["pairs_volume_doc_K2"], ca["docs_with_mention"], ca["artifact"]["bytes"], ca["artifact"]["gzip_bytes"], ca["distinct_K2"])
        got = (acc.pairs, acc.docs_with_mention, arts[label][0], arts[label][1], len(acc.vocab))
        controls["census_arms"][label] = {"expected_pairs_docs_bytes_gz_vocab": exp, "measured": got, "ok": exp == got}
    ok = (all(v["expected"] == v["measured"] for v in controls["store_rows"].values())
          and controls["scope_documents"]["expected"] == docs_total
          and all(v["ok"] for v in controls["census_arms"].values())
          and not parity["length_mismatch"] and parity["rows_not_slicing_back"] == 0
          and parity["rows_doc_missing_from_regions"] == 0 and not head_problems
          and gold_agreement_spans == 350)
    controls["all_ok"] = ok

    # ---------------------------------------------------------------- assemble
    def by_band(metric):
        return {b: c[(metric, b)] for b in BANDS + ["all"]}

    def share(num, den):
        return round(num / den, 4) if den else None

    agr_acc = accs["agreement"]
    int_acc = accs["intersection_sweep_side"]
    res = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "script": os.path.abspath(__file__),
        "population": "TEI-rule scope: ~/frus-ner-raw/scope.json, 267 volumes, documents = sum of marked heads' docs",
        "scope": {"volumes": len(volumes), "documents": docs_total, "documents_by_band": dict(docs_by_band)},
        "definitions": {
            "arm": "editor marks ∪ {filtered-sweep span overlapping (>0 code points) ≥1 filtered-control span in the same document}; union removes exact (s,e,surface) duplicates (grains.py union_exact); intersection = grains.py intersection(FS, FC)",
            "key": "census.py K2: casefold, whitespace collapse, trailing possessive stripped, ONE leading honorific from its 29-token list stripped",
            "pair": "(volume, document, K2) distinct",
            "regions": "agreement.document_regions over the TEI document div, offsets in R-0 coordinates; a row's region is that of its start offset; precedence note > head (first <head>) > other_head (later <head>s, chiefly enclosure headings) > apparatus (opener/closer/dateline/salute/signed/postscript/byline) > prose",
            "added": "agreement pairs whose K2 is not among the editor layer's K2 keys in the same document",
            "pools": {"fc_only": "filtered-control rows overlapping NO filtered-sweep row in the document",
                      "fs_only": "filtered-sweep rows overlapping NO filtered-control row in the document",
                      "three_way_minus_agreement": "distinct (s,e,surface) rows of editor ∪ filtered control ∪ filtered sweep not in the arm",
                      "pairs_gross": "distinct (doc,K2) among the pool's rows",
                      "pairs_net_of_agreement": "those whose K2 the arm does not already carry in that document (for the three-way pool: three-way pairs minus arm pairs)",
                      "keys_net_of_agreement_vocabulary": "pool keys (gross) that appear nowhere in the arm's corpus-wide vocabulary"},
            "pocom": "measure_pocom.py load_pocom (verbatim copy), surname = surname_of(k2_surface(text_of(surface)) stripped form), looked up casefolded; in office = live_count over [doc year, doc year] with its ±1; doc year = TEI frus:doc-dateTime-min (first 600 chars of the div, measure_pocom tei_doc_years rule); a pair's status is the best over its surfaces; a key's status is the best over its pairs. A CEILING: an officeholder of that surname was in office, not that the name is that person.",
        },
        "positive_controls": controls,
        "task1_agreement_arm": {
            "rows_summed_editor_plus_intersection": by_band("agr_rows_summed"),
            "rows_distinct_span_text": by_band("agr_rows_distinct_span_text"),
            "rows_distinct_offsets": by_band("agr_rows_distinct_offsets"),
            "rows_from_editor_distinct": by_band("agr_rows_from_editor_distinct"),
            "rows_intersection_not_editor_distinct": by_band("agr_rows_intersection_distinct_not_editor"),
            "intersection_sweep_side_rows_raw": by_band("int_fs_rows_raw"),
            "pairs": {b: (agr_acc.pairs_by_band[b] if b != "all" else agr_acc.pairs) for b in BANDS + ["all"]},
            "distinct_K2": {b: len(keysets[("agr", b)]) for b in BANDS + ["all"]},
            "documents_reached": {b: {"docs": (agr_acc.docs_by_band[b] if b != "all" else agr_acc.docs_with_mention),
                                      "share": share(agr_acc.docs_by_band[b] if b != "all" else agr_acc.docs_with_mention,
                                                     docs_by_band[b] if b != "all" else docs_total)} for b in BANDS + ["all"]},
            "docs_only_marked_fromto": agr_acc.docs_only_fromto,
            "per_volume_distinct_K2": {"median": statistics.median(agr_acc.per_volume_k2.values()), "max": max(agr_acc.per_volume_k2.values()),
                                       "max_volume": max(agr_acc.per_volume_k2, key=agr_acc.per_volume_k2.get)},
            "rows_per_scope_document": share(c[("agr_rows_distinct_span_text", "all")], docs_total),
            "artifact_grouped_one_letter": {"path": agr_acc.path, "bytes": arts["agreement"][0], "gzip_bytes": arts["agreement"][1], "vocab_size": len(agr_acc.vocab)},
            "concentration_K2_over_distinct_rows": {k: v for k, v in census.concentration(agr_k2_counter).items()},
            "region_of_distinct_rows": {origin: {b: {r: region_rows[("agr_" + origin, b, r)] for r in A.REGIONS} for b in BANDS}
                                        for origin in ("editor", "intersection")},
            "intersection_sweep_side_alone": {"pairs": int_acc.pairs, "docs_reached": int_acc.docs_with_mention,
                                              "docs_by_band": dict(int_acc.docs_by_band), "distinct_K2": len(int_acc.vocab),
                                              "artifact_bytes": arts["intersection_sweep_side"][0], "artifact_gzip_bytes": arts["intersection_sweep_side"][1]},
            "intersection_control_side_rows_raw": by_band("int_fc_rows_raw"),
        },
        "comparators_same_pass": {
            "editor": {"pairs": accs["marked"].pairs, "docs": accs["marked"].docs_with_mention, "distinct_K2": len(accs["marked"].vocab),
                       "bytes": arts["marked"][0], "gzip_bytes": arts["marked"][1], "pairs_by_band": dict(accs["marked"].pairs_by_band),
                       "docs_by_band": dict(accs["marked"].docs_by_band)},
            "editor_union_filtered_control": {"pairs": accs["union_marked_filtered_control"].pairs, "docs": accs["union_marked_filtered_control"].docs_with_mention,
                                              "distinct_K2": len(accs["union_marked_filtered_control"].vocab),
                                              "bytes": arts["union_marked_filtered_control"][0], "gzip_bytes": arts["union_marked_filtered_control"][1],
                                              "pairs_by_band": dict(accs["union_marked_filtered_control"].pairs_by_band),
                                              "docs_by_band": dict(accs["union_marked_filtered_control"].docs_by_band)},
        },
        "task2_beyond_editor": {
            "docs_gaining_at_least_one_name": {b: {"docs": c[("docs_gaining", b)],
                                                   "share_of_scope_docs": share(c[("docs_gaining", b)], docs_by_band[b] if b != "all" else docs_total),
                                                   "with_no_editor_name": c[("docs_gaining_no_editor_name", b)],
                                                   "already_with_editor_name": c[("docs_gaining_with_editor_name", b)]} for b in BANDS + ["all"]},
            "added_pairs": by_band("added_pairs"),
            "added_pairs_per_scope_document": {b: share(c[("added_pairs", b)], docs_by_band[b] if b != "all" else docs_total) for b in BANDS + ["all"]},
            "added_pairs_per_gaining_document": {b: dist(added_per_doc[b]) for b in BANDS + ["all"]},
            "added_distinct_K2": {b: len(keysets[("added", b)]) for b in BANDS + ["all"]},
            "added_K2_never_in_editor_vocabulary": len(keysets[("added", "all")] - keysets[("e", "all")]),
            "added_pairs_last_token_equals_an_editor_key_last_token_same_doc": by_band("added_pairs_last_token_equals_an_editor_key_last_token"),
            "added_rows_by_region": {b: {r: region_rows[("added", b, r)] for r in A.REGIONS + ("no_region",)} for b in BANDS},
            "added_pair_region_signature": {b: {sig: n for (bb, sig), n in sorted(added_sig.items()) if bb == b} for b in BANDS},
        },
        "task3_pools": {p: {
            "rows_raw": by_band(p + "_rows_raw"),
            "rows_distinct_span_text": by_band(p + "_rows_distinct_span_text"),
            "pairs_gross": by_band(p + "_pairs_gross"),
            "pairs_net_of_agreement": by_band(p + "_pairs_net_of_agreement"),
            "docs_with_net_pair": by_band(p + "_docs_with_net_pair"),
            "distinct_K2_gross": {b: len(keysets[(p + "_gross", b)]) for b in BANDS + ["all"]},
            "distinct_K2_net_of_agreement_pairs": {b: len(keysets[(p + "_net", b)]) for b in BANDS + ["all"]},
            "distinct_K2_gross_absent_from_agreement_vocabulary": {b: len(keysets[(p + "_gross", b)] - keysets[("agr", "all")]) for b in BANDS + ["all"]},
            "rows_distinct_by_region": {b: {r: region_rows[(p, b, r)] for r in A.REGIONS} for b in BANDS},
        } for p in POOLS},
        "task4_pocom_ceiling": {},
        "elapsed_secs": None,
    }
    for origin in ("all_agreement", "editor", "added"):
        blk = {}
        for b in BANDS + ["all"]:
            cnt = {STATUS[s]: c[("pocom_pairs", origin, b, s)] for s in range(6)}
            tot = sum(cnt.values())
            in_office = cnt["known_several_in_office_doc_year"] + cnt["known_exactly_one_in_office_doc_year"]
            known = tot - cnt["no_surname_token"] - cnt["surname_not_in_pocom"]
            blk[b] = dict(cnt, pairs=tot, surname_known=known, surname_in_office_doc_year=in_office,
                          share_in_office=share(in_office, tot),
                          share_exactly_one_in_office=share(cnt["known_exactly_one_in_office_doc_year"], tot))
        res["task4_pocom_ceiling"]["pairs_" + origin] = blk

    def key_summary(best):
        cnt = C(best.values())
        tot = len(best)
        in_office = cnt[4] + cnt[5]
        return {"keys": tot, "surname_known": tot - cnt[0] - cnt[1], "in_office_in_some_doc_year": in_office,
                "exactly_one_in_office_in_some_doc_year": cnt[5], "share_in_office": share(in_office, tot),
                "by_status": {STATUS[s]: cnt[s] for s in range(6)}}
    res["task4_pocom_ceiling"]["distinct_K2_agreement"] = key_summary(key_best_status)
    res["task4_pocom_ceiling"]["distinct_K2_occurring_as_added"] = key_summary(key_best_status_added)
    res["task4_pocom_ceiling"]["distinct_K2_by_band"] = {b: key_summary(key_best_band[b]) for b in BANDS}
    res["elapsed_secs"] = round(time.time() - t0, 1)

    with open(os.path.join(HERE, "agreement-census.json"), "w", encoding="utf-8") as fh:
        json.dump(res, fh, indent=1, ensure_ascii=False)
    keys = sorted({k for r in per_volume for k in r})
    with open(os.path.join(HERE, "per-volume.csv"), "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["volume", "band", "docs"] + [k for k in keys if k not in ("volume", "band", "docs")])
        w.writeheader()
        w.writerows(per_volume)
    print(json.dumps(controls, indent=1, ensure_ascii=False))
    print("elapsed", res["elapsed_secs"])
    if not ok:
        sys.exit("POSITIVE CONTROL FAILED — see agreement-census.json positive_controls")


if __name__ == "__main__":
    main()
