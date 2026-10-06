import XCTest
@testable import SitCheckCore

private let t0 = Date(timeIntervalSince1970: 1_790_000_000)
private func sec(_ s: Double) -> Date { t0.addingTimeInterval(s) }

final class PostureMonitorTests: XCTestCase {
    let baseline = PostureBaseline(roll: 0, yaw: 0, faceWidth: 0.30, savedAt: t0)
    var settings = AppSettings.default

    private func sample(_ s: Double, roll: Double = 0, yaw: Double = 0, width: Double = 0.30) -> PostureSample {
        PostureSample(at: sec(s), roll: roll, yaw: yaw, faceWidth: width)
    }

    /// 1초 간격으로 같은 샘플을 넣는다.
    private func feed(_ monitor: inout PostureMonitor, from start: Double, to end: Double,
                      roll: Double = 0, yaw: Double = 0, width: Double = 0.30) {
        var s = start
        while s <= end {
            monitor.update(sample(s, roll: roll, yaw: yaw, width: width), at: sec(s), baseline: baseline, settings: settings)
            s += 1
        }
    }

    func testBaselineIsMedianOfSamples() {
        let samples = [sample(0, roll: 1, width: 0.3), sample(1, roll: 30, width: 0.9), sample(2, roll: 2, width: 0.31)]
        let b = PostureBaseline.from(samples, at: t0)
        XCTAssertEqual(b?.roll, 2)
        XCTAssertEqual(b?.faceWidth, 0.31)
        XCTAssertNil(PostureBaseline.from([], at: t0))
    }

    func testNoBaselineNeverFires() {
        var m = PostureMonitor()
        for s in 0...200 {
            m.update(sample(Double(s), roll: 30), at: sec(Double(s)), baseline: nil, settings: settings)
        }
        XCTAssertEqual(m.state, .noBaseline)
        XCTAssertNil(m.pendingRule(at: sec(200), settings: settings))
    }

    func testSustainedTiltFiresAfterHold() {
        var m = PostureMonitor()
        feed(&m, from: 0, to: 10)
        XCTAssertEqual(m.state, .good)
        feed(&m, from: 11, to: 60, roll: 20)
        XCTAssertEqual(m.state, .tilted)
        XCTAssertNil(m.pendingRule(at: sec(60), settings: settings))
        feed(&m, from: 61, to: 110, roll: 20)
        XCTAssertEqual(m.pendingRule(at: sec(110), settings: settings), .tiltRotation)
    }

    func testYawNeedsLargerMovementThanRoll() {
        var m = PostureMonitor()
        feed(&m, from: 0, to: 10, yaw: 15)
        XCTAssertEqual(m.state, .good)
        feed(&m, from: 11, to: 20, yaw: 20)
        XCTAssertEqual(m.state, .tilted)
    }

    func testApproachWhenFaceGrows() {
        var m = PostureMonitor()
        feed(&m, from: 0, to: 120, width: 0.36)
        XCTAssertEqual(m.state, .approaching)
        XCTAssertEqual(m.pendingRule(at: sec(120), settings: settings), .screenApproach)
    }

    func testSingleOutlierIsSmoothedAway() {
        var m = PostureMonitor()
        feed(&m, from: 0, to: 10)
        m.update(sample(11, roll: 40), at: sec(11), baseline: baseline, settings: settings)
        XCTAssertEqual(m.state, .good)
    }

    func testReturningToGoodResetsTimer() {
        var m = PostureMonitor()
        feed(&m, from: 0, to: 80, roll: 20)
        feed(&m, from: 81, to: 90)
        feed(&m, from: 91, to: 150, roll: 20)
        XCTAssertNil(m.pendingRule(at: sec(150), settings: settings))
    }

    func testBriefFaceLossIsIgnoredButLongLossResets() {
        var m = PostureMonitor()
        feed(&m, from: 0, to: 60, roll: 20)
        m.update(nil, at: sec(63), baseline: baseline, settings: settings)
        XCTAssertEqual(m.state, .tilted)
        feed(&m, from: 64, to: 100, roll: 20)
        XCTAssertEqual(m.pendingRule(at: sec(100), settings: settings), .tiltRotation)

        m.update(nil, at: sec(110), baseline: baseline, settings: settings)
        XCTAssertEqual(m.state, .noFace)
        XCTAssertNil(m.pendingRule(at: sec(110), settings: settings))
        XCTAssertEqual(m.secondsSinceFace(at: sec(110)), 10)
    }

    func testResetDeviationRequiresAnotherHold() {
        var m = PostureMonitor()
        feed(&m, from: 0, to: 100, roll: 20)
        XCTAssertNotNil(m.pendingRule(at: sec(100), settings: settings))
        m.resetDeviation(at: sec(100))
        XCTAssertNil(m.pendingRule(at: sec(150), settings: settings))
        XCTAssertNotNil(m.pendingRule(at: sec(190), settings: settings))
    }

    func testOldSettingsJSONGetsCameraDefaults() throws {
        let old = #"{"sitAlertMinutes":45}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: old)
        XCTAssertEqual(decoded.sitAlertMinutes, 45)
        XCTAssertTrue(decoded.cameraEnabled)
        XCTAssertNil(decoded.postureBaseline)
    }
}

final class PostureSchedulerTests: XCTestCase {
    var settings: AppSettings = {
        var s = AppSettings.default
        s.breathEnabled = false
        return s
    }()

    private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

    func testPostureCardFiresWhileSitting() {
        var s = NudgeScheduler()
        XCTAssertEqual(s.evaluate(now: at(5), boutStart: at(0), settings: settings, posture: .stillness),
                       .showCard(.stillness))
        XCTAssertNil(s.evaluate(now: at(5), boutStart: nil, settings: settings, posture: .stillness))
    }

    func testLongSittingTakesPriority() {
        var s = NudgeScheduler()
        XCTAssertEqual(s.evaluate(now: at(40), boutStart: at(0), settings: settings, posture: .drift),
                       .showCard(.longSitting))
    }

    func testSamePostureRuleWaitsRepeatInterval() {
        var s = NudgeScheduler()
        s.cardShown(.stillness, at: at(5))
        s.cardResolved(.done, at: at(6), settings: settings)
        XCTAssertNil(s.evaluate(now: at(20), boutStart: at(10), settings: settings, posture: .stillness))
        XCTAssertEqual(s.evaluate(now: at(35), boutStart: at(10), settings: settings, posture: .stillness),
                       .showCard(.stillness))
    }

    func testOtherRuleRespectsCooldown() {
        var s = NudgeScheduler()
        s.cardShown(.stillness, at: at(5))
        s.cardResolved(.done, at: at(6), settings: settings)
        XCTAssertNil(s.evaluate(now: at(15), boutStart: at(6), settings: settings, posture: .drift))
        XCTAssertEqual(s.evaluate(now: at(21), boutStart: at(6), settings: settings, posture: .drift),
                       .showCard(.drift))
    }

    func testMutedBlocksPosture() {
        var s = NudgeScheduler()
        s.mute(at: at(0), settings: settings)
        XCTAssertNil(s.evaluate(now: at(30), boutStart: at(0), settings: settings, posture: .stillness))
    }
}
