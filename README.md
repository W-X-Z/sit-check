# 자세 코치 (SitCheck) v0.3

오래 앉아 있으면 일어나자고 알려 주고, 카메라로 자세를 보며 같은 자세가 오래 이어지거나 앉은 직후보다 낮아지거나 화면에 가까워지면 알려 주는 개인용 macOS 메뉴바 앱.
카메라로는 '바른 자세'를 판정하지 않고, 앉은 직후의 내 자세와 비교한 변화만 본다.

- 기획서 검토와 MVP에서 해석한 부분: [docs/spec-review.md](docs/spec-review.md)
- 자세 감지 방향성 리서치: [docs/posture-detection-research.md](docs/posture-detection-research.md), 근거 노트는 [docs/research-notes/posture-detection/](docs/research-notes/posture-detection/)

## 빠른 시작

```bash
cd ~/Desktop/sit-check
git pull
./scripts/make-signing-identity.sh   # 선택, 한 번만: 재빌드해도 카메라 권한 유지
./scripts/make-app.sh                # build/SitCheck.app
pkill -x SitCheck; open build/SitCheck.app
```

요구 사항: macOS 14 이상, Command Line Tools(Swift 5.9 이상) 또는 Xcode. 외부 의존성은 없다. `make-app.sh`는 SwiftPM을 거치지 않고 `swiftc`로 직접 빌드한다.
로그인할 때 자동으로 켜려면 `build/SitCheck.app`을 `/Applications`로 옮기고 시스템 설정 → 일반 → 로그인 항목에 추가한다.

## 동작

| 화면 | 내용 |
|---|---|
| 메뉴바 아이콘 | `⏱ 23분` 연속 착석 시간. 40분이 넘으면 `⚠`, 끄기 중이면 `🌙`, 자리 비움이면 `⏸` |
| 메뉴 | 착석 시간과 알림까지 남은 시간, **지금 자세**(몇 분째 같은 자세인지, 앉은 직후보다 낮아졌는지·가까워졌는지), 자리 변화 확인, 지금 스트레칭, 1시간 끄기 |
| 오래 앉아 있음 카드 | 화면 우상단, 포커스를 뺏지 않는 패널. "42분째 앉아 있어요" + 스트레칭 2개(누르면 설명과 타이머), 10분 미루기, 1시간 끄기, 완료 |
| 자세 카드 | "25분째 거의 같은 자세예요"처럼 사실 한 줄 + 할 일 한 줄, 넘기기, 1시간 끄기, 일어났다 올게요 |
| 설정 | 오래 앉아 있음 알림 시간, 같은 자세 알림 시간, 카메라 켜기·미리보기, 자세 새로 익히기, 기록 삭제 |

카드는 타이핑이 잠깐 멈출 때 뜨고(최대 5분 미룸), 통화 중(마이크 또는 다른 앱이 카메라 사용)에는 최대 30분 미룬다.

### 카메라 신호

| 규칙 | 조건 (기본값) |
|---|---|
| R5 오래 같은 자세 | 얼굴 위치·크기·각도가 평소 흔들림의 4배 넘게 바뀐 마지막 순간부터 20분 (설정에서 바꿀 수 있음) |
| R6 점점 아래로·가까이 | 앉은 지 2–5분의 위치보다 최근 5분이 아래로 또는 가까이 흔들림의 3배 이상, 5분 이어짐. 좌우 값은 쓰지 않는다 |

자세 카드는 하루 3장까지, 넘기면 같은 카드의 간격이 두 배씩 늘어난다. 자리나 화면 위치가 바뀐 것 같으면(새 착석 구간의 처음 몇 분이 평소 자세에서 크게 벗어남) 자세 카드를 멈추고 메뉴에서 새로 익힐지 묻는다.
얼굴이 보이면 키보드·마우스 입력이 없어도 앉아 있는 것으로 본다.

### 저장하는 것

영상, 사진, 프레임별 좌표는 저장하지 않는다. 1분 단위 요약 수치(중앙값·흩어짐), 알림 기록, 착석 구간만 `~/Library/Application Support/SitCheck/sitcheck.sqlite`에 남긴다. 네트워크는 쓰지 않는다.

권한: 유휴 시간은 `CGEventSource`로 읽으므로 손쉬운 사용·입력 모니터링 권한이 필요 없다. 카메라 권한만 필요하다.

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
    PostureCamera.swift    내장 카메라 고정, 프레임 상한, Vision 얼굴 분석
    CallDetector.swift     통화 감지 (카드 미루기)
  sitcheck-analyze/      터미널 분석 도구 (개발용: 기록 요약, 판정값 재생)
Tests/SitCheckCoreTests/
scripts/
  make-app.sh              앱 + 분석 도구 빌드, 서명
  make-signing-identity.sh 로컬 자체 서명 인증서 (선택)
```

> 이 앱은 진단이나 교정 방향을 제시하지 않는다. 통증이나 저림이 이어지면 진료를 받자.
