import numpy as np
from cardioguard_ml.data import synthetic_records
from cardioguard_ml.features import window_features, FEATURES
from cardioguard_ml.model import leave_one_record_out, summarize, sustained_alerts


def _records():
    return {k: window_features(t, s) for k, (t, s) in synthetic_records(12, 30, seed=1).items()}


def test_features_shape_and_labels():
    rec = _records()
    df = next(iter(rec.values()))
    assert set(FEATURES) <= set(df.columns)
    assert df[FEATURES].notna().all().all()
    assert set(df["label"].unique()) <= {0, 1}
    assert len(df) >= 55   # ~60 windows for 30 min


def test_labels_do_not_leak_into_features():
    # regular rhythm with one relabeled beat must not change features
    t = np.arange(0, 60, 0.8)
    a = window_features(t, np.array(["N"] * len(t)))
    b = window_features(t, np.array(["N"] * 5 + ["V"] * 2 + ["N"] * (len(t) - 7)))
    assert np.allclose(a[FEATURES].values, b[FEATURES].values)
    assert a["label"].sum() == 0 and b["label"].sum() >= 1


def test_personalized_beats_fixed_range_on_synthetic():
    res = leave_one_record_out(_records())
    pooled, per = summarize(res)
    assert pooled.loc["personalized_if", "AUROC"] > 0.9
    assert pooled.loc["personalized_if", "AUROC"] > pooled.loc["fixed_range", "AUROC"]
    assert len(per) > 0


def test_sustained_alert_metrics_run():
    res = leave_one_record_out(_records())
    thr = res.loc[res.label == 0, "personalized_if"].quantile(0.99)
    m = sustained_alerts(res, "personalized_if", thr, k=2)
    assert m["episodes"] > 0 and 0 <= m["episode_recall"] <= 1
