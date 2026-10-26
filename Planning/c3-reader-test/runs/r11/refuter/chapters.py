# For every TEI volume: walk div nesting, record each document div with its ancestor head chain.
# Keep a document when some ancestor head matches RECOG and the chain (or volume title) names a Latin American state.
import re,glob,os,sys,json
import xml.etree.ElementTree as ET
D="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
NS="{http://www.tei-c.org/ns/1.0}"; XID="{http://www.w3.org/XML/1998/namespace}id"
RECOG=re.compile(r'recogni|nonrecogni|non-recogni',re.I)
GOVT=re.compile(r'govern|regime|junta|provisional|de facto|president|revolution|administration|withhold|refusal|question of',re.I)
EXCL=re.compile(r'naturaliz|divorce|award|institution|blockade|meat|consul|judgment|labels|belliger|insurgen|independence of|Monroe',re.I)
LATAM=re.compile(r'Mexic|Guatemal|Hondur|Salvador|Nicaragu|Costa Rica|Panam|Cuba|Haiti|Dominican|Santo Domingo|Colombia|Venezuel|Ecuador|Peru|Bolivia|Chile|Argentin|Uruguay|Paraguay|Brazil|Central America|American Republics|Latin America|Western Hemisphere',re.I)
done=set()
if os.path.exists("chap_docs.tsv"):
    done={l.split("\t")[0] for l in open("chap_docs_done.txt")} if os.path.exists("chap_docs_done.txt") else set()
out=open("chap_docs.tsv","a"); dn=open("chap_docs_done.txt","a")
files=sorted(glob.glob(D+"/*.xml"))
for f in files:
    v=os.path.basename(f)[:-4]
    if v in done: continue
    stack=[]
    try:
        for ev,el in ET.iterparse(f,events=("start","end")):
            if el.tag==NS+"div":
                if ev=="start":
                    stack.append([el.get("type"),el.get(XID),None])
                else:
                    t,i,h=stack.pop()
                    if t=="document":
                        chain=[x[2] or "" for x in stack]
                        rec=[c for c in chain if RECOG.search(c) and GOVT.search(c) and not EXCL.search(c)]
                        if rec and LATAM.search(" ".join(chain)):
                            out.write("%s\t%s\t%s\n"%(v,i," || ".join(c[:160] for c in chain if c)))
                    el.clear()
            elif el.tag==NS+"head" and ev=="end" and stack and stack[-1][2] is None:
                stack[-1][2]=re.sub(r'\s+',' ',"".join(el.itertext())).strip()
    except Exception as e:
        print("ERR",v,e,flush=True)
    out.flush(); dn.write(v+"\n"); dn.flush()
print("done",flush=True)
