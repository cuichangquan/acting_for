# ActingFor 決定記録

更新日：2026-09-17

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

## 追記する際の項目

新しい決定には、次を記録する。

1. IDと短いタイトル
2. 日付と状態
3. 決定または提案した内容
4. その理由
5. 関連するファイル・Issue
6. 残っている未決定事項

ユーザーが明示的に採用したら「提案」を「確定」に更新し、採用日を記録する。後で変更した場合も、以前の理由を消さずに変更履歴を残す。
