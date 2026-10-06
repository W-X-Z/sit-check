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

    public init() {}

    public static let `default` = AppSettings()

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
    }
}
