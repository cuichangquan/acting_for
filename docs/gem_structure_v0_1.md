# ActingFor v0.1 Gem Structure Design

更新日：2026-09-18

**Step 7は完了（Complete / Design finalized）。** 本書をGem Structure Designの正本とする（[D028](DECISIONS.md#d028-step-7-gem-structure-design)）。Gem skeleton / Migration / Models / 最小Dummyは実装済み。D190〜D212によりDelegation Public APIの実装設計を詳細化したが、delegate / authorize / Decision / Audit integrationは実装・正式Test / CI検証済み。Gemは未リリース。以下は設計上の構成を示す。現在地点は[CURRENT_STATE](CURRENT_STATE.md)、全体進捗は[PROGRESS](PROGRESS.md)を参照。

[Step 4 Domain Model Design](domain_model_v0_1.md)、[Step 5 Public API Design](public_api_v0_1.md)、[Step 6 README Quick Start](../README.md#quick-start)の決定を維持する。進捗は[PROJECT](PROJECT.md#5-進行順)、決定理由は[DECISIONS](DECISIONS.md)を参照。後続のStep 8「Test Strategy」は[正本](test_strategy_v0_1.md)（D029）で設計完了した。

## 1. v0.1 Minimal Gem Structure

**Design finalized / Partially implemented。** 以下はD028をD195・D199で詳細化した最小構成。errors.rb / delegation_creator.rbは次の実装対象、decision.rb / authorization.rb / constraint_evaluator.rbは後続実装対象であり、今回作成しない。

```text
acting_for/
├── acting_for.gemspec
├── Gemfile
├── Rakefile
│
├── lib/
│   ├── acting_for.rb
│   └── acting_for/
│       ├── errors.rb
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
│               ├── delegation_creator.rb
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

### Delegation作成（D192〜D200）

次の実装単位の内部Serviceは `app/services/acting_for/internal/delegation_creator.rb` に置く。

```text
ActingFor.delegate(...)
    ↓
ActingFor::Internal::DelegationCreator.call(...)
    ↓
ActingFor::Delegation.create!
```

内部呼び出し形は `ActingFor::Internal::DelegationCreator.call(agent:, principal:, action:, resource:, constraints:, effect:, expires_at:)`。Public入力validation、normalization、Resource identity変換、Constraint canonicalization、expires_at validation、Delegation作成を担当する。入力規則の正本は[Public API第9節](public_api_v0_1.md#9-delegation-api)。

DelegationCreatorはInternal APIで、利用者の直接呼び出しや `DelegationCreator.new(...).call` をPublic contractにしない。DelegationValidator / DelegationNormalizer / ConstraintNormalizer / DelegationBuilderへ過剰分割せず、Base Service / ApplicationServiceも追加しない。

Principalは `principal: principal` でRails polymorphic associationへ渡し、type / IDを手動生成しない。Resourceはassociationではないため内部で識別値へ変換する。入力のArray / Hashは破壊せず必要な新しいコンテナを作るが、deep_freeze / 汎用DeepCopy utilityは追加しない。

validation / normalization後に `Delegation.create!` を1回だけ呼ぶ。事前の `valid?`、独自transaction / retryを追加しない。Public入力不正はInvalidRequestError、予期しないModel / DB failureは原則そのまま伝播する。

### Authorization（後続実装対象）

| 配置 | 内部クラス |
| --- | --- |
| `app/services/acting_for/internal/authorization.rb` | `ActingFor::Internal::Authorization` |
| `app/services/acting_for/internal/constraint_evaluator.rb` | `ActingFor::Internal::ConstraintEvaluator` |

これらはPublic APIではない。AuthorizationのPublic APIは引き続き `ActingFor.authorize(...)` とする。概念上の流れ：

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


D216により、AuthorizationのDelegation評価は **DB candidate lookup → Ruby final evaluation** の二段階とする。DBではagent / principal / action / resource_type / active stateで候補を絞り、Resource scopeの最終判定とConstraint評価はRuby側で行う。Constraintは既実装の `ActingFor::Internal::ConstraintEvaluator` を使う。matching 0件はdeny、require_approvalが1件以上ならrequire_approval、それ以外のmatchingがあればallow。DB順・ID順・created_at順・作成順・specificityによる優先順位は導入しない。具体的SQLやActiveRecord chainの細かな形は固定しない。

D216の次の実装単位はInternal Authorization coreまでとし、AuditEvent保存と `ActingFor.authorize(...)` Public Entry Point統合は後続へ分離する。


D217により、`ActingFor.authorize(...)` は `lib/acting_for.rb` の薄いPublic Entry Pointに限定し、agent / principal / action / resource / contextのPublic入力validation / normalizationは `ActingFor::Internal::Authorization` が担当する。agentはpersist済みActingFor::Agent、principalはpersist済みActiveRecord record、actionはString / Symbolをcanonical Stringへ正規化しblank / 不正typeをInvalidRequestError、resourceはD032 / D201の既存規則でresource_type / resource_idへ正規化、contextはHashのみを許可する。入力objectは破壊しない。

`AuthorizationValidator` / `AuthorizationNormalizer` 等へ過剰分割せず、validation順序やprivate method構成をPublic contractにしない。`audit_context_keys` はAudit integration時に扱い、D217の実装単位には含めない。


D218により、Authorization DecisionのAuditEvent保存も `ActingFor::Internal::Authorization` の責務に含める。別の `AuditRecorder` / `AuditService` 等は追加しない。Internal Authorizationはmatching Delegation集合を内部で保持し、そのIDを `matched_delegation_ids` としてAuditEventへ保存する。Public DecisionへAudit用属性は追加しない。

処理順序は「matching Delegation確定 → Decision生成 → AuditEvent保存 → Decision return」。Audit保存失敗時は既存仕様どおりDecisionを返さず `ActingFor::AuditPersistenceError` をraiseし、denyへ変換しない。

D219により、`audit_context_keys` のvalidation / normalizationとsanitized context生成も `ActingFor::Internal::Authorization` が担当する。Array<Symbol>、forbidden secret keys、許可scalar型、BigDecimalの10進数String化等はD031・D044を維持し、別Sanitizer Serviceは追加しない。Context選択時はSymbol key完全一致、生成するsanitized_contextのcanonical keyはStringとする。Public入力objectは破壊しない。


D220により、Internal AuthorizationはDecision生成後に `ActingFor::AuditEvent.create!` を1回だけ呼び、成功後にDecisionを返す。snapshotはagent id / identifier、`principal.class.polymorphic_name` / `principal.id.to_s`、正規化済みaction / resource identity、Decision String、D034 reason_code、実際にmatchしたDelegation ID全部、D219 sanitized_context。matched_delegation_idsはcanonical representationとしてID昇順にsortするが、順序に意味は持たせない。

AuditEvent persistenceでは `create!` 周辺の `ActiveRecord::ActiveRecordError` だけを `ActingFor::AuditPersistenceError` へwrapしcauseを保持する。属性組み立て等のprogramming errorやその他の `StandardError` は一律wrapしない。`ActingFor::InternalError < ActingFor::Error`、`ActingFor::AuditPersistenceError < ActingFor::InternalError` を既存errors.rbへ追加する。明示的transaction / retry / lock / Audit専用Serviceは追加しない。

## 5. Decision Value Object

`ActingFor::Decision` は `lib/acting_for/decision.rb` に配置する。ActiveRecord ModelでもServiceでもなく、Public APIとして利用されるValue Objectである。

Step 5で確定した以下のAPIを維持する。

```ruby
decision.status
decision.allowed?
decision.denied?
decision.approval_required?
```

statusは `:allow` / `:deny` / `:require_approval`。`require_approval != allow` であり、承認が必要な場合の `allowed?` はfalse。v0.1のDecision Public APIは `status` / `allowed?` / `denied?` / `approval_required?` の4つだけとする。`reason_code` / `matched_delegation_ids` / `context` 等の追加属性はPublic APIとして提供せず、`ActingFor::Decision.new(...)` のconstructorもPublic APIとして保証しない。Decisionは `ActingFor.authorize(...)` の戻り値として取得する（D050）。

D213により、Decisionは最小のimmutable Value Objectとして実装する。初期化後は `freeze` し、ActiveRecord ModelにはせずDBへ保存しない。`initialize(status)` は内部実装で利用可能だがPublic APIとして保証しない。不正なstatusは `ArgumentError` とし、`InvalidRequestError` へ変換しない。constructorをprivate化せずFactoryも追加しない。v0.1では `to_h`、独自 `==` / `hash` 等も追加しない。

## 6. Migration / DB Table Names

MigrationはGem側の `db/migrate/` で管理する。Rails Engine標準のMigration提供機構をHost開発者が明示的に実行し、Host Applicationの `db/migrate/` へ取り込む。DBへの適用はHost Applicationの通常のMigrationプロセスに委ねる。独自Migration DSL・独自Migration Generator・自動Migration実行機構は提供しない（D060・D064）。Gem install / Gem update / Application boot時には自動コピーしない。

初期schemaはAgent / Delegation / AuditEventの3つのMigrationへ分割し、1つにまとめない。第1節のファイル名は概念上の `create_acting_for_agents` / `create_acting_for_delegations` / `create_acting_for_audit_events` を示す設計例であり、D065時点で未決定だったtimestamp・filename・Migration Rubyコードは後続の実装で確定済み。実ファイル一覧は[CURRENT_STATE](CURRENT_STATE.md)を参照。

リリース済みMigrationは原則変更せず、schema変更には新しいMigrationを追加する。HostはGem更新時に追加Migrationを取り込み、通常のMigrationプロセスで適用する。独自schema versioning機構は作らない（D061）。リリース済みファイルは新規installation・旧versionからのupgrade・履歴保持のため原則削除せず、v0.1では過去Migrationのsquash・統合・削除を行わない（D062）。

Runtimeで独自Migration適用状況チェック、独自schema version管理、起動時Migration、自動Migration実行を行わない。管理・適用確認はHost Application / Rails / ActiveRecordの標準機構に委ねる（D063）。

Rails標準機構で安全にreversibleにできるMigrationはreversibleに設計する。独自rollback機構は提供せず、将来の全Migrationのrollback可能性までは保証しない。不可逆Migrationが必要となった場合の扱いは、その時点で別Decisionとして判断する（D066）。

Step 7時点では具体的なMigration内容・実コード・DB columnの最終型は確定しなかった。後続D032〜D034でResource IDのString保存、Agent unique index、AuditEventの一部保存型・制約を確定した。後続D043でAgent string型、principal_id string型、constraints / sanitized context / matched_delegation_idsのjson型・default・NOT NULLを確定した。後続D051・D052で3 Modelの主要DB型・NULL・CHECK・index・主キー、sanitized_contextの正式column名とAuditEventのupdated_at非設定を確定した。詳細は[Domain Model第17節](domain_model_v0_1.md#17-v01-テーブル構成)を正本とする。Migration実コードとRails標準taskは後続工程で実装・runtime検証済み。実施結果は[DECISIONS](DECISIONS.md)を参照。

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

`lib/acting_for.rb` は `ActingFor.authorize(...)` / `ActingFor.delegate(...)` の薄いPublic API Entry Pointとし、非自明なvalidation / normalizationを集中させず、内部Serviceへ委ねる（D192）。

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

Delegation API実装時に `lib/acting_for.rb` へ追加するrequireの設計例（既存requireを維持）：

```ruby
require "acting_for/errors"
```

手動requireを大量に追加する設計にはしない。app/servicesはRails / Zeitwerkに任せる。decision.rbの読み込みはDecisionを実装する後続段階で扱う。

Public Exceptionは `lib/acting_for/errors.rb` にまとめる（D191・D199）。次の実装単位では `ActingFor::Error < StandardError` と `ActingFor::InvalidRequestError < ActingFor::Error` のみを定義する。既設計のInternalError / AuditPersistenceErrorも必要な実装段階で同じファイルへ追加し、Exceptionごとのファイル分割・新しいException class・独自error code・追加属性は導入しない。今回はerrors.rbも作成しない。

## 9. Test Directory / Dummy Rails App

テストではDummy Rails Applicationを持つ構成を採用し、最低限 `test/dummy/` を想定する。Rails Engine integration、ActiveRecord、Migration、Rails autoload、Host Applicationとのintegrationを実際のRails環境で検証できるようにするためである。

Step 7時点では `test/` という構造のみを決め、Test Frameworkは未決定だった。後続の[Step 8 Test Strategy](test_strategy_v0_1.md)（D029）で **Minitest採用・RSpec不採用** を確定した。Unit / Integrationの境界と検証シナリオはStep 8正本に従う。`test/dummy` は最小Rails integration hostとし、sample product / demo applicationにはしない。最小Dummy Rails Appは実装済み。正式Minitest suiteはD221〜D228で実装・検証済み。

D221により、正式Minitest suiteの最初の実装単位は `test/test_helper.rb`、`Rake::TestTask`、`test/unit/decision_test.rb`、`test/unit/constraint_evaluator_test.rb` とする。`test_helper` は `test/dummy` Rails環境と `rails/test_help` を利用し、正式実行コマンドは `bundle exec rake test`、discoveryは `test/**/*_test.rb`。Public API Integration Testは後続へ分離し、CIはまだ実装しない。

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

gemspecへ設定済みのv0.1のversion constraintはRuby `>= 3.4`, `< 4.1`、Rails `>= 8.0`, `< 8.2` とする。dependencyとしてinstall可能であることと正式サポートは区別し、正式サポートはD046のCI matrixで検証済みの組み合わせだけとする。今回はgemspecを作成・変更しない（D047）。

ActingForは **MIT License** で公開する。LICENSE / gemspecへMITを明記済みで、今回は変更しない（D048）。

## 12. Public / Internal Boundary

| 境界 | 対象 |
| --- | --- |
| Public | `ActingFor.authorize`、`ActingFor.delegate`、`ActingFor::Decision`、`ActingFor::Agent`、`ActingFor::Delegation`、`ActingFor::AuditEvent` |
| Internal | `ActingFor::Internal::*` |

Internalは利用者向けAPIではなく、READMEでは原則としてInternal APIを利用例に示さない。Public APIから内部実装を分離し、内部クラス名・構造を将来変更可能にする。

後続D031のPublic Exceptionは `ActingFor::Error` / `ActingFor::InvalidRequestError` / `ActingFor::InternalError` / `ActingFor::AuditPersistenceError`。D199で配置を `lib/acting_for/errors.rb` と確定した。段階的な実装範囲は第8節に従う。

この分類はStep 5のPublic APIの細部を追加確定するものではない。Step 7時点で保留していた `ActingFor.delegate(...)` の全引数・default・validationとdelegate!非提供は後続D032で確定した。ModelをPublicに分類することも、DelegationをActiveRecord直接操作中心にする意味ではない。

Public分類はDecision constructorや任意Model更新の保証ではない。D049のcaller認証・認可はHost責務、D053のDelegation immutability、D054のatomic revoke!、D056のAuditEvent update / destroy禁止をModel / Public境界にも適用する。Model制約とrevoke!は実装済み。delegate / authorize / Decisionは実装・検証済み。

## 13. 未決定事項と次工程

後続D049〜D056でcaller authorizationのHost境界、Decision Public APIの4項目への限定・constructor非保証、3 Modelの主要DB型・NULL・CHECK・主要index・bigint主キー、DelegationのModel-level immutability、revoke!の並行実行契約、Constraint complexity非提供、AuditEventのModel-level append-onlyを確定した。詳細schemaの正本は[Domain Model第17節](domain_model_v0_1.md#17-v01-テーブル構成)。Migration / Modelsは実装済み。詳細な進捗は[PROGRESS](PROGRESS.md)を参照。

以下は引き続き未決定であり、本書では追加確定しない。

- Authorization queryは実装済み。Internal SQL / private method構成はPublic互換性保証外。
- install generatorの将来設計（v0.1では独自Generatorを作らない）
- Approval Workflow、MCP Adapter、OAuth / OIDC Adapterの具体設計・実装

| Step | 状態 |
| --- | --- |
| Step 4 Domain Model Design | Complete |
| Step 5 Public API Design | Complete / 10 of 10 / Design finalized |
| Step 6 README Quick Start Design | Complete / Design-stage Quick Start finalized |
| Step 7 Gem Structure Design | Complete / Design finalized / 基盤実装済み |
| Step 8 Test Strategy | Complete / Design finalized / Test suite implemented（D221〜D228） |

D190〜D230の実装・検証は完了。次工程はD231結果を確認したうえで、別途明示承認後のActual Release。Gemは **Not released**。
