| agent | model | input | cache write | cache read | output | tool calls | records | wall clock |
|---|---|---|---|---|---|---|---|---|
| refute:s3 | claude-fable-5-1 | 2,552 | 1,461,919 | 13,603,726 | 193,829 | 36 | 212 | 30.4 min |
| judge:s3 | claude-fable-5-1 | 600 | 1,078,296 | 1,764,837 | 117,867 | 18 | 68 | 8.3 min |
| run:s3 | claude-opus-5-5 | 172 | 426,806 | 13,269,347 | 109,517 | 44 | 196 | 13.1 min |
| score:s3 | claude-fable-5-1 | 1,094 | 1,847,357 | 3,760,967 | 393,355 | 26 | 95 | 15.1 min |
TOTAL input 4,418; cache write 4,814,378; cache read 32,398,877; output 814,568; tool calls 124
