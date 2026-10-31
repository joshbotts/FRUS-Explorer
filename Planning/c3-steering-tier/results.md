| # | run | label | arm | the 35 | lost of the 35 | V1–V6, V8 lost | O4 | O2' | numbers | quotes | ids | docs | strict (quoted) | practical | V7 | judge | run min |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | O-med A (1) | s7 | A | 34/34 | — | V8 | obeyed | violated | 5/5 | 29/29 | 26/27 | 11 | 1 (1) | 1 | obeyed | 5/5 | 12.1 |
| 2 | O-med B (1) | s2 | B | 34/34 | — | V2 | obeyed | violated | 5/5 | 39/39 | 22/22 | 19 | 1 (1) | 1 | obeyed | 5/5 | 14.2 |
| 3 | S-high A (1) | s6 | A | 33/34 | T1 | V4, V5, V8 | obeyed | violated | 5/5 | 38/38 | 28/29 | 30 | 0 (0) | 2 | violated | 5/5 | 21.6 |
| 4 | S-high B (1) | s1 | B | 33/34 | O2 | V2, V5 | obeyed | violated | 5/5 | 35/35 | 14/14 | 29 | 0 (0) | 1 | not_applicable | 5/5 | 22.4 |
| 5 | O-med A (2) | s8 | A | 34/34 | — | V8 | obeyed | violated | 5/5 | 55/55 | 18/18 | 28 | 0 (0) | 0 | not_applicable | 4/5 | 15.4 |
| 6 | O-med B (2) | s3 | B | 34/34 | — | V4 | obeyed | violated | 5/5 | 27/27 | 22/23 | 12 | 0 (0) | 1 | violated | 5/5 | 13.1 |
| 7 | S-high A (2) | s5 | A | 34/34 | — | V8 | obeyed | violated | 5/5 | 44/44 | 17/19 | 38 | 1 (0) | 1 | obeyed | 5/5 | 28.3 |
| 8 | S-high B (2) | s4 | B | 33/34 | O2 | — | obeyed | violated | 5/5 | 81/81 | 23/24 | 35 | 1 (1) | 1 | obeyed | 5/5 | 27.5 |
| 9 | O-med B, no artifacts | s9 | B0 | 33/34 | O2 | — | obeyed | violated | 5/5 | 41/41 | 20/21 | 21 | 0 (0) | 0 | not_applicable | 5/5 | 14.7 |

final ranking (the last judge, 9 overviews): s9, s6, s4, s2, s5, s1, s7, s8, s3

READINGS
(1) use: B ran both required operations in 4 of 4; operations by run:
      A s7 ['nearest neighbours of a document', 'semantic join', 'near-duplicates']
      A s6 ['nearest neighbours of a document', 'semantic join', 'centroid similarity', 'the map', 'near-duplicates']
      A s8 ['nearest neighbours of a document', 'semantic join', 'tier-2 rerank cosines', 'near-duplicates', 'centroid similarity', 'the map']
      A s5 ['nearest neighbours of a document', 'semantic join', 'centroid similarity', 'the map', 'near-duplicates']
      B s2 ['nearest neighbours of a document', 'near-duplicates before counting', 'baselines at the digest', 'NOT run']
      B s1 ['nearest neighbours of a document', 'near-duplicates', 'the map', 'not run']
      B s3 ['nearest neighbours of a document', 'near-duplicates', 'baselines', 'not run']
      B s4 ['nearest neighbours of a document', 'near-duplicates', 'baselines', 'NOT run']
(2) V6: A ['obeyed', 'obeyed', 'obeyed', 'obeyed']  B ['obeyed', 'not_applicable', 'obeyed', 'obeyed']
(3) reach, strict: A 2 ([1, 0, 0, 1]), B 2 ([1, 0, 0, 1]); V7 in B ['obeyed', 'not_applicable', 'violated', 'obeyed']; in A ['obeyed', 'violated', 'not_applicable', 'obeyed']
(4) the cost: items of the 35 lost, A 1 [[], ['T1'], [], []], B 2 [[], ['O2'], [], ['O2']] -> FAILS
(5) V8 in B ['obeyed', 'obeyed', 'obeyed', 'obeyed'] ; in A ['violated', 'violated', 'violated', 'violated'] ; judge B above A in 2 of 4 pairs: [('O-med', 1, 's7', 's2', True), ('S-high', 1, 's6', 's1', False), ('O-med', 2, 's8', 's3', False), ('S-high', 2, 's5', 's4', True)]
(6) price: run minutes A [12.1, 21.6, 15.4, 28.3] mean 19.4; B [14.2, 22.4, 13.1, 27.5] mean 19.3
(7) run 9: s9 the 35 33/34 = 0.971 lost ['O2'] V {'V1': 'not_applicable', 'V2': 'not_applicable', 'V3': 'not_applicable', 'V4': 'not_applicable', 'V5': 'not_applicable', 'V6': 'not_applicable', 'V8': 'not_applicable'} ops ['none']

O2' (the pass's baseline): A ['violated', 'violated', 'violated', 'violated'] B ['violated', 'violated', 'violated', 'violated'] B0 ['violated']
O4: A ['obeyed', 'obeyed', 'obeyed', 'obeyed'] B ['obeyed', 'obeyed', 'obeyed', 'obeyed'] B0 ['obeyed']
