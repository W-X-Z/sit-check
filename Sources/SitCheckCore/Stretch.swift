import Foundation

public enum Side: String, Codable, CaseIterable, Sendable {
    case left, same, right

    public var label: String {
        switch self {
        case .left: return "왼쪽"
        case .same: return "같음"
        case .right: return "오른쪽"
        }
    }
}

public enum Symptom: String, Codable, CaseIterable, Sendable {
    case none, pain, numb

    public var label: String {
        switch self {
        case .none: return "없음"
        case .pain: return "통증"
        case .numb: return "저림"
        }
    }
}

public enum StretchPosture: String, Codable, Sendable {
    case seated, standing

    public var label: String { self == .seated ? "앉아서" : "서서" }
}

/// 한 동작의 분량. 좌우 동작은 양쪽을 같은 시간 수행한 뒤 설정된 추가 세트만 더한다.
public enum Dose: Codable, Equatable, Sendable {
    case perSide(seconds: Int)
    case hold(seconds: Int)
    case reps(Int)

    public var summary: String {
        switch self {
        case .perSide(let s): return "좌우 \(s)초"
        case .hold(let s): return "\(s)초"
        case .reps(let n): return "\(n)회"
        }
    }

    public var isBilateral: Bool {
        if case .perSide = self { return true }
        return false
    }
}

public struct Stretch: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let posture: StretchPosture
    public let dose: Dose
    public let target: String
    public let steps: [String]
    public let checkPoint: String
    public let symbol: String
}

/// 추가 세트 (예: S3 오른쪽 30초). NFR-09에 따라 기본값은 비어 있다.
public struct ExtraSet: Codable, Equatable, Sendable {
    public var side: Side
    public var seconds: Int

    public init(side: Side, seconds: Int) {
        self.side = side
        self.seconds = seconds
    }
}

/// 가이드 화면의 타이머 한 구간.
public struct TimerPhase: Equatable, Sendable {
    public let title: String
    public let seconds: Int
}

public extension Stretch {
    /// 양쪽 동일 시간 → (설정된 경우) 추가 세트 순으로 타이머 구간을 만든다.
    func phases(extra: ExtraSet?) -> [TimerPhase] {
        switch dose {
        case .perSide(let s):
            var phases = [TimerPhase(title: "왼쪽", seconds: s), TimerPhase(title: "오른쪽", seconds: s)]
            if let extra, extra.seconds > 0, extra.side != .same {
                phases.append(TimerPhase(title: "\(extra.side.label) 추가", seconds: extra.seconds))
            }
            return phases
        case .hold(let s):
            return [TimerPhase(title: "유지", seconds: s)]
        case .reps(let n):
            // 1회 약 5초 기준의 안내용 타이머
            return [TimerPhase(title: "\(n)회 천천히", seconds: n * 5)]
        }
    }
}

public enum StretchLibrary {
    public static let all: [Stretch] = [
        Stretch(
            id: "S1", name: "몸통 돌리기", posture: .seated, dose: .perSide(seconds: 20),
            target: "흉추와 허리 회전",
            steps: [
                "의자 앞쪽에 앉아 양발을 바닥에 붙인다.",
                "팔짱을 끼거나 양손을 가슴에 모은다.",
                "숨을 내쉬며 명치 높이에서 몸통을 한쪽으로 돌린다.",
                "끝 지점에서 호흡을 유지하고 반대쪽도 같은 시간 한다.",
            ],
            checkPoint: "골반은 정면을 유지하고 고개만 먼저 돌아가지 않게 한다.",
            symbol: "arrow.triangle.2.circlepath"
        ),
        Stretch(
            id: "S2", name: "옆구리 늘리기", posture: .seated, dose: .perSide(seconds: 20),
            target: "요방형근, 광배",
            steps: [
                "양쪽 엉덩이에 체중을 고르게 싣고 앉는다.",
                "한 팔을 머리 위로 뻗는다.",
                "뻗은 팔 반대쪽으로 상체를 옆으로 기울인다.",
                "갈비뼈 사이가 벌어지는 느낌으로 숨을 들이쉬고, 반대쪽도 한다.",
            ],
            checkPoint: "기울이는 쪽 엉덩이가 의자에서 뜨지 않게 한다.",
            symbol: "figure.flexibility"
        ),
        Stretch(
            id: "S3", name: "4자 스트레칭", posture: .seated, dose: .perSide(seconds: 30),
            target: "고관절 회전근",
            steps: [
                "한쪽 발목을 반대쪽 무릎 위에 올려 4자를 만든다.",
                "허리를 세운 채 고관절부터 상체를 앞으로 숙인다.",
                "엉덩이 바깥이 당기는 지점에서 멈추고 호흡한다.",
                "반대쪽도 같은 시간 한다.",
            ],
            checkPoint: "등이 둥글게 말리지 않게 하고, 무릎을 억지로 누르지 않는다.",
            symbol: "figure.cooldown"
        ),
        Stretch(
            id: "S4", name: "캣카우", posture: .seated, dose: .reps(8),
            target: "척추 분절",
            steps: [
                "의자 앞쪽에 앉아 양손을 무릎 위에 둔다.",
                "숨을 들이쉬며 가슴을 앞으로 내밀고 등을 편다.",
                "숨을 내쉬며 꼬리뼈부터 등을 둥글게 만다.",
                "척추 마디마디를 순서대로 움직인다는 느낌으로 반복한다.",
            ],
            checkPoint: "목만 움직이지 말고 등 가운데까지 움직임이 가는지 본다.",
            symbol: "figure.mind.and.body"
        ),
        Stretch(
            id: "S5", name: "장요근 스트레칭", posture: .standing, dose: .perSide(seconds: 30),
            target: "장요근",
            steps: [
                "한 발을 앞으로 크게 내딛어 런지 자세를 만든다.",
                "뒤쪽 다리의 엉덩이에 힘을 주어 골반을 살짝 말아 넣는다.",
                "상체를 세운 채 체중을 앞으로 조금 옮긴다.",
                "뒤쪽 다리 허벅지 앞이 당기면 유지하고, 반대쪽도 한다.",
            ],
            checkPoint: "허리를 젖혀서 늘리지 않는다. 갈비뼈가 들리지 않게 배를 살짝 조인다.",
            symbol: "figure.strengthtraining.functional"
        ),
        Stretch(
            id: "S6", name: "문틀 가슴 스트레칭", posture: .standing, dose: .perSide(seconds: 20),
            target: "대흉근, 소흉근",
            steps: [
                "문틀에 한쪽 팔꿈치와 아래팔을 어깨 높이로 댄다.",
                "같은 쪽 발을 한 걸음 앞으로 내딛는다.",
                "몸통을 반대쪽으로 살짝 돌려 가슴 앞을 늘린다.",
                "반대쪽도 같은 시간 한다.",
            ],
            checkPoint: "어깨가 귀 쪽으로 올라가거나 앞으로 빠지지 않게 한다.",
            symbol: "door.left.hand.open"
        ),
        Stretch(
            id: "S7", name: "책상 짚고 광배 늘리기", posture: .standing, dose: .hold(seconds: 20),
            target: "광배",
            steps: [
                "책상에서 한두 걸음 떨어져 양손을 책상 모서리에 둔다.",
                "엉덩이를 뒤로 빼며 상체를 바닥과 나란하게 숙인다.",
                "팔 사이로 머리를 떨어뜨리고 겨드랑이 아래를 늘린다.",
            ],
            checkPoint: "허리가 과하게 꺾이지 않게 배에 힘을 살짝 준다.",
            symbol: "table.furniture"
        ),
    ]

    public static func stretch(_ id: String) -> Stretch? {
        all.first { $0.id == id }
    }
}
