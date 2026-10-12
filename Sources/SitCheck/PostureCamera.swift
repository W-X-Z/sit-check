import AVFoundation
import CoreImage
import CoreMedia
import ImageIO
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

/// 쓰고 있는 카메라
struct CameraInfo: Equatable {
    var name: String
    var uniqueID: String
    /// 캡처 프레임 속도 (fps). 상한을 걸었으면 그 값.
    var frameRate: Double?
}

/// 프레임 하나의 분석 결과. 얼굴이 없으면 `sample`이 nil이다.
struct FrameResult: Sendable {
    let at: Date
    let sample: PostureSample?
    let analysisMs: Double
}

/// FR-08: 카메라 프레임을 `analysisInterval`마다 한 장씩 Vision으로 분석해 수치만 넘긴다.
/// 프레임은 메모리에서 바로 버리고 저장하거나 전송하지 않는다.
/// 사진 일지를 켰을 때만 요청받은 순간의 작은 사진(가로 320픽셀)을 JPEG로 넘긴다.
///
/// - 카메라는 내장 카메라로 고정한다 (아이폰 Continuity Camera 등으로 바뀌면 기준이 조용히 깨진다).
/// - 1초에 한 장만 분석하므로 캡처도 지원되는 가장 낮은 프레임 속도로 묶는다.
final class PostureCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    /// 메인 액터에서 호출된다. `start` 전에 지정한다.
    var onFrame: (@MainActor (FrameResult) -> Void)?

    // 아래 값은 queue에서만 읽고 쓴다.
    private let queue = DispatchQueue(label: "local.sitcheck.camera")
    private var configured = false
    private var device: AVCaptureDevice?
    private var lastAnalysis = Date.distantPast
    private var analysisInterval: TimeInterval = 1
    private var mode: AnalysisMode = .face
    private var capFrameRate = true
    private var pending3DProbe: (@MainActor (String) -> Void)?
    private var pendingThumbnails: [@MainActor (Data?) -> Void] = []
    private lazy var imageContext = CIContext()

    /// 사진 일지에 남기는 사진의 가로 픽셀
    static let thumbnailWidth: CGFloat = 320

    /// Info.plist에 카메라 사용 설명이 없으면 macOS가 접근 시 앱을 종료시킨다 (`swift run`으로 실행한 경우).
    static var canRequestAccess: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil
    }

    @MainActor
    func start(preferredID: String?, mode: AnalysisMode, capFrameRate: Bool,
               completion: @escaping @MainActor (CameraStatus, CameraInfo?) -> Void) {
        guard Self.canRequestAccess else {
            completion(.unavailable("카메라는 build/SitCheck.app으로 실행할 때만 쓸 수 있어요"), nil)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run(preferredID: preferredID, mode: mode, capFrameRate: capFrameRate, completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.run(preferredID: preferredID, mode: mode, capFrameRate: capFrameRate, completion)
                } else {
                    Task { @MainActor in completion(.denied, nil) }
                }
            }
        default:
            completion(.denied, nil)
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
            self.lastAnalysis = .distantPast
            self.failThumbnails()
        }
    }

    /// 카메라를 멈추면 기다리던 사진 요청은 사진 없이 끝낸다.
    private func failThumbnails() {
        let requests = pendingThumbnails
        pendingThumbnails = []
        for completion in requests { Task { @MainActor in completion(nil) } }
    }

    /// 연결된 카메라를 떼어 낸다. 다음 `start`에서 카메라를 다시 고른다.
    func resetDevice() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            self.session.commitConfiguration()
            self.device = nil
            self.configured = false
            self.lastAnalysis = .distantPast
            self.failThumbnails()
        }
    }

    /// 분석 구성과 프레임 속도 상한을 바꾼다 (실험 1).
    func update(mode: AnalysisMode, capFrameRate: Bool, completion: (@MainActor (Double?) -> Void)? = nil) {
        queue.async {
            self.mode = mode
            let changed = self.capFrameRate != capFrameRate
            self.capFrameRate = capFrameRate
            var fps: Double?
            if changed, let device = self.device { fps = self.applyFrameRate(device) }
            if let completion { Task { @MainActor in completion(fps) } }
        }
    }

    /// 다음에 분석하는 프레임을 작은 JPEG로 넘긴다 (사진 일지). 얼굴이 없거나 다른 얼굴이 함께 잡히면 nil.
    func captureThumbnail(completion: @escaping @MainActor (Data?) -> Void) {
        queue.async { self.pendingThumbnails.append(completion) }
    }

    /// 다음 프레임에서 3D 몸 자세 요청을 한 번 돌려 결과를 알려 준다 (실험 1).
    func probe3D(completion: @escaping @MainActor (String) -> Void) {
        queue.async { self.pending3DProbe = completion }
    }

    private func run(preferredID: String?, mode: AnalysisMode, capFrameRate: Bool,
                     _ completion: @escaping @MainActor (CameraStatus, CameraInfo?) -> Void) {
        queue.async {
            self.mode = mode
            self.capFrameRate = capFrameRate
            if !self.configured {
                if let error = self.configure(preferredID: preferredID) {
                    Task { @MainActor in completion(.unavailable(error), nil) }
                    return
                }
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            let fps = self.device.flatMap { self.applyFrameRate($0) }
            let info = self.device.map { CameraInfo(name: $0.localizedName, uniqueID: $0.uniqueID, frameRate: fps) }
            let running = self.session.isRunning
            Task { @MainActor in completion(running ? .running : .unavailable("카메라를 시작하지 못했어요"), info) }
        }
    }

    /// 저장해 둔 카메라 → 내장 카메라 → 시스템 기본 카메라 순으로 고른다.
    static func pickDevice(preferredID: String?) -> AVCaptureDevice? {
        if let preferredID, let device = AVCaptureDevice(uniqueID: preferredID) { return device }
        let builtIn = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                       mediaType: .video, position: .unspecified).devices
        return builtIn.first ?? AVCaptureDevice.default(for: .video)
    }

    private func configure(preferredID: String?) -> String? {
        guard let device = Self.pickDevice(preferredID: preferredID) else { return "카메라를 찾지 못했어요" }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            return "카메라를 열지 못했어요: \(error.localizedDescription)"
        }
        session.beginConfiguration()
        if session.canSetSessionPreset(.vga640x480) { session.sessionPreset = .vga640x480 }
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return "카메라 입력을 연결하지 못했어요"
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return "카메라 출력을 연결하지 못했어요"
        }
        session.addOutput(output)
        session.commitConfiguration()
        self.device = device
        return nil
    }

    /// 상한을 걸면 지원되는 가장 낮은 프레임 속도로 고정하고, 풀면 기본값으로 되돌린다.
    /// 프리셋을 바꾸면 이 값이 초기화되므로 프리셋을 정한 뒤에 부른다.
    private func applyFrameRate(_ device: AVCaptureDevice) -> Double? {
        let ranges = device.activeFormat.videoSupportedFrameRateRanges
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if capFrameRate, let slowest = ranges.min(by: { $0.minFrameRate < $1.minFrameRate }) {
                device.activeVideoMinFrameDuration = slowest.maxFrameDuration
                device.activeVideoMaxFrameDuration = slowest.maxFrameDuration
                return slowest.minFrameRate
            }
            device.activeVideoMinFrameDuration = .invalid
            device.activeVideoMaxFrameDuration = .invalid
        } catch {
            return nil
        }
        return ranges.map(\.maxFrameRate).max()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastAnalysis) >= analysisInterval,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = now

        let started = CFAbsoluteTimeGetCurrent()
        let (sample, faces) = analyze(pixels, at: now)
        let ms = (CFAbsoluteTimeGetCurrent() - started) * 1000

        if !pendingThumbnails.isEmpty {
            let requests = pendingThumbnails
            pendingThumbnails = []
            // 사용자 한 사람만 보일 때만 찍는다 (다른 사람이 함께 찍히지 않게).
            let data = faces == 1 ? jpeg(pixels) : nil
            for completion in requests { Task { @MainActor in completion(data) } }
        }

        if let probe = pending3DProbe {
            pending3DProbe = nil
            let result = Self.run3D(pixels)
            Task { @MainActor in probe(result) }
        }
        let onFrame = self.onFrame
        let result = FrameResult(at: now, sample: sample, analysisMs: ms)
        Task { @MainActor in onFrame?(result) }
    }

    /// 거울처럼 좌우를 뒤집고 줄여서 JPEG로 만든다.
    private func jpeg(_ pixels: CVPixelBuffer) -> Data? {
        var image = CIImage(cvPixelBuffer: pixels).oriented(.upMirrored)
        let scale = Self.thumbnailWidth / max(image.extent.width, 1)
        if scale < 1 { image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let quality = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        return imageContext.jpegRepresentation(of: image, colorSpace: space, options: [quality: 0.7])
    }

    /// 프레임 하나를 분석한다. 찾은 얼굴 수도 함께 돌려준다.
    private func analyze(_ pixels: CVPixelBuffer, at now: Date) -> (PostureSample?, Int) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up)
        let faceRequest = VNDetectFaceRectanglesRequest()
        // 리비전 3부터 roll·yaw·pitch가 연속값으로 나온다 (그 전에는 구간 값).
        faceRequest.revision = VNDetectFaceRectanglesRequestRevision3
        var requests: [VNRequest] = [faceRequest]
        let bodyRequest: VNDetectHumanBodyPoseRequest? = mode == .faceBody ? VNDetectHumanBodyPoseRequest() : nil
        if let bodyRequest { requests.append(bodyRequest) }
        try? handler.perform(requests)

        // 여러 얼굴이 잡히면 가장 큰(가까운) 얼굴을 사용자로 본다.
        let faces = faceRequest.results?.count ?? 0
        guard let face = faceRequest.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { return (nil, faces) }
        let box = face.boundingBox
        let width = Double(CVPixelBufferGetWidth(pixels))
        let height = Double(CVPixelBufferGetHeight(pixels))
        // Vision 좌표는 왼쪽 아래가 원점이므로 y를 뒤집어 왼쪽 위 원점으로 맞춘다.
        var sample = PostureSample(at: now,
                                   roll: Self.degrees(face.roll), yaw: Self.degrees(face.yaw), pitch: Self.degrees(face.pitch),
                                   faceWidth: Double(box.width), faceX: Double(box.midX), faceY: 1 - Double(box.midY))

        if mode == .faceLandmarks {
            let landmarksRequest = VNDetectFaceLandmarksRequest()
            landmarksRequest.revision = VNDetectFaceLandmarksRequestRevision3
            landmarksRequest.inputFaceObservations = [face]
            try? handler.perform([landmarksRequest])
            if let landmarks = landmarksRequest.results?.first?.landmarks,
               let left = landmarks.leftPupil?.normalizedPoints.first,
               let right = landmarks.rightPupil?.normalizedPoints.first {
                // 랜드마크 좌표는 얼굴 사각형 안에서 정규화된 값이다.
                let dx = Double((left.x - right.x) * box.width) * width
                let dy = Double((left.y - right.y) * box.height) * height
                sample.eyeDistance = (dx * dx + dy * dy).squareRoot() / width
            }
        }

        if let body = bodyRequest?.results?.first,
           let ls = try? body.recognizedPoint(.leftShoulder), let rs = try? body.recognizedPoint(.rightShoulder),
           ls.confidence >= 0.3, rs.confidence >= 0.3 {
            let lx = Double(ls.location.x) * width, ly = (1 - Double(ls.location.y)) * height
            let rx = Double(rs.location.x) * width, ry = (1 - Double(rs.location.y)) * height
            let shoulderPx = ((lx - rx) * (lx - rx) + (ly - ry) * (ly - ry)).squareRoot()
            let midY = (ly + ry) / 2
            sample.shoulderWidth = shoulderPx / width
            sample.shoulderY = midY / height
            if let nose = try? body.recognizedPoint(.nose), nose.confidence >= 0.3, shoulderPx > 1 {
                let noseY = (1 - Double(nose.location.y)) * height
                sample.neckRatio = (midY - noseY) / shoulderPx
            }
        }
        return (sample, faces)
    }

    /// 3D 몸 자세 요청을 한 번 돌린다. Intel Mac에서는 뉴럴 엔진이 없어 실패할 수 있다.
    private static func run3D(_ pixels: CVPixelBuffer) -> String {
        let request = VNDetectHumanBodyPose3DRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up)
        let started = CFAbsoluteTimeGetCurrent()
        do {
            try handler.perform([request])
            let ms = Int((CFAbsoluteTimeGetCurrent() - started) * 1000)
            let count = request.results?.count ?? 0
            return count > 0
                ? "3D 몸 자세: 동작함 (사람 \(count)명, \(ms)ms). 알림에는 쓰지 않아요."
                : "3D 몸 자세: 오류는 없지만 사람을 찾지 못함 (\(ms)ms). 팔다리가 화면에 보여야 할 수 있어요."
        } catch {
            let e = error as NSError
            return "3D 몸 자세: 실패 (\(e.domain) Code=\(e.code)). 이 Mac에서는 쓰지 않아요."
        }
    }

    private static func degrees(_ radians: NSNumber?) -> Double? {
        radians.map { $0.doubleValue * 180 / .pi }
    }
}

/// 평소 자세를 저장할 때 얼굴이 화면에 잘 들어오는지 확인하는 미리보기 (좌우 반전).
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
