# ActingFor

*Rails-native delegated authorization for AI agents.*

ActingFor is a Rails-native delegated authorization gem for controlling what AI agents may do on behalf of users.

AI Agentがユーザーの代理として何をしてよいかを、委任された権限に基づいて制御するRails向け認可Gemです。

> **Status: design stage.** This README describes the intended project. The v0.1 product scope is decided, but it is not an implemented or released feature set yet. Its test acceptance criteria are finalized in Step 8; the overall Definition of Done remains a proposal. Step 5 Public API design is complete: 10 of 10 items are decided (Design finalized, not implemented). Step 6 README Quick Start design is complete (Design-stage Quick Start finalized). Step 7 Gem Structure Design is complete (Design finalized / Not implemented). Step 8 Test Strategy is complete (Complete / Design finalized / Not implemented); test code does not exist yet. Security Model Design is complete (Complete / Design finalized / Not implemented). Remaining design details are being refined (D031–D048); open questions remain. The gem remains Not implemented / Not released. The designed support targets are Ruby 3.4 / 4.0, Rails 8.0 / 8.1, and PostgreSQL, with the MIT License; support requires verification in the planned CI matrix. Installation instructions and a runnable Quick Start will follow implementation and verification.

## Why ActingFor?

An agent is a separate actor from the user it represents. A Rails application needs to determine which agent is acting, whose authority it is using, and whether the requested action falls within that delegation.

ActingFor focuses on this delegated authorization problem inside Rails applications.

## Intended model

- **Principal**: the party on whose behalf an agent acts.
- **Agent**: the separate actor requesting an action.
- **Delegation**: the permissions and constraints granted by the principal.
- **Decision**: whether the requested action is allowed, denied, or requires human approval.

## Quick Start

**Design-stage example — not implemented yet.**
The API below shows the intended v0.1 developer experience. ActingFor is not yet released, and these examples are not runnable yet.

### 1. Understand the flow

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

### 2. Prepare an authenticated/resolved Agent

The host application authenticates the external agent, or relies on an external authentication provider, then resolves it to a local `ActingFor::Agent`. Here, `shopping_agent` is that authenticated/resolved Agent. ActingFor holds an Agent representation but provides no agent authentication, login, or session management. It does not require agents to sign up like users. Agent provisioning is not fixed for v0.1; see the [Agent boundary](docs/PROJECT.md#24-agent-registration--resolution-boundary).

### 3. Delegate authority

The Principal grants two Delegations for the `:purchase` Action on the `Product` Resource type. These amounts are example delegation settings, not built-in ActingFor rules. Assume these are the only applicable Delegations, both valid, and prices are Integer amounts in JPY.

The designed creation API is `ActingFor.delegate(...)`; the example below is not implemented yet. Its arguments, defaults, and validation are now specified by D032; v0.1 will not provide `delegate!` ([Delegation API](docs/public_api_v0_1.md#9-delegation-api)).

```ruby
user = current_user # The Principal in this example

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

ActingFor.delegate(
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
```

The second Delegation requires both Constraints to hold. Above ¥30,000, neither Delegation matches, so the Decision is `deny`. There is no explicit deny Delegation.

### 4. Authorize an action

For a product priced at ¥8,900, the host loads the actual Resource and supplies its verified price as Context. The Principal is the same user who delegated authority above.

```ruby
product = Product.find(params[:product_id])

decision = ActingFor.authorize(
  agent: shopping_agent,
  principal: current_user,
  action: :purchase,
  resource: product,
  context: {
    amount: product.price
  }
)
```

> **Security contract:** `ActingFor::Decision` is the authorization result at the time `authorize` is called. It must not be treated as a reusable authorization token. Authorize as close as possible to the protected business operation. Do not reuse cached Decisions as authorization proof or use cached Delegations for authorization. Read Delegation state from an authoritative data source expected to be current; asynchronous replicas can return stale state. ActingFor does not guarantee atomicity with business logic or prevent TOCTOU through DB locking or isolation levels. See the [Security Model](docs/security_model_v0_1.md#13-toctou-boundary).

### 5. Handle the Decision

For the example Delegations:

| Purchase amount | Decision | Meaning |
| --- | --- | --- |
| ¥8,900 | `allow` | Meets ActingFor's Delegation conditions |
| ¥20,000 | `require_approval` | No automatic execution; approval is required |
| ¥50,000 | `deny` | Do not execute |

Inspect `decision.status`, `decision.allowed?`, `decision.denied?`, or `decision.approval_required?`. **`require_approval != allow`**: when approval is required, `decision.allowed?` returns `false`.

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

### 6. Existing authorization still applies

```text
Host Authorization
       AND
ActingFor Authorization
       ↓
Business Logic
```

The host must check the Principal's current permissions at execution time, using Pundit, CanCanCan, Action Policy, or its own authorization. ActingFor Core does not call these directly or replace existing authorization. Even with `allow`, the operation must not execute if the Principal lacks permission. `require_approval` does not expand the Principal's permissions; the host owns the approval workflow.

### 7. Trust only verified Context

The host verifies and establishes business-critical values; ActingFor evaluates Constraints against the supplied Context. Use the host-loaded `product.price` above, rather than blindly trusting an agent-supplied `params[:amount]`. This does not prohibit params in general: agent-supplied business values require verification before use.

ActingFor does not fetch prices from the database, validate currency, check ownership, or compare agent claims with stored values. Those are host business responsibilities. See [Context Trust Boundary](docs/public_api_v0_1.md#13-context-trust-boundary) for input details.

### 8. Audit is automatic

Authorization decisions are automatically recorded as AuditEvents inside `ActingFor.authorize(...)`. No separate audit call is required. Audit Context defaults to `{}`; only fields explicitly selected with `audit_context_keys:` are saved ([Audit Context](docs/public_api_v0_1.md#10-audit)).

If the AuditEvent cannot be saved, authorization raises an exception and no Decision is returned: it neither returns `allow` nor converts the failure to `deny`. The host must not proceed to business logic.

## Responsibility

The host application authenticates the agent and establishes the principal. ActingFor is intended to evaluate delegated authority, alongside the application's existing authorization rules. The host application must check the principal's current permissions at execution time and supply verified Context values. An agent's effective permissions are the intersection of the principal's own permissions and delegated permissions. ActingFor does not call host authorization libraries directly. The host application remains responsible for executing business operations and enforcing authorization decisions.

ActingFor is not an authentication provider, an OAuth/OIDC server, an agent framework, or an MCP server. It aims to remain independent of any particular LLM or agent framework.

The authoritative v0.1 glossary and naming rules are maintained in the [project terminology](docs/PROJECT.md#3-用語定義).

### MCP and ActingFor

> **MCP defines how agents interact with applications. ActingFor defines what agents are authorized to do on behalf of principals within a Rails application.**

ActingFor operates inside the Rails application boundary, evaluating delegated authority after an agent has been authenticated and a request has reached the application.

MCPがAgentとアプリケーションの接続・操作方法を扱うのに対し、ActingForはRailsアプリ内部で、認証済みAgentがPrincipalの代理としてその操作を行う権限を委任されているかを判断する。

The core must remain independent of MCP gems and protocol objects. A future adapter may translate MCP requests into `agent`, `principal`, `action`, `resource`, and `context`; MCP tool names and ActingFor actions are separate concepts. The host application enforces the decision before executing business logic. `require_approval` does not permit execution.

See the [formal responsibility boundary and design rules](docs/PROJECT.md#21-actingforとmcpの正式な責務境界) and [decision D012](docs/DECISIONS.md#d012-actingforとmcpの正式な責務境界).

## v0.1 scope

v0.1 will provide the following delegated-authorization path inside a Rails application:

1. Accept an authenticated principal and agent from the host application.
2. Match the requested action and resource against a delegation from that principal to that agent.
3. Evaluate constraints such as amount, resource, request context, and expiry.
4. Generate an `ActingFor::Decision` value object with status `:allow`, `:deny`, or `:require_approval`.
5. Automatically save an AuditEvent within `authorize` before returning the Decision; raise an exception if saving fails. ActingFor does not execute the business operation.

The Step 8 test acceptance criteria require automated coverage of the allow, deny, approval-required, missing-delegation, expired, and constraint-boundary paths in a supported Rails test application. The domain-model foundation defines three ActiveRecord models: Agent, Delegation, and AuditEvent. Delegation matching rules are decided. Step 5 public API design is finalized; subsequent decisions D031–D048 specify Audit Context selection, exception classes, Resource identity, Delegation and Agent validation, and AuditEvent details. Other database schema and implementation details remain undecided. See the [v0.1 domain model design](docs/domain_model_v0_1.md).

The scope deliberately excludes agent authentication, approval workflow and approval UI, general-purpose policy engines, OAuth/OIDC servers, MCP servers, payments, and agent-to-agent communication. See the [v0.1 scope, test acceptance criteria, and proposed Definition of Done](docs/PROJECT.md#4-v01スコープ) and [decision record D007](docs/DECISIONS.md#d007-v01の具体的な範囲) for details and decision status.

## Project documents

The initial project documents are maintained in Japanese:

- [Project scope, roadmap, and open questions](docs/PROJECT.md)
- [Decisions and their rationale](docs/DECISIONS.md)
- [v0.1 domain model design](docs/domain_model_v0_1.md)
- [v0.1 public API design — Design-stage API / Not implemented yet](docs/public_api_v0_1.md)
- [v0.1 Gem Structure Design — Design finalized / Not implemented](docs/gem_structure_v0_1.md)
- [v0.1 Test Strategy Design — Complete / Design finalized / Not implemented](docs/test_strategy_v0_1.md)
- [v0.1 Security Model Design — Complete / Design finalized / Not implemented](docs/security_model_v0_1.md)
- [GitHub Issues](https://github.com/cuichangquan/acting_for/issues)

The scope document distinguishes finalized product boundaries and test acceptance criteria, the proposed overall Definition of Done, and implemented features. The authoritative Step 5 public API document distinguishes decided design from undecided candidates. The API is not implemented or published yet.

## Planned support and license

The v0.1 CI matrix is Ruby 3.4 / 4.0 × Rails 8.0 / 8.1, using PostgreSQL. Only combinations verified by that matrix will be officially supported. Other DB adapters are not intentionally excluded, but are outside v0.1 support. The project will be published under the MIT License. CI, LICENSE, and gemspec are not implemented yet. See the [support and release policy](docs/PROJECT.md#46-対応環境公開方針d045d048).
