import hashlib,json,pathlib,runpy,subprocess,sys,tempfile,time
from unittest.mock import patch
BASE=pathlib.Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m4-http3/docs/acceptance/evidence/release-0.3.0')
RECIPE=BASE/'portable/recipe'; results=[]
class Clock:
    value=0.0
    def now(self): return self.value


def absence(style, name, command, timeout):
    samples = {
        "upper": "Error: No such object: " + name + "\n",
        "container": "Error: No such container: " + name + "\n",
        "lower": "[]\nerror: no such object: " + name + "\n",
        "mixed": "ErRoR: nO sUcH oBjEcT: " + name + "\n",
        "daemon_prefix": "Error response from daemon: No such container: " + name + "\n",
        "daemon_error": "Cannot connect to the Docker daemon\n",
        "permission": "permission denied while trying to connect to the Docker daemon\n",
        "empty": "",
        "wrong_name": "error: no such object: unrelated-owned-container\n",
        "prefix_name": "error: no such object: " + name + "-suffix\n",
        "exit_zero": "error: no such object: " + name + "\n",
        "timeout": "partial inspection",
    }
    if style == "timeout":
        raise subprocess.TimeoutExpired(command, timeout, output=b"partial inspection")
    return (0 if style == "exit_zero" else 1, samples[style])

def child(mode, style="upper"):
    valid = style in ("upper", "container", "lower", "mixed", "daemon_prefix")
    clock=Clock(); calls=[]; exists=False; running=False; inspections=0
    with tempfile.TemporaryDirectory() as directory:
        root=pathlib.Path(directory); evidence=root/'evidence/fresh-runtime'; evidence.mkdir(parents=True)
        name='gaoxy-release-030-portable-'+'a'*32
        def docker(cmd,**kw):
            nonlocal exists,running,inspections
            assert cmd[0]=='docker' and 0<kw['timeout']<=300-clock.value
            calls.append((list(cmd),kw['timeout'],clock.value))
            op=cmd[1]; stdout=''; stderr=''; code=0
            if op=='image':
                if mode=='image_timeout':
                    clock.value+=kw['timeout']; raise subprocess.TimeoutExpired(cmd,kw['timeout'],output=b'partial')
                stdout='sha256:fixture\n'
            elif op=='create':
                assert cmd[cmd.index('--name')+1]==name
                exists=True; stdout='owned-id\n'
                if mode=='create_timeout':
                    clock.value+=kw['timeout']; raise subprocess.TimeoutExpired(cmd,kw['timeout'],output=b'partial')
            elif op=='start': running=True; stdout=name+'\n'
            elif op=='inspect':
                assert cmd[2]==name
                if not exists: code,stderr=absence(style,name,cmd,kw["timeout"])
                else:
                    inspections+=1
                    if mode=='cleanup_inspect_timeout' and inspections==2:
                        clock.value+=kw['timeout']; raise subprocess.TimeoutExpired(cmd,kw['timeout'],output=b'partial')
                    stdout=json.dumps([{'Name':'/'+name,'State':{'Running':running,'ExitCode':0},'Image':'sha256:fixture','HostConfig':{'NetworkMode':'none'}}])
            elif op=='wait':
                assert cmd[2]==name
                if mode=='wait_timeout':
                    clock.value+=kw['timeout']; raise subprocess.TimeoutExpired(cmd,kw['timeout'],output=b'partial')
                running=False; stdout='0\n'; (evidence/'runtime-result.json').write_text('{"status":"PASS"}')
            elif op=='stop': assert cmd[-1]==name; running=False
            elif op=='logs': assert cmd[-1]==name; stdout='controlled boundary log\n'
            elif op=='rm':
                assert cmd[-1]==name
                if mode=='remove_failure': code=1; stderr='controlled removal failure'
                else: exists=False; running=False
            else: raise AssertionError(cmd)
            clock.value+=0.1
            return subprocess.CompletedProcess(cmd,code,stdout,stderr)
        with patch.object(sys,'argv',['run_runtime.py',str(root),name,'300']),patch.object(time,'monotonic',clock.now),patch.object(subprocess,'run',docker):
            try: runpy.run_path(str(RECIPE/'run_runtime.py'),run_name='__main__')
            except SystemExit as error: exit_code=error.code
        receipt=json.loads((evidence/'launch.json').read_text()); expected=0 if mode=='normal' and valid else 1
        assert exit_code==expected and receipt['status']==('PASS' if expected==0 else 'FAIL'),(mode,receipt)
        assert clock.value<=300 and receipt['owned_name']==name
        removals=[c for c,_,_ in calls if c[1]=='rm']; assert len(removals)==1 and removals[0][-1]==name
        if mode not in ('normal','remove_failure'): assert '--force' in removals[0]
        if mode=='wait_timeout':
            assert any(r.get('timed_out') for r in receipt['commands'])
            assert (evidence/'container-wait.log').read_bytes()==b'partial'
            assert any(c[1]=='stop' for c,_,_ in calls)
        if mode=='cleanup_inspect_timeout': assert any(c[1]=='logs' for c,_,_ in calls)
        if mode=='remove_failure': assert not receipt['owned_container_absent']
        results.append({'kind':'child','mode':mode,'absence_style':style,'exit':exit_code,'elapsed_simulated':clock.value,'commands':len(calls)})

def parent(mode, style="upper"):
    valid = style in ("upper", "container", "lower", "mixed", "daemon_prefix")
    clock=Clock(); calls=[]; killed=[]
    with tempfile.TemporaryDirectory() as directory:
        root=pathlib.Path(directory); (root/'context').mkdir(); exists=True
        class Process:
            pid=99123
            def __init__(self,cmd,**kw):
                self.cmd=cmd; self.output=kw['stdout']; self.returncode=None
                assert kw.get('start_new_session') is True
            def poll(self): return self.returncode
            def wait(self,timeout):
                nonlocal exists
                assert 0<timeout<=600-clock.value
                if self.returncode is not None: return self.returncode
                cmd=self.cmd; calls.append((list(cmd),timeout,clock.value)); code=0; output=''
                if cmd[0]=='docker':
                    if cmd[1]=='buildx': clock.value+=520 if mode=='child_timeout' else 1
                    elif cmd[1]=='image':
                        if mode=='image_timeout': clock.value+=timeout; raise subprocess.TimeoutExpired(cmd,timeout)
                        output='[]\n'
                    elif cmd[1]=='inspect':
                        if exists: output='[{"State":{"Running":false}}]'
                        else: code,output=absence(style,cmd[-1],cmd,timeout)
                    elif cmd[1]=='logs': output='controlled parent log'
                    elif cmd[1]=='rm': assert cmd[2]=='--force'; exists=False
                    else: raise AssertionError(cmd)
                else:
                    assert pathlib.Path(cmd[1]).name=='run_runtime.py'; name=cmd[3]
                    if mode=='child_timeout': clock.value+=timeout; raise subprocess.TimeoutExpired(cmd,timeout)
                    launch={'owned_name':name,'status':'PASS','owned_container_removed':mode!='missing_proof','owned_container_absent':True}
                    p=root/'evidence/fresh-runtime';p.mkdir();(p/'launch.json').write_text(json.dumps(launch));exists=False
                self.output.write(output);self.output.flush();self.returncode=code;clock.value+=0.1;return code
        process_holder=[]
        def popen(cmd,**kw):
            p=Process(cmd,**kw);process_holder.append(p);return p
        def kill(pid,sig): assert pid==99123; killed.append(pid);process_holder[-1].returncode=-9
        with patch.object(sys,'argv',['qualify_runtime.py',str(root)]),patch.object(time,'monotonic',clock.now),patch.object(subprocess,'Popen',popen),patch('os.killpg',kill):
            try: runpy.run_path(str(RECIPE/'qualify_runtime.py'),run_name='__main__')
            except SystemExit as error: exit_code=error.code
        receipt=json.loads((root/'evidence/runtime-qualification-stages.json').read_text()); expected=0 if mode=='normal' and valid else 1
        assert exit_code==expected and receipt['status']==('PASS' if expected==0 else 'FAIL'),(mode,receipt)
        assert clock.value<=600
        owned=receipt['owned_name']; assert len(owned.rsplit('-',1)[1])==32
        for c,_,_ in calls:
            if c[0]=='docker' and c[1] in ('inspect','logs','rm'): assert c[-1]==owned
        if mode=='child_timeout': assert killed and receipt['owned_container_absent'] and receipt['fallback_remove_exit_code']==0
        if mode=='missing_proof': assert receipt['owned_container_absent'] and receipt['status']=='FAIL'
        if mode=='image_timeout': assert killed and not any(c[0]!='docker' for c,_,_ in calls)
        results.append({'kind':'parent','mode':mode,'absence_style':style,'exit':exit_code,'elapsed_simulated':clock.value,'commands':len(calls),'process_groups_killed':len(killed)})


for style in ("upper", "lower"):
    for mode in ("normal", "image_timeout", "create_timeout", "wait_timeout", "cleanup_inspect_timeout", "remove_failure"):
        child(mode, style)
    for mode in ("normal", "image_timeout", "child_timeout", "missing_proof"):
        parent(mode, style)
for style in ("container", "mixed", "daemon_prefix", "daemon_error", "permission", "empty", "wrong_name", "prefix_name", "exit_zero", "timeout"):
    child("normal", style)
    parent("normal", style)
record = {"kind": "DETERMINISTIC_DOCKER_ABSENCE_AND_PROCESS_BOUNDARY_REGRESSION", "status": "PASS", "cases": results, "count": len(results), "not_artifact_qualification": True, "source_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (RECIPE / "run_runtime.py", RECIPE / "qualify_runtime.py")}}
receipt = BASE / ("docker-absence-boundary-green-" + str(time.time_ns()) + ".json")
receipt.write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps({"status": "PASS", "cases": len(results), "receipt": str(receipt)}))
