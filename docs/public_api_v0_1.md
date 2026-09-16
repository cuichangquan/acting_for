# ActingFor v0.1 Public API Design

更新日：2026-09-16

**状態：Design-stage API / Not implemented yet。** 本書をStep 5「Public API Design」の正本とする。進捗は **8 / 10**。項目1〜8は設計決定済み（D015〜D023）、項目9〜10は未決定。Step 5全体は進行中であり、Gemの実装は開始しない。

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
| `principal:` | 必須 | Agentが誰の代理として行動するかを表す「委任元」。Userに限定せず、Organization / Team / ServiceAccount等も想定する |
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

`decision.status` を正式なPublic APIとして持つ（D018）。statusは次の3種類だけとする。

| status | 意味 |
| --- | --- |
| `:allow` | PrincipalからAgentへのDelegation上、その操作を実行可能であることが確認された |
| `:deny` | 有効なDelegationを確認できなかった等により、ActingForとして操作を許可しない |
| `:require_approval` | 自動実行してはいけない。Human Approvalが必要 |

ActingForの `allow` はRailsアプリ全体の最終認可を意味しない。ホストアプリ自身のAuthorizationとの具体的な関係は項目9で決める。

**`require_approval != allow`。** Approval Workflow自体はActingFor v0.1の責務ではない。

DecisionはActiveRecord ModelでもDBへ直接永続化するModelでもない。Decision自体を保存せず、必要な認可判定情報をActiveRecord ModelであるAuditEventへ記録する。AuditEventが記録するのはAuthorization Decisionであり、業務処理の結果ではない。

## 6. Decision Public API

**確定：D018 / Step 5項目4。** 次の4つを正式採用する。

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

具体的なException class名は未決定であり、本書では確定しない。

## 8. Bang API

**確定：D020 / Step 5項目6。** v0.1では `ActingFor.authorize!(...)` を提供しない。Public Authorization APIは `ActingFor.authorize(...)` のみ。

ActingForはallow / deny / require_approvalの3状態を持つため、Bang APIにはdeny / require_approvalをどうExceptionへ変換するかという追加の意味付けが必要になる。v0.1では導入せず、必要性が明確になった場合にv0.2以降で再検討できる。

## 9. Delegation API

**確定：D021 / Step 5項目7。** Delegationの作成・取消はActiveRecordの直接操作をPublic APIの基本とせず、専用APIを提供する方向とする。

Step 4でDelegationの認可内容は原則immutable、権限変更は旧Delegationのrevoke + 新Delegationのcreateと決定した。直接操作を基本にすると、このLifecycleルールを壊しやすいためである。

### 作成

正式決定は「Delegation作成用の専用Public APIを用意する」こと。次は基本Public API案であり、全引数・default・validationの詳細を確定するものではない。

```ruby
delegation = ActingFor.delegate(
  agent: agent,
  principal: user,
  action: :purchase,
  resource: product,
  constraints: [...],
  effect: :allow
)
```

細かなvalidation APIと `delegate!` の有無は未決定。

### revoke

基本形は次のとおり。

```ruby
delegation.revoke!
```

hard deleteではなくrevocationとして無効化する。権限変更はrevoke + 新Delegation作成で行う。

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

これは「権限がない」という判定ではなく、「ActingForのAuthorization処理を正常に完了できなかった」というシステム異常である。具体的なException class名は未決定。

Step 4のAudit責務、append-only、ContextのFilter / Sanitizer経由の保存方針を維持する。reason_code正式一覧とFilter / SanitizerのPublic APIは未決定。

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

ActingFor CoreへMCP固有Objectを入れず、MCP Tool名とActingFor Actionを同一概念にしない。この説明は既存認可との正式な接続方法を確定するものではない。

## 12. Open Questions

Step 5で残る項目は次の2つ。本更新では決定しない。

- **項目9 / 既存認可との関係**：Pundit / CanCanCan / 独自Authorization、Principal自身の権限、DelegationがPrincipalの権限を超えない仕組み、評価順序、ActingForから既存認可を直接呼ぶか。
- **項目10 / Contextの信頼境界**：Agent申告値を信用するか、amountの取得元、resource情報・currencyの検証、ホスト側で再取得すべき値、trusted / untrusted context。Audit保存時のFilter / Sanitizer方針とは別の論点として決める。

項目1〜8の決定範囲外の詳細として、Exception class名、Delegation作成のvalidation APIと `delegate!` の有無、Decision追加属性、reason_code正式一覧、Filter / SanitizerのPublic APIも未決定のまま残す。

DB型、migration / generator構成、対応Ruby / Rails等の後続設計は[Step 4の残る未確定事項](domain_model_v0_1.md#22-次に決めること)を参照する。

## 13. Step 5 Progress

Step 4は完了。Step 5は **8 / 10** 決定済みで進行中。次にやることは **Step 5-9：既存認可（Pundit / CanCanCan等）との関係**。

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
| 9 | 既存認可（Pundit / CanCanCan等）との関係 | 未決定 |
| 10 | Contextの信頼境界 | 未決定 |

設計決定は実装完了を意味しない。本更新ではGem本体、Model、Service、Decision class、AuditEvent、migration、generator、spec / test、Gem version、gemspec依存関係を作成・変更しない。
