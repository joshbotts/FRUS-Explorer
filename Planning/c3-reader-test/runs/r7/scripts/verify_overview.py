# Checks: (1) every straight-double-quoted string in overview.md is a substring of a verified excerpt (out/quotes.tsv);
# (2) every history.state.gov pair linked in overview.md is a document entry of collection.fruscollection;
# (3) every collection excerpt is an exact substring of its document's body_text and every pair exists, non-apparatus, in document_cache.
import re, json, sqlite3, csv
R="/Users/jbotts/frus-analysis/c3/runs/r7/"
csv.field_size_limit(10**9)
quotes=[r for r in csv.DictReader(open(R+"out/quotes.tsv"), delimiter="\t")]
texts=[q["text"] for q in quotes]
o=open(R+"overview.md").read()
qs=re.findall(r'"([^"]+)"', o)
bad=[q for q in qs if not any(q in t for t in texts)]
print(f"(1) overview quotations: {len(qs)} checked, {len(qs)-len(bad)} found in verified excerpts, {len(bad)} not")
for b in bad: print("   NOT VERIFIED:", b[:120])
coll=json.load(open(R+"collection.fruscollection"))
docs={(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"}
links=set((v,d.rstrip(";.,")) for v,d in re.findall(r"https://history\.state\.gov/historicaldocuments/([^/\s)]+)/([^\s),]+)", o))
missing=[l for l in links if l not in docs]
print(f"(2) overview links: {len(links)} distinct pairs, {len(links)-len(missing)} in the collection, {len(missing)} not:", missing)
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
nex=nbad=0
for e in coll["entries"]:
    if e["kind"] in ("document","excerpt"):
        row=con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(e["volumeId"],e["documentId"])).fetchone()
        if not row: print("   PAIR MISSING:", e["volumeId"], e["documentId"]); nbad+=1; continue
        if e["kind"]=="excerpt":
            nex+=1
            if e["text"] not in row[0]: print("   EXCERPT NOT VERBATIM:", e["volumeId"], e["documentId"]); nbad+=1
print(f"(3) collection: {len(docs)} documents, {nex} excerpts checked against body_text, {nbad} problems; Ed2 pairs:", sum(1 for v,d in docs if v.endswith('Ed2')))
print("    required keys:", all(k in coll for k in ("format","formatVersion","minimumReaderVersion","name","authorLine","introductionText","composition","entries")), coll["format"], coll["formatVersion"], coll["minimumReaderVersion"], sorted(coll["composition"].keys()))
print("    notes open with attribution:", all(n.startswith("Agent finding, Agent run r7, 2026-10-25") for e in coll["entries"] if e["kind"]=="document" for n in e["notes"]))
