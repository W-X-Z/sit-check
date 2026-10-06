import Foundation

/// 카메라 카드에 붙는 "맞았나요?" 답 (실험 7: 유형별 정확도)
public enum NudgeFeedback: String, Codable, CaseIterable, Sendable {
    case right
    case wrong
    /// 자리나 화면 위치가 바뀌어서 생긴 알림
    case setupChanged

    public var label: String {
        switch self {
        case .right: return "맞아요"
        case .wrong: return "아니에요"
        case .setupChanged: return "자리가 바뀌었어요"
        }
    }
}

public struct NudgeRecord: Equatable, Sendable {
    public var id: Int64?
    public var at: Date
    public var rule: NudgeRule
    public var stretchIDs: [String]
    public var action: NudgeAction
    public var feedback: NudgeFeedback?
    /// 신호 값 (JSON). 카메라 카드의 경우 어떤 값으로 울렸는지 남긴다.
    public var detail: String?

    public init(id: Int64? = nil, at: Date, rule: NudgeRule, stretchIDs: [String], action: NudgeAction,
                feedback: NudgeFeedback? = nil, detail: String? = nil) {
        self.id = id
        self.at = at
        self.rule = rule
        self.stretchIDs = stretchIDs
        self.action = action
        self.feedback = feedback
        self.detail = detail
    }
}

/// 카메라 신호가 성립한 순간의 기록. `mode`가 shadow면 카드 없이 '울렸을 알림'만 남긴 것이다.
public struct PostureEventRecord: Equatable, Sendable {
    public var id: Int64?
    public var at: Date
    public var rule: NudgeRule
    public var variant: String
    public var mode: PostureAlertMode
    /// 현재 설정 기준 카드 후보였는지 (기록 전용 변형이면 false)
    public var actionable: Bool
    public var detail: [String: Double]

    public init(id: Int64? = nil, at: Date, rule: NudgeRule, variant: String, mode: PostureAlertMode,
                actionable: Bool, detail: [String: Double] = [:]) {
        self.id = id
        self.at = at
        self.rule = rule
        self.variant = variant
        self.mode = mode
        self.actionable = actionable
        self.detail = detail
    }
}

/// 무작위 확인 질문과 그 순간의 감지 상태
public struct CheckInRecord: Equatable, Sendable {
    public var id: Int64?
    public var at: Date
    public var question: String
    public var answer: CheckInAnswer
    /// 질문 순간 감지기가 본 '마지막 자세 변화 뒤 지난 분'
    public var stillMinutes: Double?
    public var driftScore: Double?

    public init(id: Int64? = nil, at: Date, question: String, answer: CheckInAnswer,
                stillMinutes: Double? = nil, driftScore: Double? = nil) {
        self.id = id
        self.at = at
        self.question = question
        self.answer = answer
        self.stillMinutes = stillMinutes
        self.driftScore = driftScore
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
    /// 수행률 = done인 알림 수 ÷ 전체 카드 수 (호흡 신호와 아이콘만 보여 준 경우는 카드가 아니므로 제외)
    public static func completionRate(_ nudges: [NudgeRecord]) -> Double? {
        let cards = nudges.filter { $0.rule != .breath && $0.action != .icon }
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
