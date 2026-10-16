from pathlib import Path
import ast, hashlib, json, subprocess
r=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
e=r/'docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423'
names=['command-collector2.py','browser-command-collector1.py','fixed-generation-browser-runner2.py']
for name in names: ast.parse((e/name).read_text(),filename=str(e/name))
tree=ast.parse((e/'fixed-generation-browser-runner2.py').read_text())
code=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='BROWSER' for t in n.targets))
v=subprocess.run(['node','--check'],input=code,text=True,capture_output=True,timeout=20)
assert v.returncode==0,(v.returncode,v.stdout,v.stderr)
print(json.dumps({'python_ast':'PASS','active_files':names,'embedded_js_node_check':'PASS','embedded_js_sha256':hashlib.sha256(code.encode()).hexdigest(),'runtime':'NOT EXECUTED BY SYNTAX CHECK'}))
