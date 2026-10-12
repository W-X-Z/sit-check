import XCTest
@testable import SitCheckCore

private let t0 = Date(timeIntervalSince1970: 1_789_981_200) // 2026-09-21 09:00 UTC
private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func input(_ minutesAfter: Double, bout: Date? = t0, sitting: Double = 30, events: [SignalEvent] = [],
                   near: [SnapshotPlanner.Decision] = [], roll: Double = 1) -> SnapshotPlanner.Input {
    SnapshotPlanner.Input(now: t0.addingTimeInterval(minutesAfter * 60), boutStart: bout, sittingMinutes: sitting,
                          events: events, near: near, roll: roll)
}

private func stillEvent(_ variant: String = "20분", actionable: Bool = true) -> SignalEvent {
    SignalEvent(rule: .stillness, at: t0, variant: variant, actionable: actionable, detail: [:])
}

private func nearStill(_ still: Double) -> [SnapshotPlanner.Decision] {
    SnapshotPlanner.nearCandidates(stillMinutes: still, signals: SignalParameters(), reading: nil,
                                   check: PostureCheckParameters(), flagged: [])
}

/// '알림 원함' 답 하나
private func answer(_ key: String, _ x: Double, _ wanted: SnapshotWant, reason: SnapshotReason = .random,
                    rule: NudgeRule? = nil, match: NudgeFeedback? = nil, extra: [String: Double] = [:]) -> Snapshot {
    var state = extra
    state[key] = x
    return Snapshot(at: t0, reason: reason, rule: rule, photos: [SnapshotPhoto(slot: "now", at: t0)], state: state,
                    wanted: wanted, match: match, labeledAt: t0)
}

/// "사진에서 보이는 자세" 답 하나
private func seen(_ key: String, _ x: Double, _ observed: Set<PostureIssue>) -> Snapshot {
    Snapshot(at: t0, reason: .random, photos: [SnapshotPhoto(slot: "now", at: t0)], state: [key: x],
             observed: observed, labeledAt: t0)
}

/// 정지 30분 이상일 때만 알림을 원한 답 15개
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
        XCTAssertNil(planner.decide(input(62, events: [drift])), "카드가 뜨지 않는 규칙(R6)은 찍지 않는다")
        let head = SignalEvent(rule: .forwardHead, at: t0, variant: "forwardHead", actionable: true, detail: [:])
        XCTAssertEqual(planner.decide(input(62, events: [head]))?.rule, .forwardHead)
        XCTAssertEqual(planner.takenToday, 2)
    }

    func testNearThresholdOncePerBout() {
        var planner = SnapshotPlanner(perDay: 8)
        planner.calendar = utc
        XCTAssertTrue(nearStill(13).isEmpty, "판정값(20분)의 70% 미만")
        let near = planner.decide(input(20, near: nearStill(15)))
        XCTAssertEqual(near, SnapshotPlanner.Decision(reason: .nearThreshold, rule: .stillness))
        planner.taken(near!, at: t0.addingTimeInterval(20 * 60), boutStart: t0)
        XCTAssertNil(planner.decide(input(40, near: nearStill(16))), "같은 착석 구간에서는 한 번")
        let otherBout = t0.addingTimeInterval(3600)
        XCTAssertEqual(planner.decide(input(90, bout: otherBout, near: nearStill(16)))?.reason, .nearThreshold)
    }

    func testNearCandidatesForPostureIssues() {
        // 거북목 판정값 10%의 70% 이상(8%), 어깨 7°의 70% 이상(-5.5°), 고개는 아직 멀고, 몸 치우침은 이미 바르지 않음으로 봄
        let reading = PostureReading(shoulderTilt: -5.5, headTilt: 2, sideLean: 0.3, headForward: 0.08, neckDrop: 0)
        let near = SnapshotPlanner.nearCandidates(stillMinutes: 5, signals: SignalParameters(), reading: reading,
                                                  check: PostureCheckParameters(), flagged: [.sideLean])
        XCTAssertEqual(near.map(\.variant), ["forwardHead", "shoulderTilt"])
        XCTAssertEqual(near.map(\.rule), [.forwardHead, .asymmetry])
        var check = PostureCheckParameters()
        check.asymmetry = false
        XCTAssertEqual(SnapshotPlanner.nearCandidates(stillMinutes: nil, signals: SignalParameters(), reading: reading,
                                                      check: check, flagged: []).map(\.variant), ["forwardHead"],
                       "꺼 둔 항목은 찍지 않는다")
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
        XCTAssertEqual(GradualTuner.balancedAccuracy(pts, threshold: 25), 1)
        XCTAssertEqual(GradualTuner.balancedAccuracy(pts, threshold: 35), 0.75)
        XCTAssertNil(GradualTuner.balancedAccuracy([(10, true)], threshold: 5))
    }

    func testStillMinutesMovesOneStepPerDay() throws {
        let answers = stillAnswers()
        var settings = AppSettings.default
        XCTAssertEqual(settings.signals.stillMinutes, 20)

        let eval = try XCTUnwrap(GradualTuner.evaluate(answers, settings: settings).first { $0.parameter == "stillMinutes" })
        XCTAssertTrue(eval.ready)
        XCTAssertEqual(eval.best, 30)
        XCTAssertEqual(eval.bestScore, 1)
        XCTAssertEqual(eval.next, 25)

        var history = GradualTuner.tune(answers, settings: &settings, history: [], now: t0, calendar: utc)
        XCTAssertEqual(settings.signals.stillMinutes, 25, "하루 한 칸")
        XCTAssertEqual(history.map(\.parameter), ["stillMinutes"])
        XCTAssertEqual(history.first?.oldValue, 20)

        XCTAssertTrue(GradualTuner.tune(answers, settings: &settings, history: history, now: t0.addingTimeInterval(3600), calendar: utc).isEmpty,
                      "같은 날 두 번 옮기지 않는다")
        history += GradualTuner.tune(answers, settings: &settings, history: history, now: t0.addingTimeInterval(86_400), calendar: utc)
        XCTAssertEqual(settings.signals.stillMinutes, 30)
        XCTAssertTrue(GradualTuner.tune(answers, settings: &settings, history: history, now: t0.addingTimeInterval(2 * 86_400), calendar: utc).isEmpty,
                      "가장 나은 값에 닿으면 멈춘다")
    }

    func testForwardHeadRatioFollowsWhatTheUserSees() {
        // 기준 대비 15% 넘게 커졌을 때만 사진에서 '머리가 앞으로 나옴'을 고름. 지금 10% → 12%로 한 칸
        let no: [Double] = [-0.02, 0.0, 0.03, 0.05, 0.08, 0.10, 0.11, 0.12, 0.13]
        let yes: [Double] = [0.16, 0.18, 0.22, 0.25]
        let answers = no.map { seen(SnapshotKey.headForward, $0, []) } + yes.map { seen(SnapshotKey.headForward, $0, [.forwardHead]) }
        var settings = AppSettings.default
        let changes = GradualTuner.tune(answers, settings: &settings, history: [], now: t0, calendar: utc)
        XCTAssertEqual(changes.map(\.parameter), ["forwardHeadRatio"])
        XCTAssertEqual(settings.postureCheck.forwardHeadRatio, 0.12, accuracy: 1e-9)
    }

    func testTiltUsesMagnitudeAndRespectsDisabledIssues() {
        // 어깨가 어느 쪽으로든 4° 넘게 기울었을 때 '어깨가 한쪽으로 기욺'을 고름. 지금 7° → 6°로 한 칸
        let no: [Double] = [0, 1, -1, 2, -2, 3, -3, 3.5]
        let yes: [Double] = [4.5, -5, 6, -6.5]
        let answers = no.map { seen(SnapshotKey.shoulderTilt, $0, []) } + yes.map { seen(SnapshotKey.shoulderTilt, $0, [.shoulderTilt]) }
        var settings = AppSettings.default
        _ = GradualTuner.tune(answers, settings: &settings, history: [], now: t0, calendar: utc)
        XCTAssertEqual(settings.postureCheck.shoulderTiltDegrees, 6)

        var off = AppSettings.default
        off.postureCheck.asymmetry = false
        XCTAssertTrue(GradualTuner.tune(answers, settings: &off, history: [], now: t0, calendar: utc).isEmpty,
                      "꺼 둔 판정은 옮기지 않는다")
    }

    func testNeedsEnoughAnswersOfBothKinds() {
        var settings = AppSettings.default
        let fewNo = (0..<3).map { answer(SnapshotKey.stillMinutes, Double($0), .no) }
            + (0..<10).map { answer(SnapshotKey.stillMinutes, 40 + Double($0), .yes) }
        XCTAssertTrue(GradualTuner.tune(fewNo, settings: &settings, history: [], now: t0, calendar: utc).isEmpty)
        let unsure = stillAnswers().map { s -> Snapshot in
            var s = s
            s.wanted = .unsure
            return s
        }
        XCTAssertTrue(GradualTuner.tune(unsure, settings: &settings, history: [], now: t0, calendar: utc).isEmpty)
        XCTAssertEqual(settings, AppSettings.default)
    }

    func testOnlyRandomAndSameRuleAnswersCount() {
        // 다른 규칙 알림 순간의 '네'와 감지가 틀렸다는 답은 R5 판정값에 쓰지 않는다.
        let noise = (0..<6).map { _ in answer(SnapshotKey.stillMinutes, 5, .yes, reason: .event, rule: .forwardHead) }
            + (0..<6).map { _ in answer(SnapshotKey.stillMinutes, 50, .no, reason: .event, rule: .stillness, match: .wrong) }
        var settings = AppSettings.default
        let eval = GradualTuner.evaluate(stillAnswers() + noise, settings: settings).first { $0.parameter == "stillMinutes" }
        XCTAssertEqual(eval?.samples, 15)
        _ = GradualTuner.tune(stillAnswers() + noise, settings: &settings, history: [], now: t0, calendar: utc)
        XCTAssertEqual(settings.signals.stillMinutes, 25)
    }

    func testShiftKLowersWhenStillnessDetectionOftenWrong() {
        let shift = SignalParameters().shiftK
        let events = (0..<8).map { i in
            answer(SnapshotKey.stillMinutes, 20, .unsure, reason: .event, rule: .stillness,
                   match: i < 6 ? .wrong : .right, extra: [SnapshotKey.shiftK: shift])
        }
        var settings = AppSettings.default
        var history = GradualTuner.tune(events, settings: &settings, history: [], now: t0, calendar: utc)
        XCTAssertEqual(settings.signals.shiftK, shift - 0.5)
        XCTAssertEqual(history.map(\.parameter), ["shiftK"])
        history += GradualTuner.tune(events, settings: &settings, history: history, now: t0.addingTimeInterval(86_400), calendar: utc)
        XCTAssertEqual(settings.signals.shiftK, shift - 0.5, "이전 기준으로 찍은 답은 다시 쓰지 않는다")
    }

    func testResetBlocksTuningThatDayAndRestoresDefaults() {
        var settings = AppSettings.default
        let reset = TuningChange(at: t0, parameter: "reset", oldValue: 0, newValue: 0, samples: 0, note: "되돌리기")
        XCTAssertTrue(GradualTuner.tune(stillAnswers(), settings: &settings, history: [reset], now: t0.addingTimeInterval(60), calendar: utc).isEmpty)

        settings.signals.stillMinutes = 35
        settings.postureCheck.forwardHeadRatio = 0.16
        settings.postureCheck.cardAfterMinutes = 4
        settings.postureCheck.asymmetry = false
        GradualTuner.reset(&settings)
        XCTAssertEqual(settings.signals.stillMinutes, 20)
        XCTAssertEqual(settings.postureCheck.forwardHeadRatio, 0.10)
        XCTAssertEqual(settings.postureCheck.cardAfterMinutes, 4, "판정값이 아닌 설정은 그대로")
        XCTAssertFalse(settings.postureCheck.asymmetry)
    }
}

final class SnapshotModelTests: XCTestCase {
    func testReviewAndRecheckState() {
        var s = Snapshot(at: t0, reason: .random, photos: [SnapshotPhoto(slot: "now", at: t0)])
        XCTAssertTrue(s.needsReview(at: t0))
        XCTAssertFalse(s.isAnswered)
        s.labeledAt = t0
        s.observed = []
        XCTAssertTrue(s.isAnswered, "'해당 없음'도 답이다")
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

    func testIssueEncoding() {
        XCTAssertNil(Snapshot.encode(nil))
        XCTAssertEqual(Snapshot.encode([]), "")
        XCTAssertEqual(Snapshot.encode([.sideLean, .forwardHead]), "forwardHead,sideLean")
        XCTAssertEqual(Snapshot.decode(""), [])
        XCTAssertEqual(Snapshot.decode("forwardHead,sideLean"), [.forwardHead, .sideLean])
        XCTAssertNil(Snapshot.decode(nil))
    }

    func testFactsShowWhatTheAppSaw() {
        var state: [String: Double] = [SnapshotKey.sittingMinutes: 35.2, SnapshotKey.stillMinutes: 21]
        state.merge(PostureReading(shoulderTilt: 0.2, headTilt: 0.1, sideLean: 0.01, headForward: 0.14, neckDrop: 0).detail) { $1 }
        state[SnapshotKey.issue(.forwardHead)] = 1
        let s = Snapshot(at: t0, reason: .event, rule: .forwardHead, variant: "forwardHead", photos: [], state: state)
        XCTAssertEqual(s.flagged, [.forwardHead])
        let facts = SnapshotCopy.facts(s)
        XCTAssertEqual(facts.first, "앉은 지 35분")
        XCTAssertTrue(facts.contains("거북목: 머리가 기준보다 앞으로 14% → 앱 판정: 바르지 않음"), "\(facts)")
        XCTAssertTrue(facts.contains("어깨 수평: 어깨 수평"), "\(facts)")
        XCTAssertEqual(SnapshotCopy.eventLine(s), "'거북목' 알림이 울린 순간이에요")
        let still = Snapshot(at: t0, reason: .event, rule: .stillness, variant: "20분", photos: [])
        XCTAssertEqual(SnapshotCopy.eventLine(still), "'오래 같은 자세 (20분)' 알림이 울린 순간이에요")
        let photo = SnapshotPhoto(slot: "m10", at: t0.addingTimeInterval(-600))
        XCTAssertEqual(SnapshotCopy.slotTitle(photo, snapshotAt: t0), "10분 전")
    }

    func testRecheckAgreement() {
        func pair(_ a: SnapshotActivity, _ b: SnapshotActivity, _ o1: Set<PostureIssue>, _ o2: Set<PostureIssue>) -> Snapshot {
            Snapshot(at: t0, reason: .random, photos: [], activity: a, observed: o1, labeledAt: t0,
                     recheckActivity: b, recheckObserved: o2, recheckAt: t0)
        }
        let r = SnapshotAgreement.recheck([pair(.screen, .screen, [], []), pair(.sink, .lookDown, [.forwardHead], []),
                                           Snapshot(at: t0, reason: .random, photos: [])])
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r.activity, 0.5)
        XCTAssertEqual(r.observed, 0.5)
        XCTAssertNil(r.wanted)
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
        let s = Snapshot(at: t0, reason: .event, rule: .forwardHead, variant: "forwardHead",
                         photos: [SnapshotPhoto(slot: "ref", at: t0.addingTimeInterval(-1800)), SnapshotPhoto(slot: "now", at: t0)],
                         state: [SnapshotKey.headForward: 0.14, SnapshotKey.issue(.forwardHead): 1, SnapshotKey.sittingMinutes: 31],
                         settingsVersion: 9)
        let id = try store.insert(s)
        var loaded = try XCTUnwrap(try store.snapshots(since: t0.addingTimeInterval(-60)).first)
        XCTAssertEqual(loaded.id, id)
        loaded.id = nil
        XCTAssertEqual(loaded, s)

        try store.updateSnapshotLabel(id: id, activity: .lookDown, observed: [.forwardHead, .headTilt], wanted: .no, match: .wrong,
                                      labeledAt: t0.addingTimeInterval(600), recheckDue: t0.addingTimeInterval(2 * 86_400))
        try store.updateSnapshotRecheck(id: id, activity: .lookDown, observed: [], wanted: .yes, at: t0.addingTimeInterval(3 * 86_400))
        loaded = try XCTUnwrap(try store.snapshotsWithPhotos().first)
        XCTAssertEqual(loaded.activity, .lookDown)
        XCTAssertEqual(loaded.observed, [.forwardHead, .headTilt])
        XCTAssertEqual(loaded.recheckObserved, [], "'해당 없음'은 빈 집합으로 남는다")
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
