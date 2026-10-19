import json, subprocess, sys
from pathlib import Path
scope=json.loads(Path('.audit/hell-migration/ordinary-scope.json').read_text())
for row in scope['batches']:
    result=subprocess.run(['python3','.audit/hell-migration/envrun.py',row['name']+('-fresh' if row['name']=='hell-native-ordinary' else ''),*row['command']])
    if result.returncode: sys.exit(result.returncode)
