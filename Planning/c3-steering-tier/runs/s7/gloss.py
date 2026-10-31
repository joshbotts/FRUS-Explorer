import json,sys
sys.path.insert(0,"/Users/jbotts/frus-analysis/c3s/runs/s7")
from db import *
R="/Applications/FRUS Explorer.app/Contents/Resources/"
dl=json.load(open(R+"decimal-class-labels.json"))
for s in dl["schedules"]:
    print(s["id"], "classes:",json.dumps(s["classes"])[:200]); print("  countries sample:",json.dumps(dict(list(s["countries"].items())[:3])) if isinstance(s["countries"],dict) else json.dumps(s["countries"][:3])); print("  subjects sample:",json.dumps(s["subjects"])[:300])
for cls in ["893.00","751G.00","795B.00","788.00","861.00","751J.00"]:
    r=q("WITH h AS (SELECT DISTINCT c.volume_id v, c.document_id d FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt* OR briberi OR bribe*' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')) SELECT MIN(dd.date_iso),MAX(dd.date_iso),COUNT(*) FROM h JOIN document_sources s ON s.volume_id=h.v AND s.document_id=h.d JOIN document_dates dd ON dd.volume_id=h.v AND dd.document_id=h.d WHERE s.decimal_class=?",(cls,),"gloss-span")
    print(cls, r)
