#!/usr/bin/env python3
"""Follow-up to agreement_census.py: (1) TEI documents with no frus:doc-dateTime-min in the first 600 chars
(checks the census's zero `known_doc_undated`); (2) most frequent K2 keys among ADDED pairs and among each
pool's NET pairs, with single-token shares; (3) sum over volumes of per-volume distinct K2 (the persons-row
grain analogue) for editor, editor ∪ filtered control, filtered control, filtered sweep and the arm.
Same arm and key as agreement.py. Writes followup.json."""
import collections, json, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import agreement as A
import census_orig_copy as census
ner_store = census.ner_store
HOME = os.path.expanduser("~")
E_STORE, FC_STORE, FS_STORE = (os.path.join(HOME, x) for x in ("frus-ner-raw", "frus-ner-raw-control-filtered", "frus-ner-raw-filtered"))
BANDS = ["1861-1899", "1900-1929", "1930-1945", "1946-"]

def main():
    t0 = time.time()
    vols = ner_store.scope_volumes(E_STORE)
    k2c = {}
    def K(n):
        v = k2c.get(n)
        if v is None:
            v = k2c[n] = A.k2_of(n)
        return v
    cnt = {name: collections.Counter() for name in ("added", "fc_only_net", "fs_only_net", "three_way_net")}
    tok = collections.Counter()
    undated = collections.Counter(); undated_with_agr = collections.Counter(); docs_tei = collections.Counter()
    pv_sum = collections.Counter()
    for vol in vols:
        band = ner_store.band_of(vol)
        reg = A.document_regions(open("/Users/jbotts/Development/frus/volumes/%s.xml" % vol, encoding="utf-8").read())
        for d, entry in reg.items():
            docs_tei[band] += 1
            if entry[1] is None:
                undated[band] += 1
        by = {}
        for name, store, layer in (("E", E_STORE, "marked"), ("FC", FC_STORE, "detected"), ("FS", FS_STORE, "detected")):
            g = collections.defaultdict(list)
            for r in ner_store.volume_layer(store, layer, vol):
                g[r["d"]].append((r["s"], r["e"], r["n"]))
            by[name] = g
        vk = collections.defaultdict(set)
        for d in set(by["E"]) | set(by["FC"]) | set(by["FS"]):
            e, fc, fs = by["E"].get(d, []), by["FC"].get(d, []), by["FS"].get(d, [])
            int_fs, fs_only, _, fc_only = A.split_detectors(fc, fs)
            agr = set(e) | set(int_fs)
            kE = {K(x[2]) for x in e}; kA = {K(x[2]) for x in agr}; kFC = {K(x[2]) for x in fc}; kFS = {K(x[2]) for x in fs}
            vk["editor"] |= kE; vk["agreement"] |= kA; vk["filtered_control"] |= kFC; vk["filtered_sweep"] |= kFS
            vk["editor_union_filtered_control"] |= kE | kFC
            if kA and reg.get(d, (0, 1))[1] is None:
                undated_with_agr[band] += 1
            sets = {"added": kA - kE, "fc_only_net": {K(x[2]) for x in fc_only} - kA,
                    "fs_only_net": {K(x[2]) for x in fs_only} - kA, "three_way_net": (kE | kFC | kFS) - kA}
            for name, ks in sets.items():
                for k in ks:
                    cnt[name][k] += 1
                    tok[(name, band, "single" if len(k.split()) == 1 else "multi")] += 1
        for name, ks in vk.items():
            pv_sum[name] += len(ks)
    out = {"script": os.path.abspath(__file__),
           "tei_documents_with_text": dict(docs_tei), "tei_documents_without_doc_dateTime_min_in_first_600_chars": dict(undated),
           "undated_documents_carrying_an_agreement_pair": dict(undated_with_agr),
           "sum_over_volumes_of_distinct_K2": dict(pv_sum), "keys": {}}
    for name, c in cnt.items():
        pairs = sum(c.values())
        single = {b: tok[(name, b, "single")] for b in BANDS}
        multi = {b: tok[(name, b, "multi")] for b in BANDS}
        out["keys"][name] = {"pairs": pairs, "distinct_K2": len(c),
                             "pairs_single_token_key": sum(single.values()), "share_single_token": round(sum(single.values()) / pairs, 4) if pairs else None,
                             "single_token_by_band": single, "multi_token_by_band": multi,
                             "pairs_on_keys_seen_once_corpus_wide": sum(v for v in c.values() if v == 1),
                             "top40": c.most_common(40)}
    out["elapsed_secs"] = round(time.time() - t0, 1)
    json.dump(out, open(os.path.join(HERE, "followup.json"), "w"), indent=1, ensure_ascii=False)
    print(json.dumps({k: v for k, v in out.items() if k != "keys"}, indent=1))
    for name, v in out["keys"].items():
        print(name, {k: v[k] for k in v if k not in ("top40",)})
        print("   ", v["top40"])

main()
