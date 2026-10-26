# CardioGuard Phase 3: scoring API

FastAPI service. `POST /v1/score` takes a new reading plus the user's history and returns a tier
(`normal` / `note` / `urgent`), a 0-1 score, confidence, plain-language reasons, and per-measure stats.

## Run it (Terminal on your Mac, not Xcode)

```bash
cd CardioGuard/backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pytest -q                                   # 13 tests
python -m scripts.simulate                  # synthetic alert-rate check
uvicorn app.main:app --reload --port 8000   # leave running while you use the app
```

Then open http://localhost:8000/docs for an interactive page to try requests.
Set `CARDIOGUARD_API_KEY=somesecret` before starting to require an `X-API-Key` header.

## How it scores (manual vitals)
- Per user, per measure: robust baseline (median + MAD) from the user's own history, shrunk toward a generic prior while data is scarce (cold start).
- The 2 most recent readings are excluded from the baseline, so a developing problem can't quietly become "normal".
- note: one reading >= 3 robust SDs from your normal, or 3 in a row >= 2 SDs in the same direction.
- urgent: 2 in a row >= 4 SDs in the same direction, and not still calibrating (needs ~10+ readings over 3+ days).
- Separate absolute safety rules (very low glucose, BP crisis range, low oxygen) in `app/scoring.py: SAFETY_RULES`. Have a clinician check these before real-world use.
- Stateless: nothing is stored or logged server-side.

## Why this isn't the Phase 2 model (yet)
Phase 2's Isolation Forest scores beat-to-beat timing (RR intervals), which needs Apple Watch data (Phase 5).
Manually typed readings don't contain that, so this phase uses the statistical-baseline approach from the spec. A `/v1/rhythm/score` endpoint can be added alongside once real MIT-BIH results exist and HealthKit supplies RR data.

## Deploy
`docker build -t cardioguard-api . && docker run -p 8000:8000 -e CARDIOGUARD_API_KEY=... cardioguard-api`
(or push this folder to Render/Fly.io/Railway). Use HTTPS in production.
