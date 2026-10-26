# Writes collection.fruscollection; verifies every pair exists in document_cache (SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?), no duplicates, no Ed2.
import json, sqlite3
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
Q = {(v, d): q for v, d, q in json.load(open('/Users/jbotts/frus-analysis/c3/runs/r4/quotes.json'))}
A = "Agent finding, run r4, 2026-10-25: "
intro = open('/Users/jbotts/frus-analysis/c3/runs/r4/intro.txt').read().strip()
groups = [
 ("The standing tests: control, obligations, acquiescence",
  "From 1895 to 1949 the Department kept returning to the same three questions about a government that had taken power: does it control the country, will it meet its international obligations, and do the people accept it. These four documents state the tests in four different decades.",
  [("frus1895p1","d244","An instruction on Ecuador's 1895 revolution: do business with the de facto authority that controls the government with the people's general acquiescence; leave formal recognition to Washington."),
   ("frus1913","d894","Recognition of Huerta held back in February 1913 while the Department applied the 'usual tests': popular assent, and the ability to protect foreigners and meet international obligations."),
   ("frus1930v01","d375","Stimson's press release of 17 September 1930 recognizing Argentina, Peru and Bolivia: de facto control, no active resistance, intent to fulfil obligations, and elections in due course."),
   ("frus1949v02","d439","The Embassy in Panama, December 1949, names the three conditions, citing a circular instruction of 8 June 1948 that FRUS does not print.")]),
 ("Constitutional legitimacy and the Central American treaties, 1913-1936",
  "Wilson's March 1913 statement and the Central American treaties of 1907 and 1923 added a fourth test: how the government came to power. The thread runs from the Tinoco case in Costa Rica to the State Department dropping the treaty rule in 1936.",
  [("frus1913","d7","Wilson's statement of 11 March 1913, circulated to the missions in Latin America: cooperation only with just government based on law, not on irregular force. Added by hand; it never uses the word recognition."),
   ("frus1917","d378","Lansing on Costa Rica, February 1917: no recognition for any government not elected by legal and constitutional means."),
   ("frus1917","d414","Tinoco's agent quotes Article I of the 1907 Additional Treaty and argues it binds only the five republics, not the United States."),
   ("frus1932v05","d623","El Salvador, January 1932: the Department works through Article II of the 1923 treaty clause by clause to see who could be recognized."),
   ("frus1936v05","d112","April 1936: the Department will no longer be guided by Article II of the 1923 treaty in extending or denying recognition in Central America.")]),
 ("Recognition as a bargain: Mexico, 1920-1923",
  "With Mexico, recognition was tied to specific undertakings: the interpretation of Article 27 of the 1917 Constitution, claims, and a treaty.",
  [("frus1920v03","d225","Under Secretary Davis, August 1920: Article 27 must be interpreted as not retroactive before relations resume."),
   ("frus1921v02","d344","Hughes, June 1921: recognition is 'a subordinate one' and will come with a treaty binding Mexico to its primary international obligations.")]),
 ("Wartime: consultation and the Axis test, 1943-1944",
  "In wartime the question became collective and political: the other republics were consulted, and the test was whether the new regime had Axis connections.",
  [("frus1943v05","d335","Armour in Buenos Aires, June 1943, denies that a break with the Axis was being imposed as a condition precedent to recognizing the Ramirez government."),
   ("frus1944v07","d432","Bolivia, June 1944: pro-Nazi MNR leaders made recognition impossible; none is now in a prominent post."),
   ("frus1944v07","d1023","June 1944: under the Montevideo formula (Resolution XXII) every revolutionary change triggers consultation on Axis inspiration.")]),
 ("After Bogota: continuity, and what was still asked, 1948-1973",
  "Resolution XXXV at Bogota in 1948 recast recognition as continuity of relations that implied no approval. The later documents show what Washington still weighed: communism, elections, civil rights, and timing.",
  [("frus1948v09","d74","Resolution XXXV, Bogota 1948: maintaining relations implies no judgment on the government's domestic policy."),
   ("frus1948v09","d89","November 1948, Peru's military junta: the presumption is now to keep relations with all Latin American governments."),
   ("frus1958-60v06","d217","Herter to Eisenhower, 7 January 1959: recognize Castro's provisional government without delay; it claims control, promises to honour commitments, and appears free from Communist taint."),
   ("frus1961-63v12","d421","Ball to Kennedy, July 1962: the suspension of relations after the Peruvian coup moved the junta on elections and civil rights."),
   ("frus1969-76v21","d348","Washington Special Actions Group, 12 September 1973: well-disposed to the Chilean junta, but not the first to recognize it.")]),
]
entries = []
seen = set()
for title, prose, docs in groups:
    entries.append({"kind": "heading", "text": title, "level": 1})
    entries.append({"kind": "prose", "text": prose})
    for v, d, note in docs:
        assert (v, d) not in seen and not v.endswith('Ed2')
        assert con.execute("SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
        seen.add((v, d))
        entries.append({"kind": "document", "volumeId": v, "documentId": d, "notes": [A + note]})
        if (v, d) in Q: entries.append({"kind": "excerpt", "volumeId": v, "documentId": d, "text": Q[(v, d)]})
assert set(Q) <= seen, set(Q) - seen
entries.append({"kind": "heading", "text": "Threads not followed", "level": 1})
entries.append({"kind": "prose", "text": open('/Users/jbotts/frus-analysis/c3/runs/r4/closing.txt').read().strip()})
entries.append({"kind": "generated", "generatedBlockType": "archivalSources"})
col = {"format": "fruscollection", "formatVersion": 2, "minimumReaderVersion": 1,
       "name": "Recognizing governments that took power by force in Latin America",
       "authorLine": "Agent run r4, 2026-10-25",
       "introductionText": intro,
       "composition": {"defaultBodyDepth": "full", "footnoteStyle": "all", "includeSourceNote": True, "tocStyle": "citation", "applyHighlights": False, "includeNotes": True, "includeWordCloud": False},
       "entries": entries}
json.dump(col, open('/Users/jbotts/frus-analysis/c3/runs/r4/collection.fruscollection', 'w'), ensure_ascii=False, indent=1)
print('documents', len(seen), 'excerpts', sum(1 for e in entries if e['kind'] == 'excerpt'), 'entries', len(entries))
