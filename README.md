# pp-back

POSIX shell backup script using rsync with hard-link deduplication and GFS retention.

## Features

- Push (local→remote) or pull (remote→local) modes
- Hard-link deduplication via rsync `--link-dest`
- Three-tier retention: daily, monthly, yearly
- Dry-run mode (`-n`) to preview deletions
- Pre/post backup hooks

## Usage

```sh
./pp-back config      # run backup using config.ppb
./pp-back -n config   # dry-run (no changes, show what would be deleted)
```

## Configuration

Create a `.ppb` file:

```sh
# laptop.ppb - backup laptop to NAS
name=laptop
mode=push
host=backup@nas.local
prefix=/backups/laptop
data="/home/user /etc"
```

```sh
# server.ppb - pull from remote server
name=server
mode=pull
host=root@server.example.com
prefix=/backup/server
save=30
monthly=6
data="/etc /var/www /home"
```

```sh
# local.ppb - local backup (no network)
name=local
mode=pull
host=""
prefix=/mnt/backup
data="/home /etc"
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `mode` | - | `push` or `pull` |
| `host` | - | user@hostname (empty for local) |
| `prefix` | - | backup destination directory |
| `data` | - | space-separated source directories |
| `save` | 14 | daily backups to keep |
| `monthly` | 12 | monthly backups to keep |
| `link` | yes | use hard-link deduplication |
| `delete` | no | remove files deleted from source |

## Retention

Backups are stored as `YYYY.MMDD` directories. Retention tiers:

- **Yearly**: first backup of each year (kept forever)
- **Monthly**: first backup of each month (keep last `monthly`)
- **Daily**: all others (keep last `save`)

## Exclude Files

Place rsync exclude patterns in:
- `config.ppb.exclude` - alongside config file
- `$source/config.ppb.exclude` - in source directory root
- `$prefix/config.ppb.exclude` - in backup destination

## License

Public domain
