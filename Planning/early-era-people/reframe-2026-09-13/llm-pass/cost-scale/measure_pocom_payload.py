#!/usr/bin/env python3
"""Shape C inputs: per (volume, K2 surface) row — mentions, POCOM in-window candidates, and the
characters needed to describe each candidate. Reuses measure_pocom.py's k2_surface, surname_of,
text_of, load_windows, live-window rule (±1) by import. Read-only. Writes pocom-payload.json here."""
import os, sys, re, glob, json, collections, statistics
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, REPO + "/tools/semantic-harvest")
sys.path.insert(0, REPO + "/Planning/early-era-people/feasibility-2026-09-12/measure-pocom")
import ner_store
import measure_pocom as mp
HERE = os.path.dirname(os.path.abspath(__file__))
POCOM = "/Users/jbotts/Development/pocom"
H = os.path.expanduser

def collapse(s): return " ".join(s.split())
def humanize(slug): return re.sub(r"-\d{4}$", "", slug or "").replace("-", " ").title()

# labels
labels = {}
for p in glob.glob(POCOM + "/roles-country-chiefs/*.xml") + glob.glob(POCOM + "/positions-principals/*.xml"):
    t = open(p, encoding="utf-8", errors="replace").read()
    i = re.search(r"<id>([^<]+)</id>", t); s = re.search(r"<singular>(.*?)</singular>", t, re.S)
    if i and s: labels[i.group(1)] = collapse(s.group(1))
people = {}
for p in sorted(glob.glob(POCOM + "/people/*/*.xml")):
    t = open(p, encoding="utf-8", errors="replace").read()
    sid = re.search(r"<id>([^<]+)</id>", t); sur = re.search(r"<surname>([^<]*)</surname>", t)
    fore = re.search(r"<forename>([^<]*)</forename>", t); gen = re.search(r"<genname>([^<]*)</genname>", t)
    b = re.search(r"<birth>([^<]*)</birth>", t); d = re.search(r"<death>([^<]*)</death>", t)
    if sid and sur and sur.group(1).strip():
        people[sid.group(1)] = dict(sur=sur.group(1).strip(), fore=(fore.group(1).strip() if fore else ""),
                                    gen=(gen.group(1).strip() if gen else ""), birth=(b.group(1) if b else ""), death=(d.group(1) if d else ""))
appts = collections.defaultdict(list)
for path in sorted(glob.glob(POCOM + "/missions-*/*.xml")) + sorted(glob.glob(POCOM + "/positions-principals/*.xml")):
    t = open(path, encoding="utf-8", errors="replace").read()
    place = re.search(r"<territory-id>([^<]+)</territory-id>", t) or re.search(r"<id>([^<]+)</id>", t)
    for blk in re.findall(r"<(?:chief|principal)>.*?</(?:chief|principal)>", t, re.S):
        pid = re.search(r"<person-id>([^<]+)</person-id>", blk)
        if not pid: continue
        years = [int(y) for y in re.findall(r"<date>(\d{4})", blk)]
        if not years: continue
        role = re.search(r"<role-title-id>([^<]+)</role-title-id>", blk)
        rid = role.group(1) if role else ""
        rl = labels.get(rid, humanize(rid))
        where = "" if "positions-principals" in path else ", " + humanize(place.group(1) if place else "")
        appts[pid.group(1)].append((min(years), max(years), "%s%s, %d–%d" % (rl, where, min(years), max(years))))
by_cf = collections.defaultdict(set)
for slug, pe in people.items():
    if slug in appts: by_cf[pe["sur"].casefold()].add(slug)

def head(slug):
    pe = people[slug]
    nm = collapse("%s %s %s" % (pe["fore"], pe["sur"], pe["gen"]))
    return "%s [%s] (%s–%s)" % (nm, slug, pe["birth"], pe["death"])

windows = mp.load_windows()
def pct(xs, q):
    xs = sorted(xs); return xs[min(len(xs) - 1, int(q * len(xs)))] if xs else 0

def tally(rowmap):
    cand_n, desc_win, desc_all, ments, unknown = [], [], [], [], 0
    zero = one = several = 0
    for (v, key), (stripped, n) in rowmap.items():
        lo, hi = windows[v]
        ments.append(n)
        sur = mp.surname_of(stripped)
        cands = by_cf.get(sur.casefold(), set()) if sur else set()
        if not cands: unknown += 1
        live = [s for s in cands if any(a - 1 <= hi and lo <= b + 1 for a, b, _ in appts[s])]
        cand_n.append(len(live))
        if len(live) == 0: zero += 1
        elif len(live) == 1: one += 1
        else: several += 1
        cw = ca = 0
        for s in live:
            h = len(head(s)) + 1
            cw += h + sum(len(x) + 2 for a, b, x in appts[s] if a - 1 <= hi and lo <= b + 1)
            ca += h + sum(len(x) + 2 for a, b, x in appts[s])
        desc_win.append(cw); desc_all.append(ca)
    R = len(cand_n)
    def dist(xs):
        return {"sum": sum(xs), "mean": round(sum(xs) / R, 3), "p50": pct(xs, .5), "p90": pct(xs, .9), "p99": pct(xs, .99), "max": max(xs)}
    return {"rows": R, "surname_unknown_rows": unknown, "rows_0_live": zero, "rows_1_live": one, "rows_several_live": several,
            "live_candidates": dist(cand_n), "desc_chars_in_window_appts": dist(desc_win), "desc_chars_all_appts": dist(desc_all),
            "mentions_per_row": dist(ments),
            "snippets_cap3": sum(min(3, m) for m in ments), "snippets_cap5": sum(min(5, m) for m in ments)}

vols = ner_store.scope_volumes(H("~/frus-ner-raw"))
marked, union = {}, {}
for v in vols:
    for r in ner_store.volume_layer(H("~/frus-ner-raw"), "marked", v):
        key, st = mp.k2_surface(mp.text_of(r["n"]))
        if not key: continue
        e = marked.setdefault((v, key), [st, 0]); e[1] += 1
        e = union.setdefault((v, key), [st, 0]); e[1] += 1
    for r in ner_store.volume_layer(H("~/frus-ner-raw-control-filtered"), "detected", v):
        key, st = mp.k2_surface(mp.text_of(r["n"]))
        if not key: continue
        e = union.setdefault((v, key), [st, 0]); e[1] += 1
res = {"note": "rows = (volume, measure_pocom.k2_surface) ; live = POCOM officeholder with any appointment overlapping the volume manifest window ±1 (measure_pocom rule); candidate description = 'Forename Surname [slug] (birth–death)' + each appointment 'Role, Territory, YYYY–YYYY'",
       "pocom_people_with_appointments": sum(1 for s in people if s in appts),
       "marked": tally({k: tuple(v) for k, v in marked.items()}),
       "marked_union_filtered_control": tally({k: tuple(v) for k, v in union.items()})}
ex = sorted(((len(by_cf.get(s,())), s) for s in by_cf), reverse=True)[:10]
res["most_shared_surnames"] = ex
res["example_descriptions"] = [head(s) + " " + "; ".join(x for _, _, x in appts[s]) for s in sorted(by_cf.get("seward", []))][:4]
json.dump(res, open(os.path.join(HERE, "pocom-payload.json"), "w"), indent=1, ensure_ascii=False)
print(json.dumps(res, indent=1, ensure_ascii=False)[:4000])
