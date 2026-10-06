import Foundation

/// 알림 규칙.
///
/// - R1 장시간 착석, R4 호흡: 키보드·마우스 기반
/// - R2 기울기·회전, R3 화면 접근: 예전 카메라 규칙. 카드는 띄우지 않고 비교용 기록만 남긴다.
/// - R5 오래 같은 자세, R6 점점 아래로·가까이, R7 가까움: '바른 자세'를 판정하지 않는 카메라 신호
public enum NudgeRule: String, Codable, CaseIterable, Sendable {
    case longSitting = "R1"
    case tiltRotation = "R2"
    case screenApproach = "R3"
    case breath = "R4"
    case stillness = "R5"
    case drift = "R6"
    case near = "R7"
    /// 자리·화면 위치가 바뀐 것 같음 (알림이 아니라 기록과 확인 질문)
    case setupChange = "R8"

    /// 카메라 신호로 띄우는 카드인지 (하루 상한·간격 늘리기 대상)
    public var isPostureCard: Bool {
        switch self {
        case .stillness, .drift, .near: return true
        default: return false
        }
    }

    public var title: String {
        switch self {
        case .longSitting: return "장시간 착석"
        case .tiltRotation: return "기울기·회전 (기록 전용)"
        case .screenApproach: return "화면 접근 (기록 전용)"
        case .breath: return "호흡"
        case .stillness: return "오래 같은 자세"
        case .drift: return "점점 아래로·가까이"
        case .near: return "가까움"
        case .setupChange: return "자리·화면 변화 의심"
        }
    }
}

/// FR-04: 규칙, 최근 이력, 제외 목록으로 스트레칭 2개를 고른다.
///
/// - R1: S5 고정 + 순환 1개. 순환 칸은 가장 오래 전에 나온 동작을 고른다.
/// - R2: S2, S1 / R3: S4, S6. 제외된 동작은 순환 후보로 채운다.
/// - 같은 스트레칭을 연속 두 번 제시하지 않는다. 단, R1의 고정 동작(S5)은
///   기획서가 "고정"으로 정했으므로 이 규칙의 예외로 둔다 (docs/spec-review.md 참고).
public struct Prescriber: Sendable {
    public var library: [Stretch]
    public var count: Int = 2

    public init(library: [Stretch] = StretchLibrary.all) {
        self.library = library
    }

    public static func fixedIDs(for rule: NudgeRule) -> [String] {
        switch rule {
        case .longSitting: return ["S5"]
        case .tiltRotation: return ["S2", "S1"]
        case .screenApproach: return ["S4", "S6"]
        case .breath, .stillness, .drift, .near, .setupChange: return []
        }
    }

    /// - Parameters:
    ///   - history: 과거 알림에서 제시한 동작 ID 목록. 오래된 것부터, 마지막이 직전 알림.
    ///   - excluded: 사용자가 제외했거나 통증·저림을 기록한 동작.
    public func prescribe(rule: NudgeRule, history: [[String]], excluded: Set<String>) -> [Stretch] {
        // 카메라 신호 카드는 감지된 자세를 '고칠 결함'처럼 읽히게 하지 않도록 스트레칭을 붙이지 않는다.
        guard rule != .breath, rule != .setupChange, !rule.isPostureCard else { return [] }
        let previous = Set(history.last ?? [])
        let available = library.filter { !excluded.contains($0.id) }

        var picked: [Stretch] = []
        for id in Self.fixedIDs(for: rule) where picked.count < count {
            guard let s = available.first(where: { $0.id == id }) else { continue }
            // R1의 고정 동작은 연속 제시 예외. R2/R3의 고정 쌍은 직전과 겹치면 순환으로 대체한다.
            if rule != .longSitting && previous.contains(id) { continue }
            picked.append(s)
        }

        // 순환 후보: 가장 오래 전에 쓴 동작 우선, 한 번도 안 쓴 동작이 가장 먼저.
        let lastUsed = lastUsedIndex(history)
        let ranked = available
            .filter { s in !picked.contains(where: { $0.id == s.id }) }
            .enumerated()
            .sorted { a, b in
                let ua = lastUsed[a.element.id] ?? -1
                let ub = lastUsed[b.element.id] ?? -1
                return ua != ub ? ua < ub : a.offset < b.offset
            }
            .map(\.element)

        for s in ranked where picked.count < count && !previous.contains(s.id) {
            picked.append(s)
        }
        // 후보가 모자라면 연속 금지를 풀어서라도 채운다.
        for s in ranked where picked.count < count && !picked.contains(where: { $0.id == s.id }) {
            picked.append(s)
        }
        return picked
    }

    private func lastUsedIndex(_ history: [[String]]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (i, ids) in history.enumerated() {
            for id in ids { result[id] = i }
        }
        return result
    }
}
