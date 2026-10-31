import json
R="/Users/jbotts/frus-analysis/c3s/runs/s9"
Q={q:(v,d,t) for q,v,d,t in json.load(open(R+"/quotes.json"))}
A="Agent finding, run s9, 2026-10-30: "
def doc(v,d,note): return {"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]}
def ex(q): v,d,t=Q[q]; return {"kind":"excerpt","volumeId":v,"documentId":d,"text":t}
E=[]
E+= [{"kind":"heading","text":"1. A client's corruption as a reason to limit or condition aid (China, the Philippines, 1943–1950)","level":1},
 {"kind":"prose","text":"These documents follow one argument from diagnosis to decision: officers in China described Nationalist corruption from 1943, the Ambassador proposed in 1947 to meter aid against it, and in November 1948 the Secretary of State listed corrupt officials among the reasons the United States would not undertake all-out aid. The 1950 Philippine instruction shows the same reasoning turned into conditions on further aid."},
 doc("frus1943China","d202","Davies's 1943 memorandum describes graft, bribery and nepotism as structural features of Kuomintang government, the diagnosis later decisions drew on."), ex("Q1"),
 doc("frus1947v07","d292","Stuart proposes aid released stage by stage against evidence of reform and stopped when corruption reasserts itself: corruption as the measure of leverage."), ex("Q3"),
 doc("frus1948v07","d506","The Secretary's November 1948 instruction gives the presence of corrupt officials in high positions as one reason against an all-out aid programme for the National Government."), ex("Q2"),
 doc("frus1950v06","d831","Instruction to the Economic Survey Mission to the Philippines; the editors' note summarises the Mission's call for a cleanup of corrupt tax officials, and the instruction asks what conditions might be attached to further aid. The quoted passage is the editors' summary, not the telegram's own text."), ex("Q4")]
E+= [{"kind":"heading","text":"2. Corruption as an obstacle in South Vietnam, and the limits of leverage (1960–1968)","level":1},
 {"kind":"prose","text":"From Durbrow in 1960 to the Saigon embassy's corruption committee in 1967, U.S. officials treated corruption in the South Vietnamese government as a cause of political weakness and an obstacle to pacification; Calhoun's 1967 memorandum is the clearest statement of why Washington declined the control that a rapid cure would have required."},
 doc("frus1958-60v01","d179","Durbrow's 1960 letter lists Diem's tolerance of corruption in his family and in high circles among the weaknesses of his rule."), ex("Q5"),
 doc("frus1964-68v05","d258","Calhoun accepts that corruption has become a key obstacle to pacification but rejects a U.S. veto over South Vietnamese appointments as an invasion of sovereignty; the editors' note records the committee's 'incident reports' compromise."), ex("Q6"), ex("Q7"),
 doc("frus1964-68v06","d16","DePuy's January 1968 memorandum records that corrupt province chiefs had not been removed and junior officers were restive over corruption in the armed forces."), ex("Q8")]
E+= [{"kind":"heading","text":"3. American corporate bribery abroad as a diplomatic problem (1975–1976)","level":1},
 {"kind":"prose","text":"When the Senate's multinational corporations subcommittee exposed Lockheed's and Northrop's payments, the Department and the White House handled the disclosures as a threat to allied governments: in West Germany and the Netherlands, in Saudi Arabia, and in Japan, where the Prime Minister asked for the names and the embassy watched a former Prime Minister's arrest."},
 doc("frus1969-76ve15p2","d292","Hartman reports the subcommittee staff's findings that Lockheed's payments to Strauss and the CSU paved the way for the Starfighter sale to West Germany."), ex("Q9"),
 doc("frus1969-76ve15p2","d293","The editors' note quotes Kissinger telling Ford on 8 October 1975 that the bribes to Prince Bernhard and Strauss had to be kept quiet to protect the CSU. The quotation is in the editors' note, from another record."), ex("Q10"),
 doc("frus1969-76ve09p2","d155","Atherton warns that full disclosure of Lockheed's payments through Khashoggi to high Saudi officials could damage Saudi-U.S. relations more than the Northrop case."), ex("Q11"),
 doc("frus1969-76ve12","d218","Miki's letter to Ford asks U.S. help in disclosing the names of Japanese officials implicated in the Lockheed payments."),
 doc("frus1969-76ve12","d222","Kissinger tells Ambassador Togo that the Lockheed affair belongs to judicial procedure and is not a foreign policy matter."), ex("Q12"),
 doc("frus1969-76ve12","d224","A special envoy sent at the Diet's insistence thanks the United States for its help and asks for continued release of Lockheed information."), ex("Q19"),
 doc("frus1969-76ve12","d227","The embassy reports Tanaka's arrest and expects it to reduce suspicion that the two governments sought to cover up the scandal."), ex("Q13")]
E+= [{"kind":"heading","text":"4. From scandal to policy: the illicit payments initiative (1976–1978)","level":1},
 {"kind":"prose","text":"The disclosures moved into economic diplomacy: in 1976 officials asked whether to raise bribery at the economic summit, and by 1977–1978 Carter's economic officials counted the U.S. proposal for an international agreement on illicit payments as one of the few North–South issues on which Washington held the initiative."},
 doc("frus1969-76v31","d140","Preparing the 1976 summit, Parsky raises corporate bribery and Kissinger counsels against browbeating two governments already in difficulty."), ex("Q14"),
 doc("frus1977-80v03","d266","Cooper names the illicit payments proposal as an area where the United States can take the offensive; Vance highlighted the passage."), ex("Q20"),
 doc("frus1977-80v03","d310","Cooper tells Carter that illicit payments is one area where the United States has seized the initiative in the North–South dialogue."), ex("Q15")]
E+= [{"kind":"heading","text":"5. Bribery of the U.S. Congress and the Korean troop withdrawal (1978)","level":1},
 {"kind":"prose","text":"The Tongsun Park affair, in which South Korean figures were accused of bribing members of Congress, appears in the 1978 papers as a reason to postpone the first combat troop withdrawal from Korea: the scandal, not the withdrawal itself, set the limits of what Congress would vote."},
 doc("frus1977-80v13","d84","The NSC staff paper argues for postponing the first withdrawals because Congress cannot address Korean security while the Tongsun Park affair hangs over it."), ex("Q16"),
 doc("frus1977-80v13","d92","The interagency options memorandum carries the same justification into Option 2, postponing the December 1978 brigade withdrawal."),
 doc("frus1977-80v13","d94","At the White House meeting Holbrooke says the issue is the Tongsun Park affair, not the withdrawal, and that Congressmen fear voting any aid to Korea."), ex("Q17")]
E+= [{"kind":"heading","text":"6. An allegation of corruption as a weapon against the United States (1875)","level":1},
 {"kind":"prose","text":"An early counterpoint: here the allegation is aimed at a process the United States relied on, and the Venezuelan President uses it to refuse payment of U.S. claims awarded by an arbitral commission."},
 doc("frus1875v01","d199","Scruggs reports that Guzmán Blanco uses the alleged corruption of the claims commission as a pretext for refusing to pay U.S. claims."), ex("Q18")]
E+= [{"kind":"prose","text":"Threads this collection could not follow: what the investigating committees themselves found (the Senate multinational corporations subcommittee's and the House ethics inquiries' own records are outside FRUS); how the 1977 Foreign Corrupt Practices Act was drafted (four printed documents name it); corruption in U.S. advisory missions (one 1979 NSC memorandum mentions it for Iran); and anything after 1988, where the indexed series thins to one volume. Corruption described in passing in country reporting across the series (about three thousand documents) is not read here document by document."},
 {"kind":"generated","generatedBlockType":"archivalSources"}]
intro=("What FRUS answers directly: the printed record shows corruption shaping U.S. decisions in four recurring ways: as a reason to limit or condition aid to a client government (China 1947–48, the Philippines 1950), as an obstacle the United States declined to remove by taking control (South Vietnam 1960–68), as a diplomatic problem when American firms' bribes threatened allied governments (Lockheed and Northrop, 1975–76), and as a domestic scandal that constrained policy (Koreagate and the 1978 troop withdrawal). "
 "Where FRUS points for the rest: the documents came mainly from the Department of State's central files (Record Group 59), from lot files such as the Records of Henry Kissinger (Entry A1 5403) and Richard N. Cooper's subject files (Entry UD-04D 21/22), and from the Ford and Carter Libraries' national security files; the editors also cite unprinted Executive Secretariat and Policy Planning lots. "
 "What this request cannot get from FRUS: the congressional investigations' own records, the drafting of the Foreign Corrupt Practices Act, and anything after 1988.")
c={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"Corruption and U.S. foreign policy: what FRUS prints",
 "authorLine":"Agent run s9, 2026-10-30","introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":E}
pairs=[(e["volumeId"],e["documentId"]) for e in E if e["kind"]=="document"]
assert len(pairs)==len(set(pairs)), "duplicate"
for e in E:
    if e["kind"] in ("document","excerpt"): assert e.get("volumeId") and e.get("documentId")
    assert not e.get("volumeId","").endswith("Ed2")
exp={(e["volumeId"],e["documentId"]) for e in E if e["kind"]=="excerpt"}
assert exp <= set(pairs)
json.dump(c, open(R+"/collection.fruscollection","w"), indent=1, ensure_ascii=False)
print("documents", len(pairs), "excerpts", sum(e["kind"]=="excerpt" for e in E))
