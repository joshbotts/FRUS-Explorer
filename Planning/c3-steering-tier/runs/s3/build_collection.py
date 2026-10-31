import json, sqlite3, re
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
RUN="Agent run s3, 2026-10-30"
A="Agent finding, run s3, 2026-10-30: "
Q={(v,d):[] for v,d,q in json.load(open("quotes.json"))}
for v,d,q in json.load(open("quotes.json")): Q[(v,d)].append(q)
intro=("What FRUS answers directly: across the 553 volumes indexed, about one document in a hundred uses the language of corruption, bribery, graft or embezzlement, and the printed record shows corruption entering U.S. policy in three ways: as a measure of whether an aid recipient could survive (Nationalist China 1944-48, Korea and the Philippines 1961), as a lever for U.S. pressure on a dependent government (Cuba 1922), and, from 1974, as a diplomatic liability created by American firms' payments abroad (Saudi Arabia, Honduras, Western Europe), which ended in the Foreign Corrupt Practices Act and the 1980 debate over its export cost. "
"Where FRUS points for the rest: the documents came chiefly from the Department of State's central files (Record Group 59: the Central Decimal File, then the 1964-73 central files and the Central Foreign Policy File), from CIA files, and from the presidential libraries' National Security Files (Kennedy, naId 1164; Johnson, naId 567979; Nixon, naId 572235); and from RG 59 lots such as the Marshall Mission Files (Lot 54D270) and the NSC policy papers (Lot 63D351, naId 2839192, entry A1 1586E, 1947-1979, partly restricted). The editors' footnotes point, without printing, to the same central-file classes and to RG 59 Lots 66D95 and 63D351 (naId 2839192), 62D1 (Policy Planning Council, naId 2838992, 1948-1961) and 62D430 (naId 2839191, 1953-1961). "
"What this request cannot get from FRUS: nothing after the series ends (no 1990s document matched); the withheld names in the 1970s reporting (about one matching document in six from 1969 on carries a 'not declassified' bracket); and enclosures the editors did not print, such as Crowder's 1922 memorandum on graft in Cuba, which stays in the Central Decimal File.")
def doc(v,d,note): return {"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]}
def exc(v,d): return [{"kind":"excerpt","volumeId":v,"documentId":d,"text":q} for q in Q.get((v,d),[])]
E=[]
def sec(title, prose, docs):
    E.append({"kind":"heading","text":title,"level":1}); E.append({"kind":"prose","text":prose})
    for v,d,n in docs: E.append(doc(v,d,n)); E.extend(exc(v,d))
sec("Corruption as a condition of reform: Cuba, 1922",
 "The earliest sustained case in the set: the U.S. special representative made the reform of graft in the Cuban administration a formal demand, and asked Washington to back it with a warning. One document, read whole.",
 [("frus1922v01","d841","Crowder forwards his Memorandum No. 8 on graft and corruption (not printed) and asks for the Department's approval and a warning to the Zayas government; he reports he cannot get specific evidence.")])
sec("Corruption as a measure of an ally's viability: China, 1944-1948",
 "Embassy, consular and mission reporting treats Nationalist corruption as a cause of military failure and of lost public support, and the Wedemeyer mission's working papers make anti-corruption measures part of the reform programme. Date order.",
 [("frus1944v06","d292","Gauss transmits an OWI report from Fukien: graft and bribery are standard practice and the population cares more about bad government than the war."),
  ("frus1947v07","d583","Sprouse's memorandum for Wedemeyer lists reforms the U.S. should seek, including investigation of corruption among army officers and an empowered Control Yuan."),
  ("frus1948v07","d43","Stuart transmits a speech by Hollington Tong complaining that U.S. reporters play up graft cases and make Americans think the whole government corrupt: the allegation itself had become a factor in U.S.-China relations."),
  ("frus1948v07","d471","Clubb transmits Fu Tso-yi's speech attributing Nationalist defeat in Manchuria to Nationalist corruption and impotence.")])
sec("Graft and aid in Asia, 1961: Korea and the Philippines",
 "In 1961 the embassy in Seoul judged the military government's campaign against graft genuine, and in Washington a former ambassador and the desk discussed placing advisers in Philippine ministries to check graft. Date order.",
 [("frus1961-63v23","d356","Cowen tells Bell that graft and corruption are the principal cause of Garcia's low standing and proposes IMF-supplied 'watchdog' consultants; Garcia has signalled acceptance."),
  ("frus1961-63v22","d244","Embassy Seoul's assessment: the junta's drive against graft, bribery and smuggling is genuine and producing results, though signs of graft are reappearing in high places.")])
sec("American payments abroad as a diplomatic liability, 1974-1975",
 "From late 1974 the problem turns round: the corruption at issue is paid by American firms, and the documents weigh what disclosure will do to relations with Saudi Arabia, Honduras and the Federal Republic and the Netherlands. Date order.",
 [("frus1969-76ve09p2","d122","Embassy Jidda's airgram on corruption in Saudi Arabia: rising corruption is a medium-term threat to the regime and so to U.S. interests; recommends that the U.S. refuse to facilitate corrupt contracts."),
  ("frus1969-76ve11p1","d159","Rogers tells Kissinger that United Brands paid a $1.25 million bribe to Honduran officials; the Department refused to help cover it up and expects the Honduran government to fall."),
  ("frus1969-76ve09p2","d155","Atherton's August 1975 briefing for Kissinger: publicity over agents' fees paid by Northrop, Lockheed and Raytheon through Khashoggi threatens to strain U.S.-Saudi relations. Found by its similarity to the Jidda airgram, by no word search, and read before it was cited."),
  ("frus1969-76ve15p2","d292","Hartman reports the Church subcommittee staff's findings on Lockheed payments to Strauss and the CSU and to Prince Bernhard.")])
sec("From scandal to statute: the Foreign Corrupt Practices Act, 1980",
 "By 1980 the question had become whether the 1977 law cost exports. One document, read whole.",
 [("frus1977-80v03","d248","Klutznick and Askew list the FCPA as exporters' second export disincentive and recommend clarifying amendments without loopholes for bribery; Carter's statement followed.")])
E.append({"kind":"prose","text":"Threads not followed in this run: South Vietnam 1954-1968 and Iran 1951-1954, both heavily represented among the matching documents but not read; U.S. covert payments to foreign politicians (for example in the Congo, 1964-1968), present but not read; the 1976 OECD guidelines on bribery; Japan's Lockheed affair; the Church subcommittee and SEC records themselves; and the withheld names in the 1970s reporting."})
E.append({"kind":"generated","generatedBlockType":"archivalSources"})
pairs=[(e["volumeId"],e["documentId"]) for e in E if e["kind"]=="document"]
assert len(pairs)==len(set(pairs))
for e in E:
    if e["kind"] in ("document","excerpt"):
        assert e.get("volumeId") and e.get("documentId")
        r=con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(e["volumeId"],e["documentId"])).fetchone()
        assert r, e
        if e["kind"]=="excerpt": assert e["text"] in re.sub(r"\s+"," ",r[0]), e["text"]; 
        if e["kind"]=="excerpt": print("excerpt raw-exact" if e["text"] in r[0] else "excerpt whitespace-collapsed only", e["volumeId"], e["documentId"])
    assert not e.get("volumeId","").endswith("Ed2")
C={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"Corruption and U.S. foreign policy: scope run","authorLine":RUN,"introductionText":intro,
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},"entries":E}
json.dump(C,open("collection.fruscollection","w"),indent=1,ensure_ascii=False)
print("documents",len(pairs),"excerpts",sum(e["kind"]=="excerpt" for e in E))
