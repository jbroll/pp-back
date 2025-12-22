# pp-browse

CGI script for browsing and retrieving files from pp-back backups.

## Features

- Browse backup configurations, dates, and directory trees
- Download files directly from backups
- Download directories as tar.gz archives
- Works with both push (remote) and pull (local) backup modes
- Uses SSH for remote access (same as pp-back)
- Mime type detection for common file extensions

## Dependencies

Same minimal dependencies as pp-back: `/bin/sh`, `ssh`, `ls`, `cat`, `awk`, `cut`, `basename`, `dirname`, `tar`, `gzip`

## URL Path Format

```
/pp-browse                              # list available configs
/pp-browse/<config>                     # list backup dates
/pp-browse/<config>/<date>              # list backed-up directories
/pp-browse/<config>/<date>/<path>       # browse directory or download file
/pp-browse/<config>/<date>/<path>?tar   # download directory as tar.gz
```

Examples:
```
/cgi-bin/pp-browse                      # show blink, laptop, etc.
/cgi-bin/pp-browse/blink                # show 2025.1221, 2025.1220, etc.
/cgi-bin/pp-browse/blink/2025.1221      # show /home, /etc, etc.
/cgi-bin/pp-browse/blink/2025.1221/home/user/doc.pdf   # download file
/cgi-bin/pp-browse/blink/2025.1221/home?tar            # download /home as tar.gz
```

## Configuration

Set `CONFIG_DIR` at the top of the script or via environment variable:

```sh
CONFIG_DIR="/path/to/ppb/configs"
```

The script reads `.ppb` config files to determine:
- `mode` - push or pull
- `host` - remote host for SSH (empty for local)
- `prefix` - backup directory location

## Deployment

### Apache

```apache
ScriptAlias /pp-browse /path/to/pp-browse
<Location /pp-browse>
    SetEnv CONFIG_DIR /path/to/configs
</Location>
```

### lighttpd

```lighttpd
alias.url += ( "/pp-browse" => "/path/to/pp-browse" )
cgi.assign = ( "/pp-browse" => "" )
setenv.add-environment = ( "CONFIG_DIR" => "/path/to/configs" )
```

### Manual Testing

```sh
cd /path/to/pp-back
SCRIPT_NAME="/cgi-bin/pp-browse" PATH_INFO="" ./pp-browse
SCRIPT_NAME="/cgi-bin/pp-browse" PATH_INFO="/blink" ./pp-browse
SCRIPT_NAME="/cgi-bin/pp-browse" PATH_INFO="/blink/2025.1221" ./pp-browse
```

## Security

- Path traversal blocked (`..` rejected)
- Config names validated (alphanumeric, dash, underscore only)
- Date format validated (`YYYY.MMDD` pattern only)
- Config files must exist in `CONFIG_DIR`

## Mime Types

Files are served with appropriate Content-Type based on extension:

| Extensions | Mime Type |
|------------|-----------|
| `.html`, `.htm` | text/html |
| `.css` | text/css |
| `.js` | application/javascript |
| `.json` | application/json |
| `.pdf` | application/pdf |
| `.png`, `.jpg`, `.gif`, `.svg`, `.webp` | image/* |
| `.txt`, `.log`, `.md`, `.sh` | text/plain |
| `.zip`, `.tar`, `.gz`, `.bz2`, `.xz` | application/* |
| other | application/octet-stream |
