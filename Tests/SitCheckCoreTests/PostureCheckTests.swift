import XCTest
@testable import SitCheckCore

private let t0 = Date(timeIntervalSince1970: 1_789_981_200) // 2026-09-21 09:00 UTC

/// t0부터 1초 간격 샘플 n개
private func samples(_ n: Int, from start: Int = 0, shoulderTilt: Double = 0, headTilt: Double = 0, sideLean: Double = 0,
                     headScale: Double = 0.4, neckRatio: Double = 0.5, yaw: Double = 0) -> [PostureSample] {
    (0..<n).map { i in
        PostureSample(at: t0.addingTimeInterval(Double(start + i)), yaw: yaw, faceWidth: 0.2,
                      neckRatio: neckRatio, shoulderWidth: 0.5,
                      shoulderTilt: shoulderTilt, headTilt: headTilt, sideLean: sideLean, headScale: headScale)
    }
}

private func feed(_ checker: inout PostureChecker, _ list: [PostureSample]) {
    for s in list { checker.update(s, at: s.at) }
}

private let ready = UprightReference(headScale: 0.4, neckRatio: 0.5, minutes: 5)

final class BodyGeometryTests: XCTestCase {
    func testLeftRightComesFromPositionNotLabel() {
        // 반전하지 않은 영상: 화면 오른쪽(x가 큰 쪽)이 사용자의 왼쪽. 그쪽 어깨가 20px 높다.
        var s = PostureSample(at: t0, faceWidth: 0.2)
        BodyGeometry.apply(shoulders: (PixelPoint(x: 480, y: 120), PixelPoint(x: 160, y: 100)),
                           eyes: (PixelPoint(x: 290, y: 300), PixelPoint(x: 350, y: 300)),
                           faceWidthPx: 128, frameWidth: 640, frameHeight: 480, to: &s)
        XCTAssertEqual(s.shoulderTilt!, atan2(20, 320) * 180 / .pi, accuracy: 1e-9)
        XCTAssertEqual(s.headTilt!, 0, accuracy: 1e-9)
        XCTAssertEqual(s.headScale!, 128.0 / (320 * 320 + 20 * 20).squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(s.shoulderWidth!, (320 * 320 + 20 * 20).squareRoot() / 640, accuracy: 1e-9)
        // 두 눈 가운데(x 320)가 어깨 가운데(x 320)와 같다.
        XCTAssertEqual(s.sideLean!, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(s.neckRatio!, 0)

        // 같은 점을 순서만 바꿔 넣어도 결과가 같다.
        var swapped = PostureSample(at: t0, faceWidth: 0.2)
        BodyGeometry.apply(shoulders: (PixelPoint(x: 160, y: 100), PixelPoint(x: 480, y: 120)),
                           eyes: (PixelPoint(x: 350, y: 300), PixelPoint(x: 290, y: 300)),
                           faceWidthPx: 128, frameWidth: 640, frameHeight: 480, to: &swapped)
        XCTAssertEqual(s, swapped)
    }

    func testHeadShiftAndTiltDirections() {
        // 머리가 화면 오른쪽(사용자의 왼쪽)으로 64px, 왼쪽 눈(화면 오른쪽)이 10px 높다.
        var s = PostureSample(at: t0, faceWidth: 0.2)
        BodyGeometry.apply(shoulders: (PixelPoint(x: 160, y: 100), PixelPoint(x: 480, y: 100)),
                           eyes: (PixelPoint(x: 354, y: 300), PixelPoint(x: 414, y: 310)),
                           faceWidthPx: 128, frameWidth: 640, frameHeight: 480, to: &s)
        XCTAssertEqual(s.sideLean!, 64.0 / 320, accuracy: 1e-9)
        XCTAssertGreaterThan(s.headTilt!, 0)
        XCTAssertEqual(s.shoulderTilt!, 0, accuracy: 1e-9)
    }

    func testNarrowShouldersAreIgnored() {
        var s = PostureSample(at: t0, faceWidth: 0.2)
        BodyGeometry.apply(shoulders: (PixelPoint(x: 300, y: 100), PixelPoint(x: 340, y: 100)), eyes: nil,
                           faceWidthPx: 128, frameWidth: 640, frameHeight: 480, to: &s)
        XCTAssertNil(s.shoulderWidth)
        XCTAssertNil(s.shoulderTilt)
    }
}

final class PostureCheckerTests: XCTestCase {
    func testShoulderTiltWithHysteresis() {
        var checker = PostureChecker()
        feed(&checker, samples(15))
        XCTAssertNotNil(checker.reading)
        XCTAssertTrue(checker.issues.isEmpty)
        XCTAssertNil(checker.badSince)

        feed(&checker, samples(20, from: 15, shoulderTilt: 9))
        XCTAssertEqual(checker.issues, [.shoulderTilt])
        XCTAssertNotNil(checker.badSince)

        // 7° × 0.8 = 5.6° 위면 그대로 바르지 않음
        feed(&checker, samples(20, from: 35, shoulderTilt: 6))
        XCTAssertEqual(checker.issues, [.shoulderTilt])

        feed(&checker, samples(20, from: 55, shoulderTilt: 5))
        XCTAssertTrue(checker.issues.isEmpty)
        XCTAssertNil(checker.badSince)
    }

    func testFaceOnlyRollJudgesHeadTilt() {
        var checker = PostureChecker()
        let list = (0..<12).map { i in
            PostureSample(at: t0.addingTimeInterval(Double(i)), roll: 14, faceWidth: 0.25)
        }
        feed(&checker, list)
        XCTAssertNotNil(checker.reading)
        XCTAssertEqual(checker.issues, [.headTilt])
        XCTAssertEqual(checker.reading?.phrase(.headTilt), "고개가 왼쪽으로 14°")
        XCTAssertNil(checker.reading?.shoulderTilt)
    }

    func testOtherAsymmetryItems() {
        var checker = PostureChecker()
        feed(&checker, samples(15, headTilt: -12, sideLean: 0.3))
        XCTAssertEqual(checker.issues, [.headTilt, .sideLean])
        XCTAssertEqual(checker.reading?.phrase(.headTilt), "고개가 오른쪽으로 12°")
        XCTAssertEqual(checker.reading?.phrase(.sideLean), "머리가 오른쪽으로 어깨 폭의 30%")
    }

    func testSideLeanIgnoredWhileHeadIsTurned() {
        var checker = PostureChecker()
        feed(&checker, samples(15, sideLean: 0.3, yaw: 35))
        XCTAssertNil(checker.reading?.sideLean)
        XCTAssertTrue(checker.issues.isEmpty)
    }

    func testAsymmetryOffWhenDisabled() {
        var params = PostureCheckParameters()
        params.asymmetry = false
        var checker = PostureChecker(params: params)
        feed(&checker, samples(15, shoulderTilt: 12, headTilt: 15))
        XCTAssertTrue(checker.issues.isEmpty)
    }

    func testForwardHeadNeedsReference() {
        var checker = PostureChecker()
        feed(&checker, samples(15, headScale: 0.5))
        XCTAssertNil(checker.reading?.headForward)
        XCTAssertTrue(checker.issues.isEmpty)

        checker.reference = UprightReference(headScale: 0.4, neckRatio: 0.5, minutes: 4)
        feed(&checker, samples(15, from: 15, headScale: 0.5))
        XCTAssertNil(checker.reading?.headForward, "기준 분이 모자라면 판정하지 않는다")
    }

    func testForwardHeadAgainstReference() {
        var checker = PostureChecker(reference: ready)
        feed(&checker, samples(15, headScale: 0.41, neckRatio: 0.5))
        XCTAssertTrue(checker.issues.isEmpty)

        // 얼굴이 어깨에 비해 12.5% 커지고 눈–어깨 간격이 약간 줄었다.
        feed(&checker, samples(20, from: 15, headScale: 0.45, neckRatio: 0.47))
        XCTAssertEqual(checker.issues, [.forwardHead])
        XCTAssertEqual(checker.reading!.headForward!, 0.125, accuracy: 1e-9)
        XCTAssertEqual(checker.reading?.phrase(.forwardHead), "머리가 기준보다 앞으로 13%")
    }

    func testTorsoRotationIsNotForwardHead() {
        // 몸통을 돌리면 어깨가 좁아 보여 얼굴 ÷ 어깨가 커지지만, 눈–어깨 간격 ÷ 어깨도 같이 커진다.
        var checker = PostureChecker(reference: ready)
        feed(&checker, samples(20, headScale: 0.45, neckRatio: 0.56))
        XCTAssertTrue(checker.issues.isEmpty)
    }

    func testCardEventAfterHoldMinutes() {
        var checker = PostureChecker(reference: ready)
        feed(&checker, samples(15, shoulderTilt: 9, headScale: 0.46, neckRatio: 0.49))
        let start = checker.badSince!
        XCTAssertNil(checker.cardEvent(at: start.addingTimeInterval(60)))

        let event = checker.cardEvent(at: start.addingTimeInterval(121))!
        XCTAssertEqual(event.rule, .forwardHead)
        XCTAssertEqual(event.variant, "forwardHead,shoulderTilt")
        XCTAssertEqual(event.detail["shoulderTilt"], 1)
        XCTAssertEqual(event.detail["bad_minutes"]!, 121.0 / 60, accuracy: 1e-9)

        let withoutHead = checker.cardEvent(at: start.addingTimeInterval(121), excluding: [.forwardHead])!
        XCTAssertEqual(withoutHead.rule, .asymmetry)
        XCTAssertNil(checker.cardEvent(at: start.addingTimeInterval(121), excluding: [.forwardHead, .shoulderTilt]))

        let copy = NudgeCopy.posture(event, sittingMinutes: 30)
        XCTAssertEqual(copy.reason, "2분째 자세가 바르지 않아요 (머리가 기준보다 앞으로 15%, 오른쪽 어깨가 9° 높음)")
        XCTAssertEqual(copy.action, PostureIssue.forwardHead.action)
    }

    func testBriefBodyLossKeepsBadTimer() {
        var checker = PostureChecker()
        feed(&checker, samples(15, shoulderTilt: 9))
        let since = checker.badSince
        // 20초 동안 몸이 안 보이다가 다시 보인다 (lossGrace 30초 안).
        for i in 15..<35 { checker.update(nil, at: t0.addingTimeInterval(Double(i))) }
        XCTAssertNil(checker.reading)
        XCTAssertEqual(checker.badSince, since)
        feed(&checker, samples(10, from: 35, shoulderTilt: 9))
        XCTAssertEqual(checker.badSince, since)

        // 40초 동안 안 보이면 처음부터 다시 센다.
        for i in 45..<85 { checker.update(nil, at: t0.addingTimeInterval(Double(i))) }
        XCTAssertNil(checker.badSince)
    }

    func testRestartBadTimer() {
        var checker = PostureChecker()
        feed(&checker, samples(15, shoulderTilt: 9))
        let later = t0.addingTimeInterval(200)
        checker.restartBadTimer(at: later)
        XCTAssertEqual(checker.badSince, later)
    }
}

final class UprightReferenceTests: XCTestCase {
    private func minute(_ into: Double, scale: Double, neck: Double, n: Int = 60, label: String? = nil) -> PostureMinute {
        let bout = t0
        let start = bout.addingTimeInterval(into * 60)
        func stat(_ v: Double) -> FeatureStat { FeatureStat(median: v, mad: 0.001, p10: v, p90: v, n: n) }
        return PostureMinute(start: start, end: start.addingTimeInterval(60), label: label, frames: 60, faceFrames: n,
                             stats: ["headScale": stat(scale), "neckRatio": stat(neck)], boutStart: bout)
    }

    func testUsesSettledMinutesOnly() {
        let minutes = [
            minute(0, scale: 0.9, neck: 0.1),                 // 앉은 직후 (제외)
            minute(2, scale: 0.40, neck: 0.50),
            minute(3, scale: 0.42, neck: 0.52),
            minute(4, scale: 0.41, neck: 0.51),
            minute(5, scale: 0.9, neck: 0.1, n: 10),          // 몸이 잘 안 잡힘 (제외)
            minute(6, scale: 0.9, neck: 0.1, label: "still"), // 실험 라벨 (제외)
            minute(30, scale: 0.9, neck: 0.1),                // 자리 잡은 뒤 (제외)
        ]
        let ref = UprightReference.build(from: minutes)!
        XCTAssertEqual(ref.minutes, 3)
        XCTAssertFalse(ref.isReady)
        XCTAssertEqual(ref.headScale, 0.41, accuracy: 1e-9)
        XCTAssertEqual(ref.neckRatio, 0.51, accuracy: 1e-9)
        XCTAssertNil(UprightReference.build(from: [minute(30, scale: 0.4, neck: 0.5)]))
    }
}

final class PostureCheckRuleTests: XCTestCase {
    func testPostureCheckCardsGetStretches() {
        let p = Prescriber()
        XCTAssertEqual(p.prescribe(rule: .forwardHead, history: [], excluded: []).map(\.id), ["S4", "S6"])
        XCTAssertEqual(p.prescribe(rule: .asymmetry, history: [], excluded: []).map(\.id), ["S2", "S1"])
        XCTAssertTrue(p.prescribe(rule: .stillness, history: [], excluded: []).isEmpty)
        XCTAssertTrue(NudgeRule.forwardHead.isPostureCard)
        XCTAssertTrue(NudgeRule.asymmetry.isPostureCheck)
        XCTAssertFalse(NudgeRule.stillness.isPostureCheck)
    }

    func testOldSettingsDecodeWithDefaults() throws {
        let old = #"{"sitAlertMinutes": 45}"#
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(old.utf8))
        XCTAssertEqual(s.sitAlertMinutes, 45)
        XCTAssertEqual(s.postureCheck, PostureCheckParameters())
        let partial = #"{"postureCheck": {"asymmetry": false}}"#
        let p = try JSONDecoder().decode(AppSettings.self, from: Data(partial.utf8))
        XCTAssertFalse(p.postureCheck.asymmetry)
        XCTAssertTrue(p.postureCheck.forwardHead)
        XCTAssertEqual(p.postureCheck.cardAfterMinutes, 2)
    }
}
