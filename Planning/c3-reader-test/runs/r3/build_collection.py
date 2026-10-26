import json,sqlite3,re,sys
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c=sqlite3.connect(DB,uri=True)
A="Agent finding, run r3, 2026-10-25: "
H=[]  # list of (heading, prose, [ (vol,doc,note,[excerpts]) ])
H.append(("The 1900 test and Wilson's constitutional test, 1900-1919",
"These seven documents follow the rule the Department wrote down in 1900 (recognize whoever holds power and will meet obligations), the exceptions it made for Haiti in 1911, and Wilson's turn in 1913 and 1917 toward asking whether a Latin American government rested on law and election.",
[("frus1900","d530","Colombia, 1900. The standing rule: recognition rests on de facto control, the assent of the people, no substantial resistance, and capacity to meet international obligations.",
  ["to base the recognition of a foreign government solely on its de facto ability to hold the reins of administrative power"]),
 ("frus1911","d353","Haiti, 1911. Recognition is held back until the Department receives satisfactory assurances about American interests: an early case of recognition conditioned on a promise.",
  ["take no steps looking to the recognition of a new government until he can communicate satisfactory assurances to this end to the Department"]),
 ("frus1913","d7","Wilson's statement of 11 March 1913, telegraphed to every American diplomatic officer in Latin America: friendship depends on government resting on law, not irregular force.",
  ["Cooperation is possible only when supported at every turn by the orderly processes of just government based upon law, not upon arbitrary or irregular force."]),
 ("frus1913","d894","Mexico, 28 February 1913. The Knox Department separates working relations with whoever is in control from the formal act of recognition, and names the tests it is applying: acquiescence of the population and ability and disposition to protect foreigners and meet obligations.",
  ["A distinction may be drawn between de facto relations with a de facto government and formal recognition of such government"]),
 ("frus1917","d379","Costa Rica, 9 February 1917. The constitutional test stated flatly: only a government elected legally and established under the Constitution is entitled to recognition.",
  ["no Government except such as may be elected legally and established according to the Constitution shall be considered entitled to recognition"]),
 ("frus1917","d407","Costa Rica, 9 June 1917. The President's direction to refuse Tinoco recognition is reaffirmed, with an exit offered: retire in favour of an independent, law-abiding successor.",
  ["by the express direction of the President of the United States you are instructed to reaffirm his previously expressed determination not to recognize General Tinoco as President of Costa Rica"]),
 ("frus1919v01","d869","Costa Rica, 19 August 1919. After Tinoco's fall, the Department says what would earn recognition: a president freely elected under the constitution Tinoco violated.",
  ["any person elected to the position of president of Costa Rica in free, open elections held under the constitution of Costa Rica, violated by Federico Tinoco, would appear to be [have] good claim to recognition"]),
]))
H.append(("Recognition as a bargain: Mexico, 1920-1923",
"Here the Department asked for something specific and written. These four documents show it refusing even de facto recognition in 1920, announcing in 1921 that a treaty protecting American property would itself be the recognition, and explaining in 1923 why it had insisted on that sequence.",
[("frus1920v03","d199","Mexico, 25 May 1920. Colby warns the Chargé to avoid any act that could be read as recognition of the Agua Prieta regime, even de facto.",
  ["Recognition cannot be accomplished by inference merely but by the full and formal entrance into international relations through the public action of the respective executives of the two countries."]),
 ("frus1921v02","d344","Mexico, 8 June 1921. The Department's public statement: the fundamental question is protection of property rights against confiscation; recognition will follow, concurrently, a binding commitment.",
  ["when it appears that there is a government in Mexico willing to bind itself to the discharge of primary international obligations, concurrently with that act its recognition will take place"]),
 ("frus1921v02","d349","Mexico, 21 July 1921. President Harding to General Obregon: signing the proposed treaty would effect recognition at once. Read in part first; the whole text was later read.",
  ["In entering into this treaty with you recognition would be effected, ipso facto."]),
 ("frus1923v02","d481","Mexico, 8 May 1923. Hughes briefs the American commissioners: Carranza had been recognized on assurances that were then broken, so a clear understanding was sought before recognizing Obregon. About 9,500 of its 33,346 characters were read.",
  ["it was deemed important, in order to avoid a serious crisis, that there should be a clear understanding of the policy of General Obregon’s regime before it was recognized and diplomatic relations were resumed"]),
]))
H.append(("The Central American treaty rule and the Hoover-Stimson practice, 1926-1934",
"After the 1923 Washington treaty the United States adopted its non-recognition rule for coups in the five Central American republics, while for South America in 1930 it returned to the plain de facto test. These six documents show both rules, and the case (El Salvador 1931-1934) where the treaty rule outlasted every other government's patience.",
[("frus1926v02","d476","Nicaragua, 22 January 1926. Kellogg tells the Nicaraguan minister the United States has adopted the 1923 treaty's principles as its own policy for Central America and will not recognize General Chamorro.",
  ["The United States has adopted the principles of that Treaty as its policy in the future recognition of Central American Governments"]),
 ("frus1930v01","d375","South America, 17 September 1930. Stimson's press statement recognizing the new governments of Argentina, Peru and Bolivia on the de facto test, with a separate account of the Central American and Cuban exceptions.",
  ["the evidence has satisfied me that these provisional governments are de facto in control of their respective countries, and that there is no active resistance to their rule"]),
 ("frus1930v01","d476","Brazil, 7 November 1930. Stimson asks why Brazil should wait for a constitutional convention when Argentina, Bolivia and Peru were recognized on de facto control alone.",
  ["In the cases of Argentina, Bolivia, and Peru we recognized upon the frank basis of a control by a de facto government."]),
 ("frus1931v02","d208","El Salvador, 7 December 1931. The Department applies the 1923 treaty to the Salvadoran coup, asking whether the Vice President took part in it, since if so he could not be recognized.",
  ["if the Vice President was a leader in the coup d’état or revolution, under the terms of the treaty of 1923 he could not be recognized"]),
 ("frus1932v05","d478","Chile, 6 June 1932. The Department's three usual requirements, set out to the Ambassador in Santiago: control, no active resistance, intention to meet international obligations.",
  ["whether the de facto Government can satisfy the usual requirements of international practice, namely, that it is in control of the country and that there is no active resistance to it, and that it intends to fulfill its international obligations"]),
 ("frus1934v05","d218","El Salvador, 16 January 1934. Hull reports the view, from the Minister in Colombia and the Guatemalan foreign minister, that non-recognition of the Martinez regime was working to deter revolutions.",
  ["existing non-recognition policy had good effect in keeping down revolutions and should be preserved"]),
]))
H.append(("Cuba, 1933-1934: popular support, and Latin American opinion",
"For Cuba the Department stated criteria in a form unusually close to a checklist. These three documents show Welles arguing for 'latitude' in applying them, the Department naming them, and the Latin American majority's view being used as a reason to continue withholding recognition.",
[("frus1933v05","d430","Cuba, 5 October 1933. Welles argues against recognizing the Grau regime now, on the ground that it lacks a considerable measure of popular support.",
  ["if we recognize a government now which does not possess at least a considerable measure of popular support we postpone a return by Cuba to normal and stable conditions"]),
 ("frus1933v05","d508","Cuba, 28 November 1933. Acting Secretary Phillips to Hull at Montevideo: the two criteria the Department has maintained.",
  ["We have maintained that the criteria of Cuban recognition are: (1) popular support, and (2) ability to maintain law and order and carry on the functions incumbent upon any stable government."]),
 ("frus1934v05","d75","Cuba, 8 January 1934. The British Foreign Office would be on the brink of recognizing a Grau-type regime elsewhere; the Department says recognition would be a mistake and cites Latin American sentiment.",
  ["recognition of the present regime in Cuba would be a great mistake; that the sentiment of the Latin American Governments in the great majority was against such recognition"]),
]))
H.append(("Consultation among the republics, and the separation of recognition from approval, 1943-1949",
"In the war the United States stopped deciding alone: it agreed with the other republics to consult before recognizing a regime born of force, and used the Bolivian junta of December 1943 as the test. After the war the Policy Planning Staff and the Bogota conference of 1948 tried to remove moral judgment from recognition; in December 1949, on Panama, this was put into practice and debated.",
[("frus1943v05","d33","The Committee's recommendation of 24 December 1943, as transmitted to Hull.",[]),
 ("frus1943v05","d142","Bolivia, 25 December 1943. Hull sets the policy: withhold recognition and, quietly, hold up export licences and shipping space. Read in part first; the whole text was later read.",
  ["For the immediate present the Department proposes to withhold action authorizing the recognition of the new government in Bolivia."]),
 ("frus1943v05","d34","Hull's acceptance, 27 December 1943, of the Committee's resolution to consult before recognizing governments set up by force.",
  ["they do not proceed to the recognition of a new government instituted by force, before consulting among themselves for the purpose of determining whether this government complies with the Inter-American undertakings for the defense of the continent"]),
 ("frus1944v07","d403","Bolivia, 28 January 1944. All nineteen republics withheld recognition from the junta in public statements, and Hull calls this a tribute to the consultative procedure.",
  ["All of the nineteen republics participating in the consultations and exchange of information regarding the Bolivian revolution have refused recognition to the Junta in public statements."]),
 ("frus1945v09","d1170","Venezuela, 25 October 1945. The consultation applied to a different outcome: control, general support, intention to meet obligations, no Axis inspiration, so recognize early.",
  ["that it enjoys general support without active opposition and (3) that it intends to fulfill its international obligations"]),
 ("frus1948v09","d7","Policy Planning Staff paper PPS/24, 15 March 1948. Three factors, recognition implying neither approval nor disapproval, and no recognition withheld as a political weapon except in extreme cases.",
  ["Recognition of a government by the United States should imply neither approval nor disapproval of the policies of that government with respect to strictly domestic affairs."]),
 ("frus1949v02","d446","Panama, 6 December 1949. A State Department officer objects that the Ambassador's public remark made non-recognition look like disapproval, against the declared purpose of the policy.",
  ["This purpose, as I understand it, is to separate the fact of recognition or non-recognition from approval or disapproval of domestic aspects of a situation."]),
 ("frus1949v02","d448","Panama, 8 December 1949. Miller's note to Acheson: consultation completed, criteria met, recognition about two weeks after the new president took power.",
  ["the present government apparently intends to live up to its international commitments"]),
]))
H.append(("Assurances and elections in the Cold War, and the retreat from 'recognition', 1957-1973",
"By the late 1950s the Department mostly recognized, and the question was what private assurances to extract first. These ten documents show assurances on elections, anti-communism and peaceful settlement being sought from Haiti, El Salvador, Peru, Bolivia and Argentina, then the formula of 'traditional tests' (1968), the Chilean junta's note of 1973, and the general instruction of 1973 to keep recognition questions in a low key.",
[("frus1955-57v06","d354","Haiti, 11 July 1957. Dulles tells the Embassy what to say to the junta: the Department prefers not to delay recognition and wants assurance of effective control and respect for obligations, but not an election pledge as a condition.",
  ["does not wish to find itself recognizing a new de facto regime every few weeks and would like reasonable assurance that Junta is actually in effective control of country as well as ready to abide by nation’s international obligations"]),
 ("frus1958-60v05mSupp","es_d33","El Salvador, 8 November 1960. Merchant recommends continuing to withhold recognition, on the ground that waiting gives leverage to friends in the junta. The source text bears the note that events overtook it.",
  ["withholding of recognition, at least until the situation clarifies, in fact places some leverage in the hands of friends in the junta"]),
 ("frus1958-60v05mSupp","es_d40","El Salvador, 26 November 1960. Herter proposes recognition on about 30 November after an officer's survey of the junta's independence from Castroist influence.",
  ["he has reported that Osorio seems to be the key figure behind the present Government and that the latter is attempting to maintain its independence of Castroist or Communist policies and personnel"]),
 ("frus1961-63v12","d421","Peru, 27 July 1962. Ball to Kennedy on what to ask the junta, and the case against an OAS foreign ministers' meeting. Read in part first; the whole text was later read.",
  ["It is of great importance to have the junta reaffirm, publicly and with emphasis, its intention to hold free elections"]),
 ("frus1961-63v12","d423","Peru, 30 July 1962. The package the junta is to restate: civil liberties, free elections by a date, OAS observers; civilianizing the cabinet helpful but not a sine qua non.",
  ["Some civilianizing of Cabinet, provided civilian members were known for dedication to constitutional processes, would make our recognition easier, but our view is not to insist on this as sine qua non of recognition."]),
 ("frus1964-68v31","d152","Bolivia, 3 December 1964. Recognition recommended after private pledges to reduce communist influence and not to restore relations with Cuba or Czechoslovakia.",
  ["Barrientos and his principal advisers have privately pledged that communist influence will be reduced and eventually eliminated, and that they will not reestablish relations with Cuba or Czechoslovakia."]),
 ("frus1964-68v31","d141","Argentina, 12 July 1966. Recognition after consultation under the Rio Conference's Resolution XXVI; the Argentines were told informally that public statements on its points plus a peaceful-settlement pledge would help.",
  ["We also indicated informally to the Argentine authorities that public statements on the points contained in Resolution XXVI, plus a commitment on peaceful settlement of disputes, would facilitate recognition by the United States."]),
 ("frus1964-68v31","d518","Peru, 19 October 1968. Recognition recommended: the government is in control and has 'met all the traditional tests', although the return to elected government could take years.",
  ["It has met all the traditional tests for recognition."]),
 ("frus1969-76ve08","d6","Afghanistan, 20 July 1973, a world-wide statement of Department practice, cited here because it states how the Department had come to treat recognition by the 1970s.",
  ["the Department’s policy is to minimize to the greatest extent possible recognition questions"]),
 ("frus1969-76v21","d358","Chile, 17 September 1973. The junta's note asking to continue relations is to be answered affirmatively 'in the next few days'; recognition is not mentioned as such.",
  ["it instructs our Ambassador to tell the Junta that we will be responding affirmatively to their note re continuing relations “in the next few days.”"]),
]))
INTRO=("What FRUS answers directly: the published diplomatic papers show the Department stating its tests for recognizing Latin American governments that came to power by force, from the de facto rule of 1900 to Wilson's constitutional test, the Hoover-Stimson practice, the 1943-1949 consultation system and the 1960s assurances, in 38 documents drawn from 25 volumes of a 553-volume library. "
"Where FRUS points for the rest: the documents came overwhelmingly from the State Department's central decimal files (Record Group 59) and, for 1960s-70s papers, from presidential libraries and the National Security Council files; the editors' footnotes point mostly to further decimal-file papers on the same countries. "
"What this request cannot get from FRUS: the Latin American governments' own reasoning, the staff-level working papers where individual decisions were made, and a single codified list of conditions, because the printed record shows the conditions varying case by case.")
entries=[]
used=set()
for h,prose,docs in H:
    entries.append({"kind":"heading","text":h,"level":1})
    entries.append({"kind":"prose","text":prose})
    for v,d,note,exs in docs:
        row=c.execute("select body_text,is_front_matter,is_editorial_note from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
        assert row, (v,d)
        assert row[1]==0 and row[2]==0,(v,d)
        assert not v.endswith('Ed2')
        assert (v,d) not in used; used.add((v,d))
        entries.append({"kind":"document","volumeId":v,"documentId":d,"notes":[A+note]})
        for e in exs:
            assert e in row[0], ("EXCERPT NOT FOUND",v,d,e)
            entries.append({"kind":"excerpt","volumeId":v,"documentId":d,"text":e})
entries.append({"kind":"heading","text":"Threads not followed","level":1})
entries.append({"kind":"prose","text":"Not followed: the editors' chapter headings for Bolivia 1920-21 (Saavedra), Peru 1919-20 (Leguia), Guatemala 1921-22 (Orellana), Ecuador 1928, Guatemala 1931, El Salvador 1945 and Haiti 1950 were found but their documents were not read; Argentina under Farrell 1944-45 was identified but not read; the Dominican Republic and Honduras in 1963, Brazil in 1964 and Bolivia in 1980 were seen in search results and not read; the Wilson-era Mexican cases (Huerta, Carranza) were read only at the level of the first statements; nothing before 1900 was searched; and no Latin American government's own papers are in this library. All counts and findings rest on a partial library of 553 volumes."})
entries.append({"kind":"generated","generatedBlockType":"archivalSources"})
col={"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"Recognizing governments that came to power by force in Latin America: run r3","authorLine":"Agent run r3, 2026-10-25","introductionText":INTRO,
"composition":{"defaultBodyDepth":"full","footnoteStyle":"all","includeSourceNote":True,"tocStyle":"citation","applyHighlights":False,"includeNotes":True,"includeWordCloud":False},"entries":entries}
json.dump(col,open('collection.fruscollection','w'),ensure_ascii=False,indent=2)
ex=[e for e in entries if e['kind']=='excerpt']; dc=[e for e in entries if e['kind']=='document']
print('documents',len(dc),'excerpts',len(ex),'volumes',len({e['volumeId'] for e in dc}))
# pairs.txt consistency
P={tuple(l.split()) for l in open('pairs.txt')}
print('pairs match', P==used, len(P), len(used))
