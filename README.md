# Qdumpfs

**Language**: [English](#) | [日本語](README_ja.md)

Qdumpfs is an efficient incremental backup tool developed as a personal improvement of pdumpfs.

This tool modernizes pdumpfs as a Ruby Gem, supporting recent Ruby versions (Ruby 3.2+ compatible). It creates incremental backups with date-based directory structure (YYYY/MM/DD format), copying only changed files and using hard links for unchanged files to maximize storage efficiency.

## Features

- **Efficient Incremental Backup**: Copies only changed files, saves space with hard links for unchanged files
- **Date-based Management**: Organized backups in YYYY/MM/DD directory structure
- **Cross-platform Support**: Works on Windows/Unix/macOS environments
- **Ruby 3.2+ Compatible**: Supports latest Ruby versions (taint/untaint methods removed)
- **Rich Exclusion Options**: Flexible exclusion settings with regex patterns, file size, and glob patterns
- **Comprehensive Backup Management**: Sync, verify, delete, list and other management functions

## Installation

```bash
gem install qdumpfs
```

## Requirements

- **Ruby**: 3.0 or higher (Ruby 3.2+ compatible)
- **OS**: Windows, Linux, macOS
- **Dependencies**: Standard library only (no additional gems required)

## Usage

```
Usage: qdumpfs [options] <source> <dest>
    -h, --help                       show this message
Options
    -v, --verbose                    verbose message
    -r, --report                     report message
    -n, --dry-run                    don't actually run any commands
    -e, --exclude=PATTERN            exclude files/directories matching PATTERN
    -s, --exclude-by-size=SIZE       exclude files larger than SIZE
    -w, --exclude-by-glob=GLOB       exclude files matching GLOB
    -c, --command=COMMAND            backup|sync|list|expire|verify|delete
    -l, --limit=HOURS                limit hours
    -k, --keep=KEEPARG               ex: --keep 100Y12M12W30D (100years, 12months, 12weeks, 30days, default)
```

## Examples

### Backup

To perform a backup operation:

You can create a backup with `qdumpfs source destination`. If the destination exists, it becomes an incremental backup.

```bash
qdumpfs /home/foo /backup
```

You can also explicitly specify the `--command backup` option:

```bash
qdumpfs --command=backup /home/foo /backup
```

### Backup Folder Synchronization

You can also synchronize backup folders. This is useful when your backup disk becomes tight and you want to migrate to a new disk.

You can synchronize backup folders by specifying the `--command sync` option:

```bash
qdumpfs --command=sync /backup1 /backup2
```

Since synchronization of backup folders may require an enormous amount of time, you can limit the execution time. For example, to limit to 1 hour:

When the execution time exceeds 1 hour, the process ends there and can be resumed from there next time.

```bash
qdumpfs --command=sync --limit=1 /backup1 /backup2
```

When you want to thin out backup folders, you can specify the `--keep=` option. Specifying "100Y12M12W30D" will keep one backup per year for 100 years, one per month for 12 months, one per week for 12 weeks, and all backups for the last 30 days. Backups that don't meet these conditions will not be synchronized.

```bash
qdumpfs --command=sync --limit=1 --keep=5Y6M7W10D backup1 /backup2
```

To sync only the first backup of each year (e.g., for long-term archiving), set month, week, and day retention to 0:

```bash
qdumpfs --command=sync --keep=100Y0M0W0D /backup1 /backup2
```

This keeps the first backup per year for the last 100 years, while skipping monthly, weekly, and daily backups. Only backups matching the `--keep` retention policy are selected for synchronization.

Backup synchronization is performed by selecting source backups newer than the latest date in the destination. This allows backup synchronization to resume if interrupted midway.

For example, if a backup from 2024/11/01 exists in the destination, and there is backup data after 2024/11/01 in the source (e.g., 2024/11/02), it will be synchronized (backups with the same date are not synchronized).

### Backup Folder Deletion

With `--command expire`, you can delete backups that don't match the `--keep=pattern`.

```bash
qdumpfs --command=expire --limit=1 --keep=5Y6M7W10D backup1 /backup2
```

### Delete Specified Patterns from Backup Folders

With `--command delete`, you can delete specified paths that exist in backups (useful for deleting content that was mistakenly backed up).

```bash
qdumpfs --command=delete --delete-dir=backup1 --limit=1 r:/backup2
```

### Backup Comparison

You can compare backups with `--command verify`:

```bash
qdumpfs --command=verify j:/backup/2024/11/01 k:/backup/2024/11/01
```

### Backup File Listing

You can list backup files with `--command list`:

```bash
qdumpfs --command=list j:/backup/2024/11/01
```

For example, if verify shows different results, you can diff the list results:

```bash
qdumpfs --command=list j:/backup/2024/11/01
qdumpfs --command=list k:/backup/2024/11/01
diff list_j__backup_2024_11_01.txt list_k__backup_2024_11_01.txt
```

## How Backup Works

Qdumpfs achieves efficient backup through the following mechanisms:

### Directory Structure

```
backup_destination/
├── 2024/
│   ├── 01/
│   │   ├── 15/  # Backup from January 15, 2024
│   │   └── 16/  # Backup from January 16, 2024
│   └── 02/
│       └── 01/  # Backup from February 1, 2024
└── latest -> 2024/02/01  # Symbolic link to latest backup
```

### Incremental Backup

- **New files**: Full copy from source to destination
- **Modified files**: Overwrite copy with latest content
- **Unchanged files**: Create hard link from previous backup (saves space)
- **Deleted files**: Not deleted from backup, preserved as history

### Retention Policy

The `--keep` option allows fine-grained control of backup retention periods:

- `Y` (Years): Retention by year
- `M` (Months): Retention by month
- `W` (Weeks): Retention by week
- `D` (Days): Retention by day

Example: `--keep=5Y12M12W30D`
- For 5 years: Keep one backup per year
- For last 12 months: Keep one backup per month
- For last 12 weeks: Keep one backup per week
- For last 30 days: Keep all backups

## Development & Testing

```bash
# Run tests
./test.sh

# Run specific test file
./test.sh test/qdumpfs_test.rb

# Install dependencies
bundle install

# Build gem
bundle exec rake build
```

## Contributing

Bug reports and feature requests are welcome at [GitHub Issues](https://github.com/src256/qdumpfs/issues).

## License

qdumpfs is a free software with ABSOLUTELY NO WARRANTY under the terms of the GNU General Public License version 2.