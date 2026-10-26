# TEI: every document div whose ancestor head chain names a Latin American state/region -> latam_docs.tsv (vol, doc, first matching ancestor head)
import re,glob,os
import xml.etree.ElementTree as ET
D="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
NS="{http://www.tei-c.org/ns/1.0}"; XID="{http://www.w3.org/XML/1998/namespace}id"
LATAM=re.compile(r'Mexic|Guatemal|Hondur|Salvador|Nicaragu|Costa Rica|Panam|Cuba|Haiti|Dominican|Santo Domingo|Colombia|Venezuel|Ecuador|Peru\b|Bolivia|Chile|Argentin|Uruguay|Paraguay|Brazil|Central America|American Republics|Latin America|Western Hemisphere|Inter-American|Caribbean',re.I)
out=open("latam_docs.tsv","w")
for f in sorted(glob.glob(D+"/*.xml")):
    v=os.path.basename(f)[:-4]; stack=[]
    for ev,el in ET.iterparse(f,events=("start","end")):
        if el.tag==NS+"div":
            if ev=="start": stack.append([el.get("type"),el.get(XID),None])
            else:
                t,i,h=stack.pop()
                if t=="document":
                    ch=[x[2] or "" for x in stack]
                    m=[c for c in ch if LATAM.search(c[:200])]
                    if m: out.write("%s\t%s\t%s\n"%(v,i,m[0][:120]))
                el.clear()
        elif el.tag==NS+"head" and ev=="end" and stack and stack[-1][2] is None:
            stack[-1][2]=re.sub(r'\s+',' ',"".join(el.itertext())).strip()
    out.flush()
print("done",flush=True)
