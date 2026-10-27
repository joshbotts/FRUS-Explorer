# [TEI] Spelling-variant scan for Cuba names, with positive and negative controls, over all 553 volume XML files.
# Counting surface: TAG-STRIPPED (re.sub('<[^>]+>',' ')), html.unescape, whitespace-collapsed; WHOLE volume (apparatus NOT separated).
# Patterns are word-bounded, case-SENSITIVE (Python re) except where noted. One output line per volume (checkpointed).
import re, html, os, sys, glob
D = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
P = {
 "Cuba": r"\bCuba\b", "CUBA": r"\bCUBA\b", "Cuban": r"\bCuban\b", "Cubans": r"\bCubans\b", "CUBAN(S)": r"\bCUBANS?\b",
 "Havana": r"\bHavana\b", "Habana": r"\bHabana\b", "Havanna(h)": r"\bHavannah?\b", "HAVANA/HABANA": r"\b(HAVANA|HABANA)\b",
 "Isle_of_Cuba": r"\b[Ii]sland of Cuba\b",
 "POS_Department_of_State": r"\bDepartment of State\b", "NEG_ZZZ": r"ZZZ_IMPOSSIBLE_ZZZ",
}
C = {k: re.compile(v) for k, v in P.items()}
out = "tei_scan.tsv"
done = set(l.split("\t")[0] for l in open(out)) if os.path.exists(out) else set()
f = open(out, "a")
if not done: f.write("volume\t" + "\t".join(P) + "\n")
for path in sorted(glob.glob(D + "/*.xml")):
    v = os.path.basename(path)[:-4]
    if v in done: continue
    t = open(path, encoding="utf-8").read()
    t = " ".join(html.unescape(re.sub(r"<[^>]+>", " ", t)).split())
    f.write(v + "\t" + "\t".join(str(len(c.findall(t))) for c in C.values()) + "\n"); f.flush()
print("finished")
