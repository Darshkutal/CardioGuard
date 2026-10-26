"""Personalized baseline scoring for manually logged vitals.

Method (the 'simpler / more buildable' option in the spec):
  * Per user and per measure, a robust baseline (median + MAD) from the user's own history.
  * Cold start: shrink toward a generic population prior until enough personal data exists.
  * A reading is judged by its robust z-score against that baseline, and by whether the
    deviation is SUSTAINED across consecutive readings, not by a single point.
  * Two tiers: 'note' (in-app) and 'urgent' (needs sustained, high-severity, non-calibrating).
  * Separate absolute safety rules (config below) apply regardless of personal baseline.

The thresholds are engineering defaults chosen for low false-alarm rates, NOT clinically validated.
"""
from __future__ import annotations

import math
from datetime import datetime, timedelta
from statistics import median
from typing import Dict, List, Optional, Tuple

from .schemas import (ChannelResult, Confidence, Reading, ScoreRequest, ScoreResponse, Tier, VitalType)

MODEL_VERSION = "baseline-mad-0.1"
DISCLAIMER = ("CardioGuard is a tracking tool, not a medical device. It does not diagnose conditions "
              "or replace medical care. In an emergency, call 911.")

# ---- tunables -------------------------------------------------------------------------------
# generic population prior (mean, sd) and the smallest spread we allow (so a very steady user
# is not alarmed by a tiny wobble)
PRIORS: Dict[str, Tuple[float, float]] = {
    "heartRate": (72, 12), "systolic": (120, 14), "diastolic": (78, 9),
    "glucose": (105, 25), "oxygen": (97, 1.5),
}
MIN_SPREAD: Dict[str, float] = {
    "heartRate": 3, "systolic": 4, "diastolic": 3, "glucose": 8, "oxygen": 0.6,
}
UNITS = {"heartRate": "bpm", "systolic": "mmHg", "diastolic": "mmHg", "glucose": "mg/dL", "oxygen": "%"}
NAMES = {"heartRate": "heart rate", "systolic": "systolic blood pressure",
         "diastolic": "diastolic blood pressure", "glucose": "blood glucose", "oxygen": "oxygen level"}

SHRINK_K = 10            # prior is worth this many personal readings
NOTE_SINGLE_Z = 3.0      # one reading this far from your normal -> note
NOTE_SUSTAINED_Z = 2.0   # ... or this far, 3 readings in a row, same direction -> note
NOTE_SUSTAINED_N = 3
URGENT_Z = 4.0           # this far, 2 readings in a row, same direction, not calibrating -> urgent
URGENT_N = 2
RECENT_WINDOW = timedelta(hours=72)   # readings further apart than this don't count as "in a row"
MIN_BASE_FOR_MEDIUM = 10
MIN_DAYS_FOR_MEDIUM = 3
MIN_BASE_FOR_HIGH = 30
MIN_DAYS_FOR_HIGH = 7

# Absolute safety rules, independent of the personal baseline. SOURCES: ADA Standards of Care
# (glucose <70 level 1, <54 level 2 hypoglycemia); AHA (home BP >=180 systolic and/or >=120
# diastolic is the hypertensive-crisis range; recheck); oxygen <90 is a commonly used concern level.
# >>> Have a clinician review these before any real-world use. <<<
SAFETY_RULES = [
    # (channel, op, threshold, tier, text)
    ("glucose", "<", 54, Tier.urgent, "Your glucose is very low (below 54 mg/dL)."),
    ("glucose", "<", 70, Tier.note, "Your glucose is low (below 70 mg/dL)."),
    ("systolic", ">=", 180, Tier.note, "Your systolic pressure is 180 or higher. Rest and re-check in a few minutes."),
    ("diastolic", ">=", 120, Tier.note, "Your diastolic pressure is 120 or higher. Rest and re-check in a few minutes."),
    ("oxygen", "<", 90, Tier.note, "Your oxygen reading is below 90%. Re-check with the sensor properly placed."),
]
_ORDER = {Tier.normal: 0, Tier.note: 1, Tier.urgent: 2}


def _max_tier(a: Tier, b: Tier) -> Tier:
    return a if _ORDER[a] >= _ORDER[b] else b


# ---- helpers ---------------------------------------------------------------------------------
def channels_of(r: Reading) -> Dict[str, float]:
    if r.type == VitalType.bloodPressure:
        return {"systolic": r.value, "diastolic": float(r.value2)}
    return {r.type.value: r.value}


def _series(history: List[Reading], channel: str, before: datetime) -> List[Tuple[datetime, float]]:
    out = []
    for h in history:
        if h.timestamp >= before:
            continue
        v = channels_of(h).get(channel)
        if v is not None:
            out.append((h.timestamp, v))
    out.sort(key=lambda p: p[0])
    return out


def _baseline(channel: str, base: List[Tuple[datetime, float]]):
    prior_mean, prior_sd = PRIORS[channel]
    n = len(base)
    if n == 0:
        return prior_mean, prior_sd, 0, 0.0
    vals = [v for _, v in base]
    med = median(vals)
    if n >= 3:
        mad = median(abs(v - med) for v in vals)
        spread_est = max(1.4826 * mad, MIN_SPREAD[channel])
    else:
        spread_est = prior_sd
    w = n / (n + SHRINK_K)
    center = w * med + (1 - w) * prior_mean
    spread = max(w * spread_est + (1 - w) * prior_sd, MIN_SPREAD[channel])
    span_days = (base[-1][0] - base[0][0]).total_seconds() / 86400.0
    return center, spread, n, span_days


def _confidence(n: int, span_days: float) -> Confidence:
    if n >= MIN_BASE_FOR_HIGH and span_days >= MIN_DAYS_FOR_HIGH:
        return Confidence.high
    if n >= MIN_BASE_FOR_MEDIUM and span_days >= MIN_DAYS_FOR_MEDIUM:
        return Confidence.medium
    return Confidence.low


def score_channel(channel: str, new_value: float, new_ts: datetime,
                  history: List[Reading]) -> ChannelResult:
    series = _series(history, channel, new_ts)

    # The most recent readings are the "recent window"; they must NOT define the baseline,
    # otherwise a developing problem would quietly become the user's 'normal'.
    recent = [p for p in series[-(NOTE_SUSTAINED_N - 1):] if new_ts - p[0] <= RECENT_WINDOW]
    base = series[: len(series) - len(recent)] if recent else series
    # keep recents contiguous with the new reading
    center, spread, n, span_days = _baseline(channel, base)
    conf = _confidence(n, span_days)

    z_new = (new_value - center) / spread
    z_recent = [(v - center) / spread for _, v in recent]
    sign = 1 if z_new >= 0 else -1

    def run_length(threshold: float) -> int:
        run = 1 if abs(z_new) >= threshold else 0
        if run == 0:
            return 0
        for z in reversed(z_recent):
            if abs(z) >= threshold and (z >= 0) == (sign >= 0):
                run += 1
            else:
                break
        return run

    tier = Tier.normal
    if abs(z_new) >= NOTE_SINGLE_Z or run_length(NOTE_SUSTAINED_Z) >= NOTE_SUSTAINED_N:
        tier = Tier.note
    if run_length(URGENT_Z) >= URGENT_N and conf != Confidence.low:
        tier = Tier.urgent
    consecutive = max(run_length(NOTE_SUSTAINED_Z), run_length(URGENT_Z))

    return ChannelResult(
        channel=channel, value=new_value, z=round(z_new, 2),
        center=round(center, 1), spread=round(spread, 2),
        usual_low=round(center - 2 * spread, 1), usual_high=round(center + 2 * spread, 1),
        n_baseline=n, confidence=conf, tier=tier,
        direction="above" if z_new >= NOTE_SUSTAINED_Z else ("below" if z_new <= -NOTE_SUSTAINED_Z else "none"),
        consecutive_deviations=consecutive,
    )


def _fmt(x: float) -> str:
    return str(int(round(x))) if abs(x - round(x)) < 1e-9 or abs(x) >= 20 else f"{x:.1f}"


def _channel_reason(c: ChannelResult) -> str:
    name, unit = NAMES[c.channel], UNITS[c.channel]
    where = "above" if c.z > 0 else "below"
    txt = (f"Your {name} of {_fmt(c.value)} {unit} is well {where} your usual range "
           f"(about {_fmt(c.usual_low)}-{_fmt(c.usual_high)} {unit}).")
    if c.consecutive_deviations >= 2:
        txt += f" This has now happened in {c.consecutive_deviations} readings in a row."
    if c.confidence == Confidence.low:
        txt += " CardioGuard is still learning your normal, so this is a rough comparison."
    return txt


def _safety(channel: str, value: float):
    for ch, op, thr, tier, text in SAFETY_RULES:
        if ch != channel:
            continue
        hit = value < thr if op == "<" else value >= thr
        if hit:
            return tier, text
    return None


def score(req: ScoreRequest) -> ScoreResponse:
    r = req.reading
    results: List[ChannelResult] = []
    reasons: List[str] = []
    tier = Tier.normal

    for channel, value in channels_of(r).items():
        res = score_channel(channel, value, r.timestamp, req.history)

        # low confidence: personalised judgement is capped at 'note'
        if res.confidence == Confidence.low and res.tier == Tier.urgent:
            res.tier = Tier.note
        results.append(res)
        if res.tier != Tier.normal:
            reasons.append(_channel_reason(res))
        tier = _max_tier(tier, res.tier)

        s = _safety(channel, value)
        if s:
            stier, stext = s
            reasons.append(stext)
            tier = _max_tier(tier, stier)
            if _ORDER[stier] > _ORDER[res.tier]:
                res.tier = stier

    worst = max(results, key=lambda c: abs(c.z))
    conf_order = [Confidence.low, Confidence.medium, Confidence.high]
    confidence = min((c.confidence for c in results), key=conf_order.index)
    sc = min(1.0, abs(worst.z) / 6.0)
    if tier == Tier.urgent:
        sc = max(sc, 0.8)

    if tier == Tier.normal:
        message = "This reading looks like your usual range."
    else:
        head = ("This is very different from your usual pattern." if tier == Tier.urgent
                else "This reading is different from your usual pattern.")
        tail = (" If you feel unwell (chest pain, trouble breathing, fainting), call 911 or your local "
                "emergency number. Otherwise re-check and contact your care team." if tier == Tier.urgent
                else " Consider re-checking in a few minutes. If you have symptoms or it keeps happening, "
                     "contact your care team.")
        message = head + tail

    return ScoreResponse(tier=tier, score=round(sc, 3), confidence=confidence, message=message,
                         reasons=reasons, channels=results, model_version=MODEL_VERSION,
                         disclaimer=DISCLAIMER)
