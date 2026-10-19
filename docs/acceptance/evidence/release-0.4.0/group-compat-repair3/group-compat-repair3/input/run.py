"""Qualify a bounded repair snapshot in the cached pinned builder, no release claim."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path('/work')
INPUT = Path('/repair')
OUTPUT = Path('/repair-evidence')
OUTPUT.mkdir()
manifest = json.loads((INPUT/'input-manifest.json').read_text())
identity=json.loads(Path('/tools/source-identity.json').read_text())
assert identity['source_sha']==manifest['baseline_source_sha']=='9253b787b57b768682bb4d894f25ca82919c0a94'
report = {'status':'FAIL', 'kind':'BOUNDED_REPAIR_SNAPSHOT_NOT_RELEASE_ARTIFACT', 'baseline_source_sha':manifest['baseline_source_sha'], 'input_files_sha256':manifest['files_sha256'], 'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(), 'commands':[]}
for name, digest in manifest['files_sha256'].items():
    assert hashlib.sha256((INPUT/name).read_bytes()).hexdigest()==digest, name
for name, digest in manifest['baseline_production_sha256'].items():
    assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
for name in manifest['source_paths']:
    if name.endswith('_test.exs'):
        shutil.copyfile(INPUT/name, ROOT/name)
scope=json.loads((INPUT/'ordinary-scope.json').read_text())


def run(name, command, env, timeout=300, expected_exit=0):
    start=time.monotonic()
    row={'name':name,'command':command,'environment':env,'timeout_seconds':timeout,'expected_exit_code':expected_exit}
    report['commands'].append(row)
    try:
        result=subprocess.run(command,cwd=ROOT,env=dict(os.environ,**env),capture_output=True,timeout=timeout)
        (OUTPUT/(name+'.stdout')).write_bytes(result.stdout)
        (OUTPUT/(name+'.stderr')).write_bytes(result.stderr)
        row['exit_code']=result.returncode
        assert result.returncode==expected_exit,(name,result.returncode,expected_exit)
        return (result.stdout+result.stderr).decode()
    except subprocess.TimeoutExpired as error:
        (OUTPUT/(name+'.stdout')).write_bytes(error.stdout or b'')
        (OUTPUT/(name+'.stderr')).write_bytes(error.stderr or b'')
        row['error']=repr(error)
        raise
    finally:
        row['elapsed_seconds']=time.monotonic()-start
        for suffix in ['stdout','stderr']:
            path=OUTPUT/(name+'.'+suffix)
            if path.exists():row[suffix+'_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
        (OUTPUT/'result.json').write_text(json.dumps(report,indent=2)+'\n')


try:
    red_selectors=[]
    for name in manifest['source_paths']:
        if name.endswith('_test.exs'):
            marker='ordinary h2c exchanges keep native limits' if 'gaoxy_http/test/' in name else 'exchange limits keep WebSocket settings only'
            matches=[n for n,line in enumerate((INPUT/name).read_text().splitlines(),1) if 'test "' in line and marker in line]
            assert len(matches)==1,(name,matches)
            red_selectors.append(name+':'+str(matches[0]))
    assert len(red_selectors)==2
    red=run('regression-red',['mix','test',*red_selectors,'--seed','0','--max-cases','1'],{'MIX_ENV':'test'},expected_exit=2)
    red_summaries=re.findall(r'(\d+) tests?, (\d+) failures?([^\n]*)',red)
    assert len(red_summaries)==2,red_summaries
    red_counts=[]
    for total,failures,suffix in red_summaries:
        excluded=sum(int(n) for n in re.findall(r'(\d+) excluded',suffix))
        assert int(total)-excluded==1 and int(failures)==1 and 'skipped' not in suffix
        red_counts.append({'defined':int(total),'excluded':excluded,'executed':1,'failures':1})
    assert re.search(r'assert limits ==',red) and re.search(r'assert exchange.limits == native',red)
    assert 'extended_connect' in red and 'websocket_limits' in red
    report['regression_red']={'status':'EXPECTED_FAILURE_REPRODUCED','counts':red_counts,'product_result':'FAIL before production overlay'}
    for name,digest in manifest['baseline_production_sha256'].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
        shutil.copyfile(INPUT/name,ROOT/name)
    run('repair-format',['mix','format','--check-formatted',*manifest['source_paths']],{'MIX_ENV':'test'})
    run('repair-strict-prod-compile',['mix','compile','--warnings-as-errors'],{'MIX_ENV':'prod'})
    suites=[]
    for batch in scope['batches']:
        raw=run(batch['name'],batch['command'],{'MIX_ENV':'test','HTTP_FETCH_PEER_PYTHON':'/work/.audit/h2peer/bin/python','GAOXY_QUIC_PYTHON':'/work/.audit/h2peer/bin/python','PYTHONDONTWRITEBYTECODE':'1'})
        text=re.sub(r'\x1b\[[0-9;]*[A-Za-z]','',raw)
        counts={}
        for section in re.finditer(r'(?ms)^==> ([a-z0-9_]+)\n(.*?)(?=^==>|\Z)',text):
            app, output=section.groups()
            summaries=re.findall(r'(\d+) tests?, (\d+) failures?([^\n]*)',output)
            if summaries:
                assert app not in counts and len(summaries)==1,(app,summaries)
                total,failed,suffix=summaries[0]
                excluded=sum(int(n) for n in re.findall(r'(\d+) excluded',suffix))
                skipped=sum(int(n) for n in re.findall(r'(\d+) skipped',suffix))
                counts[app]={'executed':int(total)-excluded-skipped,'failures':int(failed),'excluded':excluded,'skipped':skipped}
        assert counts==batch['applications'],(batch['name'],counts,batch['applications'])
        suites.append({'name':batch['name'],'applications':counts,'status':'PASS'})
    report['suites']=suites
    report['executed']=sum(v['executed'] for s in suites for v in s['applications'].values())
    report['excluded']=sum(v['excluded'] for s in suites for v in s['applications'].values())
    assert report['executed']==200 and report['excluded']==90
    report['status']='PASS'
except BaseException as error:
    report['error']=repr(error)
finally:
    report['completed_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
    (OUTPUT/'result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['input_files_sha256','commands','suites']}),flush=True)
