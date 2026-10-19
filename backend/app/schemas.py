"""Pydantic request/response models - the server-side mirror of the client rules."""

from __future__ import annotations

from pydantic import BaseModel, Field, field_validator

from .config import MAX_DURATION, MAX_SCORE, VALID_FIGHTERS, VALID_MODES


class ScoreIn(BaseModel):
    player_name: str = Field(min_length=2, max_length=16)
    fighter: str
    opponent: str = Field(default="", max_length=24)
    mode: str = "arcade"
    score: int = Field(ge=0, le=MAX_SCORE)
    kos: int = Field(default=0, ge=0, le=99)
    max_combo: int = Field(default=0, ge=0, le=999)
    duration: float = Field(default=0.0, ge=0.0, le=MAX_DURATION)
    victory: bool = False
    client_match_id: str = Field(default="", max_length=64)
    client_version: str = Field(default="1.0.0", max_length=16)

    @field_validator("player_name")
    @classmethod
    def _clean_name(cls, value: str) -> str:
        name = value.strip()
        if len(name) < 2:
            raise ValueError("player_name must be 2-16 visible characters")
        if any(ord(ch) < 32 or ord(ch) == 127 for ch in name):
            raise ValueError("player_name contains control characters")
        return name

    @field_validator("victory", mode="before")
    @classmethod
    def _strict_bool(cls, value: object) -> object:
        if not isinstance(value, bool):
            raise ValueError("victory must be a boolean")
        return value

    @field_validator("fighter")
    @classmethod
    def _check_fighter(cls, value: str) -> str:
        fighter = value.strip().lower()
        if fighter not in VALID_FIGHTERS:
            raise ValueError(f"unknown fighter: {value}")
        return fighter

    @field_validator("opponent")
    @classmethod
    def _check_opponent(cls, value: str) -> str:
        opponent = value.strip().lower()
        if opponent and opponent not in VALID_FIGHTERS:
            raise ValueError(f"unknown opponent: {value}")
        return opponent

    @field_validator("mode")
    @classmethod
    def _check_mode(cls, value: str) -> str:
        mode = value.strip().lower()
        if mode not in VALID_MODES:
            raise ValueError(f"unknown mode: {value}")
        return mode

    @field_validator("client_match_id")
    @classmethod
    def _check_match_id(cls, value: str) -> str:
        return value.strip()

    model_config = {
        "json_schema_extra": {
            "example": {
                "player_name": "NOVA",
                "fighter": "volt",
                "opponent": "brick",
                "mode": "arcade",
                "score": 4820,
                "kos": 2,
                "max_combo": 7,
                "duration": 58.4,
                "victory": True,
                "client_match_id": "m-1a2b3c",
                "client_version": "1.0.0",
            }
        }
    }
