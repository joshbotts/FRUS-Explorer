# Archival channels for the 1105 core docs. Came-from: document_sources (one row per doc). Pointed-at: external_citations (many rows per doc).
# SQL (per pair): SELECT citation_era, repository, record_group, series_name, lot_file_norm, decimal_class FROM document_sources WHERE volume_id=? AND document_id=?
#                 SELECT anchor, repository, collection, lot_file_norm, decimal_class, file_id, inherited FROM external_citations WHERE volume_id=? AND document_id=?
import csv, sqlite3, collections, json
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows = [r for r in csv.reader(open('/Users/jbotts/frus-analysis/c3/runs/r4/core.tsv'), delimiter='\t')]
era = collections.Counter(); rg = collections.Counter(); dc = collections.Counter(); lot = collections.Counter(); series = collections.Counter(); nosrc = 0
dcdocs = collections.defaultdict(set)
for r in rows:
    s = con.execute("SELECT citation_era, repository, record_group, series_name, lot_file_norm, decimal_class FROM document_sources WHERE volume_id=? AND document_id=?", (r[0], r[1])).fetchone()
    if not s: nosrc += 1; continue
    era[s[0]] += 1; rg[(s[1], s[2])] += 1; series[s[3]] += 1
    if s[4]: lot[s[4]] += 1
    if s[5]: dc[s[5]] += 1; dcdocs[s[5]].add(r[4][:4])
print('CAME-FROM (document_sources), core docs', len(rows), 'with a row', len(rows) - nosrc)
print(' citation_era', era.most_common())
print(' repository/RG', rg.most_common(12))
print(' series_name', series.most_common(12))
print(' lot_file_norm', lot.most_common(15))
print(' decimal_class top', [(k, n, min(dcdocs[k]), max(dcdocs[k])) for k, n in dc.most_common(25)])
anc = collections.Counter(); col = collections.Counter(); elot = collections.Counter(); edc = collections.Counter(); ndocs = set(); nrows = 0; edcyears = collections.defaultdict(set)
for r in rows:
    for a, rep, c, ln, d, fid, inh in con.execute("SELECT anchor, repository, collection, lot_file_norm, decimal_class, file_id, inherited FROM external_citations WHERE volume_id=? AND document_id=?", (r[0], r[1])):
        nrows += 1; ndocs.add((r[0], r[1])); anc[a] += 1; col[(rep, c)] += 1
        if ln: elot[ln] += 1
        if d: edc[d] += 1; edcyears[d].add(r[4][:4])
print('POINTED-AT (external_citations): rows', nrows, 'docs with any', len(ndocs), 'of', len(rows))
print(' anchor', anc.most_common())
print(' repository/collection', col.most_common(15))
print(' lot_file_norm', elot.most_common(15))
print(' decimal_class top', [(k, n, min(edcyears[k]), max(edcyears[k])) for k, n in edc.most_common(20)])
json.dump({'came_lots': lot.most_common(), 'pointed_lots': elot.most_common(), 'came_dc': dc.most_common(), 'pointed_dc': edc.most_common()}, open('/Users/jbotts/frus-analysis/c3/runs/r4/channels.json', 'w'))
