# Intersects the FTS NEAR-family hits (out/fts_candidates_raw.tsv) with the Latin American document set and the curated
# recognition headings; writes out/core_set.tsv with channel flags and the document's date (document_dates.date_iso).
import sqlite3, collections
R="/Users/jbotts/frus-analysis/c3/runs/r7/out/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
fts=set()
for l in open(R+"fts_candidates_raw.tsv"):
    v,d=l.rstrip("\n").split("|"); fts.add((v,d))
latam={}
for l in open(R+"latam_docs.tsv"):
    v,d,p=l.rstrip("\n").split("\t"); latam[(v,d)]=p
heads={}
for l in open(R+"heading_recog_docs_curated.tsv"):
    v,d,p=l.rstrip("\n").split("\t"); heads[(v,d)]=p
dates={ (v,d):(iso or "") for v,d,iso in con.execute("SELECT volume_id, document_id, date_iso FROM document_dates") }
app={ (v,d) for v,d in con.execute("SELECT volume_id, document_id FROM document_cache WHERE is_front_matter=1 OR is_editorial_note=1") }
fts_na = {k for k in fts if k not in app and not (k[0] in ("frus1951-54IranEd2","frus1969-76ve15p2Ed2"))}
A = {k for k in fts_na if k in latam}          # FTS hit inside the Latin American document set
B = set(heads)                                  # under a curated recognition heading
core = A | B
out=open(R+"core_set.tsv","w")
out.write("volume_id\tdocument_id\tdate_iso\tin_fts\tin_heading\tpath\n")
for k in sorted(core, key=lambda k:(k[0], int(k[1][1:]) if k[1][1:].isdigit() else 0, k[1])):
    out.write(f"{k[0]}\t{k[1]}\t{dates.get(k,'')}\t{int(k in A)}\t{int(k in B)}\t{latam.get(k) or heads.get(k)}\n")
out.close()
print("fts hits (all, incl. apparatus):", len(fts), " non-apparatus non-Ed2:", len(fts_na))
print("A = fts & latam:", len(A), " B = curated headings:", len(B), " A&B:", len(A&B), " core = A|B:", len(core))
print("A only (fts hit outside any recognition heading):", len(A-B), " B only (heading doc without fts hit):", len(B-A))
dec=collections.Counter(); decA=collections.Counter()
for k in core:
    y=dates.get(k,"")[:3]
    dec[(y+"0s") if y else "undated"]+=1
for k in A:
    y=dates.get(k,"")[:3]; decA[(y+"0s") if y else "undated"]+=1
print("core by decade:", sorted(dec.items()))
print("A by decade:", sorted(decA.items()))
vol=collections.Counter(k[0] for k in A-B)
print("A-only top volumes:", vol.most_common(40))
