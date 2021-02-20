# Qdumpfs

pdumpfsの個人的改良版です。

Gem化して最近のバージョンのバージョンのRubyに対応。コマンドの拡張などを行っています。

## インストール

gem install qdumpfs

## 使用方法

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

## 実行例


バックアップを実行する場合。

```
qdumpfs /home/foo /backup
```

"--command backup"オプションを明示することもできます。

```
qdumpfs --command=backup /home/foo /backup
```

"--command sync"でバックアップフォルダを同期できます。
```
qdumpfs --command=sync /backup1 /backup2
```

バックアップフォルダの同期には膨大な時間が必要な場合があるため、実行時間を制限できます。以下は例えば1時間に制限する場合です。
```
qdumpfs --command=sync --limit=1 /backup1 /backup2
```

バックアップフォルダの同期で、1時間でかつ"100Y12M12W30D"を保存する場合のオプションです。
```
qdumpfs --command=sync --limit=1 --keep=5Y6M7W10D backup1 /backup2
```

"--command expire"で、"--keep="パターンに該当しないバックアップを削除できます。
```
qdumpfs --command=expire --limit=1 --keep=5Y6M7W10D backup1 /backup2
```

"--command erase"で、バックアップに存在する指定したパスを削除できます(間違えてバックアップした内容を削除したい場合などに使用)。
```
qdumpfs --command=erase --limit=1 backup1 /backup2
```

## License

qdumpfs is a free software with ABSOLUTELY NO WARRANTY under the terms of the GNU General Public License version 2.


