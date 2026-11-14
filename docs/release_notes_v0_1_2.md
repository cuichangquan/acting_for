# ActingFor 0.1.2 Release Notes

Status: **RELEASED — RubyGems, distributed artifact verification, exact-source tag, and GitHub Release completed.**

## Fix: exact Symbol keys in authorization Context

Constraint evaluation now checks that the required top-level Symbol key actually exists, using the same key-selection rule as Audit Context sanitization.

Previously, `ActiveSupport::HashWithIndifferentAccess` could satisfy a constraint through its String-backed key. The same value was omitted from Audit even when selected with `audit_context_keys`, because Audit already enforced the documented exact Symbol-key contract. The correction makes these two paths consistent.

The host should construct a small, trusted ordinary Hash explicitly:

```ruby
context: { amount: product.price },
audit_context_keys: [:amount]
```

Load and verify business values in the host. Converting untrusted request parameters to Symbol keys does not establish that they are trustworthy.

## Compatibility

- Public API signatures, Decision statuses and reason codes, database schema, and supported Ruby / Rails ranges remain unchanged.
- A normal Hash with `:amount` still supplies the constraint value. A normal Hash containing only `"amount"` still does not.
- If both `:amount` and `"amount"` exist in an ordinary Hash, only the Symbol-keyed value is used for the constraint and for explicitly selected Audit Context.
- `HashWithIndifferentAccess` stores String keys. Constraints requiring a Symbol key no longer match those keys. Applications relying on the previous behavior must construct the trusted Symbol-keyed Context explicitly.
- This is a per-constraint matching correction, not a rejection of the entire request or Hash class. Unconstrained delegations still match. For example, an unconstrained `allow` can still allow an operation when an amount-constrained `require_approval` no longer matches. Review the complete delegation rules when upgrading.
- Audit Context remains opt-in through `audit_context_keys`; the correction does not automatically log authorization inputs.

## Adoption example: correlate authorization and host processing

[Getting Started](getting_started.md#correlate-authorization-audit-with-host-processing-logs) now shows a host-generated `authorization_id` for each authorization call. The existing Context allowlist stores it in AuditEvent, and the host includes the same ID in its processing logs.

The example distinguishes an authorization result from business success, covers outer transaction rollback, and does not use the latest AuditEvent to identify a concurrent request. The ID is for correlation; it does not implement idempotency or grant authorization.

## Verification and release status

The test-first baseline is [CI run 43546478117](https://github.com/cuichangquan/acting_for/actions/runs/43546478117) at commit `fbadce7b5d71d70d97cb97865db3912fc51f3977`. All four Ruby 3.4 / 4.0 and Rails 8.0 / 8.1 combinations reproduced the same three regression failures; each ran 355 tests with 904 assertions and no errors or skips. The fourth new case, an ordinary Hash with both key types, passed.

The four added public-API regression cases check Decision results, matched delegation IDs, and selected Audit Context. The post-fix CI and independent review evidence is recorded in [PR #10](https://github.com/cuichangquan/acting_for/pull/10).

The corrected formal suite passed with 355 tests / 910 assertions, no failures, errors, or skips, across Ruby 3.4 / 4.0 and Rails 8.0 / 8.1. The user subsequently authorized the 0.1.2 release and published with their own RubyGems authentication. RubyGems metadata records publication at 2026-11-14 12:05 JST. The [distributed Gem](https://rubygems.org/downloads/acting_for-0.1.2.gem) was downloaded after publication; its size and SHA256 match the final artifact below, as does the metadata checksum.

The final artifact was built from the frozen source and verified before publication in [Actions run 43548370616](https://github.com/cuichangquan/acting_for/actions/runs/43548370616). Strict build, the 17-file package allowlist, package-to-source comparison, known-secret-signature scan, and fresh Rails installation passed. The installation check passed 85 checks across 8 scenarios on Ruby 3.4.12 / Rails 8.0.5.2 / PostgreSQL 16.16, including migration, all three Decisions and Audit, the Context-key correction, and authorization correlation.

| Release evidence | Value |
| --- | --- |
| Version | `0.1.2` |
| Frozen release source | [`adce638556e8e8b5a048fbd7241cd9df2808db7b`](https://github.com/cuichangquan/acting_for/commit/adce638556e8e8b5a048fbd7241cd9df2808db7b) |
| Gem | `acting_for-0.1.2.gem` |
| Packaged files / size | 17 files / 16,384 bytes |
| SHA256 | `ac2b5ceb93aa3896aab9891bca73424d808629ec3e3109e7fd3d2313f63fdaab` |
| RubyGems publication | Confirmed by successful registration, public metadata, and package download |
| Distributed artifact checksum | PASS; matches the final artifact and RubyGems metadata |
| Fresh published-gem installation | PASS; 85 checks / 8 scenarios in [Actions run 43550371341](https://github.com/cuichangquan/acting_for/actions/runs/43550371341) |
| `v0.1.2` tag and GitHub Release | PASS; tag points to the frozen source; [public Release](https://github.com/cuichangquan/acting_for/releases/tag/v0.1.2) published 2026-11-14 12:13 JST |
| Core post-publication documentation / CI | Final reviewed head, merge SHA, and post-merge CI closure are tracked in [Core PR #11](https://github.com/cuichangquan/acting_for/pull/11) |
| Official Demo on released 0.1.2 | [Demo PR #5](https://github.com/cuichangquan/acting_for_demo/pull/5) merged; [post-merge CI](https://github.com/cuichangquan/acting_for_demo/actions/runs/43550608317) passed 29 tests / 182 assertions, HTTP smoke, and official MCP verification on installed 0.1.2 |

The package and `v0.1.2` tag use the frozen source above. Documentation commits made after publication have their own revisions and do not replace the packaged source or change the published bytes. The published-Gem workflow downloaded and checked the public metadata, checksum, and payload, then verified a normal version-based Gem installation and its cached artifact in a fresh Rails app. The tag/Release job ran only after that verification succeeded. Both jobs in run 43550371341 passed. The environment was Ruby 3.4.12 / RubyGems 3.6.9 / Rails 8.0.5.2 / PostgreSQL 16.16. These checks follow the [Release Runbook](release_runbook.md). See [D249](DECISIONS.md#d249-actingfor-012-public-release-and-verification) for the release record.
