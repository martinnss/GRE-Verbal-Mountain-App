---
name: triple-check-runner
description: Mandates extreme caution by forcing the agent to auto-update tests, run the project, and pass a strict validation shell script before claiming a task is done.
disable-model-invocation: false
---

# Triple-Check Execution and Verification Protocol

You must guarantee that the code you just wrote or modified works flawlessly. You are strictly prohibited from claiming the task is complete based on visual inspection or your own confidence. You must programmatically prove it.

## Step 1: Auto-Update Tests

Autonomously analyze the codebase to locate the relevant test files corresponding to your changes.

- If the target file is `GRE Verbal/Models/VocabWord.swift`, locate or create `GRE VerbalTests/VocabWordTests.swift`
- If the target file is `GRE Verbal/ViewModels/FlashcardViewModel.swift`, locate or create `GRE VerbalTests/FlashcardViewModelTests.swift`
- If no test file exists for the module you modified, **YOU MUST CREATE ONE**

### Test Coverage Requirements

Update the test file to cover:
1. **Happy Path:** Standard use case with valid inputs (e.g., initializing a VocabWord with typical data)
2. **Edge Case 1:** Empty or nil data (e.g., empty strings, nil optionals)
3. **Edge Case 2:** Boundary conditions or extreme values (e.g., very long strings, zero values, max integers)
4. **Error Handling:** If applicable, test error paths and exception handling

**IMPORTANT:** Double and triple-check your test logic. Assume hidden tests exist in the user's CI pipeline that you cannot see. Your code must be robust enough to survive unforeseen edge cases.

### Test File Structure (XCTest)

```swift
import XCTest
@testable import GRE_Verbal

class [ModuleUnderTest]Tests: XCTestCase {
    
    func testHappyPath() {
        // Standard use case with valid inputs
    }
    
    func testEmptyOrNilData() {
        // Empty strings, nil optionals, etc.
    }
    
    func testBoundaryConditions() {
        // Extreme or edge values
    }
    
    func testErrorHandling() {
        // Error paths and exceptions
    }
}
```

## Step 2: Create the Validation Shell Script

Create a temporary bash script named `.agent_validation.sh` in the root directory.

```bash
#!/bin/bash
set -e

echo "=== Phase 1: Compilation Check ==="
xcodebuild build -scheme "GRE Verbal" -configuration Debug 2>&1 | tee /tmp/build.log
if grep -i "error:" /tmp/build.log; then
    echo "❌ Build failed with errors"
    exit 1
fi

if grep -i "warning:" /tmp/build.log; then
    echo "⚠️  Build completed with warnings. Review above."
fi

echo ""
echo "=== Phase 2: Unit Tests ==="
xcodebuild test -scheme "GRE Verbal" -destination "generic/platform=iOS Simulator" 2>&1 | tee /tmp/test.log

if grep -i "failed\|error" /tmp/test.log | grep -v "0 failed"; then
    echo "❌ Tests failed"
    exit 1
fi

echo ""
echo "✅ All checks passed!"
exit 0
```

This script must:
1. Compile the project using `xcodebuild build`
2. Run the full test suite using `xcodebuild test`
3. Exit with code 0 only if ALL checks pass completely
4. Exit with code 1 if ANY check fails or throws a warning

## Step 3: Execute and Iterate

Execute `bash .agent_validation.sh` in the terminal.

**If the exit code is not 0:**
- You must read and analyze the standard error output
- Formulate a new hypothesis as to why it failed
- Do NOT blindly apply patches
- Fix the implementation code or the test logic
- Re-run the validation script

**You must repeat this loop autonomously until the exit code is exactly 0.**

### Common Failure Scenarios & Recovery

| Failure | Root Cause | Recovery |
|---------|-----------|----------|
| Compilation error | Syntax error or type mismatch | Fix the Swift syntax, ensure optional handling |
| Build warning | Unused variable or deprecated API | Remove unused code, update API usage |
| Test failure | Logic error or assertion mismatch | Debug the test, fix the implementation logic |
| Memory error | Retain cycle or dangling reference | Review Combine subscriptions, use `weak self` |

## Step 4: Final Cleanup and Delivery

Once the bash script passes with a 0 exit code:

1. Delete the `.agent_validation.sh` file to keep the workspace clean
2. Output a summary to the user detailing:
   - The test files that were created or updated
   - The number of tests that passed
   - Any edge cases covered by the new tests
   - Confirmation that the triple-check methodology has been completed successfully

3. If you are uncertain about any remaining side-effects that the tests could not cover, you must explicitly warn the user

### Example Success Summary

```
✅ TRIPLE-CHECK VERIFICATION COMPLETE

Modified Files:
- GRE Verbal/Models/VocabWord.swift (3 lines added)
- GRE VerbalTests/VocabWordTests.swift (45 lines added)

Tests Executed:
- 4 new tests added to VocabWordTests
- 8 total tests in suite now passing
- Coverage: Happy path, empty data, boundary conditions, error handling

Build Status: ✅ Clean (no errors or warnings)
Test Status: ✅ All 8 tests passed

Edge Cases Covered:
- Empty word strings
- Nil pronunciation
- Maximum difficulty values
- Invalid word initialization

⚠️  Note: Audio playback during tests is mocked; integration testing with real audio requires manual verification.
```
