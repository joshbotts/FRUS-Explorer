#!/usr/bin/env python3
"""Part 3: ONE READER'S JUDGEMENT (Claude, this session) over the 80 cases in cases.txt
(10 per band x {POCOM 'nobody in office', POCOM 'several in office'}, random.Random(234)).
determines: plain = head/local context names the post/place (or the full name/signature) so that, with the year, a
            reader picks one person without outside knowledge beyond the candidate records' posts;
            plausible = determinable by convention or outside knowledge (e.g. a despatch 'to Mr. Seward' in 1863 is the
            Secretary; 'Consul at Tientsin' needs a consular roster no candidate source carries);
            cannot = this reader could not settle it from the document and candidates.
truth_in_union: does the union candidate list (5 sources) contain the person this reader believes is meant.
No gold exists; these labels are unverified."""
import json, math, collections
R = {
 1:("plain","no","Earl Russell = British Foreign Secretary; sole union candidate Thomas Russell (US, Venezuela) is wrong"),
 2:("plausible","no","US consul at Halifax; sole union candidate Henry Rootes Jackson is wrong"),
 3:("plausible","no","Commander, USN, the Vanderbilt; no candidate"),
 4:("plain","no","Mexican Legation: Matias Romero; no candidate"),
 5:("cannot","unknown","Caracas legation 1868; sole candidate R. H. Pruyn (Japan 1861-65) doubtful"),
 6:("plausible","no","New Granada treaty note: Colombian minister; no candidate"),
 7:("plausible","yes","1874, F. W. Seward out of office: G. F. Seward; union 2"),
 8:("plausible","yes","Winslow extradition, London: Wickham Hoffman (secretary of legation); union 1"),
 9:("plain","yes","Trescot, special mission Chile; union 1"),
 10:("cannot","unknown","Madrid telegram 1896; sole candidate David Armstrong implausible"),
 11:("plausible","no","Commander, USS Marietta; no candidate"),
 12:("plain","yes","'President Wilson'; union 13"),
 13:("plain","yes","'President Wilson'; union 9"),
 14:("plain","no","'Minister Blanchard', file 838 Haiti = Bailly-Blanchard; hyphenated surname misses every key"),
 15:("plain","yes","Charge in Guatemala; union 1"),
 16:("plain","yes","Charge in Peru; union 1"),
 17:("plain","no","Solicitor for the Department (Hyde); no candidate"),
 18:("plain","yes","Charge in China 1925: Ferdinand L. Mayer; union 2 (other b.1903)"),
 19:("plain","yes","Charge in France; union 1"),
 20:("plain","yes","Charge in Great Britain; union 2 = same man twice (rollup without authority id)"),
 21:("plain","yes","Charge in France; union 1"),
 22:("plain","yes","Chief, Near Eastern Affairs; union 1"),
 23:("plain","yes","Chief of Naval Operations; union 1"),
 24:("plain","yes","Charge in Chile; union 1"),
 25:("plain","yes","Officer in Charge at New Delhi; union 1"),
 26:("plain","yes","'President Roosevelt'; union 6 incl. a junk index-entry rollup"),
 27:("plain","yes","Charge in the UK; union 1"),
 28:("plain","yes","Administrator, FEA; union 1"),
 29:("plain","yes","Political Adviser for Germany; union 3 (same man twice)"),
 30:("plausible","no","Consul at Tientsin; union 4, none plausible"),
 31:("plain","yes","Deputy Director, European Affairs; union 1"),
 32:("plain","yes","Charge in Yugoslavia; union 1"),
 33:("plain","yes","'General of the Army Douglas MacArthur'; union 2 (vs MacArthur II)"),
 34:("plain","no","Chairman, Intl Railways of Central America; no candidate"),
 35:("plain","yes","'Brigadier General Marshall S. Carter'; union 4"),
 36:("plausible","yes","Air Force rep on regulation of armaments: Pierpont M. Hamilton USAF; union 6"),
 37:("plain","yes","Minister-Counselor in China 1949: Lewis Clark; union 12"),
 38:("plain","yes","Charge at Saigon; union 1"),
 39:("plain","yes","CINC Far East; union 1"),
 40:("plain","yes","Executive Secretary, NSC; union 1"),
 41:("plausible","yes","1863 'Mr. Adams to Mr. Seward': the Secretary by convention; F. W. also in office"),
 42:("plausible","yes","'Mr. Seward to Senor Tassara', Dept of State 1863: by convention W. H."),
 43:("plausible","yes","as 41"),
 44:("plausible","yes","French legation to 'Mr. Seward' 1864: by convention W. H."),
 45:("plain","yes","signature WILLIAM H. SEWARD inside first 300 chars"),
 46:("plausible","yes","as 42"),
 47:("plausible","yes","Berlin, 1 May 1865 (both Sewards injured in April): addressee still the Secretary by convention"),
 48:("plausible","yes","Swiss consul general, 15 Apr 1865: as 47"),
 49:("plausible","yes","'Mr. Davis', Dept of State 1883: John Davis (J.C.B. Davis left 1882) — needs outside knowledge"),
 50:("plain","yes","Legation Vienna 1893 + signature Frederick D. Grant"),
 51:("plain","yes","'Ambassador Wilson' 1910: only Henry Lane Wilson held an embassy"),
 52:("plain","yes","'Ambassador O'Brien', Tokyo"),
 53:("plain","yes","'President Wilson'"),
 54:("plain","yes","Ambassador in Italy (Page)"),
 55:("plain","yes","Ambassador in Great Britain (Page) in the enclosure"),
 56:("plausible","yes","'Ambassador Page' + British 'Secretary of State for Foreign Affairs': London"),
 57:("plain","yes","Ambassador in Great Britain (Page)"),
 58:("plain","yes","Ambassador in Great Britain (Davis) 1919; union 9 incl. John W. Davis under two ids"),
 59:("plain","yes","Minister in Liberia (Johnson)"),
 60:("plain","yes","Minister in Liberia (Johnson)"),
 61:("plain","yes","Minister in Switzerland (Wilson) = Hugh R."),
 62:("plain","yes","as 61"),
 63:("plain","yes","Ambassador in Italy (Long) 1936 = Breckinridge Long; union 4 incl. him under 3 ids"),
 64:("plain","yes","Ambassador in China (Johnson) = Nelson T."),
 65:("plain","yes","Minister in Finland (Schoenfeld) = H.F. Arthur, given the full POCOM post list"),
 66:("plain","yes","as 65"),
 67:("plain","yes","Minister in Ecuador (Long) = Boaz"),
 68:("plain","yes","full name Alexander C. Kirk + post"),
 69:("plain","yes","Ambassador in Nicaragua (Warren) = Fletcher"),
 70:("plain","yes","Ambassador in Costa Rica (Johnson) = Hallett"),
 71:("plain","yes","Ambassador in Australia (Butler) = Robert"),
 72:("plausible","yes","Acting US Representative at the UN 1946 = Herschel V. Johnson; no candidate record names the UN post"),
 73:("plausible","yes","Consul General at Shanghai 1947 = Monnett B. Davis; candidate records do not name the post"),
 74:("plain","yes","Ambassador in the Soviet Union (Smith) = W. Bedell Smith; union 19"),
 75:("plain","yes","Deputy ECA Administrator (Bruce) = Howard Bruce: BOTH POCOM in-office candidates are wrong"),
 76:("plain","yes","Ambassador in France (Bruce) = David K. E."),
 77:("plain","yes","as 76"),
 78:("plain","yes","as 76"),
 79:("plain","yes","Deputy Under Secretary (Matthews) = H. Freeman Matthews"),
 80:("plain","yes","Deputy Asst SecDef ISA (Davis) = Arthur C. Davis; union 19"),
}
UNION_SIZE = {1:1,2:1,3:0,4:0,5:1,6:0,7:2,8:1,9:1,10:1,11:0,12:13,13:9,14:0,15:1,16:1,17:0,18:2,19:1,20:2,21:1,22:1,23:1,24:1,25:1,26:6,27:1,28:1,29:3,30:4,31:1,32:1,33:2,34:0,35:4,36:6,37:12,38:1,39:1,40:1}
BANDS = ["1861-1899", "1900-1929", "1930-1945", "1946-"]
def wilson(k, n, z=1.959964):
    p = k / n; den = 1 + z*z/n; c = (p + z*z/(2*n)) / den; h = z*math.sqrt(p*(1-p)/n + z*z/(4*n*n)) / den
    return [round(c-h, 3), round(c+h, 3)]
out = {"note": __doc__, "cases": {}, "tally": {}}
for n, (det, tin, why) in R.items():
    cls = "NOBODY" if n <= 40 else "SEVERAL"
    band = BANDS[((n - 1) % 40) // 10]
    out["cases"][n] = {"class": cls, "band": band, "determines": det, "truth_in_union": tin, "note": why}
for cls in ("NOBODY", "SEVERAL"):
    t = collections.defaultdict(collections.Counter)
    for n, c in out["cases"].items():
        if c["class"] == cls:
            t[c["band"]][c["determines"]] += 1; t["all"][c["determines"]] += 1
            t[c["band"]]["truth_in_union_" + c["truth_in_union"]] += 1; t["all"]["truth_in_union_" + c["truth_in_union"]] += 1
    tot = sum(v for k, v in t["all"].items() if k in ("plain", "plausible", "cannot"))
    t["all_wilson95_plain"] = wilson(t["all"]["plain"], tot)
    out["tally"][cls] = {k: dict(v) if isinstance(v, collections.Counter) else v for k, v in t.items()}
u = collections.Counter()
for n, sz in UNION_SIZE.items():
    tin = R[n][1]
    u["size%s_%s" % ("0" if sz == 0 else "1" if sz == 1 else "2+", tin)] += 1
out["tally"]["NOBODY_union_size_vs_truth"] = dict(u)
json.dump(out, open("case-read.json", "w"), indent=1)
print(json.dumps(out["tally"], indent=1))
