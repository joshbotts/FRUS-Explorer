# quotes.py: the quotation table (id, volume_id, document_id, text) and its verifier. Verification SELECT: SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?  ; test: text in body_text (raw, exact) and in whitespace-collapsed body_text.
Q=[
("Q01","frus1889","d43","so soon as a majority of the people of Brazil should have signified their assent to the establishment and maintenance of the Republic he was to give it, on behalf of the United States, a formal and cordial recognition."),
("Q02","frus1895p1","d246","the practice of this Government has been to enter into effective relations with the de facto government when it shall have been fully established with the general consent of the people."),
("Q03","frus1900","d530","to base the recognition of a foreign government solely on its de facto ability to hold the reins of administrative power"),
("Q04","frus1900","d530","it is in a position to fulfill all the international obligations and responsibilities incumbent upon a sovereign state under treaties and international law"),
("Q05","frus1913","d7","Cooperation is possible only when supported at every turn by the orderly processes of just government based upon law, not upon arbitrary or irregular force."),
("Q06","frus1913","d1028","The consent of General Huerta to bind himself not to be a candidate for election as President of the Republic at this election"),
("Q07","frus1915","d987","It is a question of fact as to whether they are in power. If they are in power then we can only consider them for recognition."),
("Q08","frus1916","d258","The withholding of the funds by the United States Government, on account of the fact that recognition has not been granted to Henríquez, has brought an economic crisis in the country"),
("Q09","frus1917","d379","no Government except such as may be elected legally and established according to the Constitution shall be considered entitled to recognition"),
("Q10","frus1920v01","d377","the Government of the United States has not as yet recognized the revolutionary Government as being even a de facto government"),
("Q11","frus1920v01","d391","The two Governments believe it advisable to wait until a government has been formed as a result of the elections in accordance with the Constitution before recognizing it."),
("Q12","frus1920v01","d399","the President has determined to recognize the Government of Bolivia, as soon as a provisional President is elected, as the de facto Government of Bolivia"),
("Q13","frus1921v02","d344","when it appears that there is a government in Mexico willing to bind itself to the discharge of primary international obligations, concurrently with that act its recognition will take place."),
("Q14","frus1923v02","d484","It seems to be advisable that we should agree upon a day on which the resumption of diplomatic relations should be formally announced."),
("Q15","frus1923v02","d345","will not recognize any other Government which may come into power in any of the five Republics through a coup d’état or a revolution against a recognized Government, so long as the freely elected representatives of the people thereof have not constitutionally reorganized the country."),
("Q16","frus1930v01","d375","the evidence has satisfied me that these provisional governments are de facto in control of their respective countries, and that there is no active resistance to their rule."),
("Q17","frus1930v01","d375","Each of the present governments has also made it clear that it is its intention to fulfill its respective international obligations and to hold, in due course, elections to regularize its status."),
("Q18","frus1932v05","d618","Martínez can under no circumstances be recognized. This is not due to any animus against Martínez, but because of the clear provisions of the Treaty."),
("Q19","frus1932v05","d641","it was obvious that if the British Government should grant recognition to Martínez it would have the effect of encouraging him to stay on in power"),
("Q20","frus1933v05","d508","We have maintained that the criteria of Cuban recognition are: (1) popular support, and (2) ability to maintain law and order and carry on the functions incumbent upon any stable government."),
("Q21","frus1934v05","d255","the Government of the United States should cooperate with them in that effort"),
("Q22","frus1936v05","d109","Under our new policy, if General Somoza headed a régime which effectively governed the country and fulfilled its international obligations we would extend recognition to him regardless of his eligibility to recognition under the 1923 Treaty."),
("Q23","frus1943v05","d334","In order that all the American governments may arrive at a common decision and take simultaneous action it is obviously necessary that there be the fullest exchange of information and consultation between the several governments"),
("Q24","frus1943v05","d340","has the hope and belief that Argentina will collaborate in the same spirit and measure as the other American republics for the fulfillment of inter-American solidarity in all its aspects"),
("Q25","frus1943v05","d486","Included in the relevant considerations is the question whether outside influence unfriendly to the Allied cause played any part."),
("Q26","frus1944v07","d219","In all matters relating to the security and defense of the Hemisphere, we must look to the substance rather than the form."),
("Q27","frus1944v07","d231","it is almost incredible that any American regime should expect recognition and the advantages of membership in the American family of nations without sincerely contributing to this common effort"),
("Q28","frus1944v07","d429","The present Bolivian Government has shown, by its acts, to be sympathetic to the Allied cause."),
("Q29","frus1944v07","d437","this Government is also willing to recognize on June 23 if it is the consensus on the part of the Governments of the American nations"),
("Q30","frus1945v09","d70","The Department hopes that the general adoption of the Estrada doctrine will not be pressed in as much as it doubts that the doctrine is a desirable basis for our recognition policy"),
("Q31","frus1948v09","d7","(a) de facto control of the territory and the administrative machinery of State, including the maintenance of public order; (b) the ability and willingness of a government to discharge its international obligations; (c) general acquiescence of the people of a country in the government in power."),
("Q32","frus1948v09","d89","In the absence of any compelling reason to the contrary, it is desirable for the United States to maintain diplomatic relations with all Latin American governments."),
("Q33","frus1948v09","d115","Recognition should not be withheld as a political weapon or to express moral censure except in extreme cases when U.S. national interests would be served thereby."),
("Q34","frus1948v09","d119","non-recognition is not a suitable approach to much broader problem of dictatorships and use of force as a political procedure"),
("Q35","frus1949v02","d457","Delay in resuming relations might affect domestic prestige of the de facto government sufficiently to encourage it to adopt more representative procedures and democratic practices in order to win United States “approval” by recognition and add to its prestige and political strength."),
("Q36","frus1952-54v04","d490","one of criteria for recognition is that new government be in control of territory of the country"),
("Q37","frus1958-60v06","d217","I believe that the statements of intention of the new government have been made in good faith and that it is in our national interest to recognize the Provisional Government of Cuba without delay."),
("Q38","frus1961-63v12","d421","It is of great importance to have the junta reaffirm, publicly and with emphasis, its intention to hold free elections so that any temptation to continue to enjoy the fruits of power may be discouraged."),
("Q39","frus1961-63v12","d423","Guarantee of free and fair elections, preferably before June 9 but at no later date, with full rights to all parties under Constitution, and with guarantee that Armed Forces will respect results those elections."),
("Q40","frus1961-63v12","d423","our view is not to insist on this as sine qua non of recognition"),
("Q41","frus1961-63v12","d363","In cases both countries our principal objective in withholding recognition has been return at earliest possible date constitutionally elected government."),
("Q42","frus1964-68v31","d135","we should seek the usual assurances regarding acceptance of international obligations, as well as respect for civil liberties and an early return to constitutional government, before recognizing"),
("Q43","frus1964-68v31","d141","We also indicated informally to the Argentine authorities that public statements on the points contained in Resolution XXVI, plus a commitment on peaceful settlement of disputes, would facilitate recognition by the United States."),
("Q44","frus1964-68v31","d206","there would be no problem of U.S. recognition of the new government because we would merely continue our relations with the President"),
("Q45","frus1964-68v31","d515","None of the Latin governments, except Venezuela, is disposed to insist on a commitment to hold elections as a pre-condition for recognition."),
("Q46","frus1969-76v21","d360","I told Huerta that we shall respond affirmatively to the Junta’s note, and expect to do so within the next few days."),
("Q47","frus1977-80v24","d132","We do not repeat not want to legitimize the interruption of the process of democratic political development."),
("Q49","frus1961-63v10-12mSupp","d160","Problem of eventual recognition Honduras and restoration of normal relations including military and economic aid tied to earliest possible establishment or restoration of Honduran constitutional government."),
("Q50","frus1877","d222","In the present case it waits before recognizing General Diaz as the President of Mexico until it shall be assured that his election is approved by the Mexican people, and that his administration is possessed of stability to endure and of disposition to comply with the rules of international comity and the obligations of treaties."),
("Q51","frus1878","d344","the Government of the United States before recognizing General Diaz as the President of Mexico waited to be assured that his administration was approved by the Mexican people, and was possessed of due stability and animated by a disposition to comply with the rules of international comity and the obligations of treaties"),
("Q52","frus1961-63v12","d427","In taking this public position we hoped to demonstrate to the hemisphere our firm support of democratic, constitutional process and to provide a deterrent to potential military coups against democratic, constitutional regimes elsewhere in the hemisphere."),
("Q53","frus1913","d1064","justified both Governments in withholding their recognition of the Huerta Government"),
("Q48","frus1977-80v15","d276","recognition as such does not arise in our international practice. U.S. practice now (in a kind of Estrada doctrine) is to recognize nations, not governments. We simply continue relations when a new government comes in."),
]
if __name__=="__main__":
    import sqlite3
    c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
    ok=0
    for qid,v,d,t in Q:
        b=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
        raw=t in b; col=t in ' '.join(b.split())
        print(qid,v,d,'RAW' if raw else '-','COLLAPSED' if col else '-', '' if raw else 'FAIL')
        ok+=1 if raw else 0
    print('verified raw',ok,'of',len(Q))
