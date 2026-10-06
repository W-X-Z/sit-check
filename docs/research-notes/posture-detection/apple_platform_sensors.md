# Apple platform sensing for a posture coach: Vision body/face pose, AVFoundation camera, and AirPods head motion on an Intel iMac with macOS 14 Sonoma

*Method note for the report writer:* I read the Apple Developer Documentation pages through their JSON endpoints (checked 2026-10-06) and read the WWDC20/21/23/24 session transcripts in full. The egress proxy blocked support.apple.com, apps.apple.com and several third-party sites (portal.app, rogueamoeba.com, ithinkdiff.com, research.macpaw.com). Claims from those pages come only from search-result excerpts and are tagged **(search excerpt)**. The shared web-search budget ran out partway through, so the remaining open items are listed under **Gaps** and were not guessed. The tags **[macOS 15+]**, **[macOS 27+]** and **[ANE / Apple silicon]** mark features that are not usable as-is on the target machine.

---

## Q1. VNDetectHumanBodyPoseRequest (2D): joint set, availability and revisions, upper-body-only behavior, minimum size, seated accuracy, and the newer Swift API

### Takeaway
The 2D body pose request works on the target: it is VN API only, macOS 11+, and Revision1 is the only revision. It returns 19 joints with a confidence value for each: nose, eyes, ears, a "neck" point between the shoulders, shoulders, elbows, wrists, hips, root, knees and ankles. Coordinates are normalized with a lower-left origin. Apple publishes no minimum person size, no upper-body-only mode for this request and no seated or webcam accuracy figures, so these need on-device validation. The Swift `DetectHumanBodyPoseRequest` (Revision 2, which can also detect hands) needs **[macOS 15+]**.

### Cited Findings
- `VNDetectHumanBodyPoseRequest` availability: iOS 14.0+, iPadOS 14.0+, Mac Catalyst 14.0+, **macOS 11.0+**, tvOS 14.0+, visionOS 1.0+. The page lists only one revision constant, `VNDetectHumanBodyPoseRequestRevision1`. — [Apple: VNDetectHumanBodyPoseRequest](https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest); [Apple: VNDetectHumanBodyPoseRequestRevision1](https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequestrevision1)
- WWDC21: "Revision number one is the latest and the only available revision of this request." — [WWDC21 10040 "Detect people, faces, and poses using Vision"](https://developer.apple.com/videos/play/wwdc2021/10040/)
- The joint set has 19 points. Head group: `nose`, `leftEye`, `rightEye`, `leftEar`, `rightEar`, `neck`. Arms: `left/rightShoulder`, `left/rightElbow`, `left/rightWrist`. Waist: `root`. Legs: `left/rightHip`, `left/rightKnee`, `left/rightAnkle`. — [Apple: VNHumanBodyPoseObservation.JointName](https://developer.apple.com/documentation/vision/vnhumanbodyposeobservation/jointname). Apple's article also says Vision detects "up to 19 unique body points". — [Apple: Detecting Human Body Poses in Images](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)
- How the joints are defined (WWDC20): there is "a neck point between the shoulders" and "a root joint between the two hip joints". The shoulder landmarks "appear in more then one group" (torso and arms). — [WWDC20 10653 "Detect Body and Hand Pose with Vision"](https://developer.apple.com/videos/play/wwdc2020/10653/)
- Left and right refer to the subject, not the image: "Note that this is the subject's right arm, not the one on the right side of the image." — [WWDC20 10653](https://developer.apple.com/videos/play/wwdc2020/10653/)
- Coordinates and confidence: points "use the same lower left origin as other Vision algorithms and are also returned to normalized coordinates relative to the pixel dimensions of your image". Labeled points come back as `VNRecognizedPoint` with a confidence value. "Vision provides a confidence value per point while ARKit does not." — [WWDC20 10653](https://developer.apple.com/videos/play/wwdc2020/10653/)
- Results: "The request returns a unique observation for each detected human body pose, with each containing the recognized points and a confidence score". — [Apple: Detecting Human Body Poses in Images](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images). The request handles several people at once: "the capability to analyze many people at once for body pose". — [WWDC20 10653](https://developer.apple.com/videos/play/wwdc2020/10653/)
- Region of interest: "If you have a known region of interest (ROI) in an image, you can specify it using the request's regionOfInterest property. Setting an ROI reduces the region in the image where the request performs its analysis, which generally results in more accurate pose estimation." — [Apple: Detecting Human Body Poses in Images](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)
- Limitations Apple states (WWDC20):
  - "If the people on the scene are bent over or upside down, the body pose algorithm will not perform as well."
  - The pose may not be determinable with "obstructive flowing clothing".
  - When one person partially occludes another, "it is possible for the algorithm to get confused".
  - "the results may get worse if the subject is close to the edges of the screen."
  - Source: [WWDC20 10653](https://developer.apple.com/videos/play/wwdc2020/10653/)
- Apple names ergonomics as a use case: "Perhaps it can help with training for proper ergonomics" ([WWDC20 10653](https://developer.apple.com/videos/play/wwdc2020/10653/)) and "a safety-training app could help employees use correct ergonomics" ([Apple article](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)).
- The Vision API "can be used on all supported platforms, except the watch". — [WWDC20 10653](https://developer.apple.com/videos/play/wwdc2020/10653/)
- The upper-body switch belongs to a different request, `VNDetectHumanRectanglesRequest`. Its `upperBodyOnly` property (macOS 12.0+) defaults to `true`, meaning the request "requires detecting a person's upper body only to find the bound box around it". Revision 2 added full-body detection. — [Apple: upperBodyOnly](https://developer.apple.com/documentation/vision/vndetecthumanrectanglesrequest/upperbodyonly); [WWDC21 10040](https://developer.apple.com/videos/play/wwdc2021/10040/)
- Swift API, **[macOS 15+]**: `DetectHumanBodyPoseRequest` (a struct) is iOS 18.0+ and macOS 15.0+. Its `Revision` enum lists `.revision2` (macOS 15.0+). `detectsHands` is "`true`" by default and "requires DetectHumanBodyPoseRequest.Revision.revision2". — [Apple: DetectHumanBodyPoseRequest](https://developer.apple.com/documentation/vision/detecthumanbodyposerequest); [Apple: revision2](https://developer.apple.com/documentation/vision/detecthumanbodyposerequest/revision-swift.enum/revision2); [Apple: detectsHands](https://developer.apple.com/documentation/vision/detecthumanbodyposerequest/detectshands)
- WWDC24 describes "holistic body pose", which detects "hands and body together". It also says "Vision will only introduce new features in Swift moving forward. Our existing APIs are not going away". — [WWDC24 10163 "Discover Swift enhancements in the Vision framework"](https://developer.apple.com/videos/play/wwdc2024/10163/)
- Prior art, Posturr: an open-source (MIT) macOS posture app. It "detects the face, tracks the relative position of the nose and shoulders, and measures the vertical distance between them" and blurs the screen when you slouch **(search excerpt)**. — [Gigazine on Posturr](https://gigazine.net/gsc_news/en/20260126-posturr/); [github.com/tldev/posturr](https://github.com/tldev/posturr)
- Prior art, Dorso (same GitHub owner): the README says it tracks "nose and head position" with body pose. It has a "Face Detection Fallback: When full body isn't visible, tracks face position". It "Requires a working camera with adequate lighting and clear view of upper body/face", and the minimum OS is macOS 13. — [github.com/tldev/dorso](https://github.com/tldev/dorso)

### Inferences
- **Expected framing.** With a seated user and the camera above the display, frames mostly show the head, shoulders and upper torso. Hips are usually below the frame or hidden by the desk, and knees and ankles are almost always missing. Posture metrics should therefore use only nose, eyes, ears, neck and shoulders, and each joint should be gated on its confidence. That Dorso needed a face fallback suggests body pose sometimes fails in desk framing. This is indirect evidence only.
- **Neck point.** Vision's "neck" is defined as a point between the shoulders, so it behaves like a shoulder midpoint, not the C7 vertebra. The proposed ear–shoulder vertical distance ÷ shoulder width ratio can be computed from `leftEar`/`rightEar` and `leftShoulder`/`rightShoulder`. Using `neck` adds little independent information.
- **Leaning in.** Apple warns about subjects near the frame edges. When the user leans toward the screen, which is one form of slouching, the shoulders can drop out of the bottom or sides of the frame. The app should treat "shoulders not visible" as its own state, not report a bad posture score from low-confidence joints.
- **ROI.** A cheap face-rectangle pass can set `regionOfInterest` for body pose around the user's head and shoulders, and pick the right person when several are in view. Apple says an ROI "generally results in more accurate pose estimation".
- **Depth.** 2D pose has no depth. Forward head posture shows up only indirectly: the ears move down and forward relative to the shoulders, and the face grows larger. Per-user calibration against an upright baseline is required.
- **Revision pinning.** Set `request.revision = VNDetectHumanBodyPoseRequestRevision1` explicitly. WWDC21 gives this advice in general so behavior stays deterministic when new revisions arrive (see Q3).

#### Cross-cutting availability matrix (target: Intel x86_64 iMac, macOS 14). Sources are in each section.

| Capability | API availability | Usable on target? |
|---|---|---|
| `VNDetectFaceRectanglesRequest` rev3: continuous roll, yaw and **pitch** | macOS 12+ | Yes. This is the current implementation; pitch is not used yet. |
| `VNDetectFaceLandmarksRequest` rev3: 76 points, pupils | macOS 10.15+ | Yes |
| `VNDetectHumanBodyPoseRequest` rev1: 19 joints | macOS 11+ | Yes. Runs on CPU/GPU; performance not measured. |
| `VNDetectHumanRectanglesRequest` with `upperBodyOnly` | macOS 12+ | Yes |
| `VNDetectHumanBodyPose3DRequest` rev1: 17 joints in meters | macOS 14+ | **Uncertain.** Apple says it "requires a device with a neural engine (but may work on some Intel Mac devices)". **[ANE / Apple silicon]** |
| Vision compute-device API (`setComputeDevice`, `supportedComputeStageDevices`) | macOS 14+ | Yes. Intel Macs have no ANE, so the choices are CPU/GPU. |
| Swift Vision API (`DetectHumanBodyPoseRequest` rev2 with hands, `DetectHumanBodyPose3DRequest`, `DetectFaceRectanglesRequest`) | macOS 15+ | **No on macOS 14 [macOS 15+]** |
| `DetectFaceRectanglesRequest` revision4 | macOS 27+ | **No [macOS 27+]** |
| `AVCaptureDevice.Format.videoFieldOfView` and intrinsic-matrix delivery | Not on macOS | **No** |
| Center Stage APIs | macOS 12.3+ | The API exists. Support on the built-in Intel iMac camera is unverified and expected to be absent. |
| Continuity Camera | macOS 13+ (`.continuityCamera` device type is macOS 14+) | Yes, with an iPhone on iOS 16+ |
| `CMHeadphoneMotionManager` | macOS 14+ | **Unverified.** Apple's Mac head tracking for Spatial Audio requires Apple silicon. |
| `CMHeadphoneActivityManager` | macOS 15+ | **No [macOS 15+]** |

### Gaps
- Apple does not document a minimum person or joint size in pixels. It also does not say what confidence values joints outside the frame receive. Treating confidence 0 or near 0 as "missing" is common practice, but I could not verify it.
- I found no Apple or independent accuracy figures for seated, upper-body-only, front-facing webcam use.
- Apple does not say whether the Swift `.revision2` uses a different body model from VN Revision1 or only adds hands.
- The search budget ran out before I could look for forum or Stack Overflow reports on upper-body-only failure modes.

---

## Q2. VNDetectHumanBodyPose3DRequest (macOS 14+): outputs, depth requirement, hardware requirement, accuracy

### Takeaway
The API exists on macOS 14 (the Swift wrapper needs **[macOS 15+]**) and works from plain 2D images; depth is optional and improves accuracy. It returns one 17-joint skeleton in meters for the most prominent person. Without depth, it assumes a 1.8 m reference body height. Apple's sample code also says "all limbs of the subject" should be visible. An Apple Vision engineer stated the request "requires a device with a neural engine (but may work on some Intel Mac devices)". On an Intel iMac, with a seated user whose legs are hidden, it is high-risk: probe it at runtime and keep a 2D fallback.

### Cited Findings
- Availability: `VNDetectHumanBodyPose3DRequest` is iOS 17.0+, **macOS 14.0+**, Mac Catalyst 17.0+, tvOS 17.0+ and visionOS 1.0+. `VNDetectHumanBodyPose3DRequestRevision1` is macOS 14.0+. — [Apple: VNDetectHumanBodyPose3DRequest](https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest); [Apple: Revision1](https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequestrevision1)
- The Swift `DetectHumanBodyPose3DRequest` is **[macOS 15+]** (iOS 18) and only has `.revision1`. — [Apple: DetectHumanBodyPose3DRequest](https://developer.apple.com/documentation/vision/detecthumanbodypose3drequest)
- Depth is optional: "If the system allows it, the request uses AVDepthData information to improve the accuracy." — [Apple: VNDetectHumanBodyPose3DRequest](https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest)
- WWDC23 on depth: "Vision now enables you to retrieve that 3D position from images without ARKit or ARSession." "VNImageRequestHandler has added initializer APIs for cvPixelBuffer and cmSampleBuffer that take a new parameter for AVDepthData." LiDAR "allows for accurate scale and measurement of the scene." — [WWDC23 111241 "Explore 3D body pose and person segmentation in Vision"](https://developer.apple.com/videos/play/wwdc2023/111241/)
- WWDC23 on outputs: "a 3D skeleton with 17 joints". "position of the 3D joints is returned in meters relative to the captured scene in the real world with an origin at a root joint". "This initial revision returns one skeleton for the most prominent person detected in the frame." "Left and right are always relative to the person". — [WWDC23 111241](https://developer.apple.com/videos/play/wwdc2023/111241/)
- The 17 joints are `topHead`, `centerHead`, `centerShoulder`, `left/rightShoulder`, `left/rightElbow`, `left/rightWrist`, `spine`, `root`, `left/rightHip`, `left/rightKnee` and `left/rightAnkle`. The 3D set has **no nose, eyes or ears**. — [Apple: VNHumanBodyPose3DObservation.JointName](https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/jointname)
- Point semantics: `position` is a `simd_float4x4` relative to the root joint at the center of the hip. `localPosition` is relative to the parent joint. Both come from `VNHumanBodyRecognizedPoint3D`. — [WWDC23 111241](https://developer.apple.com/videos/play/wwdc2023/111241/); [Apple: VNHumanBodyRecognizedPoint3D](https://developer.apple.com/documentation/vision/vnhumanbodyrecognizedpoint3d)
- `bodyHeight` is "The estimated human body height, in meters". It is accurate only when `heightEstimation == .measured`; otherwise it is a `.reference` height. WWDC23 gives the reference value: "a reference height of 1.8 meters". — [Apple: bodyHeight](https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/bodyheight); [WWDC23 111241](https://developer.apple.com/videos/play/wwdc2023/111241/)
- Camera-related outputs (all macOS 14.0+):
  - `cameraOriginMatrix` is "A transform from the skeleton hip to the camera". — [Apple: cameraOriginMatrix](https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/cameraoriginmatrix)
  - `cameraRelativePosition(_:)` returns a joint's position relative to the camera, "in meters". — [Apple: cameraRelativePosition](https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/camerarelativeposition%28_:%29)
  - `pointInImage(_:)` returns "A projection of the 3D position onto the original 2D image in normalized, lower left origin coordinates". — [Apple: pointInImage](https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/pointinimage%28_:%29)
- Apple's sample code says: "ensure you're using an iOS device with an A12 chip or later. The input image should have all limbs of the subject visible." It also notes that during the beta period a `cameraOriginMatrix` behavior change rotated the camera position by 180°. — [Apple sample: Detecting human body poses in 3D with Vision](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-3d-with-vision)
- Hardware: in an accepted answer from Dec 2023, the Apple forum account "visionframeworkdev" wrote: "This request is not supported on simulator, and requires a device with a neural engine (but may work on some Intel Mac devices)". The failure reported in that thread was `Error Domain=com.apple.Vision Code=16 "VNDetectHumanBodyPose3DRequest does not support VNDetectHumanBodyPose3DRequestRevision1"`. — [Apple Developer Forums 743402](https://developer.apple.com/forums/thread/743402)
- A related log message, "ABPKPersonIDTracker not supported on this device / Failed to initialize ABPK Person ID Tracker", is harmless according to Apple: "These logs are unfortunately log noise, but will not impact the results". — [Apple Developer Forums 740961](https://developer.apple.com/forums/thread/740961)
- Accuracy: the WWDC23 session gives **no quantitative accuracy figures** for 3D body pose; I read the full transcript. — [WWDC23 111241](https://developer.apple.com/videos/play/wwdc2023/111241/)

### Inferences
- **Runtime probe.** On an Intel iMac the request may fail at `perform` with Vision error Code=16. Probe once at launch on a test frame, cache the result, and fall back to 2D.
- **Scale.** The FaceTime HD camera has no depth, so metric scale comes from the 1.8 m height assumption. Absolute values such as "head 4 cm forward" are not trustworthy. Angles, such as the head-to-centerShoulder vector against the spine, are more meaningful but have not been validated.
- **Seated framing.** The root (hip center) and the legs are usually hidden for a seated user, and Apple's sample asks for all limbs to be visible. Expect degraded or failed observations in normal desk framing.
- **Speed.** If the request does run on an Intel Mac, it will run without an ANE (CPU/GPU) and is likely to be slow. At one analysis per second that could still fit the budget, but this must be measured.
- **Value for forward head posture.** On this hardware, the 2D proxies (ear–shoulder offset and face size against a calibrated baseline) are likely more robust than 3D pose.

### Gaps
- Apple publishes no list of which Intel Macs can run the request. "May work on some Intel Mac devices" is the only statement I found, and I found no Intel iMac reports before the search budget ran out.
- No published 3D accuracy figures (for example MPJPE) were found, and nothing on upper-body-only inputs.
- It is undocumented whether the request returns an observation (with inferred legs) or nothing when only the upper body is visible.

---

## Q3. Face analysis: rectangle revisions, roll/yaw/pitch availability, landmark points (pupils), accuracy, orientation and mirroring pitfalls

### Takeaway
On macOS 14 the current face-rectangles request at revision 3 already reports **continuous roll, yaw and pitch**. Pitch is macOS 12+ and exists only from revision 3. Landmarks revision 3 (macOS 10.15+) adds a 76-point constellation with pupils, normalized to the face bounding box. The main pitfalls are:
- coordinate conventions (lower-left origin; landmarks are relative to the face box),
- left/right being relative to the subject,
- mirroring,
- angles that are nil when not computed.

### Cited Findings
- `VNDetectFaceRectanglesRequest` is macOS 10.13+. Revision2 is macOS 10.14+ (iOS 12). Revision3 is **macOS 12.0+** (iOS 15). — [Apple: VNDetectFaceRectanglesRequest](https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequest); [Apple: Revision2](https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequestrevision2); [Apple: Revision3](https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequestrevision3)
- WWDC21 on revision 3: it "can now also detect faces covered by masks". "Previously, we have provided roll and yaw metrics only. Most metrics are reported in radians and their values are returned in discrete bins. With the new revision introduction, we're also adding a pitch metric … We're also making all three metrics reported in continuous space." The zero position is "a neutral position of a human head, when the person is looking straight", and pitch tracks the head "nodding up or down". — [WWDC21 10040](https://developer.apple.com/videos/play/wwdc2021/10040/)
- `VNFaceObservation.pitch` is an `NSNumber?` in radians for rotation "around the x-axis", **macOS 12.0+**. `roll` (z-axis) and `yaw` (y-axis) are macOS 10.14+. For all three, "If the request doesn't calculate the angle, the value is `nil`." — [Apple: pitch](https://developer.apple.com/documentation/vision/vnfaceobservation/pitch); [Apple: roll](https://developer.apple.com/documentation/vision/vnfaceobservation/roll); [Apple: yaw](https://developer.apple.com/documentation/vision/vnfaceobservation/yaw)
- `VNFaceObservation` has `init(requestRevision:boundingBox:roll:yaw:pitch:)`. — [Apple: VNFaceObservation](https://developer.apple.com/documentation/vision/vnfaceobservation)
- `VNDetectFaceLandmarksRequest` is macOS 10.13+. It can take `inputFaceObservations` from a face-rectangles request so faces are not detected twice. `VNDetectFaceLandmarksRequestRevision3` is macOS 10.15+ (iOS 13). — [Apple: VNDetectFaceLandmarksRequest](https://developer.apple.com/documentation/vision/vndetectfacelandmarksrequest); [Apple: Revision3](https://developer.apple.com/documentation/vision/vndetectfacelandmarksrequestrevision3)
- Landmarks revision 3 "offers 76-point constellation to better represent major face regions and also provide accurate pupil detection" ([WWDC21 10040](https://developer.apple.com/videos/play/wwdc2021/10040/)). The constellations are `constellation65Points` and `constellation76Points` ([Apple: VNRequestFaceLandmarksConstellation](https://developer.apple.com/documentation/vision/vnrequestfacelandmarksconstellation)). WWDC20 says that in 2019 Apple introduced "a new, richer set of landmarks that infer pupil locations" ([WWDC20 10653](https://developer.apple.com/videos/play/wwdc2020/10653/)).
- `VNFaceLandmarks2D` regions: `allPoints`, `faceContour`, `leftEye`, `rightEye`, `leftEyebrow`, `rightEyebrow`, `nose`, `noseCrest`, `medianLine`, `outerLips`, `innerLips`, `leftPupil`, `rightPupil`. Landmark coordinates "are normalized to the dimensions of the face observation's boundingBox, with the origin at the bounding box's lower-left corner". Convert them with `VNImagePointForFaceLandmarkPoint`. — [Apple: VNFaceLandmarks2D](https://developer.apple.com/documentation/vision/vnfacelandmarks2d)
- On `leftPupil`: "This value may be inaccurate if the eye is blinking." — [Apple: leftPupil](https://developer.apple.com/documentation/vision/vnfacelandmarks2d/leftpupil)
- Coordinate system (WWDC24): "coordinates are normalized between 0 and 1, and the origin is in the lower left hand corner". The Swift API **[macOS 15+]** adds `toImageCoordinates(…)` with an upper-left option. — [WWDC24 10163](https://developer.apple.com/videos/play/wwdc2024/10163/)
- WWDC21 advises pinning revisions: "we always recommend to set explicitly to guarantee deterministic behavior in the future … if new revisions are introduced, the default will also change". The advice was given while discussing segmentation. — [WWDC21 10040](https://developer.apple.com/videos/play/wwdc2021/10040/)
- The Swift `DetectFaceRectanglesRequest` is **[macOS 15+]** and offers `.revision3` and `.revision4`. `.revision4` is **[macOS 27+]** (iOS 27): "Compared to `.revision3`, this revision generally provides better precision and recall, and bounding boxes tend to be tighter. This is the default revision on platforms that support it." — [Apple: DetectFaceRectanglesRequest](https://developer.apple.com/documentation/vision/detectfacerectanglesrequest); [Apple: revision4](https://developer.apple.com/documentation/vision/detectfacerectanglesrequest/revision-swift.enum/revision4)
- Mirroring: `AVCaptureConnection.isVideoMirrored` is macOS 10.7+. When set, `AVCaptureVideoDataOutput` "uses hardware acceleration to mirror every frame". Apple's tip: "Avoid potential performance issues by only mirroring video with a capture connection when necessary." — [Apple: isVideoMirrored](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/isvideomirrored)
- Accuracy statements are qualitative only: "Our face detector offers high precision and recall metrics, it can find faces with arbitrary orientation, different sizes, and also partially occluded." — [WWDC21 10040](https://developer.apple.com/videos/play/wwdc2021/10040/)

### Inferences
- **Pitch is available now.** The app can read `pitch` with no OS change because it already uses revision 3 on macOS 14. A head drop or chin jut changes pitch. The camera sits above the display and looks down, so "neutral" pitch is offset; use per-user calibration and work with changes from that baseline.
- **Perspective.** Face angles are measured relative to the camera's line of sight. If the user moves sideways or up and down in the frame, apparent yaw and pitch shift a little even without a real head turn. Calibrated baselines and short-window medians help.
- **Revision drift.** If the app later moves to the Swift API, revision4's tighter boxes will change the bounding-box-width-to-distance mapping. Pin the revision explicitly and recalibrate whenever the revision changes.
- **Distance from interpupillary distance (IPD).**
  - Pupils are returned in face-box-normalized coordinates, so convert them to pixels first. Then distance ≈ f_px × IPD_mm / IPD_px.
  - macOS exposes no field of view and no intrinsics (Q5), so f_px must be calibrated.
  - For a single user, one calibration at a known distance folds IPD_mm and f_px into a single constant K (distance ≈ K / IPD_px), so no population-average IPD is needed.
  - Pupils can be wrong during blinks, so take a median over several frames.
- **Orientation and mirroring.** Built-in Mac camera frames are landscape and upright, so orientation `.up` should be correct (verify on device). Keep the frames used for analysis unmirrored and mirror only a preview, if one exists. Mirroring the analysis frames flips the image's left/right and the signs of roll and yaw.

### Gaps
- Apple publishes no angle-accuracy figures in degrees and no bin sizes for the discrete angles of revisions 1 and 2.
- I could not confirm the default mirroring state of the built-in camera's data output on macOS 14; the documentation does not state the default. Check `connection.isVideoMirrored` at runtime.
- I found no measured precision for pupil landmarks on 640×480 frames.

---

## Q4. Performance on Intel Macs: CPU vs GPU vs ANE, reported fps and CPU figures, tuning options, recommended analysis rates

### Takeaway
Apple does not document which compute device each request uses. On macOS 14 you can query and override it with `supportedComputeStageDevices` and `setComputeDevice(_:for:)`, using `MLComputeDevice` values `.cpu`, `.gpu` and `.neuralEngine`. Intel Macs have no ANE, so Vision runs there on CPU or GPU. The only Intel measurement I found is a forum report of person segmentation running at about 10 fps on an Intel i7 MacBook Pro, against 60 fps on an M1. I found no Intel measurements for body pose or face requests. At one analysis per second, average cost is roughly inference latency × rate plus the capture pipeline's own overhead, so measure on the iMac itself.

### Cited Findings
- `setComputeDevice(_:for:)` is **macOS 14.0+** (iOS 17). Passing `nil` returns device choice to the framework. "When performing a request, the system makes a validity check. Call supportedComputeStageDevices to get valid compute devices". — [Apple: setComputeDevice(_:for:)](https://developer.apple.com/documentation/vision/vnrequest/setcomputedevice%28_:for:%29)
- `supportedComputeStageDevices` returns `[VNComputeStage : [MLComputeDevice]]` and is macOS 14.0+ ([Apple](https://developer.apple.com/documentation/vision/vnrequest/supportedcomputestagedevices)). `VNComputeStage` has `.main` and `.postProcessing` ([Apple](https://developer.apple.com/documentation/vision/vncomputestage)). `MLComputeDevice` has `.cpu`, `.gpu`, `.neuralEngine` and `allComputeDevices`, macOS 14.0+ ([Apple](https://developer.apple.com/documentation/coreml/mlcomputedevice)).
- `usesCPUOnly` is **deprecated in macOS 14.0**. Its default is false, "to signify that the Vision request is free to leverage the GPU". — [Apple: usesCPUOnly](https://developer.apple.com/documentation/vision/vnrequest/usescpuonly)
- `preferBackgroundProcessing` (macOS 10.13+), when true, "reduces the request's memory footprint, processing footprint, and CPU/GPU contention at the potential cost of longer execution time". — [Apple: preferBackgroundProcessing](https://developer.apple.com/documentation/vision/vnrequest/preferbackgroundprocessing)
- WWDC24 on devices with a Neural Engine: "To reduce our memory footprint, Vision will remove CPU and GPU support for some requests on devices with a Neural Engine. On these device, the Neural Engine is the most performant option. You can always check what compute devices are supported by a request…" — [WWDC24 10163](https://developer.apple.com/videos/play/wwdc2024/10163/)
- WWDC24 on memory and batching: "Vision requests can be memory-intensive", and "for optimal performance Vision recommends performing requests together" through one handler. — [WWDC24 10163](https://developer.apple.com/videos/play/wwdc2024/10163/)
- The only Intel measurement found, from an Apple forum thread (June 2022, no Apple reply): `VNGeneratePersonSegmentationRequest` at `.balanced` ran "60 fps without any issue" on an M1 but "only 10 fps" on a "MacBook Pro Intel i7 2.7GHz" with "Intel Iris Plus Graphics 655". — [Apple Developer Forums 709244](https://developer.apple.com/forums/thread/709244)
- An iPhone measurement, not Intel: `VNDetectHumanBodyPoseRequest` takes about 40 ms per frame on an iPhone 11 **(search excerpt; thread not fetched)**. — [Apple Developer Forums 679909](https://developer.apple.com/forums/thread/679909)
- WWDC20 on older devices: "you will need to pay attention to latency on older devices"; running inference "only a few times per second should be OK". This was said about action classification on top of body pose. — [WWDC20 10653](https://developer.apple.com/videos/play/wwdc2020/10653/)
- 3D body pose "requires a device with a neural engine (but may work on some Intel Mac devices)". — [Apple Developer Forums 743402](https://developer.apple.com/forums/thread/743402)
- Capping the capture frame rate:
  - `activeVideoMinFrameDuration` (macOS 10.7+) can limit the maximum frame rate.
  - The value must be in the format's `videoSupportedFrameRateRanges`, and setting it requires `lockForConfiguration()`.
  - "Choosing a new preset for the capture session also resets this property to its default value".
  - Source: [Apple: activeVideoMinFrameDuration](https://developer.apple.com/documentation/avfoundation/avcapturedevice/activevideominframeduration)
- The `vga640x480` session preset exists on macOS 10.7+. — [Apple: vga640x480](https://developer.apple.com/documentation/avfoundation/avcapturesession/preset/vga640x480)

### Inferences
- **Budget arithmetic** (no Intel figures for body pose or face requests exist). At one analysis per second, an inference that takes L ms costs about L/10 % of one core. For example, 20 ms → about 2% and 60 ms → about 6% of one core. The "≤3% average CPU" target needs a precise definition (per-core Activity Monitor percent or share of total CPU), because body pose on an Intel CPU or GPU could plausibly exceed 3% of one core. This is arithmetic, not a measurement.
- **Measurement plan on the iMac:**
  - Log `supportedComputeStageDevices` for the face, body-pose and 3D requests.
  - Time `.cpu` against `.gpu` for `.main` using `setComputeDevice`.
  - Set `preferBackgroundProcessing = true` and reuse request objects.
  - Run face and body requests in a single `perform([...])` call.
  - Measure average CPU and memory over about 10 minutes with Activity Monitor or Instruments.
- **Capture cost.** Capture can cost more than inference. A session delivering 30 fps all the time burns CPU even if only one frame per second is analyzed. Lower the frame rate to the lowest supported value after setting the preset (the preset resets it), skip mirroring, and consider stopping the session between samples (see the LED trade-off in Q5).
- **Intel slowdown.** The segmentation numbers (M1 60 fps against Intel about 10 fps) suggest that neural-network requests that are trivial on Apple silicon can be several times slower on Intel integrated GPUs. Body pose is a heavier network than face-rectangle detection, so its cost should be measured before switching to it. That it is heavier is an assumption, unverified.

### Gaps
- No published fps or CPU numbers for `VNDetectHumanBodyPoseRequest` or `VNDetectFaceRectanglesRequest` on any Intel Mac were found; the search budget ran out before more targeted queries.
- It is unknown which devices `supportedComputeStageDevices` reports on Intel iMacs. CPU plus the AMD Radeon Pro GPU on 27" models is expected but unverified.
- Apple gives no recommended analysis rate for continuous posture monitoring.

---

## Q5. Camera: Intel iMac FaceTime HD specs, field of view, intrinsics on macOS, Center Stage, in-use indicator and privacy, sharing the camera with other apps

### Takeaway
macOS exposes neither field of view nor intrinsics: `videoFieldOfView` and intrinsic-matrix delivery are not available on macOS. Viewing-distance estimates therefore need user calibration. The 2020 27" iMac has a 1080p FaceTime HD camera; the 2019 models are believed to be 720p, unverified. Center Stage APIs exist on macOS 12.3+ but are unlikely to apply to the built-in Intel iMac camera. The green indicator light is designed to be on whenever the camera runs, so continuous capture means a constant light. Ad-hoc signing makes macOS's camera permission (TCC) unreliable across rebuilds.

### Cited Findings
- The iMac (Retina 5K, 27-inch, 2020) has a "1080p FaceTime HD camera" **(search excerpt of Apple's tech-specs page; page not fetched)**. — [Apple Support 111913](https://support.apple.com/en-ae/111913)
- `AVCaptureDevice.Format.videoFieldOfView` "Indicates the format's horizontal field of view in degrees". Platforms are iOS 7.0+, iPadOS, Mac Catalyst 14.0+ and tvOS 17.0+, with **no macOS**. "Returns zero if the format's field of view is unknown." — [Apple: videoFieldOfView](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/videofieldofview)
- `AVCaptureConnection.isCameraIntrinsicMatrixDeliverySupported` covers iOS 11.0+, Mac Catalyst 14.0+ and tvOS 17.0, with **no macOS**. — [Apple: isCameraIntrinsicMatrixDeliverySupported](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/iscameraintrinsicmatrixdeliverysupported)
- Center Stage APIs are macOS 12.3+. The class property `AVCaptureDevice.isCenterStageEnabled` can be set only under app or cooperative control. `Format.isCenterStageSupported` and `isCenterStageActive` report support and state. When active, "the camera automatically pans, tightens, or widens the field of view". — [Apple: isCenterStageEnabled](https://developer.apple.com/documentation/avfoundation/avcapturedevice/iscenterstageenabled); [Apple: isCenterStageSupported](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/iscenterstagesupported); [Apple: isCenterStageActive](https://developer.apple.com/documentation/avfoundation/avcapturedevice/iscenterstageactive)
- Continuity Camera "brings advanced features like Center Stage, Portrait mode, and Studio Light to all Mac devices". — [Apple sample: Supporting Continuity Camera in your macOS app](https://developer.apple.com/documentation/avfoundation/supporting-continuity-camera-in-your-macos-app)
- Signs of camera sharing:
  - `AVCaptureDevice.isInUseByAnotherApplication` is macOS 10.7+ and key-value observable. — [Apple](https://developer.apple.com/documentation/avfoundation/avcapturedevice/isinusebyanotherapplication)
  - `AVCaptureSession.InterruptionReason`, which includes `videoDeviceInUseByAnotherClient`, is **not available on macOS** (iOS, iPadOS, Catalyst, tvOS and visionOS only). — [Apple](https://developer.apple.com/documentation/avfoundation/avcapturesession/interruptionreason)
  - `wasInterruptedNotification` does exist on macOS 10.14+. — [Apple](https://developer.apple.com/documentation/avfoundation/avcapturesession/wasinterruptednotification)
- `AVCaptureDevice.systemPreferredCamera` (macOS 13+) "may change spontaneously". It takes into account "the appearance of Continuity Cameras". `userPreferredCamera` is also macOS 13+. — [Apple: systemPreferredCamera](https://developer.apple.com/documentation/avfoundation/avcapturedevice/systempreferredcamera); [Apple: userPreferredCamera](https://developer.apple.com/documentation/avfoundation/avcapturedevice/userpreferredcamera)
- Indicator light: "The camera is engineered so that it can't be activated without the camera indicator light also turning on." A green light beside the camera glows while the camera is on **(search excerpt of Apple's Mac User Guide; page not fetched)**. — [Apple Mac User Guide mchlp2980](https://support.apple.com/en-asia/guide/mac-help/mchlp2980/10.15/mac)
- Permission, Info.plist key: `NSCameraUsageDescription` is macOS 10.14+, and "This key is required if your app uses APIs that access the device's camera." — [Apple: NSCameraUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription)
- Permission, Apple's capture-authorization article:
  - "In iOS and macOS 10.14 and later, the user must explicitly grant permission for each app".
  - "In macOS, you also need to enable … the Camera entitlement".
  - "Your app needs to contain the appropriate key in its Info.plist file, and the appropriate entitlement enabled in macOS, before it requests authorization or attempts to use a capture device. Otherwise, the system terminates your app."
  - Source: [Apple: Requesting authorization to capture and save media](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)
- Permission, entitlement scope: you add the camera entitlement by first enabling "the App Sandbox or Hardened Runtime capability". — [Apple: com.apple.security.device.camera](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.camera)
- Ad-hoc signing (TN3127): "Ad hoc signed code, called Sign to Run Locally by Xcode, has a DR but it's tied to that specific version of the code. In both cases macOS can't reliably track the identity of the code." (DR = designated requirement, the rule macOS uses to recognize an app's identity.) Also: "When working with privacy-protected resources on macOS, like the microphone, you might find that the system fails to remember your choices during development." — [Apple TN3127: Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)

### Inferences
- **Focal length.** With no API for field of view or intrinsics on macOS, focal length in pixels must come from calibration: a known distance, a known-size object, or the single-constant IPD method in Q3. Store it per camera `uniqueID` and per capture format.
- **Camera selection.** Pin the built-in camera by `uniqueID`. Do not follow `systemPreferredCamera` automatically: if a Continuity Camera iPhone appears and is picked up, the geometry changes and calibration silently breaks.
- **Center Stage.** If Center Stage is ever active (for example on a Continuity Camera), automatic framing breaks bounding-box- and IPD-based distance and position metrics. Check `isCenterStageActive` and pause scoring or warn the user.
- **Indicator light.** Continuous capture keeps the green light on all day, a real UX and privacy-perception cost for an always-on coach. Cycling the session (start, grab a few frames, stop) makes the light blink and adds camera warm-up and auto-exposure settling time, which I did not measure. The product has to choose between these.
- **Camera sharing.** macOS has `isInUseByAnotherApplication` and lacks the iOS "in use by another client" interruption reason. That is consistent with macOS letting several apps open the camera at once, but this is unverified. Test with FaceTime and Zoom on the target, and consider pausing analysis while `isInUseByAnotherApplication` is true, since another app may change exposure or format.
- **TCC and ad-hoc signing.** Under ad-hoc signing every `swiftc` rebuild changes the code's identity (its DR), so the camera grant may not carry over or may re-prompt. Practical fixes:
  - Sign with a stable, persistent identity, such as a self-signed code-signing certificate in the keychain, so the DR stays constant.
  - Always launch the `.app` bundle with its `Info.plist`, not the bare binary from Terminal, so the prompt and the grant attach to the app.
  - `tccutil reset Camera <bundle-id>` is the usual reset tool (common practice; not from the sources above).
- **Entitlement.** The entitlement page ties the camera entitlement to App Sandbox or Hardened Runtime, while the authorization article says it is needed "in macOS". Including `com.apple.security.device.camera` is harmless and avoids termination if hardened runtime is ever turned on.

### Gaps
- Apple publishes no horizontal field of view for any Intel iMac FaceTime HD camera, and I found no measured values before the search budget ran out.
- Unverified because support.apple.com was blocked:
  - The 2019 21.5" and 27" iMac cameras are believed to be 720p FaceTime HD, and the iMac Pro is believed to be 1080p.
  - The list of iMacs that can run Sonoma is believed to be iMac 2019 and later plus the iMac Pro 2017.
  - Background belief: macOS 26 Tahoe is the last Intel-supporting release and supports only the 2020 iMac among iMacs, so **[macOS 27+]** features are out of reach on Intel.
- I found no primary source on concurrent camera use by several apps on macOS 14, or on what happens to our session's format when a video-call app opens the camera.
- I found no source on whether the built-in Intel iMac camera exposes any Center Stage-capable format; none is expected.

---

## Q6. CMHeadphoneMotionManager on macOS: availability, supported devices, outputs, permissions, sample rate, reference frame and drift, connection handling, battery, and use by Mac posture apps

### Takeaway
The API exists on **macOS 14.0+**; it requires `NSMotionUsageDescription` in Info.plist or the app crashes. It streams attitude, rotation rate and user acceleration from AirPods and Beats that support Spatial Audio with dynamic head tracking, one earbud at a time. However, Apple's support documentation says Spatial Audio head tracking on Mac requires **Apple silicon**, and I found no confirmation that headphone motion works on Intel Macs at all. Treat it as **unverified and possibly unavailable** on the Intel iMac and check `isDeviceMotionAvailable` with a tiny probe before designing around it. Apple publishes no sample rate, drift or battery figures.

### Cited Findings
- Availability: `CMHeadphoneMotionManager` is iOS 14.0+, Mac Catalyst 14.0+, **macOS 14.0+** and watchOS 7.0+. The following are all macOS 14.0+:
  - `CMHeadphoneMotionManagerDelegate`, with `headphoneMotionManagerDidConnect(_:)` and `headphoneMotionManagerDidDisconnect(_:)`
  - `authorizationStatus()`
  - `isDeviceMotionAvailable`
  - `startDeviceMotionUpdates(to:withHandler:)`
  - `startConnectionStatusUpdates()` and `isConnectionStatusActive`
  - Sources: [Apple: CMHeadphoneMotionManager](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager); [Apple: CMHeadphoneMotionManagerDelegate](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanagerdelegate); [Apple: isDeviceMotionAvailable](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager/isdevicemotionavailable); [Apple: startConnectionStatusUpdates()](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager/startconnectionstatusupdates%28%29)
- Info.plist: "In iOS and macOS, include the NSMotionUsageDescription key in your app's Info.plist file. If this key is absent, the system crashes your app when you start device-motion updates." — [Apple: CMHeadphoneMotionManager](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager). The key itself is macOS 10.15+. — [Apple: NSMotionUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmotionusagedescription)
- WWDC23 on availability: "this year, CMHeadphoneMotionManager is coming to macOS … starting this year, it's also coming to macOS 14." "You can use CMHeadphoneMotionManager to stream device motion from audio products that support spatial audio with dynamic head tracking, like AirPods Pro, to a connected iOS, iPadOS, or macOS device. Inspect CMDeviceMotion for attitude, user acceleration, and rotation rate data". "Data is available when the audio device is connected to a supported streaming device, like iPhone, iPad, or Mac." — [WWDC23 10179 "What's new in Core Motion"](https://developer.apple.com/videos/play/wwdc2023/10179/)
- Connection events (WWDC23): with Automatic Ear Detection on, "You'll get a disconnect event when the buds are taken out of ear, and a connect event when they're put back in". Putting on or taking off over-ear headphones with automatic head detection triggers the same events. — [WWDC23 10179](https://developer.apple.com/videos/play/wwdc2023/10179/)
- One earbud at a time (WWDC23): "motion data is delivered to you from one bud at a time". `SensorLocation` identifies which bud. If the streaming bud comes out, "my left bud will take over the data stream". — [WWDC23 10179](https://developer.apple.com/videos/play/wwdc2023/10179/). `CMDeviceMotion.SensorLocation` has `.default`, `.headphoneLeft` and `.headphoneRight`. — [Apple: CMDeviceMotion.SensorLocation](https://developer.apple.com/documentation/coremotion/cmdevicemotion/sensorlocation-swift.enum)
- Reference attitude (WWDC23): "we can keep track of a reference attitude as startingPose and use the multiply method to conveniently obtain the current sample's relative change to that original pose." — [WWDC23 10179](https://developer.apple.com/videos/play/wwdc2023/10179/)
- Apple names posture as a use case: "Things like counting the number of pushups you did or monitoring posture were made easier than ever." — [WWDC23 10179](https://developer.apple.com/videos/play/wwdc2023/10179/)
- Authorization: "Users of your app are prompted to authorize your app for motion data using the Motion Usage Description key … You can check the authorizationStatus property". — [WWDC23 10179](https://developer.apple.com/videos/play/wwdc2023/10179/). Dorso's AirPods mode requires "Motion & Fitness Activity permission". — [github.com/tldev/dorso](https://github.com/tldev/dorso)
- **Mac hardware requirement for head tracking:** Spatial Audio and head tracking on Mac are for "Mac computers with Apple silicon and macOS 12.3 or later" **(search excerpt; page not fetched)**. — [Apple Support HT211775 "Control Spatial Audio and head tracking on AirPods"](https://support.apple.com/en-au/HT211775)
- Supported headphones: Spatial Audio works with AirPods Pro (1st or 2nd generation), AirPods Max, AirPods (3rd generation), Beats Fit Pro and Beats Studio Pro. AirPods Max 1 (USB-C) and AirPods Max 2 also support head tracking over a USB-C cable on macOS 15.4+ **(search excerpt)**. — [Apple Support HT211775](https://support.apple.com/en-au/HT211775)
- Reference-frame instability on macOS (forum post, about four weeks before 2026-10-06, unanswered): yaw "appears to recenter as soon as I press play" when Spatial Audio is set to Head Tracked or Fixed. The poster asked whether "the application using Spatial Audio take[s] precedence over other applications using CMHeadphoneMotionManager". — [Apple Developer Forums 844940](https://developer.apple.com/forums/thread/844940)
- Firmware dependency precedent (iOS 14 betas, 2020): the handler was never called until "the latest AirPod Pro firmware (3A283)". — [Apple Developer Forums 650051](https://developer.apple.com/forums/thread/650051)
- `CMHeadphoneActivityManager` (headphone-based activity and status) is **[macOS 15+]** (iOS 18), so it is not on macOS 14. — [Apple: CMHeadphoneActivityManager](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager)
- Mac posture apps that use it:
  - **Posture Pal** got a Mac version when "Apple made the necessary motion-tracking APIs available in macOS Sonoma". It shows giraffe, monkey or alpaca reminders, has three sensitivity levels, and is free with a $4.99 unlock. Reviewers say "certain AirPods models don't work as well as others" and some reported detection problems **(search excerpts)**. — [Cult of Mac](https://www.cultofmac.com/?p=832389); [Macwelt test](https://www.macwelt.de/article/2095820/posture-pal-test.html)
  - A Posture Pal App Store listing was summarized as "requires macOS 12.0 or later and a Mac with Apple M1 chip or later" **(search excerpt; ambiguous, because this is the standard wording for iPhone/iPad apps running on Apple-silicon Macs)**. — [App Store id1590316152](https://apps.apple.com/us/app/-/id1590316152)
  - **Dorso** supports camera or AirPods. Its AirPods mode "Requires macOS 14+ and compatible AirPods (Pro, Max, or 3rd generation+)" and uses head-tilt pitch. The README says nothing about Intel or Apple silicon. — [github.com/tldev/dorso](https://github.com/tldev/dorso)
  - Other Mac apps reported to use AirPods motion for posture: AirPosture, NeckLife and Headjust **(search excerpts)**. — [Softpedia: AirPosture](https://mac.softpedia.com/get/Utilities/AirPosture.shtml); [hunted.space: NeckLife](https://hunted.space/product/neck-life); [Product Hunt: Headjust](https://www.producthunt.com/products/headjust)

### Inferences
- **Intel risk.** On Mac, head tracking is gated on Apple silicon for Spatial Audio, and WWDC says data flows only to "a supported streaming device". It is therefore quite possible that `isDeviceMotionAvailable` is false, or that no samples arrive, on an Intel iMac. A 20-line probe app (bundle with `NSMotionUsageDescription`; log `isDeviceMotionAvailable`, `authorizationStatus()`, connect/disconnect callbacks and the sample count over 30 s) would settle this in minutes. Do it before investing in this path.
- **Drift and recentering.** The attitude reference is arbitrary at start and, per the forum report, can recenter when another app starts Spatial Audio playback. Posture logic should be relative to a calibrated baseline, re-baseline when the user confirms they are upright, and tolerate jumps by looking at short-window changes. Pitch should be less affected than yaw if the reference frame stays gravity-aligned, but I have not verified this for headphones.
- **Connection is the norm, not the exception.** AirPods must be connected to the Mac. Automatic switching to an iPhone, case insertion or removing the buds produce disconnect events, so the app needs a graceful "AirPods signal unavailable" state and fallback to the camera.
- **What it measures.** AirPods measure head orientation only, not the trunk or shoulders. Slouching with the head held level, or forward head translation without a pitch change, can go undetected. It is a complementary, camera-free signal, not a replacement.
- **Battery.** Streaming motion likely adds some drain to the AirPods. No figures exist.

### Gaps
- Whether `CMHeadphoneMotionManager` delivers data on Intel Macs running macOS 14: I found no primary statement and no developer report; the search budget was exhausted.
- Sample rate (often said to be about 25 Hz; unverified), drift magnitude and battery impact are not documented by Apple and were not found.
- The exact device list for headphone motion, as opposed to Spatial Audio, was not verified; AirPods 4, AirPods Pro 3 and Powerbeats Pro 2 are uncertain.
- It is unclear whether the Mac version of Posture Pal is native or the iPad app running on Mac, and whether it supports Intel.
- How macOS 14 presents the motion-permission prompt and settings pane was not checked first-hand.

---

## Q7. Other on-device signals relevant to sitting posture on a Mac (Continuity Camera, Apple Watch, others)

### Takeaway
Continuity Camera (macOS 13+, iPhone on iOS 16+) is the main other Apple-supported sensor path and works on "all Mac devices". It could provide a better-placed camera, including a side view that is ideal for forward head posture, plus Center Stage and Portrait mode, but it ties up an iPhone. I found no Mac API for streaming Apple Watch motion. On macOS 14 the remaining Vision options are cheap detectors useful for gating, not new posture signals.

### Cited Findings
- Continuity Camera:
  - Requirements: a Mac on macOS 13 or later, an iPhone on iOS 16 or later, and both "signed into an Apple ID account that uses two-factor authentication".
  - It uses "the rear-facing, wide-angle camera of iPhone".
  - It "brings advanced features like Center Stage, Portrait mode, and Studio Light to all Mac devices".
  - Apps are expected to adopt automatic camera selection through `systemPreferredCamera`.
  - Source: [Apple sample: Supporting Continuity Camera in your macOS app](https://developer.apple.com/documentation/avfoundation/supporting-continuity-camera-in-your-macos-app)
- `AVCaptureDevice.DeviceType.continuityCamera` is **macOS 14.0+**. — [Apple: continuityCamera](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/continuitycamera)
- Prior art: PostureFix is described as using "Apple Vision with neural engine pose detection" with a "camera picker (FaceTime / iPhone Continuity)", calibration, per-metric scores and CSV logs **(search excerpt)**. — [github.com/adnanakil/PostureFix](https://github.com/adnanakil/PostureFix)
- Person segmentation (`VNGeneratePersonSegmentationRequest`) is supported on macOS, with fast, balanced and accurate quality levels ([WWDC21 10040](https://developer.apple.com/videos/play/wwdc2021/10040/)). On an Intel MacBook Pro it ran at about 10 fps on `.balanced` ([Apple Developer Forums 709244](https://developer.apple.com/forums/thread/709244)).
- `VNDetectHumanRectanglesRequest` with `upperBodyOnly` (macOS 12.0+) gives a cheap upper-body presence box. — [Apple: upperBodyOnly](https://developer.apple.com/documentation/vision/vndetecthumanrectanglesrequest/upperbodyonly)
- 3D body pose can take `AVDepthData` when it is provided. — [WWDC23 111241](https://developer.apple.com/videos/play/wwdc2023/111241/)
- `CMHeadphoneActivityManager` is **[macOS 15+]**. — [Apple: CMHeadphoneActivityManager](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager)

### Inferences
- **Side-view camera.** An iPhone on a side mount through Continuity Camera would view the user's sagittal (side) plane directly. That suits forward head posture and trunk-flexion measurement far better than the top-of-display front camera. It is impractical for an always-on menu-bar coach, though: the phone is tied up, battery drains, and setup has friction. It suits occasional calibration or "posture check" sessions better.
- **Presence gating.** Human rectangles with `upperBodyOnly`, or simply "face present", can decide "user at desk" cheaply, so the heavier body-pose request runs only when someone is there.
- **Apple Watch.** Using Watch motion would need a watchOS or iPhone companion app relaying data (for example through WatchConnectivity or HealthKit). That is outside a single-Mac-app design, and I found no direct Watch-to-Mac motion API.

### Gaps
- Not verified: whether Continuity Camera delivers depth (`AVDepthData`) or intrinsics to macOS apps.
- I did not research Apple Watch-to-Mac motion streaming in depth because the search budget ran out; no Apple API for it was found.
- I found no Apple documentation of other built-in Mac sensors relevant to posture; iMacs have no motion sensors. This is my background knowledge, not a sourced finding.
