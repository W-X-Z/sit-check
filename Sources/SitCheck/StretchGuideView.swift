import AppKit
import SwiftUI
import SitCheckCore

/// FR-05: 동작 설명, 확인 포인트, 좌우 타이머
struct StretchGuideView: View {
    let stretch: Stretch
    let extra: ExtraSet?
    let back: () -> Void

    @State private var phaseIndex = 0
    @State private var remaining = 0
    @State private var running = false
    @State private var finished = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var phases: [TimerPhase] { stretch.phases(extra: extra) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: back) {
                Label("카드로 돌아가기", systemImage: "chevron.left")
            }
            .buttonStyle(.link)

            HStack(spacing: 12) {
                Image(systemName: stretch.symbol)
                    .font(.system(size: 36))
                    .frame(width: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stretch.id) \(stretch.name)").font(.title3.bold())
                    Text("\(stretch.posture.label) · \(stretch.dose.summary) · \(stretch.target)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(stretch.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(i + 1).").monospacedDigit().foregroundStyle(.secondary)
                        Text(step).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .font(.callout)

            Label {
                Text(stretch.checkPoint).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "checkmark.seal")
            }
            .font(.callout)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(.yellow.opacity(0.15)))

            timer
        }
        .onAppear(perform: reset)
        .onReceive(ticker) { _ in step() }
    }

    private var timer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(phases.enumerated()), id: \.offset) { i, phase in
                    Text(phase.title)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(i == phaseIndex && !finished ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.1)))
                }
            }
            Text(finished ? "끝" : "\(remaining)초")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
            HStack {
                if finished {
                    Button("다시", action: reset)
                    Button("기록하러 가기", action: back).keyboardShortcut(.defaultAction)
                } else {
                    Button(running ? "일시정지" : "시작") { running.toggle() }
                        .keyboardShortcut(.defaultAction)
                    Button("다음 구간", action: advance)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func reset() {
        phaseIndex = 0
        remaining = phases.first?.seconds ?? 0
        running = false
        finished = false
    }

    private func step() {
        guard running, !finished else { return }
        if remaining > 1 {
            remaining -= 1
        } else {
            NSSound.beep()
            advance()
        }
    }

    private func advance() {
        if phaseIndex + 1 < phases.count {
            phaseIndex += 1
            remaining = phases[phaseIndex].seconds
        } else {
            finished = true
            running = false
        }
    }
}
