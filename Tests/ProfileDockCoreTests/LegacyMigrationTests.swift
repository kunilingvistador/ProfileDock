import Foundation
import XCTest
@testable import ProfileDockCore

final class LegacyMigrationTests: XCTestCase {
    // A source fixture, never compiled or executed. Conversion must recognize the
    // old window-focusing flow, not merely a matching application bundle name.
    private let supported = #"""
    use framework "AppKit"
    use scripting additions
    on run
        my focusExistingWindow()
    end run
    on reopen
        my focusExistingWindow()
    end reopen
    on focusExistingWindow()
        set targetName to "Работа \"Studio\""
        tell application "Google Chrome"
            set targetID to id of first window whose given name is targetName
            set minimized of window id targetID to false
            set index of window id targetID to 1
        end tell
        set apps to current application's NSRunningApplication's runningApplicationsWithBundleIdentifier:"com.google.Chrome"
        if (count of apps) > 0 then
            (item 1 of apps)'s activateWithOptions:0
        end if
    end focusExistingWindow
    """#

    func testRecognizesTheSupportedWindowFocusingTemplateWithoutLosingUnicodeOrQuotes() {
        XCTAssertEqual(LegacyShortcutImport.supportedTarget(in: supported), "Работа \"Studio\"")
    }

    func testBlockCommentsCannotSupplyOrHideAMigrationTarget() {
        for source in [
            "(*\nset targetName to \"Wrong window\"\n*)\n" + supported,
            "(*\n" + supported + "\n*)",
            supported + "\n(* explanatory comment *)",
        ] {
            XCTAssertNil(LegacyShortcutImport.supportedTarget(in: source))
        }
    }

    func testMultipleTargetAssignmentsAreNotSafeToMigrate() {
        XCTAssertNil(LegacyShortcutImport.supportedTarget(in:
            supported + "\nset targetName to \"Other window\""))
        let sameAssignment = supported.split(separator: "\n").first { $0.contains("set targetName") }!
        XCTAssertNil(LegacyShortcutImport.supportedTarget(in:
            supported + "\n" + sameAssignment))
    }

    func testCommentedTemplateAndBareNameRemainReadOnlyImportCandidates() {
        let commented = supported.split(separator: "\n").map { "-- " + $0 }.joined(separator: "\n")
        let source = commented + "\nset targetName to \"Only a name\""
        XCTAssertEqual(LegacyShortcutImport.targetName(in: source), "Only a name")
        XCTAssertNil(LegacyShortcutImport.supportedTarget(in: source))
        XCTAssertNil(LegacyShortcutImport.supportedTarget(in: "set targetName to \"Only a name\""))
    }

    func testExtraExecutionAndWindowCreationCommandsDisqualifyConversion() {
        for command in [
            #"do shell script "echo unexpected""#,
            #"run script "return 1""#,
            #"open location "https://example.test/""#,
            "make new window",
        ] {
            XCTAssertNil(LegacyShortcutImport.supportedTarget(in: supported + "\n" + command), command)
        }
    }

    func testMissingReopenOrDifferentActivationBehaviorIsNotSilentlyConverted() {
        XCTAssertNil(LegacyShortcutImport.supportedTarget(in:
            supported.replacingOccurrences(of: "on reopen", with: "on unrelatedHandler")))
        XCTAssertNil(LegacyShortcutImport.supportedTarget(in:
            supported.replacingOccurrences(of: "activateWithOptions:0", with: "activateWithOptions:1")))
        XCTAssertNil(LegacyShortcutImport.supportedTarget(in:
            supported.replacingOccurrences(of: "set index of window id targetID to 1", with: "activate")))
    }
}
