#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Refresh `PersonAuthorityIndexGenerator/wikidata-snapshot.json`: the Wikidata facts the person
authority's identifier rule reads (#1767, item 1; `Planning/Person-Authority-Identifier-Assessment-2026-10-17.md`
§7.4).

`PersonAuthorityIndexGenerator` stamps an overlay entry's Wikidata and VIAF ids on a registry record only
where the item fits the record and something independent agrees (`PersonIdentifierRule`). It reads the
items from this snapshot, so the generator itself never goes to the network and a run is reproducible.
This tool writes the snapshot. It collects every Wikidata and VIAF id an overlay entry can bring to a
registry record (an entry carrying the people-id of a registry record with a FRUS anchor), and the VIAF
ids those records already carry; asks query.wikidata.org which items hold each VIAF id; fetches every
such item, and every item the overlay names, from the Wikidata API; and fetches the labels of the
family names, positions, occupations and employers their claims point to. What it writes is facts
derived from those answers, one item to a line:

    human        the item is an instance of human (P31 Q5), at any rank
    names        every name the item offers: its en and mul labels and aliases, its English Wikipedia
                 title without a closing parenthesis, its birth name, native-language name, pseudonym
                 and nickname (P1477, P1559, P742, P1449), and the labels of its family names (P734)
    born, died   the years of P569 and P570 given to a year or finer, preferred rank first, else every
                 rank but deprecated
    viaf         its VIAF ids (P214), at any rank
    description  its English description
    roles        the labels of its positions held, occupations and employers (P39, P106, P108)
    redirect     the item the requested id redirects to, whose facts these are
    missing      the id names no item (deleted)

and, for every VIAF id collected, the items that hold it (`viafHolders`, an empty list when none does;
holders whose every P214 statement is deprecated are listed apart in `viafDeprecatedHolders`).

The tool refuses to write, printing NOT WRITTEN and exiting 1, when an id it collected is left without
facts: an item the API did not answer for, or a VIAF id no query answered. The generator refuses in turn
when an overlay id it would stamp has no facts here, so a new overlay drop forces a refresh rather than
passing unread.

Standard library only. Requests go out at about one a second to the Wikidata API (40 items a call, its
labels 50 a call) and once a minute to query.wikidata.org, which rate-limits this client to one request
a minute (1,500 VIAF ids a query). Answers are cached under CACHE_DIR, so a run that stops resumes
where it stopped; remove the cache to fetch afresh.

    PERSONS_COMPLETE   required: frus-name-authority's 4_Outputs/persons-complete.xml
    PEOPLE_DATA_DIR    required: the data/ directory of a HistoryAtState/people checkout
    OUTPUT_PATH        default PersonAuthorityIndexGenerator/wikidata-snapshot.json
    CACHE_DIR          default .cache/wikidata-snapshot (gitignored)
    FETCHED_DATE       the date stamped into the snapshot (default today, UTC)

Run it from the project root:

    PERSONS_COMPLETE=~/Development/frus-name-authority/4_Outputs/persons-complete.xml \
    PEOPLE_DATA_DIR=~/Development/people/data \
      python3 -I tools/person-authority-facts/refresh_wikidata_snapshot.py

Version history:
  1.0 — #1767 lane B: initial implementation, from the identifier assessment's fetchers of 2026-10-17
"""
import datetime
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

UA = "FRUSExplorer-AuthorityFacts/1.0 (https://github.com/joshbotts/FRUS-Explorer)"
API = "https://www.wikidata.org/w/api.php"
SPARQL = "https://query.wikidata.org/sparql"
ITEM_BATCH = 40
LABEL_BATCH = 50
SPARQL_BATCH = 1500
NAME_CLAIMS = ("P1477", "P1559", "P742", "P1449")
ROLE_CLAIMS = ("P39", "P106", "P108")
LABELLED_CLAIMS = ("P734",) + ROLE_CLAIMS
ABOUT = (
    "Wikidata facts (CC0) for the overlay identifiers PersonAuthorityIndexGenerator tests before it stamps "
    "them (#1767; Planning/Person-Authority-Identifier-Assessment-2026-10-17.md). Written by "
    "tools/person-authority-facts/refresh_wikidata_snapshot.py, never by hand; its docstring says what "
    "each field holds."
)


def log(msg):
    print(datetime.datetime.now().strftime("%H:%M:%S"), msg, flush=True)


# ---- the inputs --------------------------------------------------------------------------------------

FRUS_ANCHOR = re.compile(r"historicaldocuments/frus[^/<]+/persons#")
RECORD_ID = re.compile(r"<id>\s*(\d+)\s*</id>")
REGISTRY_VIAF = re.compile(r'<authority service="viaf">\s*([^<]*?)\s*</authority>')
IDNO = re.compile(r"<idno([^>]*)>(.*?)</idno>", re.S)
TYPE_ATTR = re.compile(r'type="([^"]*)"')


def read_registry(data_dir):
    """(people-ids of the records with a FRUS anchor, {people-id: the record's VIAF id})."""
    anchored, viaf = set(), {}
    for root, _, files in os.walk(data_dir):
        for name in files:
            if not name.endswith(".xml"):
                continue
            text = open(os.path.join(root, name), encoding="utf-8").read()
            m = RECORD_ID.search(text)
            if not m:
                continue
            pid = str(int(m.group(1)))
            if FRUS_ANCHOR.search(text):
                anchored.add(pid)
            v = REGISTRY_VIAF.search(text)
            if v and v.group(1):
                viaf[pid] = v.group(1)
    return anchored, viaf


def overlay_entries(path):
    """(people-ids, Wikidata ids, VIAF ids) of each entry, as PersonsCompleteOverlay splits the file.

    Every bare `Wikidata` and `VIAF` idno is taken, where the generator reads the first of each: a
    superset, so that no id the generator reads goes unfetched.
    """
    xml = open(path, encoding="utf-8").read()
    pos = 0
    while True:
        a = xml.find("<person ", pos)
        if a < 0:
            a = xml.find("<person>", pos)
        if a < 0:
            return
        b = xml.find("</person>", a)
        chunk = xml[a:b if b >= 0 else len(xml)]
        pos = b + len("</person>") if b >= 0 else len(xml)
        idnos = []
        for attrs, value in IDNO.findall(chunk):
            t = TYPE_ATTR.search(attrs)
            if t:
                idnos.append((t.group(1).lower(), value.strip()))
        yield ([v for t, v in idnos if t == "people-id" and v],
               [v for t, v in idnos if t == "wikidata" and v],
               [v for t, v in idnos if t == "viaf" and v])


def collect(persons_complete, people_dir):
    anchored, registry_viaf = read_registry(people_dir)
    wikidata, viaf, reached = set(), set(), set()
    for people_ids, wd, vf in overlay_entries(persons_complete):
        known = [p for p in people_ids if p in anchored]
        if not known:
            continue
        reached.update(known)
        wikidata.update(wd)
        viaf.update(vf)
    viaf.update(registry_viaf[p] for p in reached if p in registry_viaf)
    odd = sorted(q for q in wikidata if not re.fullmatch(r"Q\d+", q))
    if odd:
        raise SystemExit(f"NOT WRITTEN: {len(odd)} overlay Wikidata ids are not of the form Q123: {odd[:10]}")
    return sorted(wikidata, key=lambda q: int(q[1:])), sorted(viaf, key=viaf_key), len(reached)


def viaf_key(v):
    return (0, int(v), v) if v.isdigit() else (1, 0, v)


# ---- the network, cached ----------------------------------------------------------------------------

def fetch_json(url, data=None, headers=None, tries=12, wait_first=5):
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, data=data, headers={"User-Agent": UA, **(headers or {})})
            with urllib.request.urlopen(req, timeout=300) as resp:
                body = json.load(resp)
            if isinstance(body, dict) and "error" in body:
                raise RuntimeError("API error " + json.dumps(body["error"])[:300])
            return body
        except urllib.error.HTTPError as exc:
            retry = exc.headers.get("Retry-After") if exc.headers else None
            wait = int(retry) + 5 if retry and retry.isdigit() else wait_first + 10 * attempt
            log(f"HTTP {exc.code}; retry {attempt + 1} in {wait}s")
            time.sleep(wait)
        except (urllib.error.URLError, TimeoutError, ConnectionError, RuntimeError, json.JSONDecodeError) as exc:
            wait = wait_first + 10 * attempt
            log(f"{str(exc)[:200]}; retry {attempt + 1} in {wait}s")
            time.sleep(wait)
    return None


class Cache:
    """One JSON file a key, under CACHE_DIR/<kind>/."""

    def __init__(self, root, kind):
        self.dir = os.path.join(root, kind)
        os.makedirs(self.dir, exist_ok=True)

    def path(self, key):
        return os.path.join(self.dir, hashlib.sha256(key.encode()).hexdigest()[:24] + ".json")

    def get(self, key):
        p = self.path(key)
        return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else None

    def put(self, key, value):
        p = self.path(key)
        tmp = p + ".tmp"
        json.dump(value, open(tmp, "w", encoding="utf-8"), ensure_ascii=False)
        os.replace(tmp, p)


def viaf_holders(viaf_ids, cache):
    """{viaf: [[item, rank], …]} for every VIAF id, an empty list when no item holds it; None on failure."""
    out, last_query = {}, None
    for n in range(0, len(viaf_ids), SPARQL_BATCH):
        batch = viaf_ids[n:n + SPARQL_BATCH]
        key = "sparql-p214|" + "|".join(batch)
        rows = cache.get(key)
        if rows is None:
            if last_query is not None:
                time.sleep(max(0, 65 - (time.time() - last_query)))
            values = " ".join('"%s"' % v for v in batch)
            query = ("SELECT ?viaf ?item ?rank WHERE { VALUES ?viaf { %s } "
                     "?item p:P214 ?st . ?st ps:P214 ?viaf ; wikibase:rank ?rank . }" % values)
            body = fetch_json(SPARQL, data=urllib.parse.urlencode({"query": query}).encode(), headers={
                "Accept": "application/sparql-results+json",
                "Content-Type": "application/x-www-form-urlencoded"}, tries=8, wait_first=65)
            last_query = time.time()
            if body is None:
                return None
            rows = [[r["viaf"]["value"], r["item"]["value"].rsplit("/", 1)[-1], r["rank"]["value"].rsplit("#", 1)[-1]]
                    for r in body["results"]["bindings"]]
            cache.put(key, rows)
        for v in batch:
            out.setdefault(v, [])
        for v, item, rank in rows:
            if [item, rank] not in out[v]:
                out[v].append([item, rank])
        log(f"VIAF holders: {min(n + SPARQL_BATCH, len(viaf_ids))}/{len(viaf_ids)} ids, {len(rows)} statements")
    return out


def entities(ids, cache, props, batch_size, kind):
    """{requested id: entity JSON, or {"missing": ""}}, through redirects; ids left out on failure."""
    out = {}
    todo = []
    for q in ids:
        hit = cache.get(f"{kind}|{q}")
        if hit is None:
            todo.append(q)
        else:
            out[q] = hit
    log(f"{kind}: {len(ids)} ids, {len(ids) - len(todo)} cached, {len(todo)} to fetch")
    for n in range(0, len(todo), batch_size):
        batch = todo[n:n + batch_size]
        params = {"action": "wbgetentities", "ids": "|".join(batch), "props": props,
                  "languages": "en|mul", "format": "json"}
        if "sitelinks" in props:
            params["sitefilter"] = "enwiki"
        body = fetch_json(API + "?" + urllib.parse.urlencode(params), headers={"Accept": "application/json"})
        if body is None:
            log(f"{kind}: gave up on a batch of {len(batch)}")
            continue
        by_request = {}
        for key, ent in body.get("entities", {}).items():
            by_request[(ent.get("redirects") or {}).get("from") or key] = ent
        for q in batch:
            ent = by_request.get(q)
            if ent is None:
                continue
            cache.put(f"{kind}|{q}", ent)
            out[q] = ent
        if (n // batch_size) % 20 == 0 or n + batch_size >= len(todo):
            log(f"{kind}: {min(n + batch_size, len(todo))}/{len(todo)}")
        time.sleep(1.0)
    return out


# ---- the facts --------------------------------------------------------------------------------------

def snak_value(snak):
    if snak.get("snaktype") != "value":
        return None
    dv = snak["datavalue"]
    v = dv["value"]
    if dv["type"] == "wikibase-entityid":
        return v.get("id") or ("Q%d" % v["numeric-id"])
    if dv["type"] == "time":
        return {"t": v["time"], "p": v["precision"]}
    if dv["type"] == "monolingualtext":
        return {"text": v["text"]}
    return v


def claims(entity, prop):
    """[(value, rank)] of a property's statements, in the item's order."""
    return [(snak_value(st["mainsnak"]), st.get("rank", "normal")) for st in entity.get("claims", {}).get(prop, [])]


def year_of(value):
    """A time value's year, when it is given to a year or finer."""
    if not isinstance(value, dict) or value.get("p", 0) < 9:
        return None
    m = re.match(r"([+-])(\d+)-", value["t"])
    if not m:
        return None
    return -int(m.group(2)) if m.group(1) == "-" else int(m.group(2))


def years(entity, prop):
    rows = claims(entity, prop)
    preferred = [v for v, rank in rows if rank == "preferred"]
    use = preferred or [v for v, rank in rows if rank != "deprecated"]
    return [y for y in (year_of(v) for v in use) if y is not None]


def unique(values):
    seen, out = set(), []
    for v in values:
        if v and v not in seen:
            seen.add(v)
            out.append(v)
    return out


def facts(entity, labels):
    if "missing" in entity:
        return {"missing": True}
    out = {}
    names = []
    for lang in ("en", "mul"):
        label = entity.get("labels", {}).get(lang, {}).get("value")
        if label:
            names.append(label)
        names.extend(a["value"] for a in entity.get("aliases", {}).get(lang, []))
    enwiki = entity.get("sitelinks", {}).get("enwiki", {}).get("title")
    if enwiki:
        names.append(re.sub(r"\s*\(.*?\)\s*$", "", enwiki))
    for prop in NAME_CLAIMS:
        names.extend(v["text"] for v, _ in claims(entity, prop) if isinstance(v, dict) and "text" in v)
    names.extend(labels.get(v, "") for v, _ in claims(entity, "P734") if isinstance(v, str))
    out["names"] = unique(names)
    out["human"] = any(v == "Q5" for v, _ in claims(entity, "P31"))
    born, died = years(entity, "P569"), years(entity, "P570")
    if born:
        out["born"] = born
    if died:
        out["died"] = died
    viaf = unique(v for v, _ in claims(entity, "P214") if isinstance(v, str))
    if viaf:
        out["viaf"] = viaf
    description = entity.get("descriptions", {}).get("en", {}).get("value")
    if description:
        out["description"] = description
    roles = unique(labels.get(v, "") for prop in ROLE_CLAIMS for v, _ in claims(entity, prop) if isinstance(v, str))
    if roles:
        out["roles"] = roles
    return out


def write_snapshot(path, snapshot):
    """One item, and one VIAF id, to a line: a refresh's diff reads item by item."""
    def dumps(value):
        return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))

    def block(mapping, key):
        return ",\n".join(f"{dumps(k)}:{dumps(mapping[k])}" for k in sorted(mapping, key=key))

    item_key = lambda q: int(q[1:])
    text = "{\n" + ",\n".join([
        f'"about":{dumps(snapshot["about"])}',
        f'"counts":{dumps(snapshot["counts"])}',
        f'"fetched":{dumps(snapshot["fetched"])}',
        '"items":{\n' + block(snapshot["items"], item_key) + "\n}",
        f'"personsComplete":{dumps(snapshot["personsComplete"])}',
        '"viafDeprecatedHolders":{\n' + block(snapshot["viafDeprecatedHolders"], viaf_key) + "\n}",
        '"viafHolders":{\n' + block(snapshot["viafHolders"], viaf_key) + "\n}",
    ]) + "\n}\n"
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(text)
    os.replace(tmp, path)
    return len(text.encode("utf-8"))


def main():
    persons_complete = os.environ.get("PERSONS_COMPLETE")
    people_dir = os.environ.get("PEOPLE_DATA_DIR")
    if not persons_complete or not people_dir:
        raise SystemExit("NOT WRITTEN: set PERSONS_COMPLETE and PEOPLE_DATA_DIR (see the docstring).")
    output = os.environ.get("OUTPUT_PATH", "PersonAuthorityIndexGenerator/wikidata-snapshot.json")
    cache_root = os.environ.get("CACHE_DIR", ".cache/wikidata-snapshot")
    fetched = os.environ.get("FETCHED_DATE") or datetime.datetime.now(datetime.timezone.utc).date().isoformat()

    wikidata, viaf, reached = collect(persons_complete, people_dir)
    log(f"{reached} registry records reached by the overlay; {len(wikidata)} Wikidata ids and {len(viaf)} VIAF ids")

    holders = viaf_holders(viaf, Cache(cache_root, "sparql"))
    if holders is None:
        raise SystemExit("NOT WRITTEN: query.wikidata.org did not answer for every VIAF id.")
    holder_items = {item for rows in holders.values() for item, _ in rows}
    wanted = sorted(set(wikidata) | holder_items, key=lambda q: int(q[1:]))
    ents = entities(wanted, Cache(cache_root, "items"), "labels|aliases|descriptions|claims|sitelinks",
                    ITEM_BATCH, "items")
    unanswered = [q for q in wanted if q not in ents]
    if unanswered:
        raise SystemExit(f"NOT WRITTEN: the API did not answer for {len(unanswered)} items: {unanswered[:20]}")

    pointed = sorted({v for e in ents.values() for prop in LABELLED_CLAIMS for v, _ in claims(e, prop)
                      if isinstance(v, str) and re.fullmatch(r"Q\d+", v)}, key=lambda q: int(q[1:]))
    label_ents = entities(pointed, Cache(cache_root, "labels"), "labels", LABEL_BATCH, "labels")
    unlabelled = [q for q in pointed if q not in label_ents]
    if unlabelled:
        raise SystemExit(f"NOT WRITTEN: the API did not answer for the labels of {len(unlabelled)} items: {unlabelled[:20]}")
    labels = {}
    for q, e in label_ents.items():
        lab = e.get("labels", {})
        labels[q] = (lab.get("en") or lab.get("mul") or {}).get("value", "")

    items = {}
    for q in wanted:
        e = ents[q]
        f = facts(e, labels)
        resolved = e.get("id")
        if resolved and resolved != q and "missing" not in e:
            f["redirect"] = resolved
        items[q] = f

    live, deprecated = {}, {}
    for v, rows in holders.items():
        by_item = {}
        for item, rank in rows:
            by_item.setdefault(item, set()).add(rank)
        live[v] = sorted((i for i, ranks in by_item.items() if ranks != {"DeprecatedRank"}), key=lambda q: int(q[1:]))
        gone = sorted((i for i, ranks in by_item.items() if ranks == {"DeprecatedRank"}), key=lambda q: int(q[1:]))
        if gone:
            deprecated[v] = gone

    missing_facts = [q for q in wikidata if q not in items] + [v for v in viaf if v not in live]
    if missing_facts:
        raise SystemExit(f"NOT WRITTEN: {len(missing_facts)} collected ids have no facts: {missing_facts[:20]}")

    digest = hashlib.sha256(open(persons_complete, "rb").read()).hexdigest()
    snapshot = {
        "about": ABOUT,
        "counts": {"items": len(items), "overlayWikidataIds": len(wikidata), "viafIds": len(viaf),
                   "viafIdsHeld": sum(1 for v in live if live[v]), "registryRecordsReached": reached},
        "fetched": fetched,
        "items": items,
        "personsComplete": digest,
        "viafDeprecatedHolders": deprecated,
        "viafHolders": live,
    }
    size = write_snapshot(output, snapshot)
    log(f"wrote {output}: {len(items)} items, {len(live)} VIAF ids ({snapshot['counts']['viafIdsHeld']} held), {size:,} bytes")


if __name__ == "__main__":
    main()
