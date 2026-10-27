import re
L=open("memo.md").read().split("\n")
def ln(pat):
    for i,l in enumerate(L,1):
        if re.search(pat,l): return i
    raise SystemExit("no line for "+pat)
ref={
 "cov":ln(r"^COVERAGE \(first command"),"c1":ln(r"^- \*\*C1 "),"c2":ln(r"^- \*\*C2 "),
 "s3":ln(r"^- \*\*S3 "),"n01":ln(r"^### N01"),"n02":ln(r"^### N02"),"n03":ln(r"^### N03"),"n04":ln(r"^### N04"),"n05":ln(r"^### N05"),"n06":ln(r"^### N06"),"n07":ln(r"^### N07"),
 "v2":ln(r"^- \*\*V2 "),"v7":ln(r"^- \*\*V7 "),"r01":ln(r"^- \*\*R01\*\*"),
 "a01":ln(r"^- \*\*A01 "),"a02":ln(r"^- \*\*A02 "),"a03":ln(r"^- \*\*A03 "),"a04":ln(r"^- \*\*A04 "),"a06":ln(r"^- \*\*A06 "),"a07":ln(r"^- \*\*A07 "),"a08":ln(r"^- \*\*A08 "),"a09":ln(r"^- \*\*A09 "),"a11":ln(r"^- \*\*A11 "),
 "chan2":ln(r"^\*\*Channel two"),"chk":ln(r"^\*\*Overview–memo check"),"thr":ln(r"^- Threads proposed"),"attr":ln(r"^Speaker and author attributions"),
}
def q(i): return ln(r"^\| %s(\s|\|)"%i)
rows=[
("553 volumes indexed (bottom line 1, Scope, How this was done)","line %d (coverage), %d (C1)"%(ref["cov"],ref["c1"])),
("22 documents the argument rests on (bottom line 1, Scope, How this was done, Read next)","line %d (R01); the 22 are the document entries of collection.fruscollection, listed with dates in section 4 and verified by line %d"%(ref["r01"],ref["chk"])),
("about 4,100 documents naming Cuba five or more times (4,107) (bottom line 1 and 2, Scope, How this was done)","lines %d (S3), %d (N03)"%(ref["s3"],ref["n03"])),
("about 12,300 documents that name Cuba at all (12,256) (bottom line 1, Scope)","line %d (N01)"%ref["n01"]),
("catalogue and tier for file class 837: political affairs, financial conditions, cane sugar, 1910 to 1949","line %d (A03)"%ref["a03"]),
("for 1900 to 1957 most documents came from the central decimal file in Record Group 59","line %d (A02)"%ref["a02"]),
("Missile Crisis lot: entry A1 3053, identifier 27022950, 1962–1963, partly restricted","line %d (A06)"%ref["a06"]),
("Memorandums of Conversation: A1 1566, identifier 602231, 1953–1964, unrestricted","line %d (A06)"%ref["a06"]),
("Special Assistant on Communism subject files: A1 3148, identifier 2363836, 1958–1961, partly restricted","line %d (A06)"%ref["a06"]),
("Operation Mongoose files: UD-UP 293-B, identifier 648748, 1963–1965, unrestricted","line %d (A06)"%ref["a06"]),
("presidential libraries (Kennedy, Johnson, Nixon, Carter, Eisenhower Whitman File) and CIA files as sources","lines %d (A04), %d (A07)"%(ref["a04"],ref["a07"])),
("621 of the same 4,100 documents carry at least one footnote citation of unprinted files","line %d (A09)"%ref["a09"]),
("NSC Policy Papers lot: A1 1586E, identifier 2839192, 1947–1979, partly restricted; second series A1 1586F","line %d (A11)"%ref["a11"]),
("Records Relating to Sugar: UD-UP 215, identifier 27022874, 1955–1962, coverage from 1932, fully restricted","line %d (A11)"%ref["a11"]),
("index records a source for 1 of 309 documents (1870–1899); no footnote entry before December 1910","lines %d (A01), %d (channel two header), %d (A09)"%(ref["a01"],ref["chan2"],ref["a09"])),
("National Archives series for Spain and Cuba: identifiers 177380726, 603720, 177380758, 183303928, 183303950","line %d (A08)"%ref["a08"]),
("177 indexed documents dated in the 1990s, none naming Cuba","line %d (N01)"%ref["n01"]),
("a nonsense word returned nothing; Department of State appeared in all 553 volumes (also: 'Department of State' and 'national security' in quotation marks are search terms, not quotations)","line %d (C1)"%ref["c1"]),
("1,137 documents about Havana that never use the word Cuba, across four periods","line %d (N06)"%ref["n06"]),
("only 10 documents before 1947 pair 'national security' with Cuba (para 3, Decisions)","line %d (N04)"%ref["n04"]),
("10 of 40 sampled documents use 'national security' in any sense but the Council's name","line %d (N04)"%ref["n04"]),
("literal in 39 of 40 sampled documents, all 40 with plurals","line %d (N02)"%ref["n02"]),
("about 62 per thousand in the 1870s, 17 in the 1940s, 114 in the 1960s","line %d (N01)"%ref["n01"]),
("about 65 documents read in full or in windows","line %d (R01)"%ref["r01"]),
("2,982 of 6,124 documents naming Cuba from 1958 in one cluster; none of the 1,240 from 1870 to 1899","line %d (N07)"%ref["n07"]),
("fingerprints put the 1874 instruction nearest 1897–98 despatches; the 1951 statement beside a 1948 memorandum and the 1969 study","line %d (V2); V7 at line %d"%(ref["v2"],ref["v7"])),
("share of documents with defence or Soviet vocabulary near Cuba: between one in five and one in three before 1958 (0.304, 0.219, 0.330), about four in five from 1958 (0.783)","line %d (N05, narrow list)"%ref["n05"]),
("share with sugar, trade or investment vocabulary near Cuba: seven in ten in 1940–1957 (0.705) to one in two from 1958 (0.505)","line %d (N05, narrow list)"%ref["n05"]),
("quota reduction 'by a fifth to a quarter' (20 to 25 per cent)","line %d (Q15)"%q("Q15")),
("'five days later' (22 June to 27 June 1960) and 'nearly a year earlier'","lines %d (Q15 date), %d (Q28 date and passage)"%(q("Q15"),q("Q28"))),
("'three months later' (treaty 29 May 1934; trade agreement 24 August 1934)","lines %d (Q09), %d (Q32)"%(q("Q09"),q("Q32"))),
("dates in the text: February 1874; October 1897; April 1898; March 1902; August 1917; 1933; 1941; 1948; 1951; 1952; September 1959; June and July 1960; 16 October 1962 (morning, evening); July 1969; 1977; 1979; 1981","lines %d to %d (section 4 table), times of day at line %d"%(q("Q01"),q("Q24"),ref["attr"])),
("six sections and 31 passages in the collection","line %d (check_overview.out summary)"%ref["chk"]),
("Crowder missions of 1919–1923; sugar-tariff exchanges of 1927–1929; Mariel exodus of 1980 (existence only)","line %d"%ref["thr"]),
]
for i,t in [("Q01","“almost contiguous to the United States”"),("Q02","“a large and lucrative market”"),("Q06","“the commerce, trade, and business of our people”"),("Q05","“a constant menace to our peace” and the Q05 sentence"),("Q12","“of great strategic importance” and the Q12 sentence"),("Q26","“a domestic, political problem”"),("Q19","“strategic weapons” and the Q19 sentence"),("Q22","“It presents no direct threat to us”"),("Q03","“perpetual solicitude”"),("Q04","“our great commerce with Cuba has thus been practically destroyed”"),("Q07","the Q07 sentence on foreign lodgment"),("Q08","the Q08 sentence"),("Q09","the Q09 sentence"),("Q10","“economic and defense reasons” and the Q10 sentence"),("Q11","the Q11 sentence"),("Q13","“retaliatory instruments” and the Q13 sentence"),("Q15","the Q15 sentence"),("Q14","“one Rubicon” and the Q14 sentence"),("Q18","“intolerable and not acceptable” and the Q18 sentence"),("Q16","“doesn’t mean that much” and the Q16 sentence"),("Q17","the Q17 sentence"),("Q20","“subsidiary and lesser”"),("Q21","the Q21 passage")]:
    rows.append(("quotation: "+t,"line %d (%s, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4)"%(q(i),i)))
out=["","| overview item | memo line |","|---|---|"]+["| %s | %s |"%r for r in rows]
open("memo.md","a").write("\n".join(out)+"\n")
print(len(rows),"rows")
