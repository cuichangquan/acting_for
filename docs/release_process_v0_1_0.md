# ActingFor v0.1.0 Release Process and Verification Record

この文書は、ActingFor `0.1.0` の初回公開時に実際に行ったリリース前確認、リリース作業、リリース後確認を記録する。

利用者向けのリリース内容は [release_notes_v0_1_0.md](release_notes_v0_1_0.md) を参照する。次回リリース時に最初に読む短い手順書は [release_runbook.md](release_runbook.md) を参照する。

本書の目的は次の2つ。

1. ActingFor 0.1.0をどのような手順と証跡で公開したかを残す
2. 次回リリース時に、過去の実績と判断根拠を確認できるようにする

GitHub `main` がプロジェクト成果物の正本である。

## 1. Final Release Facts

```text
Gem name: acting_for
Version: 0.1.0
Release date: 2026-09-22
RubyGems: acting_for 0.1.0
Git tag: v0.1.0
GitHub Release: ActingFor 0.1.0
Release source SHA: 6722623a9f24a38c41091e867209bc8f3d913c36
Gem files: 17
Gem size: 15,872 bytes
Gem SHA256: a7c3cfc97bf04445c04b8fc9cbe6be8a9aa433cfb8ba20b0da90f853b1336abd
```

`v0.1.0` tagはRelease Source SHA `6722623a9f24a38c41091e867209bc8f3d913c36` を指す。リリース後にdocumentationを更新したため、GitHub `main` はその後のcommitへ進んでいる。

```text
v0.1.0 tag
    ↓
released source

main
    ↓
released source + post-release documentation / next work
```

## 2. Release全体の流れ

```text
Phase 1 — Pre-Release
リリースしてよい状態か確認
        ↓
Phase 2 — Release
RubyGems / Git tag / GitHub Release公開
        ↓
Phase 3 — Post-Release
公開されたartifactと実利用を再確認
```

今回の重要な考え方は、local buildの成功だけで公開完了としなかったこと。

```text
Source
  ↓
Build Artifact
  ↓
RubyGems
  ↓
RubyGemsから再取得
  ↓
Checksum一致
  ↓
Fresh Install
  ↓
Official Demo integration
```

## 3. Phase 1 — Pre-Release

### 3.1 Public API / Security Contractの確定

リリース前に、Domain Model、Public API、Security Model、Gem Structure、Test Strategy、Delegation API、Authorization、Decision、ConstraintEvaluator、Audit integration、Host Authorization Boundaryを確定した。

ActingForは認可Gemなので、「動くこと」だけでなく「安全側に失敗すること」を重視した。

### 3.2 Formal Test Suite

正式なMinitest suiteとしてDecision、ConstraintEvaluator、Delegation、Authorization、AuditEvent、Rails Engine、Migration、Host Authorization Boundaryを整備した。

Release Readiness時点の代表結果:

```text
298 runs
755 assertions
0 failures
0 errors
0 skips
```

### 3.3 Formal CI Matrix

GitHub Actionsで以下を正式support matrixとして検証した。

| Ruby | Rails | Database |
| --- | --- | --- |
| 3.4 | 8.0 | PostgreSQL 16 |
| 3.4 | 8.1 | PostgreSQL 16 |
| 4.0 | 8.0 | PostgreSQL 16 |
| 4.0 | 8.1 | PostgreSQL 16 |

独立RuboCop jobを含む合計5 jobsをRelease Gateとした。

```text
RuboCop
Ruby 3.4 / Rails 8.0
Ruby 3.4 / Rails 8.1
Ruby 4.0 / Rails 8.0
Ruby 4.0 / Rails 8.1
```

### 3.4 Runnable Quick Start Verification

READMEの導入手順を新規Rails Applicationで実行した。

Verified environment:

```text
Ruby 3.4.10
Rails 8.0.5.1
PostgreSQL 16.15
```

確認した流れ:

```text
新規Rails App
  ↓
ActingFor導入
  ↓
Migration install / db:migrate
  ↓
Agent作成
  ↓
Delegation作成
  ↓
ActingFor.authorize
  ↓
ALLOW / REQUIRE_APPROVAL / DENY
  ↓
AuditEvent確認
```

Gem repository内だけでなく、別Rails ApplicationからPublic APIとして利用できることを確認した。

### 3.5 Package Verification

公開前に実際のgem packageを作成した。

```sh
gem build --strict acting_for.gemspec
```

確認項目:

- strict build成功
- warningなし
- package内ファイル確認
- 不要ファイルが含まれていない
- 必要なlib / app / migration / README / LICENSEが存在
- secret / credential等が含まれていない
- gemspec metadata確認

### 3.6 Artifact Install Verification

buildした `.gem` そのものを新規Rails Applicationへinstallし、Migration、Delegation、Authorization、Auditまで確認した。

この段階ではGit checkout sourceではなく、実際に配布予定のartifactを検証した。

### 3.7 Release Readiness Gate

Release前にGateを設け、結果を `RELEASE READY` とした。

確認対象はFormal tests、CI matrix、RuboCop、Gem build、Package audit、Artifact install、Runnable Quick Start、Documentation、Support environment。

`RELEASE READY` と `RELEASED` は別状態として扱った。

### 3.8 Additional Security Hardening

Release Ready後もSecurity Regression Testを追加した。

Delegation lifecycle:

- persisted Delegationの認可属性変更禁止
- revoke
- revoke idempotency
- revoked Delegationで認可できない
- stale instance behavior

AuditEvent tamper resistance:

- persisted AuditEventの変更禁止
- destroy禁止
- Authorizationごとに新規AuditEvent作成
- Agent変更後もsnapshot保持
- Delegation revoke後も既存Audit snapshot保持

Security hardening batch:

- Sensitive Context
- Error Leakage
- DB Constraints
- Stale Decision
- Delegation Management Host Boundary
- Replay Boundary
- Concurrent revoke
- Confused-Deputy binding

Production APIを増やすのではなく、既存Security ContractをRegression Testとして固定することを優先した。

### 3.9 Release Candidate

正式公開前にRelease Candidate baselineを固定した。目的は、公開直前に検証対象が動き続けないようにすること。

RCに対してfresh artifact verificationを行い、RubyGems authentication等の公開作業に必要なhuman確認も行った。

### 3.10 Repository Public化とRelease-facing Documentation

RubyGems公開前にActingFor repositoryとOfficial DemoをPublic化した。

private repository前提、Git authentication前提、unreleased / released表記、Getting Started、README、Demo build手順を確認した。

RubyGemsへ実際に公開されるまでは、releasedと記述せずtruthfulなunreleased状態を維持した。

### 3.11 Final Artifact Source

最終公開artifactのSourceを以下へ固定した。

```text
6722623a9f24a38c41091e867209bc8f3d913c36
```

このSHAをGem artifact、Git tag、GitHub Releaseの基準とした。

## 4. Phase 2 — Release

### 4.1 Build Final Gem

Final Sourceから再度strict buildした。

```sh
gem build --strict acting_for.gemspec
```

最終artifact:

```text
acting_for-0.1.0.gem
17 files
15,872 bytes
SHA256:
a7c3cfc97bf04445c04b8fc9cbe6be8a9aa433cfb8ba20b0da90f853b1336abd
```

### 4.2 Publish to RubyGems

最終artifactをRubyGemsへ公開した。

概念的なrelease command:

```sh
gem push acting_for-0.1.0.gem
```

公開後、RubyGemsから `acting_for 0.1.0` が取得可能であることを確認した。

### 4.3 Verify the Distributed Artifact

RubyGemsから公開済みartifactを再取得し、local release artifactとSHA256を比較した。

結果:

```text
MATCH

a7c3cfc97bf04445c04b8fc9cbe6be8a9aa433cfb8ba20b0da90f853b1336abd
```

これにより、検証したartifactと利用者へ配布されるartifactが同一であることを確認した。

### 4.4 Fresh Install Verification

既存bundleやlocal pathを使わないfresh environmentで、RubyGemsから通常installした。

```text
Ruby 3.4.10 fresh container
gem install succeeded
ActingFor::VERSION == "0.1.0"
```

package不足、dependency不足、require漏れ、published artifactの問題がないことを確認した。

### 4.5 Create v0.1.0 Tag

Release Sourceへtagを付けた。

```text
v0.1.0
  ↓
6722623a9f24a38c41091e867209bc8f3d913c36
```

release後のdocumentation commitへtagを移動していない。Tagはそのversionを作ったsourceの固定参照点として扱う。

### 4.6 Publish GitHub Release

GitHub Releaseを公開した。

```text
Name: ActingFor 0.1.0
Tag: v0.1.0
draft: false
prerelease: false
```

Release本文にはRubyGems version、Source SHA、Gem size、SHA256、Installation、Features、Public API、Host authorization boundary、Known limitations、Supported environments、Documentation、Licenseを含めた。

Release: https://github.com/cuichangquan/acting_for/releases/tag/v0.1.0

### 4.7 Release Completion

ここまで完了した時点でD238 `ActingFor 0.1.0 public release completed` とした。

Release本体の完了条件:

```text
RubyGems publication
AND
distributed artifact verification
AND
fresh install verification
AND
v0.1.0 tag
AND
GitHub Release
```

## 5. Phase 3 — Post-Release

### 5.1 Update Main Documentation

公開後、README等を通常のRubyGems installへ変更した。

```ruby
gem "acting_for", "~> 0.1.0"
```

更新対象:

- README.md
- docs/getting_started.md
- docs/release_notes_v0_1_0.md
- docs/CURRENT_STATE.md
- docs/PROGRESS.md
- docs/DECISIONS.md

Post-release documentation commit:

```text
545bd642b4c44d38195c3d9bf87caa0f92dd576a
docs: record v0.1.0 release
```

このcommitは`v0.1.0` tagの後にあるため、`tag = released source`、`main = released source + post-release docs` となる。

### 5.2 Post-Release CI

Post-release documentation更新後にも、RuboCopとRuby/Rails 4-matrixの合計5 jobsがすべてgreenであることを確認した。

### 5.3 Official Demo Dependency Switch

Official DemoをRelease Candidate Git sourceからRubyGems dependencyへ切り替えた。

```ruby
gem "acting_for", "~> 0.1.0"
```

`Gemfile.lock`でも `acting_for (0.1.0)` がRubyGemsから解決される状態にした。

### 5.4 Demo Automated Integration Verification

released `acting_for 0.1.0` に対してOfficial Demo integration testを実行した。

最初のreleased-gem verification:

```text
17 runs
94 assertions
0 failures
0 errors
0 skips
```

### 5.5 Smoke Verification

Demoを実際に起動し、代表的な3Decisionを確認した。

```text
¥800   → ALLOW            → Purchase created
¥2,000 → REQUIRE APPROVAL → Purchase not created
¥5,000 → DENY             → Purchase not created
```

AuditEventも3Decisionすべて確認した。

Smoke Verification: `PASS`.

### 5.6 Manual Verificationで見つかったDemo Bug

revoke scenarioの手動確認中、Gem本体ではなくDemo UIの問題を発見した。

ALLOW Delegationだけをrevokeすると、Shopが完全なDelegation設定を前提としていたため500 Internal Server Errorになった。ActingForのAuthorization自体はFail Closedで動作していた。

Demo fix:

```text
fd4846a7f9e6301bfcfd1cef9e889e4442fe05be
fix: keep demo shop usable after partial revoke
```

Regression Test:

```text
18 runs
108 assertions
0 failures
0 errors
0 skips
```

この経験から、Gemの認可ロジックとHost application UIは別々に確認する必要があることが分かった。

### 5.7 Verification Provenance

Release後のDemo verificationでは、誰がどの検証を行ったかを区別した。

```text
Smoke          → PASS
Scenario 1–6   → Human verified PASS
Scenario 7–11  → Codex-assisted PASS
Regression     → PASS
```

Codex-assisted verificationを `Human Manual Verification COMPLETE` とは記録しなかった。誰が、どの方法で、何を確認したかを残す方針とした。

## 6. Releaseで重要だった考え方

### 6.1 Source / Tag / Artifactを結び付ける

```text
Source SHA
  ↓
Tag
  ↓
Gem Artifact
  ↓
SHA256
  ↓
Published Artifact
```

今回:

```text
Source: 6722623a9f24a38c41091e867209bc8f3d913c36
Tag: v0.1.0
Gem: acting_for-0.1.0.gem
SHA256: a7c3cfc97bf04445c04b8fc9cbe6be8a9aa433cfb8ba20b0da90f853b1336abd
```

### 6.2 Build成功だけでは不十分

```text
Source tests PASS
  ↓
gem build PASS
  ↓
package contents PASS
  ↓
local artifact install PASS
  ↓
RubyGems publish PASS
  ↓
published artifact checksum PASS
  ↓
fresh RubyGems install PASS
  ↓
real host application PASS
```

### 6.3 Published Artifactを再検証する

自分がbuildしたgemだけでなく、利用者がRubyGemsから取得するgemを検証する。Release pipelineの最後で別物が配布されていないことをchecksumで確認する。

### 6.4 TagはRelease Sourceに固定する

release後にREADMEやdocumentationを変更しても、release tagを新しいmainへ動かさない。Tagはそのversionを作ったsourceの永久的な参照点として扱う。

### 6.5 Release NotesとRelease Processは別物

`release_notes_v0_1_0.md` は利用者向け。本書はmaintainer向けで、どうreleaseしたか、何を検証したか、どのartifactを公開したかを記録する。

### 6.6 Demo VerificationはGem Releaseと分離する

Gem公開そのものとOfficial Demoでpublished gemを確認する作業を別フェーズとして扱う。Release artifact integrityとHost integration correctnessを混同しない。

## 7. v0.1.0 Release Result

```text
ActingFor 0.1.0
RELEASED

RubyGems: PASS
Distributed Artifact Checksum: PASS
Fresh Install: PASS
v0.1.0 Tag: PASS
GitHub Release: PASS
Post-Release CI: PASS
Official Demo Automated Integration: PASS
Smoke Verification: PASS
Human / Codex-assisted Demo Verification: PASS with provenance recorded
```

ActingFor 0.1.0の初回公開は完了した。
