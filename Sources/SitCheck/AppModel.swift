import AppKit
import Combine
import SitCheckCore

/// 알림 카드 한 장의 상태. 동작별 좌우 기록과 증상, 카메라 카드의 "맞았나요?" 답을 모았다가 카드가 닫힐 때 저장한다.
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
    /// 카메라 카드면 그 신호
    let event: SignalEvent?

    @Published var entries: [String: Entry] = [:]
    /// nil이면 카드, 값이 있으면 해당 동작의 가이드 화면
    @Published var guide: Stretch?
    @Published var feedback: NudgeFeedback?

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

    var allSidesRecorded: Bool {
        !stretches.isEmpty && stretches.allSatisfy { entries[$0.id]?.side != nil }
    }
}

/// 무작위 확인 질문 한 번 (놓친 경우를 보기 위한 것)
struct CheckInPrompt: Equatable {
    static let question = "최근 20분 동안 자세를 거의 안 바꿨나요?"
    let askedAt: Date
    let stillMinutes: Double?
    let driftScore: Double?
}

/// 안내에 따라 동작을 하며 라벨을 붙여 기록하는 실험 (실험 3, 4)
struct GuidedSession: Equatable {
    enum Kind: Equatable { case still, protocolRun }

    var kind: Kind
    var steps: [ExperimentLabel]
    var stepSeconds: TimeInterval
    var index: Int
    var stepEndsAt: Date

    var current: ExperimentLabel { steps[index] }
    var title: String { kind == .still ? "실험 3 · 가만히 5분" : "실험 4 · 의도한 동작 구분" }
}

enum CalibrationKind: Equatable {
    /// 평소 자세 저장 (10초)
    case usualPosture
    /// 줄자로 잰 60 cm에서 거리 보정 (10초)
    case distance60
}

/// 실험 화면에 보여 줄 오늘 측정 요약
struct MeasurementSummary: Equatable {
    var startedAt: Date?
    var todayMinutes = 0
    var todaySittingMinutes = 0
    var todayFaceCoverage: Double?
    var todayEvents: [NudgeRule: Int] = [:]
    var todayStill: [String: Int] = [:]
    var stillMinutesRecorded = 0
    var protocolMinutesRecorded = 0
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
    /// 카드 대신 아이콘으로만 알린 규칙 (실험 8)
    @Published private(set) var iconSignal: NudgeRule?
    @Published private(set) var mutedUntil: Date?
    @Published private(set) var cardVisible = false

    // 메뉴 요약
    @Published private(set) var completionRate7d: Double?
    @Published private(set) var nudgeCount7d = 0
    @Published private(set) var tightness: [TightnessItem] = []
    @Published private(set) var clinicAdvice = false
    @Published private(set) var lastError: String?

    // 카메라
    @Published private(set) var cameraStatus: CameraStatus = .off
    @Published private(set) var cameraInfo: CameraInfo?
    @Published private(set) var lastSample: PostureSample?
    @Published private(set) var lastMinute: PostureMinute?
    @Published private(set) var stillMinutes: Double?
    @Published private(set) var driftLower: Double?
    @Published private(set) var driftCloser: Double?
    @Published private(set) var distanceCm: Double?
    @Published private(set) var noise: NoiseModel = .defaults
    @Published private(set) var autoBaseline: AutoBaseline?
    @Published private(set) var setupChangeSuspected = false
    @Published private(set) var inCall = false
    @Published private(set) var calibration: CalibrationKind?
    @Published private(set) var experiment: GuidedSession?
    @Published private(set) var checkIn: CheckInPrompt?
    @Published private(set) var probe3DResult: String?
    @Published private(set) var airPodsResult: String?
    @Published private(set) var measurement = MeasurementSummary()
    @Published var experimentsWindowOpen = false

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
    private var experimentTimer: Timer?
    private var breathOffTask: Task<Void, Never>?
    private var iconOffTask: Task<Void, Never>?
    private var screenLocked = false
    private var observers: [NSObjectProtocol] = []
    let camera = PostureCamera()
    private let headphoneProbe = HeadphoneProbe()
    /// 얼굴이 마지막으로 보인 시각, 예전 R2·R3 비교 기록
    private var legacy = PostureMonitor()
    private var legacyLogged: [NudgeRule: Date] = [:]
    private var aggregator = MinuteAggregator()
    private var signals = PostureSignals()
    private var setupDetector = SetupChangeDetector()
    private var gate = DeliveryGate()
    private var checkInPlanner = CheckInPlanner(perDay: AppSettings.default.checkInsPerDay)
    private var cpuMeter = CPUMeter()
    private var pendingPosture: SignalEvent?
    private var pendingCheckIn = false
    private var calibrationSamples: [PostureSample] = []
    private var calibrationEnds: Date?
    private var lastBaselineRefresh = Date.distantPast
    let photos = PhotoStore(directory: PhotoStore.defaultDirectory())
    private var photoPlanner = SnapshotPlanner(perDay: AppSettings.default.photosPerDay)
    /// 최근 사진 (메모리에만, 5분마다 한 장). 사진 일지를 남길 때 '몇 분 전' 칸에 쓴다.
    private var recentThumbs: [(at: Date, bout: Date, data: Data)] = []
    /// 앉은 직후 사진 (메모리에만). 사진 일지를 남길 때 '앉은 직후' 칸에 쓴다.
    private var boutThumb: (at: Date, bout: Date, data: Data)?
    private var capturingSnapshot = false
    private var lastPhotoMaintenance = Date.distantPast
    /// App Nap으로 타이머가 몇 분씩 밀리면 자리 비움을 놓치므로 끈다 (시스템 잠자기는 허용).
    private let activity = ProcessInfo.processInfo.beginActivity(
        options: .userInitiatedAllowingIdleSystemSleep, reason: "착석 시간 측정")

    static let tickInterval: TimeInterval = 5
    static let breathSignalSeconds: UInt64 = 60
    static let iconSignalSeconds: UInt64 = 120
    static let calibrationSeconds: TimeInterval = 10
    static let minCalibrationSamples = 5
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
            tracker.awayThreshold = Double(settings.awayAfterMinutes) * 60
        } catch {
            lastError = "저장소를 열지 못했어요: \(error)"
        }
        checkInPlanner.perDay = settings.checkInsPerDay
        photoPlanner.perDay = settings.photosPerDay
        signals = PostureSignals(params: settings.signals, noise: noise, distance: settings.distanceCalibration)
        observeSystemEvents()
        camera.onFrame = { [weak self] frame in self?.handle(frame) }
        refreshBaseline()
        updateCamera()
        refreshStats()
        maintainPhotos()
        autoTuneIfNeeded()
        _ = cpuMeter.sample(at: Date())
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    // MARK: - 설정

    private func settingsChanged(from old: AppSettings) {
        guard settings != old else { return }
        tracker.awayThreshold = Double(settings.awayAfterMinutes) * 60
        persist { try $0.saveSettings(settings) }
        if settings.cameraEnabled != old.cameraEnabled { updateCamera() }
        if settings.analysisMode != old.analysisMode || settings.capFrameRate != old.capFrameRate {
            camera.update(mode: settings.analysisMode, capFrameRate: settings.capFrameRate) { [weak self] fps in
                guard let self, let fps else { return }
                self.cameraInfo?.frameRate = fps
            }
        }
        signals.params = settings.signals
        signals.distance = settings.distanceCalibration
        checkInPlanner.perDay = settings.checkInsPerDay
        photoPlanner.perDay = settings.photosPerDay
        if !settings.photoDiaryEnabled {
            recentThumbs = []
            boutThumb = nil
        }
        if settings.photoRetentionDays != old.photoRetentionDays || settings.keepLabeledPhotos != old.keepLabeledPhotos {
            maintainPhotos()
        }
        if settings.postureAlertMode != old.postureAlertMode {
            pendingPosture = nil
            gate.cancelAll()
        }
        if settings.postureBaseline != old.postureBaseline { legacy.reset() }
    }

    // MARK: - 상태 표시

    var statusSymbol: String {
        if breathing { return "wind" }
        if iconSignal != nil { return "figure.walk" }
        if isMuted { return "moon.zzz" }
        if !isSitting { return "pause.circle" }
        if cardVisible || sittingMinutes >= settings.sitAlertMinutes { return "exclamationmark.circle.fill" }
        return "timer"
    }

    var isMuted: Bool { scheduler.isMuted(at: Date()) }

    private var panelBusy: Bool { session != nil || checkIn != nil }

    // MARK: - 주기 처리

    private func tick(now: Date = Date()) {
        inCall = CallDetector.inCall()
        if !screenLocked {
            let wasSitting = tracker.isSitting
            var idle = IdleMonitor.secondsSinceLastInput()
            // 입력 없이 읽거나 영상을 봐도 얼굴이 보이면 앉아 있는 것으로 본다.
            if cameraStatus == .running, let sinceFace = legacy.secondsSinceFace(at: now) {
                idle = min(idle, sinceFace)
            }
            let closed = tracker.tick(now: now, idleSeconds: idle)
            if let closed {
                boutClosed(closed, at: now)
            } else if wasSitting, !tracker.isSitting {
                // 1분 미만이라 저장하지 않는 구간이어도 자리를 비운 것이므로 같은 처리를 한다.
                scheduler.boutEnded()
                closePanelsForAway()
            }
        }
        refreshDisplay(now: now)

        // 실험 중에는 카드와 확인 질문을 띄우지 않는다.
        guard experiment == nil, calibration == nil else { return }

        // 미뤄 둔 카메라 카드는 그 상태가 끝났으면 버린다.
        if let pending = pendingPosture, !signals.isActive(pending.rule, at: now) {
            gate.cancel(pending.rule.rawValue)
            pendingPosture = nil
        }
        let idleNow = IdleMonitor.secondsSinceLastInput()
        let postureCandidate = settings.postureAlertMode == .cards && !setupChangeSuspected ? pendingPosture?.rule : nil

        switch scheduler.evaluate(now: now, boutStart: tracker.boutStart, settings: settings, posture: postureCandidate) {
        case .showCard(let rule)?:
            if gate.shouldDeliver(rule.rawValue, now: now, idleSeconds: idleNow, inCall: inCall) {
                deliver(rule, at: now)
            }
        case .breath?:
            gate.cancelAll()
            signalBreath()
        case nil:
            gate.cancelAll()
        }

        if pendingCheckIn, !panelBusy, tracker.isSitting,
           gate.shouldDeliver("checkin", now: now, idleSeconds: idleNow, inCall: inCall) {
            showCheckIn(at: now)
        }
    }

    private func refreshDisplay(now: Date) {
        isSitting = tracker.isSitting
        sittingMinutes = Int(tracker.sittingSeconds(at: now) / 60)
        mutedUntil = scheduler.isMuted(at: now) ? scheduler.mutedUntil : nil
        stillMinutes = signals.stillMinutes(at: now)
    }

    private func boutClosed(_ bout: SitBout, at now: Date) {
        persist { try $0.insert(bout) }
        scheduler.boutEnded()
        closePanelsForAway()
    }

    private func closePanelsForAway() {
        if cardVisible { resolveCard(.expired) }
        if checkIn != nil { answerCheckIn(.dismissed) }
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

    /// 조건이 된 알림을 카드나 아이콘(실험 8)으로 전한다.
    private func deliver(_ rule: NudgeRule, at now: Date) {
        let event = rule.isPostureCard ? pendingPosture : nil
        if rule.isPostureCard { pendingPosture = nil }
        if settings.iconOnlyPercent > 0, Double.random(in: 0..<100) < Double(settings.iconOnlyPercent) {
            scheduler.iconShown(rule, at: now, settings: settings)
            persist { try $0.insert(NudgeRecord(at: now, rule: rule, stretchIDs: [], action: .icon, detail: event.map(Self.json))) }
            iconSignal = rule
            iconOffTask?.cancel()
            iconOffTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: Self.iconSignalSeconds * 1_000_000_000)
                guard !Task.isCancelled else { return }
                self?.iconSignal = nil
            }
            refreshStats()
            return
        }
        showCard(rule: rule, at: now, event: event)
    }

    /// 메뉴의 "지금 스트레칭"에서도 호출한다.
    func showCard(rule: NudgeRule = .longSitting, at now: Date = Date(), event: SignalEvent? = nil) {
        guard session == nil else {
            panel.bringToFront()
            return
        }
        if checkIn != nil { answerCheckIn(.dismissed) }
        let history = (try? store?.recentPrescriptions()) ?? []
        let stretches = prescriber.prescribe(rule: rule, history: history, excluded: settings.excludedStretchIDs)
        let session = CardSession(rule: rule, shownAt: now, stretches: stretches,
                                  sittingMinutes: Int(tracker.sittingSeconds(at: now) / 60), event: event)
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

    func record(feedback: NudgeFeedback, in session: CardSession) {
        session.feedback = session.feedback == feedback ? nil : feedback
    }

    func resolveCard(_ action: NudgeAction) {
        guard let session else { return }
        let now = Date()
        persist { store in
            let nudgeID = try store.insert(NudgeRecord(at: session.shownAt, rule: session.rule,
                                                       stretchIDs: session.stretches.map(\.id), action: action,
                                                       feedback: session.feedback,
                                                       detail: session.event.map(Self.json)))
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
        // '자리가 바뀌었어요'라고 답했으면 설치 변화 확인 질문을 띄운다.
        if session.feedback == .setupChanged { setupChangeSuspected = true }

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

    // MARK: - 무작위 확인 질문

    private func showCheckIn(at now: Date) {
        pendingCheckIn = false
        checkInPlanner.asked(at: now)
        let prompt = CheckInPrompt(askedAt: now, stillMinutes: signals.stillMinutes(at: now), driftScore: signals.driftScore)
        checkIn = prompt
        panel.show(CheckInView(prompt: prompt, model: self))
    }

    func answerCheckIn(_ answer: CheckInAnswer) {
        guard let prompt = checkIn else { return }
        persist {
            try $0.insert(CheckInRecord(at: prompt.askedAt, question: CheckInPrompt.question, answer: answer,
                                        stillMinutes: prompt.stillMinutes, driftScore: prompt.driftScore))
        }
        checkIn = nil
        if session == nil { panel.close() }
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
        photos.deleteAll()
        recentThumbs = []
        boutThumb = nil
        refreshReview()
        settings.measurementStartedAt = nil
        refreshStats()
        refreshBaseline()
        refreshMeasurement()
    }

    // MARK: - 요약

    func refreshStats(now: Date = Date()) {
        guard let store else { return }
        do {
            let nudges = try store.nudges(since: now.addingTimeInterval(-7 * 86_400))
            nudgeCount7d = nudges.filter { $0.rule != .breath && $0.action != .icon }.count
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

    /// 실험 화면의 오늘 측정 요약
    func refreshMeasurement(now: Date = Date()) {
        guard let store else { return }
        let today = Calendar.current.startOfDay(for: now)
        let minutes = (try? store.postureMinutes(since: today)) ?? []
        let events = (try? store.postureEvents(since: today)) ?? []
        let day = Analysis.days(minutes: minutes, events: events, params: settings.signals).first
        let still = (try? store.postureMinutes(label: ExperimentLabel.still.rawValue)) ?? []
        let protocolCount = ExperimentLabel.allCases
            .filter { $0 != .still }
            .reduce(0) { $0 + ((try? store.postureMinutes(label: $1.rawValue))?.count ?? 0) }
        measurement = MeasurementSummary(startedAt: settings.measurementStartedAt,
                                         todayMinutes: day?.minutes ?? 0,
                                         todaySittingMinutes: day?.sittingMinutes ?? 0,
                                         todayFaceCoverage: day?.faceCoverage,
                                         todayEvents: day?.events ?? [:],
                                         todayStill: day?.stillVariants ?? [:],
                                         stillMinutesRecorded: still.count,
                                         protocolMinutesRecorded: protocolCount)
    }

    /// 개인 흔들림과 자동 기준을 다시 계산한다 (시작할 때, 1시간마다, 실험·다시 배우기 뒤).
    func refreshBaseline(now: Date = Date()) {
        lastBaselineRefresh = now
        guard let store else { return }
        let since = max(now.addingTimeInterval(-14 * 86_400), settings.baselineResetAt ?? .distantPast)
        let recent = (try? store.postureMinutes(since: since)) ?? []
        let still = (try? store.postureMinutes(label: ExperimentLabel.still.rawValue)) ?? []
        var noise = NoiseModel.estimate(from: still, source: "가만히 측정 (\(still.count)분)") ?? .defaults
        let baseline = AutoBaseline.build(from: recent, noise: noise, params: settings.signals)
        if noise.minutes == 0, let baseline, baseline.isReady { noise = baseline.noise }
        self.noise = noise
        self.autoBaseline = baseline
        signals.noise = noise
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

    // MARK: - 카메라 (FR-08~11)

    var cameraStatusText: String {
        switch cameraStatus {
        case .off: return "카메라 꺼짐"
        case .starting: return "카메라 켜는 중…"
        case .running:
            if let calibration {
                return calibration == .usualPosture ? "평소 자세를 재는 중… 편하게 앉아 화면을 봐 주세요"
                                                    : "거리 보정 중… 줄자로 잰 60 cm에 앉아 화면을 봐 주세요"
            }
            if let experiment { return "\(experiment.title): \(experiment.current.title)" }
            return lastSample == nil ? "얼굴이 보이지 않아요" : "\(settings.postureAlertMode == .shadow ? "기록 중 (카드 없음)" : "감지 중")"
        case .denied: return "카메라 권한이 없어요. 시스템 설정 > 개인정보 보호 및 보안 > 카메라에서 허용해 주세요."
        case .unavailable(let reason): return reason
        }
    }

    /// 지금 프레임 기준 추정 거리 (보정한 경우)
    var liveDistanceCm: Double? {
        guard let sample = lastSample, let calibration = settings.distanceCalibration else { return nil }
        return calibration.distanceCm(faceWidth: sample.faceWidth)
    }

    private func updateCamera() {
        if settings.cameraEnabled && !screenLocked {
            guard cameraStatus != .running, cameraStatus != .starting else { return }
            cameraStatus = .starting
            camera.start(preferredID: settings.cameraUniqueID, mode: settings.analysisMode,
                         capFrameRate: settings.capFrameRate) { [weak self] status, info in
                guard let self else { return }
                // 켜는 사이에 설정을 끄거나 화면이 잠기면 바로 멈춘다.
                if status == .running, !self.settings.cameraEnabled || self.screenLocked {
                    self.camera.stop()
                    self.cameraStatus = .off
                    return
                }
                self.cameraStatus = status
                self.cameraInfo = info
                if status == .running {
                    // 카메라가 꺼져 있던 시간을 첫 분의 CPU 평균에 섞지 않는다.
                    self.cpuMeter = CPUMeter()
                    _ = self.cpuMeter.sample(at: Date())
                }
                // 처음 켤 때 고른 카메라(내장 카메라)를 고정한다.
                if status == .running, self.settings.cameraUniqueID == nil, let id = info?.uniqueID {
                    self.settings.cameraUniqueID = id
                }
            }
        } else {
            camera.stop()
            if cameraStatus == .running || cameraStatus == .starting { cameraStatus = .off }
            if let minute = aggregator.flush(at: Date()) { minuteClosed(minute) }
            legacy.reset()
            lastSample = nil
            calibration = nil
            calibrationEnds = nil
        }
    }

    func retryCamera() {
        cameraStatus = .off
        updateCamera()
    }

    /// 고정해 둔 카메라를 풀고 내장 카메라를 다시 고른다.
    func resetCameraChoice() {
        if let minute = aggregator.flush(at: Date()) { minuteClosed(minute) }
        settings.cameraUniqueID = nil
        camera.resetDevice()
        cameraStatus = .off
        cameraInfo = nil
        updateCamera()
    }

    private func handle(_ frame: FrameResult) {
        guard cameraStatus == .running else { return }
        let now = frame.at
        lastSample = frame.sample

        // 예전 R2·R3: 카드는 띄우지 않고 '울렸을 알림' 비교 기록만 남긴다.
        legacy.update(frame.sample, at: now, baseline: settings.postureBaseline, settings: settings)
        if experiment == nil, tracker.isSitting, let rule = legacy.pendingRule(at: now, settings: settings) {
            logLegacy(rule, at: now)
            legacy.resetDeviation(at: now)
        }

        if calibration != nil {
            if let sample = frame.sample { calibrationSamples.append(sample) }
            if let calibrationEnds, now >= calibrationEnds { finishCalibration(at: now) }
        }

        let context = MinuteAggregator.Context(label: experiment?.current.rawValue, mode: settings.analysisMode,
                                               frameCap: settings.capFrameRate, boutStart: tracker.boutStart,
                                               settingsVersion: settings.detectionVersion)
        if let minute = aggregator.add(frame.sample, at: now, analysisMs: frame.analysisMs, context: context) {
            minuteClosed(minute)
        }
    }

    private func logLegacy(_ rule: NudgeRule, at now: Date) {
        if let last = legacyLogged[rule], now.timeIntervalSince(last) < Double(settings.postureRepeatMinutes) * 60 { return }
        legacyLogged[rule] = now
        persist {
            try $0.insert(PostureEventRecord(at: now, rule: rule, variant: "예전 규칙", mode: .shadow, actionable: false))
        }
    }

    private func minuteClosed(_ closed: PostureMinute) {
        var minute = closed
        minute.cpuPercent = cpuMeter.sample(at: minute.end)
        persist { try $0.insert(minute) }
        lastMinute = minute
        if settings.measurementStartedAt == nil { settings.measurementStartedAt = minute.start }
        defer {
            if experimentsWindowOpen { refreshMeasurement() }
        }
        guard minute.label == nil else { return }

        let events = signals.process(minute)
        stillMinutes = signals.stillMinutes(at: minute.end)
        driftLower = signals.driftLower
        driftCloser = signals.driftCloser
        distanceCm = signals.distanceCm
        for event in events {
            persist {
                try $0.insert(PostureEventRecord(at: event.at, rule: event.rule, variant: event.variant,
                                                 mode: settings.postureAlertMode, actionable: event.actionable,
                                                 detail: event.detail))
            }
            guard settings.postureAlertMode == .cards, event.actionable else { continue }
            // 여럿이 겹치면 착석 구간 안 변화(R6) > 오래 같은 자세(R5) > 가까움(R7) 순으로 하나만 기다린다.
            if pendingPosture == nil || Self.priority(event.rule) > Self.priority(pendingPosture!.rule) {
                pendingPosture = event
            }
        }

        photoDiaryStep(minute, events: events)

        if let change = setupDetector.process(minute, baseline: autoBaseline) {
            setupChangeSuspected = true
            persist {
                try $0.insert(PostureEventRecord(at: minute.end, rule: .setupChange, variant: "\(change.features)개 특징",
                                                 mode: settings.postureAlertMode, actionable: false,
                                                 detail: ["score": change.score, "features": Double(change.features)]))
            }
        }

        if settings.cameraEnabled, settings.checkInsPerDay > 0, !pendingCheckIn,
           checkInPlanner.shouldAsk(now: minute.end, sittingMinutes: tracker.sittingSeconds(at: minute.end) / 60,
                                    roll: Double.random(in: 0..<1)) {
            pendingCheckIn = true
        }

        if minute.end.timeIntervalSince(lastBaselineRefresh) > 3600 { refreshBaseline(now: minute.end) }
        if minute.end.timeIntervalSince(lastPhotoMaintenance) > 6 * 3600 {
            maintainPhotos(now: minute.end)
            autoTuneIfNeeded(now: minute.end)
        }
    }

    private static func priority(_ rule: NudgeRule) -> Int {
        switch rule {
        case .drift: return 3
        case .stillness: return 2
        case .near: return 1
        default: return 0
        }
    }

    /// '자리가 바뀌었어요' 확인
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
        guard settings.photoDiaryEnabled, cameraStatus == .running, experiment == nil, calibration == nil,
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

        let input = SnapshotPlanner.Input(now: now, boutStart: bout, sittingMinutes: tracker.sittingSeconds(at: now) / 60,
                                          events: events, stillMinutes: signals.stillMinutes(at: now),
                                          driftScore: signals.driftScore, params: settings.signals,
                                          roll: Double.random(in: 0..<1))
        guard !capturingSnapshot, let decision = photoPlanner.decide(input) else { return }
        capturingSnapshot = true
        let state = snapshotState(at: now, minute: minute, bout: bout)
        camera.captureThumbnail { [weak self] data in
            guard let self else { return }
            self.capturingSnapshot = false
            // 얼굴이 없거나 다른 얼굴이 함께 잡혀 찍지 않았으면 세지 않는다.
            guard let data, self.settings.photoDiaryEnabled else { return }
            self.saveSnapshot(decision, now: now, bout: bout, nowData: data, state: state)
        }
    }

    /// 사진을 남기는 순간 감지기가 본 값
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
        if let cm = signals.distanceCm { state[SnapshotKey.distanceCm] = cm }
        for feature in PostureFeature.allCases {
            if let stat = minute[feature] { state[SnapshotKey.feature(feature)] = stat.median }
        }
        return state
    }

    private func saveSnapshot(_ decision: SnapshotPlanner.Decision, now: Date, bout: Date, nowData: Data,
                              state: [String: Double]) {
        guard let store else { return }
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
        } catch {
            lastError = "사진 일지를 저장하지 못했어요: \(error)"
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
    func submitReview(_ snapshot: Snapshot, activity: SnapshotActivity?, wanted: SnapshotWant?, match: NudgeFeedback?) {
        guard let store, let id = snapshot.id else { return }
        let now = Date()
        let skipped = activity == nil && wanted == nil && match == nil
        do {
            if snapshot.labeledAt == nil {
                let recheck = !skipped && Double.random(in: 0..<1) < Self.recheckRate
                try store.updateSnapshotLabel(id: id, activity: activity, wanted: wanted, match: match, labeledAt: now,
                                              recheckDue: recheck ? now.addingTimeInterval(Self.recheckDelay) : nil)
                if skipped || (!recheck && !settings.keepLabeledPhotos) { deletePhotos(of: snapshot, at: now) }
            } else {
                try store.updateSnapshotRecheck(id: id, activity: activity, wanted: wanted, at: now)
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
        var params = settings.signals
        let changes = GradualTuner.tune(answered, params: &params, history: history, now: now)
        guard !changes.isEmpty else { return }
        for change in changes { persist { try $0.insert(change) } }
        settings.signals = params
        refreshReview(now: now)
    }

    /// 자동 조정한 판정값을 처음 값으로 되돌린다. 그날은 다시 옮기지 않는다.
    func resetTuning() {
        let now = Date()
        persist {
            try $0.insert(TuningChange(at: now, parameter: "reset", oldValue: 0, newValue: 0, samples: 0,
                                       note: "판정값을 처음 값으로 되돌림"))
        }
        settings.signals = SignalParameters()
        refreshReview(now: now)
    }

    // MARK: - 보정 (평소 자세, 거리)

    func startCalibration(_ kind: CalibrationKind) {
        guard cameraStatus == .running else {
            lastError = "카메라가 켜져 있어야 해요"
            return
        }
        calibrationSamples = []
        calibrationEnds = Date().addingTimeInterval(Self.calibrationSeconds)
        calibration = kind
    }

    private func finishCalibration(at now: Date) {
        guard let kind = calibration else { return }
        calibration = nil
        calibrationEnds = nil
        defer { calibrationSamples = [] }
        switch kind {
        case .usualPosture:
            guard calibrationSamples.count >= Self.minCalibrationSamples,
                  let baseline = PostureBaseline.from(calibrationSamples, at: now) else {
                lastError = "얼굴이 잘 보이지 않아 평소 자세를 저장하지 못했어요. 밝은 곳에서 다시 해 주세요."
                return
            }
            settings.postureBaseline = baseline
            lastError = nil
        case .distance60:
            let frontal = calibrationSamples.filter { abs($0.yaw ?? 0) <= 15 }
            guard frontal.count >= Self.minCalibrationSamples,
                  let width = Stats.median(frontal.map(\.faceWidth)), width > 0 else {
                lastError = "정면을 본 얼굴이 충분히 잡히지 않아 거리 보정을 하지 못했어요."
                return
            }
            settings.distanceCalibration = DistanceCalibration(knownCm: 60, faceWidth: width, calibratedAt: now)
            lastError = nil
        }
    }

    func clearDistanceCalibration() {
        settings.distanceCalibration = nil
    }

    // MARK: - 안내 실험 (실험 3, 4)

    func startExperiment(_ kind: GuidedSession.Kind) {
        guard experiment == nil else { return }
        guard cameraStatus == .running else {
            lastError = "카메라가 켜져 있어야 실험을 할 수 있어요"
            return
        }
        var rng = SystemRandomNumberGenerator()
        let steps = kind == .still ? [ExperimentLabel.still] : ExperimentLabel.protocolSteps(using: &rng)
        let seconds: TimeInterval = kind == .still ? 300 : 120
        experiment = GuidedSession(kind: kind, steps: steps, stepSeconds: seconds, index: 0,
                                   stepEndsAt: Date().addingTimeInterval(seconds))
        pendingPosture = nil
        gate.cancelAll()
        Self.chime()
        experimentTimer?.invalidate()
        experimentTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advanceExperiment() }
        }
    }

    func stopExperiment() {
        finishExperiment()
    }

    private func advanceExperiment(now: Date = Date()) {
        guard var current = experiment, now >= current.stepEndsAt else { return }
        if current.index + 1 < current.steps.count {
            current.index += 1
            current.stepEndsAt = now.addingTimeInterval(current.stepSeconds)
            experiment = current
            Self.chime()
        } else {
            finishExperiment()
        }
    }

    private func finishExperiment() {
        experimentTimer?.invalidate()
        experimentTimer = nil
        guard experiment != nil else { return }
        experiment = nil
        // 라벨이 붙은 마지막 구간을 바로 닫는다.
        if let minute = aggregator.flush(at: Date()) { minuteClosed(minute) }
        Self.chime()
        refreshBaseline()
        refreshMeasurement()
    }

    private static func chime() {
        (NSSound(named: "Glass") ?? NSSound(named: "Ping"))?.play()
    }

    // MARK: - 비용·API 확인 (실험 1, 2)

    func runProbe3D() {
        guard cameraStatus == .running else {
            probe3DResult = "카메라가 켜져 있어야 확인할 수 있어요"
            return
        }
        probe3DResult = "확인 중…"
        camera.probe3D { [weak self] text in
            self?.probe3DResult = text
            self?.appendProbeLog(text)
        }
    }

    func runAirPodsProbe() {
        airPodsResult = "30초 동안 확인 중… AirPods를 귀에 꽂고 고개를 천천히 숙였다 들어 보세요."
        headphoneProbe.run { [weak self] text in
            self?.airPodsResult = text
            self?.appendProbeLog(text)
        }
    }

    /// 확인 결과를 터미널 분석 도구에서도 볼 수 있게 파일에 남긴다.
    private func appendProbeLog(_ text: String) {
        let url = Store.defaultURL().deletingLastPathComponent().appendingPathComponent("probes.log")
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(text)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
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
        recentThumbs = []
        boutThumb = nil
        if experiment != nil { finishExperiment() }
        updateCamera()
        let now = Date()
        if let bout = tracker.markAway(at: now) {
            boutClosed(bout, at: now)
        } else {
            scheduler.boutEnded()
            closePanelsForAway()
        }
        tick(now: now)
    }

    private func handleBack() {
        screenLocked = false
        updateCamera()
        tick()
    }
}
