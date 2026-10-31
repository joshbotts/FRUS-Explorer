Refuter scratch for cell f5 (2026-10-31). Scripts and their outputs:
  quote_check.py / .out        segment-strict quotation check: 30 overview quotations + 39 excerpts, 0 failures
  numbers_check.py / .out      headline figures, M4, M3 controls, M11, section 3, prose facts (80 million, 14 steps, 28 leaders, 65%)
  archival_check.py / .out     20 identifiers against central-files / series-facts / accession-series / document_sources: 20 confirmed; d81 source note = Kennedy Library
  vector_rerun.py / .out       own decode of the index segments; digests; nn lists for d122, d31, d105 reproduce in order; map, near-dups, baselines
  vecjoin_rerun.out            Operation 2 (82 neighbours, decades, sources) and Operation 3 centroids reproduce
  reach_check.py / .out        15 URL-cited documents vs every logged MATCH/LIKE/NEAR/regex-filter query; d104 only by the control predicate
  reach_check_uncited.py / .out  the 6 documents quoted in prose without a citation; d99 is selected by the PubDip regex filter (R=8) and by corpus MATCH predicates
  slice_check.py / .out        topic slice 597+114=711; 392 pointers on 200 documents; tallies; M5/M6; MIN(date)=1910-12-06
  census_rerun.py / .out       independent regex census: USIA 375, USIS 402, VOA 179, core 864, decades 196/13688 293/12972 330/7884 45/3370 0/106
  checker_output.txt           python3 -I check_collection.py -> "31 documents; all checks pass"
