"""Behavioral tests for the sourced writable-copy installer (GNU tools on PATH)."""
from pathlib import Path
import os
import subprocess
import shutil
import sys
import tempfile

helper = str(Path(sys.argv[1]).resolve())
root = Path(tempfile.mkdtemp(prefix="mutable-copy-"))
src = root / "source"
src.write_text("baseline\n")
dst = root / "home with spaces/config"


def invoke(action="installMutableCopy", source=src, target=dst, fail=None, dry=False, ok=True):
    env = dict(os.environ)
    env.pop("DRY_RUN", None)
    if dry:
        env["DRY_RUN"] = "1"
    if fail:
        fake = root / ("fake-" + fail)
        fake.mkdir(exist_ok=True)
        executable = fake / fail
        if fail == "mv":
            # Fail only publishing the staged content, allowing rollback to run.
            executable.write_text('#!/usr/bin/env bash\ncase "$*" in *hm-stage.*/content*) exit 71;; esac\nexec "' + shutil.which("mv") + '" "$@"\n')
        else:
            executable.write_text("#!/usr/bin/env bash\nexit 2\n")
        executable.chmod(0o755)
        env["PATH"] = str(fake) + os.pathsep + env["PATH"]
    arguments = [str(source), str(target), "u+w" if source.is_dir() else "600"] if action == "installMutableCopy" else [str(target)]
    result = subprocess.run(["bash", "-c", 'set -euo pipefail; source "$1"; shift; "$@"', "test", helper, action, *arguments], env=env, text=True, capture_output=True)
    assert (result.returncode == 0) == ok, result.stdout + result.stderr


invoke(dry=True)
assert not dst.parent.exists()
invoke()
assert dst.read_text() == "baseline\n" and not dst.is_symlink()
assert dst.stat().st_mode & 0o777 == 0o600

dst.write_text("local edit one\n")
invoke()
backups = list(dst.parent.glob("config.hm-bak.*/original"))
assert len(backups) == 1 and backups[0].read_text() == "local edit one\n"
invoke()
assert list(dst.parent.glob("config.hm-bak.*/original")) == backups

dst.write_text("local edit two\n")
invoke()
assert sorted(p.read_text() for p in dst.parent.glob("config.hm-bak.*/original")) == ["local edit one\n", "local edit two\n"]

for failure in ["cp", "chmod", "diff", "mv"]:
    dst.write_text("survives " + failure)
    invoke(fail=failure, ok=False)
    assert dst.read_text() == "survives " + failure
    assert not list(dst.parent.glob("config.hm-stage.*"))

# Broken symlinks are backed up as links, not followed or written through.
dst.unlink()
dst.symlink_to(root / "missing")
invoke()
assert not dst.is_symlink() and dst.read_text() == "baseline\n"
assert any((p / "original").is_symlink() for p in dst.parent.glob("config.hm-bak.*"))

# Directory deployment stages first; publication failures restore the old tree.
tree = root / "tree-source"
tree.mkdir()
(tree / "init.lua").write_text("new tree")
tree_dst = root / "tree-target"
tree_dst.mkdir()
(tree_dst / "init.lua").write_text("edited tree")
invoke(source=tree, target=tree_dst, fail="cp", ok=False)
assert (tree_dst / "init.lua").read_text() == "edited tree"
invoke(source=tree, target=tree_dst, fail="mv", ok=False)
assert (tree_dst / "init.lua").read_text() == "edited tree"
invoke(source=tree, target=tree_dst)
assert (tree_dst / "init.lua").read_text() == "new tree"
assert any((p / "init.lua").read_text() == "edited tree" for p in root.glob("tree-target.hm-bak.*/original"))
invoke(action="preserveMutableCopy", target=tree_dst, dry=True)
assert tree_dst.is_dir()
invoke(action="preserveMutableCopy", target=tree_dst)
assert not tree_dst.exists()
assert any((p / "init.lua").read_text() == "new tree" for p in root.glob("tree-target.hm-bak.*/original"))
print("Writable-copy tests passed: files, directories, repeated switches, backups, symlinks, dry runs, failed preparation and rollback")
