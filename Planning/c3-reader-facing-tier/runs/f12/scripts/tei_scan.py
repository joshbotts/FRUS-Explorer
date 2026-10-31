# TEI scan. Counting surface: tag-stripped (all <...> removed), entities for &amp; etc. unescaped, whitespace-collapsed,
# WHOLE FILE (document text + apparatus: front matter, footnotes, index are NOT separated). Case-insensitive regex.
import re,sys,html,os
VD="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
FAM={
 "soft_power": r"\bsoft[\s\-]+power\b",
 "public_diplomacy": r"\bpublic[\s\-]+diplomacy\b",
 "image_of_US": r"\b(image|images) of (the United States|the U\.\s?S\.|America)\b|\b(U\.\s?S\.|US|American|America's|America’s) (image|images)\b",
 "image_of_US__US_image_form": r"\b(U\.\s?S\.|US|American|America's|America’s) (image|images)\b",
 "image_of_US__image_of_form": r"\b(image|images) of (the United States|the U\.\s?S\.|America)\b",
 "psychological": r"\bpsychological\w*\b",
 "psyop_acronyms": r"\b(PSYOPS?|psywar|psy[\s\-]?ops?)\b",
 "propaganda": r"\bpropaganda\w*\b",
 "USIA_USIS_acronym": r"\bUSI[AS]\b",
 "USIA_spelled": r"\bUnited States Information (Agency|Service)\b",
 "POS_Department_of_State": r"\bDepartment of State\b",
 "NEG_ZZZ": r"ZZZ_IMPOSSIBLE_ZZZ",
}
out=open(sys.argv[1],"a")
for v in sys.argv[2:]:
    p=os.path.join(VD,v+".xml")
    t=open(p,encoding="utf-8").read()
    t=re.sub(r"<[^>]+>"," ",t); t=html.unescape(t); t=re.sub(r"\s+"," ",t)
    row=[v,str(len(t))]+[str(len(re.findall(rx,t,flags=re.I))) for rx in FAM.values()]
    out.write("\t".join(row)+"\n"); out.flush(); print("\t".join(row),flush=True)
