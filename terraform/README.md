# Terraform AWS Deployment

This Terraform configuration deploys the Fitband MQTT Broker to AWS using the cheapest possible setup.

## Cost Breakdown

### Option 1: EC2 + RDS (Recommended)

- **EC2 t3.micro**: Free for 12 months, then ~$7/month
- **RDS db.t3.micro**: Free for 12 months, then ~$15/month
- **EBS Storage**: ~$2/month (20GB)
- **Data Transfer**: Minimal for small deployments
- **Total after free tier**: ~$24/month

### Option 2: EC2 Only (Cheapest)

- **EC2 t3.micro**: Free for 12 months, then ~$7/month
- **EBS Storage**: ~$2/month
- **Total after free tier**: ~$9/month
- ⚠️ PostgreSQL runs on same instance (less reliable, but cheaper)

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured: `aws configure`
3. **AWS Credentials** - Make sure you're logged in:
   - If using AWS SSO: `aws sso login`
   - If using regular credentials: `aws configure`
4. **Terraform** installed: `brew install terraform` (or [download](https://www.terraform.io/downloads))
5. **SSH Key Pair** created in AWS:
   ```bash
   aws ec2 create-key-pair --key-name fitband-broker-key --query 'KeyMaterial' --output text > ~/.ssh/fitband-broker-key.pem
   chmod 400 ~/.ssh/fitband-broker-key.pem
   ```

## Quick Start

1. **Copy example variables**:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Create AWS Key Pair**:

   **Using AWS CLI** :

   ```bash
   # Create key pair and save to ~/.ssh/
   aws ec2 create-key-pair \
     --key-name fitband-broker-key \
     --query 'KeyMaterial' \
     --output text > ~/.ssh/fitband-broker-key.pem

   # Set correct permissions (required for SSH)
   chmod 400 ~/.ssh/fitband-broker-key.pem

   # Verify it was created
   aws ec2 describe-key-pairs --key-names fitband-broker-key
   ```

3. **Edit `terraform.tfvars`** with your values:

   - `key_pair_name`: The name you used above (e.g., `fitband-broker-key`)
   - `git_repo_url`: Your repository URL (e.g., `https://github.com/yourusername/fitband-mqtt-broker.git`)
   - `api_key`: Generate with `openssl rand -hex 32`
   - `ssh_cidr`: Restrict to your IP for security (e.g., `"1.2.3.4/32"` or use `"0.0.0.0/0"` for testing)

4. **Initialize Terraform**:

   ```bash
   cd terraform
   terraform init
   ```

5. **Plan deployment**:

   **If using AWS SSO or temporary credentials** (most common), use the helper script:
   ```bash
   ./run-terraform.sh plan
   ```
   
   **Or export credentials manually**:
   ```bash
   eval $(aws configure export-credentials --format env)
   terraform plan
   ```
   
   **If using permanent credentials** (stored in ~/.aws/credentials):
   ```bash
   terraform plan
   ```

6. **Deploy**:

   **With helper script** (recommended for SSO):
   ```bash
   ./run-terraform.sh apply
   ```
   
   **Or manually**:
   ```bash
   eval $(aws configure export-credentials --format env)
   terraform apply
   ```

7. **Get outputs** (URLs, IPs, database password):
   ```bash
   terraform output
   ```

## Configuration Options

### Cheapest Setup (EC2 Only)

Set in `terraform.tfvars`:

```hcl
use_rds = false
```

This installs PostgreSQL directly on the EC2 instance. Total cost: ~$9/month after free tier.

### Recommended Setup (EC2 + RDS)

Set in `terraform.tfvars`:

```hcl
use_rds = true
db_instance_class = "db.t3.micro"
```

More reliable, separate database. Total cost: ~$24/month after free tier.

### Custom VPC

If you want to create a new VPC instead of using default:

```hcl
create_vpc = true
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
```

## Security Notes

⚠️ **Important**: Before production deployment:

1. **Restrict SSH access**:

   ```hcl
   ssh_cidr = "YOUR_IP/32"  # Replace with your actual IP
   ```

2. **Set CORS origin**:

   ```hcl
   cors_origin = "https://yourdomain.com"
   ```

3. **Enable RDS snapshots**:

   ```hcl
   db_skip_final_snapshot = false
   ```

4. **Use strong API key**:
   ```bash
   openssl rand -hex 32
   ```

## Accessing the Application

After deployment, get the URLs:

```bash
terraform output application_urls
```

- Health: `http://IP:8080/health`
- API: `http://IP:8080/api`
- WebSocket: `ws://IP:8080/ws`

## Updating the Application

SSH to the instance and pull latest code:

```bash
# Get SSH command
terraform output ssh_command

# Then on the instance:
cd /home/ubuntu/fitband-mqtt-broker
git pull origin main
sudo docker-compose -f docker-compose.yml --env-file .env.prod up -d --build
```

## Database Access

### If using RDS:

```bash
# Get connection string
terraform output -raw database_url

# Or connect via EC2:
ssh -i ~/.ssh/key.pem ubuntu@EC2_IP
psql -h RDS_ENDPOINT -U postgres -d fitband_broker
```

### If using local PostgreSQL:

```bash
ssh -i ~/.ssh/key.pem ubuntu@EC2_IP
sudo -u postgres psql -d fitband_broker
```

## Troubleshooting

### Check instance logs:

```bash
ssh -i ~/.ssh/key.pem ubuntu@EC2_IP
sudo journalctl -u docker -f
sudo docker-compose -f /home/ubuntu/fitband-mqtt-broker/docker-compose.yml --env-file /home/ubuntu/fitband-mqtt-broker/.env.prod logs
```

### Check application health:

```bash
curl http://EC2_IP:8080/health
```

### Restart application:

```bash
ssh -i ~/.ssh/key.pem ubuntu@EC2_IP
cd /home/ubuntu/fitband-mqtt-broker
sudo docker-compose -f docker-compose.yml --env-file .env.prod restart
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

⚠️ **Warning**: This will delete the database and all data if `db_skip_final_snapshot = true`!

## Cost Optimization Tips

1. **Use EC2 only** (`use_rds = false`) for development/testing
2. **Stop instance** when not in use (data persists on EBS)
3. **Use Spot Instances** for non-critical workloads (add to `main.tf` if needed)
4. **Monitor costs** in AWS Cost Explorer
5. **Set up billing alerts** in AWS Console

## Next Steps

After deployment:

1. Set up HTTPS with Let's Encrypt (see `scripts/deployment/setup-https-duckdns.sh`)
2. Configure domain name and DNS
3. Set up CloudWatch monitoring
4. Configure automated backups
5. Set up CI/CD for deployments
