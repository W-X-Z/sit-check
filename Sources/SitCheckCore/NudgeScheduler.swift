import Foundation

public enum NudgeAction: String, Codable, Sendable {
    case done, snooze, dismiss
    /// 카드가 떠 있는 동안 자리를 비워 자동으로 닫힌 경우 (수행률 계산에서는 미수행)
    case expired
}

public enum SchedulerEvent: Equatable, Sendable {
    case showCard(NudgeRule)
    case breath
}

/// FR-03, FR-07, FR-13 알림 판정.
///
/// - R1은 연속 착석이 임계값을 넘으면 발생한다. 미루기 중이면 미루기가 끝날 때 다시 뜬다.
/// - 한 알림 뒤 cooldown 동안은 **다른 규칙**의 카드를 띄우지 않는다.
/// - "1시간 끄기"는 카드와 호흡 신호를 모두 멈춘다.
/// - R4 호흡은 아이콘 신호만 주며 cooldown에 영향을 주지 않는다.
public struct NudgeScheduler: Sendable {
    public private(set) var cardVisible: NudgeRule?
    public private(set) var snoozedUntil: Date?
    public private(set) var mutedUntil: Date?
    public private(set) var lastCard: (rule: NudgeRule, at: Date)?
    public private(set) var lastBreath: Date?
    public private(set) var lastShown: [NudgeRule: Date] = [:]

    public init() {}

    public func isMuted(at now: Date) -> Bool {
        if let mutedUntil { return now < mutedUntil }
        return false
    }

    /// - Parameter posture: 카메라 감지기가 충분히 오래 이어졌다고 판단한 자세 규칙 (R2, R3)
    public mutating func evaluate(now: Date, boutStart: Date?, settings: AppSettings,
                                  posture: NudgeRule? = nil) -> SchedulerEvent? {
        guard cardVisible == nil, !isMuted(at: now), let boutStart else { return nil }
        let sitting = now.timeIntervalSince(boutStart)

        if sitting >= Double(settings.sitAlertMinutes) * 60, canShow(.longSitting, now: now, settings: settings) {
            return .showCard(.longSitting)
        }

        if let posture, canShow(posture, now: now, settings: settings),
           lastShown[posture].map({ now.timeIntervalSince($0) >= Double(settings.postureRepeatMinutes) * 60 }) ?? true {
            return .showCard(posture)
        }

        if settings.breathEnabled {
            let interval = Double(settings.breathIntervalMinutes) * 60
            let since = max(boutStart, lastBreath ?? boutStart)
            if now.timeIntervalSince(since) >= interval {
                lastBreath = now
                return .breath
            }
        }
        return nil
    }

    private func canShow(_ rule: NudgeRule, now: Date, settings: AppSettings) -> Bool {
        if let snoozedUntil, now < snoozedUntil { return false }
        if let lastCard, lastCard.rule != rule,
           now.timeIntervalSince(lastCard.at) < Double(settings.cooldownMinutes) * 60 {
            return false
        }
        return true
    }

    public mutating func cardShown(_ rule: NudgeRule, at now: Date) {
        cardVisible = rule
        lastCard = (rule, now)
        lastShown[rule] = now
        snoozedUntil = nil
    }

    public mutating func cardResolved(_ action: NudgeAction, at now: Date, settings: AppSettings) {
        cardVisible = nil
        switch action {
        case .snooze:
            snoozedUntil = now.addingTimeInterval(Double(settings.snoozeMinutes) * 60)
        case .dismiss:
            mutedUntil = now.addingTimeInterval(Double(settings.muteMinutes) * 60)
        case .done, .expired:
            break
        }
    }

    /// 메뉴에서 "1시간 끄기"를 직접 누른 경우
    public mutating func mute(at now: Date, settings: AppSettings) {
        mutedUntil = now.addingTimeInterval(Double(settings.muteMinutes) * 60)
    }

    public mutating func unmute() {
        mutedUntil = nil
    }

    /// 착석 구간이 끝나면 미루기와 호흡 주기를 초기화한다.
    public mutating func boutEnded() {
        snoozedUntil = nil
        lastBreath = nil
    }
}

/// 알림 카드 문구 규칙: 첫 줄은 사실만, 둘째 줄은 행동 하나만. 평가·점수 문구는 쓰지 않는다.
public enum NudgeCopy {
    public static func reason(rule: NudgeRule, sittingMinutes: Int) -> String {
        switch rule {
        case .longSitting: return "\(sittingMinutes)분째 앉아 있어요"
        case .tiltRotation: return "\(sittingMinutes)분째 앉아 있고, 한쪽으로 기운 상태가 이어지고 있어요"
        case .screenApproach: return "\(sittingMinutes)분째 앉아 있고, 화면 쪽으로 다가가 있어요"
        case .breath: return "길게 한 번 내쉬어 보세요"
        }
    }

    public static func action(for stretches: [Stretch]) -> String {
        let n = stretches.count
        if stretches.contains(where: { $0.posture == .standing }) {
            return "일어나서 \(n)개만 하고 오세요"
        }
        return "앉은 채로 \(n)개만 해 보세요"
    }
}
