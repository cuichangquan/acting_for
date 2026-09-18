# ActingFor v0.1 Test Strategy Design

更新日：2026-09-18

**Step 8: Complete / Design finalized / Not implemented。** 本書をActingFor v0.1 Test Strategy Designの正本とする（[D029](DECISIONS.md#d029-step-8-test-strategy-design)）。Test Strategyの設計は完了したが、Testコードはまだ存在しない。Gem skeleton / Migration / Models / 最小Dummyは実装・検証済みだが、正式Minitest suiteは未実装。Gemは **Not released** であり、README Quick Startは実行できない。

[Domain Model](domain_model_v0_1.md)、[Public API](public_api_v0_1.md)、[Gem Structure](gem_structure_v0_1.md)の既存決定をTest上のAcceptance Criteriaへ対応付ける。実装詳細や未決定APIを追加確定するものではない。進捗は[PROGRESS](PROGRESS.md)、現在地点は[CURRENT_STATE](CURRENT_STATE.md)を参照。

## 1. Test Framework

v0.1では **Minitest** を正式採用する。Rails-nativeでRails標準のTest構成と自然に統合でき、`test/dummy` と相性がよい。v0.1に十分で、不要なTest Framework依存を増やさないためである。RSpecはv0.1では採用しない。

## 1.1 正式Test suiteの最初の実装単位（D221）

正式Minitest suiteは、まず共通実行基盤とUnit Testから実装する。

```text
test/
├── test_helper.rb
├── unit/
│   ├── decision_test.rb
│   └── constraint_evaluator_test.rb
└── integration/
    └── （後続実装）
```

`test/test_helper.rb` から最小 `test/dummy` Rails環境をloadし、Rails標準の `rails/test_help` を使う。新しいTest Framework依存は追加しない。`Rake::TestTask` を追加し、正式Test実行コマンドは `bundle exec rake test`、discovery patternは `test/**/*_test.rb` とする。

最初の実装対象は `ActingFor::Decision` と `ActingFor::Internal::ConstraintEvaluator` のUnit Testまで。`ActingFor.delegate(...)` / `ActingFor.authorize(...)` / AuditEvent persistence等のIntegration Testは次の実装単位へ分離し、CIにはまだ進まない。private methodを直接Test Contractにせず、Public behavior / observable behaviorを中心に検証する。

## 2. Unit Test / Integration Testの境界

| 種別 | 境界 | 主な対象 |
| --- | --- | --- |
| Unit Test | Rails / DBへの依存が小さいpure / internal logic | `ActingFor::Decision`、`ActingFor::Internal::ConstraintEvaluator` |
| Integration Test | Rails / ActiveRecord / DB / Engine / Public APIをまたぐ動作 | `ActingFor.delegate(...)`、`ActingFor.authorize(...)`、Delegation + ActiveRecord、AuditEvent persistence、Rails Engine、Migration、Zeitwerk / autoload、`test/dummy` |

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

D213により、将来の正式Unit Testでは上記に加えてDecisionが初期化後にfreezeされること、不正statusが `ArgumentError` になることを確認する。ただしconstructor自体をPublic API contractとして扱わないD050は維持する。この反映ではTestコードを実装しない。

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

D215のContext key規則も検証する。canonical String field `"amount"` は `context[:amount]` のみにmatchし、`context["amount"]` にはmatchしない。fieldをnested pathとして解釈せず、たとえば `"order.amount"` はトップレベルの `:"order.amount"` keyだけを参照する。field不存在・値nilは不成立とする。

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
- allow / require_approvalでは実際にmatchしたDelegation IDをすべて保存し、canonical representationとしてID昇順であることを確認する。ただしTestの意味論としてpriorityやprecedenceを順序に持たせない。
- 複数matchでは該当Delegationを追跡できること。
- ContextはFilter / Sanitizerを経由し、allowlist優先で必要最小限を保存する既存方針に従う。生のContextをそのまま保存する契約にしない。
- D219に従い、`audit_context_keys` はArray<Symbol>のみ、重複除去、forbidden secret key拒否、missing key無視、unsupported value拒否、BigDecimalの精度保持String化を検証する。Symbol keyで選択し、sanitized_contextのcanonical keyがStringになることも検証する。
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

D220に従い、`AuditEvent.create!` が `ActiveRecord::ActiveRecordError` をraiseした場合だけ `ActingFor::AuditPersistenceError` へwrapされcauseが保持されることを確認する。Audit属性組み立て等の非persistence errorを一律AuditPersistenceErrorへ変換しないことも境界として確認する。

## 9. Migration / Engine Integration Test

`test/dummy` を使い、Rails標準のEngine / Migration機構で正常に統合できることを検証する。

- `ActingFor::Engine` boot。
- Zeitwerk / autoload。
- `isolate_namespace ActingFor` とHost Applicationとのnamespace衝突防止。
- Migration適用とActiveRecord Modelとの接続。
- `acting_for_agents`、`acting_for_delegations`、`acting_for_audit_events` の作成・利用。

Step 8時点ではDB columnの最終型を固定しなかったが、後続D043・D051・D052で確定した範囲はDomain Model正本に従う。Migration方針は後続D060〜D066と[Gem Structure第6節](gem_structure_v0_1.md#6-migration--db-table-names)に従う。Migration実コード・task・filenameは後続工程で確定・実装済み。Docker runtime verificationの結果は[DECISIONS](DECISIONS.md)を参照。Configuration / Initializerや独自Generatorの追加を前提にしない。

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
| Delegation | Public入力validation・normalization・非破壊・永続化と、全matching条件を満たす委任のみ適用すること | 7・16 / Integration |
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

[PROJECT 4.3のDefinition of Done](PROJECT.md#43-v01全体のdefinition-of-done)は、Step 8およびD057〜D059時点では全体がProposalだったが、後続D076で整合する範囲を正式決定へ更新した。より広い未承認条件はProposalのまま残す。必須自動Test・正式Ruby / Rails / PostgreSQL CI matrix・RuboCopの成功、Runnable Quick Startの実行可能性、README / Security Boundary / Responsibility Boundaryと実装の一致、確定機能の実装完了、GitHub Release Notesを公開できる状態を完成条件とし、v0.1対象外機能は含めない。新しい未承認Test項目は追加しない。

後続D067・D072・D073により、正式CI基盤はGitHub Actions、triggerはPull Requestとmain branchへのpush。少なくとも正式Ruby / Rails matrix・PostgreSQL・既存の必須Test・RuboCopを検証し、RuboCop violationはCI failureとする。scheduled / cron CI、独自Style Guide、大量の独自Cop、大規模custom rule set、複数plugin群はv0.1必須でない。

RuboCop version / config / rule set / plugin、rake task名、workflow YAML・job構成・cache・具体的CI command・service設定、Quick Start最終コード、Release Notes本文、CHANGELOG方式、release / gem push / GitHub Release / tagの自動化は未決定。Release Notes公開先は後続D074でGitHub Releasesに確定し、D075で最初のversion `0.1.0` / tag `v0.1.0` を確定した。設定・本文・Test / CI実装は作成しない。

Step 8時点で保留していたException / Audit Context、Resource / Delegation、Agent validation、AuditEvent詳細は後続D031〜D034で確定した。今回Test Strategyの再構築やTestコード実装は行わず、Delegation Public APIの具体的なAcceptance Criteriaは後続D190〜D212に基づく第16節に反映する。後続D049〜D056でcaller authorizationのHost境界、Decision Public APIの4項目への限定・constructor非保証、3 Modelの主要DB型・NULL・CHECK・主要index・bigint主キー、DelegationのModel-level immutability、revoke!の並行実行契約、Constraint complexity非提供、AuditEventのModel-level append-onlyを確定した。詳細schemaの正本は[Domain Model第17節](domain_model_v0_1.md#17-v01-テーブル構成)。Migration / Modelsは実装・Docker検証済み。正式Test suiteは未実装で、Authorization等の未対象の実装詳細は後続工程で扱う。

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

## 16. Delegation Public API Test as Executable Documentation

**D208：Public API Test = Executable Documentation。** 将来の正式Minitest suiteでは、`ActingFor.delegate(...)` / `ActingFor.authorize(...)` を中心に、利用者が読める仕様書としてテストを書く。以下はD190〜D212に基づくIntegration TestのAcceptance Criteriaであり、今回Testコードは作成しない。入力仕様の正本は[Public API第9節](public_api_v0_1.md#9-delegation-api)。

テスト名は許可・拒否条件が理解できる英語名とする。たとえば `delegate accepts a persisted agent`、`delegate rejects an unsaved agent`、`delegate converts symbol action to string`、`delegate does not mutate constraints passed by the caller`。正常系と間違いやすい異常系を明示し、Internal class名・private method依存を最小化する。1テストへ大量の仕様を詰め込まず、コメントよりテスト名・入力・期待結果で伝える。READMEの将来の利用例とPublic API Testを乖離させない。

以下の「拒否」は `ActingFor::InvalidRequestError` を意味する。原則1テスト1仕様違反とし、他の入力は正常にする。

### Agent / Principal

| 対象 | 入力 | 期待結果 |
| --- | --- | --- |
| Agent | persisted ActingFor::Agent | success。完全class一致ではなくis_a?で判定 |
| Agent | nil / 別class / unsaved Agent | それぞれ拒否 |
| Principal | persisted ActiveRecord record | success。Rails polymorphic associationで保存・取得 |
| Principal | nil / non-ActiveRecord object / 単なるid付きobject / unsaved ActiveRecord record | それぞれ拒否 |

### Action

| 入力 | 期待結果 |
| --- | --- |
| `"purchase"` | success |
| `:purchase` | `"purchase"` に正規化 |
| nil / `""` / `"   "` / 非String・Symbol | それぞれ拒否 |
| `" purchase "` | trimせず同じStringを保存 |

### Resource

| 入力 | 期待するtype / IDまたは失敗 |
| --- | --- |
| nil | nil / nil |
| ActiveModel-style Class | model_name.name / nil |
| ActiveModel-style Instance | class.model_name.name / id.to_s |
| model_nameなしClass | 拒否 |
| 必要interfaceなしInstance | 拒否 |
| idがnil | 拒否 |
| id.to_sが空文字 | 拒否 |
| String / Hash direct identifier | それぞれ拒否 |

非ActiveRecordのResource instanceでも必要interfaceがあれば成功するケースを設け、`persisted?` を要求しないことを読み取れるTestにする。to_model / to_param / GlobalID / polymorphic associationも要件に追加しない。

### Effect

| 入力 | 期待結果 |
| --- | --- |
| `"allow"` / `:allow` | success / `"allow"` |
| `"require_approval"` / `:require_approval` | success / `"require_approval"` |
| nil / `"deny"` / `:deny` | それぞれ拒否 |
| 大文字 / 前後空白 / `"require-approval"` / 未知値 / 不正type | それぞれ拒否。trim / downcase / alias変換なし |

### Constraints

正常入力例（テスト実装ではなく仕様の入力値）：

```ruby
[
  { field: :amount, operator: :lte, value: 10_000 }
]
```

保存後のcanonical form：

```ruby
[
  { "field" => "amount", "operator" => "lte", "value" => 10_000 }
]
```

| ケース | 期待結果 |
| --- | --- |
| 省略 / 空Array | 条件なしとしてsuccess |
| Array以外 / nil / Constraint要素がHash以外 | それぞれ拒否 |
| key不足 / extra key / 非String・Symbol key | それぞれ拒否 |
| String・Symbol keyの正規化後duplicate | 拒否。たとえばfieldと"field"の併存 |
| field空文字 / field不正type | それぞれ拒否 |
| operator不正type / 未知値 | それぞれ拒否 |
| eqのString / Integer / true / false | 各型でsuccess |
| eqの不正value型 | 拒否 |
| lt / lte / gt / gteのInteger | 各operatorでsuccess |
| lt / lte / gt / gteの非Integer | 各operatorで拒否。数値String・Floatも変換しない |
| inのString / Integer / true / falseを含むArray | success |
| inの非Array / Array要素の不正型 | それぞれ拒否。Symbol等も変換しない |
| `field: "   "` | 許可。non-emptyでありnon-blankを要求しない |
| `operator: "in", value: []` | 許可 |
| `operator: "in", value: [1, 1, 2]` | 許可。dedup / sortせず順序・重複を維持 |

field / operatorはSymbolのみString化し、trim / downcase / field命名regex / 意味的な有用性判定を追加しない。入力非破壊も個別に確認する：元constraints Array、元Constraint Hash、in value Arrayの内容を変更しない。

### expires_at

| 入力 | 期待結果 |
| --- | --- |
| nil | success |
| future Time | success |
| future ActiveSupport::TimeWithZone | success |
| current timeと同時刻 / past | それぞれ拒否 |
| String / Date / DateTime / Integer | それぞれ拒否 |

Rails time helperで基準時刻を固定する。ActingFor側でparse / convert / timezone変換 / 丸めをしない方針を維持する。正常なTime系objectはそのままActiveRecordへ渡すという境界と、DBの保存表現を区別する。

### Return / Persistence

- 正常時はpersist済みActingFor::Delegationを返す。
- 各delegate callは独立した新規Delegationを作る。同じ内容の2回の呼び出しでもdedup / upsertしない。
- revoked_atはnilで作成する。

### Error Boundary

| 原因 | 期待結果 |
| --- | --- |
| Public入力不正 | ActingFor::InvalidRequestError |
| canonical化後のModel validation failure | ActiveRecord::RecordInvalidを一律InvalidRequestErrorへwrapしない |
| DB failure | 一律InvalidRequestErrorへwrapせず原則そのまま伝播 |

Exception classはPublic contractだが、message全文一致と複数不正時のvalidation順序はTest contractにしない（D210・D211）。内部の検出順序やprivate methodへ依存せずPublic behaviorを検証する。
