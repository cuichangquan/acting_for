# ActingFor Release Runbook

この文書は、**次回リリース時に最初に読む短い全体案内**である。

過去の実例は [release_process_v0_1_0.md](release_process_v0_1_0.md)、利用者向けRelease Notesの例は [release_notes_v0_1_0.md](release_notes_v0_1_0.md) を参照する。

目的は、細かいコマンドを覚えることではなく、「今どの段階で、次に何を確認すべきか」をすぐ把握できるようにすること。

## 1. まず全体像

```text
① Scope / Versionを決める
        ↓
② Release Gate
   Tests / CI / Security / Docs / Quick Start
        ↓
③ Release Sourceを固定
   exact commit SHA
        ↓
④ Final Gemをbuild
   files / size / SHA256を記録
        ↓
⑤ RubyGemsへpublish
        ↓
⑥ Published Artifactを再取得して検証
   checksum / fresh install / version
        ↓
⑦ Tag + GitHub Release
   tagはexact Release Source SHA
        ↓
⑧ Post-Release Docs + CI
        ↓
⑨ Official Demoをreleased gemへ切替
   automated integration / smoke / manual-or-assisted
        ↓
⑩ Evidenceをdocsへ記録
```

迷ったら、まず「今どの番号か」を確認する。

## 2. 3つの状態を混同しない

```text
RELEASE READY
  ↓
公開してよい状態
RubyGemsにはまだ出していない

RELEASED
  ↓
RubyGems + Published Artifact verification
+ Tag + GitHub Releaseまで完了

POST-RELEASE VERIFIED
  ↓
Docs / CI / Official Demoまで確認済み
```

`gem push` 成功だけで `POST-RELEASE VERIFIED` とはしない。

## 3. Release Gate — 公開前に止まって確認

### Code / Security

```text
[ ] Public APIの変更点を把握
[ ] Security Contractの変更点を把握
[ ] Delegation / Authorization / Auditのregression PASS
[ ] 未解決のrelease blockerなし
```

### Tests / CI

```text
[ ] Formal tests PASS
[ ] failures = 0
[ ] errors = 0
[ ] CI matrix green
[ ] RuboCop green
```

### Real Installation

```text
[ ] Runnable Quick Start PASS
[ ] 新規Rails AppからPublic APIを利用できる
[ ] Migration install / migrate PASS
[ ] ALLOW / REQUIRE_APPROVAL / DENY確認
[ ] AuditEvent確認
```

### Package

```text
[ ] gem build --strict PASS
[ ] package contents確認
[ ] secret / credential混入なし
[ ] local .gem artifact install PASS
```

### Release-facing information

```text
[ ] version確認
[ ] gemspec確認
[ ] README確認
[ ] Getting Started確認
[ ] Release Notes準備
[ ] supported versions再確認
[ ] repository visibility確認
[ ] RubyGems authentication確認
```

全部満たしたら `RELEASE READY`。

## 4. Release Sourceを固定する

公開直前にexact commit SHAを記録する。

```text
VERSION=x.y.z
RELEASE_SOURCE=<exact commit SHA>
```

以後、Final Gem、Tag、GitHub ReleaseはこのSourceを基準にする。

公開作業中にmainが進んでも、Release Sourceを曖昧にしない。

## 5. Final Artifactを作る

Release Sourceからbuildする。

```sh
gem build --strict acting_for.gemspec
```

最低限、次を記録する。

```text
Gem filename:
File count:
Size:
SHA256:
Source SHA:
```

macOSの例:

```sh
shasum -a 256 acting_for-X.Y.Z.gem
```

ここで得たSHA256はpublished artifact照合の基準値になる。

## 6. RubyGemsへpublish

```sh
gem push acting_for-X.Y.Z.gem
```

ただし、ここではまだ作業を終えない。

```text
gem push success
    ≠
release verification complete
```

## 7. Published Artifactを必ず再検証

RubyGemsから配布されるartifactを再取得し、release前に記録したSHA256と比較する。

```text
local final artifact SHA256
        ==
RubyGems distributed artifact SHA256
```

さらにfresh environmentで通常installする。

確認項目:

```text
[ ] RubyGemsからinstall成功
[ ] require "acting_for" 成功
[ ] ActingFor::VERSIONが期待version
[ ] local path / Git sourceを参照していない
```

この段階で、利用者が実際に受け取るartifactを確認できる。

## 8. Tag + GitHub Release

TagはRelease Source SHAへ付ける。

```text
vX.Y.Z
  ↓
exact RELEASE_SOURCE
```

Release後docs commitへtagを動かさない。

GitHub Releaseで確認するもの:

```text
[ ] correct tag
[ ] correct version/name
[ ] draft = false
[ ] prereleaseの意図が正しい
[ ] Source SHA記載
[ ] Gem SHA256記載
[ ] installation記載
[ ] known limitations記載
[ ] supported environment記載
```

ここまででRelease本体を `RELEASED` とできる。

## 9. Post-Release

### Main documentation

released状態へ更新する。

```text
[ ] README
[ ] Getting Started
[ ] Release Notes
[ ] CURRENT_STATE
[ ] PROGRESS
[ ] DECISIONS（正式Decisionがある場合）
```

### CI

```text
[ ] post-release main CI green
```

### Official Demo

Demoをdevelopment Git sourceからreleased RubyGems dependencyへ切り替える。

```ruby
gem "acting_for", "~> X.Y.Z"
```

順番:

```text
Demo automated integration
        ↓
Smoke verification
        ↓
Human / assisted verification
        ↓
Compatibility record
```

誰がどの方法で確認したかを明記し、Codex-assisted verificationをHuman verificationとして記録しない。

## 10. Release中に問題を見つけたとき

### Pre-Releaseで見つけた

公開を止める。修正後にGateをやり直す。

### RubyGems publish前にartifact差分を見つけた

公開しない。Release Source / artifactを再固定する。

### RubyGems publish後にpublished artifact verificationで問題を見つけた

「公開済み」を事実として扱い、隠さず状況を記録する。Versionを上書きする前提にしない。必要なら次versionのreleaseを検討する。

### Demoで問題を見つけた

まず分類する。

```text
Gem bug?
Demo host bug?
Manual procedure bug?
Environment issue?
```

Gemの仕様をDemo側で無理に回避しない。

## 11. Release Evidence Template

毎回、最終的にこの情報を1箇所へ残す。

```text
Version:
Release date:
Release source SHA:
Tag:
Gem filename:
Gem file count:
Gem size:
Gem SHA256:

Formal tests:
CI:
RuboCop:
Quick Start:
Artifact install:

RubyGems publication:
Distributed artifact checksum:
Fresh install:
GitHub Release:

Post-release CI:
Demo automated integration:
Smoke:
Human verification:
Assisted verification:

Problems found:
Follow-up fixes:
Final status:
```

## 12. 迷ったときの最短チェック

次回リリース時に時間がなくても、この順番だけは崩さない。

```text
1. Tests / CI green?
2. Release Source SHAは固定した?
3. Final .gemをそのSHAからbuildした?
4. SHA256を記録した?
5. RubyGemsへpublishした?
6. RubyGemsから取り直してSHA256一致した?
7. fresh installした?
8. tagはRelease Source SHAを指している?
9. GitHub Releaseを公開した?
10. Demoでpublished gemを確認した?
11. 証跡をdocsへ残した?
```

この11項目が、ActingFor releaseの最短の全体像である。
