"""Detectors + leave-one-record-out evaluation.

Four detectors are compared on each held-out "user" (record):
  fixed_range     generic 60-100 bpm rule (the thing the app is supposed to beat)
  personal_z      only the user's own baseline (median/MAD z-scores), no population data
  population_if   Isolation Forest on absolute features, trained on OTHER records' normal windows
  personalized_if Isolation Forest on baseline-relative features, trained on other records' normal
                  windows PLUS this user's own (unlabeled) baseline windows  <- proposed model
Baseline = first N windows of each record (calibration period). Only later windows are scored.
"""
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import roc_auc_score, average_precision_score, roc_curve

from .features import FEATURES

DETECTORS = ["fixed_range", "personal_z", "population_if", "personalized_if"]


def baseline_stats(df, n_base):
    base = df.iloc[:n_base][FEATURES]
    med = base.median()
    mad = (base - med).abs().median()
    scale = 1.4826 * mad + 1e-3 + 0.05 * med.abs()   # floor so near-constant features don't explode
    return med, scale


def relativize(df, stats):
    med, scale = stats
    z = (df[FEATURES] - med) / scale
    return np.sign(z) * np.log1p(np.abs(z))          # compress heavy tails, keep sign


def _iforest(X, seed):
    scaler = StandardScaler().fit(X)
    m = IsolationForest(n_estimators=300, random_state=seed).fit(scaler.transform(X))
    return lambda Z: -m.score_samples(scaler.transform(Z))   # higher = more anomalous


def fit_population_model(records, n_base=20, seed=0):
    """Fit on all given records' normal windows (used for the exported/deployed model)."""
    Xs = [relativize(df, baseline_stats(df, n_base))[df["label"] == 0]
          for df in records.values() if len(df) > n_base]
    return _iforest(pd.concat(Xs).values, seed)


def leave_one_record_out(records, n_base=20, seed=0):
    """records: {name: window_df}. Returns long DataFrame of scores for post-baseline windows."""
    records = {k: v for k, v in records.items() if len(v) > n_base + 5}
    rel = {k: relativize(v, baseline_stats(v, n_base)) for k, v in records.items()}
    out = []
    for held, df in records.items():
        others = [k for k in records if k != held]
        test = df.iloc[n_base:]
        Xrel_test = rel[held].iloc[n_base:]
        own_base = rel[held].iloc[:n_base]

        # 1. fixed range
        hr = test["mean_hr"].values
        s_fixed = np.maximum.reduce([60 - hr, hr - 100, np.zeros_like(hr)])

        # 2. personal z (own baseline only)
        s_z = np.abs(Xrel_test.values).max(axis=1)

        # 3. population IF, absolute features
        Xabs = pd.concat([records[k][FEATURES][records[k]["label"] == 0] for k in others])
        s_pop = _iforest(Xabs.values, seed)(test[FEATURES].values)

        # 4. personalized IF (population normals in relative space + own baseline windows)
        Xrel = pd.concat([rel[k][records[k]["label"] == 0] for k in others] + [own_base])
        s_pers = _iforest(Xrel.values, seed)(Xrel_test.values)

        res = pd.DataFrame({"record": held, "start": test["start"].values,
                            "label": test["label"].values,
                            "fixed_range": s_fixed, "personal_z": s_z,
                            "population_if": s_pop, "personalized_if": s_pers})
        out.append(res)
    return pd.concat(out, ignore_index=True)


def _recall_at_fpr(y, s, fpr_target):
    fpr, tpr, _ = roc_curve(y, s)
    return float(np.interp(fpr_target, fpr, tpr))


def summarize(results):
    """Pooled + per-record metrics."""
    pooled = []
    for d in DETECTORS:
        y, s = results["label"].values, results[d].values
        pooled.append({"detector": d,
                       "AUROC": roc_auc_score(y, s),
                       "AvgPrecision": average_precision_score(y, s),
                       "Recall@1%FPR": _recall_at_fpr(y, s, 0.01),
                       "Recall@5%FPR": _recall_at_fpr(y, s, 0.05)})
    per = []
    for rec, g in results.groupby("record"):
        if g["label"].nunique() < 2:
            continue
        per.append({"record": rec, "n_windows": len(g), "anom_rate": g["label"].mean(),
                    **{d: roc_auc_score(g["label"], g[d]) for d in DETECTORS}})
    return pd.DataFrame(pooled).set_index("detector"), pd.DataFrame(per).set_index("record")


def sustained_alerts(results, col, threshold, k=2):
    """Two-tier logic: 'urgent' only when >= k consecutive windows exceed threshold.
    Returns false alerts per hour (on normal-only stretches) and fraction of anomaly episodes caught."""
    fa, hours, caught, episodes = 0, 0.0, 0, 0
    for _, g in results.sort_values("start").groupby("record"):
        above = (g[col].values > threshold).astype(int)
        y = g["label"].values
        run = np.convolve(above, np.ones(k, dtype=int), mode="full")[:len(above)]
        urgent = run >= k
        hours += len(g) * 30 / 3600
        # merge consecutive urgent windows into alert events
        starts = np.flatnonzero(urgent & ~np.r_[False, urgent[:-1]])
        for s in starts:
            e = s
            while e + 1 < len(urgent) and urgent[e + 1]:
                e += 1
            if y[max(0, s - k + 1): e + 1].sum() == 0:
                fa += 1
        # anomaly episodes (runs of label==1)
        lstarts = np.flatnonzero((y == 1) & ~np.r_[False, (y == 1)[:-1]])
        for s in lstarts:
            e = s
            while e + 1 < len(y) and y[e + 1] == 1:
                e += 1
            episodes += 1
            caught += int(urgent[s: e + k].any())
    return {"false_alerts_per_hour": fa / max(hours, 1e-9),
            "episodes": episodes, "episode_recall": caught / max(episodes, 1)}
