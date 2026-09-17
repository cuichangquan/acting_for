# ActingFor v0.1 Domain Model Design

更新日：2026-09-17

Step 4の基本方針（[D013](DECISIONS.md#d013-v01のドメインモデル基本方針)）と詳細ルール（[D014](DECISIONS.md#d014-v01-delegation判定constraintlifecycleaudit詳細)）を記録する。**Step 4は完了。** 実装済み仕様ではない。Public APIの後続決定は[Step 5の正本](public_api_v0_1.md)を参照。残る未確定事項は第22節に記録する。

### 更新履歴

- 2026-09-15 / D013：モデル構成、関連、委任・監査の基本方針を記録。
- 2026-09-15 / D014：matching、Resourceのnilの意味、Constraint、複数一致、Lifecycle、Audit詳細を確定。従来の単一 `delegation_id` 案は、複数一致を記録する `matched_delegation_ids` へ変更した。旧方針と理由はDECISIONSのD013と後続決定で追跡する。
- 2026-09-17 / D031〜D034：Step 4完了後の詳細化としてAudit Context、Exception、Resource identity、Delegation / Agent validation、AuditEvent詳細を確定。実装は行わない。

## 1. 目的

ActingFor v0.1では、次をRailsアプリ内部で判定するための最小ドメインモデルを定義する。

> 認証済みAgentが、Principalから委任された権限の範囲内で操作を実行できるか。

過剰なPolicy EngineやIdentity基盤は作らず、Agent、Delegation、Authorization、Decision、Auditの最小構成に集中する。

## 2. 全体構造

```text
Principal
    │ delegates authority
    ▼
Delegation ─── Agent
    │
    ▼
Authorization
    │
    ▼
Decision (allow / deny / require_approval)
    │
    ▼
AuditEvent
```

Rails上でDBへ永続化する主要Modelは3つとする。

| 概念 | 役割 | 専用DB Model |
| --- | --- | --- |
| Agent | Entity / ActiveRecord Model | 作る |
| Delegation | Entity / ActiveRecord Model | 作る |
| AuditEvent | Entity / ActiveRecord Model | 作る |
| Authorization | Service | 作らない |
| Decision | Value Object | 作らない |
| Action | Value | 作らない |
| Resource | Authorization対象の識別情報 | 作らない |
| Constraint | Delegation内の条件データ | 作らない |

正式用語のAudit Eventを、Model名では `AuditEvent` と表記する。

## 3. Agent

### 責務

> 認証済みの外部AgentをActingFor内部で識別するためのローカル表現。

ActingForはAgentの本人確認やAgent Identityの検証を行わない。

後続決定D026により、認証済み外部Agentをローカル `ActingFor::Agent` へresolveする責務もホストアプリにある。Userのような会員登録・ログインは前提にしない。AgentレコードのProvisioning方法はv0.1では固定せず、正式なProvisioning APIも追加しない。詳細は[Agent Registration / Resolution Boundary](PROJECT.md#24-agent-registration--resolution-boundary)を参照。モデル・属性・関連は変更しない。

```text
外部の接続・認証基盤（OAuth / OIDC / MCP / API Key / その他）
    ↓
Authentication
    ↓
Authenticated Agent
    ↓ Host Applicationがresolve
ActingFor::Agent
```

### 最小属性

```text
id
identifier
name
created_at
updated_at
```

`identifier` は必須・一意、`name` は任意とする。

```text
identifier: shopping-agent-abc123
name: Shopping Agent
```

### Agent validation（後続決定D033）

| 属性 | 許可する値 | 長さ（Model validation） | 一意性 |
| --- | --- | --- | --- |
| identifier | whitespace characterを一切含まないnon-blank String | 1..255文字 | ActiveRecord validation + DB unique index |
| name | nil、またはnon-blank String | 指定時1..255文字 | 不要。同名Agentを許可 |

identifierは必須。nil、空文字、whitespace-only、String以外、255文字超過、途中や前後にwhitespaceを含む値はvalidation error。implicit conversion、自動trim、downcase等は行わず、case-sensitive exact identityとする。`"shopping-agent"` / `"Shopping-Agent"` は有効で別identity、`"shopping agent"` / `" shopping-agent"` / `"shopping-agent "` は不正。

nameは任意だが、空文字、whitespace-only、String以外、255文字超過はvalidation error。自動trimは行わない。identifierが異なる `agent-001` / `agent-002` が同じname `"Shopping Agent"` を持ってよい。Agent Identityの一意性はidentifierのみで保証する。

長さはModel validation上の決定であり、DB columnのlimitやDB-level length constraintは未決定。一意性のDB unique indexは確定しているが、具体的なDB adapter対応・実装方式は今回決めない。

### Principalとの関係

Agent自身にはPrincipalを直接持たせない。`Agent belongs_to :principal` や `Agent belongs_to :user` という設計にはしない。

```text
Principal
    │
Delegation
    │
Agent
```

AgentとPrincipalの関係そのものをDelegationとして表現する。これにより、将来的に1つのAgentが複数PrincipalからDelegationを受ける構造にも対応できる。

## 4. Delegation

### 責務

> PrincipalがAgentへ与えた代理権限。

ActingForの中心となるModel。1件のDelegationの正式な意味は次のとおり。

> Agent A が、Principal P の代理として、Resource R に対して Action X を、Constraint C の範囲内で実行する権限 E を持つ。

```text
Delegation = Agent + Principal + Action + Resource Scope
             + Constraints + Effect + Validity
```

### 基本属性

```text
id
agent_id
principal_type
principal_id
action
resource_type
resource_id
effect
constraints
expires_at
revoked_at
created_at
updated_at
```

### Delegation作成のvalidation（後続決定D032）

作成は `ActingFor.delegate(agent:, principal:, action:, resource: nil, constraints: [], effect:, expires_at: nil)` のみで、delegate!は提供しない。agentはpersist済みActingFor::Agent、principalはpersist済みActiveRecord model instanceとする。actionはString / SymbolをStringへ正規化し、nil・空文字・その他typeはInvalidRequestError。effectはString / Symbolのallow / require_approvalだけで、必須・defaultなし。

resourceは第7節、constraintsは第8節、期限・取消は第10節に従う。成功時はpersist済みDelegationを返す。類似委任も許可し、各呼び出しは独立した新規Delegationを作る。dedup / upsert / semantic uniqueness / duplicate detectionは導入しない。詳細な入力とExceptionの契約は[Delegation API](public_api_v0_1.md#9-delegation-api)を正本とする。

## 5. Principal

PrincipalはActingFor内部専用Modelを作らず、ホストRailsアプリ側のModelを利用する。例は `User`、`Organization`、`Team`、`ServiceAccount`。

DelegationからPrincipalへはpolymorphic associationを利用する。

```ruby
belongs_to :principal, polymorphic: true
```

これにより特定の `User` Modelへ依存させない。

### 主キー型の制約

`principal_type` / `principal_id` で参照するため、`principal_id` の型は共通になる。たとえば `User` がbigint、`Organization` がUUIDなど、Principal候補ごとに主キー型が異なるアプリでは注意が必要。v0.1では万能化せず、この制約をドキュメントで明示する方向とする。

## 6. Action

Action専用テーブルは作らず、文字列として扱う。

```text
purchase
search
cancel_order
delete_account
```

v0.1では完全一致のみとする。`purchase.*`、`orders:*`、wildcard、regex、action hierarchyのような高度な表現は導入しない。汎用Policy Engine化を避けるためである。

## 7. Resource

Resource専用テーブルは作らず、Delegationの `resource_type` / `resource_id` で対象を表現する。

| 識別情報 | 正式な意味 |
| --- | --- |
| `resource_type: "Order"`, `resource_id: "123"` | Order #123のみ |
| `resource_type: "Order"`, `resource_id: nil` | Order全体 |
| `resource_type: nil`, `resource_id: nil` | Resourceを必要としないAction |
| `resource_type: nil`, `resource_id: "123"` | 不正 |

`resource_type: nil` は「全Resource」を意味しない。後続決定D032で `resource_id` の正式保存型を **String** とする。

ResourceはActiveRecord polymorphic associationにはせず、**Authorization用の識別情報**として扱う。将来、Virtual ResourceやExternal Resource等を扱える余地を残す。

### Public resourceからの正規化（後続決定D032）

Rails / ActiveModel-style Resource ClassまたはInstance、またはnilを受け付ける。String / HashをResource identifierとして直接渡すAPIは採用しない。

| Public入力 | resource_type | resource_id |
| --- | --- | --- |
| Resource instance | `resource.class.model_name.name` | `resource.id.to_s` |
| Resource Class | `resource.model_name.name` | nil |
| nil | nil | nil |

Classはmodel_nameを持つ必要がある。Instanceはclassからmodel_nameを解決でき、idを持ち、そのidがnilではなく、id.to_sが空文字でないことが必要。必要interfaceを持たないobject、instanceのidがnil / id.to_sが空文字の場合は `ActingFor::InvalidRequestError`。

IDはPublic API境界で1回だけto_sする。resource_typeは正規化後の文字列をcase-sensitiveで比較し、specific Resourceのresource_idも正規化後のStringを完全一致で比較する。case normalization、numeric coercion / conversion、追加のimplicit coercion、fuzzy matchingは行わない。

### Resource matchingのscope（D032の確認済み補足）

`resource: Product` はProduct型全体への委任という既存設計を維持する。Delegationのresource_typeが指定されresource_idがnilの場合、nilとの一致を要求するのではなく、そのresource_type全体を表すscopeとして扱う。同じ型の個別Resourceにもmatchし、異なる型にはmatchしない。

specific ResourceへのDelegationはresource_typeとresource_idの両方が厳密に一致した場合にmatchする。Delegationの両方がnilならResource-less Actionのscopeであり、Requestの両方がnilの場合にmatchする。全Resourceへの委任ではない。

以下はResource matchingのみの例。他のDelegation matching条件もすべて満たす必要がある。

| Delegation resource_type | Delegation resource_id | Request resource_type | Request resource_id | Resource match |
| --- | --- | --- | --- | --- |
| `"Product"` | `"123"` | `"Product"` | `"123"` | match |
| `"Product"` | `"123"` | `"Product"` | `"456"` | no match |
| `"Product"` | nil | `"Product"` | `"123"` | match |
| `"Product"` | nil | `"Product"` | `"456"` | match |
| `"Product"` | nil | `"Order"` | `"123"` | no match |
| nil | nil | nil | nil | match |

「完全一致」はscope内で比較する識別値の規則を表す。Resource matching全体を `(resource_type, resource_id)` の単純なtuple完全一致へ変更するものではない。

## 8. Constraint

Constraint専用テーブルは作らず、DelegationのJSON / JSONBとして保存する。Constraintの最終DB型は未決定であり、AuditEventのJSON保存とは別に扱う。

正式な基本形式は `Array<Constraint>` とし、各Constraintは `field`、`operator`、`value` を持つ。

```json
[
  { "field": "amount", "operator": "lte", "value": 10000 }
]
```

複数条件の例：

```json
[
  { "field": "amount", "operator": "gt", "value": 10000 },
  { "field": "amount", "operator": "lte", "value": 30000 }
]
```

複数Constraintは**AND**で評価し、すべて満たす必要がある。同じfieldを複数指定でき、上の例は `amount > 10000 AND amount <= 30000` を表す。

ContextのトップレベルKeyのみ参照できる。`order.amount`、`items[0].price` などのnested accessは非対応。

| 対応operator | 型ルール |
| --- | --- |
| `eq` | String / Integer / Boolean |
| `lt` / `lte` / `gt` / `gte` | Integer |
| `in` | Context側はscalar、Constraint側valueはString / Integer / BooleanのArray（D032） |

暗黙の型変換は禁止する。たとえばContextのamountが `"8900"`、Constraintが `amount <= 10000` の場合、文字列を整数に変換せずConstraint不成立とする。

- missing field、nilはConstraint不成立。
- invalid constraintはmatchさせない。
- fail closedを基本原則とする。
- 空Constraintは `[]`。作成APIの省略時も `[]` であり、明示的 `constraints: nil` はInvalidRequestError（D032）。
- Floatはv0.1のConstraint値として積極的に扱わず、金額等はInteger表現を推奨する。

作成時の後続決定D032：constraintsはArrayのみで、各要素はfield / operator / valueだけを必須keyとするHash。非Hash、必須key不足、extra keyはInvalidRequestError。keyはString / SymbolをStringへ正規化し、正規化後の重複は不正。fieldはnon-empty StringまたはSymbol、operatorは既定6種類のString / Symbolで、両者ともStringへ正規化する。valueは上表の型のみで暗黙変換しない。nested path検出用regex・命名規則は追加決定しない。これはPublic入力validationであり、Authorization時に保存済みのinvalid constraintをmatchさせない方針とは区別する。

Ruby Procや任意コードをDBへ保存しない。たとえば次のコードをDelegationへ保存する設計は採用しない。

```ruby
->(context) { context[:amount] <= 10_000 }
```

理由はAudit、安全性、serialization、バージョン管理、DB上での意味の確認が難しくなるためである。

v0.1ではConstraintを小さく保つ。OR、NOT、nested expressions、nested object access、regex、custom functions、arbitrary Ruby code、database query、resource traversal、cross-resource conditions、wildcardは作らない。

## 9. Delegation Effect

Delegationに保存するEffectは `allow` / `require_approval` とし、v0.1ではexplicit deny Delegationを作らない。**default deny**を採用する。denyはDecisionとして存在するが、Delegation effectとしては保存しない。

```text
一致する有効なDelegationが存在する
    → allow / require_approval

一致する有効なDelegationが存在しない
    → deny
```

委任設定の例：

```text
amount <= 10,000              → allow
10,000 < amount <= 30,000     → require_approval
それ以外                     → matching Delegationなし → deny
```

組み込みの金額ルールではない。explicit deny、priority、precedence、conflict resolutionを汎用的に扱うPolicy Engineへ拡大しないため、この構成にする。

## 10. Expiration / Revocation

Delegationは `expires_at` と `revoked_at` を持つ。有効条件は次のとおり。

```text
revoked_at == nil
AND
(
  expires_at == nil
  OR
  expires_at > current_time
)
```

`expires_at` が現在時刻と等しい場合は期限切れとなる。`revoked_at` が設定されていれば有効対象から除外する。

有効期限前でもDelegationを即時無効化できるようにする。Agentが侵害された場合などに停止でき、DELETEするよりもrevocationとして記録を残す方がAudit上も扱いやすい。

後続決定D032：作成時のexpires_atはnil / Time / ActiveSupport::TimeWithZoneのみ。String / Date / Integer等から暗黙parse・変換しない。指定時はActingFor trusted current timeより未来でなければInvalidRequestError。同時刻・過去は不正、nilは無期限。

作成APIはrevoked_atを受け付けず、新規時は必ずnil。通常Public APIの取消は `delegation.revoke!` のみでidempotent。初回にtrusted current timeを設定し、既にrevoked済みならExceptionにせず、最初のtimestampを保持して更新しない。Clock injection・競合制御の具体方式は未決定。

`starts_at` はv0.1では導入しない。

### Delegation lifecycle

Delegationの認可内容は原則immutableとして扱う。principal、agent、action、resource scope、constraints、effectを直接UPDATEしない。

```text
権限変更 = 旧Delegationをrevoke + 新Delegationをcreate
```

過去Auditが参照するDelegationの意味を壊さないためである。Gemの通常操作ではhard deleteを前提にしない。expired（期限切れ）とrevoked（取消）は区別する。

## 11. Authorization

AuthorizationはActiveRecord ModelではなくServiceとする。入力概念はAgent、Principal、Action、Resource、Context。

### Delegation matching

Authorization時は次の条件を**すべて**満たすDelegationだけがmatchする。1つでも満たさなければ、そのDelegationはmatchしない。

1. Agent一致
2. Principal一致
3. Action一致（完全一致）
4. Resource一致（第7節）
5. expiredしていない
6. revokedされていない
7. Constraintをすべて満たす

```text
Authorization Request (Agent / Principal / Action / Resource / Context)
    ↓
Agent一致 → Principal一致 → Action一致 → Resource一致
    ↓
Expiration確認 → Revocation確認 → Constraint評価
    ↓
Matching Delegations
    ├─ require_approvalが1件以上 → require_approval
    ├─ allowのみ                → allow
    └─ 0件                      → deny
    ↓
Decision
    ↓
AuditEvent
```

基本原則はfail closed。ActingForがauthorityを明確に確認できない場合はallowしない。後続決定D023により、Audit記録失敗時はDecisionを返さずExceptionで中断する（第22節）。

ActingForは業務処理を実行せず、ホストアプリがDecisionを適用する。`require_approval` は実行許可を意味しない。

## 12. Decision

DecisionはDB Modelにせず、Authorization結果を表すValue Objectとする。種類は `allow` / `deny` / `require_approval`。

後続決定D018で確定したPublic API（設計のみ・未実装）：

```ruby
decision.status
decision.allowed?
decision.denied?
decision.approval_required?
```

後続決定D017で、戻り値クラスは `ActingFor::Decision`、概念上の `decision.status` は `:allow` / `:deny` / `:require_approval` と確定した（未実装）。上記4つのPublic APIはD018で確定し、require_approvalの場合の `allowed?` は必ずfalseとする。永続化が必要なDecision情報はAuditEventへ記録する。

## 13. Delegationが複数一致した場合

正式な優先順位は次のとおり。

```text
require_approval > allow
```

| 一致する有効なDelegation | Decision |
| --- | --- |
| 0件 | `deny` |
| allowのみ | `allow` |
| require_approvalが1件以上 | `require_approval` |

ResourceやConstraintの具体性によるoverrideはしない。id、created_at、作成順による優先順位やpriorityフィールドは作らない。「specific rule wins」も導入しない。権限を上書きするPolicy Engineへ発展させず、判断できない場合はallowしない。

## 14. AuditEvent

AuditEventは、**ActingForがどのAuthorization Decisionを行ったか**を専用テーブル `acting_for_audit_events` に記録する。実際の業務処理が成功したかを記録する責務は持たない。

たとえばActingForがallowを返した後、PurchaseServiceが成功したか失敗したかはホストRailsアプリ側の責務である。

### 基本情報

| 観点 | 追跡する情報 |
| --- | --- |
| WHO | `agent_id`、`agent_identifier` |
| FOR WHOM | `principal_type`、`principal_id` |
| WHAT | `action`、`resource_type`、`resource_id` |
| WHY | `matched_delegation_ids`、`reason_code`、sanitized context |
| RESULT | `decision` |
| WHEN | `created_at` |

### matched_delegation_ids

**後続決定D034。**

単一delegation_id案を廃止し複数一致を記録するD014を維持する。常にArrayとしnilは禁止。denyでは必ず `[]`、allow / require_approvalでは1件以上の実際にmatchしたDelegation IDを保存する。

ID重複は許可しない。`[12, 18]` は有効、`[12, 12, 18]` は不正。match集合として扱い、配列順序に意味はない。`[12, 18]` と `[18, 12]` は同じ集合を表し、利用者は順序に依存しない。

JSON配列（`[]` / `[12, 18]` 等）として保存する。PostgreSQL固有のJSONBを必須とせず、新しい中間テーブルは作らない。Delegation ID自体のDB型や新しい制約は追加決定しない。

### reason_code

**後続決定D034：decisionとの整合性も含む。**

reason_codeは最終Authorization Decisionがなぜその結果になったかを表す。正式一覧と有効な組み合わせは以下の3組のみ。

| AuditEvent decision（DB String） | reason_code |
| --- | --- |
| `"allow"` | `delegation_allowed` |
| `"require_approval"` | `delegation_requires_approval` |
| `"deny"` | `no_matching_delegation` |

正常に保存されるAuthorization AuditEventでは両項目を必須とし、nilや未知の値を許可しない。Model validationを行い、両DB columnはNOT NULLとする。許可値を固定するDB CHECK constraintは設けない。

decision / reason_codeの組み合わせもModel validationで上表の3組だけを許可する。`allow` と `no_matching_delegation` 等はvalidation error。Public `ActingFor::Decision#status` のSymbol表現は変更せず、Audit DB表現だけStringとする。

個々のDelegationがmatchしなかった理由（expired / resource mismatch / constraint mismatch等）は単一reason_codeとして記録しない。API misuse / InternalError / AuditPersistenceError等のExceptionもDecision reason_codeの責務外。旧候補一覧はD014時点の履歴であり、D034の正式一覧へ置き換える。

### sanitized context（後続決定D031・D034）

Audit用に選択したContextをJSON objectとして保存する。例は `{"amount": 12000, "currency": "JPY"}`。保存対象なしは `{}` としraw Contextへfallbackしない。JSONBは必須としない。sanitized contextのDB default / NOT NULLは今回決めない。選択・型・禁止keyの規則は第16節に従う。

## 15. AuditEventの方針

AuditEventは基本的にappend-onlyとする。通常利用ではINSERTを中心とし、通常APIとしてupdate / destroyを前提にしない。Authorizationの結果を書き換えるのではなく、新しいAuditEventを追加して履歴を残す。DBレベルのWORMや暗号署名等まではv0.1で担当しない。

## 16. Audit Contextの安全性

Authorization Contextを無条件に保存しない。後続決定D031により、保存項目の選択は `ActingFor.authorize(..., audit_context_keys: [])` のallowlistのみとする。省略時はContextを保存せず `{}`。raw contextへのfallbackは禁止。

`Array<Symbol>`だけを許可し、重複Symbolは内部で除去する。ContextのトップレベルSymbol keyと完全一致し、String / Symbol変換・indifferent access・nested path解釈をしない。存在しないkeyは無視する。選択されたvalueはString / Integer / Float / BigDecimal / TrueClass / FalseClass / nilのみ。Hash / Array等のunsupported valueはsilent ignoreせずInvalidRequestErrorとする。

password、password_confirmation、token、access_token、refresh_token、api_key、secret、client_secret、credentialのSymbolはbuilt-in forbidden secret keys。allowlistへ指定した時点でInvalidRequestError。完全一致のみで判定し、token_count等をsubstring / regex / 推測で禁止しない。Hostは機密情報を選択しない責務を維持する。

custom Audit Filter / Sanitizer、Proc、callback、sanitizer class、global allowlist config、initializer設定はv0.1で提供しない。BigDecimalのJSON serialization表現は未決定。正式な入力例と詳細は[Audit Context selection](public_api_v0_1.md#10-audit)に従う。

## 17. v0.1 テーブル構成

ActingFor自身が作る主要テーブルは3つに限定する。

```text
acting_for_agents
acting_for_delegations
acting_for_audit_events
```

Action、Resource、Constraint、Decisionなどのために個別テーブルを増やさない。

## 18. Model関連

```text
Agent
    │ has_many
    ▼
Delegation
    │ belongs_to polymorphic
    ▼
Principal（ホストRailsアプリ）

AuditEvent
    ├─ Agent
    ├─ Principal
    └─ matched_delegation_ids（複数一致を配列で記録）
```

AgentとPrincipalを直接結び付けない。Delegationが、AgentがPrincipalの代理として行動する権限そのものを表す。

## 19. v0.1で意図的に作らないもの

- Action / Resource / Constraint / Decision / Authorizationの専用DB Model
- explicit deny rules
- Policy DSL language / generic policy language
- wildcard actions
- nested policy expressions
- custom executable constraints
- Policy priority engine

ActingForを汎用Policy Engineにはしない。

## 20. v0.1 ドメインモデル最終イメージ

```text
Principal (Host Rails App Model)
    ▲
    │ principal: polymorphic
Delegation
    ├─ agent ──────────────► Agent
    ├─ action                 ├─ identifier
    ├─ resource_type          └─ name
    ├─ resource_id
    ├─ effect
    ├─ constraints
    ├─ expires_at
    └─ revoked_at

Runtime Authorization

Agent / Principal / Action / Resource / Context
    ↓
Authorization Service
    ↓
Decision (allow / deny / require_approval)
    ↓
AuditEvent
```

## 21. 今回の重要な設計決定

1. DB ModelはAgent / Delegation / AuditEventの3つを中心とする。
2. AgentとPrincipalを直接関連付けず、その関係をDelegationで表現する。
3. PrincipalはホストRailsアプリ側のModelを利用し、polymorphic associationで参照する。
4. Action専用Modelを作らず、文字列として扱う。
5. Resource専用Modelを作らず、`resource_type` / `resource_id` で識別する。
6. Constraint専用Modelを作らず、JSON / JSONBで保存する。
7. Constraintには任意Rubyコードを保存しない。
8. v0.1ではConstraint Languageを小さく保つ。
9. DelegationのEffectは `allow` / `require_approval` とする。
10. denyはDelegationとして保存せず、default denyとする。
11. AuthorizationはServiceとして扱い、DB Modelにしない。
12. DecisionはValue Objectとして扱い、DB Modelにしない。
13. Delegationには `expires_at` を持たせる。
14. Delegationには即時取消のための `revoked_at` も持たせる。
15. AuditEventはappend-onlyを基本とする。
16. Authorization Contextを無条件にAuditへ保存しない。
17. ActingForを汎用Policy Engine化しない。
18. v0.1では最小構成を維持する。

## 22. 次に決めること

Step 4は完了。Step 5「Public API Design」も完了し、進捗は10 / 10、全項目がD015〜D025で決定済み。最新の決定範囲と10項目の進捗は[Step 5の正本](public_api_v0_1.md)を参照。後続決定D031〜D034でException、Audit Context、Resource、Delegation、Agent validation、AuditEvent詳細を確定した。次の事項は引き続き**未確定**。

- Decisionの追加属性
- D032〜D034で確定した範囲以外のDB schemaの型・制約（AgentのDB column length、Audit sanitized contextのDB default / NOT NULL、Constraint JSON / JSONBの最終DB型を含む）
- BigDecimalのJSON serialization、DB adapter正式対応範囲
- Clock injection、transaction / locking / isolation / retry、cache / replica、Retention等の[残るSecurity詳細](security_model_v0_1.md#27-今回決めないこと)
- Ruby / Rails対応バージョン
- Migrationの実コード・taskの具体的なコマンド名

Gem構成・配置、Rails標準Migration方式、v0.1での独自Generator非提供は[Step 7の正本](gem_structure_v0_1.md)（D028）で決定した。Domain Modelの仕様は変更せず、Gemは未実装のままとする。

### 既存認可とContextの後続決定（D024・D025）

Principal自身の現在の権限はホストアプリが実行時にも確認し、Delegation認可と両方を満たす場合のみ業務処理へ進む。Agentの実効権限はPrincipal自身の権限とDelegationされた権限の積集合であり、require_approvalも権限を拡張しない。ActingFor CoreはPundit等を直接呼ばない。

Context値の正確性・信頼性はホストの責務であり、Agent申告値を無条件に渡さず、必要に応じDB等で確認・確定する。ActingForは値の真偽を検証せずConstraintを評価する。Context形式不正はException、有効な形式での必要field不足はConstraint不成立・Delegation不一致とし、第8節のfail closedを維持する。trusted / untrusted Contextの仕組みは導入しない。詳細は[Step 5の正本](public_api_v0_1.md#12-existing-authorization-integration)を参照。Domain Model自体は変更しない。

### Auditの後続決定（D022・D023）

AuditEventは `ActingFor.authorize(...)` 内部で自動生成・保存し、保存後にDecisionを返す。保存失敗時はallowを返さず、denyへ変換せず、Decisionを返さず、Exceptionで処理を中断してBusiness Logicへ進ませない。後続決定D031でAudit保存失敗は `ActingFor::AuditPersistenceError` とし、lower-level persistence exceptionをwrapしてcauseを保持する。詳細は[Step 5のAudit設計](public_api_v0_1.md#10-audit)を参照する。
