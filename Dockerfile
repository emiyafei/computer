FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_MODULE=app.main:app \
    HOST=0.0.0.0 \
    PORT=8000 \
    UVICORN_EXTRA="--reload --log-level debug" \
    START_UVICORN=1 \
    RESPAWN_UVICORN=0 \
    IDLE_COMMAND="tail -f /dev/null"

WORKDIR /workspace
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY docker/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
