# The session's own reading of the .fruscollection file, written before any reviewer returned

Read: FRUSCoreKit/Collections/NativeCollectionFormat.swift, whole, at efd73ec. Not yet read: the app half, the Agentic Analysis Guide, the tests.

1. The file is decoupled from the model types by its own doc comment (:24-25: "decoupled from the SwiftData @Model types, so the file schema can evolve independently of the persistence layer"). A new record type does not by itself change the file.
2. The reader's gate is `minimumReaderVersion ?? formatVersion` against `currentVersion` 2 (:439-442). Unknown JSON keys are ignored; an unknown entry kind is skipped (:699-704); an unknown generated block type is kept as an inert entry (:741-746).
3. The writer writes the minimum (:448-455, :610-652): a v1 file when no v2 feature is used, else v2 with `minimumReaderVersion: 1`.
4. The floor rises "only when ignoring a field would corrupt meaning, never for degradable features" (:91-93; :657-659, "Migration rule 3").
5. Additions 2.1 to 2.5 all rode v2 with the floor at 1 (:37-73).
6. The design's §7.6 says the file takes version 3 and a 1.0 app refuses it, and that writing the minimum "would need a second function from the new values back to the old". Under the design's own §3.1 every addition degrades on a 1.0 reader and none corrupts, so by rule 4 the floor need not rise. A writer needs a mapping from the new values to some file schema in any case.
7. `footnoteStyle`, the tri-state, is always written (:151-154, :479). The design's "volume's notes" has the same three values.
8. An entry's footnote and source-note overrides are two independent optionals (:245-253). A partial pair has no equivalent as one optional tri-state key. The design's upgrade table does not say what becomes of one.
9. Not serialized: the collection's summary prompt (:146-147), selected highlight ids (:55-58), selected note ids (:268-273), project ids, the saved-search link (:679-683), ids and timestamps. A headnote travels as an id only (:227-231), so its text does not reach another person.
10. The design does not say what a look chosen in the export sheet means for a file that is the collection's source and not a rendering.
11. The candidate "selected passages" rests on highlights, which do not travel.
12. The same files are read and written by a host outside the app through the kit (:74-75, :398-404).
