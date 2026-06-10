import XCTest
@testable import Baseline

final class OnboardingViewModelTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "OnboardingVMTests")!
        defaults.removePersistentDomain(forName: "OnboardingVMTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "OnboardingVMTests")
        defaults = nil
        super.tearDown()
    }

    func testCompleteSetsFlagWithoutWritingName() {
        let vm = OnboardingViewModel(defaults: defaults)
        vm.complete()
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
        XCTAssertNil(defaults.string(forKey: "userName"))
    }

    func testCompleteSavingNameTrimsPersistsAndSetsFlag() {
        let vm = OnboardingViewModel(defaults: defaults)
        vm.draftName = "  Ben "
        vm.completeSavingName()
        XCTAssertEqual(defaults.string(forKey: "userName"), "Ben")
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
    }

    func testCompleteSavingNameWithBlankDraftBehavesLikeSkip() {
        let vm = OnboardingViewModel(defaults: defaults)
        vm.draftName = "   "
        vm.completeSavingName()
        XCTAssertNil(defaults.string(forKey: "userName"))
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
    }
}
