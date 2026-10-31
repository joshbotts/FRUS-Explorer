import sqlite3
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
terms = ['"Department of State"','"ZZZ_IMPOSSIBLE_ZZZ"','corrupt','bribe','bribery','graft','kickback','embezzl','venal','peculat','payoff','"questionable payments"','"illicit payments"','"foreign corrupt practices"','"corrupt practices"','anticorruption','"anti-corruption"','kleptocra*','nepotism','"conflict of interest"','scandal','"under the table"','"squeeze"','"dishonest*"','"honest government"','"graft and corruption"','"corruption and"','"inefficiency and corruption"', 'Lockheed','"Foreign Corrupt Practices Act"']
for t in terms:
    r = db.execute("""SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
      WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0""",('body_text:'+t if not t.startswith('body') else t,)).fetchone()
    print(f"{t:40s} docs={r[0]:7d} vols={r[1]}")
