| cell | model | effort | compliance | violated | numbers | quotes | fab. | ids | docs | reader | quality | run min | cell min | tool calls | weekly pts | Fable pts |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S-high | claude-sonnet-5-5 | high | 1.000 | — | 5/5 | 37/37 | 0 | 22/22 | 56 | 5/5 | 1.000 | 30.5 | 61.8 | 171 | 2 | 3 |
| S-max | claude-sonnet-5-5 | max | 1.000 | — | 5/5 | 38/38 | 0 | 24/24 | 45 | 5/5 | 1.000 | 88.9 | 128.6 | 426 | 4 | 4 |
| O-med | claude-opus-5-5 | medium | 1.000 | — | 5/5 | 39/39 | 0 | 12/12 | 19 | 5/5 | 1.000 | 18.2 | 52.0 | 83 | 1 | 2 |
| O-max | claude-opus-5-5 | max | 1.000 | — | 5/5 | 49/49 | 0 | 34/34 | 41 | 5/5 | 1.000 | 60.1 | 98.2 | 160 | 2 | 4 |
| O-med (2) | claude-opus-5-5 | medium | 1.000 | — | 5/5 | 42/42 | 0 | 22/22 | 26 | 5/5 | 1.000 | 19.4 | 56.2 | 81 | 2 | 4 |
| S-high (2) | claude-sonnet-5-5 | high | 1.000 | — | 5/5 | 44/44 | 0 | 16/16 | 56 | 5/5 | 1.000 | 32.4 | 66.0 | 222 | 2 | 5 |
| F-high | claude-fable-5-1 | high | 0.971 | O2 | 5/5 | 78/78 | 0 | 13/13 | 34 | 5/5 | 0.971 | 31.1 | 66.0 | 53 | 3 | 5 |
| O-max (2) | claude-opus-5-5 | max | 0.971 | O2 | 5/5 | 36/36 | 0 | 24/24 | 52 | 5/5 | 0.971 | 77.9 | 110.6 | 244 | 3 | 3 |
| O-high | claude-opus-5-5 | high | 0.941 | P6,O2 | 5/5 | 49/49 | 0 | 44/44 | 43 | 5/5 | 0.941 | 27.1 | 59.0 | 106 | 2 | 3 |
| F-max | claude-fable-5-1 | max | 0.912 | I2,I3,O2 | 5/5 | 111/111 | 0 | 18/18 | 58 | 5/5 | 0.912 | 34.4 | 63.0 | 79 | 3 | 6 |
| F-med | claude-fable-5-1 | medium | 0.941 | R3,O1 | 5/5 | 64/64 | 0 | 19/19 | 52 | 4/5 (J4) | 0.753 | 24.4 | 65.0 | 49 | 3 | 6 |
| S-med | claude-sonnet-5-5 | medium | 0.912 | R3,S3,P2 | 5/5 | 66/66 | 0 | 25/25 | 38 | 4/5 (J4) | 0.729 | 13.5 | 45.7 | 79 | 2 | 3 |

Final judge ranking (best to worst): S-high (2) > O-max > O-max (2) > S-high > S-max > F-max > O-high > F-high > O-med (2) > O-med > F-med > S-med
  (for the earlier judges' rankings see each cell's verdicts.json)

Per cell, runs pooled (mean of n runs):
  S-high (n=2): compliance 1.000 (min 1.000), quality 1.000, run 31.4 min, weekly pts 2.0, fabrications 0
  S-max: compliance 1.000 (min 1.000), quality 1.000, run 88.9 min, weekly pts 4.0, fabrications 0
  O-med (n=2): compliance 1.000 (min 1.000), quality 1.000, run 18.8 min, weekly pts 1.5, fabrications 0
  O-max (n=2): compliance 0.985 (min 0.971), quality 0.985, run 69.0 min, weekly pts 2.5, fabrications 0
  F-high: compliance 0.971 (min 0.971), quality 0.971, run 31.1 min, weekly pts 3.0, fabrications 0
  O-high: compliance 0.941 (min 0.941), quality 0.941, run 27.1 min, weekly pts 2.0, fabrications 0
  F-max: compliance 0.912 (min 0.912), quality 0.912, run 34.4 min, weekly pts 3.0, fabrications 0
  F-med: compliance 0.941 (min 0.941), quality 0.753, run 24.4 min, weekly pts 3.0, fabrications 0
  S-med: compliance 0.912 (min 0.912), quality 0.729, run 13.5 min, weekly pts 2.0, fabrications 0

Compliance floor 0.952: below it — ['S-med', 'O-high', 'F-med', 'F-max'] (a fast cell below the floor is a warning, not a recommendation)
FASTEST (lowest run wall clock among cells at or above the floor with zero fabrications): O-med (n=2) at 18.799999999999997 min
BEST VALUE (quality per weekly point, instruments included): O-med (n=2) at 0.667 per point (quality 1.000 over 1.5 points)
  all: O-med (n=2) 0.667, S-high (n=2) 0.500, O-high 0.471, O-max (n=2) 0.394, S-med 0.365, F-high 0.324, F-max 0.304, F-med 0.251, S-max 0.250
HIGHEST QUALITY (quality score, ties by the refuter's error count, then the judge's ranking): S-high (n=2) (1.000)
  order: S-high (n=2) 1.000 > S-max 1.000 > O-med (n=2) 1.000 > O-max (n=2) 0.985 > F-high 0.971 > O-high 0.941 > F-max 0.912 > F-med 0.753 > S-med 0.729
