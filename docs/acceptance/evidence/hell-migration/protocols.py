import json, subprocess, sys
from pathlib import Path
peer='/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m5-websocket-over-h2-h3/.audit/m5/venv/bin/python'
base=Path('.audit/hell-migration')
reports={}
for protocol in ['h2','h2c']:
    label='peer-'+protocol
    command=[peer,'integration/websocket_multiplexed/run.py','--protocol',protocol,'--evidence',str(base/label)]
    result=subprocess.run(['python3',str(base/'envrun.py'),label,*command])
    if result.returncode: sys.exit(result.returncode)
    report=max((base/label).glob('run-*/report.json'),key=lambda p:p.stat().st_mtime_ns)
    data=json.loads(report.read_text())
    assert data['status']=='PASS' and data['executed']==15,(report,data.get('status'),data.get('executed'))
    reports[protocol]=report
for protocol in ['h2','http1']:
    label='browser-'+protocol
    command=[peer,'integration/websocket_multiplexed/browser.py','--protocol',protocol,'--chromium','/run/current-system/sw/bin/chromium','--evidence',str(base/label)]
    if protocol=='h2': command+=['--native-peer-report',str(reports['h2'])]
    result=subprocess.run(['python3',str(base/'envrun.py'),label,*command])
    if result.returncode: sys.exit(result.returncode)
