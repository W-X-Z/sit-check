import Foundation

/// 카메라 프레임에서 뽑는 특징. 위치는 프레임 기준 0~1이고 왼쪽 위가 원점이다 (아래로 갈수록 y가 커짐).
/// 좌우를 비교하는 특징(어깨 높이 차 등)은 일부러 두지 않는다 (진단 전 대칭 판정 금지, NFR-09).
public enum PostureFeature: String, Codable, CaseIterable, Sendable {
    /// 얼굴 각도 (도). 알림에는 쓰지 않고 움직임 감지·품질 확인·비공개 기록에만 쓴다.
    case roll, yaw, pitch
    /// 얼굴 사각형 폭 ÷ 프레임 폭
    case faceWidth
    /// 얼굴 사각형 중심
    case faceX, faceY
    /// 눈동자 사이 거리 ÷ 프레임 폭 (분석 구성: 얼굴 + 랜드마크)
    case eyeDistance
    /// 양 어깨 중점의 y (분석 구성: 얼굴 + 2D 몸 자세)
    case shoulderY
    /// (어깨 중점 y − 코 y) ÷ 어깨 폭, 픽셀 단위 비율 (분석 구성: 얼굴 + 2D 몸 자세)
    case neckRatio
    /// 어깨 폭 ÷ 프레임 폭 (분석 구성: 얼굴 + 2D 몸 자세)
    case shoulderWidth
}

/// 카메라 한 프레임에서 얻은 값. 얼굴을 못 찾은 프레임은 샘플 자체가 없다(nil).
/// 각도는 Vision이 값을 주지 않으면 nil로 두고 0°로 바꾸지 않는다.
public struct PostureSample: Equatable, Sendable {
    public var at: Date
    public var roll: Double?
    public var yaw: Double?
    public var pitch: Double?
    public var faceWidth: Double
    public var faceX: Double
    public var faceY: Double
    public var eyeDistance: Double?
    public var shoulderY: Double?
    public var neckRatio: Double?
    public var shoulderWidth: Double?

    public init(at: Date, roll: Double? = nil, yaw: Double? = nil, pitch: Double? = nil,
                faceWidth: Double, faceX: Double = 0.5, faceY: Double = 0.5,
                eyeDistance: Double? = nil, shoulderY: Double? = nil,
                neckRatio: Double? = nil, shoulderWidth: Double? = nil) {
        self.at = at
        self.roll = roll
        self.yaw = yaw
        self.pitch = pitch
        self.faceWidth = faceWidth
        self.faceX = faceX
        self.faceY = faceY
        self.eyeDistance = eyeDistance
        self.shoulderY = shoulderY
        self.neckRatio = neckRatio
        self.shoulderWidth = shoulderWidth
    }

    public func value(_ feature: PostureFeature) -> Double? {
        switch feature {
        case .roll: return roll
        case .yaw: return yaw
        case .pitch: return pitch
        case .faceWidth: return faceWidth
        case .faceX: return faceX
        case .faceY: return faceY
        case .eyeDistance: return eyeDistance
        case .shoulderY: return shoulderY
        case .neckRatio: return neckRatio
        case .shoulderWidth: return shoulderWidth
        }
    }
}

/// 사용자가 저장한 '평소 자세'. 첫 고정 기준과 자동 기준 비교에만 쓰고, 이것으로 되돌리라고 알리지 않는다.
public struct PostureBaseline: Codable, Equatable, Sendable {
    public var roll: Double
    public var yaw: Double
    public var faceWidth: Double
    public var savedAt: Date
    public var pitch: Double?
    public var faceX: Double?
    public var faceY: Double?
    public var samples: Int?

    public init(roll: Double, yaw: Double, faceWidth: Double, savedAt: Date,
                pitch: Double? = nil, faceX: Double? = nil, faceY: Double? = nil, samples: Int? = nil) {
        self.roll = roll
        self.yaw = yaw
        self.faceWidth = faceWidth
        self.savedAt = savedAt
        self.pitch = pitch
        self.faceX = faceX
        self.faceY = faceY
        self.samples = samples
    }

    /// 여러 샘플의 중앙값으로 기준을 만든다. 샘플이 없으면 nil.
    public static func from(_ samples: [PostureSample], at now: Date) -> PostureBaseline? {
        guard let width = Stats.median(samples.map(\.faceWidth)) else { return nil }
        return PostureBaseline(roll: Stats.median(samples.compactMap(\.roll)) ?? 0,
                               yaw: Stats.median(samples.compactMap(\.yaw)) ?? 0,
                               faceWidth: width,
                               savedAt: now,
                               pitch: Stats.median(samples.compactMap(\.pitch)),
                               faceX: Stats.median(samples.map(\.faceX)),
                               faceY: Stats.median(samples.map(\.faceY)),
                               samples: samples.count)
    }
}

public enum PostureState: Equatable, Sendable {
    case noBaseline
    case noFace
    case good
    /// 기준 대비 고개 기울기(roll) 또는 회전(yaw)이 임계값을 넘음
    case tilted
    /// 기준 대비 얼굴이 커짐 = 화면 쪽으로 다가감
    case approaching

    public var rule: NudgeRule? {
        switch self {
        case .tilted: return .tiltRotation
        case .approaching: return .screenApproach
        default: return nil
        }
    }
}

/// 예전 R2(기울기·회전)·R3(화면 접근) 판정. 카드는 띄우지 않고 '울렸을 알림' 비교 기록에만 쓴다.
/// 얼굴이 언제 마지막으로 보였는지(착석 추정)도 여기서 관리한다.
///
/// - 최근 샘플 몇 개의 중앙값으로 판정해 순간적인 흔들림을 무시한다.
/// - 벗어난 상태가 `postureHoldSeconds` 동안 이어져야 `pendingRule`이 된다.
/// - 얼굴이 잠깐(`faceLossGrace`) 안 보이는 것은 무시하고, 그보다 길면 누적 시간을 초기화한다.
public struct PostureMonitor: Sendable {
    public var smoothingCount = 5
    public var faceLossGrace: TimeInterval = 5

    public private(set) var state: PostureState = .noFace
    public private(set) var lastFaceAt: Date?
    public private(set) var deviationSince: Date?
    private var recent: [PostureSample] = []

    public init() {}

    @discardableResult
    public mutating func update(_ sample: PostureSample?, at now: Date,
                                baseline: PostureBaseline?, settings: AppSettings) -> PostureState {
        guard let sample else {
            if let lastFaceAt, now.timeIntervalSince(lastFaceAt) <= faceLossGrace { return state }
            recent.removeAll()
            deviationSince = nil
            state = .noFace
            return state
        }
        lastFaceAt = now
        recent.append(sample)
        if recent.count > smoothingCount { recent.removeFirst(recent.count - smoothingCount) }

        guard let baseline else {
            deviationSince = nil
            state = .noBaseline
            return state
        }

        let next = Self.classify(roll: Stats.median(recent.compactMap(\.roll)),
                                 yaw: Stats.median(recent.compactMap(\.yaw)),
                                 faceWidth: Stats.median(recent.map(\.faceWidth)) ?? 0,
                                 baseline: baseline, settings: settings)
        if next.rule == nil {
            deviationSince = nil
        } else if next != state || deviationSince == nil {
            deviationSince = now
        }
        state = next
        return state
    }

    /// 벗어난 자세가 충분히 오래 이어졌으면 해당 규칙.
    public func pendingRule(at now: Date, settings: AppSettings) -> NudgeRule? {
        guard let rule = state.rule, let deviationSince,
              now.timeIntervalSince(deviationSince) >= Double(settings.postureHoldSeconds) else { return nil }
        return rule
    }

    /// 마지막으로 얼굴을 본 뒤 지난 시간. 얼굴을 본 적이 없으면 nil.
    public func secondsSinceFace(at now: Date) -> TimeInterval? {
        lastFaceAt.map { max(0, now.timeIntervalSince($0)) }
    }

    /// 한 번 기록했으면 같은 자세로 다시 누적하도록 초기화한다.
    public mutating func resetDeviation(at now: Date) {
        if deviationSince != nil { deviationSince = now }
    }

    public mutating func reset() {
        recent.removeAll()
        deviationSince = nil
        lastFaceAt = nil
        state = .noFace
    }

    static func classify(roll: Double?, yaw: Double?, faceWidth: Double,
                         baseline: PostureBaseline, settings: AppSettings) -> PostureState {
        if baseline.faceWidth > 0,
           faceWidth / baseline.faceWidth >= 1 + Double(settings.approachThresholdPercent) / 100 {
            return .approaching
        }
        let tilt = Double(settings.tiltThresholdDegrees)
        // 고개를 돌리는 동작(yaw)은 기울기보다 자연스럽게 크게 움직이므로 1.5배 여유를 둔다.
        if let roll, abs(roll - baseline.roll) >= tilt { return .tilted }
        if let yaw, abs(yaw - baseline.yaw) >= tilt * 1.5 { return .tilted }
        return .good
    }
}
