| agent | model | input | cache write | cache read | output | tool calls | records | wall clock |
|---|---|---|---|---|---|---|---|---|
| refute:r5 | claude-fable-5-1 | 1,766 | 1,178,141 | 8,407,295 | 320,271 | 43 | 159 | 13.2 min |
| run:r5 | claude-sonnet-5-5 | 640 | 1,223,009 | 99,391,264 | 423,009 | 171 | 1021 | 30.5 min |
| score:r5 | claude-fable-5-1 | 1,224 | 1,249,869 | 4,973,849 | 301,091 | 36 | 122 | 12.6 min |
| judge:r5 | claude-fable-5-1 | 616 | 648,574 | 2,220,815 | 68,321 | 13 | 76 | 5.5 min |
TOTAL input 4,246; cache write 4,299,593; cache read 114,993,223; output 1,112,692; tool calls 263
