#!/usr/bin/env python3
"""POCOM posts with exact dates, and the geography crosswalk (#234, chapter-context/coverage).

Read-only over /Users/jbotts/Development/pocom. Stdlib only.
"""
import re, glob, collections, datetime

POCOM = "/Users/jbotts/Development/pocom"

# Department principals. Tier 1 = the Secretary (or ad interim during a vacancy). Tier 2 = the
# officers who signed "Acting Secretary" during the Secretary's absence (POCOM does not record
# those absences; only the posts from which an acting signature could come).
DEPT_TIER1 = ["secretary", "secretary-ad-interim"]
DEPT_TIER2 = ["assistant-secretary", "second-assistant-secretary", "third-assistant-secretary", "chief-clerk"]


def _d(s, end=False):
    s = (s or "").strip()
    m = re.match(r"^(\d{4})(?:-(\d{2}))?(?:-(\d{2}))?$", s)
    if not m:
        return None
    y = int(m.group(1)); mo = int(m.group(2) or (12 if end else 1))
    if m.group(3):
        dd = int(m.group(3))
    else:
        dd = 31 if end and mo == 12 else (28 if end else 1)
    try:
        return datetime.date(y, mo, dd)
    except ValueError:
        return datetime.date(y, mo, 28)


def _date_of(block, tag, end=False):
    m = re.search(r"<%s>\s*<date>([^<]*)</date>" % tag, block)
    return _d(m.group(1), end) if m else None


def load_people():
    sur, full = {}, {}
    for path in glob.glob(f"{POCOM}/people/*/*.xml"):
        t = open(path, encoding="utf-8", errors="replace").read()
        sid = re.search(r"<id>([^<]+)</id>", t)
        s = re.search(r"<surname>([^<]*)</surname>", t)
        f = re.search(r"<forename>([^<]*)</forename>", t)
        if sid:
            sur[sid.group(1)] = (s.group(1).strip() if s else "")
            full[sid.group(1)] = ((f.group(1).strip() + " ") if f else "") + (s.group(1).strip() if s else "")
    return sur, full


def load_posts():
    """{post_key: [(slug, start, end, role, open_end)]}; post_key = 'dept:<position>' or 'chief:<territory>'."""
    posts = collections.defaultdict(list)
    stats = collections.Counter()
    for f in DEPT_TIER1 + DEPT_TIER2:
        t = open(f"{POCOM}/positions-principals/{f}.xml", encoding="utf-8").read()
        for b in re.findall(r"<principal>.*?</principal>", t, re.S):
            slug = re.search(r"<person-id>([^<]+)", b).group(1)
            st = [x for x in (_date_of(b, "appointed"), _date_of(b, "started")) if x]
            en = _date_of(b, "ended", end=True)
            if not st:
                stats["dept_no_start"] += 1
                continue
            s = min(st)
            if en is None or en < s:   # e.g. second-assistant-secretary hunter: started 1886 > ended 1886-07-22
                if en is not None:
                    stats["dept_end_before_start_fixed_to_appointed"] += 1
                    s = min(st); en = max(st + [en])
                else:
                    en = datetime.date(9999, 1, 1); stats["dept_open_end"] += 1
            posts["dept:" + f].append((slug, s, en, f))
    for path in sorted(glob.glob(f"{POCOM}/missions-countries/*.xml")):
        t = open(path, encoding="utf-8").read()
        terr = re.search(r"<territory-id>([^<]+)", t).group(1)
        for b in re.findall(r"<chief>.*?</chief>", t, re.S):
            slug = re.search(r"<person-id>([^<]+)", b).group(1)
            role = re.search(r"<role-title-id>([^<]*)", b).group(1)
            st = [x for x in (_date_of(b, "appointed"), _date_of(b, "arrived"), _date_of(b, "started")) if x]
            en = _date_of(b, "ended", end=True)
            if not st:
                stats["chief_no_start"] += 1
                continue
            s = min(st)
            served = _date_of(b, "started") or _date_of(b, "arrived")
            if en is None and served is None:
                # appointed but no start, arrival or end: a nomination declined, withdrawn or never
                # taken up (e.g. frelinghuysen-frederick-theodore to the UK, 1870). Not a holder.
                stats["chief_no_end_no_start_excluded"] += 1
                continue
            posts["chief:" + terr].append([slug, s, en, role])
    for key in [k for k in posts if k.startswith("chief:")]:
        rows = sorted(posts[key], key=lambda r: r[1])
        for i, r in enumerate(rows):
            if r[2] is None:
                nxt = [q[1] for q in rows[i + 1:] if q[1] > r[1]]
                r[2] = nxt[0] if nxt else datetime.date(9999, 1, 1)
                stats["chief_served_no_end_closed_at_next_start" if nxt else "chief_served_open_end"] += 1
        posts[key] = [tuple(r) for r in rows]
    return posts, stats


def holders(posts, key, date, slack_days=0):
    sl = datetime.timedelta(days=slack_days)
    return {slug for slug, s, e, _ in posts.get(key, ()) if s - sl <= date <= e + sl}


# ---------------------------------------------------------------- geography crosswalk
CENTRAL_AMERICA = ("guatemala", "honduras", "el-salvador", "costa-rica", "nicaragua")

# key (the app's GeoKeyNormalizer output, or a repaired title) -> tuple of POCOM territory ids.
# Historical states are named as POCOM names them: Prussia/North German Union/German Empire are
# filed under `germany` (chief notes: "Commissioned to Prussia"), New Granada / United States of
# Colombia under `colombia`, the Pontifical States under `holy-see`, Persia `iran`, Siam `thailand`,
# the Hawaiian Kingdom `hawaii`, the Two Sicilies `two-sicilies` (contemporary id
# kingdom-of-two-sicilies-1861), Korea `korea` (contemporary joseon-dynasty-1910), Austria-Hungary
# `austria`, Sweden and Norway `sweden` (norway only from 1905).
GEO = {
    "great britain": ("united-kingdom",), "england": ("united-kingdom",), "united kingdom": ("united-kingdom",),
    "china": ("china",), "spain": ("spain",), "mexico": ("mexico",), "france": ("france",),
    "turkey": ("turkey",), "turkish empire": ("turkey",), "ottoman empire": ("turkey",),
    "germany": ("germany",), "prussia": ("germany",), "north germany": ("germany",),
    "north german union": ("germany",), "german empire": ("germany",),
    "russia": ("russia",), "japan": ("japan",), "haiti": ("haiti",), "hayti": ("haiti",),
    "colombia": ("colombia",), "new granada": ("colombia",), "united states of colombia": ("colombia",),
    "austria": ("austria",), "austria-hungary": ("austria",),
    "venezuela": ("venezuela",), "brazil": ("brazil",), "peru": ("peru",),
    "central america": CENTRAL_AMERICA, "central american states": CENTRAL_AMERICA,
    "belgium": ("belgium",), "switzerland": ("switzerland",), "netherlands": ("netherlands",),
    "italy": ("italy",), "rome": ("holy-see",), "papal states": ("holy-see",), "pontifical states": ("holy-see",),
    "denmark": ("denmark",), "portugal": ("portugal",), "chile": ("chile",), "chili": ("chile",),
    "sweden": ("sweden",), "sweden and norway": ("sweden",), "norway": ("norway",),
    "hawaii": ("hawaii",), "hawaiian islands": ("hawaii",), "sandwich islands": ("hawaii",),
    "persia": ("iran",), "ecuador": ("ecuador",), "greece": ("greece",), "korea": ("korea",), "corea": ("korea",),
    "dominican republic": ("dominican-republic",), "santo domingo": ("dominican-republic",),
    "san domingo": ("dominican-republic",),
    "paraguay": ("paraguay",), "bolivia": ("bolivia",), "cuba": ("cuba",), "liberia": ("liberia",),
    "siam": ("thailand",), "uruguay": ("uruguay",),
    "argentina": ("argentina",), "argentine republic": ("argentina",), "argentine confederation": ("argentina",),
    "panama": ("panama",), "rumania": ("romania",), "roumania": ("romania",), "romania": ("romania",),
    "serbia": ("serbia",), "servia": ("serbia",), "morocco": ("morocco",), "egypt": ("egypt",),
    "bulgaria": ("bulgaria",), "montenegro": ("montenegro",), "luxemburg": ("luxembourg",), "luxembourg": ("luxembourg",),
    "costa rica": ("costa-rica",), "nicaragua": ("nicaragua",), "el salvador": ("el-salvador",),
    "salvador": ("el-salvador",), "guatemala": ("guatemala",), "honduras": ("honduras",),
    "two sicilies": ("two-sicilies",), "naples": ("two-sicilies",),
}
# Known non-mission geographies (no POCOM chief before 1906) — named so the unmapped list says why.
NO_POCOM_MISSION = {"tunis", "tripoli", "kongo", "congo", "samoa", "south african republic", "orange free state",
                    "zanzibar", "madagascar", "barbary states", "transvaal", "newfoundland", "canada", "muscat",
                    "abyssinia", "fiji", "tonga", "borneo", "sarawak"}
# Consular post keys whose US officer in this era was ALSO a POCOM chief of mission (agent and
# consul-general / minister resident and consul-general).
CONSULAR_POST_CHIEF = {"cairo": ("egypt",), "alexandria": ("egypt",), "tangier": ("morocco",),
                       "bangkok": ("thailand",), "monrovia": ("liberia",), "seoul": ("korea",),
                       "teheran": ("iran",), "honolulu": ("hawaii",)}
# US mission city -> country, for subchapter titles "correspondence with the legation of the
# united states at madrid".
CITY = {"madrid": "spain", "paris": "france", "london": "great britain", "berlin": "germany",
        "vienna": "austria", "st. petersburg": "russia", "rome": "italy", "peking": "china", "pekin": "china",
        "tokyo": "japan", "tokio": "japan", "mexico": "mexico", "constantinople": "turkey", "lisbon": "portugal",
        "the hague": "netherlands", "brussels": "belgium", "berne": "switzerland", "copenhagen": "denmark",
        "stockholm": "sweden", "athens": "greece", "rio de janeiro": "brazil", "lima": "peru", "santiago": "chile",
        "caracas": "venezuela", "bogota": "colombia", "port au prince": "haiti", "honolulu": "hawaii"}
ADJ = {"british": "great britain", "french": "france", "spanish": "spain", "mexican": "mexico", "russian": "russia",
       "austrian": "austria", "austro-hungarian": "austria", "german": "germany", "prussian": "prussia",
       "italian": "italy", "chinese": "china", "japanese": "japan", "peruvian": "peru", "chilean": "chile",
       "chilian": "chile", "brazilian": "brazil", "portuguese": "portugal", "netherlands": "netherlands",
       "belgian": "belgium", "swiss": "switzerland", "danish": "denmark", "swedish": "sweden", "turkish": "turkey",
       "haytian": "haiti", "haitian": "haiti", "colombian": "colombia", "venezuelan": "venezuela",
       "argentine": "argentina", "hawaiian": "hawaii", "korean": "korea", "greek": "greece", "ecuadorian": "ecuador",
       "guatemalan": "guatemala", "nicaraguan": "nicaragua", "costa rican": "costa rica", "salvadorean": "el salvador",
       "honduranean": "honduras", "bolivian": "bolivia", "paraguayan": "paraguay", "uruguayan": "uruguay",
       "siamese": "siam", "persian": "persia", "dominican": "dominican republic", "liberian": "liberia"}

ROMAN = re.compile(r"^(?:\[\d+\]\s*)?\*?\s*(?:part\s+)?[ivxlc]+\s*\.?\s*[—–-]+\s*")
LEADCORR = re.compile(r"^correspondence\s*\.?\s*[—–-]?\s*")
TRAILCORR = re.compile(r"\s*\.?\s*correspondence$")


def repaired_key(title_lower):
    """Crosswalk repairs over a lower-cased chapter title. Returns (key, kind) or (None, None).

    kind: 'country' | 'us-mission' (a US legation/embassy subchapter) | 'foreign-legation'
    (correspondence with a foreign legation in Washington).
    """
    t = " ".join(title_lower.split()).strip()
    t = re.sub(r"\(continued\.?\)", "", t).strip()
    t = ROMAN.sub("", t)
    t = LEADCORR.sub("", t) if not t.startswith("correspondence with") else t
    t = TRAILCORR.sub("", t)
    t = t.strip(" .,;:")
    m = re.search(r"(?:legation|embassy) of the united states (?:at|in) ([a-z .]+)$", t)
    if m and m.group(1).strip(" .") in CITY:
        return CITY[m.group(1).strip(" .")], "us-mission"
    m = re.search(r"(?:legation|embassy|minister) of ([a-z -]+?) (?:at|in) washington", t) or \
        re.search(r"^(?:correspondence with )?(?:the )?(?:legation|embassy) of ([a-z -]+)$", t)
    if m:
        k = m.group(1).strip()
        k = ADJ.get(k, k)
        if k in GEO:
            return k, "foreign-legation"
    m = re.search(r"^(?:correspondence with )?(?:the )?([a-z -]+?) (?:legation|embassy|minister)(?: (?:at|in) washington)?$", t)
    if m:
        k = ADJ.get(m.group(1).strip(), m.group(1).strip())
        if k in GEO:
            return k, "foreign-legation"
    head = re.split(r"\s*[—–]\s*|\.\s*[—–-]", t)[0].strip(" .")
    if head in GEO:
        return head, "country"
    return None, None
