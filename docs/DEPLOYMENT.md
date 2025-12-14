# Deployment Guide

Complete guide for deploying Fitband MQTT Broker to AWS EC2.

## Prerequisites

- AWS CLI installed and configured
- SSH key pair for EC2 access
- DuckDNS account (for dynamic DNS)
- Domain/subdomain configured

## Quick Deploy

### 1. Create EC2 Instance

```bash
# Create t2.micro instance (free tier eligible)
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name fitband-broker-key \
  --security-group-ids sg-xxxxxxxxx \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=fitband-mqtt-broker}]'
```

### 2. Configure Security Group

Allow inbound traffic:
- SSH (22) from your IP
- HTTP (80) from anywhere
- HTTPS (443) from anywhere
- Custom TCP (8080) from anywhere (optional, for direct access)

### 3. Deploy Application

```bash
# From your local machine
./scripts/deployment/deploy-to-aws.sh main
```

This will:
- SSH into EC2 instance
- Clone/update repository
- Build Docker containers
- Run database migrations
- Start the application

### 4. Setup HTTPS (Optional but Recommended)

SSH into the server and run:

```bash
ssh -i ~/.ssh/fitband-broker-key.pem ubuntu@<EC2_IP>
cd /home/ubuntu/fitband-mqtt-broker
sudo ./scripts/deployment/setup-https-duckdns.sh
```

Follow the prompts to:
- Configure DuckDNS subdomain
- Get Let's Encrypt SSL certificate
- Setup Nginx reverse proxy
- Enable automatic certificate renewal

## Environment Configuration

### Development (.env)

```bash
NODE_ENV=development
ENABLE_HTTPS=true
HTTPS_PORT=8443
HTTP_PORT=8080
DATABASE_URL=postgresql://...
```

### Production (.env.prod)

```bash
NODE_ENV=production
ENABLE_HTTPS=false  # Nginx handles HTTPS
HTTP_PORT=8080
DATABASE_URL=postgresql://...
API_KEY=your-secure-api-key
CORS_ORIGIN=https://yourdomain.com
```

## Post-Deployment

### Check Status

```bash
# From local machine
./scripts/deployment/check-status.sh

# Or SSH into server
ssh -i ~/.ssh/fitband-broker-key.pem ubuntu@<EC2_IP>
sudo docker ps
sudo docker logs fitband-mqtt-broker
```

### Test Endpoints

```bash
# Health check
curl https://yourdomain.com/health

# Swagger API docs
open https://yourdomain.com/api

# WebSocket
node scripts/utils/test-websocket.js wss://yourdomain.com/ws
```

### Monitor Logs

```bash
# Real-time logs
sudo docker logs -f fitband-mqtt-broker

# Last 100 lines
sudo docker logs --tail=100 fitband-mqtt-broker
```

## Maintenance

### Update Application

```bash
# Deploy latest changes
./scripts/deployment/deploy-to-aws.sh main
```

### Cleanup Docker Resources

If disk space runs low:

```bash
./scripts/deployment/cleanup-docker.sh
```

### Renew SSL Certificate

Automatic renewal is configured via Certbot. Check status:

```bash
sudo certbot renew --dry-run
sudo systemctl status certbot.timer
```

### Update DuckDNS IP

Automatic updates every 5 minutes via cron. Manual update:

```bash
/usr/local/bin/update-duckdns.sh
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
sudo docker logs fitband-mqtt-broker

# Rebuild and restart
cd /home/ubuntu/fitband-mqtt-broker
sudo docker-compose -f docker-compose.prod.yml down
sudo docker-compose -f docker-compose.prod.yml up --build -d
```

### Database Migration Issues

```bash
# Reset and re-run migrations
sudo docker exec fitband-mqtt-broker npx prisma migrate reset
sudo docker exec fitband-mqtt-broker npx prisma migrate deploy
```

### Nginx Issues

```bash
# Check Nginx status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Check error logs
sudo tail -f /var/log/nginx/error.log
```

### WebSocket Connection Fails

1. Check Nginx configuration for `/ws/` location
2. Verify WebSocket upgrade headers
3. Check firewall/security group rules
4. Test with: `node scripts/utils/test-websocket.js wss://yourdomain.com/ws`

### High Memory Usage

```bash
# Check container stats
sudo docker stats

# Restart container
sudo docker restart fitband-mqtt-broker
```

## Scaling

### Vertical Scaling

Upgrade EC2 instance type:

```bash
# Stop instance
aws ec2 stop-instances --instance-ids i-xxxxxxxxx

# Change instance type
aws ec2 modify-instance-attribute \
  --instance-id i-xxxxxxxxx \
  --instance-type t2.medium

# Start instance
aws ec2 start-instances --instance-ids i-xxxxxxxxx
```

### Horizontal Scaling

For multiple instances:
1. Use AWS Application Load Balancer
2. Enable sticky sessions for WebSocket
3. Use Redis for session storage
4. Configure database connection pooling

## Security Best Practices

1. **Use HTTPS**: Always enable HTTPS in production
2. **Rotate API Keys**: Change API_KEY regularly
3. **Update Dependencies**: Keep packages up to date
4. **Monitor Logs**: Watch for suspicious activity
5. **Backup Database**: Regular PostgreSQL backups
6. **Limit SSH Access**: Restrict SSH to your IP
7. **Use IAM Roles**: For AWS service access
8. **Enable CloudWatch**: For metrics and alerts

## Cost Optimization

- Use t2.micro (free tier) for testing
- Schedule auto-stop for non-production environments
- Use RDS free tier or external database
- Enable EBS snapshots with retention policy
- Monitor data transfer costs
- Use CloudFront for static assets

## Monitoring

### CloudWatch Metrics

- CPU utilization
- Memory usage
- Network traffic
- Disk I/O
- Request count/latency

### Application Metrics

- Active WebSocket connections
- Message throughput
- API response times
- Error rates
- Database query performance

## Backup & Recovery

### Database Backup

```bash
# Manual backup
pg_dump $DATABASE_URL > backup-$(date +%Y%m%d).sql

# Restore
psql $DATABASE_URL < backup-20240101.sql
```

### Code Backup

Git repository serves as code backup. Tag releases:

```bash
git tag -a v1.0.0 -m "Production release"
git push origin v1.0.0
```

## Support

For issues or questions:
1. Check application logs
2. Review Nginx logs
3. Test with utility scripts
4. Verify environment configuration

