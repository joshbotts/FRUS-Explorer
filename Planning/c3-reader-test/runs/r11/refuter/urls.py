import re
t=open('/Users/jbotts/frus-analysis/c3/runs/r11/overview.md',encoding='utf-8').read()
pairs=re.findall(r'historicaldocuments/([^/\s)]+)/(d\d+)',t)
print('url citations', len(pairs), 'distinct', len(set(pairs)))
for p in sorted(set(pairs)): print(p[0], p[1], 'x%d'%pairs.count(p))
# printed citations: "Document N" occurrences
print()
for m in re.finditer(r'((?:Papers Relating|Foreign Relations)[^()]*?Document (\d+)), (https://history\.state\.gov/historicaldocuments/([^/\s)]+)/(d\d+))',t):
    print(m.group(2), '->', m.group(4), m.group(5), '|', m.group(1)[:90])
print()
print('"same volume" / "see also" citations:')
for m in re.finditer(r'(same volume, Document (\d+)|Document (\d+),|Documents (\d+) and (\d+))[^h]*?(https://[^\s)]+)',t):
    print(m.group(0)[:160])
