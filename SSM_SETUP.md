# SSM + ECR Setup Runbook (one-time)

## What was provisioned (already done)

| Resource | Value |
|---|---|
| AWS Account | 290719180191 |
| Region | ap-south-1 |
| IAM Role | `zamorin-demo-ec2-role` |
| IAM Instance Profile | `zamorin-demo-ec2-profile` |
| Security Group | `zamorin-demo-sg` (ports 80, 443 only) |
| AMI | Ubuntu 24.04 LTS (ami-0d49397b762873260) |
| Instance Type | t3.small |
| EC2 Instance | `i-0809330bf1e8a2aad` |
| Elastic IP | `13.202.144.116` |
| Demo URL | `https://13-202-144-116.sslip.io` |
| ECR Repo | `290719180191.dkr.ecr.ap-south-1.amazonaws.com/zamorin-demo` |
| CI User | `zamorin-demo-ci` (AccessKeyId: AKIAUHMBWUWPUTYB6DOB) |

## Prerequisites for redeploy on this instance

The EC2 instance already has Docker installed and the demo repo cloned at `/home/ubuntu/zamorin-demo`. To deploy a new tag:

```bash
# From your laptop
export EC2_INSTANCE_ID=i-0809330bf1e8a2aad
export AWS_REGION=ap-south-1

# Create and push a tag
git tag v0.2.0-demo
git push origin v0.2.0-demo

# Or deploy manually
./scripts/deploy.sh v0.2.0-demo
```

## Gotchas learned during setup

1. **MongoDB ulimit**: The `t3.small` default ulimit (1024) causes "Too many open files" in MongoDB. The `docker-compose.yml` now includes `ulimits.nofile: 65536` for the MongoDB service.

2. **MongoDB replica set**: Must be initiated manually after first start:
   ```bash
   docker exec zamorin-mongodb mongosh --eval "rs.initiate({_id: \"rs0\", members: [{_id: 0, host: \"mongodb:27017\"}]})"
   ```

3. **ALLOWED_ORIGINS**: Production startup validator rejects `http://` origins unless they're `localhost` or `127.0.0.1`. Use only `https://` origins for non-loopback IPs/domains.

4. **Caddyfile hostname**: Caddy needs an explicit server name (e.g. `13-202-144-116.sslip.io`) to obtain a Let's Encrypt certificate. Without it, only HTTP works.

5. **Restart vs recreate**: `docker compose restart` doesn't re-read `.env` changes. Use `docker compose up -d --no-deps backend` to recreate containers with updated env vars.

6. **Tag-based deploys**: Only tags matching `v*-demo` trigger the GitHub Actions workflow. Push a tag to deploy; untagged pushes don't deploy.

## GitHub Actions secrets needed (for CI)

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | AKIAUHMBWUWPUTYB6DOB (from `zamorin-demo-ci` user) |
| `AWS_SECRET_ACCESS_KEY` | (SecretAccessKey from user creation) |
| `EC2_INSTANCE_ID` | i-0809330bf1e8a2aad |

## Teardown

```bash
# Via SSM session:
aws ssm start-session --target i-0809330bf1e8a2aad --region ap-south-1
cd /home/ubuntu/zamorin-demo && docker compose down -v

# Then in AWS console: terminate EC2, release Elastic IP, delete ECR repo
```

## Cost (80-day demo window)

| Item | Monthly | 80 days |
|---|---|---|
| EC2 t3.small | $15.20 | ~$40.50 |
| EBS 20 GB | $1.60 | ~$4.30 |
| ECR storage | ~$0.02 | ~$0.05 |
| **Total** | **~$16.82** | **~$44.85** |

Well within $195 credits (expires Feb 06, 2027).

## Critical: Docker Network

When starting services, ALWAYS use `docker compose up -d` — never `docker run` for individual services. If Caddy is started outside Compose, it won't be on the same Docker network as the backend and API calls will return 502 (causing the frontend to appear to continuously reload).

If this happens, fix it with:
```bash
docker network connect zamorin-demo_default zamorin-frontend-ui
docker restart zamorin-frontend-ui
```
