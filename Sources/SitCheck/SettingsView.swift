import SwiftUI
import SitCheckCore

/// 설정: 임계값, 추가 세트, 제외 동작, 데이터 내보내기와 삭제
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section("알림") {
                Stepper("연속 착석 알림: \(model.settings.sitAlertMinutes)분",
                        value: $model.settings.sitAlertMinutes, in: 10...120, step: 5)
                Stepper("자리 비움 판정: 입력 없음 \(model.settings.awayAfterMinutes)분",
                        value: $model.settings.awayAfterMinutes, in: 1...15)
                Stepper("미루기: \(model.settings.snoozeMinutes)분",
                        value: $model.settings.snoozeMinutes, in: 5...30, step: 5)
                Stepper("끄기: \(model.settings.muteMinutes)분",
                        value: $model.settings.muteMinutes, in: 30...240, step: 30)
                Stepper("알림 사이 최소 간격: \(model.settings.cooldownMinutes)분",
                        value: $model.settings.cooldownMinutes, in: 0...60, step: 5)
            }

            Section {
                Toggle("카메라로 자세 감지", isOn: $model.settings.cameraEnabled)
                if model.settings.cameraEnabled {
                    if model.cameraStatus == .running {
                        CameraPreview(session: model.camera.session)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    LabeledContent("상태") {
                        Text(model.cameraStatusText).multilineTextAlignment(.trailing)
                    }
                    if let delta = model.postureDeltaText {
                        LabeledContent("기준 대비") { Text(delta).monospacedDigit() }
                    }
                    HStack {
                        Button(model.settings.postureBaseline == nil ? "지금 자세를 기준으로 저장" : "기준 자세 다시 저장") {
                            model.startCalibration()
                        }
                        .disabled(model.cameraStatus != .running || model.calibrating)
                        if model.cameraStatus != .running && model.cameraStatus != .starting {
                            Button("카메라 다시 시도") { model.retryCamera() }
                        }
                        Spacer()
                        if let saved = model.settings.postureBaseline?.savedAt {
                            Text("저장: \(saved.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper("기울기·회전 기준: \(model.settings.tiltThresholdDegrees)°",
                            value: $model.settings.tiltThresholdDegrees, in: 5...30)
                    Stepper("화면 접근 기준: 얼굴 \(model.settings.approachThresholdPercent)% 커짐",
                            value: $model.settings.approachThresholdPercent, in: 5...50, step: 5)
                    Stepper("이어진 시간: \(model.settings.postureHoldSeconds)초",
                            value: $model.settings.postureHoldSeconds, in: 30...600, step: 30)
                    Stepper("같은 자세 알림 간격: \(model.settings.postureRepeatMinutes)분",
                            value: $model.settings.postureRepeatMinutes, in: 10...120, step: 10)
                }
            } header: {
                Text("카메라 자세 감지")
            } footer: {
                Text("바르게 앉아 화면을 본 상태로 기준을 저장하세요. 영상은 저장하거나 전송하지 않고, 1초에 한 장씩 얼굴 각도와 크기만 이 Mac에서 계산해요. 얼굴이 보이면 입력이 없어도 앉아 있는 것으로 봐요.")
            }

            Section("호흡 신호 (메뉴바 아이콘만, 소리·팝업 없음)") {
                Toggle("호흡 신호 사용", isOn: $model.settings.breathEnabled)
                Stepper("간격: \(model.settings.breathIntervalMinutes)분",
                        value: $model.settings.breathIntervalMinutes, in: 10...60, step: 5)
                    .disabled(!model.settings.breathEnabled)
            }

            Section {
                ForEach(StretchLibrary.all) { stretch in
                    Toggle(isOn: Binding(
                        get: { !model.settings.excludedStretchIDs.contains(stretch.id) },
                        set: { on in
                            if on { model.settings.excludedStretchIDs.remove(stretch.id) }
                            else { model.settings.excludedStretchIDs.insert(stretch.id) }
                        }
                    )) {
                        Text("\(stretch.id) \(stretch.name)")
                        Text("\(stretch.posture.label) · \(stretch.dose.summary) · \(stretch.target)")
                    }
                }
            } header: {
                Text("처방에 쓸 동작")
            } footer: {
                Text("카드에서 통증·저림을 기록한 동작은 자동으로 꺼져요.")
            }

            Section {
                ForEach(StretchLibrary.all.filter(\.dose.isBilateral)) { stretch in
                    ExtraSetRow(stretch: stretch, extra: Binding(
                        get: { model.settings.extraSets[stretch.id] },
                        set: { model.settings.extraSets[stretch.id] = $0 }
                    ))
                }
            } header: {
                Text("한쪽 추가 세트")
            } footer: {
                Text("양쪽을 같은 시간 한 뒤 더하는 세트예요. 진단 전에는 좌우를 다르게 하는 교정을 보류하기로 했으니, 진료 후에 켜는 것을 권해요.")
            }

            Section("데이터") {
                HStack {
                    Button("CSV로 내보내기") { model.exportCSV() }
                    Spacer()
                    Button("모든 기록 삭제", role: .destructive) { confirmDelete = true }
                }
                Text("기록은 이 Mac의 ~/Library/Application Support/SitCheck에만 저장돼요. 네트워크는 쓰지 않아요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 720)
        .confirmationDialog("착석, 알림, 스트레칭 기록을 모두 지울까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) { model.deleteAllRecords() }
        } message: {
            Text("설정은 남아요. 되돌릴 수 없어요.")
        }
    }
}

private struct ExtraSetRow: View {
    let stretch: Stretch
    @Binding var extra: ExtraSet?

    var body: some View {
        HStack {
            Text("\(stretch.id) \(stretch.name)")
            Spacer()
            Picker("", selection: Binding(
                get: { extra?.side ?? .same },
                set: { side in extra = side == .same ? nil : ExtraSet(side: side, seconds: extra?.seconds ?? 30) }
            )) {
                Text("없음").tag(Side.same)
                Text("왼쪽").tag(Side.left)
                Text("오른쪽").tag(Side.right)
            }
            .labelsHidden()
            .frame(width: 90)
            Stepper("\(extra?.seconds ?? 0)초", value: Binding(
                get: { extra?.seconds ?? 0 },
                set: { if var e = extra { e.seconds = $0; extra = e } }
            ), in: 10...60, step: 10)
            .disabled(extra == nil)
        }
    }
}
