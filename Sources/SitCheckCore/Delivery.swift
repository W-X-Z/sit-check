import Foundation

/// 카메라 신호를 어떻게 쓸지
public enum PostureAlertMode: String, Codable, CaseIterable, Sendable {
    /// 카드 없이 '울렸을 알림'만 기록한다 (측정 기간, 기본값)
    case shadow
    /// 통과한 신호를 카드로 띄운다
    case cards

    public var label: String {
        switch self {
        case .shadow: return "기록만 (카드 없음)"
        case .cards: return "카드로 알림"
        }
    }
}

/// 카드를 언제 띄울지 정한다. 입력이 잠깐 멈춘 순간(작업 경계)에 띄우고, 통화 중에는 미룬다.
/// 계속 타이핑 중이어도 `maxDefer`가 지나면 띄우고, 통화가 길어져도 `maxCallDefer`가 지나면 띄운다.
public struct DeliveryGate: Sendable {
    /// 이만큼(초) 입력이 없으면 작업 경계로 본다.
    public var pauseSeconds: Double = 2.5
    public var maxDefer: TimeInterval = 5 * 60
    public var maxCallDefer: TimeInterval = 30 * 60

    private var waitingSince: [String: Date] = [:]

    public init() {}

    public func isWaiting(_ key: String) -> Bool { waitingSince[key] != nil }

    /// - Parameter key: 기다리는 대상 (규칙 ID 등)
    public mutating func shouldDeliver(_ key: String, now: Date, idleSeconds: Double, inCall: Bool) -> Bool {
        let since = waitingSince[key] ?? now
        waitingSince[key] = since
        let waited = now.timeIntervalSince(since)
        let ready: Bool
        if inCall {
            ready = waited >= maxCallDefer
        } else {
            ready = idleSeconds >= pauseSeconds || waited >= maxDefer
        }
        if ready { waitingSince[key] = nil }
        return ready
    }

    public mutating func cancel(_ key: String) {
        waitingSince[key] = nil
    }

    public mutating func cancelAll() {
        waitingSince = [:]
    }
}

/// 놓친 경우를 보기 위한 무작위 확인 질문 ("최근 20분 동안 자세를 거의 안 바꿨나요?").
/// 알림이 울린 순간에만 묻는 피드백은 정확도만 보여 주고 놓침은 보여 주지 않으므로 따로 둔다.
public struct CheckInPlanner: Sendable {
    public var perDay: Int
    /// 하루에 앉아 있는 시간 가정 (분). 이 시간에 걸쳐 고르게 묻도록 확률을 정한다.
    public var expectedSittingMinutesPerDay: Double = 240
    public var minSittingMinutes: Double = 20
    public var minGap: TimeInterval = 2 * 3600
    public var calendar: Calendar = .current

    public private(set) var day: Date?
    public private(set) var askedToday = 0
    public private(set) var lastAskedAt: Date?

    public init(perDay: Int) {
        self.perDay = perDay
    }

    /// 1분에 한 번 부른다. `roll`은 0~1 균등 난수.
    public mutating func shouldAsk(now: Date, sittingMinutes: Double, roll: Double) -> Bool {
        rollDay(now)
        guard perDay > 0, askedToday < perDay, sittingMinutes >= minSittingMinutes else { return false }
        if let lastAskedAt, now.timeIntervalSince(lastAskedAt) < minGap { return false }
        return roll < Double(perDay) / expectedSittingMinutesPerDay
    }

    public mutating func asked(at now: Date) {
        rollDay(now)
        askedToday += 1
        lastAskedAt = now
    }

    private mutating func rollDay(_ now: Date) {
        let today = calendar.startOfDay(for: now)
        if day != today {
            day = today
            askedToday = 0
        }
    }
}

public enum CheckInAnswer: String, Codable, CaseIterable, Sendable {
    case yes, no, unsure
    /// 답하지 않고 닫았거나 자리를 비워 사라짐
    case dismissed

    public var label: String {
        switch self {
        case .yes: return "네"
        case .no: return "아니요"
        case .unsure: return "잘 모르겠어요"
        case .dismissed: return "닫음"
        }
    }
}
