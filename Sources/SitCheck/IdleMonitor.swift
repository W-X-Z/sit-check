import CoreGraphics

/// FR-02: 마지막 키보드·마우스 입력 이후 경과 시간. 별도 권한이 필요 없다.
enum IdleMonitor {
    static func secondsSinceLastInput() -> Double {
        // kCGAnyInputEventType (~0)
        let anyInput = CGEventType(rawValue: ~0)!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
