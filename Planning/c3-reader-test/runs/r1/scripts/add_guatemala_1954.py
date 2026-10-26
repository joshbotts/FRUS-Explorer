# One-off edit script: bring Guatemala in 1954 (frus1952-54v04 documents 490 and 502, retrieved whole and added to the cited set as finding 6)
# into the builders, the memo templates and the trace rows. Every replacement asserts that the old text occurs exactly once.
import re
RUN = "/Users/jbotts/frus-analysis/c3/runs/r1"

def edit(path, pairs):
    s = open(RUN + "/" + path).read()
    for old, new in pairs:
        n = s.count(old)
        assert n == 1, (path, n, old[:80])
        s = s.replace(old, new)
    open(RUN + "/" + path, "w").write(s)
    print("edited", path, len(pairs), "replacements")

# ---------------- content.py: notes and the finding-6 description
edit("scripts/content.py", [
 (' "frus1955-57v06/d354": "On Haiti',
  ' "frus1952-54v04/d490": "Telegram of 28 June 1954 from the Ambassador in Guatemala, the day three colonels announced a military junta: when Colonel Diaz raises recognition, the Ambassador answers that Washington will want a reasonable period to see what they do and that one of the criteria for recognition is control of the country\'s territory, which they lack while Castillo Armas controls a portion of it.",\n'
  ' "frus1952-54v04/d502": "Memorandum of 9 July 1954 from the Secretary of State to President Eisenhower: the new government, formally established on 2 July, appears to control the entire territory and has sent a formal note saying it is prepared to fulfill Guatemala\'s international obligations; he proposes to ask the other American republics, London, Paris and Ottawa for their views and to consider recognition on 13 July, so as not to be conspicuously in the lead or behind. The editors record the President\'s approval of 10 July and that recognition was extended on 13 July.",\n'
  ' "frus1955-57v06/d354": "On Haiti'),
 ("From the Haitian junta of 1957 to Chile in 1973, the printed record shows",
  "From Guatemala in 1954 and the Haitian junta of 1957 to Chile in 1973, the printed record shows"),
])

# ---------------- build_overview.py
edit("scripts/build_overview.py", [
 ("Forty-three documents carry the argument", "Forty-five documents carry the argument"),
 ("28 of the 43 documents I rely on", "30 of the 45 documents I rely on"),
 ("recognition became the default. A National Security Council policy of February 1959 told",
  "recognition became the default. In Guatemala on 28 June 1954 the Ambassador told the three colonels who had just announced a military junta that Washington would want a reasonable period to see what they did, and that one of the criteria for recognition was control of the country’s territory, which they lacked while Castillo Armas controlled a portion of it (%s). On 9 July the Secretary of State told President Eisenhower that the new government, formally established on 2 July, appeared to control the entire territory and had sent a formal note saying it was prepared to fulfill Guatemala’s international obligations; he proposed to ask the other American republics, and London, Paris and Ottawa, for their views and to consider recognition on 13 July, so that the United States would not be conspicuously in the lead or behind, and the editors record that recognition was extended on 13 July (%s). A National Security Council policy of February 1959 told"),
 ('% (c("frus1958-60v05/d11"), c("frus1958-60v06/d217"), c("frus1961-63v12/d363"), c("frus1964-68v31/d132")))',
  '% (c("frus1952-54v04/d490"), c("frus1952-54v04/d502"), c("frus1958-60v05/d11"), c("frus1958-60v06/d217"), c("frus1961-63v12/d363"), c("frus1964-68v31/d132")))'),
 ("Guatemala in 1944 and 1954, the Dominican Republic in 1916", "Guatemala in 1944 and, beyond the two documents I read, in 1954, the Dominican Republic in 1916"),
 ("and about one document in forty that has the phrase has it only in a footnote.",
  "and about one document in forty that has recognition near government, regime, junta or administration has it only in a footnote or the source note."),
])

# ---------------- build_collection.py: the closing block
edit("scripts/build_collection.py", [
 ("I did not search the Guatemalan and Bolivian cases of the early 1950s, where the editors’ chapter titles do not name recognition, nor the Nicaraguan case of 1979,",
  "Of the early 1950s I followed only Guatemala in June and July 1954, in two documents; I did not follow the rest of the Guatemalan record of 1954 or the Bolivian cases of the early 1950s, where the editors’ chapter titles do not name recognition, nor the Nicaraguan case of 1979,"),
])

# ---------------- trace_rows.py
edit("scripts/trace_rows.py", [
 ('"Forty-three documents carry the argument"', '"Forty-five documents carry the argument"'),
 ('"28 of the 43 documents; about two in three', '"30 of the 45 documents; about two in three'),
 ('"non-recognition 123 documents against 65; about one document in forty has it only in a footnote"',
  '"non-recognition 123 documents against 65; about one document in forty with recognition near government, regime, junta or administration has it only in a footnote or the source note"'),
 ('("Finding 6", "February 1959; 7 January 1959; 14 December 1963; Rio 1965", ["R39", "R38", "R40", "R41"]),',
  '("Finding 6", "28 June 1954; 2 July, 9 July and 13 July (1954); Castillo Armas", ["R44", "R45"]),\n ("Finding 6", "February 1959; 7 January 1959; 14 December 1963; Rio 1965", ["R39", "R38", "R40", "R41"]),'),
 ('Guatemala in 1944 and 1954, the Dominican Republic in 1916', 'Guatemala in 1944 and, beyond the two documents I read, in 1954, the Dominican Republic in 1916'),
 ('["N18"]),\n ("Collection, closing block"', '["N18", "N21"]),\n ("Collection, closing block"'),
])

# ---------------- assemble_memo.py: two more document-stated dates and phrases
edit("scripts/assemble_memo.py", [
 (' ("R43", "frus1969-76v21/d361", ["September 20, 1973", "24 September 1973"]),\n]',
  ' ("R43", "frus1969-76v21/d361", ["September 20, 1973", "24 September 1973"]),\n'
  ' ("R44", "frus1952-54v04/d490", ["June 28, 1954", "one of criteria for recognition is that new government be in control of territory", "Castillo Armas controlled a portion of territory"]),\n'
  ' ("R45", "frus1952-54v04/d502", ["July 9, 1954", "formally established on July 2", "prepared to fulfill the international obligations of Guatemala", "conspicuously in the lead or behind", "recognition to the new Guatemalan Government on July 13, 1954"]),\n]'),
])

# ---------------- memo templates
edit("work/memo_template_1.md", [
 ("(103 of the 104 documents retrieved are inside it, section 10)", "(every other document retrieved is inside it, section 10)"),
 ("[N18b] Of the 2,255 documents under these chapters, 50 were among the documents I retrieved (section 10).",
  "[N18b] Of the 2,255 documents under these chapters, 50 were among the documents I retrieved (section 10).\n\n"
  "[N21] Guatemala in 1954, followed in part. The editors' chapter titles for 1954 do not name recognition, so the case is outside set E. It was found by browse listings of family C (scripts/browse.py with the family C expression, once with --vol frus1952-54Guat and once with --vol frus1952-54v04 and --path guatemala, both limited to 1954; the SELECTs are in queries.log). The Guatemala volume (frus1952-54Guat) has 5 family C documents dated 1954 (24 April, 28 April, 24 May, 19 June and 24 June: planning papers of the operation, which speak of recognizing the new government once it exists). The American Republics volume (frus1952-54v04) has 15 dated 1954; 6 of them sit under a Guatemala heading (documents 471, 490, 498, 502, 508 and 512), and by their snippets 471 (planning for recognition), 490 and 502 are about recognition of the new government, while 498, 508 and 512 use the word in other senses. Documents 490 and 502 were retrieved whole (section 10) and are in the collection as finding 6; every other 1954 document was seen as a snippet only."),
])
edit("work/memo_template_3.md", [
 ("[N07] The cited set. 43 documents (", "[N07] The cited set. 45 documents ("),
 ("all 43 exist, none is front matter", "all 45 exist, none is front matter"),
 ("By finding: 5, 8, 9, 5, 9 and 7 documents (findings 1 to 6). 17 of the 43 are quoted and carry 19 quotations; the other 26 are cited",
  "By finding: 5, 8, 9, 5, 9 and 9 documents (findings 1 to 6). 17 of the 45 are quoted and carry 19 quotations; the other 28 are cited"),
 ("CAME-FROM, the 43 cited documents (", "CAME-FROM, the 45 cited documents ("),
 ("decimal file number **28**; no source note 4", "decimal file number **30**; no source note 4"),
 ("POL 23-9 ARG). 28 + 4 + 2 + 5 + 4 = 43.", "POL 23-9 ARG). 30 + 4 + 2 + 5 + 4 = 45."),
 ("Cited set: 3 of 43 documents carry a row (frus1944v07/d432, frus1955-57v06/d354 and frus1958-60v06/d217, all centralFileClass).",
  "Cited set: 5 of 45 documents carry a row, 11 rows in all (frus1944v07/d432, frus1952-54v04/d490, frus1952-54v04/d502, frus1955-57v06/d354 and frus1958-60v06/d217, all centralFileClass)."),
 ("not cited among the 43 documents", "not cited among the 45 documents"),
 ('738.00 (Haiti) is class 7 "Internal Political and National Defense Affairs" under the 1950-1959 schedule.',
  '738.00 (Haiti), 714.00 and 714.02 (Guatemala) are class 7 "Internal Political and National Defense Affairs" under the 1950-1959 schedule, which the table glosses for class and country only.'),
])
print("done")
