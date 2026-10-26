| agent | model | input | cache write | cache read | output | tool calls | records | wall clock |
|---|---|---|---|---|---|---|---|---|
| run:r3 | claude-sonnet-5-5 | 294 | 713,720 | 29,021,416 | 180,890 | 79 | 478 | 13.5 min |
| score:r3 | claude-fable-5-1 | 936 | 1,895,838 | 2,914,103 | 259,451 | 21 | 98 | 13.8 min |
| refute:r3 | claude-fable-5-1 | 1,958 | 575,517 | 9,714,412 | 166,099 | 28 | 220 | 13.8 min |
| judge:r3 | claude-fable-5-1 | 360 | 475,119 | 1,136,080 | 52,102 | 9 | 60 | 4.6 min |
TOTAL input 3,548; cache write 3,660,194; cache read 42,786,011; output 658,542; tool calls 137
