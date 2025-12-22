# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

pp-back (Push/Pull Backup) is a POSIX shell script that performs incremental backups using rsync with hard-link deduplication. It supports both push (local to remote) and pull (remote to local) modes.

## Running Backups

```sh
./pp-back /path/to/config  # config file is config.ppb, extension omitted
./pp-back blink            # runs backup using blink.ppb config
```

## Configuration File Format (.ppb)

Configuration files use shell variable syntax and are sourced by the main script:

```sh
mode=push|pull           # push to remote or pull from remote
host=user@hostname       # remote host (empty string for local backups)
link=yes|no              # use hard-links to previous backup for deduplication
save=N                   # keep last N daily backups (first-of-month backups always kept)
delete=yes|no            # delete files no longer in source
prefix=/backup/path      # target directory for backups
data="/dir1 /dir2"       # space/newline-separated list of directories to backup
```

Config files can include pre/post backup hooks by checking `$ACTION`:
- `ACTION=PRE_BACKUP` - set when sourced before backup starts
- `ACTION=POST_BACKUP` - set when sourced after backup completes

## Exclude Files

Patterns can be placed in these files (rsync exclude format):
- `config.ppb.exclude` - alongside the config file
- `$source/config.ppb.exclude` - in each source directory root
- `$prefix/config.ppb.exclude` - in the target prefix directory
- `$prefix/config.ppb.$dirname.exclude` - per-source excludes at target

## Backup Directory Structure

Backups are stored as `YYYY.MMDD` directories under the prefix path. The `--link-dest` option creates hard links to up to 20 previous backups for space-efficient storage.

## Dependencies

The script requires: `/bin/sh`, `ssh`, `rsync`, `awk`, `mkdir`, `ls`, `date`, `echo`, `rm`, `basename`

## Browsing Backups (pp-browse)

A CGI script for browsing and retrieving backed-up files. See [PP-BROWSE.md](PP-BROWSE.md) for full documentation.

```sh
./pp-browse 8080              # Run standalone server on port 8080
# Browse to http://localhost:8080/cgi-bin/pp-browse
```

URL path format: `/<config>/<date>/<path>` (e.g., `/blink/2025.0101/home/user/file.txt`)

Features:
- Browse backup configs, dates, and directory trees
- Download individual files with proper mime types
- Download directories as tar.gz (`?tar` query parameter)
- Works with both push and pull mode configs via SSH
