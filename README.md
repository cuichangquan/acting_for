# ActingFor

*Rails-native delegated authorization for AI agents.*

ActingFor is a Rails-native delegated authorization gem for controlling what AI agents may do on behalf of users.

AI Agentがユーザーの代理として何をしてよいかを、委任された権限に基づいて制御するRails向け認可Gemです。

> **Status: implemented and CI verified; Not released.** Gem skeleton, migrations, models, `delegate`, `authorize`, Decision, Constraints, and automatic Audit persistence are implemented. Formal tests and core RuboCop pass in GitHub Actions across all four supported Ruby / Rails combinations with PostgreSQL 16. The runnable Quick Start below is verified in a new Rails application (D230). ActingFor has not been published to RubyGems.

## Why ActingFor?

An agent is a separate actor from the user it represents. A Rails application needs to determine which agent is acting, whose authority it is using, and whether the requested action falls within that delegation.

ActingFor focuses on this delegated authorization problem inside Rails applications.

## Model

- **Principal**: the party on whose behalf an agent acts.
- **Agent**: the separate actor requesting an action.
- **Delegation**: the permissions and constraints granted by the principal.
- **Decision**: whether the requested action is allowed, denied, or requires human approval.

## Quick Start

This pre-release Quick Start installs GitHub `main`, not a RubyGems release. Verified with Ruby 3.4.10, Rails 8.0.5.1, and PostgreSQL 16.15 in a **new** Rails application. Install Ruby 3.4, PostgreSQL 16, and PostgreSQL client development libraries first; the database account must be able to create databases. Configure your local PostgreSQL connection (for example `PGHOST`, `PGUSER`, and `PGPASSWORD`, or `config/database.yml`).

The example uses Principal `User`, Shopping Agent, Action `purchase`, Resource `Product`, and integer JPY Context `amount`. These are host examples, not required models or built-in business rules. Rails console is used for developer verification; production Agent / Delegation provisioning and management belong to the host application. No controller, route, view, or approval UI is needed.

### 1. Install in a new Rails application

```sh
gem install rails -v 8.0.5.1
rails _8.0.5.1_ new shopping_demo --database=postgresql --minimal --skip-bundle --skip-git
cd shopping_demo
```

The repository is currently private: your GitHub account needs repository access. Authenticate Git access first. This verification used an existing GitHub SSH key / agent and the following HTTPS-to-SSH rewrite (GitHub's `github:` Gemfile shorthand uses HTTPS):

```sh
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

Use this in an isolated development environment, or use your existing authenticated HTTPS setup. The rewrite applies to GitHub URLs for that Git user; remove it with `git config --global --unset url."git@github.com:".insteadOf` when no longer needed.

Add to the generated `Gemfile`:

```ruby
gem "acting_for", github: "cuichangquan/acting_for", branch: "main"
# Rails 8.0 uses JSON options removed in JSON 3.
gem "json", "< 3"
```

```sh
bundle install
```

`main` can change; Bundler records the resolved Git revision in `Gemfile.lock`. After a RubyGems release, this Git source can be replaced with the released version requirement.

### 2. Copy migrations and prepare host models

Run the Rails Engine standard task explicitly, then generate the two minimal host models:

```sh
bin/rails acting_for:install:migrations
bin/rails generate model User name:string
bin/rails generate model Product name:string price:integer
bin/rails db:create db:migrate
```

The install task copies three ActingFor migrations into the host's `db/migrate`; Rails assigns their timestamps. Migration creates `acting_for_agents`, `acting_for_delegations`, and `acting_for_audit_events`. Gem installation and application boot do not copy or apply migrations automatically.

### 3. Understand the flow

A Shopping Agent purchases a product on behalf of a Principal:

```text
Principal
   ↓ delegates
Shopping Agent
   ↓ requests :purchase
Host Application
   ↓
ActingFor.authorize(...)
   ↓
allow / deny / require_approval
   ↓
Host Application decides what to do next
```

ActingFor evaluates delegated authority; it does not execute business logic.

### 4. Create the Principal, products, and Agent

```sh
bin/rails console
```

In the console, run each Ruby block below in order on the fresh database:

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

The Agent's identifier is unique, 1–255 characters, with no whitespace; its optional name must be nonblank when supplied. This creates the local Agent representation only. In production the host authenticates the external agent and resolves it to this record. ActingFor provides no agent authentication, login, or session management; see the [Agent boundary](docs/PROJECT.md#24-agent-registration--resolution-boundary).

### 5. Delegate authority

The Principal grants two Delegations for the `:purchase` Action on the `Product` Resource type. These amounts are example delegation settings, not built-in ActingFor rules. Assume these are the only applicable Delegations, both valid, and prices are Integer amounts in JPY.

`ActingFor.delegate(...)` returns a persisted Delegation or raises an exception for invalid input or persistence failure; there is no `delegate!` ([Delegation API](docs/public_api_v0_1.md#9-delegation-api)).

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
    { field: "amount", operator: "gt",  value: 10_000 },
    { field: "amount", operator: "lte", value: 30_000 }
  ],
  effect: :require_approval
)
[allow_delegation.persisted?, approval_delegation.persisted?] # => [true, true]
```

The second Delegation requires both Constraints to hold. Above ¥30,000, neither Delegation matches, so the Decision is `deny`. There is no explicit deny Delegation.

### 6. Authorize an action

For a product priced at ¥8,900, the host loads the actual Resource and supplies its verified price as Context. The Principal is the same user who delegated authority above.

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
```

> **Security contract:** `ActingFor::Decision` is the authorization result at the time `authorize` is called. It must not be treated as a reusable authorization token. Authorize as close as possible to the protected business operation. Do not reuse cached Decisions as authorization proof or use cached Delegations for authorization. Read Delegation state from an authoritative data source expected to be current; asynchronous replicas can return stale state. ActingFor does not guarantee atomicity with business logic or prevent TOCTOU through DB locking or isolation levels. See the [Security Model](docs/security_model_v0_1.md#13-toctou-boundary).

### 7. Check all three Decisions

For the example Delegations:

| Purchase amount | Decision | Meaning |
| --- | --- | --- |
| ¥8,900 | `allow` | Meets ActingFor's Delegation conditions |
| ¥20,000 | `require_approval` | No automatic execution; approval is required |
| ¥50,000 | `deny` | Do not execute |

Inspect `decision.status`, `decision.allowed?`, `decision.denied?`, or `decision.approval_required?`. **`require_approval != allow`**: when approval is required, `decision.allowed?` returns `false`.

```ruby
[decision.status, decision.allowed?, decision.denied?, decision.approval_required?]
# => [:allow, true, false, false]

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

```ruby
case decision.status
when :allow
  # Host Application may proceed only if host authorization also permits it
when :require_approval
  # Stop and start the host application's approval flow
when :deny
  # Do not execute
end
```

### 8. Existing authorization still applies

```text
Host Authorization
       AND
ActingFor Authorization
       ↓
Business Logic
```

The host must check the Principal's current permissions at execution time, using Pundit, CanCanCan, Action Policy, or its own authorization. ActingFor Core does not call these directly or replace existing authorization. Even with `allow`, the operation must not execute if the Principal lacks permission. `require_approval` does not expand the Principal's permissions; the host owns the approval workflow.

### 9. Trust only verified Context

The host verifies and establishes business-critical values; ActingFor evaluates Constraints against the supplied Context. Use the host-loaded `product.price` above, rather than blindly trusting an agent-supplied `params[:amount]`. This does not prohibit params in general: agent-supplied business values require verification before use.

ActingFor does not fetch prices from the database, validate currency, check ownership, or compare agent claims with stored values. Those are host business responsibilities. See [Context Trust Boundary](docs/public_api_v0_1.md#13-context-trust-boundary) for input details.

### 10. Audit is automatic

Authorization decisions are automatically recorded as AuditEvents inside `ActingFor.authorize(...)`. No separate audit call is required. Audit Context defaults to `{}`; only fields explicitly selected with `audit_context_keys:` are saved ([Audit Context](docs/public_api_v0_1.md#10-audit)).

Inspect the automatically persisted results in the same console:

```ruby
ActingFor::AuditEvent.order(:id).pluck(:decision)
# => ["allow", "require_approval", "deny"]
audit = ActingFor::AuditEvent.last
[audit.persisted?, audit.decision, audit.sanitized_context]
# => [true, "deny", {}]
```

The `amount` supplied for authorization is not saved by default; this example does not select any Audit Context fields. Raw Context is never automatically saved in full.

If the AuditEvent cannot be saved, authorization raises an exception and no Decision is returned: it neither returns `allow` nor converts the failure to `deny`. The host must not proceed to business logic.

## Responsibility

The host application authenticates the agent and establishes the principal. ActingFor evaluates delegated authority alongside the application's existing authorization rules. The host application must check the principal's current permissions at execution time and supply verified Context values. An agent's effective permissions are the intersection of the principal's own permissions and delegated permissions. ActingFor does not call host authorization libraries directly. The host application remains responsible for executing business operations and enforcing authorization decisions.

ActingFor is not an authentication provider, an OAuth/OIDC server, an agent framework, or an MCP server. It aims to remain independent of any particular LLM or agent framework.

The authoritative v0.1 glossary and naming rules are maintained in the [project terminology](docs/PROJECT.md#3-用語定義).

### MCP and ActingFor

> **MCP defines how agents interact with applications. ActingFor defines what agents are authorized to do on behalf of principals within a Rails application.**

ActingFor operates inside the Rails application boundary, evaluating delegated authority after an agent has been authenticated and a request has reached the application.

MCPがAgentとアプリケーションの接続・操作方法を扱うのに対し、ActingForはRailsアプリ内部で、認証済みAgentがPrincipalの代理としてその操作を行う権限を委任されているかを判断する。

The core must remain independent of MCP gems and protocol objects. A future adapter may translate MCP requests into `agent`, `principal`, `action`, `resource`, and `context`; MCP tool names and ActingFor actions are separate concepts. The host application enforces the decision before executing business logic. `require_approval` does not permit execution.

See the [formal responsibility boundary and design rules](docs/PROJECT.md#21-actingforとmcpの正式な責務境界) and [decision D012](docs/DECISIONS.md#d012-actingforとmcpの正式な責務境界).

## v0.1 scope

The implemented v0.1 scope provides the following delegated-authorization path inside a Rails application:

1. Accept an authenticated principal and agent from the host application.
2. Match the requested action and resource against a delegation from that principal to that agent.
3. Evaluate constraints such as amount, resource, request context, and expiry.
4. Generate an `ActingFor::Decision` value object with status `:allow`, `:deny`, or `:require_approval`.
5. Automatically save an AuditEvent within `authorize` before returning the Decision; raise an exception if saving fails. ActingFor does not execute the business operation.

The formal test suite covers allow, deny, approval-required, missing-delegation, expired, and constraint-boundary paths, plus Audit, Engine / Migration integration, and host authorization boundaries. The domain foundation consists of three ActiveRecord models: Agent, Delegation, and AuditEvent. Public APIs and schema are implemented according to the recorded decisions. See the [v0.1 domain model design](docs/domain_model_v0_1.md).

The scope deliberately excludes agent authentication, approval workflow and approval UI, general-purpose policy engines, OAuth/OIDC servers, MCP servers, payments, and agent-to-agent communication. See the [v0.1 scope, test acceptance criteria, and Definition of Done](docs/PROJECT.md#4-v01スコープ) and [decision record D007](docs/DECISIONS.md#d007-v01の具体的な範囲) for details and decision status.

## Project documents

The project documents are maintained in Japanese:

- [Project scope, roadmap, and open questions](docs/PROJECT.md)
- [Decisions and their rationale](docs/DECISIONS.md)
- [v0.1 domain model design](docs/domain_model_v0_1.md)
- [v0.1 public API design](docs/public_api_v0_1.md)
- [v0.1 Gem Structure Design](docs/gem_structure_v0_1.md)
- [v0.1 Test Strategy Design](docs/test_strategy_v0_1.md)
- [v0.1 Security Model Design](docs/security_model_v0_1.md)
- [GitHub Issues](https://github.com/cuichangquan/acting_for/issues)

The documents record design rationale and historical decisions; current implementation progress is summarized in [Current State](docs/CURRENT_STATE.md) and [Progress](docs/PROGRESS.md). Public APIs are implemented; the gem remains Not released.

## CI-verified support and license

The formal GitHub Actions matrix verifies all four v0.1 supported combinations with PostgreSQL 16:

| Ruby | Rails |
| --- | --- |
| 3.4 | 8.0 |
| 3.4 | 8.1 |
| 4.0 | 8.0 |
| 4.0 | 8.1 |

Other DB adapters are outside v0.1 official support; this is not a claim that they cannot work. Formal Minitest and core RuboCop are CI gates. The gemspec and [MIT License](LICENSE) are implemented. ActingFor has not been released to RubyGems. See the [support and release policy](docs/PROJECT.md#46-対応環境公開方針d045d048).
