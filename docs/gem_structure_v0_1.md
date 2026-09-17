# ActingFor v0.1 Gem Structure Design

更新日：2026-09-17

**Step 7は完了（Complete / Design finalized / Not implemented）。** 本書をStep 7「Gem Structure Design」の正本とする（[D028](DECISIONS.md#d028-step-7-gem-structure-design)）。Gemは未実装・未リリース。このドキュメントは実装済み構成を示すものではない。ファイル構成とRubyコードは設計例であり、今回作成するのは設計ドキュメントのみ（Design documentation only / No implementation）。

[Step 4 Domain Model Design](domain_model_v0_1.md)、[Step 5 Public API Design](public_api_v0_1.md)、[Step 6 README Quick Start](../README.md#quick-start)の決定を維持する。進捗は[PROJECT](PROJECT.md#5-進行順)、決定理由は[DECISIONS](DECISIONS.md)を参照。後続のStep 8「Test Strategy」は[正本](test_strategy_v0_1.md)（D029）で設計完了した。

## 1. v0.1 Minimal Gem Structure

**Design finalized / Not implemented。** 以下は正式な最小構成の設計であり、実ファイルの存在を示さない。将来候補のファイルは追加しない。

```text
acting_for/
├── acting_for.gemspec
├── Gemfile
├── Rakefile
│
├── lib/
│   ├── acting_for.rb
│   └── acting_for/
│       ├── version.rb
│       ├── engine.rb
│       └── decision.rb
│
├── app/
│   ├── models/
│   │   └── acting_for/
│   │       ├── application_record.rb
│   │       ├── agent.rb
│   │       ├── delegation.rb
│   │       └── audit_event.rb
│   │
│   └── services/
│       └── acting_for/
│           └── internal/
│               ├── authorization.rb
│               └── constraint_evaluator.rb
│
├── db/
│   └── migrate/
│       ├── create_acting_for_agents.rb
│       ├── create_acting_for_delegations.rb
│       └── create_acting_for_audit_events.rb
│
└── test/
    └── dummy/
```

## 2. Rails Engine / Namespace

ActingFor v0.1は **Headless Rails Engine** として `Rails::Engine` を採用する。Routes、Controllers、Views、Assetsを前提としたWeb UIは作らない。Rails::EngineがRailtieの役割を含むため、独立した `ActingFor::Railtie` は作らない。

`lib/acting_for/engine.rb` の設計例：

```ruby
module ActingFor
  class Engine < ::Rails::Engine
    isolate_namespace ActingFor
  end
end
```

`isolate_namespace ActingFor` によりHost Applicationとの名前空間衝突を避け、ActingFor所有コンポーネントを明確にし、`ActingFor::Agent` 等をGem側の名前空間へ閉じ込める。

## 3. ActiveRecord Models

| 配置 | 対応クラス |
| --- | --- |
| `app/models/acting_for/application_record.rb` | `ActingFor::ApplicationRecord` |
| `app/models/acting_for/agent.rb` | `ActingFor::Agent` |
| `app/models/acting_for/delegation.rb` | `ActingFor::Delegation` |
| `app/models/acting_for/audit_event.rb` | `ActingFor::AuditEvent` |

`ActingFor::ApplicationRecord` をGem内ActiveRecord Modelの共通親クラスとする。Step 4の主要Modelは引き続きAgent / Delegation / AuditEventの3つ。属性・関連・Lifecycleの仕様は変更しない。

## 4. Internal Authorization Services

| 配置 | 内部クラス |
| --- | --- |
| `app/services/acting_for/internal/authorization.rb` | `ActingFor::Internal::Authorization` |
| `app/services/acting_for/internal/constraint_evaluator.rb` | `ActingFor::Internal::ConstraintEvaluator` |

これらはPublic APIではない。Public APIは引き続き `ActingFor.authorize(...)` とする。概念上の流れ：

```text
ActingFor.authorize(...)
        ↓
ActingFor::Internal::Authorization
        ↓
ActingFor::Internal::ConstraintEvaluator
        ↓
Decision
        ↓
AuditEvent
```

内部のクラス名・構造・具体的実装は将来変更可能。private method構成等は確定しない。Step 5の自動Auditを維持し、AuditEvent保存後にDecisionを返す。保存失敗時はDecisionを返さずExceptionで中断する。

時刻取得は内部の共通境界 `ActingFor.current_time` に集約し、通常は `Time.current` を返す。Expiration / Revocation / Authorization等は直接 `Time.current` を呼ばない。v0.1ではClock差し替えPublic API（`ActingFor.clock =` / `ActingFor.reset_clock!`）を提供しない。TestではRails time helper（`travel_to` 等）を使う（D035）。

`ActingFor.authorize(...)` 自身は明示的なDB transactionを開始しない。概念上の順序はDelegation lookup → Authorization evaluation → Decision生成 → AuditEvent保存 → Decision return。保存失敗時は `ActingFor::AuditPersistenceError` をraiseし、Decisionを返さない。Host側Business Logicのtransaction管理はHost Applicationの責務。

v0.1のAuthorizationはDelegationへ `SELECT ... FOR UPDATE` 等の明示的なDB lockを取得しない。Decisionは実行時点で観測した状態に基づき、返却後からBusiness Logic実行までDelegationの有効性を保証しない。独自のtransaction isolation levelを要求・変更せず、READ COMMITTED / REPEATABLE READ / SERIALIZABLEを強制しない。Host Application / DB設定に従い、特定isolation levelによるatomicity / TOCTOU防止も保証しない（D036）。

v0.1ではAuthorization / Delegation作成 / AuditEvent保存を内部で自動retryしない。失敗は既存Exception方針で呼び出し元へ伝える。Hostがretryする場合、古いDecisionを再利用せず、必要に応じauthorizeから再評価する。delegateは呼ぶたび新規Delegationを作るため、内部自動retryによるduplicate Delegation作成を避ける（D038）。

## 5. Decision Value Object

`ActingFor::Decision` は `lib/acting_for/decision.rb` に配置する。ActiveRecord ModelでもServiceでもなく、Public APIとして利用されるValue Objectである。

Step 5で確定した以下のAPIを維持する。

```ruby
decision.status
decision.allowed?
decision.denied?
decision.approval_required?
```

statusは `:allow` / `:deny` / `:require_approval`。`require_approval != allow` であり、承認が必要な場合の `allowed?` はfalse。追加属性やAPIは今回決定しない。

## 6. Migration / DB Table Names

MigrationはGem側の `db/migrate/` で管理し、第1節の3ファイルを想定する。Rails Engine標準のMigration提供方式を利用し、Host ApplicationのDBへMigrationをコピー・適用する。独自Migration DSLや独自DBセットアップ機構は作らない。

Step 7時点では具体的なMigration内容・実コード・DB columnの最終型は確定しなかった。後続D032〜D034でResource IDのString保存、Agent unique index、AuditEventの一部保存型・制約を確定した。後続D043でAgent string型、principal_id string型、constraints / sanitized context / matched_delegation_idsのjson型・default・NOT NULLを確定した。その他の型・制約とMigration実コードは未決定。Migration taskの具体的なコマンド名はRails実装時に確認する事項とし、未検証のコマンドを正式仕様に固定しない。

全テーブルに `acting_for_` prefixを付ける。

| Model | Table |
| --- | --- |
| `ActingFor::Agent` | `acting_for_agents` |
| `ActingFor::Delegation` | `acting_for_delegations` |
| `ActingFor::AuditEvent` | `acting_for_audit_events` |

Host Applicationのテーブルとの衝突を防ぎ、ActingFor所有テーブルであることを明確にする。

## 7. Generator

v0.1では独自Generatorを作らない。`acting_for:install`、`acting_for:agent`、`acting_for:config` 等は提供しない。

現時点では不要で、Rails標準機能で対応でき、保守対象を増やさないためである。実際の必要性が出てから将来追加できるが、v0.1の約束には含めない。

## 8. Public Entry Point / Load / Zeitwerk

`lib/acting_for.rb` は `ActingFor.authorize(...)` / `ActingFor.delegate(...)` の薄いPublic API Entry Pointとし、内部ロジックを集中させない。

```text
利用者
  ↓
ActingFor.authorize(...)
  ↓
Public Entry Point
  ↓
ActingFor::Internal::Authorization
```

| 配置 | 役割 / 読み込み |
| --- | --- |
| `lib/` | GemのEntry Point / Public Ruby API。必要最小限を明示的に読み込む |
| `app/` | Rails EngineのRails Components。`app/models/` / `app/services/` はRails / Zeitwerkのautoloadに任せる |

`lib/acting_for.rb` での設計例：

```ruby
require "acting_for/version"
require "acting_for/decision"
require "acting_for/engine"
```

手動requireを大量に追加する設計にはしない。これらは未実装の設計例である。

## 9. Test Directory / Dummy Rails App

テストではDummy Rails Applicationを持つ構成を採用し、最低限 `test/dummy/` を想定する。Rails Engine integration、ActiveRecord、Migration、Rails autoload、Host Applicationとのintegrationを実際のRails環境で検証できるようにするためである。

Step 7時点では `test/` という構造のみを決め、Test Frameworkは未決定だった。後続の[Step 8 Test Strategy](test_strategy_v0_1.md)（D029）で **Minitest採用・RSpec不採用** を確定した。Unit / Integrationの境界と検証シナリオはStep 8正本に従う。`test/dummy` は最小Rails integration hostとし、sample product / demo applicationにはしない。TestコードとDummy Rails Appは未実装。

## 10. Configuration / Initializer

v0.1では現時点で `lib/acting_for/configuration.rb` と `config/initializers/acting_for.rb` を作らない。必須Configurationが確定していないため、空のConfiguration APIを先にPublic化しない。将来必要になった時点で追加できる。

Audit Sanitizer等の将来候補を理由にConfiguration APIを追加しない。後続D031によりAudit Contextの選択はaudit_context_keysのみとし、custom Filter / Sanitizer・global config・initializer設定はv0.1で提供しない。

## 11. Runtime Dependencies

`rails` meta-gem全体には依存せず、必要なRails componentを最小限依存とする。現時点の設計対象：

- `activerecord`
- `railties`
- `activesupport`

Pundit、CanCanCan、Action Policy、MCP関連Gem、OAuth / OIDC関連Gem、OpenAI SDK、Claude SDK、Gemini SDKには依存しない。ホスト認可、接続・認証、LLMとの既存の責務境界を維持する。

v0.1の正式対応DB adapterは **PostgreSQLのみ**。他adapterを意図的に排除する設計にはしないが、正式サポート・動作保証対象外とする。CI / Integration Testで検証したDBだけを正式サポートとする（D045）。

正式サポート対象は **Ruby 3.4 / 4.0、Rails 8.0 / 8.1**。Ruby 3.3以下、Rails 7.2以下は対象外。正式CI matrixは以下の4組で、DBはいずれもPostgreSQL。正式サポートはこのmatrixで実際に検証した組み合わせのみ（D046）。

| Ruby | Rails | DB |
| --- | --- | --- |
| 3.4 | 8.0 | PostgreSQL |
| 3.4 | 8.1 | PostgreSQL |
| 4.0 | 8.0 | PostgreSQL |
| 4.0 | 8.1 | PostgreSQL |

Rails 8.0のSecurity Support終了時期が近いため、v0.1リリース直前にRails公式support statusを再確認する。Ruby公式support statusもリリース直前に再確認する。これは設計上の対象であり、現在検証済み・リリース済みという意味ではない。CIはまだ実装しない。

将来gemspecへ設定するv0.1のversion constraintはRuby `>= 3.4`, `< 4.1`、Rails `>= 8.0`, `< 8.2` とする。dependencyとしてinstall可能であることと正式サポートは区別し、正式サポートはD046のCI matrixで検証済みの組み合わせだけとする。今回はgemspecを作成・変更しない（D047）。

ActingForは **MIT License** で公開する。将来LICENSE / gemspecへMITを明記するが、今回はLICENSEファイルを作成せず、gemspecも作成・変更しない（D048）。

## 12. Public / Internal Boundary

| 境界 | 対象 |
| --- | --- |
| Public | `ActingFor.authorize`、`ActingFor.delegate`、`ActingFor::Decision`、`ActingFor::Agent`、`ActingFor::Delegation`、`ActingFor::AuditEvent` |
| Internal | `ActingFor::Internal::*` |

Internalは利用者向けAPIではなく、READMEでは原則としてInternal APIを利用例に示さない。Public APIから内部実装を分離し、内部クラス名・構造を将来変更可能にする。

後続D031のPublic Exceptionは `ActingFor::Error` / `ActingFor::InvalidRequestError` / `ActingFor::InternalError` / `ActingFor::AuditPersistenceError`。具体的ファイル配置は今回追加決定しない。

この分類はStep 5のPublic APIの細部を追加確定するものではない。Step 7時点で保留していた `ActingFor.delegate(...)` の全引数・default・validationとdelegate!非提供は後続D032で確定した。ModelをPublicに分類することも、DelegationをActiveRecord直接操作中心にする意味ではない。

## 13. 未決定事項と次工程

以下は引き続き未決定であり、本書では追加確定しない。

- D032〜D034・D043で確定した範囲以外のDB型・制約、Migrationの実コード・taskの具体的なコマンド名
- Decisionの追加属性・constructor（ExceptionはD031、Audit reason_codeはD034で確定）
- install generatorの将来設計（v0.1では独自Generatorを作らない）
- 実装クラスの細かなprivate method構成
- Approval Workflow、MCP Adapter、OAuth / OIDC Adapterの具体設計・実装

| Step | 状態 |
| --- | --- |
| Step 4 Domain Model Design | Complete |
| Step 5 Public API Design | Complete / 10 of 10 / Design finalized |
| Step 6 README Quick Start Design | Complete / Design-stage Quick Start finalized |
| Step 7 Gem Structure Design | Complete / Design finalized / Not implemented |
| Step 8 Test Strategy | Complete / Design finalized / Not implemented（D029） |

Gem全体は引き続き **Not implemented / Not released**。Gem本体、Model、Service、Migration、Generator、Dummy Rails App等の実装ファイルは今回作成しない。
