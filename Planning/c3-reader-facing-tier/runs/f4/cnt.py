from h import *
c=conn()
SQL="SELECT COUNT(DISTINCT d.volume_id), COUNT(*), SUM(d.is_front_matter), SUM(d.is_editorial_note) FROM document_cache d JOIN R USING(volume_id)"
print(SQL, c.execute(SQL).fetchall())
SQL="SELECT COUNT(DISTINCT d.volume_id), COUNT(*) FROM document_cache d JOIN R USING(volume_id) WHERE d.is_front_matter=0 AND d.is_editorial_note=0"
print(SQL, c.execute(SQL).fetchall())
SQL="SELECT COUNT(DISTINCT d.volume_id), COUNT(*) FROM document_cache d JOIN G USING(volume_id) WHERE d.is_front_matter=0 AND d.is_editorial_note=0"
print(SQL, c.execute(SQL).fetchall())
