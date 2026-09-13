#!/usr/bin/env python3
"""#234 identity lens: what an identity pass would be choosing among, and with what evidence.

Read-only. Stdlib only. Writes candidates.json, head-evidence.json, cases.txt beside itself.

Population: EVERY marked from/to row in the 267 scope volumes (not a sample; superset of the
>=20,000 stratified sample asked for). Document year = TEI frus:doc-dateTime-min (the rule
measure_pocom.py uses), so the POCOM-verbatim column is a positive control against pocom.json
(235,751 from/to rows, 235,218 with surname, 189,613 known, 130,321 unique, 40,563 nobody, 18,729 several).
"""
import re, os, sys, json, glob, gzip, random, sqlite3, unicodedata, collections

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
VOLUMES = "/Users/jbotts/Development/frus/volumes"
POCOM = "/Users/jbotts/Development/pocom"
PEOPLE = "/Users/jbotts/Development/people/data"
PCOMPLETE = "/Users/jbotts/Development/frus-name-authority/4_Outputs/persons-complete.xml"
AUTH = REPO + "/FRUSExplorer/Resources/person-authority-index.json"
MANIFEST = REPO + "/FRUSExplorer/Resources/manifest.json"
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
MARKED = os.path.expanduser("~/frus-ner-raw")
TEXT = os.path.expanduser("~/frus-semantic-raw/text")
sys.path.insert(0, REPO + "/tools/semantic-harvest")
import ner_store

# ---- verbatim from measure_pocom.py / m1a_survey.py
DOCSPLIT = re.compile(r'(?=<div\b[^>]*type="document")')
DOCDATE = re.compile(r'frus:doc-dateTime-min="(\d{4})')
TITLES = {"Mr.", "Mrs.", "Sir", "Lord", "Count", "Baron", "Prince", "King",
          "Queen", "Excellency", "Dr.", "Hon."}


def text_of(fragment):
    return " ".join(re.sub(r"<[^>]+>", "", fragment).split())


def surname_of(name):
    toks = [t.strip(".,;:()") for t in name.split()]
    toks = [t for t in toks if t and t not in TITLES and t[0].isupper() and len(t) >= 3]
    return toks[-1] if toks else None
# ---- end verbatim


HONOR = {"mr", "mrs", "miss", "ms", "dr", "sir", "lord", "lady", "count", "countess", "baron", "baroness", "prince",
         "princess", "king", "queen", "excellency", "hon", "gen", "general", "col", "colonel", "capt", "captain", "maj",
         "major", "lieut", "lt", "lieutenant", "adm", "admiral", "commodore", "commander", "rev", "reverend", "don", "dona",
         "señor", "senor", "señora", "monsieur", "m", "mme", "madame", "mlle", "herr", "earl", "duke", "marquis", "viscount",
         "president", "secretary", "ambassador", "minister", "governor", "judge", "prof", "professor", "the", "his", "her",
         "majesty", "messrs", "esq", "consul", "chargé", "charge", "acting", "vice", "senator", "u", "s", "n", "usn"}


def fold(s):
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c)).casefold()


SUFFIX = {"jr", "jr.", "sr", "sr.", "ii", "iii", "iv", "2d", "3d"}


def source_surname(name):
    """Surname key for an authority-style name: 'Surname, Forenames' -> last token before the
    first comma; otherwise the last non-suffix token. Parentheticals removed. Folded."""
    name = re.sub(r"\([^)]*\)", " ", name or "").strip()
    if not name:
        return None, ""
    if "," in name:
        head, rest = name.split(",", 1)
        toks = head.split()
        fore = rest.strip()
    else:
        toks = [t for t in name.split() if t.strip(".,").casefold() not in SUFFIX]
        fore = " ".join(toks[:-1])
    toks = [t.strip(".,;:") for t in toks if t.strip(".,;:")]
    if not toks:
        return None, ""
    return fold(toks[-1]), fore


def initial_of(fore):
    toks = [t for t in re.split(r"[\s.]+", fore or "") if t and t[0].isalpha() and fold(t) not in SUFFIX]
    return fold(toks[0][0]) if toks else None


def year_of(s):
    return int(s[:4])


def load_windows():
    man = json.load(open(MANIFEST))
    vols = man["volumes"] if isinstance(man, dict) else man
    return {v["volumeId"]: (year_of(v["dateRange"]["earliest"]), year_of(v["dateRange"]["latest"])) for v in vols}


def life_window(b, d):
    """INFERRED plausibility rule: active from age 18 to death; one-sided bounds padded."""
    if b and d:
        return (b + 18, d)
    if b:
        return (b + 18, b + 85)
    if d:
        return (d - 65, d)
    return None


def hum(x):
    return (x or "").replace("-", " ")


# --------------------------------------------------------------------------- sources
def load_pocom():
    people = {}
    for path in sorted(glob.glob(f"{POCOM}/people/*/*.xml")):
        t = open(path, encoding="utf-8", errors="replace").read()
        sid = re.search(r"<id>([^<]+)</id>", t)
        sur = re.search(r"<surname>([^<]*)</surname>", t)
        fore = re.search(r"<forename>([^<]*)</forename>", t)
        if sid and sur and sur.group(1).strip():
            people[sid.group(1)] = (sur.group(1).strip(), (fore.group(1).strip() if fore else ""))
    appts = collections.defaultdict(list)  # slug -> [(lo, hi, role, where)]
    for path in sorted(glob.glob(f"{POCOM}/missions-*/*.xml")) + sorted(glob.glob(f"{POCOM}/positions-principals/*.xml")):
        t = open(path, encoding="utf-8", errors="replace").read()
        fileid = re.search(r"<(?:territory-id|id)>([^<]+)<", t)
        pname = re.search(r"<singular>([^<]+)</singular>", t)
        for blk in re.findall(r"<(?:chief|principal)>.*?</(?:chief|principal)>", t, re.S):
            pid = re.search(r"<person-id>([^<]+)</person-id>", blk)
            if not pid:
                continue
            years = [int(y) for y in re.findall(r"<date>(\d{4})", blk)]
            if not years:
                continue
            role = re.search(r"<role-title-id>([^<]+)<", blk)
            terr = re.search(r"<contemporary-territory-id>([^<]+)<", blk)
            if "positions-principals" in path:
                where = " ".join((pname.group(1) if pname else hum(fileid.group(1))).split())
                rl = where
            else:
                where = hum(terr.group(1) if terr else (fileid.group(1) if fileid else ""))
                rl = hum(role.group(1) if role else "")
            appts[pid.group(1)].append((min(years), max(years), rl, where))
    return people, appts


def load_registry():
    out = {}
    for path in glob.glob(f"{PEOPLE}/**/*.xml", recursive=True):
        t = open(path, encoding="utf-8", errors="replace").read()
        pid = re.search(r"<id>([^<]+)</id>", t)
        if not pid:
            continue
        names = re.findall(r"<name>([^<]+)</name>", t)
        by = re.search(r"<birth-year>(\d{4})", t)
        dy = re.search(r"<death-year>(\d{4})", t)
        slug = re.search(r"departmenthistory/people/([a-z0-9-]+)", t)
        vols = set(re.findall(r"historicaldocuments/([^/<]+)/persons", t))
        remark = re.search(r"<p>([^<]+)</p>", t)
        out[pid.group(1)] = dict(names=list(dict.fromkeys(names)), b=int(by.group(1)) if by else None,
                                 d=int(dy.group(1)) if dy else None, slug=slug.group(1) if slug else None,
                                 vols=vols, remark=(remark.group(1)[:90] if remark else ""))
    return out


def load_pcomplete():
    t = open(PCOMPLETE, encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'<person xml:id="([^"]+)">(.*?)</person>', t, re.S):
        body = m.group(2)
        names = re.findall(r'<persName type="(?:main|variant)">([^<]+)</persName>', body)
        pids = re.findall(r'<idno type="people-id">([^<]+)</idno>', body)
        vols = set(re.findall(r'<idno type="frus-ref">([^/<]+)/', body))
        b = re.search(r"<birth[^>]*>\D*(\d{4})", body)
        d = re.search(r"<death[^>]*>\D*(\d{4})", body)
        occ = re.search(r"<occupation>([^<]+)</occupation>", body)
        out[m.group(1)] = dict(names=list(dict.fromkeys(names)), pids=pids, vols=vols,
                               b=int(b.group(1)) if b else None, d=int(d.group(1)) if d else None,
                               occ=(occ.group(1)[:90] if occ else ""))
    return out


class Index:
    """surname key -> [(identity, windows, initials set, label)]; undated entries kept apart."""

    def __init__(self, name):
        self.name = name
        self.by = collections.defaultdict(list)
        self.undated = collections.defaultdict(set)
        self.entities = 0
        self.dated_entities = 0

    def add(self, ident, names, windows, label):
        self.entities += 1
        keys = {}
        for n in names:
            k, fore = source_surname(n)
            if k and len(k) >= 2:
                keys.setdefault(k, set())
                ini = initial_of(fore)
                if ini:
                    keys[k].add(ini)
        if not windows:
            for k in keys:
                self.undated[k].add(ident)
            return
        self.dated_entities += 1
        for k, inis in keys.items():
            self.by[k].append((ident, windows, inis, label))

    def candidates(self, key, year):
        out = {}
        for ident, windows, inis, label in self.by.get(key, ()):
            if any(lo - 1 <= year + 0 and year <= hi + 1 for lo, hi in windows):
                out.setdefault(ident, (inis, label))
        return out


def build_sources(windows):
    pocom_people, appts = load_pocom()
    reg = load_registry()
    pcomp = load_pcomplete()
    auth = json.load(open(AUTH))
    slug_to_pid = {}
    for pid, r in reg.items():
        if r["slug"]:
            slug_to_pid.setdefault(r["slug"], pid)
    for pid, a in auth["authority"].items():
        if a.get("s"):
            slug_to_pid.setdefault(a["s"], pid)

    def ident_for_slug(slug):
        return "A" + slug_to_pid[slug] if slug in slug_to_pid else "P" + slug

    def vol_windows(vols):
        return [windows[v] for v in sorted(vols) if v in windows]

    S = {}
    # POCOM
    ix = Index("pocom")
    pocom_label = {}
    for slug, (sur, fore) in pocom_people.items():
        if slug not in appts:
            continue
        spans = [(lo, hi) for lo, hi, _, _ in appts[slug]]
        label = "; ".join(sorted({"%s %s %d-%d" % (r, ("(" + w + ")") if w and w != r else "", lo, hi)
                                  for lo, hi, r, w in appts[slug]}))[:220]
        pocom_label[slug] = label
        ix.add(ident_for_slug(slug), ["%s, %s" % (sur.split()[-1], fore)], spans, "POCOM " + slug + ": " + label)
    S["pocom"] = ix
    # bundled authority index: life window + crosswalk appearance windows
    cross_vols = collections.defaultdict(set)
    for vol, refs in auth["crosswalk"].items():
        for ref, pid in refs.items():
            cross_vols[str(pid)].add(vol)
    ix = Index("authority_index")
    for pid, a in auth["authority"].items():
        w = []
        lw = life_window(a.get("b"), a.get("d"))
        if lw:
            w.append(lw)
        w += vol_windows(cross_vols.get(pid, ()))
        ix.add("A" + pid, [a["n"]], w, "AUTH %s: %s (b%s d%s) %s" % (pid, a["n"], a.get("b"), a.get("d"), (a.get("r") or "")[:90]))
    S["authority_index"] = ix
    # HistoryAtState people registry
    ix = Index("people_registry")
    for pid, r in reg.items():
        w = []
        lw = life_window(r["b"], r["d"])
        if lw:
            w.append(lw)
        w += vol_windows(r["vols"])
        ix.add("A" + pid, r["names"], w, "REG %s: %s (b%s d%s) %s" % (pid, r["names"][0] if r["names"] else "?", r["b"], r["d"], r["remark"]))
    S["people_registry"] = ix
    # frus-name-authority persons-complete.xml
    ix = Index("persons_complete")
    for fid, r in pcomp.items():
        w = []
        lw = life_window(r["b"], r["d"])
        if lw:
            w.append(lw)
        w += vol_windows(r["vols"])
        ident = ("A" + r["pids"][0]) if r["pids"] else fid
        ix.add(ident, r["names"], w, "PC %s: %s %s" % (fid, r["names"][0] if r["names"] else "?", r["occ"]))
    S["persons_complete"] = ix
    # live index editor lists (person_rollup over the 285 covered volumes)
    c = sqlite3.connect("file:%s?mode=ro" % DB, uri=True)
    members = collections.defaultdict(set)
    mnames = collections.defaultdict(set)
    for vol, ref, rid, name in c.execute(
            "select m.volume_id, m.ref, m.rollup_id, p.name from person_rollup_member m join persons p using(volume_id, ref)"):
        members[rid].add(vol)
        mnames[rid].add(name)
    ix = Index("live_index_rollups")
    for rid, name, aid, desc in c.execute("select rollup_id, canonical_name, authority_id, description from person_rollup"):
        ident = ("A%d" % aid) if aid else ("R%d" % rid)
        ix.add(ident, [name] + sorted(mnames[rid]), vol_windows(members[rid]),
               "LIVE r%d: %s %s" % (rid, name, (desc or "")[:90]))
    S["live_index_rollups"] = ix
    meta = {"pocom_people_with_surname": len(pocom_people), "pocom_people_with_dated_appointment": len(appts),
            "registry_people": len(reg), "registry_with_birth": sum(1 for r in reg.values() if r["b"]),
            "registry_with_death": sum(1 for r in reg.values() if r["d"]),
            "registry_with_frus_persons_url": sum(1 for r in reg.values() if r["vols"]),
            "registry_with_pocom_slug": sum(1 for r in reg.values() if r["slug"]),
            "authority_index_people": len(auth["authority"]),
            "persons_complete_entries": len(pcomp),
            "persons_complete_with_people_id": sum(1 for r in pcomp.values() if r["pids"]),
            "live_rollups": c.execute("select count(*) from person_rollup").fetchone()[0],
            "live_rollups_with_authority_id": c.execute("select count(*) from person_rollup where authority_id is not null").fetchone()[0],
            "pocom_slugs_mapped_to_people_id": sum(1 for s in appts if s in slug_to_pid)}
    for k, ix in S.items():
        meta[k + "_entities"] = ix.entities
        meta[k + "_dated_entities"] = ix.dated_entities
        meta[k + "_distinct_dated_surname_keys"] = len(ix.by)
    return S, meta, pocom_people, appts


def bin_of(n):
    return "0" if n == 0 else "1" if n == 1 else "2-5" if n <= 5 else ">5"


def tei_doc_years(vol):
    t = open(f"{VOLUMES}/{vol}.xml", encoding="utf-8", errors="replace").read()
    out = {}
    for seg in DOCSPLIT.split(t)[1:]:
        head = seg[:600]
        ym = DOCDATE.search(head)
        did = re.search(r'xml:id="([^"]+)"', head)
        if ym and did:
            out[did.group(1)] = int(ym.group(1))
    return out


POST = re.compile(r"\b(Secretary|Under Secretary|Assistant Secretary|Ambassador|Minister|Chargé|Charge|Consul|"
                  r"Vice Consul|Consul General|President|Governor|Counselor|Counsellor|Representative|Commissioner|"
                  r"Delegate|Delegation|Admiral|General|Agent|Envoy|Attorney General|Senator|Chairman|Prime Minister|"
                  r"Emperor|King|Queen|Sultan|Khedive|Viceroy|Premier|Chancellor|Director|Adviser|Advisor|Legation|Embassy|"
                  r"Military Attaché|Naval Attaché|Attaché|Ministry|Foreign Office|Department)\b")
MONTH = r"(January|February|March|April|May|June|July|August|September|October|November|December|Jan\.|Feb\.|Mar\.|Apr\.|Aug\.|Sept?\.|Oct\.|Nov\.|Dec\.)"
DATELINE = re.compile(r"([A-Z][A-Za-zÀ-ÿ'’.\- ]{2,40}?)\s*,\s*\]?\s*" + MONTH + r"\s+\d{1,2}\s*,?\s*\d{4}")
NOTE_PREFIX = ("prefix_title = a post word among the 3 tokens before the span, not right after 'to' or a full stop "
               "(e.g. Minister Blanchard, President Wilson); counted in doc_head_names_a_fromto_with_post")
ALIASES = {"united kingdom": ("united kingdom", "great britain", "england", "london"), "russia": ("russia", "soviet union", "moscow"),
           "holy see": ("holy see", "vatican"), "china": ("china", "peking", "peiping", "chungking", "nanking")}
RULE_DEF = ("local = R-0 text from 110 chars before the span to 70 after it, folded. For each POCOM officeholder of the surname "
            "in office in the doc year (+-1), a match if one of their in-office appointments' place (territory/org id, hyphens as spaces; "
            "aliases for united kingdom, russia, holy see, china) or principal-position title occurs as a whole word in local. "
            "resolves_one = exactly one in-office officeholder matches. For class 'one' this is agreement, not accuracy; "
            "for 'nobody' it is 0 by construction.")
OFFICE_ONLY = re.compile(r"\b(?:to|from)\s+the\s+(Secretary of State|Acting Secretary of State|President|Department of State)\b")


def main():
    rnd = random.Random(234)
    windows = load_windows()
    S, meta, pocom_people, appts = build_sources(windows)
    print("sources loaded", json.dumps(meta), file=sys.stderr)
    # verbatim POCOM for the positive control
    pocom_by_surname = collections.defaultdict(set)
    for slug, (sur, _) in pocom_people.items():
        if slug in appts:
            pocom_by_surname[sur].add(slug)

    scope = ner_store.scope_volumes(MARKED)
    names = list(S) + ["union"]
    bins = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))  # band -> src -> bin
    initial_bins = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
    undated_hit = collections.defaultdict(lambda: collections.defaultdict(int))
    ctrl = collections.Counter()
    ctrl_band = collections.defaultdict(collections.Counter)
    union_given_pocom = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
    decisions = collections.defaultdict(lambda: collections.defaultdict(set))
    surface_initial = collections.defaultdict(collections.Counter)
    several_cases, nobody_cases = collections.defaultdict(list), collections.defaultdict(list)
    head_stats = collections.defaultdict(collections.Counter)
    namekey_bins = collections.defaultdict(collections.Counter)
    initial_prefilter = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
    rule = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
    other_examples = collections.defaultdict(list)
    head_docs = collections.defaultdict(list)

    for i, vol in enumerate(scope):
        band = ner_store.band_of(vol)
        years = tei_doc_years(vol)
        rows = ner_store.volume_layer(MARKED, "marked", vol)
        texts = ner_store.volume_text(TEXT, vol)
        fromto_by_doc = collections.defaultdict(list)
        for r in rows:
            if r["t"] not in ("from", "to"):
                continue
            fromto_by_doc[r["d"]].append(r)
            y = years.get(r["d"])
            raw = r["n"]
            sur = surname_of(text_of(raw))
            ctrl["n"] += 1
            if not sur:
                continue
            ctrl["with_surname"] += 1
            if y is None:
                ctrl["no_year"] += 1
                continue
            # verbatim POCOM class
            cands = pocom_by_surname.get(sur)
            pclass = "unknown"
            if cands:
                ctrl["known"] += 1
                live = sum(1 for s in cands if any(a - 1 <= y <= b + 1 for a, b, _, _ in appts[s]))
                pclass = "nobody" if live == 0 else "one" if live == 1 else "several"
                ctrl[pclass] += 1
                ctrl_band[band][pclass] += 1
            ctrl_band[band]["with_surname"] += 1
            key = fold(sur)
            # mention initial (a given-name initial printed before the surname)
            toks = [t.strip(".,;:()") for t in text_of(raw).split()]
            toks = [t for t in toks if t and t[0].isupper() and fold(t) not in HONOR and fold(t) != key]
            m_ini = fold(toks[0][0]) if (toks and fold(sur) == key and text_of(raw).split()[-1].strip(".,;:()") == sur) else None
            surface_initial[band]["with_initial" if m_ini else "surname_only"] += 1
            union = {}
            for src, ix in S.items():
                cs = ix.candidates(key, y)
                bins[band][src][bin_of(len(cs))] += 1
                if not cs and ix.undated.get(key):
                    undated_hit[band][src] += 1
                for ident, (inis, label) in cs.items():
                    e = union.setdefault(ident, [set(), []])
                    e[0] |= inis
                    e[1].append(label)
                if m_ini:
                    initial_prefilter[band][src][bin_of(len(cs))] += 1
                    ci = {k: v for k, v in cs.items() if not v[0] or m_ini in v[0]}
                    initial_bins[band][src][bin_of(len(ci))] += 1
            ub = bin_of(len(union))
            nk = {(key, v[0] and min(v[0]) or None) for v in union.values()}
            namekey_bins[band][bin_of(len({k for k in nk}))] += 1
            bins[band]["union"][ub] += 1
            union_given_pocom[band][pclass][ub] += 1
            if m_ini:
                initial_prefilter[band]["union"][ub] += 1
                ci = {k: v for k, v in union.items() if not v[0] or m_ini in v[0]}
                initial_bins[band]["union"][bin_of(len(ci))] += 1
            if ub != "1":
                decisions[band]["mention_rows"].add((vol, r["d"], r["o"] if "o" in r else None, r["s"]))
                decisions[band]["doc_surface"].add((vol, r["d"], fold(text_of(raw))))
                decisions[band]["vol_surface"].add((vol, fold(text_of(raw))))
            if pclass in ("one", "several", "nobody"):
                tt = texts.get(r["d"])
                if tt is None:
                    rule[band][pclass]["no_text"] += 1
                else:
                    local = fold(" ".join(tt[max(0, r["s"] - 110):r["e"] + 70].split()))
                    hits = 0
                    for slug in pocom_by_surname.get(sur, ()):
                        live_ap = [ap for ap in appts[slug] if ap[0] - 1 <= y <= ap[1] + 1]
                        ok = False
                        for lo_, hi_, rl_, where_ in live_ap:
                            w = fold(where_)
                            alts = ALIASES.get(w, (w,))
                            if any(a and re.search(r"\b" + re.escape(a) + r"\b", local) for a in alts):
                                ok = True
                        hits += ok
                    rule[band][pclass]["resolves_one" if hits == 1 else "matches_several" if hits > 1 else "matches_none"] += 1
            rec = (vol, r["d"], y, r["t"], raw, r["s"], r["e"], union)
            if pclass == "several":
                several_cases[band].append(rec)
            elif pclass == "nobody":
                nobody_cases[band].append(rec)
        # head evidence sample: every document is a candidate; reservoir per band below
        head_docs[band].extend((vol, d) for d in years)
        if (i + 1) % 25 == 0:
            print("[%d/%d] %s" % (i + 1, len(scope), vol), file=sys.stderr)

    # ---------------- head evidence over a stratified document sample (1,500 per band)
    head_sample = {b: rnd.sample(v, min(1500, len(v))) for b, v in head_docs.items()}
    by_vol = collections.defaultdict(list)
    for b, lst in head_sample.items():
        for vol, d in lst:
            by_vol[vol].append((b, d))
    head_examples = collections.defaultdict(list)
    for vol, items in sorted(by_vol.items()):
        texts = ner_store.volume_text(TEXT, vol)
        rows = ner_store.volume_layer(MARKED, "marked", vol)
        rbd = collections.defaultdict(list)
        for r in rows:
            rbd[r["d"]].append(r)
        for b, d in items:
            hs = head_stats[b]
            t = texts.get(d)
            hs["docs"] += 1
            if t is None:
                hs["no_text"] += 1
                continue
            head = t[:300]
            ft = [r for r in rbd.get(d, ()) if r["t"] in ("from", "to") and r["s"] < 300]
            anyft = [r for r in rbd.get(d, ()) if r["t"] in ("from", "to")]
            if anyft:
                hs["doc_has_fromto_mark_anywhere"] += 1
            if ft:
                hs["doc_has_fromto_mark_in_first_300"] += 1
            post_any = False
            for r in ft:
                hs["fromto_mentions_in_head"] += 1
                before = t[max(0, r["s"] - 90):r["s"]]
                after = t[r["e"]:r["e"] + 60]
                # (a) "The Minister in China ( Johnson )" : span inside parens preceded by a post phrase
                pa = re.search(r"\(\s*$", before) and POST.search(before.split(" to ")[-1] if " to " in before else before)
                # (b) "Mr. Black ( Secretary of State )" : post in a parenthesis right after the name
                pb = re.match(r"\s*\(\s*[^)]{0,60}\)", after) and POST.search(after[:60])
                # (c) "Mr. X, Minister at Y," appositive
                pc = re.match(r"\s*,\s*[^,.]{0,50}", after) and POST.search(after[:50])
                if pa or pb or pc:
                    hs["fromto_mentions_in_head_with_post"] += 1
                    post_any = True
                    if re.search(r"\b(in|at|to)\s+(the\s+)?[A-Z]", (before + " " + after)):
                        hs["fromto_mentions_in_head_with_post_and_place_word"] += 1
                elif POST.search(" ".join(before.split()[-3:])) and not re.search(r"\bto\s*$|\.\s*$", before):
                    hs["fromto_mentions_in_head_prefix_title"] += 1
                    post_any = True
                elif re.match(r"(Mr|Mrs|Señor|Senor|Sir|Baron|Count|M|Messrs|Lord|Earl)\.?\s", t[r["s"]:r["e"]]):
                    hs["fromto_mentions_in_head_span_starts_with_honorific"] += 1
                elif re.search(r"\b(Mr|Mrs|Señor|Senor|Sir|Baron|Count|M|Messrs)\.?\s*$", before):
                    hs["fromto_mentions_in_head_bare_honorific_only"] += 1
                else:
                    hs["fromto_mentions_in_head_other"] += 1
                    if len(other_examples[b]) < 12:
                        other_examples[b].append(" ".join(t[max(0, r["s"] - 50):r["e"] + 30].split()) + "  <<" + t[r["s"]:r["e"]] + ">>")
            if post_any:
                hs["doc_head_names_a_fromto_with_post"] += 1
            for om in OFFICE_ONLY.finditer(head):
                hs["office_only_phrases_in_head"] += 1
                o_s, o_e = om.start(1), om.end(1)
                if any(r["s"] < o_e and r["e"] > o_s for r in rbd.get(d, ())):
                    hs["office_only_phrases_in_head_overlapping_any_mark"] += 1
            if OFFICE_ONLY.search(head):
                hs["doc_head_office_only_correspondent"] += 1
            dl = DATELINE.search(t[:400])
            if dl:
                hs["doc_dateline_place_in_first_400"] += 1
            if re.search(r"\bNo\.\s*\d+", head):
                hs["doc_head_has_despatch_number"] += 1
            if ft and len(head_examples[b]) < 6:
                head_examples[b].append((vol, d, head[:160]))

    # ---------------- cases for the one-reader read (10 per band per class)
    def fmt_case(rec, kind, texts_cache):
        vol, d, y, role, raw, s, e, union = rec
        if vol not in texts_cache:
            texts_cache.clear()
            texts_cache[vol] = ner_store.volume_text(TEXT, vol)
        t = texts_cache[vol].get(d, "")
        head = " ".join(t[:260].split())
        ctx = "" if s < 260 else " || ctx: ..." + " ".join(t[max(0, s - 90):e + 60].split()) + "..."
        sur = surname_of(text_of(raw))
        pc = sorted(pocom_by_surname.get(sur, ()))
        pl = []
        for slug in pc:
            inoff = any(a - 1 <= y <= b + 1 for a, b, _, _ in appts[slug])
            pl.append("%s%s: %s" % ("*" if inoff else " ", slug, "; ".join("%s %s %d-%d" % (r, w if w != r else "", a, b2) for a, b2, r, w in appts[slug])[:200]))
        others = []
        for ident, (inis, labels) in union.items():
            others.append("%s <- %s" % (ident, " | ".join(sorted(set(l[:140] for l in labels))[:3])))
        return ("[%s] %s/%s year=%d role=%s surface=%r\n  HEAD: %s%s\n  POCOM(same surname; * = in office y±1):\n    %s\n  UNION candidates in window (%d):\n    %s\n"
                % (kind, vol, d, y, role, text_of(raw), head, ctx, "\n    ".join(pl[:8]) + ("\n    ... %d more" % (len(pl) - 8) if len(pl) > 8 else ""),
                   len(union), "\n    ".join(others[:8]) + ("\n    ... %d more" % (len(others) - 8) if len(others) > 8 else "")))

    picks = []
    for band in sorted(several_cases):
        for kind, pool in (("SEVERAL", several_cases[band]), ("NOBODY", nobody_cases[band])):
            for rec in rnd.sample(pool, min(10, len(pool))):
                picks.append((band, kind, rec))
    picks.sort(key=lambda x: (x[1], x[0], x[2][0]))
    cache = {}
    with open(os.path.join(HERE, "cases.txt"), "w") as f:
        for n, (band, kind, rec) in enumerate(picks, 1):
            f.write("#%02d band=%s " % (n, band) + fmt_case(rec, kind, cache) + "\n")

    def tab(d):
        return {b: {s: dict(c) for s, c in v.items()} for b, v in sorted(d.items())}

    pooled = collections.defaultdict(collections.Counter)
    for b, v in bins.items():
        for s, c in v.items():
            pooled[s].update(c)
    out = {
        "generated_by": os.path.abspath(__file__),
        "population": "every marked from/to row in the 267 scope volumes with an m1a surname_of() surname and a TEI doc year",
        "window_rule": "candidate if any window [lo,hi] satisfies lo-1 <= year <= hi+1 (year = TEI frus:doc-dateTime-min). "
                       "POCOM windows = appointment spans (min..max of all <date> in the chief/principal block, m1a's rule). "
                       "Registry / authority index / persons-complete windows = life window (birth+18..death; one-sided: b+18..b+85 or d-65..d; INFERRED rule) "
                       "UNION manifest dateRange of every volume that lists the person. Live-index rollups = dateRange of member volumes. "
                       "Entities with no window are 'undated' and never counted as candidates (reported separately).",
        "surname_rule": "mention: m1a surname_of() then NFKD accent-strip + casefold. source: last token before first comma, else last non-suffix token; same fold. "
                        "POCOM keyed by LAST token of <surname> (so 'Van Buren' -> 'buren', matching surname_of); the verbatim exact-case rule is the positive control only.",
        "identity_rule_for_union": "HistoryAtState people-id where known (registry id; authority-index key; persons-complete people-id idno; rollup authority_id; POCOM slug via registry source-url or authority 's'); else source-local id.",
        "source_meta": meta,
        "positive_control_pocom_verbatim": {"pooled": dict(ctrl), "by_band": {b: dict(c) for b, c in sorted(ctrl_band.items())},
                                            "expected_from_pocom_json": {"fromto_rows": 235751, "with_surname": 235218, "known": 189613, "one": 130321, "nobody": 40563, "several": 18729}},
        "candidate_bins_by_band": tab(bins),
        "candidate_bins_pooled": {s: dict(c) for s, c in pooled.items()},
        "bins_after_given_initial_filter_rows_with_printed_initial_only": tab(initial_bins),
        "bins_before_given_initial_filter_same_rows": tab(initial_prefilter),
        "post_place_rule_by_band_and_pocom_class": {b: {k: dict(c) for k, c in v.items()} for b, v in sorted(rule.items())},
        "post_place_rule_definition": RULE_DEF,
        "surface_carries_given_initial_by_band": {b: dict(c) for b, c in sorted(surface_initial.items())},
        "union_bins_by_namekey_lower_bound": {b: dict(c) for b, c in sorted(namekey_bins.items())},
        "undated_surname_hits_when_zero_dated_candidates": {b: dict(v) for b, v in sorted(undated_hit.items())},
        "union_bin_given_pocom_class": {b: {k: dict(c) for k, c in v.items()} for b, v in sorted(union_given_pocom.items())},
        "decisions_not_single_union_candidate": {b: {k: len(s) for k, s in v.items()} for b, v in sorted(decisions.items())},
        "case_file": os.path.join(HERE, "cases.txt"),
    }
    json.dump(out, open(os.path.join(HERE, "candidates.json"), "w"), indent=1, sort_keys=True, ensure_ascii=False)
    hout = {"generated_by": os.path.abspath(__file__), "note_prefix_title": NOTE_PREFIX, "sample": "1,500 documents per band, random.Random(234), from the TEI-dated documents of the scope",
            "definitions": {
                "fromto_mentions_in_head": "marked from/to spans starting in the first 300 chars of the R-0 text",
                "with_post": "(a) span inside '( )' preceded (within 90 chars, after the last ' to ') by a post word; (b) a '( ... )' right after the span holding a post word; (c) a ', ...' appositive within 50 chars holding a post word. Post words: regex POST in the script.",
                "bare_honorific_only": "no post by (a)-(c) and the span is preceded by Mr./Señor/Sir/Baron/Count/M./Messrs",
                "office_only_correspondent": "head contains 'to|from the Secretary of State|Acting Secretary of State|President|Department of State' (the correspondent is an OFFICE, often unmarked)",
                "dateline_place": "regex '<Capitalised place> , <Month> <d>, <yyyy>' in the first 400 chars"},
            "by_band": {b: dict(c) for b, c in sorted(head_stats.items())},
            "examples": head_examples, "other_examples": other_examples}
    json.dump(hout, open(os.path.join(HERE, "head-evidence.json"), "w"), indent=1, sort_keys=True, ensure_ascii=False)
    print(json.dumps({"control": out["positive_control_pocom_verbatim"], "pooled": out["candidate_bins_pooled"]}, indent=1))


if __name__ == "__main__":
    main()
