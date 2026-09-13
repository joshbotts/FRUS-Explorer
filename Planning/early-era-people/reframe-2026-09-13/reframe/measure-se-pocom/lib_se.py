#!/usr/bin/env python3
"""Shared helpers for reframe/measure-se-pocom (#234). Standard library only; all inputs read-only.

FROM THE COMPILED APP CLASSIFIER (never re-implemented here): every category, geo key, confidence,
chosen title and shown row, read from the Swift harness's per-document JSONL:
  geo-fix/before-docs.jsonl  (pre-#1292 sources; md5 == chapter-context/harness/frus-pre1906-classified.jsonl)
  geo-fix/after-docs.jsonl   (md5 == classified/head-docs.jsonl, rebuilt here from HEAD f63e253e)

MIRRORED HERE, used only to SPLIT rows by chapter kind and to say WHEN the sender rule decided:
  foreign_legation_name  <- GeoKeyNormalizer.foreignLegationName + stripChapterDecoration + fold
  sos_sender / presidential_sender <- CentralFilesClassifier.secretaryOfStateSender / presidentialSender
  proxy_headers.py pins both mirrors against the compiled output (parity counts in its JSON).

THIS PROGRAM'S OWN JUDGEMENT (labelled so in every output): us_mission_title (a chapter kind the app has
no notion of), the filing-role label map (category x side -> role), and the evidence parsers for list role
text and printed header offices.

Revision 2 (after reading the first proxy run's wrong examples): a place-less role (the Department, a foreign
consul, a U.S. executive office, a special agent) matches without a place; an evidence place is looked up as a
CITY first ("at Rome" in 1873 is Italy, not the Papal States); consular posts also compare at country level
(Cairo and Alexandria are one agency); a diplomatic agent is accepted as mission or consulate; "President X" is
a U.S. domestic office only for a U.S. president; memorandum headers ("handed to X by Y") carry no sender/addressee.
"""
import re, os, sys, json, math

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "lib"))
import ner_store  # noqa: F401  imported first so a later sys.path insert cannot shadow the copy
import pocom_posts as PP

SP = os.path.abspath(os.path.join(HERE, "..", ".."))
BEFORE = os.path.join(SP, "geo-fix", "before-docs.jsonl")
AFTER = os.path.join(SP, "geo-fix", "after-docs.jsonl")
LISTVOLS_AFTER = os.path.join(HERE, "classified", "head-listvols-docs.jsonl")
LV = os.path.join(SP, "chapter-context", "label-validation")
LISTVOLS_BEFORE = os.path.join(LV, "classified-list-volumes.jsonl")
GOLD_MENTIONS = os.path.join(LV, "gold-mentions.jsonl")
GOLD_ENTRIES = os.path.join(LV, "gold-entries.jsonl")
MARKED = os.path.expanduser("~/frus-ner-raw")
GEO_CATS = {"diplomaticDespatches", "diplomaticInstructions", "notesToForeignMissions", "notesFromForeignMissions"}
_TRIM = " \t\r\n   .,;"


def jsonl(path):
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                yield json.loads(line)


def _c(x):
    return {"category": x["category"], "geoKeys": list(x.get("geoKeys") or []), "confidence": x.get("confidence")}


def slim(r):
    return {"volume": r["volume"], "d": r["d"], "header": r.get("header"), "dateline": r.get("dateline"),
            "datelineDateISO": r.get("datelineDateISO"), "dateIsoIndex": r.get("dateIsoIndex"),
            "appYear": r.get("appYear"), "gate": r.get("gate"), "sectionPath": r.get("sectionPath") or [],
            "chosenTitle": r.get("chosenTitle"), "chosenTitleIndex": r.get("chosenTitleIndex"),
            "shown": [_c(x) for x in (r.get("shown") or [])],
            "classifierByTitle": [{"title": t["title"], "titleGeoKeys": list(t.get("titleGeoKeys") or []),
                                   "titleKeyServedByDiplomaticRoll": bool(t.get("titleKeyServedByDiplomaticRoll")),
                                   "classifications": [_c(x) for x in (t.get("classifications") or [])]}
                                  for t in (r.get("classifierByTitle") or [])]}


def slim_lv_before(r):
    """label-validation `lv classify` output (pre-#1292 sources, commit 7ec27675 hashes) -> slim shape."""
    ci = r.get("shownChosenIndex")
    path = r.get("path") or []
    cbt = []
    if r.get("dateline") is not None:
        cbt = [{"title": t["title"], "titleGeoKeys": list(t.get("keys") or []),
                "titleKeyServedByDiplomaticRoll": bool(t.get("firstServed")),
                "classifications": [_c(x) for x in (t.get("classify") or [])]} for t in (r.get("titles") or [])]
    return {"volume": r["volume"], "d": r["d"], "header": r.get("header"), "dateline": r.get("dateline"),
            "datelineDateISO": r.get("datelineDateISO"), "dateIsoIndex": r.get("date_iso"), "appYear": r.get("appYear"),
            "gate": r.get("shownGate"), "sectionPath": path, "chosenTitle": path[ci] if ci is not None else None,
            "chosenTitleIndex": ci, "shown": [_c(x) for x in (r.get("shown") or [])], "classifierByTitle": cbt}


def load_docs(path, volumes=None, adapter=slim):
    out = {}
    for r in jsonl(path):
        if volumes is not None and r["volume"] not in volumes:
            continue
        out[(r["volume"], r["d"])] = adapter(r)
    return out


def scope_volumes(max_year=1905):
    return [v for v in ner_store.scope_volumes(MARKED) if int(v[4:8]) <= max_year]


def band_of_volume(v):
    y = int(v[4:8])
    return "1861-1899" if y <= 1899 else ("1900-1905" if y <= 1905 else "post-1905")


# ------------------------------------------------------------------ mirrors of merged app rules
_L = r"[^\W\d_]"
_LX = r"(?:[^\W\d_]|['\-])"


def fold(s):
    s = (s or "").strip(_TRIM)
    return " ".join(x for x in s.lower().split(" ") if x)


_DECOR1 = re.compile(r"^(?:\[\d+\]\s*)?\*?\s*(?:[IVXLCDM]+|\d{1,3})\.\s*[—–-]\s*")
_DECOR2 = re.compile(r"\s*\(\s*continued\.?\s*\)\s*$", re.I)


def strip_decoration(title):
    t = (title or "").strip()
    m = _DECOR1.match(t)
    if m:
        t = t[m.end():]
    m = _DECOR2.search(t)
    if m:
        t = t[:m.start()]
    return re.sub(r"(?<=[^\W\d_])[–—](?=[^\W\d_])", "-", t)


_LEAD = r"(?:correspondence (?:with|between the department of state and) )?(?:the )?"
_WASH = r"(?:,? (?:at|in) (?:washington(?:,? d\. ?c)?|the united states(?: of america)?))?"
_LEG = [re.compile("^" + _LEAD + r"(?:legation|embassy) of (?:the )?(.+?)" + _WASH + r"\Z"),
        re.compile("^" + _LEAD + "(" + _L + _LX + "*(?: " + _L + _LX + "*){0,2}) (?:legation|embassy)" + _WASH + r"\Z")]


def foreign_legation_name(title):
    t = fold(strip_decoration(title))
    for p in _LEG:
        m = p.match(t)
        if not m:
            continue
        name = m.group(1)
        if any(w in ("at", "in", "to", "for", "from", "by") for w in name.split(" ")):
            return None
        if name in ("american", "united states", "united states of america") or name.startswith("u. s") or name.startswith("u.s"):
            return None
        return name
    return None


_SOS = re.compile(r"\b(?:secretary of state(?! for)|mr\.? (?:[a-z]\. ?)*(?:seward|fish|evarts|blaine|frelinghuysen|bayard|foster|gresham|olney|sherman|day|hay|root|hunter|adee|wharton|uhl))\b")
_PRES = re.compile(r"^\s*(?:no\. ?\d+\. )?the president\b")


def sos_sender(header):
    h = (header or "").lower()
    i = h.find(" to ")
    return i >= 0 and _SOS.search(h[:i]) is not None


def presidential_sender(header):
    h = (header or "").lower()
    i = h.find(" to ")
    return i >= 0 and _PRES.search(h[:i]) is not None


# THIS PROGRAM'S chapter-kind rule for U.S.-mission chapters (no app counterpart).
_USM = re.compile(r"^(?:[ivxlc]+\.?\s*[—–-]*\s*)?(?:miscellaneous )?correspondence (?:with|between the department of state,? and) (?:the )?(?:(?:legation|embassy) of the united states(?! of colombia)|united states (?:legation|embassy))")


def us_mission_title(title):
    return _USM.match(fold(strip_decoration(title))) is not None


def title_is_country(t):
    k0 = t["titleGeoKeys"][0] if t["titleGeoKeys"] else None
    return bool(t["titleKeyServedByDiplomaticRoll"]) or (k0 in PP.GEO if k0 else False)


def title_kind(t):
    if foreign_legation_name(t["title"]):
        return "foreign-legation"
    if us_mission_title(t["title"]):
        return "us-mission"
    return "country" if title_is_country(t) else "topical"


def doc_kind(r):
    """Structural chapter kind of a document's section path (precedence legation > US mission > country > topical)."""
    cbt = r["classifierByTitle"]
    titles = [t["title"] for t in cbt] if cbt else r["sectionPath"]
    if any(foreign_legation_name(t) for t in titles):
        return "foreign-legation"
    if any(us_mission_title(t) for t in titles):
        return "us-mission"
    if not cbt:
        return "no-dateline(kind unread)"
    return "country" if any(title_is_country(t) for t in cbt) else "topical"


def sender_rule_decided(r, title):
    """True when the merged sender rule (legation chapter, dateline without 'department of state', a Secretary's
    name or office as sender) is what made the document Department outbound."""
    return bool(title) and foreign_legation_name(title) is not None and \
        "department of state" not in (r.get("dateline") or "").lower() and sos_sender(r.get("header"))


# ------------------------------------------------------------------ arms over the compiled output
def arm_S(r):
    """What Source Explorer SHOWS: the resolutions with a NARA roll, on the title the app's walk chose."""
    if r is None or not r["shown"]:
        return None
    shown = r["shown"]
    ci = r["chosenTitleIndex"]
    cbt = r["classifierByTitle"]
    t = cbt[ci] if (ci is not None and ci < len(cbt)) else None
    gk = next((c["geoKeys"][0] for c in shown if c["category"] in GEO_CATS and c["geoKeys"]), None)
    # Revision 3: a diplomatic role needs the chosen title to be a country title. When only a date-matched
    # series resolved (consular pair, letters received) on a title like "Correspondence", the title's
    # instruction/note candidates are keyed on that word and must not become "the Correspondence legation".
    return {"classifications": shown, "cands": t["classifications"] if t else shown,
            "terr": PP.GEO.get(gk) if gk else None, "geo_key": gk,
            "geo_ok": bool(gk) or (bool(t) and title_is_country(t)), "legation_kind": None,
            "chapter": r["chosenTitle"], "kind_used": title_kind(t) if t else None}


def arm_T(r):
    """The classifier's own candidates WITHOUT the NARA-roll test, on the first title (root->leaf) that has
    candidates and whose app key is a diplomatic-roll key or maps to a POCOM territory; app keys only."""
    if r is None:
        return None
    first = None
    for t in r["classifierByTitle"]:
        if not t["classifications"]:
            continue
        if first is None:
            first = t
        if title_is_country(t):
            k0 = t["titleGeoKeys"][0]
            return {"classifications": t["classifications"], "cands": t["classifications"],
                    "terr": PP.GEO.get(k0), "geo_key": k0, "geo_ok": True, "legation_kind": None,
                    "chapter": t["title"], "kind_used": title_kind(t)}
    if first is None:
        return None
    k0 = first["titleGeoKeys"][0] if first["titleGeoKeys"] else None
    return {"classifications": first["classifications"], "cands": first["classifications"], "terr": None,
            "geo_key": k0, "geo_ok": False, "legation_kind": None, "chapter": first["title"],
            "kind_used": title_kind(first)}


# ------------------------------------------------------------------ the filing-role label (no identity)
def roles_from(cands, geo_ok):
    """(from_roles, to_roles): frozensets of (kind, key). Diplomatic roles need a country key (geo_ok)."""
    F, T = set(), set()
    for c in cands or []:
        cat = c["category"]
        g = c["geoKeys"][0] if c.get("geoKeys") else None
        if cat in GEO_CATS and not (geo_ok and g):
            continue
        if cat == "diplomaticDespatches":
            F.add(("us-mission", g)); T.add(("department", None))
        elif cat == "diplomaticInstructions":
            F.add(("department", None)); T.add(("us-mission", g))
        elif cat == "notesToForeignMissions":
            F.add(("department", None)); T.add(("foreign-legation", g))
        elif cat == "notesFromForeignMissions":
            F.add(("foreign-legation", g)); T.add(("department", None))
        elif cat == "consularDespatches":
            F.add(("us-consulate", g)); T.add(("department", None))
        elif cat == "notesFromForeignConsuls":
            F.add(("foreign-consul", None)); T.add(("department", None))
        elif cat == "notesToForeignConsuls":
            F.add(("department", None)); T.add(("foreign-consul", None))
        elif cat == "consularInstructions":
            F.add(("department", None)); T.add(("us-consulate", None))
        elif cat == "lettersReceived":
            F.add(("us-domestic-office", None)); T.add(("department", None))
        elif cat == "domesticLetters":
            F.add(("department", None)); T.add(("us-domestic-office", None))
        elif cat == "specialAgentsDespatches":
            F.add(("special-agent", None)); T.add(("department", None))
        elif cat == "specialAgentsInstructions":
            F.add(("department", None)); T.add(("special-agent", None))
    return frozenset(F), frozenset(T)


_NAMES = {"department": "the Department of State", "us-mission": "the U.S. mission in {k}",
          "foreign-legation": "the {k} legation in Washington", "us-consulate": "the U.S. consulate at {k}",
          "foreign-consul": "a foreign consul in the United States", "us-domestic-office": "a U.S. executive office",
          "special-agent": "a special agent of the Department"}


def render_role(role):
    kind, key = role
    if kind == "us-consulate" and not key:
        return "a U.S. consul abroad"
    return _NAMES.get(kind, kind).format(k=(key or "?").title())


def render_row_label(own, other, side):
    a = " or ".join(sorted(render_role(r) for r in own))
    b = " or ".join(sorted(render_role(r) for r in other)) or "?"
    return a + (" -- writing to " if side == "from" else " -- receiving from ") + b


# ------------------------------------------------------------------ independent evidence and the judge
ADJ = dict(PP.ADJ)
ADJ.update({"britannic": "great britain", "english": "great britain", "ottoman": "turkey", "cuban": "cuba",
            "salvadoran": "el salvador", "norwegian": "norway", "roumanian": "romania", "rumanian": "romania",
            "servian": "serbia", "dutch": "netherlands", "hungarian": "austria", "soviet": "russia",
            "moroccan": "morocco", "egyptian": "egypt", "panamanian": "panama", "honduran": "honduras",
            "bulgarian": "bulgaria", "polish": "poland", "czechoslovak": "czechoslovakia", "finnish": "finland",
            "irish": "ireland", "canadian": "canada", "iranian": "persia", "thai": "siam", "saudi": "saudi arabia"})
CITY2 = dict(PP.CITY)
CITY2.update({"san salvador": "el salvador", "buenos ayres": "argentina", "buenos aires": "argentina", "leon": "nicaragua",
              "alexandria": "egypt", "cairo": "egypt", "tangier": "morocco", "geneva": "switzerland", "quito": "ecuador",
              "montevideo": "uruguay", "asuncion": "paraguay", "la paz": "bolivia", "tegucigalpa": "honduras",
              "managua": "nicaragua", "san jose": "costa rica", "port-au-prince": "haiti", "santo domingo": "dominican republic",
              "bangkok": "siam", "seoul": "korea", "teheran": "persia", "monrovia": "liberia", "havana": "cuba",
              "bucharest": "romania", "belgrade": "serbia", "athens": "greece", "petrograd": "russia", "moscow": "russia",
              "nanking": "china", "guatemala": "guatemala", "panama": "panama", "christiania": "norway",
              "austro-hungarian empire": "austria", "soviet union": "russia"})
PLACELESS = {"department", "foreign-consul", "us-domestic-office", "special-agent"}


def terr_of_key(k):
    if not k:
        return None
    return tuple(PP.GEO[k]) if k in PP.GEO else ("key:" + k,)


def terr_of_place(name):
    """City first, then country name, then adjective (an office 'at Rome' in 1873 is Italy)."""
    if not name:
        return None
    n = re.sub(r"^the ", "", name.lower().strip(" .,;:()"))
    n = re.sub(r"\s+", " ", n)
    for cand in (CITY2.get(n), n, ADJ.get(n)):
        if cand and cand in PP.GEO:
            return tuple(PP.GEO[cand])
    return None


def role_evidence_1873(e):
    """Acceptable roles for a frus1873p1 list entry, from its printed role text and list heading."""
    role = " ".join((e.get("role") or "").lower().split())
    head = (e.get("heading") or "").strip(" .").lower()
    hterr = terr_of_place(head) if head and head != "department of state" else None
    ev = set()
    if re.match(r"^(?:acting |assistant |second assistant |third assistant )?secretary of state\b", role) or role.startswith("chief clerk"):
        ev.add(("department", None))
    m = re.search(r"(?:agent and consul general|consul general|consul)(?: of the united states)? at ([a-z .’'-]+?)(?=[,.;(]|$)", role)
    if m:
        ev.add(("us-consulate", m.group(1).strip()))
        if "agent" in role:
            ev.add(("us-mission", terr_of_place(m.group(1)) or hterr))
    foreign = re.search(r"majesty|of the king|of the emperor|of the president of|at washington|of the republic of", role)
    if ("of the united states" in role or "secretary of legation" in role) and \
            re.search(r"envoy|minister|charg|secretary of (?:the )?legation", role) and not foreign:
        m2 = re.search(r"of the united states (?:of america )?(?:at|to|in) ([a-z .’'-]+?)(?=[,.;(]|$)", role)
        ev.add(("us-mission", (terr_of_place(m2.group(1)) if m2 else None) or hterr))
    if "charg" in role and "consul" in role and not any(k == "us-mission" for k, _ in ev):
        ev.add(("us-mission", hterr))
    if foreign:
        ev.add(("foreign-legation", hterr))
    return ev


_Q = "[’']"
_FOFF = re.compile(r"minister (?:of|for) (?:foreign|exterior) (?:affairs|relations)|foreign (?:office|minister|affairs)|secretary of state for foreign affairs|minister of state\b|secretary(?:ship)? of foreign relations|imperial chancellor|grand vizier|tsungli yamen|prime minister")
_DEPT = re.compile(r"\b(?:(?:acting|assistant|second assistant|third assistant|under) )?secretary of state\b(?! (?:for|of))|\bacting secretary\b(?! of (?!state))|\bdepartment of state\b")
_USM1 = re.compile(r"\b(?:american|united states|u\. ?s\.)\s+(?:ambassador|minister|charg|envoy|legation|embassy|diplomatic agent)")
_USM2 = re.compile(r"\b(?:ambassador|minister(?: resident)?|charg\S* d" + _Q + r"affaires(?: ad interim)?|envoy extraordinary|legation|embassy)\b[^;]*? of the united states(?! of (?:colombia|mexico|brazil|venezuela))(?: of america)?(?: (?:at|in|to) ([a-z][a-z .’'-]+?))?(?=[,.;)]|$| to)")
_USM3 = re.compile(r"^(?:the )?(?:acting )?(ambassador|minister|charg\S*(?: d" + _Q + r"affaires)?(?: ad interim)?|diplomatic agent|legation|embassy) (?:in|at|to) ([a-z][a-z .’'-]+?)\s*(?:\(|,|$)")
_USMW = re.compile(r"^(?:ambassador|minister|charg\S*) (?!of |for |in |at |to |resident)[a-z]")
_FLEG = re.compile(r"\b(?:the )?([a-z][a-z-]*(?: [a-z][a-z-]*)?) (?:ambassador|minister|charg\S* d" + _Q + r"affaires|charg\S*|legation|embassy|envoy)(?![a-z])(?! (?:of|for) (?:foreign|state|the interior|war|marine|finance|public|justice))")
_HBM = re.compile(r"her (?:britannic )?majesty" + _Q + r"s (?:envoy|minister|charg)")
_CUS = re.compile(r"\b(?:american|united states|u\. ?s\.) (?:vice |deputy )?consul|\b(?:vice |deputy )?consul(?:-general| general)? (?:of the united states )?at ([a-z][a-z .’'-]+?)(?=[,.;(]|$| to)")
_CFOR = re.compile(r"\b(?:h\. ?b\. ?m\.?|british|french|spanish|german|mexican|chinese|italian|russian|japanese|belgian|dutch|swiss|danish|swedish|austrian|portuguese) (?:vice |deputy )?consul")
_USPRES = r"(?:lincoln|johnson|grant|hayes|garfield|arthur|cleveland|harrison|mckinley|roosevelt|taft|wilson|harding|coolidge|hoover)"
_DOM = re.compile(r"^(?:the )?president(?: of the united states)?(?:,|$)|^the president\b(?! of (?!the united states))|\bpresident of the united states\b|^president " + _USPRES + r"\b|secretary of (?:war|the navy|the treasury|the interior|agriculture|commerce|labor)|attorney[- ]general|postmaster[- ]general")
_MEMO = re.compile(r"^(?:no\. ?\d+\.?\s*)?(?:memorandum|aide-m|note verbale|pro memoria)")


def segment_evidence(seg):
    """(roles, strength, tag) for one side of a header, or None when no office is printed.
    THIS PROGRAM'S parser; strength 'weak' = the 1905 style 'Minister Leishman', which a foreign 'Minister Wu' shares."""
    s = " ".join((seg or "").lower().replace("( ", "(").replace(" )", ")").split())
    s = re.sub(r"^no\. ?\d+\.?\s*", "", s).strip(" .,")
    if not s:
        return None
    if _FOFF.search(s):
        m = next((mm for mm in _FLEG.finditer(s) if mm.group(1).split()[-1] in ADJ), None)
        return ({("foreign-official", terr_of_place(ADJ.get(m.group(1).split()[-1])) if m else None)}, "strict", "foreign-office")
    if _DEPT.search(s):
        return ({("department", None)}, "strict", "department")
    m = _USM3.search(s)
    if m:
        roles = {("us-mission", terr_of_place(m.group(2)))}
        if m.group(1) == "diplomatic agent":
            roles.add(("us-consulate", m.group(2).strip()))
        return (roles, "strict", "us-mission:office-in-place")
    m = _USM2.search(s)
    if m:
        return ({("us-mission", terr_of_place(m.group(1)) if m.group(1) else None)}, "strict", "us-mission:of-the-united-states")
    if _USM1.search(s):
        return ({("us-mission", None)}, "strict", "us-mission:american")
    if _HBM.search(s):
        return ({("foreign-legation", ("united-kingdom",))}, "strict", "foreign-legation:hbm")
    for mm in _FLEG.finditer(s):
        w = mm.group(1).split()[-1]
        if w in ADJ and w != "american":
            return ({("foreign-legation", terr_of_place(ADJ[w]))}, "strict", "foreign-legation:adjective")
    if _CFOR.search(s):
        return ({("foreign-consul", None)}, "strict", "foreign-consul")
    m = _CUS.search(s)
    if m:
        return ({("us-consulate", (m.group(1) or "").strip() or None)}, "strict", "us-consulate")
    if _DOM.search(s):
        return ({("us-domestic-office", None)}, "strict", "us-domestic-office")
    if _USMW.search(s):
        return ({("us-mission", None)}, "weak", "us-mission:bare-title-name")
    return None


def header_sides(header):
    """(sender, addressee) split at the first ' to '; (None, None) for memoranda and headers without ' to '."""
    h = " ".join((header or "").split())
    if _MEMO.search(h.lower()):
        return None, None
    i = h.lower().find(" to ")
    if i < 0:
        return None, None
    return h[:i], h[i + 4:]


def _city(s):
    s = fold(s)
    s = re.sub(r"^at ", "", s)
    s = re.sub(r"\(?\s*(?:of )?barbary\s*\)?", "", s)
    return s.strip(" ,.;()")


def _role_place_match(r, e):
    """True / False / None (untestable) for a label role vs an evidence role of the same kind."""
    if r[0] in PLACELESS:
        return True
    if r[0] == "us-consulate":
        if not r[1] or not e[1]:
            return None
        a, b = _city(r[1]), _city(e[1])
        if a and b and (a in b or b in a):
            return True
        ca, cb = CITY2.get(a), CITY2.get(b)
        if ca and cb:
            return ca == cb
        return False
    rt, et = terr_of_key(r[1]), e[1]
    if rt is None or et is None:
        return None
    return bool(set(rt) & set(et))


def judge(own, evidence):
    """'right' | 'right-kind-place-untestable' | 'wrong-place' | 'wrong-kind'."""
    pairs = [(r, e) for r in own for e in evidence if r[0] == e[0]]
    if not pairs:
        return "wrong-kind"
    res = [_role_place_match(r, e) for r, e in pairs]
    if any(x is True for x in res):
        return "right"
    if any(x is None for x in res):
        return "right-kind-place-untestable"
    return "wrong-place"


def wilson(k, n, z=1.96):
    if not n:
        return None
    p = k / n
    den = 1 + z * z / n
    c = (p + z * z / (2 * n)) / den
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return [round(p, 4), round(max(0.0, c - h), 4), round(min(1.0, c + h), 4)]


def precision_block(counter):
    judged = sum(v for k, v in counter.items() if k in ("right", "right-kind-place-untestable", "wrong-place", "wrong-kind"))
    right = counter.get("right", 0)
    loose = right + counter.get("right-kind-place-untestable", 0)
    return {"judged": judged, "right": right, "right_kind_place_untestable": counter.get("right-kind-place-untestable", 0),
            "wrong_place": counter.get("wrong-place", 0), "wrong_kind": counter.get("wrong-kind", 0),
            "unlabeled": counter.get("unlabeled", 0),
            "strict_precision_wilson95": wilson(right, judged), "loose_precision_wilson95": wilson(loose, judged)}


if __name__ == "__main__":
    tests = [("British legation.", "british"), ("Correspondence with the legation of Mexico at Washington.", "mexico"),
             ("Correspondence Between the Department of State and the German Embassy.", "german"),
             ("Correspondence with the embassy of the United States at Paris.", None), ("XXIX.—Spain.", None),
             ("Correspondence with the legation of the United States of Colombia.", "united states of colombia"),
             ("Great Britain. (Continued.)", None), ("Correspondence with the Mexican legation.", "mexican"),
             ("I.—Correspondence with the embassy of the United States at Paris.", None)]
    bad = 0
    for t, want in tests:
        got = foreign_legation_name(t)
        bad += got != want
        print("OK " if got == want else "BAD", repr(t), got)
    for t, want in [("I. Correspondence with the Legation of the United States at Madrid.", True),
                    ("I.—Correspondence with the embassy of the United States at Paris.", True),
                    ("Correspondence with the legation of the United States of Colombia.", False)]:
        bad += us_mission_title(t) != want
        print("OK " if us_mission_title(t) == want else "BAD", "usm", t)
    for h, want in [("Mr. F. W. Seward to Lord Lyons .", True), ("Mr. Hunter to Sir Frederick Bruce .", True),
                    ("Lord Lyons to Mr. Seward .", False), ("Mr. Welles to Mr. Seward.", False)]:
        bad += sos_sender(h) != want
        print("OK " if sos_sender(h) == want else "BAD", h)
    checks = [("the Secretary of State", "department"), ("President Loubet", None), ("The President", "us-domestic-office"),
              ("President McKinley", "us-domestic-office"), ("The Diplomatic Agent at Cairo ( Arnold )", "us-mission")]
    for seg, want in checks:
        ev = segment_evidence(seg)
        got = sorted(k for k, _ in ev[0])[0] if ev else None
        bad += got != want
        print("OK " if got == want else "BAD", seg, "->", ev)
    for own, ev, want in [({("department", None)}, {("department", None)}, "right"),
                          ({("us-consulate", "cairo")}, {("us-consulate", "alexandria")}, "right"),
                          ({("us-mission", "italy")}, {("us-mission", terr_of_place("Rome"))}, "right"),
                          ({("us-consulate", "at tripoli of barbary")}, {("us-consulate", "tripoli")}, "right")]:
        got = judge(own, ev)
        bad += got != want
        print("OK " if got == want else "BAD", own, ev, got)
    print("header_sides memo:", header_sides("Memorandum handed to Mr. Adee by the Chinese minister, Mr. Wu."))
    print("self-check failures:", bad)
