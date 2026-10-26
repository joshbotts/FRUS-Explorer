# Literal share census of FTS hit lists (all hits; every list < 300). Text = header+dateline+source_note+body_text, whitespace collapsed. Python re, IGNORECASE.
# SQL per pair: SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?
import sqlite3, re
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
S = r'[\s\-,().]+'
T = [('hits_Estradadoctrine.txt', 'Estrada doctrine', r'Estrada'+S+r'doctrines?'),
     ('hits_Betancourtdoctrine.txt', 'Betancourt doctrine', r'Betancourt'+S+r'doctrines?'),
     ('hits_Stimsondoctrine.txt', 'Stimson doctrine', r'Stimson'+S+r'doctrines?'),
     ('hits_ResolutionXXXV.txt', 'Resolution XXXV', r'Resolutions?'+S+r'(?:XXXV|35)\b'),
     ('hits_ResolutionXXII.txt', 'Resolution XXII', r'Resolutions?'+S+r'(?:XXII|22)\b'),
     ('hits_Montevideoformula.txt', 'Montevideo formula', r'Montevideo'+S+r'formulas?'),
     ('hits_Tobar.txt', 'Tobar doctrine', r'Tobar'+S+r'doctrines?'),
     ('hits_Larreta.txt', 'Rodriguez Larreta', r'Rodr[ií]guez'+S+r'Larreta'),
     ('hits_Larreta.txt', 'Larreta proposal|note|doctrine', r'Larreta'+S+r'(?:proposals?|notes?|doctrines?|plan)')]
for fn, strict, tol in T:
    pairs = [l.strip().split('|') for l in open('/Users/jbotts/frus-analysis/c3/runs/r4/' + fn) if l.strip()]
    s = t = 0; ids = []
    for v, d in pairs:
        x = re.sub(r'\s+', ' ', ' '.join(y or '' for y in con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()))
        if re.search(re.escape(strict) if '|' not in strict else r'Larreta (?:proposal|note|doctrine)', x, re.I): s += 1
        if re.search(tol, x, re.I): t += 1; ids.append(v + '/' + d)
    print('%s | FTS hits %d | STRICT %d of %d | TOLERANT %d of %d | %s' % (strict, len(pairs), s, len(pairs), t, len(pairs), ' '.join(ids[:12])))
