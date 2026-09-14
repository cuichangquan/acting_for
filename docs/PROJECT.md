# ActingFor 開発方針

更新日：2026-09-15

- プロジェクト名：**ActingFor**
- Gem名：`acting_for`
- リポジトリ：[cuichangquan/acting_for](https://github.com/cuichangquan/acting_for)
- 現在の段階：設計。以下は実装済み機能の一覧ではない。
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
- `current_user` と `current_agent` を分離する。
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

MCP側でアクセスが許可されても、業務操作の代理権限が認められたことにはならない。ActingForはホストアプリの既存認可と併用し、ホストアプリがDecisionを適用する。Approval Workflowの境界はD009、Auditの境界はD010に従う。

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

## 3. 用語定義

**状態：確定（D011）。** ActingFor v0.1では、次の用語を正式名称として使用する。

| 用語 | 正式な意味 | 例 |
| --- | --- | --- |
| **Principal** | Agentに権限を委任し、Agentがその代理として行動する対象 | `current_user` |
| **Agent** | Principalの代理として操作を要求する主体。ActingForはその身元認証自体を行わない | Shopping Agent |
| **Delegation** | PrincipalからAgentへ与えられた代理権限 | 「purchaseを1万円まで許可」 |
| **Action** | Agentが実行しようとしている操作 | `:purchase`、`:delete_account` |
| **Resource** | Actionの対象となるオブジェクト | Product、Order |
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

Public APIはこの語彙に揃える。次は用語の対応を示す設計イメージであり、メソッド名や戻り値を確定するものではない。

```ruby
decision = ActingFor.authorize(
  agent: current_agent,
  principal: current_user,
  action: :purchase,
  resource: product,
  context: {
    amount: 8_900
  }
)
```

## 4. v0.1スコープ

**状態：製品スコープは確定（D007）。項目別の完了条件とDefinition of Doneは提案であり、実装済みという意味ではない。**

### 4.1 v0.1で成立させる利用経路

ホストRailsアプリが認証済みのPrincipalとAgent、要求するactionとresource、判定に必要なcontextを渡す。ActingForはDelegationと条件を評価し、`allow` / `deny` / `require_approval` を返し、認可判定をAudit logへ記録する。ホストアプリは判定を受けて業務処理を実行または停止する。

```text
host authentication
  -> principal + agent + action + resource + context
  -> ActingFor delegation decision
  -> host executes or stops the operation
```

Agentの本人確認はActingForの責務ではない。OAuth / OIDC / MCPなど外部の仕組みで認証されたAgent情報を受け取る。特定の認証方式やAgent Identity規格は作らない。

### 4.2 必須機能と項目別の完了条件

| 必須機能 | v0.1で提供する範囲 | 完了条件 |
| --- | --- | --- |
| Agent representation | Rails内部で操作主体となるAgentをPrincipalと別に表現する。最小属性は `id`、必須・一意の `identifier`、任意の `name`、timestamps。PrincipalとはDelegationを介して関連付ける（D013）。Gemは本人確認を行わない | 同じPrincipalでもAgentが異なれば別の主体として扱われ、認証済みAgent情報をホストから受け取れることを自動テストで示す |
| Delegation | PrincipalからAgentへの委任として、`principal`、`agent`、`action`、Resource識別情報、`effect`、`constraints`、`expires_at`、`revoked_at` を表現する（D013） | 指定したPrincipal / Agent / action / resourceだけが一致し、別主体・別action・別resourceには適用されないことを自動テストで示す |
| Authorization | ActingForの中心機能として、委任された操作を実行してよいか判定する。結果は `allow` / `deny` / `require_approval` の3種類 | 3種類すべてとDelegationが存在しない場合を自動テストし、呼び出し側が結果を区別できる |
| Constraint | 金額上限、resource一致、context条件などの条件付き委任を扱う。独自の巨大なPolicy言語は作らない | 少なくとも金額上限とresource条件について、条件内・境界値・条件外を自動テストする。context条件の具体的な提供方式はPublic API設計で決める |
| Expiration | Delegationに `expires_at` と `revoked_at` を持たせ、期限切れ・取消済みを有効対象から除外する（D013） | 有効期限なし・期限内は他の条件に従って評価し、現在時刻と等しい期限・期限切れ・取消済みのDelegationが除外されることを時刻固定テストで示す。有効な一致がなければ `deny` となる |
| Approval判定 | 自動許可できない操作に `require_approval` を返す。ActingForは「承認が必要」と判断するところまでを担当する | `require_approval` が `allow` と区別され、それだけでは実行許可にならないことを文書とテストで示す。承認依頼、通知、画面、承認後の再実行は含めない |
| Audit log | 認可判定を専用AuditEventテーブルへ基本append-onlyで記録する。Agent、Principal、action、resource、フィルタ済みcontext、decision、timestampを扱う（D013） | 3種類の判定について必要項目を追跡できることを自動テストで示す。Filter / Sanitizerによる必要最小限のcontext記録を検証する。具体的なフィルタ仕様と記録失敗時の扱いはAudit設計で決める |
| Rails integration | Rails Gemとして自然に導入・利用できる入口を提供する。generatorの具体構成は後続設計で決める | 対応対象に含めるRailsテストアプリで、インストール、設定、Delegation、判定、Auditまでの一連の利用を統合テストとQuick Startで再現できる |

上表の「提供する範囲」は確定スコープ、「完了条件」はその範囲を検証可能にするための提案である。初期資料の `ActingFor.authorize(...)`、`decision.allowed?`、`rails generate acting_for:install` などは引き続きAPIイメージであり、メソッド名、戻り値クラス、generator構成を確定するものではない。

### 4.3 v0.1全体のDefinition of Done

**状態：提案。** 次をすべて満たした時点をv0.1実装完了とする。

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

- [ドメインモデル基本方針](domain_model_v0_1.md)に基づく属性案の確定、DBスキーマ、識別子の型、Delegation matchingとResourceの詳細
- Public API、例外、Decisionとreason codeの具体形
- Constraintの記述方法とcontextの信頼境界
- AuditEventの詳細スキーマ、Filter / Sanitizerの仕様、記録失敗時の扱い
- Delegationの作成・更新・取消の操作、複数一致時の詳細ルール、未定義・不正入力時の扱い
- Principal自身の認可とDelegationの具体的な接続方法
- Ruby / Railsの対応バージョン
- ライセンス

## 5. 進行順

| 順番 | 作業 | 状態 |
| --- | --- | --- |
| 1 | 解決する問題を1文で確定 | 完了。READMEとD006に記録 |
| 2 | v0.1スコープを正式確定 | 完了。本文とD007に記録 |
| 3 | 用語定義 | 完了。本文とD011に記録 |
| 4 | ドメインモデル設計 | 基本方針を確定（D013）。[設計書](domain_model_v0_1.md)に記録。Delegationの詳細ルールは未確定 |
| 5 | Public API設計 | 初期イメージあり、未確定 |
| 6 | README Quick Start作成 | API設計後 |
| 7 | Gem内部構成設計 | 未着手 |
| 8 | セキュリティモデル設計 | 未着手。各設計工程でも随時検討する |
| 9 | テスト方針 | v0.1の完了条件を定義。詳細設計は未着手 |
| 10 | 実装開始 | 設計後 |

MCPとの責務境界は正式確定済み（2.1〜2.3、D012）。Step 4の基本方針はD013で確定。次はDelegationの意味と詳細ルールを定義し、その後Step 5へ進む。

競合の初期調査、ポジショニングの方向性整理、ActingForへの改名は引き継ぎ済み。競合調査は過去の初期調査として扱い、最新状況を検証した記録とはしない。

## 6. Issue化する候補

**以下は未登録の候補。GitHub Issue番号はまだない。**

| 候補タイトル | 解決したいこと |
| --- | --- |
| v0.1の完了条件を確定する | 4.2の完了条件と4.3のDefinition of Doneをレビューする |
| Principal自身の権限とDelegationの関係を決める | 委任で本人の権限を超えないための、既存認可との接続方法を決める |
| 判定ルールと失効の扱いを決める | 未定義時、競合ルール、期限切れ、取消、判定から実行までの変更を扱う |
| Constraint入力の信頼境界を決める | Agentの申告値に依存せず、金額・通貨・対象を確認する方法を決める |
| require_approval後のホスト要件を決める | 確定済みの責任分界を前提に、承認する人、承認対象との紐付け、内容変更、再利用、再認可を整理する |
| Auditの最小仕様を決める | 判定と実際の実行結果を区別し、記録範囲・秘匿化・失敗時の扱いを決める |

Issueを作成したら、この表の対応する行をIssueへのリンクに置き換える。詳細と進捗はIssue側で管理し、本文を重複管理しない。

## 7. 情報の管理ルール

| 管理先 | 役割 |
| --- | --- |
| README.md | Gemの紹介と、検証済みの使い方 |
| docs/PROJECT.md | 開発方針、スコープ、進行順 |
| docs/DECISIONS.md | 決定事項、理由、提案・確定・保留の区別 |
| docs/domain_model_v0_1.md | v0.1ドメインモデルの基本方針と詳細設計の未決定事項 |
| GitHub Issues | 開発タスク、懸念点、未解決の質問 |

- 会話の区切りで、決まった内容を該当ファイルへ反映する。
- AIの提案を、承認済みの決定事項として記録しない。
- 決定を変える場合は、以前の判断を消さず、変更日と理由を残す。
- 次の会話はREADME、本書、DECISIONS、関連Issueを読んで再開する。
- 元のPDFは初期資料として扱い、日々の更新はMarkdownで行う。

新しい機能を検討するときは、v0.1への必要性、既存標準での代替、ActingForの責務、Railsとしての自然さ、セキュリティ、標準変更への耐性、過剰設計の有無を確認する。

## 8. 次に進めること

1. [ドメインモデル設計書の次工程](domain_model_v0_1.md#22-次に決めること)に従い、Delegationのmatching、Resource、Constraint、複数一致、作成・更新・取消の詳細を定義する。
2. v0.1の完了条件をレビューし、Public APIを設計する。
3. DBスキーマとAudit Filter / Sanitizerの詳細、対応Ruby/Rails、ライセンスを決める。

## 9. 初版の根拠

- `AgentAuthority Project Instructions.pdf`：旧名称での初期構想。
- `ActingFor_Project_Summary.pdf`：改名後の方針整理。
- 2026-09-14の引き継ぎと会話：最新の名称、説明文案、責務、進行順、情報管理方針。
- [ChatGPT共有会話「ActingFor問題定義」](https://chatgpt.com/share/6aa7c32e-77b4-83ee-ad35-ae048e8001ef)：紹介文とv0.1正式スコープ。

初版では、名称と責務について最新の引き継ぎ内容を優先した。PDFの旧名称や未確定のAPI例を、そのまま現在の確定仕様にはしていない。
