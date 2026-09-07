# Scoping memo: US participation in international sanitary conventions and quarantine practice, as documented in FRUS

**To:** the historian
**Re:** what the *Foreign Relations of the United States* corpus (552 indexed volumes, 316,839 documents, 1861–1988) will and will not give you on this question
**Basis:** one scoping pass over the local FTS index, the TEI corpus, and the bundled reference JSON. Every command is in `queries.log` beside this file.

---

## 1. Headline

The corpus is **unexpectedly strong** on this question for the period **c. 1865–1948**, and **effectively silent after 1950**. That shape is not an artifact of my searching; it is the shape of FRUS itself, and it is the single most important thing to know before you budget time.

The strength comes from a specific structural fact: for roughly 1861–1949 FRUS was a comprehensive annual publication of diplomatic correspondence organised by country and by *subject heading*, and the editors repeatedly gave international sanitary matters their own headings. After the series reorganised around crises, policy problems and high-level decision-making, quarantine and sanitary conventions stopped being the kind of thing FRUS prints. The 1951 International Sanitary Regulations — the instrument that replaced the whole convention regime — **are not documented here at all**.

The second thing to know is a trap. In this corpus the word *quarantine* is dominated after 1960 by the **Cuban missile crisis naval "quarantine."** A bare full-text search for `quarantine` returns 863 documents, of which 194 sit in two 1961–63 volumes. The app's own subject taxonomy actively encodes this: subject #132 is literally named **"Quarantine (Blockade)"** under *Politico-Military Issues*, with 4,674 documents, and its top volumes are Berlin 1948, the WWI blockade supplements and the Civil War. If you click "Quarantine" in the subject facet you will get blockade, not public health.

---

## 2. What I actually measured

### 2.1 Raw term counts (FTS5, `porter unicode61` stemming, whole corpus)

| query | documents |
|---|---|
| `quarantine` (stems to quarantined/quarantines/quarantinable) | 863 |
| `sanitary` | 1,331 |
| `"public health"` | 977 |
| `epidemic` | 498 |
| `cholera` | 250 |
| `"yellow fever"` | 169 |
| `"World Health Organization"` | 156 |
| `"bill(s) of health"` | 139 |
| `disinfection` | 103 |
| `"health officer"` | 98 |
| `"sanitary convention"` | 84 |
| `"international sanitary"` | 65 |
| `"Marine Hospital Service"` | 51 |
| `fumigation` | 36 |
| `lazaretto` | 30 |
| `"sanitary bureau"` / `"sanitary conference"` | 23 / 23 |
| `"Pan American Sanitary"` | 17 |
| `"Superior Board of Health"` | 15 |
| `"sanitary council"` | 11 |
| `"Office International"` | 10 |
| `"hygiene publique"` | 3 |

Caution on stemming: `quarantine` and `quarantinable` return the *same* 863 documents, so you cannot use the index to isolate a morphological variant.

### 2.2 The working corpus

I defined a core query:

```
quarantine OR "sanitary convention" OR "sanitary conference" OR "sanitary code"
  OR "sanitary bureau" OR "sanitary council" OR "international sanitary"
  OR "bill of health" OR "bills of health" OR lazaretto OR "pratique"
```

- Raw: **1,089 documents**
- After `NOT (missile OR Khrushchev OR OAS OR blockade)`: **804 documents**, across **209 volumes**, with **57 volumes carrying ≥5 hits**
- Documents where a core stem occurs ≥3 times (a crude "substantively about it" filter): **265**
- Of the 804: **259** also carry a human-disease marker (cholera / plague / yellow fever / smallpox / typhus / passengers / emigrants / pilgrims); **191** also carry an animal-or-plant marker (cattle / livestock / foot-and-mouth / swine / meat / plant / nursery / citrus)
- Only **11** are front matter and **7** are editorial notes; the rest are printed documents

**Precision check.** I pulled a deterministic pseudo-random sample of 30 from the 804 and read the KWIC snippets. Roughly 25 are squarely on topic (quarantine detentions, bills of health, sanitary conferences, sanitary councils); 2 are the naval-quarantine sense that survived my exclusion (Cuba 1962; a 1970 proposal to "quarantine the port of Sihanoukville"); 1 is a tariff schedule listing "quarantine dues" among port charges; 2 are animal/plant quarantine. So call precision ~83% for the strict human-sanitary reading and ~90% if you count animal quarantine as in scope. Recall I did not measure and cannot, but see §5.

### 2.3 Chronology

Decade histogram of the 804, by document date (`document_dates.date_iso`):

```
1840s   2 |
1850s   2 |
1860s  85 |█████████████████
1870s  58 |███████████
1880s  89 |██████████████████
1890s  77 |███████████████
1900s  98 |████████████████████
1910s  61 |████████████
1920s  90 |██████████████████
1930s  93 |███████████████████
1940s  55 |███████████
1950s  15 |███
1960s  44 |█████████   ← residual Cuba
1970s  19 |████
1980s   9 |██
```

The `sanitary` histogram is even cleaner and shows the same cliff: 1900s 157, 1910s 164, 1920s 201, 1930s 196, 1940s 172 — then **1950s 45, 1960s 15, 1970s 12, 1980s 2**.

**The cliff is real and it is at 1948–50.** Post-1955 hits are scattered across ~20 volumes at 1–10 documents each, and are mostly the Cuba quarantine plus figurative usage.

---

## 3. What is actually in here — the eight threads worth your time

I found these by reading the editors' own **compilation headings** out of `volume_structures` (the TEI table-of-contents JSON), which is by far the highest-yield surface for this question. Eighteen volumes carry a heading containing "Sanitary"; eight carry one containing "Quarantine."

### (a) The nineteenth-century conference series
The corpus follows the International Sanitary Conferences from the outside and then from the inside.

- **1866 Constantinople** — `frus1866p2/d205`, France proposing "the reunion of an international sanitary conference."
- **1874 Vienna** — `frus1874/d20`, `d21`, `d26`. Delaplaine's despatch from Vienna is a substantial narrative report on the conference's purpose and on "the question as to the efficacy or necessity as well as to the duration of quarantines."
- **1881 Washington — the US hosts.** This is the find I would lead with. `frus1880/d4` is a **circular instruction to all US diplomatic officers, 30 July 1880**, announcing that under a joint resolution of Congress approved 14 May 1880 the President would convene an international sanitary conference at Washington, and instructing every legation to press the host government to attend. It transmits a memorandum "which concludes with a statement of the specific propositions which the President would desire to submit." The 1880 and 1881 presidents' messages both report on it. Because it was a *circular*, the replies should be scattered through the 1880 and 1881 country sections — a discrete, tractable research project in itself.
- **1903 Paris** — referenced repeatedly (`frus1907p1/d338`; `frus1932v02/d469` notes Egypt "made itself heard" there).

### (b) The Pan American system
The densest single institutional thread, and the one where US leadership is most visible.

- 1905 convention among Argentina, Brazil, Paraguay, Uruguay (`frus1905` heading)
- Sanitary convention of 1905 (`frus1906p2`)
- **Third International Sanitary Convention, Mexico City, 2–7 Dec 1907** — its own chapter, `frus1907p2/ch116`
- **Fourth Pan-American Sanitary Conference / Fourth International Sanitary Convention** — `frus1909`, incl. `d613`, `d614`
- `frus1910/d24`, `d26` on adopting the Mexican and Costa Rican conference conclusions
- **Pan American Sanitary Code, Havana, 14 Nov 1924** — treaty text at `frus1924v01/d219`, with Art. 55 on the Pan American Sanitary Bureau visible at `d219`
- **Additional Protocol, 19 Oct 1927** (`frus1927v01`), and the Eighth Pan American Sanitary Conference at Lima (`frus1928v01/d363`)
- Ninth Conference, Buenos Aires, Nov 1934 (`frus1937v05/d210`)

### (c) The Paris convention regime and the Office International d'Hygiène Publique
- **1908**: heading "Arrangement between the United States and other powers for the establishment of the International Office of Public Health" — the US as a founding party to the 1907 Rome Agreement. `frus1908/d468` is the definitional document: it explains that the phrase "Boards of Health" applies to **the Sanitary Councils of Alexandria, Constantinople, Tangier, Teheran**.
- **1923**: heading "Approval by the United States of a project for cooperation between the International Office of Public Health and the Health Commission of the League of Nations." `frus1923v01/d45–d50`, filed **512.4-A**, opens with Jusserand transmitting the First Assembly's December 1920 resolution proposing to place the Paris office under the League. This is the US position on the OIHP/LNHO turf fight, in six documents — and it is a US that was not in the League.
- **1926**: the revising convention of 21 June 1926 gets four documents in `frus1926v01` (`d116`–`d119`: the convention, then three *procès-verbaux* of deposits of ratification, including the US's own), plus the negotiation at `d113`–`d115` under **512.4-B**.

### (d) Egypt and the Alexandria board — a complete arc in ~30 documents
The best-bounded story in the whole set, and it runs from the 1870s to 1938.

- `frus1879/d328` — the Egyptian quarantine board's power to reduce detention
- `frus1907p1/d338` — the Maritime and Quarantine Board of Egypt authorised to organise transit
- `frus1919Parisv13/ch13subch6` — a defeated power renounces "all participation in the Sanitary, Maritime, and Quarantine Board of Egypt"
- `frus1920v02/d184`, `frus1921v01/d843–d844` — proposals to transfer the board's powers
- `frus1926v01/d114`, `d116` — American representation; Article 145 of the revised convention
- **`frus1928v02/d756–d766`** — an eleven-document run on the US seeking a seat on the International Quarantine Board at Alexandria, under heading "Appointment of an American representative on the International Quarantine Board at Alexandria"
- **`frus1932v02/d468–d470`** — continued, explicitly cross-referenced to 1928
- **`frus1938v01/d927–d930`** — the abolition. Egypt asks US support to abolish the board; the US agrees; and `d930` (Wilson to Hull, Paris, 3 Nov 1938, file **512.4B3/26**) reports that **Surgeon General Hugh S. Cumming (ret.), USPHS**, represented the United States at the Paris Sanitary Conference of 28 Oct 1938, assisted by Second Secretary Edwin A. Plitt, among 57 delegates of whom 24 were plenipotentiaries, to transfer the board's duties to Egypt and revise Titles II–IV of the 1926 convention.

### (e) Quarantine as a sovereignty question in the extraterritorial world
This is the analytically richest thread and the one a historian of empire will want.

- **Japan, 1879 — the *Hesperia* affair.** Named documents: `frus1879/d319`, `d325`, `d328`, `d329`, `d330`, `d331`, `d332` — seven, and they are the *only* seven in the corpus (`Hesperia` returns eight hits, the eighth being a Munich hotel in `frus1969-76v39/d332`). The German steamer taken out of quarantine at Yokohama during cholera; Terashima's order, and the enclosed notes from the Japanese side. The surrounding quarantine documents in the same volume (`d301`, `d303`, `d319`–`d332`) belong to the same compilation. This is the classic case of extraterritoriality defeating a host state's quarantine.
- **Japan again, 1900–01** — heading "Alleged discrimination in United States against Japanese, in the matter of quarantine against bubonic plague," `frus1900/d865`–`d880`+, continued in `frus1901`. San Francisco and Colorado quarantine orders against Japanese subjects, protested through the legation. Quarantine as racial exclusion, argued in diplomatic form.
- **China, 1930** — heading "Jurisdiction for quarantine purposes over American merchant vessels in Chinese ports." A **fifteen-document run, `frus1930v02/d588–d603`, all filed 893.12**, opening with Minister Johnson's memorandum of a conversation with **Wu Lien-teh**, Director of the Chinese National Quarantine Service. Johnson, Cunningham (Shanghai) and Washington argue out whether an American ship must submit to Chinese quarantine.
- **Ottoman Empire / Morocco / Persia** — the Superior Board of Health at Constantinople (`frus1906p2/d495`, `frus1907p1/d338`), and the Tangier and Teheran councils named at `frus1908/d468`. Thinner: 11 documents for `"sanitary council"`, 18 for quarantine co-occurring with Morocco/Tangier/Persia/Teheran.
- **Spain, 1866–67** — a substantial cluster, `frus1867p1/d445`–`d478`, on Spanish cholera quarantine against American vessels; note `d461`, where Seward forwards a communication from the Metropolitan Board of Health on the sanitary condition of US ports as a *diplomatic instrument*.

### (f) The Second World War settlement — and where it stops
- **`frus1944v02/d254–d263`**: UNRRA drafts the **International Sanitary Convention, 1944** and the **International Sanitary Convention for Aerial Navigation, 1944**. Lehman to Hull and back, filed **512.4A1A1** and 840.50 UNRRA and 800.796. This is the aviation-quarantine regime being invented.
- Afterwards the convention appears only as a treaty-succession entry: `frus1949v09/d184` lists it in a multilateral-treaty schedule; `frus1951v06p1/d489` mentions the Protocol prolonging the 1944 convention.
- **`frus1919Parisv06/v07/v13`** do the same for the earlier conventions — the 1892/1893/1894/1897/1903 sanitary conventions appear in the Peace Conference's lists of multilateral instruments to be revived or succeeded. Useful for a treaty-succession argument, useless for practice.

### (g) The animal and plant sanitary regime — adjacent, large, and easy to confuse
Nearly a quarter of my core set. Treat as a separate project or exclude explicitly.

- 1913 **Plant Quarantine Act** (`frus1913`)
- 1928 US–Mexico convention on infectious and contagious diseases of livestock (`frus1928v03`; still being litigated in `frus1947v08/d695–d696`)
- **Argentine meat**: 1933 representations against US sanitary restrictions (`frus1933v04`), the unperfected **Sanitary Convention of 24 May 1935** (`frus1935v04/d318`), and Argentina pressing for ratification in 1938–40 (`frus1938v05/d297`, `d458`; `frus1940v05/d591–d597`, where Roosevelt's assurances to Buenos Aires and the US livestock lobby collide)
- Foot-and-mouth in Mexico, 1946–48 (`frus1946v11`, `frus1947v08`, `frus1948v09`)
- **The pork embargoes, 1881–1891** — a big and separate body: 117 documents mention trichinae/trichinosis, 201 mention "American pork," concentrated in `frus1883` (57), `frus1881` (49), `frus1884` (19), `frus1891` (13). Headings include "Importation of American pork containing trichinæ" and "Pork inspection." If your question is *sanitary regulation as trade barrier*, this is the largest single body in the corpus.

### (h) The technical-assistance and occupation strand
Not conventions, but where American sanitary practice was exported.

- Cuba and Panama sanitary conditions (`frus1904`, `frus1905`, `frus1907p2` "Improvement of Sanitary Conditions")
- **Liberia** — "Interest of the Department of State in sanitary reforms for Liberia" (`frus1930v03`, continuing from 1929v03), USPHS officer Howard F. Smith as Chief Medical Adviser (`frus1929v03`), Dr. R. G. Fuszek "Head of Sanitary Survey, Monrovia." Filed **882.124a**, which is the single largest public-health decimal class in the corpus (39 documents).
- 1942 **health and sanitation program agreements** with Bolivia, Brazil, Colombia, Ecuador, El Salvador, Haiti, Nicaragua, Paraguay, Peru (`frus1942v05`, `frus1942v06`) — nine-plus separate compilation headings, the Institute of Inter-American Affairs programme.

---

## 4. The archival payoff (this may be the most useful section)

Because `document_sources` preserves the State Department file citation, the corpus tells you **which decimal file to request at NARA**. I verified these empirically against the 1910–49 schedule in the bundled `decimal-class-labels.json` (class 8 = Internal Affairs of States; suffix `.12` = Public health; `.124` = Hygiene and sanitation; `.124A` = Sanitary engineer; `.1246` = Hygiene of vessels and aircraft; class 5 = Congresses and Conferences).

**RG 59 Decimal File 512.4 is the international-sanitary-conference file.** Confirmed instances:

| file | subject | documents seen |
|---|---|---|
| `512.4 A 1a` / `512.4-A` | OIHP and the League health organisation, 1921–23 | 6 (`frus1923v01/d45–d50`) |
| `512.4-B` | negotiation of the 1926 Paris convention | 3 (`frus1926v01/d113–d115`) |
| `512.4B3` | 1938 Paris conference; abolition of the Egyptian board | 4 (`frus1938v01/d927–d930`) |
| `512.4A1A1` | International Sanitary Conventions, 1944 (UNRRA) | 3 (`frus1944v02`) |

Country public-health files actually cited in printed FRUS documents:

| class | country + subject | documents |
|---|---|---|
| 882.124a / 882.124A / 882.124 | Liberia — sanitary engineer | 62 |
| 822.124 | Ecuador — hygiene and sanitation | 37 |
| 823.124 | Peru — hygiene and sanitation | 15 |
| 893.12 | China — public health | 15 |
| 883.12 | Egypt — public health | 14 |
| 821.12, 867.12, 838.124, 832.12, 838.12 | Colombia, Turkey, Haiti, Brazil | ~13 |

Also seen on core documents: `811.612`, `800.796` (aerial), `840.50-UNRRA`.

Only **396 of the 804** core documents carry a source row at all — pre-1910 volumes generally print no archival citation — so this map is only usable for the 1910–1949 window.

---

## 5. Limits, traps, and things I could not settle

1. **The Cuba problem is not fully solvable by keyword.** My `NOT (missile OR Khrushchev OR OAS OR blockade)` filter cut 863→620 on `quarantine` alone, but 28 documents in 1961–63 volumes survived it and at least 2 of 30 in my read sample were still the naval sense. Any count I give is an upper bound of ~±5%.

2. **Headers are useless before ~1920.** Nineteenth-century FRUS documents are headed "Mr. Hale to Mr. Seward" and nothing else. Only **10 documents corpus-wide** have a sanitary/quarantine/cholera/plague/epidemic/hygiene word in the header field. Searching headers will find you almost nothing. Search `volume_structures` (compilation headings) and body text instead.

3. **The person index will mislead you.** Hugh S. Cumming the Surgeon General — the US delegate to the 1938 Paris conference — **does not appear in the `persons` table**. What you get for "Cumming" is his son, Hugh S. Cumming Jr., the Foreign Service officer and INR director. The persons table is built from editorial "List of Persons" front matter, which only mid-twentieth-century volumes carry, so nineteenth- and early-twentieth-century health officials are simply absent. Do not use person search as a finding aid for this topic.

4. **The subject taxonomy is a partial help and a trap.** `Global Issues > Public Health > Public Health` (subject 102, 914 documents) is genuinely useful and its decade curve peaks *later* than mine (1930s 121, 1940s 183, 1950s 180) because it also catches health-as-development. But it overlaps my core set on only **78 documents**, and its own provenance string warns that the tags come from "case-insensitive string matching of subject names and variants, NOT semantic analysis — treat as recall-oriented candidates rather than ground truth." And subject 132, `Quarantine (Blockade)`, is the naval sense only.

5. **The post-1950 silence is a finding, not a gap in my search.** I checked directly: `"World Health Organization"` returns 156 documents, but the top-ranked hits in 1946–54 volumes are **abbreviation lists in front matter** (`frus1946v01/terms`, `frus1947v01/terms`, …) and passing mentions of WHO as one UN agency among several. There is no compilation on the **International Sanitary Regulations of 1951**. `"World Health Assembly"` returns 17. `smallpox` returns 2 documents in the whole Carter administration. The one late compilation that exists is **`frus1977-80v02`, "International Health, Population Growth, and Women's Issues"** — roughly 20+ documents around Peter Bourne as Special Assistant for International Health Issues, Halfdan Mahler and WHO, and a proposed "World Health Initiative." That is health as foreign-aid policy, not quarantine.

6. **Recall is unmeasured.** I never sampled outside my query to estimate what I missed. Two known likely gaps: (i) French-language enclosures — `"hygiene publique"` returns only 3 and `"Conseil sanitaire"` only 1, which is implausibly low for a regime conducted in French, so the corpus's French-language material is either sparse or spelled with accents my ASCII queries missed; (ii) the back-of-book analytical indexes in nineteenth-century volumes, which I did not mine and which would name topics precisely.

7. **Corpus boundary.** `/Users/jbotts/Development/frus/volumes` holds **694 XML files (3.1 GB)** but the index and `manifest.json` cover **552 volumes**. 142 files are outside the indexed set; I did not determine what they are, and anything in them is invisible to every count above.

---

## 6. What I would search for, if you want to go further

In rough order of expected yield:

1. `volume_structures LIKE '%Sanitary%'` and `'%uarantine%'` — 18 + 8 volumes, and every heading is a compilation. This is the cheapest high-yield move in the whole corpus and it is how I found most of §3.
2. The **1880 circular** (`frus1880/d4`) followed forward: read the 1880 and 1881 country sections for legation replies about attending the Washington conference. Nobody has to guess where they are — they are the despatches immediately following each country's routine business.
3. `decimal_class LIKE '512.4%'` in `document_sources`, then the same prefix in the NARA Central Decimal File. Sixteen printed documents point at a file that must contain hundreds.
4. `frus1928v02/d756–766` + `frus1932v02/d468–470` + `frus1938v01/d927–930` read as one sequence: the United States joins the Alexandria board in 1928 and votes to abolish it in 1938. Ten years, thirty documents, one arc.
5. `quarantine` restricted to `frus1930v02` (the China cluster) and `frus1879`/`frus1900` (the Japan clusters) for the extraterritoriality argument.
6. If the trade-barrier question interests you more than the epidemiological one: `trichina OR trichinosis OR "American pork"` in `frus1881`–`frus1891`, then the Argentine convention 1933–1940. Both are larger than the sanitary-convention material proper.
7. Terms I tried that returned little and are probably not worth repeating: `"epidemic intelligence"` (0), `"Conseil sanitaire"` (1), `pesthouse`/`lazaret` (3), `Kamaran`/`Camaran` (6), `Hamburg AND cholera` (6), `pilgrim AND (quarantine OR sanitary OR cholera)` (13). The Mecca-pilgrimage/Red Sea quarantine question — the engine of the whole nineteenth-century convention series — is **barely present in FRUS**, presumably because the United States had no pilgrim traffic. That absence is itself worth a sentence in whatever you write.

---

## 7. One-paragraph answer, if you need it now

FRUS documents the United States as a **participant, host and eventually an office-holder** in the international sanitary regime from the 1860s to 1948, and then stops. It carries the American side of the Vienna (1874) and Washington (1881) conferences, the founding of the Office International d'Hygiène Publique (1908), the US position in the 1921–23 OIHP-versus-League dispute, ratification of the revised Paris convention of 1926, a decade-long effort to seat an American on the International Quarantine Board at Alexandria (1928–32) that ends with the US helping abolish it (1938), the whole Pan American Sanitary Conference and Code sequence from 1905 to 1934, and UNRRA's drafting of the 1944 maritime and aerial sanitary conventions. On *practice* rather than treaty-making, its best material is quarantine as a sovereignty and race question in the extraterritorial world — the *Hesperia* at Yokohama in 1879, the plague quarantines against Japanese subjects in San Francisco and Colorado in 1900, and the 1930 argument over whether American ships must obey Chinese quarantine. Approximately **800 documents** across **209 volumes** touch the subject; something like **265** are substantially about it; and the working file to request at NARA is **RG 59, 512.4**.
