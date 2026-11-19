# Zamorin Cafe ERP — Demo Deployment (AWS EC2, all-AWS)

Self-contained demo on a single EC2 instance. No Vercel, no Render, no Atlas.
Everything runs in Docker containers on one box. Cost ~$16.60/mo (~$45 for 80 days).

## Prerequisites

- AWS account with credits
- SSH key pair for EC2 access

## 1. Launch EC2

- **AMI:** Ubuntu 24.04 LTS
- **Type:** t3.small (2 vCPU, 2 GB RAM) — enough for Mongo + Redis + Node
- **Region:** ap-south-1 (Mumbai) or closest to you
- **Security group:** inbound 22 (your IP), 80 (0.0.0.0/0), 443 (0.0.0.0/0)
- **Storage:** 20 GB gp3

## 2. Allocate Elastic IP

EC2 Console → Elastic IPs → Allocate → Associate with your instance.  
Note the IP — you'll use it for sslip.io.

## 3. Install Docker

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker ubuntu
# log out and back in
```

## 4. Deploy the app

```bash
# Clone (or scp) the demo repo
git clone <your-infra-repo> /home/ubuntu/zamorin-demo
cd /home/ubuntu/zamorin-demo

# Create .env from template
cp .env.demo.example .env
# Edit .env: replace REPLACE_IP with your Elastic IP, generate secrets
nano .env

# Start everything
docker compose up -d

# Verify
curl http://localhost/health/ready
```

## 5. Access the demo

- URL: `https://<ELASTIC_IP>.sslip.io` (e.g. `https://13-233-45-67.sslip.io`)
- Login: use the `INITIAL_MASTER_EMAIL` / `INITIAL_MASTER_PASSWORD` from your `.env`
- All five windows available: Master, Owner, Cafe Admin, Staff, Vendor portal

## 6. Seed demo data (optional but recommended)

The production mode creates only the master account. For a compelling demo:
- Log in as master
- Create 1 cafe (e.g. "Zamorin Cafe - Demo")
- Add 5-10 menu items
- Add 2-3 staff members
- Create a test order via POS

Or: run `npm run dev` locally (seeds full demo data), then `mongodump`/`mongorestore` to transfer to the EC2 Mongo container.

## 7. Tear down (when done)

```bash
docker compose down -v   # removes containers + volumes (data gone)
# Then terminate EC2 + release Elastic IP in AWS console
```

## Cost

| Item | Monthly | 80 days |
|---|---|---|
| EC2 t3.small | $15.20 | ~$40.50 |
| EBS 20 GB | $1.60 | ~$4.30 |
| Elastic IP | $0 (attached) | $0 |
| SSL (Let's Encrypt via Caddy) | $0 | $0 |
| **Total** | **~$16.80** | **~$44.80** |

Well within $195 credits. Credits expire Feb 06, 2027.

## Troubleshooting

- **Caddy cert fails:** sslip.io Let's Encrypt rate limit. Wait 1 hour or use `http://` for the demo.
- **Mongo won't start:** check `docker compose logs mongodb`. Replica set init takes ~10s on first boot.
- **Backend won't boot:** check `REDIS_URL` is set (production requires Redis). Check `JWT_ACCESS_SECRET` is 32+ chars.
- **Port 80/443 blocked:** security group inbound rules missing.
