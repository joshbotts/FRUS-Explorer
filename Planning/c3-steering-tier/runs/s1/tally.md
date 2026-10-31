| agent | model | input | cache write | cache read | output | tool calls | records | wall clock |
|---|---|---|---|---|---|---|---|---|
| refute:s1 | claude-fable-5-1 | 1,754 | 637,536 | 9,894,091 | 169,605 | 27 | 155 | 13.1 min |
| run:s1 | claude-sonnet-5-5 | 380 | 860,475 | 45,880,973 | 250,199 | 100 | 410 | 22.4 min |
| judge:s1 | claude-fable-5-1 | 465 | 587,835 | 1,665,065 | 64,316 | 15 | 60 | 4.2 min |
| score:s1 | claude-fable-5-1 | 1,193 | 1,227,703 | 5,472,901 | 352,497 | 27 | 101 | 12.6 min |
TOTAL input 3,792; cache write 3,313,549; cache read 62,913,030; output 836,617; tool calls 169
