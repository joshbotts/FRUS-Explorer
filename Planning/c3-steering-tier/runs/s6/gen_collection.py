import json, re, sys
sys.path.insert(0, ".")
M = json.load(open("meta.json"))
QV = {q["id"]: q for q in json.load(open("quotes_verified.json"))}
DATE = "2026-10-30"
ATT = "Agent run s6, " + DATE + ": "


def raw_passage(k, text):
    v, d = k.split("/")
    raw = open("docs/%s__%s.txt" % (v, d)).read()
    if text in raw:
        return text
    words = [re.escape(w) for w in text.split()]
    m = re.search(r"\s+".join(words), raw)
    assert m, (k, text)
    return m.group(0)


FIND = [
    ("Vietnam: corruption raised with the government for a decade, increasingly because of Washington's own politics",
     "These six documents follow one thread from 1960 to 1970: the Embassy reports corruption inside the Saigon government, raises it with the head of state, and by 1967 and 1970 is pressing it because the Congress and the press are doing so. They were chosen because each shows an American official acting on corruption or explaining why. What they do not show is aid cut for corruption; I did not find that.",
     [
         ("frus1958-60v01/d111", "Durbrow's despatch of March 1960 reports Presidential adviser Wolf Ladejinsky's account of corruption in the Vietnamese government, including a business agent of the Can Lao Party said to receive a company's stock for favours, which Ladejinsky called straight corruption. An early instance of the Embassy putting corruption in its reports.", []),
         ("frus1958-60v01/d160", "Durbrow reads Diem a message that includes corruption in the Can Lao Party; Diem replies that the party's task is to stop it and blames rumours. Corruption is put to a head of state directly, in 1960.", ["Q5"]),
         ("frus1964-68v04/d280", "At Manila, President Johnson asks Ky whether anything can be done about corruption before his critics get there, with Congressional investigations about to begin. Ky calls corruption the worst problem in Vietnam. Shows domestic critics as the reason for pressing.", []),
         ("frus1964-68v05/d197", "Presidential counsel McPherson reports from Saigon: Ky tells him most generals and senior provincial officials are corrupt but that corruption takes time and exists everywhere. The Americans hear a candid admission and an excuse in one breath.", ["Q8"]),
         ("frus1964-68v05/d258", "Minister-Counselor Calhoun agrees with Komer that corruption has become a key obstacle to pacification and discusses Komer's proposal, through the Embassy's interagency committee, to identify suspect officials so American advisers avoid them.", []),
         ("frus1969-76v06/d175", "Bunker tells Thieu corruption is now the number one problem, a problem of Vietnamese-American relations, and ties it to a Congressional inquiry into black-market currency and the prospects for more aid. An editors' note records that Nixon had asked for some quiet work on corruption.", ["Q10"]),
     ]),
    ("China, 1943 to 1948: corruption as the diagnosis of an ally that would not hold",
     "American diplomats put corruption at the centre of their account of the Nationalist government while Washington was deciding how far to back it. The four documents are spread over five years and written by four different hands; the last was reached by asking the semantic index for neighbours, not by searching for words.",
     [
         ("frus1943China/d202", "Davies, proposing an American consulate and observers in Communist territory, describes Kuomintang officials: nepotism, favouritism, graft and bribery. The corruption passage is part of his argument about the regime's durability.", ["Q1"]),
         ("frus1944v06/d269", "Ambassador Gauss reports an alleged plot by young officers to remove high officials they believed corrupt and inefficient, naming Kung and Ho Ying-chin among the targets.", []),
         ("frus1947v07/d591", "Sprouse's memorandum for General Wedemeyer's mission lists widespread corruption and graft among the reasons the National Government lost public confidence.", ["Q3"]),
         ("frus1948v07/d590", "Cabot's letter from Shanghai: American aid wasted, the same old grafters in the same posts. Reached by the semantic neighbours of the Davies memorandum, not by the word search, which missed the form 'grafters'.", ["Q4"]),
     ]),
    ("Tolerated, excused or made a condition: corruption weighed against other interests, 1961 to 1980",
     "The documents that deplore corruption often argue it should not decide policy. Six documents across nineteen years show the argument in Iran, the Philippines, Korea, Saudi Arabia and Haiti. The quoted passages were chosen where an official states how corruption bears on a decision.",
     [
         ("frus1961-63v17/d27", "Policy Planning memorandum on Iran: corruption a long-standing feature of administrations; the Shah himself honest, many around him not; not a major economic factor; and a discussion of whether aid can be used as leverage for reform.", []),
         ("frus1961-63v23/d355", "NSC staff records the State Department view on the Philippine elections: corruption is characteristic of the country's politics and may be no worse than elsewhere, so the United States should stay out. Corruption as a reason for not acting.", ["Q11"]),
         ("frus1961-63v22/d249", "Ambassador Berger cites the Korean junta's campaign against corruption, graft and bribes among his reasons for confidence in it. Corruption as a reason for backing a government.", []),
         ("frus1969-76ve09p2/d122", "The Embassy in Jidda revises its estimate: corruption is increasing and, unchecked, would breed instability after King Faisal. Recommends telling the Saudis the United States will not facilitate corruption. The semantic index places it in no cluster of the map.", ["Q14"]),
         ("frus1977-80v23/d252", "Embassy Haiti: a proposed $125 million aid programme conditioned on fiscal and administrative reform, aimed at institutionalised corruption on which the regime's power is built; the Embassy doubts it will succeed. Corruption as a condition of aid.", ["Q17"]),
         ("frus1977-80v18/d206", "Ambassador West's assessment as of January 1980: corruption is the greatest single threat to the stability of the Saudi ruling family, and he knows of no truly effective means to help correct it. The 21st-nearest neighbour of the 1974 airgram in the semantic index.", []),
     ]),
    ("When the corrupt party was an American firm, corruption became a problem of the diplomacy itself, 1975 to 1980",
     "Nine documents on the Lockheed and related commission scandals and their legal aftermath. They were chosen because in each an official decides how the Government will conduct itself toward a foreign government once an American firm's payments are in question. One document (the Kissinger conversation with Ambassador Togo) was reached through the semantic neighbours of the Saito conversation.",
     [
         ("frus1969-76ve09p2/d152", "Kissinger's staff meeting, 7 August 1975: an official argues fees to arms-sale intermediaries should be disclosed to the buyer and sees nothing good in them; Kissinger replies that this is how business is done in the Middle East and asks who has thought about the impact on Saudi Arabia.", []),
         ("frus1969-76ve09p2/d161", "Ambassador Akins tells Prince Sultan that Lockheed has admitted about $20 million in bribes abroad; Sultan asks that the names never be divulged and says disclosure by Congress would end the special relationship.", ["Q32"]),
         ("frus1969-76ve15p2/d292", "Hartman reports the findings of the Senate subcommittee staff on Lockheed payments in West Germany and judges nothing useful can be done. Cited with the later memorandum; the second-edition twin of this volume is not used.", []),
         ("frus1969-76ve15p2/d293", "Follow-up memorandum; the editors' note records Kissinger telling Ford the matter must be kept quiet because disclosure could shake Germany. The quoted words are in the editors' note quoting a memorandum of conversation.", ["Q19"]),
         ("frus1969-76ve12/d219", "Ford replies to Miki on the Lockheed scandal: offers to share SEC material with Japanese investigators and supports an international agreement on corrupt practices.", []),
         ("frus1969-76ve09p1/d49", "The Department forwards a Libyan diplomatic note requesting complete details of commissions and bribes in the Lockheed C-130 sale, showing the Lockheed disclosures reaching a third government.", []),
         ("frus1969-76ve12/d222", "Kissinger tells Ambassador Togo he has kept himself out of the Lockheed matter, which he says is a judicial and not a foreign-policy matter. Reached through the semantic neighbours of the 14 May 1976 conversation.", []),
         ("frus1969-76ve12/d224", "Ambassador Saito stresses for the Prime Minister the extremely political nature of the Lockheed question in Japan; Kissinger says the Department cannot interfere in a criminal investigation.", []),
         ("frus1977-80v03/d248", "Commerce and the Trade Representative on the cost of the Foreign Corrupt Practices Act to exporters: the loss of some sales is intended, and the answer is a multilateral agreement.", ["Q26"]),
     ]),
    ("Koreagate and the timetable for withdrawing from Korea, 1978",
     "Three documents of April 1978 in which a bribery affair in the Congress becomes a reason for the Executive Branch to change the pace of a troop withdrawal. Nearest in the documents I read to an allegation of corruption altering a decision.",
     [
         ("frus1977-80v13/d92", "Memorandum laying out options: one is to postpone the December 1978 withdrawal on the ground that Congress cannot address Korean policy while the Tongsun Park affair hangs over it.", []),
         ("frus1977-80v13/d94", "Meeting of 11 April 1978: Holbrooke says at least 100 votes in the House have been lost on the compensatory package simply because of Koreagate. The editors define Koreagate in a footnote.", ["Q29"]),
         ("frus1977-80v13/d95", "Brzezinski to Carter: Koreagate has made many Congressmen reluctant to vote for any aid to Seoul this year, so the arms transfers promised with the withdrawal are at risk.", ["Q30"]),
     ]),
    ("The charge as contested ground: Hawaii, 1893",
     "Two statements from the papers on the Hawaiian revolution: one gives corruption as a cause of the revolution, the other denies that the revolutionists found any. They show the allegation as evidence in what the United States collected, not that it decided the American position.",
     [
         ("frus1894app2/d255", "Blount to Gresham, transmitting the interview with Mr. Waterhouse, who gives the lottery and opium bills and bribery and corruption as the cause of the revolution.", ["Q27"]),
         ("frus1894app2/d306", "A statement hostile to the revolutionists: they justified seizing power by the need to correct abuses, yet no fraud or malfeasance was found.", ["Q28"]),
     ]),
]

CLOSING = ("Threads I could not follow in this pass: (1) the Ottoman bribery cases in which missionaries' assailants were allegedly protected by bribed judges (1893 and 1894, Mosul) and what the Legation did; (2) Watergate and the other corruption of American officials, 183 documents mention Watergate; (3) the Soviet corruption assessments of 1982 (the Clark memoranda on Andropov's anti-corruption campaign); (4) the coups explained by corruption, such as Morocco in 1971 and Liberia in 1980; (5) Dominican, Colombian and Philippine cases in the 1960s and 1970s, read only in passages; (6) whether aid was ever actually withheld for corruption, which needs the policy documents that follow each of the exchanges above; (7) the earlier decades before 1860, where the library holds only 483 dated documents; and (8) the 1990s, where it holds 177. The archival sources block below is computed by the app from the documents in this collection.")

INTRO = ("What FRUS answers directly: across the 553 volumes indexed (two second editions set aside), about 1 document in 100 uses the vocabulary of corruption (3,174 of 311,429) and about 1 in 650 does so three or more times (479); the 30 documents here show that officials repeatedly weighed an ally's corruption against a strategic interest and the strategic interest usually won, and that corruption moved policy most visibly when the corrupt party was American (Lockheed, 1975 to 1976) or when allegations reached the Congress (Koreagate, 1978). "
         "Where FRUS points for the rest: the printed documents came from the State Department's central files in Record Group 59, the Records of Henry Kissinger (Lot 91D414, NARA identifier 2131131), the Kissinger staff-meeting transcripts (Lot 78D443, 619160), the Jidda Embassy files (Record Group 84, Lot 79F80) and the Johnson, Kennedy, Ford and Carter libraries; the editors' footnotes cite, unprinted, the same libraries' national-security files and State lots 65 D 330, 85 D 240 and 66 D 193. "
         "What this request cannot get from FRUS: proof that an allegation changed a decision, the Senate subcommittee's own evidence on Lockheed, anything before 1860 or after 1989 (searched, with controls, and thin), and the American officials' own corruption, which I did not follow.")

entries = []
used_q = []
for h, prose, docs in FIND:
    entries.append({"kind": "heading", "text": h, "level": 1})
    entries.append({"kind": "prose", "text": prose})
    for k, note, qs in docs:
        v, d = k.split("/")
        entries.append({"kind": "document", "volumeId": v, "documentId": d, "notes": [ATT + note]})
        for q in qs:
            entries.append({"kind": "excerpt", "volumeId": v, "documentId": d,
                            "text": raw_passage(k, QV[q]["text"])})
            used_q.append(q)
entries.append({"kind": "heading", "text": "Threads not followed", "level": 1})
entries.append({"kind": "prose", "text": CLOSING})
entries.append({"kind": "generated", "generatedBlockType": "archivalSources"})

col = {
    "format": "fruscollection",
    "formatVersion": 2,
    "minimumReaderVersion": 1,
    "name": "Corruption and U.S. diplomacy (agent run s6)",
    "authorLine": "Agent run s6, " + DATE,
    "introductionText": INTRO,
    "composition": {
        "defaultBodyDepth": "full",
        "footnoteStyle": "all",
        "includeSourceNote": True,
        "tocStyle": "citation",
        "applyHighlights": False,
        "includeNotes": True,
        "includeWordCloud": False,
    },
    "entries": entries,
}
json.dump(col, open("collection.fruscollection", "w"), indent=2, ensure_ascii=False)
print("entries", len(entries), "documents", sum(1 for e in entries if e["kind"] == "document"),
      "excerpts", len(used_q), sorted(used_q))
