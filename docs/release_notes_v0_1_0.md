# ActingFor 0.1.0

Published on 2026-09-22 as GitHub Release `v0.1.0` and RubyGems `acting_for` 0.1.0.

Source SHA: `6722623a9f24a38c41091e867209bc8f3d913c36`  
Gem SHA256: `a7c3cfc97bf04445c04b8fc9cbe6be8a9aa433cfb8ba20b0da90f853b1336abd`

*Rails-native delegated authorization for AI agents.*

ActingFor evaluates what an AI agent may do on behalf of a principal inside a Rails application. It provides a headless Rails Engine, without business-operation execution or an authentication server.

## Features

- Local Agent representation with a unique identifier, separate from the host's Principal.
- Persistent Delegations created with `ActingFor.delegate(...)`, scoped by Principal, Agent, Action, and optional Resource type or instance.
- `ActingFor.authorize(...)` returns an immutable Decision with three statuses: `allow`, `deny`, and `require_approval`. `require_approval` is not `allow`; `allowed?` is false.
- Constraints support `eq`, `lt`, `lte`, `gt`, `gte`, and `in`, combined with AND and strict value types. Missing / nil Context fields do not match. Ordering comparisons use Integer values.
- Optional expiration and idempotent `Delegation#revoke!`. Delegation authorization attributes are immutable at the Model level; changes use revoke + create. An expired or revoked Delegation cannot authorize an action.
- Automatic persisted AuditEvent for every returned authorization Decision, including deny. Audit Context defaults to `{}`; `audit_context_keys:` explicitly selects supported fields. Audit Model records are append-only at the Model level.
- Three Engine migrations installed explicitly through the Rails standard task.

Matching `require_approval` takes precedence over matching `allow`; no match yields `deny`. There is no explicit deny Delegation effect.

## Supported environments

| Ruby | Rails | Database |
| --- | --- | --- |
| 3.4 | 8.0 | PostgreSQL 16 |
| 3.4 | 8.1 | PostgreSQL 16 |
| 4.0 | 8.0 | PostgreSQL 16 |
| 4.0 | 8.1 | PostgreSQL 16 |

These four combinations are verified by the formal CI matrix. PostgreSQL is the only officially supported adapter for v0.1. Dependency ranges are Ruby `>= 3.4, < 4.1` and Rails components `>= 8.0, < 8.2`; installable dependencies do not extend the formal support matrix.

Support checked on 2026-09-19: Ruby 3.4 and 4.0 are in normal maintenance. Rails 8.0 receives security fixes until 2026-11-07; its bug-fix period has ended. Rails 8.1 receives bug fixes until 2026-10-10 and security fixes until 2027-10-10. PostgreSQL 16 is supported until 2028-11-09. Recheck before publication if it occurs later. Sources: [Ruby](https://www.ruby-lang.org/en/downloads/branches/), [Rails](https://rubyonrails.org/maintenance), [PostgreSQL](https://www.postgresql.org/support/versioning/).

## Installation

Add:

```ruby
gem "acting_for", "~> 0.1.0"
# For Rails 8.0, use the JSON compatibility constraint from the verified Quick Start.
gem "json", "< 3"
```

```sh
bundle install
bin/rails acting_for:install:migrations
bin/rails db:migrate
```

Configure the host's PostgreSQL connection first. The install task copies three migrations into the host's `db/migrate`. Installation, update, and application boot do not copy or apply them automatically. See the [README Quick Start](https://github.com/cuichangquan/acting_for#quick-start) for a new application, host User / Product models, Agent creation, and all three Decision results.

## Public API

```ruby
delegation = ActingFor.delegate(
  agent: resolved_agent,
  principal: resolved_principal,
  action: :purchase,
  resource: Product,
  constraints: [{ field: "amount", operator: "lte", value: 10_000 }],
  effect: :allow,
  expires_at: nil
)

decision = ActingFor.authorize(
  agent: resolved_agent,
  principal: resolved_principal,
  action: :purchase,
  resource: host_loaded_product,
  context: { amount: host_loaded_product.price },
  audit_context_keys: [:amount]
)

# decision.status / allowed? / denied? / approval_required?
# delegation.revoke!
```

The host must provide a persisted `ActingFor::Agent` and persisted ActiveRecord Principal. The host resolves and verifies these example variables; this fragment is an API overview, not provisioning or execution code. `delegate` persists and returns a Delegation. Invalid API inputs and system failures raise exceptions; they are not collapsed into `deny`. There is no `delegate!` or `authorize!` API. See the [Public API contract](https://github.com/cuichangquan/acting_for/blob/v0.1.0/docs/public_api_v0_1.md).

## Host authorization and trust boundaries

The host authenticates the external Agent and resolves Agent / Principal records. It establishes the actual Resource and verifies business-critical Context values. ActingFor evaluates the supplied values; it does not fetch prices, verify ownership, or compare an agent's claims with database facts.

The host checks the Principal's **current** permissions at execution time. Execution requires **Host Authorization AND ActingFor allow**. ActingFor does not call Pundit, CanCanCan, or Action Policy directly. `require_approval` stops execution and enters the host's approval flow; it does not expand Principal permissions.

ActingFor saves the AuditEvent before returning a Decision. If Audit persistence fails, no Decision is returned; the host must stop. System / API failures remain exceptions. Raw Context is not automatically saved in full, and audit field selection does not replace the host's privacy review.

## Outside v0.1 and known limitations

- Agent authentication, login, session management, and Principal / Agent provisioning workflows belong to the host.
- The host executes business operations and enforces Decisions. ActingFor supplies no approval workflow, approval UI, notification, or approved-operation replay.
- ActingFor is not an Agent framework, MCP server, OAuth / OIDC provider, general-purpose policy engine, payment processor, or agent-to-agent communication layer. Core has no MCP protocol dependency.
- PostgreSQL alone is officially supported. Other adapters have no v0.1 support guarantee.
- Model-level immutability and append-only protection do not defend against all direct SQL / database administration. No DB trigger, WORM storage, or cryptographic Audit signing is provided. Host retention and audit access control remain host responsibilities.
- A Decision is the result at authorization time, **not a reusable authorization token**. Authorize close to the protected operation; do not cache Decisions as proof or use stale cached Delegations. The host must read current authoritative Delegation state; asynchronous replicas can be stale.
- ActingFor does not guarantee atomicity with the business operation or eliminate TOCTOU through locking / isolation. The host owns the business transaction boundary.

See the [Security Model](https://github.com/cuichangquan/acting_for/blob/v0.1.0/docs/security_model_v0_1.md) and [Responsibility Boundary](https://github.com/cuichangquan/acting_for/blob/v0.1.0/docs/PROJECT.md).

## Compatibility and license

This is the first release, version `0.1.0`, tag `v0.1.0`. During 0.x, **breaking changes may occur, including Public API changes**. Review future release notes before upgrading. Licensed under the [MIT License](https://github.com/cuichangquan/acting_for/blob/v0.1.0/LICENSE).
