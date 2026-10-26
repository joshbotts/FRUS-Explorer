# build_deliverables.py: writes overview.md and collection.fruscollection from content.py, notes.py, quotes.py, final_docs.py and checks them against the index (read-only).
import sqlite3, json, re, sys
sys.path.insert(0, '/Users/jbotts/frus-analysis/c3/runs/r5')
import content as C
from notes import NOTES
from quotes import Q
from final_docs import F, ALL

R = '/Users/jbotts/frus-analysis/c3/runs/r5/'
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
QD = {qid: (v, d, t) for qid, v, d, t in Q}

TITLES = {
 'frus1877': 'Papers Relating to the Foreign Relations of the United States, 1877',
 'frus1878': 'Papers Relating to the Foreign Relations of the United States, 1878',
 'frus1889': 'Papers Relating to the Foreign Relations of the United States, 1889',
 'frus1895p1': 'Papers Relating to the Foreign Relations of the United States, 1895, Part I',
 'frus1900': 'Papers Relating to the Foreign Relations of the United States, 1900',
 'frus1913': 'Papers Relating to the Foreign Relations of the United States, 1913',
 'frus1915': 'Papers Relating to the Foreign Relations of the United States, 1915',
 'frus1916': 'Papers Relating to the Foreign Relations of the United States, 1916',
 'frus1917': 'Papers Relating to the Foreign Relations of the United States, 1917',
 'frus1919v01': 'Papers Relating to the Foreign Relations of the United States, 1919, Volume I',
 'frus1920v01': 'Papers Relating to the Foreign Relations of the United States, 1920, Volume I',
 'frus1921v02': 'Papers Relating to the Foreign Relations of the United States, 1921, Volume II',
 'frus1923v02': 'Papers Relating to the Foreign Relations of the United States, 1923, Volume II',
 'frus1930v01': 'Papers Relating to the Foreign Relations of the United States, 1930, Volume I',
 'frus1932v05': 'Foreign Relations of the United States, Diplomatic Papers, 1932, The American Republics, Volume V',
 'frus1933v05': 'Foreign Relations of the United States, Diplomatic Papers, 1933, The American Republics, Volume V',
 'frus1934v05': 'Foreign Relations of the United States, Diplomatic Papers, 1934, The American Republics, Volume V',
 'frus1936v05': 'Foreign Relations of the United States, Diplomatic Papers, 1936, The American Republics, Volume V',
 'frus1943v05': 'Foreign Relations of the United States, Diplomatic Papers, 1943, The American Republics, Volume V',
 'frus1944v07': 'Foreign Relations of the United States, Diplomatic Papers, 1944, The American Republics, Volume VII',
 'frus1945v09': 'Foreign Relations of the United States, Diplomatic Papers, 1945, The American Republics, Volume IX',
 'frus1948v09': 'Foreign Relations of the United States, 1948, The Western Hemisphere, Volume IX',
 'frus1949v02': 'Foreign Relations of the United States, 1949, The United Nations; The Western Hemisphere, Volume II',
 'frus1952-54v04': 'Foreign Relations of the United States, 1952–1954, The American Republics, Volume IV',
 'frus1958-60v06': 'Foreign Relations of the United States, 1958–1960, Cuba, Volume VI',
 'frus1961-63v12': 'Foreign Relations of the United States, 1961–1963, Volume XII, American Republics',
 'frus1961-63v10-12mSupp': 'Foreign Relations of the United States, 1961–1963, Volumes X/XI/XII, Microfiche Supplement, American Republics',
 'frus1964-68v31': 'Foreign Relations of the United States, 1964–1968, Volume XXXI, South and Central America; Mexico',
 'frus1969-76v21': 'Foreign Relations of the United States, 1969–1976, Volume XXI, Chile, 1969–1973',
 'frus1977-80v24': 'Foreign Relations of the United States, 1977–1980, Volume XXIV, South America; Latin America Region',
 'frus1977-80v15': 'Foreign Relations of the United States, 1977–1980, Volume XV, Central America',
}
missing = {v for v, d in ALL} - set(TITLES)
assert not missing, missing

def docnum(v, d):
    return db.execute("SELECT document_number FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()[0]

def cite(vd):
    v, d = vd.split('/')
    return '%s, Document %s, https://history.state.gov/historicaldocuments/%s/%s' % (TITLES[v], docnum(v, d), v, d)

cited_in_overview = set()
def expand(text):
    def c(m):
        cited_in_overview.add(m.group(1))
        return cite(m.group(1))
    return re.sub(r'\{C:([^}]+)\}', c, text)

# ---------------- overview.md ----------------
quotes_in_overview = []
out = []
out.append('# ' + C.TITLE + '\n')
out.append('## The bottom line\n')
out.append(expand(C.BL1) + '\n')
out.append(expand(C.BL2_INTRO) + '\n')
out.append('Series the printed documents came from (the first channel):\n')
for t in C.BL2_CAME: out.append('- ' + expand(t))
out.append('\nSeries the footnotes cite without printing (the second channel):\n')
for t in C.BL2_POINTED: out.append('- ' + expand(t))
out.append('')
out.append(expand(C.BL3) + '\n')
out.append(expand(C.SCOPE) + '\n')
out.append('## Decisions this needs from you\n')
for i, (h, t) in enumerate(C.DECISIONS, 1):
    out.append('%d. **%s** %s' % (i, h, t))
out.append('\n' + C.INCLUSION_RULE + '\n')
out.append('## Findings\n')
for i, (h, para, qs) in enumerate(C.FINDINGS, 1):
    out.append('### %d. %s\n' % (i, h))
    out.append(expand(para) + '\n')
    for qid, vd in qs:
        v, d, t = QD[qid]
        assert vd == v + '/' + d, (qid, vd)
        quotes_in_overview.append(qid)
        cited_in_overview.add(vd)
        out.append('- “%s” — %s' % (t, cite(vd)))
    out.append('')
out.append('## How this was done\n')
out.append(expand(C.HOWDONE) + '\n')
out.append('## Read next\n')
out.append(expand(C.READNEXT) + '\n')
overview = '\n'.join(out)
open(R + 'overview.md', 'w').write(overview)

# ---------------- collection ----------------
INTRO = ("What FRUS answers directly: once a government had taken power by force, the Department's working test was control of the country, the people's acceptance and the ability to meet international obligations; "
 "it departed from that test on purpose in Wilson's requirement of a constitutional election (1913 to 1920), in the Central American treaty rule it followed until 1936, and in wartime consultation over Argentina and Bolivia (1943 to 1944). "
 "What it asked was usually assurances on obligations, sometimes an election, a property or financial guarantee, civil liberties or proof of loyalty to the Allied cause; from 1948 recognition was separated from approval. "
 "Where FRUS points for the rest: the printed papers came almost entirely from the State Department's central decimal file (Record Group 59), whose National Archives identifiers are not in the bundled data; "
 "the one lot cited that resolves, the Policy Planning Staff's Lot 64 D 563 (Record Group 59), is divided among twelve series dated 1947 to 1962, all unrestricted where checked; the editors' footnotes cite unprinted central-file numbers in only about one document in thirty. "
 "What this request cannot get from FRUS: the Department's unprinted deliberations, the other governments' own reasoning, the terms on which relations with Peru's junta resumed in 1962, and anything before 1877 or after 1979, which I did not search.")
entries = []
qs_by_doc = {}
for h, para, qs in C.FINDINGS:
    for qid, vd in qs:
        qs_by_doc.setdefault(vd, []).append(qid)
for (heading, docs), (fh, _, _), prose in zip(F, C.FINDINGS, C.HEADINGS_PROSE):
    entries.append({"kind": "heading", "text": heading, "level": 1})
    entries.append({"kind": "prose", "text": prose})
    for v, d, date in docs:
        vd = v + '/' + d
        entries.append({"kind": "document", "volumeId": v, "documentId": d, "notes": ["%s: %s" % (C.RUN, NOTES[vd])]})
        for qid in qs_by_doc.get(vd, []):
            entries.append({"kind": "excerpt", "volumeId": v, "documentId": d, "text": QD[qid][2]})
entries.append({"kind": "heading", "text": "Threads I could not follow", "level": 1})
entries.append({"kind": "prose", "text": C.CLOSING_PROSE})
entries.append({"kind": "generated", "generatedBlockType": "archivalSources"})
coll = {
 "format": "fruscollection", "formatVersion": 2, "minimumReaderVersion": 1,
 "name": C.COLLECTION_NAME, "authorLine": C.AUTHOR_LINE, "introductionText": INTRO,
 "composition": {"defaultBodyDepth": "full", "footnoteStyle": "all", "includeSourceNote": True, "tocStyle": "citation", "applyHighlights": False, "includeNotes": True, "includeWordCloud": False},
 "entries": entries,
}
open(R + 'collection.fruscollection', 'w').write(json.dumps(coll, ensure_ascii=False, indent=1))

# ---------------- checks ----------------
rep = []
c2 = json.load(open(R + 'collection.fruscollection'))
assert c2['format'] == 'fruscollection' and c2['formatVersion'] == 2 and c2['minimumReaderVersion'] == 1
assert set(c2['composition']) == {"defaultBodyDepth", "footnoteStyle", "includeSourceNote", "tocStyle", "applyHighlights", "includeNotes", "includeWordCloud"}
pairs = []; nex = 0; ok_ex = 0
for e in c2['entries']:
    if e['kind'] in ('document', 'excerpt'):
        assert e.get('volumeId') and e.get('documentId'), e
        row = db.execute("SELECT body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (e['volumeId'], e['documentId'])).fetchone()
        assert row is not None, ('missing pair', e)
        assert not e['volumeId'].endswith('Ed2')
        if e['kind'] == 'document':
            pairs.append((e['volumeId'], e['documentId']))
            assert e['notes'][0].startswith(C.RUN)
        else:
            nex += 1
            ok_ex += 1 if e['text'] in row[0] else 0
assert len(pairs) == len(set(pairs)), 'duplicate document pair'
rep.append("collection: %d document entries (all pairs exist in document_cache, none duplicated, none Ed2), %d excerpts, %d of %d excerpts verbatim in body_text" % (len(pairs), nex, ok_ex, nex))
assert ok_ex == nex
# overview checks
qtexts = [QD[q][2] for q in quotes_in_overview]
missing_q = [q for q in quotes_in_overview if '“' + QD[q][2] + '”' not in overview]
assert not missing_q
# every double-quoted span in the overview that is longer than 60 characters must be one of the verified quotes
spans = re.findall(r'“([^”]{40,})”', overview)
unverified = [s for s in spans if s not in qtexts]
rep.append("overview: %d verbatim quotations, each in the verified quote table (unverified long spans: %d)" % (len(quotes_in_overview), len(unverified)))
assert not unverified, unverified
# every excerpt corresponds to a quotation in the overview and vice versa
ex_texts = {e['text'] for e in c2['entries'] if e['kind'] == 'excerpt'}
assert ex_texts == set(qtexts), (ex_texts ^ set(qtexts))
rep.append("excerpt set equals overview quotation set: %d" % len(ex_texts))
# every document the overview cites is in the collection
cset = {v + '/' + d for v, d in pairs}
not_in = sorted(x for x in cited_in_overview if x not in cset)
rep.append("overview cites %d distinct documents; not in collection: %s" % (len(cited_in_overview), not_in))
assert not not_in
# overview hygiene: no SQL words, no file paths
bad = [w for w in ['SELECT', 'document_cache', 'volume_id', 'document_id', '/Users/', 'FTS', 'rowid'] if w in overview]
rep.append("overview forbidden strings present: %s" % bad)
assert not bad
# quoted documents (distinct) in overview
qdocs = sorted({QD[q][0] + '/' + QD[q][1] for q in quotes_in_overview})
rep.append("distinct documents quoted in the overview: %d" % len(qdocs))
print('\n'.join(rep))
open(R + 'build_report.txt', 'w').write('\n'.join(rep) + '\n')
