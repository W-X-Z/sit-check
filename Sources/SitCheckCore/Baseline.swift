import Foundation

/// 앉은 직후 자리 잡은 분들로 만든 '평소 자세' (제안 C를 고친 형태).
/// 공통 인체공학 기준(수평 등)으로 거르지 않고, 시간·안정성·품질로만 고른다.
public struct AutoBaseline: Codable, Equatable, Sendable {
    public var faceX: Double
    public var faceY: Double
    public var faceWidth: Double
    /// 분 중앙값들 사이의 흩어짐 (강건 표준편차). 설치 변화 판정에 쓴다.
    public var spreadX: Double
    public var spreadY: Double
    public var spreadWidthRel: Double
    /// 후보 분들의 분 안 흔들림
    public var noise: NoiseModel
    /// 후보 분이 나온 서로 다른 날 수
    public var days: Int
    public var minutes: Int
    public var from: Date
    public var to: Date

    public static let requiredDays = 3
    public static let requiredMinutes = 30

    public var isReady: Bool { days >= Self.requiredDays && minutes >= Self.requiredMinutes }

    /// 기준 후보: 실험 라벨이 없고, 앉은 지 2–15분이고, 얼굴이 80% 넘게 잡히고,
    /// 화면 쪽을 보고(|yaw| ≤ 20°, 품질 조건), 그 분 안에 크게 움직이지 않은 분.
    public static func isCandidate(_ m: PostureMinute, noise: NoiseModel, params: SignalParameters) -> Bool {
        guard m.label == nil, let offset = m.minutesIntoBout, offset >= 2, offset < 15,
              m.frames >= params.minFrames, m.validRatio >= 0.8,
              let y = m[.faceY], let w = m[.faceWidth], w.median > 0 else { return false }
        if let yaw = m[.yaw]?.median, abs(yaw) > 20 { return false }
        return y.range <= params.rangeK * noise.faceY && w.range / w.median <= params.rangeK * noise.widthRel
    }

    public static func build(from minutes: [PostureMinute], noise: NoiseModel = .defaults,
                             params: SignalParameters = SignalParameters(),
                             calendar: Calendar = .current) -> AutoBaseline? {
        let candidates = minutes
            .filter { isCandidate($0, noise: noise, params: params) }
            .sorted { $0.start < $1.start }
        guard let first = candidates.first, let last = candidates.last else { return nil }
        let xs = candidates.compactMap { $0[.faceX]?.median }
        let ys = candidates.compactMap { $0[.faceY]?.median }
        let ws = candidates.compactMap { $0[.faceWidth]?.median }
        guard let x = Stats.median(xs), let y = Stats.median(ys), let w = Stats.median(ws), w > 0 else { return nil }
        func spread(_ values: [Double]) -> Double { (Stats.mad(values) ?? 0) * Stats.madToSigma }
        let days = Set(candidates.map { calendar.startOfDay(for: $0.start) }).count
        return AutoBaseline(faceX: x, faceY: y, faceWidth: w,
                            spreadX: spread(xs), spreadY: spread(ys), spreadWidthRel: spread(ws.map { $0 / w }),
                            noise: NoiseModel.estimate(from: candidates, source: "자동 (\(candidates.count)분)") ?? noise,
                            days: days, minutes: candidates.count, from: first.start, to: last.end)
    }

    /// 다른 기준(예: 사용자가 저장한 평소 자세)과의 차이. 특징별 흩어짐 단위 중 가장 큰 값.
    public func difference(faceX x: Double, faceY y: Double, faceWidth w: Double) -> Double {
        let dx = abs(x - faceX) / max(spreadX, noise.faceX)
        let dy = abs(y - faceY) / max(spreadY, noise.faceY)
        let dw = abs(w / faceWidth - 1) / max(spreadWidthRel, noise.widthRel)
        return max(dx, dy, dw)
    }
}

/// 새 착석 구간의 처음 몇 분이 평소 자세 기준에서 크게 벗어나면 '자리나 화면 위치가 바뀌었을 수 있음'.
/// 의자·모니터가 바뀐 뒤의 기준은 다른 사람의 기준과 같으므로, 이때는 알림을 멈추고 다시 배울지 묻는다.
public struct SetupChangeDetector: Sendable {
    /// 흩어짐(강건 표준편차)의 몇 배를 넘으면 벗어난 것으로 보는지
    public var threshold: Double = 4
    /// 처음 몇 분을 모아 판단하는지
    public var minutesNeeded = 3

    private var bout: Date?
    private var samples: [(x: Double, y: Double, w: Double)] = []
    private var decided = false

    public init() {}

    /// 벗어났다고 판단하면 (가장 큰 차이, 벗어난 특징 수)
    public mutating func process(_ m: PostureMinute, baseline: AutoBaseline?) -> (score: Double, features: Int)? {
        guard let start = m.boutStart, let baseline, baseline.isReady else { return nil }
        if bout != start {
            bout = start
            samples = []
            decided = false
        }
        guard !decided, m.label == nil, m.validRatio >= 0.8, let offset = m.minutesIntoBout, offset >= 1, offset < 8,
              let x = m[.faceX]?.median, let y = m[.faceY]?.median, let w = m[.faceWidth]?.median, w > 0 else { return nil }
        samples.append((x: x, y: y, w: w))
        guard samples.count >= minutesNeeded,
              let mx = Stats.median(samples.map { $0.x }),
              let my = Stats.median(samples.map { $0.y }),
              let mw = Stats.median(samples.map { $0.w }) else { return nil }
        decided = true
        let noise = baseline.noise
        let deviations = [
            abs(mx - baseline.faceX) / max(baseline.spreadX, 1.5 * noise.faceX),
            abs(my - baseline.faceY) / max(baseline.spreadY, 1.5 * noise.faceY),
            abs(mw / baseline.faceWidth - 1) / max(baseline.spreadWidthRel, 1.5 * noise.widthRel),
        ]
        let count = deviations.filter { $0 > threshold }.count
        return count >= 2 ? (deviations.max() ?? 0, count) : nil
    }
}
