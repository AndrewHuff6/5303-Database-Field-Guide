"""
Shared test setup: one small database per test session.

It's generated into a temp folder (as idx_10k.db), and DATA_DIR is pointed at
it before the app is imported, so the tests never touch your real databases.
"""

from __future__ import annotations

import importlib
import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "datasets" / "store" / "generator"))


@pytest.fixture(scope="session")
def client(tmp_path_factory):
    data = tmp_path_factory.mktemp("data")

    import scale_data
    scale_data.build(str(data / "idx_10k.db"), customers=200, products=150,
                     zipcodes=60, purchases=3_000, skew=True, seed=7)
    con = __import__("sqlite3").connect(data / "idx_10k.db")
    con.executescript((ROOT / "units/01_sqlite/05_load/summary_tables.sql").read_text())
    con.close()

    os.environ["DATA_DIR"] = str(data)

    from fastapi.testclient import TestClient
    import app.experiment
    importlib.reload(app.experiment)          # pick up DATA_DIR
    import app.main
    importlib.reload(app.main)

    with TestClient(app.main.app) as c:
        yield c
