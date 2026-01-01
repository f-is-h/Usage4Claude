# Usage4Claude

[English](../README.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.kr.md)

<div align="center">

<img src="images/icon@2x.png" width="256" alt="icon">

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0%2B-orange?style=flat-square)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-purple?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/f-is-h/Usage4Claude?style=flat-square)](https://github.com/f-is-h/Usage4Claude/releases)
[![Downloads (all assets, all releases)](https://img.shields.io/github/downloads/f-is-h/Usage4Claude/total)](https://github.com/f-is-h/Usage4Claude/releases)

**Claude AI 사용량을 실시간으로 모니터링하는 우아한 macOS 메뉴 바 앱.**

✨ **모든 Claude 플랫폼 모니터링 지원: Web • Claude Code • Desktop • Mobile App** ✨

[기능](#-기능) • [다운로드 및 설치](#-다운로드-및-설치) • [사용 가이드](#-사용-가이드) • [자주 묻는 질문](#-자주-묻는-질문) • [프로젝트 지원](#-프로젝트-지원)

</div>

---

## ✨ 기능

### 🎯 핵심 기능

- **📊 실시간 모니터링** - 메뉴 바에서 Claude 구독 사용 할당량을 실시간 표시
- **🎯 다중 제한 지원** - 최대 5가지 제한 동시 표시(5시간/7일/추가 사용량/7일 Opus/7일 Sonnet)
- **🎨 스마트 표시 모드** - 데이터가 있는 모든 제한 유형을 자동 감지하여 표시
- **⚙️ 사용자 정의 표시** - 표시할 제한 유형을 수동으로 선택, 모든 조합 지원
- **🎨 스마트 컬러** - 사용률에 따라 자동 색상 변경(5시간: 녹색/주황/빨강; 7일: 보라색 그라데이션)
- **⏰ 정확한 타이밍** - 분 단위로 할당량 재설정 시간 표시
- **🔄 스마트 새로고침 시스템** - 지능형 4단계 적응형 새로고침 또는 고정 간격(1/3/5/10분)
- **⚡ 수동 새로고침** - 새로고침 버튼 클릭으로 즉시 데이터 업데이트(10초 디바운스 보호)
- **💻 네이티브 경험** - 순수 네이티브 macOS 앱, 가볍고 우아함

### 🌐 크로스 플랫폼 지원

모든 Claude 제품과 원활하게 작동:
- 🌐 **Claude.ai** (웹 인터페이스)
- 💻 **Claude Code** (개발자용 CLI 도구)
- 🖥️ **Desktop App** (macOS/Windows)
- 📱 **Mobile App** (iOS/Android)

모든 플랫폼이 동일한 사용 할당량을 공유하므로 한 곳에서 모니터링!

### 🎨 개인화

- **🕓 다양한 표시 모드**
  - 백분율만 표시 - 깔끔하고 직관적, 클릭 없이 확인 가능
  - 아이콘만 표시 - 절제되고 우아함, 클릭 시 상세 정보 표시
  - 아이콘 + 백분율 - 완전한 정보, 빠른 시각적 식별

- **🌍 다국어 지원**
  - English
  - 日本語
  - 简体中文
  - 繁體中文
  - 한국어
  - 더 많은 언어 지원 예정...

### 🔧 편리한 기능

- **⚙️ 시각적 설정** - 코드 수정 없이 GUI로 모든 옵션 구성
- **🆕 스마트 업데이트 알림** - 메뉴 바 배지와 무지개 애니메이션으로 새 버전 알림
- **🚀 로그인 시 실행** - 시스템 시작 시 자동 실행 옵션
- **⌨️ 키보드 단축키** - 일반적인 작업에 단축키 지원(⌘R, ⌘,, ⌘Q)
- **👋 친절한 안내** - 첫 실행 시 상세한 설정 마법사 제공
- **… 메뉴 표시** - 다양한 메뉴 접근 방법, 상세 보기 및 우클릭
- **🛠️ 디버그 모드** - 개발자 옵션: 가짜 데이터 테스트, 시뮬레이션 업데이트, 즉시 새로고침

### 🔒 보안 및 개인정보

- 🏠 **로컬 저장소만** - 모든 데이터는 로컬에만 저장, 개인 정보 수집 및 업로드 절대 없음
- 🔐 **Keychain 보호** - 민감한 정보는 Keychain에 저장, 평문 키 없음
- 📖 **오픈 소스 투명성** - 코드 완전 공개, 누구나 감사 가능
- 🛡️ **샌드박스 보호** - App Sandbox 활성화로 보안 강화

---

## 📸 스크린샷

### 메뉴 바 표시

- 아이콘과 모든 사용량 제한을 자유롭게 조합하여 표시 가능(최소 1개 항목은 표시 필요)
- 형태와 색상의 이중 표시로 단색 테마에서도 쉽게 식별

| 아이콘 | 5시간 | 7일 | 추가 사용량 | 7일 Opus | 7일 Sonnet | 단색(적응형) |
|:---:|:---:|:---:|:---:|:---:|:---:|-----|
| <img src="images/bar.icon@2x.png" width="40" height="40" alt="icon"> | <img src="images/bar.5h@2x.png" width="45" height="45" alt="5h ring"> | <img src="images/bar.7d@2x.png" width="45" height="45" alt="7d ring"> | <img src="images/bar.ex@2x.png" width="45" height="45" alt="extra ring"> | <img src="images/bar.7do@2x.png" width="45" height="45" alt="7d opus ring"> | <img src="images/bar.7ds@2x.png" width="45" height="45" alt="7d sonnet ring"> | <img src="images/bar.mono.b@2x.png" width="auto" height="35" alt="mono black"></br> <img src="images/bar.mono.w@2x.png" width="auto" height="35" alt="mono white"> |

**색상 표시**:

- **5시간 제한(상세 창 포함)**: ![macOS 녹색](https://img.shields.io/badge/macOS_녹색-34C759) → ![macOS 주황](https://img.shields.io/badge/macOS_주황-FF9500) → ![macOS 빨강](https://img.shields.io/badge/macOS_빨강-FF3B30)
- **7일 제한(상세 창 포함)**: ![연보라](https://img.shields.io/badge/연보라-C084FC) → ![보라](https://img.shields.io/badge/보라-B450F0) → ![진보라](https://img.shields.io/badge/진보라-B41EA0)
- **추가 사용량**: ![분홍](https://img.shields.io/badge/분홍-FF9ECD) → ![장미](https://img.shields.io/badge/장미-EC4899) → ![마젠타](https://img.shields.io/badge/마젠타-D946EF)
- **7일 Opus 제한**: ![연주황](https://img.shields.io/badge/연주황-FFC864) → ![호박색](https://img.shields.io/badge/호박색-FBBF24) → ![주황빨강](https://img.shields.io/badge/주황빨강-FF6432)
- **7일 Sonnet 제한**: ![연파랑](https://img.shields.io/badge/연파랑-64C8FF) → ![파랑](https://img.shields.io/badge/파랑-007AFF) → ![남색](https://img.shields.io/badge/남색-4F46E5)

### 상세 창

<table border="0">
<tr>
<td align="top" valign="top">
<img src="images/detail.5.kr@2x.png" width="280" alt="5시간 제한 모드">
<br/><br/><br/><br/>
<sub><i>5시간 제한 모드</i></sub>
</td>
<td align="center" valign="top">
<img src="images/detail.all.kr@2x.png" width="280" alt="전체 제한 모드">
<br/>
<sub><i>전체 제한 모드(자유롭게 조합 가능)</i></sub>
</td>
<td align="center" valign="top">
<img src="images/detail@2x.gif" width="280" alt="전환 애니메이션">
<br/>
<sub><i>남은 시간 전환 애니메이션</i></sub>
</td>
</tr>
</table>



### 설정

**일반** - 로그인 시 실행, 표시 사용자 정의, 테마 설정, 새로고침 및 언어 옵션
**인증** - Claude 계정 인증 정보 구성, 연결 진단
**정보** - 버전 정보 및 관련 링크

### 환영 화면

**인증 정보 구성** - Session Key, Organization ID 자동 검색
**표시 옵션 구성** - 표시 옵션 및 테마 설정, 실시간 미리보기 지원
**나중에 설정** - 환영 화면을 닫고 나중에 설정에서 구성

---

## 💾 다운로드 및 설치

### 방법 1: 미리 빌드된 버전 다운로드(권장)

1. [Releases 페이지](https://github.com/f-is-h/Usage4Claude/releases)로 이동
2. 최신 `.dmg` 파일 다운로드
3. 더블 클릭하여 열고 앱을 Applications 폴더로 드래그
4. 첫 실행 시 앱을 우클릭하고 "열기" 선택(서명되지 않은 앱 허용)
5. 인증 정보 저장을 위한 Keychain 접근 허용(버전 업데이트 후 다시 허용 필요. 인증 프롬프트는 1회 표시: Session Key)

### 방법 2: 소스에서 빌드

#### 요구사항
- macOS 13.0 이상
- Xcode 15.0 이상
- Git

#### 빌드 단계

```bash
# 저장소 복제
git clone https://github.com/f-is-h/Usage4Claude.git
cd Usage4Claude

# Xcode에서 열기
open Usage4Claude.xcodeproj

# Xcode에서 Cmd + R로 실행
```

---

## 📖 사용 가이드

### 초기 설정

1. **앱 실행**
   첫 실행 시 환영 화면이 표시됩니다

2. **인증 정보 구성**
   "인증 설정으로 이동" 버튼 클릭

3. **Session Key 가져오기**
   - "브라우저에서 Claude 사용량 페이지 열기" 클릭
   - 브라우저 개발자 도구 열기(F12 또는 Cmd + Option + I)
   - "Network" 탭으로 전환
   - 페이지 새로고침
   - `usage`라는 이름의 요청 찾기
   - Headers 보기, `Cookie`에서 `sessionKey=sk-ant-...` 값 찾기

4. **정보 입력**
   - Session Key를 "Session Key" 필드에 붙여넣기
   - 구성 완료 후 자동으로 모니터링 시작

### 일상적인 사용

- **기본 표시** - 메뉴 바에 사용량 백분율 표시
- **상세 보기** - 메뉴 바 아이콘 또는 백분율 클릭
- **수동 새로고침** - 상세 창에서 새로고침 버튼 클릭 또는 단축키 ⌘R 사용
- **메뉴 표시** - 상세 창에서 "…" 아이콘 클릭 또는 메뉴 바 아이콘 우클릭
- **키보드 단축키**
  - ⌘R - 수동으로 데이터 새로고침
  - ⌘, - 일반 설정 열기
  - ⌘⇧A - 인증 설정 열기
  - ⌘Q - 앱 종료
- **업데이트 알림** - 새 버전이 있을 때 메뉴 바 아이콘에 배지 표시, 메뉴 항목에 무지개 텍스트 표시
- **업데이트 확인** - 메뉴 → 업데이트 확인

### 새로고침 모드

**스마트 빈도(권장)**
- 사용 패턴에 따라 새로고침 간격 자동 조정
- 활성 모드(1분) - Claude 활발히 사용 중일 때 빠른 새로고침
- 유휴 모드(3/5/10분) - 유휴 시 점진적으로 새로고침 속도 감소
- 유휴 기간 동안 API 호출 크게 감소(최대 10배)
- 사용 감지 시 즉시 1분 새로고침으로 복귀

**고정 빈도**
- **1분** - 일관된 모니터링에 권장
- **3분** - 균형잡힌 모니터링
- **5분** - 저빈도 모니터링
- **10분** - 최소 API 호출

---

## ❓ 자주 묻는 질문

<details>
<summary><b>Q: 앱이 "세션 만료됨"을 표시하면 어떻게 하나요?</b></summary>

A: Session Key는 주기적으로 만료됩니다(보통 몇 주에서 몇 달), 다시 가져와야 합니다:
1. 설정 → 인증 열기
2. 구성 가이드에 따라 새 Session Key 가져오기
3. 새 Session Key 붙여넣기

</details>

<details>
<summary><b>Q: 시작 시 자동 실행을 활성화하려면?</b></summary>

A: 두 가지 방법이 있습니다:

**방법 1: 내장 옵션 사용(권장)**
1. 설정 → 일반 열기
2. "로그인 시 실행" 옵션 체크

**방법 2: 시스템 설정을 통해**
1. 시스템 설정 → 일반 → 로그인 항목 열기
2. "+"를 클릭하여 Usage4Claude 추가

</details>

<details>
<summary><b>Q: 시스템 리소스를 얼마나 사용하나요?</b></summary>

A: 매우 가볍습니다:
- CPU 사용률: < 0.1%(유휴 시)
- 메모리: ~20MB
- 네트워크: 분당 1회 요청만

</details>

<details>
<summary><b>Q: 어떤 macOS 버전을 지원하나요?</b></summary>

A: macOS 13.0(Ventura) 이상이 필요합니다. Intel 및 Apple Silicon(M1/M2/M3) 칩 모두 지원합니다.

</details>

<details>
<summary><b>Q: Keychain 권한이 왜 필요한가요?</b></summary>

A:
- Keychain은 macOS의 시스템 수준 비밀번호 관리자입니다
- Session Key는 Keychain에 암호화되어 저장됩니다
- Organization ID는 로컬 구성에 저장(민감하지 않은 식별자)
- 이것은 Apple이 권장하는 안전한 저장 방법입니다
- 이 앱만 정보에 액세스할 수 있으며 다른 앱은 볼 수 없습니다

</details>

<details>
<summary><b>Q: 내 데이터는 안전한가요? 개인정보는 어떻게 보호되나요?</b></summary>

**완전히 안전합니다!**

**데이터 저장:**
- 모든 데이터는 **오직** 로컬 Mac에만 저장
- 정보 수집, 추적, 통계 전혀 없음
- Claude API 호출 외 다른 네트워크 요청 없음
- 타사 서비스 사용 안 함

**인증 보안:**
- Session Key는 macOS Keychain을 통해 암호화(시스템 수준 암호화)
- Keychain은 AES-256 암호화 + 하드웨어 보호(T2 / Secure Enclave) 사용
- 이 앱만 자격 증명에 액세스 가능, 다른 앱은 읽을 수 없음
- "Keychain Access" 앱을 통해 언제든 액세스 취소 가능

**코드 투명성:**
- 100% 오픈 소스
- 난독화 또는 숨겨진 기능 없음
- 커뮤니티가 감사 및 검증 가능

**추가 보호:**
- App Sandbox 활성화(시스템 액세스 제한)
- 파일, 연락처 또는 다른 앱에 대한 액세스 권한 없음
- 최소 권한(네트워크 + Keychain만)

GitHub에서 소스 코드를 검토하여 이 모든 것을 확인할 수 있습니다!

</details>

<details>
<summary><b>Q: Claude Code / Desktop App / Mobile App에서 작동하나요?</b></summary>

A: **예, 모든 Claude 플랫폼에서 작동합니다!**

모든 Claude 제품(Web, Claude Code, Desktop App, Mobile App)이 동일한 사용 할당량을 공유하므로 Usage4Claude는 모든 플랫폼에서의 총 사용량을 모니터링합니다.

다음과 같은 경우에도:
- 터미널에서 `claude code`로 코딩
- claude.ai에서 채팅
- 데스크톱 앱 사용
- 모바일 앱 사용

메뉴 바에서 실시간 총 사용량을 볼 수 있습니다. 플랫폼별 구성이 필요 없습니다!

</details>

<details>
<summary><b>Q: 메뉴 바에 아이콘이 보이지 않으면?</b></summary>

A: macOS 시스템 또는 타사 소프트웨어(Bartender, Hidden Bar 등)가 메뉴 바 아이콘을 자동으로 숨길 수 있습니다.

**해결 방법:**
1. **Command (⌘) 키** 누르기
2. 메뉴 바에서 마우스로 아이콘 드래그
3. Usage4Claude 아이콘을 메뉴 바 오른쪽 보이는 영역으로 드래그
4. 마우스 놓기

**참고:**
- macOS Sonoma(14.0+)는 자주 사용하지 않는 아이콘을 자동으로 "제어 센터"에 숨깁니다
- "시스템 설정" → "제어 센터"에서 메뉴 바 아이콘 표시를 조정할 수 있습니다

</details>

---

## 🛠 기술 스택

최신 macOS 네이티브 기술로 구축:

- **언어**: Swift 5.0+
- **UI 프레임워크**: SwiftUI + AppKit 하이브리드
- **아키텍처**: MVVM
- **네트워킹**: URLSession
- **반응형**: Combine Framework
- **현지화**: 내장 i18n 지원
- **플랫폼**: macOS 13.0+

---

## 🗺 로드맵

### ✅ 완료됨
- [x] 기본 모니터링 기능
- [x] 메뉴 바 실시간 표시
- [x] 원형 진행 표시기
- [x] 스마트 색상 알림
- [x] 실시간 카운트다운
- [x] 메뉴 바 다중 표시 모드
- [x] 시각적 설정 인터페이스
- [x] 다국어 지원
- [x] 첫 실행 안내
- [x] 업데이트 확인 및 시각적 알림
- [x] Keychain 인증 저장
- [x] Shell 자동 DMG 패키징
- [x] GitHub Actions 자동 릴리스
- [x] 설정 인터페이스 표시 최적화
- [x] 로그인 시 실행 옵션
- [x] 키보드 단축키 지원
- [x] 수동 새로고침 기능
- [x] 3점 메뉴 다크 모드 적응
- [x] 이중 제한 모드 지원(5시간 + 7일)
- [x] 이중 링 메뉴 바 아이콘
- [x] 통합 색상 체계 관리
- [x] 디버그 모드(가짜 데이터, 시뮬레이션 업데이트)
- [x] 상세 창 Focus 상태 제거
- [x] 다중 제한 유형 지원(5가지)
- [x] 스마트/사용자 정의 표시 모드
- [x] Organization ID 자동 검색
- [x] 최적화된 환영 플로우
- [x] 단색 테마 아이콘 표시
- [x] 한국어 지원

### 단기 계획
1. **개발자 경험**
    - 🚧 GitHub Actions 온라인 버전 확인

### 중기 계획
2. **표시 최적화**
    - 🚧 설정 인터페이스 다크 모드 적응

3. **기능 추가**
    - 사용량 알림
    - 더 많은 언어 현지화

### 장기 비전
4. **자동 설정**
   - 브라우저 확장 프로그램을 통한 자동 인증
   - 자격 증명 자동 구성

5. **더 많은 표시 방법**
   - 데스크톱 위젯
   - 브라우저 확장 프로그램 아이콘 사용량 표시

6. **데이터 분석**
   - 사용 기록
   - 트렌드 차트

7. **멀티플랫폼 지원**
   - iOS / iPadOS 버전
   - Apple Watch 버전
   - Windows 버전

---

## 🤝 기여

모든 형태의 기여를 환영합니다! 새로운 기능, 버그 수정 또는 문서 개선이든.

자세한 기여 가이드라인은 [CONTRIBUTING.md](../CONTRIBUTING.md)를 참조하세요.

### 기여 방법

1. 이 저장소 포크
2. 기능 브랜치 생성(`git checkout -b feature/AmazingFeature`)
3. 변경 사항 커밋(`git commit -m 'Add some AmazingFeature'`)
4. 브랜치에 푸시(`git push origin feature/AmazingFeature`)
5. Pull Request 열기

### 기여자

이 프로젝트에 기여한 모든 분들께 감사드립니다!

<!-- ALL-CONTRIBUTORS-LIST:START -->
<!-- 기여자 목록이 자동으로 생성됩니다 -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## 📝 변경 로그

자세한 버전 기록 및 업데이트 내용은 [CHANGELOG.md](../CHANGELOG.md)를 참조하세요.

---

## 💖 프로젝트 지원

이 프로젝트가 도움이 되었다면 다음 방법으로 지원해 주세요:

### ⭐ 프로젝트에 Star 주기
Star를 주는 것이 가장 큰 격려입니다!

### ☕ 커피 사주기

<!-- GitHub Sponsors -->
<a href="https://github.com/sponsors/f-is-h?frequency=one-time">
  <img src="https://img.shields.io/badge/GitHub-Sponsor-EA4AAA?style=for-the-badge&logo=github" alt="GitHub Sponsor">
</a>

<!-- Ko-fi -->
<a href="https://ko-fi.com/1attle">
  <img src="https://img.shields.io/badge/Ko--fi-Support-FF5E5B?style=for-the-badge&logo=ko-fi" alt="Ko-fi">
</a>

<!-- Buy Me A Coffee -->
<!-- <a href="https://buymeacoffee.com/fish_">
  <img src="https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee">
</a> -->

### 📢 프로젝트 공유
이 프로젝트가 마음에 드신다면 더 많은 사람들에게 공유해 주세요!

---

## 📄 라이선스

이 프로젝트는 MIT 라이선스에 따라 라이선스가 부여됩니다 - 자세한 내용은 [LICENSE](LICENSE) 파일 참조

```
MIT License

Copyright (c) 2025 f-is-h

소프트웨어의 사본을 자유롭게 사용, 복사, 수정, 병합, 게시, 배포, 재라이선스 및/또는 판매할 수 있습니다.
```

---

## 🙏 감사의 말

- [Claude AI](https://claude.ai)에 감사드립니다 - 대부분의 코드가 AI에 의해 작성되었습니다
- 모든 기여자와 사용자의 지원에 감사드립니다
- 아이콘 디자인은 Claude AI 공식 브랜딩에서 영감을 받았습니다

---

## 📞 연락처

- **Issues**: [문제 또는 제안 제출](https://github.com/f-is-h/Usage4Claude/issues)
- **Discussions**: [토론 참여](https://github.com/f-is-h/Usage4Claude/discussions)
- **GitHub**: [@f-is-h](https://github.com/f-is-h)

---

## ⚖️ 면책 조항

이 프로젝트는 Anthropic 또는 Claude AI와 공식적인 관련이 없는 독립적인 타사 도구입니다. 이 소프트웨어를 사용할 때 Claude AI의 서비스 약관을 준수하십시오.

---

<div align="center">

**이 프로젝트가 도움이 되었다면 ⭐ Star를 주세요!**

Made with ❤️ by [f-is-h](https://github.com/f-is-h)

[⬆ 맨 위로](#usage4claude)

</div>
