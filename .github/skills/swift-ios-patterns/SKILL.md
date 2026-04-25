---
name: swift-ios-patterns
description: "Use when: implementing SwiftUI views, managing state with ViewModels, handling async operations, or working with SwiftData persistence. Provides battle-tested patterns for GRE Verbal app development."
---

# Swift/iOS Best Practices for GRE Verbal

## Critical Patterns

### 1. ViewModel Initialization & Cleanup
**Problem**: Timer callbacks accumulating in DrillTimerViewModel, memory leaks in Combine subscriptions

**Pattern**:
```swift
class MyViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    // Cancel all subscriptions on deinit
    deinit {
        cancellables.removeAll()
    }
    
    func setupBindings() {
        timer
            .sink { [weak self] _ in
                self?.updateState()
            }
            .store(in: &cancellables)
    }
}
```

**Checklist**:
- [ ] Use `Set<AnyCancellable>` for Combine subscriptions
- [ ] Always use `[weak self]` in closures to prevent retain cycles
- [ ] Remove subscriptions in `deinit`
- [ ] Test timer callbacks don't accumulate (call ViewModel init/deinit multiple times)

### 2. SwiftUI State Management
**Problem**: DrillActiveView toggle state synchronization failures

**Pattern**:
```swift
struct DrillActiveView: View {
    @StateObject private var viewModel = DrillViewModel()
    @State private var localToggleState = false
    
    var body: some View {
        Toggle("Active", isOn: $localToggleState)
            .onChange(of: localToggleState) { newValue in
                viewModel.setActive(newValue)
            }
    }
}
```

**Checklist**:
- [ ] Use `@StateObject` for ViewModel persistence
- [ ] Use `@State` for local UI state, not model data
- [ ] Use `onChange` for side effects, not `didSet`
- [ ] Never mutate state inside computed properties
- [ ] Test toggle produces single state change (not duplicates)

### 3. SwiftData Container Initialization
**Problem**: GRE_VerbalApp container crashes on data corruption

**Pattern**:
```swift
import SwiftData

@main
struct GRE_VerbalApp: App {
    let modelContainer: ModelContainer
    
    init() {
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false
        )
        do {
            self.modelContainer = try ModelContainer(
                for: VocabWord.self, DrillSession.self, WordProgress.self,
                configurations: config
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
}
```

**Checklist**:
- [ ] Always use `backup` configuration for production
- [ ] Include all model types in container init
- [ ] Handle initialization errors with fatalError (crash early)
- [ ] Test on both fresh install and upgrade scenarios
- [ ] Never create multiple ModelContainers

### 4. Analytics State Normalization
**Problem**: Incorrect error rate calculations due to state value mismatches

**Pattern**:
```swift
enum QuestionState: String, Codable {
    case correct = "right"
    case incorrect = "incorrect"
    case pending = "pending"
    
    // Normalize incoming values
    static func normalize(_ value: String) -> QuestionState {
        switch value.lowercased() {
        case "correct", "right":
            return .correct
        case "wrong", "incorrect", "x":
            return .incorrect
        case "unanswered", "pending", "skipped":
            return .pending
        default:
            return .pending // Safe fallback
        }
    }
}
```

**Checklist**:
- [ ] All QuestionState values use normalized names
- [ ] Normalize incoming data immediately on parse
- [ ] Provide fallback logic for unknown values
- [ ] Verify error rate = (incorrect + pending) / total
- [ ] Test with mixed value formats (correct, right, etc.)

### 5. Error Handling & Recovery
**Pattern**:
```swift
func loadVocabWords() async throws {
    guard !words.isEmpty else {
        throw VocabError.noWordsLoaded
    }
    
    do {
        let fetched = try await repository.fetch()
        DispatchQueue.main.async {
            self.words = fetched
        }
    } catch {
        print("Load failed: \(error)")
        throw error
    }
}
```

**Checklist**:
- [ ] Use `throws` for operations that can fail
- [ ] Update UI on main thread (use DispatchQueue.main.async)
- [ ] Provide specific error types, not generic String
- [ ] Log errors for debugging
- [ ] Test error paths in unit tests

## Testing Checklist

For any modified file:
1. Happy path: nominal flow works end-to-end
2. Edge case 1: nil/empty data handled gracefully
3. Edge case 2: async operation cancellation or timeout
4. Regression: verify critical modules (DrillTimerViewModel, DrillActiveView, GRE_VerbalApp)

## Pre-Submission Validation

```bash
# Build
xcodebuild -scheme "GRE Verbal" -sdk iphonesimulator -configuration Debug build

# Test
xcodebuild test -scheme "GRE Verbal" -sdk iphonesimulator

# Lint (if SwiftLint configured)
swiftlint
```

If any step fails, DO NOT submit.
