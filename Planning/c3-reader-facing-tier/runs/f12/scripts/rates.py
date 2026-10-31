# per-million-character rates from out/tei_scan.tsv (TEI, tag-stripped, whole file incl. apparatus)
import csv
rows=list(csv.DictReader(open("/Users/jbotts/frus-analysis/c3f/runs/f12/out/tei_scan.tsv"),delimiter="\t"))
info={"frus1917-72PubDipv06","frus1917-72PubDipv07","frus1917-72PubDipv08","frus1955-57v09","frus1961-63v25","frus1969-76v38p2","frus1977-80v30"}
for fam in ["soft_power","image_of_US","psychological","propaganda","public_diplomacy","POS_Department_of_State","NEG_ZZZ"]:
    for name,sel in [("information vols (7)",lambda r:r["volume"] in info),("East Asia area vols (14)",lambda r:r["volume"] not in info)]:
        rs=[r for r in rows if sel(r)]; n=sum(int(r[fam]) for r in rs); ch=sum(int(r["chars_tagstripped"]) for r in rs)
        nz=sum(1 for r in rs if int(r[fam])>0)
        print(f"{fam:24s} {name:26s} count {n:6d} chars {ch:9d} per_million {n/ch*1e6:7.2f}  volumes_nonzero {nz} of {len(rs)}")
