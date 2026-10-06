import Foundation
import SitCheckCore

// 자세 코치 기록 분석 도구. 앱과 같은 판정 코드(SitCheckCore)로 실험 결과를 계산한다.
// 사용법은 `sitcheck-analyze help`.

let usage = """
사용법: sitcheck-analyze [명령] [옵션]

명령
  report     전체 요약과 다음 할 일 (기본)
  days       날짜별 기록량과 '울렸을 알림' 수 (실험 5)
  cost       분석 구성별 CPU·분석 시간 (실험 1)
  noise      가만히 있을 때 흔들림과 현재 임계값의 배수 (실험 3)
  protocol   의도한 동작 구분 결과 (실험 4)
  replay     기록 재생으로 판정값 고르기 (실험 5)
  feedback   카메라 카드 정확도와 무작위 확인 질문 (실험 7)
  outcomes   알림 뒤 10분 안에 실제로 일어났는지, 카드와 아이콘 비교 (실험 8)
  probes     3D 몸 자세·AirPods 확인 기록 (실험 1·2)
  export     전체 기록을 CSV로 내보내기 (예: export ~/Desktop/sitcheck-csv)
  help       이 도움말

옵션
  --db PATH            데이터베이스 경로 (기본: ~/Library/Application Support/SitCheck/sitcheck.sqlite)
  --days N             최근 N일만 본다 (기본 28)
  replay 전용
  --still 20,30,45     '오래 같은 자세' 분 후보
  --drift-k 2,3,4      '점점 아래로·가까이' 기준 (개인 흔들림의 배수) 후보
  --drift-hold 3,5,8   '점점 아래로·가까이' 이어진 분 후보
  --shift-k 3,4,5      자세를 바꿨다고 보는 이동 (개인 흔들림의 배수) 후보
  --range-k 6          1분 안 움직임 폭 (개인 흔들림의 배수) 후보
  --split N            앞의 N일로 고르고 나머지 날로 확인 (예: --split 7)
"""

// MARK: - 인자

struct Options {
    var command = "report"
    var dbPath = Store.defaultURL().path
    var days = 28
    var still: [Int]?
    var driftK: [Double]?
    var driftHold: [Int]?
    var shiftK: [Double]?
    var rangeK: [Double]?
    var split: Int?
    var positional: [String] = []
}

func parseOptions(_ args: [String]) -> Options {
    var o = Options()
    var i = 0
    func next() -> String? {
        i += 1
        return i < args.count ? args[i] : nil
    }
    func ints(_ s: String?) -> [Int]? { s.map { $0.split(separator: ",").compactMap { Int($0) } } }
    func doubles(_ s: String?) -> [Double]? { s.map { $0.split(separator: ",").compactMap { Double($0) } } }
    var commandSet = false
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--db": if let v = next() { o.dbPath = (v as NSString).expandingTildeInPath }
        case "--days": if let v = next(), let n = Int(v) { o.days = n }
        case "--still": o.still = ints(next())
        case "--drift-k": o.driftK = doubles(next())
        case "--drift-hold": o.driftHold = ints(next())
        case "--shift-k": o.shiftK = doubles(next())
        case "--range-k": o.rangeK = doubles(next())
        case "--split": if let v = next(), let n = Int(v) { o.split = n }
        case "-h", "--help": o.command = "help"; commandSet = true
        default:
            if !commandSet && !arg.hasPrefix("-") {
                o.command = arg
                commandSet = true
            } else {
                o.positional.append(arg)
            }
        }
        i += 1
    }
    return o
}

// MARK: - 출력 도우미

/// 터미널 표시 폭 (한글·한자는 2칸)
func displayWidth(_ s: String) -> Int {
    s.unicodeScalars.reduce(0) { width, scalar in
        let v = scalar.value
        let wide = (0x1100...0x115F).contains(v) || (0x2E80...0xA4CF).contains(v) || (0xAC00...0xD7A3).contains(v)
            || (0xF900...0xFAFF).contains(v) || (0xFE30...0xFE4F).contains(v) || (0xFF00...0xFF60).contains(v)
        return width + (wide ? 2 : 1)
    }
}

func pad(_ s: String, _ width: Int, right: Bool = false) -> String {
    let fill = String(repeating: " ", count: max(0, width - displayWidth(s)))
    return right ? fill + s : s + fill
}

func table(_ header: [String], _ rows: [[String]]) {
    var widths = header.map(displayWidth)
    for row in rows {
        for (i, cell) in row.enumerated() where i < widths.count {
            widths[i] = max(widths[i], displayWidth(cell))
        }
    }
    func line(_ cells: [String]) -> String {
        cells.enumerated().map { i, c in pad(c, widths[i], right: i > 0) }.joined(separator: "  ")
    }
    print(line(header))
    print(widths.map { String(repeating: "-", count: $0) }.joined(separator: "  "))
    rows.forEach { print(line($0)) }
}

func title(_ s: String) {
    print("\n\u{1B}[1m■ \(s)\u{1B}[0m")
}

func f(_ v: Double?, _ digits: Int = 1) -> String {
    v.map { String(format: "%.\(digits)f", $0) } ?? "-"
}

func pct(_ v: Double?) -> String {
    v.map { "\(Int(($0 * 100).rounded()))%" } ?? "-"
}

let dayFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd (E)"
    fmt.locale = Locale(identifier: "ko_KR")
    return fmt
}()

let timeFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "MM-dd HH:mm"
    return fmt
}()

// MARK: - 데이터

struct Dataset {
    let settings: AppSettings
    let minutes: [PostureMinute]
    let events: [PostureEventRecord]
    let nudges: [NudgeRecord]
    let bouts: [SitBout]
    let checkIns: [CheckInRecord]
    let stillMinutes: [PostureMinute]
    let since: Date
}

func load(_ store: Store, days: Int) throws -> Dataset {
    let since = Date().addingTimeInterval(-Double(days) * 86_400)
    return Dataset(settings: try store.loadSettings(),
                 minutes: try store.postureMinutes(since: since),
                 events: try store.postureEvents(since: since),
                 nudges: try store.nudges(since: since),
                 bouts: try store.bouts(since: since),
                 checkIns: try store.checkIns(since: since),
                 stillMinutes: try store.postureMinutes(label: ExperimentLabel.still.rawValue),
                 since: since)
}

func noiseModel(_ d: Dataset) -> NoiseModel {
    if let n = NoiseModel.estimate(from: d.stillMinutes, source: "가만히 측정 (\(d.stillMinutes.count)분)") { return n }
    let recent = d.minutes.filter { m in d.settings.baselineResetAt.map { m.start >= $0 } ?? true }
    if let b = AutoBaseline.build(from: recent, params: d.settings.signals), b.isReady { return b.noise }
    return .defaults
}

/// 재생·날짜 통계에 쓸 날: 앉아 있던 분이 60분 이상인 날
func usableDays(_ d: Dataset) -> [Date] {
    Analysis.days(minutes: d.minutes, events: d.events, params: d.settings.signals)
        .filter { $0.sittingMinutes >= 60 }
        .map(\.day)
}

let cameraRules: [NudgeRule] = [.stillness, .drift, .near]

// MARK: - 명령

func showDays(_ d: Dataset) {
    title("날짜별 기록과 '울렸을 알림' (실험 5)")
    let days = Analysis.days(minutes: d.minutes, events: d.events, params: d.settings.signals)
    guard !days.isEmpty else {
        print("아직 카메라 기록이 없어요. 앱에서 카메라를 켜 두면 1분마다 쌓여요.")
        return
    }
    table(["날짜", "기록(분)", "앉음(분)", "얼굴 잡힘", "R5", "R6", "R7", "R2(예전)", "R3(예전)", "R5 20/30/45분"],
          days.map { day in
              [dayFormatter.string(from: day.day), "\(day.minutes)", "\(day.sittingMinutes)", pct(day.faceCoverage),
               "\(day.events[.stillness] ?? 0)", "\(day.events[.drift] ?? 0)", "\(day.events[.near] ?? 0)",
               "\(day.events[.tiltRotation] ?? 0)", "\(day.events[.screenApproach] ?? 0)",
               ["20분", "30분", "45분"].map { "\(day.stillVariants[$0] ?? 0)" }.joined(separator: "/")]
          })
    print("기준: 앉아 있을 때 얼굴이 잡힌 분 90% 이상, 유형별 하루 중앙값 2회 이하·가장 많은 날 3회 이하.")
    print("R5–R7은 지금 설정 기준 카드 후보 수, R2·R3은 예전 규칙이었다면 울렸을 수예요.")
}

func showCost(_ d: Dataset) {
    title("분석 구성별 비용 (실험 1)")
    let rows = Analysis.cost(d.minutes)
    guard !rows.isEmpty else {
        print("아직 비용 기록이 없어요. 앱의 실험·측정 창에서 분석 구성을 바꿔 가며 10분씩 켜 두세요.")
        return
    }
    table(["분석 구성", "프레임 상한", "기록(분)", "CPU 평균", "CPU 중앙값", "분석 시간"],
          rows.map { r in
              [r.mode.label, r.frameCap.map { $0 ? "켬" : "끔" } ?? "-", "\(r.minutes)",
               r.cpuMean.map { String(format: "%.1f%%", $0) } ?? "-",
               r.cpuMedian.map { String(format: "%.1f%%", $0) } ?? "-",
               r.analysisMsMean.map { String(format: "%.0f ms", $0) } ?? "-"]
          })
    print("CPU는 앱 전체, 코어 1개 = 100% 기준이에요. 예산(예: 3%) 안인 구성만 실험 3·4에 써요.")
}

func showNoise(_ d: Dataset) {
    title("가만히 있을 때 흔들림 (실험 3)")
    let noise = noiseModel(d)
    print("쓰는 값: \(noise.source)")
    if d.stillMinutes.isEmpty {
        print("아직 '가만히 5분' 측정이 없어요. 실험·측정 창에서 날짜와 조명을 바꿔 3번 해 주세요.")
    } else {
        let days = Set(d.stillMinutes.map { Calendar.current.startOfDay(for: $0.start) }).count
        print("'가만히' 기록: \(d.stillMinutes.count)분, \(days)일")
    }
    table(["특징", "흔들림(σ)", "단위"], [
        ["얼굴 위치 x", f(noise.faceX * 100, 2), "프레임 폭의 %"],
        ["얼굴 위치 y", f(noise.faceY * 100, 2), "프레임 높이의 %"],
        ["얼굴 크기", f(noise.widthRel * 100, 2), "%"],
        ["roll", f(noise.roll, 2), "도"],
        ["yaw", f(noise.yaw, 2), "도"],
        ["pitch", f(noise.pitch, 2), "도"],
    ])
    let s = d.settings
    print("\n현재 임계값을 흔들림의 배수로 (잡으려는 변화는 흔들림의 3배 이상이어야 해요)")
    table(["임계값", "값", "흔들림의 배수"], [
        ["예전 R2 기울기", "\(s.tiltThresholdDegrees)°", f(Double(s.tiltThresholdDegrees) / noise.roll)],
        ["예전 R2 회전", "\(Double(s.tiltThresholdDegrees) * 1.5)°", f(Double(s.tiltThresholdDegrees) * 1.5 / noise.yaw)],
        ["예전 R3 얼굴 크기", "+\(s.approachThresholdPercent)%", f(Double(s.approachThresholdPercent) / 100 / noise.widthRel)],
        ["R6 아래로", f(s.signals.driftK * noise.faceY * 100, 2) + "% (높이)", f(s.signals.driftK)],
        ["R6 가까이", "+" + f(s.signals.driftK * noise.widthRel * 100, 1) + "% (크기)", f(s.signals.driftK)],
        ["자세 변화(이동)", f(s.signals.shiftK * noise.faceY * 100, 2) + "% (높이)", f(s.signals.shiftK)],
    ])
}

func showProtocol(_ d: Dataset) {
    title("의도한 동작 구분 (실험 4)")
    let noise = noiseModel(d)
    let k = d.settings.signals.driftK
    let results = Analysis.separation(d.minutes, noise: noise, k: k)
    guard !results.isEmpty else {
        print("아직 실험 4 기록이 없어요. 실험·측정 창에서 '의도한 동작 실험'을 서로 다른 날 2–3번 해 주세요.")
        return
    }
    table(["동작", "분", "아래로(σ)", "가까이(σ)", "\(f(k))σ 넘은 분", "기대", "결과", "pitch차", "코–어깨 비율차"],
          results.map { r in
              let expected: String
              switch r.label.shouldTrigger {
              case true?: expected = "잡혀야 함"
              case false?: expected = "안 잡혀야 함"
              case nil: expected = "-"
              }
              let verdict = r.passes.map { $0 ? "통과" : "실패" } ?? "-"
              return [r.label.title, "\(r.minutes)", f(r.lowerSigma), f(r.closerSigma), pct(r.triggerRatio),
                      expected, verdict, f(r.pitchDelta), f(r.neckRatioDelta, 3)]
          })
    print("기준: 가라앉기·다가가기는 80% 이상, 내려다보기·옆 화면·옆으로 기대기는 10% 이하.")
    print("가라앉기와 내려다보기가 안 갈리면 pitch·코–어깨 비율(얼굴 + 2D 몸 자세 구성)을 더해 다시 해 보세요.")
}

func combos(_ o: Options, base: SignalParameters) -> [SignalParameters] {
    var out: [SignalParameters] = []
    for still in o.still ?? [base.stillMinutes] {
        for driftK in o.driftK ?? [base.driftK] {
            for hold in o.driftHold ?? [base.driftHoldMinutes] {
                for shiftK in o.shiftK ?? [base.shiftK] {
                    for rangeK in o.rangeK ?? [base.rangeK] {
                        var p = base
                        p.stillMinutes = still
                        p.driftK = driftK
                        p.driftHoldMinutes = hold
                        p.shiftK = shiftK
                        p.rangeK = rangeK
                        out.append(p)
                    }
                }
            }
        }
    }
    return out
}

func showReplay(_ d: Dataset, _ o: Options) {
    title("기록 재생 (실험 5)")
    let days = usableDays(d)
    guard !days.isEmpty else {
        print("앉아 있던 시간이 60분 넘는 날의 카메라 기록이 아직 없어요.")
        return
    }
    let noise = noiseModel(d)
    let trainDays: [Date]
    let testDays: [Date]
    if let split = o.split, split < days.count {
        trainDays = Array(days.prefix(split))
        testDays = Array(days.dropFirst(split))
        print("앞 \(trainDays.count)일로 고르고 뒤 \(testDays.count)일로 확인해요. 흔들림 값: \(noise.source)")
    } else {
        trainDays = days
        testDays = []
        print("\(days.count)일 전체로 봐요 (--split N으로 나눠 확인할 수 있어요). 흔들림 값: \(noise.source)")
    }
    struct Row { var params: SignalParameters; var train: [Analysis.RuleDayStats]; var test: [Analysis.RuleDayStats] }
    let rows: [Row] = combos(o, base: d.settings.signals).map { params in
        let counts = Analysis.replay(d.minutes, params: params, noise: noise, distance: d.settings.distanceCalibration)
        return Row(params: params,
                   train: Analysis.dayStats(counts, days: trainDays, rules: cameraRules),
                   test: testDays.isEmpty ? [] : Analysis.dayStats(counts, days: testDays, rules: cameraRules))
    }
    func cell(_ stats: [Analysis.RuleDayStats], _ rule: NudgeRule) -> String {
        guard let s = stats.first(where: { $0.rule == rule }) else { return "-" }
        return "\(f(s.median))/\(s.max)\(s.passes ? "" : "✗")"
    }
    var header = ["정지(분)", "R6 k", "R6 지속", "이동 k", "폭 k"]
    header += cameraRules.map { "\($0.rawValue) 고름" }
    if !testDays.isEmpty { header += cameraRules.map { "\($0.rawValue) 확인" } }
    let sorted = rows.sorted { a, b in
        let sa = (testDays.isEmpty ? a.train : a.test)
        let sb = (testDays.isEmpty ? b.train : b.test)
        let pa = sa.filter(\.passes).count, pb = sb.filter(\.passes).count
        if pa != pb { return pa > pb }
        return sa.reduce(0) { $0 + $1.total } > sb.reduce(0) { $0 + $1.total }
    }
    table(header, sorted.map { r in
        var row = ["\(r.params.stillMinutes)", f(r.params.driftK), "\(r.params.driftHoldMinutes)", f(r.params.shiftK), f(r.params.rangeK)]
        row += cameraRules.map { cell(r.train, $0) }
        if !testDays.isEmpty { row += cameraRules.map { cell(r.test, $0) } }
        return row
    })
    print("칸: 하루 중앙값/가장 많은 날 (✗ = 중앙값 2회 이하·최대 3회 이하 기준 미달). 위쪽일수록 기준을 더 많이 통과해요.")
    print("R7(가까움)은 거리 보정을 한 경우에만 세요.")
}

func showFeedback(_ d: Dataset) {
    title("카메라 카드 정확도 (실험 7)")
    let rows = Analysis.feedback(d.nudges)
    if rows.isEmpty {
        print("아직 카메라 카드가 없어요 (측정 기간에는 '기록만' 상태라 정상이에요).")
    } else {
        table(["유형", "카드", "맞아요", "아니에요", "자리 바뀜", "무응답", "정확도"],
              rows.map { r in
                  [r.rule.title, "\(r.cards)", "\(r.right)", "\(r.wrong)", "\(r.setupChanged)", "\(r.unanswered)", pct(r.precision)]
              })
        print("기준: 유형별 정확도 0.8 이상, 잘못 뜬 자세 카드 하루 1장 이하. 2주 연속 0.7 미만이면 그 카드는 없애요.")
    }
    let summary = Analysis.checkIns(d.checkIns, stillMinutes: d.settings.signals.stillMinutes)
    print("\n무작위 확인 질문: \(summary.total)번 (네 \(summary.answers[.yes] ?? 0) · 아니요 \(summary.answers[.no] ?? 0) · 모름 \(summary.answers[.unsure] ?? 0) · 닫음 \(summary.answers[.dismissed] ?? 0))")
    if summary.yesDetected + summary.yesMissed + summary.noDetected + summary.noClear > 0 {
        table(["사용자 답", "감지기도 정지", "감지기는 아님"], [
            ["거의 안 바꿈(네)", "\(summary.yesDetected)", "\(summary.yesMissed)  ← 놓침"],
            ["바꿈(아니요)", "\(summary.noDetected)  ← 잘못 잡음", "\(summary.noClear)"],
        ])
    }
}

func showOutcomes(_ d: Dataset) {
    title("알림 뒤 10분 안에 실제로 일어났는지 (R1, 실험 8)")
    let rows = Analysis.outcomes(nudges: d.nudges, bouts: d.bouts, minutes: d.minutes, params: d.settings.signals)
    guard !rows.isEmpty else {
        print("아직 알림 기록이 없어요.")
        return
    }
    table(["유형", "전달", "횟수", "일어남", "비율"],
          rows.map { [$0.rule.title, $0.delivery, "\($0.count)", "\($0.stoodUp)", pct($0.rate)] })
    print("'완료'를 눌러 타이머를 다시 시작한 것은 일어난 것으로 세지 않아요 (자리 비움·잠금·카메라에서 얼굴이 사라진 분만).")
    print("실험 8 기준: 카드 쪽이 아이콘 쪽보다 10%p 이상 높은 상태가 4주 이어지면 카드를 유지해요.")
}

func showProbes(_ dbPath: String) {
    title("3D 몸 자세·AirPods 확인 기록 (실험 1·2)")
    let url = URL(fileURLWithPath: dbPath).deletingLastPathComponent().appendingPathComponent("probes.log")
    guard let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty else {
        print("아직 없어요. 실험·측정 창의 '3D 몸 자세 동작 확인', 'AirPods 동작 데이터 확인'을 눌러 주세요.")
        return
    }
    text.split(separator: "\n").suffix(10).forEach { print($0) }
}

func showReport(_ d: Dataset, _ o: Options) {
    title("요약")
    let s = d.settings
    print("데이터: \(o.dbPath)")
    if let first = d.minutes.first, let last = d.minutes.last {
        print("카메라 기록: \(timeFormatter.string(from: first.start)) ~ \(timeFormatter.string(from: last.end)), \(d.minutes.count)분 (최근 \(o.days)일)")
    } else {
        print("카메라 기록: 없음 (최근 \(o.days)일)")
    }
    if let started = s.measurementStartedAt {
        let days = Int(Date().timeIntervalSince(started) / 86_400) + 1
        print("측정 시작: \(dayFormatter.string(from: started)), \(days)일째")
    }
    print("카메라 알림: \(s.postureAlertMode.label) · 분석 구성: \(s.analysisMode.label) · 프레임 상한: \(s.capFrameRate ? "켬" : "끔")")
    print("판정값: 정지 \(s.signals.stillMinutes)분 · R6 \(f(s.signals.driftK))σ \(s.signals.driftHoldMinutes)분 · 이동 \(f(s.signals.shiftK))σ · 폭 \(f(s.signals.rangeK))σ")
    print("거리 보정: \(s.distanceCalibration.map { "있음 (\(dayFormatter.string(from: $0.calibratedAt)))" } ?? "없음")")

    showDays(d)
    showReplay(d, o)
    showCost(d)
    showNoise(d)
    showProtocol(d)
    showFeedback(d)
    showOutcomes(d)
    showProbes(o.dbPath)

    title("다음 할 일")
    var todo: [String] = []
    if !d.minutes.contains(where: { $0.cpuPercent != nil }) { todo.append("실험 1: 분석 구성별로 10분씩 켜 두고 'cost'로 CPU 확인") }
    if (try? String(contentsOf: URL(fileURLWithPath: o.dbPath).deletingLastPathComponent().appendingPathComponent("probes.log"), encoding: .utf8)) == nil {
        todo.append("실험 1·2: 실험·측정 창에서 3D 몸 자세, AirPods 확인 버튼 누르기")
    }
    let stillDays = Set(d.stillMinutes.map { Calendar.current.startOfDay(for: $0.start) }).count
    if stillDays < 3 { todo.append("실험 3: '가만히 5분'을 다른 날·조명으로 \(3 - stillDays)번 더") }
    let protocolDays = Set(d.minutes.filter { $0.label != nil && $0.label != ExperimentLabel.still.rawValue }
        .map { Calendar.current.startOfDay(for: $0.start) }).count
    if protocolDays < 2 { todo.append("실험 4: '의도한 동작 실험'을 다른 날 \(2 - protocolDays)번 더") }
    if s.distanceCalibration == nil { todo.append("실험 6: 줄자로 60 cm에서 거리 보정") }
    let measuredDays = usableDays(d).count
    if measuredDays < 14 { todo.append("실험 5: '기록만' 상태로 \(14 - measuredDays)일 더 쓰기 (앉은 시간 60분 넘는 날 기준)") }
    else if s.postureAlertMode == .shadow { todo.append("실험 5 끝: 'replay --split 7'로 기준을 통과한 신호만 '카드로 알림'으로 바꾸기") }
    if todo.isEmpty { todo.append("실험 7·8 진행 중: 'feedback', 'outcomes'로 정확도와 효과 확인") }
    todo.forEach { print("• \($0)") }
}

// MARK: - 실행

let options = parseOptions(Array(CommandLine.arguments.dropFirst()))
if options.command == "help" {
    print(usage)
    exit(0)
}
guard FileManager.default.fileExists(atPath: options.dbPath) else {
    print("데이터베이스가 없어요: \(options.dbPath)")
    print("앱(build/SitCheck.app)을 한 번 실행하면 만들어져요. 다른 경로는 --db로 지정하세요.")
    exit(1)
}

do {
    let store = try Store(path: options.dbPath)
    if options.command == "export" {
        let target = options.positional.first.map { ($0 as NSString).expandingTildeInPath }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/sitcheck-csv").path
        let files = try store.exportCSV(to: URL(fileURLWithPath: target, isDirectory: true))
        print("내보냈어요: \(target)")
        files.forEach { print("  \($0.lastPathComponent)") }
        exit(0)
    }
    let data = try load(store, days: options.days)
    switch options.command {
    case "report": showReport(data, options)
    case "days": showDays(data)
    case "cost": showCost(data)
    case "noise": showNoise(data)
    case "protocol": showProtocol(data)
    case "replay": showReplay(data, options)
    case "feedback": showFeedback(data)
    case "outcomes": showOutcomes(data)
    case "probes": showProbes(options.dbPath)
    default:
        print("알 수 없는 명령: \(options.command)\n")
        print(usage)
        exit(1)
    }
} catch {
    print("오류: \(error)")
    exit(1)
}
