"""Turn a beat-time series into fixed-length window features + labels.

IMPORTANT: features use ONLY beat timing (RR intervals), the same signal the phone gets from a
watch. Labels use the cardiologist beat annotations and are NEVER used as features.
"""
import numpy as np
import pandas as pd

FEATURES = ["mean_hr", "sdnn", "rmssd", "pnn50", "max_jump",
            "min_ratio", "max_ratio", "premature_frac"]

# Annotation symbols that mark rhythm-relevant ectopy (PVC, PAC, aberrant, junctional, escape...).
# Bundle-branch blocks (L, R) and paced beats are morphology/pacing, not timing anomalies -> excluded.
ECTOPIC = ("A", "a", "J", "S", "V", "F", "e", "j", "E", "r")


def window_features(beat_times, symbols, window_s=30.0, min_beats=10,
                    min_ectopic=2, ectopic=ECTOPIC) -> pd.DataFrame:
    """Non-overlapping windows. Label = 1 if the window holds >= min_ectopic ectopic beats."""
    t = np.asarray(beat_times, dtype=float)
    sym = np.asarray(symbols)
    is_ect = np.isin(sym, list(ectopic))
    rows = []
    for w0 in np.arange(t[0], t[-1] - window_s + 1e-9, window_s):
        m = (t >= w0) & (t < w0 + window_s)
        if m.sum() < min_beats:
            continue
        rr = np.diff(t[m]) * 1000.0          # ms
        d = np.diff(rr)
        med = np.median(rr)
        rows.append({
            "start": w0,
            "mean_hr": 60000.0 / rr.mean(),
            "sdnn": rr.std(ddof=1),
            "rmssd": np.sqrt(np.mean(d ** 2)),
            "pnn50": np.mean(np.abs(d) > 50),
            "max_jump": np.max(np.abs(d)) / med,
            "min_ratio": rr.min() / med,
            "max_ratio": rr.max() / med,
            "premature_frac": np.mean(rr < 0.8 * med),
            "n_ectopic": int(is_ect[m].sum()),
        })
    df = pd.DataFrame(rows)
    if len(df):
        df["label"] = (df["n_ectopic"] >= min_ectopic).astype(int)
    return df
