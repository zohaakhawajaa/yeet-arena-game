"""YEET ARENA backend configuration."""

from __future__ import annotations

import os
import pathlib

APP_NAME = "yeet-arena-api"
VERSION = "1.0.0"

BASE_DIR = pathlib.Path(__file__).resolve().parent.parent

DB_PATH = pathlib.Path(os.environ.get("YEET_DB_PATH", str(BASE_DIR / "yeet_scores.db")))

HOST = os.environ.get("YEET_API_HOST", "127.0.0.1")
PORT = int(os.environ.get("YEET_API_PORT", "8000"))

VALID_FIGHTERS: tuple[str, ...] = ("volt", "brick", "phantom", "chaos", "titan", "glitch")
VALID_MODES: tuple[str, ...] = ("arcade", "demo")

MAX_SCORE = 5_000_000
MAX_DURATION = 600.0

RATE_LIMIT_MAX_POSTS = 30
RATE_LIMIT_WINDOW_SEC = 60.0
