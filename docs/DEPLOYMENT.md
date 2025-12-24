# Deployment Guide

This guide covers deploying AfyaFit to staging and production environments using Docker and GitLab CI/CD.

## Prerequisites

- Docker and Docker Compose installed on the server
- GitLab CI/CD configured with necessary variables
- SSH access to staging/production servers
- Required secrets files in `secrets/prod/` directory

## Environment Setup

### Required Secrets

Create the following secret files in `secrets/prod/`:

- `postgres_user.txt` - PostgreSQL username
- `postgres_password.txt` - PostgreSQL password
- `postgres_db.txt` - PostgreSQL database name
- `database_url.txt` - Full database URL (e.g., `ecto://user:pass@host/dbname`)
- `secret_key_base.txt` - Secret key base (generate with `mix phx.gen.secret`)
- `paystack_secret_key.txt` - Paystack secret key

### GitLab CI/CD Variables

Configure the following variables in GitLab CI/CD settings:

**For Staging:**
- `STAGING_SERVER` - Staging server hostname/IP
- `STAGING_USER` - SSH user for staging server
- `STAGING_APP_PATH` - Path to application on staging server
- `SSH_PRIVATE_KEY` - SSH private key for deployment

**For Production:**
- `PRODUCTION_SERVER` - Production server hostname/IP
- `PRODUCTION_USER` - SSH user for production server
- `PRODUCTION_APP_PATH` - Path to application on production server
- `SSH_PRIVATE_KEY` - SSH private key for deployment

**Common:**
- `CI_REGISTRY` - Docker registry URL
- `CI_REGISTRY_USER` - Docker registry username
- `CI_REGISTRY_PASSWORD` - Docker registry password

## Local Development

### Development Environment

Start the development environment:

```bash
docker-compose up -d
mix setup
mix phx.server
```

### Building Docker Image Locally

```bash
docker build -t afyafit:latest -f Dockerfile .
```

## Staging Deployment

### Initial Setup

1. Clone the repository on the staging server
2. Create `secrets/staging/` directory with all required secret files
3. Ensure Docker and Docker Compose are installed
4. Configure GitLab CI/CD variables for staging
5. Initialize backups directory: `./scripts/init_backups_dir.sh`

### Deploying to Staging

1. Push code to the `develop` branch
2. GitLab CI/CD will automatically:
   - Run tests
   - Build Docker image
   - Push image to registry
3. Manually trigger the `deploy:staging` job in GitLab CI/CD
4. The deployment will:
   - Pull the latest Docker image
   - Restart services
   - Run database migrations

### Manual Staging Deployment

```bash
# SSH into staging server
ssh user@staging-server

# Navigate to application directory
cd /path/to/afyafit

# Pull latest changes
git pull origin develop

# Initialize backups directory (first time only)
./scripts/init_backups_dir.sh

# Pull latest Docker images
docker-compose -f docker-compose.staging.yml pull

# Start/restart services
docker-compose -f docker-compose.staging.yml up -d

# Run migrations
docker-compose -f docker-compose.staging.yml exec app mix ecto.migrate
```

## Production Deployment

### Initial Setup

1. Clone the repository on the production server
2. Create `secrets/prod/` directory with all required secret files
3. Ensure Docker and Docker Compose are installed
4. Configure GitLab CI/CD variables for production
5. Initialize backups directory: `./scripts/init_backups_dir.sh`
6. Set up SSL certificates (if using HTTPS)
7. Configure reverse proxy (nginx/traefik) if needed

### Deploying to Production

1. Push code to the `main` branch or create a tag
2. GitLab CI/CD will automatically:
   - Run tests
   - Build Docker image
   - Push image to registry
3. Manually trigger the `deploy:production` job in GitLab CI/CD
4. The deployment will:
   - Pull the latest Docker image
   - Restart services
   - Run database migrations

### Manual Production Deployment

```bash
# SSH into production server
ssh user@production-server

# Navigate to application directory
cd /path/to/afyafit

# Pull latest changes
git pull origin main

# Pull latest Docker images
docker-compose -f docker-compose.prod.yml pull

# Start/restart services
docker-compose -f docker-compose.prod.yml up -d

# Run migrations
docker-compose -f docker-compose.prod.yml exec app mix ecto.migrate
```

## Database Backups

### Automated Backups

Backups are configured to run automatically via cron. To set up:

```bash
# On the server, run:
./scripts/setup_backup_cron.sh
```

This will create a daily backup at 2 AM (configurable via `CRON_SCHEDULE`).

### Manual Backup

```bash
# Create a backup
./scripts/backup_postgres.sh

# Backups are stored in /backups directory
# Default retention: 30 days
```

### Restore from Backup

```bash
# Restore a backup
./scripts/restore_postgres.sh /backups/afyafit_backup_YYYYMMDD_HHMMSS.sql.gz
```

## Monitoring

### Health Checks

The application includes health checks:
- Application: `http://localhost:4000/`
- PostgreSQL: Automatic health check in docker-compose
- Redis: Automatic health check in docker-compose

### Logs

View application logs:

```bash
# Production - All services
docker-compose -f docker-compose.prod.yml logs -f

# Production - Application only
docker-compose -f docker-compose.prod.yml logs -f app

# Staging - All services
docker-compose -f docker-compose.staging.yml logs -f

# Staging - Application only
docker-compose -f docker-compose.staging.yml logs -f app
```

### Database Access

```bash
# Production - Access PostgreSQL shell
docker-compose -f docker-compose.prod.yml exec postgres psql -U $(cat secrets/prod/postgres_user.txt) -d $(cat secrets/prod/postgres_db.txt)

# Staging - Access PostgreSQL shell
docker-compose -f docker-compose.staging.yml exec postgres psql -U $(cat secrets/staging/postgres_user.txt) -d $(cat secrets/staging/postgres_db.txt)
```

## Troubleshooting

### Application Won't Start

1. Check logs: `docker-compose -f docker-compose.prod.yml logs app`
2. Verify secrets are correctly set
3. Check database connectivity
4. Ensure migrations are up to date

### Database Connection Issues

1. Verify PostgreSQL is running: `docker-compose -f docker-compose.prod.yml ps`
2. Check database credentials in secrets
3. Verify network connectivity between containers

### Migration Issues

```bash
# Rollback last migration
docker-compose -f docker-compose.prod.yml exec app mix ecto.rollback

# Check migration status
docker-compose -f docker-compose.prod.yml exec app mix ecto.migrations
```

## Security Considerations

1. **Secrets Management**: Never commit secrets to version control
2. **SSL/TLS**: Configure HTTPS in production
3. **Firewall**: Restrict access to necessary ports only
4. **Updates**: Keep Docker images and dependencies updated
5. **Backups**: Regularly test backup restoration procedures

## Rollback Procedure

If a deployment causes issues:

```bash
# Stop current services
docker-compose -f docker-compose.prod.yml down

# Checkout previous version
git checkout <previous-commit-hash>

# Pull previous Docker image
docker-compose -f docker-compose.prod.yml pull

# Start services
docker-compose -f docker-compose.prod.yml up -d

# Rollback database migrations if needed
docker-compose -f docker-compose.prod.yml exec app mix ecto.rollback
```

