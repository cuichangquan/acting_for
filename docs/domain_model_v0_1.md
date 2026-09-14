# ActingFor v0.1 Domain Model Design

更新日：2026-09-15

Step 4で決めたドメインモデルの基本方針を記録する（[D013](DECISIONS.md#d013-v01のドメインモデル基本方針)）。実装済み仕様ではない。「案」「候補」「方向」「想定」と記した項目、および末尾の詳細ルールは未確定とする。

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

ActingForの中心となるModel。1件のDelegationは概念的に、あるAgentが、あるPrincipalの代理として、あるResourceに対して、あるActionを、一定のConstraintの範囲内で実行する権限を表す。

### 最小属性案

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

v0.1では原則として完全一致とする。`purchase.*`、`orders:*`、wildcard、regex、action hierarchyのような高度な表現は導入しない。汎用Policy Engine化を避けるためである。

## 7. Resource

Resource専用テーブルは作らず、Delegationの `resource_type` / `resource_id` で対象を表現する。

| 識別情報 | 対象の考え方 |
| --- | --- |
| `resource_type: Order`, `resource_id: 123` | Order #123 |
| `resource_type: Order`, `resource_id: nil` | Order全体 |

上記の対象範囲とmatchingの詳細は次工程で正式定義する。

ResourceはRailsのpolymorphic associationとして強く結び付けず、**Authorization用の識別情報**として扱う。将来、対象がActiveRecord Object、Class、Virtual Resource、External Resourceになる可能性があるためである。

## 8. Constraint

Constraint専用テーブルは作らず、DelegationのJSON / JSONBとして保存する。

フォーマット例（正式フォーマットは未確定）：

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

候補operatorは `eq`、`lt`、`lte`、`gt`、`gte`、`in`。複数条件の評価方法は正式フォーマットとあわせて定義する。

Ruby Procや任意コードをDBへ保存しない。たとえば次のコードをDelegationへ保存する設計は採用しない。

```ruby
->(context) { context[:amount] <= 10_000 }
```

理由はAudit、安全性、serialization、バージョン管理、DB上での意味の確認が難しくなるためである。

v0.1ではConstraintを小さく保ち、AND / OR / NOTを表現する高度なPolicy Language、nested expressions、arbitrary functions、cross-resource references、custom executable codeを作らない。

## 9. Delegation Effect

Delegationに保存するEffectは `allow` / `require_approval` とし、v0.1ではexplicit deny Delegationを作らない。**default deny**を採用する。

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

## 11. Authorization

AuthorizationはActiveRecord ModelではなくServiceとする。概念的な入力と判定フローは次のとおり。

```text
Agent / Principal / Action / Resource / Context
    ↓
対応するDelegation検索
    ↓
Expiration / Revocationを確認
    ↓
Constraint評価
    ↓
Matching Delegation
    ├─ allow
    └─ require_approval
    ↓
Decision
```

一致する有効なDelegationが存在しなければ `deny` を返す。ActingForは業務処理を実行せず、ホストアプリがDecisionを適用する。`require_approval` は実行許可を意味しない。

## 12. Decision

DecisionはDB Modelにせず、Authorization結果を表すValue Objectとする。種類は `allow` / `deny` / `require_approval`。

将来のAPIイメージ（未確定）：

```ruby
decision.allowed?
decision.denied?
decision.approval_required?
```

必要に応じて `status`、`reason`、`delegation` などを持たせる想定。永続化が必要なDecision情報はAuditEventへ記録する。

## 13. Delegationが複数一致した場合

安全側に倒すため、`allow` と `require_approval` が両方一致した場合は、次の優先順とする方向で設計する。

```text
require_approval > allow
```

詳細ルールは未確定。将来explicit denyを導入するなら `deny > require_approval > allow` という優先順位が考えられるが、explicit deny自体はv0.1に含めない。

## 14. AuditEvent

AuditEventはAuthorization判定を専用テーブル `acting_for_audit_events` に記録する。

### 最小属性案

```text
id
agent_id
principal_type
principal_id
action
resource_type
resource_id
decision
reason_code
delegation_id
context
created_at
```

記録例：

```yaml
agent: shopping-agent-abc
principal: User#10
action: purchase
resource: Product#55
context:
  amount: 8900
decision: allow
delegation_id: 123
reason_code: delegation_matched
```

属性とreason codeの具体形は未確定。

## 15. AuditEventの方針

AuditEventは基本的にappend-onlyとする。通常利用ではINSERTを中心とし、UPDATE / DELETEを前提にしない。Authorizationの結果を書き換えるのではなく、新しいAuditEventを追加して履歴を残す。

## 16. Audit Contextの安全性

Authorization時に渡されたContextを、そのままAuditEventへ保存してはいけない。password、access token、credit card information、email body、personal information、secretなどが含まれる可能性があるためである。

```text
Authorization Context
    ↓
Audit Filter / Sanitizer
    ↓
AuditEvent Context
```

AuditEventには必要最小限の情報だけを保存する。例は `amount`、`currency`、`order_id`。Audit機能そのものが情報漏洩リスクにならない設計とする。Filter / Sanitizerの具体的な仕様は後続設計で決める。

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
    └─ Delegation（必要に応じて）
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

次は **Delegation 1件が正確に何を意味するのか** を正式に定義する。

- Delegation matching rule
- `resource_type` / `resource_id` の意味
- Constraintの正式フォーマットとoperator
- 複数Delegationが一致した場合の詳細ルール
- `require_approval` の判定ルール
- Delegationの作成・更新・取消の考え方

これを確定した後、Step 5「Public API Design」へ進む。属性案、DBの型・制約、DecisionのAPI、Auditの詳細も後続設計で具体化する。
