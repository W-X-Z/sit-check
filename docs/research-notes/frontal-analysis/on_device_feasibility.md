# On-device feasibility of richer CV/ML posture models on an Intel x86_64 iMac (macOS 14 Sonoma, Swift menu-bar app, swiftc-only build)

Researched 2026-10-12. Scope: what can run fully locally on an Intel iMac (no Neural Engine), at about 1 analyzed frame per second within a few percent of one CPU core, built with `swiftc` + Command Line Tools (no SwiftPM, no Xcode assumed).

How to read this file:
- **Measured**: a number someone actually benchmarked (the device is always named).
- **Apple-silicon-only**: the only published number is from M-series or iPhone hardware. It does not transfer to Intel.
- **Estimate**: my own back-of-envelope reasoning. It is never cited as a source.
- **Budget arithmetic used throughout**: "a few % of one core" at 1 frame/s works out to about **20–50 ms of single-core CPU time per analyzed frame**, including pre- and post-processing. A model run once per minute can use about 60× that per run (about 1.2–3 s single-core) for the same average budget.

Access limits during research: huggingface.co, onnxruntime.ai, support.apple.com, wikipedia.org, cdn.jsdelivr.net and docs.ultralytics.com were blocked by this session's egress policy. Facts from those sites come from search-result summaries, which are flagged as such, or are listed under Gaps. Apple developer docs (JSON), GitHub pages, PyPI metadata and the MediaPipe wheels were read directly.

---

## Q1. Apple frameworks on Intel Macs (no Neural Engine): which Vision requests exist on macOS 14 and what do they cost; Core ML compute units on Intel; Create ML / MLUpdateTask

### Takeaway
Every Vision request named in the brief is in the macOS 14 SDK. All of them run on-device with zero dependencies from a `swiftc`-built app, which makes them the cheapest integration path. The exception is `VNDetectHumanBodyPose3DRequest`, which may not run on Intel at all: an accepted forum answer says it "requires a device with a neural engine (but may work on some Intel Mac devices)". No published per-frame timing exists for any Vision request on an Intel Mac, so per-request cost on the target iMac must be measured. On Intel, Core ML can only use the CPU or the Metal GPU (AMD Radeon or Intel iGPU). Apple itself recommends `cpuOnly` for background-style apps.

### Cited Findings
**Vision request availability (Apple doc metadata, read directly):**
- `VNDetectHumanBodyPoseRequest`: macOS 11.0+. It returns a `VNHumanBodyPoseObservation` (2D) — [Apple docs](https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest)
- `VNDetectHumanBodyPose3DRequest`: macOS 14.0+ / iOS 17. It "detects points on human bodies in 3D space, relative to the camera", and "if the system allows it, the request uses AVDepthData information to improve the accuracy" — [Apple docs](https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest)
  - 3D pose returns a **17-joint** skeleton in meters relative to a root joint, for **one** (the most prominent) person. `bodyHeight` is either a measured height (when depth exists) or a **reference height of 1.8 m**. `cameraOriginMatrix` gives the camera position relative to the person, and `pointInImage` projects back to 2D — [WWDC23 "Explore 3D body pose and person segmentation in Vision"](https://developer.apple.com/videos/play/wwdc2023/111241/)
  - **Intel support is uncertain.** The accepted answer (by user "visionframeworkdev", affiliation not shown) to a Dec 2023 thread about the error "VNDetectHumanBodyPose3DRequest does not support VNDetectHumanBodyPose3DRequestRevision1" reads: "This request is not supported on simulator, and requires a device with a neural engine (but may work on some Intel Mac devices)" — [Apple Developer Forums 743402](https://developer.apple.com/forums/thread/743402)
  - The Swift-only successor `DetectHumanBodyPose3DRequest` requires macOS 15 (so it is not usable on Sonoma). It takes a `frameAnalysisSpacing: CMTime?` parameter (per search summary of the doc page) — [Apple docs](https://developer.apple.com/documentation/vision/detecthumanbodypose3drequest)
- `VNDetectFaceLandmarksRequest`: macOS 10.13+ — [Apple docs](https://developer.apple.com/documentation/vision/vndetectfacelandmarksrequest). Revision 3 offers a **76-point** constellation with pupil detection. Face detector revision 3 adds a **pitch** metric, and roll/yaw/pitch are now reported "in continuous space" (useful for head pitch, i.e. forward-head posture) — [WWDC21 "Detect people, faces, and poses using Vision"](https://developer.apple.com/videos/play/wwdc2021/10040/)
- `VNGeneratePersonSegmentationRequest`: macOS 12.0+, returns a matte in a `VNPixelBufferObservation` — [Apple docs](https://developer.apple.com/documentation/vision/vngeneratepersonsegmentationrequest). It has three quality levels, `accurate` (default), `balanced` and `fast`. Apple recommends accurate for computational photography, balanced for "video frame-by-frame segmentation" and fast "for streaming processing". Reusing the request object across frames smooths temporal changes at the fast level — [WWDC21 10040](https://developer.apple.com/videos/play/wwdc2021/10040/)
- `VNGenerateForegroundInstanceMaskRequest`: macOS 14.0+, "generates an instance mask of noticable objects to separate from the background" (subject lifting) — [Apple docs](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest); [WWDC23 "Lift subjects from images"](https://developer.apple.com/videos/play/wwdc2023/10176/). Vision's newer person instance segmentation can "segment up to four individuals" — [WWDC23 111241](https://developer.apple.com/videos/play/wwdc2023/111241/)
- `VNGenerateImageFeaturePrintRequest`: macOS 10.15+ — [Apple docs](https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequest). **Revision 2** (`VNGenerateImageFeaturePrintRequestRevision2`) is macOS 14.0+ — [Apple docs](https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequestrevision2). The vector length is exposed at runtime via `VNFeaturePrintObservation.elementCount` / `elementType` — [Apple docs](https://developer.apple.com/documentation/vision/vnfeatureprintobservation/data). The default crop/scale option is `scaleFill` — [Apple docs](https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequest/imagecropandscaleoption). A July 2023 forum report says revision changes after WWDC23 broke `computeDistance` between prints made with different revisions. So pin the revision explicitly (per search summary) — [Apple forums, visionkit tag](https://developer.apple.com/forums/tags/visionkit?page=6)
- `regionOfInterest` (normalized rect, lower-left origin) lets any image-based Vision request process only a crop: macOS 10.13+ — [Apple docs](https://developer.apple.com/documentation/vision/vnimagebasedrequest/regionofinterest)
- macOS 14 adds per-request compute device control. `setComputeDevice(_:for:)` assigns a compute device per compute stage, and `supportedComputeStageDevices` lists the valid devices (both macOS 14.0+) — [Apple docs](https://developer.apple.com/documentation/vision/vnrequest/setcomputedevice(_:for:)); [Apple docs](https://developer.apple.com/documentation/vision/vnrequest/supportedcomputestagedevices)
- Apple's position: "All Vision Framework requests are on device" (forum response, per search summary) — [Apple forums 799529](https://developer.apple.com/forums/thread/799529)
- **No published ms/frame for Vision body pose on Intel Macs** was found. The only timing anecdote is from Apple silicon: an M1 Max took 7+ hours on a 1-hour 4K60 video with a body-pose action classifier — [Apple forums 697434](https://developer.apple.com/forums/thread/697434)

**Core ML compute units on Intel:**
- `MLComputeUnits.all` lets "the OS select the best processing unit to use (including the neural engine, if available)". Apple adds: "Use cpuOnly to restrict the model to the CPU, if your app might run in the background or runs other GPU intensive tasks" — [Apple docs](https://developer.apple.com/documentation/coreml/mlcomputeunits)
- `cpuAndGPU` (macOS 10.14+) uses the CPU and GPU but not the ANE — [Apple docs](https://developer.apple.com/documentation/coreml/mlcomputeunits/cpuandgpu). `cpuAndNeuralEngine` is macOS 13+ — [Apple docs](https://developer.apple.com/documentation/coreml/mlcomputeunits/cpuandneuralengine)
- `MLModelConfiguration.preferredMetalDevice` (macOS 10.15+) chooses which Metal device (e.g. AMD dGPU vs Intel iGPU) to use. `nil` means Core ML chooses — [Apple docs](https://developer.apple.com/documentation/coreml/mlmodelconfiguration/preferredmetaldevice)
- `allowLowPrecisionAccumulationOnGPU` (macOS 10.15+) trades GPU precision for speed — [Apple docs](https://developer.apple.com/documentation/coreml/mlmodelconfiguration/allowlowprecisionaccumulationongpu). A community note says the GPU path stores fp16 but accumulates in fp32 by default — [neural-engine docs (community)](https://github.com/michaelbernstein/neural-engine/blob/master/docs/16-bit.md)
- macOS 14 / iOS 17 added `MLModel.availableComputeDevices` / `MLComputeDevice` for runtime inspection, e.g. to check whether a Neural Engine exists — [WWDC23 "Improve Core ML integration with async prediction"](https://developer.apple.com/videos/play/wwdc2023/10049/)
- Community reports from Intel-era Macs: small Core ML models can run **faster on CPU than GPU** — [Apple forums 99210](https://developer.apple.com/forums/thread/99210). A 2019 Mac Pro with AMD Vega II Duo gave noticeably different numeric results on CPU vs GPU — [Apple forums 130960](https://developer.apple.com/forums/thread/130960)

**Create ML / on-device training:**
- The Create ML framework is available on macOS 10.14+ for training models "on your Mac" — [Apple docs](https://developer.apple.com/documentation/createml). `MLImageClassifier` is macOS 10.14+ — [Apple docs](https://developer.apple.com/documentation/createml/mlimageclassifier)
- `MLUpdateTask` (macOS 10.15+) "updates a model with additional training data" on the user's device — [Apple docs](https://developer.apple.com/documentation/coreml/mlupdatetask). It needs a model whose `isUpdatable` is true — [Apple docs](https://developer.apple.com/documentation/coreml/mlmodeldescription/isupdatable). Apple's sample personalizes an updatable drawing classifier with user samples via `MLArrayBatchProvider` — [Apple sample](https://developer.apple.com/documentation/coreml/personalizing-a-model-with-on-device-updates). The gallery ships `UpdatableDrawingClassifier.mlmodel` (382 KB) — [Apple Core ML Models](https://developer.apple.com/machine-learning/models/)

### Inferences
- On an Intel iMac, `.all` effectively means CPU+GPU, because there is no ANE. For a 1 Hz menu-bar workload, `cpuOnly` is the predictable choice (Apple's own guidance for background apps). Waking a discrete AMD GPU once per second may cost more energy than it saves in CPU time. This is unmeasured; see Gaps.
- The 2D body pose, face rectangles/landmarks (with continuous pitch/yaw/roll) and person segmentation at `fast`/`balanced` are the likely "free" upgrades on Intel. Run them only on a `regionOfInterest` around the upper body.
- Treat 3D body pose as **optional with a runtime probe**. Call `perform` once at startup, catch the "does not support Revision1" error, and fall back. Even when it runs, the 1.8 m reference height means absolute metric depth is not trustworthy without AVDepthData, which the FaceTime HD camera does not provide.
- Feature prints suit "is this frame similar to my calibrated good-posture frame?" (a personal baseline via distance). For personalization, a cheaper path than `MLUpdateTask` (which needs NeuralNetwork-format updatable models) is a tiny classifier trained in-process on keypoint or feature-print vectors. That can be Create ML tabular or logistic regression, or hand-rolled Swift. This is an inference; Create ML tabular APIs were not individually verified.

### Gaps
- No measured ms/frame or CPU % for any Vision request on Intel Macs (body pose, face landmarks, segmentation, feature print, instance mask). This must be benchmarked on the target iMac, e.g. by timing `perform` and sampling process CPU.
- Whether `VNDetectHumanBodyPose3DRequest` and `VNGenerateForegroundInstanceMaskRequest` actually execute on Intel hardware (and on which compute device) is unconfirmed.
- Feature print vector size per revision: I could not verify the commonly repeated "rev 1 = 2048 floats, rev 2 = 768 floats" claim from a primary source. Read `elementCount` at runtime.
- Which Intel iMac GPUs Core ML actually selects, and the relative energy of CPU vs AMD GPU at 1 Hz, are unknown.

---

## Q2. MediaPipe on macOS from a native Swift app (Pose Landmarker, Face Landmarker 478 pts + transformation matrix, Selfie Segmenter)

### Takeaway
As of Oct 2026, **no officially supported MediaPipe path exists for a native Intel macOS Swift app**. The Swift/Obj-C Tasks SDK is iOS-only and CocoaPods-distributed. The Python wheels stopped shipping macOS x86_64 builds after 0.10.21 (Feb 2025). The new C API library inside the wheels (`libmediapipe.dylib`) ships **arm64-only** for macOS. On Intel, the options are building the C API from source with Bazel (unverified, high effort) or bundling an old 0.10.21 Python runtime (fragile, frozen).

### Cited Findings
- The iOS Pose Landmarker guide uses Swift (`PoseLandmarker(options:)`) and requires installing `MediaPipeTasksVision` **via CocoaPods** — [Google AI Edge iOS pose guide](https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker/ios?hl=ja). On iOS, "MediaPipe Tasks only supports running models on standard CPU processors" (per search summary) — [MediaPipe iOS setup](https://developers.google.com/edge/mediapipe/solutions/setup_ios)
- The `MediaPipeTasksVision` podspec template sets only `s.ios.deployment_target = '15.0'`, with **no osx platform**. It vendors `MediaPipeTasksVision.xcframework` as a static framework linking `c++` — [GitHub podspec template](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/tasks/ios/MediaPipeTasksVision.podspec.template). The CocoaPods trunk lists versions up to **1.0.0** (read from the CocoaPods index during this research) — [CocoaPods CDN index](https://cdn.cocoapods.org/)
- An iOS Swift Package Manager request was still open in mid-2024 (per search summary) — [MediaPipe issues](https://redirect.github.com/google-ai-edge/mediapipe/issues)
- **PyPI wheel history (read from PyPI JSON):** 0.10.21 (2025-02-06) shipped `macosx_11_0_x86_64` and `universal2` wheels for cp39–cp312. Every release from **0.10.30 (2025-12-16) through 1.1.0 (2026-10-06)** ships exactly one macOS wheel, `py3-none-macosx_11_0_arm64`. The license is Apache 2.0 — [PyPI mediapipe JSON](https://pypi.org/pypi/mediapipe/json)
- **Wheel contents (inspected directly):**
  - The 1.1.0 macOS wheel contains `mediapipe/tasks/c/libmediapipe.dylib` (129.3 MB, `Mach-O 64-bit arm64`). Its Python layer calls C functions via ctypes (`MpPoseLandmarkerCreate`, `MpPoseLandmarkerDetectImage`, `MpPoseLandmarkerDetectForVideo`, `MpPoseLandmarkerClose`, …), and the dylib also contains Face/Hand landmarker entry points. No `.h` headers are shipped in the wheel — [mediapipe-1.1.0 macOS wheel](https://files.pythonhosted.org/packages/e0/7c/e5e1b0fd0a43a8f71db9062c94731a3de196186d392ce0c4417d7923a1a0/mediapipe-1.1.0-py3-none-macosx_11_0_arm64.whl)
  - The 0.10.21 x86_64 wheel uses a pybind module, `_framework_bindings.cpython-311-darwin.so` (75.6 MB). It bundles legacy models such as `pose_landmark_full.tflite` (6.4 MB), `pose_detection.tflite` (3.0 MB), `face_landmark_with_attention.tflite` (2.5 MB) and `face_landmark.tflite` (1.2 MB) — [mediapipe-0.10.21 cp311 x86_64 wheel](https://files.pythonhosted.org/packages/c5/78/b1bd10f9941eb5853a669d4a72d96010b43c45a8241a90a3c017c543697b/mediapipe-0.10.21-cp311-cp311-macosx_11_0_x86_64.whl)
- The C API source tree has `mediapipe/tasks/c/vision/{face_landmarker, pose_landmarker, image_segmenter, image_embedder, holistic_landmarker, face_detector, hand_landmarker, …}` with Bazel `BUILD` files. No README with platform support was found — [GitHub tasks/c/vision](https://github.com/google-ai-edge/mediapipe/tree/master/mediapipe/tasks/c/vision)
- A macOS 15.5 issue reports the same pose frame rate on CPU and GPU delegates (per search summary) — [MediaPipe issue 6041](https://github.com/google-ai-edge/mediapipe/issues/6041). Another issue title reports that Pose `detect_for_video` with the GPU delegate crashes on Mac when segmentation is enabled (per CodeTriage summary) — [CodeTriage mediapipe](https://codetriage.com/google/mediapipe)
- The wider ecosystem is dropping Intel Mac binaries. PyTorch stopped macOS x86_64 builds after 2.2 (Jan 2024) — [PyTorch dev-discuss](https://dev-discuss.pytorch.org/t/pytorch-macos-x86-builds-deprecation-starting-january-2024/1690.md). Ray dropped them from 2.49 — [Ray discuss](https://discuss.ray.io/t/deprecation-notice-macos-x86-64-wheels/22939)

### Inferences
- From Swift on Intel, the only practical MediaPipe routes are:
  - (a) **Bazel-build `libmediapipe.dylib` for x86_64** and call the C API through a hand-written header and module map from `swiftc`. This is high effort, and the build compatibility on x86_64 macOS with current Bazel/toolchains is unverified.
  - (b) **Spawn a pinned Python 0.10.21** helper process. This adds a Python runtime dependency, is frozen at Feb 2025, and conflicts with the "no Python at runtime" constraint.
  - (c) **Port the `.tflite` models** (e.g. the face landmark / pose landmark models) to Core ML or ONNX yourself. That loses MediaPipe's graph logic (ROI tracking, 478-pt refinement, transformation-matrix solver), which would have to be reimplemented.
  - None of these is a "small" integration. Vision's built-in face pose (continuous pitch/yaw/roll) and 2D body pose already cover most of what the Face Landmarker transformation matrix and Pose Landmarker would add for a sitting-posture app.
- Supporting evidence for MediaPipe's 478-point/52-blendshape/transformation-matrix outputs and per-device latency tables could not be fetched (developers.google.com and ai.google.dev were unreachable).

### Gaps
- No Intel-CPU latency numbers for MediaPipe Pose/Face Landmarker or Selfie Segmenter were found.
- Whether the C API builds cleanly for `darwin_x86_64` with current Bazel is unknown.
- The official Face Landmarker model card details (478 landmarks, blendshapes, facial transformation matrix, model sizes) could not be retrieved this session (Google docs domains blocked).

---

## Q3. Converting/running open models (Core ML Tools / ONNX Runtime) on Intel macOS: depth, pose, embeddings, small VLMs — latency at 1 frame/min vs 1 frame/s

### Takeaway
The runtimes still exist for Intel, but the window is closing. **coremltools 9.0** still ships macOS x86_64 wheels, so conversion is fine. **ONNX Runtime dropped macOS x86_64 binaries in 1.24 (Feb 2026)**, so 1.23.2 (Oct 2025) is the last official Intel build. **No benchmark found anywhere measures any of these models on an Intel Mac.** The closest x86 data is RTMPose on an i7-11700 (3–25 ms) and YOLO26-pose on a cloud Xeon (≥40 ms at 640 px). By measured x86 numbers, small top-down pose models (RTMPose-t/s) fit a 1 fps budget. By estimate, Depth Anything V2 Small, DINOv2-S and similar ViTs fit only at once-per-minute cadence and/or reduced resolution. VLMs (≥256M params) only fit occasional (≤1/min) use, and 3B-class VLMs are unsuitable for a menu-bar app.

### Cited Findings
**Runtimes on Intel macOS:**
- ONNX Runtime 1.23.0 release notes: "The next release will stop providing x86_64 binaries for macOS and iOS" and will raise the minimum macOS from 13.4 to 14.0 — [newreleases ORT 1.23.0](https://newreleases.io/project/pypi/onnxruntime/release/1.23.0). 1.24.1 confirms x86_64 macOS/iOS binaries are no longer provided — [newreleases ORT 1.24.1](https://newreleases.io/project/pypi/onnxruntime/release/1.24.1)
- PyPI confirms the change. 1.23.0–1.23.2 (Sep–Oct 2025) shipped `macosx_13_0_x86_64` wheels. 1.24.1 through **1.31.0 (2026-10-09)** ship only `macosx_14_0_arm64` — [PyPI onnxruntime JSON](https://pypi.org/pypi/onnxruntime/json)
- The ORT CoreML Execution Provider requires macOS 10.15+, recommends devices with the Apple Neural Engine for best performance, and takes an `MLComputeUnits` option (per search summary) — [ORT CoreML EP docs](https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html). The v1.31.0 notes say GPU selection requires macOS 12+ — [newreleases ORT v1.31.0](https://newreleases.io/project/github/microsoft/onnxruntime/release/v1.31.0)
- coremltools **9.0** (2025-11-10) ships `macosx_10_15_x86_64` wheels for cp37–cp313 alongside arm64 — [PyPI coremltools JSON](https://pypi.org/pypi/coremltools/json)

**Pose models (x86 CPU numbers exist):**
- **Measured, x86 desktop CPU.** RTMPose ONNX Runtime latency on an Intel **i7-11700**, 256×192 input: RTMPose-t 3.20 ms (3.34M params, 0.36 GFLOPs, 68.5 AP); RTMPose-s 4.48 ms (5.47M, 0.68 GFLOPs, 72.2 AP); RTMPose-m 11.06 ms (13.59M, 1.93 GFLOPs, 75.8 AP); RTMPose-l 18.85 ms (27.66M, 4.16 GFLOPs). RTMPose-m at 384×288 takes 24.78 ms — [mmpose RTMPose README](https://github.com/open-mmlab/mmpose/tree/main/projects/rtmpose). The paper reports "90+ FPS on an Intel i7-11700 CPU" for RTMPose-m — [arXiv 2303.07399](https://arxiv.org/abs/2303.07399). The Chinese README lists RTMPose-m at 13.50 ms on the same CPU, about 20% different (per search summary) — [mmpose benchmark mirror](https://cdn05042023.gitlink.org.cn/OpenMMLab/mmpose/src/branch/main/projects/rtmpose/benchmark/README_CN.md)
- RTMW whole-body (133 kpts): RTMW-m 256×192 is 4.3 GFLOPs (58.2 whole AP), RTMW-l is 7.9 GFLOPs (66.0 AP). No latency is published — [mmpose RTMPose README](https://github.com/open-mmlab/mmpose/tree/main/projects/rtmpose)
- RTMPose can be deployed without PyTorch via `rtmlib` (OpenCV/ONNX Runtime/OpenVINO) or exported to `end2end.onnx` via MMDeploy — [mmpose RTMPose README](https://github.com/open-mmlab/mmpose/tree/main/projects/rtmpose)
- **Measured, cloud Xeon CPU.** Ultralytics YOLO26-pose at 640 px, CPU ONNX: n 40.3 ms (2.9M params, 7.6 GFLOPs, 57.2 mAP), s 85.3 ms, m 218 ms, l 275 ms, x 565 ms. These were measured on an Amazon EC2 P4d instance (CPU model not stated for the pose table) — [Ultralytics GitHub README](https://github.com/ultralytics/ultralytics)

**Depth models (Apple-silicon-only or GPU numbers):**
- Depth Anything V2 sizes: Small 24.8M, Base 97.5M, Large 335.3M, Giant 1.3B params — [Depth-Anything-V2 GitHub](https://github.com/DepthAnything/Depth-Anything-V2). Community ONNX port: [fabio-sim/Depth-Anything-ONNX](https://github.com/fabio-sim/Depth-Anything-ONNX) (listed in the same README)
- **Apple-silicon-only.** Apple's Core ML Depth Anything V2 Small F16: iPhone 16 Pro 26.21 ms, iPhone 15 Pro Max 33.90 ms, MacBook Pro M1 Max 33.48 ms (compute "All") and 32.78 ms (GPU) — [Apple Core ML Models](https://developer.apple.com/machine-learning/models/). The HF card adds M3 Max 24.58 ms and iPhone 12 Pro Max 31.10 ms, with the Neural Engine as the dominant unit. F16 abs-rel error vs the PyTorch reference is 0.0089, against 0.0072 for F32 (per search summary; HF not directly reachable) — [HF apple/coreml-depth-anything-v2-small](https://huggingface.co/apple/coreml-depth-anything-v2-small)
- **Depth Pro.** "2.25-megapixel depth map in 0.3 seconds on a standard GPU" (GPU unnamed) — [apple/ml-depth-pro](https://github.com/apple/ml-depth-pro). One HF Spaces user reports CPU inference ">200 secs" (anecdotal) — [HF discussion](https://www.huggingface.co/spaces/lightly-ai/ml-depth-pro/discussions/1). A community Core ML conversion reports about 4.8 s/frame fp16 and 3.6 s for 6-bit palettized (1.8 GB fp16) on fanless Apple silicon (per search summary) — [HF mickeyvanolst/depthpro-coreml](https://huggingface.co/mickeyvanolst/depthpro-coreml)

**Embeddings:**
- DINOv2 ViT-S/14 (distilled) has 21M params, with a with-registers variant (`dinov2_vits14_reg`) — [facebookresearch/dinov2](https://github.com/facebookresearch/dinov2)

**Small VLMs (no CPU numbers found):**
- SmolVLM paper: throughput is reported only on A100/L4 GPUs. The 256M model runs in-browser via WebGPU at up to 80 decode tok/s on an M4 Max MacBook Pro — [SmolVLM arXiv 2504.05299](https://arxiv.org/pdf/2504.05299)
- Moondream: CPU runs use float32 (CUDA/MPS use float16) — [Pipecat Moondream docs](https://docs.pipecat.ai/server/services/vision/moondream). No x86 per-image latency was found. Recent Moondream "Photon" releases target Apple silicon, Windows x86_64+CUDA and NVIDIA — [Moondream blog](https://moondream.ai/blog/photon-1-2-0-update)
- No credible Intel-Mac or x86-CPU benchmarks were found for Qwen2.5-VL-3B, LLaVA, SmolVLM or Moondream. llama.cpp search results were Apple-silicon-centric SEO pages (low quality) — [example](https://aiindigo.com/blog/the-local-llm-power-user-s-guide-to-llama-cpp-on-apple-silicon)

### Inferences
- **Estimate: scaling i7-11700 numbers to Intel iMacs.** The 2019 iMac's 6-core i5 (no SMT, AVX2, no AVX-512) and the 2020 27" i5/i7 (10th gen, AVX2) are probably 1.3–3× slower per inference than an i7-11700 under multi-threaded ORT. That puts RTMPose-s at about 6–15 ms, i.e. inside a 1 fps budget when given a person crop. The crop would come from Vision's body/face rectangle, since RTMPose is top-down and needs a detector.
- **Estimate: YOLO26n-pose at 640 px** (≈40 ms on a Xeon) is borderline at 1 fps. At 320 px the cost should drop about 4× (FLOPs scale with pixel count), but it duplicates what Vision 2D body pose already gives for free. Its **AGPL-3.0 license** (Q6) is the bigger blocker.
- **Estimate: Depth Anything V2 Small at its native 518×518.** That is about 1,369 ViT-S tokens. ViT-S encoder plus attention is roughly 45 GMACs (~90 GFLOPs) before the DPT head. At a realistic 50–200 effective GFLOPS on a 6-core AVX2 CPU, that implies roughly 0.5–2 s per frame. That is **not** affordable at 1 fps, but averages to about 1–3% of one core at **once per minute**. Lowering the input to about 252–266 px cuts tokens about 4× (and attention cost about 16×), probably to a few hundred ms. Relative depth from a single 720p webcam frame is only useful for coarse cues (head/torso distance trend). This must be verified by measurement.
- **Depth Pro** is unaffordable on Intel CPUs even once per minute (multi-second to minutes per frame per the reports above, and GB-scale weights).
- **DINOv2-S / CLIP ViT-B embeddings at 224 px** (256 tokens for ViT-S/14) are estimated at about 4–6 GFLOPs for ViT-S, i.e. roughly tens of ms on CPU. That is plausible at 1 fps but redundant with Vision feature prints, which are free and built in.
- **VLMs.** The 256M–500M models are estimated at seconds per image on an x86 CPU (vision encoder plus tens of decoded tokens), with RAM of several hundred MB to ~1 GB. They are only conceivable at ≤1/min or on demand. 3B-class models (Qwen2.5-VL-3B, LLaVA) would take multiple GB of RAM and tens of seconds per image on CPU, which is unsuitable for a background menu-bar app. All of this is estimated, not measured.
- **Runtime choice.** Prefer converting to Core ML (`.mlpackage` → `.mlmodelc`) and running via `MLModel`/`VNCoreMLRequest`. That avoids shipping a third-party dylib frozen at ORT 1.23.2. ORT 1.23.2 x86_64 remains a fallback if a model will not convert.

### Gaps
- No measured latency on any Intel Mac (CPU or AMD GPU) for Depth Anything V2, MiDaS, RTMPose, ViTPose-S, DINOv2-S, CLIP, or any VLM.
- No data found for **MiDaS small** or **ViTPose-S** (latency, size, license); not researched in depth this session.
- Whether ORT's prebuilt macOS x86_64 1.23.x native packages (not just Python wheels) include the CoreML EP was not verified (onnxruntime.ai blocked).
- Whether ORT CoreML EP or Core ML itself is faster on AMD Radeon GPUs than on CPU for these models is unknown.

---

## Q4. Apple's Core ML model gallery: which models exist and which have Intel-compatible (non-ANE-only) variants

### Takeaway
Apple's gallery has no ANE-only models. Every listed model is a standard `.mlpackage` or `.mlmodel` with Float16 or Float32 weights, which Core ML can run on CPU/GPU. However, **every published latency is from iPhones or M-series Macs**. The posture-relevant entries are **Depth Anything V2 Small** (F16 49.8 MB; 6-bit palettized 19 MB), **FastViT** (T8 is tiny: 3.6M params, 8.2 MB), **DETR-ResNet50 semantic segmentation** and **DeepLabV3** (person segmentation alternatives, but Vision's built-in person segmentation is cheaper to integrate).

### Cited Findings
All of the following come from [Apple Core ML Models](https://developer.apple.com/machine-learning/models/), read directly:
- **FastViT**: T8 has 3.6M params (`FastViTT8F16.mlpackage` 8.2 MB; headless 6.5 MB); MA36 has 42.7M (88.3 MB). Measured T8 F16 is 0.62 ms on MacBook Pro M3 Max and MA36 F16 is 2.94 ms on M2 Max (compute "All").
- **Depth Anything V2 Small**: 24.8M params. `DepthAnythingV2SmallF16.mlpackage` is 49.8 MB and `DepthAnythingV2SmallF16P6.mlpackage` (6-bit palettized) is 19 MB. F32 is 99.2 MB. Measured M1 Max: 33.48 ms (All), 32.78 ms (GPU).
- **DETR ResNet50 Semantic Segmentation**: 43M params, F16 85.5 MB, F16P8 43.1 MB. Measured M1 Max F16: **117 ms with "All" vs 43 ms on GPU**. On a 4th-gen iPad Pro, F16P8 took 1224 ms.
- **DeepLabV3**: 8.6 MB (FP32) / 4.3 MB (FP16) / 2.3 MB (Int8 LUT). **MobileNetV2**: 24.7 / 12.4 / 6.3 MB. **ResNet-50**: 102.6 / 51.3 / 25.8 MB (plus a headless 94.4 MB). **YOLOv3**: 248.4 MB (Tiny FP16 17.7 MB). Also listed: BERT-SQuAD, MNIST, and UpdatableDrawingClassifier (382 KB).
- Depth Anything's own README notes the 2024-06-25 integration into Apple Core ML Models — [Depth-Anything-V2 GitHub](https://github.com/DepthAnything/Depth-Anything-V2)

### Inferences
- The DETR numbers show that "All" is not always fastest even on Apple silicon (117 ms vs 43 ms on GPU). On Intel, every compute-unit setting must be benchmarked (`cpuOnly` vs `cpuAndGPU`).
- Palettized (P6/P8) and Int8-LUT variants mainly reduce disk/RAM. On CPU they are typically decompressed to fp16/fp32, so they should not be expected to be faster on Intel (inference, unverified).
- FastViT-T8 headless (6.5 MB) is a cheap generic embedding backbone. It is a possible alternative to Vision feature prints for a personal "good vs bad posture" classifier head, but Vision feature prints need zero model shipping.

### Gaps
- Apple publishes no Intel-Mac timings for any gallery model.
- Whether ML Program (`.mlpackage`) fp16 models execute in fp32 on Intel CPUs (and the resulting speed/accuracy) is not confirmed from a primary source this session.
- The minimum macOS version per gallery model (ML Program packages generally need macOS 12+) was not confirmed per model.

---

## Q5. Build/toolchain constraints: swiftc + Command Line Tools only (no Xcode, no SwiftPM); shipping compiled models

### Takeaway
Vision and Core ML need no third-party dependencies, which suits a `swiftc` build. Core ML models do **not** require Xcode at runtime. The app can call `MLModel.compileModel(at:)` (macOS 10.13+) on first launch and cache the resulting `.mlmodelc`, or a CI macOS runner with Xcode can produce the `.mlmodelc` ahead of time with `xcrun coremlcompiler compile`. MediaPipe (CocoaPods/Bazel/Python) and ORT ≥1.24 (arm64-only) are the dependencies that break the constraints.

### Cited Findings
- `MLModel.compileModel(at:)` "compiles a model on the device", producing an `.mlmodelc` (macOS 10.13+; async variant macOS 13+). Apple says compiling "can be time consuming and shouldn't be done on the main thread" — [Apple docs](https://developer.apple.com/documentation/coreml/mlmodel/compilemodel(at:)-6442s). Apple also says to "save the compiled model to a permanent location" because it is otherwise written to a temporary location — [Apple docs: Downloading and Compiling a Model on the User's Device](https://developer.apple.com/documentation/coreml/downloading-and-compiling-a-model-on-the-user-s-device)
- Offline compile command: `xcrun coremlcompiler compile MyModel.mlmodel /path/to/output/` produces `.mlmodelc` — [Apple forums 750161](https://developer.apple.com/forums/thread/750161); [Apple forums 718136](https://developer.apple.com/forums/thread/718136). The tool is described as coming from Xcode's toolchain (per search summary) — [levelup article](https://levelup.gitconnected.com/how-to-include-a-core-ml-model-in-a-swift-package-88c44c1e1403)
- Source vs compiled assets: `.mlmodel`/`.mlpackage` are open source formats, while `.mlmodelc` is "designed for runtime access". Apple advises not loading models on the UI thread at launch, using async/lazy loading, and keeping a model loaded if it will be reused. First (uncached) loads are expensive — [WWDC23 10049](https://developer.apple.com/videos/play/wwdc2023/10049/)
- MediaPipe's Swift SDK is CocoaPods-only and iOS-only, Intel Python wheels stopped at 0.10.21, and the macOS C API dylib is arm64-only (see Q2) — [podspec template](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/tasks/ios/MediaPipeTasksVision.podspec.template); [PyPI mediapipe JSON](https://pypi.org/pypi/mediapipe/json)
- GitHub-hosted macOS 13 runners are being retired, and the macOS 15 **Intel** runner becomes unavailable in **August 2027** (per a pygit2 PR, via search summary) — [pygit2 PR 1441](https://github.com/libgit2/pygit2/pull/1441)

### Inferences
- **Recommended Core ML packaging under swiftc:**
  - (1) Convert in CI with coremltools (x86_64 or arm64 runner) to `.mlpackage`.
  - (2) Either compile to `.mlmodelc` in CI with `xcrun coremlcompiler` and copy it into `Contents/Resources`, or ship the `.mlpackage` and compile on first launch with `MLModel.compileModel(at:)`, caching into `~/Library/Application Support/<app>/`. The runtime route removes any Xcode dependency entirely.
  - Without Xcode-generated model classes, call `MLModel(contentsOf:configuration:)` directly with `MLDictionaryFeatureProvider` / `MLMultiArray`, or wrap the model in `VNCoreMLModel` + `VNCoreMLRequest` so Vision handles resizing and cropping. This is straightforward from `swiftc`.
- `.mlmodelc` contents are believed to be architecture-neutral (model spec + weights), so compiling on an arm64 CI runner for an Intel target should work. This must be verified once on the iMac. If it fails, the runtime-compile route sidesteps the question.
- **ONNX Runtime from swiftc:** pin the 1.23.2 x86_64 (or universal2) native C library, expose its C header via `-import-objc-header` or a module map, and bundle and sign the dylib. That is feasible, but the dependency is frozen and gets no further upstream fixes for Intel.
- None of the above stores frames to disk. Vision, Core ML and ORT all take in-memory `CVPixelBuffer`/`CGImage`/tensors. Only the compiled model is written to disk.

### Gaps
- Whether the **Command Line Tools-only** install (no Xcode.app) includes `coremlcompiler` is unverified. Check with `xcrun --find coremlcompiler` on the user's machine.
- Whether `.mlmodelc` produced by a newer Xcode on an arm64 runner loads on macOS 14 Intel is untested (model spec version vs OS).

---

## Q6. Licensing constraints of candidate models

### Takeaway
The permissive, shippable choices are Apple Vision (OS-provided), **Depth Anything V2 Small (Apache-2.0)**, **DINOv2 (Apache-2.0)**, **MediaPipe (Apache-2.0)**, and SmolVLM/Moondream (Apache-2.0 per aggregators). The problem cases are **Depth Anything V2 Base/Large/Giant (CC-BY-NC-4.0, non-commercial)**, **Ultralytics YOLO-pose (AGPL-3.0 unless an Enterprise license is bought)**, and **Depth Pro**, whose license signals conflict.

### Cited Findings
- "Depth-Anything-V2-Small model is under the Apache-2.0 license. Depth-Anything-V2-Base/Large/Giant models are under the CC-BY-NC-4.0 license." — [Depth-Anything-V2 GitHub](https://github.com/DepthAnything/Depth-Anything-V2). A Roboflow page claims Small/Base/Large are Apache-2.0, which **contradicts** the official README and should be treated as wrong — [Roboflow playground](https://playground.roboflow.com/models/bytedance/depth-anything-v2). A LibreYOLO repackaging agrees with the official split — [HF LibreYOLO](https://huggingface.co/LibreYOLO/LibreDepthAnythingV2s-depth)
- Depth Pro's GitHub LICENSE is a custom Apple license granting a "personal, non-exclusive license … to use, reproduce, modify and redistribute the Apple Software", with no explicit research-only restriction — [ml-depth-pro LICENSE](https://github.com/apple/ml-depth-pro/blob/main/LICENSE). However, Hugging Face lists Apple's DepthPro repo under **`apple-amlr`** (Apple's ML-research license), and a Core ML repo is tagged `apple-ascl` (per search summary) — [HF apple/DepthPro-mixin](https://huggingface.co/apple/DepthPro-mixin/commits/main). **These conflict**, so check the license attached to the exact weights used.
- Ultralytics: **AGPL-3.0** for open use, or a paid **Enterprise License** "to integrate Ultralytics software and models into business products … without the AGPL-3.0 open-source requirements" — [Ultralytics GitHub](https://github.com/ultralytics/ultralytics)
- "DINOv2 code and model weights are released under the Apache License 2.0" (XRay-DINO and Cell-DINO weights are under separate FAIR non-commercial licenses) — [facebookresearch/dinov2](https://github.com/facebookresearch/dinov2)
- MediaPipe: PyPI license "Apache 2.0" — [PyPI mediapipe JSON](https://pypi.org/pypi/mediapipe/json). The podspec license is "Apache" — [podspec template](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/tasks/ios/MediaPipeTasksVision.podspec.template)
- Moondream 2 is "distributed under the Apache 2.0 license" and requires `trust_remote_code=True` in transformers (aggregator sources) — [Roboflow Moondream 2](https://playground.roboflow.com/models/moondream-ai/moondream-2); [dev.co](https://dev.co/ai/llms/moondream2). SmolVLM2 is listed as Apache 2.0 (aggregator) — [Roboflow SmolVLM2](https://playground.roboflow.com/models/hugging-face/smolvlm2)
- Apple Core ML gallery models are distributed by Apple for use in apps — [Apple Core ML Models](https://developer.apple.com/machine-learning/models/)

### Inferences
- For a distributable app, the safe pose stack is Vision 2D pose (OS-provided) plus optionally RTMPose via ONNX/Core ML. mmpose is widely reported as Apache-2.0, but this was not confirmed this session. Avoid YOLO-pose unless the app is AGPL or a license is bought.
- For depth, only **DA-V2 Small** is clearly commercial-safe. Apple's Core ML conversion of it inherits Apache-2.0 for the weights, though Apple's HF card license field could not be read directly.

### Gaps
- License of **RTMPose/RTMW/mmpose** weights, **ViTPose**, **MiDaS**, **CLIP** variants, **Qwen2.5-VL-3B** (suspected to differ from the 7B's Apache-2.0; unverified), **LLaVA** (inherits base-LLM terms), and **SAM / SAM 2** were not verified this session.
- Apple's HF Core ML Depth Anything card license field could not be read (HF blocked).

---

## Q7. Energy/CPU budgeting tricks and Intel iMac thermal considerations

### Takeaway
The levers that are documented or built into the APIs are:
- `regionOfInterest` cropping;
- the person-segmentation `fast`/`balanced` quality levels;
- reusing stateful request objects;
- `cpuOnly` compute units for background work;
- loading models once (async, off the main thread) and keeping them resident.

Running heavy models (depth, VLM) only once per minute converts a 1–2 s CPU cost into about 2–3% of one core on average. No published data quantifies Intel iMac thermals or fans for this workload.

### Cited Findings
- `regionOfInterest` restricts any image-based Vision request to a normalized sub-rectangle — [Apple docs](https://developer.apple.com/documentation/vision/vnimagebasedrequest/regionofinterest)
- Person segmentation quality levels, and Apple's guidance (accurate for photos, balanced for frame-by-frame video, fast for streaming). Reused request objects smooth temporal changes — [WWDC21 10040](https://developer.apple.com/videos/play/wwdc2021/10040/)
- `cpuOnly` is recommended "if your app might run in the background or runs other GPU intensive tasks" — [Apple docs MLComputeUnits](https://developer.apple.com/documentation/coreml/mlcomputeunits)
- Model load and lifecycle: don't load on launch on the UI thread, use async/lazy loading, and keep the model loaded if it will be reused. The OS-level inference engine got faster from iOS 16 → 17 (and the same OS generation on other platforms) without recompiling — [WWDC23 10049](https://developer.apple.com/videos/play/wwdc2023/10049/)
- Vision on macOS 14 can pin each request stage to a compute device (e.g. force CPU) — [Apple docs setComputeDevice](https://developer.apple.com/documentation/vision/vnrequest/setcomputedevice(_:for:))
- The macOS 15 Swift 3D-pose API exposes `frameAnalysisSpacing` for built-in frame skipping (not available on macOS 14) — [Apple docs DetectHumanBodyPose3DRequest](https://developer.apple.com/documentation/vision/detecthumanbodypose3drequest)
- RTMPose latency scales with input size: RTMPose-m 256×192 takes 11.06 ms vs 24.78 ms at 384×288 (i7-11700) — [mmpose RTMPose README](https://github.com/open-mmlab/mmpose/tree/main/projects/rtmpose)

### Inferences
- **Suggested tiering (estimate-based).**
  - **Every 1 s:** a Vision face rectangles+landmarks (or body pose) request on a downscaled frame (e.g. 640×360) with ROI on the last known upper-body box, plus cheap geometry.
  - **Every 5–10 s:** person segmentation `fast`/`balanced` or feature print, if needed.
  - **Every 60 s:** heavy models such as DA-V2 Small at reduced resolution.
  - **On demand only:** VLM explanations.
- Capture at the camera's native format but convert/downscale once with vImage/Core Image in memory, and never persist frames. Use `AVCaptureVideoDataOutput` with `alwaysDiscardsLateVideoFrames`, and stop the capture session between samples if the camera's own wake/AE cost is acceptable. This is a design suggestion; camera power was not measured.
- On Intel iMacs, prefer `cpuOnly` for 1 Hz work so the discrete AMD GPU is not repeatedly woken. Benchmark both, though, because a single larger model may be cheaper on the GPU.
- Measure with `powermetrics` / Activity Monitor "Energy Impact" and per-process CPU time over 10+ minutes on the actual iMac. Turbo-boost bursts on Intel can make short benchmarks look cheaper or more expensive than steady state.

### Gaps
- No sources were found on Intel iMac fan/thermal behavior under sustained low-duty ML inference, or on the energy cost of waking AMD Radeon GPUs at 1 Hz.
- No sources quantify FaceTime HD camera power when held open continuously vs started and stopped every second or minute.

---

## Q8. Which Intel iMacs run macOS 14, and which camera/GPU they have

### Takeaway
Sonoma supports the **iMac 2019 and later** (both 2019 sizes and the 2020 27") plus the **iMac Pro (2017)**. The cameras are **720p** on the 2019 iMacs and **1080p** on the 2020 27" iMac and the iMac Pro. GPUs are AMD Radeon Pro (Polaris/Vega/Navi) or Vega in the iMac Pro, and no Intel iMac has a Neural Engine. Only the **2020 27" iMac** goes on to macOS 26 Tahoe, the last Intel macOS.

### Cited Findings
- Sonoma's compatible list includes "iMac 2019 and later". A pre-release note says Sonoma covers all T2 Intel Macs plus one non-T2 Intel iMac, the iMac 2019 (iMac19,x) (2023 pre-release report) — [Eclectic Light, 2023-06-08](https://eclecticlight.co/2023/06/08/what-features-has-apple-announced-for-macos-14-sonoma-and-can-your-mac-use-them/); [9to5Mac Sonoma guide](https://9to5mac.com/guides/macos-sonoma/page/3/)
- 2020 27" iMac: **1080p FaceTime HD camera**; Radeon Pro **5300** (4 GB GDDR6) in the lower configs and **5500 XT** (8 GB) in the $2,299 config; 10th-gen Core i5/i7; discontinued March 2022 — [Tom's Guide review](https://www.tomsguide.com/news/apple-imac-27-inch-2020); [Adorama listing](https://www.adorama.com/acmmxwu2llaa.html)
- 2019 21.5" iMac (Retina 4K): **Radeon Pro 560X** 4 GB GDDR5 in the listed config — [Revendo listing](https://revendo.ch/en/products/apple-imac-21-5-retina-4k-silver-3-ghz-6-core-i5-512-gb-ssd-8-gb-ram-radeon-pro-560x-early-2019). The webcam is listed as **720p** ("HD Ready") — [Coolblue listing](https://www.coolblue.nl/en/product/829790/apple-imac-21-5-inches-2019-16gb-512gb-3-0ghz.html)
- iMac Pro (2017) had "the first ever 1080p FaceTime camera on a Mac", vs 720p on the 5K iMac — [AppleInsider](https://appleinsider.com/articles/17/12/28/imac-pro-vs-5k-imac-speakers-and-facetime-cameras-compared). As of 2020, only the iMac Pro had a Mac webcam better than 720p — [Six Colors](https://sixcolors.com/link/2020/04/laptop-webcams-are-kind-of-terrible/). Bare Feats contrasts the iMac Pro's 1080p FaceTime camera with the 2019 iMac's 720p — [Bare Feats](https://barefeats.com/imac-2019-i9-versus-imac-pro.html). The iMac Pro GPU is Radeon Pro Vega 56 (standard) — [EveryMac](https://everymac.com/systems/apple/imac-pro/specs/differences-between-imac-pro-late-2017-27-inch-imac-mid-2017.html)
- macOS 26 Tahoe is the last major release for Intel Macs, and the 2020 27" iMac is the only iMac on its list. Intel Macs get about three years of security updates afterwards — [Thurrott](https://www.thurrott.com/?p=321965); [Guru3D](https://www.guru3d.com/story/apple-ends-major-macos-support-for-intel-macs-after-tahoe-26/)
- Hand-gesture reactions on Intel Macs need Continuity Camera, which illustrates that Apple's newer camera/ML features often assume Apple silicon — [Eclectic Light](https://eclecticlight.co/2023/06/08/what-features-has-apple-announced-for-macos-14-sonoma-and-can-your-mac-use-them/)

### Inferences
- A 720p camera (2019 iMacs) is adequate for face/upper-body keypoints at desk distance. Fine facial landmark precision and depth-from-mono quality will be lower than on 1080p units.
- Since the user's iMac runs Sonoma (not Tahoe), it is most likely a 2019 iMac, an iMac Pro, or a 2020 27" iMac not upgraded. The app should detect the model identifier (`sysctl hw.model`) and camera format at runtime rather than assume.
- The ecosystem trend (ORT, MediaPipe, PyTorch, GitHub Intel runners) means any third-party ML dependency chosen for Intel today will freeze. Apple's OS frameworks (Vision/Core ML) stay supported for as long as the OS gets updates.

### Gaps
- Apple's official Sonoma compatibility page and tech-spec pages (support.apple.com) could not be fetched. The 2019 27" iMac GPU range (Radeon Pro 570X/575X/580X/Vega 48) and the 2020 27" high-end options (5700/5700 XT) are from my general knowledge and unverified here.
- The 2020 refresh of the 21.5" iMac: camera resolution and Sonoma eligibility not confirmed.
- The exact end of security updates for macOS 14 Sonoma was not researched.

---

## Q9. Synthesis: feasibility matrix at ~1 analyzed frame/s and a few % of one core (Intel iMac, macOS 14, swiftc)

### Takeaway
At 1 fps on an Intel iMac, **Apple Vision built-ins are the only zero-dependency, license-clean option**, and they probably fit the budget. Their per-request cost on Intel is unmeasured, so benchmark first. **RTMPose-t/s via Core ML or ONNX** is the strongest third-party upgrade with real x86 numbers (3–5 ms on an i7-11700). **Depth Anything V2 Small** is a once-per-minute, reduced-resolution feature at best. **MediaPipe** and **VLMs** are poor fits for this machine and toolchain.

### Cited Findings
(The matrix below draws only on the cited findings in Q1–Q8; see those sections for sources.)

### Inferences
Legend: **M** = measured (device named), **AS** = Apple-silicon-only numbers, **E** = my estimate, **?** = unknown, must benchmark.

| Candidate | Runs on Intel macOS 14? | Latency evidence | Fits 1 fps @ few % core? | Fits 1/min? | Model size / RAM | License | Swift (swiftc) integration effort |
|---|---|---|---|---|---|---|---|
| Vision `VNDetectHumanBodyPoseRequest` (2D) | Yes (macOS 11+) | ? (no Intel data) | Likely (E); benchmark | Yes | OS-provided | OS API | **Very low** |
| Vision face rect + `VNDetectFaceLandmarksRequest` (76 pts, continuous pitch/yaw/roll) | Yes (10.13+) | ? | Likely (E) | Yes | OS | OS API | **Very low** |
| Vision `VNDetectHumanBodyPose3DRequest` (17 joints, 3D) | **Uncertain**: forum says needs ANE, "may work on some Intel Macs" | ? | Unknown | Maybe | OS | OS API | Very low, plus runtime probe/fallback |
| Vision `VNGeneratePersonSegmentationRequest` fast/balanced | Yes (12+) | ? | fast: likely (E); accurate: probably not | Yes | OS | OS API | Very low |
| Vision `VNGenerateForegroundInstanceMaskRequest` / person instance mask | API present (14+); Intel execution unverified | ? | Unknown | Likely | OS | OS API | Very low |
| Vision `VNGenerateImageFeaturePrintRequest` rev 2 | Yes (rev 2 on 14+) | ? | Likely (E) | Yes | OS; vector size: read `elementCount` | OS API | Very low |
| Create ML / tiny on-device classifier on keypoints or feature prints | Yes (Create ML 10.14+; MLUpdateTask 10.15+) | n/a (training is occasional) | n/a | n/a | KB-scale | OS API | Low to medium |
| RTMPose-t / -s (top-down, 256×192), via Core ML or ORT 1.23.2 | Yes (CPU) | **M**: 3.20 / 4.48 ms on i7-11700 (ORT) | **Yes** (E: ~5–15 ms on iMac i5) | Yes | 3.3M / 5.5M params | mmpose (Apache-2.0 reported, unverified) | Medium (convert; crop from Vision box; SimCC decode) |
| RTMPose-m / RTMW-m (whole-body 133 kpts) | Yes (CPU) | **M**: RTMPose-m 11.06 ms (i7-11700); RTMW: GFLOPs only (4.3 G) | Borderline to yes (E: 15–40 ms) | Yes | 13.6M | as above | Medium |
| YOLO26n-pose (640) | Yes (ORT CPU) | **M**: 40.3 ms CPU ONNX (EC2 P4d Xeon) | Borderline at 640; yes at 320 (E) | Yes | 2.9M params | **AGPL-3.0** / paid Enterprise | Medium; license blocker |
| Depth Anything V2 Small (Core ML F16 / P6) | Yes (CPU/GPU; not ANE-only) | **AS**: 26–34 ms iPhone/M1 Max; Intel ? | **No** at 518 px (E: ~0.5–2 s CPU) | **Yes** at reduced res (E) | 24.8M; 49.8 MB F16 / 19 MB P6 | **Apache-2.0** (Small only) | Low to medium (Apple ships the `.mlpackage`) |
| Depth Anything V2 Base/Large | Yes, technically | none for Intel | No | No (E) | 97.5M / 335M | **CC-BY-NC-4.0** | n/a, license blocker |
| Apple Depth Pro | Yes, technically | GPU 0.3 s; CPU ">200 s" anecdote; Core ML AS 4.8 s | No | No | GB-scale (1.8 GB fp16 Core ML) | Conflicting (GitHub custom permissive vs HF `apple-amlr`) | High |
| MiDaS small | Probably | none found | ? | ? | ? | ? | ? |
| DINOv2-S/14 embeddings (224 px) | Yes (convert) | none for Intel | Possible (E: tens of ms) | Yes | 21M | Apache-2.0 | Medium; redundant with feature print |
| FastViT-T8 (Apple gallery) as an embedding backbone | Yes | **AS**: 0.62 ms M3 Max | Likely (E) | Yes | 3.6M; 6.5 MB headless | Apple gallery | Low |
| MediaPipe Pose/Face Landmarker / Selfie Segmenter | **No supported Intel path** (iOS-only pod; x86 wheels end 0.10.21; macOS C dylib arm64-only) | none for Intel | Unknown | Unknown | 1–6 MB tflite models | Apache-2.0 | **High** (Bazel x86_64 build of C API, or Python 0.10.21 runtime) |
| Small VLM (SmolVLM-256M/500M, Moondream2) | Possibly (CPU fp32 via llama.cpp/ORT) | none for x86 CPU | **No** | Marginal (E: seconds/image, ~0.5–1 GB RAM) | 256M–2B params | Apache-2.0 (aggregators) | High |
| 3B-class VLM (Qwen2.5-VL-3B, LLaVA) | Technically, on CPU | none | No | No (E: tens of s, multi-GB RAM) | 3B+ | Varies / unverified | High |

Key decision notes:
- **Recommended path:** keep the 1 fps loop on Vision (body pose + face landmarks/pose with `regionOfInterest`, `cpuOnly`/CPU compute stage), then benchmark on the actual iMac. If finer keypoints are needed, add **RTMPose-s converted to Core ML**, fed by the Vision body/face box. Treat **DA-V2 Small at reduced resolution once per minute** as an experimental extra.
- Avoid MediaPipe, ORT ≥1.24, and Python/CocoaPods/Bazel runtime dependencies on this Intel + swiftc setup.

### Gaps
- Every Intel-specific latency and CPU % in the matrix marked "?" or "E" needs on-device measurement. No published Intel-Mac benchmarks were found for any candidate.
