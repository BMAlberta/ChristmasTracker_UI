# AGENTS.md instructions for /Users/brian/Development/christmasTracker/Mobile UI/ChristmasTracker

## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file.

### Available skills
- swiftui-expert-skill: Write, review, or improve SwiftUI code following best practices for state management, view composition, performance, modern APIs, Swift concurrency, and iOS 26+ Liquid Glass adoption. Use when building new SwiftUI features, refactoring existing views, reviewing code quality, or adopting modern SwiftUI patterns. (file: /Users/brian/.codex/skills/swiftui-expert-skill/SKILL.md)
- skill-creator: Guide for creating effective skills. Use when creating or updating skills that extend Codex with specialized workflows. (file: /Users/brian/.codex/skills/.system/skill-creator/SKILL.md)
- skill-installer: Install Codex skills into `$CODEX_HOME/skills` from curated lists or GitHub paths. Use when listing installable skills or installing skills. (file: /Users/brian/.codex/skills/.system/skill-installer/SKILL.md)

### How to use skills
- Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill description above, use that skill for the turn.
- Missing/blocked: If a named skill is missing or unreadable, state it briefly and continue with the best fallback.
- Progressive disclosure:
  1. Open the skill's `SKILL.md` and read only what is needed.
  2. Resolve relative references from the skill directory first.
  3. Load only referenced files required for the current task.
  4. Reuse skill scripts/assets/templates when provided.
- Coordination: If multiple skills apply, use the minimal set and state order briefly.
- Context hygiene: Keep context small and avoid unnecessary deep reference chasing.
