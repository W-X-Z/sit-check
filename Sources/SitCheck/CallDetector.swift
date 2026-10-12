import AVFoundation
import CoreAudio

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
