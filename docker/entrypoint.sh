#!/usr/bin/env bash
set -euo pipefail

APP_MODULE=${APP_MODULE:-app.main:app}
HOST=${HOST:-0.0.0.0}
PORT=${PORT:-8000}
UVICORN_EXTRA=${UVICORN_EXTRA:---reload --log-level debug}
START_UVICORN=${START_UVICORN:-1}
RESPAWN_UVICORN=${RESPAWN_UVICORN:-0}
IDLE_COMMAND=${IDLE_COMMAND:-tail -f /dev/null}

UVICORN_PID=""
UVICORN_MANAGER_PID=""
IDLE_PID=""

start_uvicorn() {
    echo "[entrypoint] $(date -Is) 启动 uvicorn: ${APP_MODULE} -> ${HOST}:${PORT}"
    IFS=' ' read -r -a extra_args <<< "${UVICORN_EXTRA}"
    uvicorn "${APP_MODULE}" --host "${HOST}" --port "${PORT}" "${extra_args[@]}" &
    UVICORN_PID=$!
}

uvicorn_loop() {
    while true; do
        start_uvicorn
        if ! wait "${UVICORN_PID}"; then
            EXIT_CODE=$?
            echo "[entrypoint] $(date -Is) uvicorn 异常退出，状态码 ${EXIT_CODE}"
        else
            echo "[entrypoint] $(date -Is) uvicorn 正常结束"
        fi
        UVICORN_PID=""
        if [[ "${RESPAWN_UVICORN}" != "1" ]]; then
            break
        fi
        echo "[entrypoint] 将在 1 秒后重启 uvicorn ..."
        sleep 1
    done
}

cleanup() {
    echo "[entrypoint] 收到停止信号，开始清理..."
    if [[ -n "${UVICORN_PID}" ]]; then
        kill "${UVICORN_PID}" 2>/dev/null || true
    fi
    if [[ -n "${UVICORN_MANAGER_PID}" ]]; then
        kill "${UVICORN_MANAGER_PID}" 2>/dev/null || true
    fi
    if [[ -n "${IDLE_PID}" ]]; then
        kill "${IDLE_PID}" 2>/dev/null || true
    fi
}

trap cleanup TERM INT

if [[ "${START_UVICORN}" == "1" ]]; then
    uvicorn_loop &
    UVICORN_MANAGER_PID=$!
else
    echo "[entrypoint] START_UVICORN=0，跳过自动启动 uvicorn，可通过 kubectl exec 手动调试。"
fi

echo "[entrypoint] 进入持久化调试模式: ${IDLE_COMMAND}"
bash -c "${IDLE_COMMAND}" &
IDLE_PID=$!
wait "${IDLE_PID}"
