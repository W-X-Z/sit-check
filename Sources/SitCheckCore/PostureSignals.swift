import Foundation

/// 카메라 신호 판정값. 근거로 정해진 값이 아니라 출발값이며, 기록 재생(`sitcheck-analyze replay`)으로 맞춘다.
public struct SignalParameters: Codable, Equatable, Sendable {
    /// R5: 마지막 자세 변화 뒤 이 시간(분)이 지나면 '오래 같은 자세'
    public var stillMinutes: Int = 20
    /// 분 중앙값이 기준점에서 개인 흔들림(σ)의 몇 배 넘게 옮겨 가면 자세를 바꾼 것으로 본다.
    public var shiftK: Double = 4
    /// 1분 안의 p10–p90 폭이 σ의 몇 배를 넘으면 그 분 안에 움직인 것으로 본다.
    public var rangeK: Double = 6
    /// R6: 이번 착석 구간 기준보다 아래로·가까이 옮겨 간 정도가 σ의 몇 배 이상이면
    public var driftK: Double = 3
    /// R6: 그 상태가 이어져야 하는 시간 (분)
    public var driftHoldMinutes: Int = 5
    /// R7: 추정 거리가 이 값(cm)보다 가까운 상태가
    public var nearCm: Double = 40
    /// R7: 이 시간(분) 이어지면
    public var nearHoldMinutes: Int = 10
    /// 얼굴이 잡힌 프레임 비율이 이보다 낮은 분은 '얼굴 안 보임'으로 본다.
    public var minValidRatio: Double = 0.5
    /// 분석 프레임이 이보다 적은 분은 판정에 쓰지 않는다 (카메라를 막 켰을 때 등).
    public var minFrames: Int = 20
    /// 기록 전용으로 함께 세는 '오래 같은 자세' 변형 (분)
    public var stillVariants: [Int] = [20, 30, 45]

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SignalParameters()
        stillMinutes = try c.decodeIfPresent(Int.self, forKey: .stillMinutes) ?? d.stillMinutes
        shiftK = try c.decodeIfPresent(Double.self, forKey: .shiftK) ?? d.shiftK
        rangeK = try c.decodeIfPresent(Double.self, forKey: .rangeK) ?? d.rangeK
        driftK = try c.decodeIfPresent(Double.self, forKey: .driftK) ?? d.driftK
        driftHoldMinutes = try c.decodeIfPresent(Int.self, forKey: .driftHoldMinutes) ?? d.driftHoldMinutes
        nearCm = try c.decodeIfPresent(Double.self, forKey: .nearCm) ?? d.nearCm
        nearHoldMinutes = try c.decodeIfPresent(Int.self, forKey: .nearHoldMinutes) ?? d.nearHoldMinutes
        minValidRatio = try c.decodeIfPresent(Double.self, forKey: .minValidRatio) ?? d.minValidRatio
        minFrames = try c.decodeIfPresent(Int.self, forKey: .minFrames) ?? d.minFrames
        stillVariants = try c.decodeIfPresent([Int].self, forKey: .stillVariants) ?? d.stillVariants
    }
}

/// 가만히 있을 때의 개인 흔들림 (강건 표준편차). 판정 임계값은 모두 이 값의 배수다.
public struct NoiseModel: Codable, Equatable, Sendable {
    public var faceX: Double
    public var faceY: Double
    /// 얼굴 폭의 상대 흔들림 (0.01 = 1%)
    public var widthRel: Double
    public var roll: Double
    public var yaw: Double
    public var pitch: Double
    /// 어디서 얻은 값인지 (기본값, 가만히 5분, 자동)
    public var source: String
    /// 계산에 쓴 분 수
    public var minutes: Int

    public init(faceX: Double, faceY: Double, widthRel: Double, roll: Double, yaw: Double, pitch: Double,
                source: String, minutes: Int) {
        self.faceX = faceX
        self.faceY = faceY
        self.widthRel = widthRel
        self.roll = roll
        self.yaw = yaw
        self.pitch = pitch
        self.source = source
        self.minutes = minutes
    }

    /// 측정 전 출발값. 60 cm에서 얼굴 위치 약 3 mm, 크기 약 1% 흔들림을 가정한다.
    public static let defaults = NoiseModel(faceX: 0.006, faceY: 0.006, widthRel: 0.012,
                                            roll: 1.0, yaw: 2.0, pitch: 2.0, source: "기본값", minutes: 0)
    /// 측정값이 이보다 작아도 이 값을 쓴다 (σ가 0에 가까우면 모든 움직임이 신호가 된다).
    public static let floor = NoiseModel(faceX: 0.002, faceY: 0.002, widthRel: 0.004,
                                         roll: 0.3, yaw: 0.6, pitch: 0.6, source: "하한", minutes: 0)

    /// 분별 MAD의 중앙값 × 1.4826. 얼굴이 충분히 잡힌 분이 3개 이상 있어야 한다.
    public static func estimate(from minutes: [PostureMinute], source: String, minFaceFrames: Int = 30) -> NoiseModel? {
        let usable = minutes.filter { $0.faceFrames >= minFaceFrames }
        guard usable.count >= 3 else { return nil }
        func sigma(_ f: PostureFeature, floor: Double, fallback: Double) -> Double {
            guard let m = Stats.median(usable.compactMap { $0[f]?.mad }) else { return fallback }
            return max(floor, m * Stats.madToSigma)
        }
        let relative = usable.compactMap { m -> Double? in
            guard let s = m[.faceWidth], s.median > 0 else { return nil }
            return s.mad / s.median
        }
        let widthRel = Stats.median(relative).map { max(Self.floor.widthRel, $0 * Stats.madToSigma) } ?? defaults.widthRel
        return NoiseModel(faceX: sigma(.faceX, floor: Self.floor.faceX, fallback: defaults.faceX),
                          faceY: sigma(.faceY, floor: Self.floor.faceY, fallback: defaults.faceY),
                          widthRel: widthRel,
                          roll: sigma(.roll, floor: Self.floor.roll, fallback: defaults.roll),
                          yaw: sigma(.yaw, floor: Self.floor.yaw, fallback: defaults.yaw),
                          pitch: sigma(.pitch, floor: Self.floor.pitch, fallback: defaults.pitch),
                          source: source, minutes: usable.count)
    }

    /// 특징별 σ (얼굴 폭은 상대값이라 `widthRel`을 따로 쓴다)
    public func sigma(_ feature: PostureFeature) -> Double? {
        switch feature {
        case .faceX: return faceX
        case .faceY: return faceY
        case .roll: return roll
        case .yaw: return yaw
        case .pitch: return pitch
        default: return nil
        }
    }
}

/// 줄자로 잰 거리에서 한 번 저장한 얼굴 폭으로 화면까지 거리를 추정한다 (얼굴 폭 ∝ 1/거리).
/// 카메라 화각이나 눈 사이 거리를 가정하지 않아도 된다.
public struct DistanceCalibration: Codable, Equatable, Sendable {
    public var knownCm: Double
    /// `knownCm` 거리에서의 얼굴 폭 비율
    public var faceWidth: Double
    public var calibratedAt: Date

    public init(knownCm: Double, faceWidth: Double, calibratedAt: Date) {
        self.knownCm = knownCm
        self.faceWidth = faceWidth
        self.calibratedAt = calibratedAt
    }

    public func distanceCm(faceWidth width: Double) -> Double? {
        guard width > 0, faceWidth > 0 else { return nil }
        return knownCm * faceWidth / width
    }
}

/// 카메라 신호 하나가 새로 성립한 순간.
public struct SignalEvent: Equatable, Sendable {
    public var rule: NudgeRule
    public var at: Date
    /// 같은 규칙 안의 변형 (예: "20분", "아래로", "가까이")
    public var variant: String
    /// 현재 설정 기준으로 카드 후보인지. 기록 전용 변형이면 false.
    public var actionable: Bool
    public var detail: [String: Double]

    public init(rule: NudgeRule, at: Date, variant: String, actionable: Bool, detail: [String: Double]) {
        self.rule = rule
        self.at = at
        self.variant = variant
        self.actionable = actionable
        self.detail = detail
    }
}

/// '바른 자세'를 판정하지 않는 카메라 신호 (제안 D). 분 단위 요약만 보고 판정하므로,
/// 앱에서 쓰는 코드를 그대로 기록에 대고 다시 돌릴 수 있다.
///
/// - R5 오래 같은 자세: 얼굴 위치·크기·각도가 개인 흔들림의 몇 배 넘게 바뀐 마지막 순간부터 센다.
/// - R6 점점 아래로·가까이: 앉은 지 2–5분의 중앙값을 그 착석 구간의 기준으로 삼고, 최근 5분이
///   아래로(얼굴 위치) 또는 가까이(얼굴 크기) 옮겨 간 정도를 본다. 좌우 값은 넣지 않는다.
/// - R7 가까움: 거리 보정을 한 경우에만, 추정 거리가 정한 값보다 가까운 상태가 이어지면.
public struct PostureSignals: Sendable {
    public var params: SignalParameters
    public var noise: NoiseModel
    public var distance: DistanceCalibration?

    // R5
    private var stillBout: Date?
    private var anchor: [PostureFeature: Double]?
    private var lastChange: Date?
    private var firedStill: Set<Int> = []

    // R6
    private var driftBout: Date?
    private var referenceSamples: [(y: Double, w: Double)] = []
    public private(set) var driftReference: (y: Double, w: Double, at: Date)?
    private var recent: [(end: Date, y: Double, w: Double)] = []
    private var driftStreak = 0
    private var driftArmed = true
    /// 최근 5분이 기준보다 아래로 옮겨 간 정도 (σ 단위, 양수 = 아래로)
    public private(set) var driftLower: Double?
    /// 최근 5분이 기준보다 가까워진 정도 (σ 단위, 양수 = 가까이)
    public private(set) var driftCloser: Double?

    // R7
    private var nearStreak = 0
    private var nearArmed = true
    public private(set) var distanceCm: Double?

    public init(params: SignalParameters = SignalParameters(), noise: NoiseModel = .defaults,
                distance: DistanceCalibration? = nil) {
        self.params = params
        self.noise = noise
        self.distance = distance
    }

    /// 마지막 자세 변화 뒤 지난 시간 (분). 판정할 수 없으면 nil.
    public func stillMinutes(at now: Date) -> Double? {
        guard anchor != nil, let lastChange else { return nil }
        return max(0, now.timeIntervalSince(lastChange) / 60)
    }

    /// 아래로·가까이 중 큰 값 (σ 단위)
    public var driftScore: Double? {
        switch (driftLower, driftCloser) {
        case let (l?, c?): return max(l, c)
        default: return nil
        }
    }

    /// 지금도 그 상태가 이어지고 있는지 (미뤄 둔 카드를 아직 띄울지 판단)
    public func isActive(_ rule: NudgeRule, at now: Date) -> Bool {
        switch rule {
        case .stillness: return (stillMinutes(at: now) ?? 0) >= Double(params.stillMinutes)
        case .drift: return (driftScore ?? 0) >= params.driftK
        case .near: return nearStreak >= params.nearHoldMinutes
        default: return false
        }
    }

    public mutating func reset() {
        stillBout = nil
        anchor = nil
        lastChange = nil
        firedStill = []
        driftBout = nil
        referenceSamples = []
        driftReference = nil
        recent = []
        driftStreak = 0
        driftArmed = true
        driftLower = nil
        driftCloser = nil
        nearStreak = 0
        nearArmed = true
        distanceCm = nil
    }

    /// 분 단위 요약 하나를 넣고 새로 성립한 신호를 돌려준다. 요약은 시간 순서대로 넣어야 한다.
    public mutating func process(_ m: PostureMinute) -> [SignalEvent] {
        guard m.label == nil, m.frames >= params.minFrames else { return [] }
        guard let bout = m.boutStart else {
            reset()
            return []
        }
        let valid = m.validRatio >= params.minValidRatio
            && m[.faceX] != nil && m[.faceY] != nil && (m[.faceWidth]?.median ?? 0) > 0
        return stillness(m, bout: bout, valid: valid)
            + drift(m, bout: bout, valid: valid)
            + near(m, valid: valid)
    }

    // MARK: - R5 오래 같은 자세

    private mutating func stillness(_ m: PostureMinute, bout: Date, valid: Bool) -> [SignalEvent] {
        if stillBout != bout {
            stillBout = bout
            anchor = nil
            lastChange = nil
            firedStill = []
        }
        guard valid else {
            // 얼굴이 대부분 안 보인 분은 움직인 것으로 본다 (자리를 뜨거나 크게 돌아앉음).
            anchor = nil
            lastChange = nil
            firedStill = []
            return []
        }
        let current = Self.medians(m)
        guard let a = anchor, let since = lastChange else {
            anchor = current
            lastChange = m.start
            return []
        }
        if moved(m, from: a) {
            anchor = current
            lastChange = m.end
            firedStill = []
            return []
        }
        let still = m.end.timeIntervalSince(since) / 60
        var events: [SignalEvent] = []
        for threshold in Set(params.stillVariants + [params.stillMinutes]).sorted()
        where still >= Double(threshold) && !firedStill.contains(threshold) {
            firedStill.insert(threshold)
            events.append(SignalEvent(rule: .stillness, at: m.end, variant: "\(threshold)분",
                                      actionable: threshold == params.stillMinutes,
                                      detail: ["still_minutes": still, "threshold": Double(threshold)]))
        }
        return events
    }

    private func moved(_ m: PostureMinute, from a: [PostureFeature: Double]) -> Bool {
        for feature in [PostureFeature.faceX, .faceY, .roll, .yaw, .pitch] {
            guard let s = m[feature], let sigma = noise.sigma(feature), let ref = a[feature] else { continue }
            if abs(s.median - ref) > params.shiftK * sigma || s.range > params.rangeK * sigma { return true }
        }
        if let s = m[.faceWidth], let ref = a[.faceWidth], ref > 0, s.median > 0 {
            if abs(s.median / ref - 1) > params.shiftK * noise.widthRel
                || s.range / s.median > params.rangeK * noise.widthRel { return true }
        }
        return false
    }

    private static func medians(_ m: PostureMinute) -> [PostureFeature: Double] {
        var out: [PostureFeature: Double] = [:]
        for feature in [PostureFeature.faceX, .faceY, .faceWidth, .roll, .yaw, .pitch] {
            if let s = m[feature] { out[feature] = s.median }
        }
        return out
    }

    // MARK: - R6 점점 아래로·가까이

    private mutating func drift(_ m: PostureMinute, bout: Date, valid: Bool) -> [SignalEvent] {
        if driftBout != bout {
            driftBout = bout
            referenceSamples = []
            driftReference = nil
            recent = []
            driftStreak = 0
            driftArmed = true
            driftLower = nil
            driftCloser = nil
        }
        guard valid, let y = m[.faceY]?.median, let w = m[.faceWidth]?.median, w > 0 else { return [] }
        let offset = m.start.timeIntervalSince(bout) / 60

        if driftReference == nil {
            if offset >= 5, referenceSamples.count >= 2,
               let ry = Stats.median(referenceSamples.map { $0.y }), let rw = Stats.median(referenceSamples.map { $0.w }) {
                driftReference = (y: ry, w: rw, at: bout.addingTimeInterval(120))
            } else {
                // 앉은 지 2–5분이 기준. 그 사이 얼굴이 잘 안 잡혔으면 8분까지 기다린다.
                if offset >= 2 && offset < 8 { referenceSamples.append((y: y, w: w)) }
                return []
            }
        }
        guard let ref = driftReference else { return [] }

        recent.append((end: m.end, y: y, w: w))
        recent.removeAll { m.end.timeIntervalSince($0.end) > 5 * 60 }
        guard recent.count >= 3, let curY = Stats.median(recent.map { $0.y }), let curW = Stats.median(recent.map { $0.w }) else {
            return []
        }
        let lower = (curY - ref.y) / noise.faceY
        let closer = (curW / ref.w - 1) / noise.widthRel
        driftLower = lower
        driftCloser = closer
        let score = max(lower, closer)

        if score >= params.driftK {
            driftStreak += 1
        } else {
            driftStreak = 0
            if score < params.driftK / 2 { driftArmed = true }
        }
        guard driftStreak >= params.driftHoldMinutes, driftArmed else { return [] }
        driftArmed = false
        return [SignalEvent(rule: .drift, at: m.end, variant: lower >= closer ? "아래로" : "가까이", actionable: true,
                            detail: ["lower_sigma": lower, "closer_sigma": closer,
                                     "lower_pct": (curY - ref.y) * 100, "closer_pct": (curW / ref.w - 1) * 100,
                                     "reference_at": ref.at.timeIntervalSince1970, "minutes_in_bout": offset])]
    }

    // MARK: - R7 가까움

    private mutating func near(_ m: PostureMinute, valid: Bool) -> [SignalEvent] {
        guard let calibration = distance else {
            distanceCm = nil
            return []
        }
        guard valid, let w = m[.faceWidth]?.median, let cm = calibration.distanceCm(faceWidth: w) else { return [] }
        // 고개를 크게 돌린 분은 얼굴 폭이 달라지므로 거리 판정에서 뺀다.
        if let yaw = m[.yaw]?.median, abs(yaw) > 25 { return [] }
        distanceCm = cm
        if cm < params.nearCm {
            nearStreak += 1
        } else {
            nearStreak = 0
            nearArmed = true
        }
        guard nearStreak >= params.nearHoldMinutes, nearArmed else { return [] }
        nearArmed = false
        return [SignalEvent(rule: .near, at: m.end, variant: "\(Int(params.nearCm))cm 미만", actionable: true,
                            detail: ["distance_cm": cm, "minutes": Double(nearStreak)])]
    }
}
