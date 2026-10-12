import Foundation

/// 골격(2D 몸 자세)으로 보는 '바르지 않은 자세'.
///
/// - 거북목: 머리가 어깨보다 앞으로 나오면 얼굴이 어깨에 비해 커 보인다 (얼굴 폭 ÷ 어깨 폭).
///   머리·어깨 비율은 사람마다 달라 공통 기준이 없으므로, 앉은 지 2–15분의 자리 잡은 자세와 비교한다.
///   정면 카메라라 옆에서 재는 CVA가 아니라 '머리가 어깨보다 앞으로 나온 정도'의 근사값이다.
/// - 좌우 비대칭: 어깨선·눈선이 수평에서 기운 각도, 머리가 어깨 가운데에서 옆으로 치우친 정도.
///   기준 자세 없이 수평·가운데와 비교한다. 몸통을 10° 돌리면 어깨선이 3–4° 기울어 보이므로 임계값은 그보다 크게 둔다.
public enum PostureIssue: String, Codable, CaseIterable, Comparable, Sendable {
    case forwardHead, shoulderTilt, headTilt, sideLean

    public var title: String {
        switch self {
        case .forwardHead: return "거북목"
        case .shoulderTilt: return "어깨 수평"
        case .headTilt: return "고개 기울기"
        case .sideLean: return "몸 치우침"
        }
    }

    public var rule: NudgeRule { self == .forwardHead ? .forwardHead : .asymmetry }

    /// 카드의 행동 한 줄
    public var action: String {
        switch self {
        case .forwardHead: return "턱을 살짝 당겨 머리를 어깨 위로 되돌려 보세요"
        case .shoulderTilt: return "양 어깨를 으쓱 올렸다가 힘을 빼고 내려 보세요"
        case .headTilt: return "고개를 세우고 화면을 정면으로 봐 보세요"
        case .sideLean: return "엉덩이를 의자 가운데로 옮겨 앉아 보세요"
        }
    }

    public static func < (a: PostureIssue, b: PostureIssue) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

/// 바른 자세 판정값. 근거로 정해진 값이 아니라 출발값이다.
public struct PostureCheckParameters: Codable, Equatable, Sendable {
    public var forwardHead = true
    public var asymmetry = true
    /// 얼굴 폭 ÷ 어깨 폭이 기준보다 이 비율 이상 커지면 거북목 (0.10 = 10%)
    public var forwardHeadRatio = 0.10
    public var shoulderTiltDegrees = 7.0
    public var headTiltDegrees = 10.0
    /// 머리(두 눈 가운데)가 어깨 가운데에서 어깨 폭의 이 비율 넘게 옆으로 가면
    public var sideLeanRatio = 0.25
    /// 바르지 않은 상태가 이 시간(분) 이어지면 카드
    public var cardAfterMinutes = 2

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PostureCheckParameters()
        forwardHead = try c.decodeIfPresent(Bool.self, forKey: .forwardHead) ?? d.forwardHead
        asymmetry = try c.decodeIfPresent(Bool.self, forKey: .asymmetry) ?? d.asymmetry
        forwardHeadRatio = try c.decodeIfPresent(Double.self, forKey: .forwardHeadRatio) ?? d.forwardHeadRatio
        shoulderTiltDegrees = try c.decodeIfPresent(Double.self, forKey: .shoulderTiltDegrees) ?? d.shoulderTiltDegrees
        headTiltDegrees = try c.decodeIfPresent(Double.self, forKey: .headTiltDegrees) ?? d.headTiltDegrees
        sideLeanRatio = try c.decodeIfPresent(Double.self, forKey: .sideLeanRatio) ?? d.sideLeanRatio
        cardAfterMinutes = try c.decodeIfPresent(Int.self, forKey: .cardAfterMinutes) ?? d.cardAfterMinutes
    }

    public func isEnabled(_ issue: PostureIssue) -> Bool {
        issue == .forwardHead ? forwardHead : asymmetry
    }

    func threshold(_ issue: PostureIssue) -> Double {
        switch issue {
        case .forwardHead: return forwardHeadRatio
        case .shoulderTilt: return shoulderTiltDegrees
        case .headTilt: return headTiltDegrees
        case .sideLean: return sideLeanRatio
        }
    }
}

/// 이미지 위의 한 점 (픽셀, 왼쪽 아래 원점)
public struct PixelPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// 골격 점에서 자세 수치를 계산한다.
public enum BodyGeometry {
    /// 어깨 폭이 프레임 폭의 이 비율보다 좁으면 (옆으로 앉았거나 잘못 잡힌 것) 쓰지 않는다.
    /// 책상 앞 웹캠은 상반신만 보여 어깨가 좁게 잡히므로 너무 높으면 판정이 통째로 빠진다.
    public static let minShoulderWidth = 0.10

    /// 좌우 반전하지 않은 카메라 영상에서는 사용자의 왼쪽이 화면 오른쪽(x가 큰 쪽)에 있다.
    /// Vision의 관절 이름 대신 위치로 좌우를 정해, 이름 규칙이나 반전 여부가 바뀌어도 방향이 뒤집히지 않게 한다.
    public static func apply(shoulders: (PixelPoint, PixelPoint), eyes: (PixelPoint, PixelPoint)?,
                             faceWidthPx: Double, frameWidth: Double, frameHeight: Double,
                             to sample: inout PostureSample) {
        let (sRight, sLeft) = ordered(shoulders)
        let shoulderPx = distance(sRight, sLeft)
        guard frameWidth > 0, frameHeight > 0, shoulderPx >= minShoulderWidth * frameWidth else { return }
        let mid = PixelPoint(x: (sRight.x + sLeft.x) / 2, y: (sRight.y + sLeft.y) / 2)

        sample.shoulderWidth = shoulderPx / frameWidth
        sample.shoulderY = 1 - mid.y / frameHeight
        sample.shoulderTilt = angle(from: sRight, to: sLeft)
        sample.headScale = faceWidthPx / shoulderPx

        guard let eyes else { return }
        let (eRight, eLeft) = ordered(eyes)
        let eyeMid = PixelPoint(x: (eRight.x + eLeft.x) / 2, y: (eRight.y + eLeft.y) / 2)
        sample.headTilt = angle(from: eRight, to: eLeft)
        sample.neckRatio = (eyeMid.y - mid.y) / shoulderPx
        sample.sideLean = (eyeMid.x - mid.x) / shoulderPx
    }

    /// (사용자의 오른쪽, 왼쪽)
    static func ordered(_ pair: (PixelPoint, PixelPoint)) -> (PixelPoint, PixelPoint) {
        pair.0.x <= pair.1.x ? pair : (pair.1, pair.0)
    }

    static func distance(_ a: PixelPoint, _ b: PixelPoint) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    /// 오른쪽 점에서 왼쪽 점으로 가는 선이 수평과 이루는 각도 (도). 양수면 사용자의 왼쪽이 높다.
    static func angle(from right: PixelPoint, to left: PixelPoint) -> Double {
        atan2(left.y - right.y, left.x - right.x) * 180 / .pi
    }
}

/// 거북목 비교 기준: 앉은 지 2–15분, 몸이 잘 잡힌 분들의 분별 중앙값의 중앙값.
public struct UprightReference: Equatable, Sendable {
    public var headScale: Double
    public var neckRatio: Double
    public var minutes: Int

    public static let requiredMinutes = 5
    public static let settledRange: ClosedRange<Double> = 2...15
    public static let minFrames = 20

    public var isReady: Bool { minutes >= Self.requiredMinutes }

    public static func isSettled(_ m: PostureMinute) -> Bool {
        guard m.label == nil, let into = m.minutesIntoBout, settledRange.contains(into),
              let scale = m[.headScale], scale.n >= minFrames, m[.neckRatio] != nil else { return false }
        return true
    }

    /// 자리 잡은 분이 하나도 없으면 nil
    public static func build(from minutes: [PostureMinute]) -> UprightReference? {
        let settled = minutes.filter(isSettled)
        guard let scale = Stats.median(settled.compactMap { $0[.headScale]?.median }),
              let neck = Stats.median(settled.compactMap { $0[.neckRatio]?.median }) else { return nil }
        return UprightReference(headScale: scale, neckRatio: neck, minutes: settled.count)
    }
}

/// 최근 몇 초의 중앙값으로 본 지금 자세
public struct PostureReading: Equatable, Sendable {
    /// 도. 양수면 사용자의 왼쪽 어깨가 높다.
    public var shoulderTilt: Double?
    /// 도. 양수면 왼쪽 눈이 높다. 화면 문구는 거울 미리보기·실제 고개와 맞게 반대로 적는다.
    public var headTilt: Double?
    /// 어깨 폭 대비. 양수면 머리가 사용자의 왼쪽으로 치우쳤다.
    public var sideLean: Double?
    /// 기준 대비 얼굴 폭 ÷ 어깨 폭의 변화 (0.1 = 10% 커짐 = 머리가 앞으로). 기준이 없으면 nil.
    public var headForward: Double?
    /// 기준 대비 눈–어깨 세로 간격이 줄어든 비율 (음수면 늘어남). 기준이 없으면 nil.
    public var neckDrop: Double?

    public init(shoulderTilt: Double? = nil, headTilt: Double? = nil, sideLean: Double? = nil,
                headForward: Double? = nil, neckDrop: Double? = nil) {
        self.shoulderTilt = shoulderTilt
        self.headTilt = headTilt
        self.sideLean = sideLean
        self.headForward = headForward
        self.neckDrop = neckDrop
    }

    public init(detail: [String: Double]) {
        self.init(shoulderTilt: detail["shoulder_tilt"], headTilt: detail["head_tilt"], sideLean: detail["side_lean"],
                  headForward: detail["head_forward"], neckDrop: detail["neck_drop"])
    }

    public var detail: [String: Double] {
        var d: [String: Double] = [:]
        d["shoulder_tilt"] = shoulderTilt
        d["head_tilt"] = headTilt
        d["side_lean"] = sideLean
        d["head_forward"] = headForward
        d["neck_drop"] = neckDrop
        return d
    }

    public func value(_ issue: PostureIssue) -> Double? {
        switch issue {
        case .forwardHead: return headForward
        case .shoulderTilt: return shoulderTilt
        case .headTilt: return headTilt
        case .sideLean: return sideLean
        }
    }

    /// 잰 값을 방향과 함께 한 구절로. 값이 없으면 nil.
    public func phrase(_ issue: PostureIssue) -> String? {
        guard let v = value(issue) else { return nil }
        switch issue {
        case .forwardHead:
            let pct = Int((v * 100).rounded())
            return pct > 0 ? "머리가 기준보다 앞으로 \(pct)%" : "머리가 기준 위치 (\(pct)%)"
        case .shoulderTilt:
            let deg = Int(abs(v).rounded())
            return deg == 0 ? "어깨 수평" : "\(v > 0 ? "오른쪽" : "왼쪽") 어깨가 \(deg)° 높음"
        case .headTilt:
            let deg = Int(abs(v).rounded())
            return deg == 0 ? "고개 똑바름" : "고개가 \(v > 0 ? "왼쪽" : "오른쪽")으로 \(deg)°"
        case .sideLean:
            let pct = Int((abs(v) * 100).rounded())
            return pct < 5 ? "머리가 어깨 가운데" : "머리가 \(v > 0 ? "오른쪽" : "왼쪽")으로 어깨 폭의 \(pct)%"
        }
    }
}

/// 1초마다 들어오는 골격 수치로 지금 자세가 바른지 판정한다.
///
/// - 최근 `window`초 중앙값으로 판정해 순간적인 움직임(키보드 내려다보기 등)을 무시한다.
/// - 한 번 바르지 않음으로 본 항목은 임계값의 `hysteresis`배 아래로 내려와야 풀린다 (경계에서 깜빡임 방지).
/// - 거북목은 눈–어깨 간격이 같이 늘어난 경우(몸통을 돌려 어깨가 좁아 보인 경우)는 세지 않는다.
public struct PostureChecker: Sendable {
    public var params: PostureCheckParameters
    public var reference: UprightReference?
    public var window: TimeInterval = 15
    public var minSamples = 6
    /// 몸이 이보다 오래 안 보이면 이어지던 '바르지 않음' 시간을 버린다.
    public var lossGrace: TimeInterval = 30
    public var hysteresis = 0.8
    /// 고개를 이보다 많이 돌리면 몸 치우침은 보지 않는다 (눈 위치가 같이 옮겨 가므로).
    public var maxYawForLean = 25.0
    /// 눈–어깨 간격이 이보다 더 늘어났으면 거북목으로 보지 않는다.
    public var maxNeckGrowth = 0.03

    public private(set) var reading: PostureReading?
    public private(set) var issues: Set<PostureIssue> = []
    /// 바르지 않은 상태가 이어지기 시작한 시각
    public private(set) var badSince: Date?
    private var recent: [PostureSample] = []
    private var lastBodyAt: Date?

    public init(params: PostureCheckParameters = PostureCheckParameters(), reference: UprightReference? = nil) {
        self.params = params
        self.reference = reference
    }

    public var hasBody: Bool { reading != nil }

    public mutating func update(_ sample: PostureSample?, at now: Date) {
        recent.removeAll { now.timeIntervalSince($0.at) > window }
        if var sample {
            // 어깨가 안 잡혀도 얼굴 기울기(roll)로 고개는 판정한다.
            if sample.headTilt == nil, let roll = sample.roll { sample.headTilt = roll }
            if sample.shoulderWidth != nil || sample.headTilt != nil {
                recent.append(sample)
                lastBodyAt = now
            }
        }
        guard recent.count >= minSamples else {
            reading = nil
            issues = []
            if lastBodyAt.map({ now.timeIntervalSince($0) > lossGrace }) ?? true { badSince = nil }
            return
        }
        let next = Self.read(recent, reference: reference, maxYawForLean: maxYawForLean)
        reading = next
        issues = judge(next)
        if issues.isEmpty {
            badSince = nil
        } else if badSince == nil {
            badSince = now
        }
    }

    /// 바르지 않은 상태가 이어진 시간 (분)
    public func badMinutes(at now: Date) -> Double? {
        badSince.map { max(0, now.timeIntervalSince($0) / 60) }
    }

    /// 바르지 않은 상태가 `cardAfterMinutes` 넘게 이어졌으면 카드 후보. `excluding`의 항목은 빼고 본다.
    public func cardEvent(at now: Date, excluding: Set<PostureIssue> = []) -> SignalEvent? {
        let shown = issues.subtracting(excluding)
        guard !shown.isEmpty, let reading, let minutes = badMinutes(at: now),
              minutes >= Double(params.cardAfterMinutes) else { return nil }
        var detail = reading.detail
        detail["bad_minutes"] = minutes
        for issue in shown { detail[issue.rawValue] = 1 }
        let rule: NudgeRule = shown.contains(.forwardHead) ? .forwardHead : .asymmetry
        return SignalEvent(rule: rule, at: now, variant: shown.sorted().map(\.rawValue).joined(separator: ","),
                           actionable: true, detail: detail)
    }

    /// 카드를 본 뒤 고쳐 앉았다고 하면 이어지던 시간을 처음부터 다시 센다.
    public mutating func restartBadTimer(at now: Date) {
        if badSince != nil { badSince = now }
    }

    public mutating func reset() {
        recent.removeAll()
        reading = nil
        issues = []
        badSince = nil
        lastBodyAt = nil
    }

    static func read(_ samples: [PostureSample], reference: UprightReference?, maxYawForLean: Double) -> PostureReading {
        var r = PostureReading(shoulderTilt: Stats.median(samples.compactMap(\.shoulderTilt)),
                               headTilt: Stats.median(samples.compactMap(\.headTilt)),
                               sideLean: Stats.median(samples.filter { abs($0.yaw ?? 0) <= maxYawForLean }.compactMap(\.sideLean)))
        if let reference, reference.isReady, reference.headScale > 0, reference.neckRatio > 0 {
            r.headForward = Stats.median(samples.compactMap(\.headScale)).map { $0 / reference.headScale - 1 }
            r.neckDrop = Stats.median(samples.compactMap(\.neckRatio)).map { 1 - $0 / reference.neckRatio }
        }
        return r
    }

    func judge(_ r: PostureReading) -> Set<PostureIssue> {
        var out: Set<PostureIssue> = []
        for issue in PostureIssue.allCases where params.isEnabled(issue) {
            guard let v = r.value(issue) else { continue }
            let limit = params.threshold(issue) * (issues.contains(issue) ? hysteresis : 1)
            switch issue {
            case .forwardHead:
                if v >= limit, (r.neckDrop ?? 0) >= -maxNeckGrowth { out.insert(issue) }
            case .shoulderTilt, .headTilt, .sideLean:
                if abs(v) >= limit { out.insert(issue) }
            }
        }
        return out
    }
}
