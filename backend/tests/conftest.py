"""Shared pytest fixtures: an isolated app + database per test."""

from __future__ import annotations

import pathlib
import sys
from typing import Iterator

import pytest
from fastapi.testclient import TestClient

BACKEND_DIR = pathlib.Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.main import create_app  # noqa: E402


@pytest.fixture()
def db_file(tmp_path: pathlib.Path) -> pathlib.Path:
    return tmp_path / "yeet_test_scores.db"


@pytest.fixture()
def client(db_file: pathlib.Path) -> Iterator[TestClient]:
    app = create_app(db_file)
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture()
def sample() -> dict:
    return {
        "player_name": "NOVA",
        "fighter": "volt",
        "opponent": "brick",
        "mode": "arcade",
        "score": 4820,
        "kos": 2,
        "max_combo": 7,
        "duration": 58.4,
        "victory": True,
        "client_match_id": "m-test-0001",
        "client_version": "1.0.0",
    }
