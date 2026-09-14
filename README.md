# ActingFor

*Rails-native delegated authorization for AI agents.*

ActingFor is a Rails-native delegated authorization gem for controlling what AI agents may do on behalf of users.

AI Agentがユーザーの代理として何をしてよいかを、委任された権限に基づいて制御するRails向け認可Gemです。

> **Status: design stage.** This README describes the intended project. The v0.1 scope, public API, supported Ruby/Rails versions, and license are not yet finalized. Installation instructions and a runnable Quick Start will follow implementation and verification.

## Why ActingFor?

An agent is a separate actor from the user it represents. A Rails application needs to determine which agent is acting, whose authority it is using, and whether the requested action falls within that delegation.

ActingFor focuses on this delegated authorization problem inside Rails applications.

## Intended model

- **Principal**: the user on whose behalf an agent acts.
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

`require_approval` does not authorize execution. Approval handling and the conditions for a later execution remain part of the design work.

## Responsibility

The host application authenticates the agent and establishes the principal. ActingFor is intended to evaluate delegated authority, alongside the application's existing authorization rules. The host application remains responsible for executing business operations and enforcing authorization decisions.

ActingFor is not an authentication provider, an OAuth/OIDC server, an agent framework, or an MCP server. It aims to remain independent of any particular LLM or agent framework.

## Project documents

The initial project documents are maintained in Japanese:

- [Project scope, roadmap, and open questions](docs/PROJECT.md)
- [Decisions and their rationale](docs/DECISIONS.md)
- [GitHub Issues](https://github.com/cuichangquan/acting_for/issues)

The scope document distinguishes planned features from finalized decisions. API examples from the initial project materials are design sketches, not a published API.
