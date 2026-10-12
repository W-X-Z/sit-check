import AppKit
import SwiftUI
import SitCheckCore

@main
struct SitCheckApp: App {
    @StateObject private var model = AppModel()

    init() {
        // Dock 아이콘 없이 메뉴바에만 상주
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("자세 코치 설정", id: "settings") {
            SettingsView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)

        Window("자세 코치 사진 리뷰", id: "review") {
            PhotoReviewView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
    }
}

/// FR-01: 연속 착석 시간과 상태 아이콘
struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: model.statusSymbol)
            if model.isSitting {
                if model.isPostureBad {
                    Text("자세")
                }
                Text("\(model.sittingMinutes)분")
                    .monospacedDigit()
            }
        }
    }
}
