import XCTest
@testable import Khmerlang_Keyboard_IOS

final class KeyboardLogicTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SharedStore.spellCheckEnabled = false
        SharedStore.spellCheckConsentGranted = false
    }

    override func tearDown() {
        SharedStore.spellCheckEnabled = false
        SharedStore.spellCheckConsentGranted = false
        super.tearDown()
    }

    func testCloudSpellCheckDefaultsAreOff() {
        XCTAssertFalse(SharedStore.spellCheckEnabled)
        XCTAssertFalse(SharedStore.spellCheckConsentGranted)
    }

    func testCloudSpellCheckConsentAndFeatureFlagsPersist() {
        SharedStore.spellCheckConsentGranted = true
        SharedStore.spellCheckEnabled = true

        XCTAssertTrue(SharedStore.spellCheckConsentGranted)
        XCTAssertTrue(SharedStore.spellCheckEnabled)
    }
}
