# ActingFor v0.1 Test Strategy Design

更新日：2026-09-17

**Step 8: Complete / Design finalized / Not implemented。** 本書をActingFor v0.1 Test Strategy Designの正本とする（[D029](DECISIONS.md#d029-step-8-test-strategy-design)）。Test Strategyの設計は完了したが、Testコードはまだ存在しない。Gemも **Not implemented / Not released** であり、README Quick Startは実行できない。

[Domain Model](domain_model_v0_1.md)、[Public API](public_api_v0_1.md)、[Gem Structure](gem_structure_v0_1.md)の既存決定をTest上のAcceptance Criteriaへ対応付ける。実装詳細や未決定APIを追加確定するものではない。進捗は[PROJECT](PROJECT.md#5-進行順)を参照。

## 1. Test Framework

v0.1では **Minitest** を正式採用する。Rails-nativeでRails標準のTest構成と自然に統合でき、`test/dummy` と相性がよい。v0.1に十分で、不要なTest Framework依存を増やさないためである。RSpecはv0.1では採用しない。

## 2. Unit Test / Integration Testの境界

| 種別 | 境界 | 主な対象 |
| --- | --- | --- |
| Unit Test | Rails / DBへの依存が小さいpure / internal logic | `ActingFor::Decision`、`ActingFor::Internal::ConstraintEvaluator` |
| Integration Test | Rails / ActiveRecord / DB / Engine / Public APIをまたぐ動作 | `ActingFor.authorize(...)`、Delegation + ActiveRecord、AuditEvent persistence、Rails Engine、Migration、Zeitwerk / autoload、`test/dummy` |

`ActingFor.authorize(...)` はAuthorizationからAuditEvent保存まで含むため、中心的なIntegration Test対象とする。`ActingFor::Internal::Authorization` のprivate / internal method単位の仕様をTest Contractにせず、Public behaviorを検証する。

## 3. Dummy Rails Application

`test/dummy` は、ActingForを実際のRails Applicationへ組み込んだ状態を再現する **最小Host Application** とする。

- 検証対象：Rails Engine integration、ActiveRecord models、Migration、Zeitwerk / autoload、`ActingFor.authorize(...)`、Host Principal / Host Resourceとの連携。
- 含めないもの：本格的なEC機能、Approval Workflow、MCP Server、OAuth / OIDC、UI、Controller E2E、複雑なBusiness Logic。

```text
test/dummy = minimal Rails integration host
           ≠ sample product
           ≠ demo application
```

Host側の停止・実行可能・Approval Workflowへ渡す境界は最小の統合シナリオで検証し、業務製品やWorkflow自体は実装対象にしない。

## 4. Decision Unit Test

3つのstatusそれぞれで、確定済みの4つのPublic APIを検証する。

| decision.status | decision.allowed? | decision.denied? | decision.approval_required? |
| --- | --- | --- | --- |
| `:allow` | `true` | `false` | `false` |
| `:deny` | `false` | `true` | `false` |
| `:require_approval` | `false` | `false` | `true` |

必須Security Invariantは **`require_approval != allow`**。特にstatusが `:require_approval` の場合、`allowed? == false`、`approval_required? == true` を必須Testとする。D050によりconstructorはPublic APIとして保証しない。Public利用ではauthorizeの戻り値を取得し、Unit Test内部の生成方法は固定しない。

## 5. ConstraintEvaluator Unit Test

`ActingFor::Internal::ConstraintEvaluator` では以下を最低限検証する。評価ルールは[Domain ModelのConstraint](domain_model_v0_1.md#8-constraint)を維持する。

| ケース | 検証する挙動 |
| --- | --- |
| single constraint pass / fail | Contextに対する単一条件の成立・不成立 |
| multiple constraints AND | すべて成立した場合のみ成立。1つでも不成立なら不成立 |
| boundary value | 条件内・境界値・条件外をoperatorの意味に従って評価 |
| missing Context field | 必要field不足では不成立 |
| invalid / unevaluable constraint | 不正・評価不能なConstraintを成立扱いにしない |
| type mismatch | 暗黙の型変換をせず、不成立 |
| nested Context非対応 | nested object accessで条件を成立させない。トップレベルKeyのみ参照 |
| fail closed | 権限条件を確認できない場合に成立扱いにしない |

Delegation lookup、effect precedence、final Decision生成、AuditEvent保存はこのUnit Testの対象外とする。内部method名、constructor形式、内部class構造をTest Strategy上の契約として固定しない。評価不能な条件とSystem failureの境界は第12節に従う。

## 6. ActingFor.authorize Integration Test

以下を最低限のシナリオとし、Public APIの結果と永続化を検証する。

| シナリオ | 期待するPublic behavior |
| --- | --- |
| allow | `:allow` のDecisionとAuditEvent保存 |
| deny | `:deny` のDecisionとAuditEvent保存 |
| require_approval | `:require_approval` のDecisionとAuditEvent保存。自動実行不可 |
| matching Delegationなし | deny |
| allowとrequire_approvalがmatch | require_approvalを優先 |
| expired / revoked Delegation | matching対象外 |
| Action / Resource / Constraint mismatch | matching対象外 |
| 通常のAuthorization不成立 | Decisionを返す。有効なmatchがなければdeny |
| API misuse / internal error | Exception。denyへ変換しない |

matching対象外のDelegationがあるだけで常にdenyになるわけではない。他に有効なmatchがあるかも評価し、第7節の結果に従う。Decisionを返すケースはAudit保存の成功を前提とし、保存失敗時は第8節に従う。

## 7. Delegation Matching Integration Test

**Agent / Principal / Action / Resource / Expiration / Revocation / Constraintの全条件** を満たすDelegationだけがmatchする。各条件について、1つでも満たさなければそのDelegationがmatchしないことを検証する。Resource matchingはConstraint evaluationと分け、[既存Resource設計](domain_model_v0_1.md#7-resource)に従う。

Expirationは時刻を固定して境界を検証する。他のmatching条件も満たすことを前提とする。

| 状態 | 有効性 |
| --- | --- |
| `expires_at == nil` | 期限なし |
| `expires_at > now` | active |
| `expires_at == now` | expired |
| `expires_at < now` | expired |
| revoked Delegation | matching対象外 |

複数Delegationがmatchした場合は **`require_approval > allow`**。allowのみならallow、0件ならdenyとする。結果がDB id、created_at順、作成順、specificityに依存しないことも検証する。explicit deny Delegationやspecificityによるoverrideは導入しない。

## 8. AuditEvent / Audit保存失敗 Integration Test

AuditEventは `ActingFor.authorize(...)` 経由で検証する。allow / deny / require_approvalのすべてで自動保存され、別途audit呼び出しが不要であることを確認する。

追跡対象はAgent、Principal、Action、Resource、Decision、`matched_delegation_ids`、sanitized Context、timestamp。既存Audit設計に従い、Agentのid / identifier、PrincipalとResourceの識別情報、判定と記録時刻を追跡できることを検証する。

- matching Delegationなしのdenyでは `matched_delegation_ids = []`。
- 複数matchでは該当Delegationを追跡できること。
- ContextはFilter / Sanitizerを経由し、allowlist優先で必要最小限を保存する既存方針に従う。生のContextをそのまま保存する契約にしない。
- 記録するのはAuthorization Decision。Business operation success / failureは対象外。
- Step 8時点で未決定だったAudit Context選択APIは後続D031、reason_code正式一覧とAuditEvent詳細はD034で確定した。現行仕様は各正本を参照し、Testへの詳細反映は後続工程で確認する。

### Audit保存失敗

**必須Integration Test。** 元のAuthorization結果がallow / deny / require_approvalのどれでも、AuditEvent保存失敗時には以下を確認する。

```text
Decisionを返さない
権限不足のdenyへ変換しない
Exceptionで中断する
Business Logicへ進ませない
```

AuthorizationとしてのdenyとAudit / System failureは異なる。Audit保存失敗はSystem Errorであり、Step 8時点で未固定だったclassは後続D031のAuditPersistenceErrorに従う。lower-level persistence exceptionのcauseを保持する。

## 9. Migration / Engine Integration Test

`test/dummy` を使い、Rails標準のEngine / Migration機構で正常に統合できることを検証する。

- `ActingFor::Engine` boot。
- Zeitwerk / autoload。
- `isolate_namespace ActingFor` とHost Applicationとのnamespace衝突防止。
- Migration適用とActiveRecord Modelとの接続。
- `acting_for_agents`、`acting_for_delegations`、`acting_for_audit_events` の作成・利用。

DB columnの最終型、Migration実装詳細、Migration taskの具体的名称は固定しない。Configuration / Initializerや独自Generatorの追加を前提にしない。

## 10. Host Authorization Boundary

Dummy Rails AppによるIntegration Testで、次の境界を検証する。

```text
Agentの実効権限
= Principal自身の現在の権限 ∩ Delegationされた権限
```

| Host Authorization | ActingFor | Host側の結果 |
| --- | --- | --- |
| deny | allowでも | Business Logicへ進まない |
| allow | allow | 実行可能 |
| Principal自身に権限なし | require_approvalでも | STOP |
| Principal自身に権限あり | require_approval | 自動実行せずHost Approval Workflowへ |

この表は両認可の論理的な境界であり、Hostがdenyした後に必ずActingForを呼ぶ順序を要求しない。Delegation作成後にPrincipalが権限を失ったケースも検証し、古いDelegationだけを根拠に実行しないことを確認する。require_approvalもPrincipalの権限を拡張しない。

ActingFor CoreはPundit、CanCanCan、Action Policy、その他Host Authorization libraryを直接呼ばない。特定libraryのAPIをTest Contractにせず、Hostの現在権限と委任認可の責任分界を検証する。

## 11. Context Trust Boundary

Integration Testで、Contextの正確性はHost Application、渡されたContextによるConstraint評価はActingForの責務であることを検証する。

Hostは値を確定してからContextとして渡す。ActingFor自身はProductをDBから再取得したり、商品価格・Resource所有者を確認したり、Agent申告値とDB値を比較したり、外部Serviceで値を検証したりしない。Hostが確定したContextを使った評価を検証する。

| 入力 | 期待する挙動 |
| --- | --- |
| `context: "hello"` | 形式不正のためException |
| `context: {}` で必要field不足 | Constraint不成立。そのDelegationはmatchしない |
| 必要field不足の結果、有効なmatching Delegationなし | deny |

v0.1では `trusted_context:`、`untrusted_context:`、`TrustedContext`、`VerifiedContext`、`ContextVerifier` を導入せず、Test Contractにも含めない。

## 12. Fail Closed

fail-closedは横断的Security RequirementとしてUnit / Integration双方で検証する。

Delegationなし、expired、revoked、Action mismatch、Resource mismatch、Constraint mismatch、missing Context field、type mismatch、invalid constraintを根拠にallowしない。ConstraintのUnit Testでは不成立、Integration Testでは当該Delegationがmatchせず、有効なmatchがなければdenyとなることを確認する。

```text
権限を明確に確認できない → allowしない
Authorization failure → Decision(:deny)
System failure → Exception
```

ここで `Decision(:deny)` は結果の概念表記であり、constructorを定めるものではない。API misuse、configuration error、internal error、Audit保存失敗をdenyへ変換しない。configuration errorの検証方針は、新しいConfiguration APIの提供を意味しない。

## 13. v0.1 Acceptance Criteriaとの対応

[PROJECT 4.2](PROJECT.md#42-必須機能と項目別の完了条件)の必須機能を、以下のTest上のAcceptance Criteriaへ対応付ける。設計確定であり、Test実装完了・合格を示さない。

| 必須機能 / 横断的要件 | Test上のAcceptance Criteria | 対応節 / 種別 |
| --- | --- | --- |
| Agent representation | Hostが認証・解決したAgentをPrincipalと別主体として受け取り、同じPrincipalでも異なるAgentを区別する | 3・7 / Integration |
| Delegation | Agent / Principal / Action / Resourceを含む全matching条件を満たす委任のみ適用する | 7 / Integration |
| Authorization | 3つのDecision、一致なしdeny、require_approval優先、DecisionとExceptionの境界 | 4・6・7 / Unit・Integration |
| Constraint | Contextに対する条件内・境界値・条件外、AND、field不足、型不一致、不正・評価不能、nested非対応 | 5・6・11 / Unit・Integration |
| Expiration / Revocation | 期限なし・期限内、期限とnowの一致・期限切れ、取消済みを区別する | 7 / Integration |
| Approval | require_approval != allow、allowed?はfalse、Host側で自動実行しない | 4・6・10 / Unit・Integration |
| Audit | 全Decisionの自動記録、追跡情報・sanitized Context、一致なしの空配列、複数match、全結果の保存失敗時Exception | 8 / Integration |
| Rails integration | 最小Hostへの導入、Engine boot、Migration、autoload、namespace、Delegation・Authorization・Auditの連携 | 3・6・9 / Integration |
| Host Authorization Boundary | Principalの現在権限との積集合、委任後の権限喪失、Approvalによる権限拡張なし | 10 / Integration |
| Context Trust Boundary | Hostが値を確定、CoreはConstraint評価、形式不正と必要field不足の区別 | 11 / Integration |
| fail-closed | 権限を確認できなければallowしない。System failureはException | 5〜12 / Unit・Integration |

## 14. 未決定事項と完了状態

[PROJECT 4.3のDefinition of Done](PROJECT.md#43-v01全体のdefinition-of-done)全体は引き続き **Proposal / 提案**。Ruby / Rails・CI matrixはD046、LicenseはD048で確定した。static analysis、Runnable Quick Start、Release notes等は未決定であり、全体の完了条件は追加確定しない。

Step 8時点で保留していたException / Audit Context、Resource / Delegation、Agent validation、AuditEvent詳細は後続D031〜D034で確定した。今回Test Strategyの再構築やTestコード実装は行わず、後続仕様のTestへの反映は別途確認する。後続D049〜D056でcaller authorizationのHost境界、Decision Public APIの4項目への限定・constructor非保証、3 Modelの主要DB型・NULL・CHECK・主要index・bigint主キー、DelegationのModel-level immutability、revoke!の並行実行契約、Constraint complexity非提供、AuditEventのModel-level append-onlyを確定した。詳細schemaの正本は[Domain Model第17節](domain_model_v0_1.md#17-v01-テーブル構成)。実装は引き続きNot implemented。 Migration実コード・task名、内部method・constructor・class構造、具体的validation / callback / queryコードは引き続き未決定。

Step 8は **Complete / Design finalized / Not implemented**。次工程の番号・順序は新たに決めず、Security Model Design等をStep 9に採番しない。Gem / Test / Migration / Model / Service / Decision / AuditEvent / Generator / Dummy Rails Appの実装、Configuration追加、CI構築、releaseには進まない。

## 15. 後続決定に対応する検証設計（D035・D043〜D046）

v0.1の正式対応DB adapterは **PostgreSQLのみ**。他adapterを意図的に排除する設計にはしないが、正式サポート・動作保証対象外とする。CI / Integration Testで検証したDBだけを正式サポートとする（D045）。

正式サポート対象は **Ruby 3.4 / 4.0、Rails 8.0 / 8.1**。Ruby 3.3以下、Rails 7.2以下は対象外。正式CI matrixは以下の4組で、DBはいずれもPostgreSQL。正式サポートはこのmatrixで実際に検証した組み合わせのみ（D046）。

| Ruby | Rails | DB |
| --- | --- | --- |
| 3.4 | 8.0 | PostgreSQL |
| 3.4 | 8.1 | PostgreSQL |
| 4.0 | 8.0 | PostgreSQL |
| 4.0 | 8.1 | PostgreSQL |

Rails 8.0のSecurity Support終了時期が近いため、v0.1リリース直前にRails公式support statusを再確認する。Ruby公式support statusもリリース直前に再確認する。これは設計上の対象であり、現在検証済み・リリース済みという意味ではない。CIはまだ実装しない。

時刻取得は内部の共通境界 `ActingFor.current_time` に集約し、通常は `Time.current` を返す。Expiration / Revocation / Authorization等は直接 `Time.current` を呼ばない。v0.1ではClock差し替えPublic API（`ActingFor.clock =` / `ActingFor.reset_clock!`）を提供しない。TestではRails time helper（`travel_to` 等）を使う（D035）。

Integration Testではbigint / UUID等の異なるPrincipal ID型について、stringのDelegation#principal_idを介したassociationとAuthorization動作を確認する。Model / Migration検証はD043のjson型・default・NOT NULLとAgent string型・unique indexに従い、AuditではBigDecimalの10進数String保存による精度維持を確認する設計とする。これは検証方針だけであり、Test / Dummy App / Migration / CI workflowを実装しない。
