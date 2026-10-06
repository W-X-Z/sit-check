import Foundation

public struct NudgeRecord: Equatable, Sendable {
    public var id: Int64?
    public var at: Date
    public var rule: NudgeRule
    public var stretchIDs: [String]
    public var action: NudgeAction

    public init(id: Int64? = nil, at: Date, rule: NudgeRule, stretchIDs: [String], action: NudgeAction) {
        self.id = id
        self.at = at
        self.rule = rule
        self.stretchIDs = stretchIDs
        self.action = action
    }
}

public struct StretchLog: Equatable, Sendable {
    public var id: Int64?
    public var at: Date
    public var stretchID: String
    /// "어느 쪽이 덜 갔나". 증상만 기록한 경우 nil.
    public var tighterSide: Side?
    public var symptom: Symptom
    public var nudgeID: Int64?

    public init(id: Int64? = nil, at: Date, stretchID: String, tighterSide: Side?, symptom: Symptom = .none, nudgeID: Int64? = nil) {
        self.id = id
        self.at = at
        self.stretchID = stretchID
        self.tighterSide = tighterSide
        self.symptom = symptom
        self.nudgeID = nudgeID
    }
}

/// 기획서 7장 지표 정의.
public enum Metrics {
    /// 수행률 = done인 알림 수 ÷ 전체 알림 수 (호흡 신호는 카드가 아니므로 제외)
    public static func completionRate(_ nudges: [NudgeRecord]) -> Double? {
        let cards = nudges.filter { $0.rule != .breath }
        guard !cards.isEmpty else { return nil }
        return Double(cards.filter { $0.action == .done }.count) / Double(cards.count)
    }

    /// 좌우 뻣뻣함 지수 = 최근 N일 (right − left) ÷ 기록 횟수. 양수면 오른쪽이 더 뻣뻣함.
    public static func tightnessIndex(_ logs: [StretchLog], stretchID: String, now: Date, days: Int = 14) -> (index: Double, count: Int)? {
        let from = now.addingTimeInterval(-Double(days) * 86_400)
        let sides = logs
            .filter { $0.stretchID == stretchID && $0.at >= from && $0.at <= now }
            .compactMap(\.tighterSide)
        guard !sides.isEmpty else { return nil }
        let right = sides.filter { $0 == .right }.count
        let left = sides.filter { $0 == .left }.count
        return (Double(right - left) / Double(sides.count), sides.count)
    }

    /// NFR-10: 통증·저림 기록이 3일 연속이면 true (최근 `withinDays`일 안에서).
    public static func needsClinicAdvice(_ logs: [StretchLog], now: Date, calendar: Calendar = .current,
                                         consecutiveDays: Int = 3, withinDays: Int = 7) -> Bool {
        let today = calendar.startOfDay(for: now)
        let symptomDays = Set(logs.filter { $0.symptom != .none }.map { calendar.startOfDay(for: $0.at) })
        var run = 0
        for offset in stride(from: withinDays - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            run = symptomDays.contains(day) ? run + 1 : 0
            if run >= consecutiveDays { return true }
        }
        return false
    }
}
