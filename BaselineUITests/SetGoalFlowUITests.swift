import XCTest

@MainActor
final class SetGoalFlowUITests: BaseUITestCase {
    // .populated has NO active goal, so the "Set Goal" affordance is present.
    override var seedProfile: SeedProfile { .populated }

    func testSetWeightGoalEntersGoalMode() {
        tapTab(A11yID.TabBar.trends)
        let setGoal = app.buttons[A11yID.Trends.setGoalButton]
        XCTAssertTrue(setGoal.waitForExistence(timeout: Self.defaultTimeout))
        setGoal.tap()

        let target = app.textFields[A11yID.SetGoal.targetField]
        XCTAssertTrue(target.waitForExistence(timeout: Self.defaultTimeout))
        target.tap()
        target.typeText("185")

        app.buttons[A11yID.SetGoal.save].tap()

        // After saving, the manage-goal affordance replaces set-goal.
        XCTAssertTrue(app.buttons[A11yID.Trends.manageGoalButton].waitForExistence(timeout: Self.defaultTimeout))
    }
}
