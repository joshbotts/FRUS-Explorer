# Cross-checks overview.md: every history.state.gov pair is in the collection; every quoted span (straight double quotes) is a substring of a verified quote in quotes.json or of the cited document's body_text.
import re, json, sqlite3
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
ov = open('/Users/jbotts/frus-analysis/c3/runs/r4/overview.md').read()
col = json.load(open('/Users/jbotts/frus-analysis/c3/runs/r4/collection.fruscollection'))
pairs = {(e['volumeId'], e['documentId']) for e in col['entries'] if e['kind'] == 'document'}
cited = set(re.findall(r'historicaldocuments/([^/\s)]+)/(d\w+)', ov))
print('cited', len(cited), 'in collection', len(cited & pairs), 'missing', cited - pairs, 'collection not cited', pairs - cited)
Q = [q for v, d, q in json.load(open('/Users/jbotts/frus-analysis/c3/runs/r4/quotes.json'))]
ex = [e['text'] for e in col['entries'] if e['kind'] == 'excerpt']
spans = [x for x in re.findall(r'"([^"]*)"', ov) if len(x) >= 25]
bad = [x for x in spans if not any(x in q for q in Q)]
print('quoted spans >=25 chars', len(spans), 'not inside a verified quote', bad)
print('excerpts', len(ex), 'all verified quotes', all(e in Q for e in ex))
