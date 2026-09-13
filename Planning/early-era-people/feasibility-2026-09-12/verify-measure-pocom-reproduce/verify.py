#!/usr/bin/env python3
"""Independent reproduction of measure-pocom's load-bearing figures. Read-only. Stdlib only.
POCOM via ElementTree (not regex); TEI doc years off the <div type="document"> opening tag;
novel/overlap via a sorted-spans bisect; own tallies. Writes verify.json beside this file."""
import os, re, sys, json, gzip, glob, csv, bisect, collections
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
VOL = "/Users/jbotts/Development/frus/volumes"
POCOM = "/Users/jbotts/Development/pocom"
MARKED = os.path.expanduser("~/frus-ner-raw")
CF = os.path.expanduser("~/frus-ner-raw-control-filtered")
CR = os.path.expanduser("~/frus-ner-raw-control")
AUTHOR = json.load(open("/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/measure-pocom/pocom.json"))
HON = set(AUTHOR["definitions"]["honorifics"])

def band_of(v):
    y = int(re.search(r"frus(\d{4})", v).group(1))
    return "1861-1899" if y <= 1899 else "1900-1929" if y <= 1929 else "1930-1945" if y <= 1945 else "1946-"

def rows(path):
    if not os.path.exists(path):
        path = path + ".gz" if not path.endswith(".gz") else path
    op = gzip.open if path.endswith(".gz") else open
    with op(path, "rt", encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]

def layer(store, layer_name, v):
    for suf in (".jsonl", ".jsonl.gz"):
        p = os.path.join(store, layer_name, v + suf)
        if os.path.exists(p):
            return rows(p)
    return None

# ---------------- POCOM via ElementTree
def load_pocom_et():
    sur = {}
    for p in glob.glob(f"{POCOM}/people/*/*.xml"):
        root = ET.parse(p).getroot()
        pid = root.findtext("id")
        s = root.findtext("persName/surname")
        if pid and s and s.strip():
            sur[pid] = s.strip()
    spans = collections.defaultdict(list)
    files = glob.glob(f"{POCOM}/missions-countries/*.xml") + glob.glob(f"{POCOM}/missions-orgs/*.xml") + glob.glob(f"{POCOM}/positions-principals/*.xml")
    for p in files:
        root = ET.parse(p).getroot()
        for blk in root.iter("chief"):
            _add(blk, spans)
        for blk in root.iter("principal"):
            _add(blk, spans)
    by = collections.defaultdict(set)
    for pid, s in sur.items():
        if pid in spans:
            by[s].add(pid)
    return sur, spans, by

def _add(blk, spans):
    pid = blk.findtext("person-id")
    if not pid:
        return
    ys = []
    for d in blk.iter("date"):
        if d.text and re.match(r"\d{4}", d.text.strip()):
            ys.append(int(d.text.strip()[:4]))
    if ys:
        spans[pid].append((min(ys), max(ys)))

# ---------------- m1a surname rule (re-implemented from its description)
TITLES = {"Mr.", "Mrs.", "Sir", "Lord", "Count", "Baron", "Prince", "King", "Queen", "Excellency", "Dr.", "Hon."}
def surname(name):
    out = None
    for tok in name.split():
        t = tok.strip(".,;:()")
        if not t or t in TITLES or not t[0].isupper() or len(t) < 3:
            continue
        out = t
    return out

def in_year(cands, spans, y):
    return [c for c in cands if any(a - 1 <= y <= b + 1 for a, b in spans[c])]
def in_window(cands, spans, lo, hi):
    return [c for c in cands if any(not (b + 1 < lo or a - 1 > hi) for a, b in spans[c])]

POSS = re.compile(r"(?:'|’)s$")
def k2(surface):
    s = " ".join(surface.split())
    s = POSS.sub("", s).strip()
    toks = s.split()
    i = 0
    while i < len(toks) and toks[i].strip(".,").casefold() in HON:
        i += 1
    s = " ".join(toks[i:])
    return s.casefold(), s

# ---------------- TEI doc years off the opening tag
DIVTAG = re.compile(r'<div\b[^>]*?type="document"[^>]*?>')
XMLID = re.compile(r'xml:id="([^"]+)"')
DMIN = re.compile(r'frus:doc-dateTime-min="(\d{4})')
def doc_years(v):
    t = open(f"{VOL}/{v}.xml", encoding="utf-8", errors="replace").read()
    out, n = {}, 0
    for m in DIVTAG.finditer(t):
        n += 1
        g = m.group(0)
        i, y = XMLID.search(g), DMIN.search(g)
        if i and y:
            out[i.group(1)] = int(y.group(1))
    return out, n, t

class Pop:
    def __init__(s):
        s.c = collections.Counter(); s.dk = {}; s.vk = {}; s.kv = collections.defaultdict(set); s.kk = {}; s.ksur = {}
        s.known_sur = collections.Counter(); s.uniq_sur = collections.Counter()
    def add(s, v, d, n, win, y, spans, by, bycf):
        s.c["n"] += 1
        sur = surname(n)
        if sur: s.c["ws"] += 1
        cands = by.get(sur) if sur else None
        one_tok = len(n.split()) == 1
        wl = None
        if cands:
            s.c["known"] += 1; s.known_sur[sur] += 1
            if one_tok: s.c["known_1tok"] += 1
            wl = len(in_window(cands, spans, *win))
            if wl == 1: s.c["uniq_win"] += 1
        if y is not None:
            s.c["dated"] += 1
            if cands:
                dl = len(in_year(cands, spans, y))
                if dl == 0: s.c["nobody"] += 1
                elif dl == 1:
                    s.c["uniq_doc"] += 1; s.uniq_sur[sur] += 1
                else: s.c["several"] += 1
                if dl == 1 and wl != 1: s.c["proxy_loses"] += 1
                if dl != 1 and wl == 1: s.c["proxy_gains"] += 1
        key, stripped = k2(n)
        if not key:
            s.c["k2_empty"] += 1; return
        ks = surname(stripped)
        kc = bycf.get(ks.casefold()) if ks else None
        kn = bool(kc); un = kn and len(in_window(kc, spans, *win)) == 1
        s.dk.setdefault((v, d, key), (kn, un)); s.vk.setdefault((v, key), (kn, un))
        s.kv[key].add(v); s.kk[key] = kn; s.ksur[key] = ks.casefold() if ks else None
    def out(s, windows, spans, bycf):
        c = s.c; ws = c["ws"]
        o = {"n": c["n"], "with_surname": ws, "known": c["known"], "uniq_doc": c["uniq_doc"], "uniq_win": c["uniq_win"],
             "dated": c["dated"], "nobody": c["nobody"], "several": c["several"], "known_1tok": c["known_1tok"], "k2_empty": c["k2_empty"],
             "proxy_loses": c["proxy_loses"], "proxy_gains": c["proxy_gains"],
             "share_known": round(c["known"] / ws, 4) if ws else None, "share_uniq_doc": round(c["uniq_doc"] / ws, 4) if ws else None,
             "share_uniq_win": round(c["uniq_win"] / c["n"], 4) if c["n"] else None,
             "top10_known": s.known_sur.most_common(10), "top5_uniq": s.uniq_sur.most_common(5),
             "distinct_uniq_sur": len(s.uniq_sur),
             "top10_share_of_uniq": round(sum(x for _, x in s.uniq_sur.most_common(10)) / c["uniq_doc"], 4) if c["uniq_doc"] else None}
        for lab, tb in (("doc_x_surface", s.dk), ("vol_x_surface", s.vk)):
            o[lab] = {"n": len(tb), "known": sum(1 for k, u in tb.values() if k), "uniq_win": sum(1 for k, u in tb.values() if u)}
        kn = un = 0
        for key, vols in s.kv.items():
            if not s.kk[key]: continue
            kn += 1
            lo = min(windows[v][0] for v in vols); hi = max(windows[v][1] for v in vols)
            if len(in_window(bycf[s.ksur[key]], spans, lo, hi)) == 1: un += 1
        o["distinct_surface"] = {"n": len(s.kv), "known": kn, "uniq_union_win": un}
        return o

def main():
    sur, spans, by = load_pocom_et()
    bycf = collections.defaultdict(set)
    for s_, ids in by.items(): bycf[s_.casefold()] |= ids
    res = {"pocom_et": {"people": len(glob.glob(f"{POCOM}/people/*/*.xml")), "with_surname": len(sur), "dated": len(spans), "surnames": len(by), "surnames_cf": len(bycf)}}
    sew = {p: spans[p] for p in by.get("Seward", ())}
    res["sewards"] = {p: sorted(v) for p, v in sew.items()}
    res["sewards_in_office_1865"] = in_year(by["Seward"], spans, 1865)
    # cross-check ET loader vs author's regex loader
    sys.path.insert(0, os.path.dirname(AUTHOR["generated_by"]))
    import importlib.util
    spec = importlib.util.spec_from_file_location("mp", AUTHOR["generated_by"]); mp = importlib.util.module_from_spec(spec); spec.loader.exec_module(mp)
    asur, aspans, aby = mp.load_pocom()
    res["loader_parity"] = {"surnames_equal": asur == sur, "spans_equal": {k: sorted(v) for k, v in aspans.items()} == {k: sorted(v) for k, v in spans.items()}, "by_surname_equal": aby == by}

    man = json.load(open(f"{REPO}/FRUSExplorer/Resources/manifest.json"))
    windows = {v["volumeId"]: (int(v["dateRange"]["earliest"][:4]), int(v["dateRange"]["latest"][:4])) for v in (man["volumes"] if isinstance(man, dict) else man)}
    scope = json.load(open(f"{MARKED}/scope.json"))["volumes"]
    sample = json.load(open(f"{REPO}/Planning/early-era-people/m1a-survey.json"))["sample"]

    whole = {k: Pop() for k in ("fromto", "all", "novel", "union")}
    band = collections.defaultdict(lambda: {k: Pop() for k in ("fromto", "all", "novel", "union")})
    samp = Pop()
    types = collections.Counter(); docs_head = 0; docs_tei = 0; docs_tei_dated = 0; divtags = 0
    marked_undated = 0; cf_total = 0; novel_total = 0; overlap_total = 0
    ovchk = {"compared": 0, "match": 0, "mismatch": []}
    tei12 = {"full_seg_ws_dated": 0, "first8000_ws_dated": 0, "fromto_anywhere": 0, "store_fromto": 0, "store_fromto_ws": 0, "store_undated": 0}
    FROMTO = re.compile(r'<persName[^>]*type="(from|to)"[^>]*>(.*?)</persName>', re.S)
    def text_of(f): return " ".join(re.sub(r"<[^>]+>", "", f).split())
    for i, v in enumerate(scope):
        b = band_of(v); win = windows[v]
        dy, ndiv, tei = doc_years(v)
        divtags += ndiv; docs_tei_dated += len(dy)
        head = json.load(open(f"{MARKED}/marked/{v}.head.json")); docs_head += head["docs"]
        marked = layer(MARKED, "marked", v)
        spans_by_doc = collections.defaultdict(list)
        for r in marked:
            types[r["t"] or "untyped"] += 1
            spans_by_doc[r["d"]].append((r["s"], r["e"]))
            y = dy.get(r["d"])
            if y is None: marked_undated += 1
            a = (v, r["d"], r["n"], win, y, spans, by, bycf)
            whole["all"].add(*a); band[b]["all"].add(*a); whole["union"].add(*a); band[b]["union"].add(*a)
            if r["t"] in ("from", "to"):
                whole["fromto"].add(*a); band[b]["fromto"].add(*a)
                if v in sample:
                    samp.add(*a); tei12["store_fromto"] += 1
                    if surname(r["n"]): tei12["store_fromto_ws"] += 1
                    if y is None: tei12["store_undated"] += 1
        # sorted spans per doc for bisect overlap
        idx = {}
        for d, sp in spans_by_doc.items():
            sp.sort(); starts = [s for s, e in sp]
            # prefix max of ends for O(log n) overlap test
            pm = []; m = -1
            for s, e in sp:
                m = max(m, e); pm.append(m)
            idx[d] = (starts, pm)
        def novel(r):
            it = idx.get(r["d"])
            if not it: return True
            starts, pm = it
            j = bisect.bisect_left(starts, r["e"])  # spans with start < e
            return not (j > 0 and pm[j - 1] > r["s"])
        det = layer(CF, "detected", v); cf_total += len(det)
        for r in det:
            if not novel(r): overlap_total += 1; continue
            novel_total += 1
            a = (v, r["d"], r["n"], win, dy.get(r["d"]), spans, by, bycf)
            whole["novel"].add(*a); band[b]["novel"].add(*a); whole["union"].add(*a); band[b]["union"].add(*a)
        raw = layer(CR, "detected", v); rh = json.load(open(f"{CR}/detected/{v}.head.json"))
        mine = sum(1 for r in raw if novel(r)); ovchk["compared"] += 1
        if mine == rh["novel"]: ovchk["match"] += 1
        else: ovchk["mismatch"].append((v, mine, rh["novel"]))
        if v in sample:
            tei12["fromto_anywhere"] += len(FROMTO.findall(tei))
            starts = [m.start() for m in DIVTAG.finditer(tei)] + [len(tei)]
            for k in range(len(starts) - 1):
                seg = tei[starts[k]:starts[k + 1]]
                g = DIVTAG.match(seg).group(0)
                if not DMIN.search(g): continue
                for _, raw_ in FROMTO.findall(seg):
                    if surname(text_of(raw_)): tei12["full_seg_ws_dated"] += 1
                for _, raw_ in FROMTO.findall(seg[:8000]):
                    if surname(text_of(raw_)): tei12["first8000_ws_dated"] += 1
        if (i + 1) % 50 == 0: print(i + 1, v, file=sys.stderr)
    res["scope"] = {"volumes": len(scope), "docs_head": docs_head, "div_tags_tei": divtags, "docs_tei_with_id_and_year": docs_tei_dated,
                    "marked_rows_without_doc_year": marked_undated, "types": dict(types),
                    "filtered_control_rows": cf_total, "novel": novel_total, "overlap": overlap_total, "overlap_check_vs_raw_heads": ovchk}
    w = {lo_hi[1] - lo_hi[0] for v, lo_hi in windows.items() if v in set(scope)}
    ws_ = [windows[v][1] - windows[v][0] for v in scope]
    res["windows"] = {"single_year": sum(1 for x in ws_ if x == 0), "multi": sum(1 for x in ws_ if x > 0), "max_hi_minus_lo": max(ws_), "min_nonzero": min(x for x in ws_ if x > 0)}
    res["sample12"] = tei12
    res["sample12_store"] = samp.out(windows, spans, bycf)
    res["whole"] = {k: p.out(windows, spans, bycf) for k, p in whole.items()}
    res["band"] = {b: {k: p.out(windows, spans, bycf) for k, p in ps.items()} for b, ps in sorted(band.items())}
    json.dump(res, open(os.path.join(HERE, "verify.json"), "w"), indent=1, default=list)
    print(json.dumps({k: res[k] for k in ("pocom_et", "loader_parity", "scope", "windows", "sample12", "sewards_in_office_1865")}, indent=1, default=list))

main()
