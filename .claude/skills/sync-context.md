---
name: sync-context
description: Automatically updates the AGENTS.md, CLAUDE.md, or local directory context files with newly discovered project patterns, build commands, or architectural decisions.
disable-model-invocation: false
---

# Context Synchronization and Memory Protocol

The project's architecture or dependencies have evolved during this working session. To ensure future agents (or future sessions) do not repeat mistakes or lack vital context, you must update the project's memory files.

## Step 1: Memory File Location

Locate the primary memory file. Look for `AGENTS.md` at the repository root.

For directory-specific changes, you may also create or update a local `AGENTS.md` file within a specific subfolder:
- `GRE Verbal/AGENTS.md` - For app-wide architectural decisions
- `GRE Verbal/ViewModels/AGENTS.md` - For ViewModel-specific patterns
- `GRE Verbal/Services/AGENTS.md` - For service-layer conventions
- `GRE VerbalTests/AGENTS.md` - For testing methodologies and mocking patterns

## Step 2: Analyze the Delta

Reflect on the actions taken during the current session. Identify what novel, critical information was introduced that is not currently present in the memory file:

**Potential Additions:**
- Was a new SPM package integrated? (Include package name, version, and usage guidelines)
- Was a new architectural pattern established? (e.g., "All API calls must route through VocabRepository")
- Did a testing pattern or command evolve? (e.g., "New tests must mock AudioManager to avoid simulator audio delays")
- Was a folder structure or module organization changed?
- Was a Combine pattern or async/await convention established?
- Did the build configuration change? (e.g., new build phases, target dependencies)
- Were new @Published properties or observable patterns introduced?

## Step 3: Update with Extreme Brevity (Instruction Budget)

Read the existing memory file.

**You must abide by the LLM Instruction Budget:** Keep the file as short as mathematically possible (strictly under 300 lines).

**Rules:**
- Do not add verbose explanations
- Use concise, actionable, bulleted rules
- One line per concept when possible
- If a section has become bloated, refactor it to point to a documentation file (e.g., "See `docs/architecture/database.md`") rather than explaining it inline

### Hierarchical Organization

Maintain the following core structure:

```markdown
# Global Agent Operating Protocol

## Core Directive
[Existing content]

## Platform Detection & Tooling
[Existing content]

## The Cautious Coding Protocol (Immutable Rules)
[Existing content]

## Project Structure Context
[Add discovered patterns and conventions here]

### Key Files & Dependencies
- List any newly integrated SPM packages
- Document critical file paths and their purposes

### Testing Conventions
- Document any new testing patterns discovered
- List mocking requirements for external services

### Build & Deployment Notes
[Add build phase changes here]

## Dynamic Context Synchronization
[Existing content]
```

## Step 4: File Modification

Read the current AGENTS.md file, then rewrite it incorporating the new knowledge.

**Sections to potentially update:**
1. **Key Models & Services** - Add any newly created or discovered classes
2. **Testing Conventions** - Add mocking strategies or test patterns
3. **Build & Deployment Notes** - Document build phase changes
4. **SPM Dependencies** - List any newly added packages with version and purpose

### Example Update Scenarios

**Scenario 1: New SPM Package Added**
- **Before:** No mention of networking library
- **After:** Add under "### SPM Dependencies": `Alamofire (v5.7+) - For HTTP requests. All network calls route through VocabRepository.fetchWords()`

**Scenario 2: New Testing Pattern Discovered**
- **Before:** Generic testing instructions
- **After:** Add under "### Testing Conventions": `Mock AudioManager in tests via setUp() to prevent simulator audio delays. Use XCTestExpectation for async operations.`

**Scenario 3: Architectural Decision Made**
- **Before:** No mention of state management
- **After:** Add under "### Architecture & Guardrails": `All mutable state lives in ViewModels with @Published. Views must never mutate @State directly. Use @Binding for child view updates.`

## Step 5: Output Summary

Once you have updated AGENTS.md (or the relevant context file), output a concise summary to the user:

```markdown
## Context Synchronization Complete ✅

**File Updated:** AGENTS.md

**Changes Made:**
1. Added SPM dependency: [Package Name]
2. Documented new testing pattern: [Pattern Description]
3. Added architectural guideline: [Guideline]

**Rationale:**
[Brief explanation of why this knowledge is critical for future sessions]

**Impact:**
Future agents will now [benefit how].
```

## Step 6: Validate No Regression

After updating AGENTS.md, re-read the first 50 lines to ensure:
- Core directives are still clear and unambiguous
- No contradictions were introduced
- Instruction count remains under 300 lines
- The file remains machine-readable and human-scannable

If the file exceeds 300 lines, you must refactor by:
- Extracting verbose sections into `docs/` folder
- Creating hierarchical `AGENTS.md` files in subdirectories
- Converting prose into bullet-point checklists
