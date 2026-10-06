import AVFoundation
import SwiftUI
import Vision
import SitCheckCore

enum CameraStatus: Equatable {
    case off
    case starting
    case running
    case denied
    case unavailable(String)
}

/// FR-08: 카메라 프레임을 `analysisInterval`마다 한 장씩 Vision으로 분석해 얼굴 각도·크기만 넘긴다.
/// 프레임은 메모리에서 바로 버리고 저장하거나 전송하지 않는다.
final class PostureCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    var analysisInterval: TimeInterval = 1
    /// 얼굴을 찾지 못한 프레임은 nil. 메인 액터에서 호출된다. `start` 전에 지정한다.
    var onSample: (@MainActor (PostureSample?) -> Void)?

    private let queue = DispatchQueue(label: "local.sitcheck.camera")
    private var configured = false
    private var lastAnalysis = Date.distantPast

    /// Info.plist에 카메라 사용 설명이 없으면 macOS가 접근 시 앱을 종료시킨다 (`swift run`으로 실행한 경우).
    static var canRequestAccess: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil
    }

    @MainActor
    func start(completion: @escaping @MainActor (CameraStatus) -> Void) {
        guard Self.canRequestAccess else {
            completion(.unavailable("카메라는 build/SitCheck.app으로 실행할 때만 쓸 수 있어요"))
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run(completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.run(completion)
                } else {
                    Task { @MainActor in completion(.denied) }
                }
            }
        default:
            completion(.denied)
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
            self.lastAnalysis = .distantPast
        }
    }

    private func run(_ completion: @escaping @MainActor (CameraStatus) -> Void) {
        queue.async {
            if !self.configured {
                if let error = self.configure() {
                    Task { @MainActor in completion(.unavailable(error)) }
                    return
                }
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            let running = self.session.isRunning
            Task { @MainActor in completion(running ? .running : .unavailable("카메라를 시작하지 못했어요")) }
        }
    }

    private func configure() -> String? {
        guard let device = AVCaptureDevice.default(for: .video) else { return "카메라를 찾지 못했어요" }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            return "카메라를 열지 못했어요: \(error.localizedDescription)"
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.vga640x480) { session.sessionPreset = .vga640x480 }
        guard session.canAddInput(input) else { return "카메라 입력을 연결하지 못했어요" }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return "카메라 출력을 연결하지 못했어요" }
        session.addOutput(output)
        return nil
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastAnalysis) >= analysisInterval,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = now

        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        try? VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up).perform([request])

        // 여러 얼굴이 잡히면 가장 큰(가까운) 얼굴을 사용자로 본다.
        let face = request.results?.max { $0.boundingBox.width < $1.boundingBox.width }
        let sample = face.map {
            PostureSample(at: now,
                          roll: Self.degrees($0.roll),
                          yaw: Self.degrees($0.yaw),
                          faceWidth: Double($0.boundingBox.width))
        }
        let onSample = self.onSample
        Task { @MainActor in onSample?(sample) }
    }

    private static func degrees(_ radians: NSNumber?) -> Double {
        (radians?.doubleValue ?? 0) * 180 / .pi
    }
}

/// 기준 자세를 저장할 때 얼굴이 화면에 잘 들어오는지 확인하는 미리보기 (좌우 반전).
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
