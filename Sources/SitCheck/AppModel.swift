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

    // 카메라 자세 감지
    @Published private(set) var cameraStatus: CameraStatus = .off
    @Published private(set) var postureState: PostureState = .noFace
    @Published private(set) var lastSample: PostureSample?
    @Published private(set) var calibrating = false

    @Published var settings: AppSettings = .default {
        didSet {
            guard settings != oldValue else { return }
            tracker.awayThreshold = Double(settings.awayAfterMinutes) * 60
            persist { try $0.saveSettings(settings) }
            if settings.cameraEnabled != oldValue.cameraEnabled { updateCamera() }
            if settings.postureBaseline != oldValue.postureBaseline { posture.reset() }
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
    let camera = PostureCamera()
    private var posture = PostureMonitor()
    private var calibrationSamples: [PostureSample] = []
    private var calibrationEnds: Date?
    /// App Nap으로 타이머가 몇 분씩 밀리면 자리 비움을 놓치므로 끈다 (시스템 잠자기는 허용).
    private let activity = ProcessInfo.processInfo.beginActivity(
        options: .userInitiatedAllowingIdleSystemSleep, reason: "착석 시간 측정")

    static let tickInterval: TimeInterval = 5
    static let breathSignalSeconds: UInt64 = 60
    static let calibrationSeconds: TimeInterval = 3

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
        camera.onSample = { [weak self] sample in self?.handle(sample) }
        updateCamera()
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
            var idle = IdleMonitor.secondsSinceLastInput()
            // 입력 없이 읽거나 영상을 봐도 얼굴이 보이면 앉아 있는 것으로 본다.
            if cameraStatus == .running, let sinceFace = posture.secondsSinceFace(at: now) {
                idle = min(idle, sinceFace)
            }
            let closed = tracker.tick(now: now, idleSeconds: idle)
            if let closed {
                boutClosed(closed, at: now)
            } else if wasSitting, !tracker.isSitting {
                // 1분 미만이라 저장하지 않는 구간이어도 자리를 비운 것이므로 같은 처리를 한다.
                scheduler.boutEnded()
                if cardVisible { resolveCard(.expired) }
            }
        }
        refreshDisplay(now: now)

        let pendingPosture = cameraStatus == .running ? posture.pendingRule(at: now, settings: settings) : nil
        switch scheduler.evaluate(now: now, boutStart: tracker.boutStart, settings: settings, posture: pendingPosture) {
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
        if rule == .tiltRotation || rule == .screenApproach { posture.resetDeviation(at: now) }
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

    // MARK: - 카메라 자세 감지 (FR-08~11)

    var cameraStatusText: String {
        switch cameraStatus {
        case .off: return "카메라 꺼짐"
        case .starting: return "카메라 켜는 중…"
        case .running: return postureText
        case .denied: return "카메라 권한이 없어요. 시스템 설정 > 개인정보 보호 및 보안 > 카메라에서 허용해 주세요."
        case .unavailable(let reason): return reason
        }
    }

    private var postureText: String {
        if calibrating { return "기준 자세를 재는 중… 바르게 앉아 화면을 봐 주세요" }
        switch postureState {
        case .noBaseline: return "바른 자세 기준을 저장해 주세요"
        case .noFace: return "얼굴이 보이지 않아요"
        case .good: return "기준 자세와 비슷해요"
        case .tilted: return "고개가 기울거나 돌아가 있어요"
        case .approaching: return "화면 쪽으로 다가가 있어요"
        }
    }

    /// 기준 대비 현재 차이 (설정에서 임계값을 맞출 때 참고용)
    var postureDeltaText: String? {
        guard let sample = lastSample, let base = settings.postureBaseline, base.faceWidth > 0 else { return nil }
        let roll = Int((sample.roll - base.roll).rounded())
        let yaw = Int((sample.yaw - base.yaw).rounded())
        let distance = Int(((sample.faceWidth / base.faceWidth - 1) * 100).rounded())
        return "기울기 \(roll)° · 회전 \(yaw)° · 얼굴 크기 \(distance >= 0 ? "+" : "")\(distance)%"
    }

    private func updateCamera() {
        if settings.cameraEnabled && !screenLocked {
            guard cameraStatus != .running, cameraStatus != .starting else { return }
            cameraStatus = .starting
            camera.start { [weak self] status in
                guard let self else { return }
                // 켜는 사이에 설정을 끄거나 화면이 잠기면 바로 멈춘다.
                if status == .running, !self.settings.cameraEnabled || self.screenLocked {
                    self.camera.stop()
                    self.cameraStatus = .off
                } else {
                    self.cameraStatus = status
                }
            }
        } else {
            camera.stop()
            if cameraStatus == .running || cameraStatus == .starting { cameraStatus = .off }
            posture.reset()
            postureState = .noFace
            lastSample = nil
            calibrating = false
        }
    }

    func retryCamera() {
        cameraStatus = .off
        updateCamera()
    }

    /// 바르게 앉은 상태에서 몇 초간 샘플을 모아 기준으로 저장한다.
    func startCalibration() {
        guard cameraStatus == .running else {
            lastError = "카메라가 켜져 있어야 기준 자세를 저장할 수 있어요"
            return
        }
        calibrationSamples = []
        calibrationEnds = Date().addingTimeInterval(Self.calibrationSeconds)
        calibrating = true
    }

    private func handle(_ sample: PostureSample?) {
        guard cameraStatus == .running else { return }
        let now = Date()
        lastSample = sample
        if calibrating {
            if let sample { calibrationSamples.append(sample) }
            if let calibrationEnds, now >= calibrationEnds { finishCalibration(at: now) }
        }
        postureState = posture.update(sample, at: now, baseline: settings.postureBaseline, settings: settings)
    }

    private func finishCalibration(at now: Date) {
        calibrating = false
        calibrationEnds = nil
        if calibrationSamples.count >= 2, let baseline = PostureBaseline.from(calibrationSamples, at: now) {
            settings.postureBaseline = baseline
            lastError = nil
        } else {
            lastError = "얼굴이 잘 보이지 않아 기준을 저장하지 못했어요. 밝은 곳에서 다시 해 주세요."
        }
        calibrationSamples = []
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
        updateCamera()
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
        updateCamera()
        tick()
    }
}
