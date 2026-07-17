# Mac Motion Cues — Design Notes

macOS에 가속도계가 없어 시스템의 "Vehicle Motion Cues" 접근성 기능을 쓸 수 없는 문제를,
AirPods의 헤드 모션 센서(`CMHeadphoneMotionManager`, 공개 API)로 대체 구현한 것이 이 앱이다.
이 문서는 (1) Apple의 실제 시스템 기능을 리버스 엔지니어링해서 확인한 사실과, (2) 그로부터
이 저장소에 반영한 개선 사항을 기록한다.

## 0. Apple 시스템 기능 리버스 엔지니어링 결과

`dyld_shared_cache_arm64e`에서 `AXMotionCuesServices.framework` / `AccessibilityUtilities.framework`를
`ipsw`(https://github.com/blacktop/ipsw)로 추출해 class-dump한 결과:

```
AccessibilityUtilities.framework
  └ AXSettings.MotionCues                       # 설정값 저장 (Swift)
      motionCuesDotSize: Float
      motionCuesDotDensity: Float
      motionCuesIncreasedSizeEnabled: Bool
      motionCuesIncreasedDensityEnabled: Bool

AXMotionCuesServices.framework
  └ AXMotionCuesService (XPC 싱글턴)
      enableWithCompletionBlock: / disable:
      registerMotionCuesMoving:(block)           # 애니메이션 프레임 콜백
      registerMotionCuesVisible:(block)          # 표시/숨김(fade) 콜백
      simulateDeviceMotion:(motion)              # 내부 미리보기용 모션 주입 hook

CoreMotion (private notification)
  kCMMotionCuesEnterVehicularStateNotification    # OS의 "차량 탑승" 판별 이벤트
```

점을 실제로 그리는 렌더러 코드는 이 프레임워크들 안에 없다 — `AXMotionCuesService`는 "모션 판별 →
moving/visible 콜백 발행"까지만 하는 XPC 브로커이고, 그리기는 별도 클라이언트가 담당한다. 이 앱의
`OverlayWindowController` + `DotsView` + `DotsViewModel`이 정확히 그 클라이언트 역할을 독자적으로
구현한 것에 해당한다 (private XPC는 호출하지 않음 — 엔타이틀먼트가 없어 애초에 불가능).

`kCMMotionCuesEnterVehicularStateNotification`의 존재는 실제 기능이 iPhone의 **모션 코프로세서
기반 활동 분류**로 "차량 탑승"을 판별한다는 뜻이다. Mac + AirPods 조합에는 이 분류기가 없으므로,
`CoreLocationDetectionSource`가 GPS 속도 기반 휴리스틱(진입 5m/s 이상 5초 지속, 이탈 1m/s 이하
30초 지속)으로 이를 근사한다 — 가속도 분산 기반보다 오탐이 적어 이 방식이 더 낫다.

Apple의 실제 UI 옵션(`Localizable.loctable`에서 확인, 문자열 그대로 재사용 가능):

| 항목 | 실제 키 | 값 |
|---|---|---|
| 색상 | `display.motionCues.color.*` | Grayscale / Blue / Green / Yellow / Orange / Red / Purple |
| 패턴 | `display.motionCues.pattern.*` | Regular(default) / Dynamic |
| 크기 | `display.motionCues.size` | "더 큰 점" (bool 부스트) |
| 밀도 | `display.motionCues.density` | "더 많은 점" (bool 부스트) |

## 1. 이 저장소의 실제 아키텍처 (구현 완료 상태)

```
CMHeadphoneMotionManager (AirPods, 공개 API)
        │  CMDeviceMotion
        ▼
AirPodsMotionSource ──► MotionPipeline ──► DotsViewModel ──► DotsView
        │                    ▲                                 │
        ▼                    │                                 ▼
MotionSource (protocol)      │                          OverlayWindowController
                             │                          (화면별 borderless NSWindow)
CoreLocationDetectionSource ─┘
(VehicleDetectionSource protocol, GPS 속도 기반 "차량 탑승" 게이팅)
```

- `Motion/MotionSource.swift` — `MotionSource`/`VehicleDetectionSource` 프로토콜. 모션 소스(구동)와
  차량 감지 소스(게이팅)를 분리해 여러 소스를 플러그인처럼 추가할 수 있게 설계됨.
- `Motion/AirPodsMotionSource.swift` — `CMHeadphoneMotionManager` 래핑, 권한/연결 상태 머신,
  5초 무응답 시 `.stale` 전환하는 워치독 포함.
- `Motion/CoreLocationDetectionSource.swift` — GPS 속도 히스테리시스로 "차량 탑승" 판별.
- `ViewModel/DotsViewModel.swift` — anchor 기반 점 배치(네 가장자리), 스프링 물리로 오프셋 애니메이션,
  강한 모션 시 파티클(`MotionBubble`) 스폰.
- `View/DotsView.swift` — `CueMark`(신규, §2 참조)로 dot/bubble 렌더링 통합, `VibrantCircle`/`VibrantRing`으로
  `NSVisualEffectView` 기반 반투명 스타일 제공.
- `View/OverlayWindowController.swift` — `NSScreen.screens`마다 클릭 통과 borderless 오버레이 창 관리,
  `appState.appEnabled && pipeline.shouldRenderCues`를 관찰해 자동 install/uninstall.

## 2. 이번에 추가한 개선: 색상(Color) 옵션

기존 구현에는 Apple 실제 기능의 7가지 색상 옵션이 빠져 있었다 (검정 고정). §0에서 확인한 정확한
옵션 세트와 실제 로컬라이즈 문자열을 그대로 가져와 추가했다.

- `ViewModel/DotsSettings.swift`: `DotColorOption` enum (grayscale/blue/green/yellow/orange/red/purple),
  `dotColor` 설정값 (UserDefaults 영속화, 기본값 `.grayscale` = 기존 검정 외형 유지).
- `View/DotsView.swift`: dot/bubble이 각각 중복 구현하던 solid/vibrant 분기를 `CueMark(style:color:)`
  뷰로 통합하며 색상 tint 적용 (`.dynamic` 스타일은 vibrant blur 위에 반투명 컬러 오버레이).
- `View/MenuBar.swift`: "Dot Style" 섹션에 Color 피커 추가 (스타일 피커의 `Style`/`Halo` 행과 동일한
  레이아웃 패턴).
- `Localizable.xcstrings`: "Color/Grayscale/Blue/Green/Yellow/Orange/Red/Purple"의 en/de/ko/pt-BR
  번역을 Apple의 실제 `Localizable.loctable` 값 그대로 추가 (직접 번역하지 않고 원본 재사용).

기본값(`grayscale`)에서는 기존 검정 점 외형이 그대로 유지되므로 회귀 없음.

## 3. 알려진 한계

- 모션 코프로세서 기반 "automotive activity" 분류가 없어 `CoreLocationDetectionSource`의 차량 탑승
  판별은 GPS 속도 근사치 (도보/자전거 등 오탐 가능성 있음 — 그래서 수동 소스 토글이 필요).
- 실제 Apple 렌더러의 정확한 애니메이션 커브/색상 렌더링 디테일(예: "색 채도 자동 대비 조정")은
  알 수 없어 이 앱은 자체 근사치로 구현됨.
- private XPC(`simulateDeviceMotion:` 등)는 사용하지 않음 — 엔타이틀먼트 문제로 호출 불가.
