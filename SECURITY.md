# Security Policy

## Scope

This repository contains **documentation files only** (Markdown skill definitions). There is no executable code, no server, and no data storage in this repository.

However, the skills in this repo instruct AI agents to interact with the OKX exchange via the `okx` CLI, which handles real API credentials and can execute live trades. The following guidance applies to that context.

## Credential Safety

- **Never commit API keys, secret keys, or passphrases** to this repository or include them in skill documents
- Skills reference credential paths (`~/.okx/config.toml`) or environment variables — never inline values
- If you accidentally commit credentials, rotate them immediately via the OKX API management portal

## Reporting a Vulnerability

If you discover a security issue in this repository (e.g., a skill document that could mislead an AI agent into unsafe behavior, credential leakage patterns, or prompt injection risks):

1. **Do not open a public GitHub issue**
2. Report privately by emailing the maintainers or using GitHub's private security advisory feature
3. Include a description of the issue and potential impact

We will acknowledge reports within 3 business days and aim to address confirmed issues within 14 days.

## Out of Scope

- Vulnerabilities in the `okx` CLI itself — report those to the [okx-trade-mcp](https://github.com/okx/okx-trade-mcp) repository
- Vulnerabilities in the OKX exchange platform — report via OKX's official security disclosure program
