import json, os, subprocess, sys
from pathlib import Path
qualified=json.loads(Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m5-websocket-over-h2-h3/.audit/m5/nix-env.json').read_text())
env=os.environ.copy()
for key in ('PATH','LD_LIBRARY_PATH','LOCALE_ARCHIVE','LANG'):
    if key in qualified: env[key]=qualified[key]
env.setdefault('MIX_ENV','test')
env.update(ERL_FLAGS='+S 4:4 +SDcpu 2 +SDio 2', GAOXY_QUIC_PYTHON='/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m5-websocket-over-h2-h3/.audit/m5/venv/bin/python')
sys.exit(subprocess.call(['python3','.audit/hell-migration/run.py',*sys.argv[1:]],env=env))
