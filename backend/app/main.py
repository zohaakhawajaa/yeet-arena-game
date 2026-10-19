"""YEET ARENA leaderboard API.

FastAPI + SQLite. Run with:

    uvicorn app.main:app --host 127.0.0.1 --port 8000
    # or
    python -m app.main

The Godot client talks to:
    GET  /health
    GET  /api/scores?limit=&offset=&fighter=
    GET  /api/stats
    POST /api/scores
"""

from __future__ import annotations

import sqlite3
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any, AsyncIterator

from fastapi import FastAPI, HTTPException, Query, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import db as database
from .config import (
    APP_NAME,
    DB_PATH,
    HOST,
    PORT,
    RATE_LIMIT_MAX_POSTS,
    RATE_LIMIT_WINDOW_SEC,
    VALID_FIGHTERS,
    VERSION,
)
from .schemas import ScoreIn


def create_app(db_path: Path | str | None = None) -> FastAPI:
    """Application factory - tests pass a temporary database path."""
    path = Path(db_path) if db_path is not None else DB_PATH

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        conn = database.connect(path)
        database.init_db(conn)
        app.state.conn = conn
        app.state.rate = {}
        try:
            yield
        finally:
            conn.close()

    app = FastAPI(
        title="YEET ARENA Leaderboard API",
        description="Score submission and rankings for the YEET ARENA arcade fighter.",
        version=VERSION,
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    def conn_of(request: Request) -> sqlite3.Connection:
        conn: sqlite3.Connection = request.app.state.conn
        return conn

    def rate_limit(request: Request) -> None:
        """Cheap in-memory limiter for submissions (single-process friendly)."""
        client = request.client.host if request.client else "unknown"
        bucket: dict[str, list[float]] = request.app.state.rate
        now = time.monotonic()
        stamps = [t for t in bucket.get(client, []) if now - t < RATE_LIMIT_WINDOW_SEC]
        if len(stamps) >= RATE_LIMIT_MAX_POSTS:
            bucket[client] = stamps
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many submissions - try again in a moment.",
            )
        stamps.append(now)
        bucket[client] = stamps

    # ------------------------------------------------------------------ meta

    @app.get("/")
    def index() -> dict[str, Any]:
        return {
            "service": APP_NAME,
            "version": VERSION,
            "docs": "/docs",
            "endpoints": ["/health", "/api/scores", "/api/stats"],
        }

    @app.get("/health")
    def health(request: Request) -> dict[str, Any]:
        conn = conn_of(request)
        return {
            "status": "ok",
            "service": APP_NAME,
            "version": VERSION,
            "matches": database.count_scores(conn),
            "server_time": database.utc_now(),
        }

    # ---------------------------------------------------------------- scores

    @app.get("/api/scores")
    def list_scores(
        request: Request,
        limit: int = Query(default=10, ge=1, le=100),
        offset: int = Query(default=0, ge=0, le=100_000),
        fighter: str = Query(default=""),
    ) -> dict[str, Any]:
        conn = conn_of(request)
        wanted = fighter.strip().lower()
        if wanted and wanted not in VALID_FIGHTERS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"unknown fighter filter: {fighter}",
            )
        scores = database.fetch_scores(conn, wanted, limit, offset)
        return {
            "scores": scores,
            "count": database.count_scores(conn, wanted),
            "fighter": wanted,
            "limit": limit,
            "offset": offset,
        }

    @app.post("/api/scores", status_code=status.HTTP_201_CREATED)
    def submit_score(payload: ScoreIn, request: Request, response: Response) -> dict[str, Any]:
        rate_limit(request)
        conn = conn_of(request)
        data = payload.model_dump()
        if data["client_match_id"] and database.match_exists(conn, data["client_match_id"]):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This match was already submitted.",
            )
        try:
            stored = database.insert_score(conn, data)
        except sqlite3.IntegrityError:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This match was already submitted.",
            )
        beats = int(conn.execute("SELECT COUNT(*) AS c FROM scores", ()).fetchone()["c"])
        return {
            "id": stored["id"],
            "rank": stored["rank"],
            "score": stored["score"],
            "fighter": stored["fighter"],
            "player_name": stored["player_name"],
            "mode": stored["mode"],
            "created_at": stored["created_at"],
            "entries": beats,
            "message": f"Rank {stored['rank']} with {stored['score']} points!",
        }

    @app.get("/api/stats")
    def get_stats(request: Request) -> dict[str, Any]:
        conn = conn_of(request)
        return database.stats(conn)

    # ---------------------------------------------------------------- errors

    @app.exception_handler(HTTPException)
    async def http_error(_request: Request, exc: HTTPException) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail, "status": exc.status_code},
        )

    return app


app = create_app()


def main() -> None:
    import uvicorn

    uvicorn.run("app.main:app", host=HOST, port=PORT, reload=False)


if __name__ == "__main__":
    main()
