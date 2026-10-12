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

    // 사진 일지
    /// 답할 차례인 사진 묶음 (오래된 것부터)
    @Published private(set) var reviewQueue: [Snapshot] = []
    /// 최근 판정값 조정 기록
    @Published private(set) var tuningLog: [TuningChange] = []

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
    let photos = PhotoStore(directory: PhotoStore.defaultDirectory())
    private var photoPlanner = SnapshotPlanner(perDay: AppSettings.default.photosPerDay)
    /// 최근 사진 (메모리에만, 5분마다 한 장). 사진 일지를 남길 때 '몇 분 전' 칸에 쓴다.
    private var recentThumbs: [(at: Date, bout: Date, data: Data)] = []
    /// 앉은 직후 사진 (메모리에만). 거북목 기준과 같은 때라 '앉은 직후' 칸으로 비교한다.
    private var boutThumb: (at: Date, bout: Date, data: Data)?
    private var capturingSnapshot = false
    /// 사진을 남긴 '바르지 않은 자세' 구간 (한 구간에 한 번만 알림 순간 사진을 찍는다)
    private var snapshotBadSince: Date?
    private var lastPhotoMaintenance = Date.distantPast
    /// App Nap으로 타이머가 몇 분씩 밀리면 자리 비움을 놓치므로 끈다 (시스템 잠자기는 허용).
    private let activity = ProcessInfo.processInfo.beginActivity(
        options: .userInitiatedAllowingIdleSystemSleep, reason: "착석 시간 측정")

    static let tickInterval: TimeInterval = 5
    static let thumbInterval: TimeInterval = 5 * 60
    /// 처음 답한 사진 중 며칠 뒤 한 번 더 보여 줄 비율 (답이 일정한지 보기 위해)
    static let recheckRate = 0.1
    static let recheckDelay: TimeInterval = 2 * 86_400

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
        photoPlanner.perDay = settings.photosPerDay
        observeSystemEvents()
        camera.onFrame = { [weak self] frame in self?.handle(frame) }
        refreshBaseline()
        maintainPhotos()
        autoTuneIfNeeded()
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
        photoPlanner.perDay = settings.photosPerDay
        if !settings.photoDiaryEnabled {
            recentThumbs = []
            boutThumb = nil
        }
        if settings.photoRetentionDays != old.photoRetentionDays || settings.keepLabeledPhotos != old.keepLabeledPhotos {
            maintainPhotos()
        }
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
        photos.deleteAll()
        recentThumbs = []
        boutThumb = nil
        refreshReview()
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
        photoDiaryStep(minute, events: events)

        if UprightReference.isSettled(minute) {
            settledMinutes.append(minute)
            updateUprightReference()
        }
        if setupDetector.process(minute, baseline: autoBaseline) != nil {
            setupChangeSuspected = true
        }
        if minute.end.timeIntervalSince(lastBaselineRefresh) > 3600 { refreshBaseline(now: minute.end) }
        if minute.end.timeIntervalSince(lastPhotoMaintenance) > 6 * 3600 {
            maintainPhotos(now: minute.end)
            autoTuneIfNeeded(now: minute.end)
        }
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

    // MARK: - 사진 일지

    /// 1분마다: 앉은 직후·5분마다 작은 사진을 메모리에 두고, 정해진 순간에 사진 묶음을 남긴다.
    private func photoDiaryStep(_ minute: PostureMinute, events: [SignalEvent]) {
        guard settings.photoDiaryEnabled, cameraStatus == .running,
              let bout = tracker.boutStart, minute.boutStart == bout else { return }
        let now = minute.end
        let intoBout = now.timeIntervalSince(bout) / 60
        if boutThumb?.bout != bout, intoBout >= 2, intoBout < 6 {
            camera.captureThumbnail { [weak self] data in
                guard let self, let data, self.tracker.boutStart == bout else { return }
                self.boutThumb = (at: now, bout: bout, data: data)
            }
        } else if recentThumbs.last.map({ now.timeIntervalSince($0.at) >= Self.thumbInterval }) ?? true {
            camera.captureThumbnail { [weak self] data in
                guard let self, let data, self.settings.photoDiaryEnabled else { return }
                self.recentThumbs.removeAll { $0.bout != bout || now.timeIntervalSince($0.at) > 35 * 60 }
                self.recentThumbs.append((at: now, bout: bout, data: data))
            }
        }

        // 바르지 않은 자세 카드가 될 상태면, 그 구간에서 한 번만 알림 순간으로 찍는다.
        var candidates = events
        let excluded: Set<PostureIssue> = setupChangeSuspected ? [.forwardHead] : []
        if let event = checker.cardEvent(at: now, excluding: excluded), checker.badSince != snapshotBadSince {
            candidates.append(event)
        }
        let near = SnapshotPlanner.nearCandidates(stillMinutes: signals.stillMinutes(at: now), signals: settings.signals,
                                                  reading: checker.reading, check: settings.postureCheck,
                                                  flagged: checker.issues)
        let input = SnapshotPlanner.Input(now: now, boutStart: bout, sittingMinutes: tracker.sittingSeconds(at: now) / 60,
                                          events: candidates, near: near, roll: Double.random(in: 0..<1))
        guard !capturingSnapshot, let decision = photoPlanner.decide(input) else { return }
        capturingSnapshot = true
        let state = snapshotState(at: now, minute: minute, bout: bout)
        let badSince = checker.badSince
        camera.captureThumbnail { [weak self] data in
            guard let self else { return }
            self.capturingSnapshot = false
            // 얼굴이 없거나 다른 얼굴이 함께 잡혀 찍지 않았으면 세지 않는다.
            guard let data, self.settings.photoDiaryEnabled else { return }
            if self.saveSnapshot(decision, now: now, bout: bout, nowData: data, state: state),
               decision.reason == .event, decision.rule?.isPostureCheck == true {
                self.snapshotBadSince = badSince
            }
        }
    }

    /// 사진을 남기는 순간 앱이 본 값
    private func snapshotState(at now: Date, minute: PostureMinute, bout: Date) -> [String: Double] {
        var state: [String: Double] = [
            SnapshotKey.sittingMinutes: tracker.sittingSeconds(at: now) / 60,
            SnapshotKey.minutesInBout: now.timeIntervalSince(bout) / 60,
            SnapshotKey.shiftK: settings.signals.shiftK,
        ]
        if let still = signals.stillMinutes(at: now) { state[SnapshotKey.stillMinutes] = still }
        if let lower = signals.driftLower { state[SnapshotKey.driftLower] = lower }
        if let closer = signals.driftCloser { state[SnapshotKey.driftCloser] = closer }
        if let score = signals.driftScore { state[SnapshotKey.driftScore] = score }
        if let reading = checker.reading { state.merge(reading.detail) { $1 } }
        for issue in checker.issues { state[SnapshotKey.issue(issue)] = 1 }
        if let bad = checker.badMinutes(at: now) { state[SnapshotKey.badMinutes] = bad }
        for feature in PostureFeature.allCases {
            if let stat = minute[feature] { state[SnapshotKey.feature(feature)] = stat.median }
        }
        return state
    }

    /// 사진 묶음을 저장한다 (앉은 직후 · 약 20분 전 · 약 10분 전 · 지금). 저장했으면 true.
    @discardableResult
    private func saveSnapshot(_ decision: SnapshotPlanner.Decision, now: Date, bout: Date, nowData: Data,
                              state: [String: Double]) -> Bool {
        guard let store else { return false }
        var frames: [(slot: String, at: Date, data: Data)] = []
        var after = Date.distantPast
        if let ref = boutThumb, ref.bout == bout {
            frames.append((slot: "ref", at: ref.at, data: ref.data))
            after = ref.at
        }
        let earlier = recentThumbs.filter { $0.bout == bout && $0.at > after }
        func closest(_ minutesAgo: Double) -> (at: Date, bout: Date, data: Data)? {
            earlier.min { a, b in
                abs(now.timeIntervalSince(a.at) / 60 - minutesAgo) < abs(now.timeIntervalSince(b.at) / 60 - minutesAgo)
            }
        }
        if let m20 = closest(20), now.timeIntervalSince(m20.at) >= 12 * 60 {
            frames.append((slot: "m20", at: m20.at, data: m20.data))
        }
        if let m10 = closest(10), now.timeIntervalSince(m10.at) >= 6 * 60, !frames.contains(where: { $0.at == m10.at }) {
            frames.append((slot: "m10", at: m10.at, data: m10.data))
        }
        frames.append((slot: "now", at: now, data: nowData))

        let snapshot = Snapshot(at: now, reason: decision.reason, rule: decision.rule, variant: decision.variant,
                                photos: frames.map { SnapshotPhoto(slot: $0.slot, at: $0.at) }, state: state,
                                settingsVersion: settings.detectionVersion)
        do {
            let id = try store.insert(snapshot)
            do {
                for frame in frames { try photos.write(frame.data, id: id, slot: frame.slot) }
            } catch {
                photos.delete(id: id, slots: frames.map { $0.slot })
                try? store.markPhotosDeleted(snapshotID: id, at: now)
                throw error
            }
            photoPlanner.taken(decision, at: now, boutStart: bout)
            refreshReview(now: now)
            return true
        } catch {
            lastError = "사진 일지를 저장하지 못했어요: \(error)"
            return false
        }
    }

    /// 리뷰할 사진과 조정 기록을 다시 읽는다.
    func refreshReview(now: Date = Date()) {
        guard let store else { return }
        reviewQueue = ((try? store.snapshotsWithPhotos()) ?? []).filter { $0.needsReview(at: now) }
        tuningLog = (try? store.tuningLog(since: now.addingTimeInterval(-60 * 86_400))) ?? []
    }

    func photoURL(_ snapshot: Snapshot, _ photo: SnapshotPhoto) -> URL? {
        snapshot.id.map { photos.url(id: $0, slot: photo.slot) }
    }

    /// 리뷰 답을 저장한다. 답이 모두 nil이면 건너뛴 것으로 보고 사진을 지운다.
    /// 처음 답한 사진 중 일부는 며칠 뒤 한 번 더 보여 주고, 나머지는 바로 지운다 (보관 설정을 켜지 않았다면).
    func submitReview(_ snapshot: Snapshot, activity: SnapshotActivity?, observed: Set<PostureIssue>?,
                      wanted: SnapshotWant?, match: NudgeFeedback?) {
        guard let store, let id = snapshot.id else { return }
        let now = Date()
        let skipped = activity == nil && observed == nil && wanted == nil && match == nil
        do {
            if snapshot.labeledAt == nil {
                let recheck = !skipped && Double.random(in: 0..<1) < Self.recheckRate
                try store.updateSnapshotLabel(id: id, activity: activity, observed: observed, wanted: wanted, match: match,
                                              labeledAt: now,
                                              recheckDue: recheck ? now.addingTimeInterval(Self.recheckDelay) : nil)
                if skipped || (!recheck && !settings.keepLabeledPhotos) { deletePhotos(of: snapshot, at: now) }
            } else {
                try store.updateSnapshotRecheck(id: id, activity: activity, observed: observed, wanted: wanted, at: now)
                if skipped || !settings.keepLabeledPhotos { deletePhotos(of: snapshot, at: now) }
            }
        } catch {
            lastError = "\(error)"
        }
        autoTuneIfNeeded(now: now)
        refreshReview(now: now)
    }

    private func deletePhotos(of snapshot: Snapshot, at now: Date) {
        guard let id = snapshot.id else { return }
        photos.delete(id: id, slots: snapshot.photos.map(\.slot))
        persist { try $0.markPhotosDeleted(snapshotID: id, at: now) }
    }

    /// 보관 기간이 지났거나 답한 사진을 지운다 (시작할 때, 6시간마다, 보관 설정을 바꿨을 때).
    func maintainPhotos(now: Date = Date()) {
        lastPhotoMaintenance = now
        guard let store else { return }
        let withPhotos = (try? store.snapshotsWithPhotos()) ?? []
        for snapshot in PhotoStore.expired(withPhotos, now: now, retentionDays: settings.photoRetentionDays,
                                           keepLabeled: settings.keepLabeledPhotos) {
            deletePhotos(of: snapshot, at: now)
        }
        refreshReview(now: now)
    }

    func deleteAllPhotos() {
        photos.deleteAll()
        persist { try $0.markAllPhotosDeleted(at: Date()) }
        recentThumbs = []
        boutThumb = nil
        refreshReview()
    }

    /// 답이 쌓였으면 판정값을 하루 한 칸 옮긴다 (최근 60일 답).
    private func autoTuneIfNeeded(now: Date = Date()) {
        guard settings.autoTune, let store else { return }
        let answered = ((try? store.snapshots(since: now.addingTimeInterval(-60 * 86_400))) ?? []).filter { $0.labeledAt != nil }
        let history = (try? store.tuningLog(since: now.addingTimeInterval(-2 * 86_400))) ?? []
        var tuned = settings
        let changes = GradualTuner.tune(answered, settings: &tuned, history: history, now: now)
        guard !changes.isEmpty else { return }
        for change in changes { persist { try $0.insert(change) } }
        settings = tuned
        refreshReview(now: now)
    }

    /// 자동 조정한 판정값을 처음 값으로 되돌린다. 그날은 다시 옮기지 않는다.
    func resetTuning() {
        let now = Date()
        persist {
            try $0.insert(TuningChange(at: now, parameter: "reset", oldValue: 0, newValue: 0, samples: 0,
                                       note: "판정값을 처음 값으로 되돌림"))
        }
        var reset = settings
        GradualTuner.reset(&reset)
        settings = reset
        refreshReview(now: now)
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
        recentThumbs = []
        boutThumb = nil
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
