# Aggregate the TEI scan (out/tei/<volume>.tsv; columns in out/tei_columns.txt). Counting surface: tag-stripped,
# whitespace-collapsed text of each <div type="document">; DOC = document text without <note> and without the
# document's own <head>; NOTE = footnotes (<note> other than type="source"). Matching is case-sensitive per variant.
# Joins: out/doc_paths.tsv (LA flag, apparatus flags, isdoc, date_iso), out/scope_S2.tsv (S2, A1).
# Reports: controls; variant split (DOC|NOTE) in the LA universe and in S2; recognition-family DOC/NOTE split by era;
# false-friend test (document shares) for the question's own terms against the control phrase; decade rates.
import os, collections, re
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
cols = open(R + "out/tei_columns.txt").readline().rstrip("\n").split("\t")
VAR = cols[5:]
DROP = {"frus1951-54IranEd2", "frus1969-76ve15p2Ed2"}
meta = {}
for line in open(R + "out/doc_paths.tsv"):
    v, d, fm, ed, di, la, p, isdoc = line.rstrip("\n").split("\t")
    meta[(v, d)] = (fm, ed, di, la, isdoc)
S2 = {}; A1 = set()
for line in open(R + "out/scope_S2.tsv"):
    f = line.rstrip("\n").split("\t"); S2[(f[0], f[1])] = f[2]
    if f[3] == "A1": A1.add((f[0], f[1]))
RECOG = ["recognize", "recognized", "recognizes", "recognizing", "Recognize_cap", "recognise", "recognised", "recognises", "recognising",
         "recognition", "Recognition_cap", "RECOGNITION_caps", "nonrecognition", "non-recognition", "non_recognition_space", "Nonrecognition_cap", "unrecognized"]
def era(di):
    if not di: return "undated"
    for lim, name in (("1913", "E1_to1912"), ("1930", "E2_1913-29"), ("1943", "E3_1930-42"), ("1949", "E4_1943-48"), ("1961", "E5_1949-60")):
        if di < lim: return name
    return "E6_1961-88"
vols_with_ctrl = set(); vols_all = set(); neg_total = 0; ctrl_docs = 0; ndocs = 0; unmatched = 0
tot = {k: collections.Counter() for k in ("LA", "S2", "A1", "ALL")}   # variant -> DOC/NOTE counts
docsets = {k: collections.Counter() for k in ("LA", "S2", "A1", "ALL")}  # per-document presence counts
den = collections.Counter()
recog_era = collections.defaultdict(lambda: [0, 0])  # (set, era) -> [DOC occurrences, NOTE occurrences]
recog_docs_era = collections.Counter(); la_docs_era = collections.Counter()
dec_hits = collections.defaultdict(collections.Counter); dec_den = collections.Counter()
for fn in sorted(os.listdir(R + "out/tei")):
    if not fn.endswith(".tsv"): continue
    vol = fn[:-4]
    if vol in DROP: continue
    vols_all.add(vol)
    vol_ctrl = 0
    for line in open(R + "out/tei/" + fn):
        f = line.rstrip("\n").split("\t")
        if len(f) < 5: continue
        did = f[1]; cells = f[5:]
        c = {VAR[i]: tuple(int(x) for x in cells[i].split("|")) for i in range(len(VAR))}
        vol_ctrl += c["CTRL_DeptOfState"][0]; neg_total += c["CTRL_impossible"][0]
        m = meta.get((vol, did))
        if not m: unmatched += 1; continue
        fm, ed, di, la, isdoc = m
        if fm == "1" or ed == "1" or isdoc != "1": continue
        ndocs += 1
        if c["CTRL_DeptOfState"][0] > 0: ctrl_docs += 1
        sets = ["ALL"] + (["LA"] if la == "1" else []) + (["S2"] if (vol, did) in S2 else []) + (["A1"] if (vol, did) in A1 else [])
        rd = sum(c[k][0] for k in RECOG); rn = sum(c[k][1] for k in RECOG)
        for s in sets:
            den[s] += 1
            for k in VAR:
                tot[s][k + "|DOC"] += c[k][0]; tot[s][k + "|NOTE"] += c[k][1]
                if c[k][0] > 0: docsets[s][k + "|DOC"] += 1
                if c[k][1] > 0: docsets[s][k + "|NOTE"] += 1
            if rd > 0: docsets[s]["RECOG_any|DOC"] += 1
            if rn > 0: docsets[s]["RECOG_any|NOTE"] += 1
            if rd == 0 and rn > 0: docsets[s]["RECOG_NOTE_only"] += 1
            e = era(di)
            recog_era[(s, e)][0] += rd; recog_era[(s, e)][1] += rn
        if la == "1" and di:
            dec = di[:3] + "0s"; dec_den[dec] += 1
            if rd > 0: dec_hits[dec][vol] += 1
    if vol_ctrl > 0: vols_with_ctrl.add(vol)
print("volumes scanned (Ed2 dropped):", len(vols_all), " volumes with the positive control 'Department of State':", len(vols_with_ctrl))
print("volumes WITHOUT the positive control:", sorted(vols_all - vols_with_ctrl))
print("negative control 'ZZZ_IMPOSSIBLE_ZZZ' occurrences:", neg_total)
print("TEI document divs not matched to the index:", unmatched, " non-apparatus documents counted:", ndocs, " with the control phrase:", ctrl_docs)
print("documents per set:", dict(den))
print()
print("variant\t" + "\t".join("%s_DOC\t%s_NOTE\t%s_docsDOC" % (s, s, s) for s in ("LA", "S2", "A1")))
for k in VAR:
    print(k + "\t" + "\t".join("%d\t%d\t%d" % (tot[s][k + "|DOC"], tot[s][k + "|NOTE"], docsets[s][k + "|DOC"]) for s in ("LA", "S2", "A1")))
print()
for s in ("LA", "S2", "A1", "ALL"):
    print("%s: documents with any recognition-family form in DOC text %d of %d; in footnotes %d; ONLY in footnotes %d" % (
        s, docsets[s]["RECOG_any|DOC"], den[s], docsets[s]["RECOG_any|NOTE"], docsets[s]["RECOG_NOTE_only"]))
print()
print("recognition-family occurrences DOC vs NOTE by era")
for s in ("S2", "LA"):
    for e in ("E1_to1912", "E2_1913-29", "E3_1930-42", "E4_1943-48", "E5_1949-60", "E6_1961-88"):
        d, n = recog_era[(s, e)]
        print("%s\t%s\tDOC %d\tNOTE %d\tNOTE share %d of %d" % (s, e, d, n, n, d + n))
print()
print("false-friend test (document shares, DOC surface): term in A1 (on-topic chapters) vs LA universe vs whole corpus")
for k in ("RECOG_any", "by_force", "coup_detat", "junta", "Junta_cap", "de_facto", "CTRL_DeptOfState"):
    key = k + "|DOC"
    if k == "CTRL_DeptOfState":
        print("%s\tA1 %d of %d\tLA %d of %d\tALL %d of %d   (control counted on the whole div)" % (k, docsets["A1"][key], den["A1"], docsets["LA"][key], den["LA"], docsets["ALL"][key], den["ALL"]))
    else:
        print("%s\tA1 %d of %d\tLA %d of %d\tALL %d of %d" % (k, docsets["A1"][key], den["A1"], docsets["LA"][key], den["LA"], docsets["ALL"][key], den["ALL"]))
print()
print("decade\tLA docs with recognition-family form in DOC\tLA dated docs\tper1000\ttop volume share")
for dec in sorted(dec_den):
    n = sum(dec_hits[dec].values()); top = dec_hits[dec].most_common(1)
    print("%s\t%d\t%d\t%.1f\t%s" % (dec, n, dec_den[dec], 1000.0 * n / dec_den[dec] if dec_den[dec] else 0, ("%s %d of %d" % (top[0][0], top[0][1], n)) if top else "-"))
