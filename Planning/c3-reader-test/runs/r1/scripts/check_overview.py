# Checks on overview.md and collection.fruscollection: (1) every block quotation is a verified quotation; (2) every history.state.gov address cited is in the collection and vice versa;
# (3) no SQL, table or column names, file paths or issue numbers in the reader-facing text; (4) the collection's excerpts are the overview's quotations.
import re, json, sys
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import content as K
ov = open(K.RUN + "/overview.md").read()
col = json.load(open(K.RUN + "/collection.fruscollection"))
verified = {q["text"] for q in K.QUOTES.values()}
bq = re.findall(r"^> “(.*)”$", ov, re.M)
print("block quotations in the overview:", len(bq), "| all verified:", all(b in verified for b in bq), "| distinct:", len(set(bq)))
ex = [e["text"] for e in col["entries"] if e["kind"] == "excerpt"]
print("excerpts in the collection:", len(ex), "| equal to the overview's quotations as sets:", set(ex) == set(bq))
body = re.sub(r"^> .*$", "", ov, flags=re.M)
inline = re.findall(r"“([^”]{3,})”", body)
print("inline quoted phrases outside block quotes:", inline)
urls = set(re.findall(r"https://history\.state\.gov/historicaldocuments/([^/\s,;)]+)/(d\d+)", ov))
coldocs = {(e["volumeId"], e["documentId"]) for e in col["entries"] if e["kind"] == "document"}
print("addresses cited in overview:", len(urls), "| in collection:", len(coldocs), "| cited not in collection:", sorted(urls - coldocs), "| in collection not cited:", sorted(coldocs - urls))
txt = re.sub(r"https://history\.state\.gov/\S+", "", ov)
bad = []
for pat in [r"\bSELECT\b", r"\bFROM\b", r"\bMATCH\b", r"document_cache", r"volume_id", r"document_id", r"external_citations", r"document_sources", r"is_front_matter", r"/Users/", r"\.tsv", r"\.py\b", r"\.json", r"scope\.db", r"#\d{3,4}\b", r"\bissue\b", r"\bsqlite", r"\bFTS"]:
    for m in re.finditer(pat, txt, 0 if pat in (r"\bSELECT\b", r"\bFROM\b", r"\bMATCH\b") else re.I):
        bad.append((pat, txt[max(0, m.start() - 40): m.end() + 40].replace("\n", " ")))
print("forbidden-pattern hits:", bad)
print("bare id pairs outside addresses:", re.findall(r"frus[0-9][^\s/]*/d\d+", txt))
for term in ["stem", "bm25", "tokeniz", "regex", "porter", "FTS5", "lemma", "stemm"]:
    if re.search(term, txt, re.I): print("technical term present:", term)
