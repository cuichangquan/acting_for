# ActingFor 0.1.1 Release Notes

Status: **Draft / not yet published**

ActingFor 0.1.1 is a backward-compatible patch release that adds a public explanation hook to authorization Decisions.

## Highlights

### Decision#reason_code

`ActingFor.authorize(...)` continues to return an immutable `ActingFor::Decision`, and 0.1.1 adds:

```ruby
decision.reason_code
```

The supported mappings are:

| Decision status | reason_code |
| --- | --- |
| `:allow` | `:delegation_allowed` |
| `:require_approval` | `:delegation_requires_approval` |
| `:deny` | `:no_matching_delegation` |

Example:

```ruby
decision = ActingFor.authorize(...)

decision.status
# => :deny

decision.reason_code
# => :no_matching_delegation
```

### Decision and Audit consistency

Decision exposes the reason as a Symbol while AuditEvent keeps the existing String representation.

```ruby
decision.reason_code
# => :no_matching_delegation

audit_event.reason_code
# => "no_matching_delegation"
```

Authorization now derives the persisted AuditEvent reason from the returned Decision reason, so both represent the same final authorization reason.

## Compatibility

0.1.1 does not change:

- the three Decision statuses
- `allowed?`, `denied?`, or `approval_required?`
- Delegation matching semantics
- database schema or migrations
- existing AuditEvent reason String values
- supported Ruby / Rails ranges

The new API intentionally exposes only the final Decision reason. It does not expose per-Delegation mismatch details such as expiration, revocation, resource mismatch, or constraint mismatch.

## Verification

Core verification completed before release preparation:

- Ruby 3.4 / Rails 8.0: PASS
- Ruby 3.4 / Rails 8.1: PASS
- Ruby 4.0 / Rails 8.0: PASS
- Ruby 4.0 / Rails 8.1: PASS
- RuboCop: PASS
- representative formal suite: 351 runs / 898 assertions / 0 failures / 0 errors / 0 skips

Official Demo verification against the unreleased candidate:

- automated integration: 18 runs / 118 assertions / 0 failures / 0 errors / 0 skips
- focused human browser verification: PASS
- ALLOW / REQUIRE APPROVAL / DENY reason display and Audit consistency confirmed
- only ALLOW executed the purchase

## Installation

After 0.1.1 is published:

```ruby
gem "acting_for", "~> 0.1.1"
```

Until RubyGems publication completes, 0.1.0 remains the latest released version.

## Documentation

- [README](../README.md)
- [Getting Started](getting_started.md)
- [Decision reason_code API](decision_reason_code.md)
- [Release Runbook](release_runbook.md)
