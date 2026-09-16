# ActingFor 開発方針

更新日：2026-09-17

- プロジェクト名：**ActingFor**
- Gem名：`acting_for`
- リポジトリ：[cuichangquan/acting_for](https://github.com/cuichangquan/acting_for)
- 現在の段階：Step 8「Test Strategy」完了（Complete / Design finalized / Not implemented）。[Step 8正本](test_strategy_v0_1.md)に記録。Step 7もComplete / Design finalized / Not implementedを維持する。Step 6はComplete / Design-stage Quick Start finalizedを維持する。Step 5は10 / 10、Complete / Design finalizedを維持する。Gemは未実装・未リリースで、Quick Startはまだ実行できない。
- 紹介文の本文：[README](../README.md)
- 決定の理由と状態：[DECISIONS](DECISIONS.md)

## 1. 解決する問題

Railsアプリが、認証済みのAI Agentによる操作要求について、次を判断できるようにする。

1. どのAgentか。
2. 誰の代理か。
3. 何をしようとしているか。
4. その権限が委任されているか。
5. 金額・期限などの制約を満たすか。

判定結果の設計方針は `allow` / `deny` / `require_approval` の3種類。

## 2. 基本方針

- Human / Principal と Agent を別主体として扱う。
- PrincipalとAgentを分離する。ホストの `current_user` とAgentは別主体であり、ActingForが `current_agent` helperを提供する意味ではない（D026）。
- 認証済みのAgentに対する、Railsアプリ内部の委任と認可に集中する。
- 汎用認可エンジン、独自のAgent Identity規格は作らない。
- 特定のLLMやAgent Frameworkに依存しない設計を目指す。
- OAuth/OIDCやMCPなどへの接続は、必要に応じたAdapterとして検討する。v0.1での実装を約束しない。
- RailsらしいAPIと導入の容易さを優先し、過剰設計を避ける。

### 2.1 ActingForとMCPの正式な責務境界

**状態：確定（D012）。** 今後の設計は次の責務境界に従う。

> **MCPは「AgentがRailsアプリの機能にどうアクセスするか」を扱う。**
> **ActingForは「そのAgentがPrincipalの代理として、その操作を実行してよいか」を扱う。**

| 項目 | MCP側 / 外部 | ActingFor |
| --- | --- | --- |
| Agent ↔ Rails間の接続 | 担当 | 担当しない |
| Tool / Resource公開 | 担当 | 担当しない |
| MCPリクエスト形式 | 担当 | Coreは知らない |
| OAuth等によるアクセス認証 | MCP側 / 外部が担当 | 担当しない |
| 「誰の代理か」 | 情報を渡す可能性がある | 判断の中心 |
| Human / Principal → Agentの権限委任 | 担当しない | 担当 |
| Actionの認可 | 接続・Toolレベルのアクセス制御はあり得る | 委任に基づく業務権限を担当 |
| 金額・期限等のConstraint | 原則アプリ責務 | 担当 |
| `require_approval` | 担当しない | 判定を担当 |
| Delegationの有効期限 | 担当しない | 担当 |
| DelegationベースのAudit | 担当しない | 認可判定の記録を担当 |

この表は本プロジェクトの責務分担を示す。MCP側のAuthorizationとActingForのAuthorizationはレイヤーが異なる。

```text
MCP側のAuthorization
  「このClientは、このMCP Server / Toolへアクセスしてよいか？」

ActingForのAuthorization
  「このAgentは、このPrincipalの代理として、この業務操作を実行してよいか？」
```

MCP側でアクセスが許可されても、業務操作の代理権限が認められたことにはならない。ActingForはホストアプリの既存認可と併用し、ホストアプリがDecisionを適用する。Approval Workflowの境界はD009、Auditの境界はD010と後続決定D014に従う。

### 2.2 設計ルール

1. **ActingFor CoreはMCPに依存しない。** `mcp` gemやMCP protocol objectをCore APIに入れない。
2. **MCP固有情報は将来Adapterで変換する。** Coreへ渡す語彙は `agent`、`principal`、`action`、`resource`、`context` とする。Adapterの具体的なAPI、種類、提供時期は未決定であり、v0.1での実装を約束しない。
3. **ActingForはAgentの本人確認を行わない。** ホストアプリまたは外部の認証基盤が認証したAgentを受け取り、委任に基づいて認可する。
4. **MCP Tool名とActingFor Actionを同一概念にしない。** たとえばMCP Tool `checkout` の内部でAction `purchase` を判定できる。`tool_name == action` という依存関係を作らない。
5. **Business LogicはActingForの後ろに置く。** ホストアプリは認可判定を適用してから業務処理を実行する。`deny` と `require_approval` では実行しない。ActingFor自身は業務処理を実行しない。

```text
MCP Request
    ↓
MCP Adapter（将来の接続点）
    ↓
agent / principal / action / resource / context
    ↓
ActingFor Core
```

全体の責務境界は次のとおり。認証の具体的な配置はホスト構成によるが、ActingForは認証後に評価する。

```text
External Agent
    ↓
MCP / REST / GraphQL / other
    ↓
Protocol / Identity / Authentication（OAuth・OIDC等）
──────────── Rails内部の委任認可との境界 ────────────
    ↓
ActingFor
  Delegation / Constraint / Expiration
  Authorization / Approval Decision / Audit
    ↓
ホストアプリがDecisionを適用
──────────── 業務処理との境界 ────────────
    ↓ 実行が許可された場合
Rails Business Logic
```

### 2.3 Shopping Agentの例

以下は責務境界を説明するための委任設定例であり、組み込みの金額ルールや確定済みPublic APIではない。「purchaseは10,000円以内なら自動許可、超過時は承認が必要」という委任があり、その他の条件を満たすものとする。

```text
AI Agent: purchase(product, amount: 8_900)
    ↓
MCP側: purchase toolへのアクセスを許可
    ↓
ホスト：Principalの現在の権限を確認 / 金額を確認・確定
    ↓
Rails → ActingFor
    ├─ 誰の代理か？
    ├─ purchaseが委任されているか？
    ├─ 上限10,000円以内か？
    └─ Delegationの期限内か？
    ↓
allow
    ↓
ホストアプリ → PurchaseService
```

同じ委任設定で `amount: 30_000` を要求すると、MCPとして正常なTool Callでも、ActingForは `require_approval` を返す。ホストアプリは業務処理を停止し、必要な承認ワークフローを扱う。金額超過が常に `require_approval` になるという一般ルールを定めるものではない。

**ActingForはMCPを置き換えない。MCPの内側に残る「代理権限」の問題を解決する。** この境界を保つことで、接続プロトコルが変わっても委任認可をRails内部で扱える。

### 2.4 Agent Registration / Resolution Boundary

**状態：確定（D026）。** `ActingFor::Agent` は、外部AgentをRails内部で識別するローカル表現。Userと同じ会員登録・ログインを前提にしない。

```text
External Agent
    ↓ Authentication（Host / 外部認証基盤）
Host Application
    ↓ resolve
ActingFor::Agent
    ↓
ActingFor.authorize(...)
```

Agent AuthenticationはHost Applicationまたは外部認証基盤の責務であり、OAuth / OIDC / API Key / MCPその他の接続・認証方法にCoreを依存させない。認証済み外部AgentをローカルAgentへ対応付けるResolutionもHost Applicationの責務とする。

AgentレコードのProvisioning方法はv0.1では固定しない。管理画面、API、初回認証時、seed、ホスト独自方式などは選択肢の例であり、ActingForの正式なProvisioning APIとして確定しない。

README Quick Startでは認証・Session管理の提供と誤解されないよう `current_agent` を使わず、ホストによって認証・解決済みの `shopping_agent` を用いる。ActingForはAgentを保持するが、認証・ログインさせる仕組みは提供しない。D012・D013の責務境界、PrincipalとAgentをDelegationで関連付ける構造は維持する。

## 3. 用語定義

**状態：確定（D011）。** ActingFor v0.1では、次の用語を正式名称として使用する。

| 用語 | 正式な意味 | 例 |
| --- | --- | --- |
| **Principal** | Agentに権限を委任し、Agentがその代理として行動する対象 | `current_user` |
| **Agent** | Principalの代理として操作を要求する主体。ActingForはその身元認証自体を行わない | Shopping Agent |
| **Delegation** | PrincipalからAgentへ与えられた代理権限 | 「purchaseを1万円まで許可」 |
| **Action** | Agentが実行しようとしている操作 | `:purchase`、`:delete_account` |
| **Resource** | Authorization用の対象識別情報（D014） | Product、Order |
| **Context** | 認可判定時に渡される実行時情報 | `amount: 8_900` |
| **Constraint** | Delegationに付随する条件・制限 | `amount <= 10_000` |
| **Expiration** | Delegationの有効期限 | `expires_at` |
| **Authorization** | Delegation、Constraint等をもとに操作可否を判断する処理 | `ActingFor.authorize(...)` |
| **Decision** | Authorizationの判定結果 | `allow` / `deny` / `require_approval` |
| **Approval** | 自動実行せず、人間の承認が必要であること | `require_approval` |
| **Audit Event** | Authorizationで何を判断したかの記録 | agent / principal / action / decision |

### 3.1 命名と責任分界

- 正式用語にはUserではなく **Principal** を使う。RailsアプリではUserであることが多いが、将来ほかの主体を扱う可能性を限定しないためである。
- **Agent Identity** はコア用語にしない。ActingForはAgentの本人確認や独自ID規格を提供せず、Authenticationを外部の責務とする。
- **Owner** は使わない。「所有者」と「代理として行動される対象」は意味が異なるためである。
- **Approval** と **Approval Workflow** を分ける。ActingForが扱うのはDecisionとして `require_approval` を返すところまでであり、承認依頼、承認操作、通知、再実行はホストアプリの責務とする。
- **Authentication** と **Authorization** を分ける。Authenticationは外部、Delegationに基づくAuthorizationはActingForの責務とする。
- **Policy** はv0.1のコア用語にしない。将来、PolicyクラスをDSLとして採用する可能性はあるが、ActingForの中心概念はPolicyではなくDelegationである。

概念上の流れは次のとおり。

```text
Principal
   │
   │ Delegation
   ▼
 Agent
   │
   │ Action + Resource + Context
   ▼
ActingFor
   │
   ├─ allow
   ├─ deny
   └─ require_approval
```

Public APIはこの語彙に揃える。次はD015〜D017で決定した設計上の利用例であり、未実装。戻り値は `ActingFor::Decision` とする。Step 5の正本は[Public API Design](public_api_v0_1.md)。

```ruby
decision = ActingFor.authorize(
  agent: shopping_agent, # ホストによって認証・解決済み
  principal: current_user,
  action: :purchase,
  resource: product,
  context: {
    amount: product.price
  }
)
```

## 4. v0.1スコープ

**状態：製品スコープは確定（D007）。Test上のAcceptance CriteriaはStep 8で設計確定（D029）。Definition of Done全体はProposal / 提案であり、実装済みという意味ではない。**

### 4.1 v0.1で成立させる利用経路

ホストRailsアプリが認証済みのPrincipalとAgent、要求するactionとresource、判定に必要なcontextを渡す。ActingForはDelegationと条件を評価し、statusが `:allow` / `:deny` / `:require_approval` の `ActingFor::Decision` を生成し、authorize内部でAuditEventを自動保存してから返す。Audit保存に失敗した場合はDecisionを返さずExceptionで中断する（D022・D023）。ホストアプリは判定を受けて業務処理を実行または停止する。

```text
host authentication
  -> principal + agent + action + resource + context
  -> host authorization of the principal’s current permissions
  -> ActingFor delegation decision
  -> host executes or stops the operation
```

Agentの本人確認はActingForの責務ではない。OAuth / OIDC / MCPなど外部の仕組みで認証されたAgent情報を受け取る。特定の認証方式やAgent Identity規格は作らない。

### 4.2 必須機能と項目別の完了条件

| 必須機能 | v0.1で提供する範囲 | 完了条件 |
| --- | --- | --- |
| Agent representation | Rails内部で操作主体となるAgentをPrincipalと別に表現する。最小属性は `id`、必須・一意の `identifier`、任意の `name`、timestamps。PrincipalとはDelegationを介して関連付ける（D013）。Gemは本人確認を行わない | 同じPrincipalでもAgentが異なれば別の主体として扱われ、認証済みAgent情報をホストから受け取れることを自動テストで示す |
| Delegation | PrincipalからAgentへの委任として、`principal`、`agent`、`action`、Resource識別情報、`effect`、`constraints`、`expires_at`、`revoked_at` を表現する。認可内容は原則immutableで、変更はrevoke + createとする（D014） | 指定したPrincipal / Agent / action / resourceだけが一致し、別主体・別action・別resourceには適用されないことを自動テストで示す |
| Authorization | ActingForの中心機能として、委任された操作を実行してよいか判定する。全matching条件を満たす委任を評価し、結果は `allow` / `deny` / `require_approval` の3種類。一致なしはdeny、require_approvalをallowより優先し、判断できなければallowしない（D014） | 3種類すべてとDelegationが存在しない場合を自動テストし、呼び出し側が結果を区別できる |
| Constraint | JSON / JSONBのfield / operator / value配列をAND評価する。ContextのトップレベルKeyのみ参照し、6 operatorと型ルールに従う。暗黙変換をせず、不成立・不正なConstraintはmatchさせない（D014） | Contextに対する条件について、条件内・境界値・条件外を自動テストする。Resource matchingはDelegation matching側で扱う。Constraint形式と評価ルールはD014で確定済み。Public APIの決定はStep 5の正本を参照 |
| Expiration | Delegationに `expires_at` と `revoked_at` を持たせ、期限切れ・取消済みを有効対象から除外する（D013） | 有効期限なし・期限内は他の条件に従って評価し、現在時刻と等しい期限・期限切れ・取消済みのDelegationが除外されることを時刻固定テストで示す。有効な一致がなければ `deny` となる |
| Approval判定 | 自動許可できない操作に `require_approval` を返す。ActingForは「承認が必要」と判断するところまでを担当する | `require_approval` が `allow` と区別され、それだけでは実行許可にならないことを文書とテストで示す。承認依頼、通知、画面、承認後の再実行は含めない |
| Audit log | 認可判定を専用AuditEventテーブルへ基本append-onlyで記録する。Agent（agent_id / agent_identifier）、Principal、action、resource、matched_delegation_ids、reason_code、フィルタ済みcontext、decision、created_atを扱う。業務処理の成功・失敗は対象外（D014） | 3種類の判定について必要項目を追跡できることを自動テストで示す。allowlist優先のFilter / Sanitizerによる必要最小限のcontext記録を検証する。自動記録と保存失敗時ExceptionはD022・D023で確定済み。Filter / SanitizerのPublic APIは未確定 |
| Rails integration | Rails Gemとして自然に導入・利用できる入口を提供する。Headless Rails EngineとRails標準Migration方式を採用し、v0.1では独自Generatorを作らない（D028） | 最小Hostである `test/dummy` で、導入、Engine boot、Migration、autoload、namespace分離、Delegation、Authorization、AuditまでをIntegration Testで検証する。Runnable Quick Startは未完了 |

上表の「提供する範囲」は確定スコープ。Test上のAcceptance Criteriaは[Step 8正本の対応表](test_strategy_v0_1.md#13-v01-acceptance-criteriaとの対応)で設計確定（D029）し、詳細な検証範囲は同書に従う。Testコードはまだ存在せず、合格済みという意味ではない。`ActingFor.authorize(...)` の入口・引数と戻り値 `ActingFor::Decision` はD015〜D017で設計決定済みだが、未実装。`decision.allowed?` 等のDecision APIはD018で設計決定済み。Gem構成は[Step 7の正本](gem_structure_v0_1.md)で設計確定。v0.1では独自Generator・Configuration / Initializerを作らない（D028）。

横断的Security Acceptance CriteriaもStep 8で確定する。

| 要件 | Test上のAcceptance Criteria |
| --- | --- |
| Host Authorization Boundary | Principalの現在権限とDelegationの積集合を守る。委任後の権限喪失とrequire_approvalでも権限を拡張しないことをIntegration Testで示す |
| Context Trust Boundary | Hostが値を確定し、ActingForは渡されたContextを評価する。形式不正はException、必要field不足はConstraint不成立としてIntegration Testで区別する |
| fail-closed | Unit / Integration双方で、権限を明確に確認できなければallowしない。API misuse / System failure / Audit保存失敗はdenyへ変換せずExceptionとする |

### 4.3 v0.1全体のDefinition of Done

**状態：Proposal / 提案。** 対応Ruby version、対応Rails version、CI matrix、static analysis、License、Runnable Quick Start、Release notesが未決定のため、Step 8完了後も全体は正式決定しない。以下はv0.1実装完了条件の提案である。

1. 4.2の全項目と境界ケースが自動テストされ、対応対象と決めたRuby/Railsの組み合わせでCIが成功する。
2. サンプルRailsアプリまたは統合テストで、Delegation作成から判定、Audit記録までを再現できる。
3. READMEに、実行可能なインストール手順、Quick Start、Agent認証との責任分界、Constraint、Expiration、Approvalの責任分界を記載する。
4. セキュリティ上の主要な失敗ケースを、テストまたは設計文書で扱う。
5. Public API、永続化方式、対応Ruby/Rails、ライセンスをDECISIONSで確定し、破壊的変更の可能性をv0.1のリリースノートに明記する。
6. `bundle exec rake` 相当の一つの公開コマンドで、単体・統合テストと静的検査を再現できる。
7. 未実装機能をREADMEで利用可能と表現せず、対象外と既知の制約を明記する。

### 4.4 v0.1の対象外

- Agent認証
- OAuth Server、OIDC Provider
- 独自Agent Identity規格、政府認証Agent ID、Agent証明書発行基盤
- MCP Server、Agent間通信
- 決済処理
- Approval UI、承認依頼の送信、通知機能、承認後の処理再実行
- UI、管理画面
- 独自暗号方式
- 分散Authorization Server
- 汎用Policy Engine

対象外の機能はホストアプリで実装できる。将来の拡張点を妨げない設計は行うが、v0.1の完了条件には含めない。

### 4.5 スコープ確定後も別途決める設計

Step 4のドメインモデルと詳細ルールは[D014](DECISIONS.md#d014-v01-delegation判定constraintlifecycleaudit詳細)で確定。以下は引き続き未確定。

- 具体的なException class名
- Decisionの追加属性、reason_code正式一覧（クラス・statusはD017、4つのPublic APIはD018で決定済み）
- Delegation作成の細かなvalidation APIと `delegate!` の有無
- Filter / SanitizerのPublic API
- DB schemaの細かな型・制約、resource_idの正式DB型
- Migrationの実コード・taskの具体的なコマンド名（構成と独自Generator非提供はStep 7 / D028で決定済み）
- Ruby / Railsの対応バージョン
- ライセンス

## 5. 進行順

| 順番 | 作業 | 状態 |
| --- | --- | --- |
| 1 | 解決する問題を1文で確定 | 完了。READMEとD006に記録 |
| 2 | v0.1スコープを正式確定 | 完了。本文とD007に記録 |
| 3 | 用語定義 | 完了。本文とD011に記録 |
| 4 | ドメインモデル設計 | 完了。基本方針D013と詳細ルールD014を[設計書](domain_model_v0_1.md)に記録 |
| 5 | Public API設計 | 完了（Complete）。進捗は10 / 10。D015〜D025で全項目決定済み。[正本](public_api_v0_1.md) |
| 6 | README Quick Start | 完了（Complete / Design-stage Quick Start finalized）。D026・D027、[README](../README.md#quick-start)に反映済み。実行不可 |
| 7 | Gem Structure Design | 完了（Complete / Design finalized / Not implemented）。D028、[正本](gem_structure_v0_1.md) |
| 8 | Test Strategy | 完了（Complete / Design finalized / Not implemented）。D029、[正本](test_strategy_v0_1.md)。Testコード未実装 |
| 未採番 | セキュリティモデル設計 | 未着手。各設計工程でも随時検討する。後続の順番は未確定 |
| 10 | 実装開始 | 設計後 |

MCPとの責務境界は正式確定済み（2.1〜2.3、D012）。Step 4はD013・D014で完了。Step 5「Public API設計」もD015〜D025で完了。Step 6もD026・D027で完了（Design-stage Quick Start finalized）。Step 7もD028で完了（Design finalized / Not implemented）。Step 8もD029で完了（Complete / Design finalized / Not implemented）。

競合の初期調査、ポジショニングの方向性整理、ActingForへの改名は引き継ぎ済み。競合調査は過去の初期調査として扱い、最新状況を検証した記録とはしない。

Step 7決定に伴い、従来Step 9に置いていたテスト方針をStep 8へ変更した。セキュリティモデル設計の後続の順番は今回固定しない。Gem実装にはまだ入っていない。

### 5.1 Step 5の検討項目

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

入口は `ActingFor.authorize(agent:, principal:, action:, resource: nil, context: {})`。keyword argumentsのみとし、戻り値は `ActingFor::Decision`。詳細と未決定事項は[Step 5の正本](public_api_v0_1.md)に記録する。Step 5 progress = **10 / 10、Complete**。Step 6もD026・D027で完了（Design-stage Quick Start finalized）。Step 7もD028で完了（Design finalized / Not implemented）。Step 8もD029で完了（Complete / Design finalized / Not implemented）。実装は開始しない。

D024により、Principal自身の現在の権限はホストが実行時にも確認し、ActingForのDelegation認可と両方を満たして初めて業務処理を実行する。Agentの実効権限はPrincipal自身の権限とDelegationされた権限の積集合であり、require_approvalも権限を拡張しない。CoreはPundit等を直接呼ばない。D025により、Context値の正確性・信頼性はホストが保証する。ActingForは値の真偽を検証せずConstraintを評価する。形式不正はException、必要field不足はConstraint不成立とする。

### 5.2 Step 6 README Quick Start Design

**Complete / Design-stage Quick Start finalized（D027）。** [README Quick Start](../README.md#quick-start)への反映を完了した。Gem実装・リリースやRunnable Quick Startの完了ではない。Step 5の10 / 10の仕様は変更しない。

代表ユースケースは「Shopping AgentがPrincipalの代理として商品を購入する」。Principal、Agent、Delegation、Action（`purchase`）、Resource、Context、Constraint、Decisionを使い、次の8節で数分で基本を理解できる構成とする。

1. 全体フロー：Principalの委任からHostの要求、authorize、3状態、Hostの次の判断まで。ActingForはBusiness Logicを実行しない。
2. 認証・解決済みAgent：D026に従う `shopping_agent` を使う。
3. Delegation作成：10,000円以下allow、10,000円超かつ30,000円以下require_approvalの2件のみ。30,000円超はmatchingなしでdeny。組み込み金額ルールでもexplicit deny Delegationでもない。
4. Authorization：実際の `product` と、ホストが取得・確認した `product.price` を渡す。代表例は8,900円。
5. Decision：8,900円 / 20,000円 / 50,000円の表とD018の4つのPublic APIを示す。require_approval != allow、承認時のallowed?はfalse。
6. 既存認可：Host Authorization AND ActingFor Authorization。Principalの現在の権限確認はホスト責務で、allowも最終実行許可ではなく、require_approvalも権限を拡張しない。
7. Context：Agent申告値を無検証で利用しない。ホストが値を確認・確定し、ActingForはConstraintを評価する。
8. Audit：authorize内で自動記録し、保存失敗時はException。allowもdenyもDecisionも返さず、業務処理へ進ませない。

冒頭で未実装・未リリース・実行不可を一度明示する。Installation、Gem追加・bundle install、MCPや認証方式の詳細、Provisioning API、Constraint全仕様、Exception一覧、AuditEvent全カラム・reason_code・Filter / Sanitizer、Approval Workflow実装、Pundit等の具体Integrationコード、その他未決定APIや将来機能はQuick Startに入れない。`ActingFor.delegate(...)` はD021の方向性を示す例であり、全引数・default・validation・`delegate!` は未決定のまま残す。

### 5.3 Step 7 Gem Structure Design

**Complete / Design finalized / Not implemented（D028）。** [Gem Structure Designの正本](gem_structure_v0_1.md)に最小構成、Headless Rails Engine、Model / Internal Service / Decisionの配置、Migration、autoload、依存関係、Public / Internal boundaryを記録した。独自GeneratorとConfiguration / Initializerは現時点で作らない。Gemは未実装・未リリース。後続のStep 8もD029で設計完了した。

### 5.4 Step 8 Test Strategy Design

**Complete / Design finalized / Not implemented（D029）。** [Test Strategyの正本](test_strategy_v0_1.md)にMinitest採用、Unit / Integrationの境界、最小 `test/dummy`、Decision、ConstraintEvaluator、authorize、Delegation matching、Audit / 保存失敗、Migration / Engine、Host Authorization Boundary、Context Trust Boundary、fail-closed、v0.1 Acceptance Criteriaとの対応を記録した。

Testコードはまだ存在しない。4.3のDefinition of Done全体はProposal / 提案を維持する。次工程の番号・順序は新たに決めず、Security Model DesignをStep 9として採番しない。GemはNot implemented / Not releasedであり、実装開始には進まない。

## 6. Issue化する候補

**以下は未登録の候補。GitHub Issue番号はまだない。**

| 候補タイトル | 解決したいこと |
| --- | --- |
| v0.1の完了条件を確定する | Step 8のTest上のAcceptance Criteriaを前提に、未決定事項を含む4.3のDefinition of Done全体をレビューする |
| Public APIの残る詳細を設計する | D018〜D023を前提に、具体的なException class、Delegation作成のvalidation API等を決める |
| require_approval後のホスト要件を決める | 確定済みの責任分界を前提に、承認する人、承認対象との紐付け、内容変更、再利用、再認可を整理する |
| Auditの残る詳細を決める | D022・D023の自動記録・保存失敗時Exceptionを前提に、reason_code正式一覧とFilter / Sanitizer APIを決める |

Issueを作成したら、この表の対応する行をIssueへのリンクに置き換える。詳細と進捗はIssue側で管理し、本文を重複管理しない。

## 7. 情報の管理ルール

| 管理先 | 役割 |
| --- | --- |
| README.md | Gemの紹介とDesign-stage Quick Start。実行可能な手順は実装・検証後に掲載 |
| docs/PROJECT.md | 開発方針、スコープ、進行順 |
| docs/DECISIONS.md | 決定事項、理由、提案・確定・保留の区別 |
| docs/domain_model_v0_1.md | v0.1ドメインモデルの確定設計と後続工程の未決定事項 |
| docs/public_api_v0_1.md | Step 5 Public API設計の正本。決定済み範囲と未決定事項・進捗 |
| docs/gem_structure_v0_1.md | Step 7 Gem Structure Designの正本。Design finalized / Not implemented |
| docs/test_strategy_v0_1.md | Step 8 Test Strategy Designの正本。Complete / Design finalized / Not implemented |
| GitHub Issues | 開発タスク、懸念点、未解決の質問 |

- 会話の区切りで、決まった内容を該当ファイルへ反映する。
- AIの提案を、承認済みの決定事項として記録しない。
- 決定を変える場合は、以前の判断を消さず、変更日と理由を残す。
- 次の会話はREADME、本書、DECISIONS、関連Issueを読んで再開する。
- 元のPDFは初期資料として扱い、日々の更新はMarkdownで行う。

新しい機能を検討するときは、v0.1への必要性、既存標準での代替、ActingForの責務、Railsとしての自然さ、セキュリティ、標準変更への耐性、過剰設計の有無を確認する。

## 8. 次に進めること

1. Step 8はComplete / Design finalized / Not implemented。次工程の番号・順序は今回新たに決めず、実装にも進まない。
2. reason_code正式一覧、Filter / SanitizerのPublic API等の詳細は未決定のまま残す。
3. [残る未確定事項](domain_model_v0_1.md#22-次に決めること)に従い、DB型、Migration実コード・taskの確認、対応Ruby/Rails、ライセンス等を後続工程で扱い、v0.1の完了条件をレビューする。

## 9. 初版の根拠

- `AgentAuthority Project Instructions.pdf`：旧名称での初期構想。
- `ActingFor_Project_Summary.pdf`：改名後の方針整理。
- 2026-09-14の引き継ぎと会話：最新の名称、説明文案、責務、進行順、情報管理方針。
- [ChatGPT共有会話「ActingFor問題定義」](https://chatgpt.com/share/6aa7c32e-77b4-83ee-ad35-ae048e8001ef)：紹介文とv0.1正式スコープ。

初版では、名称と責務について最新の引き継ぎ内容を優先した。PDFの旧名称や未確定のAPI例を、そのまま現在の確定仕様にはしていない。
