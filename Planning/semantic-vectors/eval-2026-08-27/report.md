# Retrieval evaluation — the owner-query sitting (W-17 session 3 / W-9 step 2)

Two routes over the same corpus, 25 owner-written queries, top 10 each.
**Lexical** is the app's own search (the rendered MATCH expression is shown — what
actually executed). **Semantic** is the shipped funnel (Hamming → int8 rerank) with the
query embedded by the SHA-pinned GGUF (`text-embedding-embeddinggemma-300m-qat`, `5a9e0645541b…`), primary
prompt = the model's retrieval query template; the two other prompt variants appear as
id lists with overlap counts, so this sitting also settles the prompt question.
`CSUserQuery` (W-9 step 1) is not built yet and joins this report when it is.

**How to judge:** for each row mark `relevant` in `verdicts.csv` as 1 (would open it),
0 (noise), or leave blank (can't tell from the snippet). Known-item queries are judged
on whether the known document surfaces at all. The null control ("Space aliens") is
judged the other way: the honest route is the one that does NOT dress noise as an answer.

---

## Q1. How did U.S. diplomats engage with host governments about the Emancipation Proclamation?

### Lexical — `"how" AND "did" AND "u.s." AND "diplomats" AND "engage" AND "with" AND "host" AND "governments" AND "about" AND "the" AND "emancipation" AND "proclamation?"`

1. **No. 23. Statement of Charles T. Gulick.**  
   `frus1894app2/d306` · score -7.2846  
   > No. 23. Statement of Charles T. Gulick. Col. J. H. Blount , United States Commissioner, etc.: Dear Sir : I send you by bearer a very hastily prepared sketch of some features of Hawaiian History with our present condition in view. Time has n…

### Semantic (query prompt)

1. **The Secretary of State to the Attorney General ( Palmer )** — Washington , April 8, 1920 .  
   `frus1920v03/d523` · score 0.5641  
   > 701.6111/505 The Secretary of State to the Attorney General ( Palmer ) Washington , April 8, 1920 . Sir : Referring to the informal request of Mr. Hoover, that this Department prepare a statement regarding diplomatic immunity as applied to …
2. **Mr. King to Mr. Seward** — Legation of the United States at Rome, January 14, 1865.  
   `frus1865p3/d149` · score 0.5630  
   > Mr. King to Mr. Seward No. 31] Legation of the United States at Rome, January 14, 1865. Sir: I have the honor to acknowledge the receipt of despatch No. 21, of December 16, from the State Department, in reply to mine of November 12, and con…
3. **28. Telegram 84081 From the Department of State to All African Diplomatic Posts** — Washington , April 12, 1975, 0205Z  
   `frus1969-76ve06/d28` · score 0.5628  
   > 28. Telegram 84081 From the Department of State to All African Diplomatic Posts Source: National Archives, RG 84, Ethiopia Embassy Files: Lot 77 F 121, OAU Relations with the United States. Confidential; Priority; Limdis. Repeated priority …
4. **Mr. Taylor to Mr. Seward .** — Legation of the United States , St. Petersburgh , January 21, 1863.  
   `frus1863p2/d168` · score 0.5620  
   > [Extracts.] Mr. Taylor to Mr. Seward . No. 27.] Legation of the United States , St. Petersburgh , January 21, 1863. Sir: Your despatch No. 10, of December 23, was received on the 17th instant. The first portion of it, which relates to the i…
5. **81. Memorandum From the Director of the United States Information Agency ( Murrow ) to the Special Assistant to the President ( Schlesinger )** — Washington , May 21, 1962 .  
   `frus1917-72PubDipv06/d81` · score 0.5615  
   > 81. Memorandum From the Director of the United States Information Agency ( Murrow ) to the Special Assistant to the President ( Schlesinger ) Source: Kennedy Library, Schlesinger Papers, White House Subject Files, Subject File 1961–1964, Bo…
6. **Mr. Motley to Mr. Seward** — Legation of the United States, Vienna, April 9, 1865.  
   `frus1865p3/d9` · score 0.5610  
   > Mr. Motley to Mr. Seward No. 92.] Legation of the United States, Vienna, April 9, 1865. Sir: I have the honor to acknowledge the receipt of your despatch No. 129, of date 13th of March, containing very interesting reflections on the close c…
7. **Memorandum handed by the Chilean minister to the Acting Secretary of State .** — Legation of Chile , Washington , June 22, 1891 . (Received June 23.)  
   `frus1891/d304` · score 0.5577  
   > Memorandum handed by the Chilean minister to the Acting Secretary of State . Legation of Chile , Washington , June 22, 1891 . (Received June 23.) Mr. Secretary : I have asked this interview rather in the hope of preventing the raising of qu…
8. **Mr. Black ( Secretary of State ) to all the ministers of the United States .** — Department of State , Washington , February 28, 1861 .  
   `frus1861/d2` · score 0.5575  
   > Mr. Black ( Secretary of State ) to all the ministers of the United States . Department of State , Washington , February 28, 1861 . CIRCULAR. Sir : You are, of course, aware that the election of last November resulted in the choice of Mr. A…
9. **219. Memorandum of Conversation** — New York , September 24, 1966, 1:15 p.m.  
   `frus1964-68v24/d219` · score 0.5566  
   > 219. Memorandum of Conversation Source: Department of State, Central Files, POL AFR–US. Confidential. Drafted by Alec G. Toumayan and Harry R. Melone, and approved in S on October 4. The conversation was held at the Waldorf Towers in New Yo…
10. **Mr. Pike to Mr. Seward .** — United States Legation , The Hague , December 31, 1862.  
   `frus1863p2/d202` · score 0.5563  
   > Mr. Pike to Mr. Seward . No. 70.] United States Legation , The Hague , December 31, 1862. Sir: I have to acknowledge the receipt of your despatch of December 6, No. 70. The President’s message, the American diplomatic correspondence of 1862…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 4/10, bare: 2/10.*
*document variant:* frus1917-72PubDipv06/d81, frus1914/d1, frus1955-57v18/d314, frus1863p2/d202, frus1952-54v03/d807, frus1925v01/d146, frus1862/d105, frus1969-76v28/d48, frus1861/d2, frus1865p3/d9
*bare variant:* frus1942v02/d177, frus1925v01/d146, frus1958-60v06/d455, frus1917-72PubDipv06/d131, frus1969-76ve06/d28, frus1952-54v08/d5, frus1944v06/d25, frus1861/d2, frus1914-20v01/d490, frus1893/d357

---

## Q2. How did immigration affect U.S. diplomacy with China in the 1880s?

### Lexical — `"how" AND "did" AND "immigration" AND "affect" AND "u.s." AND "diplomacy" AND "with" AND "china" AND "in" AND "the" AND "1880s?"`

1. **No. 23. Statement of Charles T. Gulick.**  
   `frus1894app2/d306` · score -4.2130  
   > No. 23. Statement of Charles T. Gulick. Col. J. H. Blount , United States Commissioner, etc.: Dear Sir : I send you by bearer a very hastily prepared sketch of some features of Hawaiian History with our present condition in view. Time has n…

### Semantic (query prompt)

1. **Mr. Chang Yen Hoon to Mr. Bayard .** — Chinese Legation , Washington , January 26, 1889 . (Received January 26.)  
   `frus1889/d87` · score 0.6789  
   > Mr. Chang Yen Hoon to Mr. Bayard . Chinese Legation , Washington , January 26, 1889 . (Received January 26.) Sir : I have the honor to inform you that I have carefully examined the act of Congress approved October 1, 1888, in relation to th…
2. **Mr. Wu to Mr. Hay .** — Chinese Legation , Washington , December 10, 1901 .  
   `frus1901/d85` · score 0.6679  
   > Mr. Wu to Mr. Hay . Chinese Legation , Washington , December 10, 1901 . No. 219.] Sir : In view of the fact that the law of the Congress of the United States which went into force May 6, 1882, based upon the treaty of 1880 between China and…
3. **No. 126. The commission to Mr. Evarts .** — United States Commission , Peking , October 11, 1880 .  
   `frus1881/d126` · score 0.6597  
   > No. 126. The commission to Mr. Evarts . United States Commission , Peking , October 11, 1880 . No. 6.] Sir : Recurring to our dispatch No. 4, of the 27th ultimo, in which we reported our arrival here, and the appointment by the Government o…
4. **No. 240. Mr. Bayard to Mr. Chang Yen Soon .** — Department of State , Washington , January 12, 1887 .  
   `frus1888p1/d240` · score 0.6404  
   > No. 240. Mr. Bayard to Mr. Chang Yen Soon . [Confidential.] Department of State , Washington , January 12, 1887 . Sir : I have had the honor informally to discuss with you, in recent personal interviews in connection with questions growing …
5. **No. 127. The commission to Mr. Evarts .** — United States Commission , Peking , October 23, 1880 .  
   `frus1881/d127` · score 0.6295  
   > No. 127. The commission to Mr. Evarts . United States Commission , Peking , October 23, 1880 . No. 8.] Sir : Our dispatch No. 6 covered the memorandum which we submitted at our first interview with the Chinese commissioners, and the reply w…
6. **Mr. Tsui to Mr. Foster .** — Chinese Legation , Washington, D. C. , Nov. 11, 1892 . (Received November 12.)  
   `frus1892/d114` · score 0.6197  
   > Mr. Tsui to Mr. Foster . Chinese Legation , Washington, D. C. , Nov. 11, 1892 . (Received November 12.) Sir : I have the honor to transmit herewith for your consideration and for the consideration of his excellency, the President of the Uni…
7. **No. 239. Mr. Rives to Mr. Denby .** — Department of State , Washington , October 10, 1888 .  
   `frus1888p1/d239` · score 0.6166  
   > No. 239. Mr. Rives to Mr. Denby . Department of State , Washington , October 10, 1888 . No. 357.] Sir : I transmit herewith for your information copies of the recently approved Chinese exclusion act and of the President’s message upon the s…
8. **No. 214. Mr. Bayard to Mr. Denby .** — Department of State , Washington , June 7, 1888 .  
   `frus1888p1/d214` · score 0.6146  
   > No. 214. Mr. Bayard to Mr. Denby . Department of State , Washington , June 7, 1888 . No. 328.] Sir : The treaty concluded in this city on March 12 last, between the Chinese minister and myself, was, as you have been heretofore informed, dul…
9. **No. 129. The commission to Mr. Evarts .** — United States Commission , Peking , November 3, 1880 .  
   `frus1881/d129` · score 0.6145  
   > No. 129. The commission to Mr. Evarts . United States Commission , Peking , November 3, 1880 . No. 11.] Sir : Our dispatch. No. 8, of October 23, 1880, brought the history of our negotiation down to the inverview of that day with the Chines…
10. **Mr. Wharton to Mr. Tsui .** — Department of State , Washington , December 10, 1892 .  
   `frus1892/d115` · score 0.6131  
   > Mr. Wharton to Mr. Tsui . Department of State , Washington , December 10, 1892 . Sir : I have the honor to acknowledge the reception of your two notes of the respective dates of November 7 and November 11, 1892, concerning the recent legisl…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 7/10.*
*document variant:* frus1889/d87, frus1901/d85, frus1881/d126, frus1888p1/d240, frus1876/d44, frus1892/d114, frus1881/d127, frus1890/d160, frus1892/d100, frus1888p1/d260
*bare variant:* frus1889/d87, frus1901/d85, frus1881/d126, frus1888p1/d240, frus1881/d127, frus1892/d114, frus1892/d100, frus1881/d129, frus1876/d44, frus1890/d160

---

## Q3. How did U.S. diplomats think about Cuban independence before 1898?

### Lexical — `"how" AND "did" AND "u.s." AND "diplomats" AND "think" AND "about" AND "cuban" AND "independence" AND "before"`

1. **18. Policy Paper Prepared in the Department of State** — Washington , undated  
   `frus1977-80v23/d18` · score -20.7747  
   > 18. Policy Paper Prepared in the Department of State Source: National Archives, RG 59, Anthony Lake Working Papers, Lot 82D298, TL Sensitive 7/1–9/20/77. Secret; Nodis. An attached August 1 note from Stedman and Lake to Christopher asks app…
2. **221. Memorandum of Conversation** — New York , October 4, 1982, 3–7:30 p.m.  
   `frus1981-88v03/d221` · score -18.8839  
   > 221. Memorandum of Conversation Source: Department of State, Executive Secretariat, S/S–I Records, Memoranda of Conversations Pertaining to United States and USSR Relations, 1981–1990, Lot 93D188, Shultz / Gromyko UN Sept–Oct 82 BMCK 1982 G…
3. **474. Memorandum of Discussion at the 436th Meeting of the National Security Council, Washington, March 10, 1960** — Washington , March 10, 1960  
   `frus1958-60v06/d474` · score -17.6200  
   > 474. Memorandum of Discussion at the 436th Meeting of the National Security Council, Washington, March 10, 1960 Source: Eisenhower Library, Whitman File, NSC Records. Top Secret. Prepared by Boggs on March 14. Washington , March 10, 1960 [H…
4. **68. Memorandum of Conversation** — Washington , August 5, 1977, 10:30 a.m.–noon  
   `frus1977-80v16/d68` · score -17.0628  
   > 68. Memorandum of Conversation Source: Carter Library, National Security Affairs, Staff Material, North/South, Funk , Subject File, Box 116, Tanzania: 5/77–11/80. Secret. The meeting took place in the White House Cabinet Room. Washington , …
5. **382. Memorandum of Conversation** — Washington , February 12, 1976, 4:15–4:45 p.m.  
   `frus1969-76ve11p1/d382` · score -16.9746  
   > 382. Memorandum of Conversation Summary: Kissinger and Wills discussed Guyana’s votes in the United Nations, Angola, and bilateral relations. Kissinger told Wills that the United States had no interest in confrontation with Guyana, and Will…
6. **152. Memorandum of Conversation** — Washington , August 18, 1976, 5 p.m.  
   `frus1969-76v18/d152` · score -16.7301  
   > 152. Memorandum of Conversation Source: Ford Library, National Security Adviser, Kissinger – Scowcroft West Wing Office Files, 1969–1977, Box 6, China, unnumbered items (33), 8/1/76–8/28/76. Secret; Nodis. The meeting was held in Secretary …
7. **342. Memorandum of a Conversation Between the Ambassador in Cuba ( Bonsal ) and Minister of State Roa , Havana, July 23, 1959** — Havana , July 23, 1959  
   `frus1958-60v06/d342` · score -16.7201  
   > 342. Memorandum of a Conversation Between the Ambassador in Cuba ( Bonsal ) and Minister of State Roa , Havana, July 23, 1959 Source: Department of State, Central Files, 611.37/7–2559. Secret; Limit Distribution. Transmitted as an enclosure…
8. **187. Memorandum of Conversation** — New York , June 19, 1982, 9:30 a.m.–1:40 p.m.  
   `frus1981-88v03/d187` · score -16.4009  
   > 187. Memorandum of Conversation Source: Reagan Library, Clark Files, Haig / Gromyko Meetings 06/18/1982–06/19/1982. Secret; Nodis . The meeting took place at the Soviet Mission to the United Nations. Bremer sent the memorandum of conversati…
9. **No. 713. Admiral Polo de Bernabé to Mr. Fish .** — Legation of Spain , Washington , December 10, 1873 ,  
   `frus1874/d715` · score -16.3256  
   > No. 713. Admiral Polo de Bernabé to Mr. Fish . Legation of Spain , Washington , December 10, 1873 , As a result of the protocol signed at Washington on the 29th of November last, relative to the case of the Virginius, the undersigned, envoy…
10. **26. Memorandum of a Conversation, Department of State, Washington, June 30, 1958** — Washington , June 30, 1958  
   `frus1958-60v13/d26` · score -16.2958  
   > 26. Memorandum of a Conversation, Department of State, Washington, June 30, 1958 Source: Department of State, Central Files, 611.84A/6–3058. Secret. Drafted by Bergus on July 1. Washington , June 30, 1958 SUBJECT U.S.-Israel Relations and t…

### Semantic (query prompt)

1. **No. 550. Mr. Fish to Mr. Cushing .** — Department of State , Washington , February 6, 1874 .  
   `frus1874/d552` · score 0.6757  
   > No. 550. Mr. Fish to Mr. Cushing . Department of State , Washington , February 6, 1874 . No. 2.] Sir : Whatever general instructions you may need at the present time for your guidance in representing this Government at Madrid have reference…
2. **[Untitled]**  
   `frus1902/d273` · score 0.6647  
   > [Untitled] To the Congress of the United States: I commend to the Congress timely consideration of measures for maintaining diplomatic and consular representatives in Cuba and for carrying out the provisions of the act making appropriation …
3. **279. Telegram From the Embassy in Cuba to the Department of State** — Havana , April 15, 1959—noon .  
   `frus1958-60v06/d279` · score 0.6588  
   > 279. Telegram From the Embassy in Cuba to the Department of State Source: Department of State, Central Files, 033.3711/4–1559. Confidential; Priority. Havana , April 15, 1959—noon . 1199. Castro ’s trip to United States has assumed increasi…
4. **150. Memorandum of Conversation** — Washington , September 18, 1962, 11:49 a.m.  
   `frus1961-63v12/d150` · score 0.6588  
   > 150. Memorandum of Conversation Source: Department of State, Central Files, 612.37/9-1862. Secret. Drafted by Sayre and approved in S October 12. The conversation was held at the Department of State. The time of the meeting is taken from Ru…
5. **Mr. Woodford to the President .** — Legation of the United States , Madrid , March 9, 1898 .  
   `frus1898/d544` · score 0.6564  
   > Mr. Woodford to the President . Legation of the United States , Madrid , March 9, 1898 . No. 41.] Dear Mr. President : Knowing how pressed you are for time, I fear you may find my letters somewhat prolix, but I know that you must wish all t…
6. **Mr. Woodford to Mr. Sherman .** — Legation of the United States , Madrid , March 25, 1898 .  
   `frus1898/d557` · score 0.6520  
   > Mr. Woodford to Mr. Sherman . Legation of the United States , Madrid , March 25, 1898 . No. 189.] Sir : Since the receipt of the Spanish note dated February 1, 1898, I have waited for suitable opportunity to have full and frank discussion w…
7. **The American Minister to the Secretary of State .** — American Legation , Habana , February 12, 1912 .  
   `frus1912/d405` · score 0.6499  
   > File No. 437.00/27. The American Minister to the Secretary of State . [Extract] No. 104.] American Legation , Habana , February 12, 1912 . Sir : Referring to previous correspondence [etc.] I have the honor to enclose herewith copy and trans…
8. **Memorandum of Conference by the Secretary of State With the Press on October 2, 1930** — October 2, 1930  
   `frus1930v02/d747` · score 0.6492  
   > 837.00/2844½ Memorandum of Conference by the Secretary of State With the Press on October 2, 1930 October 2, 1930 [Excerpt] A correspondent said that press dispatches from Havana report that President Machado contemplates asking Congress to…
9. **362. Memorandum of a Conversation, Department of State, Washington, September 18, 1959** — Washington , September 18, 1959  
   `frus1958-60v06/d362` · score 0.6479  
   > 362. Memorandum of a Conversation, Department of State, Washington, September 18, 1959 Source: Department of State, Central Files, 611.37/9–1859. Confidential. Drafted by Owen . Bonsal returned to the United States on September 14. (Telegra…
10. **527. Memorandum of a Conference, Department of State, Washington, June 7, 1960** — Washington , June 7, 1960  
   `frus1958-60v06/d527` · score 0.6477  
   > 527. Memorandum of a Conference, Department of State, Washington, June 7, 1960 Source: Department of State, Central Files, 737.00/6–760. Confidential. Drafted by Torrey and approved in U on June 16. Washington , June 7, 1960 SUBJECT Cuban S…

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
   > Message of the President . To the Congress: In my annual message addressed to the Congress on the third instant I called attention to the pending boundary controversy between Great Britain and the Republic of Venezuela and recited the subst…
2. **Mr. Olney to Mr. Bayard .** — Department of State , Washington , July 20, 1895 .  
   `frus1895p1/d527` · score 0.6371  
   > Mr. Olney to Mr. Bayard . Department of State , Washington , July 20, 1895 . No. 804.] His Excellency Thomas F. Bayard , Etc., etc., etc., London. Sir : I am directed by the President to communicate to you his views upon a subject to which …
3. **Mr. Andrade to Mr. Gresham .** — Legation of Venezuela , Washington , March 31, 1894 .  
   `frus1894/d820` · score 0.6284  
   > Mr. Andrade to Mr. Gresham . [Translation.] Legation of Venezuela , Washington , March 31, 1894 . Sir : In our interview of the 8th of last January, the subject of which was the endless and vexed boundary controversy between Venezuela and G…
4. **Lord Salisbury to Sir Julian Pauncefote .** — Foreign Office , November 26, 1895 .  
   `frus1895p1/d529` · score 0.6275  
   > Lord Salisbury to Sir Julian Pauncefote . Foreign Office , November 26, 1895 . No. 189.] Sir , On the 7th August I transmitted to Lord Gough a copy of the despatch from Mr. Olney which Mr. Bayard had left with me that day, and of which he h…
5. **Lord Salisbury to Sir Julian Pauncefote .** — Foreign Office , November 26, 1895 .  
   `frus1895p1/d530` · score 0.6235  
   > Lord Salisbury to Sir Julian Pauncefote . Foreign Office , November 26, 1895 . No. 190.] Sir , In my preceding despatch of to-day’s date I have replied only to the latter portion of Mr. Olney’s despatch of the 20th July last, which treats o…
6. **Mr. Gresham to Mr. Bayard .** — Department of State , Washington , July 13, 1894 .  
   `frus1894/d243` · score 0.6106  
   > Mr. Gresham to Mr. Bayard . Department of State , Washington , July 13, 1894 . No. 442.] Sir : During your incumbency of the office of Secretary of State you became acquainted with a long pending controversy between Great Britain and Venezu…
7. **430. Information Memorandum From the Presidentʼs Special Assistant ( Rostow ) to President Johnson** — Washington , January 25, 1968 .  
   `frus1964-68v32/d430` · score 0.6088  
   > 430. Information Memorandum From the Presidentʼs Special Assistant ( Rostow ) to President Johnson Source: Johnson Library, National Security File, Country File, Guyana (Brit. G.), Vol. I, Cables, Memos, and Misc., 5/66–11/68. Confidential.…
8. **The Secretary of State to various Senators .** — Department of State , Washington , January 22, 1912 .  
   `frus1912/d1493` · score 0.6040  
   > File No. 817.51/297A. The Secretary of State to various Senators . [Circular letter.] Department of State , Washington , January 22, 1912 . My Dear Senator : I have ventured to send you copy of an address I recently made on “The Monroe Doct…
9. **524. Memorandum From the Director of the Office of Colombian-Venezuelan Affairs ( Margolies ) to the Assistant Secretary of State for Inter-American Affairs ( Mann )** — Washington , January 13, 1965 .  
   `frus1964-68v31/d524` · score 0.6012  
   > 524. Memorandum From the Director of the Office of Colombian-Venezuelan Affairs ( Margolies ) to the Assistant Secretary of State for Inter-American Affairs ( Mann ) Source: National Archives and Records Administration, RG 59, Central Files…
10. **The Ambassador in Mexico ( Daniels ) to the Secretary of State** — Mexico , October 6, 1933 . [Received October 9.]  
   `frus1933v04/d25` · score 0.5995  
   > 710.G 1A/220 The Ambassador in Mexico ( Daniels ) to the Secretary of State No. 668 Mexico , October 6, 1933 . [Received October 9.] Sir : I have the honor to enclose a translation of a memorandum which was given to me this afternoon by Doc…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 7/10.*
*document variant:* frus1895p1/d526, frus1895p1/d527, frus1895p1/d529, frus1933v04/d25, frus1912/d1493, frus1964-68v32/d430, frus1914-20v02/d281, frus1894/d820, frus1895p1/d530, frus1929v01/d522
*bare variant:* frus1895p1/d526, frus1895p1/d527, frus1894/d820, frus1895p1/d530, frus1894/d243, frus1964-68v32/d430, frus1894/d822, frus1896/d182, frus1895p2/d750, frus1895p1/d529

---

## Q5. Mexican Revolution

### Lexical — `"mexican" AND "revolution"`

1. **The Acting Secretary for Foreign Affairs of the Vásquez Gómez-Provisional Government to the Secretary of State .** — Palomas, Chihuahua , February 25, 1913 .  
   `frus1913/d876` · score -13.7785  
   > File No. 812.00/6534. The Acting Secretary for Foreign Affairs of the Vásquez Gómez-Provisional Government to the Secretary of State . Received March 6; communicated to the Ambassador March 17; filed March 21. [Translation.] Palomas, Chihua…
2. **The American Ambassador to the Secretary of State .** — American Embassy , Mexico , July 7, 1913.  
   `frus1913/d1231` · score -13.3864  
   > File No. 412.00/28. The American Ambassador to the Secretary of State . No. 1998.] American Embassy , Mexico , July 7, 1913. Sir : I have the honor to acknowledge the Department’s No. 1337, of June 21, 1913, in which I am directed to reopen…
3. **The Secretary of State to the Chargé in Mexico ( Summerlin )** — Washington , October 9, 1919 .  
   `frus1920v03/d281` · score -13.0297  
   > 412.00/112 The Secretary of State to the Chargé in Mexico ( Summerlin ) Washington , October 9, 1919 . No. 1161 Sir : The Department acknowledges the receipt of your despatch No. 2406 dated September 17, 1919, Not printed. with which you fo…
4. **571. Memorandum of a Conversation, Department of State, Washington, August 3, 1960** — Washington , August 3, 1960  
   `frus1958-60v06/d571` · score -13.0112  
   > 571. Memorandum of a Conversation, Department of State, Washington, August 3, 1960 Source: Department of State, Central Files, 611.37/8–360. Confidential. Drafted by Osborne, initialed by Rubottom , and approved on August 9. Washington , Au…
5. **The Minister in Nicaragua ( Eberhardt ) to the Secretary of State** — Managua , December 31, 1926—10 p.m. [Received 10:40 p.m.]  
   `frus1927v03/d252` · score -12.8806  
   > 817.00/4335: Telegram The Minister in Nicaragua ( Eberhardt ) to the Secretary of State Managua , December 31, 1926—10 p.m. [Received 10:40 p.m.] 259. A conference was held this morning in the Legation at the request of the Diaz Government.…
6. **The Chargé in Nicaragua ( Dennis ) to the Secretary of State** — U. S. S. “ Denver ,” October 19, 1926—4 p.m. [Received October 21—11:30 a.m.]  
   `frus1926v02/d498` · score -12.8294  
   > 817.00/3943: Telegram The Chargé in Nicaragua ( Dennis ) to the Secretary of State U. S. S. “ Denver ,” October 19, 1926—4 p.m. [Received October 21—11:30 a.m.] 167. The conference is now in a deadlock over formula for “reestablishment of p…
7. **The Brazilian Minister to Mexico to the Secretary of State .** — Mexico City , March 9, 1915—11 p.m.  
   `frus1915/d839` · score -12.7930  
   > File No. 312.11/5656. The Brazilian Minister to Mexico to the Secretary of State . [Telegram.] Mexico City , March 9, 1915—11 p.m. 404. I have been requested by a committee of American citizens to transmit to you the following: The American…
8. **The American Ambassador to the Secretary of State .** — American Embassy , Mexico , January 6, 1912 .  
   `frus1912/d905` · score -12.7889  
   > File No. 812.00/2692. The American Ambassador to the Secretary of State . No. 1203.] American Embassy , Mexico , January 6, 1912 . Sir : I have the honor to transmit herewith for such action as the Department deems necessary to take, a copy…
9. **The Acting Secretary of State to the Ambassador in Mexico ( Fletcher )** — Washington , March 8, 1918 .  
   `frus1918/d695` · score -12.7478  
   > File No. 412.00/58 The Acting Secretary of State to the Ambassador in Mexico ( Fletcher ) No. 470 Washington , March 8, 1918 . Sir : The Department acknowledges the receipt of your No. 834 [634] of December 5, 1917, No. 634 not printed; for…
10. **The Minister in Nicaragua ( Eberhardt ) to the Secretary of State** — Managua , December 31, 1926—3 p.m. [Received 10:20 p.m.]  
   `frus1926v02/d528` · score -12.6474  
   > 817.00/4334: Telegram The Minister in Nicaragua ( Eberhardt ) to the Secretary of State Managua , December 31, 1926—3 p.m. [Received 10:20 p.m.] 257. Department’s 148, December 30, 4 p.m. President Diaz telegraphed a reply yesterday to Pres…

### Semantic (query prompt)

1. **The Confidential Agent of the Constitutionalist Government of Mexico to the Secretary of State .** — Washington , October 7, 1915 .  
   `frus1915/d991` · score 0.6013  
   > File No. 812.00/16543. The Confidential Agent of the Constitutionalist Government of Mexico to the Secretary of State . Washington , October 7, 1915 . Mr. Secretary : In consideration of the agreement between your excellency and the other A…
2. **Mr. Arredondo to the Secretary of State .** — Confidential Agency of the Constitutionalist Government of Mexico , Washington , December 16, 1914 .  
   `frus1914/d976` · score 0.5967  
   > File No. 812.00/14031. Mr. Arredondo to the Secretary of State . Confidential Agency of the Constitutionalist Government of Mexico , Washington , December 16, 1914 . Mr. Secretary : I have the honor to enclose herewith copy in translation o…
3. **No. 385. Mr. de Zamacona to Mr. Evarts .** — Legation of Mexico in the United States , Washington , July 31, 1878 . (Received August 3.)  
   `frus1878/d390` · score 0.5928  
   > No. 385. Mr. de Zamacona to Mr. Evarts . [Translation.] Legation of Mexico in the United States , Washington , July 31, 1878 . (Received August 3.) Mr. Secretary : The allusion contained in one of the notes with which I have recently been h…
4. **No. 213. Mr. Foster to Mr. Fish .** — Legation of the United States , Mexico , April 22, 1876 . (Received May 8.)  
   `frus1876/d223` · score 0.5899  
   > No. 213. Mr. Foster to Mr. Fish . Legation of the United States , Mexico , April 22, 1876 . (Received May 8.) No. 403.] Sir : The revolution has steadily increased since the date of my last dispatch on current events, and is to-day stronger…
5. **Memorandum by the Under Secretary of State ( Clark )** — [ Washington ,] March 5, 1929 .  
   `frus1929v03/d381` · score 0.5871  
   > 812.00/29464 Memorandum by the Under Secretary of State ( Clark ) [ Washington ,] March 5, 1929 . The Present Situation A. In July last, Obregon, who had been elected President of Mexico to succeed Calles was assassinated. He would have tak…
6. **Vice Consul Blocker to the Secretary of State** — Eagle Pass , December 7, 1916 .  
   `frus1916/d815` · score 0.5865  
   > File No. 312.11/8274 Vice Consul Blocker to the Secretary of State [Extract] No. 1097 Eagle Pass , December 7, 1916 . Sir : * * * Enclosed is an original [manifesto] to the people of Mexico, signed by General Villa, at San Andres, Chihuahua…
7. **The American Ambassador to the Secretary of State .** — American Embassy , Mexico , July 11, 1911 .  
   `frus1911/d764` · score 0.5839  
   > File No. 812.00/2219. The American Ambassador to the Secretary of State . American Embassy , Mexico , July 11, 1911 . My Dear Mr. Knox : The fears expressed in my confidential dispatches of May 23 Not printed. and May 31 Not printed. that t…
8. **The American Ambassador to the Secretary of State .** — American Embassy , Mexico , November 26, 1910 .  
   `frus1911/d479` · score 0.5822  
   > File No. 812.00/517. The American Ambassador to the Secretary of State . American Embassy , Mexico , November 26, 1910 . No. 272.] Sir : As supplementary to telegrams of November 18 [and others subsequent], I have the honor to call the atte…
9. **The American Ambassador to the Secretary of State .** — American Embassy , Mexico , February 4, 1913 .  
   `frus1913/d785` · score 0.5805  
   > File No. 812.00/6.068. The American Ambassador to the Secretary of State . [Extract.] American Embassy , Mexico , February 4, 1913 . My Dear Mr. Knox : Upon resuming my duties at this post after an absence of two months Mr. Wilson resumed c…
10. **The Acting Secretary for Foreign Affairs of the Vásquez Gómez-Provisional Government to the Secretary of State .** — Palomas, Chihuahua , February 25, 1913 .  
   `frus1913/d876` · score 0.5800  
   > File No. 812.00/6534. The Acting Secretary for Foreign Affairs of the Vásquez Gómez-Provisional Government to the Secretary of State . Received March 6; communicated to the Ambassador March 17; filed March 21. [Translation.] Palomas, Chihua…

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 5/10, bare: 6/10.*
*document variant:* frus1916/d815, frus1915/d991, frus1914/d976, frus1865p3/d454, frus1868p2/d332, frus1868p2/d296, frus1878/d390, frus1867p2/d419, frus1911/d479, frus1866p3/d99
*bare variant:* frus1915/d991, frus1914/d976, frus1929v03/d430, frus1915/d905, frus1917/d1147, frus1929v03/d381, frus1876/d223, frus1911/d479, frus1912/d905, frus1878/d390

---

## Q6. When did U.S. diplomats realize that Hitler was a serious danger to the United States?

### Lexical — `"when" AND "did" AND "u.s." AND "diplomats" AND "realize" AND "that" AND "hitler" AND "was" AND "a" AND "serious" AND "danger" AND "to" AND "the" AND "united" AND "states?"`

1. **263. Record of the Meeting Between Secretary of State Dulles and President Tito on the Island of Vanga, November 6, 1955, 3–5:40 p.m.** — Island of Vanga , November 6, 1955, 3–5:40 p.m.  
   `frus1955-57v26/d263` · score -13.7550  
   > 263. Record of the Meeting Between Secretary of State Dulles and President Tito on the Island of Vanga, November 6, 1955, 3–5:40 p.m. Source: Department of State, Secretary’s Memoranda of Conversation: Lot 64 D 199, Yugoslavia. Secret. Draf…
2. **208. Paper Prepared in the National Security Council** — Washington , undated  
   `frus1981-88v01/d208` · score -13.6773  
   > 208. Paper Prepared in the National Security Council Source: Reagan Library, European and Soviet Affairs Directorate, NSC Records, Subject File, NSC General (2); NLR–170–11–19–8–2. No classification marking. Lenczowski sent the paper to McF…
3. **No. 529 Memorandum of Discussion at the 186th Meeting of the National Security Council, Friday, February 26, 1954** — February 26, 1954  
   `frus1952-54v07p1/d529` · score -12.4781  
   > Eisenhower Library, Eisenhower papers, Whitman file No. 529 Memorandum of Discussion at the 186th Meeting of the National Security Council, Friday, February 26, 1954 top secret eyes only February 26, 1954 Present at this meeting were the Pr…
4. **No. 33 The Chairman of the President’s War Relief Control Board ( Davies ) to the President** — Washington , June 12, 1945 .  
   `frus1945Berlinv01/d33` · score -11.6641  
   > 740.00119 Potsdam/7–345 No. 33 The Chairman of the President’s War Relief Control Board This was Davies ’ only official position in the United States Government at this time, although he acted as an adviser to the President before and durin…
5. **United States Delegation Minutes** — Bermuda , December 7, 1953 .  
   `frus1952-54v05p2/d357` · score -11.5988  
   > Conference files, lot 60 D 627, CF 185 United States Delegation Minutes The U.S. Delegation transmitted to Washington a summary of this meeting in Secto 24 from Bermuda, Dec. 7. This telegram was repeated to London, Paris, Bonn, and Moscow.…
6. **58. Memorandum of Conversation** — Beijing , November 12, 1973, 5:40–8:25 p.m.  
   `frus1969-76v18/d58` · score -10.8350  
   > 58. Memorandum of Conversation Source: National Archives, Nixon Presidential Materials, NSC Files, Kissinger Office Files, Box 100, Country Files, Far East, Secretary Kissinger ’s Conversations in Peking, November 1973. Top Secret; Sensitiv…
7. **219. Address by Secretary of Defense Weinberger** — Washington , November 28, 1984  
   `frus1981-88v01/d219` · score -10.7969  
   > 219. Address by Secretary of Defense Weinberger Source: News Release, Office of Assistant Secretary of Defense (Public Affairs), No. 609–84, November 28, 1984; Public Statements of Caspar W. Weinberger , Secretary of Defense, 1984 , vol. IV…
8. **9. Memorandum of Conversation** — Beijing , February 16, 1973, 2:15–6:00 p.m.  
   `frus1969-76v18/d9` · score -10.3686  
   > 9. Memorandum of Conversation Source: National Archives, Nixon Presidential Materials, NSC Files, Kissinger Office Files, Box 98, Country Files, Far East, HAK China Trip, Memcons & Reports (originals), February 1973. Top Secret; Sensitive; …
9. **71. Memorandum of Conversation** — Helsinki , July 31, 1985, 2–5 p.m.  
   `frus1981-88v05/d71` · score -10.1172  
   > 71. Memorandum of Conversation Source: Reagan Library, Jack Matlock Files, US - USSR Summits, 1985–1986, F.2, Memcons — Shultz / Shevardnadze Meetings Helsinki and New York. Secret; Super Sensitive. The meeting took place at the U.S. Ambass…
10. **271. Memorandum of Conversation** — Moscow , May 24, 1972, 7:50–11 p.m.  
   `frus1969-76v14/d271` · score -10.0963  
   > 271. Memorandum of Conversation Source: National Archives, Nixon Presidential Materials, NSC Files, Box 487, President’s Trip Files, The President’s Conversations in Salzburg, Moscow, Tehran, and Warsaw, May 1972, Part 2. Top Secret; Sensit…

### Semantic (query prompt)

1. **The Ambassador in Uruguay ( Dawson ) to the Secretary of State** — Montevideo , November 13, 1942—3 p.m. [Received 7:40 p.m.]  
   `frus1942v05/d78` · score 0.5984  
   > 740.0011 European War 1939/25630: Telegram The Ambassador in Uruguay ( Dawson ) to the Secretary of State Montevideo , November 13, 1942—3 p.m. [Received 7:40 p.m.] 996. For the Under Secretary from Spaeth No. 43. Reference is made to the s…
2. **The Acting Secretary of State to the Ambassador in the Soviet Union ( Steinhardt )** — [ Washington ,] June 23, 1941 .  
   `frus1941v01/d725` · score 0.5971  
   > 740.0011 European War 1939/12385a: Telegram The Acting Secretary of State to the Ambassador in the Soviet Union ( Steinhardt ) [ Washington ,] June 23, 1941 . 836. At a press conference held today the Acting Secretary, Welles, made the foll…
3. **The Secretary of State to the Chargé in Germany ( Mayer )** — Washington , August 5, 1936 .  
   `frus1936v01/d265` · score 0.5953  
   > 761.62/389a The Secretary of State to the Chargé in Germany ( Mayer ) No. 650 Washington , August 5, 1936 . Sir : The Department is greatly interested in determining the attitude, policies and plans of the present Government and leaders in …
4. **The Ambassador in Germany ( Dodd ) to the Secretary of State** — Berlin , March 8, 1934 . [Received March 17.]  
   `frus1934v02/d413` · score 0.5930  
   > 862.002 Hitler, Adolf/34 The Ambassador in Germany ( Dodd ) to the Secretary of State No. 600 Berlin , March 8, 1934 . [Received March 17.] Sir : Referring to my confidential telegram No. 48, of March 6, 12 noon, I have the honor to enclose…
5. **Memorandum of Conversation, by the Ambassador in Germany ( Wilson )** — March 22, 1938  
   `frus1938v02/d356` · score 0.5922  
   > 711.62/145 Memorandum of Conversation, by the Ambassador in Germany ( Wilson ) Transmitted to the Department by the Ambassador in Germany in his despatch No. 41, March 23; received April 11. March 22, 1938 Dr. Goebbels received me in his of…
6. **The Ambassador in France ( Bullitt ) to the Secretary of State** — Paris , September 19, 1939—noon . [Received 12:58 p.m.]  
   `frus1939v01/d718` · score 0.5892  
   > 740.00/2138: Telegram The Ambassador in France ( Bullitt ) to the Secretary of State Paris , September 19, 1939—noon . [Received 12:58 p.m.] 2050. Personal for the President. I now have in written form the report made in Vienna on March 12t…
7. **Memorandum by the Ambassador in Germany ( Wilson ) of a Conversation With the German Minister for Foreign Affairs ( Ribbentrop )**  
   `frus1938v02/d357` · score 0.5891  
   > 711.62/150 Memorandum by the Ambassador in Germany ( Wilson ) of a Conversation With the German Minister for Foreign Affairs ( Ribbentrop ) Transmitted to the Department by the Ambassador in Germany in his despatch No. 125, May 2; received …
8. **Memorandum of Conversation, by the Under Secretary of State ( Welles )** — [ Washington ,] March 14, 1938 .  
   `frus1938v01/d459` · score 0.5880  
   > 863.00/1436½ Memorandum of Conversation, by the Under Secretary of State ( Welles ) [ Washington ,] March 14, 1938 . The German Ambassador Hans Heinrich Dieckhoff. came in to see me this evening immediately after leaving the Secretary of St…
9. **Memorandum by the Secretary of State** — [ Washington ,] March 17, 1937 .  
   `frus1937v02/d277` · score 0.5870  
   > 862.002 Hitler, Adolf/122 Memorandum by the Secretary of State [ Washington ,] March 17, 1937 . The German Ambassador called upon his own request at 3:00 o’clock this afternoon. He proceeded to detail and to emphasize the deepseated feeling…
10. **The Chargé in Germany ( Kirk ) to the Secretary of State** — Berlin , April 17, 1940—noon . [Received 6:05 p.m.]  
   `frus1940v01/d83` · score 0.5827  
   > 740.0011 European War 1939/2286: Telegram The Chargé in Germany ( Kirk ) to the Secretary of State Berlin , April 17, 1940—noon . [Received 6:05 p.m.] 1017. For the Secretary and Under Secretary. Within the last few days I have spoken with …

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 5/10.*
*document variant:* frus1942v05/d78, frus1936v01/d265, frus1941v01/d725, frus1940v01/d83, frus1934v02/d413, frus1934v02/d407, frus1940v02/d680, frus1937v01/d29, frus1939v01/d156, frus1938v02/d356
*bare variant:* frus1941v01/d725, frus1942v05/d78, frus1940v01/d83, frus1936v01/d265, frus1939v01/d718, frus1942v05/d247, frus1942v01/d242, frus1958-60v09/d41, frus1941v04/d25, frus1955-57v20/d229

---

## Q7. Intelligence collaboration

### Lexical — `"intelligence" AND "collaboration"`

1. **422. National Security Council Intelligence Directive No. 4** — Washington , December 12, 1947 .  
   `frus1945-50Intel/d422` · score -11.6651  
   > 422. National Security Council Intelligence Directive No. 4 Source: National Archives and Records Administration, RG 59, Records of the Department of State, Records of the Executive Secretariat, NSC Files: Lot 66 D 148, Dulles – Jackson – C…
2. **The Ambassador in Burma ( Key ) to the Secretary of State** — Rangoon , June 28, 1951—3 p. m.  
   `frus1951v06p1/d129` · score -11.6189  
   > 790B.00/6–2851: Telegram The Ambassador in Burma ( Key ) to the Secretary of State secret Rangoon , June 28, 1951—3 p. m. 966. Deptel 891, June 22. The Embassy in Burma was requested in telegram 891 to Rangoon, June 22 (not printed), to pro…
3. **200. Director of Central Intelligence Directive No. 4/3** — Washington , December 14, 1954 .  
   `frus1950-55Intel/d200` · score -11.5257  
   > 200. Director of Central Intelligence Directive No. 4/3 Source: National Archives, RG 59, S/P– NSC Files: Lot 62 D 1, NSC Intelligence Directives. Secret. DCID 4/3 and DCID 4/4 ( Document 201 ) were attached to a single cover page, which in…
4. **Memorandum for the National Security Council by the Executive Secretary ( Lay )** — Washington , May 23, 1951 .  
   `frus1951v01/d18` · score -11.3848  
   > S/S– NSC Files, Lot 63 D 351, NSC 90 Series Memorandum for the National Security Council by the Executive Secretary ( Lay ) secret Washington , May 23, 1951 . Subject: Collaboration With Friendly Governments on Exchange of Information Conce…
5. **97. National Intelligence Estimate** — Washington , February 7, 1956 .  
   `frus1955-57v27/d97` · score -11.3230  
   > 97. National Intelligence Estimate Source: Department of State, INR– NIE Files. Secret. An attached chart showing the party composition of the Italian Chamber of Deputies as of January 1, 1956, is not printed. According to a note on the cov…
6. **President Sergio Osmeña of the Philippines to the Secretary of the Interior ( Ickes )** — Manila , September 12, 1945 .  
   `frus1945v06/d914` · score -11.0833  
   > 811B.00/9–1945: Telegram President Sergio Osmeña of the Philippines to the Secretary of the Interior ( Ickes ) Manila , September 12, 1945 . In reply to your telegram of September 11 I desire to state that information given you that I inten…
7. **30. Memorandum From the Assistant Chief of Staff for Military Intelligence of the War Department General Staff ( Bissell ) to Secretary of War Patterson** — Washington , October 22, 1945 .  
   `frus1945-50Intel/d30` · score -10.9212  
   > 30. Memorandum From the Assistant Chief of Staff for Military Intelligence of the War Department General Staff ( Bissell ) to Secretary of War Patterson Source: National Archives and Records Administration, RG 263, Records of the Central In…
8. **413. Memorandum From the Acting Chairman of the National Security Resources Board ( Steelman ) to the Executive Secretary of the National Security Council ( Souers )** — Washington , February 2, 1950 .  
   `frus1945-50Intel/d413` · score -10.9163  
   > 413. Memorandum From the Acting Chairman of the National Security Resources Board ( Steelman ) to the Executive Secretary of the National Security Council ( Souers ) Source: Truman Library, Papers of Harry S. Truman , President’s Secretary’…
9. **213. National Intelligence Estimate** — Washington , July 7, 1966 .  
   `frus1964-68v24/d213` · score -10.7431  
   > 213. National Intelligence Estimate Source: Central Intelligence Agency: Job 79–R01012A, ODDI Registry of NIE and SNIE Files. Secret; Controlled Dissem. According to a note on the cover sheet, the estimate was submitted by Director of Centr…
10. **The Consul General at Manila ( Steintorf ) to the Secretary of State** — Manila , September 5, 1945—9 a.m. [Received September 5—3:50 a.m.]  
   `frus1945v06/d911` · score -10.7377  
   > 811B.00/9–545: Telegram The Consul General at Manila ( Steintorf ) to the Secretary of State Manila , September 5, 1945—9 a.m. [Received September 5—3:50 a.m.] 617. President Osmeña after conferring with Council of State issued Executive Or…

### Semantic (query prompt)

1. **41. Memorandum From the President’s Assistant for National Security Affairs ( Brzezinski )** — Washington , May 31, 1977  
   `frus1977-80v28/d41` · score 0.6106  
   > 41. Memorandum From the President’s Assistant for National Security Affairs ( Brzezinski ) Source: Central Intelligence Agency, Office of the Director of Central Intelligence, Job 97M00248R: Policy Files, Office Level and Above, Box 1, Fold…
2. **221. Report by the Commission on Organization of the Executive Branch of the Government to the Congress** — Washington , June 1955 .  
   `frus1950-55Intel/d221` · score 0.6049  
   > 221. Report by the Commission on Organization of the Executive Branch of the Government to the Congress Source: Central Intelligence Agency, Executive Registry, Job 86–B00269R, Box 14. Unclassified. The title page of Part II bears the date …
3. **358. Report From the Intelligence Survey Group to the National Security Council** — Washington , January 1, 1949 .  
   `frus1945-50Intel/d358` · score 0.5907  
   > 358. Report From the Intelligence Survey Group to the National Security Council Source: National Archives and Records Administration, RG 59, Records of the Department of State, Records of the Executive Secretariat, NSC Files: Lot 66 D 148, …
4. **62. Message From Director of Central Intelligence Turner to Chiefs of Station** — Washington , October 4, 1977  
   `frus1977-80v28/d62` · score 0.5886  
   > 62. Message From Director of Central Intelligence Turner to Chiefs of Station Source: Department of State, INR/IL Historical Files, TIN: 980643000017, State- CIA Relations, January–May 1978. Secret; Priority; Unintel Rybat; [ handling restr…
5. **202. Paper by James Q. Reber of the Planning and Coordination Staff of the Central Intelligence Agency** — Washington , December 23, 1954 .  
   `frus1950-55Intel/d202` · score 0.5843  
   > 202. Paper by James Q. Reber of the Planning and Coordination Staff of the Central Intelligence Agency Source: National Archives, RG 59, INR Files: Lot 58 D 776, Collection and Dissemination. Secret. Washington , December 23, 1954 . INTELLI…
6. **35. Memorandum From the Assistant Director for Administrative Management, Bureau of the Budget ( Stone ) to the Assistant Director, Bureau of the Budget ( Appleby )** — Washington , October 26, 1945 .  
   `frus1945-50Intel/d35` · score 0.5832  
   > 35. Memorandum From the Assistant Director for Administrative Management, Bureau of the Budget ( Stone ) to the Assistant Director, Bureau of the Budget ( Appleby ) Source: National Archives and Records Administration, RG 51, Records of the…
7. **50. Paper Prepared in the Department of Defense** — Washington , undated  
   `frus1977-80v28/d50` · score 0.5826  
   > 50. Paper Prepared in the Department of Defense Source: Central Intelligence Agency, Office of the Director of Central Intelligence, Job 97M00248R: Policy Files, Office Level and Above, Box 2, Folder 16: Intelligence Structure and Mission (…
8. **247. Memorandum From the Director of the Bureau of Intelligence and Research ( Cline ) to the Under Secretary of State ( Irwin )** — Washington , December 1, 1971 .  
   `frus1969-76v02/d247` · score 0.5805  
   > 247. Memorandum From the Director of the Bureau of Intelligence and Research ( Cline ) to the Under Secretary of State ( Irwin ) Source: Department of State, INR/IL Historical Files, Functions and Responsibilities, 1965–1986. Washington , D…
9. **70. Memorandum From the Director of the Bureau of the Budget ( Smith ) to the President’s Special Counsel ( Rosenman )** — Washington , January 10, 1946 .  
   `frus1945-50Intel/d70` · score 0.5788  
   > 70. Memorandum From the Director of the Bureau of the Budget ( Smith ) to the President’s Special Counsel ( Rosenman ) Source: Truman Library, Papers of Samuel I. Rosenman , Subject File— OSS , 1946. Confidential. Washington , January 10, 1…
10. **17. Memorandum From Attorney General Clark to President Truman** — Washington , undated .  
   `frus1945-50Intel/d17` · score 0.5772  
   > 17. Memorandum From Attorney General Clark to President Truman Source: National Archives and Records Administration, RG 51, Records of the Office of Management and Budget, Director’s Files, Series 39.27, Intelligence. Secret. In a covering …

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 7/10.*
*document variant:* frus1977-80v28/d41, frus1950-55Intel/d221, frus1969-76v02/d247, frus1977-80v28/d62, frus1969-76v02/d229, frus1945-50Intel/d35, frus1950-55Intel/d202, frus1945-50Intel/d358, frus1977-80v28/d42, frus1977-80v28/d50
*bare variant:* frus1977-80v28/d41, frus1977-80v28/d62, frus1977-80v28/d50, frus1950-55Intel/d202, frus1977-80v28/d42, frus1950v04/d156, frus1969-76v02/d247, frus1950-55Intel/d221, frus1977-80v28/d37, frus1945-50Intel/d17

---

## Q8. How did the United States collaborate with Great Britain to conduct economic warfare during World War II?

### Lexical — `"how" AND "did" AND "the" AND "united" AND "states" AND "collaborate" AND "with" AND "great" AND "britain" AND "to" AND "conduct" AND "economic" AND "warfare" AND "during" AND "world" AND "war" AND "ii?"`

1. **271. Draft Paper, June 22** — June 22, 1962  
   `frus1961-63v07-09mSupp/d271` · score -14.8967  
   > 271. Draft Paper, June 22 “Basic National Security Policy.” Printed in part in the print volume as Document 93 . Secret. 186 pp. Department of State, S/P Files: Lot 69 D 121, BNSP Draft 6/22/62. June 22, 1962 BASIC NATIONAL SECURITY POLICY …
2. **299. Minutes of a Meeting of the Secretary of State’s Open Forum** — Washington , May 11, 1987  
   `frus1981-88v01/d299` · score -14.7796  
   > 299. Minutes of a Meeting of the Secretary of State’s Open Forum Source: Department of State, S/P Files, Open Forum Program—Chronological Files and Journals, Lot 92D97, 40 th Anniversary of S/P 5/11/87. No classification marking. Printed fr…
3. **Notes of a Meeting Held at President Wilson’s House in the Place des Etats-Unis, Paris, on Tuesday, May 20, 1919, at 11 a.m.** — Paris , May 20, 1919, 11 a.m.  
   `frus1919Parisv05/d76` · score -14.2360  
   > Paris Peace Conf. 180.03401/20 CF–20 Notes of a Meeting Held at President Wilson’s House in the Place des Etats-Unis, Paris, on Tuesday, May 20, 1919, at 11 a.m. Paris , May 20, 1919, 11 a.m. Present United States of America President Wilso…
4. **Memorandum Prepared in the Department of State** — [ Washington ,] May 19, 1942 .  
   `frus1931-41v02/d237` · score -14.0788  
   > 711.94/2651½ Memorandum Prepared in the Department of State [ Washington ,] May 19, 1942 . ACCOUNT OF INFORMAL CONVERSATIONS BETWEEN THE GOVERNMENT OF THE UNITED STATES AND THE GOVERNMENT OF JAPAN, 1941 Introductory As the year 1941 opened,…
5. **Memorandum of Conversation, Prepared in the Department of State** — January 6 and 7, 1951 . January 12 and 13, 1951 .  
   `frus1951v07p2/d2` · score -12.8215  
   > S/P Files: Lot 64 D 563 Memorandum of Conversation, Prepared in the Department of State This is the first of a series of unsigned memoranda, most or all of which were written by Charles Burton Marshall of the Policy Planning Staff. Accordin…
6. **United States Delegation Minutes, Third Formal Session, Conference of Foreign Ministers, Spiridonovka, Moscow, December 18, 1945, 4:00–7:15 p. m.** — Moscow , December 18, 1945, 4:00–7:15 p.m.  
   `frus1945v02/d235` · score -12.5981  
   > 740.00119 Council/12–2645 United States Delegation Minutes, Third Formal Session, Conference of Foreign Ministers, Spiridonovka, Moscow, December 18, 1945, 4:00–7:15 p. m. A brief report on this meeting was transmitted to Washington by the …
7. **Memorandum Prepared in the Department of State** — [ Washington , undated .]  
   `frus1947v05/d395` · score -11.4357  
   > NEA Files: Lot 55–D36 Memorandum Prepared in the Department of State top secret [ Washington , undated .] Specific Current Questions [Here follow a table of contents and a note which states: “The material included in this section was prepar…
8. **193. Memorandum From Acting Director of Central Intelligence Gates to the President’s Assistant for National Security Affairs ( Carlucci )** — Washington , January 15, 1987  
   `frus1981-88v44p1/d193` · score -11.1785  
   > 193. Memorandum From Acting Director of Central Intelligence Gates to the President’s Assistant for National Security Affairs ( Carlucci ) Source: Reagan Library, William Tobey Files, Subject File, Sov ABM Breakout (3 of 4). Secret; [ handl…
9. **The Military Representative on the Supreme War Council ( Bliss ) to the Secretary of State** — Washington , February 19, 1920 .  
   `frus1914-20v02/d147` · score -10.5685  
   > 763.72 Su/99 The Military Representative on the Supreme War Council ( Bliss ) to the Secretary of State Washington , February 19, 1920 . Sir : I have the honor to submit, herewith, my report on the Supreme War Council. A duplicate copy has …
10. **22. Draft Report Prepared by Lincoln Bloomfield , Special Assistant to the Assistant Secretary of State for International Organization Affairs** — Washington , February 9, 1956 .  
   `frus1955-57v11/d22` · score -10.2681  
   > 22. Draft Report Prepared by Lincoln Bloomfield , Special Assistant to the Assistant Secretary of State for International Organization Affairs Source: Department of State, IO Files: Lot 60 D 113, Studies US Policy re UN . Confidential. The …

### Semantic (query prompt)

1. **Memorandum by the Secretary of State to President Roosevelt** — Washington , September 8, 1944 .  
   `frus1944v03/d19` · score 0.6428  
   > Memorandum by the Secretary of State to President Roosevelt Copy obtained from the Franklin D. Roosevelt Library, Hyde Park, N.Y. Washington , September 8, 1944 . Lend-Lease and General Economic Relations with the United Kingdom in “Phase 2…
2. **The Secretary of State to the President** — Washington , September 8, 1944 .  
   `frus1944Quebec/d110` · score 0.6325  
   > Roosevelt Papers The Secretary of State to the President Washington , September 8, 1944 . Lend-Lease and General Economic Relations With the United Kingdom in “Phase 2” 1. The most important international economic problem of the transition …
3. **The Secretary of State to the Diplomatic Representatives in the American Republics Except Argentina** — Washington , December 7, 1943 .  
   `frus1944v07/d1457` · score 0.6262  
   > 740.00112 RP/3 The Secretary of State to the Diplomatic Representatives in the American Republics Except Argentina Washington , December 7, 1943 . Sirs : During the past years this Government has inaugurated many programs directed at implem…
4. **The Secretary of State to the Ambassador in the United Kingdom ( Winant )** — Washington , September 19, 1944—12:40 p.m.  
   `frus1944v03/d22` · score 0.6248  
   > 841.24/9–1644: Airgram The Secretary of State to the Ambassador in the United Kingdom ( Winant ) Washington , September 19, 1944—12:40 p.m. A–1843. At the President’s request I am repeating to you herein a memorandum to me from the Presiden…
5. **Memorandum by Mr. Howard J. Trueblood of the Office of the Adviser on International Economic Affairs** — [ Washington ,] November 12, 1940 .  
   `frus1940v04/d657` · score 0.6216  
   > 811.20 (D) Regulations/1004 Memorandum by Mr. Howard J. Trueblood of the Office of the Adviser on International Economic Affairs Assistant Secretary of State Grady on November 19 added a notation as follows: “I feel that our reply to the Br…
6. **Memorandum by the Secretary of State to President Roosevelt** — Washington , September 30, 1944 .  
   `frus1944v03/d23` · score 0.6175  
   > 840.50/9–3044 Memorandum by the Secretary of State to President Roosevelt Handed to the President by the Secretary of State, October 1, 1944. Washington , September 30, 1944 . You will recall my memorandum of September 2, 1944, Not printed.…
7. **The British Ambassador ( Lothian ) to the Secretary of State**  
   `frus1940v03/d84` · score 0.6167  
   > 641.116/2612½ The British Ambassador ( Lothian ) to the Secretary of State Memorandum The British Ambassador appreciates the understanding shown in Mr. Cordell Hull’s memorandum of February 21st, 1940, of the grave conditions with which Gre…
8. **Memorandum of Conversation, by the Secretary of State** — [ Washington ,] July 5, 1940 .  
   `frus1940v03/d38` · score 0.6124  
   > 740.0011 European War 1939/4578 Memorandum of Conversation, by the Secretary of State [ Washington ,] July 5, 1940 . The British Ambassador called at his request and handed me an aide-mémoire dated July 3, 1940 (copy attached), which review…
9. **The Department of State to the British Embassy** — [ Washington ,] February 21, 1940 .  
   `frus1940v03/d82` · score 0.6067  
   > 641.116/2621 The Department of State to the British Embassy [ Washington ,] February 21, 1940 . Memorandum It is recognized that the British Ambassador’s memorandum of February 14, as amended by the memorandum of February 16, Neither memora…
10. **Department of State Policy Statement** — Washington , June 11, 1948 .  
   `frus1948v03/d679` · score 0.6063  
   > Berlin Mission Files: Lot F–169: Box 34 Department of State Policy Statement Department of State Policy Statements were concise summaries of current United States policy toward a country or region, relations of that country or region with t…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 8/10.*
*document variant:* frus1944v03/d19, frus1944Quebec/d110, frus1944v07/d1457, frus1940v03/d84, frus1944v03/d23, frus1940v03/d82, frus1948v03/d679, frus1944v03/d22, frus1944v03/d30, frus1942v01/d142
*bare variant:* frus1944v03/d19, frus1944Quebec/d110, frus1944v07/d1457, frus1940v04/d657, frus1944v03/d22, frus1940v03/d38, frus1917Supp02v02/d19, frus1944v03/d23, frus1943v03/d39, frus1948v03/d679

---

## Q9. Foreign Service reform

### Lexical — `"foreign" AND "service" AND "reform"`

1. **338. Action Memorandum From the Chairman of the Secretary’s Open Forum Panel, Department of State ( Thomas ) to the Deputy Under Secretary of State for Administration ( Macomber )** — Washington , October 20, 1971 .  
   `frus1969-76v02/d338` · score -11.6477  
   > 338. Action Memorandum From the Chairman of the Secretary’s Open Forum Panel, Department of State ( Thomas ) to the Deputy Under Secretary of State for Administration ( Macomber ) Source: National Archives, RG 59, Office of the Deputy Under…
2. **Preface**  
   `frus1977-80v28/preface` · score -11.4344  
   > Preface Structure and Scope of the Foreign Relations Series This volume is part of a subseries of volumes of the Foreign Relations series that documents the most important issues in the foreign policy of the administration of Jimmy Carter .…
3. **No. 201. Mr. Francis to Mr. Fish .** — Legation of the United States , Athens , June 29, 1872 . (Received July 22.)  
   `frus1872p1/d201` · score -11.1945  
   > No. 201. Mr. Francis to Mr. Fish . Legation of the United States , Athens , June 29, 1872 . (Received July 22.) No. 64.] Sir : I have the honor to transmit herewith a copy of a letter addressed by me to Mr. Mélétopoulo, secretary-general of…
4. **171. Memorandum From the Senior Officer Bunch to the Under Secretary of State for Management ( Read ) and the Director General of the Foreign Service and Director of Personnel ( Barnes )** — Washington , undated  
   `frus1977-80v28/d171` · score -11.1292  
   > 171. Memorandum From the Senior Officer Bunch to the Under Secretary of State for Management ( Read ) and the Director General of the Foreign Service and Director of Personnel ( Barnes ) Source: National Archives, RG 59, Records of the Unde…
5. **153. Memorandum From the Director of the Office of Civil Service Career Development and Assignments ( Bourbon ) to the Director General of the Foreign Service and Director of Personnel ( Barnes )** — Washington , June 2, 1978  
   `frus1977-80v28/d153` · score -10.8338  
   > 153. Memorandum From the Director of the Office of Civil Service Career Development and Assignments ( Bourbon ) to the Director General of the Foreign Service and Director of Personnel ( Barnes ) Source: National Archives, RG 59, Records of…
6. **326. Memorandum From Mary S. Olmsted of the Ad Hoc Women’s Committee, Department of State to Chris Petrow of the Office of the Deputy Under Secretary of State for Administration** — Washington , October 7, 1970 .  
   `frus1969-76v02/d326` · score -10.6314  
   > 326. Memorandum From Mary S. Olmsted of the Ad Hoc Women’s Committee, Department of State to Chris Petrow of the Office of the Deputy Under Secretary of State for Administration Source: National Archives, RG 59, Office of the Deputy Under S…
7. **155. Memorandum From the Director of the Office of Civil Service Career Development and Assignments ( Bourbon ) to the Director General of the Foreign Service and Director of Personnel ( Barnes )** — Washington , August 4, 1978  
   `frus1977-80v28/d155` · score -10.6090  
   > 155. Memorandum From the Director of the Office of Civil Service Career Development and Assignments ( Bourbon ) to the Director General of the Foreign Service and Director of Personnel ( Barnes ) Source: National Archives, RG 59, Records of…
8. **339. Memorandum From the Chairman of the Department of State Task Force VII Committee ( Petrow ) to the Deputy Under Secretary of State for Management ( Macomber )** — Washington , December 21, 1971 .  
   `frus1969-76v02/d339` · score -10.5808  
   > 339. Memorandum From the Chairman of the Department of State Task Force VII Committee ( Petrow ) to the Deputy Under Secretary of State for Management ( Macomber ) Source: National Archives, RG 59, Office of the Deputy Under Secretary for M…
9. **256. Paper Prepared in the Department of the Treasury** — Washington , undated  
   `frus1981-88v38/d256` · score -10.4898  
   > 256. Paper Prepared in the Department of the Treasury Source: National Archives, RG 56, Records of the Office of the Secretary of the Treasury, Congressional Correspondence, 1988, UD–10, 56–10–1, Box 35, Group Letters S/, Current Approach t…
10. **The Chief of the Division of Latin American Affairs, Department of State ( Munro ) to the Secretary of State** — [ Washington ,] April 10, 1922 .  
   `frus1922v01/d839` · score -10.4425  
   > 837.51/756 The Chief of the Division of Latin American Affairs, Department of State ( Munro ) to the Secretary of State [ Washington ,] April 10, 1922 . Dear Mr. Secretary : In the attached despatch Despatch of Apr. 9, supra. and telegram, …

### Semantic (query prompt)

1. **158. Report to Congress Prepared in the Department of State** — Washington , January 10, 1977 .  
   `frus1969-76v38p2/d158` · score 0.6886  
   > 158. Report to Congress Prepared in the Department of State Source: Department of State, Policy and Procedural Files of the Deputy Under Secretary for Management: Lot 79 D 63, M Chron, January 1977 D. No classification marking. Eagleburger …
2. **164. Memorandum From the Director of the Office of UN Political Affairs (Bridges) to the Under Secretary of State for Management ( Read ) and the Director General of the Foreign Service and Director of Personnel ( Barnes )** — Washington , January 24, 1979  
   `frus1977-80v28/d164` · score 0.6806  
   > 164. Memorandum From the Director of the Office of UN Political Affairs (Bridges) to the Under Secretary of State for Management ( Read ) and the Director General of the Foreign Service and Director of Personnel ( Barnes ) Source: National …
3. **144. Memorandum of Conversation** — Washington , June 5, 1975, 6:30–7:30 p.m.  
   `frus1969-76v38p2/d144` · score 0.6663  
   > 144. Memorandum of Conversation Source: Department of State, Files of Lawrence S. Eagleburger : Lot 84 D 204, Chron—June 1975. Confidential. Drafted by Wesley Egan (S). The meeting was held in Kissinger ’s office at the Department of State.…
4. **181. Letter From the Under Secretary of State for Management ( Read ) to the Director of the Office of Management and Budget (McIntyre)** — Washington , October 6, 1980  
   `frus1977-80v28/d181` · score 0.6593  
   > 181. Letter From the Under Secretary of State for Management ( Read ) to the Director of the Office of Management and Budget (McIntyre) Source: National Archives, RG 59, Records of the Under Secretary for Management (M), 1980, Box 7, Chron …
5. **223. Briefing Paper Prepared in the Department of State** — Washington , undated .  
   `frus1969-76v38p2/d223` · score 0.6568  
   > 223. Briefing Paper Prepared in the Department of State Source: National Archives, RG 59, Transition Records of the Executive Secretariat, 1959–1977, Entry 5338, Box 1, Transition Material to S/CL —Mr. Lake from Bureaus. No classification m…
6. **161. Memorandum From the Director General of the Foreign Service and Director of Personnel ( Barnes ) to Secretary of State Vance** — Washington , January 25, 1978  
   `frus1977-80v28/d161` · score 0.6493  
   > 161. Memorandum From the Director General of the Foreign Service and Director of Personnel ( Barnes ) to Secretary of State Vance Source: National Archives, RG 59, Records of the Under Secretary for Management (M), 1977–1978, Box 8, Chron J…
7. **154. Memorandum From the Director General of the Foreign Service ( Laise ) to the Deputy Under Secretary of State for Management ( Eagleburger )** — Washington , undated .  
   `frus1969-76v38p2/d154` · score 0.6448  
   > 154. Memorandum From the Director General of the Foreign Service ( Laise ) to the Deputy Under Secretary of State for Management ( Eagleburger ) Source: Department of State, Administrative Correspondence Files 1969–77, Policy and Procedural…
8. **55. Memorandum From the President’s Special Representative ( Bowles ) to President Kennedy** — Washington , May 25, 1962 .  
   `frus1961-63v25/d55` · score 0.6430  
   > 55. Memorandum From the President’s Special Representative ( Bowles ) to President Kennedy Source: Kennedy Library, National Security Files, Departments and Agencies Series, Department of State, General, 5/18/62–5/25/62. Limited Official Us…
9. **174. Airgram From the Department of State to All Diplomatic and Consular Posts** — Washington , June 26, 1979, 10:57 a.m.  
   `frus1977-80v28/d174` · score 0.6419  
   > 174. Airgram From the Department of State to All Diplomatic and Consular Posts Source: National Archives, RG 59, Records of the Under Secretary for Management (M), 1978–1979, Box 7, Chron June 24–30, 1979. Unclassified. Drafted by Dwight Ma…
10. **323. Memorandum From the Assistant Secretary of State for European Affairs ( Hillenbrand ) to the Deputy Under Secretary of State for Administration ( Macomber )** — Washington , August 19, 1970 .  
   `frus1969-76v02/d323` · score 0.6392  
   > 323. Memorandum From the Assistant Secretary of State for European Affairs ( Hillenbrand ) to the Deputy Under Secretary of State for Administration ( Macomber ) Source: National Archives, RG 59, Office of the Deputy Under Secretary for Man…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 6/10.*
*document variant:* frus1977-80v28/d164, frus1969-76v38p2/d158, frus1969-76v38p2/d223, frus1977-80v28/d169, frus1977-80v28/d161, frus1969-76v38p2/d154, frus1969-76v38p2/d144, frus1977-80v28/d181, frus1969-76v02/d323, frus1969-76v02/d339
*bare variant:* frus1977-80v28/d164, frus1969-76v38p2/d144, frus1977-80v28/d161, frus1977-80v28/d181, frus1969-76v02/d339, frus1969-76v38p2/d223, frus1961-63v25/d55, frus1977-80v28/d169, frus1977-80v28/d167, frus1977-80v28/d180

---

## Q10. What convinced U.S. policymakers that the Soviet Union was no long an ally after World War II?

### Lexical — `"what" AND "convinced" AND "u.s." AND "policymakers" AND "that" AND "the" AND "soviet" AND "union" AND "was" AND "no" AND "long" AND "an" AND "ally" AND "after" AND "world" AND "war" AND "ii?"`

1. ****  
   `frus1969-76v34/d59` · score -26.8950  
   > 59. Editorial Note An outgrowth of the Nixon administration’s policy of linkage, making negotiating progress in one area dependent on progress in another, was the threatened use of U.S. or allied military force to encourage North Vietnam an…
2. **8. Address by Ronald Reagan** — Chicago , August 18, 1980  
   `frus1981-88v01/d8` · score -23.4824  
   > 8. Address by Ronald Reagan Source: Reagan Library, White House Office of Speechwriting, Research Office, 1980 Campaign File, Campaign and Pre-Presidential Speeches, 1979–1981, 0/8/18/1980 VFW Convention, Chicago, IL. Reagan addressed the a…
3. **Volume Summary**  
   `frus1964-68v12/summary` · score -22.4085  
   > Volume Summary (This is not an official statement of policy by the Department of State; it is intended only as a guide to the contents of this volume.) Since 1861, the Department of State’s documentary series Foreign Relations of the United…
4. **241. Memorandum of Conversation** — Washington , March 20, 1980, 1–3 p.m.  
   `frus1977-80v12/d241` · score -21.0656  
   > 241. Memorandum of Conversation Source: National Archives, RG 59, Records of Under Secretary of State for Political Affairs David Newsom , Lot 81D154, folder 2. Secret. The meeting took place at the Soviet Embassy. In a covering memorandum …
5. **192. Remarks by President Reagan** — Washington , April 6, 1984  
   `frus1981-88v01/d192` · score -17.4301  
   > 192. Remarks by President Reagan Source: Public Papers: Reagan, 1984 , Book I, pp. 477–485. All brackets are in the original. The President addressed the National Leadership Forum of the Center for Strategic and International Studies of Geo…
6. **Report to the President by the President’s Committee on International Information Activities** — [ Washington ,] June 30, 1953 .  
   `frus1952-54v02p2/d370` · score -16.7076  
   > Eisenhower Library, White House Office records, “Project ‘Clean Up’” Report to the President by the President’s Committee on International Information Activities top secret [ Washington ,] June 30, 1953 . [Here follow a table of contents an…
7. **300. Response to National Security Study Memorandum 156** — Washington , September 1, 1972  
   `frus1969-76ve07/d300` · score -13.4342  
   > 300. Response to National Security Study Memorandum 156 Source: Washington National Records Center, OSD Files: FRC 77–0094, India, 1972. Secret; Sensitive; Eyes Only. The paper was circulated on September 26 to the CIA , the JCS , and the D…

### Semantic (query prompt)

1. **Memorandum by the Acting Department of State Member ( Matthews ) to the State–War–Navy Coordinating Committee** — Washington , April 1, 1946 .  
   `frus1946v01/d591` · score 0.6642  
   > SWNCC File Memorandum by the Acting Department of State Member ( Matthews ) to the State–War–Navy Coordinating Committee top secret Washington , April 1, 1946 . Subject: Political Estimate of Soviet Policy for Use in Connection with Militar…
2. **Draft Department of State Policy Statement** — Washington , undated .  
   `frus1951v04p2/d302` · score 0.6510  
   > No. 767 611.61/1–1651 Draft Department of State Policy Statement Copies of interoffice memoranda attached to the source text indicate that this draft policy statement was prepared in the Office of Eastern European Affairs, and received work…
3. **Memorandum “by the Director of the Office of European Affairs ( Hickerson ) to the Under Secretary of State ( Lovett )** — [ Washington ,] May 27, 1948 .  
   `frus1948v04/d589` · score 0.6495  
   > 711.61/5–2748 Memorandum “by the Director of the Office of European Affairs ( Hickerson ) to the Under Secretary of State ( Lovett ) [ Washington ,] May 27, 1948 . I. Summary of Acts From United States Side Evidencing Desire for Cooperation…
4. **The Ambassador in the Soviet Union ( Smith ) to the Secretary of State** — Moscow , May 10, 1948—1 a. m.  
   `frus1948v04/d570` · score 0.6411  
   > 711.61/5–1048: Telegram The Ambassador in the Soviet Union ( Smith ) to the Secretary of State top secret niact us urgent Moscow , May 10, 1948—1 a. m. 867. Eyes only for the Secretary from Smith. The Soviet Government has familiarized itse…
5. **The Chargé in Latvia ( Cole ) to the Acting Secretary of State** — Riga , November 23, 1933 . [Received December 5.]  
   `frus1933v02/d609` · score 0.6356  
   > 711.61/416 The Chargé in Latvia ( Cole ) to the Acting Secretary of State No. 1716 Riga , November 23, 1933 . [Received December 5.] Sir : I have the honor to enclose a translation in full Not printed. of the leading editorial in the Moscow…
6. **Memorandum of Conversation, by the Assistant Secretary of State for Far Eastern Affairs ( Rusk )** — [ Washington ,] October 4, 1950 .  
   `frus1950v04/d701` · score 0.6335  
   > 611.61/10–450 Memorandum of Conversation, by the Assistant Secretary of State for Far Eastern Affairs ( Rusk ) top secret [ Washington ,] October 4, 1950 . Participants: Yakov A. Malik Yakov Alexandrovich Malik was the Permanent Representat…
7. **61. Memorandum of Conversation** — Washington , January 6, 1959 .  
   `frus1958-60v10p1/d61` · score 0.6306  
   > 61. Memorandum of Conversation Source: Department of State, Conference Files: Lot 64 D 560, CF 1183. Secret. Drafted by Freers and approved by the Vice President’s office on January 16. Notations on the source text indicate that Dulles and …
8. **The Chargé in Latvia ( Cole ) to the Acting Secretary of State** — Riga , November 23, 1933 . [Received December 5.]  
   `frus1933-39/d47` · score 0.6303  
   > 711.61/416 The Chargé in Latvia ( Cole ) to the Acting Secretary of State No. 1716 Riga , November 23, 1933 . [Received December 5.] Sir : I have the honor to enclose a translation in full Not printed. of the leading editorial in the Moscow…
9. **The Ambassador in the Soviet Union ( Smith ) to the Secretary of State** — Moscow , May 4, 1948—7 p. m.  
   `frus1948v04/d567` · score 0.6301  
   > 711.61/5–448: Telegram The Ambassador in the Soviet Union ( Smith ) to the Secretary of State top secret Moscow , May 4, 1948—7 p. m. 836. Eyes only. Reference mytel 835 May 4. Following exact text of statement to Molotov, informal transcri…
10. **249. Study Prepared by an Ad Hoc Interagency Group on U.S.-Soviet Relations** — Washington , December 6, 1982  
   `frus1981-88v03/d249` · score 0.6256  
   > 249. Study Prepared by an Ad Hoc Interagency Group on U.S.-Soviet Relations Source: National Security Council, Box SR 080 [ NSDD 60–76], NSDD 75, US Relations w/ USSR . Secret. Prepared in response to NSSD 11–82 (see Document 204 ). Sent fr…

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
   > Marshall Mission Files, Lot 54–D270 Draft Policy Memorandum Prepared in the Embassy in China See last paragraph of General Marshall’s telegram No. 1367, August 23, p. 79 . This draft was forwarded on September 6 by the Minister-Counselor of…
2. **Memorandum by the Policy Planning Staff** — [ Washington ,] November 23, 1948 .  
   `frus1948v08/d164` · score 0.6191  
   > Policy Planning Staff Files, Lot 54D195 Memorandum by the Policy Planning Staff PPS 39/1 [ Washington ,] November 23, 1948 . U. S. Policy Toward China The following are the views of the Policy Planning Staff on the assertion, now frequently…
3. **Memorandum of Conversation, Prepared in the Department of State** — January 6 and 7, 1951 . January 12 and 13, 1951 .  
   `frus1951v07p2/d2` · score 0.6145  
   > S/P Files: Lot 64 D 563 Memorandum of Conversation, Prepared in the Department of State This is the first of a series of unsigned memoranda, most or all of which were written by Charles Burton Marshall of the Policy Planning Staff. Accordin…
4. **The Chargé in China ( Strong ) to the Secretary of State** — Canton , September 15, 1949—6 p. m. [Received September 16—1:08 p. m.]  
   `frus1949v08/d602` · score 0.6097  
   > 893.00B/9–1549: Telegram The Chargé in China ( Strong ) to the Secretary of State Canton , September 15, 1949—6 p. m. [Received September 16—1:08 p. m.] Cantel 1112. Embassy has following comments on Nanking telegram 1994 to Department, rep…
5. **Note by Rear Admiral Sidney W. Souers , Executive Secretary to the National Security Council** — [ Washington ,] July 26, 1948 .  
   `frus1948v08/d105` · score 0.6072  
   > Executive Secretariat Files: NSC 22 Note by Rear Admiral Sidney W. Souers , Executive Secretary to the National Security Council NSC 22 [ Washington ,] July 26, 1948 . Possible Courses of Action for the U. S. With Respect to the Critical Si…
6. **The Acting Secretary of State to General Marshall** — Washington , July 4, 1946—noon .  
   `frus1946v09/d636` · score 0.6062  
   > 893.00/7–446: Telegram The Acting Secretary of State to General Marshall Drafted by the Director of the Office of Far Eastern Affairs (Vincent). Washington , July 4, 1946—noon . 414. The following comment, responsive to your request of July…
7. **Memorandum by the Director of the Office of Far Eastern Affairs ( Butterworth ) to the Under Secretary of State ( Webb )** — [ Washington ,] May 17, 1949 .  
   `frus1949v08/d378` · score 0.6058  
   > 893.00/5–1749 Memorandum by the Director of the Office of Far Eastern Affairs ( Butterworth ) to the Under Secretary of State ( Webb ) [ Washington ,] May 17, 1949 . The most important aspect of the situation in Nationalist China is the con…
8. **Minutes of Briefing Session of the United States Delegation to the General Assembly, Washington, Department of State, September 7, 1950, 3:00 p. m .** — Washington , September 7, 1950, 3:00 p.m.  
   `frus1950v02/d161` · score 0.6032  
   > IO Files: US/ A /M (Chr)/134 Minutes of Briefing Session of the United States Delegation to the General Assembly, Washington, Department of State, September 7, 1950, 3:00 p. m . Washington , September 7, 1950, 3:00 p.m. secret [Here follows…
9. **Memorandum by the Director of the Office of Far Eastern Affairs ( Vincent )**  
   `frus1945v07/d541` · score 0.6010  
   > 121.893/11–2845 Memorandum by the Director of the Office of Far Eastern Affairs ( Vincent ) Copy in Department files bears no indication of drafting officer, and date was apparently inserted subsequently; name of drafting officer and date s…
10. **The Ambassador in China ( Gauss ) to the Secretary of State** — Chungking , September 28, 1944 . [Received October 24.]  
   `frus1944v06/d453` · score 0.6001  
   > 893.00/9–2844 The Ambassador in China ( Gauss ) to the Secretary of State No. 3018 Chungking , September 28, 1944 . [Received October 24.] Sir : I have the honor to transmit copies of the following reports prepared by Mr. John S. Service, S…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 4/10, bare: 6/10.*
*document variant:* frus1948v08/d164, frus1947v07/d616, frus1948v08/d105, frus1948v08/d46, frus1948v08/d122, frus1944v06/d453, frus1946v10/d69, frus1947v07/d591, frus1947v07/d666, frus1955-57v03/d248
*bare variant:* frus1948v08/d164, frus1946v10/d69, frus1948v08/d105, frus1964-68v30/d236, frus1947v07/d616, frus1948v08/d122, frus1944v06/d453, frus1950v02/d161, frus1951v07p2/d2, frus1948v08/d46

---

## Q12. Deposing shah

### Lexical — `"deposing" AND "shah"`

1. **Minister Pearson to the Secretary of State .** — Teheran , August 12, 1906 .  
   `frus1906p2/d327` · score -16.8057  
   > Minister Pearson to the Secretary of State . [Telegram.—Paraphrase.] Teheran , August 12, 1906 . (Mr. Pearson states that popular agitation, similar to that in Russia, demanding constitutional reforms but less violent, has triumphed in Pers…
2. **279. Telegram From the Embassy in Italy to the Department of State** — Rome , August 18, 1953, 8 p.m .  
   `frus1951-54Iran/d279` · score -16.6280  
   > 279. Telegram From the Embassy in Italy to the Department of State Source: National Archives, RG 59, Central Files 1950–1954, 788.11/8–1853. Confidential; Security Information; Priority. Repeated Priority to Tehran and Baghdad. Received at …
3. **279. Telegram From the Embassy in Italy to the Department of State** — Rome , August 18, 1953, 8 p.m.  
   `frus1951-54IranEd2/d279` · score -16.6280  
   > 279. Telegram From the Embassy in Italy to the Department of State Source: National Archives, RG 59, Central Files 1950–1954, 788.11/8–1853. Confidential; Security Information; Priority. Repeated Priority to Tehran and Baghdad. Received at …
4. **The Chargé in Iran ( Ford ) to the Secretary of State** — Tehran , December 16, 1943—3 p.m. [Received 5:45 p.m.]  
   `frus1943v04/d437` · score -16.3714  
   > 891.002/392: Telegram The Chargé in Iran ( Ford ) to the Secretary of State Tehran , December 16, 1943—3 p.m. [Received 5:45 p.m.] 1126. New Cabinet, 1125, December 16, is regarded locally as clear victory for Shah who has been able to plac…
5. **The Acting Secretary of State to the American Minister .** — Department of State , Washington , July 31, 1911 .  
   `frus1911/d988` · score -16.3671  
   > File No. 891.00/595a. The Acting Secretary of State to the American Minister . [Telegram.] Department of State , Washington , July 31, 1911 . In view of alarmist press telegrams, report concisely by telegraph concerning the political situat…
6. **No. 316 The Ambassador in Iran ( Henderson ) to the Department of State** — Tehran , March 10, 1953—1 p.m.  
   `frus1952-54v10/d316` · score -14.6126  
   > 788.00/3–1053: Telegram No. 316 The Ambassador in Iran ( Henderson ) to the Department of State Transmitted in two sections; also sent to London and pouched to Ankara, Baghdad, Cairo, and Dhahran. secret priority Tehran , March 10, 1953—1 p…
7. **No. 250. Mr. Gibbs to Mr. Evarts .** — Legation of the United States , Lima, Peru , June 12, 1877 . (Received July 9.)  
   `frus1877/d250` · score -14.0541  
   > No. 250. Mr. Gibbs to Mr. Evarts . Legation of the United States , Lima, Peru , June 12, 1877 . (Received July 9.) No. 162.] Sir : Since my dispatch No. 159, of 9th instant, an apparent conspiracy to change the government was attempted and …
8. **The Ambassador in Iran ( Murray ) to the Secretary of State** — Tehran , June 26, 1945—9 a.m. [Received June 26—6:35 a.m.]  
   `frus1945v08/d349` · score -13.5998  
   > 891.00/6–2645: Telegram The Ambassador in Iran ( Murray ) to the Secretary of State Tehran , June 26, 1945—9 a.m. [Received June 26—6:35 a.m.] 428. Dept’s instruction of Feb 28, 1945. Not printed. In view of unavoidable delay in reporting s…
9. **291. Memorandum of Discussion at the 449th Meeting of the National Security Council** — Washington , June 30, 1960 .  
   `frus1958-60v12/d291` · score -13.3896  
   > 291. Memorandum of Discussion at the 449th Meeting of the National Security Council Source: Eisenhower Library, Whitman File, NSC Records. Top Secret; Eyes Only. Drafted by Boggs on June 30. Washington , June 30, 1960 . [Here follow a parag…
10. **393. Despatch From the Embassy in Iran to the Department of State** — Tehran , March 11, 1957 .  
   `frus1955-57v12/d393` · score -12.5460  
   > 393. Despatch From the Embassy in Iran to the Department of State Source: Department of State, Central Files, 788.11/3–1157. Secret. Also sent to KhorramShahr, Isfahan, Tabriz, and Meshed. Passed to London, Moscow, Ankara, Baghdad, Kabul, K…

### Semantic (query prompt)

1. **Mr. McDonald to Mr. Olney .** — Legation of the United States , Teheran, Persia , May 4, 1896 . (Received June 11.)  
   `frus1896/d386` · score 0.5862  
   > Mr. McDonald to Mr. Olney . Legation of the United States , Teheran, Persia , May 4, 1896 . (Received June 11.) No. 241, Dip. Ser.] Sir : It is my melancholy duty to report for your information the facts, as far as they can be ascertained, …
2. **No. 305 The Ambassador in Iran ( Henderson ) to the Department of State** — Tehran , February 25, 1953—11 p.m.  
   `frus1952-54v10/d305` · score 0.5462  
   > 788.11/2–2553: Telegram No. 305 The Ambassador in Iran ( Henderson ) to the Department of State Also sent to London. top secret niact Tehran , February 25, 1953—11 p.m. 3393. Noforn . 1. Ala Minister Court came to see me tonight, obviously …
3. ****  
   `frus1977-80v11p1/d326` · score 0.5437  
   > 326. Editorial Note On July 27, 1980, the former Shah of Iran, Mohammed Reza Pahlavi , died in Cairo. The Department of State issued a press statement conforming to its final draft. See Document 308 . The press statement is in Department of…
4. **No. 308 The Ambassador in Iran ( Henderson ) to the Department of State** — Tehran , February 28, 1953—5 p.m.  
   `frus1952-54v10/d308` · score 0.5216  
   > 788.11/2–2853: Telegram No. 308 The Ambassador in Iran ( Henderson ) to the Department of State Transmitted in four sections; also sent to London, Baghdad, Ankara, and Dhahran. top secret niact Tehran , February 28, 1953—5 p.m. 3449. Early …
5. **393. Despatch From the Embassy in Iran to the Department of State** — Tehran , March 11, 1957 .  
   `frus1955-57v12/d393` · score 0.5186  
   > 393. Despatch From the Embassy in Iran to the Department of State Source: Department of State, Central Files, 788.11/3–1157. Secret. Also sent to KhorramShahr, Isfahan, Tabriz, and Meshed. Passed to London, Moscow, Ankara, Baghdad, Kabul, K…
6. **The Ambassador in Iran ( Murray ) to the Secretary of State** — Tehran , June 26, 1945—9 a.m. [Received June 26—6:35 a.m.]  
   `frus1945v08/d349` · score 0.5159  
   > 891.00/6–2645: Telegram The Ambassador in Iran ( Murray ) to the Secretary of State Tehran , June 26, 1945—9 a.m. [Received June 26—6:35 a.m.] 428. Dept’s instruction of Feb 28, 1945. Not printed. In view of unavoidable delay in reporting s…
7. **161. Telegram From the Embassy in Iran to the Department of State** — Tehran , February 25, 1953, 11 p.m.  
   `frus1951-54IranEd2/d161` · score 0.5075  
   > 161. Telegram From the Embassy in Iran to the Department of State Source: National Archives, RG 59, Central Files 1950–1954, 788.11/2–2553. Top Secret; Security Information; NIACT ; Noforn . Repeated to London, Baghdad, and Madrid. Received…
8. **161. Telegram From the Embassy in Iran to the Department of State** — Tehran , February 25, 1953, 11 p.m .  
   `frus1951-54Iran/d161` · score 0.5072  
   > 161. Telegram From the Embassy in Iran to the Department of State Source: National Archives, RG 59, Central Files 1950–1954, 788.11/2–2553. Top Secret; Security Information; NIACT ; Noforn . Repeated to London, Baghdad, and Madrid. Received…
9. **The Chargé in Iran ( Somerville ) to the Secretary of State** — Tehran , February 14, 1949—3 p. m.  
   `frus1949v06/d269` · score 0.5070  
   > 891.00/2–1449: Telegram The Chargé in Iran ( Somerville ) to the Secretary of State secret Tehran , February 14, 1949—3 p. m. 161. During audience which I had yesterday with Shah he commented at some length on crisis precipitated by attempt…
10. **No. 301 The Ambassador in Iran ( Henderson ) to the Department of State** — Tehran , February 22, 1953—2 p.m.  
   `frus1952-54v10/d301` · score 0.5069  
   > 788.00/2–2253: Telegram No. 301 The Ambassador in Iran ( Henderson ) to the Department of State Transmitted in three sections; also sent to London. top secret priority Tehran , February 22, 1953—2 p.m. 3334. 1. Ala , Minister of Court, aske…

*Route overlap: 2 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 4/10.*
*document variant:* frus1896/d386, frus1977-80v11p1/d326, frus1952-54v10/d305, frus1952-54v10/d308, frus1951-54Iran/d166, frus1951-54IranEd2/d166, frus1951-54IranEd2/d161, frus1951-54Iran/d161, frus1949v06/d268, frus1977-80v11p1/d219
*bare variant:* frus1896/d386, frus1977-80v11p1/d326, frus1910/d932, frus1910/d609, frus1885/d569, frus1910/d930, frus1952-54v10/d308, frus1952-54v10/d305, frus1910/d603, frus1910/d898

---

## Q13. Diego Garcia base

### Lexical — `"diego" AND "garcia" AND "base"`

1. **46. Memorandum From Secretary of Defense McNamara to the Secretary of the Navy ( Ignatius )** — Washington , October 27, 1967 .  
   `frus1964-68v21/d46` · score -27.0533  
   > 46. Memorandum From Secretary of Defense McNamara to the Secretary of the Navy ( Ignatius ) Source: Washington National Records Center, RG 330, OSD Files: FRC 72 A 2468, Indian Ocean 323.3, 27 Oct. 67. Secret. Washington , October 27, 1967 …
2. **86. Minutes of the Secretary of State’s Staff Regional Staff Meeting** — Washington , April 25, 1975, 8 a.m.  
   `frus1969-76ve08/d86` · score -26.1665  
   > 86. Minutes of the Secretary of State’s Staff Regional Staff Meeting Source: National Archives, RG 59, Transcripts of Secretary of State Kissinger ’s Staff Meetings, 1973–77, Entry 5177, Box 3, Secretary’s Analytical Staff Meetings. Secret.…
3. **65. Memorandum From the Deputy Assistant Secretary of Defense for European and NATO Affairs ( Bergold ) to the Deputy Assistant Secretary of Defense for Security Assistance ( Peet )** — Washington , January 17, 1974 .  
   `frus1969-76ve08/d65` · score -25.5635  
   > 65. Memorandum From the Deputy Assistant Secretary of Defense for European and NATO Affairs ( Bergold ) to the Deputy Assistant Secretary of Defense for Security Assistance ( Peet ) Source: Washington National Records Center, OSD Files: 330…
4. **87. Minutes of the Senior Review Group Meeting** — Washington , May 6, 1975, 4:16–5:04 p.m.  
   `frus1969-76ve08/d87` · score -25.5264  
   > 87. Minutes of the Senior Review Group Meeting Source: Library of Congress, Manuscript Division, Kissinger Papers, Box CL 306, Committees and Panels, Senior Review Group, May–October 1975. Secret; Sensitive. The meeting was held in the Whit…
5. **126. Memorandum From Secretary of Defense Brown to Secretary of State Vance and the President’s Assistant for National Security Affairs ( Brzezinski )** — Washington , November 3, 1979  
   `frus1977-80v18/d126` · score -25.2142  
   > 126. Memorandum From Secretary of Defense Brown to Secretary of State Vance and the President’s Assistant for National Security Affairs ( Brzezinski ) Source: Carter Library, National Security Affairs, Staff Material, Middle East, Subject F…
6. **69. Memorandum From Secretary of State Kissinger to President Nixon** — Washington , February 25, 1974 .  
   `frus1969-76ve08/d69` · score -24.9644  
   > 69. Memorandum From Secretary of State Kissinger to President Nixon Source: Library of Congress, Manuscript Division, Kissinger Papers, Box CL 299, Presidential Memoranda, March, 1974. Confidential. Attached at Tab A is the March 1 letter. …
7. **89. Memorandum of Conversation** — Washington , July 16, 1975, 11 a.m.  
   `frus1969-76ve08/d89` · score -24.7029  
   > 89. Memorandum of Conversation Source: Ford Library, National Security Advisor, Memoranda of Conversations, 1973–77, Ford Administration, Box 13. Top Secret. The meeting was held in the White House Cabinet Room. Secretary of Defense James S…
8. **129. Briefing Memorandum From the Director of the Bureau of Politico-Military Affairs ( Bartholomew ) to Secretary of State Muskie** — Washington , June 30, 1980  
   `frus1977-80v18/d129` · score -24.6590  
   > 129. Briefing Memorandum From the Director of the Bureau of Politico-Military Affairs ( Bartholomew ) to Secretary of State Muskie Source: National Archives, RG 59, Central Foreign Policy File, P800109–1201. Secret. Drafted by David C. Gomp…
9. **47. Memorandum From the Joint Chiefs of Staff to Secretary of Defense McNamara** — Washington , April 10, 1968 .  
   `frus1964-68v21/d47` · score -24.4753  
   > 47. Memorandum From the Joint Chiefs of Staff to Secretary of Defense McNamara Source: Washington National Records Center, RG 330, OSD Files: FRC 73 A 1250, Indian Ocean 323.3, 10 Apr. 68. Secret. The memorandum indicates that McNamara saw …
10. **40. Memorandum From the Assistant Secretary of Defense for International Security Affairs ( Nutter ) to Secretary of Defense Laird** — Washington , March 17, 1970 .  
   `frus1969-76v24/d40` · score -24.3901  
   > 40. Memorandum From the Assistant Secretary of Defense for International Security Affairs ( Nutter ) to Secretary of Defense Laird Source: Washington National Records Center, OSD Files: FRC 330–76–067, Box 73, Indian Ocean 1970. Secret. Was…

### Semantic (query prompt)

1. **39. Paper Prepared in the Office of the Chief of Naval Operations ( Moorer )** — Washington , February 11, 1970 .  
   `frus1969-76v24/d39` · score 0.5916  
   > 39. Paper Prepared in the Office of the Chief of Naval Operations ( Moorer ) Source: National Archives, RG 59, Central Files 1970–73, DEF 15 IND– US . Secret. The paper was submitted to U. Alexis Johnson under a February 1 covering memorand…
2. **46. Memorandum From Secretary of Defense McNamara to the Secretary of the Navy ( Ignatius )** — Washington , October 27, 1967 .  
   `frus1964-68v21/d46` · score 0.5770  
   > 46. Memorandum From Secretary of Defense McNamara to the Secretary of the Navy ( Ignatius ) Source: Washington National Records Center, RG 330, OSD Files: FRC 72 A 2468, Indian Ocean 323.3, 27 Oct. 67. Secret. Washington , October 27, 1967 …
3. **57. Telegram 118250 From the Department of State to the Embassy in the United Kingdom** — Washington , June 18, 1973, 1946Z .  
   `frus1969-76ve08/d57` · score 0.5656  
   > 57. Telegram 118250 From the Department of State to the Embassy in the United Kingdom Source: National Archives, RG 59, Central Files 1970–73, DEF 15 India-United States Relations. Secret; Priority; Exdis . It was drafted on June 7 by John …
4. **37. Memorandum From the Assistant Secretary of State for Near Eastern and South Asian Affairs ( Sisco ) to Secretary of State Rogers** — Washington , June 24, 1969 .  
   `frus1969-76v24/d37` · score 0.5646  
   > 37. Memorandum From the Assistant Secretary of State for Near Eastern and South Asian Affairs ( Sisco ) to Secretary of State Rogers Source: National Archives, RG 59, Central Files 1967–69, DEF 15 IND– US . Secret. Drafted by Grant E. Mouse…
5. **65. Memorandum From the Deputy Assistant Secretary of Defense for European and NATO Affairs ( Bergold ) to the Deputy Assistant Secretary of Defense for Security Assistance ( Peet )** — Washington , January 17, 1974 .  
   `frus1969-76ve08/d65` · score 0.5584  
   > 65. Memorandum From the Deputy Assistant Secretary of Defense for European and NATO Affairs ( Bergold ) to the Deputy Assistant Secretary of Defense for Security Assistance ( Peet ) Source: Washington National Records Center, OSD Files: 330…
6. **40. Memorandum From the Assistant Secretary of Defense for International Security Affairs ( Nutter ) to Secretary of Defense Laird** — Washington , March 17, 1970 .  
   `frus1969-76v24/d40` · score 0.5521  
   > 40. Memorandum From the Assistant Secretary of Defense for International Security Affairs ( Nutter ) to Secretary of Defense Laird Source: Washington National Records Center, OSD Files: FRC 330–76–067, Box 73, Indian Ocean 1970. Secret. Was…
7. **126. Memorandum From Secretary of Defense Brown to Secretary of State Vance and the President’s Assistant for National Security Affairs ( Brzezinski )** — Washington , November 3, 1979  
   `frus1977-80v18/d126` · score 0.5515  
   > 126. Memorandum From Secretary of Defense Brown to Secretary of State Vance and the President’s Assistant for National Security Affairs ( Brzezinski ) Source: Carter Library, National Security Affairs, Staff Material, Middle East, Subject F…
8. **44. Memorandum From the Secretary of the Navy ( Nitze ) to Secretary of Defense McNamara** — Washington , February 24, 1967 .  
   `frus1964-68v21/d44` · score 0.5480  
   > 44. Memorandum From the Secretary of the Navy ( Nitze ) to Secretary of Defense McNamara Source: Washington National Records Center, RG 330, OSD Files: FRC 72 A 2468, Indian Ocean 323.3, 24 Feb. 67. Secret. A copy was sent to the Under Secr…
9. **129. Briefing Memorandum From the Director of the Bureau of Politico-Military Affairs ( Bartholomew ) to Secretary of State Muskie** — Washington , June 30, 1980  
   `frus1977-80v18/d129` · score 0.5479  
   > 129. Briefing Memorandum From the Director of the Bureau of Politico-Military Affairs ( Bartholomew ) to Secretary of State Muskie Source: National Archives, RG 59, Central Foreign Policy File, P800109–1201. Secret. Drafted by David C. Gomp…
10. **48. Memorandum From the Deputy Secretary of Defense ( Nitze )** — Washington , June 15, 1968 .  
   `frus1964-68v21/d48` · score 0.5441  
   > 48. Memorandum From the Deputy Secretary of Defense ( Nitze ) Source: Washington National Records Center, RG 330, OSD Files: FRC 73 A 1250, Indian Ocean 323.3, 15 Jun. 68. Secret. A copy was sent to the Assistant Secretary of Defense (SA). …

*Route overlap: 5 of 10 shared. Prompt variants vs primary — document: 9/10, bare: 5/10.*
*document variant:* frus1964-68v21/d46, frus1969-76v24/d37, frus1969-76v24/d39, frus1977-80v18/d126, frus1969-76ve08/d57, frus1977-80v18/d129, frus1969-76v24/d40, frus1964-68v21/d44, frus1969-76v41/d273, frus1969-76ve08/d65
*bare variant:* frus1964-68v21/d46, frus1969-76v41/d273, frus1969-76ve08/d57, frus1969-76v24/d37, frus1964-68v12/d207, frus1969-76v24/d40, frus1969-76v24/d39, frus1948v09/d178, frus1969-76v41/d290, frus1969-76ve15p2/d229

---

## Q14. Space aliens
*null control*

### Lexical — `"space" AND "aliens"`

1. **The Consul General at Shanghai ( Cabot ) to the Secretary of State** — Shanghai , December 13, 1948—midnight . [Received December 14—1:57 p.m.]  
   `frus1948v08/d858` · score -14.5506  
   > 840.48 Refugees/12–1348: Telegram The Consul General at Shanghai ( Cabot ) to the Secretary of State Shanghai , December 13, 1948—midnight . [Received December 14—1:57 p.m.] 2755. ReEmbtel 1231, December 9, Sent to the Department as telegra…
2. **The Secretary of State to the Consul General at Rangoon ( Schnare )** — Washington , February 4, 1942—9 p.m.  
   `frus1942v01/d192` · score -14.4256  
   > 390.1115A/676: Telegram The Secretary of State to the Consul General at Rangoon ( Schnare ) Washington , February 4, 1942—9 p.m. 57. Your 106, January 31, 1 p.m. Extra space made available by emergency consular certificates issued under dis…
3. **The Ambassador in the United Kingdom ( Kennedy ) to the Secretary of State** — London , October 3, 1939—8 p.m. [Received October 3—6:15 p.m.]  
   `frus1939v01/d661` · score -13.8348  
   > 340.1115A/100: Telegram The Ambassador in the United Kingdom ( Kennedy ) to the Secretary of State London , October 3, 1939—8 p.m. [Received October 3—6:15 p.m.] 1912. Your 1131, September 30. We have been looking into the charges of allege…
4. **The Ambassador in China ( Stuart ) to the Secretary of State** — Nanking , December 9, 1948 . [Received December 9—8:23 a.m.]  
   `frus1948v08/d847` · score -13.8109  
   > 393.1115/12–948: Telegram The Ambassador in China ( Stuart ) to the Secretary of State Nanking , December 9, 1948 . [Received December 9—8:23 a.m.] 2469. [To Shanghai:] Evacuation policy as agreed upon by Department, Embassy, and Naval auth…
5. **The Acting Secretary of State to Certain Diplomatic and Consular Officers** — Washington , February 20, 1942—10 p.m.  
   `frus1942v01/d199` · score -13.7153  
   > 300.1115/245b: Circular telegram The Acting Secretary of State to Certain Diplomatic and Consular Officers Sent to diplomatic officers at London, with instructions to repeat to all seaport consular offices in the British Isles; Cairo (to re…
6. **Extract from the Constitution of May 23, 1845.** — [ May 23, 1845 .]  
   `frus1873p1v2/d217` · score -13.0084  
   > Extract from the Constitution of May 23, 1845. [ May 23, 1845 .] Part I.—Article I . “Spaniards are— “1. All persons born within the dominions of Spain. “2. The children of a Spanish father and mother, though born out of the dominions of Sp…
7. **The Minister in Switzerland ( Harrison ) to the Secretary of State** — Bern , June 25, 1943 . [Received June 25—6:26 p.m.]  
   `frus1943v03/d732` · score -12.7536  
   > 701.0090/1640: Telegram The Minister in Switzerland ( Harrison ) to the Secretary of State Bern , June 25, 1943 . [Received June 25—6:26 p.m.] 3804. American interests Far East, repatriation. Department’s 1311, 2d, and 1333, 4th. Department…
8. **383. Memorandum From Maxwell W. Hunter II of the National Aeronautics and Space Council to Robert F. Packard of the Office of International Scientific Affairs** — Washington , July 18, 1963 .  
   `frus1961-63v25/d383` · score -12.6149  
   > 383. Memorandum From Maxwell W. Hunter II of the National Aeronautics and Space Council to Robert F. Packard of the Office of International Scientific Affairs Source: National Archives and Records Administration, RG 59, Central Files 1960–6…
9. **The Assistant Secretary of Labor ( White ) to the Assistant Secretary of State ( Carr )** — Washington , April 22, 1927 .  
   `frus1927v01/d360` · score -12.0211  
   > 150.01 Commuters/16 The Assistant Secretary of Labor ( White ) to the Assistant Secretary of State ( Carr ) Washington , April 22, 1927 . My Dear Mr. Carr : Enclosed find copy of General Order No. 86, outlining land border crossing procedur…
10. **Bear Admiral C. W. Styer , of the Office of Chief of Naval Operations, to the Director of the Office of Far Eastern Affairs ( Butterworth )** — Washington , 8 January 1948 .  
   `frus1948v08/d257` · score -12.0207  
   > 811.3393/1–848 Bear Admiral C. W. Styer , of the Office of Chief of Naval Operations, to the Director of the Office of Far Eastern Affairs ( Butterworth ) Ser: 004P35 (SC) A14–7/EF16 Washington , 8 January 1948 . My Dear Mr. Butterworth : T…

### Semantic (query prompt)

1. **383. Memorandum From Maxwell W. Hunter II of the National Aeronautics and Space Council to Robert F. Packard of the Office of International Scientific Affairs** — Washington , July 18, 1963 .  
   `frus1961-63v25/d383` · score 0.5960  
   > 383. Memorandum From Maxwell W. Hunter II of the National Aeronautics and Space Council to Robert F. Packard of the Office of International Scientific Affairs Source: National Archives and Records Administration, RG 59, Central Files 1960–6…
2. **479. Report by the National Aeronautics and Space Council** — Washington , January 26, 1960 .  
   `frus1958-60v02/d479` · score 0.4777  
   > 479. Report by the National Aeronautics and Space Council Source: Department of State, S/S – NSC (Miscellaneous) Files: Lot 66 D 95, Outer Space. Secret. The cover sheet, memorandum of transmittal, note from the National Aeronautics and Spa…
3. **145. Memorandum From the Executive Secretary of the Department of State ( Read ) to the President’s Special Assistant ( Rostow )** — Washington , August 10, 1966 .  
   `frus1964-68v11/d145` · score 0.4763  
   > 145. Memorandum From the Executive Secretary of the Department of State ( Read ) to the President’s Special Assistant ( Rostow ) Source: Department of State, Central Files, SP 4. Confidential. Drafted by Gerald B. Helman ( IO / UNP ) and cl…
4. **442. National Security Council Report** — Washington , August 18, 1958 .  
   `frus1958-60v02/d442` · score 0.4748  
   > 442. National Security Council Report Source: Department of State, S/P – NSC Files: Lot 62 D 1. Secret. A cover sheet; a memorandum of transmittal, dated August 18, which noted that the President had approved NSC 5814/1 on that day; a table…
5. **365. Memorandum of Conversation** — Washington , May 19, 1961 .  
   `frus1961-63v25/d365` · score 0.4692  
   > 365. Memorandum of Conversation Source: National Archives and Records Administration, RG 59, Central Files 1960–63, 701.56311/5–1961. Confidential. Drafted by Crosby on May 23. Washington , May 19, 1961 . SUBJECT United Nations Outer Space …
6. **430. Memorandum From the Deputy Legal Adviser of the Department of State ( Meeker ) to Secretary of State Rusk** — Washington , October 8, 1963 .  
   `frus1961-63v25/d430` · score 0.4682  
   > 430. Memorandum From the Deputy Legal Adviser of the Department of State ( Meeker ) to Secretary of State Rusk Source: National Archives and Records Administration, RG 59, Central Files 1960–63, SP 5 UN . Confidential. Washington , October …
7. **265. Airgram A-420 From the Embassy in the Soviet Union to the Department of State** — Moscow , May 20, 1971 .  
   `frus1969-76ve01/d265` · score 0.4620  
   > 265. Airgram A-420 From the Embassy in the Soviet Union to the Department of State Source: National Archives, RG 59, Central Files 1970-73, SP 10 US . Confidential. Drafted by William N. Harben, scientific officer at the Embassy on May 20, …
8. **463. Telegram From the Department of State to the Mission at the United Nations** — Washington , November 6, 1959—7:02 p.m.  
   `frus1958-60v02/d463` · score 0.4597  
   > 463. Telegram From the Department of State to the Mission at the United Nations Source: Department of State, Central Files, 320.5701/11–659. Confidential. Drafted by Sisco on November 5; cleared by Meeker , Nunley , and Gathright; and appro…
9. **43. Letter From Chairman Khrushchev to President Kennedy** — Moscow , March 20, 1962 .  
   `frus1961-63v06/d43` · score 0.4596  
   > 43. Letter From Chairman Khrushchev to President Kennedy Source: Department of State, Presidential Correspondence: Lot 66 D 204. Confidential; Limit Distribution. The Russian-language text is ibid. Another copy is in the Kennedy Library, Na…
10. **55. Department of State Policy Paper** — Washington , October 1966 .  
   `frus1964-68v34/d55` · score 0.4583  
   > 55. Department of State Policy Paper Source: National Archives and Records Administration, RG 59, Records of the Department of State, Central Files, 1964–66, SP 1 US. Secret. Prepared by the Policy Planning Council. A typed note on the cove…

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 5/10, bare: 7/10.*
*document variant:* frus1961-63v25/d383, frus1958-60v02/d442, frus1873p1v2/d213, frus1961-63v25/d367, frus1964-68v11/d145, frus1964-68v34/d55, frus1961-63v25/d430, frus1964-68v11/d128, frus1958-60v02/d461, frus1873p1v2/d303
*bare variant:* frus1961-63v25/d383, frus1958-60v02/d479, frus1961-63v25/d367, frus1958-60v02/d442, frus1969-76ve01/d265, frus1964-68v34/d55, frus1964-68v11/d145, frus1961-63v25/d365, frus1958-60v03mSupp/d283, frus1961-63v25/d429

---

## Q15. U.S.S. Liberty sinking
*wrong-premise probe (the Liberty was attacked, not sunk)*

### Lexical — `"u.s.s." AND "liberty" AND "sinking"`

1. **The Ambassador in Japan ( Grew ) to the Secretary of State** — Tokyo , September 29, 1941—noon . [Received 2:25 p.m.]  
   `frus1941v04/d359` · score -9.2217  
   > 711.94/2319: Telegram The Ambassador in Japan ( Grew ) to the Secretary of State Tokyo , September 29, 1941—noon . [Received 2:25 p.m.] 1529. For the Secretary and Under Secretary only. 1. A review of our exchange of confidential telegrams …
2. **Joint Chiefs of Staff Minutes** — Potsdam , July 24, 1945, 2:30 p.m.  
   `frus1945Berlinv02/d710a-90` · score -6.3305  
   > J. C. S. Files Joint Chiefs of Staff Minutes The papers of the Joint Chiefs of Staff indicate that “These Minutes were transcribed from notes taken by the United States Secretaries, Combined Chiefs of Staff.” Potsdam , July 24, 1945, 2:30 p…
3. **United States Delegation Record, Council of Foreign Ministers, Second Session, Third Meeting, Paris, April 27, 1946, 4 p.m.** — Paris , April 27, 1946, 4 p.m.  
   `frus1946v02/d76` · score -6.0524  
   > C.F.M. Files: Lot M–88: Box 2063: US Delegation Minutes United States Delegation Record, Council of Foreign Ministers, Second Session, Third Meeting, Paris, April 27, 1946, 4 p.m. For a list of persons present at this meeting, see the Recor…
4. **Verbatim Record** — July 30, 1946, 4 p.m.  
   `frus1946v03/d18` · score -4.5586  
   > CFM Files Verbatim Record July 30, 1946, 4 p.m. C.P.(Plen) 2 Chairman: M. Bidault (France) The Chairman : The list of speakers is as follows: the first Delegate of the United States of America, the first Delegate of the United Kingdom, and …
5. **Mr. Stevens to Mr. Blaine .** — United States Legation , Honolulu , June 9, 1890 .  
   `frus1894app2/d134` · score -4.5275  
   > Mr. Stevens to Mr. Blaine . No. 26.] United States Legation , Honolulu , June 9, 1890 . Sir : I improve the first mail opportunity to forward two copies of the speech of Hon. L. A. Thurston, Minister of Interior, just delivered in the Hawai…
6. **EXHIBIT V. Annex 1.** — [ December 7, 1891 to November 5, 1892 ]  
   `frus1902app1/d30` · score -4.2496  
   > EXHIBIT V. Annex 1. [ December 7, 1891 to November 5, 1892 ] [Bark Cape Horn Pigeon —Log book. Season of 1892. Thomas Scullen, master.] Monday, December 7. —At 1.30 p.m. hove up anchor, and tug Sea Witch towed us out to Whising Buoy. At 3.3…
7. **Thompson Minutes** — Potsdam , July 19, 1945, 5 p.m.  
   `frus1945Berlinv02/d710a-28` · score -4.1159  
   > Truman Papers Thompson Minutes Potsdam , July 19, 1945, 5 p.m. top secret Bulgarian–Greek Frontier Incident Mr. Churchill said he wished to refer to a point which Stalin had raised at the previous meeting concerning an incident on the Bulga…
8. **Minister Dawson to the President .** — Washington , July 1, 1905 .  
   `frus1905/d345` · score -3.9559  
   > Minister Dawson to the President . Washington , July 1, 1905 . memorandum on the dominican modus vivendi, its effects up to the present time, and the reasons that lead to its adoption. The financial modus vivendi put into effect April 1 by …
9. **Report of the Special Representative of the United States Government ( House )**  
   `frus1917Supp02v01/d370` · score -2.6403  
   > File No. 763.72/13416 Report of the Special Representative of the United States Government ( House ) This and the following reports, which were submitted to Colonel House , pp. 334 – 445 , comprise the report of the American War Mission to …
10. **210. Letter From the President’s Military Representative ( Taylor ) to the President** — Washington , November 3, 1961 .  
   `frus1961-63v01/d210` · score -1.2266  
   > 210. Letter From the President’s Military Representative ( Taylor ) to the President Source: Kennedy Library, National Security Files, Viet-Nam Country Series, Taylor Report A & B. Top Secret. No drafting information is given on the source …

### Semantic (query prompt)

1. **219. Memorandum for the Record** — Washington , June 8, 1967, 3:30 p.m.  
   `frus1964-68v19/d219` · score 0.5829  
   > 219. Memorandum for the Record Source: Johnson Library, National Security File, NSC Special Committee Files, Liberty . Top Secret. Prepared in the National Military Command Center. Washington , June 8, 1967, 3:30 p.m. SUBJECT The USS Libert…
2. ****  
   `frus1964-68v19/d204` · score 0.5591  
   > 204. Editorial Note On June 8, 1967, at 8:03 a.m. Eastern Daylight Time (1203Z; p.m. local time), the U.S.S. Liberty was attacked and hit by unidentified jet fighters, which made six strafing runs. Twenty minutes later the ship was attacked…
3. **284. Intelligence Memorandum Prepared in the Central Intelligence Agency** — Washington , June 13, 1967 .  
   `frus1964-68v19/d284` · score 0.5531  
   > 284. Intelligence Memorandum Prepared in the Central Intelligence Agency Source: Johnson Library, National Security File, Country File, Middle East Crisis, CIA Intelligence Memoranda. Top Secret; Trine; No Foreign Dissem. Prepared in the Ce…
4. **234. Memorandum for the Record** — Washington , June 9, 1967, 3:26 p.m.  
   `frus1964-68v19/d234` · score 0.5474  
   > 234. Memorandum for the Record Source: Johnson Library, National Security File, Country File, Middle East Crisis, Vol. IV. Top Secret; Trine. Prepared in the National Military Command Center. A handwritten note on the memorandum indicates a…
5. **373. Memorandum From the Chairman of the President’s Foreign Intelligence Advisory Board ( Clifford ) to the President’s Special Assistant ( Rostow )** — Washington , July 18, 1967 .  
   `frus1964-68v19/d373` · score 0.5451  
   > 373. Memorandum From the Chairman of the President’s Foreign Intelligence Advisory Board ( Clifford ) to the President’s Special Assistant ( Rostow ) Source: Johnson Library, National Security File, Country File, Middle East Crisis, Intelli…
6. **The Ambassador in Austria-Hungary ( Penfield ) to the Secretary of State** — Vienna , December 29, 1915,7 p. m. [ Received December 30, 3.50 p. m. ]  
   `frus1915Supp/d909` · score 0.5374  
   > File No. 865.857An2/97 The Ambassador in Austria-Hungary ( Penfield ) to the Secretary of State [Telegram] Vienna , December 29, 1915,7 p. m. [ Received December 30, 3.50 p. m. ] 1064. The following reply to my note of the 21st instant, com…
7. **The Chargé in Germany ( Grew ) to the Secretary of State** — Berlin , December 17, 1916 . [ Received December 21, 10.45 a. m. ]  
   `frus1916Supp/d438` · score 0.5340  
   > File No. 300.115C72/23 The Chargé in Germany ( Grew ) to the Secretary of State [Telegram] Berlin , December 17, 1916 . [ Received December 21, 10.45 a. m. ] 4744. The following note relative to the sinking of the Columbian has just been re…
8. **352. Diplomatic Note From Secretary of State Rusk to the Israeli Ambassador ( Harman )** — Washington , June 10, 1967 .  
   `frus1964-68v19/d352` · score 0.5253  
   > 352. Diplomatic Note From Secretary of State Rusk to the Israeli Ambassador ( Harman ) Source: National Archives and Records Administration, RG 59, Central Files 1967–69, POL 27 ARAB–ISR. No classification marking. The note, dated June 10, …
9. **The Ambassador in Germany ( Gerard ) to the Secretary of State** — Berlin , May 29, 1915, 7 p. m. [ Received May 31, 1.30 a. m. ]  
   `frus1915Supp/d615` · score 0.5250  
   > File No. 763.72/1830 The Ambassador in Germany ( Gerard ) to the Secretary of State [Telegram] Berlin , May 29, 1915, 7 p. m. [ Received May 31, 1.30 a. m. ] 2326. The following is the text of the reply of the German Government to the Lusit…
10. **The Consul at Amsterdam ( Mahin ) to the Secretary of State** — Amsterdam , March 23, 1917 . [ Received 6 p.m. ]  
   `frus1917Supp01v01/d214` · score 0.5238  
   > File No. 300.115H34/6 The Consul at Amsterdam ( Mahin ) to the Secretary of State [Telegram] Amsterdam , March 23, 1917 . [ Received 6 p.m. ] Supplementing telegram 22d, Healdton lights showed name and American flag painted on sides, also f…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 4/10.*
*document variant:* frus1964-68v19/d204, frus1964-68v19/d219, frus1964-68v19/d284, frus1917Supp01v01/d214, frus1916Supp/d411, frus1917Supp01v01/d207, frus1915Supp/d909, frus1915Supp/d615, frus1916Supp/d402, frus1915Supp/d632
*bare variant:* frus1915Supp/d909, frus1916Supp/d438, frus1916Supp/d308, frus1917Supp01v01/d214, frus1914-20v01/d328, frus1917Supp01v01/d156, frus1916Supp/d414, frus1915Supp/d615, frus1917Supp01v01/d207, frus1915Supp/d632

---

## Q16. How did Kissinger manage the State Department?

### Lexical — `"how" AND "did" AND "kissinger" AND "manage" AND "the" AND "state" AND "department?"`

1. **90. Minutes of Secretary of State Kissinger ’s Regional Staff Meeting** — Washington , July 1, 1976 .  
   `frus1969-76v35/d90` · score -14.9622  
   > 90. Minutes of Secretary of State Kissinger ’s Regional Staff Meeting Source: National Archives, RG 59, Transcripts of Secretary of State Kissinger ’s Staff Meetings, 1973–1977, Lot File 78D443, Box 10, Chronological File. Secret. According…
2. **139. Memorandum of Conversation** — Washington , October 7, 1974, 10:30 a.m.  
   `frus1969-76v38p2/d139` · score -13.7884  
   > 139. Memorandum of Conversation Source: Library of Congress, Manuscript Division, Kissinger Papers, Box CL 346, Department of State, Memoranda of Conversations, Internal, Aug. 1974–Mar. 1975. Secret; Nodis . The meeting took place in Kissin…
3. **11. Minutes of the Secretary of State’s Staff Meeting** — Washington , October 22, 1974, 9–10:10 a.m.  
   `frus1969-76v37/d11` · score -13.5475  
   > 11. Minutes of the Secretary of State’s Staff Meeting Source: National Archives, RG 59, Transcripts of Secretary of State Kissinger ’s Staff Meetings, Lot 78D443, Box 2, Secretary’s Staff Meetings. Secret. Kissinger presided over the meetin…
4. **42. Memorandum of Conversation** — Washington , August 13, 1974 .  
   `frus1969-76v38p1/d42` · score -13.5238  
   > 42. Memorandum of Conversation Source: Library of Congress, Manuscript Division, Kissinger Papers, Box CL 426, Subject File, Media, Briefings, Background, April–October 1974. Confidential; Nodis . Drafted by Robert Anderson ( S/PRS ) and re…
5. **86. Minutes of Secretary of State Kissinger ’s Principals and Regionals Staff Meeting** — Washington , June 27, 1975 .  
   `frus1969-76v22/d86` · score -13.2243  
   > 86. Minutes of Secretary of State Kissinger ’s Principals and Regionals Staff Meeting Source: National Archives, RG 59, Transcripts of Secretary of State Kissinger ’s Staff Meetings, 1973–1977, Lot 78D443, ES177, Secretary’s Staff Meeting, …
6. **350. Memorandum of Conversation** — Washington , November 21, 1973 .  
   `frus1969-76v25/d350` · score -13.1649  
   > 350. Memorandum of Conversation Source: National Archives, Nixon Presidential Materials, NSC Files, Kissinger Office Files, Box 129, Country Files, Middle East, Middle East—1971–72–73–74. Secret; Nodis. Drafted by Korn . Washington , Novemb…
7. **144. Memorandum of Conversation** — Washington , June 5, 1975, 6:30–7:30 p.m.  
   `frus1969-76v38p2/d144` · score -13.0187  
   > 144. Memorandum of Conversation Source: Department of State, Files of Lawrence S. Eagleburger : Lot 84 D 204, Chron—June 1975. Confidential. Drafted by Wesley Egan (S). The meeting was held in Kissinger ’s office at the Department of State.…
8. **230. Memorandum From the Assistant Director, Office of Management and Budget ( Schlesinger ) to the Director ( Shultz )** — Washington , May 11, 1971 .  
   `frus1969-76v02/d230` · score -12.9725  
   > 230. Memorandum From the Assistant Director, Office of Management and Budget ( Schlesinger ) to the Director ( Shultz ) Source: National Archives, Nixon Presidential Materials, NSC Files, Subject Files, Box 332, Intelligence Reorganization,…
9. **218. Memorandum of Conversation** — Washington , November 19, 1976, 3 p.m.  
   `frus1969-76v38p2/d218` · score -12.9302  
   > 218. Memorandum of Conversation Source: Library of Congress, Manuscript Division, Kissinger Papers, Box CL 346, Department of State, Memoranda of Conversations, Internal, November 1976. Secret; Sensitive; Nodis . Washington , November 19, 1…
10. **177. Minutes of Secretary of State Kissinger ’s Staff Meeting** — Washington , October 29, 1973, 3:15 p.m.  
   `frus1969-76v39/d177` · score -12.8682  
   > 177. Minutes of Secretary of State Kissinger ’s Staff Meeting Source: National Archives, RG 59, Transcripts of Secretary of State Kissinger ’s Staff Meetings, 1973–1977, Entry 5177: Lot 78 D 443, Box 1, Secretary’s Staff Meetings. Secret. W…

### Semantic (query prompt)

1. ****  
   `frus1969-76v38p2/d117` · score 0.7187  
   > 117. Editorial Note Following President Nixon ’s inauguration for a second term on January 20, 1973, William P. Rogers remained as Secretary of State, but the President had already determined that Rogers ’ remaining tenure would be brief. S…
2. **139. Memorandum of Conversation** — Washington , October 7, 1974, 10:30 a.m.  
   `frus1969-76v38p2/d139` · score 0.6698  
   > 139. Memorandum of Conversation Source: Library of Congress, Manuscript Division, Kissinger Papers, Box CL 346, Department of State, Memoranda of Conversations, Internal, Aug. 1974–Mar. 1975. Secret; Nodis . The meeting took place in Kissin…
3. **137. Memorandum of Conversation** — Washington , September 27, 1974, 11:30 a.m.  
   `frus1969-76v38p2/d137` · score 0.6469  
   > 137. Memorandum of Conversation Source: Library of Congress, Manuscript Division, Kissinger Papers, Box CL 346, Department of State, Memoranda of Conversations, Internal, Aug. 1974–Mar. 1975. No classification marking. The meeting took plac…
4. ****  
   `frus1969-76v13/d95` · score 0.6345  
   > 95. Editorial Note On January 14, 1971, Assistant to the President for National Security Affairs Henry Kissinger received a telephone call at 7:22 p.m. from Yuli Vorontsov , the Soviet Chargé d’Affaires. According to the transcript, the con…
5. **61. Transcript of Telephone Conversation Between the President’s Assistant for National Security Affairs ( Kissinger ) and Secretary of State Rogers** — Washington , March 16, 1972, 9:40 a.m.  
   `frus1969-76v14/d61` · score 0.6312  
   > 61. Transcript of Telephone Conversation Between the President’s Assistant for National Security Affairs ( Kissinger ) and Secretary of State Rogers Source: Library of Congress, Manuscript Division, Kissinger Papers, Box 371, Telephone Conv…
6. ****  
   `frus1969-76v38p1/d53` · score 0.6268  
   > 53. Editorial Note On March 31, 1975, Secretary of State Henry Kissinger met with Dean Rusk , Cyrus Vance , McGeorge Bundy , George Shultz , Douglas Dillon , W. Averell Harriman , Robert McNamara , David Rockefeller , George Ball , William …
7. **84. Interview With Secretary of State Kissinger** — Washington , undated .  
   `frus1969-76v38p1/d84` · score 0.6204  
   > 84. Interview With Secretary of State Kissinger Source: Department of State Bulletin , February 7, 1977, pp. 102–107. All brackets are in the original. Kissinger was interviewed by James Reston , Hedrick Smith, and Bernard Gwertzman of the …
8. **244. Minutes of the Secretary’s Staff Meeting** — Washington , October 22, 1974. 9 a.m.  
   `frus1969-76ve03/d244` · score 0.6162  
   > 244. Minutes of the Secretary’s Staff Meeting Source: National Archives, RG 59, Central Foreign Policy Files, P870036–2253. Secret. The paper Kissinger asked to see is published as Document 246 . Kissinger discussed with key Department of S…
9. ****  
   `frus1969-76v38p1/d16` · score 0.6161  
   > 16. Editorial Note President Richard Nixon announced the resignation of Secretary of State William P. Rogers during an August 22, 1973, news conference at the Western White House in San Clemente, California. After praising Rogers as one of …
10. **132. Action Memorandum From the Assistant Secretary of State for Public Affairs ( Laise ) to Secretary of State Kissinger** — Washington , April 26, 1974 .  
   `frus1969-76v38p2/d132` · score 0.6142  
   > 132. Action Memorandum From the Assistant Secretary of State for Public Affairs ( Laise ) to Secretary of State Kissinger Source: National Archives, RG 59, General Administrative Correspondence Files of the Deputy Under Secretary for Manage…

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 6/10.*
*document variant:* frus1969-76v38p2/d117, frus1969-76v38p1/d84, frus1969-76v38p2/d139, frus1969-76v01/d80, frus1969-76v38p2/d137, frus1969-76v38p2/d218, frus1969-76v14/d61, frus1969-76v38p1/d25, frus1969-76v13/d95, frus1969-76v38p1/d53
*bare variant:* frus1969-76v38p2/d117, frus1969-76v38p2/d139, frus1969-76v38p2/d137, frus1969-76v38p1/d84, frus1964-68v33/d16, frus1969-76ve03/d244, frus1969-76v13/d95, frus1969-76v02/d297, frus1969-76v02/d123, frus1969-76ve06/d121

---

## Q17. What joke did Mao make about Chinese women?
*known-item*

### Lexical — `"what" AND "joke" AND "did" AND "mao" AND "make" AND "about" AND "chinese" AND "women?"`

1. **126. Memorandum of Conversation, Beijing, April 22, 1972, 4:30-8 p.m.** — Beijing , April 22, 1972, 4:30–8 p.m.  
   `frus1969-76ve13/d126` · score -13.7474  
   > 126. Memorandum of Conversation, Beijing, April 22, 1972, 4:30-8 p.m. Source: National Archives, Nixon Presidential Materials, NSC Files, Box 1038, Files for the President-China Material, Mansfield / Scott Trip to China [April-May 1972]. No…

### Semantic (query prompt)

1. **86. Paper Prepared by the National Security Council Staff, Washington, undated** — Washington , undated  
   `frus1969-76ve13/d86` · score 0.5418  
   > 86. Paper Prepared by the National Security Council Staff, Washington, undated Source: Library of Congress, Manuscript Division, Kissinger Papers, Geopolitical Files, China, Trips, February 1972, Briefing Book. Top Secret; Sensitive; Exclus…
2. **12. Memorandum of Conversation** — Beijing , February 17–18, 1973, 11:30 p.m.–1:20 a.m.  
   `frus1969-76v18/d12` · score 0.5203  
   > 12. Memorandum of Conversation Source: National Archives, Nixon Presidential Materials, NSC Files, Kissinger Office Files, Box 98, Country Files, Far East, HAK China Trip, Memcons & Reports (originals), February 1973. Top Secret; Sensitive;…
3. **58. Memorandum of Conversation** — Beijing , November 12, 1973, 5:40–8:25 p.m.  
   `frus1969-76v18/d58` · score 0.5039  
   > 58. Memorandum of Conversation Source: National Archives, Nixon Presidential Materials, NSC Files, Kissinger Office Files, Box 100, Country Files, Far East, Secretary Kissinger ’s Conversations in Peking, November 1973. Top Secret; Sensitiv…
4. **264. Memorandum From the Director of the Office of Chinese Affairs ( Clough ) to the Assistant Secretary of State for Far Eastern Affairs ( Robertson )** — Washington , June 20, 1957 .  
   `frus1955-57v03/d264` · score 0.5011  
   > 264. Memorandum From the Director of the Office of Chinese Affairs ( Clough ) to the Assistant Secretary of State for Far Eastern Affairs ( Robertson ) Source: Department of State, Central Files, 793.11/6–2057. Drafted in CA by Bennett. Was…
5. **193. Memorandum From the President’s Assistant for National Security Affairs ( Kissinger ) to President Nixon** — Washington , February 19, 1972 .  
   `frus1969-76v17/d193` · score 0.4913  
   > 193. Memorandum From the President’s Assistant for National Security Affairs ( Kissinger ) to President Nixon Source: National Archives, Nixon Presidential Materials, NSC Files, Box 847, President’s File—China Trip, China Visit—Readings on …
6. **124. Memorandum of Conversation** — Beijing , October 21, 1975, 6:25–8:05 p.m.  
   `frus1969-76v18/d124` · score 0.4745  
   > 124. Memorandum of Conversation Source: Ford Library, National Security Adviser, Kissinger Reports on USSR , China, and Middle East Discussions, Box 2, China Memcons and Reports, October 19–23, 1975, Kissinger ’s Trip. Secret; Sensitive. Th…
7. **The Ambassador in China ( Stuart ) to the Secretary of State** — Nanking , July 6, 1949—1 p. m. [Received July 6—6:34 a. m.]  
   `frus1949v08/d478` · score 0.4675  
   > 893.00/7–649: Telegram The Ambassador in China ( Stuart ) to the Secretary of State Nanking , July 6, 1949—1 p. m. [Received July 6—6:34 a. m.] 1443. We owe to Mao Tse-tung vote of thanks for his article “On People’s Democratic Dictatorship…
8. **Memorandum by Mr. Everett F. Drumright of the Division of Chinese Affairs** — [ Washington , May 1, 1945 .]  
   `frus1945v07/d248` · score 0.4612  
   > 893.00B/5–145 Memorandum by Mr. Everett F. Drumright of the Division of Chinese Affairs [ Washington , May 1, 1945 .] It seems clear that Mao Tse-tung’s report “On the Coalition Government” Supra . merits our close study. In this report, Ma…
9. **Report by the Second Secretary of Embassy in China ( Service )** — [ Yenan ,] April 1, 1945 .  
   `frus1945v07/d224` · score 0.4602  
   > 893.00/4–145 Report by the Second Secretary of Embassy in China ( Service ) Received in the Department about April 27. No. 26 [ Yenan ,] April 1, 1945 . Attached is a memorandum of a conversation on this date with a group of Communist leade…
10. **303. Paper Prepared by Alfred Jenkins of the National Security Council Staff** — Washington , February 22, 1968 .  
   `frus1964-68v30/d303` · score 0.4583  
   > 303. Paper Prepared by Alfred Jenkins of the National Security Council Staff Source: Johnson Library, National Security File, Country File, China, Vol. XII. Secret. Rostow sent the paper to the President with a covering note of the same dat…

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
   > 3. Paper Prepared in the Department of State Source: Carter Library, National Security Affairs, Staff Material, North/South, Box 42, Panama, PRM –1, 1/77. Secret. Prepared in response to PRM –1. The Defense Department and CIA contributed to…
2. **553. Memorandum From Secretary of Defense Laird to President Nixon** — Washington , September 3, 1971  
   `frus1969-76ve10/d553` · score 0.6740  
   > 553. Memorandum From Secretary of Defense Laird to President Nixon Source: Washington National Records Center, OASD /ISD Files: FRC 330–74–083, Panama 1971, 821. Secret; Noforn. Prepared on August 26 by Colonel Mallett ( DOD /IA). Published…
3. **428. Memorandum From the President’s Special Representatives ( Anderson and Irwin ) to President Johnson** — Washington , September 2, 1965 .  
   `frus1964-68v31/d428` · score 0.6733  
   > 428. Memorandum From the President’s Special Representatives ( Anderson and Irwin ) to President Johnson Source: Johnson Library, National Security File, NSC Histories, Panama. Confidential. The memorandum was unsigned, but a handwritten li…
4. **52. Memorandum of Conversation** — Grenada , June 15, 1977  
   `frus1977-80v29/d52` · score 0.6705  
   > 52. Memorandum of Conversation Source: National Archives, RG 59, Central Foreign Policy File, P770115–2347. Confidential. Drafted by Mark Dion ( USOAS ) on June 16 and approved by Twaddell on June 29. The meeting took place during breakfast…
5. **533. Memorandum From the NSC Inter-Departmental Group for Inter-American Affairs to President Nixon** — Washington , April 6, 1970  
   `frus1969-76ve10/d533` · score 0.6685  
   > 533. Memorandum From the NSC Inter-Departmental Group for Inter-American Affairs to President Nixon Source: National Archives, Nixon Presidential Materials, NSC Files, NSC Institutional Files (H-Files), Box H–169, NSSM Files, NSSM 86. Secre…
6. **The Panaman Minister ( Alfaro ) to the Secretary of State** — Washington , January 3, 1923 .  
   `frus1923v02/d574` · score 0.6680  
   > 611.1931/45 The Panaman Minister ( Alfaro ) to the Secretary of State [Translation File translation revised. ] Washington , January 3, 1923 . Mr. Secretary : When the Republic of Panama seceded from Colombia in 1903 See Foreign Relations , …
7. **89. Minutes of a Cabinet Meeting** — Washington , August 29, 1977, 9:05 a.m.  
   `frus1977-80v29/d89` · score 0.6679  
   > 89. Minutes of a Cabinet Meeting Source: Central Intelligence Agency, Office of the Director of Central Intelligence, Job 80M00165A, Box 23, Folder 3: 468. No classification marking. The meeting ended at 10:54 a.m. Washington , August 29, 1…
8. **79. Memorandum From the Assistant to the President ( Jordan ) and William Hyland of the National Security Council Staff to President Carter** — Washington , August 9, 1977  
   `frus1977-80v29/d79` · score 0.6647  
   > 79. Memorandum From the Assistant to the President ( Jordan ) and William Hyland of the National Security Council Staff to President Carter Source: Carter Library, Plains Files, President’s Personal Foreign Affairs File, Box 3, Panama Canal…
9. **20. Briefing Memorandum From Ambassador at Large ( Bunker ) and Panama Canal Treaty Co-Negotiator ( Linowitz ) to Secretary of State Vance** — Washington , February 25, 1977  
   `frus1977-80v29/d20` · score 0.6634  
   > 20. Briefing Memorandum From Ambassador at Large ( Bunker ) and Panama Canal Treaty Co-Negotiator ( Linowitz ) to Secretary of State Vance Source: National Archives, RG 59, Official and Personal Files of Ambassador at Large Ellsworth Bunker…
10. **223. Internal Transcript of a White House Briefing** — Washington , May 8, 1979, 7:40–9:05 p.m.  
   `frus1977-80v29/d223` · score 0.6603  
   > 223. Internal Transcript of a White House Briefing Source: National Archives, RG 59, Files of Assistant Secretary J. Brian Atwood , Subject Files and Chrons. 1977/78/79/80, Lot 81D115, Box 2, Panama Implementing Legislation. No classificati…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 7/10.*
*document variant:* frus1969-76v22/d44, frus1964-68v31/d428, frus1977-80v29/d79, frus1969-76ve10/d533, frus1977-80v29/d3, frus1977-80v01/d67, frus1977-80v29/d89, frus1977-80v29/d20, frus1969-76ve10/d553, frus1969-76ve10/d530
*bare variant:* frus1977-80v29/d3, frus1969-76ve10/d553, frus1977-80v29/d89, frus1977-80v29/d223, frus1969-76v22/d44, frus1964-68v31/d428, frus1977-80v29/d52, frus1969-76v22/d13, frus1977-80v29/d79, frus1969-76v22/d94

---

## Q19. Climate diplomacy

### Lexical — `"climate" AND "diplomacy"`

1. **303. Memorandum From the Assistant to the President’s Special Assistant for Health Issues ( Fill ) to the President’s Special Assistant for Health Issues ( Bourne )** — Washington , November 30, 1977  
   `frus1977-80v02/d303` · score -14.6028  
   > 303. Memorandum From the Assistant to the President’s Special Assistant for Health Issues ( Fill ) to the President’s Special Assistant for Health Issues ( Bourne ) Source: Carter Library, Staff Office Files, Special Assistant for Health Is…
2. **497. Memorandum From the President’s Assistant for National Security Affairs ( Brzezinski ) to Secretary of State Vance , Secretary of Defense Brown , the Director of the Office of Management and Budget ( McIntyre ), the Director of the Arms Control and Disarmament Agency ( Warnke ), and the Director of the International Communication Agency (Reinhardt)** — Washington , June 8, 1978  
   `frus1977-80v26/d497` · score -11.9126  
   > 497. Memorandum From the President’s Assistant for National Security Affairs ( Brzezinski ) to Secretary of State Vance , Secretary of Defense Brown , the Director of the Office of Management and Budget ( McIntyre ), the Director of the Arm…
3. ****  
   `frus1969-76v01/d6` · score -11.5303  
   > 6. Editorial Note Richard Nixon offered his perspective on prospects for détente with the Soviet Union in his acceptance speech at the Republican convention in Miami Beach, Florida, on August 8, 1968: “And now to the leaders of the Communis…
4. **134. Memorandum From the President’s Assistant for National Security Affairs ( Brzezinski ) to Secretary of State Vance , Secretary of Defense Brown , the Director of the Office of Management and Budget ( McIntyre ), the Director of the Arms Control and Disarmament Agency ( Warnke ), and the Director of the International Communication Agency ( Reinhardt )** — Washington , undated  
   `frus1977-80v30/d134` · score -11.3745  
   > 134. Memorandum From the President’s Assistant for National Security Affairs ( Brzezinski ) to Secretary of State Vance , Secretary of Defense Brown , the Director of the Office of Management and Budget ( McIntyre ), the Director of the Arm…
5. **The Chargé in the Soviet Union ( Kennan ) to the Secretary of State** — Moscow , March 20, 1946—2 p.m. [Received 4:59 p.m.]  
   `frus1946v06/d487` · score -11.1652  
   > 761.00/3–2046: Telegram The Chargé in the Soviet Union ( Kennan ) to the Secretary of State secret Moscow , March 20, 1946—2 p.m. [Received 4:59 p.m.] 878. In recent days we have noted a number of statements made either editorially in Ameri…
6. **317. Letter From Prime Minister Nehru to President Kennedy** — New Delhi , August 11, 1963 .  
   `frus1961-63v19/d317` · score -10.6581  
   > 317. Letter From Prime Minister Nehru to President Kennedy Source: Kennedy Library, National Security Files, Countries Series, India, Nehru Correspondence, 4/1/63-8/31/63. No classification marking. New Delhi , August 11, 1963 . Dear Mr. Pr…
7. **43. Contingency Study Prepared by the National Security Council Interdepartmental Working Group/Europe, Washington, undated.** — Washington , undated .  
   `frus1969-76ve15p1/d43` · score -10.4550  
   > 43. Contingency Study Prepared by the National Security Council Interdepartmental Working Group/Europe, Washington, undated. Source: National Security Council, Ford Subject Files, Romania. No classification marking. Attached but not publish…
8. **172. Minutes of National Security Council Meeting** — Washington , January 13, 1977, 10:30–11:30 a.m.  
   `frus1969-76v35/d172` · score -9.9582  
   > 172. Minutes of National Security Council Meeting Source: Ford Library, National Security Adviser, National Security Council Meetings File, Box 2, NSC Meeting, January 13, 1977. Top Secret; Sensitive. The meeting was held in the White House…
9. **No. 783. Mr. Beardsley to Mr. Fish .** — Agency and Consulate-General of the United States in Egypt , Cairo , September 3, 1873 . (Received September 29.)  
   `frus1874/d786` · score -9.9402  
   > No. 783. Mr. Beardsley to Mr. Fish . Agency and Consulate-General of the United States in Egypt , Cairo , September 3, 1873 . (Received September 29.) No. 123.] Sir : I have the honor to inform you that Sir Samuel Baker and Lady Baker arriv…
10. **33. Memorandum From Robert Pastor of the National Security Council Staff to the President’s Assistant for National Security Affairs ( Brzezinski )** — Washington , October 4, 1978  
   `frus1977-80v24/d33` · score -9.8273  
   > 33. Memorandum From Robert Pastor of the National Security Council Staff to the President’s Assistant for National Security Affairs ( Brzezinski ) Source: Carter Library, National Security Affairs, Brzezinski Material, Country File, Box 45,…

### Semantic (query prompt)

1. **356. Telegram From the Embassy in France to Multiple Recipients** — Paris , December 9, 1986, 1653Z  
   `frus1981-88v41/d356` · score 0.5435  
   > 356. Telegram From the Embassy in France to Multiple Recipients Source: Reagan Library, Robert Johnson Files, Stratospheric Ozone—#4. Unclassified. Sent Priority to the Department of State. Sent to the White House, the OECD collective, Beij…
2. **352. Telegram From the Department of State to Multiple Diplomatic Posts** — Washington , March 30, 1985, 0546Z  
   `frus1981-88v41/d352` · score 0.5310  
   > 352. Telegram From the Department of State to Multiple Diplomatic Posts Source: Department of State, Environmental Issues, 1979–1993, Lot 93D395, Ozone. Limited Official Use. Drafted by Hajost , Losey , and Weil ; cleared by Benedick and Ma…
3. **36. Information Memorandum From the Assistant Secretary of State for Economic and Business Affairs ( Hormats ) to Secretary of State Haig** — Washington , undated  
   `frus1981-88v38/d36` · score 0.5245  
   > 36. Information Memorandum From the Assistant Secretary of State for Economic and Business Affairs ( Hormats ) to Secretary of State Haig Source: Reagan Library, Douglas McMinn Files, Subject Files, Global Negotiations; NLR–369–3–22–12–2. C…
4. **358. Telegram From the United States USUN Environmental Mission to the Department of State** — Vienna , February 26, 1987, 1932Z  
   `frus1981-88v41/d358` · score 0.5140  
   > 358. Telegram From the United States USUN Environmental Mission to the Department of State Source: Reagan Library, Bledsoe, Ralph: Files, 330—Stratospheric Ozone (1985 to June 1987) [6]. Limited Official Use; Immediate. Sent Immediate for i…
5. **325. Report on the UN Conference on the Human Environment from the Vice-Chairman of Delegation ( Herter ) to Secretary of State Rogers** — Washington , July 28, 1972 .  
   `frus1969-76ve01/d325` · score 0.5092  
   > 325. Report on the UN Conference on the Human Environment from the Vice-Chairman of Delegation ( Herter ) to Secretary of State Rogers Source: National Archives, RG 59, Central Files 1970-73, SCI 41-3 UN . Confidential. Herter transmitted t…
6. **355. Action Memorandum From the Assistant Secretary of State for Oceans and International Environmental and Scientific Affairs ( Negroponte ) to the Under Secretary of State for Economic Affairs ( Wallis )** — Washington , November 28, 1986  
   `frus1981-88v41/d355` · score 0.5030  
   > 355. Action Memorandum From the Assistant Secretary of State for Oceans and International Environmental and Scientific Affairs ( Negroponte ) to the Under Secretary of State for Economic Affairs ( Wallis ) Source: Reagan Library, Bledsoe, R…
7. **299. Memorandum From Acting Secretary of State Johnson to President Nixon** — Washington , August 24, 1970 .  
   `frus1969-76ve01/d299` · score 0.5014  
   > 299. Memorandum From Acting Secretary of State Johnson to President Nixon Source: National Archives, RG 59, Central Files 1970-73, SCI 41. Unclassified. Drafted by Herter . A notation on the first page indicated that the President approved …
8. **373. Telegram From the Consulate in Canada to the Department of State** — Montreal , September 11, 1987, 1252Z  
   `frus1981-88v41/d373` · score 0.4995  
   > 373. Telegram From the Consulate in Canada to the Department of State Source: Department of State, Environmental Issues, 1979–1993, Lot 93D395, Ozone. Confidential; Immediate. Montreal , September 11, 1987, 1252Z 2997. Subject: Ozone Protoc…
9. **367. Briefing Memorandum From the Acting Assistant Secretary of State for Oceans and International Environmental and Scientific Affairs ( Benedick ) to the Deputy Secretary of State ( Whitehead )** — Washington , June 9, 1987  
   `frus1981-88v41/d367` · score 0.4929  
   > 367. Briefing Memorandum From the Acting Assistant Secretary of State for Oceans and International Environmental and Scientific Affairs ( Benedick ) to the Deputy Secretary of State ( Whitehead ) Source: Department of State, Environmental I…
10. **10. Memorandum From the U.S. Special Negotiator for Economic Matters ( Meissner ) to the Under Secretary of State-Designate for Economic Affairs ( Rashish ), the Assistant Secretary of State-Designate for Economic and Business Affairs ( Hormats ), and Henry Nau of the National Security Council Staff** — Washington , April 21, 1981  
   `frus1981-88v38/d10` · score 0.4923  
   > 10. Memorandum From the U.S. Special Negotiator for Economic Matters ( Meissner ) to the Under Secretary of State-Designate for Economic Affairs ( Rashish ), the Assistant Secretary of State-Designate for Economic and Business Affairs ( Hor…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 2/10.*
*document variant:* frus1981-88v41/d356, frus1981-88v41/d362, frus1981-88v41/d352, frus1981-88v38/d36, frus1969-76ve01/d325, frus1981-88v41/d358, frus1981-88v41/d373, frus1907p2/d508p, frus1981-88v41/d368, frus1969-76ve01/d306
*bare variant:* frus1907p2/d508p, frus1981-88v38/d36, frus1969-76ve08/d171, frus1919Parisv03/d11, frus1969-76v37/d31, frus1981-88v01/d149, frus1981-88v41/d367, frus1969-76ve03/d36, frus1969-76ve14p1/d39, frus1969-76ve03/d35

---

## Q20. Window of vulnerability

### Lexical — `"window" AND "of" AND "vulnerability"`

1. **183. Memorandum From Secretary of Defense Brown to President Carter** — Washington , April 30, 1980  
   `frus1977-80v04/d183` · score -13.8845  
   > 183. Memorandum From Secretary of Defense Brown to President Carter Source: Carter Library, National Security Affairs, Brzezinski Donated Material, Subject File, Box 20, Alpha Channel (Miscellaneous)—[4/80–6/80]. Secret; Sensitive. Carter w…
2. **264. Information Memorandum From the Director of the Policy Planning Staff (Solomon) to Secretary of State Shultz** — Washington , January 27, 1988  
   `frus1981-88v11/d264` · score -10.4867  
   > 264. Information Memorandum From the Director of the Policy Planning Staff (Solomon) to Secretary of State Shultz Source: Department of State, Memoranda/Correspondence From the Director of the Policy Planning Staff to the Secretary: Lot 89D…
3. **237. Memorandum From the Assistant Secretary of the Treasury for International Affairs ( Mulford ) to Secretary of the Treasury Baker** — Washington , February 26, 1988  
   `frus1981-88v38/d237` · score -9.3837  
   > 237. Memorandum From the Assistant Secretary of the Treasury for International Affairs ( Mulford ) to Secretary of the Treasury Baker Source: National Archives, RG 56, Records of the Office of the Secretary of the Treasury, Congressional Co…
4. **204. Memorandum to the Chairman of the 40 Committee** — Washington , June 2, 1975 .  
   `frus1969-76v35/d204` · score -9.2331  
   > 204. Memorandum to the Chairman of the 40 Committee Source: National Security Council Files, Ford Administration Intelligence Files, MATADOR , 1975. Top Secret; [ codeword not declassified ]; MATADOR . Washington , June 2, 1975 . SUBJECT Pr…
5. **The Ambassador in the Soviet Union ( Harriman ) to the Secretary of State** — Moscow , January 20, 1946—noon. [Received 4:03 p.m.]  
   `frus1946v06/d463` · score -8.3287  
   > 811.20200 (D)/1–2046: Telegram The Ambassador in the Soviet Union ( Harriman ) to the Secretary of State confidential Moscow , January 20, 1946—noon. [Received 4:03 p.m.] 187. . . . In evaluating need for information program directed to USS…
6. **96. Backchannel Message From the Ambassador to Chile ( Korry ) to the Under Secretary of State for Political Affairs ( Johnson )** — Santiago , September 16, 1970 .  
   `frus1969-76v21/d96` · score -8.0978  
   > 96. Backchannel Message From the Ambassador to Chile ( Korry ) to the Under Secretary of State for Political Affairs ( Johnson ) Source: National Security Council, Nixon Intelligence Files, Subject Files, Chile, 1970. Secret; Sensitive. San…
7. **211. Memorandum From the President’s Assistant for National Security Affairs ( Kissinger ) to President Nixon** — Washington , February 20, 1970 .  
   `frus1969-76v20/d211` · score -8.0869  
   > 211. Memorandum From the President’s Assistant for National Security Affairs ( Kissinger ) to President Nixon Source: National Archives, Nixon Presidential Materials, NSC Files, Subject Files, Box 338, HAK/ Richardson Meetings, January 1970…
8. **80. Memorandum From Senator Nunn to President Bush** — Washington , February 22, 1990  
   `frus1989-92v31/d80` · score -7.9517  
   > 80. Memorandum From Senator Nunn to President Bush Source: Department of State, Economic and Agricultural Affairs, Lot 96D484, Robert B. Zoellick , Under Secretary for Economic and Agricultural Affairs, Gates Group NODIS . No classification…
9. **368. Telegram From the Embassy in the United Arab Republic to the Department of State** — Cairo , March 19, 1959, 2 p.m.  
   `frus1958-60v12/d368` · score -7.5666  
   > 368. Telegram From the Embassy in the United Arab Republic to the Department of State Source: Department of State, Central Files, 786H.00/3–1–959. Transmitted in two sections and repeated to Jidda, London, Rome, Bonn, Taiz, and Aden. Cairo …
10. **Memorandum of Conversation, by Mr. Elbridge Durbrow of the Division of European Affairs** — [ Washington ,] February 3, 1943 .  
   `frus1943v03/d374` · score -7.4768  
   > 711.61/2–343 Memorandum of Conversation, by Mr. Elbridge Durbrow of the Division of European Affairs [ Washington ,] February 3, 1943 . The following is an outline of a conversation I had with Mr. Joseph E. Davies Ambassador to the Soviet U…

### Semantic (query prompt)

1. **The Acting Secretary of State to Minister Beaupré .** — Department of State , Washington , May 9, 1910 .  
   `frus1910/d68` · score 0.4637  
   > File No. 23700/20. The Acting Secretary of State to Minister Beaupré . [Telegram.—Paraphrase.] Department of State , Washington , May 9, 1910 . Mr. Wilson acknowledges legation’s May 7, and says that under the laws of the United States Knep…
2. **125. Information Memorandum From the Director of the Policy Planning Staff ( Wolfowitz ) to Secretary of State Shultz** — Washington , August 5, 1982  
   `frus1981-88v38/d125` · score 0.4138  
   > 125. Information Memorandum From the Director of the Policy Planning Staff ( Wolfowitz ) to Secretary of State Shultz Source: Department of State, Executive Secretariat, S/P Records, Memoranda/Correspondence From the Director of the Policy …
3. **57. Paper Prepared in the Department of the Navy** — Washington , undated .  
   `frus1969-76v37/d57` · score 0.4100  
   > 57. Paper Prepared in the Department of the Navy Source: Washington National Records Center, OSD Files: FRC 330–79–0049, Box 82, Saudi Arabia. Unclassified. Attached to this paper is a note from Rear Admiral Staser Holcomb to Schlesinger th…
4. **The President of the Standard Oil Company of New Jersey ( W. C. Teagle ) to the Secretary of State** — New York , April 17, 1923 . [Received April 18.]  
   `frus1923v02/d159` · score 0.4051  
   > 890g.6363 T 84/92 The President of the Standard Oil Company of New Jersey ( W. C. Teagle ) to the Secretary of State New York , April 17, 1923 . [Received April 18.] My Dear Mr. Secretary : For your information, I beg to advise you of recen…
5. **Mr. Terrell to Mr. Olney .** — Legation of the United States , Constantinople , October 12, 1896 . (Received Oct. 26.)  
   `frus1896/d842` · score 0.3974  
   > Mr. Terrell to Mr. Olney . Legation of the United States , Constantinople , October 12, 1896 . (Received Oct. 26.) No. 1019.] Sir : I have the honor to inclose for your information the copy of a dispatch from the British vice-consul at Harp…
6. **444. Memorandum From Berkner to Killian** — March 24, 1959  
   `frus1958-60v03mSupp/d444` · score 0.3941  
   > 444. Memorandum From Berkner to Killian Source: Transmits report on concealment of underground explosions. Secret. 7 pp. Eisenhower Library, White House Office Files, Additional Records of the Office of the Special Assistant for Science and…
7. **Mr. Adams to Mr. Seward** — Legation of the United States , London , December 14, 1867.  
   `frus1868p1/d8` · score 0.3936  
   > Mr. Adams to Mr. Seward No. 1495.] Legation of the United States , London , December 14, 1867. Sir: In accordance with the directions contained in yonr dispatch No. 2105, I have written to Mr. West to apply for an official report of Captain…
8. **No. 774. Mr. Bayard to Mr. Bragg .** — Department of State , Washington , March 15, 1888 .  
   `frus1888p2/d61` · score 0.3935  
   > No. 774. Mr. Bayard to Mr. Bragg . Department of State , Washington , March 15, 1888 . No. 8.] Sir : Referring to the subject of the murder of Leon McLeod Baldwin, a citizen of the United States, of which Mr. Connery informed me in his disp…
9. **Professor A. C. Coolidge to the Commission to Negotiate Peace** — Vienna , April 22, 1919 . [Received April 25.]  
   `frus1919Parisv12/d101` · score 0.3911  
   > Paris Peace Conf. 184.01102/388 Professor A. C. Coolidge to the Commission to Negotiate Peace No. 238 Vienna , April 22, 1919 . [Received April 25.] Sirs : I have the honor to enclose herewith two reports Second report, dated April 22, not …
10. **173. Memorandum From Victor Utgoff of the National Security Council Staff to the President’s Assistant for National Security Affairs (Brzezinski)** — Washington , February 8, 1980  
   `frus1977-80v04/d173` · score 0.3878  
   > 173. Memorandum From Victor Utgoff of the National Security Council Staff to the President’s Assistant for National Security Affairs (Brzezinski) Source: Carter Library, National Security Affairs, Brzezinski Material, Subject File, Box 43, …

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 7/10, bare: 5/10.*
*document variant:* frus1910/d68, frus1952-54v06p2/d1001, frus1958-60v03mSupp/d444, frus1896/d842, frus1868p1/d8, frus1969-76v37/d57, frus1931v02/d248, frus1923v02/d159, frus1977-80v04/d173, frus1977-80v03/d314
*bare variant:* frus1910/d68, frus1958-60v03mSupp/d444, frus1981-88v38/d125, frus1961-63v23/d225, frus1923v02/d159, frus1896/d842, frus1981-88v04/d110, frus1977-80v11p1/d37, frus1969-76ve01/d38, frus1964-68v18/d172

---

## Q21. washington naval conference ratios

### Lexical — `"washington" AND "naval" AND "conference" AND "ratios"`

1. **The Ambassador in Japan ( Grew ) to the Secretary of State** — Tokyo , February 1, 1934—5 p.m. [Received February 1—6:24 a.m.]  
   `frus1934v03/d21` · score -17.6368  
   > 500.A15a5/21: Telegram The Ambassador in Japan ( Grew ) to the Secretary of State Tokyo , February 1, 1934—5 p.m. [Received February 1—6:24 a.m.] 21. Yesterday in the Diet Foreign Minister Hirota stated in effect: “Japan’s policy toward the…
2. **The Minister in China ( Johnson ) to the Secretary of State** — Peiping , August 16, 1934 . [Received September 8.]  
   `frus1934v03/d192` · score -17.4081  
   > 500.A15a5/182 The Minister in China ( Johnson ) to the Secretary of State No. 2907 Peiping , August 16, 1934 . [Received September 8.] Sir : I have the honor to report statements made on August 13, 1934, to a member of my staff by Mr. Hagiw…
3. **The Secretary of State to the Japanese Ambassador ( Debuchi )** — [ Washington , November 12, 1929 .]  
   `frus1929v01/d180` · score -17.3310  
   > 500.A15a3/387 The Secretary of State to the Japanese Ambassador ( Debuchi ) [ Washington , November 12, 1929 .] Aide-Mémoire You have asked me for an expression of my opinion as to the proposed ratio for Japan in the several classes to be d…
4. **The Acting Chairman of the American Delegation ( Gibson ) to the Secretary of State** — Geneva , March 27, 1933—3 p.m. [Received March 27—10:25 a.m.]  
   `frus1933v01/d59` · score -17.3003  
   > 500.A15A4 Air Armaments/231: Telegram The Acting Chairman of the American Delegation ( Gibson ) to the Secretary of State Geneva , March 27, 1933—3 p.m. [Received March 27—10:25 a.m.] 594. Your 311, March 23, 6 p.m., reference paragraph on …
5. **Memorandum by the Chief of the Division of Far Eastern Affairs ( Hornbeck ) to the Secretary of State** — [ Washington ,] March 31, 1934 .  
   `frus1934v01/d174` · score -17.2363  
   > 500.A15A5/45½ Memorandum by the Chief of the Division of Far Eastern Affairs ( Hornbeck ) to the Secretary of State [ Washington ,] March 31, 1934 . Mr. Secretary : Referring further to the question of the (problematical) Naval Conference: …
6. **The Department of State to the Japanese Embassy**  
   `frus1929v01/d207` · score -16.5943  
   > 500.A15a3/550 The Department of State to the Japanese Embassy Copies also sent to the British, French, and Italian Embassies. Memorandum During the stay in Washington of the Japanese Delegates to the London Naval Conference, they attended t…
7. **Memorandum by the Under Secretary of State ( Phillips )** — [ Washington ,] May 24, 1934 .  
   `frus1934v01/d184` · score -16.5414  
   > 500.A15A5/58 Memorandum by the Under Secretary of State ( Phillips ) [ Washington ,] May 24, 1934 . During my conversation with the President this morning he said that he wanted Assistant Secretary Roosevelt, Henry L. Roosevelt, Assistant S…
8. **The Ambassador in Great Britain ( Bingham ) to the Secretary of State** — London , June 18, 1934—10 p.m. [Received June 18—8:20 p.m.]  
   `frus1934v01/d207` · score -16.5353  
   > 500.A15A5/94: Telegram The Ambassador in Great Britain ( Bingham ) to the Secretary of State London , June 18, 1934—10 p.m. [Received June 18—8:20 p.m.] 332. From Norman Davis. Chairman of the American delegation to the General Disarmament …
9. **The Chargé in Japan ( Neville ) to the Secretary of State** — Tokyo , November 2, 1935 . [Received November 18.]  
   `frus1931-41v01/d203` · score -16.3033  
   > 500. A15A 5/549 The Chargé in Japan ( Neville ) to the Secretary of State No. 1539 Tokyo , November 2, 1935 . [Received November 18.] Sir : I have the honor to observe that with Japan’s acceptance on October 29 of the British Government’s i…
10. **The Ambassador in Japan ( Warren ) to the Secretary of State** — Tokyo , December 3, 1921—2 p.m. [Received December 3—1:43 p.m.]  
   `frus1922v01/d47` · score -16.2204  
   > 500.A4/314: Telegram The Ambassador in Japan ( Warren ) to the Secretary of State [Paraphrase] Tokyo , December 3, 1921—2 p.m. [Received December 3—1:43 p.m.] 405. My telegram no. 403, November 30. There is evidence of Government efforts, s…

### Semantic (query prompt)

1. **The Department of State to the Japanese Embassy**  
   `frus1929v01/d207` · score 0.6163  
   > 500.A15a3/550 The Department of State to the Japanese Embassy Copies also sent to the British, French, and Italian Embassies. Memorandum During the stay in Washington of the Japanese Delegates to the London Naval Conference, they attended t…
2. **The Secretary of State to the Japanese Ambassador ( Debuchi )** — [ Washington , November 12, 1929 .]  
   `frus1929v01/d180` · score 0.6094  
   > 500.A15a3/387 The Secretary of State to the Japanese Ambassador ( Debuchi ) [ Washington , November 12, 1929 .] Aide-Mémoire You have asked me for an expression of my opinion as to the proposed ratio for Japan in the several classes to be d…
3. **The Secretary of State to the Ambassador in Great Britain ( Dawes )** — Washington , August 28, 1929—7 p.m.  
   `frus1929v01/d132` · score 0.6016  
   > 500.A15a3/130: Telegram The Secretary of State to the Ambassador in Great Britain ( Dawes ) [Paraphrase] Washington , August 28, 1929—7 p.m. 225. Relative to your telegram No. 242, August 24, 2 p.m. The following review of our points of agr…
4. **The Secretary of State to the Ambassador in Great Britain ( Dawes )** — Washington , September 11, 1929—8 p.m.  
   `frus1929v01/d144` · score 0.5975  
   > 500.A15a3/162: Telegram The Secretary of State to the Ambassador in Great Britain ( Dawes ) Washington , September 11, 1929—8 p.m. 244. The following principles are set down upon which the Government of the United States and His Majesty’s G…
5. **Memorandum by the Japanese Naval Experts** — [ Washington ,] November 30, 1921 .  
   `frus1922v01/d43` · score 0.5876  
   > 500.A4b/548½ Memorandum by the Japanese Naval Experts [ Washington ,] November 30, 1921 . 1. At the Second Plenary session of the Conference, Baron Kato, as Plenipotentiary Delegate for Japan, expressed his approval of the American proposal…
6. **Memorandum by the American Naval Experts** — [ Washington , undated. ]  
   `frus1922v01/d44` · score 0.5859  
   > 500.A4b/548½ Memorandum by the American Naval Experts [ Washington , undated. ] In reply to the paper submitted by Vice Admiral Kato at the informal meeting of the Naval Advisors on November 30th, Memorandum by Japanese naval experts, supra…
7. **Speech Delivered by Mr. Norman H. Davis at London on December 6, 1934** — London , December 6, 1934  
   `frus1931-41v01/d193` · score 0.5857  
   > 500.A15A5/321½ Speech Delivered by Mr. Norman H. Davis at London on December 6, 1934 At a luncheon given by the Association of American Correspondents in London to the members of the American delegation in the preliminary naval conversation…
8. **Memorandum by the Chief of the Division of Far Eastern Affairs ( Hornbeck ) to the Secretary of State** — [ Washington ,] March 31, 1934 .  
   `frus1934v01/d174` · score 0.5817  
   > 500.A15A5/45½ Memorandum by the Chief of the Division of Far Eastern Affairs ( Hornbeck ) to the Secretary of State [ Washington ,] March 31, 1934 . Mr. Secretary : Referring further to the question of the (problematical) Naval Conference: …
9. **Memorandum of Conversation Between the American and the Japanese Delegations** — [ London ,] December 17, 1935 .  
   `frus1931-41v01/d206` · score 0.5806  
   > 500.A15A5/598 Memorandum of Conversation Between the American and the Japanese Delegations [ London ,] December 17, 1935 . Present: Admiral Nagano Mr. Nagai Admiral Iwashita Mr. Terasaki Mr. Mizota Mr. Davis Mr. Phillips Admiral Standley Mr…
10. **The Secretary of State to the, Ambassador in Japan ( Warren )** — Washington , November 19, 1921—7 p.m.  
   `frus1922v01/d38` · score 0.5718  
   > 500.A492/176a: Telegram The Secretary of State to the, Ambassador in Japan ( Warren ) Washington , November 19, 1921—7 p.m. 199. Your telegram 390, November 17, 9 p.m. In yesterday’s press appears what purports to be an official announcemen…

*Route overlap: 3 of 10 shared. Prompt variants vs primary — document: 8/10, bare: 7/10.*
*document variant:* frus1922v01/d43, frus1929v01/d180, frus1922v01/d44, frus1929v01/d207, frus1929v01/d132, frus1929v01/d144, frus1934v01/d174, frus1931-41v01/d211, frus1929v01/d107, frus1931-41v01/d193
*bare variant:* frus1929v01/d207, frus1929v01/d180, frus1922v01/d44, frus1929v01/d132, frus1922v01/d43, frus1929v01/d144, frus1922v01/d42, frus1929v01/d107, frus1929v01/d85, frus1934v01/d174

---

## Q22. sussex pledge

### Lexical — `"sussex" AND "pledge"`

1. **The Secretary of State to the Ambassador in Germany ( Gerard )** — Washington , April 18, 1916, 6 p. m.  
   `frus1916Supp/d308` · score -16.9310  
   > File No. 763.72/2597a The Secretary of State to the Ambassador in Germany ( Gerard ) [Telegram] Washington , April 18, 1916, 6 p. m. 2913. You are instructed to deliver to the Secretary of Foreign Affairs a communication reading as follows:…
2. **The Ambassador in Germany ( Gerard ) to the Secretary of State** — Berlin , January 16, 1917 . [Received February 6.]  
   `frus1914-20v01/d656` · score -15.6242  
   > 763.72/3173½ The Ambassador in Germany ( Gerard ) to the Secretary of State Berlin , January 16, 1917 . [Received February 6.] Dear Mr. Secretary : The nearer I get to the situation the more I consider the President’s peace note an exceedin…
3. **The Secretary of State to President Wilson** — Washington , May 10, 1916 .  
   `frus1914-20v01/d536` · score -15.4606  
   > 763.72/2754a The Secretary of State to President Wilson Washington , May 10, 1916 . My Dear Mr. President : In the submarine controversy we will unavoidably be forced to meet a situation which will arise, if it has not already arisen, and t…
4. **Draft Instructions to the Ambassador in Germany ( Gerard )** — undated  
   `frus1914-20v01/d509` · score -13.5736  
   > 851.857 Su 8/54½a Draft Instructions to the Ambassador in Germany ( Gerard ) This paper bears the notation: “Original handed to Prest for his consideration 2:30 pm April 6/16. RL.” See also footnote 34, p. 546 . undated You are instructed t…
5. **The Secretary of State to the Chairman of the Senate Committee on Privileges and Elections ( Pomerene )** — Washington , November 26, 1917 .  
   `frus1914-20v02/d53` · score -12.2364  
   > 841.857 L 97/139½ The Secretary of State to the Chairman of the Senate Committee on Privileges and Elections ( Pomerene ) Washington , November 26, 1917 . My Dear Senator Pomerene : Referring to your letter of October 16th last and to our c…
6. **Mr. Adams to Mr. Seward .** — Legation of the United States, London, May 13, 1864.  
   `frus1864p1/d394` · score -2.6834  
   > Mr. Adams to Mr. Seward . No. 692.] Legation of the United States, London, May 13, 1864. Sir: I have the honor to transmit a copy of the London Times, containing a report of the speech of Mr. Gladstone, in the House of Commons, on Wednesday…

### Semantic (query prompt)

1. **The Secretary of State to President Wilson** — Washington , March 27, 1916 .  
   `frus1914-20v01/d507` · score 0.4674  
   > 851.857 Su 8/54a The Secretary of State to President Wilson Washington , March 27, 1916 . My Dear Mr. President : All the information which we are receiving in regard to the sinking of the Sussex in the English Channel, by which several Ame…
2. **Mr. Hay to Mr. Sherman .** — American Embassy , London , April 26, 1898 .  
   `frus1898/d737` · score 0.4546  
   > Mr. Hay to Mr. Sherman . American Embassy , London , April 26, 1898 . No. 367.] Sir : I have the honor to inclose herewith two copies of the London Gazette Extraordinary of this date, containing Her Britannic Majesty’s proclamation of neutr…
3. **The Secretary of State to President Wilson** — Washington , April 10, 1916 .  
   `frus1914-20v01/d510` · score 0.4522  
   > 851.857 Su 8/54½a The Secretary of State to President Wilson Washington , April 10, 1916 . My Dear Mr. President : I enclose a suggested insertion in the draft of instructions to the American Ambassador at Berlin, which I handed to you at t…
4. **The Ambassador in Germany ( Gerard ) to the Secretary of State** — Berlin , May 8, 1916, 6 p. m. [ Received May 9, 10 p. m. ]  
   `frus1916Supp/d346` · score 0.4471  
   > File No. 851.857Su8/77 The Ambassador in Germany ( Gerard ) to the Secretary of State [Telegram] Berlin , May 8, 1916, 6 p. m. [ Received May 9, 10 p. m. ] 3865. Following is translation of the text of note upon which my telegram No. 3858 N…
5. **The British Ambassador ( Lindsay ) to the Under Secretary of State ( Castle )** — Washington , June 24, 1931 .  
   `frus1931v01/d156` · score 0.4379  
   > 462.00R296/4325 The British Ambassador ( Lindsay ) to the Under Secretary of State ( Castle ) Washington , June 24, 1931 . Dear Mr. Under-Secretary : In accordance with my instructions, I communicate to you herewith a statement which will b…
6. **The Secretary of State to the Ambassador in Germany ( Gerard )** — Washington , April 18, 1916, 6 p. m.  
   `frus1916Supp/d308` · score 0.4330  
   > File No. 763.72/2597a The Secretary of State to the Ambassador in Germany ( Gerard ) [Telegram] Washington , April 18, 1916, 6 p. m. 2913. You are instructed to deliver to the Secretary of Foreign Affairs a communication reading as follows:…
7. **Memorandum by The Secretary of State of a Conversation With the German Ambassador ( Bernstorff ), April 18, 1916** — April 18, 1916  
   `frus1914-20v01/d523` · score 0.4327  
   > 763.72/2649½ Memorandum by The Secretary of State of a Conversation With the German Ambassador ( Bernstorff ), April 18, 1916 April 18, 1916 B My Government wants me to talk over with you once more the submarine question, and the instructio…
8. **The German Secretary of State for Foreign Affairs ( Jagow ) to the German Ambassador ( Bernstorff )** — Berlin , April 11, 1916 . [Received Tuckerton, N. J., April 13—10:27 p. m.]  
   `frus1914-20v01/d512` · score 0.4256  
   > 851.857 Su 8/56½: Telegram The German Secretary of State for Foreign Affairs ( Jagow ) to the German Ambassador ( Bernstorff ) This paper bears the notation: “This wireless was delivered to German Amb. am April 14/16 RL.” [Translation] Berl…
9. **The French Ambassador ( Jusserand ) to the Secretary of State** — Washington , April 20, 1916 .  
   `frus1914-20v01/d526` · score 0.4245  
   > 851.857 Su 8/86½ The French Ambassador ( Jusserand ) to the Secretary of State Washington , April 20, 1916 . My Dear Mr. Secretary : Here are some more particulars just received from my Government concerning the torpedoing of the Sussex and…
10. **The Ambassador in the United Kingdom ( Douglas ) to the Secretary of State** — London , June 11, 1947—10 a.m.  
   `frus1947v01/d388` · score 0.4225  
   > 841.20/6–1147: Telegram The Ambassador in the United Kingdom ( Douglas ) to the Secretary of State top secret u.s. urgent London , June 11, 1947—10 a.m. 3173. For Acheson from Douglas. In your top secret 2155 of May 17 Supra. you asked for …

*Route overlap: 1 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 2/10.*
*document variant:* frus1952-54v05p2/d135, frus1916Supp/d294, frus1914-20v01/d507, frus1931v01/d156, frus1914-20v01/d523, frus1916Supp/d346, frus1916Supp/d287, frus1914-20v01/d510, frus1916Supp/d308, frus1902/d510
*bare variant:* frus1866p1/d124, frus1952-54v05p2/d135, frus1865p1/d248, frus1931v01/d156, frus1898/d737, frus1945Berlinv02/d1417, frus1944v01/d357, frus1945Malta/d500, frus1964-68v33/d340, frus1902/d499

---

## Q23. "trust but verify"

### Lexical — `"trust but verify"`

1. **168. Memorandum From the Special Advisor to the President and Secretary of State on Arms Control Matters (Nitze) to Secretary of State Shultz** — Washington , October 29, 1986  
   `frus1981-88v11/d168` · score -5.7040  
   > 168. Memorandum From the Special Advisor to the President and Secretary of State on Arms Control Matters (Nitze) to Secretary of State Shultz Source: Department of State, Lot 90D397, Ambassador Nitze’s Personal Files, 1953, 1972–1989, 1986.…
2. **301. Memorandum of Conversation** — Reykjavik , October 11, 1986, 10:40 a.m.–12:30 p.m.  
   `frus1981-88v05/d301` · score -4.7110  
   > 301. Memorandum of Conversation Source: Reagan Library, Jack Matlock Files, Chronological File, 1980–1986, Matlock Chron October 1986 (4/6). Secret. Drafted by Zarechnak. The meeting took place at Hofdi House. Reagan wrote in his diary on O…
3. **3. Minutes of a National Security Planning Group Meeting** — Washington , October 27, 1986, 11 a.m.–noon  
   `frus1981-88v06/d3` · score -4.2486  
   > 3. Minutes of a National Security Planning Group Meeting Source: Reagan Library, Executive Secretariat, NSC National Security Planning Group ( NSPG ) Records, NSPG 0139 10/27/1986 [Arms Control] (1). Secret. Brackets are in the original. Th…
4. **335. Address by President Reagan to the Nation** — Washington , January 11, 1989  
   `frus1981-88v01/d335` · score -4.1040  
   > 335. Address by President Reagan to the Nation Source: Public Papers: Reagan, 1988–1989 , Book II, pp. 1718–1723. All brackets are in the original. The President spoke at 9:02 p.m. from the Oval Office. His address was broadcast live on nat…
5. **306. Remarks by President Reagan** — Los Angeles , August 26, 1987  
   `frus1981-88v01/d306` · score -3.7238  
   > 306. Remarks by President Reagan Source: Public Papers: Reagan, 1987 , Book II, pp. 977–982. All brackets are in the original. The President spoke at 1:02 p.m. at a luncheon in the Los Angeles Ballroom at the Century Plaza Hotel. His remark…
6. **333. Remarks by President Reagan** — Charlottesville, Virginia , December 16, 1988  
   `frus1981-88v01/d333` · score -3.2487  
   > 333. Remarks by President Reagan Source: Public Papers: Reagan, 1988–1989 , Book II, pp. 1631–1638. All brackets are in the original. The President spoke at 10:35 a.m. at Cabell Hall at the University of Virginia. The text of the question a…
7. **360. Memorandum of Conversation** — Washington , July 27, 1988, 11 a.m.–1:40 p.m.  
   `frus1981-88v10/d360` · score -2.8714  
   > 360. Memorandum of Conversation Source: Reagan Library, Rudolf Perina Files, Presidential Meeting with PM Groz Hungary 7/27/1988 (6). Secret. The meeting took place in the Oval Office, the Cabinet Room, and the Residence. Washington , July …
8. **68. Memorandum of Conversation** — Washington , September 15, 1987, 3:30–5:30 p.m.  
   `frus1981-88v06/d68` · score -2.7679  
   > 68. Memorandum of Conversation Source: Department of State, Executive Secretariat, S/S Records, Memoranda of Conversations Pertaining to United States and USSR Relations, 1981–1990, Lot 93D188, Shultz — Shevardnadze —Wash—9/87. Secret; Sens…
9. **308. Memorandum of Conversation** — Moscow , May 30, 1988, 9:15 a.m.–12:05 p.m.  
   `frus1981-88v11/d308` · score -2.3629  
   > 308. Memorandum of Conversation Source: Department of State, Executive Secretariat, S/S-IRM Records, Memorandum of Conversations Pertaining to United States and USSR Relations, 1981–1990, Lot 93D188, Moscow Summit 5/29–6/1, 1988. Secret. Th…

### Semantic (query prompt)

1. **32. Notes of a National Security Council Meeting** — Washington , August 9, 1982, 3:10 p.m.  
   `frus1981-88v11/d32` · score 0.5223  
   > 32. Notes of a National Security Council Meeting Source: National Security Council, National Security Council Institutional Files, Box SR 102, NSC 00059 RWR 8/09/82. Secret. Drafted by Wheeler. The original text is handwritten. The editor t…
2. **121. Message from President Kennedy to Prime Minister Macmillan , April 6** — April 6, 1962  
   `frus1961-63v07-09mSupp/d121` · score 0.4977  
   > 121. Message from President Kennedy to Prime Minister Macmillan , April 6 Thoughts on proposed statement and U.K. letter to Khrushchev . Attached is a draft U.S.–U.K. statement on nuclear testing. Top Secret. 6 pp. Kennedy Library, National…
3. **44. Telegram From the Department of State to the Embassy in the Soviet Union** — Washington , April 7, 1962, 5:16 p.m.  
   `frus1961-63v06/d44` · score 0.4972  
   > 44. Telegram From the Department of State to the Embassy in the Soviet Union Source: Department of State, Presidential Correspondence: Lot 66 D 204. Secret; Priority; Verbatim Text; Eyes Only. Drafted by Davis ; cleared by Kohler , Beam ( A…
4. **107. Tosec 95 to Geneva, March 21** — March 21, 1962, 1:53 p.m.  
   `frus1961-63v07-09mSupp/d107` · score 0.4866  
   > 107. Tosec 95 to Geneva, March 21 Text of message from Macmillan to President Kennedy . Pushing Khrushchev on verification issue. Top Secret. 4 pp. Department of State, Conference Files: Lot 65 D 533, CF 2059. March 21, 1962, 1:53 p.m. Foll…
5. **Minutes of the Twenty-ninth Meeting of the United States Delegation, New York, Hotel Pennsylvania, November 26, 1946, 9 a.m.** — New York , November 26, 1946, 9 a.m.  
   `frus1946v01/d546` · score 0.4801  
   > IO Files Minutes of the Twenty-ninth Meeting of the United States Delegation, New York, Hotel Pennsylvania, November 26, 1946, 9 a.m. New York , November 26, 1946, 9 a.m. secret [Here follows a list of persons (28) present.] Resolution on A…
6. **12. Memorandum From the Joint Chiefs of Staff to Secretary of Defense McNamara** — Washington , February 22, 1964 .  
   `frus1964-68v11/d12` · score 0.4780  
   > 12. Memorandum From the Joint Chiefs of Staff to Secretary of Defense McNamara Source: Washington National Records Center, RG 330, OASD / ISA Files: FRC 68 A 4023, 388.3 (January-February 1964). Top Secret; Restricted Data. Attached is a Fe…
7. **488. Memorandum from Llewellyn E. Thompson to Rusk , November 3** — November 3, 1962, noon  
   `frus1961-63v10-12mSupp/d488` · score 0.4761  
   > 488. Memorandum from Llewellyn E. Thompson to Rusk , November 3 Notes of a conversation between Dobrynin and Thompson on November 3 re verification arrangements. Secret. 3 pp. Kennedy Library, NSF , Countries Series, USSR , Dobrynin Talks, …
8. **Agreement Between the United States and the United Kingdom for the Establishment of the Combined Development Trust** — June 13, 1944  
   `frus1944v02/d885` · score 0.4639  
   > Lot File 55D540, Box 2 Agreement Between the United States and the United Kingdom for the Establishment of the Combined Development Trust June 13, 1944 This Agreement and Declaration of Trust is made the 13th day of June 1944 by Franklin De…
9. **113. Secto 107 from Geneva, March 25** — Geneva , March 25, 1962, 8 p.m.  
   `frus1961-63v07-09mSupp/d113` · score 0.4637  
   > 113. Secto 107 from Geneva, March 25 Rusk concerns re notice to mariners, verification issue semantics, and joint statement. Secret. 2 pp. Department of State, Central Files, 700.5611/3–2562. Geneva , March 25, 1962, 8 p.m. Eyes only for Pr…
10. **78. Letter From Director of Central Intelligence Turner to Secretary of State Vance** — Washington , February 23, 1978  
   `frus1977-80v28/d78` · score 0.4617  
   > 78. Letter From Director of Central Intelligence Turner to Secretary of State Vance Source: National Archives, RG 59, Records of the Secretary of State, 1977–1980, Lot 84D241, Executive Order on Intelligence, 1978. Secret. Washington , Febr…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 6/10.*
*document variant:* frus1961-63v07-09mSupp/d121, frus1961-63v06/d44, frus1911/d263, frus1977-80v28/d78, frus1944v02/d885, frus1961-63v10-12mSupp/d488, frus1964-68v11/d12, frus1961-63v11/d141, frus1949v08/d1128, frus1950v03/d697
*bare variant:* frus1981-88v11/d32, frus1911/d263, frus1961-63v07-09mSupp/d121, frus1961-63v06/d44, frus1961-63v07-09mSupp/d113, frus1961-63v07-09mSupp/d107, frus1944v02/d885, frus1977-80v26/d231, frus1969-76ve02/d138, frus1949v08/d1128

---

## Q24. persona non grata

### Lexical — `"persona" AND "non" AND "grata"`

1. **United States concern over the assassination of a Legation employee considered “persona non grata” by the Ethiopian government**  
   `frus1947v05/ch8` · score -30.0576  
   > United States concern over the assassination of a Legation employee considered “persona non grata” by the Ethiopian government [Mr. Johannes Semerjibashian, who was serving as dragoman-interpreter of the American Legation at Addis Ababa eve…
2. **The Acting Secretary of State to the Legation in Hungary** — Washington , November 24, 1947—6 p. m.  
   `frus1947v04/d273` · score -27.8274  
   > 123 Chapin, Selden: Telegram The Acting Secretary of State to the Legation in Hungary top secret urgent niact Washington , November 24, 1947—6 p. m. 1191. While we agree in principle as indicated Deptel 1188 Nov 22 Not printed. that you sho…
3. **Memorandum by the Chief of the Division of Security ( Nicholson ) to the Director of the Office of Middle American Affairs ( Mann )** — [ Washington ,] April 5, 1950 .  
   `frus1950v02/d450` · score -27.0988  
   > 123 Patterson, Richard C. Memorandum by the Chief of the Division of Security ( Nicholson ) This memorandum was also marked for the attention of W. Tapley Bennett, Jr., Officer in Charge of Central America and Panama Affairs. to the Directo…
4. ****  
   `frus1950v04/d537` · score -26.8306  
   > Editorial Note In a note of March 10 to the Legation in Budapest, the Hungarian Foreign Ministry declared Military Attaché Col. James B. Kraft, Assistant Military Attaché Lt. Col. John T. Hoyne, and Assistant Air Attaché Maj. Donald E. Grif…
5. **355. Memorandum From the Assistant Secretary of State for Near Eastern, South Asian, and African Affairs ( Rountree ) to the Acting Secretary of State** — Washington , August 13, 1957 .  
   `frus1955-57v13/d355` · score -26.3390  
   > 355. Memorandum From the Assistant Secretary of State for Near Eastern, South Asian, and African Affairs ( Rountree ) to the Acting Secretary of State Source: Department of State, Central Files, 783.00/8–1357. Confidential. Drafted by Burde…
6. **The Italian Ambassador ( Colonna ) to the Secretary of State** — Washington , April 8, 1941—XIX .  
   `frus1941v02/d797` · score -26.2249  
   > 701.6511/1020 The Italian Ambassador ( Colonna ) to the Secretary of State No. 1860 Washington , April 8, 1941—XIX . Mr. Secretary of State : I have the honor to inform you that the request of the United States Government, transmitted with …
7. **The Chargé in Bulgaria ( O’Donoghue ) to the Secretary of State** — Sofia , March 17, 1949—3 p. m.  
   `frus1949v05/d204` · score -25.5797  
   > 701.4174/3–1749: Telegram The Chargé in Bulgaria ( O’Donoghue ) to the Secretary of State secret Sofia , March 17, 1949—3 p. m. 225. Legtel 216, March 15. On March 9 the Bulgarian Government declared Denis A. Greenhill, First Secretary of t…
8. **The Secretary of State to the Embassy in Poland** — Washington , April 7, 1950—7 p. m.  
   `frus1950v04/d560` · score -25.0786  
   > 120.32148/3–2150: Telegram The Secretary of State to the Embassy in Poland confidential Washington , April 7, 1950—7 p. m. 169. Re Embtel 399 Mar 15 Supra . and Desp 463 Mar 21. Not printed, but see footnote 3, supra . If no objection, deli…
9. **Memorandum of Conversation, by the Assistant Secretary of State ( Long )** — [ Washington ,] September 2, 1944 .  
   `frus1944v05/d255` · score -24.9404  
   > 845.00/9–244 Memorandum of Conversation, by the Assistant Secretary of State ( Long ) [ Washington ,] September 2, 1944 . The British Ambassador came in to see me by appointment arranged by the Secretary’s office. Prior to the arrival of Lo…
10. **109. Telegram From the Embassy in the Soviet Union to the Department of State** — Moscow , May 12, 1965, 1305Z .  
   `frus1964-68v14/d109` · score -24.9054  
   > 109. Telegram From the Embassy in the Soviet Union to the Department of State Source: National Archives and Records Administration, RG 59, Central Files 1964–66, POL 17 US – USSR . Confidential; Limdis . Moscow , May 12, 1965, 1305Z . 3386.…

### Semantic (query prompt)

1. **The Minister Resident in Ethiopia ( Engert ) to the Secretary of State** — Addis Ababa , June 12, 1936—3 p.m. [Received 7:44 p.m.]  
   `frus1936v03/d349` · score 0.4546  
   > 124.84/101: Telegram The Minister Resident in Ethiopia ( Engert ) to the Secretary of State Addis Ababa , June 12, 1936—3 p.m. [Received 7:44 p.m.] 418. Last paragraph Department’s 270, June 9. None of the chiefs of mission here used the ti…
2. **99. Briefing Paper Prepared in the Department of State** — Washington , undated .  
   `frus1955-57v27/d99` · score 0.4532  
   > 99. Briefing Paper Prepared in the Department of State Source: Eisenhower Library, Whitman File, Dulles – Herter Series. Secret. No drafting information appears on the source text. The source text is undated but it was transmitted to the Pr…
3. **Mr. Draper to Mr. Day .** — Embassy of the United States , Rome, Italy , May 28, 1898 .  
   `frus1898/d743` · score 0.4509  
   > Mr. Draper to Mr. Day . Embassy of the United States , Rome, Italy , May 28, 1898 . No. 216.] Sir : I beg leave to inclose, as directed in your No. 178, of the 13th instant, two copies of the Gazetta Ufficiale containing the proclamation of…
4. **The Italian Ambassador ( Martino ) to the Secretary of State**  
   `frus1927v03/d136` · score 0.4478  
   > 811.918/197 The Italian Ambassador ( Martino ) to the Secretary of State The Italian Ambassador presents his compliments to His Excellency the Secretary of State and has the honor to bring the following to his attention. The weekly paper Il…
5. **The Ambassador in Italy ( Fletcher ) to the Secretary of State** — Rome , July 22, 1925—5 p.m. [Received July 22—2:42 p.m.]  
   `frus1925v02/d319` · score 0.4477  
   > 811.91265/9: Telegram The Ambassador in Italy ( Fletcher ) to the Secretary of State [Paraphrase] Rome , July 22, 1925—5 p.m. [Received July 22—2:42 p.m.] 119. A note has been received from the Under Secretary for Foreign Affairs, which sta…
6. **Baron Fava to Mr. Hay .** — Italian Embassy , Washington , October 31, 1899 .  
   `frus1899/d403` · score 0.4463  
   > Baron Fava to Mr. Hay . [Translation.] Italian Embassy , Washington , October 31, 1899 . Mr. Secretary of State : In your note of the 14th of August last I read the replies made by the honorable Secretary of the Treasury to the note of June…
7. **The Chargé in Italy ( Jay ) to the Secretary of State** — Rome , September 17, 1918 . [ Received October 14. ]  
   `frus1918Supp01v01/d841` · score 0.4437  
   > File No. 763.72/11730 The Chargé in Italy ( Jay ) to the Secretary of State No. 1005 Rome , September 17, 1918 . [ Received October 14. ] Sir : In accordance with instructions contained in the Department’s cablegram No. 1670 of September 7,…
8. **The Ambassador in Italy ( page ) to the Secretary of State** — Rome , December 25, 1916, 6 p. m. [ Received December 26, 8.30 a. m. ]  
   `frus1916Supp/d162` · score 0.4383  
   > File No. 763.72119/255 The Ambassador in Italy ( page ) to the Secretary of State [Telegram] Rome , December 25, 1916, 6 p. m. [ Received December 26, 8.30 a. m. ] Press here strongly hostile to President’s suggestion. Clerical press partly…
9. **The Secretary of State to Consular Officers in Latin American Countries** — Washington , December 6, 1917 .  
   `frus1917Supp02v02/d130` · score 0.4381  
   > File No. 763.72112/5959a The Secretary of State to Consular Officers in Latin American Countries No. 562 Washington , December 6, 1917 . General Instructions Consular Gentlemen : Referring to General Instruction No. 554 of November 7, 1917,…
10. **The Ambassador in Italy ( Fletcher ) to the Secretary of State** — Rome , July 28, 1925 . [Received August 10.]  
   `frus1925v02/d322` · score 0.4374  
   > 811.91265/13 The Ambassador in Italy ( Fletcher ) to the Secretary of State Rome , July 28, 1925 . [Received August 10.] No. 542 Sir : With reference to my telegram No. 119 of July 22, 5 p.m. and No. 121 of July 27, 4 p.m., and to the Depar…

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 6/10, bare: 0/10.*
*document variant:* frus1955-57v27/d99, frus1914-20v01/d692, frus1927v03/d136, frus1916Supp/d173, frus1891/d605, frus1899/d403, frus1918Supp01v01/d841, frus1925v02/d322, frus1936v03/d349, frus1955-57v27/d128
*bare variant:* frus1952-54v15p2/d819, frus1872p2v4/d43, frus1981-88v04/d108, frus1919Parisv03/d3, frus1916/d449, frus1933v03/d384, frus1906p2/d308, frus1909/d435, frus1918/d676, frus1914-20v01/d214

---

## Q25. blood telegram
*known-item by nickname (Archer Blood's April 1971 Dacca dissent cable — the documents never call it that)*

### Lexical — `"blood" AND "telegram"`

1. **3. Telegram From the Department of State to All Diplomatic and Consular Posts** — Washington , September 22, 1983, 1904Z  
   `frus1981-88v41/d3` · score -9.5570  
   > 3. Telegram From the Department of State to All Diplomatic and Consular Posts Source: Department of State, Central Foreign Policy File, D830551–0463. Unclassified. Drafted by Walsh ; cleared in OES/E , OES/ENR , M/MED , AID/S&T/H , HHS / PA…
2. **7. Telegram From the Department of State to the Medical Collective** — Washington , June 7, 1985, 0045Z  
   `frus1981-88v41/d7` · score -9.5522  
   > 7. Telegram From the Department of State to the Medical Collective Source: Department of State, Subject Files, Other Agency and Channel Messages and Substantive Material—World Health Organization ( WHO ), 1985, Lot 89D136, 83 HLTH WHO Progr…
3. **The Secretary of State to the Ambassador in China ( Gauss )** — Washington , December 18, 1943 .  
   `frus1943China/d700` · score -9.0791  
   > 151.10/2003a: Telegram The Secretary of State to the Ambassador in China ( Gauss ) Washington , December 18, 1943 . 1819. On December 17, 1943 the President approved an Act of Congress, Public 199, 57 Stat. 600. of which Section 1 repeals t…
4. **The Ambassador in Germany ( Dodd ) to the Secretary of State** — Berlin , September 19, 1935 . [Received September 27.]  
   `frus1935v02/d305` · score -8.8451  
   > 862.4016/1554 The Ambassador in Germany ( Dodd ) to the Secretary of State [Extract] No. 2322 Berlin , September 19, 1935 . [Received September 27.] Sir : With reference to the Embassy’s telegram No. 172 of September 16, 11 a.m., Not printe…
5. **2. Telegram From the Department of State to the Embassy in Haiti** — Washington , September 21, 1982, 1345Z  
   `frus1981-88v41/d2` · score -8.8305  
   > 2. Telegram From the Department of State to the Embassy in Haiti Source: Department of State, Central Foreign Policy File, D820498–0189. Unclassified. Sent through MED Channel. Sent for information to Santo Domingo. Drafted by Washington an…
6. **No. 807 The Ambassador in Japan ( Allison ) to the Department of State** — Tokyo , September 24, 1954—8 p.m.  
   `frus1952-54v14p2/d807` · score -8.7621  
   > 894.245/9–2454: Telegram No. 807 The Ambassador in Japan ( Allison ) to the Department of State confidential Tokyo , September 24, 1954—8 p.m. 712. Pass AEC . Reference Embassy’s 704. Dated Sept. 23; in it the Embassy reported that Dr. Masa…
7. **199. Memorandum From Secretary of State Muskie to President Carter** — Washington , September 13, 1980  
   `frus1977-80v19/d199` · score -8.2301  
   > 199. Memorandum From Secretary of State Muskie to President Carter Source: Carter Library, National Security Affairs, Brzezinski Material, Subject File, Box 23, Evening Reports (State): 9/80. Secret. Carter initialed the top of the memorand…
8. **The Minister in Lithuania ( Norem ) to the Secretary of State** — Kaunas , July 19, 1940—10 a.m. [Received 7:38 p.m.]  
   `frus1940v01/d402` · score -8.1712  
   > 860M.00/452: Telegram The Minister in Lithuania ( Norem ) to the Secretary of State Kaunas , July 19, 1940—10 a.m. [Received 7:38 p.m.] 158. The election results have been announced as one of 99% variety and indicates a total lack of true d…
9. **19. Telegram From the Department of State to All African Diplomatic Posts** — Washington , August 5, 1986, 0233Z  
   `frus1981-88v41/d19` · score -8.1314  
   > 19. Telegram From the Department of State to All African Diplomatic Posts Source: Department of State, Central Foreign Policy File, D860596–0043. Confidential. Sent for information to Moscow. Drafted by Rapoport ; cleared in AF/P , OES/ENR …
10. **74. Telegram 1569 From the Consulate General in Dacca to the Department of State** — Dacca , August 17, 1970, 0624Z  
   `frus1969-76ve07/d74` · score -8.0912  
   > 74. Telegram 1569 From the Consulate General in Dacca to the Department of State Source: National Archives, RG 59, Central Files 1970–73, SOC 10 PAK. Confidential; Priority. Repeated to Rawalpindi. The telegram, signed by Consul General Blo…

### Semantic (query prompt)

1. **The Chargé in Costa Rica ( Trueblood ) to the Secretary of State** — San José , September 14, 1943—5 p.m. [Received 11:44 p.m.]  
   `frus1943v06/d115` · score 0.5524  
   > 811.515/2145: Telegram The Chargé in Costa Rica ( Trueblood ) to the Secretary of State San José , September 14, 1943—5 p.m. [Received 11:44 p.m.] 646. Reference Department’s telegram 535, August 21, and my despatch No. 545 of September 4. …
2. **The Chargé in Bolivia ( Trueblood ) to the Secretary of State** — La Paz , April 15, 1931—11 a.m. [Received 11:50 a.m.]  
   `frus1931v01/d739` · score 0.5516  
   > 824.733/4: Telegram The Chargé in Bolivia ( Trueblood ) to the Secretary of State La Paz , April 15, 1931—11 a.m. [Received 11:50 a.m.] 33. Manager of the All America Cables notified the Legation yesterday that beginning today he would be r…
3. **[Untitled]** — [Telegram, dated Ottawa , May 31, 1868 .]  
   `frus1868p1/d194` · score 0.5501  
   > [Untitled] [Telegram, dated Ottawa , May 31, 1868 .] To his Excellency Edward Thornton , British Legation: I have this telegram from a trustworthy source: “Head Center at Ogdensburg presented draft at Jodson’s bank for several thousand doll…
4. **The Commission to Negotiate Peace to the Acting Secretary of State** — Paris , May 6 [ 7? ], 1919 . [Received May 7, 4:16 p.m.]  
   `frus1919Russia/d884` · score 0.5350  
   > 861.00/4443: Telegram The Commission to Negotiate Peace to the Acting Secretary of State Paris , May 6 [ 7? ], 1919 . [Received May 7, 4:16 p.m.] 2027. [From Ravndal at Constantinople:] “May 6th, 5 p.m. From Jenkins , repeat Washington. ‘Ai…
5. **The Chargé in Paraguay ( Trueblood ) to the Secretary of State** — Asunción , July 17, 1947—4 p.m.  
   `frus1947v08/d839` · score 0.5333  
   > 834.00/7–1747: Telegram The Chargé in Paraguay ( Trueblood ) to the Secretary of State confidential Asunción , July 17, 1947—4 p.m. 391. Embtel s 376, July 11 and 387, July 16. Neither printed. The following is a literal translation of the …
6. **The Minister in China ( MacMurray ) to the Secretary of State** — Peiping , October 19, 1929—7 p.m. [Received 9:03 p.m.]  
   `frus1929v02/d239` · score 0.5248  
   > 861.77 Chinese Eastern/403: Telegram The Minister in China ( MacMurray ) to the Secretary of State Peiping , October 19, 1929—7 p.m. [Received 9:03 p.m.] 910. The Senior (Netherland) Minister received the following telegram dated on October…
7. **The Secretary of State to the Chargé in the Kingdom of the Serbs, Croats and Slovenes ( Boal )** — Washington , May 1, 1922—4 p.m.  
   `frus1922v02/d886` · score 0.5170  
   > 860h.51/153: Telegram The Secretary of State to the Chargé in the Kingdom of the Serbs, Croats and Slovenes ( Boal ) [Paraphrase] Washington , May 1, 1922—4 p.m. 11. Your telegram no. 10, April 28, 5 p.m. Not printed. Telegraph Department w…
8. **The Acting Secretary of State to Ambassador Bacon .** — Department of State , Washington , January 27, 1910 .  
   `frus1910/d581` · score 0.5150  
   > File No. 23286/1. The Acting Secretary of State to Ambassador Bacon . [Telegram—Paraphrase.] Department of State , Washington , January 27, 1910 . Mr. Wilson informs Mr. Bacon of the sending of the telegram which the President has addressed…
9. **The Chargé in Great Britain ( Laughlin ) to the Secretary of State** — London , October 24, 1918 . [ Received 2.45 p.m. ]  
   `frus1918Russiav03/d217` · score 0.5142  
   > File No. 811.142/6073 The Chargé in Great Britain ( Laughlin ) to the Secretary of State [Telegram] London , October 24, 1918 . [ Received 2.45 p.m. ] 3053. [From Endicott to] American Red Cross: 1872. Have seen general commanding Archangel…
10. **The United States Deputy Political Adviser at Allied Force Headquarters ( Byington ) to the Secretary of State** — Caserta , May 8, 1946—5 p.m. [Received May 8—1:10 p.m.]  
   `frus1946v06/d625` · score 0.5122  
   > 865.00/5–846: Telegram The United States Deputy Political Adviser at Allied Force Headquarters ( Byington ) to the Secretary of State secret Caserta , May 8, 1946—5 p.m. [Received May 8—1:10 p.m.] 501. Re my 496, May 3, 3 p.m. Not printed; …

*Route overlap: 0 of 10 shared. Prompt variants vs primary — document: 4/10, bare: 4/10.*
*document variant:* frus1868p1/d194, frus1931v01/d739, frus1931v01/d593, frus1947v08/d844, frus1961-63v04/d283, frus1918Russiav03/d217, frus1952-54Guat/d270, frus1947v08/d839, frus1947v08/d832, frus1925v02/d424
*bare variant:* frus1943v06/d115, frus1919Russia/d884, frus1931v01/d739, frus1910/d581, frus1917/d1469, frus1917/d935, frus1907p2/d352, frus1940v04/d77, frus1921v02/d673, frus1941v01/d520
