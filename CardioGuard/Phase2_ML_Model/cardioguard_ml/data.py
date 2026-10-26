"""Loading MIT-BIH (real) or synthetic beat data. Both return {record: (beat_times_s, symbols)}."""
import os
import numpy as np

# 48 records; 102, 104, 107, 217 are paced (standard practice is to exclude them).
MITDB_RECORDS = [str(r) for r in
                 list(range(100, 110)) + list(range(111, 120)) + [121, 122, 123, 124] +
                 list(range(200, 204)) + [205, 207, 208, 209, 210, 212, 213, 214, 215,
                                          217, 219, 220, 221, 222, 223, 228, 230, 231,
                                          232, 233, 234]]
PACED = {"102", "104", "107", "217"}
BEAT_SYMBOLS = set("NLRBAaJSVrFejnE/fQ?")


def load_mitdb(data_dir="data/mitdb", records=None, exclude_paced=True):
    import wfdb  # imported lazily so synthetic mode works without it
    if not os.path.isdir(data_dir) or not any(f.endswith(".atr") for f in os.listdir(data_dir)):
        wfdb.dl_database("mitdb", data_dir)  # downloads ~100 MB once
    out = {}
    for rec in (records or MITDB_RECORDS):
        if exclude_paced and rec in PACED:
            continue
        ann = wfdb.rdann(os.path.join(data_dir, rec), "atr")
        keep = np.array([s in BEAT_SYMBOLS for s in ann.symbol])
        times = ann.sample[keep] / float(ann.fs)
        syms = np.array(ann.symbol)[keep]
        out[rec] = (times, syms)
    return out


def synthetic_records(n_records=20, minutes=30, seed=0):
    """Fake beat series with sinus rhythm + respiratory modulation + bursts of PVCs.
    Only for testing the pipeline offline. NOT a substitute for real results."""
    rng = np.random.default_rng(seed)
    out = {}
    for i in range(n_records):
        base_rr = 60.0 / rng.uniform(55, 95)
        resp_amp = rng.uniform(0.01, 0.05)
        total = minutes * 60
        episodes = []
        for _ in range(rng.integers(1, 5)):
            s = rng.uniform(600, total - 200)     # keep first 10 min clean-ish (baseline)
            episodes.append((s, s + rng.uniform(40, 150)))
        t, times, syms = 0.0, [], []
        pending_comp = False
        while t < total:
            rr = base_rr * (1 + resp_amp * np.sin(2 * np.pi * t / 4.0)) + rng.normal(0, 0.012)
            in_ep = any(a <= t <= b for a, b in episodes)
            sym = "N"
            if pending_comp:
                rr *= 1.4
                pending_comp = False
            elif in_ep and rng.random() < 0.18:
                rr *= 0.6
                sym = "V"
                pending_comp = True
            t += max(rr, 0.25)
            times.append(t)
            syms.append(sym)
        out[f"syn{i:02d}"] = (np.array(times), np.array(syms))
    return out
