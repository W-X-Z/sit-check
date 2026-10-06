import Foundation

public enum NudgeAction: String, Codable, Sendable {
    case done, snooze, dismiss
    /// 카드가 떠 있는 동안 자리를 비워 자동으로 닫힌 경우 (수행률 계산에서는 미수행)
    case expired
    /// 카드 대신 메뉴바 아이콘만 바꿔 알린 경우 (실험 8, 수행률 계산에서 제외)
    case icon
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
/// - 카메라 카드(R5–R7)는 하루 상한이 있고, 무시하거나 미룰 때마다 같은 카드의 간격을 두 배로 늘린다.
public struct NudgeScheduler: Sendable {
    public var calendar: Calendar = .current

    public private(set) var cardVisible: NudgeRule?
    public private(set) var snoozedUntil: Date?
    public private(set) var mutedUntil: Date?
    public private(set) var lastCard: (rule: NudgeRule, at: Date)?
    public private(set) var lastBreath: Date?
    public private(set) var lastShown: [NudgeRule: Date] = [:]
    /// 규칙별 간격 배수의 지수 (0이면 기본 간격, 최대 3 = 8배)
    public private(set) var backoff: [NudgeRule: Int] = [:]
    private var postureDay: Date?
    private var postureCount = 0

    public static let maxBackoff = 3

    public init() {}

    public func isMuted(at now: Date) -> Bool {
        if let mutedUntil { return now < mutedUntil }
        return false
    }

    /// 오늘 띄운 카메라 카드 수 (아이콘만 보여 준 경우 포함)
    public func postureCards(on now: Date) -> Int {
        postureDay == calendar.startOfDay(for: now) ? postureCount : 0
    }

    /// 같은 카메라 카드를 다시 띄우기까지의 간격
    public func repeatInterval(_ rule: NudgeRule, settings: AppSettings) -> TimeInterval {
        Double(settings.postureRepeatMinutes) * 60 * pow(2, Double(backoff[rule] ?? 0))
    }

    /// - Parameter posture: 지금 이어지고 있는 카메라 신호 중 카드 후보 (R5–R7)
    public mutating func evaluate(now: Date, boutStart: Date?, settings: AppSettings,
                                  posture: NudgeRule? = nil) -> SchedulerEvent? {
        guard cardVisible == nil, !isMuted(at: now), let boutStart else { return nil }
        let sitting = now.timeIntervalSince(boutStart)

        if sitting >= Double(settings.sitAlertMinutes) * 60, canShow(.longSitting, now: now, settings: settings) {
            return .showCard(.longSitting)
        }

        if let posture, posture.isPostureCard, canShowPosture(posture, now: now, settings: settings) {
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

    private func canShowPosture(_ rule: NudgeRule, now: Date, settings: AppSettings) -> Bool {
        guard canShow(rule, now: now, settings: settings),
              postureCards(on: now) < settings.postureCardsPerDay else { return false }
        if let last = lastShown[rule], now.timeIntervalSince(last) < repeatInterval(rule, settings: settings) {
            return false
        }
        return true
    }

    public mutating func cardShown(_ rule: NudgeRule, at now: Date) {
        cardVisible = rule
        lastCard = (rule, now)
        lastShown[rule] = now
        snoozedUntil = nil
        if rule.isPostureCard { countPostureCard(at: now) }
    }

    /// 카드 대신 아이콘만 보여 준 경우. R1은 미루기를 누른 것처럼 다음 알림까지 기다린다.
    public mutating func iconShown(_ rule: NudgeRule, at now: Date, settings: AppSettings) {
        lastCard = (rule, now)
        lastShown[rule] = now
        if rule.isPostureCard {
            countPostureCard(at: now)
        } else {
            snoozedUntil = now.addingTimeInterval(Double(settings.snoozeMinutes) * 60)
        }
    }

    public mutating func cardResolved(_ action: NudgeAction, at now: Date, settings: AppSettings) {
        let rule = cardVisible
        cardVisible = nil
        switch action {
        case .snooze:
            snoozedUntil = now.addingTimeInterval(Double(settings.snoozeMinutes) * 60)
        case .dismiss:
            mutedUntil = now.addingTimeInterval(Double(settings.muteMinutes) * 60)
        case .done, .expired, .icon:
            break
        }
        if let rule, rule.isPostureCard {
            switch action {
            case .done:
                backoff[rule] = 0
            case .snooze, .dismiss, .expired:
                backoff[rule] = min((backoff[rule] ?? 0) + 1, Self.maxBackoff)
            case .icon:
                break
            }
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

    private mutating func countPostureCard(at now: Date) {
        let today = calendar.startOfDay(for: now)
        if postureDay != today {
            postureDay = today
            postureCount = 0
            backoff = [:]
        }
        postureCount += 1
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
        case .stillness: return "\(sittingMinutes)분째 앉아 있고, 오래 거의 같은 자세예요"
        case .drift: return "\(sittingMinutes)분째 앉아 있고, 앉은 직후보다 자세가 옮겨 갔어요"
        case .near: return "화면에 가까운 상태가 이어지고 있어요"
        case .setupChange: return "자리나 화면 위치가 바뀐 것 같아요"
        }
    }

    public static func action(for stretches: [Stretch]) -> String {
        let n = stretches.count
        if stretches.contains(where: { $0.posture == .standing }) {
            return "일어나서 \(n)개만 하고 오세요"
        }
        return "앉은 채로 \(n)개만 해 보세요"
    }

    /// 카메라 신호 카드 문구. 무엇이 얼마나 이어졌는지만 말하고, 고칠 방향은 말하지 않는다.
    public static func posture(_ event: SignalEvent, sittingMinutes: Int,
                               calendar: Calendar = .current) -> (reason: String, action: String) {
        switch event.rule {
        case .stillness:
            let still = Int((event.detail["still_minutes"] ?? 0).rounded())
            return ("\(sittingMinutes)분째 앉아 있고, \(still)분째 거의 같은 자세예요",
                    "원하면 일어나 한 바퀴 걸어 보세요")
        case .drift:
            let since = event.detail["reference_at"].map { clock(Date(timeIntervalSince1970: $0), calendar: calendar) + " 무렵" } ?? "앉은 직후"
            if event.variant == "가까이" {
                let pct = Int((event.detail["closer_pct"] ?? 0).rounded())
                return ("\(sittingMinutes)분째 앉아 있고, \(since)보다 화면에 가까이 있어요 (얼굴 크기 +\(pct)%)",
                        "원하면 자세를 한 번 바꿔 보세요")
            }
            return ("\(sittingMinutes)분째 앉아 있고, \(since)보다 얼굴 위치가 낮아요",
                    "원하면 자세를 한 번 바꿔 보세요")
        case .near:
            let cm = Int((event.detail["distance_cm"] ?? 0).rounded())
            let minutes = Int((event.detail["minutes"] ?? 0).rounded())
            return ("화면까지 약 \(cm)cm인 상태가 \(minutes)분째예요",
                    "원하면 의자나 화면 위치를 한 번 확인해 보세요")
        default:
            return (reason(rule: event.rule, sittingMinutes: sittingMinutes), "원하면 자세를 한 번 바꿔 보세요")
        }
    }

    static func clock(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
