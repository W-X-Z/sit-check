# Calibration and Personalization Strategies for Posture/Behavior Monitoring (on-device, little data)

> Method note (read first): during this session, full-text fetching from most academic hosts was blocked by the sandbox egress proxy. Blocked hosts included PubMed Central/NCBI, arXiv, medRxiv, Nature, MDPI, Google Patents, Justia and several university servers. Most findings below therefore come from search-engine-indexed abstracts and summaries of the cited pages, not from reading the full papers. When I could not confirm which paper a number came from, I marked it "(attribution per search snippet)". Sample sizes are given wherever the abstract reported them. Inferences are kept separate from cited facts. Context: single-user macOS menu-bar app on an Intel iMac with the built-in webcam. Current method: a 3-s median "good posture" baseline, then alerts on roll >12°, yaw >18° or face width >+15% held for 90 s. Target: ≤2 false alarms per day. Constraint: no enforced symmetry or prescribed correction direction before a diagnosis.

## 1. How do posture monitors calibrate (IMU wearables, webcam systems), and how large is the generic-vs-personalized accuracy gap?

### Takeaway
Commercial posture devices and apps almost all calibrate the same way. The user sets an explicit "good" pose, and the device alerts on a fixed deviation from it that lasts long enough. Only a few go further: Lumo's patented automatic calibration from walking, and SitApp's personal model trained on "best posture" and "worst slouch" examples. In both posture classification and human activity recognition (HAR), person-specific or personalized models beat generic ones. Examples: a pressure-sensing chair scored 96% on known users vs 79% on new users, and HAR studies report 85.1%→95% and 55.6%→74.8% balanced accuracy. A few minutes of personal data, or about 5 labels per class, already captures much of that gain.

### Cited Findings
**Wearables (IMU): products, patents, research**
- Upright GO: calibration "teaches your GO what your desired posture is". All feedback is relative to this baseline. Users should recalibrate every time the device is placed on the back, or whenever it feels off. They should calibrate in the position they use most (calibrate while sitting for sitting use), in a comfortable upright posture they can hold, without overextending or stiffening. Calibration starts from the app or with a double-click (two short vibrations, then stay upright one more second). The device vibrates when the user is no longer upright. — [UPRIGHT Q&A](https://www.uprightpose.com/?p=4249); [UPRIGHT calibration page](https://www.uprightpose.com/?p=364); [UPRIGHT GO user manual](https://www.electronicsdatasheets.com/datasheet/UPRIGHT%20GO%20User%20Manual.pdf)
- Lumo Lift bench test (Mälardalen University student publication; 2 devices, not peer-reviewed). The device was calibrated upright on a ruler, and the ruler was then tilted. At "normal" tilt speed, vibration triggered between **6° and 25°** of forward tilt. In two trials, one device never vibrated through a full 90° tilt. Backward tilt triggered at **8–32°**. — [MDU publication 4130](https://www.es.mdu.se/publications/4130-Posture_Sensor_as_Feedback_when_Lifting_Weights)
- LUMO BodyTech patent application US20170258374A1, "System and method for automatic posture calibration" (appl. 15/454,514). The system detects walking from kinematic data, calibrates to a "base walking orientation", sets a posture correction factor, and triggers feedback on the adjusted posture. — [Google Patents](https://patents.google.com/patent/US20170258374); [Justia](https://patents.justia.com/patent/20170258374) (summary per search index; full text not opened)
- Implantable-device precedents for automatic posture calibration:
  - Cardiac Pacemakers, "Posture sensor automatic calibration": calibrates when walking states or posture changes are detected. — [US8165840B2](https://patents.google.com/patent/US8165840)
  - Medtronic, "Automated calibration of posture state classification": posture vectors are associated with posture-state definitions with minimal clinician intervention. — [US9149210B2](https://patents.google.com/patent/US9149210)
- Patent "System and method of biomechanical posture detection and feedback": users can start a calibration and record personalized stationary postures, pelvic-tilt angles and state-transition signals, later used to quantify good vs bad posture. — [US 9286782](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9286782) (search snippet)
- Smart seat-cover patent: the user enters height and weight, and an "automatic profiling process" assigns acceptable pressure thresholds. Thresholds may depend on age, gender, weight and height. — [US 9795322](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9795322) (search snippet)
- Research IMU example: two tri-axial accelerometers (upper neck and just below C7) were calibrated in the "most upright posture". Sagittal angles were recorded at 20 Hz and averaged each second, and the neck module vibrated when the angle exceeded a programmable threshold. — [Sensors 21(7):2379](https://www.mdpi.com/1424-8220/21/7/2379/html) (attribution per search snippet)
- Wearable design documents and patents found by search use thresholds of roughly **2° to 15°** beyond the calibrated upright posture and feedback latencies of about **2–3 s**. These are low-quality sources. — [US 11957457](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11957457); [UIUC ECE445 project](https://courses.grainger.illinois.edu/ece445/project.asp?id=11509)

**Webcam apps and methods**
- StopSlouching compares seated posture against a baseline the user calibrates. It reminds the user when they drift past a user-chosen threshold "for a sustained period". — [AlternativeTo listing](https://alternativeto.net/software/stopslouching/about/)
- SitApp (macOS): the user shows "your best posture and worst slouch" and can add as many poor-posture poses as they like. The app builds a personal model that runs on-device ("no frames are uploaded"). Recommended distance from the lens is 40–60 cm. — [Mac App Store](https://apps.apple.com/us/app/sitapp-posture-reminder/id6768987893?mt=12)
- Face-landmark pixel displacements depend on distance to the camera, and normalizing by eye width reduces that dependence. A user-dependent calibration at an initial stage lets head pose be computed without measuring the camera–user distance. — [US 11813054](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11813054); [US 10671156](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10671156) (search snippets; claims combined across the two)

**Generic vs personalized: posture classification**
- Sensing chair (pressure mats, 10 static postures; Tan et al., as reviewed by Zemp et al.): **96% subject-dependent vs 79% subject-independent**. — [Zemp et al. 2016, BioMed Res Int](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5102712/)
- Zemp et al. 2016 (force sensors plus backrest angle; Random Forest; leave-one-subject-out): **90.9%** mean accuracy on unfamiliar subjects. Another study using an 8×8 pressure array reached **92.2%** subject-independent (8 training subjects, 8 different test subjects). — [Zemp et al. 2016](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5102712/)
- Population cut-offs for forward head posture lack consensus. Craniovertebral angle (CVA) cut-offs for forward head posture range from ≤44° to ≤54°, with "normal" reported above 53–55°. One study derived its 44° cut-off by k-means clustering. Reliability varies with measurement method and rater. — [PMC12329986](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12329986/); [J. Mashhad Univ. Med. Sci. article](https://journals.mums.ac.ir/article_26804_a19632920cb9a8b9fae60efa54801919.pdf) (search snippets; which number comes from which source is approximate)

**Generic vs personalized: HAR personalization literature**
- Weiss & Lockhart compared impersonal (universal), personal and hybrid models. Personal models performed "dramatically better" than impersonal ones, "even when trained from only a few minutes worth of data". — [Weiss & Lockhart, AAAI-12 workshop](https://storm.cis.fordham.edu/gweiss/papers/aaai12-workshop-personalization.pdf). Their deployed Actitracker service starts with a universal model and switches to a "much more accurate" personal model after a simple training phase. — [Actitracker, DSAA 2016](https://storm.cis.fordham.edu/gweiss/papers/dsaa-actitracker-2016.pdf)
- Zdravevski et al. 2018 (single accelerometer): fully personalized **95%**, collaborative-filtering hybrid **91.6%**, generic **85.1%**. The hybrid avoids the cold-start problem. — [UKIM repository](https://repository.ukim.mk/handle/20.500.12188/21206)
- On a 57-subject dataset, personalization raised balanced accuracy from **55.60% to 74.81%**. — [Ulster PhD thesis record](https://pure.ulster.ac.uk/en/studentTheses/personalisation-of-machine-learning-models-for-human-activity-rec/) (attribution per search snippet)
- Scheurer et al. 2020, *Sensors* (8 datasets, 4 algorithms): person-specific models (PSMs) beat person-independent models (PIMs) by **43.5%** on subject-dependent performance. PIMs beat PSMs by **55.9%** on subject-independent performance. — [PMC7374316](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7374316/)
- Lin & Marculescu (PerCom Workshops 2020): **+6–14%** accuracy on the target user with **five labeled samples per class**, across three public datasets. — [paper PDF](https://staff.itee.uq.edu.au/jaga/proceedings/percomworkshops2020/papers/p304-lin.pdf)
- On-device few-shot framework (2025 preprint): a cross-user representation is trained first, then only a lightweight classifier layer is updated on the device. Post-deployment adaptation gave **+3.73%, +17.38% and +3.70%** on RecGym, QVAR-Gesture and Ultrasound-Gesture. — [arXiv 2508.15413](https://arxiv.org/pdf/2508.15413v2)
- Driver-drowsiness analog: adapting a group-trained neural network to a specific driver improves drowsiness detection and prediction. — [HAL hal-01878111](https://hal-amu.archives-ouvertes.fr/hal-01878111v1)

### Inferences
- The current app follows standard industry practice: explicit pose, fixed delta and persistence (StopSlouching works the same way). The open questions are elsewhere: whether the reference is representative, whether it drifts, robustness to setup changes, and feedback-driven tuning.
- **Option A (body-pose skeleton with population thresholds) has weak support.** Even the most-studied population posture metric (CVA) has no agreed cut-off. A population "ideal" also assumes symmetry (roll ≈ 0, level shoulders), which conflicts with the pre-diagnosis rule against prescribing a direction. Population limits are better used as plausibility and quality gates (e.g., "yaw this large means the user is looking away; ignore") than as alert triggers.
- **Option B (posture library, then feedback personalization) has good support.** Personalization helps, and small amounts of data are enough (minutes of data, or about 5 labels per class). A few-shot nearest-neighbor or prototype classifier over a handful of personal examples (as in SitApp's best/worst poses) is cheap to run on-device. The weak point is label quality, not model capacity (see Q5).
- For a single user, the "subject-independent" failure mode becomes a cross-setup failure: a model or baseline fit to one camera/chair/monitor geometry is effectively applied to a "new subject" after the setup changes. The 96%→79% chair result shows how large such a shift can be. Detecting setup changes (Q2) is therefore part of personalization, not a separate add-on.
- Device-level threshold inconsistency (Lumo Lift's 6–25° trigger spread) suggests that persistence/hold logic and filtering matter as much as the nominal angle threshold.

### Gaps
- No peer-reviewed study was found that compares generic and personalized **webcam/face-based** posture detection on the same users. The evidence comes from pressure chairs, IMUs and HAR.
- No independent validation of Upright GO trigger thresholds was found. Commercial webcam apps (StopSlouching, SitApp) document their algorithms only in store text.
- Full texts were not readable, so per-activity numbers and the exact amount of personal data needed in Weiss & Lockhart could not be extracted.

## 2. Automatic calibration: selecting "good" reference windows, avoiding contamination, detecting setup changes

### Takeaway
Automatic calibration that holds up in practice anchors on a state that is easy to identify and constrains posture. Examples are walking for trunk IMUs (Lumo, implant patents) and the first minutes of a session for driver monitors. The reference is then estimated from many such windows with robust statistics. Contamination is limited by quality gates, choosing early-in-bout windows, median/MAD estimators (50% breakdown point) and excluding alert periods. Setup changes look like abrupt step changes in several geometry features at once. They are best caught by change-point detectors (CUSUM, Bayesian online changepoint detection (BOCPD), ADWIN) followed by one-tap confirmation, rather than silent adaptation.

### Cited Findings
- **Anchoring on a constrained activity:**
  - Lumo's automatic calibration detects walking and calibrates to a "base walking orientation" plus a correction factor. — [US20170258374A1](https://patents.google.com/patent/US20170258374)
  - The Cardiac Pacemakers patent calibrates when walking or posture changes are detected. — [US8165840B2](https://patents.google.com/patent/US8165840)
- **Calibration from accumulated idle data:** thresholds "can be calculated from an automatic calibration procedure" in which, after one or more days of use, data from inactive or sedentary periods are stored and clustered. — [US 10980446](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10980446) (search snippet)
- **Session-start baselines (driver/worker monitoring):** a camera system can use the first few minutes, when the person is expected to be alert, to compute mean and variance and calibrate. The patent itself warns the person "may not be in a completely normal state" at that point. — [US 10740633](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10740633). In the UTA-RLDD drowsiness dataset work, the first third of each subject's alert-state blinks gives per-feature mean and SD, which normalize the rest of that subject's data. — [arXiv 1904.07312](https://arxiv.org/pdf/1904.07312)
- **The explicit "good posture" pose is not the habitual posture.** Mabb et al. 2013 (*Scoliosis*; n=24 asymptomatic young adults) compared habitual sitting (HSP), subjectively perceived ideal (SPIP) and neutral sitting (NSP). — [PMC3847868](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3847868/)
  - HSP was more kyphosed than NSP at the upper lumbar spine (mean difference 4.63°, 95% CI 1.97–7.29).
  - SPIP was less kyphosed than NSP at the lower thoracic spine (mean difference −2.31°).
  - Cervical erector spinae activity was higher in HSP (p=0.001). Thoracic erector spinae and external oblique activity was higher in SPIP and NSP than in HSP.
- Upright GO's calibration instructions ask users not to "overextend or stiffen" and to choose a posture they can hold. This is an implicit acknowledgment of calibration-pose bias. — [UPRIGHT Q&A](https://www.uprightpose.com/?p=4249)
- **Posture degrades within a sitting bout.** All 46 office workers (23 with chronic low back pain (LBP), 23 controls; 1 h of typing; seat pressure mat) slumped after about 20 minutes. — [Akkarakittichoke & Janwantanakul 2017, Saf Health Work](https://pmc.ncbi.nlm.nih.gov/articles/PMC5447416)
- **Robust estimators:** the median absolute deviation (MAD) is the most robust dispersion measure in the presence of outliers, and Leys et al. 2013 recommend median ± 2.5×MAD by default. — [mathematical docs summarizing Leys et al. 2013](https://mathematical.readthedocs.io/en/latest/api/outliers.html). The modified z-score has a 50% breakdown point, and 1.4826×MAD is a consistent estimator of SD under normality. — [MetricGate: Iglewicz–Hoaglin](https://metricgate.com/docs/iglewicz-hoaglin-modified-z-outliers/)
- **Camera "moved" detection (surveillance literature):**
  - Tampering is grouped into covered (occlusion), defocused (blur) and moved (changed viewing direction). Methods either target one type each or use unified detectors that trade classification ability for lower complexity. — [Survey, arXiv 2310.07886](https://arxiv.org/pdf/2310.07886); [comparative study, arXiv 1608.02385](https://arxiv.org/pdf/1608.02385)
  - Typical features: accumulated strong edges, or similarity between the current edge image and a reference edge image. — [US 8073261](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/8073261) (search snippet)
- **Change-point and drift detectors usable on-device:**
  - BOCPD (Adams & MacKay 2007) computes the posterior over "run length" (time since the last changepoint) online with simple message passing. — [Adams & MacKay](https://ar5iv.arxiv.org/html/0710.3742); [explainer](https://gregorygundersen.com/blog/2019/08/13/bocd)
  - ADWIN (Bifet & Gavaldà 2007) grows its window while data are stationary and shrinks it on change. It compares sub-window means with a Hoeffding bound, and its false-detection probability is bounded by δ. — [scikit-multiflow ADWIN docs](https://scikit-multiflow.readthedocs.io/en/latest/api/generated/skmultiflow.drift_detection.ADWIN.html)
  - Page-Hinkley and other drift detectors are packaged in R `datadriftR`. — [datadriftR reference](https://cran.nics.utk.edu/cran/web/packages/datadriftR/refman/datadriftR.html)

### Inferences
- **Choosing reference minutes for an auto-baseline (Option C, made safer):**
  1. Quality gates: face found in most frames of the minute, near-frontal (generous |yaw| bound), low within-minute motion, adequate light.
  2. Loose, *symmetric* population plausibility gates only. Strict population gates could reject an asymmetric user's normal posture entirely, or quietly force symmetry.
  3. Prefer "settled early-bout" minutes: roughly minutes 2–15 after sitting down. Slumping tends to appear after about 20 min (Akkarakittichoke 2017), and early minutes are the posture-constrained state, like Lumo's walking.
  4. Exclude minutes during or shortly before alerts.
  5. Require coverage across at least 3 separate days before activating.
  6. Estimate with the median of per-minute medians and 1.4826×MAD across minutes. The median tolerates up to 50% contaminated minutes, unlike a mean.
- **"Pass population thresholds, then average" (Option C as written) has two failure modes.** If the gates are loose, slumped minutes get in. If they are tight, an asymmetric user may never produce a qualifying sample. Using the *mode* of the user's own early-bout distribution, with loose gates, avoids both.
- **Reconciling explicit and automatic baselines:** keep both. If the explicit 3-s baseline lies more than about 2 robust SDs from the auto-baseline, show the user ("your saved 'good posture' differs a lot from how you usually start sessions") rather than silently choosing. Mabb et al. suggest an explicit "ideal" pose will be more upright than habitual sitting, which biases alerts toward over-firing. A 3-s capture is also short compared with the minutes of data an auto-baseline uses.
- **Setup-change detection on the iMac.** The built-in camera is fixed to the display, so "camera moved" mostly means display tilt or height changes, a moved iMac, a different chair height or position, or a different viewing distance.
  - Expected signatures: step changes in face-box center (x, y), face size and possibly yaw (chair off-center). Step changes in head roll should be rare from setup alone.
  - Detection: run a two-sided CUSUM or BOCPD on standardized per-minute medians of these geometry features.
  - Decision rule: a step in two or more geometry features within a few minutes of a session boundary (long idle, wake from sleep, camera reconnect) means "setup change suspected". Then pause absolute-threshold alerts, fall back to within-session relative measures (Q4), and offer a one-tap "re-learn my baseline?" after about 20–30 qualifying minutes.
- Surveillance tamper detectors compare against stored reference images. This app never stores frames, so the equivalent would be a tiny scene signature, such as a coarse background brightness or edge histogram. That is still derived image data and needs an explicit privacy decision; geometry features alone may be enough.

### Gaps
- No study was found that evaluates automatic re-baselining for **webcam** posture monitoring after camera/chair/monitor changes, or that measures contamination rates of auto-baselines in posture apps.
- The full text of the Lumo automatic-calibration patent was not readable, so its window lengths and thresholds are unknown.
- How much head roll or yaw from a front camera reflects trunk asymmetry versus head posture or gaze was not covered here (likely another researcher's scope).

## 3. Concept drift in long-term personal sensing: guardrails that stop an adaptive baseline from following gradual deterioration

### Takeaway
Treat learning the baseline and monitoring against it as separate phases, as statistical process control (SPC) does with Phase I (estimation) and Phase II (monitoring). A baseline that updates continuously from the stream it monitors will absorb slow deterioration as "normal", and false-alarm guarantees are hard to state when parameters keep being re-estimated. Practical guardrails, drawn from SPC, drift-detection and wearable-health practice:
- an immutable anchor reference;
- slow, bounded, gated updates;
- a lagged baseline window, comparing recent data with older data;
- two-tier persistence alerts;
- explicit user confirmation once cumulative drift passes a cap.

### Cited Findings
- Gama, Žliobaitė, Bifet, Pechenizkiy & Bouchachia 2014 (*ACM Computing Surveys* 46(4)): define concept drift (the input–target relation changing over time), categorize adaptation strategies and cover evaluation methodology for adaptive learners. — [TU/e record](https://research.tue.nl/en/publications/a-survey-on-concept-drift-adaptation/); [IP Paris record](https://researchportal.ip-paris.fr/en/publications/a-survey-on-concept-drift-adaptation/)
- **Self-starting control charts:**
  - Hawkins' self-starting CUSUM (1987) re-estimates mean and SD with each new observation, turns standardized residuals into approximately i.i.d. N(0,1) "Q-statistics", and feeds them into an ordinary CUSUM. No Phase I calibration window is needed. — [MetricGate: Hawkins self-starting CUSUM](https://metricgate.com/docs/hawkins-cusum-self-starting/)
  - Traditional Phase I needs "inordinately large and unproductive samples". — [arXiv 2410.12736](https://arxiv.org/html/2410.12736v1)
  - Setting a decision threshold that guarantees a preset false-alarm tolerance is "a very difficult task" when parameters are unknown and sequentially updated. — [Predictive Ratio CUSUM paper (Polimi)](https://re.public.polimi.it/bitstream/11311/1229847/1/Predictive%20ratio%20CUSUM%20%28PRC%29%20A%20Bayesian%20approach%20in%20online%20change%20point%20detection%20of%20short%20runs.pdf)
- SPC tooling exists for charts whose in-control state is estimated rather than known. — [CRAN spcadjust vignette "EWMA chart with estimated in-control state"](https://cran.case.edu/web/packages/spcadjust/vignettes/EWMA_NormalNormal.html) (title-level evidence only)
- **Personal-baseline anomaly detection in wearables (Mishra et al. 2020, *Nature Biomedical Engineering*):**
  - Cohort: about 5,300 participants. Of 32 COVID-19 cases with data, 26 (81%) showed changes in heart rate, steps or sleep, and 22 of 25 cases with symptom data were flagged at or before symptom onset. — [Nature BME](https://www.nature.com/articles/s41551-020-00640-6); [Stanford Medicine news](https://med.stanford.edu/news/all-news/2020/12/smartwatch-can-detect-early-signs-of-illness.html); [PMC9020268](https://pmc.ncbi.nlm.nih.gov/articles/PMC9020268/)
  - RHR-Diff compares each hourly interval against a **28-day sliding baseline** using standardized residuals. The online CuSum detector has **two tiers**: a "yellow" alert for initial deviations and a "red" alert if the signal persists (reported as >24 h). A real-time version could have caught 63% of cases before symptoms. — same sources (algorithm details per search-index summary)
- ADWIN responds to change by shrinking its window, dropping stale data. — [scikit-multiflow ADWIN](https://scikit-multiflow.readthedocs.io/en/latest/api/generated/skmultiflow.drift_detection.ADWIN.html)
- Upright GO sidesteps long-term drift by asking for recalibration every time the device is put on, re-anchoring each session. — [UPRIGHT Q&A](https://www.uprightpose.com/?p=4249)
- In streaming active learning, drift can occur away from the decision boundary, where a classifier that queries only uncertain points never notices it. Žliobaitė et al. therefore combine uncertainty-based querying with randomization and dynamic allocation of the labeling budget. — [Žliobaitė et al., ECML/PMLR 2011](https://proceedings.mlr.press/v17/zliobaite11a.html); [IEEE TNNLS 2014 record](https://researchportal.ip-paris.fr/en/publications/active-learning-with-drifting-streaming-data/)

### Inferences
- **Guardrails for Option C.** The parameter values below are my suggestions, not evidence-derived; tune them by replay (Q6).
  1. **Immutable anchor `A0`.** The first validated baseline, from the explicit pose and/or the first week of auto-baseline. Only the user can replace it, via "re-anchor".
  2. **Working baseline `B_t` updated slowly and only from gated minutes** (the Q2 criteria), at most once a day or week. For example, an EWMA on daily medians with a half-life of several weeks.
  3. **Per-update clamp:** each update moves at most about 0.25 robust SD.
  4. **Cumulative cap:** |B_t − A0| ≤ about 1 robust SD (or a fixed angle or percentage). Hitting the cap freezes updates and produces a non-judgmental message such as "your typical head tilt has shifted 3° since <date>; re-learn or keep?" The user decides.
  5. **Lagged comparison window (Mishra-style sliding baseline plus a gap):** compare the last 7 days against days 8–35. Slow deterioration then appears as a difference instead of being absorbed. The gap is my addition; Mishra used a 28-day sliding window.
  6. **Freeze learning around alerts:** no baseline updates from alert periods or the minutes just before them.
  7. **Two-tier output, as in Mishra:** a soft, glanceable status indicator for short deviations; a notification only when deviations persist.
- **Direction-agnostic constraint:** many drift guardrails in practice allow updates toward "better" and resist updates toward "worse". That is only acceptable for features with a defensible bad direction, such as face size growing as the user leans toward the screen. For roll and yaw (lateral), "better" cannot be defined before a diagnosis, so caps and alerts must be **symmetric** around the user's own anchor.
- The drift itself is useful information. Log `B_t − A0` over weeks as a neutral trend that the user (or a clinician later) can review. This is safer than either silently adapting or silently alerting.

### Gaps
- No posture-specific study evaluating baseline-drift guardrails (update rates, caps, anchors) was found. The evidence is borrowed from SPC, streaming ML and wearable-illness detection.
- Whether Mishra et al. excluded alarm periods from the baseline could not be confirmed (full text blocked).

## 4. Within-session relative measures and variability metrics as alternatives to absolute "correctness"

### Takeaway
Studies show posture changes progressively within a session: workers slumped after about 20 min, and trunk flexion increased from 10 to 20 to 30 min of computer work. Posture shifts, fidgeting and sedentary breaks are linked to comfort and health markers, and ergonomics reviews reject the idea of a single "correct" posture. This supports direction-agnostic signals: drift relative to the start of the current bout, stillness duration, and posture variability. However, none of these has been validated as a **webcam alert criterion**. Bout-relative measures also fail when a bout starts badly or is short.

### Cited Findings
- **No single correct posture:** Slater, Korakakis, O'Sullivan, Nolan & O'Sullivan 2019 (*JOSPT*), "Sit Up Straight: Time to Re-evaluate":
  - There is no strong evidence for one optimal posture, or that avoiding "incorrect" postures prevents low back pain.
  - Spinal curvatures vary naturally, and comfortable postures vary between individuals.
  - Exploring different postures may relieve symptoms.
  - Common warnings to "protect" the spine are not evidence-informed and can create fear.

  — [University of Limerick record](https://pure.ul.ie/en/publications/sit-up-straight-time-to-re-evaluate/)
- **Slumping within the first hour:** Akkarakittichoke & Janwantanakul 2017 (n=46; 1 h typing; seat pressure mat). — [PMC5447416](https://pmc.ncbi.nlm.nih.gov/articles/PMC5447416); [DOAJ record](https://doaj.org/article/ec1601ccbcd9450397d258ab51f9c38a)
  - All workers slumped after about 20 min.
  - The chronic-LBP group sat more asymmetrically.
  - Healthy workers made significantly more postural shifts than the LBP group.
  - The authors recommend changing posture often and taking a short break from sitting every 20 min.
- In 30 min of computer work, the change in trunk flexion angle increased significantly from 10 to 20 to 30 min, and cervical erector spinae activation rose over time. — [Yonsei University repository item](https://ir.ymlib.yonsei.ac.kr/handle/22282913/201844) (attribution per search snippet)
- Greater head flexion predicted seated upper-quadrant musculoskeletal pain developing over time: the pain score rose **0.22 points per 1° of head flexion**. This is a conference abstract. — [World Physiotherapy congress proceeding](https://world.physio/congress-proceeding/relationship-between-sitting-posture-and-seated-related-upper-quadrant)
- Sammonds, Fray & Mansfield 2017 (*Applied Ergonomics* 58:119–127; 140-min simulated drive): as rated discomfort rose, the frequency of seat fidgets and movements rose with it. The large correlation lets movement serve as an objective remote measure of discomfort. — [Loughborough repository](https://repository.lboro.ac.uk/articles/journal_contribution/Effect_of_long_term_driving_on_driver_discomfort_and_its_relationship_with_seat_fidgets_and_movements_SFMs_/9347123)
- Healy et al. 2008 (*Diabetes Care* 31(4):661–666; n=168; accelerometer for 7 days): more breaks in sedentary time were beneficially associated with metabolic-risk markers. The authors argue for avoiding prolonged uninterrupted sedentary time. — [Curtin espace record](https://espace.curtin.edu.au/handle/20.500.11937/10528)
- **Product precedent for a non-judgmental, time-based prompt:** Apple Watch reminds the user to stand at 50 minutes past the hour if they have not stood and moved for at least 1 minute during that hour. — [TekRevue explainer](https://www.tekrevue.com/tip/disable-apple-watch-stand-reminders/)
- **Session-start references in driver monitoring:** first-minutes baselines are used, with the caveat that the person may not be "normal" at the start. — [US 10740633](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10740633); [arXiv 1904.07312](https://arxiv.org/pdf/1904.07312)

### Inferences
- **Option D fits the constraints best:** no prescribed direction, no population ideal, no long-term baseline that can drift. Candidate signals, computable from per-minute aggregates:
  1. **Bout-relative drift.** Define the bout reference as the median of minutes 2–5 after sitting down. Drift is the median of the last 5 min minus that reference, in robust-z units. Alert only if drift persists, and phrase it neutrally ("you've drifted from how you started").
  2. **Stillness.** Minutes since the last postural shift. A shift is a change in face center, size or roll larger than k × the within-minute jitter (MAD). Prompt after a long still period (e.g., 30–50 min), mirroring the Apple Watch stand logic.
  3. **Variability.** Shifts per 30 min, or the IQR of features per 30 min, shown as a trend, not an alarm.
  4. **Bout length.** Time since sitting down, with a break prompt (e.g., 20–50 min; the Akkarakittichoke authors suggested 20 min).
- **Failure modes:**
  - (a) A bout that starts slumped makes the reference itself bad. Mitigate by also comparing the bout reference to the long-term anchor (Q3) and flagging large gaps without judgment.
  - (b) Short bouts (under ~10 min) give no reliable reference.
  - (c) Movement is ambiguous: Sammonds shows fidgeting *increases* with discomfort, while Akkarakittichoke links more shifting to healthy workers. A movement count should be shown as information, not scored as good or bad.
  - (d) Face-based shift detection also responds to looking at a phone, papers or a second screen.
- **A hybrid is likely strongest:** Option D signals as the default notification channel (low false-alarm risk, no direction), and absolute or personal-baseline deviations (Option C) shown only as a glanceable indicator or daily summary until feedback labels show they are precise enough.

### Gaps
- No study was found that compares within-bout relative alerts with absolute-threshold alerts on false-alarm rate, adherence or pain outcomes, and none was found for webcam or face-based features.
- Sammonds 2017's sample size, and the exact source and sample size of the "10 < 20 < 30 min" trunk-flexion result, could not be confirmed.
- No validated, posture-specific "stillness" threshold (minutes) was found; recommendations (20 min breaks, hourly stand) come from adjacent domains.

## 5. User-feedback labeling ("was this alert right?"): prompt design, label noise, label budgets, active learning

### Takeaway
One-tap micro-prompts get high response rates (μEMA: 87% completion, about 5 s per answer), and delivering prompts at task breakpoints reduces frustration. In HAR, active learning typically needs only about 7–10% of labels, and a few minutes of data or about 5 labels per class already personalizes a classifier. However, "was this alert right?" labels are biased and noisy:
- they exist only for moments that triggered an alert;
- annoyance colors the answer;
- people misjudge their own posture.

They should therefore tune a few parameters (thresholds, hold time) rather than train a complex model. A small random-query budget is needed to catch misses and drift.

### Cited Findings
- **μEMA (Intille and colleagues):** single-question, one-tap smartwatch prompts. One study reported **87.01% completion (5226/6006)**, **74.00% compliance (5226/7062)** and **5.4 s (SD 1.5)** average time per answer. μEMA may allow much higher prompting rates than conventional EMA, with higher response and lower burden. — [JMIR mHealth uHealth 2021;9(3):e23391](https://mhealth.jmir.org/2021/3/e23391/PDF); [Northeastern μEMA project](https://www.khoury.northeastern.edu/research_projects/microinteraction-ecological-momentary-assessment/) (numbers per search snippet). A separate paper studies contextual biases in μEMA non-response. — [OUCI record](https://ouci.dntb.gov.ua/works/40DKKBW4) (title-level only)
- **Timing:** Iqbal & Bailey, CHI 2008. Delivering notifications at task breakpoints reduced frustration and reaction time compared with immediate delivery, and the relevance of the content determines which kind of breakpoint suits it. — [Iqbal & Bailey CHI'08 PDF](https://www.interruptions.net/literature/Iqbal-CHI08.pdf)
- **Annotation method affects label quality:** Hoelzemann & Van Laerhoven 2023 (11 participants, 2 weeks, 4 annotation methods). — [arXiv 2305.08752](https://arxiv.org/pdf/2305.08752)
  - In-situ annotation gives fewer but more precise labels than recall.
  - Participants often forgot to annotate.
  - A data-visualization tool reduced missing labels, improved consistency and raised deep-learning F1 by up to 8%.
- **In-the-wild self-labels:** ExtraSensory (Vaizman et al.) has 60 users, more than 300k examples and 51 self-reported labels, with considerable missing data. — [Frontiers in Computer Science 2024](https://www.frontiersin.org/journals/computer-science/articles/10.3389/fcomp.2024.1379788/pdf). Recall-based labels are "notoriously unreliable". — [eScholarship (Vaizman)](https://escholarship.org/uc/item/200910xx)
- **Self-perception is unreliable for posture:** people's "perceived ideal" sitting posture differed from neutral sitting (Mabb et al. 2013, n=24). — [PMC3847868](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3847868/)
- **Active learning in HAR:**
  - Adaimi & Thomaz (IMWUT 2019): comparable or better performance than supervised training using about **10%** of the training data. — [paper PDF](https://users.ece.utexas.edu/~ethomaz/papers/j6.pdf)
  - Alemdar et al. 2017 (smart homes, uncertainty sampling): nearly the same performance as full labeling with **7%** of data points. — [METU publication page](https://user.ceng.metu.edu.tr/~alemdar/publication/2017_j_jaise/)
  - ActiveSense (area-under-the-margin uncertainty): a model trained on **0.15%** of the data generalized better than one trained on 85%. — [Habits Lab](https://www.thehabitslab.com/publications/activesense/)
- **Streaming active learning under a budget:** Žliobaitė et al. define budget B as the maximum fraction of incoming points that can be labeled. They propose variable-uncertainty strategies plus randomization, because uncertainty-only querying misses drift away from the boundary. — [PMLR v17 (2011)](https://proceedings.mlr.press/v17/zliobaite11a.html); [TNNLS 2014 record](https://researchportal.ip-paris.fr/en/publications/active-learning-with-drifting-streaming-data/)
- **Label amounts for personalization:** five labels per class gave +6–14% ([Lin & Marculescu](https://staff.itee.uq.edu.au/jaga/proceedings/percomworkshops2020/papers/p304-lin.pdf)). A few minutes of personal data beat impersonal models ([Weiss & Lockhart](https://storm.cis.fordham.edu/gweiss/papers/aaai12-workshop-personalization.pdf)).
- **Alert fatigue reduces engagement:** a time-motion ICU study (Görges et al. 2009) found clinicians ignored **41%** of alarms. — [AHRQ PSNet summary](https://psnet.ahrq.gov/issue/improving-alarm-performance-medical-intensive-care-unit-using-delays-and-clinical-context)

### Inferences
- **Prompt design (μEMA-style, at most one tap):** the macOS notification offers "Right", "I was fine" and "Setup changed", plus Snooze.
  - The third option separates setup changes from wrong alerts, which also feeds Q2.
  - No response counts as missing, never as negative.
  - Ask for feedback on only a subset: the first alert of the day, alerts whose score is near threshold (uncertainty sampling), plus a small random share.
  - Defer the question to a breakpoint, such as the next return from idle or right after the user corrects posture. Cap at about 3 questions per day.
- **Bias in alert feedback:**
  - Feedback labels estimate **precision** (positive predictive value, PPV) only. Misses are never seen.
  - Occasional random spot-check prompts ("quick check: comfortable right now?"), at a rate of perhaps 1–2 per day, give an unbiased sample. This follows Žliobaitė's randomization rationale.
  - Expect noise from annoyance and from mistaken self-perception. Weight a label by its consistency with the features (e.g., an "I was fine" when |z| is huge is suspect).
- **What to fit with few labels.** Use the labels to adjust 1–3 scalars per feature (threshold z*, hold time, perhaps the cooldown) with simple Bayesian updates, such as a Beta posterior on precision at the current settings. Do not train a high-capacity classifier. A few-shot nearest-neighbor or prototype model (Option B) becomes viable once there are roughly 5 or more confirmed examples per posture class, built from per-minute feature vectors in robust-z space with a "reject if far from all prototypes" rule.
- **How many labels (basic binomial arithmetic):**
  - Estimating precision to ±10 percentage points (95% CI, worst case p=0.5) needs about 1.96²×0.25/0.1² ≈ **96 labeled alerts**. ±15 points needs about 43.
  - At 2–5 alerts a day with ~60% labeled, that is roughly 3–8 weeks for ±10 points. Personalization should start with small, conservative steps.

### Gaps
- No study was found that measures label noise or response behavior specifically for "was this alert right?" prompts in posture or ergonomics apps.
- No posture-specific evidence was found on how many labels are needed to tune thresholds. The figures above are statistical arithmetic and HAR analogies.
- Primary μEMA paper details (population, prompt rate) were not verified because the full text was blocked.

## 6. Thresholds from the personal distribution, hold-time tuning to a false-alarm target, and offline replay of logged features

### Takeaway
Set thresholds from robust personal statistics: median ± k·1.4826·MAD, or empirical percentiles of vetted "settled" minutes. Express the ≤2 false alarms/day target as an in-control average run length (ARL), and tune threshold × hold × cooldown by replaying the logged per-minute features. In the alarm literature, persistence or delay requirements are the strongest single lever: delays of about 14–19 s cut ICU alarms by roughly 50–67% (secondary sources). Offline evaluation should use event-based metrics (Ward et al.) with an explicit low-false-positive weighting (Numenta Anomaly Benchmark (NAB) "low FP" profile).

### Cited Findings
- **Robust thresholds:**
  - Leys et al. 2013 recommend median ± 2.5×MAD by default (2.5 described as a reasonable choice), with a justified threshold and reporting of outliers. — [mathematical docs](https://mathematical.readthedocs.io/en/latest/api/outliers.html); [ULB record](https://difusion.ulb.ac.be/vufind/Record/ULB-DIPOT:oai:dipot.ulb.ac.be:2013/139499/TOC)
  - Iglewicz–Hoaglin modified z: z_m = 0.6745·(x − median)/MAD, flagged when |z_m| > 3.5, which roughly matches the false-positive rate of a classical |z| > 3 rule but with a 50% breakdown point. 0.6745 is the 0.75 quantile of N(0,1), and 1.4826 = 1/0.6745. — [MetricGate](https://metricgate.com/docs/iglewicz-hoaglin-modified-z-outliers/)
- **Streaming quantiles:** the P² algorithm (Jain & Chlamtac, *CACM* 1985) estimates quantiles without storing observations. It keeps 5 markers (min, max and quantile estimates) adjusted with a piecewise-parabolic formula, in fixed memory. — [Jain's P² page](https://www.cs.wustl.edu/~jain/papers/psqr.htm). Implementations exist in Boost.Accumulators and Apache Commons Math. — [Boost p_square_quantile](https://www.boost.org/doc/libs/latest/boost/accumulators/statistics/p_square_quantile.hpp); [Apache Commons PSquarePercentile](https://commons.apache.org/proper/commons-math/commons-math-docs/jacoco-aggregate/commons-math4-legacy/org.apache.commons.math4.legacy.stat.descriptive.rank/PSquarePercentile.java.html)
- **EWMA control charts (NIST handbook):** the EWMA gives geometrically decreasing weight to older data. λ is usually 0.2–0.3 (Lucas & Saccucci 1990 tables help choose it). The EWMA variance is about (λ/(2−λ))·s². — [NIST e-Handbook 6.3.2.4](https://itl.nist.gov/div898/handbook/pmc/section3/pmc324.htm). ARL at zero shift is the expected number of samples before a false alarm. — [JMP: ARL report for EWMA](https://jmp.com/support/help/en/16.0/jmp/average-run-length-report-for-ewma-control-charts.shtml)
- **CUSUM:**
  - Parameters are the reference value k and the decision interval h, chosen from desired ARLs at acceptable and rejectable levels. Two one-sided charts monitor both directions. — [NIST e-Handbook 6.3.2.3.1](https://itl.nist.gov/div898/handbook/pmc/section3/pmc3231.htm)
  - Standard tabular design: k=0.5 with h=4 gives ARL₀ ≈ 168, and h=5 gives ARL₀ ≈ 465 (textbook values, Montgomery). — [MetricGate CUSUM run-length docs](https://metricgate.com/docs/page-cusum-run-length/) (secondary source)
- **Persistence/delay and alarm reduction:**
  - Secondary sources report that a 14–15-s delay between threshold crossing and alarm reduced false-positive alarms by about 50–60%, and a 19-s delay by about 67%. Sources disagree on which delay pairs with which percentage. They attribute these figures to Görges et al. 2009, *Anesth Analg* 108:1546–52. — [Critical review of alarm-reduction methods, arXiv 2302.03885](https://arxiv.org/pdf/2302.03885); [AHRQ PSNet](https://psnet.ahrq.gov/issue/improving-alarm-performance-medical-intensive-care-unit-using-delays-and-clinical-context) (primary text not verified)
  - More recent ICU work reports that a 10-s delay removed more than half of alarms, and that delays should be tailored to each parameter. Adaptive time delays have also been proposed. — [Thieme article 10.1055/s-0042-118618](https://www.thieme-connect.com/products/all/doi/10.1055/s-0042-118618); [UKE: adaptive time delays](https://fis.uke.de/portal/en/publications/reduction-of-clinically-irrelevant-alarms-in-patient-monitoring-by-adaptive-time-delays%2899275c89-3a53-490d-b14d-65976f65969b%29.html) (search snippets)
- **Product precedents for persistence:**
  - StopSlouching requires drift "for a sustained period". — [AlternativeTo](https://alternativeto.net/software/stopslouching/about/)
  - Mishra et al. escalate to "red" only after a persistent deviation. — [Nature BME](https://www.nature.com/articles/s41551-020-00640-6)
- **Offline evaluation metrics:**
  - Ward, Lukowicz & Gellersen 2011 (*ACM TIST* 2(1)) show that frame-based metrics miss event fragmentation, merging and timing offsets. They propose event-based metrics (correct, inserted, deleted, fragmented, merged events). — [Lancaster eprint](https://eprints.lancs.ac.uk/id/eprint/53444)
  - The Numenta Anomaly Benchmark (Lavin & Ahmad 2015) scores detections within anomaly windows. It rewards the earliest true detection, softly penalizes late ones and penalizes every false positive. A "low FP" application profile weights false alarms more heavily. — [arXiv 1510.03336](https://www.arxiv.org/pdf/1510.03336)

### Inferences
- **Translate the ≤2 false alarms/day target.** About 8 h of monitored sitting is about 480 per-minute samples, so the in-control ARL should be at least **240 minutes** after hold and cooldown logic.
  - A standardized CUSUM with k=0.5 and h≈5 (textbook ARL₀≈465) clears the 240-minute target; h≈4 (ARL₀≈168) does not. By my own Siegmund-approximation check, not from a fetched source, both textbook values are for the two-sided scheme (two one-sided charts); each one-sided chart alone has about twice the ARL₀.
  - Per-minute posture features are autocorrelated, which lowers the real ARL below the i.i.d. tables, so **set h empirically by replay**, not from tables.
  - A simpler equivalent: alert when |robust z| > z* for ≥ hold minutes, then a cooldown (e.g., 30–45 min) and a daily cap. Note that a cap limits total alerts, not false ones.
- **Personal thresholds.** Compute z per feature as (x − baseline) / max(1.4826·MAD, noise floor).
  - The floor stops very stable users from getting hair-trigger thresholds.
  - Start z* at about 3–3.5 (Iglewicz–Hoaglin), or at the personal P99 of settled minutes, and adjust with feedback (Q5).
  - The current fixed limits (12° roll, 18° yaw, +15% width) can be converted into personal-z terms from the logs to see how many robust SDs each represents. A limit that sits much closer to the user's spread on one feature than on the others would explain an uneven false-alarm load.
- **Logging for exact replay.**
  - Per-minute medians cannot reproduce a 90-s hold exactly. Also log, each minute, the **longest run of consecutive seconds above each of a few candidate levels** (e.g., |z| > 2, 2.5, 3, 3.5, 4), or 10–15-s sub-aggregates.
  - Also log: valid-frame fraction; face center and size; roll/yaw medians and within-minute MAD; session and idle boundaries; app/config version; alerts fired; and feedback labels.
  - Data volume is trivial: ≤1,440 rows/day, about 43k rows/month. Exact sorting-based percentiles over 30 days are cheap on an Intel iMac. P² is only needed for per-frame streaming within a minute.
- **Replay harness.**
  - Compile the same Swift detection code into a command-line or test target, feed it logged minutes deterministically, and grid-search threshold × hold × cooldown.
  - Report: alerts per day (median and P90 across days); precision on labeled alerts (Wilson CI); event-based recall and latency on user-confirmed events (Ward-style); and a NAB-like low-FP score.
  - Validate forward in time: tune on weeks 1–2, test on week 3. Repeat after any detected setup change.
- **Label-free false-alarm proxy.** Replaying over all minutes gives an *upper bound* on false alarms, since some alerts are true. Replaying over "known-good" windows gives the in-control exceedance rate directly; examples are the first 10 minutes after an explicit calibration and minutes the user marked "I was fine".
- **Simple confidence statement.** If 0 false alarms are seen over N monitored days, the 95% upper bound on the daily rate is about 3/N (from the Poisson equation e^(−λN) = 0.05). Two weeks without a false alarm therefore supports a rate below about 0.21/day.

### Gaps
- No posture-specific evidence was found on hold time vs false-alarm or detection trade-offs. ICU delay numbers may not transfer, and their exact attribution was inconsistent across secondary sources.
- Stochastic-approximation quantile trackers (e.g., "frugal streaming") and Kim et al.'s critique of point-adjusted time-series anomaly-detection evaluation were not verified this session.
- No published offline-replay methodology specific to webcam posture coaching was found. The harness above combines general practice (SPC ARL, event-based HAR metrics, NAB).
