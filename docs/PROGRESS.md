# ActingFor Progress

更新日：2026-09-21

正本は [GitHub `main`](https://github.com/cuichangquan/acting_for/tree/main)。本書はプロジェクト全体の進捗マップ。短い現在地点は[CURRENT_STATE](CURRENT_STATE.md)、正式Decision履歴は[DECISIONS](DECISIONS.md)で管理し、詳細仕様を本書へ複製しない。

> 設計の大部分・基盤実装・Delegation / Authorization / Decision / ConstraintEvaluator / Audit authorization integrationが完了。正式Minitest Unit / Delegation / Authorization / Audit / Engine / Migration / Host Boundary TestはDocker検証完了。CI前の確定済みcoverage確認完了。正式CI matrix・core RuboCopはGitHub Actionsで成功（D229）。Runnable Quick Startは新規Rails Applicationで検証完了（D230）。D231はRELEASE READY（D076全9項目PASS）。D232 Delegation lifecycle Security Invariant regression Test、D233 AuditEvent tamper resistance Security regression Testはいずれも正式CI確認済み。Releaseは未実施。

## 全体進捗

| # | 項目 | 状態 |
| --- | --- | --- |
| 1 | プロジェクト定義 | ✅ 完了 |
| 2 | v0.1スコープ・用語定義 | ✅ 完了 |
| 3 | Domain Model設計 | ✅ 完了 |
| 4 | Public API設計 | ✅ 完了 |
| 5 | Security Model | ✅ 完了 |
| 6 | Gem構成設計 | ✅ 完了 |
| 7 | Test Strategy設計 | ✅ 完了 |
| 8 | Gem skeleton実装 | ✅ 完了 |
| 9 | Migration実装 | ✅ 完了 |
| 10 | ActiveRecord Model実装 | ✅ 完了 |
| 11 | Delegation Public API実装設計 | ✅ 完了 |
| 12 | ActingFor.delegate実装 | ✅ 完了 |
| 13 | Authorization実装 | ✅ 完了 |
| 14 | ConstraintEvaluator実装 | ✅ 完了 |
| 15 | Decision実装 | ✅ 完了 |
| 16 | Audit Authorization Integration | ✅ 完了 |
| 17 | 正式Minitest suite | ✅ D221〜D228正式coverage + D232 Delegation lifecycle security regression Test + D233 AuditEvent tamper resistance Test（いずれもCI確認済み） |
| 18 | CI | ✅ 正式4 matrix / PostgreSQL 16 / RuboCop green（D229） |
| 19 | Runnable Quick Start | ✅ 新規Rails Applicationで実検証済み（D230） |
| 20 | Gem Release | ⬜ 未実施。D231 artifact / docs検証済み、RELEASE READY / D076全9項目PASS / CI全5 jobs green |

## 現在の位置

```text
設計：ほぼ完了
  Domain / Public API / Security / Gem Structure / Test Strategy
      ↓
基盤実装：完了
  Gem skeleton → Migration → Models
      ↓
Public API / Value Object実装
  delegate ✅
  Decision ✅
  Authorization core ✅
  authorize Public API ✅
  ConstraintEvaluator ✅
  Audit integration ✅
      ↓
品質・公開：正式TestのCI前coverage実装・Docker検証済み
  正式Tests ✅ → CI ✅ → Runnable Quick Start ✅ → Release（未実施 ← 現在ここ）
```

上記は進捗の俯瞰であり、未承認の実装順序や完了率を定めない。

## 実装・検証済みの実績

- D233 Security hardening：AuditEvent tamper resistanceの正式Integration Testを追加。persist済みAuditEventのsnapshot更新禁止、destroy禁止、後続Authorizationの新規INSERT、Agent / Delegation後続変更後のsnapshot保持を対象化。Production code変更なし。正式CI #23全5 jobs green。Ruby 3.4 / Rails 8.0で326 runs / 821 assertions / 0 failures / 0 errors / 0 skips。

- D232 Security hardening：Delegation immutability / revoke! lifecycleの正式Integration Testを追加。通常updateによる権限内容改ざん防止、revoke timestamp / idempotency / stale instance、unsaved revoke、revoke後Authorization、duplicate Delegation非波及を対象化。Production code変更なし。正式4 matrix CI / RuboCop確認済み。

- D231 Release Readiness Gate：strict built gem・17 files package audit・secret / privacy簡易監査・built artifactから新規Rails App導入 / Migration / 全Decision / Audit検証成功。Release Notes draft / Actual Release plan完成。support / Security / Responsibility / README照合済み。RELEASE READY / D076全9項目PASS / CI全5 jobs green、Not released。

- Gem skeleton implemented。
- Migration implemented and runtime verified。
- ActiveRecord Models implemented。
- Docker Model verification：213 checks passed。
- Delegation API implemented / Docker verification：110 checks passed。
- 既存Model regression：213 checks passed。
- Migration regression passed（rollback後3テーブル削除、再up後schema一致）。
- Decision Value Object implemented（D213）。D221の正式Unit Testでruntime verification済み。
- ConstraintEvaluator implemented（D214・D215）。D221の正式Unit Testでruntime verification済み。
- Authorization core implemented（D216）。DB候補抽出 → Ruby最終評価 → Decision生成まで。
- Public authorize basic input boundary implemented（D217）。agent / principal / action / resource / contextのvalidation・normalizationをInternal Authorizationで実装。
- Audit Context sanitization implemented（D219）。audit_context_keys validation / dedup / forbidden key拒否 / strict Symbol key selection / canonical String key / BigDecimal decimal String化まで。
- Audit authorization integration implemented（D218・D220）。AuditEvent snapshot / create! / reason_code / matched_delegation_ids / AuditPersistenceError wrapまで実装。D226の正式Integration Testでruntime verification完了。
- 正式Minitest Unit foundation implemented（D221）。`test_helper` / `Rake::TestTask` / Decision / ConstraintEvaluator Unit Testを追加。D222〜D224のTest infrastructure修正とDB準備によりDocker検証成功：16 runs / 53 assertions / 0 failures / 0 errors / 0 skips。Authorization / Audit Integration TestはD226で追加・検証済み。
- Delegation Integration Test implemented（D225）：114件追加。既存Unit16件と合わせDocker検証成功：130 runs / 328 assertions / 0 failures / 0 errors / 0 skips。
- Authorization / Audit Integration Test implemented（D226）：132件追加。既存Unit・Delegation Testと合わせDocker検証成功：262 runs / 615 assertions / 0 failures / 0 errors / 0 skips。Production code修正なし。
- Engine / Migration Integration Test implemented（D227）：24件追加。既存262件と合わせDocker検証成功：286 runs / 688 assertions / 0 failures / 0 errors / 0 skips。Production code・schema修正なし。
- Host Authorization Boundary / 残存coverage（D228）：Host Test8件・その他既存仕様4件追加。既存286件と合わせDocker検証成功：298 runs / 755 assertions / 0 failures / 0 errors / 0 skips。Production code変更なし。Context Trust / Fail Closedの既存coverageも確認済み。Test Strategy §17に実装状態を記録。
- v0.1正式CI（D229）：PR / main push、正式4 matrix、PostgreSQL 16、`db:prepare` / Minitest、core RuboCop独立jobを実装。GitHub Actions全5 jobs green。Productionはbehavior非変更のStyle修正のみ。
- Runnable Quick Start（D230）：GitHub main Gem・Rails標準Migration取り込み・User / Product・Agent・delegate / authorize・全Decision predicate・Audit保存を新規Rails Appで検証。Ruby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16.15。READMEの古いstatus / support表記整理。Production code変更なし。

今回の現在地点は[CURRENT_STATE](CURRENT_STATE.md)、従来のModel検証詳細は[DECISIONS](DECISIONS.md#model-runtime-verification完了記録2026-09-18)を参照。正式CI matrix全体とRuboCopはD229で検証成功。Quick StartはD230で実装・新規Rails Applicationで検証成功。GemはNot released。

## 設計の正本

[Domain Model](domain_model_v0_1.md) / [Public API](public_api_v0_1.md) / [Security Model](security_model_v0_1.md) / [Gem Structure](gem_structure_v0_1.md) / [Test Strategy](test_strategy_v0_1.md)。

## 更新ルール

- 細かなDecisionごとには更新せず、重要な実装単位が完了したタイミングで更新する。
- 詳細仕様の正本にはせず、DECISIONS / 各設計書へのリンクを維持する。
- CURRENT_STATEは短い現在地点、PROGRESSは全体進捗マップ、DECISIONSは正式Decision履歴という役割を保つ。
