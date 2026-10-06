import Foundation

/// 카메라 한 프레임에서 얻은 얼굴 정보. 각도는 도(°), 얼굴 폭은 프레임 폭 대비 비율(0~1).
public struct PostureSample: Equatable, Sendable {
    public var at: Date
    public var roll: Double
    public var yaw: Double
    public var faceWidth: Double

    public init(at: Date, roll: Double, yaw: Double, faceWidth: Double) {
        self.at = at
        self.roll = roll
        self.yaw = yaw
        self.faceWidth = faceWidth
    }
}

/// 사용자가 "바른 자세"로 저장한 기준값.
public struct PostureBaseline: Codable, Equatable, Sendable {
    public var roll: Double
    public var yaw: Double
    public var faceWidth: Double
    public var savedAt: Date

    public init(roll: Double, yaw: Double, faceWidth: Double, savedAt: Date) {
        self.roll = roll
        self.yaw = yaw
        self.faceWidth = faceWidth
        self.savedAt = savedAt
    }

    /// 여러 샘플의 중앙값으로 기준을 만든다. 샘플이 없으면 nil.
    public static func from(_ samples: [PostureSample], at now: Date) -> PostureBaseline? {
        guard !samples.isEmpty else { return nil }
        return PostureBaseline(roll: median(samples.map(\.roll)),
                               yaw: median(samples.map(\.yaw)),
                               faceWidth: median(samples.map(\.faceWidth)),
                               savedAt: now)
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

/// FR-08~11: 카메라 샘플을 기준 자세와 비교해 R2(기울기·회전), R3(화면 접근)를 판정한다.
///
/// - 최근 샘플 몇 개의 중앙값으로 판정해 순간적인 흔들림을 무시한다.
/// - 벗어난 상태가 `postureHoldSeconds` 동안 이어져야 알림 후보(`pendingRule`)가 된다.
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

        let next = Self.classify(roll: median(recent.map(\.roll)),
                                 yaw: median(recent.map(\.yaw)),
                                 faceWidth: median(recent.map(\.faceWidth)),
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

    /// 알림을 띄웠으면 같은 자세로 다시 누적하도록 초기화한다.
    public mutating func resetDeviation(at now: Date) {
        if deviationSince != nil { deviationSince = now }
    }

    public mutating func reset() {
        recent.removeAll()
        deviationSince = nil
        lastFaceAt = nil
        state = .noFace
    }

    static func classify(roll: Double, yaw: Double, faceWidth: Double,
                         baseline: PostureBaseline, settings: AppSettings) -> PostureState {
        if baseline.faceWidth > 0,
           faceWidth / baseline.faceWidth >= 1 + Double(settings.approachThresholdPercent) / 100 {
            return .approaching
        }
        let tilt = Double(settings.tiltThresholdDegrees)
        // 고개를 돌리는 동작(yaw)은 기울기보다 자연스럽게 크게 움직이므로 1.5배 여유를 둔다.
        if abs(roll - baseline.roll) >= tilt || abs(yaw - baseline.yaw) >= tilt * 1.5 {
            return .tilted
        }
        return .good
    }
}

func median(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let mid = sorted.count / 2
    return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
}
