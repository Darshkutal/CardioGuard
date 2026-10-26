from datetime import datetime, timedelta, timezone

import numpy as np
import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)
NOW = datetime(2026, 10, 3, 12, 0, tzinfo=timezone.utc)


def r(t, v, hours_ago, v2=None):
    d = {"type": t, "timestamp": (NOW - timedelta(hours=hours_ago)).isoformat(), "value": v}
    if v2 is not None:
        d["value2"] = v2
    return d


def hr_history(days=14, per_day=2, mean=70, sd=3, seed=0):
    rng = np.random.default_rng(seed)
    out = []
    for i in range(days * per_day):
        out.append(r("heartRate", round(float(rng.normal(mean, sd))), 6 + i * (24 / per_day)))
    return out


def post(reading, history=()):
    resp = client.post("/v1/score", json={"reading": reading, "history": list(history)})
    return resp


def test_health():
    assert client.get("/healthz").json()["status"] == "ok"


def test_usual_reading_is_normal():
    res = post(r("heartRate", 71, 0), hr_history(days=20)).json()
    assert res["tier"] == "normal" and res["confidence"] == "high"
    res14 = post(r("heartRate", 71, 0), hr_history(days=14)).json()
    assert res14["confidence"] == "medium"   # 28 readings < 30 needed for 'high'


def test_single_big_jump_is_note_not_urgent():
    res = post(r("heartRate", 100, 0), hr_history()).json()
    assert res["tier"] == "note"
    assert "usual range" in res["reasons"][0]


def test_sustained_big_deviation_is_urgent():
    hist = hr_history() + [r("heartRate", 102, 4)]
    res = post(r("heartRate", 104, 0), hist).json()
    assert res["tier"] == "urgent"
    assert res["channels"][0]["consecutive_deviations"] >= 2
    assert "911" in res["message"]


def test_developing_problem_does_not_become_the_baseline():
    # a whole week of elevated readings must still flag, because recent readings are excluded from the baseline
    hist = hr_history(days=14) + [r("heartRate", 95, 30), r("heartRate", 96, 14)]
    res = post(r("heartRate", 97, 0), hist).json()
    assert res["tier"] in ("note", "urgent")


def test_cold_start_never_urgent_from_deviation_alone():
    hist = [r("heartRate", 70, 48), r("heartRate", 71, 24)]
    res = post(r("heartRate", 150, 0), hist).json()
    assert res["confidence"] == "low"
    assert res["tier"] == "note"
    assert "still learning" in res["reasons"][0]


def test_safety_rule_low_glucose_urgent_even_with_no_history():
    res = post(r("glucose", 45, 0)).json()
    assert res["tier"] == "urgent"
    assert any("very low" in x for x in res["reasons"])


def test_glucose_below_70_is_note():
    assert post(r("glucose", 65, 0)).json()["tier"] == "note"


def test_blood_pressure_scores_both_channels():
    hist = [r("bloodPressure", 120 + (i % 3), 6 + i * 12, v2=78 + (i % 2)) for i in range(30)]
    res = post(r("bloodPressure", 124, 0, v2=80), hist).json()
    assert {c["channel"] for c in res["channels"]} == {"systolic", "diastolic"}
    assert res["tier"] == "normal"
    high = post(r("bloodPressure", 185, 0, v2=95), hist).json()
    assert high["tier"] in ("note", "urgent")


def test_ignores_other_vital_types_and_future_readings():
    hist = hr_history() + [r("glucose", 300, 5), r("heartRate", 200, -5)]  # future reading
    assert post(r("heartRate", 71, 0), hist).json()["tier"] == "normal"


def test_rejects_implausible_and_malformed_input():
    assert post(r("heartRate", 5000, 0)).status_code == 422
    assert post(r("bloodPressure", 120, 0)).status_code == 422             # missing diastolic
    assert post(r("bloodPressure", 90, 0, v2=95)).status_code == 422       # diastolic >= systolic
    assert client.post("/v1/score", json={"nope": 1}).status_code == 422


def test_naive_timestamps_are_treated_as_utc():
    naive = {"type": "heartRate", "timestamp": "2026-10-03T12:00:00", "value": 70}
    assert post(naive).status_code == 200


def test_api_key_enforced_when_configured(monkeypatch):
    monkeypatch.setenv("CARDIOGUARD_API_KEY", "secret")
    body = {"reading": r("heartRate", 70, 0)}
    assert client.post("/v1/score", json=body).status_code == 401
    assert client.post("/v1/score", json=body, headers={"x-api-key": "wrong"}).status_code == 401
    assert client.post("/v1/score", json=body, headers={"x-api-key": "secret"}).status_code == 200
    assert client.get("/healthz").status_code == 200   # health stays open
