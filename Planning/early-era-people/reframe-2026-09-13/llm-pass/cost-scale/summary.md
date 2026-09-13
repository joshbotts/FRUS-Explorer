
### A  ($ low / central / high)
| model | std, no cache, low eff | std, no cache, high eff | batch, no cache, low | batch, cached, low | batch, cached, high | tokens central: in / out / think(low) / think(high) MTok |
|---|---|---|---|---|---|---|
| haiku-4.5 | 250 / 425 / 1,888 | 378 / 663 / 2,887 | 125 / 213 / 944 | 125 / 213 / 676 | 189 / 332 / 1,175 | 280.6 / 28.9 / 0.0 / 47.6 |
| sonnet-5 | 653 / 1,056 / 4,410 | 913 / 1,532 / 6,471 | 326 / 528 / 2,205 | 307 / 438 / 1,669 | 437 / 675 / 2,699 | 330.5 / 34.2 / 5.3 / 52.8 |
| opus-5 | 1,315 / 2,466 / 11,196 | 1,888 / 3,603 / 16,452 | 658 / 1,233 / 5,598 | 609 / 1,007 / 4,257 | 895 / 1,575 / 6,885 | 308.5 / 31.9 / 5.1 / 50.5 |
batches needed (low/central/high scenario, by 100k-request and 256 MB caps): haiku-4.5 [3, 5, 20], sonnet-5 [3, 4, 16], opus-5 [3, 5, 16]
requests: [19668, 37277, 199163] ; body MB (sonnet-5): [780, 1072, 4249]

### B  ($ low / central / high)
| model | std, no cache, low eff | std, no cache, high eff | batch, no cache, low | batch, cached, low | batch, cached, high | tokens central: in / out / think(low) / think(high) MTok |
|---|---|---|---|---|---|---|
| haiku-4.5 | 265 / 471 / 1,722 | 396 / 735 / 2,525 | 132 / 235 / 861 | 132 / 235 / 593 | 198 / 368 / 994 | 300.0 / 34.2 / 0.0 / 52.8 |
| sonnet-5 | 649 / 1,107 / 3,733 | 886 / 1,582 / 5,179 | 325 / 553 / 1,867 | 305 / 463 / 1,330 | 424 / 701 / 2,053 | 355.9 / 34.2 / 5.3 / 52.8 |
| opus-5 | 1,339 / 2,643 / 9,628 | 1,891 / 3,832 / 13,443 | 669 / 1,322 / 4,814 | 621 / 1,095 / 3,473 | 897 / 1,690 / 5,381 | 331.2 / 34.2 / 5.3 / 52.8 |
batches needed (low/central/high scenario, by 100k-request and 256 MB caps): haiku-4.5 [4, 5, 21], sonnet-5 [4, 5, 17], opus-5 [4, 5, 16]
requests: [19668, 37277, 199163] ; body MB (sonnet-5): [828, 1157, 4360]

### C_marked_all  ($ low / central / high)
| model | std, no cache, low eff | std, no cache, high eff | batch, no cache, low | batch, cached, low | batch, cached, high | tokens central: in / out / think(low) / think(high) MTok |
|---|---|---|---|---|---|---|
| haiku-4.5 | 7 / 13 / 33 | 16 / 30 / 70 | 4 / 6 / 16 | 4 / 6 / 12 | 8 / 15 / 31 | 9.0 / 0.8 / 0.0 / 3.4 |
| sonnet-5 | 18 / 33 / 77 | 35 / 63 / 144 | 9 / 16 / 39 | 9 / 13 / 31 | 17 / 28 / 64 | 10.7 / 0.8 / 0.4 / 3.4 |
| opus-5 | 40 / 78 / 196 | 81 / 153 / 361 | 20 / 39 / 98 | 19 / 32 / 77 | 39 / 69 / 160 | 9.9 / 0.8 / 0.4 / 3.4 |
batches needed (low/central/high scenario, by 100k-request and 256 MB caps): haiku-4.5 [1, 1, 1], sonnet-5 [1, 1, 1], opus-5 [1, 1, 1]
requests: [607, 1214, 3033] ; body MB (sonnet-5): [22, 35, 83]

### C_union_all  ($ low / central / high)
| model | std, no cache, low eff | std, no cache, high eff | batch, no cache, low | batch, cached, low | batch, cached, high | tokens central: in / out / think(low) / think(high) MTok |
|---|---|---|---|---|---|---|
| haiku-4.5 | 71 / 135 / 355 | 174 / 324 / 767 | 36 / 67 / 178 | 36 / 67 / 132 | 87 / 162 / 338 | 91.6 / 8.7 / 0.0 / 37.7 |
| sonnet-5 | 187 / 340 / 835 | 370 / 678 / 1,579 | 94 / 170 / 418 | 87 / 137 / 326 | 178 / 306 / 698 | 106.9 / 8.7 / 4.0 / 37.7 |
| opus-5 | 411 / 816 / 2,105 | 870 / 1,660 / 3,963 | 206 / 408 / 1,053 | 189 / 325 / 823 | 418 / 748 / 1,752 | 100.1 / 8.7 / 4.0 / 37.7 |
batches needed (low/central/high scenario, by 100k-request and 256 MB caps): haiku-4.5 [1, 2, 4], sonnet-5 [1, 2, 4], opus-5 [1, 2, 4]
requests: [6813, 13625, 34062] ; body MB (sonnet-5): [209, 352, 880]

### C_marked_live  ($ low / central / high)
| model | std, no cache, low eff | std, no cache, high eff | batch, no cache, low | batch, cached, low | batch, cached, high | tokens central: in / out / think(low) / think(high) MTok |
|---|---|---|---|---|---|---|
| haiku-4.5 | 2 / 4 / 10 | 5 / 9 / 20 | 1 / 2 / 5 | 1 / 2 / 4 | 2 / 4 / 9 | 3.0 / 0.2 / 0.0 / 0.9 |
| sonnet-5 | 6 / 10 / 23 | 11 / 19 / 41 | 3 / 5 / 12 | 3 / 4 / 9 | 5 / 8 / 18 | 3.6 / 0.2 / 0.1 / 0.9 |
| opus-5 | 13 / 25 / 58 | 24 / 45 / 104 | 7 / 12 / 29 | 6 / 10 / 24 | 12 / 21 / 46 | 3.4 / 0.2 / 0.1 / 0.9 |
batches needed (low/central/high scenario, by 100k-request and 256 MB caps): haiku-4.5 [1, 1, 1], sonnet-5 [1, 1, 1], opus-5 [1, 1, 1]
requests: [166, 332, 830] ; body MB (sonnet-5): [8, 12, 25]

### C_union_live  ($ low / central / high)
| model | std, no cache, low eff | std, no cache, high eff | batch, no cache, low | batch, cached, low | batch, cached, high | tokens central: in / out / think(low) / think(high) MTok |
|---|---|---|---|---|---|---|
| haiku-4.5 | 6 / 11 / 26 | 13 / 23 / 54 | 3 / 5 / 13 | 3 / 5 / 10 | 7 / 12 / 24 | 7.8 / 0.6 / 0.0 / 2.5 |
| sonnet-5 | 16 / 27 / 62 | 28 / 50 / 112 | 8 / 14 / 31 | 8 / 11 / 25 | 14 / 23 / 50 | 9.4 / 0.6 / 0.3 / 2.5 |
| opus-5 | 34 / 65 / 156 | 65 / 121 / 280 | 17 / 32 / 78 | 16 / 27 / 62 | 31 / 55 / 125 | 8.7 / 0.6 / 0.3 / 2.5 |
batches needed (low/central/high scenario, by 100k-request and 256 MB caps): haiku-4.5 [1, 1, 1], sonnet-5 [1, 1, 1], opus-5 [1, 1, 1]
requests: [458, 915, 2286] ; body MB (sonnet-5): [20, 31, 67]