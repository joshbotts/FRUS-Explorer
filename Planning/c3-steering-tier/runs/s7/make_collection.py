import json,sys
sys.path.insert(0,"/Users/jbotts/frus-analysis/c3s/runs/s7")
from db import q
Q=json.load(open("quotes.json"))
A="Agent run s7, 2026-10-30: "
intro=("What FRUS answers directly: the printed record shows corruption entering U.S. decisions in recurring ways: as a pretext a debtor government used against arbitral awards (Venezuela, 1875); as a diagnosis that shaped how far Washington would back a client (Nationalist China, 1947–48; South Korea, 1961); as an obstacle to a war aim that the United States chose not to override at the cost of sovereignty (South Vietnam, 1966–67); and, from 1975, as American corporate bribery abroad that became a matter of diplomacy (Lockheed and Japan, West Germany) and of trade policy (the Foreign Corrupt Practices Act). About 2,700 documents in about 435 of the 553 volumes use the words corruption or bribery, and the rate rises sharply after 1945. "
"Where FRUS points for the rest: the documents came chiefly from the State Department's Central Decimal File (RG 59), from the National Security Files and President's Office Files of the Johnson and Kennedy Libraries, from the Ford Library's Presidential Correspondence with Foreign Leaders, and from Executive Secretariat lot files such as Lot 63D351 (RG 59, Records Relating to National Security Council Policy Papers, Entry A1 1586E, NAID 2839192, 1947–1979, partly restricted); the editors cite without printing further decimal files on South Korean and Indochinese internal politics and Lot 66D95 (same series) and Lot 62D1 (RG 59, Policy Planning Council, NAID 2838992). "
"What this request cannot get from FRUS: the series ends in the late 1980s for this subject (about 6,000 dated documents in the 1980s against 76,000 in the 1940s), so the later anti-corruption regime is outside it, and the modern word 'kleptocracy' never appears (controls passed), which shows only that contemporaries said 'corruption'; 'questionable payments', the 1975–76 term for corporate bribery, cannot be counted because the index folds it into unrelated phrases; enforcement of the 1977 anti-bribery law appears in four documents in two volumes, so the Justice Department's and the SEC's own files are the shelf for that; and the 1867–68 Venezuelan commission scandal itself is printed only as Venezuela's charge, not as an inquiry.")
E=[]
def doc(v,d,note): E.append({"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]})
def exc(v,d):
    for qv,qd,t in Q:
        if qv==v and qd==d: E.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":t})
def H(t): E.append({"kind":"heading","text":t,"level":1})
def P(t): E.append({"kind":"prose","text":t})
H("Corruption as a lever in claims diplomacy, 1875")
P("Two despatches of 1875 show a debtor government using charges of corruption against an arbitral commission to refuse payment, and the Secretary of State refusing to let vague charges reopen a settled award. They follow the Venezuelan claims dispute.")
doc("frus1875v01","d199","The U.S. minister at Bogotá (Scruggs) reports that Venezuela's President Blanco intends never to pay the awards, using the alleged corruption of the commission as his pretext."); exc("frus1875v01","d199")
doc("frus1875v02","d393","Secretary Fish, in conversation with the Venezuelan envoy, dismisses vague allegations of corruption and threatens a break in relations if Venezuela does not pay; the envoy names the U.S. minister Stilwell. The index dates this 1874-06-04; its dateline reads June 4, 1875."); exc("frus1875v02","d393")
H("Nationalist China, 1947–1948: diagnosis and a contest over American opinion")
P("Wedemeyer's fact-finding mission reported corruption as a structural fact of the Nationalist regime, while the Nationalist government complained that American reporting of corruption was turning U.S. opinion. Together they show corruption as both evidence in an aid decision and a public-relations problem for the client.")
doc("frus1947v07","d582","Wedemeyer to Marshall, August 1947: corruption and inept practice reaffirmed in Shanghai, Formosa misgoverned, smuggling through the south."); exc("frus1947v07","d582")
doc("frus1948v07","d43","Stuart reports a Chinese government spokesman's complaint that U.S. reporters play up corruption and graft, so that Americans believe the whole government corrupt."); exc("frus1948v07","d43")
H("South Korea, 1961: corruption as a threat to the aid program")
P("The Farley report argued that graft and corruption endangered the U.S. position in Korea and the Mutual Security program; Rostow carried it to Kennedy. The second document was reached through a vector neighbour, not a word search: it never uses the word corruption.")
doc("frus1961-63v22","d202","ICA officer Hugh Farley's report, March 1961: graft, corruption and fraud endanger the U.S. position and the aid program; he resigned over his stand on corruption."); exc("frus1961-63v22","d202")
doc("frus1961-63v22","d204","Rostow to Kennedy, March 15, 1961: the Farley paper and State's more cautious reading; reached by semantic neighbour of the Farley report."); exc("frus1961-63v22","d204")
H("South Vietnam, 1966–1967: an obstacle to pacification and the limits of leverage")
P("In Saigon, U.S. officials judged corruption a key obstacle to the war aim but declined to act on it at the risk of a coup or at the cost of taking over Vietnamese sovereignty. These two documents show the trade-off stated in their own words.")
doc("frus1964-68v04","d215","Ky and Lodge discuss corrupt generals; Lodge had decided not to raise corruption for fear of precipitating a coup, and endorses delay until after the election."); exc("frus1964-68v04","d215")
doc("frus1964-68v05","d258","Calhoun to Komer, July 1967: corruption a key obstacle to pacification, but rapid reduction would need a U.S. veto over appointments, which he advises against seeking."); exc("frus1964-68v05","d258")
H("American bribery abroad, 1975–1978: a problem of diplomacy and of trade policy")
P("After the Church subcommittee's hearings, corporate payments to foreign officials became a matter between governments, and later a cost weighed in export policy. The first document reports a Senate staff member's allegations, not established findings.")
doc("frus1969-76ve15p2","d292","Hartman memo, September 1975, relaying the Church subcommittee staff's allegations of Lockheed payments in West Germany (allegations, as reported)."); exc("frus1969-76ve15p2","d292")
doc("frus1969-76ve12","d218","Prime Minister Miki asks President Ford to help disclose the names of Japanese officials in the Lockheed affair, warning of harm to Japanese democracy."); exc("frus1969-76ve12","d218")
doc("frus1977-80v03","d152","Eizenstat to Carter, July 1978: the export package; repealing the foreign bribery law named among unwise options; guidelines for the Foreign Corrupt Practices Act recommended."); exc("frus1977-80v03","d152")
P("Threads not followed: Nicaragua under Somoza (1977–80, Central America volume), Iran 1977–80, the Philippines, the 1975–79 negotiation on an international agreement on illicit payments (16 documents, four volumes), corruption of U.S. officials themselves, and 'graft' and 'embezzlement' as separate families. The CORDS/MACV 'GVN Corruption 1967' file at the Center of Military History and the Kissinger records (RG 59, Entry 5403) are not resolved by the bundled indexes.")
E.append({"kind":"generated","generatedBlockType":"archivalSources"})
pairs=[(e["volumeId"],e["documentId"]) for e in E if e["kind"]=="document"]
assert len(pairs)==len(set(pairs))
for v,d in pairs+[(e["volumeId"],e["documentId"]) for e in E if e["kind"]=="excerpt"]:
    assert q("SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?",(v,d),"collection-verify"), (v,d)
    assert not v.endswith("Ed2")
C={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"Corruption and U.S. foreign policy: five cases in FRUS","authorLine":"Agent run s7, 2026-10-30","introductionText":intro,
"composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},"entries":E}
json.dump(C,open("collection.fruscollection","w"),ensure_ascii=False,indent=2)
print("documents",len(pairs),"excerpts",sum(e["kind"]=="excerpt" for e in E),"all pairs verified")
