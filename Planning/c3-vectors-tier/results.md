| run | compliance (35 items) | all 40 | V1–V6 | violated | numbers | quotes | ids | docs | reader | quality | ops | vector-reached (quoted) | run min | cell min | tool calls | weekly pts |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| O-med+V (1) | 0.941 | 0.925 | ✓✓✓✓✓✗ | T1,P6,V6 | 5/5 | 44/44 | 22/22 | 16 | 5/5 | 0.941 | 5 | 0 (0) of 16 | 23.3 | 60.2 | 87 | 2 |
| S-high+V (1) | 0.971 | 0.950 | ✓✓✓✓✓✗ | P5,V6 | 5/5 | 64/64 | 20/20 | 23 | 5/5 | 0.971 | 5 | 1 (1) of 23 | 21.2 | 53.5 | 106 | 2 |
| O-med+V (2) | 0.971 | 0.925 | ✓✓✓✓✗✗ | P5,V5,V6 | 4/5 | 38/38 | 30/32 | 16 | 5/5 | 0.776 | 5 | 1 (1) of 16 | 14.2 | 50.3 | 55 | 1 |
| S-high+V (2) | 1.000 | 0.975 | ✓✓✓✓✓✗ | V6 | 5/5 | 64/64 | 20/20 | 22 | 5/5 | 1.000 | 5 | 0 (0) of 22 | 25.2 | 57.5 | 121 | 2 |

C-3 reference, same cells, the recognition question (compliance, run min, weekly pts, docs, reader):
  O-med [(1.0, 18.2, 1, 19, 5), (1.0, 19.4, 2, 26, 5)]
  S-high [(1.0, 30.5, 2, 56, 5), (1.0, 32.4, 2, 56, 5)]
Final judge ranking: S-high+V (2) > S-high+V (1) > O-med+V (2) > O-med+V (1)

READINGS (design §6):
  Use: 4 of 4 runs ran a vector operation; operations per run [5, 5, 5, 5]; digests compared in 4 of 4
  Reach: vector-reached documents per run [('O-med+V (1)', 0, 0), ('S-high+V (1)', 1, 1), ('O-med+V (2)', 1, 1), ('S-high+V (2)', 0, 0)] (count, of which quoted)
  Appendix cost, O-med: compliance on the 35 items [0.941, 0.971] against C-3's [1.0, 1.0]; run min [23.3, 14.2] against [18.2, 19.4]; weekly pts [2, 1] against [1, 2]; documents [16, 16] against [19, 26]
  Appendix cost, S-high: compliance on the 35 items [0.971, 1.0] against C-3's [1.0, 1.0]; run min [21.2, 25.2] against [30.5, 32.4]; weekly pts [2, 2] against [2, 2]; documents [23, 22] against [56, 56]
  Reader: items [('O-med+V (1)', 5), ('S-high+V (1)', 5), ('O-med+V (2)', 5), ('S-high+V (2)', 5)]
  Compliance floor 0.952 on the 35 items: below it — ['O-med+V (1)']
