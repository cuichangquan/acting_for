# ActingFor v0.1 Public API Design

更新日：2026-09-15

**状態：Design-stage API / Not implemented yet。** 本書をStep 5「Public API Design」の正本とする。項目1〜3は設計決定済み（D015〜D017）、項目4〜10は未決定。Step 5全体は進行中であり、Gemの実装は開始しない。

## 1. Purpose

完了済みの[Step 4 Domain Model Design](domain_model_v0_1.md)を前提に、RailsアプリがDelegationに基づく認可を要求するPublic APIを定義する。決定の理由と履歴は[DECISIONS](DECISIONS.md)で管理する。

## 2. Design principles

- PrincipalとAgentを別主体として明示し、Delegationを中心概念にする。
- ActingForはAgent Authenticationを担当せず、ホストアプリで認証済みのAgentを受け取る。
- Public APIと内部実装を分離する。内部Serviceの具体構成は未確定。
- CoreはMCPに依存せず、MCP Tool名とActingFor Actionを同一概念にしない。
- Step 4のAction完全一致、Resourceのnilの意味、Constraint評価、DecisionとAuditEventの責務を維持する。
- 汎用Policy Engineへ拡大せず、v0.1で過剰設計しない。

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

Publicは `ActingFor.authorize(...)`。Internalは未確定。内部で `ActingFor::Authorization.call(...)` 等を使う可能性はあるが、実装時に決める。

## 4. authorize Arguments

**確定：D016 / Step 5項目2。** Public APIの引数形は次のとおり（シグネチャの設計表記）。

```ruby
ActingFor.authorize(
  agent:,
  principal:,
  action:,
  resource: nil,
  context: {}
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
| `principal:` | 必須 | Agentが誰の代理として行動するか。Userに限定しない |
| `action:` | 必須 | 要求するAction |
| `resource:` | 任意 / `nil` | 特定Resource、Resource type全体、またはResource不要のAction |
| `context:` | 任意 / `{}` | 認可判定時の情報を持つHash |

### action

`action: :purchase` のようにSymbolで自然に書けるようにする。String（`action: "purchase"`）も受け付ける方向とし、内部では `:purchase` → `"purchase"` のように同一のActionとして正規化する。

Action matchingはStep 4どおり完全一致。wildcard、regex、hierarchy、`purchase.*`、`orders:*` はv0.1では扱わない。このAction正規化は、Constraint値の暗黙の型変換を認めるものではない。

### resource

| 設計上の利用形 | 意味 |
| --- | --- |
| `resource: product` | 特定Resource |
| `resource: Product` | Resource type全体 |
| `resource: nil` | Resourceを必要としないAction |

**`resource: nil` は「すべてのResource」を意味しない。** Step 4のResource識別情報の設計を維持する。

### context

Hashを受け取る。例：

```ruby
context: {
  amount: 8_900,
  currency: "JPY"
}
```

Constraintが参照するのはトップレベルKeyのみ。次のHashの `order.amount` のようなnested object accessはv0.1のConstraint評価対象にしない。

```ruby
context: {
  order: {
    amount: 8_900
  }
}
```

Agentから送られた値を信用してよいか、ホストアプリによる確認済み値を必須にするかは、項目10で別途決定する。本節では信頼境界を確定しない。

## 5. Decision

**確定：D017 / Step 5項目3。** `ActingFor.authorize(...)` はSymbolを直接返さず、`ActingFor::Decision` というValue Objectを返す設計とする。

```ruby
decision = ActingFor.authorize(...)
# 概念上：#<ActingFor::Decision status=:allow>

decision.status
# => :allow
```

最低限、概念として `decision.status` を持つ。statusは次の3種類だけとする。

| status | 意味 |
| --- | --- |
| `:allow` | PrincipalからAgentへのDelegation上、その操作を実行可能であることが確認された |
| `:deny` | 有効なDelegationを確認できなかった等により、ActingForとして操作を許可しない |
| `:require_approval` | 自動実行してはいけない。Human Approvalが必要 |

ActingForの `allow` はRailsアプリ全体の最終認可を意味しない。ホストアプリ自身のAuthorizationとの具体的な関係は項目9で決める。

**`require_approval != allow`。** Approval Workflow自体はActingFor v0.1の責務ではない。

DecisionはActiveRecord ModelでもDBへ直接永続化するModelでもない。Decision自体を保存せず、必要な認可判定情報をActiveRecord ModelであるAuditEventへ記録する。AuditEventが記録するのはAuthorization Decisionであり、業務処理の結果ではない。

`allowed?`、`denied?`、`approval_required?` 等の具体的なDecision APIは候補段階。項目4で決めるため、確定済みAPIとして扱わない。

## 6. Undecided Items

以下は今回確定しない。

- **項目4 / Decision API**：`decision.allowed?`、`decision.denied?`、`decision.approval_required?` 等の採否。
- **項目5 / denyとExceptionの境界**：権限不足、入力不正、設定不正、プログラミングミスの扱い。Step 4のmatching / Constraintルールは維持するが、そこから例外のPublic APIを推測しない。
- **項目6 / Bang API**：`ActingFor.authorize!(...)` の要否。
- **項目7 / Delegation操作API**：`ActingFor.delegate(...)`、`ActingFor.revoke(...)`、`delegation.revoke!` 等の採否。Step 4のrevoke + create方針からメソッド名を確定しない。
- **項目8 / Audit**：Authorization時のAudit呼び出し方法、Audit INSERT失敗時にallowを返すか、denyにするか、exceptionにするか。reason_code正式一覧とFilter / SanitizerのPublic APIも未確定。
- **項目9 / 既存認可との関係**：Pundit / CanCanCan等との正式な接続方法、Principal自身の権限とDelegationの関係、具体的なPublic APIと責務境界。
- **項目10 / Contextの信頼境界**：Agent送信のamount / currency / resource information等を信用してよいか、ホストアプリの確認済み値を必須とするか。Audit保存時のFilter / Sanitizer方針とは別の論点として決める。

DB型、migration / generator構成、対応Ruby / Rails等の後続設計は[Step 4の残る未確定事項](domain_model_v0_1.md#22-次に決めること)を参照する。

## 7. Step 5 Progress

Step 4は完了。Step 5は進行中で、10項目中1〜3のみ決定済み。次は項目4を検討する。

| 項目 | 内容 | 状態 |
| --- | --- | --- |
| 1 | Authorization entry point | 決定済み（D015） |
| 2 | authorizeの引数仕様 | 決定済み（D016） |
| 3 | Decisionの形 | 決定済み（D017） |
| 4 | Decision API | 未決定 |
| 5 | denyとExceptionの境界 | 未決定 |
| 6 | Bang API（authorize!）の要否 | 未決定 |
| 7 | Delegation操作API | 未決定 |
| 8 | Auditの扱いとAudit失敗時方針 | 未決定 |
| 9 | 既存認可（Pundit / CanCanCan等）との関係 | 未決定 |
| 10 | Contextの信頼境界 | 未決定 |

設計決定は実装完了を意味しない。本更新ではGem本体、Model、Service、Decision class、AuditEvent、migration、generator、spec / test、Gem version、gemspec依存関係を作成・変更しない。
