import json, os, subprocess, sys
from pathlib import Path
root=Path.cwd()
env=os.environ.copy()
routes=json.loads((root/'.audit/hell-migration/cache-route-v2.json').read_text())['routes']
env['GIT_CONFIG_COUNT']=str(len(routes))
for index,row in enumerate(routes):
    env[f'GIT_CONFIG_KEY_{index}']='url.'+Path(row['local_verified_source']).as_uri()+'.insteadOf'
    env[f'GIT_CONFIG_VALUE_{index}']=row['canonical_url']
env['HEX_OFFLINE']='1'
commands=[
 ('consumer-core-fresh',['bash','scripts/external-consumer.sh']),
 ('consumer-http',['bash','scripts/http-consumer.sh']),
 ('phoenix-deps',['env','-C','examples/phoenix_native','MIX_ENV=dev','PHOENIX_NATIVE_H3=1','mix','deps.get','--check-locked']),
 ('phoenix-compile',['env','-C','examples/phoenix_native','MIX_ENV=dev','PHOENIX_NATIVE_H3=1','mix','compile','--warnings-as-errors'])]
for label,command in commands:
    result=subprocess.run(['python3','.audit/hell-migration/envrun.py',label,*command],env=env)
    if result.returncode: sys.exit(result.returncode)
