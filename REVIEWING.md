# Skill Review Checklist

Use this checklist before approving a skill MR. It is organized by priority so reviewers can triage quickly.

---

## 1. Structure (High Priority)

- [ ] **Frontmatter has `---` delimiters** — YAML metadata must be wrapped in `---` markers for the skill engine to parse `name`, `description`, and other fields correctly.
- [ ] **`description` is concise (aim for 80–150 words)** — The description field is always-in-context and used for agent routing, not as a feature spec. Trigger phrases belong here; detailed routing tables go in the body.
- [ ] **File size is under 500 lines** — If the skill exceeds 500 lines, consider a layered architecture (guideline, not a hard gate):
  - `SKILL.md` (~300 lines): core workflow, always loaded
  - `references/cli-commands.md`: detailed CLI parameter tables
  - `references/edge-cases.md`: boundary conditions and error handling
  - `references/examples.md`: input/output examples

---

## 2. Content Accuracy (High Priority)

- [ ] **No phantom tool references** — Every MCP tool or CLI command listed must actually exist and be registered. Cross-check against the real tool registry or CLI help output before approving.
- [ ] **Cross-skill references have fallbacks** — If the skill references other skills (e.g. `okx-cex-portfolio`, `okx-cex-market`), note them as optional dependencies and describe fallback behavior when those skills are not installed.

---

## 3. Interaction Design (Medium Priority)

- [ ] **Confirmation logic is proportional** — WRITE operations should require confirmation. However, if the user's original instruction contains complete parameters and clear execution intent, the summary and execution can be merged into one step. Avoid forcing a redundant confirmation round for explicit commands like "buy 100 USDT of BTC".
- [ ] **Language follows the user** — If the user writes in Chinese, respond in Chinese; if in English, respond in English. Do not hardcode confirmation templates or response phrases in a single language.

---

## 4. Writing Style (Low Priority)

- [ ] **Explain why, not just what** — Prefer explaining the reasoning behind a rule rather than issuing a bare directive. For example: instead of "ALWAYS use `lendingRate` from this endpoint", explain that `avgRate` from `rate-summary` is a historical average (typically 2–3× higher) and is not suitable for display as the current rate.
- [ ] **No excessive repetition** — Each concept (e.g. "demo mode not supported") should be explained in detail once and briefly referenced elsewhere. Repeating the same warning in three sections adds noise without adding clarity.
- [ ] **ALWAYS/NEVER used sparingly** — Reserve all-caps directives for genuine safety constraints (e.g. live trading guards). For style and formatting preferences, use normal casing and explain the rationale instead.
