import XCTest
@testable import SitCheckCore

private let t0 = Date(timeIntervalSince1970: 1_789_981_200) // 2026-09-21 09:00 UTC
private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func input(_ minutesAfter: Double, bout: Date? = t0, sitting: Double = 30, events: [SignalEvent] = [],
                   still: Double? = nil, drift: Double? = nil, roll: Double = 1) -> SnapshotPlanner.Input {
    SnapshotPlanner.Input(now: t0.addingTimeInterval(minutesAfter * 60), boutStart: bout, sittingMinutes: sitting,
                          events: events, stillMinutes: still, driftScore: drift, params: SignalParameters(), roll: roll)
}

private func stillEvent(_ variant: String = "20분", actionable: Bool = true) -> SignalEvent {
    SignalEvent(rule: .stillness, at: t0, variant: variant, actionable: actionable, detail: [:])
}

/// 판정값 조정용 답 하나
private func answer(_ key: String, _ x: Double, _ wanted: SnapshotWant, reason: SnapshotReason = .random,
                    rule: NudgeRule? = nil, match: NudgeFeedback? = nil, extra: [String: Double] = [:]) -> Snapshot {
    var state = extra
    state[key] = x
    return Snapshot(at: t0, reason: reason, rule: rule, photos: [SnapshotPhoto(slot: "now", at: t0)], state: state,
                    wanted: wanted, match: match, labeledAt: t0)
}

/// 정지 30분 이상일 때만 알림을 원한 답 14개
private func stillAnswers() -> [Snapshot] {
    let no: [Double] = [5, 8, 10, 12, 15, 18, 20, 22, 25, 28]
    let yes: [Double] = [31, 35, 40, 45, 50]
    return no.map { answer(SnapshotKey.stillMinutes, $0, .no) } + yes.map { answer(SnapshotKey.stillMinutes, $0, .yes) }
}

final class SnapshotPlannerTests: XCTestCase {
    func testEventSnapshotsRespectGapAndPerRuleCap() {
        var planner = SnapshotPlanner(perDay: 8)
        planner.calendar = utc
        let first = planner.decide(input(30, events: [stillEvent()]))
        XCTAssertEqual(first, SnapshotPlanner.Decision(reason: .event, rule: .stillness, variant: "20분"))
        planner.taken(first!, at: t0.addingTimeInterval(30 * 60), boutStart: t0)

        XCTAssertNil(planner.decide(input(31, events: [stillEvent("30분", actionable: false)], roll: 0)), "15분 간격 전")
        let second = planner.decide(input(46, events: [stillEvent("30분", actionable: false)]))
        XCTAssertEqual(second?.reason, .event, "기록 전용 변형도 판정값을 올릴 근거로 찍는다")
        planner.taken(second!, at: t0.addingTimeInterval(46 * 60), boutStart: t0)

        XCTAssertNil(planner.decide(input(62, events: [stillEvent("45분", actionable: false)])), "규칙별 하루 2장")
        let drift = SignalEvent(rule: .drift, at: t0, variant: "아래로", actionable: true, detail: [:])
        XCTAssertEqual(planner.decide(input(62, events: [drift]))?.rule, .drift)
        XCTAssertEqual(planner.takenToday, 2)
    }

    func testNearThresholdOncePerBout() {
        var planner = SnapshotPlanner(perDay: 8)
        planner.calendar = utc
        XCTAssertNil(planner.decide(input(20, still: 13)), "판정값(20분)의 70% 미만")
        let near = planner.decide(input(20, still: 15))
        XCTAssertEqual(near, SnapshotPlanner.Decision(reason: .nearThreshold, rule: .stillness))
        planner.taken(near!, at: t0.addingTimeInterval(20 * 60), boutStart: t0)
        XCTAssertNil(planner.decide(input(40, still: 16)), "같은 착석 구간에서는 한 번")
        let otherBout = t0.addingTimeInterval(3600)
        XCTAssertEqual(planner.decide(input(90, bout: otherBout, still: 16))?.reason, .nearThreshold)
        XCTAssertEqual(planner.decide(input(90, bout: otherBout, drift: 2.0))?.rule, .drift, "R6 기준 3σ의 60% 이상")
    }

    func testRandomNeedsSittingAndRoll() {
        var planner = SnapshotPlanner(perDay: 8)
        planner.calendar = utc
        XCTAssertNil(planner.decide(input(5, sitting: 5, roll: 0)), "앉은 지 10분 전")
        XCTAssertNil(planner.decide(input(30, bout: nil, roll: 0)), "앉아 있지 않음")
        XCTAssertNil(planner.decide(input(30, roll: 0.5)))
        XCTAssertEqual(planner.decide(input(30, roll: 0))?.reason, .random)
        for i in 0..<3 {
            planner.taken(.init(reason: .random), at: t0.addingTimeInterval(Double(i) * 1200), boutStart: t0)
        }
        XCTAssertNil(planner.decide(input(120, roll: 0)), "무작위는 하루 3장")
    }

    func testDailyCapRollsOver() {
        var planner = SnapshotPlanner(perDay: 1)
        planner.calendar = utc
        planner.taken(.init(reason: .random), at: t0, boutStart: t0)
        XCTAssertNil(planner.decide(input(60, roll: 0)))
        let nextDay = t0.addingTimeInterval(86_400)
        XCTAssertEqual(planner.decide(input(24 * 60 + 30, bout: nextDay, roll: 0))?.reason, .random)
    }
}

final class GradualTunerTests: XCTestCase {
    func testBalancedAccuracy() {
        let pts: [(x: Double, yes: Bool)] = [(10, false), (20, false), (30, true), (40, true)]
        XCTAssertEqual(GradualTuner.balancedAccuracy(pts, threshold: 25, firesAbove: true), 1)
        XCTAssertEqual(GradualTuner.balancedAccuracy(pts, threshold: 35, firesAbove: true), 0.75)
        XCTAssertEqual(GradualTuner.balancedAccuracy(pts, threshold: 25, firesAbove: false), 0)
        XCTAssertNil(GradualTuner.balancedAccuracy([(10, true)], threshold: 5, firesAbove: true))
    }

    func testStillMinutesMovesOneStepPerDay() throws {
        let answers = stillAnswers()
        var params = SignalParameters()
        XCTAssertEqual(params.stillMinutes, 20)

        let eval = try XCTUnwrap(GradualTuner.evaluate(answers, params: params).first { $0.parameter == "stillMinutes" })
        XCTAssertTrue(eval.ready)
        XCTAssertEqual(eval.best, 30)
        XCTAssertEqual(eval.bestScore, 1)
        XCTAssertEqual(eval.next, 25)

        var history = GradualTuner.tune(answers, params: &params, history: [], now: t0, calendar: utc)
        XCTAssertEqual(params.stillMinutes, 25, "하루 한 칸")
        XCTAssertEqual(history.map(\.parameter), ["stillMinutes"])
        XCTAssertEqual(history.first?.oldValue, 20)

        XCTAssertTrue(GradualTuner.tune(answers, params: &params, history: history, now: t0.addingTimeInterval(3600), calendar: utc).isEmpty,
                      "같은 날 두 번 옮기지 않는다")
        history += GradualTuner.tune(answers, params: &params, history: history, now: t0.addingTimeInterval(86_400), calendar: utc)
        XCTAssertEqual(params.stillMinutes, 30)
        XCTAssertTrue(GradualTuner.tune(answers, params: &params, history: history, now: t0.addingTimeInterval(2 * 86_400), calendar: utc).isEmpty,
                      "가장 나은 값에 닿으면 멈춘다")
    }

    func testNeedsEnoughAnswersOfBothKinds() {
        var params = SignalParameters()
        let fewNo = (0..<3).map { answer(SnapshotKey.stillMinutes, Double($0), .no) }
            + (0..<10).map { answer(SnapshotKey.stillMinutes, 40 + Double($0), .yes) }
        XCTAssertTrue(GradualTuner.tune(fewNo, params: &params, history: [], now: t0, calendar: utc).isEmpty)
        let unsure = stillAnswers().map { s -> Snapshot in
            var s = s
            s.wanted = .unsure
            return s
        }
        XCTAssertTrue(GradualTuner.tune(unsure, params: &params, history: [], now: t0, calendar: utc).isEmpty)
        XCTAssertEqual(params, SignalParameters())
    }

    func testOnlyRandomAndSameRuleAnswersCount() {
        // 다른 규칙(R6) 알림 순간의 '네'와 감지가 틀렸다는 답은 R5 판정값에 쓰지 않는다.
        let noise = (0..<6).map { _ in answer(SnapshotKey.stillMinutes, 5, .yes, reason: .event, rule: .drift) }
            + (0..<6).map { _ in answer(SnapshotKey.stillMinutes, 50, .no, reason: .event, rule: .stillness, match: .wrong) }
        var params = SignalParameters()
        let eval = GradualTuner.evaluate(stillAnswers() + noise, params: params).first { $0.parameter == "stillMinutes" }
        XCTAssertEqual(eval?.samples, 15)
        _ = GradualTuner.tune(stillAnswers() + noise, params: &params, history: [], now: t0, calendar: utc)
        XCTAssertEqual(params.stillMinutes, 25)
    }

    func testNearCmFiresBelowThreshold() {
        // 45 cm보다 가까울 때만 알림을 원함. 지금 판정값 40 cm → 42.5 cm로 한 칸
        let no: [Double] = [48, 50, 52, 55, 58, 60, 65]
        let yes: [Double] = [35, 38, 41, 43, 44]
        let answers = no.map { answer(SnapshotKey.distanceCm, $0, .no) } + yes.map { answer(SnapshotKey.distanceCm, $0, .yes) }
        var params = SignalParameters()
        let changes = GradualTuner.tune(answers, params: &params, history: [], now: t0, calendar: utc)
        XCTAssertEqual(changes.map(\.parameter), ["nearCm"])
        XCTAssertEqual(params.nearCm, 42.5)
    }

    func testShiftKLowersWhenStillnessDetectionOftenWrong() {
        let shift = SignalParameters().shiftK
        let events = (0..<8).map { i in
            answer(SnapshotKey.stillMinutes, 20, .unsure, reason: .event, rule: .stillness,
                   match: i < 6 ? .wrong : .right, extra: [SnapshotKey.shiftK: shift])
        }
        var params = SignalParameters()
        var history = GradualTuner.tune(events, params: &params, history: [], now: t0, calendar: utc)
        XCTAssertEqual(params.shiftK, shift - 0.5)
        XCTAssertEqual(history.map(\.parameter), ["shiftK"])
        history += GradualTuner.tune(events, params: &params, history: history, now: t0.addingTimeInterval(86_400), calendar: utc)
        XCTAssertEqual(params.shiftK, shift - 0.5, "이전 기준으로 찍은 답은 다시 쓰지 않는다")
    }

    func testResetBlocksTuningThatDay() {
        var params = SignalParameters()
        let reset = TuningChange(at: t0, parameter: "reset", oldValue: 0, newValue: 0, samples: 0, note: "되돌리기")
        XCTAssertTrue(GradualTuner.tune(stillAnswers(), params: &params, history: [reset], now: t0.addingTimeInterval(60), calendar: utc).isEmpty)
    }
}

final class SnapshotModelTests: XCTestCase {
    func testReviewAndRecheckState() {
        var s = Snapshot(at: t0, reason: .random, photos: [SnapshotPhoto(slot: "now", at: t0)])
        XCTAssertTrue(s.needsReview(at: t0))
        s.labeledAt = t0
        s.wanted = .no
        XCTAssertFalse(s.needsReview(at: t0))
        s.recheckDue = t0.addingTimeInterval(2 * 86_400)
        XCTAssertFalse(s.needsReview(at: t0.addingTimeInterval(86_400)))
        XCTAssertTrue(s.needsReview(at: t0.addingTimeInterval(3 * 86_400)))
        s.recheckAt = t0.addingTimeInterval(3 * 86_400)
        XCTAssertFalse(s.needsReview(at: t0.addingTimeInterval(4 * 86_400)))
        s.recheckAt = nil
        s.photosDeletedAt = t0
        XCTAssertFalse(s.needsReview(at: t0.addingTimeInterval(3 * 86_400)), "사진이 없으면 보여 주지 않는다")
    }

    func testFactsStateValuesOnly() {
        let s = Snapshot(at: t0, reason: .event, rule: .stillness, variant: "20분", photos: [],
                         state: [SnapshotKey.sittingMinutes: 35.2, SnapshotKey.stillMinutes: 21,
                                 SnapshotKey.driftLower: 1.24, SnapshotKey.driftCloser: -0.3])
        XCTAssertEqual(SnapshotCopy.facts(s), ["앉은 지 35분", "감지: 마지막 자세 변화 뒤 21분",
                                               "감지: 앉은 직후보다 아래로 1.2 · 가까이 -0.3 (흔들림의 배수)"])
        XCTAssertEqual(SnapshotCopy.eventLine(s), "'오래 같은 자세 (20분)' 알림이 울렸을 순간이에요")
        let photo = SnapshotPhoto(slot: "m10", at: t0.addingTimeInterval(-600))
        XCTAssertEqual(SnapshotCopy.slotTitle(photo, snapshotAt: t0), "10분 전")
        for text in SnapshotCopy.facts(s) + [SnapshotCopy.eventLine(s) ?? ""] {
            for word in ["나쁜", "바른", "교정", "고치"] { XCTAssertFalse(text.contains(word), text) }
        }
    }

    func testRecheckAgreement() {
        func pair(_ a: SnapshotActivity, _ b: SnapshotActivity, _ w1: SnapshotWant, _ w2: SnapshotWant) -> Snapshot {
            Snapshot(at: t0, reason: .random, photos: [], activity: a, wanted: w1, labeledAt: t0,
                     recheckActivity: b, recheckWanted: w2, recheckAt: t0)
        }
        let r = SnapshotAgreement.recheck([pair(.screen, .screen, .no, .no), pair(.sink, .lookDown, .yes, .no),
                                           Snapshot(at: t0, reason: .random, photos: [])])
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r.activity, 0.5)
        XCTAssertEqual(r.wanted, 0.5)
    }
}

final class PhotoStoreTests: XCTestCase {
    func testWriteDeleteAndPermissions() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("photos-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let photos = PhotoStore(directory: dir)
        try photos.write(Data([0xFF, 0xD8, 0xFF]), id: 7, slot: "now")
        try photos.write(Data([0xFF, 0xD8, 0xFF]), id: 7, slot: "ref")
        XCTAssertTrue(photos.exists(id: 7, slot: "now"))
        let fileAttrs = try FileManager.default.attributesOfItem(atPath: photos.url(id: 7, slot: "now").path)
        XCTAssertEqual((fileAttrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        let dirAttrs = try FileManager.default.attributesOfItem(atPath: dir.path)
        XCTAssertEqual((dirAttrs[.posixPermissions] as? NSNumber)?.intValue, 0o700)

        photos.delete(id: 7, slots: ["now"])
        XCTAssertFalse(photos.exists(id: 7, slot: "now"))
        XCTAssertTrue(photos.exists(id: 7, slot: "ref"))
        photos.deleteAll()
        XCTAssertFalse(photos.exists(id: 7, slot: "ref"))
    }

    func testExpired() {
        let now = t0.addingTimeInterval(20 * 86_400)
        let photo = [SnapshotPhoto(slot: "now", at: t0)]
        let old = Snapshot(id: 1, at: t0, reason: .random, photos: photo)
        let fresh = Snapshot(id: 2, at: now, reason: .random, photos: photo)
        let labeled = Snapshot(id: 3, at: now, reason: .random, photos: photo, labeledAt: now)
        let recheck = Snapshot(id: 4, at: now, reason: .random, photos: photo, labeledAt: now, recheckDue: now.addingTimeInterval(86_400))
        let gone = Snapshot(id: 5, at: t0, reason: .random, photos: photo, photosDeletedAt: t0)
        let all = [old, fresh, labeled, recheck, gone]
        XCTAssertEqual(PhotoStore.expired(all, now: now, retentionDays: 14, keepLabeled: false).map(\.id), [1, 3])
        XCTAssertEqual(PhotoStore.expired(all, now: now, retentionDays: 14, keepLabeled: true).map(\.id), [1])
    }
}

final class StoreV3Tests: XCTestCase {
    func testSnapshotAndTuningRoundTrip() throws {
        let store = try Store(path: ":memory:")
        XCTAssertEqual(try store.userVersion(), 3)
        let s = Snapshot(at: t0, reason: .event, rule: .drift, variant: "아래로",
                         photos: [SnapshotPhoto(slot: "ref", at: t0.addingTimeInterval(-1800)), SnapshotPhoto(slot: "now", at: t0)],
                         state: [SnapshotKey.driftScore: 3.4, SnapshotKey.sittingMinutes: 31], settingsVersion: 9)
        let id = try store.insert(s)
        var loaded = try XCTUnwrap(try store.snapshots(since: t0.addingTimeInterval(-60)).first)
        XCTAssertEqual(loaded.id, id)
        loaded.id = nil
        XCTAssertEqual(loaded, s)

        try store.updateSnapshotLabel(id: id, activity: .lookDown, wanted: .no, match: .wrong, labeledAt: t0.addingTimeInterval(600),
                                      recheckDue: t0.addingTimeInterval(2 * 86_400))
        try store.updateSnapshotRecheck(id: id, activity: .lookDown, wanted: .yes, at: t0.addingTimeInterval(3 * 86_400))
        loaded = try XCTUnwrap(try store.snapshotsWithPhotos().first)
        XCTAssertEqual(loaded.activity, .lookDown)
        XCTAssertEqual(loaded.wanted, .no)
        XCTAssertEqual(loaded.match, .wrong)
        XCTAssertEqual(loaded.recheckWanted, .yes)
        XCTAssertNotNil(loaded.recheckAt)

        try store.markPhotosDeleted(snapshotID: id, at: t0.addingTimeInterval(3 * 86_400))
        XCTAssertTrue(try store.snapshotsWithPhotos().isEmpty)
        try store.insert(Snapshot(at: t0, reason: .random, photos: [SnapshotPhoto(slot: "now", at: t0)]))
        try store.markAllPhotosDeleted(at: t0)
        XCTAssertTrue(try store.snapshotsWithPhotos().isEmpty)

        try store.insert(TuningChange(at: t0, parameter: "stillMinutes", oldValue: 20, newValue: 25, samples: 14,
                                      scoreBefore: 0.8, scoreAfter: 0.9, note: "n"))
        let change = try XCTUnwrap(try store.tuningLog(since: t0.addingTimeInterval(-60)).first)
        XCTAssertEqual(change.newValue, 25)
        XCTAssertEqual(change.scoreAfter, 0.9)

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertEqual(try store.exportCSV(to: dir).count, 8)
        try? FileManager.default.removeItem(at: dir)

        try store.deleteAllRecords()
        XCTAssertTrue(try store.snapshots(since: .distantPast).isEmpty)
        XCTAssertTrue(try store.tuningLog(since: .distantPast).isEmpty)
    }

    func testOldSettingsGetPhotoDiaryOff() throws {
        let json = #"{"sitAlertMinutes": 45}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertFalse(settings.photoDiaryEnabled, "사진 일지는 직접 켜야 한다")
        XCTAssertTrue(settings.autoTune)
        XCTAssertEqual(settings.photoRetentionDays, 14)
    }
}
