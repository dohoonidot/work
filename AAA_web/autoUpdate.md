# GitHub Release 자동 배포 가이드

> ASPN AI Agent 앱에 auto_updater 기반 자동 업데이트 및 GitHub Release 배포 완전 가이드

**현재 버전:** 1.3.0
**작성일:** 2025-10-15
**대상 플랫폼:** Windows Desktop
**사용 패키지:** auto_updater v1.0.0 (Sparkle/WinSparkle 기반)

---

## 📋 목차

1. [전체 아키텍처 개요](#전체-아키텍처-개요)
2. [버전 관리 전략](#버전-관리-전략)
3. [GitHub Release 배포 프로세스](#github-release-배포-프로세스)
4. [자동 업데이트 작동 원리](#자동-업데이트-작동-원리)
5. [트러블슈팅](#트러블슈팅)

---

## 전체 아키텍처 개요

### 시스템 구조

```
┌─────────────────────────────────────────────────────────────────┐
│                      Flutter 클라이언트 앱                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 1. 앱 시작 후 3초 지연 (ChatHomePageV5 진입 시)            │  │
│  │ 2. UpdateService가 appcast.xml 조회                       │  │
│  │ 3. shortVersionString과 현재 버전 비교 (빌드 번호 제외)    │  │
│  │ 4. 업데이트 필요 시 WinSparkle 다이얼로그 표시             │  │
│  │ 5. 자동 다운로드 → SILENT 설치 → 재시작                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────────────┘
                       │ HTTPS GET
                       │ /releases/latest/download/appcast.xml
                       ↓
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Releases (호스팅)                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Repository: dohooniaspn/ASPN_AI_AGENT                    │  │
│  │                                                            │  │
│  │  각 Release (예: v1.3.0)에 포함된 파일:                     │  │
│  │    ✅ appcast.xml                    (메타데이터)          │  │
│  │    ✅ ASPN_AI_Agent_Setup_v1.3.0.exe (Inno Setup 설치파일) │  │
│  │                                                            │  │
│  │  URL 구조:                                                 │  │
│  │  - appcast.xml:                                           │  │
│  │    /releases/latest/download/appcast.xml                  │  │
│  │  - Setup 파일:                                            │  │
│  │    /releases/download/v1.3.0/ASPN_AI_Agent_Setup_v1.3.0.exe │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 핵심 컴포넌트

| 컴포넌트 | 역할 | 파일/코드 |
|---------|------|----------|
| **auto_updater** | WinSparkle 기반 자동 업데이트 라이브러리 | `pubspec.yaml` |
| **UpdateService** | 업데이트 확인 및 초기화 로직 | `lib/update/update_service.dart` |
| **appcast.xml** | Sparkle 형식 메타데이터 (버전, 다운로드 URL) | 프로젝트 루트 |
| **installer.iss** | Inno Setup 스크립트 (EXE 생성) | 프로젝트 루트 |
| **GitHub Releases** | 파일 호스팅 및 배포 플랫폼 | 웹 인터페이스 |

---

## 버전 관리 전략

### ✅ 현재 방식: 빌드 번호 제거 (권장)

**pubspec.yaml:**
```yaml
version: 1.3.0  # 빌드 번호(+11) 제거
```

**장점:**
- ✅ Windows 파일 버전과 앱 내부 버전 완벽 일치
- ✅ auto_updater의 버전 비교 로직과 호환
- ✅ 업데이트 반복 알림 문제 해결
- ✅ 단순하고 명확한 버전 관리

**버전 올리는 방법:**
```
1.3.0 → 1.3.1  (버그 수정, 마이너 패치)
1.3.0 → 1.4.0  (새로운 기능 추가)
1.3.0 → 2.0.0  (대규모 변경, 호환성 파괴)
```

### ❌ 이전 방식: 빌드 번호 사용 (문제 발생)

**문제점:**
- `pubspec.yaml`: `version: 1.3.0+11`
- Windows 빌드 파일 버전: `1.3.0` (빌드 번호 무시됨)
- `PackageInfo.version`: `1.3.0+11` 반환
- 버전 불일치로 업데이트 알림 반복 발생

---

## GitHub Release 배포 프로세스

### ✅ 완료된 사전 작업

이미 다음 파일들이 설정되어 있습니다:

1. ✅ `pubspec.yaml`: `version: 1.3.0` (빌드 번호 제거)
2. ✅ `installer.iss`: `AppVersion=1.3.0`, `OutputBaseFilename=ASPN_AI_Agent_Setup_v1.3.0`
3. ✅ `appcast.xml`: 모든 버전 정보 `1.3.0`으로 설정

---

### 📝 배포 단계별 가이드

#### **STEP 1: Flutter Windows 빌드**

```bash
# 프로젝트 루트 디렉토리에서 실행
cd /mnt/c/AI_Agent/AI_Agent/Agent_APP/Desktop_App_amqp_beforeLog

# 클린 빌드 (권장)
flutter clean
flutter pub get

# Windows Release 빌드
flutter build windows --release
```

**빌드 완료 후 생성되는 파일 위치:**
```
build/windows/x64/runner/Release/
  ├── ASPN_AI_Agent.exe         (실행 파일)
  ├── flutter_windows.dll       (Flutter 엔진)
  ├── data/                     (리소스 파일)
  └── ... (기타 DLL 및 의존성)
```

**예상 소요 시간:** 3~5분

---

#### **STEP 2: Inno Setup Compiler로 설치 파일 생성**

1. **Inno Setup Compiler 실행**
   - 프로그램이 없다면: https://jrsoftware.org/isinfo.php 에서 다운로드 및 설치

2. **installer.iss 파일 열기**
   - `File` → `Open` → `installer.iss` 선택

3. **컴파일 실행**
   - `Build` → `Compile` 클릭 (또는 `Ctrl+F9`)
   - 녹색 로그가 나타나며 진행

4. **생성된 설치 파일 확인**
   ```
   Output/ASPN_AI_Agent_Setup_v1.3.0.exe
   ```
   - 파일 크기: 약 50~100MB
   - 이 파일이 사용자에게 배포될 최종 설치 파일입니다

**Inno Setup이 자동으로 하는 작업:**
- ✅ 앱 종료 감지 및 자동 종료 (`taskkill`)
- ✅ 기존 버전 덮어쓰기 (자동 업그레이드)
- ✅ 바탕화면 바로가기 생성 옵션
- ✅ 시작 프로그램 등록 옵션
- ✅ 설치 후 자동 실행

---

#### **STEP 3: GitHub Release 생성 및 파일 업로드**

1. **GitHub 저장소 이동**
   ```
   https://github.com/dohooniaspn/ASPN_AI_AGENT
   ```

2. **Releases 페이지 접속**
   - 오른쪽 사이드바에서 **"Releases"** 클릭
   - 또는 직접 URL: `https://github.com/dohooniaspn/ASPN_AI_AGENT/releases`

3. **새 릴리스 생성**
   - **"Draft a new release"** 버튼 클릭

4. **Release 정보 입력**

   **Tag version (중요!):**
   ```
   v1.3.0
   ```
   - 반드시 `v`로 시작
   - `pubspec.yaml`의 버전과 일치해야 함
   - 태그가 없으면 "Create new tag on publish" 자동 선택

   **Release title:**
   ```
   v1.3.0 - 버전 관리 개선
   ```

   **Description (예시):**
   ```markdown
   ## 🚀 주요 변경사항
   - 빌드 번호 제거로 자동 업데이트 안정성 향상
   - Windows 파일 버전과 앱 내부 버전 완벽 일치
   - 업데이트 반복 알림 문제 해결

   ## 📦 설치 방법
   `ASPN_AI_Agent_Setup_v1.3.0.exe` 다운로드 후 실행

   ## 🔧 기술적 변경
   - pubspec.yaml: version: 1.3.0 (빌드 번호 제거)
   - auto_updater 기반 자동 업데이트 적용
   ```

5. **파일 업로드 (매우 중요!)**

   드래그 앤 드롭 영역에 **반드시 2개 파일** 모두 업로드:

   ```
   ✅ Output/ASPN_AI_Agent_Setup_v1.3.0.exe
   ✅ appcast.xml
   ```

   **주의사항:**
   - `appcast.xml`을 빠뜨리면 자동 업데이트가 작동하지 않습니다
   - 파일명이 정확히 일치해야 합니다
   - `.exe` 파일 업로드에 시간이 걸릴 수 있습니다 (약 1~2분)

6. **릴리스 게시**
   - **"Publish release"** 버튼 클릭
   - 태그가 자동으로 생성되며 릴리스가 공개됩니다

---

#### **STEP 4: 자동 업데이트 작동 확인**

1. **생성된 URL 확인**

   Release 페이지에서 각 파일의 URL을 확인:

   **appcast.xml URL (자동 업데이트가 사용):**
   ```
   https://github.com/dohooniaspn/ASPN_AI_AGENT/releases/latest/download/appcast.xml
   ```

   **Setup 파일 URL:**
   ```
   https://github.com/dohooniaspn/ASPN_AI_AGENT/releases/download/v1.3.0/ASPN_AI_Agent_Setup_v1.3.0.exe
   ```

2. **appcast.xml 접근 테스트**

   브라우저에서 다음 URL 접속:
   ```
   https://github.com/dohooniaspn/ASPN_AI_AGENT/releases/latest/download/appcast.xml
   ```

   **예상 결과:**
   - 파일이 다운로드되거나 XML 내용이 표시되면 ✅ 성공
   - 404 에러가 나면 ❌ 실패 (파일 업로드 다시 확인)

3. **자동 업데이트 테스트**

   **방법 1: 로그인 후 자동 확인 (3초 대기)**
   - 구버전 앱 실행
   - LoginPage에서 로그인
   - ChatHomePageV5 진입 후 3초 대기
   - 업데이트 알림 팝업이 나타나면 성공

   **방법 2: 설정에서 수동 확인**
   - 앱 실행 → 설정 페이지
   - "업데이트 확인" 버튼 클릭
   - 업데이트 다이얼로그 확인

   **예상 로그:**
   ```
   🔄 [AUTO_UPDATE] 초기화 시작...
   ✅ [AUTO_UPDATE] Appcast URL 설정: https://github.com/...
   🔄 [AUTO_UPDATE] 업데이트 확인 시작...
   🔍 버전 비교 - current(short): 1.2.0, latest(basis): 1.3.0
   ✅ [AUTO_UPDATE] 업데이트 확인 완료
   ```

4. **업데이트 프로세스 확인**

   - "Update" 버튼 클릭 → 다운로드 시작
   - 진행률 표시 확인
   - 다운로드 완료 후 자동으로 설치 시작
   - 앱 자동 종료 → 설치 → 재시작
   - 새 버전으로 실행 확인

---

### 📌 배포 전 체크리스트

배포하기 전에 반드시 확인:

- [ ] `pubspec.yaml` version: `1.3.0` (빌드 번호 없음)
- [ ] `installer.iss` AppVersion: `1.3.0`
- [ ] `installer.iss` OutputBaseFilename: `ASPN_AI_Agent_Setup_v1.3.0`
- [ ] `appcast.xml` sparkle:version: `1.3.0`
- [ ] `appcast.xml` sparkle:shortVersionString: `1.3.0`
- [ ] `appcast.xml` url에 태그명 `v1.3.0` 포함
- [ ] GitHub Release 태그: `v1.3.0`
- [ ] 업로드할 파일 2개: `.exe`, `appcast.xml`
- [ ] `flutter build windows --release` 실행 완료
- [ ] Inno Setup 컴파일 성공 확인

---

### 🔄 다음 버전 배포 시 (예: 1.4.0)

1. **파일 수정 (3곳)**

   **1) pubspec.yaml:**
   ```yaml
   version: 1.4.0  # 1.3.0 → 1.4.0
   ```

   **2) installer.iss:**
   ```iss
   AppVersion=1.4.0
   OutputBaseFilename=ASPN_AI_Agent_Setup_v1.4.0
   ```

   **3) appcast.xml:**
   ```xml
   <title>Version 1.4.0</title>
   ...
   url="https://github.com/dohooniaspn/ASPN_AI_AGENT/releases/download/v1.4.0/ASPN_AI_Agent_Setup_v1.4.0.exe"
   sparkle:version="1.4.0"
   sparkle:shortVersionString="1.4.0"
   ```

2. **STEP 1~4 반복**

3. **이전 버전과의 호환성 확인**
   - 데이터베이스 마이그레이션 필요 여부
   - API 호환성
   - 설정 파일 형식 변경

---

## 자동 업데이트 작동 원리

### UpdateService 구조

**파일 위치:** `lib/update/update_service.dart`

**핵심 로직:**

```dart
/// 로그인 후 자동 업데이트 확인
Future<void> checkForUpdatesAfterLogin() async {
  // 1. 초기화 확인
  if (!_isInitialized) await initialize();

  // 2. 3초 지연 (UI 안정화)
  await Future.delayed(UpdateConfig.startupCheckDelay);

  // 3. 버전 비교 (빌드 번호 제거)
  final shouldSkip = await _isAlreadyLatest();
  if (shouldSkip) return;  // 최신 버전이면 스킵

  // 4. WinSparkle 업데이트 다이얼로그 표시
  await autoUpdater.checkForUpdates();
}
```

**버전 비교 로직 (`_isAlreadyLatest`):**

```dart
Future<bool> _isAlreadyLatest() async {
  // 현재 버전 (PackageInfo에서 가져옴)
  final current = await _getCurrentVersion();  // "1.3.0+11" 또는 "1.3.0"
  final currentShort = current.split('+').first.trim();  // "1.3.0"

  // 최신 버전 (appcast.xml의 shortVersionString)
  final latestShort = await _getLatestShortVersionFromAppcast();  // "1.3.0"

  // 비교 (완전 일치 여부)
  return currentShort == latestShort;
}
```

**중요:**
- `split('+')` 로 빌드 번호를 제거하여 비교
- `1.3.0+11`과 `1.3.0`을 같은 버전으로 인식
- 하지만 **현재는 빌드 번호를 사용하지 않으므로** 이 로직이 필요 없어짐

---

### appcast.xml 구조

**파일 위치:** 프로젝트 루트 `appcast.xml`

**Sparkle 표준 형식:**

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>ASPN AI Agent</title>
    <description>Multi-AI Chat Client for Desktop</description>
    <language>ko</language>

    <item>
      <title>Version 1.3.0</title>
      <description>
        <![CDATA[
          <h2>새로운 기능</h2>
          <ul>
            <li>버전 관리 시스템 개선 (빌드 번호 제거)</li>
            <li>자동 업데이트 안정성 향상</li>
            <li>성능 개선 및 버그 수정</li>
          </ul>
        ]]>
      </description>
      <pubDate>Wed, 15 Oct 2025 00:00:00 +0900</pubDate>
      <enclosure
        url="https://github.com/dohooniaspn/ASPN_AI_AGENT/releases/download/v1.3.0/ASPN_AI_Agent_Setup_v1.3.0.exe"
        sparkle:version="1.3.0"
        sparkle:shortVersionString="1.3.0"
        type="application/octet-stream"
        sparkle:installerArguments="/SILENT /SP- /SUPPRESSMSGBOXES"
      />
    </item>

  </channel>
</rss>
```

**필드 설명:**

| 필드 | 설명 | 중요도 |
|-----|------|--------|
| `sparkle:version` | 내부 버전 번호 (빌드 번호 포함 가능) | ✅ 필수 |
| `sparkle:shortVersionString` | 사용자 표시 버전 (비교에 사용) | ✅ 필수 |
| `url` | 설치 파일 다운로드 URL | ✅ 필수 |
| `sparkle:installerArguments` | 자동 설치 옵션 (SILENT 모드) | ⚠️ 권장 |
| `pubDate` | 릴리스 날짜 (RFC 822 형식) | ⚠️ 권장 |
| `description` | 릴리스 노트 (HTML 지원) | ⚠️ 권장 |

**Inno Setup 자동 설치 인수:**
```
/SILENT          - 설치 UI 표시 안 함
/SP-             - "This will install..." 메시지 숨김
/SUPPRESSMSGBOXES - 모든 메시지 박스 숨김
```

---

### installer.iss 핵심 기능

**자동 앱 종료 로직:**

```pascal
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // taskkill로 실행 중인 앱 종료
  Exec('taskkill', '/IM ASPN_AI_Agent.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  if ResultCode = 0 then
  begin
    // SILENT 모드: 자동 종료
    if WizardSilent() then
    begin
      Exec('taskkill', '/F /IM ASPN_AI_Agent.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(1500);
      Result := True;
    end
    else
    begin
      // 일반 모드: 사용자 확인
      if MsgBox('ASPN AI Agent가 실행 중입니다. 종료하고 계속하시겠습니까?', mbConfirmation, MB_YESNO) = IDYES then
      begin
        Exec('taskkill', '/F /IM ASPN_AI_Agent.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
        Sleep(1500);
        Result := True;
      end
      else
        Result := False;
    end;
  end;
end;
```

**자동 설치 후 실행:**

```iss
[Run]
Filename: "{app}\ASPN_AI_Agent.exe"; Flags: nowait
```

---

## 트러블슈팅

### 1. "업데이트 알림이 반복적으로 나타남"

**원인:**
- Windows 빌드 파일 버전: `1.3.0`
- 앱 내부 버전 (`PackageInfo`): `1.3.0+11`
- appcast.xml: `1.3.0`
- 버전 불일치로 계속 업데이트 필요로 인식

**해결:**
- ✅ `pubspec.yaml`에서 빌드 번호 제거: `version: 1.3.0`

---

### 2. "appcast.xml 파일을 찾을 수 없음 (404)"

**원인:**
- GitHub Release에 `appcast.xml` 파일 업로드 누락

**해결:**
1. GitHub Release 편집 ("Edit release")
2. `appcast.xml` 파일 드래그 앤 드롭으로 추가
3. "Update release" 클릭

---

### 3. "업데이트 다운로드 후 설치가 시작되지 않음"

**원인:**
- `sparkle:installerArguments` 누락 또는 잘못됨

**해결:**
- appcast.xml에 다음 추가:
  ```xml
  sparkle:installerArguments="/SILENT /SP- /SUPPRESSMSGBOXES"
  ```

---

### 4. "Inno Setup 컴파일 오류: Can't find file"

**원인:**
- Flutter 빌드가 완료되지 않음
- `build/windows/x64/runner/Release/` 폴더가 없음

**해결:**
1. `flutter clean`
2. `flutter build windows --release`
3. `build/windows/x64/runner/Release/` 폴더 존재 확인
4. Inno Setup 재실행

---

### 5. "업데이트 확인 시 아무 일도 일어나지 않음"

**원인:**
- `UpdateService.initialize()` 호출 누락
- `checkForUpdatesAfterLogin()` 호출 누락

**해결:**
- `main.dart`에서 초기화 확인:
  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await UpdateService().initialize();
    runApp(MyApp());
  }
  ```
- `ChatHomePageV5`에서 호출 확인:
  ```dart
  @override
  void initState() {
    super.initState();
    UpdateService().checkForUpdatesAfterLogin();
  }
  ```

---

### 6. "GitHub Release URL이 변경되어야 하는가?"

**질문:**
- appcast.xml의 URL에 특정 버전 태그가 들어가는데, 매번 변경해야 하나?

**답변:**
- ✅ 네, 매번 변경해야 합니다.
- appcast.xml은 각 릴리스마다 새로운 버전 정보를 포함해야 합니다.
- `/releases/latest/download/appcast.xml`은 항상 최신 릴리스의 파일을 가리킵니다.
- `/releases/download/v1.3.0/...`은 특정 버전의 파일을 가리킵니다.

---

## 보안 고려사항

### 1. HTTPS 필수

- ✅ GitHub Releases는 기본적으로 HTTPS 제공
- ❌ HTTP URL 사용 금지

### 2. 파일 무결성

**향후 개선 계획:**
- Inno Setup 빌드 파일의 SHA-256 체크섬 생성
- appcast.xml에 체크섬 추가
- UpdateService에서 다운로드 후 검증

### 3. 코드 서명 (선택적)

**Windows Authenticode 서명:**
```bash
# 인증서 구매 후
signtool sign /f certificate.pfx /p password /tr http://timestamp.digicert.com Output\ASPN_AI_Agent_Setup_v1.3.0.exe
```

**장점:**
- Windows SmartScreen 경고 제거
- 신뢰할 수 있는 게시자로 표시
- 사용자 신뢰도 향상

---

## 참고 자료

### 공식 문서
- [auto_updater 패키지](https://pub.dev/packages/auto_updater)
- [WinSparkle](https://winsparkle.org/)
- [Inno Setup](https://jrsoftware.org/isinfo.php)
- [GitHub Releases 문서](https://docs.github.com/en/repositories/releasing-projects-on-github)

### 관련 파일
- `lib/update/update_service.dart` - 업데이트 서비스
- `lib/update/update_config.dart` - 설정
- `installer.iss` - Inno Setup 스크립트
- `appcast.xml` - Sparkle 메타데이터
- `pubspec.yaml` - 앱 버전 정보

---

## 변경 이력

| 버전 | 날짜 | 변경사항 |
|-----|------|---------|
| 2.0.0 | 2025-10-15 | auto_updater 기반으로 전면 개편, 빌드 번호 제거 전략 적용 |
| 1.0.0 | 2025-10-14 | 초기 문서 작성 (desktop_updater 기반) |

---

**문서 작성:** ASPN AI Agent 개발팀
**최종 수정:** 2025-10-15
**다음 검토:** 1.4.0 배포 시
