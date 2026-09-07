# Scoping memo: the isthmian canal in the FRUS corpus

**Question.** How did the United States pursue and negotiate rights to build and control an isthmian canal?

**Corpus.** Local FRUS Explorer index, 316,839 documents across 552 volumes, plus the TEI source and the app's bundled reference JSON. Everything below is reproducible from `queries.log`.

---

## 1. Headline

The corpus holds a **usable, near-continuous documentary spine for this question from 1862 to 1978** — roughly **3,200 candidate documents**, of which **~2,465** also carry negotiation vocabulary. Every named instrument in the sequence is present and locatable: Clayton–Bulwer (as a live dispute, not as a negotiation), Hay–Pauncefote I and II, Hay–Herrán, Hay–Bunau-Varilla, the Nicaragua treaty of 1914–16, Thomson–Urrutia, the 1936 revision, the 1955 revision, and the 1977 Torrijos–Carter treaties. Several **treaty texts are printed in full**.

But the shape of the evidence is lopsided in a way that matters for how you'd frame the project:

| Period | Candidate docs (by document date) |
|---|---|
| pre-1910 (pursuit and acquisition) | **417** |
| 1910 onward (defence of what was acquired) | **2,762** |

The corpus is far richer on **control** than on **acquisition**. The single densest acquisition moment — 1903 — is well documented, but the two decades of route-shopping and Anglo-American manoeuvring that produced it (1870s–1890s) are thin, and the founding instruments of 1846 and 1850 predate the series entirely.

**The three finding aids the app offers you are all unusable for this question.** Details in §5. Plan on full-text search.

---

## 2. What I would actually search for

The editors' vocabulary is not the historiography's vocabulary. Measured counts (FTS5, `porter unicode61`):

| Query | Docs | Note |
|---|---|---|
| `canal` | 6,957 | half of it is Suez |
| `canal AND suez` | 2,070 | the noise floor |
| `isthmus` | 802 | |
| `interoceanic` | 325 | + `inter-oceanic` 65 |
| `isthmian` | 225 | |
| `"canal zone"` | 1,576 | |
| `"panama canal"` | 1,927 | |
| `"clayton-bulwer"` | 57 | identical to `"clayton bulwer"` — the tokenizer splits hyphens |
| `"hay-pauncefote"` | 39 | |
| `"bunau-varilla"` | 51 | `"hay-bunau-varilla"` only 16 |
| `"hay-herran"` | 25 | |
| `"bryan-chamorro"` | 54 | |
| `"thomson-urrutia"` | 7 | |
| `"maritime canal company"` | 21 | |
| `"isthmian canal commission"` | 57 | |
| `"spooner act"` | 7 | |
| `"walker commission"` | 2 | |
| `"hull-alfaro"` | **0** | |
| `"frelinghuysen-zavala"` | **0** | |

Two lessons.

**(a) Do not search by treaty nickname.** The editors mostly don't use them. `hull-alfaro` and `frelinghuysen-zavala` return nothing; the 1934–36 revision is findable only through the section title *"Negotiations between the United States and Panama for the revision of the treaty of November 18, 1903"* (frus1934v05, 17 docs). Likewise `bidlack` returns **1** document and `mallarino` **2** — the 1846 New Granada treaty is cited as **"treaty of 1846"** (141 docs) or by its transit-guarantee clause, **"article xxxv" / "thirty-fifth article"** (39 / 28 docs, concentrated in frus1881 and frus1879). Those two phrases are the real handle on the legal basis for US intervention on the Isthmus.

**(b) Stemming will burn you.** `neutralization` and `neutral` return **exactly the same 19,672 documents**. Any count you take on `neutralization`, `tolls`, or `perpetuity` is a count of the stem, not the word. Verify before you quote.

The working query I settled on, and the one behind the counts in §1:

```
canal AND (isthmus OR isthmian OR interoceanic OR "inter-oceanic" OR panama
           OR nicaragua OR colombia OR "new granada" OR darien OR tehuantepec
           OR "costa rica")                                    -> 3,203 docs
```
adding `AND (treaty OR convention OR negotiation OR negotiate OR concession OR protocol
OR ratification OR ratify OR "right of way" OR sovereignty OR grant)` → **2,465**.

---

## 3. Where the material actually is

### 3a. The strongest single block: frus1903

`volume_structures` gives the editors' own section headings, and for this question they are the best finding aid in the whole system. frus1903 contains, in order:

- **d105–d225 (121 docs)** — *"Correspondence concerning the convention between the United States and Colombia for the construction of an interoceanic canal"* — the Hay–Herrán negotiation and its rejection by the Colombian senate. Beaupré–Hay traffic from Bogotá.
- **d226–d278** — *"Revolution on the Isthmus of Panama and establishment of independent Republic"*, split into consulate-general correspondence (20), communications from the Panama government (6), and the Colombian chargé (5).
- **d279–d306 (28 docs)** — *"Instructions to naval and consular officers concerning freedom of transit across Isthmus"* — i.e. the operational face of the Article XXXV guarantee.
- **d307–d330** — the aftermath, including **d320/d321**, Reyes's "statement of grievances" and Hay's answer of 5 January 1904.

I read frus1903 d321 in full to confirm this is not a stub: it is Hay's substantive reply to Colombia, arguing from the accomplished fact of recognition. That block of ~226 documents is the core of the acquisition story and can be cited as a unit.

frus1904 continues it: transfer of the New Panama Canal Company's property, transfer of the Canal Zone, **payment of the canal indemnity (12 docs)**, and establishment of US ports and post offices in the Zone (23 docs).

### 3b. Treaty texts are printed

This is worth knowing before you go to the Statutes at Large:

- **frus1901 d232a** (17,254 chars) — a Senate document reprinting *the Clayton–Bulwer Treaty and the Hay–Pauncefote Treaty with amendments* together.
- **frus1901 d233** — the presidential message transmitting Hay–Pauncefote II.
- **frus1902 d519** — the proclamation of Hay–Pauncefote II.
- **frus1904 d542** (25,446 chars) — the proclamation of the Hay–Bunau-Varilla convention, carrying the treaty text.

So the corpus gives you the *instruments* for 1850 and 1901 even though it does not give you their *negotiation*.

### 3c. The Anglo-American thread, 1861–1903

`"clayton-bulwer"` traces cleanly across forty years and is the best-documented diplomatic argument in the set:

- frus1861 d77 (Adams–Seward, London) — the earliest mention.
- frus1867 d438 (Dickinson–Seward, León) — Nicaragua.
- **frus1881 d339, d342, d345** — Blaine's attempt to modify the treaty; plus the message of the president.
- **frus1882 d181, d182, d203, d204** and **frus1883 d225, d266, d277, d310** — the Frelinghuysen–Granville exchanges, including Granville's replies to West.
- frus1888p1 d539 (Bayard–Phelps); frus1889 d173 (Salisbury).
- 1893–95: Costa Rica and the Bluefields crisis (frus1893, frus1894Nicaragua, frus1894app1, frus1895p1).
- 1900–03: the Hay–Pauncefote settlement.
- **1912–13: it comes back** — frus1912 d659–d665 including the text of the Panama Canal Act, and frus1913 d597/d598 — the British protest against tolls exemption for US coastwise shipping. This is the "control" question in its purest form.

### 3d. Nicaragua as the road not taken

- frus1871 d324 — *"Report concerning the route for the Nicaragua Canal, 1871"*.
- frus1879 (13 canal docs), frus1881 (28), frus1883 (19) — the de Lesseps moment and the American reaction.
- 1884 Frelinghuysen–Zavala: **effectively absent** (frus1884 holds only 6 canal documents; `zavala AND canal` returns 6 across the whole corpus, only one of which is from the 1880s).
- 1913–1916: the **Bryan–Chamorro** treaty and the protests of Costa Rica and El Salvador — the best-documented Nicaragua episode. frus1916 has *"Interoceanic Canal treaty between the United States and Nicaragua"* (36 docs) and *"Nicaraguan Canal Route—Convention"* (8); frus1914 and frus1915 carry the parallel protest chapters. `"bryan-chamorro"` runs into frus1917.
- 1938: frus1938v05 — *"proposed amendment to Nicaraguan constitution authorizing treaty for an inter-oceanic canal"* (12 docs) — the option was still live.

### 3e. Colombia's compensation

frus1914 (29 docs) — *"Conclusion of a treaty between the United States and Colombia for the settlement of their differences"* — plus frus1916 (10 docs) continuing it, and `"thomson-urrutia"` in frus1919v01 d82/d727/d742/d764. Notably it resurfaces in **frus1969-76v22 d35** and **frus1969-76ve11p2 d268/d270**: the Colombians were still raising 1903 in the 1970s.

### 3f. Revision and control, 1934–1978

| Volume | Section | Docs |
|---|---|---|
| frus1934v05 | Revision of the treaty of 18 Nov 1903 | 17 |
| frus1935v04 / frus1934v05 | Canal annuity in devalued dollars | 17 / 10 |
| frus1940v05 | Lease of tracts outside the Zone for canal defence | 7 |
| frus1948v09 | Withdrawal from defence sites; renewed negotiations | 16 |
| frus1952-54v04 | US–Panama political and economic relations | 47 |
| frus1955-57v07 | US–Panama political and military relations; **impact of the Suez crisis** | 62 |
| frus1961-63v12 | Panama | 20 |
| frus1964-68v31 | Panama (post-flag-riot) | 92 |
| frus1969-76v22 | **Panama, 1973–1976** (dedicated volume, 148 docs) | 146 |
| frus1977-80v29 | **Panama** (dedicated volume, 280 docs): Negotiation and Signing (95) + Ratification (73) | 168 |

The two **dedicated Panama volumes** (frus1969-76v22, frus1977-80v29) are the only volumes in the entire 552 whose *titles* name Panama. If you want the negotiation of control as an institutional process — Bunker, Linowitz, the DoD negotiating working group, the ratification fight — that is where it is, and it is dense: `frus1977-80v29` alone supplies 222 of the 2,465 negotiation-scoped hits.

### 3g. A seam worth taking seriously

The **1956 Suez crisis forced the United States to state its own theory of title at Panama.** `"panama canal" AND suez AND (sovereignty OR treaty)` inside frus1955-57v16 returns six documents including a memorandum from the Office of the Assistant Legal Adviser (d9), Eisenhower–Dulles conversations (d81), and NEA memoranda. frus1955-57v07's Panama section is titled, by the editors, *"…impact of the Suez Canal crisis."* This is the moment the US had to explain why nationalising Suez was illegitimate while holding Panama in perpetuity. It falls out of a search that most people would discard as Suez noise.

---

## 4. Hard limits of the corpus

**The founding acts are not here.** FRUS begins in 1861. The Bidlack–Mallarino treaty (1846) and the Clayton–Bulwer negotiation (1849–50) are *invoked* constantly but never *documented*. The earliest isthmian-canal document I could date in the corpus is **frus1872p2v1 d151, 17 September 1855** (an Attorney-General opinion, printed retrospectively in the Alabama-claims papers); the earliest contemporaneous run is **frus1863p2 d472–d486, Thayer–Seward, 1862–63**.

**The 1880s–1890s are thin.** Per-volume canal counts across 1879–1899 run: 1879:13, 1880:6, 1881:28, 1882:8, 1883:19, 1884:6, 1885:5, 1886:1, 1887:7, 1888:12, 1889:1, 1890:2, 1891:1, 1893:4, 1894:6, 1895:2, 1896:1, 1897:10, 1898:1, 1899:4. This is not an indexing gap — it reflects what the President chose to transmit to Congress. Pending and rejected treaties were routinely withheld, which is precisely why Frelinghuysen–Zavala is invisible. **For that period FRUS is a poor proxy for the diplomatic record and you should treat any argument from silence as unsafe.**

**No source notes before 1906.** 2,710 of 3,203 candidates have a parsed source note, but the volumes *without* one are exactly the ones you most need to trace: frus1903 (74 untraced), frus1904 (35), frus1881 (28), frus1883 (19), frus1912 (17), frus1910 (14), frus1905 (13), frus1879 (13). For the acquisition period FRUS prints text without provenance.

**No person index before 1906.** Only **1 of 285** volumes carrying a `persons` list is a pre-1906 annual. Consequently `Bunau-Varilla`, `Herrán`, `Cromwell`, `de Lesseps`, `Wyse`, `Amador`, `Remón` and `Squier` are **absent from the person authority entirely** — they exist only as strings in body text. Pauncefote is there (from a later volume). Any person-based analysis silently excludes the 1903 cast.

---

## 5. The three finding aids that do not work here — and why that matters

I checked each because a reader could reasonably trust them.

**Subject index.** Of 491 subjects in the bundled taxonomy, the only canal subject is **"Suez Canal"** (df 2,178). There is no Panama, isthmian, or interoceanic subject. Worse, on the densest canal block in the corpus (frus1903 d105–d330) only **82 of 226 documents carry any subject tag at all**, and the top tags are *Sovereignty* (26), *Peace* (25), *Science and technology* (24), *War* (20). Filtering by subject would silently discard two-thirds of the core evidence and mislabel the rest.

**Volume tag taxonomy.** 438 distinct tags; the canal-relevant ones are `panama` (100 volumes) and `suez-canal` (35). There is no `panama-canal` tag. frus1903, frus1904 and frus1912 are tagged only `colombia`, `nicaragua`, `panama`.

**Semantic map.** 179 clusters. Nine mention Panama or Nicaragua; exactly one names the canal — cluster 33 (`panamanian, torrijo, panama, canal`, 725 docs, entirely modern-era). Cluster 59 (`panaman, panama, porra, colon`, 1,067) is interwar; cluster 149 (`bluefield, mosquito, nicaragua, guatemala`, 912) is the 1890s Nicaragua crisis. **There is no cluster corresponding to the 1900–1904 acquisition.** The map will not lead you to it.

**Cross-references** are also modern-skewed: 3,550 outbound references from the candidate set (only 2 broken), but the most-cited targets are all 1955+ (frus1977-80v01 d29, d33; frus1977-80v13 d108). The pre-1906 volumes cross-refer in prose — the frus1903 section titles literally read *"See Foreign Relations, 1902, p. 293"* — which is not machine-linked.

---

## 6. The archival trail beyond FRUS

For the 1910+ material the source notes give you real hooks. Top decimal classes in the candidate set:

| Class | Docs | Reading |
|---|---|---|
| 711F.1914 | 107 | US–Canal Zone political relations / treaty (heavy in 1940–41 defence-site negotiations) |
| 817.812 | 74 | Nicaragua — canal |
| 811F.504 | 53 | Canal Zone — labor |
| 711.1928 | 51 | US–Panama political relations |
| 819.00, 819.74, 819.77, 817.51, 817.00 | 47/41/39/35/18 | Panama and Nicaragua internal affairs |

Top lot files: **78D300** (39), **81F1** (27), 63D351, 81D113, 84D241. Repositories: Department of State 1,835; Carter Library 273; National Archives 227; Nixon Materials 70; Johnson 50; Eisenhower 42. Footnote citations (707 rows) point mainly at *National Security Affairs* (106), *Presidential Materials* (29), *National Security File* (21), *Whitman File* (14).

**Two cautions on the app's own resolution machinery:**

1. **The decimal-class label table will mis-gloss the canal classes.** Its country vocabulary maps `11f` to **"Naos Island"**, not to the Canal Zone. So `711F.1914` — the single largest class in this corpus — would render as *"United States — Naos Island — political relations"*. Naos Island is in Panama Bay, so the parse is not random, but the gloss is wrong for the file's actual scope. Read the raw class, not the label. (I confirmed the class's real use by reading raw source notes: frus1940v05 d1159–d1165, frus1941v07 d333–d337, all `711F.1914/nnn`.)

2. **None of these classes is digitized.** NARA's digitised decimal-file ranges in the bundled index cover **18 classes only** — the WWI `763.72*` family and visa/citizenship classes 131/133. `711F.1914`, `811F.504`, `817.812`, `819.74`, `711.21`: **zero digitised ranges each.** Plan on College Park in person.

For the **pre-1906** material, where FRUS gives no provenance at all, the bundled central-files index does supply the route. In RG 59 country series it carries 93 canal-country rolls of Diplomatic Despatches (incl. *"Despatches from U.S. Ministers to Colombia, 1820–1906"*), 6 of Diplomatic Instructions (Volumes 15 and 16 cover Colombia 1833–1875), 16 of Notes from Foreign Missions, 111 of Consular Despatches (Cartagena, Santa Marta, Panama), and — directly on point — **Notes to Foreign Missions, "Colombia: April 24, 1885 – July 16, 1906 (includes Panama)"**, NAID 216903953. That is where the Hay–Herrán file lives.

---

## 7. What I would do next

1. **Treat frus1903 d105–d330 as the spine** and read it straight through. It is one editorially coherent block and it contains both the negotiation and its collapse.
2. **Run the Article XXXV thread separately** (`"article xxxv" OR "thirty-fifth article"`, 67 docs, concentrated 1878–1913). It is the legal argument that connects 1846 to 1903 to the tolls dispute, and no topical search finds it.
3. **Read the Clayton–Bulwer list in date order** (§3c) as a single forty-year argument with Britain — it is the cleanest available narrative of how the US converted a shared-canal obligation into an exclusive right.
4. **Pair frus1912 d659–d665 with frus1913 d597/d598** for the moment when "control" became legally contentious in exactly the terms the 1977 treaties would revisit.
5. **Take the Suez seam (§3g) seriously** rather than filtering it out.
6. **Do not build the project on the 1880s–90s FRUS record.** Use it as a pointer to the microfilm listed in §6 and expect to work outside FRUS for the route-shopping decades.

## 8. Numbers you can check

| Claim | Where |
|---|---|
| 316,839 docs / 552 volumes | `SELECT COUNT(*) FROM document_cache` |
| `canal` = 6,957; `canal AND suez` = 2,070 | queries.log lines 4, 21 |
| Candidate set = 3,203; negotiation-scoped = 2,465 | lines 30, 61 |
| pre-1910 = 417 of 3,179 dated | line 30 (decade histogram) |
| `neutral` = `neutralization` = 19,672 | lines 57–58 |
| Only 1 pre-1906 volume in `persons` (of 285) | lines 27–29 |
| Only "Suez Canal" in the 491-subject vocab | line 46 |
| 82 of 226 frus1903 canal docs subject-tagged | line 65 |
| No canal class among 18 digitised decimal classes | line 71 |
| 128 canal-titled sections in 61 volumes, 2,527 attached docs | line 24 |

*Prepared from a read-only copy of the index; no writes to any corpus surface.*
