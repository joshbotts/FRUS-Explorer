# Build collection.fruscollection from out/collection_check.json (verified pairs, finding order), quotes/quotes_verified.json
# (excerpts, all exact substrings of body_text) and the per-document notes below. Validates the file after writing.
import json, csv, sqlite3
RUN = "Agent note, recognition run, 2026-10-25"
rows = json.load(open("out/collection_check.json"))
OV = open("overview.md").read()
import re as _re
_frag = _re.findall(r'"([^"]+)"', OV)
# v2: excerpts only for quotations the overview relies on (a verified quotation containing an overview-quoted fragment)
quotes = [q for q in json.load(open("quotes/quotes_verified.json")) if q["raw_substring"] and any(f.strip() in q["text"] and len(f.strip()) >= 25 or f.strip() == q["text"] for f in _frag)]
HEAD = {
 "F1": ("1. Before 1913, recognition followed control, but Washington could name a price first",
        "These instructions state the de facto test in the Department's own words (control of the capital and machinery of state, popular assent, the will to meet treaty obligations) and show it being made conditional, as with Díaz in 1877 and the pledges asked of Estrada in Nicaragua. They follow the test from the 1870s to 1911."),
 "F2": ("2. From 1913 to 1920, Wilson added a test of origin",
        "These documents trace how the Wilson administration added a requirement about how a government came to power: from the Taft Department's 'usual tests' in February 1913, through Wilson's declaration and his terms for Huerta, to the refusal to recognize Tinoco unless a successor was elected constitutionally, and the Peruvian recognitions of 1914 and 1919 that show the test applied selectively."),
 "F3": ("3. What Washington asked: treaties, customs, property and elections",
        "The most explicit lists of conditions precedent to recognition: Haiti's five undertakings and election plan in 1914, the Haitian refusal, the treaty asked of Obregón's Mexico in 1921, and Mexico's own account in 1923 of the points the Department had named."),
 "F4": ("4. From 1923 to 1936, two rules at once: a treaty rule for Central America, the old test elsewhere",
        "These documents set the Central American treaty rule (Article II of 1923) beside Stimson's 1930 de facto recognitions in South America, show the rule applied to Guatemala and El Salvador and a popular-support test argued for Cuba, and end with the 1936 decision to stop following the treaty."),
 "F5": ("5. From 1943 to 1945, recognition by consultation, with a wartime security test",
        "From mid-1943 recognition became a joint inter-American act. These documents run from the Argentine case of June 1943 through Resolution XXII of December 1943 and the Bolivian non-recognition to the consultations on Ecuador (1944) and El Salvador (1945), where the old tests were joined by a test of Axis influence."),
 "F6": ("6. After 1948, relations without approval, and conditions pressed through aid and delay",
        "From the 1948 Policy Planning Staff paper and the Bogotá resolution on continuity of relations, recognition was meant to imply no approval. These documents show that rule applied (Peru 1948, Haiti 1957, Cuba 1959), Kennedy-era non-recognition used as leverage (Peru 1962, Honduras and the Dominican Republic 1963), the question avoided (Brazil 1964), and later asks reduced to statements (Argentina 1966, Chile 1973, Bolivia 1978)."),
}
NOTES = {
 "frus1877/d222": "The Department withholds recognition of Díaz after the revolution of 1876 until his election is approved and his government shows stability and the will to keep treaties, and asks for a frontier arrangement as a condition precedent.",
 "frus1892/d517": "The minister in Caracas reports recognizing Crespo's de facto government once Crespo, in unopposed control, gave assurances of his ability and disposition to fulfill international obligations; he also asked about a constitutional election.",
 "frus1899/d792": "Hay's one-line statement of the de facto test for Venezuela: complete control of affairs by a government able to meet international obligations.",
 "frus1900/d530": "The fullest statement of the de facto rule: recognition deferred until the new executive holds the machinery of state with the people's assent, without substantial resistance, and can fulfill international obligations.",
 "frus1911/d933": "Instruction to the new minister in Nicaragua explaining that Estrada's government was recognized on the strength of pledges (the Dawson agreements) to restore constitutional guarantees and rehabilitate the finances.",
 "frus1913/d894": "Days after Huerta took power, the Taft Department keeps only de facto relations and weighs 'the usual tests': popular acquiescence and the ability to protect foreigners and meet obligations.",
 "frus1913/d7": "Wilson's declaration of March 1913 on Latin America: cooperation only with governments resting on law, not on arbitrary or irregular force. It never uses the word recognition.",
 "frus1913/d1028": "Wilson's address of August 1913 with his terms for Mexico: armistice, a free election, Huerta not a candidate, all parties to abide by the result; the United States pledges to recognize the government so chosen.",
 "frus1914/d1812": "Bryan instructs the minister in Lima to recognize Colonel Benavides's government as the provisional government of Peru, simultaneously with Argentina, Brazil and Chile: a coup-born government recognized under Wilson.",
 "frus1919v02/d720": "Lansing instructs the minister in Lima to recognize Leguía, who had overthrown President Pardo, as head of the de facto government of Peru.",
 "frus1914-20v02/d384": "Lansing reports to Wilson on the 1915 Pan-American conferences on Mexico: the aim is to recognize a government that would restore peace, secure individual rights and perform its international obligations.",
 "frus1917/d378": "Circular after Tinoco's coup in Costa Rica: the United States will give no recognition or support to any government unless it is elected by legal and constitutional means.",
 "frus1914-20v02/d348": "Lansing to Wilson: he told the deposed Costa Rican president that the United States would not recognize Tinoco or any government growing out of the revolution.",
 "frus1914/d540": "The Department's plan for Haiti: a provisional president who would not be a candidate, elections watched by American observers, then recognition of the elected government as constitutional.",
 "frus1914/d544": "Conditions precedent to recognizing Théodore as provisional president of Haiti: a commission to negotiate a customs convention, the railroad and bank disputes, protection of foreign interests, and no lease of Haitian territory to a European power.",
 "frus1914/d568": "The Haitian government tells the American minister it cannot send a commission empowered to negotiate customs control, and offers a counter-project instead.",
 "frus1921v02/d344": "Hughes's public statement of June 1921: recognition of Obregón's government is to come with a treaty of amity and commerce protecting property rights acquired before the 1917 Constitution.",
 "frus1923v02/d472": "Mexico's foreign minister welcomes the end of the treaty as a condition precedent to recognition, calls it prejudicial to Mexican sovereignty, and lists the five points the Department had named as obstacles.",
 "frus1923v02/d345": "Hughes announces that Washington's recognition of new Central American governments will follow Article II of the 1923 treaty, quoting its ban on coup governments and on coup leaders and their relatives.",
 "frus1930v01/d375": "Stimson's statement recognizing the provisional governments of Argentina, Peru and Bolivia: de facto control, no active resistance, intention to meet obligations and to hold elections; the Central American treaty described as a separate rule.",
 "frus1931v02/d412": "Stimson tells the Central American missions that, having opposed Orellana, the Department is ready to recognize Reina Andrade as constitutional provisional president once elections are called, in step with the treaty's signatories.",
 "frus1932v05/d618": "Stimson to the chargé in El Salvador: under the 1923 treaty Martínez can under no circumstances be recognized; the Department's only interest is a first designate eligible for recognition.",
 "frus1933v05/d430": "Welles argues from Havana that recognizing the Grau San Martín government without popular support would postpone stability, and recommends waiting for a government with general confidence.",
 "frus1934v05/d199": "Welles proposes to Roosevelt a procedure for recognizing Martínez once El Salvador and Costa Rica have denounced the 1923 treaty, noting his efficient government and public support.",
 "frus1936v05/d112": "Hull's instruction of April 1936: the United States will no longer be guided by Article II of the 1923 treaty in granting or withholding recognition in Central America.",
 "frus1943v05/d335": "The ambassador in Buenos Aires tells the American republics' envoys that Washington will not make a break with the Axis a condition precedent to recognizing the Ramírez government.",
 "frus1943v05/d33": "Resolution XXII of the Emergency Advisory Committee for Political Defense (24 December 1943): no recognition of a government instituted by force before the American governments consult.",
 "frus1943v05/d142": "Hull withholds recognition from the new Bolivian government and orders export controls pending joint inter-American consideration of recognition.",
 "frus1944v07/d1018": "Circular on Ecuador, June 1944: control, no active resistance and intent to meet obligations established, plus no pro-Axis inspiration 'from the security angle'; consultation under Resolution XXII proposed.",
 "frus1944v07/d437": "Hull agrees to recognize the Bolivian regime on 23 June 1944 if that is the consensus of the American governments, reporting their replies.",
 "frus1945v09/d880": "Result of the consultation on El Salvador's Aguirre regime: fourteen of sixteen replies favour recognition on the three grounds of control, general support and obligations, with no Axis influence found.",
 "frus1948v09/d7": "Policy Planning Staff paper of March 1948 on recognition policy: three factors (control, obligations, acquiescence), recognition to imply neither approval nor disapproval, not to be withheld as a political weapon except in extreme cases.",
 "frus1948v09/d89": "Resumption of relations with Peru's military junta in November 1948 under the Bogotá resolution on continuity of relations, which avoids the formal term recognition.",
 "frus1955-57v06/d353": "On Haiti in 1957: the two classical criteria (de facto control, willingness to abide by international agreements) should govern; making elections a condition would be intervention.",
 "frus1958-60v06/d217": "Dulles asks Eisenhower to recognize Cuba's provisional government without delay, citing its assurances of control and of honoring Cuba's commitments.",
 "frus1961-63v12/d421": "Ball to Kennedy after the Peruvian coup of July 1962: the steps to ask of the junta before resuming relations (earlier elections, a public pledge of free elections, no help to Communists, if possible a civilian cabinet).",
 "frus1961-63v12/d363": "Explaining the December 1963 recognitions of the Honduran and Dominican regimes: withholding recognition aimed at an early return to constitutional government, but further non-recognition would gain nothing.",
 "frus1964-68v31/d206": "National Security Council meeting of 2 April 1964 on Brazil: no recognition problem, because Washington would merely continue relations with the constitutional successor.",
 "frus1964-68v31/d141": "Rusk to Johnson on recognizing Onganía's government in 1966: consultation under Resolution XXVI, informal requests for public statements on its points and on peaceful settlement, and no statement on elections.",
 "frus1969-76v21/d355": "Kissinger to Nixon, 14 September 1973: Pinochet's message on the junta's intentions (breaking with Cuba and the USSR, honoring the copper debt) and his view that the United States should not be the first to continue relations.",
 "frus1977-80v24/d133": "The ambassador in La Paz tells the Pereda government's representative that Washington must know its plans for democratization and human rights before defining its position.",
}
INTRO = ("What FRUS answers directly: for most of the record the test was whether a new government controlled the country, had the people's acquiescence and would meet its international obligations (stated in 1900 and again in 1948). "
         "The series records three departures: the Wilson administration's demand from 1913, in Mexico and Central America though not in Peru, that governments set up by force be constitutionally elected, the Central American treaty rule of 1923–1936, and wartime recognition by inter-American consultation from December 1943. "
         "Before recognizing, Washington asked for concrete undertakings: frontier guarantees from Díaz (1877), Huerta's withdrawal from the election (1913), a customs convention and four more undertakings from Haiti (1914), a property-protecting treaty from Mexico (1921), proof of no Axis inspiration (1944–1945), and from 1962 election dates and civil liberties. "
         "The set is about 2,300 documents in 137 of the 553 volumes in this copy of the index (the whole series as the app lists it), about 1,200 of them in the editors' 51 recognition chapters (1895–1950). "
         "Where FRUS points for the rest: the printed documents came overwhelmingly from the State Department's Central Decimal File (Record Group 59), chiefly each country's political-affairs and government files, then from the Subject-Numeric File (1963–1973), the Central Foreign Policy File, Department lot files and presidential libraries. The editors' unprinted citations point back to the same country files, to two Bureau of Inter-American Affairs lot files and to Carter Library papers. "
         "What this request cannot get from FRUS: a full run of post-1950 cases (no editors' recognition headings after 1950), the nineteenth-century files behind the despatches (no source notes before 1906), the Latin American governments' own deliberations, and the 1980s (one candidate document in the two 1981–1988 volumes that concern Latin America). The question's own phrases (came to power, by force, Latin America) are nearly absent from the documents.")
entries = []
cur = None
for r in rows:
    f = r["finding"]
    if f != cur:
        cur = f; t, prose = HEAD[f]
        entries.append({"kind": "heading", "text": t, "level": 1})
        entries.append({"kind": "prose", "text": prose})
    v, d = r["pair"].split("/")
    entries.append({"kind": "document", "volumeId": v, "documentId": d, "notes": [f"{RUN}: {NOTES[r['pair']]}"]})
    for q in quotes:
        if q["pair"] == r["pair"]:
            entries.append({"kind": "excerpt", "volumeId": v, "documentId": d, "text": q["text"]})
entries.append({"kind": "heading", "text": "Threads this run could not follow", "level": 1})
entries.append({"kind": "prose", "text": ("Not followed here, though the scope holds candidates: nineteenth-century cases beyond Mexico and Venezuela (Maximilian's empire in the 1860s, Peru in 1881, Chile in 1891); the 1915 recognition of Carranza's de facto government and the 1920 Mexican revolution; the 1934 recognition of Mendieta in Cuba; Argentina's Farrell government, withheld in 1944 and recognized in 1945; the 1950s cases (Colombia 1953, Guatemala 1954, Argentina 1955); El Salvador's juntas of 1960–1961; the Dominican Republic in 1965; Nicaragua in 1979 and Bolivia in 1980; "
          "the planning, in 1960–1961, of a Cuban provisional government that the United States itself would install and recognize; and recognition of insurgents as belligerents. After 1950 the scope rests on a text search of about half precision, so these later threads need reading before they are counted.")})
entries.append({"kind": "generated", "generatedBlockType": "archivalSources"})
coll = {"format": "fruscollection", "formatVersion": 2, "minimumReaderVersion": 1,
        "name": "Recognizing governments that took power by force in Latin America (FRUS)",
        "authorLine": "Agent run, recognition of governments that took power by force in Latin America, 2026-10-25",
        "introductionText": INTRO,
        "composition": {"defaultBodyDepth": "full", "footnoteStyle": "all", "includeSourceNote": True, "tocStyle": "citation",
                        "applyHighlights": False, "includeNotes": True, "includeWordCloud": False},
        "entries": entries}
json.dump(coll, open("collection.fruscollection", "w"), indent=1, ensure_ascii=False)
# ---- validation ----
c = json.load(open("collection.fruscollection"))
assert c["format"] == "fruscollection" and c["formatVersion"] == 2 and c["minimumReaderVersion"] == 1
assert set(c["composition"]) == {"defaultBodyDepth", "footnoteStyle", "includeSourceNote", "tocStyle", "applyHighlights", "includeNotes", "includeWordCloud"}
docs = [(e["volumeId"], e["documentId"]) for e in c["entries"] if e["kind"] == "document"]
exs = [(e["volumeId"], e["documentId"], e["text"]) for e in c["entries"] if e["kind"] == "excerpt"]
assert all(e.get("volumeId") and e.get("documentId") for e in c["entries"] if e["kind"] in ("document", "excerpt"))
assert len(docs) == len(set(docs)), "duplicate document pair"
assert not any(v.endswith("Ed2") for v, d in docs)
assert all(n.startswith(RUN + ":") for e in c["entries"] if e["kind"] == "document" for n in e["notes"])
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL = "SELECT body_text FROM document_cache WHERE volume_id = ? AND document_id = ?"
open("out/sql_trace.log", "a").write(f"[build_collection.py] {SQL}  -- once per document and excerpt entry\n")
for v, d in docs: assert con.execute(SQL, (v, d)).fetchone() is not None, (v, d)
for v, d, t in exs: assert t in con.execute(SQL, (v, d)).fetchone()[0], (v, d, t[:40])
assert c["entries"][-1] == {"kind": "generated", "generatedBlockType": "archivalSources"}
print("collection written:", len(docs), "documents,", len(exs), "excerpts,", sum(1 for e in c["entries"] if e["kind"] == "heading"), "headings,",
      sum(1 for e in c["entries"] if e["kind"] == "prose"), "prose blocks; all validations passed")
