# YEET ARENA — verification report

**Date:** 2026-10-19
**Project:** `C:\Users\DELL\yeet-arena`
**Scope:** full project — Godot 4.7.2 client, FastAPI + SQLite backend, generated
audio, test suite, launchers.

---

## 1. Environment

| Item | Value |
| ---- | ----- |
| OS | Windows (win32), PowerShell 5.1 |
| Godot | **4.7.2-stable** (`Godot_v4.7.2-stable_win64_console.exe`), run headless for verification |
| Python | 3.14.7 (3.13 and 3.12 also installed; backend runs on all three) |
| Backend deps | fastapi 0.142.2, pydantic 2.13.5, uvicorn 0.54.0, httpx 0.28.1, pytest 9.1.1 |
| git | 2.55 |

---

## 2. Result summary

| # | Check | Result |
| - | ----- | ------ |
| 1 | Godot project import (all 33 GDScript files parse) | **PASS** — no script errors |
| 2 | Backend test suite (pytest) | **PASS** — 22/22 |
| 3 | Godot menu smoke test (all 6 menu screens through the real router) | **PASS** |
| 4 | Godot full match test (countdown → 3 shrink phases → K.O./time → results) | **PASS** |
| 5 | Godot ↔ backend integration test (health, validation, submit, leaderboard, stats) | **PASS** |
| 6 | `run_tests.bat` end-to-end (all four stages, exit code) | **PASS** — exit 0 |
| 7 | Audio manifest (25 files, format, determinism) | **PASS** |
| 8 | Assets (fonts, icon, resources, scenes) | **PASS** |
| 9 | Packaged `yeet-arena-portfolio.zip` unpacked and re-tested from scratch | **PASS** |

Every stage below was executed, not assumed; the observed output is quoted.

---

## 3. Stage-by-stage evidence

### 3.1 Godot import / script compilation

```
$ GODOT --headless --path C:\Users\DELL\yeet-arena --import
[  16% ] first_scan_filesystem | Loading global class names...
[  50% ] first_scan_filesystem | Creating autoload scripts...
[ DONE ] first_scan_filesystem
[ DONE ] loading_editor_layout
```

Filtered for failures (`SCRIPT ERROR|Failed to load|Parse Error`): **no output**.
The project registers **16 global classes** — `AIController`, `Arena`,
`ArenaBG`, `ArenaCatalog`, `ArenaDef`, `ArenaPreview`, `Fighter`,
`FighterArt`, `FighterCatalog`, `FighterStats`, `Fx`, `MatchHUD`, `MenuScreen`,
`PauseMenu`, `PlayerController`, `ResultsScreen` — plus the 5 autoloads
`Settings`, `UIStyle`, `AudioMan`, `API`, `GameState`.

### 3.2 Backend test suite

```
$ cd backend; python -m pytest
collected 22 items
tests\test_api.py ......................                                 [100%]
============================= 22 passed in 0.54s ==============================
```

Coverage of those 22 tests (`backend/tests/test_api.py`, collected as
`test_health_ok`, `test_index_lists_endpoints`, `test_health_counts_increase`,
`test_submit_returns_rank_and_fields`, `test_ranks_follow_score_order`,
`test_rank_scope_is_per_mode`, `test_duplicate_match_id_conflicts`,
`test_missing_match_id_allows_repeats`, `test_payload_is_normalized`,
`test_validation_rejects_bad_payloads`, `test_invalid_json_body`,
`test_list_defaults_and_shape`, `test_scores_sorted_by_score_desc`,
`test_fighter_filter`, `test_unknown_fighter_filter_rejected`, `test_paging`,
`test_query_validation`, `test_stats_empty`, `test_stats_aggregates`,
`test_rate_limit_blocks_flood`, `test_database_persists_across_restarts`,
`test_payload_is_not_mutated_by_server`):

* health/index shape and the counter increasing between calls
* submission response (`rank`, `score`, `entries`, message), score ordering,
  rank scoping per mode, duplicate `client_match_id` → 409, empty match id
  allows repeats, payload normalisation (name/fighter lower-casing)
* 16 invalid payload shapes → 422 (`player_name` length/control chars, unknown
  fighter/opponent/mode, negative/oversized score, kos/combo/duration ranges,
  non-boolean `victory`, wrong types …), malformed JSON body
* leaderboard shape, descending order, fighter filter (+400 on unknown filter),
  limit/offset paging with per-page ranks, query validation (limit 0/101, negative offset)
* stats on an empty database and with mixed data (averages, best, KOs, wins,
  win-rate, per-fighter rows, demo/arcade split)
* rate limiting → the 31st submission in a minute returns 429
* persistence across an application restart (same DB file)
* input payload is not mutated by the server

### 3.3 Godot menu smoke test

```
$ GODOT --headless --path . --fixed-fps 60 --quit-after 300 res://tests/godot/menu_smoke.tscn -- --no-audio
[smoke] main booted
[smoke] showed title
[smoke] showed fighter_select
[smoke] showed arena_select
[smoke] showed how_to_play
[smoke] showed settings
[smoke] showed leaderboard
[smoke] ALL_MENUS_OK
[smoke] done
```

No `ERROR`/`WARNING` lines in the output. The test drives the real `main.tscn`
router (`show_screen_now`), so screen construction, theme application, animated
backdrops, keyboard focus, API health probing and audio commands all execute.

### 3.4 Godot full match test

```
$ GODOT --headless --path . --fixed-fps 60 --quit-after 6000 res://tests/godot/match_test.tscn -- --no-audio
[match] starting arcade match volt vs glitch in reactor_core
[match] PASS match loaded (2 fighters, arena director active)
[match] PASS results screen shown after the match
[match] ALL_MATCH_OK
```

A complete 60-second arcade match was simulated: countdown, three safe-zone
contractions with warning phases, reactor hazard, combat, timer expiry and the
results screen hand-off — with no script errors.

### 3.5 Godot ↔ backend integration test

Backend started with `python -m uvicorn app.main:app --app-dir backend`:

```
$ GODOT --headless --path . --quit-after 6000 res://tests/godot/api_test.tscn -- --no-audio
[api] target http://127.0.0.1:8000
[api] PASS health check reports online
[api] PASS client validation rejects bad payload: invalid payload: player_name must be 2-16 characters
[api] PASS submission accepted, rank 1.0
[api] PASS leaderboard returns the submitted match (count 1.0)
[api] PASS stats expose total_matches=5.0 top_fighter=volt
[api] ALL_API_OK
```

This exercises the real `api_client.gd`: health probing, local payload
validation, `POST /api/scores` (payload built by `GameState.build_score_payload`),
`GET /api/scores` round-trip by `client_match_id`, and `GET /api/stats`.

### 3.6 Full suite through the launcher

```
$ set GODOT_BIN=...\Godot_v4.7.2-stable_win64_console.exe
$ run_tests.bat
 1/4  Backend tests (pytest)          -> 22 passed
 2/4  Godot menu smoke test           -> [PASS] every menu screen boots cleanly
 3/4  Godot full match test           -> [PASS] full match plays to the results screen
 4/4  Godot to backend API test       -> [PASS] game client talks to the live backend
  RESULT: ALL TESTS PASSED
exit code: 0
```

The launcher also proves `start_backend.bat`-equivalent startup works: stage 4
boots uvicorn, polls `/health` until it answers, runs the test and stops the
temporary backend afterwards.

### 3.7 Audio manifest

```
$ python tools/generate_audio.py
25 files, 1.71 MB written to game/assets/audio
```

Independently re-measured with the Python `wave` module:

```
wav files: 25 | total 1.71 MB
all 22050 Hz mono 16-bit: True
bad: []
missing: []          # all 23 SFX + music_menu + music_match present
unexpected: []
```

Regenerating into a fresh directory produced **byte-identical** files
(deterministic synthesis).

### 3.8 Assets & content

| Item | Verified |
| ---- | -------- |
| Fonts | `Orbitron.ttf`, `Rajdhani-Regular/SemiBold/Bold.ttf` present (OFL, credited) |
| Icon | `icon.svg` present and referenced by `project.godot` |
| Fighters | 6 `.tres` (volt, brick, phantom, chaos, titan, glitch) |
| Arenas | 3 `.tres` (neon_pit, reactor_core, void_circuit) |
| Scenes | 12 `.tscn` (router, gameplay, 6 menus, fighter, tests) |
| Code size | 33 GDScript files / ≈5,100 lines · 9 Python files / ≈1,120 lines |

### 3.9 Boot with audio enabled

```
$ GODOT --headless --path . --fixed-fps 60 --quit-after 200 res://game/scenes/main.tscn
(no SCRIPT ERROR / Invalid / Parse Error lines)
```

### 3.10 The packaged archive

`yeet-arena-portfolio.zip` — **2.18 MB, 173 entries** — excludes `.godot/`
(regenerated on first open), `.git/`, `tools/godot/` (a locally placed engine
binary), `*.db*` and `__pycache__`/`.pytest_cache`.

The archive was then unpacked into an empty directory and re-tested **from the
extracted copy**, to prove it is self-contained:

```
$ Expand-Archive yeet-arena-portfolio.zip  (into an empty folder)
$ GODOT --headless --path <extracted>\yeet-arena --import      # 33 scripts, 16 global classes, no errors
$ GODOT --headless --path <extracted>\yeet-arena --fixed-fps 60 --quit-after 300 res://tests/godot/menu_smoke.tscn -- --no-audio
[smoke] ALL_MENUS_OK
$ cd <extracted>\yeet-arena\backend; python -m pytest
22 passed in 0.65s
```

Every asset (mid/small fonts, all 25 WAVs, `.tres` resources, `.tscn` scenes,
`.import` metadata) survives packaging, and the extracted project boots its
menus with no missing-file errors.

---

## 4. Known notes and honest limitations

1. **No earlier prototype existed to port.** The original HTML/JS/Express
   version of YEET ARENA was not present anywhere on this machine (searched the
   filesystem and the environment). This project is therefore a clean-room
   re-implementation of the described design, not a migration. This is recorded
   in `ASSET_CREDITS.md`.
2. **The Godot binary is not bundled** (≈100 MB, MIT-licensed but third-party).
   `README.md` and `start_game.bat` explain the three ways to point the
   launchers at your own Godot 4.7.x install.
3. **Headless audio at process exit.** With the real audio driver enabled (i.e.
   without `-- --no-audio`), Godot prints an engine-level notice
   (`2 ObjectDB instances were leaked`, `resources still in use`) when the
   process exits while a sound is playing — reproducible even for a bare
   `AudioStreamPlayer` playing one WAV, and independent of this project's code.
   The game mitigates it with an immediate `AudioManager.hard_stop()` on the
   graceful quit path and by looping music via replay instead of engine-level
   loop flags. Automated tests pass `-- --no-audio`, so all verification output
   above is warning-free.
4. **`--fixed-fps` and HTTP.** `HTTPRequest`'s timeout is measured against the
   engine clock, so running the game with a fixed frame rate makes network
   requests time out early. The API test therefore runs in real time; this is
   documented in `run_tests.bat` and `README.md`. Normal gameplay (no override)
   is unaffected.
5. **Single-process rate limiter.** Submission throttling is in-memory, which is
   correct for the single-user local backend shipped here; a multi-process
   deployment would move it to Redis or the reverse proxy. Documented in
   `docs/DESIGN.md`.
6. **No screenshots** are stored in the repository (they would need a rendered
   window); the visual design is described in `docs/DESIGN.md` and is entirely
   procedural.

---

## 5. How to reproduce this verification

All commands are run from the repository root (the launchers `cd` there
themselves; `--app-dir backend` is relative to it).

```bat
:: 1. point the tooling at a Godot 4.7.x executable
setx GODOT_BIN "C:\Godot\Godot_v4.7.2-stable_win64.exe"

:: 2. everything at once (backend tests + 3 headless Godot tests)
run_tests.bat

:: 3. or piece by piece
cd backend && python -m pytest
py tools\generate_audio.py
"%GODOT_BIN%" --headless --path . --import
"%GODOT_BIN%" --headless --path . --fixed-fps 60 --quit-after 300 res://tests/godot/menu_smoke.tscn -- --no-audio
"%GODOT_BIN%" --headless --path . --fixed-fps 60 --quit-after 6000 res://tests/godot/match_test.tscn -- --no-audio
start_backend.bat
"%GODOT_BIN%" --headless --path . --quit-after 6000 res://tests/godot/api_test.tscn -- --no-audio

:: 4. play it
start_game.bat
```

**Verified by:** automated runs on 2026-10-19 — every command above was executed
in this environment and produced the output quoted in section 3.
