import hashlib
import json
import io
from pathlib import Path
import subprocess
import tarfile
import urllib.request

OUT = Path(__file__).resolve().parent
VERSION = '0.11.1'
assets = OUT / 'assets'
assets.mkdir(exist_ok=True)
release = json.loads(subprocess.check_output([
    'gh','release','view','v'+VERSION,'--json',
    'tagName,targetCommitish,url,publishedAt,assets'], text=True))
(OUT/'published-release.json').write_text(json.dumps(release,indent=2)+'\n')
subprocess.run(['gh','release','download','v'+VERSION,'--dir',str(assets),'--clobber'],check=True)
checks = []
expected_sha = '09715de3f165db134e287e1ea5fd4e93b1325905'
def require(ok, label):
    if not ok:
        raise RuntimeError(label)
    checks.append(label)
tag = subprocess.check_output(['git','ls-remote','origin','refs/tags/v'+VERSION],text=True).split()[0]
require(tag == expected_sha, 'remote tag exact source '+expected_sha)
for asset in release['assets']:
    digest = hashlib.sha256((assets/asset['name']).read_bytes()).hexdigest()
    require(asset['digest'] == 'sha256:'+digest, 'asset digest '+asset['name'])
for line in (assets/'SHA256SUMS').read_text().splitlines():
    expected,name = line.split(maxsplit=1)
    require(hashlib.sha256((assets/name).read_bytes()).hexdigest()==expected,
            'SHA256SUMS '+name)
packages = ['gaoxy_websock_adapter','gaoxy','gaoxy_http','gaoxy_http3','gaoxy_proxy','gaoxy_test']
hex_dir = OUT/'hex'
hex_dir.mkdir(exist_ok=True)
for package in packages:
    with urllib.request.urlopen(f'https://hex.pm/api/packages/{package}/releases/{VERSION}',timeout=60) as r:
        metadata=json.load(r)
    require(metadata['version']==VERSION,'Hex API version '+package)
    (hex_dir/(package+'.json')).write_text(json.dumps(metadata,indent=2)+'\n')
    filename=f'{package}-{VERSION}.tar'
    with urllib.request.urlopen('https://repo.hex.pm/tarballs/'+filename,timeout=60) as r:
        payload=r.read()
    require(payload==(assets/filename).read_bytes(),'Hex/GitHub bytes '+package)
    require(hashlib.sha256(payload).hexdigest()==metadata['checksum'],'Hex API checksum '+package)
    (hex_dir/filename).write_bytes(payload)
    with tarfile.open(hex_dir/filename) as tar:
        info=tar.extractfile('metadata.config').read().decode()
        if package == 'gaoxy_http':
            with tarfile.open(fileobj=io.BytesIO(tar.extractfile('contents.tar.gz').read()),mode='r:gz') as contents:
                actual=contents.extractfile('lib/gaoxy/http/exchange.ex').read()
            source=Path('apps/gaoxy_http/lib/gaoxy/http/exchange.ex').read_bytes()
            require(actual==source,'published Exchange equals reviewed source')
        require('{<<"version">>,<<"'+VERSION+'">>}' in info,'Hex archive version '+package)
with tarfile.open(assets/f'gaoxy-{VERSION}-linux-x86_64.tar.gz') as tar:
    names=tar.getnames()
    require(not any('/lib/gaoxy_test-' in n or '/lib/ex_unit-' in n for n in names),
            'standalone excludes gaoxy_test and ex_unit')
    require(any('/releases/'+VERSION+'/' in n for n in names),'standalone release version')
require(len(release['assets'])==8,'exactly eight release assets')
receipt={'release':release['url'],'checks':checks,'status':'PASS'}
(OUT/'publication-readback.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
