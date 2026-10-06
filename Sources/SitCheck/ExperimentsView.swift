import SwiftUI
import SitCheckCore

/// 확정 전에 이 Mac에서 돌리는 실험들 (docs/experiments.md). 결과는 터미널의 `build/sitcheck-analyze`로 본다.
struct ExperimentsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            measurementSection
            if let session = model.experiment {
                runningSection(session)
            }
            costSection
            airPodsSection
            noiseSection
            protocolSection
            distanceSection
            usualPostureSection
            alertSection
            Section("터미널에서 결과 보기") {
                Text("cd ~/Desktop/sit-check && build/sitcheck-analyze report")
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 760)
        .onAppear {
            model.experimentsWindowOpen = true
            model.refreshMeasurement()
        }
        .onDisappear { model.experimentsWindowOpen = false }
    }

    // MARK: - 측정 상태

    private var measurementSection: some View {
        Section {
            LabeledContent("카메라") { Text(model.cameraStatusText).multilineTextAlignment(.trailing) }
            if let info = model.cameraInfo {
                LabeledContent("고정한 카메라") {
                    Text("\(info.name)\(info.frameRate.map { String(format: " · %.0f fps", $0) } ?? "")")
                }
            }
            LabeledContent("카메라 알림") { Text(model.settings.postureAlertMode.label) }
            if let started = model.measurement.startedAt {
                let days = Int(Date().timeIntervalSince(started) / 86_400) + 1
                LabeledContent("측정 시작") { Text("\(started.formatted(date: .abbreviated, time: .omitted)) · \(days)일째") }
            }
            LabeledContent("오늘 기록") {
                Text("\(model.measurement.todayMinutes)분 (앉아 있던 \(model.measurement.todaySittingMinutes)분)")
            }
            if let coverage = model.measurement.todayFaceCoverage {
                LabeledContent("앉아 있을 때 얼굴이 잡힌 분") { Text(percent(coverage)) }
            }
            LabeledContent("오늘 '울렸을 알림'") { Text(eventsText) }
            LabeledContent("통화 감지") { Text(model.inCall ? "통화 중으로 봄 (카드 미룸)" : "아니요") }
        } header: {
            Text("측정 상태")
        } footer: {
            Text("측정 기간(1–2주)에는 카메라 카드를 띄우지 않고 '울렸을 알림'만 기록해요. 40분 착석 카드는 그대로 떠요.")
        }
    }

    private var eventsText: String {
        let rules: [NudgeRule] = [.stillness, .drift, .near, .tiltRotation, .screenApproach]
        let parts = rules.compactMap { rule -> String? in
            guard let n = model.measurement.todayEvents[rule], n > 0 else { return nil }
            return "\(rule.rawValue) \(n)"
        }
        return parts.isEmpty ? "없음" : parts.joined(separator: " · ")
    }

    // MARK: - 진행 중인 실험

    private func runningSection(_ session: GuidedSession) -> some View {
        Section(session.title) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(session.index + 1)/\(session.steps.count) · \(session.current.title)")
                    .font(.title3.bold())
                Text(session.current.instruction)
                    .fixedSize(horizontal: false, vertical: true)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(session.stepEndsAt.timeIntervalSince(context.date)))
                    Text(String(format: "%d:%02d 남음", remaining / 60, remaining % 60))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                if session.index + 1 < session.steps.count {
                    Text("다음: \(session.steps[session.index + 1].title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("실험 멈추기", role: .destructive) { model.stopExperiment() }
            }
        }
    }

    // MARK: - 실험 1

    private var costSection: some View {
        Section {
            Picker("분석 구성", selection: $model.settings.analysisMode) {
                ForEach(AnalysisMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            Toggle("카메라 프레임 속도를 최저로 묶기", isOn: $model.settings.capFrameRate)
            if let minute = model.lastMinute {
                LabeledContent("직전 1분") {
                    Text("CPU \(minute.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "-") · 분석 \(minute.analysisMs.map { String(format: "%.0f ms", $0) } ?? "-")")
                        .monospacedDigit()
                }
            }
            HStack {
                Button("3D 몸 자세 동작 확인") { model.runProbe3D() }
                    .disabled(model.cameraStatus != .running)
                Spacer()
            }
            if let result = model.probe3DResult {
                Text(result).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("실험 1 · 비용과 API (반나절)")
        } footer: {
            Text("구성마다 10분 이상 켜 두고 `sitcheck-analyze cost`로 평균 CPU를 비교하세요. CPU는 코어 1개를 100%로 본 값이에요. 3D는 성공해도 알림에는 쓰지 않아요.")
        }
    }

    // MARK: - 실험 2

    private var airPodsSection: some View {
        Section {
            Button("AirPods 동작 데이터 확인 (30초)") { model.runAirPodsProbe() }
            if let result = model.airPodsResult {
                Text(result).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("실험 2 · AirPods (30분)")
        } footer: {
            Text("샘플이 끊김 없이 들어오지 않으면 AirPods 경로는 접어요. 들어와도 고개 방향만 보이고 몸통은 볼 수 없어요.")
        }
    }

    // MARK: - 실험 3

    private var noiseSection: some View {
        Section {
            Button("가만히 5분 측정 시작") { model.startExperiment(.still) }
                .disabled(model.experiment != nil || model.cameraStatus != .running)
            LabeledContent("지금 쓰는 흔들림 값") { Text(model.noise.source) }
            Text(noiseText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            LabeledContent("기록된 '가만히' 분") { Text("\(model.measurement.stillMinutesRecorded)분") }
        } header: {
            Text("실험 3 · 가만히 있을 때 흔들림 (5분 × 3회, 다른 날·조명)")
        } footer: {
            Text("평소처럼 글을 읽으며 앉아 있으면 돼요. 안경을 쓴다면 쓴 채로도 한 번 해 주세요.")
        }
    }

    private var noiseText: String {
        let n = model.noise
        return String(format: "얼굴 위치 x %.3f · y %.3f · 크기 %.1f%% · roll %.1f° · yaw %.1f° · pitch %.1f°",
                      n.faceX, n.faceY, n.widthRel * 100, n.roll, n.yaw, n.pitch)
    }

    // MARK: - 실험 4

    private var protocolSection: some View {
        Section {
            Button("의도한 동작 실험 시작 (약 18분)") { model.startExperiment(.protocolRun) }
                .disabled(model.experiment != nil || model.cameraStatus != .running)
            LabeledContent("기록된 동작 분") { Text("\(model.measurement.protocolMinutesRecorded)분") }
        } header: {
            Text("실험 4 · 의도한 동작 구분 (30분 × 2–3회, 다른 날)")
        } footer: {
            Text("자연스럽게 앉기 → (무작위 순서) 내려다보기, 휴대폰, 옆 화면, 다가가기, 가라앉기, 등받이, 옆으로 기대기 → 의자 바꾸기를 2분씩 해요. 바뀔 때 소리가 나요. 실험 중에는 카드가 뜨지 않아요.")
        }
    }

    // MARK: - 실험 6

    private var distanceSection: some View {
        Section {
            Text("줄자로 눈에서 화면까지 60 cm를 맞춰 앉고, 정면을 본 채 버튼을 누르세요 (10초).")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(model.calibration == .distance60 ? "재는 중…" : "60 cm에서 보정") { model.startCalibration(.distance60) }
                    .disabled(model.cameraStatus != .running || model.calibration != nil)
                if model.settings.distanceCalibration != nil {
                    Button("보정 지우기") { model.clearDistanceCalibration() }
                }
                Spacer()
            }
            if let calibration = model.settings.distanceCalibration {
                LabeledContent("보정") { Text(calibration.calibratedAt.formatted(date: .abbreviated, time: .shortened)) }
                if let cm = model.liveDistanceCm {
                    LabeledContent("지금 추정 거리") { Text(String(format: "약 %.0f cm", cm)).monospacedDigit() }
                }
            }
        } header: {
            Text("실험 6 · 거리 보정 (10분)")
        } footer: {
            Text("45 cm와 75 cm에도 앉아 추정 거리가 10% 안에 드는지 확인하세요. 벗어나면 cm 표시는 쓰지 않아요.")
        }
    }

    // MARK: - 평소 자세

    private var usualPostureSection: some View {
        Section {
            HStack {
                Button(model.calibration == .usualPosture ? "재는 중…" : "평소 자세 저장 (10초)") { model.startCalibration(.usualPosture) }
                    .disabled(model.cameraStatus != .running || model.calibration != nil)
                Spacer()
                if let saved = model.settings.postureBaseline?.savedAt {
                    Text("저장: \(saved.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let auto = model.autoBaseline {
                LabeledContent("자동 기준") {
                    Text(auto.isReady ? "준비됨 (\(auto.days)일, \(auto.minutes)분)"
                                      : "모으는 중 (\(auto.days)/\(AutoBaseline.requiredDays)일, \(auto.minutes)분)")
                }
                if auto.isReady, let saved = model.settings.postureBaseline,
                   let x = saved.faceX, let y = saved.faceY {
                    let diff = auto.difference(faceX: x, faceY: y, faceWidth: saved.faceWidth)
                    LabeledContent("저장한 평소 자세와 차이") {
                        Text(String(format: "%.1f배", diff) + (diff >= 2 ? " (자동 기준을 써요)" : ""))
                    }
                }
            } else {
                LabeledContent("자동 기준") { Text("아직 없음 (앉은 직후 2–15분 기록이 3일 이상 필요)") }
            }
        } header: {
            Text("평소 자세")
        } footer: {
            Text("'바른 자세'가 아니라 평소 자세예요. 이 자세로 되돌리라고 알리지 않고, 자리가 바뀌었는지 확인하는 데만 써요.")
        }
    }

    // MARK: - 알림 방식

    private var alertSection: some View {
        Section {
            Picker("카메라 알림", selection: $model.settings.postureAlertMode) {
                ForEach(PostureAlertMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            Picker("카드 대신 아이콘만 (실험 8)", selection: $model.settings.iconOnlyPercent) {
                Text("0%").tag(0)
                Text("30%").tag(30)
                Text("50%").tag(50)
            }
        } header: {
            Text("알림 방식 (실험 7·8)")
        } footer: {
            Text("측정 기간(1–2주)이 끝나고 기준을 통과한 신호만 '카드로 알림'으로 바꾸세요. 아이콘만 보여 주는 비율은 6주차쯤 카드 효과를 비교할 때 켜요.")
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
