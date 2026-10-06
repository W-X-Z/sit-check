import Foundation

/// 설정에서 바꿀 수 있는 임계값과 처방 옵션. settings 테이블에 JSON 한 덩어리로 저장한다.
public struct AppSettings: Codable, Equatable, Sendable {
    /// R1: 연속 착석 알림 기준 (분)
    public var sitAlertMinutes: Int = 40
    /// FR-02: 입력이 없으면 자리 비움으로 보는 시간 (분)
    public var awayAfterMinutes: Int = 3
    /// FR-07
    public var snoozeMinutes: Int = 10
    public var muteMinutes: Int = 60
    /// 한 알림 뒤 다른 알림을 띄우지 않는 시간 (분)
    public var cooldownMinutes: Int = 15
    /// FR-13 / R4
    public var breathEnabled: Bool = true
    public var breathIntervalMinutes: Int = 20
    /// FR-14: 처방에서 제외할 동작 (사용자가 직접 지정 + 통증·저림 기록 시 자동 추가)
    public var excludedStretchIDs: Set<String> = []
    /// 동작별 추가 세트. 기획서 초기값은 S3 오른쪽 30초지만,
    /// 진단 전 좌우 편향 처방을 막는 NFR-09와 충돌하므로 기본값은 비워 둔다.
    public var extraSets: [String: ExtraSet] = [:]

    // MARK: 카메라

    /// FR-08: 카메라 사용. 영상은 저장하지 않고 분 단위 요약 수치만 남긴다.
    public var cameraEnabled: Bool = true
    /// 카메라 신호를 카드로 띄울지, 기록만 할지. 측정 기간에는 기록만 한다.
    public var postureAlertMode: PostureAlertMode = .shadow
    /// R5–R7 판정값
    public var signals: SignalParameters = SignalParameters()
    /// 카메라 카드 하루 상한
    public var postureCardsPerDay: Int = 3
    /// 같은 카메라 카드를 다시 띄우기까지의 기본 간격 (분). 무시하거나 미루면 두 배씩 늘어난다.
    public var postureRepeatMinutes: Int = 30
    /// 하루 무작위 확인 질문 수 (0이면 끔)
    public var checkInsPerDay: Int = 2
    /// 카드 조건이 된 순간 중 아이콘만 보여 줄 비율 (%, 실험 8)
    public var iconOnlyPercent: Int = 0
    /// 분석 구성 (실험 1)
    public var analysisMode: AnalysisMode = .face
    /// 카메라를 지원되는 가장 낮은 프레임 속도로 묶는다 (실험 1에서 전후 비교)
    public var capFrameRate: Bool = true
    /// 고정해서 쓸 카메라 (처음 켤 때 내장 카메라로 정한다)
    public var cameraUniqueID: String?
    /// 줄자로 잰 거리에서 저장한 보정값 (실험 6)
    public var distanceCalibration: DistanceCalibration?
    /// 사용자가 저장한 '평소 자세'
    public var postureBaseline: PostureBaseline?
    /// 카메라 기록을 처음 시작한 시각 (측정 기간 계산)
    public var measurementStartedAt: Date?
    /// '자리가 바뀌었어요 → 다시 배우기'를 누른 시각. 자동 기준은 이 뒤의 기록으로만 만든다.
    public var baselineResetAt: Date?

    // MARK: 예전 R2·R3 (기록 전용)

    public var tiltThresholdDegrees: Int = 12
    public var approachThresholdPercent: Int = 15
    public var postureHoldSeconds: Int = 90

    public init() {}

    public static let `default` = AppSettings()

    /// 판정에 영향을 주는 설정의 지문 (FNV-1a). 분 단위 기록에 남겨, 기록 재생 때 설정이 같은 구간끼리 묶는다.
    public var detectionVersion: Int {
        struct Fingerprint: Encodable {
            var signals: SignalParameters
            var analysisMode: AnalysisMode
            var capFrameRate: Bool
            var distanceCalibration: DistanceCalibration?
            var cameraUniqueID: String?
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(Fingerprint(signals: signals, analysisMode: analysisMode, capFrameRate: capFrameRate,
                                                     distanceCalibration: distanceCalibration,
                                                     cameraUniqueID: cameraUniqueID))) ?? Data()
        var hash: UInt32 = 2_166_136_261
        for byte in data {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return Int(hash)
    }

    // 새 필드가 추가돼도 이전 JSON을 읽을 수 있도록 누락된 키는 기본값을 쓴다.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        sitAlertMinutes = try c.decodeIfPresent(Int.self, forKey: .sitAlertMinutes) ?? d.sitAlertMinutes
        awayAfterMinutes = try c.decodeIfPresent(Int.self, forKey: .awayAfterMinutes) ?? d.awayAfterMinutes
        snoozeMinutes = try c.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? d.snoozeMinutes
        muteMinutes = try c.decodeIfPresent(Int.self, forKey: .muteMinutes) ?? d.muteMinutes
        cooldownMinutes = try c.decodeIfPresent(Int.self, forKey: .cooldownMinutes) ?? d.cooldownMinutes
        breathEnabled = try c.decodeIfPresent(Bool.self, forKey: .breathEnabled) ?? d.breathEnabled
        breathIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .breathIntervalMinutes) ?? d.breathIntervalMinutes
        excludedStretchIDs = try c.decodeIfPresent(Set<String>.self, forKey: .excludedStretchIDs) ?? d.excludedStretchIDs
        extraSets = try c.decodeIfPresent([String: ExtraSet].self, forKey: .extraSets) ?? d.extraSets
        cameraEnabled = try c.decodeIfPresent(Bool.self, forKey: .cameraEnabled) ?? d.cameraEnabled
        postureAlertMode = try c.decodeIfPresent(PostureAlertMode.self, forKey: .postureAlertMode) ?? d.postureAlertMode
        signals = try c.decodeIfPresent(SignalParameters.self, forKey: .signals) ?? d.signals
        postureCardsPerDay = try c.decodeIfPresent(Int.self, forKey: .postureCardsPerDay) ?? d.postureCardsPerDay
        postureRepeatMinutes = try c.decodeIfPresent(Int.self, forKey: .postureRepeatMinutes) ?? d.postureRepeatMinutes
        checkInsPerDay = try c.decodeIfPresent(Int.self, forKey: .checkInsPerDay) ?? d.checkInsPerDay
        iconOnlyPercent = try c.decodeIfPresent(Int.self, forKey: .iconOnlyPercent) ?? d.iconOnlyPercent
        analysisMode = try c.decodeIfPresent(AnalysisMode.self, forKey: .analysisMode) ?? d.analysisMode
        capFrameRate = try c.decodeIfPresent(Bool.self, forKey: .capFrameRate) ?? d.capFrameRate
        cameraUniqueID = try c.decodeIfPresent(String.self, forKey: .cameraUniqueID)
        distanceCalibration = try c.decodeIfPresent(DistanceCalibration.self, forKey: .distanceCalibration)
        postureBaseline = try c.decodeIfPresent(PostureBaseline.self, forKey: .postureBaseline)
        measurementStartedAt = try c.decodeIfPresent(Date.self, forKey: .measurementStartedAt)
        baselineResetAt = try c.decodeIfPresent(Date.self, forKey: .baselineResetAt)
        tiltThresholdDegrees = try c.decodeIfPresent(Int.self, forKey: .tiltThresholdDegrees) ?? d.tiltThresholdDegrees
        approachThresholdPercent = try c.decodeIfPresent(Int.self, forKey: .approachThresholdPercent) ?? d.approachThresholdPercent
        postureHoldSeconds = try c.decodeIfPresent(Int.self, forKey: .postureHoldSeconds) ?? d.postureHoldSeconds
    }
}
