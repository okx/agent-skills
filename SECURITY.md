# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest release | ✅ |
| Previous minor | ✅ security fixes only |
| Older versions | ❌ |

We recommend always running the latest published version.

## Reporting a Vulnerability

**Please do NOT open a public GitHub issue for security vulnerabilities.**

Report security issues privately via:

- **GitHub Private Advisory:** Use the [Report a vulnerability](../../security/advisories/new) button on the Security tab of this repository.
- **Email:** security@okx.com

Include as much detail as possible: description of the issue, steps to reproduce, potential impact, and any suggested mitigations.

## Priority Issues

The following vulnerability types are treated as **highest priority** due to their potential for financial harm:

- **API key / secret key leakage** — any path that could expose credentials
- **Fund safety** — issues that could cause unintended orders, transfers, or position changes
- **Authentication bypass** — bypassing signature verification or access controls

## Response Timeline

| Stage | Target |
|-------|--------|
| Initial acknowledgement | Within **48 hours** |
| Triage and severity assessment | Within **3 business days** |
| Remediation plan communicated | Within **7 days** |
| Fix released | Depends on severity; critical issues prioritized |

## Scope

This project is a **skill definition layer** — Markdown documents that instruct AI agents how to use the `okx` CLI. The primary attack surfaces are:

1. **Prompt injection** — skill documents are loaded directly into AI agent system prompts. A maliciously crafted skill could embed hidden instructions that override the agent's intended behavior, potentially tricking it into executing dangerous operations (e.g. unauthorized trades, credential exfiltration).
2. **Unplanned behavior** — incorrect command examples, wrong parameter formats, or misleading operation flows in a skill could cause the agent to execute unintended trades, transfers, or position changes.
3. **MCP tool input** — skills define the parameter patterns that AI agents pass to trading tools. Malformed or overly permissive parameter examples could lead to invalid or harmful tool invocations.

Out of scope: vulnerabilities in the `okx` CLI itself (report those to [okx-trade-mcp](https://github.com/okx/agent-trade-kit)), OKX's own platform, or third-party AI agent frameworks.

## Disclosure Policy

We follow [responsible disclosure](https://en.wikipedia.org/wiki/Responsible_disclosure). Once a fix is released, we will credit the reporter (unless anonymity is requested) and publish a summary in the changelog.
