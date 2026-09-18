# ActingFor 決定記録

更新日：2026-09-18

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
- 後続決定（2026-09-17）：D026でAgent Authentication / Resolutionのホスト責務を明確化。上記は主体の分離を示すもので、ActingForによる `current_agent` helper提供の決定ではない。
- 未決定：具体的なモデル、関連、識別子、認証結果の受け渡し方法。
- 後続決定（2026-09-15）：モデルと関連の基本方針はD013で確定。AgentはPrincipalを直接参照せず、Delegationで関係を表現する。

## D003: Rails内部の委任と認可に責務を絞る

- 日付：2026-09-14
- 状態：**確定**
- 決定：認証済みAgentが、指定されたユーザーの代理として操作してよいかを判断するレイヤーに集中する。
- 理由：独自認証基盤や汎用認可エンジンまで広げると、目的が曖昧になり過剰設計につながる。
- 設計への反映：独自OAuth/OIDC、独自Agent Identity規格、MCP Server本体は作らない。
- 未決定：既存認証・認可との具体的な接続、Adapterの種類と提供時期。
- 後続決定（2026-09-16 / Step 5完了）：既存認可との関係はD024、Contextの信頼境界はD025で確定。Step 5は10 / 10で完了。過去の未決定・進捗表記は当時の記録として残す。

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
- 後続決定（2026-09-16）：D018でDecision Public API、D019でdeny / Exceptionの境界を確定。Step 5は8 / 10決定済み、項目9・10は未決定。

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
- 後続決定（2026-09-17）：D033（Agent validation）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

## D008: v0.1の競合判定とfail-closed原則

- 日付：2026-09-14
- 状態：**変更済み（D013・D014・D019・D023）。以下の決定案は当時の提案であり、現行仕様ではない。**
- 決定案：入力が妥当で評価可能な場合だけ自動許可できる。該当なし、必須入力欠落、不正値、条件評価不能は `deny` とする。複数のDelegationが一致した場合は `deny`、`require_approval`、`allow` の順に優先する。
- 理由：障害や曖昧さによる権限昇格を避け、結果をDelegationの追加順やDB取得順に依存させないため。
- 補足：reason codeと、プログラミングエラーを例外として扱う境界はPublic API設計で決める。
- 後続決定（2026-09-15）：D013で一致なしのdefault denyを確定し、explicit deny Delegationはv0.1対象外とした。旧3値のDelegation優先順位案は置き換え、require_approval優先の方向とする。入力欠落・不正値・評価不能時の扱いは引き続き提案。
- 後続決定（2026-09-15）：D014でmatching、Constraint不成立・invalid constraintの除外、default deny、require_approval > allow、判断できなければallowしないfail closedを確定。旧3値優先順位案は現行仕様ではない。例外等のPublic APIとAudit failure policyは未確定。
- 後続決定（2026-09-16）：D019でAPI誤用・設定不正・内部異常をdenyへ変換せずExceptionとする境界、D023でAudit保存失敗時のExceptionを確定。必須入力欠落・不正値を一律denyとする旧案は採用しない。D014のConstraint不成立・invalid constraintをmatchさせないルールは維持する。
- 後続決定（2026-09-17）：D034（AuditEvent詳細）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

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
- 後続決定（2026-09-16）：D022でauthorize内部のAudit自動記録、D023で保存失敗時にDecisionを返さずExceptionとする方針を確定。reason_code正式一覧、Filter / Sanitizer API、DB型は引き続き未決定。
- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）、D033（Agent validation）、D034（AuditEvent詳細）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

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
- 後続決定（2026-09-16）：D018〜D023でStep 5項目4〜8を確定。最新の進捗は8 / 10で、項目9・10は未決定。
- 後続決定（2026-09-17）：D034（AuditEvent詳細）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

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
- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）、D033（Agent validation）、D034（AuditEvent詳細）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。
- 後続決定（2026-09-17追加）：D043・D045〜D048で該当する保留を解消。上記の未決定表記は当時の履歴であり、現在の仕様は後続決定に従う。

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
- 後続決定（2026-09-16）：D018〜D023でDecision Public API、deny / Exception、authorize!非提供、Delegation専用API、自動Auditと保存失敗時Exceptionを確定。ドメインモデルは変更しない。Step 5は8 / 10決定済み。
- 後続決定（2026-09-16 / Step 5完了）：既存認可との関係はD024、Contextの信頼境界はD025で確定。Step 5は10 / 10で完了。過去の未決定・進捗表記は当時の記録として残す。
- 後続決定（2026-09-17）：Migration提供方式と独自Generator非提供はD028で確定。DB型・Migration実コード等は未決定のまま維持する。
- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）、D032（Resource identity・Delegation API / validation）、D033（Agent validation）、D034（AuditEvent詳細）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。
- 後続決定（2026-09-17追加）：D035〜D048で該当する保留を解消。上記の未決定表記は当時の履歴であり、現在の仕様は後続決定に従う。

## D015: Authorization Public Entry Point

- 日付：2026-09-15
- Status：**確定（設計のみ・未実装）**。Step 5項目1。
- Context：Step 4が完了し、Railsアプリから委任認可を呼び出すPublic Entry Pointを決める必要がある。
- Decision：`ActingFor.authorize(...)` を正式なPublic Entry Pointとする。内部構成は未確定とし、Public APIと分離する。
- Rationale：短く責務が明確で、Agent / Principal / Actionを明示できる。`ActingFor::Authorization.call(...)` は内部Service構造を公開するためPublic APIに採用しない。`agent.authorized_to?(:purchase)` はPrincipalが見えにくく、`principal.authorize_agent(...)` はPrincipal ModelへAuthorization責務を持ち込むため採用しない。
- Consequences：内部で `ActingFor::Authorization.call(...)` 等を使うかは実装時に決める。ホスト向けの入口を保ちながら内部構造を変更できる。Agent AuthenticationやMCPとの既存の責務境界は維持する。本決定は内部Serviceの実装を開始する指示ではない。
- 正式本文：[Authorization Entry Point](public_api_v0_1.md#3-authorization-entry-point)。
- 根拠：ユーザーが提示したStep 5 Decision 1と設計ドキュメントのみの更新指示。
- 後続決定（2026-09-17）：内部Serviceの配置はD028のActingFor::Internal配下に決定。Public Entry Pointは維持し、内部の具体的実装は未決定。

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
- 後続決定（2026-09-16）：入力不正と例外の境界はD019で確定。具体的なException class名とContextの信頼境界は未決定。
- 後続決定（2026-09-16 / Step 5完了）：既存認可との関係はD024、Contextの信頼境界はD025で確定。Step 5は10 / 10で完了。過去の未決定・進捗表記は当時の記録として残す。
- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）、D032（Resource identity・Delegation API / validation）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

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
- 後続決定（2026-09-16）：4つのDecision Public APIはD018、deny / ExceptionはD019、Audit呼び出しと保存失敗時方針はD022・D023で確定。Step 5は8 / 10決定済み、項目9・10は未決定。
- 後続決定（2026-09-16 / Step 5完了）：既存認可との関係はD024、Contextの信頼境界はD025で確定。Step 5は10 / 10で完了。過去の未決定・進捗表記は当時の記録として残す。

## D018: Decision Public API

- 日付：2026-09-16
- Status：**確定（設計のみ・未実装）**。Step 5項目4。
- Context：D017のValue Objectに対し、呼び出し側が3状態を明確に区別できるAPIが必要である。
- Decision：`decision.status`、`decision.allowed?`、`decision.denied?`、`decision.approval_required?` を正式採用する。statusは `:allow` / `:deny` / `:require_approval`。各predicateは対応するstatusの場合にtrueとなり、require_approvalの場合の `allowed?` は必ずfalseとする。
- Rationale：承認が必要な状態を実行許可と混同せず、最小のAPIで3状態を表現するため。
- Consequences：v0.1では `success?`、`permitted?`、`executable?` を作らない。Decisionの追加属性は未決定。
- 正式本文：[Decision Public API](public_api_v0_1.md#6-decision-public-api)。
- 根拠：ユーザーが提示した今日のStep 5項目1〜8の決定内容と、設計ドキュメントのみの更新指示。

- 後続決定（2026-09-17追加）：D050でDecision Public APIを4つだけに限定し、追加属性非提供・constructor非保証を確定。

## D019: deny vs Exception

- 日付：2026-09-16
- Status：**確定（設計のみ・未実装）**。Step 5項目5。
- Context：通常の権限不成立とAuthorization処理そのものの異常を区別する必要がある。
- Decision：Authorizationとして正常に判定できたが権限が成立しない場合はdenyとする。有効なmatching Delegationなし、expired、revoked、Constraint不成立、Resource / Action不一致などが該当する。処理そのものが成立しない場合はExceptionとし、`agent: nil`、`principal: nil`、`action: nil`、`context: "invalid"`、API誤用・設定不正・内部異常をdenyへ潰さない。
- Rationale：権限がないという正常な判定と、API・システムの異常を混同しないため。
- Consequences：「Authorizationとして判断できた → Decision」「処理そのものが成立しない → Exception」を基本原則とする。D014のmatching / Constraintルールは維持する。具体的なException class名は未決定。
- 正式本文：[deny vs Exception](public_api_v0_1.md#7-deny-vs-exception)。
- 根拠：ユーザーが提示した今日のStep 5項目1〜8の決定内容と、設計ドキュメントのみの更新指示。
- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

## D020: authorize!をv0.1では提供しない

- 日付：2026-09-16
- Status：**確定（設計のみ・未実装）**。Step 5項目6。
- Context：AuthorizationのPublic APIにBang APIを加えるか判断する必要がある。
- Decision：v0.1では `ActingFor.authorize!(...)` を提供しない。Public Authorization APIは `ActingFor.authorize(...)` のみとする。
- Rationale：allow / deny / require_approvalの3状態を持ち、Bang APIはdeny / require_approvalをどのようにExceptionへ変換するかという追加の意味付けを必要とするため。
- Consequences：必要性が明確になった場合にv0.2以降で再検討できる。本決定から `delegate!` の採否を推測しない。
- 正式本文：[authorize!をv0.1では提供しない](public_api_v0_1.md#8-bang-api)。
- 根拠：ユーザーが提示した今日のStep 5項目1〜8の決定内容と、設計ドキュメントのみの更新指示。
- 後続決定（2026-09-17）：D032（Resource identity・Delegation API / validation）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

## D021: Delegation専用Public API

- 日付：2026-09-16
- Status：**確定（設計のみ・未実装）**。Step 5項目7。
- Context：D014ではDelegationの認可内容は原則immutable、権限変更は旧Delegationのrevoke + 新Delegationのcreateとした。
- Decision：作成・取消はActiveRecord直接操作をPublic APIの基本とせず、専用APIを提供する方向とする。作成用専用Public APIを用意し、基本案は `ActingFor.delegate(agent: agent, principal: user, action: :purchase, resource: product, constraints: [...], effect: :allow)`。revokeの基本形は `delegation.revoke!` とする。
- Rationale：ActiveRecordの直接操作を基本にするとLifecycleルールを壊しやすいため。
- Consequences：hard deleteではなくrevocationとして無効化し、権限変更はrevoke + createで行う。作成APIの細かな引数・validation APIと `delegate!` の有無は未決定であり、例から確定しない。
- 正式本文：[Delegation専用Public API](public_api_v0_1.md#9-delegation-api)。
- 根拠：ユーザーが提示した今日のStep 5項目1〜8の決定内容と、設計ドキュメントのみの更新指示。
- 後続決定（2026-09-17）：D032（Resource identity・Delegation API / validation）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

## D022: Auditをauthorize内で自動記録

- 日付：2026-09-16
- Status：**確定（設計のみ・未実装）**。Step 5項目8（Audit）。
- Context：認可判定のAudit記録を呼び出し側がどのように行うか決める必要がある。
- Decision：AuditEvent生成・保存は `ActingFor.authorize(...)` 内部で自動的に行う。Authorization → Decision生成 → AuditEvent保存 → Decisionを返す、の順とする。`ActingFor.audit(decision)` のような追加呼び出しをRails開発者へ要求しない。
- Rationale：Audit記録忘れを防ぐため。
- Consequences：D014のAudit責務・append-only・ContextのFilter / Sanitizer方針は維持する。保存失敗時はD023に従う。reason_code正式一覧とFilter / SanitizerのPublic APIは未決定。
- 正式本文：[Auditをauthorize内で自動記録](public_api_v0_1.md#10-audit)。
- 根拠：ユーザーが提示した今日のStep 5項目1〜8の決定内容と、設計ドキュメントのみの更新指示。
- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）、D034（AuditEvent詳細）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

## D023: Audit保存失敗時はException

- 日付：2026-09-16
- Status：**確定（設計のみ・未実装）**。Step 5項目8（Audit failure）。
- Context：Authorization結果がallowでもAuditEvent INSERTに失敗する場合の扱いが必要である。
- Decision：AuditEvent保存に失敗した場合はExceptionとして処理を中断する。allowを返さず、denyへ変換せず、Decisionを返さず、Business Logicへ進ませない。
- Rationale：「権限がない」というAuthorization結果ではなく、「ActingForのAuthorization処理を正常に完了できなかった」というシステム異常だから。
- Consequences：D019のdeny / Exception境界をAudit保存にも適用する。具体的なException class名は未決定。既存認可との関係（項目9）とContextの信頼境界（項目10）は本決定では確定しない。
- 正式本文：[Audit保存失敗時はException](public_api_v0_1.md#10-audit)。
- 根拠：ユーザーが提示した今日のStep 5項目1〜8の決定内容と、設計ドキュメントのみの更新指示。
- 後続決定（2026-09-16 / Step 5完了）：既存認可との関係はD024、Contextの信頼境界はD025で確定。Step 5は10 / 10で完了。過去の未決定・進捗表記は当時の記録として残す。
- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

## D024: Existing Authorization Integration

- 日付：2026-09-16
- Status：**確定（設計のみ・未実装）**。Step 5項目9。
- Context：Delegationが存在してもPrincipal本人に操作権限があるとは限らず、委任後にPrincipalの権限が失われる場合もある。既存認可と委任認可の責任分界が必要である。
- Decision：Principal自身の現在の権限確認はホストRailsアプリの責務とし、Delegation作成時だけでなく実行時にも確認する。ActingForはPrincipal → AgentのDelegation認可のみを担当する。Business Logic実行にはホスト認可とActingFor認可の両方が必要。概念上はAuthentication → Principal特定 → Host Authorization → ActingFor Authorization → Business Logicとする。
- Decision（実効権限）：Agentの実効権限 = Principal自身の権限 ∩ Delegationされた権限。DelegationだけでPrincipalの権限を超えさせない。require_approvalもPrincipalの権限を拡張せず、Principalに権限がなければ停止する。
- Decision（依存）：ホストはPundit / CanCanCan / Action Policy / 独自Authorization等を利用できる。ActingFor Coreはこれらに依存せず、直接呼び出さない。
- Rationale：Delegationを権限昇格の仕組みにせず、特定のAuthorization Libraryへの依存や汎用Policy Engine化を避けるため。
- Consequences：ホストは残存するDelegationだけを根拠に業務処理を実行しない。Principalに権限がありrequire_approvalとなった場合も自動実行せず、ホストのApproval Workflowへ進む。Adapter、host_authorizer:、principal_authorizer:やApproval Workflowの詳細は今回設計しない。
- 正式本文：[Existing Authorization Integration](public_api_v0_1.md#12-existing-authorization-integration)。
- 根拠：ユーザーが提示したStep 5項目9の正式決定と、設計ドキュメントのみの更新指示。

## D025: Context Trust Boundary

- 日付：2026-09-16
- Status：**確定（設計のみ・未実装）**。Step 5項目10。
- Context：Agentが申告する金額等は現実世界やDBの値と一致するとは限らない。Contextの真偽と、API形式・Constraint評価を区別する必要がある。
- Decision：Contextの正確性・信頼性はホストアプリの責務。Agent申告値を無条件に渡さず、必要に応じDB等の信頼できる情報源から再取得・確認し、確定したContextを渡す。ActingForは値の真偽を検証せず、渡されたContextでConstraintを評価する。
- Decision（責務外）：ActingForはProductのDB取得、価格・通貨・Resource所有者の確認、Agent申告値とDB値の比較などのBusiness Logicを実行しない。v0.1ではtrusted_context: / untrusted_context:やTrustedContext / VerifiedContext / ContextVerifierを導入しない。
- Decision（形式と不足）：`context: "hello"` 等の形式不正はExceptionでありdenyではない。`context: {}` は形式として有効だが必要fieldがなければConstraint不成立となり、そのDelegationはmatchしない。D014のfail closedとD019のdeny / Exception境界を維持する。
- Rationale：業務データの正しさはホストが保証し、ActingForをConstraint評価という責務に留め、v0.1の過剰設計を避けるため。
- Consequences：Context確定とAudit Filter / Sanitizerを混同しない。Exception class正式一覧、reason_codeや既存の未決定詳細を追加確定しない。本決定とD024によりStep 5は10 / 10で完了（Design finalized）。実装済みを意味しない。次はStep 6「README Quick Start作成」だが、今回は着手しない。
- 正式本文：[Context Trust Boundary](public_api_v0_1.md#13-context-trust-boundary)。
- 根拠：ユーザーが提示したStep 5項目10の正式決定と、設計ドキュメントのみの更新指示。
- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）、D034（AuditEvent詳細）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

## D026: Agent Registration / Resolution Boundary

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：ローカルAgent Modelの存在が、Userのような会員登録・ログインやAuthentication / Session管理の提供と誤解されない責務境界が必要である。
- Decision：`ActingFor::Agent` は外部AgentをRails内部で識別するためのローカル表現。AgentをUserと同じように会員登録・ログインさせることは前提にしない。ActingForはAgentを保持するが、認証・ログインさせる仕組みは提供しない。
- Decision（Authentication / Resolution）：OAuth / OIDC / API Key / MCPその他の接続・認証方法はHost Applicationまたは外部認証基盤の責務。認証済み外部Agentをローカル `ActingFor::Agent` へresolveする責務もHost Application側とする。
- Decision（Provisioning）：Agentレコードの作成方法はv0.1では固定しない。管理画面、API、初回認証時、seed、その他ホスト独自方式は例であり、正式なProvisioning APIとして確定しない。
- Decision（README）：Quick Startでは `current_agent` を使わず、ホストにより認証・解決済みの `shopping_agent` を使う。`current_agent` helperやAgent作成・登録・解決・認証の新しいPublic APIを追加確定しない。
- Rationale：Railsの `current_user` と同様のAuthentication / Session機能までGemが提供するという誤解を避け、外部の本人確認とRails内部の委任認可を分離するため。
- Consequences：D002の主体分離、D012のMCP非依存とAuthentication責務外、D013のローカルAgent表現を維持・補足する。AgentはPrincipalを直接belongs_toせず、関係はDelegationで表現する。Domain ModelとStep 5仕様は変更しない。Provisioning方式・具体APIは未固定のまま残す。
- 正式本文：[Agent Registration / Resolution Boundary](PROJECT.md#24-agent-registration--resolution-boundary)、[Domain ModelのAgent](domain_model_v0_1.md#3-agent)。
- 根拠：ユーザーが提示したAgent Registration / Resolution Boundaryの正式決定と、設計ドキュメントのみの更新指示。
- 後続決定（2026-09-17）：D033（Agent validation）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

## D027: README Quick Start Design

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。Step 6は **Complete / Design-stage Quick Start finalized**。
- Context：Rails開発者が数分でActingForの価値と基本的な使い方を理解でき、未実装のGemを実行可能と誤認しないREADMEが必要である。
- Decision（構成）：代表例は「Shopping AgentがPrincipalの代理として商品を購入する」、Actionは `purchase`。Principal / Agent / Delegation / Action / Resource / Context / Constraint / Decisionを使用する。全体フロー、認証・解決済みAgent、委任、認可、Decision、既存認可、verified Context、自動Auditの8節とする。ActingForはBusiness Logicを実行せず、Hostが次の処理を判断する。
- Decision（段階）：冒頭でDesign-stage example、未実装・未リリース・実行不可を一度明示する。Installation、Gem追加、bundle installは掲載しない。
- Decision（Delegation）：`ActingFor.delegate(...)` の設計例は2件のみ。10,000円以下をallow、10,000円超かつ30,000円以下をrequire_approvalとする。30,000円超はmatching Delegationなしでdeny。組み込み金額ルールではなく委任設定例であり、explicit deny Delegationは使用しない。D021の方向性を示すだけで、全引数・default・validation・delegate!の有無は確定しない。
- Decision（Authorization / Decision）：D026の `shopping_agent`、実際の `product`、ホストが取得・確認した `product.price` を用いる。8,900円のallow例を中心に、20,000円のrequire_approval、50,000円のdenyを表で示す。D018のstatus / allowed? / denied? / approval_required?を使用し、require_approval != allow、承認時のallowed?はfalseと明示する。
- Decision（Host / Context）：Host Authorization AND ActingFor Authorizationを満たして業務処理へ進む。Principalの現在の権限確認はHost責務で、allowはアプリ全体の最終認可ではなく、require_approvalも権限を拡張しない。CoreはPundit等を直接呼ばない。Agent申告の業務上重要な値を無検証で使わず、HostがContextを確認・確定し、ActingForがConstraintを評価する。paramsの一般的な禁止や新しいContext APIは導入しない。
- Decision（Audit）：authorize内部でAuthorization DecisionをAuditEventへ自動記録し、別途audit呼び出しを要求しない。保存失敗時はExceptionで、allowもdenyもDecisionも返さず、Business Logicへ進ませない。
- Decision（除外）：MCP詳細、認証方式の具体説明、Provisioning Public API、Constraint全仕様、Exception class一覧、AuditEvent全カラム・reason_code・Context Filter / Sanitizer、Approval Workflow実装、Pundit等の具体Integrationコード、その他未決定API、将来機能はQuick Startへ入れない。詳細は既存設計書へ委ねる。
- Rationale：代表例と短い責務説明で利用価値を伝え、設計例を実装済み機能や追加API確定と誤解させないため。
- Consequences：READMEへの反映によりStep 6設計を完了とする。Gem実装完了やRunnable Quick Start完了ではない。Step 5は10 / 10完了のまま仕様を変更せず、D014のmatching・immutable・require_approval > allow等とD018〜D025を維持する。D026のProvisioningと既存の未決定詳細も追加確定しない。
- 正式本文：[README Quick Start](../README.md#quick-start)、[Step 6の記録](PROJECT.md#52-step-6-readme-quick-start-design)。
- 根拠：ユーザーが提示したStep 6 README Quick Start Designの正式決定と、設計ドキュメントのみの更新指示。
- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）、D032（Resource identity・Delegation API / validation）、D034（AuditEvent詳細）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。

- 後続決定（2026-09-17追加）：D058でREADMEのRunnable Quick Startをv0.1必須成果物とし、対象範囲を確定。上記はDesign-stageの履歴であり、Runnable本文は未作成。

## D028: Step 7 Gem Structure Design

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。Step 7は **Complete / Design finalized / Not implemented**。
- Context：Step 4のDomain Model、Step 5のPublic API、Step 6のQuick Startを維持し、Rails Gemとしての最小構成とPublic / Internalの境界を記録する必要がある。
- Decision（Engine）：Headless `Rails::Engine` と `isolate_namespace ActingFor` を採用する。Routes / Controllers / Views / Assets前提のWeb UIは作らない。EngineがRailtieの役割を含むため独立した `ActingFor::Railtie` は作らない。
- Decision（Models）：`app/models/acting_for/` にapplication_record.rb、agent.rb、delegation.rb、audit_event.rbを配置する設計。対応する `ActingFor::ApplicationRecord` を共通親クラスとし、`ActingFor::Agent` / `ActingFor::Delegation` / `ActingFor::AuditEvent` を置く。
- Decision（Internal）：`app/services/acting_for/internal/` にauthorization.rbとconstraint_evaluator.rbを置き、`ActingFor::Internal::Authorization` / `ActingFor::Internal::ConstraintEvaluator` とする。Public APIではなく、具体的実装・内部構造は将来変更可能。
- Decision（Decision）：`ActingFor::Decision` は `lib/acting_for/decision.rb` に置くPublic Value Object。ActiveRecord ModelでもServiceでもない。D018のstatus / allowed? / denied? / approval_required?を維持する。
- Decision（Migration / Tables）：Gem側の `db/migrate/` で3つの主要ModelのMigrationを管理し、Rails Engine標準方式でHost Applicationへコピー・DBに適用する。独自Migration DSL・DBセットアップ機構は作らない。テーブル名は `acting_for_agents` / `acting_for_delegations` / `acting_for_audit_events` とし、全て `acting_for_` prefixを持つ。具体的なカラム型・実コードは未決定、taskのコマンド名はRails実装時に確認する。
- Decision（Generator）：v0.1では独自Generatorを作らない。acting_for:install / acting_for:agent / acting_for:config等は提供しない。将来の追加は可能だがv0.1の約束には含めない。
- Decision（Entry Point / Load）：`lib/acting_for.rb` はauthorize / delegateの薄いPublic Entry Pointとする。libはGem Entry Point / Public Ruby API、appはRails Components。version / decision / engine等の必要最小限を明示的に読み込み、app/models / app/servicesはRails / Zeitwerkのautoloadに任せる。
- Decision（Tests）：最低限 `test/dummy/` を想定するDummy Rails Appを持ち、Engine、ActiveRecord、Migration、autoload、Hostとのintegrationを実際のRails環境で検証できる構成とする。Minitest / RSpecとTest Strategy詳細はStep 8で決定し、今回着手しない。
- Decision（Configuration）：必須設定が未確定のため、現時点でconfiguration.rbとconfig/initializers/acting_for.rbを作らず、空のConfiguration APIをPublic化しない。Audit Sanitizerを理由に追加しない。
- Decision（Dependencies）：rails meta-gem全体に依存せず、最小のRails component単位とする。設計対象はactiverecord / railties / activesupport。Pundit、CanCanCan、Action Policy、MCP関連Gem、OAuth / OIDC関連Gem、OpenAI / Claude / Gemini SDKには依存しない。version constraintと対応Ruby / Rails versionは未決定。
- Decision（Boundary）：PublicはActingFor.authorize / ActingFor.delegate / ActingFor::Decision / ActingFor::Agent / ActingFor::Delegation / ActingFor::AuditEvent。InternalはActingFor::Internal::*で利用者向けAPIではなく、READMEでは原則利用例に示さない。delegateの全引数・default・validation、delegate!の有無は追加確定しない。
- Rationale：Hostとの名前・テーブル衝突を避け、所有コンポーネントと公開境界を明確にする。Rails標準機能を利用して保守対象と依存を最小限にし、内部実装の変更余地を残す。Dummy Rails AppでRailsとの統合を検証できる構成にする。
- Consequences：Step 7正本にv0.1 Minimal Gem Structureを記録するが、実装ファイルは作成・変更しない。Step 4〜6の仕様を維持し、GemはNot implemented / Not released。次はStep 8 Test Strategy（今回は未着手）。従来の進行順でStep 9だったテスト方針をStep 8へ更新し、セキュリティモデル設計の後続の順番は固定しない。Exception class名、reason_code、Audit Sanitizer Public API、Approval Workflow、各Adapter等の未決定詳細は維持する。
- 正式本文：[Gem Structure Design](gem_structure_v0_1.md)、[Step 7の記録](PROJECT.md#53-step-7-gem-structure-design)、[README](../README.md#project-documents)。
- 根拠：ユーザーが提示したStep 7 Gem Structure Designの正式決定と、設計ドキュメントのみの更新指示。
- 後続決定（2026-09-17）：D029でStep 8を完了し、Minitest採用とTest Strategyを設計確定。上記の未決定・未着手表記はStep 7時点の履歴として残す。
- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）、D032（Resource identity・Delegation API / validation）、D034（AuditEvent詳細）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。
- 後続決定（2026-09-17追加）：D035・D036・D038・D043〜D048で該当する保留を解消。上記の未決定表記は当時の履歴であり、現在の仕様は後続決定に従う。

- 後続決定（2026-09-18）：Migration提供・更新・保持・Runtime境界・明示的取り込み・3分割・reversibilityはD060〜D066で確定。

## D029: Step 8 Test Strategy Design

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。Step 8は **Complete / Design finalized / Not implemented**。Testコードはまだ存在しない。
- Context：Step 4〜7の決定を維持し、v0.1の必須機能とSecurity Boundaryを検証するTest Strategyを正式に記録する必要がある。
- Decision（Framework / 境界）：Minitestを正式採用し、RSpecはv0.1では採用しない。DecisionとConstraintEvaluatorのpure / internal logicはUnit Test、Rails / DB / Public APIをまたぐ処理はIntegration Testとする。authorizeはAudit保存まで含む中心的なIntegration Test対象とする。
- Decision（Dummy）：`test/dummy` は最小Rails integration host。Engine、ActiveRecord、Migration、autoload、authorize、Host Principal / Resourceとの連携を検証する。EC製品、Approval Workflow、MCP Server、OAuth / OIDC、UI、Controller E2E、複雑なBusiness Logicは含めない。
- Decision（Unit）：Decisionの3状態と4つのPublic API、require_approval != allowを検証する。ConstraintEvaluatorは単一条件の成立・不成立、AND、境界値、field不足、不正・評価不能、型不一致、nested非対応、fail-closedを検証する。lookup、effect優先、final Decision、AuditはUnit対象外。constructorや内部method・class構造を契約にしない。
- Decision（Authorization / Matching）：Public behaviorを中心に全matching条件、allow / deny / require_approval、一致なしdeny、require_approval > allow、期限・取消・Action / Resource / Constraint mismatchを検証する。expires_at == nowはexpired。結果をDB id、created_at順、作成順、specificityへ依存させない。通常の認可不成立はDecision、API misuse / internal errorはExceptionとする。
- Decision（Audit）：authorize経由で3状態すべての自動保存、Agent / Principal / Action / Resource / Decision / matched_delegation_ids / sanitized Context / timestampの追跡を検証する。一致なしは空配列、複数一致は該当Delegationを追跡する。記録はAuthorization Decisionであり、業務成否ではない。全結果について保存失敗時はDecisionを返さず、denyへ変換せず、Exceptionで中断し、Business Logicへ進ませない。
- Decision（Rails）：DummyでEngine boot、Zeitwerk / autoload、isolate_namespace、Migration、Model接続、Host namespace衝突防止と3つのacting_for_テーブルを検証する。DB型・Migration実装詳細・task名は固定しない。
- Decision（Security）：Hostの現在権限とDelegationの積集合、委任後の権限喪失、Approvalによる権限拡張なしをIntegration Testで検証する。CoreはHost Authorization libraryを直接呼ばず、特定libraryのAPIを契約にしない。ContextはHostが値を確定し、Coreは渡された値でConstraintを評価する。形式不正はException、必要field不足はConstraint不成立。新しいContext APIは導入しない。fail-closedをUnit / Integration双方で扱い、API misuse / configuration error / internal error / Audit failureをdenyへ変換しない。
- Decision（Acceptance Criteria）：Agent representation、Delegation、Authorization、Constraint、Expiration / Revocation、Approval、Audit、Rails integrationへTest上のAcceptance Criteriaを対応付ける。Host Authorization Boundary、Context Trust Boundary、fail-closedを横断的要件として追加する。Resource matchingとContextのConstraint evaluationを区別し、Rails integrationは導入・Engine boot・Migration・Delegation・Authorization・Audit等で検証する。
- Rationale：Rails-nativeな構成と最小Hostでv0.1に必要な検証を行い、不要なFramework依存を増やさず、内部実装の変更余地とSecurity Boundaryを守るため。
- Consequences：D028のTest Framework保留を本決定で解消する。Step 4〜7の製品仕様は変更しない。PROJECT 4.3のDefinition of Done全体はProposal / 提案を維持する。Ruby / Rails version、CI matrix、static analysis、License、Runnable Quick Start、Release notes、Exception class名、reason_code正式一覧、Filter / Sanitizer Public API、delegate!等は未決定のまま。次工程の番号・順序は新たに決めず、実装には進まない。GemはNot implemented / Not released。
- 正式本文：[Test Strategy Design](test_strategy_v0_1.md)、[Step 8の記録](PROJECT.md#54-step-8-test-strategy-design)。
- 根拠：ユーザーが提示したStep 8 Test Strategy Designの正式決定と、設計ドキュメントのみの更新指示。
- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）、D032（Resource identity・Delegation API / validation）、D034（AuditEvent詳細）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。
- 後続決定（2026-09-17追加）：D035・D043・D045・D046・D048で該当する保留を解消。上記の未決定表記は当時の履歴であり、現在の仕様は後続決定に従う。

- 後続決定（2026-09-17追加）：D057〜D059でstatic analysis（RuboCop）、Runnable Quick Start、Release Notesの必須要件を確定。上記の該当する未決定表記は当時の履歴。具体的設定・コマンド・配置は未決定。

- 後続決定（2026-09-18）：CI基盤・trigger・RuboCop合否境界はD067・D072・D073、全体DoDはD076で確定。

## D030: v0.1 Security Model Design

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。Security Model Designは **Complete / Design finalized / Not implemented**。
- Context：Step 8完了後、認証・解決済みAgentがPrincipalから委任された範囲を超えて操作することを防ぐため、Security requirementとHost Applicationとの責務境界を整理する必要がある。
- Decision（Threat / Trust Boundary）：HostがAuthentication、Agent / Principal Resolution、Resource / Context確定を担当し、ActingForがDelegation / Constraint / Expiration / Revocation / Authorizationを評価する。認証突破、OAuth / OIDCやMCP自体、HostやDB管理権限の完全な乗っ取り、Business Operation自体の安全性はCoreの直接責務外。
- Decision（Fail Closed / Secure Defaults）：権限を明確に確認できなければallowしない。無効・不一致のDelegationはmatchさせず、有効なmatchがなければdeny。Unknown / Invalid / Ambiguousや設定不足で権限を拡大しない。Authorization failureはDecision(:deny)、System / API / configuration failureはExceptionとし、異常をdenyへ潰さない。
- Decision（Privilege / Binding）：実効権限はPrincipal Current AuthorityとDelegated Authorityの積集合。HostがPrincipalの現在権限を確認し、古いDelegationやrequire_approvalで権限を拡張しない。明示されたAgent / Principalの組み合わせで評価し、別Principalの委任を流用しない。Decisionは判定時点のAgent / Principal / Action / Resource / Contextに対する結果であり、再利用可能なAuthorization Tokenではない。入力・Delegation状態・Principal権限等の判断に影響する状態が変われば再authorizeする。
- Decision（Audit Integrity / Confidentiality）：allow / deny / require_approvalすべてでAuditEvent保存成功後にのみDecisionを返す。保存失敗はDecisionを返さずExceptionとし、denyへ変換せずBusiness Logicへ進ませない（D022・D023・D029）。Raw ContextはFilter / Sanitizerを経由し、allowlist優先で必要最小限を保存する。Token / API Keyを保存せず、Secretを無条件に保存しない。
- Decision（Delegation Tamper / 操作保護）：認可内容はimmutable、権限変更はrevoke + createとする。作成・revokeするcallerのAuthentication / Host AuthorizationはHost責務で、専用Public APIも代替しない。
- Decision（Replay / Time / TOCTOU）：二重実行防止、idempotency、exactly-onceはHost責務。ExpirationにはActingFor側の信頼できる現在時刻を使い、外部callerの任意時刻を信頼しない。既存の時刻固定Test方針は維持する。DecisionとBusiness Logicの完全な原子性は単体で保証せず、Hostは重要操作の実行直前と判断に影響する状態変更後に再authorizeする。
- Decision（Resource / Constraint）：Hostが確定した一意に識別可能なResource情報を用い、既存のResource scopeとnilの意味は維持する。Constraint評価でeval / instance_eval / DB由来の任意Ruby code・Proc・Lambdaを実行せず、既存の限定operatorのみ評価する。巨大入力・過剰な構造を無制限に評価せず、上限を設けられる設計とし、制限超過をallowへ倒さない。
- Decision（Information / Error Leakage）：外部Agentにはallow / deny / require_approvalを中心とする必要最小限の情報を返す。他PrincipalのDelegation有無、内部Constraint・reason・DB・Debug詳細を不用意に公開しない。Resource / Contextの機密情報をAudit・log・Error / Exception messageへそのまま出力しない。Hostが内部Exceptionを安全な外部Error Responseへ変換し、調査情報は保護されたlog / monitoringで扱う。
- Decision（Audit Tamper / Retention）：通常Public APIはappend-onlyでupdate / deleteを設けない。必要最小限の記録とし、無期限保存を固定仕様にしない。Hostが法令・Privacy / Security Policyに応じRetentionを管理可能とする。Retention / legal deletion / DB保守は通常Audit APIとは別の運用責務。
- Decision（Direct DB / Concurrency / Stale State）：Public APIを迂回するModel / SQL / DB直接更新まで完全防御する保証はせず、Host側の責務とする。通常はPublic API経由を推奨し、可能な範囲で安全なModel制約を持たせる方向とする。同時実行、revoke競合、expiration境界、状態更新で古い状態から権限を拡大させない。十分新しいDelegation状態を使い、cache / replica / stale objectによってrevoked / expired Delegationを再度allowしない。
- Rationale：委任範囲・判定時点・Auditの完全性と機密性を守り、HostとCoreの保証範囲を明確にする。Security requirementと実装手段を分け、過剰設計や未決定APIの先行確定を避けるため。
- Consequences：Threat Model、Trust Boundary、Security Invariant、Host責務、v0.1要件、実装方式との分離、未決定事項の整理を完了条件とし、設計完了とする。Step 1〜8と過去の工程番号を変更せず、Security Model Designは未採番。次は「未決定事項の詰め」だが今回は未着手。Implementation / Testへの反映は後続工程で確認し、Step 8の再設計やGem / Test / Migration実装は行わない。GemはNot implemented / Not released、全体Definition of DoneはProposalを維持する。
- 未決定：Exception class / reason_code正式一覧、Sanitizer Public API・設定方式、Retention期間・削除API、Constraint / Context / JSONの上限・timeout、Clock / Time injection、transaction / locking / isolation / retry、cache / replica方式、Resource identifierのDB型、Delegation validation・delegate!・caller authorization API、TOCTOU transaction API、Decision binding token等。Configuration / Initializer、Generator、対応Ruby / Rails、CI matrix、static analysis、License、Approval Workflow、各Adapterも追加決定しない。D028の既存非提供方針を維持し、全項目は正本第27節を参照。
- 正式本文：[Security Model Design](security_model_v0_1.md)、[Security Model Designの記録](PROJECT.md#55-security-model-design)。
- 根拠：ユーザーが提示したSecurity Model Designの正式決定と、設計ドキュメントのみの更新指示。

- 後続決定（2026-09-17）：D031（Audit Context allowlist・Exception）、D032（Resource identity・Delegation API / validation）、D033（Agent validation）、D034（AuditEvent詳細）で該当する詳細を確定。上記の未決定・候補・追加確定しないという記載は当時の履歴であり、現在の仕様は後続決定と正本に従う。未対象の詳細は引き続き未決定。
- 後続決定（2026-09-17追加）：D035〜D048で該当する保留を解消。上記の未決定表記は当時の履歴。特にD030のサイズ制限・競合・stale state要件はD036・D037・D039・D041・D042のv0.1保証範囲に従う。

- 後続決定（2026-09-17追加）：D049〜D056でcaller境界、主要schema、Model-level immutability / append-only、revoke! concurrency、complexityの保留を解消。

- 後続決定（2026-09-17追加）：D057で必須static analysisをRuboCopと確定。具体的設定・CI組み込み方法は未決定。

## D031: Audit Context allowlist / Exception classes

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。Step 5・Security Model完了後の詳細化。
- Context：D030まで未決定だったAudit Contextの選択APIとException classを、raw Contextを保存しない原則とdeny / Exception境界に沿って確定する。
- Decision（API）：authorizeにoptional `audit_context_keys: []` を追加。唯一のAudit Context選択allowlistとし、省略時・対象なしは `{}`、raw contextへのfallbackは禁止。Array<Symbol>のみ許可し、nil / 単一Symbol / String要素 / 混在はInvalidRequestError。重複Symbolは許可して内部で除去する。
- Decision（Key / Value）：ContextのトップレベルSymbol keyと完全一致し、String / Symbol変換・indifferent access・nested path解釈を行わない。存在しないkeyは無視する。選択valueはString / Integer / Float / BigDecimal / TrueClass / FalseClass / nilのみ。Hash / Array等のunsupported valueが選択された場合はsilent ignoreせずInvalidRequestError。Constraint値の型規則は拡大しない。
- Decision（Secret）：password / password_confirmation / token / access_token / refresh_token / api_key / secret / client_secret / credentialのSymbolをbuilt-in forbidden secret keysとし、指定時点でInvalidRequestError。完全一致のみで、token_countは許可。substring / regex / 推測は導入しない。
- Decision（除外）：v0.1ではcustom Audit Filter / Sanitizer、Proc、callback、sanitizer class、global allowlist config、initializer設定を提供しない。
- Decision（Exception）：ActingFor定義classは `Error < StandardError`、`InvalidRequestError < Error`、`InternalError < Error`、`AuditPersistenceError < InternalError` の4つのみ（すべてActingFor namespace）。Public入力・形式・利用方法の不正はInvalidRequestError。ActingFor自身が検出した内部・system-level errorはInternalError。lower-layer exceptionは原則そのままraiseし、明示決定したものだけwrapする。
- Decision（Audit失敗）：AuditPersistenceErrorはAuditEvent保存失敗専用。lower-level persistence exceptionをwrapしRubyのcauseを保持する。全Decisionについて返却せず、denyへ変換せず、Business Logicへ進ませない。ConstraintError / DelegationError / ConfigurationError等は作らない。
- Rationale：保存項目を呼び出しごとに明示し、秘密情報の誤保存と失敗の黙殺を防ぎ、元の例外原因を追跡できる最小のAPIとするため。
- Consequences：D016のシグネチャ、D019・D023のException詳細、D014・D022・D030のAudit Filter / Sanitizer保留を詳細化する。BigDecimalの最終JSON serialization表現は未決定。実装・Configuration追加は行わない。
- 正式本文：[Public API Arguments](public_api_v0_1.md#4-authorize-arguments)、[Exception](public_api_v0_1.md#7-deny-vs-exception)、[Audit](public_api_v0_1.md#10-audit)、[Security Model](security_model_v0_1.md)。
- 根拠：ユーザーが提示したv0.1設計決定反映指示のAudit Context / Exception正式決定。
- 後続決定（2026-09-17追加）：D044で該当する保留を解消。上記の未決定表記は当時の履歴であり、現在の仕様は後続決定に従う。

## D032: Resource Identity / Delegation API Validation

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。Resource scopeとの適用関係も確認済み。
- Context：Resource識別情報とDelegation作成・取消の入力、成功結果を明確にし、D014・D021の残る詳細を確定する。
- Decision（Resource）：resource_idの保存型はString。Rails / ActiveModel-style Classはmodel_name.nameとnil ID、Instanceはclass.model_name.nameとid.to_s、nilは両方nilへ正規化する。Instanceのid nil / id.to_s空文字、必要interfaceなし、String / Hashの直接識別子はInvalidRequestError。IDのto_sはPublic境界で1回のみ。resource_typeは正規化後の文字列をcase-sensitiveで、specific Resourceのresource_idは正規化後のStringを完全一致で比較する。case normalization / numeric coercion・conversion / 追加implicit coercion / fuzzy matchingは行わない。resource: nilはResource-less Actionであり全Resourceではない。
- Decision（Resource scope・確認済み補足）：既存の型全体Delegationを維持する。Delegationのtype指定・ID nilはその型全体のscopeであり、同じ型の個別IDにもmatchし、別の型にはmatchしない。specific ResourceはtypeとIDの両方を厳密比較する。両方nilのDelegationはResource-less Requestにmatchする。「完全一致」は識別値の比較規則であり、matching全体を単純なtuple完全一致へ変更しない。ユーザーの追加確認により曖昧さを解消した。
- Decision（作成）：Public APIは `ActingFor.delegate(agent:, principal:, action:, resource: nil, constraints: [], effect:, expires_at: nil)` のみ。delegate!は提供しない。effectはrequiredでdefaultなし。成功時はpersist済みDelegationを返す。
- Decision（主体 / Action / Effect）：agentはpersist済みActingFor::Agent、principalはpersist済みActiveRecord model instance。nil / 別class・非ActiveRecord / unsavedはInvalidRequestError。actionはString / SymbolをStringに正規化し、nil / 空文字 / その他typeは不正。authorizeのAction規則も一致させる。effectはString / Symbolのallow / require_approvalだけを正規化し、deny / nil / 未知値 / その他typeを拒否する。
- Decision（Constraint）：constraintsはArrayのみ、省略時[]、明示的nilは不正。各要素はfield / operator / valueだけを必須keyとするHash。非Hash / key不足 / extra keyはInvalidRequestError。Hash keyはString / SymbolをStringに正規化し、正規化後の重複keyは不正。fieldはnon-empty String / Symbol、operatorは既定6種のString / Symbolで、Stringに正規化する。valueはeqがString / Integer / Boolean、比較がInteger、inがString / Integer / BooleanのArray。それ以外はInvalidRequestError、暗黙型変換はしない。nested path非対応を維持し、判定regexや命名規則は追加しない。
- Decision（期限 / 取消）：expires_atはnil / Time / ActiveSupport::TimeWithZoneのみで、指定時はtrusted current timeより未来。同時刻・過去・不正typeはInvalidRequestError、暗黙parseしない。作成APIはrevoked_atを受け付けず必ずnilで開始する。取消はrevoke!のみ、初回のtrusted current timeを記録する。idempotentで、再取消はExceptionにせず最初のtimestampを更新しない。
- Decision（Duplicate）：類似委任の存在を禁止せず、各delegate呼び出しは独立した新規Delegationを作る。dedup / upsert / semantic uniqueness / duplicate detectionは導入しない。
- Rationale：識別と入力の曖昧さを減らし、権限変更はrevoke + createという既存方針を維持するため。
- Consequences：Public作成時の不正入力はInvalidRequestError、Authorization時の不正・評価不能な保存済みConstraintはmatchさせないという既存境界を維持する。caller Authentication / Host AuthorizationはHost責務。Clock injection、transaction / locking / retry等は未決定。Model・Migration実装は行わない。
- 正式本文：[Resource](domain_model_v0_1.md#7-resource)、[Public Resource](public_api_v0_1.md#4-authorize-arguments)、[Delegation API](public_api_v0_1.md#9-delegation-api)。
- 根拠：ユーザーが提示したv0.1設計決定反映指示のResource / Delegation正式決定。
- 後続決定（2026-09-17追加）：D035・D036・D038・D043で該当する保留を解消。上記の未決定表記は当時の履歴であり、現在の仕様は後続決定に従う。

## D033: Agent Validation

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：Agentのローカルidentityと表示名のvalidationを具体化する。Authentication / Resolution / ProvisioningのHost責務は変えない。
- Decision（identifier）：必須のnon-blank String、1..255文字、whitespace characterを一切含まない。nil / 空文字 / whitespace-only / 非String / 長さ超過 / 前後・途中のwhitespaceはvalidation error。implicit conversion / 自動trim / downcaseを行わず、case-sensitive exact identityとする。一意性はActiveRecord validation + DB unique indexの両方で保証する。
- Decision（name）：nilまたはnon-blank String、指定時1..255文字。空文字 / whitespace-only / 非String / 長さ超過はvalidation error。自動trimなし。nameは非一意で同名Agentを許可し、identityの一意性はidentifierだけで保証する。
- Rationale：identityと表示名を区別し、暗黙変換や空白による取り違えを防ぐため。
- Consequences：文字数上限はModel validationの決定。DB column limit / DB-level length constraintを追加決定しない。DB adapter対応範囲・具体実装も未決定。新しいAgent作成・認証APIは追加しない。
- 正式本文：[Agent](domain_model_v0_1.md#3-agent)、[Security Model](security_model_v0_1.md)。
- 根拠：ユーザーが提示したv0.1設計決定反映指示のAgent validation正式決定。
- 後続決定（2026-09-17追加）：D043・D045で該当する保留を解消。上記の未決定表記は当時の履歴であり、現在の仕様は後続決定に従う。

## D034: AuditEvent Decision / Reason / Match Set / Context

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：D014のAudit基本情報を、最終Authorization Decisionの一貫した保存仕様へ詳細化する。
- Decision（reason_code）：最終Decisionの理由を表し、正式一覧はdelegation_allowed / delegation_requires_approval / no_matching_delegationの3つだけ。個別Delegationのexpired / Resource mismatch / Constraint mismatchや、API misuse / InternalError / AuditPersistenceError等のExceptionは責務外。
- Decision（decision / 整合性）：Audit decisionはDB Stringのallow / deny / require_approvalのみ。Public Decision#statusのSymbolは維持する。有効な組はallow ↔ delegation_allowed、require_approval ↔ delegation_requires_approval、deny ↔ no_matching_delegationだけ。両項目はModel validationで必須・許可値・組み合わせを検証し、各columnはNOT NULL。DB CHECK constraintは設けない。
- Decision（matched_delegation_ids）：常にArray、nil不可。denyは[]、allow / require_approvalは実際にmatchしたIDを1件以上保存する。重複IDは不正、順序に意味を持たないmatch集合とする。JSON配列として保存し、JSONBを必須としない。ID自体のDB型や新しい制約は追加しない。
- Decision（sanitized context）：D031のallowlistで選択したContextをJSON objectとして保存する。対象なしは{}でraw contextへfallbackしない。JSONBは必須としない。DB default / NOT NULLは追加決定しない。
- Rationale：最終Decisionの説明と一致した委任集合を正確に追跡し、内部失敗理由や業務実行結果と混同しないため。
- Consequences：D014時点のreason_code候補を正式一覧で置き換える。Audit自動保存、全結果の保存失敗時Exception、append-only、Retentionの別運用責務は維持する。Constraint JSON / JSONBの最終DB型、DB adapter正式対応範囲は未決定。Test設計の再構築・実装は行わない。
- 正式本文：[AuditEvent](domain_model_v0_1.md#14-auditevent)、[Audit Context](public_api_v0_1.md#10-audit)、[Security Model](security_model_v0_1.md)。
- 根拠：ユーザーが提示したv0.1設計決定反映指示のAuditEvent正式決定。
- 後続決定（2026-09-17追加）：D040・D043〜D045で該当する保留を解消。上記の未決定表記は当時の履歴であり、現在の仕様は後続決定に従う。

- 後続決定（2026-09-17追加）：D052でdecision / reason_codeの各許可値DB CHECKを設ける方針へ変更。上記CHECK非設定は当時の履歴であり、現行仕様ではない。pair用CHECKは設けない。ID型・sanitized_context名等もD051・D052で詳細化。

## D035: Clock / Trusted Current Time

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：信頼できる時刻取得の境界を統一する。
- Decision：

時刻取得は内部の共通境界 `ActingFor.current_time` に集約し、通常は `Time.current` を返す。Expiration / Revocation / Authorization等は直接 `Time.current` を呼ばない。v0.1ではClock差し替えPublic API（`ActingFor.clock =` / `ActingFor.reset_clock!`）を提供しない。TestではRails time helper（`travel_to` 等）を使う（D035）。

- Rationale：時刻取得の分散と不要な設定APIを避ける。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[domain_model_v0_1.md](domain_model_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D036: Authorization Transaction / Locking / Isolation

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：authorizeとHost業務処理のtransaction責務を明確にする。
- Decision：

`ActingFor.authorize(...)` 自身は明示的なDB transactionを開始しない。概念上の順序はDelegation lookup → Authorization evaluation → Decision生成 → AuditEvent保存 → Decision return。保存失敗時は `ActingFor::AuditPersistenceError` をraiseし、Decisionを返さない。Host側Business Logicのtransaction管理はHost Applicationの責務。

v0.1のAuthorizationはDelegationへ `SELECT ... FOR UPDATE` 等の明示的なDB lockを取得しない。Decisionは実行時点で観測した状態に基づき、返却後からBusiness Logic実行までDelegationの有効性を保証しない。独自のtransaction isolation levelを要求・変更せず、READ COMMITTED / REPEATABLE READ / SERIALIZABLEを強制しない。Host Application / DB設定に従い、特定isolation levelによるatomicity / TOCTOU防止も保証しない（D036）。

- Rationale：観測時点の判定と業務処理の原子性を混同しない。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[public_api_v0_1.md](public_api_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D037: Decision / TOCTOU Security Contract

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：認可確認と業務処理の間の状態変化を扱う。
- Decision：

**Security Contract（D036・D037・D039）**

- `ActingFor::Decision` はauthorize実行時点の判定結果であり、再利用可能なauthorization token / capability / 権限証明ではない。過去のDecisionを保存・再利用して「認可済み」と扱わない。
- Host Applicationは保護対象Business Logicの実行に可能な限り近い時点でauthorizeする。
- cached Decisionを権限証明として再利用せず、cached Delegationを権限判定・authorization proofに使わない。
- Authorizationに必要なDelegation状態は、最新状態を期待できるauthoritative data sourceから読む。非同期Read Replicaはreplication lagによりstale Delegationを返す可能性があり、その安全性はActingForの保証範囲外。
- ActingForはBusiness Logicとのatomicity、DB locking / isolation levelによるTOCTOU防止を保証しない。v0.1ではDecision binding token / atomic execution APIを提供しない。

- Rationale：Decisionの再利用による誤った権限証明を防ぐ。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[security_model_v0_1.md](security_model_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D038: Retry Strategy

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：失敗時の再実行の責務を整理する。
- Decision：

v0.1ではAuthorization / Delegation作成 / AuditEvent保存を内部で自動retryしない。失敗は既存Exception方針で呼び出し元へ伝える。Hostがretryする場合、古いDecisionを再利用せず、必要に応じauthorizeから再評価する。delegateは呼ぶたび新規Delegationを作るため、内部自動retryによるduplicate Delegation作成を避ける（D038）。

- Rationale：古い判定の再利用と内部retryによる重複作成を避ける。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[public_api_v0_1.md](public_api_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D039: Cache / Authoritative Data Source / Read Replica

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：stale Delegationを使う危険と読取元の責務を明確にする。
- Decision：

ActingFor v0.1はAuthorization DecisionとDelegation lookup結果を内部cacheせず、Authorizationごとに現在の永続化状態を参照する。Host独自cacheの安全性は保証範囲外。Read Replica routing機能は提供しない（D039）。

cached Decisionを権限証明として再利用せず、cached Delegationを権限判定・authorization proofに使わない。Authorizationに必要なDelegation状態は、最新状態を期待できるauthoritative data sourceから読む。非同期Read Replicaでは、authoritative DBでrevoke済みでもreplication lagにより旧Delegationを読みallowとなる可能性があり、そのstale readの安全性はActingForでは保証しない。Decisionの時点とTOCTOU境界はD037に従う。

- Rationale：cache / replication lagによる古い権限状態を安全と誤認しない。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[security_model_v0_1.md](security_model_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D040: AuditEvent Retention / Delete API

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：通常Auditと保持・削除運用を区別する。
- Decision：

AuditEventは通常運用でappend-onlyとし、v0.1では削除用Public APIを提供しない。固定retention period、自動削除、自動アーカイブは設けない。保持期間・削除・アーカイブはHost Applicationの運用責務で、サービスのセキュリティ要件・法令・社内規程等に応じて決定する（D040）。

- Rationale：サービスごとの要件をHostで扱う。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[security_model_v0_1.md](security_model_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D041: Context Size / Constraint Count

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：未決定だった入力・監査サイズと条件数の扱いを確定する。
- Decision：

v0.1ではAuthorization context全体とsanitized Audit Contextに固定byte上限をPublic仕様として設けず、1 DelegationあたりのConstraint件数にも固定上限を設けない。HostはAuthorizationに必要な最小限のContextだけを渡し、汎用データ搬送手段として使わないことを推奨する。Auditは `audit_context_keys:` で明示的に選択した必要最小限の値だけを保存し、Constraintも認可に必要な最小限の条件へ保つ（D041）。

- Rationale：固定上限を設けず、必要最小限の入力を推奨する。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[public_api_v0_1.md](public_api_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D042: Authorization Timeout / Network Boundary

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：Authorizationと実行環境のtimeout責務を区別する。
- Decision：

v0.1はAuthorization専用timeout設定・timeout APIを提供しない。DB / request / job等のtimeoutはHost Application / 実行環境の責務。ActingFor CoreのAuthorization処理に外部ネットワーク呼び出しを持ち込まない（D042）。

- Rationale：Coreへ専用timeout機構や外部通信を持ち込まない。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[security_model_v0_1.md](security_model_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D043: Agent / Delegation / AuditEvent DB Schema

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：D033・D034等で保留していたDB型・default・NULL制約を確定する。
- Decision：

| 対象 | DB type | default | NULL / 補足 |
| --- | --- | --- | --- |
| Agent#identifier / Agent#name | `string` | 今回追加決定なし | Model validationは指定時1..255文字。identifierのDB unique indexを維持し、DB-level length CHECK constraintは追加しない |
| Delegation#principal_id | `string` | 今回追加決定なし | persist済みPrincipalのIDを文字列として扱う |
| Delegation#constraints | `json` | `[]` | `null: false` |
| AuditEventのsanitized context | `json` | `{}` | `null: false`。全体としてnilを保存しない |
| AuditEvent#matched_delegation_ids | `json` | `[]` | `null: false`。denyは[]、allow / require_approvalは1件以上 |

PostgreSQL固有の `jsonb` は必須としない。Constraint評価はRuby側で行い、JSON内部をDB queryすることをv0.1 Public契約にしない。Principal IDはbigint `123` → `"123"`、UUID → `"550e8400-e29b-41d4-a716-446655440000"` のように扱い、特定主キー型へ固定しない。異なるPrincipal ID型とのassociation / Authorization動作はIntegration Testで確認する設計とする（D043）。

- Rationale：Principal主キー型への固定を避け、空のJSON表現を一貫させる。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[domain_model_v0_1.md](domain_model_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

- 後続決定（2026-09-17追加）：D051・D052で主要schemaの残る型・NULL・CHECK・index・主キーを詳細化。json / default方針は維持。

## D044: BigDecimal Audit Serialization

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：D031で保留していた監査JSON表現を確定する。
- Decision：

sanitized Audit ContextのBigDecimalはFloatへ変換せず、精度を失わない10進数StringとしてJSONへ保存する。例：`BigDecimal("12345.67")` → JSON `"12345.67"`。その他の既決定scalar型の仕様は変更しない（D044）。

- Rationale：監査ログの数値精度を維持する。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[public_api_v0_1.md](public_api_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D045: Supported DB Adapter

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：v0.1のDB動作保証対象を明確にする。
- Decision：

v0.1の正式対応DB adapterは **PostgreSQLのみ**。他adapterを意図的に排除する設計にはしないが、正式サポート・動作保証対象外とする。CI / Integration Testで検証したDBだけを正式サポートとする（D045）。

- Rationale：検証したDBのみを正式サポートする。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[test_strategy_v0_1.md](test_strategy_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D046: Ruby / Rails Support / CI Matrix

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：対応系列と検証対象を確定する。
- Decision：

正式サポート対象は **Ruby 3.4 / 4.0、Rails 8.0 / 8.1**。Ruby 3.3以下、Rails 7.2以下は対象外。正式CI matrixは以下の4組で、DBはいずれもPostgreSQL。正式サポートはこのmatrixで実際に検証した組み合わせのみ（D046）。

| Ruby | Rails | DB |
| --- | --- | --- |
| 3.4 | 8.0 | PostgreSQL |
| 3.4 | 8.1 | PostgreSQL |
| 4.0 | 8.0 | PostgreSQL |
| 4.0 | 8.1 | PostgreSQL |

Rails 8.0のSecurity Support終了時期が近いため、v0.1リリース直前にRails公式support statusを再確認する。Ruby公式support statusもリリース直前に再確認する。これは設計上の対象であり、現在検証済み・リリース済みという意味ではない。CIはまだ実装しない。

- Rationale：正式サポートを実際のCI検証と対応させる。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[test_strategy_v0_1.md](test_strategy_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D047: Gem Version Constraints

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：将来のdependency制約を記録する。
- Decision：

将来gemspecへ設定するv0.1のversion constraintはRuby `>= 3.4`, `< 4.1`、Rails `>= 8.0`, `< 8.2` とする。dependencyとしてinstall可能であることと正式サポートは区別し、正式サポートはD046のCI matrixで検証済みの組み合わせだけとする。今回はgemspecを作成・変更しない（D047）。

- Rationale：install可能範囲と動作保証範囲を区別する。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[gem_structure_v0_1.md](gem_structure_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D048: MIT License

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context：公開ライセンスを確定する。
- Decision：

ActingForは **MIT License** で公開する。将来LICENSE / gemspecへMITを明記するが、今回はLICENSEファイルを作成せず、gemspecも作成・変更しない（D048）。

- Rationale：ユーザーの正式決定であるMITを公開方針に反映する。
- Consequences：既存Decisionの履歴と未対象の未決定事項を維持する。今回の変更は設計文書のみで、実装は開始しない。
- 正式本文：[gem_structure_v0_1.md](gem_structure_v0_1.md)。
- 根拠：ユーザーが提示した2026-09-17追加正式決定。

## D049: Delegation Caller Authorization Boundary

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D021・D030・D032のHost責務を確定し、caller authorization具体APIの保留を解消する。
- Decision：ActingFor v0.1はDelegation作成・取消callerのAuthentication / Authorizationを提供しない。Host Applicationが事前に認証・認可してから `ActingFor.delegate(...)` / `delegation.revoke!` を呼ぶ。caller authorization用の `actor:` / `current_user:` 等のPublic APIは追加しない（D049）。
- Rationale：Hostの認証・認可とDelegation操作の責務を分離する。
- Consequences：設計文書だけを更新し、Gem / Model / Service / Migration / Test / CI / LICENSE / gemspecを実装しない。今回明示されない具体コード・task名・後続機能は確定しない。
- 正式本文：[詳細設計](public_api_v0_1.md#9-delegation-api)。
- 根拠：ユーザー承認済みの2026-09-17追加正式決定。

## D050: Decision Public API Final Boundary

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D017・D018・D028の4 APIを維持し、追加属性・constructorのPublic境界の保留を解消する。AuditEventのreason_code等は維持する。
- Decision：v0.1のDecision Public APIは `status` / `allowed?` / `denied?` / `approval_required?` の4つだけとする。`reason_code` / `matched_delegation_ids` / `context` 等の追加属性はPublic APIとして提供せず、`ActingFor::Decision.new(...)` のconstructorもPublic APIとして保証しない。Decisionは `ActingFor.authorize(...)` の戻り値として取得する（D050）。
- Rationale：判定結果のPublic契約を最小限に保つ。
- Consequences：設計文書だけを更新し、Gem / Model / Service / Migration / Test / CI / LICENSE / gemspecを実装しない。今回明示されない具体コード・task名・後続機能は確定しない。
- 正式本文：[詳細設計](public_api_v0_1.md#6-decision-public-api)。
- 根拠：ユーザー承認済みの2026-09-17追加正式決定。

## D051: Agent / Delegation DB Schema

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D032・D033・D043の型・JSON方針を維持し、主要schemaの保留を解消する。通常の無効化はrevoke!とする。
- Decision：Agent / DelegationはRails標準bigint主キー、UUID切替機構なし。Agentはidentifier string NOT NULL + unique index、name string NULL、両timestamps datetime NOT NULL。長さは既存Model validationのみでDB length CHECKなし。Delegationはagent_id bigint NOT NULL + Agent FK + 単独index、cascade deleteなしで参照中Agent削除を拒否。principal_type / principal_id / actionはstring NOT NULL、resource_type / resource_idはstring NULL、effectはstring NOT NULL、constraintsはjson NOT NULL DEFAULT []、expires_at / revoked_atはdatetime NULL・defaultなし、両timestampsはdatetime NOT NULL。Host Principal / Resource FKなし。ResourceのNULL type + 非NULL IDはModel + DB CHECKで禁止、effectのallow / require_approvalはModel + DB CHECKのみでRails / PostgreSQL enumなし。Action一覧をDB固定せず、constraintsのJSON内部CHECKなし。expires_at / revoked_atにCHECK・単独indexなし。Authorization lookup複合indexは(agent_id, principal_type, principal_id, action, resource_type)でresource_id / expires_at / revoked_atを含めない。追加indexは利用状況・実測から後続検討する。意味・validation・全column表は正本第17節に記録する。
- Rationale：必要な整合性をDBでも保証し、既存のResource scopeと小さいschemaを維持する。
- Consequences：設計文書だけを更新し、Gem / Model / Service / Migration / Test / CI / LICENSE / gemspecを実装しない。今回明示されない具体コード・task名・後続機能は確定しない。
- 正式本文：[詳細設計](domain_model_v0_1.md#17-v01-テーブル構成)。
- 根拠：ユーザー承認済みの2026-09-17追加正式決定。

## D052: AuditEvent DB Schema / Snapshots

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D034のdecision / reason_codeの許可値DB CHECK非設定を変更する。旧記録は履歴として保持する。D031・D043のAudit選択・json / default方針は維持する。
- Decision：AuditEventはRails標準bigint主キー、UUID切替機構なし。agent_id bigint NOT NULL / agent_identifier string NOT NULL、principal_type / principal_id / action string NOT NULLをAuthorization時点のsnapshotとして保存し、Foreign Keyは設けない。resource_type / resource_idはstring NULLでDelegationと同じsemanticsとNULL type + 非NULL ID禁止CHECKを持つ。action一覧をDB固定しない。decision / reason_codeはstring NOT NULLで各正式3値をModel validation + DB CHECKで限定し、Rails / PostgreSQL enumは使わない。allow ↔ delegation_allowed、require_approval ↔ delegation_requires_approval、deny ↔ no_matching_delegationの組み合わせはModel validationのみで、pair用DB CHECKなし。matched_delegation_idsはjson NOT NULL DEFAULT []、内部IDはJSON number / Integer、String化しない。Array・Integerのみ・重複なし・順序に意味なし・denyは[]・他2結果は1件以上をModel / Authorization内部で保証し、JSON内部用DB CHECKなし。sanitized_contextを正式column名としjson NOT NULL DEFAULT {}、allowlistとbuilt-in validationを通った値だけを保存する。raw context column・fallbackなし。created_at datetime NOT NULLのみ、更新しないappend-only recordのためupdated_atなし。PK以外の検索indexは追加決定せず、検索API・管理画面・分析要件と利用状況から後続検討する。
- Rationale：Audit snapshotをrecord lifecycleから分離し、固定値の整合性をDBでも保証する。
- Consequences：設計文書だけを更新し、Gem / Model / Service / Migration / Test / CI / LICENSE / gemspecを実装しない。今回明示されない具体コード・task名・後続機能は確定しない。
- 正式本文：[詳細設計](domain_model_v0_1.md#17-v01-テーブル構成)。
- 根拠：ユーザー承認済みの2026-09-17追加正式決定。

## D053: Delegation Model-level Immutability

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D014・D021・D030のimmutable方針をexpires_atとModelレベルの誤更新防止まで詳細化する。
- Decision：persist済みDelegationの `agent` / `principal` / `action` / `resource_type` / `resource_id` / `constraints` / `effect` / `expires_at` はModelレベルでも変更禁止とし、validation等で誤更新を防ぐ。期限延長・短縮も旧Delegationのrevoke + 新Delegationのcreateで表す。通常lifecycleで変更可能な状態属性は `revoked_at` のみ（通常のRails timestamp更新は別）。v0.1ではDB triggerによるimmutability強制は行わず、具体的なcallback・validationのRuby実装は未決定（D053）。
- Rationale：期限を含む過去の権限内容の意味を保つ。
- Consequences：設計文書だけを更新し、Gem / Model / Service / Migration / Test / CI / LICENSE / gemspecを実装しない。今回明示されない具体コード・task名・後続機能は確定しない。
- 正式本文：[詳細設計](domain_model_v0_1.md#10-expiration--revocation)。
- 根拠：ユーザー承認済みの2026-09-17追加正式決定。

## D054: Concurrent Idempotent Revocation

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D032のidempotencyを並行実行にも明示し、D035の時刻境界を維持する。D036のAuthorization locking / TOCTOU境界は変更しない。
- Decision：`Delegation#revoke!` は並行実行時にもidempotentとする。対象IDと `revoked_at IS NULL` を条件とするatomic updateを用い、最初に永続化されたrevoked_atを保持する。後続呼び出しはtimestampを書き換えず、既にrevokedでもExceptionにしない。explicit row lockは使わない。revoked_atが変更された場合は通常のRails timestampとしてupdated_atも更新する。時刻は `ActingFor.current_time` を使う。具体的なActiveRecord / Ruby / SQL実装は未決定（D054）。
- Rationale：並行取消でも最初の取消時刻を保持する。
- Consequences：設計文書だけを更新し、Gem / Model / Service / Migration / Test / CI / LICENSE / gemspecを実装しない。今回明示されない具体コード・task名・後続機能は確定しない。
- 正式本文：[詳細設計](public_api_v0_1.md#9-delegation-api)。
- 根拠：ユーザー承認済みの2026-09-17追加正式決定。

## D055: Constraint Complexity Boundary

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D014の小さいConstraint language、D041・D042の上限・timeout方針を維持し、complexityの保留を解消する。
- Decision：v0.1ではConstraint complexity score、深さ制限、動的complexity判定、complexity engineを提供しない。固定Constraint件数上限・固定byte上限・Authorization専用timeoutを設けない既存方針を維持する。eq / lt / lte / gt / gte / in、nested pathなし、任意Ruby codeなし、複数ConstraintはANDという小さい言語で複雑性を抑え、Hostには必要最小限のConstraint利用を推奨する（D055）。
- Rationale：専用complexity機構を増やさず、表現可能な条件を小さく保つ。
- Consequences：設計文書だけを更新し、Gem / Model / Service / Migration / Test / CI / LICENSE / gemspecを実装しない。今回明示されない具体コード・task名・後続機能は確定しない。
- 正式本文：[詳細設計](domain_model_v0_1.md#8-constraint)。
- 根拠：ユーザー承認済みの2026-09-17追加正式決定。

## D056: AuditEvent Model-level Append-only

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D014・D030のappend-onlyをModelレベルでも強制する方針に詳細化する。D040のHost retention責務と削除Public API非提供は維持する。
- Decision：persist済みAuditEventのupdate / destroyをModelレベルでも禁止する。新しいAudit情報は常に新規INSERTで記録する。v0.1ではDB trigger、WORM storage、cryptographic signingによるDB / storage-level強制は行わない。Host側retention責務は変更しない。具体的なModel実装は未決定（D056）。
- Rationale：Authorization履歴の通常操作での書き換え・削除を防ぐ。
- Consequences：設計文書だけを更新し、Gem / Model / Service / Migration / Test / CI / LICENSE / gemspecを実装しない。今回明示されない具体コード・task名・後続機能は確定しない。
- 正式本文：[詳細設計](domain_model_v0_1.md#15-auditeventの方針)。
- 根拠：ユーザー承認済みの2026-09-17追加正式決定。

## D057: v0.1 Static Analysis

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D029・D030とPROJECTのstatic analysis選定の保留を解消する。
- Decision：v0.1の必須static analysisは **RuboCop** とする。Sorbet、Steep、Brakeman、独自security scannerはv0.1必須要件に含めない。RuboCopのversion、具体的configuration、rule set、plugin、CIへの具体的組み込み方法、rake taskの具体名は未決定とし、実装工程で決める。
- Rationale：必須の静的検査を明確にし、v0.1の必須要件を限定する。
- 未決定：RuboCop version / config / rule set / plugin、CI組み込み方法、rake task名。Gem実装詳細は今回決めない。
- Consequences：設計文書のみ更新する。Gem / Test / CI / Migration実装、RuboCop設定ファイル、README Runnable Quick Startコード、Release Notes本文は作成しない。Definition of Done全体を追加承認するものではない。
- 正式本文：[PROJECTの必須成果物](PROJECT.md#43-v01全体のdefinition-of-done)。
- 根拠：ユーザー承認済みの追加正式決定。

- 後続決定（2026-09-18）：RuboCop violationによるCI failureはD067、CI基盤とtriggerはD072・D073で確定。具体設定は未決定を維持する。

## D058: Runnable Quick Start

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D027のDesign-stage Quick Start完了は維持し、D029とPROJECTで保留していたRunnable Quick Startの必須成果物・対象範囲を確定する。
- Decision：v0.1ではREADMEの **実行可能な最小Quick Start** を必須成果物とする。対象はGem導入、Migration適用、Agent作成、Delegation作成、`ActingFor.authorize(...)`、`ActingFor::Decision` の結果確認。Approval Workflow、MCP、OAuth / OIDC、Agent Authentication実装、UI、独立したサンプルRailsアプリは含めない。独立したサンプルアプリの提供はv0.1必須要件としない。
- Rationale：最小の導入から判定結果確認までの利用経路を実行可能な形で示すため。
- 未決定：README Quick Startの具体的コマンド、Migration実コード・task名。Gem実装詳細は今回決めない。
- Consequences：設計文書のみ更新する。Gem / Test / CI / Migration実装、RuboCop設定ファイル、README Runnable Quick Startコード、Release Notes本文は作成しない。Definition of Done全体を追加承認するものではない。
- 正式本文：[PROJECTの必須成果物](PROJECT.md#43-v01全体のdefinition-of-done)。
- 根拠：ユーザー承認済みの追加正式決定。

- 後続決定（2026-09-18）：実行可能性・Rails console用途・Public API境界・Shopping Agent例はD068〜D071で確定。

## D059: v0.1 Release Notes

- 日付：2026-09-17
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D029とPROJECTのRelease Notes要件の保留を解消する。
- Decision：v0.1公開時には **Release Notes** を必須とする。最低限、v0.1の主要機能、対応Ruby / Rails / DB、Public API、v0.1対象外機能、既知の制約、0.xであり破壊的変更の可能性があることを記載する。自動CHANGELOG生成、詳細な変更履歴生成基盤、Release Notes自動生成システムはv0.1必須要件としない。
- Rationale：公開時の提供範囲・対応環境・制約・互換性の注意を利用者へ伝えるため。
- 未決定：Release Notesのファイル名・配置方法、CHANGELOG方式。Gem実装詳細は今回決めない。
- Consequences：設計文書のみ更新する。Gem / Test / CI / Migration実装、RuboCop設定ファイル、README Runnable Quick Startコード、Release Notes本文は作成しない。Definition of Done全体を追加承認するものではない。
- 正式本文：[PROJECTの必須成果物](PROJECT.md#43-v01全体のdefinition-of-done)。
- 根拠：ユーザー承認済みの追加正式決定。

- 後続決定（2026-09-18）：公開先はD074でGitHub Releasesに確定。version / tagはD075、全体DoDはD076で確定。本文・CHANGELOG方式は未決定を維持する。

## D060: Migration Provisioning

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D028のRails Engine標準方式を具体化する。
- Decision：MigrationはGem側の `db/migrate/` で管理し、Rails Engine標準のMigration提供機構でHost Applicationの `db/migrate/` へ取り込む。DBへの適用はHost Applicationの通常のMigrationプロセスに委ねる。独自Migration DSL、独自Migration Generator、自動Migration実行機構は提供しない。
- Rationale：Rails標準の導入手順とHostのDB管理責務を維持する。
- 未決定：具体的なRails task名・Migration Rubyコード。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[Gem Structure](gem_structure_v0_1.md#6-migration--db-table-names)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D061: Migration Evolution Policy

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：リリース済みMigrationの変更方針を明確にする。
- Decision：一度リリースしたMigrationは原則変更せず、DB schema変更には新しいMigrationを追加する。Host ApplicationはGem更新時に追加Migrationを取り込み、通常のMigrationプロセスで適用する。独自schema versioning機構はv0.1では作らない。
- Rationale：既存installationの履歴を保ち、追加Migrationで更新する。
- 未決定：Migration実コード・具体的task名。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[Gem Structure](gem_structure_v0_1.md#6-migration--db-table-names)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D062: Migration Retention Policy

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：新規installationと旧versionからのupgradeに同じ履歴を提供する。
- Decision：一度リリースしたMigrationファイルは原則Gemから削除しない。新規installation、旧versionからのupgrade、Migration履歴保持を目的とする。過去Migrationのsquash・統合・削除はv0.1では行わない。
- Rationale：導入・更新に必要なMigration履歴を保持する。
- 未決定：具体的Migrationファイルの最終形。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[Gem Structure](gem_structure_v0_1.md#6-migration--db-table-names)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D063: Migration Runtime Boundary

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：Migration管理とRuntimeの責務を分離する。
- Decision：v0.1のRuntimeでは独自Migration適用状況チェック、独自schema version管理、起動時Migration、自動Migration実行を行わない。Migration管理・適用確認はHost Application / Rails / ActiveRecordの標準機構に委ねる。
- Rationale：標準の管理機構へ責務を集約する。
- 未決定：具体的なMigration task名・実コード。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[Gem Structure](gem_structure_v0_1.md#6-migration--db-table-names)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D064: Explicit Migration Installation

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D060の取り込み操作の実行主体を明確にする。
- Decision：Host開発者がRails Engine標準のMigration提供機構を明示的に実行してHost Applicationへ取り込む。Gem install、Gem update、Application bootを契機として自動コピーしない。
- Rationale：Host開発者がDB変更の導入を管理できるようにする。
- 未決定：具体的task名は実装工程で確認・決定する。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[Gem Structure](gem_structure_v0_1.md#6-migration--db-table-names)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D065: Initial Migration Granularity

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D028の初期schema構成を正式な分割方針として確定する。
- Decision：初期schemaはAgent / Delegation / AuditEventの3つのMigrationへ分割し、1つの巨大な初期Migrationにまとめない。概念上の名称は `create_acting_for_agents` / `create_acting_for_delegations` / `create_acting_for_audit_events` とする。
- Rationale：3 Modelに対応するMigrationの単位を明確にする。
- 未決定：具体的timestamp・filenameの最終形・Migration Rubyコード。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[Gem Structure](gem_structure_v0_1.md#6-migration--db-table-names)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D066: Migration Reversibility Policy

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：Rails標準のreversibilityと保証範囲を区別する。
- Decision：Rails標準機構で安全にreversibleにできるMigrationはreversibleに設計する。独自rollback機構は提供しない。将来、不可逆Migrationが必要になった場合はその時点で別Decisionとして判断する。v0.1で将来の全Migrationのrollback可能性までは保証しない。
- Rationale：安全に利用できる標準機構を使い、将来の保証を広げない。
- 未決定：不可逆Migrationが必要になった場合の扱い・具体的実コード。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[Gem Structure](gem_structure_v0_1.md#6-migration--db-table-names)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D067: RuboCop Enforcement Boundary

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D057の必須static analysisの合否境界を確定する。
- Decision：v0.1ではRuboCopを必須static analysisとして実行し、violationがあればCI failureとする。独自Style Guide、大量の独自Cop、大規模なcustom rule set、複数plugin群はv0.1必須ではない。
- Rationale：必須検査の失敗条件を明確にする。
- 未決定：RuboCop version・具体的config・具体的rule set・plugin採否。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[Test Strategy](test_strategy_v0_1.md)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D068: Runnable Quick Start Executability

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D058の必須成果物について実行可能性を明確にする。
- Decision：対応する新規Rails Applicationで、READMEの手順を上から順番に実行し、Gem導入 → Migration取り込み → Migration実行 → Agent作成 → Delegation作成 → `ActingFor.authorize(...)` → Decision確認まで到達できる手順とする。未実装APIや疑似コードを実行可能なコードとして掲載しない。具体的な実コード化はGem実装後に行う。
- Rationale：最小の導入・動作確認を再現可能にする。
- 未決定：Quick Startの最終コード・具体的コマンド。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[README](../README.md#quick-start)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D069: Runnable Quick Start Execution Context

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：Quick Startと本番の管理方法を区別する。
- Decision：README Quick Startの最小動作確認にはRails consoleを使う。これはQuick Start / 開発者による動作確認用であり、本番のAgent / Delegation管理方法をRails consoleと規定しない。本番の作成・管理フローはHost Applicationの責務とする。Quick StartだけのためのController、Route、View、UI、専用管理画面は必須としない。
- Rationale：最小確認のためにUIを要求せず、Hostの本番管理責務を維持する。
- 未決定：Quick Startの最終コード。本番管理フローはHost側で定める。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[README](../README.md#quick-start)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D070: Quick Start Public API Boundary

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D058の導入説明のためにAPIを増やさない境界を定める。
- Decision：Runnable Quick Startは正式にサポートするPublic APIとRails標準操作のみで構成する。簡単に見せる目的だけで `ActingFor.create_agent(...)`、`ActingFor.setup(...)`、`ActingFor.quick_start(...)` 等の新しいPublic API / helper / setup APIを追加しない。
- Rationale：説明用の便宜でPublic APIの保証範囲を広げない。
- 未決定：Quick Startの最終コード・具体的コマンド。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[README](../README.md#quick-start)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D071: Quick Start Example Domain

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D027の既存Shopping Agent例とRunnable版の題材を揃える。
- Decision：v0.1 Runnable Quick Startは既存READMEのShopping Agent例に統一する。Principal = User、Agent = Shopping Agent、Action = purchase、Resource = Product、Context = amountとする。これはREADMEの説明用サンプルであり、必須domain・必須Host Model・必須business logicを規定しない。
- Rationale：説明の一貫性を保ち、利用domainを限定しない。
- 未決定：サンプルの最終コード。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[README](../README.md#quick-start)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D072: v0.1 CI Platform

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D046の正式matrixとD057の必須検査を実行する基盤を確定する。
- Decision：正式CI基盤はGitHub Actionsとする。少なくとも正式Ruby / Rails matrix、PostgreSQL、必須Test、RuboCopをCI上で検証する。
- Rationale：正式対応環境と必須検査を同じCI方針で扱う。
- 未決定：workflow YAML・job分割・cache・具体的command・service設定。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[Test Strategy](test_strategy_v0_1.md)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D073: CI Trigger Policy

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D072のCI実行契機を確定する。
- Decision：Pull Requestとmain branchへのpushを契機にCIを実行する。scheduled / cron CIはv0.1必須要件としない。
- Rationale：変更提案とmainへの反映を検証する。
- 未決定：具体的GitHub Actions YAML。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[Test Strategy](test_strategy_v0_1.md)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D074: Release Notes Publication

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：D059で保留していた正式な公開先を確定する。
- Decision：正式Release NotesはGitHub Releasesで公開し、各Releaseを対応するversion tagと紐付ける。RELEASE_NOTES.md、CHANGELOG、自動CHANGELOG生成はv0.1必須成果物としない。Release Notes本文はrelease準備時に作成する。
- Rationale：公開versionと説明を対応付ける。
- 未決定：Release Notes本文・CHANGELOG方式。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[PROJECT](PROJECT.md#43-v01全体のdefinition-of-done)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D075: Versioning and Tagging Policy

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：最初の公開versionとtagの対応を確定する。
- Decision：Semantic Versioningを基本とし、最初の公開versionは `0.1.0`、Git tagは `v0.1.0` とする。0.x期間中はPublic APIを含む破壊的変更の可能性をRelease Notesで明示する。
- Rationale：versionと互換性の注意を明確にする。
- 未決定：自動release・自動tag作成・release automation（gem push automation・GitHub Release自動作成を含む）。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[PROJECT](PROJECT.md#43-v01全体のdefinition-of-done)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D076: v0.1 Definition of Done

- 日付：2026-09-18
- Status：**確定（設計のみ・未実装）**。
- Context / 既存決定との関係：PROJECTでProposalだった全体DoDを承認済みの範囲で正式決定へ更新する。
- Decision：ActingFor `0.1.0` は少なくとも、v0.1確定機能の実装完了、必須自動Test成功、正式Ruby / Rails / PostgreSQL CI matrix成功、RuboCop成功、対応環境でRunnable Quick Startの実行可能性確認、READMEと実装の一致、Security Boundaryと実装の一致、Responsibility Boundaryと実装の一致、GitHub Release Notesを公開できる状態を満たした時点で完成とする。v0.1対象外機能は含めない。従来Proposalは本Decisionに整合する範囲を正式決定へ更新し、より広い未承認条件は昇格させない。
- Rationale：完成判定を確定済みスコープと必須成果物に対応付ける。
- 未決定：従来ProposalのうちD076より広い未承認条件、各成果物の未決定の実装詳細。
- Consequences：設計文書のみ更新する。具体的な実装・設定・Runnableコード・Release Notes本文は作成せず、tag作成・releaseも行わない。GemはNot implemented / Not releasedを維持する。
- 関連文書：[PROJECT](PROJECT.md#43-v01全体のdefinition-of-done)、[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD060〜D076設計ドキュメント反映指示。

## D077: First Implementation Unit

- 日付：2026-09-18
- Status：**確定**。
- Decision：Implementation Phaseの最初の実装単位はGem skeletonとする。
- Rationale：最初の実装範囲を最小単位に限定する。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：Core featureの実装には入らない。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D078: Gem Skeleton Scope

- 日付：2026-09-18
- Status：**確定**。
- Decision：第1実装範囲は `acting_for.gemspec`、`Gemfile`、`Rakefile`、`LICENSE`、`lib/acting_for.rb`、`lib/acting_for/version.rb`、`lib/acting_for/engine.rb` とする。Decision、Model、Migration、Authorization、ConstraintEvaluator、Audit、test/dummy、CIはまだ実装しない。
- Rationale：実装対象と対象外を明確にする。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：必要なdirectoryのみ作成し、Testコード・Runnable Quick Startも追加しない。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D079: Gem Skeleton Completion Criteria

- 日付：2026-09-18
- Status：**確定**。
- Decision：`bundle install` と `require "acting_for"` が成功し、`ActingFor::VERSION` が参照でき、値が `"0.1.0"` であり、Rails環境で `ActingFor::Engine` が正常にロードできることを完了条件とする。
- Rationale：依存関係と最小ロード経路の成立を確認する。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：Gem skeletonの完了とv0.1全体の完成を区別する。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D080: Gemspec Dependencies

- 日付：2026-09-18
- Status：**確定**。
- Decision：Rubyは `>= 3.4, < 4.1`、activerecord / activesupport / railtiesはそれぞれ `>= 8.0, < 8.2` とする。rails meta-gemには依存しない。LicenseはMIT、versionは `ActingFor::VERSION` を参照する。
- Rationale：対応範囲と必要なRuntime依存関係を明示する。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：Gemfileへ依存関係を重複定義しない。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D081: Minimal Entry Point

- 日付：2026-09-18
- Status：**確定**。
- Decision：`lib/acting_for.rb` は `require "acting_for/version"`、`require "acting_for/engine"` と空の `module ActingFor` による最小Entry Pointとする。authorize、delegate、current_time、Configuration、Error classes、Business Logicは追加しない。
- Rationale：入口へ未実装のAPIや業務ロジックを持ち込まない。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：Public APIの追加実装は後続工程とする。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D082: Minimal Engine

- 日付：2026-09-18
- Status：**確定**。
- Decision：`ActingFor::Engine < ::Rails::Engine` とし、クラス内は `isolate_namespace ActingFor` のみとする。initializer、routes、独自autoload設定、Migration hook、独自Railtie、その他Engine設定は追加しない。
- Rationale：Rails Engineとnamespace分離の最小構造を維持する。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：追加Engine設定を今回の範囲に含めない。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D083: Version Constant

- 日付：2026-09-18
- Status：**確定**。
- Decision：`module ActingFor` 内に `VERSION = "0.1.0"` を定義する。Version専用classや追加APIは作らない。
- Rationale：versionを単一の定数で管理する。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：gemspecから同じ定数を参照する。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D084: Minimal Gemfile

- 日付：2026-09-18
- Status：**確定**。
- Decision：Gemfileは `source "https://rubygems.org"` と `gemspec` のみとする。Rails依存関係やTest用Gemを重複・追加定義しない。
- Rationale：依存関係をgemspecへ集約する。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：今回追加Gemを導入しない。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D085: Minimal Rakefile

- 日付：2026-09-18
- Status：**確定**。
- Decision：Rakefileは `require "bundler/gem_tasks"` のみとする。test task、rubocop task、release用独自task、migration task、独自namespaceは追加しない。
- Rationale：標準Gem taskのみを利用する。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：独自task・Release automationは実装しない。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D086: Minimal Gemspec Metadata

- 日付：2026-09-18
- Status：**確定**。
- Decision：gemspecはRubyGems公開に必要な最小metadataと依存関係のみを持つ。summaryは `Rails-native delegated authorization for AI agents.` とする。詳細な製品説明・設計情報はREADME.mdとdocs/を正本とする。
- Rationale：製品説明・設計情報の重複を避ける。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：未承認のmetadataを追加しない。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D087: Gem Package Files

- 日付：2026-09-18
- Status：**確定**。
- Decision：Gem package対象は `lib/**/*`、`app/**/*`、`db/**/*`、`README.md`、`LICENSE*` とする。test/、docs/を含めず、ファイル一覧取得に `git ls-files` を使わない。
- Rationale：配布対象を限定し、ファイル一覧取得をGit commandに依存させない。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：対象patternに該当するファイルを収録する。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D088: License File

- 日付：2026-09-18
- Status：**確定**。
- Decision：Gem skeleton実装時に標準MIT License本文のLICENSEを作成する。独自条項は追加しない。
- Rationale：配布物にLicense本文を含める。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：gemspecのMIT表記と一致させる。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D089: License Copyright

- 日付：2026-09-18
- Status：**確定**。
- Decision：LICENSEのCopyrightは `Copyright (c) 2026 ChangQuan Cui` とする。
- Rationale：承認済みの著作権表記を明示する。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：LICENSEへ指定表記を記載する。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D090: Gemspec Author

- 日付：2026-09-18
- Status：**確定**。
- Decision：`spec.authors = ["ChangQuan Cui"]` とする。v0.1ではemail metadataを設定しない。
- Rationale：承認済みの著者情報のみを公開metadataに持たせる。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：emailを追加しない。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D091: Gemspec URLs

- 日付：2026-09-18
- Status：**確定**。
- Decision：`spec.homepage = "https://github.com/cuichangquan/acting_for"` とし、metadataは `"source_code_uri" => "https://github.com/cuichangquan/acting_for"` のみとする。その他のmetadata URIは現時点では追加しない。
- Rationale：正本リポジトリを公開metadataから参照できるようにする。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：追加URIを独自判断で設定しない。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D092: Implementation Phase Start

- 日付：2026-09-18
- Status：**確定**。
- Decision：Gem skeletonについて事前設計を終了し、Implementation Phaseを開始する。
- Rationale：承認済みの最小範囲の実装へ進む。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：Gem skeletonのみを実装し、Core feature implementationは開始しない。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D093: Explicit Rails Engine Require

- 日付：2026-09-18
- Status：**確定**。
- Decision：`lib/acting_for/engine.rb` の先頭で `require "rails/engine"` を行い、その後に `module ActingFor` 内で `class Engine < ::Rails::Engine` と `isolate_namespace ActingFor` を定義する。
- Rationale：Rails未ロードのRubyプロセスでもD079の `require "acting_for"` を成立させる。
- 未決定：本Decisionの範囲に追加の未決定事項はない。範囲外の未決定事項は既存決定のまま維持する。
- Consequences：D081のEntry Pointを維持し、D082のEngineクラス構造・設定を変えずにRails Engineを明示的にロードする。
- 関連文書：[PROJECT](PROJECT.md)。
- 根拠：ユーザー承認済みのD077〜D093実装指示。

## D094: Rails Entry Point for Standalone Load

- 日付：2026-09-18
- Status：**確定**。
- Context / 既存決定との関係：D093のrequireを後続Decisionとして修正する。D093の履歴は保持する。
- Decision：`lib/acting_for/engine.rb` の先頭を `require "rails"` とする。その後は `module ActingFor` 内で `class Engine < ::Rails::Engine` を定義し、クラス内は `isolate_namespace ActingFor` のみとする。`require "rails/engine"` は置き換える。
- Rationale：D093の `require "rails/engine"` は実環境で単独ロードに必要なRails / ActiveSupportの前提を満たさなかったため、Railsの標準入口を読み込む。
- 未決定：本Decisionで追加の未決定事項は設けない。範囲外の未決定事項は維持する。
- Consequences：D079の単独ロードを成立させる。D081のEntry Point、D082のEngineクラス構造、依存関係、Public APIは変更しない。
- 関連文書：[PROJECT](PROJECT.md)、[Engine](../lib/acting_for/engine.rb)。
- 根拠：ユーザー承認済みのD094追加決定。


## D095: Migration Implementation as Second Implementation Unit

- 日付：2026-09-18
- Status：**確定**。
- Context / 既存決定との関係：D077でImplementation Phaseの最初の実装単位をGem skeletonとし、D094まででGem skeleton実装とstandalone load修正が完了した。次のImplementation単位を確定する。
- Decision：Gem skeletonの次の実装単位は **Migration implementation** とする。対象は `acting_for_agents`、`acting_for_delegations`、`acting_for_audit_events` の3テーブルに限定する。この実装単位ではModel、Authorization、Auditロジック、Test、CIへは進まない。
- Rationale：3テーブルのschema・主要constraint・index方針は既存設計で十分に確定しており、後続のModel実装の土台としてMigrationを先に実装するのが自然である。実装範囲を小さく保ち、既存Decisionを一度に複数レイヤへ展開しない。
- 未決定：Migration Rubyコードの具体形、timestamp・最終filename、実装時に必要となるRails Migration APIの細部。
- Consequences：次の実装検討はMigration implementationに限定する。Model / Authorization / Audit / Test / CIは引き続き未実装とする。
- 関連文書：[Current State](CURRENT_STATE.md)、[Domain Model](domain_model_v0_1.md#17-v01-テーブル構成)、[Gem Structure](gem_structure_v0_1.md#6-migration--db-table-names)。
- 根拠：ユーザー明示承認（2026-09-18）。


## D096: Migration Compatibility Version

- 日付：2026-09-18
- Status：**確定**。
- Context / 既存決定との関係：D046で正式サポート対象をRails 8.0 / 8.1とし、D095で次の実装単位をMigration implementationと確定した。Migration classの互換バージョンを確定する。
- Decision：v0.1の3つのMigration classはすべて `ActiveRecord::Migration[8.0]` を継承する。例：`class CreateActingForAgents < ActiveRecord::Migration[8.0]`。Rails 8.1向けに `[8.1]` へ分けない。
- Rationale：正式サポート範囲の最小Rails versionである8.0をMigration APIの基準とし、Rails 8.0 / 8.1の両方で同一Migrationを扱えるようにするため。
- 未決定：Migration Rubyコードの具体形、timestamp・最終filename。
- Consequences：`acting_for_agents`、`acting_for_delegations`、`acting_for_audit_events` の3 Migrationで同じ互換バージョンを使用する。Model / Authorization / Auditロジック / Test / CIにはまだ進まない。
- 関連文書：[Current State](CURRENT_STATE.md)、[Gem Structure](gem_structure_v0_1.md#6-migration--db-table-names)、[Test Strategy](test_strategy_v0_1.md)。
- 根拠：ユーザー明示承認（2026-09-18）。


## D097: Migration Implementation Start

- 日付：2026-09-18
- Status：**確定**。
- Context / 既存決定との関係：D095でMigration implementationを第2実装単位とし、D096で3 Migrationの互換バージョンを `ActiveRecord::Migration[8.0]` に統一した。
- Decision：Migration implementationを開始し、既存のDB schema決定に従って `acting_for_agents`、`acting_for_delegations`、`acting_for_audit_events` の3 Migrationのみを実装する。Model、Authorization、Auditロジック、Test、CIは今回の範囲に含めない。
- Rationale：Migration実装に必要なschema、主要CHECK constraint、Foreign Key、index方針が既存Decisionで確定しており、追加のdomain設計をせず実装へ移せるため。
- 未決定：実環境PostgreSQLでのMigration up / down実行確認と、後続のModel implementation開始時期。
- Consequences：3 Migration fileを追加する。Migration Ruby syntaxは確認するが、今回のcommitではDummy Rails App、Test code、CIを追加せず、PostgreSQLへの実適用確認は行わない。
- 関連文書：[Current State](CURRENT_STATE.md)、[Domain Model](domain_model_v0_1.md#17-v01-テーブル構成)、[Gem Structure](gem_structure_v0_1.md#6-migration--db-table-names)。
- 根拠：ユーザー明示承認（2026-09-18）。


## D098: Migration Verification Completion Criteria

- 日付：2026-09-18
- Status：**確定**。
- Context / 既存決定との関係：D095でMigration implementationを第2実装単位とし、D097で3 Migration fileを実装した。Model implementationへ進む前のMigration実装完了条件を確定する。
- Decision：Migration implementationは、PostgreSQL上で3 Migrationを実際に `up → rollback → up` し、エラーなく適用・取消・再適用できることを確認して完了とする。この確認が終わるまでModel implementationへ進まない。
- Rationale：Migration Ruby fileの存在やsyntax確認だけでは、PostgreSQL上でのDDL・constraint・index・Foreign Keyの実行可能性を保証できないため。
- 未決定：検証に使用する具体的なRails host環境・実行コマンド。
- Consequences：Migration runtime verificationは未完了のまま維持する。Model / Authorization / Auditロジック / Test / CIにはまだ進まない。
- 関連文書：[Current State](CURRENT_STATE.md)、[Domain Model](domain_model_v0_1.md#17-v01-テーブル構成)、[Gem Structure](gem_structure_v0_1.md#6-migration--db-table-names)。
- 根拠：ユーザー明示承認（2026-09-18）。


## D099: Dummy Rails Host for Migration Verification

- 日付：2026-09-18
- Status：**確定**。
- Context / 既存決定との関係：D098でMigration implementationの完了条件をPostgreSQL上の `up → rollback → up` 実行確認とした。Step 8 Test Strategyでは将来のRails Engine integration用に `test/dummy` Rails Applicationを使う方針が既に確定している。
- Decision：Migration runtime verificationに使用するRails hostは、将来のIntegration Testでも使用する `test/dummy` Rails Applicationとする。Migration検証のために最小限のDummy Rails Appを先行して作成する。
- Rationale：Migration検証専用の一時Hostを別に作らず、後続のRails Engine integration test基盤と共用することで重複を避けるため。
- 未決定：`test/dummy` の今回の最小ファイル構成、Rails version、PostgreSQL接続設定、Migration取り込み・実行の具体的コマンド。
- Consequences：Dummy Rails Appの実装開始はMigration verificationを目的とする最小範囲に限定する。現時点ではMinitest本体のTest実装、Model、Authorization、Auditロジック、CIへは進まない。
- 関連文書：[Current State](CURRENT_STATE.md)、[Gem Structure](gem_structure_v0_1.md#9-test-directory--dummy-rails-app)、[Test Strategy](test_strategy_v0_1.md)。
- 根拠：ユーザー明示承認（2026-09-18）。


## D100: Minimal Dummy Rails App Structure

- 日付：2026-09-18
- Status：**確定**。
- Context / 既存決定との関係：D099でMigration runtime verification用Hostとして `test/dummy` Rails Applicationを採用した。今回作成するDummy Appの最小構成を確定する。
- Decision：Migration検証のために先行作成する `test/dummy` は、次の最小構成に限定する。

```text
test/dummy/
├── config/
│   ├── application.rb
│   ├── boot.rb
│   ├── environment.rb
│   └── database.yml
├── Rakefile
└── db/
    └── migrate/
```

この段階では、Controller / View / Route / Model / Test helper / Minitest本体 / sample domain等は追加しない。
- Rationale：Migrationの `up → rollback → up` 実行確認に必要なRails hostだけを先に用意し、Dummy Appをsample productや過剰なTest基盤へ拡張しないため。
- 未決定：Dummy Appで使用するRails version、Ruby version、PostgreSQL接続設定、Migration取り込み方法・具体的実行コマンド。
- Consequences：次の実装検討は上記最小ファイル群に限定する。Model / Authorization / Auditロジック / Minitest本体 / CIへはまだ進まない。
- 関連文書：[Current State](CURRENT_STATE.md)、[Gem Structure](gem_structure_v0_1.md#9-test-directory--dummy-rails-app)、[Test Strategy](test_strategy_v0_1.md#3-dummy-rails-application)。
- 根拠：ユーザー明示承認（2026-09-18）。


## D101: Dummy App Rails Version

- 日付：2026-09-18
- Status：**確定**。
- Context / 既存決定との関係：D046で正式サポート対象をRails 8.0 / 8.1とし、D096でMigration互換バージョンを `ActiveRecord::Migration[8.0]`、D100でMigration検証用 `test/dummy` の最小構成を確定した。
- Decision：Migration runtime verification用の最小 `test/dummy` Rails Applicationは **Rails 8.0** を基準に作成する。
- Rationale：正式サポート対象の最小Rails versionでMigration適用可否を確認し、`ActiveRecord::Migration[8.0]` の互換基準と揃えるため。
- 未決定：Dummy Appで使用するRuby version、PostgreSQL接続設定、Migration取り込み方法・具体的実行コマンド。
- Consequences：今回のDummy App実装はRails 8.0前提で進める。Rails 8.1の正式検証は後続のIntegration Test / CI matrixで扱い、今回のMigration verificationに含めない。
- 関連文書：[Current State](CURRENT_STATE.md)、[Gem Structure](gem_structure_v0_1.md#11-runtime-dependencies)、[Test Strategy](test_strategy_v0_1.md#15-後続決定に対応する検証設計d035d043d046)。
- 根拠：ユーザー明示承認（2026-09-18）。

## D102: Dummy App Ruby version

- 日付：2026-09-18
- Status：**確定**。
- Decision：Dummy AppのRuby versionはRuby 3.4とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D103: Migration Verification Database

- 日付：2026-09-18
- Status：**確定**。
- Decision：Migration検証DBはPostgreSQL 16とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D104: Database Connection Environment

- 日付：2026-09-18
- Status：**確定**。
- Decision：database.ymlの接続情報は環境変数から取得し、password等をRepositoryへ固定保存しない。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D105: Default Database Name

- 日付：2026-09-18
- Status：**確定**。
- Decision：default DB名は `acting_for_dummy_test` とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D106: Verification Rails Environment

- 日付：2026-09-18
- Status：**確定**。
- Decision：Migration検証は `RAILS_ENV=test` のみで行う。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D107: Default Database Connection

- 日付：2026-09-18
- Status：**確定**。
- Decision：default接続はlocalhost:5432 / postgresとし、passwordにはdefaultを設けない。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D108: No Repository Env File

- 日付：2026-09-18
- Status：**確定**。
- Decision：`.env` はRepositoryへ追加せず、秘密情報は環境変数で渡す。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D109: Database Adapter

- 日付：2026-09-18
- Status：**確定**。
- Decision：DB adapterは `postgresql` とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D110: Database Name Override

- 日付：2026-09-18
- Status：**確定**。
- Decision：`POSTGRES_DB` でDB名を上書き可能とし、未指定時は `acting_for_dummy_test` とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D111: Manual Minimal Dummy App

- 日付：2026-09-18
- Status：**確定**。
- Decision：`rails new` は使わず、最小Dummy Appを手動作成する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D112: Dummy Application Class

- 日付：2026-09-18
- Status：**確定**。
- Decision：`Dummy::Application < Rails::Application` とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D113: Dummy Rails Defaults

- 日付：2026-09-18
- Status：**確定**。
- Decision：`config.load_defaults 8.0` を使用する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D114: Minimal Rails Components

- 日付：2026-09-18
- Status：**確定**。
- Decision：`rails/all` は使わず、railsとactive_record/railtieを使用する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D115: Test Database Configuration Only

- 日付：2026-09-18
- Status：**確定**。
- Decision：database.ymlはtestのみとする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D116: Dummy Boot

- 日付：2026-09-18
- Status：**確定**。
- Decision：config/boot.rbは `require "bundler/setup"` のみとする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D117: Dummy Application Requires

- 日付：2026-09-18
- Status：**確定**。
- Decision：application.rbでrails / active_record/railtie / acting_forを読み込む。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D118: Dummy Environment Initialization

- 日付：2026-09-18
- Status：**確定**。
- Decision：environment.rbで `Rails.application.initialize!` を実行する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D119: Dummy Rake Tasks

- 日付：2026-09-18
- Status：**確定**。
- Decision：Rakefileで `Rails.application.load_tasks` を実行する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D120: Host Migration Installation

- 日付：2026-09-18
- Status：**確定**。
- Decision：Gem MigrationをHost同様 `test/dummy/db/migrate` へ取り込んで検証する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D121: Standard Engine Migration Installation

- 日付：2026-09-18
- Status：**確定**。
- Decision：Rails Engine標準Migration取り込み機構を使い、独自copy task / generatorは作らない。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D122: Migration Verification Cycle

- 日付：2026-09-18
- Status：**確定**。
- Decision：up → rollback → upを行い、table / index / FK / CHECK constraintまで確認する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D123: Empty Database First Up

- 日付：2026-09-18
- Status：**確定**。
- Decision：最初のupは空DBから開始する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D124: Inspect Database Structure

- 日付：2026-09-18
- Status：**確定**。
- Decision：command成功だけでなくDB構造自体を確認する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D125: Exclude Dummy Schema

- 日付：2026-09-18
- Status：**確定**。
- Decision：`test/dummy/db/schema.rb` はGit管理しない。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D126: Migration Installation Task

- 日付：2026-09-18
- Status：**確定**。
- Decision：`railties:install:migrations` を利用する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D127: Track Copied Migration Fixtures

- 日付：2026-09-18
- Status：**確定**。
- Decision：`test/dummy/db/migrate/*.acting_for.rb` はIntegration検証用fixtureとしてGit管理する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D128: Test Migration Commands

- 日付：2026-09-18
- Status：**確定**。
- Decision：`RAILS_ENV=test` で `db:migrate → db:rollback → db:migrate` を実行する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D129: Clean Dedicated Test Database

- 日付：2026-09-18
- Status：**確定**。
- Decision：検証開始時は専用test DBをクリーンな状態から使用する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D130: Rails 8.0 Verification Gemfile

- 日付：2026-09-18
- Status：**確定**。
- Decision：`gemfiles/rails_8_0.gemfile` を追加する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D131: Verification Bundle Gemfile

- 日付：2026-09-18
- Status：**確定**。
- Decision：`BUNDLE_GEMFILE=gemfiles/rails_8_0.gemfile` で検証する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D132: Verification Gemspec Reference

- 日付：2026-09-18
- Status：**確定**。
- Decision：rails_8_0.gemfileから `gemspec path: ".."` でGem本体を参照する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D133: Rails 8.0 Dependency Constraints

- 日付：2026-09-18
- Status：**確定**。
- Decision：activerecord / activesupport / railtiesは `~> 8.0.0` とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D134: PostgreSQL Verification Gem

- 日付：2026-09-18
- Status：**確定**。
- Decision：検証用Gemfileへpgを追加する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D135: Preserve Runtime Dependencies

- 日付：2026-09-18
- Status：**確定**。
- Decision：root Gemfile / acting_for.gemspecのruntime dependencyは変更しない。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D136: Minimal Verification Gemfile

- 日付：2026-09-18
- Status：**確定**。
- Decision：rails_8_0.gemfileは最小構成とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D137: Ruby Version in Runtime

- 日付：2026-09-18
- Status：**確定**。
- Decision：Ruby versionはGemfileで固定せず、実行環境でRuby 3.4を使用する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D138: No Dummy Gemfile

- 日付：2026-09-18
- Status：**確定**。
- Decision：Dummy App独自Gemfileは作らない。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D139: Rake Without Binstubs

- 日付：2026-09-18
- Status：**確定**。
- Decision：bin/rails / bin/rakeは作らず、 `bundle exec rake` を利用する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D140: Preserve Generated Migration Filenames

- 日付：2026-09-18
- Status：**確定**。
- Decision：Dummy側Migration filenameはRailsが生成したtimestampをそのまま使用する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D141: Standard Database Lifecycle Tasks

- 日付：2026-09-18
- Status：**確定**。
- Decision：DB作成・削除はRails標準db:create / db:dropを使用し、独自setup scriptは作らない。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D142: Single Verification Commit

- 日付：2026-09-18
- Status：**確定**。
- Decision：Dummy App実装・Migration検証・Decision反映をまとめて1commitにする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D143: Fix Source Migrations

- 日付：2026-09-18
- Status：**確定**。
- Decision：Migration問題時はDummyコピーだけを修正せず、Gem本体Migrationを修正して再コピーする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D144: Final Structure Inspection

- 日付：2026-09-18
- Status：**確定**。
- Decision：最終up後にcolumn / default / index / FK / CHECK constraintまで確認する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D145: Verify Rollback Table Removal

- 日付：2026-09-18
- Status：**確定**。
- Decision：rollback後は3テーブルがすべて削除されたことを確認する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D146: Docker Verification Isolation

- 日付：2026-09-18
- Status：**確定**。
- Decision：Migration検証環境をDockerへ完全分離し、MacへRuby / Rails / PostgreSQLを直接installしない。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D147: Two Docker Services

- 日付：2026-09-18
- Status：**確定**。
- Decision：app + dbの2サービスとする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D148: Migration Compose File

- 日付：2026-09-18
- Status：**確定**。
- Decision：`compose.migration.yml` を使用する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D149: Docker Only Bundle Install

- 日付：2026-09-18
- Status：**確定**。
- Decision：bundle installもDocker内だけで実施する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D150: Disposable PostgreSQL Data

- 日付：2026-09-18
- Status：**確定**。
- Decision：PostgreSQLデータは検証後破棄可能にする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D151: Migration Dockerfile Path

- 日付：2026-09-18
- Status：**確定**。
- Decision：Dockerfileは `docker/migration/Dockerfile` とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D152: Ruby Docker Image

- 日付：2026-09-18
- Status：**確定**。
- Decision：Ruby imageは `ruby:3.4-bookworm` とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D153: Repository Bind Mount

- 日付：2026-09-18
- Status：**確定**。
- Decision：Repositoryを `/app` へbind mountし、working_dirは `/app` とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D154: Docker Database Connection

- 日付：2026-09-18
- Status：**確定**。
- Decision：Docker network内DB接続はhost=db、port=5432、user=postgres、database=acting_for_dummy_testとする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D155: App Container Environment

- 日付：2026-09-18
- Status：**確定**。
- Decision：app containerは `RAILS_ENV=test`、`BUNDLE_GEMFILE=/app/gemfiles/rails_8_0.gemfile` とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D156: Docker Verification Cleanup

- 日付：2026-09-18
- Status：**確定**。
- Decision：検証後に `docker compose ... down -v` を実行する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D157: Start Database First

- 日付：2026-09-18
- Status：**確定**。
- Decision：dbを先に `up -d` で起動する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D158: Ephemeral App Container

- 日付：2026-09-18
- Status：**確定**。
- Decision：appは常駐させず、 `docker compose run --rm app` で実行する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D159: Install Gems First in Docker

- 日付：2026-09-18
- Status：**確定**。
- Decision：最初にDocker内でbundle installを実行する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D160: Verification Command Order

- 日付：2026-09-18
- Status：**確定**。
- Decision：検証順はdb:create → railties:install:migrations → db:migrate → 構造確認 → rollback → 削除確認 → db:migrate → 最終構造確認とする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D161: PostgreSQL SQL Inspection

- 日付：2026-09-18
- Status：**確定**。
- Decision：構造確認はPostgreSQL SQLでも実施する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D162: Final Volume Cleanup

- 日付：2026-09-18
- Status：**確定**。
- Decision：最後に `down -v` を実行する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D163: PostgreSQL Healthcheck

- 日付：2026-09-18
- Status：**確定**。
- Decision：PostgreSQLへ `pg_isready` healthcheckを設定する。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D164: No Published Database Port

- 日付：2026-09-18
- Status：**確定**。
- Decision：DB portをMacへpublishしない。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D165: Required PostgreSQL Password

- 日付：2026-09-18
- Status：**確定**。
- Decision：`POSTGRES_PASSWORD` は必須環境変数とし、Composeへpasswordを固定記載しない。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D166: Bundle Named Volume

- 日付：2026-09-18
- Status：**確定**。
- Decision：Bundle用GemはDocker named volumeへ保存し、 `down -v` で削除可能にする。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## D167: Psql Structure Inspection

- 日付：2026-09-18
- Status：**確定**。
- Decision：構造確認にはdb container内psqlを利用し、独自検証Rubyコード / Rake taskは作らない。
- 根拠：ユーザー承認済みのD102〜D167完了反映・Commit指示。

## Migration Runtime Verification完了記録（2026-09-18）

D098・D122〜D145・D160の完了条件を確認した実施結果であり、新しいDecisionではない。基準commitは `0a6ba3eee733ee28890344746edf3af40632191e`。

- 環境：Docker内のみ。Ruby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16 / RAILS_ENV=test。
- 空の専用DBからup成功 → `db:rollback STEP=3` 成功 → 対象3テーブルすべての削除確認 → 再up成功。初回と再up後のDB構造は一致した。
- db container内のpsqlで、acting_for_agents / acting_for_delegations / acting_for_audit_eventsの計31カラムの型・NULL・defaultが設計と一致することを確認した。全Primary Keyはbigint。
- agents.identifierのunique index、delegations.agent_idのindex、Authorization lookupの5カラム複合index（agent_id, principal_type, principal_id, action, resource_type）の存在・順序を確認した。
- Delegations → AgentsのFKを確認し、cascade deleteなし。DelegationsのCHECKは2件（resource scope / effect）、AuditEventsは3件（resource scope / decision / reason_code）。
- AuditEventsにはupdated_at、FK、Primary Key以外のindexがないことを確認した。
- Gem本体Migrationは問題なく、修正不要だった。DummyコピーはRails生成filenameと出典コメントを維持し、Migration本体の内容を保持する。
- `config.eager_load` 未設定warningは検証結果へ影響していないため、今回変更しない。
- 最後に `down -v` を実行し、検証用DB・Gem volumeの削除を確認した。Model / Authorization / Auditロジック / Minitest本体 / CIには進んでいない。
- 関連文書：[Current State](CURRENT_STATE.md)、[Domain Model](domain_model_v0_1.md#17-v01-テーブル構成)。

## D168: Model Implementation Unit

- 日付：2026-09-18
- Status：**確定**。
- Decision：第3実装単位をModel implementationとする。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D169: Model Implementation Targets

- 日付：2026-09-18
- Status：**確定**。
- Decision：対象はActingFor::ApplicationRecord / ActingFor::Agent / ActingFor::Delegation / ActingFor::AuditEventとする。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D170: Model Only Scope

- 日付：2026-09-18
- Status：**確定**。
- Decision：今回の範囲はModel層のみ。Delegation API / Authorization / Decision / Test / CIへ進まない。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D171: Abstract ApplicationRecord

- 日付：2026-09-18
- Status：**確定**。
- Decision：ApplicationRecordはActiveRecord::Baseを継承するabstract classとする。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D172: Model Associations

- 日付：2026-09-18
- Status：**確定**。
- Decision：Agent has_many Delegations、Delegation belongs_to Agent、Delegation belongs_to polymorphic Principalとする。AuditEventはsnapshotのためAgent / Principal associationを持たない。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D173: Agent Deletion Restriction

- 日付：2026-09-18
- Status：**確定**。
- Decision：Delegationを持つAgentの削除はModelでもrestrictする。通常の無効化はDelegation#revoke!を使う。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D174: Agent Model Validation

- 日付：2026-09-18
- Status：**確定**。
- Decision：Agent validationを既存設計どおり実装する。identifier / nameの非String値がActiveRecord castで通らないようtype-cast前入力も確認する。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D175: Minimal Current Time

- 日付：2026-09-18
- Status：**確定**。
- Decision：D035実装のため `ActingFor.current_time` を最小実装する。通常は `Time.current` を返す。Clock configuration APIは作らない。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D176: Delegation Model Validation

- 日付：2026-09-18
- Status：**確定**。
- Decision：Delegationの基本Model validationを実装する。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D177: Delegation Immutability

- 日付：2026-09-18
- Status：**確定**。
- Decision：persist済みDelegationの権限内容をModel validationでimmutableにする。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D178: Revocation Only Through Revoke

- 日付：2026-09-18
- Status：**確定**。
- Decision：revoked_atの通常更新は禁止し、revoke!だけが変更する。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D179: Atomic Conditional Revocation

- 日付：2026-09-18
- Status：**確定**。
- Decision：revoke!は `id + revoked_at IS NULL` のconditional atomic updateを使用する。最初のrevocation timestampを保持し、explicit row lock / internal retryを行わない。unsaved recordは `ActiveRecord::RecordNotSaved` とする。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D180: Canonical Constraint Validation

- 日付：2026-09-18
- Status：**確定**。
- Decision：Constraint Model validationはPublic入力正規化ではなく、保存されるcanonical formを検証する。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D181: No Constraint Value Conversion

- 日付：2026-09-18
- Status：**確定**。
- Decision：Constraint valueを暗黙型変換しない。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D182: Audit Snapshot Validation

- 日付：2026-09-18
- Status：**確定**。
- Decision：AuditEventでsnapshot、resource scope、decision / reason pair、matched_delegation_ids、sanitized_contextをvalidationする。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D183: Readonly Persisted Audit Events

- 日付：2026-09-18
- Status：**確定**。
- Decision：persist済みAuditEventはreadonlyとし、update / destroyを `ActiveRecord::ReadOnlyRecord` で拒否する。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D184: Model Protection Boundary

- 日付：2026-09-18
- Status：**確定**。
- Decision：Model制約は通常ActiveRecord操作を対象とする。update_all / delete_all / raw SQL / DB管理者操作まで完全防御せず、DB triggerも追加しない。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D185: Agent Input Types and Case Sensitivity

- 日付：2026-09-18
- Status：**確定**。
- Decision：Agentのidentifier / nameはbefore type cast値を確認し、implicit String conversionを許可しない。identifier uniquenessはcase-sensitiveとする。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D186: Standard Rails Validation Errors

- 日付：2026-09-18
- Status：**確定**。
- Decision：Model validation失敗はRails標準errorsを使用する。独自Model validation Exceptionを作らない。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D187: Dirty Change Immutability Validation

- 日付：2026-09-18
- Status：**確定**。
- Decision：Delegation immutabilityはdirty change validationで実装する。callbackで無言に値を戻さない。revoked_atも通常saveでは変更不可とする。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D188: Single Revocation Time and Reload

- 日付：2026-09-18
- Status：**確定**。
- Decision：revoke!では `ActingFor.current_time` を1回取得し、revoked_at / updated_atへ同じ時刻をatomic updateする。その後reloadする。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## D189: JSON Column Validation

- 日付：2026-09-18
- Status：**確定**。
- Decision：JSON columnのModel validationはcast後Ruby値を検証する。独自JSON parse / serializer / custom attribute typeは作らない。
- 根拠：ユーザー承認済みのModel Implementation完了反映・Commit指示。

## Model Runtime Verification完了記録（2026-09-18）

D168〜D189に基づくModel実装の実施結果であり、新しいDecisionではない。作業開始時の基準commitは `f2e50d2bf514be8eaf2c16e9498c09d55857029e`。

- 環境：Docker / Ruby 3.4.10 / Rails 8.0.5.1 / PostgreSQL 16.15 / RAILS_ENV=test。MacへのRuby / Rails / PostgreSQLインストールは行っていない。
- 新規の専用DBに既存Migrationを適用し、一時Ruby scriptから `test/dummy` environmentをrequireして確認した。scriptはRepositoryへ追加していない。Minitest本体は未実装。
- **全213 checks成功**：ApplicationRecord abstract class 1、Agent 36、Delegation基本24、Delegation immutability 23、Constraint 56、revoke! 5、AuditEvent 59、append-only 9。
- Agent：Integer identifier / name、duplicate identifierを拒否。name=nil / duplicate name / case-sensitive identifierを許可。Delegationを持つAgentのdestroy拒否とDB Foreign Key制約を確認した。
- Delegation：Resource scope、effect、期限、必須項目、canonical constraintsを検証。immutable attributesの通常更新とconstraintsのin-place変更を拒否した。ConstraintのSymbol keyはcast前入力も確認して拒否し、独自JSON parseや型変換は追加していない。
- revoke!：1回目にrevoked_at / updated_atへ同一時刻を設定。2回目は例外なしで両timestampが不変。異なる2接続のconcurrent executionでも最初のtimestampを保持した。unsaved revoke!は `ActiveRecord::RecordNotSaved` となった。
- AuditEvent：正式3 pair、snapshot、resource scope、matched_delegation_idsの型・重複・件数・順序保持、sanitized_contextを確認。persist直後と再取得後のupdate / update! / destroyは `ActiveRecord::ReadOnlyRecord` となり、DBの値も不変だった。
- Migration regression：`db:migrate → db:rollback STEP=3 → db:migrate` 成功。rollback後の対象3テーブル削除も確認した。既存Migrationは変更していない。
- 既存Dummyの `config.eager_load` 未設定warningあり。検証コマンドの作業ディレクトリと一時Principal定義を修正後、全件成功した。
- 検証後に専用Composeプロジェクトを `down -v` し、コンテナ・DB / Gem volumeを削除した。
- Delegation API / Authorization / Decision / ConstraintEvaluator / Audit保存Service / Minitest / CI / Runnable Quick Startには進んでいない。
- 関連文書：[Current State](CURRENT_STATE.md)。

## D190: Delegation Public APIを次の実装単位とする

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

- 次の実装単位を `ActingFor.delegate(...)` とする
- 既存 `Delegation#revoke!` を利用する
- この実装単位では Authorization / Decision / Audit authorization integration には進まない
- 現在の実装単位を越えて機能追加しない

## D191: Delegation API実装時のException class

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

今回実装対象：

```ruby
ActingFor::Error < StandardError
ActingFor::InvalidRequestError < ActingFor::Error
```

既に設計済みの以下は、必要になる実装段階まで実装を待つ：

```ruby
ActingFor::InternalError
ActingFor::AuditPersistenceError
```

新しいException classを追加しない。

## D192: `lib/acting_for.rb` は薄いPublic Entry Point

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

- `ActingFor.delegate(...)` は `lib/acting_for.rb` に置く
- `lib/acting_for.rb` は薄いPublic API Entry Pointに限定する
- 非自明なvalidation / normalizationロジックを `lib/acting_for.rb` に集中させない
- 既存 `gem_structure_v0_1.md` の「Public APIと内部実装を分離する」方針を維持する

## D193: Delegation保存とException境界

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

- 正常時はpersist済み `ActingFor::Delegation` を返す
- 保存は `ActingFor::Delegation.create!` を使用する
- Public入力不正は `ActingFor::InvalidRequestError`
- DB障害や予期しないModel validation failureを一律 `InvalidRequestError` へwrapしない
- lower-level exceptionは既存方針どおり原則そのまま伝播する

## D194: Public APIでcanonical formへ正規化する

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

`ActingFor.delegate(...)` のPublic API境界で、Modelへ渡す前に以下へ正規化する。

```text
agent
→ persisted ActingFor::Agent

principal
→ persisted ActiveRecord model

action
→ canonical String

resource
→ resource_type / resource_id

constraints
→ canonical Array<Hash<String, ...>>

effect
→ "allow" / "require_approval"

expires_at
→ 検証済みTime系objectまたはnil

revoked_at
→ nil
```

Modelはcanonical formの最終防御を担当する。

## D195: `DelegationCreator` をInternal Serviceとして導入する

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

配置：

```text
app/services/acting_for/internal/delegation_creator.rb
```

概念：

```text
ActingFor.delegate(...)
    ↓
ActingFor::Internal::DelegationCreator
    ↓
ActingFor::Delegation.create!
```

責務：

- Public入力validation
- normalization
- Resource identity変換
- Constraint canonicalization
- expires_at validation
- Delegation作成

v0.1では以下のような過剰分割をしない：

```text
DelegationValidator
DelegationNormalizer
ConstraintNormalizer
DelegationBuilder
```

## D196: `DelegationCreator.call` を内部呼び出し形とする

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

内部Serviceの呼び出し形：

```ruby
ActingFor::Internal::DelegationCreator.call(
  agent:,
  principal:,
  action:,
  resource:,
  constraints:,
  effect:,
  expires_at:
)
```

- `DelegationCreator` はInternal API
- 利用者が直接呼ぶことは想定しない
- `DelegationCreator.new(...).call` をPublic contractにしない
- Base Service / ApplicationServiceを追加しない

## D197: PrincipalはRails polymorphic associationへ任せる

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

Delegation作成時、Principalを以下のように手動変換しない：

```ruby
principal_type: principal.class.name
principal_id: principal.id.to_s
```

代わりに：

```ruby
ActingFor::Delegation.create!(
  principal: principal,
  ...
)
```

としてRailsのpolymorphic associationへ任せる。

ResourceはActiveRecord associationではないため、既存設計どおりActingFor側で `resource_type / resource_id` に正規化する。

## D198: Public validationとModel / DB failureを分離する

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

処理順：

```text
Public input
  ↓
DelegationCreator validation / normalization
  ↓
canonical values
  ↓
Delegation.create!
```

- Public仕様違反 → `ActingFor::InvalidRequestError`
- `create!` は1回だけ使用
- 事前に `valid?` を呼ばない
- canonical化後にModel validationで `ActiveRecord::RecordInvalid` が発生した場合は `InvalidRequestError` にwrapしない
- DB exceptionも原則そのまま伝播
- 独自transaction / retryを追加しない

## D199: Public Exceptionは `lib/acting_for/errors.rb`

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

新規：

```text
lib/acting_for/errors.rb
```

内容：

```ruby
module ActingFor
  class Error < StandardError; end
  class InvalidRequestError < Error; end
end
```

`lib/acting_for.rb` から：

```ruby
require "acting_for/errors"
```

将来 `InternalError` / `AuditPersistenceError` を実装するときも同じファイルへ追加する。

Exceptionごとにファイル分割しない。
独自error codeや追加属性はv0.1では導入しない。

## D200: Public入力objectを破壊しない

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

`DelegationCreator` は呼び出し元から渡された入力を破壊的変更しない。

特に：

- constraints Arrayを変更しない
- 各Constraint Hashを変更しない
- `in` operatorのvalue Arrayも変更しない
- canonical化では必要な新しいArray / Hashを生成する
- `deep_freeze` はしない
- 汎用DeepCopy utilityは作らない

## D201: Resource正規化

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

既存D032を最小実装する。

```text
nil
→ resource_type = nil
→ resource_id = nil

Resource Class
→ resource.model_name.name
→ resource_id = nil

Resource instance
→ resource.class.model_name.name
→ resource.id.to_s
```

Class：

- `model_name` を持つ必要がある
- 持たない場合は `InvalidRequestError`

Instance：

- classから `model_name` を解決できる
- `id` を持つ
- `id != nil`
- `id.to_s` が空文字でない

Resource instanceは `ActiveRecord::Base` に限定しない。
ActiveModel-style Resourceを許可する。

要求しないもの：

```text
resource.persisted?
to_model
to_param
GlobalID
polymorphic association
String / Hashによる直接identifier指定
```

## D202: actionのblankをPublic APIで拒否する

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

`action:` はString / Symbolを受け付け、SymbolはStringへ正規化する。

以下は `InvalidRequestError`：

```text
nil
""
"   "
String / Symbol以外
```

ただし自動trimはしない。

```ruby
" purchase "
```

を `"purchase"` へ変換しない。

## D203: Principal validation

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

Principalとして許可するのは：

```ruby
principal.is_a?(ActiveRecord::Base)
principal.persisted?
```

の両方を満たすrecord。

不正例：

```text
nil
String
Hash
単なるid付きobject
unsaved ActiveRecord record
```

追加でPrincipal ID型を独自検証しない。
Principal type / IDを手動生成しない。

## D204: Agent validation

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

Agentとして許可するのは：

```ruby
agent.is_a?(ActingFor::Agent)
agent.persisted?
```

を満たすrecord。

完全class一致ではなく `is_a?` とする。

Public API内で以下をしない：

```text
identifierによるAgent検索
Agent自動作成
Agent Resolution
Agent Authentication
```

## D205: effectの厳密な正規化

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

許可：

```text
"allow"              → "allow"
:allow               → "allow"
"require_approval"   → "require_approval"
:require_approval    → "require_approval"
```

不正：

```text
nil
"deny"
:deny
"ALLOW"
" allow "
"require-approval"
その他type
```

- SymbolのみString化
- 任意objectのto_sを使わない
- trimしない
- downcaseしない
- aliasを追加しない
- explicit deny Delegationは作らない

## D206: Constraint Hash keyのcanonicalization

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

各Constraintは `field / operator / value` の3 keyだけを許可。

- keyはString / Symbolのみ
- String keyへ正規化
- 3 key不足 → `InvalidRequestError`
- extra key → `InvalidRequestError`
- 正規化後に同じkeyが重複 → `InvalidRequestError`
- 元Hashを変更しない
- HashWithIndifferentAccess的な曖昧な扱いを導入しない

例：

```ruby
{
  field: "amount",
  "field" => "price",
  operator: "lte",
  value: 10_000
}
```

は正規化後 `field` が重複するため不正。

## D207: Constraint field / operatorのみ必要最小限正規化

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

field：

- String / Symbolのみ
- SymbolはStringへ
- 空文字は不正
- trimしない
- downcaseしない
- 任意objectのto_sをしない

operator：

- String / Symbolのみ
- SymbolはStringへ
- 許可値：

```text
eq
lt
lte
gt
gte
in
```

value：

- 型変換しない
- String数値をIntegerへ変換しない
- SymbolをStringへ変換しない
- FloatをIntegerへ変換しない
- `in` Array要素も変換しない

既存D032のoperator別value型をそのまま守る。

## D208: Public API TestをExecutable Documentationとして書く

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

正式Test Suiteでは、Public API Testを利用者が読める仕様書として扱う。

方針：

- `ActingFor.delegate(...)` / `ActingFor.authorize(...)` を中心にテスト
- テスト名から許可 / 拒否条件が理解できるようにする
- 正常系と間違いやすい異常系を明示する
- Internal class名 / private methodへの依存を最小化する
- 1テストに大量の仕様を詰め込まない
- コメントよりテスト名・入力・期待結果を読みやすくする
- READMEの利用例とPublic API Testを乖離させない

例：

```ruby
test "delegate accepts a persisted agent" do
  ...
end

test "delegate rejects an unsaved agent" do
  ...
end

test "delegate converts symbol action to string" do
  ...
end

test "delegate does not mutate constraints passed by the caller" do
  ...
end
```

## D209: expires_atは検証のみで時刻変換しない

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

許可：

```text
nil
Time
ActiveSupport::TimeWithZone
```

指定時：

```ruby
expires_at > ActingFor.current_time
```

が必要。

不正例：

```text
String
Date
DateTime
Integer
現在時刻と同じ
過去
```

ActingFor側では以下をしない：

```text
parse
Timeへの暗黙変換
timezone変換
丸め
```

正常なTime系objectはそのままActiveRecordへ渡す。

## D210: Exception classはPublic contract、message全文はcontractにしない

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

- `ActingFor::InvalidRequestError` がraiseされることはPublic contract
- messageは人間が原因を理解できる具体的内容にする
- message全文の完全一致をPublic contractにしない
- Testも原則message全文一致に依存しない

## D211: validation順序はPublic contractにしない

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

複数の入力が同時に不正でも、

```text
agentが必ず最初
principalが必ず次
```

のようなvalidation順序は保証しない。

Testでは原則1ケースにつき1つの仕様違反を明確にする。

保証するのは：

```text
不正なPublic入力
→ ActingFor::InvalidRequestError
```

であり、どのエラーを最初に検出するかは内部実装とする。

## D212: Constraintへ未決定の追加ルールを足さない

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済みのD190〜D212設計ドキュメント反映指示。
- 関連文書：[Public API](public_api_v0_1.md#9-delegation-api)、[Gem Structure](gem_structure_v0_1.md)、[Test Strategy](test_strategy_v0_1.md)。

D032 / D207をそのまま実装し、意味的な補正・最適化を追加しない。

既存仕様上、次を新たに禁止しない：

```ruby
field: "   "
operator: "in", value: []
operator: "in", value: [1, 1, 2]
```

理由：

- fieldはnon-emptyでありnon-blankとは決定していない
- `in` はArrayであることまでが既存仕様
- duplicate禁止は決定していない

以下をしない：

```text
field trim
field命名regex追加
空in Arrayの拒否
in valueのdedup
sort
意味的に「役に立たないConstraint」かの判定
```

Public APIは既決定の型・構造を保証し、未決定の意味ルールを勝手に追加しない。

## 追記する際の項目

新しい決定には、次を記録する。

1. IDと短いタイトル
2. 日付と状態
3. 決定または提案した内容
4. その理由
5. 関連するファイル・Issue
6. 残っている未決定事項

ユーザーが明示的に採用したら「提案」を「確定」に更新し、採用日を記録する。後で変更した場合も、以前の理由を消さずに変更履歴を残す。

## D213: Decisionは最小のimmutable Value Objectとして実装する

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済み。
- 関連文書：[Public API](public_api_v0_1.md#6-decision-public-api)、[Gem Structure](gem_structure_v0_1.md#5-decision-value-object)、[Test Strategy](test_strategy_v0_1.md#4-decision-unit-test)。

`ActingFor::Decision` はAuthorization結果を表す最小のimmutable Value Objectとして実装する。

- 配置は `lib/acting_for/decision.rb`
- ActiveRecord Modelにはしない
- DBへ永続化しない
- statusは `:allow` / `:deny` / `:require_approval` の3種類だけ
- 正式Public APIは既存D018 / D050どおり `status` / `allowed?` / `denied?` / `approval_required?` の4つだけ
- `:require_approval` の場合、`allowed?` は必ずfalse
- 初期化後は `freeze` し、状態変更不可とする
- `initialize(status)` は内部実装で利用してよいが、Public APIとして保証しない
- 不正なstatusを内部で渡した場合は `ArgumentError` とする
- 不正statusを `ActingFor::InvalidRequestError` にはしない。InvalidRequestErrorはPublic入力不正のためであり、Decisionへの不正statusは内部プログラミングエラーとして扱う
- constructorをprivate化しない
- Factoryを追加しない

v0.1では `reason_code` / `matched_delegation_ids` / `context` / `success?` / `permitted?` / `executable?` / `to_h` / 独自 `==` / 独自 `hash` / Factory / private constructor を追加しない。

想定実装形は以下。ただしD213の設計反映時点では実装しない。

```ruby
module ActingFor
  class Decision
    STATUSES = %i[allow deny require_approval].freeze
    private_constant :STATUSES

    attr_reader :status

    def initialize(status)
      raise ArgumentError, "invalid decision status" unless STATUSES.include?(status)

      @status = status
      freeze
    end

    def allowed?
      status == :allow
    end

    def denied?
      status == :deny
    end

    def approval_required?
      status == :require_approval
    end
  end
end
```

## D214: ConstraintEvaluatorを次の実装単位とする

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済み。
- 関連文書：[Gem Structure](gem_structure_v0_1.md#4-internal-authorization-services)、[Test Strategy](test_strategy_v0_1.md#5-constraintevaluator-unit-test)、[Domain Model](domain_model_v0_1.md#8-constraint)。

Decision実装完了後の次の実装単位を `ActingFor::Internal::ConstraintEvaluator` とする。

理由：

- Authorization本体へ進む前にConstraint評価を独立して実装・検証できる
- Authorizationの責務を小さく保ち、実装を一度に複雑化しない
- 既存Gem Structure / Test StrategyでConstraintEvaluatorはInternal Serviceとして分離済み

この実装単位では以下へ進まない：

- `ActingFor.authorize(...)`
- `ActingFor::Internal::Authorization`
- Audit authorization integration
- Authorization用DB query

ConstraintEvaluatorの既存仕様を実装対象とし、未決定の意味ルールや追加機能を勝手に導入しない。

## D215: Constraint fieldはContextのSymbol keyへ厳密に対応させる

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済み。
- 関連文書：[Domain Model](domain_model_v0_1.md#8-constraint)、[Public API](public_api_v0_1.md#4-authorize-arguments)、[Test Strategy](test_strategy_v0_1.md#5-constraintevaluator-unit-test)。

保存済みConstraintの `field` はcanonical Stringであり、Constraint評価時はそのStringをSymbolへ変換して、ContextのトップレベルSymbol keyを1回だけ厳密に参照する。

例：

```text
Constraint field "amount"
→ context[:amount]
```

ルール：

- `"amount"` は `context[:amount]` を参照する
- `context["amount"]` とはmatchしない
- String / Symbolのindifferent accessは行わない
- Context keyの自動変換を追加しない
- nested pathとして解釈しない
- たとえばfield `"order.amount"` は `context[:"order.amount"]` というトップレベルkeyだけを参照し、`context[:order][:amount]` は参照しない
- fieldがContextに存在しない、または値がnilならConstraint不成立

理由：

- Public APIの既存例 `context: { amount: 8_900 }` と自然に一致する
- Audit ContextのSymbol key完全一致方針と整合する
- String / Symbol両方を暗黙に探索する曖昧な評価を避ける
- nested object access非対応という既存v0.1境界を維持する

## D216: AuthorizationはDB候補抽出とRuby最終評価を分離する

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済み。
- 関連文書：[Gem Structure](gem_structure_v0_1.md#4-internal-authorization-services)、[Domain Model](domain_model_v0_1.md#4-delegation)、[Test Strategy](test_strategy_v0_1.md#6-actingforauthorize-integration-test)。

`ActingFor::Internal::Authorization` のDelegation評価は、DBで候補を絞り込み、その後Ruby側で最終matchingを行う二段階構成とする。

概念上の流れ：

```text
DB candidate lookup
  ↓
agent / principal / action / resource_type / active state で候補抽出
  ↓
Ruby final evaluation
  ├─ Resource scope判定
  ├─ ConstraintEvaluator
  └─ matching Delegation確定
  ↓
require_approval > allow > deny
```

ルール：

- Constraint評価をDB queryへ押し込まず、既実装の `ActingFor::Internal::ConstraintEvaluator` を使う
- specific Resource / type-wide Resource / Resource-lessの最終scope判定はRuby側で行う
- matching Delegationが0件なら `:deny`
- matching Delegationに `require_approval` が1件以上あれば `:require_approval`
- それ以外にmatching Delegationが1件以上あれば `:allow`
- explicit deny Delegationは導入しない
- DB取得順、ID順、created_at順、作成順、Resource specificityによる優先順位を導入しない
- lock / cache / retryを追加しない
- 具体的SQL、ActiveRecord chainの細かな形、private method構成はPublic contractにしない

この実装単位ではAuditEvent保存と `ActingFor.authorize(...)` Public Entry Pointの統合にはまだ進まない。まずInternal Authorization coreのcandidate lookup・final matching・Decision生成を実装対象とする。

## D217: authorizeのPublic入力validation / normalizationはInternal Authorizationが担当する

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済み。
- 関連文書：[Public API](public_api_v0_1.md#4-authorize-arguments)、[Gem Structure](gem_structure_v0_1.md#4-internal-authorization-services)、[Domain Model](domain_model_v0_1.md#7-resource)。

`lib/acting_for.rb` の `ActingFor.authorize(...)` は薄いPublic Entry Pointに限定し、Public入力のvalidation / normalizationは `ActingFor::Internal::Authorization` が担当する。

概念上の流れ：

```text
ActingFor.authorize(...)
        ↓
ActingFor::Internal::Authorization.call(...)
        ↓
Public input validation / normalization
        ↓
D216 Authorization core
```

Internal Authorizationが担当するPublic入力規則：

- `agent` はpersist済み `ActingFor::Agent`
- `principal` はpersist済み `ActiveRecord::Base` record
- `action` はString / Symbolのみ。SymbolはStringへ正規化
- `action` のnil / empty / whitespace-only / その他typeは `ActingFor::InvalidRequestError`
- `action` はtrim / downcaseしない
- `resource` は既存D032 / D201と同じ規則で `resource_type / resource_id` へ正規化
- `context` はHashのみ許可し、その他typeは `ActingFor::InvalidRequestError`
- Public入力objectを破壊しない
- Public入力不正を通常のdeny Decisionへ変換しない

構造上の方針：

- `lib/acting_for.rb` に非自明なvalidation / normalizationを集中させない
- `AuthorizationValidator` / `AuthorizationNormalizer` 等の追加Serviceは作らない
- Base Service / ApplicationServiceを追加しない
- validation順序や細かなprivate method構成をPublic contractにしない

`audit_context_keys` のvalidation / normalizationは本Decisionの実装単位に含めず、Audit authorization integration時に扱う。

このDecisionはPublic authorizeのvalidation / normalization責務を確定するものであり、AuditEvent保存・AuditPersistenceError・Audit Context selectionの実装には進まない。

## D218: Audit保存はInternal Authorizationの責務に含める

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済み。
- 関連文書：[Public API](public_api_v0_1.md#10-audit)、[Domain Model](domain_model_v0_1.md#14-auditevent)、[Gem Structure](gem_structure_v0_1.md#4-internal-authorization-services)。

Authorization実行時のAuditEvent保存は、別の `AuditRecorder` / `AuditService` 等へ分離せず、`ActingFor::Internal::Authorization` の責務に含める。

概念上の流れ：

```text
Delegation evaluation
        ↓
matching Delegation確定
        ↓
Decision生成
        ↓
AuditEvent保存
        ↓
Decision return
```

方針：

- Internal Authorizationがmatching Delegation集合を保持し、そのIDを `matched_delegation_ids` としてAuditEventへ保存する
- Public `ActingFor::Decision` へ `matched_delegation_ids` / `reason_code` / Audit用context等を追加しない
- Audit用情報はAuthorization内部の実装情報として扱う
- AuditEvent保存成功後にのみDecisionを返す
- AuditEvent保存失敗時はDecisionを返さず、既存D023 / D031どおり `ActingFor::AuditPersistenceError` をraiseする
- Audit保存失敗をdeny Decisionへ変換しない
- Audit保存専用の追加Service、Base Service、callback、event bus等はv0.1では導入しない
- AuditEvent保存時の具体的なprivate method構成はPublic contractにしない

`audit_context_keys` のvalidation / normalization / sanitized context生成は本Decisionでは実装詳細を確定せず、次のDecisionで別項目として扱う。

## D219: audit_context_keysの処理とsanitized_context canonicalization

- 日付：2026-09-18
- Status：**確定**。
- 根拠：ユーザー承認済み。
- 関連文書：[Public API](public_api_v0_1.md#10-audit)、[Domain Model](domain_model_v0_1.md#16-audit-contextの安全性)、[Gem Structure](gem_structure_v0_1.md#4-internal-authorization-services)、[Test Strategy](test_strategy_v0_1.md#8-auditevent--audit保存失敗-integration-test)。

`ActingFor.authorize(...)` の `audit_context_keys: []` はPublic Entry Pointから `ActingFor::Internal::Authorization` へそのまま渡し、Internal Authorizationがvalidation / normalizationと `sanitized_context` 生成を担当する。

既存D031・D044のAudit Context規則を実装境界としてそのまま維持する。

- `audit_context_keys` は `Array<Symbol>` のみ許可する
- nil、単一Symbol、String要素、String / Symbol混在Array等は `ActingFor::InvalidRequestError`
- 重複Symbolは許可し、内部で重複除去する
- built-in forbidden secret keyはContextに存在するかに関係なく、allowlistへ指定した時点で `InvalidRequestError`
- ContextはトップレベルSymbol keyとの完全一致だけで選択する
- String keyへの暗黙変換、indifferent access、nested path解釈は行わない
- 指定keyがContextに存在しない場合は無視する
- 選択可能valueはString / Integer / Float / BigDecimal / TrueClass / FalseClass / nilのみ
- Hash / Array / その他unsupported valueが選択された場合は `InvalidRequestError`
- BigDecimalはFloatへ変換せず、精度を失わない10進数Stringへ変換する
- 保存対象がない場合は `{}` とし、raw Contextへfallbackしない
- 呼び出し元の `context` / `audit_context_keys` は破壊しない
- Audit Sanitizer等の追加Serviceは作らず、Internal Authorization内で処理する

`sanitized_context` のcanonical keyは **String** とする。

```ruby
context: { amount: 100 }
audit_context_keys: [:amount]

# sanitized_context
{ "amount" => 100 }
```

key選択時はD031どおりSymbolで厳密比較し、選択後にAudit JSON objectへ保存するcanonical representationとしてString keyへ変換する。これにより、Authorization用Contextのkey semanticsは変更しない。

本Decisionは `audit_context_keys` と `sanitized_context` 生成までを確定する。AuditEvent INSERT、reason_code / matched_delegation_idsの保存、AuditPersistenceErrorの実装はD218に基づく後続実装単位で扱う。

