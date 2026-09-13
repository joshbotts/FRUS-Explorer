#!/usr/bin/env python3
"""verify-measure-agreement: INDEPENDENT corpus census of the agreement arm.

Imports none of agreement.py / agreement_census.py / census.py / measure_pocom.py / ner_store.py.
Own store readers; overlap via MERGED control-coverage intervals (not a prefix-max index); token-based
census K2; an ELEMENT-STACK TEI region map in R-0 coordinates (every TAG match is a token boundary, so a
comment is inert by construction) validated against the text layer at EVERY region boundary; own artifact
writer in census.py's grouped one-letter format; own ElementTree POCOM loader (with and without the regex
loader's two quirks); the m1a surname rule re-typed from its definition.
Writes v-census.json, samples.json and artifact-agreement.json(.gz) beside this script. Stdlib only.
"""
import bisect, collections, glob, gzip, json, os, random, re, statistics, sys, time
import xml.etree.ElementTree as ET

HOME = os.path.expanduser("~")
OUT = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
E_DIR = HOME + "/frus-ner-raw/marked"
FC_DIR = HOME + "/frus-ner-raw-control-filtered/detected"
FS_DIR = HOME + "/frus-ner-raw-filtered/detected"
TEXT = HOME + "/frus-semantic-raw/text"
TEI = "/Users/jbotts/Development/frus/volumes"
POCOM = "/Users/jbotts/Development/pocom"
BANDS = ["1861-1899", "1900-1929", "1930-1945", "1946-"]


def band_of(vol):
    y = int(re.search(r"frus(\d{4})", vol).group(1))
    assert y >= 1861, vol
    return BANDS[0] if y <= 1899 else BANDS[1] if y <= 1929 else BANDS[2] if y <= 1945 else BANDS[3]


def read_jsonl(dirpath, vol):
    c = [p for p in (os.path.join(dirpath, vol + ".jsonl"), os.path.join(dirpath, vol + ".jsonl.gz")) if os.path.exists(p)]
    assert len(c) == 1, (dirpath, vol, c)
    op = gzip.open if c[0].endswith(".gz") else open
    with op(c[0], "rt", encoding="utf-8") as h:
        return [json.loads(x) for x in h if x.strip()]


# ---------------------------------------------------------------- census K2, token-based
C_HON = set("mr mrs miss dr sir hon general colonel captain major admiral señor monsieur herr mme messrs rev judge governor president minister count baron lord lady prince king queen".split())
_k2c = {}


def K(n):
    v = _k2c.get(n)
    if v is not None:
        return v
    s = " ".join(n.casefold().split())
    for suf in ("’s", "'s", "’", "'"):
        if s.endswith(suf):
            s = s[:-len(suf)]
            break
    s = s.strip()
    v = s
    p = s.split(" ", 1)
    if len(p) == 2:
        t = p[0]
        if t == "m." or t in C_HON or (t.endswith(".") and t[:-1] in C_HON):
            r = p[1].strip()
            if r:
                v = r
    _k2c[n] = v
    return v


# ---------------------------------------------------------------- overlap via merged coverage
def coverage(spans):
    iv = sorted((s, e) for s, e, _ in spans if e > s)
    merged = []
    for s, e in iv:
        if merged and s <= merged[-1][1]:
            if e > merged[-1][1]:
                merged[-1][1] = e
        else:
            merged.append([s, e])
    return [m[0] for m in merged], merged


def touches(s, e, cov):
    if e <= s:
        return False
    starts, merged = cov
    i = bisect.bisect_left(starts, e) - 1
    return i >= 0 and merged[i][1] > s


# ---------------------------------------------------------------- TEI regions, element stack
DOCSPLIT = re.compile(r'(?=<div\b[^>]*type="document")')
TAGRE = re.compile(r"<[^>]+>")
NAMERE = re.compile(r"<(/?)([A-Za-z_][\w.:\-]*)")
APP = {"opener", "closer", "dateline", "salute", "signed", "postscript", "byline"}
TRACK = {"note", "head", "p", "list", "item", "table", "row", "cell", "quote", "lg", "l"} | APP


def classify(stack):
    names = [x[0] for x in stack]
    if "note" in names:
        return "note"
    heads = [x[1] for x in stack if x[0] == "head"]
    if heads:
        return "head" if 0 in heads else "other_head"
    if any(n in APP for n in names):
        return "apparatus"
    if any(n in ("table", "row", "cell") for n in names):
        return "prose:table"
    if any(n in ("list", "item") for n in names):
        return "prose:list"
    if "p" in names:
        return "prose:p"
    if any(n in ("quote", "lg", "l") for n in names):
        return "prose:quote"
    return "prose:other"


def volume_regions(xml):
    res = {}
    for ordinal, seg in enumerate(DOCSPLIT.split(xml)[1:]):
        tag_end = seg.find(">")
        cut = len(seg)
        nxt = seg.find("<div", tag_end + 1)
        if nxt != -1:
            cut = min(cut, nxt)
        be = seg.find("</body>")
        if be != -1:
            cut = min(cut, be)
        m = re.search(r'xml:id="([^"]+)"', seg[:600])
        did = m.group(1) if m else "ord%d" % ordinal
        ym = re.search(r'frus:doc-dateTime-min="(\d{4})', seg[:600])
        year = int(ym.group(1)) if ym else None
        body = seg[:cut]
        stack, nhead, out_len, pos = [], 0, 0, 0
        starts, states, firsttok = [], [], []
        cur = "prose:other"

        def take(chunk, out_len, cur):
            toks = chunk.split()
            if not toks:
                return out_len
            st = out_len + (1 if out_len else 0)
            if not states or states[-1] != cur:
                starts.append(st)
                states.append(cur)
                firsttok.append(toks[0])
            return st + sum(map(len, toks)) + len(toks) - 1
        for mt in TAGRE.finditer(body):
            if mt.start() > pos:
                out_len = take(body[pos:mt.start()], out_len, cur)
            pos = mt.end()
            nm = NAMERE.match(mt.group(0))
            if nm and nm.group(2) in TRACK:
                name = nm.group(2)
                if nm.group(1) == "/":
                    for j in range(len(stack) - 1, -1, -1):
                        if stack[j][0] == name:
                            del stack[j:]
                            break
                    cur = classify(stack)
                elif not mt.group(0).endswith("/>"):
                    stack.append((name, nhead if name == "head" else None))
                    if name == "head":
                        nhead += 1
                    cur = classify(stack)
        out_len = take(body[pos:], out_len, cur)
        if out_len == 0:
            continue
        assert did not in res, did
        res[did] = (out_len, year, starts, states, firsttok)
    return res


def region_at(entry, s):
    i = bisect.bisect_right(entry[2], s) - 1
    return entry[3][i] if i >= 0 else "before_first_token"


def coarse(r):
    return "prose" if r.startswith("prose") else r


# ---------------------------------------------------------------- POCOM, ElementTree, two variants
def load_pocom(quirk):
    """quirk=True mimics the m1a regex loader: <chief>/<principal> WITHOUT attributes only, <date> WITHOUT attributes only."""
    surnames = {}
    people_files = sorted(glob.glob(POCOM + "/people/*/*.xml"))
    for p in people_files:
        root = ET.parse(p).getroot()
        pid = root.findtext("id")
        sur = root.find(".//surname")
        if pid and sur is not None and sur.text and sur.text.strip():
            surnames[pid] = sur.text.strip()
    spans = collections.defaultdict(list)
    for p in sorted(glob.glob(POCOM + "/missions-*/*.xml")) + sorted(glob.glob(POCOM + "/positions-principals/*.xml")):
        root = ET.parse(p).getroot()
        for el in root.iter():
            if el.tag not in ("chief", "principal"):
                continue
            if quirk and el.attrib:
                continue
            pid = el.findtext("person-id")
            if not pid:
                continue
            years = []
            for dt in el.iter("date"):
                if quirk and dt.attrib:
                    continue
                if dt.text and re.match(r"\d{4}", dt.text):
                    years.append(int(dt.text[:4]))
            if years:
                spans[pid].append((min(years), max(years)))
    by_cf = collections.defaultdict(set)
    exact = collections.defaultdict(set)
    for slug, sur in surnames.items():
        if slug in spans:
            exact[sur].add(slug)
            by_cf[sur.casefold()].add(slug)
    stats = {"people_files": len(people_files), "people_with_surname": len(surnames), "people_with_dated_appointment": len(spans),
             "distinct_surnames_with_dated_appointment": len(exact), "distinct_surnames_casefolded": len(by_cf)}
    return spans, by_cf, stats


TITLES = {"Mr.", "Mrs.", "Sir", "Lord", "Count", "Baron", "Prince", "King", "Queen", "Excellency", "Dr.", "Hon."}
P_HON = set("""mr mrs miss ms dr sir lord lady count countess baron baroness prince princess king queen excellency hon gen general
col colonel capt captain maj major lieut lt lieutenant adm admiral commodore rev reverend don dona doña señor senor señora monsieur
m mme madame mlle herr earl duke marquis viscount president secretary ambassador minister governor judge prof professor the his
her majesty""".split())
assert len(P_HON) == 62, len(P_HON)


def pocom_surname(n):
    s = " ".join(re.sub(r"<[^>]+>", "", n).split())
    s = re.sub(r"(?:'|’)s$", "", s).strip()
    t = s.split()
    while t and t[0].strip(".,").casefold() in P_HON:
        t = t[1:]
    s = " ".join(t)
    if not s:
        return None
    toks = [x.strip(".,;:()") for x in s.split()]
    toks = [x for x in toks if x and x not in TITLES and x[0].isupper() and len(x) >= 3]
    return toks[-1] if toks else None


def main():
    t0 = time.time()
    scope = json.load(open(HOME + "/frus-ner-raw/scope.json"))["volumes"]
    assert len(scope) == 267
    manifest = {v["volumeId"]: int(v["dateRange"]["earliest"][:4]) for v in json.load(open(REPO + "/FRUSExplorer/Resources/manifest.json"))}
    pocom = {}
    for q in (True, False):
        pocom[q] = load_pocom(q)
    stcache = {}

    def status(n, year, q):
        ck = (n, year, q)
        v = stcache.get(ck)
        if v is not None:
            return v
        spans, by_cf, _ = pocom[q]
        sur = pocom_surname(n)
        if not sur:
            v = 0
        else:
            cands = by_cf.get(sur.casefold())
            if not cands:
                v = 1
            elif year is None:
                v = 2
            else:
                live = sum(1 for sl in cands if any(a - 1 <= year <= b + 1 for a, b in spans[sl]))
                v = 3 if live == 0 else 5 if live == 1 else 4
        stcache[ck] = v
        return v

    C = collections.Counter()
    keys = collections.defaultdict(set)
    added_per_doc = []
    sig = collections.Counter()
    sig_fine = collections.Counter()
    rows_region = collections.Counter()
    pocom_pairs = collections.Counter()
    key_best = collections.defaultdict(dict)
    pv_k2 = {}
    persons = collections.Counter()
    persons_corpus = collections.defaultdict(set)
    rng = random.Random(20260913)
    samples = collections.defaultdict(list)
    seen = collections.Counter()

    def reservoir(name, item, size=30):
        seen[name] += 1
        L = samples[name]
        if len(L) < size:
            L.append(item)
        else:
            j = rng.randrange(seen[name])
            if j < size:
                L[j] = item
    art = open(os.path.join(OUT, "artifact-agreement.json"), "w", encoding="utf-8")
    art.write('{"r":{')
    vocab = {}
    first_vol = True

    for vi, vol in enumerate(scope):
        band = band_of(vol)
        mh = json.load(open(os.path.join(E_DIR, vol + ".head.json")))
        ndocs = mh["docs"]
        C[("docs", band)] += ndocs
        C[("docs", "all")] += ndocs
        rows = {}
        for nm, dp in (("E", E_DIR), ("FC", FC_DIR), ("FS", FS_DIR)):
            rows[nm] = read_jsonl(dp, vol)
            C[("store_rows", nm)] += len(rows[nm])
            if nm != "E":
                hd = json.load(open(os.path.join(dp, vol + ".head.json")))
                if hd.get("sampled") is not False or hd.get("docs_in_volume") != ndocs or hd.get("mentions") != len(rows[nm]):
                    C[("head_problem", nm)] += 1
        texts = {}
        with gzip.open(os.path.join(TEXT, vol + ".jsonl.gz"), "rt", encoding="utf-8") as h:
            for x in h:
                if x.strip():
                    r = json.loads(x)
                    texts[r["d"]] = r["t"]
        reg = volume_regions(open(os.path.join(TEI, vol + ".xml"), encoding="utf-8").read())
        C[("text_docs", "all")] += len(texts)
        for d, t in texts.items():
            ent = reg.get(d)
            if ent is None or ent[0] != len(t):
                C[("length_mismatch", "all")] += 1
                continue
            for st, tok in zip(ent[2], ent[4]):
                C[("boundaries_checked", "all")] += 1
                if t[st:st + len(tok)] != tok:
                    C[("boundary_token_mismatch", "all")] += 1
        C[("region_docs_not_in_text", "all")] += sum(1 for d in reg if d not in texts)
        byd = {nm: collections.defaultdict(set) for nm in rows}
        ftrows = collections.defaultdict(set)
        for nm, rs in rows.items():
            for r in rs:
                sp = (r["s"], r["e"], r["n"])
                t = texts.get(r["d"])
                if t is None or t[r["s"]:r["e"]] != r["n"]:
                    C[("row_slice_mismatch", nm)] += 1
                byd[nm][r["d"]].add(sp)
                if nm == "E" and r.get("t") in ("from", "to"):
                    ftrows[r["d"]].add(sp)
                if nm != "E":
                    C[("raw_rows", nm, band)] += 1
        vol_entries = []
        vk = collections.defaultdict(set)
        vol_k2 = set()
        for d in sorted(set(byd["E"]) | set(byd["FC"]) | set(byd["FS"])):
            e, fc, fs = byd["E"].get(d, set()), byd["FC"].get(d, set()), byd["FS"].get(d, set())
            cfc, cfs, ce = coverage(fc), coverage(fs), coverage(e)
            int_fs = {x for x in fs if touches(x[0], x[1], cfc)}
            fs_only = fs - int_fs
            int_fc = {x for x in fc if touches(x[0], x[1], cfs)}
            fc_only = fc - int_fc
            agr = e | int_fs
            ent = reg.get(d)
            year = ent[1] if ent else None
            kE = {K(x[2]) for x in e}
            kA = {K(x[2]) for x in agr}
            kFC = {K(x[2]) for x in fc}
            kFS = {K(x[2]) for x in fs}
            vk["marked"] |= {" ".join(x[2].split()).lower() for x in e}
            vk["agreement"] |= {" ".join(x[2].split()).lower() for x in agr}
            vk["union_marked_fc"] |= {" ".join(x[2].split()).lower() for x in e | fc}
            for b in (band, "all"):
                C[("agr_rows_distinct", b)] += len(agr)
                C[("agr_rows_editor", b)] += len(e)
                C[("agr_rows_int_not_editor", b)] += len(int_fs - e)
                C[("int_fs_distinct", b)] += len(int_fs)
                C[("int_fc_distinct", b)] += len(int_fc)
                C[("fc_only_distinct", b)] += len(fc_only)
                C[("fs_only_distinct", b)] += len(fs_only)
                C[("agr_pairs", b)] += len(kA)
                C[("E_pairs", b)] += len(kE)
                C[("EuFC_pairs", b)] += len(kE | kFC)
                C[("agr_docs", b)] += 1 if kA else 0
                C[("E_docs", b)] += 1 if kE else 0
                C[("EuFC_docs", b)] += 1 if (kE or kFC) else 0
            keys[("agr", band)] |= kA
            keys[("agr", "all")] |= kA
            keys[("E", "all")] |= kE
            keys[("EuFC", "all")] |= kE | kFC
            vol_k2 |= kA
            if agr:
                ids = []
                for k in sorted(kA):
                    if k not in vocab:
                        vocab[k] = len(vocab)
                    ids.append(vocab[k])
                vol_entries.append("%s:%s" % (json.dumps(d, ensure_ascii=False), json.dumps(ids, separators=(",", ":"))))
            if ent:
                for x in ftrows.get(d, ()):
                    rows_region[("editor_fromto", band, coarse(region_at(ent, x[0])))] += 1
            # ---- beyond editor
            added = kA - kE
            if added:
                e_last = {k.split()[-1] for k in kE if k.split()}
                added_per_doc.append(len(added))
                for b in (band, "all"):
                    C[("gain_docs", b)] += 1
                    C[("gain_docs_no_editor", b)] += 0 if kE else 1
                    C[("added_pairs", b)] += len(added)
                    C[("added_lasttok_dup", b)] += sum(1 for k in added if k.split() and k.split()[-1] in e_last)
                    C[("added_single_token", b)] += sum(1 for k in added if len(k.split()) == 1)
                keys[("added", "all")] |= added
                regs = collections.defaultdict(set)
                for x in agr - e:
                    k = K(x[2])
                    if k in added:
                        r = region_at(ent, x[0]) if ent else "no_region"
                        regs[k].add(r)
                        rows_region[("added_rows", band, coarse(r))] += 1
                        rows_region[("added_rows_fine", band, r)] += 1
                        if r in ("prose:p", "prose:list", "prose:table", "prose:other", "apparatus", "note") and len(k.split()) >= 1:
                            reservoir("added_row_" + r, (vol, d, x[0], x[1], x[2], texts[d][max(0, x[0] - 90):x[1] + 90]))
                for k, rs in regs.items():
                    cs = {coarse(r) for r in rs}
                    sig[(band, "+".join(sorted(cs)))] += 1
                    sig[("all", "+".join(sorted(cs)))] += 1
                    sig_fine[("all", "+".join(sorted(rs)))] += 1
                    sig_fine[(band, "+".join(sorted(rs)))] += 1
            # ---- pools
            three = e | fc | fs
            pool3 = three - agr
            pools = {"fc_only": fc_only, "fs_only": fs_only, "three_way_minus_agreement": pool3}
            for pn, pr in pools.items():
                pk = {K(x[2]) for x in pr}
                net = ((kE | kFC | kFS) - kA) if pn == "three_way_minus_agreement" else (pk - kA)
                for b in (band, "all"):
                    C[(pn + "_rows", b)] += len(pr)
                    C[(pn + "_pairs_gross", b)] += len(pk)
                    C[(pn + "_pairs_net", b)] += len(net)
                    C[(pn + "_docs_net", b)] += 1 if net else 0
                keys[(pn + "_gross", band)] |= pk
                keys[(pn + "_gross", "all")] |= pk
                keys[(pn + "_net", band)] |= net
                keys[(pn + "_net", "all")] |= net
                if pn == "three_way_minus_agreement" and net:
                    src = collections.defaultdict(set)
                    for x in pr:
                        k = K(x[2])
                        if k in net:
                            src[k].add("int_fc" if x in int_fc else "fc_only" if x in fc_only else "fs_only" if x in fs_only else "other")
                    a_last = {k.split()[-1] for k in kA if k.split()}
                    for k, ss in src.items():
                        tag = "+".join(sorted(ss))
                        for b in (band, "all"):
                            C[("three_net_source", tag, b)] += 1
                            if k.split() and k.split()[-1] in a_last:
                                C[("three_net_lasttok_of_arm_key", b)] += 1
                        if ss == {"int_fc"}:
                            xs = [x for x in pr if K(x[2]) == k]
                            partner = sorted({y[2] for y in int_fs if any(min(x[1], y[1]) - max(x[0], y[0]) > 0 for x in xs)})
                            reservoir("three_net_int_fc_only", (vol, d, [x[2] for x in xs][:3], partner[:3]))
                if pn == "fs_only" and net:
                    for k in net:
                        xs = [x for x in pr if K(x[2]) == k]
                        if all(touches(x[0], x[1], ce) for x in xs):
                            for b in (band, "all"):
                                C[("fs_only_net_all_rows_overlap_editor", b)] += 1
            # ---- POCOM ceiling
            surf = collections.defaultdict(set)
            for x in agr:
                surf[K(x[2])].add(x[2])
            for k, ss in surf.items():
                origin = "added" if k in added else "editor"
                for q in (True, False):
                    st = max(status(n, year, q) for n in ss)
                    for o in (origin, "all"):
                        for b in (band, "all"):
                            pocom_pairs[(q, o, b, st)] += 1
                    for o, b in ((origin, "all"), ("all", "all"), ("all", band)):
                        kb = key_best[(q, o, b)]
                        if st > kb.get(k, -1):
                            kb[k] = st
        pv_k2[vol] = len(vol_k2)
        if not first_vol:
            art.write(",")
        first_vol = False
        art.write("%s:{%s}" % (json.dumps(vol), ",".join(vol_entries)))
        for nm, s in vk.items():
            persons[(nm, "rows")] += len(s)
            persons[(nm, "name_bytes")] += sum(len(x) for x in s)
            if manifest[vol] < 1910:
                persons[(nm, "pre1910")] += len(s)
            persons_corpus[nm] |= s
        if (vi + 1) % 25 == 0:
            print("  %d/%d %.0fs" % (vi + 1, len(scope), time.time() - t0), file=sys.stderr)

    inv = [None] * len(vocab)
    for k, i in vocab.items():
        inv[i] = k
    art.write('},"s":' + json.dumps(inv, ensure_ascii=False, separators=(",", ":")) + "}")
    art.close()
    ap = os.path.join(OUT, "artifact-agreement.json")
    with open(ap, "rb") as src, open(ap + ".gz", "wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=9, mtime=0) as dst:
        dst.write(src.read())

    def bb(metric):
        return {b: C[(metric, b)] for b in BANDS + ["all"]}

    def q_(vals, p):
        v = sorted(vals)
        return v[min(len(v) - 1, int(round(p * (len(v) - 1))))]
    res = {"script": os.path.abspath(__file__), "elapsed_secs": None,
           "controls": {"store_rows": {nm: C[("store_rows", nm)] for nm in ("E", "FC", "FS")},
                        "head_problems": {nm: C[("head_problem", nm)] for nm in ("FC", "FS")},
                        "row_slice_mismatch": {nm: C[("row_slice_mismatch", nm)] for nm in ("E", "FC", "FS")},
                        "text_docs": C[("text_docs", "all")], "length_mismatch": C[("length_mismatch", "all")],
                        "region_boundaries_checked": C[("boundaries_checked", "all")],
                        "region_boundary_token_mismatch": C[("boundary_token_mismatch", "all")],
                        "region_docs_not_in_text": C[("region_docs_not_in_text", "all")],
                        "pocom_loader_quirk": pocom[True][2], "pocom_loader_et": pocom[False][2],
                        "editor_fromto_region": {b: {r: rows_region[("editor_fromto", b, r)] for r in ("head", "other_head", "note", "apparatus", "prose")} for b in BANDS}},
           "docs": bb("docs"),
           "task1": {"rows_distinct": bb("agr_rows_distinct"), "rows_editor": bb("agr_rows_editor"), "rows_int_not_editor": bb("agr_rows_int_not_editor"),
                     "int_fs_distinct": bb("int_fs_distinct"), "int_fc_distinct": bb("int_fc_distinct"),
                     "fc_only_distinct": bb("fc_only_distinct"), "fs_only_distinct": bb("fs_only_distinct"),
                     "raw_rows_FC": {b: C[("raw_rows", "FC", b)] for b in BANDS}, "raw_rows_FS": {b: C[("raw_rows", "FS", b)] for b in BANDS},
                     "pairs": bb("agr_pairs"), "docs_reached": bb("agr_docs"),
                     "distinct_K2": {b: len(keys[("agr", b)]) for b in BANDS + ["all"]},
                     "per_volume_distinct_K2": {"median": statistics.median(pv_k2.values()), "max": max(pv_k2.values()), "max_volume": max(pv_k2, key=pv_k2.get)},
                     "artifact": {"bytes": os.path.getsize(ap), "gzip_bytes": os.path.getsize(ap + ".gz"), "vocab": len(vocab)},
                     "editor": {"pairs": bb("E_pairs"), "docs": bb("E_docs"), "distinct_K2": len(keys[("E", "all")])},
                     "editor_union_fc": {"pairs": bb("EuFC_pairs"), "docs": bb("EuFC_docs"), "distinct_K2": len(keys[("EuFC", "all")])},
                     "persons_rows_lowercase_key": {nm: {"rows": persons[(nm, "rows")], "pre1910": persons[(nm, "pre1910")], "name_bytes": persons[(nm, "name_bytes")], "corpus_distinct": len(persons_corpus[nm])} for nm in ("marked", "agreement", "union_marked_fc")}},
           "task2": {"gain_docs": bb("gain_docs"), "gain_docs_no_editor": bb("gain_docs_no_editor"), "added_pairs": bb("added_pairs"),
                     "added_lasttok_dup": bb("added_lasttok_dup"), "added_single_token": bb("added_single_token"),
                     "added_distinct_K2": len(keys[("added", "all")]), "added_never_in_editor_vocab": len(keys[("added", "all")] - keys[("E", "all")]),
                     "per_gaining_doc": {"mean": round(sum(added_per_doc) / len(added_per_doc), 3), "median": statistics.median(added_per_doc),
                                         "p90": q_(added_per_doc, .9), "p99": q_(added_per_doc, .99), "max": max(added_per_doc)},
                     "pair_signature_coarse": {b: {s: n for (bb_, s), n in sig.items() if bb_ == b} for b in BANDS + ["all"]},
                     "pair_signature_fine_all": {s: n for (bb_, s), n in sorted(sig_fine.items(), key=lambda kv: -kv[1]) if bb_ == "all"},
                     "rows_region": {b: {r: n for (p, bb_, r), n in rows_region.items() if p == "added_rows" and bb_ == b} for b in BANDS},
                     "rows_region_fine": {b: {r: n for (p, bb_, r), n in rows_region.items() if p == "added_rows_fine" and bb_ == b} for b in BANDS}},
           "task3": {pn: {"rows": bb(pn + "_rows"), "pairs_gross": bb(pn + "_pairs_gross"), "pairs_net": bb(pn + "_pairs_net"), "docs_net": bb(pn + "_docs_net"),
                          "keys_gross": {b: len(keys[(pn + "_gross", b)]) for b in BANDS + ["all"]},
                          "keys_net": {b: len(keys[(pn + "_net", b)]) for b in BANDS + ["all"]},
                          "keys_gross_absent_from_arm_vocab": len(keys[(pn + "_gross", "all")] - keys[("agr", "all")])}
                     for pn in ("fc_only", "fs_only", "three_way_minus_agreement")},
           "task3_extra": {"three_net_pair_sources": {tag: {k[2]: n for k, n in C.items() if len(k) == 3 and k[0] == "three_net_source" and k[1] == tag} for tag in sorted({k[1] for k in C if len(k) == 3 and k[0] == "three_net_source"})},
                           "three_net_pairs_last_token_equals_an_arm_key_last_token": bb("three_net_lasttok_of_arm_key"),
                           "fs_only_net_pairs_all_rows_overlap_an_editor_span": bb("fs_only_net_all_rows_overlap_editor")},
           "task4": {}}
    for q in (True, False):
        blk = {}
        for o in ("all", "editor", "added"):
            blk[o] = {}
            for b in BANDS + ["all"]:
                cnt = [pocom_pairs[(q, o, b, s)] for s in range(6)]
                tot = sum(cnt)
                blk[o][b] = {"pairs": tot, "no_surname": cnt[0], "unknown": cnt[1], "undated": cnt[2], "nobody": cnt[3], "several": cnt[4], "exactly_one": cnt[5],
                             "known": tot - cnt[0] - cnt[1], "in_office": cnt[4] + cnt[5],
                             "share_in_office": round((cnt[4] + cnt[5]) / tot, 4) if tot else None, "share_exactly_one": round(cnt[5] / tot, 4) if tot else None}
        kblk = {}
        for (qq, o, b), kb in key_best.items():
            if qq != q:
                continue
            cc = collections.Counter(kb.values())
            kblk["%s/%s" % (o, b)] = {"keys": len(kb), "known": len(kb) - cc[0] - cc[1], "in_office": cc[4] + cc[5], "exactly_one": cc[5]}
        res["task4"]["quirk_loader" if q else "elementtree_loader"] = {"pairs": blk, "keys": kblk}
    res["elapsed_secs"] = round(time.time() - t0, 1)
    json.dump(res, open(os.path.join(OUT, "v-census.json"), "w"), indent=1, ensure_ascii=False)
    json.dump(samples, open(os.path.join(OUT, "samples.json"), "w"), indent=1, ensure_ascii=False)
    print(json.dumps(res["controls"], indent=1))
    print("elapsed", res["elapsed_secs"])


if __name__ == "__main__":
    main()
