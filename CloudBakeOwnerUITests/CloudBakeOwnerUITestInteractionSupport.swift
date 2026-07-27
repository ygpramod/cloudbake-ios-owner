import XCTest

extension CloudBakeOwnerUITests {
    func tapWhenReady(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element did not exist before tap.", file: file, line: line)
        let ready = NSPredicate(format: "isHittable == true AND isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: ready, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Element was not enabled and hittable before tap.",
            file: file,
            line: line
        )
        element.tap()
    }

    func tapWhenReady(
        _ element: XCUIElement,
        waitingFor destination: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tapWhenReady(element, timeout: timeout, file: file, line: line)
        XCTAssertTrue(
            destination.waitForExistence(timeout: timeout),
            "Tap did not reach the expected destination. Hierarchy: \(app.debugDescription)",
            file: file,
            line: line
        )
    }

    func tapScrollableAction(
        _ element: XCUIElement,
        in scrollContainer: XCUIElement,
        waitingFor destination: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        positionScrollableElementForInteraction(
            element,
            in: scrollContainer,
            app: app,
            timeout: timeout,
            file: file,
            line: line
        )
        for attempt in 0..<2 {
            tapWhenReady(element, timeout: timeout, file: file, line: line)
            if destination.waitForExistence(timeout: timeout) {
                return
            }
            if attempt == 0 {
                app.activate()
            }
        }
        XCTFail(
            "Tap did not reach the expected destination. Hierarchy: \(app.debugDescription)",
            file: file,
            line: line
        )
    }

    func positionScrollableElementForInteraction(
        _ element: XCUIElement,
        in scrollContainer: XCUIElement,
        app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        scrollToHittable(
            element,
            in: app,
            scrollContainer: scrollContainer,
            timeout: timeout,
            file: file,
            line: line
        )
        let positioningDeadline = Date().addingTimeInterval(timeout)
        let scrollFrame = scrollContainer.frame
        let reliableTop = scrollFrame.minY + 100
        let reliableBottom = scrollFrame.maxY - 140

        while element.exists, Date() < positioningDeadline {
            if element.frame.midY > reliableBottom {
                dragPrimaryScrollableArea(
                    in: app,
                    preferred: scrollContainer,
                    fromY: 0.72,
                    toY: 0.42
                )
            } else if element.frame.midY < reliableTop {
                dragPrimaryScrollableArea(
                    in: app,
                    preferred: scrollContainer,
                    fromY: 0.34,
                    toY: 0.58
                )
            } else {
                break
            }

            _ = element.waitForExistence(timeout: 0.5)
        }

        XCTAssertTrue(
            element.isHittable
                && element.frame.midY >= reliableTop
                && element.frame.midY <= reliableBottom,
            "Element was not positioned safely between navigation overlays.",
            file: file,
            line: line
        )
    }

    func tapExisting(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element.firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Element did not exist before tap.", file: file, line: line)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func typeText(
        _ text: String,
        into element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element.firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Element did not exist before typing.", file: file, line: line)
        let hittable = NSPredicate(format: "isHittable == true")
        let hittableExpectation = XCTNSPredicateExpectation(predicate: hittable, object: target)
        XCTAssertEqual(
            XCTWaiter.wait(for: [hittableExpectation], timeout: timeout),
            .completed,
            "Element was not hittable before typing.",
            file: file,
            line: line
        )
        focusTextInput(target, timeout: timeout, file: file, line: line)
        target.typeText(text)
    }

    func focusTextInput(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.5)).tap()
            if waitForKeyboardFocus(element, timeout: 0.8) {
                return
            }

            element.tap()
            if waitForKeyboardFocus(element, timeout: 0.8) {
                return
            }
        } while Date() < deadline

        XCTFail("Text input did not receive keyboard focus before typing.", file: file, line: line)
    }

    private func waitForKeyboardFocus(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let focusPredicate = NSPredicate(format: "hasKeyboardFocus == true")
        let focusExpectation = XCTNSPredicateExpectation(predicate: focusPredicate, object: element)
        if XCTWaiter.wait(for: [focusExpectation], timeout: timeout) == .completed {
            return true
        }

        let keyboard = XCUIApplication().keyboards.firstMatch
        if keyboard.exists || keyboard.waitForExistence(timeout: 0.2) {
            return true
        }

        return keyboard.exists
    }

    func dismissKeyboard(in app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }
        let doneButton = app.buttons["Done"]
        if doneButton.exists, doneButton.isHittable {
            doneButton.tap()
        } else if app.keyboards.buttons["Done"].exists {
            app.keyboards.buttons["Done"].tap()
        } else if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        }

        if app.keyboards.firstMatch.waitForExistence(timeout: 0.5) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        }
    }

    func dismissNativeDialog(
        titled title: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let dialogTitle = app.staticTexts[title]
        XCTAssertTrue(
            dialogTitle.waitForExistence(timeout: timeout),
            "Native dialog did not appear before dismissal.",
            file: file,
            line: line
        )

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.1)).tap()

        let dismissed = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: dismissed, object: dialogTitle)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Native dialog did not dismiss after tapping outside it.",
            file: file,
            line: line
        )
    }

    func nativeDialogAction(
        identifiedBy identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let matches = app.sheets.buttons.matching(identifier: identifier)
        XCTAssertTrue(
            matches.firstMatch.waitForExistence(timeout: timeout),
            "Native dialog action \(identifier) did not appear.",
            file: file,
            line: line
        )
        let matchCount = matches.count
        XCTAssertGreaterThan(
            matchCount,
            0,
            "Native dialog action \(identifier) was not available.",
            file: file,
            line: line
        )
        return matches.element(boundBy: max(0, matchCount - 1))
    }

    func nativeDialogAction(
        labeled label: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let matches = app.sheets.buttons.matching(
            NSPredicate(format: "label == %@", label)
        )
        XCTAssertTrue(
            matches.firstMatch.waitForExistence(timeout: timeout),
            "Native dialog action \(label) did not appear.",
            file: file,
            line: line
        )
        let matchCount = matches.count
        XCTAssertGreaterThan(
            matchCount,
            0,
            "Native dialog action \(label) was not available.",
            file: file,
            line: line
        )
        return matches.element(boundBy: max(0, matchCount - 1))
    }

    func nativeAlertAction(
        labeled label: String,
        in alert: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let matches = alert.buttons.matching(
            NSPredicate(format: "label == %@", label)
        )
        let matchCount = matches.count
        XCTAssertGreaterThan(
            matchCount,
            0,
            "Native alert action \(label) was not available.",
            file: file,
            line: line
        )
        return matches.element(boundBy: max(0, matchCount - 1))
    }

    func tapVisibleElementAtCenter(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Element did not exist before tap.",
            file: file,
            line: line
        )
        XCTAssertTrue(element.isEnabled, "Element was not enabled before tap.", file: file, line: line)

        let appFrame = app.frame
        let elementFrame = element.frame
        let visibleFrame = appFrame.intersection(elementFrame)
        XCTAssertTrue(
            !visibleFrame.isEmpty,
            "Element did not intersect the visible app frame before tap.",
            file: file,
            line: line
        )

        app.coordinate(
            withNormalizedOffset: CGVector(
                dx: (visibleFrame.midX - appFrame.minX) / appFrame.width,
                dy: (visibleFrame.midY - appFrame.minY) / appFrame.height
            )
        ).tap()
    }

    func assertExistsAfterScrolling(
        _ element: XCUIElement,
        in app: XCUIApplication,
        scrollContainer: XCUIElement? = nil,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !element.exists && Date() < deadline {
            swipeUpInPrimaryScrollableArea(in: app, preferred: scrollContainer)
            _ = element.waitForExistence(timeout: 0.25)
        }
        XCTAssertTrue(element.exists, "Element did not exist after scrolling.", file: file, line: line)
    }

    func scrollToHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        scrollContainer: XCUIElement? = nil,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while (!element.exists || !element.isHittable) && Date() < deadline {
            scrollTowardHittableElement(element, in: app, preferred: scrollContainer)
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(element.exists, "Element did not exist after scrolling.", file: file, line: line)
        XCTAssertTrue(element.isHittable, "Element was not hittable after scrolling.", file: file, line: line)
    }

    func scrollToVisible(
        _ element: XCUIElement,
        in app: XCUIApplication,
        scrollContainer: XCUIElement? = nil,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while (!element.exists || !isElementVisible(element, in: app)) && Date() < deadline {
            scrollTowardHittableElement(element, in: app, preferred: scrollContainer)
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(element.exists, "Element did not exist after scrolling.", file: file, line: line)
        XCTAssertTrue(isElementVisible(element, in: app), "Element was not visible after scrolling.", file: file, line: line)
    }

    func scrollToTop(in app: XCUIApplication) {
        for _ in 0..<3 {
            app.swipeDown()
        }
    }

    func swipeUpInPrimaryScrollableArea(
        in app: XCUIApplication,
        preferred scrollView: XCUIElement? = nil
    ) {
        if let scrollView, scrollView.exists {
            scrollView.swipeUp()
            return
        }

        let collectionView = visibleElement(in: app.collectionViews)
        if collectionView.exists {
            collectionView.swipeUp()
            return
        }

        let scrollView = visibleElement(in: app.scrollViews)
        if scrollView.exists {
            scrollView.swipeUp()
            return
        }

        app.swipeUp()
    }

    private func scrollTowardHittableElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        preferred scrollView: XCUIElement?
    ) {
        guard element.exists else {
            swipeUpInPrimaryScrollableArea(in: app, preferred: scrollView)
            return
        }

        let appFrame = app.windows.firstMatch.exists ? app.windows.firstMatch.frame : app.frame
        if element.frame.midY < appFrame.midY {
            dragPrimaryScrollableArea(
                in: app,
                preferred: scrollView,
                fromY: 0.34,
                toY: 0.58
            )
        } else {
            dragPrimaryScrollableArea(
                in: app,
                preferred: scrollView,
                fromY: 0.72,
                toY: 0.48
            )
        }
    }

    private func isElementVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, !element.frame.isEmpty else { return false }
        let appFrame = app.windows.firstMatch.exists ? app.windows.firstMatch.frame : app.frame
        return appFrame.intersects(element.frame)
    }

    private func swipeDownInPrimaryScrollableArea(in app: XCUIApplication) {
        let collectionView = visibleElement(in: app.collectionViews)
        if collectionView.exists {
            collectionView.swipeDown()
            return
        }

        let scrollView = visibleElement(in: app.scrollViews)
        if scrollView.exists {
            scrollView.swipeDown()
            return
        }

        app.swipeDown()
    }

    private func dragPrimaryScrollableArea(
        in app: XCUIApplication,
        preferred scrollView: XCUIElement? = nil,
        fromY: CGFloat,
        toY: CGFloat
    ) {
        let scrollable: XCUIElement
        if let scrollView, scrollView.exists {
            scrollable = scrollView
        } else {
            let collectionView = visibleElement(in: app.collectionViews)
            scrollable =
                collectionView.exists
                ? collectionView
                : visibleElement(in: app.scrollViews)
        }
        guard scrollable.exists else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY)))
            return
        }

        let start = scrollable.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
        let end = scrollable.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func visibleElement(in query: XCUIElementQuery) -> XCUIElement {
        for index in 0..<query.count {
            let candidate = query.element(boundBy: index)
            if candidate.exists, candidate.isHittable {
                return candidate
            }
        }
        return query.firstMatch
    }
}
