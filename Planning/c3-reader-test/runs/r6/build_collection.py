# Builds collection.fruscollection from cited.tsv, quotes.json and the notes below; verifies every pair and excerpt
# against document_cache (SELECT body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?)
# and orders documents by document_dates.date_iso within each heading.
import json, sqlite3, re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
A="Agent finding, run r6, 2026-10-25: "
H={"F1":("Before Wilson: control, acquiescence, and a price paid in promises (1877–1911)",
 "These documents show the working test applied before 1913 — control, popular acquiescence, willingness to honour treaties and claims — and how the waiting period was used to extract specific promises. The thread runs from the Díaz case in Mexico through Santo Domingo, Honduras and Nicaragua."),
"F2":("Wilson's test of origin: constitutional succession and a free election (1913–1919)",
 "These documents show the shift from asking what a government would do to asking how it came to power. The thread follows the Huerta case from the last Taft instruction through Wilson's statement and his August 1913 terms, then the refusal to recognize Tinoco in Costa Rica."),
"F3":("Mexico, 1920–1923: recognition traded for property guarantees",
 "These documents show recognition of Obregón tied to guarantees for American property under the 1917 Constitution, with the treaty signature itself to serve as the act of recognition. The thread follows the Department's insistence that it set no conditions while it named them."),
"F4":("Central America's treaty rule, 1923–1936, and its abandonment",
 "These documents show the United States adopting, for Central America only, the 1923 treaty's bar on governments born of coups or revolutions, applying it to Martínez in El Salvador, engineering an exit in 1934, and dropping it in 1936. The Cuban document shows the same lever used outside the treaty."),
"F5":("Consultation, then the attempt to drain recognition of meaning (1943–1950)",
 "These documents show recognition turned into a procedure of consultation among the American republics during the war, limited to Axis influence, and then the Bogotá resolution of 1948, which sought to make continued relations normal and recognition free of judgment."),
"F6":("After 1950: continuity as the default, conditions bargained case by case",
 "These documents mark how the question was handled after the editors stopped naming it in chapter titles: assurances on communism and capital in the 1950s, election packages under Kennedy, continuation and suspension under Johnson, and timing alone in Chile in 1973. They are markers from a search set, not a census."),
}
N={
("frus1877","d222"):"Seward to Foster, May 1877: the United States waits to recognize Díaz until his election is approved, his government stable and willing to keep its treaties, and wants frontier guarantees before, not after, recognition.",
("frus1878","d344"):"Evarts to Foster, March 1878: recognition of Díaz authorized after claims instalments were paid, with frontier talks to follow the act.",
("frus1904","d228"):"Powell to Hay, December 1903: the legation names four claims and concessions the Dominican provisional government must accept before recognition, and the government accepts them.",
("frus1907p2","d22"):"Bacon to the Mexican Ambassador, August 1907: joint U.S.–Mexican recognition of Dávila's provisional government in Honduras, after asking about a constitution and elections.",
("frus1911","d933"):"Instruction to the new minister in Nicaragua, January 1911: the history of withholding from Zelaya and Madriz and recognizing Estrada on pledges of reform made to the Dawson mission.",
("frus1913","d873"):"Knox to the Ambassador in Mexico, 25 February 1913: no formal recognition of those de facto in control without specific instructions — the Taft administration's last word on Huerta.",
("frus1913","d7"):"Bryan's circular of 12 March 1913 transmitting Wilson's statement of 11 March: cooperation only with governments resting on law, not on force.",
("frus1913","d1028"):"Bryan's telegram of 27 August 1913 with Wilson's message to Congress: the four conditions for a Mexican settlement, including a free election in which Huerta does not stand, and a pledge to recognize the government so chosen.",
("frus1917","d379"):"Lansing to Hale, February 1917: no government in Costa Rica except one elected legally and established under the Constitution will be recognized; none set up by Tinoco will be.",
("frus1917","d409"):"Chargé Johnson, June 1917: Tinoco's reply that recognition is desirable but not necessary and that he will not retire.",
("frus1920v03","d230"):"Davis memorandum, September 1920: the United States denies dictating conditions but requires protection of life and property, repair of damages and assurances against repetition before recognition.",
("frus1921v02","d344"):"Hughes's public statement of June 1921: protection of property titles against retroactive application of the 1917 Constitution, by treaty; signing the treaty will itself accomplish recognition.",
("frus1922v02","d569"):"Hughes to Summerlin, January 1922: Mexico proposes claims conventions first and the treaty after, with implicit recognition at the first signature.",
("frus1923v02","d345"):"Hughes to the Minister in Honduras, June 1923: public statement that U.S. recognition policy in Central America will follow Article II of the 1923 treaty, quoted in full.",
("frus1930v01","d375"):"Stimson's press release of September 1930: recognition of the Argentine, Peruvian and Bolivian provisional governments on control, no active resistance, intention to meet obligations and to hold elections; Central America is the treaty exception.",
("frus1932v05","d618"):"Stimson to the chargé in El Salvador, January 1932: Martínez can under no circumstances be recognized under the 1923 treaty; any eligible designate would be.",
("frus1934v05","d75"):"Phillips to Caffery, January 1934: the Department tells the British that recognizing the Grau San Martín regime in Cuba would be a great mistake.",
("frus1934v05","d199"):"Welles to Roosevelt, January 1934: a procedure by which the remaining treaty states, and then the United States, recognize Martínez once El Salvador and Costa Rica have denounced the treaty.",
("frus1935v04","d823"):"Welles for the Secretary to Lane, April 1935: the treaty's bar on officials of the six preceding months applies only to those who reach power by coup or revolution; no comment in advance on any future regime.",
("frus1936v05","d112"):"Hull to the Minister in Honduras, April 1936, with the Department's memorandum: the United States will no longer be guided by Article II; diplomats are to give no advice on domestic questions.",
("frus1944v07","d1"):"Hull to Lane in Bogotá, January 1944: the Montevideo resolution requires consultation on Axis influence only; the decision to recognize stays with each government.",
("frus1944v07","d386"):"Hull's circular of January 1944: the United States accepts the Committee's resolution that the new Bolivian government be recognized only after consultation.",
("frus1944v07","d1018"):"Stettinius's circular of June 1944: Ecuador's Velasco Ibarra government meets the tests of control, no resistance, obligations and security; consult and recognize simultaneously.",
("frus1944v07","d1020"):"Stettinius's circular of June 1944: recognition of Ecuador after consultation found no pro-Axis inspiration; announcement to cite the Montevideo resolution.",
("frus1945v09","d875"):"Stettinius's circular of January 1945: after three months of consultation and a peaceful election, the Aguirre government in El Salvador should be recognized.",
("frus1945v09","d1172"):"Byrnes's circular of October 1945: recognition of the Venezuelan junta after consultation found no pro-Axis inspiration.",
("frus1946v11","d773"):"Byrnes's circular of March 1946: Haiti's military junta; concern about promises of democracy broken after recognition, set against the junta's control and its call for elections.",
("frus1948v09","d75"):"Marshall's circular of January 1948: tally of American republics for and against recognizing Román in Nicaragua; the United States follows the majority.",
("frus1948v09","d384"):"Marshall to the Embassy in Costa Rica, May 1948: the Bogotá resolution summarized; the question of recognizing the new Costa Rican regime should not arise.",
("frus1948v09","d89"):"Daniels memorandum, November 1948: relations with Peru's military junta on the basis of the Bogotá resolution, which separates relations from approval and avoids the word recognition.",
("frus1949v02","d446"):"Jamison memorandum, December 1949: an ambassador's remark that nonrecognition reflects disapproval of force undercuts the policy of separating recognition from approval.",
("frus1950v02","d476"):"Mann memorandum, May 1950: Haiti's junta meets the tests; consult, give 72 hours' notice, and move when about half the republics have continued relations so the United States does not lead.",
("frus1952-54v04","d327"):"Acheson to Truman, March 1952: continuation of relations with Batista after assurances on international obligations, private capital and communism.",
("frus1952-54v04","d136"):"Acheson to Truman, May 1952: Bolivia's revolutionary government; control of the territory as the first prerequisite, tin nationalization, and concerted recognition.",
("frus1955-57v06","d353"):"Dreier to Rubottom, July 1957: on Haiti, the Bogotá resolution puts the burden of proof on withholding; elections should not be made a condition.",
("frus1961-63v12","d417"):"Rusk to Lima, June 1962: contingency plans for a military takeover in Peru — withhold recognition, suspend aid, recall the Ambassador, act with Latin American states.",
("frus1961-63v12","d423"):"Rusk to Lima, July 1962: the package the junta should restate before U.S. recognition — civil liberties, free elections by a date, OAS observers; resumption of relations would not mean resumption of aid.",
("frus1961-63v12","d363"):"Ball to Caracas, December 1963: why the United States recognized the Dominican and Honduran regimes — nonrecognition had achieved what it could.",
("frus1964-68v31","d206"):"NSC meeting, 2 April 1964: on Brazil, doubts about Mazzilli's legality, and Ball's view that relations would simply continue.",
("frus1964-68v31","d132"):"Ball to Buenos Aires, June 1966: contact with the Argentine de facto authorities cut; relations suspended pending consultation with OAS members.",
("frus1964-68v31","d512"):"Department to Lima, October 1968: the Assistant Secretary's thoughts on moving recognition practice toward a variant of the Estrada Doctrine after Peru's coup.",
("frus1969-76v21","d360"):"Davis from Santiago, September 1973: the junta asks for immediate confirmation of relations; the Ambassador asks for a brief delay.",
("frus1969-76v21","d361"):"WSAG minutes, 20 September 1973: Chile's junta is an established fact; recognition timed around Kissinger's confirmation.",
}
quotes={}
for f,v,d,q in json.load(open("quotes.json")): quotes.setdefault((v,d),[]).append(q)
cited=[l.split() for l in open("cited.tsv")]
def date(v,d):
    r=con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(v,d)).fetchone(); return (r[0] if r else "") or ""
intro=open("overview.md",encoding="utf-8").read().split("## The bottom line")[1].split("**Scope.**")[0]
intro=re.sub(r"\*\*(\d)\. ([^*]+)\*\*",r"\1. \2",intro).strip()
intro=re.sub(r"\*([^*]+)\*",r"\1",intro)
entries=[]
seen=set()
for F in ["F1","F2","F3","F4","F5","F6"]:
    entries.append({"kind":"heading","text":H[F][0],"level":1})
    entries.append({"kind":"prose","text":H[F][1]})
    docs=sorted([(date(v,d),v,d) for f,v,d in cited if f==F])
    for dt,v,d in docs:
        r=con.execute("SELECT body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        assert r and r[1]==0 and r[2]==0 and (v,d) not in seen and not v.endswith("Ed2")
        seen.add((v,d))
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[A+N[(v,d)]]})
        for q in quotes.get((v,d),[]):
            assert q in r[0]
            entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":q})
entries.append({"kind":"prose","text":"Threads not followed in this run (run r6, 2026-10-25): the roughly 600 unchaptered recognition candidates before 1895; the roughly 110 post-1950 search results beyond the eleven read here, including the Guatemalan, Nicaraguan (1979) and Bolivian cases; the 1937–38 exchange on continuing relations with Vargas's Brazil without a formal act of recognition; the Legal Adviser's memoranda; the Uruguayan Foreign Minister Larreta's note of November 1945 (retrieved, not read); Latin American governments' own doctrines such as Mexico's Estrada Doctrine, which FRUS holds only as reported; and the archival series named in the overview, none of which has been consulted."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
col={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"Recognizing governments that came to power by force — Latin America",
 "authorLine":"Agent run r6, 2026-10-25",
 "introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
json.dump(col,open("collection.fruscollection","w",encoding="utf-8"),ensure_ascii=False,indent=2)
print("documents",sum(e["kind"]=="document" for e in entries),"excerpts",sum(e["kind"]=="excerpt" for e in entries),"headings",sum(e["kind"]=="heading" for e in entries),"prose",sum(e["kind"]=="prose" for e in entries))
