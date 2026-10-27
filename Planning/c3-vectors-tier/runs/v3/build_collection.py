import json, sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
Q={q["id"]:q for q in json.load(open("quotes_verified.json"))}
A="Agent finding, Cuba security-and-prosperity run, 2026-10-27: "
def doc(v,d,note): return {"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]}
def exc(qid):
    q=Q[qid]; assert q["exact"]; return {"kind":"excerpt","volumeId":q["volumeId"],"documentId":q["documentId"],"text":q["text"]}
def head(t): return {"kind":"heading","text":t,"level":1}
def prose(t): return {"kind":"prose","text":t}
E=[]
E+= [head("1. A rich neighbour that must stay out of European hands, 1874-1886"),
 prose("Why these documents: they are the earliest statements in the indexed library of what Cuba meant to the United States, written while Spain was fighting the Ten Years' War and before any treaty tied the two countries together. The thread is that independence, not annexation, was the stated aim, and that Cuba's value was described in commercial and geographic terms, not in the vocabulary of national security."),
 doc("frus1874","d552","Secretary Fish's instructions to the new minister in Madrid, 6 February 1874. Cuba is described as almost contiguous, commercially closer to the United States than to Spain, and the war there as 'the one great cause of perpetual solicitude' in the nation's foreign relations. Independence is called inevitable and desirable. Index number 552; the printed number is 550."),
 exc("Q01"),exc("Q02"),exc("Q03"),
 doc("frus1881","d405","Secretary Blaine to the minister in Hawaii, 1 December 1881, using Cuba as the model for Hawaii: the 'key to the Gulf', part of the American commercial system though Spanish. The same text is reprinted in an 1894 appendix volume (a near-duplicate found by vector distance of 4 bits); only the 1881 copy is cited."),
 exc("Q04"),
 doc("frus1886","d414","Minister Curry to Secretary Bayard from Madrid, 22 October 1886, on tonnage dues and the sugar trade. The one-line statistic quoted here (the United States buys about 95 per cent of Cuba's sugar exports) is the earliest quantified statement of the trade interest in this run."),
 exc("Q05"),
 head("2. The sugar bowl and the case for war, 1897-1898"),
 prose("Why these documents: in the last year before the war with Spain, American officials set out what they thought Cuba was worth: a sugar supply, a market, American capital, a health risk and a source of disorder at the door. The two documents are an envoy explaining US aims to a foreign ambassador, and the President's own message to Congress."),
 doc("frus1898","d498","Minister Woodford to Secretary Sherman, 5 October 1897: his account to the German ambassador of why the United States cares about Cuba (no annexation, sugar, American investments, yellow fever, the cost of policing neutrality). The best single list of the prosperity case. Its nearest vector neighbours are other Woodford despatches (Hamming distance 32 and 50), which is why those were not added."),
 exc("Q07"),exc("Q06"),exc("Q34"),
 doc("frus1898","ch83","The President's message on Cuba, April 1898 (the index dates it 12 April). It lists four grounds for intervention: humanity, protection of citizens, injury to commerce, and the 'constant menace' to peace and expense of the war. Not in the vector index, which has no row for this chapter-level text."),
 exc("Q09"),exc("Q08"),
 head("3. Security and prosperity written into one treaty system, 1904-1934"),
 prose("Why these documents: after 1898 the two aims are put in one set of instruments. The Platt Amendment's text joins independence, intervention, sanitation and naval stations; a 1929 note shows how much capital Cuba was said to hold; Stimson and Welles apply and argue about the intervention right; and in 1934 the right is dropped while the sugar tariff is cut."),
 doc("frus1904","d207","President Roosevelt's proclamation of the treaty of 22 May 1904, which reprints the eight articles of the Platt Amendment: article III (the right to intervene) and article VII (coaling or naval stations, 'for its own defense'). Security and sanitation (article V) are in the same text."),
 exc("Q11"),exc("Q10"),
 doc("frus1929v02","d924","The Cuban ambassador's note of 10 January 1929 in the negotiation over revising the 1902 reciprocity treaty. The figure of nearly 1,500 million dollars of American capital is the Cuban government's own statement to the Secretary of State, not an American estimate; it is the only investment total printed in this run. The note also names a US Tariff Commission report of 1929 on the treaty's effects."),
 exc("Q12"),
 doc("frus1930v02","d747","Secretary Stimson's background talk to the press, 2 October 1930, during the Machado crisis: the Platt Amendment is about preserving independence, not a protectorate over internal affairs, quoting Root's 1901 reading."),
 exc("Q13"),
 doc("frus1933v05","d299","Ambassador Welles to the President, 8 August 1933: his mission is to avoid a situation that would require intervention under article III of the permanent treaty. Shows intervention still treated as a live obligation in 1933."),
 exc("Q14"),
 doc("frus1934v05","d127","Secretary Hull's instruction of 26 July 1934 on the reciprocal trade agreement. It says the new treaty of relations has removed the permissive right of intervention and presents the sugar duty cut as helping the Cuban people and opening markets for American farm and factory goods."),
 exc("Q15"),exc("Q16"),
 head("4. Hemisphere defence, bases and sovereignty, 1941-1958"),
 prose("Why these documents: the Second World War turned Cuba into a defence problem. They show the Navy and the Joint Chiefs wanting exclusive jurisdiction over bases, the State Department and the Cubans resisting it, and, at the other end, sugar defended as a 'strategic concept' and internal stability defined as hemispheric defence."),
 doc("frus1941v07","d119","State Department memorandum of 14 July 1941 on the Navy's draft for extending the Guantanamo naval station. State argues that leased areas under unquestioned US jurisdiction could not be applied elsewhere in the hemisphere, and the Navy hints it would use Jamaica instead."),
 exc("Q18"),
 doc("frus1944v07","d878","Secretary of State to Ambassador Braden, 20 December 1944, relaying the Joint Chiefs' wish for a long-term lease of the San Antonio de los Banos and San Julian air bases under exclusive US jurisdiction after the war."),
 exc("Q19"),
 doc("frus1945v09","d741","Braden to the Secretary of State, 12 January 1945: President Grau refuses any lease of the bases as a matter of sovereignty, and offers instead to keep them available for the defence of the continent."),
 exc("Q20"),
 doc("frus1952-54v04","d342","Secretary of State to the Secretary of Agriculture, 4 June 1954, opposing a cut in Cuba's share of the US sugar market. It argues from Cuban stability, US exports and the claim that Cuba is a reliable source of sugar in war and peace, 'a strategic concept'."),
 exc("Q17"),
 doc("frus1958-60v06","d70","State-Joint Chiefs meeting, 27 June 1958, on arms supplied to Batista. Murphy links Cuban internal security, leftist exploitation and hemispheric defence; Admiral Burke objects that the US is telling a sovereign nation what to do with its arms."),
 exc("Q21"),
 head("5. Communism, missiles and economic denial, 1959-1963"),
 prose("Why these documents: after Castro, the threat is defined by Soviet weapons and Cuban subversion, and prosperity becomes an instrument: the plan is to hurt the Cuban economy. The October 1962 transcripts show the security argument at its most explicit, including the Defense Secretary's private view that the missiles changed the strategic balance 'not at all'."),
 doc("frus1958-60v05","d112","Director of Central Intelligence Dulles to the Acting Secretary of State, March 1959 (undated): the earliest document in this run to frame Castro as a regional instigator tied to communism. Reached only through vector similarity (106 bits from the Mallory memo, no closer than a median 25th neighbour); it never uses the word Cuba, so a Cuba search would not return it."),
 exc("Q22"),
 doc("frus1958-60v06","d499","Mallory to Rubottom, 6 April 1960, 'The Decline and Fall of Castro': weaken the Cuban economy through sugar legislation and other means to bring about hunger and the overthrow of the government. The turn from prosperity as a shared interest to prosperity as a weapon."),
 exc("Q23"),exc("Q24"),
 doc("frus1961-63v11","d21","Transcript of the first White House meeting on the missiles, 16 October 1962 (long, about 100,000 characters; the quoted exchange is Bundy and McNamara). The Defense Secretary says his own view is that the strategic effect is 'not at all'."),
 exc("Q25"),
 doc("frus1961-63v11","d34","NSC minutes, 20 October 1962: the President says planes in Cuba did not concern him but missiles had 'an entirely different impact' in Latin America. The danger is political and regional as much as strategic."),
 exc("Q26"),exc("Q27"),
 doc("frus1961-63v10-12mSupp","d729","Bundy to President Johnson, 15 December 1963: defines the post-crisis aim as a Cuba that poses no threat to its neighbours and is not a Soviet satellite, and names isolation measures and covert measures as the two chief offensive weapons. Reached only through vector similarity (52 bits from the 1969 study), not by a text search."),
 exc("Q28"),exc("Q29"),
 head("6. A managed problem, 1969-1981"),
 prose("Why these documents: after the missile crisis, Cuba is analysed as a double problem (a Soviet base and an exporter of revolution) whose economic leverage is modest. The last document shows the 1962 understanding still being used to define the limit in 1981."),
 doc("frus1969-76ve10","d205","Interdepartmental study answering National Security Study Memorandum 32, 2 July 1969: ranks US interests in Cuba from preventing strategic weapons (vital) to demonstrating that radicalism does not pay. Found by text search; its nearest vector neighbour (52 bits) is the 1963 Bundy memo above, which is how that memo was found."),
 exc("Q30"),
 doc("frus1977-80v23","d21","Treasury Secretary Blumenthal to President Carter, 12 August 1977, on normalization: lifting the embargo would give little economic leverage; the political significance of trade outweighs economic effects; US claims of about 2 billion dollars could be settled for perhaps 30 per cent."),
 exc("Q31"),exc("Q32"),exc("Q35"),
 doc("frus1981-88v03","d5","Haig to President Reagan, 26 January 1981, on the 1962 US-Soviet understanding, the 1970 clarification on naval facilities, the 1979 brigade and MiG-23s. The aim of the 1962 understanding is restated as keeping Cuba from threatening US and hemispheric security."),
 exc("Q33"),
 prose("Threads not followed in this run. (1) The Ten Years' War and the 1895-98 insurrection were read only through the 1874 and 1897 documents above, not through the despatches of the consuls in Cuba. (2) The 1898-1902 military occupation, the 1906-09 intervention, and the Bay of Pigs were left out; the editors' chapters on them are large and unread here. (3) Congress, the sugar lobbies and public opinion appear only as the officials describe them. (4) The Cuban government's and Spain's own papers are not in FRUS. (5) Nothing after January 1989 is in the indexed library for this topic. (6) The Mariel boatlift and Cuba's African commitments are not followed beyond passing mentions in the 1977 Treasury memorandum and the 1981 Haig memorandum."),
 {"kind":"generated","generatedBlockType":"archivalSources"}]
intro="\n\n".join(["What FRUS answers directly: the printed record shows American officials describing Cuba as a neighbouring, commercially rich island that should become independent and stay out of European hands (1874-1886), a sugar supply, market and source of disorder that justified war (1897-98), a place where security (naval stations, the right to intervene) and prosperity (sugar, tariffs, American capital) were handled in one treaty system (1904-1934), a hemispheric-defence problem (1941-1958), a Soviet and revolutionary threat with prosperity turned into a weapon (1959-1963), and a managed problem whose economic leverage was modest (1969-1981). The set is 23 documents chosen from about 4,900 in the editors' Cuba chapters and about 13,900 that mention Cuba, in the 553 volumes indexed.",
"Where FRUS points for the rest: the printed documents came from the State Department's central decimal file on Cuba, the Kennedy, Johnson, Carter and Eisenhower libraries' national-security files, CIA files and Record Group 59 lot series such as the Cuban Missile Crisis records (Lot 65 D 438, NAID 27022950) and the Operation Mongoose files (Lot 66 D 501, NAID 648748); the editors cite without printing the Executive Secretariat's NSC policy-paper records (Lot 66 D 95, NAIDs 2839192 and 2839193), the Cuba records of the Coordinator of Cuban Affairs (Lot 73 D 191, NAID 1040618) and the sugar records (Lot 65 D 212, NAID 27022874).",
"What this request cannot get from FRUS: the phrase 'national security' is absent from the Cuba chapters before the 1940s, so the earlier thinking has to be read under other names (independence, defence, commerce, sanitation); Cuban and Spanish views, trade and investment statistics, Congress and the sugar lobbies are not systematically printed; and the library holds nothing on Cuba after January 1989."])
col={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"Cuba, national security and prosperity, 1874-1981 (agent run, 2026-10-27)",
 "authorLine":"Agent run, 2026-10-27",
 "introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":E}
# checks
pairs=[(e["volumeId"],e["documentId"]) for e in E if e["kind"]=="document"]
assert len(pairs)==len(set(pairs)), "dup"
for v,d in pairs:
    r=db.execute("select is_front_matter,is_editorial_note from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    assert r is not None and r==(0,0),(v,d,r)
for e in E:
    if e["kind"]=="excerpt":
        assert (e["volumeId"],e["documentId"]) in pairs
        b=db.execute("select body_text from document_cache where volume_id=? and document_id=?",(e["volumeId"],e["documentId"])).fetchone()[0]
        assert e["text"] in b
assert not any(v.endswith("Ed2") for v,d in pairs)
json.dump(col,open("collection.fruscollection","w"),indent=2,ensure_ascii=False)
print("documents",len(pairs),"excerpts",sum(e["kind"]=="excerpt" for e in E),"headings",sum(e["kind"]=="heading" for e in E))
