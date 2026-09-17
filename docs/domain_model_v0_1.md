# ActingFor v0.1 Domain Model Design

更新日：2026-09-17

Step 4の基本方針（[D013](DECISIONS.md#d013-v01のドメインモデル基本方針)）と詳細ルール（[D014](DECISIONS.md#d014-v01-delegation判定constraintlifecycleaudit詳細)）を記録する。**Step 4は完了。** 実装済み仕様ではない。Public APIの後続決定は[Step 5の正本](public_api_v0_1.md)を参照。残る未確定事項は第22節に記録する。

### 更新履歴

- 2026-09-15 / D013：モデル構成、関連、委任・監査の基本方針を記録。
- 2026-09-15 / D014：matching、Resourceのnilの意味、Constraint、複数一致、Lifecycle、Audit詳細を確定。従来の単一 `delegation_id` 案は、複数一致を記録する `matched_delegation_ids` へ変更した。旧方針と理由はDECISIONSのD013と後続決定で追跡する。
- 2026-09-17 / D049〜D056：Public境界、主要DB schema、immutability、revoke! concurrency、Constraint complexity、Audit append-onlyを確定。D034の許可値CHECK非設定をD052で更新。設計のみ・未実装。
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

後続D043でidentifier / nameのDB型は `string` と確定。Model validationは1..255文字、identifierのDB unique indexを維持する。v0.1ではDB-level length CHECK constraintを追加しない。正式対応DBはPostgreSQLのみ（D045）。

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

ActingFor v0.1はDelegation作成・取消callerのAuthentication / Authorizationを提供しない。Host Applicationが事前に認証・認可してから `ActingFor.delegate(...)` / `delegation.revoke!` を呼ぶ。caller authorization用の `actor:` / `current_user:` 等のPublic APIは追加しない（D049）。

## 5. Principal

PrincipalはActingFor内部専用Modelを作らず、ホストRailsアプリ側のModelを利用する。例は `User`、`Organization`、`Team`、`ServiceAccount`。

DelegationからPrincipalへはpolymorphic associationを利用する。

```ruby
belongs_to :principal, polymorphic: true
```

これにより特定の `User` Modelへ依存させない。

### 主キー型の制約

後続D043により `Delegation#principal_id` はDB上で `string` とする。persist済みPrincipalのbigint `123` は `"123"`、UUIDはその文字列として扱い、特定主キー型へ固定しない。異なるPrincipal ID型とのassociation / AuthorizationはIntegration Testで検証する設計とする。

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

Constraint専用テーブルは作らず、`Delegation#constraints` は `json` / `default: []` / `null: false` とする。Ruby側で評価し、JSON内部のDB queryはPublic契約にしない。jsonbは必須としない（D043）。

v0.1ではAuthorization context全体とsanitized Audit Contextに固定byte上限をPublic仕様として設けず、1 DelegationあたりのConstraint件数にも固定上限を設けない。HostはAuthorizationに必要な最小限のContextだけを渡し、汎用データ搬送手段として使わないことを推奨する。Auditは `audit_context_keys:` で明示的に選択した必要最小限の値だけを保存し、Constraintも認可に必要な最小限の条件へ保つ（D041）。

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

v0.1ではConstraint complexity score、深さ制限、動的complexity判定、complexity engineを提供しない。固定Constraint件数上限・固定byte上限・Authorization専用timeoutを設けない既存方針を維持する。eq / lt / lte / gt / gte / in、nested pathなし、任意Ruby codeなし、複数ConstraintはANDという小さい言語で複雑性を抑え、Hostには必要最小限のConstraint利用を推奨する（D055）。

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

作成APIはrevoked_atを受け付けず、新規時は必ずnil。通常Public APIの取消は `delegation.revoke!` のみでidempotent。初回にtrusted current timeを設定し、既にrevoked済みならExceptionにせず、最初のtimestampを保持して更新しない。時刻取得は内部の共通境界 `ActingFor.current_time` に集約し、通常は `Time.current` を返す。Expiration / Revocation / Authorization等は直接 `Time.current` を呼ばない。v0.1ではClock差し替えPublic API（`ActingFor.clock =` / `ActingFor.reset_clock!`）を提供しない。TestではRails time helper（`travel_to` 等）を使う（D035）。 Authorizationのtransaction / locking / isolationはD036、TOCTOU境界はD037に従う。`Delegation#revoke!` は並行実行時にもidempotentとする。対象IDと `revoked_at IS NULL` を条件とするatomic updateを用い、最初に永続化されたrevoked_atを保持する。後続呼び出しはtimestampを書き換えず、既にrevokedでもExceptionにしない。explicit row lockは使わない。revoked_atが変更された場合は通常のRails timestampとしてupdated_atも更新する。時刻は `ActingFor.current_time` を使う。具体的なActiveRecord / Ruby / SQL実装は未決定（D054）。

`starts_at` はv0.1では導入しない。

### Delegation lifecycle

persist済みDelegationの `agent` / `principal` / `action` / `resource_type` / `resource_id` / `constraints` / `effect` / `expires_at` はModelレベルでも変更禁止とし、validation等で誤更新を防ぐ。期限延長・短縮も旧Delegationのrevoke + 新Delegationのcreateで表す。通常lifecycleで変更可能な状態属性は `revoked_at` のみ（通常のRails timestamp更新は別）。v0.1ではDB triggerによるimmutability強制は行わず、具体的なcallback・validationのRuby実装は未決定（D053）。

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

`ActingFor.authorize(...)` 自身は明示的なDB transactionを開始しない。概念上の順序はDelegation lookup → Authorization evaluation → Decision生成 → AuditEvent保存 → Decision return。保存失敗時は `ActingFor::AuditPersistenceError` をraiseし、Decisionを返さない。Host側Business Logicのtransaction管理はHost Applicationの責務。

v0.1のAuthorizationはDelegationへ `SELECT ... FOR UPDATE` 等の明示的なDB lockを取得しない。Decisionは実行時点で観測した状態に基づき、返却後からBusiness Logic実行までDelegationの有効性を保証しない。独自のtransaction isolation levelを要求・変更せず、READ COMMITTED / REPEATABLE READ / SERIALIZABLEを強制しない。Host Application / DB設定に従い、特定isolation levelによるatomicity / TOCTOU防止も保証しない（D036）。

ActingFor v0.1はAuthorization DecisionとDelegation lookup結果を内部cacheせず、Authorizationごとに現在の永続化状態を参照する。Host独自cacheの安全性は保証範囲外。Read Replica routing機能は提供しない（D039）。

## 12. Decision

DecisionはDB Modelにせず、Authorization実行時点の結果を表すValue Objectとする。再利用可能な権限証明ではない（D037）。種類は `allow` / `deny` / `require_approval`。

後続決定D018で確定したPublic API（設計のみ・未実装）：

```ruby
decision.status
decision.allowed?
decision.denied?
decision.approval_required?
```

後続決定D017で、戻り値クラスは `ActingFor::Decision`、概念上の `decision.status` は `:allow` / `:deny` / `:require_approval` と確定した（未実装）。上記4つのPublic APIはD018で確定し、require_approvalの場合の `allowed?` は必ずfalseとする。永続化が必要なDecision情報はAuditEventへ記録する。

v0.1のDecision Public APIは `status` / `allowed?` / `denied?` / `approval_required?` の4つだけとする。`reason_code` / `matched_delegation_ids` / `context` 等の追加属性はPublic APIとして提供せず、`ActingFor::Decision.new(...)` のconstructorもPublic APIとして保証しない。Decisionは `ActingFor.authorize(...)` の戻り値として取得する（D050）。

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

JSON配列（`[]` / `[12, 18]` 等）として保存する。PostgreSQL固有のJSONBを必須とせず、新しい中間テーブルは作らない。後続D043でDB schemaは `json` / `default: []` / `null: false` とする。後続D051・D052によりDelegation主キーはbigint、配列内部IDはJSON number / Integerとし、Stringへ変換しない。Array・Integerのみ・重複なし・Decisionとの件数整合性はModel / Authorization内部ロジックで保証し、JSON内部用DB CHECKは設けない。

### reason_code

**後続決定D034：decisionとの整合性も含む。**

reason_codeは最終Authorization Decisionがなぜその結果になったかを表す。正式一覧と有効な組み合わせは以下の3組のみ。

| AuditEvent decision（DB String） | reason_code |
| --- | --- |
| `"allow"` | `delegation_allowed` |
| `"require_approval"` | `delegation_requires_approval` |
| `"deny"` | `no_matching_delegation` |

正常に保存されるAuthorization AuditEventでは両項目を必須とし、nilや未知の値を許可しない。Model validationを行い、両DB columnはNOT NULLとする。後続D052によりdecision / reason_codeそれぞれに許可値3値を固定するDB CHECK constraintを設ける。Rails enum / PostgreSQL enumは使わない。D034のCHECK非設定はこの2項目について更新された。組み合わせ用DB CHECKは設けない。

decision / reason_codeの組み合わせもModel validationで上表の3組だけを許可する。`allow` と `no_matching_delegation` 等はvalidation error。Public `ActingFor::Decision#status` のSymbol表現は変更せず、Audit DB表現だけStringとする。

個々のDelegationがmatchしなかった理由（expired / resource mismatch / constraint mismatch等）は単一reason_codeとして記録しない。API misuse / InternalError / AuditPersistenceError等のExceptionもDecision reason_codeの責務外。旧候補一覧はD014時点の履歴であり、D034の正式一覧へ置き換える。

### sanitized_context（後続決定D031・D034・D052）

正式column名は `sanitized_context`。raw Authorization Context用の `context` columnは作らない。

Audit用に選択したContextをJSON objectとして保存する。例は `{"amount": 12000, "currency": "JPY"}`。保存対象なしは `{}` としraw Contextへfallbackしない。JSONBは必須としない。後続D043でDB schemaは `json` / `default: {}` / `null: false` とし、全体としてnilは保存しない。選択・型・禁止keyの規則は第16節に従う。

## 15. AuditEventの方針

persist済みAuditEventのupdate / destroyをModelレベルでも禁止する。新しいAudit情報は常に新規INSERTで記録する。v0.1ではDB trigger、WORM storage、cryptographic signingによるDB / storage-level強制は行わない。Host側retention責務は変更しない。具体的なModel実装は未決定（D056）。

AuditEventは通常運用でappend-onlyとし、v0.1では削除用Public APIを提供しない。固定retention period、自動削除、自動アーカイブは設けない。保持期間・削除・アーカイブはHost Applicationの運用責務で、サービスのセキュリティ要件・法令・社内規程等に応じて決定する（D040）。

## 16. Audit Contextの安全性

Authorization Contextを無条件に保存しない。後続決定D031により、保存項目の選択は `ActingFor.authorize(..., audit_context_keys: [])` のallowlistのみとする。省略時はContextを保存せず `{}`。raw contextへのfallbackは禁止。

`Array<Symbol>`だけを許可し、重複Symbolは内部で除去する。ContextのトップレベルSymbol keyと完全一致し、String / Symbol変換・indifferent access・nested path解釈をしない。存在しないkeyは無視する。選択されたvalueはString / Integer / Float / BigDecimal / TrueClass / FalseClass / nilのみ。Hash / Array等のunsupported valueはsilent ignoreせずInvalidRequestErrorとする。

password、password_confirmation、token、access_token、refresh_token、api_key、secret、client_secret、credentialのSymbolはbuilt-in forbidden secret keys。allowlistへ指定した時点でInvalidRequestError。完全一致のみで判定し、token_count等をsubstring / regex / 推測で禁止しない。Hostは機密情報を選択しない責務を維持する。

custom Audit Filter / Sanitizer、Proc、callback、sanitizer class、global allowlist config、initializer設定はv0.1で提供しない。sanitized Audit ContextのBigDecimalはFloatへ変換せず、精度を失わない10進数StringとしてJSONへ保存する。例：`BigDecimal("12345.67")` → JSON `"12345.67"`。その他の既決定scalar型の仕様は変更しない（D044）。正式な入力例と詳細は[Audit Context selection](public_api_v0_1.md#10-audit)に従う。

## 17. v0.1 テーブル構成

ActingFor自身が作る主要テーブルは3つに限定する。

```text
acting_for_agents
acting_for_delegations
acting_for_audit_events
```

Action、Resource、Constraint、Decisionなどのために個別テーブルを増やさない。

### DB schema詳細の正本（D043・D051・D052）

以下は概念schemaであり、Migration実コードではない。3 Modelの `id` はRails標準のbigint primary keyとし、v0.1ではUUID切替機構を提供しない。表で明記したdefault以外のdefaultは追加決定しない。

#### acting_for_agents

| Column | DB type | NULL | default / 補足 |
| --- | --- | --- | --- |
| id | bigint | 不可 | primary key |
| identifier | string | 不可 | unique index |
| name | string | 可 | duplicate可 |
| created_at | datetime | 不可 | Rails timestamp |
| updated_at | datetime | 不可 | Rails timestamp |

identifierはrequired / uniqueでModel validation 1..255文字。nameはoptionalで指定時1..255文字。両者にDB length CHECKは設けない。第3節の既存validationを維持する。

#### acting_for_delegations

| Column | DB type | NULL | default / 補足 |
| --- | --- | --- | --- |
| id | bigint | 不可 | primary key |
| agent_id | bigint | 不可 | FK → acting_for_agents.id、単独index |
| principal_type | string | 不可 | Host polymorphic model |
| principal_id | string | 不可 | Principal IDの文字列表現 |
| action | string | 不可 | String完全一致 |
| resource_type | string | 可 | 第7節のResource scope |
| resource_id | string | 可 | Resource IDの文字列表現 |
| effect | string | 不可 | allow / require_approval |
| constraints | json | 不可 | `[]` |
| expires_at | datetime | 可 | defaultなし。NULLは無期限 |
| revoked_at | datetime | 可 | defaultなし。NULLは未取消、日時ありは取消済み |
| created_at | datetime | 不可 | Rails timestamp |
| updated_at | datetime | 不可 | Rails timestamp。revoke!でrevoked_at変更時も更新 |

- agent_idのForeign Keyにcascade deleteを使わない。Delegationが存在するAgentの削除はDB Foreign Keyで拒否し、Agent削除に伴うDelegation自動削除はしない。通常の権限無効化は `delegation.revoke!` を使う。
- PrincipalはHostのpolymorphic model。bigint `123` → `"123"`、UUID → UUID Stringとして保存し、Host Principal tableへのDB Foreign Keyは設けない。
- action一覧をDB enum / DB CHECKで固定せず、Model / Public APIで有効性を検証する。
- Resourceは `"Product" / "123"`（specific）、`"Product" / NULL`（型全体）、`NULL / NULL`（Resource不要Action）が有効。`resource_type IS NULL AND resource_id IS NOT NULL` はModel validationとDB CHECKで禁止する。Resource tableへのDB Foreign Keyは設けない。
- effectはModel validation + DB CHECKでallow / require_approvalの2値のみ許可する。Rails enum / PostgreSQL enumは使わない。
- constraintsのArray形式・field / operator / value構造等はModel / Public APIで検証し、JSON内部構造用DB CHECKは設けない。jsonbを必須としない。
- expires_at / revoked_atにDB CHECKや単独indexは追加しない。期限判定は `expires_at == nil OR expires_at > ActingFor.current_time` を維持し、同時刻はexpired。
- Authorization lookup用複合indexは **(agent_id, principal_type, principal_id, action, resource_type)**。resource_id / expires_at / revoked_atは含めない。追加indexは先回りせず、必要時に利用状況・実測をもとに後続検討する。

#### acting_for_audit_events

| Column | DB type | NULL | default / 補足 |
| --- | --- | --- | --- |
| id | bigint | 不可 | primary key |
| agent_id | bigint | 不可 | Authorization時点のsnapshot |
| agent_identifier | string | 不可 | Authorization時点のsnapshot |
| principal_type | string | 不可 | Authorization時点のidentity snapshot |
| principal_id | string | 不可 | Authorization時点のidentity snapshot |
| action | string | 不可 | Authorization時点のsnapshot |
| resource_type | string | 可 | Resource snapshot |
| resource_id | string | 可 | Resource snapshot |
| decision | string | 不可 | allow / deny / require_approval |
| reason_code | string | 不可 | 第14節の正式3値 |
| matched_delegation_ids | json | 不可 | `[]`。内部IDはJSON number / Integer |
| sanitized_context | json | 不可 | `{}` |
| created_at | datetime | 不可 | Authorization時点のappend-only record |

- updated_atは持たない。作成後更新されない記録のためである。
- Foreign Keyは設けない。Agent情報はsnapshotとして保存し、Agent record lifecycleとAudit履歴を強く結合しない。Host Principal / Resource tableへのForeign Keyも設けない。
- action一覧をDB enum / DB CHECKで固定しない。
- Resource semanticsはDelegationと同じ。`"Product" / "123"`、`"Product" / NULL`、`NULL / NULL` を許可し、`NULL / "123"` はModel validation + DB CHECKで禁止する。
- decisionはModel validation + DB CHECKでallow / deny / require_approvalの3値のみ許可。reason_codeもdelegation_allowed / delegation_requires_approval / no_matching_delegationの3値のみ許可。Rails enum / PostgreSQL enumは使わない。D034の両columnの許可値CHECK非設定をD052で更新した。
- decision / reason_codeの正式3組は第14節のModel validationで保証し、組み合わせ用DB CHECKは設けない。
- matched_delegation_idsはStringへ変換せず `[12, 18, 25]` のように保存する。Array・Integerのみ・重複なし・順序に意味なし・denyは[]・allow / require_approvalは1件以上という要件はModel / Authorization内部ロジックで保証する。JSON内部用DB CHECKは設けない。
- sanitized_contextには `audit_context_keys:` allowlistとbuilt-in validationを通った値だけを保存する。raw Context用context columnやraw Contextへのfallbackは設けない。jsonbを必須としない。
- v0.1設計段階でprimary key以外の検索用indexを追加決定しない。agent_id、principal_type + principal_id、decision、created_at等にも先回りで付けず、Audit検索API・管理画面・分析要件と利用状況の確認後に検討する。

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
    ├─ Agent snapshot（DB Foreign Keyなし）
    ├─ Principal snapshot（DB Foreign Keyなし）
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
6. Constraint専用Modelを作らず、jsonで保存する（D043）。
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

Step 4は完了。Step 5「Public API Design」も完了し、進捗は10 / 10、全項目がD015〜D025で決定済み。最新の決定範囲と10項目の進捗は[Step 5の正本](public_api_v0_1.md)を参照。後続決定D031〜D034でException、Audit Context、Resource、Delegation、Agent validation、AuditEvent詳細を確定した。

D035〜D048で時刻・実行境界・cache / replica・保持方針・上限・timeout・DB schemaの一部・BigDecimal・対応環境・ライセンスを確定した。後続D049〜D056でcaller authorizationのHost境界、Decision Public APIの4項目への限定・constructor非保証、3 Modelの主要DB型・NULL・CHECK・主要index・bigint主キー、DelegationのModel-level immutability、revoke!の並行実行契約、Constraint complexity非提供、AuditEventのModel-level append-onlyを確定した。詳細schemaの正本は[Domain Model第17節](domain_model_v0_1.md#17-v01-テーブル構成)。実装は引き続きNot implemented。

次の事項は引き続き**未確定**。

- Model validation / callback、revoke!の具体的ActiveRecordコード、Authorization queryの具体的SQL
- Migrationの実コード・taskの具体的なコマンド名
- その他の[残るSecurity詳細](security_model_v0_1.md#27-今回決めないこと)

Gem構成・配置、Rails標準Migration方式、v0.1での独自Generator非提供は[Step 7の正本](gem_structure_v0_1.md)（D028）で決定した。Domain Modelの仕様は変更せず、Gemは未実装のままとする。

### 既存認可とContextの後続決定（D024・D025）

Principal自身の現在の権限はホストアプリが実行時にも確認し、Delegation認可と両方を満たす場合のみ業務処理へ進む。Agentの実効権限はPrincipal自身の権限とDelegationされた権限の積集合であり、require_approvalも権限を拡張しない。ActingFor CoreはPundit等を直接呼ばない。

Context値の正確性・信頼性はホストの責務であり、Agent申告値を無条件に渡さず、必要に応じDB等で確認・確定する。ActingForは値の真偽を検証せずConstraintを評価する。Context形式不正はException、有効な形式での必要field不足はConstraint不成立・Delegation不一致とし、第8節のfail closedを維持する。trusted / untrusted Contextの仕組みは導入しない。詳細は[Step 5の正本](public_api_v0_1.md#12-existing-authorization-integration)を参照。Domain Model自体は変更しない。

### Auditの後続決定（D022・D023）

AuditEventは `ActingFor.authorize(...)` 内部で自動生成・保存し、保存後にDecisionを返す。保存失敗時はallowを返さず、denyへ変換せず、Decisionを返さず、Exceptionで処理を中断してBusiness Logicへ進ませない。後続決定D031でAudit保存失敗は `ActingFor::AuditPersistenceError` とし、lower-level persistence exceptionをwrapしてcauseを保持する。詳細は[Step 5のAudit設計](public_api_v0_1.md#10-audit)を参照する。
