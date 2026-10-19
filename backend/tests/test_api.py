"""End-to-end tests for the YEET ARENA leaderboard API."""

from __future__ import annotations

import copy

from fastapi.testclient import TestClient


def post(client: TestClient, sample: dict, **overrides):
    payload = dict(sample)
    payload.update(overrides)
    return client.post("/api/scores", json=payload)


# --------------------------------------------------------------- health + meta

def test_health_ok(client: TestClient):
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["service"] == "yeet-arena-api"
    assert body["version"] == "1.0.0"
    assert body["matches"] == 0
    assert "server_time" in body


def test_index_lists_endpoints(client: TestClient):
    r = client.get("/")
    assert r.status_code == 200
    assert "/api/scores" in r.json()["endpoints"]


def test_health_counts_increase(client: TestClient, sample: dict):
    post(client, sample)
    assert client.get("/health").json()["matches"] == 1


# ------------------------------------------------------------------ submissions

def test_submit_returns_rank_and_fields(client: TestClient, sample: dict):
    r = post(client, sample)
    assert r.status_code == 201
    body = r.json()
    assert body["rank"] == 1
    assert body["score"] == 4820
    assert body["fighter"] == "volt"
    assert body["player_name"] == "NOVA"
    assert body["mode"] == "arcade"
    assert body["entries"] == 1
    assert "Rank 1" in body["message"]


def test_ranks_follow_score_order(client: TestClient, sample: dict):
    assert post(client, sample, score=100, client_match_id="a").json()["rank"] == 1
    assert post(client, sample, score=900, client_match_id="b").json()["rank"] == 1
    assert post(client, sample, score=500, client_match_id="c").json()["rank"] == 2
    assert post(client, sample, score=50, client_match_id="d").json()["rank"] == 4


def test_rank_scope_is_per_mode(client: TestClient, sample: dict):
    assert post(client, sample, score=4000, client_match_id="arc-1").json()["rank"] == 1
    demo = post(client, sample, mode="demo", score=100, client_match_id="demo-1")
    assert demo.status_code == 201
    assert demo.json()["rank"] == 1


def test_duplicate_match_id_conflicts(client: TestClient, sample: dict):
    assert post(client, sample).status_code == 201
    again = post(client, sample, score=1)
    assert again.status_code == 409
    assert "already" in again.json()["detail"].lower()
    assert client.get("/api/scores").json()["count"] == 1


def test_missing_match_id_allows_repeats(client: TestClient, sample: dict):
    assert post(client, sample, client_match_id="").status_code == 201
    assert post(client, sample, client_match_id="").status_code == 201
    assert client.get("/api/scores").json()["count"] == 2


def test_payload_is_normalized(client: TestClient, sample: dict):
    r = post(client, sample, player_name="  nova  ", fighter="VOLT")
    assert r.status_code == 201
    assert r.json()["player_name"] == "nova"
    assert r.json()["fighter"] == "volt"


# ------------------------------------------------------------------- validation

def test_validation_rejects_bad_payloads(client: TestClient, sample: dict):
    bad = [
        {"player_name": "X"},
        {"player_name": "  "},
        {"player_name": "A" * 17},
        {"player_name": "bad\tname"},
        {"fighter": "goku"},
        {"fighter": ""},
        {"opponent": "goku"},
        {"mode": "ranked"},
        {"score": -1},
        {"score": 5_000_001},
        {"kos": 100},
        {"max_combo": 1000},
        {"duration": 601.0},
        {"victory": "yes"},
        {"score": "lots"},
        {"client_match_id": "x" * 65},
    ]
    for overrides in bad:
        r = post(client, sample, **overrides)
        assert r.status_code == 422, f"expected 422 for {overrides}, got {r.status_code}"
    assert client.get("/api/scores").json()["count"] == 0


def test_invalid_json_body(client: TestClient):
    r = client.post("/api/scores", content=b"{not json", headers={"Content-Type": "application/json"})
    assert r.status_code == 422


# ---------------------------------------------------------------------- queries

def test_list_defaults_and_shape(client: TestClient, sample: dict):
    post(client, sample)
    r = client.get("/api/scores")
    assert r.status_code == 200
    body = r.json()
    assert body["count"] == 1
    assert body["limit"] == 10
    assert body["offset"] == 0
    assert body["fighter"] == ""
    entry = body["scores"][0]
    for key in ("id", "player_name", "fighter", "score", "kos", "max_combo", "victory", "rank", "created_at"):
        assert key in entry
    assert entry["victory"] is True
    assert entry["rank"] == 1


def test_scores_sorted_by_score_desc(client: TestClient, sample: dict):
    for i, score in enumerate([10, 900, 400, 700]):
        post(client, sample, score=score, client_match_id=f"s{i}", player_name=f"P{i}")
    scores = [s["score"] for s in client.get("/api/scores").json()["scores"]]
    assert scores == [900, 700, 400, 10]


def test_fighter_filter(client: TestClient, sample: dict):
    post(client, sample, fighter="volt", client_match_id="v1")
    post(client, sample, fighter="brick", client_match_id="b1")
    body = client.get("/api/scores", params={"fighter": "brick"}).json()
    assert body["count"] == 1
    assert body["fighter"] == "brick"
    assert body["scores"][0]["fighter"] == "brick"


def test_unknown_fighter_filter_rejected(client: TestClient):
    r = client.get("/api/scores", params={"fighter": "goku"})
    assert r.status_code == 400
    assert "unknown fighter" in r.json()["detail"]


def test_paging(client: TestClient, sample: dict):
    for i in range(5):
        post(client, sample, score=100 + i * 10, client_match_id=f"p{i}")
    page1 = client.get("/api/scores", params={"limit": 2, "offset": 0}).json()
    page2 = client.get("/api/scores", params={"limit": 2, "offset": 2}).json()
    assert [s["score"] for s in page1["scores"]] == [140, 130]
    assert [s["score"] for s in page2["scores"]] == [120, 110]
    assert page1["count"] == 5
    assert page1["scores"][0]["rank"] == 1
    assert page2["scores"][0]["rank"] == 3


def test_query_validation(client: TestClient):
    assert client.get("/api/scores", params={"limit": 0}).status_code == 422
    assert client.get("/api/scores", params={"limit": 101}).status_code == 422
    assert client.get("/api/scores", params={"offset": -5}).status_code == 422


# ------------------------------------------------------------------------ stats

def test_stats_empty(client: TestClient):
    body = client.get("/api/stats").json()
    assert body["total_matches"] == 0
    assert body["average_score"] == 0
    assert body["top_fighter"] == ""
    assert body["by_fighter"] == []


def test_stats_aggregates(client: TestClient, sample: dict):
    post(client, sample, fighter="volt", score=1000, victory=True, kos=2, client_match_id="s1")
    post(client, sample, fighter="volt", score=2000, victory=False, kos=1, client_match_id="s2")
    post(client, sample, fighter="brick", score=3000, victory=True, kos=0, client_match_id="s3")
    post(client, sample, fighter="chaos", mode="demo", score=500, kos=0, victory=False, client_match_id="s4")
    body = client.get("/api/stats").json()
    assert body["total_matches"] == 4
    assert body["arcade_matches"] == 3
    assert body["demo_matches"] == 1
    assert body["average_score"] == 1625.0
    assert body["best_score"] == 3000
    assert body["total_kos"] == 3
    assert body["wins"] == 2
    assert body["win_rate"] == 0.5
    assert body["top_fighter"] == "volt"
    by_fighter = {row["fighter"]: row for row in body["by_fighter"]}
    assert by_fighter["volt"]["matches"] == 2
    assert by_fighter["volt"]["best"] == 2000
    assert by_fighter["volt"]["average"] == 1500.0
    assert by_fighter["brick"]["wins"] == 1


# ---------------------------------------------------------------- rate limiting

def test_rate_limit_blocks_flood(client: TestClient, sample: dict):
    for i in range(30):
        assert post(client, sample, client_match_id=f"flood-{i}").status_code == 201
    blocked = post(client, sample, client_match_id="flood-final")
    assert blocked.status_code == 429
    assert "too many" in blocked.json()["detail"].lower()


# ------------------------------------------------------------------- persistence

def test_database_persists_across_restarts(client: TestClient, sample: dict, db_file):
    post(client, sample)
    from app.main import create_app

    with TestClient(create_app(db_file)) as second:
        body = second.get("/api/scores").json()
        assert body["count"] == 1
        assert body["scores"][0]["score"] == 4820


def test_payload_is_not_mutated_by_server(client: TestClient, sample: dict):
    payload = copy.deepcopy(sample)
    post(client, payload)
    assert payload == sample
