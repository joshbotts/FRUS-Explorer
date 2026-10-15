# Retrieval evaluation — the owner-query sitting (W-17 session 3 / W-9 step 2)

Two routes over the same corpus, 25 owner-written queries, top 10 each.
**Lexical** is the app's own search (the rendered MATCH expression is shown — what
actually executed). **Semantic** is the shipped funnel (Hamming → int8 rerank) with the
query embedded by the SHA-pinned GGUF (`embeddinggemma-2-Q8_0`, `2188ac1deca4…`), primary
prompt = the model's retrieval query template; the two other prompt variants appear as
id lists with overlap counts, so this sitting also settles the prompt question.
`CSUserQuery` (W-9 step 1) is not built yet and joins this report when it is.

**How to judge — one test for every row:** *would you open this document while pursuing
this question?* Mark `relevant` in `verdicts.csv` as **1** (yes — it advances the
question, is the item itself, or is proximity you would genuinely follow: an April 1971
Dacca telegram IS a 1 for "blood telegram"), **0** (you can already tell it would waste
your time — including the confidently wrong), or **blank** (the row's evidence
underdetermines it; blank describes the report, not the document, and is excluded from
the denominator rather than counted against either route). Don't reserve 1 for a
known item — near-misses score by the same test, and the did-it-find-the-thing hit is
computed separately from the known documents' identities. The null control
("Space aliens") has no 1 to give; what matters there is which route's junk would have
fooled a rushed reader. Try not to look at the score column while judging.

Snippets are **prose-first**: the body's opening echo of the header, source note,
dateline, and despatch serial is stripped, so the quoted text is evidence the row has
not already shown you.

---

## Q1. How did U.S. diplomats engage with host governments about the Emancipation Proclamation?

### Lexical — `"how" AND "did" AND "u.s." AND "diplomats" AND "engage" AND "with" AND "host" AND "governments" AND "about" AND "the" AND "emancipation" AND "proclamation?"`

1. **No. 23. Statement of Charles T. Gulick.**  
   `frus1894app2/d306` · score -7.2816  
   > Col. J. H. Blount, United States Commissioner, etc.: Dear Sir: I send you by bearer a very hastily prepared sketch of some features of Hawaiian History with our present condition in view. Time has not permitted of as careful an arrangement and comparison of facts and analysis of motives as I could…

### Semantic (query prompt)

1. **Mr. Adams to Mr. Seward.** — Legation of the United States. London, January 16, 1863.  
   `frus1863p1/d33` · score 0.8264  
   > Sir: I have this moment received a large deputation of the executive committee of the Emancipation Society, who have, through their president, presented to me a series of resolutions adopted by them, which I am requested to transmit to the President of the United States. Some remarks were made by…
2. **Mr. Adams to Mr. Seward.** — Legation of the United States, London, July 11, 1862.  
   `frus1862/d105` · score 0.8098  
   > That there has been more or less of communication between the great powers on the subject of the present state of America I do not doubt. As yet it has not probably run into any distinct form of action, but rather portends consultation to bring it to that. The interests of the different parties…
3. **Mr. Motley to Mr. Seward.** — Legation of the United States, Vienna, November —, 1861.  
   `frus1862/d455` · score 0.8085  
   > Sir: I have the honor to acknowledge the receipt of your despatches Nos. 1 to 8. Copies of Nos. 2, 5, and 6, relating to my predecessor, Mr. Jones, and commending his management of the affairs of the legation, were immediately forwarded to that gentleman. I am happy to bear my testimony, also, to…
4. **Mr. Fogg to Mr. Seward.** — United States Legation, Berne, January 24, 1863.  
   `frus1863p2/d555` · score 0.8060  
   > Sir: Your circular of January 3, transmitting the President’s proclamation declaring slavery no longer to exist in the insurrectionary States and districts of the United States, is received. Permit me, without discussing the military efficiency of the measure, to express the opinion that this act,…
5. **Mr. Adams to Mr. Seward.** — Legation of the United States, London, February 5, 1863.  
   `frus1863p1/d73` · score 0.8048  
   > Sir: I have to acknowledge the reception of despatches from the department, numbered from 449 to 455, inclusive. Also printed circular (No. 30) of the 24th of December last. I shall endeavor to attend to the various subjects to which they refer as promptly as possible. Since the date of my last…
6. **Mr. Bigelow to Mr. Seward** — Legation of the United States, Paris, November 24, 1865.  
   `frus1865p3/d415` · score 0.8041  
   > Sir: I have the honor to acknowledge the receipt of your instruction No. 296, covering the opinion of Mr. Attorney General Speed, in reference to certain decrees relating to emigration which have recently been promulgated from the city of Mexico, and to enclose a copy of a communication addressed…
7. **Mr. Bigelow to Mr. Seward** — Legation of the United States, Paris, January 10, 1866.  
   `frus1866p1/d250` · score 0.8015  
   > Sir: I deemed the proclamation of the 18th of December, announcing the termination of slavery in the United States, marked an event of such importance, in the social and political history of the world, as to justify me in bringing it formally to the notice of the Emperor’s government. I accordingly…
8. **Mr. Bigelow to Mr. Seward** — Legation of the United States, Paris, November 24, 1865.  
   `frus1865p3/d472` · score 0.8011  
   > Sir: I have the honor to acknowledge the receipt of your instruction No. 296, covering the opinion of Mr. Attorney General Speed in reference to certain decrees relating to emigration which have recently been promulgated from the city of Mexico, and to enclose a copy of a communication addressed by…
9. **Mr. Bigelow to Mr. Seward** — Legation of the United States, Paris, February 7, 1866.  
   `frus1866p1/d254` · score 0.8010  
   > Sir: Recalling my despatch No. 241, enclosing a communication made by me to M. Guizot and the Duke de Broglie, with the President’s proclamation announcing the abolition of slavery in the United States, I have the honor to enclose a copy and translation of a reply to a similar communication, made…
10. **Mr. Seward to Mr. Pike.** — Department of State, Washington, March 9, 1863.  
   `frus1863p2/d215` · score 0.8008  
   > Sir: By direction of the President, I transmit to you a copy of concurrent resolutions of the Congress of the United States concerning foreign intervention in the existing rebellion. In compliance with a request made by that body, you are instructed to make the resolutions known to the government…

### PRF — centroid of the lexical top-5, no encoder (1 seed)

1. **No. 23. Statement of Charles T. Gulick.**  
   `frus1894app2/d306` · score 1.0012  
   > Col. J. H. Blount, United States Commissioner, etc.: Dear Sir: I send you by bearer a very hastily prepared sketch of some features of Hawaiian History with our present condition in view. Time has not permitted of as careful an arrangement and comparison of facts and analysis of motives as I could…
2. **No. 17. Mr. Blount to Mr. Gresham.** — Honolulu, H. I., July 17, 1893.  
   `frus1894app2/d265` · score 0.9782  
   > Sir: On the 11thof March, 1893, I was appointed by the President of the United States as special commissioner to the Hawaiian Islands. At the same time the following instructions were given to me by you: Department of State, Washington, March 11, 1893. Sir: The situation created in the Hawaiian…
3. **No. 41. Statement of the Hawaiian Patriotic League.** — [undated.]  
   `frus1894app2/d324` · score 0.9692  
   > memorial on the hawaiian crisis I.— Generative causes. The strongest argument of the men who, for personal aims, crave for the overthrow of the Hawaiian national monarchy, is that the natives are incapable of self-government, and to this flimsy and false argument the United States minister…
4. **No. 5. Statement of Volney V. Ashford.** — Honolulu, Hawaiian Islands, March 8, 1893.  
   `frus1894app2/d288` · score 0.9662  
   > Hon. James H. Blount, United States Ambassador to Hawaii: Sir: You ask me to put in writing the substance of my information to you in re Hawaiian affairs on the 3d instant. In order to fully understand the situation, it seems necessary to refer to political developments which led to the conditions…
5. **No. 2. Mr. Stevens to Mr. Foster.** — United States Legation, Honolulu, January 18, 1893. (Received February 3.)  
   `frus1894app2/d73` · score 0.9661  
   > Sir: In my 73 of November 8 I gave full information of the surrender of the Queen to the wishes of the legislature by the formation of a ministry composed of men of intelligence and wealth possessing the entire confidence of the business men and the more responsible citizens of the country. But…
6. **Mr. Stevens to Mr. Foster.** — United States Legation, Honolulu, January 18, 1893.  
   `frus1894app2/d192` · score 0.9645  
   > Sir: In my 73, of November 8, I gave full information of the surrender of the Queen to the wishes of the Legislature by the formation of a ministry composed of men of intelligence and wealth, possessing the entire confidence of the business men and the more responsible citizens of the country. But…
7. **No. 60. Statement of C. B. Wilson.**  
   `frus1894app2/d344` · score 0.9639  
   > facts in relation to the revolution of 1893, and the causes which led to it. Two years ago the nation was preparing its decorations to joyously celebrate and welcome the home-coming of His Majesty King Kalakaua, who was away on a visit of business to the United States, endeavoring to benefit his…
8. **No. 6. Mr. Blount to Mr. Gresham** — Honolulu, Hawaiian Islands, April 26, 1893.  
   `frus1894app2/d254` · score 0.9622  
   > Sir: On the 7th instant the Alameda reached this place. Among its passengers were Dr. William Shaw Bowen and Mr. Harold M. Sewall The San Francisco papers announced that they had refused to say that they were not joint commissioners with myself to Honolulu, The former represented himself to me as a…
9. **No. 1. Statement of W. D. Alexander.** — [undated.]  
   `frus1894app2/d284` · score 0.9615  
   > a statement of facts relating to politics during kalakaua’s reign. It is true that the germs of many of the evils of Kalakaua’s reign may be traced to the reign of Kamehameha V. The reactionary policy of that monarch is well known. Under him the “recrudescence” of heathenism commenced, as evinced…
10. **No. 54. Dr. Trousseau’s statements.** — May 16, 1893.  
   `frus1894app2/d337` · score 0.9601  
   > Hon. J. H. Blount: Sir: As you are not acquainted with me, I take the liberty of stating who I am. Born in Paris, France, in 1833, I am now a little over 60 years of age. I graduated in Paris as a physician in 1858. If you ask who is Trousseau, you will be probably answered, why, he is one of the…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 3/10.*
*document variant:* frus1863p1/d33, frus1862/d455, frus1862/d105, frus1867p2/d96, frus1862/d462, frus1863p2/d215, frus1863p2/d555, frus1863p1/d73, frus1864p1/d64, frus1873p2v3/d30
*bare variant:* frus1863p1/d33, frus1862/d572, frus1872p2v1/d2, frus1862/d455, frus1866p1/d251, frus1862/d510, frus1867p2/d96, frus1863p1/d137, frus1864p1/d64, frus1863p2/d555

---

## Q2. How did immigration affect U.S. diplomacy with China in the 1880s?

### Lexical — `"how" AND "did" AND "immigration" AND "affect" AND "u.s." AND "diplomacy" AND "with" AND "china" AND "in" AND "the" AND "1880s?"`

1. **No. 23. Statement of Charles T. Gulick.**  
   `frus1894app2/d306` · score -4.2123  
   > Col. J. H. Blount, United States Commissioner, etc.: Dear Sir: I send you by bearer a very hastily prepared sketch of some features of Hawaiian History with our present condition in view. Time has not permitted of as careful an arrangement and comparison of facts and analysis of motives as I could…

### Semantic (query prompt)

1. **Mr. Wu to Mr. Hay.** — Chinese Legation, Washington, December 10, 1901.  
   `frus1901/d85` · score 0.8426  
   > Sir: In view of the fact that the law of the Congress of the United States which went into force May 6, 1882, based upon the treaty of 1880 between China and the United States, regulating Chinese immigration, and which was reenacted May 5, 1892, for ten years, is about to expire by limitation, and…
2. **Mr. Chang Yen Hoon to Mr. Bayard.** — Chinese Legation, Washington, January 26, 1889. (Received January 26.)  
   `frus1889/d87` · score 0.8288  
   > Sir: I have the honor to inform you that I have carefully examined the act of Congress approved October 1, 1888, in relation to the prohibition of the coming of Chinese laborers into the United States, copies of which you kindly sent me with your note of October 18 last, and I beg respectfully to…
3. **No. 126. The commission to Mr. Evarts.** — United States Commission, Peking, October 11, 1880.  
   `frus1881/d126` · score 0.8260  
   > Sir: Recurring to our dispatch No. 4, of the 27th ultimo, in which we reported our arrival here, and the appointment by the Government of China of two commissioners plenipotentiary, we have now the honor to inform you that upon the 1st instant we met the two commissioners at the foreign office by…
4. **No. 239. Mr. Rives to Mr. Denby.** — Department of State, Washington, October 10, 1888.  
   `frus1888p1/d239` · score 0.8245  
   > Sir: I transmit herewith for your information copies of the recently approved Chinese exclusion act and of the President’s message upon the subject; also of Senate Ex. Doc. O, Fiftieth Congress, For Senate Ex. Doc. O, Fiftieth Congress (convention for restricting Chinese immigration), see Document…
5. **Mr. Denby to Mr. Blaine.** — Legation of the United States, Peking, July 25, 1890. (Received September 22.)  
   `frus1890/d140` · score 0.8212  
   > Sir: I have the honor to inclose a translation of a communication bearing date June 16, 1890, lately sent to me by the Tsung-li yamên; also a translation of another communication bearing date June 17, 1890; also copies of my replies to these two communications. The delay in forwarding these papers…
6. **Mr. Denby to Mr. Foster.** — Legation of the United States, Peking, November 29, 1892. (Received January 14, 1893.)  
   `frus1892/d100` · score 0.8204  
   > Sir: In my dispatch No. 1569, of the 18th August last, I transmitted a copy of a translation of a communication received by me from the foreign office, relating to the recent exclusion acts of the United States against Chinese laborers, together with a copy of my reply thereto. I now inclose a…
7. **Mr. Wharton to Mr. Tsui.** — Department of State, Washington, December 10, 1892.  
   `frus1892/d115` · score 0.8203  
   > Sir: I have the honor to acknowledge the reception of your two notes of the respective dates of November 7 and November 11, 1892, concerning the recent legislation of the Congress of the United States “in respect to Chinese subjects” in this country. In the former of these two notes you refer to…
8. **Mr. Tsui to Mr. Blaine.** — Chinese Legation, Washington, March 26, 1890. (Received March 28.)  
   `frus1890/d160` · score 0.8199  
   > Sir: Under date of the 26th of January, 1889, my predecessor submitted some considerations to your Department upon the act of your Congress of October 1, 1888. Mr. Secretary Bayard, on the 2d of February, 1889, referred to that note as containing “highly important matters” and promised to “make…
9. **No. 236. Mr. Denby to Mr. Bayard.** — Legation of the United States, Peking, September 17, 1888. (Received November 2.)  
   `frus1888p1/d236` · score 0.8162  
   > Sir: I have the honor to report that some days ago five ministers of the Yamên, to wit, Marquis Tseng, San Yü Wen, Hsu Yung-I, Liao Shou-Heng, and Hsi Chén sent cards asking for an interview to-day. I, of course, assented. Four came to the legation at 3 o’clock and remained until after 5. They…
10. **Mr. Tsui to Mr. Foster.** — Chinese Legation, Washington, D. C., Nov. 11, 1892. (Received November 12.)  
   `frus1892/d114` · score 0.8134  
   > Sir: I have the honor to transmit herewith for your consideration and for the consideration of his excellency, the President of the United States, a communication of the foreign office at Peking, and addressed to Hon. Charles Denby, United States minister, in reply to a note from him dated July 4,…

### PRF — centroid of the lexical top-5, no encoder (1 seed)

1. **No. 23. Statement of Charles T. Gulick.**  
   `frus1894app2/d306` · score 1.0012  
   > Col. J. H. Blount, United States Commissioner, etc.: Dear Sir: I send you by bearer a very hastily prepared sketch of some features of Hawaiian History with our present condition in view. Time has not permitted of as careful an arrangement and comparison of facts and analysis of motives as I could…
2. **No. 17. Mr. Blount to Mr. Gresham.** — Honolulu, H. I., July 17, 1893.  
   `frus1894app2/d265` · score 0.9782  
   > Sir: On the 11thof March, 1893, I was appointed by the President of the United States as special commissioner to the Hawaiian Islands. At the same time the following instructions were given to me by you: Department of State, Washington, March 11, 1893. Sir: The situation created in the Hawaiian…
3. **No. 41. Statement of the Hawaiian Patriotic League.** — [undated.]  
   `frus1894app2/d324` · score 0.9692  
   > memorial on the hawaiian crisis I.— Generative causes. The strongest argument of the men who, for personal aims, crave for the overthrow of the Hawaiian national monarchy, is that the natives are incapable of self-government, and to this flimsy and false argument the United States minister…
4. **No. 5. Statement of Volney V. Ashford.** — Honolulu, Hawaiian Islands, March 8, 1893.  
   `frus1894app2/d288` · score 0.9662  
   > Hon. James H. Blount, United States Ambassador to Hawaii: Sir: You ask me to put in writing the substance of my information to you in re Hawaiian affairs on the 3d instant. In order to fully understand the situation, it seems necessary to refer to political developments which led to the conditions…
5. **No. 2. Mr. Stevens to Mr. Foster.** — United States Legation, Honolulu, January 18, 1893. (Received February 3.)  
   `frus1894app2/d73` · score 0.9661  
   > Sir: In my 73 of November 8 I gave full information of the surrender of the Queen to the wishes of the legislature by the formation of a ministry composed of men of intelligence and wealth possessing the entire confidence of the business men and the more responsible citizens of the country. But…
6. **Mr. Stevens to Mr. Foster.** — United States Legation, Honolulu, January 18, 1893.  
   `frus1894app2/d192` · score 0.9645  
   > Sir: In my 73, of November 8, I gave full information of the surrender of the Queen to the wishes of the Legislature by the formation of a ministry composed of men of intelligence and wealth, possessing the entire confidence of the business men and the more responsible citizens of the country. But…
7. **No. 60. Statement of C. B. Wilson.**  
   `frus1894app2/d344` · score 0.9639  
   > facts in relation to the revolution of 1893, and the causes which led to it. Two years ago the nation was preparing its decorations to joyously celebrate and welcome the home-coming of His Majesty King Kalakaua, who was away on a visit of business to the United States, endeavoring to benefit his…
8. **No. 6. Mr. Blount to Mr. Gresham** — Honolulu, Hawaiian Islands, April 26, 1893.  
   `frus1894app2/d254` · score 0.9622  
   > Sir: On the 7th instant the Alameda reached this place. Among its passengers were Dr. William Shaw Bowen and Mr. Harold M. Sewall The San Francisco papers announced that they had refused to say that they were not joint commissioners with myself to Honolulu, The former represented himself to me as a…
9. **No. 1. Statement of W. D. Alexander.** — [undated.]  
   `frus1894app2/d284` · score 0.9615  
   > a statement of facts relating to politics during kalakaua’s reign. It is true that the germs of many of the evils of Kalakaua’s reign may be traced to the reign of Kamehameha V. The reactionary policy of that monarch is well known. Under him the “recrudescence” of heathenism commenced, as evinced…
10. **No. 54. Dr. Trousseau’s statements.** — May 16, 1893.  
   `frus1894app2/d337` · score 0.9601  
   > Hon. J. H. Blount: Sir: As you are not acquainted with me, I take the liberty of stating who I am. Born in Paris, France, in 1833, I am now a little over 60 years of age. I graduated in Paris as a physician in 1858. If you ask who is Trousseau, you will be probably answered, why, he is one of the…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 9/10.*
*document variant:* frus1901/d85, frus1881/d126, frus1890/d160, frus1889/d87, frus1888p1/d239, frus1892/d115, frus1892/d100, frus1876/d44, frus1890/d140, frus1881/d127
*bare variant:* frus1901/d85, frus1888p1/d239, frus1889/d87, frus1881/d126, frus1890/d140, frus1890/d160, frus1888p1/d236, frus1892/d100, frus1892/d96, frus1892/d115

---

## Q3. How did U.S. diplomats think about Cuban independence before 1898?

### Lexical — `"how" AND "did" AND "u.s." AND "diplomats" AND "think" AND "about" AND "cuban" AND "independence" AND "before"`

1. **18. Policy Paper Prepared in the Department of State** — Washington, undated  
   `frus1977-80v23/d18` · score -20.7909  
   > How To Proceed Next With Cuba We have completed the steps authorized by Presidential Directive/NSC–6, which called for a review once those steps had been taken. See Document 9. PRC review of the options available on Cuba in the months ahead is also timely now in light of the opening of Interests…
2. **221. Memorandum of Conversation** — New York, October 4, 1982, 3–7:30 p.m.  
   `frus1981-88v03/d221` · score -18.8979  
   > SUBJECT Meeting Between Secretary Shultz and Soviet Foreign Minister Gromyko PARTICIPANTS U.S. Secretary of State George P. Shultz Undersecretary for Political Affairs Lawrence S. Eagleburger Ambassador to the USSR Arthur A. Hartman Assistant Secretary of State for European Affairs Richart Burt…
3. **474. Memorandum of Discussion at the 436th Meeting of the National Security Council, Washington, March 10, 1960** — Washington, March 10, 1960  
   `frus1958-60v06/d474` · score -17.6324  
   > Mr. Dulles then summarized the situation in Cuba. He said that the U.S. Embassy Country Team had reached the conclusion that there was no hope that the U.S. would ever be able to establish satisfactory relations with a Cuban Government dominated by Castro and his associates. The Cuban charges in…
4. **68. Memorandum of Conversation** — Washington, August 5, 1977, 10:30 a.m.–noon  
   `frus1977-80v16/d68` · score -17.0697  
   > SUBJECT Summary of the President’s Meeting II with President Julius Nyerere of Tanzania PARTICIPANTS United States The President The Vice President Dr. Zbigniew Brzezinski Acting Secretary of State Warren Christopher Assistant Secretary of State for African Affairs Richard Moose Ambassador James…
5. **382. Memorandum of Conversation** — Washington, February 12, 1976, 4:15–4:45 p.m.  
   `frus1969-76ve11p1/d382` · score -16.9836  
   > Summary: Kissinger and Wills discussed Guyana’s votes in the United Nations, Angola, and bilateral relations. Kissinger told Wills that the United States had no interest in confrontation with Guyana, and Wills assured Kissinger that Guyana would not become a Soviet or Cuban base. Source: National…
6. **152. Memorandum of Conversation** — Washington, August 18, 1976, 5 p.m.  
   `frus1969-76v18/d152` · score -16.7466  
   > PARTICIPANTS Ambassador Huang Chen, Chief, PRC Liaison Office Mr. Chien Ta-yung, Counselor, PRC Liaison Office Ms. Shen Jo-yun, Interpreter, PRC Liaison Office Secretary Kissinger Arthur W. Hummel, Jr., Assistant Secretary, EA Winston Lord, Director, S/P William H. Gleysteen, National Security…
7. **342. Memorandum of a Conversation Between the Ambassador in Cuba (Bonsal) and Minister of State Roa, Havana, July 23, 1959** — Havana, July 23, 1959  
   `frus1958-60v06/d342` · score -16.7289  
   > I called on Dr. Roa by arrangement. In the course of the preliminary exchange of courtesies, he was good enough to say that he had heard on all sides favorable expressions about my mission here, and he gave me a friendly personal message from Fidel Castro, with whom he had just been talking. We…
8. **187. Memorandum of Conversation** — New York, June 19, 1982, 9:30 a.m.–1:40 p.m.  
   `frus1981-88v03/d187` · score -16.4093  
   > SUBJECT Private Meeting Between Secretary Haig and Minister Gromyko PARTICIPANTS US Secretary of State Alexander M. Haig Cyril Muromcew, Interpreter USSR Foreign Minister Andrey A. Gromyko Victor Sukhodrev, MFA, USSR Foreign Minister Gromyko suggested to Secretary Haig that they continue where they…
9. **No. 713. Admiral Polo de Bernabé to Mr. Fish.** — Legation of Spain, Washington, December 10, 1873,  
   `frus1874/d715` · score -16.3430  
   > As a result of the protocol signed at Washington on the 29th of November last, relative to the case of the Virginius, the undersigned, envoy extraordinary and minister plenipotentiary of Spain, has the honor to transmit herewith to the Secretary of State of the United States various authenticated…
10. **26. Memorandum of a Conversation, Department of State, Washington, June 30, 1958** — Washington, June 30, 1958  
   `frus1958-60v13/d26` · score -16.3089  
   > SUBJECT U.S.-Israel Relations and the Situation in the Near East PARTICIPANTS Mr. Abba Eban, Ambassador of Israel Mr. Ya’acov Herzog, Minister, Embassy of Israel The Secretary NE — Stuart W. Rockwell NE — Donald C. Bergus Mr. Eban reported that he would leave Washington in a week’s time for two…

### Semantic (query prompt)

1. **No. 550. Mr. Fish to Mr. Cushing.** — Department of State, Washington, February 6, 1874.  
   `frus1874/d552` · score 0.8268  
   > Sir: Whatever general instructions you may need at the present time for your guidance in representing this Government at Madrid have reference entirely to the actual state of the island of Cuba and its relation to the United States as well as to Spain. It is now more than five years since an…
2. **Mr. Woodford to the President.** — Legation of the United States, Madrid, March 9, 1898.  
   `frus1898/d544` · score 0.8206  
   > Dear Mr. President: Knowing how pressed you are for time, I fear you may find my letters somewhat prolix, but I know that you must wish all the light I can give you. * * * On Monday evening, March 7, Señor ________, a well-known Spanish merchant, gave us a family dinner, at which were present his…
3. **Extracts from the Remarks of the Cuban Ambassador (Torriente) on the Occasion of His Reception by President Coolidge, December 13, 1923** — December 13, 1923  
   `frus1923v01/d679` · score 0.8192  
   > Mr. President: . . . . . . . . . . . . . . In entering upon the duties of my office by addressing Your Excellency in the name of the President of Cuba and, therefore, of my Nation, I cannot but recall the days, which are already somewhat distant, during which the Cubans struggled bravely to obtain…
4. **Mr. Squiers to Mr. Hay.** — Legation of the United States, Habana, November 21, 1902.  
   `frus1902/d313` · score 0.8173  
   > Sir: For the information of the Department I have the honor to inclose herewith a translation of a report made to the constitutional convention by a committee appointed therefrom to report upon the relations which, in the judgment of the convention, should exist between Cuba and the United States.…
5. **Mr. Woodford to Mr. Sherman.** — Legation of the United States, Madrid, February 9, 1898.  
   `frus1898/d531` · score 0.8165  
   > Sir: On the afternoon of February 3 instant I received from the Spanish minister of foreign affairs a note, dated February 1 instant, being the official reply to my note to the Spanish Government, dated December 20, 1897. The translation was begun at once, but both translation and copying have been…
6. **Señor Polo de Bernabé to Mr. Sherman.** — Legation of Spain, Washington, April 1, 1898.  
   `frus1898/d586` · score 0.8138  
   > Mr. Secretary: His excellency the Governor-General of the Island of Cuba requests me to communicate to your excellency, in order that it be transmitted to the President of the United States of America, the following telegram: The colonial government of Cuba desires through your excellency to make…
7. **The American Minister to the Secretary of State.** — American Legation, Habana, February 12, 1912.  
   `frus1912/d405` · score 0.8138  
   > Sir: Referring to previous correspondence [etc.] I have the honor to enclose herewith copy and translation of a long personal note on the subject, which I received yesterday from Sr. Sanguily. I also enclose copy of my reply of today’s date. * * * In case the Department desires me to comply with…
8. **Mr. Woodford to Mr. Sherman.** — Legation of the United States, Madrid, March 25, 1898.  
   `frus1898/d557` · score 0.8108  
   > Sir: Since the receipt of the Spanish note dated February 1, 1898, I have waited for suitable opportunity to have full and frank discussion with the Spanish minister for foreign affairs concerning the real condition of affairs in Cuba and the duty of the United States in regard thereto. After an…
9. **Mr. Woodford to the President.** — Legation of the United States, Madrid, March 17, 1898.  
   `frus1898/d545` · score 0.8108  
   > Dear Mr. President: In my No. 41, of March 9, I told you of Señor ________ call that afternoon and of Mr. ________ call that evening. On Saturday, March 12, Señor ________ came again; said that he had seen Minister Moret again on the 11th; that it was clear that autonomy would surely succeed if the…
10. **[Untitled]**  
   `frus1902/d273` · score 0.8094  
   > To the Congress of the United States: I commend to the Congress timely consideration of measures for maintaining diplomatic and consular representatives in Cuba and for carrying out the provisions of the act making appropriation for the support of the Army for the fiscal year ending June 30, 1902,…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **382. Memorandum of Conversation** — Washington, February 12, 1976, 4:15–4:45 p.m.  
   `frus1969-76ve11p1/d382` · score 0.9451  
   > Summary: Kissinger and Wills discussed Guyana’s votes in the United Nations, Angola, and bilateral relations. Kissinger told Wills that the United States had no interest in confrontation with Guyana, and Wills assured Kissinger that Guyana would not become a Soviet or Cuban base. Source: National…
2. **545. Memorandum of Discussion at the 450th Meeting of the National Security Council, Washington, July 7, 1960** — Washington, July 7, 1960  
   `frus1958-60v06/d545` · score 0.9402  
   > Turning next to the situation in Cuba, Mr. Dulles dealt first with the seizure by Cuba of the oil refineries. The Cuban Government seized the Texaco facilities on June 29 and the Esso and Shell facilities on July 1. Ambassador Bonsal delivered a note of protest to the Cuban Government on July 5.…
3. **206. Memorandum for the Record** — Washington, May 5, 1961.  
   `frus1961-63v10/d206` · score 0.9362  
   > SUBJ Debrief of NSC meeting, 5 May 61 [Here follows a brief summary of the discussion of Iran and Korea.] Cuba 7. Mr. Nitze then discussed his paper on Cuba. Document 202. It was asked whether or not anybody in the room believed that we should intervene militarily in Cuba now. I said perhaps not…
4. **536. Memorandum of a Conference, Department of State, Washington, June 27, 1960** — Washington, June 27, 1960  
   `frus1958-60v06/d536` · score 0.9348  
   > SUBJECT Questions Concerning the Program of Economic Pressures against Castro PARTICIPANTS: The White House Mr. Gordon Gray Mr. James S. Lay, Jr. Treasury Department Secretary Anderson Defense Department Secretary Gates State Department The Secretary Under Secretary Dillon A note on the source text…
5. **48. Memorandum of Conversation** — Beijing, August 23, 1977, 9:30–11:50 a.m.  
   `frus1977-80v13/d48` · score 0.9327  
   > SUBJECT Africa; Latin America; Normalization with other Countries; Human Rights; Non-Proliferation; ME; Yugoslavia; Normalization of US– PRC Relations PARTICIPANTS U.S. The Secretary Ambassador Woodcock Under Secretary Habib Assistant Secretary Holbrooke, EA William H. Gleysteen, Jr. Deputy…
6. **221. Memorandum of Conversation** — New York, October 4, 1982, 3–7:30 p.m.  
   `frus1981-88v03/d221` · score 0.9319  
   > SUBJECT Meeting Between Secretary Shultz and Soviet Foreign Minister Gromyko PARTICIPANTS U.S. Secretary of State George P. Shultz Undersecretary for Political Affairs Lawrence S. Eagleburger Ambassador to the USSR Arthur A. Hartman Assistant Secretary of State for European Affairs Richart Burt…
7. **138. Memorandum of Conversation** — Geneva, January 26, 1982, 2–7 p.m.  
   `frus1981-88v03/d138` · score 0.9304  
   > SUBJECT Haig - Gromyko Conversation PARTICIPANTS US Secretary of State Alexander M. Haig D. Arensburger, Interpreter USSR Foreign Minister Andrey A. Gromyko V. Sukhodrev, Interpreter INF and SALT Foreign Minister Gromyko did not know whether Secretary Haig had anything to add on the question of…
8. **423. Memorandum of Discussion at the 432d Meeting of the National Security Council, Washington, January 14, 1960, 9 a.m.** — Washington, January 14, 1960, 9 a.m.  
   `frus1958-60v06/d423` · score 0.9301  
   > Turning to Cuba, Mr. Dulles reported that Castro and Guevara were continuing their program of seizing lands and assets. Teams of Cuban diplomats were visiting the underdeveloped countries in an effort to organize a Conference of Hungry Nations. Cuban diplomats were interviewing Nasser in an effort…
9. **18. Policy Paper Prepared in the Department of State** — Washington, undated  
   `frus1977-80v23/d18` · score 0.9295  
   > How To Proceed Next With Cuba We have completed the steps authorized by Presidential Directive/NSC–6, which called for a review once those steps had been taken. See Document 9. PRC review of the options available on Cuba in the months ahead is also timely now in light of the opening of Interests…
10. **364. Memorandum From the Ambassador to Cuba (Bonsal) to the Assistant Secretary of State for Inter-American Affairs (Rubottom)** — Washington, September 1959. Although the source text bears the handwritten date “11/59”, it was probably prepared in late September 1959, and no earlier than September 25, during Bonsal’s visit to Washington.  
   `frus1958-60v06/d364` · score 0.9292  
   > SUBJECT Cuban-American Relations The purpose of this memorandum is to itemize current problems in Cuban-American relations and to define in the form of recommendations and of questions the policy aspects involved from our point of view. Basic to this approach is the belief that we should maintain…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 9/10.*
*document variant:* frus1874/d552, frus1898/d531, frus1912/d405, frus1898/d544, frus1902/d313, frus1958-60v06/d362, frus1923v01/d679, frus1898/d503, frus1898/d545, frus1898/d490
*bare variant:* frus1874/d552, frus1898/d544, frus1898/d531, frus1912/d405, frus1902/d313, frus1898/d545, frus1923v01/d679, frus1898/d557, frus1902/d273, frus1898/d503

---

## Q4. Which document related to the Anglo-Venezuelan boundary dispute expanded the Monroe Doctrine?
*known-item*

### Lexical — `"which" AND "document" AND "related" AND "to" AND "the" AND "anglo-venezuelan" AND "boundary" AND "dispute" AND "expanded" AND "the" AND "monroe" AND "doctrine?"`

*(no results)*

### Semantic (query prompt)

1. **Message of the President.**  
   `frus1895p1/d526` · score 0.8348  
   > To the Congress: In my annual message addressed to the Congress on the third instant I called attention to the pending boundary controversy between Great Britain and the Republic of Venezuela and recited the substance of a representation made by this Government to Her Britannic Majesty’s Government…
2. **Mr. Andrade to Mr. Gresham.** — Legation of Venezuela, Washington, March 31, 1894.  
   `frus1894/d820` · score 0.8181  
   > Sir: In our interview of the 8th of last January, the subject of which was the endless and vexed boundary controversy between Venezuela and Great Britain, your excellency expressed his wish that I should explain to him by writing certain especial points connected with it. This I have endeavored to…
3. **Mr. Olney to Mr. Bayard.** — Department of State, Washington, July 20, 1895.  
   `frus1895p1/d527` · score 0.8131  
   > His Excellency Thomas F. Bayard, Etc., etc., etc., London. Sir: I am directed by the President to communicate to you his views upon a subject to which he has given much anxious thought and respecting which he has not reached a conclusion without a lively sense of its great importance as well as of…
4. **Prominent facts relating to the boundary question between Venezuela and Great Britain.** — Legation of Venezuela.  
   `frus1894/d816` · score 0.8045  
   > The Republic of Venezuela inherited from Spain all the territories formerly known as Captaincy General of Venezuela. Guiana was a province thereof. It was bounded by the Atlantic Ocean on the east, and by the Amazon River on the south. A part of this territory had been invaded by the Dutch, during…
5. **The Secretary of State to various Senators.** — Department of State, Washington, January 22, 1912.  
   `frus1912/d1493` · score 0.8021  
   > My Dear Senator: I have ventured to send you copy of an address I recently made on “The Monroe Doctrine and some incidental obligations in the zone of the Caribbean.” I do so in the hope of increasing your interest in the Convention between the United States and Honduras, and even more especially…
6. **Lord Salisbury to Sir Julian Pauncefote.** — Foreign Office, November 26, 1895.  
   `frus1895p1/d530` · score 0.8003  
   > Sir, In my preceding despatch of to-day’s date I have replied only to the latter portion of Mr. Olney’s despatch of the 20th July last, which treats of the application of the Monroe doctrine to the question of the boundary dispute between Venezuela and the colony of British Guiana. But it seems…
7. **Lord Salisbury to Sir Julian Pauncefote.** — Foreign Office, November 26, 1895.  
   `frus1895p1/d529` · score 0.7987  
   > Sir, On the 7th August I transmitted to Lord Gough a copy of the despatch from Mr. Olney which Mr. Bayard had left with me that day, and of which he had read portions to me. I informed him at the time that it could not be answered until it had been carefully considered by the Law Officers of the…
8. **Mr. Haselton to Mr. Gresham.** — Legation of the United States, Caracas, January 15, 1895. (Received January 30.)  
   `frus1894/d825` · score 0.7976  
   > Sir: Under date of December 7 last the minister of foreign affairs of Venezuela transmitted to me a note with reference to the boundary question between this country and Great Britain. After an examination of former correspondence between the legation and the Department of State I have been led to…
9. **Mr. Gresham to Mr. Bayard.** — Department of State, Washington, July 13, 1894.  
   `frus1894/d243` · score 0.7908  
   > Sir: During your incumbency of the office of Secretary of State you became acquainted with a long pending controversy between Great Britain and Venezuela concerning the boundary between that Republic and British Guiana. The recourse to arbitration, first proposed in 1881, having been supported by…
10. **The Secretary of State to American Diplomatic Officers in Latin America** — Washington, February 28, 1929.  
   `frus1929v01/d522` · score 0.7846  
   > Sirs: The discussions in the United States Senate incident to its consideration of the Multilateral Peace Pact, Treaty for the Renunciation of War, signed at Paris, August 27, 1928, Foreign Relations, 1928, vol. i, p. 153. and the report of the Senate Committee on Foreign Affairs The General Pact…

### PRF — centroid of the lexical top-5, no encoder (0 seeds)

*(no seeds — PRF amplifies lexical search and cannot rescue a query it returned nothing for)*

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 10/10, bare: 9/10.*
*document variant:* frus1895p1/d526, frus1894/d820, frus1895p1/d527, frus1912/d1493, frus1894/d816, frus1895p1/d530, frus1895p1/d529, frus1894/d825, frus1894/d243, frus1929v01/d522
*bare variant:* frus1895p1/d526, frus1894/d820, frus1895p1/d527, frus1895p1/d530, frus1895p1/d529, frus1912/d1493, frus1894/d816, frus1894/d825, frus1908/d734, frus1894/d243

---

## Q5. Mexican Revolution

### Lexical — `"mexican" AND "revolution"`

1. **The Acting Secretary for Foreign Affairs of the Vásquez Gómez-Provisional Government to the Secretary of State.** — Palomas, Chihuahua, February 25, 1913.  
   `frus1913/d876` · score -13.7800  
   > Received March 6; communicated to the Ambassador March 17; filed March 21. [Translation.] Palomas, Chihuahua, February 25, 1913. To the Secretary of State of the United States of North America: The Provisional President of the Revolution of the United Mexican States has ordered me to inform your…
2. **The American Ambassador to the Secretary of State.** — American Embassy, Mexico, July 7, 1913.  
   `frus1913/d1231` · score -13.3885  
   > Sir: I have the honor to acknowledge the Department’s No. 1337, of June 21, 1913, in which I am directed to reopen with the British Minister and the Mexican Foreign Office the question of claims growing out of a successful revolution and those growing out of an unsuccessful one. While the…
3. **The Secretary of State to the Chargé in Mexico (Summerlin)** — Washington, October 9, 1919.  
   `frus1920v03/d281` · score -13.0296  
   > Sir: The Department acknowledges the receipt of your despatch No. 2406 dated September 17, 1919, Not printed. with which you forwarded the official text and translation of the Presidential Decree of August 30, 1919, See Foreign Relations, 1919, vol. ii, p. 640. modifying the Presidential Decree of…
4. **571. Memorandum of a Conversation, Department of State, Washington, August 3, 1960** — Washington, August 3, 1960  
   `frus1958-60v06/d571` · score -13.0113  
   > SUBJECT Proposed Offer of Good Offices to United States and Cuba PARTICIPANTS The Secretary of State Mexican Ambassador Antonio Carrillo Flores Assistant Secretary R. R. Rubottom, Jr. Dr. José Gallastegui, Private Secretary to the Mexican Foreign Minister Melville E. Osborne— CMA Mr. Rubottom…
5. **The Minister in Nicaragua (Eberhardt) to the Secretary of State** — Managua, December 31, 1926—10 p.m. [Received 10:40 p.m.]  
   `frus1927v03/d252` · score -12.8814  
   > A conference was held this morning in the Legation at the request of the Diaz Government. It was attended by the Minister for Foreign Affairs, the Minister of Finance, High Commissioner, Deputy Collector General of Customs and Manager of the National Bank. The Government representatives stated the…
6. **The Chargé in Nicaragua (Dennis) to the Secretary of State** — U. S. S. “Denver,” October 19, 1926—4 p.m. [Received October 21—11:30 a.m.]  
   `frus1926v02/d498` · score -12.8307  
   > The conference is now in a deadlock over formula for “reestablishment of peace on basis of constitutionality and the treaty of Washington.” Conference on Central American Affairs, p. 287. A Conservative executive and government with participation for the Liberals is insisted upon by the…
7. **The Brazilian Minister to Mexico to the Secretary of State.** — Mexico City, March 9, 1915—11 p.m.  
   `frus1915/d839` · score -12.7931  
   > I have been requested by a committee of American citizens to transmit to you the following: The American residents of Mexico City and vicinity in general meeting at the American Club in this city have considered carefully your cablegram to the Brazilian Minister Of March 5, 5 p.m. which reads,…
8. **The American Ambassador to the Secretary of State.** — American Embassy, Mexico, January 6, 1912.  
   `frus1912/d905` · score -12.7889  
   > Sir: I have the honor to transmit herewith for such action as the Department deems necessary to take, a copy of an informal note, with its inclosures, from the Mexican Minister for Foreign Affairs, relative to certain seditious propaganda being carried on by Dr. Emilio Vázquez Gómez from his…
9. **The Acting Secretary of State to the Ambassador in Mexico (Fletcher)** — Washington, March 8, 1918.  
   `frus1918/d695` · score -12.7469  
   > Sir: The Department acknowledges the receipt of your No. 834 [634] of December 5, 1917, No. 634 not printed; for enclosure see ante, p. 793. with which you forwarded the text and translation of the presidential decree providing for the appointment of a commission to pass upon claims for damages to…
10. **The Minister in Nicaragua (Eberhardt) to the Secretary of State** — Managua, December 31, 1926—3 p.m. [Received 10:20 p.m.]  
   `frus1926v02/d528` · score -12.6475  
   > Department’s 148, December 30, 4 p.m. President Diaz telegraphed a reply yesterday to President Jimenez’s offer of mediation stating that he had received similar [offer] from the Guatemalan Government which he had answered with a proposal to send a diplomat to Guatemala. While these conversations…

### Semantic (query prompt)

1. **Mr. Plumb to Mr. Seward.** — Legation of the United States, City of Mexico, September 25, 1868.  
   `frus1868p2/d332` · score 0.7874  
   > Sir: I beg to inclose to the department herewith a copy of the Diario Oficial of this government, of yesterday, in which certain late documents are published, from which it appears that the ex-General Santa Anna has established a military headquarters in Havana, and is seeking to prepare from there…
2. **Mr. Plumb to Mr. Seward.** — Legation of the United States, City of Mexico, May 23, 1868.  
   `frus1868p2/d296` · score 0.7852  
   > Sir: It will be with unfeigned regret, I well know, that the government and people of the United States will learn that the era of pronun-ciamentos is apparently again returning to this country. As I have said before, no political movement to erect any other in the place of the constitutional…
3. **Vice Consul Blocker to the Secretary of State** — Eagle Pass, December 7, 1916.  
   `frus1916/d815` · score 0.7811  
   > Sir: * * * Enclosed is an original [manifesto] to the people of Mexico, signed by General Villa, at San Andres, Chihuahua, setting forth the platform of Villa and his colleagues. It seems evident that General Murguia, the Government commander, successfully reached Chihuahua and wrested it from the…
4. **Ambassador Fletcher to the Secretary of State** — American Embassy, Mexico City, April 18, 1917.  
   `frus1917/d1147` · score 0.7771  
   > Sir: I have the honor to report that in accordance with the Transitory Article No. 6 of the recently adopted Constitution, the Congress met in extraordinary session on the 15th instant. The First Chief of the Constitutionalist Army, charged with the Executive Power of the Nation, appeared before it…
5. **The Brazilian Minister to Mexico to the Secretary of State ad interim.** — Brazilian Legation, Mexico City, June 16, 1915—11 a.m.  
   `frus1915/d917` · score 0.7765  
   > I beg to transmit following note delivered to me yesterday night. Cardoso de Oliveira. [Untitled] Mexico City, June 15, 1915. Mr. Minister: With respect to the declarations publicly made by His Excellency President Wilson as to the policy he will pursue in Mexican affairs, the Sovereign…
6. **The American Ambassador to the Secretary of State.** — American Embassy, Mexico, February 4, 1913.  
   `frus1913/d785` · score 0.7740  
   > My Dear Mr. Knox: Upon resuming my duties at this post after an absence of two months Mr. Wilson resumed charge of the Embassy on January 5. I find practically the same conditions existing that prevailed prior to my departure. The area of the armed revolution against the Government appears to have…
7. **Mr. Arredondo to the Secretary of State.** — Confidential Agency of the Constitutionalist Government of Mexico, Washington, December 16, 1914.  
   `frus1914/d976` · score 0.7715  
   > Mr. Secretary: I have the honor to enclose herewith copy in translation of a decree issued on the 12th instant by Mr. Venustiano (Carranza as First Chief of the Constitutionalist Army in charge of the Executive Power of Mexico, with headquarters at Vera Cruz. In sending you this document I am…
8. **Mr. Romero to Mr. Seward** — Mexican Legation in the United States of America, Washington, December 24, 1865.  
   `frus1865p3/d572` · score 0.7707  
   > Mr. Secretary: I have the honor of transmitting to you, for the information of the government of the United States, documents relating to Mexican affairs; and although some of them are of old date, I think them all of sufficient importance to be submitted officially to your consideration. You will…
9. **Mr. Romero to Mr. Seward** — Mexican Legation in the United States of America, Washington, August 12, 1866.  
   `frus1866p3/d99` · score 0.7705  
   > Mr. Secretary: Continuing my communications to the government of the United States of the chief occurrences in the Mexican republic at this critical period of its political existence, I send you to-day the enclosed indexed documents relating to Don Antonio Lopez de Santa Anna’s offer of his…
10. **General Huerta to the President.** — Mexico, February 18, 1913.  
   `frus1913/d837` · score 0.7705  
   > I have the honor to inform you that I have overthrown this Government. The forces are with me, and from now on peace and prosperity will reign. Your obedient servant, Victoriano Huerta.

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **The Chargé in Mexico (Summerlin) to the Secretary of State** — Mexico, May 25, 1922. [Received June 5.]  
   `frus1922v02/d576` · score 0.9387  
   > Sir: I have the honor to acknowledge the receipt of the Department’s telegram (No. 70, May 15, 5 p.m.), in which I was instructed to request Mr. Pani to elucidate a certain paragraph in his informal note of May 4, 1922. Ante, p. 653. I was also instructed to request specific information as to the…
2. **The Ambassador in Mexico (Fletcher) to the Secretary of State** — Mexico, December 11, 1918.  
   `frus1918/d705` · score 0.9382  
   > Sir: Confirming my telegram No. 1804 of to-day’s date, Not printed. I have the honor to forward herewith a copy and translation of a note received last night from the Mexican Foreign Office, in reply to my note No. 288 of March 29 last, on the subject of the claims commission set up by the Mexican…
3. **The American Ambassador to the Secretary of State.** — American Embassy, Mexico, February 5, 1913.  
   `frus1913/d1213` · score 0.9358  
   > Sir: I have the honor to acknowledge the receipt of the Department’s instruction No. 1168 of the 10th ultimo, relative to the correspondence exchanged between the Mexican Minister for Foreign Affairs and the British Minister concerning the status of claims growing out of the revolution. In order,…
4. **The American Ambassador to the Secretary of State.** — American Embassy, Mexico, March 12, 1913.  
   `frus1913/d934` · score 0.9290  
   > My dear Mr. Bryan: * * * relations with díaz and huerta. My attention has been called to articles in certain American newspapers which, either through erroneous information or malicious intention, seemed disposed to put a false construction on the relations of the Embassy with Generals Huerta and…
5. **reply of the secretary of foreign affairs, señor gamboa, to the proposals of the american government conveyed through the honorable john lind.** — Foreign Office, Mexico, August 16, 1913.  
   `frus1913/d1029` · score 0.9284  
   > [Laid before Congress by the President on the occasion of his address above printed.] Sir: On the 6th instant, pursuant to telegraphic instructions from his Government, the Chargé d’Affaires ad interim of the United States of America verbally informed Mr. Manuel Garza Aldape, then in charge of the…
6. **The American Chargé d’Affaires to the Secretary of State.** — American Embassy, Mexico, November 27, 1912.  
   `frus1912/d1216` · score 0.9262  
   > Sir: With reference to my telegram of November 24, 12 noon, Should be November 27, 12 noon. I have the honor to transmit herewith a translation of the note which I have received in reply to the Embassy’s strong note of September 15 last. I have [etc.] Montgomery Schuyler. [Inclosure.—Translation.]…
7. **The Chargé in Mexico (Summerlin) to the Secretary of State** — [Mexico City,] April 5, 1923. [Received April 12(?)]  
   `frus1923v02/d472` · score 0.9252  
   > Sir: In confirmation of my telegram No. 21, April 4, 5 P.M., Not printed. and with reference to your informal instruction dated July 28, 1923 [1922], Foreign Relations, 1922, vol. ii, p. 674. and to previous correspondence, in regard to the proposed Treaty of Amity and Commerce, I have the honor to…
8. **The American Ambassador to the Secretary of State.** — American Embassy, Mexico, May 15, 1913.  
   `frus1913/d988` · score 0.9247  
   > My Dear Mr. Bryan: Since my despatch of March 12, 1913, which aimed to cover in the fullest detail the events of the recent revolutionary uprising which led to the installation of the present Huerta Government, events have crowded so thick and fast that an intelligent analysis of the situation has…
9. **The American Ambassador to the Secretary of State.** — American Embassy, Mexico, January 18, 1913.  
   `frus1913/d1133` · score 0.9244  
   > My Dear Mr. Knox: * * * The draft of the note For. Rel. 1912, p. 835. It was embodied in the note of September 15, 1912. sent hither by the Department of State to be transmitted by this Embassy to the Mexican Government marked a distinctly new departure in our dealings with this Government and the…
10. **The Chargé in Mexico (Summerlin) to the Secretary of State** — Mexico, June 10, 1921. [Received June 23.]  
   `frus1921v02/d345` · score 0.9238  
   > Sir: Supplementing my confidential No. 3929, of June 3, 1921, and in confirmation of the Embassy’s telegram No. 119, June 4, six P.M., Not printed. I have the honor to forward herewith translation of Memorandum No. 1 and its enclosure, Enclosure with memorandum no. 1 not printed. and copy and…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 7/10.*
*document variant:* frus1955-57v06/d245, frus1868p2/d332, frus1913/d785, frus1916/d815, frus1917/d1147, frus1911/d764, frus1868p2/d296, frus1914/d976, frus1915/d917, frus1915/d991
*bare variant:* frus1868p2/d296, frus1916/d815, frus1868p2/d332, frus1917/d1147, frus1866p3/d51, frus1915/d905, frus1914/d976, frus1865p3/d572, frus1922v02/d576, frus1913/d785

---

## Q6. When did U.S. diplomats realize that Hitler was a serious danger to the United States?

### Lexical — `"when" AND "did" AND "u.s." AND "diplomats" AND "realize" AND "that" AND "hitler" AND "was" AND "a" AND "serious" AND "danger" AND "to" AND "the" AND "united" AND "states?"`

1. **263. Record of the Meeting Between Secretary of State Dulles and President Tito on the Island of Vanga, November 6, 1955, 3–5:40 p.m.** — Island of Vanga, November 6, 1955, 3–5:40 p.m.  
   `frus1955-57v26/d263` · score -13.7627  
   > The Secretary flew from Geneva, where he was attending the Four-Power Conference of Foreign Ministers, to Vienna on November 4. He met informally with Austrian leaders on November 5 (see Toden 16, infra) and then flew to Brioni for talks with Tito on November 6. According to Dulles’ Appointment…
2. **208. Paper Prepared in the National Security Council** — Washington, undated  
   `frus1981-88v01/d208` · score -13.6848  
   > THE ADMINISTRATION’S DEBATES WITH ITS DOMESTIC CRITICS The terms of the public debate on foreign policy is too often being defined by the President’s domestic critics and not by the President and the Administration. Yet the first rule in these matters is: he who defines the terms of the debate is…
3. **No. 529 Memorandum of Discussion at the 186th Meeting of the National Security Council, Friday, February 26, 1954** — February 26, 1954  
   `frus1952-54v07p1/d529` · score -12.4835  
   > Memorandum of Discussion at the 186th Meeting of the National Security Council, Friday, February 26, 1954 top secret eyes only February 26, 1954 Present at this meeting were the President of the United States, presiding; the Vice President of the United States; the Secretary of State; the Acting…
4. **No. 33 The Chairman of the President’s War Relief Control Board (Davies) to the President** — Washington, June 12, 1945.  
   `frus1945Berlinv01/d33` · score -11.6685  
   > The Chairman of the President’s War Relief Control Board This was Davies’ only official position in the United States Government at this time, although he acted as an adviser to the President before and during the Berlin Conference and as a special representative of the President on the mission to…
5. **United States Delegation Minutes** — Bermuda, December 7, 1953.  
   `frus1952-54v05p2/d357` · score -11.6025  
   > The U.S. Delegation transmitted to Washington a summary of this meeting in Secto 24 from Bermuda, Dec. 7. This telegram was repeated to London, Paris, Bonn, and Moscow. secret Plenary Minutes 5 Bermuda, December 7, 1953. Subjects: Indochina Security Assurances President Eisenhower opened the…
6. **58. Memorandum of Conversation** — Beijing, November 12, 1973, 5:40–8:25 p.m.  
   `frus1969-76v18/d58` · score -10.8411  
   > PARTICIPANTS Chairman Mao Tse-tung Prime Minister Chou En-lai Foreign Minister Chi Peng-fei Assistant Minister of Foreign Affairs Wang Hai-jung Tang Wang-shen, Interpreter Shen Jo-yen, Interpreter Henry A. Kissinger, Secretary of State Ambassador David Bruce, Chief U.S. Liaison Office Winston Lord,…
7. **219. Address by Secretary of Defense Weinberger** — Washington, November 28, 1984  
   `frus1981-88v01/d219` · score -10.8038  
   > “The Uses of Military Power” Thank you for inviting me to be here today with the members of the National Press Club, a group most important to our national security. I say that because a major point I intend to make in my remarks today is that the single most critical element of a successful…
8. **9. Memorandum of Conversation** — Beijing, February 16, 1973, 2:15–6:00 p.m.  
   `frus1969-76v18/d9` · score -10.3769  
   > PARTICIPANTS Chou En-lai, Premier, State Council, Chi P’eng-fei, Minister of Foreign Affairs, Ch’iao Kuan-hua, Vice Minister of Foreign Affairs, Wang Hai-jung, Assistant Foreign Minister T’ang Wen-sheng, Interpreter Shen Jo-yun, Interpreter Two Notetakers Dr. Henry A. Kissinger, Assistant to the…
9. **71. Memorandum of Conversation** — Helsinki, July 31, 1985, 2–5 p.m.  
   `frus1981-88v05/d71` · score -10.1247  
   > Source: Reagan Library, Jack Matlock Files, US - USSR Summits, 1985–1986, F.2, Memcons — Shultz / Shevardnadze Meetings Helsinki and New York. Secret; Super Sensitive. The meeting took place at the U.S. Ambassador’s residence in Helsinki. No drafting information appears on the memorandum. Under an…
10. **271. Memorandum of Conversation** — Moscow, May 24, 1972, 7:50–11 p.m.  
   `frus1969-76v14/d271` · score -10.1046  
   > PARTICIPANTS Leonid I. Brezhnev, General Secretary of the Central Committee of the CPSU Nikolai V. Podgorny, Chairman of the Presidium of the Supreme Soviet Aleksei N. Kosygin, Chairman of the Council of Ministers of the USSR Andrei M. Aleksandrov-Agentov, Assistant to the General Secretary Viktor…

### Semantic (query prompt)

1. **Memorandum by the Secretary of State** — [Washington,] April 14, 1941.  
   `frus1931-41v02/d242` · score 0.7866  
   > The Ambassador of Japan called at my apartment at the Wardman Park Hotel at my request. I stated that as the Ambassador would recall, both the President and I suggested during our conversations with him that he might care in discussions with me to explore the question of improving relations between…
2. **Memorandum of Conversation, by the Acting Secretary of State** — [Washington,] August 9, 1939.  
   `frus1939v01/d208` · score 0.7865  
   > Copies were transmitted on August 10 to the Secretary of State at White Sulphur Springs, West Virginia, and to President Roosevelt. [Extracts] [Washington,] August 9, 1939. The Polish Ambassador called to see me this afternoon upon his return to the United States after a month’s stay in Poland. . .…
3. **Memorandum of Conversation, by the Under Secretary of State (Welles)** — [Washington,] November 1, 1938.  
   `frus1938v02/d359` · score 0.7835  
   > The German Ambassador called to see me today and referred to the conversation which the Secretary of State had had on the telephone the previous day with Dr. Resenberg, First Secretary of his Embassy. The Ambassador expressed his regret that he had been ill and unable to talk himself and said that…
4. **The Ambassador in Uruguay (Dawson) to the Secretary of State** — Montevideo, November 13, 1942—3 p.m. [Received 7:40 p.m.]  
   `frus1942v05/d78` · score 0.7785  
   > For the Under Secretary from Spaeth No. 43. Reference is made to the statement in the Department’s cable no. 669 of November 7, 7 p.m., Not printed. that one objective of the total effort being made in support of the North African campaign is to “immediately consolidate hemisphere solidarity…
5. **Memorandum of Conversation, by the Secretary of State** — [Washington,] September 11, 1940.  
   `frus1940v02/d588` · score 0.7758  
   > With regard to Martinique, the Ambassador Gaston Henry-Haye called at the Department on September 11 to present his credentials as the new French Ambassador to the United States. sought to assure us that they would preserve order in the French islands. I raised the question of the ninety airplanes…
6. **The Secretary of State to the United States Political Adviser on Austrian Affairs (Erhardt), at Caserta** — Washington, April 3, 1945.  
   `frus1945v03/d27` · score 0.7755  
   > Dear Jack: This letter is intended for your guidance in your new mission as United States Political Adviser on Austrian Affairs. In that mission you will have the responsibility of representing the interests and policies of the United States, and also will contribute toward the re-establishment of…
7. **The Ambassador in Germany (Dodd) to President Roosevelt** — Berlin, February 27, 1937.  
   `frus1937v01/d665` · score 0.7751  
   > Photostatic copy obtained from the Franklin D. Roosevelt Library, Hyde Park, N. Y. Berlin, February 27, 1937. Dear Mr. President: Before you receive this, you will have seen a telegram or two which we shall have sent. This letter is designed to explain things a little further in case you have time…
8. **The Secretary of State to the Ambassador in Argentina (Armour)** — Washington, December 4, 1942—9 p.m.  
   `frus1942v05/d247` · score 0.7742  
   > Your 2401, November 28, 6 p.m. The Department approves in principle the suggestion contained in the second paragraph of your telegram under reference but believes that any statement which you might have to use in case the counter-memorandum allegedly being prepared by the Germans is presented,…
9. **The Secretary of State to the Ambassador in Japan (Grew)** — Washington, March 11, 1941—7 p.m.  
   `frus1941v04/d47` · score 0.7740  
   > On March 8 the Japanese Ambassador called on me at my apartment on the basis of a joint and equal initiative on his and my part growing out of his talk with the President at the time he presented his credentials. A chance remark offered occasion for me to refer to this Government’s program of a…
10. **Memorandum by the Under Secretary of State (Welles)** — Washington, June 24, 1937.  
   `frus1937v01/d248` · score 0.7728  
   > The Ambassador of Germany called upon me this morning for the purpose of complying with the friendly suggestion I made to him yesterday, namely, that he keep the Department of State advised so far as might be possible of any information which he might receive from his own Government with regard to…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **249. Verbatim Minutes of the Western European Chiefs of Mission Conference, Paris, May 6, 1957** — Paris, May 6, 1957  
   `frus1955-57v04/d249` · score 0.9556  
   > The following is verbatim text of the opening session of the Chiefs of Mission Conference, May 6, 1957, at 10:00 a.m. Ambassador Houghton: Mr. Secretary and distinguished guests. I believe it says in the Bible that the first will be last and the last will be first, and this is ample evidence that…
2. **263. Record of the Meeting Between Secretary of State Dulles and President Tito on the Island of Vanga, November 6, 1955, 3–5:40 p.m.** — Island of Vanga, November 6, 1955, 3–5:40 p.m.  
   `frus1955-57v26/d263` · score 0.9543  
   > The Secretary flew from Geneva, where he was attending the Four-Power Conference of Foreign Ministers, to Vienna on November 4. He met informally with Austrian leaders on November 5 (see Toden 16, infra) and then flew to Brioni for talks with Tito on November 6. According to Dulles’ Appointment…
3. **No. 33 The Chairman of the President’s War Relief Control Board (Davies) to the President** — Washington, June 12, 1945.  
   `frus1945Berlinv01/d33` · score 0.9538  
   > The Chairman of the President’s War Relief Control Board This was Davies’ only official position in the United States Government at this time, although he acted as an adviser to the President before and during the Berlin Conference and as a special representative of the President on the mission to…
4. **No. 529 Memorandum of Discussion at the 186th Meeting of the National Security Council, Friday, February 26, 1954** — February 26, 1954  
   `frus1952-54v07p1/d529` · score 0.9521  
   > Memorandum of Discussion at the 186th Meeting of the National Security Council, Friday, February 26, 1954 top secret eyes only February 26, 1954 Present at this meeting were the President of the United States, presiding; the Vice President of the United States; the Secretary of State; the Acting…
5. **No. 304 Minutes of the Chiefs of Mission Meeting at Luxembourg, September 18–19, 1953** — [Luxembourg?,] September 30, 1953.  
   `frus1952-54v06p1/d304` · score 0.9482  
   > Minutes of the Chiefs of Mission Meeting at Luxembourg, September 18–19, 1953 In addition to the accounts of the morning and afternoon sessions of Sept. 18 presented here, the minutes of the Luxembourg meeting included three attachments. The first was telegram Colux 3 from Luxembourg, Sept. 20,…
6. **Memorandum of Discussion at the 229th Meeting of the National Security Council, Tuesday, December 21, 1954** — December 21, 1954  
   `frus1952-54v02p1/d143` · score 0.9477  
   > Drafted by Deputy Executive Secretary Gleason on Dec. 22. [Extracts] top secret eyes only December 21, 1954 Present at the 229th Meeting of the National Security Council were the President of the United States, presiding; the Vice President of the United States; the Secretary of State; the…
7. **United States Delegation Minutes** — Bermuda, December 4, 1958.  
   `frus1952-54v05p2/d341` · score 0.9473  
   > The U.S. Delegation transmitted to Washington a summary of the plenary part of the first meeting in Secto 5, from Bermuda, Dec. 5. (396.1/12–553) This telegram was repeated to London, Paris, Bonn, and Moscow and states that President Eisenhower assumed the chair for the meeting at the request of…
8. **150. Memorandum of Discussion at the 254th Meeting of the National Security Council, Washington, July 7, 1955** — Washington, July 7, 1955  
   `frus1955-57v05/d150` · score 0.9468  
   > Basic U.S. Policy in Relation to Four-Power Negotiations (NSC 5524; Annexes to NSC 5524; Memos for NSC from Executive Secretary, same subject, dated July 1 and 5, 1955; NSC Action No. 1419 Regarding NSC 5524 and its annexes, see Document 144. The memoranda of July 1 and 5 by Lay circulated copies…
9. **No. 303 Summary Minutes of the Chiefs of Mission Meeting, London, September 24–26, 1952** — [Washington,] October 2, 1952.  
   `frus1952-54v06p1/d303` · score 0.9450  
   > Summary Minutes of the Chiefs of Mission Meeting, London, September 24–26, 1952 These minutes, along with a cover sheet and a table of contents, were circulated as document LAM Minutes. The drafter has not been identified. A summary of this 3-day meeting was transmitted to the Department of State…
10. **176. Memorandum of the Conversation at the Tripartite Luncheon, President’s Villa, Geneva, July 17, 1955, 1 p.m.** — Geneva, July 17, 1955, 1 p.m.  
   `frus1955-57v05/d176` · score 0.9445  
   > PARTICIPANTS United States The President The Secretary of State Mr. Douglas MacArthur II Mr. Livingston Merchant Lt. Col. Vernon Walters United Kingdom Prime Minister Eden Mr. Harold Macmillan Sir Ivone Kirkpatrick Sir Norman Brook France Prime Minister Faure Mr. Antoine Pinay Mr. Armand Berard Mr.…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 4/10.*
*document variant:* frus1931-41v02/d242, frus1939v01/d208, frus1938v02/d359, frus1945v03/d27, frus1941v04/d25, frus1969-76v01/d39, frus1933v02/d299, frus1942v05/d78, frus1940v01/d28, frus1937v01/d665
*bare variant:* frus1931-41v02/d242, frus1942v05/d78, frus1945v03/d27, frus1939v01/d208, frus1937v01/d736, frus1933v02/d268, frus1942v05/d11, frus1950v01/d74, frus1917Supp01v01/d100, frus1969-76v01/d39

---

## Q7. Intelligence collaboration

### Lexical — `"intelligence" AND "collaboration"`

1. **422. National Security Council Intelligence Directive No. 4** — Washington, December 12, 1947.  
   `frus1945-50Intel/d422` · score -11.6744  
   > NATIONAL INTELLIGENCE OBJECTIVES Pursuant to the provisions of Section 102(d)(5) of the National Security Act of 1947 and for the purpose of providing intelligence support for the preparation of studies required by the National Security Council in the fulfillment of its duties, it is directed that:…
2. **The Ambassador in Burma (Key) to the Secretary of State** — Rangoon, June 28, 1951—3 p. m.  
   `frus1951v06p1/d129` · score -11.6264  
   > secret Rangoon, June 28, 1951—3 p. m. 966. Deptel 891, June 22. The Embassy in Burma was requested in telegram 891 to Rangoon, June 22 (not printed), to provide information to substantiate its previous assertion that the People’s Republic of China had decided to provide aid to Thakin Than Tun, the…
3. **200. Director of Central Intelligence Directive No. 4/3** — Washington, December 14, 1954.  
   `frus1950-55Intel/d200` · score -11.5347  
   > COMPREHENSIVE NATIONAL INTELLIGENCE OBJECTIVES 1. Pursuant to National Security Council Intelligence Directive No. 4, Text in Foreign Relations, 1945–1950, Emergence of the Intelligence Establishment, Document 422. paragraph 1, the following comprehensive national intelligence objectives, generally…
4. **Memorandum for the National Security Council by the Executive Secretary (Lay)** — Washington, May 23, 1951.  
   `frus1951v01/d18` · score -11.3918  
   > secret Washington, May 23, 1951. Subject: Collaboration With Friendly Governments on Exchange of Information Concerning Operations Against Guerrillas Reference: NSC 90 NSC 90, October 26, 1950, is printed in Foreign Relations, 1950, vol. i, p. 401. In accordance with the request of the Secretary of…
5. **97. National Intelligence Estimate** — Washington, February 7, 1956.  
   `frus1955-57v27/d97` · score -11.3300  
   > Another note on the cover sheet indicates that NIE 24–56 was a supplement to NIE 24–54, “Probable Developments in Italy,” November 16, 1954. (Department of State, INR– NIE Files) NIE 24–56 Washington, February 7, 1956. THE POLITICAL OUTLOOK IN ITALY The Problem To estimate probable political…
6. **President Sergio Osmeña of the Philippines to the Secretary of the Interior (Ickes)** — Manila, September 12, 1945.  
   `frus1945v06/d914` · score -11.0907  
   > In reply to your telegram of September 11 I desire to state that information given you that I intend to release numerous persons against whom evidence was collected by the U.S. Army is erroneous. Persons kept in detention by Counter Intelligence Corps of U.S. Army and later delivered to the…
7. **30. Memorandum From the Assistant Chief of Staff for Military Intelligence of the War Department General Staff (Bissell) to Secretary of War Patterson** — Washington, October 22, 1945.  
   `frus1945-50Intel/d30` · score -10.9287  
   > SUBJECT Discussion with Secretary of Navy Regarding Joint Intelligence 1. Reference paragraph 2 (joint intelligence) of the memorandum of 13 October from the Secretary of Navy, Document 26. This memorandum was transmitted to Bissell under a October 22 memorandum from Colonel L.R. Forney, Acting…
8. **413. Memorandum From the Acting Chairman of the National Security Resources Board (Steelman) to the Executive Secretary of the National Security Council (Souers)** — Washington, February 2, 1950.  
   `frus1945-50Intel/d413` · score -10.9237  
   > SUBJECT Appraisal of Foreign Economic Intelligence Requirements, Facilities and Arrangements Related to the National Security As resources mobilization planning progresses, it is increasingly evident to the participating agencies that the full effectiveness of many segments of such planning depends…
9. **213. National Intelligence Estimate** — Washington, July 7, 1966.  
   `frus1964-68v24/d213` · score -10.7501  
   > NIE 60–1–66 Washington, July 7, 1966. THE RADICAL WEST AFRICAN STATES The Problem To assess the nature of West African radicalism as exemplified in Guinea, Mali, and Congo (Brazzaville) and the prospects over the next few years. Conclusions A. The radical or moderate character of a West African…
10. **The Consul General at Manila (Steintorf) to the Secretary of State** — Manila, September 5, 1945—9 a.m. [Received September 5—3:50 a.m.]  
   `frus1945v06/d911` · score -10.7448  
   > President Osmeña after conferring with Council of State issued Executive Order No. 65, Sept 3 Official Gazette, vol. 41, No. 6, p. 416. entitled “providing for the provisional release on bail of political prisoners, prior to the institution of the corresponding criminal cases against them,…

### Semantic (query prompt)

1. **41. Memorandum From the President’s Assistant for National Security Affairs (Brzezinski)** — Washington, May 31, 1977  
   `frus1977-80v28/d41` · score 0.7929  
   > MEMORANDUM FOR The Vice President The Secretary of State The Secretary of Defense The Attorney General The Director, Office of Management and Budget The Director of Central Intelligence SUBJECT PRM/NSC–11 The attached report has been prepared by a special interagency drafting team for SCC…
2. **221. Report by the Commission on Organization of the Executive Branch of the Government to the Congress** — Washington, June 1955.  
   `frus1950-55Intel/d221` · score 0.7913  
   > [Omitted here are a list of the members of the Commission and of the Task Force on Intelligence Activities, a transmittal letter, table of contents, acknowledgments, and preface.] PART I The task force, in order to give assurance to the Nation that all segments of the Intelligence Activities are…
3. **50. Paper Prepared in the Department of Defense** — Washington, undated  
   `frus1977-80v28/d50` · score 0.7856  
   > STRUCTURE OF THE INTELLIGENCE COMMUNITY AS PROPOSED BY THE DEPARTMENT OF DEFENSE The principal problem with the present intelligence effort is that it is not adequately responsive to users, whether they are national, departmental or tactical. The central issue in assessing the options available to…
4. **42. Memorandum From Director of Central Intelligence Turner to the President’s Assistant for National Security Affairs (Brzezinski)** — Washington, June 1, 1977  
   `frus1977-80v28/d42` · score 0.7800  
   > SUBJECT PRM/NSC–11, Task 2 Report 1. Submitted herewith is the subject report as directed by the President. I believe it provides an instructive overview of the functions, powers, and problems of the Director of Central Intelligence (DCI), particularly in his role as leader of the Intelligence…
5. **229. Memorandum From the President’s Deputy Assistant for National Security Affairs (Haig) to the President’s Assistant for National Security Affairs (Kissinger)** — Washington, March 27, 1971.  
   `frus1969-76v02/d229` · score 0.7778  
   > SUBJECT Review of the Intelligence Community Attached is the Presidential approval of yours and Shultz’s joint memorandum on intelligence reorganization. Per your instructions and with the agreement of Shultz, the PFIAB was given a copy of the basic study with the review of the various options. It…
6. **220. Report by the Task Force on Intelligence Activities of the Commission on Organization of the Executive Branch of the Government** — Washington, May 1955.  
   `frus1950-55Intel/d220` · score 0.7772  
   > PREFACE Scope of the Study “Intelligence”—A Definition The fate of the nation well may rest on accurate and complete intelligence data which may serve as a trustworthy guide for top-level governmental decisions on policy and action in a troubled world where so many forces and ideologies work at…
7. **82. Memorandum From the President’s Assistant for National Security Affairs (Scowcroft) to President Ford** — Washington, January 4, 1977.  
   `frus1969-76v38p2/d82` · score 0.7769  
   > SUBJECT PFIAB Report on “Intelligence for the Future” You have reviewed the PFIAB report concerning “Intelligence for the Future” and commented that it contains good suggestions which should be acted upon or passed on to the next Administration. Since the PFIAB report, you have in fact expressly…
8. **73. Memorandum From the National Intelligence Officers to Director of Central Intelligence Bush** — Washington, April 22, 1976.  
   `frus1969-76v38p2/d73` · score 0.7747  
   > SUBJECT A DCI -Oriented Approach to National Production 1. Much of the discussion of the future of the national intelligence production system has been framed in terms of concerns over the purity of the chain-of-command, the centrality of the CIA, and other narrow structural issues. On April 14,…
9. **70. Memorandum From the Director of the Bureau of the Budget (Smith) to the President’s Special Counsel (Rosenman)** — Washington, January 10, 1946.  
   `frus1945-50Intel/d70` · score 0.7736  
   > Some time ago I asked Colonel McCormack, who used to be in Army Intelligence and who is now working on the intelligence problem for the State Department, to give me a memorandum concerning the subject. My staff regards him very highly. The memorandum just came in today, and I have not at this…
10. **206. Memorandum From the Consultant to the National Security Council (Marshall) to the President’s Assistant for National Security Affairs (Kissinger)** — Washington, May 1, 1970.  
   `frus1969-76v02/d206` · score 0.7726  
   > SUBJECT Intelligence Inputs for Major Issues: A Substantive Evaluation and Proposals for Improvement When we first talked, you indicated a concern for the quality of the intelligence product you receive on major issues such as the SS–9 program, trends in Soviet strategic forces, etc. During the…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **Memorandum for the National Security Council by the Executive Secretary (Lay)** — Washington, May 23, 1951.  
   `frus1951v01/d18` · score 0.9183  
   > secret Washington, May 23, 1951. Subject: Collaboration With Friendly Governments on Exchange of Information Concerning Operations Against Guerrillas Reference: NSC 90 NSC 90, October 26, 1950, is printed in Foreign Relations, 1950, vol. i, p. 401. In accordance with the request of the Secretary of…
2. **212. National Security Council Directive** — Washington, March 12, 1955.  
   `frus1950-55Intel/d212` · score 0.9140  
   > NSC 5412/1 COVERT OPERATIONS 1. The National Security Council, taking cognizance of the vicious covert activities of the USSR and Communist China and the governments, parties and groups dominated by them, (hereinafter collectively referred to an “International Communism”) to discredit and defeat…
3. **200. Director of Central Intelligence Directive No. 4/3** — Washington, December 14, 1954.  
   `frus1950-55Intel/d200` · score 0.9105  
   > COMPREHENSIVE NATIONAL INTELLIGENCE OBJECTIVES 1. Pursuant to National Security Council Intelligence Directive No. 4, Text in Foreign Relations, 1945–1950, Emergence of the Intelligence Establishment, Document 422. paragraph 1, the following comprehensive national intelligence objectives, generally…
4. **250. National Security Council Directive** — Washington, undated.  
   `frus1950-55Intel/d250` · score 0.9088  
   > NSC 5412/2 Washington, undated. COVERT OPERATIONS 1. The National Security Council, taking cognizance of the vicious covert activities of the USSR and Communist China and the governments, parties and groups dominated by them, (hereinafter collectively referred to as “International Communism”) to…
5. **145. Memorandum From Robert P. Joyce of the Policy Planning Staff to the Deputy Under Secretary of State (Matthews)** — Washington, January 27, 1953.  
   `frus1950-55Intel/d145` · score 0.9052  
   > There is forwarded to you herewith two memoranda, both dated yesterday, on the general subject of the secret intelligence activities and the covert operations abroad of the CIA. The first memorandum, signed by me, is designed to provide background material and to set in the proper framework the…
6. **171. Note From the Executive Secretary of the National Security Council (Lay) to the National Security Council** — Washington, March 15, 1954.  
   `frus1950-55Intel/d171` · score 0.9052  
   > NSC 5412 Washington, March 15, 1954. COVERT OPERATIONS REFERENCES A. Memo for the Statutory Members of the NSC from Executive Secretary, subject: “The NSC 10 Series”, dated March 3, 1954 Not found. B. NSC 10/2 See Foreign Relations, 1945–1950, Emergence of the Intelligence Establishment, Document…
7. **Report to the President by the President’s Committee on International Information Activities** — [Washington,] June 30, 1953.  
   `frus1952-54v02p2/d370` · score 0.9051  
   > top secret [Washington,] June 30, 1953. [Here follow a table of contents and a list of appendices, of which all but Appendix II are printed.] Letter of Transmittal June 30, 1953. Dear Mr. President: We submit herewith the report of the President’s Committee on International Information Activities.…
8. **Memorandum for the National Security Council by the Executive Secretary (Lay)** — Washington, April 26, 1951.  
   `frus1951v01/d17` · score 0.9045  
   > top secret Washington, April 26, 1951. Subject: Review of the Current World Situation and Ability of the Force Being Maintained to Meet United States Commitments References: A. NSC 20/4 NSC 20/4, “United States Objectives With Respect to the USSR To Counter Soviet Threats to U.S. Security,” a…
9. **127. Memorandum From the Executive Secretary of the National Security Council (Lay) to the National Security Council** — Washington, August 19, 1952.  
   `frus1950-55Intel/d127` · score 0.9041  
   > SUBJECT Status of United States Programs for National Security as of June 30, 1952 REFERENCES A. NSC 135 Regarding NSC 135, “Status of U.S. Programs for National Security as of June 30, 1952,” see Foreign Relations, 1952–1954, vol. II, Part 1, pp. 56 – 57. B. Memo for NSC from Executive Secretary…
10. **38. Memorandum From Director of Central Intelligence Smith to the Executive Secretary of the National Security Council (Lay)** — Washington, January 8, 1951.  
   `frus1950-55Intel/d38` · score 0.9033  
   > SUBJECT Draft of NSC Directive on Covert Operations and Clandestine Activities 1. On 14 December 1950, at my request, the National Security Council suspended paragraph 4 of NSC 10/2. NSC Action No. 400, approved December 14, 1950, suspended the provisions of paragraph 4 of NSC 10/2, at the request…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 10/10, bare: 7/10.*
*document variant:* frus1977-80v28/d41, frus1950-55Intel/d221, frus1977-80v28/d50, frus1977-80v28/d42, frus1969-76v38p2/d73, frus1969-76v02/d229, frus1950-55Intel/d220, frus1969-76v38p2/d82, frus1969-76v02/d206, frus1945-50Intel/d70
*bare variant:* frus1977-80v28/d41, frus1977-80v28/d50, frus1950-55Intel/d221, frus1950-55Intel/d202, frus1969-76v02/d229, frus1977-80v28/d42, frus1969-76v02/d206, frus1950-55Intel/d146, frus1945-50Intel/d70, frus1969-76v02/d179

---

## Q8. How did the United States collaborate with Great Britain to conduct economic warfare during World War II?

### Lexical — `"how" AND "did" AND "the" AND "united" AND "states" AND "collaborate" AND "with" AND "great" AND "britain" AND "to" AND "conduct" AND "economic" AND "warfare" AND "during" AND "world" AND "war" AND "ii?"`

1. **271. Draft Paper, June 22** — June 22, 1962  
   `frus1961-63v07-09mSupp/d271` · score -14.9003  
   > BASIC NATIONAL SECURITY POLICY PART ONE: PRINCIPLES AND PURPOSES Introduction 1. In order to outline national security policy in Part Two of this paper, it is necessary first to lay out the broad principles and purposes which generate these policies; which determine their relative impor tance and…
2. **299. Minutes of a Meeting of the Secretary of State’s Open Forum** — Washington, May 11, 1987  
   `frus1981-88v01/d299` · score -14.7868  
   > MR. WILSON: Welcome to a special session of the Secretary’s Open Forum. Today we celebrate the fortieth anniversary of the Policy Planning Staff. The theme of the anniversary is Future Foreign Policy Challenges for the U.S. Mr. Richard Solomon, the current Director of the Policy Planning Staff is…
3. **Notes of a Meeting Held at President Wilson’s House in the Place des Etats-Unis, Paris, on Tuesday, May 20, 1919, at 11 a.m.** — Paris, May 20, 1919, 11 a.m.  
   `frus1919Parisv05/d76` · score -14.2416  
   > CF–20 Notes of a Meeting Held at President Wilson’s House in the Place des Etats-Unis, Paris, on Tuesday, May 20, 1919, at 11 a.m. Paris, May 20, 1919, 11 a.m. Present United States of America President Wilson. France M. Clemenceau. British Empire Rt. Hon. D. Lloyd George, M. P. Italy H. E. M.…
4. **Memorandum Prepared in the Department of State** — [Washington,] May 19, 1942.  
   `frus1931-41v02/d237` · score -14.0839  
   > ACCOUNT OF INFORMAL CONVERSATIONS BETWEEN THE GOVERNMENT OF THE UNITED STATES AND THE GOVERNMENT OF JAPAN, 1941 Introductory As the year 1941 opened, a vast movement of political forces throughout the world was intensely active. The Axis grouping among Germany, Italy and Japan had been formalized…
5. **Memorandum of Conversation, Prepared in the Department of State** — January 6 and 7, 1951. January 12 and 13, 1951.  
   `frus1951v07p2/d2` · score -12.8254  
   > This is the first of a series of unsigned memoranda, most or all of which were written by Charles Burton Marshall of the Policy Planning Staff. According to notations on the source texts, five copies (in a few cases, six copies) were made of each memorandum. One copy of each was sent to Deputy…
6. **United States Delegation Minutes, Third Formal Session, Conference of Foreign Ministers, Spiridonovka, Moscow, December 18, 1945, 4:00–7:15 p. m.** — Moscow, December 18, 1945, 4:00–7:15 p.m.  
   `frus1945v02/d235` · score -12.6017  
   > A brief report on this meeting was transmitted to Washington by the Secretary of State in telegram 4221, Delsec 15, December 19, 1945, from Moscow (740.00119 Council/12–1945). Moscow, December 18, 1945, 4:00–7:15 p.m. Present: According to the British delegation minutes of this meeting (not…
7. **Memorandum Prepared in the Department of State** — [Washington, undated.]  
   `frus1947v05/d395` · score -11.4397  
   > top secret [Washington, undated.] Specific Current Questions [Here follow a table of contents and a note which states: “The material included in this section was prepared by officers dealing with these matters in the interested geographical divisions of the Department and is intended primarily to…
8. **193. Memorandum From Acting Director of Central Intelligence Gates to the President’s Assistant for National Security Affairs (Carlucci)** — Washington, January 15, 1987  
   `frus1981-88v44p1/d193` · score -11.1826  
   > SUBJECT NSDD 250 Response [portion markings not declassified] 1. Attached is the DCI response to a key portion of the tasking that was posed to the Director in NSDD 250; that portion of the tasking that dealt with verification matters and was assigned to Ken Adelman and the DCI jointly as well as…
9. **The Military Representative on the Supreme War Council (Bliss) to the Secretary of State** — Washington, February 19, 1920.  
   `frus1914-20v02/d147` · score -10.5750  
   > Sir: I have the honor to submit, herewith, my report on the Supreme War Council. A duplicate copy has been handed to the Secretary of War. Very respectfully, Tasker H. Bliss [Enclosure] The Military Representative on the Supreme War Council (Bliss) to the Secretary of State Washington, February 6,…
10. **22. Draft Report Prepared by Lincoln Bloomfield, Special Assistant to the Assistant Secretary of State for International Organization Affairs** — Washington, February 9, 1956.  
   `frus1955-57v11/d22` · score -10.2710  
   > SUBJECT Report on “Evaluation of Role of US in 10th General Assembly” Problem To analyze objectively the effect which the 10th Session has had on the international position of the United States, particularly upon the factors of prestige and general reputation in the American role of world…

### Semantic (query prompt)

1. **Memorandum by the Secretary of State to President Roosevelt** — Washington, September 8, 1944.  
   `frus1944v03/d19` · score 0.8008  
   > Lend-Lease and General Economic Relations with the United Kingdom in “Phase 2” Phase 2 designated the period of the war between the surrender of Germany and the surrender of Japan. 1. The most important international economic problem of the transition and post-war periods will be the situation of…
2. **Memorandum by the Secretary of State to President Roosevelt** — Washington, September 30, 1944.  
   `frus1944v03/d23` · score 0.7977  
   > Handed to the President by the Secretary of State, October 1, 1944. Washington, September 30, 1944. You will recall my memorandum of September 2, 1944, Not printed. suggesting that you urge upon Mr. Churchill the early resumption of conversations on economic policy, and my memorandum of September…
3. **The British Minister (Campbell) to the Assistant Secretary of State (Acheson)** — Washington, 24 August, 1944.  
   `frus1944v02/d103` · score 0.7929  
   > My Dear Mr. Assistant Secretary: With reference to Mr. Marris’ letter of 10th May to Mr. Taft about economic policy towards the European Neutrals after the collapse of Germany, I am now writing to give you an outline of the results of preliminary consideration given to this problem in London. The…
4. **The Secretary of State to the President** — Washington, September 8, 1944.  
   `frus1944Quebec/d110` · score 0.7893  
   > Lend-Lease and General Economic Relations With the United Kingdom in “Phase 2” 1. The most important international economic problem of the transition and post-war periods will be the situation of the United Kingdom: the sterling–dollar relationship, the change in Britain’s creditor position, the…
5. **The British Ambassador (Lothian) to the Secretary of State**  
   `frus1940v03/d84` · score 0.7849  
   > Memorandum The British Ambassador appreciates the understanding shown in Mr. Cordell Hull’s memorandum of February 21st, 1940, of the grave conditions with which Great Britain is confronted in financing its maximum war effort and of the reasons which compel the United Kingdom Government to reduce…
6. **Memorandum of Conversation, by the Secretary of State** — [Washington,] July 5, 1940.  
   `frus1940v03/d38` · score 0.7847  
   > The British Ambassador called at his request and handed me an aide-mémoire dated July 3, 1940 (copy attached), which reviewed at length the altered situation of the British in view of the collapse of the French. This aide-mémoire pointed out certain considerations and situations which the British…
7. **Memorandum by Mr. Howard J. Trueblood of the Office of the Adviser on International Economic Affairs** — [Washington,] November 12, 1940.  
   `frus1940v04/d657` · score 0.7836  
   > Assistant Secretary of State Grady on November 19 added a notation as follows: “I feel that our reply to the British should indicate sympathy with the objectives and a desire to cooperate to the extent that it is practical.” [Washington,] November 12, 1940. From an examination of the underlying…
8. **The British Embassy to the Department of State**  
   `frus1932v01/d529` · score 0.7823  
   > In their note of November 10th His Majesty’s Government in the United Kingdom put forward a request to the United States Government to enter upon discussions with a view to the adjustment of the British War Debt, and at the same time they suggested a suspension of the payment due on December 15th,…
9. **The Chargé in the United Kingdom (Matthews) to the Secretary of State** — London, April 12, 1942—3 p.m. [Received April 12—2:04 p.m.]  
   `frus1942v01/d142` · score 0.7804  
   > From informal conversations of Penrose Ernest F. Penrose, economist, special assistant in the Embassy at London. with Ronald, Nigel Bruce Ronald, Counselor, British Foreign Office; appointed Acting Assistant Under Secretary of State for Foreign Affairs on July 6, 1942. Keynes John Maynard Keynes,…
10. **The Secretary of State to the Diplomatic Representatives in the American Republics Except Argentina** — Washington, December 7, 1943.  
   `frus1944v07/d1457` · score 0.7790  
   > Sirs: During the past years this Government has inaugurated many programs directed at implementation of economic warfare against the Axis in the American republics. One such program, which to some extent has overlapped the matter of Proclaimed List and related questions, has been the program for…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **Report by the Policy Planning Staff** — [Washington,] February 24, 1948.  
   `frus1948v01p2/d4` · score 0.9608  
   > top secret [Washington,] February 24, 1948. PPS /23 Review of Current Trends U.S. Foreign Policy i. united states, britain, and europe On the assumption that Western Europe will be rescued from communist control, the relationships between Great Britain and the continental countries, on the one…
2. **299. Minutes of a Meeting of the Secretary of State’s Open Forum** — Washington, May 11, 1987  
   `frus1981-88v01/d299` · score 0.9568  
   > MR. WILSON: Welcome to a special session of the Secretary’s Open Forum. Today we celebrate the fortieth anniversary of the Policy Planning Staff. The theme of the anniversary is Future Foreign Policy Challenges for the U.S. Mr. Richard Solomon, the current Director of the Policy Planning Staff is…
3. **271. Draft Paper, June 22** — June 22, 1962  
   `frus1961-63v07-09mSupp/d271` · score 0.9544  
   > BASIC NATIONAL SECURITY POLICY PART ONE: PRINCIPLES AND PURPOSES Introduction 1. In order to outline national security policy in Part Two of this paper, it is necessary first to lay out the broad principles and purposes which generate these policies; which determine their relative impor tance and…
4. **109. Memorandum of Conversation** — Beijing, May 21, 1978, 9:52 a.m.–1:20 p.m.  
   `frus1977-80v13/d109` · score 0.9513  
   > SUBJECT Summary of Dr. Brzezinski’s Meeting with Foreign Minister Huang Hua PARTICIPANTS Zbigniew Brzezinski, Assistant to the President for National Security Affairs Leonard Woodcock, United States Ambassador to the People’s Republic of China Richard Holbrooke, Assistant Secretary of State for…
5. **Memorandum by the Counselor (Kennan) to the Secretary of State** — [Washington,] January 6, 1950.  
   `frus1950v01/d52` · score 0.9510  
   > Marginal notations by the Secretary of State, each consisting merely of a summary key word or two, appear beside certain paragraphs in the source text. confidential [Washington,] January 6, 1950. Mr. Secretary: Since we assume that you will wish to make your presentation to the Congressional…
6. **Report of the American Delegation, February 9, 1922**  
   `frus1922v01/d88` · score 0.9479  
   > To the President: The undersigned, appointed by the President as Commissioners to represent the Government of the United States at the Conference on Limitation of Armament, have the honor to submit the following report of the Proceedings of the Conference. On July 8, 1921, by direction of the…
7. **47. Memorandum of Conversation** — Beijing, August 22, 1977, 4–6:40 p.m.  
   `frus1977-80v13/d47` · score 0.9462  
   > SUBJECT U.S. Foreign Policy; Domestic Roots; Allies; Strategic Forces; Arms Control; East-South Asia; Yugoslavia; ME PARTICIPANTS U.S. The Secretary Ambassador Woodcock Under Secretary Habib Assistant Secretary Holbrooke, EA Assistant Secretary Carter, PA Peter R. Tarnoff, Executive Secretary…
8. **252. Northern European Chiefs of Mission Conference, London, September 19–21, 1957: Summary of Proceedings** — London, September 19–21, 1957  
   `frus1955-57v04/d252` · score 0.9453  
   > Participants American Embassy, London— Ambassador John Hay Whitney Minister Walworth Barbour American Embassy, Reykjavik— Ambassador John J. Muccio Joseph Carwell, Counselor USRO, Paris— Ambassador George W. Perkins American Embassy, Helsinki— Ambassador John D. Hickerson Mose L. Harvey, Counselor…
9. **Memorandum of Conversation, Prepared in the Department of State** — January 6 and 7, 1951. January 12 and 13, 1951.  
   `frus1951v07p2/d2` · score 0.9450  
   > This is the first of a series of unsigned memoranda, most or all of which were written by Charles Burton Marshall of the Policy Planning Staff. According to notations on the source texts, five copies (in a few cases, six copies) were made of each memorandum. One copy of each was sent to Deputy…
10. **Draft Memorandum by the Counselor (Kennan) to the Secretary of State** — [Washington,] February 17, 1950.  
   `frus1950v01/d62` · score 0.9446  
   > Circulated in the Policy Planning Staff by Harry H. Schwartz, Executive Secretary, under a memorandum of transmittal of February 17 which read as follows: “Attached is a copy of a draft memorandum addressed to the Secretary prepared by Mr. Kennan. This memorandum has not been sent nor is it Mr.…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 8/10.*
*document variant:* frus1944v03/d19, frus1944v03/d23, frus1944v02/d103, frus1944Quebec/d110, frus1932v01/d529, frus1948v03/d679, frus1940v03/d84, frus1940v03/d38, frus1944v07/d1457, frus1945v06/d15
*bare variant:* frus1944v03/d23, frus1944v03/d19, frus1944v02/d103, frus1944Quebec/d110, frus1932v01/d529, frus1940v03/d84, frus1947v01/d501, frus1945v06/d15, frus1940v03/d38, frus1944v07/d1457

---

## Q9. Foreign Service reform

### Lexical — `"foreign" AND "service" AND "reform"`

1. **338. Action Memorandum From the Chairman of the Secretary’s Open Forum Panel, Department of State (Thomas) to the Deputy Under Secretary of State for Administration (Macomber)** — Washington, October 20, 1971.  
   `frus1969-76v02/d338` · score -11.6535  
   > REFORM OF THE ROLE OF FOREIGN SERVICE WIVES It has become increasingly clear in the past few years that a reform is urgently needed in the treatment of Foreign Service wives. No question before the Open Forum Panel has been more controversial; none has drawn consistently greater attendance at Panel…
2. **Preface**  
   `frus1977-80v28/preface` · score -11.4399  
   > Structure and Scope of the Foreign Relations Series This volume is part of a subseries of volumes of the Foreign Relations series that documents the most important issues in the foreign policy of the administration of Jimmy Carter. The subseries presents a documentary record of major foreign policy…
3. **No. 201. Mr. Francis to Mr. Fish.** — Legation of the United States, Athens, June 29, 1872. (Received July 22.)  
   `frus1872p1/d201` · score -11.1999  
   > Sir: I have the honor to transmit herewith a copy of a letter addressed by me to Mr. Mélétopoulo, secretary-general of the minister of foreign affairs, under date of the 18th instant, inclosing documents on civil-service reform in the United States. And I also transmit a copy of the reply of Mr.…
4. **171. Memorandum From the Senior Officer Bunch to the Under Secretary of State for Management (Read) and the Director General of the Foreign Service and Director of Personnel (Barnes)** — Washington, undated  
   `frus1977-80v28/d171` · score -11.1346  
   > In reply to your request, Not further identified. please find attached our recommendations for specific changes in the proposed Foreign Service Act of 1980. Attached but not printed. Our recommendations are substantively the same as those we have suggested over the last few months See, for example,…
5. **153. Memorandum From the Director of the Office of Civil Service Career Development and Assignments (Bourbon) to the Director General of the Foreign Service and Director of Personnel (Barnes)** — Washington, June 2, 1978  
   `frus1977-80v28/d153` · score -10.8390  
   > SUBJECT Status of FPMP The House Government Operations Committee will hold bearings on Reorganization Plan Number 2 Carter submitted Reorganization Plan No. 2 of 1978 to Congress on May 23. See Public Papers: Carter, 1978, Book I, pp. 953–959. (to establish an Office of Personnel Management) on…
6. **326. Memorandum From Mary S. Olmsted of the Ad Hoc Women’s Committee, Department of State to Chris Petrow of the Office of the Deputy Under Secretary of State for Administration** — Washington, October 7, 1970.  
   `frus1969-76v02/d326` · score -10.6361  
   > SUBJECT Our Recommendations re Task Force Reports Thank you for the time and trouble you went to in making our views known to the chairmen of the Task Forces about the role and status of women in the Department and the Foreign Service, and for your memorandum of September 30 reporting their…
7. **Reforms, governmental, judicial, and educational**  
   `frus1906p1/ch57` · score -10.6355  
   > See also changes in the customs service, p. 280. (For previous correspondence see Foreign Relations, 1905, pp. 176 et seq.)
8. **155. Memorandum From the Director of the Office of Civil Service Career Development and Assignments (Bourbon) to the Director General of the Foreign Service and Director of Personnel (Barnes)** — Washington, August 4, 1978  
   `frus1977-80v28/d155` · score -10.6136  
   > SUBJECT Civil Service Reform Legislation The House Post Office and Civil Service Committee print of the Civil Service Reform Act of 1978, which was expected at CSC today, has not yet arrived. We will get a copy when it does arrive. A New York Times article of August 3, 1978 (attached) Attached but…
9. **339. Memorandum From the Chairman of the Department of State Task Force VII Committee (Petrow) to the Deputy Under Secretary of State for Management (Macomber)** — Washington, December 21, 1971.  
   `frus1969-76v02/d339` · score -10.5839  
   > SUBJECT Findings of Task Force Chairmen The following represents a consensus of the views of the Task Force Chairmen. It is a summary of their findings during their week-long inquiry in the Department and of their recommendations for the future. I. Findings A. The first and the most important thing…
10. **256. Paper Prepared in the Department of the Treasury** — Washington, undated  
   `frus1981-88v38/d256` · score -10.4930  
   > CONTINUATION OF CURRENT APPROACH TO DEBT PROBLEMS: A REALISTIC ASSESSMENT The current approach to debt problems focuses on the adoption of debtor reforms buttressed by external financial support. Its fundamental objective is to generate stronger growth in debtor nations as a basis for achieving a…

### Semantic (query prompt)

1. **158. Report to Congress Prepared in the Department of State** — Washington, January 10, 1977.  
   `frus1969-76v38p2/d158` · score 0.8404  
   > MEETING FUTURE FOREIGN AFFAIRS PERSONNEL NEEDS Report to the Congress on Plans for Improving and Simplifying the Personnel Systems of the Department of State and the United States Information Agency [Omitted here is the table of contents.] I. Introduction and Summary To meet the demands of national…
2. **143. Action Memorandum From the Director General of the Foreign Service (Laise) to Secretary of State Kissinger** — Washington, May 17, 1975.  
   `frus1969-76v38p2/d143` · score 0.8368  
   > The Professional Service of the Department of State In the Department of State you, as Secretary, have a resource of exceptional wealth. As you have acknowledged, it is a pool of intelligence, versatility, and dedication. Yet you, like other leaders, have found flaws in the Service that seem to…
3. **223. Briefing Paper Prepared in the Department of State** — Washington, undated.  
   `frus1969-76v38p2/d223` · score 0.8317  
   > Department Organizational and Personnel Issues In this Department, more than in program-oriented agencies, the fundamental resource is people, and organizational performance depends to an unusual extent on the quality of our personnel and on the way we manage and direct their efforts. I. Department…
4. **154. Memorandum From the Director General of the Foreign Service (Laise) to the Deputy Under Secretary of State for Management (Eagleburger)** — Washington, undated.  
   `frus1969-76v38p2/d154` · score 0.8285  
   > SUBJECT The Department’s Personnel Structure: A Rational Solution The structure of the Department’s personnel system has been studied enough times, both from without and within, so that any attempt to characterize the process almost inevitably falls into cliches. Even as we moved into the postwar…
5. **338. Action Memorandum From the Chairman of the Secretary’s Open Forum Panel, Department of State (Thomas) to the Deputy Under Secretary of State for Administration (Macomber)** — Washington, October 20, 1971.  
   `frus1969-76v02/d338` · score 0.8272  
   > REFORM OF THE ROLE OF FOREIGN SERVICE WIVES It has become increasingly clear in the past few years that a reform is urgently needed in the treatment of Foreign Service wives. No question before the Open Forum Panel has been more controversial; none has drawn consistently greater attendance at Panel…
6. **38. Letter From President Johnson to the Speaker of the House of Representatives (McCormack)** — Washington, May 6, 1965.  
   `frus1964-68v33/d38` · score 0.8244  
   > Dear Mr. Speaker: In my message of January 14, 1965, to the Congress relative to foreign aid, For text, see Public Papers of the Presidents of the United States: Lyndon B. Johnson, 1965, Book I, pp. 44–50. I stated that we would develop “a program which is designed to strengthen the personnel…
7. **164. Memorandum From the Director of the Office of UN Political Affairs (Bridges) to the Under Secretary of State for Management (Read) and the Director General of the Foreign Service and Director of Personnel (Barnes)** — Washington, January 24, 1979  
   `frus1977-80v28/d164` · score 0.8236  
   > SUBJECT Proposed Personnel System Changes I venture to offer you the following reactions to the proposed changes in the Foreign Service personnel system. The proposals were not found. As a one-time worker in Personnel, I can appreciate how much work has gone into the proposals. But I am very sorry…
8. **161. Memorandum From the Director General of the Foreign Service and Director of Personnel (Barnes) to Secretary of State Vance** — Washington, January 25, 1978  
   `frus1977-80v28/d161` · score 0.8233  
   > Your Meeting with the FSO Group Background You have agreed to meet with a small group of FSOs No minutes of this meeting were found. who represent the 500-some officers who signed a letter (attached) expressing concern over the state of the Service. This is a serious group. It came together…
9. **174. Airgram From the Department of State to All Diplomatic and Consular Posts** — Washington, June 26, 1979, 10:57 a.m.  
   `frus1977-80v28/d174` · score 0.8214  
   > A–2040 Washington, June 26, 1979, 10:57 a.m. SUBJECT Proposed Foreign Service Act of 1979 On June 20, 1979 the Secretary submitted the proposed Foreign Service Act of 1979 to the Congress. He and Under Secretary Read testified in support of the Bill on June 21. This Airgram forwards for your…
10. **181. Letter From the Under Secretary of State for Management (Read) to the Director of the Office of Management and Budget (McIntyre)** — Washington, October 6, 1980  
   `frus1977-80v28/d181` · score 0.8198  
   > Dear Jim: I am writing to provide the views of the Department of State on H.R. 6790, an enrolled bill to “promote the foreign policy of the United States by strengthening and improving the Foreign Service of the United States, and for other purposes.” H.R. 6790 was introduced on March 12. The…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **171. Memorandum From the Senior Officer Bunch to the Under Secretary of State for Management (Read) and the Director General of the Foreign Service and Director of Personnel (Barnes)** — Washington, undated  
   `frus1977-80v28/d171` · score 0.9197  
   > In reply to your request, Not further identified. please find attached our recommendations for specific changes in the proposed Foreign Service Act of 1980. Attached but not printed. Our recommendations are substantively the same as those we have suggested over the last few months See, for example,…
2. **338. Action Memorandum From the Chairman of the Secretary’s Open Forum Panel, Department of State (Thomas) to the Deputy Under Secretary of State for Administration (Macomber)** — Washington, October 20, 1971.  
   `frus1969-76v02/d338` · score 0.9151  
   > REFORM OF THE ROLE OF FOREIGN SERVICE WIVES It has become increasingly clear in the past few years that a reform is urgently needed in the treatment of Foreign Service wives. No question before the Open Forum Panel has been more controversial; none has drawn consistently greater attendance at Panel…
3. **161. Memorandum From the Director General of the Foreign Service and Director of Personnel (Barnes) to Secretary of State Vance** — Washington, January 25, 1978  
   `frus1977-80v28/d161` · score 0.9132  
   > Your Meeting with the FSO Group Background You have agreed to meet with a small group of FSOs No minutes of this meeting were found. who represent the 500-some officers who signed a letter (attached) expressing concern over the state of the Service. This is a serious group. It came together…
4. **174. Airgram From the Department of State to All Diplomatic and Consular Posts** — Washington, June 26, 1979, 10:57 a.m.  
   `frus1977-80v28/d174` · score 0.9112  
   > A–2040 Washington, June 26, 1979, 10:57 a.m. SUBJECT Proposed Foreign Service Act of 1979 On June 20, 1979 the Secretary submitted the proposed Foreign Service Act of 1979 to the Congress. He and Under Secretary Read testified in support of the Bill on June 21. This Airgram forwards for your…
5. **172. Memorandum From the Under Secretary of State for Management (Read) to Secretary of State Vance** — Washington, June 6, 1979  
   `frus1977-80v28/d172` · score 0.9105  
   > The Foreign Service Act Meeting, 10:00 a.m., June 7 No minutes of this meeting were found. I—Suggested Compromises and II—Next Steps Cy: I My reflections on the remaining issues and intra-Service political problems on structure following your Tuesday meeting with the Vine and AFSA groups June 5. No…
6. **164. Memorandum From the Director of the Office of UN Political Affairs (Bridges) to the Under Secretary of State for Management (Read) and the Director General of the Foreign Service and Director of Personnel (Barnes)** — Washington, January 24, 1979  
   `frus1977-80v28/d164` · score 0.9102  
   > SUBJECT Proposed Personnel System Changes I venture to offer you the following reactions to the proposed changes in the Foreign Service personnel system. The proposals were not found. As a one-time worker in Personnel, I can appreciate how much work has gone into the proposals. But I am very sorry…
7. **223. Briefing Paper Prepared in the Department of State** — Washington, undated.  
   `frus1969-76v38p2/d223` · score 0.9086  
   > Department Organizational and Personnel Issues In this Department, more than in program-oriented agencies, the fundamental resource is people, and organizational performance depends to an unusual extent on the quality of our personnel and on the way we manage and direct their efforts. I. Department…
8. **170. Memorandum of Conversation** — Washington, May 19, 1979  
   `frus1977-80v28/d170` · score 0.9082  
   > Meeting with Secretary Full-Time Participants Secretary Vance, Mr. Christopher, Mr. Tarnoff, Mr. Vest, Mr. Read, Amb. Barnes, Mr. Michel, Mr. Bacchus William Bacchus (PER). I. AFSA (9:00–10:00—Lars Hydle, Hydle, the country officer for Djibouti and Ethiopia, was President of AFSA. et al) Hydle said…
9. **154. Memorandum From the Director General of the Foreign Service (Laise) to the Deputy Under Secretary of State for Management (Eagleburger)** — Washington, undated.  
   `frus1969-76v38p2/d154` · score 0.9053  
   > SUBJECT The Department’s Personnel Structure: A Rational Solution The structure of the Department’s personnel system has been studied enough times, both from without and within, so that any attempt to characterize the process almost inevitably falls into cliches. Even as we moved into the postwar…
10. **169. Memorandum From the Under Secretary of State for Management (Read) and the Director General of the Foreign Service and Director of Personnel (Barnes) to Secretary of State Vance** — Washington, May 16, 1979  
   `frus1977-80v28/d169` · score 0.9043  
   > SUBJECT Areas of Consensus and Contention with Pros and Cons A. Areas of Consensus Since last November, consultations and discussions have been taking place in the Department, with the field, with other agencies immediately concerned, and with the Hill on the Foreign Service structure proposals.…

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 9/10.*
*document variant:* frus1969-76v38p2/d143, frus1969-76v38p2/d223, frus1969-76v38p2/d158, frus1969-76v38p2/d154, frus1977-80v28/d169, frus1969-76v02/d338, frus1977-80v28/d180, frus1977-80v28/d161, frus1969-76v38p2/d141, frus1977-80v28/d164
*bare variant:* frus1969-76v38p2/d158, frus1969-76v38p2/d223, frus1969-76v38p2/d143, frus1969-76v38p2/d154, frus1964-68v33/d38, frus1969-76v02/d338, frus1977-80v28/d169, frus1977-80v28/d181, frus1977-80v28/d161, frus1977-80v28/d164

---

## Q10. What convinced U.S. policymakers that the Soviet Union was no long an ally after World War II?

### Lexical — `"what" AND "convinced" AND "u.s." AND "policymakers" AND "that" AND "the" AND "soviet" AND "union" AND "was" AND "no" AND "long" AND "an" AND "ally" AND "after" AND "world" AND "war" AND "ii?"`

1. **59. Editorial Note**  
   `frus1969-76v34/d59` · score -26.8993  
   > An outgrowth of the Nixon administration’s policy of linkage, making negotiating progress in one area dependent on progress in another, was the threatened use of U.S. or allied military force to encourage North Vietnam and their Soviet patrons to reach a settlement to the conflict in Vietnam. On…
2. **8. Address by Ronald Reagan** — Chicago, August 18, 1980  
   `frus1981-88v01/d8` · score -23.4948  
   > [Omitted here are Reagan’s introductory remarks and the portion of his address dealing with the Veterans Administration.] These are matters of great concern to your great organization. Let us turn now to a matter which vitally concerns our nation — “PEACE”. It has always struck me as odd that you…
3. **Volume Summary**  
   `frus1964-68v12/summary` · score -22.4174  
   > (This is not an official statement of policy by the Department of State; it is intended only as a guide to the contents of this volume.) Since 1861, the Department of State’s documentary series Foreign Relations of the United States has constituted the official record of the foreign policy and…
4. **241. Memorandum of Conversation** — Washington, March 20, 1980, 1–3 p.m.  
   `frus1977-80v12/d241` · score -21.0772  
   > PARTICIPANTS Alexander Bessmertnykh, Minister-Counselor, Soviet Embassy Marshall Brement, NSC Staff Member SUBJECT Afghanistan and US-Soviet Relations (U) Bessmertnykh opened the conversation by insisting on the need to maintain channels of communication between us, a sentiment with which I readily…
5. **192. Remarks by President Reagan** — Washington, April 6, 1984  
   `frus1981-88v01/d192` · score -17.4362  
   > Remarks at the National Leadership Forum of the Center for Strategic and International Studies of Georgetown University Thank you very much, Ann Armstrong. Thank you, Cochairman Sam Nunn. I am honored to have this opportunity to take part in your National Leadership Forum. The CSIS reputation for…
6. **Report to the President by the President’s Committee on International Information Activities** — [Washington,] June 30, 1953.  
   `frus1952-54v02p2/d370` · score -16.7150  
   > top secret [Washington,] June 30, 1953. [Here follow a table of contents and a list of appendices, of which all but Appendix II are printed.] Letter of Transmittal June 30, 1953. Dear Mr. President: We submit herewith the report of the President’s Committee on International Information Activities.…
7. **300. Response to National Security Study Memorandum 156** — Washington, September 1, 1972  
   `frus1969-76ve07/d300` · score -13.4355  
   > In response to NSSM 156, the NSC Interdepartmental Group for Near East and South Asia assessed India’s nuclear capabilities and intentions and U.S. options for influencing India on the issue. Washington, September 1, 1972 SUMMARY Indian Capabilities/Intentions At present India’s relatively…

### Semantic (query prompt)

1. **Draft Department of State Policy Statement** — Washington, undated.  
   `frus1951v04p2/d302` · score 0.8298  
   > Copies of interoffice memoranda attached to the source text indicate that this draft policy statement was prepared in the Office of Eastern European Affairs, and received working-level clearances by EUR, UNA, PD, UNP, P, TRC, and ITP, apparently during January, February, and March 1951. In a…
2. **41. Memorandum From the President’s Assistant for National Security Affairs (Kissinger) to President Nixon** — Washington, October 20, 1969.  
   `frus1969-76v01/d41` · score 0.8211  
   > SUBJECT Analysis of changes in international politics since World War II and their implications for our basic assumptions about U.S. foreign policy In your meeting with the NSC Staff on October 2 you expressed the view that many basic aspects of international politics have changed during the past…
3. **No. 25 Memorandum by the Assistant to the Secretary of State (Bohlen)** — [Moscow,] May 27, 1945.  
   `frus1945Berlinv01/d25` · score 0.8181  
   > Memorandum by the Assistant to the Secretary of State (Bohlen) top secret [Moscow,] May 27, 1945. Memorandum of 2 nd Conversation at the Kremlin, 8 pm May 27 Present: Mr. Hopkins, Ambassador Harriman, Mr. Bohlen Marshal Stalin, Mr. Molotov, Mr. Pavlov Subjects: Subjects about which Stalin expressed…
4. **Memorandum by the Assistant Secretary of State for Public Affairs (Barrett)** — [Washington,] January 29, 1951.  
   `frus1951v01/d323` · score 0.8179  
   > The memorandum was discussed on February 6 by the Under Secretary’s Advisory Committee, a small group including several of the principal officers of the Department of State, who met weekly to discuss major policy problems. According to the record of the February 6 meeting, those present included…
5. **153. Memorandum From Helmut Sonnenfeldt of the National Security Council Staff to the President’s Assistant for National Security Affairs (Kissinger)** — Washington, March 24, 1971.  
   `frus1969-76v13/d153` · score 0.8163  
   > SUBJECT Soviet Party Congress Bill Hyland and I have had a series of discussions over the last few weeks with the best Sovietologists in the Government. Without necessarily attributing all our views of the CPSU Congress and Soviet developments generally to any of them, attached are two memoranda on…
6. **United States Delegation Minutes** — Bermuda, December 4, 1958.  
   `frus1952-54v05p2/d341` · score 0.8162  
   > The U.S. Delegation transmitted to Washington a summary of the plenary part of the first meeting in Secto 5, from Bermuda, Dec. 5. (396.1/12–553) This telegram was repeated to London, Paris, Bonn, and Moscow and states that President Eisenhower assumed the chair for the meeting at the request of…
7. **17. National Intelligence Estimate** — Washington, February 26, 1958  
   `frus1958-60v03mSupp/d17` · score 0.8129  
   > NIE 100–58 (Supersedes NIE 100–3–57) Washington, February 26, 1958 ESTIMATE OF THE WORLD SITUATION TABLE OF CONTENTS I. INTRODUCTION II. CHANGES IN THE WORLD SITUATION A. The Strategic Situation B. Soviet Progress and Policy C. Psychological Impact of Soviet and US Policies III. KEY AREAS OF…
8. **No. 44 Summary Minutes of the Chiefs of Mission Meeting at Vienna, September 22–24, 1953** — [Vienna,?] September 29, 1953.  
   `frus1952-54v08/d44` · score 0.8124  
   > Summary Minutes of the Chiefs of Mission Meeting at Vienna, September 22–24, 1953 The summary minutes were divided into six major sections: the five printed here, arranged according to the five sessions held during the three-day meeting, and a summary, entitled “Principal Conclusions,” not printed,…
9. **The Chargé in Latvia (Cole) to the Acting Secretary of State** — Riga, November 23, 1933. [Received December 5.]  
   `frus1933-39/d47` · score 0.8115  
   > Sir: I have the honor to enclose a translation in full Not printed. of the leading editorial in the Moscow Izvestiya, organ of the Central Executive Committee of the Union of the Soviet Socialist Republics, No. 282, of November 20, 1933, concerning the recognition of the Union by the United States.…
10. **252. Northern European Chiefs of Mission Conference, London, September 19–21, 1957: Summary of Proceedings** — London, September 19–21, 1957  
   `frus1955-57v04/d252` · score 0.8108  
   > Participants American Embassy, London— Ambassador John Hay Whitney Minister Walworth Barbour American Embassy, Reykjavik— Ambassador John J. Muccio Joseph Carwell, Counselor USRO, Paris— Ambassador George W. Perkins American Embassy, Helsinki— Ambassador John D. Hickerson Mose L. Harvey, Counselor…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **8. Address by Ronald Reagan** — Chicago, August 18, 1980  
   `frus1981-88v01/d8` · score 0.9725  
   > [Omitted here are Reagan’s introductory remarks and the portion of his address dealing with the Veterans Administration.] These are matters of great concern to your great organization. Let us turn now to a matter which vitally concerns our nation — “PEACE”. It has always struck me as odd that you…
2. **69. Background Press Briefing by the President’s Assistant for National Security Affairs (Kissinger)** — New Orleans, Louisiana, August 14, 1970.  
   `frus1969-76v01/d69` · score 0.9581  
   > [Omitted here are Klein’s introductions and Kissinger’s opening remarks.] I will talk to you for a bit about our general approach to foreign policy, and specifically also about the disarmament talks, relations with the Soviets and Vietnam, maybe a word about the Middle East. Then Secretary Sisco…
3. **108. Memorandum of Conversation** — Beijing, May 20, 1978, 3:30–6:40 p.m.  
   `frus1977-80v13/d108` · score 0.9534  
   > SUBJECT Summary of Dr. Brzezinski’s Meeting with Foreign Minister Huang Hua PARTICIPANTS Zbigniew Brzezinski, Assistant to the President for National Security Affairs Leonard Woodcock, United States Ambassador to the People’s Republic of China Richard Holbrooke, Assistant Secretary of State for…
4. **147. Address by President Carter** — Philadelphia, Pennsylvania, May 9, 1980  
   `frus1977-80v01/d147` · score 0.9528  
   > Chairman Yarnall and President Bodine, Reference is to D. Robert Yarnall, Jr., Chairman of the Board of Directors and William Bodine, Jr., President. Members of Congress, ladies and gentlemen: [Omitted here are the President’s introductory remarks.] For the past 6 months, all of our policies abroad…
5. **99. Address by President Reagan** — Eureka, Illinois, May 9, 1982  
   `frus1981-88v01/d99` · score 0.9503  
   > Address at Commencement Exercises at Eureka College in Illinois President Gilbert, President of Eureka College Daniel Gilbert. trustees, administration and faculty, students, and the friends of Eureka College, and particularly those whose day this is, the graduating class of ’82: Dan, you said the…
6. **35. Address by President Nixon** — Annapolis, Maryland, June 5, 1974.  
   `frus1969-76v38p1/d35` · score 0.9486  
   > Pragmatism and Moral Force in American Foreign Policy [Omitted here are Nixon’s introductory remarks.] When the war ended in Europe and Asia in 1945, America was the only economic and military superpower in the world. Most of Europe and Japan were in ruins—economically exhausted, politically…
7. **192. Remarks by President Reagan** — Washington, April 6, 1984  
   `frus1981-88v01/d192` · score 0.9474  
   > Remarks at the National Leadership Forum of the Center for Strategic and International Studies of Georgetown University Thank you very much, Ann Armstrong. Thank you, Cochairman Sam Nunn. I am honored to have this opportunity to take part in your National Leadership Forum. The CSIS reputation for…
8. **306. Remarks by President Reagan** — Los Angeles, August 26, 1987  
   `frus1981-88v01/d306` · score 0.9460  
   > Remarks on Soviet-United States Relations at the Town Hall of California Meeting in Los Angeles Before we begin, I hope you’ll forgive me for saying that it’s good to be back in California. Actually, I didn’t realize how completely I made the transition from Washington until I got on a helicopter…
9. **52. Remarks by President Carter** — Charleston, South Carolina, July 21, 1977  
   `frus1977-80v01/d52` · score 0.9453  
   > And I want to talk to you today about the hopes and problems that we as southerners and as Americans share together. I feel a special kinship with your State legislators. For 4 years I was a member of the Georgia Senate, and I still prize State government not only for the talents of those who work…
10. **12. Remarks by President Nixon** — Washington, May 24, 1973.  
   `frus1969-76v38p1/d12` · score 0.9451  
   > Now, let me come to the briefing and why I decided to have a briefing. Incidentally, we had first thought it would be a classified briefing, but while we knew there was no problem insofar as leaks as far as this group was concerned, our friends in the press very vigorously objected, and they said,…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 7/10.*
*document variant:* frus1951v04p2/d302, frus1969-76v01/d41, frus1951v01/d323, frus1969-76v13/d153, frus1958-60v03mSupp/d17, frus1955-57v04/d252, frus1952-54v05p2/d341, frus1952-54v08/d44, frus1950v01/d62, frus1950v01/d85
*bare variant:* frus1951v04p2/d302, frus1951v01/d323, frus1969-76v01/d41, frus1952-54v05p2/d341, frus1933-39/d47, frus1955-57v04/d252, frus1933v02/d609, frus1950v04/d701, frus1958-60v10p1/d62, frus1945Berlinv01/d25

---

## Q11. At what point did U.S. decision makers determine that the Nationalists couldn't prevail in the Chinese Civil War?

### Lexical — `"at" AND "what" AND "point" AND "did" AND "u.s." AND "decision" AND "makers" AND "determine" AND "that" AND "the" AND "nationalists" AND "couldn't" AND "prevail" AND "in" AND "the" AND "chinese" AND "civil" AND "war?"`

*(no results)*

### Semantic (query prompt)

1. **Memorandum of Conversation, by Mr. John Foster Dulles, Consultant to the Secretary of State** — [New York,] October 27, 1950.  
   `frus1950v06/d331` · score 0.8078  
   > secret [New York,] October 27, 1950. Participants H. E. Dr. Tingfu F. Tsiang, China Mr. John Foster Dulles, U.S.A. Mr. John M. Allison, U.S.A. Subject: Formosa Dr. Tsiang called, pursuant to appointment, to discuss with us the question of Formosa. He said that he was concerned lest our policy of…
2. **Minutes of Briefing Session of the United States Delegation to the General Assembly, Washington, Department of State, September 7, 1950, 3:00 p. m.** — Washington, September 7, 1950, 3:00 p.m.  
   `frus1950v02/d161` · score 0.8046  
   > secret [Here follows list of representatives and alternate representatives present (8).] 1. Chinese Representation Under the Chairmanship of Ambassador Austin, the Delegation continued its briefing meeting in the afternoon. The first briefing meeting, held on the morning of September 7, was chaired…
3. **Note by Rear Admiral Sidney W. Souers, Executive Secretary to the National Security Council** — [Washington,] July 26, 1948.  
   `frus1948v08/d105` · score 0.8040  
   > NSC 22 [Washington,] July 26, 1948. Possible Courses of Action for the U. S. With Respect to the Critical Situation in China At the request of the Secretary of the Army the enclosed paper assessing the current critical situation in China and outlining alternative courses of action is circulated…
4. **Draft of New China News Agency**  
   `frus1946v09/d645` · score 0.7964  
   > Manifesto of the Central Executive Committee of the Chinese Communist Party in Commemoration of the 9 th Anniversary of the “7 th of July” Draft from New China News Agency, July 7, on the 9th anniversary of the outbreak of the undeclared war between China and Japan at Marco Polo Bridge, near…
5. **Colonel David D. Barrett to Major General Albert C. Wedemeyer** — [Yenan,] December 10, 1944.  
   `frus1944v06/d524` · score 0.7948  
   > Subject: Interview with Chairman Mao Tzu-tung. 1. On November [December] 8, 1944, I had a long interview with Mao Tzu-tung, Chairman of the Central Committee of the Chinese Communist Party, and Chow En-lai, Vice-Chairman of the same committee. I opened the interview by saying I had been informed…
6. **Memorandum by Mr. James R. Shepley to General Marshall** — [En route to Nanking,] 19 December 1945.  
   `frus1945v07/d560` · score 0.7927  
   > Memorandum by Mr. James R. Shepley Member of the Marshall Mission, designated as Attaché to the Embassy in China. to General Marshall [En route to Nanking,] 19 December 1945. General Marshall: On the basis of information to date, Colonel Byroade Col. Henry A. Byroade, member of the Marshall…
7. **The Ambassador in China (Stuart) to the Secretary of State** — Nanking, January 1, 1947. [Received January 1—11:06 a.m.]  
   `frus1946v10/d359` · score 0.7909  
   > Following are Chou En-lai’s Head of the Chinese Communist Party delegtation during the 1946 negotiations with General Marshall and the Chinese Government. comments on President Truman’s statement, December 18, 1946: Department of State, United States Relations With China (Washington, Government…
8. **The Ambassador in China (Hurley) to President Truman** — [Chungking,] 20 May, 1945.  
   `frus1945v07/d73` · score 0.7899  
   > Notation on the original: “Copy to General Marshall and to Admiral King.” Copy obtained from former President Harry S. Truman. [Chungking,] 20 May, 1945. 201118. Lord Louis Mountbatten and the diplomatic, commercial and military representatives of the other nations with colonial interests in Asia…
9. **204. National Intelligence Estimate** — Washington, April 16, 1955.  
   `frus1955-57v02/d204` · score 0.7899  
   > A note on the cover sheet reads as follows: “Submitted by the Director of Central Intelligence. The following intelligence organizations participated in the preparation of this estimate: The Central Intelligence Agency and the intelligence organizations of the Departments of State, the Army, the…
10. **The Ambassador in China (Stuart) to the Secretary of State** — Nanking, October 28, 1948. [Received November 8.]  
   `frus1948v07/d418` · score 0.7885  
   > Sir: I have the honor once more to supplement our cabled reports by a few more general comments on the rapidly worsening outlook for the National Government. The Embassy has urged in substance that in view of this outlook American policy should be decided upon as early as current issues in the two,…

### PRF — centroid of the lexical top-5, no encoder (0 seeds)

*(no seeds — PRF amplifies lexical search and cannot rescue a query it returned nothing for)*

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 7/10.*
*document variant:* frus1948v08/d105, frus1950v06/d331, frus1950v02/d161, frus1955-57v02/d204, frus1946v09/d645, frus1948v08/d122, frus1948v07/d418, frus1946v10/d359, frus1940v04/d503, frus1945v07/d560
*bare variant:* frus1950v06/d331, frus1948v08/d105, frus1950v02/d161, frus1946v09/d645, frus1944v06/d524, frus1948v08/d122, frus1946v10/d359, frus1948v07/d418, frus1946v09/d745, frus1945v07/d2

---

## Q12. Deposing shah

### Lexical — `"deposing" AND "shah"`

1. **Minister Pearson to the Secretary of State.** — Teheran, August 12, 1906.  
   `frus1906p2/d327` · score -16.8129  
   > (Mr. Pearson states that popular agitation, similar to that in Russia, demanding constitutional reforms but less violent, has triumphed in Persia. Rioting in Teheran, resulting in killing 117 persons, including two Seyids, descendants of Mahomet, insurgents and other advocates of greater liberty…
2. **279. Telegram From the Embassy in Italy to the Department of State** — Rome, August 18, 1953, 8 p.m.  
   `frus1951-54Iran/d279` · score -16.6340  
   > Shah arrived Rome early this afternoon (reference Baghdad’s 97 and Tehran’s 374 to Department). Not found. Associated Press has given Embassy following on what it believes exclusive interview with Shah: Asked about Iranian Foreign Minister’s demand that he abdicate, he said “I am not (repeat not)…
3. **279. Telegram From the Embassy in Italy to the Department of State** — Rome, August 18, 1953, 8 p.m.  
   `frus1951-54IranEd2/d279` · score -16.6340  
   > Shah arrived Rome early this afternoon (reference Baghdad’s 97 and Tehran’s 374 to Department). Not found. Associated Press has given Embassy following on what it believes exclusive interview with Shah: Asked about Iranian Foreign Minister’s demand that he abdicate, he said “I am not (repeat not)…
4. **The Chargé in Iran (Ford) to the Secretary of State** — Tehran, December 16, 1943—3 p.m. [Received 5:45 p.m.]  
   `frus1943v04/d437` · score -16.3776  
   > New Cabinet, 1125, December 16, is regarded locally as clear victory for Shah who has been able to place his own candidates in a majority of Cabinet posts. Soheily has also gained his ends and strengthened his position by eliminating the opposing elements in the previous Cabinet including Tadayyon,…
5. **The Acting Secretary of State to the American Minister.** — Department of State, Washington, July 31, 1911.  
   `frus1911/d988` · score -16.3748  
   > In view of alarmist press telegrams, report concisely by telegraph concerning the political situation, with particular reference to the return of the deposed Shah and the attitude of the British and Russian Governments toward the internal situation and toward the American financial advisers. Adee.
6. **No. 316 The Ambassador in Iran (Henderson) to the Department of State** — Tehran, March 10, 1953—1 p.m.  
   `frus1952-54v10/d316` · score -14.6162  
   > The Ambassador in Iran (Henderson) to the Department of State Transmitted in two sections; also sent to London and pouched to Ankara, Baghdad, Cairo, and Dhahran. secret priority Tehran, March 10, 1953—1 p.m. 3627. 1. Department will have noted we have not as yet presented our ideas as to why…
7. **No. 250. Mr. Gibbs to Mr. Evarts.** — Legation of the United States, Lima, Peru, June 12, 1877. (Received July 9.)  
   `frus1877/d250` · score -14.0564  
   > Sir: Since my dispatch No. 159, of 9th instant, an apparent conspiracy to change the government was attempted and has failed. The excitement of the affair of the Huascar and Her Britannic Majesty’s ships Shah and Amethyst had subsided, but a deep feeling remained against the government by charges…
8. **The Ambassador in Iran (Murray) to the Secretary of State** — Tehran, June 26, 1945—9 a.m. [Received June 26—6:35 a.m.]  
   `frus1945v08/d349` · score -13.6014  
   > Dept’s instruction of Feb 28, 1945. Not printed. In view of unavoidable delay in reporting sooner by written despatch on the delivery to the Shah on June 5 last of my letters of credence and the audience I had with him following the ceremonies of presentation, I believe the Dept may be interested…
9. **291. Memorandum of Discussion at the 449th Meeting of the National Security Council** — Washington, June 30, 1960.  
   `frus1958-60v12/d291` · score -13.3913  
   > [Here follow a paragraph listing the participants at the meeting and agenda item 1.] 2. Significant World Developments Affecting U.S. Security [Here follows discussion of unrelated matters by Acting Director of Central Intelligence Cabell.] Turning to Iran, General Cabell reported that relations…
10. **393. Despatch From the Embassy in Iran to the Department of State** — Tehran, March 11, 1957.  
   `frus1955-57v12/d393` · score -12.5485  
   > REF Embdes 736, December 20, 1951 Not printed. (Ibid., 788.11/12–2051) SUBJECT The Shah of Iran, 1957—A Revised Study Enclosed is a memorandum entitled The Shah of Iran, 1957—A Revised Study, prepared by Second Secretary Thomas A. Cassilly before his recent transfer from this post. Mr. Cassilly’s…

### Semantic (query prompt)

1. **118. Memorandum Prepared by Max Thornburg** — August 22, 1952.  
   `frus1951-54Iran/d118` · score 0.7602  
   > What would we have to do? Make up our own minds, promptly, concerning three things: (1) Our own readiness to back the Shah in establishing a “responsible” government, by which we would mean, among other things, one loyal to the Shah, dedicated to necessary reforms within the country, willing to…
2. **118. Memorandum Prepared by Max Thornburg** — August 22, 1952.  
   `frus1951-54IranEd2/d118` · score 0.7602  
   > What would we have to do? Make up our own minds, promptly, concerning three things: (1) Our own readiness to back the Shah in establishing a “responsible” government, by which we would mean, among other things, one loyal to the Shah, dedicated to necessary reforms within the country, willing to…
3. **393. Despatch From the Embassy in Iran to the Department of State** — Tehran, March 11, 1957.  
   `frus1955-57v12/d393` · score 0.7600  
   > REF Embdes 736, December 20, 1951 Not printed. (Ibid., 788.11/12–2051) SUBJECT The Shah of Iran, 1957—A Revised Study Enclosed is a memorandum entitled The Shah of Iran, 1957—A Revised Study, prepared by Second Secretary Thomas A. Cassilly before his recent transfer from this post. Mr. Cassilly’s…
4. **205. Despatch From the Embassy in Iran to the Department of State** — Tehran, May 19, 1953.  
   `frus1951-54IranEd2/d205` · score 0.7555  
   > REF Embassy Despatch 953, May 15, 1953 Document 204. SUBJECT Further Conversation with Source Close to Shah There is attached for the information of the Department a memorandum of a conversation which I had on May 17 with an emissary of the Shah in the presence of several members of the Embassy. A…
5. **205. Despatch From the Embassy in Iran to the Department of State** — Tehran, May 19, 1953.  
   `frus1951-54Iran/d205` · score 0.7555  
   > REF Embassy Despatch 953, May 15, 1953 Document 204. SUBJECT Further Conversation with Source Close to Shah There is attached for the information of the Department a memorandum of a conversation which I had on May 17 with an emissary of the Shah in the presence of several members of the Embassy. A…
6. **180. Intelligence Report 2035–72** — Washington, May 1972  
   `frus1969-76ve04/d180` · score 0.7548  
   > The CIA’s Directorate of Intelligence analyzed the current political structure of Iran. Washington, May 1972 Centers of Power in Iran A Mountain Village, Typical of Most of Iran A Modern Housing Development, Still Limited to a Few Urban Areas The study of politics is the study of influence and the…
7. **No. 301 The Ambassador in Iran (Henderson) to the Department of State** — Tehran, February 22, 1953—2 p.m.  
   `frus1952-54v10/d301` · score 0.7548  
   > The Ambassador in Iran (Henderson) to the Department of State Transmitted in three sections; also sent to London. top secret priority Tehran, February 22, 1953—2 p.m. 3334. 1. Ala, Minister of Court, asked see me this morning. He said he wished discuss “most serious recent development”. On evening…
8. **110. Telegram From the Embassy in Iran to the Department of State** — Tehran, November 28, 1965, 1730Z.  
   `frus1964-68v22/d110` · score 0.7544  
   > Country Team message. Shah and U.S. 1. Fathoming the Shah. To understand Iran one must understand Shah. This is not one-shot undertaking. Shah’s personality undergoes steady metamorphosis. To understand current developments, such as authorization to borrow up to $200,000,000 for military purposes…
9. **166. Telegram From the Embassy in Iran to the Department of State** — Tehran, February 28, 1953, 5 p.m.  
   `frus1951-54IranEd2/d166` · score 0.7513  
   > Early this morning stories regarding imminent departure Shah pouring in from many sources. These stories had conflicting details. Altho some reflected confusion and bewilderment, there seemed be general impression that Shah’s decision depart was in some way connected with friction between him and…
10. **166. Telegram From the Embassy in Iran to the Department of State** — Tehran, February 28, 1953, 5 p.m.  
   `frus1951-54Iran/d166` · score 0.7512  
   > Early this morning stories regarding imminent departure Shah pouring in from many sources. These stories had conflicting details. Altho some reflected confusion and bewilderment, there seemed be general impression that Shah’s decision depart was in some way connected with friction between him and…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **279. Telegram From the Embassy in Italy to the Department of State** — Rome, August 18, 1953, 8 p.m.  
   `frus1951-54Iran/d279` · score 0.9385  
   > Shah arrived Rome early this afternoon (reference Baghdad’s 97 and Tehran’s 374 to Department). Not found. Associated Press has given Embassy following on what it believes exclusive interview with Shah: Asked about Iranian Foreign Minister’s demand that he abdicate, he said “I am not (repeat not)…
2. **279. Telegram From the Embassy in Italy to the Department of State** — Rome, August 18, 1953, 8 p.m.  
   `frus1951-54IranEd2/d279` · score 0.9373  
   > Shah arrived Rome early this afternoon (reference Baghdad’s 97 and Tehran’s 374 to Department). Not found. Associated Press has given Embassy following on what it believes exclusive interview with Shah: Asked about Iranian Foreign Minister’s demand that he abdicate, he said “I am not (repeat not)…
3. **237. Telegram From the Embassy in Iran to the Department of State** — Tehran, July 13, 1953, 11 a.m.  
   `frus1951-54IranEd2/d237` · score 0.9035  
   > Belgian Minister who had audience with Shah yesterday tells me in strict confidence that Shah still very strongly desires to take trip (re my 42, July 7) Document 235. and is endeavoring arrange with Italian Government for invitation. However, CAS source close to Shah states that Shah much…
4. **237. Telegram From the Embassy in Iran to the Department of State** — Tehran, July 13, 1953, 11 a.m.  
   `frus1951-54Iran/d237` · score 0.9028  
   > Belgian Minister who had audience with Shah yesterday tells me in strict confidence that Shah still very strongly desires to take trip (re my 42, July 7) Document 235. and is endeavoring arrange with Italian Government for invitation. However, CAS source close to Shah states that Shah much…
5. **284. Telegram From the Central Intelligence Agency [text not declassified]** — Washington, August 19, 1953.  
   `frus1951-54IranEd2/d284` · score 0.8996  
   > DIR 16330. 1. New State instruction follows. (These instructions should be carried out by Ambassador Baghdad in event Shah leaves Rome for Baghdad.) A. Discreet contact should be established with _____ of the _____ or designate. B. Shah should be urged strongly to make or reiterate public…
6. **284. Telegram From the Central Intelligence Agency [text not declassified]** — Washington, August 19, 1953.  
   `frus1951-54Iran/d284` · score 0.8996  
   > DIR 16330. 1. New State instruction follows. (These instructions should be carried out by Ambassador Baghdad in event Shah leaves Rome for Baghdad.) A. Discreet contact should be established with _____ of the _____ or designate. B. Shah should be urged strongly to make or reiterate public…
7. **The Acting Secretary of State to the American Minister.** — Department of State, Washington, July 31, 1911.  
   `frus1911/d988` · score 0.8986  
   > In view of alarmist press telegrams, report concisely by telegraph concerning the political situation, with particular reference to the return of the deposed Shah and the attitude of the British and Russian Governments toward the internal situation and toward the American financial advisers. Adee.
8. **272. Telegram From the Central Intelligence Agency [text not declassified]** — Washington, August 17, 1953.  
   `frus1951-54Iran/d272` · score 0.8972  
   > DIR 16090. 1. Reference your priority message of 17 August. The reference is presumably to [text not declassified]. In view extra sensitivity this matter we have been requested by State to convey [1½ lines not declassified]. 2. State considers your handling of situation exemplary under…
9. **272. Telegram From the Central Intelligence Agency [text not declassified]** — Washington, August 17, 1953.  
   `frus1951-54IranEd2/d272` · score 0.8969  
   > DIR 16090. 1. Reference your priority message of 17 August. The reference is presumably to [text not declassified]. In view extra sensitivity this matter we have been requested by State to convey [1½ lines not declassified]. 2. State considers your handling of situation exemplary under…
10. **266. Telegram From the Embassy in Iran to the Department of State** — Tehran, August 16, 1953, 3 p.m.  
   `frus1951-54IranEd2/d266` · score 0.8938  
   > Late morning August 16, correspondents Donald Schwind, Associated Press, and Kennett Love, New York Times, went to hills north of Tehran at request son of General Zahedi for conference. Zahedi not present, but son showed signed decree from Shah and gave photostats of it to newsmen. Decree, signed…

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 8/10.*
*document variant:* frus1969-76ve04/d180, frus1955-57v12/d393, frus1951-54Iran/d118, frus1951-54IranEd2/d118, frus1964-68v22/d110, frus1961-63v17/d27, frus1969-76v27/d121, frus1964-68v22/d29, frus1961-63v17/d247, frus1951-54IranEd2/d166
*bare variant:* frus1969-76ve04/d180, frus1955-57v12/d393, frus1951-54Iran/d118, frus1951-54IranEd2/d118, frus1964-68v22/d110, frus1952-54v10/d301, frus1961-63v17/d27, frus1951-54IranEd2/d166, frus1951-54Iran/d166, frus1951-54IranEd2/d353

---

## Q13. Diego Garcia base

### Lexical — `"diego" AND "garcia" AND "base"`

1. **46. Memorandum From Secretary of Defense McNamara to the Secretary of the Navy (Ignatius)** — Washington, October 27, 1967.  
   `frus1964-68v21/d46` · score -27.0490  
   > SUBJECT Austere Support Facility on Diego Garcia (S) Last February the Navy sent forward a proposal to construct a $26 million “austere” support facility on Diego Garcia, whether or not the British participate in its funding and use, because there would be money advantages to refueling carriers…
2. **86. Minutes of the Secretary of State’s Staff Regional Staff Meeting** — Washington, April 25, 1975, 8 a.m.  
   `frus1969-76ve08/d86` · score -26.1600  
   > The Secretary and his principal staff members discussed the Soviet position on the Indian Ocean, the Soviet base at Berbera, and Diego Garcia in relation to international initiatives to remove bases from the Indian Ocean. Washington, April 25, 1975, 8 a.m. PRESENT: THE SECRETARY OF STATE— HENRY A.…
3. **65. Memorandum From the Deputy Assistant Secretary of Defense for European and NATO Affairs (Bergold) to the Deputy Assistant Secretary of Defense for Security Assistance (Peet)** — Washington, January 17, 1974.  
   `frus1969-76ve08/d65` · score -25.5552  
   > Assistant Secretary Harold Bergold informed Vice Admiral Ray Peet of the British response to the United States’ Diego Garcia expansion proposal. Washington, January 17, 1974. SUBJECT: Diego Garcia (S) John Wilberforce of the British Embassy came into State this afternoon to give the UK answer on…
4. **87. Minutes of the Senior Review Group Meeting** — Washington, May 6, 1975, 4:16–5:04 p.m.  
   `frus1969-76ve08/d87` · score -25.5186  
   > The Senior Review Group met to formulate a policy on the Indian Ocean and Diego Garcia based on the study conclusions from NSSM 199. Washington, May 6, 1975, 4:16–5:04 p.m. Subject: Indian Ocean Participants: Chairman: Henry A. Kissinger State: Robert Ingersoll Helmut Sonnenfeldt George Vest Tom…
5. **126. Memorandum From Secretary of Defense Brown to Secretary of State Vance and the President’s Assistant for National Security Affairs (Brzezinski)** — Washington, November 3, 1979  
   `frus1977-80v18/d126` · score -25.2060  
   > SUBJECT Diego Garcia You will recall our discussion at lunch on October 25 of further upgrading of the facilities at Diego Garcia. At the Vance - Brown - Brzezinski luncheon on October 25, the principals decided that a tentative go-ahead for upgrading would be given; the Department of Defense was…
6. **69. Memorandum From Secretary of State Kissinger to President Nixon** — Washington, February 25, 1974.  
   `frus1969-76ve08/d69` · score -24.9555  
   > Secretary of State Kissinger provided President Nixon with a draft reply to Prime Minister Bandaranaike’s letter of February 11 regarding Diego Garcia. Washington, February 25, 1974. SUBJECT: Reply to Letter from Sri Lanka Prime Minister At Tab B is a letter to you from Prime Minister Bandaranaike…
7. **89. Memorandum of Conversation** — Washington, July 16, 1975, 11 a.m.  
   `frus1969-76ve08/d89` · score -24.6955  
   > Secretary of Defense James Schlesinger briefed the President about recent developments regarding Berbera and the status of Diego Garcia funding in Congress. Washington, July 16, 1975, 11 a.m. SUBJECT: President’s Meeting with the Cabinet [Omitted here is material unrelated to Diego Garcia.]…
8. **129. Briefing Memorandum From the Director of the Bureau of Politico-Military Affairs (Bartholomew) to Secretary of State Muskie** — Washington, June 30, 1980  
   `frus1977-80v18/d129` · score -24.6501  
   > Diego Garcia In Ankara, my British counterpart and I formalized a new side understanding (to the 1976 US – UK Agreement) See footnote 3, Document 126. on the use of Diego Garcia (attached). Attached but not printed is a June 13 memorandum of conversation detailing Bartholomew’s discussions with…
9. **47. Memorandum From the Joint Chiefs of Staff to Secretary of Defense McNamara** — Washington, April 10, 1968.  
   `frus1964-68v21/d47` · score -24.4660  
   > SUBJECT Proposal for a Joint US Military Facility on Diego Garcia (U) JCSM -226-68 1. (S) Reference is made to: a. JCSM -420-67, dated 25 July 1967, subject: “Proposed Naval Facility on Diego Garcia (S),” Document 45. which recommended funding the first increment of construction ($13 million) in…
10. **40. Memorandum From the Assistant Secretary of Defense for International Security Affairs (Nutter) to Secretary of Defense Laird** — Washington, March 17, 1970.  
   `frus1969-76v24/d40` · score -24.3812  
   > SUBJECT Diego Garcia I–21269/70 The purpose of this memorandum is to identify precisely the nature of your decision regarding the proposed US communications facility on Diego Garcia. Although the attached Navy recommendation Not attached. The proposal is in a memorandum from Chafee to Laird,…

### Semantic (query prompt)

1. **39. Paper Prepared in the Office of the Chief of Naval Operations (Moorer)** — Washington, February 11, 1970.  
   `frus1969-76v24/d39` · score 0.8031  
   > Diego Garcia—Background and Status The Navy has long recognized the strategic importance of gaining a modest logistics support capability in the Indian Ocean. In recognition of this need a Navy Strategic Island Concept was developed in 1959 and approved by JCS in 1960. In essence it calls for a…
2. **65. Memorandum From the Deputy Assistant Secretary of Defense for European and NATO Affairs (Bergold) to the Deputy Assistant Secretary of Defense for Security Assistance (Peet)** — Washington, January 17, 1974.  
   `frus1969-76ve08/d65` · score 0.7979  
   > Assistant Secretary Harold Bergold informed Vice Admiral Ray Peet of the British response to the United States’ Diego Garcia expansion proposal. Washington, January 17, 1974. SUBJECT: Diego Garcia (S) John Wilberforce of the British Embassy came into State this afternoon to give the UK answer on…
3. **126. Memorandum From Secretary of Defense Brown to Secretary of State Vance and the President’s Assistant for National Security Affairs (Brzezinski)** — Washington, November 3, 1979  
   `frus1977-80v18/d126` · score 0.7896  
   > SUBJECT Diego Garcia You will recall our discussion at lunch on October 25 of further upgrading of the facilities at Diego Garcia. At the Vance - Brown - Brzezinski luncheon on October 25, the principals decided that a tentative go-ahead for upgrading would be given; the Department of Defense was…
4. **46. Memorandum From Secretary of Defense McNamara to the Secretary of the Navy (Ignatius)** — Washington, October 27, 1967.  
   `frus1964-68v21/d46` · score 0.7857  
   > SUBJECT Austere Support Facility on Diego Garcia (S) Last February the Navy sent forward a proposal to construct a $26 million “austere” support facility on Diego Garcia, whether or not the British participate in its funding and use, because there would be money advantages to refueling carriers…
5. **86. Minutes of the Secretary of State’s Staff Regional Staff Meeting** — Washington, April 25, 1975, 8 a.m.  
   `frus1969-76ve08/d86` · score 0.7750  
   > The Secretary and his principal staff members discussed the Soviet position on the Indian Ocean, the Soviet base at Berbera, and Diego Garcia in relation to international initiatives to remove bases from the Indian Ocean. Washington, April 25, 1975, 8 a.m. PRESENT: THE SECRETARY OF STATE— HENRY A.…
6. **44. Memorandum From the Secretary of the Navy (Nitze) to Secretary of Defense McNamara** — Washington, February 24, 1967.  
   `frus1964-68v21/d44` · score 0.7744  
   > Ser 001653 Washington, February 24, 1967. SUBJECT Proposed Limited Support Facility on Diego Garcia (S) 1. I believe we should reconsider the decision made last fall that approval for the proposed limited support facility at Diego Garcia would depend on substantial British participation and…
7. **80. Telegram 201428 From the Department of State to the Embassies in India and Thailand** — Washington, September 13, 1974, 0008Z.  
   `frus1969-76ve08/d80` · score 0.7742  
   > The Department replied at length to Ambassador Daniel P. Moynihan’s concerns regarding Diego Garcia and affirmed the administration’s policy on the expansion of the facility. Washington, September 13, 1974, 0008Z. Subject: Diego Garcia Refs: (A) New Delhi 11114; (B) Bangkok 13687 (NOTAL); (C) State…
8. **40. Memorandum From the Assistant Secretary of Defense for International Security Affairs (Nutter) to Secretary of Defense Laird** — Washington, March 17, 1970.  
   `frus1969-76v24/d40` · score 0.7738  
   > SUBJECT Diego Garcia I–21269/70 The purpose of this memorandum is to identify precisely the nature of your decision regarding the proposed US communications facility on Diego Garcia. Although the attached Navy recommendation Not attached. The proposal is in a memorandum from Chafee to Laird,…
9. **37. Memorandum From the Assistant Secretary of State for Near Eastern and South Asian Affairs (Sisco) to Secretary of State Rogers** — Washington, June 24, 1969.  
   `frus1969-76v24/d37` · score 0.7724  
   > SUBJECT Congressional Hearings on Diego Garcia Information Memorandum Representatives of the Defense Department will testify before the House Armed Services Committee on June 30 regarding plans to construct communications and refueling facilities on the island of Diego Garcia in the Chagos…
10. **66. Letter From the Chairman of the Senate Committee on Armed Services (Stennis) to Secretary of Defense Schlesinger** — Washington, January 29, 1974.  
   `frus1969-76ve08/d66` · score 0.7654  
   > Senator John C. Stennis of Mississippi requested that the Department of Defense provide a plan and rationale for the expansion of Diego Garcia. Schlesinger replied on February 16. Washington, January 29, 1974. Dear Mr. Secretary: According to recent press reports, and subsequently confirmed by…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **65. Memorandum From the Deputy Assistant Secretary of Defense for European and NATO Affairs (Bergold) to the Deputy Assistant Secretary of Defense for Security Assistance (Peet)** — Washington, January 17, 1974.  
   `frus1969-76ve08/d65` · score 0.9580  
   > Assistant Secretary Harold Bergold informed Vice Admiral Ray Peet of the British response to the United States’ Diego Garcia expansion proposal. Washington, January 17, 1974. SUBJECT: Diego Garcia (S) John Wilberforce of the British Embassy came into State this afternoon to give the UK answer on…
2. **126. Memorandum From Secretary of Defense Brown to Secretary of State Vance and the President’s Assistant for National Security Affairs (Brzezinski)** — Washington, November 3, 1979  
   `frus1977-80v18/d126` · score 0.9494  
   > SUBJECT Diego Garcia You will recall our discussion at lunch on October 25 of further upgrading of the facilities at Diego Garcia. At the Vance - Brown - Brzezinski luncheon on October 25, the principals decided that a tentative go-ahead for upgrading would be given; the Department of Defense was…
3. **87. Minutes of the Senior Review Group Meeting** — Washington, May 6, 1975, 4:16–5:04 p.m.  
   `frus1969-76ve08/d87` · score 0.9474  
   > The Senior Review Group met to formulate a policy on the Indian Ocean and Diego Garcia based on the study conclusions from NSSM 199. Washington, May 6, 1975, 4:16–5:04 p.m. Subject: Indian Ocean Participants: Chairman: Henry A. Kissinger State: Robert Ingersoll Helmut Sonnenfeldt George Vest Tom…
4. **44. Memorandum From the Secretary of the Navy (Nitze) to Secretary of Defense McNamara** — Washington, February 24, 1967.  
   `frus1964-68v21/d44` · score 0.9415  
   > Ser 001653 Washington, February 24, 1967. SUBJECT Proposed Limited Support Facility on Diego Garcia (S) 1. I believe we should reconsider the decision made last fall that approval for the proposed limited support facility at Diego Garcia would depend on substantial British participation and…
5. **39. Paper Prepared in the Office of the Chief of Naval Operations (Moorer)** — Washington, February 11, 1970.  
   `frus1969-76v24/d39` · score 0.9410  
   > Diego Garcia—Background and Status The Navy has long recognized the strategic importance of gaining a modest logistics support capability in the Indian Ocean. In recognition of this need a Navy Strategic Island Concept was developed in 1959 and approved by JCS in 1960. In essence it calls for a…
6. **66. Letter From the Chairman of the Senate Committee on Armed Services (Stennis) to Secretary of Defense Schlesinger** — Washington, January 29, 1974.  
   `frus1969-76ve08/d66` · score 0.9389  
   > Senator John C. Stennis of Mississippi requested that the Department of Defense provide a plan and rationale for the expansion of Diego Garcia. Schlesinger replied on February 16. Washington, January 29, 1974. Dear Mr. Secretary: According to recent press reports, and subsequently confirmed by…
7. **86. Minutes of the Secretary of State’s Staff Regional Staff Meeting** — Washington, April 25, 1975, 8 a.m.  
   `frus1969-76ve08/d86` · score 0.9293  
   > The Secretary and his principal staff members discussed the Soviet position on the Indian Ocean, the Soviet base at Berbera, and Diego Garcia in relation to international initiatives to remove bases from the Indian Ocean. Washington, April 25, 1975, 8 a.m. PRESENT: THE SECRETARY OF STATE— HENRY A.…
8. **47. Memorandum From the Joint Chiefs of Staff to Secretary of Defense McNamara** — Washington, April 10, 1968.  
   `frus1964-68v21/d47` · score 0.9259  
   > SUBJECT Proposal for a Joint US Military Facility on Diego Garcia (U) JCSM -226-68 1. (S) Reference is made to: a. JCSM -420-67, dated 25 July 1967, subject: “Proposed Naval Facility on Diego Garcia (S),” Document 45. which recommended funding the first increment of construction ($13 million) in…
9. **80. Telegram 201428 From the Department of State to the Embassies in India and Thailand** — Washington, September 13, 1974, 0008Z.  
   `frus1969-76ve08/d80` · score 0.9235  
   > The Department replied at length to Ambassador Daniel P. Moynihan’s concerns regarding Diego Garcia and affirmed the administration’s policy on the expansion of the facility. Washington, September 13, 1974, 0008Z. Subject: Diego Garcia Refs: (A) New Delhi 11114; (B) Bangkok 13687 (NOTAL); (C) State…
10. **46. Memorandum From Secretary of Defense McNamara to the Secretary of the Navy (Ignatius)** — Washington, October 27, 1967.  
   `frus1964-68v21/d46` · score 0.9230  
   > SUBJECT Austere Support Facility on Diego Garcia (S) Last February the Navy sent forward a proposal to construct a $26 million “austere” support facility on Diego Garcia, whether or not the British participate in its funding and use, because there would be money advantages to refueling carriers…

*Route overlap: 5 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 9/10.*
*document variant:* frus1969-76ve08/d65, frus1969-76v24/d39, frus1969-76ve08/d86, frus1969-76v35/d38, frus1977-80v18/d126, frus1964-68v21/d46, frus1946v01/d595, frus1969-76v24/d40, frus1969-76v24/d37, frus1969-76ve08/d80
*bare variant:* frus1969-76v24/d39, frus1969-76ve08/d65, frus1969-76ve08/d86, frus1977-80v18/d126, frus1964-68v21/d49, frus1969-76ve08/d80, frus1969-76ve08/d66, frus1969-76v24/d37, frus1964-68v21/d44, frus1964-68v21/d46

---

## Q14. Space aliens
*null control*

### Lexical — `"space" AND "aliens"`

1. **The Consul General at Shanghai (Cabot) to the Secretary of State** — Shanghai, December 13, 1948—midnight. [Received December 14—1:57 p.m.]  
   `frus1948v08/d858` · score -14.5568  
   > ReEmbtel 1231, December 9, Sent to the Department as telegram No. 2469, p. 924. evacuation foreign nationals. Statement mytel 1990 Sent to the Department as telegram No. 2637, December 3, 8 p.m., p. 913. that Navy may be unable help other foreign communities even in emergency based on statement…
2. **The Secretary of State to the Consul General at Rangoon (Schnare)** — Washington, February 4, 1942—9 p.m.  
   `frus1942v01/d192` · score -14.4319  
   > Your 106, January 31, 1 p.m. Extra space made available by emergency consular certificates issued under discretionary authority given you by Department’s 51, December 20, may be utilized only for American citizens and their accompanying alien spouses and unmarried minor alien children properly…
3. **The Ambassador in the United Kingdom (Kennedy) to the Secretary of State** — London, October 3, 1939—8 p.m. [Received October 3—6:15 p.m.]  
   `frus1939v01/d661` · score -13.8385  
   > Your 1131, September 30. We have been looking into the charges of alleged discrimination against American citizens on American vessels and we are inclined to believe that there is no basis for this accusation. It has been the policy of this Embassy and of the United States Lines throughout the…
4. **The Ambassador in China (Stuart) to the Secretary of State** — Nanking, December 9, 1948. [Received December 9—8:23 a.m.]  
   `frus1948v08/d847` · score -13.8161  
   > Evacuation policy as agreed upon by Department, Embassy, and Naval authorities has been that foreign nationals would be accorded facilities on space available basis. Inquiries from foreign diplomatic representatives have been uniformly answered in this sense and this policy has been followed in…
5. **The Acting Secretary of State to Certain Diplomatic and Consular Officers** — Washington, February 20, 1942—10 p.m.  
   `frus1942v01/d199` · score -13.7193  
   > Sent to diplomatic officers at London, with instructions to repeat to all seaport consular offices in the British Isles; Cairo (to repeat to Alexandria, Port Said, and Suez); Reykjavik; Monrovia; and to consular officers at Aden; Basra; Batavia (to repeat to Surabaya); Belfast; Calcutta (to repeat…
6. **Extract from the Constitution of May 23, 1845.** — [May 23, 1845.]  
   `frus1873p1v2/d217` · score -13.0122  
   > Part I.—Article I. “Spaniards are— “1. All persons born within the dominions of Spain. “2. The children of a Spanish father and mother, though born out of the dominions of Spain. “3. Aliens who have obtained a certificate of naturalization. “4. Those who, without having obtained such certificate,…
7. **The Minister in Switzerland (Harrison) to the Secretary of State** — Bern, June 25, 1943. [Received June 25—6:26 p.m.]  
   `frus1943v03/d732` · score -12.7582  
   > American interests Far East, repatriation. Department’s 1311, 2d, and 1333, 4th. Department’s telegrams under reference transmitted Swiss Legation, Tokyo, which replied that in its opinion geographic allotment space described Legation’s 5751, December 8 Not printed; it transmitted allocations…
8. **383. Memorandum From Maxwell W. Hunter II of the National Aeronautics and Space Council to Robert F. Packard of the Office of International Scientific Affairs** — Washington, July 18, 1963.  
   `frus1961-63v25/d383` · score -12.6161  
   > SUBJECT Thoughts on the Space Alien Race Question During recent discussions the question has occasionally, though rarely, arisen that perhaps we should consider the policy question of what to do if an alien intelligence is discovered in space. Some discussion of this occurred, as you will recall,…
9. **The Assistant Secretary of Labor (White) to the Assistant Secretary of State (Carr)** — Washington, April 22, 1927.  
   `frus1927v01/d360` · score -12.0232  
   > My Dear Mr. Carr: Enclosed find copy of General Order No. 86, outlining land border crossing procedure, which may be of interest to your Department, particularly, as it may greatly increase the applications for non-quota visas at some of your consulates. I am informed this phase of the question was…
10. **Bear Admiral C. W. Styer, of the Office of Chief of Naval Operations, to the Director of the Office of Far Eastern Affairs (Butterworth)** — Washington, 8 January 1948.  
   `frus1948v08/d257` · score -12.0219  
   > Ser: 004P35 (SC) A14–7/EF16 Washington, 8 January 1948. My Dear Mr. Butterworth: The following information is submitted in response to your letter of 26 December 1947, (Paragraph numbers correspond):– 1. The Joint Chiefs of Staff in August 1945 charged the Commanding General, China, with…

### Semantic (query prompt)

1. **383. Memorandum From Maxwell W. Hunter II of the National Aeronautics and Space Council to Robert F. Packard of the Office of International Scientific Affairs** — Washington, July 18, 1963.  
   `frus1961-63v25/d383` · score 0.7438  
   > SUBJECT Thoughts on the Space Alien Race Question During recent discussions the question has occasionally, though rarely, arisen that perhaps we should consider the policy question of what to do if an alien intelligence is discovered in space. Some discussion of this occurred, as you will recall,…
2. **479. Report by the National Aeronautics and Space Council** — Washington, January 26, 1960.  
   `frus1958-60v02/d479` · score 0.7015  
   > On December 17, 1959, the National Aeronautics and Space Council transmitted a draft of this report to the National Security Council. Designated NSC 5918, it was considered by the Council at its 321st meeting on January 12, 1960, and minor revisions and deletions were made. A copy of NSC 5918 is…
3. **442. National Security Council Report** — Washington, August 18, 1958.  
   `frus1958-60v02/d442` · score 0.6955  
   > NSC 5814/1 STATEMENT OF PRELIMINARY U.S. POLICY ON OUTER SPACE Introductory Note The USSR has surpassed the United States and the Free World in scientific and technological accomplishments in outer space, which have captured the imagination and admiration of the world. The USSR, if it maintains its…
4. **55. Department of State Policy Paper** — Washington, October 1966.  
   `frus1964-68v34/d55` · score 0.6850  
   > SPACE GOALS AFTER THE LUNAR LANDING Summary Even before the outcome of the moon race has been decided, we face the question of whether to commit ourselves to still more ambitious programs—proceeding with manned exploration of the moon after the initial landing; mounting large-scale scientific…
5. **23. Report Prepared by the Committee on National Security Policy Planning Implications of Outer Space in the 1970s, Basic National Security Policy Planning Task I (1)** — Washington, January 30, 1964.  
   `frus1964-68v34/d23` · score 0.6834  
   > [Here follow a title page, table of contents, two-page preface, and a list of Committee members.] PLANNING IMPLICATIONS FOR NATIONAL SECURITY OF OUTER SPACE IN THE 1970s Conclusions A The implications of exploration and use of outer space in the 1970’s indicate clearly that, from the viewpoint of…
6. **104. Telegram 703 From the Mission to the United Nations to the Department of State** — New York, March 6, 1975, 2344Z  
   `frus1969-76ve03/d104` · score 0.6735  
   > The telegram summarized an initiative to define outer space proposed at the Legal Sub-Committee meeting of the UN Outer Space Committee. New York, March 6, 1975, 2344Z Subj: Outer Space Legal Subcommittee: Definition of Outer Space 1. Summary: France and Argentina called for adoption of a…
7. **43. Letter From Chairman Khrushchev to President Kennedy** — Moscow, March 20, 1962.  
   `frus1961-63v06/d43` · score 0.6694  
   > Dear Mr. President: Having carefully familiarized myself with your message of March 7 Document 41. of this year, I note with satisfaction that my communication to you of February 21 Document 35. containing the proposal that our two countries unite their efforts for the conquest of space has met…
8. **Proclamation No. 1408, November 16, 1917, Setting Forth Additional Regulations Prescribing Conduct toward Alien Enemies** — November 16, 1917  
   `frus1918Supp02/d178` · score 0.6651  
   > By the President of the United States of America A PROCLAMATION Whereas the Congress of the United States in the exercise of the constitutional authority vested in them have resolved, by joint resolution of the Senate and House of Representatives bearing date of April 6th, 1917, “That the state of…
9. **127. Telegram 2755 From the Mission to the United Nations to the Department of State** — New York, July 2, 1976, 2250Z  
   `frus1969-76ve03/d127` · score 0.6645  
   > The Mission communicated the delegation’s appraisal of the 1976 session of the UN Outer Space Committee. New York, July 2, 1976, 2250Z Subj: Outer Space Committee: Wrap-up 1. Summary-Outer Space Committee concluded July 2 with relatively routine report recommending continued work on existing…
10. **438. Memorandum of a Conversation, Department of State, Washington, March 20, 1958** — Washington, March 20, 1958  
   `frus1958-60v02/d438` · score 0.6634  
   > SUBJECT Outer Space PARTICIPANTS Sir Leslie Munro, Ambassador, New Zealand Mr. H. P. Jeffery, First Secretary, New Zealand Embassy The Under Secretary Mr. Walmsley, IO Mr. Becker, L Mr. Spiers, S/AE Sir Leslie called at his request to discuss the problem of control of outer space. He noted that he…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **The Ambassador in China (Stuart) to the Secretary of State** — Nanking, December 9, 1948. [Received December 9—8:23 a.m.]  
   `frus1948v08/d847` · score 0.9351  
   > Evacuation policy as agreed upon by Department, Embassy, and Naval authorities has been that foreign nationals would be accorded facilities on space available basis. Inquiries from foreign diplomatic representatives have been uniformly answered in this sense and this policy has been followed in…
2. **The Consul General at Shanghai (Cabot) to the Secretary of State** — Shanghai, December 13, 1948—midnight. [Received December 14—1:57 p.m.]  
   `frus1948v08/d858` · score 0.9297  
   > ReEmbtel 1231, December 9, Sent to the Department as telegram No. 2469, p. 924. evacuation foreign nationals. Statement mytel 1990 Sent to the Department as telegram No. 2637, December 3, 8 p.m., p. 913. that Navy may be unable help other foreign communities even in emergency based on statement…
3. **The Secretary of State to the Consul General at Rangoon (Schnare)** — Washington, February 4, 1942—9 p.m.  
   `frus1942v01/d192` · score 0.9247  
   > Your 106, January 31, 1 p.m. Extra space made available by emergency consular certificates issued under discretionary authority given you by Department’s 51, December 20, may be utilized only for American citizens and their accompanying alien spouses and unmarried minor alien children properly…
4. **The Acting Secretary of State to Certain Diplomatic and Consular Officers** — Washington, February 20, 1942—10 p.m.  
   `frus1942v01/d199` · score 0.9134  
   > Sent to diplomatic officers at London, with instructions to repeat to all seaport consular offices in the British Isles; Cairo (to repeat to Alexandria, Port Said, and Suez); Reykjavik; Monrovia; and to consular officers at Aden; Basra; Batavia (to repeat to Surabaya); Belfast; Calcutta (to repeat…
5. **The Secretary of State to the Consul General at Singapore (Patton)** — Washington, January 26, 1942—5 p.m.  
   `frus1942v01/d187` · score 0.9108  
   > Department’s 197, December 26, 11 p.m. Not printed; it stated that the Department was making allotments to Batavia, Surabaya, Medan, Sydney, Ceylon, and Capetown for loans in connection with emergency repatriation or evacuation and temporary maintenance of American Citizens while awaiting…
6. **The Secretary of State to the Consul General at Batavia (Foote)** — Washington, December 18, 1941—9 p.m.  
   `frus1941v05/d503` · score 0.9108  
   > Sent as No. 51, December 20, 5 p.m., to the Consul at Rangoon (Brady) with respect to Burmese waters. Washington, December 18, 1941—9 p.m. 197. Maritime Commission is notifying all owners and operators of American ships operating in Netherlands Indian waters to make available to American citizens…
7. **The Secretary of State to the Minister in Egypt (Kirk)** — Washington, June 30, 1942—3 p.m.  
   `frus1942v01/d208` · score 0.9064  
   > Your 1048, June 22. Printed in vol. iv, section under Egypt entitled “Concern of the United States regarding effect of Axis military advance into Egypt …”. Telegraph briefly nature of evacuation plans referred to in your telegram under reference particularly whether they include provision for…
8. **The Ambassador in the United Kingdom (Kennedy) to the Secretary of State** — London, October 3, 1939—8 p.m. [Received October 3—6:15 p.m.]  
   `frus1939v01/d661` · score 0.9035  
   > Your 1131, September 30. We have been looking into the charges of alleged discrimination against American citizens on American vessels and we are inclined to believe that there is no basis for this accusation. It has been the policy of this Embassy and of the United States Lines throughout the…
9. **The Secretary of State to the Ambassador in the United Kingdom (Kennedy)** — Washington, September 27, 1939—3 p.m.  
   `frus1939v01/d655` · score 0.9020  
   > Your 1830, September 26, 5:30 P.M. First. It was always intended to send the Iroquois to a British port for repatriation service. The Acadia is not proceeding to England. She is sailing for Bordeaux, and if she has a full complement of passengers there, will proceed directly to the United States.…
10. **The Chargé in China (Strong) to the Secretary of State** — Canton, August 26, 1949—9 p. m. [Received August 27—12:33 a. m.]  
   `frus1949v09/d1355` · score 0.9002  
   > Cantel 1030. TelCan 550, August 11, repeated Shanghai 1582, Nanking 945, and Cantel 953, August 15. Following note dated August 24 received [from] Foreign Office: “The Ministry of Foreign Affairs presents its compliments to the American Embassy and has the honor to state that with reference to the…

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 6/10.*
*document variant:* frus1961-63v25/d383, frus1958-60v02/d479, frus1958-60v02/d442, frus1964-68v34/d55, frus1964-68v34/d23, frus1969-76ve01/d228, frus1961-63v25/d381, frus1964-68v34/d27, frus1964-68v11/d145, frus1961-63v06/d43
*bare variant:* frus1961-63v25/d383, frus1958-60v02/d479, frus1958-60v02/d442, frus1895p1/d552, frus1969-76ve03/d104, frus1977-80v26/d39, frus1969-76ve03/d127, frus1977-80v26/d48, frus1958-60v02/d446, frus1964-68v34/d23

---

## Q15. U.S.S. Liberty sinking
*wrong-premise probe (the Liberty was attacked, not sunk)*

### Lexical — `"u.s.s." AND "liberty" AND "sinking"`

1. **The Ambassador in Japan (Grew) to the Secretary of State** — Tokyo, September 29, 1941—noon. [Received 2:25 p.m.]  
   `frus1941v04/d359` · score -9.2147  
   > For the Secretary and Under Secretary only. 1. A review of our exchange of confidential telegrams since last spring pertaining to the preliminary conversations in Washington and Tokyo reveals the steadily increasing and latterly intensified efforts of Japanese Government to bring about without…
2. **Joint Chiefs of Staff Minutes** — Potsdam, July 24, 1945, 2:30 p.m.  
   `frus1945Berlinv02/d710a-90` · score -6.3241  
   > The papers of the Joint Chiefs of Staff indicate that “These Minutes were transcribed from notes taken by the United States Secretaries, Combined Chiefs of Staff.” Potsdam, July 24, 1945, 2:30 p.m. top secret General of the Army Antonov asked Fleet Admiral Leahy to preside at this, the first…
3. **United States Delegation Record, Council of Foreign Ministers, Second Session, Third Meeting, Paris, April 27, 1946, 4 p.m.** — Paris, April 27, 1946, 4 p.m.  
   `frus1946v02/d76` · score -6.0466  
   > For a list of persons present at this meeting, see the Record of Decisions, infra. Paris, April 27, 1946, 4 p.m. secret M. Molotov called upon the Chairman of the Deputies’ Meeting to present the Deputies’ report. Report of the Deputies Mr. Jebb stated that the Deputies proposed that the agenda of…
4. **Verbatim Record** — July 30, 1946, 4 p.m.  
   `frus1946v03/d18` · score -4.5532  
   > C.P.(Plen) 2 Chairman: M. Bidault (France) The Chairman: The list of speakers is as follows: the first Delegate of the United States of America, the first Delegate of the United Kingdom, and the first Delegate of the Republic of China. After that we shall hear the report of the Credentials…
5. **Mr. Stevens to Mr. Blaine.** — United States Legation, Honolulu, June 9, 1890.  
   `frus1894app2/d134` · score -4.5219  
   > Sir: I improve the first mail opportunity to forward two copies of the speech of Hon. L. A. Thurston, Minister of Interior, just delivered in the Hawaiian Legislature. It is a clear, strong statement of facts, as I had previously ascertained them by careful investigation, and these plainly indicate…
6. **EXHIBIT V. Annex 1.** — [December 7, 1891 to November 5, 1892]  
   `frus1902app1/d30` · score -4.2443  
   > [Bark Cape Horn Pigeon —Log book. Season of 1892. Thomas Scullen, master.] Monday, December 7. —At 1.30 p.m. hove up anchor, and tug Sea Witch towed us out to Whising Buoy. At 3.30 tug let go, wind NE., ship steering SW. by S. All sail set at 6 p.m. Farallon light, bearing NW., distant 20 miles.…
7. **Thompson Minutes** — Potsdam, July 19, 1945, 5 p.m.  
   `frus1945Berlinv02/d710a-28` · score -4.1109  
   > top secret Bulgarian–Greek Frontier Incident Mr. Churchill said he wished to refer to a point which Stalin had raised at the previous meeting concerning an incident on the Bulgarian-Greek frontier. He had made inquiries. The British Government had heard of no fighting. These people did not like…
8. **Minister Dawson to the President.** — Washington, July 1, 1905.  
   `frus1905/d345` · score -3.9508  
   > memorandum on the dominican modus vivendi, its effects up to the present time, and the reasons that lead to its adoption. The financial modus vivendi put into effect April 1 by a decree of the Dominican Government was the natural outcome of the situation—the logical development from what had gone…
9. **Report of the Special Representative of the United States Government (House)**  
   `frus1917Supp02v01/d370` · score -2.6365  
   > This and the following reports, which were submitted to Colonel House, pp. 334 – 445, comprise the report of the American War Mission to England and France, November, 1917. The mission was composed of the following: Edward M. House, Special Representative of the United States Government; In the…
10. **210. Letter From the President’s Military Representative (Taylor) to the President** — Washington, November 3, 1961.  
   `frus1961-63v01/d210` · score -1.2247  
   > This letter and its attachments are in a binder entitled “Report on General Taylor’s Mission to South Vietnam, 3 November 1961,” which also includes a table of contents. The source text is Tab A. At 4 p.m. on November 3, the President greeted at the White House all the returning members of the…

### Semantic (query prompt)

1. **284. Intelligence Memorandum Prepared in the Central Intelligence Agency** — Washington, June 13, 1967.  
   `frus1964-68v19/d284` · score 0.7983  
   > SC No. 01415/67 Washington, June 13, 1967. THE ISRAELI ATTACK ON THE USS LIBERTY The US Naval technical research ship Liberty was attacked by Israeli aircraft and torpedo boats off the Sinai Peninsula on 8 June. The following account of the circumstances of the attack has been compiled from all…
2. **219. Memorandum for the Record** — Washington, June 8, 1967, 3:30 p.m.  
   `frus1964-68v19/d219` · score 0.7736  
   > SUBJECT The USS Liberty (AGTR–5) Struck by Torpedo 1. At 080911 EDT June, USCINCEUR notified the NMCC by phone that the USS Liberty was under attack, had been hit by a torpedo and was listing to starboard. The ship was operating in the Mediterranean Sea approximately 60–70 miles east-northeast of…
3. **204. Editorial Note**  
   `frus1964-68v19/d204` · score 0.7718  
   > On June 8, 1967, at 8:03 a.m. Eastern Daylight Time (1203Z; p.m. local time), the U.S.S. Liberty was attacked and hit by unidentified jet fighters, which made six strafing runs. Twenty minutes later the ship was attacked by three torpedo boats. One torpedo hit the starboard side. At the time, the…
4. **234. Memorandum for the Record** — Washington, June 9, 1967, 3:26 p.m.  
   `frus1964-68v19/d234` · score 0.7705  
   > SUBJECT Attack on USS Liberty (AGTR–5) 1. This memorandum updates and supplements memoranda, same subject, of 1530 EDT 8 June and 0600 EDT 9 June 1967. Document 219; the June 9 memorandum was not found. 2. USS Liberty had been directed by JCS to proceed to 32–00N; 33–00E, a point 39 nautical miles…
5. **373. Memorandum From the Chairman of the President’s Foreign Intelligence Advisory Board (Clifford) to the President’s Special Assistant (Rostow)** — Washington, July 18, 1967.  
   `frus1964-68v19/d373` · score 0.7604  
   > SC No. 07445/67 Washington, July 18, 1967. SUBJECT The Israeli Attack on the USS Liberty In accordance with your request, I have reviewed all available information on the subject. Based thereon, I submit the enclosed memorandum which deals with the question of Israeli culpability. In the event…
6. **46. Telegram From the Director of the National Security Agency (Carter) to the Joint Chiefs of Staff/Joint Reconnaissance Center** — Washington, May 23, 1967, 1729Z.  
   `frus1964-68v19/d46` · score 0.7604  
   > “M /R: The present situation in the Middle East has resulted in NSA declaring a SIGINT readiness Bravo. In order to augment coverage in the area, the diversion of the USS Liberty (USN 855) is considered a necessary course of action in view of the Liberty’ s excellent collection, processing and…
7. **285. Memorandum From the Director of the Bureau of Intelligence and Research (Hughes) to Acting Secretary of State Katzenbach** — Washington, June 13, 1967.  
   `frus1964-68v19/d285` · score 0.7554  
   > SUBJECT INR Comments on the USS Liberty Incident, June 8 According to a radio report from the USS Liberty, two unidentified delta-wing jet fighters orbited the ship at 0650Z on June 8 at an estimated altitude of 5000 feet and at a distance of two miles. A subsequent sitrep from the Liberty…
8. **352. Diplomatic Note From Secretary of State Rusk to the Israeli Ambassador (Harman)** — Washington, June 10, 1967.  
   `frus1964-68v19/d352` · score 0.7482  
   > The Secretary of State presents his compliments to His Excellency the Ambassador of Israel and has the honor to refer to the Ambassador’s Note of June 10, 1967 concerning the attacks by Israeli aircraft and torpedo boats on the United States naval vessel U.S.S. Liberty, which were carried out…
9. **210. Memorandum of Telephone Conversations** — Washington, June 8, 1967, 10:15 a.m. and 11 a.m.  
   `frus1964-68v19/d210` · score 0.7444  
   > SUBJECT USS Liberty PARTICIPANTS Mr. Yuri N. Tcherniakov, Soviet Chargé d’Affaires a.i. Mr. Foy D. Kohler, Deputy Under Secretary Mr. Kohler informed the Chargés that he had an urgent message for the Soviet Government. An American ship, the USS Liberty, was torpedoed a few hours ago off Port Said.…
10. **205. Memorandum From the President’s Special Assistant (Rostow) to President Johnson** — Washington, June 8, 1967, 9:50 a.m.  
   `frus1964-68v19/d205` · score 0.7429  
   > Mr. President: We have a flash report from the Joint Reconnaissance Center indicating that a U.S. elint (electronics intelligence) ship, the Liberty, has been torpedoed in the Mediterranean. The ship is located 60–100 miles north of Egypt. At 10:15 a.m., National Security Agency Director General…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **Report of the American Delegation, February 9, 1922**  
   `frus1922v01/d88` · score 0.9546  
   > To the President: The undersigned, appointed by the President as Commissioners to represent the Government of the United States at the Conference on Limitation of Armament, have the honor to submit the following report of the Proceedings of the Conference. On July 8, 1921, by direction of the…
2. **Report of the Special Representative of the United States Government (House)**  
   `frus1917Supp02v01/d370` · score 0.9538  
   > This and the following reports, which were submitted to Colonel House, pp. 334 – 445, comprise the report of the American War Mission to England and France, November, 1917. The mission was composed of the following: Edward M. House, Special Representative of the United States Government; In the…
3. **Memorandum by Bishop James E. Walsh, Superior General of the Catholic Foreign Mission Society of America**  
   `frus1941v04/d395` · score 0.9428  
   > Notation on file copy: “Document left with the Secretary of State by Bishop Walsh on November 15, 1941.” 1. Story. The October 2nd reply from Washington Oral statement, Foreign Relations, Japan, 1931–1941, vol. ii, p. 656. shook the confidence of the entire Japanese Government. With some difficulty…
4. **Notes of a Meeting Held at President Wilson’s House in the Place des Etats-Unis, Paris, on Wednesday, June 25, 1919, at 4 p.m.** — Paris, June 25, 1919, 4 p.m.  
   `frus1919Parisv06/d75` · score 0.9389  
   > CF–92 Notes of a Meeting Held at President Wilson’s House in the Place des Etats-Unis, Paris, on Wednesday, June 25, 1919, at 4 p.m. Paris, June 25, 1919, 4 p.m. Present United States of America President Wilson. British Empire The Rt. Hon. D. Lloyd George, M. P. France M. Clemenceau. Italy M.…
5. **Report by the Under Secretary of State (Welles) on His Special Mission to Europe** — Rome, February 26, 1940.  
   `frus1940v01/d28` · score 0.9366  
   > Photostatic copy obtained from the Franklin D. Roosevelt Library, Hyde Park, N. Y. This report, in the form of a separate memorandum for each conversation, was apparently brought back by Mr. Welles when he returned to Washington on March 29, 1940. Rome, February 26, 1940. At 10 a.m. on Monday,…
6. **The Military Representative on the Supreme War Council (Bliss) to the Secretary of State** — Washington, February 19, 1920.  
   `frus1914-20v02/d147` · score 0.9365  
   > Sir: I have the honor to submit, herewith, my report on the Supreme War Council. A duplicate copy has been handed to the Secretary of War. Very respectfully, Tasker H. Bliss [Enclosure] The Military Representative on the Supreme War Council (Bliss) to the Secretary of State Washington, February 6,…
7. **Notes of a Meeting of the Heads of Delegations of the Five Great Powers Held in M. Pichon’s Room, Quai d’Orsay, Paris, on Monday, December 1, 1919, at 10:30 a.m.** — Paris, December 1, 1919, 10:30 a.m.  
   `frus1919Parisv09/d19` · score 0.9359  
   > HD–103 Notes of a Meeting of the Heads of Delegations of the Five Great Powers Held in M. Pichon’s Room, Quai d’Orsay, Paris, on Monday, December 1, 1919, at 10:30 a.m. Paris, December 1, 1919, 10:30 a.m. Present America, United States of Hon. F. L. Polk Secretary Mr. L. Harrison British Empire Sir…
8. **Memorandum Prepared in the Department of State** — [Washington,] May 19, 1942.  
   `frus1931-41v02/d237` · score 0.9356  
   > ACCOUNT OF INFORMAL CONVERSATIONS BETWEEN THE GOVERNMENT OF THE UNITED STATES AND THE GOVERNMENT OF JAPAN, 1941 Introductory As the year 1941 opened, a vast movement of political forces throughout the world was intensely active. The Axis grouping among Germany, Italy and Japan had been formalized…
9. **The Under Secretary of State (Stettinius) to the Secretary of State** — [Washington,] May 22, 1944.  
   `frus1944v03/d1` · score 0.9354  
   > My Dear Mr. Secretary: It gives me pleasure to transmit to you herewith a report on the conversations carried on in London on your behalf from April 7th to April 29th, 1944. As directed by you and the President, the objective of our Mission was to exchange views with members of the British…
10. **Notes of a Meeting of the Heads of Delegations of the Five Great Powers Held in M. Pichon’s Room at the Quai d’Orsay, Paris, on Thursday, September 25, 1919, at 10:30 a.m.** — Paris, September 25, 1919, 10:30 a.m.  
   `frus1919Parisv08/d19` · score 0.9345  
   > HD–60 Notes of a Meeting of the Heads of Delegations of the Five Great Powers Held in M. Pichon’s Room at the Quai d’Orsay, Paris, on Thursday, September 25, 1919, at 10:30 a.m. Paris, September 25, 1919, 10:30 a.m. Present America, United States of Hon. F. L. Polk Secretary Mr. L. Harrison British…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 4/10.*
*document variant:* frus1964-68v19/d284, frus1917Supp01v01/d156, frus1964-68v19/d204, frus1915Supp/d909, frus1964-68v19/d46, frus1916Supp/d308, frus1964-68v19/d234, frus1964-68v19/d373, frus1964-68v19/d219, frus1964-68v19/d352
*bare variant:* frus1964-68v19/d284, frus1964-68v19/d204, frus1964-68v19/d234, frus1964-68v19/d219, frus1915Supp/d909, frus1914-20v02/d53, frus1916Supp/d308, frus1931-41v01/d387, frus1917Supp01v01/d156, frus1964-68v19/d319

---

## Q16. How did Kissinger manage the State Department?

### Lexical — `"how" AND "did" AND "kissinger" AND "manage" AND "the" AND "state" AND "department?"`

1. **90. Minutes of Secretary of State Kissinger’s Regional Staff Meeting** — Washington, July 1, 1976.  
   `frus1969-76v35/d90` · score -14.9763  
   > [Omitted here is discussion unrelated to national security policy.] Secretary Kissinger: Well, this just can’t be bought off. We have to fight it. We cannot buy off. The question is whether human rights is the only objective of American foreign policy, and that’s what it’s rapidly coming down to.…
2. **139. Memorandum of Conversation** — Washington, October 7, 1974, 10:30 a.m.  
   `frus1969-76v38p2/d139` · score -13.7985  
   > PARTICIPANTS Henry A. Kissinger, Secretary of State Robert S. Ingersoll, Deputy Secretary of State Joseph J. Sisco, Under Secretary for Political Affairs L. Dean Brown, Deputy Under Secretary for Management Arthur A. Hartman, Assistant Secretary for European Affairs Nathaniel Davis, Director…
3. **11. Minutes of the Secretary of State’s Staff Meeting** — Washington, October 22, 1974, 9–10:10 a.m.  
   `frus1969-76v37/d11` · score -13.5611  
   > Secretary Kissinger: Tom. Mr. Enders: As I reported to you, the French have political objections to going ahead at an official level in the Camp David follow-up. See Document 10. These objections may prove to be less firm than they are right at the moment, if we proceed with floating our ideas in a…
4. **42. Memorandum of Conversation** — Washington, August 13, 1974.  
   `frus1969-76v38p1/d42` · score -13.5347  
   > SUBJECT Highlights of Secretary Kissinger’s OFF THE RECORD Breakfast with Time, Inc., Madison Room, Department of State, August 13, 1974. Present at the breakfast were Henry A. Kissinger, Secretary of State Hedley Donovan, Editor-in-Chief Henry Grunwald, Managing Editor Murray Gart, Assistant…
5. **86. Minutes of Secretary of State Kissinger’s Principals and Regionals Staff Meeting** — Washington, June 27, 1975.  
   `frus1969-76v22/d86` · score -13.2352  
   > [Omitted here are a list of attendees and discussion of unrelated matters.] Mr. Rogers: Torrijos’ response to the press yesterday was tempered. On June 27, Panamanian newspapers reported that Torrijos remained confident that the “United States would live up to its commitment to negotiate” despite…
6. **350. Memorandum of Conversation** — Washington, November 21, 1973.  
   `frus1969-76v25/d350` · score -13.1781  
   > SUBJECT Meeting Between the Secretary and Syrian UN Permanent Representative Kaylani PARTICIPANTS Haytham Kaylani, Syrian Permanent Representative to the UN Diya’allah al-Bettal, Director, UN Department, Syrian Ministry of Foreign Affairs Henry A. Kissinger, Secretary of State Joseph J. Sisco,…
7. **144. Memorandum of Conversation** — Washington, June 5, 1975, 6:30–7:30 p.m.  
   `frus1969-76v38p2/d144` · score -13.0272  
   > PARTICIPANTS Secretary Kissinger Deputy Secretary Ingersoll Ambassador Carol Laise, Director General Mr. Lawrence S. Eagleburger, Deputy Under Secretary for Management Mr. L.P. Bremer, Executive Assistant to the Secretary Mr. Wesley W. Egan, Jr., Notetaker SUBJECT “The Professional Service of the…
8. **230. Memorandum From the Assistant Director, Office of Management and Budget (Schlesinger) to the Director (Shultz)** — Washington, May 11, 1971.  
   `frus1969-76v02/d230` · score -12.9803  
   > SUBJECT Reorganizing the Intelligence Community This memorandum is intended to apprise you of the several responses within the intelligence community to the Overview paper, One of two attachments to Document 229. which has been distributed on a highly selected basis. Copies went to the DCI, DOD,…
9. **218. Memorandum of Conversation** — Washington, November 19, 1976, 3 p.m.  
   `frus1969-76v38p2/d218` · score -12.9418  
   > PARTICIPANTS Secretary Kissinger Deputy Secretary Robinson Under Secretary William Rogers Under Secretary Philip Habib Deputy Under Secretary for Management Eagleburger Mr. Winston Lord, Policy/Planning Staff General Scowcroft, Director— NSC Mr. Bill Hyland, NSC Jock Covey, notetaker SUBJECT…
10. **177. Minutes of Secretary of State Kissinger’s Staff Meeting** — Washington, October 29, 1973, 3:15 p.m.  
   `frus1969-76v39/d177` · score -12.8797  
   > PRESENT The Secretary of State: Henry A. Kissinger Kenneth Rush William J. Porter Curtis W. Tarr Jack B. Kubisch Arthur W. Hummel, Jr. George S. Springsteen David D. Newsom Robert J. McCloskey Alfred L. Atherton George Aldrich Thomas R. Pickering Winston Lord Lawrence S. Eagleburger [Omitted here…

### Semantic (query prompt)

1. **117. Editorial Note**  
   `frus1969-76v38p2/d117` · score 0.8642  
   > Following President Nixon’s inauguration for a second term on January 20, 1973, William P. Rogers remained as Secretary of State, but the President had already determined that Rogers’ remaining tenure would be brief. Shortly after his re-election on November 7, 1972, President Nixon, in…
2. **139. Memorandum of Conversation** — Washington, October 7, 1974, 10:30 a.m.  
   `frus1969-76v38p2/d139` · score 0.8351  
   > PARTICIPANTS Henry A. Kissinger, Secretary of State Robert S. Ingersoll, Deputy Secretary of State Joseph J. Sisco, Under Secretary for Political Affairs L. Dean Brown, Deputy Under Secretary for Management Arthur A. Hartman, Assistant Secretary for European Affairs Nathaniel Davis, Director…
3. **53. Editorial Note**  
   `frus1969-76v38p1/d53` · score 0.8351  
   > On March 31, 1975, Secretary of State Henry Kissinger met with Dean Rusk, Cyrus Vance, McGeorge Bundy, George Shultz, Douglas Dillon, W. Averell Harriman, Robert McNamara, David Rockefeller, George Ball, William Scranton, Peter G. Peterson, David K.E. Bruce, John McCloy, Lawrence Eagleburger, and…
4. **95. Editorial Note**  
   `frus1969-76v13/d95` · score 0.8347  
   > On January 14, 1971, Assistant to the President for National Security Affairs Henry Kissinger received a telephone call at 7:22 p.m. from Yuli Vorontsov, the Soviet Chargé d’Affaires. According to the transcript, the conversation included the following brief exchange: “V: Dr. Kissinger, I have got…
5. **29. Editorial Note**  
   `frus1969-76v02/d29` · score 0.8336  
   > Early in the Nixon administration the President’s Assistant for National Security Affairs Henry Kissinger began the practice of maintaining special direct channels of communication with some foreign officials and U.S. Ambassadors, bypassing the Department of State. The Kissinger –Dobrynin channel,…
6. **137. Memorandum of Conversation** — Washington, September 27, 1974, 11:30 a.m.  
   `frus1969-76v38p2/d137` · score 0.8319  
   > PARTICIPANTS The Secretary The Deputy Secretary The Undersecretary for Political Affairs, Mr. Sisco Deputy Undersecretary, Ambassador Brown Director General, Ambassador Davis Assistant Secretary Hartman Mr. Eagleburger Jerry Bremer, Notetaker Kissinger: I just wanted to spend ten minutes with you…
7. **84. Interview With Secretary of State Kissinger** — Washington, undated.  
   `frus1969-76v38p1/d84` · score 0.8289  
   > Q. A number of serious charges have been made against you, and the Times thought you should have the opportunity to answer them. The first charge is that in a solemn world you tried to be funny. Secretary Kissinger: In this job you have only two choices: you are either funny deliberately or you are…
8. **24. Memorandum of Conversation** — Washington, March 29, 1973, 11:05 a.m.–noon.  
   `frus1969-76v18/d24` · score 0.8243  
   > PARTICIPANTS Ambassador David Bruce, Chief-designate of US Liaison Office in Peking Dr. Henry A. Kissinger, Assistant to the President Alfred leS. Jenkins, Deputy-designate of US Liaison Office John H. Holdridge, Deputy-designate of US Liaison Office Peter W. Rodman, NSC Staff Dr. Kissinger: David,…
9. **14. Memorandum of Conversation** — Beijing, February 19, 1973, 12:35–2:20 a.m.  
   `frus1969-76v18/d14` · score 0.8210  
   > PARTICIPANTS Chou En-lai, Premier, State Council Chi P’eng-fei, Minister of Foreign Affairs Ch’iao Kuan-hua, Vice Minister of Foreign Affairs Chang Wen-chin, Assistant Minister of Foreign Affairs Wang Hai-jung, Assistant to Minister of Foreign Affairs T’ang Wen-sheng, Interpreter Shen Jo-yun,…
10. **80. Memorandum of Conversation** — Washington, December 9, 1970, 1–2:45 p.m.  
   `frus1969-76v01/d80` · score 0.8187  
   > PARTICIPANTS Hedley Donovan Hugh Sidey William Mader Herman Nichol John Steele Henry A. Kissinger David R. Young (note taker) The luncheon opened with a general discussion about the student movement. Mr. Kissinger explained that when he met with the students around the time of the Cambodian…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **139. Memorandum of Conversation** — Washington, October 7, 1974, 10:30 a.m.  
   `frus1969-76v38p2/d139` · score 0.9588  
   > PARTICIPANTS Henry A. Kissinger, Secretary of State Robert S. Ingersoll, Deputy Secretary of State Joseph J. Sisco, Under Secretary for Political Affairs L. Dean Brown, Deputy Under Secretary for Management Arthur A. Hartman, Assistant Secretary for European Affairs Nathaniel Davis, Director…
2. **218. Memorandum of Conversation** — Washington, November 19, 1976, 3 p.m.  
   `frus1969-76v38p2/d218` · score 0.9489  
   > PARTICIPANTS Secretary Kissinger Deputy Secretary Robinson Under Secretary William Rogers Under Secretary Philip Habib Deputy Under Secretary for Management Eagleburger Mr. Winston Lord, Policy/Planning Staff General Scowcroft, Director— NSC Mr. Bill Hyland, NSC Jock Covey, notetaker SUBJECT…
3. **137. Memorandum of Conversation** — Washington, September 27, 1974, 11:30 a.m.  
   `frus1969-76v38p2/d137` · score 0.9474  
   > PARTICIPANTS The Secretary The Deputy Secretary The Undersecretary for Political Affairs, Mr. Sisco Deputy Undersecretary, Ambassador Brown Director General, Ambassador Davis Assistant Secretary Hartman Mr. Eagleburger Jerry Bremer, Notetaker Kissinger: I just wanted to spend ten minutes with you…
4. **64. Minutes of the Secretary of State’s Staff Meeting** — Washington, November 13, 1975, 8–9:10 a.m.  
   `frus1969-76v35/d64` · score 0.9470  
   > [Omitted here is discussion unrelated to national security policy.] Secretary Kissinger: Bill. Mr. Hyland: The intelligence agencies are meeting today on the strategic forces estimate, and this will be the final go-round. Colby is going to spend the entire day on it. The main issue is what happens…
5. **11. Minutes of the Secretary of State’s Staff Meeting** — Washington, October 22, 1974, 9–10:10 a.m.  
   `frus1969-76v37/d11` · score 0.9447  
   > Secretary Kissinger: Tom. Mr. Enders: As I reported to you, the French have political objections to going ahead at an official level in the Camp David follow-up. See Document 10. These objections may prove to be less firm than they are right at the moment, if we proceed with floating our ideas in a…
6. **53. Editorial Note**  
   `frus1969-76v38p1/d53` · score 0.9422  
   > On March 31, 1975, Secretary of State Henry Kissinger met with Dean Rusk, Cyrus Vance, McGeorge Bundy, George Shultz, Douglas Dillon, W. Averell Harriman, Robert McNamara, David Rockefeller, George Ball, William Scranton, Peter G. Peterson, David K.E. Bruce, John McCloy, Lawrence Eagleburger, and…
7. **224. Minutes of the Secretary of State’s Regionals Staff Meeting** — Washington, April 11, 1975, 8:31–8:51 a.m.  
   `frus1969-76v10/d224` · score 0.9419  
   > PROCEEDINGS (The meeting was convened at 8:31 a.m., Secretary of State Kissinger presiding as Chairman.) Secretary Kissinger: I’ve got to make it a fairly short meeting. I want to make a few observations about yesterday evening’s speech. See Document 217. I think we all know that Viet-Nam has been…
8. **86. Minutes of Secretary of State Kissinger’s Principals and Regionals Staff Meeting** — Washington, June 27, 1975.  
   `frus1969-76v22/d86` · score 0.9410  
   > [Omitted here are a list of attendees and discussion of unrelated matters.] Mr. Rogers: Torrijos’ response to the press yesterday was tempered. On June 27, Panamanian newspapers reported that Torrijos remained confident that the “United States would live up to its commitment to negotiate” despite…
9. **42. Memorandum of Conversation** — Washington, August 13, 1974.  
   `frus1969-76v38p1/d42` · score 0.9376  
   > SUBJECT Highlights of Secretary Kissinger’s OFF THE RECORD Breakfast with Time, Inc., Madison Room, Department of State, August 13, 1974. Present at the breakfast were Henry A. Kissinger, Secretary of State Hedley Donovan, Editor-in-Chief Henry Grunwald, Managing Editor Murray Gart, Assistant…
10. **40. Minutes of a National Security Council Meeting** — Washington, August 10, 1974, 11:15–11:35 a.m.  
   `frus1969-76v38p1/d40` · score 0.9364  
   > SUBJECT Presidential Transition PARTICIPANTS Chairman The President State Henry A. Kissinger Robert S. Ingersoll Defense James R. Schlesinger William P. Clements, Jr. JCS Gen. George S. Brown White House Staff Jack Marsh Donald Rumsfeld Alexander M. Haig Robert Hartmann CIA William Colby NSC L/Gen.…

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 9/10.*
*document variant:* frus1969-76v38p2/d117, frus1969-76v38p2/d139, frus1969-76v02/d29, frus1969-76v38p1/d53, frus1969-76v38p1/d84, frus1969-76v13/d95, frus1969-76v38p2/d137, frus1969-76v38p2/d197, frus1969-76v01/d80, frus1964-68v33/d16
*bare variant:* frus1969-76v38p2/d117, frus1969-76v38p2/d139, frus1969-76v38p1/d84, frus1969-76v38p1/d53, frus1969-76v18/d14, frus1969-76v38p2/d137, frus1969-76v13/d95, frus1969-76v10/d224, frus1969-76v18/d24, frus1969-76v02/d29

---

## Q17. What joke did Mao make about Chinese women?
*known-item*

### Lexical — `"what" AND "joke" AND "did" AND "mao" AND "make" AND "about" AND "chinese" AND "women?"`

1. **126. Memorandum of Conversation, Beijing, April 22, 1972, 4:30-8 p.m.** — Beijing, April 22, 1972, 4:30–8 p.m.  
   `frus1969-76ve13/d126` · score -13.7525  
   > Senators Mansfield and Scott and Chinese Premier Chou En-lai discussed the feasibility of neutralizing all of Indochina, how tensions on the Korean peninsula could be reduced, the state of negotiations between the Soviet Union and China on reducing border tensions, and the status of Cambodia.…

### Semantic (query prompt)

1. **12. Memorandum of Conversation** — Beijing, February 17–18, 1973, 11:30 p.m.–1:20 a.m.  
   `frus1969-76v18/d12` · score 0.7920  
   > PARTICIPANTS Mao Tsetung, Chairman, Politburo, Chinese Communist Party Chou En-lai, Premier of the State Council Wang Hai-jung, Assistant Minister of Foreign Affairs Tang Wen-sheng, Interpreter Shen Jo-yun, Interpreter Dr. Henry A. Kissinger, Assistant to the President for National Security Affairs…
2. **86. Paper Prepared by the National Security Council Staff, Washington, undated** — Washington, undated  
   `frus1969-76ve13/d86` · score 0.7813  
   > The paper provided a summary of Chairman of the Communist Party of China Mao Tse-tung’s major philosophical and political themes and offered a brief history of China since the Communists assumed power in 1949. Washington, undated MEMORANDUM February 15, 1972 MEMORANDUM FOR: THE PRESIDENT FROM:…
3. **124. Memorandum of Conversation** — Beijing, October 21, 1975, 6:25–8:05 p.m.  
   `frus1969-76v18/d124` · score 0.7712  
   > PARTICIPANTS Chairman Mao Tse-tung Teng Hsiao-p’ing, Vice Premier of the State Council of the People’s Republic of China Ch’iao Kuan-hua, Minister of Foreign Affairs Amb. Huang Chen, Chief of the PRC Liaison Office, Washington Wang Hai-jung, Vice Minister of Foreign Affairs T’ang Wen-sheng, Deputy…
4. **58. Memorandum of Conversation** — Beijing, November 12, 1973, 5:40–8:25 p.m.  
   `frus1969-76v18/d58` · score 0.7668  
   > PARTICIPANTS Chairman Mao Tse-tung Prime Minister Chou En-lai Foreign Minister Chi Peng-fei Assistant Minister of Foreign Affairs Wang Hai-jung Tang Wang-shen, Interpreter Shen Jo-yen, Interpreter Henry A. Kissinger, Secretary of State Ambassador David Bruce, Chief U.S. Liaison Office Winston Lord,…
5. **234. Memorandum From the President’s Assistant for National Security Affairs (Kissinger) to President Nixon** — Washington, June 27, 1972.  
   `frus1969-76v17/d234` · score 0.7581  
   > SUBJECT Atmospherics of My Visit to Peking The mood of our Chinese hosts throughout the visit was extraordinarily warm and friendly—especially considering the circumstances. It was very apparent that the Chinese were determined not to let the Vietnam situation stand in the way of an improvement in…
6. **303. Paper Prepared by Alfred Jenkins of the National Security Council Staff** — Washington, February 22, 1968.  
   `frus1964-68v30/d303` · score 0.7561  
   > THOUGHTS ON CHINA Prologue to the Present The Present Predicament The Most Probable Future Relations with Others The term “madness” has been applied to the present climate in Peking. In some ways it is not inappropriate. But to a Chinese, because of the historical prologue to the present and…
7. **264. Memorandum From the Director of the Office of Chinese Affairs (Clough) to the Assistant Secretary of State for Far Eastern Affairs (Robertson)** — Washington, June 20, 1957.  
   `frus1955-57v03/d264` · score 0.7556  
   > SUBJECT Mao Tse-tung’s Speech of February 27 “On the Correct Handling of Contradictions Among the People” For additional information on this speech, see Document 238. An overall assessment of the speech, as released on June 18, was circulated in the Department on July 1 in an “Intelligence Report”…
8. **160. Memorandum From the Executive Secretary of the National Security Council (Smith) to President Johnson** — Washington, June 29, 1966, 7 p.m.  
   `frus1964-68v30/d160` · score 0.7555  
   > Mr. President: Consul General Rice in Hong Kong sends in a highly interesting summary of what is apparently going on in Communist China. Bromley Smith Attachment From Hong Kong (2327) SUBJECT Mainland China: Speculation on Recent Developments At no time in recent years have there occurred on…
9. **Report by the Second Secretary of Embassy in China (Service)** — [Yenan,] April 1, 1945.  
   `frus1945v07/d224` · score 0.7538  
   > Received in the Department about April 27. No. 26 [Yenan,] April 1, 1945. Attached is a memorandum of a conversation on this date with a group of Communist leaders: Mao Tse-tung, Chairman of the Central Committee; Chou En-lai, second ranking political leader and functioning “Foreign Minister”; and…
10. **Mr. Mao Tse-tung to the Ambassador in China (Hurley)** — Yenan, January 22, 1945.  
   `frus1945v07/d139` · score 0.7504  
   > Dear General Hurley: Your kind letter has been received. General Chow En-lai is being sent to Chungking to represent the Chinese Communist Party to negotiate with the National Government. With my best wishes for your continued good health, I remain, Yours respectfully, [Signature in Chinese] Mao…

### PRF — centroid of the lexical top-5, no encoder (1 seed)

1. **126. Memorandum of Conversation, Beijing, April 22, 1972, 4:30-8 p.m.** — Beijing, April 22, 1972, 4:30–8 p.m.  
   `frus1969-76ve13/d126` · score 1.0005  
   > Senators Mansfield and Scott and Chinese Premier Chou En-lai discussed the feasibility of neutralizing all of Indochina, how tensions on the Korean peninsula could be reduced, the state of negotiations between the Soviet Union and China on reducing border tensions, and the status of Cambodia.…
2. **124. Memorandum of Conversation, Beijing, April 20, 1972, 10:45 a.m.-1:22 p.m.** — Beijing, April 20, 1972, 10:45 a.m.–1:22 p.m.  
   `frus1969-76ve13/d124` · score 0.9471  
   > Senators Mansfield and Scott and Chinese Vice Minister of Foreign Affairs Ch’iao Kuan-hua discussed Vietnam, Korea, and Taiwan. Beijing, April 20, 1972, 10:45 a.m.–1:22 p.m. SECOND MEETING Peking, China - April 20, 1972 CHINESE DELEGATION Mr. Chiao Kuan-Hua, Vice-President of the Chinese People’s…
3. **123. Memorandum of Conversation, Beijing, April 19, 1972, 10:05 a.m.-12:52 p.m.** — Beijing, April 19, 1972, 10:05 a.m.–12:52 p.m.  
   `frus1969-76ve13/d123` · score 0.9449  
   > NSC staff member Lord provided President’s Assistant for National Security Affairs Kissinger with a brief summary of Senators Mansfield and Scott’s trip to China. Beijing, April 19, 1972, 10:05 a.m.–12:52 p.m. INFORMATION May 12, 1972 MEMORANDUM FOR: HENRY A. KISSINGER FROM: WINSTON LORD SUBJECT:…
4. **125. Memorandum of Conversation, Beijing, April 20, 1972, 8:55-10:40 p.m.** — Beijing, April 20, 1972, 8:55–10:40 p.m.  
   `frus1969-76ve13/d125` · score 0.9409  
   > Senators Mansfield and Scott and Chinese Premier Chou En-lai agreed that an American withdrawal from Vietnam would reduce tensions in Asia. Beijing, April 20, 1972, 8:55–10:40 p.m. THIRD MEETING Great Hall of the People Peking, China - April 20, 1972 CHINESE DELEGATION Premier Chou En-lai, Premier…
5. **196. Memorandum of Conversation** — Beijing, February 22, 1972, 2:10–6 p.m.  
   `frus1969-76v17/d196` · score 0.9373  
   > PARTICIPANTS The President Dr. Henry A. Kissinger, Assistant to the President for National Security Affairs John H. Holdridge, NSC Staff Winston Lord, NSC Staff Prime Minister Chou En-lai Ch’iao Kuan-hua, Vice Minister of Foreign Affairs Chang Wen-chin, Director of Western Europe, North American,…
6. **140. Memorandum of Conversation** — Beijing, July 10, 1971, 12:10–6 p.m.  
   `frus1969-76v17/d140` · score 0.9337  
   > PARTICIPANTS Prime Minister Chou En-lai, People’s Republic of China Yeh Chien-ying, Vice Chairman, Military Affairs Commission, Chinese Communist Party, PRC Huang Hua, PRC Ambassador to Canada Chang Wen-chin, Director, Western Europe and American Department, PRC Ministry of Foreign Affairs PRC PRC…
7. **199. Memorandum of Conversation** — Beijing, February 24, 1972, 5:15–8:05 p.m.  
   `frus1969-76v17/d199` · score 0.9324  
   > PARTICIPANTS The President Dr. Henry A. Kissinger, Assistant to the President for National Security Affairs John H. Holdridge, NSC Staff Winston Lord, NSC Staff Prime Minister Chou En-lai Ch’iao Kuan-hua, Vice Minister of Foreign Affairs Chang Wen-chin, Director of Western Europe, North American,…
8. **79. Memorandum of Conversation, Beijing, January 7, 1972, 11:45 p.m.** — Beijing, January 7, 1972, 11:45 p.m.  
   `frus1969-76ve13/d79` · score 0.9313  
   > Chinese Premier Chou En-lai voiced the Chinese views concerning the joint communiqué, which President’s Deputy Assistant for National Security Affairs Haig indicated he would convey to President’s Assistant for National Security Affairs Kissinger and President Nixon. Beijing, January 7, 1972, 11:45…
9. **139. Memorandum of Conversation** — Beijing, July 9, 1971, 4:35–11:20 p.m.  
   `frus1969-76v17/d139` · score 0.9293  
   > PARTICIPANTS Prime Minister Chou En-lai, People’s Republic of China Yeh Chien-ying, Vice Chairman, Military Affairs Commission, Chinese Communist Party, PRC Huang Hua, PRC Ambassador to Canada Chang Wen-chin, Director, Western Europe and Americas Department, PRC Ministry of Foreign Affairs One…
10. **78. Memorandum of Conversation, Beijing January 6, 1972, 11 a.m.** — Beijing January 6, 1972, 11 a.m.  
   `frus1969-76ve13/d78` · score 0.9277  
   > President’s Deputy Assistant for National Security Affairs Haig, acting on Kissinger’s instructions concerning the communique, informed Acting Chinese Foreign Minister Chi P’eng-fei that the United States wanted to strengthen trade, cultural, and scientific relations between the two nations and…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 10/10, bare: 8/10.*
*document variant:* frus1969-76ve13/d86, frus1969-76v18/d12, frus1969-76v18/d124, frus1964-68v30/d303, frus1969-76v18/d58, frus1964-68v30/d160, frus1955-57v03/d264, frus1969-76v17/d234, frus1945v07/d224, frus1945v07/d139
*bare variant:* frus1969-76v18/d12, frus1969-76v18/d124, frus1969-76ve13/d86, frus1969-76v18/d58, frus1955-57v03/d264, frus1964-68v30/d160, frus1964-68v30/d303, frus1951v07p2/d83, frus1969-76v17/d234, frus1949v08/d919

---

## Q18. What medium- and long-term impacts did U.S. policymakers anticipate the Panama Canal Treaty having? What were they right and wrong about?

### Lexical — `"what" AND "medium-" AND "long-term" AND "impacts" AND "did" AND "u.s." AND "policymakers" AND "anticipate" AND "the" AND "panama" AND "canal" AND "treaty" AND "having?" AND "what" AND "were" AND "they" AND "right" AND "wrong" AND "about?"`

*(no results)*

### Semantic (query prompt)

1. **223. Internal Transcript of a White House Briefing** — Washington, May 8, 1979, 7:40–9:05 p.m.  
   `frus1977-80v29/d223` · score 0.8283  
   > THE PRESIDENT: I don’t know of a better way to wind up a day of delightful legislative work—(Laughter)—than to discuss the Panama Canal Treaty and its implementation. I would like to start out and say a few words as President and then call on Secretary Alexander to follow me and then General…
2. **3. Paper Prepared in the Department of State** — Washington, January 21, 1977  
   `frus1977-80v29/d3` · score 0.8229  
   > POLICY REVIEW MEMORANDUM: PANAMA I. CURRENT SITUATION Our basic national interest in Panama is that the Canal remain efficient, secure, neutral, and continuously open to all world shipping at reasonable tolls. The present Canal has served us well over the years, and is still a “major” defense asset…
3. **20. Briefing Memorandum From Ambassador at Large (Bunker) and Panama Canal Treaty Co-Negotiator (Linowitz) to Secretary of State Vance** — Washington, February 25, 1977  
   `frus1977-80v29/d20` · score 0.8221  
   > PANAMA We have just returned from nine days of talks with Panama’s negotiators. As specified by the Policy Review Committee on January 27 See Document 8. and the President on February 11, See Document 14. the objective of these talks was to explore informally whether Panama would be willing to…
4. **52. Memorandum of Conversation** — Grenada, June 15, 1977  
   `frus1977-80v29/d52` · score 0.8170  
   > Participants U.S. Secretary Cyrus Vance Under Secretary P. Habib Assistant Secretary Todman Ambassador McGee Mr. Hodding Carter, III Mr. Mark Dion (Notetaker) PANAMA Foreign Minister Gonzalez-Revilla Ambassador de la Rosa Ambassador Nander Pitty Panama Negotiations; OAS General Assembly—Joint…
5. **67. Address by President Carter to the Nation** — Washington, February 1, 1978  
   `frus1977-80v01/d67` · score 0.8164  
   > Panama Canal Treaties Good evening. Seventy-five years ago, our Nation signed a treaty which gave us rights to build a canal across Panama, to take the historic step of joining the Atlantic and Pacific Oceans. See footnote 6, Document 33. The results of the agreement have been of great benefit to…
6. **533. Memorandum From the NSC Inter-Departmental Group for Inter-American Affairs to President Nixon** — Washington, April 6, 1970  
   `frus1969-76ve10/d533` · score 0.8152  
   > The National Security Council Inter-Departmental Group for Inter-American Affairs (NSC–IG/ARA) reviewed the key issues for the United States in writing new Canal treaties with Panama. The NSC–IG/ARA focused on the following concerns: Canal capacity, sovereignty, control and defense of the Canal,…
7. **55. Memorandum of Conversation** — Washington, June 29, 1977, 7–8:15 a.m.  
   `frus1977-80v29/d55` · score 0.8151  
   > SUBJECT Briefing President Carlos Andres Perez of Venezuela on Status of Canal Negotiations PARTICIPANTS Venezuela President Carlos Andres Perez Foreign Minister Ramon Escovar Salom Gonzalo Plaza, Interpreter United States Ambassador Bunker Ambassador Linowitz Anthony Hervas, Interpreter PEREZ: How…
8. **89. Minutes of a Cabinet Meeting** — Washington, August 29, 1977, 9:05 a.m.  
   `frus1977-80v29/d89` · score 0.8142  
   > The twenty-fifth meeting of the Cabinet was called to order by the President at 9:05 a.m., Monday, August 29, 1977. All Cabinet members were present except Secretary Bergland, who was represented by Deputy Secretary of Agriculture John White; Secretary Califano, represented by Under Secretary of…
9. **553. Memorandum From Secretary of Defense Laird to President Nixon** — Washington, September 3, 1971  
   `frus1969-76ve10/d553` · score 0.8131  
   > Laird addressed the opposing positions on duration, the temporary decision on the issue, examined the termination arguments, and recommended that Panama be informed that the United States would not agree to a fixed-term treaty. He also recommended that the U.S. Government proceed much further into…
10. **77. Minutes of a National Security Council Meeting** — Washington, May 15, 1975, 4:30–5:30 p.m.  
   `frus1969-76v22/d77` · score 0.8116  
   > SUBJECT Panama Canal Negotiations PRINCIPALS The President The Vice President Secretary of State Henry A. Kissinger Secretary of Defense James Schlesinger Chairman, Joint Chiefs of Staff General George S. Brown Director of Central Intelligence William Colby OTHER ATTENDEES State Deputy Secretary of…

### PRF — centroid of the lexical top-5, no encoder (0 seeds)

*(no seeds — PRF amplifies lexical search and cannot rescue a query it returned nothing for)*

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 9/10, bare: 10/10.*
*document variant:* frus1977-80v29/d223, frus1977-80v29/d3, frus1977-80v29/d20, frus1977-80v29/d89, frus1969-76ve10/d533, frus1977-80v01/d67, frus1977-80v29/d55, frus1977-80v29/d52, frus1964-68v31/d428, frus1969-76v22/d77
*bare variant:* frus1977-80v29/d223, frus1969-76v22/d77, frus1977-80v29/d55, frus1977-80v29/d20, frus1977-80v29/d3, frus1977-80v29/d52, frus1977-80v01/d67, frus1969-76ve10/d533, frus1977-80v29/d89, frus1969-76ve10/d553

---

## Q19. Climate diplomacy

### Lexical — `"climate" AND "diplomacy"`

1. **303. Memorandum From the Assistant to the President’s Special Assistant for Health Issues (Fill) to the President’s Special Assistant for Health Issues (Bourne)** — Washington, November 30, 1977  
   `frus1977-80v02/d303` · score -14.6014  
   > SUBJECT A Thought re Implications of a New International Health Policy If we established as a principle of foreign policy that we would not deny any needy nation international health assistance it would be a first in U.S. history. By establishing this moral principle we would not hesitate to award…
2. **497. Memorandum From the President’s Assistant for National Security Affairs (Brzezinski) to Secretary of State Vance, Secretary of Defense Brown, the Director of the Office of Management and Budget (McIntyre), the Director of the Arms Control and Disarmament Agency (Warnke), and the Director of the International Communication Agency (Reinhardt)** — Washington, June 8, 1978  
   `frus1977-80v26/d497` · score -11.9078  
   > SUBJECT Interagency Committee on Public Diplomacy and Disarmament Whatever the specific accomplishments of the UN Special Session on Disarmament (SSOD), it has focused the attention of important publics throughout the world on disarmament issues. As we move beyond SSOD, it is desirable to foster a…
3. **6. Editorial Note**  
   `frus1969-76v01/d6` · score -11.5026  
   > Richard Nixon offered his perspective on prospects for détente with the Soviet Union in his acceptance speech at the Republican convention in Miami Beach, Florida, on August 8, 1968: “And now to the leaders of the Communist world, we say: After an era of confrontation, the time has come for an era…
4. **134. Memorandum From the President’s Assistant for National Security Affairs (Brzezinski) to Secretary of State Vance, Secretary of Defense Brown, the Director of the Office of Management and Budget (McIntyre), the Director of the Arms Control and Disarmament Agency (Warnke), and the Director of the International Communication Agency (Reinhardt)** — Washington, undated  
   `frus1977-80v30/d134` · score -11.3682  
   > SUBJECT Interagency Committee on Public Diplomacy and Disarmament An unknown hand underlined the subject line. Whatever the specific accomplishments of the UN Special Session on Disarmament (SSOD), The tenth UN Special Session on Disarmament took place May 23–June 30. Documentation on the Special…
5. **The Chargé in the Soviet Union (Kennan) to the Secretary of State** — Moscow, March 20, 1946—2 p.m. [Received 4:59 p.m.]  
   `frus1946v06/d487` · score -11.1583  
   > secret Moscow, March 20, 1946—2 p.m. [Received 4:59 p.m.] 878. In recent days we have noted a number of statements made either editorially in American papers or individually by prominent Americans reflecting the view that Soviet “suspicions” could be assuaged if we on our part would make greater…
6. **317. Letter From Prime Minister Nehru to President Kennedy** — New Delhi, August 11, 1963.  
   `frus1961-63v19/d317` · score -10.6544  
   > Dear Mr. President, Ambassador Chester Bowles and the U.K. High Commissioner Sir Paul Gore-Booth jointly handed over for the consideration of the Government of India a draft joint communique to our Foreign Secretary on the evening of the 7th. Bowles reported on this demarche in telegram 608 from…
7. **43. Contingency Study Prepared by the National Security Council Interdepartmental Working Group/Europe, Washington, undated.** — Washington, undated.  
   `frus1969-76ve15p1/d43` · score -10.4502  
   > The National Security Council prepared a study of the potential impact of Soviet military action against Romania or internal Romanian political instability on the U.S. and the NATO alliance. Washington, undated. CONTINGENCY STUDY FOR ROMANIA Summary There are broadly speaking two sets of…
8. **172. Minutes of National Security Council Meeting** — Washington, January 13, 1977, 10:30–11:30 a.m.  
   `frus1969-76v35/d172` · score -9.9513  
   > SUBJECT Semiannual Review of the Intelligence Community PRINCIPALS The President The Vice President Secretary of State Henry A. Kissinger Secretary of Defense Donald Rumsfeld Director of Central Intelligence George Bush Chief of Naval Operations James L. Holloway (Acting for Chairman, Joint Chiefs…
9. **No. 783. Mr. Beardsley to Mr. Fish.** — Agency and Consulate-General of the United States in Egypt, Cairo, September 3, 1873. (Received September 29.)  
   `frus1874/d786` · score -9.9348  
   > Sir: I have the honor to inform you that Sir Samuel Baker and Lady Baker arrived at Cairo on the 24th ultimo, where they are now stopping. I have had the pleasure of several interviews with Sir Samuel, on which occasions he graphically detailed the incidents of his expedition and expressed himself…
10. **33. Memorandum From Robert Pastor of the National Security Council Staff to the President’s Assistant for National Security Affairs (Brzezinski)** — Washington, October 4, 1978  
   `frus1977-80v24/d33` · score -9.8218  
   > SUBJECT Impact of U.S. Human Rights Policy in Latin America After our discussion at the staff meeting last week, I tasked the CIA to do an overall assessment of the impact of our human rights policy in the Southern Cone. Brzezinski highlighted this sentence in the left-hand margin and wrote,…

### Semantic (query prompt)

1. **74. Article by the Assistant Secretary of State for International Organization Affairs (Maynes)** — Washington, undated  
   `frus1977-80v01/d74` · score 0.7614  
   > The Maturing of American Diplomacy How does one describe the trends of American diplomacy today? Were it 30 years ago, in the full flush of American power and opportunity, we might adopt Dean Acheson’s metaphor and proclaim ourselves “present at the creation.” Reference is to Acheson’s memoirs,…
2. **3. Notes of a Meeting** — London, February 18, 1981  
   `frus1981-88v38/d3` · score 0.7576  
   > NOTES FROM THE SHERPAS MEETING The meeting was chaired by Allan Gotlieb, Canada. North/South An unknown hand added this heading in the left-hand margin. Canada: Our main concern is to prepare for a successful summit. The obligation of the Personal Representatives, i.e., the mandate we received from…
3. **48. Memorandum of Conversation** — Beijing, August 23, 1977, 9:30–11:50 a.m.  
   `frus1977-80v13/d48` · score 0.7435  
   > SUBJECT Africa; Latin America; Normalization with other Countries; Human Rights; Non-Proliferation; ME; Yugoslavia; Normalization of US– PRC Relations PARTICIPANTS U.S. The Secretary Ambassador Woodcock Under Secretary Habib Assistant Secretary Holbrooke, EA William H. Gleysteen, Jr. Deputy…
4. **32. Notes of a Meeting** — Cancun, August 1–2, 1981  
   `frus1981-88v38/d32` · score 0.7433  
   > PREPARATORY MEETING OF FOREIGN MINISTERS FOR CANCUN SUMMIT Saturday AM Session (10:00 a.m.–1:30 p.m.) Mexico —It has been a long itinerary, and we have overcome many obstacles to get here. It is time to overcome the forces of confusion and private interest. We must reorganize the political…
5. **331. Talking Points Prepared in the Policy Planning Staff** — Washington, undated  
   `frus1981-88v01/d331` · score 0.7427  
   > TALKING POINTS FOR SECRETARY’S INTERVIEW Achievements of Reagan Administration — America is back: During the 1970’s, Soviet Union was on a roll: Vietnam, Cambodia, Afghanistan, Ethiopia, Angola and Nicaragua all entered Soviet orbit. Communism appeared to be wave of the future; America, by…
6. **100. Memorandum of Conversation** — New York City, September 30, 1976, 4 p.m.  
   `frus1969-76ve08/d100` · score 0.7423  
   > The Secretary of State Kissinger and Prime Minister Bandaranaike discussed U.S. relations with Sri Lanka, focusing on votes in the United Nations and Sri Lanka’s position on regional questions. New York City, September 30, 1976, 4 p.m. SUBJECT: Meeting with Prime Minister Bandaranaike of Sri Lanka…
7. **120. Message From Chairman Khrushchev to President Kennedy** — Moscow, October 30, 1962.  
   `frus1961-63v11/d120` · score 0.7419  
   > Dear Mr. President, I want to convey to you confidentially some considerations which, if you agree with them, could serve, in my opinion, our common cause, that is, prompt elimination of the remnants of the dangerous crisis which you and we have in the main liquidated. This would help to finalize…
8. **352. Telegram From the Department of State to Multiple Diplomatic Posts** — Washington, March 30, 1985, 0546Z  
   `frus1981-88v41/d352` · score 0.7411  
   > Subject: Conference of Plenipotentiaries for Protection of the Ozone Layer: Report of the U.S. Delegation. 1. Summary: The Conference of Plenipotentiaries on the Protection of the Ozone Layer (18–22 March 1985) was successfully concluded, with the quote Vienna Convention for the Protection of the…
9. **42. Briefing Memorandum From the Assistant Secretary of State for International Organization Affairs (Lewis) to Secretary of State Kissinger, Washington, March 3, 1976.** — Washington, March 3, 1976  
   `frus1969-76ve14p1/d42` · score 0.7405  
   > Lewis presented strategies for promoting multilateral diplomacy initiatives at the United Nations during 1976. Washington, March 3, 1976 DEPARTMENT OF STATE BRIEFING MEMORANDUM March 3, 1976 TO: The Secretary THROUGH: P - Mr. Sisco E - Mr. Robinson FROM: IO - Samuel W. Lewis [SWL initialed]…
10. **71. Letter From Chairman Khrushchev to President Kennedy** — Moscow, October 30, 1962.  
   `frus1961-63v06/d71` · score 0.7393  
   > Dear Mr. President, I want to convey to you confidentially some considerations which, if you agree with them, could serve, in my opinion, our common cause, that is, prompt elimination of the remnants of the dangerous crisis which you and we have in the main liquidated. This would help to finalize…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **134. Memorandum From the President’s Assistant for National Security Affairs (Brzezinski) to Secretary of State Vance, Secretary of Defense Brown, the Director of the Office of Management and Budget (McIntyre), the Director of the Arms Control and Disarmament Agency (Warnke), and the Director of the International Communication Agency (Reinhardt)** — Washington, undated  
   `frus1977-80v30/d134` · score 0.9423  
   > SUBJECT Interagency Committee on Public Diplomacy and Disarmament An unknown hand underlined the subject line. Whatever the specific accomplishments of the UN Special Session on Disarmament (SSOD), The tenth UN Special Session on Disarmament took place May 23–June 30. Documentation on the Special…
2. **497. Memorandum From the President’s Assistant for National Security Affairs (Brzezinski) to Secretary of State Vance, Secretary of Defense Brown, the Director of the Office of Management and Budget (McIntyre), the Director of the Arms Control and Disarmament Agency (Warnke), and the Director of the International Communication Agency (Reinhardt)** — Washington, June 8, 1978  
   `frus1977-80v26/d497` · score 0.9406  
   > SUBJECT Interagency Committee on Public Diplomacy and Disarmament Whatever the specific accomplishments of the UN Special Session on Disarmament (SSOD), it has focused the attention of important publics throughout the world on disarmament issues. As we move beyond SSOD, it is desirable to foster a…
3. **52. Remarks by President Carter** — Charleston, South Carolina, July 21, 1977  
   `frus1977-80v01/d52` · score 0.9212  
   > And I want to talk to you today about the hopes and problems that we as southerners and as Americans share together. I feel a special kinship with your State legislators. For 4 years I was a member of the Georgia Senate, and I still prize State government not only for the talents of those who work…
4. **108. Memorandum of Conversation** — Beijing, May 20, 1978, 3:30–6:40 p.m.  
   `frus1977-80v13/d108` · score 0.9206  
   > SUBJECT Summary of Dr. Brzezinski’s Meeting with Foreign Minister Huang Hua PARTICIPANTS Zbigniew Brzezinski, Assistant to the President for National Security Affairs Leonard Woodcock, United States Ambassador to the People’s Republic of China Richard Holbrooke, Assistant Secretary of State for…
5. **86. Memorandum From the Counselor of the Department of State (Sonnenfeldt) to Secretary of State Kissinger** — Washington, November 14, 1974.  
   `frus1969-76v16/d86` · score 0.9190  
   > SUBJECT Memorandum for the President for Vladivostok Attached is the President’s Briefing Book for Vladivostok which contains a memorandum to him for your signature, as well as comprehensive background material on all the major subjects likely to come up at the talks. This briefing material is…
6. **23. Letter From President Reagan to Soviet General Secretary Gorbachev** — Washington, April 30, 1985  
   `frus1981-88v05/d23` · score 0.9189  
   > Source: Reagan Library, Executive Secretariat, NSC Head of State File, U.S.S.R.: General Secretary Gorbachev (8590475). No classification marking. In an April 25 memorandum to McFarlane, Matlock explained that he “redrafted” the letter to “take account of the Soviet action Monday in disavowing an…
7. **10. Memorandum from Battle to Swank, April 21** — April 21, 1961  
   `frus1961-63v07-09mSupp/d10` · score 0.9179  
   > The Secretary’s Remarks to the Disarmament Consultants The attached copy of the Secretary’s remarks, as delivered to the disarmament consultants on April 14, is referred for approval. The Disarmament Administration plans no distribution of the Secretary’s remarks, except for one copy to Ambassador…
8. **41. Memorandum From Secretary of State Shultz to President Reagan** — Washington, June 12, 1985  
   `frus1981-88v05/d41` · score 0.9178  
   > Source: Reagan Library, George Shultz Papers, 1985 Soviet Union June. Secret; Sensitive. Brackets are in the original. Kelly sent Shultz the memorandum under an undated action memorandum, recommending that he send it to Reagan. Jonathan Benton (S/S–S) noted on the action memorandum: “GPS gave…
9. **98. Message From Chairman Khrushchev to President Kennedy** — Moscow, undated.  
   `frus1961-63v06/d98` · score 0.9170  
   > Dear Mr. President: I have with interest acquainted myself with your message of April 11. Document 95. If my impression is correct as to its principal motive, namely to seek out new possibilities for the cooperation of our countries in the resolution of questions which are ripe for settlement, then…
10. **8. Address by Ronald Reagan** — Chicago, August 18, 1980  
   `frus1981-88v01/d8` · score 0.9165  
   > [Omitted here are Reagan’s introductory remarks and the portion of his address dealing with the Veterans Administration.] These are matters of great concern to your great organization. Let us turn now to a matter which vitally concerns our nation — “PEACE”. It has always struck me as odd that you…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 5/10, bare: 5/10.*
*document variant:* frus1977-80v01/d74, frus1981-88v38/d3, frus1969-76ve14p1/d30, frus1958-60v05mSupp/co_d2, frus1977-80v01/d40, frus1977-80v13/d48, frus1977-80v01/d62, frus1961-63v06/d71, frus1977-80v01/d47, frus1981-88v41/d352
*bare variant:* frus1981-88v01/d299, frus1981-88v38/d3, frus1977-80v01/d74, frus1981-88v41/d352, frus1977-80v13/d48, frus1981-88v01/d331, frus1969-76v18/d97, frus1969-76ve03/d52, frus1969-76v31/d124, frus1969-76ve14p1/d18

---

## Q20. Window of vulnerability

### Lexical — `"window" AND "of" AND "vulnerability"`

1. **183. Memorandum From Secretary of Defense Brown to President Carter** — Washington, April 30, 1980  
   `frus1977-80v04/d183` · score -13.8855  
   > SUBJECT FB–111B/C Proposal (U) (S) General Ellis, Commander of the Strategic Air Command, has proposed that we modify 150 F–111As and FB–111s into a new, longer range strategic bomber called the FB–111B/C. He argues that this would strengthen our strategic forces during the “vulnerability window”…
2. **264. Information Memorandum From the Director of the Policy Planning Staff (Solomon) to Secretary of State Shultz** — Washington, January 27, 1988  
   `frus1981-88v11/d264` · score -10.4865  
   > SUBJECT Heading Off Criticism of START SUMMARY. Several well-known members of the strategic “establishment,” including Henry Kissinger, Brent Scowcroft, Bill Hyland, and Jim Woolsey, have begun to criticize the emerging START agreement on the grounds that 50 percent reductions will concentrate U.S.…
3. **237. Memorandum From the Assistant Secretary of the Treasury for International Affairs (Mulford) to Secretary of the Treasury Baker** — Washington, February 26, 1988  
   `frus1981-88v38/d237` · score -9.3805  
   > SUBJECT Next Steps Under the Debt Strategy Summary This memo provides an appraisal of the debt strategy, in light of recent developments and evolving debtor and commercial bank attitudes. In particular, it explores options for encouraging new bank financing, as well as various debt reduction…
4. **204. Memorandum to the Chairman of the 40 Committee** — Washington, June 2, 1975.  
   `frus1969-76v35/d204` · score -9.2301  
   > SUBJECT Project MATADOR REFERENCE –0188/75(R), Same Subject dated 19 May 1975 Document 203. 1. This memorandum requests 40 Committee direction on initiation of the Project MATADOR mission as stated below. It amplifies the information provided in the reference. 2. Mission Readiness. The HUGHES…
5. **The Ambassador in the Soviet Union (Harriman) to the Secretary of State** — Moscow, January 20, 1946—noon. [Received 4:03 p.m.]  
   `frus1946v06/d463` · score -8.3249  
   > confidential Moscow, January 20, 1946—noon. [Received 4:03 p.m.] 187. . . . In evaluating need for information program directed to USSR, we begin with basic consideration that US relations with USSR are probably more important and portentous than with any other countries. There can be little…
6. **96. Backchannel Message From the Ambassador to Chile (Korry) to the Under Secretary of State for Political Affairs (Johnson)** — Santiago, September 16, 1970.  
   `frus1969-76v21/d96` · score -8.0939  
   > I am extremely grateful for the confidence and support of President Nixon and the 40 Committee. 2. I am painfully aware of the delicacy of my situation and I trust that you and your colleagues are equally aware of the long odds involved. 3. President Frei’s attitude is very clear to me: He is 100…
7. **211. Memorandum From the President’s Assistant for National Security Affairs (Kissinger) to President Nixon** — Washington, February 20, 1970.  
   `frus1969-76v20/d211` · score -8.0830  
   > SUBJECT The Williams Case You will recall the Williams case in the Philippines, in which an Air Force sergeant at Clark Field was accused of complicity in an attempted rape case in the nearby town of Angeles, and was inadvertently allowed by his military supervisors to depart on reassignment while…
8. **80. Memorandum From Senator Nunn to President Bush** — Washington, February 22, 1990  
   `frus1989-92v31/d80` · score -7.9475  
   > SUBJECT Ban on Mobile MIRV ed ICBM s I have been urging the Administration to propose a ban in START on mobile MIRV ed ICBM s because I think it makes sense in terms of greater strategic stability and because I think it may be your only hope for maintaining congressional support for the Rail…
9. **368. Telegram From the Embassy in the United Arab Republic to the Department of State** — Cairo, March 19, 1959, 2 p.m.  
   `frus1958-60v12/d368` · score -7.5624  
   > Following is summary impression my just concluded visit to Yemen: Ambassador Hare at Cairo was accredited as Minister to Yemen, and during a visit to Yemen presented his credentials to the Imam on March 11. As of March 16 there was an American legation in Taiz with a resident chargé. Throughout…
10. **Memorandum of Conversation, by Mr. Elbridge Durbrow of the Division of European Affairs** — [Washington,] February 3, 1943.  
   `frus1943v03/d374` · score -7.4722  
   > The following is an outline of a conversation I had with Mr. Joseph E. Davies Ambassador to the Soviet Union during 1937 and part of 1938. regarding our attitude vis-à-vis the Soviet Union. After discussing at some length the difficulties which Admiral Standley had had in connection with the visit…

### Semantic (query prompt)

1. **96. Editorial Note**  
   `frus1961-63v21/d96` · score 0.7129  
   > 96. Editorial Note [Text not declassified.]
2. **274. Editorial Note**  
   `frus1964-68v33/d274` · score 0.7117  
   > 274. Editorial Note [text not declassified]
3. **100. Airgram From the Embassy in Vietnam to the Department of State** — Saigon, April 25, 1963.  
   `frus1961-63v03/d100` · score 0.7085  
   > A–661 Saigon, April 25, 1963. SUBJECT Interdiction REF CA-10362 Document 66. For Harriman and Hilsman from Nolting. In response to the reference instruction, my staff and I, with the close cooperation of MACV and 2nd Air Division, have conducted a thorough review and evaluation of the subject of…
4. **88. Memorandum From the Ambassador’s Special Assistant (Lansdale) to the Ambassador to Vietnam (Bunker)** — Saigon, February 27, 1968.  
   `frus1964-68v06/d88` · score 0.7070  
   > SUBJECT Evaluation of Tet Offensive As desired by you, the Senior Liaison Office submits herein its spot evaluation of the enemy’s Tet offensive. It contains both my personal opinion and also the opinions of the members of my staff (David Hudson, Calvin Mehlert and Charles Sweet). It’s our first…
5. **486. Report of Joint U.S.–U.K. Technical Group** — London, August 10–11, 1959  
   `frus1958-60v03mSupp/d486` · score 0.7055  
   > Report of Joint US– UK Technical Group to Review Technical Aspects of Nuclear Weapons Test Detection UK Participants Sir William Penney Sir Frederick Brundrett Dr. R. Press Mr. Hulme Mr. Mattock Dr. Levin Dr. Maurice Hill Mr. Con O’Neill Mr. V. Macklin US Participants Dr. J. R. Killian Dr. Hens…
6. **302. Letter From the Ambassador in Vietnam (Nolting) to the Deputy Assistant Secretary of State for Far Eastern Affairs (Cottrell)** — Saigon, October 15, 1962.  
   `frus1961-63v02/d302` · score 0.7031  
   > Dear Cot: I have received your letter of September 11 Document 282. which listed eleven questions asked by Ed Rice about Viet-Nam. These are, as you know, some (but not all) of the complex and broad questions to which we are constantly seeking the answers and which we are attempting to cover as…
7. **230. Memorandum from Gordon Chase to McGeorge Bundy, April 30** — April 30, 1963  
   `frus1961-63v10-12mSupp/d230` · score 0.7026  
   > SUBJECT Venezuela—General Lansdale’s Report I refer to your request that I brief the attached report by General Lansdale. The report, which the General wrote after a visit to CINCARIB and a nine-day visit to Venezuela, examines the Communist insurgency menace in that country. It concludes that…
8. **59. Paper Prepared by the Vice President** — Washington, undated.  
   `frus1961-63v01/d59` · score 0.7025  
   > It is not clear whether this paper was intended to be an annex to the memorandum to the President, a draft of the memorandum itself, or the report from which the Vice President briefed the Cabinet on May 25. The copy of the memorandum to the President in OSD Files also has this attachment, but…
9. **127. Airgram From the Embassy in Vietnam to the Department of State** — Saigon, March 23, 1962.  
   `frus1961-63v02/d127` · score 0.7019  
   > A-257 Saigon, March 23, 1962. SUBJECT Assessment of Political and Economic Factors in Vietnamese War Following is assessment of political and economic factors in Vietnamese war, prepared for use at current SecDefense meeting in Honolulu: See Document 124. 1. Political Factors The main political…
10. **186. Telegram From the Embassy in Vietnam to the Department of State** — Saigon, March 7, 1965, 3 p.m.  
   `frus1964-68v02/d186` · score 0.7017  
   > General Johnson’s party See Document 179. met with US Mission Council for about three hours on afternoon of March 5. Most of time was spent in discussing causes for retardation of pacification program and areas for possible additional effort to eliminate these causes. I opened discussion by…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **21. Memorandum From Linton Brooks of the National Security Council Staff to the President’s Deputy Assistant for National Security Affairs (Gates)** — Washington, May 18, 1989  
   `frus1989-92v31/d21` · score 0.9337  
   > SUBJECT Deputies Committee Meeting, Saturday, May 20, 1989, 10:00–11:00 a.m.—Security and Arms Control This Deputies Meeting, which precedes a May 25 (tentative) NSC meeting on the same subject, will be your first opportunity to have the Deputies Committee deal with arms control. The nominal…
2. **113. Memorandum From Secretary of Defense Rumsfeld to President Ford** — Washington, November 30, 1976.  
   `frus1969-76v35/d113` · score 0.9321  
   > NATIONAL SECURITY COUNCIL DEFENSE REVIEW PANEL MEMORANDUM FOR THE PRESIDENT SUBJECT Response to NSSM 246— US Defense Policy and Military Posture Attached hereto is the National Security Council Defense Review Panel’s response to NSSM 246. The response was not found attached to Rumsfeld’s covering…
3. **103. Draft Memorandum From Secretary of Defense McNamara to President Johnson** — Washington, November 1, 1965.  
   `frus1964-68v10/d103` · score 0.9289  
   > SUBJECT Recommended FY 1967–71 Strategic Offensive and Defensive Forces (U) I have completed my review of our general nuclear war posture and our programs for the strategic offensive and defensive forces over the FY 1967–71 period. The estimated costs for the Previously Approved, the Service…
4. **210. Draft Memorandum From Secretary of Defense Clifford to President Johnson** — Washington, July 29, 1968.  
   `frus1964-68v10/d210` · score 0.9275  
   > SUBJECT Strategic Offensive and Defensive Forces (U) We have reviewed our Strategic Offensive and Defensive Forces for FY 70–74 and reached the following major conclusions: 1. Against the expected Soviet threat, our present strategic offensive forces provide a more than adequate Assured Destruction…
5. **170. Memorandum From the Director of Central Intelligence (Bush) to Recipients of National Intelligence Estimate 11–3/8–76** — Washington, undated.  
   `frus1969-76v35/d170` · score 0.9274  
   > The attached National Intelligence Estimate is the official appraisal of the Director of Central Intelligence. This Estimate, including its italicized statements of differing views by members of The National For eign Intelligence Board, was drafted and coordinated by professional intelligence…
6. **17. Letter From Secretary of Defense McNamara to President Kennedy** — Washington, February 20, 1961  
   `frus1961-63v08/d17` · score 0.9274  
   > Dear Mr. President: I have now completed my initial review of the Eisenhower Administration FY 1961 and FY 1962 budgets for the Department of Defense. The attached memorandum explains the basis on which the review has been made and summarizes the changes I am recommending for your consideration. In…
7. **126. Memorandum From the Under Secretary of Defense for Policy (Ikle) to Secretary of Defense Weinberger** — Washington, August 19, 1986  
   `frus1981-88v44p1/d126` · score 0.9261  
   > SUBJECT The Vance, Laird, Scowcroft, et al, Paper on SDI, Arms Control, and such Attached for your information is the paper made available to members of Congress, which was “endorsed” by Brown, Laird, Schlesinger, Scowcroft, and Vance, and which got front page coverage in last Sunday’s New York…
8. **193. Memorandum From Acting Director of Central Intelligence Gates to the President’s Assistant for National Security Affairs (Carlucci)** — Washington, January 15, 1987  
   `frus1981-88v44p1/d193` · score 0.9260  
   > SUBJECT NSDD 250 Response [portion markings not declassified] 1. Attached is the DCI response to a key portion of the tasking that was posed to the Director in NSDD 250; that portion of the tasking that dealt with verification matters and was assigned to Ken Adelman and the DCI jointly as well as…
9. **97. Paper Prepared by the Arms Control Support Group** — Washington, September 24, 1985  
   `frus1981-88v05/d97` · score 0.9260  
   > Source: Department of State, Executive Secretariat, S/S, Top Secret/Secret Sensitive Memorandum, Lot 91D257, Eggplant II, September–December 1985 NP. Top Secret; Owl; Noforn. Handle via Owl Channels. McFarlane sent the paper to Shultz, Weinberger, Casey, Vessey, and Adelman under a September 27…
10. **29. Memorandum From Richard Davis of the National Security Council Staff to the President’s Deputy Assistant for National Security Affairs (Gates)** — Washington, June 8, 1989  
   `frus1989-92v31/d29` · score 0.9246  
   > SUBJECT Deputies Committee Meeting, Friday, June 9, 1989, 10:00 a.m.— START Positions on Mobile ICBM S, Mobile ICBM Verification and New Initiatives This Deputies Meeting will be the last of three meetings to review the specifics of our START position before the negotiations resume June 19. It will…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 2/10, bare: 0/10.*
*document variant:* frus1952-54v06p2/d1001, frus1961-63v21/d96, frus1950-55Intel/d156, frus1964-68v33/d274, frus1969-76ve02/d164, frus1958-60v01/d112, frus1981-88v41/d35, frus1952-54Guat/d103, frus1964-68v03/d237, frus1961-63v02/d328
*bare variant:* frus1958-60v01/d112, frus1969-76ve02/d164, frus1964-68v02/d9, frus1969-76ve12/d11, frus1981-88v01/d275, frus1961-63v02/d328, frus1969-76v35/d18, frus1964-68v03/d87, frus1952-54v01p2/d22, frus1961-63v02/d173

---

## Q21. washington naval conference ratios

### Lexical — `"washington" AND "naval" AND "conference" AND "ratios"`

1. **The Ambassador in Japan (Grew) to the Secretary of State** — Tokyo, February 1, 1934—5 p.m. [Received February 1—6:24 a.m.]  
   `frus1934v03/d21` · score -17.6485  
   > Yesterday in the Diet Foreign Minister Hirota stated in effect: “Japan’s policy toward the second Washington conference The first Washington Conference, from November 1921 to February 1922, dealt with naval armaments and with Far Eastern questions; for correspondence, see Foreign Relations, 1922,…
2. **The Minister in China (Johnson) to the Secretary of State** — Peiping, August 16, 1934. [Received September 8.]  
   `frus1934v03/d192` · score -17.4174  
   > Sir: I have the honor to report statements made on August 13, 1934, to a member of my staff by Mr. Hagiwara, an officer of the Asiatic Bureau of the Japanese Ministry for Foreign Affairs, now on tour in China, with regard to the Japanese attitude toward the next naval disarmament conference. It is…
3. **The Secretary of State to the Japanese Ambassador (Debuchi)** — [Washington, November 12, 1929.]  
   `frus1929v01/d180` · score -17.3394  
   > Aide-Mémoire You have asked me for an expression of my opinion as to the proposed ratio for Japan in the several classes to be dealt with at the London Conference, and you have suggested that Japan desires a ratio not of 5–3 but of 10–7 in the cruiser class particularly as to the type armed with…
4. **The Acting Chairman of the American Delegation (Gibson) to the Secretary of State** — Geneva, March 27, 1933—3 p.m. [Received March 27—10:25 a.m.]  
   `frus1933v01/d59` · score -17.3107  
   > Your 311, March 23, 6 p.m., reference paragraph on table following article 41 under air armaments. General comment indicates that we will not be alone in holding that numbers indicated are inadequate. In our opinion table should be redrafted in form to provide for four columns covering…
5. **Memorandum by the Chief of the Division of Far Eastern Affairs (Hornbeck) to the Secretary of State** — [Washington,] March 31, 1934.  
   `frus1934v01/d174` · score -17.2450  
   > Mr. Secretary: Referring further to the question of the (problematical) Naval Conference: Right or wrong, like it or not, this country is at the head of the column and therefore must function within and according to the character imposed upon it by virtue of its being in that position. We ought,…
6. **The Department of State to the Japanese Embassy**  
   `frus1929v01/d207` · score -16.6008  
   > Copies also sent to the British, French, and Italian Embassies. Memorandum During the stay in Washington of the Japanese Delegates to the London Naval Conference, they attended two meetings with the American Delegates to the Conference on Tuesday December 17 and Thursday December 19, 1929,…
7. **Memorandum by the Under Secretary of State (Phillips)** — [Washington,] May 24, 1934.  
   `frus1934v01/d184` · score -16.5515  
   > During my conversation with the President this morning he said that he wanted Assistant Secretary Roosevelt, Henry L. Roosevelt, Assistant Secretary of the Navy. Admiral Standley, William H. Standley, Chief of Naval Operations. Pierrepont Moffat Chief of the Division of Western European Affairs.…
8. **The Ambassador in Great Britain (Bingham) to the Secretary of State** — London, June 18, 1934—10 p.m. [Received June 18—8:20 p.m.]  
   `frus1934v01/d207` · score -16.5430  
   > From Norman Davis. Chairman of the American delegation to the General Disarmament Conference, temporarily in London for naval conversations. The first naval conversation took place this morning at 10 Downing Street. The Prime Minister, J. Ramsay MacDonald. the First Lord of the Admiralty, Sir…
9. **The Chargé in Japan (Neville) to the Secretary of State** — Tokyo, November 2, 1935. [Received November 18.]  
   `frus1931-41v01/d203` · score -16.3105  
   > Sir: I have the honor to observe that with Japan’s acceptance on October 29 of the British Government’s invitation to participate in the formal naval disarmament conference required by the Treaties, and which is to be held on December 2, next, the attitude of the Japanese Government is one of quiet…
10. **The Ambassador in Japan (Warren) to the Secretary of State** — Tokyo, December 3, 1921—2 p.m. [Received December 3—1:43 p.m.]  
   `frus1922v01/d47` · score -16.2280  
   > My telegram no. 403, November 30. There is evidence of Government efforts, since the Cabinet meeting yesterday, to prepare the public mind to consider the matter of ratio of naval strength as but part of the fundamental question of an agreement on Far Eastern and Pacific questions. As Uchida stated…

### Semantic (query prompt)

1. **The Secretary of State to the Japanese Ambassador (Debuchi)** — [Washington, November 12, 1929.]  
   `frus1929v01/d180` · score 0.8231  
   > Aide-Mémoire You have asked me for an expression of my opinion as to the proposed ratio for Japan in the several classes to be dealt with at the London Conference, and you have suggested that Japan desires a ratio not of 5–3 but of 10–7 in the cruiser class particularly as to the type armed with…
2. **The Chairman of the American Delegation (Davis) to the Secretary of State** — London, January 15, 1936—2 p.m. [Received January 15—11:27 a.m. Telegram in three sections.]  
   `frus1931-41v01/d211` · score 0.8048  
   > At this afternoon’s meeting following the Japanese exposition, it is planned that all of the delegations will make final statements in reply. Tenth meeting of the First Committee, January 15, 1936’, The London Naval Conference, 1935, p. 212. As the Japanese are planning to release their statement…
3. **The Department of State to the Japanese Embassy**  
   `frus1929v01/d207` · score 0.8017  
   > Copies also sent to the British, French, and Italian Embassies. Memorandum During the stay in Washington of the Japanese Delegates to the London Naval Conference, they attended two meetings with the American Delegates to the Conference on Tuesday December 17 and Thursday December 19, 1929,…
4. **Memorandum of Conversation Between the American and the Japanese Delegations** — [London,] December 17, 1935.  
   `frus1931-41v01/d206` · score 0.7963  
   > Present: Admiral Nagano Mr. Nagai Admiral Iwashita Mr. Terasaki Mr. Mizota Mr. Davis Mr. Phillips Admiral Standley Mr. Dooman Captain Ingersoll Commander Schuirmann Mr. Field In response to a request from Admiral Nagano in regard to the American proposal referred to by Mr. Davis at the opening…
5. **Memorandum by the Japanese Naval Experts** — [Washington,] November 30, 1921.  
   `frus1922v01/d43` · score 0.7962  
   > At the Second Plenary session of the Conference, Baron Kato, as Plenipotentiary Delegate for Japan, expressed his approval of the American proposal in general, and made a declaration of his determination to carry out a drastic reduction in naval armaments. At the same time, he stated that, in…
6. **The Ambassador in Japan (Warren) to the Secretary of State** — Tokyo, November 30, 1921—5 p.m. [Received 10:40 p.m.]  
   `frus1922v01/d42` · score 0.7952  
   > Your 202 of November 27, 10 p.m. An attempt has been made to organize a newspaper demand for fixed ratio of 10 to 7. Apparently it was inspired by the Japanese delegates in Washington through correspondents there, and continued in Japan by the Navy Department and by interested outside persons. It…
7. **Memorandum of a Meeting of Representatives of the State, War, and Navy Departments** — [Washington,] August 15, 1932.  
   `frus1932v01/d215` · score 0.7934  
   > Present: Chairman, William R. Castle, Jr., Under Secretary of State. For the Department of State: James Grafton Rogers, Assistant Secretary of State; Jay Pierrepont Moffat, Chief of the Division of Western European Affairs; and Noel H. Field. For the War Department: Brigadier General George S.…
8. **Memorandum by the Secretary of State** — [Washington,] December 2, 1929.  
   `frus1929v01/d192` · score 0.7908  
   > I had a long interview with the Japanese Ambassador this morning. He said first that he was instructed by his Government to tell me two things. First, that in regard to my former note as to what took place at the Washington Conference Baron Shidehara wanted to call my attention to the fact, in…
9. **The Secretary of State to the Chairman of the American Delegation to the London Naval Conference (Davis)** — [Washington,] November 26, 1935.  
   `frus1935v01/d147` · score 0.7905  
   > My Dear Mr. Davis: With reference to your appointment by the President as Chairman of the American Delegation to the forthcoming Naval Conference at London, I am sending you herewith for your guidance, a memorandum, setting forth in the form of questions and answers, certain comments and views with…
10. **The Secretary of State to the Chairman of the American Delegation (Gibson)** — Washington, July 25, 1927—12 noon.  
   `frus1927v01/d126` · score 0.7886  
   > Your No. 114, July 22, 1 p.m. My No. 55, July 19, 4 p.m., answering your No. 106, July 18, 11 p.m., was intended to allow latitude for slight variations which were reconxmended by naval experts at Conference and reported in your No. 106, and which were approved here. Naturally we have no interest…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **The Secretary of State to the Japanese Ambassador (Debuchi)** — [Washington, November 12, 1929.]  
   `frus1929v01/d180` · score 0.9557  
   > Aide-Mémoire You have asked me for an expression of my opinion as to the proposed ratio for Japan in the several classes to be dealt with at the London Conference, and you have suggested that Japan desires a ratio not of 5–3 but of 10–7 in the cruiser class particularly as to the type armed with…
2. **The Ambassador in Japan (Grew) to the Secretary of State** — Tokyo, February 1, 1934—5 p.m. [Received February 1—6:24 a.m.]  
   `frus1934v03/d21` · score 0.9384  
   > Yesterday in the Diet Foreign Minister Hirota stated in effect: “Japan’s policy toward the second Washington conference The first Washington Conference, from November 1921 to February 1922, dealt with naval armaments and with Far Eastern questions; for correspondence, see Foreign Relations, 1922,…
3. **Memorandum by the Chief of the Division of Far Eastern Affairs (Hornbeck) to the Secretary of State** — [Washington,] March 31, 1934.  
   `frus1934v01/d174` · score 0.9375  
   > Mr. Secretary: Referring further to the question of the (problematical) Naval Conference: Right or wrong, like it or not, this country is at the head of the column and therefore must function within and according to the character imposed upon it by virtue of its being in that position. We ought,…
4. **The Ambassador in Japan (Grew) to the Secretary of State** — Tokyo, July 5, 1934. [Received July 23.]  
   `frus1934v03/d563` · score 0.9371  
   > Sir: I have the honor to report that the progress of the preliminary naval conversations in London between the United States and Great Britain has been followed with the greatest interest in this country and there is a perceptible hardening of public opinion on the question of abolishing the ratio…
5. **The Secretary of State to the Acting Chairman of the American Delegation (Gibson)** — Washington, June 7, 1932—noon.  
   `frus1932v01/d101` · score 0.9349  
   > To the Delegation. Your 220, May 28, 2 p.m. 1. I am wholly sympathetic with your desire to be so prepared that it will be unnecessary for you to discourage the cause of disarmament by holding back in case a situation for a real measure of success should arise. This does not, however, require that…
6. **The Chairman of the American Delegation to the General Disarmament Conference (Davis) to President Roosevelt** — London, March 6, 1934.  
   `frus1934v01/d173` · score 0.9331  
   > A memorandum from President Roosevelt to the Secretary of State, March 26, 1934, attached to photostatic copy of this letter reads as follows: “Will you read this and let me know if there is anything you think we should do at this time? F. D. R.” For reply from the Secretary of State to Mr. Davis,…
7. **The Minister in China (Johnson) to the Secretary of State** — Peiping, August 16, 1934. [Received September 8.]  
   `frus1934v03/d192` · score 0.9327  
   > Sir: I have the honor to report statements made on August 13, 1934, to a member of my staff by Mr. Hagiwara, an officer of the Asiatic Bureau of the Japanese Ministry for Foreign Affairs, now on tour in China, with regard to the Japanese attitude toward the next naval disarmament conference. It is…
8. **The Chairman of the American Delegation (Davis) to the Secretary of State** — London, January 15, 1936—2 p.m. [Received January 15—11:27 a.m. Telegram in three sections.]  
   `frus1931-41v01/d211` · score 0.9322  
   > At this afternoon’s meeting following the Japanese exposition, it is planned that all of the delegations will make final statements in reply. Tenth meeting of the First Committee, January 15, 1936’, The London Naval Conference, 1935, p. 212. As the Japanese are planning to release their statement…
9. **The Ambassador in Japan (Grew) to the Secretary of State** — Tokyo, September 15, 1933. [Received September 30.]  
   `frus1931-41v01/d180` · score 0.9317  
   > Sir: Japanese naval leaders find themselves at present in a serious quandary. They have, since the ratification of the London Treaty London Naval Treaty, signed at London, April 22, 1930, Department of State Treaty Series No. 830. and especially in the past year or more, insisted that Japan must…
10. **The Ambassador in Japan (Castle) to the Acting Secretary of State** — Tokyo, February 14, 1930—9 p.m. [Received February 14—11:55 a.m.]  
   `frus1930v01/d20` · score 0.9295  
   > Your telegram No. 36, February 13, 5 p.m. Please repeat to London. Transmitted to the American delegation as Department’s telegram No. 103, February 14, noon. I think that certain thoughtful Japanese regret that demand for 10–7 ratio in auxiliary ships was made practically a sine qua non of the…

*Route overlap: 2 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 4/10.*
*document variant:* frus1929v01/d180, frus1931-41v01/d211, frus1922v01/d42, frus1922v01/d43, frus1922v01/d88, frus1929v01/d207, frus1929v01/d147, frus1929v03/d5, frus1935v01/d147, frus1931-41v01/d206
*bare variant:* frus1929v01/d180, frus1929v03/d5, frus1931-41v01/d211, frus1922v01/d88, frus1929v01/d207, frus1929v01/d147, frus1929v01/d132, frus1929v01/d144, frus1931-41v01/d206, frus1919Parisv09/d26

---

## Q22. sussex pledge

### Lexical — `"sussex" AND "pledge"`

1. **The Secretary of State to the Ambassador in Germany (Gerard)** — Washington, April 18, 1916, 6 p. m.  
   `frus1916Supp/d308` · score -16.9314  
   > You are instructed to deliver to the Secretary of Foreign Affairs a communication reading as follows: I did not fail to transmit immediately, by telegraph, to my Government your excellency’s note of the 10th instant in regard to certain attacks by German submarines, and particularly in regard to…
2. **The Ambassador in Germany (Gerard) to the Secretary of State** — Berlin, January 16, 1917. [Received February 6.]  
   `frus1914-20v01/d656` · score -15.6243  
   > Dear Mr. Secretary: The nearer I get to the situation the more I consider the President’s peace note an exceedingly wise move. It has made it difficult for the Terrorists here to start anything which will bring Germany in conflict with the U. S. The Chancellor, Zimmermann, Stumm; have all ridiculed…
3. **The Secretary of State to President Wilson** — Washington, May 10, 1916.  
   `frus1914-20v01/d536` · score -15.4604  
   > My Dear Mr. President: In the submarine controversy we will unavoidably be forced to meet a situation which will arise, if it has not already arisen, and to determine on a course of action. The problem is this: A German submarine torpedoes, without conforming in any way to the rules of…
4. **Draft Instructions to the Ambassador in Germany (Gerard)** — undated  
   `frus1914-20v01/d509` · score -13.5687  
   > This paper bears the notation: “Original handed to Prest for his consideration 2:30 pm April 6/16. RL.” See also footnote 34, p. 546. undated You are instructed to deliver to the Secretary of Foreign Affairs a note reading as follows: On March 24, 1916, at two-fifty p. m. the unarmed steamer…
5. **The Secretary of State to the Chairman of the Senate Committee on Privileges and Elections (Pomerene)** — Washington, November 26, 1917.  
   `frus1914-20v02/d53` · score -12.2323  
   > My Dear Senator Pomerene: Referring to your letter of October 16th last and to our conversations regarding certain data which the subcommittee of the Committee on Privileges and Elections desires from the Department in relation to the address made by Senator La Follette before the Non-partisan…
6. **Mr. Adams to Mr. Seward.** — Legation of the United States, London, May 13, 1864.  
   `frus1864p1/d394` · score -2.6796  
   > Sir: I have the honor to transmit a copy of the London Times, containing a report of the speech of Mr. Gladstone, in the House of Commons, on Wednesday afternoon, on the question of franchise. I need not say that this is one of the most significant events of the day. It at once marks out the shape…

### Semantic (query prompt)

1. **Chief Baron Pigott’s refusal of a mixed jury in Warren’s case.** — [undated.]  
   `frus1873p1v2/d279` · score 0.7323  
   > The Chief Baron. My learned brother and I do not entertain the least doubt as to the course we ought to adopt in reference to this proceeding. It is essential to sustain the application; and, assuming the court has the power to grant it, the practice has been invariably to award a jure de…
2. **Mr. Adams to Mr. Seward.** — Legation of the United States, London, February 6, 1867.  
   `frus1867p1/d33` · score 0.7323  
   > Sir: I have to acknowledge the reception of despatches from the department, numbered from 1910 to 1924 inclusive, and likewise a box containing a gold watch intended for Captain Furney. Parliament was opened yesterday in form by the Queen, and her speech was read, a copy of which is herewith…
3. **The Secretary of State to the Ambassador in Great Britain (Page)** — Washington, April 4, 1916, 7 p. m.  
   `frus1916Supp/d294` · score 0.7238  
   > Please ascertain definitely whether the Sussex was ever used by the British Government as a transport or troopship and whether the route followed by transports is the same as that followed by the Sussex on her last trip. Lansing
4. **Mr. Adams to Mr. Seward.** — Legation of the United States, London, August 30, 1861.  
   `frus1861/d74` · score 0.7225  
   > Sir: It is not without regret that I am compelled to announce the failure of the negotiation which I am led, by the tenor of your despatches, Nos. 55 and 58, to infer you considered almost sure to succeed. I have now the honor to transmit the copy of a note addressed by me to Lord Russell on the…
5. **Mr. Adams to Mr. Seward.** — Legation of the United States, London, June 28, 1866.  
   `frus1866p1/d124` · score 0.7213  
   > Sir: I have the honor to transmit a copy of the proclamation of neutrality issued by the Queen in regard to the conflict which is now raging on the continent. The tendency of the news of the past week is to show that the military position of Austria will not be easy to deal with by eitheror both of…
6. **General Schenck to Mr. Fish** — Legation of the United States, London, June 22, 1871. (Received July 6.)  
   `frus1871/d226` · score 0.7193  
   > Sir: Last Friday, the 16th, I sent a telegram informing you that the next day was appointed for the exchange of ratifications of the treaty. * * * * * * * A copy of that telegram is inclosed. * * * I have the satisfaction to inform you that, having produced and exchanged powers from our respective…
7. **Mr. Adams to Mr. Seward.** — Legation of the United States, London, April 30, 1863.  
   `frus1863p1/d175` · score 0.7192  
   > Sir: I have the honor to transmit a copy of one of the official publications made for the use of Parliament, containing the correspondence that has passed between Lord Russell and myself on the subject of the intercepted despatches and the rebel agents in England. You will doubtless take note of…
8. **Mr. Adams to Mr. Seward** — Legation of the United States, London, November 29, 1867.  
   `frus1868p1/d1` · score 0.7190  
   > Sir: I have to acknowledge the reception of your dispatch No. 2090, of the 15th of November, in relation to the case of Captain John Warren, and likewise of a telegram by the cable on the 28th, instructing me to forward immediately the statutes of treason-felony under which he was tried. I infer…
9. **Mr. Stuart to Mr. Seward.** — Washington, November 9, 1862.  
   `frus1863p1/d317` · score 0.7154  
   > Sir: With reference to the note which I had the honor to address to you on the 1st instant, and to your answer of the 3d instant relative to the capture of the British steamer Sunbeam, I have now the honor to enclose a copy of a further protest relating to that capture, and to call your attention…
10. **Mr. Seward to Mr. Adams.** — Department of State, Washington, November 23, 1863.  
   `frus1863p1/d675` · score 0.7153  
   > Sir: I transmit the originals of certain recently intercepted insurgent correspondence which have been published in the newspapers. It has occurred to the Secretary of the Navy that they might be useful to you for judicial or diplomatic purposes, and perhaps for both. If he should be mistaken in…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **Draft Instructions to the Ambassador in Germany (Gerard)** — undated  
   `frus1914-20v01/d509` · score 0.9584  
   > This paper bears the notation: “Original handed to Prest for his consideration 2:30 pm April 6/16. RL.” See also footnote 34, p. 546. undated You are instructed to deliver to the Secretary of Foreign Affairs a note reading as follows: On March 24, 1916, at two-fifty p. m. the unarmed steamer…
2. **The Secretary of State to the Ambassador in Germany (Gerard)** — Washington, April 18, 1916, 6 p. m.  
   `frus1916Supp/d308` · score 0.9483  
   > You are instructed to deliver to the Secretary of Foreign Affairs a communication reading as follows: I did not fail to transmit immediately, by telegraph, to my Government your excellency’s note of the 10th instant in regard to certain attacks by German submarines, and particularly in regard to…
3. **The Counselor for the Department of State (Lansing) to the Secretary of State** — [Washington,] May 12, 1915.  
   `frus1914-20v01/d350` · score 0.9436  
   > Dear Mr. Secretary: I enclose herewith the draft prepared by the President in re Lusitania. The method which I have adopted in making suggestions is to put in brackets the portions of the President’s draft which I would omit, and underscoring the words which I would add. I feel that the…
4. **The Counselor for the Department of State (Lansing) to the Secretary of State** — [Washington,] June 7, 1915.  
   `frus1914-20v01/d392` · score 0.9417  
   > Dear Mr. Secretary: I enclose herewith the President’s draft of a note to Germany with suggested changes indicated by underlining and parentheses. Actually, brackets were used by Mr. Lansing rather than parentheses. For text of the note as sent, see Foreign Relations, 1915, supp., p. 436. The…
5. **The Ambassador in Germany (Gerard) to the Secretary of State** — Berlin, May 4, 1916, 6 p. m. [Received May 5, 7.30-10 p. m.]  
   `frus1916Supp/d337` · score 0.9414  
   > Following is the text of the note handed to me both in German and English at 5.30 this afternoon by Secretary of State for Foreign Affairs: Foreign Office, Berlin, May 4, 1916. The undersigned, on behalf of the Imperial Government, has the honor to present to his excellency the Ambassador of the…
6. **The Secretary of State to President Wilson** — Washington, March 27, 1916.  
   `frus1914-20v01/d507` · score 0.9413  
   > My Dear Mr. President: All the information which we are receiving in regard to the sinking of the Sussex in the English Channel, by which several Americans were injured and some undoubtedly killed, indicates that the vessel was torpedoed by a German submarine. For correspondence previously printed…
7. **The Secretary of State to President Wilson** — Washington, April 10, 1916.  
   `frus1914-20v01/d510` · score 0.9397  
   > My Dear Mr. President: I enclose a suggested insertion in the draft of instructions to the American Ambassador at Berlin, which I handed to you at the White House on the 6th instant. Supra. The suggestion is due to Mr. Gerard’s telegram #3713 of April 6th. Foreign Relations, 1916, supp., p. 225. I…
8. **The Secretary of State to the Chairman of the Senate Committee on Privileges and Elections (Pomerene)** — Washington, November 26, 1917.  
   `frus1914-20v02/d53` · score 0.9386  
   > My Dear Senator Pomerene: Referring to your letter of October 16th last and to our conversations regarding certain data which the subcommittee of the Committee on Privileges and Elections desires from the Department in relation to the address made by Senator La Follette before the Non-partisan…
9. **The Secretary of State to President Wilson** — Washington, May 10, 1916.  
   `frus1914-20v01/d536` · score 0.9365  
   > My Dear Mr. President: In the submarine controversy we will unavoidably be forced to meet a situation which will arise, if it has not already arisen, and to determine on a course of action. The problem is this: A German submarine torpedoes, without conforming in any way to the rules of…
10. **Address of the President of the United States to Congress, February 3, 1917** — February 3, 1917  
   `frus1917Supp01v01/d100` · score 0.9341  
   > Gentlemen of the Congress: The Imperial German Government on the 31st of January announced to this Government and to the governments of the other neutral nations that on and after the 1st day of February, the present month, it would adopt a policy with regard to the use of submarines against all…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 6/10.*
*document variant:* frus1873p1v2/d279, frus1870/d272, frus1868p1/d7, frus1863p1/d175, frus1873p1v2/d204, frus1861/d74, frus1865p2/d181, frus1863p1/d675, frus1871/d226, frus1868p1/d1
*bare variant:* frus1864p1/d333, frus1873p1v2/d279, frus1863p1/d175, frus1866p1/d124, frus1868p1/d1, frus1867p1/d33, frus1865p2/d181, frus1865p1/d369, frus1868p1/d76, frus1861/d74

---

## Q23. "trust but verify"

### Lexical — `"trust but verify"`

1. **168. Memorandum From the Special Advisor to the President and Secretary of State on Arms Control Matters (Nitze) to Secretary of State Shultz** — Washington, October 29, 1986  
   `frus1981-88v11/d168` · score -5.6972  
   > SUBJECT NSPG Meeting, 11:00 a.m., October 27, 1986 Formal minutes of this meeting are printed in Foreign Relations, 1981–1988, vol. VI, Soviet Union, October 1986–January 1989, Document 3. John Poindexter summarized the agreement reached at Reykjavik: a. 50% reductions in strategic arms to 1,600…
2. **301. Memorandum of Conversation** — Reykjavik, October 11, 1986, 10:40 a.m.–12:30 p.m.  
   `frus1981-88v05/d301` · score -4.7043  
   > Source: Reagan Library, Jack Matlock Files, Chronological File, 1980–1986, Matlock Chron October 1986 (4/6). Secret. Drafted by Zarechnak. The meeting took place at Hofdi House. Reagan wrote in his diary on October 11: “A.M. a briefing session then a 5 min. drive to the meeting place—a waterfront…
3. **3. Minutes of a National Security Planning Group Meeting** — Washington, October 27, 1986, 11 a.m.–noon  
   `frus1981-88v06/d3` · score -4.2426  
   > SUBJECT Arms Control Follow-up to Reykjavik (U) PARTICIPANTS The President State Secretary George Shultz Treasury Secretary James Baker Defense Secretary Caspar Weinberger Mr. Richard Perle Energy Secretary John Herrington OMB Mr. James Miller ACDA Mr. Kenneth Adelman CIA Mr. Douglas George JCS…
4. **335. Address by President Reagan to the Nation** — Washington, January 11, 1989  
   `frus1981-88v01/d335` · score -4.0982  
   > Farewell Address to the Nation My fellow Americans: This is the 34th time I’ll speak to you from the Oval Office and the last. We’ve been together 8 years now, and soon it’ll be time for me to go. But before I do, I wanted to share some thoughts, some of which I’ve been saving for a long time. It’s…
5. **306. Remarks by President Reagan** — Los Angeles, August 26, 1987  
   `frus1981-88v01/d306` · score -3.7184  
   > Remarks on Soviet-United States Relations at the Town Hall of California Meeting in Los Angeles Before we begin, I hope you’ll forgive me for saying that it’s good to be back in California. Actually, I didn’t realize how completely I made the transition from Washington until I got on a helicopter…
6. **333. Remarks by President Reagan** — Charlottesville, Virginia, December 16, 1988  
   `frus1981-88v01/d333` · score -3.2437  
   > Remarks and a Question-and-Answer Session at the University of Virginia in Charlottesville [Omitted here are the President’s introductory remarks and his comments about President Thomas Jefferson, the founder of the University of Virginia.] Well, that was politics in 1800. So, you see, not all that…
7. **360. Memorandum of Conversation** — Washington, July 27, 1988, 11 a.m.–1:40 p.m.  
   `frus1981-88v10/d360` · score -2.8668  
   > SUBJECT The President’s Meeting with General Secretary Karoly Grosz of Hungary PARTICIPANTS U.S. The President Secretary of State George P. Shultz Secretary of Treasury James A. Baker, III Secretary of Commerce C. William Verity Kenneth M. Duberstein, Chief of Staff M. B. Oglesby, Deputy Chief of…
8. **68. Memorandum of Conversation** — Washington, September 15, 1987, 3:30–5:30 p.m.  
   `frus1981-88v06/d68` · score -2.7635  
   > SUBJECT First Shultz - Shevardnadze Plenary PARTICIPANTS U.S. The Secretary Ambassador Kampelman Ambassador Ridgway Ambassador Nitze Ambassador Matlock Director Adelman Col. Linhard Mr. Simons (notetaker) U.S.S.R Foreign Minister Shevardnadze Dep. FonMin Bessmertnykh Ambassador Karpov Ambassador…
9. **308. Memorandum of Conversation** — Moscow, May 30, 1988, 9:15 a.m.–12:05 p.m.  
   `frus1981-88v11/d308` · score -2.3590  
   > SUBJECT Defense and Space, START PARTICIPANTS U.S. AMB Nitze AMB Kampelman AMB Hanmer AMB Cooper AMB Rowny AS Lehman ADM Howe COL Linhard Mr. Castillo Dr. Timbie Dr. Graham Mr. Richardson Mr. Korobovsky (Interpreter) Mr. Stafford (Notetaker) USSR MSU Akhromeyev AMB Obukhov AMB Kuznetsov AMB…

### Semantic (query prompt)

1. **38. Letter From the Chairman of the President’s Foreign Intelligence Advisory Board (Armstrong) to President Reagan** — Washington, September 20, 1982  
   `frus1981-88v11/d38` · score 0.7320  
   > Dear Mr. President: In response to your May 13 tasking, According to an undated paper titled “Tasking for PFIAB Review of START monitoring,” Reagan told the PFIAB at a May 13 meeting: “I would like you to examine the intelligence community’s capability, methodology, and organization for monitoring,…
2. **The Acting Secretary of State to Minister Rockhill.** — Department of State, Washington, December 13, 1907.  
   `frus1908/d165` · score 0.7167  
   > (Mr. Bacon refers to department’s telegraphic instruction of June 8, 1906, and instructs Mr. Rockhill to report whether the claims of American citizens have been carefully substantiated, and to forward them to department for approval.)
3. **96. Editorial Note**  
   `frus1961-63v21/d96` · score 0.7166  
   > 96. Editorial Note [Text not declassified.]
4. **3. Telegram From the Department of State to the Embassy in the Soviet Union** — Washington, November 15, 1981, 0222 Z  
   `frus1981-88v11/d3` · score 0.7136  
   > Subject: Soviet reply to Rostow/ Bessmertnykh conversation of August 21. See Document 2. Ref: State 229568. See footnote 7, Document 2. 1. Secret–entire text. 2. In the course of a luncheon a deux at the Soviet Embassy at Dobrynin’s invitation on 11 November, the Soviet ambassador gave ACDA…
5. **No. 9. Mr. Gresham to Mr. Baker.** — Department of State, Washington, March 7, 1894.  
   `frus1894Nicaragua/d9` · score 0.7112  
   > If you verify Braida’s telegram report alleged grounds for landing
6. **Mr. Hay to Mr. Conger.** — Department of State, Washington, July 21, 1900.  
   `frus1900/d137` · score 0.7105  
   > Dispatch received. Authenticity doubted. Answer this, giving your sister’s name. Report attitude and position of Chinese Government. Hay.
7. **The Secretary of State to the Minister in the Netherlands (Van Dyke)** — Washington, June 8 1915.  
   `frus1915Supp/d1015` · score 0.7104  
   > Repeated to the Ambassador in Great Britain, No. 1685, June 8. [Telegram] Washington, June 8 1915. 164. Would Netherlands Oversea Trust receive and forward to addressees telegrams relating to orders for materials, shipping and other necessary directions, acknowledgments and transfer of payments,…
8. **181. Letter From Soviet General Secretary Brezhnev to President Carter** — March 11, 1979  
   `frus1977-80v06/d181` · score 0.7099  
   > Dear Mr. President, I received your letter of March 7. See Document 180. Like you, I feel satisfied with the fact that we are on the threshold of completing the preparation of the strategic arms limitation agreement. I am confident that our compromise proposals, including those transmitted recently…
9. **41. National Security Decision Directive 65** — Washington, November 10, 1982  
   `frus1981-88v11/d41` · score 0.7077  
   > ESTABLISHMENT OF NATIONAL SECURITY COUNCILARMS CONTROL VERIFICATION COMMITTEE (U) Compliance with the provision of existing and future arms control agreements is essential to their success and therefore to US national security. Effective verification is necessary to ensure compliance with those…
10. **The United States Representative at the United Nations (Austin) to the Secretary of State** — New York, May 19, 1948—2:15 p. m.  
   `frus1948v05p2/d290` · score 0.7068  
   > A copy of telegram 674 was sent by Brig. Gen. Carter to Mr. Connelly under cover of a memorandum which read as follows: “Secretary Marshall asked me to see that the attached message is Drought to the immediate attention of the President.” (Truman Papers, President’s Secretary’s File) top secret New…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **3. Minutes of a National Security Planning Group Meeting** — Washington, October 27, 1986, 11 a.m.–noon  
   `frus1981-88v06/d3` · score 0.9674  
   > SUBJECT Arms Control Follow-up to Reykjavik (U) PARTICIPANTS The President State Secretary George Shultz Treasury Secretary James Baker Defense Secretary Caspar Weinberger Mr. Richard Perle Energy Secretary John Herrington OMB Mr. James Miller ACDA Mr. Kenneth Adelman CIA Mr. Douglas George JCS…
2. **119. Notes of a Conversation** — Geneva, November 19, 1985  
   `frus1981-88v11/d119` · score 0.9631  
   > SUMMARY RECORD President Reagan: —When we last met (this morning), Memoranda of conversation for Reagan and Gorbachev’s private and plenary morning meetings are scheduled for publication in Foreign Relations, 1981–1988, vol. V, Soviet Union March 1985–October 1986, Documents 150 and 151. we agreed…
3. **306. Remarks by President Reagan** — Los Angeles, August 26, 1987  
   `frus1981-88v01/d306` · score 0.9617  
   > Remarks on Soviet-United States Relations at the Town Hall of California Meeting in Los Angeles Before we begin, I hope you’ll forgive me for saying that it’s good to be back in California. Actually, I didn’t realize how completely I made the transition from Washington until I got on a helicopter…
4. **138. Telegram From the Embassy in the Soviet Union to the Department of State** — Moscow, November 6, 1985, 1550 Z  
   `frus1981-88v05/d138` · score 0.9613  
   > Source: Reagan Library, George Shultz Papers, Memoranda of Conversations 1985. Secret; Immediate; Nodis; Adam. Special Encryption. Moscow, November 6, 1985, 1550 Z 15987. Subject: Secretary’s Meeting With Gorbachev, Nov. 5, 1985. Talking points prepared for Shultz for this meeting are in the Reagan…
5. **168. Memorandum From the Special Advisor to the President and Secretary of State on Arms Control Matters (Nitze) to Secretary of State Shultz** — Washington, October 29, 1986  
   `frus1981-88v11/d168` · score 0.9598  
   > SUBJECT NSPG Meeting, 11:00 a.m., October 27, 1986 Formal minutes of this meeting are printed in Foreign Relations, 1981–1988, vol. VI, Soviet Union, October 1986–January 1989, Document 3. John Poindexter summarized the agreement reached at Reykjavik: a. 50% reductions in strategic arms to 1,600…
6. **306. Memorandum of Conversation** — Reykjavik, October 12, 1986, 10 a.m.–1:35 p.m.  
   `frus1981-88v05/d306` · score 0.9584  
   > Source: Reagan Library, Jack Matlock Files, US - USSR Summits, 1985–1986, Reykjavik Meeting—Geneva Materials Oct 12–13, 1986 (2). Secret; Sensitive. The meeting took place at Hofdi House. No drafting information appears on the memorandum of conversation. For the Soviet record of the meeting, see…
7. **302. Memorandum of Conversation** — Reykjavik, October 11, 1986, 3:30–5:40 p.m.  
   `frus1981-88v05/d302` · score 0.9580  
   > Source: Reagan Library, Jack Matlock Files, US - USSR Summits, 1985–1986, Reykjavik Meeting—Geneva Materials 10/12/86–10/13/86 (2). Secret; Sensitive. Drafted by Simons. The meeting took place at Hofdi House. In his diary on October 11, Reagan wrote: “In the afternoon we had at it and looked like…
8. **314. Address by President Reagan to the Nation** — Washington, December 10, 1987  
   `frus1981-88v01/d314` · score 0.9562  
   > Address to the Nation on the Soviet-United States Summit Meeting Good evening. As I am speaking to you now, General Secretary Gorbachev is leaving on his return trip to the Soviet Union. His departure marks the end of 3 historic days here in Washington in which Mr. Gorbachev and I continued to…
9. **158. Memorandum of Conversation** — Moscow, May 30, 1988, 10–11:45 a.m.  
   `frus1981-88v06/d158` · score 0.9561  
   > SUBJECT First Plenary Meeting (U) PARTICIPANTS US The President Secretary George P. Shultz Secretary Frank C. Carlucci Senator Howard Baker General Colin Powell Ambassador Rozanne Ridgway Ambassador Jack Matlock Mark Parris, Department of State (Notetaker) Nelson C. Ledsky, NSC (Notetaker) USSR…
10. **143. Memorandum From Secretary of State Shultz to President Reagan** — Washington, November 12, 1985  
   `frus1981-88v05/d143` · score 0.9549  
   > Source: Reagan Library, Jack Matlock Files, Chronological File, 1980–1986, Matlock Chron November 1985 (4/10). Secret; Sensitive. All brackets are in the original. No drafting information appears on the memorandum. According to an undated action memorandum from Ridgway to Shultz, under which…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 1/10, bare: 2/10.*
*document variant:* frus1952-54v06p2/d1001, frus1961-63v21/d96, frus1964-68v31/d36, frus1969-76v20/d83, frus1950-55Intel/d156, frus1964-68v33/d227, frus1969-76v41/d227, frus1977-80v11p1/d255, frus1964-68v29p2/d24, frus1989-92v31/d21
*bare variant:* frus1952-54v06p2/d1001, frus1961-63v21/d96, frus1981-88v11/d32, frus1950-55Intel/d156, frus1981-88v11/d38, frus1989-92v31/d21, frus1977-80v26/d189, frus1981-88v11/d13, frus1981-88v11/d2, frus1969-76ve02/d164

---

## Q24. persona non grata

### Lexical — `"persona" AND "non" AND "grata"`

1. **United States concern over the assassination of a Legation employee considered “persona non grata” by the Ethiopian government**  
   `frus1947v05/ch8` · score -30.0767  
   > [Mr. Johannes Semerjibashian, who was serving as dragoman-interpreter of the American Legation at Addis Ababa even though the Ethiopian Government had declared him persona non grata soon after his employment in July 1946, was assassinated on the evening of October 9, 1947, while in a Legation car…
2. **The Acting Secretary of State to the Legation in Hungary** — Washington, November 24, 1947—6 p. m.  
   `frus1947v04/d273` · score -27.8431  
   > top secret urgent niact Washington, November 24, 1947—6 p. m. 1191. While we agree in principle as indicated Deptel 1188 Nov 22 Not printed. that you should assume responsibility for official activities subordinate members Legation (urtel 1871, Nov. 21) we cannot question right Hungarians declare…
3. **Memorandum by the Chief of the Division of Security (Nicholson) to the Director of the Office of Middle American Affairs (Mann)** — [Washington,] April 5, 1950.  
   `frus1950v02/d450` · score -27.1125  
   > Memorandum by the Chief of the Division of Security (Nicholson) This memorandum was also marked for the attention of W. Tapley Bennett, Jr., Officer in Charge of Central America and Panama Affairs. to the Director of the Office of Middle American Affairs (Mann) [Extract] confidential [Washington,]…
4. **Editorial Note**  
   `frus1950v04/d537` · score -26.8183  
   > In a note of March 10 to the Legation in Budapest, the Hungarian Foreign Ministry declared Military Attaché Col. James B. Kraft, Assistant Military Attaché Lt. Col. John T. Hoyne, and Assistant Air Attaché Maj. Donald E. Griffin personae non gratae and requested their recall. The note further…
5. **355. Memorandum From the Assistant Secretary of State for Near Eastern, South Asian, and African Affairs (Rountree) to the Acting Secretary of State** — Washington, August 13, 1957.  
   `frus1955-57v13/d355` · score -26.3465  
   > SUBJECT Proposed Steps in Response to Syrian Government Actions Against the United States Discussion: The Syrian Government over the past several months has been taking an increasingly unfriendly attitude towards the United States and concurrently establishing closer ties with the Soviet Union. It…
6. **The Italian Ambassador (Colonna) to the Secretary of State** — Washington, April 8, 1941—XIX.  
   `frus1941v02/d797` · score -26.2364  
   > Mr. Secretary of State: I have the honor to inform you that the request of the United States Government, transmitted with your Note of April 2, 1941, that Admiral Alberto Lais, Naval Attaché of the Royal Italian Embassy, be immediately withdrawn from the United States being at present persona non…
7. **The Chargé in Bulgaria (O’Donoghue) to the Secretary of State** — Sofia, March 17, 1949—3 p. m.  
   `frus1949v05/d204` · score -25.5885  
   > secret Sofia, March 17, 1949—3 p. m. 225. Legtel 216, March 15. On March 9 the Bulgarian Government declared Denis A. Greenhill, First Secretary of the British Legation in Sofia, persona non grata. Greenhill, together with several former and current members of the British and American missions in…
8. **The Secretary of State to the Embassy in Poland** — Washington, April 7, 1950—7 p. m.  
   `frus1950v04/d560` · score -25.0851  
   > confidential Washington, April 7, 1950—7 p. m. 169. Re Embtel 399 Mar 15 Supra. and Desp 463 Mar 21. Not printed, but see footnote 3, supra. If no objection, deliver fol Aide-Mémoire to Acting FonMin in reply his communication Mar 15. (Begin verbatim text) Reference is made to the Fon Ministry’s…
9. **Memorandum of Conversation, by the Assistant Secretary of State (Long)** — [Washington,] September 2, 1944.  
   `frus1944v05/d255` · score -24.9450  
   > The British Ambassador came in to see me by appointment arranged by the Secretary’s office. Prior to the arrival of Lord Halifax but after reading the ticker text Printed as annex to this memorandum. of the quotation from the Caroe telegram to the British Foreign Office, and after talking again…
10. **109. Telegram From the Embassy in the Soviet Union to the Department of State** — Moscow, May 12, 1965, 1305Z.  
   `frus1964-68v14/d109` · score -24.9137  
   > Subject: Norris Garnett PNG Case. On May 11 the Foreign Ministry had declared Norris D. Garnett, Assistant Cultural Officer at the U.S. Embassy and the first African-American assigned there, persona non grata for carrying on work hostile to the USSR among African students. We have following…

### Semantic (query prompt)

1. **The Ambassador in Italy (Fletcher) to the Secretary of State** — Rome, July 22, 1925—5 p.m. [Received July 22—2:42 p.m.]  
   `frus1925v02/d319` · score 0.7224  
   > A note has been received from the Under Secretary for Foreign Affairs, which states that on account of reports contained in recent telegraphic news despatches sent to the Chicago Tribune by George Seldes, Tribune correspondent at Rome, he is to be considered persona non grata in Italy, and I am…
2. **109. Telegram From the Embassy in the Soviet Union to the Department of State** — Moscow, May 12, 1965, 1305Z.  
   `frus1964-68v14/d109` · score 0.7221  
   > Subject: Norris Garnett PNG Case. On May 11 the Foreign Ministry had declared Norris D. Garnett, Assistant Cultural Officer at the U.S. Embassy and the first African-American assigned there, persona non grata for carrying on work hostile to the USSR among African students. We have following…
3. **Editorial Note**  
   `frus1948v04/d244` · score 0.7171  
   > On July 16, 1948, in response to their request, Vice Consul Donald F. Ewing of the Legation in Sofia agreed to meet, outside the Legation, two Bulgarian acquaintances whom he had previously known in connection with the visa work of the Legation. The Bulgarian secret police arrested the two…
4. **The Acting Secretary of State to the Legation in Hungary** — Washington, November 24, 1947—6 p. m.  
   `frus1947v04/d273` · score 0.7157  
   > top secret urgent niact Washington, November 24, 1947—6 p. m. 1191. While we agree in principle as indicated Deptel 1188 Nov 22 Not printed. that you should assume responsibility for official activities subordinate members Legation (urtel 1871, Nov. 21) we cannot question right Hungarians declare…
5. **Mr. Washburn to Señor Benitez.** — Legation of the United States, Asuncion, August 13, 1868.  
   `frus1868p2/d443` · score 0.7140  
   > Sir: Excusing myself for the delay in answering that part of your note of the 31st ultimo, relating to the case of Mr. Bliss and Mr. Masterman, which I have deferred in order to answer the part of it which seemed to me of more pressing importance, and also to answer your subsequent very long note…
6. **Mr. Terrell to Mr. Gresham.** — Legation of the United States, Legation of the United States, February 17, 1895. (Received March 8.)  
   `frus1894/d750` · score 0.7068  
   > Sir: I have secured through an unofficial request the recognition by iradé of the acquired nationality of Socrates Seferiades, about whom there was so much trouble. He is a native Greek and a gentleman. He failed to inform me of facts regarding his business connection with American industries,…
7. **249. Letter From the Acting Assistant Secretary of State for European Affairs (Beam) to the Director of Special Operations, Department of Defense (Erskine)** — Washington, May 8, 1957.  
   `frus1955-57v25/d249` · score 0.7040  
   > Dear General Erskine: I would like to return to the question of declaring the Hungarian Assistant Military Attaché in Washington persona non grata in retaliation for the expulsion from Hungary of Captain Thomas R. Gleason. On April 3, Captain Gleason and Colonel J.C. Todd, U.S. Military Attaché,…
8. **Mr. Gresham to Mr. Smythe.** — Department of State, Washington, March 16, 1894.  
   `frus1894/d331` · score 0.7027  
   > Sir: Your No. 47, diplomatic series, of the 3d instant, has been received. You therein report the expulsion from Haiti, by executive decree, of six Frenchmen, on the ground that their presence is judged to be dangerous to public safety; and you ask instructions in the event of similar decree…
9. **Memorandum of Conversation, by the Assistant Secretary of State (Long)** — [Washington,] April 2, 1941.  
   `frus1941v02/d795` · score 0.7001  
   > The Italian Ambassador Don Ascanio dei principi Colonna. called about six o’clock this evening at my request. At the direction of the Secretary I had obtained the approval of the President, by telephone, to notify the Ambassador his Naval Attaché is persona non grata. On April 1 the Assistant…
10. **Mr. Gresham to Mr. Terrell.** — Department of State, Department of State, October 29, 1894.  
   `frus1894/d758` · score 0.7000  
   > Your No. 320 Not printed. received. Your untenable demand that native teachers in American schools be not arrested without your consent may have been due to misapprehension of my telegram of 3d instant. While you will protest against capricious or unreasonable arrest of such persons as occasion…

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **The Acting Secretary of State to the Legation in Hungary** — Washington, November 24, 1947—6 p. m.  
   `frus1947v04/d273` · score 0.9196  
   > top secret urgent niact Washington, November 24, 1947—6 p. m. 1191. While we agree in principle as indicated Deptel 1188 Nov 22 Not printed. that you should assume responsibility for official activities subordinate members Legation (urtel 1871, Nov. 21) we cannot question right Hungarians declare…
2. **Editorial Note**  
   `frus1951v04p2/d271` · score 0.9066  
   > A Hungarian Government note of July 2 to the American Legation in Budapest asserted that it had been established in the trial of Archbishop Grösz that nine former or current American Legation officials had been involved in espionage and conspiracy against the Hungarian state, that Legation…
3. **355. Memorandum From the Assistant Secretary of State for Near Eastern, South Asian, and African Affairs (Rountree) to the Acting Secretary of State** — Washington, August 13, 1957.  
   `frus1955-57v13/d355` · score 0.9066  
   > SUBJECT Proposed Steps in Response to Syrian Government Actions Against the United States Discussion: The Syrian Government over the past several months has been taking an increasingly unfriendly attitude towards the United States and concurrently establishing closer ties with the Soviet Union. It…
4. **249. Letter From the Acting Assistant Secretary of State for European Affairs (Beam) to the Director of Special Operations, Department of Defense (Erskine)** — Washington, May 8, 1957.  
   `frus1955-57v25/d249` · score 0.9002  
   > Dear General Erskine: I would like to return to the question of declaring the Hungarian Assistant Military Attaché in Washington persona non grata in retaliation for the expulsion from Hungary of Captain Thomas R. Gleason. On April 3, Captain Gleason and Colonel J.C. Todd, U.S. Military Attaché,…
5. **Editorial Note**  
   `frus1950v04/d537` · score 0.8991  
   > In a note of March 10 to the Legation in Budapest, the Hungarian Foreign Ministry declared Military Attaché Col. James B. Kraft, Assistant Military Attaché Lt. Col. John T. Hoyne, and Assistant Air Attaché Maj. Donald E. Griffin personae non gratae and requested their recall. The note further…
6. **Memorandum by the Chief of the Division of Security (Nicholson) to the Director of the Office of Middle American Affairs (Mann)** — [Washington,] April 5, 1950.  
   `frus1950v02/d450` · score 0.8959  
   > Memorandum by the Chief of the Division of Security (Nicholson) This memorandum was also marked for the attention of W. Tapley Bennett, Jr., Officer in Charge of Central America and Panama Affairs. to the Director of the Office of Middle American Affairs (Mann) [Extract] confidential [Washington,]…
7. **The Legation in Hungary to the Hungarian Foreign Ministry** — [Budapest, March 4, 1950.]  
   `frus1950v04/d536` · score 0.8870  
   > The Legation of the United States of America presents its compliments to the Ministry for Foreign Affairs of Hungary and has the honor to refer to the Ministry’s note of February 23, 1950, In the note under reference here, the Hungarian Foreign Ministry drew attention to testimony during the…
8. **The Minister in Hungary (Chapin) to the Secretary of State** — Budapest, November 21, 1947—6 p. m.  
   `frus1947v04/d272` · score 0.8853  
   > top secret urgent niact Budapest, November 21, 1947—6 p. m. 1871. For Armour and Hickerson. As Department will have gathered from my telegrams it is an integral and important part of the present Communist campaign for extending complete domination of Hungary to vilify the US and to endeavor to make…
9. **The Chargé in Turkey (Tarler) to the Secretary of State** — Constantinople, April 23, 1917. [Received June 20.]  
   `frus1917Supp01v01/d833` · score 0.8846  
   > Sir: Through the courtesy of the Swedish Minister, I have the honor to transmit herewith copy and translation of a note from the Ottoman Minister of Foreign Affairs, dated April 20, 1917, informing the Embassy that in view of the state of war existing between the United States and the German…
10. **Memorandum by the Chief of the Division of Southeast European Affairs (Barbour) to the Director of the Office of European Affairs (Hickerson)** — [Washington,] March 28, 1949.  
   `frus1949v05/d286` · score 0.8837  
   > confidential [Washington,] March 28, 1949. Subject: Expulsion of American military officers from Hungary The action of the Hungarian Government on March 22 in expelling Lt. Cols. Peter J. Kopcsak and John P. Merrill Both were Assistant Military Attachés at the Legation in Budapest. from Hungary on…

*Route overlap: 2 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 0/10.*
*document variant:* frus1868p2/d443, frus1925v02/d319, frus1948v04/d244, frus1907p1/d461, frus1894/d331, frus1891/d241, frus1947v04/d273, frus1950v04/d536, frus1941v02/d795, frus1913/d1452
*bare variant:* frus1872p2v2/d25, frus1872p2v1/d147, frus1868p1/d361, frus1888p2/d381, frus1872p2v3/d26, frus1886/d65, frus1894/d313, frus1886/d71, frus1928v03/d626, frus1866p2/d160

---

## Q25. blood telegram
*known-item by nickname (Archer Blood's April 1971 Dacca dissent cable — the documents never call it that)*

### Lexical — `"blood" AND "telegram"`

1. **3. Telegram From the Department of State to All Diplomatic and Consular Posts** — Washington, September 22, 1983, 1904Z  
   `frus1981-88v41/d3` · score -9.5620  
   > Subject: Information on Acquired Immune Deficiency Syndrome (AIDS). 1. During the September 5–10 meeting in Rome involving State OES Assistant Secretary Malone and science officers from European embassies, considerable interest was shown in the new disease called acquired immune deficiency syndrome…
2. **7. Telegram From the Department of State to the Medical Collective** — Washington, June 7, 1985, 0045Z  
   `frus1981-88v41/d7` · score -9.5571  
   > Subject: Acquired Immune Deficiency. For Regional Medical Officers and Foreign Service nurses. 1. The ICD–9–CM does not have a number specifically set aside for this disorder. After consulting with the National Center for Health Statistics, M/MED designates the following numbers as the codes for…
3. **The Secretary of State to the Ambassador in China (Gauss)** — Washington, December 18, 1943.  
   `frus1943China/d700` · score -9.0841  
   > On December 17, 1943 the President approved an Act of Congress, Public 199, 57 Stat. 600. of which Section 1 repeals the Chinese exclusion laws, Section 2 establishes an immigration quota for Chinese (which has been computed at 105 annually) and provides a preference of seventy-five per centum for…
4. **The Ambassador in Germany (Dodd) to the Secretary of State** — Berlin, September 19, 1935. [Received September 27.]  
   `frus1935v02/d305` · score -8.8490  
   > Sir: With reference to the Embassy’s telegram No. 172 of September 16, 11 a.m., Not printed. I have the honor to transmit herewith two copies of the Reichsgesetzblatt, No. 100, Part I, of September-16, containing the three laws adopted by the Reichstag at Nuremberg on September 15 regarding…
5. **2. Telegram From the Department of State to the Embassy in Haiti** — Washington, September 21, 1982, 1345Z  
   `frus1981-88v41/d2` · score -8.8348  
   > Subject: AIDS Among Haitian Populations. Ref: Port Au Prince 5108. In telegram 5108 from Port Au Prince, September 15, the Embassy wrote, “Recent publicity given to occurrence Acquired Immune Deficiency Syndrome (AIDS) among Haitian population in US and at least two unexplained deaths of Haitians…
6. **No. 807 The Ambassador in Japan (Allison) to the Department of State** — Tokyo, September 24, 1954—8 p.m.  
   `frus1952-54v14p2/d807` · score -8.7659  
   > The Ambassador in Japan (Allison) to the Department of State confidential Tokyo, September 24, 1954—8 p.m. 712. Pass AEC. Reference Embassy’s 704. Dated Sept. 23; in it the Embassy reported that Dr. Masao Tsuzuki, the physician in charge of the Fukuryu Maru patients, had requested (with the…
7. **199. Memorandum From Secretary of State Muskie to President Carter** — Washington, September 13, 1980  
   `frus1977-80v19/d199` · score -8.2333  
   > Indian Reaction to Congressional Committee Action on Tarapur: The Government of India’s public reaction to the negative Tarapur votes was careful and restrained, and paralleled the positions taken with us privately. See footnote 2, Document 197. In telegram 19029 from New Delhi, September 11, Blood…
8. **The Minister in Lithuania (Norem) to the Secretary of State** — Kaunas, July 19, 1940—10 a.m. [Received 7:38 p.m.]  
   `frus1940v01/d402` · score -8.1750  
   > The election results have been announced as one of 99% variety and indicates a total lack of true democratic expression. Indications point to complete absorption into the Soviet Union. The new Seimas is scheduled to meet on Sunday, July 21. This body met at noon on July 21 and “decided to petition…
9. **19. Telegram From the Department of State to All African Diplomatic Posts** — Washington, August 5, 1986, 0233Z  
   `frus1981-88v41/d19` · score -8.1340  
   > Subject: Disinformation: AIDS Made in USA. Ref: A) Dakar 8253; B) Dakar 8510; C) Nairobi 27931; D) Moscow 12333. Telegram 8253 from Dakar, July 18. (Department of State, Central Foreign Policy File, D860553–0606) Telegram 8510 from Dakar, July 25. (Department of State, Central Foreign Policy File,…
10. **74. Telegram 1569 From the Consulate General in Dacca to the Department of State** — Dacca, August 17, 1970, 0624Z  
   `frus1969-76ve07/d74` · score -8.0940  
   > Ambassador Farland reported from Dacca on severe flooding in East Pakistan that had led Pakistani President Yahya to postpone national elections from October to December. Dacca, August 17, 1970, 0624Z For Secretary and Sisco from Ambassador 1. Severe floods are causing considerable damage and…

### Semantic (query prompt)

1. **Chargé Bliss to the Secretary of State.** — American Embassy, St. Petersburg, January 30, 1907.  
   `frus1907p2/d365` · score 0.7658  
   > Guidema, director Vassili Ostroff prison here, assassinated this morning about 11. Bliss.
2. **Mr. Rockhill to Mr. Williams.** — Department of State, Washington, February 28, 1896.  
   `frus1896/d762` · score 0.7657  
   > Cable as to health and welfare Sanguily. His friends apprehensive.
3. **The Secretary of State to Minister Ewing** — Department of State, Washington, June 11, 1917, 6 p.m.  
   `frus1917/d1469` · score 0.7575  
   > Your undated telegram received June 11, 11.35 a.m. Contents of your cable have been sent to American Red Cross which will render all aid possible. Lansing
4. **The Secretary of State to the Chargé in Japan (Caffery)** — Washington, October 22, 1924—5 p.m.  
   `frus1923v02/d454` · score 0.7485  
   > Your 247, September 29, noon. Red Cross has deposited with the Department $466,140.88 for which you may draw a draft the proceeds of which you may turn over to the appropriate Japanese authorities. Hughes
5. **The Minister in Costa Rica (Sack) to the Secretary of State** — San José, January 22, 1934—2 p.m. [Received 3:45 p.m.]  
   `frus1934v05/d239` · score 0.7464  
   > Costa Rican Government has invited Trueblood Edward G. Trueblood, Third Secretary of Legation. and myself to official dinner Tuesday night, January 23rd, in honor Salvadoran special mission. In light of telegram No’. 1 of January 12, 5 p.m., See footnote 6, p. 225. signed Phillips, information…
6. **The Secretary of State to the Consul at Jerusalem (Glazebrook)** — Washington, February 4, 1916.  
   `frus1916Supp/d1216` · score 0.7437  
   > Red Cross planning send about February 15 on United States collier about two tons medical supplies for Jewish hospitals Jerusalem. Telegraph whether agent Jaffa can arrange send small boat meet collier beyond mined area and land supplies. Lansing
7. **The Secretary of State to the Consul at Vladivostok (Caldwell)** — Washington, September 24, 1918, 7 p.m.  
   `frus1918Russiav01/d638` · score 0.7433  
   > Your 158, September 21, 3 p.m. You will please not concur in British proposal and will await Department’s circular telegram on the general subject being repeated to you from Tokyo. Lansing
8. **440. Telegram 7835 From the Embassy in Morocco to the Department of State** — Rabat, August 6, 1986, 1605Z  
   `frus1981-88v24/d440` · score 0.7423  
   > 440. Telegram 7835 From the Embassy in Morocco to the Department of State Source: Department of State, INR/IL Historical Files, Morocco, [text not declassified]. Secret; [handling restriction not declassified]. 2 pages not declassified. Rabat, August 6, 1986, 1605Z
9. **The Secretary of State to the Minister in Belgium (Whitlock)** — Department of State, Washington, August 19, 1914.  
   `frus1914Supp/d148` · score 0.7413  
   > Your August 17, 5 p.m. Department approves your course of action. Bryan
10. **The Governor of Porto Rico to the Secretary of State.** — San Juan de Porto Rico, January 22, 1907.  
   `frus1907p1/d431` · score 0.7412  
   > I have been asked to ascertain present conditions Jamaica sufferers. Whether Red Cross desire private subscriptions and form donations should take. Please cable reply. Beekman Winthrop.

### PRF — centroid of the lexical top-5, no encoder (5 seeds)

1. **3. Telegram From the Department of State to All Diplomatic and Consular Posts** — Washington, September 22, 1983, 1904Z  
   `frus1981-88v41/d3` · score 0.9240  
   > Subject: Information on Acquired Immune Deficiency Syndrome (AIDS). 1. During the September 5–10 meeting in Rome involving State OES Assistant Secretary Malone and science officers from European embassies, considerable interest was shown in the new disease called acquired immune deficiency syndrome…
2. **7. Telegram From the Department of State to the Medical Collective** — Washington, June 7, 1985, 0045Z  
   `frus1981-88v41/d7` · score 0.9234  
   > Subject: Acquired Immune Deficiency. For Regional Medical Officers and Foreign Service nurses. 1. The ICD–9–CM does not have a number specifically set aside for this disorder. After consulting with the National Center for Health Statistics, M/MED designates the following numbers as the codes for…
3. **8. Paper Prepared in the Department of State** — Washington, undated  
   `frus1981-88v41/d8` · score 0.8944  
   > DEPARTMENT OF STATE ACTION PLAN FOR ACQUIRED IMMUNE DEFICIENCY SYNDROME (AIDS) The Department of State, in May 1985, implemented a series of policies to deal with the AIDS problem. See Document 7. The major elements of the program are health education, a policy for management of infected…
4. **2. Telegram From the Department of State to the Embassy in Haiti** — Washington, September 21, 1982, 1345Z  
   `frus1981-88v41/d2` · score 0.8942  
   > Subject: AIDS Among Haitian Populations. Ref: Port Au Prince 5108. In telegram 5108 from Port Au Prince, September 15, the Embassy wrote, “Recent publicity given to occurrence Acquired Immune Deficiency Syndrome (AIDS) among Haitian population in US and at least two unexplained deaths of Haitians…
5. **18. Paper Prepared in the Department of State** — Washington, April 1986  
   `frus1981-88v41/d18` · score 0.8845  
   > Executive Summary The Problem Acquired Immune Deficiency Syndrome (AIDS) has rapidly emerged as a worldwide public health threat since its identification in 1981. Its recognition as a new disease was delayed by the absence of unique symptoms, and also by the long period between infection (by the…
6. **17. Letter From Acting Secretary of State Whitehead to the Director of the Office of Management and Budget (Miller)** — Washington, March 21, 1986  
   `frus1981-88v41/d17` · score 0.8823  
   > Dear Mr. Miller: I am writing with respect to the Department of Health and Human Services’ proposal to designate AIDS as a “dangerous, contagious disease”, excludable under Section 212(a)(6) of the Immigration and Naturalization Act (INA). For reasons stated below, the Department of State urges…
7. **27. Memorandum From the Domestic Policy Council to President Reagan** — Washington, May 27, 1987  
   `frus1981-88v41/d27` · score 0.8801  
   > SUBJECT AIDS Testing ISSUE —What additional steps should be taken by the Federal Government to prevent the spread of the HIV virus in America. BACKGROUND —Since 1981, when AIDS was first recognized as a fatal disease, there has been increasing discussion about the best way to stop the spread of the…
8. **16. Telegram From the Department of State to All Diplomatic and Consular Posts** — Washington, March 5, 1986, 1807Z  
   `frus1981-88v41/d16` · score 0.8748  
   > Subject: Proposed AIDS Screening for U.S. Visa Applicants: Update and Press Guidance. Ref: State 51793. In telegram 51793 to all diplomatic and consular posts, February 20, the Department requested that Embassies provide their views on the effects of the proposed HHS rule. (Department of State,…
9. **24. Telegram From the Department of State to Agency for International Development Mission Directors and Representatives** — Washington, April 4, 1987, 0920Z  
   `frus1981-88v41/d24` · score 0.8736  
   > Subject: A.I.D. Policy Guidance on AIDS. From Administrator M. Peter McPherson. I have recently approved the following policy guidance on AIDS. The guidance is designed to provide missions with guidelines on which to base decisions on how to respond to requests for A.I.D. support of AIDS -related…
10. **12. Minutes of AIDS Working Group Meeting** — Washington, December 9, 1985, 10–11:15 a.m.  
   `frus1981-88v41/d12` · score 0.8726  
   > ATTENDEES Ambassador Negroponte OES, Chair Dr. Ken Bart AID/ST/H Neil Boyer IO/T Marvin Brown CA Robert Brexler EAP/RA Bryce Grelach NEA/EX Paul Goff M/MED June Heil CA/VA Rich Kauzlarich IO Peter Knecht PA/OAP Bill Long OES/ENR Dave Lyon AF/RA Burnie Pixley M/MED William Robertson Georgia Rogers…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 5/10.*
*document variant:* frus1896/d762, frus1917/d1469, frus1907p2/d365, frus1923v02/d454, frus1914/d428, frus1981-88v24/d440, frus1916Supp/d1216, frus1891/d266, frus1914Supp/d148, frus1934v05/d239
*bare variant:* frus1907p2/d365, frus1917/d1469, frus1896/d758, frus1923v02/d454, frus1958-60v07p1/d112, frus1958-60v10p2/d223, frus1981-88v24/d440, frus1961-63v17/d1, frus1958-60v07p2/d74, frus1914Supp/d148
