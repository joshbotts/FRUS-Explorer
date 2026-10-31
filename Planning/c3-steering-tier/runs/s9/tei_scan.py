# TEI variant scan. Counting surface: tag-stripped + whitespace-collapsed text, word-bounded regex.
# Surfaces: DOC = <body> outside <note>; NOTE = <note> inside <body>; FRONT = <front>; BACK = <back>.
import re, sys, os, json, glob, html
V = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
OUT = "/Users/jbotts/frus-analysis/c3s/runs/s9/tei_scan.jsonl"
VAR = {
 "corrupt": r"corrupt", "corruption": r"corruption", "corruptions": r"corruptions", "corrupted": r"corrupted",
 "corrupting": r"corrupting", "corruptly": r"corruptly", "corruptness": r"corruptness", "corruptible": r"(?:in)?corruptib(?:le|ility)",
 "corruptionist": r"corruptionists?",
 "bribe": r"bribe", "bribes": r"bribes", "bribed": r"bribed", "bribing": r"bribing", "bribery": r"bribery", "briberies": r"briberies", "briber": r"bribers?",
 "graft": r"graft", "grafter": r"grafters?", "embezzle_fam": r"embezzl\w*", "kickback": r"kick-?backs?",
 "payoff": r"pay-?offs?", "illicit_payment": r"illicit[\s\-]+payments?", "questionable_payment": r"questionable[\s\-]+payments?",
 "improper_payment": r"improper[\s\-]+payments?", "squeeze": r"squeeze", "venal_fam": r"venal(?:ity)?", "peculation": r"peculations?",
 "nepotism": r"nepotism", "koreagate": r"koreagate", "foreign_corrupt_practices": r"foreign[\s\-]+corrupt[\s\-]+practices",
 "POS_department_of_state": r"department[\s\-]+of[\s\-]+state", "NEG_zzz": r"zzz_impossible_zzz",
}
RX = {k: re.compile(r"\b" + v + r"\b", re.I) for k, v in VAR.items()}
def strip(s):
    s = re.sub(r"<[^>]+>", " ", s); s = html.unescape(s); return re.sub(r"\s+", " ", s)
done = set()
if os.path.exists(OUT):
    for l in open(OUT): done.add(json.loads(l)["vol"])
files = sorted(glob.glob(V + "/*.xml"))
lo, hi = int(sys.argv[1]), int(sys.argv[2])
with open(OUT, "a") as out:
    for fp in files[lo:hi]:
        vol = os.path.basename(fp)[:-4]
        if vol in done: continue
        x = open(fp, encoding="utf-8").read()
        x = re.sub(r"<teiHeader.*?</teiHeader>", " ", x, flags=re.S)
        def grab(tag):
            parts = re.findall(r"<%s\b[^>]*>(.*?)</%s>" % (tag, tag), x, flags=re.S); return " ".join(parts)
        front, back = grab("front"), grab("back")
        body = grab("body")
        notes = " ".join(re.findall(r"<note\b[^>]*>.*?</note>", body, flags=re.S))
        doc = re.sub(r"<note\b[^>]*>.*?</note>", " ", body, flags=re.S)
        surf = {"DOC": strip(doc), "NOTE": strip(notes), "FRONT": strip(front), "BACK": strip(back)}
        rec = {"vol": vol, "chars": {k: len(v) for k, v in surf.items()}, "counts": {}}
        for k, r in RX.items():
            c = {}
            for s, t in surf.items():
                ms = r.findall(t)
                if ms:
                    c[s] = {"n": len(ms), "lower": sum(1 for m in ms if m.islower()), "upper": sum(1 for m in ms if m.isupper() and len(m) > 1), }
                    c[s]["mixed"] = c[s]["n"] - c[s]["lower"] - c[s]["upper"]
            rec["counts"][k] = c
        out.write(json.dumps(rec) + "\n"); out.flush()
        print(vol, flush=True)
