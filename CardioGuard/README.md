# CardioGuard

An iPhone app that learns what is normal for each person with a heart condition or diabetes and warns them, in plain language, when their readings change in a way that matters. Built for the 2026 Congressional App Challenge.

CardioGuard is a tracking tool, not a medical device. It does not diagnose conditions and does not replace medical care. In an emergency, call 911.

| Folder | What it is | How to run |
|---|---|---|
| `Phase1_iOS_Tracker/` | SwiftUI app: vitals and symptom logging, charts, history, CSV export for doctor visits | Open in Xcode (iOS 17+) |
| `Phase2_ML_Model/` | Offline rhythm-anomaly model evaluated on MIT-BIH, plus a Colab notebook | Google Colab, or Terminal (see its README) |
| `Phase3_Backend_API/` | FastAPI scoring service (personal baseline, two-tier alerts) and Swift client | `uvicorn app.main:app` (see its README) |
| `CAC_Submission/` | Simulated demo-patient data used for the demo video | Used by the app's demo mode |

## How the AI works
Each user gets their own baseline from the median of their readings, so one-off spikes don't skew it. New readings are scored against it. A single outlier only produces a note, and an urgent alert needs a sustained deviation and enough data to trust. New users start from a population prior that fades as their own data grows.

## AI assistance disclosure
Parts of this project were written with the help of Claude, an AI assistant from Anthropic. The author reviewed the code and made the design decisions.

## Data and privacy
The app stores data only on the device. The scoring service is stateless and stores nothing. Demo data is simulated; no real patient data is in this repository.

## AI assistance disclosure
[Edit so every word is true.] I used Claude (Anthropic's AI assistant) as a coding and learning tool on parts of this project, including [first drafts of some SwiftUI screens, the Python scoring service and the evaluation notebook]. I [chose the problem and approach, tested the app, ran and checked the model on MIT-BIH data, and made the final decisions].

## Notes
- `CAC_Submission/DemoScenario.swift` holds simulated demo data only. No real patient data is in this repository.
- The scoring engine is in `Phase3_Backend_API/app/scoring.py`; run its tests with `pytest -q` from that folder.
- CardioGuard is a tracking tool, not a medical device. It does not diagnose conditions. In an emergency, call 911.
