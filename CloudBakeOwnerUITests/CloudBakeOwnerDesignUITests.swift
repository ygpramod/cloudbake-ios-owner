import XCTest

extension CloudBakeOwnerUITests {
    func testDesignRemovalCanBeCancelledAndConfirmed() throws {
        let app = makeApp(initialDestination: "designs")
        app.launchEnvironment["CLOUDBAKE_SEED_CAKE_DESIGN_FIXTURE"] = "1"
        app.launch()

        let design = app.buttons["designs.item.design-ui-fixture-floral"]
        XCTAssertTrue(design.waitForExistence(timeout: 10))
        tapWhenReady(design)

        let remove = app.buttons["Remove Design"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        tapWhenReady(remove)
        XCTAssertTrue(app.staticTexts["Remove Design?"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "image remains in Photos")
            ).firstMatch.exists
        )
        dismissNativeDialog(titled: "Remove Design?", in: app)
        XCTAssertTrue(app.buttons["designs.preview.done"].exists)

        tapWhenReady(remove)
        XCTAssertTrue(app.staticTexts["Remove Design?"].waitForExistence(timeout: 5))
        let confirm = nativeDialogAction(
            identifiedBy: "designs.delete.confirm",
            in: app
        )
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        tapWhenReady(confirm)

        XCTAssertTrue(app.staticTexts["No owner designs saved"].waitForExistence(timeout: 5))
    }

    func testDesignCanStartAnUnsavedOrderDraftWithTheDesignLinked() throws {
        let app = makeApp(initialDestination: "designs")
        app.launchEnvironment["CLOUDBAKE_SEED_CAKE_DESIGN_FIXTURE"] = "1"
        app.launch()

        let design = app.buttons["designs.item.design-ui-fixture-floral"]
        XCTAssertTrue(design.waitForExistence(timeout: 10))
        tapWhenReady(design)
        let useForNewOrder = app.buttons["designs.preview.useForNewOrder"]
        XCTAssertTrue(useForNewOrder.waitForExistence(timeout: 5))
        tapWhenReady(useForNewOrder)

        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: 10))
        let linkedDesign = app.buttons["orders.form.design"]
        scrollToHittable(linkedDesign, in: app, timeout: 10)
        XCTAssertTrue(linkedDesign.label.contains("Pink Floral Cake"))
        tapWhenReady(app.buttons["orders.form.cancel"])

        XCTAssertTrue(app.staticTexts["No orders yet"].waitForExistence(timeout: 5))
    }

    func testCustomerReferenceDraftShowsItsCurrentSelectedProvenance() throws {
        let app = makeApp(initialDestination: "designs")
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_PHOTO_FIXTURE"] = "1"
        app.launch()

        let reference = app.buttons["designs.reference.design-ui-fixture-reference"]
        scrollToVisible(
            reference,
            in: app,
            scrollContainer: app.scrollViews["screen.designs"]
        )
        let useForNewOrder = app.buttons["designs.preview.useForNewOrder"]
        tapVisibleElementAtCenter(reference, in: app)
        XCTAssertTrue(useForNewOrder.waitForExistence(timeout: 15))
        tapWhenReady(useForNewOrder, timeout: 15)

        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: 10))
        let designField = app.buttons["orders.form.design"]
        scrollToHittable(designField, in: app, timeout: 10)
        XCTAssertTrue(designField.label.contains("Customer sketch"))
        tapWhenReady(designField)

        let currentReference = app.descendants(matching: .any)[
            "orders.designSelection.reference.design-ui-fixture-reference"
        ]
        XCTAssertTrue(currentReference.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["orders.designSelection.none"].isEnabled)
    }

    func testDesignDetailSupportsZoomControlsAndAdjacentSwipe() throws {
        let app = makeApp(initialDestination: "designs")
        app.launchEnvironment["CLOUDBAKE_SEED_DESIGN_GALLERY_FIXTURE"] = "1"
        app.launch()

        let floralFilter = app.buttons["#Floral"]
        XCTAssertTrue(floralFilter.waitForExistence(timeout: 10))
        tapWhenReady(floralFilter)

        let firstDesign = app.buttons["designs.item.design-ui-gallery-first"]
        XCTAssertTrue(firstDesign.waitForExistence(timeout: 10))
        tapWhenReady(firstDesign)

        let zoomControls = app.descendants(matching: .any)["designs.preview.zoomControls"]
        XCTAssertTrue(zoomControls.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Zoom In"].exists)
        XCTAssertTrue(app.buttons["Zoom Out"].exists)
        XCTAssertTrue(app.buttons["Reset Zoom"].exists)

        let photo = app.descendants(matching: .any)["designs.preview.photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        XCTAssertTrue(String(describing: photo.value).contains("100 percent"))
        tapWhenReady(app.buttons["Zoom In"])
        XCTAssertTrue(String(describing: photo.value).contains("150 percent"))
        tapWhenReady(app.buttons["Reset Zoom"])

        photo.swipeLeft()
        XCTAssertTrue(app.navigationBars["Second Gallery Cake"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["designs.preview.photo"].swipeRight()
        XCTAssertTrue(app.navigationBars["First Gallery Cake"].waitForExistence(timeout: 5))

        XCTAssertFalse(app.buttons["Previous Design"].isEnabled)
        tapWhenReady(app.buttons["Add Favorite"])
        tapWhenReady(app.buttons["Next Design"])

        XCTAssertTrue(app.navigationBars["Second Gallery Cake"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Next Design"].isEnabled)
        tapWhenReady(app.buttons["Previous Design"])
        XCTAssertTrue(app.navigationBars["First Gallery Cake"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Remove Favorite"].exists)

        tapWhenReady(app.navigationBars.buttons["Tags"])
        let tagsAlert = app.alerts["Edit Tags"]
        XCTAssertTrue(tagsAlert.waitForExistence(timeout: 5))
        let tagsField = tagsAlert.textFields.firstMatch
        XCTAssertTrue(tagsField.waitForExistence(timeout: 5))
        tagsField.tap()
        tagsField.typeText(", Wedding")
        tapVisibleElementAtCenter(nativeAlertAction(labeled: "Save", in: tagsAlert), in: app)
        tapWhenReady(app.buttons["Next Design"])
        tapWhenReady(app.buttons["Previous Design"])
        tapWhenReady(app.navigationBars.buttons["Tags"])
        let updatedTagsAlert = app.alerts["Edit Tags"]
        XCTAssertTrue(updatedTagsAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(
            String(describing: updatedTagsAlert.textFields.firstMatch.value)
                .contains("Wedding")
        )
        tapVisibleElementAtCenter(
            nativeAlertAction(labeled: "Cancel", in: updatedTagsAlert),
            in: app
        )
    }

    func testDesignLandingCanScrollFromBottomBackToTop() throws {
        let app = makeApp(initialDestination: "designs")
        app.launchEnvironment["CLOUDBAKE_SEED_CAKE_DESIGN_FIXTURE"] = "1"
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_PHOTO_FIXTURE"] = "1"
        app.launchEnvironment["CLOUDBAKE_SEED_DESIGN_SCROLL_FIXTURE"] = "1"
        app.launch()

        let finalReference = app.buttons["designs.reference.design-ui-fixture-reference"]
        let designsScroll = app.scrollViews["screen.designs"]
        XCTAssertTrue(designsScroll.waitForExistence(timeout: 10))
        for _ in 0..<4 { designsScroll.swipeUp() }
        XCTAssertTrue(finalReference.isHittable)

        for _ in 0..<3 { app.swipeUp() }

        Thread.sleep(forTimeInterval: 1)
        let settledPositions = (0..<8).map { _ in
            let position = finalReference.frame.minY
            Thread.sleep(forTimeInterval: 0.1)
            return position
        }
        let verticalMovement = (settledPositions.max() ?? 0) - (settledPositions.min() ?? 0)
        XCTAssertLessThan(
            verticalMovement,
            2,
            "Designs screen continued moving after the bottom scroll gesture ended."
        )

        for _ in 0..<4 { app.swipeDown() }

        let search = app.descendants(matching: .any)["designs.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(search.isHittable)
    }

    func testMyDesignsAddActionOpensPhotosOwnedImportForm() throws {
        let app = makeApp(initialDestination: "designs")
        app.launch()

        let add = app.buttons["designs.myDesigns.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        tapWhenReady(add)

        XCTAssertTrue(app.navigationBars["Add My Design"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["designs.ownerDesign.photo"].exists)
        XCTAssertTrue(app.textFields["designs.ownerDesign.name"].exists)
        XCTAssertTrue(app.textFields["designs.ownerDesign.tags"].exists)
        XCTAssertTrue(app.buttons["designs.ownerDesign.save"].exists)
    }

    func testReferenceImportRequiresAPhotoWithVisibleFeedback() throws {
        let app = makeApp(initialDestination: "designs")
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_PHOTO_FIXTURE"] = "1"
        app.launch()

        let addReference = app.descendants(matching: .any)["designs.references.add"]
        scrollToHittable(addReference, in: app, timeout: 10)
        tapWhenReady(addReference)
        XCTAssertTrue(app.navigationBars["Import Reference"].waitForExistence(timeout: 5))

        tapWhenReady(app.buttons["designs.referenceImport.save"])
        XCTAssertTrue(
            app.staticTexts["designs.referenceImport.error"].waitForExistence(timeout: 5)
        )
        XCTAssertEqual(
            app.staticTexts["designs.referenceImport.error"].label,
            "Reference photo is required."
        )
    }

}
