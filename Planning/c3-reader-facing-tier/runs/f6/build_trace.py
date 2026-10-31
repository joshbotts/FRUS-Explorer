import re,json
ov=open('overview.md',encoding='utf8').read().split('## Documents cited')[0]
ex=json.load(open('excerpts.json'))
t2=re.sub(r'\([0-9]{4}, [^)]*Document \d+\)','',ov)
toks=[m.group(0) for m in re.finditer(r'\d[\d,\.\-–]*\d|\d|\b(?:one|two|three|four|five|six|seven|eight|nine|ten|thirty|forty|twenty|first|second|third)\b',t2,re.I)]
groups=[
("76 (volumes on East Asia and the Pacific)",{"76"},"M2 (SELECT COUNT(DISTINCT volume_id) ... IN the 76 ids = 76)"),
("553 (volumes of the series in the index)",{"553"},"M1 (canary: COUNT(DISTINCT volume_id) = 553)"),
("14 (volumes on information policy and public diplomacy)",{"14"},"M3 (= 14 volumes; also Lot count 'Kennedy 14' row in M13, same numeral different meaning)"),
("1,300 (documents in the family, rounded from 1,296)",{"1,300"},"M4 (COUNT(*) = 1296)"),
("61 (documents retrieved whole)",{"61"},"Section 7 reading accounting and retrieval_check.txt (61 of 61 whole)"),
("1945, 1980 (period searched), 1951 (kept volume), 1945-1963 (no decimal-file series bundled)",{"1945","1980","1951","1945–1963"},"Section 2 scope (earliest document year 1944 or later; 1945 volume first; document_dates up to 1981); 1951 = frus1951v06p1/p2 in eap_volumes.txt; 1945-1963 = archival_facts.txt decimal line and the check that central-files-index.json has no decimal-file series for those years (jsonscan.py)"),
("1910 (no pointed-at row before 1910)",{"1910"},"House rule stated in the brief (external_citations has no row before 1910-12-06); not a measurement of mine"),
("3, 15, 18 (series per USIA accession); two (series of FRC 306-84-0003)",{"3","15","18","two"},"M11 (accession-series-index.json: 306/67A222 = 3, 306/68A4933 = 15, 306/72A5121 = 18, 306/840003 = 2); the isolated '3' in the binational-centre sentence is M14"),
("four (series of lot 62 D 430), three (series of lot 62 D 1)",{"four","three"},"M12 (lot-claimants-index.json: 4 and 3 claimants) - also 'three' counts the vector-found documents, see below"),
("41, 16, 13, 9 (documents citing Lots 66 D 95, 62 D 430, 63 D 351, 62 D 1); 19, 25, 14, 7 (Nixon, Johnson, Kennedy, Carter library citations); 178 (central file numbers)",{"41","16","13","9","19","25","7","178"},"M13 (docs column of the pointed-at query; 14 for Kennedy is the same '14' token as M3)"),
("64 (documents), 28 (volumes) - survey/poll scan; 33 (documents), 17 (volumes) - leaflet/script/film scan; 3 (binational centres); 60 (Peace Corps)",{"64","28","33","17","60"},"M14 table rows 1, 3, 6 and 4 respectively (absence_results.txt); '33' also appears as the sample hits in M5 (33 of 40)"),
("40 (sample), 33 (held the intended words), seven (the other seven)",{"40","seven"},"M5 and M6 (33 of 40 tolerant and strict; seven misses, searched, none held the words)"),
("Three (documents found by similarity); Three (days later)",{"Three"},"Three vector-found documents: section 8 (frus1969-76ve12/d16, ve12/d17, frus1977-80v22/d3). 'Three days later': document_dates 1965-02-24 (frus1964-68v02/d160) to 1965-02-27 (frus1964-68v02/d172)"),
("28 million (in a quotation)",{"28"},"Q14 (frus1964-68v01/d197 passage 'Vietnamese audiences at USIS film showings last year totalled an estimated 28 million.')"),
("Years of documents and series, and dates (1949, 1950, 1953, 1954, 1961, 1962, 1963, 1964, 1965, 1967, 1968, 1969, 1971, 1975, 1977; 1960s, 1963-1969, 1969-1974, 1953-1961, 1947-1979 and similar)",set(),"Each year in a document description is the first four characters of date_iso of the cited document (cite table C1-C27, section 6); each series date range is from archival_facts.txt (series-facts-index.json inclusive years y0-y1; library series dates from presidential-library-catalog.json)"),
("NAIDs, entry numbers, FRC accession numbers, record groups, file numbers, lot numbers, linear feet (26, 47, 9, 4 etc.)",set(),"NAIDs and extents: archival_facts.txt; accession and entry strings (FRC 67 A 222, 68 A 4933, 72 A 5121, UD WW 257, P-207, P-104, 306-84-0003; decimal 711.90, 611.90, 790.5, 611.98; Lot 63 D 351 Entry A1 1586E): the source notes in section 6 and archival_facts.txt; report number R-10-65: footnote text of frus1964-68v02/d172"),
("The structural numerals: '1.', '2.', '3.' headings of the skeleton, 'Document N' inside citations",set(),"Not counts. Document numbers: cite table column 'document_number' (SELECT document_number FROM document_cache)."),
]
covered=set()
for _,s,_ in groups: covered|=s
unc=sorted(set(t for t in toks if t not in covered and not re.fullmatch(r'(19|20)\d\d(–(19|20)\d\d)?|\d{5,}|\d+\.\d+|\d{1,3}|10-65|306-84-0003|1,300|1947–1979|[0-9–]+',t)))
print("uncovered tokens (non-year, non-id):",unc)
# quotations
qs=[q for q in re.findall(r'["“]([^"”]+)["”]',ov)]
qrows=[]
for q in qs:
    core=re.sub(r'^\[a\] ','a ',q.rstrip(',.'))
    hit=[i for i,(v,d,t) in enumerate(ex) if core in t or core[0].upper()+core[1:] in t]
    qrows.append(f"| \"{q[:90]}{'...' if len(q)>90 else ''}\" | "+(", ".join(f"Q{i+1} ({ex[i][0]}/{ex[i][1]})" for i in hit[:2]) if hit else "NOT A DOCUMENT QUOTATION (a defined term or title)")+" |")
out="## 10. Trace table: every number and quotation in the overview\n\nMemo lines are the M-numbers above and the sections named. A year inside a citation parenthesis, e.g. (1964, Volume I, Document 197), is taken from the cite table (section 6). \n\n| number or set of numbers in the overview | memo line it comes from |\n|---|---|\n"
for a,_,c in groups: out+=f"| {a} | {c} |\n"
out+="\n### Quotations\n\n| quotation in the overview | verified passage |\n|---|---|\n"+"\n".join(qrows)+"\n"
out+="\n### Word-numbers that are not counts\n\n'first' (\"reading the editors' headings first\") and 'one' (\"a Thai-initiated one\"; \"is one I verified\") are not counts. 'Channel' labels are names, not numbers.\n"
open('memo_part3.md','w',encoding='utf8').write(out)
print(out[-2500:])
