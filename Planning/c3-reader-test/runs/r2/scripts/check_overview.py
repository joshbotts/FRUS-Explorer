# Overview checks: (1) every straight-double-quoted string is a substring of a verified quotation (quotes/quotes_verified.json),
# except the question's own phrase; (2) the set of cited documents (history.state.gov URLs) equals the collection pairs;
# (3) no SQL, table or column names, id strings or file paths outside the URLs.
import json, re, csv
ov = open("overview.md").read()
verified = [q["text"] for q in json.load(open("quotes/quotes_verified.json")) if q["raw_substring"]]
WHITELIST = {"came to power by force"}
quoted = re.findall(r'"([^"]+)"', ov)
bad = [q for q in quoted if q not in WHITELIST and not any(q.strip() in v for v in verified)]
print("double-quoted strings:", len(quoted), "| not traceable to a verified quotation:", bad)
cited = set(re.findall(r"https://history\.state\.gov/historicaldocuments/([^/\s)]+)/([^\s)/.,]+)", ov))
coll = {tuple(p.split("/")) for f, p in csv.reader(open("out/collection_pairs.tsv"), delimiter="\t")}
print("cited documents:", len(cited), "| collection pairs:", len(coll), "| cited not in collection:", sorted(cited - coll), "| collection not cited:", sorted(coll - cited))
nourl = re.sub(r"https://history\.state\.gov/historicaldocuments/\S+", "", ov)
leaks = re.findall(r"document_cache|frus_documents|volume_id|document_id|SELECT|/Users/|\bfrus\d{4}|\bd\d+\b|external_citations|document_sources|\.json|\.tsv|issue #|#\d+", nourl)
print("leaks outside URLs:", leaks)
