# ActingFor v0.1 Domain Model Design

更新日：2026-09-15

Step 4の基本方針（[D013](DECISIONS.md#d013-v01のドメインモデル基本方針)）と詳細ルール（[D014](DECISIONS.md#d014-v01-delegation判定constraintlifecycleaudit詳細)）を記録する。**Step 4は完了。** 実装済み仕様ではない。Public APIの後続決定は[Step 5の正本](public_api_v0_1.md)を参照。残る未確定事項は第22節に記録する。

### 更新履歴

- 2026-09-15 / D013：モデル構成、関連、委任・監査の基本方針を記録。
- 2026-09-15 / D014：matching、Resourceのnilの意味、Constraint、複数一致、Lifecycle、Audit詳細を確定。従来の単一 `delegation_id` 案は、複数一致を記録する `matched_delegation_ids` へ変更した。旧方針と理由はDECISIONSのD013と後続決定で追跡する。

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

```text
外部の接続・認証基盤（OAuth / OIDC / MCP / API Key / その他）
    ↓
Authentication
    ↓
Authenticated Agent
    ↓
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

`resource_type: nil` は「全Resource」を意味しない。例の文字列表記はDB型の決定ではなく、`resource_id` の正式DB型は未確定。

ResourceはActiveRecord polymorphic associationにはせず、**Authorization用の識別情報**として扱う。将来、Virtual ResourceやExternal Resource等を扱える余地を残す。

## 8. Constraint

Constraint専用テーブルは作らず、DelegationのJSON / JSONBとして保存する。

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
| `in` | Context側はscalar、Constraint側valueはArray |

暗黙の型変換は禁止する。たとえばContextのamountが `"8900"`、Constraintが `amount <= 10000` の場合、文字列を整数に変換せずConstraint不成立とする。

- missing field、nilはConstraint不成立。
- invalid constraintはmatchさせない。
- fail closedを基本原則とする。
- 空Constraintは `[]` とする。NULLと `[]` を使い分けず `[]` へ統一する方向とする。
- Floatはv0.1のConstraint値として積極的に扱わず、金額等はInteger表現を推奨する。

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

基本原則はfail closed。ActingForがauthorityを明確に確認できない場合はallowしない。Audit記録失敗時の扱いは別途未確定（第22節）。

ActingForは業務処理を実行せず、ホストアプリがDecisionを適用する。`require_approval` は実行許可を意味しない。

## 12. Decision

DecisionはDB Modelにせず、Authorization結果を表すValue Objectとする。種類は `allow` / `deny` / `require_approval`。

将来のAPIイメージ（未確定）：

```ruby
decision.allowed?
decision.denied?
decision.approval_required?
```

後続決定D017で、戻り値クラスは `ActingFor::Decision`、概念上の `decision.status` は `:allow` / `:deny` / `:require_approval` と確定した（未実装）。上記メソッド等の具体的なDecision APIはStep 5項目4で決める。永続化が必要なDecision情報はAuditEventへ記録する。

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

従来の単一 `delegation_id` 案は廃止し、複数Delegationが同時にmatchするため `matched_delegation_ids` に置き換える（D014）。新しい中間テーブルは作らず、v0.1ではJSON / JSONB等の配列で十分とする方針。

```text
複数一致: matched_delegation_ids: [12, 18]
一致なしのdeny: matched_delegation_ids: []
```

### reason_code

Auditでreason_codeを利用する。正式一覧は**未確定**。以下は候補例であり、確定仕様ではない。

- `delegation_matched`
- `no_matching_delegation`
- `authorization_error`
- `invalid_constraint`

Public API / Audit詳細設計で最終決定する。

## 15. AuditEventの方針

AuditEventは基本的にappend-onlyとする。通常利用ではINSERTを中心とし、通常APIとしてupdate / destroyを前提にしない。Authorizationの結果を書き換えるのではなく、新しいAuditEventを追加して履歴を残す。DBレベルのWORMや暗号署名等まではv0.1で担当しない。

## 16. Audit Contextの安全性

Authorization時に渡されたContextを、そのままAuditEventへ保存してはいけない。password、access token、credit card information、email body、personal information、secretなどが含まれる可能性があるためである。

```text
Authorization Context
    ↓
Audit Filter / Sanitizer
    ↓
AuditEvent Context
```

AuditEventには必要最小限の情報だけを保存する。例は `amount`、`currency`、`order_id`。Audit機能そのものが情報漏洩リスクにならない設計とする。基本方針はallowlist方式を優先し、保存してよい項目だけを選択する方向とする。全項目を保存して危険項目を削除する方式を基本にしない。Filter / SanitizerのPublic APIは未確定。

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

Step 4は完了。Step 5「Public API Design」は進行中で、項目1〜3はD015〜D017で決定済み。最新の決定範囲と10項目の進捗は[Step 5の正本](public_api_v0_1.md)を参照。次の事項は引き続き**未確定**。

- Public APIの残り（Step 5項目4〜10）と例外の具体的な扱い
- Decisionの具体的なAPIと追加属性（第12節のpredicateメソッドは候補）
- reason_codeの正式一覧（第14節の一覧は候補）
- Audit failure policy
- Filter / SanitizerのPublic API
- DB schemaの細かな型・制約、resource_idの正式DB型
- Ruby / Rails対応バージョン
- migration / generator構成

### Audit失敗時の扱い（未確定）

Authorizationの判定がallowでも、AuditEvent INSERTに失敗した場合に、allowを維持するか、denyへ倒すか、例外にするかは未確定。v0.1の仕様としてここでは固定せず、Step 5以降で検討する。
