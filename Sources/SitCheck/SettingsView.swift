import AppKit
import SwiftUI
import SitCheckCore

/// 설정: 임계값, 추가 세트, 제외 동작, 데이터 내보내기와 삭제
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
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
                Toggle("카메라 사용", isOn: $model.settings.cameraEnabled)
                if model.settings.cameraEnabled {
                    if model.cameraStatus == .running {
                        CameraPreview(session: model.camera.session)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    LabeledContent("상태") {
                        Text(model.cameraStatusText).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        if model.cameraStatus != .running && model.cameraStatus != .starting {
                            Button("카메라 다시 시도") { model.retryCamera() }
                        }
                        Button("카메라 다시 고르기") { model.resetCameraChoice() }
                        Spacer()
                        Button("실험·측정 열기") {
                            NSApp.activate(ignoringOtherApps: true)
                            openWindow(id: "experiments")
                        }
                    }
                    Picker("카메라 알림", selection: $model.settings.postureAlertMode) {
                        ForEach(PostureAlertMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    Stepper("오래 같은 자세(R5): \(model.settings.signals.stillMinutes)분",
                            value: $model.settings.signals.stillMinutes, in: 10...90, step: 5)
                    Stepper("점점 아래로·가까이(R6) 이어진 시간: \(model.settings.signals.driftHoldMinutes)분",
                            value: $model.settings.signals.driftHoldMinutes, in: 2...30)
                    Stepper(String(format: "R6 기준: 개인 흔들림의 %.1f배", model.settings.signals.driftK),
                            value: $model.settings.signals.driftK, in: 1.5...8, step: 0.5)
                    Stepper("카메라 카드 하루 최대: \(model.settings.postureCardsPerDay)장",
                            value: $model.settings.postureCardsPerDay, in: 1...10)
                    Stepper("같은 카드 다시 띄우는 간격: \(model.settings.postureRepeatMinutes)분부터",
                            value: $model.settings.postureRepeatMinutes, in: 10...120, step: 10)
                    Stepper("하루 확인 질문: \(model.settings.checkInsPerDay)번",
                            value: $model.settings.checkInsPerDay, in: 0...4)
                }
            } header: {
                Text("카메라")
            } footer: {
                Text("영상은 저장하거나 전송하지 않아요. 1초에 한 장씩 얼굴 위치·크기·각도만 이 Mac에서 계산하고, 1분 단위 요약 수치만 남겨요. '바른 자세'를 판정하거나 좌우를 비교하지 않고, 같은 자세가 오래 이어지거나 앉은 직후보다 아래로·가까이 옮겨 간 것만 봐요. 얼굴이 보이면 입력이 없어도 앉아 있는 것으로 봐요.")
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
