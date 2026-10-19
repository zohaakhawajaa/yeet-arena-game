# YEET ARENA — design notes

The tuned numbers behind the game. Everything here is implemented exactly as
described; file references point at the source of truth.

---

## 1. Pitch

A 2D arcade fighter where the arena itself is an opponent. Two fighters, a
60-second clock and a cage that closes three times. Matches are short, loud and
decided by whoever keeps their nerve when the walls arrive.

**Pillars**

1. *Readable chaos* — big, exaggerated motion so every hit is legible.
2. *One weird button* — YEET: slow, enormous, edge-latched. High risk, high reward.
3. *Pressure from the world* — the shrinking safe zone forces interaction.
4. *Honest AI* — the CPU uses the same inputs and intents as the player.

---

## 2. Core loop

```
title → fighter select → arena select → 3-2-1 countdown → 60 s match
      → shrink ×3 → K.O. or time-up → results → submit score → leaderboard
```

Demo ("attract") matches run the same pipeline with `mode = "demo"` and are
never submitted to the leaderboard.

---

## 3. Movement & combat rules

| Rule | Value | Source |
| ---- | ----- | ------ |
| Gravity / terminal velocity | 1850 / 1450 px·s⁻¹ | `combat/fighter.gd` |
| Input buffer | 0.16 s | `fighter.gd` |
| Combo window | 1.45 s | `fighter.gd` |
| Damage scaling | `max(0.45, 1 − 0.07·(combo−1))` | `fighter.gd` |
| Controllable states | idle, run, jump, fall, guard | `fighter.gd` |
| Guard | hold `S`, blocks most damage, knockback still applies | `fighter.gd` |
| Parry (GLITCH) | tap guard on late frames → hard counter | `fighter.gd` |
| Super armour (BRICK) | light/heavy hits do not interrupt | `fighter.gd` |
| YEET | slow, huge, **edge-latched**: release before re-arming | `fighter.gd`, `player_controller.gd` |
| Hitstop + shake | scaled per hit weight | `effects/fx.gd` |

Both the player and the AI produce the same **intent dictionaries** every frame,
which the fighter consumes. There is no special-cased AI code path inside the
fighter — the CPU is physically honest.

---

## 4. Shrinking cage

Implemented in `core/match.gd` (`SHRINK_EVENTS`), visualised by
`arenas/arena.gd`:

| Time (match clock) | Phase | Inset (horizontal) | Notes |
| ------------------ | ----- | ------------------ | ----- |
| 15 s warn → 18 s | contracting | 72 px | "ARENA CONTRACTING" |
| 35 s warn → 38 s | contracting | 158 px | |
| 47 s warn → 50 s | **final** | 236 px | "FINAL PHASE" |

* Vertical inset = horizontal inset × 0.55 (the arena is 16:9, so the cage closes
  evenly in world space).
* Hard bounds: `Rect2(64, 70, 1152, 570)`; floor at `y = 640`.
* Standing outside the safe rect deals chip damage every 0.5 s
  (`3.0 + phase` per tick ≈ 8–12 dps), enough to punish camping, slow enough to
  cross back in.
* Transitions are telegraphed for 3 s with a pulsing border and an audio cue.

---

## 5. Arenas

| Arena | Hazard | Behaviour |
| ----- | ------ | --------- |
| `neon_pit` | none | Pure fighting; the shrinking cage is the only pressure. |
| `reactor_core` | vent | Floor vents telegraph, then erupt for burst damage + knockback. |
| `void_circuit` | orbs | Drifting orbs shove fighters around; no direct damage. |

Visual identity is data-driven (`resources/arenas/*.tres`): palette, skyline
seed, grid colours and hazard type.

---

## 6. Roster

| Fighter | Archetype | Ability |
| ------- | --------- | ------- |
| VOLT | rushdown | Overdrive Rush — fast approach, low damage per hit |
| BRICK | grappler/tank | Super Armour — ignores light/heavy interruption |
| PHANTOM | evasive | Phase Blink — repositional dash with i-frames |
| CHAOS | pressure | Entropy Surge — unpredictable multi-hit |
| TITAN | heavyweight | Gravity Slam — huge damage, slow |
| GLITCH | counter | Perfect Parry — hard counter on a late guard |

Each fighter is a `FighterStats` resource (`resources/fighters/*.tres`) with
speed, power, toughness, mobility and technique scores that the select screen
displays as bars.

---

## 7. AI

`ai/ai_controller.gd` is a state machine (`AIState`) driven by difficulty
profiles:

| Difficulty | Reaction | Block chance | Special chance | Aggression |
| ---------- | -------- | ------------ | -------------- | ---------- |
| easy | 0.45 s | 18% | 15% | 0.40 |
| normal | 0.25 s | 42% | 40% | 0.65 |
| hard | 0.12 s | 70% | 62% | 0.90 |

* Reaction delays are jittered (±30%), so the CPU never feels frame-perfect.
* Per-fighter personalities shift spacing, poke frequency and YEET willingness.
* The AI respects cooldowns and attack ranges, and reacts to telegraphs it can
  "see" — no health-based cheating, no impossible inputs.

---

## 8. Scoring

`core/match.gd#_compute_score()`:

```
score = damage_dealt × 10
      + max_combo × 60
      + kos × 500          (1 if the match ended in a K.O. you won, else 0)
      + time_left × 15
      + hp_left × 5
      + (victory ? 1500 : 0)
```

`demo` runs are scored identically for the results screen but never submitted.

---

## 9. Presentation

* **Fixed camera** on a 1280×720 `canvas_items` viewport (`keep` stretch) — the
  arena *is* the screen; screen shake is applied to the `World` node.
* **Fighter art** is an articulated skeleton (torso, head, limbs) drawn with
  polygons each frame, posed from the state machine — animation *is* the art.
* **Audio** is generated (`tools/generate_audio.py`) and routed through `Music`
  and `SFX` buses driven by the settings screen.
* **Accessibility** — reduced-effects toggle (fewer particles, less shake),
  separate master/music/SFX volumes, keyboard-only menu navigation.

---

## 10. Backend design

* FastAPI + stdlib `sqlite3` (WAL). No ORM: the schema is one readable SQL string
  (`backend/app/db.py`).
* `client_match_id` is uniquely indexed → retries return `409`, never duplicates.
* Ranks are scoped per mode so `demo` runs cannot outrank real runs.
* Rate limiting: 30 submissions per minute per IP → `429`.
* Validation is mirrored on both sides: the client refuses to send what the
  server would reject, and the server never trusts the client.
* The game degrades gracefully: if the backend is down, matches still play and
  the results screen offers "TRY AGAIN".
