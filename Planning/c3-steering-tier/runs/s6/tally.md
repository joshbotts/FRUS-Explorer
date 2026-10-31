| agent | model | input | cache write | cache read | output | tool calls | records | wall clock |
|---|---|---|---|---|---|---|---|---|
| score:s6 | claude-fable-5-1 | 1,028 | 1,162,769 | 4,686,115 | 366,773 | 25 | 92 | 14.1 min |
| run:s6 | claude-sonnet-5-5 | 338 | 745,904 | 40,116,324 | 276,392 | 91 | 375 | 21.6 min |
| judge:s6 | claude-fable-5-1 | 235 | 497,820 | 718,577 | 73,894 | 9 | 45 | 4.7 min |
| refute:s6 | claude-fable-5-1 | 2,181 | 953,529 | 13,170,153 | 284,610 | 38 | 173 | 16.6 min |
TOTAL input 3,782; cache write 3,360,022; cache read 58,691,169; output 1,001,669; tool calls 163
