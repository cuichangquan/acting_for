# ActingFor Current State

更新日：2026-09-18

## Source of Truth

正本は [GitHub `main`](https://github.com/cuichangquan/acting_for/tree/main)。このファイルは現在地点の短い案内板であり、設計・仕様の正本ではない。

全体進捗は [PROGRESS](PROGRESS.md)を参照。詳細は [DECISIONS](DECISIONS.md)、[PROJECT](PROJECT.md)、各設計書（[Domain Model](domain_model_v0_1.md)、[Public API](public_api_v0_1.md)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)、[Security Model](security_model_v0_1.md)）を参照する。

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
D217
```

## Current Status

```text
Design substantially finalized
Gem skeleton implemented
Migration implemented and runtime verified
Minimal Dummy Rails App implemented for migration verification
Docker migration verification environment implemented
ActiveRecord Models implemented and Docker verified
Delegation Public API implementation design finalized
Delegation API implemented
Decision implemented
Authorization core implemented
ActingFor.authorize Public Entry Point not implemented
ConstraintEvaluator implemented
Audit authorization integration not implemented
Minitest test suite not implemented
CI not implemented
Runnable Quick Start not implemented

Not released
```

## Implemented

Authorization core：`app/services/acting_for/internal/authorization.rb`。D216どおり、DBでagent / principal / action / resource_type / active stateの候補を絞り、Ruby側でResource scopeとConstraintEvaluatorを評価してmatching Delegationを確定し、`require_approval > allow > deny` でDecisionを生成する。`ActingFor.authorize(...)` Public Entry PointとAuditEvent保存はまだ未実装。正式Minitest suite / CIは未実装のため、この反映ではruntime verificationは行っていない。

ConstraintEvaluator：`app/services/acting_for/internal/constraint_evaluator.rb`。D214・D215と既存Constraint仕様どおり、`eq` / `lt` / `lte` / `gt` / `gte` / `in`、複数条件AND、strict type、missing / nil不成立、invalid constraint fail-closed、トップレベルSymbol key厳密参照を実装した。`ActingFor.authorize(...)` / Authorization / Audit integration / DB queryには進んでいない。正式Minitest suite / CIは未実装のため、この反映ではruntime verificationは行っていない。

Decision Value Object：`lib/acting_for/decision.rb`。D213どおり、`:allow` / `:deny` / `:require_approval` の3 status、`status` / `allowed?` / `denied?` / `approval_required?` の4 Public API、初期化後freeze、不正statusの `ArgumentError` を実装した。`lib/acting_for.rb` からrequireする。正式Minitest suite / CIは未実装のため、この反映ではruntime verificationは行っていない。

Delegation Public API：`lib/acting_for.rb` の `ActingFor.delegate(...)`、`lib/acting_for/errors.rb`、`app/services/acting_for/internal/delegation_creator.rb`。D190〜D212どおり実装し、既存Modelは変更していない。

Docker / Ruby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16.15 / RAILS_ENV=testでDelegation API **110 checks passed**、既存Model **213 checks passed**。Migrationのrollback（STEP=3）→ up、3テーブル削除と再適用後のcolumn / default / NULL / index / FK / CHECK一致も確認済み。一時検証scriptを使用し、正式Minitest suiteは追加していない。

ActiveRecord Models / time helper：

```text
app/models/acting_for/
├── application_record.rb
├── agent.rb
├── delegation.rb
└── audit_event.rb

lib/acting_for.rb
└── ActingFor.current_time
```

Model verification：Docker / Ruby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16.15 / RAILS_ENV=testで **213 checks passed**。Migration regressionも成功。詳細は[DECISIONS](DECISIONS.md#model-runtime-verification完了記録2026-09-18)を参照。

Migration files：

```text
db/migrate/
├── 20260918030001_create_acting_for_agents.rb
├── 20260918030002_create_acting_for_delegations.rb
└── 20260918030003_create_acting_for_audit_events.rb
```

Implemented schema follows the existing Domain Model decisions for columns, defaults, indexes, Foreign Key, and DB CHECK constraints.

Migration検証環境：最小 `test/dummy` host、`compose.migration.yml`、`docker/migration/Dockerfile`、`gemfiles/rails_8_0.gemfile`、Rails標準taskでDummy側へコピーした3 Migration（Git管理する検証用fixture）。

Docker内のRuby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16 / RAILS_ENV=testで、空DBからup → rollback（STEP=3）→ upに成功。rollback後の3テーブル削除と再up後の構造一致を確認した。table / column / default / index / FK / CHECK constraintは設計と一致。検証用volumeは `down -v` で削除済み。詳細結果は[DECISIONS](DECISIONS.md)を参照。

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

Authorization core実装完了。D217で `ActingFor.authorize(...)` を薄いPublic Entry Pointとし、Public入力validation / normalizationを `ActingFor::Internal::Authorization` が担当する方針を確定。Public Entry Point自体はまだ未実装。次の明示指示でagent / principal / action / resource / contextのvalidation・normalizationと `ActingFor.authorize(...)` からInternal Authorizationへの受け渡しを実装する。`audit_context_keys` とAuditEvent保存・Audit integrationにはまだ進まない。詳細は[Public API](public_api_v0_1.md)、[Domain Model](domain_model_v0_1.md)、[Gem Structure](gem_structure_v0_1.md)を参照。

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
