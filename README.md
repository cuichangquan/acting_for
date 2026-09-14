# ActingFor

*Rails-native delegated authorization for AI agents.*

ActingFor is a Rails-native delegated authorization gem for controlling what AI agents may do on behalf of users.

AI Agentがユーザーの代理として何をしてよいかを、委任された権限に基づいて制御するRails向け認可Gemです。

> **Status: design stage.** This README describes the intended project. The v0.1 product scope is decided, but it is not an implemented or released feature set yet. Its detailed acceptance criteria remain a proposal. The public API, supported Ruby/Rails versions, and license remain to be finalized. Installation instructions and a runnable Quick Start will follow implementation and verification.

## Why ActingFor?

An agent is a separate actor from the user it represents. A Rails application needs to determine which agent is acting, whose authority it is using, and whether the requested action falls within that delegation.

ActingFor focuses on this delegated authorization problem inside Rails applications.

## Intended model

- **Principal**: the party on whose behalf an agent acts.
- **Agent**: the separate actor requesting an action.
- **Delegation**: the permissions and constraints granted by the principal.
- **Decision**: whether the requested action is allowed, denied, or requires human approval.

The following is an illustrative delegation, not a set of built-in rules:

| Requested action | Decision |
| --- | --- |
| Search products | `allow` |
| Add a product to the cart | `allow` |
| Purchase for up to JPY 10,000 | `allow` |
| Purchase for more than JPY 10,000 | `require_approval` |
| Delete the account | `deny` |

`require_approval` does not authorize execution. ActingFor reports that approval is required; the host application owns the approval workflow.

## Responsibility

The host application authenticates the agent and establishes the principal. ActingFor is intended to evaluate delegated authority, alongside the application's existing authorization rules. The host application remains responsible for executing business operations and enforcing authorization decisions.

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
4. Return `allow`, `deny`, or `require_approval`.
5. Record an audit log for the authorization decision without executing the business operation.

The proposed completion criteria require automated coverage of the allow, deny, approval-required, missing-delegation, expired, and constraint-boundary paths in a supported Rails test application. The domain-model foundation defines three ActiveRecord models: Agent, Delegation, and AuditEvent. Delegation matching details, the public API, database schema details, and audit filtering remain to be finalized. See the [v0.1 domain model design](docs/domain_model_v0_1.md).

The scope deliberately excludes agent authentication, approval workflow and approval UI, general-purpose policy engines, OAuth/OIDC servers, MCP servers, payments, and agent-to-agent communication. See the [v0.1 scope and proposed acceptance criteria](docs/PROJECT.md#4-v01スコープ) and [decision record D007](docs/DECISIONS.md#d007-v01の具体的な範囲) for details and decision status.

## Project documents

The initial project documents are maintained in Japanese:

- [Project scope, roadmap, and open questions](docs/PROJECT.md)
- [Decisions and their rationale](docs/DECISIONS.md)
- [v0.1 domain model design](docs/domain_model_v0_1.md)
- [GitHub Issues](https://github.com/cuichangquan/acting_for/issues)

The scope document distinguishes finalized product boundaries, proposed acceptance criteria, and implemented features. API examples from the initial project materials are design sketches, not a published API.
