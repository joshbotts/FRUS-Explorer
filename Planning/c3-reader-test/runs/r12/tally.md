| agent | model | input | cache write | cache read | output | tool calls | records | wall clock |
|---|---|---|---|---|---|---|---|---|
| run:r12 | claude-sonnet-5-5 | 638 | 1,456,483 | 117,349,277 | 537,350 | 222 | 1037 | 32.4 min |
| score:r12 | claude-fable-5-1 | 1,350 | 1,427,907 | 5,282,573 | 332,583 | 32 | 125 | 11.4 min |
| refute:r12 | claude-fable-5-1 | 1,766 | 1,381,686 | 8,409,540 | 418,862 | 40 | 158 | 14.5 min |
| judge:r12 | claude-fable-5-1 | 744 | 1,802,911 | 2,175,291 | 100,978 | 32 | 91 | 7.7 min |
TOTAL input 4,498; cache write 6,068,987; cache read 133,216,681; output 1,389,773; tool calls 326
