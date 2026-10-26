"""Synthetic sanity check of the scorer's alert rates. NOT clinical validation.

Simulates users with their own resting heart rate / variability (2 readings/day, 30 days), then
  (a) counts false alerts on healthy users, and
  (b) injects a sustained shift on day 20 and checks how fast it is flagged.
Noise is Gaussian plus occasional single-reading spikes (talking, stairs) to test false-alarm control.
Run from backend/:  python -m scripts.simulate
"""
from datetime import datetime, timedelta, timezone

import numpy as np

from app.schemas import Reading, ScoreRequest
from app.scoring import score

START = datetime(2026, 9, 1, 8, 0, tzinfo=timezone.utc)


def make_user(rng, days=30, shift_day=None, shift=0.0):
    mean, sd = rng.uniform(55, 90), rng.uniform(2.5, 7)
    out = []
    for i in range(days * 2):
        t = START + timedelta(hours=12 * i)
        v = rng.normal(mean, sd)
        if rng.random() < 0.03:
            v += rng.uniform(10, 25)              # benign single spike
        if shift_day is not None and t >= START + timedelta(days=shift_day):
            v += shift
        out.append(Reading(type="heartRate", timestamp=t, value=float(np.clip(round(v), 30, 220))))
    return out


def run(n_users=300, seed=0):
    rng = np.random.default_rng(seed)
    # (a) healthy users: replay days 8-30 (after a week of calibration)
    notes = urgent = readings = 0
    for _ in range(n_users):
        data = make_user(rng)
        for i in range(14, len(data)):
            res = score(ScoreRequest(reading=data[i], history=data[:i]))
            readings += 1
            notes += res.tier.value == "note"
            urgent += res.tier.value == "urgent"
    print(f"HEALTHY  users={n_users} readings={readings}")
    print(f"  note   : {notes / readings:.2%} of readings  (~{notes / n_users:.1f} per user-month)")
    print(f"  urgent : {urgent / readings:.3%} of readings (~{urgent / n_users:.2f} per user-month)")

    # (b) sustained shift of +15 bpm starting day 20
    for shift in (10, 15, 25):
        first_note, first_urgent = [], []
        for _ in range(n_users):
            data = make_user(rng, shift_day=20, shift=shift)
            fn = fu = None
            for i in range(40, len(data)):          # day 20 onward
                tier = score(ScoreRequest(reading=data[i], history=data[:i])).tier.value
                k = i - 40
                if tier != "normal" and fn is None:
                    fn = k
                if tier == "urgent" and fu is None:
                    fu = k
            first_note.append(fn)
            first_urgent.append(fu)
        def summary(xs):
            hit = [x for x in xs if x is not None]
            med = f"{np.median(hit) / 2:.1f} days" if hit else "n/a"
            return f"caught {len(hit) / len(xs):.0%}, median time {med}"
        print(f"SHIFT +{shift} bpm  note: {summary(first_note)} | urgent: {summary(first_urgent)}")


if __name__ == "__main__":
    run()
