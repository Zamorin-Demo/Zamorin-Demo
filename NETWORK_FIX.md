# Docker Network Fix — Critical for Caddy + Backend Communication

## The Problem
When Caddy is started via `docker run` (outside Docker Compose), it runs on Docker's default `bridge` network. The backend, started via `docker compose`, runs on the `zamorin-demo_default` network. Caddy cannot resolve the `backend` hostname, resulting in 502 errors on all `/api/*` requests — which makes the frontend appear to continuously reload.

## The Fix — Always use Docker Compose
Never start Caddy with `docker run`. Always use:

```bash
cd /home/ubuntu/zamorin-demo
docker compose up -d
```

This ensures all services (MongoDB, Redis, Backend, Caddy/Frontend) are on the same `zamorin-demo_default` network and can resolve each other by service name.

## If Caddy is already running standalone (wrong network)
Connect it to the compose network and restart:

```bash
docker network connect zamorin-demo_default zamorin-frontend-ui
docker restart zamorin-frontend-ui
```

## Verification
From inside the Caddy container, `backend` should resolve:

```bash
docker exec zamorin-frontend-ui ping -c 1 backend
```

And `/api/*` requests through Caddy should return 200:

```bash
curl -sf https://<your-sslip-host>.sslip.io/api/v1/health
```
