# Retrieval evaluation — the owner-query sitting (W-17 session 3 / W-9 step 2)

Two routes over the same corpus, 25 owner-written queries, top 10 each.
**Lexical** is the app's own search (the rendered MATCH expression is shown — what
actually executed). **Semantic** is the shipped funnel (Hamming → int8 rerank) with the
query embedded by the SHA-pinned GGUF (`text-embedding-embeddinggemma-300m-qat`, `5a9e0645541b…`), primary
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
   `frus1894app2/d306` · score -7.2846  
   > Col. J. H. Blount , United States Commissioner, etc.: Dear Sir : I send you by bearer a very hastily prepared sketch of some features of Hawaiian History with our present condition in view. Time has not permitted of as careful an arrangement and comparison of facts and analysis of motives as I…

### Semantic (query prompt)

1. **The Secretary of State to the Attorney General ( Palmer )** — Washington , April 8, 1920 .  
   `frus1920v03/d523` · score 0.5641  
   > Sir : Referring to the informal request of Mr. Hoover, that this Department prepare a statement regarding diplomatic immunity as applied to the case of Mr. L. C. A. K. Martens, I have the honor to enclose, herewith for your information, a copy of a memorandum upon the subject, embodying the views…
2. **Mr. King to Mr. Seward** — Legation of the United States at Rome, January 14, 1865.  
   `frus1865p3/d149` · score 0.5630  
   > Sir: I have the honor to acknowledge the receipt of despatch No. 21, of December 16, from the State Department, in reply to mine of November 12, and conveying instructions as to the disposition to be made of sundry volumes in the archives of the United States legation in Rome. The intelligence of…
3. **28. Telegram 84081 From the Department of State to All African Diplomatic Posts** — Washington , April 12, 1975, 0205Z  
   `frus1969-76ve06/d28` · score 0.5628  
   > The Department reported on the April 8 meeting between Kissinger and African ambassadors in which an exchange of views on U.S.-African relations took place. Washington , April 12, 1975, 0205Z Subject: Secretary’s Meeting With the African Chiefs of Mission Inform Consuls. London for Haverkamp; Paris…
4. **Mr. Taylor to Mr. Seward .** — Legation of the United States , St. Petersburgh , January 21, 1863.  
   `frus1863p2/d168` · score 0.5620  
   > Sir: Your despatch No. 10, of December 23, was received on the 17th instant. The first portion of it, which relates to the impression conveyed by my despatch No. 21, of November 28, 1862, has, I trust, been already answered by my subsequent despatches. I consider that a part of my official duty is…
5. **81. Memorandum From the Director of the United States Information Agency ( Murrow ) to the Special Assistant to the President ( Schlesinger )** — Washington , May 21, 1962 .  
   `frus1917-72PubDipv06/d81` · score 0.5615  
   > Herbert Mitgang ’s suggestion about teams of Lincoln scholars looks good. In a May 8 note, written on The New York Times letterhead, Mitgang suggested to Schlesinger that the United States could “put our best foot forward historically” if a “team of Lincoln scholars, sponsored by one or two of the…
6. **Mr. Motley to Mr. Seward** — Legation of the United States, Vienna, April 9, 1865.  
   `frus1865p3/d9` · score 0.5610  
   > Sir: I have the honor to acknowledge the receipt of your despatch No. 129, of date 13th of March, containing very interesting reflections on the close connexion of the political condition of Europe with the development of our great revolution. You observe that the principal maritime powers of…
7. **Memorandum handed by the Chilean minister to the Acting Secretary of State .** — Legation of Chile , Washington , June 22, 1891 . (Received June 23.)  
   `frus1891/d304` · score 0.5577  
   > Mr. Secretary : I have asked this interview rather in the hope of preventing the raising of questions between our Governments than of making any formal representation. I feel very deeply, as does my Government, the recent prompt and friendly action of the United States in its successful effort to…
8. **Mr. Black ( Secretary of State ) to all the ministers of the United States .** — Department of State , Washington , February 28, 1861 .  
   `frus1861/d2` · score 0.5575  
   > CIRCULAR. Sir : You are, of course, aware that the election of last November resulted in the choice of Mr. Abraham Lincoln; that he was the candidate of the republican or anti-slavery party; that the preceding discussion had been confined almost entirely to topics connected, directly or indirectly,…
9. **219. Memorandum of Conversation** — New York , September 24, 1966, 1:15 p.m.  
   `frus1964-68v24/d219` · score 0.5566  
   > SecDel/MC/34 New York , September 24, 1966, 1:15 p.m. SECRETARY’S DELEGATION TO THE TWENTY FIRST-SESSION OF THE UNITED NATIONS GENERAL ASSEMBLY New York, September–October 1966 SUBJECT The United States and Africa—Selected Remarks Made at Luncheon for African Foreign Ministers PARTICIPANTS The…
10. **Mr. Pike to Mr. Seward .** — United States Legation , The Hague , December 31, 1862.  
   `frus1863p2/d202` · score 0.5563  
   > Sir: I have to acknowledge the receipt of your despatch of December 6, No. 70. The President’s message, the American diplomatic correspondence of 1862, and Mr. Bright’s Manchester speech, all appearing at the same time, have given a great fillip to the discussions of the American question. The…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 4/10, bare: 2/10.*
*document variant:* frus1917-72PubDipv06/d81, frus1914/d1, frus1955-57v18/d314, frus1863p2/d202, frus1952-54v03/d807, frus1925v01/d146, frus1862/d105, frus1969-76v28/d48, frus1861/d2, frus1865p3/d9
*bare variant:* frus1942v02/d177, frus1925v01/d146, frus1958-60v06/d455, frus1917-72PubDipv06/d131, frus1969-76ve06/d28, frus1952-54v08/d5, frus1944v06/d25, frus1861/d2, frus1914-20v01/d490, frus1893/d357

---

## Q2. How did immigration affect U.S. diplomacy with China in the 1880s?

### Lexical — `"how" AND "did" AND "immigration" AND "affect" AND "u.s." AND "diplomacy" AND "with" AND "china" AND "in" AND "the" AND "1880s?"`

1. **No. 23. Statement of Charles T. Gulick.**  
   `frus1894app2/d306` · score -4.2130  
   > Col. J. H. Blount , United States Commissioner, etc.: Dear Sir : I send you by bearer a very hastily prepared sketch of some features of Hawaiian History with our present condition in view. Time has not permitted of as careful an arrangement and comparison of facts and analysis of motives as I…

### Semantic (query prompt)

1. **Mr. Chang Yen Hoon to Mr. Bayard .** — Chinese Legation , Washington , January 26, 1889 . (Received January 26.)  
   `frus1889/d87` · score 0.6789  
   > Sir : I have the honor to inform you that I have carefully examined the act of Congress approved October 1, 1888, in relation to the prohibition of the coming of Chinese laborers into the United States, copies of which you kindly sent me with your note of October 18 last, and I beg respectfully to…
2. **Mr. Wu to Mr. Hay .** — Chinese Legation , Washington , December 10, 1901 .  
   `frus1901/d85` · score 0.6679  
   > Sir : In view of the fact that the law of the Congress of the United States which went into force May 6, 1882, based upon the treaty of 1880 between China and the United States, regulating Chinese immigration, and which was reenacted May 5, 1892, for ten years, is about to expire by limitation, and…
3. **No. 126. The commission to Mr. Evarts .** — United States Commission , Peking , October 11, 1880 .  
   `frus1881/d126` · score 0.6597  
   > Sir : Recurring to our dispatch No. 4, of the 27th ultimo, in which we reported our arrival here, and the appointment by the Government of China of two commissioners plenipotentiary, we have now the honor to inform you that upon the 1st instant we met the two commissioners at the foreign office by…
4. **No. 240. Mr. Bayard to Mr. Chang Yen Soon .** — Department of State , Washington , January 12, 1887 .  
   `frus1888p1/d240` · score 0.6404  
   > Sir : I have had the honor informally to discuss with you, in recent personal interviews in connection with questions growing out of mob violence upon Chinese in certain of the Northwestern Territories of this country, the expediency of concluding a treaty between our respective Governments for the…
5. **No. 127. The commission to Mr. Evarts .** — United States Commission , Peking , October 23, 1880 .  
   `frus1881/d127` · score 0.6295  
   > Sir : Our dispatch No. 6 covered the memorandum which we submitted at our first interview with the Chinese commissioners, and the reply which they transmitted a few days after. Upon the receipt of that reply we asked for and obtained an interview on the 13th instant, at which we took up their…
6. **Mr. Tsui to Mr. Foster .** — Chinese Legation , Washington, D. C. , Nov. 11, 1892 . (Received November 12.)  
   `frus1892/d114` · score 0.6197  
   > Sir : I have the honor to transmit herewith for your consideration and for the consideration of his excellency, the President of the United States, a communication of the foreign office at Peking, and addressed to Hon. Charles Denby, United States minister, in reply to a note from him dated July 4,…
7. **No. 239. Mr. Rives to Mr. Denby .** — Department of State , Washington , October 10, 1888 .  
   `frus1888p1/d239` · score 0.6166  
   > Sir : I transmit herewith for your information copies of the recently approved Chinese exclusion act and of the President’s message upon the subject; also of Senate Ex. Doc. O, Fiftieth Congress, For Senate Ex. Doc. O, Fiftieth Congress (convention for restricting Chinese immigration), see Document…
8. **No. 214. Mr. Bayard to Mr. Denby .** — Department of State , Washington , June 7, 1888 .  
   `frus1888p1/d214` · score 0.6146  
   > Sir : The treaty concluded in this city on March 12 last, between the Chinese minister and myself, was, as you have been heretofore informed, duly submitted to the Senate for its advice and consent, and a full copy thereof, together with the message of the President transmitting the same, have been…
9. **No. 129. The commission to Mr. Evarts .** — United States Commission , Peking , November 3, 1880 .  
   `frus1881/d129` · score 0.6145  
   > Sir : Our dispatch. No. 8, of October 23, 1880, brought the history of our negotiation down to the inverview of that day with the Chinese commissioners, and briefly summarized its result. We now have the honor to inclose a full précis of the conversation on that occasion. When that précis was…
10. **Mr. Wharton to Mr. Tsui .** — Department of State , Washington , December 10, 1892 .  
   `frus1892/d115` · score 0.6131  
   > Sir : I have the honor to acknowledge the reception of your two notes of the respective dates of November 7 and November 11, 1892, concerning the recent legislation of the Congress of the United States “in respect to Chinese subjects” in this country. In the former of these two notes you refer to…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 7/10.*
*document variant:* frus1889/d87, frus1901/d85, frus1881/d126, frus1888p1/d240, frus1876/d44, frus1892/d114, frus1881/d127, frus1890/d160, frus1892/d100, frus1888p1/d260
*bare variant:* frus1889/d87, frus1901/d85, frus1881/d126, frus1888p1/d240, frus1881/d127, frus1892/d114, frus1892/d100, frus1881/d129, frus1876/d44, frus1890/d160

---

## Q3. How did U.S. diplomats think about Cuban independence before 1898?

### Lexical — `"how" AND "did" AND "u.s." AND "diplomats" AND "think" AND "about" AND "cuban" AND "independence" AND "before"`

1. **18. Policy Paper Prepared in the Department of State** — Washington , undated  
   `frus1977-80v23/d18` · score -20.7747  
   > How To Proceed Next With Cuba We have completed the steps authorized by Presidential Directive/NSC–6, which called for a review once those steps had been taken. See Document 9 . PRC review of the options available on Cuba in the months ahead is also timely now in light of the opening of Interests…
2. **221. Memorandum of Conversation** — New York , October 4, 1982, 3–7:30 p.m.  
   `frus1981-88v03/d221` · score -18.8839  
   > SUBJECT Meeting Between Secretary Shultz and Soviet Foreign Minister Gromyko PARTICIPANTS U.S. Secretary of State George P. Shultz Undersecretary for Political Affairs Lawrence S. Eagleburger Ambassador to the USSR Arthur A. Hartman Assistant Secretary of State for European Affairs Richart Burt…
3. **474. Memorandum of Discussion at the 436th Meeting of the National Security Council, Washington, March 10, 1960** — Washington , March 10, 1960  
   `frus1958-60v06/d474` · score -17.6200  
   > Mr. Dulles then summarized the situation in Cuba. He said that the U.S. Embassy Country Team had reached the conclusion that there was no hope that the U.S. would ever be able to establish satisfactory relations with a Cuban Government dominated by Castro and his associates. The Cuban charges in…
4. **68. Memorandum of Conversation** — Washington , August 5, 1977, 10:30 a.m.–noon  
   `frus1977-80v16/d68` · score -17.0628  
   > SUBJECT Summary of the President’s Meeting II with President Julius Nyerere of Tanzania PARTICIPANTS United States The President The Vice President Dr. Zbigniew Brzezinski Acting Secretary of State Warren Christopher Assistant Secretary of State for African Affairs Richard Moose Ambassador James…
5. **382. Memorandum of Conversation** — Washington , February 12, 1976, 4:15–4:45 p.m.  
   `frus1969-76ve11p1/d382` · score -16.9746  
   > Summary: Kissinger and Wills discussed Guyana’s votes in the United Nations, Angola, and bilateral relations. Kissinger told Wills that the United States had no interest in confrontation with Guyana, and Wills assured Kissinger that Guyana would not become a Soviet or Cuban base. Source: National…
6. **152. Memorandum of Conversation** — Washington , August 18, 1976, 5 p.m.  
   `frus1969-76v18/d152` · score -16.7301  
   > PARTICIPANTS Ambassador Huang Chen , Chief, PRC Liaison Office Mr. Chien Ta-yung , Counselor, PRC Liaison Office Ms. Shen Jo-yun , Interpreter, PRC Liaison Office Secretary Kissinger Arthur W. Hummel , Jr., Assistant Secretary, EA Winston Lord , Director, S/P William H. Gleysteen , National…
7. **342. Memorandum of a Conversation Between the Ambassador in Cuba ( Bonsal ) and Minister of State Roa , Havana, July 23, 1959** — Havana , July 23, 1959  
   `frus1958-60v06/d342` · score -16.7201  
   > I called on Dr. Roa by arrangement. In the course of the preliminary exchange of courtesies, he was good enough to say that he had heard on all sides favorable expressions about my mission here, and he gave me a friendly personal message from Fidel Castro , with whom he had just been talking. We…
8. **187. Memorandum of Conversation** — New York , June 19, 1982, 9:30 a.m.–1:40 p.m.  
   `frus1981-88v03/d187` · score -16.4009  
   > SUBJECT Private Meeting Between Secretary Haig and Minister Gromyko PARTICIPANTS US Secretary of State Alexander M. Haig Cyril Muromcew, Interpreter USSR Foreign Minister Andrey A. Gromyko Victor Sukhodrev, MFA , USSR Foreign Minister Gromyko suggested to Secretary Haig that they continue where…
9. **No. 713. Admiral Polo de Bernabé to Mr. Fish .** — Legation of Spain , Washington , December 10, 1873 ,  
   `frus1874/d715` · score -16.3256  
   > As a result of the protocol signed at Washington on the 29th of November last, relative to the case of the Virginius, the undersigned, envoy extraordinary and minister plenipotentiary of Spain, has the honor to transmit herewith to the Secretary of State of the United States various authenticated…
10. **26. Memorandum of a Conversation, Department of State, Washington, June 30, 1958** — Washington , June 30, 1958  
   `frus1958-60v13/d26` · score -16.2958  
   > SUBJECT U.S.-Israel Relations and the Situation in the Near East PARTICIPANTS Mr. Abba Eban , Ambassador of Israel Mr. Ya’acov Herzog , Minister, Embassy of Israel The Secretary NE — Stuart W. Rockwell NE — Donald C. Bergus Mr. Eban reported that he would leave Washington in a week’s time for two…

### Semantic (query prompt)

1. **No. 550. Mr. Fish to Mr. Cushing .** — Department of State , Washington , February 6, 1874 .  
   `frus1874/d552` · score 0.6757  
   > Sir : Whatever general instructions you may need at the present time for your guidance in representing this Government at Madrid have reference entirely to the actual state of the island of Cuba and its relation to the United States as well as to Spain. It is now more than five years since an…
2. **[Untitled]**  
   `frus1902/d273` · score 0.6647  
   > To the Congress of the United States: I commend to the Congress timely consideration of measures for maintaining diplomatic and consular representatives in Cuba and for carrying out the provisions of the act making appropriation for the support of the Army for the fiscal year ending June 30, 1902,…
3. **279. Telegram From the Embassy in Cuba to the Department of State** — Havana , April 15, 1959—noon .  
   `frus1958-60v06/d279` · score 0.6588  
   > Castro ’s trip to United States has assumed increasing importance in minds Cubans during past several days and now generally regarded as one of crucial events of his regime. More revolutionary-minded members of group around Castro look upon trip as historical precedent, considering it first time a…
4. **150. Memorandum of Conversation** — Washington , September 18, 1962, 11:49 a.m.  
   `frus1961-63v12/d150` · score 0.6588  
   > SUBJECT Mexican policy towards Cuba PARTICIPANTS The Secretary Antonio Carrillo Flores —Ambassador of Mexico Mr. Martin —Assistant Secretary for Inter-American Affairs Mr. Sayre —Officer in Charge, Mexican Affairs The Ambassador called at the Secretary’s request. The Secretary inquired about the…
5. **Mr. Woodford to the President .** — Legation of the United States , Madrid , March 9, 1898 .  
   `frus1898/d544` · score 0.6564  
   > Dear Mr. President : Knowing how pressed you are for time, I fear you may find my letters somewhat prolix, but I know that you must wish all the light I can give you. * * * On Monday evening, March 7, Señor ________, a well-known Spanish merchant, gave us a family dinner, at which were present his…
6. **Mr. Woodford to Mr. Sherman .** — Legation of the United States , Madrid , March 25, 1898 .  
   `frus1898/d557` · score 0.6520  
   > Sir : Since the receipt of the Spanish note dated February 1, 1898, I have waited for suitable opportunity to have full and frank discussion with the Spanish minister for foreign affairs concerning the real condition of affairs in Cuba and the duty of the United States in regard thereto. After an…
7. **The American Minister to the Secretary of State .** — American Legation , Habana , February 12, 1912 .  
   `frus1912/d405` · score 0.6499  
   > Sir : Referring to previous correspondence [etc.] I have the honor to enclose herewith copy and translation of a long personal note on the subject, which I received yesterday from Sr. Sanguily. I also enclose copy of my reply of today’s date. * * * In case the Department desires me to comply with…
8. **Memorandum of Conference by the Secretary of State With the Press on October 2, 1930** — October 2, 1930  
   `frus1930v02/d747` · score 0.6492  
   > A correspondent said that press dispatches from Havana report that President Machado contemplates asking Congress to suspend constitutional guarantees until after the forthcoming elections. The correspondent enquired whether this Government has any attitude or policy on that. The Secretary said…
9. **362. Memorandum of a Conversation, Department of State, Washington, September 18, 1959** — Washington , September 18, 1959  
   `frus1958-60v06/d362` · score 0.6479  
   > SUBJECT Our Future Relations with Cuba PARTICIPANTS R.R. Rubottom, Jr. , Assistant Secretary Ambassador Bonsal CMA — William A. Wieland ARA — J.C. Hill CMA — R.A. Stevenson , R.B. Owen The meeting was called to decide what tactics we should employ in our future relations with Cuba. The following…
10. **527. Memorandum of a Conference, Department of State, Washington, June 7, 1960** — Washington , June 7, 1960  
   `frus1958-60v06/d527` · score 0.6477  
   > SUBJECT Cuban Situation: Meeting with Representatives of the National Foreign Trade Council PARTICIPANTS Representatives of the National Foreign Trade Council: Mr. Harry Pike , H.H. Pike & Co., Chairman of NFTC Cuba Committee Mr. John Akin , Secretary of the NFTC Mr. M.L. Haider , Director of…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 8/10.*
*document variant:* frus1958-60v06/d623, frus1874/d552, frus1902/d273, frus1930v02/d747, frus1958-60v06/d628, frus1958-60v06/d362, frus1958-60v06/d279, frus1961-63v12/d150, frus1918/d348, frus1898/d637
*bare variant:* frus1930v02/d747, frus1912/d405, frus1961-63v12/d150, frus1958-60v06/d279, frus1902/d273, frus1898/d713, frus1898/d627, frus1898/d544, frus1874/d552, frus1898/d557

---

## Q4. Which document related to the Anglo-Venezuelan boundary dispute expanded the Monroe Doctrine?
*known-item*

### Lexical — `"which" AND "document" AND "related" AND "to" AND "the" AND "anglo-venezuelan" AND "boundary" AND "dispute" AND "expanded" AND "the" AND "monroe" AND "doctrine?"`

*(no results)*

### Semantic (query prompt)

1. **Message of the President .**  
   `frus1895p1/d526` · score 0.6567  
   > To the Congress: In my annual message addressed to the Congress on the third instant I called attention to the pending boundary controversy between Great Britain and the Republic of Venezuela and recited the substance of a representation made by this Government to Her Britannic Majesty’s Government…
2. **Mr. Olney to Mr. Bayard .** — Department of State , Washington , July 20, 1895 .  
   `frus1895p1/d527` · score 0.6371  
   > His Excellency Thomas F. Bayard , Etc., etc., etc., London. Sir : I am directed by the President to communicate to you his views upon a subject to which he has given much anxious thought and respecting which he has not reached a conclusion without a lively sense of its great importance as well as…
3. **Mr. Andrade to Mr. Gresham .** — Legation of Venezuela , Washington , March 31, 1894 .  
   `frus1894/d820` · score 0.6284  
   > Sir : In our interview of the 8th of last January, the subject of which was the endless and vexed boundary controversy between Venezuela and Great Britain, your excellency expressed his wish that I should explain to him by writing certain especial points connected with it. This I have endeavored to…
4. **Lord Salisbury to Sir Julian Pauncefote .** — Foreign Office , November 26, 1895 .  
   `frus1895p1/d529` · score 0.6275  
   > Sir , On the 7th August I transmitted to Lord Gough a copy of the despatch from Mr. Olney which Mr. Bayard had left with me that day, and of which he had read portions to me. I informed him at the time that it could not be answered until it had been carefully considered by the Law Officers of the…
5. **Lord Salisbury to Sir Julian Pauncefote .** — Foreign Office , November 26, 1895 .  
   `frus1895p1/d530` · score 0.6235  
   > Sir , In my preceding despatch of to-day’s date I have replied only to the latter portion of Mr. Olney’s despatch of the 20th July last, which treats of the application of the Monroe doctrine to the question of the boundary dispute between Venezuela and the colony of British Guiana. But it seems…
6. **Mr. Gresham to Mr. Bayard .** — Department of State , Washington , July 13, 1894 .  
   `frus1894/d243` · score 0.6106  
   > Sir : During your incumbency of the office of Secretary of State you became acquainted with a long pending controversy between Great Britain and Venezuela concerning the boundary between that Republic and British Guiana. The recourse to arbitration, first proposed in 1881, having been supported by…
7. **430. Information Memorandum From the Presidentʼs Special Assistant ( Rostow ) to President Johnson** — Washington , January 25, 1968 .  
   `frus1964-68v32/d430` · score 0.6088  
   > SUBJECT Guyanaʼs Border Dispute with Venezuela During Prime Minister Burnham ʼs call he asked for our help in persuading Venezuela to be less “bellicose” about the border dispute. You asked for a memorandum. See Document 426 . The dispute, involving some 5/8 of Guyana (see attached map), Attached…
8. **The Secretary of State to various Senators .** — Department of State , Washington , January 22, 1912 .  
   `frus1912/d1493` · score 0.6040  
   > My Dear Senator : I have ventured to send you copy of an address I recently made on “The Monroe Doctrine and some incidental obligations in the zone of the Caribbean.” I do so in the hope of increasing your interest in the Convention between the United States and Honduras, and even more especially…
9. **524. Memorandum From the Director of the Office of Colombian-Venezuelan Affairs ( Margolies ) to the Assistant Secretary of State for Inter-American Affairs ( Mann )** — Washington , January 13, 1965 .  
   `frus1964-68v31/d524` · score 0.6012  
   > SUBJECT Venezuela Asks U.S. Intercession in Settling Guiana Boundary Dispute The Problem On December 15, 1964, the Venezuelan Foreign Minister called on Mr. Ball (then Acting Secretary), and requested that the U.S. Government use its good offices to help bring the current negotiations between…
10. **The Ambassador in Mexico ( Daniels ) to the Secretary of State** — Mexico , October 6, 1933 . [Received October 9.]  
   `frus1933v04/d25` · score 0.5995  
   > Sir : I have the honor to enclose a translation of a memorandum which was given to me this afternoon by Doctor Puig, comprising his ideas on the Monroe Doctrine and its amplification at the Montevideo Conference. I am unable to state at this time whether or not this memorandum has the approval of…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 7/10.*
*document variant:* frus1895p1/d526, frus1895p1/d527, frus1895p1/d529, frus1933v04/d25, frus1912/d1493, frus1964-68v32/d430, frus1914-20v02/d281, frus1894/d820, frus1895p1/d530, frus1929v01/d522
*bare variant:* frus1895p1/d526, frus1895p1/d527, frus1894/d820, frus1895p1/d530, frus1894/d243, frus1964-68v32/d430, frus1894/d822, frus1896/d182, frus1895p2/d750, frus1895p1/d529

---

## Q5. Mexican Revolution

### Lexical — `"mexican" AND "revolution"`

1. **The Acting Secretary for Foreign Affairs of the Vásquez Gómez-Provisional Government to the Secretary of State .** — Palomas, Chihuahua , February 25, 1913 .  
   `frus1913/d876` · score -13.7785  
   > Received March 6; communicated to the Ambassador March 17; filed March 21. [Translation.] Palomas, Chihuahua , February 25, 1913 . To the Secretary of State of the United States of North America : The Provisional President of the Revolution of the United Mexican States has ordered me to inform your…
2. **The American Ambassador to the Secretary of State .** — American Embassy , Mexico , July 7, 1913.  
   `frus1913/d1231` · score -13.3864  
   > Sir : I have the honor to acknowledge the Department’s No. 1337, of June 21, 1913, in which I am directed to reopen with the British Minister and the Mexican Foreign Office the question of claims growing out of a successful revolution and those growing out of an unsuccessful one. While the…
3. **The Secretary of State to the Chargé in Mexico ( Summerlin )** — Washington , October 9, 1919 .  
   `frus1920v03/d281` · score -13.0297  
   > Sir : The Department acknowledges the receipt of your despatch No. 2406 dated September 17, 1919, Not printed. with which you forwarded the official text and translation of the Presidential Decree of August 30, 1919, See Foreign Relations , 1919, vol. ii , p. 640 . modifying the Presidential Decree…
4. **571. Memorandum of a Conversation, Department of State, Washington, August 3, 1960** — Washington , August 3, 1960  
   `frus1958-60v06/d571` · score -13.0112  
   > SUBJECT Proposed Offer of Good Offices to United States and Cuba PARTICIPANTS The Secretary of State Mexican Ambassador Antonio Carrillo Flores Assistant Secretary R. R. Rubottom, Jr. Dr. José Gallastegui , Private Secretary to the Mexican Foreign Minister Melville E. Osborne— CMA Mr. Rubottom…
5. **The Minister in Nicaragua ( Eberhardt ) to the Secretary of State** — Managua , December 31, 1926—10 p.m. [Received 10:40 p.m.]  
   `frus1927v03/d252` · score -12.8806  
   > A conference was held this morning in the Legation at the request of the Diaz Government. It was attended by the Minister for Foreign Affairs, the Minister of Finance, High Commissioner, Deputy Collector General of Customs and Manager of the National Bank. The Government representatives stated the…
6. **The Chargé in Nicaragua ( Dennis ) to the Secretary of State** — U. S. S. “ Denver ,” October 19, 1926—4 p.m. [Received October 21—11:30 a.m.]  
   `frus1926v02/d498` · score -12.8294  
   > The conference is now in a deadlock over formula for “reestablishment of peace on basis of constitutionality and the treaty of Washington.” Conference on Central American Affairs , p. 287. A Conservative executive and government with participation for the Liberals is insisted upon by the…
7. **The Brazilian Minister to Mexico to the Secretary of State .** — Mexico City , March 9, 1915—11 p.m.  
   `frus1915/d839` · score -12.7930  
   > I have been requested by a committee of American citizens to transmit to you the following: The American residents of Mexico City and vicinity in general meeting at the American Club in this city have considered carefully your cablegram to the Brazilian Minister Of March 5, 5 p.m. which reads,…
8. **The American Ambassador to the Secretary of State .** — American Embassy , Mexico , January 6, 1912 .  
   `frus1912/d905` · score -12.7889  
   > Sir : I have the honor to transmit herewith for such action as the Department deems necessary to take, a copy of an informal note, with its inclosures, from the Mexican Minister for Foreign Affairs, relative to certain seditious propaganda being carried on by Dr. Emilio Vázquez Gómez from his…
9. **The Acting Secretary of State to the Ambassador in Mexico ( Fletcher )** — Washington , March 8, 1918 .  
   `frus1918/d695` · score -12.7478  
   > Sir : The Department acknowledges the receipt of your No. 834 [634] of December 5, 1917, No. 634 not printed; for enclosure see ante , p. 793 . with which you forwarded the text and translation of the presidential decree providing for the appointment of a commission to pass upon claims for damages…
10. **The Minister in Nicaragua ( Eberhardt ) to the Secretary of State** — Managua , December 31, 1926—3 p.m. [Received 10:20 p.m.]  
   `frus1926v02/d528` · score -12.6474  
   > Department’s 148, December 30, 4 p.m. President Diaz telegraphed a reply yesterday to President Jimenez’s offer of mediation stating that he had received similar [offer] from the Guatemalan Government which he had answered with a proposal to send a diplomat to Guatemala. While these conversations…

### Semantic (query prompt)

1. **The Confidential Agent of the Constitutionalist Government of Mexico to the Secretary of State .** — Washington , October 7, 1915 .  
   `frus1915/d991` · score 0.6013  
   > Mr. Secretary : In consideration of the agreement between your excellency and the other American representatives during the last conference held in New York, on the 18th ultimo, I have the honor to transmit herewith for your excellency’s information a brief résumé of the Mexican Revolution,…
2. **Mr. Arredondo to the Secretary of State .** — Confidential Agency of the Constitutionalist Government of Mexico , Washington , December 16, 1914 .  
   `frus1914/d976` · score 0.5967  
   > Mr. Secretary : I have the honor to enclose herewith copy in translation of a decree issued on the 12th instant by Mr. Venustiano (Carranza as First Chief of the Constitutionalist Army in charge of the Executive Power of Mexico, with headquarters at Vera Cruz. In sending you this document I am…
3. **No. 385. Mr. de Zamacona to Mr. Evarts .** — Legation of Mexico in the United States , Washington , July 31, 1878 . (Received August 3.)  
   `frus1878/d390` · score 0.5928  
   > Mr. Secretary : The allusion contained in one of the notes with which I have recently been honored by the Department of State, to the difficulties encountered in Texas in convicting of an infraction of the neutrality laws those persons who have been conspiring for some months past against the peace…
4. **No. 213. Mr. Foster to Mr. Fish .** — Legation of the United States , Mexico , April 22, 1876 . (Received May 8.)  
   `frus1876/d223` · score 0.5899  
   > Sir : The revolution has steadily increased since the date of my last dispatch on current events, and is to-day stronger than at any time since its commencement. The principle proclaimed by the plans of the various chiefs is “no re-election to the presidency,” and they allege as the reason for the…
5. **Memorandum by the Under Secretary of State ( Clark )** — [ Washington ,] March 5, 1929 .  
   `frus1929v03/d381` · score 0.5871  
   > The Present Situation A. In July last, Obregon, who had been elected President of Mexico to succeed Calles was assassinated. He would have taken office December 1, 1928. B. His followers were keenly disappointed, many doubtless because of promised offices. Among the more important followers, was…
6. **Vice Consul Blocker to the Secretary of State** — Eagle Pass , December 7, 1916 .  
   `frus1916/d815` · score 0.5865  
   > Sir : * * * Enclosed is an original [manifesto] to the people of Mexico, signed by General Villa, at San Andres, Chihuahua, setting forth the platform of Villa and his colleagues. It seems evident that General Murguia, the Government commander, successfully reached Chihuahua and wrested it from the…
7. **The American Ambassador to the Secretary of State .** — American Embassy , Mexico , July 11, 1911 .  
   `frus1911/d764` · score 0.5839  
   > My Dear Mr. Knox : The fears expressed in my confidential dispatches of May 23 Not printed. and May 31 Not printed. that the situation which had been created by the success of the revolutionary movement of Mr. Madero might lead to a permanent disrespect for constituted authority and to a…
8. **The American Ambassador to the Secretary of State .** — American Embassy , Mexico , November 26, 1910 .  
   `frus1911/d479` · score 0.5822  
   > Sir : As supplementary to telegrams of November 18 [and others subsequent], I have the honor to call the attention of the Department to the following points in connection with the recent revolutionary outbreaks in Mexico: First. That the movement, while apparently unorganized and without…
9. **The American Ambassador to the Secretary of State .** — American Embassy , Mexico , February 4, 1913 .  
   `frus1913/d785` · score 0.5805  
   > My Dear Mr. Knox : Upon resuming my duties at this post after an absence of two months Mr. Wilson resumed charge of the Embassy on January 5. I find practically the same conditions existing that prevailed prior to my departure. The area of the armed revolution against the Government appears to have…
10. **The Acting Secretary for Foreign Affairs of the Vásquez Gómez-Provisional Government to the Secretary of State .** — Palomas, Chihuahua , February 25, 1913 .  
   `frus1913/d876` · score 0.5800  
   > Received March 6; communicated to the Ambassador March 17; filed March 21. [Translation.] Palomas, Chihuahua , February 25, 1913 . To the Secretary of State of the United States of North America : The Provisional President of the Revolution of the United Mexican States has ordered me to inform your…

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 5/10, bare: 6/10.*
*document variant:* frus1916/d815, frus1915/d991, frus1914/d976, frus1865p3/d454, frus1868p2/d332, frus1868p2/d296, frus1878/d390, frus1867p2/d419, frus1911/d479, frus1866p3/d99
*bare variant:* frus1915/d991, frus1914/d976, frus1929v03/d430, frus1915/d905, frus1917/d1147, frus1929v03/d381, frus1876/d223, frus1911/d479, frus1912/d905, frus1878/d390

---

## Q6. When did U.S. diplomats realize that Hitler was a serious danger to the United States?

### Lexical — `"when" AND "did" AND "u.s." AND "diplomats" AND "realize" AND "that" AND "hitler" AND "was" AND "a" AND "serious" AND "danger" AND "to" AND "the" AND "united" AND "states?"`

1. **263. Record of the Meeting Between Secretary of State Dulles and President Tito on the Island of Vanga, November 6, 1955, 3–5:40 p.m.** — Island of Vanga , November 6, 1955, 3–5:40 p.m.  
   `frus1955-57v26/d263` · score -13.7550  
   > The Secretary flew from Geneva, where he was attending the Four-Power Conference of Foreign Ministers, to Vienna on November 4. He met informally with Austrian leaders on November 5 (see Toden 16, infra ) and then flew to Brioni for talks with Tito on November 6. According to Dulles ’ Appointment…
2. **208. Paper Prepared in the National Security Council** — Washington , undated  
   `frus1981-88v01/d208` · score -13.6773  
   > THE ADMINISTRATION’S DEBATES WITH ITS DOMESTIC CRITICS The terms of the public debate on foreign policy is too often being defined by the President’s domestic critics and not by the President and the Administration. Yet the first rule in these matters is: he who defines the terms of the debate is…
3. **No. 529 Memorandum of Discussion at the 186th Meeting of the National Security Council, Friday, February 26, 1954** — February 26, 1954  
   `frus1952-54v07p1/d529` · score -12.4781  
   > Memorandum of Discussion at the 186th Meeting of the National Security Council, Friday, February 26, 1954 top secret eyes only February 26, 1954 Present at this meeting were the President of the United States, presiding; the Vice President of the United States; the Secretary of State; the Acting…
4. **No. 33 The Chairman of the President’s War Relief Control Board ( Davies ) to the President** — Washington , June 12, 1945 .  
   `frus1945Berlinv01/d33` · score -11.6641  
   > The Chairman of the President’s War Relief Control Board This was Davies ’ only official position in the United States Government at this time, although he acted as an adviser to the President before and during the Berlin Conference and as a special representative of the President on the mission to…
5. **United States Delegation Minutes** — Bermuda , December 7, 1953 .  
   `frus1952-54v05p2/d357` · score -11.5988  
   > The U.S. Delegation transmitted to Washington a summary of this meeting in Secto 24 from Bermuda, Dec. 7. This telegram was repeated to London, Paris, Bonn, and Moscow. secret Plenary Minutes 5 Bermuda , December 7, 1953 . Subjects: Indochina Security Assurances President Eisenhower opened the…
6. **58. Memorandum of Conversation** — Beijing , November 12, 1973, 5:40–8:25 p.m.  
   `frus1969-76v18/d58` · score -10.8350  
   > PARTICIPANTS Chairman Mao Tse-tung Prime Minister Chou En-lai Foreign Minister Chi Peng-fei Assistant Minister of Foreign Affairs Wang Hai-jung Tang Wang-shen, Interpreter Shen Jo-yen, Interpreter Henry A. Kissinger , Secretary of State Ambassador David Bruce , Chief U.S. Liaison Office Winston…
7. **219. Address by Secretary of Defense Weinberger** — Washington , November 28, 1984  
   `frus1981-88v01/d219` · score -10.7969  
   > “The Uses of Military Power” Thank you for inviting me to be here today with the members of the National Press Club, a group most important to our national security. I say that because a major point I intend to make in my remarks today is that the single most critical element of a successful…
8. **9. Memorandum of Conversation** — Beijing , February 16, 1973, 2:15–6:00 p.m.  
   `frus1969-76v18/d9` · score -10.3686  
   > PARTICIPANTS Chou En-lai , Premier, State Council, Chi P’eng-fei , Minister of Foreign Affairs, Ch’iao Kuan-hua , Vice Minister of Foreign Affairs, Wang Hai-jung , Assistant Foreign Minister T’ang Wen-sheng , Interpreter Shen Jo-yun , Interpreter Two Notetakers Dr. Henry A. Kissinger , Assistant to…
9. **71. Memorandum of Conversation** — Helsinki , July 31, 1985, 2–5 p.m.  
   `frus1981-88v05/d71` · score -10.1172  
   > PARTICIPANTS U.S. SIDE Secretary Shultz Ambassador Hartman Ambassador Kampelman Ambassador Nitze Assistant Secretary Ridgway Ambassador Matlock Deputy Assistant Secretary Palmer Interpreter D. Zarechnak SOVIET SIDE Foreign Minister Shevardnadze Ambassador Dobrynin MFA Deputy Minister Komplektov…
10. **271. Memorandum of Conversation** — Moscow , May 24, 1972, 7:50–11 p.m.  
   `frus1969-76v14/d271` · score -10.0963  
   > PARTICIPANTS Leonid I. Brezhnev , General Secretary of the Central Committee of the CPSU Nikolai V. Podgorny , Chairman of the Presidium of the Supreme Soviet Aleksei N. Kosygin , Chairman of the Council of Ministers of the USSR Andrei M. Aleksandrov-Agentov , Assistant to the General Secretary…

### Semantic (query prompt)

1. **The Ambassador in Uruguay ( Dawson ) to the Secretary of State** — Montevideo , November 13, 1942—3 p.m. [Received 7:40 p.m.]  
   `frus1942v05/d78` · score 0.5984  
   > For the Under Secretary from Spaeth No. 43. Reference is made to the statement in the Department’s cable no. 669 of November 7, 7 p.m., Not printed. that one objective of the total effort being made in support of the North African campaign is to “immediately consolidate hemisphere solidarity…
2. **The Acting Secretary of State to the Ambassador in the Soviet Union ( Steinhardt )** — [ Washington ,] June 23, 1941 .  
   `frus1941v01/d725` · score 0.5971  
   > At a press conference held today the Acting Secretary, Welles, made the following statement: “If any further proof could conceivably be required of the real purposes and projects of the present leaders of Germany for world-domination, it is now furnished by Hitler’s treacherous attack upon Soviet…
3. **The Secretary of State to the Chargé in Germany ( Mayer )** — Washington , August 5, 1936 .  
   `frus1936v01/d265` · score 0.5953  
   > Sir : The Department is greatly interested in determining the attitude, policies and plans of the present Government and leaders in Germany in respect of the countries of Eastern Europe and it, consequently, hopes that the Embassy may find it practicable to devote special attention to this…
4. **The Ambassador in Germany ( Dodd ) to the Secretary of State** — Berlin , March 8, 1934 . [Received March 17.]  
   `frus1934v02/d413` · score 0.5930  
   > Sir : Referring to my confidential telegram No. 48, of March 6, 12 noon, I have the honor to enclose herewith copies and translation of the memorandum therein mentioned. It will be noticed that this was not written on stamped paper nor did it bear any initial or signature. There does not seem,…
5. **Memorandum of Conversation, by the Ambassador in Germany ( Wilson )** — March 22, 1938  
   `frus1938v02/d356` · score 0.5922  
   > Transmitted to the Department by the Ambassador in Germany in his despatch No. 41, March 23; received April 11. March 22, 1938 Dr. Goebbels received me in his office at the Reichs Propaganda Ministerium at 1:00 o’clock on March 22. He began the conversation by stating that he was very glad to meet…
6. **The Ambassador in France ( Bullitt ) to the Secretary of State** — Paris , September 19, 1939—noon . [Received 12:58 p.m.]  
   `frus1939v01/d718` · score 0.5892  
   > Personal for the President. I now have in written form the report made in Vienna on March 12th last by two leading Nazis, Secretary of State Wilhelm Keppler and Director General Vogl, to which I referred in my telegram No. 565, March 25, 1 p.m. Not printed; in this telegram Ambassador Bullitt…
7. **Memorandum by the Ambassador in Germany ( Wilson ) of a Conversation With the German Minister for Foreign Affairs ( Ribbentrop )**  
   `frus1938v02/d357` · score 0.5891  
   > Transmitted to the Department by the Ambassador in Germany in his despatch No. 125, May 2; received May 10. When we had disposed of the matter of American citizens in Vienna, concerning which I reported to the Department in my telegram No. 209, April 29, 1938, 7:00 p.m., Post , p. 513 . the…
8. **Memorandum of Conversation, by the Under Secretary of State ( Welles )** — [ Washington ,] March 14, 1938 .  
   `frus1938v01/d459` · score 0.5880  
   > The German Ambassador Hans Heinrich Dieckhoff. came in to see me this evening immediately after leaving the Secretary of State. The Ambassador told me that he had handed to the Secretary in its German text a formal communication For translation of communication, see Department of State, Press…
9. **Memorandum by the Secretary of State** — [ Washington ,] March 17, 1937 .  
   `frus1937v02/d277` · score 0.5870  
   > The German Ambassador called upon his own request at 3:00 o’clock this afternoon. He proceeded to detail and to emphasize the deepseated feeling aroused among German officials and the German people at the utterance of Mayor La Guardia at a mass meeting in New York on the night of March 15th. He…
10. **The Chargé in Germany ( Kirk ) to the Secretary of State** — Berlin , April 17, 1940—noon . [Received 6:05 p.m.]  
   `frus1940v01/d83` · score 0.5827  
   > For the Secretary and Under Secretary. Within the last few days I have spoken with the representatives in Berlin of practically every neutral country in the immediate or relative proximity of Germany, Italy and Russia. There is not one, who in view of the latest developments, does not fear for his…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 5/10.*
*document variant:* frus1942v05/d78, frus1936v01/d265, frus1941v01/d725, frus1940v01/d83, frus1934v02/d413, frus1934v02/d407, frus1940v02/d680, frus1937v01/d29, frus1939v01/d156, frus1938v02/d356
*bare variant:* frus1941v01/d725, frus1942v05/d78, frus1940v01/d83, frus1936v01/d265, frus1939v01/d718, frus1942v05/d247, frus1942v01/d242, frus1958-60v09/d41, frus1941v04/d25, frus1955-57v20/d229

---

## Q7. Intelligence collaboration

### Lexical — `"intelligence" AND "collaboration"`

1. **422. National Security Council Intelligence Directive No. 4** — Washington , December 12, 1947 .  
   `frus1945-50Intel/d422` · score -11.6651  
   > NATIONAL INTELLIGENCE OBJECTIVES Pursuant to the provisions of Section 102(d)(5) of the National Security Act of 1947 and for the purpose of providing intelligence support for the preparation of studies required by the National Security Council in the fulfillment of its duties, it is directed that:…
2. **The Ambassador in Burma ( Key ) to the Secretary of State** — Rangoon , June 28, 1951—3 p. m.  
   `frus1951v06p1/d129` · score -11.6189  
   > secret Rangoon , June 28, 1951—3 p. m. 966. Deptel 891, June 22. The Embassy in Burma was requested in telegram 891 to Rangoon, June 22 (not printed), to provide information to substantiate its previous assertion that the People’s Republic of China had decided to provide aid to Thakin Than Tun, the…
3. **200. Director of Central Intelligence Directive No. 4/3** — Washington , December 14, 1954 .  
   `frus1950-55Intel/d200` · score -11.5257  
   > COMPREHENSIVE NATIONAL INTELLIGENCE OBJECTIVES 1. Pursuant to National Security Council Intelligence Directive No. 4, Text in Foreign Relations , 1945–1950, Emergence of the Intelligence Establishment, Document 422 . paragraph 1, the following comprehensive national intelligence objectives,…
4. **Memorandum for the National Security Council by the Executive Secretary ( Lay )** — Washington , May 23, 1951 .  
   `frus1951v01/d18` · score -11.3848  
   > secret Washington , May 23, 1951 . Subject: Collaboration With Friendly Governments on Exchange of Information Concerning Operations Against Guerrillas Reference: NSC 90 NSC 90, October 26, 1950, is printed in Foreign Relations , 1950, vol. i , p. 401 . In accordance with the request of the…
5. **97. National Intelligence Estimate** — Washington , February 7, 1956 .  
   `frus1955-57v27/d97` · score -11.3230  
   > Another note on the cover sheet indicates that NIE 24–56 was a supplement to NIE 24–54, “Probable Developments in Italy,” November 16, 1954. (Department of State, INR– NIE Files) NIE 24–56 Washington , February 7, 1956 . THE POLITICAL OUTLOOK IN ITALY The Problem To estimate probable political…
6. **President Sergio Osmeña of the Philippines to the Secretary of the Interior ( Ickes )** — Manila , September 12, 1945 .  
   `frus1945v06/d914` · score -11.0833  
   > In reply to your telegram of September 11 I desire to state that information given you that I intend to release numerous persons against whom evidence was collected by the U.S. Army is erroneous. Persons kept in detention by Counter Intelligence Corps of U.S. Army and later delivered to the…
7. **30. Memorandum From the Assistant Chief of Staff for Military Intelligence of the War Department General Staff ( Bissell ) to Secretary of War Patterson** — Washington , October 22, 1945 .  
   `frus1945-50Intel/d30` · score -10.9212  
   > SUBJECT Discussion with Secretary of Navy Regarding Joint Intelligence 1. Reference paragraph 2 (joint intelligence) of the memorandum of 13 October from the Secretary of Navy, Document 26 . This memorandum was transmitted to Bissell under a October 22 memorandum from Colonel L.R. Forney , Acting…
8. **413. Memorandum From the Acting Chairman of the National Security Resources Board ( Steelman ) to the Executive Secretary of the National Security Council ( Souers )** — Washington , February 2, 1950 .  
   `frus1945-50Intel/d413` · score -10.9163  
   > SUBJECT Appraisal of Foreign Economic Intelligence Requirements, Facilities and Arrangements Related to the National Security As resources mobilization planning progresses, it is increasingly evident to the participating agencies that the full effectiveness of many segments of such planning depends…
9. **213. National Intelligence Estimate** — Washington , July 7, 1966 .  
   `frus1964-68v24/d213` · score -10.7431  
   > NIE 60–1–66 Washington , July 7, 1966 . THE RADICAL WEST AFRICAN STATES The Problem To assess the nature of West African radicalism as exemplified in Guinea, Mali, and Congo (Brazzaville) and the prospects over the next few years. Conclusions A. The radical or moderate character of a West African…
10. **The Consul General at Manila ( Steintorf ) to the Secretary of State** — Manila , September 5, 1945—9 a.m. [Received September 5—3:50 a.m.]  
   `frus1945v06/d911` · score -10.7377  
   > President Osmeña after conferring with Council of State issued Executive Order No. 65, Sept 3 Official Gazette , vol. 41, No. 6, p. 416. entitled “providing for the provisional release on bail of political prisoners, prior to the institution of the corresponding criminal cases against them,…

### Semantic (query prompt)

1. **41. Memorandum From the President’s Assistant for National Security Affairs ( Brzezinski )** — Washington , May 31, 1977  
   `frus1977-80v28/d41` · score 0.6106  
   > MEMORANDUM FOR The Vice President The Secretary of State The Secretary of Defense The Attorney General The Director, Office of Management and Budget The Director of Central Intelligence SUBJECT PRM/NSC–11 The attached report has been prepared by a special interagency drafting team for SCC…
2. **221. Report by the Commission on Organization of the Executive Branch of the Government to the Congress** — Washington , June 1955 .  
   `frus1950-55Intel/d221` · score 0.6049  
   > [Omitted here are a list of the members of the Commission and of the Task Force on Intelligence Activities, a transmittal letter, table of contents, acknowledgments, and preface.] PART I The task force, in order to give assurance to the Nation that all segments of the Intelligence Activities are…
3. **358. Report From the Intelligence Survey Group to the National Security Council** — Washington , January 1, 1949 .  
   `frus1945-50Intel/d358` · score 0.5907  
   > THE CENTRAL INTELLIGENCE ORGANIZATION AND NATIONAL ORGANIZATION FOR INTELLIGENCE Summary The primary object of this survey has been the Central Intelligence Agency, its organization and activities, and the relationship of these activities to the intelligence work of other Government agencies.…
4. **62. Message From Director of Central Intelligence Turner to Chiefs of Station** — Washington , October 4, 1977  
   `frus1977-80v28/d62` · score 0.5886  
   > To: [ 1½ lines not declassified ]. Ref: Director [ message indicator not declassified ]. 1. Ref transmits the text of new agreement between myself and Secretary of State on relationships between Chiefs of Station and Ambassadors. I want in this supplementary message to share with you both the…
5. **202. Paper by James Q. Reber of the Planning and Coordination Staff of the Central Intelligence Agency** — Washington , December 23, 1954 .  
   `frus1950-55Intel/d202` · score 0.5843  
   > INTELLIGENCE INFORMATION COLLECTION PROGRAM AND THE COORDINATION OF REQUIREMENTS 1. Coordination of collection requirements which are responsive to the intelligence production programs of the IAC and its member agencies is fundamental to obtain the maximum benefit from the collection activities of…
6. **35. Memorandum From the Assistant Director for Administrative Management, Bureau of the Budget ( Stone ) to the Assistant Director, Bureau of the Budget ( Appleby )** — Washington , October 26, 1945 .  
   `frus1945-50Intel/d35` · score 0.5832  
   > SUBJECT Comments on Proposal “U.S. Secret World-Wide Intelligence Coverage” Document 17 . Attached is a draft of a reply from you to Tom Clark covering his plan for a new intelligence setup. The draft is not printed. For the reply as sent, see Document 37 . The plan is analyzed below. This and the…
7. **50. Paper Prepared in the Department of Defense** — Washington , undated  
   `frus1977-80v28/d50` · score 0.5826  
   > STRUCTURE OF THE INTELLIGENCE COMMUNITY AS PROPOSED BY THE DEPARTMENT OF DEFENSE The principal problem with the present intelligence effort is that it is not adequately responsive to users, whether they are national, departmental or tactical. The central issue in assessing the options available to…
8. **247. Memorandum From the Director of the Bureau of Intelligence and Research ( Cline ) to the Under Secretary of State ( Irwin )** — Washington , December 1, 1971 .  
   `frus1969-76v02/d247` · score 0.5805  
   > SUBJECT Implications for the Department of the President’s Reorganization of the Intelligence Community The President’s reorganization of the management of U.S. Intelligence activities is a hopeful and timely move toward strengthening the entire Intelligence Community. The Department of State is…
9. **70. Memorandum From the Director of the Bureau of the Budget ( Smith ) to the President’s Special Counsel ( Rosenman )** — Washington , January 10, 1946 .  
   `frus1945-50Intel/d70` · score 0.5788  
   > Some time ago I asked Colonel McCormack , who used to be in Army Intelligence and who is now working on the intelligence problem for the State Department, to give me a memorandum concerning the subject. My staff regards him very highly. The memorandum just came in today, and I have not at this…
10. **17. Memorandum From Attorney General Clark to President Truman** — Washington , undated .  
   `frus1945-50Intel/d17` · score 0.5772  
   > A PLAN FOR U.S. SECRET WORLD-WIDE INTELLIGENCE COVERAGE Secret world-wide intelligence coverage for the benefit of the United States Government must have as its primary objectives the providing to the executive branches of the Government basic data on a world-wide scale upon which plans may be…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 7/10.*
*document variant:* frus1977-80v28/d41, frus1950-55Intel/d221, frus1969-76v02/d247, frus1977-80v28/d62, frus1969-76v02/d229, frus1945-50Intel/d35, frus1950-55Intel/d202, frus1945-50Intel/d358, frus1977-80v28/d42, frus1977-80v28/d50
*bare variant:* frus1977-80v28/d41, frus1977-80v28/d62, frus1977-80v28/d50, frus1950-55Intel/d202, frus1977-80v28/d42, frus1950v04/d156, frus1969-76v02/d247, frus1950-55Intel/d221, frus1977-80v28/d37, frus1945-50Intel/d17

---

## Q8. How did the United States collaborate with Great Britain to conduct economic warfare during World War II?

### Lexical — `"how" AND "did" AND "the" AND "united" AND "states" AND "collaborate" AND "with" AND "great" AND "britain" AND "to" AND "conduct" AND "economic" AND "warfare" AND "during" AND "world" AND "war" AND "ii?"`

1. **271. Draft Paper, June 22** — June 22, 1962  
   `frus1961-63v07-09mSupp/d271` · score -14.8967  
   > BASIC NATIONAL SECURITY POLICY PART ONE: PRINCIPLES AND PURPOSES Introduction 1. In order to outline national security policy in Part Two of this paper, it is necessary first to lay out the broad principles and purposes which generate these policies; which determine their relative impor tance and…
2. **299. Minutes of a Meeting of the Secretary of State’s Open Forum** — Washington , May 11, 1987  
   `frus1981-88v01/d299` · score -14.7796  
   > MR. WILSON: Welcome to a special session of the Secretary’s Open Forum. Today we celebrate the fortieth anniversary of the Policy Planning Staff. The theme of the anniversary is Future Foreign Policy Challenges for the U.S. Mr. Richard Solomon , the current Director of the Policy Planning Staff is…
3. **Notes of a Meeting Held at President Wilson’s House in the Place des Etats-Unis, Paris, on Tuesday, May 20, 1919, at 11 a.m.** — Paris , May 20, 1919, 11 a.m.  
   `frus1919Parisv05/d76` · score -14.2360  
   > CF–20 Notes of a Meeting Held at President Wilson’s House in the Place des Etats-Unis, Paris, on Tuesday, May 20, 1919, at 11 a.m. Paris , May 20, 1919, 11 a.m. Present United States of America President Wilson. France M. Clemenceau. British Empire Rt. Hon. D. Lloyd George, M. P. Italy H. E. M.…
4. **Memorandum Prepared in the Department of State** — [ Washington ,] May 19, 1942 .  
   `frus1931-41v02/d237` · score -14.0788  
   > ACCOUNT OF INFORMAL CONVERSATIONS BETWEEN THE GOVERNMENT OF THE UNITED STATES AND THE GOVERNMENT OF JAPAN, 1941 Introductory As the year 1941 opened, a vast movement of political forces throughout the world was intensely active. The Axis grouping among Germany, Italy and Japan had been formalized…
5. **Memorandum of Conversation, Prepared in the Department of State** — January 6 and 7, 1951 . January 12 and 13, 1951 .  
   `frus1951v07p2/d2` · score -12.8215  
   > This is the first of a series of unsigned memoranda, most or all of which were written by Charles Burton Marshall of the Policy Planning Staff. According to notations on the source texts, five copies (in a few cases, six copies) were made of each memorandum. One copy of each was sent to Deputy…
6. **United States Delegation Minutes, Third Formal Session, Conference of Foreign Ministers, Spiridonovka, Moscow, December 18, 1945, 4:00–7:15 p. m.** — Moscow , December 18, 1945, 4:00–7:15 p.m.  
   `frus1945v02/d235` · score -12.5981  
   > A brief report on this meeting was transmitted to Washington by the Secretary of State in telegram 4221, Delsec 15, December 19, 1945, from Moscow (740.00119 Council/12–1945). Moscow , December 18, 1945, 4:00–7:15 p.m. Present: According to the British delegation minutes of this meeting (not…
7. **Memorandum Prepared in the Department of State** — [ Washington , undated .]  
   `frus1947v05/d395` · score -11.4357  
   > top secret [ Washington , undated .] Specific Current Questions [Here follow a table of contents and a note which states: “The material included in this section was prepared by officers dealing with these matters in the interested geographical divisions of the Department and is intended primarily…
8. **193. Memorandum From Acting Director of Central Intelligence Gates to the President’s Assistant for National Security Affairs ( Carlucci )** — Washington , January 15, 1987  
   `frus1981-88v44p1/d193` · score -11.1785  
   > SUBJECT NSDD 250 Response [ portion markings not declassified ] 1. Attached is the DCI response to a key portion of the tasking that was posed to the Director in NSDD 250; that portion of the tasking that dealt with verification matters and was assigned to Ken Adelman and the DCI jointly as well as…
9. **The Military Representative on the Supreme War Council ( Bliss ) to the Secretary of State** — Washington , February 19, 1920 .  
   `frus1914-20v02/d147` · score -10.5685  
   > Sir : I have the honor to submit, herewith, my report on the Supreme War Council. A duplicate copy has been handed to the Secretary of War. Very respectfully, Tasker H. Bliss [Enclosure] The Military Representative on the Supreme War Council ( Bliss ) to the Secretary of State Washington , February…
10. **22. Draft Report Prepared by Lincoln Bloomfield , Special Assistant to the Assistant Secretary of State for International Organization Affairs** — Washington , February 9, 1956 .  
   `frus1955-57v11/d22` · score -10.2681  
   > SUBJECT Report on “Evaluation of Role of US in 10th General Assembly” Problem To analyze objectively the effect which the 10th Session has had on the international position of the United States, particularly upon the factors of prestige and general reputation in the American role of world…

### Semantic (query prompt)

1. **Memorandum by the Secretary of State to President Roosevelt** — Washington , September 8, 1944 .  
   `frus1944v03/d19` · score 0.6428  
   > Lend-Lease and General Economic Relations with the United Kingdom in “Phase 2” Phase 2 designated the period of the war between the surrender of Germany and the surrender of Japan. 1. The most important international economic problem of the transition and post-war periods will be the situation of…
2. **The Secretary of State to the President** — Washington , September 8, 1944 .  
   `frus1944Quebec/d110` · score 0.6325  
   > Lend-Lease and General Economic Relations With the United Kingdom in “Phase 2” 1. The most important international economic problem of the transition and post-war periods will be the situation of the United Kingdom: the sterling–dollar relationship, the change in Britain’s creditor position, the…
3. **The Secretary of State to the Diplomatic Representatives in the American Republics Except Argentina** — Washington , December 7, 1943 .  
   `frus1944v07/d1457` · score 0.6262  
   > Sirs : During the past years this Government has inaugurated many programs directed at implementation of economic warfare against the Axis in the American republics. One such program, which to some extent has overlapped the matter of Proclaimed List and related questions, has been the program for…
4. **The Secretary of State to the Ambassador in the United Kingdom ( Winant )** — Washington , September 19, 1944—12:40 p.m.  
   `frus1944v03/d22` · score 0.6248  
   > A–1843. At the President’s request I am repeating to you herein a memorandum to me from the President dated September 15, 1944: This memorandum was sent by President Roosevelt from the Second Quebec Conference. It is based on a memorandum initialled by British Prime Minister Churchill and President…
5. **Memorandum by Mr. Howard J. Trueblood of the Office of the Adviser on International Economic Affairs** — [ Washington ,] November 12, 1940 .  
   `frus1940v04/d657` · score 0.6216  
   > Assistant Secretary of State Grady on November 19 added a notation as follows: “I feel that our reply to the British should indicate sympathy with the objectives and a desire to cooperate to the extent that it is practical.” [ Washington ,] November 12, 1940 . From an examination of the underlying…
6. **Memorandum by the Secretary of State to President Roosevelt** — Washington , September 30, 1944 .  
   `frus1944v03/d23` · score 0.6175  
   > Handed to the President by the Secretary of State, October 1, 1944. Washington , September 30, 1944 . You will recall my memorandum of September 2, 1944, Not printed. suggesting that you urge upon Mr. Churchill the early resumption of conversations on economic policy, and my memorandum of September…
7. **The British Ambassador ( Lothian ) to the Secretary of State**  
   `frus1940v03/d84` · score 0.6167  
   > Memorandum The British Ambassador appreciates the understanding shown in Mr. Cordell Hull’s memorandum of February 21st, 1940, of the grave conditions with which Great Britain is confronted in financing its maximum war effort and of the reasons which compel the United Kingdom Government to reduce…
8. **Memorandum of Conversation, by the Secretary of State** — [ Washington ,] July 5, 1940 .  
   `frus1940v03/d38` · score 0.6124  
   > The British Ambassador called at his request and handed me an aide-mémoire dated July 3, 1940 (copy attached), which reviewed at length the altered situation of the British in view of the collapse of the French. This aide-mémoire pointed out certain considerations and situations which the British…
9. **The Department of State to the British Embassy** — [ Washington ,] February 21, 1940 .  
   `frus1940v03/d82` · score 0.6067  
   > Memorandum It is recognized that the British Ambassador’s memorandum of February 14, as amended by the memorandum of February 16, Neither memorandum printed. In presenting the memorandum of February 14, the British Ambassador explained that it was not an official document and that his Government…
10. **Department of State Policy Statement** — Washington , June 11, 1948 .  
   `frus1948v03/d679` · score 0.6063  
   > s were concise summaries of current United States policy toward a country or region, relations of that country or region with the principal powers, and the issues and trends in that country or region. The statements, which were generally prepared by ad hoc working groups in the responsible bureaus…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 8/10.*
*document variant:* frus1944v03/d19, frus1944Quebec/d110, frus1944v07/d1457, frus1940v03/d84, frus1944v03/d23, frus1940v03/d82, frus1948v03/d679, frus1944v03/d22, frus1944v03/d30, frus1942v01/d142
*bare variant:* frus1944v03/d19, frus1944Quebec/d110, frus1944v07/d1457, frus1940v04/d657, frus1944v03/d22, frus1940v03/d38, frus1917Supp02v02/d19, frus1944v03/d23, frus1943v03/d39, frus1948v03/d679

---

## Q9. Foreign Service reform

### Lexical — `"foreign" AND "service" AND "reform"`

1. **338. Action Memorandum From the Chairman of the Secretary’s Open Forum Panel, Department of State ( Thomas ) to the Deputy Under Secretary of State for Administration ( Macomber )** — Washington , October 20, 1971 .  
   `frus1969-76v02/d338` · score -11.6477  
   > REFORM OF THE ROLE OF FOREIGN SERVICE WIVES It has become increasingly clear in the past few years that a reform is urgently needed in the treatment of Foreign Service wives. No question before the Open Forum Panel has been more controversial; none has drawn consistently greater attendance at Panel…
2. **Preface**  
   `frus1977-80v28/preface` · score -11.4344  
   > Structure and Scope of the Foreign Relations Series This volume is part of a subseries of volumes of the Foreign Relations series that documents the most important issues in the foreign policy of the administration of Jimmy Carter . The subseries presents a documentary record of major foreign…
3. **No. 201. Mr. Francis to Mr. Fish .** — Legation of the United States , Athens , June 29, 1872 . (Received July 22.)  
   `frus1872p1/d201` · score -11.1945  
   > Sir : I have the honor to transmit herewith a copy of a letter addressed by me to Mr. Mélétopoulo, secretary-general of the minister of foreign affairs, under date of the 18th instant, inclosing documents on civil-service reform in the United States. And I also transmit a copy of the reply of Mr.…
4. **171. Memorandum From the Senior Officer Bunch to the Under Secretary of State for Management ( Read ) and the Director General of the Foreign Service and Director of Personnel ( Barnes )** — Washington , undated  
   `frus1977-80v28/d171` · score -11.1292  
   > In reply to your request, Not further identified. please find attached our recommendations for specific changes in the proposed Foreign Service Act of 1980. Attached but not printed. Our recommendations are substantively the same as those we have suggested over the last few months See, for example,…
5. **153. Memorandum From the Director of the Office of Civil Service Career Development and Assignments ( Bourbon ) to the Director General of the Foreign Service and Director of Personnel ( Barnes )** — Washington , June 2, 1978  
   `frus1977-80v28/d153` · score -10.8338  
   > SUBJECT Status of FPMP The House Government Operations Committee will hold bearings on Reorganization Plan Number 2 Carter submitted Reorganization Plan No. 2 of 1978 to Congress on May 23. See Public Papers: Carter , 1978 , Book I, pp. 953–959. (to establish an Office of Personnel Management) on…
6. **326. Memorandum From Mary S. Olmsted of the Ad Hoc Women’s Committee, Department of State to Chris Petrow of the Office of the Deputy Under Secretary of State for Administration** — Washington , October 7, 1970 .  
   `frus1969-76v02/d326` · score -10.6314  
   > SUBJECT Our Recommendations re Task Force Reports Thank you for the time and trouble you went to in making our views known to the chairmen of the Task Forces about the role and status of women in the Department and the Foreign Service, and for your memorandum of September 30 reporting their…
7. **155. Memorandum From the Director of the Office of Civil Service Career Development and Assignments ( Bourbon ) to the Director General of the Foreign Service and Director of Personnel ( Barnes )** — Washington , August 4, 1978  
   `frus1977-80v28/d155` · score -10.6090  
   > SUBJECT Civil Service Reform Legislation The House Post Office and Civil Service Committee print of the Civil Service Reform Act of 1978, which was expected at CSC today, has not yet arrived. We will get a copy when it does arrive. A New York Times article of August 3, 1978 (attached) Attached but…
8. **339. Memorandum From the Chairman of the Department of State Task Force VII Committee ( Petrow ) to the Deputy Under Secretary of State for Management ( Macomber )** — Washington , December 21, 1971 .  
   `frus1969-76v02/d339` · score -10.5808  
   > SUBJECT Findings of Task Force Chairmen The following represents a consensus of the views of the Task Force Chairmen. It is a summary of their findings during their week-long inquiry in the Department and of their recommendations for the future. I. Findings A. The first and the most important thing…
9. **256. Paper Prepared in the Department of the Treasury** — Washington , undated  
   `frus1981-88v38/d256` · score -10.4898  
   > CONTINUATION OF CURRENT APPROACH TO DEBT PROBLEMS: A REALISTIC ASSESSMENT The current approach to debt problems focuses on the adoption of debtor reforms buttressed by external financial support. Its fundamental objective is to generate stronger growth in debtor nations as a basis for achieving a…
10. **The Chief of the Division of Latin American Affairs, Department of State ( Munro ) to the Secretary of State** — [ Washington ,] April 10, 1922 .  
   `frus1922v01/d839` · score -10.4425  
   > Dear Mr. Secretary : In the attached despatch Despatch of Apr. 9, supra. and telegram, Telegram of Apr. 8, 4 p.m., p. 1019 . General Crowder requests authorization to present two memoranda, which he regards as equivalent to an ultimatum, to the Cuban Government. The first memorandum discusses very…

### Semantic (query prompt)

1. **158. Report to Congress Prepared in the Department of State** — Washington , January 10, 1977 .  
   `frus1969-76v38p2/d158` · score 0.6886  
   > MEETING FUTURE FOREIGN AFFAIRS PERSONNEL NEEDS Report to the Congress on Plans for Improving and Simplifying the Personnel Systems of the Department of State and the United States Information Agency [Omitted here is the table of contents.] I. Introduction and Summary To meet the demands of national…
2. **164. Memorandum From the Director of the Office of UN Political Affairs (Bridges) to the Under Secretary of State for Management ( Read ) and the Director General of the Foreign Service and Director of Personnel ( Barnes )** — Washington , January 24, 1979  
   `frus1977-80v28/d164` · score 0.6806  
   > SUBJECT Proposed Personnel System Changes I venture to offer you the following reactions to the proposed changes in the Foreign Service personnel system. The proposals were not found. As a one-time worker in Personnel, I can appreciate how much work has gone into the proposals. But I am very sorry…
3. **144. Memorandum of Conversation** — Washington , June 5, 1975, 6:30–7:30 p.m.  
   `frus1969-76v38p2/d144` · score 0.6663  
   > PARTICIPANTS Secretary Kissinger Deputy Secretary Ingersoll Ambassador Carol Laise , Director General Mr. Lawrence S. Eagleburger , Deputy Under Secretary for Management Mr. L.P. Bremer, Executive Assistant to the Secretary Mr. Wesley W. Egan, Jr., Notetaker SUBJECT “The Professional Service of the…
4. **181. Letter From the Under Secretary of State for Management ( Read ) to the Director of the Office of Management and Budget (McIntyre)** — Washington , October 6, 1980  
   `frus1977-80v28/d181` · score 0.6593  
   > Dear Jim: I am writing to provide the views of the Department of State on H.R. 6790, an enrolled bill to “promote the foreign policy of the United States by strengthening and improving the Foreign Service of the United States, and for other purposes.” H.R. 6790 was introduced on March 12. The…
5. **223. Briefing Paper Prepared in the Department of State** — Washington , undated .  
   `frus1969-76v38p2/d223` · score 0.6568  
   > Department Organizational and Personnel Issues In this Department, more than in program-oriented agencies, the fundamental resource is people, and organizational performance depends to an unusual extent on the quality of our personnel and on the way we manage and direct their efforts. I. Department…
6. **161. Memorandum From the Director General of the Foreign Service and Director of Personnel ( Barnes ) to Secretary of State Vance** — Washington , January 25, 1978  
   `frus1977-80v28/d161` · score 0.6493  
   > Your Meeting with the FSO Group Background You have agreed to meet with a small group of FSOs No minutes of this meeting were found. who represent the 500-some officers who signed a letter (attached) expressing concern over the state of the Service. This is a serious group. It came together…
7. **154. Memorandum From the Director General of the Foreign Service ( Laise ) to the Deputy Under Secretary of State for Management ( Eagleburger )** — Washington , undated .  
   `frus1969-76v38p2/d154` · score 0.6448  
   > SUBJECT The Department’s Personnel Structure: A Rational Solution The structure of the Department’s personnel system has been studied enough times, both from without and within, so that any attempt to characterize the process almost inevitably falls into cliches. Even as we moved into the postwar…
8. **55. Memorandum From the President’s Special Representative ( Bowles ) to President Kennedy** — Washington , May 25, 1962 .  
   `frus1961-63v25/d55` · score 0.6430  
   > SUBJECT Recommendations for Strengthening the Foreign Service Summary and Recommendations: Some progress has been made in streamlining and modernizing our operational techniques of dealing with the problems of foreign policy. Two key obstacles stand in the way of further movement: 1. There is no…
9. **174. Airgram From the Department of State to All Diplomatic and Consular Posts** — Washington , June 26, 1979, 10:57 a.m.  
   `frus1977-80v28/d174` · score 0.6419  
   > A–2040 Washington , June 26, 1979, 10:57 a.m. SUBJECT Proposed Foreign Service Act of 1979 On June 20, 1979 the Secretary submitted the proposed Foreign Service Act of 1979 to the Congress. He and Under Secretary Read testified in support of the Bill on June 21. This Airgram forwards for your…
10. **323. Memorandum From the Assistant Secretary of State for European Affairs ( Hillenbrand ) to the Deputy Under Secretary of State for Administration ( Macomber )** — Washington , August 19, 1970 .  
   `frus1969-76v02/d323` · score 0.6392  
   > SUBJECT Task Force Reports As you are aware, a number of the Task Forces’ recommendations relate directly to the organization and operations of the regional bureaus. I have therefore encouraged the officers of EUR to submit comments on those recommendations. A number of the more cogent of these…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 6/10.*
*document variant:* frus1977-80v28/d164, frus1969-76v38p2/d158, frus1969-76v38p2/d223, frus1977-80v28/d169, frus1977-80v28/d161, frus1969-76v38p2/d154, frus1969-76v38p2/d144, frus1977-80v28/d181, frus1969-76v02/d323, frus1969-76v02/d339
*bare variant:* frus1977-80v28/d164, frus1969-76v38p2/d144, frus1977-80v28/d161, frus1977-80v28/d181, frus1969-76v02/d339, frus1969-76v38p2/d223, frus1961-63v25/d55, frus1977-80v28/d169, frus1977-80v28/d167, frus1977-80v28/d180

---

## Q10. What convinced U.S. policymakers that the Soviet Union was no long an ally after World War II?

### Lexical — `"what" AND "convinced" AND "u.s." AND "policymakers" AND "that" AND "the" AND "soviet" AND "union" AND "was" AND "no" AND "long" AND "an" AND "ally" AND "after" AND "world" AND "war" AND "ii?"`

1. ****  
   `frus1969-76v34/d59` · score -26.8950  
   > Editorial Note An outgrowth of the Nixon administration’s policy of linkage, making negotiating progress in one area dependent on progress in another, was the threatened use of U.S. or allied military force to encourage North Vietnam and their Soviet patrons to reach a settlement to the conflict in…
2. **8. Address by Ronald Reagan** — Chicago , August 18, 1980  
   `frus1981-88v01/d8` · score -23.4824  
   > [Omitted here are Reagan’s introductory remarks and the portion of his address dealing with the Veterans Administration.] These are matters of great concern to your great organization. Let us turn now to a matter which vitally concerns our nation — “PEACE”. It has always struck me as odd that you…
3. **Volume Summary**  
   `frus1964-68v12/summary` · score -22.4085  
   > (This is not an official statement of policy by the Department of State; it is intended only as a guide to the contents of this volume.) Since 1861, the Department of State’s documentary series Foreign Relations of the United States has constituted the official record of the foreign policy and…
4. **241. Memorandum of Conversation** — Washington , March 20, 1980, 1–3 p.m.  
   `frus1977-80v12/d241` · score -21.0656  
   > PARTICIPANTS Alexander Bessmertnykh , Minister-Counselor, Soviet Embassy Marshall Brement , NSC Staff Member SUBJECT Afghanistan and US-Soviet Relations (U) Bessmertnykh opened the conversation by insisting on the need to maintain channels of communication between us, a sentiment with which I…
5. **192. Remarks by President Reagan** — Washington , April 6, 1984  
   `frus1981-88v01/d192` · score -17.4301  
   > Remarks at the National Leadership Forum of the Center for Strategic and International Studies of Georgetown University Thank you very much, Ann Armstrong . Thank you, Cochairman Sam Nunn . I am honored to have this opportunity to take part in your National Leadership Forum. The CSIS reputation for…
6. **Report to the President by the President’s Committee on International Information Activities** — [ Washington ,] June 30, 1953 .  
   `frus1952-54v02p2/d370` · score -16.7076  
   > top secret [ Washington ,] June 30, 1953 . [Here follow a table of contents and a list of appendices, of which all but Appendix II are printed.] Letter of Transmittal June 30, 1953. Dear Mr. President : We submit herewith the report of the President’s Committee on International Information…
7. **300. Response to National Security Study Memorandum 156** — Washington , September 1, 1972  
   `frus1969-76ve07/d300` · score -13.4342  
   > In response to NSSM 156, the NSC Interdepartmental Group for Near East and South Asia assessed India’s nuclear capabilities and intentions and U.S. options for influencing India on the issue. Washington , September 1, 1972 SUMMARY Indian Capabilities/Intentions At present India’s relatively…

### Semantic (query prompt)

1. **Memorandum by the Acting Department of State Member ( Matthews ) to the State–War–Navy Coordinating Committee** — Washington , April 1, 1946 .  
   `frus1946v01/d591` · score 0.6642  
   > top secret Washington , April 1, 1946 . Subject: Political Estimate of Soviet Policy for Use in Connection with Military Studies This memorandum was prepared in response to a request submitted by the Joint Chiefs of Staff to the State-War-Navy Coordinating Committee on March 13. In that request,…
2. **Draft Department of State Policy Statement** — Washington , undated .  
   `frus1951v04p2/d302` · score 0.6510  
   > Copies of interoffice memoranda attached to the source text indicate that this draft policy statement was prepared in the Office of Eastern European Affairs, and received working-level clearances by EUR , UNA , PD , UNP , P , TRC , and ITP , apparently during January, February, and March 1951. In a…
3. **Memorandum “by the Director of the Office of European Affairs ( Hickerson ) to the Under Secretary of State ( Lovett )** — [ Washington ,] May 27, 1948 .  
   `frus1948v04/d589` · score 0.6495  
   > I. Summary of Acts From United States Side Evidencing Desire for Cooperation With Soviet Union. A. War Aid 1. Military and civilian supplies to a value of over $11 billion were supplied the Soviet Union under Lend-Lease, 2. Military and technological information was furnished through U.S. military…
4. **The Ambassador in the Soviet Union ( Smith ) to the Secretary of State** — Moscow , May 10, 1948—1 a. m.  
   `frus1948v04/d570` · score 0.6411  
   > top secret niact us urgent Moscow , May 10, 1948—1 a. m. 867. Eyes only for the Secretary from Smith. The Soviet Government has familiarized itself with the declaration of the Ambassador of the USA, Mr. Smith, dated May 4, 1948, See telegram 836, May 4, p. 847 . in connection with the present state…
5. **The Chargé in Latvia ( Cole ) to the Acting Secretary of State** — Riga , November 23, 1933 . [Received December 5.]  
   `frus1933v02/d609` · score 0.6356  
   > Sir : I have the honor to enclose a translation in full Not printed. of the leading editorial in the Moscow Izvestiya , organ of the Central Executive Committee of the Union of the Soviet Socialist Republics, No. 282, of November 20, 1933, concerning the recognition of the Union by the United…
6. **Memorandum of Conversation, by the Assistant Secretary of State for Far Eastern Affairs ( Rusk )** — [ Washington ,] October 4, 1950 .  
   `frus1950v04/d701` · score 0.6335  
   > top secret [ Washington ,] October 4, 1950 . Participants: Yakov A. Malik Yakov Alexandrovich Malik was the Permanent Representative of the Soviet Union to the United Nations, 1948–1952. —Soviet Delegation to the United Nations W. W. Lancaster—National City Bank of New York Dean Rusk—Assistant…
7. **61. Memorandum of Conversation** — Washington , January 6, 1959 .  
   `frus1958-60v10p1/d61` · score 0.6306  
   > SUBJECT US -Soviet Relations PARTICIPANTS Richard M. Nixon , Vice President of the United States Anastas I. Mikoyan , Deputy Premier of the Soviet Union Mikhail A. Menshikov , Soviet Ambassador Llewellyn E. Thompson , American Ambassador Oleg A. Troyanovsky, Ministry of Foreign Affairs of the USSR…
8. **The Chargé in Latvia ( Cole ) to the Acting Secretary of State** — Riga , November 23, 1933 . [Received December 5.]  
   `frus1933-39/d47` · score 0.6303  
   > Sir : I have the honor to enclose a translation in full Not printed. of the leading editorial in the Moscow Izvestiya , organ of the Central Executive Committee of the Union of the Soviet Socialist Republics, No. 282, of November 20, 1933, concerning the recognition of the Union by the United…
9. **The Ambassador in the Soviet Union ( Smith ) to the Secretary of State** — Moscow , May 4, 1948—7 p. m.  
   `frus1948v04/d567` · score 0.6301  
   > top secret Moscow , May 4, 1948—7 p. m. 836. Eyes only. Reference mytel 835 May 4. Following exact text of statement to Molotov, informal transcript of which has been given to Troyanovski: Two years ago during my initial conversation with Generalissimo Stalin and yourself, I stated as clearly as…
10. **249. Study Prepared by an Ad Hoc Interagency Group on U.S.-Soviet Relations** — Washington , December 6, 1982  
   `frus1981-88v03/d249` · score 0.6256  
   > Response to NSSD 11–82 : U.S. Relations With The USSR INTRODUCTION The record of US-Soviet relations since October, 1917, has been one of tension and hostility, interrupted by short-lived periods of cooperation. The Soviet challenge to U.S. interests has many roots, including: (1) an imperial…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 5/10, bare: 6/10.*
*document variant:* frus1946v01/d591, frus1981-88v03/d249, frus1948v04/d589, frus1951v04p2/d302, frus1981-88v03/d260, frus1948v01p2/d60, frus1969-76v12/d68, frus1950v04/d701, frus1961-63v09/d324, frus1969-76v01/d41
*bare variant:* frus1946v01/d591, frus1948v04/d589, frus1951v04p2/d302, frus1981-88v03/d249, frus1948v04/d570, frus1950v04/d701, frus1981-88v03/d260, frus1969-76v01/d41, frus1948v01p2/d60, frus1951v01/d323

---

## Q11. At what point did U.S. decision makers determine that the Nationalists couldn't prevail in the Chinese Civil War?

### Lexical — `"at" AND "what" AND "point" AND "did" AND "u.s." AND "decision" AND "makers" AND "determine" AND "that" AND "the" AND "nationalists" AND "couldn't" AND "prevail" AND "in" AND "the" AND "chinese" AND "civil" AND "war?"`

*(no results)*

### Semantic (query prompt)

1. **Draft Policy Memorandum Prepared in the Embassy in China**  
   `frus1946v10/d69` · score 0.6231  
   > See last paragraph of General Marshall’s telegram No. 1367, August 23, p. 79 . This draft was forwarded on September 6 by the Minister-Counselor of Embassy (Butterworth) to General Marshall with the observation, “Needless to say, I am not satisfied with it, having sought unsuccessfully some elixir…
2. **Memorandum by the Policy Planning Staff** — [ Washington ,] November 23, 1948 .  
   `frus1948v08/d164` · score 0.6191  
   > PPS 39/1 [ Washington ,] November 23, 1948 . U. S. Policy Toward China The following are the views of the Policy Planning Staff on the assertion, now frequently heard both inside and outside the Government, that we have no policy with relation to the present course of events in China, and that it…
3. **Memorandum of Conversation, Prepared in the Department of State** — January 6 and 7, 1951 . January 12 and 13, 1951 .  
   `frus1951v07p2/d2` · score 0.6145  
   > This is the first of a series of unsigned memoranda, most or all of which were written by Charles Burton Marshall of the Policy Planning Staff. According to notations on the source texts, five copies (in a few cases, six copies) were made of each memorandum. One copy of each was sent to Deputy…
4. **The Chargé in China ( Strong ) to the Secretary of State** — Canton , September 15, 1949—6 p. m. [Received September 16—1:08 p. m.]  
   `frus1949v08/d602` · score 0.6097  
   > Cantel 1112. Embassy has following comments on Nanking telegram 1994 to Department, repeated Shanghai 1083, September 3. In view of long record of Nationalists’ failures against Communists, the premises and conclusions as to US action strike a most responsive chord. Yet despite our pessimism over…
5. **Note by Rear Admiral Sidney W. Souers , Executive Secretary to the National Security Council** — [ Washington ,] July 26, 1948 .  
   `frus1948v08/d105` · score 0.6072  
   > NSC 22 [ Washington ,] July 26, 1948 . Possible Courses of Action for the U. S. With Respect to the Critical Situation in China At the request of the Secretary of the Army the enclosed paper assessing the current critical situation in China and outlining alternative courses of action is circulated…
6. **The Acting Secretary of State to General Marshall** — Washington , July 4, 1946—noon .  
   `frus1946v09/d636` · score 0.6062  
   > Drafted by the Director of the Office of Far Eastern Affairs (Vincent). Washington , July 4, 1946—noon . 414. The following comment, responsive to your request of July 2, No. 1032, p. 1277 . is offered in the realization that some portions may be obvious to you but in the hope that others may prove…
7. **Memorandum by the Director of the Office of Far Eastern Affairs ( Butterworth ) to the Under Secretary of State ( Webb )** — [ Washington ,] May 17, 1949 .  
   `frus1949v08/d378` · score 0.6058  
   > The most important aspect of the situation in Nationalist China is the continued failure of the leadership to unify its defense efforts. In the struggle between the Generalissimo and Acting President Li Tsung-jen, Li is demanding that the Generalissimo either resume office or give Li full control…
8. **Minutes of Briefing Session of the United States Delegation to the General Assembly, Washington, Department of State, September 7, 1950, 3:00 p. m .** — Washington , September 7, 1950, 3:00 p.m.  
   `frus1950v02/d161` · score 0.6032  
   > secret [Here follows list of representatives and alternate representatives present (8).] 1. Chinese Representation Under the Chairmanship of Ambassador Austin, the Delegation continued its briefing meeting in the afternoon. The first briefing meeting, held on the morning of September 7, was chaired…
9. **Memorandum by the Director of the Office of Far Eastern Affairs ( Vincent )**  
   `frus1945v07/d541` · score 0.6010  
   > Copy in Department files bears no indication of drafting officer, and date was apparently inserted subsequently; name of drafting officer and date supplied from text printed in Institute of Pacific Relations: Hearings before the Subcommittee to Investigate the Administration of the Internal…
10. **The Ambassador in China ( Gauss ) to the Secretary of State** — Chungking , September 28, 1944 . [Received October 24.]  
   `frus1944v06/d453` · score 0.6001  
   > Sir : I have the honor to transmit copies of the following reports prepared by Mr. John S. Service, Second Secretary of Embassy on detail to General Stilwell’s Headquarters, now in Yenan, Shensi (seat of the Chinese Communist regime) as a member of the United States Army Observer Section. (1)…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 4/10, bare: 6/10.*
*document variant:* frus1948v08/d164, frus1947v07/d616, frus1948v08/d105, frus1948v08/d46, frus1948v08/d122, frus1944v06/d453, frus1946v10/d69, frus1947v07/d591, frus1947v07/d666, frus1955-57v03/d248
*bare variant:* frus1948v08/d164, frus1946v10/d69, frus1948v08/d105, frus1964-68v30/d236, frus1947v07/d616, frus1948v08/d122, frus1944v06/d453, frus1950v02/d161, frus1951v07p2/d2, frus1948v08/d46

---

## Q12. Deposing shah

### Lexical — `"deposing" AND "shah"`

1. **Minister Pearson to the Secretary of State .** — Teheran , August 12, 1906 .  
   `frus1906p2/d327` · score -16.8057  
   > (Mr. Pearson states that popular agitation, similar to that in Russia, demanding constitutional reforms but less violent, has triumphed in Persia. Rioting in Teheran, resulting in killing 117 persons, including two Seyids, descendants of Mahomet, insurgents and other advocates of greater liberty…
2. **279. Telegram From the Embassy in Italy to the Department of State** — Rome , August 18, 1953, 8 p.m .  
   `frus1951-54Iran/d279` · score -16.6280  
   > Shah arrived Rome early this afternoon (reference Baghdad’s 97 and Tehran’s 374 to Department). Not found. Associated Press has given Embassy following on what it believes exclusive interview with Shah: Asked about Iranian Foreign Minister’s demand that he abdicate, he said “I am not (repeat not)…
3. **279. Telegram From the Embassy in Italy to the Department of State** — Rome , August 18, 1953, 8 p.m.  
   `frus1951-54IranEd2/d279` · score -16.6280  
   > Shah arrived Rome early this afternoon (reference Baghdad’s 97 and Tehran’s 374 to Department). Not found. Associated Press has given Embassy following on what it believes exclusive interview with Shah: Asked about Iranian Foreign Minister’s demand that he abdicate, he said “I am not (repeat not)…
4. **The Chargé in Iran ( Ford ) to the Secretary of State** — Tehran , December 16, 1943—3 p.m. [Received 5:45 p.m.]  
   `frus1943v04/d437` · score -16.3714  
   > New Cabinet, 1125, December 16, is regarded locally as clear victory for Shah who has been able to place his own candidates in a majority of Cabinet posts. Soheily has also gained his ends and strengthened his position by eliminating the opposing elements in the previous Cabinet including Tadayyon,…
5. **The Acting Secretary of State to the American Minister .** — Department of State , Washington , July 31, 1911 .  
   `frus1911/d988` · score -16.3671  
   > In view of alarmist press telegrams, report concisely by telegraph concerning the political situation, with particular reference to the return of the deposed Shah and the attitude of the British and Russian Governments toward the internal situation and toward the American financial advisers. Adee.
6. **No. 316 The Ambassador in Iran ( Henderson ) to the Department of State** — Tehran , March 10, 1953—1 p.m.  
   `frus1952-54v10/d316` · score -14.6126  
   > The Ambassador in Iran ( Henderson ) to the Department of State Transmitted in two sections; also sent to London and pouched to Ankara, Baghdad, Cairo, and Dhahran. secret priority Tehran , March 10, 1953—1 p.m. 3627. 1. Department will have noted we have not as yet presented our ideas as to why…
7. **No. 250. Mr. Gibbs to Mr. Evarts .** — Legation of the United States , Lima, Peru , June 12, 1877 . (Received July 9.)  
   `frus1877/d250` · score -14.0541  
   > Sir : Since my dispatch No. 159, of 9th instant, an apparent conspiracy to change the government was attempted and has failed. The excitement of the affair of the Huascar and Her Britannic Majesty’s ships Shah and Amethyst had subsided, but a deep feeling remained against the government by charges…
8. **The Ambassador in Iran ( Murray ) to the Secretary of State** — Tehran , June 26, 1945—9 a.m. [Received June 26—6:35 a.m.]  
   `frus1945v08/d349` · score -13.5998  
   > Dept’s instruction of Feb 28, 1945. Not printed. In view of unavoidable delay in reporting sooner by written despatch on the delivery to the Shah on June 5 last of my letters of credence and the audience I had with him following the ceremonies of presentation, I believe the Dept may be interested…
9. **291. Memorandum of Discussion at the 449th Meeting of the National Security Council** — Washington , June 30, 1960 .  
   `frus1958-60v12/d291` · score -13.3896  
   > [Here follow a paragraph listing the participants at the meeting and agenda item 1.] 2. Significant World Developments Affecting U.S. Security [Here follows discussion of unrelated matters by Acting Director of Central Intelligence Cabell .] Turning to Iran, General Cabell reported that relations…
10. **393. Despatch From the Embassy in Iran to the Department of State** — Tehran , March 11, 1957 .  
   `frus1955-57v12/d393` · score -12.5460  
   > REF Embdes 736, December 20, 1951 Not printed. ( Ibid., 788.11/12–2051) SUBJECT The Shah of Iran, 1957—A Revised Study Enclosed is a memorandum entitled The Shah of Iran , 1957—A Revised Study, prepared by Second Secretary Thomas A. Cassilly before his recent transfer from this post. Mr. Cassilly…

### Semantic (query prompt)

1. **Mr. McDonald to Mr. Olney .** — Legation of the United States , Teheran, Persia , May 4, 1896 . (Received June 11.)  
   `frus1896/d386` · score 0.5862  
   > Dip. Ser.] Sir : It is my melancholy duty to report for your information the facts, as far as they can be ascertained, in connection with the assassination of His Majesty the Shah. My telegram of the 1st instant communicates the sad intelligence, with such small details as I was able to compress…
2. **No. 305 The Ambassador in Iran ( Henderson ) to the Department of State** — Tehran , February 25, 1953—11 p.m.  
   `frus1952-54v10/d305` · score 0.5462  
   > The Ambassador in Iran ( Henderson ) to the Department of State Also sent to London. top secret niact Tehran , February 25, 1953—11 p.m. 3393. Noforn . 1. Ala Minister Court came to see me tonight, obviously worried and distressed. Said he wanted to talk in utmost secrecy. During conversation…
3. ****  
   `frus1977-80v11p1/d326` · score 0.5437  
   > Editorial Note On July 27, 1980, the former Shah of Iran, Mohammed Reza Pahlavi , died in Cairo. The Department of State issued a press statement conforming to its final draft. See Document 308 . The press statement is in Department of State Bulletin , September 1980, page 55. President Anwar Sadat…
4. **No. 308 The Ambassador in Iran ( Henderson ) to the Department of State** — Tehran , February 28, 1953—5 p.m.  
   `frus1952-54v10/d308` · score 0.5216  
   > The Ambassador in Iran ( Henderson ) to the Department of State Transmitted in four sections; also sent to London, Baghdad, Ankara, and Dhahran. top secret niact Tehran , February 28, 1953—5 p.m. 3449. Early this morning stories regarding imminent departure Shah pouring in from many sources. These…
5. **393. Despatch From the Embassy in Iran to the Department of State** — Tehran , March 11, 1957 .  
   `frus1955-57v12/d393` · score 0.5186  
   > REF Embdes 736, December 20, 1951 Not printed. ( Ibid., 788.11/12–2051) SUBJECT The Shah of Iran, 1957—A Revised Study Enclosed is a memorandum entitled The Shah of Iran , 1957—A Revised Study, prepared by Second Secretary Thomas A. Cassilly before his recent transfer from this post. Mr. Cassilly…
6. **The Ambassador in Iran ( Murray ) to the Secretary of State** — Tehran , June 26, 1945—9 a.m. [Received June 26—6:35 a.m.]  
   `frus1945v08/d349` · score 0.5159  
   > Dept’s instruction of Feb 28, 1945. Not printed. In view of unavoidable delay in reporting sooner by written despatch on the delivery to the Shah on June 5 last of my letters of credence and the audience I had with him following the ceremonies of presentation, I believe the Dept may be interested…
7. **161. Telegram From the Embassy in Iran to the Department of State** — Tehran , February 25, 1953, 11 p.m.  
   `frus1951-54IranEd2/d161` · score 0.5075  
   > Ala Minister Court came to see me tonight, obviously worried and distressed. Said he wanted to talk in utmost secrecy. During conversation between Shah and Mosadeq on February 24, latter had indicated that it might be good idea after all for Shah leave country as soon as possible and to remain…
8. **161. Telegram From the Embassy in Iran to the Department of State** — Tehran , February 25, 1953, 11 p.m .  
   `frus1951-54Iran/d161` · score 0.5072  
   > Ala Minister Court came to see me tonight, obviously worried and distressed. Said he wanted to talk in utmost secrecy. During conversation between Shah and Mosadeq on February 24, latter had indicated that it might be good idea after all for Shah leave country as soon as possible and to remain…
9. **The Chargé in Iran ( Somerville ) to the Secretary of State** — Tehran , February 14, 1949—3 p. m.  
   `frus1949v06/d269` · score 0.5070  
   > secret Tehran , February 14, 1949—3 p. m. 161. During audience which I had yesterday with Shah he commented at some length on crisis precipitated by attempt on his life and gave evidence of determination meet situation. He said, “We have some problems here which we must resolve and finish.” He…
10. **No. 301 The Ambassador in Iran ( Henderson ) to the Department of State** — Tehran , February 22, 1953—2 p.m.  
   `frus1952-54v10/d301` · score 0.5069  
   > The Ambassador in Iran ( Henderson ) to the Department of State Transmitted in three sections; also sent to London. top secret priority Tehran , February 22, 1953—2 p.m. 3334. 1. Ala , Minister of Court, asked see me this morning. He said he wished discuss “most serious recent development”. On…

*Route overlap: 2 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 4/10.*
*document variant:* frus1896/d386, frus1977-80v11p1/d326, frus1952-54v10/d305, frus1952-54v10/d308, frus1951-54Iran/d166, frus1951-54IranEd2/d166, frus1951-54IranEd2/d161, frus1951-54Iran/d161, frus1949v06/d268, frus1977-80v11p1/d219
*bare variant:* frus1896/d386, frus1977-80v11p1/d326, frus1910/d932, frus1910/d609, frus1885/d569, frus1910/d930, frus1952-54v10/d308, frus1952-54v10/d305, frus1910/d603, frus1910/d898

---

## Q13. Diego Garcia base

### Lexical — `"diego" AND "garcia" AND "base"`

1. **46. Memorandum From Secretary of Defense McNamara to the Secretary of the Navy ( Ignatius )** — Washington , October 27, 1967 .  
   `frus1964-68v21/d46` · score -27.0533  
   > SUBJECT Austere Support Facility on Diego Garcia (S) Last February the Navy sent forward a proposal to construct a $26 million “austere” support facility on Diego Garcia, whether or not the British participate in its funding and use, because there would be money advantages to refueling carriers…
2. **86. Minutes of the Secretary of State’s Staff Regional Staff Meeting** — Washington , April 25, 1975, 8 a.m.  
   `frus1969-76ve08/d86` · score -26.1665  
   > The Secretary and his principal staff members discussed the Soviet position on the Indian Ocean, the Soviet base at Berbera, and Diego Garcia in relation to international initiatives to remove bases from the Indian Ocean. Washington , April 25, 1975, 8 a.m. PRESENT: THE SECRETARY OF STATE— HENRY A.…
3. **65. Memorandum From the Deputy Assistant Secretary of Defense for European and NATO Affairs ( Bergold ) to the Deputy Assistant Secretary of Defense for Security Assistance ( Peet )** — Washington , January 17, 1974 .  
   `frus1969-76ve08/d65` · score -25.5635  
   > Assistant Secretary Harold Bergold informed Vice Admiral Ray Peet of the British response to the United States’ Diego Garcia expansion proposal. Washington , January 17, 1974 . SUBJECT: Diego Garcia (S) John Wilberforce of the British Embassy came into State this afternoon to give the UK answer on…
4. **87. Minutes of the Senior Review Group Meeting** — Washington , May 6, 1975, 4:16–5:04 p.m.  
   `frus1969-76ve08/d87` · score -25.5264  
   > The Senior Review Group met to formulate a policy on the Indian Ocean and Diego Garcia based on the study conclusions from NSSM 199. Washington , May 6, 1975, 4:16–5:04 p.m. Subject: Indian Ocean Participants: Chairman: Henry A. Kissinger State: Robert Ingersoll Helmut Sonnenfeldt George Vest Tom…
5. **126. Memorandum From Secretary of Defense Brown to Secretary of State Vance and the President’s Assistant for National Security Affairs ( Brzezinski )** — Washington , November 3, 1979  
   `frus1977-80v18/d126` · score -25.2142  
   > SUBJECT Diego Garcia You will recall our discussion at lunch on October 25 of further upgrading of the facilities at Diego Garcia. At the Vance - Brown - Brzezinski luncheon on October 25, the principals decided that a tentative go-ahead for upgrading would be given; the Department of Defense was…
6. **69. Memorandum From Secretary of State Kissinger to President Nixon** — Washington , February 25, 1974 .  
   `frus1969-76ve08/d69` · score -24.9644  
   > Secretary of State Kissinger provided President Nixon with a draft reply to Prime Minister Bandaranaike ’s letter of February 11 regarding Diego Garcia. Washington , February 25, 1974 . SUBJECT: Reply to Letter from Sri Lanka Prime Minister At Tab B is a letter to you from Prime Minister…
7. **89. Memorandum of Conversation** — Washington , July 16, 1975, 11 a.m.  
   `frus1969-76ve08/d89` · score -24.7029  
   > Secretary of Defense James Schlesinger briefed the President about recent developments regarding Berbera and the status of Diego Garcia funding in Congress. Washington , July 16, 1975, 11 a.m. SUBJECT: President’s Meeting with the Cabinet [Omitted here is material unrelated to Diego Garcia.]…
8. **129. Briefing Memorandum From the Director of the Bureau of Politico-Military Affairs ( Bartholomew ) to Secretary of State Muskie** — Washington , June 30, 1980  
   `frus1977-80v18/d129` · score -24.6590  
   > Diego Garcia In Ankara, my British counterpart and I formalized a new side understanding (to the 1976 US – UK Agreement) See footnote 3, Document 126 . on the use of Diego Garcia (attached). Attached but not printed is a June 13 memorandum of conversation detailing Bartholomew ’s discussions with…
9. **47. Memorandum From the Joint Chiefs of Staff to Secretary of Defense McNamara** — Washington , April 10, 1968 .  
   `frus1964-68v21/d47` · score -24.4753  
   > SUBJECT Proposal for a Joint US Military Facility on Diego Garcia (U) JCSM -226-68 1. (S) Reference is made to: a. JCSM -420-67, dated 25 July 1967, subject: “Proposed Naval Facility on Diego Garcia (S),” Document 45 . which recommended funding the first increment of construction ($13 million) in…
10. **40. Memorandum From the Assistant Secretary of Defense for International Security Affairs ( Nutter ) to Secretary of Defense Laird** — Washington , March 17, 1970 .  
   `frus1969-76v24/d40` · score -24.3901  
   > SUBJECT Diego Garcia I–21269/70 The purpose of this memorandum is to identify precisely the nature of your decision regarding the proposed US communications facility on Diego Garcia. Although the attached Navy recommendation Not attached. The proposal is in a memorandum from Chafee to Laird ,…

### Semantic (query prompt)

1. **39. Paper Prepared in the Office of the Chief of Naval Operations ( Moorer )** — Washington , February 11, 1970 .  
   `frus1969-76v24/d39` · score 0.5916  
   > Diego Garcia—Background and Status The Navy has long recognized the strategic importance of gaining a modest logistics support capability in the Indian Ocean. In recognition of this need a Navy Strategic Island Concept was developed in 1959 and approved by JCS in 1960. In essence it calls for a…
2. **46. Memorandum From Secretary of Defense McNamara to the Secretary of the Navy ( Ignatius )** — Washington , October 27, 1967 .  
   `frus1964-68v21/d46` · score 0.5770  
   > SUBJECT Austere Support Facility on Diego Garcia (S) Last February the Navy sent forward a proposal to construct a $26 million “austere” support facility on Diego Garcia, whether or not the British participate in its funding and use, because there would be money advantages to refueling carriers…
3. **57. Telegram 118250 From the Department of State to the Embassy in the United Kingdom** — Washington , June 18, 1973, 1946Z .  
   `frus1969-76ve08/d57` · score 0.5656  
   > The Department discussed the decision to shut down the post at Kagnew Station in Asmara, Ethiopia, and create a communications station and naval facility at Diego Garcia. Washington , June 18, 1973, 1946Z . Subj: Diego Garcia 1. DOD budget constraints led to decision in February 1972 to reduce…
4. **37. Memorandum From the Assistant Secretary of State for Near Eastern and South Asian Affairs ( Sisco ) to Secretary of State Rogers** — Washington , June 24, 1969 .  
   `frus1969-76v24/d37` · score 0.5646  
   > SUBJECT Congressional Hearings on Diego Garcia Information Memorandum Representatives of the Defense Department will testify before the House Armed Services Committee on June 30 regarding plans to construct communications and refueling facilities on the island of Diego Garcia in the Chagos…
5. **65. Memorandum From the Deputy Assistant Secretary of Defense for European and NATO Affairs ( Bergold ) to the Deputy Assistant Secretary of Defense for Security Assistance ( Peet )** — Washington , January 17, 1974 .  
   `frus1969-76ve08/d65` · score 0.5584  
   > Assistant Secretary Harold Bergold informed Vice Admiral Ray Peet of the British response to the United States’ Diego Garcia expansion proposal. Washington , January 17, 1974 . SUBJECT: Diego Garcia (S) John Wilberforce of the British Embassy came into State this afternoon to give the UK answer on…
6. **40. Memorandum From the Assistant Secretary of Defense for International Security Affairs ( Nutter ) to Secretary of Defense Laird** — Washington , March 17, 1970 .  
   `frus1969-76v24/d40` · score 0.5521  
   > SUBJECT Diego Garcia I–21269/70 The purpose of this memorandum is to identify precisely the nature of your decision regarding the proposed US communications facility on Diego Garcia. Although the attached Navy recommendation Not attached. The proposal is in a memorandum from Chafee to Laird ,…
7. **126. Memorandum From Secretary of Defense Brown to Secretary of State Vance and the President’s Assistant for National Security Affairs ( Brzezinski )** — Washington , November 3, 1979  
   `frus1977-80v18/d126` · score 0.5515  
   > SUBJECT Diego Garcia You will recall our discussion at lunch on October 25 of further upgrading of the facilities at Diego Garcia. At the Vance - Brown - Brzezinski luncheon on October 25, the principals decided that a tentative go-ahead for upgrading would be given; the Department of Defense was…
8. **44. Memorandum From the Secretary of the Navy ( Nitze ) to Secretary of Defense McNamara** — Washington , February 24, 1967 .  
   `frus1964-68v21/d44` · score 0.5480  
   > Ser 001653 Washington , February 24, 1967 . SUBJECT Proposed Limited Support Facility on Diego Garcia (S) 1. I believe we should reconsider the decision made last fall that approval for the proposed limited support facility at Diego Garcia would depend on substantial British participation and…
9. **129. Briefing Memorandum From the Director of the Bureau of Politico-Military Affairs ( Bartholomew ) to Secretary of State Muskie** — Washington , June 30, 1980  
   `frus1977-80v18/d129` · score 0.5479  
   > Diego Garcia In Ankara, my British counterpart and I formalized a new side understanding (to the 1976 US – UK Agreement) See footnote 3, Document 126 . on the use of Diego Garcia (attached). Attached but not printed is a June 13 memorandum of conversation detailing Bartholomew ’s discussions with…
10. **48. Memorandum From the Deputy Secretary of Defense ( Nitze )** — Washington , June 15, 1968 .  
   `frus1964-68v21/d48` · score 0.5441  
   > MEMORANDUM FOR Chairman, Joint Chiefs of Staff Secretary of the Navy Assistant Secretary of Defense (ISA) SUBJECT Proposal for a Joint US Military Facility on Diego Garcia (U) A JCS memorandum dated 10 April 1968 Document 47 . proposed the establishment of a $44 million joint military facility on…

*Route overlap: 5 of 10 shared. Prompt variants vs primary — document: 9/10, bare: 5/10.*
*document variant:* frus1964-68v21/d46, frus1969-76v24/d37, frus1969-76v24/d39, frus1977-80v18/d126, frus1969-76ve08/d57, frus1977-80v18/d129, frus1969-76v24/d40, frus1964-68v21/d44, frus1969-76v41/d273, frus1969-76ve08/d65
*bare variant:* frus1964-68v21/d46, frus1969-76v41/d273, frus1969-76ve08/d57, frus1969-76v24/d37, frus1964-68v12/d207, frus1969-76v24/d40, frus1969-76v24/d39, frus1948v09/d178, frus1969-76v41/d290, frus1969-76ve15p2/d229

---

## Q14. Space aliens
*null control*

### Lexical — `"space" AND "aliens"`

1. **The Consul General at Shanghai ( Cabot ) to the Secretary of State** — Shanghai , December 13, 1948—midnight . [Received December 14—1:57 p.m.]  
   `frus1948v08/d858` · score -14.5506  
   > ReEmbtel 1231, December 9, Sent to the Department as telegram No. 2469, p. 924 . evacuation foreign nationals. Statement mytel 1990 Sent to the Department as telegram No. 2637, December 3, 8 p.m., p. 913 . that Navy may be unable help other foreign communities even in emergency based on statement…
2. **The Secretary of State to the Consul General at Rangoon ( Schnare )** — Washington , February 4, 1942—9 p.m.  
   `frus1942v01/d192` · score -14.4256  
   > Your 106, January 31, 1 p.m. Extra space made available by emergency consular certificates issued under discretionary authority given you by Department’s 51, December 20, may be utilized only for American citizens and their accompanying alien spouses and unmarried minor alien children properly…
3. **The Ambassador in the United Kingdom ( Kennedy ) to the Secretary of State** — London , October 3, 1939—8 p.m. [Received October 3—6:15 p.m.]  
   `frus1939v01/d661` · score -13.8348  
   > Your 1131, September 30. We have been looking into the charges of alleged discrimination against American citizens on American vessels and we are inclined to believe that there is no basis for this accusation. It has been the policy of this Embassy and of the United States Lines throughout the…
4. **The Ambassador in China ( Stuart ) to the Secretary of State** — Nanking , December 9, 1948 . [Received December 9—8:23 a.m.]  
   `frus1948v08/d847` · score -13.8109  
   > Evacuation policy as agreed upon by Department, Embassy, and Naval authorities has been that foreign nationals would be accorded facilities on space available basis. Inquiries from foreign diplomatic representatives have been uniformly answered in this sense and this policy has been followed in…
5. **The Acting Secretary of State to Certain Diplomatic and Consular Officers** — Washington , February 20, 1942—10 p.m.  
   `frus1942v01/d199` · score -13.7153  
   > Sent to diplomatic officers at London, with instructions to repeat to all seaport consular offices in the British Isles; Cairo (to repeat to Alexandria, Port Said, and Suez); Reykjavik; Monrovia; and to consular officers at Aden; Basra; Batavia (to repeat to Surabaya); Belfast; Calcutta (to repeat…
6. **Extract from the Constitution of May 23, 1845.** — [ May 23, 1845 .]  
   `frus1873p1v2/d217` · score -13.0084  
   > Part I.—Article I . “Spaniards are— “1. All persons born within the dominions of Spain. “2. The children of a Spanish father and mother, though born out of the dominions of Spain. “3. Aliens who have obtained a certificate of naturalization. “4. Those who, without having obtained such certificate,…
7. **The Minister in Switzerland ( Harrison ) to the Secretary of State** — Bern , June 25, 1943 . [Received June 25—6:26 p.m.]  
   `frus1943v03/d732` · score -12.7536  
   > American interests Far East, repatriation. Department’s 1311, 2d, and 1333, 4th. Department’s telegrams under reference transmitted Swiss Legation, Tokyo, which replied that in its opinion geographic allotment space described Legation’s 5751, December 8 Not printed; it transmitted allocations…
8. **383. Memorandum From Maxwell W. Hunter II of the National Aeronautics and Space Council to Robert F. Packard of the Office of International Scientific Affairs** — Washington , July 18, 1963 .  
   `frus1961-63v25/d383` · score -12.6149  
   > SUBJECT Thoughts on the Space Alien Race Question During recent discussions the question has occasionally, though rarely, arisen that perhaps we should consider the policy question of what to do if an alien intelligence is discovered in space. Some discussion of this occurred, as you will recall,…
9. **The Assistant Secretary of Labor ( White ) to the Assistant Secretary of State ( Carr )** — Washington , April 22, 1927 .  
   `frus1927v01/d360` · score -12.0211  
   > My Dear Mr. Carr : Enclosed find copy of General Order No. 86, outlining land border crossing procedure, which may be of interest to your Department, particularly, as it may greatly increase the applications for non-quota visas at some of your consulates. I am informed this phase of the question…
10. **Bear Admiral C. W. Styer , of the Office of Chief of Naval Operations, to the Director of the Office of Far Eastern Affairs ( Butterworth )** — Washington , 8 January 1948 .  
   `frus1948v08/d257` · score -12.0207  
   > Ser: 004P35 (SC) A14–7/EF16 Washington , 8 January 1948 . My Dear Mr. Butterworth : The following information is submitted in response to your letter of 26 December 1947, (Paragraph numbers correspond):– 1. The Joint Chiefs of Staff in August 1945 charged the Commanding General, China, with…

### Semantic (query prompt)

1. **383. Memorandum From Maxwell W. Hunter II of the National Aeronautics and Space Council to Robert F. Packard of the Office of International Scientific Affairs** — Washington , July 18, 1963 .  
   `frus1961-63v25/d383` · score 0.5960  
   > SUBJECT Thoughts on the Space Alien Race Question During recent discussions the question has occasionally, though rarely, arisen that perhaps we should consider the policy question of what to do if an alien intelligence is discovered in space. Some discussion of this occurred, as you will recall,…
2. **479. Report by the National Aeronautics and Space Council** — Washington , January 26, 1960 .  
   `frus1958-60v02/d479` · score 0.4777  
   > On December 17, 1959, the National Aeronautics and Space Council transmitted a draft of this report to the National Security Council. Designated NSC 5918, it was considered by the Council at its 321st meeting on January 12, 1960, and minor revisions and deletions were made. A copy of NSC 5918 is…
3. **145. Memorandum From the Executive Secretary of the Department of State ( Read ) to the President’s Special Assistant ( Rostow )** — Washington , August 10, 1966 .  
   `frus1964-68v11/d145` · score 0.4763  
   > SUBJECT Negotiation of an Outer Space Treaty Background —On May 7, President Johnson asked Ambassador Goldberg to undertake the negotiation of a treaty governing the uses of celestial bodies. See Document 127 . After some initial private conversations, and a letter from Gromyko to U Thant which…
4. **442. National Security Council Report** — Washington , August 18, 1958 .  
   `frus1958-60v02/d442` · score 0.4748  
   > NSC 5814/1 STATEMENT OF PRELIMINARY U.S. POLICY ON OUTER SPACE Introductory Note The USSR has surpassed the United States and the Free World in scientific and technological accomplishments in outer space, which have captured the imagination and admiration of the world. The USSR , if it maintains…
5. **365. Memorandum of Conversation** — Washington , May 19, 1961 .  
   `frus1961-63v25/d365` · score 0.4692  
   > SUBJECT United Nations Outer Space Committee and Conference PARTICIPANTS Dr. Hugh Dryden , NASA Dr. John P. Hagen , NASA Mr. Arnold Frutkin , NASA Mr. Philip Farley , S/AE Mr. Wreatham Gathright , S/AE Mr. Herbert Reis , L/UNA Ambassador Plimpton , USUN Mr. Peter Thatcher , USUN Mr. Harlan…
6. **430. Memorandum From the Deputy Legal Adviser of the Department of State ( Meeker ) to Secretary of State Rusk** — Washington , October 8, 1963 .  
   `frus1961-63v25/d430` · score 0.4682  
   > SUBJECT Status of Discussions with Soviets on Outer Space Legal Questions In the last two weeks, we have had five meetings with the Soviet Delegation in New York to discuss outer space legal questions, on which previously no progress had been made in the United Nations because of Soviet…
7. **265. Airgram A-420 From the Embassy in the Soviet Union to the Department of State** — Moscow , May 20, 1971 .  
   `frus1969-76ve01/d265` · score 0.4620  
   > Assessing U.S.- USSR space cooperation in the historical context, the Embassy concluded that the Soviets were after specific technical information and were not interested in genuine cooperation. Moscow , May 20, 1971 . SUBJECT : Soviet Space Effort REF: Department’s A-32, 3/12/72 (Collection…
8. **463. Telegram From the Department of State to the Mission at the United Nations** — Washington , November 6, 1959—7:02 p.m.  
   `frus1958-60v02/d463` · score 0.4597  
   > Gadel 93. Re Outer Space (Delgas 326, 327, 340). Delga 326 is supra ; regarding Delgas 327 and 340, see footnotes 2 and 3 , supra . Pending receipt from Kuznetsov of specific comments on our text, Department transmits following interim guidance: 1. Our impression is that Soviets wish separate…
9. **43. Letter From Chairman Khrushchev to President Kennedy** — Moscow , March 20, 1962 .  
   `frus1961-63v06/d43` · score 0.4596  
   > Dear Mr. President : Having carefully familiarized myself with your message of March 7 Document 41 . of this year, I note with satisfaction that my communication to you of February 21 Document 35 . containing the proposal that our two countries unite their efforts for the conquest of space has met…
10. **55. Department of State Policy Paper** — Washington , October 1966 .  
   `frus1964-68v34/d55` · score 0.4583  
   > SPACE GOALS AFTER THE LUNAR LANDING Summary Even before the outcome of the moon race has been decided, we face the question of whether to commit ourselves to still more ambitious programs—proceeding with manned exploration of the moon after the initial landing; mounting large-scale scientific…

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 5/10, bare: 7/10.*
*document variant:* frus1961-63v25/d383, frus1958-60v02/d442, frus1873p1v2/d213, frus1961-63v25/d367, frus1964-68v11/d145, frus1964-68v34/d55, frus1961-63v25/d430, frus1964-68v11/d128, frus1958-60v02/d461, frus1873p1v2/d303
*bare variant:* frus1961-63v25/d383, frus1958-60v02/d479, frus1961-63v25/d367, frus1958-60v02/d442, frus1969-76ve01/d265, frus1964-68v34/d55, frus1964-68v11/d145, frus1961-63v25/d365, frus1958-60v03mSupp/d283, frus1961-63v25/d429

---

## Q15. U.S.S. Liberty sinking
*wrong-premise probe (the Liberty was attacked, not sunk)*

### Lexical — `"u.s.s." AND "liberty" AND "sinking"`

1. **The Ambassador in Japan ( Grew ) to the Secretary of State** — Tokyo , September 29, 1941—noon . [Received 2:25 p.m.]  
   `frus1941v04/d359` · score -9.2217  
   > For the Secretary and Under Secretary only. 1. A review of our exchange of confidential telegrams since last spring pertaining to the preliminary conversations in Washington and Tokyo reveals the steadily increasing and latterly intensified efforts of Japanese Government to bring about without…
2. **Joint Chiefs of Staff Minutes** — Potsdam , July 24, 1945, 2:30 p.m.  
   `frus1945Berlinv02/d710a-90` · score -6.3305  
   > The papers of the Joint Chiefs of Staff indicate that “These Minutes were transcribed from notes taken by the United States Secretaries, Combined Chiefs of Staff.” Potsdam , July 24, 1945, 2:30 p.m. top secret General of the Army Antonov asked Fleet Admiral Leahy to preside at this, the first…
3. **United States Delegation Record, Council of Foreign Ministers, Second Session, Third Meeting, Paris, April 27, 1946, 4 p.m.** — Paris , April 27, 1946, 4 p.m.  
   `frus1946v02/d76` · score -6.0524  
   > For a list of persons present at this meeting, see the Record of Decisions, infra . Paris , April 27, 1946, 4 p.m. secret M. Molotov called upon the Chairman of the Deputies’ Meeting to present the Deputies’ report. Report of the Deputies Mr. Jebb stated that the Deputies proposed that the agenda…
4. **Verbatim Record** — July 30, 1946, 4 p.m.  
   `frus1946v03/d18` · score -4.5586  
   > C.P.(Plen) 2 Chairman: M. Bidault (France) The Chairman : The list of speakers is as follows: the first Delegate of the United States of America, the first Delegate of the United Kingdom, and the first Delegate of the Republic of China. After that we shall hear the report of the Credentials…
5. **Mr. Stevens to Mr. Blaine .** — United States Legation , Honolulu , June 9, 1890 .  
   `frus1894app2/d134` · score -4.5275  
   > Sir : I improve the first mail opportunity to forward two copies of the speech of Hon. L. A. Thurston, Minister of Interior, just delivered in the Hawaiian Legislature. It is a clear, strong statement of facts, as I had previously ascertained them by careful investigation, and these plainly…
6. **EXHIBIT V. Annex 1.** — [ December 7, 1891 to November 5, 1892 ]  
   `frus1902app1/d30` · score -4.2496  
   > [Bark Cape Horn Pigeon —Log book. Season of 1892. Thomas Scullen, master.] Monday, December 7. —At 1.30 p.m. hove up anchor, and tug Sea Witch towed us out to Whising Buoy. At 3.30 tug let go, wind NE., ship steering SW. by S. All sail set at 6 p.m. Farallon light, bearing NW., distant 20 miles.…
7. **Thompson Minutes** — Potsdam , July 19, 1945, 5 p.m.  
   `frus1945Berlinv02/d710a-28` · score -4.1159  
   > top secret Bulgarian–Greek Frontier Incident Mr. Churchill said he wished to refer to a point which Stalin had raised at the previous meeting concerning an incident on the Bulgarian-Greek frontier. He had made inquiries. The British Government had heard of no fighting. These people did not like…
8. **Minister Dawson to the President .** — Washington , July 1, 1905 .  
   `frus1905/d345` · score -3.9559  
   > memorandum on the dominican modus vivendi, its effects up to the present time, and the reasons that lead to its adoption. The financial modus vivendi put into effect April 1 by a decree of the Dominican Government was the natural outcome of the situation—the logical development from what had gone…
9. **Report of the Special Representative of the United States Government ( House )**  
   `frus1917Supp02v01/d370` · score -2.6403  
   > This and the following reports, which were submitted to Colonel House , pp. 334 – 445 , comprise the report of the American War Mission to England and France, November, 1917. The mission was composed of the following: Edward M. House , Special Representative of the United States Government; In the…
10. **210. Letter From the President’s Military Representative ( Taylor ) to the President** — Washington , November 3, 1961 .  
   `frus1961-63v01/d210` · score -1.2266  
   > This letter and its attachments are in a binder entitled “Report on General Taylor ’s Mission to South Vietnam, 3 November 1961,” which also includes a table of contents. The source text is Tab A. At 4 p.m. on November 3, the President greeted at the White House all the returning members of the…

### Semantic (query prompt)

1. **219. Memorandum for the Record** — Washington , June 8, 1967, 3:30 p.m.  
   `frus1964-68v19/d219` · score 0.5829  
   > SUBJECT The USS Liberty (AGTR–5) Struck by Torpedo 1. At 080911 EDT June, USCINCEUR notified the NMCC by phone that the USS Liberty was under attack, had been hit by a torpedo and was listing to starboard. The ship was operating in the Mediterranean Sea approximately 60–70 miles east-northeast of…
2. ****  
   `frus1964-68v19/d204` · score 0.5591  
   > Editorial Note On June 8, 1967, at 8:03 a.m. Eastern Daylight Time (1203Z; p.m. local time), the U.S.S. Liberty was attacked and hit by unidentified jet fighters, which made six strafing runs. Twenty minutes later the ship was attacked by three torpedo boats. One torpedo hit the starboard side. At…
3. **284. Intelligence Memorandum Prepared in the Central Intelligence Agency** — Washington , June 13, 1967 .  
   `frus1964-68v19/d284` · score 0.5531  
   > SC No. 01415/67 Washington , June 13, 1967 . THE ISRAELI ATTACK ON THE USS LIBERTY The US Naval technical research ship Liberty was attacked by Israeli aircraft and torpedo boats off the Sinai Peninsula on 8 June. The following account of the circumstances of the attack has been compiled from all…
4. **234. Memorandum for the Record** — Washington , June 9, 1967, 3:26 p.m.  
   `frus1964-68v19/d234` · score 0.5474  
   > SUBJECT Attack on USS Liberty (AGTR–5) 1. This memorandum updates and supplements memoranda, same subject, of 1530 EDT 8 June and 0600 EDT 9 June 1967. Document 219 ; the June 9 memorandum was not found. 2. USS Liberty had been directed by JCS to proceed to 32–00N; 33–00E, a point 39 nautical miles…
5. **373. Memorandum From the Chairman of the President’s Foreign Intelligence Advisory Board ( Clifford ) to the President’s Special Assistant ( Rostow )** — Washington , July 18, 1967 .  
   `frus1964-68v19/d373` · score 0.5451  
   > SC No. 07445/67 Washington , July 18, 1967 . SUBJECT The Israeli Attack on the USS Liberty In accordance with your request, I have reviewed all available information on the subject. Based thereon, I submit the enclosed memorandum which deals with the question of Israeli culpability. In the event…
6. **The Ambassador in Austria-Hungary ( Penfield ) to the Secretary of State** — Vienna , December 29, 1915,7 p. m. [ Received December 30, 3.50 p. m. ]  
   `frus1915Supp/d909` · score 0.5374  
   > The following reply to my note of the 21st instant, communicating textually the contents of the Department’s telegram No. 1039 of December 19, 1 p. m., Ante , p. 647 . was received this afternoon: In reply to the very esteemed note No. 4307, of the 21st instant, the undersigned has the honor most…
7. **The Chargé in Germany ( Grew ) to the Secretary of State** — Berlin , December 17, 1916 . [ Received December 21, 10.45 a. m. ]  
   `frus1916Supp/d438` · score 0.5340  
   > The following note relative to the sinking of the Columbian has just been received: The undersigned has the honor to make the following reply to the note of Mr. Grew , Chargé d’Affaires of the United States of America, dated the 21st ultimo (Foreign Office No. 1442), relative to the sinking of the…
8. **352. Diplomatic Note From Secretary of State Rusk to the Israeli Ambassador ( Harman )** — Washington , June 10, 1967 .  
   `frus1964-68v19/d352` · score 0.5253  
   > The Secretary of State presents his compliments to His Excellency the Ambassador of Israel and has the honor to refer to the Ambassador’s Note of June 10, 1967 concerning the attacks by Israeli aircraft and torpedo boats on the United States naval vessel U.S.S. Liberty , which were carried out…
9. **The Ambassador in Germany ( Gerard ) to the Secretary of State** — Berlin , May 29, 1915, 7 p. m. [ Received May 31, 1.30 a. m. ]  
   `frus1915Supp/d615` · score 0.5250  
   > The following is the text of the reply of the German Government to the Lusitania note, which I am informed will be published here Monday: Berlin , May 28, 1915. The undersigned has the honor to make the following reply to the note of his excellency, Mr. James W. Gerard , Ambassador of the United…
10. **The Consul at Amsterdam ( Mahin ) to the Secretary of State** — Amsterdam , March 23, 1917 . [ Received 6 p.m. ]  
   `frus1917Supp01v01/d214` · score 0.5238  
   > Supplementing telegram 22d, Healdton lights showed name and American flag painted on sides, also flag flying at stern; two torpedoes, one entered amidships at name, other at flag; ship sank in few minutes, three boats lowered, one capsized, drowning occupants; one with 8 reached northern Holland, 1…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 4/10.*
*document variant:* frus1964-68v19/d204, frus1964-68v19/d219, frus1964-68v19/d284, frus1917Supp01v01/d214, frus1916Supp/d411, frus1917Supp01v01/d207, frus1915Supp/d909, frus1915Supp/d615, frus1916Supp/d402, frus1915Supp/d632
*bare variant:* frus1915Supp/d909, frus1916Supp/d438, frus1916Supp/d308, frus1917Supp01v01/d214, frus1914-20v01/d328, frus1917Supp01v01/d156, frus1916Supp/d414, frus1915Supp/d615, frus1917Supp01v01/d207, frus1915Supp/d632

---

## Q16. How did Kissinger manage the State Department?

### Lexical — `"how" AND "did" AND "kissinger" AND "manage" AND "the" AND "state" AND "department?"`

1. **90. Minutes of Secretary of State Kissinger ’s Regional Staff Meeting** — Washington , July 1, 1976 .  
   `frus1969-76v35/d90` · score -14.9622  
   > [Omitted here is discussion unrelated to national security policy.] Secretary Kissinger : Well, this just can’t be bought off. We have to fight it. We cannot buy off. The question is whether human rights is the only objective of American foreign policy, and that’s what it’s rapidly coming down to.…
2. **139. Memorandum of Conversation** — Washington , October 7, 1974, 10:30 a.m.  
   `frus1969-76v38p2/d139` · score -13.7884  
   > PARTICIPANTS Henry A. Kissinger , Secretary of State Robert S. Ingersoll , Deputy Secretary of State Joseph J. Sisco , Under Secretary for Political Affairs L. Dean Brown , Deputy Under Secretary for Management Arthur A. Hartman , Assistant Secretary for European Affairs Nathaniel Davis , Director…
3. **11. Minutes of the Secretary of State’s Staff Meeting** — Washington , October 22, 1974, 9–10:10 a.m.  
   `frus1969-76v37/d11` · score -13.5475  
   > Secretary Kissinger : Tom. Mr. Enders : As I reported to you, the French have political objections to going ahead at an official level in the Camp David follow-up. See Document 10 . These objections may prove to be less firm than they are right at the moment, if we proceed with floating our ideas…
4. **42. Memorandum of Conversation** — Washington , August 13, 1974 .  
   `frus1969-76v38p1/d42` · score -13.5238  
   > SUBJECT Highlights of Secretary Kissinger ’s OFF THE RECORD Breakfast with Time, Inc. , Madison Room, Department of State, August 13, 1974. Present at the breakfast were Henry A. Kissinger , Secretary of State Hedley Donovan, Editor-in-Chief Henry Grunwald, Managing Editor Murray Gart, Assistant…
5. **86. Minutes of Secretary of State Kissinger ’s Principals and Regionals Staff Meeting** — Washington , June 27, 1975 .  
   `frus1969-76v22/d86` · score -13.2243  
   > [ Omitted here are a list of attendees and discussion of unrelated matters. ] Mr. Rogers: Torrijos ’ response to the press yesterday was tempered. On June 27, Panamanian newspapers reported that Torrijos remained confident that the “United States would live up to its commitment to negotiate”…
6. **350. Memorandum of Conversation** — Washington , November 21, 1973 .  
   `frus1969-76v25/d350` · score -13.1649  
   > SUBJECT Meeting Between the Secretary and Syrian UN Permanent Representative Kaylani PARTICIPANTS Haytham Kaylani , Syrian Permanent Representative to the UN Diya’allah al-Bettal , Director, UN Department, Syrian Ministry of Foreign Affairs Henry A. Kissinger , Secretary of State Joseph J. Sisco ,…
7. **144. Memorandum of Conversation** — Washington , June 5, 1975, 6:30–7:30 p.m.  
   `frus1969-76v38p2/d144` · score -13.0187  
   > PARTICIPANTS Secretary Kissinger Deputy Secretary Ingersoll Ambassador Carol Laise , Director General Mr. Lawrence S. Eagleburger , Deputy Under Secretary for Management Mr. L.P. Bremer, Executive Assistant to the Secretary Mr. Wesley W. Egan, Jr., Notetaker SUBJECT “The Professional Service of the…
8. **230. Memorandum From the Assistant Director, Office of Management and Budget ( Schlesinger ) to the Director ( Shultz )** — Washington , May 11, 1971 .  
   `frus1969-76v02/d230` · score -12.9725  
   > SUBJECT Reorganizing the Intelligence Community This memorandum is intended to apprise you of the several responses within the intelligence community to the Overview paper, One of two attachments to Document 229 . which has been distributed on a highly selected basis. Copies went to the DCI , DOD ,…
9. **218. Memorandum of Conversation** — Washington , November 19, 1976, 3 p.m.  
   `frus1969-76v38p2/d218` · score -12.9302  
   > PARTICIPANTS Secretary Kissinger Deputy Secretary Robinson Under Secretary William Rogers Under Secretary Philip Habib Deputy Under Secretary for Management Eagleburger Mr. Winston Lord , Policy/Planning Staff General Scowcroft , Director— NSC Mr. Bill Hyland , NSC Jock Covey, notetaker SUBJECT…
10. **177. Minutes of Secretary of State Kissinger ’s Staff Meeting** — Washington , October 29, 1973, 3:15 p.m.  
   `frus1969-76v39/d177` · score -12.8682  
   > PRESENT The Secretary of State: Henry A. Kissinger Kenneth Rush William J. Porter Curtis W. Tarr Jack B. Kubisch Arthur W. Hummel, Jr. George S. Springsteen David D. Newsom Robert J. McCloskey Alfred L. Atherton George Aldrich Thomas R. Pickering Winston Lord Lawrence S. Eagleburger [Omitted here…

### Semantic (query prompt)

1. ****  
   `frus1969-76v38p2/d117` · score 0.7187  
   > Editorial Note Following President Nixon ’s inauguration for a second term on January 20, 1973, William P. Rogers remained as Secretary of State, but the President had already determined that Rogers ’ remaining tenure would be brief. Shortly after his re-election on November 7, 1972, President…
2. **139. Memorandum of Conversation** — Washington , October 7, 1974, 10:30 a.m.  
   `frus1969-76v38p2/d139` · score 0.6698  
   > PARTICIPANTS Henry A. Kissinger , Secretary of State Robert S. Ingersoll , Deputy Secretary of State Joseph J. Sisco , Under Secretary for Political Affairs L. Dean Brown , Deputy Under Secretary for Management Arthur A. Hartman , Assistant Secretary for European Affairs Nathaniel Davis , Director…
3. **137. Memorandum of Conversation** — Washington , September 27, 1974, 11:30 a.m.  
   `frus1969-76v38p2/d137` · score 0.6469  
   > PARTICIPANTS The Secretary The Deputy Secretary The Undersecretary for Political Affairs, Mr. Sisco Deputy Undersecretary, Ambassador Brown Director General, Ambassador Davis Assistant Secretary Hartman Mr. Eagleburger Jerry Bremer, Notetaker Kissinger : I just wanted to spend ten minutes with you…
4. ****  
   `frus1969-76v13/d95` · score 0.6345  
   > Editorial Note On January 14, 1971, Assistant to the President for National Security Affairs Henry Kissinger received a telephone call at 7:22 p.m. from Yuli Vorontsov , the Soviet Chargé d’Affaires. According to the transcript, the conversation included the following brief exchange: “V: Dr.…
5. **61. Transcript of Telephone Conversation Between the President’s Assistant for National Security Affairs ( Kissinger ) and Secretary of State Rogers** — Washington , March 16, 1972, 9:40 a.m.  
   `frus1969-76v14/d61` · score 0.6312  
   > R : Hi, Henry. K : Bill, you called me last night? R : Last night? No. K : I got a message that you called last night and you might call again this morning. R : No, I didn’t call you last night. But on this business about the Qs and As today on the Soviet Union trip, I am perfectly prepared to be…
6. ****  
   `frus1969-76v38p1/d53` · score 0.6268  
   > Editorial Note On March 31, 1975, Secretary of State Henry Kissinger met with Dean Rusk , Cyrus Vance , McGeorge Bundy , George Shultz , Douglas Dillon , W. Averell Harriman , Robert McNamara , David Rockefeller , George Ball , William Scranton , Peter G. Peterson , David K.E. Bruce , John McCloy ,…
7. **84. Interview With Secretary of State Kissinger** — Washington , undated .  
   `frus1969-76v38p1/d84` · score 0.6204  
   > Q. A number of serious charges have been made against you, and the Times thought you should have the opportunity to answer them. The first charge is that in a solemn world you tried to be funny. Secretary Kissinger : In this job you have only two choices: you are either funny deliberately or you…
8. **244. Minutes of the Secretary’s Staff Meeting** — Washington , October 22, 1974. 9 a.m.  
   `frus1969-76ve03/d244` · score 0.6162  
   > Kissinger discussed with key Department of State personnel the relationship of human rights issues to larger U.S. foreign policy goals. Washington , October 22, 1974. 9 a.m. The meeting was convened at 9:00 a.m., SECRETARY KISSINGER presiding. PRESENT: The Secretary of State— HENRY A. KISSINGER MR.…
9. ****  
   `frus1969-76v38p1/d16` · score 0.6161  
   > Editorial Note President Richard Nixon announced the resignation of Secretary of State William P. Rogers during an August 22, 1973, news conference at the Western White House in San Clemente, California. After praising Rogers as one of the “major architects” of his administration’s foreign policy,…
10. **132. Action Memorandum From the Assistant Secretary of State for Public Affairs ( Laise ) to Secretary of State Kissinger** — Washington , April 26, 1974 .  
   `frus1969-76v38p2/d132` · score 0.6142  
   > “Consensus” Begins at Home It is my perception that only a limited number of officers in the Department of State understand your view of the world, see how the parts of it for which they are responsible fit into the whole, and act accordingly. Moreover, some of those who do understand do not have…

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 6/10.*
*document variant:* frus1969-76v38p2/d117, frus1969-76v38p1/d84, frus1969-76v38p2/d139, frus1969-76v01/d80, frus1969-76v38p2/d137, frus1969-76v38p2/d218, frus1969-76v14/d61, frus1969-76v38p1/d25, frus1969-76v13/d95, frus1969-76v38p1/d53
*bare variant:* frus1969-76v38p2/d117, frus1969-76v38p2/d139, frus1969-76v38p2/d137, frus1969-76v38p1/d84, frus1964-68v33/d16, frus1969-76ve03/d244, frus1969-76v13/d95, frus1969-76v02/d297, frus1969-76v02/d123, frus1969-76ve06/d121

---

## Q17. What joke did Mao make about Chinese women?
*known-item*

### Lexical — `"what" AND "joke" AND "did" AND "mao" AND "make" AND "about" AND "chinese" AND "women?"`

1. **126. Memorandum of Conversation, Beijing, April 22, 1972, 4:30-8 p.m.** — Beijing , April 22, 1972, 4:30–8 p.m.  
   `frus1969-76ve13/d126` · score -13.7474  
   > Senators Mansfield and Scott and Chinese Premier Chou En-lai discussed the feasibility of neutralizing all of Indochina, how tensions on the Korean peninsula could be reduced, the state of negotiations between the Soviet Union and China on reducing border tensions, and the status of Cambodia.…

### Semantic (query prompt)

1. **86. Paper Prepared by the National Security Council Staff, Washington, undated** — Washington , undated  
   `frus1969-76ve13/d86` · score 0.5418  
   > The paper provided a summary of Chairman of the Communist Party of China Mao Tse-tung ’s major philosophical and political themes and offered a brief history of China since the Communists assumed power in 1949. Washington , undated MEMORANDUM February 15, 1972 MEMORANDUM FOR: THE PRESIDENT FROM:…
2. **12. Memorandum of Conversation** — Beijing , February 17–18, 1973, 11:30 p.m.–1:20 a.m.  
   `frus1969-76v18/d12` · score 0.5203  
   > PARTICIPANTS Mao Tsetung , Chairman, Politburo, Chinese Communist Party Chou En-lai , Premier of the State Council Wang Hai-jung , Assistant Minister of Foreign Affairs Tang Wen-sheng , Interpreter Shen Jo-yun , Interpreter Dr. Henry A. Kissinger , Assistant to the President for National Security…
3. **58. Memorandum of Conversation** — Beijing , November 12, 1973, 5:40–8:25 p.m.  
   `frus1969-76v18/d58` · score 0.5039  
   > PARTICIPANTS Chairman Mao Tse-tung Prime Minister Chou En-lai Foreign Minister Chi Peng-fei Assistant Minister of Foreign Affairs Wang Hai-jung Tang Wang-shen, Interpreter Shen Jo-yen, Interpreter Henry A. Kissinger , Secretary of State Ambassador David Bruce , Chief U.S. Liaison Office Winston…
4. **264. Memorandum From the Director of the Office of Chinese Affairs ( Clough ) to the Assistant Secretary of State for Far Eastern Affairs ( Robertson )** — Washington , June 20, 1957 .  
   `frus1955-57v03/d264` · score 0.5011  
   > SUBJECT Mao Tse-tung ’s Speech of February 27 “On the Correct Handling of Contradictions Among the People” For additional information on this speech, see Document 238 . An overall assessment of the speech, as released on June 18, was circulated in the Department on July 1 in an “Intelligence…
5. **193. Memorandum From the President’s Assistant for National Security Affairs ( Kissinger ) to President Nixon** — Washington , February 19, 1972 .  
   `frus1969-76v17/d193` · score 0.4913  
   > SUBJECT Mao, Chou and the Chinese Litmus Test The Litmus Test Over the long term, the intangibles of your China visit will prove more important than the tangible results. We should be able to leave the People’s Republic of China with a creditable public outcome—because of the advance work, the…
6. **124. Memorandum of Conversation** — Beijing , October 21, 1975, 6:25–8:05 p.m.  
   `frus1969-76v18/d124` · score 0.4745  
   > PARTICIPANTS Chairman Mao Tse-tung Teng Hsiao-p’ing , Vice Premier of the State Council of the People’s Republic of China Ch’iao Kuan-hua , Minister of Foreign Affairs Amb. Huang Chen , Chief of the PRC Liaison Office, Washington Wang Hai-jung, Vice Minister of Foreign Affairs T’ang Wen-sheng,…
7. **The Ambassador in China ( Stuart ) to the Secretary of State** — Nanking , July 6, 1949—1 p. m. [Received July 6—6:34 a. m.]  
   `frus1949v08/d478` · score 0.4675  
   > We owe to Mao Tse-tung vote of thanks for his article “On People’s Democratic Dictatorship” as an unprecedentedly clear exposition of just where top leadership of CCP stands. Here, etched in clean sharp lines, is plan of how “science of Marxism-Leninism” is to be applied to Chinese society. Here…
8. **Memorandum by Mr. Everett F. Drumright of the Division of Chinese Affairs** — [ Washington , May 1, 1945 .]  
   `frus1945v07/d248` · score 0.4612  
   > It seems clear that Mao Tse-tung’s report “On the Coalition Government” Supra . merits our close study. In this report, Mao continues the current Communist strategy which is to discredit the Kuomintang and, by contrast, to laud the achievements of his own regime. Pursuing the line of a despatch…
9. **Report by the Second Secretary of Embassy in China ( Service )** — [ Yenan ,] April 1, 1945 .  
   `frus1945v07/d224` · score 0.4602  
   > Received in the Department about April 27. No. 26 [ Yenan ,] April 1, 1945 . Attached is a memorandum of a conversation on this date with a group of Communist leaders: Mao Tse-tung, Chairman of the Central Committee; Chou En-lai, second ranking political leader and functioning “Foreign Minister”;…
10. **303. Paper Prepared by Alfred Jenkins of the National Security Council Staff** — Washington , February 22, 1968 .  
   `frus1964-68v30/d303` · score 0.4583  
   > THOUGHTS ON CHINA Prologue to the Present The Present Predicament The Most Probable Future Relations with Others The term “madness” has been applied to the present climate in Peking. In some ways it is not inappropriate. But to a Chinese, because of the historical prologue to the present and…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 8/10.*
*document variant:* frus1969-76ve13/d86, frus1969-76v18/d12, frus1969-76v18/d58, frus1969-76v17/d193, frus1964-68v30/d303, frus1955-57v03/d264, frus1969-76v17/d11, frus1949v08/d485, frus1964-68v30/d160, frus1945v07/d224
*bare variant:* frus1969-76ve13/d86, frus1969-76v18/d12, frus1969-76v18/d58, frus1955-57v03/d264, frus1969-76v17/d193, frus1969-76v18/d124, frus1949v08/d78, frus1969-76v17/d11, frus1945v07/d224, frus1964-68v30/d303

---

## Q18. What medium- and long-term impacts did U.S. policymakers anticipate the Panama Canal Treaty having? What were they right and wrong about?

### Lexical — `"what" AND "medium-" AND "long-term" AND "impacts" AND "did" AND "u.s." AND "policymakers" AND "anticipate" AND "the" AND "panama" AND "canal" AND "treaty" AND "having?" AND "what" AND "were" AND "they" AND "right" AND "wrong" AND "about?"`

*(no results)*

### Semantic (query prompt)

1. **3. Paper Prepared in the Department of State** — Washington , January 21, 1977  
   `frus1977-80v29/d3` · score 0.6755  
   > POLICY REVIEW MEMORANDUM: PANAMA I. CURRENT SITUATION Our basic national interest in Panama is that the Canal remain efficient, secure, neutral, and continuously open to all world shipping at reasonable tolls. The present Canal has served us well over the years, and is still a “major” defense asset…
2. **553. Memorandum From Secretary of Defense Laird to President Nixon** — Washington , September 3, 1971  
   `frus1969-76ve10/d553` · score 0.6740  
   > Laird addressed the opposing positions on duration, the temporary decision on the issue, examined the termination arguments, and recommended that Panama be informed that the United States would not agree to a fixed-term treaty. He also recommended that the U.S. Government proceed much further into…
3. **428. Memorandum From the President’s Special Representatives ( Anderson and Irwin ) to President Johnson** — Washington , September 2, 1965 .  
   `frus1964-68v31/d428` · score 0.6733  
   > SUBJECT Panama Canal Treaty Negotiations Since May, the United States negotiators have been discussing with the Panamanians three treaties, an Interim Treaty (regarding the existing Canal), a Sea Level Canal Treaty and a Base Rights and Status of Forces Agreement. All aspects of the discussions…
4. **52. Memorandum of Conversation** — Grenada , June 15, 1977  
   `frus1977-80v29/d52` · score 0.6705  
   > Participants U.S. Secretary Cyrus Vance Under Secretary P. Habib Assistant Secretary Todman Ambassador McGee Mr. Hodding Carter, III Mr. Mark Dion (Notetaker) PANAMA Foreign Minister Gonzalez-Revilla Ambassador de la Rosa Ambassador Nander Pitty Panama Negotiations; OAS General Assembly—Joint…
5. **533. Memorandum From the NSC Inter-Departmental Group for Inter-American Affairs to President Nixon** — Washington , April 6, 1970  
   `frus1969-76ve10/d533` · score 0.6685  
   > The National Security Council Inter-Departmental Group for Inter-American Affairs (NSC–IG/ARA) reviewed the key issues for the United States in writing new Canal treaties with Panama. The NSC–IG/ARA focused on the following concerns: Canal capacity, sovereignty, control and defense of the Canal,…
6. **The Panaman Minister ( Alfaro ) to the Secretary of State** — Washington , January 3, 1923 .  
   `frus1923v02/d574` · score 0.6680  
   > Mr. Secretary : When the Republic of Panama seceded from Colombia in 1903 See Foreign Relations , 1903, pp. 224 ff. and 689 ff. and gained the recognition of its independence by the Government of the United States, soon followed by that of the leading nations of the world, the main question which…
7. **89. Minutes of a Cabinet Meeting** — Washington , August 29, 1977, 9:05 a.m.  
   `frus1977-80v29/d89` · score 0.6679  
   > The twenty-fifth meeting of the Cabinet was called to order by the President at 9:05 a.m., Monday, August 29, 1977. All Cabinet members were present except Secretary Bergland, who was represented by Deputy Secretary of Agriculture John White; Secretary Califano , represented by Under Secretary of…
8. **79. Memorandum From the Assistant to the President ( Jordan ) and William Hyland of the National Security Council Staff to President Carter** — Washington , August 9, 1977  
   `frus1977-80v29/d79` · score 0.6647  
   > SUBJECT Panama Canal Treaty Attached is the background material you requested on the new Panama Canal Treaty: (1) Basic Elements and (2) Talking Points. However, the latest report from Panama indicates the negotiations have slowed down somewhat today and that an announcement that an agreement in…
9. **20. Briefing Memorandum From Ambassador at Large ( Bunker ) and Panama Canal Treaty Co-Negotiator ( Linowitz ) to Secretary of State Vance** — Washington , February 25, 1977  
   `frus1977-80v29/d20` · score 0.6634  
   > PANAMA We have just returned from nine days of talks with Panama’s negotiators. As specified by the Policy Review Committee on January 27 See Document 8 . and the President on February 11, See Document 14 . the objective of these talks was to explore informally whether Panama would be willing to…
10. **223. Internal Transcript of a White House Briefing** — Washington , May 8, 1979, 7:40–9:05 p.m.  
   `frus1977-80v29/d223` · score 0.6603  
   > THE PRESIDENT: I don’t know of a better way to wind up a day of delightful legislative work—(Laughter)—than to discuss the Panama Canal Treaty and its implementation. I would like to start out and say a few words as President and then call on Secretary Alexander to follow me and then General…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 7/10.*
*document variant:* frus1969-76v22/d44, frus1964-68v31/d428, frus1977-80v29/d79, frus1969-76ve10/d533, frus1977-80v29/d3, frus1977-80v01/d67, frus1977-80v29/d89, frus1977-80v29/d20, frus1969-76ve10/d553, frus1969-76ve10/d530
*bare variant:* frus1977-80v29/d3, frus1969-76ve10/d553, frus1977-80v29/d89, frus1977-80v29/d223, frus1969-76v22/d44, frus1964-68v31/d428, frus1977-80v29/d52, frus1969-76v22/d13, frus1977-80v29/d79, frus1969-76v22/d94

---

## Q19. Climate diplomacy

### Lexical — `"climate" AND "diplomacy"`

1. **303. Memorandum From the Assistant to the President’s Special Assistant for Health Issues ( Fill ) to the President’s Special Assistant for Health Issues ( Bourne )** — Washington , November 30, 1977  
   `frus1977-80v02/d303` · score -14.6028  
   > SUBJECT A Thought re Implications of a New International Health Policy If we established as a principle of foreign policy that we would not deny any needy nation international health assistance it would be a first in U.S. history. By establishing this moral principle we would not hesitate to award…
2. **497. Memorandum From the President’s Assistant for National Security Affairs ( Brzezinski ) to Secretary of State Vance , Secretary of Defense Brown , the Director of the Office of Management and Budget ( McIntyre ), the Director of the Arms Control and Disarmament Agency ( Warnke ), and the Director of the International Communication Agency (Reinhardt)** — Washington , June 8, 1978  
   `frus1977-80v26/d497` · score -11.9126  
   > SUBJECT Interagency Committee on Public Diplomacy and Disarmament Whatever the specific accomplishments of the UN Special Session on Disarmament ( SSOD ), it has focused the attention of important publics throughout the world on disarmament issues. As we move beyond SSOD , it is desirable to foster…
3. ****  
   `frus1969-76v01/d6` · score -11.5303  
   > Editorial Note Richard Nixon offered his perspective on prospects for détente with the Soviet Union in his acceptance speech at the Republican convention in Miami Beach, Florida, on August 8, 1968: “And now to the leaders of the Communist world, we say: After an era of confrontation, the time has…
4. **134. Memorandum From the President’s Assistant for National Security Affairs ( Brzezinski ) to Secretary of State Vance , Secretary of Defense Brown , the Director of the Office of Management and Budget ( McIntyre ), the Director of the Arms Control and Disarmament Agency ( Warnke ), and the Director of the International Communication Agency ( Reinhardt )** — Washington , undated  
   `frus1977-80v30/d134` · score -11.3745  
   > SUBJECT Interagency Committee on Public Diplomacy and Disarmament An unknown hand underlined the subject line. Whatever the specific accomplishments of the UN Special Session on Disarmament ( SSOD ), The tenth UN Special Session on Disarmament took place May 23–June 30. Documentation on the Special…
5. **The Chargé in the Soviet Union ( Kennan ) to the Secretary of State** — Moscow , March 20, 1946—2 p.m. [Received 4:59 p.m.]  
   `frus1946v06/d487` · score -11.1652  
   > secret Moscow , March 20, 1946—2 p.m. [Received 4:59 p.m.] 878. In recent days we have noted a number of statements made either editorially in American papers or individually by prominent Americans reflecting the view that Soviet “suspicions” could be assuaged if we on our part would make greater…
6. **317. Letter From Prime Minister Nehru to President Kennedy** — New Delhi , August 11, 1963 .  
   `frus1961-63v19/d317` · score -10.6581  
   > Dear Mr. President , Ambassador Chester Bowles and the U.K. High Commissioner Sir Paul Gore-Booth jointly handed over for the consideration of the Government of India a draft joint communique to our Foreign Secretary on the evening of the 7th. Bowles reported on this demarche in telegram 608 from…
7. **43. Contingency Study Prepared by the National Security Council Interdepartmental Working Group/Europe, Washington, undated.** — Washington , undated .  
   `frus1969-76ve15p1/d43` · score -10.4550  
   > The National Security Council prepared a study of the potential impact of Soviet military action against Romania or internal Romanian political instability on the U.S. and the NATO alliance. Washington , undated . CONTINGENCY STUDY FOR ROMANIA Summary There are broadly speaking two sets of…
8. **172. Minutes of National Security Council Meeting** — Washington , January 13, 1977, 10:30–11:30 a.m.  
   `frus1969-76v35/d172` · score -9.9582  
   > SUBJECT Semiannual Review of the Intelligence Community PRINCIPALS The President The Vice President Secretary of State Henry A. Kissinger Secretary of Defense Donald Rumsfeld Director of Central Intelligence George Bush Chief of Naval Operations James L. Holloway (Acting for Chairman, Joint Chiefs…
9. **No. 783. Mr. Beardsley to Mr. Fish .** — Agency and Consulate-General of the United States in Egypt , Cairo , September 3, 1873 . (Received September 29.)  
   `frus1874/d786` · score -9.9402  
   > Sir : I have the honor to inform you that Sir Samuel Baker and Lady Baker arrived at Cairo on the 24th ultimo, where they are now stopping. I have had the pleasure of several interviews with Sir Samuel, on which occasions he graphically detailed the incidents of his expedition and expressed himself…
10. **33. Memorandum From Robert Pastor of the National Security Council Staff to the President’s Assistant for National Security Affairs ( Brzezinski )** — Washington , October 4, 1978  
   `frus1977-80v24/d33` · score -9.8273  
   > SUBJECT Impact of U.S. Human Rights Policy in Latin America After our discussion at the staff meeting last week, I tasked the CIA to do an overall assessment of the impact of our human rights policy in the Southern Cone. Brzezinski highlighted this sentence in the left-hand margin and wrote,…

### Semantic (query prompt)

1. **356. Telegram From the Embassy in France to Multiple Recipients** — Paris , December 9, 1986, 1653Z  
   `frus1981-88v41/d356` · score 0.5435  
   > Subject: UNEP Negotiations on Protocol to Protect Ozone Layer, Geneva, December 1–5, 1986 (Delegation Report). Ref: A) State 364665, B) State 349396, C) State 255252 (Notal). In telegram 364665 to multiple recipients, November 22, the Department transmitted alternative texts of operative protocol…
2. **352. Telegram From the Department of State to Multiple Diplomatic Posts** — Washington , March 30, 1985, 0546Z  
   `frus1981-88v41/d352` · score 0.5310  
   > Subject: Conference of Plenipotentiaries for Protection of the Ozone Layer: Report of the U.S. Delegation. 1. Summary: The Conference of Plenipotentiaries on the Protection of the Ozone Layer (18–22 March 1985) was successfully concluded, with the quote Vienna Convention for the Protection of the…
3. **36. Information Memorandum From the Assistant Secretary of State for Economic and Business Affairs ( Hormats ) to Secretary of State Haig** — Washington , undated  
   `frus1981-88v38/d36` · score 0.5245  
   > SUBJECT Global Negotiations This memorandum follows-up your request to me to consider how best to approach the issue of global negotiations. I should alert you at the outset that I am not at all confident that any approach, short of full support for Global Negotiations, can avoid the President’s…
4. **358. Telegram From the United States USUN Environmental Mission to the Department of State** — Vienna , February 26, 1987, 1932Z  
   `frus1981-88v41/d358` · score 0.5140  
   > Subject: Ozone Layer Protocol Negotiations, Vienna February 23–27 (Report #2—Status). 1. Summary—Second round of negotiations proceeding in workmanlike fashion and, in US Del’s view, focusing on proper range of issues. In contrast to first meeting in Geneva last December, UNEP working group seems…
5. **325. Report on the UN Conference on the Human Environment from the Vice-Chairman of Delegation ( Herter ) to Secretary of State Rogers** — Washington , July 28, 1972 .  
   `frus1969-76ve01/d325` · score 0.5092  
   > Herter transmitted the U.S. Delegation’s official report of activity during the Stockholm Conference. Washington , July 28, 1972 . CLASSIFIED REPORT OF THE UNITED STATES DELEGATION TO THE UNITED NATIONS CONFERENCE ON THE HUMAN ENVIRONMENT STOCKHOLM, SWEDEN JUNE 5-16, 1972 SUMMARY On the whole, the…
6. **355. Action Memorandum From the Assistant Secretary of State for Oceans and International Environmental and Scientific Affairs ( Negroponte ) to the Under Secretary of State for Economic Affairs ( Wallis )** — Washington , November 28, 1986  
   `frus1981-88v41/d355` · score 0.5030  
   > SUBJECT Circular 175: Request for Authority to Negotiate a Protocol to the Convention for the Protection of the Ozone Layer ISSUE FOR DECISION: Whether to authorize negotiation of a protocol to the Vienna Convention for the Protection of the Ozone Layer which would control emissions of…
7. **299. Memorandum From Acting Secretary of State Johnson to President Nixon** — Washington , August 24, 1970 .  
   `frus1969-76ve01/d299` · score 0.5014  
   > Johnson asked the President to provide guidance for U.S. policy toward the major international organizations dealing with the environment. Washington , August 24, 1970 . Subject: U.S. Policy toward the Major International Organizations Dealing with the Environment Recommendation: That the United…
8. **373. Telegram From the Consulate in Canada to the Department of State** — Montreal , September 11, 1987, 1252Z  
   `frus1981-88v41/d373` · score 0.4995  
   > Subject: Ozone Protocol Negotiations (Montreal)—Status Report. 1. (C—Entire text). 2. Following provides status as of 5 p.m. Thursday September 10. of fast-paced negotiations which have involved night sessions since Monday. September 7. While significant progress is being made, complex issues…
9. **367. Briefing Memorandum From the Acting Assistant Secretary of State for Oceans and International Environmental and Scientific Affairs ( Benedick ) to the Deputy Secretary of State ( Whitehead )** — Washington , June 9, 1987  
   `frus1981-88v41/d367` · score 0.4929  
   > SUBJECT Domestic Policy Council Meeting on Protocol to Control Ozone-Depleting Chemicals—11:00 a.m., Thursday, June 11 I. YOUR OBJECTIVE The first DPC Meeting on this subject (May 20— Allen Wallis attending) See Document 363 . failed to resolve deep agency divisions over the U.S. negotiating…
10. **10. Memorandum From the U.S. Special Negotiator for Economic Matters ( Meissner ) to the Under Secretary of State-Designate for Economic Affairs ( Rashish ), the Assistant Secretary of State-Designate for Economic and Business Affairs ( Hormats ), and Henry Nau of the National Security Council Staff** — Washington , April 21, 1981  
   `frus1981-88v38/d10` · score 0.4923  
   > SUBJECT Formulating a U.S. Policy toward a Multilateral Political Dialogue on the Functioning of the Market Oriented International Economic System I. Preamble Since the early 1960’s the developing countries (LDCs) have coalesced in a very loose political structure to demand changes in the market…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 2/10.*
*document variant:* frus1981-88v41/d356, frus1981-88v41/d362, frus1981-88v41/d352, frus1981-88v38/d36, frus1969-76ve01/d325, frus1981-88v41/d358, frus1981-88v41/d373, frus1907p2/d508p, frus1981-88v41/d368, frus1969-76ve01/d306
*bare variant:* frus1907p2/d508p, frus1981-88v38/d36, frus1969-76ve08/d171, frus1919Parisv03/d11, frus1969-76v37/d31, frus1981-88v01/d149, frus1981-88v41/d367, frus1969-76ve03/d36, frus1969-76ve14p1/d39, frus1969-76ve03/d35

---

## Q20. Window of vulnerability

### Lexical — `"window" AND "of" AND "vulnerability"`

1. **183. Memorandum From Secretary of Defense Brown to President Carter** — Washington , April 30, 1980  
   `frus1977-80v04/d183` · score -13.8845  
   > SUBJECT FB–111B/C Proposal ( U ) ( S ) General Ellis, Commander of the Strategic Air Command, has proposed that we modify 150 F–111As and FB–111s into a new, longer range strategic bomber called the FB–111B/C. He argues that this would strengthen our strategic forces during the “vulnerability…
2. **264. Information Memorandum From the Director of the Policy Planning Staff (Solomon) to Secretary of State Shultz** — Washington , January 27, 1988  
   `frus1981-88v11/d264` · score -10.4867  
   > SUBJECT Heading Off Criticism of START SUMMARY . Several well-known members of the strategic “establishment,” including Henry Kissinger , Brent Scowcroft, Bill Hyland, and Jim Woolsey, have begun to criticize the emerging START agreement on the grounds that 50 percent reductions will concentrate…
3. **237. Memorandum From the Assistant Secretary of the Treasury for International Affairs ( Mulford ) to Secretary of the Treasury Baker** — Washington , February 26, 1988  
   `frus1981-88v38/d237` · score -9.3837  
   > SUBJECT Next Steps Under the Debt Strategy Summary This memo provides an appraisal of the debt strategy, in light of recent developments and evolving debtor and commercial bank attitudes. In particular, it explores options for encouraging new bank financing, as well as various debt reduction…
4. **204. Memorandum to the Chairman of the 40 Committee** — Washington , June 2, 1975 .  
   `frus1969-76v35/d204` · score -9.2331  
   > SUBJECT Project MATADOR REFERENCE –0188/75(R), Same Subject dated 19 May 1975 Document 203 . 1. This memorandum requests 40 Committee direction on initiation of the Project MATADOR mission as stated below. It amplifies the information provided in the reference. 2. Mission Readiness. The HUGHES…
5. **The Ambassador in the Soviet Union ( Harriman ) to the Secretary of State** — Moscow , January 20, 1946—noon. [Received 4:03 p.m.]  
   `frus1946v06/d463` · score -8.3287  
   > confidential Moscow , January 20, 1946—noon. [Received 4:03 p.m.] 187. . . . In evaluating need for information program directed to USSR, we begin with basic consideration that US relations with USSR are probably more important and portentous than with any other countries. There can be little…
6. **96. Backchannel Message From the Ambassador to Chile ( Korry ) to the Under Secretary of State for Political Affairs ( Johnson )** — Santiago , September 16, 1970 .  
   `frus1969-76v21/d96` · score -8.0978  
   > I am extremely grateful for the confidence and support of President Nixon and the 40 Committee. 2. I am painfully aware of the delicacy of my situation and I trust that you and your colleagues are equally aware of the long odds involved. 3. President Frei ’s attitude is very clear to me: He is 100…
7. **211. Memorandum From the President’s Assistant for National Security Affairs ( Kissinger ) to President Nixon** — Washington , February 20, 1970 .  
   `frus1969-76v20/d211` · score -8.0869  
   > SUBJECT The Williams Case You will recall the Williams case in the Philippines, in which an Air Force sergeant at Clark Field was accused of complicity in an attempted rape case in the nearby town of Angeles, and was inadvertently allowed by his military supervisors to depart on reassignment while…
8. **80. Memorandum From Senator Nunn to President Bush** — Washington , February 22, 1990  
   `frus1989-92v31/d80` · score -7.9517  
   > SUBJECT Ban on Mobile MIRV ed ICBM s I have been urging the Administration to propose a ban in START on mobile MIRV ed ICBM s because I think it makes sense in terms of greater strategic stability and because I think it may be your only hope for maintaining congressional support for the Rail…
9. **368. Telegram From the Embassy in the United Arab Republic to the Department of State** — Cairo , March 19, 1959, 2 p.m.  
   `frus1958-60v12/d368` · score -7.5666  
   > Following is summary impression my just concluded visit to Yemen: Ambassador Hare at Cairo was accredited as Minister to Yemen, and during a visit to Yemen presented his credentials to the Imam on March 11. As of March 16 there was an American legation in Taiz with a resident chargé. Throughout…
10. **Memorandum of Conversation, by Mr. Elbridge Durbrow of the Division of European Affairs** — [ Washington ,] February 3, 1943 .  
   `frus1943v03/d374` · score -7.4768  
   > The following is an outline of a conversation I had with Mr. Joseph E. Davies Ambassador to the Soviet Union during 1937 and part of 1938. regarding our attitude vis-à-vis the Soviet Union. After discussing at some length the difficulties which Admiral Standley had had in connection with the visit…

### Semantic (query prompt)

1. **The Acting Secretary of State to Minister Beaupré .** — Department of State , Washington , May 9, 1910 .  
   `frus1910/d68` · score 0.4637  
   > Mr. Wilson acknowledges legation’s May 7, and says that under the laws of the United States Knepper’s crime constitutes burglary as defined by the treaty, and that the law of America defines breaking and entering as including opening of window or door even if the window or door is not latched or…
2. **125. Information Memorandum From the Director of the Policy Planning Staff ( Wolfowitz ) to Secretary of State Shultz** — Washington , August 5, 1982  
   `frus1981-88v38/d125` · score 0.4138  
   > SUBJECT The International Financial System—Heightened Risks INTRODUCTION The international financial system is more vulnerable to sudden shocks today than any time since 1945. Strains on a system that so far has demonstrated great resilience have intensified enormously. Some banks have failed, and…
3. **57. Paper Prepared in the Department of the Navy** — Washington , undated .  
   `frus1969-76v37/d57` · score 0.4100  
   > VULNERABILITY OF OIL FIELD FACILITIES—IMPACT ON CONTINGENCY PLANNING Attempting to get at the facts of this issue is like an emotional court case where prosecution and defense lawyers drag in “expert” witnesses who attempt to make the case for each side couched in scientific terminology. Shortly…
4. **The President of the Standard Oil Company of New Jersey ( W. C. Teagle ) to the Secretary of State** — New York , April 17, 1923 . [Received April 18.]  
   `frus1923v02/d159` · score 0.4051  
   > My Dear Mr. Secretary : For your information, I beg to advise you of recent development in connection with, the negotiations between the American Group and representatives of the present partners of the Turkish Petroleum Company, Limited, for a participation of our Group in that Company. Mr. H. E.…
5. **Mr. Terrell to Mr. Olney .** — Legation of the United States , Constantinople , October 12, 1896 . (Received Oct. 26.)  
   `frus1896/d842` · score 0.3974  
   > Sir : I have the honor to inclose for your information the copy of a dispatch from the British vice-consul at Harpoot, inclosing formal affidavits, which establish the complicity of the Turkish soldiers in the burning and plundering of the American college in that city. This testimony was taken in…
6. **444. Memorandum From Berkner to Killian** — March 24, 1959  
   `frus1958-60v03mSupp/d444` · score 0.3941  
   > SUBJECT Concealment of Underground Explosions The Panel on Seismic Improvement, appointed by the Chairman of the President’s Science Advisory Committee, considered the general problem of the concealment of underground nuclear tests at its meeting on 5 and 6 March 1959. The Panel reviewed various…
7. **Mr. Adams to Mr. Seward** — Legation of the United States , London , December 14, 1867.  
   `frus1868p1/d8` · score 0.3936  
   > Sir: In accordance with the directions contained in yonr dispatch No. 2105, I have written to Mr. West to apply for an official report of Captain Warren’s trial. By a letter received this morning from him, I learn that he has already received and forwarded an official copy of the indictment. The…
8. **No. 774. Mr. Bayard to Mr. Bragg .** — Department of State , Washington , March 15, 1888 .  
   `frus1888p2/d61` · score 0.3935  
   > Sir : Referring to the subject of the murder of Leon McLeod Baldwin, a citizen of the United States, of which Mr. Connery informed me in his dispatches No. 239, of October 4, 1887, and 251 of October 19, 1887, I have now to call your attention to the statements presented to this Department in…
9. **Professor A. C. Coolidge to the Commission to Negotiate Peace** — Vienna , April 22, 1919 . [Received April 25.]  
   `frus1919Parisv12/d101` · score 0.3911  
   > Sirs : I have the honor to enclose herewith two reports Second report, dated April 22, not printed. by Mr. Walter E. Bundy which contain interesting information on the present situation. Personally I am inclined to take a less pessimistic view of the immediate situation than does Mr. Bundy. As long…
10. **173. Memorandum From Victor Utgoff of the National Security Council Staff to the President’s Assistant for National Security Affairs (Brzezinski)** — Washington , February 8, 1980  
   `frus1977-80v04/d173` · score 0.3878  
   > SUBJECT M–X Basing Vulnerability In response to your question as to which is less vulnerable—the racetrack or multiple holes—I think the sheltered road mobile basing system is less vulnerable overall, because it can be made as resistant to nuclear attacks as the multiple holes system, but is far…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 5/10.*
*document variant:* frus1910/d68, frus1952-54v06p2/d1001, frus1958-60v03mSupp/d444, frus1896/d842, frus1868p1/d8, frus1969-76v37/d57, frus1931v02/d248, frus1923v02/d159, frus1977-80v04/d173, frus1977-80v03/d314
*bare variant:* frus1910/d68, frus1958-60v03mSupp/d444, frus1981-88v38/d125, frus1961-63v23/d225, frus1923v02/d159, frus1896/d842, frus1981-88v04/d110, frus1977-80v11p1/d37, frus1969-76ve01/d38, frus1964-68v18/d172

---

## Q21. washington naval conference ratios

### Lexical — `"washington" AND "naval" AND "conference" AND "ratios"`

1. **The Ambassador in Japan ( Grew ) to the Secretary of State** — Tokyo , February 1, 1934—5 p.m. [Received February 1—6:24 a.m.]  
   `frus1934v03/d21` · score -17.6368  
   > Yesterday in the Diet Foreign Minister Hirota stated in effect: “Japan’s policy toward the second Washington conference The first Washington Conference, from November 1921 to February 1922, dealt with naval armaments and with Far Eastern questions; for correspondence, see Foreign Relations , 1922,…
2. **The Minister in China ( Johnson ) to the Secretary of State** — Peiping , August 16, 1934 . [Received September 8.]  
   `frus1934v03/d192` · score -17.4081  
   > Sir : I have the honor to report statements made on August 13, 1934, to a member of my staff by Mr. Hagiwara, an officer of the Asiatic Bureau of the Japanese Ministry for Foreign Affairs, now on tour in China, with regard to the Japanese attitude toward the next naval disarmament conference. It is…
3. **The Secretary of State to the Japanese Ambassador ( Debuchi )** — [ Washington , November 12, 1929 .]  
   `frus1929v01/d180` · score -17.3310  
   > Aide-Mémoire You have asked me for an expression of my opinion as to the proposed ratio for Japan in the several classes to be dealt with at the London Conference, and you have suggested that Japan desires a ratio not of 5–3 but of 10–7 in the cruiser class particularly as to the type armed with…
4. **The Acting Chairman of the American Delegation ( Gibson ) to the Secretary of State** — Geneva , March 27, 1933—3 p.m. [Received March 27—10:25 a.m.]  
   `frus1933v01/d59` · score -17.3003  
   > Your 311, March 23, 6 p.m., reference paragraph on table following article 41 under air armaments. General comment indicates that we will not be alone in holding that numbers indicated are inadequate. In our opinion table should be redrafted in form to provide for four columns covering…
5. **Memorandum by the Chief of the Division of Far Eastern Affairs ( Hornbeck ) to the Secretary of State** — [ Washington ,] March 31, 1934 .  
   `frus1934v01/d174` · score -17.2363  
   > Mr. Secretary : Referring further to the question of the (problematical) Naval Conference: Right or wrong, like it or not, this country is at the head of the column and therefore must function within and according to the character imposed upon it by virtue of its being in that position. We ought,…
6. **The Department of State to the Japanese Embassy**  
   `frus1929v01/d207` · score -16.5943  
   > Copies also sent to the British, French, and Italian Embassies. Memorandum During the stay in Washington of the Japanese Delegates to the London Naval Conference, they attended two meetings with the American Delegates to the Conference on Tuesday December 17 and Thursday December 19, 1929,…
7. **Memorandum by the Under Secretary of State ( Phillips )** — [ Washington ,] May 24, 1934 .  
   `frus1934v01/d184` · score -16.5414  
   > During my conversation with the President this morning he said that he wanted Assistant Secretary Roosevelt, Henry L. Roosevelt, Assistant Secretary of the Navy. Admiral Standley, William H. Standley, Chief of Naval Operations. Pierrepont Moffat Chief of the Division of Western European Affairs.…
8. **The Ambassador in Great Britain ( Bingham ) to the Secretary of State** — London , June 18, 1934—10 p.m. [Received June 18—8:20 p.m.]  
   `frus1934v01/d207` · score -16.5353  
   > From Norman Davis. Chairman of the American delegation to the General Disarmament Conference, temporarily in London for naval conversations. The first naval conversation took place this morning at 10 Downing Street. The Prime Minister, J. Ramsay MacDonald. the First Lord of the Admiralty, Sir…
9. **The Chargé in Japan ( Neville ) to the Secretary of State** — Tokyo , November 2, 1935 . [Received November 18.]  
   `frus1931-41v01/d203` · score -16.3033  
   > Sir : I have the honor to observe that with Japan’s acceptance on October 29 of the British Government’s invitation to participate in the formal naval disarmament conference required by the Treaties, and which is to be held on December 2, next, the attitude of the Japanese Government is one of…
10. **The Ambassador in Japan ( Warren ) to the Secretary of State** — Tokyo , December 3, 1921—2 p.m. [Received December 3—1:43 p.m.]  
   `frus1922v01/d47` · score -16.2204  
   > My telegram no. 403, November 30. There is evidence of Government efforts, since the Cabinet meeting yesterday, to prepare the public mind to consider the matter of ratio of naval strength as but part of the fundamental question of an agreement on Far Eastern and Pacific questions. As Uchida stated…

### Semantic (query prompt)

1. **The Department of State to the Japanese Embassy**  
   `frus1929v01/d207` · score 0.6163  
   > Copies also sent to the British, French, and Italian Embassies. Memorandum During the stay in Washington of the Japanese Delegates to the London Naval Conference, they attended two meetings with the American Delegates to the Conference on Tuesday December 17 and Thursday December 19, 1929,…
2. **The Secretary of State to the Japanese Ambassador ( Debuchi )** — [ Washington , November 12, 1929 .]  
   `frus1929v01/d180` · score 0.6094  
   > Aide-Mémoire You have asked me for an expression of my opinion as to the proposed ratio for Japan in the several classes to be dealt with at the London Conference, and you have suggested that Japan desires a ratio not of 5–3 but of 10–7 in the cruiser class particularly as to the type armed with…
3. **The Secretary of State to the Ambassador in Great Britain ( Dawes )** — Washington , August 28, 1929—7 p.m.  
   `frus1929v01/d132` · score 0.6016  
   > Relative to your telegram No. 242, August 24, 2 p.m. The following review of our points of agreement is sent to you in an endeavor to meet the whole situation. The phraseology of some of these has been slightly changed to meet our general discussions, with the addition of certain clauses which may,…
4. **The Secretary of State to the Ambassador in Great Britain ( Dawes )** — Washington , September 11, 1929—8 p.m.  
   `frus1929v01/d144` · score 0.5975  
   > The following principles are set down upon which the Government of the United States and His Majesty’s Government propose, as relating to their own governments, to enter upon a conference of the principal naval powers for the limitation and reduction of naval armament. First: These negotiations are…
5. **Memorandum by the Japanese Naval Experts** — [ Washington ,] November 30, 1921 .  
   `frus1922v01/d43` · score 0.5876  
   > At the Second Plenary session of the Conference, Baron Kato, as Plenipotentiary Delegate for Japan, expressed his approval of the American proposal in general, and made a declaration of his determination to carry out a drastic reduction in naval armaments. At the same time, he stated that, in…
6. **Memorandum by the American Naval Experts** — [ Washington , undated. ]  
   `frus1922v01/d44` · score 0.5859  
   > In reply to the paper submitted by Vice Admiral Kato at the informal meeting of the Naval Advisors on November 30th, Memorandum by Japanese naval experts, supra. the United States Naval Advisors wish first to point out that if relativity is treated from the standpoint of what each nation conceives…
7. **Speech Delivered by Mr. Norman H. Davis at London on December 6, 1934** — London , December 6, 1934  
   `frus1931-41v01/d193` · score 0.5857  
   > At a luncheon given by the Association of American Correspondents in London to the members of the American delegation in the preliminary naval conversations. London , December 6, 1934 There seems to be some confusion of thought with regard to the matters at issue in the naval conversations, arising…
8. **Memorandum by the Chief of the Division of Far Eastern Affairs ( Hornbeck ) to the Secretary of State** — [ Washington ,] March 31, 1934 .  
   `frus1934v01/d174` · score 0.5817  
   > Mr. Secretary : Referring further to the question of the (problematical) Naval Conference: Right or wrong, like it or not, this country is at the head of the column and therefore must function within and according to the character imposed upon it by virtue of its being in that position. We ought,…
9. **Memorandum of Conversation Between the American and the Japanese Delegations** — [ London ,] December 17, 1935 .  
   `frus1931-41v01/d206` · score 0.5806  
   > Present: Admiral Nagano Mr. Nagai Admiral Iwashita Mr. Terasaki Mr. Mizota Mr. Davis Mr. Phillips Admiral Standley Mr. Dooman Captain Ingersoll Commander Schuirmann Mr. Field In response to a request from Admiral Nagano in regard to the American proposal referred to by Mr. Davis at the opening…
10. **The Secretary of State to the, Ambassador in Japan ( Warren )** — Washington , November 19, 1921—7 p.m.  
   `frus1922v01/d38` · score 0.5718  
   > Your telegram 390, November 17, 9 p.m. In yesterday’s press appears what purports to be an official announcement of the Japanese position with respect to naval limitation given out by Admiral Baron Kato:—“Because of her geographical position, Japan deems it only fair at the present time that the…

*Route overlap: 3 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 7/10.*
*document variant:* frus1922v01/d43, frus1929v01/d180, frus1922v01/d44, frus1929v01/d207, frus1929v01/d132, frus1929v01/d144, frus1934v01/d174, frus1931-41v01/d211, frus1929v01/d107, frus1931-41v01/d193
*bare variant:* frus1929v01/d207, frus1929v01/d180, frus1922v01/d44, frus1929v01/d132, frus1922v01/d43, frus1929v01/d144, frus1922v01/d42, frus1929v01/d107, frus1929v01/d85, frus1934v01/d174

---

## Q22. sussex pledge

### Lexical — `"sussex" AND "pledge"`

1. **The Secretary of State to the Ambassador in Germany ( Gerard )** — Washington , April 18, 1916, 6 p. m.  
   `frus1916Supp/d308` · score -16.9310  
   > You are instructed to deliver to the Secretary of Foreign Affairs a communication reading as follows: I did not fail to transmit immediately, by telegraph, to my Government your excellency’s note of the 10th instant in regard to certain attacks by German submarines, and particularly in regard to…
2. **The Ambassador in Germany ( Gerard ) to the Secretary of State** — Berlin , January 16, 1917 . [Received February 6.]  
   `frus1914-20v01/d656` · score -15.6242  
   > Dear Mr. Secretary : The nearer I get to the situation the more I consider the President’s peace note an exceedingly wise move. It has made it difficult for the Terrorists here to start anything which will bring Germany in conflict with the U. S. The Chancellor, Zimmermann, Stumm; have all…
3. **The Secretary of State to President Wilson** — Washington , May 10, 1916 .  
   `frus1914-20v01/d536` · score -15.4606  
   > My Dear Mr. President : In the submarine controversy we will unavoidably be forced to meet a situation which will arise, if it has not already arisen, and to determine on a course of action. The problem is this: A German submarine torpedoes, without conforming in any way to the rules of…
4. **Draft Instructions to the Ambassador in Germany ( Gerard )** — undated  
   `frus1914-20v01/d509` · score -13.5736  
   > This paper bears the notation: “Original handed to Prest for his consideration 2:30 pm April 6/16. RL.” See also footnote 34, p. 546 . undated You are instructed to deliver to the Secretary of Foreign Affairs a note reading as follows: On March 24, 1916, at two-fifty p. m. the unarmed steamer…
5. **The Secretary of State to the Chairman of the Senate Committee on Privileges and Elections ( Pomerene )** — Washington , November 26, 1917 .  
   `frus1914-20v02/d53` · score -12.2364  
   > My Dear Senator Pomerene : Referring to your letter of October 16th last and to our conversations regarding certain data which the subcommittee of the Committee on Privileges and Elections desires from the Department in relation to the address made by Senator La Follette before the Non-partisan…
6. **Mr. Adams to Mr. Seward .** — Legation of the United States, London, May 13, 1864.  
   `frus1864p1/d394` · score -2.6834  
   > Sir: I have the honor to transmit a copy of the London Times, containing a report of the speech of Mr. Gladstone, in the House of Commons, on Wednesday afternoon, on the question of franchise. I need not say that this is one of the most significant events of the day. It at once marks out the shape…

### Semantic (query prompt)

1. **The Secretary of State to President Wilson** — Washington , March 27, 1916 .  
   `frus1914-20v01/d507` · score 0.4674  
   > My Dear Mr. President : All the information which we are receiving in regard to the sinking of the Sussex in the English Channel, by which several Americans were injured and some undoubtedly killed, indicates that the vessel was torpedoed by a German submarine. For correspondence previously printed…
2. **Mr. Hay to Mr. Sherman .** — American Embassy , London , April 26, 1898 .  
   `frus1898/d737` · score 0.4546  
   > Sir : I have the honor to inclose herewith two copies of the London Gazette Extraordinary of this date, containing Her Britannic Majesty’s proclamation of neutrality in relation to the war between the United States and Spain. I have, etc., John Hay. [Inclosure.] The London Gazettle…
3. **The Secretary of State to President Wilson** — Washington , April 10, 1916 .  
   `frus1914-20v01/d510` · score 0.4522  
   > My Dear Mr. President : I enclose a suggested insertion in the draft of instructions to the American Ambassador at Berlin, which I handed to you at the White House on the 6th instant. Supra . The suggestion is due to Mr. Gerard’s telegram #3713 of April 6th. Foreign Relations , 1916, supp., p. 225…
4. **The Ambassador in Germany ( Gerard ) to the Secretary of State** — Berlin , May 8, 1916, 6 p. m. [ Received May 9, 10 p. m. ]  
   `frus1916Supp/d346` · score 0.4471  
   > Following is translation of the text of note upon which my telegram No. 3858 Not printed. was based: Supplementing his note of the 4th instant, concerning the conduct of the German submarine warfare, the undersigned has the honor to inform his excellency, the American Ambassador, Mr. James W.…
5. **The British Ambassador ( Lindsay ) to the Under Secretary of State ( Castle )** — Washington , June 24, 1931 .  
   `frus1931v01/d156` · score 0.4379  
   > Dear Mr. Under-Secretary : In accordance with my instructions, I communicate to you herewith a statement which will be made today in the House of Commons by the Chancellor of the Exchequer. Believe me [etc.] R. C. Lindsay [Enclosure] Statement by the British Chancellor of the Exchequer ( Snowden )…
6. **The Secretary of State to the Ambassador in Germany ( Gerard )** — Washington , April 18, 1916, 6 p. m.  
   `frus1916Supp/d308` · score 0.4330  
   > You are instructed to deliver to the Secretary of Foreign Affairs a communication reading as follows: I did not fail to transmit immediately, by telegraph, to my Government your excellency’s note of the 10th instant in regard to certain attacks by German submarines, and particularly in regard to…
7. **Memorandum by The Secretary of State of a Conversation With the German Ambassador ( Bernstorff ), April 18, 1916** — April 18, 1916  
   `frus1914-20v01/d523` · score 0.4327  
   > B My Government wants me to talk over with you once more the submarine question, and the instruction which I have received. I thought it would be better if I would give you confidentially a copy of the telegram. Infra . I had the telegram Friday but I had to put it in order. * * * This form of…
8. **The German Secretary of State for Foreign Affairs ( Jagow ) to the German Ambassador ( Bernstorff )** — Berlin , April 11, 1916 . [Received Tuckerton, N. J., April 13—10:27 p. m.]  
   `frus1914-20v01/d512` · score 0.4256  
   > This paper bears the notation: “This wireless was delivered to German Amb. am April 14/16 RL.” [Translation] Berlin , April 11, 1916 . [Received Tuckerton, N. J., April 13—10:27 p. m.] No. 130. For your information. Reply regarding Sussex , other cases handed Gerard Monday night. Careful…
9. **The French Ambassador ( Jusserand ) to the Secretary of State** — Washington , April 20, 1916 .  
   `frus1914-20v01/d526` · score 0.4245  
   > My Dear Mr. Secretary : Here are some more particulars just received from my Government concerning the torpedoing of the Sussex and the way we happened to be able to ascertain who was the author of this shocking deed. Lieut. Commander Cayrol of our staff was entrusted with the care of examining the…
10. **The Ambassador in the United Kingdom ( Douglas ) to the Secretary of State** — London , June 11, 1947—10 a.m.  
   `frus1947v01/d388` · score 0.4225  
   > top secret u.s. urgent London , June 11, 1947—10 a.m. 3173. For Acheson from Douglas. In your top secret 2155 of May 17 Supra. you asked for my preliminary views on Empire defense, Bevin’s position and that of the Cabinet as a whole, apparent failure of British Government to supply British press…

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 2/10.*
*document variant:* frus1952-54v05p2/d135, frus1916Supp/d294, frus1914-20v01/d507, frus1931v01/d156, frus1914-20v01/d523, frus1916Supp/d346, frus1916Supp/d287, frus1914-20v01/d510, frus1916Supp/d308, frus1902/d510
*bare variant:* frus1866p1/d124, frus1952-54v05p2/d135, frus1865p1/d248, frus1931v01/d156, frus1898/d737, frus1945Berlinv02/d1417, frus1944v01/d357, frus1945Malta/d500, frus1964-68v33/d340, frus1902/d499

---

## Q23. "trust but verify"

### Lexical — `"trust but verify"`

1. **168. Memorandum From the Special Advisor to the President and Secretary of State on Arms Control Matters (Nitze) to Secretary of State Shultz** — Washington , October 29, 1986  
   `frus1981-88v11/d168` · score -5.7040  
   > SUBJECT NSPG Meeting, 11:00 a.m., October 27, 1986 Formal minutes of this meeting are printed in Foreign Relations , 1981–1988, vol. VI, Soviet Union, October 1986–January 1989, Document 3 . John Poindexter summarized the agreement reached at Reykjavik: a. 50% reductions in strategic arms to 1,600…
2. **301. Memorandum of Conversation** — Reykjavik , October 11, 1986, 10:40 a.m.–12:30 p.m.  
   `frus1981-88v05/d301` · score -4.7110  
   > PARTICIPANTS US SIDE President Reagan Secretary Shultz (came in at 11:30) Ambassador Matlock D. Zarechnak (Interpreter) USSR SIDE General Secretary Gorbachev Foreign Minister Shevardnadze (came in at 11:30) Notetaker N. Upsenskiy (Interpreter) Nikolai Uspensky is the correct name for the Soviet…
3. **3. Minutes of a National Security Planning Group Meeting** — Washington , October 27, 1986, 11 a.m.–noon  
   `frus1981-88v06/d3` · score -4.2486  
   > SUBJECT Arms Control Follow-up to Reykjavik (U) PARTICIPANTS The President State Secretary George Shultz Treasury Secretary James Baker Defense Secretary Caspar Weinberger Mr. Richard Perle Energy Secretary John Herrington OMB Mr. James Miller ACDA Mr. Kenneth Adelman CIA Mr. Douglas George JCS…
4. **335. Address by President Reagan to the Nation** — Washington , January 11, 1989  
   `frus1981-88v01/d335` · score -4.1040  
   > Farewell Address to the Nation My fellow Americans: This is the 34th time I’ll speak to you from the Oval Office and the last. We’ve been together 8 years now, and soon it’ll be time for me to go. But before I do, I wanted to share some thoughts, some of which I’ve been saving for a long time. It’s…
5. **306. Remarks by President Reagan** — Los Angeles , August 26, 1987  
   `frus1981-88v01/d306` · score -3.7238  
   > Remarks on Soviet-United States Relations at the Town Hall of California Meeting in Los Angeles Before we begin, I hope you’ll forgive me for saying that it’s good to be back in California. Actually, I didn’t realize how completely I made the transition from Washington until I got on a helicopter…
6. **333. Remarks by President Reagan** — Charlottesville, Virginia , December 16, 1988  
   `frus1981-88v01/d333` · score -3.2487  
   > Remarks and a Question-and-Answer Session at the University of Virginia in Charlottesville [Omitted here are the President’s introductory remarks and his comments about President Thomas Jefferson, the founder of the University of Virginia.] Well, that was politics in 1800. So, you see, not all that…
7. **360. Memorandum of Conversation** — Washington , July 27, 1988, 11 a.m.–1:40 p.m.  
   `frus1981-88v10/d360` · score -2.8714  
   > SUBJECT The President’s Meeting with General Secretary Karoly Grosz of Hungary PARTICIPANTS U.S. The President Secretary of State George P. Shultz Secretary of Treasury James A. Baker, III Secretary of Commerce C. William Verity Kenneth M. Duberstein, Chief of Staff M. B. Oglesby, Deputy Chief of…
8. **68. Memorandum of Conversation** — Washington , September 15, 1987, 3:30–5:30 p.m.  
   `frus1981-88v06/d68` · score -2.7679  
   > SUBJECT First Shultz - Shevardnadze Plenary PARTICIPANTS U.S. The Secretary Ambassador Kampelman Ambassador Ridgway Ambassador Nitze Ambassador Matlock Director Adelman Col. Linhard Mr. Simons (notetaker) U.S.S.R Foreign Minister Shevardnadze Dep. FonMin Bessmertnykh Ambassador Karpov Ambassador…
9. **308. Memorandum of Conversation** — Moscow , May 30, 1988, 9:15 a.m.–12:05 p.m.  
   `frus1981-88v11/d308` · score -2.3629  
   > SUBJECT Defense and Space, START PARTICIPANTS U.S. AMB Nitze AMB Kampelman AMB Hanmer AMB Cooper AMB Rowny AS Lehman ADM Howe COL Linhard Mr. Castillo Dr. Timbie Dr. Graham Mr. Richardson Mr. Korobovsky (Interpreter) Mr. Stafford (Notetaker) USSR MSU Akhromeyev AMB Obukhov AMB Kuznetsov AMB…

### Semantic (query prompt)

1. **32. Notes of a National Security Council Meeting** — Washington , August 9, 1982, 3:10 p.m.  
   `frus1981-88v11/d32` · score 0.5223  
   > Bud McF —introductory remarks [VP joins . . . Baker, Deaver , Darmon still out—Poindexter not present] . . . missiles above 850, nondeployed—4 groups of constraints—Group A (1) development of capabilities, (2) missiles & equipment at sites, (3) activities to develop reconstitution—recommend…
2. **121. Message from President Kennedy to Prime Minister Macmillan , April 6** — April 6, 1962  
   `frus1961-63v07-09mSupp/d121` · score 0.4977  
   > David Gore and my people have worked through the Joint Statement and made a half-dozen minor changes, which seem to meet the special worries of both sides, without changing the basic thrust of the document. This will be coming to you through David, but for your convenience I send it along after…
3. **44. Telegram From the Department of State to the Embassy in the Soviet Union** — Washington , April 7, 1962, 5:16 p.m.  
   `frus1961-63v06/d44` · score 0.4972  
   > You should concert with British Embassy delivery on April 9 to Soviet Foreign Ministry final agreed text quoted below: “Joint US/UK Statement on Nuclear Testing” Begin Verbatim Text Discussions among ourselves and the Soviet Union about a treaty to ban nuclear tests have been going on in Geneva for…
4. **107. Tosec 95 to Geneva, March 21** — March 21, 1962, 1:53 p.m.  
   `frus1961-63v07-09mSupp/d107` · score 0.4866  
   > Following is text message to President from Macmillan dated March 20 to which President’s letter reftel replies QUOTE I agreed with you after Bermuda that Christmas Island could be made available for your tests with our help. You agreed with me that the Christmas Island tests could not in fact be…
5. **Minutes of the Twenty-ninth Meeting of the United States Delegation, New York, Hotel Pennsylvania, November 26, 1946, 9 a.m.** — New York , November 26, 1946, 9 a.m.  
   `frus1946v01/d546` · score 0.4801  
   > secret [Here follows a list of persons (28) present.] Resolution on Armed Forces Mr. Sanders, at the request of Senator Connally, introduced the subject of the Resolution on Armed Forces. He reported that the United Kingdom on November 25 had submitted its resolution on the subject (US/A/C.1/72…
6. **12. Memorandum From the Joint Chiefs of Staff to Secretary of Defense McNamara** — Washington , February 22, 1964 .  
   `frus1964-68v11/d12` · score 0.4780  
   > JCSM -148-64 Washington , February 22, 1964 . SUBJECT Verification of a Freeze on Strategic Nuclear Vehicles ( U ) 1. Reference is made to the memorandum from the Acting Assist-ant Secretary of Defense ( ISA ) I-21210/64, dated 11 February 1964, Not found. which requested comments on an Arms…
7. **488. Memorandum from Llewellyn E. Thompson to Rusk , November 3** — November 3, 1962, noon  
   `frus1961-63v10-12mSupp/d488` · score 0.4761  
   > SUBJECT Memorandum of Conversation—Ambassador Anatoliy F. Dobrynin , USSR , and Llewellyn E. Thompson , Ambassador-at-Large, Department of State, 12:00 noon, Saturday, November 3, 1962 After a discussion of other subjects, Ambassador Dobrynin said that based on his conversation with Mr. Mikoyan in…
8. **Agreement Between the United States and the United Kingdom for the Establishment of the Combined Development Trust** — June 13, 1944  
   `frus1944v02/d885` · score 0.4639  
   > This Agreement and Declaration of Trust is made the 13th day of June 1944 by Franklin Delano Roosevelt on behalf of the Government of the United States of America, and by Winston Leonard Spencer Churchill on behalf of the Government of the United Kingdom of Great Britain and Northern Ireland. The…
9. **113. Secto 107 from Geneva, March 25** — Geneva , March 25, 1962, 8 p.m.  
   `frus1961-63v07-09mSupp/d113` · score 0.4637  
   > Eyes only for President and Acting Secretary from Secretary. Tosec 141 consider essential notice to mariners should be so timed there can be no possibility of asking for further delay because ships are already loaded or have left ports, or because there is not adequate time to take necessary…
10. **78. Letter From Director of Central Intelligence Turner to Secretary of State Vance** — Washington , February 23, 1978  
   `frus1977-80v28/d78` · score 0.4617  
   > Dear Cy: Out of a concern that the discussions between our staffs on the State- CIA “Treaty” See Documents 65 and 77 . may not be progressing as dispassionately as I would hope, and because I am deeply concerned at the recent turn of events, I would like to lay out my views on this critical subject…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 6/10.*
*document variant:* frus1961-63v07-09mSupp/d121, frus1961-63v06/d44, frus1911/d263, frus1977-80v28/d78, frus1944v02/d885, frus1961-63v10-12mSupp/d488, frus1964-68v11/d12, frus1961-63v11/d141, frus1949v08/d1128, frus1950v03/d697
*bare variant:* frus1981-88v11/d32, frus1911/d263, frus1961-63v07-09mSupp/d121, frus1961-63v06/d44, frus1961-63v07-09mSupp/d113, frus1961-63v07-09mSupp/d107, frus1944v02/d885, frus1977-80v26/d231, frus1969-76ve02/d138, frus1949v08/d1128

---

## Q24. persona non grata

### Lexical — `"persona" AND "non" AND "grata"`

1. **United States concern over the assassination of a Legation employee considered “persona non grata” by the Ethiopian government**  
   `frus1947v05/ch8` · score -30.0576  
   > [Mr. Johannes Semerjibashian, who was serving as dragoman-interpreter of the American Legation at Addis Ababa even though the Ethiopian Government had declared him persona non grata soon after his employment in July 1946, was assassinated on the evening of October 9, 1947, while in a Legation car…
2. **The Acting Secretary of State to the Legation in Hungary** — Washington , November 24, 1947—6 p. m.  
   `frus1947v04/d273` · score -27.8274  
   > top secret urgent niact Washington , November 24, 1947—6 p. m. 1191. While we agree in principle as indicated Deptel 1188 Nov 22 Not printed. that you should assume responsibility for official activities subordinate members Legation ( urtel 1871, Nov. 21) we cannot question right Hungarians declare…
3. **Memorandum by the Chief of the Division of Security ( Nicholson ) to the Director of the Office of Middle American Affairs ( Mann )** — [ Washington ,] April 5, 1950 .  
   `frus1950v02/d450` · score -27.0988  
   > Memorandum by the Chief of the Division of Security ( Nicholson ) This memorandum was also marked for the attention of W. Tapley Bennett, Jr., Officer in Charge of Central America and Panama Affairs. to the Director of the Office of Middle American Affairs ( Mann ) [Extract] confidential […
4. ****  
   `frus1950v04/d537` · score -26.8306  
   > Editorial Note In a note of March 10 to the Legation in Budapest, the Hungarian Foreign Ministry declared Military Attaché Col. James B. Kraft, Assistant Military Attaché Lt. Col. John T. Hoyne, and Assistant Air Attaché Maj. Donald E. Griffin personae non gratae and requested their recall. The…
5. **355. Memorandum From the Assistant Secretary of State for Near Eastern, South Asian, and African Affairs ( Rountree ) to the Acting Secretary of State** — Washington , August 13, 1957 .  
   `frus1955-57v13/d355` · score -26.3390  
   > SUBJECT Proposed Steps in Response to Syrian Government Actions Against the United States Discussion: The Syrian Government over the past several months has been taking an increasingly unfriendly attitude towards the United States and concurrently establishing closer ties with the Soviet Union. It…
6. **The Italian Ambassador ( Colonna ) to the Secretary of State** — Washington , April 8, 1941—XIX .  
   `frus1941v02/d797` · score -26.2249  
   > Mr. Secretary of State : I have the honor to inform you that the request of the United States Government, transmitted with your Note of April 2, 1941, that Admiral Alberto Lais, Naval Attaché of the Royal Italian Embassy, be immediately withdrawn from the United States being at present persona non…
7. **The Chargé in Bulgaria ( O’Donoghue ) to the Secretary of State** — Sofia , March 17, 1949—3 p. m.  
   `frus1949v05/d204` · score -25.5797  
   > secret Sofia , March 17, 1949—3 p. m. 225. Legtel 216, March 15. On March 9 the Bulgarian Government declared Denis A. Greenhill, First Secretary of the British Legation in Sofia, persona non grata . Greenhill, together with several former and current members of the British and American missions in…
8. **The Secretary of State to the Embassy in Poland** — Washington , April 7, 1950—7 p. m.  
   `frus1950v04/d560` · score -25.0786  
   > confidential Washington , April 7, 1950—7 p. m. 169. Re Embtel 399 Mar 15 Supra . and Desp 463 Mar 21. Not printed, but see footnote 3, supra . If no objection, deliver fol Aide-Mémoire to Acting FonMin in reply his communication Mar 15. ( Begin verbatim text ) Reference is made to the Fon…
9. **Memorandum of Conversation, by the Assistant Secretary of State ( Long )** — [ Washington ,] September 2, 1944 .  
   `frus1944v05/d255` · score -24.9404  
   > The British Ambassador came in to see me by appointment arranged by the Secretary’s office. Prior to the arrival of Lord Halifax but after reading the ticker text Printed as annex to this memorandum. of the quotation from the Caroe telegram to the British Foreign Office, and after talking again…
10. **109. Telegram From the Embassy in the Soviet Union to the Department of State** — Moscow , May 12, 1965, 1305Z .  
   `frus1964-68v14/d109` · score -24.9054  
   > Subject: Norris Garnett PNG Case. On May 11 the Foreign Ministry had declared Norris D. Garnett, Assistant Cultural Officer at the U.S. Embassy and the first African-American assigned there, persona non grata for carrying on work hostile to the USSR among African students. We have following…

### Semantic (query prompt)

1. **The Minister Resident in Ethiopia ( Engert ) to the Secretary of State** — Addis Ababa , June 12, 1936—3 p.m. [Received 7:44 p.m.]  
   `frus1936v03/d349` · score 0.4546  
   > Last paragraph Department’s 270, June 9. None of the chiefs of mission here used the title of “Viceroy” in addressing Badoglio. Graziani has never called himself even Acting Viceroy but only Governor General ad interim. I have been careful to refer to him befittingly as “Commander in Chief” thus…
2. **99. Briefing Paper Prepared in the Department of State** — Washington , undated .  
   `frus1955-57v27/d99` · score 0.4532  
   > SUBSTANTIVE BRIEF FOR THE PRESIDENT FOR HIS MEETING WITH PRESIDENT GRONCHI AT 10:30 A.M. FEBRUARY 28 U.S. Objectives During the Visit It is precisely because of the controversial character, personality and intentions of President Gronchi and also of his ignorance of the U.S. that we have, early in…
3. **Mr. Draper to Mr. Day .** — Embassy of the United States , Rome, Italy , May 28, 1898 .  
   `frus1898/d743` · score 0.4509  
   > Sir : I beg leave to inclose, as directed in your No. 178, of the 13th instant, two copies of the Gazetta Ufficiale containing the proclamation of neutrality issued by the Italian Government, and also the laws in regard to the enforcement of neutrality and the penalties for its transgression. I…
4. **The Italian Ambassador ( Martino ) to the Secretary of State**  
   `frus1927v03/d136` · score 0.4478  
   > The Italian Ambassador presents his compliments to His Excellency the Secretary of State and has the honor to bring the following to his attention. The weekly paper Il Martello of New York (77 East 10th Street) edited by the American citizen Carlo Tresca, has published under the signature of…
5. **The Ambassador in Italy ( Fletcher ) to the Secretary of State** — Rome , July 22, 1925—5 p.m. [Received July 22—2:42 p.m.]  
   `frus1925v02/d319` · score 0.4477  
   > A note has been received from the Under Secretary for Foreign Affairs, which states that on account of reports contained in recent telegraphic news despatches sent to the Chicago Tribune by George Seldes, Tribune correspondent at Rome, he is to be considered persona non grata in Italy, and I am…
6. **Baron Fava to Mr. Hay .** — Italian Embassy , Washington , October 31, 1899 .  
   `frus1899/d403` · score 0.4463  
   > Mr. Secretary of State : In your note of the 14th of August last I read the replies made by the honorable Secretary of the Treasury to the note of June 10, whereby Count Vinci called your excellency’s attention to the depositions made by the Commissioner of Immigration on the 10th of February last…
7. **The Chargé in Italy ( Jay ) to the Secretary of State** — Rome , September 17, 1918 . [ Received October 14. ]  
   `frus1918Supp01v01/d841` · score 0.4437  
   > Sir : In accordance with instructions contained in the Department’s cablegram No. 1670 of September 7, 1918, I have the honor to forward herewith a full report on the Italian attitude with reference to the Jugo-Slavs, which has been very carefully prepared by Mr. Gino C. Speranza of this Embassy. I…
8. **The Ambassador in Italy ( page ) to the Secretary of State** — Rome , December 25, 1916, 6 p. m. [ Received December 26, 8.30 a. m. ]  
   `frus1916Supp/d162` · score 0.4383  
   > Press here strongly hostile to President’s suggestion. Clerical press partly favorable, though a part refers to Pope as the true intermediary and reference has been made to United States and Switzerland as representing Protestantism. Pope in allocution yesterday referring to peace made no reference…
9. **The Secretary of State to Consular Officers in Latin American Countries** — Washington , December 6, 1917 .  
   `frus1917Supp02v02/d130` · score 0.4381  
   > General Instructions Consular Gentlemen : Referring to General Instruction No. 554 of November 7, 1917, Not printed. enclosing a copy of an act, “to define, regulate and punish trading with the enemy, and for other purposes,” approved by the President, October 6, 1917, together with a copy of the…
10. **The Ambassador in Italy ( Fletcher ) to the Secretary of State** — Rome , July 28, 1925 . [Received August 10.]  
   `frus1925v02/d322` · score 0.4374  
   > Sir : With reference to my telegram No. 119 of July 22, 5 p.m. and No. 121 of July 27, 4 p.m., and to the Department’s No. 91 of July 25, 1 p.m., concerning the expulsion by the Italian Government of Mr. George Seldes, correspondent of the Chicago Tribune , I have the honor to report as follows: On…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 0/10.*
*document variant:* frus1955-57v27/d99, frus1914-20v01/d692, frus1927v03/d136, frus1916Supp/d173, frus1891/d605, frus1899/d403, frus1918Supp01v01/d841, frus1925v02/d322, frus1936v03/d349, frus1955-57v27/d128
*bare variant:* frus1952-54v15p2/d819, frus1872p2v4/d43, frus1981-88v04/d108, frus1919Parisv03/d3, frus1916/d449, frus1933v03/d384, frus1906p2/d308, frus1909/d435, frus1918/d676, frus1914-20v01/d214

---

## Q25. blood telegram
*known-item by nickname (Archer Blood's April 1971 Dacca dissent cable — the documents never call it that)*

### Lexical — `"blood" AND "telegram"`

1. **3. Telegram From the Department of State to All Diplomatic and Consular Posts** — Washington , September 22, 1983, 1904Z  
   `frus1981-88v41/d3` · score -9.5570  
   > Subject: Information on Acquired Immune Deficiency Syndrome ( AIDS ). 1. During the September 5–10 meeting in Rome involving State OES Assistant Secretary Malone and science officers from European embassies, considerable interest was shown in the new disease called acquired immune deficiency…
2. **7. Telegram From the Department of State to the Medical Collective** — Washington , June 7, 1985, 0045Z  
   `frus1981-88v41/d7` · score -9.5522  
   > Subject: Acquired Immune Deficiency. For Regional Medical Officers and Foreign Service nurses. 1. The ICD–9–CM does not have a number specifically set aside for this disorder. After consulting with the National Center for Health Statistics, M/MED designates the following numbers as the codes for…
3. **The Secretary of State to the Ambassador in China ( Gauss )** — Washington , December 18, 1943 .  
   `frus1943China/d700` · score -9.0791  
   > On December 17, 1943 the President approved an Act of Congress, Public 199, 57 Stat. 600. of which Section 1 repeals the Chinese exclusion laws, Section 2 establishes an immigration quota for Chinese (which has been computed at 105 annually) and provides a preference of seventy-five per centum for…
4. **The Ambassador in Germany ( Dodd ) to the Secretary of State** — Berlin , September 19, 1935 . [Received September 27.]  
   `frus1935v02/d305` · score -8.8451  
   > Sir : With reference to the Embassy’s telegram No. 172 of September 16, 11 a.m., Not printed. I have the honor to transmit herewith two copies of the Reichsgesetzblatt , No. 100, Part I, of September-16, containing the three laws adopted by the Reichstag at Nuremberg on September 15 regarding…
5. **2. Telegram From the Department of State to the Embassy in Haiti** — Washington , September 21, 1982, 1345Z  
   `frus1981-88v41/d2` · score -8.8305  
   > Subject: AIDS Among Haitian Populations. Ref: Port Au Prince 5108. In telegram 5108 from Port Au Prince, September 15, the Embassy wrote, “Recent publicity given to occurrence Acquired Immune Deficiency Syndrome ( AIDS ) among Haitian population in US and at least two unexplained deaths of Haitians…
6. **No. 807 The Ambassador in Japan ( Allison ) to the Department of State** — Tokyo , September 24, 1954—8 p.m.  
   `frus1952-54v14p2/d807` · score -8.7621  
   > The Ambassador in Japan ( Allison ) to the Department of State confidential Tokyo , September 24, 1954—8 p.m. 712. Pass AEC . Reference Embassy’s 704. Dated Sept. 23; in it the Embassy reported that Dr. Masao Tsuzuki , the physician in charge of the Fukuryu Maru patients, had requested (with the…
7. **199. Memorandum From Secretary of State Muskie to President Carter** — Washington , September 13, 1980  
   `frus1977-80v19/d199` · score -8.2301  
   > Indian Reaction to Congressional Committee Action on Tarapur: The Government of India’s public reaction to the negative Tarapur votes was careful and restrained, and paralleled the positions taken with us privately. See footnote 2, Document 197 . In telegram 19029 from New Delhi, September 11,…
8. **The Minister in Lithuania ( Norem ) to the Secretary of State** — Kaunas , July 19, 1940—10 a.m. [Received 7:38 p.m.]  
   `frus1940v01/d402` · score -8.1712  
   > The election results have been announced as one of 99% variety and indicates a total lack of true democratic expression. Indications point to complete absorption into the Soviet Union. The new Seimas is scheduled to meet on Sunday, July 21. This body met at noon on July 21 and “decided to petition…
9. **19. Telegram From the Department of State to All African Diplomatic Posts** — Washington , August 5, 1986, 0233Z  
   `frus1981-88v41/d19` · score -8.1314  
   > Subject: Disinformation: AIDS Made in USA. Ref: A) Dakar 8253; B) Dakar 8510; C) Nairobi 27931; D) Moscow 12333. Telegram 8253 from Dakar, July 18. (Department of State, Central Foreign Policy File, D860553–0606) Telegram 8510 from Dakar, July 25. (Department of State, Central Foreign Policy File,…
10. **74. Telegram 1569 From the Consulate General in Dacca to the Department of State** — Dacca , August 17, 1970, 0624Z  
   `frus1969-76ve07/d74` · score -8.0912  
   > Ambassador Farland reported from Dacca on severe flooding in East Pakistan that had led Pakistani President Yahya to postpone national elections from October to December. Dacca , August 17, 1970, 0624Z For Secretary and Sisco from Ambassador 1. Severe floods are causing considerable damage and…

### Semantic (query prompt)

1. **The Chargé in Costa Rica ( Trueblood ) to the Secretary of State** — San José , September 14, 1943—5 p.m. [Received 11:44 p.m.]  
   `frus1943v06/d115` · score 0.5524  
   > Reference Department’s telegram 535, August 21, and my despatch No. 545 of September 4. The Minister of Finance has instructed the Junta de Custodia to take the necessary steps to convert the dollar funds held by the Spanish Minister into colones and block the latter. Foreign Minister Echandi…
2. **The Chargé in Bolivia ( Trueblood ) to the Secretary of State** — La Paz , April 15, 1931—11 a.m. [Received 11:50 a.m.]  
   `frus1931v01/d739` · score 0.5516  
   > Manager of the All America Cables notified the Legation yesterday that beginning today he would be required by the Government to collect the taxes prescribed by the law of February 14th, 1929, on all cables except press and Bolivian official. Tax on Legation’s cables to the Department will amount…
3. **[Untitled]** — [Telegram, dated Ottawa , May 31, 1868 .]  
   `frus1868p1/d194` · score 0.5501  
   > To his Excellency Edward Thornton , British Legation: I have this telegram from a trustworthy source: “Head Center at Ogdensburg presented draft at Jodson’s bank for several thousand dollars. It was sent to New York for collection, and money returned yesterday and delivered to him. Eight wagon…
4. **The Commission to Negotiate Peace to the Acting Secretary of State** — Paris , May 6 [ 7? ], 1919 . [Received May 7, 4:16 p.m.]  
   `frus1919Russia/d884` · score 0.5350  
   > “May 6th, 5 p.m. From Jenkins , repeat Washington. ‘Aid to Volunteer Army. I respectfully refer to my telegram from Odessa Not printed. regarding report on [ Red Cross ] assistance for North Caucasus. The Volunteer Army has usual defects of any purely Russian organization but should be assisted not…
5. **The Chargé in Paraguay ( Trueblood ) to the Secretary of State** — Asunción , July 17, 1947—4 p.m.  
   `frus1947v08/d839` · score 0.5333  
   > confidential Asunción , July 17, 1947—4 p.m. 391. Embtel s 376, July 11 and 387, July 16. Neither printed. The following is a literal translation of the mediation proposals as presented by the Brazilian Embassy in Asunción on July 11 to US Government for approval: “Established the conditions…
6. **The Minister in China ( MacMurray ) to the Secretary of State** — Peiping , October 19, 1929—7 p.m. [Received 9:03 p.m.]  
   `frus1929v02/d239` · score 0.5248  
   > The Senior (Netherland) Minister received the following telegram dated on October 18th: “Red bands raid Russian emigrant settlements Three Rivers district, torment [to?] death, murder all peaceful men, women; number victims grows incessantly. For humaneness beg you as representative whole civilized…
7. **The Secretary of State to the Chargé in the Kingdom of the Serbs, Croats and Slovenes ( Boal )** — Washington , May 1, 1922—4 p.m.  
   `frus1922v02/d886` · score 0.5170  
   > Your telegram no. 10, April 28, 5 p.m. Not printed. Telegraph Department whether any part of the $30,000,000 referred to by Legation in its no. 7 of April 21, 4 p.m., will be used to pay off debts of Yugoslavia to foreign governments or to their nationals. Also what plan is contemplated by the…
8. **The Acting Secretary of State to Ambassador Bacon .** — Department of State , Washington , January 27, 1910 .  
   `frus1910/d581` · score 0.5150  
   > Mr. Wilson informs Mr. Bacon of the sending of the telegram which the President has addressed to-day to the President of the French Republic and says that the National Red Cross state they would be prepared to cable $5,000. Directs Mr. Bacon to telegraph for their information whether this would be…
9. **The Chargé in Great Britain ( Laughlin ) to the Secretary of State** — London , October 24, 1918 . [ Received 2.45 p.m. ]  
   `frus1918Russiav03/d217` · score 0.5142  
   > American Red Cross: 1872. Have seen general commanding Archangel area who is now in London. He instructs us not to send foodstuffs to Archangel as it is not necessary. Laughlin
10. **The United States Deputy Political Adviser at Allied Force Headquarters ( Byington ) to the Secretary of State** — Caserta , May 8, 1946—5 p.m. [Received May 8—1:10 p.m.]  
   `frus1946v06/d625` · score 0.5122  
   > secret Caserta , May 8, 1946—5 p.m. [Received May 8—1:10 p.m.] 501. Re my 496, May 3, 3 p.m. Not printed; it reported that in general the May Day celebrations in Trieste had passed quietly (800.00B International Red Day/5–346). AFHQ has been informed by XIII Corps that there is increased evidence…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 4/10, bare: 4/10.*
*document variant:* frus1868p1/d194, frus1931v01/d739, frus1931v01/d593, frus1947v08/d844, frus1961-63v04/d283, frus1918Russiav03/d217, frus1952-54Guat/d270, frus1947v08/d839, frus1947v08/d832, frus1925v02/d424
*bare variant:* frus1943v06/d115, frus1919Russia/d884, frus1931v01/d739, frus1910/d581, frus1917/d1469, frus1917/d935, frus1907p2/d352, frus1940v04/d77, frus1921v02/d673, frus1941v01/d520
