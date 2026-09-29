# Decision reason_code — ActingFor 0.1.1 Public API

更新日：2026-09-29

状態：**Released in ActingFor 0.1.1**

ActingFor 0.1.1 is published on RubyGems. This document records the `Decision#reason_code` Public API addition defined by D240, implemented and verified by D241–D245, and released in 0.1.1.

## Public API

`ActingFor.authorize(...)` continues to return an immutable `ActingFor::Decision`.

ActingFor 0.1.1 adds:

```ruby
decision.reason_code
```

The supported status / reason pairs are:

| status | reason_code |
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

## Audit consistency

Decision returns the reason as a Symbol. AuditEvent preserves its existing String representation.

```ruby
decision.reason_code
# => :no_matching_delegation

audit_event.reason_code
# => "no_matching_delegation"
```

Authorization derives the persisted AuditEvent reason from `decision.reason_code`, so both represent the same final authorization reason.

## Scope boundary

This addition exposes only the final Decision reason.

It does not expose per-Delegation mismatch details such as expiration, revocation, resource mismatch, or constraint mismatch. It also does not add `matched_delegation_ids` or authorization context to Decision.

Existing Public API remains unchanged:

```ruby
decision.status
decision.allowed?
decision.denied?
decision.approval_required?
```

## Compatibility

- No schema or Migration change.
- No Delegation matching change.
- No change to the three Decision statuses.
- No change to existing AuditEvent String reason values.
- No existing Public API is removed or renamed.
- `Decision#reason_code` is available starting with `acting_for 0.1.1`.

For the released 0.1.0 baseline contract, see [v0.1 Public API Design](public_api_v0_1.md). For the 0.1.1 design, verification, and release decisions, see D240–D246 in [DECISIONS](DECISIONS.md).
