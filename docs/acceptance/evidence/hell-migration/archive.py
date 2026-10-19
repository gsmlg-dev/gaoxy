import gzip, hashlib, json, shutil, sys
from pathlib import Path
base=Path('.audit/hell-migration')
destination=Path('docs/acceptance/evidence/hell-migration')
destination.mkdir(parents=True,exist_ok=True)
inputs=[*base.glob('*.json'),*base.glob('*.log'),base/'verified.diff']
for name in ['peer-h2','peer-h2c','browser-h2','browser-http1']:
 inputs.extend(path for path in (base/name).rglob('*') if path.is_file() and path.suffix in ['.json','.log','.html','.png'])
inputs.extend(base/name for name in ['run.py','envrun.py','ordinary.py','consumers.py','protocols.py','archive.py'])
manifest=[]
for source in sorted(inputs):
 relative=source.relative_to(base)
 compress=source.suffix in ['.log','.diff','.html'] or source.name=='netlog.json'
 target=destination/relative
 if compress: target=target.with_name(target.name+'.gz')
 raw=source.read_bytes()
 data=gzip.compress(raw,mtime=0) if compress else raw
 target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists(): assert target.read_bytes()==data,('immutable evidence changed',target)
 else: target.write_bytes(data)
 manifest.append({'source':str(relative),'archive':str(target.relative_to(destination)),'source_sha256':hashlib.sha256(raw).hexdigest(),'archive_sha256':hashlib.sha256(data).hexdigest(),'gzip':compress})
path=destination/('manifest-'+sys.argv[1]+'.json')
assert not path.exists(),path
path.write_text(json.dumps({'note':'Exact evidence bytes; logs, patches, HTML and browser netlogs gzip-compressed. Test certificate/key PEM files and dependency checkouts are excluded. Canonical dependency declarations unchanged by process-local caching.','files':manifest},indent=2)+'\n')
print('Archived',len(manifest),'files to',destination)
