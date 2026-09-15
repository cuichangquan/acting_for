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
- 後続決定（2026-09-15）：モデルと関連の基本方針はD013で確定。AgentはPrincipalを直接参照せず、Delegationで関係を表現する。

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
- 後続決定（2026-09-15）：D013でDecisionをValue Objectとする方針を確定。メソッド名や詳細ルールは未確定。
- 後続決定（2026-09-15）：D014で複数一致時のrequire_approval > allowを確定。Decisionの具体クラス・API、エラーの具体的な扱いは引き続き未確定。
- 後続決定（2026-09-15）：D015〜D017でPublic Entry Point、authorize引数、戻り値 `ActingFor::Decision` と概念上のstatusを設計決定。Step 5項目4〜10は未決定。最新の範囲は[Public API Design](public_api_v0_1.md)を参照。

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
- 後続決定（2026-09-15）：D013でドメインモデルとAudit永続化の基本方針を具体化。PROJECTの旧Agent属性案（principal / external_id / provider）はidentifier / name等の最小属性へ置き換えた。

## D008: v0.1の競合判定とfail-closed原則

- 日付：2026-09-14
- 状態：**提案（共有会話では未決定）**
- 決定案：入力が妥当で評価可能な場合だけ自動許可できる。該当なし、必須入力欠落、不正値、条件評価不能は `deny` とする。複数のDelegationが一致した場合は `deny`、`require_approval`、`allow` の順に優先する。
- 理由：障害や曖昧さによる権限昇格を避け、結果をDelegationの追加順やDB取得順に依存させないため。
- 補足：reason codeと、プログラミングエラーを例外として扱う境界はPublic API設計で決める。
- 後続決定（2026-09-15）：D013で一致なしのdefault denyを確定し、explicit deny Delegationはv0.1対象外とした。旧3値のDelegation優先順位案は置き換え、require_approval優先の方向とする。入力欠落・不正値・評価不能時の扱いは引き続き提案。
- 後続決定（2026-09-15）：D014でmatching、Constraint不成立・invalid constraintの除外、default deny、require_approval > allow、判断できなければallowしないfail closedを確定。旧3値優先順位案は現行仕様ではない。例外等のPublic APIとAudit failure policyは未確定。

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
- 後続決定（2026-09-15）：D013で専用AuditEventテーブルへの永続化、基本append-only、ContextのFilter / Sanitizer経由の記録を確定。識別子、フィルタ仕様、記録失敗時の扱いは未確定。
- 後続決定（2026-09-15）：D014で業務処理結果を監査対象外とする責務、agent_identifierとmatched_delegation_idsを含む基本情報、allowlist優先方針を確定。reason_code正式一覧、Filter / Sanitizer API、DB型、Audit failure policyは未確定。

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
- 後続決定（2026-09-15）：Railsモデル、DecisionのValue Object化、Audit Eventの保存方式の基本方針はD013で確定。DBスキーマとPublic APIの詳細は未確定。
- 後続決定（2026-09-15）：D015〜D017でPublic Entry Point、authorize引数、戻り値 `ActingFor::Decision` と概念上のstatusを設計決定。Step 5項目4〜10は未決定。最新の範囲は[Public API Design](public_api_v0_1.md)を参照。

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
- 後続決定（2026-09-15）：Step 4の基本方針はD013で確定。次はDelegationの詳細ルールを定義する。
- 後続決定（2026-09-15）：Step 4はD014で完了。次はStep 5「Public API設計」を実施する。MCP・Authenticationとの責務境界は維持する。

## D013: v0.1のドメインモデル基本方針

- 日付：2026-09-15
- 状態：**確定（基本方針）。属性案、候補operator、複数一致時の詳細ルール、Public APIは未確定。**
- 決定：主要なActiveRecord ModelとテーブルはAgent、Delegation、AuditEventの3つとする。AuthorizationはService、DecisionはValue Objectとし、Action、Resource、Constraintの専用テーブルは作らない。
- 関連：Agentは必須・一意のidentifierと任意のnameを持ち、Principalを直接持たない。ホストRailsアプリのPrincipalをDelegationからpolymorphic associationで参照する。
- 委任：Actionは文字列で原則完全一致、Resourceはtype / idによる識別情報、ConstraintはJSON / JSONBとする。任意コードや高度なPolicy Languageを保存・実行しない。
- 判定：Effectはallow / require_approvalとし、explicit deny Delegationは作らない。有効な一致がない場合はdefault deny。両Effectが一致した場合はrequire_approvalを優先する方向だが、詳細ルールは次工程で定義する。
- 有効性：revoked_atがnilで、expires_atがnilまたは現在時刻より未来の場合に有効とする。starts_atは導入しない。
- 監査：専用AuditEventテーブルに基本append-onlyで記録する。Authorization Contextをそのまま保存せず、Filter / Sanitizerを通して必要最小限にする。
- 理由：AgentとPrincipalの関係を委任として表現し、Rails内の代理権限の判定・取消・監査に必要な最小構成を保つため。
- 正式本文：[v0.1 Domain Model Design](domain_model_v0_1.md)。属性案、例、採用理由と未決定事項は本文で管理する。
- 既存記録との関係：D002、D005、D007、D010、D011、D012の下位設計を具体化する。D008の旧競合案は上記の方針で部分的に置き換え、未定義・不正入力の扱いは引き続き提案とする。
- 次工程：Delegation 1件の意味、matching、Resource、Constraint、複数一致、require_approval、作成・更新・取消の詳細を定義し、その後Step 5「Public API Design」へ進む。
- 根拠：ユーザーが提示したStep 4のドメインモデル設計内容と、docs/domain_model_v0_1.mdへの整理・保存の指示。
- 後続決定（2026-09-15）：詳細ルールはD014で確定。Delegationの意味・基本属性、matching、Resource、Constraint、競合、Lifecycle、Auditを具体化し、単一delegation_id案はmatched_delegation_idsへ変更。Public APIとDB型等は引き続き未確定。

## D014: v0.1 Delegation判定・Constraint・Lifecycle・Audit詳細

- 日付：2026-09-15
- 状態：**確定**
- 決定の範囲：D013の基本方針を以下の詳細ルールで具体化し、Step 4を完了とする。未確定事項は本記録の末尾に明示する。
- Delegationの意味：Agent AがPrincipal Pの代理としてResource RにAction XをConstraint Cの範囲内で実行する権限E。Agent、Principal、Action、Resource Scope、Constraints、Effect、Validityで構成する。基本属性は[設計書](domain_model_v0_1.md#4-delegation)に記録する。
- Matching：Agent、Principal、Action、Resourceが一致し、expiredでもrevokedでもなく、すべてのConstraintを満たす場合だけmatchする。Actionは完全一致のみ。
- Resource：type / idはAuthorization用識別情報とし、ActiveRecord polymorphic associationにしない。typeあり・idありは個別対象、typeあり・idなしはそのtype全体、両方nilはResource不要のAction。typeがnilでidありは不正。typeがnilは全Resourceを意味しない。resource_idのDB型は未確定。
- Constraint：JSON / JSONBのArrayで、各要素はfield / operator / value。複数条件はAND、ContextのトップレベルKeyのみ参照し、同一fieldの複数指定を認める。operatorはeq、lt、lte、gt、gte、in。eqはString / Integer / Boolean、大小比較はInteger、inはContext側scalar・value側Arrayとする。
- 型とfail closed：暗黙の型変換は禁止。missing fieldとnilはConstraint不成立、invalid constraintはmatchさせない。authorityを明確に確認できなければallowしない。空Constraintは[]とし、NULLと使い分けず[]へ統一する方向。Floatを積極的に扱わず、金額等はIntegerを推奨する。
- Constraintの対象外：OR、NOT、nested expressions、nested object access、regex、custom functions、任意Rubyコード、database query、resource traversal、cross-resource conditions、wildcardは作らない。
- Effectと競合：保存するeffectはallow / require_approvalのみ。explicit deny Delegationは作らない。一致0件はdeny、allowのみならallow、require_approvalが1件以上あればrequire_approval。Resource・Constraintの具体性、id、created_at、作成順によるoverrideやpriorityフィールドを導入しない。
- 有効性：revoked_atがnil、かつexpires_atがnilまたは現在時刻より未来なら有効。現在時刻と等しい期限はexpired。starts_atは導入せず、expiredとrevokedを区別する。
- Lifecycle：認可内容は原則immutable。principal、agent、action、resource scope、constraints、effectを直接UPDATEせず、権限変更は旧Delegationのrevokeと新Delegationのcreateで行う。通常操作でhard deleteを前提にしない。
- Audit責務：Authorization Decisionを記録する。allow後の業務処理の成功・失敗はホストRailsアプリの責務。基本情報はagent_id / agent_identifier、Principal、Action / Resource、matched_delegation_ids / reason_code / sanitized context、decision、created_at。
- Audit変更：単一delegation_id案を廃止し、複数一致をmatched_delegation_idsの配列で記録する。一致なしのdenyは[]。新しい中間テーブルは作らず、JSON / JSONB等の配列で十分とする方針。
- Audit保護：原則append-onlyで、通常APIにupdate / destroyを前提としない。DBレベルのWORMや暗号署名は対象外。ContextはFilter / Sanitizerを通し、allowlist方式を優先して保存可能な項目だけを選ぶ方向とする。
- 理由：汎用Policy Engine化を避け、明確な委任だけを認可し、権限変更後も過去Auditが参照するDelegationの意味と判定根拠を保つため。
- 履歴：D013の基本方針を詳細化し、D008の競合・fail closed案とD010のAudit境界を具体化する。過去記録は削除せず、後続決定として参照する。
- 未確定：Public API、Decisionの具体クラス/API、reason_code正式一覧、Audit failure policy、Filter / SanitizerのPublic API、DB schemaの細かな型とresource_idの正式DB型、Ruby / Rails対応バージョン、migration / generator構成。Audit INSERT失敗時のallow維持・deny・例外は固定しない。
- 正式本文：[v0.1 Domain Model Design](domain_model_v0_1.md)。reason_codeの例は候補であり確定一覧ではない。
- 次工程：Step 5「Public API設計」。
- 根拠：ユーザーが2026-09-15に提示したStep 4の正式決定と設計ドキュメント更新指示。
- 後続決定（2026-09-15）：D015〜D017でPublic Entry Point、authorize引数、戻り値 `ActingFor::Decision` と概念上のstatusを設計決定。Step 5項目4〜10は未決定。最新の範囲は[Public API Design](public_api_v0_1.md)を参照。

## D015: Authorization Public Entry Point

- 日付：2026-09-15
- Status：**確定（設計のみ・未実装）**。Step 5項目1。
- Context：Step 4が完了し、Railsアプリから委任認可を呼び出すPublic Entry Pointを決める必要がある。
- Decision：`ActingFor.authorize(...)` を正式なPublic Entry Pointとする。内部構成は未確定とし、Public APIと分離する。
- Rationale：短く責務が明確で、Agent / Principal / Actionを明示できる。`ActingFor::Authorization.call(...)` は内部Service構造を公開するためPublic APIに採用しない。`agent.authorized_to?(:purchase)` はPrincipalが見えにくく、`principal.authorize_agent(...)` はPrincipal ModelへAuthorization責務を持ち込むため採用しない。
- Consequences：内部で `ActingFor::Authorization.call(...)` 等を使うかは実装時に決める。ホスト向けの入口を保ちながら内部構造を変更できる。Agent AuthenticationやMCPとの既存の責務境界は維持する。本決定は内部Serviceの実装を開始する指示ではない。
- 正式本文：[Authorization Entry Point](public_api_v0_1.md#3-authorization-entry-point)。
- 根拠：ユーザーが提示したStep 5 Decision 1と設計ドキュメントのみの更新指示。

## D016: authorize Arguments

- 日付：2026-09-15
- Status：**確定（設計のみ・未実装）**。Step 5項目2。
- Context：D015の入口に、正式用語とStep 4のAction / Resource / Context設計に沿う引数仕様が必要である。
- Decision：`ActingFor.authorize(agent:, principal:, action:, resource: nil, context: {})` とし、keyword argumentsのみを採用する。agent / principal / actionは必須。agentはホスト側で認証済みの操作主体、principalは代理される対象でUserに限定しない。
- Decision（Action）：Symbolで自然に書けるようにし、Stringも受け付ける方向とする。`:purchase` → `"purchase"` のように内部で同一Actionへ正規化する。matchingは完全一致とし、wildcard / regex / hierarchy / `purchase.*` / `orders:*` は扱わない。
- Decision（Resource / Context）：resourceは特定の `product`、type全体の `Product`、Resource不要の `nil` を想定する。nilは全Resourceを意味しない。contextはHashを受け取り、ConstraintはトップレベルKeyのみを参照する。`order.amount` 等のnested object accessはv0.1では評価しない。
- Rationale：複数引数の意味や順番の取り違えを防ぎ、Agent / Principalを明示する。Step 4の最小構成と評価ルールを維持する。
- Consequences：位置引数は採用しない。Action正規化からConstraint値の暗黙変換を認めるものではない。入力不正と例外の境界は項目5、Contextの信頼境界とホストの値確認要件は項目10で決める。本決定では確定しない。
- 正式本文：[authorize Arguments](public_api_v0_1.md#4-authorize-arguments)。
- 根拠：ユーザーが提示したStep 5 Decision 2と設計ドキュメントのみの更新指示。

## D017: Decision Value Object

- 日付：2026-09-15
- Status：**確定（設計のみ・未実装）**。Step 5項目3。
- Context：Step 4でDecisionはValue Object、AuditEventはActiveRecord Modelと決定した。Public APIの戻り値の形を具体化する必要がある。
- Decision：`ActingFor.authorize(...)` はSymbolを直接返さず `ActingFor::Decision` を返す。最低限、概念として `decision.status` を持ち、statusは `:allow` / `:deny` / `:require_approval` の3種類だけとする。
- Decision（意味）：allowはPrincipalからAgentへのDelegation上の実行可能性が確認されたこと、denyは有効なDelegationを確認できない等によりActingForとして許可しないこと、require_approvalは自動実行せずHuman Approvalが必要なことを表す。`require_approval != allow`。allowはRailsアプリ全体の最終認可を意味しない。
- Rationale：3種類の認可結果をValue Objectとして表現し、実行時の判定結果と監査用の永続化を分離する。Step 4のDecision / AuditEventの責務を維持する。
- Consequences：DecisionはActiveRecord Modelや直接DB保存するModelにしない。必要な認可判定情報をAuditEventへ記録する。`allowed?` / `denied?` / `approval_required?` 等は項目4の候補に留める。例外は項目5、Audit呼び出しと失敗時方針は項目8、既存認可との具体的な接続は項目9で決める。Approval Workflowはv0.1の責務外。
- 正式本文：[Decision](public_api_v0_1.md#5-decision)。Step 5は項目1〜3が決定済み、4〜10は未決定で進行中。
- 根拠：ユーザーが提示したStep 5 Decision 3と設計ドキュメントのみの更新指示。

## 追記する際の項目

新しい決定には、次を記録する。

1. IDと短いタイトル
2. 日付と状態
3. 決定または提案した内容
4. その理由
5. 関連するファイル・Issue
6. 残っている未決定事項

ユーザーが明示的に採用したら「提案」を「確定」に更新し、採用日を記録する。後で変更した場合も、以前の理由を消さずに変更履歴を残す。
