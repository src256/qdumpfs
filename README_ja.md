# Qdumpfs

**Language**: [English](README.md) | [日本語](#)

Qdumpfsは、pdumpfsの個人的改良版として開発された効率的な差分バックアップツールです。

pdumpfsをRuby Gemとして現代化し、最近のRubyバージョン（Ruby 3.2系対応）に対応しています。日付ベース（YYYY/MM/DD形式）のディレクトリ構造で差分バックアップを作成し、変更されたファイルのみをコピーして、未変更ファイルはハードリンクを利用することで、ストレージ効率を最大化します。

## 特徴

- **効率的な差分バックアップ**: 変更されたファイルのみをコピーし、未変更ファイルはハードリンクで容量を節約
- **日付ベース管理**: YYYY/MM/DD形式のディレクトリ構造で整理されたバックアップ
- **クロスプラットフォーム対応**: Windows/Unix/macOS環境での動作をサポート
- **Ruby 3.2系対応**: 最新のRubyバージョンに対応（taint/untaintメソッド削除済み）
- **豊富な除外オプション**: 正規表現、ファイルサイズ、Globパターンによる柔軟な除外設定
- **バックアップ管理機能**: 同期、検証、削除、一覧表示など包括的な管理機能

## インストール

```bash
gem install qdumpfs
```

## 動作環境

- **Ruby**: 3.0以上（Ruby 3.2系対応済み）
- **OS**: Windows、Linux、macOS
- **依存関係**: 標準ライブラリのみ（追加のgemは不要）

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

`qdumpfs コピー元 コピー先`でバックアップを作成することができます。コピー先が存在する場合差分バックアップとなります。

```
qdumpfs /home/foo /backup
```

`--command backup`オプションを明示することもできます。

```
qdumpfs --command=backup /home/foo /backup
```

### バックアップフォルダの同期

バックアップフォルダを同期することもできます。バックアップディスクが手狭になり、新しいディスクに移行したい場合に便利です。

`--command sync`オプションを指定することでバックアップフォルダを同期できます。

```
qdumpfs --command=sync /backup1 /backup2
```

バックアップフォルダの同期には膨大な時間が必要な場合があるため、実行時間を制限できます。以下は例えば1時間に制限する場合です。

実行時間が1時間を超えるとそこで処理が終了しますそこから次回継続することができます。

```
qdumpfs --command=sync --limit=1 /backup1 /backup2
```

バックアップフォルダを間引きたい場合、`--keep=`オプションを指定することができます。"100Y12M12W30D"を指定すると、100年間は年に1つ、12ヶ月間は月に1つ、12週間は週に1つ、直近30日間のバックアップを保持します。条件に該当しないバックアップは同期されません。

```
qdumpfs --command=sync --limit=1 --keep=5Y6M7W10D backup1 /backup2
```

バックアップの同期は、コピー先の最新の日付より新しいコピー元を選択して実行されます。これはバックアップの同期が途中で中断された場合、再開することができるようにするためです。

例えばコピー先に2024/11/01のバックアップが存在する場合、コピー元の2024/11/01より後のバックアップデータ(例えば2024/11/02)があれば、それが同期されます(同じ日付は同期されません)。




### バックアップフォルダの削除

`--command expire`で、`--keep=パターン`に該当しないバックアップを削除できます。


```
qdumpfs --command=expire --limit=1 --keep=5Y6M7W10D backup1 /backup2
```

### バックアップフォルダから指定パターンを削除

`--command delete`で、バックアップに存在する指定したパスを削除できます(間違えてバックアップした内容を削除したい場合などに使用)。


```
qdumpfs --command=delete --delete-dir=backup1 --limit=1  r:/backup2
```

### バックアップの比較

`--command verify`でバックアップを比較することができます。

```
qdumpfs  --command=verify j:/backup/2024/11/01 k:/backup/2024/11/01
```

### バックアップファイルの一覧

`--command list`でバックアップファイルを一覧表示することができます。

```
qdumpfs  --command=list j:/backup/2024/11/01 
```

例えばverifyで異なる結果が表示された場合、listした結果をdiffすることができます。

```
qdumpfs  --command=list j:/backup/2024/11/01 
qdumpfs  --command=list k:/backup/2024/11/01 
diff list_j__backup_2024_11_01.txt list_k__backup_2024_11_01.txt
```

## バックアップの仕組み

Qdumpfsは以下の仕組みで効率的なバックアップを実現しています：

### ディレクトリ構造

```
バックアップ先/
├── 2024/
│   ├── 01/
│   │   ├── 15/  # 2024年1月15日のバックアップ
│   │   └── 16/  # 2024年1月16日のバックアップ
│   └── 02/
│       └── 01/  # 2024年2月1日のバックアップ
└── latest -> 2024/02/01  # 最新バックアップへのシンボリックリンク
```

### 差分バックアップ

- **新規ファイル**: コピー元からコピー先へ完全コピー
- **変更されたファイル**: 最新の内容で上書きコピー
- **未変更ファイル**: 前回のバックアップからハードリンクを作成（容量節約）
- **削除されたファイル**: バックアップからは削除されず履歴として保持

### 保持ポリシー

`--keep`オプションでバックアップの保持期間を細かく制御できます：

- `Y` (Years): 年単位での保持
- `M` (Months): 月単位での保持  
- `W` (Weeks): 週単位での保持
- `D` (Days): 日単位での保持

例: `--keep=5Y12M12W30D`
- 5年間: 年に1つのバックアップを保持
- 直近12ヶ月: 月に1つのバックアップを保持
- 直近12週間: 週に1つのバックアップを保持
- 直近30日間: 全てのバックアップを保持

## 開発・テスト

```bash
# テスト実行
./test.sh

# 特定のテストファイル実行
./test.sh test/qdumpfs_test.rb

# 依存関係インストール
bundle install

# Gemビルド
bundle exec rake build
```

## 貢献

バグ報告や機能要望は[GitHub Issues](https://github.com/src256/qdumpfs/issues)まで。

## License

qdumpfs is a free software with ABSOLUTELY NO WARRANTY under the terms of the GNU General Public License version 2.


