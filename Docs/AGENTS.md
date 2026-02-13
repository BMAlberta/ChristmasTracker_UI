# AGENTS.md - Implementation Guide Generation System

**Purpose:** This file teaches Claude how to generate high-quality, token-optimized implementation guides for development tasks. These guides are designed for use with AI coding agents (like Claude Code, Cursor, Aider, etc.) to maximize output quality while minimizing token usage.

---

## Core Principles

### 1. Token Optimization
- **Break large features into focused prompts** (10k-20k tokens each)
- **Use compact strategy** - Recommend compaction points in long guides
- **Avoid repetition** - Don't repeat context the agent already has
- **Be specific, not verbose** - "Add X to line Y" not "You might want to consider..."

### 2. Superpowers Decision Framework
**Enable Superpowers When:**
- ✅ Complex architectural decisions needed
- ✅ Multiple integration points
- ✅ Non-obvious patterns or best practices
- ✅ Error-prone implementations
- ✅ State management or data flow logic

**Disable Superpowers When:**
- ❌ Straightforward UI components
- ❌ Simple CRUD operations
- ❌ Direct API to component mappings
- ❌ Styling and layout tasks
- ❌ Copy-paste or template-based work

**Rule of Thumb:** If you can write the complete implementation in the prompt without ambiguity, disable Superpowers. If the agent needs to make architectural choices, enable it.

### 3. Prompt Structure
Every prompt should have:
1. **Clear goal statement** - What we're building
2. **Requirements list** - Specific, testable criteria
3. **Implementation section** - Complete, working code
4. **Boundaries** - Explicit "Do NOT" statements
5. **Testing guidance** - How to verify it works

---

## Implementation Guide Template

Use this structure when creating multi-prompt implementation guides:

```markdown
# [Feature Name] - Token-Optimized Guide

**Goal:** [One sentence describing what we're building]

**Strategy:** [Number] focused prompts to [high-level description]

---

## Overview

### What We're Building:
1. [Component/feature 1]
2. [Component/feature 2]
3. [Component/feature 3]

### Superpowers Strategy:
- ✅ **Enable for [X]** - [Reason why]
- ❌ **Disable for [Y]** - [Reason why]

**Expected Total:** ~[Number]-[Number] tokens

---

## Prerequisites

Before starting, ensure you have:
- [ ] [Dependency 1]
- [ ] [Dependency 2]
- [ ] [Endpoint/API available]

---

## Token Budget Breakdown

| Phase | Prompts | Est. Tokens | Superpowers | Notes |
|-------|---------|-------------|-------------|-------|
| **[Phase 1]** | 1 | [Number] | Yes/No | [Brief description] |
| **[Phase 2]** | 2 | [Number] | Yes/No | [Brief description] |
| **Total** | X prompts | **~[Total]** | Mixed/None/All | |

**Compact Strategy:** [When to compact context]

---

## Phase N: [Phase Name]

### **Prompt N: [Specific Task]**

**Enable/Disable Superpowers: YES/NO**

```
[Clear instruction for the agent]

[If applicable: File location and purpose]

Requirements:
- [Specific requirement 1]
- [Specific requirement 2]
- [Specific requirement 3]

Implementation:
```[language]
[Complete, working code that can be copy-pasted]
```

[Additional instructions or context]

Do NOT [explicit boundary 1].
Do NOT [explicit boundary 2].
```

**Expected tokens:** ~[Number]

**Why Superpowers:** [Only if enabled]
- ✅ [Reason 1]
- ✅ [Reason 2]

---

## Summary & Testing

### What You've Built:
- ✅ [Feature 1]
- ✅ [Feature 2]
- ❌ [Not included - next phase]

### Testing Checklist:
- [ ] [Test 1]
- [ ] [Test 2]
- [ ] [Test 3]

---

## Next Steps

[What comes after this guide]
```

---

## Prompt Writing Best Practices

### ✅ DO:
```
Create src/components/Button.tsx

A reusable button component with variants.

Requirements:
- Primary and secondary variants
- Loading state with spinner
- Disabled state
- Click handler prop

Implementation:
```typescript
interface ButtonProps {
  variant?: 'primary' | 'secondary'
  loading?: boolean
  disabled?: boolean
  onClick?: () => void
  children: React.ReactNode
}

export function Button({ 
  variant = 'primary', 
  loading, 
  disabled, 
  onClick, 
  children 
}: ButtonProps) {
  return (
    <button
      onClick={onClick}
      disabled={disabled || loading}
      className={`px-4 py-2 rounded-lg font-medium transition-colors
        ${variant === 'primary' ? 'bg-primary text-white' : 'bg-surface border'}
        ${disabled ? 'opacity-50 cursor-not-allowed' : 'hover:opacity-90'}
      `}
    >
      {loading ? <Spinner /> : children}
    </button>
  )
}
```

Do NOT add additional variants.
Do NOT implement size prop yet.
```

**Why this works:**
- ✅ Clear file path
- ✅ Complete working code
- ✅ Specific requirements
- ✅ Clear boundaries

### ❌ DON'T:
```
Can you help me create a button component? I need it to be reusable and have different styles. Maybe it could have a primary and secondary variant? Also it should probably handle loading states. Oh and make sure it's accessible. Use your best judgment on the styling.
```

**Why this fails:**
- ❌ Vague requirements
- ❌ No code provided
- ❌ Ambiguous scope
- ❌ Agent has to guess

---

## Token Budget Estimation Guide

### Component Complexity:

**Simple Component** (10k-15k tokens):
- Single file
- < 100 lines of code
- Straightforward logic
- Example: Button, Card, Badge

**Medium Component** (15k-25k tokens):
- Multiple files or states
- 100-300 lines
- Some data fetching
- Example: Modal, Form, Table

**Complex Feature** (25k-40k tokens):
- Multiple components
- State management
- API integration
- Business logic
- Example: Authentication flow, Dashboard page

**Architecture/System** (40k+ tokens):
- Multiple features
- Cross-cutting concerns
- Requires planning
- Example: Complete auth system, Admin panel

### Token Budget Formula:
```
Base (instructions): 2k-5k tokens
Code (per 100 lines): 3k-5k tokens
Examples/tests: 2k-3k tokens
Explanations: 1k-2k tokens

Total = Base + (Lines/100 * 4k) + Examples + Explanations
```

---

## When to Create Implementation Guides

### ✅ Create a Guide When:
1. **Feature requires multiple prompts** (> 30k tokens)
2. **Complex dependencies** between components
3. **Specific ordering** required
4. **Multiple integration points**
5. **Non-obvious patterns** to follow
6. **Reusable workflow** that will repeat

### ❌ Skip the Guide When:
1. **Single prompt sufficient** (< 20k tokens)
2. **Straightforward task** with no dependencies
3. **One-off implementation**
4. **Agent can infer structure** from existing code
5. **No specific ordering** required

---

## Superpowers Decision Tree

```
START: Does this task involve...

→ Complex architectural decisions?
  YES → Enable Superpowers
  NO  → Continue

→ Multiple integration points?
  YES → Enable Superpowers
  NO  → Continue

→ Non-obvious implementation patterns?
  YES → Enable Superpowers
  NO  → Continue

→ Error-prone logic (auth, payments, etc)?
  YES → Enable Superpowers
  NO  → Continue

→ State management or data flow?
  YES → Enable Superpowers
  NO  → Continue

→ Just UI/styling/CRUD?
  YES → Disable Superpowers
  
DEFAULT: Disable Superpowers
```

---

## Example Use Cases

### Use Case 1: Authentication System
```
Request: "Help me implement authentication"

Response: Create implementation guide with:
- Phase 1: Auth routes + middleware (Superpowers: YES)
- Phase 2: Login/register pages (Superpowers: NO)
- Phase 3: Protected route wrapper (Superpowers: YES)
- Phase 4: Auth state management (Superpowers: YES)

Total: 4 prompts, ~80k tokens
Superpowers: 3 of 4 phases
```

### Use Case 2: Simple Modal
```
Request: "Create a confirmation modal"

Response: Single prompt with:
- Modal component code
- Trigger button example
- Usage documentation

Total: 1 prompt, ~12k tokens
Superpowers: NO
```

### Use Case 3: Dashboard with Charts
```
Request: "Build analytics dashboard with charts"

Response: Create implementation guide with:
- Phase 1: Dashboard layout (Superpowers: NO)
- Phase 2: Data fetching hooks (Superpowers: YES)
- Phase 3: Chart components (Superpowers: NO)
- Phase 4: Integration + state (Superpowers: YES)

Total: 4 prompts, ~70k tokens
Superpowers: 2 of 4 phases
```

---

## Quality Checklist

Before finalizing an implementation guide, verify:

### Completeness:
- [ ] Every prompt has clear instructions
- [ ] All code is complete and working
- [ ] Dependencies are documented
- [ ] Testing guidance included

### Token Efficiency:
- [ ] No repetitive explanations
- [ ] Compact points identified
- [ ] Prompts are focused (not monolithic)
- [ ] Code examples are minimal but complete

### Clarity:
- [ ] Requirements are specific and testable
- [ ] "Do NOT" boundaries are explicit
- [ ] Superpowers decisions are justified
- [ ] File paths are exact

### Usability:
- [ ] Agent can copy-paste prompts directly
- [ ] No ambiguous instructions
- [ ] Clear success criteria
- [ ] Logical progression between prompts

---

## Common Patterns

### Pattern 1: API Integration
```
Phase 1: Create API client + types (Superpowers: YES)
Phase 2: Create React Query hooks (Superpowers: NO)
Phase 3: Create UI components (Superpowers: NO)
Phase 4: Integration + error handling (Superpowers: YES)
```

### Pattern 2: Form with Validation
```
Phase 1: Form schema + validation (Superpowers: YES)
Phase 2: Form UI components (Superpowers: NO)
Phase 3: Submit logic + API (Superpowers: YES)
```

### Pattern 3: CRUD Resource
```
Phase 1: API routes + service (Superpowers: YES)
Phase 2: List view + table (Superpowers: NO)
Phase 3: Create/edit modal (Superpowers: NO)
Phase 4: Delete confirmation (Superpowers: NO)
```

### Pattern 4: Complex State Flow
```
Phase 1: State architecture design (Superpowers: YES)
Phase 2: Store implementation (Superpowers: YES)
Phase 3: UI components (Superpowers: NO)
Phase 4: Integration + side effects (Superpowers: YES)
```

---

## Anti-Patterns to Avoid

### ❌ Anti-Pattern 1: Monolithic Prompts
**Bad:** One 80k token prompt for entire feature
**Good:** 4-5 focused 15-20k token prompts

### ❌ Anti-Pattern 2: Verbose Explanations
**Bad:** "You might want to consider using React Query here because it provides caching and..."
**Good:** "Use React Query for data fetching. See example below."

### ❌ Anti-Pattern 3: Ambiguous Requirements
**Bad:** "Make it look nice"
**Good:** "Use primary button style: bg-primary text-white rounded-lg px-4 py-2"

### ❌ Anti-Pattern 4: Missing Boundaries
**Bad:** "Create a modal component"
**Good:** "Create a modal component. Do NOT add animations. Do NOT implement backdrop click."

### ❌ Anti-Pattern 5: Over-Enabling Superpowers
**Bad:** Enable for simple UI components
**Good:** Enable only for complex logic/architecture

---

## Adaptation Guidelines

### For Different Agents:

**Claude Code (VSCode Extension):**
- Can read existing files
- Prefers delta packages
- Good at maintaining consistency

**Cursor:**
- Works best with inline instructions
- Prefers smaller, focused tasks
- Good at refactoring

**Aider:**
- Excels at git-aware changes
- Good for systematic refactors
- Prefers whole-file context

**General AI Chat:**
- Needs complete context in each prompt
- Can't read files directly
- Best for planning and architecture

### For Different Stacks:

**React + TypeScript:**
- Include type definitions
- Specify component patterns (functional/hooks)
- Note state management library

**Node.js + Express:**
- Include route structure
- Specify middleware chain
- Note error handling patterns

**Python + FastAPI:**
- Include dependency injection
- Specify response models
- Note async patterns

**Any Stack:**
- Always provide exact file paths
- Include all imports
- Specify framework versions if relevant

---

## Measuring Success

Good implementation guides should result in:

1. **First-Try Success Rate > 80%**
   - Agent implements correctly without clarifications
   - Code compiles/runs on first attempt

2. **Token Efficiency > 70%**
   - Actual usage within 30% of budget
   - No wasted prompt iterations

3. **Minimal Back-and-Forth**
   - < 2 follow-up questions per prompt
   - Clear enough to execute independently

4. **Maintainability**
   - Code is consistent with project
   - Follows established patterns
   - Easy to extend later

---

## Usage Instructions

### For Users:
1. Place this file in your project root as `AGENTS.md`
2. Reference it when asking Claude for implementation guides
3. Claude will automatically use these patterns

### For Claude:
When a user asks for implementation help:

1. **Assess Complexity:**
   - Single prompt (< 20k tokens) → Direct implementation
   - Multiple prompts → Create guide

2. **Plan Structure:**
   - Break into logical phases
   - Estimate token budget
   - Decide Superpowers per phase

3. **Generate Guide:**
   - Use template structure
   - Include complete code
   - Add clear boundaries
   - Provide testing checklist

4. **Optimize:**
   - Remove verbosity
   - Add compact points
   - Ensure copy-pasteable

---

## Version History

- **v1.0** - Initial framework
- Covers: Token optimization, Superpowers decisions, guide templates
- Designed for: React/TypeScript, Node.js, general web development

---

## Example Invocation

**User:**
```
Using the AGENTS.md guidelines, create an implementation guide 
for building a user profile page with edit functionality.
```

**Claude Response:**
```
I'll create a token-optimized implementation guide following AGENTS.md.

[Generates structured guide with]:
- Token budget breakdown
- Phase-by-phase prompts
- Superpowers decisions per phase
- Complete code examples
- Testing checklist
```

---

**END OF AGENTS.MD**

This file should be read by Claude at the start of conversations where implementation guidance is needed. It establishes consistent patterns for generating high-quality, efficient development guides.
