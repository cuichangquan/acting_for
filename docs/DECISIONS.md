# ActingFor 決定記録

更新日：2026-09-15

このファイルは、決定内容と理由を残す。現在の開発範囲は[PROJECT](PROJECT.md)、紹介文の本文は[README](../README.md)を参照する。

## 状態の意味

- **確定**：ユーザーが指定した内容、または引き継ぎで確定方針として示した内容。
- **提案**：文案や設計候補。明示的な採用確認は未記録。
- **保留**：判断に必要な情報や設計がまだ揃っていない。
- **変更済み**：後の決定で置き換えたもの。変更先を記録して履歴を残す。

## D001: プロジェクト名とGem名

- 日付：2026-09-14
- 状態：**確定**
- 決定：プロジェクト名は **ActingFor**、Gem名は `acting_for`。
- 理由：初期調査で旧名称に近いOSSが報告され、混同を避けるため改名した。
- 経緯：旧名称は `AgentAuthority`、旧Gem名候補は `agent_authority`。
- 根拠：ユーザーの改名指示と、改名後の引き継ぎ。

## D002: HumanとAgentを別主体として扱う

- 日付：2026-09-14
- 状態：**確定**
- 決定：Agentはユーザー本人ではなく、一定範囲の権限を委任された代理主体とする。
- 理由：誰が要求したかと、誰の権限で動くかを区別する必要がある。
- 設計への反映：`current_user` と `current_agent` を分離する。
- 未決定：具体的なモデル、関連、識別子、認証結果の受け渡し方法。

## D003: Rails内部の委任と認可に責務を絞る

- 日付：2026-09-14
- 状態：**確定**
- 決定：認証済みAgentが、指定されたユーザーの代理として操作してよいかを判断するレイヤーに集中する。
- 理由：独自認証基盤や汎用認可エンジンまで広げると、目的が曖昧になり過剰設計につながる。
- 設計への反映：独自OAuth/OIDC、独自Agent Identity規格、MCP Server本体は作らない。
- 未決定：既存認証・認可との具体的な接続、Adapterの種類と提供時期。

## D004: 特定のLLMやAgent Frameworkに依存しない

- 日付：2026-09-14
- 状態：**確定**
- 決定：特定プロバイダーを前提にせず、Railsでの委任認可を中心に設計する。
- 理由：Agentの実装や外部標準が変わっても、アプリ側の委任認可を扱えるようにする。
- 補足：これは設計方針であり、各プロバイダーとの接続を実装・検証済みという意味ではない。

## D005: 判定結果は3種類を基本とする

- 日付：2026-09-14
- 状態：**確定**
- 決定：`allow` / `deny` / `require_approval` を基本とする。
- 理由：自動許可、拒否、人間の承認が必要な場合を区別する。
- 未決定：戻り値のクラス、メソッド名、エラー時の扱い、ルールの優先順位、承認後の実行方法。
- 補足：`require_approval` は実行許可を意味しない。

## D006: READMEの紹介文

- 日付：2026-09-14
- 状態：**確定**
- 決定：README冒頭に短いキャッチコピー `Rails-native delegated authorization for AI agents.` と、その直後に英語・日本語の説明文を置く。
- 理由：Rails、委任、認可、AI Agent、ユーザーの代理という要素を伝えられる。
- 本文：[README](../README.md)。ここには複製しない。
- 根拠：[共有会話「ActingFor問題定義」](https://chatgpt.com/share/6aa7c32e-77b4-83ee-ad35-ae048e8001ef)でのStep 1と、共有会話で決まった内容をローカルへ反映するというユーザー指示。

## D007: v0.1の具体的な範囲

- 日付：2026-09-14
- 状態：**確定**
- 決定：[PROJECTのv0.1スコープ](PROJECT.md#4-v01スコープ)に記載したAgent representation、Delegation、Authorization、Constraint、Expiration、Approval判定、Audit log、Rails integrationをv0.1の必須範囲とする。
- 要約：認証済みのPrincipal/AgentをホストRailsアプリから受け取り、Delegation、条件、有効期限を評価して `allow` / `deny` / `require_approval` を返し、認可判定をAudit logへ記録する。
- Constraintの境界：金額、resource、contextによる条件付き委任を扱えるようにするが、独自の巨大なPolicy言語は作らない。
- Approvalの境界：`require_approval` を返すところまでとし、承認ワークフローはホストアプリの責務とする。
- 対象外：Agent認証、OAuth Server、OIDC Provider、独自Agent Identity規格、MCP Server、Agent間通信、決済、UI・管理画面・通知、Agent証明書、独自暗号方式、分散Authorization Server、汎用Policy Engine。
- 理由：認証や汎用認可へ責務を広げず、Rails-nativeなAI Agent Delegated Authorizationに集中するため。
- この決定に含まないもの：項目別完了条件、Public API、具体的なモデルとDBスキーマ、Auditの保存方式、対応Ruby/Rails、ライセンス。これらは下位設計として別途決定する。
- 根拠：[共有会話「ActingFor問題定義」](https://chatgpt.com/share/6aa7c32e-77b4-83ee-ad35-ae048e8001ef)でのStep 2と、共有会話で決まった内容をローカルへ反映するというユーザー指示。

## D008: v0.1の競合判定とfail-closed原則

- 日付：2026-09-14
- 状態：**提案（共有会話では未決定）**
- 決定案：入力が妥当で評価可能な場合だけ自動許可できる。該当なし、必須入力欠落、不正値、条件評価不能は `deny` とする。複数のDelegationが一致した場合は `deny`、`require_approval`、`allow` の順に優先する。
- 理由：障害や曖昧さによる権限昇格を避け、結果をDelegationの追加順やDB取得順に依存させないため。
- 補足：reason codeと、プログラミングエラーを例外として扱う境界はPublic API設計で決める。

## D009: v0.1のApproval責任分界

- 日付：2026-09-14
- 状態：**確定**
- 決定：v0.1は `require_approval` の判定までを提供し、承認依頼、メール・Push通知、承認画面、ユーザーによる承認、処理再実行を含む承認ワークフローは提供しない。
- 理由：3値判定の意味を保ちながら、承認者認証、要求の固定、再利用防止など別のセキュリティ領域をv0.1へ持ち込まないため。
- 根拠：D007と同じ共有会話。

## D010: v0.1の監査境界

- 日付：2026-09-14
- 状態：**確定（範囲のみ）**
- 決定：v0.1で認可判定のAudit logを扱う。追跡対象の最小項目はAgent、Principal、action、resource、context、decision、timestampとする。高度な分析、ダッシュボード、SIEM連携は対象外とする。
- 理由：AI Agentによる重要な認可判定を後から追跡できるようにするため。
- 未決定：保存方式、識別子、contextの記録・秘匿化、記録失敗時の扱い。構造化イベント方式とホスト責任での永続化は、共有会話で確定していないため採用済みとは扱わない。
- 根拠：D007と同じ共有会話。

## D011: ActingFor v0.1の正式用語

- 日付：2026-09-14
- 状態：**確定**
- 決定：v0.1の正式用語をPrincipal、Agent、Delegation、Action、Resource、Context、Constraint、Expiration、Authorization、Decision、Approval、Audit Eventとする。各用語の正式な意味と例は[PROJECTの用語定義](PROJECT.md#3-用語定義)に記載する。
- 中心構造：PrincipalからAgentへのDelegationを、Action、Resource、Contextに対して評価し、AuthorizationのDecisionとして `allow` / `deny` / `require_approval` を返す。
- 命名：代理される対象の正式名称にはUserやOwnerではなくPrincipalを使う。Agent IdentityとPolicyはコア用語にしない。
- 責任分界：AgentのAuthenticationは外部の責務とする。Approvalは `require_approval` というDecisionを指し、Approval WorkflowはActingForの責務に含めない。
- 理由：HumanとAgentを別主体として扱い、ActingForの本質が本人確認や汎用Policyではなく、PrincipalからAgentへのDelegationに基づくAuthorizationであることを明確にするため。
- Public APIへの反映：引数名は `agent`、`principal`、`action`、`resource`、`context` の語彙に揃える。`ActingFor.authorize(...)` は現時点では設計イメージであり、Public API自体の確定は後続工程で行う。
- 残っている未決定事項：各概念のRailsモデル、DBスキーマ、Public APIの具体形、Decisionの戻り値クラスとreason code、Audit Eventの保存方式。
- 根拠：Step 3「用語定義」でユーザーが確定した内容。

## D012: ActingForとMCPの正式な責務境界

- 日付：2026-09-15
- 状態：**確定**
- 決定：MCPは「AgentがRailsアプリの機能にどうアクセスするか」を扱い、ActingForは「そのAgentがPrincipalの代理として、その操作を実行してよいか」を扱う。
- Authorizationの境界：MCP側のServer / Toolへのアクセス制御と、ActingForのDelegationに基づく業務操作の認可を別レイヤーとして扱う。MCP側でのアクセス許可はActingForでの実行許可を意味しない。
- 設計への反映：CoreはMCPに依存せず、`mcp` gemやMCP protocol objectをCore APIへ入れない。MCP固有情報は将来Adapterで `agent`、`principal`、`action`、`resource`、`context` に変換する。Tool名とActionの一致を要求しない。
- 認証と実行の境界：認証済みAgentを受け取って認可する。ホストアプリはActingForのDecisionを適用した後に業務処理を実行し、`deny` / `require_approval` では実行しない。承認ワークフローは引き続きホストアプリの責務とする（D009）。
- 理由：接続方法、本人確認、代理権限を分離し、MCP以外のプロトコルでもRails内部の委任認可を利用できるようにするため。
- 正式な責務比較、5つの設計ルール、操作例：[PROJECTの責務境界](PROJECT.md#21-actingforとmcpの正式な責務境界)。英語・日本語の紹介文：[README](../README.md#mcp-and-actingfor)。
- 既存決定との関係：D003、D004の責務分離を具体化する。v0.1スコープ（D007）、Approval境界（D009）、Audit境界（D010）は維持する。
- 残っている未決定事項：AdapterのAPIと提供時期、ドメインモデル、DBスキーマ、Public API、既存認可との具体的な接続。これらを本決定で確定したものとは扱わない。
- 次工程：Step 4「ドメインモデル設計」。
- 根拠：ユーザーが今回提示した、ActingForとMCPの責務境界を正式決定としてファイルへ反映する指示。

## 追記する際の項目

新しい決定には、次を記録する。

1. IDと短いタイトル
2. 日付と状態
3. 決定または提案した内容
4. その理由
5. 関連するファイル・Issue
6. 残っている未決定事項

ユーザーが明示的に採用したら「提案」を「確定」に更新し、採用日を記録する。後で変更した場合も、以前の理由を消さずに変更履歴を残す。
