---
name: subagent-creator
description: >
  Use this skill whenever a user wants to create, design, or generate subagents for the Claude Agent SDK.
  Triggers include: "서브 에이전트 만들어줘", "subagent 생성", "에이전트 설계", "create a subagent", "make me an agent",
  "write an agent definition", "전문 에이전트 구성", "Claude SDK 에이전트", "병렬 에이전트", "코드 리뷰 에이전트", or any prompt
  describing a specialized task that should be delegated to an autonomous Claude agent.
  Always use this skill proactively when the user describes an autonomous, task-focused AI worker — even if they
  don't say "subagent" explicitly. This skill produces ready-to-use AgentDefinition code (Python and/or TypeScript)
  plus a markdown spec file suitable for filesystem-based deployment.
---

# Subagent Creator

This skill transforms a plain-language description into a fully-specified Claude Agent SDK subagent, including:
- A sharply scoped **system prompt** (the subagent's expertise and operating constraints)
- A precise **description** field Claude uses to decide when to invoke the agent
- An optimal **tool set** matched to the agent's responsibilities
- A recommended **model tier** (haiku / sonnet / opus)
- Ready-to-run **Python and TypeScript code snippets**
- An optional **filesystem-based markdown spec** (`.claude/agents/<name>.md`)

---

## Step 1 — Understand What the User Wants

Extract these details from the user's prompt. Ask only for what is missing or ambiguous:

| Question | Why it matters |
|---|---|
| What is the agent's single, primary responsibility? | Drives the system prompt focus |
| What inputs does it receive? (files, queries, structured data…) | Sets context expectations |
| What outputs does it produce? (summary, code diff, JSON…) | Sets response format |
| Should it read, write, or execute? | Determines tool set |
| How much autonomy / how many steps? | Influences model tier |
| Does it need to call other subagents? (not supported) | Flag constraint early |
| Language preference for code output? (Python / TypeScript / both) | Output format |

**Do not ask all questions at once.** If the user's prompt already answers most of them, proceed directly to design.

---

## Step 2 — Design the Agent

### 2a. Name the agent
- Lowercase, hyphenated slug: `code-reviewer`, `data-extractor`, `security-scanner`
- One name per responsibility — avoid generic names like `helper` or `agent`

### 2b. Write the `description` field
This is the most critical field — it controls **when Claude invokes the agent**.

Rules for a great description:
- Start with the agent's role/expertise in ≤ 10 words
- List 2-4 specific trigger situations (use "Use for…" or "Invoke when…")
- Include example task phrasings the user might say
- Be specific enough to avoid false positives

Bad: `"Helps with code"`  
Good: `"Expert Python code reviewer. Use for quality, security, and performance reviews of Python files. Invoke when the user asks to review, audit, or improve Python code."`

### 2c. Write the system prompt (`prompt` field)
Structure:
```
You are a [role] specializing in [domain].

[2-3 sentences of core expertise and approach]

When [task type], you:
- [specific behavior 1]
- [specific behavior 2]
- [specific behavior 3]

Output format: [describe expected output structure]
[Any constraints: never do X, always do Y]
```

Keep it under 400 words. Be concrete and behavioral, not aspirational.

### 2d. Select tools
Choose the minimum set the agent needs. Reference the table in `references/tool-guide.md`.

| Agent type | Recommended tools |
|---|---|
| Read-only analyst | `Read`, `Grep`, `Glob` |
| Test runner | `Bash`, `Read`, `Grep` |
| Code modifier | `Read`, `Edit`, `Write`, `Grep`, `Glob` |
| Research assistant | `Read`, `Grep`, `Glob`, `WebSearch` |
| Full automation | omit `tools` (inherits all) |

**Never include `Agent` in a subagent's tool list** — subagents cannot spawn their own subagents.

### 2e. Select model tier
| Tier | Use when |
|---|---|
| `haiku` | High-volume, simple extraction, classification |
| `sonnet` | Default for most tasks — balanced speed/quality |
| `opus` | Complex reasoning, strict security reviews, multi-step planning |

Omit `model` to inherit from the parent agent.

---

## Step 3 — Generate Output

Always produce **all three** output sections below.

### Output A — Python snippet

```python
from claude_agent_sdk import AgentDefinition

agents = {
    "<agent-name>": AgentDefinition(
        description="<description>",
        prompt="""<system prompt>""",
        tools=["<tool1>", "<tool2>"],  # omit to inherit all
        model="<sonnet|opus|haiku>",   # omit to inherit
    ),
}
```

Embed inside a full `query()` call if the user wants runnable code.

### Output B — TypeScript snippet

```typescript
import { AgentDefinition } from "@anthropic-ai/claude-agent-sdk";

const agents = {
  "<agent-name>": {
    description: "<description>",
    prompt: `<system prompt>`,
    tools: ["<tool1>", "<tool2>"],
    model: "<sonnet|opus|haiku>",
  } satisfies AgentDefinition,
};
```

### Output C — Filesystem markdown spec

For use in `.claude/agents/<agent-name>.md`:

```markdown
---
name: <agent-name>
description: <description>
tools: <tool1>, <tool2>
model: <sonnet|opus|haiku>
---

<system prompt body>
```

---

## Step 4 — Explain Design Decisions

After presenting the code, add a brief "Design notes" section:
- Why this tool set was chosen
- Why this model tier was selected
- Any limitations or caveats the user should know
- How to invoke explicitly: `"Use the <agent-name> agent to…"`

---

## Step 5 — Offer to Refine or Extend

Suggest natural follow-ups:
- Creating a second complementary subagent (e.g., a `test-runner` to accompany a `code-reviewer`)
- Wrapping into a complete `query()` harness with parent agent setup
- Generating a dynamic agent factory function for runtime configuration
- Creating multiple agents for parallelization

---

## Key Constraints to Always Respect

1. **Subagents cannot spawn subagents** — never add `Agent` to a subagent's `tools`
2. **Context isolation** — subagents start fresh; the parent must pass all needed context in the Agent tool prompt
3. **Only the final message returns** — design prompts so the agent's last message is a complete, useful result
4. **Filesystem agents load at startup** — warn users that new `.claude/agents/` files need a session restart
5. **Windows prompt length limit** — 8191 chars on Windows; keep prompts concise for cross-platform use

---

## Reference files

- `references/tool-guide.md` — Full tool list with descriptions, read when user asks about specific tools
- `references/examples.md` — Complete worked examples for common agent archetypes
