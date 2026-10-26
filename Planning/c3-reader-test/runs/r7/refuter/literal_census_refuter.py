# Literal-share census of the NEAR family over the core set (out/core_set.tsv, in_fts=1 rows, and separately every row).
# Surface: header + dateline + source_note + body_text concatenated, whitespace-collapsed (the index's own flattened text).
# TOLERANT: a token starting with recogni (also non-/un- prefixed), within 15 intervening words of an anchor phrase whose
#   words may take inflections and any run of space, hyphen, comma, parenthesis or full stop between them.
# STRICT: the recognition word exactly one of the listed forms, the anchor phrase exactly as the query spells it with single
#   spaces, and single spaces between the up-to-15 intervening words. Case-INSENSITIVE throughout (Python re.I).
import sqlite3, re, sys, json
R="/Users/jbotts/frus-analysis/c3/runs/r7/refuter/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows=[l.rstrip("\n").split("\t") for l in open("/Users/jbotts/frus-analysis/c3/runs/r7/refuter/core_refuter.tsv")][1:]
S=r"[\s\-,().]+"
anchors_t = [r"de"+S+r"facto", r"juntas?", r"coups?", r"provisional"+S+r"governments?", r"revolutionary"+S+r"governments?",
  r"new"+S+r"governments?", r"new"+S+r"regimes?", r"military"+S+r"governments?", r"revolutionary"+S+r"regimes?",
  r"military"+S+r"regimes?", r"provisional"+S+r"presidents?", r"revolutionary"+S+r"juntas?", r"military"+S+r"juntas?",
  r"de"+S+r"jure", r"constitutional"+S+r"governments?", r"overthr(?:ow|own|owing|ows|ew)", r"revolutions?", r"golpes?", r"unconstitutional\w*"]
anchors_s = ["de facto","junta","coup","provisional government","revolutionary government","new government","new regime",
  "military government","revolutionary regime","military regime","provisional president","revolutionary junta","military junta",
  "de jure","constitutional government","overthrow","overthrown","revolution","golpe","unconstitutional"]
REC_T = r"(?:non-?|un-?)?recogni\w*"
REC_S = r"(?:recognition|recognize|recognized|recognizes|recognizing|recognise|recognised|recognises|recognising|nonrecognition|non-recognition|unrecognized|unrecognised)"
AT="(?:"+"|".join(anchors_t)+")"; AS="(?:"+"|".join(re.escape(a) for a in anchors_s)+")"
tol = re.compile(r"\b"+REC_T+r"(?:\W+\w+){0,15}?\W+"+AT+r"\b|\b"+AT+r"(?:\W+\w+){0,15}?\W+"+REC_T+r"\b", re.I)
strict = re.compile(r"\b"+REC_S+r"(?: \S+){0,15} "+AS+r"\b|\b"+AS+r"(?: \S+){0,15} "+REC_S+r"\b", re.I)
out=open(R+"literal_census.tsv","w")
out.write("volume_id\tdocument_id\tin_fts\tin_heading\ttolerant\tstrict\tchars\n")
n=0
for vid,did,iso,in_fts,in_head in rows:
    h,dl,sn,b = con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?",(vid,did)).fetchone()
    text=" ".join(" ".join([h or "",dl or "",sn or "",b or ""]).split())
    t=1 if tol.search(text) else 0
    s=1 if strict.search(text) else 0
    out.write(f"{vid}\t{did}\t{in_fts}\t{in_head}\t{t}\t{s}\t{len(text)}\n")
    n+=1
    if n%200==0:
        out.flush(); open(R+"literal_census.progress","w").write(str(n))
out.close(); open(R+"literal_census.progress","w").write("done "+str(n))
