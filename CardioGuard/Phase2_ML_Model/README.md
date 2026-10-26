# CardioGuard Phase 2: offline anomaly model

Run on your Mac (needs internet to reach physionet.org, ~100 MB download the first time):

```bash
cd CardioGuard/ml
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pytest -q                                  # 4 tests, uses synthetic data, ~15 s
jupyter notebook phase2_mitbih_anomaly.ipynb   # Run All; downloads MIT-BIH into data/mitdb
```

Offline pipeline check: `CG_SOURCE=synthetic jupyter notebook ...` (fake data, not results).

## What it does
- Uses beat timing only (RR intervals), the signal a watch provides. Annotations are used for labels only (a test checks there is no leakage).
- 30 s windows, 8 features (mean HR, SDNN, RMSSD, pNN50, max jump, min/max RR ratio, premature-beat fraction).
- Compares 4 detectors with leave-one-record-out: fixed 60-100 bpm rule, own-baseline z-score, population Isolation Forest, and the proposed personalized Isolation Forest (baseline-relative features, population normals + the user's own calibration windows).
- Two-tier alerting: urgent = 2+ consecutive windows over threshold; reports false alerts/hour and episode recall.

## Status
Verified on synthetic data only: PhysioNet was unreachable from the build environment. Synthetic results are too easy to mean anything. Real MIT-BIH numbers come from your run; paste them back and we can tune features/thresholds. Add a separate held-out split before quoting numbers in the CAC writeup.
