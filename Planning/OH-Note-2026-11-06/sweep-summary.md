# Items 1 and 5 of the note, swept over the 553 volumes (2026-11-06)

**For the owner, not for the Office.** `../OH-Note-2026-11-06.md` found two error classes in `frus1870` alone: items 1 and 5 of its Part A, by `check.py` §4. This sweep looks for both in every volume FRUS Explorer lists.

The note is the owner's draft and is not edited here. §4 says what its items 1 and 5 should add. Nothing has been posted anywhere.

The files beside this one:

- [`sweep.py`](sweep.py): the script, stdlib only. Its header states both rules.
- [`sweep.out`](sweep.out): its output, from one run.
- [`papers-filed-inside.csv`](papers-filed-inside.csv): item 1, one row per candidate, with its mark and its reading (208 rows).
- [`receipt-month-dates.csv`](receipt-month-dates.csv): item 5, likewise (26 rows).

## 1. How it was measured

- **One run** of `sweep.py`, through `Scripts/heavy.sh` with `python3 -I`, about a minute. It reads the 553 volumes that are `Planning/editors-annotations/inventory.json`'s keys.
- **Corpus `6170e4b32`.** Every line number is relative to it. `volumes/` and `schema/` are unchanged from there to `master` at `216cdb764`, which the run checks.
- **The controls are the note's own findings.**
  - Item 1: the run finds `frus1870`'s Nos. 216, 284 and 303 at the note's head lines, and nothing else in that volume.
  - Item 5: it finds the note's 16 dates of receipt at the note's 16 lines.

  The run exits with an error when either fails.
- **Every candidate was read in the file before it was marked:**
  - its List of Papers row;
  - the paper it sits in;
  - the attachment's head and dateline;
  - where anything was unclear, the XML around it.

  The verdicts are in the script (`READINGS_1`, `READINGS_5`). The run exits with an error when a candidate has no verdict or a verdict no candidate. The marks follow the note's: **confirmed** when the file itself settles it, **question** when only the Office can say what was meant.
- **No printed page was read.** Each question says what the page would settle.

## 2. Item 1: a paper the List of Papers prints that the file holds only inside an earlier paper

### The rule

1. **Every List of Papers is read, however it is encoded.**
   - Read literally, the brief's rule (a `subtype="table-of-contents"` division whose rows open with a number) finds the lists of only 2 of the 62 volumes of 1861–1898: `frus1870` and `frus1871`.
   - Most lists are a `section` with `subtype="index"` and `xml:id="papers"`. Others are `toc-papers`, `papers1` or `type="toc"`.
   - The run takes every division outside the documents whose head reads "List of papers", "Papers relating to foreign affairs", "Contents" or "Table of contents", and whose own tables hold five or more rows that end in a page number. That is 167 lists in 161 volumes.
   - `frus1875v01`'s list also serves `frus1875v02`, which has none.
2. **Each row is matched to the document that begins on its page and gives its day.** In order, the matcher:
   1. lets a numbered row claim the document whose opener prints its number;
   2. lets a row claim the document whose head shares the names in its writer cell;
   3. matches on page and day alone;
   4. matches on page where one side has no day;
   5. matches on day with the page either side.

   In 1861–1898, 26,563 of 27,879 rows find their document.
3. **A row left over whose day is that of a `frus:attachment` on its page is a candidate only when the attachment is dated after the paper it sits in.**
   - An inclosure cannot postdate its covering paper.
   - Some lists give their inclosures rows, notably those of the 1860s, of 1898 and of 1914–1918. Such rows meet an attachment not shown to be later: of the same day, earlier, or with no date to compare. They are counted, not reported: 79 rows in 1861–1898 and 84 after.
4. **An attachment's date inferred from outside the paper is set aside** (`@ana` "…inferred-from-sibling-dates" and the like). A blank form dated from its covering note would otherwise look later than the note.

### What it found

**208 candidates in 49 volumes.** All were read:

| | Candidates | Confirmed | Question | Not this class |
|---|---:|---:|---:|---:|
| 1861–1898 | 102 | 101 | 0 | 1 |
| 1899–1932 | 106 | 95 | 8 | 3 |
| **all** | **208** | **196** | **8** | **4** |

**The 196 confirmed papers are in 44 volumes.** 101 are in 22 volumes of 1861–1898, and `frus1870`'s three are among them. The rest:
- 1899–1913: 33, in 12 volumes;
- 1914–1919: 61, in 9;
- 1932: `frus1932v02`, one.

No List of Papers of 1920–1931, or of 1933–1945, yields a confirmed one.

The table gives, for each volume:
- how many are confirmed;
- the earliest document in the file that one sits in;
- the documents after that one, which a division of its own for the paper renumbers.

| Volume | Papers | Earliest inside | Documents after it |
|---|---:|---|---:|
| `frus1862` | 4 | `d213` (line 32210) | 507 |
| `frus1863p1` | 3 | `d27` (line 16821) | 668 |
| `frus1863p2` | 1 | `d224` (line 25265) | 417 |
| `frus1864p1` | 1 | `d81` (line 22518) | 317 |
| `frus1864p3` | 1 | `d497` (line 51658) | 32 |
| `frus1865p2` | 3 | `d396` (line 33863) | 279 |
| `frus1865p3` | 2 | `d427` (line 50286) | 339 |
| `frus1866p1` | 7 | `d27` (line 14231) | 489 |
| `frus1866p2` | 2 | `d49` (line 14777) | 509 |
| `frus1866p3` | 5 | `d2` (line 6637) | 221 |
| `frus1867p1` | 2 | `d131` (line 22047) | 509 |
| `frus1867p2` | 9 | `d221` (line 41162) | 294 |
| `frus1868p1` | 1 | `d125` (line 40880) | 274 |
| `frus1868p2` | 9 | `d23` (line 15727) | 645 |
| `frus1870` | 3 | `d215` (line 27794) | 85 |
| `frus1871` | 1 | `d172` (line 43386) | 264 |
| `frus1872p2v5` | 1 | `d72` (line 13019) | 91 |
| `frus1889` | 4 | `d85` (line 19744) | 265 |
| `frus1893` | 1 | `d380` (line 41519) | 318 |
| `frus1895p2` | 6 | `d221` (line 35671) | 546 |
| `frus1896` | 2 | `d174` (line 33911) | 723 |
| `frus1898` | 33 | `d614` (line 82632) | 580 |
| `frus1899` | 2 | `d608` (line 58807) | 202 |
| `frus1900` | 4 | `d80` (line 24282) | 995 |
| `frus1901` | 1 | `d326` (line 38611) | 211 |
| `frus1902` | 6 | `d800` (line 84824) | 228 |
| `frus1904` | 1 | `d727` (line 69529) | 222 |
| `frus1905` | 2 | `d415` (line 59013) | 721 |
| `frus1906p1` | 5 | `d53` (line 20515) | 685 |
| `frus1906p2` | 3 | `d594` (line 66769) | 18 |
| `frus1910` | 1 | `d689` (line 65180) | 271 |
| `frus1911` | 4 | `d16` (line 17108) | 1,062 |
| `frus1912` | 3 | `d5` (line 31770) | 1,855 |
| `frus1913` | 1 | `d1611` (line 133066) | 98 |
| `frus1914` | 3 | `d166` (line 44328) | 1,699 |
| `frus1914Supp` | 18 | `d420` (line 66453) | 926 |
| `frus1915Supp` | 2 | `d1104` (line 122673) | 423 |
| `frus1916` | 3 | `d323` (line 46053) | 1,003 |
| `frus1916Supp` | 1 | `d905` (line 104761) | 411 |
| `frus1918` | 27 | `d12` (line 18933) | 721 |
| `frus1919Parisv11` | 4 | `d187` (line 33125) | 222 |
| `frus1919Russia` | 1 | `d416` (line 40850) | 502 |
| `frus1919v01` | 2 | `d778` (line 61099) | 137 |
| `frus1932v02` | 1 | `d52` (line 17466) | 558 |

### What the confirmed papers are

Three shapes cover them.

- **A later despatch, reply, memorandum, message or treaty filed inside the paper before it, 1862–1932.** Each has a head and a dateline of its own, and often its own despatch number. Examples:
  - `frus1862`: Mr. Cameron's despatch No. 2 of June 26, 1862, from St. Petersburg, inside Mr. Seward's instruction of February 4 to Mr. Clay (head at line 45896);
  - `frus1863p1`: Mr. Seward's reply of May 19, 1863 inside the note of May 18 from Lord Lyons that it answers (line 58927);
  - `frus1866p1`: Mr. Hunter's instruction No. 1868 of October 30, 1866 inside Mr. Moran's despatch of October 27 (line 31369).
- **A run of papers filed inside the first of them.** In `frus1898`:
  - `d1190a`, the Department's circular of April 15, 1898, holds 13 later circulars, of April 18 to August 18, each with its own row;
  - `d1190b` holds 6 more, of July 15 to December 30.
- **#25's own two mechanisms, in volumes #25 did not name.**
  - A reply with no file number of its own, filed inside the telegram or letter it answers: `frus1914Supp` 18, `frus1918` 27.
  - A memorandum whose source is a footnote to its head: Mr. Lansing's, in `frus1919Parisv11`.
  - #25 named 52 volumes as corrected. Two of them still hold such papers: `frus1915Supp` (2) and `frus1916Supp` (1).

### The questions and the papers not reported

- **Questions (8).** In seven the book seems to print the later paper under the earlier one's own head or source note:
  - one head, "[Telegrams.]", for two telegrams (`frus1911`, `frus1912`);
  - a circular telegram with its variants ("Sent to Puerto Mexico …", `frus1914`);
  - "Appendix I" to "IV" (`frus1907p1`);
  - an exchange of notes printed as Treaty Series No. 619–A (`frus1916`);
  - an armistice whose head's source note covers the conventions after it (`frus1919Parisv02`, twice).

  In the eighth the paper it sits in is dated "Paris, May 1919" with no day (`frus1919Parisv11`). Each has its own row in the list.
- **Not this class (4).** The list's row is the paper it sits in, whose dateline prints no day or another date, and the attachment is that paper's labelled inclosure: `frus1879` `d415`, `frus1903` `d351`, `frus1915Supp` `d1516`, `frus1920v03` `d542`.
- **Numbered rows that met an attachment of the same day or earlier: 5, none an error.**
  - In three the list names the paper by its inclosure: `frus1872p2v2` No. 13, `frus1876` No. 90, `frus1887` No. 316.
  - In two the list's date differs from its paper's: `frus1880` No. 529, `frus1888p1` No. 122.

### What the rule cannot see

- **A volume with no List of Papers.** The rule has nothing to compare there. In 1861–1898 that is `frus1865p4`, `frus1872p2v1`, `frus1872p2v4`, `frus1873p2v3`, `frus1894`, `frus1894app1`, `frus1894app2` and `frus1897`; after 1945, every volume but four.
- **A later paper of the same day as the paper it sits in.** Only a numbered list could show one, and the five such rows are not errors.
- **A paper the list does not name, and an attachment that begins two or more pages from its row's page.**
- **A paper run on inside another's text, with no attachment of its own.** One was found only because it ran on inside an attachment: `frus1915Supp`'s circular of November 1, 1915. It sits inside the British ambassador's Enclosure 2: the enclosure at line 122755, the circular's title at line 122783.

## 3. Item 5: a date whose month is the receipt's

### The rule

A `<date when>` whose own text writes out a month and day that contradict `@when` is set beside the receipt its dateline or opener prints.

- **The class:** `@when` is the printed day in the month of receipt.
- **Two siblings, counted with it:** `@when` is the receipt's own date; `@when` is the printed month and day in the receipt's year.
- **A day the editors correct in brackets ("August 10 [11]") is read both ways,** since `@when` follows either.

### What it found

- **821 dates contradict their `@when`** in the 553 volumes, 312 of them in 1861–1898.
- **19 take their month from the receipt, all confirmed against their List of Papers row:**
  - 16 in `frus1870`, the note's;
  - 3 in `frus1871`, new: `d28`, `d308`, `d350`.

  No other volume has one.
- **A 20th, `frus1919v01` `d264`, is the other way round.** It prints May 23, 1918. Its list gives July 23 and its receipt July 24, so `@when`'s July is right. The CSV marks it not this class; for the Office it is a question about its dateline (§4).
- **None other comes near.** 87 of the 821 print a receipt. Beyond the classes here, 28 have `@when` in the month of their receipt, but every one of them was received in the month it prints.
- **5 take the receipt's year instead:** `frus1881` `d86`, `d87`, `d144`, `d286`, and `frus1891` `d425`. All five are already #469's rows (`OH-Report-2026-10-01/dates.csv`, year contradicts text).
- **1 takes the receipt's whole date (a question):** `frus1949v08` `d1375`, line 84570.

## 4. What items 1 and 5 of Part A should add

### Item 1

**The summary table's row:**

> | 1 | `frus1870` and 43 more volumes | A paper the List of Papers prints is encoded only inside an earlier paper, as a `frus:attachment`: 196 papers in 44 volumes. In `frus1870` (Nos. 216, 284 and 303), each document's `@n` is one or two below its printed number from `d216` on | confirmed |

**A subsection after "Three slips the List of Papers settles":**

> #### The same error in 43 more volumes
>
> **Confirmed.** The same check, run on every List of Papers in the 553 volumes, finds 193 more papers that the file holds only inside an earlier paper, in 43 volumes: 98 in 21 volumes of 1861–1898, and 95 in 22 volumes of 1899–1932. Each:
>
> - has a row of its own in the volume's List of Papers, which no document answers;
> - is a `frus:attachment` of an earlier paper and is dated after it, so it cannot be that paper's inclosure.
>
> [the table in §2 above]
>
> `papers-filed-inside.csv` gives each paper's row, the line of its head, its date and the paper it sits in. Most are a later despatch, reply or memorandum filed inside the paper before it, as in `frus1870`.
>
> - **A run of papers sits inside the first of them.** `frus1898` `d1190a` (line 118385), the circular of April 15, 1898, holds 13 later circulars; `d1190b` holds 6 more.
> - **From 1914 the papers are those #25 described.**
>   - A reply with no file number of its own sits inside the telegram it answers: `frus1914Supp` 18, `frus1918` 27.
>   - A memorandum whose source is a footnote to its head sits inside an unrelated paper (`frus1919Parisv11`).
>   - Of #25's 52 volumes, `frus1915Supp` still holds 2 and `frus1916Supp` 1.
>
> **Eight more are questions.** In seven the volume prints the later paper under the earlier one's head or source note, and in one the earlier paper gives no day; the page decides each. They are the CSV's rows marked `question`.

**In "What follows from it":** the bullet on #25 can add that 41 of the other 43 volumes were not among #25's 52 either.

**The bullet on renumbering** can point to the table's last column, which counts the renumbered documents from the earliest paper filed inside another.

### Item 5

**The summary table's row:**

> | 5 | `frus1870`, `frus1871` | 24 `@when` values that contradict the date they mark: 19 take their month from the receipt, 16 in `frus1870` and 3 in `frus1871` | confirmed |

**After the 16-row table:**

> **`frus1871` has three more, and no other volume of the 553 has one:**
>
> | Document | Line | Printed | Encoded | Received | The List of Papers |
> |---|---|---|---|---|---|
> | `d28` | 20250 | June 10, 1871 | 1871-07-10 | July 14 | June 10 (line 14387) |
> | `d308` | 64633 | April 29, 1871 | 1871-05-29 | May 12 | April 29 (line 17176) |
> | `d350` | 72337 | November 19, 1870 | 1870-12-19 | December 12 | Nov. 19 (line 17595) |
>
> **Two more dates are questions, of other kinds.**
>
> - `frus1949v08` `d1375` (line 84570) prints "August 12, 1949—5 p. m." and is encoded `1949-08-19`, the day of its receipt. Its hours fit a telegram sent and received on the 19th, so only the page can say which is the slip.
> - `frus1919v01` `d264` (line 27972) is the other way round. It prints "May 23, 1918, 1 p.m.", while its List of Papers (line 10095) gives July 23 and its receipt July 24, 3.59 a.m. `@when` holds July 23, and the page decides whether the "May" is the book's or the transcription's.

**The paragraph "The rule that found these is simple …"** says it was run on `frus1870` alone. It now says the rule was run on all 553 volumes.

**"What was checked and is not reported"** can add one bullet:

> Five dates take the year of their receipt (`frus1881` `d86`, `d87`, `d144` and `d286`; `frus1891` `d425`). All five are in #469 (§5.1).

### Part B and the rest of Part A

- **Part A's heading** names "three papers of 1870 filed inside the paper before them". With the sweep, it names the error across 44 volumes.
- **The status header and "How to reproduce"** name one run of `check.py`. They should name `sweep.py` beside it, for items 1 and 5 beyond `frus1870`.
- **B.2** says item 5's rule "was run on that volume alone". That is no longer so.
- **B.4** lists the sweep as not done. It can point here instead.
- **B.5** can add the sweep's run.

## 5. Found in passing, not swept

- **`frus1871` `d168` to `d172`: the error the other way round.**
  - They are the five inclosures of No. 153 (`d167`, Mr. Bancroft's despatch of December 17, 1870), encoded as documents of their own.
  - No. 154 is then filed inside the last of them.
  - It is an inclosure promoted to a document.
- **`frus1870`'s List of Papers gives two wrong pages.**
  - No. 163 is "508" for p. 208 (`d163`).
  - No. 189 is "223" for p. 233 (`d189`).

  They are two of the three rows the sweep could not match in that volume. The third is No. 131, which the note's item 1 discusses.
- **`frus1867p1` `d380`, Mr. Burlingame's despatch No. 126, is dated "January 3, 1861"** in its text and its `@when`, in a volume of 1867's papers. The circular filed inside it is of January 17, 1867. #469's year rule could not see it, since the text and the attribute agree.
