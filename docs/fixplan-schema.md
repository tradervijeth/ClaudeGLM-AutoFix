# FixPlan JSON Contract

Claude must respond to planning requests with JSON that passes validation against `schemas/fixplan.schema.json`. No additional prose, markdown fences, or trailing commentary are allowed.

## High-Level Structure
```json
{
  "plan_version": "1.0",
  "overview": { ... },
  "tasks": [ ... ],
  "tests": { ... },
  "metadata": { ... }
}
```

### Required Fields
- `plan_version`: Always `"1.0"`. Enables orchestrator-side migrations.
- `overview`: Summarizes the failure Claude is addressing.
- `tasks`: Ordered list of actionable steps for GLM.
- `tests`: Commands used to validate the completed plan.
- `metadata`: Bookkeeping about the planning request.

## Task Anatomy
- `id`: `"T"` followed by digits. Stable reference for dependencies.
- `title`: Concise imperative summary, e.g., `"Import Missing Module in GameScene"`.
- `rationale`: Why the change is necessary.
- `acceptance`: At least one bullet describing success criteria.
- `dependencies`: Optional array of task IDs that must complete first.
- `edits`: One or more edit objects (see below).
- `post_checks`: Optional human-readable checklists for the orchestrator to echo.

### Edit Actions
| Action | Description |
| --- | --- |
| `modify_file` | Apply a patch to an existing file. |
| `create_file` | Create a new file with specified instructions. |
| `delete_file` | Remove a file (rare; orchestrator prompts for confirmation). |
| `rename_file` | Rename/move a file. Must include `target_path` and place it in `notes` if rationale is needed. |

Each edit must include:
- `path`: POSIX relative path from repo root.
- `instructions`: What GLM should do.
- `strategy`: `unified_patch` (default) or `file_rewrite`.
- `context_files`: Additional files to supply to GLM when generating the edit.
- `target`: Optional hint for syntax-highlighting / prompt tuning (`swift`, `plist`, `markdown`, `other`).
- `target_path`: Required when `action` is `rename_file`.

## Tests Block
Claude must provide at least one command in `tests.commands`. Typical defaults:
- `xcodebuild -scheme <SchemeName> -configuration Debug build`
- `swift test`

`stop_on_failure`: Determines whether the orchestrator should halt immediately or continue through the command list when a failure occurs.

`max_attempts`: Optional guardrail for iterative repair loops.

## Metadata Block
| Field | Description |
| --- | --- |
| `created_at` | ISO 8601 UTC timestamp. |
| `model` | Claude model string (e.g., `"claude-3.5-sonnet"`). |
| `fix_attempt` | 1-based index of the orchestrator attempt requesting the plan. |

## Example
```json
{
  "plan_version": "1.0",
  "overview": {
    "primary_issue": "GameScene.swift fails to compile because PhysicsWorldDelegate is missing methods.",
    "risk_level": "medium",
    "summary": "Implement delegate stubs and adjust node configuration to satisfy new API requirements.",
    "assumptions": [
      "PhysicsWorldDelegate is only used in GameScene.swift"
    ]
  },
  "tasks": [
    {
      "id": "T1",
      "title": "Implement delegate stubs in GameScene",
      "rationale": "Compiler error indicates protocol requirements were not met.",
      "acceptance": [
        "GameScene conforms to PhysicsWorldDelegate without compiler errors."
      ],
      "edits": [
        {
          "action": "modify_file",
          "path": "Sources/GameScene.swift",
          "target": "swift",
          "instructions": "Add missing delegate method stubs with TODO bodies.",
          "strategy": "unified_patch",
          "context_files": [
            "Sources/GameScene.swift",
            "Sources/PhysicsWorldDelegate.swift"
          ]
        }
      ]
    }
  ],
  "tests": {
    "commands": [
      "xcodebuild -scheme SpaceAdventure -configuration Debug build"
    ],
    "stop_on_failure": true,
    "max_attempts": 2
  },
  "metadata": {
    "created_at": "2024-03-09T14:22:33Z",
    "model": "claude-3.5-sonnet",
    "fix_attempt": 1
  }
}
```

## Validation
- Use `validators/fixplan_validator.js` to confirm the structure before trusting Claude's response.
- The orchestrator must reject any payload that includes extra keys, missing fields, or non-JSON output.
