# Existing posture-monitoring apps, products and open-source projects: how they detect "bad posture" (state as of October 2026)

> **Evidence legend.** **[code]** = read directly in the cloned repository at the commit in the link (strongest evidence). **[repo-docs]** = the repository's README/CHANGELOG/PRIVACY file. **[listing]** = vendor, App Store, Setapp or Product Hunt text (marketing, not independently checked). **[press]** = tech press or review. **[ss]** = known only from a search-engine result summary. This session's egress proxy blocked direct fetches of apps.apple.com, korben.info, gigazine.net, news.ycombinator.com, reddit.com, setapp.com, cultofmac.com, mac.softpedia.com, digitaltrends.com and ithinkdiff.com, so every [ss] item is second-hand and may paraphrase or merge several pages. The session's shared web-search budget ran out before the candidate list was finished (see the Gaps sections).

## 1. Which signals do existing products rely on, and which products cover macOS? (product-by-product catalogue)

### Takeaway
Front-camera desktop products almost always use the simplest available signal: the vertical position of the face or nose, plus face size as a proxy for leaning closer, compared with the user's own calibrated baseline. Full-body skeletons appear in only two roles: (a) to obtain the nose point (Dorso), or (b) in side-view tools that measure neck and trunk angles (PostureFix, LearnOpenCV-style scripts). AirPods-based tools measure only head pitch. Body-worn wearables use the tilt of an IMU on the trunk (Upright GO is still sold; Lumo Lift is discontinued).

macOS coverage:
- **Camera apps:** Dorso (formerly Posturr; open source, universal binary), PostureBar (open source, universal), PostureFix (open source, side view), SitApp (Apple M1 or later only), Nekoze, SitWit (formerly MacPosture), SlouchSniper (Setapp) and Posture Monitor.
- **AirPods apps:** Posture Pal, SitTall and Dorso's AirPods mode. All three need macOS 14 or later.

### Cited Findings

#### 1a. macOS camera apps, open source (code inspected)

**Dorso (formerly "Posturr").** Actively maintained. The latest release is v1.15.1 (2026-07-19) and the last commit is from 2026-08-25.
- **Timeline.** First released as Posturr v1.0.0 on 2026-01-24, with "Multi-screen corner calibration" and a "Universal binary (Apple Silicon + Intel)" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L578-L589). Renamed Dorso in v1.9.0 (2026-02-16) [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L144-L147). The Show HN post reached the Hacker News top 10 on 2026-01-26 [ss: Gigazine](https://gigazine.net/gsc_news/en/20260126-posturr/), [ss: HN thread](https://news.ycombinator.com/item?id=46754944).
- **Distribution and price.** MIT-licensed. Available through Homebrew, as signed and notarized GitHub releases, and on the Mac App Store (badge links to id6758276540, "posturr-posture-monitor") [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/README.md#L7). Korben describes it as free, requiring macOS 13+, and installable with `brew install --cask dorso` [ss: Korben](https://korben.info/en/dorso-mac-app-blurs-screen-when-you-slouch.html).
- **Platform.** Camera mode needs macOS 13+. AirPods mode needs macOS 14+ and AirPods Pro, Max, or 3rd generation or later [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/README.md#L35), [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/README.md#L155-L176). AirPods 4 with ANC support was added in v1.11.0 [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L84).
- **Camera sensing [code].** Each processed frame runs `VNDetectHumanBodyPoseRequest` and keeps only the `.nose` joint (confidence > 0.3). If no body is found, it falls back to `VNDetectFaceRectanglesRequest` and uses the face box's midY and width [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L464-L504). Capture is 640×480 (VGA preset) [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L325-L337).
- **Press claim vs code.** Gigazine and AlternativeTo say Posturr tracks "the relative position of the nose and shoulders" and measures the vertical distance between them [ss: Gigazine](https://gigazine.net/gsc_news/en/20260126-posturr/). The current code uses no shoulder joints at all, only nose Y, plus face width in the face-box fallback [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L482-L507).
- **What is measured.**
  - Slouch: a smoothed nose height that falls below the lowest nose height recorded during calibration.
  - Forward head ("turtle neck", added in v1.5.1): the face-box width relative to calibration [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L548-L589), [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L295).
- **Feedback.**
  - Warning styles: progressive screen blur (default, via a private CoreGraphics API, with an `NSVisualEffectView` "Compatibility mode"), glow (a red vignette), border, solid colour, or none [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Core/Models.swift#L129-L135), [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/README.md#L114).
  - Menu-bar icons for good, bad, away, paused and calibrating [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L285).
  - A local analytics dashboard with a daily score, a 7-day trend, slouch count and slouch duration [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L392-L399).
- **Privacy.** The privacy policy (dated 2026-02-16) says Dorso does "not collect, store, or transmit any personal data", contains no analytics, and "does not connect to the internet" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/PRIVACY.md#L3-L36). However, since v1.14.0 (2026-07-19), GitHub builds include Sparkle auto-update, which checks for new versions in the background [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L35), [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Package.swift#L14-L15). The "no network" statement is therefore out of date for direct-download builds.
- **CPU and battery.**
  - The developer reported ~14% CPU at 10 fps, ~8% at 4 fps and ~7% at 2 fps (v1.4.7). Those figures were measured at 352×288, on unspecified hardware [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L324-L334).
  - v1.5.10 says "Reduced CPU usage by skipping unnecessary work when posture is good", after a user reported high CPU usage in AirPods mode [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L228-L231).
  - "Pause on battery" was added in v1.13.0 [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L43).
- **AirPods mode [code].** Reads `CMHeadphoneMotionManager` attitude. Only pitch is evaluated, and only in the forward or down direction; roll and yaw are stored at calibration but not judged [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/AirPodsPostureDetector.swift#L430-L486). Thresholds are listed in section 4.

**PostureBar (bogumat/posturebar).** Brand-new: every commit visible in the history is from 2026-09-03. It is a single-developer project and is not notarized.
- **Platform.** macOS 13 or later; supports Apple Silicon and Intel; ships as a universal ZIP. Users must allow it under "Open Anyway" because it is not notarized [repo-docs](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/README.md#L15-L29). It is free and open source.
- **Sensing [code].** Uses only `VNDetectFaceRectanglesRequest` on the largest face (confidence ≥ 0.30). The features are face midY and √(width×height) [code](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/Sources/PostureBar/PoseDetector.swift#L5-L29). It makes 5 checks per second on low-resolution frames [repo-docs](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/README.md#L7-L11).
- **README framing.** "A face moving lower is the main slouch signal, while a face becoming larger (moving closer) is a secondary signal". It describes itself as "a relative posture reminder, not an ergonomic or medical assessment" [repo-docs](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/README.md#L42-L51).
- **Feedback.** A green tick or red spiral in the menu bar, a one-hour posture history graph, and a buzzer sound after sustained slouching [repo-docs](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/README.md#L1-L11).
- **Privacy and camera.** No uploads and no saved frames. It "releases the camera when another app uses the microphone or camera", which covers calls [repo-docs](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/README.md#L69-L70).

**PostureFix (adnanakil/PostureFix).** Created 2026-08-05. One developer, MIT-licensed. No adoption evidence was found.
- **Two implementations.**
  - A native SwiftUI app using Apple Vision body pose, with Vision's `.neck` joint as a C7 proxy. Requires macOS 14+ [repo-docs](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/README.md#L20-L34), [code](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/swift-app/Sources/PostureFix/PoseEstimator.swift#L21-L55).
  - A Python engine using MediaPipe, with optional skin stickers and lens calibration.
- **Camera placement.** The user must sit side-on to the camera (sagittal view) [repo-docs](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/README.md#L68-L76).
- **Metrics** [repo-docs](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/README.md#L114-L134):
  - Craniovertebral angle (CVA).
  - Neck flexion.
  - Head-forward distance (ear-to-C7 offset ÷ trunk length).
  - Trunk lean.
  - Spine bend (from stickers).
  - Shoulder protraction.
- **Marketing language.** The README claims "Hyper-accurate" tracking and "clinical-grade spine tracking" with stickers [repo-docs](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/README.md#L6-L9). These claims have not been validated.
- **Privacy.** "No networking code at all"; frames are analysed in memory [repo-docs](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/README.md#L176-L182). The only exception is an optional one-time script that generates a TTS voice bank through the Gemini API [repo-docs](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/README.md#L43-L56).

#### 1b. macOS camera apps, closed source (listing and press only)

**SitApp: Posture Reminder.** On the Mac App Store as id6768987893, and also on Windows.
- **Requirements.** "macOS 12.0 or later and a Mac with Apple M1 chip or later" [ss: App Store](https://apps.apple.com/us/app/sitapp-posture-reminder/id6768987893?mt=12).
- **Price.** Free for up to 60 minutes a day. Pro in-app purchases cost $3.99, $34.99 or $89.99 [ss: App Store](https://apps.apple.com/us/app/sitapp-posture-reminder/id6768987893?mt=12).
- **Method [listing].** A personal "Droid": the user shows "your best posture and worst slouch" and the app "builds a personal model that knows the difference". This is a per-user trained classifier [ss: App Store](https://apps.apple.com/us/app/sitapp-posture-reminder/id6768987893?mt=12).
- **Features [listing].** "Gentle customizable nudges", break reminders, multi-monitor support, and daily and weekly summaries [ss: App Store](https://apps.apple.com/us/app/sitapp-posture-reminder/id6768987893?mt=12).
- **Privacy [listing].** Every frame is processed locally: "no frames are uploaded, no screenshots, and no biometrics are sent to a server" [ss: App Store](https://apps.apple.com/us/app/sitapp-posture-reminder/id6768987893?mt=12).
- **History.** Originally launched in 2021. It was relaunched on Product Hunt on 2026-03-31, when "M1 support has now landed" [ss: Product Hunt](https://www.producthunt.com/products/sitapp?launch=sitapp).
- **Reviews.** PCWorld: free, gives a percentage posture score, works for sitting and standing desks, starts and stops with a click, and computes everything locally [ss: PCWorld](https://www.pcworld.com/article/2905862/this-free-app-fixed-my-posture-and-stopped-my-backaches.html). Digital Trends: you calibrate "good posture and poor posture poses"; the app also detects "custom posture sins" and pops up in the corner [ss: Digital Trends](https://digitaltrends.com/computing/i-fixed-my-back-sitapp/).
- **Ratings.** The App Store showed too few ratings to display an average [ss: App Store](https://apps.apple.com/us/app/sitapp-posture-reminder/id6768987893?mt=12).

**Nekoze.** On the Mac App Store as id627505674, by Katsuma Tanaka. Free.
- **Method.** Uses face recognition to judge hunching and sits in the menu bar as a cat-head icon. Alerts are on-screen plus a meowing sound. Strictness is adjustable. Requires macOS Monterey or later. The developer states it collects no data [ss: App Store](https://apps.apple.com/us/app/nekoze/id627505674?mt=12), [ss: AddictiveTips](https://www.addictivetips.com/mac-os/nekoze-mac-monitors-posture-alerts-when-you-start-to-slouch/).
- **How it decides.** "Facial tracking: when … your face position exceeds the normal movement range" it flags bad posture. Sensitivity and detection frequency are configurable; the strictest setting alerts "almost every three seconds" for slight movement. It depends heavily on lighting, and the Start button is greyed out when no face is recognised [ss: Waerfa](https://www.waerfa.com/nekoze), [ss: sspai](https://sspai.com/post/31483), [ss: Lifehacker JP 2013](https://www.lifehacker.jp/article/130509macnekoze/).
- **Age.** Lifehacker JP covered it on 2013-05-09 and 2015-07-13 (dates from the URL slugs) [ss](https://www.lifehacker.jp/article/150713_mac_nekoze/). This is an old app, but its current listing requires macOS 12, so it was rebuilt at some point.

**SitWit – Posture & Breaks (formerly "MacPosture" and apparently "HLTH").** Mac App Store id1503879351.
- **Name history.** The same id appears under the URL slugs `posture-monitoring-macposture` and `hlth-posture-break-reminders` [ss: App Store](https://apps.apple.com/us/app/posture-monitoring-macposture/id1503879351?mt=12), [ss: App Store](https://apps.apple.com/us/app/hlth-posture-break-reminders/id1503879351?mt=12).
- **Method [listing].** Uses the webcam to "send real-time notifications to adjust when you lean too far forward or backward". Includes a Pomodoro timer (by default, a 5-minute break every 25 minutes), posture scores and 7-day trends. Free with in-app purchases [ss: App Store](https://apps.apple.com/app/apple-store/id1503879351).
- **MacPosture description.** A menu-bar posture score and suggestions "such as to move further away from the screen". Premium adds a week of statistics and customisable break reminders [ss: Softpedia](https://mac.softpedia.com/get/Utilities/MacPosture.shtml).

**SlouchSniper.** Distributed through the Setapp subscription.
- **Method [listing].** Set the camera to show head and shoulders and run "a quick calibration"; then "the AI should recognize your ideal alignment".
- **Feedback.** "It gently dims your screen the moment you slouch and brightens back up as soon as you correct your position."
- **Controls.** A mode with less frequent notifications, or a "slouch alert delay" slider.
- **Other.** A graph of posture through the day, on-device analysis, and macOS 12.0+ [ss: Setapp](https://setapp.com/apps/slouchsniper).

**Posture Monitor.** Mac App Store id6751619063, $4.99.
- **Claims [listing].** "Advanced 3D human body pose detection" with the built-in camera, menu-bar status, and adjustable sensitivity, reminder frequency and performance settings. Processing is local. Requires macOS 14.0+ [ss: App Store](https://apps.apple.com/us/app/posture-monitor/id6751619063?mt=12).
- **Not verified:** the developer, the actual algorithm, and whether it runs on Intel.

#### 1c. AirPods / headphone IMU (head pitch)

**Posture Pal (Jordi Bruin).**
- **History.** Launched on iOS in 2022 [press: 9to5Mac 2022-03-17](https://9to5mac.com/2022/03/17/posture-pal-iphone-app-airpods/). The Mac app followed once Apple exposed the headphone-motion APIs in macOS Sonoma [ss: Cult of Mac](https://www.cultofmac.com/reviews/posture-pal-use-airpods-to-improve-posture-awesome-apps), [ss: iThinkDiff](https://www.ithinkdiff.com/airpods-correct-posture-with-posture-pal-macos/).
- **Method.** Uses the same motion data as Spatial Audio. If "the head is tilted excessively forward or backward" it sends a reminder [ss: iThinkDiff](https://www.ithinkdiff.com/airpods-correct-posture-with-posture-pal-macos/).
- **Headphones.** AirPods (3rd generation), AirPods Pro, AirPods Max and Beats Fit Pro [ss: App Store](https://apps.apple.com/us/app/posture-pal-improve-alert/id1590316152).
- **Mac app [ss: Cult of Mac](https://www.cultofmac.com/reviews/posture-pal-use-airpods-to-improve-posture-awesome-apps).** A cartoon giraffe ("Rafi"), monkey or alpaca pops up at the left, right or middle of the screen. There are three sensitivity levels. The free version runs for 10 minutes at a time; a one-time $4.99 purchase removes the limit.
- **iOS app.** Visual, sound and phone-vibration alerts. Rated 4.4/5 from 293 ratings at the time of the search [ss: App Store](https://apps.apple.com/us/app/posture-pal-improve-alert/id1590316152).
- A Macwelt test also exists [press](https://www.macwelt.de/article/2095820/posture-pal-test.html); it was not retrieved.

**SitTall.** A native Mac menu-bar app [listing: hunted.space](https://hunted.space/product/sittall-fix-your-posture).
- **Method.** AirPods motion sensors with "no camera"; it "calibrates in two taps (sit up straight, slouch, done)" and "nudges you when bad posture persists".
- **Price and requirements.** $6 one-time; macOS 14+; AirPods Pro 2 or AirPods 4 ANC.
- **Marketing claim.** "6-axis motion sensor running 60 times a second".

**AirPosture (allenv0/AirPosture).**
- **Platform and status.** An iOS app; the README shows macOS mock-ups as future plans. Open-sourced, and the author describes the project as "currently on hold" [repo-docs](https://github.com/allenv0/AirPosture/blob/31780ce1968fd2a8bc117eff29a470b701ebc2dc/README.md#L16-L33). The last commit is from 2026-09-22.
- **Usage claim.** "Used in over 100,000 sessions" [repo-docs](https://github.com/allenv0/AirPosture/blob/31780ce1968fd2a8bc117eff29a470b701ebc2dc/README.md#L33).
- **Copycat warning.** The author warns about "unofficial 'AirPosture' apps with aggressive paywalls" [repo-docs](https://github.com/allenv0/AirPosture/blob/31780ce1968fd2a8bc117eff29a470b701ebc2dc/README.md#L42-L44). Softpedia lists an "AirPosture For Mac" [ss](https://mac.softpedia.com/get/Utilities/AirPosture.shtml); its relationship to this project is unverified.

**Dorso AirPods mode.** Described above, with thresholds in section 4.

#### 1d. Body-worn IMU wearables

**Upright GO 2 / Upright GO S (Upright Technologies, now DarioHealth).** Still sold, and the app is maintained.
- **Company.** Upright Technologies' status is "acquired" [ss: startupim](https://startupim.com/company/upright-pose/raw). The Android app is published by "dariohealth-corp"; version 3.0.19 was released on 2026-07-29 [ss: APKMirror](https://www.apkmirror.com/apk/dariohealth-corp/upright/upright-3-0-19-release/).
- **Product.** A sensor stuck on the upper back with adhesive, or worn on a necklace accessory. The GO S is a newer, smaller sensor [press: iTWire](https://itwire.com/your-it-news/home-it/don-t-be-uptight-about-bad-posture,-assume-a-great-posture-with-the-upright-go-2-and-upright-go-s), [press: AppleInsider 2021-05-01](https://appleinsider.com/articles/21/05/01/review-upright-go-2-tells-you-to-sit-up-straight-for-better-posture).
- **App behaviour [ss: T3](https://www.t3.com/reviews/upright-go-2-posture-corrector), [ss: TechRadar](https://www.techradar.com/reviews/upright-go-2-review).**
  - Calibration is a button on the home screen.
  - Vibration patterns are selectable, and there is a vibration delay of 10, 15 or 20 seconds.
  - **Training mode:** a daily target of sustained good posture that lengthens over time; the device vibrates on each slouch.
  - **Tracking mode:** no vibration, recording only.

**Lumo Lift (Lumo BodyTech).** **Discontinued; the company is closed** [ss: Craft.co](https://craft.co/lumo-bodytech). All the information below is from roughly 2014–2016 reviews.
- **Hardware.** A clip-on sensor below the collarbone.
- **Calibration.** You calibrate every time you put it on, by tapping it twice.
- **Coaching sessions.** 5 minutes, 15 minutes, 1 hour or 4 hours.
- **Coach personas and their buzz delays.** "Drill Sergeant" waits 3–30 s; "Mom" waits 1–3 minutes; "Grandmother" waits 4–10 minutes.
- **Reception.** Some reviewers found it "too sensitive and intrusive".
- Sources: [ss: Wareable](https://www.wareable.com/fitness-trackers/lumo-lift-review), [ss: Gear Patrol](https://www.gearpatrol.com/?p=309314), [ss: GearBrain](https://www.gearbrain.com/lumo-lift-posture-wearable-review-1714311431.html).

#### 1e. Windows, cross-platform and browser

**PostureMinder (PostureMinder Ltd, UK).** Windows 7/10/11 shareware; version 4.2 is listed. Current maintenance is unknown.
- **Method.** "Stores a reference picture of the computer user's normal posture and then continually checks to see if the person starts to slump or lean", checking "every few seconds".
- **When it reminds.** When the user sits "in a damaging posture for an extended period, or spend[s] too much time sitting in any position without moving sufficiently" [ss: FreeDownloadManager](https://en.freedownloadmanager.org/Windows-PC/PostureMinder.html), [ss: HSM](https://www.hsmsearch.com/?p=1590).

**BatesPosture (wtbates99/batesposture).** A Python and MediaPipe tray app; the last commit is from 2026-08-09.
- **Method.** "Seven weighted pose metrics" produce a 0–100 score. A "six-second baseline" calibration is used, and away time is auto-paused [repo-docs](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/README.md#L27-L34).
- **Licence.** PolyForm Noncommercial [repo-docs](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/README.md#L125).

**Posture!Posture!Posture! (Chrome/Firefox extension; killa-kyle).** Repository history runs from 2021-11 to 2024-11-14 (last commit), so the project is likely dormant.
- **Method.** Uses TensorFlow.js MoveNet. It takes "a baseline of you sitting with good posture" and then blurs web pages "when you start to deviate" [repo-docs](https://github.com/killa-kyle/posture-posture-posture-chrome-extension/blob/778dae27025c6947dcdc5bee46c43b8eb59d908d/README.md#L3-L5), [repo-docs](https://github.com/killa-kyle/posture-posture-posture-chrome-extension/blob/778dae27025c6947dcdc5bee46c43b8eb59d908d/README.md#L18-L29).

**"Fix Posture" (Olesya Chernyavskaya; web experiment, older and undated).**
- **Method.** TensorFlow.js PoseNet. It considers "the tilt of your eyes, the relationship between your eyes, shoulders, and the horizon, and the intrusion of any foreign objects like a knee or foot", then blurs the entire page.
- **Scope.** A demo on its homepage only, accompanied by design notes on its successes and shortcomings [ss: PC Gamer](https://pcgamer.com/this-site-goes-blurry-if-your-posture-sucks), [ss: Lifehacker.ru](https://lifehacker.ru/fix-posture/).

**SlouchDetector (Alexander Kranga; in-browser).**
- **Method.** MediaPipe face detection establishes "your reference position when you're sitting properly" and then monitors deviations. It uses the face only, not the 33-point body pose.
- **Stack.** Next.js 15 and React 19; runs locally in the browser [ss: Korben](https://korben.info/en/slouchdetector-webcam-posture-reminder.html).

**Side-view MediaPipe script (shamiul5201/sitting-posture-analysis, 2024-11; LearnOpenCV-style).** A Streamlit app that needs a side view and measures neck and torso inclination. Its threshold sliders are given in section 4 [code](https://github.com/shamiul5201/sitting-posture-analysis/blob/6a5b09fb4e35e089ec6685c18d981cc9201349bc/sittiing_pose_analysis.py#L198-L206).

**FixPosture (MyWorldRules; Windows; last commit 2021-02-11; unmaintained).** An OpenCV Haar-cascade face detector compared against an averaged baseline, with `win10toast` notifications [repo-docs](https://github.com/MyWorldRules/FixPosture/blob/4651b926bc15b80de0055f9ea70d4b335029b535/README.md#L13-L20).

#### 1f. Names that surfaced but could not be examined
- **Zen.** Appears on Product Hunt as a posture-category competitor [ss](https://www.producthunt.com/products/zen-2/alternatives).
- **Other webcam products:** SitSense [ss](https://www.producthunt.com/products/sitsense), PostureGuard, SuperShrimp, Straighty.app, Zesture, Shisei and NoSlouch.
- **Other App Store listings:** Posture Reminder AI (Mac, id1574005886) [ss](https://apps.apple.com/us/app/ai-posture-reminder-app/id1574005886?mt=12) and PodPosture (AirPods, iOS) [ss](https://apps.apple.com/us/app/podposture-posture-improver/id1550684595).
- **Browser:** the PostureCorrector Chrome extension.
- **Linux:** a Posturr port called "Postured", mentioned in the Hacker News thread [ss](https://news.ycombinator.com/item?id=46754944).

### Inferences
- **The dominant signal for an above-display camera is relative vertical head position plus head size versus the user's own baseline.** Dorso, PostureBar, Nekoze, SlouchDetector, the Chrome extension, FixPosture (2021), PostureMinder and probably SitWit all work this way. Skeleton angle metrics such as CVA, neck inclination and trunk lean appear only in tools that require a **side view** (PostureFix, the LearnOpenCV-style script). That camera geometry is not available from an iMac's built-in camera above the display.
- **Which tools fit the user's setup (Intel iMac, macOS 14, built-in camera).** Dorso and PostureBar ship universal binaries; SitApp explicitly requires an M1 or later; Posture Monitor and Nekoze state no architecture in what was found. Dorso's AirPods mode is part of the same universal binary, so it presumably runs on an Intel Mac with macOS 14. This is untested.
- **No inspected product judges left–right asymmetry (head roll or yaw, shoulder tilt) against a personal baseline, as the user's current app does with roll and yaw.**
  - Dorso, PostureBar, Posture Pal and SitTall judge only one sagittal direction: dropping, leaning in, or pitching down.
  - Symmetry-enforcing metrics appear only in BatesPosture (shoulder level, head side tilt) and in "Fix Posture" (eye tilt and the eye–shoulder–horizon relationship). Those are exactly the kinds of rules the user wants to avoid before a diagnosis.
- **Wearables measure trunk tilt directly**, which no camera can do from the front.
  - Upright GO is still sold but phone-centric (DarioHealth app).
  - Lumo Lift is gone.
  - Neither has a macOS client, so both are only reference points for how hold times and calibration were designed.

### Gaps
- App Store pages (exact current prices, versions, update dates, ratings, review text), Hacker News comments and Reddit threads could not be fetched (egress blocked). Their content is known only through search summaries.
- The web-search budget ran out before checking: Zen, SitSense, PostureGuard, SuperShrimp, Straighty, Zesture, Shisei, Posture Reminder AI, NAMU "Alex" and other neck wearables, PostureMinder's current status, the SitApp developer's identity, the Posture Monitor developer and algorithm, and the Nekoze and Posture Pal Mac architecture requirements.
- Posture Pal's calibration procedure (an explicit "sit straight" calibration, or an automatic reference) was not found.
- No reliable independent CPU or battery measurements exist for any commercial app, and none at all for Intel Macs.

## 2. Calibration: calibration pose, automatic calibration, or absolute thresholds? How are chair, monitor and camera changes handled?

### Takeaway
Nearly every product calibrates to the individual user. The most common method is a single user-triggered "sit up straight" snapshot. A minority record both a good and a slouched example and set a threshold between them (SitTall, AirPosture) or train a personal classifier (SitApp). One app auto-captures a baseline when the user is stable (PostureBar). Absolute or population thresholds appear only in side-view tools: as hand-tuned angle limits, or as a "clinical floor" layered on top of a personal baseline (PostureFix's CVA < 50°). Changes to the workspace are handled by asking the user to recalibrate. Dorso goes further, keying calibration profiles to the display set and camera. PostureFix detects chair moves (a sustained >15% change in trunk length) and prompts. No product was found that auto-builds a baseline by filtering samples through population thresholds (the user's option C).

### Cited Findings

**Single "good posture" reference, triggered by the user**
- **Dorso, camera mode [code].**
  - The calibration window steps the user through looking at the top-left, top-right, bottom-right and bottom-left corners of every screen ("Look at the ring and tap Space") while seated upright [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/UI/CalibrationWindow.swift#L304-L311).
  - From the samples (at least 4), goodY = max nose Y, badY = min nose Y, range = max − min, and neutralFaceWidth = the maximum face width [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L247-L279).
  - Using the maximum face width rather than the average fixed false positives immediately after calibration (v1.5.6) [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L254).
- **Dorso, AirPods mode [code].** Calibration is the mean pitch, roll and yaw over the calibration samples [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/AirPodsPostureDetector.swift#L430-L442).
- **Chrome extension [code].** The baseline is the right-eye Y position from the first detected pose after starting, or after the "Reset the 'Good Posture' position" button [code](https://github.com/killa-kyle/posture-posture-posture-chrome-extension/blob/778dae27025c6947dcdc5bee46c43b8eb59d908d/src/pages/Options/Options.tsx#L123-L161).
- **BatesPosture [code].** Over 6 s it averages the posture score, neck angle and shoulder vertical delta [code](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/batesposture/ui/onboarding.py#L101-L106). The dashboard then uses baseline neck angle + 5° and baseline shoulder level + 0.02 as thresholds [code](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/batesposture/ui/dashboard.py#L393-L394).
- **PostureFix [repo-docs].** A countdown (default 5 s) is followed by "hold your best posture for 5 seconds". The baseline is captured when the countdown expires, "not when you press the key", so it reflects the user seated rather than leaning to the keyboard [repo-docs](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/README.md#L68-L76).
  - The Swift app also allows "Use this frame as baseline" after the user has hand-corrected anchor points [repo-docs](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/README.md#L36-L41).
- **PostureMinder.** Stores "a reference picture of … normal posture" [ss](https://en.freedownloadmanager.org/Windows-PC/PostureMinder.html).
- **SlouchSniper.** "Quick calibration" with head and shoulders in view [ss](https://setapp.com/apps/slouchsniper).
- **SlouchDetector.** Reference taken "when you're sitting properly" [ss](https://korben.info/en/slouchdetector-webcam-posture-reminder.html).
- **Wearables.** Upright GO uses an in-app calibrate button [ss](https://www.t3.com/reviews/upright-go-2-posture-corrector). Lumo Lift is recalibrated with a double tap every time it is put on [ss](https://www.wareable.com/fitness-trackers/lumo-lift-review).

**Good and bad examples, giving a personal threshold or classifier**
- **AirPosture [code].** Records 5 s of good posture, then a 3 s transition, then 5 s of slouching. The threshold is the midpoint of the two mean pitches, clamped to [−35°, −5°] [code](https://github.com/allenv0/AirPosture/blob/31780ce1968fd2a8bc117eff29a470b701ebc2dc/AirPostureCore/Sources/AirPostureCore/AirPostureTracker.swift#L330-L357).
- **SitTall [listing].** "Sit up straight, slouch, done" [ss](https://hunted.space/product/sittall-fix-your-posture).
- **SitApp [listing].** "Show it your best posture and worst slouch, and it builds a personal model" [ss](https://apps.apple.com/us/app/sitapp-posture-reminder/id6768987893?mt=12).

**Automatic calibration**
- **PostureBar [code].**
  - On first launch, the user sits upright "for about four seconds" [repo-docs](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/README.md#L32-L36).
  - In code, it collects 20 plausible samples whose face-Y range is ≤ 0.035 and face-size range is ≤ 0.025 (normalized), with no gap longer than 0.75 s. Any instability restarts the window "to avoid mixing two different seated positions into one baseline".
  - The baseline is the median, with dispersion = MAD × 1.4826 capped at 0.015 (Y) and 0.0125 (size) [code](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/Sources/PostureBar/PostureClassifier.swift#L21-L27), [code](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/Sources/PostureBar/PostureClassifier.swift#L117-L204).
- **Dorso (source switching, not re-calibration).** "Automatic tracking mode" switches between camera and AirPods based on availability [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L115).

**Absolute or population thresholds**
- **Side-view script [code].** Neck inclination must lie between −5° and +35°, and torso inclination between −5° and +10°. A code comment says: "The threshold angles have been set based on intuition" [code](https://github.com/shamiul5201/sitting-posture-analysis/blob/6a5b09fb4e35e089ec6685c18d981cc9201349bc/sittiing_pose_analysis.py#L198-L206), [code](https://github.com/shamiul5201/sitting-posture-analysis/blob/6a5b09fb4e35e089ec6685c18d981cc9201349bc/sittiing_pose_analysis.py#L340-L341).
- **PostureFix hybrid [code].** Scoring is deviation from the personal baseline, plus an absolute floor: "CVA < 50 flags even against a bad baseline" (badness is forced to at least 0.6) [code](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/swift-app/Sources/PostureFix/Metrics.swift#L185-L215). The README calls ~50° "the standard clinical threshold for forward head posture" [repo-docs](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/README.md#L114-L130).
- **BatesPosture hybrid [code].** Scores against ideal geometry: neck vector vs vertical, normalized by 45°; shoulder-level and head-tilt scaling constants. A personal calibration is layered on top [code](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/batesposture/services/settings_service.py#L116-L120), [code](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/batesposture/ml/pose_detector.py#L205-L257).

**Handling chair, monitor and camera changes**
- **Dorso [repo-docs].** "Each unique monitor setup has its own calibration profile", keyed by the sorted UUIDs of connected displays. "Calibration is camera-specific. Changing cameras requires recalibration." A display setup without a profile pauses with "Calibration needed" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/PROFILES.md#L1-L49), [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/PROFILES.md#L78).
  - Separate "Settings Profiles" (for example Work, Home, Standing Desk) store sensitivity settings [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L218).
- **PostureBar [repo-docs].** "Keep the camera position fixed and recalibrate after moving the camera, chair, or desk" (manual). A camera chosen from the menu is remembered [repo-docs](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/README.md#L38-L51).
- **PostureFix [repo-docs].** Normalizes by a "running median trunk length". "A sustained trunk-length change beyond 15% triggers a 'chair moved?' prompt."
  - The Python engine also compensates for camera bumps using a background-feature similarity transform. It goes "sticky-broken" rather than guessing when tracking is lost [repo-docs](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/README.md#L124-L150).
- **Nekoze.** If detection fails, users are told to move the light or reposition the Mac [ss](https://www.waerfa.com/nekoze).

### Inferences
- **Dorso's corner calibration is a deliberate design.** It defines "acceptable" as the range of head heights seen while the user looks around the whole screen. The slouch threshold is therefore "lower than when looking at the bottom corner", which tolerates normal gaze changes. Glances at the keyboard below the screen still fall outside that range, which is why Dorso later added an onset delay (section 3).
- **PostureBar's stability-gated auto-calibration is the closest existing analogue to the user's option C, but it gates on stillness, not on population ergonomic thresholds.** No product found checks that the baseline itself is ergonomically "good". PostureFix's absolute CVA floor addresses the related risk of a bad baseline hiding a bad posture, but only in a side view.
- **Two-pose calibration (good plus deliberate slouch) is the common way to set a personal threshold without population norms** (SitTall, AirPosture, SitApp). For a user who must not be pushed toward any particular correction, a "deliberate slouch" sample defines direction only in the sagittal plane. That is compatible with the constraint as long as no lateral sample is requested (inference).
- **Recalibration triggers in practice:** a display-set change (Dorso), a camera change (Dorso), a trunk-length or scale change (PostureFix), or user instruction (PostureBar, Nekoze). A face-size jump is a cheap proxy for "chair moved" with a frontal camera (inference by analogy with PostureFix's trunk-length rule).

### Gaps
- The calibration details of SitApp's classifier (number of samples, features, retraining), SlouchSniper ("the AI should recognize your ideal alignment") and Posture Pal are unknown.
- No product was found that classifies against a generic posture library (the user's option B) rather than the user's own examples.

## 3. How products limit false alarms and nagging (hold time, smoothing, dead zones, cooldowns, schedules, gentle feedback), with default values

### Takeaway
Products stack several layers:
- smoothing (moving average or EMA);
- debouncing (N consecutive readings);
- a dead zone or hysteresis band;
- a hold or onset delay before alerting;
- a cooldown or progressive escalation after the first alert;
- automatic pausing (screen lock, calls, battery, away from desk, AirPods removed).

Default hold times are short in camera apps: 0 s plus about a 1–2 s debounce (Dorso), 5 s (AirPosture, side-view script), 10 s (PostureBar), 12 s (PostureFix). Wearables used longer, user-selectable delays: Upright 10–20 s; Lumo Lift from 3–30 s up to 4–10 minutes. Ambient, non-modal feedback is common: blur, dimming, a coloured glow or border, a menu-bar icon, a cartoon character, or a progressively louder buzzer.

### Cited Findings

**Dorso (camera) [code].**
- Smoothing: a 5-sample moving average of nose Y [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L122-L126), [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L540-L546).
- Hysteresis: the exit threshold is 0.7× the entry threshold [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L551-L559).
- Debounce: 8 consecutive bad readings to enter slouching; 5 consecutive good readings to exit. Any single good reading resets the bad counter and zeroes the warning intensity, so the blur clears instantly [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Core/PostureEngine.swift#L22-L28), [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Core/PostureEngine.swift#L199-L238).
- Warning onset delay: a slider from 0 to 30 s, default 0 [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/UI/SettingsWindow.swift#L448-L455), [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Settings/SettingsProfiles.swift#L45-L47). It was added in v1.3.0 so users can make "brief glances at keyboard without triggering warning" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L404-L408).
- Dead zone: the options are 0, 0.08, 0.15, 0.25 and 0.40 of the calibrated range (labelled Strict to Loose); the default is 0.03.
- Intensity: the options are 0.08, 0.15, 0.35, 0.65 and 1.2 (labelled Gentle to Aggressive); the default is 1.0. Warning strength = severity^(1/intensity) [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/UI/SettingsWindow.swift#L58-L62), [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Core/PostureEngine.swift#L222-L227).
- Documentation drift: the README still calls these controls "Sensitivity (5 levels from Low to Very High)" and "Dead Zone (None to Very Large)" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/README.md#L84-L85).
- Frame rate: 2, 4 or 10 fps; the default is Balanced (4 fps). Sampling boosts to 10 fps (0.1 s interval) once a bad reading occurs, "for quicker recovery detection" [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Core/Models.swift#L160-L170), [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Settings/SettingsProfiles.swift#L77), [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L128-L135).
- Auto-pauses:
  - Screen lock. This "addresses privacy concern: webcam light now turns off when computer is locked" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L413-L417).
  - "Pause on the go" (laptop display only) and "Blur when away" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/README.md#L84-L88).
  - Pause on battery [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L43).
- A global toggle hotkey (⌃⌥P) [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L348).
- An "away" state after 15 consecutive frames with no detection [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L137-L143).
- Changelog history of these controls:
  - Border and vignette styles were added because a user suggested "the screen border alternative to blur" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L430-L444).
  - The dead-zone range was widened to 0–40% "for more noticeable impact between settings" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L422-L427).
  - "Fixed backwards math where 'high sensitivity' was actually less responsive" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L455).

**Dorso (AirPods) [code].** Only a forward or down pitch counts. "Leaning back … is ignored (e.g., stretching)" [code](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/AirPodsPostureDetector.swift#L468-L486), [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L311). Monitoring pauses automatically when the AirPods are removed [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/README.md#L108-L112).

**PostureBar [code].**
- Smoothing: an EMA (0.55 × new + 0.45 × previous).
- Entry: 3 consecutive smoothed scores ≥ 1.0. Exit: 3 consecutive scores ≤ 0.55, giving a hysteresis band of 0.55–1.0 [code](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/Sources/PostureBar/PostureClassifier.swift#L74-L101).
- Buzzer delay: 1, 2, 5, 10, 20, 30 or 60 s; default 10 s.
- Volume: in "Progressive" mode the volume rises from 5% to 90% by 120 s of continuous slouching (eased with an exponent of 1.35). A beep sounds every 5 s. "Constant (Maximum)" is optional [code](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/Sources/PostureBar/PostureAlertPolicy.swift#L3-L78), [repo-docs](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/README.md#L63-L67).
- Sound can be muted without pausing monitoring.
- The camera is released during calls [repo-docs](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/README.md#L63-L70).

**PostureFix [code].**
- Notification after bad posture lasting more than 12 s, with a 60 s cooldown.
- **Stillness alert:** if the ear moves no more than 25 px for 20 minutes, it shows "You've been still a long time – stand up and move for a minute", with a 10-minute cooldown [code](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/swift-app/Sources/PostureFix/PostureEngine.swift#L479-L509). The Python engine has the same defaults [code](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/posturefix/alerts.py#L11-L21), [code](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/posturefix/alerts.py#L71-L103).
- **Live coach:** "one cue at a time, bottom-up"; at least 3.5 s between cues; the same cue repeats only after 9 s; per-segment enter/exit hysteresis (for example the head: 6° to enter, 4° to exit). The stated goal: "pacing gaps stop machine-gun nagging" [code](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/swift-app/Sources/PostureFix/PostureEngine.swift#L405-L438).

**AirPosture [code].**
- A low-pass filter with factor 0.4 on pitch [code](https://github.com/allenv0/AirPosture/blob/31780ce1968fd2a8bc117eff29a470b701ebc2dc/AirPostureCore/Sources/AirPostureCore/Types.swift#L14-L23).
- Notification delay options: "Immediate", 2 s ("filter momentary slouches"), 5 s ("Balanced"), 30 s ("Only notify for sustained poor posture") and 60 s ("Minimal interruptions") [code](https://github.com/allenv0/AirPosture/blob/31780ce1968fd2a8bc117eff29a470b701ebc2dc/AirPostureApp/NotificationSettingsComponents.swift#L300-L306).
- Constants: default realtime notification delay 5 s; haptic feedback delay 5 s; recovery duration 5 s; grace period 30 s; bad-posture notice threshold 10 s [code](https://github.com/allenv0/AirPosture/blob/31780ce1968fd2a8bc117eff29a470b701ebc2dc/AirPostureApp/Shared/MotionConstants.swift#L4-L18).

**BatesPosture [code].**
- A posture notification when the score is below 60, with a cooldown of 300 s.
- A separate **trend alert**: "Posture Trending Down" fires when the mean score over the last 60 s is at least 12 points below the mean of a 60 s window that ended 240 s ago. It "catches gradual slumps that never cross the absolute threshold", with an independent cooldown [code](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/batesposture/services/notification_service.py#L9-L70), [code](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/batesposture/services/score_service.py#L166-L180).
- Defaults: score threshold 65, poor-posture threshold 60, break reminder every 50 minutes [code](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/batesposture/services/settings_service.py#L29-L36).
- A focus mode suppresses notifications, and interval (non-continuous) tracking is available [repo-docs](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/README.md#L27-L34).

**Side-view script [code].** Alarm after 5 s (a slider from 0 to 20 s).
- A camera-alignment check marks the frame "not aligned" when the nose-to-shoulders offset angle exceeds 30°, so no posture verdict is produced from a bad viewpoint [code](https://github.com/shamiul5201/sitting-posture-analysis/blob/6a5b09fb4e35e089ec6685c18d981cc9201349bc/sittiing_pose_analysis.py#L198-L206), [code](https://github.com/shamiul5201/sitting-posture-analysis/blob/6a5b09fb4e35e089ec6685c18d981cc9201349bc/sittiing_pose_analysis.py#L278-L291), [code](https://github.com/shamiul5201/sitting-posture-analysis/blob/6a5b09fb4e35e089ec6685c18d981cc9201349bc/sittiing_pose_analysis.py#L393).

**Chrome extension [code].** No smoothing, debounce or hold time. Detection runs every 100 ms, and the page blurs or unblurs immediately when the 25 px deviation is crossed in either direction [code](https://github.com/killa-kyle/posture-posture-posture-chrome-extension/blob/778dae27025c6947dcdc5bee46c43b8eb59d908d/src/pages/Options/Options.tsx#L15-L21), [code](https://github.com/killa-kyle/posture-posture-posture-chrome-extension/blob/778dae27025c6947dcdc5bee46c43b8eb59d908d/src/pages/Options/Options.tsx#L136-L157).

**FixPosture (2021) [code].** Checks about every 2 s and shows a toast each time the check fails; there is no hold or cooldown [code](https://github.com/MyWorldRules/FixPosture/blob/4651b926bc15b80de0055f9ea70d4b335029b535/polishedPostureDetection.py#L166-L173).

**Commercial apps.**
- **SlouchSniper:** dims the screen; offers a "less frequent notifications" mode and a slouch-alert-delay slider [ss](https://setapp.com/apps/slouchsniper).
- **SitApp:** "gentle customizable nudges", a corner pop-up, and break reminders [ss](https://apps.apple.com/us/app/sitapp-posture-reminder/id6768987893?mt=12), [ss](https://digitaltrends.com/computing/i-fixed-my-back-sitapp/).
- **Nekoze:** adjustable sensitivity and frequency; the strictest level nags about every 3 s [ss](https://www.waerfa.com/nekoze).
- **Posture Pal:** three sensitivity levels; a cartoon character pops up [ss](https://www.cultofmac.com/reviews/posture-pal-use-airpods-to-improve-posture-awesome-apps).
- **SitWit:** a Pomodoro break schedule (25/5 minutes) [ss](https://apps.apple.com/app/apple-store/id1503879351).
- **Upright GO 2:** vibration delay of 10, 15 or 20 s; a no-vibration Tracking mode [ss](https://www.t3.com/reviews/upright-go-2-posture-corrector).
- **Lumo Lift:** coach delays of 3–30 s, 1–3 minutes or 4–10 minutes; time-boxed coaching sessions from 5 minutes to 4 hours [ss](https://www.wareable.com/fitness-trackers/lumo-lift-review).
- **PostureMinder:** reminds only for "an extended period" in a damaging posture, or after too long without movement [ss](https://en.freedownloadmanager.org/Windows-PC/PostureMinder.html).

### Inferences
- **The user's current 90 s hold at 1 fps is far more conservative than any camera product's default** (0–12 s). It is comparable to Lumo Lift's mid-level "Mom" coach (1–3 minutes). Products with short holds compensate with gentle, instantly reversible feedback: a blur or dim that clears on the first good reading, or a slowly rising buzzer volume. A long hold with a discrete notification is a different design point: it trades responsiveness for less nagging.
- **Patterns repeated across independent projects:**
  - Enter/exit hysteresis (Dorso 0.7×; PostureBar 1.0 vs 0.55; PostureFix 6°/4°).
  - A short consecutive-readings debounce: 3 readings (PostureBar) or 8 (Dorso).
  - A cooldown after an alert: 60 s (PostureFix), 300 s (BatesPosture), 10 minutes for stillness (PostureFix).
  - Auto-pause when the user is absent, the screen is locked, on battery, or during calls.
- **The user's option D already exists in the open-source examples.**
  - PostureFix's 20-minute stillness alert is purely a duration/stillness signal and is direction-neutral.
  - BatesPosture's trend alert (last 60 s vs a window ~4–5 minutes earlier, ≥ 12 points) detects progressive slumping within a bout without an absolute threshold.
  - PostureMinder (Windows) has long combined both kinds of reminder.
- **Ambient feedback options seen:**
  - blur (Dorso, Chrome extension, Fix Posture);
  - dimming (SlouchSniper);
  - red glow, border or solid fill (Dorso);
  - menu-bar icon colour or shape (Dorso, PostureBar, Nekoze);
  - a mascot pop-up (Posture Pal);
  - a progressive buzzer (PostureBar);
  - haptics (wearables).

  Menu-bar-only state is the least intrusive; blur and dim are the most effective at forcing action but were the most debated (Dorso added non-blur styles at users' request).

### Gaps
- The default delay and frequency values for SitApp, SlouchSniper, Nekoze, Posture Pal, SitTall and SitWit could not be retrieved (listing pages were blocked).
- No published data was found on which hold time or feedback style best reduces annoyance or abandonment.

## 4. Open-source projects: the actual thresholds and algorithms in the code

### Takeaway
The open-source implementations are small, transparent rule systems: nose or face-box height and face size versus a personal baseline, AirPods pitch versus a baseline, or side-view joint angles versus hand-tuned limits. None uses a trained posture classifier. Thresholds are expressed either as fractions of a calibrated range or robust spread (Dorso, PostureBar), as degrees (AirPods tools, side-view tools), or as raw pixels (the Chrome extension and FixPosture). Raw-pixel thresholds are fragile because they change with distance and resolution.

### Cited Findings

**Dorso: camera** ([CameraPostureDetector.swift](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L548-L607); constants in [PostureDetector.swift](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/PostureDetector.swift#L58-L64)) [code]:
- `slouchAmount = badPostureY − smoothedNoseY`. Here badPostureY is the lowest nose Y seen during the four-corner calibration. Vision coordinates have their origin at the bottom, so lower means slouching.
- Bad if `slouchAmount > deadZone × postureRange` (default dead zone 0.03). Exit happens at 0.7× that value.
- Forward head: bad if `faceWidth / neutralFaceWidth > 1 + max(0.05, deadZone)`. Severity reaches full scale at a further +0.15 ratio, and is at least 0.5 when forward head is detected.
- Vertical severity = (slouchAmount − deadZoneThreshold) / (range − deadZoneThreshold), clamped to 0–1. The combined severity is the maximum of the vertical and forward-head severities.
- Face width is only supplied by the face-rectangle fallback path. The body-pose path calls `handleDetection(noseY:)` without a width, so the forward-head check never fires while body pose succeeds ([L482–L489](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L482-L489) vs [L565](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/CameraPostureDetector.swift#L561-L572)). This is a code-reading inference about runtime behaviour.

**Dorso: AirPods** ([AirPodsPostureDetector.swift](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/AirPodsPostureDetector.swift#L271-L280), [L468–L486](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/Sources/Detectors/AirPodsPostureDetector.swift#L468-L486)) [code]:
- The threshold is `0.15 rad (~8.6°) + deadZone × 0.5 rad`. With the default dead zone of 0.03 this is ≈ 0.165 rad ≈ 9.5°.
- Bad only if `pitch − calibratedPitch < −threshold`.
- Severity reaches full scale at 0.3 rad (~17°) beyond the threshold.

**PostureBar** ([PostureClassifier.swift](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/Sources/PostureBar/PostureClassifier.swift#L230-L244)) [code]:
- `score = 0.75 × headDrop / max(0.030, 4 × σY) + 0.25 × sizeIncrease / max(0.025, 4 × σsize)`.
- Only drops and size increases count (`max(0, …)`). σ is the robust spread captured at calibration (MAD × 1.4826, capped).
- Features are the face-box midY and √(w×h) [code](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/Sources/PostureBar/PoseDetector.swift#L23-L29).
- Entry and exit rules are in section 3.

**PostureFix (Swift)** ([Metrics.swift](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/swift-app/Sources/PostureFix/Metrics.swift#L185-L215)) [code]:
- Per-metric "badness" = deviation from the baseline in the worse direction ÷ a full-scale value: CVA 12° (lower is worse), neck flexion 15°, head-forward 0.15 (of trunk length), trunk incline 10°, protraction 0.10.
- `score = 100 × (1 − (0.7 × worst + 0.3 × mean))`. Bad if the score is below 70.
- An absolute floor applies: CVA < 50° forces badness ≥ 0.6.
- Cues prescribe a direction ("head_back", "ribs_back", "pelvis_forward"…) [code](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/swift-app/Sources/PostureFix/PostureEngine.swift#L419-L425).
- Metric descriptions include corrective-exercise advice, for example "Chin tucks + thoracic extension over a foam roller" [code](https://github.com/adnanakil/PostureFix/blob/92738c5214e9a3b8fd116865b6a40b82cd24b984/swift-app/Sources/PostureFix/Metrics.swift#L130).

**AirPosture** ([AirPostureTracker.swift](https://github.com/allenv0/AirPosture/blob/31780ce1968fd2a8bc117eff29a470b701ebc2dc/AirPostureCore/Sources/AirPostureCore/AirPostureTracker.swift#L266-L283), [Types.swift](https://github.com/allenv0/AirPosture/blob/31780ce1968fd2a8bc117eff29a470b701ebc2dc/AirPostureCore/Sources/AirPostureCore/Types.swift#L14-L23)) [code]:
- Pitch is converted to degrees and low-pass filtered: `prev × 0.6 + cur × 0.4`.
- Poor posture if `pitch − offset < threshold`. The default threshold is −22°. Calibration replaces it with the midpoint of the good and bad means, clamped to [−35°, −5°] ([L346–L349](https://github.com/allenv0/AirPosture/blob/31780ce1968fd2a8bc117eff29a470b701ebc2dc/AirPostureCore/Sources/AirPostureCore/AirPostureTracker.swift#L346-L349)).

**BatesPosture** ([pose_detector.py](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/batesposture/ml/pose_detector.py#L205-L257), [settings_service.py](https://github.com/wtbates99/batesposture/blob/fb4f11796e4e99ddafb2551713c7868cb48e5efe/batesposture/services/settings_service.py#L29-L36)) [code]:
- Seven metric scores, each clipped to 0–1, with these weights:

  | Metric | Weight |
  |---|---|
  | Head tilt (nose vs mid-ear depth) | 0.20 |
  | Neck angle vs vertical (scaled by 45°) | 0.20 |
  | Shoulder level | 0.15 |
  | Shoulder roll (depth difference) | 0.15 |
  | Spine alignment | 0.15 |
  | Head rotation (ear distance vs 0.7 × shoulder width) | 0.10 |
  | Head side tilt (ear Y difference × 5) | 0.05 |

- The final score is the weighted sum × 100.

**Posture!Posture!Posture!** ([Options.tsx](https://github.com/killa-kyle/posture-posture-posture-chrome-extension/blob/778dae27025c6947dcdc5bee46c43b8eb59d908d/src/pages/Options/Options.tsx#L15-L66)) [code]:
- MoveNet SinglePose Lightning runs every 100 ms. Keypoint index 2 (the right eye) gives a Y value.
- Bad if `|y − baselineY| > 25` px. This is symmetric (up or down) and has no smoothing.

**Side-view script** ([sittiing_pose_analysis.py](https://github.com/shamiul5201/sitting-posture-analysis/blob/6a5b09fb4e35e089ec6685c18d981cc9201349bc/sittiing_pose_analysis.py#L278-L341)) [code]:
- Neck inclination is the angle of the ear–shoulder line from vertical; torso inclination is the angle of the shoulder–hip line from vertical.
- Good if the neck is within −5° to +35° and the torso within −5° to +10°.
- Alignment check: the offset angle between the nose and shoulders must be ≤ 30°.

**FixPosture (2021)** ([polishedPostureDetection.py](https://github.com/MyWorldRules/FixPosture/blob/4651b926bc15b80de0055f9ea70d4b335029b535/polishedPostureDetection.py#L131-L173)) [code]:
- A Haar-cascade face box is compared with an averaged baseline.
- Bad if the centre moves ≥ 50 px or the area changes by ≥ 1500 px².

### Inferences
- **The two maintained, Intel-compatible, frontal-camera Swift implementations converge on the same design** (Dorso and PostureBar):
  - signal = face or nose height drop (primary) plus face size increase (secondary);
  - measured only in the "worse" direction;
  - normalized to a personal calibration (range-based in Dorso; robust-spread-based in PostureBar).

  Neither uses roll or yaw, shoulder line, or interpupillary-distance-based distance estimation.
- **Unit choice matters.** PostureBar's thresholds have floors (`max(0.030, 4σ)`) so a very still calibration cannot yield an extremely tight threshold. Dorso's default dead zone (0.03 × range) is tiny, so in practice nearly any drop below the lowest calibrated nose height counts, and the burden moves to debounce and onset delay.
- **PostureFix's direction-prescribing cues and exercise advice, and BatesPosture's symmetry terms (shoulder level, head side tilt), are concrete examples of what the user's app must avoid before a spine diagnosis.**

### Gaps
- The LearnOpenCV reference implementation ("Building a Body Posture Analysis System using MediaPipe") could not be retrieved; the raw GitHub path returned 404. Its exact thresholds and its often-quoted alert timing remain unverified [ss: LearnOpenCV](https://learnopencv.com/building-a-body-posture-analysis-system-using-mediapipe/).
- The SitApp, SlouchSniper, Posture Monitor, Nekoze and Posture Pal algorithms are closed source.
- The "Fix Posture" (Glitch) code was not retrieved.

## 5. What reviews, discussions and press say: accuracy, false positives, CPU/battery/camera light, long-term use

### Takeaway
Recurring complaints:
- Over-sensitivity to normal head movement: looking down at a keyboard, food or phone, or turning to a second monitor.
- Misses: rounded shoulders with a level head, when only head pitch or face height is used.
- Lighting, glasses and external-camera problems for face detection.
- Battery and CPU drain.
- Camera-light and privacy unease.
- Habituation or abandonment: users "ignoring the cat"; wearable adhesive failures; poor retention for the Upright app.

Developers responded mainly by adding onset delays, alternative feedback styles and auto-pauses, rather than by adding more complex models.

### Cited Findings
- **Over-sensitivity and false positives.**
  - Posture Pal (iOS) reviews: "sensitive to every little change in my head movement"; it alerts when looking down to take a bite of food or bending to pick something up; it "might be better if it didn't notify until after a few seconds" [ss: App Store](https://apps.apple.com/us/app/posture-pal-improve-alert/id1590316152).
  - Cult of Mac: the giraffe "would pop up constantly whenever [the user] moved their head" until sensitivity was lowered [ss: Cult of Mac](https://www.cultofmac.com/reviews/posture-pal-use-airpods-to-improve-posture-awesome-apps).
  - Nekoze: users report the app "constantly meowing for no reason" even when posture had not changed [ss: App Store](https://apps.apple.com/us/app/nekoze/id627505674?mt=12).
  - SitApp: false alarms such as popping up "when turning to look at a second monitor" (the search summary attributed this to the Digital Trends/PCWorld coverage; the exact page could not be verified) [ss: Digital Trends](https://digitaltrends.com/computing/i-fixed-my-back-sitapp/), [ss: PCWorld](https://www.pcworld.com/article/2905862/this-free-app-fixed-my-posture-and-stopped-my-backaches.html).
  - Dorso changelog: the onset delay was added for "brief glances at keyboard" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L404-L408); "false positive posture warnings immediately after calibration" were fixed [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L254); "leaning head backward no longer incorrectly triggers" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L311).
- **Missed detections.** Posture Pal reviewers note it can fail to detect "slouching shoulders while keeping the head level" [ss: App Store](https://apps.apple.com/us/app/posture-pal-improve-alert/id1590316152).
- **Detection robustness.**
  - Nekoze users report the FaceTime camera "struggling to identify them in good light", glasses being a problem, external webcams not recognised, and "practically no user help" for tuning [ss: App Store](https://apps.apple.com/us/app/nekoze/id627505674?mt=12).
  - Dorso fixed distorted, green-tinted video from professional cameras and capture cards by switching to the VGA preset and RGB format [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L256-L262).
  - Hacker News users reported that Posturr's blur initially didn't work even after permissions were granted; this was fixed later [ss: HN](https://news.ycombinator.com/item?id=46754944).
- **Battery and CPU.**
  - Nekoze reviewers say it "drains batteries" [ss: App Store](https://apps.apple.com/us/app/nekoze/id627505674?mt=12).
  - Dorso: a user reported high CPU usage in AirPods mode, and the developer lists 7–14% CPU across its frame-rate modes [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L228-L231), [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L324-L334). A "Pause on battery" setting was added at a user's request [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L43-L45).
- **Camera light and privacy.**
  - A Dorso user's privacy concern led to the camera stopping when the Mac locks, so the "webcam light now turns off when computer is locked" [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L413-L417).
  - PostureBar releases the camera when another app needs the microphone or camera [repo-docs](https://github.com/bogumat/posturebar/blob/9527ad21a83c35ae5a0719ad543dffc179f12769/README.md#L69-L70).
  - Every product reviewed advertises on-device processing (SitApp, SlouchSniper, SitTall, Posture Monitor, Dorso, PostureBar, PostureFix) [ss](https://setapp.com/apps/slouchsniper), [ss](https://hunted.space/product/sittall-fix-your-posture), [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/PRIVACY.md#L3-L36).
- **Feedback-style preferences.** A user suggested a "screen border alternative to blur", which led to the vignette and border modes [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L430-L444). Another contributor added a more aggressive "solid color" style [repo-docs](https://github.com/tldev/dorso/blob/80a41c22d647d56cc01d7a0d1045ffdf86d8dfcc/CHANGELOG.md#L316-L321). This suggests users want both gentler and harsher options.
- **Long-term use and abandonment.**
  - Nekoze: "not super accurate, with users ignoring the cat after a while" [ss: App Store](https://apps.apple.com/us/app/nekoze/id627505674?mt=12).
  - Upright GO: in one week-long test, adhesive strips lasted about two days instead of the claimed ten. They slide on sweaty skin, and frequent removal shortens their life; a necklace accessory was introduced as a workaround [ss: GearBrain](https://www.gearbrain.com/amp/review-upright-go-posture-device-2525783958), [ss: AppleInsider](https://appleinsider.com/articles/21/05/01/review-upright-go-2-tells-you-to-sit-up-straight-for-better-posture).
  - The Upright app is described as rated 4.0/5 from about 5.5K reviews and as struggling with user retention (as of 2026-05-28, on a third-party app-analytics site of unclear reliability) [ss: marlvel.ai](https://marlvel.ai/apps/upright-1).
  - Lumo Lift: some reviewers found it "too sensitive and intrusive" [ss: Wareable](https://www.wareable.com/fitness-trackers/lumo-lift-review). The company later closed [ss: Craft.co](https://craft.co/lumo-bodytech).
- **Positive reports.**
  - PCWorld's author credits SitApp with fixing their posture and back pain [ss: PCWorld](https://www.pcworld.com/article/2905862/this-free-app-fixed-my-posture-and-stopped-my-backaches.html).
  - A Nekoze reviewer found it meows reliably once slouching exceeds 5–10% [ss: App Store](https://apps.apple.com/us/app/nekoze/id627505674?mt=12).
  - Posture Pal: "does a great job at … keep[ing] track of my posture through use of AirPods" [ss: App Store](https://apps.apple.com/us/app/posture-pal-improve-alert/id1590316152).
  - Posturr/Dorso reached the HN top 10 and was widely covered (Korben, Gigazine, ITC.ua) [ss: Gigazine](https://gigazine.net/gsc_news/en/20260126-posturr/), [ss: ITC.ua](https://itc.ua/news/razrabotchyk-sozdal-dlya-macos-programmu-kontrolya-osanky-ekran-zablyuryat-esly-vy-sutulytes/).
- **HN side discussion.** One developer reportedly had Claude Code assess slouching from screenshots, and a Linux port ("Postured") exists [ss: HN](https://news.ycombinator.com/item?id=46754944).

### Inferences
- **The biggest practical failure mode for head-only signals is task-related head movement** (keyboard or phone glances, second monitors, eating). Products address it with time-based gating (an onset delay or hold time), not with better geometry.
- **Habituation is common with frequent, binary alerts** (Nekoze's "ignoring the cat", Lumo's "intrusive"). The longer-lived projects moved toward escalating, ambient and reversible feedback (Dorso's progressive blur and glow, PostureBar's progressive volume) and toward user-controlled pauses.
- **For a camera on a desktop iMac, battery is irrelevant but the camera light is not.** Dorso and PostureBar treat camera release (on lock, during calls) as part of the privacy design.

### Gaps
- Direct Reddit, Hacker News comment-level and Product Hunt review text could not be read (blocked). Themes above come from search summaries and repository changelogs.
- No longitudinal or controlled data on adherence or efficacy was found for any camera app. Upright's pain-reduction and retention claims were not verified against primary sources.
- No user-feedback evidence was found specifically for Intel Macs (CPU load, fan noise) running Vision body-pose apps continuously.
