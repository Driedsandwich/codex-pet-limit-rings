import AppKit
import Foundation
import SQLite3

enum LimitRingsTestError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): return message
        }
    }
}

@main
struct LimitRingsTests {
    static func main() {
        do {
            try testCodexCLIPathsCoverCurrentChatGPTAppAndPath()
            try testAppServerRateLimitDecode()
            try testNotificationTransitionsAndDedupe()
            try testNotificationsAreOffByDefault()
            try testAccessibilityPresentationIsExplicit()
            try testAccessibilityRendererProducesImage()
            try testRecentAppServerSnapshotSurvivesTransientFailure()
            try testExpiredAppServerSnapshotIsDiscarded()
            try testNewestLogsDatabaseWins()
            try testSQLiteRateLimitFallback()
            print("limit-rings tests passed")
        } catch {
            fputs("limit-rings tests failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func testCodexCLIPathsCoverCurrentChatGPTAppAndPath() throws {
        let paths = defaultCodexCLIPaths(
            home: URL(fileURLWithPath: "/Users/tester"),
            environment: ["PATH": "/custom/bin:/usr/bin"]
        )
        try expect(
            paths.contains("/Applications/ChatGPT.app/Contents/Resources/codex"),
            "expected the current ChatGPT.app bundled Codex CLI path"
        )
        try expect(paths.contains("/custom/bin/codex"), "expected PATH-based Codex CLI discovery")
        try expect(paths.contains("/opt/homebrew/bin/codex"), "expected Homebrew Codex CLI discovery")
    }

    private static func testAppServerRateLimitDecode() throws {
        let line = #"{"id":2,"result":{"rateLimits":{"limitId":"codex","limitName":"Codex","planType":"pro","primary":{"usedPercent":12,"windowDurationMins":300,"resetsAt":4102444800},"secondary":{"usedPercent":34,"windowDurationMins":10080,"resetsAt":4102444800},"credits":{"hasCredits":true,"unlimited":false,"balance":"12.50"},"individualLimit":{"limit":"100","used":"25","remainingPercent":75,"resetsAt":4102444800}},"rateLimitsByLimitId":{"codex":{"limitId":"codex","limitName":"Codex","planType":"pro","primary":{"usedPercent":12,"windowDurationMins":300,"resetsAt":4102444800},"secondary":{"usedPercent":34,"windowDurationMins":10080,"resetsAt":4102444800},"credits":{"hasCredits":true,"unlimited":false,"balance":"12.50"},"individualLimit":{"limit":"100","used":"25","remainingPercent":75,"resetsAt":4102444800}},"review":{"limitId":"review","limitName":"Code Review","primary":{"usedPercent":25,"windowDurationMins":10080,"resetsAt":4102444800},"rateLimitReachedType":"workspace_member_usage_limit_reached"}},"rateLimitResetCredits":{"availableCount":2,"credits":null}}}"#
        guard let state = AppServerLimitStateReader.decodeRateLimitState(from: line) else {
            throw LimitRingsTestError.failed("expected app-server response to decode")
        }
        try expect(state.primary?.remainingPercent == 88, "expected primary remaining percent")
        try expect(state.secondary?.remainingPercent == 66, "expected secondary remaining percent")
        try expect(state.additional.first?.name == "Code Review", "expected additional limit bucket")
        try expect(state.additional.first?.primary?.remainingPercent == 75, "expected additional limit percentage")
        try expect(state.additional.first?.reachedType == "workspace_member_usage_limit_reached", "expected reached reason")
        try expect(state.credits?.balance == "12.50", "expected credit balance")
        try expect(state.individualLimit?.remainingPercent == 75, "expected monthly spend-control limit")
        try expect(state.resetCreditsAvailable == 2, "expected reset-credit count")
        try expect(state.source == "app-server", "expected app-server source label")
    }

    private static func testNotificationTransitionsAndDedupe() throws {
        let seeded = limitNotificationTransition(previousBand: nil, remainingPercent: 20, limitName: "Short", isFresh: true)
        try expect(seeded.band == .low, "expected initial low band to seed")
        try expect(seeded.event == nil, "expected no notification on initial seed")

        let low = limitNotificationTransition(previousBand: .healthy, remainingPercent: 25, limitName: "Short", isFresh: true)
        try expect(low.event?.kind == .low, "expected 25 percent low notification")
        let duplicate = limitNotificationTransition(previousBand: .low, remainingPercent: 20, limitName: "Short", isFresh: true)
        try expect(duplicate.event == nil, "expected duplicate low notification to be suppressed")
        let critical = limitNotificationTransition(previousBand: .low, remainingPercent: 10, limitName: "Short", isFresh: true)
        try expect(critical.event?.kind == .critical, "expected 10 percent critical notification")
        let recovered = limitNotificationTransition(previousBand: .critical, remainingPercent: 40, limitName: "Short", isFresh: true)
        try expect(recovered.event?.kind == .recovered, "expected recovery notification")
        let cached = limitNotificationTransition(previousBand: .healthy, remainingPercent: 10, limitName: "Short", isFresh: false)
        try expect(cached.event == nil, "expected cached data not to notify")
        try expect(cached.band == .healthy, "expected cached data not to change the notification band")
    }

    private static func testNotificationsAreOffByDefault() throws {
        try expect(!notificationsEnabledFromStoredValue(nil), "expected notifications to default off")
        try expect(notificationsEnabledFromStoredValue(true), "expected explicit notification opt-in")
        try expect(!notificationsEnabledFromStoredValue(false), "expected explicit notification opt-out")
    }

    private static func testAccessibilityPresentationIsExplicit() throws {
        let presentation = AccessibilityPresentation(reduceMotion: true, increaseContrast: true, differentiateWithoutColor: true)
        try expect(presentation.reduceMotion, "expected reduced motion")
        try expect(presentation.increaseContrast, "expected increased contrast")
        try expect(presentation.differentiateWithoutColor, "expected non-color differentiation")
    }

    private static func testAccessibilityRendererProducesImage() throws {
        let state = LimitState(
            planType: "pro",
            primary: LimitBucket(usedPercent: 76, windowMinutes: 300, resetAt: nil),
            secondary: LimitBucket(usedPercent: 92, windowMinutes: 10080, resetAt: nil),
            additional: [
                AdditionalLimit(
                    id: "review",
                    name: "Code Review",
                    primary: LimitBucket(usedPercent: 50, windowMinutes: 10080, resetAt: nil),
                    secondary: nil,
                    credits: nil,
                    individualLimit: nil,
                    reachedType: nil
                )
            ],
            observedAt: Date(),
            source: "app-server"
        )
        let image = NSImage(size: NSSize(width: 200, height: 200))
        image.lockFocus()
        LimitRingRenderer(
            state: state,
            phase: 0.75,
            showsReadout: true,
            accessibility: AccessibilityPresentation(reduceMotion: true, increaseContrast: true, differentiateWithoutColor: true)
        ).draw(in: CGRect(x: 0, y: 0, width: 200, height: 200))
        image.unlockFocus()
        try expect(image.tiffRepresentation?.isEmpty == false, "expected accessibility renderer output")
    }

    private static func testRecentAppServerSnapshotSurvivesTransientFailure() throws {
        let root = try temporaryDirectory(named: "cache")
        defer { try? FileManager.default.removeItem(at: root) }
        var nextState: LimitState? = LimitState(
            planType: "pro",
            primary: LimitBucket(usedPercent: 10, windowMinutes: 300, resetAt: Date().addingTimeInterval(3600).timeIntervalSince1970),
            secondary: nil,
            additional: [],
            observedAt: Date(),
            source: "app-server"
        )
        let reader = LimitStateReader(
            logsPath: root.appendingPathComponent("missing.sqlite"),
            appServerStateProvider: { nextState }
        )
        _ = reader.readLatest()
        nextState = nil
        let cached = reader.readLatest()
        try expect(cached.primary?.remainingPercent == 90, "expected cached primary value")
        try expect(cached.source == "cached", "expected cached source label")
    }

    private static func testExpiredAppServerSnapshotIsDiscarded() throws {
        let root = try temporaryDirectory(named: "expired")
        defer { try? FileManager.default.removeItem(at: root) }
        var nextState: LimitState? = LimitState(
            planType: "pro",
            primary: LimitBucket(usedPercent: 10, windowMinutes: 300, resetAt: Date().addingTimeInterval(3600).timeIntervalSince1970),
            secondary: nil,
            additional: [],
            observedAt: Date().addingTimeInterval(-(31 * 60)),
            source: "app-server"
        )
        let reader = LimitStateReader(
            logsPath: root.appendingPathComponent("missing.sqlite"),
            appServerStateProvider: { nextState }
        )
        _ = reader.readLatest()
        nextState = nil
        let expired = reader.readLatest()
        try expect(expired.primary == nil, "expected old cached value to be discarded")
        try expect(expired.source == "none", "expected empty source after cache expiry")
    }

    private static func testNewestLogsDatabaseWins() throws {
        let root = try temporaryDirectory(named: "logs")
        defer { try? FileManager.default.removeItem(at: root) }
        let sqliteDirectory = root.appendingPathComponent("sqlite", isDirectory: true)
        try FileManager.default.createDirectory(at: sqliteDirectory, withIntermediateDirectories: true)
        let legacy = root.appendingPathComponent("logs_2.sqlite")
        let moved = sqliteDirectory.appendingPathComponent("logs_2.sqlite")
        try Data().write(to: legacy)
        try Data().write(to: moved)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: legacy.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: moved.path)
        try expect(defaultLogsPath(codexHome: root).path == moved.path, "expected newest logs_2 database")
    }

    private static func testSQLiteRateLimitFallback() throws {
        let root = try temporaryDirectory(named: "sqlite-fallback")
        defer { try? FileManager.default.removeItem(at: root) }
        let logsPath = root.appendingPathComponent("logs_2.sqlite")
        var database: OpaquePointer?
        guard sqlite3_open(logsPath.path, &database) == SQLITE_OK, let database else {
            throw LimitRingsTestError.failed("could not create fallback database")
        }
        defer { sqlite3_close(database) }

        let now = Int64(Date().timeIntervalSince1970)
        let resetAt = now + 3600
        let body = #"{"type":"codex.rate_limits","plan_type":"pro","rate_limits":{"primary":{"used_percent":20,"window_minutes":300,"reset_at":RESET_AT},"secondary":{"used_percent":40,"window_minutes":10080,"reset_at":RESET_AT}}}"#
            .replacingOccurrences(of: "RESET_AT", with: String(resetAt))
        let escapedBody = body.replacingOccurrences(of: "'", with: "''")
        let sql = """
        CREATE TABLE logs (
            id INTEGER PRIMARY KEY,
            ts INTEGER NOT NULL,
            ts_nanos INTEGER NOT NULL,
            feedback_log_body TEXT NOT NULL
        );
        INSERT INTO logs (ts, ts_nanos, feedback_log_body)
        VALUES (\(now), 0, '\(escapedBody)');
        """
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw LimitRingsTestError.failed("could not seed fallback database")
        }

        let state = LimitStateReader(
            logsPath: logsPath,
            appServerStateProvider: { nil }
        ).readLatest()
        try expect(state.primary?.remainingPercent == 80, "expected SQLite primary fallback")
        try expect(state.secondary?.remainingPercent == 60, "expected SQLite secondary fallback")
        try expect(state.source == "local", "expected Local source label")
    }

    private static func temporaryDirectory(named name: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codex-pet-limit-rings-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw LimitRingsTestError.failed(message) }
    }
}
