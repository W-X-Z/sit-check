import Foundation

public struct SitBout: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public var durationMinutes: Double { end.timeIntervalSince(start) / 60 }
}

/// FR-01, FR-02: 키보드·마우스 유휴 시간으로 연속 착석 구간을 추정한다.
///
/// 주기적으로 `tick(now:idleSeconds:)`를 호출한다. 유휴 시간이 임계값 이상이면
/// 마지막 입력 시각에 구간을 닫는다. 화면 잠금·잠자기는 `markAway(at:)`로 알린다.
public struct SitTracker: Sendable {
    public var awayThreshold: TimeInterval
    /// 이보다 짧은 구간은 기록하지 않는다.
    public var minimumBout: TimeInterval = 60

    public private(set) var boutStart: Date?
    private var lastTick: Date?

    public init(awayThreshold: TimeInterval) {
        self.awayThreshold = awayThreshold
    }

    public var isSitting: Bool { boutStart != nil }

    public func sittingSeconds(at now: Date) -> TimeInterval {
        guard let boutStart else { return 0 }
        return max(0, now.timeIntervalSince(boutStart))
    }

    /// 닫힌 구간이 있으면 반환한다 (저장 대상).
    @discardableResult
    public mutating func tick(now: Date, idleSeconds: TimeInterval) -> SitBout? {
        var closed: SitBout?

        // 앱이 멈춰 있던 동안(잠자기 등) 틱이 끊겼다면 그 사이는 자리 비움으로 본다.
        if let lastTick, now.timeIntervalSince(lastTick) >= awayThreshold, boutStart != nil {
            closed = close(at: lastTick)
        }
        lastTick = now

        let lastInput = now.addingTimeInterval(-max(0, idleSeconds))
        if idleSeconds >= awayThreshold {
            if boutStart != nil {
                closed = close(at: lastInput) ?? closed
            }
        } else if boutStart == nil {
            boutStart = lastInput
        }
        return closed
    }

    /// 화면 잠금, 잠자기 등 확실한 자리 비움.
    @discardableResult
    public mutating func markAway(at now: Date) -> SitBout? {
        guard boutStart != nil else { return nil }
        return close(at: now)
    }

    /// 스트레칭을 마치고 돌아온 경우: 현재 구간을 닫고 지금부터 새로 센다.
    @discardableResult
    public mutating func restart(at now: Date) -> SitBout? {
        let closed = boutStart != nil ? close(at: now) : nil
        boutStart = now
        lastTick = now
        return closed
    }

    private mutating func close(at end: Date) -> SitBout? {
        guard let start = boutStart else { return nil }
        boutStart = nil
        let bout = SitBout(start: start, end: max(start, end))
        return bout.end.timeIntervalSince(bout.start) >= minimumBout ? bout : nil
    }
}
