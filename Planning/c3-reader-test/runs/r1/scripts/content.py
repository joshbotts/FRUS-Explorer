# Shared content for the overview and the collection: citation metadata, verified quotations, and the collection's notes and prose.
import csv, re
RUN = "/Users/jbotts/frus-analysis/c3/runs/r1"
DATE = "2026-10-25"
URLBASE = "https://history.state.gov/historicaldocuments/"

def load_meta():
    m = {}
    for r in csv.DictReader(open(RUN + "/work/cite_meta.tsv"), delimiter="\t"):
        r["key"] = r["volume_id"] + "/" + r["document_id"]
        m[r["key"]] = r
    return m

def load_quotes():
    q = {}
    for r in csv.DictReader(open(RUN + "/work/quotes.tsv"), delimiter="\t"):
        r["key"] = r["volume_id"] + "/" + r["document_id"]
        q[r["qid"]] = r
    return q

META = load_meta()
QUOTES = load_quotes()

def url(key):
    v, d = key.split("/")
    return URLBASE + v + "/" + d

def full_cite(key):
    r = META[key]
    return "%s, Document %s, %s" % (r["short_title"], r["document_number"], url(key))

def short_cite(key):
    r = META[key]
    t = r["short_title"]
    t = re.sub(r"^(Papers Relating to the Foreign Relations of the United States|Foreign Relations of the United States), ", "", t)
    return "FRUS %s, Document %s" % (t, r["document_number"])

class Citer:
    def __init__(self):
        self.used = []
    def c(self, key):
        """first mention: full printed-edition citation with URL; later mentions: short form"""
        if key not in META:
            raise KeyError(key)
        if key in self.used:
            return short_cite(key)
        self.used.append(key)
        return full_cite(key)

# ---------------------------------------------------------------- the collection's notes: one agent-written note per document
ATTR = "Agent finding, research run of %s:" % DATE
NOTES = {
 "frus1900/d530": "Instruction on the seizure of the executive in Colombia. Recognition is to be deferred until the new executive holds the machinery of state with the assent of the people and can meet the state's obligations; meanwhile agents may demand protection of American life and property.",
 "frus1930v01/d375": "Stimson's statement recognizing the provisional governments of Argentina, Bolivia and Peru: de facto control, no active resistance, an intention to meet obligations and to hold elections in due course. He calls this the regular policy since Jefferson and sets out the treaty exceptions for Central America, Cuba and Haiti.",
 "frus1937v05/d265": "Cable to Bolivia asking whether the new government meets the Department's recognition criteria and putting four questions: stability and order, public support or opposition, the attitude of other countries, and the steps the regime means to take to secure recognition.",
 "frus1948v09/d7": "Policy Planning Staff paper approved by the Secretary: recognition should rest on control, the ability and willingness to meet international obligations, and the general acquiescence of the people; it implies no approval of domestic policy and should not be withheld as a political weapon except in extreme cases.",
 "frus1949v02/d489": "Truman explains to the ousted president of Venezuela why the United States resumed relations with the junta: the practice runs back to Jefferson, recognition passes no judgment on internal arrangements, and nonrecognition is seldom effective.",
 "frus1913/d7": "Wilson's statement of 11 March 1913 as telegraphed to the missions in Latin America: just government rests on the consent of the governed, and the United States has no sympathy with those who seize power to advance personal ambition. Found by phrase search; it sits outside the Latin American sections used to define the scope.",
 "frus1913/d1028": "Wilson's address to Congress embodying the Lind instructions for Mexico: a settlement conditioned on an armistice, an early free election, Huerta's agreement not to stand and all parties' acceptance of the result, with a pledge to recognize the administration so chosen.",
 "frus1919v01/d867": "The Secretary of State tells the President that the United States has recognized in Costa Rica neither a de jure nor even a legitimately de facto government, and that only the people can set up a constitutional one; Costa Rica's declaration of war is therefore treated as legally non-existent.",
 "frus1921v01/d238": "After Bolivia's constitutional convention and election the United States will recognize the government not as the de facto one but as the constitutional one, having postponed recognition with Argentina and Brazil until it was shown to represent the people and to rest on the constitution.",
 "frus1925v02/d498": "Kellogg on Nicaragua: a successor chosen by constitutional means would be recognized, a government that came to power by violence or unconstitutional means would not; the policy follows the Central American General Treaty of Peace and Amity of 1923.",
 "frus1931v02/d232": "Stimson's instruction to four missions: General Martínez is barred from recognition by Article 2 of the 1923 treaty, both because he took power by revolution and because he had been Minister of War within six months; the Central American governments are asked to act in step.",
 "frus1934v05/d255": "Welles to Roosevelt: Costa Rica and El Salvador have denounced the 1923 treaty and Guatemala, Nicaragua and Honduras have recognized Martínez, so the United States should now recognize him. Approved the next day.",
 "frus1936v05/d109": "Memorandum on the Department's decision no longer to be guided by Article II of the 1923 treaty: an effective regime that fulfilled its obligations would be recognized whatever its eligibility under the treaty. The worry is how to announce it without seeming to invite a coup in Nicaragua.",
 "frus1877/d222": "Instruction to the minister in Mexico: recognition of Díaz waits until the United States is assured that the Mexican people approve his election and that his government is stable and willing to observe treaties; some guarantee of an arrangement on frontier raids and the other complaints should be made the condition precedent to recognition.",
 "frus1878/d344": "The President authorizes recognition of Díaz: peace and authority throughout the republic, firmer measures against border raids and payment of claims instalments; Mexico argues that non-recognition hinders a settlement, and the President waives his preference.",
 "frus1914/d567": "Instruction on Haiti: recognition will be granted when there is a government able to keep order and meet its obligations, resting on the consent of the governed; the United States wants information on the fiscal standing and plans of the government and its attitude toward foreigners.",
 "frus1915/d448": "Instruction to recognize the Haitian president-elect once Congress authorizes a treaty, and at the same time to sign that treaty, which sets up a financial adviser and receivership, a constabulary organized by Americans, and a United States right to intervene.",
 "frus1921v02/d344": "Hughes's public statement on Mexico: the question of recognition is subordinate; it will follow concurrently with a government's readiness to bind itself to primary international obligations in the proposed treaty protecting property rights.",
 "frus1932v05/d518": "Stimson on Chile's socialist regime: not disposed to recognize yet; recognition is not tied to the type of government, but there is a two-fold criterion on the protection of foreigners; the Department asks for assurances on deposits, debt, trade, taxes and American enterprises.",
 "frus1932v05/d560": "Stimson insists the Department is not bargaining over recognition, yet asks for some assurance of respect for international obligations and for an estimate of stability and popular acquiescence.",
 "frus1932v05/d561": "Culbertson reports the exchange of letters in which Chile's foreign minister undertakes to respect international obligations and foreigners' interests; he made it clear to the Chileans that the exchange implies no recognition and is no bargain for it.",
 "frus1932v05/d567": "Culbertson presents the note of recognition to the Chilean foreign minister on 21 October 1932.",
 "frus1934v05/d85": "Quoting the President: the United States will recognize a Cuban provisional government substantially supported by the people and able to maintain law and order, but cannot promise recognition in advance of those conditions.",
 "frus1961-63v10-12mSupp/d137": "Summary of the first three weeks of the Peralta regime in Guatemala: the United States recognized it on 17 April 1963 after consulting other governments; it could not obtain a public timetable for elections but received verbal assurances of elections within about two years.",
 "frus1961-63v10-12mSupp/d109": "On Ecuador's junta: it has shown control, restored liberties and given assurances on obligations; the remaining point is a public statement of return to civilian government within about a year, and the United States will not recognize until several Latin American states have done so.",
 "frus1961-63v12/d359": "Instructions to the embassy in the Dominican Republic: seven points to secure before recognition or resumption of aid, including free political activity and elections supervised by the OAS within a year; the United States will not recognize the regime as it stands.",
 "frus1964-68v31/d152": "Harriman to Johnson: recognize Bolivia's military junta, which controls the country, has restored constitutional liberties and repeated its intention to hold elections, and has privately pledged to reduce communist influence and not to restore relations with Cuba or Czechoslovakia.",
 "frus1943v05/d335": "Armour reports that the United States does not wish to bargain with Argentina's new government or to make a break with the Axis a condition of recognition, only to know its foreign policy intentions; the American envoys agree to act together.",
 "frus1944v07/d388": "Hull's circular summarizing the evidence that Bolivia's junta is pro-Nazi and telling foreign ministers that it is unlikely the United States will recognize the regime.",
 "frus1944v07/d403": "All nineteen republics in the consultations on Bolivia have publicly refused recognition to the junta; the Department praises the consultative procedure.",
 "frus1944v07/d432": "Hull's summary of the Warren report on Bolivia: the junta's MNR members have gone, Axis aliens have been expelled and firms expropriated, and the government will probably be elected with or without recognition.",
 "frus1944v07/d437": "Mexico suggests simultaneous recognition of Bolivia on 23 June; the United States is willing if that is the consensus of the American governments.",
 "frus1944v07/d1090": "Recognition of El Salvador's new administration will depend partly on its commitment not to recognize Argentina unilaterally.",
 "frus1945v09/d1170": "On Venezuela's junta: in control, with general support and no active opposition, intending to meet its obligations, and no pro-Axis inspiration; the Department proposes to consult the other republics under a resolution of the Emergency Advisory Committee for Political Defense before recognizing.",
 "frus1948v09/d74": "Extract of the Bogotá Final Act: continuity of diplomatic relations among the American states is desirable, and maintaining relations with a government implies no judgment on its domestic policy.",
 "frus1948v09/d115": "Kennan on recognizing Venezuela's junta: the normal policy is to recognize absent a compelling reason; non-recognition is not a suitable weapon in this case; recognition should come after an interval, with a statement deploring the use of force.",
 "frus1952-54v04/d490": "Telegram of 28 June 1954 from the Ambassador in Guatemala, the day three colonels announced a military junta: when Colonel Diaz raises recognition, the Ambassador answers that Washington will want a reasonable period to see what they do and that one of the criteria for recognition is control of the country's territory, which they lack while Castillo Armas controls a portion of it.",
 "frus1952-54v04/d502": "Memorandum of 9 July 1954 from the Secretary of State to President Eisenhower: the new government, formally established on 2 July, appears to control the entire territory and has sent a formal note saying it is prepared to fulfill Guatemala's international obligations; he proposes a circular telegram to the other American republics, London, Paris and Ottawa asking the republics' views and saying that recognition is under consideration for 13 July, a delay that lets others recognize first or coordinate so that the United States is not conspicuously in the lead or behind. The editors record the President's approval of 10 July and that recognition was extended on 13 July.",
 "frus1955-57v06/d354": "On Haiti's junta: the Department does not want to recognize a new de facto regime every few weeks, asks for reasonable assurance of effective control and respect for obligations, and prefers recognition independent of an election pledge.",
 "frus1958-60v06/d217": "Dulles recommends recognizing Cuba's Provisional Government at once: its note claims control and fulfilment of commitments, and it appears free of communist taint. The editors note that recognition was given at 5 p.m. that day.",
 "frus1958-60v05/d11": "National Security Council policy on Latin America: recognize all governments qualifying under the accepted criteria of international law unless a substantial question arises about communist control; encourage those with a popular base.",
 "frus1961-63v12/d363": "Explains why the United States recognized the Dominican and Honduran regimes: non-recognition had won some gains but further influence was virtually nil and continuing it would undo them; the United States recognized the Dominican government on 14 December 1963.",
 "frus1964-68v31/d132": "On Argentina's coup of June 1966: relations suspended and consultation with OAS members under the Rio resolution of 1965, which asks states to weigh foreign involvement and whether the regime promises elections, respect for obligations and human rights.",
 "frus1964-68v31/d518": "Rostow to Johnson on Peru's military government: in full control, tested by the traditional criteria, consulted with OAS members, assuring respect for obligations and a referendum on a constitution; the oil-company expropriation is to be kept separate from recognition.",
 "frus1969-76v21/d361": "Minutes of the Washington Special Actions Group: Chile's junta has satisfied the requirements, and recognition will be announced on 24 September 1973, timed around a Senate vote.",
}
# ---------------------------------------------------------------- the collection's structure
FINDINGS = {
 1: ("1. The stated test: control, consent and the ability to meet obligations",
     "These five documents show the test as the Department wrote it down in 1900, 1930, 1937, 1948 and 1949: does the new government hold the machinery of government, does the population accept it, can and will it meet the state's obligations. The excerpts are the 1900 rule, the three factors of the 1948 staff paper, its warning against using recognition as a weapon, and Truman's judgment on non-recognition."),
 2: ("2. When the test was tightened: constitutional legitimacy and the Central American treaty",
     "Under Wilson and again in Central America the Department asked for more than control. These documents follow the demand for constitutional legitimacy (1913, Mexico, Costa Rica, Bolivia) and the treaty rule that barred recognition of governments that took power by coup or revolution, from Nicaragua in 1925 through the refusal to recognize Martinez in 1931 to the decision of 1936 to drop it."),
 3: ("3. What was asked in return, first part: assurances, and in two cases a treaty",
     "From Diaz in 1877 to Chile in 1932 the Department asked new governments for assurances about treaties, foreigners and property before it recognized them, and in Haiti in 1915 and Mexico in 1921 it tied recognition to a treaty. Where the Department said it was not bargaining, the note says so."),
 4: ("4. What was asked in return, second part: popular support, elections, a date for civilian rule",
     "From Cuba in 1934 to the Dominican Republic, Ecuador and Guatemala in 1963 and Bolivia in 1964 the Department asked for evidence of popular support, a promise or timetable for elections, and sometimes a pledge against communism."),
 5: ("5. From 1943, the other American republics were asked first",
     "These documents show recognition decided by consultation: Argentina and Bolivia in 1943-44, El Salvador in 1944, Venezuela in 1945, the Bogota resolution of 1948 and the Policy Planning Staff's advice on Venezuela that year."),
 6: ("6. After 1948: recognition as the default, withholding as a short lever",
     "From Guatemala in 1954 and the Haitian junta of 1957 to Chile in 1973, the printed record shows recognition as the normal course, a checklist of traditional tests, consultation under the Rio resolution of 1965, and non-recognition used for weeks or months rather than years."),
}
EXCERPT_AFTER = {  # which verified quotations are attached to which document
 "frus1900/d530": ["Q01"], "frus1948v09/d7": ["Q02", "Q03"], "frus1949v02/d489": ["Q05"],
 "frus1913/d7": ["Q06"], "frus1931v02/d232": ["Q07"], "frus1936v05/d109": ["Q08"],
 "frus1877/d222": ["Q09"], "frus1921v02/d344": ["Q20"], "frus1932v05/d518": ["Q10"], "frus1934v05/d85": ["Q19"], "frus1961-63v12/d359": ["Q11"],
 "frus1944v07/d388": ["Q12"], "frus1944v07/d1090": ["Q13"], "frus1948v09/d115": ["Q14"],
 "frus1955-57v06/d354": ["Q15", "Q16"], "frus1964-68v31/d518": ["Q17"], "frus1969-76v21/d361": ["Q18"],
}
