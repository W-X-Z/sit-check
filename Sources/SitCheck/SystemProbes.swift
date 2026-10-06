import AVFoundation
import CoreAudio
import CoreMotion
import Darwin
import Foundation

/// 이 앱 프로세스의 CPU 사용률 (코어 1개 = 100%). 분 단위 기록마다 직전 기록 이후의 평균을 잰다 (실험 1).
struct CPUMeter {
    private var lastCPU: Double?
    private var lastWall: Date?

    static func processCPUSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ t: timeval) -> Double { Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }

    /// 직전 호출 이후의 평균 CPU 사용률. 첫 호출이면 nil.
    mutating func sample(at now: Date) -> Double? {
        let cpu = Self.processCPUSeconds()
        defer {
            lastCPU = cpu
            lastWall = now
        }
        guard let lastCPU, let lastWall else { return nil }
        let wall = now.timeIntervalSince(lastWall)
        guard wall > 1 else { return nil }
        return max(0, (cpu - lastCPU) / wall * 100)
    }
}

/// 통화 중인지 추정한다. 카드는 통화 중에 띄우지 않고 미룬다.
/// - 기본 입력 장치(마이크)를 어떤 프로세스든 쓰고 있으면 통화 중으로 본다.
/// - 다른 앱이 카메라를 쓰고 있어도 통화 중으로 본다.
enum CallDetector {
    static func inCall() -> Bool {
        micInUse() || cameraInUseByAnotherApp()
    }

    static func micInUse() -> Bool {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) == noErr,
              deviceID != 0 else { return false }
        var running = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }

    static func cameraInUseByAnotherApp() -> Bool {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external],
                                         mediaType: .video, position: .unspecified)
            .devices.contains { $0.isInUseByAnotherApplication }
    }
}

/// 실험 2: AirPods 머리 동작 데이터가 이 Mac에서 들어오는지 30초 동안 확인한다.
/// Intel Mac에서는 동작하지 않을 수 있다 (Mac의 머리 추적은 Apple silicon 필요라는 지원 문서가 있음).
@MainActor
final class HeadphoneProbe: NSObject, CMHeadphoneMotionManagerDelegate {
    private let manager = CMHeadphoneMotionManager()
    private var samples = 0
    private var connected = false
    private var firstPitch: Double?
    private var lastPitch: Double?

    func run(seconds: TimeInterval = 30, completion: @escaping @MainActor (String) -> Void) {
        let status = CMHeadphoneMotionManager.authorizationStatus()
        guard manager.isDeviceMotionAvailable else {
            completion("AirPods 동작 데이터: 이 Mac에서 사용할 수 없음 (isDeviceMotionAvailable = false, 권한 상태 \(Self.describe(status)))")
            return
        }
        manager.delegate = self
        samples = 0
        firstPitch = nil
        lastPitch = nil
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                self.samples += 1
                let pitch = motion.attitude.pitch * 180 / .pi
                if self.firstPitch == nil { self.firstPitch = pitch }
                self.lastPitch = pitch
            }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self else { return }
            self.manager.stopDeviceMotionUpdates()
            let rate = Double(self.samples) / seconds
            var text = "AirPods 동작 데이터: \(Int(seconds))초 동안 샘플 \(self.samples)개 (초당 \(String(format: "%.1f", rate)))"
            text += ", 연결 신호 \(self.connected ? "받음" : "없음"), 권한 \(Self.describe(CMHeadphoneMotionManager.authorizationStatus()))"
            if let a = self.firstPitch, let b = self.lastPitch {
                text += String(format: ", 고개 앞뒤 기울기 %.0f° → %.0f°", a, b)
            }
            if self.samples == 0 { text += ". AirPods를 귀에 꽂고 이 Mac에 연결했는지 확인해 주세요." }
            completion(text)
        }
    }

    nonisolated func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor in self.connected = true }
    }

    nonisolated func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {}

    private static func describe(_ status: CMAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "허용"
        case .denied: return "거부"
        case .restricted: return "제한"
        case .notDetermined: return "아직 묻지 않음"
        @unknown default: return "알 수 없음"
        }
    }
}
