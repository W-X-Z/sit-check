# 자세 코치 (SitCheck) v0.1

오래 앉아 있으면 알려 주고, 스트레칭 2개를 골라 주고, 어느 쪽이 덜 갔는지 기록하는 개인용 macOS 메뉴바 앱.
v0.1은 카메라 없이 키보드·마우스 입력만으로 동작한다.

- 기획서 검토와 MVP에서 해석한 부분: [docs/spec-review.md](docs/spec-review.md)

## 동작

| 화면 | 내용 |
|---|---|
| 메뉴바 아이콘 | `⏱ 23분` 연속 착석 시간. 40분이 넘으면 `⚠`, 20분마다 1분간 `🌬`(호흡 신호, 소리 없음), 끄기 중이면 `🌙`, 자리 비움이면 `⏸` |
| 알림 카드 | 화면 우상단, 포커스를 뺏지 않는 패널. "42분째 앉아 있어요 / 일어나서 2개만 하고 오세요" + 스트레칭 2개, 동작별 덜 간 쪽(왼쪽/같음/오른쪽), 통증·저림, 10분 미루기, 1시간 끄기, 완료 |
| 스트레칭 가이드 | 카드에서 동작을 누르면 단계 설명, 확인 포인트, 좌→우(→추가 세트) 타이머 |
| 메뉴 | 현재 상태, 최근 7일 수행률, 동작별 좌우 뻣뻣함(14일), 지금 스트레칭 하기, 1시간 끄기, 설정 |
| 설정 | 임계값, 호흡 신호, 처방에 쓸 동작, 한쪽 추가 세트, CSV 내보내기, 전체 삭제 |

두 동작의 덜 간 쪽을 누르면(탭 2회) 자동으로 완료 처리되고 착석 타이머가 0분부터 다시 시작한다.

## 빌드와 실행

요구 사항: macOS 14 이상, Xcode 15 이상(또는 Command Line Tools의 Swift 5.9 이상). 외부 의존성은 없다.

```bash
# 바로 실행 (터미널을 닫으면 종료)
swift run SitCheck

# 메뉴바 전용 .app 만들기 → build/SitCheck.app
./scripts/make-app.sh
open build/SitCheck.app

# 로직 테스트
swift test
```

Xcode에서 열려면 `open Package.swift` 후 `SitCheck` 스킴을 실행한다.
로그인할 때 자동으로 켜려면 `build/SitCheck.app`을 `/Applications`로 옮기고 시스템 설정 → 일반 → 로그인 항목에 추가한다.

권한: 유휴 시간은 `CGEventSource`로 읽기 때문에 손쉬운 사용·입력 모니터링 권한이 필요 없다. 네트워크도 쓰지 않는다.

## 구조

```
Sources/
  SitCheckCore/        UI와 무관한 로직 (테스트 대상)
    SitTracker.swift     유휴 시간 → 연속 착석 구간 (FR-01, 02)
    NudgeScheduler.swift 알림 판정: 40분, 미루기, 끄기, 15분 간격, 호흡 (FR-03, 07, 13)
    Prescriber.swift     처방 규칙 R1~R3, 연속 금지, 순환 (FR-04)
    Stretch.swift        스트레칭 7종, 좌우 타이머 구간, 추가 세트 (FR-05)
    Records.swift        기록 모델, 수행률·뻣뻣함 지수·진료 권유 (NFR-10)
    Store.swift          SQLite (sit_bout, nudge, stretch_log, settings), CSV 내보내기
    Settings.swift       설정값
  SitCheck/            macOS 앱 (SwiftUI MenuBarExtra + NSPanel)
Tests/SitCheckCoreTests/
```

데이터 위치: `~/Library/Application Support/SitCheck/sitcheck.sqlite`

## 다음 단계

기획서대로 일주일 써 본 뒤 메뉴의 **7일 수행률이 50% 이상**이면 v0.2(카메라 기준 자세, R2·R3)로 넘어간다.
`Prescriber`에 R2·R3 처방이 이미 들어 있어서, v0.2에서는 감지기가 `NudgeRule.tiltRotation` / `.screenApproach`를 발생시키기만 하면 된다.

> 이 앱은 진단이나 교정 방향을 제시하지 않는다. 통증이나 저림이 이어지면 진료를 받자.
