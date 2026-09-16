# ActingFor v0.1 Public API Design

更新日：2026-09-17

**状態：Design-stage API / Not implemented yet。** 本書をStep 5「Public API Design」の正本とする。進捗は **10 / 10**。全項目が設計決定済み（D015〜D025）で、**Step 5は完了（Design finalized）**。Gemは未実装であり、本更新では実装を開始しない。

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

必要field不足はStep 4のfail closedを維持する。有効なmatching Delegationがなければdenyとなる。Exception class名の正式一覧は今回決定しない。

**ActingForはContext値の真偽を検証するのではなく、ホストアプリが責任を持って確定したContextを受け取る。** API形式の確認とConstraint評価は、この責任分界と区別する。

## 14. Open Questions

Step 5の10項目は完了。決定範囲外の詳細として、Exception class名、Delegation作成のvalidation APIと `delegate!` の有無、Decision追加属性、reason_code正式一覧、Filter / SanitizerのPublic APIも未決定のまま残す。

Gem構成・配置、Rails標準Migration方式、独自Generator非提供は[Step 7の正本](gem_structure_v0_1.md)（D028）で設計決定済み。DB型、Migration実コード・taskの確認、対応Ruby / Rails等の後続事項は[Step 4の残る未確定事項](domain_model_v0_1.md#22-次に決めること)を参照する。

## 15. Step 5 Progress

Step 4は完了。Step 5「Public API Design」も **10 / 10、Complete**。後続のStep 6は **Complete / Design-stage Quick Start finalized**（D027）。最新の進捗は[PROJECT](PROJECT.md#5-進行順)、設計例は[README](../README.md#quick-start)を参照。Gemは未実装・未リリースで、例は実行不可。

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
