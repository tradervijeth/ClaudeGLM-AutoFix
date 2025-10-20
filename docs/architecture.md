# Claude/GLM Auto-Fix Architecture

## Vision
Build an autonomous Swift/Xcode development loop where Claude performs high-level reasoning, GLM applies code changes, and a Node.js supervisor orchestrates compilation, testing, and iteration. The system should feel like an AI pair-programmer that can take a failing build, propose a structured fix, implement it, and verify the result without manual intervention.

## Core Roles
- **Claude (brain)**: Consumes compiler/test diagnostics, existing code context, and orchestrator state. Produces a strict JSON FixPlan with tasks, rationale, and acceptance criteria. Provides narrative explanations only when explicitly requested.
- **GLM (hands)**: Receives the FixPlan, relevant files, and edit constraints. Returns file patches or direct file replacements that satisfy the plan without extra commentary.
- **Node.js orchestrator (supervisor)**: Manages build execution, context gathering, LLM calls, validation, and iteration. Owns safeguards, schema enforcement, and process logging.

## Key Modules
| Module | Responsibility |
| --- | --- |
| `runBuild` | Executes Swift/Xcode builds/tests (`xcodebuild`, `swift test`, custom commands) and captures structured diagnostics. |
| `callClaude` | Normalizes prompts, calls the Anthropic API, validates FixPlan JSON against schema. |
| `callGLM` | Calls the GLM 4.6/4.5 APIs with constrained prompts, streaming edits or patches. |
| `readFiles` | Pulls source snippets with configurable context windows and redaction for secrets. |
| `applyPatch` | Applies unified diffs or full-file replacements atomically, with backups and validation. |
| `auto_fix` | High-level pipeline: build → FixPlan → edits → rebuild → iterate/abort. |
| `logger` | Structured logging with verbosity levels and timestamps. |

## Data Flow
1. `auto_fix` invokes `runBuild` with configured command (default: `xcodebuild -scheme <scheme> -configuration Debug`).
2. Build diagnostics are summarized and passed to `callClaude`.
3. Claude returns FixPlan JSON (enforced by schema). On validation failure, the orchestrator requests a retry with error hints.
4. `auto_fix` traverses FixPlan tasks, fetching needed files via `readFiles`, passing them to `callGLM`.
5. GLM returns patches. `applyPatch` validates patch format, applies changes, and writes to disk.
6. After applying all tasks, `runBuild` executes again. Success ends the loop; failure triggers optional re-planning or aborts with a detailed report.

## Iteration Strategy
- **Single-pass**: One FixPlan, one implementation cycle (default).
- **Adaptive loop**: If the build still fails, capture deltas and run another Claude planning call (configurable max iterations).
- **Manual checkpointing**: Persist FixPlans and applied patches for review under `artifacts/`.

## Folder Structure (Proposed)
```
claude-glm-wrapper/
├── bin/                     # Entry points (CLI bindings, future MCP adapters)
├── docs/
│   ├── architecture.md      # This document
│   ├── fixplan-schema.md    # JSON schema and guidelines
│   └── prompts.md           # Prompt templates and usage notes
├── prompts/
│   ├── claude_fixplan.txt   # Prompt template for Claude
│   └── glm_apply.txt        # Prompt template for GLM
├── schemas/
│   └── fixplan.schema.json  # Strict JSON schema for FixPlan contract
├── src/
│   ├── orchestrator/
│   │   ├── auto_fix.js      # Bootstrapper for the full pipeline
│   │   └── pipeline.js      # Shared orchestration logic
│   ├── llm/
│   │   ├── claude.js        # Anthropic API integration
│   │   └── glm.js           # Z.AI GLM API integration
│   ├── tasks/
│   │   ├── apply_plan.js    # Converts FixPlan into actionable steps
│   │   └── run_build.js     # Wrapper around build/test commands
│   ├── utils/
│   │   ├── file_system.js   # Safe file reads/writes
│   │   ├── logger.js        # Structured logging
│   │   └── patch.js         # Patch application helpers
│   └── validators/
│       └── fixplan_validator.js
└── package.json
```

## Extensibility Hooks
- **MCP Integration**: Export orchestrator commands as MCP tools (`build`, `plan`, `apply`) by wrapping the Node modules.
- **Custom Build Commands**: Allow per-project config files (e.g. `auto-fix.config.json`) defining build/test command arrays.
- **Model Variants**: Switch GLM versions or Claude model types via environment variables or config.
- **Observability**: Stream `auto_fix` events to console, JSON logs, or remote dashboards for auditing.

## Next Steps
1. Finalize FixPlan schema and prompt templates.
2. Scaffold Node.js modules using the proposed folder layout.
3. Implement orchestrator pipeline and testing harness.
4. Update README and CLI entry points to expose the new workflow.
