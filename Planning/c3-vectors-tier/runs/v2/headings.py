# Theme tally of the editors' headings: every LEAF section at or below a section whose title matches /cuba|havana/i
# (as chapters.py), excluding frus1896's steamship "Cuban" section. A leaf's documents are assigned to every theme its
# own title (joined with its parents' titles below the Cuba match) matches, re.I. Era band from the volume's
# earliest document date_iso among the leaf's documents. Output: headings_out.txt and headings_leaves.tsv.
import sqlite3, json, re, collections
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
TH = {"security": r"defen[cs]e|military|naval|bases?\b|missile|soviet|communis|subversi|arms|hijack|war\b|enemy|security|guant",
      "economy": r"sugar|trade|reciproc|tariff|loan|financ|debt|credit|cable|concession|petroleum|tobacco|commerc|export|import|bank|lend-lease|econom|rice|trade-mark|aviation|shipping",
      "property_claims": r"propert|claim|american interests|protection of american|expropriat|compensation",
      "politics_order": r"revolution|insurrection|election|intervention|political|recognition|government|pacification|platt|treaty of relations|relations between"}
CT = {k: re.compile(v, re.I) for k, v in TH.items()}
pat = re.compile(r"cuba|havana", re.I)
def ids(s):
    r = list(s.get("documentIds", []))
    for x in s.get("subsections", []): r += ids(x)
    return r
leaves = []
def walk(v, s, inside, label):
    t = (s.get("title") or "").strip(); now = inside or bool(pat.search(t))
    lab = (label + " > " + t) if now else ""
    subs = s.get("subsections", [])
    if now and not subs and s.get("documentIds"):
        if not (v == "frus1896" and "steamship Cuban" in t): leaves.append((v, lab, s["documentIds"]))
    elif now and s.get("documentIds") and subs:
        leaves.append((v, lab + " [direct]", s["documentIds"]))
    for x in subs: walk(v, x, now, lab)
for v, js in db.execute("SELECT volume_id, structure_json FROM volume_structures"):
    if v in ("frus1951-54IranEd2", "frus1969-76ve15p2Ed2"): continue
    for s in json.loads(js)["sections"]: walk(v, s, False, "")
BANDS = [(1840, 1898), (1899, 1933), (1934, 1958), (1959, 1980)]
tal = collections.defaultdict(collections.Counter); tot = collections.Counter(); f = open("headings_leaves.tsv", "w")
for v, lab, dids in leaves:
    ds = [r[0] for d in dids for r in db.execute("SELECT dd.date_iso FROM document_cache c JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=? AND c.is_front_matter=0 AND c.is_editorial_note=0", (v, d)) if r[0]]
    if not ds: continue
    y = int(min(ds)[:4]); band = next((f"{a}-{b}" for a, b in BANDS if a <= y <= b), None)
    if not band: continue
    th = [k for k, c in CT.items() if c.search(lab)] or ["other"]
    tot[band] += len(ds)
    for k in th: tal[band][k] += len(ds)
    f.write(f"{band}\t{v}\t{len(ds)}\t{','.join(th)}\t{lab}\n")
for b in [f"{a}-{c}" for a, c in BANDS]:
    print(b, "docs", tot[b], {k: f"{tal[b][k]}/{tot[b]}" for k in list(TH) + ["other"]})
