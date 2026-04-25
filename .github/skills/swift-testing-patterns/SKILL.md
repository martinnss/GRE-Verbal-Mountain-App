---
name: swift-testing-patterns
description: "Use when: writing or updating unit tests, mocking services, testing async code, or creating integration tests. Covers XCTest conventions for GRE Verbal."
---

# Swift Testing Patterns for GRE Verbal

## Test File Organization

```
GRE VerbalTests/
├── Models/
│   ├── VocabWordTests.swift
│   ├── DrillSessionTests.swift
│   └── WordProgressTests.swift
├── ViewModels/
│   ├── DrillTimerViewModelTests.swift
│   └── FlashcardViewModelTests.swift
├── Services/
│   ├── VocabRepositoryTests.swift
│   ├── AudioManagerTests.swift
│   ├── StreakManagerTests.swift
│   └── NotificationManagerTests.swift
└── Views/
    ├── DrillActiveViewTests.swift
    └── DrillDetailViewTests.swift
```

## Unit Testing Template

### Models

```swift
import XCTest
@testable import GRE_Verbal

final class VocabWordTests: XCTestCase {
    
    func testVocabWordInitialization() {
        let word = VocabWord(
            word: "ubiquitous",
            definition: "Present everywhere",
            partOfSpeech: "adjective"
        )
        
        XCTAssertEqual(word.word, "ubiquitous")
        XCTAssertEqual(word.definition, "Present everywhere")
    }
    
    func testVocabWordWithNilOptionalFields() {
        let word = VocabWord(
            word: "test",
            definition: "test definition",
            partOfSpeech: "noun",
            exampleSentence: nil
        )
        
        XCTAssertNil(word.exampleSentence)
    }
    
    func testVocabWordEquality() {
        let word1 = VocabWord(word: "test", definition: "def", partOfSpeech: "noun")
        let word2 = VocabWord(word: "test", definition: "def", partOfSpeech: "noun")
        
        XCTAssertEqual(word1, word2)
    }
}
```

### ViewModels with Mocks

```swift
import XCTest
import Combine
@testable import GRE_Verbal

// Mock service
class MockVocabRepository: VocabRepository {
    var words: [VocabWord] = []
    var fetchCalled = false
    
    override func fetchWords() async throws -> [VocabWord] {
        fetchCalled = true
        return words
    }
}

final class FlashcardViewModelTests: XCTestCase {
    var sut: FlashcardViewModel!
    var mockRepository: MockVocabRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockVocabRepository()
        sut = FlashcardViewModel(repository: mockRepository)
        cancellables = []
    }
    
    override func tearDown() {
        cancellables.removeAll()
        mockRepository = nil
        sut = nil
        super.tearDown()
    }
    
    func testLoadWords() async {
        let testWords = [
            VocabWord(word: "test1", definition: "def1", partOfSpeech: "noun"),
            VocabWord(word: "test2", definition: "def2", partOfSpeech: "verb")
        ]
        mockRepository.words = testWords
        
        await sut.loadWords()
        
        XCTAssertTrue(mockRepository.fetchCalled)
        XCTAssertEqual(sut.words.count, 2)
    }
    
    func testLoadWordsEmpty() async {
        mockRepository.words = []
        
        await sut.loadWords()
        
        XCTAssertEqual(sut.words.count, 0)
    }
}
```

### Timer & State Management

```swift
final class DrillTimerViewModelTests: XCTestCase {
    var sut: DrillTimerViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = DrillTimerViewModel()
        cancellables = []
    }
    
    override func tearDown() {
        // CRITICAL: Clean up timer subscriptions
        sut.stopTimer()
        cancellables.removeAll()
        sut = nil
        super.tearDown()
    }
    
    func testTimerStartsCorrectly() {
        let expectation = XCTestExpectation(description: "Timer fires")
        
        sut.$elapsedTime
            .dropFirst()
            .sink { value in
                XCTAssertGreater(value, 0)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        sut.startTimer()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testTimerDoesNotAccumulate() {
        // Test that multiple startTimer calls don't accumulate callbacks
        sut.startTimer()
        let initialTime = sut.elapsedTime
        
        sut.startTimer() // Second call
        
        // Verify only ONE timer is running (not accumulated)
        XCTAssertEqual(sut.timerCount, 1)
    }
    
    func testTimerStops() {
        sut.startTimer()
        let timeBeforeStop = sut.elapsedTime
        
        sut.stopTimer()
        
        let timeAfterStop = sut.elapsedTime
        XCTAssertEqual(timeBeforeStop, timeAfterStop)
    }
}
```

### Toggle State Synchronization

```swift
final class DrillActiveViewModelTests: XCTestCase {
    var sut: DrillViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = DrillViewModel()
        cancellables = []
    }
    
    override func tearDown() {
        cancellables.removeAll()
        sut = nil
        super.tearDown()
    }
    
    func testToggleStateChangesOnce() {
        var stateChangeCount = 0
        
        sut.$isActive
            .dropFirst()
            .sink { _ in
                stateChangeCount += 1
            }
            .store(in: &cancellables)
        
        sut.setActive(true)
        sut.setActive(false)
        
        // Should be exactly 2 changes, not duplicates
        XCTAssertEqual(stateChangeCount, 2)
    }
    
    func testToggleStateDoesNotDuplicate() {
        var states: [Bool] = []
        
        sut.$isActive
            .sink { state in
                states.append(state)
            }
            .store(in: &cancellables)
        
        sut.setActive(true)
        sut.setActive(true) // Duplicate call
        
        // Should filter duplicate consecutive values
        let uniqueStates = states.dropFirst().count
        XCTAssertLessThan(uniqueStates, 3)
    }
}
```

## Testing Async Operations

```swift
func testAsyncOperation() async {
    let result = await sut.fetchData()
    
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.count, expectedCount)
}

// Or use expectation pattern for callbacks
func testAsyncWithExpectation() {
    let expectation = XCTestExpectation(description: "Data fetched")
    
    sut.fetchData { result in
        XCTAssertNotNil(result)
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
}
```

## Testing Analytics State Normalization

```swift
final class AnalyticsNormalizationTests: XCTestCase {
    
    func testQuestionStateNormalization() {
        // Test all variants normalize to correct values
        XCTAssertEqual(QuestionState.normalize("correct"), .correct)
        XCTAssertEqual(QuestionState.normalize("right"), .correct)
        XCTAssertEqual(QuestionState.normalize("wrong"), .incorrect)
        XCTAssertEqual(QuestionState.normalize("x"), .incorrect)
        XCTAssertEqual(QuestionState.normalize("pending"), .pending)
        XCTAssertEqual(QuestionState.normalize("UNKNOWN"), .pending) // Fallback
    }
    
    func testErrorRateCalculation() {
        let states = [
            QuestionState.correct,
            QuestionState.incorrect,
            QuestionState.incorrect,
            QuestionState.pending
        ]
        
        let errorRate = Double(2) / Double(4) // 2 errors out of 4
        XCTAssertEqual(errorRate, 0.5)
    }
}
```

## Running Tests

```bash
# Run all tests
xcodebuild test -scheme "GRE Verbal" -sdk iphonesimulator

# Run specific test class
xcodebuild test -scheme "GRE Verbal" -sdk iphonesimulator -only-testing GRE\ VerbalTests/DrillTimerViewModelTests

# Run with verbose output
xcodebuild test -scheme "GRE Verbal" -sdk iphonesimulator -verbose
```

## Test Coverage Targets

- Models: 90%+ coverage
- ViewModels: 80%+ coverage (especially critical modules)
- Services: 85%+ coverage
- Views: 60%+ coverage (UI testing is complex)

## Critical Testing Rules for This Project

1. **DrillTimerViewModel**: Always test timer doesn't accumulate (test both start/stop cycles)
2. **DrillActiveView**: Always test toggle produces exactly one state change per user interaction
3. **GRE_VerbalApp**: Always test container initializes without crashing on fresh install

## Common Test Pitfalls

❌ Not cleaning up Combine subscriptions → memory leaks
❌ Not mocking external services → flaky tests
❌ Not testing nil/empty edge cases → crashes in production
❌ Testing implementation instead of behavior → brittle tests
✅ Always tearDown resources
✅ Always mock external dependencies
✅ Always test both happy and sad paths
✅ Test observable behavior, not implementation details
