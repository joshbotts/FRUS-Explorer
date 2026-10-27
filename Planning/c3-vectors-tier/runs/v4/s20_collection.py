import json,re,sqlite3
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ov=open('overview.md').read()
bl=ov.split('## The bottom line')[1].split('**Scope.**')[0]
paras=[re.sub(r'\*','',p).strip() for p in bl.strip().split('\n\n')]
intro='\n\n'.join(paras)
Q={}
for l in open('quotes.tsv'):
    v,d,q=l.rstrip('\n').split('\t'); Q.setdefault((v,d),[]).append(q)
A="Agent run v4, 2026-10-27: "
groups=[
("In the 1870s Cuba was a neighbour's war, a slave society and a market",
 "Three State Department documents of 1870–1874 show the earliest frame: proximity, trade, the insurrection and Cuban slavery, argued from American commercial and racial politics. The 1874 instruction was found as a semantic neighbour of the 1897 Sherman instruction, not by word search.",
 [("frus1870","d197","Fish's 1870 circular on commerce with the Spanish American states: Cuba's trade with the United States is explained by need and proximity."),
  ("frus1873p1v2","d50","Sickles in Madrid ties Cuban slavery to the four million freedpeople of the United States and to Cuba's nearness."),
  ("frus1874","d552","Fish to Cushing, 1874: Cuba is commercially and geographically tied to the United States, ought to be independent, and slavery lies at the root of the war. Reached through a vector neighbour.")]),
("In 1897–98 disorder became a danger to property and domestic peace",
 "The instruction of July 1897 and the President's message of April 1898 recast the Cuban war as a threat to American capital and to domestic tranquillity, the ground for intervention.",
 [("frus1898","d490","Sherman to Woodford, 1897: American property, capital and domestic political peace are all endangered by the Cuban war."),
  ("frus1898","ch83","The President's message on Cuba, 1898: the war is a constant menace to the peace of the United States and a heavy expense.")]),
("1902–1945: a protectorate's security and a sugar economy",
 "From independence to the end of the Second World War the prosperity case is sugar, tariffs and reciprocity, and the security case is treaty rights, Guantánamo and wartime bases.",
 [("frus1902","d294","Squiers encloses the Cuban President's first message: Cuba's remedy for the sugar crisis is a cut in American tariffs and a reciprocity treaty. A Cuban voice, cited as context."),
  ("frus1933v05","d241","Hull's instructions to Welles, 1933: trade as the cure for unrest, and U.S. pressure presented as a way to avoid intervention under the Platt Amendment's treaty."),
  ("frus1934v05","d170","The 1934 Treaty of Relations abrogates the 1903 treaty but keeps the Guantánamo naval station."),
  ("frus1945v09","d745","Norweb, 1945: the wartime Batista air base is of great military value to the United States after the war.")]),
("1959–1963: Cuba as a Soviet base, and the economy as a weapon",
 "After the revolution, security and prosperity are fused: Cuba is a Communist base and missile site, and U.S. economic power is turned against the Cuban economy.",
 [("frus1958-60v06","d517","Rubottom, May 1960: sugar legislation and selected economic pressures to create discontent with Castro."),
  ("frus1958-60v06","d567","Gates, July 1960: after the sugar and oil actions, further economic measures against Castro's regime."),
  ("frus1961-63v10","d202","NSC task force, May 1961: Cuba's threat is chiefly as a base and example for Communist revolution in the hemisphere."),
  ("frus1961-63v11","d34","505th NSC meeting, 20 October 1962: the blockade route to stop and remove the strategic missiles.")]),
("1974–1980: a declining stake, a bargaining chip and refugees",
 "In the 1970s the Department doubts the stake itself; under Carter the embargo is a bargaining lever and the 1980 boatlift makes migration a security problem. The 1974 memorandum was found as a semantic neighbour of the 1960 Rubottom memorandum.",
 [("frus1969-76ve11p1","d278","Rush to Kubisch, 1974: the United States has no vital interests in Cuba; the economic denial programme outlived its first aim. Reached through a vector neighbour."),
  ("frus1977-80v23","d19","Policy Review Committee, August 1977: the embargo as a bargaining chip for Cuban restraint abroad and human rights."),
  ("frus1977-80v23","d98","Carter's decision, April 1980: control the flow of Cuban refugees during the boatlift.")]),
]
entries=[]; seen=set()
for h,prose,docs in groups:
    entries.append({"kind":"heading","text":h,"level":1})
    entries.append({"kind":"prose","text":prose})
    dd=[]
    for v,d,n in docs:
        iso=c.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
        dd.append((iso,v,d,n))
    for iso,v,d,n in sorted(dd):
        assert (v,d) not in seen; seen.add((v,d))
        r=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone(); assert r
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[A+n]})
        for q in Q.get((v,d),[]):
            assert q in r[0]
            entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":q})
entries.append({"kind":"prose","text":"Threads not followed in this run: the Madrid legation and Havana consular despatches of 1868–1898 behind the 1870s documents; the 1910s–1920s financial and electoral interventions; the Cuban sugar crop purchases of 1941–1946 read against trade figures; the 1964–1968 and 1969–1976 Cuba documents beyond the one memorandum cited; the editors' unprinted National Security Council policy papers; and any measure of the question's terms that separates the documents' text from the editors' footnotes."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
assert set(Q)<=seen
col={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"Cuba, security and prosperity, 1870–1980",
 "authorLine":"Agent run v4, 2026-10-27","introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
assert not any(e.get('volumeId','').endswith('Ed2') for e in entries)
json.dump(col,open('collection.fruscollection','w'),ensure_ascii=False,indent=1)
print("documents",sum(e['kind']=='document' for e in entries),"excerpts",sum(e['kind']=='excerpt' for e in entries),"all pairs verified in document_cache; all excerpts substrings of body_text")
# overview cites vs collection
ov_ids=set(re.findall(r'historicaldocuments/([^/\s]+)/([^\s,)]+)',ov))
print("overview-cited pairs",len(ov_ids),"missing from collection:",ov_ids-seen)
ovq=re.findall(r'"([^"]+)"',ov)
allq=[q for qs in Q.values() for q in qs]
bad=[q for q in ovq if not any(q in x for x in allq)]
print("overview quoted strings not inside a verified quotation:",bad)
