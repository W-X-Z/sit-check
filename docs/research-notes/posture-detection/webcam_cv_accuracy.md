# Accuracy and validity of seated-posture measurement from a single frontal desk webcam (2D pose, monocular 3D pose, face landmarks/head pose, viewing distance)

_Verification note: most publisher sites (PubMed/PMC, arXiv, MDPI, JMIR, PeerJ, SAGE, Google Research blog, TF blog, Wikipedia) were blocked by the network proxy. Items tagged **[snippet]** come from search-engine abstracts/summaries and were **not** checked against full text. Untagged items come from pages read directly: GitHub-hosted docs/READMEs, the BlazePose GHUM 3D model card PDF, and Apple developer docs/WWDC transcripts. Items tagged **(inference)** are my own reasoning or geometric calculations, not published results._

---

## Q1. How accurate are 2D pose estimators (OpenPose, MediaPipe/BlazePose, MoveNet, HRNet, Apple Vision) for a seated user with the lower body hidden, especially shoulders, ears, nose and neck? How does keypoint confidence behave at frame edges?

### Takeaway
Published 2D accuracy figures come from full-body scenes 2–4 m from the camera, scored with a lenient metric (PCK@0.2: a keypoint counts as correct if it is within 20% of torso diameter). They say almost nothing about centimetre-level accuracy of ears and shoulders for a close-range, desk-occluded upper body. In Google's comparison, Apple Vision scored lowest (82.7–91.4% PCK@0.2). Apple and Google both state that accuracy drops near frame edges, with occlusion or loose clothing, and when the model's expected input (a full-body crop with a margin) is not available. In small lab studies, simple 2D frontal-plane signs (head tilt, lateral trunk lean) reach near-expert agreement. Shoulder elevation is the weakest frontal measure.

### Cited Findings
- **MediaPipe PCK@0.2 benchmark** (Yoga / Dance / HIIT):
  - BlazePose GHUM Heavy: 96.4 / 97.2 / 97.5
  - BlazePose GHUM Full: 95.5 / 96.3 / 95.7
  - BlazePose GHUM Lite: 90.2 / 92.5 / 93.5
  - AlphaPose ResNet50: 96.0 / 95.5 / 96.0
  - Apple Vision: 82.7 / 91.4 / 88.6
  - The validation sets contain "only a single person located 2-4 meters from the camera." Google ran this comparison on its own datasets. — [MediaPipe Pose docs (GitHub)](https://github.com/google/mediapipe/blob/master/docs/solutions/pose.md)
- **How PCK@0.2 / PDJ is scored:** a keypoint counts as correct if its predicted visibility matches ground truth and its 2D error, normalised by the projected torso diameter, is under 20%. Google chose 20% as "the maximum value that does not degrade accuracy in classifying pose / asana". z is excluded from the evaluation because it comes from synthetic data. — [BlazePose GHUM 3D model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20BlazePose%20GHUM%203D.pdf)
- **BlazePose input assumptions** — [model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20BlazePose%20GHUM%203D.pdf):
  - The crop is a full body, "centered by mid-hip", with a single person in the centre and a 25% margin around the full-body square.
  - The model tolerates only "10% shift and scale" and "8° roll" of that crop.
  - It "is sensitive to face position, scale and orientation in the input image".
  - Quality degrades and "jittering" increases with degraded light, noise, motion or face overlap.
  - Out of scope: multiple people, people further than about 4 m, "Head is not visible", and "Applications requiring metric accurate depth".
- **Occluded points are guessed, not flagged.** Training data annotated hidden points with a "best guess", and with missing limbs the model "degrades gracefully by predicting average point location". — [model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20BlazePose%20GHUM%203D.pdf)
- **Confidence outputs:**
  - *visibility* = probability that the keypoint is in the frame **and** not occluded.
  - *presence* = probability that it is in the frame only; it "does not indicate whether the keypoint is occluded".
  - Both are raw values that need a sigmoid applied. — [model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20BlazePose%20GHUM%203D.pdf); [MediaPipe Pose docs](https://github.com/google/mediapipe/blob/master/docs/solutions/pose.md)
- **BlazePose fairness evaluation** (1,400 smartphone rear-camera photos, 14 regions):
  - Mean PDJ: Heavy 94.2%, Full 91.8%, Lite 87.0%.
  - Range across skin tones for Full: 85.9–92.9%.
  - Human inter-annotator PDJ: 97.5%. — [model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20BlazePose%20GHUM%203D.pdf)
- **Apple Vision body pose (WWDC20):**
  - Joints: nose, eyes, ears, shoulders, elbows, wrists, "neck" (the point between the shoulders), hips, "root" (between the hips), knees, ankles.
  - Each point has a confidence value; Apple's sample code drops points with confidence ≤ 0.1.
  - Stated failure conditions: people bent over or upside down; "obstructive flowing clothing"; one person occluding another; "results may get worse if the subject is close to the edges of the screen"; with several people, the largest is used by default. — [WWDC20 "Detect Body and Hand Pose with Vision"](https://developer.apple.com/videos/play/wwdc2020/10653/)
- **"A Deep Dive Into MediaPipe Pose for Postural Assessment"** (IEEE; 24 healthy subjects; static 40-s postural tasks; compared with a marker-based gold standard and Azure Kinect): all 2D models showed "excellent performance in frontal plane analysis, albeit with some limitations for specific angular measurements". The authors recommend 2D models for "lightweight front-view applications". Conditions were standing/full-body, not desk-occluded. — [IEEE Xplore 11297977](https://ieeexplore.ieee.org/document/11297977/) **[snippet]**
- **Sensors 2026, frontal monocular RGB processed on-device in the browser.** 18 healthy adults simulated compensations; two clinicians, blind to the instructed condition, annotated.
  - Overall macro-F1 against the individual raters: 0.75 and 0.72.
  - Head tilt and lateral trunk lean were "near-expert" (F1 0.94 and 0.92 against consensus).
  - Shoulder-girdle elevation was weakest, because "a single frontal view cannot fully disentangle it from the abduction motion".
  - Reported κ: trunk lean 0.97, head tilt 0.93, shoulder elevation 0.73, inter-limb asymmetry 0.62. The snippet does not make clear whether κ is system-vs-rater or rater-vs-rater.
  - Small sample; healthy adults; exaggerated, simulated compensations. — [Sensors 2026, doi:10.3390/s26165054](https://doi.org/10.3390/s26165054) **[snippet]**
- **Telework CNN posture system** (video; posture class per body region):
  - Accuracy: neck 0.938, shoulders 0.979, right arm 0.906, left arm 0.860, mean 0.924.
  - Up to 25 fps.
  - These are posture-category accuracies, not keypoint errors. — [Sensors 2021, 21(15):5236](https://doi.org/10.3390/s21155236) **[snippet]**
- **Jumping-jack comparison:** MediaPipe Pose, MoveNet and PoseNet reached about 92%, OpenPose about 72%, and OpenPose had the most jitter. This is an exercise task, not a seated one. — [Future Internet 2022, 14(12):380](https://www.mdpi.com/1999-5903/14/12/380) **[snippet; attribution probable]**

### Inferences
- **(inference) PCK@0.2 is far too coarse for posture work.** An adult's torso diameter (shoulder to opposite hip) is roughly 50–60 cm, so the 20% tolerance is about 10–12 cm. A model can score ">95% PCK@0.2" and still be wrong by several centimetres on a shoulder, which is larger than the 1–2 cm asymmetries or ear–shoulder changes a posture coach would track. The torso-size figure is my estimate.
- **(inference) A desk close-up breaks BlazePose's assumptions.** The hips are hidden behind the desk or out of frame, but BlazePose's crop is hip-centred and expects a full body plus a 25% margin. Hidden hips get "best guess" or average positions, which can pull the shoulder and torso estimates toward a population-average pose.
- **(inference) Shoulders sit near the frame edge.** At 50–70 cm from a built-in camera, the shoulders are often near the bottom edge, where Apple says results get worse.
- **(inference) Treat low-confidence frames as missing.** Gate every measurement on per-point visibility/confidence and on distance from the frame border, rather than reading a low-confidence frame as a posture change.
- **(inference) No standard keypoint gives C7 or the sternum.** Apple's "neck" is the shoulder midpoint, not C7, and neither Apple nor COCO-style models output a sternum point. Clinical forward-head angles cannot be computed directly from these keypoints (see Q2).

### Gaps
- I found no study that reports pixel or centimetre keypoint errors for ears and shoulders of seated users at 50–80 cm with the desk occluding the lower body. Apple Vision on macOS has no published keypoint accuracy at all.
- No quantitative data on how confidence decays as a keypoint approaches the frame edge; only qualitative statements from Apple and Google.
- MoveNet and HRNet: no seated or upper-body-specific validation numbers were retrieved. A 2024 Journal of Bodywork & Movement Therapies study compared HRNet and MediaPipe against motion capture (22 volunteers; knee and elbow only), but its numbers were not retrieved — [JBMT 40 (2024) 315–319](https://www.sciencedirect.com/science/article/pii/S1360859224002213).
- Effect of clothing (hoodies, loose shirts) on shoulder keypoints: qualitative only (Apple).

---

## Q2. Can forward head posture / craniovertebral angle (CVA) be estimated from a frontal view? What frontal proxies have been tried, and how well do they correlate with lateral-view CVA?

### Takeaway
No. CVA is a sagittal-plane angle defined by C7 and the ear tragus, and reliable measurement uses lateral photographs, usually with skin markers. No frontal-view or webcam method validated against lateral CVA was found.
- The only frontal-plane proxy with a published correlation (the angle from the sternum midpoint to both tragi) showed only a "moderate" correlation. It also needs a sternum landmark that pose models do not output.
- Frontal heuristics used in apps (face size, ear–shoulder angle or distance) are unvalidated.
- A 3D-pose classifier for forward head posture reached about 78% accuracy, in a feasibility study.

### Cited Findings
- **Definition:** CVA is the angle between a horizontal line through the C7 spinous process and a line from the ear tragus to C7. A smaller CVA means more forward head posture. — [Physiopedia – CVA](https://www.physio-pedia.com/Craniovertebral_angle)
- **Cut-off:** CVA < 48–50° is commonly used to define forward head posture. — [JMIR Formative Research 2024](https://formative.jmir.org/2024/1/e55476) **[snippet]**
- **Seated protocol:** two lateral photographs in relaxed sitting without back support, with markers on C7 and the tragus. — [Assessment of FHP and Ergonomics in Young IT Professionals (PMC9987472)](https://pmc.ncbi.nlm.nih.gov/articles/PMC9987472/) **[snippet]**
- **Noise in the reference method:**
  - PostureScreen Mobile CVA: intra-rater ICC 0.88; inter-rater ICC 0.83–0.89. — [PMC7559098](https://pmc.ncbi.nlm.nih.gov/articles/PMC7559098/) **[snippet]**
  - Smartphone photogrammetry: SEM about 0.92–1.02° and minimal detectable change (MDC) about 2.56–2.84°. CVA is significantly lower sitting than standing, with ICC 0.972–0.991 in both positions. — [Clinimetric properties of a smartphone app to measure CVA (PubMed 37810069)](https://pubmed.ncbi.nlm.nih.gov/37810069) **[snippet; assigning these exact figures to this paper is likely but unverified]**
  - Photographic CVA, sagittal head tilt and sagittal shoulder–C7 angle have been shown valid against radiographs. — [Photogrammetric Assessment of Upper Body Posture Using Postural Angles: A Literature Review (2017)](https://pubmed.ncbi.nlm.nih.gov/28559753/) **[snippet]**
- **Automated CVA still needs a side view and markers.** AutoMCA uses MediaPipe Pose for head–neck segmentation plus colour-marker detection on lateral images. It correlates r > 0.98 with manual Kinovea for CVA and cranial rotation angle, including in people with neck disorders. — [AutoMCA, Automation 2025, doi:10.3390/automation6040088](https://doi.org/10.3390/automation6040088) **[snippet]**
- **Frontal-plane proxy (Molaeifar, Yazdani, Kordi Yoosefinejad, Karimi 2021, *Work* 68(4):1221–1227):**
  - Forward head posture was induced experimentally.
  - "A moderate correlation" was found between 3-D CVA and the angle formed between the sternum and both tragi, in the whole sample and in each sex. The authors conclude that changes in sagittal CVA "can be predicted" from this frontal angle.
  - 3-D CVA also correlated moderately and negatively with height, weight and BMI, and in men with hours on digital devices.
  - The r values and sample size were not retrieved. — [SAGE / Work](https://journals.sagepub.com/doi/abs/10.3233/WOR-213451); [PubMed 33867381](https://pubmed.ncbi.nlm.nih.gov/33867381/) **[snippet]**
- **Pose models lack C7:** "most computational pose models do not include measurements of the craniovertebral angle, which involves the C7 vertebra." — [JMIR Formative Research 2024](https://formative.jmir.org/2024/1/e55476) **[snippet]**
- **3D-pose forward head posture classifier** (graph convolutional network on 3D pose estimated from 2D images; Sungkyunkwan University / Seoul National University):
  - Test accuracy 78.27% using all upper-body keypoints.
  - Macro F1 77.54%, versus 75.88% for a feed-forward network baseline. The baseline had higher precision for forward head posture but lower recall.
  - Labelled a "development and feasibility study". — [JMIR Formative Research 2024;8:e55476](https://formative.jmir.org/2024/1/e55476) **[snippet]**
- **Unvalidated frontal heuristics in hobby or commercial apps:**
  - Posture Pal infers head-to-monitor distance from the width of a Haar-cascade face box. — [Hackster: Posture Pal](https://www.hackster.io/justin-shenk/posture-pal-computer-vision-cbe67c)
  - postureCV uses the ear-to-shoulder vector angle relative to vertical and claims it is invariant to distance. — [GitHub: postureCV](https://github.com/richardli52/postureCV)
  - Zen calibrates on the user's own "good posture" using PoseNet. — [TechCrunch 2022](https://techcrunch.com/2022/04/29/zen-pre-seed-posture-correction/)
  - One open-source monitor deliberately uses a side-mounted webcam to flag slouching and forward head posture. — [GitHub: Bad_Posture_Detection](https://github.com/Sathwik-11/Bad_Posture_Detection)
  - None of these report validation against CVA.

### Inferences
- **(inference, geometry) How much does forward head posture actually move the head?** Assume a C7–tragus distance of 12–15 cm.
  - Reducing CVA by 10° (50°→40°) moves the tragus about 1.5–1.9 cm forward **and** about 1.5–1.9 cm down relative to C7.
- **(inference) In a frontal image both components are ambiguous:**
  - The forward component appears only as a ~2–3% increase in face size at 50–70 cm. Leaning the whole trunk 1.5 cm forward or rolling the chair closer produces the same change.
  - The downward component is roughly 25–35 px (1280 px frame, about 60° horizontal FOV, 50–60 cm). It is also produced by thoracic slumping, shoulder elevation, head flexion and camera-elevation perspective (Q7).
  - Frontal proxies are therefore non-specific for forward head posture.
- **(inference) Only relative drift is defensible.** Absolute forward-head thresholds (CVA < 48–50°) cannot be applied to frontal data. At most, a sustained "head lower and larger than this user's baseline" can be shown as a non-diagnostic cue.
- **(inference) Validation bar.** Because the reference method itself has an MDC of about 2.5–2.8°, any frontal proxy would need to resolve changes of that size to be clinically meaningful. Nothing found shows a frontal proxy can.

### Gaps
- Molaeifar 2021: r, n, posture (standing or sitting) and marker setup not retrieved; no webcam or markerless replication found.
- No published validation found of face-size change, ear–shoulder vertical distance, the (ear–shoulder) ÷ shoulder-width ratio, or head pitch against lateral CVA.
- JMIR 2024: sample size, camera view and source of ground-truth labels not retrieved.

---

## Q3. How accurate is monocular 3D human pose lifting for the upper body, and is it usable for forward-head or slouch detection?

### Takeaway
Root-relative 3D error is about 37–39 mm on the lab benchmark Human3.6M (MotionBERT) and about 36–45 mm reported for BlazePose GHUM. Mesh error in the wild is about 88 mm. BlazePose's depth is explicitly "not metric but up to scale", comes from synthetic GHUM fitting, and metric-depth applications are out of scope. A postural-assessment study found that MediaPipe's 3D uplifting introduced distortions **and asymmetries**. The forward-head signal (about 1.5–2 cm per 10° of CVA) is smaller than these errors. Monocular 3D is therefore not usable for absolute forward-head or thoracic-flexion measurement from a desk webcam.

### Cited Findings
- **MotionBERT:**
  - Human3.6M MPJPE 39.2 mm (trained from scratch), 37.2 mm (fine-tuned).
  - 3DPW mesh MPVE 88.1 mm.
  - Uses 17 H3.6M keypoints and input sequences of up to 243 frames. — [MotionBERT GitHub (ICCV 2023)](https://github.com/Walter0807/MotionBERT)
- **BlazePose GHUM Holistic:**
  - MPJPE 36 mm (Heavy), 39 mm (Full), 45 mm (Lite).
  - Depth-ordering errors of the fitted GHUM reconstructions fell from 25% to 3% after adding depth-order annotation.
  - Evaluation dataset and protocol not verified. — [arXiv 2206.11678](https://arxiv.org/pdf/2206.11678) **[snippet]**
- **BlazePose model card on z:**
  - z is "measured in 'image pixels'", relative to the hip plane; "Z is not metric but up to scale".
  - It is obtained "by fitting synthetic data (GHUM model) to the 2D annotation".
  - "Applications requiring metric accurate depth" and "Head is not visible" are out of scope. — [model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20BlazePose%20GHUM%203D.pdf)
- **MediaPipe world landmarks** are 3D coordinates in metres with the origin "at the center between hips". — [MediaPipe Pose docs](https://github.com/google/mediapipe/blob/master/docs/solutions/pose.md)
- **Deep Dive study** (24 subjects; compared with marker-based and Azure Kinect):
  - 3D performance degraded "counterintuitively" as model complexity increased.
  - The high-complexity model "introduced severe distortions and asymmetries, which originated from the 3D-uplifting process rather than robust 2D tracking".
  - Conclusion: 3D MediaPipe "should be used with caution for quantitative postural assessment". — [IEEE Xplore 11297977](https://ieeexplore.ieee.org/document/11297977/) **[snippet]**
- **Apple `VNDetectHumanBodyPose3DRequest`** (macOS 14+): detects body points "in 3D space, relative to the camera" and uses `AVDepthData` "if the system allows it" to improve accuracy. Apple publishes no accuracy figures. — [Apple docs](https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest)
- **Forward-head classification from 3D pose:** 78.27% accuracy (see Q2). — [JMIR Formative 2024](https://formative.jmir.org/2024/1/e55476) **[snippet]**

### Inferences
- **(inference) Error is the same size as or larger than the signal.** About 1.5–2 cm of tragus displacement per 10° of CVA (Q2) compares with 36–45 mm mean joint error on lab benchmarks, and depth is the least-constrained axis. Temporal averaging reduces jitter but not systematic biases, such as priors pulling toward an average body or a missing hip origin when the hips are under the desk.
- **(inference) No depth on this hardware.** The Intel iMac's FaceTime HD camera supplies no depth data, so Apple's 3D request would run purely monocularly. It is also unknown whether it was validated on close, upper-body-only framing.
- **(inference) Asymmetry artefacts matter here.** 3D uplifting has been shown to create spurious asymmetries. For a user whose possible trunk asymmetry is undiagnosed, a 3D pipeline could invent asymmetry or hide real asymmetry. That argues against option A's "3D pose for forward head".

### Gaps
- No validation found of monocular 3D lifting for CVA or thoracic flexion in a seated desk view (beyond the JMIR classification result).
- Apple's 3D body-pose accuracy is unpublished, and its runtime behaviour on Intel (non-Neural-Engine) Macs is undocumented in the sources found.

---

## Q4. How accurate is head pose (yaw/pitch/roll) from face images/landmarks (BIWI, AFLW2000), and how do glasses, lighting and extreme angles affect it?

### Takeaway
On benchmarks, the best dedicated head-pose networks reach about 4.0° mean absolute error (MAE) on AFLW2000 and about 2.7° on BIWI (in-domain 70/30 split); older models reach about 5–6°. **Pitch is consistently the worst axis** (4.9–6.6° on AFLW2000). Apple publishes no accuracy for `VNFaceObservation`. Before face-detector revision 3, roll and yaw were returned in **discrete bins**; revision 3 (macOS 12+) added pitch and made all three continuous. Glasses, lighting and extreme poses are named as error sources, but no quantitative effect sizes were found.

### Cited Findings
- **AFLW2000** (trained on 300W-LP), MAE in degrees (yaw / pitch / roll / mean):

  | Model | Yaw | Pitch | Roll | Mean |
  |---|---|---|---|---|
  | HopeNet | 6.47 | 6.56 | 5.44 | 6.16 |
  | FSA-Net | 4.50 | 6.08 | 4.64 | 5.07 |
  | WHENet | 5.11 | 6.24 | 4.92 | 5.42 |
  | QuatNet | 3.97 | 5.62 | 3.92 | 4.50 |
  | TriNet | 4.04 | 5.77 | 4.20 | 4.67 |
  | FDN | 3.78 | 5.61 | 3.88 | 4.42 |
  | 6DRepNet | 3.63 | 4.91 | 3.37 | 3.97 |

  — [6DRepNet GitHub](https://github.com/thohemp/6DRepNet) (Hempel et al., IEEE TIP 33 (2024) 2377–2387)
- **BIWI** (70/30 split), MAE in degrees (yaw / pitch / roll / mean):

  | Model | Yaw | Pitch | Roll | Mean |
  |---|---|---|---|---|
  | HopeNet | 3.29 | 3.39 | 3.00 | 3.23 |
  | FSA-Net | 2.89 | 4.29 | 3.60 | 3.60 |
  | TriNet | 2.93 | 3.04 | 2.44 | 2.80 |
  | FDN | 3.00 | 3.98 | 2.88 | 3.29 |
  | 6DRepNet | 2.69 | 2.92 | 2.36 | 2.66 |

  — [6DRepNet GitHub](https://github.com/thohemp/6DRepNet)
- **Apple face pose (WWDC21):** "Previously, we have provided roll and yaw metrics only. Most metrics are reported in radians and their values are returned in discrete bins. With the new revision introduction, we're also adding a pitch metric … We're also making all three metrics reported in continuous space."
  - Revision 3 also detects masked faces.
  - Face-landmarks revision 3 provides a "76-point constellation" and "accurate pupil detection". — [WWDC21 "Detect people, faces, and poses using Vision"](https://developer.apple.com/videos/play/wwdc2021/10040/)
- **API details:**
  - `VNDetectFaceRectanglesRequestRevision3` is available from macOS 12.0. — [Apple docs](https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequestrevision3)
  - `VNFaceObservation.yaw` is in radians about the y-axis and is `nil` if the request does not compute it. — [Apple docs: yaw](https://developer.apple.com/documentation/vision/vnfaceobservation/yaw)
- **Named error sources:**
  - Changing illumination, variable appearance, partial occlusion of facial landmarks, and misalignment between bounding box and face. — [Drouard et al., arXiv 1603.09732](https://arxiv.org/pdf/1603.09732) **[snippet]**
  - Glasses can permanently obscure eye corners for landmark-based methods. — [Murphy-Chutorian & Trivedi, head pose survey](https://people.ict.usc.edu/~gratch/CSCI534/Old-Readings/Head%20Pose%20estimation.pdf) **[snippet]**
  - Landmark-based estimates "drop quickly" at extreme head poses: suitable for near-frontal faces, unreliable at steep angles. — **[snippet; source attribution unclear among the search results, treat as general consensus]**

### Inferences
- **(inference) Axis reliability for this app.** Roll (in-plane head tilt) is the most robust axis, yaw is intermediate, and pitch is the weakest. Pitch also carries a camera-elevation offset that depends on distance (Q7).
- **(inference) Pin the revision.** The app should explicitly request face-detector revision 3. If it ever ran an older revision, roll and yaw would come back in discrete bins, and baseline comparisons of small changes would be meaningless. I did not verify which revision macOS 14 uses by default.
- **(inference) Measure the noise floor empirically.** Apple publishes no error figures, so the app should record a few minutes of the user sitting still, compute the per-axis standard deviation at 1 fps, and set change thresholds as a multiple of that rather than borrowing benchmark MAEs.
- **(inference) Benchmarks don't match this geometry.** AFLW2000 and BIWI faces are mostly seen at about camera height, while a webcam above the display views the face from above, adding a constant pitch bias.

### Gaps
- No public accuracy data for Apple's roll/yaw/pitch.
- No quantitative study found that isolates the effect of eyeglasses or low light on head-pose MAE.
- Cross-dataset BIWI results (train on 300W-LP, test on BIWI) were not retrieved for the README models.

---

## Q5. How accurate is viewing-distance estimation from iris diameter (~11.7 mm, e.g., MediaPipe Iris) or interpupillary distance (~63 mm)? How does it depend on camera intrinsics/FOV, and how can it be calibrated simply?

### Takeaway
Distance is the most metrically tractable frontal quantity.
- Iris-based estimation reports about 4.3% ± 2.4% mean relative error (stated as < 10%).
- A population IPD prior adds about ±6% per-person bias at 1 SD and about ±20% at population extremes.
- Native macOS AVFoundation does **not** expose the camera's field of view, so absolute distance needs an assumed FOV.
- A one-time calibration at a known distance removes both the unknown focal length and the user's own IPD.

### Cited Findings
- **MediaPipe Iris:**
  - "The horizontal iris diameter of the human eye remains roughly constant at 11.7±0.5 mm across a wide population."
  - Metric distance is estimated with "less than 10%" relative error and no depth sensor. — [MediaPipe Iris docs (GitHub)](https://github.com/google/mediapipe/blob/master/docs/solutions/iris.md)
  - Mean relative error 4.3% (SD 2.4%), compared with an iPhone 11 depth sensor whose error is < 2% up to 2 m. — [Google Research blog: MediaPipe Iris](https://research.google/blog/mediapipe-iris-real-time-iris-tracking-depth-estimation/) **[snippet]**
  - The GitHub doc does not state the number of participants, the distance range, or whether camera intrinsics are needed. — [MediaPipe Iris docs](https://github.com/google/mediapipe/blob/master/docs/solutions/iris.md)
- **Interpupillary distance (IPD) in the population** (Dodgson 2004, ANSUR and other data; 3,976 subjects aged 17–51):
  - Combined mean 63.36 mm, SD 3.83 mm, range 52–78 mm.
  - Men 64.7 ± 3.7 mm; women 62.3 ± 3.6 mm.
  - As quoted in [US Patent 10,429,648](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10429648) **[snippet]**. Original: Dodgson, "Variation and extrema of human interpupillary distance," *Stereoscopic Displays and Virtual Reality Systems XI*, SPIE 2004, pp. 36–46 (citation confirmed via [AVEH journal reference list](https://avehjournal.org/index.php/aveh/article/view/582) **[snippet]**).
- **Webcam distance from IPD (Applied Math 2025):**
  - Pupils from MediaPipe Face Mesh; a sixth-degree polynomial maps pixel IPD to distance over 20–80, 80–160 and 160–240 cm, calibrated on a uniaxial displacement rig.
  - Validated on 26 participants (15 M, 11 F) against a Bosch GLM120C laser meter.
  - Variation in IPD between people was a major error source. Women had higher relative errors, consistent with the larger female IPD SD the authors cite (F 61.53 ± 2.66 mm vs M 65.32 ± 1.50 mm).
  - Exact error values not retrieved. — [AppliedMath 5(3):118, doi:10.3390/appliedmath5030118](https://doi.org/10.3390/appliedmath5030118) **[snippet]**
- **Face2Cam (2026)** is a dataset for estimating user-to-webcam distance; models trained on it reached MAE of about 3.4–5.9 cm. It notes that feature-based methods rely on anthropometric priors such as IPD. — [Face2Cam, SciTePress 2026](https://www.scitepress.org/Papers/2026/146325/146325.pdf) **[snippet]**
- **Conflicting prior:** another real-time paper uses an average IPD of 60–62 mm (intercanthal distance about 30–31 mm), lower than Dodgson's 63.4 mm. — [ResearchGate: Face distance estimation using intercanthal distance](https://www.researchgate.net/publication/389193647_A_Real-time_Human_Face_Distance_Estimation_Using_Intercanthal_Distance) **[snippet]**
- **macOS FOV access:** `AVCaptureDevice.Format.videoFieldOfView` gives "the format's horizontal field of view in degrees" and "Returns zero if the format's field of view is unknown". It is listed for iOS 7+, iPadOS, Mac Catalyst 14+ and tvOS 17+, but **not native macOS**. — [Apple docs: videoFieldOfView](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/videofieldofview)

### Inferences
Error budget, using the pinhole model *d = f·S / s_px* (all **inference**):
- **IPD prior:** ±6.0% per 1 SD (about ±3.6 cm at 60 cm). A user at the 52 mm extreme is over-estimated by about +21%; one at 78 mm is under-estimated by about −19%.
- **Iris prior:** ±4.3% per 1 SD (0.5/11.7). The reported 4.3% mean error is consistent with anatomical variation dominating, but that is speculative.
- **FOV assumption:** assuming 60° when the true horizontal FOV is 65° gives +10.3% error; 58° or 62° gives ∓4%; 70° gives +21%.
- **Head yaw** shrinks the projected IPD by cos(yaw), over-estimating distance by +1.5% at 10°, +6.4% at 20° and +15.5% at 30°. Gate on |yaw| < about 15° or correct for it.

Calibration and design (**inference**):
- **Simplest robust calibration:** ask the user once to sit at a tape-measured distance d₀ and record IPD_px₀. Then K = d₀·IPD_px₀ and d = K / IPD_px. This cancels both the unknown focal length and the user's own IPD. Remaining error comes from landmark jitter, yaw, and lens distortion toward the frame edges.
- **The current face-box width ratio is already a relative distance estimate.** Since d/d₀ = w₀/w, it does not depend on FOV or IPD. But a face box is a detector output, not an anatomical landmark, so its jitter and its sensitivity to yaw or expression are unknown. Pupil-based IPD from the 76-point revision-3 landmarks is likely more stable; this is untested.
- **Limit of the signal:** distance change is the most trustworthy frontal signal for "leaning toward the screen", but it cannot tell whole-body lean from head protraction.

### Gaps
- Google's Iris evaluation protocol (n, distance range, eyeglass wearers) was not retrieved. No data found on how eyeglass lenses or frames bias iris-size or pupil-based distance.
- The error values from Applied Math 2025 were not retrieved.
- Apple does not document the field of view of the Intel iMac's FaceTime HD camera in any source found.

---

## Q6. What do webcam-based sitting-posture classification systems achieve (accuracy, participants, generic vs personalized models, ground-truth definition, real-world false positives)?

### Takeaway
Reported accuracies range from about 78% to 98%. Almost all are lab studies of **instructed or staged postures** with small or unreported samples. Labels come from instruction or RULA-style expert scoring, not clinical measurement, and few use subject-independent validation. The one forward-head-specific classifier reached about 78%. **No real-world false-positive rates were found.** The strongest evidence that feedback helps comes from a randomised study in which feedback compared each worker with **their own** earlier reference photo.

### Cited Findings
- **Real-time webcam upper-body method** (single images from a webcam in front of the desk; no skeleton extraction):
  - Classifies into predefined upper-body configurations, each mapped to a RULA-based risk score.
  - 88.2% average accuracy across 19 risk-level classes.
  - The dataset covers desk-sitting scenarios plus extreme cases such as turning away from the desk.
  - n not retrieved. — [ResearchGate 345432894](https://www.researchgate.net/publication/345432894_A_real-time_webcam-based_method_for_assessing_upper-body_postures) **[snippet]**
- **"Sitting Posture Recognition Based on the Computer's Camera" (ACM, 2024):**
  - MLP classifier with Leave-P-Groups-Out cross-validation.
  - 95.8% overall; 97.3% with the same table and chair; 94.1% with different table/chair sets.
  - n not retrieved. — [ACM DL 10.1145/3663976.3664014](https://dl.acm.org/doi/10.1145/3663976.3664014) **[snippet]**
- **Telework CNN system:** mean accuracy 0.924 (neck 0.938, shoulders 0.979). — [Sensors 2021, 21(15):5236](https://doi.org/10.3390/s21155236) **[snippet]**
- **Hierarchical image composition + deep learning:** 91.47% at 10 fps. Sensor type and n not verified. — [PeerJ Computer Science cs-442 (2021)](https://peerj.com/articles/cs-442/) **[snippet]**
- **"Harnessing CV and DL for optimal sitting posture detection" (2024):** overall accuracy 81.739%; precision 92.5% for "straight" sitting. — [ResearchGate 384045068](https://www.researchgate.net/publication/384045068_Harnessing_Computer_Vision_and_Deep_Learning_Model_for_Optimal_Sitting_Posture_Detection) **[snippet]**
- **Forward head posture from 3D pose (GCN):** 78.27% accuracy; macro F1 77.54%. — [JMIR Formative 2024](https://formative.jmir.org/2024/1/e55476) **[snippet]**
- **"Adaptive" system:** infrared wide-angle cameras, a YOLOv11 classifier and a "position calibration function" for different office chairs and body types; classifies 18 sitting-posture combinations. Accuracy not retrieved. — [PubMed 41337339](https://pubmed.ncbi.nlm.nih.gov/41337339/) **[snippet]**
- **Taieb-Maimon et al., *Applied Ergonomics* 2012; 43(2):376–385** (randomised; 60 office workers):
  - Arms: (1) control; (2) office ergonomic training plus workstation adjustment; (3) "photo-training" — the same training plus automatic, frequent on-screen feedback showing the worker's **current webcam photo next to their own correct-posture photo** taken during training.
  - Outcome: RULA before, during and after a 6-week intervention.
  - Both trainings improved posture in the short term; **only photo-training sustained the improvement**.
  - Effects were larger in older workers and those with more pain; photo-training helped women more than men. — [IUCC CRIS record](https://cris.iucc.ac.il/en/publications/the-effectiveness-of-a-training-method-using-self-modeling-webcam/); [ScienceDaily 2011](https://sciencedaily.com/releases/2011/08/110802180831.htm) **[snippet]**
- **Hobby and open-source monitors** use startup self-calibration (for example, learning "good posture" over a 5-second window) and combine spine-angle and face-to-screen-distance checks. None report validation. — [GitHub: Real-Time-Posture-Monitoring-DL](https://github.com/Pranava-Pai-N/Real-Time-Posture-Monitoring-DL) **[snippet]**; [GitHub: posture-alert](https://github.com/byronxlg/posture-alert)

### Inferences
- **(inference) High accuracy here means separating exaggerated poses.** Most of these accuracies measure discrimination between instructed, exaggerated postures, often with random (not subject-independent) splits. That is a much easier task than catching subtle habitual drift in one person over hours. Daily-life false-alarm rates are unknown.
- **(inference) Posture libraries encode a norm.** A library of "correct" postures (option B) usually encodes a symmetric, upright norm. For a user with possible structural asymmetry, that norm could permanently label their natural posture as "bad", which conflicts with the no-prescription requirement.
- **(inference) Personal reference without population thresholds can work.** Taieb-Maimon supports comparing the user with their own reference image rather than with population thresholds, the idea behind options C and D. Note that their reference posture was set in an ergonomist-led session, not by an algorithm.

### Gaps
- No real-world false-positive or false-alarm rates for any webcam posture coach were found.
- No webcam-specific comparison of generic vs personalised models was found. Search results on personalisation came from other sensing domains and were not used.
- Participant counts and ground-truth definitions for most cited classifiers were not retrieved.

---

## Q7. How do camera tilt and placement (above the monitor, looking down) bias absolute angles such as shoulder tilt, head pitch and slouch ratios?

### Takeaway
Single-camera 2D angles depend on perspective. A validation of OpenPose found joint-angle deviations of 15–36° from marker-based measurement across camera views, attributed to perspective rather than to keypoint error. Simple geometry shows that a camera above the display creates:
- a distance-dependent **head-pitch offset** of about 8–11° for a camera 10 cm above eye level at 50–70 cm;
- **apparent shoulder tilt** of about 3–4° from a 10° trunk rotation;
- compressed vertical distances.

Absolute population thresholds are therefore biased. Relative-to-baseline comparisons with an unchanged camera geometry are much more defensible.

### Cited Findings
- **OpenPose viewing-angle study:**
  - Average deviation between OpenPose and marker-based joint angles was 15.2°–36.48° across joint angles and camera views.
  - "Deeper investigation reveals no estimation errors but rather the issue of perspective when calculating 2D joint angles."
  - The highest mean deviation was 23.8° for a front-left view, versus 14.1–14.9° for the other cameras (likely the same study). — [Sensors 2025, 25(3):799](https://doi.org/10.3390/s25030799) **[snippet]**
- **2D vs 3D camera measurement:** RMS angle error was 12–16° with multi-camera triangulation but about 30° with a "naive depth" single-view technique. — [Sensors 2022, 22(5):1729](https://www.mdpi.com/1424-8220/22/5/1729) **[snippet]**
- **BlazePose framing tolerance:** the model tolerates only about 8° roll and 10% shift or scale of its expected crop, and is "sensitive to face position, scale and orientation". — [model card](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20BlazePose%20GHUM%203D.pdf)
- **Apple Vision:** body-pose results "may get worse if the subject is close to the edges of the screen". — [WWDC20](https://developer.apple.com/videos/play/wwdc2020/10653/)

### Inferences
All items in this subsection are my own geometric calculations (pinhole camera), not published results.
- **Head-pitch offset.** If the camera sits h cm above eye level, the face is viewed from above by atan(h/d).
  - h = 10 cm: 11.3° at 50 cm, 9.5° at 60 cm, 8.1° at 70 cm.
  - h = 5 cm: 5.7°, 4.8°, 4.1° at the same distances.
  - Moving 20 cm closer therefore changes measured pitch by about 3° with no neck flexion, and a "0° = neutral" population threshold is biased by camera height.
- **Rotation shows up as shoulder tilt.** Assume shoulders 20–30 cm below the camera, 18 cm half-width, 70 cm away. The shoulder nearer the camera projects lower in the image, giving an apparent shoulder-line tilt of:
  - 1.4–2.2° for 5° trunk rotation;
  - 2.9–4.3° for 10°;
  - 4.4–6.6° for 15°.

  This is the same size as a clinically interesting shoulder-height asymmetry, so **trunk rotation and shoulder-height asymmetry are confounded** in a frontal view from above. This matters directly for a user with suspected left–right trunk asymmetry.
- **The same keystone effect applies to the face.** Head yaw combined with camera elevation tilts the projected eye line, so roll estimates built from landmarks can pick up yaw. A model-based 3D head pose should be less affected; untested.
- **Camera roll and seating.** Any camera roll relative to gravity adds 1:1 to measured head roll and shoulder tilt; I assume a level desk and an iMac stand that tilts but does not roll (unverified). If the user faces the screen squarely, a pure downward pitch of the camera keeps horizontal body lines horizontal in the image. Problems start when the torso or head is rotated, or the user sits near the frame edge where lens distortion grows.
- **Slouch ratios mix several effects.** In (ear–shoulder vertical distance) ÷ (shoulder width):
  - the numerator is foreshortened by the downward view and shrinks when the head moves toward the camera, because closer points below the camera project further down;
  - it also shrinks with trunk slump, shoulder elevation and head flexion;
  - the denominator changes with distance, trunk rotation and shoulder protraction.

  A population cut-off on this ratio therefore will not transfer across camera heights, seating distances or bodies.

### Gaps
- No empirical study was found that quantifies how a webcam above the monitor biases head pitch, shoulder tilt or ear–shoulder ratios at desk distances. The figures above are geometric estimates.
- Lens distortion of the FaceTime HD camera is undocumented in the sources found.

---

## Q8 (objective synthesis). Which measurements are technically trustworthy from a frontal webcam, and what does that imply for options A–D?

### Takeaway
| Measurement | Trustworthiness from a frontal webcam |
|---|---|
| Viewing distance | Best supported: about ±5–10% after a one-time calibration |
| Lateral head tilt (roll) | Good for **relative** change (benchmark roll MAE about 2.4–3.4°; frontal head-tilt detection near expert level), but the absolute zero is biased |
| Gross head displacement in the frame; stillness / time without movement | Good for relative change |
| Head pitch (absolute) | Weak: worst benchmark axis, plus camera-elevation bias |
| Shoulder-height asymmetry | Weak: weakest frontal sign, confounded by rotation and clothing |
| Lateral trunk lean | Weak: needs the hips, which the desk hides |
| Trunk rotation | Weak: foreshortening is ambiguous with distance |
| Slouch ratios | Weak: confounded (Q7) |
| CVA / forward head posture | Not measurable: no C7, sagittal-plane quantity |
| Thoracic flexion | Not measurable: sagittal-plane quantity |
| Monocular 3D forward head | Not measurable: error exceeds the signal |

**Implications:** option D (non-judgmental, relative signals) is best supported. Option C is acceptable only if the baseline is personal and not filtered through symmetric population thresholds. Options A and B are not supported for asymmetry, forward head posture or slouch.

### Cited Findings
- **Head tilt and trunk lean** are detected at near-expert agreement from frontal monocular RGB (F1 0.94 / 0.92); shoulder elevation is weakest. 18 healthy adults, simulated compensations. — [Sensors 2026](https://doi.org/10.3390/s26165054) **[snippet]**
- **Smartphone photogrammetry apps** show "moderate evidence of excellent inter-rater and test-retest reliability" for head-tilt measurement. These use clinician- or marker-placed landmarks, not automatic keypoints. — [Scientific Reports 2025 meta-analysis](https://www.nature.com/articles/s41598-025-32708-1) **[snippet]**
- **2D frontal-plane analysis** with MediaPipe is "excellent"; 3D uplifting "introduced severe distortions and asymmetries". — [IEEE 11297977](https://ieeexplore.ieee.org/document/11297977/) **[snippet]**
- **Head-pose benchmark errors** (6DRepNet): roll 3.37° (AFLW2000) / 2.36° (BIWI); pitch 4.91° / 2.92°. Older models reach about 6.6° pitch on AFLW2000. — [6DRepNet GitHub](https://github.com/thohemp/6DRepNet)
- **Apple face pose** is continuous only from revision 3 (macOS 12+); earlier roll and yaw were binned. — [WWDC21](https://developer.apple.com/videos/play/wwdc2021/10040/)
- **Distance:** iris-based 4.3% ± 2.4% mean relative error; IPD SD 3.83 mm (about 6%); FOV not exposed to native macOS apps. — [Google Research blog](https://research.google/blog/mediapipe-iris-real-time-iris-tracking-depth-estimation/) **[snippet]**; [US Patent 10,429,648 quoting Dodgson](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10429648) **[snippet]**; [Apple docs](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/videofieldofview)
- **CVA** requires a lateral view and markers; the best frontal proxy found is only "moderately" correlated. — [AutoMCA](https://doi.org/10.3390/automation6040088) **[snippet]**; [Molaeifar 2021](https://journals.sagepub.com/doi/abs/10.3233/WOR-213451) **[snippet]**
- **Personal-reference photo feedback** sustained RULA improvement over 6 weeks (n = 60, randomised). — [Taieb-Maimon 2012](https://cris.iucc.ac.il/en/publications/the-effectiveness-of-a-training-method-using-self-modeling-webcam/) **[snippet]**

### Inferences
**Option A — skeleton with population or absolute thresholds** (inference)
- *Head tilt and shoulder tilt against fixed thresholds.* Measurable in principle, but:
  - the absolute zero is biased by camera roll and keystone effects (Q7);
  - shoulder keypoints at desk range are low-confidence and affected by clothing (Q1);
  - trunk rotation creates about 3–4° of apparent shoulder tilt per 10°.
- *A fixed threshold also implies a symmetric norm*, which the app must not impose before diagnosis.
- *Ear–shoulder ÷ shoulder width for slouch:* unvalidated and confounded (Q2, Q7).
- *IPD + FOV distance:* workable, but the FOV must be assumed on native macOS. A one-time known-distance calibration is better than a 63 mm + FOV prior: about ±6% (1 SD) to ±20% IPD error, plus about ±4–10% for a few degrees of FOV error.
- *3D pose for forward head:* not supported, because error exceeds the signal and uplifting creates asymmetry artefacts (Q3).

**Option B — classify against a posture library** (inference)
- Published classifiers (78–98%) are trained and tested on instructed, exaggerated postures, with no reported real-world false-positive rates.
- Library labels encode normative, often symmetric postures, so they are unsuitable for an undiagnosed asymmetric user.
- Low accuracy is expected for subtle, individual drift.

**Option C — auto-build a personal baseline from samples that pass population thresholds** (inference)
- Filtering baseline samples through population thresholds would carry option A's biases into the baseline. For an asymmetric user it would systematically reject their natural, possibly structural, posture, which is a hidden form of enforcing symmetry.
- A personal baseline is sound if samples are chosen by **user confirmation, stability or time criteria** (for example, the median of the first N minutes of each session, or the user pressing "this is comfortable"), with no symmetry criterion.
- Store the baseline per camera geometry and re-baseline when distance or framing changes.

**Option D — non-judgmental signals** (inference)
These rely only on the quantities that are measurable, relative and not directional:
- prolonged stillness (frame-to-frame keypoint or face-box motion below the noise floor for N minutes);
- progressive drift versus the session baseline, such as head moving lower or closer, distance shrinking, or pitch drifting, reported as "you've drifted from your usual position for X min" rather than "straighten your left shoulder";
- distance to the screen.

This option fits both the measurement limits and the no-prescription constraint.

**Implementation hygiene for any option** (inference)
- Pin `VNDetectFaceRectanglesRequestRevision3`.
- Discard frames with low per-point confidence or with keypoints near the frame edge.
- Gate on |yaw| < about 15° for distance and roll measures.
- Use rolling medians at 1 fps.
- Derive change thresholds from the user's own measured noise floor, not from benchmark MAEs.
- Never output a left/right correction direction.

### Gaps
- No study found that validated any frontal-webcam metric against a clinical reference (radiograph, motion capture, or lateral CVA photogrammetry) for **seated users at desk distance with the desk occluding the lower body**. All trust judgements above for that setting are extrapolated from standing or full-body studies plus geometry.
- No data found on false-alarm rates or user burden for webcam posture coaches in daily use.
- No data found on how reliable frontal shoulder-height or trunk-asymmetry measurement is in people **with** structural asymmetry such as scoliosis, as opposed to healthy volunteers simulating it.
