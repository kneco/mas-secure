# ai-enclave

AIエージェントのためのセキュアな隔離開発環境。Dockerコンテナにより、エージェントの影響範囲をコンテナ内に限定する。

## これは何？

AI支援開発のための事前構成済みDocker環境。コンテナ内にリポジトリをcloneし、Claude Code等のAIツールで安全に作業できる。ホストのファイルシステムには触れない（読み取り専用のデータ投入口を除く）。

## プリインストール済みツール

| ツール | バージョン | 用途 |
|--------|-----------|------|
| Claude Code CLI | latest | AIコーディングアシスタント |
| code-server | latest | ブラウザベースVS Code (port 8080) |
| GitHub CLI (gh) | latest | GitHub操作 |
| Bitwarden CLI (bw) | latest | シークレット管理 |
| Node.js | 22.x | JavaScriptランタイム |
| Python 3 | system | スクリプト・自動化 |
| tmux | system | ターミナルマルチプレクサ |
| git | system | バージョン管理 |
| ripgrep, fd, fzf, jq | system | 検索・データ処理 |

## クイックスタート

### Windows (bat)

```bat
setup4win.bat
```

ダブルクリックで intel ディレクトリ作成 → Docker ビルド → コンテナ起動まで自動実行。

### 手動

```bash
# 1. ビルド & 起動
docker compose build
docker compose up -d

# 2. コンテナに入る
docker exec -it ai-enclave bash

# 3. プロジェクトをclone
git clone https://github.com/<user>/<repo> /workspace/<repo>
cd /workspace/<repo>

# 4. Claude Code認証（初回のみ）
claude

# 5. code-server起動（任意）
code-server --bind-addr 0.0.0.0:8080 /workspace
# ブラウザで http://localhost:8080 を開く
```

## ボリューム構成

| ボリューム | 種別 | 用途 |
|-----------|------|------|
| `enclave-workspace` | 名前付き | プロジェクトファイル（コンテナ専用） |
| `enclave-claude-config` | 名前付き | ~/.claude 設定永続化 |
| `/intel` | bind (読み取り専用) | ホストからのデータ投入口 |

## セキュリティ

ホスト上で直接AIエージェントを動かす場合と比較して：

- **ファイルシステム隔離**: `/intel`（読み取り専用）以外のホストファイルにアクセス不可
- **非rootユーザー**: `agent` (UID 1000) で実行
- **no-new-privileges**: 権限昇格を防止
- **名前付きボリューム**: ワークスペースはホストから不可視 — ホストファイルの誤操作を防止
- **読み取り専用intel**: データ入力は一方向（ホスト → コンテナ）

## ホスト側ユーティリティ

| ファイル | 用途 |
|---------|------|
| `setup4win.bat` | Windowsセットアップ（intel作成 → ビルド → 起動） |
| `scripts/ntfy_toast.ps1` | ntfy.sh経由のWindows toast通知受信 (PowerShell 5.1+) |

## イメージ配布

```bash
# GitHub Container Registry
docker build -t ghcr.io/<user>/ai-enclave:latest .
docker push ghcr.io/<user>/ai-enclave:latest
```
