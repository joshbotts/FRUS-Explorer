| agent | model | input | cache write | cache read | output | tool calls | records | wall clock |
|---|---|---|---|---|---|---|---|---|
| run:r10 | claude-opus-5-5 | 926 | 1,565,242 | 225,015,584 | 676,754 | 244 | 1457 | 77.9 min |
| score:r10 | claude-fable-5-1 | 1,480 | 1,127,172 | 7,028,785 | 246,237 | 41 | 149 | 12.1 min |
| judge:r10 | claude-fable-5-1 | 872 | 1,617,616 | 3,020,736 | 168,300 | 32 | 104 | 9.2 min |
| refute:r10 | claude-fable-5-1 | 1,926 | 1,234,690 | 9,270,553 | 290,400 | 44 | 172 | 11.4 min |
TOTAL input 5,204; cache write 5,544,720; cache read 244,335,658; output 1,381,691; tool calls 361
