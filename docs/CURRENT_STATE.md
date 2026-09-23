# ActingFor Current State

更新日：2026-09-23

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
D239
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
Minitest unit / delegation / authorization / audit / engine / migration / host boundary tests implemented and Docker runtime verified
Pre-CI Test Strategy coverage checked
GitHub Actions formal four-matrix CI / PostgreSQL 16 / core RuboCop implemented and runtime verified
Runnable Quick Start implemented and verified in a new Rails application
Built gem / package / artifact installation / documentation / support verification completed
v0.1 Release Readiness Gate: RELEASE READY / D076 all 9 PASS
Post-readiness Delegation lifecycle security regression tests implemented and formal CI verified
Post-readiness AuditEvent tamper resistance security regression tests implemented and formal CI verified
Post-readiness Security hardening batch A-H implemented and formal CI verified
v0.1.0 Release Candidate baseline fixed at `2c2e1a6638f12b7fb961f04362f807e2cb6ff9a5` via `release/v0.1.0-rc`
Pre-publication human confirmations completed for email exposure / RubyGems authentication; RC fresh artifact verification PASS (D236)
Repository and official Demo are public; public-source documentation and Demo build instructions adjusted (D237)
ActingFor 0.1.0 published to RubyGems; distributed artifact verified; `v0.1.0` tag and GitHub Release published (D238)
Official Demo switched to RubyGems `~> 0.1.0`; automated integration verification and smoke verification PASS
Official Demo Full Human Manual Verification completed: Scenarios 1–11 PASS (completion pass 2026-09-23)
Post-release documentation current-state consistency cleanup completed (D239); historical release-stage records preserved

Released: `acting_for` 0.1.0 / `v0.1.0`
```

## Implemented

D239：Post-release Documentation Consistency Cleanup。v0.1.0公開後も設計書の現在状態部分に残っていた `Not released` / `未リリース` / `Releaseは未実施` / `Partially implemented` 等の古い表記を、D238およびDemo verification完了後の事実へ整合した。対象はPROJECT / Domain Model / Public API / Gem Structure / Test Strategy / Security Model。D231等の過去時点を記録する履歴表現は変更せず、Production code / Public API / schema / `v0.1.0` tag / 公開artifactには変更なし。

Post-release Official Demo verification closure（2026-09-23）：Official DemoはRubyGems `acting_for ~> 0.1.0` を使用し、automated integration verification **18 runs / 108 assertions / 0 failures / 0 errors / 0 skips**、Smoke Verification PASS、Full Human Manual Verification（Scenarios 1–11）PASSまで完了。Scenarios 7–8はRails console、Scenarios 9–11はbrowser workflowで人間が再確認した。詳細な証跡はDemo側 `docs/MANUAL_VERIFICATION.md` / `docs/COMPATIBILITY.md` を正本とする。Demo behavior baseline `32058147b6527ce46486c523e9a8d036760ca372` からcompletion record直前の `073a97f3c350c7c2ac81e2fb2aa6ff1762b1a005` までの差分は上記2 docsのみで、application behavior変更なし。

D238：ActingFor 0.1.0 release完了。最終Artifact Source `6722623a9f24a38c41091e867209bc8f3d913c36` からstrict buildした17-file gem（15,872 bytes / SHA256 `a7c3cfc97bf04445c04b8fc9cbe6be8a9aa433cfb8ba20b0da90f853b1336abd`）をRubyGemsへ公開。RubyGemsから再取得したartifactのSHA256一致とRuby 3.4.10 fresh containerでの通常install / `ActingFor::VERSION == "0.1.0"`を確認。`v0.1.0` tagは同Source SHAを指し、GitHub Release `ActingFor 0.1.0` はdraft=false / prerelease=falseで公開済み。

D237：ActingFor / ActingFor DemoのGitHub Repository Public化を確認し、RubyGems公開前のtruthful `Not released` 状態を維持したまま、private repository前提のREADME / Getting Started / Demo Docker build・manual verification記述をpublic source向けへ整理。Demo側commit `693447b9dc903c55831cff016a1958ba67121772`。RubyGems push / `v0.1.0` tag / GitHub Releaseは未実施。

D234：Release前Security hardening候補A〜Hをまとめて正式Regression Test化。Sensitive Context、Error Leakage、DB Constraints、Stale Decision、Delegation Management Host Boundary、Replay Boundary、Concurrent revoke、Confused-Deputy bindingを対象とする。Production code / Public API / schema変更なし。正式CI #31は全5 jobs green、Ruby 3.4 / Rails 8.0で351 runs / 889 assertions / 0 failures / 0 errors / 0 skips。詳細は[DECISIONS D234](DECISIONS.md#d234-security-hardening-batch-a-h)。

D233：Release前の追加Security hardeningとして、AuditEvent tamper resistanceの正式Integration Testを追加。persist済みAuditEventのAuthorization snapshot更新禁止、destroy禁止、後続Authorizationが既存Auditを書き換えず新規INSERTすること、Agent identifier変更・Delegation revoke後も既存snapshotが保持されることを検証する。Production code / Public API / schema変更なし。正式CI #23は全5 jobs green、Ruby 3.4 / Rails 8.0で326 runs / 821 assertions / 0 failures / 0 errors / 0 skips。詳細は[DECISIONS D233](DECISIONS.md#d233-auditevent-tamper-resistance-security-regression-tests)。

D232：Release前の追加Security hardeningとして、Delegation immutability / revoke! lifecycleの正式Integration Testを追加。正式4 matrix CI / RuboCopは2026-09-21に確認済み。persist済みDelegationの認可内容の通常update禁止、revoked_at直接update禁止、revoke!のtimestamp更新・idempotency・stale instance時のfirst timestamp保持、unsaved revoke拒否、revoke後Authorization、duplicate Delegation非波及を検証する。Production code / Public API / schema変更なし。詳細は[DECISIONS D232](DECISIONS.md#d232-delegation-lifecycle-security-regression-tests)。

D231：built `acting_for-0.1.0.gem` strict build / package audit / secret・privacy簡易監査 / 新規Rails Appへのlocal artifact installとMigration・全Decision・Audit確認が成功。Release Notes draftとActual Release planを準備。Security / Responsibility / README照合済み。正式Test 298 / 755、RuboCop違反なし。support確認日2026-09-19。repo private、RubyGems未登録、tag / GitHub Releaseなし。D231 CI #5全5 jobs green、D076全9項目PASS、RELEASE READY。詳細は[DECISIONS D231](DECISIONS.md#d231-v01-release-readiness-gate)。Not released。

Runnable Quick Start（D230）：Release前のGitHub `main` Gem導入から、Rails標準 `bin/rails acting_for:install:migrations`、最小User / Product、Agent作成、Public delegate / authorize、Decision全3結果、Audit保存まで新規Rails Applicationで実検証。Ruby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16.15。READMEから抽出したRuby codeをrunnerで実行し、Rails console起動も確認。README全体の古い未実装・planned support表記を整理。Production code変更なし。正式Test 298 runs / 755 assertions / 0 failures / 0 errors / 0 skips、RuboCop違反なし。GemはNot released。詳細は[DECISIONS D230](DECISIONS.md#d230-runnable-quick-start-implementation)。

v0.1正式CI（D229）：GitHub Actions PR / main push、Ruby 3.4 / 4.0 × Rails 8.0 / 8.1、PostgreSQL 16、Dummy `db:prepare` と正式Minitest、独立core RuboCop jobを実装。全5 jobs green。正式Testは298 runs / 755 assertions / 0 failures / 0 errors / 0 skips、RuboCop 1.91.0は違反なし。Production修正はbehavior非変更のStyleのみ。詳細と実検証runは[DECISIONS D229](DECISIONS.md#d229-v01-ci-implementation)。

Host Authorization Boundary / 残存coverage（D228）：Host boundary Test8件、Context Resource責務境界・Delegation lookup failure・bigint / UUID Principal IDの既存仕様Test4件を追加。既存286件を維持し、Docker / Ruby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16.15で正式 `bundle exec rake test` が成功（exit 0）：**298 runs, 755 assertions, 0 failures, 0 errors, 0 skips**。Dummyに最小Host operationとUUID Principal fixtureを追加。Production code変更なし。Context形式不正・field不足とFail Closedの大部分は既存Testでcoverage済み。CI前の確定済みcoverageに残存未実装項目なし。詳細は[Test Strategy §17](test_strategy_v0_1.md#17-d228後のcoverage確認2026-09-18)。

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

ActingFor 0.1.0のRubyGems publication、配布artifact verification、`v0.1.0` tag / GitHub Release、Official DemoのRubyGems `~> 0.1.0` 移行、automated integration / smoke / Full Human Manual Verificationまで完了した。v0.1.0 release verificationは閉じた状態。

次の1項目は、**v0.1.1 / 次期開発候補をGitHub `main` の設計書・Issues・残課題から再確認し、重要事項を1項目だけ提案すること**。いきなり実装を開始せず、ユーザー承認後に次の正式作業へ進む。

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
