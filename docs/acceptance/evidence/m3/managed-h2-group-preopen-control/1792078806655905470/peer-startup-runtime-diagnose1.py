import hashlib
import json
import os
from pathlib import Path
import select
import shutil
import signal
import subprocess
import tempfile
import time

R = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = Path((Path('/tmp/gaoxy-h2-group-preopen-control-evidence-path.txt')).read_text().strip())
PEER = R / 'apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py'
PYTHON = '/tmp/gaoxy-m3-h2-soak-venv/bin/python'


def run():
    reports = []
    for scenario in ('h2c-without-openssl', 'h2c-controlled-key-barrier'):
        with tempfile.TemporaryDirectory(prefix='gaoxy-peer-diagnose-') as work:
            work = Path(work)
            env = dict(os.environ)
            marker, release = work / 'marker', work / 'release'
            os.mkfifo(marker)
            os.mkfifo(release)
            if scenario == 'h2c-without-openssl':
                env['OPENSSL_BIN'] = str(work / 'unavailable-openssl')
            else:
                wrapper = work / 'openssl-wrapper'
                wrapper.write_text('#!' + shutil.which('python3') + '\n' +
                    'import os,sys\n' +
                    'if sys.argv[1] == "req" and not os.path.exists(' + repr(str(work / 'once')) + '):\n' +
                    ' open(' + repr(str(work / 'once')) + ', "x").close()\n' +
                    ' with open(' + repr(str(marker)) + ', "w") as p: p.write(str(os.getpid()) + "\\n")\n' +
                    ' with open(' + repr(str(release)) + ') as p: assert p.readline() == "continue\\n"\n' +
                    'os.execv(' + repr(shutil.which('openssl')) + ', [' + repr(shutil.which('openssl')) + '] + sys.argv[1:])\n')
                wrapper.chmod(0o700)
                env['OPENSSL_BIN'] = str(wrapper)
            started = time.monotonic()
            p = subprocess.Popen([PYTHON, '-B', str(PEER), '--protocol', 'h2c'], cwd=R,
                                 env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, text=True, start_new_session=True)
            observed = []
            try:
                if scenario == 'h2c-controlled-key-barrier':
                    fd = os.open(marker, os.O_RDONLY | os.O_NONBLOCK)
                    try:
                        if not select.select([fd], [], [], 5)[0]:
                            raise RuntimeError('certificate wrapper never reached barrier')
                        key_pid = int(os.read(fd, 128).decode().strip())
                    finally:
                        os.close(fd)
                    barrier_at = time.monotonic() - started
                    expired = max(0, 5.05 - (time.monotonic() - started))
                    premature = bool(select.select([p.stdout], [], [], expired)[0])
                    with open(release, 'w') as pipe:
                        pipe.write('continue\n')
                    if not select.select([p.stdout], [], [], 20)[0]:
                        raise RuntimeError('peer did not finish controlled preparation')
                    ready_line = p.stdout.readline()
                    observed.append(json.loads(ready_line))
                    ready_at = time.monotonic() - started
                else:
                    barrier_at = key_pid = premature = ready_at = None
                out, err = p.communicate(json.dumps({'op': 'stop'}) + '\n', timeout=25)
                observed.extend(json.loads(line) for line in out.splitlines())
                reports.append(dict(scenario=scenario, pid=p.pid, actual_exit=p.returncode,
                    joined=p.poll() is not None, elapsed_ms=round((time.monotonic()-started)*1000),
                    key_pid=key_pid, barrier_seconds=barrier_at, ready_seconds=ready_at,
                    stdout_before_five_second_deadline=premature, events=observed, stderr=err,
                    causal_limit='controlled reproduction only; original failed run timing remains unproved'))
            finally:
                if p.poll() is None:
                    os.killpg(p.pid, signal.SIGKILL)
                    p.communicate(timeout=5)
    report = dict(peer_sha256=hashlib.sha256(PEER.read_bytes()).hexdigest(),
                  script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), reports=reports)
    path = E / 'peer-startup-runtime-diagnosis1.json'
    with path.open('x') as output:
        output.write(json.dumps(report, indent=2) + '\n')
    assert reports[0]['actual_exit'] != 0
    assert reports[0]['events'][0]['event'] == 'failure'
    assert 'AttributeError' in reports[0]['stderr']
    assert reports[1]['stdout_before_five_second_deadline'] is False
    assert reports[1]['ready_seconds'] > 5
    assert reports[1]['actual_exit'] == 0
    assert reports[1]['events'][-1]['event'] == 'joined'
    assert reports[1]['events'][-1]['live'] == 0
    print(json.dumps({'receipt': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                      'reports': [{k:v for k,v in entry.items() if k not in ('events','stderr')}
                                  for entry in reports]}, indent=2))


if __name__ == '__main__':
    run()
