# Prompt Templates

All orchestrator calls should source prompt strings from `prompts/` to keep model behavior deterministic and easy to audit.

## Claude FixPlan Prompt (`prompts/claude_fixplan.txt`)
- Supplies build diagnostics, relevant file excerpts, and prior attempt context.
- Enforces strict JSON output conforming to `schemas/fixplan.schema.json`.
- Provides a failsafe JSON payload for insufficient context scenarios.
- Requires Claude to populate clear `instructions`, `strategy`, and realistic `tests.commands`.

### Template Variables
| Placeholder | Description |
| --- | --- |
| `{{repo_root}}` | Repository name or path shown to Claude. |
| `{{attempt}}` | 1-based attempt index for iterative runs. |
| `{{commands}}` | Build/test commands executed before planning. |
| `{{diagnostics_tokens}}` | Token limit applied to diagnostic snippets. |
| `{{diagnostics}}` | Captured stderr/stdout relevant to the failure. |
| `{{context_files}}` | JSON array of `{ path, language, snippet }` objects. |
| `{{previous_plan_summary}}` | Short recap of prior plans. |
| `{{timestamp}}`, `{{model}}` | Substituted when emitting the failsafe. |

## GLM Apply Prompt (`prompts/glm_apply.txt`)
- Feeds a single FixPlan task, its edit directives, and the necessary source blobs.
- Forces JSON-only responses with either unified diffs or full-file rewrites as specified.
- Guards against commentary, markdown, or unrelated edits.
- Supports fallback when context is insufficient (`notes: ["insufficient_context"]`).

### Template Variables
| Placeholder | Description |
| --- | --- |
| `{{task_id}}`, `{{task_title}}`, `{{task_rationale}}` | Copied from the active FixPlan task. |
| `{{task_acceptance}}` | Bullet list of acceptance criteria. |
| `{{task_edits}}` | JSON representation of the task's edit directives. |
| `{{source_blobs}}` | Array of `{ path, language, original }` objects for GLM reference. |

## Prompt Rendering
Use a lightweight templating helper (e.g., `src/utils/template.js`) that replaces `{{variable}}` tokens with runtime strings. Ensure substitutions are escaped appropriately (especially inside JSON literals).

## Future Enhancements
- Introduce localization tokens for different programming languages or build systems.
- Add model-specific system prompts when integrating via MCP.
- Capture prompt versions in metadata for reproducibility.
