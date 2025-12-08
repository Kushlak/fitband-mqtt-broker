#!/bin/bash
set -e

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install PostgreSQL
apt-get install -y postgresql postgresql-contrib

# Configure PostgreSQL
sudo -u postgres psql <<EOF
CREATE DATABASE fitband_broker;
ALTER USER postgres WITH PASSWORD 'postgres';
EOF

# Update pg_hba.conf to allow local connections
PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)
echo "local   all             all                                     trust" > /etc/postgresql/${PG_VERSION}/main/pg_hba.conf
echo "host    all             all             127.0.0.1/32            trust" >> /etc/postgresql/${PG_VERSION}/main/pg_hba.conf
echo "host    all             all             ::1/128                 trust" >> /etc/postgresql/${PG_VERSION}/main/pg_hba.conf

systemctl restart postgresql
systemctl enable postgresql

# Install Docker
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install Docker Compose (standalone)
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install Git
apt-get install -y git

# Clone repository
cd /home/ubuntu
if [ -d "fitband-mqtt-broker" ]; then
  rm -rf fitband-mqtt-broker
fi
git clone ${git_repo} fitband-mqtt-broker
cd fitband-mqtt-broker
git checkout ${git_branch}

# Create production .env file
cat > .env.prod <<EOF
NODE_ENV=production
HTTP_PORT=8080
HTTPS_PORT=443
ENABLE_HTTPS=false

DATABASE_URL=postgresql://postgres:postgres@localhost:5432/fitband_broker

CORS_ORIGIN=${cors_origin}

API_KEY=${api_key}

PRISMA_CLIENT_ENGINE_TYPE=binary
RUN_MIGRATIONS=true
EOF

# Build and start application
# Use docker-compose.prod.yml if it exists, otherwise use docker-compose.yml
COMPOSE_FILE="docker-compose.prod.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
  COMPOSE_FILE="docker-compose.yml"
fi

docker-compose -f $COMPOSE_FILE --env-file .env.prod build
docker-compose -f $COMPOSE_FILE --env-file .env.prod run --rm websocket-gateway npx prisma migrate deploy || docker-compose -f $COMPOSE_FILE --env-file .env.prod run --rm app npx prisma migrate deploy || true
docker-compose -f $COMPOSE_FILE --env-file .env.prod up -d

# Wait for application to start
sleep 15

# Check health
curl -f http://localhost:8080/health || echo "Health check failed, but continuing..."

# Log completion
echo "Deployment completed at $(date)" >> /var/log/fitband-deployment.log

