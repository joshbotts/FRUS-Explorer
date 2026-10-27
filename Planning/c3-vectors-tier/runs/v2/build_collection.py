# Build collection.fruscollection from quotes.json and the findings; every pair checked against document_cache.
import json, sqlite3
A = "Agent run v2, 2026-10-26"
Q = {}
for v, d, q in json.load(open("quotes.json")): Q.setdefault((v, d), []).append(q)
intro = ("What FRUS answers directly: the printed record shows Cuba's stakes moving rather than simply growing — from a disordered neighbor whose wars injured American commerce (1870s–1898), to a guardianship that fused intervention rights, naval stations and Cuban prosperity (1901–1933), to sugar as the hinge of Cuban stability, U.S. exports and wartime supply (1933–1958), to a Soviet base and exporter of revolution (1959–1970), and finally to trade as political leverage and migration as a domestic problem (1977–1980); the set is about seven thousand documents the editors filed under Cuba in 130 volumes, 1849–1980. "
 "Where FRUS points for the rest: the printed documents came from the State Department's Central Decimal File (RG 59, Cuba files 837.00, 837.51, 837.61351 and U.S. trade 611.37) and the nineteenth-century despatch and legation-note microfilm before 1950, and afterward from the presidential libraries' national security files, CIA records and RG 59 lots such as 65D438 (Cuban Missile Crisis), 74D272 (Ball), 66D501 (Operation Mongoose), 62D24 and 62D418 (Inter-American subject files) and 62D1 (Policy Planning NSC records); the footnotes cite without printing chiefly decimal-file numbers, the same library files, lots 66D95 (NSC policy papers), 66D204 (heads-of-state correspondence) and 65D212 (sugar). "
 "What this request cannot get from FRUS: anything after 1980 (no Reagan-era document carries Cuba in its heading), a usable count of 'national security' (before the 1930s it almost never occurs and afterward it is mostly the name of the Council and no commoner in Cuba documents than in the corpus), and the commercial interests' own voice, which FRUS carries only through State Department correspondence.")
F = [
 ("1870s–1898: a neighbor's disorder as a cost to commerce and a menace to peace",
  "Commerce framed by proximity, Cuba as the key to the Gulf, and the 1898 case for intervention from injury to trade and the expense of watchfulness. These are the documents that state the stakes, in date order.",
  [("frus1870", "d197", "Fish's 1870 report on trade with Spanish America: Cuban commerce rests on necessity and proximity despite Spanish legislation."),
   ("frus1881", "d405", "Blaine's 1881 instruction: Cuba as key to the Gulf and part of the American commercial system (reprinted in the 1894 Hawaii appendix)."),
   ("frus1898", "d490", "Sherman to Woodford, July 1897: the war has ruined Cuban commerce, and the President weighs duty to neighbors and to the United States."),
   ("frus1898", "ch83", "McKinley's message of April 11, 1898: intervention justified by injury to trade and property and by the cost of a permanent menace.")]),
 ("1901–1933: security and prosperity fused in a guardianship",
  "The conditions of independence, the naval-station lease and Roosevelt's 1906 warning: order, property, defense and Cuban prosperity as one test.",
  [("frus1902", "d313", "Despatch carrying the Cuban commission's report on Washington's conditions: the right to intervene for a stable government that protects property."),
   ("frus1903", "d331", "The 1903 agreement leasing coaling and naval stations, justified by Cuban independence and U.S. defense."),
   ("frus1906p1", "d427", "Roosevelt to Quesada, September 1906: Cuban peace and prosperity as the condition of Cuban independence; intervention only if order fails.")]),
 ("1933–1958: sugar as the hinge of stability, exports and supply",
  "Welles, the 1941 defense talks and Dulles in 1954: the sugar quota and defense cooperation valued for Cuban stability, U.S. exports and strategic supply.",
  [("frus1933v05", "d281", "Welles to Roosevelt, July 1933: a sugar settlement would steady Cuba and regain an export market."),
   ("frus1941v07", "d119", "1941 conversations on extending Guantánamo: a defense agreement valued for its political effect on Cuba and the hemisphere."),
   ("frus1952-54v04", "d343", "Dulles to Eisenhower, June 1954: cutting Cuba's sugar quota would risk revolution, U.S. exports and Cuba as a strategic sugar reserve.")]),
 ("1959–1970: a Soviet base and an exporter of revolution",
  "From the 1961 task force's 'remote possibility' of a Soviet strategic base, through the missile crisis, to the 1969 'double-barreled problem' and the 1970 Cienfuegos alarm.",
  [("frus1961-63v10", "d202", "May 1961 interagency task force: no direct military threat; the danger is Cuba as base and example for revolution, with a strategic base a remote possibility."),
   ("frus1961-63v11", "d34", "NSC, October 20, 1962: Kennedy separates bombers he can live with from missiles that change the balance."),
   ("frus1969-76ve10", "d205", "NSSM 32, July 1969: Cuba as a Soviet military base and an exporter of revolution; reached through a vector neighbour of the 1961 paper."),
   ("frus1969-76v12", "d211", "Moorer, September 1970: Soviet submarine support at Cienfuegos as the most serious current challenge to U.S. security.")]),
 ("1977–1980: trade as leverage, migration as a domestic problem",
  "Carter-era papers weigh the embargo for its political leverage, and the 1980 boatlift turns Cuba's impact into a domestic coordination problem.",
  [("frus1977-80v23", "d21", "Blumenthal to Carter, August 1977: the embargo's political significance far outweighs its economic effects."),
   ("frus1977-80v23", "d98", "April 1980 memorandum on the Mariel boatlift: controlling the refugee flow as a federal domestic task.")]),
]
E = []
for h, prose, docs in F:
    E.append({"kind": "heading", "text": h, "level": 1}); E.append({"kind": "prose", "text": prose})
    for v, d, note in docs:
        E.append({"kind": "document", "volumeId": v, "documentId": d, "notes": [f"{A}: {note}"]})
        for q in Q.get((v, d), []): E.append({"kind": "excerpt", "volumeId": v, "documentId": d, "text": q})
E.append({"kind": "prose", "text": "Threads not followed in this run: the Reagan-era Cuba documents scattered through the 1981–1988 volumes (none filed under Cuba); the 1875–76 Ten Years' War instructions printed outside the annual volume; the domestic sugar interests' own records; Cuban-side sources; and a document-by-document reading of the 1950s Batista files, whose low Cold War vocabulary is measured but not explained."})
E.append({"kind": "generated", "generatedBlockType": "archivalSources"})
C = {"format": "fruscollection", "formatVersion": 2, "minimumReaderVersion": 1,
     "name": "Cuba, security and prosperity, 1870–1980", "authorLine": A, "introductionText": intro,
     "composition": {"defaultBodyDepth": "full", "footnoteStyle": "all", "includeSourceNote": True, "tocStyle": "citation", "applyHighlights": False, "includeNotes": True, "includeWordCloud": False},
     "entries": E}
json.dump(C, open("collection.fruscollection", "w"), ensure_ascii=False, indent=1)
