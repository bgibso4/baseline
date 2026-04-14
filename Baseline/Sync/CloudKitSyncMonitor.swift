import Foundation
import CloudKit
import CoreData
import os

/// Monitors NSPersistentCloudKitContainer sync events and handles the
/// iCloud Keychain reset edge case (encrypted field data becomes unreadable).
///
/// Call `CloudKitSyncMonitor.start()` once at app launch.
enum CloudKitSyncMonitor {

    private static let logger = Logger(subsystem: "com.cadre.baseline", category: "CloudKitSync")
    private static var observer: NSObjectProtocol?

    /// Begin observing CloudKit sync events.
    static func start() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }

            if let error = event.error {
                handleSyncError(error)
            }
        }
    }

    /// Check whether a CKError indicates the user reset their iCloud Keychain,
    /// making previously encrypted CloudKit data unreadable.
    static func isKeychainResetError(_ error: CKError) -> Bool {
        guard error.code == .zoneNotFound else { return false }
        return error.userInfo[CKErrorUserDidResetEncryptedDataKey] != nil
    }

    // MARK: - Private

    private static func handleSyncError(_ error: Error) {
        let nsError = error as NSError

        if let ckError = error as? CKError, isKeychainResetError(ckError) {
            handleKeychainReset()
            return
        }

        // NSPersistentCloudKitContainer nests CKErrors in underlying error
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? CKError,
           isKeychainResetError(underlying) {
            handleKeychainReset()
            return
        }

        // Check partial failure errors
        if let partialErrors = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            for (_, partialError) in partialErrors {
                if let ckError = partialError as? CKError, isKeychainResetError(ckError) {
                    handleKeychainReset()
                    return
                }
            }
        }

        logger.warning("CloudKit sync error: \(error.localizedDescription)")
    }

    private static func handleKeychainReset() {
        logger.error("iCloud Keychain was reset — encrypted CloudKit data is unreadable. Local data is intact.")
        // Local SwiftData store is unaffected (encryption is cloud-side only).
        // NSPersistentCloudKitContainer will automatically re-export local records
        // on the next sync cycle, encrypting them with the new key material.
    }
}
