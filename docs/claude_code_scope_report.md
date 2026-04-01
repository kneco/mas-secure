# Claude Code スキル・設定配置戦略 調査レポート

作成日: 2026-04-01
改訂日: 2026-04-01（subtask_249a1: 具体例追加）
作成者: ashigaru1
対象: ai-enclave Docker環境でのClaude Code設定・スキル管理

---

## 1. Claude Code 設定階層まとめ

Claude Codeは4階層のスコープシステムを採用している。

| スコープ | 場所 | 対象 | チーム共有 |
|----------|------|------|-----------|
| **Managed** | `/Library/Application Support/ClaudeCode/` / `/etc/claude-code/` / `C:\Program Files\ClaudeCode\` | マシン上の全ユーザー | Yes (IT展開) |
| **User** | `~/.claude/` | 自分、全プロジェクト横断 | No |
| **Project** | `.claude/`（リポジトリ内） | そのリポジトリの全コラボレーター | Yes (git管理) |
| **Local** | `.claude/settings.local.json` | 自分、このリポジトリのみ | No (gitignore推奨) |

### 各階層に置けるもの

**プロジェクトレベル（`.claude/`）:**
- `CLAUDE.md` — プロジェクト固有の指示
- `settings.json` — プロジェクト共有設定
- `settings.local.json` — ローカルのみ設定（gitignore）
- `skills/` — プロジェクトスキル（チーム共有）
- `rules/` — ファイル種別ごとのスコープ指示
- `agents/` — カスタムエージェント定義

**ユーザーレベル（`~/.claude/`）:**
- `CLAUDE.md` — 個人の永続的な指示・好み
- `skills/` — 個人スキル（全プロジェクト横断）
- `rules/` — 個人ルール（全プロジェクト横断）
- `projects/<project>/memory/` — プロジェクト別自動メモリ

**CLAUDE.md の多層配置:**
- `~/.claude/CLAUDE.md` — ユーザーレベル（個人設定）
- `./CLAUDE.md` または `./.claude/CLAUDE.md` — プロジェクトレベル（チーム共有）
- サブディレクトリの `CLAUDE.md` はオンデマンドで読み込み
- ワーキングディレクトリから上位に向かって探索、より具体的なものが優先

### ai-enclave 環境での具体例

- **Managed** (エンタープライズ): ai-enclaveでは使用しない
  （理由: 個人開発環境のため組織IT展開不要）

- **User** (`~/.claude/`):
  - `~/.claude/CLAUDE.md` → 「戦国口調で応答せよ。コードは必ずテストを書け。」
  - `~/.claude/skills/secret-daemon/` → 全プロジェクトで使うシークレット管理スキル

- **Project** (`.claude/`):
  - `/workspace/multi-agent-shogun/.claude/CLAUDE.md` → 将軍府固有の指示
  - `/workspace/multi-agent-shogun/.claude/skills/upstream-sync/` → このプロジェクト固有スキル

- **Local** (`.claude/settings.local.json`): gitignore対象
  - 例: ローカル固有のAPIキーパス、ローカルのみのデバッグ設定

---

## 2. スキルのスコープ管理方法

### スキルの配置場所とスコープ

個々のスキルのディレクトリ構造:
```
<location>/skills/
└── <skill-name>/
    ├── SKILL.md       (必須)
    ├── template.md    (任意)
    ├── examples/
    └── scripts/
```

| 配置場所 | スコープ | 用途 |
|----------|----------|------|
| `~/.claude/skills/<name>/` | 全プロジェクト（個人） | 個人ワークフロー |
| `.claude/skills/<name>/` | このプロジェクト（チーム共有） | プロジェクト固有操作 |
| `<plugin>/skills/<name>/` | プラグイン経由（`plugin-name:skill-name`） | プラグイン提供スキル |
| Managed配置 | 組織全体 | 企業ポリシー |

**優先度**: Enterprise > Personal > Project
同名スキルが複数ある場合、高優先度が低優先度を上書き。

### ai-enclave 実在スキルの配置例

| 配置場所 | スキル例（ai-enclave実在） |
|----------|--------------------------|
| `~/.claude/skills/` | `secret-daemon`（全プロジェクト共通Bitwarden管理） |
| `~/.claude/skills/` | `gh-secure`（全プロジェクト共通GitHub認証） |
| `/workspace/multi-agent-shogun/.claude/skills/` | `upstream-sync`（shogun固有） |
| `/workspace/multi-agent-shogun/.claude/skills/` | `generative-content-creator` |
| `/workspace/multi-agent-shogun/.claude/skills/` | `slide-creator` |

### リポジトリ横断での共有方法

`.claude/rules/` ディレクトリで**シンボリックリンク**をサポート:
```bash
ln -s ~/shared-claude-rules .claude/rules/shared
```
- 循環シンボリックリンクは自動検出・無視
- `~/.claude/rules/` は全プロジェクトに自動適用
- これによりDockerコンテナ内で複数リポジトリ間のルール共有が可能

### モノレポサポート

ネストされた `.claude/skills/` ディレクトリを自動発見:
```
packages/
├── frontend/.claude/skills/   ← 自動発見
└── backend/.claude/skills/    ← 自動発見
```

### /init が生成するもの

`/init` コマンドの動作:
1. コードベースを分析
2. `CLAUDE.md` を生成（ビルドコマンド、テスト手順、プロジェクト規約）
3. 既存の `CLAUDE.md` がある場合は改善提案のみ

`CLAUDE_CODE_NEW_INIT=1` 環境変数設定時（拡張モード）:
- インタラクティブな多フェーズフロー
- セットアップ対象を選択: CLAUDE.mdファイル、スキル、フック
- サブエージェントがコードベースを探索
- ファイル書き込み前にレビュー可能なプロポーザルを提示

---

## 3. Docker環境での永続化の注意点

### `~/.claude/` を named volume で永続化した場合の挙動

**自動メモリの保存場所:**
```
~/.claude/projects/<git-repo-path>/memory/
├── MEMORY.md   (インデックス)
└── *.md        (トピック別メモリファイル)
```

- gitリポジトリのパスから自動的に派生
- named volumeに `~/.claude/` をマウントすることで、コンテナ再起動後もメモリが永続化
- 同一リポジトリの全ワークツリーが1つのメモリディレクトリを共有

**永続化される内容（named volume使用時）:**
- ユーザーレベルスキル（`~/.claude/skills/`）
- ユーザーレベル設定（`~/.claude/settings.json`等）
- 全リポジトリの自動メモリ
- ユーザーレベルルール

**永続化されない内容（プロジェクトディレクトリに残る）:**
- プロジェクトスキル（`.claude/skills/`）
- プロジェクト設定（`.claude/settings.json`）
- ローカル設定（`.claude/settings.local.json`）

### コンテナ内で複数リポジトリを扱う場合の設定管理

**具体的なディレクトリツリー例（multi-agent-shogunとblast-reversi2を両方clone）:**

```
/workspace/
├── multi-agent-shogun/
│   ├── CLAUDE.md
│   └── .claude/
│       └── skills/upstream-sync/
├── blast-reversi2/
│   └── CLAUDE.md
└── research-archive/
```

**メモリの分離（`~/.claude/` = named volume `enclave-claude-config`）:**
```
~/.claude/projects/
├── -workspace-multi-agent-shogun/memory/MEMORY.md
├── -workspace-blast-reversi2/memory/MEMORY.md
└── -workspace-research-archive/memory/MEMORY.md
```

各リポジトリはパスをキーとしてメモリが自動分離される。同一コンテナ内での設定共有方法:

```bash
# 共有ルールをシンボリックリンクで各リポジトリに適用
ln -s ~/.claude/rules/shared-rules /project-a/.claude/rules/shared
ln -s ~/.claude/rules/shared-rules /project-b/.claude/rules/shared
```

**`autoMemoryDirectory` 設定の活用:**
- メモリ保存先をカスタム変更可能
- `policy`、`local`、`user` 設定から受け付ける
- **`project` 設定からは受け付けない**（共有プロジェクトが意図しない場所に書き込むリスク防止）
- 多数プロジェクトを管理する場合にメモリを一元管理できる

---

## 4. ai-enclave 推奨配置案（main/shogunate 切り分け）

### 前提

- `ai-enclave` = セキュアなAIエージェント開発環境（Docker）
- `main` ブランチ = 汎用環境
- `shogunate` ブランチ = multi-agent-shogun 拡張環境

### 推奨構成

#### main ブランチ（汎用環境）

```
ai-enclave/
├── .claude/
│   ├── CLAUDE.md          ← コンテナ環境の基本指示（Docker操作、セキュリティ制約等）
│   ├── settings.json      ← 汎用設定（タイムアウト、許可ツール等）
│   └── skills/
│       ├── docker-build/  ← Dockerビルド・デプロイ操作
│       └── enclave-init/  ← 環境初期化スキル
```

**`~/.claude/` (named volume `enclave-claude-config` にマウント):**
```
~/.claude/
├── CLAUDE.md              ← 個人の永続指示（言語設定、スタイル等）
├── settings.json          ← ユーザーレベル設定
└── skills/
    └── common-dev/        ← 汎用開発スキル（全リポジトリ横断）
```

#### shogunate ブランチ（multi-agent-shogun 拡張）

```
ai-enclave/
├── .claude/
│   ├── CLAUDE.md          ← shogunate固有の指示（エージェント構成、通信プロトコル等）
│   ├── settings.json      ← shogunate設定（追加許可ツール等）
│   └── skills/
│       ├── docker-build/  ← (main継承 or シンボリックリンク)
│       ├── agent-deploy/  ← マルチエージェント展開スキル
│       └── shogun-ops/    ← 将軍系操作スキル
```

### 実在ファイルの配置先テーブル

| ファイル/スキル | 配置 | 理由 |
|----------------|------|------|
| `scripts/secret_daemon*.py/sh` | main (ai-enclave) | 汎用シークレット管理 — 全プロジェクトで必要 |
| `scripts/gh_secure.sh` | main (ai-enclave) | 汎用GitHub認証 — multi-agent-shogun固有ではない |
| `scripts/ntfy_toast.ps1` | main (ai-enclave) | 汎用通知 — 既にmainにある |
| `skills/generative-content-creator/` | shogunate (`.claude/skills/`) | 幕府コンテンツ生成、汎用とは言えない |
| `skills/slide-creator/` | shogunate (`.claude/skills/`) | 同上 |
| `CLAUDE.local.md`（幕府ルール） | shogunate (`CLAUDE.md` or `.claude/`) | 幕府固有の運用ルール |
| `intel/migration/` | shogunate | 幕府移植パッケージ |
| `skills/upstream-sync/` | shogunate (`.claude/skills/`) | multi-agent-shogun固有のsync操作 |

### `enclave-claude-config` ボリュームに保存されるもの

named volume `enclave-claude-config` が `~/.claude/` にマウントされた場合:

| 保存対象 | パス | 用途 |
|---------|------|------|
| ユーザー設定 | `~/.claude/settings.json` | 全プロジェクト共通設定 |
| ユーザー指示 | `~/.claude/CLAUDE.md` | 個人の永続ルール |
| 個人スキル | `~/.claude/skills/` | 汎用スキル（main/shogunate共通） |
| 自動メモリ(main) | `~/.claude/projects/<ai-enclave-main>/memory/` | mainブランチの文脈 |
| 自動メモリ(shogunate) | `~/.claude/projects/<ai-enclave-shogunate>/memory/` | shogunateブランチの文脈 |

### 切り分けの基本方針

| 分類 | 配置場所 | 理由 |
|------|----------|------|
| 汎用スキル（Docker操作等） | `~/.claude/skills/` | main/shogunate両ブランチで共有 |
| 環境固有スキル | ブランチの `.claude/skills/` | ブランチ別にバージョン管理 |
| セキュリティポリシー | `~/.claude/CLAUDE.md` または Managed | 全環境に強制適用 |
| プロジェクト固有指示 | `.claude/CLAUDE.md` | ブランチごとの文脈 |

### workspace → projects 改称の検討

- Claude Code公式ドキュメントは `projects/` という用語を使う（プロジェクトディレクトリ群の格納場所）
- 現在のdocker-compose.yml: `enclave-workspace` ボリューム → `/workspace` にマウント
- Claude Codeが複数リポジトリを扱う場合のデファクト: `/home/<user>/projects/` または `/workspace/`
- **推奨**: `/workspace` のままで問題なし（Claude Codeは場所に依存しない）。ただし利用者が複数リポジトリを置く場合は `workspace` の方が直感的（"作業場"の意味）。`projects` への改称は任意。
- docker-compose.ymlの変更が必要な場合はshogunate設計時に検討。

---

## 5. 情報源一覧

| # | タイトル | URL |
|---|---------|-----|
| 1 | Claude Code Overview | https://docs.anthropic.com/en/docs/claude-code/overview |
| 2 | Claude Code Settings (公式) | https://code.claude.com/docs/en/settings |
| 3 | Claude Code Memory (公式) | https://code.claude.com/docs/en/memory |
| 4 | Claude Code Slash Commands / Skills (公式) | https://code.claude.com/docs/en/slash-commands |

---

*本レポートはClaude Code公式ドキュメント（2026-04-01取得）に基づく。*
