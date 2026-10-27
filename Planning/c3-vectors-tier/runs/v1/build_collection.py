import json,sqlite3
Q={x["id"]:x for x in json.load(open("quotes.json"))}
A="Agent run v1, 2026-10-27: "
def doc(v,d,note): return {"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]}
def exc(qid): x=Q[qid]; return {"kind":"excerpt","volumeId":x["volumeId"],"documentId":x["documentId"],"text":x["text"]}
E=[]
def H(t): E.append({"kind":"heading","text":t,"level":1})
def P(t): E.append({"kind":"prose","text":t})
H("The neighbor with a market, 1874–1898")
P("Before 1898 these documents state Cuba's importance as proximity plus trade: a rich island next door whose wars cost American commerce and whose ownership by a European power was an irritant. The thread runs from Hamilton Fish's instruction of 1874 through the despatches of 1897 to the President's war message of April 1898, which names both commerce and peace as stakes.")
E.append(doc("frus1874","d552","Fish tells the new minister in Madrid why Cuba matters to the United States: it is nearly contiguous, a large potential market, and the one great cause of perpetual solicitude. The same paragraph says the claims of citizens, not security as such, are the daily business."))
E+= [exc("Q01"),exc("Q02"),exc("Q03")]
E.append(doc("frus1898","d498","Woodford reports to Sherman what he told the German ambassador in Madrid for transmission to Berlin: the United States seeks no annexation or protectorate, depends on Cuba for sugar, and has seen its property idle and its commerce with Cuba destroyed. The prosperity argument in its plainest form, addressed to a European power."))
E.append(exc("Q04"))
E.append(doc("frus1898","ch83","The President's message to Congress on Cuba (dated by the index 12 April 1898). It lists four grounds for intervention, the third commercial and the fourth the menace to the nation's peace and the cost of a semi-war footing."))
E+= [exc("Q05"),exc("Q06")]
H("A protectorate for security and a preferred market, 1902–1934")
P("From the Platt terms of 1902 to the abrogation of 1934 the two stakes are written into instruments: no foreign lodgment and a right to intervene on the security side, preferential trade on the prosperity side. The 1917 memorandum shows the war turning Cuba's value into sugar and manganese; the 1933 instruction and the 1934 treaty show the intervention right ended while the naval station and the preferential trade stayed.")
E.append(doc("frus1902","d273","Roosevelt's message of 27 March 1902 sets the Platt terms before Congress: the exclusion of any foreign power from lodgment in Cuba by colonization or for military or naval purposes, and, in its last lines, the commerce between the two countries."))
E+= [exc("Q07"),exc("Q30")]
E.append(doc("frus1918","d333","August 1917: the Department tells the Cuban minister that Cuba's greatest aid in the war would be economic rather than military, and the Department would hesitate to approve a loan unless the damaged Cuba Railway were restored so that sugar and manganese could be made readily available."))
E.append(exc("Q08"))
E.append(doc("frus1933v05","d241","Hull's first instruction to Welles says policy toward Cuba is governed by the first five articles of the 1903 treaty, which include the intervention right and the exclusion of foreign powers."))
E.append(exc("Q31"))
E.append(doc("frus1934v05","d170","The Treaty of Relations of 29 May 1934 abrogates the 1903 treaty and the intervention right but keeps the Guantanamo naval station in force."))
E.append(exc("Q09"))
E.append(doc("frus1934v05","d154","The reciprocal trade agreement of 24 August 1934 presents itself as a continuation of the 1902 commercial reciprocity convention: the preferential market outlived the protectorate."))
E.append(exc("Q32"))
H("Defense and sugar together, 1941–1952")
P("From the Second World War to the early 1950s the two stakes are stated in a single breath: Cuba as a defense location and as the source of sugar, with American investment large and Cuban stability the aim. The 1948 memorandum adds the lever, that tariff or quota could plunge the island into poverty, which later turns up in 1959 and 1960.")
E.append(doc("frus1941v07","d134","Messersmith urges prompt action on Cuban counterproposals because of 'economic and defense reasons': the loss of European sugar and tobacco markets has to be weighed with the political and defense factors."))
E.append(exc("Q10"))
E.append(doc("frus1948v09","d420","Pre-Castro statement of why Cuba matters: nearness, sugar, the largest American investments, and the leverage of tariff or quota. It is the nearest neighbor in the vector space of the 1951 policy statement."))
E.append(exc("Q11"))
E.append(doc("frus1950v02","d440","The 1951 policy statement puts strategic location, Guantanamo, sugar in two wars and about three-quarters of a billion dollars of private investment in one text, and names security of the hemisphere the first objective."))
E.append(exc("Q12"))
E.append(doc("frus1952-54v04","d331","A 1952 position paper treats Cuban economic and political stability as a United States interest and weighs a sugar sale behind the Iron Curtain against it."))
E.append(exc("Q25"))
H("Prosperity turned into a weapon, 1959–1960")
P("Once Castro's government is judged hostile, the instruments of prosperity, the sugar quota and trade, become the instruments of security policy. The documents show the choice being made in 1959, the quota cut proposed in June 1960 and the Secretary of Defense in July asking what further economic measures to take.")
E.append(doc("frus1958-60v06","d362","September 1959: Rubottom names the 'retaliatory instruments', GATT and the sugar quota, as likely to be used."))
E.append(exc("Q13"))
E.append(doc("frus1958-60v06","d532","22 June 1960 NSC meeting: Anderson and Dillon propose cutting Cuba's preferential sugar quota by 20 to 25 per cent as a means of economic pressure."))
E.append(exc("Q15"))
E.append(doc("frus1958-60v06","d535","Rubottom, 27 June 1960, records that nearly a year earlier the Department and the CIA decided friendly relations were impossible and that means should be devised to bring about Castro's overthrow."))
E.append(exc("Q28"))
E.append(doc("frus1958-60v06","d567","Gates to Herter, 26 July 1960: the sugar and oil actions have crossed a Rubicon, and further economic measures should be applied together, not staggered."))
E.append(exc("Q14"))
H("October 1962: geography or politics?")
P("Two transcripts of 16 October 1962 show the threat judged in opposite ways within the same room: as a base 'intolerable and not acceptable', and as, in McNamara's words, no military problem but a domestic, political one. Kennedy's own remark that geography does not mean much belongs between them.")
E.append(doc("frus1961-63v11","d18","Morning meeting of 16 October 1962: Rusk's proposed message to Castro calls the missile base intolerable and not acceptable."))
E.append(exc("Q18"))
E.append(doc("frus1961-63v11","d21","Evening meeting of 16 October 1962: Kennedy says geography does not mean much, and McNamara says he does not think there is a military problem but a domestic, political one. This transcript is the nearest neighbor of the morning one in the vector space."))
E+= [exc("Q16"),exc("Q17"),exc("Q26")]
H("From threat to test of Soviet conduct, 1969–1981")
P("After the missile crisis the documents rank the interests: a vital interest in keeping strategic weapons out of Cuba, lesser ones in improved relations, then in 1977 an American list of conditions (restraint in Africa) against a Cuban wish for markets, in 1979 a presidential statement that a Soviet brigade is no direct threat, and in 1981 an intelligence paper that treats Cuba mainly as a sore spot in the Soviet-American relationship.")
E.append(doc("frus1969-76ve10","d205","NSSM 32 study of July 1969 ranks United States interests in Cuba: preventing strategic weapons is the one vital interest; improved relations are among 'subsidiary and lesser' interests."))
E+= [exc("Q19"),exc("Q20")]
E.append(doc("frus1977-80v23","d18","July 1977 State paper on how to proceed with Cuba: United States objectives are restraint abroad and ties with the Soviet Union; Cuba's aim is access to American markets and technology."))
E+= [exc("Q29"),exc("Q21")]
E.append(doc("frus1977-80v01","d129","Carter's address of 1 October 1979 on the Soviet brigade: no direct threat to the United States, and no nuclear threat as in 1962."))
E+= [exc("Q22"),exc("Q23")]
E.append(doc("frus1981-88v03","d10","Intelligence and Research paper of 30 January 1981: Cuba as a sore spot in the United States-Soviet relationship, with possibly upwards of 6,000 Soviet military personnel in Cuba and recurring strategic concerns."))
E.append(exc("Q24"))
P("Threads not followed in this run: documents about Havana that never use the word Cuba (1,137 across the four periods, unread); the Virginius affair and the claims correspondence of the 1870s beyond a few windows; the reciprocity negotiations of the 1880s; the Crowder missions of 1919 to 1923; the Ferrara sugar-tariff exchanges of 1927 to 1929; the revolution years before 1958; the African and Central American chapters of the 1970s and 1980s; the microfiche supplements; and anything dated after 1988, which the indexed series does not hold. The Hamming-neighbour lists were not read beyond the ten nearest for a handful of anchors.")
E.append({"kind":"generated","generatedBlockType":"archivalSources"})
intro=("What FRUS answers directly: the printed record shows U.S. officials tying Cuba to American commerce and to proximity from 1874, to commerce and peace in 1898, to exclusion of rivals and a preferred market under the Platt terms and the 1934 agreements, to defense and sugar together in the 1940s and 1950s, to sugar and trade turned into pressure in 1959 and 1960, and, after 1962, to a ranked list in which only strategic weapons are vital. "
 "Where FRUS points for the rest: the documents came mostly from the Department of State's central decimal file (Cuba is file class 837) before 1958 and from the Kennedy, Johnson, Nixon, Carter and Eisenhower libraries, the CIA and State lot files after it; the footnotes cite Department of State lot files such as the NSC policy-paper records, the Secretary's memoranda of conversation, the Special Assistant on Communism's subject files and the records relating to sugar, and the Carter and Kennedy national security files, none printed. "
 "What this request cannot get from FRUS: statistics of trade and investment, Congress and public opinion, the Cuban side, and anything after 1988; the pre-1900 record is despatches only, with almost no source citations in the index.")
col={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"Cuba, national security and prosperity, 1874–1981","authorLine":"Agent run v1, 2026-10-27","introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},"entries":E}
json.dump(col,open("collection.fruscollection","w"),ensure_ascii=False,indent=1)
# checks
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pairs=[]; bad=0
for e in E:
    if e["kind"] in("document","excerpt"):
        assert e.get("volumeId") and e.get("documentId")
        r=c.execute("SELECT body_text,is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(e["volumeId"],e["documentId"])).fetchone()
        assert r and r[1]==0 and r[2]==0,(e["volumeId"],e["documentId"])
        if e["kind"]=="excerpt":
            if e["text"] not in r[0]: bad+=1; print("EXCERPT NOT IN BODY",e["volumeId"],e["documentId"],e["text"][:50])
        else: pairs.append((e["volumeId"],e["documentId"]))
assert len(pairs)==len(set(pairs))
assert not any(v.endswith("Ed2") for v,_ in pairs)
print("documents",len(pairs),"excerpts",sum(1 for e in E if e["kind"]=="excerpt"),"bad excerpts",bad,"intro chars",len(intro))
