# came_from_classes.py: re-aggregates the came-from channel over scope_pairs.tsv by repository/record group, and for
# citation_era='decimal' rows by the decimal class+subject (first 6 characters of series_name, e.g. 824.01), glossed from
# decimal-class-labels.json only when the document's own date falls inside coverage.glossableYears. Also the literal share
# of 'recogni' over the FTS-mode Set A pairs (STRICT: recognition|recognize(s|d)|recognizing|recognised; TOLERANT: recogni\w*).
import sqlite3,collections,json,re,os
os.chdir('/Users/jbotts/frus-analysis/c3/runs/r9')
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
scope=[l.split('\t') for l in open('scope_pairs.tsv').read().splitlines()]
lab=json.load(open('/Applications/FRUS Explorer.app/Contents/Resources/decimal-class-labels.json'))
print('decimal-class-labels keys:',list(lab.keys())[:12]); cov=lab.get('coverage',{}); print('coverage keys:',list(cov.keys())); print('glossableYears:',cov.get('glossableYears'))
repo=collections.Counter(); cls=collections.Counter(); suffix=collections.Counter(); yrs=collections.defaultdict(set)
for v,d,ch in scope:
    r=con.execute("SELECT repository, record_group, series_name, citation_era FROM document_sources WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: continue
    repo[(r[0] or '-', r[1] or '-')]+=1
    if r[3]=='decimal' and r[2]:
        m=re.match(r'(\d{3})\.(\d{2,4})',r[2])
        if m:
            k=m.group(1)+'.'+m.group(2)[:2]; cls[k]+=1; suffix['.'+m.group(2)[:2]]+=1
            dd=con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
            if dd and dd[0]: yrs[k].add(int(dd[0][:4]))
print('\nCAME-FROM by repository/record group:'); 
for k,n in repo.most_common(12): print(' ',n,k)
print('\ndecimal came-from rows by subject suffix (.00 political affairs, .01 government/recognition):')
for k,n in suffix.most_common(8): print(' ',n,k)
print('\ntop decimal classes (country.subject), with document years:')
for k,n in cls.most_common(16): print(' ',n,k,'years',min(yrs[k]),'-',max(yrs[k]))
json.dump({'repo':{str(k):n for k,n in repo.items()},'classes':dict(cls),'suffix':dict(suffix)},open('came_from_classes.json','w'),indent=1)
# literal share over FTS-mode Set A pairs
fts=[l.split('\t') for l in open('setA_pairs.tsv').read().splitlines() if l.split('\t')[2]=='fts']
strict=re.compile(r'\b(recognition|recognizes?|recognized|recognizing|recognised|recognise)\b',re.I); tol=re.compile(r'recogni\w*',re.I)
ns=nt=0
for v,d,mode,label in fts:
    r=con.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    t=' '.join(' '.join(x or '' for x in r).split()); ns+=bool(strict.search(t)); nt+=bool(tol.search(t))
print(f"\nSet A fts-mode pairs literal share: STRICT {ns} of {len(fts)}; TOLERANT {nt} of {len(fts)}")
