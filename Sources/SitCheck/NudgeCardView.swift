import SwiftUI
import SitCheckCore

/// 알림 카드: 사유 한 줄, 할 일 한 줄, (오래 앉아 있음·바른 자세 판정 카드면) 스트레칭 2개, 버튼 3개.
struct NudgeCardView: View {
    @ObservedObject var session: CardSession
    let model: AppModel

    var body: some View {
        Group {
            if let stretch = session.guide {
                StretchGuideView(stretch: stretch, extra: nil) {
                    session.guide = nil
                }
            } else {
                card
            }
        }
        .padding(16)
        .background(.regularMaterial)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: session.isPostureCard ? "figure.seated.side" : "figure.walk")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.reason)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(session.actionLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(session.stretches) { stretch in
                StretchRow(stretch: stretch) { session.guide = stretch }
            }

            HStack {
                Button(session.isPostureCard ? "이번엔 넘기기" : "10분 미루기") { model.resolveCard(.snooze) }
                Button("1시간 끄기") { model.resolveCard(.dismiss) }
                Spacer()
                Button(doneTitle) { model.resolveCard(.done) }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.small)
        }
    }

    private var doneTitle: String {
        if session.rule.isPostureCheck { return "고쳐 앉았어요" }
        return session.isPostureCard ? "일어났다 올게요" : "완료"
    }
}

private struct StretchRow: View {
    let stretch: Stretch
    let openGuide: () -> Void

    var body: some View {
        Button(action: openGuide) {
            HStack(spacing: 10) {
                Image(systemName: stretch.symbol)
                    .font(.title3)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stretch.name)
                        .font(.body.weight(.semibold))
                    Text("\(stretch.posture.label) · \(stretch.dose.summary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("동작 설명과 타이머 보기")
    }
}
