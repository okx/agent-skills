# Contributing to agent-skills

Thank you for your interest in contributing! This repository welcomes skill additions, corrections, and improvements.

## What is a skill?

A skill is a single Markdown file (`SKILL.md`) that teaches an AI agent how to use a CLI tool for a specific category of tasks. Each skill lives in its own subdirectory under `skills/`.

## How to add a new skill

1. Create a directory: `skills/<skill-name>/`
2. Create `skills/<skill-name>/SKILL.md` with the required frontmatter (see below)
3. Open a pull request with a clear description of what the skill covers

### Required frontmatter

```yaml
---
name: skill-name
description: "One-sentence description used by the agent routing system. List the natural-language phrases and scenarios this skill handles."
license: MIT
metadata:
  author: your-name-or-org
  version: "1.0.0"
  agent:
    requires:
      bins: ["cli-tool-name"]
---
```

The `description` field is critical — it is parsed by the agent to decide which skill to activate. Be specific and enumerate realistic user phrases.

### Skill document structure

A well-formed skill document includes:

- **Prerequisites** — install instructions and credential setup
- **Demo vs Live Mode** — if the CLI supports simulated trading, explain the flag
- **Skill Routing** — clarify what this skill does and does not cover, and point to related skills
- **Quickstart** — 3–5 working commands a user can run immediately
- **Command Index** — table of all commands with READ/WRITE classification
- **Operation Flow** — step-by-step decision guide for common tasks
- **CLI Command Reference** — parameter tables for each command
- **MCP Tool Reference** — map CLI commands to underlying tool names
- **Input / Output Examples** — realistic user requests with expected commands and outputs
- **Edge Cases** — common pitfalls and how to handle them

## How to improve an existing skill

- Fix incorrect commands or parameter names against the actual CLI source
- Add missing commands that exist in the CLI but are not documented
- Improve `description` trigger phrases for better agent routing
- Add new cross-skill workflow examples

## Pull request checklist

- [ ] Skill frontmatter is complete and valid YAML
- [ ] All CLI commands have been verified against the actual CLI binary
- [ ] WRITE commands are clearly marked and include safety confirmation notes
- [ ] No internal URLs, credentials, or personally identifiable information included
- [ ] `license: MIT` is set in frontmatter

### For reviewers

Before approving a skill MR, reviewers should follow the [Skill Review Checklist](REVIEWING.md).

## Reporting issues

Open a GitHub issue for:
- Incorrect or outdated CLI commands
- Missing skills for supported CLI modules
- Routing conflicts between skills

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
