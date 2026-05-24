import XCTest

@MainActor
final class IdentifierCoverageUITests: BaseUITestCase {
    /// Labels of system-provided controls we don't own and shouldn't fail on.
    private let systemAllowlist: Set<String> = [
        "Trends", "Now", "Body" // tab item labels
    ]

    func testNoUntaggedButtonsOnPrimaryScreens() {
        var untagged: [String] = []
        check(tab: A11yID.TabBar.now, into: &untagged)
        check(tab: A11yID.TabBar.trends, into: &untagged)
        check(tab: A11yID.TabBar.body, into: &untagged)
        XCTAssertTrue(untagged.isEmpty, "Untagged interactive controls found:\n\(untagged.joined(separator: "\n"))")
    }

    private func check(tab: String, into untagged: inout [String]) {
        tapTab(tab)
        for button in app.buttons.allElementsBoundByIndex where button.exists {
            let id = button.identifier
            let label = button.label
            if id.isEmpty && !label.isEmpty && !systemAllowlist.contains(label) {
                untagged.append("[\(tab)] button labeled '\(label)' has no accessibility identifier")
            }
        }
    }
}
