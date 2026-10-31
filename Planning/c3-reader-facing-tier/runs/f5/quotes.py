# quotes.py: quotations used in overview/collection; each is verified as a substring of the whole document text (whitespace-collapsed)
import re,json,sys
Q=[
("frus1948v07","d567","If the United States is to win and retain moral leadership it must continue to discuss domestic conditions in the United States."),
("frus1948v07","d567","The Department considers the USIS newsletter to be the most effective method for reaching the influential middle group of educated Chinese"),
("frus1949v08","d499","we should immediately and substantially expand USIS activities in all Southeast Asian countries."),
("frus1949v07p2","d386","A considerably expanded information program both in Communist and non-Communist areas of Asia is called for, both to demonstrate our understanding and sympathy for the nationalist aspirations of the Asian peoples and to expose the menace to these aspirations created by Soviet imperialism."),
("frus1950v06","d50","Comparatively few nationals understand the current policies of the United States or the history and tradition of this country."),
("frus1952-54v13p1","d116","All factors recited must be viewed as effective though degree cannot be accurately measured."),
("frus1952-54v12p2","d251","which is more affected by our actions than our words and which is hostile to propaganda from any source, especially non-Asian."),
("frus1952-54v12p2","d251","2.5 percent may be opposed to United States aims, 1.5 percent favorable, and 96 percent “unsure”"),
("frus1952-54v12p2","d352","widespread use in Philippines and elsewhere of slogan “Asia for Asians” would be most unfortunate."),
("frus1952-54v12p2","d359","During FY 1954 these services were reduced by approximately 65% because of lack of funds."),
("frus1955-57v09","d190","USIA concentrated on activities to strengthen the resolution of U.S. allies, orient Asian neutralists toward the U.S., and counter Communist attempts to soften Asian resistance to varied forms of penetration."),
("frus1955-57v22","d447","a fear of placing the U.S. in the position of appearing to support colonialism."),
("frus1955-57v22","d484","The USIA program emphasizes comprehensive anti-Communist indoctrination throughout Thailand."),
("frus1958-60v15","d548","U.S. informational, cultural and educational activities in Thailand are conducted against the background of difficulties of communication and lack of adequate media of expression common to most underdeveloped Asian countries."),
("frus1961-63v01","d49","We are in the process of cranking up a major propaganda campaign on Viet Cong insurgency in VietNam."),
("frus1961-63v02","d16","the image of the GVN in the world press can be no better than the face the GVN presents to the public"),
("frus1961-63v02","d197","Replies to my superficial enquiries have been unanimous that the content of GVN propaganda is poor."),
("frus1961-63v02","d197","Does anyone have a really hard reading on how well GVN propaganda is working in the rural areas?"),
("frus1961-63v04","d81","With Orientals in general and notably with the Ngo Dinhs, capitulation is virtually impossible"),
("frus1964-68v01","d122","the weakest part of the war operation, both on our part and that of the Government of South Viet-Nam, is in the field of information and psychological warfare."),
("frus1964-68v01","d122","I was informed that the program is a failure in several provinces because of the lack of small bits of money to pay for such things as the running of a projector, or paper on which to print leaflets."),
("frus1964-68v02","d160","efforts to develop among the South Vietnamese people a sense of national unity and a determination to fight off Communist aggression, have not progressed to my satisfaction."),
("frus1917-72PubDipv07","d32","Vietnamese peasants are, in the main, going to be persuaded by other Vietnamese."),
("frus1917-72PubDipv07","d32","The number one problem in Vietnam is motivation."),
("frus1917-72PubDipv07","d85","I think it came as a surprise to most Americans that there is an unfortunately large amount of anti-Americanism under the surface in Viet-Nam."),
("frus1964-68v26","d106","We shall soon have nothing worthwhile left in the way of an information operation."),
("frus1964-68v27","d386","The Thai Government has not given proper attention to the need for a national information program designed to gain popular support."),
("frus1917-72PubDipv08","d31","Asians are, to varying degrees, America watchers."),
("frus1917-72PubDipv08","d31","PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations (security treaty, Okinawa, Korean military modernization, trade restrictions) than on developments within the US."),
("frus1917-72PubDipv08","d31","Many PAOs reported uncertainty as to the direction of US foreign policy and especially the strength of US commitments in Asia."),
("frus1917-72PubDipv08","d99","The President’s concept of partnership suggests that the U.S. will have to lower its voice."),
("frus1917-72PubDipv08","d149","The predominant mood is apolitical, seeking to be neutral, and concerned with economic and trade problems rather than strong ideological convictions."),
("frus1969-76v19p2","d67","public opinion surveys and other assessments of Japanese attitudes have tended to confirm the seriousness of these strains."),
("frus1969-76v38p2","d105","During this waiting period, programs on U.S. security relations in Asia lack credibility and may in fact do damage to our relations."),
("frus1969-76v38p2","d105","contrast between USG words and deeds re Indochina are not lost on the Burmese."),
("frus1977-80v22","d104","Rather than being reassured, the ASEAN countries and Japan interpreted our apparent unwillingness to come to grips with the “new realities” as another indication that the United States, after twenty years of exaggerating the extent of its interests in Southeast Asia, might now decide it had no interest there at all."),
("frus1977-80v30","d79","shoring up the confidence of East Asians in America’s long-term staying power and positive involvement in the area is real and necessary."),
("frus1949v07p2","d127","Our insistence that our way is right and the Japanese way is wrong does not make sense to many Japanese who detect a latent ignorance and lack of understanding of the Oriental in our endeavors to impose American methods and way of life"),
("frus1964-68v01","d177","Increased Voice of America broadcasting into North Viet-Nam and made arrangements for a broad expansion of VOA broadcasts in Vietnamese in early July."),
]
def norm(s): return re.sub(r'\s+',' ',s).strip()
if __name__=="__main__":
    bad=0
    for v,d,q in Q:
        t=norm(open(f"/Users/jbotts/frus-analysis/c3f/runs/f5/docs/{v}__{d}.txt").read())
        ok=norm(q) in t
        print("OK " if ok else "MISS", v+"/"+d, q[:70])
        bad+= (not ok)
    print("quotes",len(Q),"missing",bad)
