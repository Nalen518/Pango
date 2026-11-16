"""Pango agent service (Phase 0 skeleton: endpoints are placeholders)."""

from fastapi import FastAPI

app = FastAPI(title="Pango agent")


@app.get("/health")
def health() -> dict:
    return {"ok": True}


def main() -> None:
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000)
