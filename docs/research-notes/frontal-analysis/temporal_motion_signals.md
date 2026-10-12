# Temporal and motion signals from a frontal desk webcam: movement, fidgeting, sway, breathing, blinking and their link to sitting discomfort and static load

Research notes, compiled 2026-10-12.

**Method caveat for the report writer:** WebFetch failed with a DNS error on every domain tried (sciencedirect, plos, pmc, arxiv, jmptonline) during this session. Every number below therefore comes from abstracts, highlights or extracts that the extended search tool returned, not from full texts I read myself. Where a figure is attributed to a paper only through a *secondary* citation, I say so. Treat exact values as "per abstract or secondary report" and check them against the DOI before quoting them as definitive. Studies from before 2015 are flagged **[older]**.

Scope reminder: this file does not repeat that prolonged static sitting is harmful or that "the best posture is the next posture" (both have mixed evidence and were covered earlier). It also does not repeat the app's existing "same posture for N minutes" logic, which uses per-minute medians and MAD of face position and size. It covers finer temporal signals and how well each one has been validated.

---

## 1a. Webcam detection of in-chair movement, fidgeting and posture transitions: agreement with pressure mats and IMUs

### Takeaway
Camera-based movement quantification of a seated desk worker has been validated against a pressure-sensing chair at roughly r ≈ 0.6–0.72 and against Kinect head tracking at r ≈ 0.86. The best-known example uses frame-differencing "motion silhouettes" (Westlund et al., 2015). That makes a camera "amount of movement" signal a moderately validated measure of *gross* in-chair movement. I found no study that validates a face-landmark-based *posture-transition count* from a frontal webcam against a pressure mat or IMU. Such a count is therefore an unvalidated proxy for the pressure-mat "postural shift" counts used in the ergonomics literature.

### Cited Findings
- **Motion Tracker (Westlund, D'Mello & Olney, PLOS ONE 2015).** The system estimates how much a person moves from video using motion silhouettes, which are frame-to-frame pixel changes, i.e. frame differencing. Results by study:
  - **Study 1:** compared against a pressure-sensor chair during a 32-minute computerized task. Between-subject correlations were r = .720 (seat) and r = .695 (back). Within-subject cross-correlations were r = .606 (seat) and r = .507 (back).
  - **Study 2:** compared against a wrist accelerometer during three brief actions such as waving. Correlations were r = .801, .679 and .681.
  - **Study 3:** compared against Kinect head tracking while the person sat at a desk. The within-subject cross-correlation was r = .855.

  Sources: [PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0130293); [PMC4472690](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4472690/); [ResearchGate](https://www.researchgate.net/publication/278790635_Motion_Tracker_Camera-Based_Monitoring_of_Bodily_Movements_Using_Motion_Silhouettes)
- A correction to the Motion Tracker paper was published (PLOS ONE 10(9): e0138636). Its content was not retrieved, so check it before citing the figures above — [PLOS ONE correction](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0138636); [PubMed 26287977](https://pubmed.ncbi.nlm.nih.gov/26287977)
- Motion Tracker's accuracy depends on keeping the body in frame and on placing the camera the same way for every participant. The frame rate used was not stated in the extracts retrieved — [PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0130293); [author project page](https://jakory.com/resources/2012/motion-tracker/)
- **Pressure-mat in-chair movement (ICM) as the reference method (Fenety, Putnam & Walker, Applied Ergonomics 2000) [older].** The authors adapted an interface pressure mat to track centre of pressure (COP) at the buttock–chair interface as a continuous, indirect measure of sitting discomfort.
  - Lab validity: COP from the mat against a force platform gave r² > 0.80. COP movement against gross trunk movement gave r² > 0.86.
  - Field phase: ICC was used to choose a reliable sampling protocol. The ICC values themselves were not retrieved.

  Source: [ScienceDirect abstract](https://www.sciencedirect.com/science/article/abs/pii/S000368700000003X)
- **Actigraphy as a movement reference (Telfer, Spence & Solomonidis, Human Factors 2009;51(5):694–704) [older].** An activity monitor detected sitting movements with Pearson r > 0.9. Discomfort ratings differed significantly between chairs and rose over time. Secondary citations report n = 12 and say postural movement explained 29.7% of the variance in discomfort. These two figures are from secondary sources and not verified — [ResearchGate](https://www.researchgate.net/publication/41668117_The_Potential_for_Actigraphy_to_Be_Used_as_an_Indicator_of_Sitting_Discomfort)
- **Kinect-based seated tracking** of office workers found frequent postural shifts within each person over 15 minutes of computer use — [ResearchGate: Seated Tracking for Correcting Computer Work Postures](https://www.researchgate.net/publication/261227741_Seated_Tracking_for_Correcting_Computer_Work_Postures)
- **Definition of a "fidget" in seat-pressure engineering.** A patent defines a fidget as a pressure-change vector across seat regions that exceeds a threshold, *followed by a return to the original position*. This is a method claim, not validation data — [USPTO 10569668](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10569668)
- **Vision and pressure each miss part of the signal.** A 2026 multimodal "smart-skin" sitting paper argues that pressure-only and vision-only systems both struggle to capture dynamic fidgeting, and proposes multimodal sensing with cross-session validation — [MDPI MTI 10(4):39](https://www.mdpi.com/2414-4088/10/4/39)
- **Generalization limits in a different population.** A 2025 machine-learning study of *infant* fidgety-movement recognition found that body-tracking precision and cross-subject generalization limited performance. It warned that standard classification metrics can hide shortcut learning, and recommended adding pressure mats. This is a different population, so it is only indirectly relevant — [PMC12775505](https://pmc.ncbi.nlm.nih.gov/articles/PMC12775505)

### Inferences
- **What counts as a validated measure.** A camera "gross movement amount" has been validated at a moderate level against a pressure chair (r ≈ .6–.7) and against head tracking (r ≈ .86). Examples of such a measure are mean absolute frame difference in a downscaled body/face region, or a motion-silhouette area. However, this validation comes from one lab group, one task (32 minutes), and correlation statistics, not event-level agreement. No published agreement statistics (sensitivity, PPV, Cohen's κ for shift events) exist between a frontal webcam and a seat pressure mat for counting discrete postural shifts.
- **Mapping shift counts across sensors.** Literature shift counts come from seat pressure (COP displacement above a threshold, e.g. "10% threshold" in Waongenngarm 2020; see 2). A frontal camera sees the head and upper trunk, not the pelvis. So a camera shift count and a pressure-mat shift count are *related but different constructs*:
  - Pelvic weight shifts with little head motion would be missed by the camera.
  - Head-only movements, such as looking at a phone, would be counted by the camera but not by the mat.

  The app should label camera counts as "upper-body/head position changes", not "postural shifts" in the pressure-mat sense.
- **Separating fidgets from settled changes.** The patent-style definition (excursion then return) suggests a practical camera taxonomy:
  - *transient excursion*: a displacement that returns to baseline within a few seconds;
  - *settled position change*: a new median position that persists, e.g. ≥ 30–60 s.

  The second is close to Vergara & Page's "macro-movement" (see 2). It is also the signal most robust to a 1 fps sampling rate (see 1b). This taxonomy is my design suggestion, not a validated scheme.

### Gaps
- Frame rate, image resolution and exact motion-silhouette parameters for Motion Tracker were not retrieved. The content of its published correction is unknown.
- I found no study validating *face-landmark or pose-keypoint velocity or jerk* from a desk webcam against an IMU or pressure mat for seated office work. I also found none validating optical-flow-based "in-chair movement" against a pressure mat.
- Exact ICC values and sampling windows in Fenety et al. (2000) were not retrieved.

---

## 1b. What is lost when analyzing at ~1 frame per second instead of 5–30 fps

### Takeaway
No study I found directly measures how frame rate affects seated movement or fidget metrics. Sampling theory and known signal timescales give a clear split:
- **Survive at 1 fps:** settled posture or position changes, slow drift, and "time without large movement".
- **Lost or aliased at 1 fps:** brief fidgets that return to baseline within about 1 s, peak velocity, jerk and other higher derivatives, blink counts, and (marginally) respiration.

Of these, the respiration limit sits closest to the 1 fps line: 1 fps puts the Nyquist limit at 30 breaths/min, so breathing is barely sampled. A hybrid scheme would recover most of the finer signals at low CPU cost: 1 fps baseline plus short higher-rate bursts, or a burst triggered when frame difference spikes. This is an inference, not a validated design.

### Cited Findings
- **Effect of a longer frame interval on optical flow.** Lowering the frame rate lengthens the time between frames, so motion between frames looks larger. In one action-recognition benchmark, reducing from 30 to 6 fps cut TV-L1 optical-flow processing only from 21 minutes to 6 minutes 42 seconds. The authors attribute the non-proportional saving to the larger per-frame motion — [arXiv 2409.05662](https://arxiv.org/pdf/2409.05662)
- **Frame dropping versus frame averaging.** Dropping frames causes judder and strobing (temporal aliasing). Averaging frames causes motion blur but reduces temporal aliasing — [arXiv 2010.13715](https://arxiv.org/pdf/2010.13715); [arXiv 2603.18305](https://arxiv.org/pdf/2603.18305)
- **Motion-smoothness metrics degrade as frame rate falls**, i.e. measured motion characteristics drift away from the full-rate reference — [Wang et al., ICIP 2018](https://eceweb.uwaterloo.ca/~z70wang/publications/icip18.pdf)
- **Low-rate sampling works for posture snapshots, not motion [older].** An early video system for keyboard-operator posture took a frame about every 30 s and measured postural angles to within 1–2°. Symptomatic operators trended toward more head tilt and neck flexion. This shows sparse sampling is adequate for posture *angles*, not for movement dynamics — [Applied Ergonomics 1991](https://www.sciencedirect.com/science/article/abs/pii/000368709190002Y)
- **Breathing rates in the relevant range.** A healthy-adult spirometry study found breathing frequency unchanged between upright and slumped sitting (see 4). Typical resting adult rates fall in roughly the 12–20 breaths/min band (0.2–0.33 Hz), consistent with the COHFACE errors reported in 4 — [Landers et al. 2003](https://bearworks.missouristate.edu/articles-chhs/375/)
- **Blink timescale.** An EAR blink-detection source notes that eyes close for about 300 ms, about 12 times per minute. The parameter-tuning literature stresses that the threshold *and frame rate* drive blink-detection performance — [ResearchGate: real-time eye blink detection using general cameras](https://www.researchgate.net/publication/374379383_Real-time_eye_blink_detection_using_general_cameras_a_facial_landmarks_approach); [Springer 2024 MediaPipe EAR chapter](https://link.springer.com/chapter/10.1007/978-3-031-77584-0_67)

### Inferences
These follow from first principles and the timescales above; none has been validated for this app. The table summarizes each signal; notes on the less obvious rows follow it.

| Signal | At 1 fps | At 5–15 fps | At 25–30 fps |
|---|---|---|---|
| Settled position change (new posture held ≥ 30 s) | Captured. Onset time is accurate to about 1 s. | Captured | Captured |
| Transient fidget (excursion and return in under ~1–2 s) | Mostly **missed** or reduced to a single-sample spike that looks like noise. | Captured | Captured |
| Movement amount (frame difference or flow magnitude) | Measures net displacement over 1 s, **not** path length. Back-and-forth motion cancels out. Biased low for oscillatory fidgeting. | Reasonable | Best |
| Keypoint velocity | Only average velocity over 1 s; peak velocity is unrecoverable. | Usable after smoothing | Usable |
| Keypoint jerk (3rd derivative) | **Meaningless**: noise dominates and samples are too sparse. | Marginal and very noise-sensitive with webcam landmarks. | Possible only with heavy filtering. No desk-webcam validation found. |
| Respiration rate | 30 bpm Nyquist limit; only 3–5 samples per breath. Fragile under jitter and irregular frame timing. Not recommended. | Workable (≥ 5 samples per breath) | Standard for rPPG and respiration datasets |
| Blink count or rate | **Not measurable.** A ~300 ms blink is seen in only a fraction of frames, and blinks merge with looking down at the keyboard. | Partly (many blinks span only 1–2 frames) | Standard |
| Eye-closed fraction (PERCLOS-like) | Statistically estimable: about 5–8% of frames if ~15 blinks/min × ~0.3 s. But heavily confounded by downward gaze with a camera above the screen. Unvalidated. | Better | Best |
| Head sway (slow drift < 0.1 Hz) | Captured | Captured | Captured |
| Head micro-sway (0.1–1 Hz) | Aliased | Captured | Captured |

- **CPU-saving options**, roughly ordered by cost:
  1. Grayscale frame difference on a downscaled ROI (e.g. 64×48 px) at 5–10 fps. This is cheap and needs no neural network.
  2. 1 fps landmark or pose inference plus 5–10 fps frame differencing.
  3. Periodic bursts, e.g. 10 s at 10–15 fps every 2–5 minutes, for breathing and sway sampling.
  4. Event-triggered bursts when the 1 fps frame difference crosses a threshold, to capture the shape of a transition.

  All of these work on derived numbers only, so no frames need storing.

### Gaps
- No study of seated movement, fidget or ICM measurement at different frame rates was found.
- Motion Tracker's own frame rate was not retrieved.
- No published data on how often office fidgets last under 1 s versus longer; this distribution determines how much a 1 fps pipeline misses. Pressure-mat studies typically sample at a few Hz, but the specific rates were not retrieved.

---

## 2. Does in-chair movement or fidgeting increase with seated discomfort or time-on-task, and can a camera capture the same signal?

### Takeaway
Pressure-mat, actigraphy and video-coding studies mostly agree that the frequency of in-chair movement, especially *large* repositioning movements, rises over prolonged sitting along with discomfort. Key studies:
- Waongenngarm 2020: n = 40, 4 h of typing.
- Sammonds 2017: n = 10, 140 min of driving.
- Telfer 2009: n = 12.
- Kruithof 2025/26 review: 6 of 8 papers reporting overall time effects found increases.

The association is moderate and context-dependent (seat, task, individual). Some studies report a "stiffening" decrease instead. Causality is debated: movement as a *response to* discomfort versus movement as a *relief strategy*. A camera can capture the upper-body part of these movements (Westlund r ≈ .6–.7 versus a pressure chair). No study shows that a webcam-derived movement rate tracks discomfort as well as seat-pressure measures do.

### Cited Findings
- **Waongenngarm, van der Beek, Akkarakittichoke & Janwantanakul (Applied Ergonomics 2020;89:103225).**
  - Design: 40 healthy participants typed a standard text at a computer workstation continuously for 4 h. Discomfort was rated on Borg CR-10 for 10 body regions; a seat pressure mat detected shifts.
  - Discomfort rose continuously in all regions. The highest were low back, buttocks, upper back, thigh and neck.
  - Small- and large-magnitude shifts both increased during the first 2 h. After 2 h, only large shifts kept increasing.
  - Shifts per hour at the 10% threshold, for hours 1–4: 14.8 ± 9.5, 17.8 ± 9.4, 18.2 ± 11.1 and 18.1 ± 9.8.
  - The authors read postural shifting as a natural coping response to relieve discomfort and pressure.

  Sources: [ResearchGate](https://www.researchgate.net/publication/343389099_Perceived_musculoskeletal_discomfort_and_its_association_with_postural_shifts_during_4-h_prolonged_sitting_in_office_workers); [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0003687020301770)
- **Akkarakittichoke, Waongenngarm & Janwantanakul (JMPT 2023).** 60 office workers sat for 1 h with postural shifting at frequencies of 10, 20 and 30 per hour, measured with a seat pressure mat. Shifting frequency had significant effects on perceived discomfort in the neck, shoulder, upper back and lower back. The direction and size per frequency were not retrieved — [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0161475423000532); [JMPT](https://www.jmptonline.org/article/S0161-4754(23)00053-2/fulltext)
- **Sammonds, Fray & Mansfield (Applied Ergonomics 2017; DOI 10.1016/j.apergo.2016.05.009).**
  - Design: 10 participants (4 female), 140 min of driving, seat fidgets and movements (SFMs).
  - Per later papers, the discomfort "threshold" that precedes a movement was reached sooner over time, so movements became more frequent. A similar association is reported between perceived discomfort and number of postural shifts over 2 h.
  - Healthy participants are cited as making 8–19 postural shifts per hour; this range is drawn from several sources including Sammonds.

  Exact per-hour counts were not retrieved. Sources: [Frontiers 2021 (cites Sammonds)](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2021.760533/full); [Kruithof et al. review, PMC12769933](https://pmc.ncbi.nlm.nih.gov/articles/PMC12769933/)
- **Vergara & Page (2002) [older], as summarized by later papers.** Seated movement divides into macro-movements (large postural changes) and micro-movements (small oscillations around a stable posture).
  - Macro-movements are attributed to perceived discomfort; large lumbar shifts indicate low-back discomfort, and these shifts were larger and faster when pain was present.
  - Small movements around a steady posture may help prevent pain.
  - Contrasting view: Fujimaki & Noro (2005) [older] argued that macro-movements recur in a repeating pattern during prolonged sitting as a *means to reduce* discomfort.

  Only the secondary summary was retrieved, not the original — [PLOS ONE 2021 car-seat study](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0259934); [Kruithof et al. review](https://pmc.ncbi.nlm.nih.gov/articles/PMC12769933/)
- **Kruithof, Song & Vink, "In-chair movements: categorizations and patterns over time" (Work, published Nov 2025 / 2026 issue; DOI 10.1177/10519815251394878).**
  - Method: PRISMA review; 18 of 230 papers included.
  - ICM terminology is inconsistent and there is *no standardized classification*.
  - 6 of 8 papers reporting overall time effects found ICM frequency increased over time. A minority found decreased movement or a "stiffening effect". Amplitude findings were inconsistent; a shift toward more slumped posture was common, especially in driving.
  - ICM patterns depend on seat characteristics, task demands and individual factors, not only time.
  - Fenety et al.'s ICM parameters correlated with overall and local discomfort, but the mechanisms remain unclear.

  Sources: [PMC12769933](https://pmc.ncbi.nlm.nih.gov/articles/PMC12769933/); [PubMed 41259324](https://pubmed.ncbi.nlm.nih.gov/41259324/); [DOI](https://doi.org/10.1177/10519815251394878)
- **Telfer et al. (2009) [older].** Discomfort ratings rose over time in every chair tested, and a wrist or body actigraph tracked sitting movements (r > 0.9). A secondary source reports movement explained 29.7% of the variance in discomfort — [ResearchGate](https://www.researchgate.net/publication/41668117_The_Potential_for_Actigraphy_to_Be_Used_as_an_Indicator_of_Sitting_Discomfort)
- **Pressure-to-discomfort validity is uncertain.** A review of pressure measurement for office-chair comfort found its validity uncertain, with some correlations up to r = 0.7 — [ResearchGate review](https://www.researchgate.net/publication/271388550_Are_pressure_measurements_effective_in_the_assessment_of_office_chair_comfortdiscomfort_A_review)
- **Movement promotion as a preventive approach.** A 6-month cluster-randomized trial (Channak et al., 2024) in high-risk office workers found that a dynamic seat cushion that promotes postural shifts reduced the incidence of neck and low-back pain. This concerns *promoting* movement, not measuring it — [PMC11479679](https://pmc.ncbi.nlm.nih.gov/articles/PMC11479679/)
- **Driving context.** A field study found drivers' sitting behaviour (from pressure mats) depended on seat characteristics, road dynamics and driving time — [PLOS ONE 2021](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0259934)
- **Teaching-level statement [non-peer-reviewed].** A Cornell ergonomics teaching note treats fidgeting rate as an index of chair discomfort: higher fidget rates correspond to higher discomfort — [Cornell DEA 3250 notes](https://ergo.human.cornell.edu/DEA3250Flipbook/DEA3250notes/sitting.html)

### Inferences
- **Group-level only.** Shift rate rising with time and discomfort is a *group-average, within-session* trend with large between-person spread. The SDs in Waongenngarm are about 50–65% of the means. A single user's shift count per hour is therefore not interpretable against population norms. At most, it is interpretable against that user's own baseline over many sessions.
- **Describing without diagnosing.** "Large repositioning movements per hour, compared with your own typical rate at this time of the session" stays descriptive and does not diagnose. The literature does not support converting a movement rate into a discomfort estimate for an individual. Explained variance is about 30% in the best-cited case (Telfer, secondary).
- **Ambiguous direction of a change.** Both "more movement = more discomfort" and "less movement = stiffening or static load" appear in the literature. A change in movement rate is therefore ambiguous by itself, which reinforces describing it rather than interpreting it.
- **Camera versus pressure mat.** The camera captures the upper-body component of macro-movements. Because the Waongenngarm finding (after 2 h only *large* shifts increase) concerns larger shifts, a frontal camera is plausibly best suited to the part of the signal that changes late in a session. This is unverified.

### Gaps
- Exact discomfort–movement correlation coefficients in Fenety 2000, Sammonds 2017 and Waongenngarm 2020 were not retrieved; only abstracts were available.
- No study validates *webcam*-derived shift rate against discomfort ratings in office work.
- Relevant work found by title only, without details: "Postural strategies among office workers during a prolonged sitting bout" (Applied Ergonomics 2022, [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0003687022000461)); Zhang et al. 2026, "Relationship between physical fatigue variations and seat pressure distribution during prolonged office sitting" ([Wiley HFM](https://onlinelibrary.wiley.com/doi/10.1002/hfm.70038)); seat pressure in office workers with and without chronic LBP over 1 h ([PubMed 28593079](https://pubmed.ncbi.nlm.nih.gov/28593079/)); Benden et al. 2011, in-situ office chair habits ([Human Factors](https://journals.sagepub.com/doi/abs/10.1177/0018720810396506)).

---

## 3. Seated postural sway and head micro-motion: can a webcam measure it, and does it relate to fatigue or pain?

### Takeaway
Head motion from a camera agrees well with depth-camera head tracking: within-subject r ≈ .86 in Westlund et al. Video-based head and trunk *posture* in sitting has been validated against 3D mocap, with intra-assessor reliability of about 2–12°. Evidence linking *seated* trunk or head sway to pain is small and contradictory: n ≈ 10 per group, with pain linked to more fine-scale variability in one study and to reduced variability and entropy in another, and weak overall. I found **no study** linking webcam-measured head micro-motion to fatigue during computer work. Any "sway" metric from the app should be treated as an unvalidated descriptive proxy.

### Cited Findings
- **Head tracking:** Motion Tracker (video frame differencing) correlated with Kinect head tracking while seated at a desk at within-subject r = .855 — [PMC4472690](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4472690/)
- **Video posture versus mocap in sitting:** a validation of a sagittal video method for seated head and trunk alignment against 3D motion capture, in static and dynamic trials, found high expert agreement. Intra-assessor reliability ranged from about 2° to 12° — [Gait & Posture, ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0966636216306154)
- **Sway during computer tasks (sit-stand workstation study):** head and trunk accelerations were 20–26% lower during mouse tasks than keyboard tasks. Sway did not differ significantly between sitting and standing. The study aimed to test fatigue effects on head repositioning, but those results were not retrieved — [ResearchGate](https://www.researchgate.net/publication/372626653_Effect_of_sit-stand_workstation_position_and_computer_task_on_head_and_trunk_postural_sway_and_discomfort)
- **Sensors 2024 (doi 10.3390/s24144750), office workers with non-specific chronic spinal pain (n = 10) versus pain-free:**
  - Pain-free workers showed more complex, less predictable trunk movements, with differences most visible in fine movements.
  - Sample entropy did **not** differ between groups (p > 0.05).
  - A multifractal "negative width" measure of fine-scale variability was *higher* in the pain group.
  - The paper also states that prolonged sitting increases variability in COP displacement and lumbar curvature while decreasing complexity.

  Sources: [PMC11281106](https://pmc.ncbi.nlm.nih.gov/articles/PMC11281106/); [MDPI](https://www.mdpi.com/1424-8220/24/14/4750)
- **Sensors 2025 pilot (doi 10.3390/s25051583), 10 office workers with chronic spinal pain in the field:** higher pain intensity correlated with lower variability at micro and larger sway scales, and with reduced sample entropy. The authors themselves describe the link as weak overall — [PMC11902825](https://pmc.ncbi.nlm.nih.gov/articles/PMC11902825/)
- **Image cues and posture differences [older].** An early video system reported postural angles to 1–2°, with symptomatic keyboard operators trending toward more head tilt and neck flexion. A recent study of female office workers measured neck and shoulder angles every 20 min over 3 h. It found significant differences between symptomatic and asymptomatic groups in craniovertebral (p = 0.01) and forward-shoulder (p = 0.00) angles during static sitting — [Applied Ergonomics 1991](https://www.sciencedirect.com/science/article/abs/pii/000368709190002Y); [PMC11004746](https://pmc.ncbi.nlm.nih.gov/articles/PMC11004746)

### Inferences
- **Sensor gap.** The sway and entropy literature uses trunk IMUs or seat COP at tens to hundreds of Hz. A 1 fps face-position series cannot reproduce sample entropy or multifractal measures; these need long, densely sampled series. At most it gives a slow "head drift range" per minute, which the app already approximates with its MAD.
- **Contradictory direction.** The direction of pain-related variability changes contradicts itself across the two small studies. Even with a validated sway measure, the app could not say whether more or less sway is "better". This supports purely descriptive reporting.
- **Feasible upgrade.** A short 10–15 fps burst gives head-position jitter at 0.1–1 Hz, which reflects breathing, ballistocardiographic and postural micro-corrections. This would make a "head micro-motion amplitude" feasible. Its relation to fatigue is unestablished.

### Gaps
- No study of webcam head micro-motion versus fatigue or time-on-task in seated computer work was found.
- Fatigue results of the sit-stand sway study were not retrieved.
- No reliability (test-retest) data for webcam-derived head sway at a desk were found.

---

## 4. Remote breathing estimation from a desk webcam: accuracy, sensitivity to posture and lighting, and relevance to slumped posture

### Takeaway
Respiration rate from RGB video is feasible under controlled, mostly still conditions:
- Benchmark MAE on COHFACE is about 0.8–2 breaths/min, but the Pearson correlation can be as low as 0.45.
- One 2026 multi-region optical-flow method (forehead, cheeks, chest, shoulders) reports an MAE of 0.61–0.95 bpm.

Performance degrades with motion, shallow breathing and texture-less clothing:
- Face-region signals are distorted by facial movement; the chest region is more robust.
- In a 5-person pilot, a webcam's MAE during shallow breathing was 44.4 bpm.

I found no validation in a realistic seated desk-work setting against a respiratory belt. On posture, the one healthy-adult study (n = 30) found that slumped sitting reduced tidal volume and minute ventilation but **not** breathing rate. So a camera respiration *rate* is not a posture indicator. Respiration *amplitude* from video is uncalibrated and confounded by distance and posture changes.

### Cited Findings
- **2026 hybrid CNN-spectral, multi-region optical flow (forehead, cheeks, chest, shoulders):** MAE 0.61–0.95 bpm across skin tones and age groups. A desk or seated-work validation against a belt was not described in the extract — [PMC12923011](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12923011/)
- **Optical-flow breathing (arXiv 2311.08426):** the face-derived signal was distorted during large facial movement, while chest signals stayed accurate. Optical flow failed to track a participant in a solid-colour (green) jumper, so the window size had to be enlarged — [arXiv 2311.08426](https://arxiv.org/pdf/2311.08426)
- **COHFACE benchmark (video-based real-time HR/RR):**
  - Real-time HR/RR monitoring paper (Expert Systems with Applications 2023): RR MAE 1.62 breaths/min, Pearson r = 0.45 — [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0957417423006371)
  - Multitask attention network (Ren et al. 2022): MAE 2.05 on COHFACE — reported in [Frontiers Physiol 2026 (DeepRespNet) comparison table](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2026.1792689/pdf)
  - Clifford-layer method (Ghezzi et al. 2024): MAE 0.83 across SCAMPS, COHFACE and BP4D+ combined — reported in [Frontiers Physiol 2026 (DeepRespNet) comparison table](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2026.1792689/pdf)
  - DeepRespNet itself: MAE 0.45–0.80 on a *custom* dataset — [PMC13229748](https://pmc.ncbi.nlm.nih.gov/articles/PMC13229748/)
  - A quality-aware framework shows a wide method-dependent spread, with a COHFACE ground-truth-oracle MAE of 1.92. Some papers exclude high-motion videos, so the figures are not like-for-like — [arXiv 2512.14093](https://www.arxiv.org/pdf/2512.14093)
- **5-participant pilot (Kim et al. 2025):** compared an RGB webcam, an RGB camera, a respiratory belt, ECG and a long-wave infrared (LWIR) camera during regular, shallow and deep breathing.
  - Webcam MAE in *shallow* breathing: 44.4 bpm.
  - The belt also failed in shallow breathing: MAE 26.0 bpm.
  - LWIR MAE: 0.6, 2.4 and 0 bpm (regular, shallow, deep).

  Small n, so these are not general benchmarks — [PubMed 41381069](https://pubmed.ncbi.nlm.nih.gov/41381069/); [SAGE](https://journals.sagepub.com/doi/10.1177/03000605251404229)
- **Vendor claim (not peer-reviewed):** iMotions reports an ICC of 0.815 for webcam respiration rate against respiration belts in controlled conditions — [iMotions](https://imotions.com/products/imotions-lab/modules/webcam-respiration/)
- **Respiratory belts are imperfect references.** Breathing style and body position distort belt airflow estimates unless calibration is improved — [PMC3852323](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3852323/)
- **Posture and breathing, healthy adults (Landers et al. 2003) [older]:** n = 30, 5 minutes of spirometry per posture. Upright sitting gave significantly higher tidal volume and minute ventilation than slumped sitting. Breathing frequency did **not** differ — [Missouri State BearWorks](https://bearworks.missouristate.edu/articles-chhs/375/); [PDF](http://apsarts.fr/wp-content/uploads/2020/04/LANDERS-MERRILL_A-comparison-of-tidal-volume-breathing-frequency-and-minute_2003.pdf)
- **Posture and breathing, COPD (n = 12 men):** sitting position had no significant effect on tidal volume or respiratory rate. Forward-leaning and arm-supported positions increased accessory inspiratory muscle activity — [PMC3436653](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3436653/)
- **Posture and lung function, students (secondary source; verify) [older]:** about 20 male students aged ~13.5. Slumped sitting lowered FVC, FEV1 and PEF; there was no difference between normal and kyphotic sitting — [academia.edu](https://www.academia.edu/806624/Effect_of_different_sitting_posture_on_pulmonary_function_in_students)

### Inferences
- **Field of view.** A built-in camera above the screen typically frames the face, neck and top of the shoulders. A chest ROI may be partly or entirely out of frame. The shoulder and upper-chest ROI plus face-motion approach is then the realistic option. The literature says the face ROI is the most motion-sensitive, which is a problem during typing and reading head movements.
- **Frame rate.** Respiration at 1 fps is below what any benchmark uses. Benchmark datasets are typically 20–30 fps; this is background knowledge, not verified this round. A periodic burst (e.g. 30 s at 10 fps during detected stillness) is the minimum plausible design. Estimates should be reported only when a motion-quality gate passes.
- **Posture relevance.** Landers 2003 found rate unchanged between slumped and upright sitting. So the camera-measurable quantity, rate, does not encode the posture effect, and the quantity that changes, tidal volume, is not measurable in calibrated form from a monocular RGB camera. Breathing is therefore a weak and **unvalidated** route to posture information. At best it could be a descriptive "breathing rate during still periods" number, with no posture interpretation.
- **Lighting and clothing.** Dim office lighting and plain dark clothing reduce optical-flow texture; arXiv 2311.08426 saw this with a solid jumper. Expect failures and design for "no estimate" rather than a noisy estimate.

### Gaps
- No desk-webcam (above-screen, about 50–70 cm, typing and reading task) validation of respiration rate against a belt or capnography was found.
- UBFC-Phys or MAHNOB-HCI respiration numbers were not retrieved.
- No study of the effect of slumped versus upright sitting on *video-derived* respiration was found.
- rPPG-Toolbox respiration support and its default frame-rate requirements were not checked this round.

---

## 5. Blink rate and eye signals from a webcam as fatigue or computer-vision-syndrome indicators (brief)

### Takeaway
Blink rate falls during screen work: Tsubota & Nakamori 1993, n = 104, ~22/min relaxed to ~7/min at a VDT [older]. A 2015 comparison suggests the drop reflects cognitive and reading demand rather than the screen itself (14.9 vs 13.6/min, screen vs paper, p = 0.58). Webcam EAR (eye aspect ratio) detection works on datasets: 79–98% accuracy, but precision as low as 83%, and per-user threshold tuning is needed. It requires a video rate of at least ~10 fps, which is incompatible with 1 fps sampling. No study validates webcam blink rate against a fatigue or visual-strain outcome in computer work. This signal is out of scope for posture and should be considered only as a descriptive, burst-mode extra.

### Cited Findings
- **Blink rate drop at a VDT [older].** Tsubota & Nakamori (1993), 104 office workers: about 22 blinks/min when relaxed versus about 7/min using a VDT. This is reported via a 2023 exploratory study of real-time blink detection as a computer-vision-syndrome (CVS) indicator — [MDPI IJERPH 20(5):4569](https://www.mdpi.com/1660-4601/20/5/4569)
- **Screen versus paper.** A study comparing desktop screen reading and printed text found mean blink rates of 14.9 versus 13.6 per minute (p = 0.58). The authors concluded that dry eye or eye strain cannot be explained simply by reduced blinking at the computer — [ScienceDirect: Cognitive demand, digital screens and blink rate](https://www.sciencedirect.com/science/article/pii/S0747563215003829). Exact attribution of these numbers within the result set is uncertain; verify.
- **Blink rate decreases while reading** from print or digital devices, regardless of task duration, difficulty or viewing distance — [IOVS](https://iovs.arvojournals.org/article.aspx?articleid=2785357)
- **Incomplete blinks and CVS** are discussed in Portello et al. 2013 [older] — [Optom Vis Sci](https://onlinelibrary.wiley.com/doi/10.1097/OPX.0b013e31828f09a7)
- **EAR accuracy on datasets:**
  - MediaPipe + EAR + peak identification: 98.03% accuracy and 83.42% precision on Eyeblink8 — [Springer 2024](https://link.springer.com/chapter/10.1007/978-3-031-77584-0_67)
  - Another method: 91% on ZJU and 79% on Eyeblink8 — [ResearchGate](https://www.researchgate.net/publication/374379383_Real-time_eye_blink_detection_using_general_cameras_a_facial_landmarks_approach)
  - Adjusted EAR: best AUC on Talking Face at a modified threshold of 0.2468, which suggests per-user calibration — [PMC9044337](https://pmc.ncbi.nlm.nih.gov/articles/PMC9044337/)
- **Spontaneous blinking and task difficulty.** Blink time series from a built-in webcam have been used to assess task difficulty, i.e. a cognitive-load signal rather than a fatigue signal — [arXiv 2102.06690](https://arxiv.org/pdf/2102.06690)
- **Standalone blink monitor.** A standalone eye-blink monitoring system for computer users has been described, with details not retrieved — [PMC11744486](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11744486/)

### Inferences
- **Camera geometry confound.** With the camera above the screen, looking down at the keyboard or phone lowers EAR and mimics eye closure. Blink counting therefore needs head-pitch and gaze gating.
- **Interpretation.** Blink-rate changes mostly reflect cognitive and reading demand. Linking them to sitting posture or static load has no support in the sources found.

### Gaps
- No webcam blink-rate validation against manual counts during prolonged real computer work was retrieved.
- No study validates webcam blink rate against an independent fatigue measure in office work.

---

## 6. Static-load metrics: "time without movement", posture-variability indices (EVA etc.), thresholds and summaries used in ergonomics

### Takeaway
The ergonomics literature summarizes static load mainly as:
- (a) distributions of uninterrupted-sequence durations at given exposure levels, via exposure variation analysis (EVA);
- (b) percentile ranges, e.g. the 10th–90th percentile range of trunk inclination;
- (c) bout-length categories, e.g. sitting bouts of 0–5, >5–20 and >20 minutes;
- (d) shift counts per hour from seat pressure, e.g. COP change above a 10% threshold.

The best accelerometer evidence (DPHACTO, n = 659, *blue-collar* workers) links *more time in brief sitting bouts* to lower neck-shoulder pain intensity (adjusted OR 0.68). I found no standard, validated threshold for "time without movement" in seated office work. Office posture-variation indices exist, but they are descriptive and not tied to outcome thresholds.

### Cited Findings
- **What EVA is.** EVA captures both exposure intensity and the duration of uninterrupted sequences at each intensity level. It has been applied from computer-based office work to heavy jobs, for EMG and for postures. Conventional summaries aggregate EVA cells above or below a threshold in exposure level and/or sequence duration. A cluster-based EVA variant (2013) discriminates exposure timelines better — [PMC3623884](https://pmc.ncbi.nlm.nih.gov/articles/PMC3623884/); [BMC Med Res Methodol](https://link.springer.com/article/10.1186/1471-2288-13-54)
- **Office posture variation [~2014].** 24 office workers had whole-day trunk posture measured, with variation quantified by an EVA-based index plus the 10th–90th percentile range. Paper-based tasks gave more non-neutral *and* more variable postures; electronic (ICT) tasks gave more neutral but less variable postures — [ResearchGate](https://www.researchgate.net/publication/264797110_Posture_variation_among_office_workers_when_using_different_information_and_communication_technologies_at_work_and_away_from_work)
- **DPHACTO (n = 659 blue-collar workers; thigh and trunk accelerometers).** Occupational sitting was split into brief (0–5 min), moderate (>5–20 min) and prolonged (>20 min) bouts. More time in brief bursts of occupational sitting was associated with lower neck-shoulder pain intensity: adjusted OR 0.68, 95% CI 0.48–? (upper bound truncated in the extract) — [PMC4871928](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4871928/)
- **Seat-pressure shift threshold.** Waongenngarm 2020 counted shifts at a "10% threshold", giving about 15–18 shifts/h. Healthy participants are cited as making 8–19 shifts/h — [ResearchGate](https://www.researchgate.net/publication/343389099_Perceived_musculoskeletal_discomfort_and_its_association_with_postural_shifts_during_4-h_prolonged_sitting_in_office_workers); [Frontiers 2021](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2021.760533/full)
- **Variability and complexity of sitting.** Prolonged sitting raises variability of COP and lumbar curvature while reducing complexity. Complexity measures such as SampEn and multifractal width did not robustly separate pain groups in office workers (n = 10 per group) — [PMC11281106](https://pmc.ncbi.nlm.nih.gov/articles/PMC11281106/)
- **Static sitting angles by symptom status.** Neck and shoulder angles sampled every 20 min over 3 h differed between symptomatic and asymptomatic female office workers — [PMC11004746](https://pmc.ncbi.nlm.nih.gov/articles/PMC11004746)
- **Background on static posture.** Static posture and lack of variation are described as risk factors for work-related MSDs, which motivates variation metrics. The empirical support is mixed; see earlier research and do not restate it — [PMC3623884](https://pmc.ncbi.nlm.nih.gov/articles/PMC3623884/)

### Inferences
- **Mapping to the app.** The app's existing "same posture for N minutes" is effectively a one-level EVA duration class. A fuller EVA-style description from 1 fps face data would be a 2-D histogram:
  - *displacement level*: distance of head position from the session median, in classes;
  - *uninterrupted duration* within that class: e.g. 0–1 min, 1–5 min, 5–20 min, >20 min, borrowing DPHACTO's bout cut-points.

  This is computable at 1 fps because the relevant durations are minutes. It would be a *descriptive* summary with no validated risk thresholds.
- **"Time without movement".** This can be reported as the distribution of inter-event intervals between settled position changes; median and longest interval are natural summaries. No validated cut-off exists for when such an interval becomes "static load". The DPHACTO 5- and 20-minute bout boundaries are the closest population-level anchors, but they come from thigh-accelerometer sitting bouts in blue-collar workers, not from upper-body stillness in office workers.
- **Comparison with IMU studies.** IMU and pressure studies sample at ≥ 10–50 Hz. Variability indices computed from 1 fps camera data are therefore not comparable in magnitude with published IMU indices. Only within-user trends are meaningful.

### Gaps
- Specific EVA class boundaries for trunk or head inclination and sequence duration in office work were not retrieved this round. From background knowledge, unverified: conventional EVA duration classes such as 0–1, 1–3, 3–7, 7–15, 15–30, 30–60 and >60 s (Mathiassen & Winkel 1991 lineage). Check before use.
- No validated "minutes without movement" threshold for discomfort or MSD outcomes in seated office work was found.
- No study computing EVA or variability indices from *camera* data in office work was found.
