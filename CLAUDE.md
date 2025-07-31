# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

QdumpfsはpdumpfsのRuby Gem改良版で、差分バックアップツールです。指定されたディレクトリを日付ベース（YYYY/MM/DD形式）でバックアップし、変更されたファイルのみをコピーする効率的なバックアップシステムを提供します。

## 開発コマンド

### テスト実行
```bash
# 全テスト実行
./test.sh
# または
bundle exec rake test

# 特定のテストファイル実行
./test.sh test/qdumpfs_test.rb
```

### Gem関連
```bash
# 依存関係インストール
bundle install

# Gemビルド
bundle exec rake build

# Gem公開（注意: メタデータで制限されている場合あり）
bundle exec rake release
```

## コード構造

### メインコンポーネント

- **exe/qdumpfs**: エントリーポイント実行ファイル
- **lib/qdumpfs.rb**: メインモジュールとCommandクラス
- **lib/qdumpfs/option.rb**: オプション解析とBackupDirクラス
- **lib/qdumpfs/util.rb**: ユーティリティ関数群
- **lib/qdumpfs/win32.rb**: Windows固有の機能
- **lib/qdumpfs/version.rb**: バージョン情報

### 主要機能

1. **backup**: 差分バックアップ作成（デフォルト）
2. **sync**: バックアップフォルダ間の同期
3. **list**: バックアップ内容の一覧表示
4. **verify**: バックアップの検証
5. **expire**: 保持ポリシーに基づく古いバックアップの削除
6. **delete**: 指定パターンの削除

### バックアップの仕組み

- 日付ベースディレクトリ構造: `dest/YYYY/MM/DD/`
- 差分バックアップ: 変更されたファイルのみコピー、未変更ファイルはハードリンク
- `latest`シンボリックリンクで最新バックアップを指示
- Windows/Unix両対応

### 除外機能

- `--exclude=PATTERN`: 正規表現パターンで除外
- `--exclude-by-size=SIZE`: ファイルサイズで除外  
- `--exclude-by-glob=GLOB`: Globパターンで除外

## 注意点

- Ruby 3.2系対応済み（taint/untaintメソッド削除対応済み）
- クロスプラットフォーム対応（Windows/Unix）
- ファイルシステムの容量不足時の不完全バックアップ処理対応