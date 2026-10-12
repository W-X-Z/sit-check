import AppKit
import Combine
import SitCheckCore

/// 알림 카드 한 장의 상태
@MainActor
final class CardSession: ObservableObject, Identifiable {
    let id = UUID()
    let rule: NudgeRule
    let shownAt: Date
    let stretches: [Stretch]
    let reason: String
    let actionLine: String
    /// 카메라 카드면 그 신호
    let event: SignalEvent?

    /// nil이면 카드, 값이 있으면 해당 동작의 가이드 화면
    @Published var guide: Stretch?

    init(rule: NudgeRule, shownAt: Date, stretches: [Stretch], sittingMinutes: Int, event: SignalEvent? = nil) {
        self.rule = rule
        self.shownAt = shownAt
        self.stretches = stretches
        self.event = event
        if let event {
            let copy = NudgeCopy.posture(event, sittingMinutes: sittingMinutes)
            self.reason = copy.reason
            self.actionLine = copy.action
        } else {
            self.reason = NudgeCopy.reason(rule: rule, sittingMinutes: sittingMinutes)
            self.actionLine = NudgeCopy.action(for: stretches)
        }
    }

    var isPostureCard: Bool { rule.isPostureCard }
}

@MainActor
final class AppModel: ObservableObject {
    // 착석
    @Published private(set) var isSitting = false
    @Published private(set) var sittingMinutes = 0
    @Published private(set) var mutedUntil: Date?
    @Published private(set) var cardVisible = false
    @Published private(set) var lastError: String?

    // 카메라
    @Published private(set) var cameraStatus: CameraStatus = .off
    @Published private(set) var lastSample: PostureSample?
    @Published private(set) var pose: PosePoints?
    @Published private(set) var stillMinutes: Double?
    @Published private(set) var setupChangeSuspected = false

    // 바른 자세 판정
    @Published private(set) var postureReading: PostureReading?
    @Published private(set) var postureIssues: Set<PostureIssue> = []
    @Published private(set) var badPostureSince: Date?
    @Published private(set) var uprightReference: UprightReference?

    @Published var settings: AppSettings = .default {
        didSet { settingsChanged(from: oldValue) }
    }

    private var store: Store?
    private var tracker: SitTracker
    private var scheduler = NudgeScheduler()
    private let prescriber = Prescriber()
    private let panel = NudgePanelController()
    private var session: CardSession?
    private var timer: Timer?
    private var screenLocked = false
    private var observers: [NSObjectProtocol] = []
    let camera = PostureCamera()
    /// 얼굴이 마지막으로 보인 시각 (입력이 없어도 앉아 있는지 판단)
    private var faceMonitor = PostureMonitor()
    private var aggregator = MinuteAggregator()
    private var signals = PostureSignals()
    private var setupDetector = SetupChangeDetector()
    private var autoBaseline: AutoBaseline?
    private var checker = PostureChecker()
    /// 거북목 기준을 만드는 '자리 잡은' 분들 (최근 14일)
    private var settledMinutes: [PostureMinute] = []
    private var gate = DeliveryGate()
    private var pendingStill: SignalEvent?
    /// 전달 시점을 기다리고 있는 카메라 카드
    private var waitingPostureRule: NudgeRule?
    /// 기록을 남긴 '바르지 않은 자세' 구간의 시작 (한 구간에 한 번만 기록)
    private var recordedBadSince: Date?
    private var lastBaselineRefresh = Date.distantPast
    /// App Nap으로 타이머가 몇 분씩 밀리면 자리 비움을 놓치므로 끈다 (시스템 잠자기는 허용).
    private let activity = ProcessInfo.processInfo.beginActivity(
        options: .userInitiatedAllowingIdleSystemSleep, reason: "착석 시간 측정")

    static let tickInterval: TimeInterval = 5

    init() {
        tracker = SitTracker(awayThreshold: Double(AppSettings.default.awayAfterMinutes) * 60)
        do {
            let store = try Store(path: Store.defaultURL().path)
            self.store = store
            settings = try store.loadSettings()
        } catch {
            lastError = "저장소를 열지 못했어요: \(error)"
        }
        applyAppDefaults()
        tracker.awayThreshold = Double(settings.awayAfterMinutes) * 60
        signals = PostureSignals(params: settings.signals, noise: .defaults, distance: nil)
        checker.params = settings.postureCheck
        observeSystemEvents()
        camera.onFrame = { [weak self] frame in self?.handle(frame) }
        refreshBaseline()
        updateCamera()
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    // MARK: - 설정

    /// 화면에 없는 기능은 끄고, 카메라 신호는 기록만 하지 않고 카드로 띄운다. 골격 인식은 늘 켠다.
    /// 예전 버전에서 저장한 설정에도 그대로 적용한다.
    private func applyAppDefaults() {
        var s = settings
        s.breathEnabled = false
        s.checkInsPerDay = 0
        s.iconOnlyPercent = 0
        s.postureAlertMode = .cards
        s.analysisMode = .faceBody
        s.distanceCalibration = nil
        guard s != settings else { return }
        settings = s
        persist { try $0.saveSettings(s) }
    }

    private func settingsChanged(from old: AppSettings) {
        guard settings != old else { return }
        tracker.awayThreshold = Double(settings.awayAfterMinutes) * 60
        persist { try $0.saveSettings(settings) }
        if settings.cameraEnabled != old.cameraEnabled { updateCamera() }
        signals.params = settings.signals
        if settings.postureCheck != old.postureCheck {
            checker.params = settings.postureCheck
            checker.reset()
            publishPosture()
        }
    }

    // MARK: - 상태 표시

    var statusSymbol: String {
        if isMuted { return "moon.zzz" }
        if !isSitting { return "pause.circle" }
        if cardVisible || sittingMinutes >= settings.sitAlertMinutes { return "exclamationmark.circle.fill" }
        if isPostureBad { return "exclamationmark.triangle" }
        return "timer"
    }

    /// 지금 자세가 바르지 않은지 (메뉴바 아이콘을 바로 바꾼다)
    var isPostureBad: Bool { isSitting && cameraStatus == .running && !postureIssues.isEmpty }

    var isMuted: Bool { scheduler.isMuted(at: Date()) }

    // MARK: - 주기 처리

    private func tick(now: Date = Date()) {
        if !screenLocked {
            let wasSitting = tracker.isSitting
            var idle = IdleMonitor.secondsSinceLastInput()
            // 입력 없이 읽거나 영상을 봐도 얼굴이 보이면 앉아 있는 것으로 본다.
            if cameraStatus == .running, let sinceFace = faceMonitor.secondsSinceFace(at: now) {
                idle = min(idle, sinceFace)
            }
            if let closed = tracker.tick(now: now, idleSeconds: idle) {
                boutClosed(closed)
            } else if wasSitting, !tracker.isSitting {
                // 1분 미만이라 저장하지 않는 구간이어도 자리를 비운 것이므로 같은 처리를 한다.
                scheduler.boutEnded()
                checker.reset()
                if cardVisible { resolveCard(.expired) }
            }
        }
        refreshDisplay(now: now)

        let candidate = postureCandidate(at: now)
        if let waiting = waitingPostureRule, waiting != candidate?.rule { gate.cancel(waiting.rawValue) }
        waitingPostureRule = candidate?.rule

        switch scheduler.evaluate(now: now, boutStart: tracker.boutStart, settings: settings, posture: candidate?.rule) {
        case .showCard(let rule)?:
            if gate.shouldDeliver(rule.rawValue, now: now, idleSeconds: IdleMonitor.secondsSinceLastInput(),
                                  inCall: CallDetector.inCall()) {
                let event = rule.isPostureCard ? candidate : nil
                if rule == .stillness { pendingStill = nil }
                if rule.isPostureCard { waitingPostureRule = nil }
                showCard(rule: rule, at: now, event: event)
            }
        case .breath?, nil:
            gate.cancelAll()
            waitingPostureRule = nil
        }
    }

    /// 지금 띄울 수 있는 카메라 카드 하나. 바른 자세 판정(R9·R10)이 오래 같은 자세(R5)보다 앞선다.
    /// 자리가 바뀐 것 같으면 기준 자세와 비교하는 거북목과 R5는 멈추고, 수평과 비교하는 좌우는 계속 본다.
    private func postureCandidate(at now: Date) -> SignalEvent? {
        if let pending = pendingStill, !signals.isActive(pending.rule, at: now) { pendingStill = nil }
        guard isSitting, cameraStatus == .running else { return nil }
        let excluded: Set<PostureIssue> = setupChangeSuspected ? [.forwardHead] : []
        if let event = checker.cardEvent(at: now, excluding: excluded) {
            if recordedBadSince != checker.badSince {
                recordedBadSince = checker.badSince
                persist {
                    try $0.insert(PostureEventRecord(at: now, rule: event.rule, variant: event.variant,
                                                     mode: settings.postureAlertMode, actionable: true,
                                                     detail: event.detail))
                }
            }
            return event
        }
        return setupChangeSuspected ? nil : pendingStill
    }

    private func refreshDisplay(now: Date) {
        isSitting = tracker.isSitting
        sittingMinutes = Int(tracker.sittingSeconds(at: now) / 60)
        mutedUntil = scheduler.isMuted(at: now) ? scheduler.mutedUntil : nil
        stillMinutes = signals.stillMinutes(at: now)
    }

    private func boutClosed(_ bout: SitBout) {
        persist { try $0.insert(bout) }
        scheduler.boutEnded()
        checker.reset()
        publishPosture()
        if cardVisible { resolveCard(.expired) }
    }

    // MARK: - 알림 카드

    /// 메뉴의 "지금 스트레칭"에서도 호출한다.
    func showCard(rule: NudgeRule = .longSitting, at now: Date = Date(), event: SignalEvent? = nil) {
        guard session == nil else {
            panel.bringToFront()
            return
        }
        let history = (try? store?.recentPrescriptions()) ?? []
        let stretches = prescriber.prescribe(rule: rule, history: history, excluded: settings.excludedStretchIDs)
        let session = CardSession(rule: rule, shownAt: now, stretches: stretches,
                                  sittingMinutes: Int(tracker.sittingSeconds(at: now) / 60), event: event)
        self.session = session
        scheduler.cardShown(rule, at: now)
        cardVisible = true
        panel.show(NudgeCardView(session: session, model: self))
    }

    func resolveCard(_ action: NudgeAction) {
        guard let session else { return }
        let now = Date()
        persist {
            _ = try $0.insert(NudgeRecord(at: session.shownAt, rule: session.rule,
                                          stretchIDs: session.stretches.map(\.id), action: action,
                                          detail: session.event.map(Self.json)))
        }
        scheduler.cardResolved(action, at: now, settings: settings)
        if action == .done, session.rule.isPostureCheck {
            checker.restartBadTimer(at: now)
        } else if action == .done, let bout = tracker.restart(at: now) {
            persist { try $0.insert(bout) }
            scheduler.boutEnded()
        }
        self.session = nil
        cardVisible = false
        panel.close()
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

    func deleteAllRecords() {
        persist { try $0.deleteAllRecords() }
        settings.measurementStartedAt = nil
        refreshBaseline()
    }

    private func persist(_ work: (Store) throws -> Void) {
        guard let store else { return }
        do { try work(store) } catch { lastError = "\(error)" }
    }

    private static func json(_ event: SignalEvent) -> String {
        var values = event.detail
        values["actionable"] = event.actionable ? 1 : 0
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body = (try? encoder.encode(values)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return "{\"variant\":\"\(event.variant)\",\"values\":\(body)}"
    }

    // MARK: - 카메라

    /// 카메라가 정상 동작 중이 아닐 때 보여 줄 한 줄. 동작 중이면 nil.
    var cameraProblem: String? {
        switch cameraStatus {
        case .running: return nil
        case .off: return "카메라 꺼짐"
        case .starting: return "카메라 켜는 중…"
        case .denied: return "카메라 권한이 없어요"
        case .unavailable(let reason): return reason
        }
    }

    private func updateCamera() {
        if settings.cameraEnabled && !screenLocked {
            guard cameraStatus != .running, cameraStatus != .starting else { return }
            cameraStatus = .starting
            camera.start(preferredID: settings.cameraUniqueID, capFrameRate: settings.capFrameRate) { [weak self] status, info in
                guard let self else { return }
                // 켜는 사이에 설정을 끄거나 화면이 잠기면 바로 멈춘다.
                if status == .running, !self.settings.cameraEnabled || self.screenLocked {
                    self.camera.stop()
                    self.cameraStatus = .off
                    return
                }
                self.cameraStatus = status
                // 처음 켤 때 고른 카메라(내장 카메라)를 고정한다.
                if status == .running, self.settings.cameraUniqueID == nil, let id = info?.uniqueID {
                    self.settings.cameraUniqueID = id
                }
            }
        } else {
            camera.stop()
            if cameraStatus == .running || cameraStatus == .starting { cameraStatus = .off }
            if let minute = aggregator.flush(at: Date()) { minuteClosed(minute) }
            faceMonitor.reset()
            checker.reset()
            lastSample = nil
            pose = nil
            publishPosture()
        }
    }

    func retryCamera() {
        cameraStatus = .off
        updateCamera()
    }

    private func handle(_ frame: FrameResult) {
        guard cameraStatus == .running else { return }
        lastSample = frame.sample
        pose = frame.pose
        faceMonitor.update(frame.sample, at: frame.at, baseline: nil, settings: settings)
        checker.update(tracker.isSitting ? frame.sample : nil, at: frame.at)
        publishPosture()
        let context = MinuteAggregator.Context(label: nil, mode: settings.analysisMode,
                                               frameCap: settings.capFrameRate, boutStart: tracker.boutStart,
                                               settingsVersion: settings.detectionVersion)
        if let minute = aggregator.add(frame.sample, at: frame.at, analysisMs: frame.analysisMs, context: context) {
            minuteClosed(minute)
        }
    }

    private func publishPosture() {
        if postureReading != checker.reading { postureReading = checker.reading }
        if postureIssues != checker.issues { postureIssues = checker.issues }
        if badPostureSince != checker.badSince { badPostureSince = checker.badSince }
    }

    private func minuteClosed(_ minute: PostureMinute) {
        persist { try $0.insert(minute) }

        // 카드는 오래 같은 자세(R5)만 띄운다. 앉은 직후보다 낮아짐·가까워짐(R6)은 거북목 판정과 겹쳐 기록만 남긴다.
        let events = signals.process(minute)
        stillMinutes = signals.stillMinutes(at: minute.end)
        for event in events {
            persist {
                try $0.insert(PostureEventRecord(at: event.at, rule: event.rule, variant: event.variant,
                                                 mode: settings.postureAlertMode, actionable: event.actionable,
                                                 detail: event.detail))
            }
            if event.actionable, event.rule == .stillness { pendingStill = event }
        }

        if UprightReference.isSettled(minute) {
            settledMinutes.append(minute)
            updateUprightReference()
        }
        if setupDetector.process(minute, baseline: autoBaseline) != nil {
            setupChangeSuspected = true
        }
        if minute.end.timeIntervalSince(lastBaselineRefresh) > 3600 { refreshBaseline(now: minute.end) }
    }

    /// 개인 흔들림과 자동 기준, 거북목 기준을 다시 계산한다 (시작할 때, 1시간마다, 다시 익히기 뒤).
    private func refreshBaseline(now: Date = Date()) {
        lastBaselineRefresh = now
        guard let store else { return }
        let since = max(now.addingTimeInterval(-14 * 86_400), settings.baselineResetAt ?? .distantPast)
        let recent = (try? store.postureMinutes(since: since)) ?? []
        let still = (try? store.postureMinutes(label: ExperimentLabel.still.rawValue)) ?? []
        var noise = NoiseModel.estimate(from: still, source: "가만히 측정 (\(still.count)분)") ?? .defaults
        let baseline = AutoBaseline.build(from: recent, noise: noise, params: settings.signals)
        if noise.minutes == 0, let baseline, baseline.isReady { noise = baseline.noise }
        autoBaseline = baseline
        signals.noise = noise
        settledMinutes = recent.filter(UprightReference.isSettled)
        updateUprightReference()
    }

    private func updateUprightReference() {
        let reference = UprightReference.build(from: settledMinutes)
        checker.reference = reference
        uprightReference = reference
    }

    /// "자리가 바뀌었어요" 확인. 바뀌었으면 그 뒤 기록으로 평소 자세를 다시 익힌다.
    func confirmSetupChange(_ changed: Bool) {
        setupChangeSuspected = false
        if changed {
            settings.baselineResetAt = Date()
            refreshBaseline()
        }
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
            boutClosed(bout)
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
