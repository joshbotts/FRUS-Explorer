# Extracts every quotation as an exact substring of document_cache.body_text (SELECT recorded per quote in out/quotes.tsv),
# verifies every cited pair exists (non-apparatus), and writes collection.fruscollection. Nothing here is a report file.
import sqlite3, json, re, sys, datetime
R="/Users/jbotts/frus-analysis/c3/runs/r7/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
RUN="Agent run r7, 2026-10-25"
TITLES={
 "frus1865p3":"Foreign Relations of the United States, 1865, Part III","frus1881":"Foreign Relations of the United States, 1881",
 "frus1891":"Foreign Relations of the United States, 1891","frus1899":"Foreign Relations of the United States, 1899",
 "frus1907p2":"Foreign Relations of the United States, 1907, Part II","frus1911":"Foreign Relations of the United States, 1911",
 "frus1913":"Foreign Relations of the United States, 1913","frus1914":"Foreign Relations of the United States, 1914",
 "frus1915":"Foreign Relations of the United States, 1915","frus1916":"Foreign Relations of the United States, 1916",
 "frus1917":"Foreign Relations of the United States, 1917","frus1919v02":"Foreign Relations of the United States, 1919, Volume II",
 "frus1920v01":"Foreign Relations of the United States, 1920, Volume I","frus1921v02":"Foreign Relations of the United States, 1921, Volume II",
 "frus1923v02":"Foreign Relations of the United States, 1923, Volume II","frus1925v02":"Foreign Relations of the United States, 1925, Volume II",
 "frus1930v01":"Foreign Relations of the United States, 1930, Volume I","frus1930v03":"Foreign Relations of the United States, 1930, Volume III",
 "frus1931v02":"Foreign Relations of the United States, 1931, Volume II","frus1934v05":"Foreign Relations of the United States, Diplomatic Papers, 1934, The American Republics, Volume V",
 "frus1936v05":"Foreign Relations of the United States, Diplomatic Papers, 1936, The American Republics, Volume V","frus1937v05":"Foreign Relations of the United States, Diplomatic Papers, 1937, The American Republics, Volume V",
 "frus1939v05":"Foreign Relations of the United States, Diplomatic Papers, 1939, The American Republics, Volume V","frus1943v05":"Foreign Relations of the United States, Diplomatic Papers, 1943, The American Republics, Volume V",
 "frus1944v07":"Foreign Relations of the United States, Diplomatic Papers, 1944, The American Republics, Volume VII","frus1945v09":"Foreign Relations of the United States, Diplomatic Papers, 1945, The American Republics, Volume IX",
 "frus1946v11":"Foreign Relations of the United States, 1946, The American Republics, Volume XI","frus1947v08":"Foreign Relations of the United States, 1947, The American Republics, Volume VIII",
 "frus1948v09":"Foreign Relations of the United States, 1948, The Western Hemisphere, Volume IX","frus1950v02":"Foreign Relations of the United States, 1950, The United Nations; The Western Hemisphere, Volume II",
 "frus1952-54v04":"Foreign Relations of the United States, 1952–1954, The American Republics, Volume IV","frus1955-57v07":"Foreign Relations of the United States, 1955–1957, American Republics: Central and South America, Volume VII",
 "frus1958-60v05mSupp":"Foreign Relations of the United States, 1958–1960, Volume V, Microfiche Supplement, American Republics","frus1958-60v06":"Foreign Relations of the United States, 1958–1960, Cuba, Volume VI",
 "frus1961-63v10-12mSupp":"Foreign Relations of the United States, 1961–1963, Volumes X/XI/XII, Microfiche Supplement, American Republics; Cuba 1961–1962; Cuban Missile Crisis and Aftermath",
 "frus1961-63v12":"Foreign Relations of the United States, 1961–1963, Volume XII, American Republics","frus1964-68v31":"Foreign Relations of the United States, 1964–1968, Volume XXXI, South and Central America; Mexico",
 "frus1969-76v21":"Foreign Relations of the United States, 1969–1976, Volume XXI, Chile, 1969–1973","frus1977-80v15":"Foreign Relations of the United States, 1977–1980, Volume XV, Central America",
 "frus1977-80v24":"Foreign Relations of the United States, 1977–1980, Volume XXIV, South America; Latin America Region",
}
def cite(v,d):
    num=d.split("_")[-1][1:] if "_" in d else d[1:]
    label=("Document "+d.split("_")[0].upper()+"–"+num) if "_" in d else "Document "+num
    return f"{TITLES[v]}, {label}", f"https://history.state.gov/historicaldocuments/{v}/{d}"
# (finding, vid, did, start snippet, end snippet, note)  -- end=None means quote is exactly the start snippet
Q=[
 (1,"frus1865p3","d423","the suggestion was offered to you by Mr. Drouyn de Lhuys","cannot be made","France asked Washington to promise de facto recognition of Maximilian if the Emperor withdrew; Seward refuses: a regime imposed by foreign arms gets no de facto recognition."),
 (1,"frus1891","d152","As on frequent occasions in the past","congressional party in Chile.","Mid-civil-war Chile: the Department will not prejudge recognition of a revolutionary movement and declines to receive its agents."),
 (1,"frus1899","d792","Test of recognition is complete regency","international obligations.","Hay's one-sentence test after Castro's march on Caracas: full control by a de facto government able to meet international obligations; meanwhile deal with local authorities."),
 (1,"frus1907p2","d27","Being advised of the competency of the provisional government","directed the recognition of the provisional government","Honduras 1907: recognition follows competency to perform international obligations plus steps to revive the constitution and hold an election."),
 (1,"frus1911","d933","The Department, following its usual practice in such cases","bordering on the Atlantic","Nicaragua 1909–11: the usual practice of answering no request from insurgents while holding whichever faction is de facto in control accountable for American lives and property."),
 (1,"frus1913","d849","this Government must very carefully consider the question","incidental to international intercourse","Knox, a week after Huerta's coup: the test is ability and disposition to meet international law, treaties and duties to foreigners, and assurances on outstanding Mexican questions are asked before recognition."),
 (1,"frus1913","d894","In the meantime this Government is considering the question","protect foreigners and their interests","Knox names the usual tests: the degree to which the population acquiesces in the new regime, and its disposition and ability to protect foreigners; de facto relations are distinguished from formal recognition."),
 (2,"frus1913","d1028","A satisfactory settlement seems to us to be conditioned on","supporting the new administration.","Wilson's August 1913 terms for Mexico, delivered through Lind: armistice, an early free election, Huerta not a candidate, all parties to abide by the result; recognition pledged to the government so chosen."),
 (2,"frus1914","d506","the Government of the United States will be probably disposed to recognize","consent of the governed.","Haiti, February 1914: Bryan grounds recognition of Zamor on the consent of the governed, and attaches the Department's financial and territorial conditions before instructing on recognition."),
 (2,"frus1914","d540","if the United States Government is satisfied that these elections","constitutional government of the republic","Haiti, November 1914: Wilson's plan makes recognition of a president and congress conditional on elections the United States has observed and judged free and fair."),
 (2,"frus1915","d993","The Conferees, after careful consideration of the facts","de facto government of Mexico","October 1915: the Pan-American conferees find Carranza's party the only one with the essentials for recognition as the de facto government, and the United States recognizes it eight days later."),
 (2,"frus1916","d244","Provisional Government will not be recognized until","free from dominion of Arias.","Dominican Republic 1916: recognition withheld until the new government accepts the American reading of the 1907 convention on customs control and a constabulary."),
 (2,"frus1917","d382","By authorization of the President you are instructed to inform Tinoco","recognition by the United States.","Costa Rica 1917: Tinoco told that election will not cure the coup; Wilson will not recognize him even if elected."),
 (2,"frus1920v01","d391","the elections to be held in Bolivia in November","before recognizing it.","Bolivia 1920: Washington and Buenos Aires agree to wait for elections under the constitution, and ask Brazil to act in concert."),
 (3,"frus1907p2","d148","Article I. The Governments of the High Contracting Parties shall not recognize","constitutionally reorganized the country.","1907: the Central American Peace Conference's additional convention, printed inside the American delegate's report, binds the five republics not to recognize a government born of a coup or revolution until freely elected representatives have reorganized the country; the clause the 1923 treaty repeated and Washington adopted."),
 (3,"frus1921v02","d344","The question of recognition is a subordinate one","the Government that makes it.","Mexico 1921: Hughes makes a treaty protecting property rights the instrument of recognition; signing it would itself recognize Obregón."),
 (3,"frus1923v02","d345","will not recognize any other Government which may come into power","constitutionally reorganized the country.","Honduras 1923: Hughes quotes Article II of the Central American treaty and announces that United States practice will follow it."),
 (3,"frus1925v02","d498","the Government of the United States would not extend recognition","violent or unconstitutional means.","Nicaragua 1925: Kellogg's rule for Chamorro's coup, stated as harmony with the 1923 treaty."),
 (3,"frus1931v02","d412","After the publication of the call for new elections to be held within 6 months","constitutional manner.","Guatemala 1931: a provisional president who came in constitutionally and has called elections within six months can be recognized; the Department seeks to act in harmony with the treaty signatories."),
 (3,"frus1931v02","d208","this Government has adopted, in accordance with the principles of the treaty of 1923","come into power by revolution.","El Salvador 1931: the policy of nonrecognition of Central American governments that come to power by revolution, and the rule that a vice president who led the coup cannot be recognized."),
 (3,"frus1934v05","d199","Since General Martínez had been Minister of War","declined to recognize General Martínez.","El Salvador 1934: why Martínez was refused in 1932, and the procedure for recognizing him once El Salvador and Costa Rica had denounced the treaty."),
 (3,"frus1936v05","d112","embodying the conclusion that “the United States should no longer be guided by Article II","fail to take”.","April 1936: Hull's instruction to the five Central American missions ends the Article II rule as the guide to recognition."),
 (4,"frus1930v01","d375","the evidence has satisfied me","elections to regularize its status.","September 1930: Stimson's public statement recognizing the provisional governments of Argentina, Peru and Bolivia on the de facto tests, with a promise of elections."),
 (4,"frus1930v03","d658","in considering the question of the recognition of a de facto government","private revenge and persecution or mob violence.","Peru 1930: Stimson tells the Peruvian ambassador that treatment of the deposed government's members counts in the capacity-to-protect test."),
 (4,"frus1937v05","d271","this Government would, of course, desire a little time","ordinary functions of government.","Bolivia 1937: Welles answers the claim that an army regime needs no new recognition by asking a little time to see popular support and working government, under the traditional policy."),
 (4,"frus1939v05","d312","1. Where a new régime is established through a coup d’état or revolution","continuance of our relations with it.","1939: the Legal Adviser's two rules: a coup requires some form of recognition, which may be ordinary dealing; a self-coup by a recognized government needs none."),
 (5,"frus1944v07","d414","The Bolivian Junta which has been recognized only by Argentina","liberty of the press.","Bolivia 1944: the junta's decree calling elections, an amnesty and press freedom is circulated to the other republics as the ground for the consultation on recognition."),
 (5,"frus1944v07","d227","we do not intend to recognize until there is concrete evidence","pro-German elements.","Argentina 1944: Armour urges holding recognition of Farrell until concrete anti-Nazi measures are taken."),
 (5,"frus1944v07","d1138","The revolutionary Junta in Guatemala appears to be accepted","able to carry out its undertakings.","Guatemala 1944: the Department's case for recognizing the junta, stated as the de facto tests plus elections announced."),
 (5,"frus1945v09","d242","That the United States be prepared to enter into consultation","measures against the Axis and Axis sympathizers.","Argentina, January 1945: the Department's list of steps required before consultation on recognition: an interim constitutional government, a break with the Axis, dissolution of Axis organizations, end of the state of siege and elections."),
 (5,"frus1945v09","d1170","This Govt has received reports from Corrigan indicating that","Venezuelan Junta revolutionary movement","Venezuela 1945: the three tests (control, general support without active opposition, intention to fulfil obligations) plus the Axis test; consultation under Resolution XXII before recognizing."),
 (5,"frus1946v11","d312","In light of its apparent popular basis","international obligations will be fulfilled.","Bolivia 1946: favourable impression from the junta's democratic character and its pledges of elections and obligations; consultation expected."),
 (5,"frus1948v09","d119","An important consideration in this Govt’s approval Bogotá Res 35","continues to be view this Govt.","Venezuela, December 1948: the Bogotá resolution's premise that non-recognition is not a suitable tool against dictatorship and force."),
 (5,"frus1950v02","d477","It is understood that the President wishes to be consulted","assume power by force.","Haiti 1950: recognition of regimes that assume power by force is cleared with the President; the junta's pledges of elections and obligations are the record."),
 (5,"frus1952-54v04","d327","The Batista regime has formally requested our recognition","communist activities in Cuba.","Cuba 1952: what Batista offered before recognition: international obligations, private capital, curbs on communist activity."),
 (5,"frus1952-54v04","d136","The first prerequisite to recognition of a de facto government","control of the national territory.","Bolivia 1952: control of the national territory named as the first prerequisite; the delay explained by doubt about control."),
 (6,"frus1955-57v07","d195","we were now satisfied that the new government had de facto control","prerequisites for recognition had been complied with.","Argentina 1955: de facto control plus acceptance of international obligations, with the President asking about freedom of the press."),
 (6,"frus1958-60v05mSupp","ve_d1","In the belief that early recognition on our part","Provisional Government of Venezuela.","Venezuela 1958: recognition of the junta within days, after assurances on investment and anti-communism."),
 (6,"frus1958-60v06","d217","I believe that the statements of intention of the new government","friendly relations with the United States.","Cuba, January 1959: Dulles recommends recognizing the Provisional Government on its statements of control, order and obligations, noting no Communist taint."),
 (6,"frus1961-63v10-12mSupp","d114","The takeover by the Junta arrested a dangerous drift","influence the new government","El Salvador 1961: recognition recommended because the junta stopped a drift toward Castroism and promised elections; some neighbours will withhold on principle."),
 (6,"frus1961-63v12","d427","Ambassador Loeb told top Peruvian military leaders","continue assistance programs","Peru 1962: the warning given before the coup, with the President's authority, that a government installed by coup would be very difficult to recognize."),
 (6,"frus1961-63v12","d423","1. Guarantee of continued civil liberties.","sine qua non of recognition.","Peru, July 1962: what Washington asked of the junta before resuming relations: civil liberties, free elections by June 1963 with the armed forces bound to the result, OAS observers; a civilian cabinet desired but not required."),
 (6,"frus1961-63v10-12mSupp","d109","USG considers Ecuadorean Junta has demonstrated ability","Latin American countries have done so.","Ecuador 1963: the junta has control, restored civil liberties and accepted obligations; still wanted is a public promise of civilian rule within about a year, and recognition waits for several other Latin American governments."),
 (6,"frus1961-63v10-12mSupp","d159","Until a govt is recognized by US","recognition of any govt.","Honduras, October 1963: the embassy is to avoid any contact that could imply approval of the coup or foreshadow recognition."),
 (6,"frus1961-63v12","d363","In cases both countries our principal objective in withholding recognition","pending new elections.","December 1963: the objectives of withholding recognition from the Dominican and Honduran regimes, and the judgment that further non-recognition would gain nothing."),
 (6,"frus1964-68v31","d206","Under Secretary Ball noted that there would be no problem","relations with the President.","Brazil, April 1964: with Mazzilli sworn in as acting president there is no recognition question; relations simply continue."),
 (6,"frus1964-68v31","d132","In keeping with international practice in such cases, diplomatic relations are suspended","Resolution XXVI of 1965 Rio Conference.","Argentina 1966: relations suspended after Onganía's coup and consultation opened under the 1965 Rio resolution."),
 (6,"frus1964-68v31","d512","Herein I shall seek to open dialogue","toward a variant of Estrada Doctrine","Peru 1968: Oliver proposes moving United States practice toward a version of the Estrada doctrine, recognizing states rather than judging governments."),
 (6,"frus1964-68v31","d515","The United States has initiated bilateral consultations","Inter-American Conference of 1965.","Peru 1968: consultation under the 1965 procedures; the junta promised to meet obligations but set no election date."),
 (6,"frus1969-76v21","d348","we should take the public position that we recognize governments","question of recognition has not arisen","Chile, 12 September 1973: the public line that the United States recognizes governments, not heads of government; and Kubisch's warning against too hasty recognition."),
 (6,"frus1969-76v21","d348","The biggest errors we have made in Latin America","in Brazil, for example.","Chile, 12 September 1973: Kubisch's warning against too hasty recognition of military regimes, Brazil 1964 the example."),
 (6,"frus1969-76v21","d361","recognition of the new government would be announced on Monday, 24 September 1973",None,"Chile, 20 September 1973: the date fixed for recognition, with the ambassador to tell the junta of goodwill and aid."),
 (6,"frus1977-80v15","d294","We should first immediately consult with our Latin American friends","have recognized it.","Nicaragua 1979: consult friends first and withhold recognition until several Latin American governments have acted."),
 (6,"frus1977-80v24","d328","Christopher reiterated that it would be very difficult","under present circumstances.","Bolivia 1980: after García Meza's coup the Deputy Secretary tells Uruguay that recognition or support is very difficult; the regime is isolated for its repression."),
]
EXTRA=[ # documents in the collection without an excerpt (context the findings rest on)
 (1,"frus1881","d583","Peru 1881: Blaine reminds the minister that recognition of the Calderón government was decided in Washington and that Piérola's rival authority cannot be recognized."),
 (3,"frus1936v05","d107","March 1936: Duggan's memorandum concluding that the treaty can no longer be invoked after Guatemala, Honduras and Nicaragua broke it."),
 (5,"frus1943v05","d484","Bolivia, December 1943: the chiefs of mission counsel caution and consultation; the Mexican ambassador explains why Mexico suspends its Estrada doctrine in wartime."),
 (5,"frus1947v08","d755","Nicaragua 1947: Costa Rican and Dominican recognition of the de facto regime breaks the common withholding; the Department consults the other republics."),
 (6,"frus1964-68v31","d209","Brazil, April 1964: the ambassador warns the new government that American support depends on juridical appearances."),
]
quotes=[]; qout=open(R+"out/quotes.tsv","w"); qout.write("quote_id\tfinding\tvolume_id\tdocument_id\tSELECT\tstart_offset\tlength\ttext\n")
ok=True
for i,(f,v,d,s,e,note) in enumerate(Q,1):
    sql="SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0"
    row=con.execute(sql,(v,d)).fetchone()
    if not row: print("MISSING PAIR",v,d); ok=False; continue
    b=row[0]; n=b.count(s)
    if n!=1: print(f"Q{i} {v}/{d}: start snippet occurs {n} times"); ok=False; continue
    a=b.index(s)
    if e is None: text=s
    else:
        z=b.find(e,a)
        if z<0: print(f"Q{i} {v}/{d}: end snippet not found after start"); ok=False; continue
        text=b[a:z+len(e)]
    quotes.append((f"Q{i}",f,v,d,text,note))
    qout.write(f"Q{i}\t{f}\t{v}\t{d}\t{sql.replace('?',repr(v),1).replace('?',repr(d),1)}\t{a}\t{len(text)}\t{text}\n")
qout.close()
for f,v,d,note in EXTRA:
    if not con.execute("SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d)).fetchone(): print("MISSING EXTRA",v,d); ok=False
print("quotes extracted:", len(quotes), "of", len(Q), "| all ok:", ok)
if not ok: sys.exit(1)
# citations table
with open(R+"out/citations.tsv","w") as c:
    seen=set()
    for _,_,v,d,_,_ in quotes:
        if (v,d) in seen: continue
        seen.add((v,d)); t,u=cite(v,d); c.write(f"{v}\t{d}\t{t}\t{u}\n")
    for f,v,d,note in EXTRA:
        if (v,d) in seen: continue
        seen.add((v,d)); t,u=cite(v,d); c.write(f"{v}\t{d}\t{t}\t{u}\n")
# collection
H={1:("Before Wilson: the de facto test and the refusal to prejudge, 1865–1913","Nineteenth-century and Taft-era instructions apply one rule to governments born of civil war or coup: wait, see whether the new authority holds the country and can meet its obligations, and refuse to judge its title. The thread runs from Seward's refusal to recognize Maximilian to Knox's 'usual tests' a week after Huerta's coup."),
   2:("Wilson's constitutional test and the conditions it produced, 1913–1920","From 1913 recognition became a lever: withheld from usurpers, promised to governments chosen in elections the United States could judge free, and tied to specific undertakings on customs, constabularies and candidacies. These documents show the conditions as they were put to Mexico, Haiti, the Dominican Republic, Costa Rica and Bolivia."),
   3:("The Central American treaty rule, and its end, 1921–1936","In Central America the United States adopted, without being a party, the 1923 treaty's Article II: no recognition for a government born of coup or revolution until the people's freely elected representatives had reorganized the country, and never for the coup's leaders. Mexico's recognition in 1921–23 was priced in a treaty instead. In 1936 the Department stopped invoking Article II after the signatories broke it."),
   4:("The return to de facto practice and the doctrine of no formal act, 1930–1939","Outside Central America the Hoover and Roosevelt administrations recognized the governments of the 1930s revolutions on the old tests, stated publicly in September 1930, and the Legal Adviser settled that a self-coup by a recognized government needs no new act while a coup against it requires some form of recognition."),
   5:("Consultation among the American republics, the Axis test and the Bogotá resolution, 1943–1952","The war added two things: consultation among the republics before any one recognized a government that came in by force, and an Axis test beside the de facto tests. After 1948 the Bogotá resolution's premise that non-recognition was not a suitable weapon against dictatorship governed, with a communist test replacing the Axis one."),
   6:("The Cold War pattern: quick recognition, conditional withholding, and the drift toward recognizing states, 1955–1980","Eisenhower recognized anti-communist juntas within days on the de facto tests; Kennedy withheld recognition from the coups of 1962–63 and asked for civil liberties, dated elections and observers; Johnson's and Nixon's administrations let relations continue or recognized after consultation, while Carter returned to withholding in Nicaragua and Bolivia.")}
entries=[]
for f in sorted(H):
    entries.append({"kind":"heading","text":H[f][0],"level":1})
    entries.append({"kind":"prose","text":H[f][1]})
    items=[(v,d,text,note) for (_,ff,v,d,text,note) in quotes if ff==f]+[(v,d,None,note) for (ff,v,d,note) in EXTRA if ff==f]
    # date order
    dates={}
    for v,d,_,_ in items:
        r=con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(v,d)).fetchone(); dates[(v,d)]=(r[0] if r and r[0] else "")
    items.sort(key=lambda x: dates[(x[0],x[1])])
    seen=set()
    for v,d,text,note in items:
        if (v,d) not in seen:
            seen.add((v,d)); entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[f"Agent finding, {RUN}: {note}"]})
        if text: entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":text})
entries.append({"kind":"prose","text":"Threads this run could not follow: the 1923 Central American treaty's text is cited to a separate publication and only its Article II is quoted (the 1907 convention is printed inside the delegate's report); the general policy papers on coups of 1962–63 and 1964 are not printed, only the country cases; the volumes for 1981–1988 hold no recognition decision for the coups of that decade; and the Latin American side of the argument (the Tobar and Estrada doctrines, the Betancourt doctrine) appears only as reported by American officers. The archival sources block below lists the series the printed documents came from and the series the editors cited without printing."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
pairs=[(e["volumeId"],e["documentId"]) for e in entries if e["kind"]=="document"]
assert len(pairs)==len(set(pairs)), "duplicate document pair"
assert not any(v.endswith("Ed2") for v,_ in pairs)
for e in entries:
    if e["kind"] in ("document","excerpt"): assert e.get("volumeId") and e.get("documentId")
coll={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,
 "name":"Recognition of governments that came to power by force in Latin America, 1865–1980 — run r7",
 "authorLine":RUN,
 "introductionText":open(R+"out/introduction.txt").read().strip() if __import__("os").path.exists(R+"out/introduction.txt") else "What FRUS answers directly: … Where FRUS points for the rest: … What this request cannot get from FRUS: …",
 "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},
 "entries":entries}
json.dump(coll, open(R+"collection.fruscollection","w"), ensure_ascii=False, indent=1)
print("collection: documents", len(pairs), "excerpts", sum(1 for e in entries if e["kind"]=="excerpt"), "headings", len(H))
