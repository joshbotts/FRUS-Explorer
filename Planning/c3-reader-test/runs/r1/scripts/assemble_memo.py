# Assemble memo.md from work/memo_template_*.md, the work files, the verified quotations and a trace table whose memo line numbers are computed from the finished text.
import csv, re, sys, json, sqlite3
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import content as K
import frus
RUN = K.RUN
def rd(p): return open(RUN + "/" + p).read().rstrip("\n")

# ---------- placeholders
def tsv_md(p):
    rows = list(csv.reader(open(RUN + "/" + p), delimiter="\t"))
    out = ["| " + " | ".join(rows[0]) + " |", "|" + "|".join(["---"] * len(rows[0])) + "|"]
    for r in rows[1:]:
        out.append("| " + " | ".join(x.replace("|", "/").replace("\n", " ") for x in r) + " |")
    return "\n".join(out)
def falsefriend():
    rows = list(csv.DictReader(open(RUN + "/work/false_friend.tsv"), delimiter="\t"))
    out = ["| term | kind | A hemisphere volumes | B Latin American sections | C everything else | A/C | B/C |", "|---|---|---|---|---|---|---|"]
    for r in rows:
        out.append("| %s | %s | %s of %s (%.1f%%) | %s of %s (%.1f%%) | %s of %s (%.1f%%) | %s | %s |" % (r["term"], r["kind"], r["A_docs"], r["A_of"], 100 * float(r["A_share"]), r["B_docs"], r["B_of"], 100 * float(r["B_share"]), r["C_docs"], r["C_of"], 100 * float(r["C_share"]), r["A_over_C"], r["B_over_C"]))
    out.append("")
    out.append("FTS expressions, in order: " + "; ".join("`%s`" % r["FTS_expression"] for r in rows))
    return "\n".join(out).replace("| nan | nan |", "| n/a (no hits) | n/a (no hits) |")
led = list(csv.DictReader(open(RUN + "/work/reading_ledger.tsv"), delimiter="\t"))
docs = {}
for r in led:
    k = (r["volume_id"], r["document_id"])
    d = docs.setdefault(k, {"whole": True, "pw": False, "chars": int(r["sql_length_chars"])})
    d["whole"] = d["whole"] and r["retrieved_whole"] == "Y" and r["sql_length_chars"] == r["captured_chars"]
    d["pw"] = d["pw"] or r["printed_whole"] == "Y"
s = sqlite3.connect("file:%s/work/scope.db?mode=ro" % RUN, uri=True)
cited = set(s.execute("SELECT volume_id, document_id FROM cited"))
Eset = set(s.execute("SELECT e.volume_id, e.document_id FROM editors_recog e JOIN scope_docs sd ON sd.volume_id=e.volume_id AND sd.document_id=e.document_id WHERE sd.numbered=1 AND sd.apparatus=0"))
Lset = set(s.execute("SELECT volume_id, document_id FROM scope_docs WHERE latam=1 AND numbered=1 AND apparatus=0 AND ed2_dup=0"))
read = set(docs)
n_ret = len(docs); n_whole = sum(1 for d in docs.values() if d["whole"]); n_full = sum(1 for d in docs.values() if d["pw"])
n_in_scope = len(read & Lset); n_E = len(read & Eset)
cited_full = len([k for k in cited if docs[k]["pw"]]); cited_part = sorted(k for k in cited if not docs[k]["pw"])
nq = len(K.QUOTES); nqd = len(set(q["key"] for q in K.QUOTES.values()))
chars = sum(d["chars"] for d in docs.values())
READING = ("%d distinct documents retrieved (%d retrievals in the ledger), all %d whole (captured length equal to length(body_text) in characters; %s characters in all); %d printed to the screen in full at least once and %d only in part (the opening plus windows around the recognition words; the full text is on disk); %d of the %d are inside the Latin American scope; all %d cited documents were retrieved whole, %d of them printed in full and %d in part (%s); %d documents are quoted (%d quotations). Documents retrieved that sit under the editors' recognition chapters: %d of %s."
          % (n_ret, len(led), n_whole, format(chars, ","), n_full, n_ret - n_full, n_in_scope, n_ret, len(cited), cited_full, len(cited_part), ", ".join("%s/%s" % k for k in cited_part), nqd, nq, n_E, format(len(Eset), ",")))
qlines = []
for qid in sorted(K.QUOTES):
    q = K.QUOTES[qid]
    qlines.append("- [%s] %s (%s characters, finding %s): “%s”" % (qid, q["key"], q["chars"], q["finding"], q["text"]))
QUOTES = "\n".join(qlines)
# R-lines with phrase verification
R = [
 ("R01", "frus1900/d530", ["September 8, 1900"]), ("R02", "frus1930v01/d375", ["September eighteenth", "June, 1923"]),
 ("R03", "frus1937v05/d265", ["July 16, 1937", "(4) Any available information as to what steps"]), ("R04", "frus1948v09/d7", ["March 15, 1948"]),
 ("R05", "frus1949v02/d489", ["February 3, 1949", "Since the administration of President Jefferson"]), ("R06", "frus1913/d7", ["March 11, 1913", "March 12, 1913"]),
 ("R07", "frus1913/d1028", ["August 27, 1913", "(b) Security given for an early and free election", "pledges itself to recognize"]),
 ("R08", "frus1919v01/d867", ["August 16, 1919", "de jure or even a legitimately de facto Government"]),
 ("R09", "frus1921v01/d238", ["January 31, 1921", "not as the de facto Government, but as the Constitutional Government"]),
 ("R10", "frus1925v02/d498", ["December 9, 1925"]), ("R11", "frus1931v02/d232", ["December 20, 1931", "within 6 months"]),
 ("R12", "frus1934v05/d255", ["January 25, 1934", "Approved, Jan. 26"]), ("R13", "frus1936v05/d109", ["April 21, 1936"]),
 ("R14", "frus1877/d222", ["May 16, 1877", "condition precedent to any recognition"]), ("R15", "frus1878/d344", ["March 23, 1878"]),
 ("R16", "frus1914/d567", ["December 12, 1914", "consent of the governed"]), ("R17", "frus1915/d448", ["August 12, 1915", "simultaneously conclude"]),
 ("R18", "frus1921v02/d344", ["June 8, 1921"]), ("R19", "frus1932v05/d518", ["July 16, 1932"]),
 ("R20", "frus1932v05/d560", ["October 12, 1932", "not bargaining over the question of recognition"]),
 ("R21", "frus1932v05/d561", ["October 16, 1932", "does not imply recognition nor is it a bargain for recognition"]),
 ("R22", "frus1932v05/d567", ["October 21, 1932"]), ("R23", "frus1934v05/d85", ["January 14, 1934", "in advance of the fulfillment of the conditions"]),
 ("R24", "frus1961-63v10-12mSupp/d109", ["July 18, 1963", "within approximately one year", "will not extend recognition until at least several other Latin American countries"]),
 ("R25", "frus1961-63v10-12mSupp/d137", ["April 17", "two years"]), ("R26", "frus1961-63v12/d359", ["October 4, 1963", "7. Commitment to institutional reforms"]),
 ("R27", "frus1964-68v31/d152", ["December 3, 1964"]), ("R28", "frus1943v05/d335", ["June 6, 1943", "to bargain with the new Government"]),
 ("R29", "frus1944v07/d388", ["January 10, 1944"]), ("R30", "frus1944v07/d403", ["January 28, 1944", "nineteen republics"]),
 ("R31", "frus1944v07/d432", ["June 2, 1944", "no MNR official"]), ("R32", "frus1944v07/d437", ["June 17, 1944", "June 23"]),
 ("R33", "frus1944v07/d1090", ["October 27, 1944"]), ("R34", "frus1945v09/d1170", ["October 25, 1945"]),
 ("R35", "frus1948v09/d74", ["does not imply any judgment upon the domestic policy", "March 30–May 2, 1948"]),
 ("R36", "frus1948v09/d115", ["December 10, 1948"]), ("R37", "frus1955-57v06/d354", ["July 11, 1957", "past seven months"]),
 ("R38", "frus1958-60v06/d217", ["January 7, 1959", "5 p.m. that day"]), ("R39", "frus1958-60v05/d11", ["February 16, 1959", "unless a substantial question should arise with respect to Communist control"]),
 ("R40", "frus1961-63v12/d363", ["December 13, 1963", "recognized the new Dominican Government on December 14"]),
 ("R41", "frus1964-68v31/d132", ["June 28, 1966", "Resolution XXVI of 1965 Rio Conference"]), ("R42", "frus1964-68v31/d518", ["October 19, 1968"]),
 ("R43", "frus1969-76v21/d361", ["September 20, 1973", "24 September 1973"]),
 ("R44", "frus1952-54v04/d490", ["June 28, 1954", "one of criteria for recognition is that new government be in control of territory", "Castillo Armas controlled a portion of territory"]),
 ("R45", "frus1952-54v04/d502", ["July 9, 1954", "formally established on July 2", "prepared to fulfill the international obligations of Guatemala", "conspicuously in the lead or behind", "recognition to the new Guatemalan Government on July 13, 1954"]),
]
conn = frus.connect()
rl = []; rbad = []
for lab, key, phrases in R:
    v, d = key.split("/")
    body = frus.collapse(open("%s/raw/%s__%s.body.txt" % (RUN, v, d)).read()).lower()
    ok = [p for p in phrases if frus.collapse(p).lower() in body]
    status = "verified" if len(ok) == len(phrases) else "NOT FOUND: " + "; ".join(p for p in phrases if p not in ok)
    if status != "verified": rbad.append((lab, key, status))
    rl.append("[%s] %s (%s): %s — %s" % (lab, key, K.META[key]["date_iso"], "; ".join("“%s”" % p for p in phrases), status))
RLINES = "\n\n".join(rl)
print("R-lines not verified:", rbad)

tmpl = "\n".join(rd("work/memo_template_%d.md" % i) + "\n" for i in (1, 2, 3, 4))
def fileblock(m):
    return "```\n" + rd(m.group(1)) + "\n```"
tmpl = re.sub(r"\{\{FILE:([^}]+)\}\}", fileblock, tmpl)
tmpl = re.sub(r"\{\{TSVMD:([^}]+)\}\}", lambda m: tsv_md(m.group(1)), tmpl)
tmpl = tmpl.replace("{{FALSEFRIEND}}", falsefriend()).replace("{{READING}}", READING).replace("{{QUOTES}}", QUOTES).replace("{{RLINES}}", RLINES)
tmpl = tmpl.replace("(2,205 of 2,255)", "(%s of 2,255)" % format(len(Eset) - n_E, ",")).replace("50 were among the documents I retrieved", "%d were among the documents I retrieved" % n_E)

# ---------- citations table (the printed-edition citation of every cited document)
cit = ["## 17. The citations used in the overview\n", "Each full citation in the overview is the manifest title of the volume (shortened to the conventional form for the volumes whose title carries the President's message), the document number, and the address https://history.state.gov/historicaldocuments/<volume>/<document>. Day is the index's day for the document; page is the first printed page from the page-range table (`SELECT page_number_raw FROM page_ranges WHERE volume_id = ? AND document_id = ? AND is_start = 1`).\n",
       "| finding | volume/document | printed citation | day | printed page | role |", "|---|---|---|---|---|---|"]
for key, r in sorted(K.META.items(), key=lambda kv: (int(kv[1]["finding"]), kv[1]["date_iso"])):
    cit.append("| %s | %s | %s, Document %s | %s | %s | %s |" % (r["finding"], key, r["short_title"], r["document_number"], r["date_iso"], r["page"], r["role"]))
body = tmpl + "\n" + "\n".join(cit) + "\n"
import trace_rows
lines = body.split("\n")
def find_line(label):
    if label == "C-table":
        for i, l in enumerate(lines, 1):
            if l.startswith("## 17."): return i
    pat = "[%s]" % label
    for i, l in enumerate(lines, 1):
        if pat in l: return i
    return None
rows = ["## TRACE TABLE\n", "One row per number, date, figure and quotation in the overview, in the order it appears; the label points to the memo line (counted in this file) that carries the source, the query or the verification. [N..] are counts of the corpus, [R..] dates and figures read in documents, [Q..] verified quotations, C-table the citations table in section 17.\n", "| overview location | item as the overview words it | memo labels | memo lines |", "|---|---|---|---|"]
miss = []
for loc, item, labs in trace_rows.TRACE:
    ls = []
    for lab in labs:
        n = find_line(lab)
        if n is None: miss.append(lab)
        ls.append(str(n))
    rows.append("| %s | %s | %s | %s |" % (loc, item, ", ".join(labs), ", ".join(ls)))
trace_text = "\n".join(rows) + "\n"
final = body + "\n" + trace_text
open(RUN + "/memo.md", "w").write(final)
print("labels with no memo line:", sorted(set(miss)))
# coverage: every numeric token of the overview (outside addresses, block quotations and citations) must occur in the trace table or the citations table
ov = open(RUN + "/overview.md").read()
t = re.sub(r"https://history\.state\.gov/\S+", "", ov)
t = re.sub(r"^> .*$", "", t, flags=re.M)
for key in K.META: t = t.replace(K.full_cite(key).replace(", https://history.state.gov/historicaldocuments/%s/%s" % tuple(key.split("/")), ""), "")
t = re.sub(r"\((?:Papers Relating|Foreign Relations|FRUS)[^()]*\)", "", t)
toks = set(re.findall(r"\d[\d,\u2013\-]*\d|\d", t))
covered = trace_text + "\n" + "\n".join(cit)
covered_norm = covered.replace("\u2013", "-")
unc = sorted(x for x in toks if x.replace("\u2013", "-") not in covered_norm)
print("numeric tokens in the overview not found in the trace or citation tables:", unc)
print("memo.md lines:", final.count("\n"))
