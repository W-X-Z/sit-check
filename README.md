# 자세 코치 (SitCheck) v0.2

오래 앉아 있으면 알려 주고, 스트레칭 2개를 골라 주고, 어느 쪽이 덜 갔는지 기록하는 개인용 macOS 메뉴바 앱.
키보드·마우스 입력과 카메라로 착석 시간을 재고, 카메라로는 '바른 자세'를 판정하지 않고 **같은 자세가 오래 이어지는지**와 **앉은 직후보다 아래로·화면 쪽으로 옮겨 갔는지**만 본다.

- 기획서 검토와 MVP에서 해석한 부분: [docs/spec-review.md](docs/spec-review.md)
- 자세 감지 방향성 리서치(기존 앱, 정면 웹캠 정확도, Apple 센서, 인체공학·알림 연구): [docs/posture-detection-research.md](docs/posture-detection-research.md), 근거 노트는 [docs/research-notes/posture-detection/](docs/research-notes/posture-detection/)
- **실험 진행 가이드와 터미널 명령: [docs/experiments.md](docs/experiments.md)**

## 빠른 시작

```bash
cd ~/Desktop/sit-check
git pull
./scripts/make-signing-identity.sh   # 선택, 한 번만: 재빌드해도 카메라 권한 유지
./scripts/make-app.sh                # 앱(build/SitCheck.app) + 분석 도구(build/sitcheck-analyze)
pkill -x SitCheck; open build/SitCheck.app
build/sitcheck-analyze report        # 기록 요약과 다음 할 일
```

요구 사항: macOS 14 이상, Command Line Tools(Swift 5.9 이상) 또는 Xcode. 외부 의존성은 없다. `make-app.sh`는 SwiftPM을 거치지 않고 `swiftc`로 직접 빌드한다.
로그인할 때 자동으로 켜려면 `build/SitCheck.app`을 `/Applications`로 옮기고 시스템 설정 → 일반 → 로그인 항목에 추가한다.

## 동작

| 화면 | 내용 |
|---|---|
| 메뉴바 아이콘 | `⏱ 23분` 연속 착석 시간. 40분이 넘으면 `⚠`, 20분마다 1분간 `🌬`(호흡 신호, 소리 없음), 아이콘만으로 알릴 때 `🚶`, 끄기 중이면 `🌙`, 자리 비움이면 `⏸` |
| 알림 카드 (R1) | 화면 우상단, 포커스를 뺏지 않는 패널. "42분째 앉아 있어요 / 일어나서 2개만 하고 오세요" + 스트레칭 2개, 동작별 덜 간 쪽, 통증·저림, 10분 미루기, 1시간 끄기, 완료 |
| 카메라 카드 (R5–R7) | 측정 기간에는 뜨지 않고 기록만 한다. 켜면: 사실 한 줄 + 원하면 할 움직임 하나 + "맞았나요?" (맞아요 / 아니에요 / 자리가 바뀌었어요) |
| 확인 질문 | 하루 1–2번 "최근 20분 동안 자세를 거의 안 바꿨나요?" (놓친 경우를 보기 위한 것) |
| 메뉴 | 착석 상태, 카메라 상태·마지막 자세 변화, 자리 변화 확인, 최근 7일 수행률, 좌우 뻣뻣함, 지금 스트레칭 하기, 1시간 끄기, 실험·측정, 설정 |
| 실험·측정 창 | 측정 상태, 분석 구성·CPU, 3D·AirPods 확인, 가만히 5분, 의도한 동작 실험, 거리 보정, 평소 자세, 알림 방식 |
| 설정 | 착석·알림 임계값, 카메라 알림 방식과 판정값, 호흡 신호, 처방에 쓸 동작, 한쪽 추가 세트, CSV 내보내기, 전체 삭제 |

카드는 타이핑이 잠깐 멈출 때 뜨고(최대 5분 미룸), 통화 중(마이크 또는 다른 앱이 카메라 사용)에는 최대 30분 미룬다.

### 카메라 신호

| 규칙 | 조건 (출발값, 설정·실험으로 조정) | 비고 |
|---|---|---|
| R5 오래 같은 자세 | 얼굴 위치·크기·각도가 개인 흔들림의 4배 넘게 바뀐 마지막 순간부터 20분 | 기록에는 20·30·45분 변형을 함께 남긴다 |
| R6 점점 아래로·가까이 | 앉은 지 2–5분의 위치보다 최근 5분이 아래로 또는 가까이 흔들림의 3배 이상, 5분 이어짐 | 좌우 값은 쓰지 않는다 |
| R7 가까움 | 거리 보정을 한 경우, 추정 40 cm 미만이 10분 | 설치 점검용 |
| R2·R3 (예전) | 저장한 자세 대비 기울기 12°·회전 18°·얼굴 +15%가 90초 | 카드 없음, 비교 기록만 |

카메라 카드는 하루 3장까지, 무시하거나 넘기면 같은 카드의 간격이 두 배씩 늘어난다. 자리나 화면 위치가 바뀐 것 같으면(새 착석 구간의 처음 몇 분이 평소 자세 기준에서 크게 벗어남) 카메라 카드를 멈추고 다시 배울지 묻는다.

### 저장하는 것

영상, 사진, 프레임별 좌표는 저장하지 않는다. 1분 단위 요약 수치(중앙값·흩어짐·CPU 등), 알림과 답, 착석 구간만 `~/Library/Application Support/SitCheck/sitcheck.sqlite`에 남긴다. 네트워크는 쓰지 않는다. 자세한 내용은 [docs/experiments.md](docs/experiments.md#무엇을-저장하나).

권한: 유휴 시간은 `CGEventSource`로 읽으므로 손쉬운 사용·입력 모니터링 권한이 필요 없다. 카메라 권한, 그리고 AirPods 확인 실험을 할 때만 동작 권한이 필요하다.

## 개발

```bash
swift build          # SwiftPM 빌드 (Command Line Tools가 깨끗할 때)
swift test           # 로직 테스트 (Xcode 필요: Command Line Tools만으로는 no such module 'XCTest')
```

CI는 macOS 15(Apple silicon)에서 빌드·테스트·번들·분석 도구·로컬 서명을, macOS 15 Intel에서 번들·분석 도구를 확인한다.

```
Sources/
  SitCheckCore/          UI와 무관한 로직 (테스트 대상, 앱과 분석 도구가 함께 씀)
    SitTracker.swift       유휴 시간 → 연속 착석 구간, 끝난 이유 (FR-01, 02)
    Posture.swift          카메라 특징, 평소 자세, 예전 R2·R3 비교 판정
    PostureMinute.swift    분 단위 요약, 분석 구성, 실험 라벨
    PostureSignals.swift   R5·R6·R7 판정, 개인 흔들림, 거리 보정
    Baseline.swift         자동 기준, 자리 변화 감지
    Delivery.swift         카드 띄울 시점(작업 경계·통화), 확인 질문 계획
    NudgeScheduler.swift   알림 판정: 40분, 미루기, 끄기, 간격, 하루 상한, 간격 늘리기, 호흡
    Prescriber.swift       알림 규칙, 처방 R1~R3, 연속 금지, 순환 (FR-04)
    Analysis.swift         실험 결과 계산, 기록 재생
    Stretch.swift          스트레칭 7종, 좌우 타이머 구간, 추가 세트 (FR-05)
    Records.swift          기록 모델, 수행률·뻣뻣함 지수·진료 권유 (NFR-10)
    Stats.swift            중앙값, MAD, 백분위
    Store.swift            SQLite (스키마 v2), CSV 내보내기
    Settings.swift         설정값
  SitCheck/              macOS 앱 (SwiftUI MenuBarExtra + NSPanel)
    PostureCamera.swift    내장 카메라 고정, 프레임 상한, Vision 분석, 3D 확인
    SystemProbes.swift     CPU 측정, 통화 감지, AirPods 확인
    ExperimentsView.swift  실험·측정 창
  sitcheck-analyze/      터미널 분석 도구
Tests/SitCheckCoreTests/
scripts/
  make-app.sh              앱 + 분석 도구 빌드, 서명
  make-signing-identity.sh 로컬 자체 서명 인증서 (선택)
```

> 이 앱은 진단이나 교정 방향을 제시하지 않는다. 통증이나 저림이 이어지면 진료를 받자.
