#!/usr/bin/env python3
"""measure-claude-jobs/volume_guides.py — INPUT sizes for job D, a correspondents guide per untagged volume and per
chapter (#234 reframe), over the TEI-rule scope (~/frus-ner-raw/scope.json, 267 volumes).

Per volume the input is: (1) the derived correspondent list from the editors' marked layer — one line per census K2
surface (measure_pocom.k2_surface) with its document count and from/to/untyped split; (2) one POCOM career line per
distinct officeholder whose surname (measure_pocom.surname_of) matches a listed surface and who holds any appointment in
the volume's manifest window ±1 (llm-pass/cost-scale/measure_pocom_payload_v2.py's rule and description format,
imported from se_pocom_cases.py); (3) a stride sample of document headers read READ-ONLY from the live index's
document_cache; (4) the volume title and coverage dates from manifest.json. Per chapter the same, restricted to the
documents a volume_structures section lists directly (deepest listing section wins), with a 20-header sample.
Read-only everywhere. Stdlib only. Writes volume-guides.json here.
"""
import sys
sys.dont_write_bytecode = True
import os, json, sqlite3, collections

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
STUDIO = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio"
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
sys.path.insert(0, HERE)
import se_pocom_cases as SC   # noqa: E402  career(), people, appts; also exposes MP, ner_store
MP, ner_store = SC.MP, SC.ner_store
MARKED = os.path.expanduser("~/frus-ner-raw")
SAMPLES = (40, 100)
CH_SAMPLE = 20
TOP = 150


def stride(items, n):
    if len(items) <= n:
        return list(items)
    step = len(items) / n
    return [items[int(i * step)] for i in range(n)]


def stats(xs):
    xs = sorted(xs)
    if not xs:
        return {"n": 0}
    q = lambda f: xs[min(len(xs) - 1, int(f * len(xs)))]
    return {"n": len(xs), "sum": sum(xs), "mean": round(sum(xs) / len(xs), 1), "p50": q(0.5), "p90": q(0.9), "max": xs[-1]}


def main():
    vols = ner_store.scope_volumes(MARKED)
    man = json.load(open(REPO + "/FRUSExplorer/Resources/manifest.json"))
    man = {v["volumeId"]: v for v in (man["volumes"] if isinstance(man, dict) else man)}
    windows = MP.load_windows()
    by_cf = collections.defaultdict(set)
    for slug, pe in SC.people.items():
        if pe["sur"] and slug in SC.appts:
            by_cf[pe["sur"].casefold()].add(slug)
    gold_vols = {json.loads(l)["v"] for l in open(STUDIO + "/frus-m2a/m2a-ground-truth-documents.jsonl")}
    import csv
    id_vols = {x["volume"] for x in csv.DictReader(open(REPO + "/Planning/early-era-people/m1a-eval-candidates.csv")) if int(x["year"]) < 1910}
    con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)
    V, C = [], []
    for vi, v in enumerate(vols):
        lo, hi = windows[v]
        rows = ner_store.volume_layer(MARKED, "marked", v)
        heads = {d: " ".join((h or "").split()) for d, h, fm in
                 con.execute("SELECT document_id, header, is_front_matter FROM document_cache WHERE volume_id=?", (v,)) if not fm}
        sj = con.execute("SELECT structure_json FROM volume_structures WHERE volume_id=?", (v,)).fetchone()
        order, chapter_of, titles = [], {}, {}

        def walk(secs, path):
            for s in secs:
                p = path + [s.get("title") or ""]
                for d in s.get("documentIds") or []:
                    if d not in chapter_of:
                        order.append(d)
                    chapter_of[d] = s.get("sectionId") or "/".join(p)
                    titles[chapter_of[d]] = " > ".join(p)
                walk(s.get("subsections") or [], p)
        walk(json.loads(sj[0]).get("sections", []) if sj else [], [])
        docs_in_order = [d for d in order if d in heads] + sorted(d for d in heads if d not in chapter_of)

        def corr(rowsub):
            K = {}
            for x in rowsub:
                key, stripped = MP.k2_surface(x["n"])
                k = K.setdefault(key, {"forms": collections.Counter(), "docs": set(), "from": 0, "to": 0, "other": 0, "stripped": stripped})
                k["forms"][x["n"]] += 1
                k["docs"].add(x["d"])
                k[x["t"] if x["t"] in ("from", "to") else "other"] += 1
            lines = sorted(((len(k["docs"]), "%s — %d documents (%d from / %d to / %d other)" % (k["forms"].most_common(1)[0][0], len(k["docs"]), k["from"], k["to"], k["other"]), k)
                            for k in K.values()), key=lambda t: (-t[0], t[1]))
            cand = set()
            for _, _, k in lines:
                sur = MP.surname_of(k["stripped"])
                if sur:
                    cand |= {s for s in by_cf.get(sur.casefold(), ()) if any(a - 1 <= hi and lo <= b + 1 for a, b, _ in SC.appts[s])}
            return (len(K), sum(len(l) + 1 for _, l, _ in lines), sum(len(l) + 1 for _, l, _ in lines[:TOP]),
                    len(cand), sum(len(SC.career(s, lo, hi)) + 1 for s in cand))

        nk, cchars, ctop, ncand, pchars = corr(rows)
        meta = len("%s (%s to %s)" % (man.get(v, {}).get("title", v), man.get(v, {}).get("dateRange", {}).get("earliest", ""), man.get(v, {}).get("dateRange", {}).get("latest", "")))
        hs = [heads[d] for d in docs_in_order]
        rec = {"v": v, "band": ner_store.band_of(v), "docs": len(hs), "marked_rows": len(rows), "keys": nk,
               "corr_chars": cchars, "corr_chars_top%d" % TOP: ctop, "pocom_candidates": ncand, "pocom_chars": pchars,
               "meta_chars": meta, "headers_all_chars": sum(len(h) + 1 for h in hs),
               **{"headers_sample%d_chars" % n: sum(len(h) + 1 for h in stride(hs, n)) for n in SAMPLES},
               "gold_volume": v in gold_vols, "identity_volume": v in id_vols}
        by_ch = collections.defaultdict(list)
        for x in rows:
            by_ch[chapter_of.get(x["d"], "(unsectioned)")].append(x)
        ch_docs = collections.defaultdict(list)
        for d in docs_in_order:
            ch_docs[chapter_of.get(d, "(unsectioned)")].append(d)
        chs = []
        for ch, ds in ch_docs.items():
            nk2, cc2, _, nc2, pc2 = corr(by_ch.get(ch, []))
            hh = [heads[d] for d in ds]
            chs.append({"docs": len(ds), "marked_rows": len(by_ch.get(ch, [])), "keys": nk2, "corr_chars": cc2, "pocom_candidates": nc2,
                        "pocom_chars": pc2, "title_chars": len(titles.get(ch, ch)), "headers_sample_chars": sum(len(h) + 1 for h in stride(hh, CH_SAMPLE))})
        rec["chapters"] = len(chs)
        rec["chapters_with_marked_rows"] = sum(1 for c in chs if c["marked_rows"])
        rec["chapters_ge5_docs"] = sum(1 for c in chs if c["docs"] >= 5)
        rec["chapter_input_chars"] = sum(c["corr_chars"] + c["pocom_chars"] + c["title_chars"] + c["headers_sample_chars"] + meta for c in chs)
        rec["chapter_input_chars_marked_only"] = sum(c["corr_chars"] + c["pocom_chars"] + c["title_chars"] + c["headers_sample_chars"] + meta for c in chs if c["marked_rows"])
        rec["chapter_input_chars_ge5_marked"] = sum(c["corr_chars"] + c["pocom_chars"] + c["title_chars"] + c["headers_sample_chars"] + meta for c in chs if c["marked_rows"] and c["docs"] >= 5)
        rec["chapters_ge5_docs_with_marked"] = sum(1 for c in chs if c["marked_rows"] and c["docs"] >= 5)
        V.append(rec)
        C.extend(dict(c, v=v) for c in chs)
        if (vi + 1) % 25 == 0:
            print("[%d/%d] %s" % (vi + 1, len(vols), v), file=sys.stderr)

    def inp(r, n):
        return r["corr_chars"] + r["pocom_chars"] + r["meta_chars"] + r["headers_sample%d_chars" % n]

    tot = lambda f, sub=V: sum(r[f] for r in sub)
    out = {"generated_by": os.path.abspath(__file__), "volumes": len(V), "docs_live_index_nonfront": tot("docs"),
           "marked_rows": tot("marked_rows"), "volume_keys_sum": tot("keys"),
           "per_volume_input_chars": {"sample%d" % n: stats([inp(r, n) for r in V]) for n in SAMPLES},
           "per_volume_input_chars_top%d_sample40" % TOP: stats([r["corr_chars_top%d" % TOP] + r["pocom_chars"] + r["meta_chars"] + r["headers_sample40_chars"] for r in V]),
           "per_volume_components": {f: stats([r[f] for r in V]) for f in ("keys", "corr_chars", "pocom_candidates", "pocom_chars", "headers_sample40_chars", "headers_sample100_chars", "headers_all_chars", "meta_chars", "docs")},
           "chapters": {"all": len(C), "with_marked_rows": sum(1 for c in C if c["marked_rows"]), "ge5_docs": sum(1 for c in C if c["docs"] >= 5),
                        "ge5_docs_with_marked": sum(1 for c in C if c["docs"] >= 5 and c["marked_rows"]),
                        "input_chars_all": tot("chapter_input_chars"), "input_chars_with_marked": tot("chapter_input_chars_marked_only"),
                        "input_chars_ge5_with_marked": tot("chapter_input_chars_ge5_marked"),
                        "docs_per_chapter": stats([c["docs"] for c in C]), "keys_per_chapter": stats([c["keys"] for c in C]),
                        "per_chapter_input_chars_with_marked": stats([c["corr_chars"] + c["pocom_chars"] + c["title_chars"] + c["headers_sample_chars"] for c in C if c["marked_rows"]])},
           "pilot_gold_volumes": {"n": sum(1 for r in V if r["gold_volume"]), **{"input_chars_sample%d" % n: sum(inp(r, n) for r in V if r["gold_volume"]) for n in SAMPLES},
                                  "chapters_with_marked": sum(r["chapters_with_marked_rows"] for r in V if r["gold_volume"]),
                                  "chapter_input_chars_with_marked": sum(r["chapter_input_chars_marked_only"] for r in V if r["gold_volume"])},
           "pilot_identity_volumes": {"n": sum(1 for r in V if r["identity_volume"]), "volumes": sorted(r["v"] for r in V if r["identity_volume"]),
                                      **{"input_chars_sample%d" % n: sum(inp(r, n) for r in V if r["identity_volume"]) for n in SAMPLES},
                                      "chapters_with_marked": sum(r["chapters_with_marked_rows"] for r in V if r["identity_volume"]),
                                      "chapter_input_chars_with_marked": sum(r["chapter_input_chars_marked_only"] for r in V if r["identity_volume"])},
           "per_volume": V}
    json.dump(out, open(os.path.join(HERE, "volume-guides.json"), "w"), indent=1, sort_keys=True)
    print(json.dumps({k: v for k, v in out.items() if k != "per_volume"}, indent=1))


if __name__ == "__main__":
    main()
