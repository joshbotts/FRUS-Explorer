# stats2.py: false-friend test for the question's own terms 'national security' and 'prosperity'
import re
from h import *
c=con()
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
bands=[("1870-1946","1870","1947"),("1947-1989","1947","1990")]
def count(q,lo,hi):
    return c.execute("""SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
      WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN %s AND dd.date_iso>=? AND dd.date_iso<?"""%ED2,(q,lo,hi)).fetchone()[0]
def total(lo,hi):
    return c.execute("""SELECT COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
      WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN %s AND dd.date_iso>=? AND dd.date_iso<?"""%ED2,(lo,hi)).fetchone()[0]
for term,fts in [("national security",'"national security"'),("prosperity (stem prosper)","prosper")]:
    print("TERM",term)
    for name,lo,hi in bands:
        M=total(lo,hi)
        for lab,base in [("Cuba docs","(cuba OR cuban)"),("Mexico docs (control country)","(mexico OR mexican)")]:
            nb=count(base,lo,hi); nt=count(base+" AND "+fts,lo,hi)
            print("  %s | %s: %d of %d contain it (%.3f)"%(name,lab,nt,nb,nt/nb))
        na=count(fts,lo,hi); print("  %s | all dated non-apparatus docs: %d of %d (%.3f)"%(name,na,M,na/M))
