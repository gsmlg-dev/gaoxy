import ast,difflib,hashlib,importlib.util,io,json,tarfile
from pathlib import Path
root=Path.cwd();sha='bd325eb408d4566b807bcef9fdaf1a2b1ad83a2d';e=root/'.audit/release-0.13.0/public-runtime-verification-o_yath33';source=root/'.audit/release-0.13.0/verify-public-artifacts.py';repaired=e/'verify-public-artifacts-keyword.py'
ast.parse(repaired.read_text());spec=importlib.util.spec_from_file_location('verifier',repaired);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);assert module.ROOT==root
archive=root/'.audit/release-0.13.0/public-artifacts-pnhqzbua/hex-gaoxy-0.13.0.tar';positive=module.check_package(archive,'gaoxy',sha)
results=[{'control':'actual_canonical_keyword_manifest','status':'PASS','source_files':positive['source_file_count']}]
with tarfile.open(archive) as outer:outer_files=[(m,outer.extractfile(m).read()) for m in outer.getmembers() if m.isfile()]
inner_data=dict((m.name,d) for m,d in outer_files)['contents.tar.gz']
with tarfile.open(fileobj=io.BytesIO(inner_data),mode='r:gz') as inner:inner_files=[(m,inner.extractfile(m).read()) for m in inner.getmembers() if m.isfile()]
original=dict((m.name,d) for m,d in inner_files)['mix.exs'];controls=e/'parser-controls';controls.mkdir(exist_ok=True)
for app,version in [('hell','0.1.3'),('abyss','0.10.0')]:
 for case in ['wrong','missing']:
  target=(f'{app}: "== {version}"').encode();replacement=(f'{app}: "== 0.0.1"').encode() if case=='wrong' else (f'unrelated_{app}: "== {version}"').encode()
  assert original.count(target)==1;manifest=original.replace(target,replacement)
  buf=io.BytesIO()
  with tarfile.open(fileobj=buf,mode='w:gz') as inner:
   for old,data in inner_files:
    data=manifest if old.name=='mix.exs' else data;member=tarfile.TarInfo(old.name);member.size=len(data);member.mode=old.mode;inner.addfile(member,io.BytesIO(data))
  path=controls/f'{app}-{case}.tar'
  with tarfile.open(path,'w') as outer:
   for old,data in outer_files:
    data=buf.getvalue() if old.name=='contents.tar.gz' else data;member=tarfile.TarInfo(old.name);member.size=len(data);member.mode=old.mode;outer.addfile(member,io.BytesIO(data))
  try:module.check_package(path,'gaoxy',sha)
  except ValueError as error:assert str(error)==f'packaged gaoxy manifest lacks exact {app} pin',str(error)
  else:raise AssertionError(f'{app}-{case} incorrectly accepted')
  results.append({'control':f'{app}_{case}_pin_rejected','status':'PASS'})
receipt={'status':'PASS','results':results,'original_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'repaired_sha256':hashlib.sha256(repaired.read_bytes()).hexdigest(),'product_source_changed':False,'sol_parser_repair_rounds':2,'first_parser_round':'FAIL positive canonical control: retained tuple closing brace; corrected complete syntax alternatives in round2'}
(e/'parser-controls.json').write_text(json.dumps(receipt,indent=2)+'\n');(e/'parser-repair.patch').write_text(''.join(difflib.unified_diff(source.read_text().splitlines(True),repaired.read_text().splitlines(True),fromfile=str(source.relative_to(root)),tofile=str(repaired.relative_to(root)))))
print(json.dumps(receipt))
