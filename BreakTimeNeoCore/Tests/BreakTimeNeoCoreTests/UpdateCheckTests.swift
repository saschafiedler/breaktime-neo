import Foundation
import Testing
@testable import BreakTimeNeoCore

struct AppVersionTests {
    private func version(_ text: String) -> AppVersion {
        AppVersion(text)!
    }

    @Test(arguments: [
        ("1.0.1", [1, 0, 1]),
        ("v1.1.0", [1, 1, 0]),
        ("2", [2]),
        ("1.10", [1, 10]),
    ])
    func reads(text: String, parts: [Int]) {
        #expect(AppVersion(text)?.parts == parts)
    }

    @Test(arguments: ["", "v", "–", "1..2", "1.2.", "1.2.0-beta.1", "1.+2", "1.-2", "x1.0", " 1.0", "١.٢"])
    func rejects(text: String) {
        #expect(AppVersion(text) == nil)
    }

    @Test func comparesNumbersNotText() {
        #expect(version("1.10.0") > version("1.9.0"))
        #expect(version("2.0.0") > version("1.99.99"))
        #expect(version("1.0.1") < version("1.1"))
    }

    @Test func missingPartsCountAsZero() {
        #expect(version("1.1") == version("1.1.0"))
        #expect(!(version("1.1") < version("1.1.0")))
        #expect(!(version("1.1.0") < version("1.1")))
    }

    @Test func printsWithoutTagPrefix() {
        #expect(version("v1.1.0").description == "1.1.0")
    }
}

struct UpdateCheckTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func dueWithoutEarlierCheck() {
        #expect(UpdateCheck.isDue(lastCheck: nil, now: start))
    }

    @Test func dueOnceADay() {
        #expect(!UpdateCheck.isDue(lastCheck: start, now: start + 23 * 3600))
        #expect(UpdateCheck.isDue(lastCheck: start, now: start + 24 * 3600))
    }

    @Test func dueAfterClockWasSetBack() {
        #expect(UpdateCheck.isDue(lastCheck: start, now: start - 60))
    }

    @Test(arguments: [
        ("v1.1.0", "1.0.1", "1.1.0"),
        ("v1.0.1", "1.0.1", nil),
        ("v1.0.0", "1.0.1", nil),
        ("v1.1.0-beta.1", "1.0.1", nil),
        // AppInfo.version when the bundle has no version.
        ("v1.1.0", "–", nil),
    ] as [(String, String, String?)])
    func newerVersion(tag: String, current: String, expected: String?) {
        #expect(UpdateCheck.newerVersion(tag: tag, than: current)?.description == expected)
    }

    @Test func noTagNoVersion() {
        #expect(UpdateCheck.newerVersion(tag: nil, than: "1.0.1") == nil)
    }

    @Test func readsTagFromGitHubAnswer() {
        let json = #"""
        {
          "html_url": "https://github.com/saschafiedler/breaktime-neo/releases/tag/v1.0.1",
          "tag_name": "v1.0.1",
          "name": "BreakTime Neo 1.0.1",
          "draft": false,
          "prerelease": false,
          "assets": []
        }
        """#
        #expect(UpdateCheck.tag(fromLatestRelease: Data(json.utf8)) == "v1.0.1")
    }

    @Test(arguments: [#"{"message": "Not Found", "status": "404"}"#, "<html></html>", ""])
    func ignoresOtherAnswers(body: String) {
        #expect(UpdateCheck.tag(fromLatestRelease: Data(body.utf8)) == nil)
    }
}
