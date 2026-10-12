import AVFoundation
import CoreImage
import CoreMedia
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
    let pose: PosePoints?
    let analysisMs: Double
}

/// 미리보기에 그릴 골격 점. Vision 좌표 (0~1, 왼쪽 아래 원점, 좌우 반전 전 카메라 영상 기준).
struct PosePoints: Equatable, Sendable {
    enum Joint: CaseIterable, Sendable {
        case nose, leftEye, rightEye, leftEar, rightEar, neck, leftShoulder, rightShoulder

        var visionName: VNHumanBodyPoseObservation.JointName {
            switch self {
            case .nose: return .nose
            case .leftEye: return .leftEye
            case .rightEye: return .rightEye
            case .leftEar: return .leftEar
            case .rightEar: return .rightEar
            case .neck: return .neck
            case .leftShoulder: return .leftShoulder
            case .rightShoulder: return .rightShoulder
            }
        }
    }

    static let bones: [(Joint, Joint)] = [
        (.leftShoulder, .neck), (.neck, .rightShoulder), (.neck, .nose),
        (.leftEye, .rightEye), (.leftEye, .leftEar), (.rightEye, .rightEar),
    ]

    var points: [Joint: CGPoint]
    /// 얼굴 사각형
    var face: CGRect
}

/// FR-08: 카메라 프레임을 `analysisInterval`마다 한 장씩 Vision으로 분석해 얼굴과 골격(눈·어깨) 수치만 넘긴다.
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
    private var capFrameRate = true
    private var pendingThumbnails: [@MainActor (Data?) -> Void] = []
    private lazy var imageContext = CIContext()

    /// 사진 일지에 남기는 사진의 가로 픽셀
    static let thumbnailWidth: CGFloat = 320

    /// Info.plist에 카메라 사용 설명이 없으면 macOS가 접근 시 앱을 종료시킨다 (`swift run`으로 실행한 경우).
    static var canRequestAccess: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil
    }

    @MainActor
    func start(preferredID: String?, capFrameRate: Bool,
               completion: @escaping @MainActor (CameraStatus, CameraInfo?) -> Void) {
        guard Self.canRequestAccess else {
            completion(.unavailable("카메라는 build/SitCheck.app으로 실행할 때만 쓸 수 있어요"), nil)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run(preferredID: preferredID, capFrameRate: capFrameRate, completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.run(preferredID: preferredID, capFrameRate: capFrameRate, completion)
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

    /// 다음에 분석하는 프레임을 작은 JPEG로 넘긴다 (사진 일지). 얼굴이 없거나 다른 얼굴이 함께 잡히면 nil.
    func captureThumbnail(completion: @escaping @MainActor (Data?) -> Void) {
        queue.async { self.pendingThumbnails.append(completion) }
    }

    /// 카메라를 멈추면 기다리던 사진 요청은 사진 없이 끝낸다.
    private func failThumbnails() {
        let requests = pendingThumbnails
        pendingThumbnails = []
        for completion in requests { Task { @MainActor in completion(nil) } }
    }

    private func run(preferredID: String?, capFrameRate: Bool,
                     _ completion: @escaping @MainActor (CameraStatus, CameraInfo?) -> Void) {
        queue.async {
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
        // 좌우 판정은 반전하지 않은 영상(사용자의 왼쪽 = 화면 오른쪽)을 가정한다.
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
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
        let (sample, pose, faces) = analyze(pixels, at: now)
        let ms = (CFAbsoluteTimeGetCurrent() - started) * 1000

        if !pendingThumbnails.isEmpty {
            let requests = pendingThumbnails
            pendingThumbnails = []
            // 사용자 한 사람만 보일 때만 찍는다 (다른 사람이 함께 찍히지 않게).
            let data = faces == 1 ? ThumbnailEncoder.jpeg(from: pixels, width: Self.thumbnailWidth, context: imageContext) : nil
            for completion in requests { Task { @MainActor in completion(data) } }
        }

        let onFrame = self.onFrame
        let result = FrameResult(at: now, sample: sample, pose: pose, analysisMs: ms)
        Task { @MainActor in onFrame?(result) }
    }

    private static let minConfidence: Float = 0.2

    /// 프레임 하나를 분석한다. 찾은 얼굴 수도 함께 돌려준다.
    private func analyze(_ pixels: CVPixelBuffer, at now: Date) -> (PostureSample?, PosePoints?, Int) {
        let faceRequest = VNDetectFaceRectanglesRequest()
        // 리비전 3부터 roll·yaw·pitch가 연속값으로 나온다 (그 전에는 구간 값).
        faceRequest.revision = VNDetectFaceRectanglesRequestRevision3
        let bodyRequest = VNDetectHumanBodyPoseRequest()
        try? VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up).perform([faceRequest, bodyRequest])

        // 여러 얼굴이 잡히면 가장 큰(가까운) 얼굴을 사용자로 본다.
        let faces = faceRequest.results?.count ?? 0
        guard let face = faceRequest.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { return (nil, nil, faces) }
        let box = face.boundingBox
        let width = Double(CVPixelBufferGetWidth(pixels))
        let height = Double(CVPixelBufferGetHeight(pixels))
        // Vision 좌표는 왼쪽 아래가 원점이므로 y를 뒤집어 왼쪽 위 원점으로 맞춘다.
        var sample = PostureSample(at: now,
                                   roll: Self.degrees(face.roll), yaw: Self.degrees(face.yaw), pitch: Self.degrees(face.pitch),
                                   faceWidth: Double(box.width), faceX: Double(box.midX), faceY: 1 - Double(box.midY))

        // 여러 사람이 잡히면 어깨 폭이 가장 넓은(가까운) 사람을 사용자로 본다.
        let poses = (bodyRequest.results ?? []).map { Self.points(of: $0) }
        guard let pose = poses.max(by: { Self.shoulderSpan($0) < Self.shoulderSpan($1) }) else { return (sample, nil, faces) }
        if let ls = pose[.leftShoulder], let rs = pose[.rightShoulder] {
            let eyes = pose[.leftEye].flatMap { le in pose[.rightEye].map { (Self.pixel(le, width, height), Self.pixel($0, width, height)) } }
            BodyGeometry.apply(shoulders: (Self.pixel(ls, width, height), Self.pixel(rs, width, height)), eyes: eyes,
                               faceWidthPx: Double(box.width) * width, frameWidth: width, frameHeight: height,
                               to: &sample)
        }
        return (sample, PosePoints(points: pose, face: box), faces)
    }

    private static func points(of body: VNHumanBodyPoseObservation) -> [PosePoints.Joint: CGPoint] {
        var out: [PosePoints.Joint: CGPoint] = [:]
        for joint in PosePoints.Joint.allCases {
            if let p = try? body.recognizedPoint(joint.visionName), p.confidence >= minConfidence {
                out[joint] = p.location
            }
        }
        return out
    }

    private static func shoulderSpan(_ points: [PosePoints.Joint: CGPoint]) -> CGFloat {
        guard let l = points[.leftShoulder], let r = points[.rightShoulder] else { return 0 }
        return abs(l.x - r.x)
    }

    private static func pixel(_ p: CGPoint, _ width: Double, _ height: Double) -> PixelPoint {
        PixelPoint(x: Double(p.x) * width, y: Double(p.y) * height)
    }

    private static func degrees(_ radians: NSNumber?) -> Double? {
        radians.map { $0.doubleValue * 180 / .pi }
    }
}

/// 카메라 미리보기 위에 인식한 골격을 겹쳐 그린다. 영상은 4:3 (VGA)이고 거울처럼 좌우 반전해 보여 준다.
struct SkeletonPreview: View {
    let session: AVCaptureSession
    let pose: PosePoints?

    var body: some View {
        CameraPreview(session: session)
            .overlay {
                Canvas { context, size in
                    guard let pose else { return }
                    // Vision 좌표(왼쪽 아래 원점)를 거울 화면 좌표(왼쪽 위 원점)로 바꾼다.
                    func view(_ p: CGPoint) -> CGPoint {
                        CGPoint(x: (1 - p.x) * size.width, y: (1 - p.y) * size.height)
                    }
                    let f = pose.face
                    let faceRect = CGRect(x: (1 - f.maxX) * size.width, y: (1 - f.maxY) * size.height,
                                          width: f.width * size.width, height: f.height * size.height)
                    context.stroke(Path(roundedRect: faceRect, cornerRadius: 6), with: .color(.white.opacity(0.6)), lineWidth: 1)
                    var bones = Path()
                    for (a, b) in PosePoints.bones {
                        guard let pa = pose.points[a], let pb = pose.points[b] else { continue }
                        bones.move(to: view(pa))
                        bones.addLine(to: view(pb))
                    }
                    context.stroke(bones, with: .color(.green), lineWidth: 2)
                    for p in pose.points.values {
                        let c = view(p)
                        context.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(.yellow))
                    }
                }
            }
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
    }
}

/// 카메라에 얼굴이 잘 들어오는지 확인하는 미리보기 (좌우 반전).
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
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
