"""SQLite persistence for YEET ARENA scores.

Uses the standard library only (sqlite3) so the backend has no ORM dependency.
A single checked-in schema is created on startup; WAL mode keeps reads fast.
"""

from __future__ import annotations

import sqlite3
import pathlib
from datetime import datetime, timezone
from typing import Any

SCHEMA = """
CREATE TABLE IF NOT EXISTS scores (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    player_name     TEXT    NOT NULL,
    fighter         TEXT    NOT NULL,
    opponent        TEXT    NOT NULL DEFAULT '',
    mode            TEXT    NOT NULL DEFAULT 'arcade',
    score           INTEGER NOT NULL,
    kos             INTEGER NOT NULL DEFAULT 0,
    max_combo       INTEGER NOT NULL DEFAULT 0,
    duration        REAL    NOT NULL DEFAULT 0,
    victory         INTEGER NOT NULL DEFAULT 0,
    client_match_id TEXT,
    client_version  TEXT    NOT NULL DEFAULT '1.0.0',
    created_at      TEXT    NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_scores_match
    ON scores(client_match_id) WHERE client_match_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_scores_score ON scores(score DESC);
CREATE INDEX IF NOT EXISTS idx_scores_fighter ON scores(fighter);
CREATE INDEX IF NOT EXISTS idx_scores_mode ON scores(mode);
"""


def connect(db_path: pathlib.Path | str) -> sqlite3.Connection:
    """Open (and create) the database, enabling WAL + foreign keys."""
    path = pathlib.Path(db_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    return conn


def init_db(conn: sqlite3.Connection) -> None:
    conn.executescript(SCHEMA)
    conn.commit()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def insert_score(conn: sqlite3.Connection, payload: dict[str, Any]) -> dict[str, Any]:
    """Insert a validated score and return the stored row plus its rank."""
    match_id = (payload.get("client_match_id") or "").strip() or None
    cur = conn.execute(
        """
        INSERT INTO scores (player_name, fighter, opponent, mode, score, kos, max_combo,
                            duration, victory, client_match_id, client_version, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            payload["player_name"],
            payload["fighter"],
            payload.get("opponent", ""),
            payload.get("mode", "arcade"),
            int(payload["score"]),
            int(payload.get("kos", 0)),
            int(payload.get("max_combo", 0)),
            float(payload.get("duration", 0.0)),
            1 if payload.get("victory") else 0,
            match_id,
            payload.get("client_version", "1.0.0"),
            utc_now(),
        ),
    )
    conn.commit()
    row_id = int(cur.lastrowid)
    row = conn.execute("SELECT * FROM scores WHERE id = ?", (row_id,)).fetchone()
    data = row_to_dict(row)
    data["rank"] = rank_of(conn, int(payload["score"]), str(payload.get("mode", "arcade")))
    return data


def match_exists(conn: sqlite3.Connection, client_match_id: str) -> bool:
    if not client_match_id:
        return False
    row = conn.execute(
        "SELECT 1 FROM scores WHERE client_match_id = ? LIMIT 1", (client_match_id,)
    ).fetchone()
    return row is not None


def rank_of(conn: sqlite3.Connection, score: int, mode: str = "arcade") -> int:
    row = conn.execute(
        "SELECT COUNT(*) AS c FROM scores WHERE mode = ? AND score > ?", (mode, int(score))
    ).fetchone()
    return int(row["c"]) + 1


def count_scores(conn: sqlite3.Connection, fighter: str = "") -> int:
    if fighter:
        row = conn.execute("SELECT COUNT(*) AS c FROM scores WHERE fighter = ?", (fighter,)).fetchone()
    else:
        row = conn.execute("SELECT COUNT(*) AS c FROM scores").fetchone()
    return int(row["c"])


def fetch_scores(
    conn: sqlite3.Connection, fighter: str = "", limit: int = 10, offset: int = 0
) -> list[dict[str, Any]]:
    sql = (
        "SELECT * FROM scores "
        + ("WHERE fighter = ? " if fighter else "")
        + "ORDER BY score DESC, created_at ASC, id ASC LIMIT ? OFFSET ?"
    )
    params: list[Any] = ([fighter] if fighter else []) + [int(limit), int(offset)]
    rows = conn.execute(sql, params).fetchall()
    out: list[dict[str, Any]] = []
    for i, row in enumerate(rows):
        data = row_to_dict(row)
        data["rank"] = int(offset) + i + 1
        out.append(data)
    return out


def stats(conn: sqlite3.Connection) -> dict[str, Any]:
    totals = conn.execute(
        """
        SELECT COUNT(*) AS matches,
               COALESCE(AVG(score), 0) AS avg_score,
               COALESCE(MAX(score), 0) AS best_score,
               COALESCE(SUM(kos), 0) AS total_kos,
               COALESCE(SUM(victory), 0) AS wins
        FROM scores
        """
    ).fetchone()
    modes = {
        row["mode"]: int(row["c"])
        for row in conn.execute("SELECT mode, COUNT(*) AS c FROM scores GROUP BY mode").fetchall()
    }
    by_fighter = [
        {
            "fighter": row["fighter"],
            "matches": int(row["c"]),
            "best": int(row["best"] or 0),
            "average": round(float(row["avg"] or 0.0), 1),
            "wins": int(row["wins"] or 0),
        }
        for row in conn.execute(
            """
            SELECT fighter, COUNT(*) AS c, MAX(score) AS best, AVG(score) AS avg,
                   SUM(victory) AS wins
            FROM scores GROUP BY fighter ORDER BY c DESC, fighter ASC
            """
        ).fetchall()
    ]
    matches = int(totals["matches"])
    top_fighter = ""
    if by_fighter:
        ranked = sorted(
            by_fighter, key=lambda f: (f["matches"], f["best"]), reverse=True
        )
        top_fighter = str(ranked[0]["fighter"])
    return {
        "total_matches": matches,
        "arcade_matches": modes.get("arcade", 0),
        "demo_matches": modes.get("demo", 0),
        "average_score": round(float(totals["avg_score"]), 1),
        "best_score": int(totals["best_score"]),
        "total_kos": int(totals["total_kos"]),
        "wins": int(totals["wins"]),
        "win_rate": round(float(totals["wins"]) / matches, 3) if matches else 0.0,
        "top_fighter": top_fighter,
        "by_fighter": by_fighter,
    }


def row_to_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": int(row["id"]),
        "player_name": row["player_name"],
        "fighter": row["fighter"],
        "opponent": row["opponent"],
        "mode": row["mode"],
        "score": int(row["score"]),
        "kos": int(row["kos"]),
        "max_combo": int(row["max_combo"]),
        "duration": float(row["duration"]),
        "victory": bool(row["victory"]),
        "client_match_id": row["client_match_id"] or "",
        "client_version": row["client_version"],
        "created_at": row["created_at"],
    }
