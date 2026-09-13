#!/usr/bin/env python3
"""POCOM reach over the whole marked layer and the filtered control's novel surfaces (#234).

Read-only over: the marked layer (~/frus-ner-raw/marked), the filtered NLTagger control
(~/frus-ner-raw-control-filtered/detected), the raw control heads (for an overlap cross-check),
the TEI corpus (document dates only), the manifest (volume coverage windows), and the POCOM
checkout. Writes only pocom.json + a per-volume CSV beside this script.

load_pocom, surname_of, text_of, TITLES, DOCSPLIT, DOCDATE, FROMTO and the Measurement-3 loop
are copied VERBATIM from Planning/early-era-people/m1a_survey.py so the positive control is
the same code, not a re-implementation.
"""
import re, os, csv, json, glob, gzip, collections, sys

HERE     = os.path.dirname(os.path.abspath(__file__))
REPO     = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
VOLUMES  = os.environ.get("VOLUMES_DIR", "/Users/jbotts/Development/frus/volumes")
POCOM    = os.environ.get("POCOM_DIR", "/Users/jbotts/Development/pocom")
MANIFEST = os.environ.get("MANIFEST", REPO + "/FRUSExplorer/Resources/manifest.json")
MARKED   = os.path.expanduser("~/frus-ner-raw")
CONTROL_FILTERED = os.path.expanduser("~/frus-ner-raw-control-filtered")
CONTROL_RAW      = os.path.expanduser("~/frus-ner-raw-control")
M1A_SURVEY = REPO + "/Planning/early-era-people/m1a-survey.json"

sys.path.insert(0, REPO + "/tools/semantic-harvest")
import ner_store  # band_of, volume_layer, layer_head

# ---------------------------------------------------------------- verbatim from m1a_survey.py
PERSNAME   = re.compile(r"<persName[^>]*>(.*?)</persName>", re.S)
FROMTO     = re.compile(r'<persName[^>]*type="(from|to)"[^>]*>(.*?)</persName>', re.S)
DOCSPLIT   = re.compile(r'(?=<div\b[^>]*type="document")')
DOCDATE    = re.compile(r'frus:doc-dateTime-min="(\d{4})')
TITLES     = {"Mr.", "Mrs.", "Sir", "Lord", "Count", "Baron", "Prince", "King",
              "Queen", "Excellency", "Dr.", "Hon."}


def text_of(fragment):
    return " ".join(re.sub(r"<[^>]+>", "", fragment).split())


def surname_of(name):
    toks = [t.strip(".,;:()") for t in name.split()]
    toks = [t for t in toks if t and t not in TITLES and t[0].isupper() and len(t) >= 3]
    return toks[-1] if toks else None


def load_pocom():
    """slug -> surname, and slug -> [(firstYear, lastYear)] over every dated appointment."""
    surnames, spans = {}, collections.defaultdict(list)
    for path in sorted(glob.glob(f"{POCOM}/people/*/*.xml")):
        t = open(path, encoding="utf-8", errors="replace").read()
        sid = re.search(r"<id>([^<]+)</id>", t)
        sur = re.search(r"<surname>([^<]*)</surname>", t)
        if sid and sur and sur.group(1).strip():
            surnames[sid.group(1)] = sur.group(1).strip()
    sources = sorted(glob.glob(f"{POCOM}/missions-*/*.xml")) + \
              sorted(glob.glob(f"{POCOM}/positions-principals/*.xml"))
    for path in sources:
        t = open(path, encoding="utf-8", errors="replace").read()
        for blk in re.findall(r"<(?:chief|principal)>.*?</(?:chief|principal)>", t, re.S):
            pid = re.search(r"<person-id>([^<]+)</person-id>", blk)
            if not pid:
                continue
            years = [int(y) for y in re.findall(r"<date>(\d{4})", blk)]
            if years:
                spans[pid.group(1)].append((min(years), max(years)))
    by_surname = collections.defaultdict(set)
    for slug, sur in surnames.items():
        if slug in spans:
            by_surname[sur].add(slug)
    return surnames, spans, by_surname


def m1a_measurement_3(sample, spans, by_surname):
    """Measurement 3 of m1a_survey.py, verbatim, over the TEI (the positive control)."""
    m3_rows, t_names = [], 0
    t_known = t_unique = 0
    for v in sample:
        t = open(f"{VOLUMES}/{v}.xml", encoding="utf-8", errors="replace").read()
        n = known = unique = 0
        for seg in DOCSPLIT.split(t)[1:]:
            ym = DOCDATE.search(seg[:600])
            if not ym:
                continue
            year = int(ym.group(1))
            for _, raw in FROMTO.findall(seg[:8000]):
                sur = surname_of(text_of(raw))
                if not sur:
                    continue
                n += 1
                cands = by_surname.get(sur)
                if not cands:
                    continue
                known += 1
                live = [s for s in cands if any(a - 1 <= year <= b + 1 for a, b in spans[s])]
                if len(live) == 1:
                    unique += 1
        m3_rows.append((v, ner_store.band_of(v), n, known, unique))
        t_names += n
        t_known += known
        t_unique += unique
    return m3_rows, t_names, t_known, t_unique
# ---------------------------------------------------------------- end verbatim


# K2 surface key: casefold, whitespace-collapse, trailing possessive stripped, leading
# honorific(s) stripped from THIS fixed list (dot-insensitive, matched on the leading token
# repeatedly). Stated in the output.
HONORIFICS = {
    "mr", "mrs", "miss", "ms", "dr", "sir", "lord", "lady", "count", "countess", "baron",
    "baroness", "prince", "princess", "king", "queen", "excellency", "hon", "gen", "general",
    "col", "colonel", "capt", "captain", "maj", "major", "lieut", "lt", "lieutenant", "adm",
    "admiral", "commodore", "rev", "reverend", "don", "dona", "doña", "señor", "senor",
    "señora", "monsieur", "m", "mme", "madame", "mlle", "herr", "earl", "duke", "marquis",
    "viscount", "president", "secretary", "ambassador", "minister", "governor", "judge",
    "prof", "professor", "the", "his", "her", "majesty",
}
POSSESSIVE = re.compile(r"(?:'|’)s$")


def k2_surface(raw):
    """Returns (key, stripped_original_case) — the original-case form is what surname_of reads."""
    s = " ".join(raw.split())
    s = POSSESSIVE.sub("", s).strip()
    toks = s.split()
    while toks and toks[0].strip(".,").casefold() in HONORIFICS:
        toks = toks[1:]
    s = " ".join(toks)
    return s.casefold(), s


def year_of(iso):
    return int(iso[:4])


def load_windows():
    man = json.load(open(MANIFEST))
    vols = man["volumes"] if isinstance(man, dict) else man
    return {v["volumeId"]: (year_of(v["dateRange"]["earliest"]), year_of(v["dateRange"]["latest"]))
            for v in vols}


def tei_doc_years(volume_id):
    """{doc xml:id: doc-dateTime-min year} for the documents that carry one (m1a's own reading)."""
    t = open(f"{VOLUMES}/{volume_id}.xml", encoding="utf-8", errors="replace").read()
    out = {}
    for seg in DOCSPLIT.split(t)[1:]:
        head = seg[:600]
        ym = DOCDATE.search(head)
        did = re.search(r'xml:id="([^"]+)"', head)
        if ym and did:
            out[did.group(1)] = int(ym.group(1))
    return out


def live_count(cands, spans, lo, hi):
    """Officeholders among `cands` with any appointment overlapping [lo-1, hi+1] (m1a's ±1)."""
    return sum(1 for s in cands if any(a - 1 <= hi and lo <= b + 1 for a, b in spans[s]))


class Tally:
    """Counts for one population at four grains."""

    def __init__(self):
        self.mention = collections.Counter()         # n, known, unique_win, dated, known_dated, unique_doc
        self.doc_key = {}                            # (doc, key) -> (known, unique_win)
        self.vol_key = {}                            # (vol, key) -> (known, unique_win)
        self.key_vols = collections.defaultdict(set)  # key -> {vol}
        self.key_known = {}                          # key -> bool
        self.key_sur_cf = {}                         # key -> casefolded surname or None
        self.known_surnames = collections.Counter()  # surname -> mentions (known, mention grain)
        self.unique_surnames = collections.Counter() # surname -> mentions unique by document year

    def add(self, vol, doc, raw, window, doc_year, spans, by_surname, by_surname_cf):
        lo, hi = window
        self.mention["n"] += 1
        # --- mention grain, m1a's exact-case surname rule
        sur = surname_of(text_of(raw))
        if sur:
            self.mention["with_surname"] += 1
        cands = by_surname.get(sur) if sur else None
        single_token = len(text_of(raw).split()) == 1
        win_live = doc_live = None
        if cands:
            self.mention["known"] += 1
            self.known_surnames[sur] += 1
            if single_token:
                self.mention["known_single_token_surface"] += 1
            win_live = live_count(cands, spans, lo, hi)
            if win_live == 1:
                self.mention["unique_win"] += 1
        if doc_year is not None:
            self.mention["dated"] += 1
            if cands:
                self.mention["known_dated"] += 1
                doc_live = live_count(cands, spans, doc_year, doc_year)
                if doc_live == 0:
                    self.mention["known_but_nobody_in_office_that_year"] += 1
                elif doc_live == 1:
                    self.mention["unique_doc"] += 1
                    self.unique_surnames[sur] += 1
                    if single_token:
                        self.mention["unique_doc_single_token_surface"] += 1
                else:
                    self.mention["known_several_in_office_that_year"] += 1
                if doc_live == 1 and win_live != 1:
                    self.mention["proxy_loses_unique"] += 1
                if doc_live != 1 and win_live == 1:
                    self.mention["proxy_gains_unique"] += 1
        # --- K2 surface grains (casefolded surname lookup)
        key, stripped = k2_surface(text_of(raw))
        if not key:
            self.mention["k2_empty"] += 1
            return
        ksur = surname_of(stripped)
        kcands = by_surname_cf.get(ksur.casefold()) if ksur else None
        known = bool(kcands)
        uniq = known and live_count(kcands, spans, lo, hi) == 1
        self.doc_key.setdefault((vol, doc, key), (known, uniq))
        self.vol_key.setdefault((vol, key), (known, uniq))
        self.key_vols[key].add(vol)
        self.key_known[key] = known
        self.key_sur_cf[key] = ksur.casefold() if ksur else None

    def summary(self, windows, spans, by_surname_cf):
        m = self.mention
        n = m["n"]
        out = {
            "mention": {
                "n": n, "surname_known": m["known"], "unique_by_volume_window": m["unique_win"],
                "share_surname_known": round(m["known"] / n, 4) if n else None,
                "share_unique_by_volume_window": round(m["unique_win"] / n, 4) if n else None,
                "with_tei_document_year": m["dated"],
                "surname_known_among_dated": m["known_dated"],
                "unique_by_document_year_among_dated": m["unique_doc"],
                "share_unique_by_document_year_among_dated": round(m["unique_doc"] / m["dated"], 4) if m["dated"] else None,
                "share_surname_known_among_dated": round(m["known_dated"] / m["dated"], 4) if m["dated"] else None,
                "k2_key_empty_after_stripping": m["k2_empty"],
                "with_surname_m1a_denominator": m["with_surname"],
                "share_surname_known_over_with_surname": round(m["known"] / m["with_surname"], 4) if m["with_surname"] else None,
                "share_unique_by_document_year_over_with_surname": round(m["unique_doc"] / m["with_surname"], 4) if m["with_surname"] else None,
                "top_15_known_surnames": self.known_surnames.most_common(15),
                "top_15_unique_by_document_year_surnames": self.unique_surnames.most_common(15),
                "unique_by_document_year_share_in_top_10_surnames": round(sum(c for _, c in self.unique_surnames.most_common(10)) / m["unique_doc"], 4) if m["unique_doc"] else None,
                "distinct_surnames_among_unique_by_document_year": len(self.unique_surnames),
                "known_but_nobody_in_office_that_year": m["known_but_nobody_in_office_that_year"],
                "known_several_in_office_that_year": m["known_several_in_office_that_year"],
                "known_single_token_surface": m["known_single_token_surface"],
                "unique_doc_single_token_surface": m["unique_doc_single_token_surface"],
                "volume_window_proxy_vs_document_year": {
                    "proxy_loses_unique (doc-year unique, window not)": m["proxy_loses_unique"],
                    "proxy_gains_unique (window unique, doc-year not)": m["proxy_gains_unique"]},
            }
        }
        for label, table in (("document_x_surface", self.doc_key), ("volume_x_surface", self.vol_key)):
            tot = len(table)
            kn = sum(1 for k, u in table.values() if k)
            un = sum(1 for k, u in table.values() if u)
            out[label] = {"n": tot, "surname_known": kn, "unique_by_volume_window": un,
                          "share_surname_known": round(kn / tot, 4) if tot else None,
                          "share_unique_by_volume_window": round(un / tot, 4) if tot else None}
        # distinct surface across the population; window = union of its volumes' windows
        tot = len(self.key_vols)
        kn = un = 0
        for key, vols in self.key_vols.items():
            if not self.key_known[key]:
                continue
            kn += 1
            lo = min(windows[v][0] for v in vols)
            hi = max(windows[v][1] for v in vols)
            if live_count(by_surname_cf[self.key_sur_cf[key]], spans, lo, hi) == 1:
                un += 1
        out["distinct_surface"] = {"n": tot, "surname_known": kn, "unique_by_union_window": un,
                                   "share_surname_known": round(kn / tot, 4) if tot else None,
                                   "share_unique_by_union_window": round(un / tot, 4) if tot else None}
        return out


def overlaps(s, e, marks):
    return any(s < me and e > ms for ms, me in marks)


def main():
    surnames, spans, by_surname = load_pocom()
    by_surname_cf = collections.defaultdict(set)
    for sur, slugs in by_surname.items():
        by_surname_cf[sur.casefold()] |= slugs
    windows = load_windows()
    scope = ner_store.scope_volumes(MARKED)
    m1a = json.load(open(M1A_SURVEY))
    sample = m1a["sample"]

    # ---- positive control: m1a Measurement 3 verbatim over the TEI
    m3_rows, t_n, t_k, t_u = m1a_measurement_3(sample, spans, by_surname)
    control = {
        "recorded_in_m1a_survey_json": {
            "pooled_names": m1a["measurement_3_pocom_constraint"]["pooled_names"],
            "pooled_surname_known": m1a["measurement_3_pocom_constraint"]["pooled_surname_known"],
            "pooled_uniquely_resolved": m1a["measurement_3_pocom_constraint"]["pooled_uniquely_resolved"],
        },
        "rerun_verbatim_today": {"pooled_names": t_n, "pooled_surname_known": t_k,
                                 "pooled_uniquely_resolved": t_u,
                                 "share_surname_known": round(t_k / t_n, 4),
                                 "share_uniquely_resolved": round(t_u / t_n, 4),
                                 "per_volume": [dict(zip(["volume", "band", "from_to_names", "surname_known", "uniquely_resolved"], r)) for r in m3_rows]},
    }
    control["reproduced_exactly"] = (
        control["recorded_in_m1a_survey_json"]["pooled_names"] == t_n and
        control["recorded_in_m1a_survey_json"]["pooled_surname_known"] == t_k and
        control["recorded_in_m1a_survey_json"]["pooled_uniquely_resolved"] == t_u)
    print("positive control (TEI, verbatim):", control["rerun_verbatim_today"]["pooled_names"], t_k, t_u,
          "exact" if control["reproduced_exactly"] else "DIFFERS", file=sys.stderr)

    # ---- whole scope
    pocom_stats = {"people_files": len(glob.glob(f"{POCOM}/people/*/*.xml")),
                   "people_with_surname": len(surnames),
                   "people_with_dated_appointment": len(spans),
                   "distinct_surnames_with_dated_appointment": len(by_surname),
                   "distinct_surnames_casefolded": len(by_surname_cf)}

    by_band = collections.defaultdict(lambda: {
        "marked_fromto": Tally(), "marked_all": Tally(), "novel_control": Tally(), "union": Tally()})
    whole = {"marked_fromto": Tally(), "marked_all": Tally(), "novel_control": Tally(), "union": Tally()}
    sample_store = {"marked_fromto": Tally()}  # the 12 m1a volumes, from the STORE
    per_volume = []
    overlap_check = {"volumes_compared": 0, "volumes_matching_raw_head_novel": 0, "mismatches": []}
    marked_type_counts = collections.Counter()
    control_missing = []
    docs_without_tei_year = 0
    docs_total = 0

    for i, vol in enumerate(scope):
        band = ner_store.band_of(vol)
        window = windows[vol]
        doc_years = tei_doc_years(vol)
        marked = ner_store.volume_layer(MARKED, "marked", vol)
        marks_by_doc = collections.defaultdict(list)
        for r in marked:
            marks_by_doc[r["d"]].append((r["s"], r["e"]))
            marked_type_counts[r["t"] or "untyped"] += 1
        # marked layer
        vt = {"marked_fromto": Tally(), "marked_all": Tally(), "novel_control": Tally()}
        for r in marked:
            dy = doc_years.get(r["d"])
            args = (vol, r["d"], r["n"], window, dy, spans, by_surname, by_surname_cf)
            vt["marked_all"].add(*args)
            for T in (whole["marked_all"], by_band[band]["marked_all"], whole["union"], by_band[band]["union"]):
                T.add(*args)
            if r["t"] in ("from", "to"):
                vt["marked_fromto"].add(*args)
                for T in (whole["marked_fromto"], by_band[band]["marked_fromto"]):
                    T.add(*args)
                if vol in sample:
                    sample_store["marked_fromto"].add(*args)
        # filtered control, novel rows only
        det = ner_store.volume_layer(CONTROL_FILTERED, "detected", vol)
        if not det and ner_store.layer_head(CONTROL_FILTERED, "detected", vol) is None:
            control_missing.append(vol)
        novel = 0
        for r in det:
            if overlaps(r["s"], r["e"], marks_by_doc.get(r["d"], ())):
                continue
            novel += 1
            dy = doc_years.get(r["d"])
            args = (vol, r["d"], r["n"], window, dy, spans, by_surname, by_surname_cf)
            vt["novel_control"].add(*args)
            for T in (whole["novel_control"], by_band[band]["novel_control"], whole["union"], by_band[band]["union"]):
                T.add(*args)
        # cross-check my overlap rule against the RAW control head's `novel`
        raw_head = ner_store.layer_head(CONTROL_RAW, "detected", vol)
        raw_rows = ner_store.volume_layer(CONTROL_RAW, "detected", vol)
        if raw_head and raw_rows:
            my_novel_raw = sum(1 for r in raw_rows if not overlaps(r["s"], r["e"], marks_by_doc.get(r["d"], ())))
            overlap_check["volumes_compared"] += 1
            if my_novel_raw == raw_head.get("novel"):
                overlap_check["volumes_matching_raw_head_novel"] += 1
            else:
                overlap_check["mismatches"].append({"volume": vol, "mine": my_novel_raw, "head": raw_head.get("novel")})
        head = ner_store.layer_head(MARKED, "marked", vol) or {}
        docs_total += head.get("docs", 0)

        row = {"volume": vol, "band": band, "window_lo": window[0], "window_hi": window[1],
               "docs": head.get("docs"), "docs_with_tei_year": len(doc_years),
               "marked_all": len(marked), "marked_fromto": vt["marked_fromto"].mention["n"],
               "fromto_known": vt["marked_fromto"].mention["known"],
               "fromto_unique_win": vt["marked_fromto"].mention["unique_win"],
               "fromto_dated": vt["marked_fromto"].mention["dated"],
               "fromto_unique_docyear": vt["marked_fromto"].mention["unique_doc"],
               "all_known": vt["marked_all"].mention["known"], "all_unique_win": vt["marked_all"].mention["unique_win"],
               "control_filtered_rows": len(det), "control_novel": novel,
               "novel_known": vt["novel_control"].mention["known"], "novel_unique_win": vt["novel_control"].mention["unique_win"]}
        per_volume.append(row)
        if (i + 1) % 25 == 0:
            print("[%d/%d] %s" % (i + 1, len(scope), vol), file=sys.stderr)

    def summarize(tallies):
        return {name: t.summary(windows, spans, by_surname_cf) for name, t in tallies.items()}

    # nearest reproducible comparison for the 12 sample volumes, from the store
    ss = sample_store["marked_fromto"].summary(windows, spans, by_surname_cf)["mention"]
    control["nearest_store_comparison_same_12_volumes"] = {
        "population": "marked-layer rows with t in {from,to} over the 12 m1a volumes (ALL such rows, "
                      "not only those in dated documents, and with no 8,000-char cut per document)",
        "mention_n": ss["n"], "surname_known": ss["surname_known"],
        "share_surname_known": ss["share_surname_known"],
        "unique_by_volume_window": ss["unique_by_volume_window"],
        "share_unique_by_volume_window": ss["share_unique_by_volume_window"],
        "with_tei_document_year": ss["with_tei_document_year"],
        "with_surname_m1a_denominator": ss["with_surname_m1a_denominator"],
        "share_surname_known_over_with_surname": ss["share_surname_known_over_with_surname"],
        "share_unique_by_document_year_over_with_surname": ss["share_unique_by_document_year_over_with_surname"],
        "unique_by_document_year_among_dated": ss["unique_by_document_year_among_dated"],
        "share_unique_by_document_year_among_dated": ss["share_unique_by_document_year_among_dated"],
        "share_surname_known_among_dated": ss["share_surname_known_among_dated"],
    }

    report = {
        "generated_by": os.path.abspath(__file__),
        "inputs": {"marked_store": MARKED, "filtered_control_store": CONTROL_FILTERED,
                   "raw_control_store": CONTROL_RAW, "tei_volumes_dir": VOLUMES,
                   "manifest": MANIFEST, "pocom_dir": POCOM, "m1a_survey": M1A_SURVEY},
        "scope": {"volumes": len(scope), "docs_per_marked_heads": docs_total,
                  "marked_rows_by_type": dict(marked_type_counts),
                  "filtered_control_volumes_missing": control_missing},
        "pocom": pocom_stats,
        "definitions": {
            "surname_known (mention grain)": "m1a_survey.surname_of(text_of(surface)) is a key of by_surname "
                                              "(exact case; only officeholders with a dated appointment).",
            "unique_by_volume_window": "exactly one POCOM officeholder with that surname has an appointment "
                                       "span overlapping [window_lo-1, window_hi+1], where the window is the "
                                       "manifest dateRange years of the VOLUME. PROXY: the store carries no "
                                       "document date. Bias: a multi-year window admits more officeholders than "
                                       "a document's own year, so this share is a LOWER bound on the per-document "
                                       "unique share m1a measured; the per-document figure is reported beside it "
                                       "wherever the TEI carries frus:doc-dateTime-min.",
            "unique_by_document_year_among_dated": "m1a's rule exactly: the document's TEI "
                                                   "frus:doc-dateTime-min year, ±1.",
            "K2 surface key": "casefold, whitespace-collapse, trailing 's / ’s stripped, leading honorific "
                              "token(s) stripped repeatedly from the fixed list `honorifics`; the surname is "
                              "surname_of() over the stripped original-case string, compared casefolded.",
            "document_x_surface": "(volume, document, K2 key) distinct — the person_mentions grain "
                                  "(one row per unique person per document).",
            "volume_x_surface": "(volume, K2 key) distinct; window = the volume's.",
            "distinct_surface": "K2 key distinct over the population; window = union of the windows of the "
                                "volumes it appears in.",
            "novel_control": "filtered-control detections whose span does not overlap (s < me and e > ms) "
                             "any marked span in the same document; overlap computed here from spans, "
                             "cross-checked against the raw control heads' `novel`.",
            "union": "marked (all types) + novel filtered control.",
            "honorifics": sorted(HONORIFICS),
            "bands": "ner_store.band_of — 1861-1899 / 1900-1929 / 1930-1945 / 1946-",
        },
        "positive_control": control,
        "overlap_cross_check_vs_raw_control_heads": overlap_check,
        "whole_scope": summarize(whole),
        "by_band": {b: summarize(t) for b, t in sorted(by_band.items())},
    }
    with open(os.path.join(HERE, "pocom.json"), "w") as f:
        json.dump(report, f, indent=1, sort_keys=True)
    with open(os.path.join(HERE, "per-volume.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(per_volume[0].keys()))
        w.writeheader()
        w.writerows(per_volume)
    print(json.dumps({"whole_scope": report["whole_scope"], "positive_control": control}, indent=1, sort_keys=True))


if __name__ == "__main__":
    main()
