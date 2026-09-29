# ActingFor 0.1.1 Release Plan

Status: **Release source fixed / final artifact verified / publication approval pending**

Decision: D244

## Scope

0.1.1 contains one backward-compatible Public API addition:

```ruby
ActingFor::Decision#reason_code
```

No schema or Migration changes are included.

## Release order

```text
Core release preparation
  ↓
Release Gate
  ↓
Core PR #2 merge to main
  ↓
freeze exact main Release Source SHA
  ↓
build final acting_for-0.1.1.gem
  ↓
package / install / checksum verification
  ↓
RubyGems publication
  ↓
download published gem / checksum / fresh install
  ↓
v0.1.1 tag + GitHub Release
  ↓
switch Official Demo to RubyGems ~> 0.1.1
  ↓
Demo automated integration / smoke
  ↓
Demo PR #1 merge
  ↓
post-release evidence
```

## Pre-release gate

### Core behavior

- [x] D240 Public API design approved
- [x] D241 tests-first implementation completed
- [x] Decision / Audit reason consistency verified
- [x] No schema / Migration change
- [x] No existing Public API removed or renamed

### Core CI

- [x] Ruby 3.4 / Rails 8.0
- [x] Ruby 3.4 / Rails 8.1
- [x] Ruby 4.0 / Rails 8.0
- [x] Ruby 4.0 / Rails 8.1
- [x] RuboCop
- [x] 351 runs / 898 assertions / 0 failures / 0 errors / 0 skips on representative matrix job

### Official Demo candidate verification

- [x] exact ActingFor candidate dependency tested
- [x] automated integration PASS: 18 runs / 118 assertions / 0 failures / 0 errors / 0 skips
- [x] human browser ALLOW verification PASS
- [x] human browser REQUIRE APPROVAL verification PASS
- [x] human browser DENY verification PASS
- [x] Decision Reason and Audit Reason consistency PASS
- [x] business execution boundary PASS

### Release-facing files

- [x] version selected: 0.1.1
- [x] `lib/acting_for/version.rb` bumped to 0.1.1
- [x] README pre-release wording prepared
- [x] Getting Started pre-release wording prepared
- [x] 0.1.1 Release Notes drafted
- [x] release order recorded in D244
- [x] pre-merge candidate strict gem build PASS
- [x] pre-merge package contents / secret scan PASS
- [x] pre-merge local artifact install PASS
- [x] technical Release Gate CI — Actions run `36526103853`, all 5 jobs green; subsequent changes are evidence/documentation only
- [x] final PR diff review / technical merge readiness — PR #2 mergeable, expected 12-file release diff only
- [x] RubyGems authentication confirmation — WebAuthn / 2FA available

## Pre-merge candidate package evidence

GitHub Actions run `36526009671` verified the 0.1.1 candidate before merge:

```text
ActingFor version: 0.1.1
Gem filename: acting_for-0.1.1.gem
Gem file count: 17
Gem size: 16384 bytes
Candidate SHA256: 57ceb266285a0970af79c3ad745171638799b00b6d8617bf9ecfc13382819c29
Package secret scan: PASS
Installed ActingFor version: 0.1.1
Engine: true
```

This is **candidate evidence only**. The final release artifact must be rebuilt after Core PR #2 is merged and the exact main Release Source SHA is fixed. Do not reuse the candidate checksum as the final published-artifact checksum.

## After Core merge

The exact merged main SHA becomes the candidate Release Source only after the final gate is confirmed.

Before publication:

- [x] record `VERSION=0.1.1`
- [x] record exact `RELEASE_SOURCE=3fdccde58c79e1b0943e22d60016993ab6743835`
- [x] `gem build --strict acting_for.gemspec` PASS
- [x] package contents reviewed — 17 files
- [x] secret / credential review PASS
- [x] local artifact installation PASS
- [x] record gem filename / file count / size / SHA256
- [ ] explicit approval to publish

## Final release artifact

```text
Release Source: 3fdccde58c79e1b0943e22d60016993ab6743835
GitHub Actions run: 36526786968
Gem filename: acting_for-0.1.1.gem
File count: 17
Size: 16384 bytes
SHA256: 57ceb266285a0970af79c3ad745171638799b00b6d8617bf9ecfc13382819c29
Package secret scan: PASS
Artifact install: PASS
ActingFor::VERSION: 0.1.1
Engine load: PASS
GitHub Actions artifact id: 11015405271
```

The downloaded workflow artifact was independently checked again: the contained gem is 16,384 bytes and has the same SHA256.

## Publication

Publication is not authorized merely by this plan.

After explicit approval:

- [ ] publish `acting_for 0.1.1` to RubyGems
- [ ] fetch distributed artifact
- [ ] distributed SHA256 equals final local artifact SHA256
- [ ] fresh RubyGems install PASS
- [ ] `ActingFor::VERSION == "0.1.1"`
- [ ] create `v0.1.1` tag on exact Release Source
- [ ] publish GitHub Release

## Post-release Demo

Official Demo must not merge its temporary exact-Git dependency to main.

After RubyGems publication:

- [ ] change Demo dependency to `gem "acting_for", "~> 0.1.1"`
- [ ] regenerate / verify `Gemfile.lock`
- [ ] automated integration PASS
- [ ] smoke verification PASS
- [ ] update compatibility evidence
- [ ] merge Demo PR #1 to main

## Final status target

```text
RELEASED
  RubyGems 0.1.1
  distributed artifact verified
  v0.1.1 tag
  GitHub Release

POST-RELEASE VERIFIED
  post-release Core CI
  Official Demo on RubyGems 0.1.1
  Demo integration / smoke verified
  evidence recorded
```
