# Qdumpfs

qdumpfs is a modified version of pdumpfs.

## Installation

gem install qdumpfs

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
    -c, --command=COMMAND            backup|sync|list|expire|verify|test
    -l, --limit=HOURS                limit hours
    -k, --keep=KEEPARG               ex: --keep 100Y12M12W30D (100years, 12months, 12weeks, 30days, default)
```

## Example

Backup your home directory, run the following command.
```
qdumpfs /home/foo /backup
```

You can specify command option(default is "backup").
```
qdumpfs --command=backup /home/foo /backup
```

Sync two backup directories.
```
qdumpfs --command=sync /backup1 /backup2
```

Sync two backup directories(limit 1 hours, keep 100Y12M12W30D).
```
qdumpfs --command=sync --limit=1 /backup1 /backup2
```

Sync two backup directories(limit 1 hours, keep specified backups only).
```
qdumpfs --command=sync --limit=1 --keep=5Y6M7W10D --keep/backup1 /backup2
```

Expire backup directory.
```
qdumpfs --command=expire --limit=1 --keep=5Y6M7W10D --keep/backup1 /backup2
```


## License

qdumpfs is a free software with ABSOLUTELY NO WARRANTY under the terms of the GNU General Public License version 2.




