# build collection.fruscollection from excerpts.json and the notes below; verify every pair in document_cache
import json, sqlite3
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
ex = {(v,d): t for v,d,t in json.load(open("excerpts.json"))}
A = "Agent finding, run s2, 2026-10-30: "
intro = ("What FRUS answers directly: corruption entered U.S. policy in two ways. A client government's corruption became a reason Washington gave for withholding, conditioning or redesigning aid and a standing subject of pressure (Nationalist China 1944–48, South Vietnam 1960 and 1967, South Korea 1961); and from 1975 American companies' payments abroad, above all Lockheed's, put friendly governments at risk and pushed Washington toward an international agreement and the Foreign Corrupt Practices Act. Between them, bribery appears as an instrument used by rivals, proposed in Washington and charged against it (Jordan 1956, Iraq 1959, Iran 1965). The words appear in about one document in a hundred across the series' 553 volumes; 19 documents carry the argument. "
 "Where FRUS points for the rest: the printed documents came from the Department of State Central Decimal File (RG 59), the Marshall Mission Files (RG 59, Lot 54 D 270; ten NARA series under creator 10481258), the Conference Files (RG 59, Lot 62 D 181; probable series 602875, entry A1 3051B, 1949–1972, unrestricted), the Kissinger staff-meeting transcripts (RG 59, Entry 5177) and records (Entry 5403), and the Johnson, Kennedy, Ford and Carter libraries' national security files; the footnotes cite, unprinted, the Far Eastern Affairs files (RG 59, Lot 62 D 26; series 1965953, entry A1 3113, 1960–1963, partly restricted), the Saigon embassy's Can Lao file (RG 84, Lot 65 F 115) and the Jidda embassy's Lockheed file (RG 84, Lot 79 F 80). "
 "What this request cannot get from FRUS: the post-1980 record (the 1977 law is named in no document of the thirteen 1981–88 volumes); the Senate investigations' own records; the names of the payees, still withheld; and the nineteenth-century record, which is in the corpus but not followed here and has almost no shelf in the bundled finding aids.")
S = [
 ("China: corruption as Washington's stated reason for reluctance on aid, 1944–1948",
  "These four documents follow one thread: the embassy's reporting of Nationalist corruption, Marshall's parting advice to Soong, Stuart's answer to the 1947 loan request, and the Chinese government's complaint that American reporting was making corruption the American image of China.",
  [("frus1944v06","d148","Gauss reports that corruption in the Ministries of Food and War is the most dangerous to the government's survival; the embassy's frame for later aid debates."),
   ("frus1946v10","d373","Marshall, leaving China, tells T. V. Soong that a respectable opposition would let Chiang root out graft and corruption: reform as the condition of American confidence."),
   ("frus1947v07","d908","Asked to support a one-billion-dollar loan, Stuart cites American opinion that the government is reactionary and corrupt: the allegation used directly against an aid request."),
   ("frus1948v07","d43","Stuart transmits the Chinese information chief's complaint that U.S. reporters play up corruption cases: the allegation as a factor in American opinion, seen from Nanking.")]),
 ("South Vietnam: allegations as leverage on aid, 1960, and as a war priority, 1967",
  "Durbrow and the Department used the Can Lao allegations, proven or not, as leverage tied to Congress and to the next year's aid; seven years later the senior officials' group made an anti-corruption campaign its first priority, partly for opinion at home.",
  [("frus1958-60v01","d131","Durbrow tells Diem that aid for fiscal 1961 may be hard to get if reports of Can Lao corruption continue, and presses him whether the reports are true or not."),
   ("frus1958-60v01","d135","The Department raises corruption with Thuan; the desk officer's memorandum, quoted by the editors, warns that even untrue rumours could hurt if aid funds seemed involved."),
   ("frus1964-68v05","d395","Katzenbach reports the senior group's unanimous view that a visible anti-corruption effort is the first priority for 1968, for the Administration's position and for an effective GVN.")]),
 ("South Korea: an aid official's corruption report reopens policy, 1961",
  "Farley's report and the White House response nine days later. The second document uses none of the words for corruption; it was found by its similarity to the first and read before it was cited.",
  [("frus1961-63v22","d202","Farley, who resigned from the aid mission, reports that graft, corruption and fraud endanger the whole U.S. position in Korea and the Mutual Security program."),
   ("frus1961-63v22","d204","Rostow tells Kennedy that Farley's paper shows Korea policy needs a fresh look and that the White House has asked State for recommendations. Found by its similarity to Document 202, by no word search.")]),
 ("Bribery as an instrument: by rivals, proposed in Washington, charged against it, 1956–1965",
  "Three documents in which bribery is a tool of statecraft rather than a domestic vice: a British complaint about Saudi money in Jordan, an American admiral's suggestion about Iraq, and an Iranian charge against the United States.",
  [("frus1955-57v13","d16","During Eden's visit, Lloyd tells the Americans that Saudi bribery of Jordanian officials leaves the British unsure of Jordan's course."),
   ("frus1958-60v12","d168","The Chief of Naval Operations offers Herter, via a note to Allen Dulles, oil pressure on Iraq or bribery as alternatives against Qasim."),
   ("frus1964-68v22","d79","CIA reports that a U.S. military credit bill, presented just after the status-of-forces bill, led to charges that Washington had bribed the Iranian government.")]),
 ("American companies' payments abroad as a crisis of alliance management, 1975–1976",
  "Once the Senate exposed Lockheed's payments, the State Department managed the fallout with Saudi Arabia, West Germany and the Netherlands, and Japan: protect the names, keep it quiet, or share evidence.",
  [("frus1969-76ve09p2","d152","At Kissinger's staff meeting Maw explains the Northrop and Lockheed fee disclosures; Kissinger doubts the Saudis want to change and fears they will go to other suppliers."),
   ("frus1969-76ve09p2","d161","Akins tells Prince Sultan of Lockheed's admitted bribes; Sultan demands the names never be divulged and warns of the end of the special relationship."),
   ("frus1969-76ve15p2","d293","Church subcommittee findings on Lockheed and McDonnell Douglas payments in West Germany; the editors quote Kissinger telling Ford to keep the Bernhard and Strauss payments quiet."),
   ("frus1969-76ve12","d218","Miki asks Ford for disclosure of the officials named, warning that Japanese democracy may suffer a fatal blow if the names stay in doubt.")]),
 ("From scandal to rules: an international agreement and the Foreign Corrupt Practices Act, 1976–1980",
  "Ford's reply to Miki ties the scandal to an American proposal for an international agreement; by 1978 State saw consensus forming at the UN; by 1980 the 1977 law was being weighed as a cost to exporters.",
  [("frus1969-76ve12","d219","Ford offers Miki access to SEC evidence through law-enforcement channels and asks Japan to back the U.S. proposal for an international agreement on corrupt practices."),
   ("frus1977-80v03","d308","A State paper reports consensus forming in the UN working group on an illicit-payments agreement, though in 1976 and 1977 the G-77 were not ready to schedule a diplomatic conference."),
   ("frus1977-80v03","d248","Klutznick and Askew report exporters rank the Foreign Corrupt Practices Act the second most significant export disincentive; lost exports were the law's intended cost.")]),
]
entries=[]; seen=set()
SQL="SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0"
for head, prose, docs in S:
    entries.append({"kind":"heading","text":head,"level":1})
    entries.append({"kind":"prose","text":prose})
    for v,d,note in docs:
        assert con.execute(SQL,(v,d)).fetchone(), (v,d)
        assert (v,d) not in seen and not v.endswith("Ed2"); seen.add((v,d))
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]})
        entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":ex[(v,d)]})
entries.append({"kind":"heading","text":"Threads not followed","level":1})
entries.append({"kind":"prose","text":"Not followed in this run: Somoza and Nicaragua, 1978–79; Mobutu's Zaire, 1977–78; Costa Rica and the Vesco affair, 1976; Iran under Zahedi, 1953–54; the Philippine election of 1953; the nineteenth-century record (Hawaii 1893, claims, extradition treaties naming bribery); U.S. covert payments; consular-fee bribery; the post-1980 record of the Foreign Corrupt Practices Act, which the published volumes do not yet reach; and the Senate investigations' own records."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
col={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
     "name":"Corruption and U.S. foreign policy — FRUS, 1944–1980","authorLine":"Agent run s2, 2026-10-30",
     "introductionText":intro,
     "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
     "entries":entries}
json.dump(col, open("collection.fruscollection","w"), ensure_ascii=False, indent=2)
cited={tuple(l.strip().split("/")) for l in open("cited.txt") if l.strip()}
print("documents", len(seen), "excerpts", sum(1 for e in entries if e["kind"]=="excerpt"), "== cited.txt:", seen==cited, "== excerpts.json pairs:", seen==set(ex))
