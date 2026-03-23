# Tool Guide for Subagents

## Available Tools in Claude Agent SDK

| Tool | What it does | Safe for subagents? |
|---|---|---|
| `Read` | Read file contents | ✅ Yes |
| `Write` | Create or overwrite files | ⚠️ Use deliberately |
| `Edit` | Targeted in-place file edits | ⚠️ Use deliberately |
| `Grep` | Search file contents by pattern | ✅ Yes |
| `Glob` | Find files by path pattern | ✅ Yes |
| `Bash` | Run shell commands | ⚠️ Restrict carefully |
| `WebSearch` | Search the web | ✅ Yes |
| `WebFetch` | Fetch a URL | ✅ Yes |
| `Agent` | Spawn another subagent | ❌ NEVER in subagents |

## Recommended Combinations

### Read-only analysis (safest)
```
tools: ["Read", "Grep", "Glob"]
```
Use for: code review, architecture analysis, documentation review, security auditing (read-only), summarization.

### Research assistant
```
tools: ["Read", "Grep", "Glob", "WebSearch", "WebFetch"]
```
Use for: competitive research, documentation lookup, fact-checking against external sources.

### Test runner
```
tools: ["Bash", "Read", "Grep"]
```
Use for: running test suites, linting, build verification, CI-style checks.

### Code modifier
```
tools: ["Read", "Edit", "Write", "Grep", "Glob"]
```
Use for: refactoring, auto-fixing lint errors, applying code style, scaffolding new files.

### Full-stack automator (inherits all parent tools)
```
# Omit the tools field entirely
```
Use for: complex multi-step tasks where restricting tools would limit usefulness.

## Tool Selection Principles

1. **Least privilege** — give the agent only the tools it needs, nothing more
2. **Match the risk** — `Bash` and `Write` can cause irreversible changes; require them intentionally
3. **Grep + Glob are almost always useful** — include them for any agent that explores a codebase
4. **Never include `Agent`** — subagents cannot spawn child subagents

## Model × Tool pairing heuristics

| Model | Best paired with | Reasoning |
|---|---|---|
| `haiku` | `Read`, `Grep`, `Glob` | Fast, cheap; ideal for read-heavy classification |
| `sonnet` | Any combination | Balanced — default choice |
| `opus` | `Bash`, `Edit`, `Write` (high-stakes) | Strong reasoning for risky or complex actions |
