import AppKit
import SwiftUI
import SitCheckCore

/// 사진 일지 리뷰: 실제로 일하던 순간의 사진을 보고 '보이는 자세', '무엇을 하고 있었나', '알림을 받았으면 좋았을까'에 답한다.
/// 답은 판정값을 하루 한 칸씩 옮기는 데 쓰고, 사진은 답하면 지운다.
struct PhotoReviewView: View {
    @EnvironmentObject private var model: AppModel
    @State private var activity: SnapshotActivity?
    /// nil = 아직 고르지 않음, 빈 집합 = '해당 없음'
    @State private var observed: Set<PostureIssue>?
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
                Text("'이 순간' 사진에서 보이는 자세를 모두 골라 주세요").font(.headline)
                HStack(spacing: 6) {
                    ForEach(PostureIssue.allCases, id: \.self) { issue in
                        choice(Self.seenLabel(issue), selected: observed?.contains(issue) == true) {
                            var set = observed ?? []
                            if set.contains(issue) { set.remove(issue) } else { set.insert(issue) }
                            observed = set
                        }
                    }
                    choice("해당 없음", selected: observed == []) {
                        observed = observed == [] ? nil : []
                    }
                }
                Text("앱의 판정과 상관없이 사진에 보이는 대로 골라 주세요. '앉은 직후' 사진과 비교하면 쉬워요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                Text("이 순간 알림을 받았으면 좋았을까요?").font(.headline)
                HStack(spacing: 6) {
                    ForEach(SnapshotWant.allCases, id: \.self) { option in
                        choice(option.label, selected: wanted == option) {
                            wanted = wanted == option ? nil : option
                        }
                    }
                }
            }
            if snapshot.reason == .event, snapshot.rule == .stillness, snapshot.labeledAt == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("그때까지 정말 거의 같은 자세였나요? (앞의 사진들과 비교)").font(.headline)
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
                model.submitReview(snapshot, activity: activity, observed: observed, wanted: wanted, match: match)
                resetAnswers()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(activity == nil && observed == nil && wanted == nil && match == nil)
            Button("건너뛰기 (사진 지움)") {
                model.submitReview(snapshot, activity: nil, observed: nil, wanted: nil, match: nil)
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
        observed = nil
        wanted = nil
        match = nil
    }

    /// 사진에서 고르는 말 (앱 판정 이름 대신 보이는 모습으로)
    static func seenLabel(_ issue: PostureIssue) -> String {
        switch issue {
        case .forwardHead: return "머리가 앞으로 나옴"
        case .shoulderTilt: return "어깨가 한쪽으로 기욺"
        case .headTilt: return "고개가 기욺"
        case .sideLean: return "몸이 한쪽으로 치우침"
        }
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
            let c = model.settings.postureCheck
            Text(String(format: "거북목 %.0f%% · 어깨 %.0f° · 고개 %.0f° · 치우침 %.0f%% · 같은 자세 %d분",
                        c.forwardHeadRatio * 100, c.shoulderTiltDegrees, c.headTiltDegrees, c.sideLeanRatio * 100,
                        model.settings.signals.stillMinutes))
                .font(.callout)
            if let last = model.tuningLog.last {
                Text("최근 조정 \(last.at.formatted(date: .abbreviated, time: .omitted)): \(changeText(last))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(model.settings.autoTune ? "아직 조정 없음. 항목마다 답이 12개 이상(그렇다·아니다 각각 4개 이상) 모이면 하루 한 칸씩 옮겨요."
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
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
    }

    private var footerText: String {
        let keep = model.settings.keepLabeledPhotos ? "답한 뒤에도 \(model.settings.photoRetentionDays)일까지 남기고"
                                                    : "답하면 바로 지우고 (10%는 이틀 뒤 한 번 더 보여 준 뒤 지움)"
        return "사진은 이 Mac의 ~/Library/Application Support/SitCheck/photos에만 있고 전송하지 않아요. \(keep), 답하지 않은 사진도 \(model.settings.photoRetentionDays)일이 지나면 지워요. 다른 얼굴이 함께 잡히면 찍지 않아요."
    }
}
