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
    -c, --command=COMMAND            backup|sync|list|expire|verify|delete
    -l, --limit=HOURS                limit hours
    -k, --keep=KEEPARG               ex: --keep 100Y12M12W30D (100years, 12months, 12weeks, 30days, default)
```

## 実行例

### バックアップ

バックアップを実行する場合。

「qdumpfs コピー元 コピー先」でバックアップを作成することができます。コピー先が存在する場合差分バックアップとなります。

```
qdumpfs /home/foo /backup
```

"--command backup"オプションを明示することもできます。

```
qdumpfs --command=backup /home/foo /backup
```

### バックアップフォルダの同期

バックアップフォルダを同期することもできます。バックアップディスクが手狭になり、新しいディスクに移行したい場合に便利です。

"--command sync"オプションを指定することでバックアップフォルダを同期できます。

```
qdumpfs --command=sync /backup1 /backup2
```

バックアップフォルダの同期には膨大な時間が必要な場合があるため、実行時間を制限できます。以下は例えば1時間に制限する場合です。

実行時間が1時間を超えるとそこで処理が終了しますそこから次回継続することができます。

```
qdumpfs --command=sync --limit=1 /backup1 /backup2
```

バックアップフォルダを間引きたい場合、"--keep="オプションを指定することができます。 "100Y12M12W30D"を指定すると、100年間は年に1つ、12ヶ月間は月に1つ、12週間は週に1つ、直近30日間のバックアップを保持します。
条件に該当しないバックアップは同期されません。

```
qdumpfs --command=sync --limit=1 --keep=5Y6M7W10D backup1 /backup2
```

### バックアップフォルダの削除

"--command expire"で、"--keep="パターンに該当しないバックアップを削除できます。
```
qdumpfs --command=expire --limit=1 --keep=5Y6M7W10D backup1 /backup2
```


### バックアップフォルダから指定パターンを削除

"--command delete"で、バックアップに存在する指定したパスを削除できます(間違えてバックアップした内容を削除したい場合などに使用)。
```
qdumpfs --command=delete --delete-dir=backup1 --limit=1  r:/backup2
```

## License

qdumpfs is a free software with ABSOLUTELY NO WARRANTY under the terms of the GNU General Public License version 2.


