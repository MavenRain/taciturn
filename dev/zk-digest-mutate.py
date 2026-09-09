"""Require compiling digest mutants to fail their named native or oracle checks."""
from pathlib import Path
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / ".gatework" / "digest-mutants"
MUTANTS = [
    ("witness", '"taciturn-circuit\\000"; Binary.u32 1;',
     'String.concat "" (List.map Fp.to_bytes_le c.witness); '
     '"taciturn-circuit\\000"; Binary.u32 1;', "native", "mul-witness-1000"),
    ("pre-import", 'framed "pre"; to_hex imports.pre;',
     'framed "pre"; to_hex imports.zk;', "native", "pre-import"),
    ("coefficient", "[ r.ql; r.qr; r.qo; r.qm; r.qc ]",
     "[ r.ql; r.qr; r.qo; r.qm; Fp.zero ]", "native", "selector-qc"),
    ("booleanity", "let rows = c.rows in",
     "let rows = List.filter (fun (r : Rows.row) -> not "
     "(Fp.equal r.qm Fp.one && Fp.equal r.ql (Fp.neg Fp.one))) c.rows in",
     "native", "booleanity-row"),
    ("public-output-count", "Binary.u32 c.n_pub_out;", "Binary.u32 1;",
     "native", "public-output-count-isolated"),
    ("public-input-count", "Binary.u32 c.n_pub_in;", "Binary.u32 0;",
     "native", "public-input-count"),
    ("private-input-count", "Binary.u32 c.n_priv;", "Binary.u32 0;",
     "native", "private-input-count-isolated"),
    ("domain", '"taciturn-circuit\\000"; Binary.u32 1;', 'Binary.u32 1;',
     "oracle", "mul-encoding-0"),
    ("format-version", '"taciturn-circuit\\000"; Binary.u32 1;',
     '"taciturn-circuit\\000"; Binary.u32 2;', "oracle", "mul-encoding-0"),
    ("frame-width", "let framed s = Binary.u64 (String.length s) ^ s",
     "let framed s = Binary.u32 (String.length s) ^ s", "oracle", "mul-encoding-0"),
    ("wire-count", "Binary.u32 c.n_wires;", "Binary.u32 0;",
     "native", "allocated-wires"),
]


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ)
    environment.pop("OPAM_SWITCH_PREFIX", None)
    for name, before, after, suite, diagnostic in MUTANTS:
        target = WORK / name
        if target.exists():
            shutil.rmtree(target)
        target.mkdir()
        for directory in ("zk", "zk_host", "test/zk", "test/digest", "spike/rows"):
            shutil.copytree(ROOT / directory, target / directory)
        (target / "dev").mkdir()
        for relative in ("dune", "dune-project", "dev/dune.sh", "dev/dunecho.sh"):
            shutil.copy2(ROOT / relative, target / relative)
        source = target / "zk/digest.ml"
        original = source.read_text()
        if original.count(before) != 1:
            raise RuntimeError(f"{name}: mutation anchor is not unique")
        source.write_text(original.replace(before, after))
        environment["DUNE_ROOT"] = str(target)
        build = subprocess.run(["zsh", "dev/dunecho.sh", "build"], cwd=target,
                               env=environment, capture_output=True, text=True, timeout=300)
        (target / "build.log").write_text(build.stdout + build.stderr)
        if build.returncode != 0 or "OK build: 0 errors, 0 warnings" not in build.stdout:
            raise RuntimeError(f"{name}: mutant failed to build; see {target / 'build.log'}")
        test = subprocess.run([str(target / "_build/default/test/digest/identity.exe")],
                              cwd=target, capture_output=True, text=True, timeout=60)
        (target / "test.log").write_text(test.stdout + test.stderr)
        oracle = subprocess.run(["node", str(target / "test/digest/check.mjs"),
                                 str(target / "_build/default/test/digest/probe.exe")],
                                cwd=target, capture_output=True, text=True, timeout=300)
        (target / "oracle.log").write_text(oracle.stdout + oracle.stderr)
        native_kill = (test.returncode == 1
                       and f"DIGEST FAIL {diagnostic}" in test.stderr.splitlines())
        oracle_kill = (oracle.returncode != 0
                       and f"DIGEST-JS FAIL {diagnostic}" in oracle.stderr.splitlines())
        killed = native_kill if suite == "native" else oracle_kill
        if not killed:
            raise RuntimeError(f"{name}: expected check did not reject mutant")
        print(f"DIGEST-MUTANT {name} CAUGHT {suite} {diagnostic}", flush=True)
    print(f"DIGEST-MUTATIONS-OK {len(MUTANTS)}/{len(MUTANTS)}", flush=True)


if __name__ == "__main__":
    main()
