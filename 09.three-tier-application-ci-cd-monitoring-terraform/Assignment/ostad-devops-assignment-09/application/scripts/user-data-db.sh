#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data-db.log) 2>&1

echo "=== Database Setup Starting ==="

# Update and install PostgreSQL 15
dnf update -y
dnf install -y postgresql15-server postgresql15-contrib

# Initialize database
/usr/bin/postgresql-setup --initdb
systemctl enable postgresql
systemctl start postgresql

# Configure PostgreSQL to listen on all interfaces
cat > /var/lib/pgsql/data/postgresql.conf << 'EOF'
listen_addresses = '*'
port = 5432
max_connections = 100
shared_buffers = 256MB
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
EOF

# Allow connections from backend tier (VPC CIDR 10.0.0.0/16)
cat > /var/lib/pgsql/data/pg_hba.conf << 'EOF'
local   all             all                                     peer
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
host    all             all             10.0.0.0/16             scram-sha-256
EOF

# Set ownership and restart
chown -R postgres:postgres /var/lib/pgsql/data
systemctl restart postgresql

# Create database, user, and sample table
sudo -u postgres psql << EOF
CREATE DATABASE ${db_name};
CREATE USER ${db_user} WITH ENCRYPTED PASSWORD '${db_password}';
GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
ALTER DATABASE ${db_name} OWNER TO ${db_user};
\c ${db_name}
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO users (name, email) VALUES
  ('Alice', 'alice@example.com'),
  ('Bob', 'bob@example.com')
ON CONFLICT DO NOTHING;
EOF

echo "=== Database Setup Complete ==="
