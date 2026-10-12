# Frontal desk-webcam 3D / geometric posture extraction (beyond 2D keypoints and face rectangles)

Scope: a single frontal webcam above the monitor, a seated user at about 50–80 cm, lower body hidden by the desk. Target is an Intel x86_64 iMac on macOS 14 with the built-in FaceTime HD camera, no cloud and no stored frames. Current as of 2026-10-12.

**How the sources were read (affects confidence).** In this session arxiv.org, PMC/NCBI, MDPI, ecva.net, alphaxiv and huggingface.co were blocked or unreachable (proxy 403 or DNS failure). Two kinds of sources were read directly: GitHub READMEs (raw.githubusercontent.com) and Apple developer documentation (developer.apple.com JSON). Numbers marked **[snippet]** come from search-engine summaries of the paper and were not checked against the full text. The report writer should treat them as provisional.

**Prior findings not repeated here** (see `정밀 자세 측정 방법 레퍼런스/camera_vision_methods.md` and `자세 감지 방향성 리서치/webcam_cv_accuracy.md`):
- No frontal method has been validated against lateral CVA.
- The sternum-to-tragi frontal angle correlates only moderately.
- Monocular 3D lifting error is about 37–45 mm, and BlazePose depth is "not metric".
- A 3D-pose forward-head classifier reached about 78%.
- Iris-based distance error is 4.3% ± 2.4%.
- No SMPL-family validation exists for seated spine or CVA.

---

## Q1. Monocular depth foundation models (Depth Anything V1/V2/V3, Depth Pro, MiDaS, Metric3D, UniDepth, Sapiens, etc.): can face-vs-shoulder relative depth detect head protraction (about 1.5–2 cm per 10° CVA)? How accurate is relative depth at close range on human bodies? Has any posture or ergonomics study used one from a frontal webcam?

### Takeaway
No study was found that uses a monocular depth foundation model (2023–2026) to measure forward head, trunk lean or shoulder rounding from a frontal webcam. Published accuracy is reported only as scene-level relative error: AbsRel about 0.04–0.05 on NYUv2, and δ1 about 0.85–0.99 for metric models. At 60–80 cm that implies centimetre-scale per-pixel error, the same size as the 1.5–2 cm head shift being sought. Human-specific depth models (Sapiens, THFM) exist but have not been validated for any posture variable. Monocular depth is therefore an unvalidated proxy for head protraction at best; it is not a measurement.

### Cited Findings
**General-purpose depth benchmarks (indoor, close range is not separated out):**
- **Depth Anything V1, zero-shot *relative* depth on NYUv2:**
  - Small (24.8M params): AbsRel 0.053, δ1 0.972.
  - Base (97.5M): 0.046 / 0.979.
  - Large (335M): 0.043 / 0.981.
  - MiDaS v3.1 (345M): 0.048 / 0.980, though the authors note MiDaS was trained on NYUv2 and so is not zero-shot there.
  - Inference time: 12 / 13 / 20 ms on a V100 for S/B/L, excluding pre/post-processing.
  — [Depth Anything V1 README](https://raw.githubusercontent.com/LiheYoung/Depth-Anything/main/README.md)
- **Depth Anything V2** ships "four models … for robust relative depth estimation". Separate *metric* versions are fine-tuned on synthetic Hypersim (indoor, max depth 20 m) or Virtual KITTI 2 (outdoor). The README states "our larger model has better temporal consistency on videos". — [Depth Anything V2 README](https://raw.githubusercontent.com/DepthAnything/Depth-Anything-V2/main/README.md); [DA-V2 metric README](https://raw.githubusercontent.com/DepthAnything/Depth-Anything-V2/main/metric_depth/README.md)
- **Video Depth Anything metric models (released 2025-08-28), comparison table:**

  | Model | NYUv2 δ1 | KITTI δ1 | ScanNet temporal alignment error (TAE, lower is better) |
  |---|---|---|---|
  | UniDepthV2-L | 0.989 | 0.982 | 1.41 |
  | MoGe-2-L | 0.967 | 0.415 | 2.56 |
  | Depth Pro | 0.953 | 0.822 | 2.73 |
  | VDA-S-Metric | 0.850 | 0.877 | 1.48 |
  | VDA-B-Metric | 0.883 | 0.887 | 1.26 |
  | VDA-L-Metric | 0.908 | 0.910 | 1.09 |

  VDA-Small latency is 9.1 ms (FP32) on an A100 for 32 × 518 × 518 input. — [Video Depth Anything README](https://raw.githubusercontent.com/DepthAnything/Video-Depth-Anything/main/README.md)
- **Depth Anything 3 (ByteDance Seed, late 2025):**
  - `DA3Mono-Large` "directly predicts depth", unlike disparity-based DA2, which the authors say gives "superior geometric accuracy". `DA3Metric-Large` targets metric monocular depth.
  - Licences: Small, Base and Metric-Large are Apache-2.0. Large and Giant are CC BY-NC 4.0.
  - The README gives no close-range or human benchmark.
  — [Depth Anything 3 README](https://raw.githubusercontent.com/ByteDance-Seed/Depth-Anything-3/main/README.md)
- **Apple Depth Pro:** zero-shot metric depth "without relying on … camera intrinsics", with focal-length estimation from a single image. It produces a 2.25-MP depth map in 0.3 s "on a standard GPU". — [ml-depth-pro README](https://raw.githubusercontent.com/apple/ml-depth-pro/main/README.md)
- **Intrinsics matter for metric head depth.** A 2024 monocular 6DoF head-pose paper states that camera intrinsics are "a necessary component for deriving depth". Without them, relative depth among faces can be estimated, but precise depth "poses a challenge". — [arXiv 2407.14136](https://arxiv.org/pdf/2407.14136) **[snippet]**
- **Benchmark-to-real gap.** Depth2Pose (NeurIPS 2026 Datasets & Benchmarks) found that monocular depth models that score well on standard benchmarks "do not necessarily generalize to our more challenging dataset". It also found that depth quality is "spatially non-uniform". — [Depth2Pose arXiv 2605.19797](https://arxiv.org/abs/2605.19797); [GitHub](https://github.com/kocurvik/depth2pose) **[snippet]**

**Human-specific depth:**
- **Sapiens (Meta, ECCV 2024):** a human-centric model family (pose, part segmentation, depth, normals) pretrained on 300M human images at 1024 × 1024. — [Sapiens README](https://raw.githubusercontent.com/facebookresearch/sapiens/main/README.md)
  - Hi4D depth RMSE:

    | Model | RMSE |
    |---|---|
    | Depth-Anything-B | 0.143 |
    | Depth-Anything-L | 0.147 |
    | Sapiens 0.3B | 0.148 |
    | Sapiens 0.6B | 0.142 |
    | Sapiens 1B | 0.125 |
    | Sapiens 2B | 0.114 |

  - The authors say δ1 "does not effectively reflect performance in human scenes". They use the MiDaS-v3.1 relative-depth protocol. — [Sapiens arXiv v2](https://arxiv.org/html/2408.12569v2) **[snippet; units and region breakdown (face, upper body) not verified]**
  - The headline claim is a "22.4% relative RMSE improvement on Hi4D". — [ECCV 2024 page](https://www.ecva.net/papers/eccv_2024/papers_ECCV/html/529_ECCV_2024_paper.php) **[snippet]**
- **THFM (Google DeepMind, March 2026):** a video diffusion model that predicts human depth as per-sequence-normalised disparity. A summary claims "competitive or superior" depth on the Goliath dataset versus Sapiens, DepthAnythingV2 and Depth Pro. No numbers were retrieved. — [THFM arXiv 2603.25892](https://arxiv.org/html/2603.25892v1) **[snippet]**

**Posture and ergonomics use:**
- A 2025 critical review states that estimating REBA directly from a single RGB image via monocular 3D pose is "largely unexamined". Most existing work "depend[s] on depth sensors or sequential inputs". — [CMC 2025 review](https://www.sciencedirect.com/org/science/article/pii/S1546221825005466) **[snippet]**
- **ROMP monocular multi-person 3D pose in elderly care:** RULA accuracy 83.8% and OWAS accuracy 90.7%. Joint-angle MAE was 9.4°, which was not specific to the neck. — [Applied Ergonomics 2023, S016981412300032X](https://www.sciencedirect.com/science/article/abs/pii/S016981412300032X) **[snippet; older]**
- **SitPose (2024)** uses an actual depth sensor, recommends a 45° downward angle from the side of the desk, and tests seven instructed actions. — [arXiv 2412.12216](https://arxiv.org/pdf/2412.12216) **[snippet]**
- No GitHub posture app was found that uses a monocular depth model and reports validation. Hobby repos use MediaPipe/BlazePose z, face size or eye height. — [Jamedjo/slouchup](https://github.com/Jamedjo/slouchup); [aaronhubhachen/slouch-detector](https://github.com/aaronhubhachen/slouch-detector) **[snippet]**

**Running it on this hardware:**
- **Apple's Core ML Depth Anything V2 Small** has 24.8M params (F16 about 49.8 MB). Publisher-reported latency on the Neural Engine is about 31–34 ms on iPhone 12/15 Pro Max, 33 ms on an M1 Max and 25 ms on an M3 Max. The "abs-rel 0.0072 (F32) / 0.0089 (F16)" figure in a mirror card appears to measure fidelity to the PyTorch model, not error against ground truth. — [apple/coreml-depth-anything-v2-small card](https://huggingface.co/apple/coreml-depth-anything-v2-small/raw/main/README.md); [f-labor mirror](https://huggingface.co/f-labor/coreml-depth-anything-v2-small) **[snippet]**

### Inferences
**Error versus signal size:**
- Transferring NYUv2 AbsRel (0.043–0.053) naively to a face at 60–80 cm gives a mean per-pixel error of about 2.6–4.2 cm.
- This error is after per-image scale and shift alignment, which relative models need. It is as large as or larger than the 1.5–2 cm per 10° CVA signal.
- What matters is the error of a *within-image difference* (face minus shoulders) tracked *over time for one person*. Errors could partly cancel there, but no source measures this. This is an assumption to test, not a known property.

**Relative models have no fixed metric scale:**
- Relative (affine-invariant) models such as DA-V1/V2 and MiDaS output disparity up to an unknown scale and shift *per frame*.
- So "face–shoulder disparity difference" has no fixed metric meaning, and it can drift when the background or lighting changes.
- An anchor is needed. One option is the face metric depth from the iris or the face transform (Q2) used to fix scale per frame. The other is a metric model (UniDepthV2, Depth Pro, DA3Metric).
- Even metric models only reach δ1 0.85–0.99 on NYUv2. δ1 = 0.95 still allows 5% of pixels to be more than 25% off.

**Where a monocular depth map adds anything:**
- Clothing, hair and a chair back behind the user make the shoulder and upper-chest depth surface ambiguous.
- Learned priors tend to regress the depth of a human torso toward typical shapes, the same bias noted earlier for SMPL.
- Monocular depth adds most where 2D keypoints are blind: it gives a coarse sign and magnitude of "head in front of the shoulder plane", tracked relative to the user's own calibrated baseline.
- It is unlikely to resolve 1–2 cm absolute protraction from a single frame. It may resolve larger changes, roughly over 3–5 cm, such as leaning in toward the screen. This is an inference from the error magnitudes above.

**Feasibility on the Intel iMac:**
- An Intel iMac has no Apple Neural Engine. Core ML would fall back to CPU or the AMD GPU, so the 25–34 ms figures do not apply.
- A per-second (not per-frame) depth pass with DA-V2-Small might be workable, but this was not measured.
- Sapiens (0.3B–2B params at 1024 px) and Depth Pro are probably too heavy for continuous local use on this hardware.

**Licence:** the DA3 Large and Giant weights are non-commercial (CC BY-NC). Small, Base and Metric are Apache-2.0.

### Gaps
- No relative-depth accuracy was found specifically for **faces and upper torsos at 0.5–0.8 m** (for example, error of nose-to-shoulder depth difference against structured light or LiDAR). The Sapiens table, if the full text can be read, may break results down by face and upper body. It could not be opened here.
- No study was found that validates any monocular depth model against lateral CVA, mocap head protraction, or trunk inclination in sitting.
- No within-subject temporal repeatability numbers exist for face-minus-shoulder depth difference with a static camera. These would be needed to know whether drift or noise is below 1.5–2 cm.
- No published CPU latency on Intel Macs was found for DA-V2-Small, DA3-Small, or Video Depth Anything Small.
- The NYUv2 numbers for Depth Pro, Metric3D v2 and DA-V2 (relative) from their own papers could not be retrieved, because arXiv was blocked.

---

## Q2. 3D face mesh and head pose with translation (MediaPipe Face Landmarker transformation matrix, ARKit-style geometry, 3DMM fitting, solvePnP, iris metric distance): how accurately can head x, y, z and pitch be tracked from a webcam? Can head z relative to shoulder scale serve as a frontal forward-head proxy? Is there any validation against lateral CVA?

### Takeaway
Head rotation from webcam face models is accurate to a few degrees for the best models (3DDFA_V2 ≤ 5.6° against mocap) but was about 11° for MediaPipe in a 2022 clinical test. Single-image head translation is accurate to about 1–1.5 cm on BIWI and about 0.4 cm on ARKitFace. MediaPipe's own translation is "relative" unless the virtual camera matches the real one. No study validates "head z minus shoulder scale" against lateral CVA, so it remains an unvalidated but geometrically plausible proxy, confounded by trunk lean and shoulder protraction.

### Cited Findings
**MediaPipe Face Landmarker and its transform matrix:**
- The landmark model's Z is "relative and is scaled as the X coordinate under the weak perspective projection camera model".
- The Face Transform module builds a "Metric 3D space" with a *virtual perspective camera*. Results improve if its parameters are "as close to the real physical camera parameters as possible".
- The canonical face model defines the metric unit (centimetres). The face pose transformation matrix is a rigid linear map from the canonical model to each frame's landmarks.
— [MediaPipe Face Mesh docs](https://raw.githubusercontent.com/google-ai-edge/mediapipe/master/docs/solutions/face_mesh.md)
- The Face Landmarker transformation matrix is off by default and must be enabled. — [Face Landmarker guide](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker) **[snippet]**
- **WebEyeTrack (2025)** notes MediaPipe's rotation is scale-invariant but its "translation is relative". The authors add a metric-depth refinement step initialised at 60 cm. — [arXiv 2508.19544](https://arxiv.org/pdf/2508.19544) **[snippet]**
- A 2025 jsPsych pull request adding head pose from the matrix notes that sign conventions were "not verified yet". — [jspsych/saccadejs PR #7](https://github.com/jspsych/saccadejs/pull/7) **[snippet; developer note]**

**Head rotation accuracy against mocap:**
- Hammadi et al., *Sensors* 2022 (doi:10.3390/s22186850), compared methods with an optoelectronic mocap baseline:

  | Method | Mean error vs mocap |
  |---|---|
  | 3DDFA_V2 | ≤ 5.6°, depending on plane |
  | MediaPipe | 11.0° |
  | OpenFace 2.0 | 14.1° |

  This is older (2022) and used the legacy Face Mesh. Participant count and camera were not retrieved. — [PMC9502716](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9502716/); [PubMed 36146199](https://pubmed.ncbi.nlm.nih.gov/36146199/) **[snippet]**
- MediaPipe landmarks reportedly degrade beyond about 45° rotation. This is an informal note. — [HF Space demo](https://huggingface.co/spaces/Akjava/mediapipe-head-pose-estimation/blob/73923f5f342026c891615235d0aaec771dc84b80/demo_header.html) **[snippet]**
- **BIWI rotation MAE** is about 3.7–3.8° for img2pose and a 2024 6DoF method. — [img2pose CVPR 2021](https://openaccess.thecvf.com/content/CVPR2021/papers/Albiero_img2pose_Face_Alignment_and_Detection_via_6DoF_Face_Pose_Estimation_CVPR_2021_paper.pdf); [arXiv 2407.14136](https://arxiv.org/html/2407.14136) **[snippet]**

**Head translation accuracy (single RGB image):**
- **TRG (ECCV 2024) supplementary results:**

  | Dataset | Method | Translation MAE | ADD |
  |---|---|---|---|
  | BIWI | TRG | 12.97 | 29.46 |
  | BIWI | Camera-space offset baseline | 13.82 | 31.25 |
  | ARKitFace | Both | about 3.6 | — |

  A companion source gives the units as mm. BIWI has no native translation labels, so its translation ground truth is derived. — [TRG ECCV 2024 supp.](https://www.ecva.net/papers/eccv_2024/papers_ECCV/papers/04824-supp.pdf); [img2pose](https://arxiv.org/pdf/2012.07791) **[snippet]**
- **Markerless neuronavigation (arXiv 2602.07052, 2026), n = 50:**
  - The best markerless method reached a median 2.32 mm / 2.01° versus a marker-based system.
  - That best translation came from *stereo* RGB, while depth sensing was best for rotation. The rig used Azure Kinect devices.
  - A monocular MediaPipe 468-landmark + canonical model + PnP pipeline was among the methods compared, but its own error was not retrieved.
  — [arXiv 2602.07052](https://arxiv.org/html/2602.07052v2); [Pith review](https://pith.science/paper/2602.07052) **[snippet]**
- An older real-time webcam appearance-model method reported about 3.9° rotation and 3.1 cm position error with known calibration. — [Academia.edu](https://www.academia.edu/2803717/Real-Time_Head_Pose_Estimation_Using_a_WEBCAM_Monocular_Adaptive_View-Based_Appearance_Model) **[snippet; older]**

**Forward-head proxies based on head z:**
- A posture write-up estimates forward lean from the MediaPipe z difference between the nose and the shoulder midpoint. It reports no validation. — [ungermate posture detection](https://ungermate.github.io/postureDetection.html) **[snippet]**
- Frontal hobby apps use "eyes sink or face grows" relative to a calibrated baseline. No validation is reported. — [Jamedjo/slouchup](https://github.com/Jamedjo/slouchup) **[snippet]**
- No study was found that compares any frontal head-z or face-scale measure with lateral CVA. A search for "craniovertebral angle from frontal image deep learning" returned only radiograph and cephalogram work. — [search result set, e.g. Cobb-angle papers](https://arxiv.org/pdf/2405.19645) **[negative result]**

**Depth-sensor upper bound for comparison:**
- Xing et al., *iScience* 2023 (Azure Kinect vs OptiTrack): forward-head agreement ICC 0.97 (0.96–0.98), Cohen's d 0.007.
- But forward head was assessed from the **left lateral** view, with the camera at 160–220 cm. The anterior view was used for indices such as uneven shoulders.
— [PMC10551660](https://pmc.ncbi.nlm.nih.gov/articles/PMC10551660/) **[snippet]**

### Inferences
**Pinhole geometry for the head-z-relative-to-shoulders proxy:**
- If the head moves forward by Δz while the shoulders stay put, the face's apparent size grows by Z/(Z−Δz) − 1 relative to shoulder scale:
  - 2 cm at 60 cm gives about 3.4%.
  - 2 cm at 80 cm gives about 2.6%.
  - 1.5 cm at 80 cm gives about 1.9%.
- So a 10° CVA change is roughly a 2–3.5% change in the face-to-shoulder scale ratio. That is about the size of the iris-distance error between people (4.3%), so the proxy can only work as a **within-person change from a calibrated baseline**.
- For a sense of scale (assumption), take a horizontal FOV of about 60° on a 1920-px-wide frame, so f ≈ 1660 px, and a 63 mm inter-pupillary distance (IPD):
  - IPD is about 175 px at 60 cm and about 130 px at 80 cm.
  - A 2.6–3.4% change is then only about 3.5–6 px, which is in the range of plausible landmark jitter (not sourced).
  - Temporal smoothing over seconds would be needed.

**Confounds:**
- **Forward trunk lean** moves the head *and* shoulders toward the camera. The ratio cancels this only if shoulder scale is measured reliably.
- **Shoulder protraction** (rounding) moves the acromions anteriorly and medially. This shrinks *apparent* shoulder width while bringing the shoulders closer, which corrupts shoulder-width-as-depth.
- **Trunk yaw** shrinks shoulder width.
- **Head pitch** foreshortens vertical face dimensions. Horizontal inter-ocular or inter-tragal distance is less pitch-sensitive.

**Why per-person errors are workable:**
- MediaPipe's metric translation depends on the virtual-camera focal length (FOV) and on the user's face matching the canonical face.
- Both errors are roughly constant *per user and setup*. So they scale z multiplicatively and largely cancel in a change-from-baseline measure.
- macOS does not expose the FaceTime HD FOV to apps (prior notes), so a one-time calibration, for example the user sitting at a known distance, would fix the scale.

**Pitch:**
- With MediaPipe's 11° mean error against mocap (2022 version), absolute neck-flexion angles from face pitch are not trustworthy.
- Changes from a baseline are likely more useful, but no within-subject repeatability figure was found.
- 3DDFA_V2-class models (≤ 5.6°) are better but are a separate model to run.

**Single-image translation accuracy versus the signal:**
- About 13 mm on BIWI is close to the 15–20 mm per 10° CVA signal.
- Temporal averaging and a fixed camera should improve within-person repeatability, but this is not quantified anywhere.

### Gaps
- No validation of MediaPipe Face Landmarker (2023+ model) transformation-matrix translation or pitch against mocap was found. Only the legacy 2022 result exists.
- The monocular MediaPipe + PnP error from the 2026 neuronavigation paper (n = 50) was not retrieved. This is the most relevant recent number and the report writer should try to obtain it.
- No 3DMM (DECA, EMOCA, FLAME, MICA) head-translation validation at desk distance was found.
- Nothing links head-z or face-scale change to lateral CVA or to tragus displacement in mm.
- No within-subject test–retest numbers exist for face-scale or iris distance over a workday.

---

## Q3. Person segmentation, silhouettes and contour features (Apple VNGeneratePersonSegmentationRequest, MediaPipe selfie segmentation, SAM-family): has upper-body silhouette shape (visible neck length, shoulder contour slope, shoulder width relative to head) been used to detect slouching or rounded shoulders from the front?

### Takeaway
No peer-reviewed study was found that validates silhouette or contour features from a frontal webcam for slouching, neck flexion or rounded shoulders against any reference. Evidence is limited to hobby projects and older segmentation work, which report that skin- or cloth-colour segmentation of the neck and shoulders is fragile. Modern person mattes (Apple Vision, MediaPipe) make the contour available cheaply, but its posture meaning is unvalidated.

### Cited Findings
- **Apple Vision APIs:**
  - `VNGeneratePersonSegmentationRequest` is available from **macOS 12**. It "produces a matte image for a person it finds in the input image" and has a `qualityLevel` setting that balances accuracy and performance.
  - `VNGeneratePersonInstanceMaskRequest` produces per-person masks.
  — [Apple docs: VNGeneratePersonSegmentationRequest](https://developer.apple.com/documentation/vision/vngeneratepersonsegmentationrequest)
- A patent on neck and shoulder landmark detection notes that skin-colour segmentation "often do[es] not provide an accurate neck location". Cloth-colour upper-body segmentation "fail[s] on very colorful cloth or large random patterns", and GrabCut and snakes are too slow for real time. — [US 9,569,661](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9569661) **[snippet; older]**
- A head-neck-shoulder contour classifier uses the distance from the contour centroid to the top of the bounding box. This is a detection paper, not a posture paper. — [arXiv 1307.5591](https://arxiv.org/pdf/1307.5591) **[snippet; older]**
- dziper/slouch: the user marks a rectangle on their shirt, a colour mask is built, and calibrated shoulder lines flag slouching. No validation. — [GitHub dziper/slouch](https://github.com/dziper/slouch) **[snippet]**
- A vendor blog claims MediaPipe upper-body landmarks are within 2–5 cm of marker-based systems. This is an unverified vendor claim. — [sitsense.app blog](https://www.sitsense.app/blog/what-is-webcam-posture-tracking) **[snippet]**

### Inferences
**What a frontal matte could add (all unvalidated):**
- (a) **Visible neck height:** the vertical gap between the chin or jaw contour and the shoulder line or collar edge shrinks with neck flexion *and* with shoulder elevation.
- (b) **Shoulder contour slope** (trapezius line), which relates to shoulder elevation.
- (c) **Head-to-shoulder width ratio** (see the Q2 confounds).
- (d) **Silhouette area and centroid drift,** which track gross lean.

**Why the matte boundary is a weak measurement:**
- It is the *clothing* boundary, so hoods, collars, long hair and headphones change the "neck" and "shoulder" contour without any posture change.
- With the camera above the monitor looking down, neck flexion and head protraction both make the chin cover more of the neck. The silhouette therefore cannot separate them.

**Practical role:** the most defensible use is as a *change detector against the user's own baseline*, with the same clothing in the same session. It could also serve as a quality gate, for example "shoulders not visible or occluded, so suppress shoulder metrics", rather than a posture measurement.

### Gaps
- No study was found that validates SAM, SAM2 or MediaPipe selfie-segmentation contour features against side-view photos, mocap or clinical scores for seated posture.
- No data was found on how clothing (collars, hoods, hair) biases frontal contour-based neck or shoulder measures.

---

## Q4. Frontal-view measures of shoulder protraction or rounded shoulders, and of neck flexion (photogrammetry: shoulder width ratio, acromion-to-midline distance, apparent neck length): any validation against side-view or clinical measures?

### Takeaway
The photogrammetry literature measures rounded shoulders and forward head mainly from the **sagittal** view. Frontal-plane photographic measures are reliable for shoulder *height asymmetry* (elevation and tilt) but correlate only poorly to moderately with radiographs. No validated frontal-view measure of shoulder protraction or of neck flexion was found.

### Cited Findings
- **Four objective forward-shoulder techniques** (JOSPT 1997): Baylor square, double square, Sahrmann, and scapular position. Intrarater reliability was reported for each (ICCs garbled in the extracted text, roughly 0.91 for the best). But "validity compared with the radiographic measurement could not be established". This is an older study. — [JOSPT 1997;25(1):34](https://www.jospt.org/doi/10.2519/jospt.1997.25.1.34) **[snippet]**
- **Digital photography for shoulder balance in idiopathic scoliosis:**
  - Intra- and inter-observer reliability was "excellent–near perfect", but frontal LRTA inter-observer ICC was 0.65.
  - Frontal SHA/AHA concordance was poor (CCC 0.66).
  - Correlation with radiological parameters was "poor to moderate".
  — [PMC4269069](https://pmc.ncbi.nlm.nih.gov/articles/PMC4269069/) **[snippet]**
- **Adolescent cervical and shoulder photogrammetry:** shoulder-angle intra-rater ICC 0.78, SEM 1.64–2.35. This used a *sagittal* view. — [PMC4183261](https://pmc.ncbi.nlm.nih.gov/articles/PMC4183261/) **[snippet]**
- Scapular position tests in people with forward neck and rounded shoulders: ICC 0.802–0.935. These are tape or caliper tests, not photographs. — [Kim et al. 2024, IES-230161](https://doi.org/10.3233/IES-230161) **[snippet]**
- The **scapular index** (sternal notch to coracoid ÷ posterolateral acromion to T-spine × 100) is tape-based, not photographic. — [Physiotutors: Scapular alignment](https://www.physiotutors.com/wiki/scapular-alignment/) **[snippet]**
- **Comparison point for neck flexion:**
  - Commercial IMU versus optical mocap for neck flexion/extension: 2.9 ± 0.9° error.
  - RULA scores neck flexion of 10–20° as 2 points.
  — [J Appl Biomech 2017, jab.2016-0120](https://doi.org/10.1123/jab.2016-0120); [Sci Rep 2025 RULA reliability](https://www.nature.com/articles/s41598-025-85159-z) **[snippet]**
- **"Posture Lab" (Wearable Technologies, June 2025):** a webcam with **ArUco markers** for head position, CVA and shoulder angles, plus accelerometers. It was tested on a **manikin**. This is marker-based, not markerless, and not tested on humans. — [ResearchGate 392723680](https://www.researchgate.net/publication/392723680_Quantifying_sitting_posture_A_pilot_feasibility_study_of_computer_vision_and_wearable_sensors_Posture_Lab_using_a_manikin_model) **[snippet]**
- No webcam head-pitch validation against an IMU or mocap during office work was found. — [search negative; see IMU validation literature above](https://doi.org/10.1123/jab.2016-0120)

### Inferences
**What a frontal view can and cannot show:**
- From the front, shoulder **elevation** (vertical acromion or contour position relative to the eyes or ears) and **lateral asymmetry** (tilt) are in-plane and measurable. Prior notes say they are reasonably reliable in 2D.
- **Protraction** is mostly an anterior–medial displacement. In a frontal image it appears only as a small *narrowing* of apparent biacromial width, plus a scale change.
- A frontal "shoulder width ÷ face width" or "shoulder width ÷ inter-ocular" ratio is therefore at best a within-person change indicator. It is confounded by trunk yaw, forward lean and clothing.

**Neck flexion:** from the front it appears as face pitch plus reduced visible neck height. Face pitch from a webcam has 5–11° error against mocap (Q2), which is larger than the 10° RULA band width.

### Gaps
- No study was found that compares any frontal-image index of shoulder width or acromion position with a side-view acromion-to-wall, scapular-index or radiographic measure of protraction.
- No study was found that validates "apparent neck length" from a frontal image against neck flexion or CVA.

---

## Q5. Dense correspondence and body-surface methods (DensePose, SMPL-X fitting limited to the upper body, Apple 3D body pose) for seated frontal views: any validation of trunk flexion or head protraction?

### Takeaway
None was found beyond what earlier notes covered: SMPL-family methods are unvalidated for seated spine or CVA. One new platform detail is that Apple's 3D body pose uses an assumed **reference height** for metric scale when no LiDAR is present, as on an iMac. Its "metres" are therefore scaled by an assumption, not measured.

### Cited Findings
- **Apple `VNDetectHumanBodyPose3DRequest`** (macOS 14+) "detects points on human bodies in 3D space, relative to the camera" and uses depth data "if the system allows it".
  - `bodyHeight` is "accurate" only when `heightEstimation == .measured`, which "uses LiDAR depth data". Otherwise it uses `.reference`, "a reference height".
  - The observation also exposes `cameraOriginMatrix` (hip-to-camera transform) and `cameraRelativePosition(_:)`.
  — [Apple docs: VNDetectHumanBodyPose3DRequest](https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest); [VNHumanBodyPose3DObservation](https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation); [bodyHeight](https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/bodyheight)
- **Monocular multi-person 3D pose (ROMP)** in an ergonomics setting: joint-angle MAE 9.4°. — [Applied Ergonomics 2023](https://www.sciencedirect.com/science/article/abs/pii/S016981412300032X) **[snippet; older]**
- **Monocular back-depth and spine-morphology estimation from RGB** (arXiv 2507.22691, 2025) targets a bare back from behind, not a seated frontal view. — [arXiv 2507.22691](https://arxiv.org/pdf/2507.22691) **[snippet]**
- **Monocular pose models versus mocap for clinical movement** (Sci Rep 2025) covers exercise movements, not sitting. — [Sci Rep s41598-025-22626-7](https://www.nature.com/articles/s41598-025-22626-7) **[snippet]**
- No DensePose or upper-body SMPL-X study validating trunk flexion or head protraction in sitting was found in this session.

### Inferences
**Apple 3D body pose on an iMac:** absolute joint depths are set by a height prior. A user who differs from the reference height gets proportionally scaled z. Like Q2, this is a constant factor per user, so changes from baseline remain interpretable, but absolute centimetres do not.

**Lower body hidden by the desk:**
- The hip root is occluded, and the SMPL and Apple skeletons are rooted at the hip. The 3D trunk orientation is therefore inferred from the prior rather than observed.
- Expect it to be biased toward "upright" and insensitive to slumping. This follows from model design and is not tested.

### Gaps
- No accuracy evaluation of Apple 3D body pose was found, consistent with prior notes. Nor was any evaluation for occluded-hip seated frontal views.
- Whether `VNDetectHumanBodyPose3DRequest` runs on Intel Macs, which have no Neural Engine, is still unconfirmed.

---

## Q6. Updates to earlier conclusions, and which measures are validated versus unvalidated on the target setup

### Takeaway
Nothing found contradicts the earlier conclusion that **no frontal-webcam method is validated against lateral CVA**. The new evidence adds three things. Single-image head 6DoF error is about 1–1.4 cm translation (BIWI) and 5–11° rotation against mocap. Human-centric and metric depth models now exist (Sapiens 2024, UniDepthV2, Depth Pro, DA3 2025, THFM 2026) but have no posture validation. Depth-camera FHP validation (ICC 0.97) relied on a lateral view.

### Cited Findings
- Earlier "~78% 3D-pose FHP classifier" (JMIR Formative 2024): reconfirmed at 78.27% test accuracy, with lower recall for FHP than the baseline. — [JMIR Form Res 2024;e55476](https://formative.jmir.org/2024/1/e55476) **[snippet]**
- An adolescent FHP detector from body landmarks (photogrammetry + OpenPose) with a genetic algorithm reached 82.4% accuracy (95% CI 75.7–87.9%). The view used was not confirmed. — [BMC Med Inform Decis Mak 2023, s12911-023-02285-2](https://bmcmedinformdecismak.biomedcentral.com/articles/10.1186/s12911-023-02285-2) **[snippet]**
- A monitor-mounted Kinect FHP detector reported 98.0% detection accuracy with a 2.0% false-alarm rate. This used a depth sensor, is older, and the evaluation conditions were not retrieved. — [PreventFHP, ResearchGate 271425853](https://www.researchgate.net/publication/271425853_D06_PreventFHP_Detection_and_warning_system_for_Forward_Head_Posture) **[snippet]**
- Azure Kinect forward head ICC 0.97 against OptiTrack used a lateral view at 160–220 cm. — [PMC10551660](https://pmc.ncbi.nlm.nih.gov/articles/PMC10551660/) **[snippet]**
- MediaPipe head rotation error is 11.0° against 3DDFA_V2's ≤ 5.6° (mocap reference, 2022). — [PMC9502716](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9502716/) **[snippet]**
- Single-image head translation MAE is about 13 mm on BIWI and about 3.6 mm on ARKitFace. — [TRG ECCV 2024 supp.](https://www.ecva.net/papers/eccv_2024/papers_ECCV/papers/04824-supp.pdf) **[snippet]**

### Inferences
**Validated versus unvalidated on this setup:**

| Measure | Status |
|---|---|
| Head rotation (yaw, pitch, roll) | Validated against mocap in general head-pose literature, not in a posture context |
| Head 3D translation | Validated on head-pose datasets (BIWI, ARKitFace), not at a desk |
| Shoulder elevation and tilt (2D) | Reliability shown in photogrammetry (prior notes) |
| Head-forward via face scale or z relative to shoulders | Unvalidated proxy |
| Monocular-depth face–shoulder offset | Unvalidated proxy |
| Silhouette neck length and contour slope | Unvalidated proxy |
| Frontal shoulder-width protraction index | Unvalidated proxy |
| Apple 3D body pose trunk angles | Unvalidated proxy |

**Lab versus real work:** all quantitative numbers above come from lab or dataset conditions (instructed head movements, posed images). None comes from real desk work with natural clothing, lighting changes, glasses, hands on the face or partial occlusion.

**Not diagnostic:** since none of these maps validly to a clinical angle, a non-diagnostic app should report them as *change relative to the user's own calibrated baseline* (for example "head about X% closer relative to shoulders than at calibration"). It should not report them as CVA, "forward head posture" or a recommended correction direction.

**Cheapest new signal on the Intel iMac:** the MediaPipe Face Landmarker transformation matrix gives head translation and rotation with no extra model cost. Combined with 2D shoulder keypoints and an iris or one-time distance calibration, it is the cheapest new signal. Monocular depth (DA-V2-Small, DA3-Small, VDA-Small metric) is a heavier optional cross-check whose benefit is unproven.

**A local validation step is feasible within the constraints.** One way is to record **derived numbers only, no frames**, while simultaneously taking occasional side-view phone photos as ground truth: tragus and C7 stickers measured in the photo, then the photo deleted. This would give a per-user correlation or Bland–Altman check of each proxy against CVA. The literature does not provide this.

### Gaps
- No 2023–2026 study evaluates a frontal webcam forward-head proxy against lateral CVA in real (non-instructed) desk work.
- No head-pose or depth accuracy numbers exist for people wearing glasses, or under low light, for the built-in iMac camera specifically.
