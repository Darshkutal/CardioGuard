import hmac
import os
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException

from .schemas import ScoreRequest, ScoreResponse
from .scoring import MODEL_VERSION, score

@asynccontextmanager
async def lifespan(_: FastAPI):
    if not os.environ.get("CARDIOGUARD_API_KEY"):
        print("WARNING: CARDIOGUARD_API_KEY not set; API is open (dev mode only).")
    yield


app = FastAPI(title="CardioGuard API", version=MODEL_VERSION, lifespan=lifespan)

# Privacy by design: this service is stateless. It never writes health data to disk or logs;
# the app sends the history it wants scored and receives the result.


def require_key(x_api_key: str = Header(default="")) -> None:
    expected = os.environ.get("CARDIOGUARD_API_KEY", "")
    if not expected:
        return  # dev mode: no key configured (warned at startup below)
    if not hmac.compare_digest(x_api_key.encode(), expected.encode()):
        raise HTTPException(status_code=401, detail="invalid api key")


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "model_version": MODEL_VERSION}


@app.post("/v1/score", response_model=ScoreResponse, dependencies=[Depends(require_key)])
def score_reading(req: ScoreRequest) -> ScoreResponse:
    return score(req)
