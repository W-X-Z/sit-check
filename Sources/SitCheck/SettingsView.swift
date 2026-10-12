import AppKit
import SwiftUI
import SitCheckCore

/// 설정: 알림 시간, 바른 자세 판정, 카메라, 기록 삭제
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var confirmDelete = false
    @State private var confirmDeletePhotos = false
    @State private var showPreview = false

    var body: some View {
        Form {
            Section("알림") {
                Stepper("오래 앉아 있음: \(model.settings.sitAlertMinutes)분",
                        value: $model.settings.sitAlertMinutes, in: 10...120, step: 5)
                Stepper("같은 자세: \(model.settings.signals.stillMinutes)분",
                        value: $model.settings.signals.stillMinutes, in: 10...90, step: 5)
                    .disabled(!model.settings.cameraEnabled)
            }

            Section {
                Toggle("거북목", isOn: $model.settings.postureCheck.forwardHead)
                Toggle("좌우 비대칭 (어깨·고개 기울기, 몸 치우침)", isOn: $model.settings.postureCheck.asymmetry)
                Stepper("바르지 않은 자세가 \(model.settings.postureCheck.cardAfterMinutes)분 이어지면 카드",
                        value: $model.settings.postureCheck.cardAfterMinutes, in: 1...10)
            } header: {
                Text("바른 자세 판정")
            } footer: {
                Text("카메라로 눈과 어깨 위치를 찾아 판정해요. 바르지 않으면 메뉴바 아이콘이 바로 ⚠︎로 바뀌어요. 거북목은 앉은 지 2~15분의 자세를 기준으로 머리가 어깨보다 앞으로 나왔는지 보고, 좌우는 어깨선·눈선이 수평에서 크게 기울었는지 봐요.")
            }
            .disabled(!model.settings.cameraEnabled)

            Section {
                Toggle("카메라로 자세 보기", isOn: $model.settings.cameraEnabled)
                if model.settings.cameraEnabled {
                    if let problem = model.cameraProblem {
                        HStack {
                            Text(problem).foregroundStyle(.secondary)
                            Spacer()
                            if model.cameraStatus != .starting {
                                Button("다시 시도") { model.retryCamera() }
                            }
                        }
                    } else {
                        Toggle("카메라 화면과 인식한 골격 보기", isOn: $showPreview)
                        if showPreview {
                            SkeletonPreview(session: model.camera.session, pose: model.pose)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    HStack {
                        Text("자리나 모니터를 옮겼다면")
                        Spacer()
                        Button("자세 새로 익히기") { model.confirmSetupChange(true) }
                    }
                }
            } header: {
                Text("카메라")
            } footer: {
                Text("영상은 저장하거나 전송하지 않고, 1초에 한 장씩 얼굴과 눈·어깨 위치만 이 Mac에서 계산해요. 사진 일지를 켜면 하루 몇 장만 이 Mac에 잠시 둬요.")
            }

            Section {
                Toggle("사진 일지 사용", isOn: $model.settings.photoDiaryEnabled)
                if model.settings.photoDiaryEnabled || !model.reviewQueue.isEmpty {
                    Stepper("하루 최대 \(model.settings.photosPerDay)묶음",
                            value: $model.settings.photosPerDay, in: 2...15)
                    Stepper("사진 보관 \(model.settings.photoRetentionDays)일",
                            value: $model.settings.photoRetentionDays, in: 3...30)
                    Toggle("답한 뒤에도 보관 기간까지 남기기", isOn: $model.settings.keepLabeledPhotos)
                    Toggle("답으로 판정값 자동 조정 (하루 한 칸)", isOn: $model.settings.autoTune)
                    HStack {
                        Button(model.reviewQueue.isEmpty ? "사진 리뷰 열기" : "사진 리뷰 열기 (\(model.reviewQueue.count))") {
                            NSApp.activate(ignoringOtherApps: true)
                            openWindow(id: "review")
                        }
                        Spacer()
                        Button("판정값 처음 값으로") { model.resetTuning() }
                        Button("사진 지우기", role: .destructive) { confirmDeletePhotos = true }
                    }
                }
            } header: {
                Text("사진 일지 (판정값 점진 조정)")
            } footer: {
                Text("앉아 있는 동안 알림 순간, 판정값 바로 아래인 순간, 무작위 순간에 작은 사진 묶음(앉은 직후 · 몇 분 전 · 지금)을 남겨요. 사진을 보고 '보이는 자세'와 '알림을 원했는지'에 답하면, 답이 쌓이는 대로 거북목·좌우·같은 자세 판정값을 하루 한 칸씩 옮겨요. 사진은 이 Mac에만 두고(백업 제외), 답하면 바로 지우고, 다른 얼굴이 함께 잡히면 찍지 않아요.")
            }

            Section {
                Button("모든 기록 삭제", role: .destructive) { confirmDelete = true }
            } footer: {
                Text("기록은 이 Mac의 ~/Library/Application Support/SitCheck에만 있어요.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog("착석, 알림, 자세 기록을 모두 지울까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) { model.deleteAllRecords() }
        } message: {
            Text("설정은 남아요. 사진 일지 사진도 함께 지워요. 되돌릴 수 없어요.")
        }
        .confirmationDialog("사진 일지 사진을 모두 지울까요?", isPresented: $confirmDeletePhotos) {
            Button("사진 삭제", role: .destructive) { model.deleteAllPhotos() }
        } message: {
            Text("이미 한 답과 판정값 조정 기록은 남아요.")
        }
    }
}
