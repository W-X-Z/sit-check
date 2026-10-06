import XCTest
@testable import SitCheckCore

private let t0 = Date(timeIntervalSince1970: 1_790_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

final class SitTrackerTests: XCTestCase {
    func testStartsBoutOnInputAndCountsMinutes() {
        var tracker = SitTracker(awayThreshold: 180)
        tracker.tick(now: at(0), idleSeconds: 2)
        XCTAssertTrue(tracker.isSitting)
        tracker.tick(now: at(41), idleSeconds: 5)
        XCTAssertEqual(tracker.sittingSeconds(at: at(41)) / 60, 41, accuracy: 0.1)
    }

    func testThreeMinutesIdleClosesBoutAtLastInput() {
        var tracker = SitTracker(awayThreshold: 180)
        tracker.tick(now: at(0), idleSeconds: 0)
        tracker.tick(now: at(20), idleSeconds: 60)
        let bout = tracker.tick(now: at(23), idleSeconds: 180)
        XCTAssertFalse(tracker.isSitting)
        XCTAssertEqual(bout?.start, at(0))
        XCTAssertEqual(bout?.end, at(20))
        // 돌아오면 새 구간
        tracker.tick(now: at(30), idleSeconds: 1)
        XCTAssertTrue(tracker.isSitting)
        XCTAssertLessThan(tracker.sittingSeconds(at: at(30)), 5)
    }

    func testSparseTicksDoNotResetWhileInputContinues() {
        var tracker = SitTracker(awayThreshold: 180)
        tracker.tick(now: at(0), idleSeconds: 0)
        // 타이머가 늦게 돌아도 입력이 이어졌다면 같은 구간이다
        XCTAssertNil(tracker.tick(now: at(30), idleSeconds: 2))
        XCTAssertEqual(tracker.sittingSeconds(at: at(30)) / 60, 30, accuracy: 0.01)
    }

    func testSleepClosesBout() {
        var tracker = SitTracker(awayThreshold: 180)
        tracker.tick(now: at(0), idleSeconds: 0)
        let bout = tracker.markAway(at: at(10))
        XCTAssertEqual(bout?.end, at(10))
        tracker.tick(now: at(70), idleSeconds: 1)
        XCTAssertLessThan(tracker.sittingSeconds(at: at(70)), 5)
    }

    func testShortBoutIsNotRecorded() {
        var tracker = SitTracker(awayThreshold: 180)
        tracker.tick(now: at(0), idleSeconds: 0)
        XCTAssertNil(tracker.markAway(at: at(0.5)))
        XCTAssertFalse(tracker.isSitting)
    }

    func testRestartAfterStretch() {
        var tracker = SitTracker(awayThreshold: 180)
        tracker.tick(now: at(0), idleSeconds: 0)
        let bout = tracker.restart(at: at(42))
        XCTAssertEqual(bout?.durationMinutes ?? 0, 42, accuracy: 0.01)
        XCTAssertEqual(tracker.sittingSeconds(at: at(43)), 60, accuracy: 0.01)
    }
}

final class PrescriberTests: XCTestCase {
    let prescriber = Prescriber()

    func testR1IsS5PlusOneRotating() {
        let picked = prescriber.prescribe(rule: .longSitting, history: [], excluded: []).map(\.id)
        XCTAssertEqual(picked, ["S5", "S1"])
    }

    func testRotatingSlotNeverRepeatsBackToBack() {
        var history: [[String]] = []
        var rotating: [String] = []
        for _ in 0..<12 {
            let ids = prescriber.prescribe(rule: .longSitting, history: history, excluded: []).map(\.id)
            XCTAssertEqual(ids.count, 2)
            XCTAssertEqual(ids.first, "S5")
            if let prev = history.last { XCTAssertNotEqual(ids[1], prev[1]) }
            history.append(ids)
            rotating.append(ids[1])
        }
        // 6개 순환 동작을 고르게 돈다
        XCTAssertEqual(Array(rotating.prefix(6)), ["S1", "S2", "S3", "S4", "S6", "S7"])
        XCTAssertEqual(Array(rotating.suffix(6)), ["S1", "S2", "S3", "S4", "S6", "S7"])
    }

    func testExcludedStretchesAreNeverPrescribed() {
        let picked = prescriber.prescribe(rule: .longSitting, history: [], excluded: ["S5", "S1"]).map(\.id)
        XCTAssertEqual(picked, ["S2", "S3"])
    }

    func testR2FixedPairFallsBackWhenRepeated() {
        let picked = prescriber.prescribe(rule: .tiltRotation, history: [["S2", "S1"]], excluded: []).map(\.id)
        XCTAssertFalse(picked.contains("S2"))
        XCTAssertFalse(picked.contains("S1"))
        XCTAssertEqual(picked.count, 2)
    }

    func testFillsEvenIfOnlyRepeatsRemain() {
        let excluded: Set<String> = ["S1", "S2", "S3", "S4", "S6"]
        let picked = prescriber.prescribe(rule: .longSitting, history: [["S5", "S7"]], excluded: excluded).map(\.id)
        XCTAssertEqual(picked, ["S5", "S7"])
    }
}

final class StretchPhaseTests: XCTestCase {
    func testBilateralPhasesWithoutExtra() {
        let s3 = StretchLibrary.stretch("S3")!
        XCTAssertEqual(s3.phases(extra: nil).map(\.seconds), [30, 30])
    }

    func testExtraSetAppendedAfterBothSides() {
        let s3 = StretchLibrary.stretch("S3")!
        let phases = s3.phases(extra: ExtraSet(side: .right, seconds: 30))
        XCTAssertEqual(phases.map(\.title), ["왼쪽", "오른쪽", "오른쪽 추가"])
    }

    func testDefaultSettingsHaveNoAsymmetricExtra() {
        XCTAssertTrue(AppSettings.default.extraSets.isEmpty)
    }
}

final class NudgeSchedulerTests: XCTestCase {
    var settings = AppSettings.default

    func testR1FiresAtFortyMinutes() {
        var s = NudgeScheduler()
        settings.breathEnabled = false
        XCTAssertNil(s.evaluate(now: at(39), boutStart: at(0), settings: settings))
        XCTAssertEqual(s.evaluate(now: at(40), boutStart: at(0), settings: settings), .showCard(.longSitting))
    }

    func testNoCardWhileVisibleAndSnoozeRefiresAfterTenMinutes() {
        var s = NudgeScheduler()
        settings.breathEnabled = false
        s.cardShown(.longSitting, at: at(40))
        XCTAssertNil(s.evaluate(now: at(41), boutStart: at(0), settings: settings))
        s.cardResolved(.snooze, at: at(41), settings: settings)
        XCTAssertNil(s.evaluate(now: at(50), boutStart: at(0), settings: settings))
        XCTAssertEqual(s.evaluate(now: at(51), boutStart: at(0), settings: settings), .showCard(.longSitting))
    }

    func testDismissMutesForAnHour() {
        var s = NudgeScheduler()
        s.cardShown(.longSitting, at: at(40))
        s.cardResolved(.dismiss, at: at(40), settings: settings)
        XCTAssertNil(s.evaluate(now: at(99), boutStart: at(0), settings: settings))
        XCTAssertEqual(s.evaluate(now: at(100), boutStart: at(0), settings: settings), .showCard(.longSitting))
    }

    func testBreathEveryTwentyMinutes() {
        var s = NudgeScheduler()
        XCTAssertNil(s.evaluate(now: at(19), boutStart: at(0), settings: settings))
        XCTAssertEqual(s.evaluate(now: at(20), boutStart: at(0), settings: settings), .breath)
        XCTAssertNil(s.evaluate(now: at(21), boutStart: at(0), settings: settings))
        XCTAssertEqual(s.evaluate(now: at(40), boutStart: at(0), settings: settings), .showCard(.longSitting))
    }

    func testNothingWhileAway() {
        var s = NudgeScheduler()
        XCTAssertNil(s.evaluate(now: at(100), boutStart: nil, settings: settings))
    }
}

final class CopyAndMetricsTests: XCTestCase {
    func testCardCopy() {
        XCTAssertEqual(NudgeCopy.reason(rule: .longSitting, sittingMinutes: 42), "42분째 앉아 있어요")
        let stretches = ["S5", "S1"].compactMap(StretchLibrary.stretch)
        XCTAssertEqual(NudgeCopy.action(for: stretches), "일어나서 2개만 하고 오세요")
    }

    func testCompletionRateIgnoresBreath() {
        let nudges = [
            NudgeRecord(at: at(0), rule: .longSitting, stretchIDs: [], action: .done),
            NudgeRecord(at: at(1), rule: .longSitting, stretchIDs: [], action: .snooze),
            NudgeRecord(at: at(2), rule: .breath, stretchIDs: [], action: .done),
        ]
        XCTAssertEqual(Metrics.completionRate(nudges), 0.5)
    }

    func testTightnessIndex() {
        let logs = [
            StretchLog(at: at(0), stretchID: "S3", tighterSide: .right),
            StretchLog(at: at(1), stretchID: "S3", tighterSide: .right),
            StretchLog(at: at(2), stretchID: "S3", tighterSide: .same),
            StretchLog(at: at(3), stretchID: "S3", tighterSide: .left),
            StretchLog(at: at(-20 * 1440), stretchID: "S3", tighterSide: .left), // 14일 밖
        ]
        let result = Metrics.tightnessIndex(logs, stretchID: "S3", now: at(10))
        XCTAssertEqual(result?.count, 4)
        XCTAssertEqual(result?.index ?? 0, 0.25, accuracy: 1e-9)
    }

    func testClinicAdviceAfterThreeConsecutiveDays() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let days = { (d: Double) in at(d * 1440) }
        let two = [days(0), days(1)].map { StretchLog(at: $0, stretchID: "S3", tighterSide: nil, symptom: .pain) }
        XCTAssertFalse(Metrics.needsClinicAdvice(two, now: days(1), calendar: cal))
        let three = two + [StretchLog(at: days(2), stretchID: "S2", tighterSide: nil, symptom: .numb)]
        XCTAssertTrue(Metrics.needsClinicAdvice(three, now: days(2), calendar: cal))
    }
}

final class StoreTests: XCTestCase {
    func testRoundTripAndExport() throws {
        let store = try Store(path: ":memory:")
        var settings = AppSettings.default
        settings.sitAlertMinutes = 45
        settings.excludedStretchIDs = ["S6"]
        try store.saveSettings(settings)
        XCTAssertEqual(try store.loadSettings(), settings)

        try store.insert(SitBout(start: at(0), end: at(42)))
        let id = try store.insert(NudgeRecord(at: at(40), rule: .longSitting, stretchIDs: ["S5", "S1"], action: .done))
        try store.insert(StretchLog(at: at(45), stretchID: "S5", tighterSide: .right, nudgeID: id))
        try store.insert(StretchLog(at: at(45), stretchID: "S1", tighterSide: nil, symptom: .pain, nudgeID: id))

        XCTAssertEqual(try store.recentPrescriptions(), [["S5", "S1"]])
        let logs = try store.stretchLogs(since: at(0))
        XCTAssertEqual(logs.map(\.tighterSide), [.right, nil])
        XCTAssertEqual(logs.map(\.symptom), [.none, .pain])
        XCTAssertEqual(try store.bouts(since: at(0)).first?.durationMinutes ?? 0, 42, accuracy: 0.01)

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = try store.exportCSV(to: dir)
        XCTAssertEqual(files.count, 6)
        let csv = try String(contentsOf: dir.appendingPathComponent("stretch_log.csv"), encoding: .utf8)
        XCTAssertTrue(csv.hasPrefix("at,stretch_id,tighter_side,symptom,nudge_id\n"))
        try? FileManager.default.removeItem(at: dir)

        try store.deleteAllRecords()
        XCTAssertTrue(try store.nudges(since: at(0)).isEmpty)
        XCTAssertEqual(try store.loadSettings().sitAlertMinutes, 45)
    }
}
