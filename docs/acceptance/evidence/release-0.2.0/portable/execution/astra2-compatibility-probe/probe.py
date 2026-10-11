import ast
import io
import json
import os
from pathlib import Path
import stat
import sys
import tarfile
import tempfile

source = Path("/candidate/runtime.py").read_text()
tree = ast.parse(source)
block = next(node for node in tree.body if isinstance(node, ast.With)
             and ast.unparse(node.items[0].context_expr) == "tarfile.open(archive)")
code = compile(ast.Module(body=[block], type_ignores=[]), "/candidate/runtime.py:extraction", "exec")

def extract(archive, destination):
    destination.mkdir()
    exec(code, {"tarfile": tarfile, "Path": Path, "RELEASE": destination, "archive": archive})

results = []
with tempfile.TemporaryDirectory(prefix="gaoxy-extraction-probe-") as directory:
    root = Path(directory)
    actual = root / "actual"
    archive = Path("/artifacts/gaoxy-0.2.0-linux-x86_64.tar.gz")
    extract(archive, actual)
    assert (actual / "releases/start_erl.data").read_text().split()[1] == "0.2.0"
    assert os.access(actual / "bin/gaoxy", os.X_OK)
    with tarfile.open(archive) as package:
        files = [m for m in package.getmembers() if m.isfile()]
        for member in files:
            path = actual / member.name
            assert path.read_bytes() == package.extractfile(member).read(), member.name
            assert not (path.stat().st_mode & 0o7022), member.name
            assert path.stat().st_uid == 0 and path.stat().st_gid == 0, member.name
    results.append({"case": "actual_archive", "status": "PASS", "files": len(files)})
    outside = root / "outside"
    cases = [("absolute", str(outside), tarfile.REGTYPE),
             ("parent_escape", "../outside", tarfile.REGTYPE),
             ("symbolic_link", "link", tarfile.SYMTYPE),
             ("hard_link", "link", tarfile.LNKTYPE),
             ("fifo", "fifo", tarfile.FIFOTYPE),
             ("character_device", "device", tarfile.CHRTYPE)]
    for index, (name, member_name, kind) in enumerate(cases):
        crafted = root / (name + ".tar")
        with tarfile.open(crafted, "w") as package:
            good = tarfile.TarInfo("prefix.txt"); good.size = 1
            package.addfile(good, io.BytesIO(b"x"))
            bad = tarfile.TarInfo(member_name); bad.type = kind
            bad.linkname = str(outside)
            package.addfile(bad)
        destination = root / ("case" + str(index))
        try:
            extract(crafted, destination)
        except AssertionError:
            pass
        else:
            raise AssertionError("unsafe member accepted: " + name)
        assert list(destination.iterdir()) == [], name
        assert not outside.exists() and not outside.is_symlink(), name
        results.append({"case": name, "status": "PASS", "outside_writes": 0})
    crafted = root / "permissions.tar"
    with tarfile.open(crafted, "w") as package:
        member = tarfile.TarInfo("executable"); member.mode = 0o7777
        member.uid = member.gid = 1234; member.uname = member.gname = "probe"
        member.size = 1; package.addfile(member, io.BytesIO(b"x"))
    extract(crafted, root / "permissions")
    metadata = (root / "permissions/executable").stat()
    assert stat.S_IMODE(metadata.st_mode) == 0o755
    assert metadata.st_uid == 0 and metadata.st_gid == 0
    results.append({"case": "permission_ownership_normalization", "status": "PASS"})
print(json.dumps({"python": sys.version, "status": "PASS", "cases": results}, indent=2))
