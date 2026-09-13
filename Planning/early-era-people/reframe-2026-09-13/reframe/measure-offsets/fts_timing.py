#!/usr/bin/env python3
"""#234 reframe task 3 — can presence of a name be served by FTS5 at runtime?

Read-only (mode=ro). Times FTS5 MATCH queries on the live index's `frus_documents`
(external-content FTS5 over `document_cache`, tokenize='porter unicode61') for common
surnames, three runs each, in several shapes:
  corpus_count    — COUNT(*) of documents whose body_text column matches the term
  scope_count     — the same restricted to the 267 TEI-rule scope volumes (join document_cache)
  doc_presence    — does ONE given document contain the term (rowid = ? AND MATCH)
  volume_docs     — document ids in one volume matching (the per-volume facet shape)
  phrase          — a two-token phrase ("John Hay")
  vocab_lookup    — fts5vocab row lookup of the stemmed term's document count
Also measures how far porter stemming conflates a surname with ordinary words: over the
documents the MATCH returns in the scope volumes, the share whose body_text contains the
surname as a case-sensitive whole word.
"""
import sqlite3, time, json, os, re, statistics
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
OUT = os.path.dirname(os.path.abspath(__file__))
SCOPE = json.load(open(os.path.expanduser('~/frus-ner-raw/scope.json')))['volumes']
NAMES = ['Seward', 'Adams', 'Hay', 'Hull', 'Smith', 'Bliss', 'Wells', 'Blaine', 'Root', 'Hughes']
con = sqlite3.connect('file:' + DB + '?mode=ro', uri=True)
con.execute("CREATE TEMP TABLE scope(volume_id TEXT PRIMARY KEY)")  # temp schema only; main db is read-only
con.executemany("INSERT INTO scope VALUES (?)", [(v,) for v in SCOPE])

def timed(sql, args=(), runs=3):
    ts = []; res = None
    for _ in range(runs):
        t = time.perf_counter(); res = con.execute(sql, args).fetchall(); ts.append((time.perf_counter() - t) * 1000)
    return res, [round(x, 2) for x in ts]

out = {'fts_table': 'frus_documents', 'content_table': 'document_cache', 'sqlite_version': sqlite3.sqlite_version, 'queries': []}
# a probe document for doc_presence: first frus1861 doc
probe_rowid = con.execute("select rowid from document_cache where volume_id='frus1885' and document_id='d100'").fetchone()[0]
for name in NAMES:
    q = 'body_text:%s' % name
    rec = {'name': name}
    r, t = timed("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH ?", (q,)); rec['corpus_count'] = r[0][0]; rec['corpus_count_ms'] = t
    r, t = timed("SELECT COUNT(*) FROM frus_documents f JOIN document_cache dc ON dc.rowid = f.rowid JOIN scope s ON s.volume_id = dc.volume_id WHERE frus_documents MATCH ?", (q,)); rec['scope_count'] = r[0][0]; rec['scope_count_ms'] = t
    r, t = timed("SELECT 1 FROM frus_documents WHERE rowid = ? AND frus_documents MATCH ?", (probe_rowid, q)); rec['doc_presence'] = bool(r); rec['doc_presence_ms'] = t
    r, t = timed("SELECT dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid = f.rowid WHERE frus_documents MATCH ? AND dc.volume_id = 'frus1885'", (q,)); rec['volume_docs'] = len(r); rec['volume_docs_ms'] = t
    # stemming conflation: scope-volume matches whose body has the case-sensitive whole word
    rows = con.execute("SELECT dc.body_text FROM frus_documents f JOIN document_cache dc ON dc.rowid = f.rowid JOIN scope s ON s.volume_id = dc.volume_id WHERE frus_documents MATCH ?", (q,)).fetchall()
    pat = re.compile(r'(?<![A-Za-z])%s(?![A-Za-z])' % re.escape(name))
    rec['scope_matches_with_case_sensitive_word'] = sum(1 for (b,) in rows if pat.search(b))
    rec['scope_matches_total'] = len(rows)
    out['queries'].append(rec)
    print(json.dumps(rec))
for phrase in ['"John Hay"', '"William H. Seward"', '"Charles Francis Adams"', '"Cordell Hull"']:
    r, t = timed("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH ?", ('body_text:' + phrase,))
    rec = {'phrase': phrase, 'corpus_count': r[0][0], 'ms': t}; out['queries'].append(rec); print(json.dumps(rec))
for term in ['seward', 'hai', 'hull', 'bliss', 'well']:
    r, t = timed("SELECT term, doc, cnt FROM frus_documents_vocab WHERE term = ?", (term,))
    rec = {'vocab_term': term, 'row': r, 'ms': t}; out['queries'].append(rec); print(json.dumps(rec))
json.dump(out, open(os.path.join(OUT, 'fts-timing.json'), 'w'), indent=1)
