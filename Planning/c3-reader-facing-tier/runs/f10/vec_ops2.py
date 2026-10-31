import sys,json
sys.path.insert(0,"/Users/jbotts/frus-analysis/c3f/runs/f10")
from vec_ops import *
mode=sys.argv[1]
if mode=="centroid":
    V=cent[:553]; Vn=V/np.linalg.norm(V,axis=1,keepdims=True)
    for a in sys.argv[2:]:
        i=vol_names.index(a); s=Vn@Vn[i]; o=np.argsort(-s)
        print("\nCENTROID neighbours of",a,"(raw centroid cosine; no calibration applies to volume centroids)")
        for j in o[1:9]: print("  %.3f %s %s"%(s[j],vol_names[j],"" if vol_names[j] in present else "[NOT IN LOCAL INDEX]"))
        rnd=[float(Vn[i]@Vn[k]) for k in range(553) if k!=i]
        print("  baseline: cosine to all other 552 volumes: mean %.3f sd %.3f min %.3f"%(np.mean(rnd),np.std(rnd),np.min(rnd)))
elif mode=="map":
    mi=json.load(open(RES+"semantic-map-index.json"))
    print("map-index keys",list(mi.keys()))
    cl=mi.get("clusters")
    print(json.dumps(cl[0])[:500] if isinstance(cl,list) else str(cl)[:300])
    # unclustered share
    unc=(placements["c"]==0xFFFF); print("unclustered %d of %d (%.1f%%)"%(unc.sum(),map_docs,100*unc.mean()))
    for a in sys.argv[2:]:
        v,i=a.split("/"); r=row_of[(v,i)]; c=int(placements["c"][r])
        lab=None
        if c!=0xFFFF and isinstance(cl,list):
            for x in cl:
                if x.get("id",x.get("cluster"))==c: lab=x; break
        print(a,"cluster",c if c!=0xFFFF else "UNCLUSTERED", json.dumps(lab)[:400] if lab else "")
