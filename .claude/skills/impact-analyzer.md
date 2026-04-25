---
name: impact-analyzer
description: Performs a comprehensive blast-radius and dependency analysis before making modifications to the codebase. Use this before starting any complex feature or refactor to prevent application failures.
disable-model-invocation: false
---

# Pre-Flight Impact Analysis Protocol

You have been invoked to perform a rigorous Pre-Flight Impact Analysis. You must thoroughly understand the environment and the cascading ripple effects of the proposed changes before writing a single line of implementation code.

## Step 1: Environment Discovery

Run safe, read-only terminal commands to discover the environment context:

**Swift/iOS Project Discovery:**
- Execute `cat GRE\ Verbal.xcodeproj/project.pbxproj | grep -A5 "targets ="` to understand build targets
- Use `grep -r "import" GRE\ Verbal/` to map internal dependencies
- Use `grep -r "\.swift"` to identify all Swift source files
- Check for any external SPM dependencies via `cat GRE\ Verbal.xcodeproj/project.xcworkspace/xcshareddata/swiftpm`

## Step 2: Blast Radius Mapping

Logically trace the execution path. For every file you intend to modify, you must list:

1. **Upstream Dependencies:** 
   - What Models or Services does this file depend on?
   - What external frameworks are imported?
   
2. **Downstream Consumers:** 
   - What Views or ViewModels reference this file?
   - What other Services call functions/properties from this file?
   - Search for all View components that observe or use this model
   
3. **State Implications:** 
   - Does this proposed change alter @Published properties that Views bind to?
   - Does this affect data persistence (VocabRepository)?
   - Does this trigger notifications or audio playback?
   - Does this impact the streak tracking system?

## Step 3: Risk Assessment

You must identify at least two potential failure points or edge cases that could arise from this change:

- **Memory/Lifecycle Issues:** Retain cycles with Combine subscriptions? Views holding onto stale references?
- **Thread Safety:** Are you modifying @Published properties from a background thread?
- **Type Safety:** Could this introduce optional chaining on non-optional types? Missing error handling?
- **UI Rendering:** Could this cause infinite view redraws? Missing `.id()` modifiers on dynamic content?
- **Data Consistency:** Could this leave the persistence layer in an inconsistent state?

## Step 4: The Execution Report

Output a concise Markdown report to the user detailing the findings of Steps 1 through 3. 

Conclude the report with a specific, step-by-step implementation plan that includes:
- Files that will be modified
- Expected changes to each file
- New test cases that will be written
- Potential edge cases to guard against

**CRITICAL:** DO NOT WRITE THE ACTUAL CODE YET. 

Terminate your output by asking the user: **"Do you approve this execution plan and blast radius assessment? Should I proceed with the modifications?"**

Only proceed to implementation after explicit user approval.
