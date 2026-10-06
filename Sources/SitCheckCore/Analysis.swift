import Foundation

/// 실험 결과 계산. 터미널 도구(`sitcheck-analyze`)와 테스트가 같이 쓴다.
/// 판정은 앱과 같은 `PostureSignals` 코드를 기록에 대고 다시 돌려서 얻는다.
public enum Analysis {
    // MARK: - 개인 흔들림 (앱과 같은 규칙)

    /// '가만히 5분' 측정이 있으면 그 값, 없으면 자동 기준(3일 이상)의 값, 그것도 없으면 기본값.
    public static func chooseNoise(minutes: [PostureMinute], params: SignalParameters = SignalParameters(),
                                   calendar: Calendar = .current) -> NoiseModel {
        let still = minutes.filter { $0.label == ExperimentLabel.still.rawValue }
        if let noise = NoiseModel.estimate(from: still, source: "가만히 측정 (\(still.count)분)") { return noise }
        if let baseline = AutoBaseline.build(from: minutes, params: params, calendar: calendar), baseline.isReady {
            return baseline.noise
        }
        return .defaults
    }

    // MARK: - 날짜별 요약 (실험 5)

    public struct DaySummary: Sendable {
        public var day: Date
        /// 평소 사용 중 기록된 분 (실험 라벨 제외)
        public var minutes: Int
        /// 그중 착석 구간 안의 분
        public var sittingMinutes: Int
        /// 앉아 있는 분 중 얼굴이 제대로 잡힌 분의 비율
        public var faceCoverage: Double?
        /// 카드 후보 신호 수 (기록 전용 R2·R3 포함)
        public var events: [NudgeRule: Int]
        /// '오래 같은 자세' 변형별 수 ("20분", "30분", "45분")
        public var stillVariants: [String: Int]
    }

    public static func days(minutes: [PostureMinute], events: [PostureEventRecord],
                            params: SignalParameters = SignalParameters(),
                            calendar: Calendar = .current) -> [DaySummary] {
        var byDay: [Date: DaySummary] = [:]
        func entry(_ day: Date) -> DaySummary {
            byDay[day] ?? DaySummary(day: day, minutes: 0, sittingMinutes: 0, faceCoverage: nil, events: [:], stillVariants: [:])
        }
        var covered: [Date: Int] = [:]
        for m in minutes where m.label == nil && m.frames >= params.minFrames {
            let day = calendar.startOfDay(for: m.start)
            var e = entry(day)
            e.minutes += 1
            if m.boutStart != nil {
                e.sittingMinutes += 1
                if m.validRatio >= params.minValidRatio { covered[day, default: 0] += 1 }
            }
            byDay[day] = e
        }
        for event in events {
            let day = calendar.startOfDay(for: event.at)
            var e = entry(day)
            if event.rule == .stillness {
                e.stillVariants[event.variant, default: 0] += 1
            }
            if event.actionable || event.rule == .tiltRotation || event.rule == .screenApproach {
                e.events[event.rule, default: 0] += 1
            }
            byDay[day] = e
        }
        return byDay.values
            .map { d -> DaySummary in
                var d = d
                if d.sittingMinutes > 0 { d.faceCoverage = Double(covered[d.day] ?? 0) / Double(d.sittingMinutes) }
                return d
            }
            .sorted { $0.day < $1.day }
    }

    // MARK: - 기록 재생

    /// 기록된 분 요약에 같은 판정 코드를 다시 돌려 날짜별 카드 후보 수를 센다.
    public static func replay(_ minutes: [PostureMinute], params: SignalParameters, noise: NoiseModel,
                              distance: DistanceCalibration?, calendar: Calendar = .current) -> [Date: [NudgeRule: Int]] {
        var signals = PostureSignals(params: params, noise: noise, distance: distance)
        var counts: [Date: [NudgeRule: Int]] = [:]
        for m in minutes.sorted(by: { $0.start < $1.start }) where m.label == nil {
            for event in signals.process(m) where event.actionable {
                counts[calendar.startOfDay(for: event.at), default: [:]][event.rule, default: 0] += 1
            }
        }
        return counts
    }

    public struct RuleDayStats: Sendable {
        public var rule: NudgeRule
        public var median: Double
        public var max: Int
        public var days: Int
        public var total: Int
        /// 실험 5 통과 기준: 하루 중앙값 2회 이하, 가장 많은 날 3회 이하
        public var passes: Bool { median <= 2 && max <= 3 }
    }

    /// `days`에 든 날짜마다 (없으면 0회로) 세어 중앙값과 최댓값을 낸다.
    public static func dayStats(_ counts: [Date: [NudgeRule: Int]], days: [Date], rules: [NudgeRule]) -> [RuleDayStats] {
        rules.map { rule in
            let perDay = days.map { counts[$0]?[rule] ?? 0 }
            return RuleDayStats(rule: rule,
                                median: Stats.median(perDay.map { Double($0) }) ?? 0,
                                max: perDay.max() ?? 0,
                                days: days.count,
                                total: perDay.reduce(0, +))
        }
    }

    // MARK: - 의도 동작 구분 (실험 4)

    public struct LabelResult: Sendable {
        public var label: ExperimentLabel
        public var minutes: Int
        /// '자연스럽게 앉기' 대비 아래로 옮겨 간 정도 (σ 단위, 분 중앙값들의 중앙값)
        public var lowerSigma: Double?
        /// '자연스럽게 앉기' 대비 가까워진 정도 (σ 단위)
        public var closerSigma: Double?
        /// max(아래로, 가까이) ≥ k 인 분의 비율
        public var triggerRatio: Double?
        /// pitch 차이 (도), 코–어깨 비율 차이 (몸 자세 구성일 때)
        public var pitchDelta: Double?
        public var neckRatioDelta: Double?

        /// 잡혀야 하는 동작은 80% 이상, 잡히면 안 되는 동작은 10% 이하
        public var passes: Bool? {
            guard let expected = label.shouldTrigger, let ratio = triggerRatio else { return nil }
            return expected ? ratio >= 0.8 : ratio <= 0.1
        }
    }

    /// 날짜별로 '자연스럽게 앉기' 분을 기준으로 삼아 각 동작이 얼마나 벗어나는지 본다.
    public static func separation(_ minutes: [PostureMinute], noise: NoiseModel, k: Double,
                                  calendar: Calendar = .current) -> [LabelResult] {
        let labeled = minutes.filter { $0.label != nil && $0.validRatio >= 0.5 }
        var references: [Date: (y: Double, w: Double, pitch: Double?, neck: Double?)] = [:]
        for (day, group) in Dictionary(grouping: labeled.filter { $0.label == ExperimentLabel.natural.rawValue },
                                       by: { calendar.startOfDay(for: $0.start) }) {
            guard let y = Stats.median(group.compactMap { $0[.faceY]?.median }),
                  let w = Stats.median(group.compactMap { $0[.faceWidth]?.median }), w > 0 else { continue }
            references[day] = (y: y, w: w,
                               pitch: Stats.median(group.compactMap { $0[.pitch]?.median }),
                               neck: Stats.median(group.compactMap { $0[.neckRatio]?.median }))
        }
        var results: [LabelResult] = []
        for label in ExperimentLabel.allCases where label != .still {
            let group = labeled.filter { $0.label == label.rawValue }
            guard !group.isEmpty else { continue }
            var lowers: [Double] = [], closers: [Double] = [], pitches: [Double] = [], necks: [Double] = []
            var triggered = 0, judged = 0
            for m in group {
                guard let ref = references[calendar.startOfDay(for: m.start)],
                      let y = m[.faceY]?.median, let w = m[.faceWidth]?.median else { continue }
                let lower = (y - ref.y) / noise.faceY
                let closer = (w / ref.w - 1) / noise.widthRel
                lowers.append(lower)
                closers.append(closer)
                judged += 1
                if max(lower, closer) >= k { triggered += 1 }
                if let p = m[.pitch]?.median, let rp = ref.pitch { pitches.append(p - rp) }
                if let n = m[.neckRatio]?.median, let rn = ref.neck { necks.append(n - rn) }
            }
            results.append(LabelResult(label: label, minutes: group.count,
                                       lowerSigma: Stats.median(lowers), closerSigma: Stats.median(closers),
                                       triggerRatio: judged > 0 ? Double(triggered) / Double(judged) : nil,
                                       pitchDelta: Stats.median(pitches), neckRatioDelta: Stats.median(necks)))
        }
        return results
    }

    // MARK: - 카드 정확도 (실험 7)

    public struct FeedbackSummary: Sendable {
        public var rule: NudgeRule
        public var cards: Int
        public var right: Int
        public var wrong: Int
        public var setupChanged: Int
        public var unanswered: Int
        /// 맞아요 ÷ (맞아요 + 아니에요). '자리가 바뀌었어요'와 무응답은 빼고 계산한다.
        public var precision: Double? { right + wrong > 0 ? Double(right) / Double(right + wrong) : nil }
    }

    public static func feedback(_ nudges: [NudgeRecord]) -> [FeedbackSummary] {
        let cards = nudges.filter { $0.rule.isPostureCard && $0.action != .icon }
        return NudgeRule.allCases.filter(\.isPostureCard).compactMap { rule in
            let group = cards.filter { $0.rule == rule }
            guard !group.isEmpty else { return nil }
            return FeedbackSummary(rule: rule, cards: group.count,
                                   right: group.filter { $0.feedback == .right }.count,
                                   wrong: group.filter { $0.feedback == .wrong }.count,
                                   setupChanged: group.filter { $0.feedback == .setupChanged }.count,
                                   unanswered: group.filter { $0.feedback == nil }.count)
        }
    }

    public struct CheckInSummary: Sendable {
        public var total: Int
        public var answers: [CheckInAnswer: Int]
        /// 사용자가 "거의 안 바꿨다"(네)고 답했을 때 감지기도 정지 임계값을 넘었던 수 / 넘지 않았던 수
        public var yesDetected: Int
        public var yesMissed: Int
        /// 사용자가 "바꿨다"(아니요)고 답했는데 감지기는 정지로 본 수 / 정지로 보지 않은 수
        public var noDetected: Int
        public var noClear: Int
    }

    public static func checkIns(_ records: [CheckInRecord], stillMinutes threshold: Int) -> CheckInSummary {
        var answers: [CheckInAnswer: Int] = [:]
        var yesDetected = 0, yesMissed = 0, noDetected = 0, noClear = 0
        for r in records {
            answers[r.answer, default: 0] += 1
            let detected = (r.stillMinutes ?? 0) >= Double(threshold)
            switch r.answer {
            case .yes: if detected { yesDetected += 1 } else { yesMissed += 1 }
            case .no: if detected { noDetected += 1 } else { noClear += 1 }
            case .unsure, .dismissed: break
            }
        }
        return CheckInSummary(total: records.count, answers: answers, yesDetected: yesDetected,
                              yesMissed: yesMissed, noDetected: noDetected, noClear: noClear)
    }

    // MARK: - 카드 뒤 실제로 일어났는지 (R1 효과, 실험 8)

    public struct Outcome: Sendable {
        public var rule: NudgeRule
        /// "카드" 또는 "아이콘"
        public var delivery: String
        public var count: Int
        public var stoodUp: Int
        public var rate: Double? { count > 0 ? Double(stoodUp) / Double(count) : nil }
    }

    /// 알림 뒤 `within`(기본 10분) 안에 자리를 떴는지. 완료 버튼으로 타이머를 다시 시작한 것은 일어난 것으로 보지 않고,
    /// 자리 비움·잠금으로 착석 구간이 끝났거나 카메라에서 얼굴이 대부분 사라진 분이 있으면 일어난 것으로 본다.
    public static func outcomes(nudges: [NudgeRecord], bouts: [SitBout], minutes: [PostureMinute],
                                within: TimeInterval = 600, params: SignalParameters = SignalParameters()) -> [Outcome] {
        func stoodUp(after t: Date) -> Bool {
            let limit = t.addingTimeInterval(within)
            if bouts.contains(where: { $0.end >= t && $0.end <= limit && ($0.endReason == .away || $0.endReason == .lock) }) {
                return true
            }
            return minutes.contains { m in
                m.label == nil && m.start >= t && m.start <= limit && m.frames >= params.minFrames && m.validRatio < 0.3
            }
        }
        var table: [String: Outcome] = [:]
        for n in nudges where n.rule != .breath && n.rule != .tiltRotation && n.rule != .screenApproach {
            let delivery = n.action == .icon ? "아이콘" : "카드"
            let key = n.rule.rawValue + delivery
            var o = table[key] ?? Outcome(rule: n.rule, delivery: delivery, count: 0, stoodUp: 0)
            o.count += 1
            if stoodUp(after: n.at) { o.stoodUp += 1 }
            table[key] = o
        }
        return table.values.sorted { ($0.rule.rawValue, $0.delivery) < ($1.rule.rawValue, $1.delivery) }
    }

    // MARK: - 비용 (실험 1)

    public struct CostSummary: Sendable {
        public var mode: AnalysisMode
        public var frameCap: Bool?
        public var minutes: Int
        public var cpuMean: Double?
        public var cpuMedian: Double?
        public var analysisMsMean: Double?
    }

    public static func cost(_ minutes: [PostureMinute]) -> [CostSummary] {
        let groups = Dictionary(grouping: minutes.filter { $0.cpuPercent != nil || $0.analysisMs != nil }) {
            "\($0.mode.rawValue)|\($0.frameCap.map { $0 ? "1" : "0" } ?? "-")"
        }
        return groups.values.compactMap { group -> CostSummary? in
            guard let first = group.first else { return nil }
            let cpu = group.compactMap(\.cpuPercent)
            let ms = group.compactMap(\.analysisMs)
            return CostSummary(mode: first.mode, frameCap: first.frameCap, minutes: group.count,
                               cpuMean: cpu.isEmpty ? nil : cpu.reduce(0, +) / Double(cpu.count),
                               cpuMedian: Stats.median(cpu),
                               analysisMsMean: ms.isEmpty ? nil : ms.reduce(0, +) / Double(ms.count))
        }
        .sorted { ($0.mode.rawValue, $0.frameCap == true ? 1 : 0) < ($1.mode.rawValue, $1.frameCap == true ? 1 : 0) }
    }
}
