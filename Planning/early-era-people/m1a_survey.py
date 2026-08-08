#!/usr/bin/env python3
"""M1a survey for the early-era people program (#234).

Measures the three unknowns that gate the program, and emits the eval-set candidate
sample the owner must hand-key. Read-only over the TEI corpus and the POCOM checkout;
writes only into this directory.

    python3 Planning/early-era-people/m1a_survey.py

Env: VOLUMES_DIR (default /Users/jbotts/Development/frus/volumes),
     POCOM_DIR   (default /Users/jbotts/Development/pocom),
     MANIFEST    (default FRUSExplorer/Resources/manifest.json),
     OUT_DIR     (default Planning/early-era-people)

Determinism: volumes are processed in manifest order; every sample uses a fixed seed.
"""
import re, os, csv, json, glob, random, collections

VOLUMES = os.environ.get("VOLUMES_DIR", "/Users/jbotts/Development/frus/volumes")
POCOM   = os.environ.get("POCOM_DIR", "/Users/jbotts/Development/pocom")
MANIFEST= os.environ.get("MANIFEST", "FRUSExplorer/Resources/manifest.json")
OUT     = os.environ.get("OUT_DIR", "Planning/early-era-people")
SEED    = 234

PERSNAME   = re.compile(r"<persName[^>]*>(.*?)</persName>", re.S)
PERSNAME_D = re.compile(r'<persName[^>]*xml:id=')
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


def year_band(volume_id):
    m = re.search(r"frus(\d{4})", volume_id)
    if not m:
        return None
    y = int(m.group(1))
    for lo, hi, label in ((1861, 1899, "1861-1899"), (1900, 1929, "1900-1929"),
                          (1930, 1945, "1930-1945"), (1946, 2000, "1946-")):
        if lo <= y <= hi:
            return label
    return None


def load_volumes():
    man = json.load(open(MANIFEST))
    return [v["volumeId"] for v in (man["volumes"] if isinstance(man, dict) else man)]


def has_editor_list(text):
    """A volume has an editor person list iff it DEFINES persName ids.

    Keyed on `xml:id`, not on the app's `<div subtype="index" xml:id="persons">` rule:
    frus1873p1v1/p1v2 carry a real list under `xml:id="correspondents"` that the app's
    parser does not recognise, and this survey must count what the TEI has, not what the
    app currently reads.
    """
    return PERSNAME_D.search(text) is not None


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


def main():
    os.makedirs(OUT, exist_ok=True)
    volumes = load_volumes()
    nolist, unread_list = [], []
    for v in volumes:
        p = f"{VOLUMES}/{v}.xml"
        if not os.path.exists(p):
            continue
        t = open(p, encoding="utf-8", errors="replace").read()
        if not has_editor_list(t):
            nolist.append(v)
        elif PERSNAME_D.search(t) and '"persons"' not in t and "listPerson" not in t:
            unread_list.append(v)

    random.seed(SEED)
    bands = collections.defaultdict(list)
    for v in nolist:
        b = year_band(v)
        if b:
            bands[b].append(v)
    sample = [v for b in sorted(bands) for v in random.sample(sorted(bands[b]), min(3, len(bands[b])))]

    # ---- Measurement 1: what share of person mentions carry <persName>? ----
    m1_rows, tot_m, tot_u = [], 0, 0
    for v in sample:
        t = open(f"{VOLUMES}/{v}.xml", encoding="utf-8", errors="replace").read()
        marked = [text_of(m.group(1)) for m in PERSNAME.finditer(t)]
        counts = collections.Counter(s for s in (surname_of(n) for n in marked if n) if s)
        top = [s for s, _ in counts.most_common(25)]
        body = re.sub(r"<[^>]+>", " ", PERSNAME.sub(" ", t))
        marked_hits = sum(counts[s] for s in top)
        unmarked_hits = sum(len(re.findall(r"\b" + re.escape(s) + r"\b", body)) for s in top)
        share = marked_hits / (marked_hits + unmarked_hits) if (marked_hits + unmarked_hits) else 0.0
        m1_rows.append((v, year_band(v), marked_hits, unmarked_hits, round(share, 4)))
        tot_m += marked_hits
        tot_u += unmarked_hits

    # ---- Measurement 3: how far does POCOM constrain a from/to name? ----
    _, spans, by_surname = load_pocom()
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
        m3_rows.append((v, year_band(v), n, known, unique))
        t_names += n
        t_known += known
        t_unique += unique

    # ---- Eval-set candidate sample (OWNER hand-keys the identity column) ----
    random.seed(SEED)
    eval_rows = []
    for v in sample:
        t = open(f"{VOLUMES}/{v}.xml", encoding="utf-8", errors="replace").read()
        found = []
        for seg in DOCSPLIT.split(t)[1:]:
            ym = DOCDATE.search(seg[:600])
            did = re.search(r'xml:id="([^"]+)"', seg[:600])
            if not (ym and did):
                continue
            for role, raw in FROMTO.findall(seg[:8000]):
                nm = text_of(raw)
                if nm:
                    found.append((v, did.group(1), ym.group(1), role, nm, surname_of(nm) or ""))
        eval_rows += random.sample(found, min(25, len(found)))

    with open(f"{OUT}/m1a-eval-candidates.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["volume", "document", "year", "role", "name_as_printed", "surname",
                    "TRUE_IDENTITY_pocom_slug_or_name", "notes"])
        for r in sorted(eval_rows):
            w.writerow(list(r) + ["", ""])

    report = {
        "generated_by": "Planning/early-era-people/m1a_survey.py",
        "seed": SEED,
        "volumes_total": len(volumes),
        "volumes_without_editor_list": len(nolist),
        "volumes_with_list_the_app_does_not_read": unread_list,
        "sample": sample,
        "measurement_1_markup_share": {
            "per_volume": [dict(zip(["volume", "band", "marked", "unmarked", "share"], r)) for r in m1_rows],
            "pooled_marked": tot_m, "pooled_unmarked": tot_u,
            "pooled_share": round(tot_m / (tot_m + tot_u), 4) if (tot_m + tot_u) else None,
        },
        "measurement_3_pocom_constraint": {
            "per_volume": [dict(zip(["volume", "band", "from_to_names", "surname_known", "uniquely_resolved"], r)) for r in m3_rows],
            "pooled_names": t_names, "pooled_surname_known": t_known,
            "pooled_uniquely_resolved": t_unique,
            "share_surname_known": round(t_known / t_names, 4) if t_names else None,
            "share_uniquely_resolved": round(t_unique / t_names, 4) if t_names else None,
        },
        "eval_candidates_written": len(eval_rows),
    }
    with open(f"{OUT}/m1a-survey.json", "w") as f:
        json.dump(report, f, indent=2, sort_keys=True)
    print(json.dumps({k: v for k, v in report.items() if k != "sample"}, indent=2, sort_keys=True)[:1400])


if __name__ == "__main__":
    main()
