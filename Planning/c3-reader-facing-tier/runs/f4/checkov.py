import re,json
s=open('overview.md').read()
Q=json.load(open('quotes.json'))
body={}
for q in Q:
    body.setdefault((q['v'],q['d']),re.sub(r'\s+',' ',open(f"docs/{q['v']}__{q['d']}.txt").read().split('BODY:',1)[1]))
allbody=" ".join(body.values())
# every double-quoted string of >=3 words OR any quote in text (excluding headings quoting soft power, etc.)
main=s.split('## Documents cited')[0]
quotes=re.findall(r'"([^"]+)"',main)
print('quoted strings in overview:',len(quotes))
for qt in quotes:
    qn=re.sub(r'\s+',' ',qt).rstrip(',.')
    found=qn in allbody
    # also allow with trailing comma stripped
    print(('OK  ' if found else 'NOT '),qt[:90])
# citations
cites=re.findall(r'\((\d{4}(?:–\d{4})?, Volume [IVXL]+(?:, Part \d)?, Document \d+)\)',main)
print('citations',len(cites),'distinct',len(set(cites)))
order=[]
for c in cites:
    if c not in order: order.append(c)
lst=s.split('## Documents cited')[1]
full=re.findall(r'^\d+\. (Foreign Relations of the United States, [^\n]*?), Document (\d+)\. (https://\S+)',lst,re.M)
print('documents cited list',len(full))
def key(f):
    t,n,u=f
    y=re.match(r'Foreign Relations of the United States, (\d{4}(?:–\d{4})?)',t).group(1)
    vol=re.search(r'(Volume [IVXL]+(?:, Part \d)?)',t).group(1)
    return f"{y}, {vol}, Document {n}"
lk=[key(f) for f in full]
print('order matches first-citation order:', lk==order)
print([x for x in order if x not in lk], [x for x in lk if x not in order])
# in collection?
coll=json.load(open('collection.fruscollection'))
cd={(e['volumeId'],e['documentId']) for e in coll['entries'] if e['kind']=='document'}
urls=[re.search(r'historicaldocuments/([^/]+)/(d\d+)',f[2]).groups() for f in full]
print('all cited docs in collection:', all(u in cd for u in urls), 'collection docs not cited:',[x for x in cd if x not in set(urls)])
bad=re.findall(r'(?i)(select |volume_id|document_id|/users/|\.db\b|\bTEI\b|\bstem|cosine|hamming|cluster|vector|neighbo|sqlite|\bFTS|rowid|issue #)',main)
print('forbidden tokens:',bad)
# word count of part 1
p1=re.search(r'\*\*1\. What FRUS answers directly\.\*\*(.*?)\n\n\*\*2\.',s,re.S).group(1)
print('part1 words',len(p1.split()))
