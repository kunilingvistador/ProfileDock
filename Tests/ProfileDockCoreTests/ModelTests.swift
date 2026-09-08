import Foundation
import XCTest
@testable import ProfileDockCore

final class ModelTests: XCTestCase {
    private let firstID = UUID(uuidString: "12345678-1111-4111-8111-111111111111")!
    private let samePrefixID = UUID(uuidString: "12345678-2222-4222-8222-222222222222")!

    private func window(_ id: String, name: String, title: String = "A browser tab", minimized: Bool = false, incognito: Bool = false) -> BrowserWindow {
        BrowserWindow(id: id, givenName: name, title: title, minimized: minimized, incognito: incognito)
    }

    func testMatchUsesTheExactGivenNameRatherThanTabTitleOrSubstring() {
        let target = window("1", name: "Work")
        let windows = [
            window("2", name: "Work archive"),
            window("3", name: "work"),
            window("4", name: "Personal", title: "Work"),
            window("5", name: " Work "),
            target,
        ]
        XCTAssertEqual(WindowMatcher.match(name: "Work", in: windows), .found(target))
        XCTAssertEqual(WindowMatcher.match(name: "Wor", in: windows), .missing)
    }

    func testBlankNamesCannotBindUnnamedWindows() {
        let windows = [window("1", name: ""), window("2", name: " \n\t")]
        for name in ["", " ", "\n\t", " \n\t"] {
            XCTAssertEqual(WindowMatcher.match(name: name, in: windows), .missing, name.debugDescription)
        }
    }

    func testMissingNameDoesNotFallBackToTheOnlyWindow() {
        XCTAssertEqual(WindowMatcher.match(name: "Work", in: []), .missing)
        XCTAssertEqual(WindowMatcher.match(name: "Work", in: [window("1", name: "Personal")]), .missing)
    }

    func testDuplicateNamesFailClosedRegardlessOfWindowOrder() {
        let windows = [window("1", name: "Work"), window("2", name: "Work", minimized: true)]
        XCTAssertEqual(WindowMatcher.match(name: "Work", in: windows), .ambiguous)
        XCTAssertEqual(WindowMatcher.match(name: "Work", in: Array(windows.reversed())), .ambiguous)
    }

    func testMinimizedWindowRemainsTheSameTarget() {
        let target = window("1", name: "Work", minimized: true)
        XCTAssertEqual(WindowMatcher.match(name: "Work", in: [target]), .found(target))
    }

    func testPrivateWindowsAreNeverSelectedOrCountedAsNormalMatches() {
        let normal = window("1", name: "Work")
        let privateWindow = window("2", name: "Work", incognito: true)
        XCTAssertEqual(WindowMatcher.match(name: "Work", in: [privateWindow]), .missing)
        XCTAssertEqual(WindowMatcher.match(name: "Work", in: [normal, privateWindow]), .found(normal))
    }

    func testBindingNameIsDeterministicAndKeepsAReadableLabel() {
        let name = WindowMatcher.bindingName(displayName: "  Work team \n", id: firstID)
        XCTAssertEqual(name, WindowMatcher.bindingName(displayName: "Work team", id: firstID))
        XCTAssertTrue(name.hasPrefix("Work team"))
        XCTAssertFalse(name.contains("\n"))
    }

    func testBindingNameKeepsIdentityAfterReadableLabelsAreTruncated() {
        let longName = String(repeating: "👩🏽‍💻", count: 90)
        let binding = WindowMatcher.bindingName(displayName: longName, id: firstID)
        XCTAssertTrue(binding.hasPrefix(String(longName.prefix(60))))
        XCTAssertFalse(binding.contains(longName))
        XCTAssertNotEqual(binding, WindowMatcher.bindingName(displayName: longName, id: samePrefixID),
                          "A shortened display label must not collapse distinct shortcut identities.")
    }

    func testBindingNamesDoNotCollideWhenUUIDPrefixesMatch() {
        XCTAssertNotEqual(WindowMatcher.bindingName(displayName: "Work", id: firstID),
                          WindowMatcher.bindingName(displayName: "Work", id: samePrefixID))
    }

    func testGeneratedFocusRouteRoundTripsTheCompleteID() {
        for id in [firstID, samePrefixID, UUID()] {
            XCTAssertEqual(ShortcutRoute.parse(ShortcutRoute.focusURL(id)), .focus(id))
        }
    }

    func testFocusRouteAcceptsCaseInsensitiveSchemeAndUUID() throws {
        let url = try XCTUnwrap(URL(string: "PROFILEDOCK://focus/\(firstID.uuidString.lowercased())"))
        XCTAssertEqual(ShortcutRoute.parse(url), .focus(firstID))
    }

    func testShowRouteOnlyAcceptsItsRootPath() throws {
        for value in ["profiledock://show", "profiledock://show/"] {
            XCTAssertEqual(ShortcutRoute.parse(try XCTUnwrap(URL(string: value))), .show)
        }
        for value in ["profiledock://show//", "profiledock://show/settings", "profiledock:show"] {
            XCTAssertNil(ShortcutRoute.parse(try XCTUnwrap(URL(string: value))), value)
        }
    }

    func testMalformedFocusRoutesFailClosed() throws {
        let id = firstID.uuidString
        let routes = [
            "profiledock://focus",
            "profiledock://focus/",
            "profiledock://focus/not-a-uuid",
            "profiledock://focus/12345678",
            "profiledock://focus/\(id.dropLast())",
            "profiledock://focus/\(id)/",
            "profiledock://focus//\(id)",
            "profiledock://focus/\(id)/extra",
            "profiledock://focus/../\(id)",
            "profiledock://focus/%2F\(id)",
            "profiledock:///focus/\(id)",
            "profiledock://unknown/\(id)",
            "https://focus/\(id)",
            "file:///focus/\(id)",
        ]
        for route in routes {
            XCTAssertNil(ShortcutRoute.parse(try XCTUnwrap(URL(string: route))), route)
        }
    }

    func testRoutesRejectQueriesFragmentsCredentialsAndPorts() throws {
        for base in ["profiledock://show", "profiledock://focus/\(firstID.uuidString)"] {
            for suffix in ["?", "?open=true", "#", "#anything"] {
                let value = base + suffix
                XCTAssertNil(ShortcutRoute.parse(try XCTUnwrap(URL(string: value))), value)
            }
        }
        for authority in ["user@focus", "user:secret@focus", ":secret@focus", "focus:443"] {
            let value = "profiledock://\(authority)/\(firstID.uuidString)"
            XCTAssertNil(ShortcutRoute.parse(try XCTUnwrap(URL(string: value))), value)
        }
    }

    func testFilenameRemainsOneComponentInsideItsDestination() {
        let destination = URL(fileURLWithPath: "/tmp/profiledock-tests", isDirectory: true)
        let hostileNames = ["../../other", "/Applications/Other", "..\\..\\Other", "a:b", "line\nreturn\r\ttab\0"]
        for input in hostileNames {
            let filename = SafeFilename.make(input, id: firstID)
            XCTAssertFalse(filename.contains("/"), input.debugDescription)
            XCTAssertFalse(filename.contains("\\"), input.debugDescription)
            XCTAssertFalse(filename.contains(":"), input.debugDescription)
            XCTAssertFalse(filename.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) })
            let output = destination.appendingPathComponent(filename).standardizedFileURL
            XCTAssertEqual(output.deletingLastPathComponent(), destination.standardizedFileURL)
            XCTAssertEqual(output.pathExtension, "app")
        }
    }

    func testFilenameProvidesAUsefulFallbackForEmptyAndDotNames() {
        for input in ["", " \n ", ".", ".."] {
            let filename = SafeFilename.make(input, id: firstID)
            XCTAssertTrue(filename.hasPrefix("Profile"), input.debugDescription)
            XCTAssertTrue(filename.hasSuffix(".app"))
        }
    }

    func testFilenameKeepsOrdinaryUnicodeNamesReadable() {
        for input in ["Работа", "仕事", "Café", "Family 👨‍👩‍👧‍👦"] {
            XCTAssertTrue(SafeFilename.make(input, id: firstID).hasPrefix(input), input)
        }
    }

    func testFilenameIsDeterministicAndDoesNotCollideForMatchingIDPrefixes() {
        let first = SafeFilename.make("Work", id: firstID)
        XCTAssertEqual(first, SafeFilename.make("Work", id: firstID))
        XCTAssertNotEqual(first, SafeFilename.make("Work", id: samePrefixID),
                          "Two distinct shortcuts with the same visible name must have distinct file paths.")
    }

    func testFilenameFitsTheFilesystemByteLimitWithoutBreakingUnicode() {
        for input in [String(repeating: "A", count: 400), String(repeating: "界", count: 200), String(repeating: "👨‍👩‍👧‍👦", count: 100)] {
            let filename = SafeFilename.make(input, id: firstID)
            XCTAssertLessThanOrEqual(filename.utf8.count, 255,
                                     "Filesystem component limits count bytes, not grapheme clusters.")
            XCTAssertTrue(filename.hasSuffix(".app"))
            XCTAssertFalse(filename.contains("�"))
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileDock-CoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func shortcut(id: UUID? = nil, name: String = "Work", windowName: String = "Bound work window", iconFile: String? = nil) -> Shortcut {
        Shortcut(id: id ?? firstID, name: name, windowName: windowName,
                 profileDirectory: "Profile 1", iconFile: iconFile, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testStoreTreatsAnAbsentFileAsAnEmptyConfiguration() throws {
        let store = ShortcutStore(directory: try temporaryDirectory().appendingPathComponent("Not created"))
        XCTAssertEqual(try store.load(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.file.path))
    }

    func testStoreRoundTripsAndReplacesACompleteConfiguration() throws {
        let store = ShortcutStore(directory: try temporaryDirectory().appendingPathComponent("Settings"))
        let original = [shortcut()]
        try store.save(original)
        XCTAssertEqual(try store.load(), original)
        let updated = [shortcut(name: "Renamed work"), shortcut(id: samePrefixID, name: "Personal", windowName: "Other window")]
        try store.save(updated)
        XCTAssertEqual(try store.load(), updated)
        let decoded = try JSONDecoder().decode(StateDocument.self, from: Data(contentsOf: store.file))
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.shortcuts, updated)
        try store.save([])
        XCTAssertEqual(try store.load(), [])
    }

    func testInvalidSaveLeavesThePreviousFileByteForByteIntact() throws {
        let store = ShortcutStore(directory: try temporaryDirectory())
        try store.save([shortcut()])
        let originalBytes = try Data(contentsOf: store.file)
        let invalidSets = [
            [shortcut(name: " \n")],
            [shortcut(name: String(repeating: "x", count: 101))],
            [shortcut(windowName: "\t")],
            [shortcut(windowName: String(repeating: "x", count: 501))],
            [shortcut(), shortcut(name: "Same identity")],
            [shortcut(iconFile: "../../outside.png")],
            [shortcut(iconFile: "/tmp/outside.png")],
            [shortcut(iconFile: samePrefixID.uuidString + ".png")],
        ]
        for invalid in invalidSets {
            XCTAssertThrowsError(try store.save(invalid))
            XCTAssertEqual(try Data(contentsOf: store.file), originalBytes)
            XCTAssertEqual(try store.load(), [shortcut()])
        }
    }

    func testInvalidSaveDoesNotCreateAConfigurationFile() throws {
        let store = ShortcutStore(directory: try temporaryDirectory().appendingPathComponent("New settings"))
        XCTAssertThrowsError(try store.save([shortcut(name: " ")]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.file.path))
    }

    func testStoreAcceptsOnlyTheShortcutOwnedIconFilename() throws {
        let store = ShortcutStore(directory: try temporaryDirectory())
        let item = shortcut(iconFile: firstID.uuidString + ".png")
        try store.save([item])
        XCTAssertEqual(try store.load(), [item])
    }

    func testMalformedImportedStateIsReportedWithoutChangingTheFile() throws {
        let store = ShortcutStore(directory: try temporaryDirectory())
        var newer = StateDocument(shortcuts: [shortcut()]); newer.version = 999
        var older = StateDocument(shortcuts: [shortcut()]); older.version = 0
        let encoder = JSONEncoder()
        let invalidDocuments = [
            Data("{\"version\":1,\"shortcuts\":[".utf8),
            Data("{}".utf8),
            Data("[]".utf8),
            try encoder.encode(newer),
            try encoder.encode(older),
            try encoder.encode(StateDocument(shortcuts: [shortcut(), shortcut()])),
            try encoder.encode(StateDocument(shortcuts: [shortcut(name: "")])),
            try encoder.encode(StateDocument(shortcuts: [shortcut(iconFile: "../foreign.png")])),
        ]
        for bytes in invalidDocuments {
            try bytes.write(to: store.file)
            XCTAssertThrowsError(try store.load())
            XCTAssertEqual(try Data(contentsOf: store.file), bytes)
        }
    }

    func testProfileDiscoveryRejectsDirectoryTraversalAndNonProfileKeys() throws {
        let root = try temporaryDirectory()
        var cache: [String: [String: Any]] = ["Default": ["name": "Personal"], "Profile 1": ["name": "Work"]]
        for invalid in ["../Profile 1", "Profile 1/../../other", "/tmp/Profile 1", "Profile 1\\..\\other", ".", "..", "Guest Profile", "System Profile", "Profile1", "Profile -1"] {
            cache[invalid] = ["name": "Must not appear"]
        }
        let bytes = try JSONSerialization.data(withJSONObject: ["profile": ["info_cache": cache]])
        let profiles = try ChromeProfileDiscovery.decode(localState: bytes, root: root)
        XCTAssertEqual(Set(profiles.map(\.id)), Set(["Default", "Profile 1"]))
    }

    func testProfileDiscoveryRetainsDirectoryIdentityAndHandlesMissingOptionalFields() throws {
        let root = try temporaryDirectory()
        let picture = root.appendingPathComponent("Default").appendingPathComponent("Google Profile Picture.png")
        try FileManager.default.createDirectory(at: picture.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0]).write(to: picture)
        let cache: [String: [String: Any]] = [
            "Default": ["name": "Personal", "user_name": "person@example.test"],
            "Profile 1": ["name": "", "user_name": ""],
            "Profile 2": [:],
        ]
        let bytes = try JSONSerialization.data(withJSONObject: ["profile": ["info_cache": cache]])
        let profiles = try ChromeProfileDiscovery.decode(localState: bytes, root: root)
        let personal = try XCTUnwrap(profiles.first { $0.id == "Default" })
        XCTAssertEqual(personal.name, "Personal")
        XCTAssertEqual(personal.account, "person@example.test")
        XCTAssertEqual(personal.avatarPath, picture.path)
        for id in ["Profile 1", "Profile 2"] {
            let profile = try XCTUnwrap(profiles.first { $0.id == id })
            XCTAssertEqual(profile.name, id)
            XCTAssertNil(profile.account)
            XCTAssertNil(profile.avatarPath)
        }
    }

    func testProfileDiscoveryHandlesMissingStructureAndMalformedJSON() throws {
        let root = try temporaryDirectory()
        for value in ["{}", "[]", "{\"profile\":{}}", "{\"profile\":{\"info_cache\":[]}}"] {
            XCTAssertEqual(try ChromeProfileDiscovery.decode(localState: Data(value.utf8), root: root), [])
        }
        XCTAssertThrowsError(try ChromeProfileDiscovery.decode(localState: Data("{".utf8), root: root))
    }

    func testFaviconWebsiteInputAcceptsHTTPAndAddsHTTPSForBareDomains() throws {
        XCTAssertEqual(FaviconDiscovery.websiteURL("  example.com/path  ")?.absoluteString, "https://example.com/path")
        for value in ["https://example.com/path", "https://example.com:443/path", "HTTPS://example.com/"] {
            let url = try XCTUnwrap(FaviconDiscovery.websiteURL(value))
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "example.com")
        }
    }

    func testFaviconWebsiteInputRejectsCredentialsAndNonHTTPResources() {
        for value in ["", " \n ", "file:///tmp/image.png", "javascript://example.com", "data:image/png;base64,AAAA", "ftp://example.com/icon.png", "https://", "https://user@example.com/icon.png", "https://user:password@example.com/icon.png"] {
            XCTAssertNil(FaviconDiscovery.websiteURL(value), value)
        }
    }

    func testFaviconDiscoveryResolvesAndDeduplicatesActualIconLinks() throws {
        let base = try XCTUnwrap(URL(string: "https://example.com/folder/page"))
        let html = """
        <link rel="stylesheet" href="/wrong.css">
        <link rel="not-an-icon" href="/wrong.png">
        <link rel="shortcut icon" sizes="32x32" href="../small.png">
        <LINK REL='APPLE-TOUCH-ICON' SIZES='180x180' HREF='/large.png'>
        <link href="https://example.com/large.png" rel="icon" sizes="180x180">
        <link rel=icon href="//cdn.example.com/favicon.png?a=1&amp;b=2" sizes=64x64>
        """
        let choices = FaviconDiscovery.candidates(html: html, baseURL: base)
        XCTAssertEqual(choices.map(\.absoluteString), [
            "https://example.com/large.png",
            "https://example.com/small.png",
        ])
    }

    func testFaviconDiscoveryDoesNotReturnNonHTTPOrCredentialedCandidates() throws {
        let base = try XCTUnwrap(URL(string: "https://example.com/"))
        let html = """
        <link rel="icon" href="file:///tmp/image.png">
        <link rel="icon" href="data:image/png;base64,AAAA">
        <link rel="icon" href="javascript://example.com/image">
        <link rel="icon" href="https://user:secret@example.com/image.png">
        <link rel="icon" href="/safe.png">
        """
        XCTAssertEqual(FaviconDiscovery.candidates(html: html, baseURL: base).map(\.absoluteString), ["https://example.com/safe.png"])
    }

    func testLegacyImportExtractsLiteralUnicodeNamesFromIndentedHandlers() {
        let source = """
        on run
            set targetName to "Рабочий профиль 👩🏽‍💻"
            return targetName
        end run
        """
        XCTAssertEqual(LegacyShortcutImport.targetName(in: source), "Рабочий профиль 👩🏽‍💻")
    }

    func testLegacyImportDecodesQuotedAndBackslashEscapes() {
        let source = #"set targetName to "Team \"Blue\" \\ Projects""#
        XCTAssertEqual(LegacyShortcutImport.targetName(in: source), #"Team "Blue" \ Projects"#)
    }

    func testLegacyImportDoesNotEvaluateExpressionsOrFindAssignmentsInsideComments() {
        let invalidSources = [
            #"set targetName to (do shell script "echo Work")"#,
            #"set targetName to "Work" & " Personal""#,
            #"set targetName to someVariable"#,
            #"-- set targetName to "Work""#,
            #"display alert "set targetName to \"Work\"""#,
            #"do shell script "echo Work""#,
            #"set targetName to "unterminated"#,
            #"set targetName to "bad\qescape""#,
            #"set targetName to 42"#,
        ]
        for source in invalidSources {
            XCTAssertNil(LegacyShortcutImport.targetName(in: source), source)
        }
    }

    func testLegacyImportRejectsEmptyAndOverlongTargets() {
        XCTAssertNil(LegacyShortcutImport.targetName(in: #"set targetName to """#))
        XCTAssertNil(LegacyShortcutImport.targetName(in: "set targetName to \"\(String(repeating: "界", count: 501))\""))
        let accepted = String(repeating: "界", count: 500)
        XCTAssertEqual(LegacyShortcutImport.targetName(in: "set targetName to \"\(accepted)\""), accepted)
    }

    func testLegacyImportReadsSurroundingCodeAsDataWithoutExecutingIt() throws {
        let marker = try temporaryDirectory().appendingPathComponent("must-not-be-created")
        let source = """
        do shell script "/usr/bin/touch '\(marker.path)'"
        set targetName to "Work"
        do shell script "/usr/bin/touch '\(marker.path)'"
        """
        XCTAssertEqual(LegacyShortcutImport.targetName(in: source), "Work")
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }
}
