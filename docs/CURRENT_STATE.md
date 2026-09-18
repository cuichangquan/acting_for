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
D227
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
ActingFor.authorize implemented with automatic AuditEvent persistence
ConstraintEvaluator implemented
Audit authorization integration implemented
Minitest unit / delegation / authorization / audit / engine / migration tests implemented and Docker runtime verified
CI not implemented
Runnable Quick Start not implemented

Not released
```

## Implemented

Engine / Migration Integration Test（D227）：`test/integration/engine_integration_test.rb` に正式Test24件を追加。namespace共存用の最小Host `::Agent` をDummy側へ追加し、fresh boot / eager load・constant解決・Host Migration参照と適用・Model接続とassociationを確認した。既存262件を維持し、Docker / Ruby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16.15で正式 `bundle exec rake test` が成功（exit 0）：**286 runs, 688 assertions, 0 failures, 0 errors, 0 skips**。Production code・schema修正なし。検証用volume・生成物は削除済み。

Authorization / Audit Integration Test（D226）：`test/integration/authorization_test.rb` にPublic API経由の正式Test132件を追加。Decision・matching・effect precedence・Public入力・Audit snapshot / Context選択・保存失敗とcause・非persistence error境界を確認。既存Unit16件・Delegation114件と合わせ、Docker / Ruby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16.15で正式 `bundle exec rake test` が成功（exit 0）：**262 runs, 615 assertions, 0 failures, 0 errors, 0 skips**。Production code修正なし。検証用volume・生成logは削除済み。

Delegation Integration Test（D225）：`test/integration/delegation_test.rb` にPublic API仕様の正常・異常系114件を追加。Dummyに最小Host Principal model / Migrationを追加した。既存Unit Test16件と合わせ、Docker / Ruby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16.15で `db:prepare` と正式 `bundle exec rake test` が成功（exit 0）：**130 runs, 328 assertions, 0 failures, 0 errors, 0 skips**。Production code・Gem本体Migration・仕様は変更していない。

Minitest Unit Test foundation：`test/test_helper.rb`、`Rakefile` の `Rake::TestTask`、`test/unit/decision_test.rb`、`test/unit/constraint_evaluator_test.rb`。D221どおりDummy Rails環境 + `rails/test_help` を共通helperとして使用し、Decisionの3 status / freeze / invalid statusとConstraintEvaluatorのAND / strict type / boundary / missing・nil / Symbol key厳密一致 / nested非対応 / fail-closedを正式Unit Test化した。D222〜D224でDummy rootとMigration確認先を一致させ、`db:prepare` 後の正式 `bundle exec rake test` がDocker / Ruby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16.15で成功：**16 runs, 53 assertions, 0 failures, 0 errors, 0 skips**。検証用volumeは削除済み。

Authorization / Public authorize / Audit integration：`app/services/acting_for/internal/authorization.rb`、`lib/acting_for.rb`、`lib/acting_for/errors.rb`。D216〜D220どおり、Public入力validation / normalization、Delegation評価、Decision生成、Audit Context sanitization、AuditEvent snapshot保存まで実装した。AuditEventは `create!` を1回だけ呼び、matched_delegation_idsはID昇順でcanonical保存する。`ActiveRecord::ActiveRecordError` のみ `AuditPersistenceError` へwrapしcauseを保持する。D226の正式Integration Testでruntime verification完了。

ConstraintEvaluator：`app/services/acting_for/internal/constraint_evaluator.rb`。D214・D215と既存Constraint仕様どおり、`eq` / `lt` / `lte` / `gt` / `gte` / `in`、複数条件AND、strict type、missing / nil不成立、invalid constraint fail-closed、トップレベルSymbol key厳密参照を実装した。`ActingFor.authorize(...)` / Authorization / Audit integration / DB queryには進んでいない。D221の正式Unit Testでruntime verification済み。

Decision Value Object：`lib/acting_for/decision.rb`。D213どおり、`:allow` / `:deny` / `:require_approval` の3 status、`status` / `allowed?` / `denied?` / `approval_required?` の4 Public API、初期化後freeze、不正statusの `ArgumentError` を実装した。`lib/acting_for.rb` からrequireする。D221の正式Unit Testでruntime verification済み。

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

D227によりEngine / Migration Integrationも正式TestでDocker検証完了。正式コマンドは `bundle exec rake test`、DB事前準備はDummyの `db:prepare`。次の候補はTest Strategyの残存coverage（Host Authorization Boundary）の実装単位を確認すること。CI / Host Authorization Boundary実装 / Quick Start / Releaseには今回進んでいない。詳細は[Test Strategy](test_strategy_v0_1.md)を参照。

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
