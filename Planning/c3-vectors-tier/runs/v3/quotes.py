import sqlite3, re, json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
Q=[
("Q01","frus1874","d552","Cuba is the largest insular possession still retained by any European power in America. It is almost contiguous to the United States."),
("Q02","frus1874","d552","In fine, Cuba, like the former continental colonies of Spain in America, ought to belong to the great family of American republics, with political forms and public policy of their own, and attached to Europe by no ties, save those of international amity, and of intellectual, commercial, and social intercourse."),
("Q03","frus1874","d552","In short, the state of Cuba is the one great cause of perpetual solicitude in the foreign relations of the United States."),
("Q04","frus1881","d405","That rich island, the key to the Gulf of Mexico, and the field for our most extended trade in the Western Hemisphere is, though in the hands of Spain, a part of the American commercial system."),
("Q05","frus1886","d414","which buys about 95 per cent, of the sugar exported from Cuba"),
("Q06","frus1898","d498","the sugar plantations of Cuba are as necessary to the food supply of the United States as are the cotton fields of India and the cotton and wheat fields of Egypt and the grain fields of Russia to England and to other countries"),
("Q07","frus1898","d498","the United States does not seek to annex Cuba or to establish a protectorate over Cuba"),
("Q08","frus1898","ch83","The present condition of affairs in Cuba is a constant menace to our peace, and entails upon this Government an enormous expense."),
("Q09","frus1898","ch83","The right to intervene may be justified by the very serious injury to the commerce, trade, and business of our people, and by the wanton destruction of property and devastation of the island."),
("Q10","frus1904","d207","That to enable the United States to maintain the independence of Cuba, and to protect the people thereof, as well as for its own defense, the government of Cuba will sell or lease to the United States lands necessary for coaling or naval stations at certain specified points to be agreed upon with the President of the United States"),
("Q11","frus1904","d207","That the government of Cuba consents that the United States may exercise the right to intervene for the preservation of Cuban independence, the maintenance of a government adequate for the protection of life, property, and individual liberty"),
("Q12","frus1929v02","d924","there is invested in Cuba at the present time, nearly 1,500 million dollars of American capital"),
("Q13","frus1930v02","d747","A great many people seem to think that the Platt Amendment gives us a protectorate over the internal affairs of Cuba"),
("Q14","frus1933v05","d299","the purpose of my mission here is to avoid the existence of a situation which would give rise to intervention by the United States"),
("Q15","frus1934v05","d127","eliminating the permissive right of intervention by this Government, has removed a chronic source of friction between our two countries, and has placed our political relations on a basis of true and friendly equality."),
("Q16","frus1934v05","d127","The magnitude of this concession is a further indication of the desire of this Government to assist the Cuban people in regaining an adequate and satisfactory standard of living."),
("Q17","frus1952-54v04","d342","It would seem to ignore the fact that Cuba has been a reliable expansible source of sugar in both war and peace, a strategic concept which should not be jeopardized."),
("Q18","frus1941v07","d119","The principle of leased areas over which the United States forces exercise unquestioned jurisdiction could not be applied to other countries of the Hemisphere"),
("Q19","frus1944v07","d878","Plans of the President and of the Joint Chiefs of Staff call for a defense facility in western Cuba under the exclusive jurisdiction of the United States Government, although it is understood that it may not be possible to obtain exclusive jurisdiction."),
("Q20","frus1945v09","d741","President Grau, as a matter of sovereignty, is adamant on the proposition that there shall not be a lease of the bases to anyone."),
("Q21","frus1958-60v06","d70","If the security of the nation is destroyed or an avenue is opened up for leftist exploitation, this would certainly weaken the nation’s stability and affect hemispheric defense."),
("Q22","frus1958-60v05","d112","Fidel Castro, the instigator of the present unsettled situation, is advocating a neutralistic bloc in Latin America, while actually supporting Communist-dominated revolutionary groups conspiring against the Dominican Republic and Nicaragua."),
("Q23","frus1958-60v06","d499","it follows that every possible means should be undertaken promptly to weaken the economic life of Cuba."),
("Q24","frus1958-60v06","d499","The principal item in our economic quiver would be flexible authority in the sugar legislation."),
("Q25","frus1961-63v11","d21","What is the strategic impact on the position of the United States of MRBMs in Cuba? How gravely does this change the strategic balance? McNamara: Mac, I asked the Chiefs that this afternoon, in effect. And they said, substantially. My own personal view is, not at all."),
("Q26","frus1961-63v11","d34","However, the existence of strategic missiles in Cuba had an entirely different impact throughout Latin America."),
("Q27","frus1961-63v11","d34","In his view the existence of fifty planes in Cuba did not affect the balance of power, but the missiles already in Cuba were an entirely different matter."),
("Q28","frus1961-63v10-12mSupp","d729","The bare minimum objective of our policy is a Cuba which poses no threat to its neighbors and which is not a Soviet satellite."),
("Q29","frus1961-63v10-12mSupp","d729","intensifying Cuba’s already-serious economic difficulties; increasing the cost and unpleasantness to the Soviets of maintaining Cuba; and stimulating direct and indirect internal resistance to the regime"),
("Q30","frus1969-76ve10","d205","Cuba has been a double-barreled problem for the U.S.: —as a base for Soviet military power, and —as an exporter of revolutionary doctrine and violence to Latin America."),
("Q31","frus1977-80v23","d21","The political significance of both sides of the trade issue far outweighs economic effects."),
("Q32","frus1977-80v23","d21","Even on sugar, our leverage in economic terms is quite modest."),
("Q33","frus1981-88v03","d5","The intent of the 1962 Understanding was to prevent Cuba from becoming a threat to the security of the US—and to countries friendly to us in the Hemisphere."),
("Q34","frus1898","d498","our native cane-sugar crop, raised mostly in Louisiana and Texas, does not furnish more than one-tenth of the sugar we consume"),
("Q35","frus1977-80v23","d21","U.S. claims now total about $2 billion, on which a settlement of at least $600 million (the usual 30%) might well be possible."),
]
ok=0; out=[]
for qid,v,d,t in Q:
    body=db.execute("select body_text, length(body_text) from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    exact = t in body[0]
    coll = re.sub(r"\s+"," ",t) in re.sub(r"\s+"," ",body[0])
    ok+=exact
    out.append({"id":qid,"volumeId":v,"documentId":d,"text":t,"exact":exact,"collapsed":coll,"bodyLen":body[1]})
    if not exact: print("NOT EXACT",qid,v,d,"collapsed:",coll)
json.dump(out,open("quotes_verified.json","w"),indent=1,ensure_ascii=False)
print("verified exact",ok,"of",len(Q))
