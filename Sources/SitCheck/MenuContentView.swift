import AppKit
import SwiftUI
import SitCheckCore

/// 메뉴바 아이콘을 눌렀을 때의 창
struct MenuContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            status

            if model.clinicAdvice {
                Label("통증이나 저림이 3일 연속 기록됐어요. 진료를 받아 보세요.", systemImage: "cross.case")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            Divider()
            summary
            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Button("지금 스트레칭 하기") { model.showCard() }
                Button("착석 타이머 다시 시작") { model.restartTimer() }
                if model.mutedUntil != nil {
                    Button("알림 다시 켜기") { model.unmute() }
                } else {
                    Button("1시간 끄기") { model.muteForAWhile() }
                }
            }
            .buttonStyle(.link)

            Divider()

            HStack {
                Button("설정…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }
                Spacer()
                Button("종료") { NSApp.terminate(nil) }
            }

            if let error = model.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { model.refreshStats() }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.isSitting {
                Text("\(model.sittingMinutes)분째 앉아 있어요")
                    .font(.title3.bold())
                Text("\(model.settings.sitAlertMinutes)분이 되면 알려 드려요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("자리 비움")
                    .font(.title3.bold())
                Text("입력이 \(model.settings.awayAfterMinutes)분 넘게 없으면 타이머를 초기화해요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let until = model.mutedUntil {
                Text("알림 꺼짐 · \(until.formatted(date: .omitted, time: .shortened))까지")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("최근 7일").font(.caption.bold()).foregroundStyle(.secondary)
            if let rate = model.completionRate7d {
                Text("수행률 \(Int((rate * 100).rounded()))% (알림 \(model.nudgeCount7d)회)")
            } else {
                Text("아직 알림 기록이 없어요").foregroundStyle(.secondary)
            }

            if !model.tightness.isEmpty {
                Text("좌우 뻣뻣함 (최근 14일)").font(.caption.bold()).foregroundStyle(.secondary)
                    .padding(.top, 4)
                ForEach(model.tightness) { item in
                    HStack {
                        Text(item.stretch.name)
                        Spacer()
                        Text(tightnessText(item.index))
                            .foregroundStyle(.secondary)
                        Text("\(item.count)회").font(.caption).foregroundStyle(.tertiary)
                    }
                    .font(.callout)
                }
            }
        }
    }

    /// 사실만 표시한다 (평가 문구 없음). 양수면 오른쪽이 덜 간 기록이 많음.
    private func tightnessText(_ index: Double) -> String {
        let pct = Int((abs(index) * 100).rounded())
        if pct == 0 { return "차이 없음" }
        return index > 0 ? "오른쪽 +\(pct)%" : "왼쪽 +\(pct)%"
    }
}
