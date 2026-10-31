import re, sys
sys.path.insert(0, ".")
from gen_common import cite, QV, M

def C(k):
    return cite(k)

def Q(i):
    return "“" + QV[i]["text"] + "”"

# keys
VN_DURB_MAR = "frus1958-60v01/d111"
VN_DURB_MAY = "frus1958-60v01/d160"
VN_MANILA = "frus1964-68v04/d280"
VN_MCPH = "frus1964-68v05/d197"
VN_CALH = "frus1964-68v05/d258"
VN_BUNK = "frus1969-76v06/d175"
CN_DAV = "frus1943China/d202"
CN_GAU = "frus1944v06/d269"
CN_SPR = "frus1947v07/d591"
CN_CAB = "frus1948v07/d590"
IR = "frus1961-63v17/d27"
PH = "frus1961-63v23/d355"
KR = "frus1961-63v22/d249"
SA74 = "frus1969-76ve09p2/d122"
HT = "frus1977-80v23/d252"
SA80 = "frus1977-80v18/d206"
STAFF = "frus1969-76ve09p2/d152"
SA75 = "frus1969-76ve09p2/d161"
DE1 = "frus1969-76ve15p2/d292"
DE2 = "frus1969-76ve15p2/d293"
JP_FORD = "frus1969-76ve12/d219"
LIBYA = "frus1969-76ve09p1/d49"
JP_TOGO = "frus1969-76ve12/d222"
JP_SAITO = "frus1969-76ve12/d224"
FCPA = "frus1977-80v03/d248"
KG1 = "frus1977-80v13/d92"
KG2 = "frus1977-80v13/d94"
KG3 = "frus1977-80v13/d95"
HI1 = "frus1894app2/d255"
HI2 = "frus1894app2/d306"

Q_QUESTION = "How has corruption, or allegations of corruption, affected U.S. foreign policy decisions or the conduct of diplomacy?"

TXT = f"""# {Q_QUESTION}

## The bottom line

**1. What FRUS answers directly.** The printed record answers this question well for a handful of episodes and only partly for the rest. Across the full series as published (553 volumes, with two second-edition volumes set aside as duplicates of volumes that are also present), about one document in a hundred uses the vocabulary of corruption at all (3,174 of 311,429 documents), and about one in 650 does so three or more times (479 documents in 203 volumes); this overview rests on 30 of those and related documents. What they show is consistent. Officials repeatedly weighed an ally's corruption against a strategic interest, and the strategic interest usually won; corruption moved policy most visibly when the corrupt party was American (a firm or a Congress under pressure) rather than foreign. In South Vietnam the Embassy pressed the government on corruption from 1960 and by January 1970 Ambassador Bunker told President Thieu that corruption was \u201cthe number one problem\u201d and that the government's failure to act on it was \u201csharply affecting\u201d American ability to help ({C(VN_BUNK)}). In 1961 the State Department's view of the Philippines was that corruption was characteristic of the country's politics and no reason to intervene ({C(PH)}). In 1976 President Ford answered Japan's request for help over the Lockheed bribery scandal by offering to share American investigators' material and proposing an international agreement on such payments ({C(JP_FORD)}). In 1978 officials planning the withdrawal of American troops from Korea told one another that the \u201cKoreagate\u201d bribery affair had cost the administration votes in the House ({C(KG2)}).

**2. Where FRUS points for the rest.** Two channels, which are not added together. *Where the printed documents came from* (the 30 documents this overview cites; 28 of them carry a source line): the State Department's decimal central files in Record Group 59 for the China, Vietnam and Korea reporting of 1943 to 1961 (the source lines cite file numbers such as 893.00, 751K.00 and 795B.00; the bundled archival indexes give no NARA series identifier or access status for these files); the Records of Henry Kissinger (Lot 91D414, entry A1 5403, NARA identifier 2131131, 1973 to 1977, partly restricted under the national-security exemption) for the 1975 German Lockheed memoranda; Transcripts of Secretary of State Henry Kissinger's Staff Meetings (Lot 78D443, entry A1 5177, identifier 619160, 1973 to 1977, unrestricted) for the August 1975 discussion of agents' commissions; the Jidda Embassy Files in Record Group 84, Lot 79F80 (the bundled authority names the lot and its "Agent's Fees" files, but the archival index carries no series identifier, so I could not resolve it to a NARA series); the Department's Central Foreign Policy Files, cited by P-number, for the Japan conversations and the Haiti airgram; the Department's Subject-Numeric Central Files, 1970 to 1973, for the Bunker telegram; and the Johnson, Kennedy, Ford and Carter presidential libraries' national-security files for the White House papers (the Carter Library's White House Central Files for the 1980 export memorandum; series titles and boxes are in the printed source lines, and I did not resolve the library series to NARA identifiers). *What the editors' footnotes cite without printing*, over the 20 volumes that hold the cited documents (the pointed-at index covers 15 of those 20, and holds only lot, library and decimal-file references; it is the volumes' whole footnote record, not the footnotes to the cited documents alone): the National Security Files at the Johnson, Kennedy and Carter libraries and the Nixon Presidential Materials NSC Files head the list; among State Department lots, the Secretary's and Under Secretary's memoranda of conversation (Lot 65 D 330, which NARA titles The Secretary's and the Under Secretary's Memorandums of Conversation, entry A1 1566, identifier 602231, 1953 to 1964, unrestricted); the lot the editors call the Bundy Files (Lot 85 D 240; NARA's matching series is titled Subject Files, created by the Office of the Assistant Secretary for East Asian and Pacific Affairs, entry A1 5408, identifier 2131132, 1961 to 1974, unrestricted); and the lot the editors call the Vietnam Working Group Files (Lot 66 D 193; NARA's matching series is titled Subject Files Relating to Political, Military, Economic Aid, and Administrative matters, created by the Bureau of Far Eastern Affairs, entry A1 5155, identifier 2658382, 1955 to 1962, access status listed as possibly restricted). The editors' names and NARA's titles differ, and NARA's creator attributions are not always reliable, so check each lot's finding aid before ordering boxes. Those lists name the unprinted shelves of the volumes, not shelves known to hold corruption material; I cannot say from the index which of them do.

**3. What this request cannot get from FRUS.** (a) *Proof that an allegation changed a decision.* The documents show officials discussing corruption and, in a few cases, naming it as a reason (Congress, aid, a troop timetable); they rarely say what they would have done otherwise, and I did not find a document in the set that records a decision reversed on corruption grounds alone. (b) *The evidence behind the accusations.* The Senate subcommittee that exposed the Lockheed payments is present only through State Department summaries of its staff's findings (a search for the subcommittee's name, "Church", and "multinational" together returns 13 documents in 10 volumes); its own records are not in FRUS, and the bundled archival indexes do not resolve them to a shelf. (c) *The period before 1860.* The library holds 483 dated documents from before 1860, in 9 volumes. A search for the corruption words returns 2 of them, and a wider search that added the counterpart vocabulary of the period (peculation, defalcation, exactions, extortion, "presents to", irregularities) returns 49, which I did not read; the check that the search works found the phrase "Department of State" in 97 of the 483 and an impossible nonsense word in none. That is a gap in what is indexed, not evidence that early diplomacy was clean. (d) *The last decade.* There are only 177 dated documents after 1989 in the series as indexed, and none uses the corruption words; I make no claim about the 1990s. (e) *Corruption by American officials themselves.* I did not follow Watergate (183 documents in 51 volumes mention it), Teapot Dome (2 documents) or the Bank of Credit and Commerce International (1 document), because whether they count is your decision below. (f) *The archives of the other side.* Where the Saudi, Japanese or Libyan governments acted on the accusations, FRUS prints only what American diplomats reported of it.

**Scope.** The 553 volumes of the series as indexed, 311,429 documents once front matter, editors' notes and the two duplicate second editions are excluded; documents that use the corruption vocabulary at all (3,174) were scanned, documents that use it three or more times (479) were treated as the core set, and 30 documents were read whole and cited. The set is a selection made by the Department's editors, so what it shows is what they chose to print.

## Decisions this needs from you

- **What counts as corruption.** Bribery, graft, embezzlement and the like only, or also patronage and nepotism, campaign money and influence-buying, or abuse of power as in Watergate? I used the first group plus nepotism; the narrow reading drops nepotism and cronyism (about 50 of the documents scanned), and the broad one adds Watergate and its diplomatic consequences, which I did not follow.
- **Whose corruption.** A client government's, an American firm's, or an American official's or legislator's? I included the first two and, because the documents tie it to a policy decision, Koreagate (foreign bribery of American legislators); I left American officials' own misconduct out.
- **Allegation or fact.** Many of the charges (Hawaii in 1893, the Chinese Nationalist officials, the Saudi princes) are reported, not proved. I included allegations, because the question does. If you want established cases only, the set shrinks to the Lockheed admissions and Koreagate.
- **What "affected" means.** A document where an official links corruption to an American action, or any document where corruption is discussed? I used the first for the findings and the second only to find them.

## Findings

### 1. Vietnam: corruption was raised with the government for a decade, and increasingly because of Washington's own politics

In March 1960 Ambassador Durbrow reported that an adviser to President Diem regarded one arrangement involving the Can Lao Party's business agent as "straight unadulterated corruption" ({C(VN_DURB_MAR)}). In May he put the charge to Diem directly. Diem replied that the party's task was to prevent it, in these words: {Q('Q5')} ({C(VN_DURB_MAY)}). By October 1966 the push came from Washington: at Manila President Johnson asked Ky whether anything could be done about corruption before the President's critics got there, with Congressional investigations about to begin ({C(VN_MANILA)}). In June 1967 the President's special counsel reported what Ky told him: {Q('Q8')} ({C(VN_MCPH)}). The Embassy had an interagency committee on corruption; in July 1967 its Minister-Counselor for political affairs agreed with Komer that the level of corruption had become a key obstacle to pacification and discussed Komer's proposal to blacklist officials so American advisers would avoid them ({C(VN_CALH)}). And in January 1970 Bunker told Thieu: {Q('Q10')} ({C(VN_BUNK)}), tying it to a Congressional inquiry into black-market currency and the mood on aid. The documents show talk, committees and controls on Americans' own conduct; I did not find in them a decision to cut aid for corruption.

### 2. China, 1943 to 1948: corruption as the diagnosis of an ally that would not hold

American diplomats put corruption at the centre of their account of the Nationalist government, in the years when Washington was deciding how much to back it. In June 1943 John Paton Davies, proposing an American consulate and observers in Communist territory, wrote of the Kuomintang's officials: {Q('Q1')} ({C(CN_DAV)}). In February 1944 Ambassador Gauss reported a plot by young officers to remove officials they believed corrupt ({C(CN_GAU)}). In August 1947 Philip Sprouse gave General Wedemeyer's mission a memorandum that said {Q('Q3')} ({C(CN_SPR)}). And in December 1948 the Consul General at Shanghai, Cabot, wrote to the Department's Far Eastern director: {Q('Q4')} ({C(CN_CAB)}). That last letter does not contain any of the words I searched for in the form I searched for them (it says "grafters"); I reached it by asking the semantic index for the neighbours of the 1943 Davies memorandum, where it appears fourth. These documents show how the diagnosis was put to Washington; by themselves they do not show that it changed a decision.

### 3. Tolerated, excused or made a condition: corruption weighed against other interests, 1961 to 1980

The same documents that deplore corruption often argue it should not decide policy. In March 1961 a memorandum from the Policy Planning Council's vice chairman on Iran said corruption had always been a feature of Iranian administrations, that the Shah himself was honest though many around him were not, and that it was not a major factor in the economy ({C(IR)}). In July 1961 the National Security Council staff recorded the State Department's view of the Philippines: {Q('Q11')} ({C(PH)}). In December 1961 Ambassador Berger cited the Korean military government's campaign against corruption among his reasons for confidence in it ({C(KR)}). In December 1974 the Embassy in Saudi Arabia revised its earlier estimate and concluded that {Q('Q14')} ({C(SA74)}); it recommended telling the Saudis that the United States would not facilitate corruption. By the start of 1980 Ambassador West called corruption the greatest single threat to the ruling family's stability and said he knew of no truly effective means to help correct it ({C(SA80)}); that report is the 21st-nearest neighbour of the 1974 airgram in the semantic index. And in July 1978 the Embassy in Haiti wrote of a new aid proposal that {Q('Q17')} ({C(HT)}).

### 4. When the corrupt party was an American firm, corruption became a problem of the diplomacy itself, 1975 to 1980

In August 1975 the Department's staff discussed agents' commissions on arms sales to the Gulf; one official said he could find nothing good in them, and Kissinger answered that this was the way business was done in the Middle East ({C(STAFF)}). The next month Ambassador Akins told Saudi Defense Minister Prince Sultan that Lockheed had admitted about $20 million in bribes abroad and that the Senate wanted the recipients' names; he reported Sultan's reaction in these words: {Q('Q32')} ({C(SA75)}). The same autumn the Department learned the Senate staff's findings on payments in Germany, and an editors' note records Kissinger telling President Ford: {Q('Q19')} ({C(DE2)}; the findings themselves are in {C(DE1)}). In 1976 Japan's government sought American help with the Lockheed investigation; Kissinger told a Japanese ambassador in April that he had kept himself out of the matter ({C(JP_TOGO)}), another envoy of the Prime Minister stressed in May how political the question was in Japan ({C(JP_SAITO)}), and Ford had offered in March to share investigators' material ({C(JP_FORD)}). Libya sent a diplomatic note asking for details of the payments on its Lockheed aircraft ({C(LIBYA)}). The law that followed had a cost its own administrators recorded: in July 1980 the Commerce Secretary and the Trade Representative, reporting that exporters thought the Foreign Corrupt Practices Act a major disincentive, wrote that {Q('Q26')} ({C(FCPA)}).

### 5. Koreagate and the timetable for withdrawing from Korea, 1978

Allegations that South Koreans had bribed members of Congress did not stay in the Congress. In April 1978 the officials planning the withdrawal of American ground forces from Korea listed postponement among their options on the ground that the Congress could not deal with Korean policy while the affair hung over it ({C(KG1)}). In the meeting that followed, Assistant Secretary Holbrooke said: {Q('Q29')} ({C(KG2)}). A week later the national security adviser wrote to President Carter: {Q('Q30')} ({C(KG3)}). Here an allegation of corruption directly altered what the Executive Branch thought it could ask the legislature to approve, which is as close to a decision effect as the documents I read come.

### 6. The charge as contested ground: Hawaii, 1893

In the 1893 papers on the overthrow of Queen Liliuokalani, both sides invoked corruption. Asked by Blount, who was reporting to Secretary of State Gresham, what caused the revolution, a Honolulu witness answered: {Q('Q27')} ({C(HI1)}). A statement taken days later, hostile to the revolutionists, answered: {Q('Q28')} ({C(HI2)}). These documents do not show that corruption decided the American position; they show that the allegation was a main exhibit in the evidence the United States collected before deciding it. They are also 18 of the 28 documents that discuss corruption at length in the 1890s, which is why that decade looks richer in the series than its size warrants.

## How this was done

I searched the full-text index of all 553 volumes for a defined family of words (corrupt-, brib-, graft, embezzl-, peculat-, venal-, kickback, malfeasance, nepotism, cronyism), counting the index's matches and then re-counting each occurrence in the flattened text of each hit document. The index folds word endings together, so I checked the literal wording: of the 479 core documents, all 479 use a family word in some form and 419 use one of the five plainest (corruption, corrupt, bribery, bribe, graft); I read a spaced sample of 40 and found the family meant corruption or bribery in public or commercial life in 35 (the others were lists of crimes in extradition treaties and figurative uses), whereas the broader set of documents with a single mention gave only 27 of 40, so I used the core set only to choose what to read. The family appears in about 6 documents in 100 in the ten volumes richest in it and 0.9 in 100 elsewhere (a contrast guaranteed in part by choosing the richest volumes), whereas the phrase \u201cDepartment of State\u201d, a control, appears in 35 in 100 and 30 in 100 of the same two groups, and a nonsense word in none, so the vocabulary measures the subject rather than the corpus. I dated documents by the date stored for each document, not by the volume year. In the documents with at least three mentions, the rate per thousand dated documents was 1.2 to 3.5 in each decade from the 1860s to the 1900s, 0.3 to 1.0 from the 1910s to the 1940s, and 1.5 to 4.0 from the 1950s to the 1980s; the 1890s figure is mostly one appendix. I then read 30 documents whole and checked every quotation here against the stored text of its document. I also asked the semantic index, which compares documents by meaning rather than by shared words, for the nearest neighbours of eight documents (suggestions, not evidence; the memo gives the distances against random pairs and against the typical 25th neighbour) and reached two cited documents that way: the Shanghai letter and the Kissinger conversation with the Japanese ambassador. The method has limits: the index stores a flattened text in which editors' footnotes sit with the document, so some of what is quoted is the editors' own words and I say so where it matters, and the word family missed one inflection ("grafters"), found only by the semantic search.

## Read next

The collection that goes with this overview, "Corruption and U.S. diplomacy (agent run s6)", contains the 30 documents above in the order of the findings, with a note on each saying what it shows, and the quoted passages as excerpts; open it in the app, begin with the Vietnam and the Lockheed sections, and read each document's neighbours there. Your answers to the decisions above would unlock the following: a broader reading adds the Watergate and Iran-Contra material (11 documents mention the latter); a narrower one lets the Lockheed and Koreagate sections stand alone as the established cases; adding the published Senate hearings on multinational corporations would supply the evidence the State Department only summarised; and a request for a single country or region would let me read the rest of the 479 core documents for the places I only touched (Iran, the Philippines, Morocco, Liberia, Colombia, the Dominican Republic).

I checked two things before finishing: every quotation in this overview and every excerpt in the collection is one the memo verified against its document, and every document this overview cites is in the collection.
"""

open("overview.md", "w").write(TXT)
print(len(TXT), "chars")
