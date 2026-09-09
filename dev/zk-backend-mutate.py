"""Build isolated backend mutants and require the corresponding test failures."""
from pathlib import Path
import os
import shutil
import subprocess


ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / ".gatework" / "backend-mutants"
MUTANTS = [
    ("booleanity", "zk/rows.ml", "let* st = assert_bit st bit in",
     "let* st = Ok st in", "select-rejects-two"),
    ("residual", "zk/lower.ml", "if linear r && k.c = [] then None else Some k",
     "if linear r then None else Some k", "repeated-definition"),
    ("ordering", "zk/lower.ml", "Wires.bindings merged",
     "List.rev (Wires.bindings merged)", "canonical-terms"),
]


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ)
    environment.pop("OPAM_SWITCH_PREFIX", None)
    for name, relative, before, after, diagnostic in MUTANTS:
        target = WORK / name
        if target.exists():
            shutil.rmtree(target)
        target.mkdir()
        for relative_dir in ("zk", "test/zk", "spike/rows"):
            shutil.copytree(ROOT / relative_dir, target / relative_dir)
        (target / "dev").mkdir()
        for relative_file in ("dune", "dune-project", "dev/dune.sh", "dev/dunecho.sh"):
            shutil.copy2(ROOT / relative_file, target / relative_file)
        source = target / relative
        text = source.read_text()
        if text.count(before) != 1:
            raise RuntimeError(f"{name}: mutation anchor is not unique")
        source.write_text(text.replace(before, after))
        environment["DUNE_ROOT"] = str(target)
        build = subprocess.run(["zsh", "dev/dunecho.sh", "build"], cwd=target,
                               env=environment, capture_output=True, text=True, timeout=60)
        (target / "build.log").write_text(build.stdout + build.stderr)
        if build.returncode != 0 or "OK build: 0 errors, 0 warnings" not in build.stdout:
            raise RuntimeError(f"{name}: mutant failed to build; see {target / 'build.log'}")
        test = subprocess.run([str(target / "_build/default/test/zk/backend.exe")],
                              cwd=target, capture_output=True, text=True, timeout=15)
        (target / "test.log").write_text(test.stdout + test.stderr)
        if test.returncode != 1 or f"BACKEND FAIL {diagnostic}" not in test.stderr.splitlines():
            raise RuntimeError(f"{name}: expected test did not reject mutant")
        print(f"BACKEND-MUTANT {name} CAUGHT {diagnostic}", flush=True)
    print(f"BACKEND-MUTATIONS-OK {len(MUTANTS)}/{len(MUTANTS)}", flush=True)


if __name__ == "__main__":
    main()
