.timeout 100000
CREATE VIRTUAL TABLE IF NOT EXISTS temp.v USING fts5vocab(main, frus_documents, 'row');
SELECT term, doc, cnt FROM temp.v WHERE term IN ('corrupt','bribe','briberi','graft','kickback','payoff','venal','embezzl','embezzel','peculat','malfeas','misappropri','scandal','nepot','cronyism','crooki','extort','racketeer','payola','malvers','illicit','impropri','gratuiti','venal','dishonest','smuggl','profiteer','pilfer','squander','misus','sleaz','crimin') ORDER BY doc DESC;
