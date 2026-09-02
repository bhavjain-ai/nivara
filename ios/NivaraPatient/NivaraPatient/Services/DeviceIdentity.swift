import Foundation
import Security

/// A stable, per-install identifier for this device that survives app
/// deletion and reinstallation — generated once and stored in the iOS
/// Keychain, which (unlike UserDefaults or the Documents directory) is not
/// wiped when the app is uninstalled.
///
/// This is deliberately NOT the device's hardware UDID — Apple has not let
/// apps read that since iOS 7 — and it's NOT `UIDevice.identifierForVendor`
/// either, which resets when this app (the only Nivara app on the device)
/// is deleted and reinstalled, defeating the "survives reinstall" property
/// a WhatsApp-style device binding needs. Instead this mints its own random
/// UUID and persists it in the Keychain, the standard approach for a
/// lightweight "remember this install" identity without SMS/OTP.
///
/// Scope note: nothing in this demo build actually sends this anywhere —
/// there's no backend in this repo yet. This is the client-side half of
/// "register this device instead of an OTP phone flow": a backend
/// registration endpoint would receive `DeviceIdentity.current` once at
/// enrollment and look it up on subsequent launches to recognize the
/// device. It is NOT a fraud-proof hardware attestation — a jailbroken
/// device or a replayed value could still spoof it, since it's just a
/// client-generated string. If the backend needs to be sure a request
/// really came from a genuine copy of this app on a genuine Apple device
/// (not just "a device claiming to be this one"), pair it server-side with
/// Apple's DeviceCheck or App Attest framework; that's a separate,
/// server-verified signal layered on top of this identifier, not a
/// replacement for it.
enum DeviceIdentity {
    private static let service = "com.nivara.patient.deviceIdentity"
    private static let account = "deviceID"

    /// The device's stable identifier — created and persisted to the
    /// Keychain on first access if none exists yet.
    static let current: String = {
        if let existing = readFromKeychain() {
            return existing
        }
        let newID = UUID().uuidString
        writeToKeychain(newID)
        return newID
    }()

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeToKeychain(_ value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Idempotent: clear any stale entry (e.g. from a previous install
        // that left a Keychain item behind, since Keychain data can outlive
        // an uninstall) before writing the fresh value.
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
