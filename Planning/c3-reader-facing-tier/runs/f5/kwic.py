import sys,re
K=re.compile(r"(USIA|USIS|Information (?:Agency|Service|Program)|information program|propaganda|psychological|cultural|educational exchange|exchange of persons|Voice of America|prestige|image|hearts and minds|Asian|Oriental|face|effective|ineffective|impact|neutralis|credib|goodwill|good will|audience|opinion|library|libraries|film|radio)",re.I)
def windows(txt,n=3,w=450):
    t=re.sub(r'\s+',' ',txt)
    pos=[m.start() for m in K.finditer(t)]
    if not pos: return []
    best=[]
    # score windows centered on each hit by count of hits within +-w
    import bisect
    sc=[]
    for p in pos:
        lo=bisect.bisect_left(pos,p-w); hi=bisect.bisect_right(pos,p+w)
        sc.append((hi-lo,p))
    sc.sort(key=lambda x:-x[0])
    chosen=[]
    for s,p in sc:
        if all(abs(p-q)>2*w for q in chosen):
            chosen.append(p)
        if len(chosen)>=n: break
    chosen.sort()
    return [(p,t[max(0,p-w):p+w]) for p in chosen]
if __name__=="__main__":
    n=int(sys.argv[1]); w=int(sys.argv[2])
    for a in sys.argv[3:]:
        v,d=a.split('/')
        txt=open(f"docs/{v}__{d}.txt").read()
        head=re.sub(r'\s+',' ',txt[:txt.index('BODY:')])[:260]
        print("=====",a,"|",head, "| len",len(txt))
        for p,s in windows(txt[txt.index('BODY:'):],n,w):
            print(f"  [@{p}] ...{s}...")
