import AppKit
import SwiftUI
import SitCheckCore

/// 사진 일지 리뷰: 실제로 일하던 순간의 사진을 보고 '무엇을 하고 있었나', '알림을 받았으면 좋았을까'에 답한다.
/// 답은 판정값을 하루 한 칸씩 옮기는 데 쓰고, 사진은 답하면 지운다.
struct PhotoReviewView: View {
    @EnvironmentObject private var model: AppModel
    @State private var activity: SnapshotActivity?
    @State private var wanted: SnapshotWant?
    @State private var match: NudgeFeedback?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let snapshot = model.reviewQueue.first {
                header(snapshot)
                photoStrip(snapshot)
                facts(snapshot)
                Divider()
                questions(snapshot)
                actions(snapshot)
            } else {
                emptyState
            }
            Divider()
            tuningSummary
            Text(footerText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 760)
        .onAppear { model.refreshReview() }
    }

    // MARK: - 사진

    private func header(_ snapshot: Snapshot) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.at.formatted(date: .abbreviated, time: .shortened))
                    .font(.title3.bold())
                if snapshot.labeledAt != nil {
                    Text("다시 보기 · 며칠 전에 답한 사진이에요. 답이 일정한지 보려고 한 번 더 물어요.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                } else if let line = SnapshotCopy.eventLine(snapshot) {
                    Text(line).font(.callout)
                } else {
                    Text(snapshot.reason.label).font(.callout)
                }
            }
            Spacer()
            Text("남은 사진 \(model.reviewQueue.count)묶음")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func photoStrip(_ snapshot: Snapshot) -> some View {
        let ordered = snapshot.photos.sorted {
            (SnapshotPhoto.order.firstIndex(of: $0.slot) ?? 9) < (SnapshotPhoto.order.firstIndex(of: $1.slot) ?? 9)
        }
        return HStack(alignment: .top, spacing: 10) {
            ForEach(ordered, id: \.slot) { photo in
                VStack(spacing: 4) {
                    if let url = model.photoURL(snapshot, photo), let image = NSImage(contentsOf: url) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(photo.slot == "now" ? Color.accentColor : Color.clear, lineWidth: 2))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 170, height: 128)
                            .overlay(Text("사진 없음").font(.caption).foregroundStyle(.secondary))
                    }
                    Text("\(SnapshotCopy.slotTitle(photo, snapshotAt: snapshot.at)) · \(photo.at.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(photo.slot == "now" ? Color.primary : Color.secondary)
                }
            }
        }
    }

    private func facts(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SnapshotCopy.facts(snapshot), id: \.self) { line in
                Text(line).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 질문

    private func questions(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("'이 순간' 사진에서 무엇을 하고 있었나요?").font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), alignment: .leading, spacing: 6) {
                    ForEach(SnapshotActivity.allCases, id: \.self) { option in
                        choice(option.label, selected: activity == option) {
                            activity = activity == option ? nil : option
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("이 순간 '잠깐 움직여 보세요' 알림을 받았으면 좋았을까요?").font(.headline)
                HStack(spacing: 6) {
                    ForEach(SnapshotWant.allCases, id: \.self) { option in
                        choice(option.label, selected: wanted == option) {
                            wanted = wanted == option ? nil : option
                        }
                    }
                }
                Text("바른 자세인지가 아니라, 그때 알림을 원했을지만 골라 주세요. 앞의 사진들과 비교해 보면 쉬워요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if snapshot.reason == .event, snapshot.labeledAt == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("감지 내용이 사진과 맞나요?").font(.headline)
                    HStack(spacing: 6) {
                        ForEach(NudgeFeedback.allCases, id: \.self) { option in
                            choice(option.label, selected: match == option) {
                                match = match == option ? nil : option
                            }
                        }
                    }
                }
            }
        }
    }

    private func actions(_ snapshot: Snapshot) -> some View {
        HStack {
            Button("저장하고 다음") {
                model.submitReview(snapshot, activity: activity, wanted: wanted, match: match)
                resetAnswers()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(activity == nil && wanted == nil && match == nil)
            Button("건너뛰기 (사진 지움)") {
                model.submitReview(snapshot, activity: nil, wanted: nil, match: nil)
                resetAnswers()
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func choice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        if selected {
            Button(title, action: action).buttonStyle(.borderedProminent)
        } else {
            Button(title, action: action).buttonStyle(.bordered)
        }
    }

    private func resetAnswers() {
        activity = nil
        wanted = nil
        match = nil
    }

    // MARK: - 빈 화면, 조정 기록

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("지금 답할 사진이 없어요").font(.title3.bold())
            Text(model.settings.photoDiaryEnabled
                 ? "앉아 있는 동안 하루 최대 \(model.settings.photosPerDay)묶음을 남겨요. 쌓이면 메뉴에 표시돼요."
                 : "사진 일지가 꺼져 있어요. 설정 > 사진 일지에서 켤 수 있어요.")
                .foregroundStyle(.secondary)
        }
    }

    private var tuningSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("판정값").font(.caption.bold()).foregroundStyle(.secondary)
            let p = model.settings.signals
            Text(String(format: "오래 같은 자세 %d분 · 아래로·가까이 %.1f배 · 자세 변화 %.1f배", p.stillMinutes, p.driftK, p.shiftK)
                 + (model.settings.distanceCalibration != nil ? String(format: " · 가까움 %.1f cm", p.nearCm) : ""))
                .font(.callout)
            if let last = model.tuningLog.last {
                Text("최근 조정 \(last.at.formatted(date: .abbreviated, time: .omitted)): \(changeText(last))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(model.settings.autoTune ? "아직 조정 없음. 네/아니요 답이 12개 이상(각각 4개 이상) 모이면 하루 한 칸씩 옮겨요."
                                             : "자동 조정이 꺼져 있어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func changeText(_ change: TuningChange) -> String {
        if change.parameter == "reset" { return change.note }
        return "\(change.note) → \(trim(change.oldValue)) → \(trim(change.newValue))"
    }

    private func trim(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private var footerText: String {
        let keep = model.settings.keepLabeledPhotos ? "답한 뒤에도 \(model.settings.photoRetentionDays)일까지 남기고"
                                                    : "답하면 바로 지우고 (10%는 이틀 뒤 한 번 더 보여 준 뒤 지움)"
        return "사진은 이 Mac의 ~/Library/Application Support/SitCheck/photos에만 있고 전송하지 않아요. \(keep), 답하지 않은 사진도 \(model.settings.photoRetentionDays)일이 지나면 지워요. 다른 얼굴이 함께 잡히면 찍지 않아요."
    }
}
