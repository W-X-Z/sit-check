import SQLite3
import XCTest
@testable import SitCheckCore

private let day0 = Date(timeIntervalSince1970: 1_789_948_800) // 2026-09-21 00:00 UTC
private let bout0 = day0.addingTimeInterval(9 * 3600)         // 09:00 UTC
private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

/// i번째 분 (착석 구간 시작 `bout`부터 i분 뒤 시작, 60초 길이)
private func minute(_ i: Int, bout: Date? = bout0, base: Date = bout0, y: Double = 0.5, w: Double = 0.3, x: Double = 0.5,
                    mad: Double = 0.002, faceFrames: Int = 60, label: String? = nil, yaw: Double? = nil) -> PostureMinute {
    let start = base.addingTimeInterval(Double(i) * 60)
    func stat(_ v: Double) -> FeatureStat {
        FeatureStat(median: v, mad: mad, p10: v - 1.3 * mad, p90: v + 1.3 * mad, n: faceFrames)
    }
    var stats = ["faceY": stat(y), "faceWidth": stat(w), "faceX": stat(x)]
    if let yaw { stats["yaw"] = FeatureStat(median: yaw, mad: 1, p10: yaw - 1, p90: yaw + 1, n: faceFrames) }
    return PostureMinute(start: start, end: start.addingTimeInterval(60), label: label, frames: 60,
                         faceFrames: faceFrames, stats: stats, boutStart: bout)
}

private func feedMinutes(_ signals: inout PostureSignals, _ minutes: [PostureMinute]) -> [(Int, SignalEvent)] {
    var out: [(Int, SignalEvent)] = []
    for (i, m) in minutes.enumerated() {
        for e in signals.process(m) { out.append((i, e)) }
    }
    return out
}

final class StatsTests: XCTestCase {
    func testFeatureStat() throws {
        let s = try XCTUnwrap(FeatureStat([1, 2, 3, 4, 100]))
        XCTAssertEqual(s.median, 3)
        XCTAssertEqual(s.mad, 1)
        XCTAssertEqual(s.p10, 1.4, accuracy: 1e-9)
        XCTAssertEqual(s.n, 5)
        XCTAssertNil(FeatureStat([]))
        XCTAssertNil(FeatureStat([.nan]))
    }
}

final class MinuteAggregatorTests: XCTestCase {
    func testClosesAtMinuteBoundaryAndOnContextChange() throws {
        var agg = MinuteAggregator()
        let ctx = MinuteAggregator.Context(mode: .face, boutStart: bout0)
        // 09:00:00 – 09:00:59 매초 프레임, 그중 10초는 얼굴 없음
        for s in 0..<60 {
            let sample = s < 50 ? PostureSample(at: bout0, roll: nil, faceWidth: 0.3, faceX: 0.5, faceY: 0.4 + Double(s) * 0.001) : nil
            XCTAssertNil(agg.add(sample, at: bout0.addingTimeInterval(Double(s)), analysisMs: 20, context: ctx))
        }
        let first = try XCTUnwrap(agg.add(nil, at: bout0.addingTimeInterval(60), analysisMs: 20, context: ctx))
        XCTAssertEqual(first.frames, 60)
        XCTAssertEqual(first.faceFrames, 50)
        XCTAssertEqual(first.validRatio, 50.0 / 60.0, accuracy: 1e-9)
        XCTAssertEqual(first.end, bout0.addingTimeInterval(60))
        XCTAssertEqual(first[.faceY]?.median ?? 0, 0.4245, accuracy: 1e-9)
        XCTAssertNil(first[.roll], "값이 없는 각도는 0°로 채우지 않는다")
        XCTAssertEqual(first.analysisMs ?? 0, 20, accuracy: 1e-9)

        // 같은 분 안에서 라벨이 바뀌면 바로 닫는다
        var labeled = ctx
        labeled.label = ExperimentLabel.still.rawValue
        let second = try XCTUnwrap(agg.add(nil, at: bout0.addingTimeInterval(70), analysisMs: nil, context: labeled))
        XCTAssertEqual(second.start, bout0.addingTimeInterval(60))
        XCTAssertNil(second.label)
        let third = try XCTUnwrap(agg.flush(at: bout0.addingTimeInterval(80)))
        XCTAssertEqual(third.label, "still")
        XCTAssertEqual(third.end, bout0.addingTimeInterval(71), "끝 시각은 마지막 프레임 + 1초")
    }
}

final class NoiseModelTests: XCTestCase {
    func testEstimateUsesMedianMADWithFloors() throws {
        let minutes = (0..<5).map { minute($0, mad: 0.004) }
        let noise = try XCTUnwrap(NoiseModel.estimate(from: minutes, source: "t"))
        XCTAssertEqual(noise.faceY, 0.004 * Stats.madToSigma, accuracy: 1e-9)
        XCTAssertEqual(noise.widthRel, 0.004 / 0.3 * Stats.madToSigma, accuracy: 1e-9)
        XCTAssertEqual(noise.roll, NoiseModel.defaults.roll, "각도 기록이 없으면 기본값")
        XCTAssertNil(NoiseModel.estimate(from: Array(minutes.prefix(2)), source: "t"))

        let tiny = (0..<5).map { minute($0, mad: 0) }
        XCTAssertEqual(try XCTUnwrap(NoiseModel.estimate(from: tiny, source: "t")).faceY, NoiseModel.floor.faceY)
    }
}

final class PostureSignalsTests: XCTestCase {
    func testStillnessFiresAtThresholdAndVariants() {
        var signals = PostureSignals()
        let events = feedMinutes(&signals, (0..<50).map { minute($0) })
        let still = events.filter { $0.1.rule == .stillness }
        XCTAssertEqual(still.map { $0.0 }, [19, 29, 44])
        XCTAssertEqual(still.map { $0.1.variant }, ["20분", "30분", "45분"])
        XCTAssertEqual(still.map { $0.1.actionable }, [true, false, false])
        XCTAssertTrue(signals.isActive(.stillness, at: bout0.addingTimeInterval(50 * 60)))
    }

    func testMovementRestartsStillness() {
        var signals = PostureSignals()
        // 25번째 분부터 얼굴 위치가 3 cm쯤 내려간 채로 머문다 → 그 순간을 자세 변화로 본다
        let minutes = (0..<50).map { minute($0, y: $0 >= 25 ? 0.55 : 0.5) }
        let still = feedMinutes(&signals, minutes).filter { $0.1.rule == .stillness && $0.1.actionable }
        XCTAssertEqual(still.map { $0.0 }, [19, 45])
    }

    func testLargeRangeWithinMinuteCountsAsMovement() {
        var signals = PostureSignals()
        var minutes = (0..<30).map { minute($0) }
        minutes[10] = minute(10, mad: 0.03) // 그 분 안에서 크게 움직임
        let still = feedMinutes(&signals, minutes).filter { $0.1.rule == .stillness && $0.1.actionable }
        XCTAssertTrue(still.isEmpty, "11분에 다시 세기 시작했으므로 30분 안에는 20분이 안 됨")
    }

    func testFaceMissingMinuteResetsStillness() {
        var signals = PostureSignals()
        var minutes = (0..<30).map { minute($0) }
        minutes[12] = minute(12, faceFrames: 10)
        XCTAssertTrue(feedMinutes(&signals, minutes).filter { $0.1.rule == .stillness }.isEmpty)
    }

    func testDriftDownFiresOnceAfterHold() {
        var signals = PostureSignals()
        let sigma = NoiseModel.defaults.faceY
        let minutes = (0..<20).map { minute($0, y: $0 >= 8 ? 0.5 + 5 * sigma : 0.5) }
        let drift = feedMinutes(&signals, minutes).filter { $0.1.rule == .drift }
        XCTAssertEqual(drift.map { $0.0 }, [15])
        XCTAssertEqual(drift.first?.1.variant, "아래로")
        XCTAssertEqual(drift.first?.1.detail["lower_pct"] ?? 0, 5 * sigma * 100, accuracy: 1e-9)
        XCTAssertEqual(signals.driftReference?.at, bout0.addingTimeInterval(120))
    }

    func testDriftRearmsAfterRecovery() {
        var signals = PostureSignals()
        let sigma = NoiseModel.defaults.faceY
        let ys = (0..<45).map { i -> Double in
            switch i {
            case 8..<20, 30...: return 0.5 + 5 * sigma
            default: return 0.5
            }
        }
        let drift = feedMinutes(&signals, ys.enumerated().map { minute($0.offset, y: $0.element) }).filter { $0.1.rule == .drift }
        XCTAssertEqual(drift.count, 2)
    }

    func testDriftIgnoresUpAndFarther() {
        var signals = PostureSignals()
        let minutes = (0..<25).map { minute($0, y: $0 >= 8 ? 0.45 : 0.5, w: $0 >= 8 ? 0.25 : 0.3) }
        XCTAssertTrue(feedMinutes(&signals, minutes).filter { $0.1.rule == .drift }.isEmpty)
        XCTAssertLessThan(signals.driftScore ?? 0, 0)
    }

    func testDriftCloser() {
        var signals = PostureSignals()
        let minutes = (0..<20).map { minute($0, w: $0 >= 8 ? 0.33 : 0.3) } // 얼굴 크기 +10%
        let drift = feedMinutes(&signals, minutes).filter { $0.1.rule == .drift }
        XCTAssertEqual(drift.first?.1.variant, "가까이")
        XCTAssertEqual(drift.first?.1.detail["closer_pct"] ?? 0, 10, accuracy: 1e-6)
    }

    func testNearNeedsCalibrationAndHold() {
        let minutes = (0..<12).map { minute($0, w: 0.32) }
        var uncalibrated = PostureSignals()
        XCTAssertTrue(feedMinutes(&uncalibrated, minutes).filter { $0.1.rule == .near }.isEmpty)

        var signals = PostureSignals(distance: DistanceCalibration(knownCm: 60, faceWidth: 0.2, calibratedAt: day0))
        let near = feedMinutes(&signals, minutes).filter { $0.1.rule == .near }
        XCTAssertEqual(near.map { $0.0 }, [9])
        XCTAssertEqual(near.first?.1.detail["distance_cm"] ?? 0, 37.5, accuracy: 1e-9)
        XCTAssertEqual(signals.distanceCm ?? 0, 37.5, accuracy: 1e-9)
    }

    func testNearSkipsTurnedHead() {
        var signals = PostureSignals(distance: DistanceCalibration(knownCm: 60, faceWidth: 0.2, calibratedAt: day0))
        let minutes = (0..<12).map { minute($0, w: 0.32, yaw: 40) }
        XCTAssertTrue(feedMinutes(&signals, minutes).filter { $0.1.rule == .near }.isEmpty)
    }

    func testNotSittingResets() {
        var signals = PostureSignals()
        _ = feedMinutes(&signals, (0..<10).map { minute($0) })
        XCTAssertNotNil(signals.stillMinutes(at: bout0.addingTimeInterval(600)))
        _ = signals.process(minute(10, bout: nil))
        XCTAssertNil(signals.stillMinutes(at: bout0.addingTimeInterval(660)))
    }

    func testLabeledMinutesAreIgnored() {
        var signals = PostureSignals()
        let events = feedMinutes(&signals, (0..<30).map { minute($0, label: "still") })
        XCTAssertTrue(events.isEmpty)
    }
}

final class BaselineTests: XCTestCase {
    private func threeDays() -> [PostureMinute] {
        (0..<3).flatMap { d -> [PostureMinute] in
            let bout = bout0.addingTimeInterval(Double(d) * 86_400)
            return (0..<20).map { minute($0, bout: bout, base: bout) }
        }
    }

    func testAutoBaselineFromSettledMinutes() throws {
        let baseline = try XCTUnwrap(AutoBaseline.build(from: threeDays(), calendar: utc))
        XCTAssertEqual(baseline.days, 3)
        XCTAssertEqual(baseline.minutes, 39, "앉은 지 2–15분만 후보")
        XCTAssertTrue(baseline.isReady)
        XCTAssertEqual(baseline.faceY, 0.5, accuracy: 1e-9)
        XCTAssertEqual(baseline.difference(faceX: 0.5, faceY: 0.5, faceWidth: 0.3), 0, accuracy: 1e-9)
        XCTAssertGreaterThan(baseline.difference(faceX: 0.5, faceY: 0.6, faceWidth: 0.3), 10)
    }

    func testCandidatesExcludeLabelsTurnedHeadAndMovement() {
        let noise = NoiseModel.defaults
        let params = SignalParameters()
        XCTAssertTrue(AutoBaseline.isCandidate(minute(5), noise: noise, params: params))
        XCTAssertFalse(AutoBaseline.isCandidate(minute(1), noise: noise, params: params))
        XCTAssertFalse(AutoBaseline.isCandidate(minute(15), noise: noise, params: params))
        XCTAssertFalse(AutoBaseline.isCandidate(minute(5, label: "natural"), noise: noise, params: params))
        XCTAssertFalse(AutoBaseline.isCandidate(minute(5, yaw: 30), noise: noise, params: params))
        XCTAssertFalse(AutoBaseline.isCandidate(minute(5, mad: 0.05), noise: noise, params: params))
        XCTAssertFalse(AutoBaseline.isCandidate(minute(5, faceFrames: 40), noise: noise, params: params))
    }

    func testNotReadyWithFewDays() throws {
        let one = (0..<20).map { minute($0) }
        XCTAssertFalse(try XCTUnwrap(AutoBaseline.build(from: one, calendar: utc)).isReady)
    }

    func testSetupChangeAtStartOfNewBout() throws {
        let baseline = try XCTUnwrap(AutoBaseline.build(from: threeDays(), calendar: utc))
        let bout = bout0.addingTimeInterval(3 * 86_400)
        var detector = SetupChangeDetector()
        var result: (score: Double, features: Int)?
        for i in 0..<6 {
            if let r = detector.process(minute(i, bout: bout, base: bout, y: 0.55, w: 0.36), baseline: baseline) { result = r }
        }
        XCTAssertEqual(result?.features, 2)

        var same = SetupChangeDetector()
        for i in 0..<6 {
            XCTAssertNil(same.process(minute(i, bout: bout, base: bout), baseline: baseline))
        }
    }
}

final class DeliveryTests: XCTestCase {
    func testWaitsForTypingPause() {
        var gate = DeliveryGate()
        XCTAssertFalse(gate.shouldDeliver("R1", now: bout0, idleSeconds: 0.5, inCall: false))
        XCTAssertFalse(gate.shouldDeliver("R1", now: bout0.addingTimeInterval(60), idleSeconds: 0.5, inCall: false))
        XCTAssertTrue(gate.shouldDeliver("R1", now: bout0.addingTimeInterval(90), idleSeconds: 3, inCall: false))
        XCTAssertFalse(gate.isWaiting("R1"))
    }

    func testMaxDefer() {
        var gate = DeliveryGate()
        XCTAssertFalse(gate.shouldDeliver("R5", now: bout0, idleSeconds: 0, inCall: false))
        XCTAssertTrue(gate.shouldDeliver("R5", now: bout0.addingTimeInterval(301), idleSeconds: 0, inCall: false))
    }

    func testCallDefersLonger() {
        var gate = DeliveryGate()
        XCTAssertFalse(gate.shouldDeliver("R1", now: bout0, idleSeconds: 10, inCall: true))
        XCTAssertFalse(gate.shouldDeliver("R1", now: bout0.addingTimeInterval(600), idleSeconds: 10, inCall: true))
        XCTAssertTrue(gate.shouldDeliver("R1", now: bout0.addingTimeInterval(1801), idleSeconds: 10, inCall: true))
    }

    func testCheckInPlanner() {
        var planner = CheckInPlanner(perDay: 2)
        planner.calendar = utc
        let t = bout0.addingTimeInterval(3600)
        XCTAssertFalse(planner.shouldAsk(now: t, sittingMinutes: 10, roll: 0))
        XCTAssertTrue(planner.shouldAsk(now: t, sittingMinutes: 30, roll: 0))
        XCTAssertFalse(planner.shouldAsk(now: t, sittingMinutes: 30, roll: 0.99), "확률을 넘는 난수")
        planner.asked(at: t)
        XCTAssertFalse(planner.shouldAsk(now: t.addingTimeInterval(3600), sittingMinutes: 30, roll: 0), "2시간 간격")
        XCTAssertTrue(planner.shouldAsk(now: t.addingTimeInterval(7200), sittingMinutes: 30, roll: 0))
        planner.asked(at: t.addingTimeInterval(7200))
        XCTAssertFalse(planner.shouldAsk(now: t.addingTimeInterval(4 * 3600), sittingMinutes: 30, roll: 0), "하루 2번")
        XCTAssertTrue(planner.shouldAsk(now: t.addingTimeInterval(86_400), sittingMinutes: 30, roll: 0), "다음 날")
    }
}

final class PostureCardSchedulingTests: XCTestCase {
    private var settings: AppSettings = {
        var s = AppSettings.default
        s.breathEnabled = false
        s.sitAlertMinutes = 600
        s.postureCardsPerDay = 2
        return s
    }()

    private func at(_ minutes: Double) -> Date { bout0.addingTimeInterval(minutes * 60) }

    func testDailyCapAndBackoff() {
        var s = NudgeScheduler()
        s.calendar = utc
        let bout = at(-5)
        XCTAssertEqual(s.evaluate(now: at(0), boutStart: bout, settings: settings, posture: .stillness), .showCard(.stillness))
        s.cardShown(.stillness, at: at(0))
        s.cardResolved(.snooze, at: at(1), settings: settings)
        XCTAssertEqual(s.backoff[.stillness], 1)
        XCTAssertEqual(s.repeatInterval(.stillness, settings: settings), 3600)
        XCTAssertNil(s.evaluate(now: at(30), boutStart: bout, settings: settings, posture: .stillness), "간격 두 배")
        XCTAssertEqual(s.evaluate(now: at(61), boutStart: bout, settings: settings, posture: .stillness), .showCard(.stillness))
        s.cardShown(.stillness, at: at(61))
        s.cardResolved(.done, at: at(62), settings: settings)
        XCTAssertEqual(s.backoff[.stillness], 0)
        XCTAssertEqual(s.postureCards(on: at(62)), 2)
        XCTAssertNil(s.evaluate(now: at(200), boutStart: bout, settings: settings, posture: .drift), "하루 상한")
        XCTAssertEqual(s.evaluate(now: at(24 * 60), boutStart: at(24 * 60 - 5), settings: settings, posture: .drift),
                       .showCard(.drift), "다음 날")
    }

    func testLegacyRulesNeverBecomeCards() {
        var s = NudgeScheduler()
        XCTAssertNil(s.evaluate(now: at(5), boutStart: at(0), settings: settings, posture: .tiltRotation))
    }

    func testIconOnlyCountsAndSnoozesR1() {
        var s = NudgeScheduler()
        s.calendar = utc
        var settings = self.settings
        settings.sitAlertMinutes = 40
        XCTAssertEqual(s.evaluate(now: at(40), boutStart: at(0), settings: settings), .showCard(.longSitting))
        s.iconShown(.longSitting, at: at(40), settings: settings)
        XCTAssertNil(s.cardVisible)
        XCTAssertNil(s.evaluate(now: at(45), boutStart: at(0), settings: settings), "아이콘 뒤에는 미루기처럼 기다린다")
        XCTAssertEqual(s.evaluate(now: at(51), boutStart: at(0), settings: settings), .showCard(.longSitting))
    }
}

final class AnalysisTests: XCTestCase {
    func testReplayMatchesLiveProcessing() {
        let minutes = (0..<50).map { minute($0) }
        let counts = Analysis.replay(minutes, params: SignalParameters(), noise: .defaults, distance: nil, calendar: utc)
        let day = utc.startOfDay(for: bout0)
        XCTAssertEqual(counts[day]?[.stillness], 1, "기록 전용 변형(30·45분)은 세지 않는다")
        let stats = Analysis.dayStats(counts, days: [day, day.addingTimeInterval(86_400)], rules: [.stillness, .drift])
        XCTAssertEqual(stats.first?.median, 0.5)
        XCTAssertEqual(stats.first?.max, 1)
        XCTAssertEqual(stats.first?.passes, true)
    }

    func testSeparation() throws {
        let natural = (0..<3).map { minute($0, label: "natural") }
        let sink = (3..<6).map { minute($0, y: 0.55, label: "sink") }
        let lookDown = (6..<9).map { minute($0, y: 0.505, label: "lookDown") }
        let leanIn = (9..<12).map { minute($0, w: 0.36, label: "leanIn") }
        let results = Analysis.separation(natural + sink + lookDown + leanIn, noise: .defaults, k: 3, calendar: utc)
        let byLabel = Dictionary(uniqueKeysWithValues: results.map { ($0.label, $0) })
        XCTAssertEqual(byLabel[.sink]?.triggerRatio, 1)
        XCTAssertEqual(byLabel[.sink]?.passes, true)
        XCTAssertEqual(byLabel[.lookDown]?.triggerRatio, 0)
        XCTAssertEqual(byLabel[.lookDown]?.passes, true)
        XCTAssertEqual(byLabel[.leanIn]?.passes, true)
        XCTAssertNil(byLabel[.natural]?.passes)
    }

    func testOutcomesCountOnlyRealStandUps() {
        let t = bout0.addingTimeInterval(40 * 60)
        let nudges = [
            NudgeRecord(at: t, rule: .longSitting, stretchIDs: ["S5"], action: .done),
            NudgeRecord(at: t.addingTimeInterval(3600), rule: .longSitting, stretchIDs: [], action: .icon),
            NudgeRecord(at: t.addingTimeInterval(7200), rule: .longSitting, stretchIDs: ["S5"], action: .snooze),
        ]
        let bouts = [
            SitBout(start: bout0, end: t, endReason: .restart),                                   // 완료 → 세지 않음
            SitBout(start: t, end: t.addingTimeInterval(3600 + 300), endReason: .away),           // 아이콘 뒤 5분
        ]
        let away = minute(165, faceFrames: 5) // 세 번째 알림 뒤 5분: 얼굴이 대부분 안 보임
        let rows = Analysis.outcomes(nudges: nudges, bouts: bouts, minutes: [away])
        let card = rows.first { $0.delivery == "카드" }
        let icon = rows.first { $0.delivery == "아이콘" }
        XCTAssertEqual(card?.count, 2)
        XCTAssertEqual(card?.stoodUp, 1)
        XCTAssertEqual(icon?.stoodUp, 1)
    }

    func testFeedbackPrecision() {
        let nudges = [
            NudgeRecord(at: bout0, rule: .stillness, stretchIDs: [], action: .done, feedback: .right),
            NudgeRecord(at: bout0, rule: .stillness, stretchIDs: [], action: .snooze, feedback: .right),
            NudgeRecord(at: bout0, rule: .stillness, stretchIDs: [], action: .snooze, feedback: .wrong),
            NudgeRecord(at: bout0, rule: .stillness, stretchIDs: [], action: .done, feedback: .setupChanged),
            NudgeRecord(at: bout0, rule: .stillness, stretchIDs: [], action: .icon),
            NudgeRecord(at: bout0, rule: .longSitting, stretchIDs: ["S5"], action: .done),
        ]
        let summary = Analysis.feedback(nudges)
        XCTAssertEqual(summary.count, 1)
        XCTAssertEqual(summary[0].cards, 4)
        XCTAssertEqual(summary[0].precision ?? 0, 2.0 / 3.0, accuracy: 1e-9)
    }

    func testDaysAndCost() {
        var minutes = (0..<10).map { minute($0) }
        minutes[3] = minute(3, faceFrames: 10)
        for i in minutes.indices { minutes[i].cpuPercent = Double(i); minutes[i].frameCap = true }
        let events = [PostureEventRecord(at: bout0, rule: .stillness, variant: "20분", mode: .shadow, actionable: true),
                      PostureEventRecord(at: bout0, rule: .stillness, variant: "30분", mode: .shadow, actionable: false),
                      PostureEventRecord(at: bout0, rule: .tiltRotation, variant: "예전 규칙", mode: .shadow, actionable: false)]
        let days = Analysis.days(minutes: minutes, events: events, calendar: utc)
        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].sittingMinutes, 10)
        XCTAssertEqual(days[0].faceCoverage ?? 0, 0.9, accuracy: 1e-9)
        XCTAssertEqual(days[0].events[.stillness], 1)
        XCTAssertEqual(days[0].events[.tiltRotation], 1)
        XCTAssertEqual(days[0].stillVariants["30분"], 1)

        let cost = Analysis.cost(minutes)
        XCTAssertEqual(cost.count, 1)
        XCTAssertEqual(cost[0].cpuMean ?? 0, 4.5, accuracy: 1e-9)
    }

    func testChooseNoisePrefersStillMeasurement() {
        let still = (0..<5).map { minute($0, mad: 0.004, label: "still") }
        XCTAssertEqual(Analysis.chooseNoise(minutes: still, calendar: utc).source, "가만히 측정 (5분)")
        XCTAssertEqual(Analysis.chooseNoise(minutes: [], calendar: utc), .defaults)
    }
}

final class CopyAndSettingsTests: XCTestCase {
    func testPostureCopyStatesFactsOnly() {
        let still = SignalEvent(rule: .stillness, at: bout0, variant: "20분", actionable: true, detail: ["still_minutes": 21.4])
        XCTAssertEqual(NudgeCopy.posture(still, sittingMinutes: 35).reason, "35분째 앉아 있고, 21분째 거의 같은 자세예요")
        let closer = SignalEvent(rule: .drift, at: bout0, variant: "가까이", actionable: true,
                                 detail: ["closer_pct": 8.2, "reference_at": bout0.addingTimeInterval(120).timeIntervalSince1970])
        XCTAssertEqual(NudgeCopy.posture(closer, sittingMinutes: 30, calendar: utc).reason,
                       "30분째 앉아 있고, 9:02 무렵보다 화면에 가까이 있어요 (얼굴 크기 +8%)")
    }

    func testDetectionVersionTracksDetectionSettingsOnly() {
        let a = AppSettings.default
        var b = a
        b.sitAlertMinutes = 50
        XCTAssertEqual(a.detectionVersion, b.detectionVersion)
        b.signals.stillMinutes = 30
        XCTAssertNotEqual(a.detectionVersion, b.detectionVersion)
    }

    func testOldSettingsGetShadowModeAndDefaults() throws {
        let old = #"{"sitAlertMinutes":45,"cameraEnabled":true,"tiltThresholdDegrees":10}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: old)
        XCTAssertEqual(decoded.postureAlertMode, .shadow)
        XCTAssertEqual(decoded.signals, SignalParameters())
        XCTAssertEqual(decoded.tiltThresholdDegrees, 10)
    }

    func testProtocolOrder() {
        var rng = SystemRandomNumberGenerator()
        let steps = ExperimentLabel.protocolSteps(using: &rng)
        XCTAssertEqual(steps.first, .natural)
        XCTAssertEqual(steps.last, .chairMove)
        XCTAssertEqual(Set(steps).count, 9)
        XCTAssertFalse(steps.contains(.still))
    }

    func testPostureRulesHaveNoStretches() {
        XCTAssertTrue(Prescriber().prescribe(rule: .stillness, history: [], excluded: []).isEmpty)
        XCTAssertTrue(Prescriber().prescribe(rule: .drift, history: [], excluded: []).isEmpty)
        XCTAssertEqual(Prescriber().prescribe(rule: .longSitting, history: [], excluded: []).count, 2)
    }
}

final class StoreV2Tests: XCTestCase {
    func testPostureTablesRoundTrip() throws {
        let store = try Store(path: ":memory:")
        XCTAssertEqual(try store.userVersion(), Store.schemaVersion)
        var m = minute(3, label: "still")
        m.frameCap = true
        m.cpuPercent = 1.25
        m.analysisMs = 18
        m.settingsVersion = 42
        let id = try store.insert(m)
        var loaded = try XCTUnwrap(try store.postureMinutes(since: day0).first)
        XCTAssertEqual(loaded.id, id)
        loaded.id = nil
        XCTAssertEqual(loaded, m)
        XCTAssertEqual(try store.postureMinutes(label: "still").count, 1)
        XCTAssertTrue(try store.postureMinutes(label: "natural").isEmpty)

        try store.insert(PostureEventRecord(at: bout0, rule: .drift, variant: "아래로", mode: .shadow, actionable: true,
                                            detail: ["lower_sigma": 3.5]))
        let event = try XCTUnwrap(try store.postureEvents(since: day0).first)
        XCTAssertEqual(event.rule, .drift)
        XCTAssertEqual(event.detail["lower_sigma"], 3.5)
        XCTAssertTrue(event.actionable)

        try store.insert(CheckInRecord(at: bout0, question: "q", answer: .yes, stillMinutes: 22, driftScore: nil))
        XCTAssertEqual(try store.checkIns(since: day0).first?.answer, .yes)

        try store.insert(NudgeRecord(at: bout0, rule: .stillness, stretchIDs: [], action: .icon, feedback: .wrong, detail: "{}"))
        let nudge = try XCTUnwrap(try store.nudges(since: day0).first)
        XCTAssertEqual(nudge.feedback, .wrong)
        XCTAssertEqual(nudge.action, .icon)
        XCTAssertTrue(try store.recentPrescriptions().isEmpty, "스트레칭이 없는 카드는 처방 이력에서 뺀다")

        try store.insert(SitBout(start: bout0, end: bout0.addingTimeInterval(600), endReason: .away))
        XCTAssertEqual(try store.bouts(since: day0).first?.endReason, .away)

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertEqual(try store.exportCSV(to: dir).count, 6)
        try? FileManager.default.removeItem(at: dir)

        try store.deleteAllRecords()
        XCTAssertTrue(try store.postureMinutes(since: day0).isEmpty)
    }

    func testMigratesVersion1Database() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("v1-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, """
            CREATE TABLE sit_bout (id INTEGER PRIMARY KEY AUTOINCREMENT, start_at REAL NOT NULL, end_at REAL NOT NULL, duration_min REAL NOT NULL);
            CREATE TABLE nudge (id INTEGER PRIMARY KEY AUTOINCREMENT, at REAL NOT NULL, rule_id TEXT NOT NULL, stretch_ids TEXT NOT NULL, action TEXT NOT NULL);
            INSERT INTO sit_bout (start_at, end_at, duration_min) VALUES (\(bout0.timeIntervalSince1970), \(bout0.timeIntervalSince1970 + 600), 10);
            INSERT INTO nudge (at, rule_id, stretch_ids, action) VALUES (\(bout0.timeIntervalSince1970), 'R2', 'S2,S1', 'done');
            PRAGMA user_version = 1;
            """, nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)

        let store = try Store(path: path)
        XCTAssertEqual(try store.userVersion(), 2)
        XCTAssertNil(try store.bouts(since: day0).first?.endReason)
        XCTAssertEqual(try store.nudges(since: day0).first?.rule, .tiltRotation)
        XCTAssertNoThrow(try store.insert(minute(0)))
        XCTAssertNoThrow(try store.insert(SitBout(start: bout0, end: bout0.addingTimeInterval(60), endReason: .lock)))
    }
}
