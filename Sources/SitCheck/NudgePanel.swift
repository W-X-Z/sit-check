import AppKit
import SwiftUI

/// 포커스를 뺏지 않는 패널 (nonactivating). 버튼 클릭은 받을 수 있도록 key는 허용한다.
private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 화면 우상단에 알림 카드를 띄운다.
@MainActor
final class NudgePanelController {
    private var panel: FloatingPanel?
    private var resizeObserver: NSObjectProtocol?
    static let width: CGFloat = 360
    static let margin: CGFloat = 12

    func show<Content: View>(_ content: Content) {
        close()
        let hosting = NSHostingController(rootView: content.frame(width: Self.width))
        hosting.sizingOptions = [.preferredContentSize]

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 300),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentViewController = hosting

        // 가이드 화면으로 바뀌어 높이가 달라져도 우상단에 붙어 있게 한다.
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.anchorTopRight() }
        }

        self.panel = panel
        anchorTopRight()
        panel.orderFrontRegardless()
    }

    func bringToFront() {
        panel?.orderFrontRegardless()
    }

    func close() {
        if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
        resizeObserver = nil
        panel?.close()
        panel = nil
    }

    private func anchorTopRight() {
        guard let panel, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let topLeft = NSPoint(x: visible.maxX - panel.frame.width - Self.margin, y: visible.maxY - Self.margin)
        if panel.frame.origin.x != topLeft.x || panel.frame.maxY != topLeft.y {
            panel.setFrameTopLeftPoint(topLeft)
        }
    }
}
