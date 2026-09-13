
### A:union_minus_agree_net
three-way union minus agreement arm, minus spans overlapping the agreement arm (the adjudication queue)

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 63.22 / 117 / 498 | 93.28 / 182 / 799 | 187 / 364 / 2,081 | 92.703 / 160.411 / 1324.21 | 6.748 / 14.869 / 30.849 | 25.891 | 3 |
| sonnet-5 | 146 / 223 / 1,130 | 200 / 339 / 1,672 | 421 / 785 / 4,310 | 116.937 / 188.832 / 1398.253 | 6.73 / 14.869 / 30.858 | 25.891 | 3 |
| opus-5 | 292 / 525 / 2,913 | 417 / 817 / 4,316 | 885 / 1,900 / 11,045 | 92.703 / 176.293 / 1409.944 | 5.8 / 14.869 / 35.1 | 25.891 | 3 |

local no-think 14B: Qwen in/out MTok (central) 153.754 / 13.276; hours central [182.94, 191.48]; hours range [95.64, 1521.94]; 27-31B judge [181.71, 3348.27]; kWh [8.61, 401.79]; $ [1.29, 100.45]

local thinking 14B, low allowance: Qwen in/out MTok (central) 153.754 / 15.706; hours central [194.27, 200.05]; hours range [103.93, 1535.04]; 27-31B judge [197.48, 3377.1]; kWh [9.35, 405.25]; $ [1.4, 101.31]

local thinking 14B, high allowance: Qwen in/out MTok (central) 153.754 / 37.574; hours central [219.33, 353.99]; hours range [116.34, 1736.54]; 27-31B judge [221.04, 3820.38]; kWh [10.47, 458.45]; $ [1.57, 114.61]

### A:union_minus_agree_exact
three-way union minus agreement arm by exact span triple (the literal set difference)

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 72.97 / 137 / 559 | 109 / 214 / 890 | 217 / 428 / 2,290 | 104.653 / 181.895 / 1441.009 | 8.257 / 18.329 / 37.482 | 30.88 | 3 |
| sonnet-5 | 168 / 260 / 1,274 | 232 / 399 / 1,870 | 489 / 920 / 4,761 | 131.986 / 214.024 / 1531.295 | 8.235 / 18.329 / 37.493 | 30.88 | 3 |
| opus-5 | 337 / 615 / 3,293 | 484 / 962 / 4,841 | 1,028 / 2,229 / 12,236 | 104.653 / 199.85 / 1545.551 | 7.094 / 18.329 / 42.734 | 30.88 | 3 |

local no-think 14B: Qwen in/out MTok (central) 174.397 / 16.366; hours central [216.7, 218.69]; hours range [112.43, 1651.52]; 27-31B judge [213.61, 3633.33]; kWh [10.12, 436.0]; $ [1.52, 109.0]

local thinking 14B, low allowance: Qwen in/out MTok (central) 174.397 / 19.257; hours central [222.0, 237.06]; hours range [118.06, 1665.83]; 27-31B judge [224.32, 3664.82]; kWh [10.63, 439.78]; $ [1.59, 109.94]

local thinking 14B, high allowance: Qwen in/out MTok (central) 174.397 / 45.282; hours central [251.84, 420.27]; hours range [132.76, 1910.93]; 27-31B judge [252.25, 4204.04]; kWh [11.95, 504.48]; $ [1.79, 126.12]

### A:control_only
filtered NLTagger spans overlapping no filtered-sweep span

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 13.65 / 24.17 / 145 | 19.20 / 35.87 / 245 | 38.39 / 71.75 / 675 | 22.366 / 37.677 / 450.627 | 0.985 / 2.133 / 5.219 | 4.681 | 1 |
| sonnet-5 | 31.82 / 45.07 / 321 | 41.80 / 66.14 / 500 | 88.48 / 157 / 1,372 | 28.239 / 44.427 / 461.094 | 0.983 / 2.133 / 5.22 | 4.681 | 1 |
| opus-5 | 63.04 / 105 / 815 | 86.49 / 158 / 1,269 | 185 / 378 / 3,467 | 22.366 / 41.449 / 462.747 | 0.849 / 2.133 / 5.817 | 4.681 | 1 |

local no-think 14B: Qwen in/out MTok (central) 36.074 / 1.904; hours central [34.4, 43.54]; hours range [18.59, 525.59]; 27-31B judge [35.32, 1156.3]; kWh [1.67, 138.76]; $ [0.25, 34.69]

local thinking 14B, low allowance: Qwen in/out MTok (central) 36.074 / 2.35; hours central [37.54, 44.05]; hours range [20.15, 530.03]; 27-31B judge [38.29, 1166.06]; kWh [1.81, 139.93]; $ [0.27, 34.98]

local thinking 14B, high allowance: Qwen in/out MTok (central) 36.074 / 6.357; hours central [48.64, 65.75]; hours range [26.63, 569.94]; 27-31B judge [50.6, 1253.87]; kWh [2.4, 150.46]; $ [0.36, 37.62]

### A:sweep_only
filtered-sweep spans overlapping no filtered-NLTagger span

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 59.03 / 110 / 499 | 87.52 / 171 / 806 | 175 / 341 / 2,112 | 85.136 / 146.968 / 1346.162 | 6.587 / 14.44 / 30.238 | 24.46 | 3 |
| sonnet-5 | 136 / 209 / 1,129 | 188 / 319 / 1,682 | 394 / 735 / 4,363 | 107.416 / 173.151 / 1415.549 | 6.569 / 14.44 / 30.247 | 24.46 | 3 |
| opus-5 | 273 / 494 / 2,907 | 391 / 769 / 4,336 | 829 / 1,781 / 11,169 | 85.136 / 161.6 / 1426.505 | 5.659 / 14.44 / 34.374 | 24.46 | 3 |

local no-think 14B: Qwen in/out MTok (central) 140.794 / 12.893; hours central [172.7, 176.18]; hours range [90.61, 1551.14]; 27-31B judge [172.17, 3412.51]; kWh [8.16, 409.5]; $ [1.22, 102.38]

local thinking 14B, low allowance: Qwen in/out MTok (central) 140.794 / 15.185; hours central [178.81, 188.83]; hours range [96.01, 1564.54]; 27-31B judge [182.43, 3441.99]; kWh [8.64, 413.04]; $ [1.3, 103.26]

local thinking 14B, high allowance: Qwen in/out MTok (central) 140.794 / 35.806; hours central [202.45, 334.01]; hours range [107.77, 1766.51]; 27-31B judge [204.77, 3886.33]; kWh [9.7, 466.36]; $ [1.45, 116.59]

### A:control_only_net
control_only minus spans overlapping an editor mark

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 13.46 / 23.85 / 142 | 18.93 / 35.39 / 239 | 37.86 / 70.78 / 661 | 22.09 / 37.202 / 440.68 | 0.967 / 2.1 / 5.127 | 4.615 | 1 |
| sonnet-5 | 31.39 / 44.48 / 315 | 41.22 / 65.24 / 489 | 87.26 / 155 / 1,342 | 27.89 / 43.868 / 451.024 | 0.964 / 2.1 / 5.128 | 4.615 | 1 |
| opus-5 | 62.18 / 104 / 798 | 85.29 / 156 / 1,242 | 183 / 373 / 3,392 | 22.09 / 40.927 / 452.658 | 0.833 / 2.1 / 5.716 | 4.615 | 1 |

local no-think 14B: Qwen in/out MTok (central) 35.619 / 1.875; hours central [33.93, 42.98]; hours range [18.31, 513.92]; 27-31B judge [34.8, 1130.62]; kWh [1.65, 135.67]; $ [0.25, 33.92]

local thinking 14B, low allowance: Qwen in/out MTok (central) 35.619 / 2.314; hours central [37.02, 43.49]; hours range [19.85, 518.25]; 27-31B judge [37.72, 1140.16]; kWh [1.79, 136.82]; $ [0.27, 34.2]

local thinking 14B, high allowance: Qwen in/out MTok (central) 35.619 / 6.265; hours central [48.01, 64.83]; hours range [26.29, 557.28]; 27-31B judge [49.95, 1226.01]; kWh [2.37, 147.12]; $ [0.35, 36.78]

### A:sweep_only_net
sweep_only minus spans overlapping an editor mark

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 54.55 / 101 / 459 | 80.43 / 157 / 741 | 161 / 313 / 1,944 | 79.85 / 137.877 / 1245.431 | 5.848 / 12.835 / 26.976 | 22.249 | 3 |
| sonnet-5 | 126 / 192 / 1,038 | 173 / 292 / 1,546 | 363 / 676 / 4,017 | 100.749 / 162.414 / 1309.266 | 5.833 / 12.835 / 26.983 | 22.249 | 2 |
| opus-5 | 252 / 453 / 2,671 | 359 / 703 / 3,982 | 763 / 1,635 / 10,275 | 79.85 / 151.589 / 1319.345 | 5.026 / 12.835 / 30.646 | 22.249 | 3 |

local no-think 14B: Qwen in/out MTok (central) 132.098 / 11.46; hours central [157.55, 164.57]; hours range [82.67, 1434.46]; 27-31B judge [157.08, 3155.82]; kWh [7.44, 378.7]; $ [1.12, 94.67]

local thinking 14B, low allowance: Qwen in/out MTok (central) 132.098 / 13.547; hours central [166.97, 172.24]; hours range [89.65, 1446.78]; 27-31B judge [170.33, 3182.91]; kWh [8.07, 381.95]; $ [1.21, 95.49]

local thinking 14B, high allowance: Qwen in/out MTok (central) 132.098 / 32.333; hours central [188.5, 304.5]; hours range [100.33, 1623.92]; 27-31B judge [190.63, 3572.62]; kWh [9.03, 428.71]; $ [1.35, 107.18]

### B:agree
editor ∪ (filtered NLTagger ∩ filtered sweep), sweep-side spans; accept rate = DOCUMENTED presence P 0.898

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 55.62 / 109 / 495 | 82.24 / 172 / 812 | 164 / 344 / 2,138 | 81.233 / 141.098 / 1345.484 | 6.002 / 15.444 / 31.57 | 25.137 | 3 |
| sonnet-5 | 129 / 209 / 1,113 | 176 / 322 / 1,684 | 371 / 738 / 4,395 | 102.454 / 166.099 / 1405.013 | 5.986 / 15.444 / 31.579 | 25.137 | 3 |
| opus-5 | 257 / 495 / 2,865 | 367 / 777 / 4,342 | 780 / 1,790 / 11,250 | 81.233 / 155.069 / 1414.412 | 5.159 / 15.444 / 35.898 | 25.137 | 3 |

local no-think 14B: Qwen in/out MTok (central) 135.241 / 13.789; hours central [170.85, 175.78]; hours range [84.41, 1559.95]; 27-31B judge [160.38, 3431.88]; kWh [7.6, 411.83]; $ [1.14, 102.96]

local thinking 14B, low allowance: Qwen in/out MTok (central) 135.241 / 16.137; hours central [173.54, 192.31]; hours range [91.14, 1573.77]; 27-31B judge [173.17, 3462.29]; kWh [8.2, 415.48]; $ [1.23, 103.87]

local thinking 14B, high allowance: Qwen in/out MTok (central) 135.241 / 37.271; hours central [197.77, 341.09]; hours range [102.13, 1803.91]; 27-31B judge [194.04, 3968.59]; kWh [9.19, 476.23]; $ [1.38, 119.06]

### C:armB:summary.json pre-#1292 approximation
rows 13907; header+dateline+chapter+classifier+career lines

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 1.64 / 2.79 / 5.32 | 3.74 / 6.65 / 13.73 | 7.48 / 13.30 / 31.21 | 2.221 / 3.823 / 11.182 | 0.211 / 0.353 / 0.64 | 1.542 | 1 |
| sonnet-5 | 4.03 / 5.70 / 13.14 | 7.78 / 12.60 / 28.32 | 16.11 / 27.89 / 64.12 | 2.793 / 4.471 / 12.031 | 0.211 / 0.353 / 0.64 | 1.542 | 1 |
| opus-5 | 8.65 / 13.52 / 33.20 | 18.03 / 30.78 / 71.13 | 37.42 / 68.30 / 161 | 2.221 / 4.185 / 12.165 | 0.211 / 0.353 / 0.64 | 1.542 | 1 |

local no-think 14B: Qwen in/out MTok (central) 3.679 / 0.315; hours central [4.36, 4.58]; hours range [2.49, 13.01]; 27-31B judge [4.72, 28.62]; kWh [0.22, 3.43]; $ [0.03, 0.86]

local thinking 14B, low allowance: Qwen in/out MTok (central) 3.679 / 0.466; hours central [4.75, 5.42]; hours range [2.59, 13.34]; 27-31B judge [4.92, 29.36]; kWh [0.23, 3.52]; $ [0.03, 0.88]

local thinking 14B, high allowance: Qwen in/out MTok (central) 3.679 / 1.782; hours central [6.26, 14.68]; hours range [3.45, 31.8]; 27-31B judge [6.56, 69.97]; kWh [0.31, 8.4]; $ [0.05, 2.1]

### C+doc:armB:summary.json pre-#1292 approximation
rows 13907; the same plus the document's R-0 text capped at 8k (low, central) / 20k (high) chars

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 6.66 / 8.41 / 13.96 | 8.76 / 12.27 / 22.38 | 17.52 / 24.54 / 48.50 | 12.256 / 15.061 / 28.468 | 0.211 / 0.353 / 0.64 | 1.542 | 1 |
| sonnet-5 | 17.08 / 20.35 / 35.69 | 20.83 / 27.25 / 50.86 | 42.20 / 57.19 / 109 | 15.838 / 19.121 / 34.573 | 0.211 / 0.353 / 0.64 | 1.542 | 1 |
| opus-5 | 33.74 / 46.39 / 91.62 | 43.11 / 63.64 / 130 | 87.60 / 134 / 278 | 12.256 / 17.33 / 35.537 | 0.211 / 0.353 / 0.64 | 1.542 | 1 |

local no-think 14B: Qwen in/out MTok (central) 13.714 / 0.315; hours central [10.2, 16.08]; hours range [8.47, 28.86]; 27-31B judge [16.09, 63.5]; kWh [0.76, 7.62]; $ [0.11, 1.9]

local thinking 14B, low allowance: Qwen in/out MTok (central) 13.714 / 0.466; hours central [11.26, 16.25]; hours range [9.11, 29.2]; 27-31B judge [17.31, 64.24]; kWh [0.82, 7.71]; $ [0.12, 1.93]

local thinking 14B, high allowance: Qwen in/out MTok (central) 13.714 / 1.782; hours central [17.76, 20.52]; hours range [14.39, 39.85]; 27-31B judge [27.34, 87.67]; kWh [1.3, 10.52]; $ [0.19, 2.63]

### C:armB:post-#1292 re-measure (this directory)
rows 14495; header+dateline+chapter+classifier+career lines

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 1.69 / 2.89 / 5.52 | 3.88 / 6.91 / 14.29 | 7.76 / 13.82 / 32.49 | 2.283 / 3.947 / 11.61 | 0.22 / 0.368 / 0.667 | 1.606 | 1 |
| sonnet-5 | 4.16 / 5.89 / 13.64 | 8.06 / 13.08 / 29.46 | 16.70 / 28.97 / 66.72 | 2.869 / 4.612 / 12.481 | 0.22 / 0.368 / 0.667 | 1.606 | 1 |
| opus-5 | 8.94 / 13.99 / 34.44 | 18.69 / 31.96 / 73.99 | 38.81 / 70.96 / 167 | 2.283 / 4.318 / 12.619 | 0.22 / 0.368 / 0.667 | 1.606 | 1 |

local no-think 14B: Qwen in/out MTok (central) 3.801 / 0.329; hours central [4.53, 4.73]; hours range [2.55, 13.52]; 27-31B judge [4.85, 29.74]; kWh [0.23, 3.57]; $ [0.03, 0.89]

local thinking 14B, low allowance: Qwen in/out MTok (central) 3.801 / 0.485; hours central [4.91, 5.63]; hours range [2.66, 13.87]; 27-31B judge [5.06, 30.51]; kWh [0.24, 3.66]; $ [0.04, 0.92]

local thinking 14B, high allowance: Qwen in/out MTok (central) 3.801 / 1.856; hours central [6.49, 15.28]; hours range [3.56, 33.13]; 27-31B judge [6.76, 72.88]; kWh [0.32, 8.75]; $ [0.05, 2.19]

### C+doc:armB:post-#1292 re-measure (this directory)
rows 14495; the same plus the document's R-0 text capped at 8k (low, central) / 20k (high) chars

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 6.88 / 8.71 / 14.42 | 9.07 / 12.72 / 23.19 | 18.14 / 25.44 / 50.29 | 12.66 / 15.569 / 29.413 | 0.22 / 0.368 / 0.667 | 1.606 | 1 |
| sonnet-5 | 17.65 / 21.04 / 36.86 | 21.55 / 28.23 / 52.67 | 43.68 / 59.27 / 113 | 16.359 / 19.762 / 35.696 | 0.22 / 0.368 / 0.667 | 1.606 | 1 |
| opus-5 | 34.88 / 47.97 / 94.62 | 44.63 / 65.95 / 134 | 90.70 / 139 / 288 | 12.66 / 17.912 / 36.688 | 0.22 / 0.368 / 0.667 | 1.606 | 1 |

local no-think 14B: Qwen in/out MTok (central) 14.178 / 0.329; hours central [10.57, 16.63]; hours range [8.76, 29.85]; 27-31B judge [16.64, 65.66]; kWh [0.79, 7.88]; $ [0.12, 1.97]

local thinking 14B, low allowance: Qwen in/out MTok (central) 14.178 / 0.485; hours central [11.67, 16.81]; hours range [9.43, 30.19]; 27-31B judge [17.91, 66.43]; kWh [0.85, 7.97]; $ [0.13, 1.99]

local thinking 14B, high allowance: Qwen in/out MTok (central) 14.178 / 1.856; hours central [18.38, 21.32]; hours range [14.92, 41.42]; 27-31B judge [28.35, 91.12]; kWh [1.34, 10.93]; $ [0.2, 2.73]

### C:armB:broad: + unresolved + no-hypothesis several rows, pre-#1292
rows 14931; header+dateline+chapter+classifier+career lines

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 1.75 / 2.99 / 5.70 | 4.01 / 7.13 / 14.73 | 8.02 / 14.26 / 33.49 | 2.369 / 4.087 / 11.98 | 0.227 / 0.379 / 0.687 | 1.656 | 1 |
| sonnet-5 | 4.31 / 6.09 / 14.08 | 8.33 / 13.50 / 30.37 | 17.25 / 29.90 / 68.78 | 2.979 / 4.778 / 12.883 | 0.227 / 0.379 / 0.687 | 1.656 | 1 |
| opus-5 | 9.25 / 14.47 / 35.55 | 19.30 / 32.99 / 76.29 | 40.08 / 73.23 / 173 | 2.369 / 4.473 / 13.026 | 0.227 / 0.379 / 0.687 | 1.656 | 1 |

local no-think 14B: Qwen in/out MTok (central) 3.935 / 0.339; hours central [4.67, 4.9]; hours range [2.65, 13.94]; 27-31B judge [5.04, 30.68]; kWh [0.24, 3.68]; $ [0.04, 0.92]

local thinking 14B, low allowance: Qwen in/out MTok (central) 3.935 / 0.5; hours central [5.08, 5.81]; hours range [2.76, 14.3]; 27-31B judge [5.25, 31.47]; kWh [0.25, 3.78]; $ [0.04, 0.94]

local thinking 14B, high allowance: Qwen in/out MTok (central) 3.935 / 1.913; hours central [6.7, 15.76]; hours range [3.69, 34.14]; 27-31B judge [7.0, 75.11]; kWh [0.33, 9.01]; $ [0.05, 2.25]

### C+doc:armB:broad: + unresolved + no-hypothesis several rows, pre-#1292
rows 14931; the same plus the document's R-0 text capped at 8k (low, central) / 20k (high) chars

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 7.13 / 9.02 / 14.96 | 9.39 / 13.15 / 24.00 | 18.77 / 26.31 / 52.02 | 13.126 / 16.135 / 30.511 | 0.227 / 0.379 / 0.687 | 1.656 | 1 |
| sonnet-5 | 18.29 / 21.80 / 38.24 | 22.31 / 29.21 / 54.54 | 45.22 / 61.31 / 117 | 16.963 / 20.483 / 37.048 | 0.227 / 0.379 / 0.687 | 1.656 | 1 |
| opus-5 | 36.14 / 49.70 / 98.18 | 46.20 / 68.22 / 139 | 93.86 / 144 / 298 | 13.126 / 18.564 / 38.08 | 0.227 / 0.379 / 0.687 | 1.656 | 1 |

local no-think 14B: Qwen in/out MTok (central) 14.692 / 0.339; hours central [10.93, 17.23]; hours range [9.07, 30.94]; 27-31B judge [17.24, 68.07]; kWh [0.82, 8.17]; $ [0.12, 2.04]

local thinking 14B, low allowance: Qwen in/out MTok (central) 14.692 / 0.5; hours central [12.07, 17.42]; hours range [9.76, 31.3]; 27-31B judge [18.55, 68.86]; kWh [0.88, 8.26]; $ [0.13, 2.07]

local thinking 14B, high allowance: Qwen in/out MTok (central) 14.692 / 1.913; hours central [19.04, 22.02]; hours range [15.42, 42.77]; 27-31B judge [29.31, 94.09]; kWh [1.39, 11.29]; $ [0.21, 2.82]

### C:armB:broad, post-#1292
rows 14976; header+dateline+chapter+classifier+career lines

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 1.75 / 3.00 / 5.71 | 4.02 / 7.15 / 14.77 | 8.03 / 14.30 / 33.58 | 2.369 / 4.092 / 12.008 | 0.228 / 0.38 / 0.689 | 1.661 | 1 |
| sonnet-5 | 4.31 / 6.10 / 14.11 | 8.35 / 13.53 / 30.45 | 17.29 / 29.98 / 68.96 | 2.978 / 4.782 / 12.912 | 0.228 / 0.38 / 0.689 | 1.661 | 1 |
| opus-5 | 9.26 / 14.49 / 35.63 | 19.35 / 33.07 / 76.48 | 40.17 / 73.42 / 173 | 2.369 / 4.478 / 13.055 | 0.228 / 0.38 / 0.689 | 1.661 | 1 |

local no-think 14B: Qwen in/out MTok (central) 3.94 / 0.34; hours central [4.68, 4.91]; hours range [2.65, 13.98]; 27-31B judge [5.04, 30.75]; kWh [0.24, 3.69]; $ [0.04, 0.92]

local thinking 14B, low allowance: Qwen in/out MTok (central) 3.94 / 0.502; hours central [5.09, 5.82]; hours range [2.76, 14.34]; 27-31B judge [5.25, 31.55]; kWh [0.25, 3.79]; $ [0.04, 0.95]

local thinking 14B, high allowance: Qwen in/out MTok (central) 3.94 / 1.919; hours central [6.72, 15.8]; hours range [3.69, 34.23]; 27-31B judge [7.01, 75.31]; kWh [0.33, 9.04]; $ [0.05, 2.26]

### C+doc:armB:broad, post-#1292
rows 14976; the same plus the document's R-0 text capped at 8k (low, central) / 20k (high) chars

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 7.15 / 9.04 / 15.00 | 9.41 / 13.19 / 24.06 | 18.82 / 26.38 / 52.15 | 13.153 / 16.169 / 30.581 | 0.228 / 0.38 / 0.689 | 1.661 | 1 |
| sonnet-5 | 18.33 / 21.84 / 38.33 | 22.37 / 29.28 / 54.67 | 45.32 / 61.46 / 117 | 16.997 / 20.526 / 37.131 | 0.228 / 0.38 / 0.689 | 1.661 | 1 |
| opus-5 | 36.22 / 49.81 / 98.41 | 46.30 / 68.39 / 139 | 94.09 / 144 / 299 | 13.153 / 18.604 / 38.165 | 0.228 / 0.38 / 0.689 | 1.661 | 1 |

local no-think 14B: Qwen in/out MTok (central) 14.723 / 0.34; hours central [10.96, 17.27]; hours range [9.09, 31.01]; 27-31B judge [17.27, 68.22]; kWh [0.82, 8.19]; $ [0.12, 2.05]

local thinking 14B, low allowance: Qwen in/out MTok (central) 14.723 / 0.502; hours central [12.1, 17.45]; hours range [9.78, 31.37]; 27-31B judge [18.59, 69.02]; kWh [0.88, 8.28]; $ [0.13, 2.07]

local thinking 14B, high allowance: Qwen in/out MTok (central) 14.723 / 1.919; hours central [19.08, 22.08]; hours range [15.46, 42.88]; 27-31B judge [29.38, 94.34]; kWh [1.39, 11.32]; $ [0.21, 2.83]

### C:armA:summary.json pre-#1292 approximation
rows 11175; header+dateline+chapter+classifier+career lines

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 1.30 / 2.22 / 4.26 | 2.99 / 5.32 / 11.02 | 5.98 / 10.64 / 25.04 | 1.75 / 3.031 / 8.944 | 0.17 / 0.284 / 0.514 | 1.238 | 1 |
| sonnet-5 | 3.19 / 4.53 / 10.51 | 6.21 / 10.07 / 22.71 | 12.85 / 22.30 / 51.42 | 2.199 / 3.539 / 9.613 | 0.17 / 0.284 / 0.514 | 1.238 | 1 |
| opus-5 | 6.86 / 10.75 / 26.54 | 14.39 / 24.61 / 57.03 | 29.89 / 54.63 / 129 | 1.75 / 3.315 / 9.719 | 0.17 / 0.284 / 0.514 | 1.238 | 1 |

local no-think 14B: Qwen in/out MTok (central) 2.919 / 0.253; hours central [3.48, 3.64]; hours range [1.96, 10.42]; 27-31B judge [3.72, 22.91]; kWh [0.18, 2.75]; $ [0.03, 0.69]

local thinking 14B, low allowance: Qwen in/out MTok (central) 2.919 / 0.374; hours central [3.78, 4.33]; hours range [2.04, 10.69]; 27-31B judge [3.88, 23.51]; kWh [0.18, 2.82]; $ [0.03, 0.71]

local thinking 14B, high allowance: Qwen in/out MTok (central) 2.919 / 1.431; hours central [4.99, 11.77]; hours range [2.73, 25.54]; 27-31B judge [5.19, 56.19]; kWh [0.25, 6.74]; $ [0.04, 1.69]

### C+doc:armA:summary.json pre-#1292 approximation
rows 11175; the same plus the document's R-0 text capped at 8k (low, central) / 20k (high) chars

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 5.34 / 6.75 / 11.18 | 7.03 / 9.85 / 17.94 | 14.06 / 19.70 / 38.89 | 9.835 / 12.086 / 22.794 | 0.17 / 0.284 / 0.514 | 1.238 | 1 |
| sonnet-5 | 13.70 / 16.33 / 28.57 | 16.72 / 21.87 / 40.77 | 33.87 / 45.91 / 87.54 | 12.709 / 15.343 / 27.674 | 0.17 / 0.284 / 0.514 | 1.238 | 1 |
| opus-5 | 27.08 / 37.23 / 73.35 | 34.61 / 51.08 / 104 | 70.31 / 108 / 223 | 9.835 / 13.906 / 28.445 | 0.17 / 0.284 / 0.514 | 1.238 | 1 |

local no-think 14B: Qwen in/out MTok (central) 11.004 / 0.253; hours central [8.19, 12.91]; hours range [6.8, 23.12]; 27-31B judge [12.91, 50.86]; kWh [0.61, 6.1]; $ [0.09, 1.53]

local thinking 14B, low allowance: Qwen in/out MTok (central) 11.004 / 0.374; hours central [9.04, 13.04]; hours range [7.31, 23.39]; 27-31B judge [13.89, 51.45]; kWh [0.66, 6.17]; $ [0.1, 1.54]

local thinking 14B, high allowance: Qwen in/out MTok (central) 11.004 / 1.431; hours central [14.26, 16.48]; hours range [11.55, 31.99]; 27-31B judge [21.95, 70.37]; kWh [1.04, 8.44]; $ [0.16, 2.11]

### C:armA:post-#1292 re-measure (this directory)
rows 13252; header+dateline+chapter+classifier+career lines

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 1.52 / 2.62 / 5.01 | 3.53 / 6.29 / 13.03 | 7.05 / 12.58 / 29.62 | 2.036 / 3.553 / 10.536 | 0.201 / 0.337 / 0.61 | 1.47 | 1 |
| sonnet-5 | 3.74 / 5.31 / 12.37 | 7.31 / 11.89 / 26.83 | 15.15 / 26.35 / 60.79 | 2.557 / 4.143 / 11.308 | 0.201 / 0.337 / 0.61 | 1.47 | 1 |
| opus-5 | 8.04 / 12.62 / 31.23 | 16.98 / 29.07 / 67.38 | 35.26 / 64.57 / 153 | 2.036 / 3.882 / 11.43 | 0.201 / 0.337 / 0.61 | 1.47 | 1 |

local no-think 14B: Qwen in/out MTok (central) 3.426 / 0.301; hours central [4.11, 4.27]; hours range [2.28, 12.29]; 27-31B judge [4.32, 27.03]; kWh [0.2, 3.24]; $ [0.03, 0.81]

local thinking 14B, low allowance: Qwen in/out MTok (central) 3.426 / 0.444; hours central [4.44, 5.12]; hours range [2.38, 12.61]; 27-31B judge [4.51, 27.74]; kWh [0.21, 3.33]; $ [0.03, 0.83]

local thinking 14B, high allowance: Qwen in/out MTok (central) 3.426 / 1.698; hours central [5.87, 13.95]; hours range [3.2, 30.26]; 27-31B judge [6.07, 66.56]; kWh [0.29, 7.99]; $ [0.04, 2.0]

### C+doc:armA:post-#1292 re-measure (this directory)
rows 13252; the same plus the document's R-0 text capped at 8k (low, central) / 20k (high) chars

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 6.17 / 7.83 / 12.93 | 8.18 / 11.50 / 20.95 | 16.36 / 23.01 / 45.46 | 11.342 / 13.976 / 26.37 | 0.201 / 0.337 / 0.61 | 1.47 | 1 |
| sonnet-5 | 15.84 / 18.90 / 33.02 | 19.41 / 25.47 / 47.48 | 39.34 / 53.52 / 102 | 14.655 / 17.73 / 31.956 | 0.201 / 0.337 / 0.61 | 1.47 | 1 |
| opus-5 | 31.31 / 43.10 / 84.75 | 40.24 / 59.55 / 121 | 81.79 / 126 / 260 | 11.342 / 16.073 / 32.838 | 0.201 / 0.337 / 0.61 | 1.47 | 1 |

local no-think 14B: Qwen in/out MTok (central) 12.732 / 0.301; hours central [9.53, 14.94]; hours range [7.87, 26.81]; 27-31B judge [14.96, 58.98]; kWh [0.71, 7.08]; $ [0.11, 1.77]

local thinking 14B, low allowance: Qwen in/out MTok (central) 12.732 / 0.444; hours central [10.53, 15.1]; hours range [8.48, 27.13]; 27-31B judge [16.12, 59.68]; kWh [0.76, 7.16]; $ [0.11, 1.79]

local thinking 14B, high allowance: Qwen in/out MTok (central) 12.732 / 1.698; hours central [16.54, 19.36]; hours range [13.52, 37.63]; 27-31B judge [25.68, 82.78]; kWh [1.22, 9.93]; $ [0.18, 2.48]

### C:armA:broad: + unresolved + no-hypothesis several rows, pre-#1292
rows 14388; header+dateline+chapter+classifier+career lines

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 1.63 / 2.82 / 5.39 | 3.80 / 6.80 / 14.10 | 7.60 / 13.61 / 32.07 | 2.163 / 3.803 / 11.349 | 0.219 / 0.365 / 0.662 | 1.595 | 1 |
| sonnet-5 | 4.00 / 5.70 / 13.31 | 7.87 / 12.83 / 29.01 | 16.31 / 28.46 / 65.76 | 2.714 / 4.428 / 12.162 | 0.219 / 0.365 / 0.662 | 1.595 | 1 |
| opus-5 | 8.61 / 13.55 / 33.60 | 18.30 / 31.40 / 72.85 | 38.02 / 69.77 / 165 | 2.163 / 4.152 / 12.29 | 0.219 / 0.365 / 0.662 | 1.595 | 1 |

local no-think 14B: Qwen in/out MTok (central) 3.671 / 0.326; hours central [4.43, 4.58]; hours range [2.42, 13.26]; 27-31B judge [4.59, 29.17]; kWh [0.22, 3.5]; $ [0.03, 0.88]

local thinking 14B, low allowance: Qwen in/out MTok (central) 3.671 / 0.482; hours central [4.76, 5.53]; hours range [2.53, 13.6]; 27-31B judge [4.8, 29.93]; kWh [0.23, 3.59]; $ [0.03, 0.9]

local thinking 14B, high allowance: Qwen in/out MTok (central) 3.671 / 1.843; hours central [6.32, 15.11]; hours range [3.41, 32.8]; 27-31B judge [6.49, 72.16]; kWh [0.31, 8.66]; $ [0.05, 2.16]

### C+doc:armA:broad: + unresolved + no-hypothesis several rows, pre-#1292
rows 14388; the same plus the document's R-0 text capped at 8k (low, central) / 20k (high) chars

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 6.75 / 8.55 / 14.14 | 8.92 / 12.53 / 22.85 | 17.84 / 25.07 / 49.56 | 12.399 / 15.268 / 28.844 | 0.219 / 0.365 / 0.662 | 1.595 | 1 |
| sonnet-5 | 17.30 / 20.64 / 36.13 | 21.18 / 27.78 / 51.83 | 42.92 / 58.35 / 111 | 16.021 / 19.373 / 34.975 | 0.219 / 0.365 / 0.662 | 1.595 | 1 |
| opus-5 | 34.20 / 47.07 / 92.74 | 43.89 / 64.92 / 132 | 89.20 / 137 / 283 | 12.399 / 17.561 / 35.943 | 0.219 / 0.365 / 0.662 | 1.595 | 1 |

local no-think 14B: Qwen in/out MTok (central) 13.907 / 0.326; hours central [10.39, 16.32]; hours range [8.6, 29.3]; 27-31B judge [16.33, 64.47]; kWh [0.77, 7.74]; $ [0.12, 1.93]

local thinking 14B, low allowance: Qwen in/out MTok (central) 13.907 / 0.482; hours central [11.48, 16.49]; hours range [9.26, 29.65]; 27-31B judge [17.6, 65.23]; kWh [0.83, 7.83]; $ [0.13, 1.96]

local thinking 14B, high allowance: Qwen in/out MTok (central) 13.907 / 1.843; hours central [18.06, 21.07]; hours range [14.72, 40.95]; 27-31B judge [27.96, 90.08]; kWh [1.32, 10.81]; $ [0.2, 2.7]

### C:armA:broad, post-#1292
rows 14529; header+dateline+chapter+classifier+career lines

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 1.66 / 2.86 / 5.48 | 3.86 / 6.89 / 14.27 | 7.71 / 13.78 / 32.44 | 2.219 / 3.88 / 11.517 | 0.221 / 0.369 / 0.668 | 1.611 | 1 |
| sonnet-5 | 4.08 / 5.80 / 13.52 | 7.99 / 13.01 / 29.37 | 16.56 / 28.85 / 66.55 | 2.786 / 4.523 / 12.355 | 0.221 / 0.369 / 0.668 | 1.611 | 1 |
| opus-5 | 8.78 / 13.80 / 34.12 | 18.57 / 31.82 / 73.75 | 38.57 / 70.70 / 167 | 2.219 / 4.239 / 12.487 | 0.221 / 0.369 / 0.668 | 1.611 | 1 |

local no-think 14B: Qwen in/out MTok (central) 3.742 / 0.33; hours central [4.5, 4.67]; hours range [2.48, 13.44]; 27-31B judge [4.71, 29.57]; kWh [0.22, 3.55]; $ [0.03, 0.89]

local thinking 14B, low allowance: Qwen in/out MTok (central) 3.742 / 0.487; hours central [4.85, 5.6]; hours range [2.59, 13.79]; 27-31B judge [4.92, 30.34]; kWh [0.23, 3.64]; $ [0.03, 0.91]

local thinking 14B, high allowance: Qwen in/out MTok (central) 3.742 / 1.862; hours central [6.42, 15.28]; hours range [3.49, 33.15]; 27-31B judge [6.63, 72.92]; kWh [0.31, 8.75]; $ [0.05, 2.19]

### C+doc:armA:broad, post-#1292
rows 14529; the same plus the document's R-0 text capped at 8k (low, central) / 20k (high) chars

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 6.82 / 8.64 / 14.29 | 9.02 / 12.67 / 23.08 | 18.03 / 25.34 / 50.07 | 12.535 / 15.435 / 29.148 | 0.221 / 0.369 / 0.668 | 1.611 | 1 |
| sonnet-5 | 17.49 / 20.86 / 36.51 | 21.41 / 28.08 / 52.36 | 43.38 / 58.97 / 113 | 16.197 / 19.585 / 35.345 | 0.221 / 0.369 / 0.668 | 1.611 | 1 |
| opus-5 | 34.57 / 47.58 / 93.72 | 44.36 / 65.61 / 133 | 90.15 / 138 / 286 | 12.535 / 17.754 / 36.324 | 0.221 / 0.369 / 0.668 | 1.611 | 1 |

local no-think 14B: Qwen in/out MTok (central) 14.059 / 0.33; hours central [10.5, 16.49]; hours range [8.69, 29.61]; 27-31B judge [16.51, 65.14]; kWh [0.78, 7.82]; $ [0.12, 1.95]

local thinking 14B, low allowance: Qwen in/out MTok (central) 14.059 / 0.487; hours central [11.61, 16.67]; hours range [9.36, 29.96]; 27-31B judge [17.79, 65.91]; kWh [0.84, 7.91]; $ [0.13, 1.98]

local thinking 14B, high allowance: Qwen in/out MTok (central) 14.059 / 1.862; hours central [18.25, 21.29]; hours range [14.87, 41.35]; 27-31B judge [28.26, 90.98]; kWh [1.34, 10.92]; $ [0.2, 2.73]

### D:volume-guide
one ~1,500-word guide per volume; input low = top-150 list + 40 headers, central = full list + 40 headers, high = full list + 100 headers

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 1.82 / 2.29 / 2.68 | 5.41 / 6.20 / 6.92 | 10.82 / 12.39 / 14.56 | 1.042 / 1.684 / 2.84 | 0.518 / 0.581 / 0.648 | 1.562 | 1 |
| sonnet-5 | 5.51 / 6.36 / 8.13 | 13.11 / 14.66 / 17.18 | 26.75 / 30.61 / 35.78 | 1.264 / 1.949 / 3.214 | 0.674 / 0.757 / 0.845 | 1.914 | 1 |
| opus-5 | 10.70 / 14.34 / 20.97 | 26.39 / 33.44 / 44.26 | 54.10 / 70.10 / 92.08 | 1.042 / 1.832 / 3.273 | 0.518 / 0.679 / 0.876 | 1.759 | 1 |

local no-think 14B: Qwen in/out MTok (central) 1.631 / 0.518; hours central [2.46, 4.6]; hours range [1.5, 5.18]; 27-31B judge [2.85, 11.4]; kWh [0.13, 1.37]; $ [0.02, 0.34]

local thinking 14B, low allowance: Qwen in/out MTok (central) 1.631 / 0.701; hours central [2.67, 5.88]; hours range [1.71, 6.47]; 27-31B judge [3.25, 14.22]; kWh [0.15, 1.71]; $ [0.02, 0.43]

local thinking 14B, high allowance: Qwen in/out MTok (central) 1.631 / 1.956; hours central [4.11, 14.72]; hours range [3.15, 15.3]; 27-31B judge [5.98, 33.66]; kWh [0.28, 4.04]; $ [0.04, 1.01]

### D:chapter-guide-1500w
one ~1,500-word guide per chapter that carries at least one marked row

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 55.71 / 71.17 / 79.21 | 190 / 217 / 237 | 379 / 433 / 501 | 14.79 / 34.128 / 64.45 | 19.324 / 21.643 / 24.155 | 58.217 | 1 |
| sonnet-5 | 174 / 200 / 249 | 457 / 509 / 586 | 935 / 1,066 / 1,226 | 15.853 / 35.332 / 65.796 | 25.122 / 28.214 / 31.499 | 71.358 | 1 |
| opus-5 | 339 / 450 / 641 | 924 / 1,163 / 1,509 | 1,897 / 2,446 / 3,153 | 14.79 / 34.801 / 66.009 | 19.324 / 25.315 / 32.658 | 65.561 | 1 |

local no-think 14B: Qwen in/out MTok (central) 35.226 / 19.324; hours central [62.54, 156.54]; hours range [28.3, 173.92]; 27-31B judge [53.77, 382.62]; kWh [2.55, 45.91]; $ [0.38, 11.48]

local thinking 14B, low allowance: Qwen in/out MTok (central) 35.226 / 26.117; hours central [70.32, 204.36]; hours range [36.09, 221.74]; 27-31B judge [68.57, 487.82]; kWh [3.25, 58.54]; $ [0.49, 14.63]

local thinking 14B, high allowance: Qwen in/out MTok (central) 35.226 / 72.904; hours central [123.96, 533.73]; hours range [89.73, 551.11]; 27-31B judge [170.48, 1212.44]; kWh [8.08, 145.49]; $ [1.21, 36.37]

### D:chapter-guide-500w-ge5docs
one ~500-word note per chapter with >= 5 documents and at least one marked row

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 16.01 / 23.79 / 26.41 | 62.45 / 72.82 / 78.23 | 125 / 146 / 174 | 10.497 / 23.488 / 43.823 | 4.303 / 4.819 / 5.378 | 19.612 | 1 |
| sonnet-5 | 44.50 / 52.53 / 75.97 | 139 / 152 / 182 | 290 / 337 / 400 | 11.392 / 24.503 / 44.957 | 5.594 / 6.282 / 7.013 | 22.537 | 1 |
| opus-5 | 88.04 / 120 / 195 | 296 / 356 / 465 | 625 / 792 / 1,020 | 10.497 / 24.055 / 45.136 | 4.303 / 5.637 / 7.272 | 21.247 | 1 |

local no-think 14B: Qwen in/out MTok (central) 24.148 / 4.303; hours central [32.62, 44.34]; hours range [9.75, 55.95]; 27-31B judge [18.52, 123.09]; kWh [0.88, 14.77]; $ [0.13, 3.69]

local thinking 14B, low allowance: Qwen in/out MTok (central) 24.148 / 6.258; hours central [34.86, 58.11]; hours range [11.99, 69.72]; 27-31B judge [22.78, 153.38]; kWh [1.08, 18.41]; $ [0.16, 4.6]

local thinking 14B, high allowance: Qwen in/out MTok (central) 24.148 / 22.882; hours central [53.91, 175.14]; hours range [31.05, 186.74]; 27-31B judge [58.99, 410.84]; kWh [2.79, 49.3]; $ [0.42, 12.33]

### E:A-pilot-64docs
the adjudication queue on the 64 keyed M2a documents

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 0.02 / 0.03 / 0.16 | 0.03 / 0.05 / 0.25 | 0.05 / 0.10 / 0.65 | 0.023 / 0.041 / 0.413 | 0.002 / 0.004 / 0.009 | 0.007 | 1 |
| sonnet-5 | 0.04 / 0.06 / 0.35 | 0.06 / 0.10 / 0.52 | 0.12 / 0.21 / 1.33 | 0.029 / 0.048 / 0.434 | 0.002 / 0.004 / 0.009 | 0.007 | 1 |
| opus-5 | 0.08 / 0.15 / 0.90 | 0.12 / 0.23 / 1.34 | 0.25 / 0.52 / 3.41 | 0.023 / 0.045 / 0.437 | 0.002 / 0.004 / 0.01 | 0.007 | 1 |

local no-think 14B: Qwen in/out MTok (central) 0.04 / 0.004; hours central [0.05, 0.05]; hours range [0.03, 0.48]; 27-31B judge [0.05, 1.05]; kWh [0.0, 0.13]; $ [0.0, 0.03]

local thinking 14B, low allowance: Qwen in/out MTok (central) 0.04 / 0.005; hours central [0.05, 0.06]; hours range [0.03, 0.48]; 27-31B judge [0.05, 1.06]; kWh [0.0, 0.13]; $ [0.0, 0.03]

local thinking 14B, high allowance: Qwen in/out MTok (central) 0.04 / 0.011; hours central [0.06, 0.1]; hours range [0.03, 0.54]; 27-31B judge [0.06, 1.19]; kWh [0.0, 0.14]; $ [0.0, 0.04]

### E:B-pilot-64docs
the agreement arm on the 64 keyed M2a documents

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 0.02 / 0.03 / 0.15 | 0.02 / 0.04 / 0.25 | 0.05 / 0.09 / 0.65 | 0.021 / 0.036 / 0.411 | 0.002 / 0.004 / 0.009 | 0.007 | 1 |
| sonnet-5 | 0.04 / 0.06 / 0.33 | 0.05 / 0.09 / 0.51 | 0.11 / 0.19 / 1.32 | 0.026 / 0.042 / 0.426 | 0.002 / 0.004 / 0.009 | 0.007 | 1 |
| opus-5 | 0.07 / 0.14 / 0.86 | 0.11 / 0.21 / 1.30 | 0.23 / 0.46 / 3.38 | 0.021 / 0.039 / 0.428 | 0.002 / 0.004 / 0.01 | 0.007 | 1 |

local no-think 14B: Qwen in/out MTok (central) 0.034 / 0.004; hours central [0.04, 0.05]; hours range [0.02, 0.48]; 27-31B judge [0.04, 1.05]; kWh [0.0, 0.13]; $ [0.0, 0.03]

local thinking 14B, low allowance: Qwen in/out MTok (central) 0.034 / 0.004; hours central [0.04, 0.05]; hours range [0.02, 0.48]; 27-31B judge [0.04, 1.06]; kWh [0.0, 0.13]; $ [0.0, 0.03]

local thinking 14B, high allowance: Qwen in/out MTok (central) 0.034 / 0.01; hours central [0.05, 0.09]; hours range [0.03, 0.55]; 27-31B judge [0.05, 1.2]; kWh [0.0, 0.14]; $ [0.0, 0.04]

### E:C-pilot-100rows
the 100 pre-1910 rows of m1a-eval-candidates.csv, arm-B payload

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 0.01 / 0.02 / 0.04 | 0.03 / 0.05 / 0.10 | 0.06 / 0.10 / 0.23 | 0.017 / 0.029 / 0.084 | 0.002 / 0.003 / 0.005 | 0.011 | 1 |
| sonnet-5 | 0.03 / 0.05 / 0.11 | 0.06 / 0.10 / 0.22 | 0.12 / 0.20 / 0.47 | 0.022 / 0.034 / 0.091 | 0.002 / 0.003 / 0.005 | 0.011 | 1 |
| opus-5 | 0.07 / 0.11 / 0.27 | 0.14 / 0.23 / 0.54 | 0.28 / 0.50 / 1.18 | 0.017 / 0.032 / 0.092 | 0.002 / 0.003 / 0.005 | 0.011 | 1 |

local no-think 14B: Qwen in/out MTok (central) 0.028 / 0.002; hours central [0.03, 0.03]; hours range [0.02, 0.1]; 27-31B judge [0.04, 0.21]; kWh [0.0, 0.03]; $ [0.0, 0.01]

local thinking 14B, low allowance: Qwen in/out MTok (central) 0.028 / 0.003; hours central [0.04, 0.04]; hours range [0.02, 0.1]; 27-31B judge [0.04, 0.22]; kWh [0.0, 0.03]; $ [0.0, 0.01]

local thinking 14B, high allowance: Qwen in/out MTok (central) 0.028 / 0.013; hours central [0.05, 0.11]; hours range [0.03, 0.23]; 27-31B judge [0.05, 0.51]; kWh [0.0, 0.06]; $ [0.0, 0.02]

### E:C+doc-pilot-100rows
the same plus document text capped 8k / 8k / 20k

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 0.05 / 0.06 / 0.10 | 0.06 / 0.09 / 0.16 | 0.12 / 0.17 / 0.34 | 0.085 / 0.105 / 0.197 | 0.002 / 0.003 / 0.005 | 0.011 | 1 |
| sonnet-5 | 0.12 / 0.15 / 0.25 | 0.15 / 0.20 / 0.36 | 0.30 / 0.40 / 0.77 | 0.11 / 0.134 / 0.239 | 0.002 / 0.003 / 0.005 | 0.011 | 1 |
| opus-5 | 0.24 / 0.33 / 0.65 | 0.31 / 0.46 / 0.93 | 0.62 / 0.95 / 1.95 | 0.085 / 0.121 / 0.246 | 0.002 / 0.003 / 0.005 | 0.011 | 1 |

local no-think 14B: Qwen in/out MTok (central) 0.096 / 0.002; hours central [0.07, 0.11]; hours range [0.06, 0.2]; 27-31B judge [0.11, 0.44]; kWh [0.01, 0.05]; $ [0.0, 0.01]

local thinking 14B, low allowance: Qwen in/out MTok (central) 0.096 / 0.003; hours central [0.08, 0.11]; hours range [0.06, 0.2]; 27-31B judge [0.12, 0.45]; kWh [0.01, 0.05]; $ [0.0, 0.01]

local thinking 14B, high allowance: Qwen in/out MTok (central) 0.096 / 0.013; hours central [0.12, 0.15]; hours range [0.1, 0.28]; 27-31B judge [0.19, 0.62]; kWh [0.01, 0.07]; $ [0.0, 0.02]

### E:D-pilot-volume-guides:pilot_gold_volumes
the 24 M2a volumes

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 0.16 / 0.21 / 0.24 | 0.49 / 0.56 / 0.62 | 0.97 / 1.11 / 1.30 | 0.096 / 0.149 / 0.251 | 0.047 / 0.052 / 0.058 | 0.14 | 1 |
| sonnet-5 | 0.50 / 0.57 / 0.73 | 1.18 / 1.32 / 1.55 | 2.41 / 2.75 / 3.21 | 0.116 / 0.173 / 0.283 | 0.061 / 0.068 / 0.076 | 0.172 | 1 |
| opus-5 | 0.97 / 1.29 / 1.89 | 2.38 / 3.01 / 3.98 | 4.87 / 6.29 / 8.25 | 0.096 / 0.162 / 0.289 | 0.047 / 0.061 / 0.079 | 0.158 | 1 |

local no-think 14B: Qwen in/out MTok (central) 0.145 / 0.047; hours central [0.22, 0.41]; hours range [0.14, 0.46]; 27-31B judge [0.26, 1.02]; kWh [0.01, 0.12]; $ [0.0, 0.03]

local thinking 14B, low allowance: Qwen in/out MTok (central) 0.145 / 0.063; hours central [0.24, 0.53]; hours range [0.16, 0.58]; 27-31B judge [0.3, 1.27]; kWh [0.01, 0.15]; $ [0.0, 0.04]

local thinking 14B, high allowance: Qwen in/out MTok (central) 0.145 / 0.176; hours central [0.37, 1.32]; hours range [0.28, 1.37]; 27-31B judge [0.54, 3.02]; kWh [0.03, 0.36]; $ [0.0, 0.09]

### E:D-pilot-volume-guides:pilot_identity_volumes
the 4 identity-sample volumes

| model | batch+cached, low effort $ L/C/H | batch+cached, high effort $ L/C/H | standard, uncached, high effort $ L/C/H | input MTok L/C/H | visible out MTok L/C/H | think(high) MTok C | batches C |
|---|---|---|---|---|---|---|---|
| haiku-4.5 | 0.03 / 0.04 / 0.04 | 0.08 / 0.09 / 0.11 | 0.16 / 0.19 / 0.22 | 0.018 / 0.027 / 0.043 | 0.008 / 0.009 / 0.01 | 0.023 | 1 |
| sonnet-5 | 0.09 / 0.10 / 0.13 | 0.20 / 0.23 / 0.26 | 0.41 / 0.46 / 0.54 | 0.022 / 0.032 / 0.048 | 0.01 / 0.011 / 0.013 | 0.029 | 1 |
| opus-5 | 0.17 / 0.23 / 0.33 | 0.40 / 0.52 / 0.68 | 0.82 / 1.06 / 1.38 | 0.018 / 0.03 / 0.049 | 0.008 / 0.01 / 0.013 | 0.026 | 1 |

local no-think 14B: Qwen in/out MTok (central) 0.026 / 0.008; hours central [0.04, 0.07]; hours range [0.03, 0.08]; 27-31B judge [0.05, 0.17]; kWh [0.0, 0.02]; $ [0.0, 0.01]

local thinking 14B, low allowance: Qwen in/out MTok (central) 0.026 / 0.01; hours central [0.04, 0.09]; hours range [0.03, 0.1]; 27-31B judge [0.05, 0.21]; kWh [0.0, 0.03]; $ [0.0, 0.01]

local thinking 14B, high allowance: Qwen in/out MTok (central) 0.026 / 0.029; hours central [0.06, 0.22]; hours range [0.05, 0.23]; 27-31B judge [0.09, 0.5]; kWh [0.0, 0.06]; $ [0.0, 0.02]
