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
            try testOptionalShortWindowDisappearsAndReturns()
            try testSparseRateLimitMergePreservesSnapshotMetadata()
            try testFullSnapshotDeadlineAndSingleInFlightGate()
            try testWindowRolloverRefreshesSnapshotMetadata()
            try testBufferedSparseUpdatesReapplyAfterFullSnapshot()
            try testRateLimitDisplaySignatureTracksVisibleValues()
            try testReconnectBackoffIsBounded()
            try testAccountUsageDecodeAndFourteenDayNormalization()
            try testAccountUsageEmptyAndAccessibleBars()
            try testUsageMilestonesAndConnectionHealth()
            try testCompatibilityFreshnessAndSafeFailureReasons()
            try testUnknownAndOptionalProtocolFieldsRemainCompatible()
            try testNotificationTransitionsAndDedupe()
            try testMissingLimitsPruneNotificationHistory()
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

    private static func testOptionalShortWindowDisappearsAndReturns() throws {
        let weeklyOnly = #"{"id":2,"result":{"rateLimits":{"limitId":"codex","planType":"pro","secondary":{"usedPercent":18,"windowDurationMins":10080,"resetsAt":4102444800}}}}"#
        guard let state = AppServerLimitStateReader.decodeRateLimitState(from: weeklyOnly) else {
            throw LimitRingsTestError.failed("expected a weekly-only full snapshot to decode")
        }
        try expect(state.primary == nil, "expected an omitted short window to remain absent")
        try expect(state.secondary?.remainingPercent == 82, "expected the remaining weekly window to stay visible")

        let full = AppServerRateLimitResult(
            rateLimits: AppServerRateLimitSnapshot(
                limitId: "codex", limitName: "Codex", primary: nil,
                secondary: AppServerRateLimitWindow(usedPercent: 18, windowDurationMins: 10080, resetsAt: 4102444800),
                credits: nil, individualLimit: nil, planType: "pro", rateLimitReachedType: nil
            ),
            rateLimitsByLimitId: nil,
            rateLimitResetCredits: nil
        )
        let bufferedReturnedShortWindow = AppServerRateLimitSnapshot(
            limitId: "codex", limitName: nil,
            primary: AppServerRateLimitWindow(usedPercent: 90, windowDurationMins: nil, resetsAt: nil),
            secondary: nil, credits: nil, individualLimit: nil, planType: nil, rateLimitReachedType: nil
        )
        let returnedByBufferedSparse = full.mergingSparse(bufferedReturnedShortWindow)
        try expect(returnedByBufferedSparse.rateLimits.primary?.usedPercent == 90, "expected a buffered live notification to restore a returned short window")

        let fullWithReturnedShortWindow = AppServerRateLimitResult(
            rateLimits: AppServerRateLimitSnapshot(
                limitId: "codex", limitName: "Codex",
                primary: AppServerRateLimitWindow(usedPercent: 12, windowDurationMins: 300, resetsAt: 4102444800),
                secondary: AppServerRateLimitWindow(usedPercent: 18, windowDurationMins: 10080, resetsAt: 4102444800),
                credits: nil, individualLimit: nil, planType: "pro", rateLimitReachedType: nil
            ),
            rateLimitsByLimitId: nil,
            rateLimitResetCredits: nil
        )
        try expect(fullWithReturnedShortWindow.toLimitState(observedAt: Date())?.primary?.remainingPercent == 88, "expected a later full snapshot to restore a returned short window")
    }

    private static func testSparseRateLimitMergePreservesSnapshotMetadata() throws {
        let original = AppServerRateLimitResult(
            rateLimits: AppServerRateLimitSnapshot(
                limitId: "codex",
                limitName: "Codex",
                primary: AppServerRateLimitWindow(usedPercent: 20, windowDurationMins: 300, resetsAt: 1000),
                secondary: AppServerRateLimitWindow(usedPercent: 40, windowDurationMins: 10080, resetsAt: 2000),
                credits: AppServerCreditsSnapshot(hasCredits: true, unlimited: false, balance: "10"),
                individualLimit: nil,
                planType: "pro",
                rateLimitReachedType: nil
            ),
            rateLimitsByLimitId: nil,
            rateLimitResetCredits: AppServerRateLimitResetCreditsSummary(availableCount: 2)
        )
        let merged = original.mergingSparse(AppServerRateLimitSnapshot(
            limitId: nil,
            limitName: nil,
            primary: AppServerRateLimitWindow(usedPercent: 25, windowDurationMins: nil, resetsAt: nil),
            secondary: nil,
            credits: nil,
            individualLimit: nil,
            planType: nil,
            rateLimitReachedType: nil
        ))
        try expect(merged.rateLimits.primary?.usedPercent == 25, "expected sparse primary percentage update")
        try expect(merged.rateLimits.primary?.windowDurationMins == 300, "expected sparse merge to preserve window length")
        try expect(merged.rateLimits.secondary?.usedPercent == 40, "expected sparse merge to preserve secondary window")
        try expect(merged.rateLimits.credits?.balance == "10", "expected sparse merge to preserve nullable account metadata")
        try expect(merged.rateLimitResetCredits?.availableCount == 2, "expected snapshot-only reset credits to remain")
    }

    private static func testFullSnapshotDeadlineAndSingleInFlightGate() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let lastFullSync = now.addingTimeInterval(-90)
        try expect(fullSnapshotReconcileDelay(lastFullSyncAt: nil, now: now, interval: 120, isConnected: true) == nil, "expected reconcile to wait for a successful full snapshot")
        try expect(fullSnapshotReconcileDelay(lastFullSyncAt: lastFullSync, now: now, interval: 120, isConnected: true) == 30, "expected an absolute deadline derived from the last full snapshot")
        try expect(!shouldRunFullSnapshotReconcile(lastFullSyncAt: now.addingTimeInterval(-119), now: now, interval: 120, isConnected: true), "expected reconcile to wait until 120 seconds")
        try expect(shouldRunFullSnapshotReconcile(lastFullSyncAt: now.addingTimeInterval(-120), now: now, interval: 120, isConnected: true), "expected reconcile at the 120-second full-snapshot boundary")
        try expect(!shouldRunFullSnapshotReconcile(lastFullSyncAt: now.addingTimeInterval(-121), now: now, interval: 120, isConnected: false), "expected reconcile to remain disabled while disconnected")

        let sparseObservations = [30.0, 60.0, 90.0, 119.0].map { now.addingTimeInterval($0) }
        for sparseObservedAt in sparseObservations {
            let deadline = fullSnapshotReconcileDelay(
                lastFullSyncAt: now,
                now: sparseObservedAt,
                interval: 120,
                isConnected: true
            )
            try expect(deadline == 120 - sparseObservedAt.timeIntervalSince(now), "expected sparse observations not to move the full-snapshot deadline")
        }
        try expect(
            shouldRunFullSnapshotReconcile(lastFullSyncAt: now, now: now.addingTimeInterval(120), interval: 120, isConnected: true),
            "expected continuous sparse notifications not to postpone the full read"
        )

        var gate = RateLimitRequestGate()
        guard let first = gate.begin() else {
            throw LimitRingsTestError.failed("expected the first full read to start")
        }
        try expect(gate.inFlight, "expected full read gate to report in-flight")
        try expect(gate.begin() == nil, "expected manual and scheduled reads to coalesce")
        try expect(
            coalescedRateLimitRequestOrigin(current: .scheduledFullSync, incoming: .manualFullSync) == .manualFullSync,
            "expected a coalesced manual refresh to remain visible as the full-sync path"
        )
        try expect(
            coalescedRateLimitRequestOrigin(current: .manualFullSync, incoming: .scheduledFullSync) == .manualFullSync,
            "expected a scheduled reconcile not to downgrade a coalesced manual refresh"
        )
        try expect(!gate.complete(token: first + 1), "expected a mismatched completion token to be ignored")
        try expect(gate.complete(token: first), "expected the active full read to complete")
        guard let second = gate.begin() else {
            throw LimitRingsTestError.failed("expected a later full read to start")
        }
        gate.cancel()
        try expect(!gate.inFlight && !gate.isCurrent(second), "expected timeout cancellation to invalidate the active request")
    }

    private static func testWindowRolloverRefreshesSnapshotMetadata() throws {
        let expiredResetAt = 1_000.0
        let refreshedResetAt = 20_000.0
        let prior = AppServerRateLimitResult(
            rateLimits: AppServerRateLimitSnapshot(
                limitId: "codex",
                limitName: "Codex",
                primary: AppServerRateLimitWindow(usedPercent: 99, windowDurationMins: 300, resetsAt: expiredResetAt),
                secondary: nil,
                credits: nil,
                individualLimit: nil,
                planType: "pro",
                rateLimitReachedType: nil
            ),
            rateLimitsByLimitId: nil,
            rateLimitResetCredits: nil
        )
        let sparse = AppServerRateLimitSnapshot(
            limitId: nil,
            limitName: nil,
            primary: AppServerRateLimitWindow(usedPercent: 1, windowDurationMins: nil, resetsAt: nil),
            secondary: nil,
            credits: nil,
            individualLimit: nil,
            planType: nil,
            rateLimitReachedType: nil
        )
        let sparseMerged = prior.mergingSparse(sparse)
        try expect(sparseMerged.rateLimits.primary?.resetsAt == expiredResetAt, "expected sparse rollover notification to preserve unknown reset metadata")

        let full = AppServerRateLimitResult(
            rateLimits: AppServerRateLimitSnapshot(
                limitId: "codex",
                limitName: "Codex",
                primary: AppServerRateLimitWindow(usedPercent: 0, windowDurationMins: 300, resetsAt: refreshedResetAt),
                secondary: nil,
                credits: nil,
                individualLimit: nil,
                planType: "pro",
                rateLimitReachedType: nil
            ),
            rateLimitsByLimitId: nil,
            rateLimitResetCredits: nil
        )
        let fullWithBufferedSparse = full.mergingSparse(sparse)
        try expect(fullWithBufferedSparse.rateLimits.primary?.usedPercent == 1, "expected buffered sparse value to win after the full read")
        try expect(fullWithBufferedSparse.rateLimits.primary?.resetsAt == refreshedResetAt, "expected the full read to replace expired rollover metadata")
        try expect(dataFreshnessState(observedAt: Date(timeIntervalSince1970: 10_000), now: Date(timeIntervalSince1970: 10_120), maxAge: 120) == .current, "expected full metadata to remain current at the deadline")
        try expect(dataFreshnessState(observedAt: Date(timeIntervalSince1970: 10_000), now: Date(timeIntervalSince1970: 10_121), maxAge: 120) == .stale, "expected overdue full metadata to be visibly stale")
    }

    private static func testBufferedSparseUpdatesReapplyAfterFullSnapshot() throws {
        let full = AppServerRateLimitResult(
            rateLimits: AppServerRateLimitSnapshot(
                limitId: "codex",
                limitName: "Codex",
                primary: AppServerRateLimitWindow(usedPercent: 20, windowDurationMins: 300, resetsAt: 1000),
                secondary: AppServerRateLimitWindow(usedPercent: 40, windowDurationMins: 10080, resetsAt: 2000),
                credits: AppServerCreditsSnapshot(hasCredits: true, unlimited: false, balance: "10"),
                individualLimit: nil,
                planType: "pro",
                rateLimitReachedType: nil
            ),
            rateLimitsByLimitId: nil,
            rateLimitResetCredits: AppServerRateLimitResetCreditsSummary(availableCount: 2)
        )
        let buffered = [25.0, 30.0].map { used in
            AppServerRateLimitSnapshot(
                limitId: nil,
                limitName: nil,
                primary: AppServerRateLimitWindow(usedPercent: used, windowDurationMins: nil, resetsAt: nil),
                secondary: nil,
                credits: nil,
                individualLimit: nil,
                planType: nil,
                rateLimitReachedType: used == 30 ? "rate_limit_reached" : nil
            )
        }
        let merged = buffered.reduce(full, { $0.mergingSparse($1) })
        try expect(merged.rateLimits.primary?.usedPercent == 30, "expected the newest buffered sparse value after full sync")
        try expect(merged.rateLimits.primary?.windowDurationMins == 300, "expected full snapshot metadata to survive buffered sparse updates")
        try expect(merged.rateLimits.secondary?.usedPercent == 40, "expected untouched secondary data to survive buffered sparse updates")
        try expect(merged.rateLimits.credits?.balance == "10", "expected credits to survive buffered sparse updates")
        try expect(merged.rateLimitResetCredits?.availableCount == 2, "expected reset credits to survive buffered sparse updates")
        try expect(merged.rateLimits.rateLimitReachedType == "rate_limit_reached", "expected buffered reached reason to reapply")
    }

    private static func testRateLimitDisplaySignatureTracksVisibleValues() throws {
        let base = LimitState(
            planType: "pro",
            primary: LimitBucket(usedPercent: 20, windowMinutes: 300, resetAt: 1000),
            secondary: nil,
            additional: [],
            credits: LimitCredits(hasCredits: true, unlimited: false, balance: "10"),
            individualLimit: SpendControlLimit(limit: "100", used: "20", remainingPercent: 80, resetsAt: 2000),
            reachedType: nil,
            resetCreditsAvailable: 2,
            observedAt: Date(timeIntervalSince1970: 1),
            source: "app-server"
        )
        var laterObservation = base
        laterObservation.observedAt = Date(timeIntervalSince1970: 2)
        try expect(rateLimitDisplaySignature(base) == rateLimitDisplaySignature(laterObservation), "expected observation time and source not to count as a displayed value change")

        var creditChange = base
        creditChange.credits?.unlimited = true
        try expect(rateLimitDisplaySignature(base) != rateLimitDisplaySignature(creditChange), "expected visible credit metadata to change the signature")

        var spendChange = base
        spendChange.individualLimit?.used = "25"
        try expect(rateLimitDisplaySignature(base) != rateLimitDisplaySignature(spendChange), "expected visible spend-control values to change the signature")

        var resetChange = base
        resetChange.resetCreditsAvailable = 1
        try expect(rateLimitDisplaySignature(base) != rateLimitDisplaySignature(resetChange), "expected visible reset-credit count to change the signature")
    }

    private static func testReconnectBackoffIsBounded() throws {
        try expect(appServerReconnectDelay(attempt: 0) == 1, "expected initial reconnect delay")
        try expect(appServerReconnectDelay(attempt: 1) == 1, "expected first reconnect delay")
        try expect(appServerReconnectDelay(attempt: 2) == 2, "expected exponential reconnect delay")
        try expect(appServerReconnectDelay(attempt: 6) == 30, "expected reconnect delay cap")
        try expect(appServerReconnectDelay(attempt: 20) == 30, "expected large reconnect attempts to remain capped")
    }

    private static func testAccountUsageDecodeAndFourteenDayNormalization() throws {
        let buckets = (1...16).map { day in
            String(format: #"{"startDate":"2026-06-%02d","tokens":%d}"#, day, day * 100)
        }.joined(separator: ",")
        let line = #"{"id":2,"result":{"summary":{"currentStreakDays":4,"lifetimeTokens":123456,"longestRunningTurnSec":90,"longestStreakDays":8,"peakDailyTokens":1600},"dailyUsageBuckets":["# + buckets + #"]}}"#
        guard let snapshot = AppServerAccountUsageReader.decodeAccountUsage(from: line) else {
            throw LimitRingsTestError.failed("expected account usage response to decode")
        }
        try expect(snapshot.buckets.count == 14, "expected only the latest fourteen daily buckets")
        try expect(snapshot.buckets.first?.startDate == "2026-06-03", "expected chronological fourteen-day window")
        try expect(snapshot.buckets.last?.tokens == 1600, "expected the newest bucket value")
        try expect(snapshot.summary?.currentStreakDays == 4, "expected current streak summary")
        try expect(snapshot.summary?.longestStreakDays == 8, "expected longest streak summary")
        try expect(snapshot.summary?.longestRunningTurnSec == 90, "expected longest running turn summary")
        try expect(snapshot.summary?.peakDailyTokens == 1600, "expected peak daily summary")
        try expect(snapshot.summary?.lifetimeTokens == 123456, "expected lifetime token summary")

        let normalized = normalizedDailyUsageBuckets([
            DailyUsageBucket(startDate: "invalid", tokens: 1),
            DailyUsageBucket(startDate: "2026-07-01", tokens: -1),
            DailyUsageBucket(startDate: "2026-07-02", tokens: 10),
            DailyUsageBucket(startDate: "2026-07-02", tokens: 20)
        ])
        try expect(normalized == [DailyUsageBucket(startDate: "2026-07-02", tokens: 20)], "expected invalid, negative, and duplicate buckets to normalize safely")
    }

    private static func testAccountUsageEmptyAndAccessibleBars() throws {
        let line = #"{"id":2,"result":{"dailyUsageBuckets":null}}"#
        guard let snapshot = AppServerAccountUsageReader.decodeAccountUsage(from: line) else {
            throw LimitRingsTestError.failed("expected nullable daily buckets to decode as an empty state")
        }
        try expect(snapshot.buckets.isEmpty, "expected nullable buckets to produce an empty state")
        try expect(dailyUsageBar(tokens: 0, maximum: 100) == "··········", "expected zero usage to have a textual empty bar")
        try expect(dailyUsageBar(tokens: 1, maximum: 100).hasPrefix("▮"), "expected positive usage to remain distinguishable without color")
        try expect(dailyUsageBar(tokens: 100, maximum: 100) == "▮▮▮▮▮▮▮▮▮▮", "expected maximum usage to fill the textual bar")
    }

    private static func testUsageMilestonesAndConnectionHealth() throws {
        let labels = UsageDurationUnitLabels(day: "d", hour: "h", minute: "m", second: "s")
        try expect(formattedUsageDuration(seconds: -1, labels: labels) == nil, "expected invalid negative duration to be omitted")
        try expect(formattedUsageDuration(seconds: 0, labels: labels) == "0s", "expected zero-second duration")
        try expect(formattedUsageDuration(seconds: 90, labels: labels) == "1m 30s", "expected minute-second duration")
        try expect(formattedUsageDuration(seconds: 3_661, labels: labels) == "1h 1m", "expected hour-minute duration")
        try expect(formattedUsageDuration(seconds: 90_061, labels: labels) == "1d 1h", "expected day-hour duration")

        try expect(connectionHealthState(isConnected: true, limitSource: "app-server") == .live, "expected connected app-server state")
        try expect(connectionHealthState(isConnected: false, limitSource: "none") == .reconnecting, "expected disconnected state without fallback data")
        try expect(connectionHealthState(isConnected: false, limitSource: "cached") == .pollFallback, "expected cached poll fallback state")
        try expect(connectionHealthState(isConnected: false, limitSource: "local") == .pollFallback, "expected local poll fallback state")
        try expect(shouldApplyPolledLimitState(isLiveConnected: false), "expected fallback polling while disconnected")
        try expect(!shouldApplyPolledLimitState(isLiveConnected: true), "expected an in-flight fallback result not to overwrite restored live state")
    }

    private static func testCompatibilityFreshnessAndSafeFailureReasons() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        try expect(dataFreshnessState(observedAt: nil, now: now, maxAge: 100) == .waiting, "expected missing observation to wait")
        try expect(dataFreshnessState(observedAt: now.addingTimeInterval(-100), now: now, maxAge: 100) == .current, "expected freshness boundary to remain current")
        try expect(dataFreshnessState(observedAt: now.addingTimeInterval(-101), now: now, maxAge: 100) == .stale, "expected old observation to become stale")
        try expect(dataFreshnessState(observedAt: now.addingTimeInterval(1), now: now, maxAge: 100) == .stale, "expected future observation to fail closed")

        try expect(connectionFailureReason(for: nil) == nil, "expected no failure reason while connected")
        try expect(connectionFailureReason(for: "cli_not_found") == .cliUnavailable, "expected safe CLI classification")
        try expect(connectionFailureReason(for: "invalid_rate_limit_response") == .incompatibleResponse, "expected safe protocol classification")
        try expect(connectionFailureReason(for: "account_usage_timeout") == .timedOut, "expected safe timeout classification")
        try expect(connectionFailureReason(for: "app_server_terminated") == .disconnected, "expected safe disconnect classification")
        try expect(connectionFailureReason(for: "request_write_failed") == .communicationFailed, "expected safe communication classification")
        try expect(connectionFailureReason(for: "future_error") == .unknown, "expected unknown errors not to leak raw details")

        try expect(normalizedCodexCLIVersion("codex-cli 0.144.0-alpha.4\n") == "codex-cli 0.144.0-alpha.4", "expected safe CLI version")
        try expect(normalizedCodexCLIVersion("codex-cli 1.0; cat /secret\n") == nil, "expected shell-like version text to be rejected")
        try expect(normalizedCodexCLIVersion(String(repeating: "x", count: 121)) == nil, "expected oversized version text to be rejected")
    }

    private static func testUnknownAndOptionalProtocolFieldsRemainCompatible() throws {
        let limits = #"{"id":2,"result":{"futureTopLevel":{"enabled":true},"rateLimits":{"limitId":"codex","primary":{"usedPercent":42,"futureWindowField":"ignored"},"rateLimitReachedType":"future_limit_reason","futureSnapshotField":17}}}"#
        guard let state = AppServerLimitStateReader.decodeRateLimitState(from: limits) else {
            throw LimitRingsTestError.failed("expected unknown rate-limit fields to be ignored")
        }
        try expect(state.primary?.remainingPercent == 58, "expected known rate-limit values with optional fields absent")
        try expect(state.reachedType == "future_limit_reason", "expected unknown reached reason to remain read-only text")

        let usage = #"{"id":2,"result":{"summary":{"currentStreakDays":2,"futureSummaryField":99},"dailyUsageBuckets":null,"futureUsageField":"ignored"}}"#
        guard let snapshot = AppServerAccountUsageReader.decodeAccountUsage(from: usage) else {
            throw LimitRingsTestError.failed("expected unknown usage fields to be ignored")
        }
        try expect(snapshot.buckets.isEmpty, "expected optional usage buckets to remain empty")
        try expect(snapshot.summary?.currentStreakDays == 2, "expected known usage summary with unknown fields")
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

    private static func testMissingLimitsPruneNotificationHistory() throws {
        let weeklyOnly = LimitState(
            planType: "pro",
            primary: nil,
            secondary: LimitBucket(usedPercent: 18, windowMinutes: 10080, resetAt: nil),
            additional: [],
            observedAt: Date(),
            source: "app-server"
        )
        let pruned = pruningNotificationBands(
            ["codex.primary": LimitNotificationBand.critical.rawValue, "codex.secondary": LimitNotificationBand.healthy.rawValue],
            activeIDs: activeLimitNotificationIDs(in: weeklyOnly)
        )
        try expect(pruned["codex.primary"] == nil, "expected an absent short window to drop stale notification history")
        try expect(pruned["codex.secondary"] == LimitNotificationBand.healthy.rawValue, "expected active weekly notification history to remain")
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
