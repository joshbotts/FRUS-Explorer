# build_collection.py: writes collection.fruscollection from the verified excerpts (excerpts.json, raw substrings of body_text).
# Checks: every document/excerpt pair exists in document_cache (SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?),
# no duplicate document pair, no volume id ending in Ed2, every excerpt text is a raw substring of its body_text.
import json,sqlite3,sys
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
EX=json.load(open('/Users/jbotts/frus-analysis/c3/runs/r9/excerpts.json'))
RUN='Recognition study, 2026-10-25'
def note(t): return f"Agent finding, {RUN}: {t}"
S=[]
def H(t): S.append({"kind":"heading","text":t,"level":1})
def P(t): S.append({"kind":"prose","text":t})
def D(v,d,t,*qids):
    S.append({"kind":"document","volumeId":v,"documentId":d,"notes":[note(t)]})
    for q in qids: S.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":EX[q]['raw']})
H("Before Wilson: control, consent and obligations, 1877–1914")
P("The oldest cases in the series state the test the Department applied to a government that had taken power by arms: did it hold the country, did the people acquiesce, and would it meet the republic's international obligations. Nothing in these instructions asks how the government came to power. The documents run from the year-long wait before recognizing Porfirio Díaz to the two-line telegram recognizing Peru's junta in 1914.")
D("frus1877","d216","Fish authorizes Foster to recognize Díaz, two months after the coup, because an indemnity instalment could not be received from an unacknowledged government; the authorization was not used for another fourteen months.","Q28")
D("frus1878","d344","Evarts states the three things the United States waited for before recognizing Díaz: popular approval, stability, and a disposition to comply with international law; he then waives them because non-recognition was blocking a frontier settlement.","Q1")
D("frus1895p1","d246","Olney's one-sentence statement of the de facto practice: effective relations with the de facto government once fully established with the general consent of the people.","Q2")
D("frus1914","d1799","Bryan recognizes Peru's junta as a provisional government on two findings: uncontested exercise of executive power and free acquiescence of the people.","Q3")
H("Wilson's constitutional test, 1913–1917")
P("Wilson added a question the earlier practice had not asked: whether the government had come to power by constitutional means. The thread runs from the conditions he put to Huerta in August 1913, through the de facto recognition of Carranza in 1915, to the flat refusal to recognize Tinoco in Costa Rica in 1917, where the new test was stated as a rule for the region.")
D("frus1913","d1028","Lind's instructions carry Wilson's four conditions for a settlement in Mexico, with the pledge to recognize the administration chosen on those terms: armistice, an early free election, Huerta not a candidate, and all parties bound by the result.","Q4")
D("frus1913","d1047","Bryan tells the chargé that the President would not recognize a president chosen in Huerta's October election, which lacked the sanctions of law.","Q5")
D("frus1915","d1003","Lansing's letter extending recognition to the de facto Government of Mexico under Carranza, after the Pan-American conference had decided to recognize whichever faction could guarantee life and property.","Q6")
D("frus1917","d378","Lansing's circular to the other Central American governments: no recognition or support for any government in Costa Rica unless clearly proven to be elected by legal and constitutional means.","Q7")
H("Obligations as the price, and the Central American treaty rule, 1921–1938")
P("In the 1920s the Department asked a government that had come to power by force to bind itself first: Hughes made a treaty protecting property rights the act of recognition itself in Mexico, and in Central America the 1923 General Treaty's Article II made non-recognition of coup governments a treaty obligation the United States enforced. Both conditions were given up in the 1930s; the Legal Adviser's 1938 opinion on Brazil shows the narrower rule that replaced them.")
D("frus1921v02","d344","Hughes tells Summerlin that recognition is subordinate: a treaty binding Mexico to protect persons and validly acquired property would itself accomplish recognition of the Obregón government.","Q35","Q8")
D("frus1932v05","d618","Stimson rules that Martínez can under no circumstances be recognized, because of the 1923 treaty, not from any animus against him.","Q9")
D("frus1936v05","d111","Welles agrees that the treaty has become a dead letter through its violation by Guatemala and Honduras, and that no public pronouncement is needed.","Q33")
D("frus1936v05","d112","Hull's instruction to the Central American missions adopting the conclusion that the United States should no longer be guided by Article II in extending or denying recognition.","Q10")
D("frus1937v05","d338","Hackworth: Vargas's abrogation of the constitution raises no occasion for recognition, because the situation is not one where a recognized government was ousted by a coup or revolution.","Q11")
H("War, consultation and the hemisphere, 1943–1947")
P("During the war the question became collective. Hull made hemisphere security and Axis influence the first test for Bolivia's new regime; the Montevideo committee's Resolution XXII asked the republics to consult before recognizing a government established by force; and Byrnes's recognition of Venezuela's junta shows the three-part finding and the fear of being last to recognize. Nicaragua in 1947 shows non-recognition kept up for a year against a Somoza-made government.")
D("frus1943v05","d486","Hull's press statement on the Bolivian regime: hemisphere security and the war effort come first, including whether unfriendly outside influence played a part.","Q12")
D("frus1944v07","d386","The circular transmitting the Montevideo committee's recommendation that the republics consult and exchange information under Resolution XXII before recognizing Bolivia's new government.","Q31")
D("frus1945v09","d1170","Byrnes's circular on Venezuela: control of the country, general support without active opposition, intention to fulfil international obligations, no pro-Axis inspiration; then consultation under Resolution XXII.","Q13")
D("frus1945v09","d1182","Byrnes explains the hurried date: other countries were recognizing and the United States risked being last, to the prejudice of its interests.","Q32")
D("frus1947v08","d733","Marshall insists that contact with Somoza be as a private citizen, not as Minister of War, while the Lacayo regime remains unrecognized.","Q29")
H("The post-war formula: control, obligations, elections as a hope, 1950–1959")
P("After 1950 the Department applied a settled formula, stated almost identically for Haiti, Cuba, Venezuela and El Salvador: the junta controls the country, promises to honour international obligations, and, in the Cold War wording, is free of communist taint; elections are hoped for, not required. Dulles's 1957 telegram on Haiti says in so many words that recognition is not to be used as an instrument of policy.")
D("frus1950v02","d478","Acheson's instruction for Haiti: the note of recognition records the junta's three statements, on international obligations, authority throughout Haiti, and democratic practices with elections as soon as practicable.","Q14")
D("frus1952-54v04","d327","Acheson to Truman on Batista: the regime has requested recognition and given satisfactory statements on international obligations, private capital and communist activities; ten Latin American states have already continued relations.","Q25")
D("frus1955-57v06","d356","Dulles on Haiti's Kebreau junta: recognition is not ordinarily to be used as an instrument of policy, and elections are an internal decision, not a condition precedent.","Q15a","Q15b")
D("frus1958-60v05mSupp","ve_d1","Rubottom's recommendation to recognize Venezuela's junta five days after the fall of Pérez Jiménez, on assurances to foreign investment and anti-communism, because early recognition would steady the new regime.","Q26")
D("frus1958-60v06","d217","Dulles to Eisenhower on Cuba: the new government's statements of intention were made in good faith, it appears free from communist taint, and should be recognized without delay.","Q16")
H("Non-recognition against coups, and the retreat from it, 1962–1979")
P("Kennedy tried to make recognition a lever against military coups in Peru, Ecuador, the Dominican Republic and Honduras, asking for a dated return to elected government; by December 1963 the Department judged the lever exhausted. From 1964 the practice turned to avoiding the question: continuity of relations in Brazil and Bolivia, consultation so as not to recognize first, and an open proposal to adopt the Estrada doctrine, under which a government is dealt with because it exists and not because it is legitimate.")
D("frus1961-63v12","d427","Martin recalls that Ambassador Loeb, on the President's authority, had warned Peru's generals before the coup that recognition would be very difficult and aid next to impossible.","Q17")
D("frus1961-63v10-12mSupp","d109","Rusk's circular on Ecuador: recognition withheld until the junta states its intention to return to civilian government, and not before several other Latin American countries have recognized.","Q18")
D("frus1961-63v12","d363","The Department explains the December 1963 recognition of the Honduran and Dominican regimes: the objective of non-recognition had been the earliest return to constitutionally elected government, and its further prospects were nil.","Q19")
D("frus1964-68v31","d206","Ball at the NSC on Brazil: no recognition problem would arise because the United States would merely continue relations with the President.","Q20")
D("frus1964-68v32","d14","The Embassy reports Dominicans reminding it that United States recognition of the triumvirate had rested on a promised election schedule.","Q27")
D("frus1964-68v31","d141","Rusk asks Johnson to approve the note recognizing Onganía's government two weeks after the Argentine coup; the note itself is not printed, and the editors give its shelf in the Central Files under POL 16 ARG.","Q36")
D("frus1964-68v31","d512","Oliver proposes moving United States recognition doctrine toward a variant of the Estrada doctrine while keeping the Rio Resolution XXVI consultation, over the Peruvian coup.","Q21")
D("frus1969-76ve10","d95","Kissinger to Nixon on Bolivia: the armed forces' mandate permits the legal fiction that Torres's government is a change of administration, so no question of recognition arises.","Q23")
D("frus1969-76v21","d348","The Washington Special Actions Group on Chile: the United States recognizes governments, not heads of government, and should not be first to recognize the junta.","Q22")
D("frus1977-80v24","d133","The Department's instruction on Bolivia, quoted in the editors' note: where there are elements of continuity, no question of recognition arises.","Q30")
D("frus1977-80v15","d282","On Nicaragua, recognition of the Sandinista provisional government is considered natural, with the statement to refer to the provisional government's pledges.","Q24")
P("Threads not followed here: the text of the 1923 General Treaty's Article II and of Resolutions XXII (1943), XXXV (1948) and XXVI (1965) are summarised in editors' notes but not printed; the Mexican and Ecuadorean statements of the Estrada and Tobar doctrines are mentioned, never printed; the notes of recognition after 1963 are mostly 'attached but not printed' and sit in the Central Foreign Policy File under POL 16; the Cuban exile 'provisional government' planning of 1961 and the Grenada and Suriname cases of 1979–80 were set aside as outside the question.")
S.append({"kind":"generated","generatedBlockType":"archivalSources"})
C={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"Recognizing governments that took power by force in Latin America",
 "authorLine":f"Agent run, {RUN}",
 "introductionText":("What FRUS answers directly: the series prints the Department's own statements of the test it applied to a Latin American government that had taken power by force, from Evarts's wait before recognizing Díaz in 1878 to the 1979 recognition of Nicaragua's provisional government, and in each case what it asked of the new government first: control of the country, the people's acquiescence, a promise to honour international obligations, and, in some periods, constitutional origin or a dated return to elections. "
  "Where FRUS points for the rest: the printed documents came almost entirely from the Department of State's central decimal file (Record Group 59), chiefly the 'political affairs' and 'government' classes for each country; the editors' footnotes cite the same file, the Bureau of Inter-American Affairs lot files, and the presidential libraries, and after 1963 the Central Foreign Policy File's POL 16 (Independence. Recognition.) category. "
  "What this request cannot get from FRUS: the texts of the inter-American resolutions on recognition and of the Estrada and Tobar doctrines, the notes of recognition after 1963, and any case before 1876 under these headings; the series mentions them and points to the shelf but does not print them."),
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":S}
# checks
pairs=[(e['volumeId'],e['documentId']) for e in S if e['kind']=='document']
assert len(pairs)==len(set(pairs)),'duplicate document pair'
for e in S:
    if e['kind'] in('document','excerpt'):
        assert 'volumeId' in e and 'documentId' in e
        assert not e['volumeId'].endswith('Ed2')
        assert con.execute("SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?",(e['volumeId'],e['documentId'])).fetchone(), e
        if e['kind']=='excerpt':
            body=con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(e['volumeId'],e['documentId'])).fetchone()[0]
            assert e['text'] in body, ('excerpt not in body',e['volumeId'],e['documentId'])
json.dump(C,open('/Users/jbotts/frus-analysis/c3/runs/r9/collection.fruscollection','w'),ensure_ascii=False,indent=1)
print('documents',len(pairs),'excerpts',sum(1 for e in S if e['kind']=='excerpt'),'headings',sum(1 for e in S if e['kind']=='heading'),'prose',sum(1 for e in S if e['kind']=='prose'))
json.dump(sorted(pairs),open('/Users/jbotts/frus-analysis/c3/runs/r9/collection_pairs.json','w'))
