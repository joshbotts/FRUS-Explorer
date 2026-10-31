import json,re,sqlite3
from quotes import Q
RUN="Agent finding, run s4, 2026-10-30: "
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
P=lambda v,d:(v,d)
sections=[
("1. Corruption charged as a reason to act: Hawaii, 1892–93, and Korea, 1894",
 "These four documents show corruption being alleged, by an American minister and by a foreign government, as the ground for action against a third country's rulers. They matter because the allegation did the work of an argument, and because the printed record itself contains the counter-charge. Whether Washington acted because of the charge is not shown by them.",
 [("frus1894app2","d172","Stevens, the U.S. Minister in Honolulu, tells Blaine on 2 April 1892 that the palace has been 'the center of corruption and scandal' for twenty years and will stay so while the monarchy lasts, and presses the need for a U.S. vessel. Shows the charge arriving in Washington attached to a request for force."),
  ("frus1894app2","d199","Stevens to Foster, 1 February 1893: the petitions against annexation are the work of white men who 'thrived on the palace corruptions'. The charge is turned on the opponents of annexation."),
  ("frus1894app2","d316","The Queen's own statement to the Blount inquiry: she says native legislators sold their votes, a practice 'taught them by the Thurston party'. The corruption charge was contested in the record Congress was given."),
  ("frus1894app1","d27","Gresham to Bayard, 20 July 1894: the Japanese minister says the rebellion in Korea was caused by official corruption and Japan will not withdraw troops until reforms are made. Corruption as another power's stated ground for armed intervention; Gresham asks Japan to deal fairly with Korea.")]),
("2. Money with strings: loans and aid made conditional on honest government",
 "Four cases, 1922 to 1961, in which the United States tied money to a clean-government program: a bank loan to Cuba, aid to Greece, and aid to a military government in Korea. The thread is the lever: officials wrote that aid or consent to a loan could be given or withheld depending on action against corruption. The Cuban cases also show the lever's limit, since the amnesty bill the Department opposed became law in 1924.",
 [("frus1922v01","d852","Crowder, the President's representative in Cuba, reports 30 June 1922 that President Zayas signed the lottery-reform decree 'in the precise form in which I rewrote it', and that he told the Cubans he would not recommend U.S. support for Zayas unless Zayas pressed reform against graft and corruption. The U.S. drafting the target country's anti-corruption decree."),
  ("frus1922v01","d864","State Department memorandum of 10 October 1922: Crowder says an amnesty bill would free the men indicted in the lottery scandals and make it impossible to punish corruption, and that the Department should not consent to a loan unless the bill is killed. The loan as lever."),
  ("frus1922v01","d872","Acting Secretary Phillips to the Cuban chargé, 4 November 1922: the Department has no objection to the loan once revenue assurances are given, but orally voices great concern about the amnesty bill and cabinet changes; the editors add that the amnesty became law in 1924. Reached by similarity to the preceding document, not by any word search; it has no corruption word in it."),
  ("frus1947v05","d23","Acheson to Marshall, 21 February 1947: Greek civil-service corruption means aid cannot be used well, so American and British administrative experts are to be sent. Corruption as the reason aid had to come with administrative reform."),
  ("frus1961-63v22","d221","NSC staff memorandum of 23 May 1961, after the Korean coup: future aid above a minimum to be conditional on performance, and the Koreans to be pressed for action on corruption (civil service, police, taxes, contracting).")]),
("3. China, 1947–1949: aiding a government the Americans called corrupt",
 "The Nationalist government's corruption is the most frequent single judgment in the American reporting on China. These documents show it entering the decision about aid in three ways: as a reason for supervision, as Chiang Kai-shek's own argument for American advisers, and as the stated cost of backing the government anyway.",
 [("frus1947v07","d553","Sprouse's note of a conversation with Chiang Monlin (a Chinese State Council member), 25 July 1947: Chiang Monlin says U.S. aid must come with close supervision and that the greatest corruption is among military commanders in Manchuria. Supervision of aid proposed from the Chinese side."),
  ("frus1947v07","d570","Sprouse's note of a conversation with Vice President Sun Fo, 30 July 1947: aid should be matched by political reform 'through elimination of corruption'. The condition is stated by a senior Chinese official."),
  ("frus1947v07","d582","General Wedemeyer's report from his fact-finding mission, 17 August 1947: Shanghai confirms 'corrupt and inept practices' and Formosa shows the Central Government wasting a chance to give honest administration. Corruption in the mission's own findings."),
  ("frus1948v07","d322","Ambassador Stuart, 16 August 1948: Chiang complains that Americans charge his government with corruption yet do little to help, and says only with American advisers can reforms be made 'which alone would justify material assistance'. The argument turned round."),
  ("frus1949v08","d131","Stuart, 5 February 1949: a retrospective in which the Kuomintang system had become 'so corrupt and inefficient' that orderly reform from within was unlikely. The explanation of the regime's weakness that the Department then carried into its public account."),
  ("frus1949v08","d576","Chargé Clark, 23 August 1949: Li Tsung-jen and Pai Chung-hsi argue that unless the United States 'come to aid of existing government, corrupt as it is', Communist domination is inevitable. The last year's dilemma stated by those on the receiving end.")]),
("4. Vietnam, 1959–1972: knowing about corruption and declining to take control",
 "Over thirteen years of reporting, American officials called corruption in the Saigon government a serious problem, built committees and aid-program reforms to deal with it, considered and rejected a veto over Vietnamese appointments on sovereignty grounds, and in 1967 valued an anti-corruption effort partly for its effect on opinion at home.",
 [("frus1958-60v01","d63","Ambassador Durbrow, 11 April 1959: Diem says the U.S. permitted corruption to rise after a devaluation in Laos and wants aid put into the military budget, which Durbrow reads as wanting fewer controls. Corruption entering the argument about what form aid should take."),
  ("frus1958-60v01","d131","Ambassador Durbrow, 7 April 1960: he tells Diem it might prove difficult to obtain adequate aid for FY 1961 if disturbing reports continue of corrupt practices by the Can Lao party, and cites congressional concern. The editors' chapter heading for this part of the volume names 'the Can Lao Party, corruption, and the use of U.S. aid'. Corruption allegations used in the aid conversation itself."),
  ("frus1958-60v01","d185","Special National Intelligence Estimate, 23 August 1960: Diem has failed to take any major steps against corruption and arbitrary conduct by the Can Lao organization. The intelligence community's view of the same problem four months later."),
  ("frus1964-68v04","d145","Komer to President Johnson, 24 May 1966: the 'only credible stick' is to withhold economic aid, and the Commercial Import Program is being reformed because of criticism of windfall profits and corruption; the editors record Johnson's handwritten approval. A decision about aid mechanics taken because of corruption criticism."),
  ("frus1964-68v05","d185","Rostow to the President, 28 May 1967: Prime Minister Ky is 'utterly frank' that corruption is real, serious and a major source of discontent, and objects that Americans want him to move fast without proof."),
  ("frus1964-68v05","d258","Calhoun to Komer, 27 July 1967: corruption is a key obstacle to pacification, but a rapid reduction would need a U.S. veto over provincial and divisional appointments, an invasion of sovereignty he refuses to seek. The decision not to take control, with its reason."),
  ("frus1964-68v05","d395","Katzenbach to President Johnson, 13 November 1967: the senior group agrees a visible anti-corruption effort would improve 'the Administration's position' and build a more effective government in Saigon. Corruption's effect on U.S. domestic opinion named as a reason to act."),
  ("frus1969-76v08","d191","Washington Special Actions Group, 22 June 1972: Sullivan summarises a Senate Foreign Relations Committee staff report that corruption is countrywide and that U.S. officials 'wink at the corruption'. The allegation arrives in Washington by way of Congress, to be rebutted before the report is issued.")]),
("5. Congress and the press as the channel, 1963–1980",
 "In these four documents corruption reaches policy by way of the legislature: an expected congressional reaction, a Secretary of State holding back equipment because of it, and aid cuts voted by committees.",
 [("frus1961-63v20","d422","Rusk, 29 May 1963: asks how to control corruption in Léopoldville because there would be 'considerable trouble with Congress' over aid to the Congo if corruption were widespread. Anticipated congressional reaction as the stated reason."),
  ("frus1977-80v24","d14","Acting Secretary Christopher to President Carter, 19 May 1977: helicopters promised to Colombia in 1975 under the narcotics program are not delivered because of reported narcotics-related corruption in the Colombian government."),
  ("frus1977-80v23","d257","Habib with Haiti's foreign minister and ambassador, 26 July 1979: the editors record that the Senate Foreign Relations Committee proposed to cancel $18.4 million in aid to Haiti for failing to carry out reforms and end corruption; the U.S. officials sympathise with Haiti's difficulty."),
  ("frus1977-80v23","d264","State Department telegram, 1 August 1980: the House Appropriations Committee cut $2 million from Haiti's aid to 'demonstrate its concern for brutality and corruption'; Haiti's ambassador calls the symbolic effect 'devastating'.")]),
("6. American companies' bribes abroad, 1975–1980",
 "The other direction: the allegation was that Americans, not foreigners, were the corrupters. These eight documents show the State Department managing the diplomatic consequences of disclosures about United Brands and Lockheed, and then the cost debate after the Foreign Corrupt Practices Act.",
 [("frus1969-76ve11p1","d159","Rogers to Kissinger, 28 March 1975: the SEC has found that United Brands promised a $2.5 million bribe to the President of Honduras; the Department is 'organizing ourselves for the crunch' and expects the revelation to damage the Honduran government and the image of U.S. firms."),
  ("frus1969-76ve09p2","d135","Embassy Jidda, 13 May 1975: if allegations of corruption and bribery of Saudi officials become widely public, bilateral relations and American business 'could be extremely damaged'."),
  ("frus1969-76ve09p2","d161","Ambassador Akins, 11 September 1975: Prince Sultan says the Department or the President must make sure the names of Lockheed's Saudi payees are never divulged, or the special relationship ends; Akins relays that Congress, not the executive, controls disclosure."),
  ("frus1969-76ve15p2","d292","Hartman to Eagleburger, 30 September 1975: Senate subcommittee staff have evidence of Lockheed payments to Franz Josef Strauss's party and to Prince Bernhard of the Netherlands; Hartman sees nothing useful the Department can do."),
  ("frus1969-76ve15p2","d293","Lowenstein memorandum of 7 October 1975, the companion of the Hartman memorandum; the editors' footnote records Kissinger telling Ford on 8 October: 'We must do everything possible to keep this quiet.' The first edition is cited; the second edition reprints the same text and is not counted."),
  ("frus1969-76ve12","d218","Prime Minister Miki to President Ford, 24 February 1976: asks for the United States to help disclose the names of Japanese officials in the Lockheed affair, in the interest of Japanese democracy."),
  ("frus1969-76ve12","d224","Kissinger and Japan's special envoy, 14 May 1976: Kissinger says the Secretary of State cannot involve himself in a criminal investigation, hopes also 'to avoid any foreign policy embarrassment', and promises to expedite the exchange of documents."),
  ("frus1977-80v03","d230","Memorandum to President Carter, 18 January 1980, on export disincentives: the Foreign Corrupt Practices Act, signed 20 December 1977, heads the list of five; the task force's estimate of export loss ($5–10 billion) 'cannot be supported by firm evidence'.")]),
]
closing=("Threads not followed. (1) The files that FRUS cites but does not print on the Lockheed affair: the Senate subcommittee's hearings and the SEC and Justice Department investigation records. (2) The Japanese, German and Dutch sides of the Lockheed cases. (3) Domestic American corruption as a cause of diplomatic decisions (the spoils system in consular appointments, Teapot Dome): the index returns only a handful of documents, and none was read. (4) Whether corruption reports changed any decision against the other motives named in the same documents: FRUS selects its documents and cannot weigh them. (5) Corruption in the Nicaraguan, Iranian, Philippine, Guatemalan and Mexican files, which turned up in the searches and which this run did not read.")
by={(v,d):(f,t) for f,v,d,t in Q}
entries=[]
used=set()
for head,prose,docs in sections:
    entries.append({"kind":"heading","text":head,"level":1})
    entries.append({"kind":"prose","text":prose})
    for v,d,note in docs:
        r=con.execute("select is_front_matter,is_editorial_note from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
        assert r==(0,0),(v,d,r)
        assert (v,d) not in used,(v,d); used.add((v,d))
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[RUN+note]})
        for f,vv,dd,t in Q:
            if (vv,dd)==(v,d):
                b=re.sub(r"\s+"," ",con.execute("select body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()[0])
                assert t in b,(v,d,t[:40])
                entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":t}); used.add(("q",v,d,t))
entries.append({"kind":"heading","text":"What this run did not follow","level":1})
entries.append({"kind":"prose","text":closing})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
nq=sum(1 for e in entries if e["kind"]=="excerpt")
assert nq==len(Q),(nq,len(Q))
intro=open("intro.txt").read().strip()
coll={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"Corruption and U.S. foreign policy — run s4",
 "authorLine":"Agent run s4, 2026-10-30",
 "introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
json.dump(coll,open("collection.fruscollection","w"),ensure_ascii=False,indent=1)
docs=[(e["volumeId"],e["documentId"]) for e in entries if e["kind"]=="document"]
print("documents",len(docs),"unique",len(set(docs)),"excerpts",nq,"Ed2 volumes:",[d for d in docs if d[0].endswith("Ed2")])
json.dump(docs,open("work/collection_docs.json","w"))
