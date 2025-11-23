# Pi-hole Sync - Setup Guide

Step-by-step guide to set up Pi-hole synchronization.

## Prerequisites

- 2+ Pi-hole instances running in Docker
- Git installed on all systems
- Network access between instances
- Git repository (GitHub, GitLab, self-hosted, etc.)

## Step-by-Step Setup

### Step 1: Prepare Git Repository

```bash
# Create repository on GitHub/GitLab, or:
# Self-hosted:
ssh your-git-server
git init --bare pihole-sync.git
```

### Step 2: Setup on Primary Instance

```bash
# Copy pihole-sync directory to your primary Pi-hole host
cd /opt  # or wherever you want to store it
# (copy the pihole-sync directory here)

cd pihole-sync

# Run setup script
./scripts/setup.sh

# When prompted, enter your Git repository URL:
# Examples:
#   https://github.com/yourusername/pihole-sync.git
#   git@github.com:yourusername/pihole-sync.git
#   ssh://git@your-server/pihole-sync.git
```

### Step 3: Export Initial Configuration

```bash
# Export current Pi-hole configuration
./scripts/export-config.sh

# This will:
# - Export all Pi-hole settings
# - Commit to Git
# - Push to remote repository
```

### Step 4: Set Up Auto-Sync (Primary)

Choose ONE method:

#### Method A: Systemd Service (Recommended)

```bash
# Install and start service
./scripts/install-service.sh

# Verify it's running
sudo systemctl status pihole-sync

# Check logs
sudo journalctl -u pihole-sync -f
```

#### Method B: Cron Job

```bash
# Edit crontab
crontab -e

# Add this line (runs every 5 minutes)
*/5 * * * * cd /opt/pihole-sync && ./scripts/export-config.sh >> /var/log/pihole-sync.log 2>&1
```

#### Method C: Manual Running

```bash
# Run in foreground
./scripts/auto-sync.sh

# Or run in background
nohup ./scripts/auto-sync.sh > /var/log/pihole-sync.log 2>&1 &
```

### Step 5: Setup Secondary Instance(s)

On each secondary Pi-hole host:

```bash
# Clone repository
cd /opt
git clone <your-git-repo-url> pihole-sync
cd pihole-sync

# Make scripts executable
chmod +x scripts/*.sh

# Configure Git (if needed)
git config user.email "pihole@yourdomain.com"
git config user.name "Pi-hole Sync"

# If your container has a different name, set it:
export PIHOLE_CONTAINER=pihole-secondary
# Or add to ~/.bashrc for persistence

# Import configuration
./scripts/import-config.sh

# Verify Pi-hole is working
docker exec pihole pihole status
```

### Step 6: Set Up Auto-Import (Secondary)

On secondary instances, set up periodic import:

```bash
# Edit crontab
crontab -e

# Add this line (runs every 15 minutes)
*/15 * * * * cd /opt/pihole-sync && ./scripts/import-config.sh >> /var/log/pihole-sync-import.log 2>&1

# If using custom container name:
*/15 * * * * cd /opt/pihole-sync && PIHOLE_CONTAINER=pihole-secondary ./scripts/import-config.sh >> /var/log/pihole-sync-import.log 2>&1
```

### Step 7: Test the Setup

```bash
# On primary instance:

# 1. Update blocklists via Pi-hole web interface
# Go to http://pihole-ip/admin
# Settings > Blocklists > Add a new blocklist
# Save and Update Gravity

# 2. Wait for auto-sync (or manually export)
./scripts/export-config.sh

# 3. Check Git repository
git log
git status

# On secondary instance:

# 1. Pull updates
cd /opt/pihole-sync
git pull

# 2. Import configuration
./scripts/import-config.sh

# 3. Verify blocklists updated
docker exec pihole pihole -g
```

## Configuration Options

### Custom Container Names

If your Docker containers have different names:

```bash
# Set environment variable
export PIHOLE_CONTAINER=my-custom-pihole-name

# Or prefix commands
PIHOLE_CONTAINER=my-custom-pihole-name ./scripts/export-config.sh
```

### Custom Check Interval

For auto-sync, adjust the check interval:

```bash
# Check every 2 minutes (120 seconds)
CHECK_INTERVAL=120 ./scripts/auto-sync.sh

# For systemd service, edit the service file:
sudo systemctl edit pihole-sync

# Add:
[Service]
Environment="CHECK_INTERVAL=120"
```

### Debug Mode

Enable verbose logging:

```bash
DEBUG=1 ./scripts/auto-sync.sh
DEBUG=1 ./scripts/export-config.sh
```

## Deployment to New Instances

When setting up a brand new Pi-hole:

```bash
# 1. Start Pi-hole container
docker-compose up -d pihole

# 2. Clone sync repository
git clone <your-repo-url> pihole-sync
cd pihole-sync

# 3. Import existing configuration
./scripts/import-config.sh

# 4. Set up auto-import
crontab -e
# Add: */15 * * * * cd /opt/pihole-sync && ./scripts/import-config.sh >> /var/log/pihole-sync.log 2>&1

# Done! New instance has all your existing blocklists and settings
```

## Docker Compose Example

If you don't have Pi-hole in Docker yet:

```bash
# Copy the example
cp docker-compose.example.yml docker-compose.yml

# Edit and customize
nano docker-compose.yml

# Start Pi-hole
docker-compose up -d

# Wait for Pi-hole to initialize (30-60 seconds)
docker-compose logs -f pihole

# Then run setup
./scripts/setup.sh
./scripts/export-config.sh
```

## Verification Checklist

- [ ] Primary instance exports successfully
- [ ] Git commits are created
- [ ] Changes pushed to remote repository
- [ ] Secondary instance pulls successfully
- [ ] Secondary instance imports successfully
- [ ] Pi-hole settings match between instances
- [ ] Blocklists match between instances
- [ ] Auto-sync service is running (primary)
- [ ] Auto-import cron is configured (secondary)
- [ ] Logs show no errors

## Common Issues

### "Container not found"
```bash
# Check container name
docker ps --format '{{.Names}}'

# Update PIHOLE_CONTAINER variable
export PIHOLE_CONTAINER=actual-container-name
```

### "Permission denied"
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Check directory ownership
ls -la /opt/pihole-sync
```

### "Git push requires password"
```bash
# Option 1: Use SSH keys
ssh-keygen -t ed25519
# Add public key to GitHub/GitLab

# Update remote URL
git remote set-url origin git@github.com:user/repo.git

# Option 2: Use credential helper
git config credential.helper store
```

### "Database is locked"
```bash
# Pi-hole may be running gravity update
# Wait a few seconds and retry, or:
docker exec pihole pihole restartdns
./scripts/import-config.sh
```

### "Import overwrites local changes"
```bash
# Import preserves IP addresses but overwrites most settings
# If you need to keep local changes, manually merge:
git pull
# Review changes
git diff config/
# Manually edit gravity.db or use pihole CLI
```

## Next Steps

1. **Monitor logs** for the first 24 hours
2. **Test failover** - verify secondary can serve DNS if primary fails
3. **Document your setup** - note container names, intervals, etc.
4. **Set up monitoring** - alert if sync fails
5. **Plan backup strategy** - backups are in `backup/` directory

## Support

- Check `README.md` for detailed documentation
- Review logs: `sudo journalctl -u pihole-sync -f`
- Check Pi-hole logs: `docker logs pihole`
- Verify Git status: `git status` and `git log`
