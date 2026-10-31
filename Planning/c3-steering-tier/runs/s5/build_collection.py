import json, sqlite3, re
from docs_list import SECTIONS
from quotes_ov import OV
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ATT="Agent finding, run s5, 2026-10-30: "
NOTES={
"frus1944v06/d269":"Gauss reports an alleged plot by young Chinese officers to remove officials believed corrupt and inefficient; he notes that criticism of corruption does not attach to Chiang except for failing to remove the corrupt.",
"frus1947v05/d23":"Acheson names unprecedented corruption in the Greek civil service among the reasons aid cannot be used well, and asks for American and British administrative experts alongside it.",
"frus1947v07/d553":"A Chinese State Council member tells the embassy, for General Wedemeyer, that U.S. aid must come with close supervision and that corruption is worst among military commanders.",
"frus1948v07/d440":"Chinese legislators say Communist propaganda has led the U.S. to think the National Government corrupt: the allegation appears as a contested fact in Sino-American relations.",
"frus1949v08/d576":"Acting President Li Tsung-jen's circle asks the U.S. to aid the existing government 'corrupt as it is'; the corruption is conceded by those asking for help.",
"frus1981-88v01/d247":"Policy Planning Staff talking points: the Philippine insurgency war goes badly partly because the military are corrupt, and Marcos may be a liability.",
"frus1981-88v01/d264":"INR names corruption among the usual causes of a regime's exhausted legitimacy, 'as in Manila'; read with the 1985 talking points as the Marcos endgame.",
"frus1912/d1502":"Acting Secretary of State urges approval of the Nicaragua loan convention and describes the Zelaya years as arbitrary and corrupt government.",
"frus1922v01/d836":"Reached by vector neighbourhood of the graft memorandum, not by a corruption word search: it contains none. It shows Crowder sequencing his reform memoranda, budget first.",
"frus1922v01/d841":"Crowder forwards his memorandum on graft, corruption and immorality, asks for Washington's approval and a warning to the Zayas administration, and admits he cannot obtain proof.",
"frus1922v01/d842":"Crowder's memorandum on the National Lottery: the colecturia system's corruption is beyond Cuban remedy and the U.S. should take official cognizance.",
"frus1922v01/d862":"The Department tells Crowder the reform plan is vital for stamping out corruption and that Cuban financial rehabilitation depends on it.",
"frus1922v01/d864":"Latin American Division note: Crowder advises against consenting to a loan unless the amnesty bill covering the indicted lottery officials is killed.",
"frus1950v06/d802":"Acheson briefs Truman before Quirino's visit: Philippine performance must precede more aid; revenues are the object of graft; Quirino took a speech as a charge of corruption.",
"frus1952-54v12p2/d324":"Ambassador Spruance proposes telling Quirino privately that aid will stop if the 1953 election is won by force and corrupt practices.",
"frus1955-57v22/d7":"Prime Minister Nu inclines against asking for a U.S. loan because widespread corruption makes it impossible to ensure funds are properly used: a recipient's refusal.",
"frus1961-63v20/d422":"Rusk asks Belgian Foreign Minister Spaak what can be done to control corruption in Leopoldville, noting trouble with Congress over aid to the Congo.",
"frus1964-68v32/d8":"The embassy proposes that Mann raise graft with Bonilla on the ground that the aid program loses value if run amid corruption.",
"frus1958-60v01/d135":"State relays a talk with Thuan: reports of corruption in Viet-Nam have reached Capitol Hill and business circles; budget-support principles are discussed.",
"frus1958-60v01/d156":"At the NSC, a briefing on criticism that Diem fostered corruption; the President says the U.S. had been proud of Diem.",
"frus1958-60v01/d160":"Durbrow's demarche to Diem on corruption in the Can Lao party; Diem answers that the party's job is to stop corruption.",
"frus1961-63v01/d298":"Nolting reports Senator Ellender's view that the insurgency expresses discontent with a corrupt regime and that U.S. aid breeds corruption.",
"frus1964-68v05/d258":"Calhoun to Komer: corruption is a key obstacle to pacification, but an American veto over appointments would invade sovereignty and feed the neo-colonial charge.",
"frus1964-68v05/d301":"State to Bunker on using American leverage after the elections; the editors' note records that the priorities paper put corruption third; the cable cautions against careless leverage.",
"frus1969-76v08/d191":"Sullivan tells WSAG that a Senate Foreign Relations Committee staff report says there is corruption throughout South Vietnam and that U.S. officials ignore it.",
"frus1981-88v41/d251":"White House memorandum on African hunger: corruption aggravates economic decline, and aid through governments weakens conditionality.",
"frus1949v06/d330":"Acheson cites Nationalist China as the example of the wrong policy; the Shah answers that China fell largely because of corruption.",
"frus1950v05/d289":"The Shah, in a Reuters interview reported by the chargé, complains that the U.S. press accuses Iran of corruption while other recipients of aid are no better.",
"frus1950v03/d728":"Truman-Attlee talks: Marshall says Chiang was held free of personal corruption but his followers and party were corrupt, in the argument over Formosa and recognition.",
"frus1961-63v22/d252":"Harriman, reporting on Korea's new rulers, is impressed by their drive against corruption and recommends no change in aid policy.",
"frus1969-76ve09p2/d155":"Briefing for Kissinger on Saudi Arabia: publicity about agents' commissions on Northrop and Lockheed contracts threatens to strain U.S.-Saudi relations.",
"frus1977-80v03/d35":"Owen to Carter: at the London summit Carter asked the leaders for support on irregular practices in trade to avoid bribery; ECOSOC is to convene a conference on illicit payments.",
"frus1977-80v24/d337":"Carter asks Venezuela's President Perez for his good offices on the international treaty on illicit payments; Perez links it to the code of conduct.",
"frus1977-80v03/d65":"Owen's summit follow-up memorandum: the illicit-payments agreement needs the summit countries' full support; Carter annotates 'Let's push this'.",
"frus1977-80v03/d230":"Export disincentives: the President is advised to reiterate support for the Foreign Corrupt Practices Act's purpose while noting business complaints about ambiguity.",
"frus1977-80v03/d248":"Commerce and USTR call the FCPA the second most significant export disincentive, while stating that the prohibition on bribery was fully intended.",
"frus1893/d628":"Terrell had an investigation moved from Amadia to Mosul after being told the officials at Amadia were corrupt: corruption as a ground for diplomatic action.",
"frus1921v01/d275":"Schurman argues that extraterritoriality should not end until Chinese judicial practice no longer shows delay, improper influence, squeeze and corruption.",
}
HEADS=["Corruption was diagnosed early and often, and the usual response was supervision, not withdrawal",
"Aid and loans were made to depend on reform, and the demand was easier to make than to enforce",
"In Vietnam the question was how far an ally could be pressed",
"The China story became a lesson, and the allegation a retort",
"From 1975 the briber was often American",
"Corrupt courts, and the protection of Americans abroad"]
PROSEL=["Officials diagnosed corruption in clients they were about to aid. These documents follow the response: supervision or reform, not withdrawal. Date order, 1944 to 1986.",
"Here corruption is tied to a loan or aid decision, from Nicaragua in 1912 to the Dominican Republic in 1964. Cuba in 1922 is the fullest sequence; the Burma telegram is the recipient's own refusal.",
"The Vietnam documents show the limit on conditionality: corruption was a key obstacle, but leverage meant taking over the government. The 1986 Africa memorandum states the same limit.",
"China's fall was carried into other conversations as a lesson by Americans and as an excuse by others; Korea in 1962 shows an anti-corruption banner accepted without a change in aid.",
"From 1975 the question turned to the bribery done by American firms: the Saudi agents' fees, the treaty on illicit payments pressed at summits, and the exporters' complaint about the Foreign Corrupt Practices Act.",
"Before the Cold War, corruption in foreign courts and offices was a reason for how Americans protected themselves and kept their jurisdiction."]
INTRO=("What FRUS answers directly: about three thousand documents in the 551 first-edition volumes of the index use the vocabulary of corruption, bribery or graft; on a forty-document test, eight in forty tie it to an American choice. The choices are: supervising rather than dropping a corrupt client (China 1944 to 1949, Greece 1947, the Philippines 1985); making aid or a loan depend on reform (Cuba 1922, the Philippines 1950 and 1952), with Burma refusing American money for the same reason in 1955; declining to press an ally hard enough to change it (Vietnam 1960 to 1972); and, from 1975, regulating and negotiating over the bribery done by American firms. "
"Where FRUS points for the rest: the documents came mostly from the Central Files of the Department of State, Record Group 59 (23 of 37 with a source line), with one from the Conference Files lot (Record Group 59, entry A1 3051B, identifier 602875, 1949 to 1972, unrestricted; probable match by name), two from the Policy Planning Staff lot 89 D 149, seven from presidential libraries and three from non-National Archives holdings; the editors' unprinted citations over the hit documents point to the Carter, Johnson and Nixon libraries and to the Executive Secretariat NSC Policy Papers series (Record Group 59, entry A1 1586E, identifier 2839192, 1947 to 1979, partly restricted). The two channels are not summed. "
"What this request cannot get from FRUS: a rate (FRUS is a selection); whether the stated reason was the real one (foreign archives); years the index barely holds (before 1860, and the 1990s); the companies' own records of the 1970s payments (the Senate subcommittee and Securities and Exchange Commission files); and intelligence reporting on foreign corruption.")
THREADS=("Threads not followed in this run: the 1949 White Paper's own treatment of Nationalist corruption (not in this index); Mobutu's Zaire, Trujillo's Dominican Republic and Batista's Cuba after 1958 as cases of corruption and policy; Marcos after 1986 and Panama under Noriega, which fall at or past the edge of the index; the Church Subcommittee papers and the Securities and Exchange Commission's 1976 report on questionable payments; the Organisation for Economic Co-operation and Development's convention of the 1990s; and foreign-language and foreign-archive accounts of any of these cases. The documents on Iran in the 1970s were not read.")
used={p:[q for q in qs if q in open("overview.md").read()] for p,qs in OV.items()}
entries=[]; ordered=[]; seen=set()
for si,(title,pairs) in enumerate(SECTIONS):
    entries.append({"kind":"heading","text":HEADS[si],"level":1})
    entries.append({"kind":"prose","text":PROSEL[si]})
    dated=[]
    for a in pairs:
        v,d=a.split("/")
        r=db.execute("SELECT dd.date_iso FROM document_cache c LEFT JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=? AND c.is_front_matter=0 AND c.is_editorial_note=0",(v,d)).fetchone()
        assert r is not None, a
        dated.append((r[0] or "9999",a))
    for _,a in sorted(dated):
        v,d=a.split("/"); assert a not in seen and not v.endswith("Ed2"); seen.add(a)
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[ATT+NOTES[a]]})
        for q in used.get(a,[]): entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":q})
entries.append({"kind":"heading","text":"Threads not followed","level":1})
entries.append({"kind":"prose","text":THREADS})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
doc={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"Corruption and American foreign policy, run s5, 2026-10-30","authorLine":"Agent run s5, 2026-10-30","introductionText":INTRO,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},"entries":entries}
json.dump(doc,open("collection.fruscollection","w"),ensure_ascii=False,indent=1)
# validation
d=json.load(open("collection.fruscollection"))
docs=[e for e in d["entries"] if e["kind"]=="document"]; exs=[e for e in d["entries"] if e["kind"]=="excerpt"]
pairs=[(e["volumeId"],e["documentId"]) for e in docs]; assert len(pairs)==len(set(pairs))
for v,dd in pairs: assert db.execute("SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?",(v,dd)).fetchone()
ok=0
for e in exs:
    t=" ".join(db.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(e["volumeId"],e["documentId"])).fetchone()[0].split())
    ok+= " ".join(e["text"].split()) in t
print("documents",len(docs),"excerpts",len(exs),"excerpts verified",ok,"all keys present:",all("volumeId" in e and "documentId" in e for e in docs+exs), "composition keys",len(d["composition"]))
print("Ed2 volumes present:",[p for p in pairs if p[0].endswith("Ed2")])
