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
D096
```

## Current Status

```text
Design substantially finalized
Gem skeleton implemented
Core feature implementation not started

Migration not implemented
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

Migration implementationへ進む前提条件として、3 Migrationの互換バージョンは `ActiveRecord::Migration[8.0]` に統一する（D096）。

次に、Migration実装へ入るかどうかを1項目として判断する。実装する場合も対象はD095の3テーブルに限定し、Model / Authorization / Auditロジック / Test / CIへは進まない。

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
