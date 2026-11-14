# ActingFor 0.1.2 Release Notes

Status: **Candidate; not published**

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

This document describes the candidate. RubyGems publication, the `v0.1.2` tag, and a GitHub Release have not occurred. Before publication, freeze the release source and perform the artifact build, install, and checksum checks in the [Release Runbook](release_runbook.md). The published version remains 0.1.1 until that release procedure is completed.
