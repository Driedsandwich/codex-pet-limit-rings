import AppKit
import CoreGraphics
import Darwin
import Foundation
import SQLite3
import UserNotifications

struct LimitBucket {
    var usedPercent: Double
    var windowMinutes: Double?
    var resetAt: TimeInterval?

    var remainingPercent: Double {
        min(max(100.0 - usedPercent, 0.0), 100.0)
    }
}

struct LimitCredits {
    var hasCredits: Bool
    var unlimited: Bool
    var balance: String?
}

struct SpendControlLimit {
    var limit: String
    var used: String
    var remainingPercent: Double
    var resetsAt: TimeInterval
}

struct AdditionalLimit {
    var id: String
    var name: String
    var primary: LimitBucket?
    var secondary: LimitBucket?
    var credits: LimitCredits?
    var individualLimit: SpendControlLimit?
    var reachedType: String?

    var representativeBucket: LimitBucket? {
        primary ?? secondary
    }
}

struct LimitState {
    var planType: String?
    var primary: LimitBucket?
    var secondary: LimitBucket?
    var additional: [AdditionalLimit]
    var credits: LimitCredits? = nil
    var individualLimit: SpendControlLimit? = nil
    var reachedType: String? = nil
    var resetCreditsAvailable: Int64? = nil
    var observedAt: Date
    var source: String

    static let empty = LimitState(planType: nil, primary: nil, secondary: nil, additional: [], observedAt: Date(), source: "none")
}

func normalizedMainLimitBuckets(
    primary: LimitBucket?,
    secondary: LimitBucket?
) -> (shortWindow: LimitBucket?, weeklyWindow: LimitBucket?) {
    switch (primary, secondary) {
    case let (primary?, secondary?):
        if let primaryMinutes = primary.windowMinutes,
           let secondaryMinutes = secondary.windowMinutes,
           primaryMinutes > secondaryMinutes {
            return (secondary, primary)
        }
        return (primary, secondary)
    case let (bucket?, nil):
        if let minutes = bucket.windowMinutes, minutes >= 24 * 60 {
            return (nil, bucket)
        }
        return (bucket, nil)
    case let (nil, bucket?):
        if let minutes = bucket.windowMinutes, minutes < 24 * 60 {
            return (bucket, nil)
        }
        return (nil, bucket)
    case (nil, nil):
        return (nil, nil)
    }
}

private let limitStatePollInterval: TimeInterval = 20.0
private let liveRateLimitReconcileInterval: TimeInterval = 120.0
private let fullSnapshotWatchdogTickInterval: TimeInterval = 1.0
private let fullSnapshotFreshnessMaxAge: TimeInterval = liveRateLimitReconcileInterval
private let dailyUsageRefreshInterval: TimeInterval = 15 * 60
private let dailyUsageDisplayCount = 14
private let appServerReconnectMaximumDelay: TimeInterval = 30
private let petFrameFallbackPollInterval: TimeInterval = 2.0
private let petFrameStateDebounceInterval: TimeInterval = 0.035
private let petFrameApplicationLaunchGraceInterval: TimeInterval = 0.35
private let dragFollowInterval: TimeInterval = 1.0 / 60.0
let dragLiveMismatchTolerance: CGFloat = 96.0
private let ringsVisibleDefaultsKey = "CodexPetLimitRings.ringsVisible"
private let notificationsEnabledDefaultsKey = "CodexPetLimitRings.notificationsEnabled"
private let notificationBandsDefaultsKey = "CodexPetLimitRings.notificationBands"
private let appServerLimitStateTimeout: TimeInterval = 5.0

func petDragLiveFrameIsClose(
    _ liveFrame: CGRect,
    to predictedFrame: CGRect,
    minimumTolerance: CGFloat = dragLiveMismatchTolerance
) -> Bool {
    let dx = liveFrame.midX - predictedFrame.midX
    let dy = liveFrame.midY - predictedFrame.midY
    let tolerance = max(minimumTolerance, max(predictedFrame.width, predictedFrame.height) * 0.85)
    return (dx * dx + dy * dy) <= tolerance * tolerance
}

func codexApplicationCanPresentPet(
    bundleIdentifier: String?,
    ownerName: String?,
    isHidden: Bool,
    isTerminated: Bool
) -> Bool {
    guard !isHidden, !isTerminated else { return false }
    return bundleIdentifier == "com.openai.codex" || ownerName == "Codex"
}

func shouldRefreshPetFrameForApplication(bundleIdentifier: String?) -> Bool {
    bundleIdentifier == "com.openai.codex"
}
private let codexCLIVersionTimeout: TimeInterval = 2.0
private let limitStateFallbackMaxAge: TimeInterval = 30 * 60
private let rateLimitFreshnessMaxAge: TimeInterval = 30 * 60
private let usageFreshnessMaxAge: TimeInterval = 30 * 60

private func localized(_ key: String, fallback: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .main, value: fallback, comment: "")
}

func notificationsEnabledFromStoredValue(_ value: Any?) -> Bool {
    (value as? Bool) ?? false
}

enum RateLimitUpdateOrigin: String, Equatable {
    case initialFullSync
    case liveNotification
    case scheduledFullSync
    case manualFullSync
    case fallback
}

enum RateLimitRefreshPath: String, Equatable {
    case connectedFullRead
    case freshConnection
}

func manualRateLimitRefreshPath(
    isProcessRunning: Bool,
    isReady: Bool,
    isSnapshotStale: Bool
) -> RateLimitRefreshPath {
    if !isProcessRunning || !isReady || isSnapshotStale {
        return .freshConnection
    }
    return .connectedFullRead
}

func coalescedRateLimitRequestOrigin(
    current: RateLimitUpdateOrigin,
    incoming: RateLimitUpdateOrigin
) -> RateLimitUpdateOrigin {
    if current == .manualFullSync || incoming == .manualFullSync {
        return .manualFullSync
    }
    return current
}

struct RateLimitRequestGate {
    private(set) var inFlight = false
    private(set) var token = 0

    mutating func begin() -> Int? {
        guard !inFlight else { return nil }
        token += 1
        inFlight = true
        return token
    }

    mutating func complete(token: Int) -> Bool {
        guard inFlight, self.token == token else { return false }
        inFlight = false
        return true
    }

    func isCurrent(_ token: Int) -> Bool {
        inFlight && self.token == token
    }

    mutating func cancel() {
        inFlight = false
        token += 1
    }
}

enum FullSnapshotWatchdogAction: Equatable {
    case none
    case requestFullSnapshot
    case recreateConnection
}

func fullSnapshotWatchdogAction(
    lastFullSyncUptime: TimeInterval?,
    overdueRequestUptime: TimeInterval?,
    nowUptime: TimeInterval,
    interval: TimeInterval = liveRateLimitReconcileInterval,
    requestTimeout: TimeInterval = appServerLimitStateTimeout,
    isConnected: Bool
) -> FullSnapshotWatchdogAction {
    guard shouldRunFullSnapshotWatchdog(
        lastFullSyncUptime: lastFullSyncUptime,
        nowUptime: nowUptime,
        interval: interval,
        isConnected: isConnected
    ) else { return .none }
    guard let overdueRequestUptime else { return .requestFullSnapshot }
    return nowUptime - overdueRequestUptime >= requestTimeout ? .recreateConnection : .none
}

func reconnectCallbackIsCurrent(
    scheduleToken: Int,
    currentScheduleToken: Int,
    generation: Int,
    currentGeneration: Int,
    stopped: Bool
) -> Bool {
    !stopped && scheduleToken == currentScheduleToken && generation == currentGeneration
}

func fullSnapshotWatchdogDelay(
    lastFullSyncUptime: TimeInterval?,
    nowUptime: TimeInterval,
    interval: TimeInterval = liveRateLimitReconcileInterval,
    isConnected: Bool
) -> TimeInterval? {
    guard isConnected, let lastFullSyncUptime else { return nil }
    return max(0, interval - (nowUptime - lastFullSyncUptime))
}

func shouldRunFullSnapshotWatchdog(
    lastFullSyncUptime: TimeInterval?,
    nowUptime: TimeInterval,
    interval: TimeInterval = liveRateLimitReconcileInterval,
    isConnected: Bool
) -> Bool {
    guard let delay = fullSnapshotWatchdogDelay(
        lastFullSyncUptime: lastFullSyncUptime,
        nowUptime: nowUptime,
        interval: interval,
        isConnected: isConnected
    ) else { return false }
    return delay == 0
}

func fullSnapshotWatchdogFreshness(
    lastFullSyncUptime: TimeInterval?,
    nowUptime: TimeInterval,
    maxAge: TimeInterval = fullSnapshotFreshnessMaxAge
) -> DataFreshnessState {
    guard let lastFullSyncUptime else { return .waiting }
    let age = nowUptime - lastFullSyncUptime
    return age >= 0 && age <= maxAge ? .current : .stale
}

func ringPresentationIsStale(source: String, freshness: DataFreshnessState) -> Bool {
    source == "app-server" && freshness != .current
}

func ringReadoutDetail(_ resetText: String?, isStale: Bool, staleLabel: String) -> String? {
    guard isStale else { return resetText }
    guard let resetText, !resetText.isEmpty else { return staleLabel }
    return "\(staleLabel) · \(resetText)"
}

func continuousUptime() -> TimeInterval {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    return Double(mach_continuous_time()) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
}

func rateLimitDisplaySignature(_ state: LimitState) -> String {
    func bucket(_ value: LimitBucket?) -> String {
        guard let value else { return "-" }
        return "\(value.usedPercent)|\(value.windowMinutes ?? -1)|\(value.resetAt ?? -1)"
    }
    func credits(_ value: LimitCredits?) -> String {
        guard let value else { return "-" }
        return "\(value.hasCredits)|\(value.unlimited)|\(value.balance ?? "-")"
    }
    func spend(_ value: SpendControlLimit?) -> String {
        guard let value else { return "-" }
        return "\(value.limit)|\(value.used)|\(value.remainingPercent)|\(value.resetsAt)"
    }
    let additional = state.additional.map {
        "\($0.id)|\($0.name)|\(bucket($0.primary))|\(bucket($0.secondary))|\(credits($0.credits))|\(spend($0.individualLimit))|\($0.reachedType ?? "-")"
    }.joined(separator: ";")
    return [
        state.planType ?? "-", bucket(state.primary), bucket(state.secondary), additional,
        credits(state.credits), spend(state.individualLimit),
        state.reachedType ?? "-", state.resetCreditsAvailable?.description ?? "-"
    ].joined(separator: "#")
}

enum LimitNotificationBand: Int, Equatable {
    case healthy = 0
    case low = 1
    case critical = 2

    static func from(remainingPercent: Double) -> LimitNotificationBand {
        if remainingPercent <= 10 { return .critical }
        if remainingPercent <= 25 { return .low }
        return .healthy
    }
}

enum LimitNotificationKind: Equatable {
    case low
    case critical
    case recovered
}

struct LimitNotificationEvent {
    var kind: LimitNotificationKind
    var limitName: String
    var remainingPercent: Double
}

func limitNotificationTransition(
    previousBand: LimitNotificationBand?,
    remainingPercent: Double,
    limitName: String,
    isFresh: Bool
) -> (band: LimitNotificationBand, event: LimitNotificationEvent?) {
    let currentBand = LimitNotificationBand.from(remainingPercent: remainingPercent)
    guard isFresh else {
        return (previousBand ?? currentBand, nil)
    }
    guard let previousBand, previousBand != currentBand else {
        return (currentBand, nil)
    }

    let kind: LimitNotificationKind?
    switch (previousBand, currentBand) {
    case (_, .critical): kind = .critical
    case (.healthy, .low): kind = .low
    case (.low, .healthy), (.critical, .healthy): kind = .recovered
    default: kind = nil
    }
    return (currentBand, kind.map { LimitNotificationEvent(kind: $0, limitName: limitName, remainingPercent: remainingPercent) })
}

func activeLimitNotificationIDs(in state: LimitState) -> Set<String> {
    var ids = Set<String>()
    if state.primary != nil { ids.insert("codex.primary") }
    if state.secondary != nil { ids.insert("codex.secondary") }
    for limit in state.additional {
        if limit.primary != nil { ids.insert("\(limit.id).primary") }
        if limit.secondary != nil { ids.insert("\(limit.id).secondary") }
    }
    return ids
}

func pruningNotificationBands(
    _ bands: [String: Int],
    activeIDs: Set<String>
) -> [String: Int] {
    bands.filter { activeIDs.contains($0.key) }
}

private struct EventPayload: Decodable {
    var type: String
    var plan_type: String?
    var rate_limits: RatePayload?
    var additional_rate_limits: [String: RatePayload]?
}

private struct RatePayload: Decodable {
    var primary: BucketPayload?
    var secondary: BucketPayload?
    var primary_window: BucketPayload?
    var secondary_window: BucketPayload?
}

private struct AppServerInitializeRequest: Encodable {
    var id = 1
    var method = "initialize"
    var params = AppServerInitializeParams()
}

private struct AppServerInitializeParams: Encodable {
    var clientInfo = AppServerClientInfo()
}

private struct AppServerClientInfo: Encodable {
    var name = "codex-pet-limit-rings"
    var title = "Codex Pet Limit Rings"
    var version = "1.0.9"
}

private struct AppServerInitializedNotification: Encodable {
    var method = "initialized"
}

private struct AppServerRateLimitReadRequest: Encodable {
    var id = 2
    var method = "account/rateLimits/read"
}

private struct AppServerAccountUsageReadRequest: Encodable {
    var id = 2
    var method = "account/usage/read"
}

private struct AppServerResponseID: Decodable {
    var id: Int?
}

private struct AppServerRateLimitReadResponse: Decodable {
    var id: Int?
    var result: AppServerRateLimitResult?
}

struct DailyUsageBucket: Decodable, Equatable {
    var startDate: String
    var tokens: Int64
}

private struct AppServerAccountUsageResult: Decodable {
    var dailyUsageBuckets: [DailyUsageBucket]?
    var summary: DailyUsageSummary?
}

private struct AppServerAccountUsageReadResponse: Decodable {
    var id: Int?
    var result: AppServerAccountUsageResult?
}

struct DailyUsageSnapshot {
    var buckets: [DailyUsageBucket]
    var summary: DailyUsageSummary?
    var observedAt: Date
}

struct DailyUsageSummary: Decodable, Equatable {
    var currentStreakDays: Int64?
    var lifetimeTokens: Int64?
    var longestRunningTurnSec: Int64?
    var longestStreakDays: Int64?
    var peakDailyTokens: Int64?
}

func appServerReconnectDelay(attempt: Int) -> TimeInterval {
    guard attempt > 0 else { return 1 }
    return min(pow(2, Double(attempt - 1)), appServerReconnectMaximumDelay)
}

func normalizedDailyUsageBuckets(_ buckets: [DailyUsageBucket], limit: Int = dailyUsageDisplayCount) -> [DailyUsageBucket] {
    guard limit > 0 else { return [] }
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"

    var byDate: [String: DailyUsageBucket] = [:]
    for bucket in buckets where bucket.tokens >= 0 && formatter.date(from: bucket.startDate) != nil {
        byDate[bucket.startDate] = bucket
    }
    return Array(byDate.values.sorted { $0.startDate < $1.startDate }.suffix(limit))
}

func dailyUsageBar(tokens: Int64, maximum: Int64, width: Int = 10) -> String {
    guard width > 0 else { return "" }
    let filled: Int
    if tokens <= 0 || maximum <= 0 {
        filled = 0
    } else {
        filled = max(1, min(width, Int((Double(tokens) / Double(maximum) * Double(width)).rounded())))
    }
    return String(repeating: "▮", count: filled) + String(repeating: "·", count: width - filled)
}

struct UsageDurationUnitLabels {
    var day: String
    var hour: String
    var minute: String
    var second: String
}

func formattedUsageDuration(seconds: Int64, labels: UsageDurationUnitLabels) -> String? {
    guard seconds >= 0 else { return nil }
    let days = seconds / 86_400
    let hours = (seconds % 86_400) / 3_600
    let minutes = (seconds % 3_600) / 60
    let remainingSeconds = seconds % 60

    let components: [(Int64, String)]
    if days > 0 {
        components = [(days, labels.day), (hours, labels.hour)]
    } else if hours > 0 {
        components = [(hours, labels.hour), (minutes, labels.minute)]
    } else if minutes > 0 {
        components = [(minutes, labels.minute), (remainingSeconds, labels.second)]
    } else {
        components = [(remainingSeconds, labels.second)]
    }
    return components.map { "\($0.0)\($0.1)" }.joined(separator: " ")
}

enum ConnectionHealthState: Equatable {
    case live
    case stale
    case reconnecting
    case pollFallback
}

func connectionHealthState(
    isConnected: Bool,
    limitSource: String,
    fullSnapshotFreshness: DataFreshnessState = .current
) -> ConnectionHealthState {
    if isConnected {
        if limitSource == "app-server", fullSnapshotFreshness != .current {
            return .stale
        }
        return .live
    }
    if limitSource == "cached" || limitSource == "local" { return .pollFallback }
    return .reconnecting
}

func shouldApplyPolledLimitState(isLiveConnected: Bool) -> Bool {
    !isLiveConnected
}

enum DataFreshnessState: String, Equatable {
    case current
    case stale
    case waiting
}

func dataFreshnessState(observedAt: Date?, now: Date = Date(), maxAge: TimeInterval) -> DataFreshnessState {
    guard let observedAt else { return .waiting }
    let age = now.timeIntervalSince(observedAt)
    return age >= 0 && age <= maxAge ? .current : .stale
}

enum ConnectionFailureReason: String, Equatable {
    case cliUnavailable
    case incompatibleResponse
    case timedOut
    case disconnected
    case communicationFailed
    case unknown
}

func connectionFailureReason(for errorCode: String?) -> ConnectionFailureReason? {
    guard let errorCode else { return nil }
    switch errorCode {
    case "cli_not_found", "launch_failed": return .cliUnavailable
    case "invalid_rate_limit_response", "invalid_account_usage_response": return .incompatibleResponse
    case "initialize_timeout", "rate_limit_timeout", "account_usage_timeout": return .timedOut
    case "app_server_terminated", "initialize_failed", "app_server_disconnected": return .disconnected
    case "request_write_failed", "rate_limit_write_failed", "account_usage_write_failed": return .communicationFailed
    default: return .unknown
    }
}

func normalizedCodexCLIVersion(_ output: String) -> String? {
    guard let firstLine = output.split(whereSeparator: { $0.isNewline }).first else { return nil }
    let value = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, value.count <= 120 else { return nil }
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ._+-"))
    guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
    return value
}

private func readCodexCLIVersion(at url: URL) -> String? {
    let process = Process()
    let output = Pipe()
    let completed = DispatchSemaphore(value: 0)
    process.executableURL = url
    process.arguments = ["--version"]
    process.standardOutput = output
    process.standardError = Pipe()
    process.terminationHandler = { _ in completed.signal() }
    do {
        try process.run()
    } catch {
        return nil
    }
    if completed.wait(timeout: .now() + codexCLIVersionTimeout) == .timedOut {
        process.terminate()
        return nil
    }
    guard process.terminationStatus == 0 else { return nil }
    let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return normalizedCodexCLIVersion(text)
}

struct AppServerRateLimitResult: Decodable {
    var rateLimits: AppServerRateLimitSnapshot
    var rateLimitsByLimitId: [String: AppServerRateLimitSnapshot]?
    var rateLimitResetCredits: AppServerRateLimitResetCreditsSummary?

    func mergingSparse(_ update: AppServerRateLimitSnapshot) -> AppServerRateLimitResult {
        var merged = self
        merged.rateLimits = rateLimits.mergingSparse(update)
        if rateLimitsByLimitId != nil {
            let updateID = update.limitId ?? rateLimits.limitId ?? "codex"
            var byID = merged.rateLimitsByLimitId ?? [:]
            byID[updateID] = (byID[updateID] ?? rateLimits).mergingSparse(update)
            merged.rateLimitsByLimitId = byID
        }
        return merged
    }

    func toLimitState(observedAt: Date) -> LimitState? {
        let selected = rateLimitsByLimitId?["codex"] ?? rateLimits
        let normalized = normalizedMainLimitBuckets(
            primary: selected.primary?.toBucket(),
            secondary: selected.secondary?.toBucket()
        )
        let primary = normalized.shortWindow
        let secondary = normalized.weeklyWindow
        guard primary != nil || secondary != nil else {
            return nil
        }

        let selectedID = selected.limitId ?? "codex"
        let additional = (rateLimitsByLimitId ?? [:])
            .compactMap { limitID, snapshot -> AdditionalLimit? in
                guard limitID != selectedID,
                      limitID != "codex" else {
                    return nil
                }
                let detail = snapshot.toAdditionalLimit(defaultID: limitID)
                guard detail.representativeBucket != nil || detail.credits != nil || detail.individualLimit != nil || detail.reachedType != nil else {
                    return nil
                }
                return detail
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return LimitState(
            planType: selected.planType,
            primary: primary,
            secondary: secondary,
            additional: additional,
            credits: selected.credits?.toLimitCredits(),
            individualLimit: selected.individualLimit?.toSpendControlLimit(),
            reachedType: selected.rateLimitReachedType,
            resetCreditsAvailable: rateLimitResetCredits?.availableCount,
            observedAt: observedAt,
            source: "app-server"
        )
    }
}

struct AppServerRateLimitSnapshot: Decodable {
    var limitId: String?
    var limitName: String?
    var primary: AppServerRateLimitWindow?
    var secondary: AppServerRateLimitWindow?
    var credits: AppServerCreditsSnapshot?
    var individualLimit: AppServerSpendControlLimitSnapshot?
    var planType: String?
    var rateLimitReachedType: String?

    func mergingSparse(_ update: AppServerRateLimitSnapshot) -> AppServerRateLimitSnapshot {
        AppServerRateLimitSnapshot(
            limitId: update.limitId ?? limitId,
            limitName: update.limitName ?? limitName,
            primary: primary?.mergingSparse(update.primary) ?? update.primary,
            secondary: secondary?.mergingSparse(update.secondary) ?? update.secondary,
            credits: update.credits ?? credits,
            individualLimit: update.individualLimit ?? individualLimit,
            planType: update.planType ?? planType,
            rateLimitReachedType: update.rateLimitReachedType ?? rateLimitReachedType
        )
    }

    func toAdditionalLimit(defaultID: String) -> AdditionalLimit {
        AdditionalLimit(
            id: limitId ?? defaultID,
            name: limitName ?? limitId ?? defaultID,
            primary: primary?.toBucket(),
            secondary: secondary?.toBucket(),
            credits: credits?.toLimitCredits(),
            individualLimit: individualLimit?.toSpendControlLimit(),
            reachedType: rateLimitReachedType
        )
    }
}

struct AppServerCreditsSnapshot: Decodable {
    var hasCredits: Bool
    var unlimited: Bool
    var balance: String?

    func toLimitCredits() -> LimitCredits {
        LimitCredits(hasCredits: hasCredits, unlimited: unlimited, balance: balance)
    }
}

struct AppServerSpendControlLimitSnapshot: Decodable {
    var limit: String
    var used: String
    var remainingPercent: Double
    var resetsAt: Double

    func toSpendControlLimit() -> SpendControlLimit {
        SpendControlLimit(limit: limit, used: used, remainingPercent: remainingPercent, resetsAt: resetsAt)
    }
}

struct AppServerRateLimitResetCreditsSummary: Decodable {
    var availableCount: Int64
}

struct AppServerRateLimitWindow: Decodable {
    var usedPercent: Double?
    var windowDurationMins: Double?
    var resetsAt: Double?

    func mergingSparse(_ update: AppServerRateLimitWindow?) -> AppServerRateLimitWindow {
        guard let update else { return self }
        return AppServerRateLimitWindow(
            usedPercent: update.usedPercent ?? usedPercent,
            windowDurationMins: update.windowDurationMins ?? windowDurationMins,
            resetsAt: update.resetsAt ?? resetsAt
        )
    }

    func toBucket() -> LimitBucket? {
        guard let used = usedPercent else { return nil }
        if let minutes = windowDurationMins, minutes <= 0 {
            return nil
        }
        return LimitBucket(usedPercent: used, windowMinutes: windowDurationMins, resetAt: resetsAt)
    }
}

struct AppServerProbeResult {
    var state: LimitState?
    var cliPath: URL?
    var errorCode: String?
}

func defaultCodexCLIPaths(home: URL, environment: [String: String]) -> [String] {
    let pathCandidates = (environment["PATH"] ?? "")
        .split(separator: ":")
        .map { String($0) + "/codex" }

    return [
        environment["CODEX_PET_LIMIT_RINGS_CODEX_CLI"],
        environment["CODEX_CLI"],
        "/Applications/ChatGPT.app/Contents/Resources/codex",
        home.appendingPathComponent("Applications/ChatGPT.app/Contents/Resources/codex").path,
        "/Applications/Codex.app/Contents/Resources/codex",
        home.appendingPathComponent("Applications/Codex.app/Contents/Resources/codex").path,
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex"
    ].compactMap { $0 } + pathCandidates
}

final class AppServerLimitStateReader {
    private let codexHome: URL

    init(codexHome: URL) {
        self.codexHome = codexHome
    }

    func readLatest() -> LimitState? {
        readResult().state
    }

    func readResult() -> AppServerProbeResult {
        guard let codexCLI = findCodexCLI() else {
            return AppServerProbeResult(state: nil, cliPath: nil, errorCode: "cli_not_found")
        }

        let process = Process()
        process.executableURL = codexCLI
        process.arguments = ["app-server", "--stdio"]
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = codexHome.path
        process.environment = environment

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let lock = NSLock()
        let semaphore = DispatchSemaphore(value: 0)
        var buffer = ""
        var resolved = false
        var initialized = false
        var state: LimitState?
        var errorCode: String?

        func resolve(_ candidate: LimitState?, error: String?) {
            lock.lock()
            defer { lock.unlock() }
            guard !resolved else { return }
            state = candidate
            errorCode = error
            resolved = true
            semaphore.signal()
        }

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
                return
            }

            lock.lock()
            buffer += chunk
            let lines = Self.drainLines(from: &buffer)
            lock.unlock()

            for line in lines {
                guard let responseID = Self.responseID(in: line, decoder: decoder) else {
                    continue
                }
                if responseID == 1, !initialized {
                    initialized = true
                    do {
                        try Self.write(AppServerInitializedNotification(), to: stdin.fileHandleForWriting, encoder: encoder)
                        try Self.write(AppServerRateLimitReadRequest(), to: stdin.fileHandleForWriting, encoder: encoder)
                    } catch {
                        resolve(nil, error: "request_write_failed")
                    }
                } else if responseID == 2 {
                    guard let decoded = Self.decodeRateLimitState(from: line, decoder: decoder) else {
                        resolve(nil, error: "invalid_rate_limit_response")
                        continue
                    }
                    resolve(decoded, error: nil)
                }
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.terminationHandler = { _ in
            resolve(nil, error: initialized ? "app_server_terminated" : "initialize_failed")
        }

        do {
            try process.run()
            try Self.write(AppServerInitializeRequest(), to: stdin.fileHandleForWriting, encoder: encoder)
        } catch {
            return AppServerProbeResult(state: nil, cliPath: codexCLI, errorCode: "launch_failed")
        }

        if semaphore.wait(timeout: .now() + appServerLimitStateTimeout) == .timedOut {
            resolve(nil, error: initialized ? "rate_limit_timeout" : "initialize_timeout")
        }
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        stdin.fileHandleForWriting.closeFile()
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        lock.lock()
        defer { lock.unlock() }
        return AppServerProbeResult(state: state, cliPath: codexCLI, errorCode: errorCode)
    }

    static func decodeRateLimitState(from line: String, decoder: JSONDecoder = JSONDecoder()) -> LimitState? {
        guard let data = line.data(using: .utf8),
              let response = try? decoder.decode(AppServerRateLimitReadResponse.self, from: data),
              response.id == 2 else {
            return nil
        }
        return response.result?.toLimitState(observedAt: Date())
    }

    private func findCodexCLI() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let environment = ProcessInfo.processInfo.environment
        var seen = Set<String>()
        return defaultCodexCLIPaths(home: home, environment: environment)
            .filter { seen.insert($0).inserted }
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private static func write<T: Encodable>(_ payload: T, to handle: FileHandle, encoder: JSONEncoder) throws {
        var data = try encoder.encode(payload)
        data.append(0x0a)
        handle.write(data)
    }

    private static func drainLines(from buffer: inout String) -> [String] {
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: "\n") {
            lines.append(String(buffer[..<newline]))
            buffer.removeSubrange(buffer.startIndex...newline)
        }
        return lines
    }

    private static func responseID(in line: String, decoder: JSONDecoder) -> Int? {
        guard let data = line.data(using: .utf8),
              let response = try? decoder.decode(AppServerResponseID.self, from: data) else {
            return nil
        }
        return response.id
    }
}

final class AppServerAccountUsageReader {
    private let codexHome: URL

    init(codexHome: URL) {
        self.codexHome = codexHome
    }

    func readLatest() -> (snapshot: DailyUsageSnapshot?, cliPath: URL?, errorCode: String?) {
        guard let codexCLI = findCodexCLI() else {
            return (nil, nil, "cli_not_found")
        }

        let process = Process()
        process.executableURL = codexCLI
        process.arguments = ["app-server", "--stdio"]
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = codexHome.path
        process.environment = environment

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let lock = NSLock()
        let semaphore = DispatchSemaphore(value: 0)
        var buffer = ""
        var resolved = false
        var initialized = false
        var snapshot: DailyUsageSnapshot?
        var errorCode: String?

        func resolve(_ candidate: DailyUsageSnapshot?, error: String?) {
            lock.lock()
            defer { lock.unlock() }
            guard !resolved else { return }
            snapshot = candidate
            errorCode = error
            resolved = true
            semaphore.signal()
        }

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

            lock.lock()
            buffer += chunk
            let lines = Self.drainLines(from: &buffer)
            lock.unlock()

            for line in lines {
                guard let responseID = Self.responseID(in: line, decoder: decoder) else { continue }
                if responseID == 1, !initialized {
                    initialized = true
                    do {
                        try Self.write(AppServerInitializedNotification(), to: stdin.fileHandleForWriting, encoder: encoder)
                        try Self.write(AppServerAccountUsageReadRequest(), to: stdin.fileHandleForWriting, encoder: encoder)
                    } catch {
                        resolve(nil, error: "request_write_failed")
                    }
                } else if responseID == 2 {
                    guard let decoded = Self.decodeAccountUsage(from: line, decoder: decoder) else {
                        resolve(nil, error: "invalid_account_usage_response")
                        continue
                    }
                    resolve(decoded, error: nil)
                }
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.terminationHandler = { _ in
            resolve(nil, error: initialized ? "app_server_terminated" : "initialize_failed")
        }

        do {
            try process.run()
            try Self.write(AppServerInitializeRequest(), to: stdin.fileHandleForWriting, encoder: encoder)
        } catch {
            return (nil, codexCLI, "launch_failed")
        }

        if semaphore.wait(timeout: .now() + appServerLimitStateTimeout) == .timedOut {
            resolve(nil, error: initialized ? "account_usage_timeout" : "initialize_timeout")
        }
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        stdin.fileHandleForWriting.closeFile()
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        lock.lock()
        defer { lock.unlock() }
        return (snapshot, codexCLI, errorCode)
    }

    static func decodeAccountUsage(from line: String, decoder: JSONDecoder = JSONDecoder()) -> DailyUsageSnapshot? {
        guard let data = line.data(using: .utf8),
              let response = try? decoder.decode(AppServerAccountUsageReadResponse.self, from: data),
              response.id == 2,
              let result = response.result else {
            return nil
        }
        return DailyUsageSnapshot(
            buckets: normalizedDailyUsageBuckets(result.dailyUsageBuckets ?? []),
            summary: result.summary,
            observedAt: Date()
        )
    }

    private func findCodexCLI() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let environment = ProcessInfo.processInfo.environment
        var seen = Set<String>()
        return defaultCodexCLIPaths(home: home, environment: environment)
            .filter { seen.insert($0).inserted }
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private static func write<T: Encodable>(_ payload: T, to handle: FileHandle, encoder: JSONEncoder) throws {
        var data = try encoder.encode(payload)
        data.append(0x0a)
        handle.write(data)
    }

    private static func drainLines(from buffer: inout String) -> [String] {
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: "\n") {
            lines.append(String(buffer[..<newline]))
            buffer.removeSubrange(buffer.startIndex...newline)
        }
        return lines
    }

    private static func responseID(in line: String, decoder: JSONDecoder) -> Int? {
        guard let data = line.data(using: .utf8),
              let response = try? decoder.decode(AppServerResponseID.self, from: data) else {
            return nil
        }
        return response.id
    }
}

private struct AppServerMethodEnvelope: Decodable {
    var method: String?
}

private struct AppServerRateLimitsUpdatedNotification: Decodable {
    struct Params: Decodable {
        var rateLimits: AppServerRateLimitSnapshot
    }

    var method: String
    var params: Params
}

final class AppServerLiveClient {
    typealias RateLimitHandler = (LimitState, RateLimitUpdateOrigin) -> Void
    typealias UsageHandler = (DailyUsageSnapshot?, String?) -> Void
    typealias ConnectionHandler = (Bool, String?) -> Void
    typealias CLIHandler = (String, String?) -> Void
    typealias RefreshPathHandler = (RateLimitUpdateOrigin, RateLimitRefreshPath) -> Void

    private let codexHome: URL
    private let queue = DispatchQueue(label: "codex-pet-limit-rings.app-server-live")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var process: Process?
    private var stdin: Pipe?
    private var stdout: Pipe?
    private var stderr: Pipe?
    private var buffer = ""
    private var rateLimitResult: AppServerRateLimitResult?
    private var rateLimitRequestGate = RateLimitRequestGate()
    private var pendingRateLimitOrigin: RateLimitUpdateOrigin = .initialFullSync
    private var pendingSparseRateLimits: [AppServerRateLimitSnapshot] = []
    private var reconnectAttempt = 0
    private var reconnectScheduled = false
    private var reconnectScheduleToken = 0
    private var connectionGeneration = 0
    private var nextInitialRateLimitOrigin: RateLimitUpdateOrigin = .initialFullSync
    private var identifiedCLIPath: String?
    private var ready = false
    private var stopped = true

    var onRateLimitState: RateLimitHandler?
    var onUsage: UsageHandler?
    var onConnectionChanged: ConnectionHandler?
    var onCLIIdentified: CLIHandler?
    var onRefreshPath: RefreshPathHandler?

    init(codexHome: URL) {
        self.codexHome = codexHome
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopped = false
            self.startConnection()
        }
    }

    func stop() {
        queue.sync {
            stopped = true
            connectionGeneration += 1
            reconnectScheduleToken += 1
            reconnectScheduled = false
            closeCurrentProcess()
        }
    }

    func requestRateLimits(origin: RateLimitUpdateOrigin) {
        queue.async { [weak self] in
            self?.sendRateLimitRequest(origin: origin)
        }
    }

    func requestManualRateLimits(snapshotIsStale: Bool) {
        queue.async { [weak self] in
            guard let self, !self.stopped else { return }
            let path = manualRateLimitRefreshPath(
                isProcessRunning: self.process?.isRunning == true,
                isReady: self.ready,
                isSnapshotStale: snapshotIsStale
            )
            self.onRefreshPath?(.manualFullSync, path)
            switch path {
            case .connectedFullRead:
                self.sendRateLimitRequest(origin: .manualFullSync)
                self.sendUsageRequest()
            case .freshConnection:
                self.recreateConnection(origin: .manualFullSync)
            }
        }
    }

    func recreateRateLimitConnection(origin: RateLimitUpdateOrigin) {
        queue.async { [weak self] in
            guard let self, !self.stopped else { return }
            self.onRefreshPath?(origin, .freshConnection)
            self.recreateConnection(origin: origin)
        }
    }

    func requestUsage() {
        queue.async { [weak self] in
            self?.sendUsageRequest()
        }
    }

    private func startConnection() {
        guard !stopped, process == nil else { return }
        guard let codexCLI = findCodexCLI() else {
            reportDisconnected("cli_not_found")
            scheduleReconnect()
            return
        }
        if identifiedCLIPath != codexCLI.path {
            identifiedCLIPath = codexCLI.path
            onCLIIdentified?(codexCLISource(codexCLI), readCodexCLIVersion(at: codexCLI))
        }

        connectionGeneration += 1
        let generation = connectionGeneration
        ready = false
        buffer = ""

        let newProcess = Process()
        newProcess.executableURL = codexCLI
        newProcess.arguments = ["app-server", "--stdio"]
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = codexHome.path
        newProcess.environment = environment

        let newStdin = Pipe()
        let newStdout = Pipe()
        let newStderr = Pipe()
        newProcess.standardInput = newStdin
        newProcess.standardOutput = newStdout
        newProcess.standardError = newStderr
        process = newProcess
        stdin = newStdin
        stdout = newStdout
        stderr = newStderr

        newStdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            self?.queue.async {
                self?.consume(chunk: chunk, generation: generation)
            }
        }
        newStderr.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        newProcess.terminationHandler = { [weak self] _ in
            self?.queue.async {
                self?.handleTermination(generation: generation)
            }
        }

        do {
            try newProcess.run()
            try write(AppServerInitializeRequest())
        } catch {
            closeCurrentProcess()
            reportDisconnected("launch_failed")
            scheduleReconnect()
            return
        }

        queue.asyncAfter(deadline: .now() + appServerLimitStateTimeout) { [weak self] in
            guard let self, generation == self.connectionGeneration, !self.ready, !self.stopped else { return }
            self.closeCurrentProcess()
            self.reportDisconnected("initialize_timeout")
            self.scheduleReconnect()
        }
    }

    private func consume(chunk: String, generation: Int) {
        guard generation == connectionGeneration, !stopped else { return }
        buffer += chunk
        for line in Self.drainLines(from: &buffer) {
            handle(line: line)
        }
    }

    private func handle(line: String) {
        guard let data = line.data(using: .utf8) else { return }
        if let envelope = try? decoder.decode(AppServerMethodEnvelope.self, from: data),
           envelope.method == "account/rateLimits/updated",
           let notification = try? decoder.decode(AppServerRateLimitsUpdatedNotification.self, from: data) {
            if rateLimitRequestGate.inFlight {
                pendingSparseRateLimits.append(notification.params.rateLimits)
            }
            if let current = rateLimitResult {
                let merged = current.mergingSparse(notification.params.rateLimits)
                rateLimitResult = merged
                if let state = merged.toLimitState(observedAt: Date()) {
                    onRateLimitState?(state, .liveNotification)
                }
            }
            return
        }

        guard let response = try? decoder.decode(AppServerResponseID.self, from: data),
              let responseID = response.id else { return }
        switch responseID {
        case 1:
            do {
                try write(AppServerInitializedNotification())
                let initialOrigin = nextInitialRateLimitOrigin
                nextInitialRateLimitOrigin = .initialFullSync
                sendRateLimitRequest(origin: initialOrigin)
                sendUsageRequest()
            } catch {
                failConnection("request_write_failed")
            }
        case 2:
            let requestToken = rateLimitRequestGate.token
            guard rateLimitRequestGate.complete(token: requestToken) else { return }
            guard let decoded = try? decoder.decode(AppServerRateLimitReadResponse.self, from: data),
                  let result = decoded.result else {
                pendingSparseRateLimits.removeAll()
                failConnection("invalid_rate_limit_response")
                return
            }
            let mergedResult = pendingSparseRateLimits.reduce(result, { $0.mergingSparse($1) })
            pendingSparseRateLimits.removeAll()
            guard let state = mergedResult.toLimitState(observedAt: Date()) else {
                failConnection("invalid_rate_limit_response")
                return
            }
            rateLimitResult = mergedResult
            ready = true
            reconnectAttempt = 0
            onConnectionChanged?(true, nil)
            onRateLimitState?(state, pendingRateLimitOrigin)
        case 3:
            guard let decoded = try? decoder.decode(AppServerAccountUsageReadResponse.self, from: data),
                  let result = decoded.result else {
                onUsage?(nil, "invalid_account_usage_response")
                return
            }
            onUsage?(
                DailyUsageSnapshot(
                    buckets: normalizedDailyUsageBuckets(result.dailyUsageBuckets ?? []),
                    summary: result.summary,
                    observedAt: Date()
                ),
                nil
            )
        default:
            break
        }
    }

    private func sendRateLimitRequest(origin: RateLimitUpdateOrigin) {
        guard process?.isRunning == true else {
            guard !stopped else { return }
            reportDisconnected("app_server_disconnected")
            scheduleReconnect()
            return
        }
        guard let requestToken = rateLimitRequestGate.begin() else {
            pendingRateLimitOrigin = coalescedRateLimitRequestOrigin(
                current: pendingRateLimitOrigin,
                incoming: origin
            )
            return
        }
        pendingRateLimitOrigin = origin
        pendingSparseRateLimits.removeAll()
        let generation = connectionGeneration
        do {
            try write(AppServerRateLimitReadRequest())
        } catch {
            rateLimitRequestGate.cancel()
            failConnection("rate_limit_write_failed")
            return
        }
        queue.asyncAfter(deadline: .now() + appServerLimitStateTimeout) { [weak self] in
            guard let self,
                  generation == self.connectionGeneration,
                  self.rateLimitRequestGate.isCurrent(requestToken) else { return }
            self.rateLimitRequestGate.cancel()
            self.failConnection("rate_limit_timeout")
        }
    }

    private func sendUsageRequest() {
        guard process?.isRunning == true else {
            onUsage?(nil, "app_server_disconnected")
            return
        }
        do {
            try write(AppServerAccountUsageReadRequest(id: 3))
        } catch {
            onUsage?(nil, "account_usage_write_failed")
            failConnection("account_usage_write_failed")
        }
    }

    private func failConnection(_ errorCode: String) {
        if nextInitialRateLimitOrigin != .manualFullSync {
            nextInitialRateLimitOrigin = pendingRateLimitOrigin
        }
        closeCurrentProcess()
        reportDisconnected(errorCode)
        scheduleReconnect()
    }

    private func recreateConnection(origin: RateLimitUpdateOrigin) {
        nextInitialRateLimitOrigin = origin
        connectionGeneration += 1
        reconnectScheduleToken += 1
        reconnectScheduled = false
        closeCurrentProcess()
        reportDisconnected(nil)
        startConnection()
    }

    private func handleTermination(generation: Int) {
        guard generation == connectionGeneration, !stopped, process != nil else { return }
        closeCurrentProcess()
        reportDisconnected(ready ? "app_server_terminated" : "initialize_failed")
        scheduleReconnect()
    }

    private func reportDisconnected(_ errorCode: String?) {
        ready = false
        onConnectionChanged?(false, errorCode)
    }

    private func scheduleReconnect() {
        guard !stopped, !reconnectScheduled else { return }
        reconnectScheduled = true
        reconnectAttempt += 1
        let delay = appServerReconnectDelay(attempt: reconnectAttempt)
        let generation = connectionGeneration
        reconnectScheduleToken += 1
        let scheduleToken = reconnectScheduleToken
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard reconnectCallbackIsCurrent(
                scheduleToken: scheduleToken,
                currentScheduleToken: self.reconnectScheduleToken,
                generation: generation,
                currentGeneration: self.connectionGeneration,
                stopped: self.stopped
            ) else { return }
            self.reconnectScheduled = false
            self.startConnection()
        }
    }

    private func closeCurrentProcess() {
        rateLimitRequestGate.cancel()
        pendingSparseRateLimits.removeAll()
        rateLimitResult = nil
        stdout?.fileHandleForReading.readabilityHandler = nil
        stderr?.fileHandleForReading.readabilityHandler = nil
        stdin?.fileHandleForWriting.closeFile()
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        stdin = nil
        stdout = nil
        stderr = nil
        if stopped {
            reconnectScheduled = false
        }
    }

    private func write<T: Encodable>(_ payload: T) throws {
        guard let handle = stdin?.fileHandleForWriting else {
            throw CocoaError(.fileNoSuchFile)
        }
        var data = try encoder.encode(payload)
        data.append(0x0a)
        handle.write(data)
    }

    private func findCodexCLI() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let environment = ProcessInfo.processInfo.environment
        var seen = Set<String>()
        return defaultCodexCLIPaths(home: home, environment: environment)
            .filter { seen.insert($0).inserted }
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private static func drainLines(from buffer: inout String) -> [String] {
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: "\n") {
            lines.append(String(buffer[..<newline]))
            buffer.removeSubrange(buffer.startIndex...newline)
        }
        return lines
    }
}

private struct BucketPayload: Decodable {
    var used_percent: Double?
    var window_minutes: Double?
    var limit_window_seconds: Double?
    var reset_at: Double?

    func toBucket() -> LimitBucket? {
        guard let used = used_percent else { return nil }
        let minutes = window_minutes ?? limit_window_seconds.map { $0 / 60.0 }
        return LimitBucket(usedPercent: used, windowMinutes: minutes, resetAt: reset_at)
    }
}

struct LimitRingsConfig {
    var codexHome: URL
    var globalStatePath: URL
    var logsPath: URL
    var previewPath: URL?
    var diagnose = false
    var fallbackSize: CGFloat = 220
}

final class LimitStateReader {
    private let logsPath: URL
    private let appServerStateProvider: (() -> LimitState?)?
    private var lastAppServerState: LimitState?

    init(
        logsPath: URL,
        codexHome: URL? = nil,
        appServerStateProvider: (() -> LimitState?)? = nil
    ) {
        self.logsPath = logsPath
        if let appServerStateProvider {
            self.appServerStateProvider = appServerStateProvider
        } else if let codexHome {
            let appServerReader = AppServerLimitStateReader(codexHome: codexHome)
            self.appServerStateProvider = { appServerReader.readLatest() }
        } else {
            self.appServerStateProvider = nil
        }
    }

    func readLatest() -> LimitState {
        if let appServerState = appServerStateProvider?() {
            lastAppServerState = appServerState
            return appServerState
        }

        let logState = readLatestLog()
        if isDisplayableLimitState(logState), isCurrentLimitState(logState, now: Date()) {
            return logState
        }

        if var cached = lastAppServerState,
           Date().timeIntervalSince(cached.observedAt) <= limitStateFallbackMaxAge,
           isCurrentLimitState(cached, now: Date()) {
            cached.source = "cached"
            return cached
        }

        return .empty
    }

    private func readLatestLog() -> LimitState {
        guard FileManager.default.fileExists(atPath: logsPath.path) else {
            return .empty
        }

        var db: OpaquePointer?
        let openResult = sqlite3_open_v2(logsPath.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        guard openResult == SQLITE_OK, let db else {
            return .empty
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT ts, feedback_log_body
        FROM logs
        WHERE feedback_log_body LIKE '%"type":"codex.rate_limits"%'
        ORDER BY ts DESC, ts_nanos DESC, id DESC
        LIMIT 1
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return .empty
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW,
              let cText = sqlite3_column_text(statement, 1) else {
            return .empty
        }

        let observedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 0)))
        let body = String(cString: cText)
        guard let json = extractRateLimitJSON(from: body),
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(EventPayload.self, from: data) else {
            return .empty
        }

        let normalized = normalizedMainLimitBuckets(
            primary: (payload.rate_limits?.primary ?? payload.rate_limits?.primary_window)?.toBucket(),
            secondary: (payload.rate_limits?.secondary ?? payload.rate_limits?.secondary_window)?.toBucket()
        )
        let primary = normalized.shortWindow
        let secondary = normalized.weeklyWindow
        let additional = (payload.additional_rate_limits ?? [:])
            .compactMap { name, payload -> AdditionalLimit? in
                let primary = (payload.primary ?? payload.primary_window)?.toBucket()
                let secondary = (payload.secondary ?? payload.secondary_window)?.toBucket()
                guard primary != nil || secondary != nil else {
                    return nil
                }
                return AdditionalLimit(id: name, name: name, primary: primary, secondary: secondary, credits: nil, individualLimit: nil, reachedType: nil)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let state = LimitState(
            planType: payload.plan_type,
            primary: primary,
            secondary: secondary,
            additional: additional,
            observedAt: observedAt,
            source: "local"
        )
        return isCurrentLimitState(state, now: Date()) ? state : .empty
    }

    private func isDisplayableLimitState(_ state: LimitState) -> Bool {
        state.primary != nil || state.secondary != nil
    }

    private func isCurrentLimitState(_ state: LimitState, now: Date) -> Bool {
        [state.primary, state.secondary].compactMap { $0 }.contains {
            if let resetAt = $0.resetAt {
                return resetAt > now.timeIntervalSince1970
            }
            let maxAge = max(($0.windowMinutes ?? 0) * 60, limitStateFallbackMaxAge)
            return now.timeIntervalSince(state.observedAt) <= maxAge
        }
    }

    private func extractRateLimitJSON(from body: String) -> String? {
        guard let start = body.range(of: "{\"type\":\"codex.rate_limits\"")?.lowerBound else {
            return nil
        }

        var depth = 0
        var inString = false
        var escaping = false
        var endIndex: String.Index?
        var index = start

        while index < body.endIndex {
            let char = body[index]
            if inString {
                if escaping {
                    escaping = false
                } else if char == "\\" {
                    escaping = true
                } else if char == "\"" {
                    inString = false
                }
            } else {
                if char == "\"" {
                    inString = true
                } else if char == "{" {
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        endIndex = body.index(after: index)
                        break
                    }
                }
            }
            index = body.index(after: index)
        }

        guard let endIndex else { return nil }
        return String(body[start..<endIndex])
    }
}

struct PetFramesTopLeft {
    var mascot: CGRect
    var overlay: CGRect
    var usedLiveOverlay: Bool
}

func isCodexPetMascotEffectWindowName(_ name: String?) -> Bool {
    name == "Codex Pet Mascot Effect"
}

func isOfficialCodexPetMascotEffectWindow(
    name: String?,
    ownerPID: pid_t?,
    officialCodexPIDs: Set<pid_t>,
    layer: CGFloat,
    bounds: CGRect,
    mascotReference: CGRect
) -> Bool {
    guard let ownerPID, officialCodexPIDs.contains(ownerPID), layer > 0 else { return false }
    if let name, !name.isEmpty {
        return isCodexPetMascotEffectWindowName(name)
    }

    // Window names are redacted for a standalone accessory app unless the user
    // grants screen-recording access. Keep the app permission-free by accepting
    // only the current pet-effect layer and its tightly bounded geometry from
    // the already-verified official ChatGPT process.
    guard layer == 2 else { return false }
    let widthRatio = bounds.width / mascotReference.width
    let heightRatio = bounds.height / mascotReference.height
    let derivedWidth = (bounds.midX - mascotReference.minX) * 2
    let derivedHeight = (bounds.midY - mascotReference.minY) * 2
    return widthRatio >= 1.35 && widthRatio <= 5.0
        && heightRatio >= 1.35 && heightRatio <= 5.0
        && derivedWidth >= 40 && derivedWidth <= bounds.width
        && derivedHeight >= 40 && derivedHeight <= bounds.height
}

final class PetFrameReader {
    private let globalStatePath: URL
    private let liveOverlayProvider: ((CGRect, CGSize) -> CGRect?)?
    private let liveMascotEffectProvider: ((CGRect) -> CGRect?)?

    init(
        globalStatePath: URL,
        liveOverlayProvider: ((CGRect, CGSize) -> CGRect?)? = nil,
        liveMascotEffectProvider: ((CGRect) -> CGRect?)? = nil
    ) {
        self.globalStatePath = globalStatePath
        self.liveOverlayProvider = liveOverlayProvider
        self.liveMascotEffectProvider = liveMascotEffectProvider
    }

    func readPetFramesTopLeft(
        preferLiveOverlay: Bool = false,
        requireLiveOverlay: Bool = false,
        liveReference: CGRect? = nil
    ) -> PetFramesTopLeft? {
        guard let data = try? Data(contentsOf: globalStatePath),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              isAvatarOverlayOpen(root),
              let bounds = root["electron-avatar-overlay-bounds"] as? [String: Any],
              let x = number(bounds["x"]),
              let y = number(bounds["y"]) else {
            return nil
        }

        if let overlayWidth = number(bounds["width"]),
           let overlayHeight = number(bounds["height"]),
           let mascotPayload = bounds["mascot"] as? [String: Any],
           let left = number(mascotPayload["left"]),
           let top = number(mascotPayload["top"]),
           let width = number(mascotPayload["width"]),
           let height = number(mascotPayload["height"]) {
            return readLegacyPetFramesTopLeft(
                persistedOverlay: CGRect(x: x, y: y, width: overlayWidth, height: overlayHeight),
                mascotOffset: CGPoint(x: left, y: top),
                mascotSize: CGSize(width: width, height: height),
                preferLiveOverlay: preferLiveOverlay,
                requireLiveOverlay: requireLiveOverlay,
                liveReference: liveReference
            )
        }

        return readModernPetFramesTopLeft(
            bounds: bounds,
            persistedMascotOrigin: CGPoint(x: x, y: y),
            preferLiveOverlay: preferLiveOverlay,
            requireLiveOverlay: requireLiveOverlay,
            liveReference: liveReference
        )
    }

    private func readLegacyPetFramesTopLeft(
        persistedOverlay: CGRect,
        mascotOffset: CGPoint,
        mascotSize: CGSize,
        preferLiveOverlay: Bool,
        requireLiveOverlay: Bool,
        liveReference: CGRect?
    ) -> PetFramesTopLeft? {
        let shouldReadLiveOverlay = preferLiveOverlay || requireLiveOverlay
        let liveOverlay: CGRect?
        if shouldReadLiveOverlay {
            let reference = liveReference ?? persistedOverlay
            if let liveOverlayProvider {
                liveOverlay = liveOverlayProvider(reference, persistedOverlay.size)
            } else {
                liveOverlay = liveCodexOverlayBounds(matching: reference, expectedSize: persistedOverlay.size)
            }
        } else {
            liveOverlay = nil
        }
        if requireLiveOverlay, liveOverlay == nil {
            return nil
        }
        let overlay = liveOverlay ?? persistedOverlay
        let mascot = CGRect(
            x: overlay.minX + mascotOffset.x,
            y: overlay.minY + mascotOffset.y,
            width: mascotSize.width,
            height: mascotSize.height
        )
        return PetFramesTopLeft(mascot: mascot, overlay: overlay, usedLiveOverlay: liveOverlay != nil)
    }

    private func readModernPetFramesTopLeft(
        bounds: [String: Any],
        persistedMascotOrigin: CGPoint,
        preferLiveOverlay: Bool,
        requireLiveOverlay: Bool,
        liveReference: CGRect?
    ) -> PetFramesTopLeft? {
        let historicalSize = historicalMascotSize(in: bounds)
        let referenceSize = historicalSize ?? CGSize(width: 113, height: 122)
        let persistedMascot = CGRect(origin: persistedMascotOrigin, size: referenceSize)
        let shouldReadLiveEffect = preferLiveOverlay || requireLiveOverlay
        let liveEffect: CGRect?
        if shouldReadLiveEffect {
            let reference = liveReference ?? persistedMascot
            if let liveMascotEffectProvider {
                liveEffect = liveMascotEffectProvider(reference)
            } else {
                liveEffect = liveCodexMascotEffectBounds(
                    matching: reference,
                    mascotReference: persistedMascot
                )
            }
        } else {
            liveEffect = nil
        }

        if requireLiveOverlay, liveEffect == nil {
            return nil
        }

        guard let liveEffect else {
            guard let historicalSize else { return nil }
            let mascot = CGRect(origin: persistedMascotOrigin, size: historicalSize)
            return PetFramesTopLeft(mascot: mascot, overlay: mascot, usedLiveOverlay: false)
        }

        let derivedSize = modernMascotSize(
            origin: persistedMascotOrigin,
            effectBounds: liveEffect,
            historicalSize: historicalSize
        )
        guard let mascotSize = derivedSize ?? historicalSize else { return nil }
        let mascot = CGRect(
            x: liveEffect.midX - mascotSize.width / 2,
            y: liveEffect.midY - mascotSize.height / 2,
            width: mascotSize.width,
            height: mascotSize.height
        )
        return PetFramesTopLeft(mascot: mascot, overlay: liveEffect, usedLiveOverlay: true)
    }

    func readPetFrameTopLeft(preferLiveOverlay: Bool = false, requireLiveOverlay: Bool = false) -> CGRect? {
        readPetFramesTopLeft(
            preferLiveOverlay: preferLiveOverlay,
            requireLiveOverlay: requireLiveOverlay
        )?.mascot
    }

    private func isAvatarOverlayOpen(_ root: [String: Any]) -> Bool {
        if let isOpen = root["electron-avatar-overlay-open"] as? Bool {
            return isOpen
        }
        if let isOpen = root["electron-avatar-overlay-open"] as? NSNumber {
            return isOpen.boolValue
        }
        return true
    }

    private func number(_ value: Any?) -> CGFloat? {
        if let value = value as? NSNumber {
            return CGFloat(truncating: value)
        }
        if let value = value as? Double {
            return CGFloat(value)
        }
        if let value = value as? Int {
            return CGFloat(value)
        }
        return nil
    }

    private func historicalMascotSize(in bounds: [String: Any]) -> CGSize? {
        func size(in payload: [String: Any]) -> CGSize? {
            for key in ["mascot", "anchor"] {
                guard let frame = payload[key] as? [String: Any],
                      let width = number(frame["width"]),
                      let height = number(frame["height"]),
                      width >= 40,
                      height >= 40 else { continue }
                return CGSize(width: width, height: height)
            }
            return nil
        }

        let currentDisplayBounds = bounds["displayBounds"] as? [String: Any]
        let currentWidth = number(currentDisplayBounds?["width"])
        let currentHeight = number(currentDisplayBounds?["height"])
        var candidates: [[String: Any]] = []

        if let displayID = bounds["displayId"] as? NSNumber,
           let byDisplay = bounds["byDisplayId"] as? [String: Any],
           let current = byDisplay[String(displayID.intValue)] as? [String: Any] {
            candidates.append(current)
        }
        if let currentWidth, let currentHeight {
            for containerKey in ["byDisplayId", "byResolution"] {
                guard let container = bounds[containerKey] as? [String: Any] else { continue }
                for key in container.keys.sorted() {
                    guard let candidate = container[key] as? [String: Any],
                          let display = candidate["displayBounds"] as? [String: Any],
                          number(display["width"]) == currentWidth,
                          number(display["height"]) == currentHeight else { continue }
                    candidates.append(candidate)
                }
            }
        }
        for containerKey in ["byDisplayId", "byResolution"] {
            guard let container = bounds[containerKey] as? [String: Any] else { continue }
            for key in container.keys.sorted() {
                if let candidate = container[key] as? [String: Any] {
                    candidates.append(candidate)
                }
            }
        }
        return candidates.compactMap(size).first
    }

    private func modernMascotSize(
        origin: CGPoint,
        effectBounds: CGRect,
        historicalSize: CGSize?
    ) -> CGSize? {
        let derived = CGSize(
            width: (effectBounds.midX - origin.x) * 2,
            height: (effectBounds.midY - origin.y) * 2
        )
        // Current ChatGPT updates the saved mascot origin when its size slider
        // moves but omits explicit dimensions. Keep every valid live-derived
        // size; historical dimensions are only a safety fallback.
        guard derived.width >= 40,
              derived.height >= 40,
              derived.width <= effectBounds.width,
              derived.height <= effectBounds.height else {
            return historicalSize
        }
        return derived
    }

    private func liveCodexMascotEffectBounds(
        matching reference: CGRect,
        mascotReference: CGRect
    ) -> CGRect? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Per-window NSRunningApplication metadata can be incomplete in a
        // long-lived accessory app. Bind the exact pet-effect window name to
        // the already-identified official ChatGPT/Codex process instead.
        let officialCodexPIDs = Set(
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")
                .map(\.processIdentifier)
        )

        return windows.compactMap { window -> CGRect? in
            let ownerPID = (window[kCGWindowOwnerPID as String] as? NSNumber).map { pid_t($0.int32Value) }
            guard let layer = number(window[kCGWindowLayer as String]),
                  let payload = window[kCGWindowBounds as String] as? [String: Any],
                  let x = number(payload["X"]),
                  let y = number(payload["Y"]),
                  let width = number(payload["Width"]),
                  let height = number(payload["Height"]),
                  width >= 40,
                  height >= 40 else {
                return nil
            }
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            guard isOfficialCodexPetMascotEffectWindow(
                name: window[kCGWindowName as String] as? String,
                ownerPID: ownerPID,
                officialCodexPIDs: officialCodexPIDs,
                layer: layer,
                bounds: bounds,
                mascotReference: mascotReference
            ) else { return nil }
            return bounds
        }
        .min { distanceSquared($0.center, to: reference) < distanceSquared($1.center, to: reference) }
    }

    private func liveCodexOverlayBounds(matching reference: CGRect, expectedSize: CGSize) -> CGRect? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        return windows.compactMap { window -> CGRect? in
            let maxWidthDelta = max(80.0, expectedSize.width * 0.55)
            let maxHeightDelta = max(80.0, expectedSize.height * 0.55)
            guard isCodexWindow(window),
                  let layer = number(window[kCGWindowLayer as String]),
                  layer > 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let x = number(bounds["X"]),
                  let y = number(bounds["Y"]),
                  let width = number(bounds["Width"]),
                  let height = number(bounds["Height"]),
                  width >= 40.0,
                  height >= 40.0,
                  abs(width - expectedSize.width) <= maxWidthDelta,
                  abs(height - expectedSize.height) <= maxHeightDelta else {
                return nil
            }

            return CGRect(x: x, y: y, width: width, height: height)
        }
        .min {
            liveOverlayScore($0, reference: reference, expectedSize: expectedSize) < liveOverlayScore($1, reference: reference, expectedSize: expectedSize)
        }
    }

    private func isCodexWindow(_ window: [String: Any]) -> Bool {
        let ownerName = window[kCGWindowOwnerName as String] as? String
        let runningApplication = (window[kCGWindowOwnerPID as String] as? NSNumber).flatMap {
            NSRunningApplication(processIdentifier: pid_t($0.int32Value))
        }
        return codexApplicationCanPresentPet(
            bundleIdentifier: runningApplication?.bundleIdentifier,
            ownerName: ownerName,
            isHidden: runningApplication?.isHidden ?? false,
            isTerminated: runningApplication?.isTerminated ?? false
        )
    }

    private func liveOverlayScore(_ rect: CGRect, reference: CGRect, expectedSize: CGSize) -> CGFloat {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let distanceScore = distanceSquared(center, to: reference)
        let widthDelta = rect.width - expectedSize.width
        let heightDelta = rect.height - expectedSize.height
        return distanceScore + (widthDelta * widthDelta + heightDelta * heightDelta) * 8.0
    }

    private func distanceSquared(_ point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY
        return dx * dx + dy * dy
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

struct AccessibilityPresentation {
    var reduceMotion: Bool
    var increaseContrast: Bool
    var differentiateWithoutColor: Bool

    static let standard = AccessibilityPresentation(reduceMotion: false, increaseContrast: false, differentiateWithoutColor: false)

    static var current: AccessibilityPresentation {
        let workspace = NSWorkspace.shared
        return AccessibilityPresentation(
            reduceMotion: workspace.accessibilityDisplayShouldReduceMotion,
            increaseContrast: workspace.accessibilityDisplayShouldIncreaseContrast,
            differentiateWithoutColor: workspace.accessibilityDisplayShouldDifferentiateWithoutColor
        )
    }
}

struct LimitRingRenderer {
    var state: LimitState
    var phase: Double
    var showsReadout: Bool = false
    var fullSnapshotFreshness: DataFreshnessState = .current
    var accessibility: AccessibilityPresentation = .standard

    func draw(in rect: CGRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setShouldAntialias(true)
        context.clear(rect)

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let minSide = min(rect.width, rect.height)
        let urgency = max(urgency(for: state.primary), urgency(for: state.secondary))
        let isStale = ringPresentationIsStale(source: state.source, freshness: fullSnapshotFreshness)
        let animatedPhase = accessibility.reduceMotion || isStale ? 0.0 : phase
        let breathe = accessibility.reduceMotion ? CGFloat(0.0) : CGFloat((sin(animatedPhase * 2.0 * .pi) + 1.0) * 0.5)
        let pulse = accessibility.reduceMotion ? CGFloat(1.0) : CGFloat(1.0 + urgency * 0.025 * breathe)
        let outerRadius = (minSide * 0.5 - 16.0) * pulse
        let innerRadius = outerRadius - 13.0

        drawHalo(context, center: center, radius: outerRadius, urgency: CGFloat(urgency), breathe: breathe)
        drawTicks(context, center: center, radius: outerRadius + 5.0)

        if let primary = state.primary {
            drawRing(
                context,
                center: center,
                radius: outerRadius,
                lineWidth: 7.0,
                bucket: primary,
                color: color(forRemaining: primary.remainingPercent, role: .primary),
                trackAlpha: accessibility.increaseContrast ? 0.34 : 0.20,
                phase: animatedPhase,
                dashPattern: isStale ? [4.0, 3.0] : nil
            )
        } else {
            drawMissingRing(context, center: center, radius: outerRadius, lineWidth: 7.0)
        }

        if let secondary = state.secondary {
            drawRing(
                context,
                center: center,
                radius: innerRadius,
                lineWidth: 4.5,
                bucket: secondary,
                color: color(forRemaining: secondary.remainingPercent, role: .secondary),
                trackAlpha: accessibility.increaseContrast ? 0.28 : 0.14,
                phase: animatedPhase + 0.18,
                dashPattern: isStale ? [4.0, 3.0] : (accessibility.differentiateWithoutColor ? [5.0, 3.0] : nil)
            )
        }

        drawModelLimitDots(context, center: center, radius: outerRadius + 11.0, state: state)
        if showsReadout {
            drawLimitReadouts(context, center: center, outerRadius: outerRadius, innerRadius: innerRadius, bounds: rect, isStale: isStale)
        }
        if isStale {
            drawStaleIndicator(context, center: center, radius: outerRadius)
        }
        context.restoreGState()
    }

    private enum RingRole {
        case primary
        case secondary
    }

    private struct LimitReadout {
        var text: String
        var detailText: String?
        var ringPoint: CGPoint
        var labelRect: CGRect
        var color: NSColor
        var angle: CGFloat
    }

    private func urgency(for bucket: LimitBucket?) -> Double {
        guard let bucket else { return 0.0 }
        return min(max((45.0 - bucket.remainingPercent) / 45.0, 0.0), 1.0)
    }

    private func drawHalo(_ context: CGContext, center: CGPoint, radius: CGFloat, urgency: CGFloat, breathe: CGFloat) {
        context.saveGState()
        let color = NSColor(calibratedRed: 0.23 + urgency * 0.55, green: 0.85 - urgency * 0.30, blue: 0.78 - urgency * 0.48, alpha: 0.22 + urgency * 0.16)
        context.setLineCap(.round)
        context.setShadow(offset: .zero, blur: 14.0 + urgency * breathe * 5.0, color: color.withAlphaComponent(0.55).cgColor)
        context.setStrokeColor(color.withAlphaComponent(0.20).cgColor)
        context.setLineWidth(8.0)
        context.addArc(center: center, radius: radius + 3.0, startAngle: 0, endAngle: CGFloat.pi * 2.0, clockwise: false)
        context.strokePath()
        context.setShadow(offset: .zero, blur: 0.0, color: nil)
        context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.045).cgColor)
        context.setLineWidth(1.0)
        context.addArc(center: center, radius: radius + 13.0, startAngle: 0, endAngle: CGFloat.pi * 2.0, clockwise: false)
        context.strokePath()
        context.restoreGState()
    }

    private func drawTicks(_ context: CGContext, center: CGPoint, radius: CGFloat) {
        context.saveGState()
        context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.10).cgColor)
        context.setLineWidth(1.2)
        context.setLineCap(.round)
        for i in 0..<24 {
            guard i % 2 == 0 else { continue }
            let angle = -CGFloat.pi / 2.0 + CGFloat(i) / 24.0 * CGFloat.pi * 2.0
            let inner = radius - 1.5
            let outer = radius + 2.5
            context.move(to: point(center: center, radius: inner, angle: angle))
            context.addLine(to: point(center: center, radius: outer, angle: angle))
            context.strokePath()
        }
        context.restoreGState()
    }

    private func drawRing(
        _ context: CGContext,
        center: CGPoint,
        radius: CGFloat,
        lineWidth: CGFloat,
        bucket: LimitBucket,
        color: NSColor,
        trackAlpha: CGFloat,
        phase: Double,
        dashPattern: [CGFloat]?
    ) {
        let start = -CGFloat.pi / 2.0
        let remaining = CGFloat(bucket.remainingPercent / 100.0)
        let end = start + max(remaining, 0.018) * CGFloat.pi * 2.0

        context.saveGState()
        context.setLineCap(.round)
        context.setLineWidth(lineWidth)
        context.setStrokeColor(NSColor(calibratedWhite: 0.0, alpha: 0.22).cgColor)
        context.addArc(center: center, radius: radius + 1.0, startAngle: 0, endAngle: CGFloat.pi * 2.0, clockwise: false)
        context.strokePath()

        context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: trackAlpha).cgColor)
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: CGFloat.pi * 2.0, clockwise: false)
        context.strokePath()

        context.setShadow(offset: .zero, blur: 10.0, color: color.withAlphaComponent(0.42).cgColor)
        context.setStrokeColor(color.withAlphaComponent(0.30).cgColor)
        context.setLineWidth(lineWidth + 6.0)
        context.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        context.strokePath()

        context.setShadow(offset: .zero, blur: 4.0, color: color.withAlphaComponent(0.52).cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        if let dashPattern {
            context.setLineDash(phase: 0, lengths: dashPattern)
        }
        context.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        context.strokePath()

        if !accessibility.reduceMotion {
            let glintAngle = start + CGFloat(phase.truncatingRemainder(dividingBy: 1.0)) * CGFloat.pi * 2.0
            let glint = point(center: center, radius: radius, angle: glintAngle)
            context.setFillColor(NSColor(calibratedWhite: 1.0, alpha: 0.38).cgColor)
            context.fillEllipse(in: CGRect(x: glint.x - 1.8, y: glint.y - 1.8, width: 3.6, height: 3.6))
        }
        context.restoreGState()
    }

    private func drawMissingRing(_ context: CGContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat) {
        context.saveGState()
        context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: CGFloat.pi * 1.74, clockwise: false)
        context.strokePath()
        context.restoreGState()
    }

    private func drawLimitReadouts(_ context: CGContext, center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, bounds: CGRect, isStale: Bool) {
        var readouts: [LimitReadout] = []
        let staleLabel = localized("ring.stale", fallback: "Stale")
        if let primary = state.primary {
            readouts.append(makeReadout(
                text: (isStale ? "! " : "") + formatPercent(primary.remainingPercent),
                detailText: ringReadoutDetail(formatResetCountdown(primary.resetAt), isStale: isStale, staleLabel: staleLabel),
                center: center,
                ringRadius: outerRadius,
                labelRadius: outerRadius + 22.0,
                remainingPercent: primary.remainingPercent,
                color: color(forRemaining: primary.remainingPercent, role: .primary),
                bounds: bounds
            ))
        }

        if let secondary = state.secondary {
            readouts.append(makeReadout(
                text: (isStale ? "! " : "") + formatPercent(secondary.remainingPercent),
                detailText: ringReadoutDetail(formatResetCountdown(secondary.resetAt), isStale: isStale, staleLabel: staleLabel),
                center: center,
                ringRadius: innerRadius,
                labelRadius: innerRadius + 21.0,
                remainingPercent: secondary.remainingPercent,
                color: color(forRemaining: secondary.remainingPercent, role: .secondary),
                bounds: bounds
            ))
        }

        for readout in resolveReadoutOverlaps(readouts, bounds: bounds) {
            drawReadout(context, readout: readout)
        }
    }

    private func drawStaleIndicator(_ context: CGContext, center: CGPoint, radius: CGFloat) {
        let indicatorCenter = point(center: center, radius: radius + 2.0, angle: CGFloat.pi / 4.0)
        let rect = CGRect(x: indicatorCenter.x - 9.0, y: indicatorCenter.y - 9.0, width: 18.0, height: 18.0)
        context.saveGState()
        context.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 0.92).cgColor)
        context.fillEllipse(in: rect)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.86).cgColor)
        context.setLineWidth(1.4)
        context.strokeEllipse(in: rect.insetBy(dx: 0.7, dy: 0.7))
        let marker = NSAttributedString(
            string: "!",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: NSColor.white
            ]
        )
        let size = marker.size()
        marker.draw(at: CGPoint(x: rect.midX - size.width / 2.0, y: rect.midY - size.height / 2.0 + 0.5))
        context.restoreGState()
    }

    private func makeReadout(
        text: String,
        detailText: String?,
        center: CGPoint,
        ringRadius: CGFloat,
        labelRadius: CGFloat,
        remainingPercent: Double,
        color: NSColor,
        bounds: CGRect
    ) -> LimitReadout {
        let angle = -CGFloat.pi / 2.0 + CGFloat(max(remainingPercent, 1.8) / 100.0) * CGFloat.pi * 2.0
        let ringPoint = point(center: center, radius: ringRadius, angle: angle)
        let labelPoint = point(center: center, radius: labelRadius, angle: angle)
        let percentSize = NSAttributedString(string: text, attributes: readoutPercentAttributes()).size()
        let detailSize = detailText.map { NSAttributedString(string: $0, attributes: readoutDetailAttributes()).size() } ?? .zero
        let labelSize = CGSize(
            width: ceil(max(text.count > 3 ? 45.0 : 38.0, percentSize.width + 20.0, detailSize.width + 18.0)),
            height: detailText == nil ? 22.0 : 34.0
        )
        var labelRect = CGRect(
            x: labelPoint.x - labelSize.width / 2,
            y: labelPoint.y - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height
        )
        labelRect = clamp(labelRect, inside: bounds)
        return LimitReadout(text: text, detailText: detailText, ringPoint: ringPoint, labelRect: labelRect, color: color, angle: angle)
    }

    private func resolveReadoutOverlaps(_ readouts: [LimitReadout], bounds: CGRect) -> [LimitReadout] {
        guard readouts.count > 1 else { return readouts }
        var resolved = readouts

        let averageAngle = resolved.map(\.angle).reduce(0, +) / CGFloat(resolved.count)
        let tangent = CGPoint(x: -sin(averageAngle), y: cos(averageAngle))
        for index in resolved.indices {
            let direction = index == 0 ? -1.0 : 1.0
            resolved[index].labelRect = clamp(resolved[index].labelRect.offsetBy(dx: tangent.x * 12.0 * direction, dy: tangent.y * 12.0 * direction), inside: bounds)
        }

        for _ in 0..<8 {
            var changed = false
            for firstIndex in 0..<resolved.count {
                for secondIndex in (firstIndex + 1)..<resolved.count {
                    let first = expanded(resolved[firstIndex].labelRect)
                    let second = expanded(resolved[secondIndex].labelRect)
                    guard first.intersects(second) else { continue }

                    let xOverlap = min(first.maxX, second.maxX) - max(first.minX, second.minX)
                    let yOverlap = min(first.maxY, second.maxY) - max(first.minY, second.minY)
                    let gap: CGFloat = 6.0
                    if xOverlap <= yOverlap {
                        let direction: CGFloat = resolved[firstIndex].labelRect.midX <= resolved[secondIndex].labelRect.midX ? -1.0 : 1.0
                        let nudge = xOverlap / 2.0 + gap
                        resolved[firstIndex].labelRect = resolved[firstIndex].labelRect.offsetBy(dx: direction * nudge, dy: 0)
                        resolved[secondIndex].labelRect = resolved[secondIndex].labelRect.offsetBy(dx: -direction * nudge, dy: 0)
                    } else {
                        let direction: CGFloat = resolved[firstIndex].labelRect.midY <= resolved[secondIndex].labelRect.midY ? -1.0 : 1.0
                        let nudge = yOverlap / 2.0 + gap
                        resolved[firstIndex].labelRect = resolved[firstIndex].labelRect.offsetBy(dx: 0, dy: direction * nudge)
                        resolved[secondIndex].labelRect = resolved[secondIndex].labelRect.offsetBy(dx: 0, dy: -direction * nudge)
                    }

                    resolved[firstIndex].labelRect = clamp(resolved[firstIndex].labelRect, inside: bounds)
                    resolved[secondIndex].labelRect = clamp(resolved[secondIndex].labelRect, inside: bounds)
                    changed = true
                }
            }
            if !changed { break }
        }

        return resolved
    }

    private func expanded(_ rect: CGRect) -> CGRect {
        rect.insetBy(dx: -4.0, dy: -3.0)
    }

    private func clamp(_ rect: CGRect, inside bounds: CGRect) -> CGRect {
        var clamped = rect
        let inset = bounds.insetBy(dx: 4, dy: 4)
        clamped.origin.x = min(max(clamped.minX, inset.minX), inset.maxX - clamped.width)
        clamped.origin.y = min(max(clamped.minY, inset.minY), inset.maxY - clamped.height)
        return clamped
    }

    private func drawReadout(_ context: CGContext, readout: LimitReadout) {
        context.saveGState()
        context.setLineCap(.round)
        context.setStrokeColor(readout.color.withAlphaComponent(0.44).cgColor)
        context.setLineWidth(1.2)
        context.move(to: readout.ringPoint)
        context.addLine(to: CGPoint(x: readout.labelRect.midX, y: readout.labelRect.midY))
        context.strokePath()

        let path = CGPath(roundedRect: readout.labelRect, cornerWidth: 8.0, cornerHeight: 8.0, transform: nil)
        context.setShadow(offset: .zero, blur: 8.0, color: readout.color.withAlphaComponent(0.22).cgColor)
        context.setFillColor(NSColor(calibratedWhite: 0.055, alpha: accessibility.increaseContrast ? 0.96 : 0.78).cgColor)
        context.addPath(path)
        context.fillPath()
        context.setShadow(offset: .zero, blur: 0.0, color: nil)
        context.setStrokeColor(readout.color.withAlphaComponent(0.42).cgColor)
        context.setLineWidth(1.0)
        context.addPath(path)
        context.strokePath()

        let percent = NSAttributedString(string: readout.text, attributes: readoutPercentAttributes())
        let percentSize = percent.size()

        if let detailText = readout.detailText {
            let detail = NSAttributedString(string: detailText, attributes: readoutDetailAttributes())
            let detailSize = detail.size()
            let totalHeight = percentSize.height + detailSize.height - 1.0
            let detailY = readout.labelRect.midY - totalHeight / 2.0 - 0.5
            let percentY = detailY + detailSize.height - 1.0
            percent.draw(at: CGPoint(x: readout.labelRect.midX - percentSize.width / 2.0, y: percentY))
            detail.draw(at: CGPoint(x: readout.labelRect.midX - detailSize.width / 2.0, y: detailY))
        } else {
            percent.draw(at: CGPoint(x: readout.labelRect.midX - percentSize.width / 2, y: readout.labelRect.midY - percentSize.height / 2 + 0.5))
        }
        context.restoreGState()
    }

    private func drawModelLimitDots(_ context: CGContext, center: CGPoint, radius: CGFloat, state: LimitState) {
        let dots = Array(state.additional.prefix(8))
        guard dots.count > 0 else { return }
        context.saveGState()
        for (index, item) in dots.enumerated() {
            guard let bucket = item.representativeBucket else { continue }
            let angle = -CGFloat.pi / 2.0 + CGFloat(index) / CGFloat(max(dots.count, 1)) * CGFloat.pi * 2.0
            let dot = point(center: center, radius: radius, angle: angle)
            let color = color(forRemaining: bucket.remainingPercent, role: .primary)
            context.setShadow(offset: .zero, blur: 5.0, color: color.withAlphaComponent(0.35).cgColor)
            context.setFillColor(color.withAlphaComponent(0.82).cgColor)
            let marker = CGRect(x: dot.x - 2.4, y: dot.y - 2.4, width: 4.8, height: 4.8)
            if accessibility.differentiateWithoutColor, index.isMultiple(of: 2) {
                context.fill(marker)
            } else {
                context.fillEllipse(in: marker)
            }
        }
        context.restoreGState()
    }

    private func color(forRemaining remaining: Double, role: RingRole) -> NSColor {
        if remaining <= 12 {
            return NSColor(calibratedRed: 1.00, green: 0.26, blue: 0.22, alpha: 0.96)
        }
        if remaining <= 30 {
            return NSColor(calibratedRed: 1.00, green: 0.68, blue: 0.20, alpha: 0.96)
        }
        if role == .secondary {
            return NSColor(calibratedRed: 0.36, green: 0.70, blue: 1.00, alpha: 0.90)
        }
        return NSColor(calibratedRed: 0.24, green: 0.92, blue: 0.74, alpha: 0.96)
    }

    private func point(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    private func formatPercent(_ percent: Double) -> String {
        if abs(percent.rounded() - percent) < 0.05 {
            return "\(Int(percent.rounded()))%"
        }
        return String(format: "%.1f%%", percent)
    }

    private func formatResetCountdown(_ resetAt: TimeInterval?) -> String? {
        guard var resetAt else { return nil }
        if resetAt > 10_000_000_000 {
            resetAt /= 1000.0
        }

        let seconds = max(0, resetAt - Date().timeIntervalSince1970)
        if seconds <= 0 {
            return "soon"
        }
        if seconds < 60 {
            return "<1m"
        }
        if seconds >= 2.0 * 24.0 * 60.0 * 60.0 {
            return "\(Int(ceil(seconds / (24.0 * 60.0 * 60.0))))d"
        }

        let minutes = Int(ceil(seconds / 60.0))
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours < 24 {
            if hours >= 6 || remainingMinutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMinutes)m"
        }

        let days = hours / 24
        let remainingHours = hours % 24
        if days >= 7 || remainingHours == 0 {
            return "\(days)d"
        }
        return "\(days)d \(remainingHours)h"
    }

    private func readoutPercentAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: 11.5, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.92)
        ]
    }

    private func readoutDetailAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: 9.0, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.64),
            .kern: -0.35
        ]
    }
}

final class LimitRingView: NSView {
    var state: LimitState = .empty {
        didSet { needsDisplay = true }
    }
    var phase: Double = 0 {
        didSet { needsDisplay = true }
    }
    var showsReadout: Bool = false {
        didSet { needsDisplay = true }
    }
    var fullSnapshotFreshness: DataFreshnessState = .waiting {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        LimitRingRenderer(
            state: state,
            phase: phase,
            showsReadout: showsReadout,
            fullSnapshotFreshness: fullSnapshotFreshness,
            accessibility: .current
        ).draw(in: bounds)
    }
}

final class LimitRingsApp: NSObject {
    private let config: LimitRingsConfig
    private let stateReader: LimitStateReader
    private let liveClient: AppServerLiveClient
    private let frameReader: PetFrameReader
    private let panel: NSPanel
    private let ringView: LimitRingView
    private let stateQueue = DispatchQueue(label: "codex-pet-limit-rings.state-reader")
    private let fullSnapshotWatchdogQueue = DispatchQueue(label: "codex-pet-limit-rings.full-snapshot-watchdog")
    private let petFrameFallbackQueue = DispatchQueue(label: "codex-pet-limit-rings.pet-frame-fallback")
    private var statusItem: NSStatusItem?
    private var summaryItem: NSMenuItem?
    private var limitDetailsMenu: NSMenu?
    private var dailyUsageMenu: NSMenu?
    private var connectionHealthMenu: NSMenu?
    private var showRingsItem: NSMenuItem?
    private var notificationsItem: NSMenuItem?
    private var stateTimer: Timer?
    private var usageTimer: Timer?
    private var fullSnapshotWatchdogSource: DispatchSourceTimer?
    private var petFrameFallbackSource: DispatchSourceTimer?
    private var animationTimer: Timer?
    private var dragFollowTimer: Timer?
    private var mouseDownMonitor: Any?
    private var mouseDragMonitor: Any?
    private var mouseUpMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var globalStateSource: DispatchSourceFileSystemObject?
    private var pendingGlobalStateWatcherRestart: DispatchWorkItem?
    private var pendingFrameUpdate: DispatchWorkItem?
    private var pendingApplicationFrameUpdate: DispatchWorkItem?
    private var workspaceApplicationObservers: [NSObjectProtocol] = []
    private var startTime = Date()
    private var currentPetFrameAppKit: CGRect?
    private var currentPetOverlayTopLeft: CGRect?
    private var currentPetOverlayFrameAppKit: CGRect?
    private var isTrackingMouseDrag = false
    private var dragMouseToPetOriginOffsetAppKit: CGPoint?
    private var dragMouseToOverlayOriginOffsetAppKit: CGPoint?
    private var holdDraggedFrameUntil: Date?
    private var ringsVisible: Bool
    private var notificationsEnabled: Bool
    private var notificationBands: [String: Int]
    private var stateReadInFlight = false
    private var usageReadInFlight = false
    private var appServerConnected = false
    private var currentLimitSource = "none"
    private var dailyUsageSnapshot: DailyUsageSnapshot?
    private var dailyUsageErrorCode: String?
    private var lastRateLimitObservedAt: Date?
    private var lastLiveRateLimitUpdateAt: Date?
    private var lastFullRateLimitSyncAt: Date?
    private var lastFullRateLimitSyncUptime: TimeInterval?
    private var lastFullRateLimitSyncOrigin: RateLimitUpdateOrigin?
    private var fullSnapshotWatchdogRequestUptime: TimeInterval?
    private var lastRateLimitValueChangeAt: Date?
    private var lastRateLimitValueChangeOrigin: RateLimitUpdateOrigin?
    private var lastRateLimitSignature: String?
    private var lastConnectionErrorCode: String?
    private var lastConnectionFailureAt: Date?
    private var lastConnectionFailureCode: String?
    private var lastManualRefreshAt: Date?
    private var lastManualRefreshPath: RateLimitRefreshPath?
    private var codexCLISourceName = "not-found"
    private var codexCLIVersion: String?

    init(config: LimitRingsConfig) {
        self.config = config
        self.stateReader = LimitStateReader(logsPath: config.logsPath)
        self.liveClient = AppServerLiveClient(codexHome: config.codexHome)
        self.frameReader = PetFrameReader(globalStatePath: config.globalStatePath)
        self.ringView = LimitRingView(frame: CGRect(origin: .zero, size: CGSize(width: config.fallbackSize, height: config.fallbackSize)))
        self.ringsVisible = UserDefaults.standard.object(forKey: ringsVisibleDefaultsKey) as? Bool ?? true
        self.notificationsEnabled = notificationsEnabledFromStoredValue(
            UserDefaults.standard.object(forKey: notificationsEnabledDefaultsKey)
        )
        self.notificationBands = UserDefaults.standard.dictionary(forKey: notificationBandsDefaultsKey) as? [String: Int] ?? [:]
        self.panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: CGSize(width: config.fallbackSize, height: config.fallbackSize)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = ringView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        super.init()
        configureLiveClient()
    }

    deinit {
        stateTimer?.invalidate()
        usageTimer?.invalidate()
        fullSnapshotWatchdogSource?.cancel()
        petFrameFallbackSource?.cancel()
        animationTimer?.invalidate()
        dragFollowTimer?.invalidate()
        pendingGlobalStateWatcherRestart?.cancel()
        pendingFrameUpdate?.cancel()
        pendingApplicationFrameUpdate?.cancel()
        globalStateSource?.cancel()
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceApplicationObservers.forEach(workspaceCenter.removeObserver)
        liveClient.stop()
        [mouseDownMonitor, mouseDragMonitor, mouseUpMonitor, mouseMoveMonitor].compactMap { $0 }.forEach {
            NSEvent.removeMonitor($0)
        }
    }

    func run() {
        installStatusMenu()
        updateState()
        usageReadInFlight = true
        updateDailyUsageMenu()
        liveClient.start()
        startFullSnapshotWatchdog()
        updateFrame()
        installGlobalStateWatcher()
        installCodexApplicationObservers()
        startPetFrameFallbackWatchdog()
        updateRingVisibility()

        stateTimer = Timer.scheduledTimer(withTimeInterval: limitStatePollInterval, repeats: true) { [weak self] _ in
            guard let self, !self.appServerConnected else { return }
            self.updateState()
        }
        usageTimer = Timer.scheduledTimer(withTimeInterval: dailyUsageRefreshInterval, repeats: true) { [weak self] _ in
            self?.requestDailyUsage()
        }
        installDragFollow()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.ringView.phase = Date().timeIntervalSince(self.startTime) / 4.6
        }
    }

    private func updateState() {
        guard !stateReadInFlight else { return }
        stateReadInFlight = true
        stateQueue.async { [weak self] in
            guard let self else { return }
            let state = self.stateReader.readLatest()
            DispatchQueue.main.async {
                if shouldApplyPolledLimitState(isLiveConnected: self.appServerConnected) {
                    self.applyLimitState(state, origin: .fallback)
                }
                self.stateReadInFlight = false
            }
        }
    }

    private func configureLiveClient() {
        liveClient.onCLIIdentified = { [weak self] source, version in
            DispatchQueue.main.async {
                guard let self else { return }
                self.codexCLISourceName = source
                self.codexCLIVersion = version
                self.updateConnectionHealthMenu()
            }
        }
        liveClient.onConnectionChanged = { [weak self] connected, errorCode in
            DispatchQueue.main.async {
                guard let self else { return }
                self.appServerConnected = connected
                self.lastConnectionErrorCode = connected ? nil : errorCode
                if !connected, let errorCode {
                    self.lastConnectionFailureAt = Date()
                    self.lastConnectionFailureCode = errorCode
                }
                if !connected {
                    if self.dailyUsageSnapshot == nil {
                        self.dailyUsageErrorCode = errorCode
                        self.usageReadInFlight = false
                        self.updateDailyUsageMenu()
                    }
                    self.updateState()
                }
                self.updateConnectionHealthMenu()
                self.updateRingFreshness()
            }
        }
        liveClient.onRateLimitState = { [weak self] state, origin in
            DispatchQueue.main.async {
                self?.applyLimitState(state, origin: origin)
            }
        }
        liveClient.onUsage = { [weak self] snapshot, errorCode in
            DispatchQueue.main.async {
                guard let self else { return }
                if let snapshot {
                    self.dailyUsageSnapshot = snapshot
                    self.dailyUsageErrorCode = nil
                } else if self.dailyUsageSnapshot == nil {
                    self.dailyUsageErrorCode = errorCode
                }
                self.usageReadInFlight = false
                self.updateDailyUsageMenu()
                self.updateConnectionHealthMenu()
            }
        }
        liveClient.onRefreshPath = { [weak self] origin, path in
            DispatchQueue.main.async {
                guard let self else { return }
                if origin == .manualFullSync {
                    self.lastManualRefreshAt = Date()
                    self.lastManualRefreshPath = path
                }
                self.updateConnectionHealthMenu()
            }
        }
    }

    private func applyLimitState(_ state: LimitState, origin: RateLimitUpdateOrigin) {
        currentLimitSource = state.source
        if state.source != "none" {
            lastRateLimitObservedAt = state.observedAt
        }
        if state.source == "app-server" {
            switch origin {
            case .liveNotification:
                lastLiveRateLimitUpdateAt = state.observedAt
            case .initialFullSync, .scheduledFullSync, .manualFullSync:
                lastFullRateLimitSyncAt = state.observedAt
                lastFullRateLimitSyncUptime = continuousUptime()
                lastFullRateLimitSyncOrigin = origin
                fullSnapshotWatchdogRequestUptime = nil
            case .fallback:
                break
            }
        }
        let signature = rateLimitDisplaySignature(state)
        if lastRateLimitSignature != signature {
            lastRateLimitValueChangeAt = Date()
            lastRateLimitValueChangeOrigin = origin
            lastRateLimitSignature = signature
        }
        ringView.state = state
        updateRingFreshness()
        updateSummaryMenuItem()
        updateLimitDetailsMenu()
        processNotifications(for: state)
        updateConnectionHealthMenu()
    }

    private func startFullSnapshotWatchdog() {
        guard fullSnapshotWatchdogSource == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: fullSnapshotWatchdogQueue)
        source.schedule(
            deadline: .now() + fullSnapshotWatchdogTickInterval,
            repeating: fullSnapshotWatchdogTickInterval,
            leeway: .milliseconds(200)
        )
        source.setEventHandler { [weak self] in
            let uptime = continuousUptime()
            DispatchQueue.main.async {
                self?.evaluateFullSnapshotWatchdog(nowUptime: uptime)
            }
        }
        fullSnapshotWatchdogSource = source
        source.resume()
    }

    private func evaluateFullSnapshotWatchdog(nowUptime: TimeInterval) {
        updateRingFreshness(nowUptime: nowUptime)
        updateSummaryMenuItem()
        updateConnectionHealthMenu(nowUptime: nowUptime)
        switch fullSnapshotWatchdogAction(
            lastFullSyncUptime: lastFullRateLimitSyncUptime,
            overdueRequestUptime: fullSnapshotWatchdogRequestUptime,
            nowUptime: nowUptime,
            isConnected: appServerConnected
        ) {
        case .none:
            return
        case .requestFullSnapshot:
            fullSnapshotWatchdogRequestUptime = nowUptime
            liveClient.requestRateLimits(origin: .scheduledFullSync)
        case .recreateConnection:
            fullSnapshotWatchdogRequestUptime = nowUptime
            liveClient.recreateRateLimitConnection(origin: .scheduledFullSync)
        }
    }

    private func updateRingFreshness(nowUptime: TimeInterval = continuousUptime()) {
        if currentLimitSource == "app-server" {
            ringView.fullSnapshotFreshness = currentFullSnapshotFreshness(nowUptime: nowUptime)
        } else {
            ringView.fullSnapshotFreshness = .current
        }
    }

    private func requestDailyUsage() {
        usageReadInFlight = true
        updateDailyUsageMenu()
        liveClient.requestUsage()
    }

    private func installGlobalStateWatcher() {
        pendingGlobalStateWatcherRestart?.cancel()
        pendingGlobalStateWatcherRestart = nil
        globalStateSource?.cancel()
        globalStateSource = nil

        let descriptor = open(config.globalStatePath.path, O_EVTONLY)
        guard descriptor >= 0 else {
            scheduleGlobalStateWatcherRestart(after: 1.0)
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let events = self.globalStateSource?.data ?? []
            self.scheduleFrameUpdateFromGlobalState()
            if events.contains(.delete) || events.contains(.rename) {
                self.scheduleGlobalStateWatcherRestart(after: 0.2)
            }
        }
        source.setCancelHandler {
            close(descriptor)
        }
        globalStateSource = source
        source.resume()
    }

    private func scheduleGlobalStateWatcherRestart(after delay: TimeInterval) {
        pendingGlobalStateWatcherRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingGlobalStateWatcherRestart = nil
            self.installGlobalStateWatcher()
            self.scheduleFrameUpdateFromGlobalState()
        }
        pendingGlobalStateWatcherRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func scheduleFrameUpdateFromGlobalState() {
        pendingFrameUpdate?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingFrameUpdate = nil
            self.updateFrame()
            self.updateTooltip(at: NSEvent.mouseLocation)
        }
        pendingFrameUpdate = work
        DispatchQueue.main.asyncAfter(deadline: .now() + petFrameStateDebounceInterval, execute: work)
    }

    private func startPetFrameFallbackWatchdog() {
        guard petFrameFallbackSource == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: petFrameFallbackQueue)
        source.schedule(
            deadline: .now() + petFrameFallbackPollInterval,
            repeating: petFrameFallbackPollInterval,
            leeway: .milliseconds(150)
        )
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.updateFrame()
            }
        }
        petFrameFallbackSource = source
        source.resume()
    }

    private func installCodexApplicationObservers() {
        guard workspaceApplicationObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.didActivateApplicationNotification
        ]
        workspaceApplicationObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      shouldRefreshPetFrameForApplication(bundleIdentifier: application.bundleIdentifier) else {
                    return
                }
                self?.refreshPetFrameForApplicationLifecycleChange()
            }
        }
    }

    private func refreshPetFrameForApplicationLifecycleChange() {
        updateFrame()
        pendingApplicationFrameUpdate?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingApplicationFrameUpdate = nil
            self.updateFrame()
        }
        pendingApplicationFrameUpdate = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + petFrameApplicationLaunchGraceInterval,
            execute: work
        )
    }

    private func updateFrame(preferLiveOverlay: Bool = false) {
        if let holdDraggedFrameUntil, Date() < holdDraggedFrameUntil {
            return
        }
        holdDraggedFrameUntil = nil
        if isTrackingMouseDrag && !preferLiveOverlay {
            return
        }

        let liveReference = preferLiveOverlay ? currentPetOverlayTopLeft : nil
        guard let petFrames = frameReader.readPetFramesTopLeft(
            preferLiveOverlay: preferLiveOverlay,
            requireLiveOverlay: true,
            liveReference: liveReference
        ) else {
            currentPetFrameAppKit = nil
            currentPetOverlayTopLeft = nil
            currentPetOverlayFrameAppKit = nil
            isTrackingMouseDrag = false
            dragMouseToPetOriginOffsetAppKit = nil
            dragMouseToOverlayOriginOffsetAppKit = nil
            stopDragFollowTimer()
            ringView.showsReadout = false
            panel.orderOut(nil)
            return
        }

        if preferLiveOverlay,
           isTrackingMouseDrag,
           !petFrames.usedLiveOverlay,
           currentPetFrameAppKit != nil {
            return
        }

        applyPetFrames(petFrames)
    }

    private func applyPetFrames(_ petFrames: PetFramesTopLeft) {
        currentPetFrameAppKit = appKitRectFromTopLeft(petFrames.mascot)
        currentPetOverlayTopLeft = petFrames.overlay
        currentPetOverlayFrameAppKit = appKitRectFromTopLeft(petFrames.overlay)
        setPanelFrame(forPetFrameTopLeft: petFrames.mascot)
        if ringsVisible {
            panel.orderFrontRegardless()
        }
    }

    private func setPanelFrame(forPetFrameTopLeft petFrame: CGRect) {
        let padding: CGFloat = 38
        let size = max(petFrame.width, petFrame.height) + padding * 2
        let topLeft = CGPoint(x: petFrame.midX - size / 2, y: petFrame.midY - size / 2)
        let origin = appKitOriginFromTopLeft(topLeft, size: CGSize(width: size, height: size))

        panel.setFrame(CGRect(origin: origin, size: CGSize(width: size, height: size)), display: true)
    }

    private func setPanelFrame(forPetFrameAppKit petFrame: CGRect) {
        let padding: CGFloat = 38
        let size = max(petFrame.width, petFrame.height) + padding * 2
        let origin = CGPoint(x: petFrame.midX - size / 2, y: petFrame.midY - size / 2)
        panel.setFrame(CGRect(origin: origin, size: CGSize(width: size, height: size)), display: true)
    }

    private func installStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        if let button = item.button {
            button.title = ""
            button.image = makeStatusBarIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "Codex Pet Limit Rings"
        }

        let menu = NSMenu()
        let summary = NSMenuItem(
            title: localized("menu.waiting", fallback: "Waiting for Codex limit data"),
            action: nil,
            keyEquivalent: ""
        )
        summary.isEnabled = false
        menu.addItem(summary)
        summaryItem = summary

        let detailsItem = NSMenuItem(
            title: localized("menu.limitDetails", fallback: "Limit Details"),
            action: nil,
            keyEquivalent: ""
        )
        let detailsMenu = NSMenu(title: localized("menu.limitDetails", fallback: "Limit Details"))
        detailsItem.submenu = detailsMenu
        menu.addItem(detailsItem)
        limitDetailsMenu = detailsMenu

        let usageItem = NSMenuItem(
            title: localized("menu.dailyUsage", fallback: "Daily Usage"),
            action: nil,
            keyEquivalent: ""
        )
        let usageMenu = NSMenu(title: localized("menu.dailyUsage", fallback: "Daily Usage"))
        usageItem.submenu = usageMenu
        menu.addItem(usageItem)
        dailyUsageMenu = usageMenu

        let connectionItem = NSMenuItem(
            title: localized("menu.connectionHealth", fallback: "Connection Health"),
            action: nil,
            keyEquivalent: ""
        )
        let connectionMenu = NSMenu(title: localized("menu.connectionHealth", fallback: "Connection Health"))
        connectionItem.submenu = connectionMenu
        menu.addItem(connectionItem)
        connectionHealthMenu = connectionMenu

        menu.addItem(.separator())

        let showItem = NSMenuItem(
            title: localized("menu.showRings", fallback: "Show Rings"),
            action: #selector(toggleRings(_:)),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)
        showRingsItem = showItem

        let notifyItem = NSMenuItem(
            title: localized("menu.notifications", fallback: "Limit Notifications"),
            action: #selector(toggleNotifications(_:)),
            keyEquivalent: ""
        )
        notifyItem.target = self
        menu.addItem(notifyItem)
        notificationsItem = notifyItem

        let refreshItem = NSMenuItem(
            title: localized("menu.refresh", fallback: "Refresh Now"),
            action: #selector(refreshNow(_:)),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: localized("menu.quit", fallback: "Quit Codex Pet Limit Rings"),
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        updateSummaryMenuItem()
        updateLimitDetailsMenu()
        updateDailyUsageMenu()
        updateConnectionHealthMenu()
        updateShowRingsMenuItem()
        updateNotificationsMenuItem()
    }

    private func makeStatusBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.black.setStroke()
        let outer = NSBezierPath()
        outer.appendArc(
            withCenter: NSPoint(x: 9, y: 9),
            radius: 6.7,
            startAngle: 22,
            endAngle: 338,
            clockwise: false
        )
        outer.lineWidth = 2.0
        outer.lineCapStyle = .round
        outer.stroke()

        let inner = NSBezierPath()
        inner.appendArc(
            withCenter: NSPoint(x: 9, y: 9),
            radius: 3.6,
            startAngle: 210,
            endAngle: 82,
            clockwise: false
        )
        inner.lineWidth = 1.6
        inner.lineCapStyle = .round
        inner.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func updateSummaryMenuItem() {
        guard let summaryItem else { return }
        let primary = ringView.state.primary.map {
            String(format: localized("summary.short", fallback: "Short %@"), formatPercent($0.remainingPercent))
        }
        let secondary = ringView.state.secondary.map {
            String(format: localized("summary.weekly", fallback: "Weekly %@"), formatPercent($0.remainingPercent))
        }
        let pieces = [primary, secondary].compactMap { $0 }
        if pieces.isEmpty {
            summaryItem.title = localized("summary.noData", fallback: "No current Codex limit data")
        } else {
            let source: String
            switch ringView.state.source {
            case "app-server":
                if currentFullSnapshotFreshness() == .current {
                    source = localized("source.appServer", fallback: "App Server")
                } else {
                    source = localized("source.stale", fallback: "! Stale")
                }
            case "cached": source = localized("source.cached", fallback: "Cached")
            case "local": source = localized("source.local", fallback: "Local")
            default: source = localized("source.unknown", fallback: "Unknown")
            }
            summaryItem.title = "\(source) " + pieces.joined(separator: " | ")
        }
    }

    private func updateLimitDetailsMenu() {
        guard let menu = limitDetailsMenu else { return }
        menu.removeAllItems()
        let state = ringView.state
        var rows: [String] = []

        if let primary = state.primary {
            rows.append(String(format: localized("details.short", fallback: "Short window: %@"), formatPercent(primary.remainingPercent)))
            if state.source == "app-server" {
                rows.append(localized("details.enforcementNotReported", fallback: "Short-window enforcement: not reported by Codex"))
            }
        } else if state.secondary != nil, state.source == "app-server" {
            rows.append(localized("details.shortNotReported", fallback: "Short window: not reported by Codex"))
        }
        if let secondary = state.secondary {
            rows.append(String(format: localized("details.weekly", fallback: "Weekly window: %@"), formatPercent(secondary.remainingPercent)))
        }
        for limit in state.additional {
            if let primary = limit.primary {
                rows.append("\(limit.name): \(formatPercent(primary.remainingPercent))")
            }
            if let secondary = limit.secondary {
                rows.append(String(format: localized("details.secondary", fallback: "%@: secondary %@"), limit.name, formatPercent(secondary.remainingPercent)))
            }
        }

        appendAccountRows(credits: state.credits, individualLimit: state.individualLimit, reachedType: state.reachedType, to: &rows)
        for limit in state.additional {
            appendAccountRows(credits: limit.credits, individualLimit: limit.individualLimit, reachedType: limit.reachedType, prefix: limit.name, to: &rows)
        }
        if let count = state.resetCreditsAvailable {
            rows.append(String(format: localized("details.resetCredits", fallback: "Reset credits available: %@"), String(count)))
        }

        if rows.isEmpty {
            rows.append(localized("details.none", fallback: "No current limit details"))
        }
        for row in rows {
            let item = NSMenuItem(title: row, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    private func updateDailyUsageMenu() {
        guard let menu = dailyUsageMenu else { return }
        menu.removeAllItems()

        let rows: [String]
        if usageReadInFlight, dailyUsageSnapshot == nil {
            rows = [localized("usage.loading", fallback: "Loading daily usage…")]
        } else if dailyUsageErrorCode != nil {
            rows = [localized("usage.unavailable", fallback: "Daily usage is unavailable in this Codex version or account")]
        } else if let snapshot = dailyUsageSnapshot,
                  snapshot.buckets.isEmpty,
                  snapshot.summary == nil {
            rows = [localized("usage.empty", fallback: "No daily usage is available yet")]
        } else if let snapshot = dailyUsageSnapshot {
            let buckets = snapshot.buckets
            let maximum = buckets.map(\.tokens).max() ?? 0
            var usageRows: [String] = []
            if let streak = snapshot.summary?.currentStreakDays {
                usageRows.append(String(
                    format: localized("usage.currentStreak", fallback: "Current streak: %@ days"),
                    localizedInteger(streak)
                ))
            }
            if let longestStreak = snapshot.summary?.longestStreakDays {
                usageRows.append(String(
                    format: localized("usage.longestStreak", fallback: "Longest streak: %@ days"),
                    localizedInteger(longestStreak)
                ))
            }
            if let seconds = snapshot.summary?.longestRunningTurnSec,
               let duration = formattedUsageDuration(
                   seconds: seconds,
                   labels: UsageDurationUnitLabels(
                       day: localized("duration.dayShort", fallback: "d"),
                       hour: localized("duration.hourShort", fallback: "h"),
                       minute: localized("duration.minuteShort", fallback: "m"),
                       second: localized("duration.secondShort", fallback: "s")
                   )
               ) {
                usageRows.append(String(
                    format: localized("usage.longestTurn", fallback: "Longest turn: %@"),
                    duration
                ))
            }
            if let peak = snapshot.summary?.peakDailyTokens {
                usageRows.append(String(
                    format: localized("usage.peakDaily", fallback: "Peak day: %@ tokens"),
                    localizedInteger(peak)
                ))
            }
            if let lifetime = snapshot.summary?.lifetimeTokens {
                usageRows.append(String(
                    format: localized("usage.lifetime", fallback: "Lifetime: %@ tokens"),
                    localizedInteger(lifetime)
                ))
            }
            if !usageRows.isEmpty, !buckets.isEmpty {
                usageRows.append("──────────")
            }
            usageRows.append(contentsOf: buckets.reversed().map { bucket in
                String(
                    format: localized("usage.row", fallback: "%@  %@  %@ tokens"),
                    localizedDailyUsageDate(bucket.startDate),
                    dailyUsageBar(tokens: bucket.tokens, maximum: maximum),
                    localizedInteger(bucket.tokens)
                )
            })
            rows = usageRows.isEmpty ? [localized("usage.empty", fallback: "No daily usage is available yet")] : usageRows
        } else {
            rows = [localized("usage.loading", fallback: "Loading daily usage…")]
        }

        for row in rows {
            let item = NSMenuItem(title: row, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    private func currentFullSnapshotFreshness(nowUptime: TimeInterval = continuousUptime()) -> DataFreshnessState {
        fullSnapshotWatchdogFreshness(
            lastFullSyncUptime: lastFullRateLimitSyncUptime,
            nowUptime: nowUptime
        )
    }

    private func updateConnectionHealthMenu(nowUptime: TimeInterval = continuousUptime()) {
        guard let menu = connectionHealthMenu else { return }
        menu.removeAllItems()
        let fullSnapshotFreshness = currentFullSnapshotFreshness(nowUptime: nowUptime)

        let statusTitle: String
        switch connectionHealthState(
            isConnected: appServerConnected,
            limitSource: currentLimitSource,
            fullSnapshotFreshness: fullSnapshotFreshness
        ) {
        case .live:
            statusTitle = localized("connection.live", fallback: "● Live app-server updates")
        case .stale:
            statusTitle = localized("connection.stale", fallback: "! Stale full snapshot · refresh pending")
        case .reconnecting:
            statusTitle = localized("connection.reconnecting", fallback: "↻ Reconnecting to app-server")
        case .pollFallback:
            statusTitle = localized("connection.pollFallback", fallback: "↙ Poll fallback while reconnecting")
        }
        appendDisabledMenuItem(statusTitle, to: menu)

        let sourceLabel: String
        switch currentLimitSource {
        case "app-server":
            if fullSnapshotFreshness == .current {
                sourceLabel = localized("connection.sourceLive", fallback: "Live")
            } else {
                sourceLabel = localized("connection.sourceStale", fallback: "Stale app-server snapshot")
            }
        case "cached": sourceLabel = localized("connection.sourceCached", fallback: "Cached")
        case "local": sourceLabel = localized("connection.sourceLocal", fallback: "Local")
        default: sourceLabel = localized("connection.sourceWaiting", fallback: "Waiting")
        }
        appendDisabledMenuItem(
            String(format: localized("connection.source", fallback: "Rate-limit source: %@"), sourceLabel),
            to: menu
        )

        let cliIdentity = codexCLIVersion ?? codexCLISourceName
        appendDisabledMenuItem(
            String(format: localized("connection.codexCLI", fallback: "Codex CLI: %@"), cliIdentity),
            to: menu
        )

        appendFreshnessRow(
            observedAt: lastRateLimitObservedAt,
            maxAge: rateLimitFreshnessMaxAge,
            updatedKey: "connection.rateLimitsUpdated",
            updatedFallback: "Rate limits updated: %@ · %@",
            waitingKey: "connection.rateLimitsWaiting",
            waitingFallback: "Rate-limit update pending",
            to: menu
        )
        appendCadenceRow(
            observedAt: lastLiveRateLimitUpdateAt,
            key: "connection.lastLiveUpdate",
            fallback: "Last live update: %@",
            waitingKey: "connection.lastLiveWaiting",
            waitingFallback: "Live update not observed yet",
            origin: nil,
            to: menu
        )
        appendFreshnessCadenceRow(
            observedAt: lastFullRateLimitSyncAt,
            maxAge: fullSnapshotFreshnessMaxAge,
            key: "connection.lastFullSync",
            fallback: "Full snapshot metadata: %@ · %@ · %@",
            waitingKey: "connection.lastFullWaiting",
            waitingFallback: "Full sync pending",
            origin: lastFullRateLimitSyncOrigin,
            freshnessOverride: fullSnapshotFreshness,
            to: menu
        )
        appendCadenceRow(
            observedAt: lastRateLimitValueChangeAt,
            key: "connection.lastValueChange",
            fallback: "Last value change: %@ · %@",
            waitingKey: "connection.lastValueWaiting",
            waitingFallback: "Value change not observed yet",
            origin: lastRateLimitValueChangeOrigin,
            to: menu
        )
        appendFreshnessRow(
            observedAt: dailyUsageSnapshot?.observedAt,
            maxAge: usageFreshnessMaxAge,
            updatedKey: "connection.usageUpdated",
            updatedFallback: "Usage updated: %@ · %@",
            waitingKey: "connection.usageWaiting",
            waitingFallback: "Usage update pending",
            to: menu
        )

        if let reason = connectionFailureReason(for: lastConnectionErrorCode) {
            appendDisabledMenuItem(
                String(
                    format: localized("connection.reason", fallback: "Reason: %@"),
                    localizedConnectionFailureReason(reason)
                ),
                to: menu
            )
        }
        if let lastConnectionFailureAt,
           let reason = connectionFailureReason(for: lastConnectionFailureCode) {
            let time = DateFormatter.localizedString(from: lastConnectionFailureAt, dateStyle: .none, timeStyle: .short)
            appendDisabledMenuItem(
                String(
                    format: localized("connection.lastFailure", fallback: "Last connection issue: %@ · %@"),
                    time,
                    localizedConnectionFailureReason(reason)
                ),
                to: menu
            )
        }
        if let lastManualRefreshAt, let lastManualRefreshPath {
            let time = DateFormatter.localizedString(from: lastManualRefreshAt, dateStyle: .none, timeStyle: .short)
            appendDisabledMenuItem(
                String(
                    format: localized("connection.lastManualRefresh", fallback: "Last manual refresh: %@ · %@"),
                    time,
                    localizedRefreshPath(lastManualRefreshPath)
                ),
                to: menu
            )
        } else {
            appendDisabledMenuItem(
                localized("connection.lastManualWaiting", fallback: "Manual refresh not used yet"),
                to: menu
            )
        }
    }

    private func appendFreshnessRow(
        observedAt: Date?,
        maxAge: TimeInterval,
        updatedKey: String,
        updatedFallback: String,
        waitingKey: String,
        waitingFallback: String,
        to menu: NSMenu
    ) {
        guard let observedAt else {
            appendDisabledMenuItem(localized(waitingKey, fallback: waitingFallback), to: menu)
            return
        }
        let time = DateFormatter.localizedString(from: observedAt, dateStyle: .none, timeStyle: .short)
        let freshness = dataFreshnessState(observedAt: observedAt, maxAge: maxAge)
        appendDisabledMenuItem(
            String(format: localized(updatedKey, fallback: updatedFallback), time, localizedFreshness(freshness)),
            to: menu
        )
    }

    private func appendDisabledMenuItem(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func appendCadenceRow(
        observedAt: Date?, key: String, fallback: String,
        waitingKey: String, waitingFallback: String,
        origin: RateLimitUpdateOrigin?, to menu: NSMenu
    ) {
        guard let observedAt else {
            appendDisabledMenuItem(localized(waitingKey, fallback: waitingFallback), to: menu)
            return
        }
        let time = DateFormatter.localizedString(from: observedAt, dateStyle: .none, timeStyle: .short)
        if let origin {
            appendDisabledMenuItem(String(format: localized(key, fallback: fallback), time, localizedRateLimitOrigin(origin)), to: menu)
        } else {
            appendDisabledMenuItem(String(format: localized(key, fallback: fallback), time), to: menu)
        }
    }

    private func appendFreshnessCadenceRow(
        observedAt: Date?, maxAge: TimeInterval, key: String, fallback: String,
        waitingKey: String, waitingFallback: String,
        origin: RateLimitUpdateOrigin?,
        freshnessOverride: DataFreshnessState? = nil,
        to menu: NSMenu
    ) {
        guard let observedAt, let origin else {
            appendDisabledMenuItem(localized(waitingKey, fallback: waitingFallback), to: menu)
            return
        }
        let time = DateFormatter.localizedString(from: observedAt, dateStyle: .none, timeStyle: .short)
        let freshness = freshnessOverride ?? dataFreshnessState(observedAt: observedAt, maxAge: maxAge)
        appendDisabledMenuItem(
            String(
                format: localized(key, fallback: fallback),
                time,
                localizedRateLimitOrigin(origin),
                localizedFreshness(freshness)
            ),
            to: menu
        )
    }

    private func localizedRateLimitOrigin(_ origin: RateLimitUpdateOrigin) -> String {
        switch origin {
        case .initialFullSync: return localized("cadence.origin.initial", fallback: "Initial")
        case .liveNotification: return localized("cadence.origin.live", fallback: "Live")
        case .scheduledFullSync: return localized("cadence.origin.scheduled", fallback: "Scheduled")
        case .manualFullSync: return localized("cadence.origin.manual", fallback: "Manual")
        case .fallback: return localized("cadence.origin.fallback", fallback: "Fallback")
        }
    }

    private func localizedRefreshPath(_ path: RateLimitRefreshPath) -> String {
        switch path {
        case .connectedFullRead:
            return localized("refresh.connectedFullRead", fallback: "Connected full read")
        case .freshConnection:
            return localized("refresh.freshConnection", fallback: "Fresh app-server connection")
        }
    }

    private func localizedFreshness(_ freshness: DataFreshnessState) -> String {
        switch freshness {
        case .current: return localized("freshness.current", fallback: "✓ Current")
        case .stale: return localized("freshness.stale", fallback: "! Stale")
        case .waiting: return localized("freshness.waiting", fallback: "… Waiting")
        }
    }

    private func localizedConnectionFailureReason(_ reason: ConnectionFailureReason) -> String {
        switch reason {
        case .cliUnavailable: return localized("reason.cliUnavailable", fallback: "Codex CLI unavailable")
        case .incompatibleResponse: return localized("reason.incompatibleResponse", fallback: "Unsupported response shape")
        case .timedOut: return localized("reason.timedOut", fallback: "app-server timed out")
        case .disconnected: return localized("reason.disconnected", fallback: "app-server disconnected")
        case .communicationFailed: return localized("reason.communicationFailed", fallback: "app-server communication failed")
        case .unknown: return localized("reason.unknown", fallback: "Temporary compatibility issue")
        }
    }

    private func localizedDailyUsageDate(_ value: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    private func localizedInteger(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func appendAccountRows(
        credits: LimitCredits?,
        individualLimit: SpendControlLimit?,
        reachedType: String?,
        prefix: String? = nil,
        to rows: inout [String]
    ) {
        let labelPrefix = prefix.map { "\($0): " } ?? ""
        if let credits {
            if credits.unlimited {
                rows.append(labelPrefix + localized("details.creditsUnlimited", fallback: "Credits: unlimited"))
            } else if let balance = credits.balance, credits.hasCredits {
                rows.append(labelPrefix + String(format: localized("details.creditsBalance", fallback: "Credits balance: %@"), balance))
            }
        }
        if let individualLimit {
            rows.append(labelPrefix + String(
                format: localized("details.monthly", fallback: "Monthly limit: %@ remaining (%@ / %@ used)"),
                formatPercent(individualLimit.remainingPercent),
                individualLimit.used,
                individualLimit.limit
            ))
        }
        if let reachedType {
            rows.append(labelPrefix + String(format: localized("details.reached", fallback: "Limit status: %@"), localizedReachedType(reachedType)))
        }
    }

    private func localizedReachedType(_ type: String) -> String {
        switch type {
        case "rate_limit_reached": return localized("reached.rate", fallback: "rate limit reached")
        case "workspace_owner_credits_depleted": return localized("reached.ownerCredits", fallback: "workspace credits depleted")
        case "workspace_member_credits_depleted": return localized("reached.memberCredits", fallback: "member credits depleted")
        case "workspace_owner_usage_limit_reached": return localized("reached.ownerUsage", fallback: "workspace usage limit reached")
        case "workspace_member_usage_limit_reached": return localized("reached.memberUsage", fallback: "member usage limit reached")
        default: return type.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func updateShowRingsMenuItem() {
        showRingsItem?.state = ringsVisible ? .on : .off
    }

    private func updateNotificationsMenuItem() {
        notificationsItem?.state = notificationsEnabled ? .on : .off
    }

    private func updateRingVisibility() {
        updateShowRingsMenuItem()
        if ringsVisible, currentPetFrameAppKit != nil {
            panel.orderFrontRegardless()
            updateTooltip(at: NSEvent.mouseLocation)
        } else {
            ringView.showsReadout = false
            panel.orderOut(nil)
        }
    }

    private func setRingsVisible(_ visible: Bool) {
        ringsVisible = visible
        UserDefaults.standard.set(visible, forKey: ringsVisibleDefaultsKey)
        updateRingVisibility()
    }

    @objc private func toggleRings(_ sender: NSMenuItem) {
        setRingsVisible(!ringsVisible)
    }

    @objc private func toggleNotifications(_ sender: NSMenuItem) {
        if notificationsEnabled {
            notificationsEnabled = false
            notificationBands.removeAll()
            UserDefaults.standard.set(false, forKey: notificationsEnabledDefaultsKey)
            UserDefaults.standard.removeObject(forKey: notificationBandsDefaultsKey)
            updateNotificationsMenuItem()
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.notificationsEnabled = granted
                self.notificationBands.removeAll()
                UserDefaults.standard.set(granted, forKey: notificationsEnabledDefaultsKey)
                UserDefaults.standard.removeObject(forKey: notificationBandsDefaultsKey)
                self.updateNotificationsMenuItem()
                if granted {
                    self.processNotifications(for: self.ringView.state)
                }
            }
        }
    }

    private func processNotifications(for state: LimitState) {
        guard notificationsEnabled else { return }
        let isFresh = state.source == "app-server" && currentFullSnapshotFreshness() == .current
        guard isFresh else { return }
        notificationBands = pruningNotificationBands(
            notificationBands,
            activeIDs: activeLimitNotificationIDs(in: state)
        )
        var measurements: [(id: String, name: String, remaining: Double)] = []
        if let primary = state.primary {
            measurements.append(("codex.primary", localized("limit.short", fallback: "Short window"), primary.remainingPercent))
        }
        if let secondary = state.secondary {
            measurements.append(("codex.secondary", localized("limit.weekly", fallback: "Weekly window"), secondary.remainingPercent))
        }
        for limit in state.additional {
            if let primary = limit.primary {
                measurements.append(("\(limit.id).primary", limit.name, primary.remainingPercent))
            }
            if let secondary = limit.secondary {
                measurements.append(("\(limit.id).secondary", "\(limit.name) · \(localized("limit.secondary", fallback: "secondary"))", secondary.remainingPercent))
            }
        }

        for measurement in measurements {
            let previous = notificationBands[measurement.id].flatMap(LimitNotificationBand.init(rawValue:))
            let transition = limitNotificationTransition(
                previousBand: previous,
                remainingPercent: measurement.remaining,
                limitName: measurement.name,
                isFresh: isFresh
            )
            notificationBands[measurement.id] = transition.band.rawValue
            if let event = transition.event {
                sendNotification(event, identifier: measurement.id)
            }
        }
        UserDefaults.standard.set(notificationBands, forKey: notificationBandsDefaultsKey)
    }

    private func sendNotification(_ event: LimitNotificationEvent, identifier: String) {
        let content = UNMutableNotificationContent()
        switch event.kind {
        case .low:
            content.title = localized("notification.low.title", fallback: "Codex limit is getting low")
            content.body = String(
                format: localized("notification.low.body", fallback: "%@ has %@ remaining."),
                event.limitName,
                formatPercent(event.remainingPercent)
            )
        case .critical:
            content.title = localized("notification.critical.title", fallback: "Codex limit is critical")
            content.body = String(
                format: localized("notification.critical.body", fallback: "%@ has only %@ remaining."),
                event.limitName,
                formatPercent(event.remainingPercent)
            )
        case .recovered:
            content.title = localized("notification.recovered.title", fallback: "Codex limit recovered")
            content.body = String(
                format: localized("notification.recovered.body", fallback: "%@ is back to %@ remaining."),
                event.limitName,
                formatPercent(event.remainingPercent)
            )
        }
        content.sound = .default
        let requestID = "codex-pet-limit-rings.\(identifier).\(event.kind).\(Int(Date().timeIntervalSince1970))"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: requestID, content: content, trigger: nil))
    }

    @objc private func refreshNow(_ sender: NSMenuItem) {
        let snapshotIsStale = currentFullSnapshotFreshness() != .current
        usageReadInFlight = true
        updateDailyUsageMenu()
        liveClient.requestManualRateLimits(snapshotIsStale: snapshotIsStale)
        updateFrame()
        updateRingVisibility()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    private func installDragFollow() {
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.beginDragFollowIfNeeded(at: NSEvent.mouseLocation)
            }
        }
        mouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.continueDragFollow(at: NSEvent.mouseLocation)
            }
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.endDragFollow()
            }
        }
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateTooltip(at: NSEvent.mouseLocation)
            }
        }
    }

    private func beginDragFollowIfNeeded(at mouse: CGPoint) {
        guard ringsVisible else { return }
        updateFrame()
        guard isLikelyPetDragStart(at: mouse) else { return }
        guard let petFrame = currentPetFrameAppKit,
              let overlayFrame = currentPetOverlayFrameAppKit else { return }
        dragMouseToPetOriginOffsetAppKit = CGPoint(x: petFrame.minX - mouse.x, y: petFrame.minY - mouse.y)
        dragMouseToOverlayOriginOffsetAppKit = CGPoint(x: overlayFrame.minX - mouse.x, y: overlayFrame.minY - mouse.y)
        isTrackingMouseDrag = true
        holdDraggedFrameUntil = nil
        startDragFollowTimer()
        updateDragFrame(at: mouse)
        ringView.showsReadout = false
    }

    private func continueDragFollow(at mouse: CGPoint) {
        if !isTrackingMouseDrag {
            beginDragFollowIfNeeded(at: mouse)
        }
        guard isTrackingMouseDrag else { return }
        guard isPrimaryMouseButtonPressed() else {
            endDragFollow()
            return
        }
        updateDragFrame(at: mouse)
        ringView.showsReadout = false
    }

    private func endDragFollow() {
        guard isTrackingMouseDrag else { return }
        isTrackingMouseDrag = false
        dragMouseToPetOriginOffsetAppKit = nil
        dragMouseToOverlayOriginOffsetAppKit = nil
        stopDragFollowTimer()
        holdDraggedFrameUntil = Date().addingTimeInterval(0.18)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { [weak self] in
            self?.updateFrame()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateFrame()
        }
    }

    private func isPrimaryMouseButtonPressed() -> Bool {
        (NSEvent.pressedMouseButtons & 1) != 0
    }

    private func updateDragFrame(at mouse: CGPoint) {
        guard isTrackingMouseDrag else { return }
        guard isPrimaryMouseButtonPressed() else {
            endDragFollow()
            return
        }

        let predictedPetFrame = predictedDragPetFrame(at: mouse)
        let predictedOverlayFrame = predictedDragOverlayFrame(at: mouse)
        let liveReference = predictedOverlayFrame.flatMap { topLeftRectFromAppKit($0) } ?? currentPetOverlayTopLeft

        if let petFrames = frameReader.readPetFramesTopLeft(preferLiveOverlay: true, liveReference: liveReference),
           petFrames.usedLiveOverlay {
            let livePetFrame = appKitRectFromTopLeft(petFrames.mascot)
            if let predictedPetFrame {
                guard petDragLiveFrameIsClose(livePetFrame, to: predictedPetFrame) else {
                    applyPredictedDragFrame(petFrame: predictedPetFrame, overlayFrame: predictedOverlayFrame)
                    ringView.showsReadout = false
                    return
                }
            }
            applyPetFrames(petFrames)
            ringView.showsReadout = false
            return
        }

        if let predictedPetFrame {
            applyPredictedDragFrame(petFrame: predictedPetFrame, overlayFrame: predictedOverlayFrame)
        }
        ringView.showsReadout = false
    }

    private func predictedDragPetFrame(at mouse: CGPoint) -> CGRect? {
        guard let currentPetFrameAppKit,
              let offset = dragMouseToPetOriginOffsetAppKit else {
            return nil
        }
        return CGRect(
            x: mouse.x + offset.x,
            y: mouse.y + offset.y,
            width: currentPetFrameAppKit.width,
            height: currentPetFrameAppKit.height
        )
    }

    private func predictedDragOverlayFrame(at mouse: CGPoint) -> CGRect? {
        guard let currentPetOverlayFrameAppKit,
              let offset = dragMouseToOverlayOriginOffsetAppKit else {
            return nil
        }
        return CGRect(
            x: mouse.x + offset.x,
            y: mouse.y + offset.y,
            width: currentPetOverlayFrameAppKit.width,
            height: currentPetOverlayFrameAppKit.height
        )
    }

    private func applyPredictedDragFrame(petFrame: CGRect, overlayFrame: CGRect?) {
        currentPetFrameAppKit = petFrame
        if let overlayFrame {
            currentPetOverlayFrameAppKit = overlayFrame
            currentPetOverlayTopLeft = topLeftRectFromAppKit(overlayFrame)
        }
        setPanelFrame(forPetFrameAppKit: petFrame)
        if ringsVisible {
            panel.orderFrontRegardless()
        }
    }

    private func startDragFollowTimer() {
        guard dragFollowTimer == nil else { return }
        let timer = Timer(timeInterval: dragFollowInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isTrackingMouseDrag, self.isPrimaryMouseButtonPressed() else {
                self.endDragFollow()
                return
            }
            self.updateDragFrame(at: NSEvent.mouseLocation)
        }
        dragFollowTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopDragFollowTimer() {
        dragFollowTimer?.invalidate()
        dragFollowTimer = nil
    }

    private func isLikelyPetDragStart(at mouse: CGPoint) -> Bool {
        if let overlay = currentPetOverlayFrameAppKit,
           overlay.insetBy(dx: -4, dy: -4).contains(mouse) {
            return true
        }
        if let petFrame = currentPetFrameAppKit,
           petFrame.insetBy(dx: -24, dy: -24).contains(mouse) {
            return true
        }
        return panel.frame.insetBy(dx: -4, dy: -4).contains(mouse)
    }

    private func updateTooltip(at mouse: CGPoint) {
        if !ringsVisible || currentPetFrameAppKit == nil || isTrackingMouseDrag {
            ringView.showsReadout = false
            return
        }

        ringView.showsReadout = isHoveringRingOrPet(mouse)
    }

    private func isHoveringRingOrPet(_ mouse: CGPoint) -> Bool {
        if let petFrame = currentPetFrameAppKit,
           petFrame.insetBy(dx: -10, dy: -10).contains(mouse) {
            return true
        }

        let frame = panel.frame
        guard frame.insetBy(dx: -4, dy: -4).contains(mouse) else {
            return false
        }

        let local = CGPoint(x: mouse.x - frame.minX, y: mouse.y - frame.minY)
        let center = CGPoint(x: frame.width / 2, y: frame.height / 2)
        let distance = hypot(local.x - center.x, local.y - center.y)
        let radius = min(frame.width, frame.height) * 0.5 - 16.0
        return distance >= radius - 24.0 && distance <= radius + 19.0
    }

    private func appKitOriginFromTopLeft(_ topLeft: CGPoint, size: CGSize) -> CGPoint {
        let topLeftRect = CGRect(origin: topLeft, size: size)
        guard let screen = screenForTopLeftRect(topLeftRect) else {
            return CGPoint(x: topLeft.x, y: max(0, config.fallbackSize - topLeft.y))
        }

        let screenTopLeftFrame = topLeftFrame(for: screen)
        let localX = topLeft.x - screenTopLeftFrame.minX
        let localY = topLeft.y - screenTopLeftFrame.minY
        return CGPoint(x: screen.frame.minX + localX, y: screen.frame.maxY - localY - size.height)
    }

    private func appKitRectFromTopLeft(_ rect: CGRect) -> CGRect {
        guard let screen = screenForTopLeftRect(rect) else {
            return rect
        }

        let screenTopLeftFrame = topLeftFrame(for: screen)
        let localX = rect.minX - screenTopLeftFrame.minX
        let localY = rect.minY - screenTopLeftFrame.minY
        return CGRect(
            x: screen.frame.minX + localX,
            y: screen.frame.maxY - localY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    private func topLeftRectFromAppKit(_ rect: CGRect) -> CGRect? {
        guard let screen = screenForAppKitRect(rect) else {
            return nil
        }

        let screenTopLeftFrame = topLeftFrame(for: screen)
        let localX = rect.minX - screen.frame.minX
        let localY = screen.frame.maxY - rect.maxY
        return CGRect(
            x: screenTopLeftFrame.minX + localX,
            y: screenTopLeftFrame.minY + localY,
            width: rect.width,
            height: rect.height
        )
    }

    private func screenForTopLeftRect(_ rect: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let screen = screens.first(where: { topLeftFrame(for: $0).contains(center) }) {
            return screen
        }

        return screens.min {
            distanceSquared(center, to: topLeftFrame(for: $0)) < distanceSquared(center, to: topLeftFrame(for: $1))
        }
    }

    private func screenForAppKitRect(_ rect: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let screen = screens.first(where: { $0.frame.contains(center) }) {
            return screen
        }

        return screens.min {
            distanceSquared(center, to: $0.frame) < distanceSquared(center, to: $1.frame)
        }
    }

    private func topLeftFrame(for screen: NSScreen) -> CGRect {
        let primaryMaxY = (primaryScreen() ?? NSScreen.screens.first)?.frame.maxY ?? screen.frame.maxY
        return CGRect(
            x: screen.frame.minX,
            y: primaryMaxY - screen.frame.maxY,
            width: screen.frame.width,
            height: screen.frame.height
        )
    }

    private func primaryScreen() -> NSScreen? {
        NSScreen.screens.first { abs($0.frame.minX) < 0.5 && abs($0.frame.minY) < 0.5 }
    }

    private func distanceSquared(_ point: CGPoint, to rect: CGRect) -> CGFloat {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let dx = point.x - clampedX
        let dy = point.y - clampedY
        return dx * dx + dy * dy
    }

    private func formatPercent(_ percent: Double) -> String {
        if abs(percent.rounded() - percent) < 0.05 {
            return "\(Int(percent.rounded()))%"
        }
        return String(format: "%.1f%%", percent)
    }
}

func renderPreview(config: LimitRingsConfig) -> Bool {
    let state = LimitStateReader(
        logsPath: config.logsPath,
        codexHome: config.codexHome
    ).readLatest()
    let size = CGSize(width: config.fallbackSize, height: config.fallbackSize)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()
    LimitRingRenderer(
        state: state,
        phase: 0.18,
        showsReadout: true,
        accessibility: .current
    ).draw(in: CGRect(origin: .zero, size: size))
    image.unlockFocus()

    guard let previewPath = config.previewPath,
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        return false
    }

    do {
        try FileManager.default.createDirectory(at: previewPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: previewPath)
        return true
    } catch {
        fputs("codex-pet-limit-rings: could not write preview: \(error)\n", stderr)
        return false
    }
}

func parseConfig() -> LimitRingsConfig? {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let codexHome = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CODEX_HOME"] ?? home.appendingPathComponent(".codex").path)
    var config = LimitRingsConfig(
        codexHome: codexHome,
        globalStatePath: codexHome.appendingPathComponent(".codex-global-state.json"),
        logsPath: defaultLogsPath(codexHome: codexHome),
        previewPath: nil
    )

    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "--help", "-h":
            print("""
            Usage: codex-pet-limit-rings [--preview PATH] [--diagnose] [--codex-home PATH] [--logs PATH] [--auth PATH] [--state PATH]

            Draws a transparent Codex rate-limit rings around the current pet.
            --diagnose prints privacy-safe compatibility information as JSON.
            --auth is accepted for compatibility but is no longer read.
            """)
            exit(0)
        case "--diagnose":
            config.diagnose = true
        case "--preview":
            guard let value = args.first else { return nil }
            args.removeFirst()
            config.previewPath = URL(fileURLWithPath: value)
        case "--codex-home":
            guard let value = args.first else { return nil }
            args.removeFirst()
            let url = URL(fileURLWithPath: value)
            config.codexHome = url
            config.globalStatePath = url.appendingPathComponent(".codex-global-state.json")
            config.logsPath = defaultLogsPath(codexHome: url)
        case "--logs":
            guard let value = args.first else { return nil }
            args.removeFirst()
            config.logsPath = URL(fileURLWithPath: value)
        case "--auth":
            guard args.first != nil else { return nil }
            args.removeFirst()
        case "--state":
            guard let value = args.first else { return nil }
            args.removeFirst()
            config.globalStatePath = URL(fileURLWithPath: value)
        case "--size":
            guard let value = args.first, let size = Double(value) else { return nil }
            args.removeFirst()
            config.fallbackSize = CGFloat(size)
        default:
            fputs("codex-pet-limit-rings: unknown argument \(arg)\n", stderr)
            return nil
        }
    }

    return config
}

func defaultLogsPath(codexHome: URL) -> URL {
    if let logs2 = newestExistingPath([
        codexHome.appendingPathComponent("sqlite/logs_2.sqlite"),
        codexHome.appendingPathComponent("logs_2.sqlite")
    ]) {
        return logs2
    }
    if let logs1 = newestExistingPath([
        codexHome.appendingPathComponent("sqlite/logs_1.sqlite"),
        codexHome.appendingPathComponent("logs_1.sqlite")
    ]) {
        return logs1
    }

    return codexHome.appendingPathComponent("logs_1.sqlite")
}

private func newestExistingPath(_ candidates: [URL]) -> URL? {
    candidates
        .filter { FileManager.default.fileExists(atPath: $0.path) }
        .max {
            modificationDate(for: $0) < modificationDate(for: $1)
        }
}

private func modificationDate(for url: URL) -> Date {
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes?[.modificationDate] as? Date) ?? .distantPast
}

private struct CompatibilityDiagnostics: Encodable {
    var appVersion: String
    var codexAppRunning: Bool
    var codexAppVersion: String?
    var codexCLI: String
    var codexCLIVersion: String?
    var appServer: String
    var appServerError: String?
    var appServerFailureReason: String?
    var rateLimitFreshness: String
    var usageFreshness: String
    var globalStateExists: Bool
    var avatarOverlayOpen: Bool?
    var petFrameReadable: Bool
    var primaryLimitAvailable: Bool
    var secondaryLimitAvailable: Bool
    var additionalLimitCount: Int
    var creditsAvailable: Bool
    var individualLimitAvailable: Bool
    var resetCreditsAvailable: Int64?
    var dailyUsageAvailable: Bool
    var dailyUsageBucketCount: Int
    var usageSummaryAvailable: Bool
    var longestStreakAvailable: Bool
    var longestTurnAvailable: Bool
    var notificationsEnabled: Bool
    var reduceMotion: Bool
    var increaseContrast: Bool
    var differentiateWithoutColor: Bool
}

func runDiagnostics(config: LimitRingsConfig) -> Bool {
    let probe = AppServerLimitStateReader(codexHome: config.codexHome).readResult()
    let usageProbe = AppServerAccountUsageReader(codexHome: config.codexHome).readLatest()
    let runningCodex = NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex").first
    let codexBundle = runningCodex?.bundleURL.flatMap { Bundle(url: $0) }
    let stateData = try? Data(contentsOf: config.globalStatePath)
    let stateRoot = stateData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    let avatarOpen: Bool?
    if let value = stateRoot?["electron-avatar-overlay-open"] as? Bool {
        avatarOpen = value
    } else if let value = stateRoot?["electron-avatar-overlay-open"] as? NSNumber {
        avatarOpen = value.boolValue
    } else {
        avatarOpen = nil
    }

    let accessibility = AccessibilityPresentation.current
    let diagnostics = CompatibilityDiagnostics(
        appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
        codexAppRunning: runningCodex != nil,
        codexAppVersion: codexBundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        codexCLI: codexCLISource(probe.cliPath),
        codexCLIVersion: probe.cliPath.flatMap { readCodexCLIVersion(at: $0) },
        appServer: probe.state == nil ? "unavailable" : "ready",
        appServerError: probe.errorCode,
        appServerFailureReason: connectionFailureReason(for: probe.errorCode)?.rawValue,
        rateLimitFreshness: dataFreshnessState(
            observedAt: probe.state?.observedAt,
            maxAge: rateLimitFreshnessMaxAge
        ).rawValue,
        usageFreshness: dataFreshnessState(
            observedAt: usageProbe.snapshot?.observedAt,
            maxAge: usageFreshnessMaxAge
        ).rawValue,
        globalStateExists: stateData != nil,
        avatarOverlayOpen: avatarOpen,
        petFrameReadable: PetFrameReader(globalStatePath: config.globalStatePath)
            .readPetFrameTopLeft(requireLiveOverlay: true) != nil,
        primaryLimitAvailable: probe.state?.primary != nil,
        secondaryLimitAvailable: probe.state?.secondary != nil,
        additionalLimitCount: probe.state?.additional.count ?? 0,
        creditsAvailable: probe.state?.credits?.hasCredits ?? false,
        individualLimitAvailable: probe.state?.individualLimit != nil,
        resetCreditsAvailable: probe.state?.resetCreditsAvailable,
        dailyUsageAvailable: usageProbe.snapshot != nil,
        dailyUsageBucketCount: usageProbe.snapshot?.buckets.count ?? 0,
        usageSummaryAvailable: usageProbe.snapshot?.summary != nil,
        longestStreakAvailable: usageProbe.snapshot?.summary?.longestStreakDays != nil,
        longestTurnAvailable: usageProbe.snapshot?.summary?.longestRunningTurnSec != nil,
        notificationsEnabled: UserDefaults.standard.bool(forKey: notificationsEnabledDefaultsKey),
        reduceMotion: accessibility.reduceMotion,
        increaseContrast: accessibility.increaseContrast,
        differentiateWithoutColor: accessibility.differentiateWithoutColor
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(diagnostics),
          let output = String(data: data, encoding: .utf8) else {
        return false
    }
    print(output)
    return true
}

private func codexCLISource(_ url: URL?) -> String {
    guard let path = url?.path else { return "not-found" }
    if path.contains("/ChatGPT.app/") { return "chatgpt-app-bundled" }
    if path.contains("/Codex.app/") { return "codex-app-bundled" }
    if path.hasPrefix("/opt/homebrew/") { return "homebrew-apple-silicon" }
    if path.hasPrefix("/usr/local/") { return "homebrew-intel-or-local" }
    return "configured-or-path"
}

#if !LIMIT_RINGS_TESTING
@main
struct LimitRingsMain {
    static func main() {
        guard let config = parseConfig() else {
            fputs("codex-pet-limit-rings: invalid arguments. Use --help.\n", stderr)
            exit(2)
        }

        if config.previewPath != nil {
            exit(renderPreview(config: config) ? 0 : 1)
        }

        if config.diagnose {
            exit(runDiagnostics(config: config) ? 0 : 1)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let rings = LimitRingsApp(config: config)
        rings.run()
        app.run()
    }
}
#endif
