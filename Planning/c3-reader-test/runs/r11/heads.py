# Scan every TEI volume for div <head> text containing recogni*; write heads_recog.tsv
import re,glob,sys,os
D="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
out=open("heads_recog.tsv","w")
hre=re.compile(r'<div\b[^>]*type="(chapter|compilation|section|subchapter)"[^>]*>\s*<head[^>]*>(.*?)</head>',re.S)
for f in sorted(glob.glob(D+"/*.xml")):
    t=open(f,encoding="utf-8").read()
    v=os.path.basename(f)[:-4]
    for m in hre.finditer(t):
        h=re.sub(r'<[^>]+>','',m.group(2)); h=re.sub(r'\s+',' ',h).strip()
        if re.search(r'recogni|de facto|revolution|coup|junta|overthrow',h,re.I):
            out.write(f"{v}\t{m.group(1)}\t{h}\n")
    out.flush()
print("done",flush=True)
