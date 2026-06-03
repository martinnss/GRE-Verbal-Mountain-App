//
//  GRE_VerbalUITests.swift
//  GRE VerbalUITests
//
//  Created by Martin Olivares on 23-01-26.
//

import XCTest

final class GRE_VerbalUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesIntoTabBar() throws {
        let app = XCUIApplication()
        app.launch()

        // App boots through a loading state into the TabView. The Practice tab
        // should appear; this also exercises the launch-path syncShieldVocabulary.
        let practiceTab = app.tabBars.buttons["Practice"]
        XCTAssertTrue(practiceTab.waitForExistence(timeout: 15),
                      "Tab bar with Practice tab never appeared — app may have crashed on launch")
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testNavigatesEveryTabWithoutCrashing() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar never appeared")

        for label in ["Progress", "Timer", "Quant", "Shield", "Practice"] {
            let tab = tabBar.buttons[label]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "\(label) tab missing")
            tab.tap()
            // Each switch should leave the app alive and foregrounded.
            XCTAssertEqual(app.state, .runningForeground, "App left foreground after tapping \(label)")
        }
    }

    @MainActor
    func testShieldTabShowsAppBlocker() throws {
        let app = XCUIApplication()
        app.launch()

        let shieldTab = app.tabBars.buttons["Shield"]
        XCTAssertTrue(shieldTab.waitForExistence(timeout: 15), "Shield tab missing")
        shieldTab.tap()

        // The App Blocker screen renders its title and the headline card text.
        XCTAssertTrue(app.staticTexts["Study Before Scrolling"].waitForExistence(timeout: 5)
                      || app.navigationBars["App Blocker"].waitForExistence(timeout: 5),
                      "App Blocker screen did not render")
        attach(app, "shield-app-blocker")
    }

    /// The big one: actually complete a drill end-to-end. This exercises the
    /// changed completion path — syncShieldVocabulary + startUnlockSession +
    /// the streak/session-complete UI — and proves it doesn't crash.
    @MainActor
    func testCompleteDrillReachesSessionCompleteWithoutCrashing() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Practice"].waitForExistence(timeout: 15))
        attach(app, "home")

        let start = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Start Practice'")).firstMatch
        if !start.waitForExistence(timeout: 5) {
            app.swipeUp()  // reveal it below the fold
        }
        if !start.waitForExistence(timeout: 5) {
            XCTFail("Start Practice button missing. Buttons seen: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
            return
        }
        start.tap()

        // Card counter "N of M" confirms the deck loaded.
        let counter = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] ' of '")).firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 8), "Flashcard deck never appeared")
        attach(app, "flashcard")

        // Tap the green "know it" button (bottom-right) until the session-complete
        // screen shows its "Practice Again" action. Bounded so a stuck UI fails
        // loudly instead of hanging.
        let knowIt = app.coordinate(withNormalizedOffset: CGVector(dx: 0.73, dy: 0.91))
        let again = app.staticTexts["Practice Again"]
        var taps = 0
        while !again.exists && taps < 50 {
            knowIt.tap()
            taps += 1
            usleep(150_000)
        }

        XCTAssertTrue(again.waitForExistence(timeout: 3),
                      "Never reached session-complete after \(taps) cards")
        XCTAssertEqual(app.state, .runningForeground, "App crashed completing the drill")
        attach(app, "session-complete")
    }

    // Save a screenshot into the result bundle so we can pull it out afterward.
    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
