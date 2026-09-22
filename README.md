# ActingFor

**Add delegated authorization behind MCP tools and other agent-driven Rails actions.**

*Rails-native delegated authorization for AI agents.*

MCP can give AI clients a standard way to discover and call tools exposed by your Rails application.

ActingFor answers the next question:

> **Should this Agent be allowed to perform this Action on behalf of this Principal?**

AI AgentがPrincipalの代理として何をしてよいかを、委任された権限に基づいて制御するRails向け認可Gemです。

## Status

> **Released: v0.1.0.** ActingFor 0.1.0 is published on [RubyGems](https://rubygems.org/gems/acting_for) and as [GitHub Release v0.1.0](https://github.com/cuichangquan/acting_for/releases/tag/v0.1.0). The Public API, migrations, models, constraints, automatic Audit persistence, and formal test suite are implemented. CI covers Ruby 3.4 / 4.0, Rails 8.0 / 8.1, and PostgreSQL 16.

## Why ActingFor?

Traditional Rails authorization usually answers:

> **May this user perform this action?**

Once an AI Agent can act through MCP, an API, or another integration, the application also needs to answer:

> **May this Agent perform this action on behalf of this user?**

For example, an MCP server might expose tools such as:

```text
search_products
purchase_product
cancel_order
```

Making those tools callable is only part of the problem. Before Rails executes `purchase_product`, it may still need to know:

```text
Which Agent is acting?
For which Principal?
Was :purchase delegated?
Is ¥8,900 within the delegated limit?
Has the Delegation expired or been revoked?
Is human approval required?
```

That is the layer ActingFor provides.

## MCP + ActingFor in one picture

```text
ChatGPT / Claude / AI Agent
            │
            │ MCP, API, or another integration
            ▼
      Rails Host Application
            │
            │ "purchase_product"
            ▼
         ActingFor
            │
            ├─ Which Agent?
            ├─ Acting for whom?
            ├─ Was :purchase delegated?
            ├─ Do constraints pass?
            ├─ Is the Delegation active?
            └─ Is approval required?
            │
            ▼
   allow / require_approval / deny
            │
            ▼
     Rails Business Logic
```

**MCP gives Agents a way to interact with your Rails application. ActingFor adds delegated authorization behind that interaction.**

ActingFor does not require MCP, and it does not replace MCP. The same authorization layer can sit behind REST APIs, background jobs, internal Agent workflows, or other interfaces.

## What does ActingFor do?

ActingFor answers a focused question: may this authenticated Agent perform this Action on behalf of this Principal, for this Resource and trusted Context?

- **Principal**: the party on whose behalf an Agent acts.
- **Agent**: the separate actor requesting an Action.
- **Delegation**: authority and constraints granted by the Principal.
- **Decision**: `allow`, `deny`, or `require_approval`.

The Principal and Agent are always separate actors. ActingFor evaluates their Delegation; it does not authenticate the Agent or execute the business operation.

## MCP vs ActingFor

| | MCP | ActingFor |
| --- | --- | --- |
| Main role | Connect AI clients to application capabilities | Decide what an Agent may do for a Principal |
| Example | Call `purchase_product` | Decide whether that Agent may purchase |
| Agent authentication | May participate through the surrounding auth flow | Not provided by ActingFor |
| Delegation | Not ActingFor-style delegated authority | Core responsibility |
| Constraints / expiry / revocation | Not ActingFor's role | Core responsibility |
| Authorization audit | Not ActingFor's role | Automatic AuditEvent persistence |

MCP tool names and ActingFor Actions are different concepts. An adapter or host layer may translate an MCP tool call into `agent`, `principal`, `action`, `resource`, and trusted `context`.

See the [formal responsibility boundary](docs/PROJECT.md#21-actingforとmcpの正式な責務境界).

## Delegated purchase example

A Principal can give an Agent only part of their authority:

```text
User A
 │
 │ delegates
 ▼
Shopping Agent
 │
 ├─ search_products       allowed by the host as appropriate
 ├─ purchase <= ¥10,000   delegated
 ├─ purchase > ¥10,000    not covered by this Delegation
 └─ delete_account        not delegated
```

At runtime:

```text
Principal (User)
 │ delegates a constrained :purchase
 ▼
Shopping Agent
 │ requests a purchase
 ▼
Rails Host Application
 │ authenticates the Agent, resolves the Principal,
 │ loads the Product, and establishes trusted Context
 ▼
ActingFor.authorize(...)
 │ evaluates Delegation, constraints, expiry, and revocation
 │ saves an AuditEvent automatically
 ▼
allow / require_approval / deny
 │
 ▼
Rails Host Application enforces the Decision
```

## 30-second example

The host has already authenticated an external caller, resolved it to the local `shopping_agent`, resolved `user`, and loaded `product`:

```ruby
ActingFor.delegate(
  agent: shopping_agent,
  principal: user,
  action: :purchase,
  resource: Product,
  constraints: [
    { field: "amount", operator: "lte", value: 10_000 }
  ],
  effect: :allow
)

decision = ActingFor.authorize(
  agent: shopping_agent,
  principal: user,
  action: :purchase,
  resource: product,
  context: { amount: product.price }
)

decision.allowed? # => true when product.price is 8_900
```

Both calls use the implemented [v0.1 Public API](docs/public_api_v0_1.md). Context values that affect authorization must be established by the host, not trusted directly from an Agent request.

## Quick Start

Install the released `0.1.0` gem from RubyGems.

1. Add the Gem and install dependencies:

   ```ruby
   gem "acting_for", "~> 0.1.0"
   # Rails 8.0 uses JSON options removed in JSON 3.
   gem "json", "< 3"
   ```

   ```sh
   bundle install
   ```

2. Install migrations:

   ```sh
   bin/rails acting_for:install:migrations
   bin/rails db:migrate
   ```

3. In `bin/rails console`, create the local Agent:

   ```ruby
   shopping_agent = ActingFor::Agent.create!(
     identifier: "shopping-agent",
     name: "Shopping Agent"
   )
   ```

4. Create a Delegation:

   ```ruby
   ActingFor.delegate(
     agent: shopping_agent,
     principal: user,
     action: :purchase,
     resource: Product,
     constraints: [
       { field: "amount", operator: "lte", value: 10_000 }
     ],
     effect: :allow
   )
   ```

5. Authorize with host-verified Context:

   ```ruby
   product = Product.find_by!(price: 8_900)
   decision = ActingFor.authorize(
     agent: shopping_agent,
     principal: user,
     action: :purchase,
     resource: product,
     context: { amount: product.price }
   )
   ```

6. Check the Decision before the host performs any operation:

   ```ruby
   [decision.status, decision.allowed?, decision.denied?, decision.approval_required?]
   # => [:allow, true, false, false]
   ```

For the complete runnable setup—including a new Rails application, RubyGems installation, host models, all three `¥8,900 / ¥20,000 / ¥50,000` outcomes, Audit behavior, and production security guidance—see [Getting Started](docs/getting_started.md).

## How does an external AI Agent reach ActingFor?

ActingFor starts **after** the Rails Host Application knows which Agent is making the request.

An external caller such as ChatGPT, Claude, an MCP client, or a custom Agent must first be authenticated or otherwise reliably identified by the host application. The host then resolves that external identity to a local `ActingFor::Agent`.

```text
External AI Agent
(ChatGPT / Claude / MCP Client / custom Agent)
        │
        │ OAuth token / JWT / API credential /
        │ another trusted authentication mechanism
        ▼
Rails Host Application
        │
        ├─ 1. Authenticate or identify the external Agent
        ├─ 2. Resolve it to an ActingFor::Agent
        ├─ 3. Resolve the Principal
        ├─ 4. Load the Resource and trusted Context
        ▼
ActingFor.authorize(...)
        │
        ├─ Delegation
        ├─ Constraints
        ├─ Expiration
        └─ Revocation
        ▼
allow / require_approval / deny
```

**Authentication answers “Which Agent is this?” ActingFor answers “What may this Agent do on behalf of this Principal?”**

### Agent and User are different records

An Agent does not need a second record in the host application's `users` table.

```text
users
└─ User A                         ← Principal

acting_for_agents
└─ Shopping Agent                ← Agent

acting_for_delegations
└─ User A → Shopping Agent → purchase
```

Conceptually:

```ruby
user
# => #<User id: 1>

shopping_agent
# => #<ActingFor::Agent id: 10>
```

The host may call these values `current_user` and `current_agent`, but ActingFor does not provide a `current_agent` authentication helper. Agent authentication and external-identity resolution belong to the host application.

### Responsibility split

| Question | Responsibility |
| --- | --- |
| Which external Agent sent this request? | Host application / authentication layer |
| Which `ActingFor::Agent` does that identity map to? | Host application |
| Which Principal is the Agent acting for? | Host application + Delegation relationship |
| May this Agent perform `purchase` for that Principal? | ActingFor |
| Do amount, expiry, and revocation constraints pass? | ActingFor |
| Should the business operation actually run? | Host application |

### Do I need Agent Authentication before installing ActingFor?

No. ActingFor can be installed independently.

However, if an external AI Agent will call the Rails application directly, the host must authenticate or otherwise reliably identify that Agent and resolve it to an `ActingFor::Agent` before calling `ActingFor.authorize(...)`.

If the application already knows the Agent through an internal trusted workflow, ActingFor can be used without adding an external Agent authentication system first.

### Example Rails stack: Devise + Doorkeeper + MCP + ActingFor

A Rails application can combine familiar components without making ActingFor responsible for authentication or MCP transport.

> **This is one possible Rails integration, not a required ActingFor stack.**

```text
Human User
    │
    │ Devise
    │ authenticate the human
    ▼
Rails Host Application
    │
    │ Doorkeeper / OAuth
    │ issue and validate access tokens
    ▼
MCP Client / AI Agent
    │
    │ MCP tool call
    │ purchase_product(product_id)
    ▼
Rails MCP endpoint
    │
    ├─ validate the surrounding authentication / OAuth context
    ├─ resolve the external identity to an ActingFor::Agent
    ├─ resolve the Principal
    ├─ load the Resource
    └─ establish trusted Context
    ▼
ActingFor.authorize(...)
    │
    ├─ Was :purchase delegated?
    ├─ Do constraints pass?
    ├─ Is the Delegation active?
    └─ Is approval required?
    ▼
allow / require_approval / deny
    │
    ▼
Rails Business Logic
```

The responsibilities remain separate:

| Component | Example responsibility |
| --- | --- |
| Devise | Authenticate the human User / Principal |
| Doorkeeper | Provide OAuth authorization and access-token handling for the Rails application |
| MCP | Expose Rails capabilities such as `purchase_product` to AI clients |
| Rails host application | Validate the caller context, resolve Agent + Principal, load trusted business data, and enforce the Decision |
| ActingFor | Decide what the resolved Agent may do on behalf of the resolved Principal |

The important boundary is that **MCP makes a capability callable, while ActingFor decides whether the resolved Agent may use that capability for this Principal**.

An illustrative host-side mapping might look like:

```ruby
oauth_application = doorkeeper_token.application
user = User.find(doorkeeper_token.resource_owner_id)

shopping_agent = ActingFor::Agent.find_by!(
  identifier: oauth_application.uid
)

decision = ActingFor.authorize(
  agent: shopping_agent,
  principal: user,
  action: :purchase,
  resource: product,
  context: { amount: product.price }
)
```

This example is intentionally simplified. A Doorkeeper application or OAuth client is **not necessarily identical to one AI Agent instance**. For example, one MCP client may front multiple logical Agents. Production applications may therefore need an explicit identity-mapping layer:

```text
Authenticated OAuth / MCP identity
            ↓
Rails identity mapping
            ↓
ActingFor::Agent
            ↓
Principal + Delegation
            ↓
ActingFor.authorize(...)
```

ActingFor does not require Devise, Doorkeeper, or MCP. Existing applications may use another authentication provider, OAuth/OIDC service, API credential, transport, or trusted internal workflow as long as the host can reliably establish the Agent and Principal before calling ActingFor.

## Security / Responsibility Boundary

```text
Host Authorization
       AND
ActingFor Authorization
       ↓
Business Logic
```

The host must authenticate the Agent, resolve the Principal, check the Principal's current permissions, provide trusted Context, enforce the returned Decision, and execute the business operation. ActingFor does not call host authorization libraries directly.

Important parts of the security contract:

- Agent and Principal are separate actors. ActingFor does not authenticate Agents or provide login/session management.
- `require_approval != allow`; approval-required operations must not execute automatically.
- `ActingFor::Decision` describes the result at authorization time. It is not a reusable authorization token or capability.
- Authorize close to the protected operation. Do not reuse cached Decisions or cached Delegations as authorization proof.
- ActingFor automatically persists an AuditEvent inside `authorize`. If Audit persistence fails, no Decision is returned and the host must not proceed.
- ActingFor does not execute business operations or guarantee atomicity with them. The host owns transaction, concurrency, retry, and TOCTOU handling.

See the [Getting Started security guidance](docs/getting_started.md#security-and-responsibility-boundary) and formal [Security Model](docs/security_model_v0_1.md).

## What ActingFor is not

ActingFor is not an authentication provider, OAuth/OIDC server, Agent framework, MCP server, approval workflow, payment system, or general-purpose policy engine. It does not fetch or validate business data, provision external Agents, or perform the authorized operation.

## Official Demo

[ActingFor Demo](https://github.com/cuichangquan/acting_for_demo) is the official real Rails host application. It demonstrates Public API integration, automated host-integration verification, and a workflow for human manual verification. The gem repository remains the source of truth for gem behavior, the Public API, and the Security Contract; the demo verifies those public boundaries without depending on `ActingFor::Internal::*`.

## Documentation

Project documents are maintained primarily in Japanese:

- [Getting Started](docs/getting_started.md)
- [Current State](docs/CURRENT_STATE.md)
- [Progress](docs/PROGRESS.md)
- [Project scope, roadmap, and terminology](docs/PROJECT.md)
- [Decisions and rationale](docs/DECISIONS.md)
- [v0.1 Public API](docs/public_api_v0_1.md)
- [v0.1 Security Model](docs/security_model_v0_1.md)
- [v0.1 Domain Model](docs/domain_model_v0_1.md)
- [v0.1 Gem Structure](docs/gem_structure_v0_1.md)
- [v0.1 Test Strategy](docs/test_strategy_v0_1.md)
- [GitHub Issues](https://github.com/cuichangquan/acting_for/issues)

## Supported Versions

The formal GitHub Actions matrix verifies PostgreSQL 16 with:

| Ruby | Rails |
| --- | --- |
| 3.4 | 8.0 |
| 3.4 | 8.1 |
| 4.0 | 8.0 |
| 4.0 | 8.1 |

Other database adapters are outside v0.1 official support. Formal Minitest and core RuboCop are CI gates. See the [support policy](docs/PROJECT.md#46-対応環境公開方針d045d048).

## License

ActingFor is available under the [MIT License](LICENSE).
