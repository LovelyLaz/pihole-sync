# Pi-hole Sync

Automated Pi-hole configuration synchronization across multiple instances using Git.

## Features

- **Automatic synchronization** of blocklists, whitelists, blacklists, and regex filters
- **Git-based** version control for configuration history
- **Auto-sync monitoring** with systemd service
- **Backup support** with automatic backup rotation
- **Docker-friendly** with configurable container names
- **Easy deployment** to new instances

## What Gets Synced

- Gravity database (all blocklists, whitelists, blacklists)
- Custom DNS records
- DNSMasq configuration
- Pi-hole settings (with IP preservation)
- Regex filters (whitelist and blacklist)
- Ad list sources

## Quick Start

### 1. Initial Setup

```bash
# Clone or create the repository
cd /tmp/pihole-sync

# Run setup script
./scripts/setup.sh

# Export current Pi-hole configuration
./scripts/export-config.sh
```

### 2. Set Up Auto-Sync on Primary Instance

**Option A: Systemd Service (Recommended)**
```bash
./scripts/install-service.sh

# Check status
sudo systemctl status pihole-sync

# View logs
sudo journalctl -u pihole-sync -f
```

**Option B: Run in Foreground**
```bash
./scripts/auto-sync.sh
```

**Option C: Cron Job**
```bash
# Add to crontab (every 5 minutes)
crontab -e

# Add this line:
*/5 * * * * cd /path/to/pihole-sync && ./scripts/export-config.sh >> /var/log/pihole-sync.log 2>&1
```

### 3. Set Up Secondary Instance(s)

```bash
# Clone the repository
git clone <your-repo-url> pihole-sync
cd pihole-sync

# If using different container name
export PIHOLE_CONTAINER=pihole-secondary

# Import configuration
./scripts/import-config.sh

# Set up periodic import (every 15 minutes)
crontab -e

# Add this line:
*/15 * * * * cd /path/to/pihole-sync && PIHOLE_CONTAINER=pihole-secondary ./scripts/import-config.sh >> /var/log/pihole-sync-import.log 2>&1
```

### 4. Deploy to New Instance

```bash
# On new server/container
git clone <your-repo-url> pihole-sync
cd pihole-sync

# Import existing configuration
./scripts/import-config.sh

# Set up auto-import
*/15 * * * * cd /path/to/pihole-sync && ./scripts/import-config.sh >> /var/log/pihole-sync.log 2>&1
```

## Scripts

| Script | Description |
|--------|-------------|
| `setup.sh` | Initial setup and Git configuration |
| `export-config.sh` | Export Pi-hole config to Git |
| `import-config.sh` | Import Pi-hole config from Git |
| `auto-sync.sh` | Monitor and auto-export on changes |
| `install-service.sh` | Install systemd service |
| `sync-now.sh` | Quick manual sync (export/import) |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PIHOLE_CONTAINER` | `pihole` | Docker container name |
| `CHECK_INTERVAL` | `300` | Auto-sync check interval (seconds) |
| `DEBUG` | `0` | Enable debug logging (set to `1`) |

## Usage Examples

### Export from Custom Container
```bash
PIHOLE_CONTAINER=my-pihole ./scripts/export-config.sh
```

### Import to Multiple Instances
```bash
# Instance 1
PIHOLE_CONTAINER=pihole1 ./scripts/import-config.sh

# Instance 2
PIHOLE_CONTAINER=pihole2 ./scripts/import-config.sh
```

### Manual Sync
```bash
# Export only
./scripts/sync-now.sh export

# Import only
./scripts/sync-now.sh import

# Both (for testing)
./scripts/sync-now.sh both
```

## Directory Structure

```
pihole-sync/
├── config/              # Synced configuration (committed to Git)
│   ├── gravity.db       # Main Pi-hole database
│   ├── custom.list      # Custom DNS records
│   ├── adlists.txt      # Ad list sources
│   ├── whitelist.txt    # Whitelisted domains
│   ├── blacklist.txt    # Blacklisted domains
│   ├── regex_*.txt      # Regex filters
│   └── metadata.txt     # Export metadata
├── scripts/             # Sync scripts
│   ├── setup.sh
│   ├── export-config.sh
│   ├── import-config.sh
│   ├── auto-sync.sh
│   ├── install-service.sh
│   └── sync-now.sh
├── backup/              # Local backups (not synced)
├── docker-compose.example.yml
└── README.md
```

## How It Works

### Automatic Sync Flow

1. **Primary Instance**: `auto-sync.sh` monitors `gravity.db` for changes
2. **Change Detected**: When blocklists are updated, config is exported
3. **Git Commit**: Changes are committed and pushed to Git repository
4. **Secondary Instances**: Periodically pull from Git and import config
5. **Apply Changes**: Pi-hole is restarted with new configuration

### Manual Workflow

1. Update blocklists on primary Pi-hole (via web interface or CLI)
2. Run `./scripts/export-config.sh` to export and push to Git
3. On secondary instances, run `./scripts/import-config.sh` to pull and apply

## Troubleshooting

### Container Not Found
```bash
# List running containers
docker ps

# Set correct container name
export PIHOLE_CONTAINER=your-container-name
```

### Permission Denied
```bash
# Make scripts executable
chmod +x scripts/*.sh

# For systemd service
sudo ./scripts/install-service.sh
```

### Git Push Failed
```bash
# Check remote URL
git remote -v

# Configure credentials (if needed)
git config credential.helper store

# Or use SSH keys
git remote set-url origin git@github.com:user/repo.git
```

### Service Not Starting
```bash
# Check service status
sudo systemctl status pihole-sync

# View detailed logs
sudo journalctl -u pihole-sync -n 50

# Check script permissions
ls -la scripts/auto-sync.sh
```

### Import Failed - Database Locked
```bash
# Stop Pi-hole temporarily
docker exec pihole pihole disable

# Run import
./scripts/import-config.sh

# Re-enable Pi-hole
docker exec pihole pihole enable
```

## Best Practices

1. **Use SSH Keys**: For passwordless Git operations
2. **Private Repository**: Keep your Pi-hole config in a private repo
3. **Regular Backups**: Backups are created automatically in `backup/`
4. **Test First**: Test import on secondary before deploying to production
5. **Monitor Logs**: Check logs regularly for sync issues
6. **Stagger Cron**: Use different intervals for export/import to avoid conflicts

## Security Notes

- **Private Repository**: Pi-hole config may contain sensitive data (custom DNS, etc.)
- **Git Credentials**: Use SSH keys or credential helpers (avoid passwords in scripts)
- **Access Control**: Limit who can push to the repository
- **Backup Retention**: Old backups are kept for 10 iterations

## Advanced Configuration

### Multiple Primary Instances

If you have multiple instances where you update blocklists:

```bash
# Instance 1
PIHOLE_CONTAINER=pihole1 ./scripts/export-config.sh

# Instance 2 pulls and merges
git pull
PIHOLE_CONTAINER=pihole2 ./scripts/import-config.sh

# Then export from instance 2 if needed
PIHOLE_CONTAINER=pihole2 ./scripts/export-config.sh
```

### Custom Sync Intervals

```bash
# Fast sync (every minute)
CHECK_INTERVAL=60 ./scripts/auto-sync.sh

# Slow sync (every hour)
CHECK_INTERVAL=3600 ./scripts/auto-sync.sh
```

### Sync to Cloud Storage

```bash
# Add additional remote (e.g., backup to another Git server)
git remote add backup git@backup-server:pihole-sync.git

# Modify export-config.sh to push to both
git push origin main
git push backup main
```

## Contributing

Issues and pull requests are welcome!

## License

MIT License - feel free to use and modify as needed.
