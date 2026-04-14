import XCTest
import CloudKit
@testable import Baseline

final class CloudKitSyncMonitorTests: XCTestCase {

    func testDetectsKeychainResetError() {
        let error = CKError(
            CKError.Code.zoneNotFound,
            userInfo: [CKErrorUserDidResetEncryptedDataKey: NSNumber(value: true)]
        )
        XCTAssertTrue(CloudKitSyncMonitor.isKeychainResetError(error))
    }

    func testIgnoresNormalZoneNotFoundError() {
        let error = CKError(CKError.Code.zoneNotFound)
        XCTAssertFalse(CloudKitSyncMonitor.isKeychainResetError(error))
    }

    func testIgnoresUnrelatedErrors() {
        let error = CKError(CKError.Code.networkUnavailable)
        XCTAssertFalse(CloudKitSyncMonitor.isKeychainResetError(error))
    }
}
