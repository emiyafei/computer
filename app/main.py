from fastapi import FastAPI

app = FastAPI(title="Debuggable Uvicorn Service")


@app.get("/healthz")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/echo")
def echo(message: str = "hello") -> dict[str, str]:
    return {"message": message}
