# ML learning approaches for frontal-webcam seated posture analysis (training, validation, personalization, label-free)

> Scope: what each family of ML methods has actually achieved for one desk worker with a built-in frontal camera. The focus is on how models were trained and validated. Searched October 2026.
> **Source-access caveat:** WebFetch failed with DNS errors (ENOTFOUND) for arxiv.org, mdpi.com, ncbi/pmc, biomedcentral and alphaxiv during this session. Only developer.apple.com could be fetched. Items marked **[snippet]** come from search-engine abstracts or snippets, not the full text, so their n, splits and tables are unverified. Items marked **[fetched]** were read directly.
> Already established in earlier notes and **not repeated** here: 78–98% accuracy on instructed postures, few subject-independent tests, no real-world false-positive rates; the GCN forward-head result (78.27%); seat-pressure personal models beating generic ones; Scheurer et al. 2020 on person-specific vs person-independent models; the 2025 on-device few-shot framework. See `../자세 감지 방향성 리서치/personalization_calibration.md` and `webcam_cv_accuracy.md`.

---

## 1. Personalized vs generic models for camera-based sitting posture (few-shot, fine-tuning, on-device updatable models)

### Takeaway
I found **no published webcam or frontal-camera sitting-posture study that directly compares leave-one-subject-out (generic) with within-subject or calibrated (personalized) performance**. The camera evidence is limited to (a) authors arguing for a per-user calibration stage (PosturePal) and (b) high accuracies from random or 90/10 splits that are not subject-independent. The direct quantitative case for personalization still comes from other sensors (pressure, IMU, EMG, acoustic gesture). There, a pooled cross-user model plus a small calibration set usually beats either extreme. Apple's stack supports exactly that pattern on device: a frozen feature extractor plus an updatable k-NN or neural-network head through `MLUpdateTask`.

### Cited Findings
**Camera-specific (weak evidence)**
- PosturePal (laptop webcam; course or tech-report quality, n not confirmed): the authors argue that rather than training on a multi-person dataset, it "might be best to only have a calibration stage for the user of interest," because people sit at different distances and angles from the laptop. Gradient-boosted trees scored highest at **0.91** when angle features were included. I found no cross-user vs calibrated split in the excerpt. — [PosturePal, Weber & Nadeem (PDF)](https://ethanweber.me/documents/posturepal.pdf) **[snippet]**
- A webcam sitting-posture SVM reported **100%** accuracy on data from **25 participants** with a **90/10 train–test split**, and **99%** mean cross-validation accuracy. The excerpt does not say that the test users were unseen, so these are **not** subject-independent numbers. — [Sitting Posture Recognition Based on the Computer's Camera (ResearchGate listing)](https://www.researchgate.net/publication/381783860_Sitting_Posture_Recognition_Based_on_the_Computer's_Camera) **[snippet]**
- The ACM 2024 paper of the same title: ordinary computer camera, **8 posture classes**, **95.8%** average accuracy, supervised. Its validation scheme was not visible. — [ACM DOI 10.1145/3663976.3664014](https://doi.org/10.1145/3663976.3664014) **[snippet]**
- Older IMU forward-head work: "due to the small number of subjects, individualized models were more effective than training one universal model" (body sensor network, **94.5%** FHP detection; flagged as **old**). — [Detecting and Preventing FHP with Wireless Inertial BSNs](https://www.researchgate.net/publication/224247904_Detecting_and_Preventing_Forward_Head_Posture_with_Wireless_Inertial_Body_Sensor_Networks) **[snippet]**

**Cross-sensor evidence on the "pooled + calibration" strategy (new since the earlier notes)**
- AirWare (in-air gesture recognition from audio and IR; not posture): **fully personalized models did not beat leave-one-subject-out models**. The authors attributed this to too little per-user training data. A strategy that **pooled other users' data and added a per-user calibration step improved results for every user**. — [AirWare, arXiv 2101.10245](https://arxiv.org/pdf/2101.10245) **[snippet]**
- Surface EMG (2026 preprint): a cross-user encoder personalized with **3 calibration repetitions** reached **macro-F1 0.827**, vs **0.593** for a per-user LDA trained from scratch. — [Personalising a Cross-User sEMG Encoder Under a Small Calibration Budget, arXiv 2609.20296](https://arxiv.org/pdf/2609.20296) **[snippet]**
- Pressure smart-skin sitting study (2026): validated **leave-one-session-out** rather than only random splits. A TCN with attention scored **85.23%** cross-session vs CNN-LSTM **82.67%**, which is far below the 95–99% typical of random splits. — [Multimodal Smart-Skin for Real-Time Sitting Posture Recognition with Cross-Session Validation, MTI 10(4):39](https://www.mdpi.com/2414-4088/10/4/39) **[snippet]**
- Electro-textile chair cover (2026), **subject-independent and cross-chair** validation, **36 subjects**, but each recording lasted only 10 s. In-lab 1D-CNN **99.8%** vs LSTM **99.7%**. — [Complex & Intelligent Systems 2026](https://link.springer.com/article/10.1007/s40747-026-02460-8) **[snippet]** (subject count from earlier notes)

**Apple on-device personalization (platform facts)**
- Core ML "Model Personalization": "With the Core ML framework, you can adapt to incoming data with an updatable model at runtime on the user's device." `MLUpdateTask` is "a task that updates a model with additional training data". — [Apple, Model Personalization](https://developer.apple.com/tutorials/data/documentation/coreml/model-personalization.md) **[fetched]**
- Core ML 3 (model spec v4) made **neural networks and k-nearest-neighbor classifiers updatable**. Apple's WWDC demo trained a small on-device k-NN from **a few example sketches**. One practitioner recommends k-NN on top of a neural feature extractor for "many, if not most" on-device personalization tasks. — [Fritz.ai, What's new in Core ML 3](https://fritz.ai/whats-new-in-core-ml-3/) **[snippet]**; [iOSDevie, on-device training](https://iosdevie.substack.com/p/coreml3-on-device-training) **[snippet]**
- `VNGenerateImageFeaturePrintRequest` returns `VNFeaturePrintObservation` image embeddings and is available on **macOS 10.15+**. It has a crop/scale option and a Revision1 constant. — [Apple Vision docs](https://developer.apple.com/tutorials/data/documentation/vision/vngenerateimagefeatureprintrequest.md) **[fetched]**

### Inferences
- For one user, the relevant generalization gap is **cross-session and cross-setup** (lighting, chair height, clothing, camera angle after a macOS update), not cross-person. The cross-session pressure result (about 85% vs about 98% on random splits) suggests session drift alone may cost on the order of 10 percentage points. This is a cross-modality analogy, not webcam evidence.
- The best-supported design for a single user is **generic feature extractor → small personal head**: Vision body-pose keypoints or feature prints → k-NN, prototype or logistic head updated with `MLUpdateTask` or plain Swift. This matches the AirWare and sEMG results, where a cross-user representation plus minutes of calibration beat both pure-generic and pure-personal models.
- **Principle conflict:** any personalized *classifier* still needs class labels. If the labels are "good" and "bad", the app implicitly prescribes a direction. A neutral alternative is labels the user defines as *states*, such as "my reference", "leaning on left elbow" or "reading close". Then the head only answers "which of my own named states is this, and how far from my reference", with no normative judgment.

### Gaps
- No webcam study with both LOSO and within-subject results for sitting posture was found. The size of the benefit from "a few minutes of own labeled data" for a webcam therefore remains unquantified.
- I found no published evaluation of `MLUpdateTask`, Create ML, or feature-print-based k-NN for posture specifically.
- The following come from background knowledge and were **not verified this session**: whether `VNFeaturePrintObservation.computeDistance` exists and what distance it uses, the embedding dimensionality, and whether the Create ML `MLActionClassifier` (body-pose sequences) can be trained at runtime on macOS 14 Intel.

---

## 2. Regression from frontal images to sagittal clinical quantities (CVA, neck/trunk flexion, head protraction)

### Takeaway
**I found no study that trains a model on frontal webcam images with side-view, marker, IMU or mocap ground truth to predict CVA, neck flexion, trunk flexion or head protraction.** Every FHP or CVA image model found uses **lateral (side-view)** photos, with photogrammetric CVA as the label, or reports classification rather than angle error. The only angle-regression results with a single webcam concern range-of-motion tasks, not seated sagittal posture.

### Cited Findings
- Yang et al. 2023 (BMC Med Inform Decis Mak): non-contact FHP detection in Chinese adolescents. OpenPose landmarks plus genetic-algorithm feature selection; Extra Trees was best, with **accuracy 82.4%, specificity 85.5%, PPV 90.2%**. The reference standard was **photogrammetry** with an "ex-body posture apparatus". CVA-like angles were extracted **from side-view** images, using the shoulder as the vertex. The paper reports validation on an independent adolescent sample. n and the split were not verified. — [PMC10496156](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10496156/) / [BMC](https://bmcmedinformdecismak.biomedcentral.com/articles/10.1186/s12911-023-02285-2) **[snippet]**
- Lee, Choi, Yum & Kim 2023 (Applied Sciences 13(19):10935): classified "text neck" and "L-posture" in computer work from **lateral** images, using skeleton-derived angles. **Accuracy 97.06%, F1 95.23%** (L-posture 100%). Participant count and validation scheme were not verified. — [MDPI](https://www.mdpi.com/2076-3417/13/19/10935) **[snippet]**
- Single-webcam 3D range-of-motion study: BlazePose 3D joints vs motion capture. A linear-regression correction gave **r = 0.971, MAE 5.778** (units presumably degrees). The task was shoulder and other joint ROM, not seated sagittal posture. — [arXiv 2310.07322](https://arxiv.org/pdf/2310.07322); [SportRxiv preprint](https://sportrxiv.org/index.php/server/preprint/download/219/version/275/422/368) **[snippet]**
- CVA ground-truth tooling: a mobile CVA app (sagittal photo with tragus and C7 markers) showed intra-rater **ICC 0.88** and inter-rater **ICC 0.83–0.89**. Sagittal photogrammetry is described as the "gold standard" for head position. — [PMC7559098](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7559098/) **[snippet]**
- Ground-truth candidates for computer work: two IMU systems were validated against 3D mocap for upper-body posture across 3 computer setups (correct monitor, raised monitor, laptop), using R² and RMSE. — [PMC10422555](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10422555/) **[snippet]**. A single-IMU spine tracker agreed with X-ray C0/C7 angles (ICC, p<0.001) in office workers but could not separate upper from lower cervical angles. — [Electronics 13(7):1363](https://www.mdpi.com/2079-9292/13/7/1363) **[snippet]**
- The head-pose literature trains deep regressors from monocular appearance to 3D head orientation (yaw, pitch, roll). These estimate head *rotation*, not translation or protraction. — [Real-Time Head Orientation from a Monocular Camera Using DNN](https://www.researchgate.net/publication/312830559_Real-Time_Head_Orientation_from_a_Monocular_Camera_Using_Deep_Neural_Network) **[snippet]**; [Deep learning for head pose estimation: survey](https://link.springer.com/article/10.1007/s42979-023-01796-z) **[snippet]**

### Inferences
- Training a frontal→CVA regressor *for this one user* is technically possible. It would need a paired calibration session: frontal webcam features synchronized with a side photo or side phone video carrying tragus and C7 stickers. But no published error bound exists, and frontal cues for protraction (face scale, chin–shoulder vertical distance, head pitch) are confounded by distance to the screen and by head rotation. Any such regressor should be reported as an **unvalidated personal estimate** with its own measured error from held-out calibration sessions.
- Under the no-diagnosis principle, a regression to CVA invites comparison with clinical FHP cut-offs (which range from 44° to 54° in the literature, per earlier notes). Showing "frontal proxy changed by X relative to your reference" is safer than showing an estimated CVA.

### Gaps
- No frontal-to-sagittal regression study, dataset, or MAE was found for CVA, neck flexion, trunk flexion or head protraction.
- The n and splits for Yang 2023 and Lee 2023 could not be verified, because full text was inaccessible this session.

---

## 3. Unsupervised and label-free approaches (clustering own states, embeddings, change-point and anomaly detection, posture variability)

### Takeaway
Label-free sitting-posture work exists almost entirely for **pressure mats**: K-means, self-organizing maps, and 2025 domain-adaptive clustering. I found **no validated example of clustering a person's own posture states from webcam keypoints or image embeddings (feature print, CLIP, DINOv2), and none of webcam change-point or anomaly detection against a personal baseline, in ergonomics or HCI.** The review literature names the core weakness: clusters are found, but "it is unknown to which postural state these clusters correspond". For this app's principle, that weakness is a feature: clusters can be described as "state A / state B, how long, when it changed" without a normative label.

### Cited Findings
- 2024 review (J NeuroEng Rehabil), "Intelligent systems for sitting posture monitoring and anomaly detection": **K-means** is the most widely used unsupervised technique, but "it is unknown to which postural state these clusters correspond". Autoencoders and GANs are described for anomaly detection: they reconstruct normal data and fail to reconstruct anomalies. — [JNER 2024, 10.1186/s12984-024-01322-z](https://jneuroengrehab.biomedcentral.com/articles/10.1186/s12984-024-01322-z); [ResearchGate PDF](https://www.researchgate.net/publication/378339236_Intelligent_systems_for_sitting_posture_monitoring_and_anomaly_detection_an_overview) **[snippet]**
- U-DaDiL (Hattay, Ayat & Ngole Mboula, CEA List / CentraleSupélec, arXiv June 2025): fully unsupervised clustering that aligns datasets through a Wasserstein-barycenter representation, to handle **domain shift across individuals** caused by morphological differences. It gave a **+24.63%** average accuracy improvement on the Office31 benchmark. On **pressure-map** posture data it beat a K-means baseline. Subject count was not visible. — [arXiv 2506.19410](https://arxiv.org/pdf/2506.19410) **[snippet]**
- Improved self-organizing map (Sensors 2021, **older**): unsupervised recognition of 6 sitting postures from a flexible pressure array. It outperformed decision tree, K-means, BP neural network and plain SOM baselines. — [PMC8473111 / Sensors 21(18):6246](https://doi.org/10.3390/s21186246) **[snippet]**
- Pose-driven anomaly detection (IET Image Processing 2023, CCTV-like setting): **RGB-based autoencoders are suboptimal for posture-level anomaly detection when training data are limited**. Pose (keypoint) features are proposed instead. — [Yang et al. 2023, IET](https://ietresearch.onlinelibrary.wiley.com/doi/full/10.1049/ipr2.12664) **[snippet]**
- Unsupervised anomaly detection for wheelchair users' sitting posture (2025) exists. Modality and numbers were not retrieved. — [ResearchGate 392465119](https://www.researchgate.net/publication/392465119_Intelligent_sitting_postural_anomaly_detection_system_for_wheelchair_users_with_unsupervised_techniques) **[snippet; title only]**
- Temporal Rate Reduction Clustering (TR²C, 2025): unsupervised segmentation of human motion video into states. Per-frame **zero-shot CLIP** labelling scored only **about 29–40%**; the authors attribute this to classifying frames without temporal context. — [arXiv 2506.21249](https://arxiv.org/pdf/2506.21249) **[snippet]**
- Posture variability as an outcome (pressure, not camera): JMPT 2023, **60 office workers**, 1-hour sitting. Postural shifts were detected from seat-pressure signals with a **±10% threshold**, and groups averaged about **13, 22 and 30 shifts per hour**. The study tested whether more frequent shifts lower discomfort. — [JMPT 2023](https://www.jmptonline.org/article/S0161-4754(23)00053-2/fulltext) **[snippet]**
- Applied Ergonomics 2022 (pressure mats): trunk movements decreased significantly over a prolonged sitting bout. The paper notes that earlier work measured variability with **video analysis (Womersley & May 2006)** and accelerometers. — [ScienceDirect S0003687022000461](https://www.sciencedirect.com/science/article/abs/pii/S0003687022000461) **[snippet]**
- 2D video image processing of keyboard operators (**old, about 2005**) reported postural angles to **1–2°** from frames sampled about every 30 s, under lab conditions. — [PubMed 15676792](https://pubmed.ncbi.nlm.nih.gov/15676792/) **[snippet]**
- Earlier notes (not repeated in detail) describe auto-calibration in which idle or sedentary data from the first days are stored and clustered to set thresholds. — see `../자세 감지 방향성 리서치/personalization_calibration.md`.

### Inferences
- A defensible label-free pipeline for this app could keep, per window, a low-dimensional keypoint feature vector (head–shoulder geometry, shoulder tilt, face scale) and perhaps a feature-print *distance* to a reference embedding. On top of that, it could run (a) online clustering into the user's own recurring states, (b) change-point detection (e.g., a CUSUM or Bayesian online change-point detector on the feature stream) and (c) "time since last state change" as a variability metric. This produces "what changed, when, for how long" outputs that make **no claim about correctness**. All three are standard techniques, but **none is validated for webcam sitting posture**. Validation would have to be done in-app, for example by letting the user confirm or deny detected changes.
- Image-level embeddings (feature print, CLIP, DINOv2) also encode lighting, clothing, background and camera exposure. Without keypoint-based features or masking, a "change" may be a lighting change. The IET finding (pose features beat RGB autoencoders with limited data) supports keypoints as the primary signal and embeddings as secondary.
- Pressure-based shift-frequency research (13–30 shifts per hour) gives a plausible order of magnitude for "posture changes per hour". However, a camera detects head and upper-body shifts, not pelvic shifts, so the numbers are not interchangeable.

### Gaps
- No webcam, keypoint or embedding clustering study for desk posture with validation (e.g., agreement with annotated state changes) was found.
- No study validated **video-based** postural-shift counts against a criterion measure, or reported their within-person reliability.
- No DINOv2- or CLIP-embedding study for sitting posture was found. Zero-shot CLIP accuracy for sitting vs slouching is unreported; the closest is a yoga-pose CLIP study at about 90% with **about 20 training images per pose** (few-shot, not zero-shot). — [Mathematics 12(1):76](https://doi.org/10.3390/math12010076) **[snippet]**

---

## 4. Temporal models (LSTM, TCN, transformers on keypoint sequences) vs per-frame models: do they reduce false alarms?

### Takeaway
**No study was found that compares a temporal model with a per-frame model for webcam sitting posture, or that reports false-alarm rates for either.** Where the two have been compared (on pressure data), they are within about 0–3 percentage points of each other. The one cross-session comparison favoured a TCN. Temporal models in the camera posture literature are mostly used for dynamic tasks (lifting, falls, exercise), not for sustained sitting.

### Cited Findings
- Pressure smart-skin (2026): under **leave-one-session-out**, a **TCN with attention scored 85.23% vs 82.67% for CNN-LSTM**, with lower latency (**14.2 ms vs 21.5 ms**). — [MTI 10(4):39](https://www.mdpi.com/2414-4088/10/4/39) **[snippet]**
- Electro-textile chair (2026, subject-independent and cross-chair): **1D-CNN 99.8% vs LSTM 99.7%**, essentially tied. — [Complex & Intelligent Systems 2026](https://link.springer.com/article/10.1007/s40747-026-02460-8) **[snippet]**
- LSP-YOLO (Nov 2025): a single-stage keypoint detector plus CNN classifier for sitting posture on embedded devices reached **96.9%** classification accuracy (keypoint mAP 68.1%). It is **per-frame**, with no LSTM variant compared, and validation details were not visible. — [arXiv 2511.14322](https://arxiv.org/pdf/2511.14322) **[snippet]**
- RGB-D posture recognition with a temporal hierarchical network on MobileNetV2: **91.47%** at 10 fps (**older, 2018**). — [arXiv 1810.00308](https://arxiv.org/pdf/1810.00308) **[snippet]**
- MediaPipe → stacked LSTM for **manual lifting** risk (2024): an architectural analogue, but for a dynamic task. — [arXiv 2408.12796](https://arxiv.org/html/2408.12796v1) **[snippet]**
- PSE-CNN-BiGRU (2025): MediaPipe skeleton keypoints, with a CNN for spatial features and a double-layer BiGRU for temporal features, used for general posture recognition. — [ScienceDirect S1526149224001309](https://www.sciencedirect.com/org/science/article/pii/S1526149224001309) **[snippet]**
- Raspberry Pi + MediaPipe sitting-posture app (2025): authors note that wrong analysis results "would result in false warnings". Accuracy was tested on 4 instructed postures; no temporal network, no false-alarm rate. — [arXiv 2508.11683](https://arxiv.org/pdf/2508.11683) **[snippet]**
- Supervised keypoint-based multi-class work (human-in-the-loop education study): LSTM and Transformer beat KNN, SVM and RF on complex postures. The study used **4,870 labeled images** and was not sitting-specific. — [PMC12292351](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12292351/) **[snippet]**

### Inferences
- Sitting posture is mostly *sustained*, so a sequence model mainly acts as a learned smoother. For false-alarm control, explicit temporal logic (minimum duration, hysteresis, a majority vote over N seconds) is transparent, needs no labels, and can be tuned by the user. A learned LSTM or TCN needs labeled *sequences*, which a single user will rarely produce.
- Temporal context matters more for **label-free segmentation** (TR²C vs per-frame CLIP, 29–40%; §3) than for supervised classification accuracy.

### Gaps
- No reported false-positive or false-alarm rates (per hour or per day) were found for any webcam sitting-posture system, temporal or per-frame, under free-living conditions. This confirms the earlier finding.
- No webcam keypoint LSTM, TCN or transformer vs per-frame comparison for sitting was found.

---

## 5. Vision-language models (GPT-4V/4o, Gemini, Claude, LLaVA, local VLMs) and image-based RULA/REBA estimation

### Takeaway
**I found no peer-reviewed or preprint study reporting agreement between a general-purpose VLM (GPT-4V/4o, Gemini, Claude, LLaVA) and expert RULA or REBA scores from images.** The closest items: a 2025 fine-tuned small VLM for REBA (Qwen2-VL-2B, construction, numbers not retrievable), a 2026 study where GPT-4o reached F1 0.756 on construction-worker *action* recognition (not posture scoring), and keypoint-instruction-tuned LLaVA-Pose. Purpose-built computer-vision RULA tools show good lab agreement but much lower field agreement. Human raters themselves disagree substantially on some tools. VLMs therefore have **no validated basis** for ergonomic scoring from a frontal desk camera, and cloud VLMs are excluded by the privacy constraint anyway.

### Cited Findings
**VLMs**
- REBA-VLM (2025): **Qwen2-VL-2B fine-tuned** with pose-guided visual instruction tuning. From a single image it outputs a **REBA score**, problem identification and suggestions in plain language (construction). It reports score agreement against baselines, but the figures were not retrievable. — [ResearchGate 408112498](https://www.researchgate.net/publication/408112498_REBA-VLM_Enhanced_risk_mitigation_in_construction_via_Pose_guided_visual_instruction_tuning) **[snippet; numbers missing]**
- Bui, Chodosh & Tavakoli (arXiv Jan 2026), "Can Vision-Language Models Understand Construction Workers?": **1,000 static images**, 10 action and 10 emotion classes, zero-shot without domain fine-tuning. **GPT-4o**: action **F1 0.756 / accuracy 0.799**, emotion F1 0.712 / accuracy 0.773. **Florence-2**: action F1 0.497. **LLaVA-1.5**: action F1 0.466. All models confused semantically close categories. The authors say domain adaptation, **temporal modeling** or multimodal sensing are needed for real-world reliability. — [arXiv 2601.10835](https://www.arxiv.org/pdf/2601.10835); [papers.cool](https://papers.cool/arxiv/2601.10835) **[snippet]**
- LLaVA-Pose (2025): LLaVA-1.5-7B instruction-tuned with **keypoint-integrated** data (**200,328** samples) for human pose and action understanding. No ergonomic scoring was evaluated. — [PMC12390531](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12390531/) **[snippet]**
- ChatGPT (text only) on **50 office-ergonomics and spine-health questions**, rated by **10 experts**: experts agreed with each other (**ICC 0.838**). The authors concluded the answers cannot replace clinical judgment, especially for individualized exercise prescription. — [PubMed 42144743](https://pubmed.ncbi.nlm.nih.gov/42144743/) **[snippet]**
- Multimodal LLMs in medical imaging illustrate "consistent but wrong" behaviour. Hand-fracture detection showed high run-to-run agreement but **38.5%** accuracy (systematic error). Thyroid ultrasound risk scoring reached at most **57.3%**. — [PMC12897326](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12897326/); [PMC12364431](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12364431/) **[snippet]**
- ERG-AI (2024) uses GPT-4 **text** prompts to generate recommendations from wearable-sensor posture predictions, with no vision input. — [Applied Intelligence 2024](https://link.springer.com/article/10.1007/s10489-024-05796-1) **[snippet]**

**Purpose-built CV RULA/REBA (non-VLM), with lab vs field agreement**
- Agostinelli, Generosi, Ceccacci & Mengoni 2024 (Sci Rep 14), real manufacturing lines: the correct **risk level** was estimated for **15/23 postures (65.22%)** on one line, and exact **score** accuracy was much lower (about **30%**). The authors conclude these systems are "not yet optimized for expert-level risk certification" but are useful for continuous monitoring. — [Nature Sci Rep, s41598-024-79373-4](https://www.nature.com/articles/s41598-024-79373-4); [open PDF](https://u-pad.unimc.it/bitstream/11393/345391/1/s41598-024-79373-4.pdf) **[snippet]**
- Other lab-vs-field contrasts surfaced in the same search: about **80%** for ERA score and risk level on static lab poses (tf-pose), but **45%** (ERA score) and **64%** (risk level) in a real setting. — via search summary of the [Sci Rep 2024 paper](https://www.nature.com/articles/s41598-024-79373-4) and related work **[snippet; attribution to specific primary papers unverified]**
- Real-time RULA/REBA/OWAS software (LACCEI): **75 measurements of 5 postures** vs one expert gave a **68–76%** match in risk level at 30 FPS. — [LACCEI proceedings](https://proceedings.laccei.org/index.php/laccei/article/view/7544) **[snippet]**
- Fully automated RULA from computer vision (IJIE 2021, **older**): **ICC > 0.75** vs two experts. — [ScienceDirect S0169814121001360](https://www.sciencedirect.com/science/article/abs/pii/S0169814121001360) **[snippet]**
- Simon et al. 2025 (Bioengineering 12(4):403): **MoveNet 2D pose vs IMU mocap**, **45** dental-assistant students. Overall RULA agreement was **moderate (κ = 0.461)**, but body-region agreement (upper arm, lower arm, wrist, neck, trunk) was not good: "methods align on overall score but not individual regions". 2D pose picked up more neck and trunk deviation. — [PMC12024670](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12024670/); [MDPI](https://www.mdpi.com/2306-5354/12/4/403) **[snippet]**
- Wheelchair users with vision-based 3D pose: **84%** risk-classification accuracy, **Cohen's κ 0.66**. — [PMC13165626](https://pmc.ncbi.nlm.nih.gov/articles/PMC13165626/) **[snippet]**

**Human-rater ceilings (for context)**
- Photo-based RULA vs Xsens IMU in **130** dentist/assistant teams: arm and wrist **κ 0.07–0.16**; neck, trunk and legs **κ 0.23–0.39**; final score **κ 0.21–0.28**. — [PMC10136304](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10136304/) **[snippet]**
- RULA in bank computer users: intra-rater **ICC 0.92**, inter-rater **ICC 0.91**. Children's computing posture showed more moderate reliability, and video ratings may be lower than live ratings. OCRA checklist inter-rater weighted **κ 0.43**. — [ResearchGate 333438280](https://www.researchgate.net/publication/333438280_Rapid_upper_limb_assessment_RULA_validity_and_reliability_evidences_in_identifying_workplace_ergonomics_among_bank_employee's_using_computers); [academia.edu](https://www.academia.edu/24482340/An_investigation_of_the_reliability_of_Rapid_Upper_Limb_Assessment_RULA_as_a_method_of_assessment_of_childrens_computing_posture) **[snippet]**

### Inferences
- RULA and REBA need sagittal joint angles (neck flexion, trunk flexion, upper-arm elevation) that a frontal camera sees poorly. CV tools already drop to roughly 30–65% field agreement with **side or oblique** views. A frontal desk camera would likely do worse, and a VLM adds no validated geometry.
- RULA and REBA output a **risk score with action levels**, which is normative and close to "prescribing a correction". That conflicts with the app's no-diagnosis principle regardless of accuracy.
- Local and offline VLM options (LLaVA-1.5-7B, Qwen2-VL-2B, Florence-2) exist and are the only privacy-compatible VLMs. But (a) their posture or action accuracy is well below GPT-4o's in the only comparison found (F1 about 0.47–0.50 vs 0.76), and (b) running a 2–7B VLM per frame on an Intel iMac CPU is impractical for continuous use. At most they could produce occasional *descriptions* ("head lowered, leaning left") from a just-captured frame that is then discarded. Even that is an unvalidated use.
- "Consistent but wrong" (high repeatability, low accuracy) is the documented MLLM failure mode in medical imaging. Repeatability tests alone would not validate a VLM posture description.

### Gaps
- No study of GPT-4o, Gemini, Claude or LLaVA vs expert RULA or REBA from images was found (searched four ways). REBA-VLM agreement numbers were not retrievable.
- No study evaluates VLMs on *seated office* posture or frontal desk views.
- No benchmark exists for local-VLM latency on Intel macOS for this task.

---

## 6. Label quality: what ground truth webcam posture ML studies use, and what is known about real-world performance and false positives

### Takeaway
The ground truth falls into four tiers, from most to least common: (1) **instructed or staged postures** (class = what the participant was told to do); (2) **expert RULA, REBA or visual scoring**; (3) **photogrammetric CVA** from side photos; (4) **IMU or optical mocap**, rare for webcam sitting studies. Newer 2024–2026 papers still mostly use (1) with random or unspecified splits. Field validations of CV ergonomics tools (risk level about 65%, exact score about 30%) show a large lab-to-field drop. **No real-world false-positive rate for a webcam sitting-posture system was found**, which confirms the earlier finding.

### Cited Findings
- SitPose (arXiv Dec 2024): Azure Kinect depth, **36 participants**, **33,409 samples**, 6 sitting postures plus standing (**instructed**). A soft-voting ensemble reached **F1 98.1%**. The validation protocol and whether test participants were held out were not visible. — [arXiv 2412.12216](https://arxiv.org/pdf/2412.12216); [HF papers](https://huggingface.co/papers/2412.12216) **[snippet]**
- Webcam SVM, **25 participants**, **90/10 split**: **100%** (CV 99%). Not shown to be subject-independent. — [ResearchGate 381783860](https://www.researchgate.net/publication/381783860_Sitting_Posture_Recognition_Based_on_the_Computer's_Camera) **[snippet]**
- LAViTSPose (2025): supervised detection, segmentation and classification for sitting posture, motivated by occlusion and keypoint misalignment in multi-person scenes. — [PMC12732004](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12732004/) **[snippet]**
- Photogrammetric labels: Yang 2023 FHP (photogrammetry reference, independent validation sample) — [PMC10496156](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10496156/) **[snippet]**
- IMU labels and their own weakness: photo-based RULA vs IMU agreement is poor by region (κ 0.07–0.39) — [PMC10136304](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10136304/). 2D pose vs IMU gives κ 0.461 overall — [PMC12024670](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12024670/) **[snippet]**
- Lab-to-field drop: manufacturing risk level **65.22%** (15/23), with exact score far lower — [Sci Rep 2024](https://www.nature.com/articles/s41598-024-79373-4). Assembly-line posture-class accuracy was **76.7%** with a dedicated classifier — [arXiv 2409.17356](https://arxiv.org/pdf/2409.17356) **[snippet]**
- "Posture Lab" pilot (Wearable Technologies, Cambridge, 2025): computer vision plus wearables quantified sitting posture on a **manikin** (video at 1 Hz), not live users. — [Cambridge Core](https://www.cambridge.org/core/journals/wearable-technologies/article/quantifying-sitting-posture-a-pilot-feasibility-study-of-computer-vision-and-wearable-sensors-posture-lab-using-a-manikin-model/3DE32CB7E61778CF5057BCD2CE611159) **[snippet]**
- Out-of-scope context (a wearable feedback study, not ML or webcam): Posture Clip (arXiv May 2026; journal version accepted April 2026). **165** laptop/PC workers (>6 h/day), 4 weeks **in their own offices**, a feedback arm and a no-feedback arm plus control. A collar sensor blanked the screen when the user was bent. The feedback group improved posture angle (p<0.001) and reduced bent-posture duration (p<0.01). The authors note that screen blackout can annoy users, e.g., during video calls. — [arXiv 2605.25664](https://arxiv.org/pdf/2605.25664); [chatpaper mirror](https://chatpaper.com/paper/285894) **[snippet; figures from mirrors]**

### Inferences
- **Instructed-posture labels measure separability of exaggerated poses**, not the detection of a user's natural, subtle drift. For a single user, a better ground truth is the user's own **reference session** plus event-level confirmations ("yes, I just changed position"). That validates "change detection" rather than "good/bad", which is consistent with the no-diagnosis principle.
- Supervised "good/bad" datasets embed a normative judgment from the dataset authors or the RULA thresholds. Reusing such a classifier, even with 95%+ reported accuracy, would import a correction direction the app must not prescribe. Label-free or user-defined-state approaches avoid this by construction.
- For a false-positive metric that a single user can measure, the app could log, without storing frames, how often a detected change or deviation was dismissed or marked "not a real change". That would supply the real-world false-alarm number the literature lacks.

### Gaps
- No free-living webcam false-positive rate (per hour or day) was found.
- No webcam sitting study using IMU or mocap ground truth for *frontal* views was found.
- No inter-annotator agreement was reported for any webcam sitting-posture label set.

---

## 7. Update to earlier conclusions (what is new from 2022–2026, and what it contradicts or confirms)

### Takeaway
New 2024–2026 evidence **confirms** the earlier picture and does not contradict it. Accuracy on instructed postures remains 95–100% (SitPose F1 98.1%, LSP-YOLO 96.9%, a 25-person SVM at 100%) with unclear or random splits. Cross-session and cross-setup testing has appeared in **pressure** sensing (85% cross-session), not in webcam work. VLM ergonomics remains unvalidated. Label-free methods remain pressure-only. The **cross-user encoder + small calibration** pattern (AirWare, sEMG 2026) refines the earlier "personal beats generic" conclusion: personal-only models can lose to pooled+calibrated ones when per-user data are scarce.

### Cited Findings
- Cross-session pressure posture: TCN-attention 85.23% (leave-one-session-out). — [MTI 10(4):39](https://www.mdpi.com/2414-4088/10/4/39) **[snippet]**
- Personal-only models did not beat LOSO; pooled+calibration improved every user (AirWare). — [arXiv 2101.10245](https://arxiv.org/pdf/2101.10245) **[snippet]**
- Cross-user encoder + 3 calibration repetitions: macro-F1 0.827 vs per-user LDA 0.593 (sEMG 2026). — [arXiv 2609.20296](https://arxiv.org/pdf/2609.20296) **[snippet]**
- GPT-4o is the best of three VLMs on construction-worker action recognition (F1 0.756), with no ergonomic scoring tested. — [arXiv 2601.10835](https://www.arxiv.org/pdf/2601.10835) **[snippet]**

### Inferences
- The earlier recommendation of "personal reference + feedback against own baseline" remains the best-supported direction. New evidence adds that a **generic pose model as the feature extractor + a small personal layer or distance-to-reference** is preferable to training a personal model from raw images.

### Gaps
- No 2025–2026 webcam sitting-posture study with LOSO, real-world sessions and false-alarm rates was found. Search coverage was limited by inaccessible full texts this session.
