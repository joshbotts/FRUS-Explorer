# The name-authority overlay's other wrong merges: the A4c review, 2026-10-17

**What this is.** The record of plan of record §6g's finding *"the name-authority overlay merges more people than
#1657's two"*, worked on the owner's word of 2026-10-16 (the card A4 left, started after #1707 merged): every
candidate read, what was corrected and why, what was left and why, what the bundle and a full library show, and
what is still wrong. The corrections themselves are `PersonAuthorityIndexGenerator/persons-complete-corrections.json`,
each with its reason; the generator's rules are `PersonsCompleteCorrections.swift` and the runbook's
`PersonAuthorityIndexGenerator` entry. §6 is open: none of it is filed.

## 1. What was read, and how

- **A4's lead**: the 317 crosswalk anchors the overlay adds whose own persons-list name disagrees with their
  record's, 206 records (A4's `A4-overlay-anchors-naming-someone-else.tsv`, in its session notes). For each record,
  the anchor's own entry in its volume (`~/Development/frus/volumes` at `6170e4b32`), the registry record
  (`HistoryAtState/people` at `63b537ad`: its preferred name, life years, every anchor's own entry), and every
  overlay entry carrying the people-id (`frus-name-authority` at `cb8b0a5`: all its anchors, not only the flagged
  ones, its Wikidata and VIAF ids and the role text the generator would take from it).
- **Every identifier a correction lists was read** on wikidata.org (label, description, life years, VIAF), and a
  VIAF id Wikidata holds no item for on viaf.org (its headings and dates). One that could not be shown to be
  someone else's stays (Curtis F. Jones's VIAF 35793170, *Jones, Curtis C.*).
- **Same-name merges the name comparison cannot see**: 1977-1980 vol. XI Part 1's two lists of Tehran hostages,
  every name against what it joins (one more: the hostage James Hughes under Brigadier General James D. Hughes);
  and the 31 overlay entries carrying two or more people-ids the registry knows, whose anchors all go to the first
  (§6.2).
- **The rule**: correct a plainly different person, never a spelling. A record whose registry anchors describe
  one career and whose flagged anchor describes the same career under another spelling, a nickname, a misprinted
  initial or a later post is left (§4).

## 2. What the generator does now

Two optional fields join A4's `anchors`, `wikidata` and `viaf`:
- **`role`**: the entry's role text, exactly as `roleText(from:)` takes it, withheld from every people-id of the
  entry. The overlay's entries pool both people's occupations, and the first, which becomes the role, is often the
  other person's: Richard F. Allen read *planning staff, National Security Council*; Ernesto Betancourt
  *President of Venezuela*. 23 corrections list one.
- **`joins`**: the registry record the held-apart anchors belong to, with its registry name (checked as the
  people-id is). After every entry, each listed anchor joins it wherever neither the registry nor an overlay
  entry answered for it; a join never overrides an answer. 16 corrections list one. **Without a join, the app
  re-merges by name**: held apart alone (measured in §5's first run), Richard V. Allen's five 1981-1988 entries
  and his Public Diplomacy one rejoined Richard F. Allen in the rollup, bridged by 1952-1954 vol. VIII's plain
  *Allen, Richard*, which is Richard F.'s and fits either name.
- **An identifier or role text is listed when it is not the keyed person's**, not only when it is the other
  person's: most of these entries' Wikidata ids are name-only matches to a third person (Alfred Rosenberg's is a
  Czech film actor born in 1975; Charles Erwin Wilson's a mayor of Montreal of 1851-1854; Richard Kerr's a British
  songwriter).

## 3. The eighty corrections

Seventy-three entries keyed to one person that carry another's anchors, then seven entries carrying several
people-ids (the last seven rows), whose misplaced anchors are held apart from every id of the entry and, where the
right one is in the bundle, join it. *Documents* counts the full library's documents that mention a listed anchor.
*Joins* is the registry record the anchors join. A listed Wikidata or VIAF id, or *withheld*, is kept off the
record.

| People-id | Keyed to | Held apart for | Anchors | Documents | Joins | Wikidata | VIAF | Role text |
|---|---|---|---:|---:|---|---|---|---|
| 100307 | Allen, Richard F. | Allen, Richard V. (registry 100308) | 13 | 118 | 100308 | Q517683 | 44887512 | withheld |
| 101262 | Betancourt, Ernesto | Betancourt, Rómulo (registry 101263) | 12 | 96 | 101263 | Q332081 | 106963495 | withheld |
| 112506 | Simons, Hans | Simons, Thomas W., Jr. (registry 112508) | 1 | 40 | 112508 | Q130776132 | 66545568 |  |
| 108798 | McCormack, Alfred | McCormack, Richard T. (registry 108802) | 1 | 24 |  | Q91470077 | 70291291 |  |
| 105915 | Hill, Arthur M. | Hill, A. Alan (Chair, Council on Environmental Quality, 1981-1989) | 1 | 24 |  | Q58003150 | 93748371 | withheld |
| 115488 | Freeman, Charles L. | Freeman, Orville L. (registry 104545) | 14 | 181 | 104545 |  | 40682506 | withheld |
| 114284 | Warne, William E. | Warne, W. Robert (Office of Caribbean Affairs, 1977-1980) | 2 | 17 |  |  | 249649234 |  |
| 108583 | Martin, William I. | Martin, William F. (NSC Executive Secretary 1982-1986; Deputy Secretary of Energy) | 4 | 24 |  | Q2072139 | 64327120 | withheld |
| 115673 | Kaiser, Mary J. | Kaiser, Marcus (Swiss chargé in Iran) | 1 | 13 |  | Q103379571 |  |  |
| 112673 | Smith, Willard W. | Smith, William Y. (registry 112676) | 13 | 76 | 112676 | Q8020641 | 26279393 |  |
| 116050 | Rosenberg, Alfred | Rosenberg, Alison P. (NSC staff, 1987-1988) | 1 | 12 |  | Q2158657 | 111673310 |  |
| 115547 | Graham, Wallace H. | Graham, William (Director, Office of Science and Technology Policy) | 2 | 18 |  | Q956335 |  | withheld |
| 102259 | Carter, William Beverly, Jr. | Carter, William A. (Billy), brother of Jimmy Carter | 1 | 9 |  |  |  |  |
| 108354 | Maher (Mahir), Ali | Maher, Ahmed (Egyptian diplomat) | 1 | 8 |  | Q401372 |  |  |
| 115089 | Abdul, Monem | Abdul, Mahmood (Bangladeshi Air Force) | 1 | 7 |  | Q3843442 |  |  |
| 111851 | Salmon, Jean | Salmon, John W., Jr. (Department of State) | 1 | 7 |  |  | 86296384 | withheld |
| 105455 | Hamilton, Fowler | Hamilton, Lee H. (registry 105460) | 6 | 24 | 105460 | Q19094847 | 85852018 |  |
| 115622 | Hubbard, Charles J. | Hubbard, Carroll (Representative from Kentucky) | 1 | 5 |  | Q1045188 |  |  |
| 115246 | Bowen, John W. | Bowen, Otis R. (Secretary of Health and Human Services) | 1 | 5 |  | Q887335 | 1344258 | withheld |
| 114790 | Woods, Arthur | Woods, Alan (AID Administrator, 1987-1989) | 1 | 5 |  | Q4708100 | 114518203 | withheld |
| 113171 | Sullivan, John L. | Sullivan, John H. (AID) | 1 | 4 |  | Q949384 | 75092583 |  |
| 103713 | Duncan, Donald B. | Duncan, Donald Keith (D. K.), of Jamaica | 1 | 4 |  | Q99439541 |  |  |
| 106471 | Jackson, Elmore | Jackson, Everett (prisoner in Cuba until 1979) | 1 | 4 |  | Q125781008 |  |  |
| 100365 | Alvarez, Alberto I. | Alvarez, Alvaro (Uruguayan foreign ministry) | 1 | 4 |  | Q76359495 | 306170851 |  |
| 111651 | Roth, William Matson | Roth, William V., Jr. (registry 111652) | 2 | 5 | 111652 | Q107782682 | 17306010 |  |
| 107637 | Lang, Kenneth W. | Lang, Kathleen (Office of Soviet Union Affairs) | 1 | 4 |  | Q88926002 | 55382181 | withheld |
| 108089 | Long, Robert W. | Long, Robert L. J. (Admiral, Commander in Chief Pacific) | 1 | 3 |  |  | 23849100 |  |
| 107108 | Khan, Nawabzada Nasrullah | Khan, Begum Nasim Wali (Awami National Party) | 1 | 3 |  | Q135402906 | 47876548 |  |
| 104072 | Evans, Barbara | Evans, Ben (CIA Executive Secretary) and Evans, Billy Lee (Representative from Georgia) | 2 | 4 |  | Q57556607 |  |  |
| 109157 | Miller, George P. | Miller, G. William (registry 109156) | 1 | 3 | 109156 | Q446960 |  |  |
| 108110 | Lopez, Salvador P. | Lopez, Sheila B. (Office of the Executive Secretary) | 1 | 3 |  |  |  | withheld |
| 106680 | Johnson, Tom | Johnson, Thomas (Science Research Laboratory, West Point) | 1 | 3 |  | Q110041288 |  |  |
| 113000 | Stevenson, Adlai Ewing, II | Stevenson, Adlai E., III (Senator from Illinois) | 1 | 1 |  |  |  |  |
| 105584 | Harris, George L. | Harris, George S. (INR, Near East and South Asia) | 1 | 2 |  | Q1334754 |  | withheld |
| 105420 | Hall, John A. | Hall, Joseph M. (hostage in Tehran, 1979-1981) | 1 | 2 |  | Q56678232 | 36403967 |  |
| 106698 | Jones, Curtis F. | Jones, Charles A., Jr. (hostage in Tehran, 1979-1981) | 1 | 2 |  | Q126164068 |  |  |
| 107780 | Lee, Guy A. | Lee, Gary E. (hostage in Tehran, 1979-1981) | 1 | 2 |  |  |  |  |
| 101174 | Bennett, Donald V. | Bennett, Douglas (AID Administrator) | 1 | 2 |  |  |  |  |
| 115705 | King, Kenneth | King, Kurleigh (Secretary-General of CARICOM) | 1 | 2 |  |  | 72996921 |  |
| 101791 | Brown, Allen W. | Brown, Timothy C. (Uruguay desk officer) | 1 | 2 |  | Q128303768 | 76553806 |  |
| 106198 | Hoyt, Michael P.E. | Hoyt, Mary (Rosalynn Carter's press secretary) | 1 | 2 |  | Q107211205 | 19040936 |  |
| 113302 | Taft, William Howard | Taft, William Howard, IV (registry 113304) | 1 | 2 | 113304 |  | 67636647 | withheld |
| 113531 | Thompson, Herbert B. | Thompson, Harold (Department of Health and Human Services) | 1 | 2 |  | Q2661942 |  | withheld |
| 107055 | Kerr, Robert Samuel | Kerr, Richard (CIA Deputy Director for Intelligence) | 2 | 3 |  | Q7327057 | 49011062 | withheld |
| 104298 | Fish, Hamilton | Fish, Hamilton, III (1933-1939) and Fish, Hamilton, IV (1977-1980), Representatives from New York | 2 | 2 |  |  |  |  |
| 109552 | Murphy, Franklin | Murphy, Frank (Attorney General, 1939-1940) | 1 | 1 |  | Q63862041 |  |  |
| 100890 | Barnes, C. Tracy | Barnes, Clair Cortland (hostage in Tehran, 1979-1981) | 1 | 1 |  |  |  |  |
| 102815 | Cooke, David O. | Cooke, Donald J. (hostage in Tehran, 1979-1981) | 1 | 1 |  |  |  |  |
| 103206 | Davis, Richard Hallock | Davis, Richard J. (Assistant Secretary of the Treasury) | 1 | 1 |  | Q7329342 | 96752185 |  |
| 104308 | Fisher, Richard | Fisher, Roger (Harvard Negotiation Project) | 1 | 1 |  |  |  | withheld |
| 107934 | Lewis, Price, Jr. | Lewis, Paul Edward (hostage in Tehran, 1979-1981) | 1 | 1 |  | Q55439013 |  |  |
| 110787 | Pittman, Charles J. | Pittman, Charles (Chuck), Colonel (Desert One) | 1 | 1 |  | Q1439529 | 167201996 | withheld |
| 112010 | Schaefer, Hermann R. | Schaefer, Thomas E. (hostage in Tehran, 1979-1981) | 1 | 1 |  |  | 198857533 |  |
| 111612 | Rosenberg, Richard J. | Rosenberg, Robert (NSC Intelligence Coordinator) | 1 | 1 |  | Q2158657 | 111673310 |  |
| 104238 | Ferreira, Antonio Medeiros | Ferreira, Armenio (MPLA representative in Lisbon) | 1 | 1 |  | Q4794372 | 99810869 |  |
| 105453 | Hamilton, Charles W. | Hamilton, Lee H. (registry 105460) | 2 | 6 | 105460 | Q984174 | 85852018 |  |
| 101828 | Brown, William Andreas | Brown, William C. (Executive Secretariat) | 1 | 1 |  | Q8003915 | 22325906 |  |
| 105126 | Graves, Edwin D., Jr. | Graves, Ernest, Jr. (Director, Defense Security Assistance Agency) | 1 | 1 |  | Q14950139 | 54424064 |  |
| 115551 | Greene, James F. | Greene, Myles (Office of Iranian Affairs) | 1 | 1 |  |  | 46427952 |  |
| 105580 | Harris, David | Harris, Don (NBC correspondent) | 1 | 1 |  | Q5292750 |  |  |
| 112785 | Southwell, Charles A.P. | Southwell, Paul (Premier of St. Kitts and Nevis) | 1 | 1 |  | Q2062527 |  |  |
| 114659 | Wilson, Charles Erwin | Wilson, Charles (Charlie), Representative from Texas | 1 | 1 |  | Q615453 |  |  |
| 101212 | Berger, Samuel David | Berger, Samuel R. (Policy Planning Staff) | 1 | 1 | 101213 |  |  |  |
| 106247 | Hughes, John Chambers | Hughes, (Robert) John (registry 106238, which has no FRUS anchor), Assistant Secretary for Public Affairs, 1982-1985 | 1 | 1 |  | Q112942102 | 73923391 | withheld |
| 113613 | Todd, Joseph A. | Todd, James C. (Bureau of Economic and Business Affairs) | 1 | 1 |  |  | 69329453 | withheld |
| 116109 | Sherman, C. D. | Sherman, Linda (Office of Oceans and Polar Affairs) | 1 | 1 |  | Q42403205 | 218635106 | withheld |
| 116183 | Taylor, James H. | Taylor, James E. (Operations Center) | 1 | 1 |  | Q6135927 |  | withheld |
| 106007 | Hoffman, Johannes | Hoffman, John (Shearman & Sterling) | 1 | 0 |  | Q16196063 | 109857298 |  |
| 107525 | Kyle, Joseph B. | Kyle, James, Colonel, USAF (Desert One) | 1 | 0 |  | Q6137499 | 31577767 |  |
| 109156 | Miller, G. William | Miller, William G. (Senate intelligence committee staff; emissary to Iran) | 1 | 0 |  | Q102137191 | 57347785 | withheld |
| 113288 | Tabatabai, Seyid Zia-ed-din | Tabatabai, Sadegh (Iranian emissary) | 1 | 0 |  | Q1797752 | 88171973805518030648 |  |
| 114410 | Welch, Leo | Welch, Larry D. (Chief of Staff of the Air Force) | 1 | 0 |  | Q1806043 | 249780778 | withheld |
| 106246 | Hughes, James D. | Hughes, James (hostage in Tehran, released November 1979) | 1 | 2 |  |  | 73923391 |  |
| 102311 | Castro, Raúl | Castro, Raul Hector (registry 102312), U.S. Ambassador to Argentina | 1 | 14 | 102312 |  |  |  |
| 108262 | Macdonald, Donald | MacDonald, Donald G. (AID; registry 108264) and MacDonald, Donald S. (INR) | 2 | 1 |  |  |  |  |
| 109500 | Mueller, Richard B. | Mueller, Richard (Department of State, Office of the Executive Secretary) | 1 | 2 |  |  |  |  |
| 111889 | Sanders, Edward | Sanders, Edward G. (Office of Management and Budget; registry 111890) | 2 | 5 | 111890 |  |  |  |
| 114233 | Walsh, John | Walsh, John P. (Deputy Executive Secretary; registry 114234) | 1 | 1 | 114234 |  |  |  |
| 115548 | Graham, John | Graham, John S. (Atomic Energy Commissioner; registry 105093) | 1 | 0 | 105093 |  |  |  |
| 115397 | Donovan, James | Donovan, James B. (New York lawyer; registry 103588) | 1 | 28 | 103588 |  |  |  |

## 4. Read and left: 134 records

Each is one person under two spellings, and each was read as §1 says. *Mentions* is A4's count for the flagged
anchors. Three kinds needed more than the two entries side by side: a registry name with a misprinted initial
(Barbara M. White is the registry's *White, Barbara P.*; Richard N. Perle its *Perle, Richard S.*, from a volume's
misprint), a later post under an earlier name (*Rogers, William "Bill"*, co-leader of the 1981 mission to El
Salvador, is William D. Rogers), and a mention after death, which a persons list makes of a president or a
Secretary of State.


| People-id | Record | The anchors' own names | Mentions | Why left |
|---|---|---|---:|---|
| 100473 | Andropov, Yuriy Vladimirovich | Andropov, Yuri / Andropov, Yuri V. / Andropov, Yury | 177 | the same name, spelled or transliterated otherwise |
| 114985 | Zahedi, Fazollah | Zahedi, Major General Fazlollah | 136 | the same name, spelled or transliterated otherwise |
| 102547 | Christopher, Warren Minor | Christopher, Warren “Chris” | 116 | the same person, by a nickname, a short form or a title |
| 115044 | Zia-ul-Haq, Mohammed | Zia-ul-Haq, Muhammad | 102 | the same name, spelled or transliterated otherwise |
| 112894 | Stalin, Joseph | Stalin, Iosif Vissarionovich | 89 | the same name, spelled or transliterated otherwise |
| 107127 | Khrushchev, Nikita Sergeyevich | Khrushchev, Nikita Sergeivich | 78 | the same name, spelled or transliterated otherwise |
| 109881 | Nixon, Patricia | Nixon, Pat | 78 | the same person, by a nickname, a short form or a title |
| 111696 | Royo, Aristide | Royo, Aristides | 66 | the same name, spelled or transliterated otherwise |
| 100520 | Arafat, Yasir | Arafat, Yasser / Arafat, Yassir | 63 | the same name, spelled or transliterated otherwise |
| 107516 | Kuznetsov, Vasily V. | Kuznetsov, Vasili Vasilievich / Kuznetsov, Vasiliy V. | 58 | the same name, spelled or transliterated otherwise |
| 103774 | Eagleburger, Lawrence Sidney | Eagleburger, Lawrence (Larry) | 55 | the same person, by a nickname, a short form or a title |
| 106896 | Karpov, Victor P. | Karpov, Viktor | 53 | one person, Victor P. Karpov, the Soviet arms negotiator |
| 110565 | Perle, Richard S. | Perle, Richard N. | 53 | one person, Richard N. Perle: the registry's own record holds 1981-1988 vol. XIII's "Perle, Richard N."; 1969-1976 vol. XVI's "S." is the misprint |
| 103539 | Dobrynin, Anatoly F. | Dobrynin, Anatoli F. / Dobrynin, Anatoliy / Dobrynin, Anatoliy F. | 47 | the same name, spelled or transliterated otherwise |
| 104949 | Glitman, Maynard Wayne | Glitman, Maynard (Mike) / Glitman, Maynard “Mike,” | 45 | the same person, by a nickname, a short form or a title |
| 113008 | Stewart, Charles Allen | Stewart, C. Allan | 39 | the same person, by a nickname, a short form or a title |
| 107025 | Kennedy, John F. | Kennedy, John F. | 38 | the same person, mentioned after his death |
| 114492 | White, Barbara P. | White, Barbara M. | 38 | one person, Barbara McClure White: USIA 1966-1971, then Alternate U.S. Representative to the United Nations with ambassador's rank (Q4859117); the registry's "P." is a misprint |
| 100789 | Bakhtiar, Shapour | Bakhtiar, Shahpur | 32 | the same name, spelled or transliterated otherwise |
| 113781 | Tsarapkin, Semyen Konstantinovich | Tsarapkin, Semen K. / Tsarapkin, Semen Konstantinovich | 32 | the same name, spelled or transliterated otherwise |
| 113758 | Trudeau, Pierre-Elliott | Trudeau, Pierre / Trudeau, Pierre Elliot | 30 | the same name, spelled or transliterated otherwise |
| 115161 | Baldrige, Malcolm (“Mac”) H., Jr. | Baldrige, H. Malcolm, Jr. (Mac) / Baldrige, H. Malcolm, Jr., (Mac) | 27 | the same person, by a nickname, a short form or a title |
| 107395 | Kosygin, Aleksei N. | Kosygin, Aleksey / Kosygin, Aleksey N. / Kosygin, Alexei / Kosygin, Alexei N. | 25 | the same name, spelled or transliterated otherwise |
| 113905 | Ustinov, Dmitriy F. | Ustinov, Dmitri / Ustinov, Dmitri F. | 24 | the same name, spelled or transliterated otherwise |
| 102443 | Cheek, James Richard | Cheek, James “Jim” | 23 | the same person, by a nickname, a short form or a title |
| 106929 | Katzenbach, Nicholas deBelleville | Katzenbach, Nicholas deB. | 23 | the same person, by a nickname, a short form or a title |
| 103887 | Eisenhower, Dwight D. | Eisenhower, Dwight D. | 22 | the same person, mentioned after his death |
| 112957 | Steiner, Steven E. | Steiner, Steven R. | 22 | one person, Steven E. Steiner (VIAF 316559679, born 1940): the Operations Center officer of 1975, the NSC arms-control director of 1987-1988 and the Special Verification Commission representative; 1981-1988 vol. XLIV's "R." is a misprint |
| 111165 | Raphel, Arnold Lewis | Raphel, Arnold “Arnie,” | 21 | the same person, by a nickname, a short form or a title |
| 104763 | Gates, Robert M. | Gates, Robert (Bob) / Gates, Robert S. / Gates, Robert “Bob | 18 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 105177 | Gregg, Donald Phinney | Gregg, Donald “Don,” | 18 | the same person, by a nickname, a short form or a title |
| 106391 | Inderfurth, Karl Frederick (“Rick”) | Inderfurth, Karl “Rick”, F. | 16 | the same person, by a nickname, a short form or a title |
| 101633 | Bowles, Chester Bliss | Bowles, Chester A. | 13 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 103998 | Entezam, Abdullah | Entezam, Abdollah | 12 | the same name, spelled or transliterated otherwise |
| 109291 | Mondale, Walter F. (“Fritz”) | Mondale, Walter S. | 12 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 110121 | Orlov, Yuriy | Orlov, Yuri | 12 | the same name, spelled or transliterated otherwise |
| 111561 | Romulo, Carlos P. | Romulo, Carlos F. | 12 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 111683 | Rowen, Henry S. | Rowen, Henry “Harry,” | 12 | the same person, by a nickname, a short form or a title |
| 113367 | Taraki, Nur Muhammad | Taraki, Nur Mohammed | 11 | the same name, spelled or transliterated otherwise |
| 101227 | Berle, Adolf Augustus, Jr. | Berle, Adolph A. | 10 | the same name, spelled or transliterated otherwise |
| 105787 | Helms, Jesse R. | Helms, Jesse A. | 10 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 108064 | Lodge, Henry Cabot, II | Lodge, Henry Cabot, Jr. | 10 | one man: Jr. and II |
| 104254 | Figueiredo, Joao Baptista de Oliveira | Figueiredo, Joao Batista | 9 | the same name, spelled or transliterated otherwise |
| 111529 | Rogers, William Dill | Rogers, William “Bill” | 9 | one person: the "former Under Secretary" co-leading the 1981 mission to El Salvador is William D. Rogers |
| 103869 | Ehrlich, Simha | Ehrlich, Simcha | 8 | the same name, spelled or transliterated otherwise |
| 107421 | Kramer, Frank | Kramer, Franklin D. | 8 | the same person, by a nickname, a short form or a title |
| 115840 | McMahon, John N. | McMahon, John D. | 8 | one person: "Deputy Director for Operations, CIA, from January 11, 1978" is John N. McMahon |
| 111579 | Roosevelt, Franklin D. | Roosevelt, Franklin D. / Roosevelt, Franklin Delano | 8 | the same person, mentioned after his death |
| 107668 | Laraki, Ahmad | Laraki, Ahmed | 7 | the same name, spelled or transliterated otherwise |
| 108548 | Marshall, George Catlett | Marshall, George C. | 7 | the same person, mentioned after his death |
| 102235 | Carrington, Peter Alexander | Carrington, Right Honorable Lord (Peter) | 6 | the same person, by a nickname, a short form or a title |
| 103617 | Douglas-Home, Alexander Frederick | Douglas-Home, Sir Alec | 6 | the same person, by a nickname, a short form or a title |
| 109966 | Nunn, Samuel (Sam) Augustus | Nunn, Samuel A. “Sam,” | 6 | the same person, by a nickname, a short form or a title |
| 100070 | Acheson, Dean Gooderham | Acheson, Dean G. | 5 | the same person, mentioned after his death |
| 100414 | Andersen, Knud Borge | Andersen, Knud Børge | 5 | the same name, spelled or transliterated otherwise |
| 100529 | Arbatov, Georgi A. | Arbatov, Georgiy | 5 | the same name, spelled or transliterated otherwise |
| 103244 | Deal, Timothy | Deal, Tim | 5 | the same person, by a nickname, a short form or a title |
| 103703 | Dulles, John Foster | Dulles, John Foster | 5 | the same person, mentioned after his death |
| 105222 | Gromyko, Andreĭ Andreevich | Gromyko, Andrey Andreyevich | 5 | the same name, spelled or transliterated otherwise |
| 106268 | Hull, Cordell | Hull, Cordell | 5 | the same person, mentioned after his death |
| 108115 | López Mateos, Adolfo | López Mateos, Alfonso | 5 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 109484 | Moyers, William D. (Bill) | Moyers, Bill D. | 5 | the same person, by a nickname, a short form or a title |
| 109994 | Oberdorfer, Donald, Jr. | Oberdorfer, Don | 5 | the same person, by a nickname, a short form or a title |
| 111037 | Quainton, Anthony Cecil Eden | Quainton, Anthony “Tony” | 5 | the same person, by a nickname, a short form or a title |
| 114691 | Wilson, Woodrow | Wilson, Woodrow | 5 | the same person, mentioned after his death |
| 100922 | Barre, Mohammed Siad | Barre, Mohamed Siad | 4 | the same name, spelled or transliterated otherwise |
| 101261 | Bessmertnykh, Aleksandr A. | Bessmertnykh, Alexander A. | 4 | the same name, spelled or transliterated otherwise |
| 102045 | Byrd, Robert C. | Byrd, Robert W. | 4 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 102261 | Carter, William Hodding, III | Carter, J. Hodding, III | 4 | the same person, by a nickname, a short form or a title |
| 115590 | Hayward, Thomas B. | Hayward, Thomas D. | 4 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 109657 | Nasser, Gamal Abdel | Nasser, Gamel Abdel | 4 | the same name, spelled or transliterated otherwise |
| 110255 | Paarlberg, Donald | Paarlberg, Don | 4 | the same person, by a nickname, a short form or a title |
| 110290 | Pahlavi, Mohammad Reza | Pahlavi, Mohammed Reza | 4 | the same name, spelled or transliterated otherwise |
| 100745 | Badran, Mudar | Badran, Muhdar | 3 | the same name, spelled or transliterated otherwise |
| 103062 | Curran, Robert Theodore | Curran, Robert “Tad,” | 3 | the same person, by a nickname, a short form or a title |
| 115359 | Darman, Richard G. | Darman, Richard “Dick,” | 3 | the same person, by a nickname, a short form or a title |
| 103894 | Eizenstat, Stuart E. | Eizenstat, Stuart L. | 3 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 106664 | Johnson, Lyndon Baines | Johnson, Lyndon Baines | 3 | the same person, mentioned after his death |
| 107145 | Kikhya (Kikhia), Mansuur | Kikhya, Mansour | 3 | the same name, spelled or transliterated otherwise |
| 107438 | Kreisberg, Paul H. | Kreisberg, Paul (Dusty) | 3 | the same person, by a nickname, a short form or a title |
| 107469 | Krueger, Robert C. | Krueger, C. Robert | 3 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 107593 | Lamb, Denis | Lamb, Dennis | 3 | the same name, spelled or transliterated otherwise |
| 109576 | Murrow, Edward R. | Murrow, Edward R. | 3 | the same person, mentioned after his death |
| 112309 | Sharp, Mitchell W. | Sharp, Mitchel | 3 | the same name, spelled or transliterated otherwise |
| 114307 | Washburn, Abbott M. | Washburn, Abbot | 3 | the same name, spelled or transliterated otherwise |
| 100057 | Abrams, Elliott | Abrams, Elliot | 2 | the same name, spelled or transliterated otherwise |
| 101577 | Boster, Davis Eugene | Boster, David E. | 2 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 102021 | Butler, Richard (“Rab”) Austen | Butler, Richard A. (RAB) | 2 | the same person, by a nickname, a short form or a title |
| 105469 | Hammadi, Saadun | Hammadi, Saddoun | 2 | the same name, spelled or transliterated otherwise |
| 105742 | Heavner, Theodore J.C. | Heavner, Theodore “Ted” | 2 | the same person, by a nickname, a short form or a title |
| 106029 | Holifield, Chester E. | Holifield, Chet | 2 | the same person, by a nickname, a short form or a title |
| 108189 | Luers, William Henry | Luers, William “Bill,” | 2 | the same person, by a nickname, a short form or a title |
| 111145 | Randall, Clarence B. | Randall, Clarence S. | 2 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 111216 | Read, Benjamin Huger | Read, Benjamin M. | 2 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 111646 | Rostow, Eugene Victor Debs | Rostow, Eugene V. (Gene) / Rostow, Eugene V. “Gene,” | 2 | the same person, by a nickname, a short form or a title |
| 113096 | Strauss, Franz Josef | Strauss, Franz-Josef | 2 | the same name, spelled or transliterated otherwise |
| 113592 | Timmons, William E. | Timmons, William “Bill,” | 2 | the same person, by a nickname, a short form or a title |
| 100055 | Abramowitz, Morton Isaac | Abramowitz, Morton “Mort,” | 1 | the same person, by a nickname, a short form or a title |
| 101863 | Bryan, William Jennings | Bryan, William Jennings | 1 | the same person, mentioned after his death |
| 101983 | Burrows, Bernard A.B. | Burrows, Bernard B.A. | 1 | the same name, spelled or transliterated otherwise |
| 102075 | Caetano, Marcelo Jose das Neves Alves | Caetano, Marcello | 1 | the same name, spelled or transliterated otherwise |
| 102748 | Colombo, Emilio | Colombo, Emilion | 1 | the same name, spelled or transliterated otherwise |
| 103559 | Dole, Robert Joseph | Dole, Robert “Bob,” | 1 | the same person, by a nickname, a short form or a title |
| 103612 | Douglas, James H., II | Douglas, James H., Jr. | 1 | one man: Jr. and II |
| 104468 | Fowler, Henry H. | Fowler, Henry R. | 1 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 105074 | Goulart, João Belchior Marques | Goulart, Jaoa | 1 | the same name, spelled or transliterated otherwise |
| 105709 | Haya de la Torre, Raúl Víctor | Haya de la Torre, Victor Raul | 1 | the same name, spelled or transliterated otherwise |
| 106332 | Hutcheson, Richard G., III | Hutcheson, Richard “Rick”, III | 1 | the same person, by a nickname, a short form or a title |
| 106346 | Hyland, William G. | Hyland, William P. | 1 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 106529 | Jamieson, Donald | Jamieson, Don | 1 | the same person, by a nickname, a short form or a title |
| 107289 | Klutznick, Philip M. | Klutznick, Philip H. | 1 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 108414 | Malinovsky, Rodion Yakovlevich | Malinovsky, Rodion Ya | 1 | the same person, by a nickname, a short form or a title |
| 108945 | McNeil, Francis J. | McNeil, Frank | 1 | the same person, by a nickname, a short form or a title |
| 108995 | Mein, John Gordon | Mein, John Gordon | 1 | the same person, mentioned after his death |
| 109285 | Molotov, Vyacheslav Mikhailovich | Molotov, Viacheslav Mikhailovich | 1 | the same name, spelled or transliterated otherwise |
| 115929 | North, Oliver L. | North, Oliver “Ollie | 1 | the same person, by a nickname, a short form or a title |
| 110307 | Palme, Olof | Palme, Olaf | 1 | the same name, spelled or transliterated otherwise |
| 111936 | Sarbanes, Paul Spyros | Sarbanes, Paul Spiros | 1 | the same name, spelled or transliterated otherwise |
| 114400 | Weiss, Seymour W. | Weiss, Seymour (Sey) | 1 | the same person, by a nickname, a short form or a title |
| 114726 | Wise, Phillip J., Jr. | Wise, Phillip M., Jr. | 1 | the same person: an initial or given name misprinted in a volume or the registry, the roles agreeing |
| 114857 | Yahya Khan, Agha Mohammad | Yahya Khan, Agha Mohammed | 1 | the same name, spelled or transliterated otherwise |
| 100188 | Alam, Asadollah | Alam, Assadollah | 0 | the same name, spelled or transliterated otherwise |
| 101911 | Bulganin, Nikolai Aleksandrovich | Bulganin, Nikolai Alekandrovich | 0 | the same name, spelled or transliterated otherwise |
| 103675 | Dubs, Adolph (“Spike”) | Dubs, Adolph H. | 0 | the same person, by a nickname, a short form or a title |
| 103785 | Earman, John S. | Earman, S.J. | 0 | the same person, by a nickname, a short form or a title |
| 106373 | Iklé, Fred Charles | Iklé, Frederick C. | 0 | the same person, by a nickname, a short form or a title |
| 106983 | Kekkonen, Urho K. | Kekkonen, Uhro | 0 | the same name, spelled or transliterated otherwise |
| 108410 | Malik, Yakov Aleksandrovich | Malik, Yakov Alexandrovich | 0 | the same name, spelled or transliterated otherwise |
| 115910 | Nance, James W. (“Bud”) | Nance, James “Bud” W. | 0 | the same person, by a nickname, a short form or a title |
| 109941 | Novak, Robert D.S. | Novak, Robert D. “Bob,” | 0 | the same person, by a nickname, a short form or a title |
| 111376 | Ridgway, Rozanne Lejeanne | Ridgway, Rozanne “Roz,” | 0 | the same person, by a nickname, a short form or a title |
| 112134 | Schwebel, Stephen M. | Schwebel, Steven | 0 | the same name, spelled or transliterated otherwise |
| 112137 | Schweitzer, Pierre-Paul | Schweitzer, Pierre-P. | 0 | the same person, by a nickname, a short form or a title |
| 114414 | Well, Günther van | Van Well, Gunter | 0 | the same name, spelled or transliterated otherwise |

## 5. What the bundle and a full library show

- **The control.** The base's generator (`64fb3923`) with the shipped file's own `GENERATED_DATE=2026-10-16`
  reproduced `person-authority-index.json` byte for byte (SHA-256 `971a4c3d…`).
- **The corrected file**, against the control, entry by entry: 108 crosswalk anchors move (56,102 → 56,029), 35
  to the right person's registry record and 73 to none, every one a listed anchor; 54 Wikidata ids (3,823 →
  3,769), 45 VIAF ids (3,197 → 3,152) and 24 role texts (12,811 → 12,787) leave records not theirs, John T.
  Hughes's among them, the John Hughes entry's second people-id; nothing else changes, and nothing is replaced,
  only removed or joined. The run prints 217 registry disagreements where it printed 256: the 37 registry anchors
  of the other person that corrections list, and the two anchors two overlay entries claimed (Richard V. Allen's
  vol. I and William H. Taft IV's vol. V). One printed line is still not the registry's: 1981-1988 vol. VI's
  Richard Combs, which two overlay entries claim for two Combs records (115327 and 102756), likely one man held
  twice. 2,532,807 bytes.
- **POCOM is not owed**: no slug moved, and `POCOMIndexGenerator` at pocom `ccc1f033` gives `pocom-index.json`
  byte for byte against the old file and the new.
- **A full library.** A4's clone of the pinned iPhone 17e (`8BE32D39`: 553 volumes at index v69, 63,667 members,
  the v11 rollup), copied twice, and its rollup rebuilt through the kit's own `consolidatePersonRollup` with each
  file (a throwaway package test, not committed; 13.6 s a rebuild, debug). The rebuild with the shipped file
  reproduced the library's stored rollup member for member, numbered alike. With the corrected file **104 members
  change person** and the rollups go from 17,956 to 18,009: 35 join the right person's registry record through the
  crosswalk, 60 a person of their own, and 9 move by name in the clusterer, 8 of them to the right person (two of
  Richard V. Allen's "Dick" entries, two of Thomas W. Simons's, Alison Rosenberg's vol. XXXVIII entry) and one,
  Myles Greene of the Office of Iranian Affairs, from James F. Greene to Colonel M.J.L. Greene of 1962, neither
  his. In People: Richard V. Allen 49 → 138 mentions and Richard F. Allen 98 → 9; Romulo Betancourt 65 → 118 and
  Ernesto Betancourt 88 → 35.
- **Held apart and still where it was: 9 members**, all of people with no record in the bundle, whom the
  clusterer joins by name to the keyed person: Adlai E. Stevenson III (1977-1980 vol. XXIII, under his father,
  whose registry record holds ten of his anchors), Hamilton Fish III (1933-1939) and IV (1977-1980 vol. XI Part 1,
  under the Secretary of State, whose registry record holds one of IV's), Frank Murphy (1933-1939, under Franklin
  D. Murphy), Richard J. Davis (under Richard H. Davis), Charlie Wilson (under Charles E. Wilson, whose registry
  record holds one of his), John Hughes of 1982-1985 (under John C. Hughes), William G. Miller (under G. William
  Miller, whose registry record holds one of his) and the hostage James Hughes (under James D. Hughes). Their
  authority data is right now; the rollup still merges them.

## 6. What is still wrong, and not fixed here

### 6.1 The overlay's Wikidata ids name someone else far beyond these entries

Every Wikidata id in the corrected bundle (3,769 records) read back from Wikidata and tested roughly: the item's
label or aliases share no word of the record's surname; or its person was born after the record's first FRUS
volume, or fewer than 15 years before it; or died more than 40 years before it (the Public Diplomacy volumes,
titled 1917-1972, left out of the years). **540 records fail one test.** Of 40 drawn at random and read, 34 are
plainly someone else: Kinnaird R. McKee wears Jeremiah Denton's id, George W. Romney the eighteenth-century
painter's, Antonio de Oliveira Salazar a Salazar who died in 1897, Andrei Grechko a man born in 1975; and John F.
Kennedy's record wears John N. Kennedy's, the Louisiana senator born in 1951. Four were the right person under
another spelling or with no English label read (Dick Cheney, Americo Tomas), and two could not be told. So about
450 of the bundle's Wikidata links, and more the tests cannot see, open someone else's page from the person sheet.
VIAF was not sized. A correction can withhold an id, but at this scale the owner may prefer a rule in the
generator (accept the overlay's id only when the item's name and years fit the record).

**Since #1767's lane B (2026-10-29) the generator has that rule**: the identifier assessment's (b4), measured in `Planning/Person-Authority-Identifier-Assessment-2026-10-17.md` and built over a committed Wikidata snapshot. The bundle keeps 1,859 of the 3,769 Wikidata ids and 1,468 of the overlay's 3,010 VIAF ids; John F. Kennedy's and McKee's wrong ids are withheld.

### 6.2 An entry carrying several people-ids gives one person's role text and identifiers to all of them

31 overlay entries carry two or more people-ids the registry knows. The enrichment stamps the entry's role text
and identifiers on every one, so where the ids are different people the others wear the first's: Raul H. Castro,
the U.S. ambassador, reads *Commander in Chief of the Cuban Armed Forces* with Raul Castro Ruz's Wikidata id; four
Donald MacDonalds (a Canadian minister, an NSC staff member, an AID administrator, a Korea desk officer) all read
*Canadian Minister of Finance from 1975*; Prince Carl Bernadotte Senior reads his son's *nephew of the King of
Sweden*; John S. Graham of the Atomic Energy Commission reads *Non-career appointee. Secretary of State ad
interim*, the John Graham of 1817. At least 12 of the 31 carry different people's ids (Castro, MacDonald, Bernadotte,
Mueller, Graham, two Donovans, Sanders, Walsh, Hughes, Simmons, Peterson); the rest are one person the registry
holds twice. A correction holds apart from every id of an entry, so it cannot divide this: it needs a rule that
says which id an entry's enrichment is for.

**Since #1767's lane B (2026-10-29)** an entry's role text goes only to the ids whose own registry remarks hold it, and its identifiers are tested against each record: Raul H. Castro and three of the four Donald MacDonalds read no other man's role, and Raul H. Castro wears no Wikidata id.

### 6.3 The registry's own merges, which win by design

The registry is never overridden, and it merges some people itself: 113000 (Adlai E. Stevenson II) holds ten of
his son's anchors as Senator, 1969-1980; 114659 (Charles Erwin Wilson, Secretary of Defense) holds Charles Edward
Wilson's (Director of Defense Mobilization) and Representative Charlie Wilson's 1977-1980 vol. II anchor; 104298
(Hamilton Fish, 1808-1893) has the Secretary of State's years beside Hamilton Fish IV's only anchor; 109156 (G.
William Miller) holds William G. Miller's 1969-1976 vol. XXXVIII Part 2 anchor; 102311 (Raul Castro Ruz) holds Raul
H. Castro's 1977-1980 vol. XXVI anchor. They are `HistoryAtState/people`'s to fix upstream.

### 6.4 What the clusterer does with an uncovered member

§5's nine held-apart members, and Myles Greene, are placed by name, and a name block's first reconciled
component wins (#1658's tie, fixed and not decided). How Richard V. Allen's entries reached Richard F. Allen
without a join, read in `PersonClusterer`: an uncovered member merges with a covered one whose given names fit
(*Richard* fits *Richard V.*) when their eras sit within `eraGapYears`, 30 years, and their roles share a word of
four letters or more. 1952-1954 vol. VIII's *Allen, Richard* (1951-1952, Richard F.'s by the registry) is 29
years from *Allen, Richard V.* of 1981-1982, both roles name *security*, and it comes first in the key order, so
it took the 1981-1988 entries and the cannot-link kept them from Richard V. Allen's own record. A join fixes it where the other person has a record in the
bundle; for the rest, a record upstream or #1658's other option (leave such a member on its own, both pairs
recorded as candidates) would.

## 7. Redoing it

The tools were scratch Python, not committed: a report per record (the anchor's TEI entry, the registry record,
every overlay entry carrying the id), a decision table with each row's reason, a builder that checks every listed
anchor, identifier and role text against the overlay before writing the JSON (the generator checks again), and a
census over copies of a full library. The generator's own refusals are the guard against drift: a correction that
no longer fits the registry or the overlay stops the run.
