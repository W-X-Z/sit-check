import Foundation

/// 알림 규칙. v0.1은 R1과 R4만 실제로 발생한다 (R2, R3는 v0.2 카메라 감지용).
public enum NudgeRule: String, Codable, CaseIterable, Sendable {
    case longSitting = "R1"
    case tiltRotation = "R2"
    case screenApproach = "R3"
    case breath = "R4"
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
        case .breath: return []
        }
    }

    /// - Parameters:
    ///   - history: 과거 알림에서 제시한 동작 ID 목록. 오래된 것부터, 마지막이 직전 알림.
    ///   - excluded: 사용자가 제외했거나 통증·저림을 기록한 동작.
    public func prescribe(rule: NudgeRule, history: [[String]], excluded: Set<String>) -> [Stretch] {
        guard rule != .breath else { return [] }
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
