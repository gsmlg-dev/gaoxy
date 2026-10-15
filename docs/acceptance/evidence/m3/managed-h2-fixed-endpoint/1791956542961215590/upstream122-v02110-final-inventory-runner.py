import hashlib,json,os,subprocess,sys,time
from pathlib import Path
R=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E=R/'docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590'
manifest=json.loads((E/'upstream122-v02110-ready-candidate-manifest.json').read_text())
owned=set(manifest['source_files'])|{'mix.lock'}
raw=subprocess.check_output(['git','status','--porcelain=v1','-z','--untracked-files=all'],cwd=R)
records=[v.decode() for v in raw.split(b'\0') if v]
paths=[];unexpected=[]
for row in records:
    assert row[:2] in [' M','??'], row
    path=row[3:]
    if path in owned or path.startswith(str(E.relative_to(R))+'/'): paths.append(path)
    else: unexpected.append(row)
assert not unexpected,unexpected
assert set(p for p in paths if not p.startswith(str(E.relative_to(R))+'/'))==owned
tracked=set(x.decode() for x in subprocess.check_output(['git','ls-files','-z'],cwd=R).split(b'\0') if x)
for p in E.rglob('*'):
    assert not p.is_symlink(),str(p)
    if p.is_file():
        assert not set(p.relative_to(E).parts)&{'_build','node_modules','__pycache__','.cache','.venv','.git'},str(p)
        assert p.stat().st_size<100*1024*1024,str(p)
        rel=str(p.relative_to(R))
        if rel not in tracked and rel not in paths: paths.append(rel)
paths=sorted(set(paths))
items=[]
for name in paths:
    p=R/name
    items.append({'path':name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
assert subprocess.check_output(['git','diff','--cached','--name-only'],cwd=R)==b''
for p,expected in [(Path('/home/gao/Workspace/gsmlg-opt/gaoxy/gaoxy-m1.1-fix-prompt.md'),'7982874aacafe8bc4f4814740f25d1bd1e5bb35cbdc3938338ab132f2cdf9f1f'),(R/'codex-prompt.md','87112f8eb621966e0062c8611054bda49af0508693c46fa621de87a2b774038c')]:
    assert hashlib.sha256(p.read_bytes()).hexdigest()==expected,str(p)
out={'kind':'EXPLICIT_TASK_OWNED_COMMIT_INVENTORY','status':'INVENTORY_ONLY_NO_STAGING','baseline':manifest['head'],'recorded_at_ns':time.time_ns(),'source_path_count':len(owned),'formal_evidence_directory':str(E.relative_to(R)),'file_count':len(items),'total_bytes':sum(x['bytes'] for x in items),'unexpected':unexpected,'preserved_prompts':True,'index_unstaged':True,'items':items}
Path('/tmp/gaoxy-v02110-final-inventory.json').write_text(json.dumps(out,indent=2)+'\n')
Path('/tmp/gaoxy-v02110-stage-allowlist.nul').write_bytes(b''.join(x['path'].encode()+b'\0' for x in items))
print(json.dumps({k:v for k,v in out.items() if k!='items'},indent=2))
