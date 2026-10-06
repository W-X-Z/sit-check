import Foundation

/// 카메라 분석 구성. 실험 1에서 구성별 CPU와 분석 시간을 비교한다.
public enum AnalysisMode: String, Codable, CaseIterable, Sendable {
    /// 얼굴 사각형 (roll·yaw·pitch, 위치, 크기)
    case face
    /// + 얼굴 랜드마크 (눈동자 사이 거리)
    case faceLandmarks
    /// + 2D 몸 자세 (어깨 위치·폭, 코–어깨 세로 비율)
    case faceBody

    public var label: String {
        switch self {
        case .face: return "얼굴만"
        case .faceLandmarks: return "얼굴 + 랜드마크"
        case .faceBody: return "얼굴 + 2D 몸 자세"
        }
    }
}

/// 1분(또는 라벨·분석 구성·착석 구간이 바뀌기 전까지) 동안의 특징 요약.
/// 영상이나 프레임별 좌표는 저장하지 않고 이 요약만 남긴다 (NFR-01).
public struct PostureMinute: Codable, Equatable, Sendable {
    public var id: Int64?
    public var start: Date
    public var end: Date
    /// 실험 라벨 (`ExperimentLabel.rawValue`). 평소 사용 중에는 nil.
    public var label: String?
    public var mode: AnalysisMode
    /// 카메라 프레임 속도를 최저로 묶었는지 (실험 1 전후 비교)
    public var frameCap: Bool?
    /// 분석한 프레임 수
    public var frames: Int
    /// 얼굴을 찾은 프레임 수
    public var faceFrames: Int
    /// `PostureFeature.rawValue` → 요약
    public var stats: [String: FeatureStat]
    /// 프레임 하나를 분석하는 데 걸린 평균 시간 (ms)
    public var analysisMs: Double?
    /// 이 구간 동안 앱 전체의 CPU 사용률 (코어 1개 = 100%)
    public var cpuPercent: Double?
    /// 이 구간이 속한 착석 구간의 시작. 앉아 있지 않았으면 nil.
    public var boutStart: Date?
    /// 판정 설정이 바뀔 때마다 올라가는 번호. 기록 재생 때 설정이 같은 구간끼리 묶는다.
    public var settingsVersion: Int

    public init(id: Int64? = nil, start: Date, end: Date, label: String? = nil, mode: AnalysisMode = .face,
                frameCap: Bool? = nil, frames: Int, faceFrames: Int, stats: [String: FeatureStat],
                analysisMs: Double? = nil, cpuPercent: Double? = nil, boutStart: Date? = nil, settingsVersion: Int = 0) {
        self.id = id
        self.start = start
        self.end = end
        self.label = label
        self.mode = mode
        self.frameCap = frameCap
        self.frames = frames
        self.faceFrames = faceFrames
        self.stats = stats
        self.analysisMs = analysisMs
        self.cpuPercent = cpuPercent
        self.boutStart = boutStart
        self.settingsVersion = settingsVersion
    }

    public subscript(_ feature: PostureFeature) -> FeatureStat? { stats[feature.rawValue] }

    /// 얼굴이 잡힌 프레임 비율
    public var validRatio: Double { frames > 0 ? Double(faceFrames) / Double(frames) : 0 }

    /// 착석 구간이 시작된 뒤 이 구간이 시작되기까지 (분)
    public var minutesIntoBout: Double? { boutStart.map { start.timeIntervalSince($0) / 60 } }
}

/// 프레임별 분석 결과를 분 단위 요약으로 모은다.
public struct MinuteAggregator: Sendable {
    /// 이 값이 바뀌면 진행 중인 구간을 닫고 새로 시작한다.
    public struct Context: Equatable, Sendable {
        public var label: String?
        public var mode: AnalysisMode
        public var frameCap: Bool?
        public var boutStart: Date?
        public var settingsVersion: Int

        public init(label: String? = nil, mode: AnalysisMode = .face, frameCap: Bool? = nil,
                    boutStart: Date? = nil, settingsVersion: Int = 0) {
            self.label = label
            self.mode = mode
            self.frameCap = frameCap
            self.boutStart = boutStart
            self.settingsVersion = settingsVersion
        }
    }

    private struct Bucket: Sendable {
        var start: Date
        var last: Date
        var context: Context
        var frames = 0
        var faceFrames = 0
        var values: [PostureFeature: [Double]] = [:]
        var analysisMsTotal = 0.0
        var analysisCount = 0
    }

    private var bucket: Bucket?

    public init() {}

    public var isEmpty: Bool { bucket == nil }

    /// 프레임 하나의 결과를 넣는다 (얼굴이 없으면 `sample`이 nil).
    /// 분이 바뀌었거나 맥락이 바뀌었으면 이전 구간을 닫아 돌려준다.
    public mutating func add(_ sample: PostureSample?, at now: Date, analysisMs: Double?, context: Context) -> PostureMinute? {
        var closed: PostureMinute?
        if let b = bucket, b.context != context || Self.minuteIndex(now) != Self.minuteIndex(b.start) {
            closed = Self.close(b, at: now)
            bucket = nil
        }
        var b = bucket ?? Bucket(start: now, last: now, context: context)
        b.last = now
        b.frames += 1
        if let analysisMs {
            b.analysisMsTotal += analysisMs
            b.analysisCount += 1
        }
        if let sample {
            b.faceFrames += 1
            for feature in PostureFeature.allCases {
                if let v = sample.value(feature), v.isFinite { b.values[feature, default: []].append(v) }
            }
        }
        bucket = b
        return closed
    }

    /// 진행 중인 구간을 닫는다 (카메라 정지, 화면 잠금 등).
    public mutating func flush(at now: Date) -> PostureMinute? {
        guard let b = bucket else { return nil }
        bucket = nil
        return Self.close(b, at: now)
    }

    static func minuteIndex(_ date: Date) -> Int {
        Int((date.timeIntervalSince1970 / 60).rounded(.down))
    }

    private static func close(_ b: Bucket, at now: Date) -> PostureMinute {
        // 끝 시각: 분 경계, 마지막 프레임 + 1초, 지금 중 가장 이른 값 (중간에 끊긴 시간을 넣지 않는다)
        let boundary = Date(timeIntervalSince1970: Double(minuteIndex(b.start) + 1) * 60)
        let end = max(b.start, min(boundary, b.last.addingTimeInterval(1), now))
        var stats: [String: FeatureStat] = [:]
        for (feature, values) in b.values {
            if let stat = FeatureStat(values) { stats[feature.rawValue] = stat }
        }
        return PostureMinute(start: b.start, end: end, label: b.context.label, mode: b.context.mode,
                             frameCap: b.context.frameCap, frames: b.frames, faceFrames: b.faceFrames, stats: stats,
                             analysisMs: b.analysisCount > 0 ? b.analysisMsTotal / Double(b.analysisCount) : nil,
                             cpuPercent: nil, boutStart: b.context.boutStart,
                             settingsVersion: b.context.settingsVersion)
    }
}

/// 실험 중 분 단위 기록에 붙이는 라벨. 라벨이 붙은 구간은 알림 판정과 자동 기준에서 뺀다.
public enum ExperimentLabel: String, CaseIterable, Codable, Sendable {
    /// 실험 3: 평소처럼 읽으며 가만히 앉아 있기
    case still
    /// 실험 4의 동작들
    case natural, lookDown, phone, sideScreen, leanIn, sink, recline, sideLean, chairMove

    public var title: String {
        switch self {
        case .still: return "평소처럼 읽으며 가만히 앉아 있기"
        case .natural: return "자연스럽게 앉기"
        case .lookDown: return "키보드와 메모 내려다보기"
        case .phone: return "휴대폰 보기"
        case .sideScreen: return "옆 화면(또는 화면 가장자리) 보기"
        case .leanIn: return "작은 글씨에 다가가기"
        case .sink: return "의자에 몸 전체로 가라앉기"
        case .recline: return "등받이에 기대기"
        case .sideLean: return "팔걸이 쪽으로 옆으로 기대기"
        case .chairMove: return "의자 거리와 높이 바꾸기"
        }
    }

    public var instruction: String {
        switch self {
        case .still: return "화면의 글을 평소처럼 읽으세요. 일부러 굳어 있을 필요는 없어요."
        case .natural: return "평소 일할 때처럼 편하게 앉아 화면을 보세요."
        case .lookDown: return "키보드나 책상 위 메모를 내려다보세요. 몸은 그대로 두고 고개만 숙여요."
        case .phone: return "휴대폰을 손에 들고 평소처럼 보세요."
        case .sideScreen: return "옆 모니터나 화면 한쪽 끝을 보세요."
        case .leanIn: return "화면의 작은 글씨를 읽으려고 앞으로 다가가세요."
        case .sink: return "엉덩이를 앞으로 빼며 의자에 몸 전체로 가라앉으세요 (앞뒤로만, 옆으로 기울지 않기)."
        case .recline: return "등받이에 기대어 화면을 보세요."
        case .sideLean: return "한쪽 팔걸이에 기대세요. 혼동되는지 확인하는 동작이에요 (좌우 판정용이 아님)."
        case .chairMove: return "의자를 당기거나 밀고 높이를 바꾼 뒤 그대로 앉아 있으세요. 끝나면 원래대로 돌려 두세요."
        }
    }

    /// 실험 4에서 '처짐·다가감' 신호가 잡혀야 하는 동작인지(true), 잡히면 안 되는 동작인지(false)
    public var shouldTrigger: Bool? {
        switch self {
        case .sink, .leanIn: return true
        case .lookDown, .sideScreen, .sideLean: return false
        default: return nil
        }
    }

    /// 실험 4 순서: 자연스럽게 앉기로 시작해 나머지를 무작위로 하고, 의자 바꾸기는 마지막에 한다.
    public static func protocolSteps<G: RandomNumberGenerator>(using rng: inout G) -> [ExperimentLabel] {
        let middle: [ExperimentLabel] = [.lookDown, .phone, .sideScreen, .leanIn, .sink, .recline, .sideLean]
        return [.natural] + middle.shuffled(using: &rng) + [.chairMove]
    }
}
