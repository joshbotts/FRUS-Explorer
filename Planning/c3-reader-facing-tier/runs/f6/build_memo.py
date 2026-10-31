import re,json,sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
head=open('memo_head.md',encoding='utf8').read()
ex=json.load(open('excerpts.json'))
ov=open('overview.md',encoding='utf8').read().split('## Documents cited')[0]
qs=[re.sub(r'^\[a\] ','a ',q.rstrip(',.')) for q in re.findall(r'["“]([^"”]+)["”]',ov)]
col=json.load(open('collection.fruscollection',encoding='utf8'))
colex={(e['volumeId'],e['documentId'],e['text']) for e in col['entries'] if e['kind']=='excerpt'}
def used(e): return any((q in e) or (q[0].upper()+q[1:] in e) for q in qs if len(q)>12)
rows=[]
for i,(v,d,t) in enumerate(ex):
    rows.append(f"| Q{i+1} | {v}/{d} | `SELECT body_text FROM document_cache WHERE volume_id='{v}' AND document_id='{d}'` then `passage IN body_text` = true | {'yes' if used(t) else 'no'} | {'yes' if (v,d,t) in colex else 'no'} | {t[:110]}{'...' if len(t)>110 else ''} |")
qt="\n".join(rows)
cite=open('cite_table.md',encoding='utf8').read()
order=json.load(open('cited_order.json'))
# overview citation text
cites=re.findall(r'\((\d{4}), ([^)]*?), Document (\d+)\)',ov)
part2=f"""
## 5. Quotations: the SELECT that retrieved each, and where it is used

Every quotation in the overview and every excerpt in the collection is a passage that I retrieved with the SELECT below and tested for exact containment in `body_text` (verify_excerpts.py; excerpt_verification.txt: all {len(ex)} of {len(ex)} exact). A quotation in the overview is a substring of one of these passages (checked by script). The raw text of each document is in docs/<volume>__<doc>.txt (that SELECT's output, with the header and dateline).

| id | volume_id/document_id | retrieving SELECT and test | in overview | in collection | passage (first 110 characters) |
|---|---|---|---|---|---|
{qt}

## 6. Citation and source table (one row per cited document, in the order of the findings)

Each row is `SELECT d.document_number, dd.date_iso, s.repository, s.record_group, s.series_name, substr(s.raw_text,1,170) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id JOIN document_sources s ON s.volume_id=d.volume_id AND s.document_id=d.document_id WHERE d.volume_id=? AND d.document_id=?` (run by cite_table script; every pair also confirmed `is_front_matter=0 AND is_editorial_note=0`). The year in each overview citation is the first four characters of date_iso.

| id | volume_id/document_id | date_iso | repository / record group / series | source note (first 170 characters) |
|---|---|---|---|---|
{cite}

All 27 pairs exist in `document_cache` and appear once in the collection (build_collection.py asserts it). The overview cites {len(set(order))} documents, all in the collection.

## 7. Reading accounting

- Retrieved whole (captured text equal to `length(body_text)` characters, tested by comparing the captured body to `SELECT body_text`): 61 of 61 (retrieval_check.txt). Quoted: 27 documents, {len(ex)} passages; every quoted document is cited in the overview and kept in the collection.
- Read in full (all characters printed to me): frus1917-72PubDipv08/d31, PubDipv07/d171, PubDipv06/d126, d133, frus1969-76v38p2/d105, frus1977-80v30/d79, d81, frus1952-54v12p2/d403, frus1961-63v01/d49, d265, frus1961-63v02/d5, d16, frus1961-63v03/d308, frus1961-63v04/d95, d108, frus1961-63v23/d289, frus1964-68v01/d197, frus1964-68v02/d160, d172, frus1964-68v03/d138, frus1964-68v27/d386, frus1969-76v19p2/d67, frus1955-57v09/d54.
- Read in part (windows of 400 to 8,500 characters around the search terms, or the first 2,000 to 7,500 characters): frus1949v07p2/d386, d338, frus1950v06/d32, frus1952-54v14p2/d820, frus1961-63v01/d339, frus1961-63v04/d81, frus1964-68v26/d106, frus1969-76v10/d199, frus1969-76ve12/d10, d16, d17, frus1977-80v22/d3, d102, d107, frus1955-57v09/d185, frus1955-57v22/d448, frus1955-57v21/d72, d79, frus1958-60v18/d180. For the cited documents among these (d386, d32, d820, d339, d106, ve12/d16, ve12/d17, v22/d3) I read the quoted passage and its surrounding paragraphs, and the document's opening.
- Retrieved but not read: frus1917-72PubDipv07/d32, d37, PubDipv08/d143, d149, frus1949v07p1/d409, frus1951v06p2/d480, frus1952-54v12p1/d388, v12p2/d359, frus1955-57v09/d190, frus1955-57v21/d78, frus1955-57v22/d463, frus1961-63v02/d266, d290, frus1961-63v03/d28, d152, frus1964-68v01/d122, frus1964-68v29p2/d46, frus1977-80v22/d104, frus1977-80v30/d68. (They came from ranked lists; I did not use them.)
- Documents seen only as a header line in ranked lists: several hundred; none was cited without being retrieved and read.

## 8. VECTORS

Operations I ran, each with anchor, file, baseline and result. Operations not run are named as such.

**Digest check (before scoring).** `semantic-vectors-index.json` `provenanceDigest` = 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101; the digest at offset 20 of `semantic-vectors-binary.bin`, at offset 20 of `semantic-map.bin`, and at offset 16 of all 553 shards in /Users/jbotts/frus-analysis/c3/SemanticVectors/ is identical (digest_check.txt; 0 mismatches). Index `generated` 2026-10-15, `harvestGenerated` 2026-10-15T06:55:14. Identity came only from the index's id segments (decode round trip passes for 553 of 553 volumes, assertion in vec.py; no id was derived from an ordinal). `retrieval.measuredRecallAt10` = 0.9021 (so absence of a neighbour is not evidence of absence).

**Baselines at this digest** (vec_baselines.txt): random pairs (20,000 pairs, `random.Random(1877)`): mean 167.1, sd 14.8, 1st percentile 132, minimum 95 of 512 bits. The 25th-nearest-neighbour distance over 200 random documents (`random.Random(2026)`): median 106, quartiles 100 and 113. A neighbour at 72 to 100 is therefore inside the near tail of the k-th-neighbour distribution and far below random pairs, which makes it a reading suggestion and not a relationship.

**1. Nearest neighbours of a document.** Anchors: frus1917-72PubDipv08/d31 (the 1969 Manila conference summary), frus1969-76v38p2/d105 (the 1975 reassessment) and frus1964-68v01/d197 (the 1964 Honolulu committee memorandum). File: `semantic-vectors-binary.bin` sign bits (512 bits), XOR and popcount over all 314,616 rows, top 800 by Hamming reranked by int8 cosine from the Tier-2 shards, top 15 shown; the cosine is shown through `retrieval.scoreCalibration` as (cosine - 0.40) / 0.60 (document to document) beside the raw cosine. Output: vec_neighbours.txt (48 lines: 3 anchors and 45 neighbours). Baseline: the 25th-neighbour distribution above (the 15 neighbours sit at 72 to 104 bits). Every neighbour's volume is present in `document_cache` (all 553 volumes are), so none is flagged as outside the index.
  Found by similarity and by none of the seven ranked or listed full-text queries I ran (their complete ordered result lists were tested, not only the top rows I read: assessment, audience beliefs, exchange, information-set Asia, Japan, header, and the M4 family; membership test in queries.log): **frus1969-76ve12/d16** (distance 80 to the 1975 reassessment anchor, raw cosine 0.913, calibrated 85%), **frus1969-76ve12/d17** (distance 99, raw cosine 0.903, calibrated 84%) and **frus1977-80v22/d3** (distance 88, 84%; all three are neighbours of the 1975 reassessment anchor, frus1969-76v38p2/d105). I read each before citing it (in part, see section 7).
  Other neighbours I noted but did not cite: frus1969-76ve12/d10 (Smyser, 1974), frus1977-80v22/d102 and d107, frus1917-72PubDipv07/d37 and d32.
  Documents in the overview reached through a vector operation and through no full-text query: those three (frus1969-76ve12/d16, ve12/d17, frus1977-80v22/d3). Every other cited document was reached by a full-text query; of the 27 cited, five appear in the neighbour lists (those three, and the Manila summary and the 1975 reassessment, which are each other's neighbours).
**2. A semantic join into the database.** Each neighbour was joined on both keys to `document_cache` (header, flags), `document_dates` (date_iso) and to the full-text family M4 (`inQAfts` flag in vec_neighbours.txt). The joined fields show which neighbours the full-text family does not capture (inQAfts=False): for the 1975 anchor, 10 of 15.
**3. Centroid similarity: not run.**
**4. The map.** `semantic-map.bin` placements and `semantic-map-index.json` cluster terms for all 27 cited documents (map_cited.txt): 5 of the 27 are unclustered (frus1917-72PubDipv08/d31, frus1969-76v38p2/d105, frus1977-80v22/d3, frus1977-80v30/d79, frus1969-76ve12/d16); corpus-wide 88,059 of 314,616 placements are unclustered (28.0%), so 5 of 27 (18.5%) is not unusual for a set that is mostly 1960s and 1970s. Cluster terms are geographic (Vietnam, Indonesia, Japan), not thematic: the map cannot find "messaging" documents, and I used it for no selection.
**5. Near-duplicates.** Pairwise Hamming distance over the sign bits among the 27 cited documents (351 pairs; vec_pairs.txt): minimum 76 (frus1917-72PubDipv06/d126 against d133, which are a request and its reply and not a reprint), next 80, 85, 86, 87. No pair is near enough to be a reprint; I also read the pairs' texts where I had read both, and none duplicated another. (I did not have section 14.9's measured reprint distances in this session; the check rests on the distances being far above the few-bit range I expect of a reprint and on my reading.)

Similarity suggestions are lead-finding only. The neighbour distances in the overview do not appear (the overview says "found by its similarity to ... by no word search I ran, and read before it was cited").

## 9. What is thin, and what I did not do

- The index holds all 553 volumes, so the thinness here is the series' and not a partial library: FRUS prints almost nothing measuring audience effect; the effect assessments are officials' own, mostly from USIA (a self-assessing source).
- The family M4 over 1940s documents includes non-American bodies (the Chinese Government's information service), so the 1940s rate in M10 overstates American messaging; the overview does not use it.
- I did not search the 14 volumes of 1981 to 1992 in the index (the EAP set's last decade holds 106 documents dated 1980 or later, from the 1977 to 1980 volumes) or any volume before 1944.
- The 27 documents are a selection by reading; other documents of the same kinds exist (the M4 family has 1,296), and a different reading could choose others. I did not read the Japan and Korea volumes beyond documents the searches ranked; cultural exchange in Japan and Korea is therefore thin in the collection.
- I did not use the NARA harvest ([HARVEST] path not supplied; that surface is unavailable to this run). Archival resolution stops at what the bundled indexes reach. The offline stack barely reaches before 1940; this scope starts in 1945 so the roadmap is not empty for that reason, but the USIA series are the ones it cannot resolve to a folder.
- The term "soft power" is absent from the series (M8); the question's vocabulary was mapped to the editors' (information program, psychological strategy, American image).
"""
open('memo_part2.md','w',encoding='utf8').write(part2)
print(len(part2))
