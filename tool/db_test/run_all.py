"""Runs every database test (tool/db_test/test_*.py), each on its own fresh
database with every migration applied. Exits non-zero if any fails.

  pip install -r tool/db_test/requirements.txt
  python3 tool/db_test/run_all.py
"""
import glob
import os
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
failed = []
for test in sorted(glob.glob(os.path.join(here, "test_*.py"))):
    name = os.path.basename(test)
    print(f"── {name}")
    if subprocess.run([sys.executable, test], cwd=here).returncode != 0:
        failed.append(name)
print()
print("All database tests passed." if not failed else f"Failed: {', '.join(failed)}")
sys.exit(1 if failed else 0)
