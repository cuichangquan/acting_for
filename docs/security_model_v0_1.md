# ActingFor v0.1 Security Model Design

更新日：2026-09-17

**Security Model Design: Complete / Design finalized / Not implemented。** 本書をActingFor v0.1 Security Model Designの正本とする（[D030](DECISIONS.md#d030-v01-security-model-design)）。Gem全体は **Not implemented / Not released**。Quick Startはまだ実行できない。

Step 8 Test Strategy完了後の設計としてSecurity requirementを確定する。Step 1〜8の既存決定を変更せず、工程番号は追加しない。D030時点では具体的実装や新しいPublic APIは決めなかった。後続決定D031〜D048で確定した詳細を本書にも反映し、未決定の実装方式は引き続き固定しない。進捗は[PROJECT](PROJECT.md#5-進行順)を参照。

## 1. 目的とThreat Model Boundary

中心目的は次のとおり。

> Host Applicationによって認証・解決されたAgentが、Principalから委任された範囲を超えて操作することを防ぐ。

ActingForは **Principal → Agent** のDelegation-based Authorizationを安全に評価する。主に防ぐ対象は、認証済み・解決済みAgentによる委任範囲を超えた操作である。

以下はActingFor Coreの直接責務外であり、本書はこれらを安全にする保証ではない。

- Agent Authenticationそのものの突破
- OAuth / OIDC自体の脆弱性
- MCP自体のセキュリティ
- Host Application自体の完全な乗っ取り
- DB管理権限を攻撃者が完全に掌握した状態
- Business Operationそのものの安全性

## 2. Trust Boundary

```text
External Agent / Request（untrusted）
        ↓
Host Application
  Authentication
  Agent Resolution
  Principal Resolution
  Resource確定
  Context確定
        ↓
──────── Trust Boundary ────────
        ↓
ActingFor
  Delegation / Constraint / Expiration / Revocation / Authorization
```

ActingForはAgent / Principal / Resource / Contextについて、Host Applicationが認証・解決・確定した値を受け取る。Agentの本人確認、Product価格の再取得、Resource所有者の再確認、Agent申告値とDB値の照合はActingForの責務ではない。

Hostは業務上重要なAgent申告値を無検証で渡さず、信頼できる情報源等で確認・確定する。ActingForは値の真偽を確認せず、受け取ったContextでConstraintを評価する。API形式の確認・Constraint評価と、Context値の正確性は別の責務である。[Context Trust Boundary](public_api_v0_1.md#13-context-trust-boundary)（D025）とAgent Resolution（D026）を維持する。

## 3. Security Invariant 1: Fail Closed

```text
権限を明確に確認できない → allowしない
Authorization failure → Decision(:deny)
System / API failure → Exception
```

Delegationなし、expired、revoked、Action mismatch、Resource mismatch、Constraint mismatch、必要Context不足、type mismatch、invalid / unevaluable Constraintを根拠にallowしてはいけない。

[Delegation matching](domain_model_v0_1.md#11-authorization)（D014）どおり、不成立のDelegationはmatchさせない。他に有効なmatching Delegationがあれば既存ルールで評価し、有効なmatchがなければdenyとする。複数一致時の `require_approval > allow` は維持する。不成立のDelegationが1件あるだけで全体をdenyにする規則は追加しない。

System failureを単なるdenyへ潰さない。API misuse、configuration error、internal error、Audit保存失敗はExceptionとする（D019・D023・D029）。Context形式不正はException、形式が有効でも必要field不足ならConstraint不成立というD025の区別を維持する。`Decision(:deny)` は概念表記であり、constructorの決定ではない。

## 4. Security Invariant 2: Privilege Escalation Prevention

```text
Effective Agent Authority
= Principal Current Authority ∩ Delegated Authority
```

Principal自身に現在権限がなければAgentも実行できない。DelegationはPrincipal自身の権限を拡張せず、`require_approval` も権限昇格ではない。Delegation作成後にPrincipalが権限を失った場合、古いDelegationだけでは実行できない。

Principalの現在権限を実行時にも確認するのはHost Applicationの責務。Host AuthorizationとActingFor Authorizationの両方を満たしてBusiness Logicへ進む。CoreはPundit等を直接呼ばず、ActingForのallowだけでアプリ全体の最終認可とはしない。[Existing Authorization Integration](public_api_v0_1.md#12-existing-authorization-integration)（D024）を維持する。`require_approval != allow` であり、Approval WorkflowはHostが担当する。

## 5. Security Invariant 3: Decision Request Binding

Authorization Decisionは、その判定時点の **Agent / Principal / Action / Resource / Context** の組み合わせに対する結果である。古いDecisionを別操作へ流用せず、再利用可能なAuthorization Tokenとして扱わない。

Agent / Principalの組み合わせ、Action、Resource、Context、Delegation状態、Principalの現在権限、その他Authorization判断に影響する状態が変わった場合は再Authorizationが必要である。

```text
amount: 8_000 → allow
amountを80_000へ変更 → 古いallowを使わない → 再authorize
```

これは再評価を求めるSecurity requirementであり、Decisionをbindingするtokenや新しいPublic APIを導入する決定ではない。

## 6. Security Invariant 4: Audit Integrity

Authorization Decisionは、対応するAuditEventの保存に成功した場合のみ呼び出し元へ返せる。

```text
Authorization
    ↓
Decision生成
    ↓
AuditEvent保存
    ↓ 成功
Decisionを返す
```

Audit保存失敗時は **Decisionを返さず、denyへ変換せず、ActingFor::AuditPersistenceErrorで中断し、Business Logicへ進ませない**。後続決定D031によりlower-level persistence exceptionをwrapし、Rubyのcauseを保持する。元のAuthorization結果がallow / deny / require_approvalのどれでも同じである（D022・D023・D029）。

Auditはauthorize内部で自動記録する。記録対象はAuthorization Decisionであり、Business Operationの成功・失敗ではない。[既存Audit仕様](public_api_v0_1.md#10-audit)を維持する。

## 7. Security Invariant 5: Audit Data Confidentiality

```text
Raw Context → audit_context_keys allowlist + built-in validation → AuditEvent
```

Raw Contextを保存対象へのfallbackにしてはいけない。後続決定D031により `audit_context_keys: []` をdefaultとし、明示allowlistだけを保存する。省略時・対象なしは `{}`。Secretを無条件保存せず、TokenやAPI Keyを保存しない。

`Array<Symbol>`のみを許可し、重複Symbolは除去、ContextのトップレベルSymbol keyと完全一致で選択する。String変換・indifferent access・nested path解釈は行わず、存在しないkeyは無視する。選択valueはString / Integer / Float / BigDecimal / TrueClass / FalseClass / nilのみ。unsupported valueはsilent ignoreせず `ActingFor::InvalidRequestError`。

forbidden secret keysは `:password` / `:password_confirmation` / `:token` / `:access_token` / `:refresh_token` / `:api_key` / `:secret` / `:client_secret` / `:credential`。allowlistへ指定した時点でInvalidRequestError。完全一致のみで、substring / regex / 推測による判定はせず、`:token_count` は禁止keyではない。Hostは別名keyを含め機密情報を選択しない。

v0.1ではcustom Audit Filter / Sanitizer、Proc、callback、sanitizer class、global allowlist config、initializer設定を提供せず、選択APIはaudit_context_keysのみ。[正式仕様](public_api_v0_1.md#10-audit)に従う。HostによるContext値の確認と、Audit用の項目選択は異なる責務である。

## 8. Security Invariant 6: Delegation Tamper Resistance

作成済みDelegationの認可内容を直接書き換えない。既存のimmutable方針（D014・D021）をSecurity Invariantとする。

```text
old Delegation → revoke
new authority → create new Delegation
権限変更 = revoke + create
```

過去の権限状態を追跡しやすくし、Auditとの整合性を保ち、後からDelegation内容を書き換えるリスクを抑える。通常操作でhard deleteを前提としない。後続決定D032のPublic入力validationを適用するが、immutableを強制するcallback等の具体的実装は決めない。

## 9. Replay / Duplicate Request Boundary

同一Business Operationの二重実行防止はHost Applicationの責務。ActingForはidempotency key、Payment duplicate prevention、同一API requestの再送防止、Business Operationのexactly-once保証を担当しない。

ActingForの責務は「この操作を実行してよいか」のAuthorizationまでである。

## 10. Delegation Creation / Revocation Protection

Delegationを誰でも作成・revokeできてはいけない。誰が作成・revokeしてよいかを認証・認可するのはHost Applicationの責務である。

設計上の `ActingFor.delegate(...)` や `delegation.revoke!` もcaller Authentication / Host Authorizationを代替しない。[Delegation API](public_api_v0_1.md#9-delegation-api)（D021・後続D032）に従う。全引数・default・validationとdelegate!非提供はD032で確定。caller authorizationの具体APIは未決定。

## 11. Principal / Agent Binding

Authorizationは明示されたagent + principalの組み合わせに対して評価する。別PrincipalのDelegationを流用せず、同じAgentでもPrincipalが違えば別委任として扱う。Principal取り違えによる権限逸脱を許さない。既存Delegation matchingのAgent一致・Principal一致を維持する。

後続決定D033によりAgent identifierはwhitespaceを一切含まない1..255文字のnon-blank Stringとし、暗黙変換・trim・downcaseを行わない。case-sensitive exact identityをActiveRecord validation + DB unique indexで保証する。nameは任意・非一意で、指定時はnon-blank String / 1..255文字。これらのModel validationからDB length constraintを追加決定しない。

## 12. Time / Expiration Trust Boundary

Expiration判定にAgentや外部callerから渡された任意時刻を信頼して使用せず、ActingFor側の信頼できる現在時刻を使う。Agentの時刻偽装によってexpired Delegationをactiveにしてはいけない。

既存の `expires_at > current_time` を有効とする境界を維持し、`expires_at == current_time` はexpiredとする。期限なし・revokedの扱いも[既存設計](domain_model_v0_1.md#10-expiration--revocation)に従う。

時刻取得は内部の共通境界 `ActingFor.current_time` に集約し、通常は `Time.current` を返す。Expiration / Revocation / Authorization等は直接 `Time.current` を呼ばない。v0.1ではClock差し替えPublic API（`ActingFor.clock =` / `ActingFor.reset_clock!`）を提供しない。TestではRails time helper（`travel_to` 等）を使う（D035）。管理されたTest環境で時刻を固定する[Step 8の検証方針](test_strategy_v0_1.md#7-delegation-matching-integration-test)と、外部callerの任意時刻を信頼しない要件は両立する。

## 13. TOCTOU Boundary

Authorization DecisionとBusiness Logic実行の完全な原子性は、ActingFor単体では保証しない。

Host Applicationは重要操作で実行直前にauthorizeし、古いDecisionを使い回さない。Delegationがrevokeされた場合、Principal権限が変わった場合、Resource / Context等が変わった場合は再authorizeする。

```text
authorize → allow
Delegation revoke
Business Operation → 古いallowを使って実行してはいけない
```

TOCTOUとは、Authorizationで確認した時点とBusiness Logicを実行する時点の間に状態が変化する問題を指す。

**Security Contract（D036・D037・D039）**

- `ActingFor::Decision` はauthorize実行時点の判定結果であり、再利用可能なauthorization token / capability / 権限証明ではない。過去のDecisionを保存・再利用して「認可済み」と扱わない。
- Host Applicationは保護対象Business Logicの実行に可能な限り近い時点でauthorizeする。
- cached Decisionを権限証明として再利用せず、cached Delegationを権限判定・authorization proofに使わない。
- Authorizationに必要なDelegation状態は、最新状態を期待できるauthoritative data sourceから読む。非同期Read Replicaはreplication lagによりstale Delegationを返す可能性があり、その安全性はActingForの保証範囲外。
- ActingForはBusiness Logicとのatomicity、DB locking / isolation levelによるTOCTOU防止を保証しない。v0.1ではDecision binding token / atomic execution APIを提供しない。

`ActingFor.authorize(...)` 自身は明示的なDB transactionを開始しない。概念上の順序はDelegation lookup → Authorization evaluation → Decision生成 → AuditEvent保存 → Decision return。保存失敗時は `ActingFor::AuditPersistenceError` をraiseし、Decisionを返さない。Host側Business Logicのtransaction管理はHost Applicationの責務。

v0.1のAuthorizationはDelegationへ `SELECT ... FOR UPDATE` 等の明示的なDB lockを取得しない。Decisionは実行時点で観測した状態に基づき、返却後からBusiness Logic実行までDelegationの有効性を保証しない。独自のtransaction isolation levelを要求・変更せず、READ COMMITTED / REPEATABLE READ / SERIALIZABLEを強制しない。Host Application / DB設定に従い、特定isolation levelによるatomicity / TOCTOU防止も保証しない（D036）。

## 14. Resource Identity

Authorization対象Resourceは、曖昧な表示名だけではなく一意に識別可能な情報によって評価する。同名Resourceの取り違えや、別ResourceへのDelegationの流用を防ぐ。Resource識別情報はHostが確定する。

[既存Resource設計](domain_model_v0_1.md#7-resource)の特定Resource / Resource type全体 / Resource不要のActionという区別を維持する。型全体への委任を禁止したり、Resource不要のActionに識別子を必須化したりしない。`resource: nil` は全Resourceを意味しない。後続決定D032でresource_idはString保存とし、Class / Instanceのmodel_nameとinstanceのid.to_sから正規化する。IDのto_sはPublic境界で1回だけ。resource_typeは正規化後の文字列をcase-sensitiveで比較し、specific ResourceのIDは正規化後のStringを完全一致で比較する。case normalization / numeric coercion・conversion / 追加のimplicit coercion / fuzzy matchingは行わない。Delegationのtype指定・ID nilはその型全体へのscopeとして同じ型の個別Resourceにもmatchする。両方nilはResource-less Actionのscope。「完全一致」を単純なtuple比較にして型全体への委任を失わせない。interface不備・instanceのnil ID / 空文字IDはInvalidRequestError。具体例は[Resource正本](domain_model_v0_1.md#7-resource)を参照。

## 15. Constraint Injection / Arbitrary Code Execution

Constraint評価で任意Rubyコードを実行してはいけない。`eval`、`instance_eval`、DB由来の任意Ruby code、DB由来の任意Proc / LambdaをConstraint評価方式として採用しない。

ActingForが定義した限定的operatorのみ評価する。未知のoperatorや評価不能Constraintをallowにしない。[既存Constraint Design](domain_model_v0_1.md#8-constraint)の6 operator、AND、トップレベルKeyのみ、暗黙型変換禁止、nested非対応を維持する。

## 16. Constraint Complexity / DoS

D030時点の過負荷対策要件をD041・D042で具体化し、v0.1で固定上限や専用timeoutを提供するという意味にはしない。

v0.1ではAuthorization context全体とsanitized Audit Contextに固定byte上限をPublic仕様として設けず、1 DelegationあたりのConstraint件数にも固定上限を設けない。HostはAuthorizationに必要な最小限のContextだけを渡し、汎用データ搬送手段として使わないことを推奨する。Auditは `audit_context_keys:` で明示的に選択した必要最小限の値だけを保存し、Constraintも認可に必要な最小限の条件へ保つ（D041）。

v0.1はAuthorization専用timeout設定・timeout APIを提供しない。DB / request / job等のtimeoutはHost Application / 実行環境の責務。ActingFor CoreのAuthorization処理に外部ネットワーク呼び出しを持ち込まない（D042）。

既存の限定的Constraint構造とfail-closedは維持する。

## 17. Authorization Enumeration / Information Leakage

外部Agentへ返すAuthorization情報は必要最小限とし、allow / deny / require_approvalを中心とする。他PrincipalのDelegation有無、matching Delegationの内部詳細、Constraint内部詳細、DB内部情報、internal reasonの詳細、Debug情報を不用意に公開しない。

```text
NG: principal_456にはpurchase delegationが存在するが、あなたのagentとは一致しない
OK: deny
```

詳細な判定情報は必要に応じて保護されたAudit側で扱える。[既存Decision Public API](public_api_v0_1.md#6-decision-public-api)を拡張せず、外部Response APIを追加しない。Audit reason_codeの正式3種類とdecisionとの整合性は後続D034で確定し、[AuditEvent詳細](domain_model_v0_1.md#14-auditevent)に従う。

## 18. Audit Tamper Resistance

AuditEventは通常運用ではappend-onlyとし、通常のActingFor Public APIからupdate / deleteする設計にはしない。Authorization履歴の後書き換えを防ぎ、Security Auditの信頼性を維持する。

後続決定D034によりAudit decision / reason_codeは正式3組のみをModel validationし、各columnはNOT NULL。DB CHECK constraintは設けない。matched_delegation_idsは重複なしのmatch集合で、denyは空配列、allow / require_approvalは実際のmatch IDを1件以上記録する。配列順に依存しない。

法的削除、Data retention、DB管理者による保守は通常Public APIとは別の運用責務であり、次節と両立する。既存方針どおりDBレベルのWORMや暗号署名等をv0.1の責務には追加しない。

## 19. Audit Retention / Data Minimization

Auditには必要最小限の情報だけを保存する。無期限保存をActingForの固定仕様にせず、Retention PolicyはHost Application側で管理可能とする。Hostは法令、Privacy Policy、社内Security Policy等に応じて保持期間を決定できる。

append-onlyは通常のAuthorization Audit APIについての原則であり、Retention / legal deletionは別の運用上の削除として扱う。AuditEventは通常運用でappend-onlyとし、v0.1では削除用Public APIを提供しない。固定retention period、自動削除、自動アーカイブは設けない。保持期間・削除・アーカイブはHost Applicationの運用責務で、サービスのセキュリティ要件・法令・社内規程等に応じて決定する（D040）。

### Audit保存表現の後続決定（D043・D044）

sanitized Audit ContextのBigDecimalはFloatへ変換せず、精度を失わない10進数StringとしてJSONへ保存する。例：`BigDecimal("12345.67")` → JSON `"12345.67"`。その他の既決定scalar型の仕様は変更しない（D044）。

Audit sanitized contextは `json` / `default: {}` / `null: false`、matched_delegation_idsは `json` / `default: []` / `null: false`。jsonbを必須とせず、詳細は[Domain Model](domain_model_v0_1.md#14-auditevent)に従う。

## 20. Sensitive Resource / Context Exposure Prevention

Resource識別情報やContextに機密情報が含まれていても、そのままAudit、Application log、Error message、Exception messageへ出力しない。Access Token、API Key、Password、Secret、Credential等を無条件に記録せず、Resource情報も必要最小限とする。

Audit以外への出力も保護対象とし、Audit Filter / Sanitizerだけで全出力の安全性を保証するとはしない。具体的なFilter / Sanitizer実装は追加決定しない。

## 21. Exception / Error Information Leakage

ActingFor内部Exceptionの詳細を外部Agentへそのまま公開しない。stack trace、SQL、DB schema情報、internal class名、file path、sensitive input、implementation detailsを不用意に出さない。

Host Applicationが外部向けの安全なError Responseへ変換する。内部調査用情報は適切に保護されたApplication log / monitoring等で扱い、その場合も第20節の機密情報保護に従う。外部Responseへの変換は、System failureをAuthorization denyへ変換する意味ではない。D031のActingFor定義ExceptionはError / InvalidRequestError / InternalError / AuditPersistenceErrorの4つのみ。lower-layer exceptionは原則そのままraiseし、明示決定されたAudit persistence exception以外を一律InternalErrorへwrapしない。

## 22. Secure Defaults / Misconfiguration

```text
Unknown / Invalid / Ambiguous → allowしない
```

設定不足・未知の値・不正設定によって権限が拡大する設計にしない。System / configuration failureを通常のAuthorization denyへ潰さず、Authorization failure → Decision(:deny)、System failure → Exceptionを維持する。Configuration / Initializerは新設しない。

## 23. Direct Model / DB Update Boundary

Host ApplicationやDB administratorがPublic APIを迂回してActiveRecord Modelを直接update、SQLで直接update、DBを書き換えることまで完全に防御できるとは保証しない。

通常利用ではPublic API経由を推奨する。Gem内部では可能な範囲で安全なModel制約を持たせる方向だが、D032〜D034・D043で確定したvalidation・DB制約だけを適用する。それ以外のcallback / DB constraint等は未決定。Public APIを迂回した操作はHost側の責務境界とする。

## 24. Concurrency / Race Condition

`ActingFor.authorize(...)` 自身は明示的なDB transactionを開始しない。概念上の順序はDelegation lookup → Authorization evaluation → Decision生成 → AuditEvent保存 → Decision return。保存失敗時は `ActingFor::AuditPersistenceError` をraiseし、Decisionを返さない。Host側Business Logicのtransaction管理はHost Applicationの責務。

v0.1のAuthorizationはDelegationへ `SELECT ... FOR UPDATE` 等の明示的なDB lockを取得しない。Decisionは実行時点で観測した状態に基づき、返却後からBusiness Logic実行までDelegationの有効性を保証しない。独自のtransaction isolation levelを要求・変更せず、READ COMMITTED / REPEATABLE READ / SERIALIZABLEを強制しない。Host Application / DB設定に従い、特定isolation levelによるatomicity / TOCTOU防止も保証しない（D036）。

v0.1ではAuthorization / Delegation作成 / AuditEvent保存を内部で自動retryしない。失敗は既存Exception方針で呼び出し元へ伝える。Hostがretryする場合、古いDecisionを再利用せず、必要に応じauthorizeから再評価する。delegateは呼ぶたび新規Delegationを作るため、内部自動retryによるduplicate Delegation作成を避ける（D038）。

## 25. Stale State / Cache / Replica Lag

ActingFor v0.1はAuthorization DecisionとDelegation lookup結果を内部cacheせず、Authorizationごとに現在の永続化状態を参照する。Host独自cacheの安全性は保証範囲外。Read Replica routing機能は提供しない（D039）。

Authorizationには最新状態を期待できるauthoritative data sourceを使う。cached Decisionを再利用可能な権限証明として扱わず、cached Delegationを権限判定へ利用しない。非同期Read Replicaでは次のstale readが起こり得る。

```text
Delegation revoked on authoritative DB
↓
Replicaにはまだ旧状態（replication lag）
↓
authorize
↓
allow
```

このstale readによる安全性はActingForでは保証しない。D030の要件をD039で詳細化したもので、Replicaの鮮度やBusiness Logicとのatomicityを保証するものではない。

## 26. 完了条件と後続工程

Security Model Designの完了条件は次のとおり。本書によりすべて設計上整理済みとする。

- Threat Modelが整理されている。
- Trust Boundaryが整理されている。
- Security Invariantが整理されている。
- Host Applicationとの責務境界が整理されている。
- v0.1で守るべきSecurity requirementが整理されている。
- 具体的実装方式とSecurity requirementが分離されている。
- 未決定事項が明示されている。

**Security Model Design = Complete / Design finalized / Not implemented。** D030時点で次工程とした「未決定事項の詰め」はD031〜D048により進行中。すべての未決定事項が完了したわけではなく、実装開始には進まない。

[Step 8 Test Strategy](test_strategy_v0_1.md)の完了状態・確定仕様を維持する。本書のSecurity requirementのImplementation / Testへの反映は後続工程で確認する。今回Test設計を再オープンせず、Test項目の大量追加や実装は行わない。v0.1全体のDefinition of Doneも引き続きProposal / 提案である。

## 27. 今回決めないこと

D030時点の未決定事項のうち、Exception / Audit ContextはD031、Resource / DelegationはD032、Agent validationはD033、AuditEvent詳細はD034で確定した。

D035〜D048でClock、transaction / locking / isolation、TOCTOU API非提供、retry、cache / replica、Audit retention / delete API、固定上限非設定、timeout、DB schemaの一部、BigDecimal、対応環境・CI matrix・ライセンスの保留を解消した。以下は引き続き未決定であり、Security requirementから推測して追加確定しない。

- Decisionの追加属性・constructor
- 確定済み範囲以外のDB schemaの型・制約
- Delegation creation / revocation caller authorizationの具体API
- 確定したModel validation / DB制約の具体的実装、未決定のcallback、revoke!の競合制御の具体実装等
- Constraint complexityの具体的な扱い（固定件数・byte上限と専用timeout非提供は確定済み）
- static analysis、Migration実コード・task名、Runnable Quick Start、Release notes
- Approval Workflow、MCP Adapter、OAuth / OIDC Adapterの具体設計・実装

Configuration / Initializer、Generatorも今回新設・追加設計しない。[D028の既存方針](gem_structure_v0_1.md)である「現時点でConfiguration / Initializerを作らない」「v0.1では独自Generatorを作らない」は維持し、将来の具体設計を今回決めない。Approval Workflowや各Adapterも既存の責務・スコープ境界を維持する。

Gem本体、Model、Service、Migration、Test、Generator、Configuration、Initializer、Cache、Locking、Sanitizer等の実装は開始しない。
