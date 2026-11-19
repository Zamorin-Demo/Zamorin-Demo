# SSM + ECR Setup Runbook (one-time)

## 1. Create ECR repository

```bash
aws ecr create-repository --repository-name zamorin-demo --region ap-south-1
```

## 2. Create IAM role for EC2

Create a role `zamorin-demo-ec2-role` with these managed policies:
- `AmazonSSMManagedInstanceCore` — enables Session Manager + Run Command (no SSH needed)
- `AmazonEC2ContainerRegistryReadOnly` — allows pulling images from ECR

Attach this role to your EC2 instance as an instance profile.

## 3. Launch EC2

- AMI: Ubuntu 24.04 LTS
- Type: t3.small
- Region: ap-south-1
- Security group: inbound 80 + 443 from 0.0.0.0/0 (NO port 22 needed)
- Instance profile: zamorin-demo-ec2-role
- Storage: 20 GB gp3

## 4. Allocate Elastic IP

EC2 Console → Elastic IPs → Allocate → Associate with instance. Note the IP.

## 5. Install Docker (via SSM Session Manager)

```bash
aws ssm start-session --target i-xxxxxxxxx --region ap-south-1

# Inside the session:
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker ubuntu
# Log out and reconnect
```

## 6. Deploy initial stack

```bash
# Via SSM session:
cd /home/ubuntu
git clone <your-demo-repo> zamorin-demo
cd zamorin-demo
cp .env.demo.example .env
nano .env   # fill in Elastic IP, secrets, master credentials
docker compose up -d
```

## 7. Verify

```bash
# From your laptop:
curl https://<elastic-ip-with-dashes>.sslip.io/health/ready
```

## 8. Set up GitHub Actions (for tag-triggered deploys)

In your demo repo's GitHub settings, add these secrets:
- `AWS_ACCESS_KEY_ID` — IAM user with ECR push + SSM send-command permissions
- `AWS_SECRET_ACCESS_KEY`
- `EC2_INSTANCE_ID` — e.g. i-0abc123def456

IAM policy for the CI user (least privilege):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ssm:SendCommand",
      "Resource": "arn:aws:ssm:ap-south-1:*:document/AWS-RunShellScript"
    },
    {
      "Effect": "Allow",
      "Action": "ssm:GetCommandInvocation",
      "Resource": "*"
    }
  ]
}
```

## 9. Deploy via tag

```bash
# On your laptop:
git tag v0.1.0-demo
git push origin v0.1.0-demo
# → GitHub Actions builds, pushes to ECR, triggers SSM deploy
# → EC2 pulls new image and restarts backend
```

## 10. Manual deploy (without CI)

```bash
AWS_REGION=ap-south-1 EC2_INSTANCE_ID=i-xxxxxxxxx ./scripts/deploy.sh v0.1.0-demo
```

## 11. Teardown

```bash
# Via SSM session:
cd /home/ubuntu/zamorin-demo && docker compose down -v

# Then in AWS console: terminate EC2, release Elastic IP, delete ECR repo
```
