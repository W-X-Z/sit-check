import AppKit
import Combine
import SitCheckCore

/// 알림 카드 한 장의 상태. 동작별 좌우 기록과 증상을 모았다가 카드가 닫힐 때 저장한다.
@MainActor
final class CardSession: ObservableObject, Identifiable {
    struct Entry: Equatable {
        var side: Side?
        var symptom: Symptom = .none
    }

    let id = UUID()
    let rule: NudgeRule
    let shownAt: Date
    let stretches: [Stretch]
    let reason: String
    let actionLine: String

    @Published var entries: [String: Entry] = [:]
    /// nil이면 카드, 값이 있으면 해당 동작의 가이드 화면
    @Published var guide: Stretch?

    init(rule: NudgeRule, shownAt: Date, stretches: [Stretch], sittingMinutes: Int) {
        self.rule = rule
        self.shownAt = shownAt
        self.stretches = stretches
        self.reason = NudgeCopy.reason(rule: rule, sittingMinutes: sittingMinutes)
        self.actionLine = NudgeCopy.action(for: stretches)
    }

    var allSidesRecorded: Bool {
        stretches.allSatisfy { entries[$0.id]?.side != nil }
    }
}

struct TightnessItem: Identifiable {
    let stretch: Stretch
    let index: Double
    let count: Int
    var id: String { stretch.id }
}

@MainActor
final class AppModel: ObservableObject {
    // 메뉴바 표시
    @Published private(set) var isSitting = false
    @Published private(set) var sittingMinutes = 0
    @Published private(set) var breathing = false
    @Published private(set) var mutedUntil: Date?
    @Published private(set) var cardVisible = false

    // 메뉴 요약
    @Published private(set) var completionRate7d: Double?
    @Published private(set) var nudgeCount7d = 0
    @Published private(set) var tightness: [TightnessItem] = []
    @Published private(set) var clinicAdvice = false
    @Published private(set) var lastError: String?

    @Published var settings: AppSettings = .default {
        didSet {
            guard settings != oldValue else { return }
            tracker.awayThreshold = Double(settings.awayAfterMinutes) * 60
            persist { try $0.saveSettings(settings) }
        }
    }

    private var store: Store?
    private var tracker: SitTracker
    private var scheduler = NudgeScheduler()
    private let prescriber = Prescriber()
    private let panel = NudgePanelController()
    private var session: CardSession?
    private var timer: Timer?
    private var breathOffTask: Task<Void, Never>?
    private var screenLocked = false
    private var observers: [NSObjectProtocol] = []
    /// App Nap으로 타이머가 몇 분씩 밀리면 자리 비움을 놓치므로 끈다 (시스템 잠자기는 허용).
    private let activity = ProcessInfo.processInfo.beginActivity(
        options: .userInitiatedAllowingIdleSystemSleep, reason: "착석 시간 측정")

    static let tickInterval: TimeInterval = 5
    static let breathSignalSeconds: UInt64 = 60

    init() {
        tracker = SitTracker(awayThreshold: Double(AppSettings.default.awayAfterMinutes) * 60)
        do {
            let store = try Store(path: Store.defaultURL().path)
            self.store = store
            settings = try store.loadSettings()
            tracker.awayThreshold = Double(settings.awayAfterMinutes) * 60
        } catch {
            lastError = "저장소를 열지 못했어요: \(error)"
        }
        observeSystemEvents()
        refreshStats()
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    // MARK: - 상태 표시

    var statusSymbol: String {
        if breathing { return "wind" }
        if isMuted { return "moon.zzz" }
        if !isSitting { return "pause.circle" }
        if cardVisible || sittingMinutes >= settings.sitAlertMinutes { return "exclamationmark.circle.fill" }
        return "timer"
    }

    var isMuted: Bool { scheduler.isMuted(at: Date()) }

    // MARK: - 주기 처리

    private func tick(now: Date = Date()) {
        if !screenLocked {
            let wasSitting = tracker.isSitting
            let closed = tracker.tick(now: now, idleSeconds: IdleMonitor.secondsSinceLastInput())
            if let closed {
                boutClosed(closed, at: now)
            } else if wasSitting, !tracker.isSitting {
                // 1분 미만이라 저장하지 않는 구간이어도 자리를 비운 것이므로 같은 처리를 한다.
                scheduler.boutEnded()
                if cardVisible { resolveCard(.expired) }
            }
        }
        refreshDisplay(now: now)

        switch scheduler.evaluate(now: now, boutStart: tracker.boutStart, settings: settings) {
        case .showCard(let rule)?:
            showCard(rule: rule, at: now)
        case .breath?:
            signalBreath()
        case nil:
            break
        }
    }

    private func refreshDisplay(now: Date) {
        isSitting = tracker.isSitting
        sittingMinutes = Int(tracker.sittingSeconds(at: now) / 60)
        mutedUntil = scheduler.isMuted(at: now) ? scheduler.mutedUntil : nil
    }

    private func boutClosed(_ bout: SitBout, at now: Date) {
        persist { try $0.insert(bout) }
        scheduler.boutEnded()
        if cardVisible { resolveCard(.expired) }
    }

    private func signalBreath() {
        breathing = true
        breathOffTask?.cancel()
        breathOffTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.breathSignalSeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.breathing = false
        }
    }

    // MARK: - 알림 카드

    /// 메뉴의 "지금 스트레칭"에서도 호출한다.
    func showCard(rule: NudgeRule = .longSitting, at now: Date = Date()) {
        guard session == nil else {
            panel.bringToFront()
            return
        }
        let history = (try? store?.recentPrescriptions()) ?? []
        let stretches = prescriber.prescribe(rule: rule, history: history, excluded: settings.excludedStretchIDs)
        let session = CardSession(rule: rule, shownAt: now, stretches: stretches,
                                  sittingMinutes: Int(tracker.sittingSeconds(at: now) / 60))
        self.session = session
        scheduler.cardShown(rule, at: now)
        cardVisible = true
        breathing = false
        panel.show(NudgeCardView(session: session, model: self))
    }

    func record(side: Side, for stretch: Stretch, in session: CardSession) {
        session.entries[stretch.id, default: .init()].side = side
        // NFR-07: 두 동작 모두 좌우를 기록하면 완료 처리 (탭 2회)
        if session.allSidesRecorded {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard let self, self.session === session else { return }
                self.resolveCard(.done)
            }
        }
    }

    func record(symptom: Symptom, for stretch: Stretch, in session: CardSession) {
        let current = session.entries[stretch.id]?.symptom
        session.entries[stretch.id, default: .init()].symptom = current == symptom ? .none : symptom
    }

    func resolveCard(_ action: NudgeAction) {
        guard let session else { return }
        let now = Date()
        persist { store in
            let nudgeID = try store.insert(NudgeRecord(at: session.shownAt, rule: session.rule,
                                                       stretchIDs: session.stretches.map(\.id), action: action))
            for stretch in session.stretches {
                guard let entry = session.entries[stretch.id], entry.side != nil || entry.symptom != .none else { continue }
                try store.insert(StretchLog(at: now, stretchID: stretch.id, tighterSide: entry.side,
                                            symptom: entry.symptom, nudgeID: nudgeID))
            }
        }

        // FR-14: 통증·저림을 기록한 동작은 처방에서 뺀다.
        let painful = session.entries.filter { $0.value.symptom != .none }.map(\.key)
        if !painful.isEmpty {
            settings.excludedStretchIDs.formUnion(painful)
        }

        scheduler.cardResolved(action, at: now, settings: settings)
        if action == .done, let bout = tracker.restart(at: now) {
            persist { try $0.insert(bout) }
            scheduler.boutEnded()
        }
        self.session = nil
        cardVisible = false
        panel.close()
        refreshStats()
        refreshDisplay(now: now)
    }

    // MARK: - 메뉴 동작

    func muteForAWhile() {
        scheduler.mute(at: Date(), settings: settings)
        mutedUntil = scheduler.mutedUntil
    }

    func unmute() {
        scheduler.unmute()
        mutedUntil = nil
    }

    func restartTimer() {
        if let bout = tracker.restart(at: Date()) {
            persist { try $0.insert(bout) }
        }
        scheduler.boutEnded()
        tick()
    }

    func exportCSV() {
        guard let store else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmm"
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SitCheck-export-\(fmt.string(from: Date()))", isDirectory: true)
        do {
            try store.exportCSV(to: dir)
            NSWorkspace.shared.activateFileViewerSelecting([dir])
        } catch {
            lastError = "내보내기 실패: \(error)"
        }
    }

    func deleteAllRecords() {
        persist { try $0.deleteAllRecords() }
        refreshStats()
    }

    // MARK: - 요약

    func refreshStats(now: Date = Date()) {
        guard let store else { return }
        do {
            let nudges = try store.nudges(since: now.addingTimeInterval(-7 * 86_400))
            nudgeCount7d = nudges.filter { $0.rule != .breath }.count
            completionRate7d = Metrics.completionRate(nudges)
            let logs = try store.stretchLogs(since: now.addingTimeInterval(-14 * 86_400))
            tightness = StretchLibrary.all.compactMap { s in
                Metrics.tightnessIndex(logs, stretchID: s.id, now: now).map { TightnessItem(stretch: s, index: $0.index, count: $0.count) }
            }
            clinicAdvice = Metrics.needsClinicAdvice(logs, now: now)
        } catch {
            lastError = "\(error)"
        }
    }

    private func persist(_ work: (Store) throws -> Void) {
        guard let store else { return }
        do { try work(store) } catch { lastError = "\(error)" }
    }

    // MARK: - 화면 잠금, 잠자기 (NFR-06)

    private func observeSystemEvents() {
        let dnc = DistributedNotificationCenter.default()
        observers.append(dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleAway() }
        })
        observers.append(dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleBack() }
        })
        let wnc = NSWorkspace.shared.notificationCenter
        observers.append(wnc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleAway() }
        })
        observers.append(wnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleBack() }
        })
    }

    private func handleAway() {
        screenLocked = true
        let now = Date()
        if let bout = tracker.markAway(at: now) {
            boutClosed(bout, at: now)
        } else {
            scheduler.boutEnded()
            if cardVisible { resolveCard(.expired) }
        }
        tick(now: now)
    }

    private func handleBack() {
        screenLocked = false
        tick()
    }
}
