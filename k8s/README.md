# Uvicorn 调试部署指南

本方案提供一个便于调试的 uvicorn 容器镜像与 Kubernetes 清单，满足以下诉求：

- 默认启动 FastAPI/uvicorn，用于功能验证。
- uvicorn 进程退出时，容器仍保持运行，便于排查和热重启。
- 通过 readinessProbe 将流量自动摘除，但不会触发 Pod 重启。

## 1. 构建与推送镜像

```bash
docker build -t <YOUR_REGISTRY>/uvicorn-debug:latest .
docker push <YOUR_REGISTRY>/uvicorn-debug:latest
```

修改 `k8s/deployment.yaml` 中的 `image` 字段为实际仓库地址。

## 2. 部署到 Kubernetes

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

查看状态：

```bash
kubectl get pods -l app=uvicorn-debug -w
```

## 3. 端口转发与访问

```bash
kubectl port-forward deployment/uvicorn-debug 8000:8000
curl http://127.0.0.1:8000/healthz
```

## 4. 调试流程示例

1. **进入容器**：
   ```bash
   kubectl exec -it deploy/uvicorn-debug -- bash
   ```
2. **停止 uvicorn**（容器仍保持运行）：
   ```bash
   pkill -f uvicorn
   ```
   readinessProbe 会失败，Service 自动摘除该 Pod，但容器不会被重启。
3. **手动重启 uvicorn**：
   ```bash
   START_UVICORN=0 uvicorn app.main:app --host 0.0.0.0 --port 8000 &
   ```
   或直接退出再让 entrypoint 自动重启（设定 `RESPAWN_UVICORN=1`）。

## 5. 关键环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `APP_MODULE` | `app.main:app` | uvicorn 加载的 ASGI 模块 |
| `UVICORN_EXTRA` | `--reload --log-level debug` | 额外命令行参数，可关闭 reload 以提高性能 |
| `START_UVICORN` | `1` | 设为 `0` 可跳过自动启动，在容器内手动运行 |
| `RESPAWN_UVICORN` | `0` | 设为 `1` 时 uvicorn 异常退出将被自动重启 |
| `IDLE_COMMAND` | `tail -f /dev/null` | 控制容器主进程，保证即使 uvicorn 退出也不会导致容器终止 |

## 6. 重要说明

- **容器存活性**：未配置 livenessProbe，uvicorn 退出不会触发 Pod 重启；如需健康检查，可改为检测 entrypoint 主进程而非 uvicorn 本身。
- **流量控制**：readinessProbe 使用 `/healthz` 接口，仅在 uvicorn 可用时提供服务。
- **调试兼容**：`IDLE_COMMAND` 可以替换为 `sleep infinity`、`bash` 等，以满足更灵活的调试需求。
