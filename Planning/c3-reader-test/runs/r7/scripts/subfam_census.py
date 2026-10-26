# Literal-share census for each sub-family's hits INSIDE the core set (whole set, all under 300): TOLERANT and STRICT, same
# surface and rules as literal_census.py (recogni* token within 15/20/30 intervening words of the family's anchor, both orders).
import sqlite3, re, os, glob, sys
R="/Users/jbotts/frus-analysis/c3/runs/r7/out/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
S=r"[\s\-,().]+"
# name: (window, tolerant anchor regex, strict anchor alternatives)
F={
 "intl_obligations": (20, r"international"+S+r"obligations?", ["international obligations"]),
 "obligations_any": (15, r"obligations?", ["obligations"]),
 "elections": (15, r"elect(?:ions?|ed|oral|ing|s)?", ["election","elections"]),
 "free_elections": (20, r"free"+S+r"elections?", ["free elections"]),
 "constitutional": (15, r"constitution\w*", ["constitution","constitutional","constitutionally"]),
 "consultation": (15, r"consult\w*", ["consultation","consult","consulted","consultations"]),
 "effective_control": (15, r"controls?", ["control"]),
 "civil_liberties": (20, r"civil"+S+r"liberties|civil"+S+r"rights|freedom"+S+r"of"+S+r"the"+S+r"press|political"+S+r"prisoners?", ["civil liberties","civil rights","freedom of the press","political prisoners"]),
 "human_rights": (20, r"human"+S+r"rights", ["human rights"]),
 "communist": (20, r"communis\w*", ["communist","communists","communism"]),
 "nazi_axis": (20, r"nazis?\w*|axis", ["nazi","nazis","axis"]),
 "approval": (15, r"approv(?:al|e|ed|es|ing)", ["approval","approve"]),
 "treaty_1923": (30, r"treaty"+S+r"of"+S+r"peace"+S+r"and"+S+r"amity|1923"+S+r"treaty|article"+S+r"ii\b", ["treaty of peace and amity","1923 treaty","article II"]),
 "bogota_resolution": (30, r"bogot[aá]|resolution"+S+r"xxxv|resolution"+S+r"35", ["bogota","Bogotá","resolution xxxv","resolution 35"]),
 "intervention": (15, r"interventions?|internal"+S+r"affairs", ["intervention","internal affairs"]),
 "assurances": (15, r"assurances?|undertakings?|pledg(?:e|es|ed|ing)|commitments?", ["assurances","undertakings","pledge","pledges","pledged","commitments"]),
 "conditions": (15, r"conditions?", ["conditions","condition"]),
 "withhold": (10, r"withh\w*|refus\w*|suspend\w*|deferr\w*|delay\w*", ["withhold","withholding","withheld","refuse","refused","refusal","suspend","suspended","suspension","deferred","delay","delayed"]),
}
REC_T = r"(?:non-?|un-?)?recogni\w*"
REC_S = r"(?:recognition|recognize|recognized|recognizes|recognizing|recognise|recognised|recognises|recognising|nonrecognition|non-recognition|unrecognized|unrecognised)"
core={}
for l in list(open(R+"core_set.tsv"))[1:]:
    v,d,iso,a,b,p=l.rstrip("\n").split("\t"); core[(v,d)]=iso
cache={}
def text(v,d):
    if (v,d) not in cache:
        h,dl,sn,b=con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        cache[(v,d)]=" ".join(" ".join([h or "",dl or "",sn or "",b or ""]).split())
    return cache[(v,d)]
out=open(R+"subfam_census_summary.tsv","a")
for name,(N,at,ss) in F.items():
    fn=R+f"subfam_{name}.tsv"
    if not os.path.exists(fn): print("skip (no file yet):", name); continue
    hits=[tuple(l.split("\t")[:2]) for l in open(fn) if l.rstrip("\n").endswith("\t1")]
    AT="(?:"+at+")"; AS="(?:"+"|".join(re.escape(a) for a in ss)+")"
    tol=re.compile(r"\b"+REC_T+r"(?:\W+\w+){0,%d}?\W+"%N+AT+r"\b|\b"+AT+r"(?:\W+\w+){0,%d}?\W+"%N+REC_T+r"\b", re.I)
    st=re.compile(r"\b"+REC_S+r"(?: \S+){0,%d} "%N+AS+r"\b|\b"+AS+r"(?: \S+){0,%d} "%N+REC_S+r"\b", re.I)
    t=s=0
    for v,d in hits:
        x=text(v,d); t+=bool(tol.search(x)); s+=bool(st.search(x))
    n=len(hits)
    line=f"{name}\tcore hits {n}\tTOLERANT {t} of {n} = {t/n if n else 0:.3f}\tSTRICT {s} of {n} = {s/n if n else 0:.3f}"
    print(line); out.write(line+"\n"); out.flush()
