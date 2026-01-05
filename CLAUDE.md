# JogPod Revival Project

iOS app migration from Objective-C to modern Swift/SwiftUI.

## Project Structure

- **This directory** (`/Users/andraslferenczi/JogPod-revived/`): New Swift codebase (target)
- **Legacy code** (`/Users/andraslferenczi/jogpod/`): Original Objective-C source

## Key Documentation

- `MIGRATION_DOCUMENTATION.md` - Complete migration plan and architecture
- `EQUIVALENCE_TESTING_STRATEGY.md` - Testing approach for behavioral equivalence
- `MEDIUM_PRIORITY_DOCUMENTATION.md` - Secondary features and improvements
- `DOCUMENTATION_INDEX.md` - Index of all documentation

## Issue Tracking

Uses `bd` (beads) for issue tracking. See `AGENTS.md` for workflow.

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
```

## Agent Assignments

- **ios-app-architect**: Architecture decisions, system design
- **swift-expert-translator**: Objective-C to Swift translation
- **ios-ui-architect**: UI modernization, SwiftUI patterns
- **devops-engineer**: Test coverage, CI/CD
- **spec-analyzer**: Verifying implementations against specs
