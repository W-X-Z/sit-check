import AppKit
import SwiftUI
import SitCheckCore

/// 메뉴바 아이콘을 눌렀을 때의 창: 자세가 바른지, 오래 앉아 있는지.
struct MenuContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            postureVerdict
            sittingVerdict

            Divider()

            HStack(spacing: 8) {
                Button {
                    model.showCard()
                } label: {
                    Label("지금 스트레칭", systemImage: "figure.cooldown")
                        .frame(maxWidth: .infinity)
                }
                if model.mutedUntil != nil {
                    Button {
                        model.unmute()
                    } label: {
                        Label("알림 켜기", systemImage: "bell")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Button {
                        model.muteForAWhile()
                    } label: {
                        Label("1시간 끄기", systemImage: "moon.zzz")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .controlSize(.large)

            HStack {
                Button("설정…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }
                if model.settings.photoDiaryEnabled || !model.reviewQueue.isEmpty {
                    Button(model.reviewQueue.isEmpty ? "사진 리뷰…" : "사진 리뷰 (\(model.reviewQueue.count))…") {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "review")
                    }
                }
                Spacer()
                Button("종료") { NSApp.terminate(nil) }
            }
            .buttonStyle(.link)
            .font(.callout)

            if let error = model.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: - 자세 올바름 / 아님

    @ViewBuilder
    private var postureVerdict: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("자세").font(.caption.bold()).foregroundStyle(.secondary)

            if let problem = model.cameraProblem {
                cameraProblem(problem)
            } else if !model.isSitting {
                statusTitle("앉으면 볼게요", symbol: "pause.circle", color: .secondary, detail: nil)
            } else if model.lastSample == nil {
                statusTitle("얼굴을 못 봐요", symbol: "person.crop.circle.badge.questionmark", color: .secondary,
                            detail: "카메라 쪽을 보고 앉아 주세요")
            } else if model.postureReading == nil {
                statusTitle("자세를 재는 중", symbol: "hourglass", color: .secondary,
                            detail: "몇 초만 가만히 앉아 주세요")
            } else if model.postureIssues.isEmpty {
                statusTitle("올바름", symbol: "checkmark.circle.fill", color: .green, detail: goodDetail)
                issueList
            } else {
                statusTitle("올바르지 않음", symbol: "exclamationmark.triangle.fill", color: .orange, detail: badDetail)
                issueList
            }

            if model.setupChangeSuspected { setupChange }
        }
    }

    private var goodDetail: String? {
        model.postureReading?.shoulderTilt == nil ? "고개는 바르고, 어깨가 안 보여 거북목은 아직 못 봐요" : nil
    }

    private var badDetail: String? {
        let minutes = model.badPostureSince.map { Int(Date().timeIntervalSince($0) / 60) } ?? 0
        let after = model.settings.postureCheck.cardAfterMinutes
        if minutes >= after { return "\(minutes)분째예요. 자세를 한 번 고쳐 앉아 보세요" }
        if minutes >= 1 { return "\(minutes)분째 · \(after)분 이어지면 알려 드려요" }
        return "\(after)분 이어지면 알려 드려요"
    }

    @ViewBuilder
    private var issueList: some View {
        if let reading = model.postureReading {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(PostureIssue.allCases.filter { model.settings.postureCheck.isEnabled($0) }, id: \.self) { issue in
                    let bad = model.postureIssues.contains(issue)
                    let phrase = reading.phrase(issue)
                    HStack(spacing: 6) {
                        Image(systemName: phrase == nil ? "minus.circle" : bad ? "xmark.circle.fill" : "checkmark.circle")
                            .foregroundStyle(phrase == nil ? Color.secondary : bad ? Color.orange : Color.green)
                            .font(.caption)
                            .frame(width: 14)
                        Text(issue.title).font(.caption.weight(.medium))
                        Text(phrase ?? missingPhrase(issue))
                            .font(.caption)
                            .foregroundStyle(bad ? Color.primary : Color.secondary)
                    }
                }
            }
            .padding(.leading, 2)
        }
    }

    private func missingPhrase(_ issue: PostureIssue) -> String {
        switch issue {
        case .forwardHead:
            let have = model.uprightReference?.minutes ?? 0
            if model.postureReading?.shoulderTilt == nil { return "어깨가 보여야 해요" }
            return "기준 익히는 중 (\(have)/\(UprightReference.requiredMinutes)분)"
        case .shoulderTilt:
            return "어깨가 보여야 해요"
        case .sideLean:
            return model.postureReading?.headTilt != nil ? "고개를 돌리고 있어 잠시 보류" : "어깨가 보여야 해요"
        case .headTilt:
            return "아직 재는 중"
        }
    }

    // MARK: - 오래 앉아 있음

    private var sittingVerdict: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("앉아 있는 시간").font(.caption.bold()).foregroundStyle(.secondary)
            if model.isSitting {
                let tooLong = model.sittingMinutes >= model.settings.sitAlertMinutes
                statusTitle(tooLong ? "너무 오래 앉아 있어요" : "\(model.sittingMinutes)분째",
                            symbol: tooLong ? "exclamationmark.circle.fill" : "timer",
                            color: tooLong ? .orange : .accentColor,
                            detail: sittingCaption)
                ProgressView(value: Double(min(model.sittingMinutes, model.settings.sitAlertMinutes)),
                             total: Double(model.settings.sitAlertMinutes))
                    .tint(tooLong ? .orange : .accentColor)
            } else {
                statusTitle("자리 비움", symbol: "pause.circle", color: .secondary, detail: "다시 앉으면 0분부터 세요")
            }
        }
    }

    private var sittingCaption: String {
        if let until = model.mutedUntil {
            return "알림 꺼짐 · \(until.formatted(date: .omitted, time: .shortened))까지"
        }
        let left = model.settings.sitAlertMinutes - model.sittingMinutes
        return left > 0 ? "\(left)분 뒤에 일어나자고 알려 드려요" : "잠깐 일어날 때예요"
    }

    private func statusTitle(_ title: String, symbol: String, color: Color, detail: String?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func cameraProblem(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            statusTitle(text, symbol: "video.slash", color: .secondary, detail: nil)
            if model.cameraStatus == .denied {
                Button("카메라 권한 설정 열기") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                }
                .buttonStyle(.link)
                .padding(.leading, 36)
            } else if model.cameraStatus != .starting {
                Button("다시 시도") { model.retryCamera() }
                    .buttonStyle(.link)
                    .padding(.leading, 36)
            }
        }
    }

    private var setupChange: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("자리나 화면 위치가 바뀌었나요? 거북목 기준을 잠시 멈췄어요.")
                .font(.caption)
                .foregroundStyle(.orange)
            HStack {
                Button("네, 새로 익히기") { model.confirmSetupChange(true) }
                Button("아니요") { model.confirmSetupChange(false) }
            }
            .controlSize(.small)
        }
    }
}
