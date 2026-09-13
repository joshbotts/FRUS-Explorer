import json, glob, os, csv, collections
H=os.path.expanduser
out={}
# marked layer
heads=glob.glob(H('~/frus-ner-raw/marked/*.head.json'))
m=d=0; keys=collections.Counter()
for h in heads:
    j=json.load(open(h)); keys.update(j.keys())
    m+=j.get('mentions', j.get('mention_count',0)) if isinstance(j.get('mentions'),int) else 0
    d+=j.get('docs', j.get('documents',0)) if isinstance(j.get('docs'),int) else 0
out['marked']={'heads':len(heads),'mentions_sum':m,'docs_sum':d,'keys':dict(keys)}
# manifests
for name,p in [('control','~/frus-ner-raw-control/run-manifest.json'),('control_filtered','~/frus-ner-raw-control-filtered/run-manifest.json'),('filtered','~/frus-ner-raw-filtered/run-manifest.json'),('boundary','~/frus-ner-raw-filtered-boundary/run-manifest.json'),('studio','/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw/run-manifest.json')]:
    try:
        j=json.load(open(H(p)))
        out[name]={k:v for k,v in j.items() if not isinstance(v,(list,dict)) or k in ('totals','totals_this_run','removed','removed_by_rule','counts','volumes_missing')}
        out[name]['_keys']=list(j.keys())
    except Exception as e: out[name]=str(e)
out['local_detected_files']=len(glob.glob(H('~/frus-ner-raw/detected/*')))
out['studio_detected_files']=len(glob.glob('/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw/detected/*'))
# m2a
M='/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/'
rows=list(csv.DictReader(open(M+'progress.csv')))
out['progress']={'rows':len(rows),'cols':list(rows[0].keys()),'annotated':dict(collections.Counter(r.get('annotated','') for r in rows))}
out['gold_lines']=sum(1 for _ in open(M+'m2a-ground-truth.jsonl'))
out['gold_doc_lines']=sum(1 for _ in open(M+'m2a-ground-truth-documents.jsonl'))
gd=[json.loads(l) for l in open(M+'m2a-ground-truth-documents.jsonl')]
out['gold_doc_keys']=list(gd[0].keys())
gs=[json.loads(l) for l in open(M+'m2a-ground-truth.jsonl')]
out['gold_span_keys']=list(gs[0].keys())
# editor-marked share by collector: spans flagged editor?
ek=[k for k in gs[0].keys() if 'edit' in k.lower() or 'seed' in k.lower() or 'source' in k.lower()]
out['gold_editor_keys']=ek
for k in ek:
    out['gold_'+k]=dict(collections.Counter(str(s.get(k)) for s in gs))
try: out['m2a_manifest']=json.load(open(M+'m2a-manifest.json'))
except Exception as e: out['m2a_manifest']=str(e)
# score
S=json.load(open(M+'score-detections.json'))
out['score_top_keys']=list(S.keys())
json.dump(out,open(os.path.dirname(__file__)+'/stores.json','w'),indent=1,default=str)
print(json.dumps(out,indent=1,default=str)[:6000])
