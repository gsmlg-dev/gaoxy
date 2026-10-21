import concurrent.futures,datetime,json,pathlib,subprocess,sys,time
ROOT=pathlib.Path(__file__).resolve().parent
OUT=ROOT/'release-workflow'
OUT.mkdir()
RUN=39552147775
SOURCE='aaa613985b08edd146f393ddd48f65fd6f3665b2'
def api(path):
    return json.loads(subprocess.check_output(['gh','api',path],text=True,timeout=45))
prior=None
for n in range(100):
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        f1=pool.submit(api,f'repos/gsmlg-dev/gaoxy/actions/runs/{RUN}')
        f2=pool.submit(api,f'repos/gsmlg-dev/gaoxy/actions/runs/{RUN}/jobs?per_page=100')
        run,jobs=f1.result(),f2.result()
    assert run['head_sha']==SOURCE and run['path']=='.github/workflows/release.yml'
    assert run['event']=='workflow_dispatch' and run['head_branch']=='main'
    stamp=datetime.datetime.now(datetime.timezone.utc).isoformat()
    snapshot={'source':SOURCE,'run_id':RUN,'captured_utc':stamp,'run':run,'jobs':jobs}
    (OUT/f'snapshot-{n:03d}.json').write_text(json.dumps(snapshot,indent=2)+'\n')
    steps=[(j['name'],j['status'],j['conclusion'],[s['name'] for s in j['steps'] if s['status']=='in_progress']) for j in jobs['jobs']]
    now=(run['status'],run['conclusion'],steps)
    if now!=prior:print(stamp,json.dumps(now),flush=True);prior=now
    if run['status']=='completed':
        snapshot['status']='PASS' if run['conclusion']=='success' else 'FAIL'
        (OUT/'result.json').write_text(json.dumps(snapshot,indent=2)+'\n')
        print(snapshot['status'],'release workflow',RUN,SOURCE,flush=True)
        sys.exit(0 if run['conclusion']=='success' else 1)
    time.sleep(30)
raise SystemExit('Release observation timeout; inspect actual workflow before retrying any publication.')

