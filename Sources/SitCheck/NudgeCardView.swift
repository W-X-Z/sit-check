import SwiftUI
import SitCheckCore

/// 알림 카드: 사유 한 줄, 스트레칭 2개, 좌우 기록 버튼 3개, 미루기와 끄기.
struct NudgeCardView: View {
    @ObservedObject var session: CardSession
    let model: AppModel

    var body: some View {
        Group {
            if let stretch = session.guide {
                StretchGuideView(stretch: stretch,
                                 extra: model.settings.extraSets[stretch.id]) {
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
            VStack(alignment: .leading, spacing: 4) {
                Text(session.reason)
                    .font(.headline)
                Text(session.actionLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(session.stretches) { stretch in
                StretchRow(stretch: stretch,
                           extra: model.settings.extraSets[stretch.id],
                           entry: session.entries[stretch.id] ?? .init(),
                           openGuide: { session.guide = stretch },
                           recordSide: { model.record(side: $0, for: stretch, in: session) },
                           recordSymptom: { model.record(symptom: $0, for: stretch, in: session) })
            }

            if session.stretches.isEmpty {
                Text("제시할 동작이 없어요. 설정에서 제외 목록을 확인해 주세요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("10분 미루기") { model.resolveCard(.snooze) }
                Button("1시간 끄기") { model.resolveCard(.dismiss) }
                Spacer()
                Button("완료") { model.resolveCard(.done) }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.small)

            if model.clinicAdvice {
                Text("통증이나 저림이 3일 연속 기록됐어요. 진료를 받아 보세요.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct StretchRow: View {
    let stretch: Stretch
    let extra: ExtraSet?
    let entry: CardSession.Entry
    let openGuide: () -> Void
    let recordSide: (Side) -> Void
    let recordSymptom: (Symptom) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: openGuide) {
                HStack(spacing: 10) {
                    Image(systemName: stretch.symbol)
                        .font(.title2)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(stretch.id) \(stretch.name)")
                            .font(.body.weight(.semibold))
                        Text("\(stretch.posture.label) · \(doseText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("동작 설명과 타이머 보기")

            if stretch.dose.isBilateral {
                HStack(spacing: 6) {
                    Text("덜 간 쪽")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("덜 간 쪽", selection: Binding(
                        get: { entry.side },
                        set: { if let side = $0 { recordSide(side) } }
                    )) {
                        ForEach(Side.allCases, id: \.self) { side in
                            Text(side.label).tag(Side?.some(side))
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            } else {
                Button(entry.side == nil ? "했어요" : "기록됨") { recordSide(.same) }
                    .controlSize(.small)
                    .disabled(entry.side != nil)
            }

            HStack(spacing: 6) {
                ForEach([Symptom.pain, .numb], id: \.self) { symptom in
                    Toggle(symptom.label, isOn: Binding(
                        get: { entry.symptom == symptom },
                        set: { _ in recordSymptom(symptom) }
                    ))
                    .toggleStyle(.button)
                    .controlSize(.mini)
                }
                if entry.symptom != .none {
                    Text("다음부터 이 동작은 빼 둘게요")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
    }

    private var doseText: String {
        guard let extra, extra.seconds > 0, extra.side != .same, stretch.dose.isBilateral else {
            return stretch.dose.summary
        }
        return "\(stretch.dose.summary), \(extra.side.label) \(extra.seconds)초 추가"
    }
}
