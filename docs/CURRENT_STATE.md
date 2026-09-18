# ActingFor Current State

更新日：2026-09-18

## Source of Truth

正本は [GitHub `main`](https://github.com/cuichangquan/acting_for/tree/main)。このファイルは現在地点の短い案内板であり、設計・仕様の正本ではない。

詳細は [DECISIONS](DECISIONS.md)、[PROJECT](PROJECT.md)、各設計書（[Domain Model](domain_model_v0_1.md)、[Public API](public_api_v0_1.md)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)、[Security Model](security_model_v0_1.md)）を参照する。

## Implementation Baseline

Gem skeleton実装完了時点のcommit：

```text
c617e33ec06006f5122adf1134fd15f43c941360
feat: implement minimal gem skeleton
```

これは現在地点の基準commitであり、GitHub `main` の最新commitを意味しない。

New Chat開始時には必ずGitHub `main` の最新版を確認すること。

## Latest Decision

```text
D100
```

## Current Status

```text
Design substantially finalized
Gem skeleton implemented
Core authorization logic implementation not started

Migration files implemented (runtime DB execution not yet verified)
Model not implemented
Delegation API not implemented
Authorization not implemented
Audit not implemented
Test not implemented
CI not implemented
Runnable Quick Start not implemented

Not released
```

## Implemented

Migration files：

```text
db/migrate/
├── 20260918030001_create_acting_for_agents.rb
├── 20260918030002_create_acting_for_delegations.rb
└── 20260918030003_create_acting_for_audit_events.rb
```

Implemented schema follows the existing Domain Model decisions for columns, defaults, indexes, Foreign Key, and DB CHECK constraints.

Ruby syntax check completed for all 3 Migration files. PostgreSQLへのup / down実行確認はまだ行っていない。

Gem skeleton：

```text
acting_for.gemspec
Gemfile
Rakefile
LICENSE
lib/
├── acting_for.rb
└── acting_for/
    ├── version.rb
    └── engine.rb
```

Ruby 4.0.1 / Rails構成Gem 8.1.3.1で確認済み（対応matrix全体は未検証）：

```text
bundle install
require "acting_for"
ActingFor::VERSION == "0.1.0"
ActingFor::Engine < Rails::Engine
isolate_namespace ActingFor
gem build acting_for.gemspec
```

Engineのstandalone loadはD093をD094で修正し、`require "rails"` を使用する。

## Next Step

Migration runtime verification用の `test/dummy` は、D100で確定した最小構成だけを先行作成する。

まだDummy App自体は未実装。Model / Authorization / Auditロジック / Minitest本体 / CIにも進まない。

次に、Dummy AppでMigration検証に使用するRails versionを1項目として決める。

## Important Rules

- GitHub `main` を正本とする。
- 未決定事項を勝手に決定せず、ユーザーの「OK」「決定」等の明示承認で正式Decisionとする。
- 重要事項は1項目ずつ進める。
- 過去Decision番号をrenumberせず、過去Decisionを書き換えず、変更は後続Decisionとして残す。
- 過剰設計せず、問題がある案には懸念点を指摘する。
- このファイルに詳細仕様や過去の経緯を複製せず、必要な各正本ドキュメントを読む。
- 将来の更新はLatest Decision、Current Status、Implemented、Next Stepを中心に行い、短く保つ。Implementation Baselineは重要な区切りだけ更新する。

## New Chat Start

1. GitHub `main` の最新版を確認する。
2. `docs/CURRENT_STATE.md` で現在地点を確認する。
3. 必要な関連設計書だけ確認する。
4. Next Stepから重要事項を1項目だけ提案する。

いきなりコード実装を開始しない。
