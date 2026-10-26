# Summarise work/tei/*.tsv (written by tei_scan.py). Counting surface: tag-stripped, whitespace-collapsed text of <div type="document" subtype="historical-document">; BODY excludes <note> descendants, NOTES = all <note> text.
import csv, collections, sys
RUN = "/Users/jbotts/frus-analysis/c3/runs/r1"
csv.field_size_limit(10**9)
rows = list(csv.reader(open(RUN + "/work/tei/variants_by_volume.tsv"), delimiter="\t"))
hdr = rows[0]; names = [h.replace("(hits/docs)", "") for h in hdr[2:]]
vols = rows[1:]
print("volumes scanned:", len(vols), "| historical-document divs:", sum(int(r[1]) for r in vols))
print("== whole-corpus totals by variant (hits, documents containing it), all 553 volumes, body+notes")
tot = {}
for i, n in enumerate(names):
    h = sum(int(r[2 + i].split("/")[0]) for r in vols); d = sum(int(r[2 + i].split("/")[1]) for r in vols)
    tot[n] = (h, d)
    print("  %-34s hits %8d  docs %7d" % (n, h, d))
ctrl = names.index("CTRL_pos_department_of_state")
z = [r[0] for r in vols if int(r[2 + ctrl].split("/")[0]) == 0]
print("positive control 'department of state': volumes with zero hits:", len(z), z)
neg = names.index("CTRL_neg_zzz")
print("negative control: total hits", sum(int(r[2 + neg].split("/")[0]) for r in vols))
# Latin American scope documents
docs = list(csv.reader(open(RUN + "/work/tei/variants_latam_docs.tsv"), delimiter="\t"))
dh = docs[0]; dn = [h.replace("(body/notes)", "") for h in dh[5:]]
D = docs[1:]
print("== Latin American scope documents scanned:", len(D))
print("  %-34s %10s %10s | docs: body-only / notes-only / both" % ("variant", "body hits", "notes hits"))
for i, n in enumerate(dn):
    bh = nh = 0; bo = no_ = both = 0
    for r in D:
        b, nn = (int(x) for x in r[5 + i].split("/"))
        bh += b; nh += nn
        if b and nn: both += 1
        elif b: bo += 1
        elif nn: no_ += 1
    print("  %-34s %10d %10d | %d / %d / %d  (documents with any: %d)" % (n, bh, nh, bo, no_, both, bo + no_ + both))
# union recognition family in scope docs
idx = {n: i for i, n in enumerate(dn)}
def any_hit(r, names_):
    return sum(int(r[5 + idx[n]].split("/")[0]) + int(r[5 + idx[n]].split("/")[1]) for n in names_)
fam = ["recognition_noun", "recognize_verb_z", "recognise_verb_s", "unrecognized_z", "unrecognised_s", "nonrecognition_hyphen", "nonrecognition_closed", "nonrecognition_spaced", "non_recognition_emdash_or_other"]
print("scope documents with any recognition-family word (TEI, body+notes):", sum(1 for r in D if any_hit(r, fam) > 0))
phr = ["PH_recog_gov_6", "PH_gov_recog_6"]
n_any = sum(1 for r in D if any_hit(r, phr) > 0)
n_body = sum(1 for r in D if any(int(r[5 + idx[n]].split("/")[0]) for n in phr))
n_notes_only = sum(1 for r in D if not any(int(r[5 + idx[n]].split("/")[0]) for n in phr) and any(int(r[5 + idx[n]].split("/")[1]) for n in phr))
print("scope documents with recognition within six words of government/regime/junta/administration: any %d | in the body %d | only in footnotes/source note %d" % (n_any, n_body, n_notes_only))
