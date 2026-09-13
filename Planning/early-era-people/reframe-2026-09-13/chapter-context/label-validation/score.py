#!/usr/bin/env python3
"""Score three identity rules against editor-asserted identities (from/to persName corresp -> list entry).

Rules (per linked from/to mention):
  S    surname-by-year: measure_pocom.load_pocom + surname_of VERBATIM (imported); doc year = TEI
       frus:doc-dateTime-min year; unique POCOM officeholder with that surname whose any-appointment
       year span covers year+-1 -> pick. Classes: unknown / nobody / one / several.
  CH   chapter rule alone: chapter country K = first section-path title whose GeoKeyNormalizer.keys().first
       is a diplomatic roll geo key (REAL Swift, lv classify); classifier categories at that title
       (REAL Swift) give direction -> post: diplomaticDespatches from=MISSION(K) to=DEPT;
       diplomaticInstructions(+notesTo) from=DEPT to=MISSION(K); notesFromForeignMissions to=DEPT;
       consularDespatches to=DEPT. MISSION(K) = POCOM missions-countries chiefs whose territory or
       contemporary-territory id normalises (REAL Swift) to K, in office on the date; prefer non-ad-interim;
       exactly one person -> pick. DEPT = POCOM `secretary` in office on the date; one -> pick. Name unread.
  COMB post holders (MISSION(K) any role / DEPT any positions-principals position) in office on the date
       whose POCOM surname matches the mention's trailing 1-3 tokens (letters only, casefolded); one -> pick.
Chapter variants: APP (raw titles, the app's behaviour), STRIP (title with a leading chapter number /
trailing '(Continued.)' removed before the real normaliser — a stated deviation), SHOWN (Source Explorer's
own shown classifications with rolls; year<1906 only).
Date = classifier datelineDateISO, else index date_iso, else TEI doc-dateTime-min.
In office: start = appointed|started, end = ended | next start in the same file | open; window
[start - before, end + after], primary (0, 60) days; sensitivity (0,0) and (365,365).
"""
import sys, json, re, datetime as dt, collections, random, math
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/Planning/early-era-people/feasibility-2026-09-12/measure-pocom")
import measure_pocom as M
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"

def D(s, end=False):
    if not s: return None
    p = s.split("-")
    try:
        y = int(p[0]); m = int(p[1]) if len(p) > 1 else (12 if end else 1)
        if len(p) > 2: d = int(p[2])
        else: d = (dt.date(y + (m == 12), m % 12 + 1, 1) - dt.timedelta(days=1)).day if end else 1
        return dt.date(y, m, d)
    except Exception: return None
def norm(s): return re.sub(r"[^a-z]", "", s.casefold())
def wilson(k, n, z=1.96):
    if n == 0: return None
    p = k / n; den = 1 + z * z / n; c = (p + z * z / (2 * n)) / den; h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return [round(p, 4), round(max(0, c - h), 4), round(min(1, c + h), 4)]
def lev1(a, b):
    if a == b: return True
    if abs(len(a) - len(b)) > 1: return False
    if len(a) == len(b): return sum(x != y for x, y in zip(a, b)) == 1 or any(a[:i] + a[i+1] + a[i] + a[i+2:] == b for i in range(len(a) - 1))
    s, l = (a, b) if len(a) < len(b) else (b, a)
    return any(l[:i] + l[i+1:] == s for i in range(len(l)))

# ---------------- POCOM
PC = json.load(open("pocom-posts.json")); people = PC["people"]
tk = json.load(open("pocom-territory-keys.json")); tk.pop("__vocabulary__")
def terr_key(x):
    if not x: return None
    k = tk.get(x.replace("-", " "), {}).get("keys") or []
    return k[0] if k else None
posts = PC["posts"]
byfile = collections.defaultdict(list)
for p in posts:
    p["s0"] = D(p["appointed"]) or D(p["started"]); p["e0"] = D(p["ended"], end=True)
    p["keys"] = {terr_key(p.get("territory")), terr_key(p.get("contemporary"))} - {None} if p["kind"] == "mission" else set()
    byfile[(p["file"], p.get("position"))].append(p)
for lst in byfile.values():
    lst.sort(key=lambda p: p["s0"] or dt.date(9999, 1, 1))
    for i, p in enumerate(lst):
        if p["e0"] is None and p["s0"]:
            nxt = next((q["s0"] for q in lst[i+1:] if q["s0"] and q["s0"] > p["s0"]), None)
            p["e1"] = nxt
        else: p["e1"] = p["e0"]
mission_by_key = collections.defaultdict(list)
for p in posts:
    for k in p["keys"]: mission_by_key[k].append(p)
principals = [p for p in posts if p["kind"] == "principal"]
def holders(cands, date, tol):
    b, a = tol
    return [p for p in cands if p["s0"] and p["s0"] - dt.timedelta(days=b) <= date and (p["e1"] is None or date <= p["e1"] + dt.timedelta(days=a))]
AD_INTERIM = {"charge-daffaires-ad-interim", "charge-daffaires-pro-tem"}
def surname_match(slug, mention):
    ps = norm(people.get(slug, {}).get("surname", ""))
    toks = [t for t in re.split(r"\s+", mention) if t]
    return bool(ps) and any(norm("".join(toks[-k:])) == ps for k in (1, 2, 3) if len(toks) >= k)

# ---------------- S rule (verbatim import)
surnames, spans, by_surname = M.load_pocom()
def rule_S(n, year):
    sur = M.surname_of(M.text_of(n))
    if not sur or sur not in by_surname: return "unknown", None
    if year is None: return "noyear", None
    live = [s for s in by_surname[sur] if any(a - 1 <= year <= b + 1 for a, b in spans[s])]
    return {0: "nobody", 1: "one"}.get(len(live), "several"), (live[0] if len(live) == 1 else None)

# ---------------- gold
man = json.load(open(REPO + "/FRUSExplorer/Resources/manifest.json")); man = man["volumes"] if isinstance(man, dict) else man
window = {v["volumeId"]: (int(v["dateRange"]["earliest"][:4]), int(v["dateRange"]["latest"][:4])) for v in man}
PAI = json.load(open(REPO + "/FRUSExplorer/Resources/person-authority-index.json"))
entries = {}
for l in open("gold-entries.jsonl"):
    e = json.loads(l); entries[(e["volume"], e["id"])] = e
HON = {"sir", "baron", "marquis", "count", "dr", "general", "colonel", "major", "commander", "captain", "admiral", "lord", "prince", "mr", "hon", "de", "von", "don", "señor"}
CHIEF_RE = re.compile(r"\b(ambassador|minister resident|envoy|charg[ée] d.affaires|minister (to|in|at)\b|agent and consul general|minister plenipotentiary|high commissioner)", re.I)
PRINC_RE = re.compile(r"\b(secretary of state|under secretary|assistant secretary|counselor (of|for) the department|counselor, department|chief clerk)", re.I)
FOREIGN_RE = re.compile(r"\bat washington\b|of (her|his) (britannic |imperial |royal )?majesty|of the (king|emperor|queen|sultan|french republic|belgians)|minister (for|of) foreign affairs|foreign (office|minister)|prime minister|\b(british|french|german|italian|japanese|chinese|russian|mexican|spanish|chilean|peruvian|bolivian|paraguayan|argentine|brazilian|colombian|ecuadoran|cuban|haitian|honduran|nicaraguan|salvadoran|guatemalan|costa rican|panamanian|venezuelan|uruguayan|dominican|canadian|austrian|hungarian|czechoslovak|polish|soviet|belgian|dutch|swiss|swedish|norwegian|danish|finnish|estonian|latvian|lithuanian|greek|turkish|albanian|bulgarian|rumanian|yugoslav|portuguese|irish|egyptian|persian|iranian|siamese|liberian|australian|indian|israeli|arab|syrian|lebanese|iraqi|saudi|korean|philippine|indonesian|thai|burmese|pakistani|afghan|ethiopian) (ambassador|minister|charg|counselor|secretary|consul|foreign|delegate|representative|chancellor|president|premier|high)", re.I)
def gold_name_parts(name):
    if "," in name:
        sur, fore = name.split(",", 1); toks_f = fore.split()
        surs = [sur.strip()]
    else:
        toks = [t for t in name.split() if norm(t) not in HON]
        surs = [" ".join(toks[-k:]) for k in (1, 2) if len(toks) >= k]; toks_f = toks[:-1]
    fi = next((norm(t)[:1] for t in toks_f if norm(t) and norm(t) not in HON), "")
    return [norm(s) for s in surs if norm(s)], fi
pocom_by_normsur = collections.defaultdict(set)
for s, p in people.items(): pocom_by_normsur[norm(p["surname"])].add(s)
held = collections.defaultdict(list)
for p in posts: held[p["person"]].append(p)
def gold_slug_B(e):
    text = (e["role"] or "") + " " + (e["heading"] or "")
    foreign = bool(FOREIGN_RE.search(e["role"] or ""))
    kind = "principal" if (PRINC_RE.search(e["role"] or "") or (e["heading"] or "").lower().startswith("department of state")) else ("mission" if CHIEF_RE.search(e["role"] or "") else None)
    info = {"foreign": foreign, "kind": kind}
    if foreign or not kind: return None, info
    surs, fi = gold_name_parts(e["name"])
    lo, hi = window[e["volume"]]
    cands = set()
    for gs in surs:
        for ps, slugs in pocom_by_normsur.items():
            if ps == gs or (len(gs) >= 5 and lev1(ps, gs)):
                for s in slugs:
                    pf = norm(people[s]["forename"])[:1]
                    if fi and pf and fi != pf: continue
                    if any(p["kind"] == kind and p["s0"] and p["s0"].year <= hi + 1 and (p["e1"] is None or p["e1"].year >= lo - 1) for p in held[s]):
                        cands.add(s)
    info["candidates"] = sorted(cands)
    return (next(iter(cands)) if len(cands) == 1 else None), info
def gold_slug_A(v, ref):
    cid = PAI["crosswalk"].get(v, {}).get(ref)
    return (PAI["authority"].get(str(cid), {}).get("s") if cid else None), cid

# ---------------- classified documents
CL = {}
for l in open("classified-list-volumes.jsonl"):
    r = json.loads(l); CL[(r["volume"], r["d"])] = r
def chapter(r, variant):
    if variant == "SHOWN":
        if not r["shown"]: return None, []
        return r["path"][r["shownChosenIndex"]], [c["category"] for c in r["shown"]]
    fs, cl = ("firstServed", "classify") if variant == "APP" else ("firstServedStripped", "classifyStripped")
    for t in r["titles"]:
        if t[fs]:
            key = (t["keys"] if variant == "APP" else t["keysStripped"])[0]
            return key, [c["category"] for c in t.get(cl, [])]
    return None, []
def shown_key(r):
    for c in r["shown"]:
        if c["geoKeys"] and c["category"] != "consularDespatches": return c["geoKeys"][0]
    return None
def hypothesis(cats, direction):
    if "diplomaticDespatches" in cats: return "MISSION" if direction == "from" else "DEPT"
    if "diplomaticInstructions" in cats: return "DEPT" if direction == "from" else "MISSION"
    if "notesFromForeignMissions" in cats or "consularDespatches" in cats: return "DEPT" if direction == "to" else None
    return None

def apply_chapter_rules(r, m, variant, tol):
    key, cats = chapter(r, variant)
    if variant == "SHOWN": key = shown_key(r)
    if variant != "SHOWN" and key is None: return {"key": None}
    if variant == "SHOWN" and not cats: return {"key": None}
    side = hypothesis(cats, m["t"])
    date = D(r["datelineDateISO"]) or D((r["date_iso"] or "")[:10]) or D(m["tei_date"])
    out = {"key": key, "cats": cats, "side": side, "date": str(date) if date else None}
    if side is None or date is None: return out
    if side == "MISSION":
        if not key: return out
        h = holders(mission_by_key.get(key, []), date, tol)
        pers = {p["person"] for p in h}
        full = {p["person"] for p in h if p["role"] not in AD_INTERIM}
        pool = full if full else pers
        out["CH"] = next(iter(pool)) if len(pool) == 1 else None
        out["CH_n"] = len(pool)
    else:
        h = holders(principals, date, tol)
        sec = {p["person"] for p in h if p["position"] == "secretary"}
        out["CH"] = next(iter(sec)) if len(sec) == 1 else None
        out["CH_n"] = len(sec)
        pers = {p["person"] for p in h}
    comb = {s for s in pers if surname_match(s, m["n"])}
    out["COMB"] = next(iter(comb)) if len(comb) == 1 else None
    out["COMB_n"] = len(comb)
    return out

def judge(pick, gold):
    if pick is None: return None
    if gold["slug"]: return "agree" if pick == gold["slug"] else "disagree"
    if gold["foreign"]: return "disagree"
    gs, gfi = gold["surs"], gold["fi"]
    ps = norm(people.get(pick, {}).get("surname", ""))
    if not any(ps == g or (len(g) >= 5 and lev1(ps, g)) for g in gs): return "disagree"
    pf = norm(people.get(pick, {}).get("forename", ""))[:1]
    if gfi and pf and gfi != pf: return "disagree"
    return "undecided"

TOLS = {"primary(0,60d)": (0, 60), "exact(0,0)": (0, 0), "wide(365,365)": (365, 365)}
rows = []
gold_cache = {}
for l in open("gold-mentions.jsonl"):
    m = json.loads(l)
    if not m["linked"]: continue
    v = m["v"]
    if (v, m["link"]) not in gold_cache:
        e = entries[(v, m["link"])]
        sA, cid = gold_slug_A(v, m["link"]); sB, info = gold_slug_B(e)
        surs, fi = gold_name_parts(e["name"])
        gold_cache[(v, m["link"])] = {"entry": e, "slugA": sA, "cid": cid, "slugB": sB, "B": info,
            "slug": sA or sB, "route": "A" if sA else ("B" if sB else None), "foreign": info["foreign"], "surs": surs, "fi": fi}
    g = gold_cache[(v, m["link"])]
    r = CL.get((v, m["d"]))
    year = int(m["tei_date"][:4]) if m["tei_date"] else None
    sclass, spick = rule_S(m["n"], year)
    row = {"v": v, "d": m["d"], "t": m["t"], "n": m["n"], "link": m["link"], "gold_slug": g["slug"], "gold_route": g["route"],
           "gold_name": g["entry"]["name"], "gold_role": g["entry"]["role"], "gold_heading": g["entry"]["heading"], "gold_foreign": g["foreign"],
           "in_index": r is not None, "pos": "head" if m.get("in_doc_head") else "enclosure/body", "S_class": sclass, "S": spick, "S_j": judge(spick, g)}
    if r:
        row["header"] = r["header"]; row["dateline"] = r["dateline"]; row["path"] = r["path"]
        for var in ("APP", "STRIP", "SHOWN"):
            for tn, tol in TOLS.items():
                o = apply_chapter_rules(r, m, var, tol)
                o["CH_j"] = judge(o.get("CH"), g); o["COMB_j"] = judge(o.get("COMB"), g)
                row[f"{var}|{tn}"] = o
    rows.append(row)
with open("scored-mentions.jsonl", "w") as f:
    for r in rows: f.write(json.dumps(r, default=str) + "\n")

# ---------------- tables
PRE = {"frus1873p1v1", "frus1873p1v2"}
def tally(rs, getj):
    c = collections.Counter(getj(r) for r in rs)
    n = len(rs); picks = c["agree"] + c["disagree"] + c["undecided"]
    dec = c["agree"] + c["disagree"]
    return {"linked": n, "picks": picks, "agree": c["agree"], "disagree": c["disagree"], "undecided": c["undecided"],
            "precision_excl_undecided": wilson(c["agree"], dec), "precision_undecided_as_wrong": wilson(c["agree"], picks),
            "precision_undecided_as_right": wilson(c["agree"] + c["undecided"], picks), "coverage": wilson(picks, n)}
def rule_getter(var, tn, rule):
    return lambda r: (r.get(f"{var}|{tn}") or {}).get(f"{rule}_j")
report = {"definitions": __doc__, "tolerances": TOLS}
vols = sorted({r["v"] for r in rows})
def block(rs):
    b = {"S": tally(rs, lambda r: r["S_j"])}
    for var in ("APP", "STRIP", "SHOWN"):
        for tn in TOLS:
            for rule in ("CH", "COMB"):
                b[f"{rule}|{var}|{tn}"] = tally(rs, rule_getter(var, tn, rule))
    return b
report["per_volume"] = {v: block([r for r in rows if r["v"] == v]) for v in vols}
chapter_vols = [v for v in vols if any((r.get("APP|primary(0,60d)") or {}).get("key") for r in rows if r["v"] == v)]
strip_vols = [v for v in vols if any((r.get("STRIP|primary(0,60d)") or {}).get("key") for r in rows if r["v"] == v)]
report["chapter_bearing_volumes_APP"] = chapter_vols
report["chapter_bearing_volumes_STRIP"] = strip_vols
report["pooled_pre1900_1873"] = block([r for r in rows if r["v"] in PRE])
proxy = [r for r in rows if r["v"] not in PRE and r["v"] in strip_vols]
report["pooled_post1905_proxy_chapter_volumes"] = block(proxy)
report["pooled_post1905_all_list_volumes"] = block([r for r in rows if r["v"] not in PRE])
report["pooled_pre1900_1873_DOCHEAD_ONLY"] = block([r for r in rows if r["v"] in PRE and r["pos"] == "head"])
report["pooled_pre1900_1873_ENCLOSURE_ONLY"] = block([r for r in rows if r["v"] in PRE and r["pos"] != "head"])
report["pooled_post1905_proxy_DOCHEAD_ONLY"] = block([r for r in rows if r["v"] not in PRE and r["v"] in strip_vols and r["pos"] == "head"])
report["position_counts"] = {str(k): n for k, n in collections.Counter(("pre1900" if r["v"] in PRE else "post1905", r["pos"]) for r in rows).items()}
# by S class and by side, primary tolerance, STRIP and APP
def by(rs, keyf):
    out = {}
    for k in sorted({keyf(r) for r in rs}, key=str):
        sub = [r for r in rs if keyf(r) == k]
        out[str(k)] = {"S": tally(sub, lambda r: r["S_j"]),
                       **{f"{rule}|{var}": tally(sub, rule_getter(var, "primary(0,60d)", rule)) for var in ("APP", "STRIP") for rule in ("CH", "COMB")}}
    return out
for label, rs in (("pre1900_1873", [r for r in rows if r["v"] in PRE]), ("post1905_proxy", proxy),
                  ("pre1900_1873_DOCHEAD", [r for r in rows if r["v"] in PRE and r["pos"] == "head"]),
                  ("post1905_proxy_DOCHEAD", [r for r in proxy if r["pos"] == "head"])):
    report[f"by_S_class_{label}"] = by(rs, lambda r: r["S_class"])
    report[f"by_side_STRIP_{label}"] = by(rs, lambda r: (r.get("STRIP|primary(0,60d)") or {}).get("side"))
    report[f"by_gold_route_{label}"] = by(rs, lambda r: r["gold_route"] or ("foreign" if r["gold_foreign"] else "no-slug"))
    report[f"by_direction_{label}"] = by(rs, lambda r: r["t"])
# gold routes
gr = collections.Counter()
for (v, ref), g in gold_cache.items():
    gr[("pre1900" if v in PRE else "post1905", g["route"] or ("foreign" if g["foreign"] else "no-slug"))] += 1
    if g["slugA"] and g["slugB"]: gr[("A_and_B_both", g["slugA"] == g["slugB"])] += 1
report["gold_entries_by_route"] = {str(k): n for k, n in gr.items()}
mr = collections.Counter()
for r in rows: mr[("pre1900" if r["v"] in PRE else "post1905", r["gold_route"] or ("foreign" if r["gold_foreign"] else "no-slug"))] += 1
report["gold_mentions_by_route"] = {str(k): n for k, n in mr.items()}
report["mentions_not_in_index"] = sum(1 for r in rows if not r["in_index"])
json.dump(report, open("score.json", "w"), indent=1, default=str)

with open("gold-slug-table.tsv", "w") as f:
    f.write("volume\tref\tname\trole\theading\tcrosswalk_id\tslugA\tslugB\tB_kind\tB_foreign\tB_candidates\n")
    for (v, ref), g in sorted(gold_cache.items()):
        f.write("\t".join(map(str, [v, ref, g["entry"]["name"], g["entry"]["role"], g["entry"]["heading"], g["cid"], g["slugA"], g["slugB"], g["B"]["kind"], g["B"]["foreign"], g["B"].get("candidates")])) + "\n")
def fmt(r, keys):
    return "%s/%s %s[%s] '%s' | gold: %s — %s [%s] slug=%s route=%s | dateline: %s | path: %s | %s" % (
        r["v"], r["d"], r["t"], r["pos"], r["n"], r["gold_name"], r["gold_role"][:90], r["gold_heading"], r["gold_slug"], r["gold_route"],
        (r.get("dateline") or "")[:70], " > ".join(p[:30] for p in r.get("path", [])), " ; ".join(keys))
def dis_keys(r):
    ks = []
    if r["S_j"] in ("disagree", "undecided"): ks.append(f"S[{r['S_class']}]={r['S']}:{r['S_j']}")
    for var in ("APP", "STRIP", "SHOWN"):
        o = r.get(f"{var}|primary(0,60d)") or {}
        for rule in ("CH", "COMB"):
            if o.get(f"{rule}_j") in ("disagree", "undecided"): ks.append(f"{rule}/{var}(K={o.get('key')},side={o.get('side')})={o.get(rule)}:{o.get(rule+'_j')}")
    return ks
with open("disagreements-1873.txt", "w") as f:
    for r in rows:
        if r["v"] in PRE and dis_keys(r): f.write(fmt(r, dis_keys(r)) + "\n")
others = [r for r in rows if r["v"] not in PRE and dis_keys(r)]
random.Random(234).shuffle(others)
with open("disagreements-sample20-post1905.txt", "w") as f:
    f.write(f"# {len(others)} post-1905 mentions with any disagreement/undecided; 20 sampled with seed 234\n")
    for r in others[:20]: f.write(fmt(r, dis_keys(r)) + "\n")
print(json.dumps({k: report[k] for k in ("gold_entries_by_route", "gold_mentions_by_route", "mentions_not_in_index", "chapter_bearing_volumes_APP", "chapter_bearing_volumes_STRIP")}, indent=1))
