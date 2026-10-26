import json,sqlite3
ex=json.load(open("excerpts.json"))
A="Agent finding, run r8, 2026-10-25: "
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
def D(v,d,note): return {"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]}
def E(q): e=ex[q]; return {"kind":"excerpt","volumeId":e["volumeId"],"documentId":e["documentId"],"text":e["text"]}
def H(t): return {"kind":"heading","text":t,"level":1}
def P(t): return {"kind":"prose","text":t}
entries=[
H("1. Wilson's constitutional test, 1913–1921"),
P("Why these documents: they are the printed statements in which the Wilson administration refused recognition to governments that had seized power and said what it wanted instead: a free election in which the usurper did not stand (Mexico, 1913), a government elected under the constitution (Costa Rica, 1917), and an election before recognition, taken jointly with Argentina and Brazil (Bolivia, 1920–1921). The thread is a recognition policy built on the legitimacy of the government's origin, not on its control of the country."),
D("frus1913","d7","Bryan's circular carrying Wilson's declaration of March 11, 1913: just government rests on the consent of the governed; no sympathy for those who seize power. The statement every later refusal cites by implication."),
E("Q1"),
E("Q29"),
D("frus1913","d1028","Bryan to the Chargé in Mexico, August 27, 1913, transmitting Wilson's address to Congress: the Lind proposals to Huerta (armistice, early free election, Huerta not a candidate, all parties to abide by the result) and a pledge to recognize the administration so chosen."),
E("Q2"),
E("Q30"),
D("frus1913","d1029","Foreign Secretary Gamboa's reply to the Lind proposals, August 16, 1913: the Huerta government's refusal, denying that Mexico was failing its international obligations and calling Wilson's premise a delusion."),
E("Q27"),
D("frus1917","d379","Lansing to Minister Hale, February 9, 1917: the Costa Rican formula, that only a government elected legally and established under the constitution is entitled to recognition, and the instruction that no government set up by Tinoco will be recognized."),
E("Q3"),
D("frus1917","d407","Lansing to Chargé Johnson, June 9, 1917: Wilson's refusal to recognize Tinoco reaffirmed as final, with the argument that a government must command popular confidence at home and recognition abroad."),
D("frus1920v01","d391","Acting Secretary Davis to the Ambassador in Brazil, September 27, 1920: the United States and Argentina agree to wait for Bolivia's November elections before recognizing the government that the July coup produced, and invite Brazil to act together."),
E("Q4"),
D("frus1921v01","d238","Colby to Ambassador Stimson in Argentina, January 31, 1921: the Saavedra government recognized as the constitutional, not the de facto, government of Bolivia after an election under the amended constitution; the three governments credited with postponing recognition until the will of the people was shown."),
E("Q5"),
H("2. The Central American rule: Article II of the 1923 treaty, 1923–1936"),
P("Why these documents: in Central America the United States borrowed a rule the five republics had written for themselves. Article II of the 1923 General Treaty of Peace and Amity barred recognition of any government that came to power by coup or revolution until freely elected representatives had reorganized the country, and barred the coup's leaders and recent ministers from the presidency. These documents show the rule adopted (1923), applied to its hardest case (El Salvador, 1932–1934) and given up (1936)."),
D("frus1923v02","d345","Hughes to the Minister in Honduras, June 30, 1923: the United States, not a party to the 1923 treaty, announces that its recognition policy in the five republics will be consonant with Article II, quoted in full."),
E("Q6"),
D("frus1923v02","d550","Hughes to the Chargé in Nicaragua, October 8, 1923: the position announced through Honduras restated as the standing policy of the United States toward any government coming to power contrary to Article II."),
D("frus1932v05","d622","Stimson to the Chargé in El Salvador, January 21, 1932: how literally the Department would read Article II's bars on cabinet officers and high military commanders when deciding whom it could recognize."),
D("frus1932v05","d639","Stimson to the Chargé in El Salvador, February 27, 1932: General Martínez's plan to deposit power temporarily in a designate is an evasion of the treaty; the only road to recognition is his outright resignation."),
E("Q8"),
D("frus1934v05","d199","Welles to President Roosevelt, January 8, 1934 (initialled OK FDR): how the United States came to withhold recognition from Martínez under the treaty, and the procedure proposed for recognizing him once El Salvador and Costa Rica had denounced it."),
E("Q28"),
D("frus1936v05","d108","Welles to Duggan, March 26, 1936: the Assistant Secretary's own reasoning in the review that ended the Article II policy."),
D("frus1936v05","d112","Hull to the Minister in Honduras and the other Central American missions, April 30, 1936: the Department's conclusion that it should no longer be guided by Article II in extending or denying recognition, with the memorandum that reached it."),
E("Q9"),
H("3. The de facto test outside Central America: Stimson, 1930"),
P("Why these documents: when revolutions overturned Argentina, Peru and Bolivia in September 1930, the Department applied a different test from the Central American one, and said so publicly. The press release is the clearest statement in the series of the three questions asked of a government that came to power by force: is it in control without active resistance, will it fulfil its international obligations, and will it hold elections in due course."),
D("frus1930v01","d375","Department press release, September 17, 1930: Stimson's statement recognizing the provisional governments of Argentina, Peru and Bolivia, the three tests he applied, and his insistence that this was no new policy but the rule since Jefferson, with the Central American treaty the exception."),
E("Q7"),
H("4. War, hemisphere security and consultation, 1943–1947"),
P("Why these documents: from 1943 the question was no longer only how a government had come to power but whether it was friendly to the Allied cause, and the decision was taken, at least in form, together with the other American republics under Resolution XXII of the Emergency Advisory Committee for Political Defense. These documents show the security test (Bolivia 1943), the demand for simultaneous action (Argentina 1943), consultation as a procedure (Bolivia 1944, Venezuela 1945), nonrecognition as leverage (Argentina 1944), and the exhaustion of the method (Nicaragua 1947)."),
D("frus1943v05","d334","Hull to Ambassador Armour, June 6, 1943: recognition of the Ramírez government to be as nearly simultaneous as possible among the American governments, after full exchange of information, including with those that follow the Estrada doctrine."),
E("Q11"),
D("frus1943v05","d486","Hull's circular of December 22, 1943 carrying his press statement on the new Bolivian regime: hemisphere security and the war effort come first, and whether unfriendly outside influence played a part is a relevant consideration."),
E("Q10"),
D("frus1944v07","d386","Hull's circular of January 6, 1944: the United States accepts the Guani committee's recommendation that the American republics consult and exchange information before recognizing the new government of Bolivia."),
D("frus1944v07","d390","Hull's circular of January 13, 1944: why the Department preferred consultation through diplomatic channels to Mexico's proposal of a joint meeting on Bolivian recognition, several governments having objected on sovereignty grounds to a joint decision."),
D("frus1944v07","d231","Hull to Ambassador Armour, May 18, 1944: the case against recognizing the Farrell regime in Argentina put as a demand for a sincere contribution to the common war effort."),
E("Q23"),
D("frus1945v09","d251","Acheson's circular of April 4, 1945: the steps Argentina had taken under the Mexico City resolutions, and the proposal that the non-recognizing republics recognize simultaneously on April 9 once a consensus was established."),
D("frus1945v09","d1170","Byrnes's circular of October 25, 1945 on the Venezuelan junta: control of the country, general support without active opposition, intention to fulfil international obligations, no pro-Axis inspiration; consultation under Resolution XXII before recognition."),
E("Q12"),
D("frus1946v11","d312","Byrnes's circular of July 26, 1946 on the Bolivian junta: favourable impression from its popular basis, its promise of early elections and its assurance on international obligations; early recognition once stability is assured."),
E("Q25"),
D("frus1947v08","d742","Lovett to the Embassy in Nicaragua, August 21, 1947: the Department will follow the majority of the American republics on recognizing the Somoza-made regime, while conceding that it has every attribute of a stable de facto government."),
E("Q21"),
D("frus1947v08","d755","Lovett's circular of December 31, 1947: Costa Rica and the Dominican Republic have broken the common front of nonrecognition toward Nicaragua; the Department asks the other republics what they intend to do."),
D("frus1948v09","d75","Marshall's circular of January 12, 1948: the summary of the republics' views on Nicaraguan recognition, the case that led directly to the Bogotá resolution."),
H("5. From recognition to continuing relations: PPS/24 and the Bogotá resolution, 1948–1950"),
P("Why these documents: in 1948 the Department decided that recognition should not be used as a political weapon, and the Ninth International Conference at Bogotá resolved (Resolution XXXV) that continuity of diplomatic relations was desirable and that establishing relations implied no judgement on a government's domestic policy. The coups in Peru and Venezuela that autumn, Panama in 1949 and Haiti in 1950 were handled under that rule: a decent interval, a note of acknowledgment, three assurances asked of the new government."),
D("frus1948v09","d74","Extract from the Final Act of the Bogotá conference, March 30–May 2, 1948: Resolution XXXV, Exercise of the Right of Legation, the text the Department applied for the next three decades."),
D("frus1948v09","d89","Daniels to Lovett, November 8, 1948, on resuming relations with Peru's military junta: how the Bogotá resolution separates relations from approval and avoids the word recognition, and how it had already been applied to Nicaragua and Costa Rica."),
E("Q14"),
D("frus1948v09","d109","Lovett's circular of December 3, 1948: the Department's account of the Venezuelan coup for the other republics, and its decision to defer a decision on resuming relations."),
D("frus1948v09","d114","Lovett's memorandum of his conversation with Venezuelan Ambassador Carnevali, December 7, 1948: the ousted government's case against continuing relations with the junta, and the three factors Lovett read into Resolution XXXV."),
D("frus1948v09","d115","Kennan's Policy Planning Staff paper PPS 47, December 10, 1948, on recognizing the Venezuelan junta: recognition should imply neither approval nor disapproval and should not be withheld as a political weapon, but the United States should say that force as an instrument of political change is deplorable."),
E("Q13"),
D("frus1948v09","d119","Lovett's circular of December 16, 1948: nonrecognition is not a suitable approach to the broader problem of dictatorships and the use of force; the republics are asked what the inter-American organization might do instead; the passage on international obligations and elections drafted for the Venezuelan note."),
D("frus1949v02","d448","Miller to Acheson, December 8, 1949, on Panama: the three questions the consultation asked (outside intervention, popular support and civil liberties, international commitments) and the timing of resumed relations in the middle of the procession."),
E("Q26"),
D("frus1950v02","d477","Miller to Acheson, May 31, 1950: President Truman wishes to be consulted on recognizing Latin American regimes that take power by force; the Haitian junta's record against the standing tests."),
D("frus1950v02","d478","Acheson to the Ambassador in Haiti, June 1, 1950: the note resuming relations, reciting the junta's three assurances, and the press announcement that the action followed an exchange of views with the other republics."),
E("Q15"),
H("6. Kennedy's conditions and the drift toward Estrada, 1960–1980"),
P("Why these documents: after 1960 the question was asked again, first in the Cold War form (El Salvador 1960) and then, under Kennedy, as a deliberate return to withholding recognition from military governments until they bound themselves to elections (Peru 1962, Dominican Republic and Honduras 1963). From 1965 the Rio resolution made consultation the rule and from 1968 the Department debated moving toward the Mexican Estrada doctrine of recognizing states rather than governments; by 1973 and 1978 that was the stated practice."),
D("frus1958-60v05mSupp","es_d29","Herter to the Embassy in El Salvador, November 2, 1960: recognition suspended while the Department sought elements able to prevent a Castro-Communist takeover and guide a transition to a constitutional regime oriented toward the West."),
D("frus1958-60v05mSupp","es_d43","Acting Secretary to the Embassy in El Salvador, December 1, 1960: the note of recognition, resting on the junta's assurances about the 1950 constitution, treaties, obligations, human rights and free elections."),
E("Q22"),
D("frus1961-63v12","d421","Ball to President Kennedy, July 27, 1962, on Peru: what to ask of the junta before resuming relations, the Venezuelan proposal to condemn the coup at the OAS, and the effect the suspension had already had on the junta's election promises."),
E("Q24"),
D("frus1961-63v12","d422","Department to the Embassy in Peru, July 28, 1962: Haya de la Torre's memorandum praising Kennedy's firmness and proposing what could be demanded of the junta as the price of recognition."),
D("frus1961-63v12","d359","Department to the Embassy in the Dominican Republic, October 4, 1963: the objectives after the Bosch coup and the seven points the triumvirate must agree to before recognition or resumed aid, including OAS-supervised elections within a year."),
E("Q16"),
D("frus1961-63v12","d360","Department to the Embassy in the Dominican Republic, October 13, 1963: no collaboration or normal relations with the de facto government under existing conditions; the triumvirate's election timetable judged inadequate."),
D("frus1961-63v10-12mSupp","d160","Circular to the Central American posts, October 4, 1963: recognition of the Honduran government tied to the earliest restoration of constitutional government, with a step-by-step constitutional procedure and election calendar proposed."),
D("frus1961-63v10-12mSupp","d165","Embassy Tegucigalpa, October 30, 1963: the military regime's position, the effect of the aid cut-off, and the Embassy's recommendations on the terms for recognition."),
D("frus1961-63v10-12mSupp","d166","Department to Tegucigalpa, October 31, 1963: the Embassy's recommendations accepted as minimal objectives; a six-to-nine-month timetable for a civilian constitutional government called reasonable; no commitment on recognition."),
D("frus1964-68v31","d128","Gordon to the Ambassador in Argentina, June 7, 1966: the attempt to deter the coup against Illia by warning its planners that the United States could not easily cooperate with a de facto government."),
D("frus1964-68v31","d132","Department to the Embassy in Argentina, June 28, 1966: relations suspended after the coup in keeping with international practice; consultation with the other OAS members under Resolution XXVI of the 1965 Rio conference, whose criteria the editors summarize in a note."),
E("Q17"),
D("frus1964-68v31","d512","Assistant Secretary Oliver to the Ambassador in Peru, October 6, 1968: a proposal to move United States recognition doctrine toward a variant of the Estrada doctrine without losing the positive elements of the Rio resolution."),
E("Q18"),
D("frus1969-76v21","d349","Kissinger to Nixon, September 12, 1973: the public line after the Chilean coup, that recognition had not arisen because the United States recognizes countries rather than governments, and the decision to let Latin American governments announce continued relations first."),
E("Q19"),
D("frus1969-76v21","d355","Kissinger to Nixon, September 14, 1973: Pinochet's message through the military group, including what the junta intended on debt, copper obligations and Marxist parties, and his view that the United States should not be first to continue relations."),
D("frus1977-80v24","d134","Department to the Embassy in Bolivia, July 27, 1978: Pereda to be pressed to shorten his election timetable, with assistance conditioned on the steps he takes, while told that recognition will not arise because the practice is to continue relations after a decent interval."),
D("frus1977-80v24","d137","Department to the Embassy in Bolivia, August 3, 1978: the note continuing relations and the press guidance that continuation implies neither approval nor disapproval and that recognition need not be addressed."),
E("Q20"),
D("frus1977-80v24","d158","Department circular of July 24, 1980, after the García Meza coup: the intelligence assessment of the coup and the measures taken instead of a recognition decision, withdrawal of the military group and termination of the aid pipeline."),
P("Threads this run could not follow. The 1950s are almost absent from the chapters the editors titled for recognition: the Cuban coup of 1952, the Bolivian revolution of 1952, Guatemala in 1954 and Argentina in 1955 appear only inside general country chapters, and the index hits there were not read in this session. The Brazilian coup of 1964 and the Argentine coup of 1976 were not read for the same reason. The text of the Estrada doctrine, of Resolution XXII of the Emergency Advisory Committee and of Resolution XXVI of the 1965 Rio conference is cited by the editors but not printed; the Policy Planning Staff paper of March 15, 1948 is printed earlier in the 1948 volume and was not read. Nineteenth-century practice before 1895, where the index shows the phrase in use, was outside the chosen scope."),
{"kind":"generated","generatedBlockType":"archivalSources"},
]
# validate: pairs exist, no duplicate document pairs, no Ed2
pairs=[(e["volumeId"],e["documentId"]) for e in entries if e["kind"]=="document"]
assert len(pairs)==len(set(pairs)), "duplicate document pair"
for e in entries:
    if e["kind"] in ("document","excerpt"):
        assert "volumeId" in e and "documentId" in e
        assert not e["volumeId"].endswith("Ed2")
        n=db.execute("SELECT COUNT(*) FROM document_cache WHERE volume_id=? AND document_id=?",(e["volumeId"],e["documentId"])).fetchone()[0]
        assert n==1,(e["volumeId"],e["documentId"])
    if e["kind"]=="excerpt":
        pos=db.execute("SELECT instr(body_text,?) FROM document_cache WHERE volume_id=? AND document_id=?",(e["text"],e["volumeId"],e["documentId"])).fetchone()[0]
        assert pos>0,(e["volumeId"],e["documentId"])
coll={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
"name":"Recognizing governments that came to power by force in Latin America",
"authorLine":"Agent run r8, 2026-10-25",
"introductionText":("What FRUS answers directly: the series prints, in the editors' own chapters on recognition and revolution, the tests the United States applied to Latin American governments that took power by force from 1895 to 1980, and the demands it made before recognizing them: Wilson's insistence on a constitutionally elected government and on an election in which the usurper did not stand (1913–1921); the Central American rule of Article II of the 1923 treaty, applied until 1936; Stimson's three questions of 1930, control without active resistance, fulfilment of international obligations and elections in due course; wartime consultation and the test of friendliness to the Allied cause (1943–1947); the Bogotá rule of 1948 that continuing relations implies no approval, with three assurances asked of each junta; Kennedy's return to conditions in 1962–1963; and the drift after 1965 toward recognizing countries rather than governments. "
"Where FRUS points for the rest: the documents came overwhelmingly from the Department of State's Central Decimal File, 1910–1949 (Record Group 59; the internal-affairs classes of each country), and after 1963 from the Central Files 1964–1969, the Kennedy, Johnson and Carter national security files, and Nixon's NSC files; the footnotes cite without printing the Department's lot files for Central America (lot 63D127, lot 64D16), the Secretary's memoranda of conversation (lot 65D330), NSC policy papers (lot 66D95) and the Muskie and Vance briefing books (lots 82D100, 84D241), all now Record Group 59 series at College Park, several still restricted. "
"What this request cannot get from FRUS: the 1950s cases (Cuba 1952, Bolivia 1952, Guatemala 1954, Argentina 1955), Brazil 1964 and Argentina 1976 are not printed under recognition headings and were not read here; the texts of the Estrada doctrine and of the inter-American resolutions of 1943 and 1965 are cited but not printed; and the Latin American governments' own reasoning survives only as reported in United States despatches."),
"composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
"entries":entries}
json.dump(coll,open("collection.fruscollection","w"),ensure_ascii=False,indent=1)
print("documents:",len(pairs),"excerpts:",sum(1 for e in entries if e["kind"]=="excerpt"),"entries:",len(entries))
