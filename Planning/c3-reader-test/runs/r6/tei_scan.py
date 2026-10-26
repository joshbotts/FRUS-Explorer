# TEI variant scan over the scope's volumes. Surfaces:
#  WHOLE = all text of the TEI file (tags stripped via ElementTree itertext), whitespace-collapsed (includes front matter, footnotes, index)
#  DOCTEXT = text of <div type="document"> elements only, with every <note> element removed, whitespace-collapsed
# Python re, case-INSENSITIVE except where a pattern says (?-i). One output line per volume, flushed.
import sys, re, xml.etree.ElementTree as ET, copy
V="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes/"
TEI="{http://www.tei-c.org/ns/1.0}"
PAT=[
("recognize_z", r"\brecogniz(?:e|es|ed|ing)\b"),
("recognise_s", r"\brecognis(?:e|es|ed|ing)\b"),
("recognition", r"\brecognitions?\b"),
("nonrecognition_closed", r"\bnonrecognition\b"),
("non-recognition_hyph", r"\bnon-recognition\b"),
("non_recognition_space", r"\bnon recognition\b"),
("de_facto", r"\bde facto\b"),
("de-facto_hyph", r"\bde-facto\b"),
("defacto_closed", r"\bdefacto\b"),
("coup_d_etat_accent", r"\bcoups? d[’']\s?état\b"),
("coup_d_etat_plain", r"\bcoups? d[’']\s?etat\b"),
("coup_detat_noapos", r"\bcoups? detat\b"),
("coup_bare", r"\bcoups?\b(?!\s*d[’']?\s?[ée]tat)"),
("junta", r"\bjuntas?\b"),
("by_force", r"\bby force\b"),
("CTRL_Department_of_State", r"\bDepartment of State\b"),
("CTRL_ZZZ_IMPOSSIBLE_ZZZ", r"ZZZ_IMPOSSIBLE_ZZZ"),
]
CP=[(n,re.compile(p,re.I)) for n,p in PAT]
def collapse(s): return re.sub(r"\s+"," ",s)
for vol in sys.argv[1:]:
    root=ET.parse(V+vol+".xml").getroot()
    whole=collapse(" ".join(root.itertext()))
    parts=[]
    for d in root.iter(TEI+"div"):
        if d.get("type")=="document":
            dc=copy.deepcopy(d)
            for parent in dc.iter():
                for ch in list(parent):
                    if ch.tag==TEI+"note": parent.remove(ch)
            parts.append(" ".join(dc.itertext()))
    doc=collapse(" ".join(parts))
    out=[vol,str(len(whole)),str(len(doc))]
    for n,c in CP: out+= [str(len(c.findall(whole))), str(len(c.findall(doc)))]
    print("\t".join(out), flush=True)
