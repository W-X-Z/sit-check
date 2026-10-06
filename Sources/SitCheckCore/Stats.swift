import Foundation

/// 한 구간 안에서 한 특징의 분포 요약. MAD는 1.4826을 곱하기 전의 원래 값이다.
public struct FeatureStat: Codable, Equatable, Sendable {
    public var median: Double
    /// 중앙값 절대 편차
    public var mad: Double
    public var p10: Double
    public var p90: Double
    public var n: Int

    public init(median: Double, mad: Double, p10: Double, p90: Double, n: Int) {
        self.median = median
        self.mad = mad
        self.p10 = p10
        self.p90 = p90
        self.n = n
    }

    /// 유한한 값이 하나도 없으면 nil
    public init?(_ values: [Double]) {
        let sorted = values.filter(\.isFinite).sorted()
        guard !sorted.isEmpty else { return nil }
        let med = Stats.median(sorted: sorted)
        let deviations = sorted.map { abs($0 - med) }.sorted()
        self.init(median: med,
                  mad: Stats.median(sorted: deviations),
                  p10: Stats.percentile(sorted: sorted, 0.1),
                  p90: Stats.percentile(sorted: sorted, 0.9),
                  n: sorted.count)
    }

    /// p10–p90 폭. 그 구간 안에서 얼마나 움직였는지 본다.
    public var range: Double { p90 - p10 }
}

/// 이상값에 강한 요약 통계
public enum Stats {
    /// 정규분포에서 MAD를 표준편차로 바꾸는 계수
    public static let madToSigma = 1.4826

    public static func median(_ values: [Double]) -> Double? {
        let sorted = values.filter(\.isFinite).sorted()
        return sorted.isEmpty ? nil : median(sorted: sorted)
    }

    public static func mad(_ values: [Double]) -> Double? {
        guard let med = median(values) else { return nil }
        return median(values.filter(\.isFinite).map { abs($0 - med) })
    }

    /// 선형 보간 백분위 (p: 0~1). 값이 없으면 nil.
    public static func percentile(_ values: [Double], _ p: Double) -> Double? {
        let sorted = values.filter(\.isFinite).sorted()
        return sorted.isEmpty ? nil : percentile(sorted: sorted, p)
    }

    static func median(sorted s: [Double]) -> Double {
        let mid = s.count / 2
        return s.count % 2 == 0 ? (s[mid - 1] + s[mid]) / 2 : s[mid]
    }

    static func percentile(sorted s: [Double], _ p: Double) -> Double {
        guard s.count > 1 else { return s[0] }
        let pos = min(max(p, 0), 1) * Double(s.count - 1)
        let lo = Int(pos.rounded(.down))
        let hi = min(lo + 1, s.count - 1)
        return s[lo] + (s[hi] - s[lo]) * (pos - Double(lo))
    }
}
