"""Read-only verification of #234 gate status on this machine (stdlib only)."""
import csv, json, glob, os, subprocess
WT='/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5'
M2A='/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a'
out={}
rows=list(csv.DictReader(open(f'{WT}/Planning/early-era-people/m1a-eval-candidates.csv',encoding='utf-8')))
out['m1a_eval_rows']=len(rows)
out['m1a_eval_keyed']=sum(1 for r in rows if r['TRUE_IDENTITY_pocom_slug_or_name'].strip())
p=list(csv.DictReader(open(f'{M2A}/progress.csv')))
out['m2a_progress_rows']=len(p)
out['m2a_progress_marked']=sum(1 for r in p if r['annotated'].strip().lower() in ('y','none'))
out['m2a_progress_unmarked_by_band']={}
for r in p:
    if r['annotated'].strip()=='' :
        out['m2a_progress_unmarked_by_band'][r['band']]=out['m2a_progress_unmarked_by_band'].get(r['band'],0)+1
out['m2a_gold_spans']=sum(1 for _ in open(f'{M2A}/m2a-ground-truth.jsonl'))
out['m2a_gold_docs']=sum(1 for _ in open(f'{M2A}/m2a-ground-truth-documents.jsonl'))
sd=json.load(open(f'{M2A}/score-detections.json'))
out['score']={r['detector']:{m:{k:round(r[m][k],3) for k in ('precision','recall','f1')} for m in ('strict','relaxed')} for r in sd['results']}
out['score_documents']=sd['documents']; out['score_mentions']=sd['mentions']
tot=docs=0
for h in glob.glob(os.path.expanduser('~/frus-ner-raw/marked/*.head.json')):
    j=json.load(open(h)); tot+=j['mentions']; docs+=j['docs']
out['marked_layer']={'volumes':len(glob.glob(os.path.expanduser('~/frus-ner-raw/marked/*.head.json'))),'mentions':tot,'docs':docs}
for name,path in [('sweep_filtered','~/frus-ner-raw-filtered'),('control','~/frus-ner-raw-control'),('control_filtered','~/frus-ner-raw-control-filtered'),('sweep_boundary','~/frus-ner-raw-filtered-boundary')]:
    m=json.load(open(os.path.expanduser(path)+'/run-manifest.json'))
    t=m.get('totals') or m.get('totals_this_run')
    out[name]={k:t.get(k) for k in ('source_mentions','kept','removed','mentions','docs','secs','volumes')}
# app code reading NER stores
r=subprocess.run(['grep','-rln','-E','frus-ner|NERStore|ner_store|PersonMentionDetector|EarlyEraNER',f'{WT}/FRUSExplorer'],capture_output=True,text=True)
out['app_files_reading_ner_store']=[l for l in r.stdout.splitlines()]
r=subprocess.run(['grep','-rn','-i','-E','synthetic-ref|force-merge-only|index-version bump batching',f'{WT}/Planning/Completed/Issues-233-243-Plan.md'],capture_output=True,text=True)
out['archived_plan_rule_definition_lines']=[l[:160] for l in r.stdout.splitlines()]
json.dump(out,open(os.path.dirname(os.path.abspath(__file__))+'/verify_gates.json','w'),indent=1)
print(json.dumps(out,indent=1))
