# ActingFor v0.1 Gem Structure Design

更新日：2026-09-17

**Step 7は完了（Complete / Design finalized / Not implemented）。** 本書をStep 7「Gem Structure Design」の正本とする（[D028](DECISIONS.md#d028-step-7-gem-structure-design)）。Gemは未実装・未リリース。このドキュメントは実装済み構成を示すものではない。ファイル構成とRubyコードは設計例であり、今回作成するのは設計ドキュメントのみ（Design documentation only / No implementation）。

[Step 4 Domain Model Design](domain_model_v0_1.md)、[Step 5 Public API Design](public_api_v0_1.md)、[Step 6 README Quick Start](../README.md#quick-start)の決定を維持する。進捗は[PROJECT](PROJECT.md#5-進行順)、決定理由は[DECISIONS](DECISIONS.md)を参照。次はStep 8「Test Strategy」だが、今回は着手しない。

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

具体的なMigration内容・実コード・DB columnの最終型は今回確定しない。Migration taskの具体的なコマンド名はRails実装時に確認する事項とし、未検証のコマンドを正式仕様に固定しない。

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

`test/` という構造表記はテストフレームワークの採用決定を意味しない。**Minitest / RSpecは未決定**であり、Step 8 Test Strategyで決定する。Test Strategy詳細・Test case一覧には今回着手しない。

## 10. Configuration / Initializer

v0.1では現時点で `lib/acting_for/configuration.rb` と `config/initializers/acting_for.rb` を作らない。必須Configurationが確定していないため、空のConfiguration APIを先にPublic化しない。将来必要になった時点で追加できる。

Audit Sanitizer等の将来候補を理由にConfiguration APIを追加しない。既存のAudit Filter / Sanitizer方針を維持し、そのPublic APIは未決定のままとする。

## 11. Runtime Dependencies

`rails` meta-gem全体には依存せず、必要なRails componentを最小限依存とする。現時点の設計対象：

- `activerecord`
- `railties`
- `activesupport`

Pundit、CanCanCan、Action Policy、MCP関連Gem、OAuth / OIDC関連Gem、OpenAI SDK、Claude SDK、Gemini SDKには依存しない。ホスト認可、接続・認証、LLMとの既存の責務境界を維持する。

Gem version constraint、対応Ruby / Rails versionは未決定。gemspecの実装変更は行わない。

## 12. Public / Internal Boundary

| 境界 | 対象 |
| --- | --- |
| Public | `ActingFor.authorize`、`ActingFor.delegate`、`ActingFor::Decision`、`ActingFor::Agent`、`ActingFor::Delegation`、`ActingFor::AuditEvent` |
| Internal | `ActingFor::Internal::*` |

Internalは利用者向けAPIではなく、READMEでは原則としてInternal APIを利用例に示さない。Public APIから内部実装を分離し、内部クラス名・構造を将来変更可能にする。

この分類はStep 5のPublic APIの細部を追加確定するものではない。特に `ActingFor.delegate(...)` の全引数・default・validation、`delegate!` の有無は未決定のまま維持する。ModelをPublicに分類することも、DelegationをActiveRecord直接操作中心にする意味ではない。

## 13. 未決定事項と次工程

以下を今回追加確定しない。

- Minitest / RSpec、Test Strategy詳細、Test case一覧
- Rails / Ruby対応version、Gem version constraint
- DB columnの最終型、Migrationの実コード・taskの具体的なコマンド名
- Exception class名、reason_code一覧、Decisionの追加属性
- Audit Sanitizer Public API、Configuration API、Initializerの具体設計
- install generatorの将来設計（v0.1では独自Generatorを作らない）
- `delegate!`、Delegation APIの全引数・default・validation
- 実装クラスの細かなprivate method構成
- Approval Workflow、MCP Adapter、OAuth / OIDC Adapterの具体設計・実装

| Step | 状態 |
| --- | --- |
| Step 4 Domain Model Design | Complete |
| Step 5 Public API Design | Complete / 10 of 10 / Design finalized |
| Step 6 README Quick Start Design | Complete / Design-stage Quick Start finalized |
| Step 7 Gem Structure Design | Complete / Design finalized / Not implemented |
| Next: Step 8 Test Strategy | 未着手。今回は着手しない |

Gem全体は引き続き **Not implemented / Not released**。Gem本体、Model、Service、Migration、Generator、Dummy Rails App等の実装ファイルは今回作成しない。
