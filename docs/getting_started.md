# Getting Started

This is the detailed runnable introduction to ActingFor. It preserves the code, values, and expected results verified in a new Rails application for [D230](DECISIONS.md#d230-runnable-quick-start-implementation).

ActingFor is not yet released to RubyGems. This guide installs GitHub `main`, which can change; Bundler records the resolved Git revision in `Gemfile.lock`.

## Verified environment

- Ruby 3.4.10
- Rails 8.0.5.1
- PostgreSQL 16.15

Install Ruby 3.4, PostgreSQL 16, and PostgreSQL client development libraries first. The database account must be able to create databases. Configure PostgreSQL through variables such as `PGHOST`, `PGUSER`, and `PGPASSWORD`, or through `config/database.yml`.

The example uses Principal `User`, Shopping Agent, Action `purchase`, Resource `Product`, and integer JPY Context `amount`. These are host examples, not required models or built-in rules. Rails console is only for developer verification; production Agent and Delegation provisioning belongs to the host application.

## 1. Create a new Rails application

```sh
gem install rails -v 8.0.5.1
rails _8.0.5.1_ new shopping_demo --database=postgresql --minimal --skip-bundle --skip-git
cd shopping_demo
```

## 2. Configure the pre-release dependency

The repository is currently private, so Bundler needs repository access and authenticated Git. D230 used an existing GitHub SSH key and agent with this HTTPS-to-SSH rewrite because GitHub's `github:` Gemfile shorthand uses HTTPS:

```sh
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

Use this only in an appropriate development environment, or use an existing authenticated HTTPS setup. Remove the rewrite when no longer needed:

```sh
git config --global --unset url."git@github.com:".insteadOf
```

Add to the generated `Gemfile`:

```ruby
gem "acting_for", github: "cuichangquan/acting_for", branch: "main"
# Rails 8.0 uses JSON options removed in JSON 3.
gem "json", "< 3"
```

```sh
bundle install
```

After a RubyGems release, replace the Git source with the released version requirement.

## 3. Install migrations and create host models

```sh
bin/rails acting_for:install:migrations
bin/rails generate model User name:string
bin/rails generate model Product name:string price:integer
bin/rails db:create db:migrate
```

The Rails Engine task copies three ActingFor migrations into the host's `db/migrate`, with host-assigned timestamps. They create `acting_for_agents`, `acting_for_delegations`, and `acting_for_audit_events`. Installing the Gem and booting the application do not copy or apply migrations automatically.

## 4. Create the Principal, products, and Agent

```sh
bin/rails console
```

Run the Ruby blocks in order on the fresh database:

```ruby
user = User.create!(name: "Quick Start User")
Product.create!(name: "Everyday purchase", price: 8_900)
Product.create!(name: "Approval purchase", price: 20_000)
Product.create!(name: "Outside delegation", price: 50_000)
shopping_agent = ActingFor::Agent.create!(
  identifier: "shopping-agent",
  name: "Shopping Agent"
)
shopping_agent.persisted? # => true
```

The Agent identifier is unique, 1–255 characters, and contains no whitespace. Its optional name must be nonblank. This record is only the host's local representation. In production, the host authenticates the external Agent and resolves it to this record. ActingFor provides no Agent authentication, login, or session management; see the [Agent registration and resolution boundary](PROJECT.md#24-agent-registration--resolution-boundary).

## 5. Create the Delegations

The Principal grants two Delegations for `:purchase` on the `Product` Resource type. The thresholds are example settings, not built-in ActingFor rules. Assume these are the only applicable Delegations and both are valid.

`ActingFor.delegate(...)` returns a persisted Delegation or raises for invalid input or persistence failure. There is no `delegate!`; see the [Delegation API](public_api_v0_1.md#9-delegation-api).

```ruby
allow_delegation = ActingFor.delegate(
  agent: shopping_agent,
  principal: user,
  action: :purchase,
  resource: Product,
  constraints: [
    { field: "amount", operator: "lte", value: 10_000 }
  ],
  effect: :allow
)

approval_delegation = ActingFor.delegate(
  agent: shopping_agent,
  principal: user,
  action: :purchase,
  resource: Product,
  constraints: [
    { field: "amount", operator: "gt", value: 10_000 },
    { field: "amount", operator: "lte", value: 30_000 }
  ],
  effect: :require_approval
)

[allow_delegation.persisted?, approval_delegation.persisted?]
# => [true, true]
```

Both constraints on the second Delegation must hold. Above ¥30,000, neither Delegation matches, so the result is `deny`; this example creates no explicit deny Delegation.

## 6. Authorize the ¥8,900 purchase

The host loads the actual Product and supplies its verified price as Context. The Principal is the same `user` that granted the Delegations.

```ruby
product = Product.find_by!(price: 8_900)

decision = ActingFor.authorize(
  agent: shopping_agent,
  principal: user,
  action: :purchase,
  resource: product,
  context: {
    amount: product.price
  }
)

[decision.status, decision.allowed?, decision.denied?, decision.approval_required?]
# => [:allow, true, false, false]
```

## 7. Verify all three Decisions

The D230-verified results are:

| Purchase amount | Decision | Meaning |
| --- | --- | --- |
| ¥8,900 | `allow` | Meets the Delegation conditions |
| ¥20,000 | `require_approval` | No automatic execution; approval is required |
| ¥50,000 | `deny` | Do not execute |

`require_approval != allow`: an approval-required Decision returns `false` from `allowed?`.

```ruby
product = Product.find_by!(price: 20_000)
approval_decision = ActingFor.authorize(
  agent: shopping_agent, principal: user, action: :purchase,
  resource: product, context: { amount: product.price }
)
[approval_decision.status, approval_decision.allowed?,
 approval_decision.denied?, approval_decision.approval_required?]
# => [:require_approval, false, false, true]

product = Product.find_by!(price: 50_000)
deny_decision = ActingFor.authorize(
  agent: shopping_agent, principal: user, action: :purchase,
  resource: product, context: { amount: product.price }
)
[deny_decision.status, deny_decision.allowed?,
 deny_decision.denied?, deny_decision.approval_required?]
# => [:deny, false, true, false]
```

The host must enforce the result:

```ruby
case decision.status
when :allow
  # Proceed only if host authorization also permits the operation
when :require_approval
  # Stop and start the host application's approval flow
when :deny
  # Do not execute
end
```

## 8. Use trusted Context

The host establishes business-critical values; ActingFor evaluates constraints against the supplied Context. Use the host-loaded `product.price`, as above, instead of blindly trusting an Agent-supplied `params[:amount]`. Agent-supplied business values require verification before use.

ActingFor does not fetch prices, validate currency, check ownership, or compare an Agent's claims with stored data. Those are host responsibilities. See the [Context Trust Boundary](public_api_v0_1.md#13-context-trust-boundary).

## 9. Verify automatic Audit persistence

Every Decision is recorded automatically inside `ActingFor.authorize(...)`; there is no separate Audit call.

```ruby
ActingFor::AuditEvent.order(:id).pluck(:decision)
# => ["allow", "require_approval", "deny"]

audit = ActingFor::AuditEvent.last
[audit.persisted?, audit.decision, audit.sanitized_context]
# => [true, "deny", {}]
```

Audit Context defaults to `{}`. Only fields explicitly selected with `audit_context_keys:` are stored. The `amount` used for authorization is not saved in this example, and raw Context is never automatically persisted in full. See the [Audit API](public_api_v0_1.md#10-audit).

If persistence fails, `ActingFor.authorize(...)` raises `ActingFor::AuditPersistenceError` and returns no Decision. The failure is neither an `allow` nor a normal `deny`; the host must not continue to business logic.


## Integrating with an existing Rails application

ActingFor does not require Agent-specific branches to be scattered throughout controllers and services.

A common integration pattern is to resolve the Principal and optional Agent near the request boundary, then keep authorization close to the protected operation.

```text
Human request
    ↓
Principal + no Agent
    ↓
Host Authorization
    ↓
Business Logic

Agent request
    ↓
Principal + Agent
    ↓
Host Authorization
    AND
ActingFor Authorization
    ↓
Business Logic
```

For example, a host application may centralize the Agent-specific part:

```ruby
def authorize_agent!(agent:, principal:, action:, resource:, context: {})
  return unless agent

  decision = ActingFor.authorize(
    agent: agent,
    principal: principal,
    action: action,
    resource: resource,
    context: context
  )

  raise YourApp::Forbidden unless decision.allowed?
end
```

The host's existing authorization still applies separately:

```ruby
authorize_host!(principal, :purchase, product)

authorize_agent!(
  agent: current_agent,
  principal: principal,
  action: :purchase,
  resource: product,
  context: { amount: product.price }
)

PurchaseService.call(user: principal, product: product)
```

This is an integration pattern, not a required ActingFor architecture. The host may use Devise, Pundit, CanCanCan, Action Policy, JWT, OAuth, or its own authentication and authorization structure.

## Security and Responsibility Boundary

### Existing host authorization still applies

```text
Host Authorization
       AND
ActingFor Authorization
       ↓
Business Logic
```

The host checks the Principal's current permission at execution time through Pundit, CanCanCan, Action Policy, or its own authorization. ActingFor neither replaces nor calls those systems. Even after `allow`, the operation must not execute if the Principal lacks permission. `require_approval` does not expand the Principal's permissions; the host owns the approval workflow.

### Agent and Principal remain separate

The host authenticates the external Agent, resolves it to an `ActingFor::Agent`, and establishes the Principal. ActingFor evaluates the explicit Agent + Principal pair; it does not authenticate either party or infer that they are the same actor.

### Decision reuse and TOCTOU

`ActingFor::Decision` is the result at the instant `authorize` runs. It is not a reusable authorization token, capability, or proof. Authorize as close as possible to the protected operation. Do not cache or reuse Decisions, and do not use cached Delegations as authorization proof.

Delegation revocation, Principal permission changes, or Resource/Context changes require another authorization. Read Delegation state from an authoritative data source expected to be current; asynchronous replicas can return stale state.

ActingFor does not guarantee atomicity between authorization and business execution, lock Delegations with `SELECT ... FOR UPDATE`, or impose a transaction isolation level. Host transaction, concurrency, idempotency, retry, and TOCTOU controls remain host responsibilities. See the formal [TOCTOU Boundary](security_model_v0_1.md#13-toctou-boundary).

### Business execution remains with the host

ActingFor returns and audits a Decision. It does not create the purchase, charge a payment method, mutate the Product, or perform any other business operation. The host must interpret and enforce the Decision safely.

## Production checklist

- Authenticate the Agent and resolve the correct local Agent record.
- Establish the intended Principal separately from the Agent.
- Protect Delegation creation and revocation with host authorization.
- Load the Resource and verify all security-relevant Context in the host.
- Apply host authorization and ActingFor authorization together.
- Treat `require_approval` as a stop, not permission to execute.
- Authorize near execution and never reuse a Decision as a token.
- Stop if Audit persistence fails.
- Let the host execute the business operation and manage its transaction.

For the normative contract, use the [Public API](public_api_v0_1.md) and [Security Model](security_model_v0_1.md). The [README](../README.md) remains the concise project entry point.
