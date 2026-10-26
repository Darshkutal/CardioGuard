from datetime import datetime, timezone
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator, model_validator


class VitalType(str, Enum):
    heartRate = "heartRate"
    bloodPressure = "bloodPressure"
    glucose = "glucose"
    oxygen = "oxygen"


# Same typo-guard bounds as the iOS app (VitalType.plausibleRange). NOT medical thresholds.
PLAUSIBLE = {
    VitalType.heartRate: (20, 250),
    VitalType.bloodPressure: (50, 260),
    VitalType.glucose: (20, 800),
    VitalType.oxygen: (50, 100),
}
PLAUSIBLE_DIASTOLIC = (30, 180)


class Reading(BaseModel):
    type: VitalType
    timestamp: datetime
    value: float
    value2: Optional[float] = None  # diastolic, for bloodPressure only

    @field_validator("timestamp")
    @classmethod
    def _to_utc(cls, v: datetime) -> datetime:
        return v.replace(tzinfo=timezone.utc) if v.tzinfo is None else v.astimezone(timezone.utc)

    @model_validator(mode="after")
    def _check(self) -> "Reading":
        lo, hi = PLAUSIBLE[self.type]
        if not (lo <= self.value <= hi):
            raise ValueError(f"{self.type.value} value {self.value} outside plausible range {lo}-{hi}")
        if self.type == VitalType.bloodPressure:
            if self.value2 is None:
                raise ValueError("bloodPressure requires value2 (diastolic)")
            dlo, dhi = PLAUSIBLE_DIASTOLIC
            if not (dlo <= self.value2 <= dhi) or self.value2 >= self.value:
                raise ValueError("diastolic out of range or not lower than systolic")
        return self


class ScoreRequest(BaseModel):
    reading: Reading
    # The user's past readings. The server is stateless: nothing is stored.
    history: List[Reading] = Field(default_factory=list, max_length=2000)


class Tier(str, Enum):
    normal = "normal"
    note = "note"        # worth noting, in-app only
    urgent = "urgent"    # eligible for escalation prompts (Phase 4)


class Confidence(str, Enum):
    low = "low"          # still calibrating; compared mostly against a generic prior
    medium = "medium"
    high = "high"


class ChannelResult(BaseModel):
    channel: str
    value: float
    z: float
    center: float
    spread: float
    usual_low: float
    usual_high: float
    n_baseline: int
    confidence: Confidence
    tier: Tier
    direction: str                 # "above" | "below" | "none"
    consecutive_deviations: int    # including this reading


class ScoreResponse(BaseModel):
    tier: Tier
    score: float                   # 0..1, larger = more unusual for THIS user
    confidence: Confidence
    message: str
    reasons: List[str]
    channels: List[ChannelResult]
    model_version: str
    disclaimer: str
