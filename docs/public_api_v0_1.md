# ActingFor v0.1 Public API Design

更新日：2026-09-18

**状態：Design finalized / Partially implemented。** 本書をStep 5「Public API Design」の正本とする。進捗は **10 / 10**。全項目が設計決定済み（D015〜D025）で、**Step 5は完了（Design finalized）**。Gem skeleton / Migration / ActiveRecord Models / delegate / Decision / ConstraintEvaluator / Authorization core / authorizeの基本入力境界 / `audit_context_keys` sanitizationは実装済み。AuditEvent persistenceを含むAudit authorization integrationは未実装。

Step 5完了後のv0.1仕様詳細化としてD031〜D048を反映する。過去の完了履歴は維持し、現在のAPI・入力要件・Audit仕様は以下の後続決定に従う。D190〜D212によりDelegation Public APIの実装設計を詳細化した。現在地点は[CURRENT_STATE](CURRENT_STATE.md)、全体進捗は[PROGRESS](PROGRESS.md)を参照。

## 1. Purpose

完了済みの[Step 4 Domain Model Design](domain_model_v0_1.md)を前提に、RailsアプリがDelegationに基づく認可を要求するPublic APIを定義する。決定の理由と履歴は[DECISIONS](DECISIONS.md)で管理する。

## 2. Design principles

- PrincipalとAgentを別主体として明示し、Delegationを中心概念にする。
- ActingForはAgent Authenticationを担当せず、ホストアプリで認証済みのAgentを受け取る。
- Public APIと内部実装を分離する。内部Serviceの配置は[Step 7の正本](gem_structure_v0_1.md)（D028）を参照。
- CoreはMCPに依存せず、MCP Tool名とActingFor Actionを同一概念にしない。
- Step 4のAction完全一致、Resourceのnilの意味、Constraint評価、DecisionとAuditEventの責務を維持する。
- 汎用Policy Engineへ拡大せず、v0.1で過剰設計しない。

D026による補足：認証済み外部Agentからローカル `ActingFor::Agent` へのResolutionもホスト責務であり、Provisioning方法はv0.1では固定しない。本書の `current_agent` はホスト側の概念例であり、ActingFor提供のhelperではない。READMEでは認証・解決済みの `shopping_agent` を使う。[Agent Registration / Resolution Boundary](PROJECT.md#24-agent-registration--resolution-boundary)を参照。新しいPublic APIやStep 5の仕様変更は含まない。

## 3. Authorization Entry Point

**確定：D015 / Step 5項目1。** Public Entry Pointは `ActingFor.authorize(...)` とする。

以下は設計上の利用例であり、現在実行できるコードではない。

```ruby
decision = ActingFor.authorize(
  agent: current_agent,
  principal: current_user,
  action: :purchase,
  resource: product,
  context: {
    amount: product.price
  }
)
```

Railsアプリから短く書け、認可という責務とAgent / Principal / Actionを明示できる。

| 採用しないPublic API | 理由 |
| --- | --- |
| `ActingFor::Authorization.call(...)` | 内部Service構造を公開すると将来の内部変更を制限する |
| `agent.authorized_to?(:purchase)` | 誰の代理かを示すPrincipalが見えにくい |
| `principal.authorize_agent(...)` | Principal ModelへActingForのAuthorization責務を持ち込まない |

Publicは `ActingFor.authorize(...)`。後続のStep 7（D028）で内部Serviceを `ActingFor::Internal::Authorization` / `ActingFor::Internal::ConstraintEvaluator` として配置する設計を決定した。具体的実装は未決定で、内部構造は将来変更可能。Public APIの仕様は変更しない。

### Authorizationの実行境界（D036〜D039）

**Security Contract（D036・D037・D039）**

- `ActingFor::Decision` はauthorize実行時点の判定結果であり、再利用可能なauthorization token / capability / 権限証明ではない。過去のDecisionを保存・再利用して「認可済み」と扱わない。
- Host Applicationは保護対象Business Logicの実行に可能な限り近い時点でauthorizeする。
- cached Decisionを権限証明として再利用せず、cached Delegationを権限判定・authorization proofに使わない。
- Authorizationに必要なDelegation状態は、最新状態を期待できるauthoritative data sourceから読む。非同期Read Replicaはreplication lagによりstale Delegationを返す可能性があり、その安全性はActingForの保証範囲外。
- ActingForはBusiness Logicとのatomicity、DB locking / isolation levelによるTOCTOU防止を保証しない。v0.1ではDecision binding token / atomic execution APIを提供しない。

`ActingFor.authorize(...)` 自身は明示的なDB transactionを開始しない。概念上の順序はDelegation lookup → Authorization evaluation → Decision生成 → AuditEvent保存 → Decision return。保存失敗時は `ActingFor::AuditPersistenceError` をraiseし、Decisionを返さない。Host側Business Logicのtransaction管理はHost Applicationの責務。

v0.1のAuthorizationはDelegationへ `SELECT ... FOR UPDATE` 等の明示的なDB lockを取得しない。Decisionは実行時点で観測した状態に基づき、返却後からBusiness Logic実行までDelegationの有効性を保証しない。独自のtransaction isolation levelを要求・変更せず、READ COMMITTED / REPEATABLE READ / SERIALIZABLEを強制しない。Host Application / DB設定に従い、特定isolation levelによるatomicity / TOCTOU防止も保証しない（D036）。

v0.1ではAuthorization / Delegation作成 / AuditEvent保存を内部で自動retryしない。失敗は既存Exception方針で呼び出し元へ伝える。Hostがretryする場合、古いDecisionを再利用せず、必要に応じauthorizeから再評価する。delegateは呼ぶたび新規Delegationを作るため、内部自動retryによるduplicate Delegation作成を避ける（D038）。

ActingFor v0.1はAuthorization DecisionとDelegation lookup結果を内部cacheせず、Authorizationごとに現在の永続化状態を参照する。Host独自cacheの安全性は保証範囲外。Read Replica routing機能は提供しない（D039）。

詳細は[Security Model](security_model_v0_1.md#13-toctou-boundary)を参照。

## 4. authorize Arguments

**D016 / Step 5項目2を後続決定D031・D032で詳細化。** Public APIの引数形は次のとおり（シグネチャの設計表記）。

```ruby
ActingFor.authorize(
  agent:,
  principal:,
  action:,
  resource: nil,
  context: {},
  audit_context_keys: []
)
```

keyword argumentsのみを使用する。引数の意味や順番を取り違えないよう、次の位置引数形式は採用しない。

```ruby
# 不採用
ActingFor.authorize(agent, principal, :purchase, product, context)
```

| 引数 | 必須 / default | 意味 |
| --- | --- | --- |
| `agent:` | 必須 | 操作を要求する、ホストアプリ側で認証済みのAgent |
| `principal:` | 必須 | Agentが誰の代理として行動するかを表す「委任元」。Userに限定せず、Organization / Team / ServiceAccount等も想定する |
| `action:` | 必須 | 要求するAction |
| `resource:` | 任意 / `nil` | 特定Resource、Resource type全体、またはResource不要のAction |
| `context:` | 任意 / `{}` | 認可判定時の情報を持つHash |
| `audit_context_keys:` | 任意 / `[]` | Auditへ保存するContext項目のallowlist（`Array<Symbol>`）。第10節参照 |

### action

String / Symbolを受け付け、Symbolは `:purchase` → `"purchase"` のようにStringへ正規化する。nil、空文字、whitespace-only、String / Symbol以外は `ActingFor::InvalidRequestError`。自動trimせず、`" purchase "` はそのまま保持する（D032・D202）。

Action matchingはStep 4どおり完全一致。wildcard、regex、hierarchy、`purchase.*`、`orders:*` はv0.1では扱わない。このAction正規化は、Constraint値の暗黙の型変換を認めるものではない。

### resource

| 設計上の利用形 | 意味 |
| --- | --- |
| `resource: product` | 特定Resource |
| `resource: Product` | Resource type全体 |
| `resource: nil` | Resourceを必要としないAction |

**`resource: nil` は「すべてのResource」を意味しない。** Step 4のResource識別情報の設計を維持する。

### Public resourceからの正規化（後続決定D032）

Rails / ActiveModel-style Resource ClassまたはInstance、またはnilを受け付ける。String / HashをResource identifierとして直接渡すAPIは採用しない。

| Public入力 | resource_type | resource_id |
| --- | --- | --- |
| Resource instance | `resource.class.model_name.name` | `resource.id.to_s` |
| Resource Class | `resource.model_name.name` | nil |
| nil | nil | nil |

Classはmodel_nameを持つ必要がある。Instanceはclassからmodel_nameを解決でき、idを持ち、そのidがnilではなく、id.to_sが空文字でないことが必要。必要interfaceを持たないobject、instanceのidがnil / id.to_sが空文字の場合は `ActingFor::InvalidRequestError`。

Resource instanceはActiveRecord::Baseに限定せず、ActiveModel-style Resourceを許可する。`persisted?` / `to_model` / `to_param` / GlobalID / polymorphic associationは要求しない（D201）。

IDはPublic API境界で1回だけto_sする。resource_typeは正規化後の文字列をcase-sensitiveで比較し、specific Resourceのresource_idも正規化後のStringを完全一致で比較する。case normalization、numeric coercion / conversion、追加のimplicit coercion、fuzzy matchingは行わない。

Delegationのresource_typeが指定されresource_idがnilなら、その型全体へのscopeとして同じ型の個別Resourceにもmatchする。specific Resourceへの委任はtypeとIDの両方を厳密比較する。両方nilのDelegationはResource-less Requestにmatchする。「完全一致」は識別値の比較規則であり、Resource matching全体を単純なtuple完全一致にはしない。[Domain ModelのResource scopeと6例](domain_model_v0_1.md#7-resource)を参照。

### context

Hashを受け取る。例：

```ruby
context: {
  amount: 8_900,
  currency: "JPY"
}
```

Constraintが参照するのはトップレベルKeyのみ。次のHashの `order.amount` のようなnested object accessはv0.1のConstraint評価対象にしない。

D215により、Constraintのcanonical String fieldはSymbolへ変換してContextのトップレベルSymbol keyを厳密に参照する。`field: "amount"`は`context[:amount]`にmatchし、`context["amount"]`にはmatchしない。String / Symbolのindifferent accessやnested path解釈は行わない。field不存在または値nilはConstraint不成立とする。

```ruby
context: {
  order: {
    amount: 8_900
  }
}
```

Context値の正確性・信頼性はホストの責務とし、確認・確定した値を渡す。詳細は[Context Trust Boundary](#13-context-trust-boundary)（D025）を参照。

## 5. Decision

**確定：D017 / Step 5項目3。** `ActingFor.authorize(...)` はSymbolを直接返さず、`ActingFor::Decision` というValue Objectを返す設計とする。

```ruby
decision = ActingFor.authorize(...)
# 概念上：#<ActingFor::Decision status=:allow>

decision.status
# => :allow
```

`decision.status` を正式なPublic APIとして持つ（D018）。statusは次の3種類だけとする。

| status | 意味 |
| --- | --- |
| `:allow` | PrincipalからAgentへのDelegation上、その操作を実行可能であることが確認された |
| `:deny` | 有効なDelegationを確認できなかった等により、ActingForとして操作を許可しない |
| `:require_approval` | 自動実行してはいけない。Human Approvalが必要 |

ActingForの `allow` はRailsアプリ全体の最終認可を意味しない。Principal自身の現在の権限はホストが実行時にも確認し、両方の認可を満たす必要がある（[Existing Authorization Integration](#12-existing-authorization-integration)、D024）。

**`require_approval != allow`。** Approval Workflow自体はActingFor v0.1の責務ではない。

DecisionはActiveRecord ModelでもDBへ直接永続化するModelでもない。Decision自体を保存せず、必要な認可判定情報をActiveRecord ModelであるAuditEventへ記録する。AuditEventが記録するのはAuthorization Decisionであり、業務処理の結果ではない。

## 6. Decision Public API

**確定：D018 / Step 5項目4、後続D050。** 次の4つだけを正式Public APIとする。

v0.1のDecision Public APIは `status` / `allowed?` / `denied?` / `approval_required?` の4つだけとする。`reason_code` / `matched_delegation_ids` / `context` 等の追加属性はPublic APIとして提供せず、`ActingFor::Decision.new(...)` のconstructorもPublic APIとして保証しない。Decisionは `ActingFor.authorize(...)` の戻り値として取得する（D050）。

```ruby
decision.status
decision.allowed?
decision.denied?
decision.approval_required?
```

| status | allowed? | denied? | approval_required? |
| --- | --- | --- | --- |
| `:allow` | `true` | `false` | `false` |
| `:deny` | `false` | `true` | `false` |
| `:require_approval` | `false` | `false` | `true` |

**require_approvalの場合、`allowed?` は必ずfalse。** v0.1では類似APIを増やさず、`success?`、`permitted?`、`executable?` は提供しない。

### Decision実装方針（D213）

`ActingFor::Decision` は最小のimmutable Value Objectとする。ActiveRecord ModelにはせずDBへ永続化しない。statusは `:allow` / `:deny` / `:require_approval` の3種類だけとし、初期化後は `freeze` して状態変更不可とする。

`initialize(status)` は内部実装で利用してよいがPublic APIとして保証しない。不正なstatusはPublic入力不正ではなく内部プログラミングエラーとして `ArgumentError` とし、`ActingFor::InvalidRequestError` にはしない。constructorのprivate化やFactoryは導入しない。

既存D018 / D050のPublic APIを維持し、v0.1では `reason_code` / `matched_delegation_ids` / `context` / `success?` / `permitted?` / `executable?` / `to_h` / 独自 `==` / 独自 `hash` 等を追加しない。

## 7. deny vs Exception

**確定：D019 / Step 5項目5。** 通常の認可不成立と、API・システム上の異常を区別する。

| 分類 | 意味 | 例 |
| --- | --- | --- |
| `deny` | Authorizationとして正常に判定できたが、権限が成立しない | matching Delegationなし、expired、revoked、Constraint不成立、Resource不一致、Action不一致により有効な一致がない |
| Exception | Authorization処理そのものを正常に成立させられない | `agent: nil`、`principal: nil`、`action: nil`、`context: "invalid"`、API誤用、設定不正、内部異常 |

```text
Authorizationとして判断できた → Decision
Authorization処理そのものが成立しない → Exception
```

認可不成立は正常系であり、`decision.denied?` がtrueとなる。API誤用や内部異常をdenyへ潰さない。Step 4のmatching / Constraint評価ルール（D014）は維持する。たとえばinvalid constraintはmatchさせず、有効な一致がなければdenyとする。

### Exception classes（後続決定D031）

v0.1でActingFor自身が定義するException classは以下の4つだけとする（設計のみ）。

```ruby
ActingFor::Error < StandardError
ActingFor::InvalidRequestError < ActingFor::Error
ActingFor::InternalError < ActingFor::Error
ActingFor::AuditPersistenceError < ActingFor::InternalError
```

| Class | 用途 |
| --- | --- |
| `ActingFor::Error` | ActingFor定義Exceptionの共通基底 |
| `ActingFor::InvalidRequestError` | Public APIの入力・形式・利用方法の不正。不正action / effect / constraints / resource / audit_context_keys等 |
| `ActingFor::InternalError` | ActingFor自身が検出した内部・system-level errorの共通class |
| `ActingFor::AuditPersistenceError` | AuditEvent保存失敗専用。lower-level persistence exceptionをwrapし、Rubyの `cause` を保持する |

外部 / lower-layer exceptionは原則そのままraiseさせる。すべてをInternalErrorへ変換せず、明示的に設計決定されたものだけwrapする。Audit保存失敗ではDecisionを返さず、denyへ変換せず、Business Logicへ進ませない。ConstraintError / DelegationError / ConfigurationError等はv0.1では追加しない。

作成APIに不正なConstraintを渡す場合はInvalidRequestError（D032）。保存済みConstraintをAuthorization時に評価して不正・評価不能だった場合にmatchさせない既存ルールとは区別する。Model validation errorや外部例外を一律にInvalidRequestError / InternalErrorへwrapする決定ではない。

## 8. Bang API

**確定：D020 / Step 5項目6。** v0.1では `ActingFor.authorize!(...)` を提供しない。Public Authorization APIは `ActingFor.authorize(...)` のみ。

ActingForはallow / deny / require_approvalの3状態を持つため、Bang APIにはdeny / require_approvalをどうExceptionへ変換するかという追加の意味付けが必要になる。v0.1では導入せず、必要性が明確になった場合にv0.2以降で再検討できる。

## 9. Delegation API

**D021の専用API方針を後続決定D032で詳細化（設計のみ・未実装）。** 作成Public APIは `ActingFor.delegate(...)` のみ。v0.1では `ActingFor.delegate!` を提供しない。認可内容はimmutableで、変更はrevoke + createとする。

### 作成シグネチャ

```ruby
ActingFor.delegate(
  agent:,
  principal:,
  action:,
  resource: nil,
  constraints: [],
  effect:,
  expires_at: nil
)
```

keyword argumentsの設計表記。`effect:` は必須でdefaultなし。`resource:` / `expires_at:` は省略時nil、`constraints:` は省略時 `[]`。成功時は **persist済み `ActingFor::Delegation`** を返し、unsaved recordを成功として返さない。

D190〜D212でD032を詳細化し、`ActingFor.delegate(...)` を次の実装対象とする。既存 `Delegation#revoke!` を利用し、この実装単位ではAuthorization / Decision / Audit authorization integrationへ進まない。以下は確定設計であり、delegateの実装完了を意味しない。

### 入力validation

次の要件に反する入力は `ActingFor::InvalidRequestError` とする。

| 引数 | 許可する入力 / 正規化 | 不正例 |
| --- | --- | --- |
| `agent:` | `is_a?(ActingFor::Agent)` かつ `persisted?` | nil、別class、unsaved Agent |
| `principal:` | `is_a?(ActiveRecord::Base)` かつ `persisted?` | nil、非ActiveRecord object、unsaved record |
| `action:` | String / Symbol。SymbolのみStringへ正規化。trimしない | nil、空文字、whitespace-only、String / Symbol以外 |
| `resource:` | 第4節のRails / ActiveModel-style Class / Instance、またはnil | String / Hashの直接識別子、必要interfaceなし、instanceのidがnil / id.to_sが空文字 |
| `effect:` | `"allow"` / `:allow` / `"require_approval"` / `:require_approval`。SymbolのみString化 | deny、nil、大文字、前後空白、alias、未知値、その他type |
| `constraints:` | `Array<Constraint>`。条件なしは `[]` | 明示的nil、Array以外 |
| `expires_at:` | nil / Time / ActiveSupport::TimeWithZone。指定時はActingFor trusted current timeより未来 | String、Date、DateTime、Integer等、現在と同時刻、過去 |

`expires_at: nil` は無期限。指定時は `expires_at > ActingFor.current_time` を検証する。parse / 暗黙のTime変換 / timezone変換 / 丸めは行わず、正常なTime / ActiveSupport::TimeWithZone objectをそのままActiveRecordへ渡す（D209）。時刻取得は内部の共通境界 `ActingFor.current_time` に集約し、通常は `Time.current` を返す。Expiration / Revocation / Authorization等は直接 `Time.current` を呼ばない。v0.1ではClock差し替えPublic API（`ActingFor.clock =` / `ActingFor.reset_clock!`）を提供しない。TestではRails time helper（`travel_to` 等）を使う（D035）。explicit deny Delegationは作らない。

Agentは完全class一致を要求しない。Public API内でidentifier検索・Agent自動作成・Resolution・Authenticationをしない（D204）。Principal ID型を独自検証せず、`principal: principal` をRails polymorphic associationへ渡す。principal_type / principal_idを手動生成しない（D197・D203）。Resourceの識別値は第4節の規則でActingFor側が正規化する。

Action / effectとも任意objectのto_sを使わない。effectはtrim・downcase・alias変換をせず、`"ALLOW"` / `" allow "` / `"require-approval"` は不正（D202・D205）。

### Constraint validation

各Constraintは `field` / `operator` / `value` の3つだけを必須keyとするHash。非Hash、必須key不足、未知のextra keyはInvalidRequestError。Hash keyはSymbol / Stringのみを受け付け、Stringへ正規化する。他のkey型は不正であり、HashWithIndifferentAccess的な曖昧な扱いは導入しない（D206）。ただし `{ field: "amount", "field" => "price", ... }` のような正規化後の重複keyはInvalidRequestErrorとする。

| 項目 | 許可する入力 / 正規化 |
| --- | --- |
| `field` | non-empty StringまたはSymbol。内部ではString。nested path非対応 |
| `operator` | String / Symbolのeq / lt / lte / gt / gte / inのみ。内部ではString |
| `value`（eq） | String / Integer / Boolean |
| `value`（lt / lte / gt / gte） | Integer |
| `value`（in） | String / Integer / BooleanのArray |

表のtype・値以外はInvalidRequestError。field / operatorはSymbolのみString化し、trim・downcase・任意objectのto_sを使わない。valueにはString数値→Integer、Symbol→String、Float→Integer等の変換をせず、`in` Array要素も変換しない（D207）。ConstraintのAND評価とAuthorization時のfail-closedは維持する。

D212により未決定の意味的ルールは追加しない。fieldはnon-emptyでありnon-blankではないため `field: "   "` を許可する。`operator: "in", value: []` および `value: [1, 1, 2]` も許可する。field命名regex、空in Array拒否、dedup、sort、意味的な有用性判定を追加しない。

### 入力非破壊と保存・Exception境界

Public境界でagent / principalを検証し、actionとeffectをcanonical String、resourceをresource_type / resource_id、constraintsをcanonical `Array<Hash<String, ...>>` に正規化する。expires_atは検証済みTime系objectまたはnil、revoked_atはnilとし、Modelはcanonical formの最終防御を担当する（D194）。

呼び出し元のconstraints Array、各Constraint Hash、`in` value Arrayを破壊的変更しない。必要な新しいArray / Hashを生成し、deep_freezeや汎用DeepCopy utilityは導入しない（D200）。

Public validation / normalizationの後に `ActingFor::Delegation.create!` を1回だけ呼び、事前に `valid?` を呼ばない。正常時はpersist済みDelegationを返す。Public仕様違反は `ActingFor::InvalidRequestError`、canonical化後の予期しない `ActiveRecord::RecordInvalid` やDB exceptionは一律wrapせず原則そのまま伝播する。独自transaction / retryは追加しない（D193・D198）。

次の実装単位では `ActingFor::Error < StandardError` と `ActingFor::InvalidRequestError < ActingFor::Error` だけを実装予定とし、既設計のInternalError / AuditPersistenceErrorは必要になる段階まで待つ（D191）。配置と呼び出し構造は[Gem Structure](gem_structure_v0_1.md)に従う。

InvalidRequestErrorというException classはPublic contract。messageは原因を理解できる具体的内容にするが、全文の完全一致はcontractにしない。複数不正時にどの入力を先に検出するかというvalidation順序も保証しない（D210・D211）。

### Revocation / duplicate Delegation

`ActingFor.delegate(...)` は `revoked_at:` を引数として受け付けず、新規Delegationは必ず `revoked_at = nil` で開始する。通常Public APIでの取消は `delegation.revoke!` のみ。

`revoke!` はidempotent。初回はActingFor trusted current timeをrevoked_atへ設定する。既にrevoked済みならExceptionにせず、2回目以降は更新せずに最初のrevocation timestampを保持する。

類似Delegationの存在は新規作成を禁止しない。各delegate呼び出しで独立した新しいDelegationを作り、dedup / upsert / semantic uniqueness / duplicate detectionは導入しない。

ActingFor v0.1はDelegation作成・取消callerのAuthentication / Authorizationを提供しない。Host Applicationが事前に認証・認可してから `ActingFor.delegate(...)` / `delegation.revoke!` を呼ぶ。caller authorization用の `actor:` / `current_user:` 等のPublic APIは追加しない（D049）。

persist済みDelegationの `agent` / `principal` / `action` / `resource_type` / `resource_id` / `constraints` / `effect` / `expires_at` はModelレベルでも変更禁止とし、validation等で誤更新を防ぐ。期限延長・短縮も旧Delegationのrevoke + 新Delegationのcreateで表す。通常lifecycleで変更可能な状態属性は `revoked_at` のみ（通常のRails timestamp更新は別）。v0.1ではDB triggerによるimmutability強制は行わず、D053を詳細化したD177・D187によりdirty change validationを実装済みで、revoked_atの通常saveも拒否する。

`Delegation#revoke!` は並行実行時にもidempotentとする。対象IDと `revoked_at IS NULL` を条件とするatomic updateを用い、最初に永続化されたrevoked_atを保持する。後続呼び出しはtimestampを書き換えず、既にrevokedでもExceptionにしない。explicit row lockは使わない。revoked_atが変更された場合は通常のRails timestampとしてupdated_atも更新する。時刻は `ActingFor.current_time` を使う。D179・D188によりconditional updateを実装済み。時刻を1回取得してrevoked_at / updated_atへ同じ値を設定後reloadし、2回目以降は両timestampを保持する。unsaved recordはActiveRecord::RecordNotSavedとなる。

## 10. Audit

**確定：D022・D023 / Step 5項目8。** AuditEvent生成・保存は `ActingFor.authorize(...)` 内部で自動的に行い、Rails開発者に `ActingFor.audit(decision)` のような追加呼び出しを要求しない。Audit記録忘れを防ぐためである。

```text
ActingFor.authorize(...)
        ↓
Authorization
        ↓
Decision生成
        ↓
AuditEvent保存
        ↓
Decisionを返す
```

### Audit保存失敗時

AuditEvent保存に失敗した場合はExceptionとして処理を中断する。Authorization結果がallowでも、AuditEvent INSERTに失敗した場合はallowを返さず、denyへ変換せず、Decisionを返さず、Business Logicへ進ませない。

これは権限不足ではなくシステム異常であり、後続決定D031により `ActingFor::AuditPersistenceError` をraiseする。lower-level persistence exceptionをwrapし、Rubyのcauseを保持する。allow / deny / require_approvalの全結果に同じ方針を適用する。

Step 4のAudit責務とappend-onlyを維持する。後続決定D031でAudit Context選択を、D034でreason_code正式一覧とAuditEvent保存要件を確定した。

### Audit Context selection（後続決定D031）

`audit_context_keys:` はAuditEventへ保存するContext項目を選ぶ唯一のPublic allowlistとする。optional keywordでdefaultは `[]`。省略時・保存対象なしのAudit Contextは `{}` とし、raw `context` をfallbackとして保存しない。Authorizationには元のContextを使い、Audit用の選択と混同しない。

```ruby
ActingFor.authorize(
  agent: shopping_agent,
  principal: current_user,
  action: :purchase,
  resource: product,
  context: { amount: 100, currency: "JPY" },
  audit_context_keys: [:amount, :currency]
)
```

| 入力 / 条件 | 扱い |
| --- | --- |
| `Array<Symbol>` | 許可。例：`[:amount, :currency]` |
| nil、`:amount`、`["amount"]`、`[:amount, "currency"]` | `ActingFor::InvalidRequestError` |
| 重複Symbol（`[:amount, :amount]`） | 許可し、内部で重複除去。Exceptionにしない |
| 指定keyがcontextにない | 無視。Exceptionにしない |
| Symbol keyの完全一致 | `:amount` は `{ amount: 100 }` にmatchし、`{ "amount" => 100 }` にはmatchしない |

String / Symbolの暗黙変換やindifferent accessは行わない。対象はトップレベルkeyのみで、`:"order.amount"` をnested pathとして解釈しない。nested path構文や判定規則は新設しない。

D219により、key選択時は上記Symbol key完全一致を維持し、選択後の `sanitized_context` ではcanonical keyをStringとする。たとえば `context: { amount: 100 }` と `audit_context_keys: [:amount]` からは `{ "amount" => 100 }` を生成する。Authorization用Context自体のkeyは変換せず、呼び出し元のHashも破壊しない。

選択されたkeyの保存可能valueは **String / Integer / Float / BigDecimal / TrueClass / FalseClass / nil** のみ。Hash / Array / その他structured・unsupported valueが選択された場合はsilent ignoreせずInvalidRequestErrorとする。sanitized Audit ContextのBigDecimalはFloatへ変換せず、精度を失わない10進数StringとしてJSONへ保存する。例：`BigDecimal("12345.67")` → JSON `"12345.67"`。その他の既決定scalar型の仕様は変更しない（D044）。Audit用の型規則からConstraint値の対応型を拡大しない。

以下はbuilt-in forbidden secret keys。contextに存在するかにかかわらず、allowlistへ指定した時点でInvalidRequestErrorとし保存を許可しない。

```ruby
[:password, :password_confirmation, :token, :access_token,
 :refresh_token, :api_key, :secret, :client_secret, :credential]
```

判定は完全一致のみ。`:access_token` / `:token` は禁止、`:token_count` は許可されるkey。substring / regex / 推測によるsecret判定は導入しない。Hostは別名keyのvalueを含め、機密情報をAuditへ選択しない責務を引き続き持つ。

v0.1ではcustom Audit Filter、custom Sanitizer、Proc、callback、sanitizer class、global allowlist config、initializer設定を提供しない。選択方法は `audit_context_keys:` のみ。

正式column名は `sanitized_context` とし、raw Authorization Context用の `context` columnは作らない（D052）。sanitized contextはJSON objectとして保存し、対象なしは `{}`。JSONBは必須ではなく、DB schemaは `json` / `default: {}` / `null: false` とし、全体としてnilは保存しない（D043）。reason_code、decisionとの整合性、matched_delegation_idsの保存要件は[AuditEvent詳細](domain_model_v0_1.md#14-auditevent)（D034）に従う。

## 11. MCP Boundary

既存決定D012を維持する。MCPは「AI Agentと外部システムをつなぐ共通の接続規格」、簡単にいえば「AI用の共通API接続ルール」と捉える。

- MCP：Agentがアプリへどう接続・操作するか。
- ActingFor：そのAgentが誰の代理として、その操作を実行してよいか。

```text
Agent
 ↓
MCPでpurchase Toolを呼ぶ
 ↓
Rails Application
 ↓
ActingForで代理権限を確認
 ↓
allow / deny / require_approval
 ↓
Host Applicationが結果を適用
```

ActingFor CoreへMCP固有Objectを入れず、MCP Tool名とActingFor Actionを同一概念にしない。ホスト認可とContextの責任分界は第12・13節に従う。

## 12. Existing Authorization Integration

**確定：D024 / Step 5項目9。** Principal自身がその操作を実行する権限を持つかは、ホストRailsアプリケーションが判断する。ActingForが判断するのは **Principal → AgentのDelegation** のみ。

ホストはPundit、CanCanCan、Action Policy、独自Authorizationなどを利用できる。ActingForはこれらに依存せず、Coreから `Pundit.authorize(...)` 等を直接呼ばない。

### 二段階の認可と実効権限

Business Logicの実行には、次の両方が必要となる。

```text
① Host Application Authorization
   Principal本人にその操作を実行する権限がある
        AND
② ActingFor Authorization
   その操作がPrincipalからAgentへ委任され、実行が許可される
```

```text
Agent Request
    ↓
Authentication
    ↓
Principalを特定
    ↓
Host Authorization
    ↓
ActingFor Authorization
    ↓ 両方を通過した場合のみ
Business Logic
```

重要原則：

```text
Agentの実効権限 = Principal自身の権限 ∩ Delegationされた権限
```

Delegationが存在しても、Principal本人が持たない権限をAgentへ与えることはできない。Delegationを権限昇格の仕組みにしない。

### ホストアプリ側の利用イメージ

以下は設計上の概念例であり、実装済みAPIやQuick Startではない。Punditが認可対象の主体として `current_user`（この操作のPrincipal）を使用するホスト構成を前提とする。

```ruby
authorize product, :purchase?

decision = ActingFor.authorize(
  agent: current_agent,
  principal: current_user,
  action: :purchase,
  resource: product,
  context: {
    amount: product.price
  }
)

if decision.allowed?
  PurchaseService.call(product)
end
```

`authorize product, :purchase?` はPrincipal自身の権限を確認し、`ActingFor.authorize(...)` はPrincipalからAgentへの委任を確認する。両者は別の責務であり、ホスト認可を通過しない場合は業務処理へ進めない。

### 実行時の確認とApproval

Delegation作成時の権限確認だけでは不十分。たとえばDay 1にPrincipalがpurchase権限を持ちAgentへ委任していても、Day 30にPrincipalがその権限を失った場合、残存するDelegationだけを根拠にpurchaseを許可してはいけない。**Principalの現在の権限は実行時にもホストアプリで確認する。**

`require_approval` もPrincipalに存在しない権限を作り出さない。

```text
Principal自身に権限なし → STOP
Principal自身に権限あり + ActingFor = require_approval → Approval Workflowへ
```

ApprovalはPrincipalの権限を拡張しない。`require_approval` はallowではなく、Approval Workflow自体は引き続きホストの責務とする。今回、Authorization Adapter、`host_authorizer:`、`principal_authorizer:` やApproval Workflowの詳細は設計しない。

## 13. Context Trust Boundary

**確定：D025 / Step 5項目10。** Contextの正確性・信頼性はホストアプリの責務。ActingForは渡された値が現実世界やDB上で正しいかを検証せず、そのContextを使ってConstraintを評価する。

### Agent申告値とホストによる値の確定

Agentが `{"product_id": 123, "amount": 8000}` と申告しても、実際の商品価格は30,000円かもしれない。申告されたamountを無条件にContextへ渡してはいけない。ホストが必要に応じてDB等の信頼できる情報源から再取得・確認して値を確定する。

以下はContext構築の設計例。業務実行には第12節のホスト認可も必要となる。

```ruby
product = Product.find(params[:product_id])

decision = ActingFor.authorize(
  agent: current_agent,
  principal: current_user,
  action: :purchase,
  resource: product,
  context: {
    amount: product.price,
    currency: product.currency
  }
)
```

```text
Agent入力
    ↓
Host Application：検証 / DB再取得 / 値の確定
    ↓
Context
    ↓
ActingFor：Constraint評価
```

| 責任主体 | 責務 |
| --- | --- |
| Host Application | Context値が正しいか確認する |
| ActingFor | 渡されたContextで `amount <= 10_000`、`currency == "JPY"` 等のConstraintを評価する |

ActingFor自身はProductのDB取得、商品価格の確認、外部サービスによるcurrency確認、Resource所有者の確認、Agent申告値とDB値の比較などのBusiness Logicを実行しない。

v0.1では `trusted_context:` / `untrusted_context:` の別APIや、`TrustedContext`、`VerifiedContext`、`ContextVerifier` を導入しない。ホストアプリが責任を持ってContextを確定してから渡す、というルールに留め、過剰設計しない。Audit保存時のFilter / Sanitizerは別の責務であり、既存方針を維持する。

### API形式不正と必要field不足

| 入力 | 扱い |
| --- | --- |
| `context: "hello"` のようにHashではなく、Context形式自体が不正 | Exception。Authorization結果のdenyではない |
| `context: {}` のように形式は有効だが、Constraintが必要とするamount等のfieldがない | Constraint不成立。そのDelegationはmatchしない |

必要field不足はStep 4のfail closedを維持する。有効なmatching Delegationがなければdenyとなる。形式不正のPublic入力は後続決定D031のInvalidRequestErrorに従う。

**ActingForはContext値の真偽を検証するのではなく、ホストアプリが責任を持って確定したContextを受け取る。** API形式の確認とConstraint評価は、この責任分界と区別する。

### 入力規模・実行環境・Audit運用（D040〜D042）

v0.1ではAuthorization context全体とsanitized Audit Contextに固定byte上限をPublic仕様として設けず、1 DelegationあたりのConstraint件数にも固定上限を設けない。HostはAuthorizationに必要な最小限のContextだけを渡し、汎用データ搬送手段として使わないことを推奨する。Auditは `audit_context_keys:` で明示的に選択した必要最小限の値だけを保存し、Constraintも認可に必要な最小限の条件へ保つ（D041）。

v0.1はAuthorization専用timeout設定・timeout APIを提供しない。DB / request / job等のtimeoutはHost Application / 実行環境の責務。ActingFor CoreのAuthorization処理に外部ネットワーク呼び出しを持ち込まない（D042）。

AuditEventは通常運用でappend-onlyとし、v0.1では削除用Public APIを提供しない。固定retention period、自動削除、自動アーカイブは設けない。保持期間・削除・アーカイブはHost Applicationの運用責務で、サービスのセキュリティ要件・法令・社内規程等に応じて決定する（D040）。

v0.1ではConstraint complexity score、深さ制限、動的complexity判定、complexity engineを提供しない。固定Constraint件数上限・固定byte上限・Authorization専用timeoutを設けない既存方針を維持する。eq / lt / lte / gt / gte / in、nested pathなし、任意Ruby codeなし、複数ConstraintはANDという小さい言語で複雑性を抑え、Hostには必要最小限のConstraint利用を推奨する（D055）。

persist済みAuditEventのupdate / destroyをModelレベルでも禁止する。新しいAudit情報は常に新規INSERTで記録する。v0.1ではDB trigger、WORM storage、cryptographic signingによるDB / storage-level強制は行わない。Host側retention責務は変更しない。D183によりpersist後のreadonlyを実装済みで、update / destroyはActiveRecord::ReadOnlyRecordとなる。

## 14. Open Questions

Step 5の10項目は完了。後続決定D031〜D034でException class、Audit Context選択、Resource identity、Delegation API / validation、Agent validation、AuditEvent詳細を確定した。後続D035〜D048で時刻・実行境界・運用方針・DB schemaの一部・BigDecimal・対応環境・ライセンスを確定した。後続D049〜D056でcaller authorizationのHost境界、Decision Public APIの4項目への限定・constructor非保証、3 Modelの主要DB型・NULL・CHECK・主要index・bigint主キー、DelegationのModel-level immutability、revoke!の並行実行契約、Constraint complexity非提供、AuditEventのModel-level append-onlyを確定した。詳細schemaの正本は[Domain Model第17節](domain_model_v0_1.md#17-v01-テーブル構成)。基盤の実装状況は[CURRENT_STATE](CURRENT_STATE.md)を参照。delegate / authorize / Decision / Audit authorization integrationは未実装。

Gem構成・配置、Rails標準Migration方式、独自Generator非提供は[Step 7の正本](gem_structure_v0_1.md)（D028）で設計決定済み。Migration / Models / revoke!は実装・検証済み。D190〜D212によりdelegateの実装設計を確定した。Authorization query等の未対象事項は引き続き後続工程で扱う。

## 15. Step 5 Progress

Step 4は完了。Step 5「Public API Design」も **10 / 10、Complete**。後続のStep 6は **Complete / Design-stage Quick Start finalized**（D027）。最新の進捗は[PROGRESS](PROGRESS.md)、設計例は[README](../README.md#quick-start)を参照。Gemの基盤は実装済みだが未リリースで、delegate / authorizeの例はまだ実行不可。

| 項目 | 内容 | 状態 |
| --- | --- | --- |
| 1 | Authorization entry point | 決定済み（D015） |
| 2 | authorizeの引数仕様 | 決定済み（D016） |
| 3 | Decisionの形 | 決定済み（D017） |
| 4 | Decision Public API | 決定済み（D018） |
| 5 | denyとExceptionの境界 | 決定済み（D019） |
| 6 | Bang API（authorize!） | 決定済み（D020：v0.1では提供しない） |
| 7 | Delegation操作API | 決定済み（D021） |
| 8 | Audit / Audit failure | 決定済み（D022・D023） |
| 9 | 既存認可（Pundit / CanCanCan等）との関係 | 決定済み（D024） |
| 10 | Contextの信頼境界 | 決定済み（D025） |

設計決定は実装完了を意味しない。本更新ではGem本体、Model、Service、Decision class、AuditEvent、migration、generator、spec / test、Gem version、gemspec依存関係を作成・変更しない。
