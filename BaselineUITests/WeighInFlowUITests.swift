import XCTest

@MainActor
final class WeighInFlowUITests: BaseUITestCase {
    func testIncrementAndSaveWeighIn() {
        tapTab(A11yID.TabBar.now)
        app.buttons[A11yID.Now.weighInButton].tap()

        let plus = app.buttons[A11yID.WeighIn.stepperPlus]
        XCTAssertTrue(plus.waitForExistence(timeout: Self.defaultTimeout))
        plus.tap(); plus.tap() // +0.2

        app.buttons[A11yID.WeighIn.save].tap()

        // .populated seed has a TODAY entry → Save triggers the overwrite alert; confirm it.
        // Use .firstMatch to avoid ambiguity if the identifier is present on multiple
        // elements in the accessibility hierarchy (alert + hosting view duplication).
        let overwrite = app.buttons[A11yID.WeighIn.overwriteConfirm].firstMatch
        if overwrite.waitForExistence(timeout: 3) {
            overwrite.tap()
        }

        // Sheet dismisses back to Now.
        XCTAssertTrue(app.buttons[A11yID.Now.weighInButton].waitForExistence(timeout: Self.defaultTimeout))
    }
}
