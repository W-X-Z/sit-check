# Body-worn sensors for precise, continuous measurement of seated spinal, pelvic, head and shoulder posture (IMUs, strain/flex and fiber sensors, smart garments, consumer wearables) — state as of October 2026

*Method note for the report writer:* The egress proxy blocked full-text access to PubMed/PMC, MDPI, BMC, ScienceDirect, arXiv, Movella, MbientLab and most vendor sites (CONNECT 403 / DNS failure). Most findings below therefore come from **web-search result excerpts** of the cited pages, not from reading the full papers. Numbers were kept only when the excerpt stated them explicitly. Where the excerpt did not clearly say which paper a number came from, that is flagged. Two primary sources were read directly: Apple's CoreMotion documentation (developer.apple.com JSON endpoint, 2026-10-11) and the MetaWear Swift SDK README (raw.githubusercontent.com, 2026-10-11). Tags used: **[lab]** = laboratory protocol; **[free-living]** = home/office/daily life; **[vendor claim]** = manufacturer or app marketing, not independently validated; **[discontinued]** / **[status unclear]** = product status.

---

## Q1. Which posture variables can body-worn sensors measure, from which placements, and how well?

### Takeaway
Gravity-referenced **sagittal and frontal inclinations** of the head, upper trunk, thoracolumbar junction and sacrum are measured well by skin-mounted IMUs. Lab errors are typically about 1–5° against motion capture, and pelvic tilt agrees with radiographs at group level (ICC ≈ 0.97). Derived angles such as kyphosis (T3−T12), lordosis/lumbar flexion (T12−S1) and pelvic tilt are equally well supported. **Rotation about the vertical axis** (trunk or pelvic axial rotation) is the weak variable, because it depends on gyro integration or indoor-disturbed magnetometers. **Shoulder protraction** and **forward head translation** have no validated wearable measure. All sensor angles are skin-surface segment inclinations, not radiographic Cobb or pelvic-incidence values. They are best used as within-person change from a calibrated reference.

### Cited Findings
**Variable → placement → best evidence found**

| Variable | Typical placement | Evidence (sample, condition, reference, error) |
|---|---|---|
| Pelvic sagittal tilt | Sacrum (S1–S2), sometimes with T12 | Systematic review of 12 studies: pelvic tilt was the most accurate pelvic axis, with RMSE ≈ 0.2°–4.9°. Better results came with sacrum placement and standardized calibration [lab; mostly gait/running] — [JoVE 2026 review](https://doi.org/10.3791/71343); [PubMed 42224203](https://pubmed.ncbi.nlm.nih.gov/42224203/). Sensors at S2 + T12 against sitting and standing radiographs in 61 pre-hip-arthroplasty patients: sitting PT −21.9 ± 12.5° (X-ray) vs −20.9 ± 11.7° (sensor), ICC 0.97; standing 1.5 ± 8.3° vs 1.0 ± 8.1°, ICC 0.98; group means differ by about 1° (per-patient error not in the excerpt); R² 0.95; BMI > 40 excluded [clinic, static] — [Sharma et al., Arthroplasty Today 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC8784288); [DOAJ record](https://doaj.org/article/7673400e62c04c6591f42df72b3d219d) |
| Lumbar flexion / lordosis | T12 (or L1) + S1/S2; relative angle = difference of inclinations | ViMove (dorsaVi) vs Vicon, n = 34 (18 with LBP), standing end-range: RMSE 1.82° flexion, 0.71° extension, 0.77°/0.98° lateral flexion; flexion 95% LoA ≈ −3.86° to +4.69° [lab] — [Mjøsund et al., BMC Musculoskelet Disord 2017](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5361703/). Three MIMUs at T3/T12/S1, n = 17, forward bending + sit-to-stand vs stereophotogrammetry: max RMSE 5.6° for kyphosis and lordosis [lab] — [Paloschi et al., Sensors 2021](https://www.mdpi.com/1424-8220/21/19/6610) |
| Thoracic kyphosis | T1–T3 + T12; kyphosis = T3 slope − T12 slope | Same Paloschi study (max RMSE 5.6°) — [Sensors 2021](https://pmc.ncbi.nlm.nih.gov/articles/PMC8513009). Fiber-optic ShapeTape along the spine vs Optotrak in sitting, n = 26: curvature R² = 0.98; mean kyphosis differences ≈ 3.6–4.3°, wide LoA [lab, seated] — [Mayo Clinic record](https://mayoclinic.elsevierpure.com/en/publications/agreement-between-fiber-optic-and-optoelectronic-systems-for-quan); [PMC4099294](https://pmc.ncbi.nlm.nih.gov/articles/PMC4099294). No IMU-vs-radiographic-Cobb kyphosis validation was found (see Gaps) |
| Trunk inclination / lateral bending | Upper trunk + mid trunk + pelvis | 3 accelerometer + gyro modules vs Vicon 370, n = 9: RMS difference < 3.1° sagittal and ≤ 2.1° coronal for trunk posture change [lab] — [Wong & Wong, Eur Spine J 2008](https://read.qxmd.com/read/18196296/trunk-posture-monitoring-with-inertial-sensors); [PMC2367407](https://pmc.ncbi.nlm.nih.gov/articles/PMC2367407) |
| Head/neck flexion | Head (forehead, headphone band, ear) ± chest/C7 | Head + chest IMUs vs optical mocap in 6 surgeons: neck flexion/extension within 2.9 ± 0.9°, trunk 1.6 ± 1.1° [lab, simulated surgery] — [UTMB record](https://researchexperts.utmb.edu/en/publications/validation-of-inertial-measurement-units-for-upper-body-kinematic/). Headphone + necklace IMU system vs 3D motion analysis, n = 29: intra-day ICC 0.954–0.971, error/MDC ≈ 1–2° [lab] — [Physical Therapy Korea 2023](https://doaj.org/article/f2204e0602fa44fd9ffd059b015de6fd) |
| Pelvic obliquity (frontal) | Sacrum | Obliquity and rotation are more variable than tilt; RMSE reached 6°–11° in high-speed running [lab] — [JoVE 2026 review](https://doi.org/10.3791/71343). Single lower-back IMU vs optoelectronic system, n = 17 (gait, sit-to-stand, step-up): frontal RMSE 2.7°–4.5°, sagittal 2.7°–8.9° — [Med Eng Phys (ScienceDirect)](https://www.sciencedirect.com/science/article/abs/pii/S1350453315002672) |
| Trunk / pelvic axial rotation | Any segment; needs heading | Accelerometers cannot observe rotation about gravity, so heading needs a magnetometer or gyro integration — [Sensors 19(6):1312](https://www.mdpi.com/1424-8220/19/6/1312). In a 2-day daily-life spine IMU study, magnetic interference affected 43% of all data — [Riddick, Alshehri & Hodges, Sensors 2025](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12390158/) |
| Shoulder protraction / rounded shoulders | Acromion or scapular spine | A review of wearable 3D scapular systems (14 articles) found high heterogeneity in calibration, tasks and populations. Acromion-flat-surface and scapular-spine placements are both used — [iris.unicampus record (search excerpt)](https://www.iris.unicampus.it/handle/20.500.12610/91344). Field validity was shown for humeral elevation, humeral axial rotation and scapular upward rotation; protraction was not mentioned — [Frontiers Sports Act Living 2024](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2024.1349570/epub). No validated wearable protraction measure was found |

- Rounded shoulder posture is defined as scapular downward rotation, protraction and anterior tilt, combined with increased cervical lordosis and upper thoracic kyphosis. A protraction sensor would have to separate these components — [Healthcare 2023 brace study](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10647296/)
- A vendor's software labelled a sacrum sensor's output "lumbar spine ROM", but with the sensor on the sacrum the output reflects pelvic motion. That labelling issue confounds comparisons between "lumbar" and "pelvic" results — [Validation of pelvis and trunk ROM using IMUs (PMC11273649)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11273649/)
- In daily life, wearable sensors estimate **relative** rather than absolute spinal angles and may be affected by soft-tissue motion — [Alshehri et al., J Clin Med 2025](https://www.mdpi.com/2077-0383/14/21/7518)

### Inferences
- A practical "precise" set for this user is 3 IMUs: upper thoracic (T1–T3), thoracolumbar (T12/L1) and sacral (S1/S2). Optionally add a head sensor (AirPods via iPhone, or a small IMU on a headband or glasses arm). From these: head pitch, cervical flexion proxy (head − T1), thoracic kyphosis change (T3 − T12), lumbar flexion (T12 − S1), pelvic sagittal tilt (S1/S2 vs gravity), frontal tilts at each level (lateral bending, pelvic obliquity proxy) and left–right asymmetry *of the frontal-plane angles*. This follows the placements that were validated above (Paloschi T3/T12/S1; Sharma S2/T12; dorsaVi T12/S2).
- **Forward head posture** in the clinical sense (craniovertebral angle, which is head *translation* relative to C7) cannot be measured by orientation sensors alone. A head − upper-trunk flexion difference is a correlated proxy, not CVA. The Korean accelerometer study's r ≥ 0.9 with CVA (Q5) suggests the proxy is useful, but it was a small pilot.
- **Rib flare** and **internal shoulder rotation** have no wearable-sensor measure in the literature found. An acromion IMU measures acromion orientation, which mixes scapular tilt, rotation and trunk posture.

### Gaps
- No study was found validating a skin IMU kyphosis angle against **radiographic Cobb** angles. Only motion capture, Spinal Mouse or flexicurve references exist.
- No study was found validating IMU **pelvic obliquity or axial rotation in sitting** (static seated frontal or transverse plane) against motion capture or radiographs.
- No validated wearable measure of **scapular protraction** or **rib flare** was found.

---

## Q2. Validated multi-IMU systems for spine/pelvis (dorsaVi ViMove/ViSafe, Movella/Xsens DOT, Shimmer, MbientLab MetaMotion, Notch, Lumo/Upright): accuracy, drift over hours, minimum sensor set

### Takeaway
The best-validated commercial spine system is **dorsaVi** (sensors at T12 and S2). It achieves about 1–2° RMSE against Vicon in standing and lifting tasks, but it is a clinical B2B product in a financially weak company and is not sold to consumers. **Movella DOT** has spine-ROM validity data (ICC ≥ 0.86 vs optical, n = 15) and an 8 h battery, but no macOS SDK and quote-only pricing. Research-grade options (Shimmer3, MbientLab MetaMotionS) are purchasable by individuals. MbientLab's Swift SDK supports macOS 14+, which makes it the most practical commercial fit for a Swift menu-bar app. Two sensors (T12 + sacrum) is the minimum set for lumbar flexion plus pelvic tilt, and a third at T1–T3 adds kyphosis. Static inclination does not drift (gravity-referenced). Heading/axial rotation does drift or is disturbed indoors.

### Cited Findings
**dorsaVi (ViMove / ViMove+ / ViSafe+)**
- ViMove vs Vicon, n = 34 (18 LBP, 16 pain-free), standing end-range lumbar inclination, 3 repetitions: RMSE 1.82 ± 1.00° flexion, 0.71 ± 0.34° extension, 0.77 ± 0.24° right and 0.98 ± 0.69° left lateral flexion. The authors judged agreement "clinically acceptable" and called for validation in complex 3D functional movement [lab] — [Mjøsund et al. 2017](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5361703/); [BMC PDF](https://bmcmusculoskeletdisord.biomedcentral.com/track/pdf/10.1186/s12891-017-1489-1)
- dorsaVi Version 6 vs Vicon during lifting, n = 12: symmetric lifts RMSE 0.86° (global T12), 0.90° (global S2), 1.34° (relative lumbar). Asymmetric lifts: 1.84°, 1.90°, 1.70° [lab] — [BMC Musculoskelet Disord 2022 (PMC9559006)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9559006/)
- Background claim quoted in a search excerpt: an earlier dorsaVi version had good concurrent validity for one-dimensional lumbar movement but poorer validity in complex, faster movement. The exact source page was not verified; it is one of [Springer s12891-022-05866-w](https://link.springer.com/10.1186/s12891-022-05866-w) or [Diagnostics 10(6):426](https://www.mdpi.com/2075-4418/10/6/426)
- ViMove cleared FDA 510(k) — [FDAnews](https://fdanews.com/articles/165867-dorsavis-vimove-wearable-device-clears-510k-hurdle)
- **[status unclear]** dorsaVi (ASX: DVL) was still filing with the ASX as of 2026-09-21 — [financialfilings.com](https://financialfilings.com/companies/dorsavi-ltd/). PitchBook shows trailing-12-month revenue of about USD 731k and a net loss of about USD 982k to 31 Mar 2026, with a share price of about $0.03 — [PitchBook](https://pitchbook.com/profiles/company/86624-02). Third-party profiles list ViMove+ (clinic/sport) and ViSafe+ (workplace) — [CB Insights](https://www.cbinsights.com/company/dorsavi). Current consumer availability was not confirmed.

**Movella DOT (formerly Xsens DOT)**
- Xsens DOT vs optical mocap, n = 15 healthy, spine ROM and movement quality: no significant differences between systems; ICC ≥ 0.86. Absolute ROM at C7, T12 and S1, plus relative thoracic, lumbar and total ROM, were the most reliable metrics. Between-day reliability was poorer, which the authors attribute to movement variability and **sensor placement**, not equipment error [lab]. This comes from an aggregator page; the journal is unconfirmed and possibly Applied Sciences 2025 — [wbldb.lievers.net index](https://wbldb.lievers.net/10404681.html); [iris.unica.it](https://iris.unica.it/handle/11584/444826)
- Specs: battery 8 h on the official shop page. A Univ. Lille equipment sheet says 10 h, and the conflict is unresolved. Charging about 1 h; real-time streaming up to 60 Hz; recording up to 120 Hz; orientation accuracy static 0.5° | 1.0° and dynamic 1.0° | 2.0° (1σ RMS; presumably roll/pitch | heading, not confirmed); latency 30 ms; 11.2 g; IP68 — [Movella shop](https://shop.movella.com/product-lines/wearables/products/xsens-dot-sensor); [Xsens DOT data sheet](https://www.xsens.com/hubfs/Xsens%20DOT%20data%20sheet.pdf); [Univ. Lille sheet](https://fr-scv.univ-lille.fr/fileadmin/user_upload/fr-scv/user_upload/images/Equipements/Xsens_Movella0506.pdf)
- SDK platforms: Android 8+, 64-bit Ubuntu 18.04/20.04, Windows 10+, iOS 11+. **No macOS SDK** is listed; the 2021.0 release notes list only a Data Exporter for Windows/macOS. Bluetooth 5.0 is required — [Movella DOT user manual](https://www.movella.com/hubfs/Movella%20DOT%20User%20Manual.pdf); [Xsens DOT 2021.0 release notes](https://www.movella.com/hubfs/Downloads/Xsens%20DOT%202021.0%20release/Xsens%20DOT%20Public%20Release%20Notes%202021.0.pdf)
- Price: "Request pricing" only, for both single sensors and the 5-sensor set (5 DOTs, charger, SDK) — [Movella shop DOT set](https://shop.movella.com/product-lines/wearables/products/xsens-dot-set)
- **[status unclear]** No DOT end-of-life notice was found. Movella EOL'd parts of the MTi 10/100 series from January 2025 (unrelated product line). The latest DOT release notes found date from 2023 — [MTi manual](https://mtidocs.movella.com/mti-10-100-series-user-manual); [DOT 2023.6.0 release blog](https://www.xsens.com/resources/blog/movella-dot-release-2023.6.0-a-step-forward-in-your-wearable-experience)

**MbientLab MetaMotionS (MMS)**
- MMS: BMI270 accelerometer/gyro, BMM150 magnetometer, BMP280, light sensor, Bosch 9-axis sensor fusion, 512 MB memory. Listed at **USD 129.99–136.99** (MMS+ with vibration motor 134.99–141.99). Some store items show "Out of stock" — [MbientLab store](https://mbientlab.com/store); [search excerpt of store pages](https://mbientlab.com/product-category/pcb/)
- MetaWear Swift SDK (README read directly): Swift 6, **macOS 14+**, iOS 17+, Xcode 16+; targets MetaMotion R/RL/S only. Sensor fusion outputs: quaternion, Euler, **gravity vector** (`.imuPlus` mode, no magnetometer) and linear acceleration. It supports **on-device flash logging while disconnected** with later download, a fusion calibration-state read (0–3), battery polling, a macOS CLI demo (`swift run MetaWearDemo`) and streaming up to 200 Hz in its app. It warns that MMS (BMI270) boards must pass `chip: .bmi270`, or fusion silently runs at the wrong ODR/range — [MetaWear-API-Swift README](https://github.com/mbientlab/MetaWear-API-Swift)
- Older MbientLab docs warn not to use the raw accelerometer, gyro and magnetometer modules while fusion is running — [MbientLab sensor fusion docs](https://mbientlab.com/androiddocs/3.6/_sources/sensor_fusion.rst.txt)
- MbientLab hardware in an office study: MetaWearC thigh sensor vs activPAL3M, 20 office workers, 3–8 working hours; sitting CCC = 0.98 (sitting/standing/stepping classification, not spine angle) [free-living] — [JMIR mHealth validation (PMC7435616)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7435616/)
- No report of MbientLab closing was found (search only) — [MbientLab store](https://mbientlab.com/store)

**Shimmer**
- Shimmer3 IMU unit is listed at €430; new buyers are directed to Consensys IMU development kits at €598–€7,074 (1–15 sensors); Shimmer3 200g IMU €545 (out of stock). Listing dates are not shown — [Shimmer3 IMU](https://shimmersensing.com/product/shimmer3-imu-unit/); [Consensys IMU kits](https://shimmersensing.com/product/consensys-imu-development-kits/)

**Notch, Lumo, Upright**
- Notch: no current information found (see Gaps).
- **[discontinued]** Lumo Bodytech (Lumo Lift, Lumo Back) is listed as closed. Its IP and engineers were picked up by Seismic (formerly Superflex, an SRI spin-off). The exact date was not confirmed — [Craft](https://craft.co/lumo-bodytech); [Sinovation Ventures](https://sinovationventures.com/blog/sri-wearable-spinoff-picks-up-ip-engineers-from-defunct-lumo-bodytech)
- Upright GO 2 is in Q5 (single upper-back sensor, no angle-validity study found).

**Multi-sensor research systems relevant to sitting**
- Office-worker lumbo-pelvic rhythm study: sensors at the thoracolumbar transition (above L1), the lumbosacral transition (above S1) and the right thigh. Lumbar flexion was computed as the difference between the first two inclinations; 63 sedentary office workers (30 LBP, 33 non-LBP); standardized maximal flexion task, not a work day — [Healthcare 2025](https://www.mdpi.com/2227-9032/13/10/1135); [PMC12111153](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12111153/)
- Lumbar lordosis maintenance in sitting with two wireless sensors at T12 and S2, n = 29 healthy, 3-min sitting tasks. Loss of lordotic angle was larger when instructed to sit upright (−3.7 ± 3.9°) than in habitual sitting (−1.2 ± 2.4°), p = 0.001. No radiographic validation [lab, seated] — [Sensors 2024 (PMC11084529)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11084529/)
- Lab vs real world, n = 25 pain-free adults, 48 h wearable monitoring: lab lumbar flexion 19.8° (upright sitting) vs 30.0° (questionnaire/preferred sitting) vs 27.1–28.1° (unstable sitting). Unstable-sitting posture correlated with real-world mean posture (r = 0.49–0.54) [lab + free-living] — [Alshehri et al., J Clin Med 2025](https://www.mdpi.com/2077-0383/14/21/7518); [PMC12608425](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12608425/)
- A sensorized-chair (pressure) system reached only about 66% (65.98%) posture-classification accuracy in real-world office use — [Sensors (PMC13517499)](https://pmc.ncbi.nlm.nih.gov/articles/PMC13517499/)

**Drift**
- Drift relative to gravity (pitch/roll) can be corrected from the accelerometer; heading drift is harder to correct — [DFKI publication](https://www.dfki.de/web/forschung/projekte-publikationen/publikation/10493); [Sensors 19(6):1312](https://www.mdpi.com/1424-8220/19/6/1312)
- A Rutgers cranial-angle-monitor thesis found gyroscope drift was linear but varied between IMUs and axes. Baseline gyro drift was too large for hour-long static tracking (gyro-only) — [Rutgers thesis](https://rucore.libraries.rutgers.edu/rutgers-lib/59151/)

### Inferences
- **Minimum set:** 2 sensors (T12/L1 + S1/S2) cover lumbar flexion, pelvic tilt and frontal-plane pelvic/lumbar tilt. This is the configuration that dorsaVi and the THA studies validated. A third sensor at T1–T3 adds kyphosis and upper-trunk inclination. A head sensor adds head pitch. Bilateral acromion sensors add only unvalidated shoulder information.
- **Drift over hours:** sagittal and frontal angles derived from the gravity vector (accelerometer-dominant during quasi-static sitting) should not accumulate drift. What changes over hours is **sensor/skin slippage and offset** (Q7), not orientation drift. Axial rotation (yaw) will drift with gyro-only fusion (e.g., BNO08x game vector at about 0.5°/min per SparkFun, Q3) and will be distorted indoors with magnetometer fusion (43% interference in Riddick 2025).
- For a Swift app on an Intel Mac running macOS 14, **MetaMotionS + MetaWear Swift SDK** is the only commercial option found with an official macOS-native SDK. Its on-board logging also allows all-day capture without a continuous BLE link. This is inferred from the README; Intel x86_64 build compatibility was not explicitly stated.

### Gaps
- No peer-reviewed study was found that quantifies **multi-hour orientation drift of a seated, skin-mounted spine IMU** against a reference.
- Movella DOT price, Korean availability and full specs (heading vs roll/pitch split) were not confirmed. Movella pages could not be fetched.
- Notch Interfaces' product status in 2026 was not researched successfully (no results).
- dorsaVi's consumer or individual purchase options and pricing were not found.
- MetaMotionS battery life in fusion streaming mode was not found.

---

## Q3. DIY/open options: low-cost BLE IMU boards (M5Stack, nRF52/ESP32 + BNO085/ICM-20948), sensor-fusion accuracy for static angles, streaming to a Mac (CoreBluetooth), calibration

### Takeaway
A DIY sensor with an on-chip-fusion IMU (BNO085/086) gives a datasheet-class static orientation error of about 1.5–2° and a gravity-referenced tilt that does not drift. That is adequate for tracking within-person trends in sagittal and frontal posture, though not for absolute anatomical angles. The open-source building blocks exist: ESP32/BNO08x BLE servers and ESP-IDF drivers. No validated, open-source, back-worn posture system with published accuracy against a reference was found. Calibration should use a standing or sitting reference posture and gravity alignment at each donning.

### Cited Findings
- BNO086 (same family as BNO085), per SparkFun's spec list:
  - Rotation Vector: dynamic error 3.5°, static error 2.0°.
  - Game Rotation Vector (no magnetometer): dynamic 2.5°, static 1.5°, **dynamic heading drift 0.5°/min**. Yaw drift is by design (Google spec).
  - Geomagnetic Rotation Vector: dynamic 4.5°, static 3.0°.

  These are vendor/datasheet figures, not independent validation — [SparkFun VR IMU Breakout BNO086](https://www.sparkfun.com/sparkfun-vr-imu-breakout-bno086-qwiic.html)
- Open-source pieces:
  - RLi43/ble_motion: BNO080 on ESP32 reporting over BLE — [GitHub](https://github.com/RLi43/ble_motion)
  - ESP-IDF BNO085 driver using CEVA SH-2 — [Espressif component registry](https://components.espressif.com/components/rinku404/bno085/versions/1.2.0/readme)
  - ESP32 + BNO085 over Bluetooth sample — [ComplexArts/SensorBoardArduino](https://github.com/ComplexArts/SensorBoardArduino)
  - OSHWA-certified Posture-Pulse: ESP32-C3 + IMU + flex sensors, slouch detection with an actuator alert; CERN-OHL-S-2.0 / MIT — [OSHWA IN000079](https://certification.oshwa.org/in000079.html)
  - An ESP32-C3 + MPU6050 vibrating posture corrector using ESP-NOW (not BLE) — [Circuit Digest](https://circuitdigest.com/microcontroller-projects/core-posture-smart-iot-posture-corrector-and-hydration-assistant)
- M5StickC Plus2 has a built-in **6-axis** IMU (no magnetometer, not a BNO085). Switch Science notes that the older M5StickC Plus reaches end of production in December 2025, with the Plus2 as successor — [Switch Science](https://www.switch-science.com/products/6470); [OpenELAB product page](https://openelab.io/fr/products/m5stickcplus2)
- Calibration and reference posture: in a lab-vs-home IMU spine study, the range of spinal motion was moderately repeatable (ICC = 0.67), but **absolute angles (e.g., starting posture) were more variable**. Of five methods for estimating the reference posture, a composite set of standardized tasks performed best (ICC = 0.72 ± 0.17) — [Riddick et al., Sensors 2025](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12390158/)
- The JoVE review associated better pelvic-tilt accuracy with **standardized calibration procedures** — [JoVE 2026](https://doi.org/10.3791/71343)
- Quasi-static intervals can be used to estimate gyro bias, and to reset joint-angle offsets when the trunk is in a neutral quasi-static pose — [DFKI adaptive fusion](https://av.dfki.de/?p=11459); [DFKI online calibration](https://av.dfki.de/?p=11458)
- MetaWear's Swift SDK shows a working CoreBluetooth stack on macOS 14. It notes that CoreBluetooth denies Bluetooth permission to `swift test` on macOS, so hardware tests need an app host, and that CoreBluetooth filters GAP services 0x1800/0x1801 on macOS — [MetaWear-API-Swift README](https://github.com/mbientlab/MetaWear-API-Swift)

### Inferences
- **Recommended DIY design for static posture:** use the accelerometer/gravity vector (or the BNO08x *game* rotation vector's pitch/roll), not the magnetometer-fused vector. Indoors, magnetic disturbance degrades heading and can also degrade inclination (Q6). Compute each segment's sagittal and frontal inclination, then differences between segments.
- **Calibration routine:**
  1. After donning, sit in a standardized "reference" posture (or stand) for 5–10 s.
  2. Store each sensor's gravity vector as zero.
  3. Report angles as deviations from that reference.
  4. Optionally add a composite of standardized tasks (e.g., upright sit, slump sit, forward bend) to anchor the range, following Riddick 2025.
  5. Re-zero after re-attachment.
- **Mac streaming:** an ESP32/nRF52 BLE peripheral with a custom GATT service at 10–50 Hz is enough for posture. CoreBluetooth central mode on macOS 14 works on Intel in general (assumption; no Intel-specific source found). Logging to flash plus batch download (as MetaWear does) preserves battery.
- Expected realistic accuracy: about 1–3° for change in inclination at one level under quiet sitting. Between-session absolute offsets of several degrees are likely, driven by placement (Q7).

### Gaps
- No independent validation of BNO085/ICM-20948 static tilt accuracy against an inclinometer or mocap in a wearable posture setting was found.
- The primary CEVA BNO085 datasheet could not be retrieved; figures come from SparkFun's BNO086 listing.
- No open-source project was found that publishes accuracy for multi-segment spinal angles.

---

## Q4. Strain/flex sensors, fiber optics and smart garments along the spine: validated accuracy for spinal curvature; durability

### Takeaway
Strain-gauge and fiber-optic spine strips (Epionics SPINE, ShapeTape, plastic optical fiber, FBG arrays) can measure lumbar lordosis and thoracic curvature *shape*. Lab agreement with motion capture is about 3–4° (R² ≈ 0.98 for curvature), and static X-ray agreement is reported as "good". Garment-integrated sensors are mostly validated only as **posture classifiers** (>95% in 10-person lab studies), not as angle meters. Fabric motion relative to the skin adds up to about 17° of error for IMUs in smart clothing. No consumer smart garment with validated seated spinal angles was found, and durability data are essentially absent.

### Cited Findings
- **Epionics SPINE** (strain-gauge strips along the spine):
  - n = 30 asymptomatic adults: good agreement with X-ray and Spinal Mouse in static positions; mean standing lordosis 32.4 ± 9.7° — [PMC3481097](https://pmc.ncbi.nlm.nih.gov/articles/PMC3481097)
  - Normative lordosis velocity data, n = 429 — [Consmüller et al., PLoS ONE 2012](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3500339/)
  - vs Vicon, n = 20 healthy: excellent agreement for chair rising, box lifting and countermovement jumps; systematic underestimation of lordosis during walking and running [lab] — [J Biomech 2019 / arXiv 1910.04282](https://arxiv.org/pdf/1910.04282); [BFH record](https://arbor.bfh.ch/9917)
- Three-device comparison (Epionics SPINE, Idiag M360/Spinal Mouse, raster stereography): lordosis values differed significantly between devices despite moderate-to-high correlations. The authors advise against mixing devices in long-term monitoring — [Sci Rep 2022](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9205914/); [DOAJ](https://doaj.org/article/3e6c8ecb2b5944d7b8baf53373923874)
- **ShapeTape** (fiber-optic shape sensor) vs Optotrak in **sitting**, n = 26 able-bodied adults: curvature R² = 0.98; mean kyphosis differences about 3.6–4.3° across postures, wide limits of agreement [lab, seated] — [Mayo Clinic record](https://mayoclinic.elsevierpure.com/en/publications/agreement-between-fiber-optic-and-optoelectronic-systems-for-quan); [PMC4099294](https://pmc.ncbi.nlm.nih.gov/articles/PMC4099294)
- **Garment-integrated plastic optical fiber** for seated spinal posture, n = 9 vs motion capture: mean value error 0.64 ± 3.1° (14.5% of average ROM), mean time error 0.53 ± 0.8 s. Reported to approximate expert visual analysis [lab, seated] — [Dunne et al., "Wearable monitoring of seated spinal posture"](https://experts.umn.edu/en/publications/wearable-monitoring-of-seated-spinal-posture/); [ResearchGate](https://www.researchgate.net/publication/221240652_Design_and_Evaluation_of_a_Wearable_Optical_Sensor_for_Monitoring_Seated_Spinal_Posture)
- **FBG arrays:**
  - PDMS "double-fishtail" FBG array on the thoracic spine, validated against mocap with 10 volunteers: >96.30% classification of normal, "breast-bearing" and hunchbacked sitting (random forest) [lab] — [UMONS repository PDF](https://orbi.umons.ac.be/bitstream/20.500.12907/50947/1/Double-Fishtail-Shaped_FBG_Wearable_Device_for_Sitting_Posture_Recognition_and_Real-Time_Respiratory_Monitoring.pdf)
  - Earlier FBG low-back movement device — [Sensors 2020 (PMC7411829)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7411829/)
- **Flexible electrogoniometer** for thoracic kyphosis vs radiographic Cobb, n = 12: r = 0.81 with mid-Cobb. Can record angles over time outside the lab — [ANU record](https://researchportalplus.anu.edu.au/en/publications/validation-of-the-flexible-electrogoniometer-for-measuring-thorac/)
- Non-wearable references for comparison:
  - Manual inclinometer vs Cobb, n = 11: r = 0.86, mean difference 4.8 ± 8.9°.
  - Flexicurve: mean difference 20.3 ± 6.1° (systematically smaller than Cobb).

  [Univ. of Limerick record](https://pure.ul.ie/en/publications/validation-of-the-manual-inclinometer-and-flexicurve-for-the-meas/). Spinal Mouse in older adults, n = 46: SEM 2.01–4.26°, inter-rater ICC 0.80–0.89 — [Ahi Evran record](https://unis.ahievran.edu.tr/yayin-detay/2_D3GrCZG_32/assessment-of-thoracic-kyphosis-and-lumbar-lordosis-on-skin-surface-in-older-adults-spinal-mouse-validity-and-reliability)
- **Smart garment** for dynamic sitting reminders: >95% posture recognition (random forest). It argues that IMUs alone struggle, e.g., with crossed legs the spine angle may barely change, and that textile stretch sensors over back muscles add information [lab] — [Designing a Smart Garment for Dynamic Sitting Reminders (PMC12157298)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12157298/)
- Smart shirt for measuring trunk orientation — [Sensors 22(23):9090](https://doi.org/10.3390/s22239090); [PMC9739249](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9739249/). Error figures could not be retrieved.
- Fabric motion: IMUs built into smart clothing showed RMSE of 0°–16.8° for upper-limb and trunk kinematics. The largest fabric deformation was under the armpits and **along the back** (2025 thesis; the search excerpt did not make clear which of these two records it was) — [UBC HUMBL](https://humbl.sbme.ubc.ca/?p=2935); [Unibo thesis](https://amslaurea.unibo.it/id/eprint/34369/)
- A registered trial plans to test whether a garment-integrated system detects spine position with clinical accuracy against motion capture — [ClinicalTrials.gov NCT02080611](https://clinicaltrials.gov/study/NCT02080611)

### Inferences
- For an individual, strain and fiber spine strips are **not practical to buy**. Epionics SPINE and ShapeTape are research or clinical instruments, and FBG needs an optical interrogator. DIY flex sensors (resistive bend strips) give a curvature *signal* but no validated angle. IMU chains at 2–3 levels approximate the same curvature information more cheaply and robustly.
- Garment-based sensing trades donning convenience for fabric-slip error. Tight compression garments reduce but do not remove it. For angle tracking, sensors taped to skin beat sensors sewn into loose clothing.

### Gaps
- No durability, wash-cycle or long-term drift data for spine strain or textile sensors were found.
- No commercially available posture shirt with published angle validity was found.

---

## Q5. Consumer devices that already measure head/neck posture: AirPods (CMHeadphoneMotionManager), smart glasses, Apple Watch, earbud apps, Upright-type single sensors

### Takeaway
**AirPods** stream head attitude, rotation rate, user acceleration and gravity through `CMHeadphoneMotionManager`. That gives head pitch relative to gravity, which is a reasonable neck-flexion proxy. However:
- **No peer-reviewed accuracy study against motion capture or an inclinometer exists.** Accuracy claims are app-marketing only.
- AirPods have no magnetometer, so yaw is relative.
- On an Intel Mac, availability remains unverified, because Mac head tracking is documented for Apple silicon.

A relay through an iPhone is the safest path. JINS MEME glasses ended consumer sales in 2024. The Upright GO 2 single upper-back sensor has only pilot usability studies and no angle validation. Apple Watch measures the wrist and is not a posture sensor.

### Cited Findings
- Apple documentation (JSON endpoint read 2026-10-11): `CMHeadphoneMotionManager` is available on iOS 14.0+, iPadOS 14.0+, Mac Catalyst 14.0+, **macOS 14.0+** and watchOS 7.0+. "In iOS and macOS, include the NSMotionUsageDescription key in your app's Info.plist file. If this key is absent, the system crashes your app when you start device-motion updates" — [Apple Developer: CMHeadphoneMotionManager](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager)
- WWDC23: the class streams device motion from audio products that support Spatial Audio with dynamic head tracking (e.g., AirPods Pro) to a connected iOS, iPadOS or **macOS 14** device — [WWDC23 session 10179](https://developer.apple.com/videos/play/wwdc2023/10179); [WWDC Notes](https://wwdcnotes.com/notes/wwdc23/10179)
- The earlier research for this project found Apple Support stating that Spatial Audio head tracking on Mac is for "Mac computers with Apple silicon" (search excerpt). Intel support for headphone motion is unverified — [Apple Support HT211775](https://support.apple.com/en-au/HT211775). No source was found either confirming or denying that `isDeviceMotionAvailable` returns false on Intel Macs (this search).
- Apple publishes no update rate. A third-party reference advises reading the reported data frequency at runtime rather than assuming a value — [tessl swift-ios-skills core-motion reference](https://tessl.io/registry/dpearson2699/swift-ios-skills/3.6.1/files/skills/core-motion/references/motion-patterns.md)
- AirPods contain **no magnetometer**, so orientation is relative to the head's initial frame. IMUPoser used AirPods Pro with Vicon ground truth, but the excerpt gives no head-orientation error — [IMUPoser, arXiv 2304.12518](https://arxiv.org/pdf/2304.12518). AirPods, Pixel Buds and Galaxy Buds lack magnetometers; eSense earable head tracking reached "a few degrees" using both earbuds — [Ferlini et al. 2019](https://www.cl.cam.ac.uk/~cm542/papers/earcomp19.pdf). Auritus earable head-pose filters reached errors as low as about 5° — [Auritus (NSF PAR)](https://par.nsf.gov/servlets/purl/10385253)
- **[vendor claim]** CheckNeck uses CMHeadphoneMotionManager at "up to 100 Hz" with "sub-degree accuracy"; no validation is cited — [hunted.space CheckNeck](https://www.hunted.space/product/checkneck). **[vendor claim, unsourced]** AirPosture cites "±1.5°" detection accuracy for 15°–45° pitch from unnamed "lab tests" — [xugj520.cn write-up](https://www.xugj520.cn/en/archives/airpods-posture-coach-innovation.html)
- Korean media coverage of **PosturePod**, an AirPods Pro posture-monitoring app, characterizes it as a habit aid — [Kormedi 2026](https://kormedi.com/2813582/)
- Closest validated non-AirPods head systems:
  - Headphone + necklace IMU vs 3D motion analysis, n = 29: ICC 0.954–0.971, about 1–2° error/MDC [lab] — [Physical Therapy Korea 2023](https://doaj.org/article/f2204e0602fa44fd9ffd059b015de6fd)
  - Korean 3-axis-accelerometer neck wearable: mean error 1.2°, r ≥ 0.9 with CVA (pilot; sample size not shown) — [KoreaScience JAKO201622341962305](https://www.koreascience.or.kr/article/JAKO201622341962305.pdf)
  - Single cervical IMU in a real office, 10 male participants: detected FHP-state transitions (> 10 s) with < 0.5 s delay. This tests detection timing, not angle accuracy [free-living office] — [Electronics 13(7):1363](https://www.mdpi.com/2079-9292/13/7/1363/html)
- Smartphone-app CVA (photo-based, not wearable): valid and reliable in standing, n = 44 — [PMC7559098](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7559098/). r = 0.95 vs reference in 90 neck-pain patients — [PMC10558335](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10558335/)
- **[discontinued for consumers]** JINS MEME smart glasses (6-axis IMU + EOG): general sales ended 27 Mar 2024, leaving business-only sales. Web API, Webhook and integrations ended around May 2024; app support ran until the end of August 2025 — [FASHIONSNAP](https://www.fashionsnap.com/article/2024-03-13/jins-meme-close/); [Impress K-tai Watch](https://k-tai.watch.impress.co.jp/docs/news/1576121.html); [MoguraVR](https://www.moguravr.com/?p=247895)
- **Upright GO 2** (single sensor on the upper back):
  - Launched 2019 at USD 149.95 — [Pickr](https://next.pickr.com.au/news/2019/upright-go-updates-posture-perfecting-to-version-two)
  - Parkinson's pilot, n = 25: may improve neck/upper-back alignment while sitting and standing, not walking — [PubMed 34656009](https://pubmed.ncbi.nlm.nih.gov/34656009/)
  - Ophthalmology-resident pilot listed small sample and "device data fidelity" as limitations — [PMC12292650](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12292650/)
  - RCT NCT03769246 (n = 30) completed; no results found — [ClinicalTrials.gov](https://clinicaltrials.gov/study/NCT03769246)
  - Consumer reviewer: effectiveness depends on correct calibration — [Choice](https://accounts.choice.com.au/?p=768770)
  - **No angle-validity study found.** Status: no discontinuation notice found; a June 2026 aggregator still describes it as current (weak evidence) — [ShopSavvy](https://shopsavvy.com/reviews-tldr/upright-go-2-posture-corrector.md)

### Inferences
- AirPods-derived **head pitch vs gravity** is the cheapest precise-ish neck signal for this user, since they likely own AirPods and an iPhone. Because of the Intel uncertainty, the robust architecture is: an iPhone companion app reads `CMHeadphoneMotionManager` and forwards pitch/roll samples over the local network (Bonjour/Multipeer) or BLE to the Mac menu-bar app. A 20-line probe on the iMac should still be tried first.
- AirPods pitch measures **head orientation**, not neck flexion. Combining it with an upper-thoracic IMU (head − T1) gives cervical flexion. Neither gives forward head translation.
- Apple Watch cannot measure spine posture. It is wrist-worn, and arm motion dominates its signal. This is an inference; no source was searched.

### Gaps
- No peer-reviewed validation of AirPods (CMHeadphoneMotionManager) pitch against mocap or an inclinometer was found.
- The actual behavior on an Intel iMac with macOS 14 is unknown and needs an on-device probe.
- No information was found on current smart glasses with open IMU APIs (post-JINS MEME) suitable for head posture.
- The AirPods head-motion sample rate is undocumented.

---

## Q6. Can wearables measure left–right asymmetry (lateral pelvic tilt/obliquity, trunk rotation) while seated, and how reliably?

### Takeaway
**Frontal-plane asymmetry** (pelvic obliquity and lateral trunk lean, measured as the sacral or thoracolumbar sensor's roll relative to gravity) is measurable with the same physics as sagittal tilt. Error is about 2–5° in lab tasks. However, it has never been validated specifically in static sitting, and obliquity is consistently less accurate than tilt. **Transverse-plane asymmetry** ("left buttock further back" = pelvic axial rotation; trunk rotation) depends on heading, which is unreliable indoors (magnetic interference) or drifts (gyro-only). Seated pelvic tilt itself is also sensitive to mid-back posture. Wearables can track *changes* in frontal-plane asymmetry over time, but cannot reliably quantify seated axial rotation.

### Cited Findings
- Pelvic obliquity and rotation show greater variability than tilt (RMSE up to 6°–11° in high-speed running). Reliability is weaker in clinical populations — [JoVE 2026 review](https://www.jove.com/v/71343/validity-reliability-inertial-measurement-units-for-pelvic); [PubMed 42224203](https://pubmed.ncbi.nlm.nih.gov/42224203/)
- Single lower-back IMU, n = 17: frontal-plane RMSE 2.7°–4.5° across gait, sit-to-stand and step-up — [ScienceDirect S1350453315002672](https://www.sciencedirect.com/science/article/abs/pii/S1350453315002672)
- ViMove lateral flexion inclination (standing): RMSE 0.77° right and 0.98° left vs Vicon, n = 34 — [Mjøsund 2017](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5361703/). Wong & Wong: coronal RMS difference ≤ 2.1° — [Eur Spine J 2008](https://read.qxmd.com/read/18196296/trunk-posture-monitoring-with-inertial-sensors)
- In the flexed-seated position, IMU pelvic tilt was more variable and tracked inversely with mid-back angle. The authors advise adjusting protocols for the mid-back angle [clinic] — [Sensors 2023, THA repeatability (PMC9823306)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9823306/)
- Sacral IMU vs radiograph for the standing → flexed-seated change in pelvic tilt: R² = 0.911; 75% of absolute errors < 5° — [Wang et al., Sensors 2020 (PMC7663251)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7663251/)
- Heading is unobservable from gravity. Indoor magnetic disturbance from steel, magnets and similar sources degrades heading and can also degrade inclination — [Sensors 19(6):1312](https://www.mdpi.com/1424-8220/19/6/1312); [FAU: eliminating magnetic disturbance effects on inclination](https://www.cris.fau.de/publications/253670987/); [MagShield, arXiv 2506.22907](https://arxiv.org/pdf/2506.22907)
- Magnetic interference affected 43% of 2-day daily-life spine IMU data — [Riddick et al., Sensors 2025](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12390158/)
- A seat-support-force instrumented wheelchair could not estimate pelvis angle in healthy users — [Univ. Twente](https://research.utwente.nl/en/publications/can-pelvis-angle-be-monitored-from-seat-support-forces-in-healthy/)

### Inferences
- **What this user can track:**
  - Sacral roll: a persistent left- or right-down pelvic obliquity proxy while seated.
  - T12 roll minus sacral roll: lumbar lateral bend.
  - Upper-thoracic roll: shoulder-girdle lean.
  - Side-to-side asymmetry of the frontal-angle distribution over a day.

  These are the most defensible "asymmetry" metrics.
- "Left buttock further back" and "only the left back touches the backrest" are mainly **transverse-plane rotation and translation relative to the chair**. Body-worn orientation sensors cannot measure translation. Rotation needs either:
  - (a) relative yaw between a sacral sensor and a chair- or desk-mounted reference sensor, re-zeroed at a known neutral sit, using gyro-only short-term yaw (drift about 0.5°/min for BNO08x game vector, so re-zero often); or
  - (b) a non-wearable modality (seat/backrest pressure mat, or a camera from above or the side).

  Both are unvalidated for this purpose.
- "One side of the low back rises when bending" could be recorded as the difference in frontal-plane tilt between T12 and the sacrum during a standardized forward bend, done the same way each time. This is a descriptive record for a clinician, not a scoliosis or leg-length diagnosis. Skin-surface angles cannot separate structural from functional causes.
- Leg-length discrepancy and true pelvic obliquity require radiographic or clinical measurement. Sensor obliquity in sitting reflects seat contact, soft tissue and posture.

### Gaps
- No study was found validating **static seated** pelvic obliquity or axial rotation from wearables against mocap or radiographs.
- No study was found on test-retest reliability of seated frontal-plane asymmetry metrics across days.

---

## Q7. Practical issues: skin adhesion, sensor slippage, clothing, sweating, daily donning variability, re-calibration, all-day wearability

### Takeaway
Placement and donning variability, not sensor electronics, dominate between-day error. Between-day reliability is consistently worse than within-day, and absolute angles are less repeatable than ranges. Studies handle this with a per-session reference posture or a set of standardized calibration tasks. Taping sensors directly to the skin over the spinous processes is the standard method; fabric-mounted sensors add large errors. No study quantified the repositioning error from removing and re-applying a spine sensor, and no data on sweating or skin tolerance over full days were found.

### Cited Findings
- Xsens DOT spine study: poorer between-day reliability was attributed to movement variability and **sensor placement** — [wbldb.lievers.net index](https://wbldb.lievers.net/10404681.html)
- Lab-vs-home study: absolute spine angles were more variable and harder to estimate than ranges. Reference-posture estimation was the key factor; a composite of standardized tasks performed best (ICC 0.72 ± 0.17). Sensor placement is listed among accuracy-degrading factors — [Riddick et al., Sensors 2025](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12390158/)
- HIKOB FOX IMUs in chronic LBP: lumbar between-day reliability (CV ≈ 15%, ICC 0.28–0.59) was worse than pelvis/thorax (CV ≈ 10%, ICC 0.48–0.78). This is for a stability metric, not a posture angle — [HAL Montpellier](https://hal.umontpellier.fr/hal-03280507)
- Spinal-wheel device, test–retest one week apart: ICC 0.719–0.908, typical error 4.0°–7.4° for thoracic/lumbar posture. Skin-marker study (7–10 days apart): MDCs mostly < 15° for lumbar/thoracic angles. Both are from a search excerpt; the source attribution among results is not verified — [search result set incl. ETH research collection](https://www.research-collection.ethz.ch/server/api/core/bitstreams/7a567368-0ee6-49c5-8744-77984d004f20/content)
- Alshehri 2025: daily-life wearable spinal angles are relative, not absolute, and affected by soft-tissue motion — [J Clin Med 2025](https://www.mdpi.com/2077-0383/14/21/7518)
- Vicon IMU guidance: use straps for limbs and **suitable tape** to attach sensors directly where vertebral movement is of interest — [Vicon IMU help](https://vicon-help.atlassian.net/wiki/spaces/IMU/pages/73120776/Attach+IMU+sensors+to+a+subject)
- Knee study: skin-mounted IMUs (elastic hook-and-loop bands) had RMSE up to 6.5° before frame-alignment correction, vs 5.1° for a rigid harness — [Bioengineering 2024](https://doaj.org/article/caa4a806223146d29cfcf27167f571c2)
- No studies have investigated relative movement between body segment and sensor attachment itself (2020 statement) — [Curr Dir Biomed Eng 2020](https://doaj.org/article/c3c48b00e3a14c3894c3ad8917c3fc04)
- Smart-clothing IMUs: fabric motion is the main error source (RMSE 0–16.8°), especially along the back — [UBC HUMBL](https://humbl.sbme.ubc.ca/?p=2935); [Unibo](https://amslaurea.unibo.it/id/eprint/34369/)
- A Sharma 2022 eligibility criterion excluded BMI > 40, implying soft tissue limits sensor accuracy — [Arthroplasty Today 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC8784288)
- Free-living multi-day wear has been done: 48 h lumbar monitoring in 25 adults — [J Clin Med 2025](https://www.mdpi.com/2077-0383/14/21/7518). Two days at home — [Sensors 2025](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12390158/). A whole workday plus overnight in 30 office workers (feasibility/acceptability study) — [WorkplaceNL summary](https://workplacenl.ca/resource/executive-summary-the-effect-of-objectively-measured-sitting-time-during-work-and-leisure-on-back-function-and-perceived-low-back-pain-a-feasibility-study)

### Inferences
- **Donning protocol for a single user:**
  1. Have someone, or a clinician once, mark C7/T1, T12 and S1/S2 with a skin marker or a small tattoo-style dot. Alternatively, take a reference photo of the placement.
  2. Use hypoallergenic double-sided tape plus an overlay film for all-day wear.
  3. Run a 10-second reference sit (plus optional standing) at each donning.
  4. Store per-session offsets.
  5. Compare across days mainly in *relative* terms (change from that day's reference, time spent beyond thresholds, left–right distributions).
  6. Flag sessions where the reference posture differs from the running median by more than a few degrees as a possible misplacement.
- Expect between-day absolute offsets of roughly 3–7° (inferred from the typical-error ranges above). Trend metrics should therefore be distribution-based (percentiles, time in band), not single absolute angles.
- Sensors on clothing (clip-on) are acceptable for coarse slouch alerts but not for "precise" records.

### Gaps
- No data were found on the degrees of error from removing and re-applying the same spine IMU at a marked site.
- No data were found on adhesive skin tolerance, sweating or itching for 8+ h back-worn sensors in office workers.
- No published comfort or wearability ratings specific to C7/T12/sacrum taped sensors were found.

---

## Q8. Battery, data access (raw data/SDK, Bluetooth to a Mac), privacy, cost and availability (including Korea); product status as of October 2026

### Takeaway
For an individual on an Intel Mac running macOS 14, the options in order of practicality are:
1. **MbientLab MetaMotionS**: about USD 130 each; official Swift SDK with macOS 14+ support; raw and fused data; on-board logging; local BLE only.
2. **DIY ESP32/nRF52 + BNO085**: lowest cost; fully local; no validation.
3. **AirPods via an iPhone relay** for head pitch: already owned; no validation.
4. **Movella DOT**: validated, 8 h battery, but quote-only pricing and no macOS SDK.
5. **Shimmer3**: €430+ per unit.

dorsaVi is clinical and B2B, Lumo is defunct, and JINS MEME consumer sales ended. Korean pricing and distributors could not be confirmed for any product.

### Cited Findings
| Product | Status (Oct 2026) | Price | Data access / Mac | Battery | Source |
|---|---|---|---|---|---|
| MbientLab MetaMotionS | Sold; some items out of stock | USD 129.99–136.99 | Swift 6 SDK, macOS 14+, raw + fusion (quaternion/Euler/gravity), on-device logging, local BLE | Not found | [MbientLab store](https://mbientlab.com/store); [MetaWear-API-Swift](https://github.com/mbientlab/MetaWear-API-Swift) |
| Movella DOT | No EOL notice found; last release notes found from 2023 **[status unclear]** | Quote only | SDK for Android/Linux/Windows/iOS; no macOS SDK; streaming 60 Hz, recording 120 Hz | 8 h (Movella shop) vs 10 h (Univ. Lille sheet) | [Movella shop](https://shop.movella.com/product-lines/wearables/products/xsens-dot-sensor); [User manual](https://www.movella.com/hubfs/Movella%20DOT%20User%20Manual.pdf) |
| Shimmer3 IMU | Sold (listing date unknown) | €430 unit; kits €598–€7,074 | Consensys software (details not checked) | Not found | [Shimmer](https://shimmersensing.com/product/shimmer3-imu-unit/) |
| dorsaVi ViMove+/ViSafe+ | Company still filing with ASX; small revenue **[status unclear]** | Not public | Clinical software | Not found | [financialfilings](https://financialfilings.com/companies/dorsavi-ltd/); [PitchBook](https://pitchbook.com/profiles/company/86624-02) |
| Upright GO 2 | No EOL notice found | USD 149.95 at 2019 launch | App-based; raw-data API not found | Not found | [Pickr 2019](https://next.pickr.com.au/news/2019/upright-go-updates-posture-perfecting-to-version-two) |
| Lumo Lift / Lumo Back | **[discontinued]** company closed | — | — | — | [Craft](https://craft.co/lumo-bodytech) |
| JINS MEME | **[discontinued for consumers]** 27 Mar 2024; app support to Aug 2025 | — | Web API ended about May 2024 | — | [FASHIONSNAP](https://www.fashionsnap.com/article/2024-03-13/jins-meme-close/) |
| AirPods (Pro/3rd gen/Max) | Current | Already owned | CMHeadphoneMotionManager, macOS 14+ API; Intel unverified | Not researched | [Apple docs](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager) |
| BNO085/086 breakout + ESP32 | Current | Price not captured | Fully open (SH-2 protocol, custom BLE GATT) | Depends on cell | [SparkFun BNO086](https://www.sparkfun.com/sparkfun-vr-imu-breakout-bno086-qwiic.html) |
| M5StickC Plus2 | Current; Plus (v1) EOL Dec 2025 | Price not captured | ESP32, 6-axis IMU, BLE | Built-in battery (capacity not captured) | [Switch Science](https://www.switch-science.com/products/6470) |

- Korea:
  - A 2022 Sahmyook University project combined a wearable IMU with an EMS module and a smartphone app for forward-head-posture monitoring; commercialization was not confirmed — [Sahmyook Univ. news](https://www.syu.ac.kr/blog/%ea%b1%b0%eb%b6%81%eb%aa%a9-%ea%b0%9c%ec%84%a0%ed%95%98%eb%8a%94-iot-%ec%9b%a8%ec%96%b4%eb%9f%ac%eb%b8%94-%ec%8b%9c%ec%8a%a4%ed%85%9c-%ea%b0%9c%eb%b0%9c%ed%95%9c%eb%8b%a4/)
  - The AirPods-based PosturePod app was covered by Korean media in 2026 — [Kormedi](https://kormedi.com/2813582/)
  - Korean validation research exists for headphone/necklace neck-angle IMUs — [Physical Therapy Korea 2023](https://doaj.org/article/f2204e0602fa44fd9ffd059b015de6fd)
  - No Korean retailer price for Upright GO 2, MetaMotionS, Movella DOT, M5StickC Plus2 or BNO085 was found in searches.
- Privacy-relevant architecture: the MetaWear SDK runs scanner, BLE transport and protocol locally and offers SwiftData persistence and CSV export, with no cloud requirement described in the README — [MetaWear-API-Swift](https://github.com/mbientlab/MetaWear-API-Swift)

### Inferences
- **Privacy:** IMU posture data is low-identifiability compared with camera frames, and BLE links stay local. A DIY or MetaWear pipeline keeps all data on the Mac (CSV/SQLite) for private trend tracking and clinician export. Consumer apps such as Upright and AirPods posture apps may sync to vendor clouds; their policies were not checked.
- **Cost for a 3-sensor spine set:**
  - MetaMotionS: about USD 390–410 plus shipping and import duty to Korea.
  - DIY ESP32 + BNO085: likely well under USD 100 for three units (component prices not captured; inference).
  - Movella DOT: unknown (quote).
- **Battery:** all-day (8+ h) wear is borderline for streaming IMUs (Movella DOT 8 h at most). A low-rate design (e.g., 10–25 Hz, or on-board logging with periodic sync) is preferable for posture, which changes slowly.

### Gaps
- Korean availability, distributors and KRW prices for every product listed were not found (Korean-language searches returned nothing relevant).
- Battery life was not found for MetaMotionS, Upright GO 2, or AirPods head-motion streaming.
- Privacy policies and cloud dependence of Upright GO 2 and the AirPods posture apps were not checked.
- Movella DOT BLE GATT protocol documentation, which could allow a direct CoreBluetooth integration without the SDK, was not verified.
