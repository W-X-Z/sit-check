import Foundation

// 사진 일지: 실제로 일하는 동안 사진을 하루 몇 장 남겨 두고, 나중에 사용자가 보고 답한 것으로
// 판정값을 하루 한 칸씩 옮긴다. 일부러 과장한 자세 실험 없이, 평소 기록에서 점진적으로 맞춘다.
// 사진은 이 Mac에만, 정해진 기간만 두고, 답하면 바로 지운다 (설정으로 바꿀 수 있음).

/// 사진을 찍은 이유
public enum SnapshotReason: String, Codable, CaseIterable, Sendable {
    /// 신호(기록만 포함)가 성립한 순간. 감지가 맞았는지 본다.
    case event
    /// 앉아 있는 동안 무작위 순간. 놓친 경우와 평소 모습을 본다.
    case random
    /// 판정값 바로 아래. 판정값을 옮길지 정하는 데 정보가 가장 많다.
    case nearThreshold

    public var label: String {
        switch self {
        case .event: return "알림이 울렸을 순간"
        case .random: return "무작위 순간"
        case .nearThreshold: return "판정값 바로 아래"
        }
    }
}

/// 사진을 보고 고르는 '이때 무엇을 하고 있었나'. 좋고 나쁨이 아니라 상황 묘사다.
public enum SnapshotActivity: String, Codable, CaseIterable, Sendable {
    case screen, leanIn, sink, lookDown, phone, sideScreen, recline, chinRest, sideLean, other

    public var label: String {
        switch self {
        case .screen: return "화면 보며 작업"
        case .leanIn: return "화면 쪽으로 다가감"
        case .sink: return "의자에 가라앉음"
        case .lookDown: return "키보드·책상 내려다봄"
        case .phone: return "휴대폰 봄"
        case .sideScreen: return "옆 화면·다른 곳 봄"
        case .recline: return "등받이에 기댐"
        case .chinRest: return "턱·볼을 굄"
        case .sideLean: return "옆으로 기댐"
        case .other: return "기타"
        }
    }
}

/// "이 순간 알림을 받았으면 좋았을까요?" 바른 자세인지가 아니라 사용자가 원했는지를 묻는다.
public enum SnapshotWant: String, Codable, CaseIterable, Sendable {
    case yes, no, unsure

    public var label: String {
        switch self {
        case .yes: return "네"
        case .no: return "아니요"
        case .unsure: return "모르겠어요"
        }
    }
}

/// 한 번에 남기는 사진 묶음의 한 장
public struct SnapshotPhoto: Codable, Equatable, Sendable {
    /// "ref" 앉은 직후, "m20" 약 20분 전, "m10" 약 10분 전, "now" 지금
    public var slot: String
    public var at: Date

    public init(slot: String, at: Date) {
        self.slot = slot
        self.at = at
    }

    /// 화면에 보여 줄 순서
    public static let order = ["ref", "m20", "m10", "now"]
}

/// 사진을 찍은 순간 감지기가 본 값의 키
public enum SnapshotKey {
    public static let stillMinutes = "still_minutes"
    public static let driftLower = "drift_lower"
    public static let driftCloser = "drift_closer"
    public static let driftScore = "drift_score"
    public static let distanceCm = "distance_cm"
    public static let sittingMinutes = "sitting_minutes"
    public static let minutesInBout = "minutes_in_bout"
    /// 그때 쓰던 '자세를 바꿨다' 기준 (σ의 배수). 기준이 바뀌면 이전 답은 이 값 조정에 쓰지 않는다.
    public static let shiftK = "shift_k"

    /// 직전 1분 특징 중앙값 (예: "feature_faceY")
    public static func feature(_ f: PostureFeature) -> String { "feature_\(f.rawValue)" }
}

/// 사진 일지 한 건. 사진 파일은 `PhotoStore`에 두고, 여기에는 시각·이유·감지 값·답만 둔다.
public struct Snapshot: Equatable, Sendable {
    public var id: Int64?
    public var at: Date
    public var reason: SnapshotReason
    /// 알림 순간·판정값 바로 아래일 때 그 규칙 (무작위면 nil)
    public var rule: NudgeRule?
    public var variant: String?
    public var photos: [SnapshotPhoto]
    /// 사진 파일을 지운 시각 (지우면 리뷰에 다시 나오지 않는다)
    public var photosDeletedAt: Date?
    public var state: [String: Double]
    public var settingsVersion: Int

    public var activity: SnapshotActivity?
    public var wanted: SnapshotWant?
    /// 알림 순간 사진에서 "감지 내용이 맞나요?"
    public var match: NudgeFeedback?
    /// 답한 시각. 건너뛰면 답 없이 이 값만 채운다.
    public var labeledAt: Date?

    /// 같은 사진을 며칠 뒤 다시 보여 줄 시각 (답이 얼마나 일정한지 보기 위해 일부만)
    public var recheckDue: Date?
    public var recheckActivity: SnapshotActivity?
    public var recheckWanted: SnapshotWant?
    public var recheckAt: Date?

    public init(id: Int64? = nil, at: Date, reason: SnapshotReason, rule: NudgeRule? = nil, variant: String? = nil,
                photos: [SnapshotPhoto], photosDeletedAt: Date? = nil, state: [String: Double] = [:], settingsVersion: Int = 0,
                activity: SnapshotActivity? = nil, wanted: SnapshotWant? = nil, match: NudgeFeedback? = nil,
                labeledAt: Date? = nil, recheckDue: Date? = nil, recheckActivity: SnapshotActivity? = nil,
                recheckWanted: SnapshotWant? = nil, recheckAt: Date? = nil) {
        self.id = id
        self.at = at
        self.reason = reason
        self.rule = rule
        self.variant = variant
        self.photos = photos
        self.photosDeletedAt = photosDeletedAt
        self.state = state
        self.settingsVersion = settingsVersion
        self.activity = activity
        self.wanted = wanted
        self.match = match
        self.labeledAt = labeledAt
        self.recheckDue = recheckDue
        self.recheckActivity = recheckActivity
        self.recheckWanted = recheckWanted
        self.recheckAt = recheckAt
    }

    public var hasPhotos: Bool { photosDeletedAt == nil && !photos.isEmpty }

    /// 다시 보기 차례인지 (처음 답은 했고, 다시 보기 기한이 지났고, 아직 다시 답하지 않음)
    public func isRecheckDue(at now: Date) -> Bool {
        guard labeledAt != nil, recheckAt == nil, let due = recheckDue else { return false }
        return now >= due
    }

    /// 리뷰 목록에 보여 줄지
    public func needsReview(at now: Date) -> Bool {
        guard hasPhotos else { return false }
        return labeledAt == nil || isRecheckDue(at: now)
    }

    /// 판정값 조정에 쓸 수 있는 답인지 (네/아니요로 답함)
    public var answeredWant: Bool? {
        switch wanted {
        case .yes: return true
        case .no: return false
        case .unsure, nil: return nil
        }
    }
}

// MARK: - 언제 찍을지

/// 사진을 언제 찍을지 정한다. 하루 상한, 사진 사이 최소 간격, 이유별 상한을 둔다.
/// `decide`는 찍을지 여부만 알려 주고, 실제로 찍었을 때 `taken`을 불러야 센다
/// (다른 사람 얼굴이 함께 잡혀 찍지 않은 경우를 세지 않도록).
public struct SnapshotPlanner: Sendable {
    public var perDay: Int
    public var randomPerDay = 3
    public var eventsPerRulePerDay = 2
    public var nearPerDay = 2
    public var minGap: TimeInterval = 15 * 60
    /// 하루에 앉아 있는 시간 가정 (분). 무작위 사진이 하루에 고르게 퍼지도록 확률을 정한다.
    public var expectedSittingMinutesPerDay: Double = 240
    /// 앉은 지 이만큼(분)은 지나야 찍는다.
    public var minSittingMinutes: Double = 10
    public var calendar: Calendar = .current

    public private(set) var day: Date?
    public private(set) var takenToday = 0
    private var eventsToday: [NudgeRule: Int] = [:]
    private var randomToday = 0
    private var nearToday = 0
    private var lastTakenAt: Date?
    /// 판정값 바로 아래 사진은 착석 구간마다 규칙별로 한 번만
    private var nearTakenInBout: [NudgeRule: Date] = [:]

    public struct Decision: Equatable, Sendable {
        public var reason: SnapshotReason
        public var rule: NudgeRule?
        public var variant: String?

        public init(reason: SnapshotReason, rule: NudgeRule? = nil, variant: String? = nil) {
            self.reason = reason
            self.rule = rule
            self.variant = variant
        }
    }

    public struct Input: Sendable {
        public var now: Date
        public var boutStart: Date?
        public var sittingMinutes: Double
        /// 이번 분에 새로 성립한 신호 (기록 전용 변형 포함)
        public var events: [SignalEvent]
        public var stillMinutes: Double?
        public var driftScore: Double?
        public var params: SignalParameters
        /// 0~1 균등 난수
        public var roll: Double

        public init(now: Date, boutStart: Date?, sittingMinutes: Double, events: [SignalEvent], stillMinutes: Double?,
                    driftScore: Double?, params: SignalParameters, roll: Double) {
            self.now = now
            self.boutStart = boutStart
            self.sittingMinutes = sittingMinutes
            self.events = events
            self.stillMinutes = stillMinutes
            self.driftScore = driftScore
            self.params = params
            self.roll = roll
        }
    }

    public init(perDay: Int) {
        self.perDay = perDay
    }

    /// 1분에 한 번 부른다.
    public mutating func decide(_ input: Input) -> Decision? {
        rollDay(input.now)
        guard perDay > 0, takenToday < perDay, let bout = input.boutStart,
              input.sittingMinutes >= minSittingMinutes else { return nil }
        if let lastTakenAt, input.now.timeIntervalSince(lastTakenAt) < minGap { return nil }

        // 1. 신호가 성립한 순간. '오래 같은 자세'는 기록 전용 변형(30·45분)도 찍어 판정값을 올릴 근거로 쓴다.
        let cameraRules: [NudgeRule] = [.drift, .stillness, .near]
        for rule in cameraRules where eventsToday[rule, default: 0] < eventsPerRulePerDay {
            if let event = input.events.first(where: { $0.rule == rule && ($0.actionable || $0.rule == .stillness) }) {
                return Decision(reason: .event, rule: rule, variant: event.variant)
            }
        }

        // 2. 판정값 바로 아래 (판정값을 내릴 근거)
        if nearToday < nearPerDay {
            let threshold = Double(input.params.stillMinutes)
            if nearTakenInBout[.stillness] != bout, let still = input.stillMinutes,
               still >= 0.7 * threshold, still < threshold {
                return Decision(reason: .nearThreshold, rule: .stillness)
            }
            if nearTakenInBout[.drift] != bout, let score = input.driftScore,
               score >= 0.6 * input.params.driftK, score < input.params.driftK {
                return Decision(reason: .nearThreshold, rule: .drift)
            }
        }

        // 3. 무작위
        if randomToday < randomPerDay, input.roll < Double(randomPerDay) / expectedSittingMinutesPerDay {
            return Decision(reason: .random)
        }
        return nil
    }

    /// 실제로 찍어 저장했을 때 부른다.
    public mutating func taken(_ decision: Decision, at now: Date, boutStart: Date?) {
        rollDay(now)
        takenToday += 1
        lastTakenAt = now
        switch decision.reason {
        case .event:
            if let rule = decision.rule { eventsToday[rule, default: 0] += 1 }
        case .nearThreshold:
            nearToday += 1
            if let rule = decision.rule, let boutStart { nearTakenInBout[rule] = boutStart }
        case .random:
            randomToday += 1
        }
    }

    private mutating func rollDay(_ now: Date) {
        let today = calendar.startOfDay(for: now)
        if day != today {
            day = today
            takenToday = 0
            eventsToday = [:]
            randomToday = 0
            nearToday = 0
        }
    }
}

// MARK: - 답으로 판정값 옮기기

/// 판정값을 옮긴 기록
public struct TuningChange: Equatable, Sendable {
    public var id: Int64?
    public var at: Date
    /// "stillMinutes", "driftK", "nearCm", "shiftK", 또는 되돌리기면 "reset"
    public var parameter: String
    public var oldValue: Double
    public var newValue: Double
    /// 근거로 쓴 답 수
    public var samples: Int
    public var scoreBefore: Double?
    public var scoreAfter: Double?
    public var note: String

    public init(id: Int64? = nil, at: Date, parameter: String, oldValue: Double, newValue: Double, samples: Int,
                scoreBefore: Double? = nil, scoreAfter: Double? = nil, note: String) {
        self.id = id
        self.at = at
        self.parameter = parameter
        self.oldValue = oldValue
        self.newValue = newValue
        self.samples = samples
        self.scoreBefore = scoreBefore
        self.scoreAfter = scoreAfter
        self.note = note
    }
}

/// 사진에 붙은 답으로 판정값을 조금씩 옮긴다.
///
/// - 판정값(R5 분, R6 σ 배수, R7 cm): "알림을 받았으면 좋았을까요?"의 네/아니요를 가장 잘 가르는 값
///   (균형 정확도 = 네를 잡은 비율과 아니요를 거른 비율의 평균)을 찾고, 지금 값보다 0.05 이상 나을 때만
///   그쪽으로 **하루 한 칸** 옮긴다.
/// - '자세를 바꿨다' 기준(shiftK): '오래 같은 자세' 알림 사진에서 "감지 내용이 아니에요"가 많으면
///   (맞아요 비율 0.7 미만) 하루 0.5씩 낮춰 작은 움직임도 자세 변화로 본다.
/// - 모든 값은 정해진 범위 안에서만 움직이고, 하루 상한 같은 알림 양 설정은 건드리지 않는다.
public enum GradualTuner {
    public static let minSamples = 12
    public static let minEachClass = 4
    public static let minGain = 0.05
    public static let minMatchAnswers = 8

    struct Knob: Sendable {
        var parameter: String
        var title: String
        var key: String
        var candidates: [Double]
        /// true면 값이 판정값 이상일 때 울린다 (R7 거리는 반대로 판정값보다 가까울 때)
        var firesAbove: Bool
        var rule: NudgeRule
        var get: @Sendable (SignalParameters) -> Double
        var set: @Sendable (inout SignalParameters, Double) -> Void
    }

    static let knobs: [Knob] = [
        Knob(parameter: "stillMinutes", title: "오래 같은 자세(R5) 분", key: SnapshotKey.stillMinutes,
             candidates: stride(from: 15.0, through: 60, by: 5).map { $0 }, firesAbove: true, rule: .stillness,
             get: { Double($0.stillMinutes) }, set: { $0.stillMinutes = Int($1.rounded()) }),
        Knob(parameter: "driftK", title: "아래로·가까이(R6) σ 배수", key: SnapshotKey.driftScore,
             candidates: stride(from: 1.5, through: 6, by: 0.5).map { $0 }, firesAbove: true, rule: .drift,
             get: { $0.driftK }, set: { $0.driftK = $1 }),
        Knob(parameter: "nearCm", title: "가까움(R7) cm", key: SnapshotKey.distanceCm,
             candidates: stride(from: 30.0, through: 55, by: 2.5).map { $0 }, firesAbove: false, rule: .near,
             get: { $0.nearCm }, set: { $0.nearCm = $1 }),
    ]

    public struct Evaluation: Sendable {
        public var parameter: String
        public var title: String
        public var samples: Int
        public var yes: Int
        public var no: Int
        public var current: Double
        public var best: Double?
        public var currentScore: Double?
        public var bestScore: Double?
        /// 한 칸 옮길 값 (옮기지 않으면 nil)
        public var next: Double?

        public var ready: Bool { samples >= GradualTuner.minSamples && yes >= GradualTuner.minEachClass && no >= GradualTuner.minEachClass }
    }

    /// 판정값 `threshold`로 네/아니요를 얼마나 잘 가르는지 (균형 정확도)
    public static func balancedAccuracy(_ points: [(x: Double, yes: Bool)], threshold: Double, firesAbove: Bool) -> Double? {
        let yes = points.filter { $0.yes }
        let no = points.filter { !$0.yes }
        guard !yes.isEmpty, !no.isEmpty else { return nil }
        func fires(_ x: Double) -> Bool { firesAbove ? x >= threshold : x < threshold }
        let tpr = Double(yes.filter { fires($0.x) }.count) / Double(yes.count)
        let tnr = Double(no.filter { !fires($0.x) }.count) / Double(no.count)
        return (tpr + tnr) / 2
    }

    /// 이 규칙의 판정값 조정에 쓸 답. 무작위 사진과 그 규칙 때문에 찍은 사진만 쓴다
    /// (다른 규칙 알림 순간의 '네'는 이 규칙과 상관없을 수 있다).
    static func points(_ snapshots: [Snapshot], knob: Knob) -> [(x: Double, yes: Bool)] {
        snapshots.compactMap { s in
            guard s.reason == .random || s.rule == knob.rule, s.match != .wrong,
                  let yes = s.answeredWant, let x = s.state[knob.key] else { return nil }
            return (x: x, yes: yes)
        }
    }

    public static func evaluate(_ snapshots: [Snapshot], params: SignalParameters) -> [Evaluation] {
        knobs.map { knob in
            let pts = points(snapshots, knob: knob)
            let current = knob.get(params)
            var eval = Evaluation(parameter: knob.parameter, title: knob.title, samples: pts.count,
                                  yes: pts.filter { $0.yes }.count, no: pts.filter { !$0.yes }.count, current: current)
            eval.currentScore = balancedAccuracy(pts, threshold: current, firesAbove: knob.firesAbove)
            var best: (value: Double, score: Double)?
            for c in knob.candidates {
                guard let score = balancedAccuracy(pts, threshold: c, firesAbove: knob.firesAbove) else { continue }
                // 점수가 같으면 지금 값에 가까운 쪽을 고른다.
                if best == nil || score > best!.score + 1e-9
                    || (abs(score - best!.score) <= 1e-9 && abs(c - current) < abs(best!.value - current)) {
                    best = (c, score)
                }
            }
            eval.best = best?.value
            eval.bestScore = best?.score
            if eval.ready, let best, let now = eval.currentScore, best.score - now >= minGain, best.value != current {
                if best.value > current {
                    eval.next = knob.candidates.first(where: { $0 > current + 1e-9 })
                } else {
                    eval.next = knob.candidates.last(where: { $0 < current - 1e-9 })
                }
            }
            return eval
        }
    }

    /// '오래 같은 자세' 알림 사진의 "감지 내용이 맞나요?" (지금 shiftK로 찍은 것만)
    public static func stillnessMatch(_ snapshots: [Snapshot], shiftK: Double) -> (right: Int, wrong: Int) {
        let answered = snapshots.filter { s in
            s.reason == .event && s.rule == .stillness
                && (s.state[SnapshotKey.shiftK].map { abs($0 - shiftK) < 1e-9 } ?? false)
        }
        return (answered.filter { $0.match == .right }.count, answered.filter { $0.match == .wrong }.count)
    }

    /// 하루 한 번, 값마다 한 칸까지만 옮긴다. 옮긴 내용을 돌려준다.
    public static func tune(_ snapshots: [Snapshot], params: inout SignalParameters, history: [TuningChange],
                            now: Date, calendar: Calendar = .current) -> [TuningChange] {
        func movedToday(_ parameter: String) -> Bool {
            history.contains { ($0.parameter == parameter || $0.parameter == "reset") && calendar.isDate($0.at, inSameDayAs: now) }
        }
        var changes: [TuningChange] = []
        let evaluations = evaluate(snapshots, params: params)
        for knob in knobs {
            guard !movedToday(knob.parameter),
                  let eval = evaluations.first(where: { $0.parameter == knob.parameter }), let next = eval.next else { continue }
            let pts = points(snapshots, knob: knob)
            let old = knob.get(params)
            knob.set(&params, next)
            changes.append(TuningChange(at: now, parameter: knob.parameter, oldValue: old, newValue: knob.get(params),
                                        samples: eval.samples, scoreBefore: eval.currentScore,
                                        scoreAfter: balancedAccuracy(pts, threshold: next, firesAbove: knob.firesAbove),
                                        note: "\(knob.title): 답 \(eval.samples)개 (네 \(eval.yes) · 아니요 \(eval.no))"))
        }

        let match = stillnessMatch(snapshots, shiftK: params.shiftK)
        let answered = match.right + match.wrong
        if !movedToday("shiftK"), answered >= minMatchAnswers,
           Double(match.right) / Double(answered) < 0.7, params.shiftK > 2.5 + 1e-9 {
            let old = params.shiftK
            params.shiftK = max(2.5, old - 0.5)
            changes.append(TuningChange(at: now, parameter: "shiftK", oldValue: old, newValue: params.shiftK,
                                        samples: answered, scoreBefore: Double(match.right) / Double(answered),
                                        note: "'오래 같은 자세' 감지가 사진과 다르다는 답 \(match.wrong)/\(answered)개"))
        }
        return changes
    }
}

// MARK: - 리뷰 화면 문구

public enum SnapshotCopy {
    /// 사진을 찍은 순간 감지기가 본 사실. 평가 문구 없이 값만 적는다.
    public static func facts(_ s: Snapshot) -> [String] {
        var lines: [String] = []
        if let sitting = s.state[SnapshotKey.sittingMinutes] {
            lines.append("앉은 지 \(Int(sitting.rounded()))분")
        }
        if let still = s.state[SnapshotKey.stillMinutes] {
            lines.append("감지: 마지막 자세 변화 뒤 \(Int(still.rounded()))분")
        }
        if let lower = s.state[SnapshotKey.driftLower], let closer = s.state[SnapshotKey.driftCloser] {
            lines.append(String(format: "감지: 앉은 직후보다 아래로 %.1f · 가까이 %.1f (흔들림의 배수)", lower, closer))
        }
        if let cm = s.state[SnapshotKey.distanceCm] {
            lines.append(String(format: "감지: 화면까지 약 %.0f cm", cm))
        }
        return lines
    }

    /// 알림 순간 사진이면 어떤 알림이었는지
    public static func eventLine(_ s: Snapshot) -> String? {
        guard let rule = s.rule else { return nil }
        let variant = s.variant.map { " (\($0))" } ?? ""
        switch s.reason {
        case .event: return "'\(rule.title)\(variant)' 알림이 울렸을 순간이에요"
        case .nearThreshold: return "'\(rule.title)' 판정값 바로 아래였던 순간이에요"
        case .random: return nil
        }
    }

    public static func slotTitle(_ photo: SnapshotPhoto, snapshotAt: Date) -> String {
        let minutes = Int((snapshotAt.timeIntervalSince(photo.at) / 60).rounded())
        switch photo.slot {
        case "ref": return "앉은 직후"
        case "now": return "이 순간"
        default: return "\(minutes)분 전"
        }
    }
}

// MARK: - 다시 보기 일치도

public enum SnapshotAgreement {
    /// 같은 사진에 며칠 뒤 다시 답한 것 중 같은 답의 비율 (상황, 알림 원함)
    public static func recheck(_ snapshots: [Snapshot]) -> (count: Int, activity: Double?, wanted: Double?) {
        let done = snapshots.filter { $0.recheckAt != nil }
        let activityPairs = done.filter { $0.activity != nil && $0.recheckActivity != nil }
        let wantedPairs = done.filter { $0.wanted != nil && $0.recheckWanted != nil }
        let activity = activityPairs.isEmpty ? nil
            : Double(activityPairs.filter { $0.activity == $0.recheckActivity }.count) / Double(activityPairs.count)
        let wanted = wantedPairs.isEmpty ? nil
            : Double(wantedPairs.filter { $0.wanted == $0.recheckWanted }.count) / Double(wantedPairs.count)
        return (done.count, activity, wanted)
    }
}

// MARK: - 사진 파일

/// 사진 파일 보관. 폴더는 본인만 읽을 수 있게(0700) 만들고 Time Machine 백업에서 뺀다.
public struct PhotoStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func defaultDirectory() -> URL {
        Store.defaultURL().deletingLastPathComponent().appendingPathComponent("photos", isDirectory: true)
    }

    public func url(id: Int64, slot: String) -> URL {
        directory.appendingPathComponent("\(id)-\(slot).jpg")
    }

    public func prepare() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        var dir = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
    }

    public func write(_ data: Data, id: Int64, slot: String) throws {
        try prepare()
        let path = url(id: id, slot: slot).path
        guard FileManager.default.createFile(atPath: path, contents: data, attributes: [.posixPermissions: 0o600]) else {
            throw StoreError.file("사진 파일을 쓰지 못했어요: \(path)")
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }

    public func exists(id: Int64, slot: String) -> Bool {
        FileManager.default.fileExists(atPath: url(id: id, slot: slot).path)
    }

    public func delete(id: Int64, slots: [String]) {
        for slot in slots { try? FileManager.default.removeItem(at: url(id: id, slot: slot)) }
    }

    /// 폴더 안 사진을 모두 지운다.
    public func deleteAll() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "jpg" { try? fm.removeItem(at: file) }
    }

    /// 지워야 할 사진 묶음: 보관 기간이 지났거나, 답했고 보관·다시 보기 대상이 아닌 것
    public static func expired(_ snapshots: [Snapshot], now: Date, retentionDays: Int, keepLabeled: Bool) -> [Snapshot] {
        let limit = now.addingTimeInterval(-Double(retentionDays) * 86_400)
        return snapshots.filter { s in
            guard s.hasPhotos else { return false }
            if s.at < limit { return true }
            guard s.labeledAt != nil else { return false }
            let waitingRecheck = s.recheckDue != nil && s.recheckAt == nil
            return !waitingRecheck && !keepLabeled
        }
    }
}
